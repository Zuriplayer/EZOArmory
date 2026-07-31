-- Equipado de kits mediante una cola con LibAsync.
--
-- Hechos verificados (contra Wizard's Wardrobe, en produccion):
--   - EquipItem(sourceBag, sourceSlot, destEquipSlot) NO es funcion protegida.
--   - Pero el equipo NO se puede cambiar en combate ni muerto: WW condiciona el
--     cambio a not IsUnitInCombat("player") and not IsUnitDeadOrReincarnating.
--   - Mover desde el banco SI es protegido, asi que las piezas deben estar en la
--     mochila (BAG_BACKPACK) o ya puestas.
--
-- Este modulo no crea globales de trabajo pesado ni corre en cada frame salvo
-- mientras aplica un equipado. LibAsync es opcional: sin el, el equipado no esta
-- disponible pero el resto del addon sigue funcionando.

EZOArmory = EZOArmory or {}
EZOArmory.Equip = EZOArmory.Equip or {}

local Equip = EZOArmory.Equip

-- Se puede cambiar equipo ahora mismo.
function Equip.IsReady()
    if type(IsUnitInCombat) == "function" and IsUnitInCombat("player") then
        return false
    end
    if type(IsUnitDeadOrReincarnating) == "function" and IsUnitDeadOrReincarnating("player") then
        return false
    end
    return true
end

-- El equipado requiere LibAsync para repartir el trabajo entre frames.
function Equip.IsAvailable()
    return LibAsync ~= nil
end

-- Construye la lista de objetivos a partir del analisis de coherencia de unos
-- kits: para cada slot asignado, el item concreto y su constante de equip slot.
local function BuildTargets(analysis)
    local targets = {}
    if not analysis or not analysis.assignment then
        return targets
    end

    for slotKey, piece in pairs(analysis.assignment) do
        local equipSlot = EZOArmory.Gear.GetEquipSlotId(slotKey)
        if equipSlot ~= nil and piece.itemId then
            targets[#targets + 1] = {
                slotKey = slotKey,
                equipSlot = equipSlot,
                itemId = piece.itemId,
                itemName = piece.itemName,
                setName = piece.setName,
            }
        end
    end
    return targets
end

-- Equipa un objetivo. Muta el contador de estado.
local function EquipOne(target, state)
    -- Ya puesto en el slot correcto: nada que hacer.
    local wornId = EZOArmory.Gear.ReadItemId(BAG_WORN, target.equipSlot)
    if wornId ~= nil and wornId == target.itemId then
        state.already = state.already + 1
        return
    end

    -- Se localiza en el momento (las posiciones cambian al equipar).
    local location = EZOArmory.Gear.FindItemById(target.itemId)
    if not location then
        state.missing = state.missing + 1
        state.missingNames[#state.missingNames + 1] =
            target.itemName ~= "" and target.itemName or (target.setName ~= "" and target.setName or target.slotKey)
        return
    end

    if location.bag == BAG_WORN then
        -- La pieza exacta esta puesta en otro slot (tipico con los dos anillos).
        -- Reubicarla entre slots de equipo es un caso aparte; se deja para la
        -- fase de la ventana. Por ahora se cuenta y no se toca.
        state.wornElsewhere = state.wornElsewhere + 1
        return
    end

    if type(EquipItem) == "function" then
        EquipItem(location.bag, location.slot, target.equipSlot)
        state.equipped = state.equipped + 1
    end
end

-- Aplica los kits indicados. onReport(state) se llama al terminar (o con un
-- estado de error). Devuelve true si se ha iniciado el proceso.
--
-- state al terminar: { equipped, already, missing, wornElsewhere, missingNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplyKits(kitIds, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    if not (EZOArmory.Kits and EZOArmory.Coherence) then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local resolved = EZOArmory.Kits.ResolveKits(kitIds)
    local analysis = EZOArmory.Coherence.Analyze(resolved)
    local targets = BuildTargets(analysis)

    if #targets == 0 then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local state = {
        equipped = 0,
        already = 0,
        missing = 0,
        wornElsewhere = 0,
        missingNames = {},
        queued = not Equip.IsReady(),
    }

    if state.queued and type(Equip.onQueued) == "function" then
        Equip.onQueued()
    end

    local task = LibAsync:Create("EZOArmory_Equip")
    task:WaitUntil(function()
        return Equip.IsReady()
    end):Then(function(innerTask)
        innerTask:For(1, #targets):Do(function(index)
            EquipOne(targets[index], state)
        end):Then(function()
            if onReport then onReport(state) end
        end)
    end)

    return true
end

-- ------------------------------------------------------- Kits de habilidades ----
--
-- Ranurar una habilidad por codigo (verificado contra el manager nativo,
-- esoui/ingame/skills/actionbarassignmentmanager.lua, y contra
-- WW.SlotSkill/WW.LoadSkills en Wizard's Wardrobe, en produccion):
--   ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)
--       :AssignSkillToSlotByAbilityId(slotIndex, abilityId)
-- No es funcion protegida (llamada Lua normal, sin keybind), pero fuera de
-- combate: RESPEC_RESULT_IS_IN_COMBAT es un resultado de fallo esperado.
-- Antes de ranurar se comprueba que la habilidad este comprada
-- (SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id):GetSkillData()
-- :IsPurchased()), igual que hace WW, por si el kit se capturo en otro
-- personaje o antes de un respec. Solo se toca lo que difiere de lo ya
-- ranurado (mismo principio de aplicacion idempotente que el equipo).

-- Aplica un kit de habilidades. onReport(state) al terminar.
-- state al terminar: { slotted, already, skipped, skippedNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplySkillKit(kitId, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    local kit = EZOArmory.Skills and EZOArmory.Skills.GetKit(kitId)
    if not kit or not kit.bars then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local state = {
        slotted = 0,
        already = 0,
        skipped = 0,
        skippedNames = {},
        queued = not Equip.IsReady(),
    }

    if state.queued and type(Equip.onQueued) == "function" then
        Equip.onQueued()
    end

    local task = LibAsync:Create("EZOArmory_EquipSkills")
    task:WaitUntil(function()
        return Equip.IsReady()
    end):Then(function()
        if type(ACTION_BAR_ASSIGNMENT_MANAGER) ~= "table"
            or type(GetSlotBoundId) ~= "function" then
            if onReport then onReport({ error = "empty" }) end
            return
        end

        for hotbar = EZOArmory.Skills.HOTBAR_FRONT, EZOArmory.Skills.HOTBAR_BACK do
            local hotbarData = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbar)
            local bar = kit.bars[hotbar] or {}
            for slot = EZOArmory.Skills.SLOT_FIRST, EZOArmory.Skills.SLOT_LAST do
                local abilityId = tonumber(bar[slot]) or 0
                if abilityId ~= 0 then
                    local okCurrent, current = pcall(GetSlotBoundId, slot, hotbar)
                    current = (okCurrent and tonumber(current)) or 0

                    if current == abilityId then
                        state.already = state.already + 1
                    else
                        local purchased = false
                        if type(SKILLS_DATA_MANAGER) == "table" then
                            local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
                            purchased = progressionData ~= nil
                                and progressionData:GetSkillData() ~= nil
                                and progressionData:GetSkillData():IsPurchased() == true
                        end

                        if purchased and hotbarData then
                            hotbarData:AssignSkillToSlotByAbilityId(slot, abilityId)
                            state.slotted = state.slotted + 1
                        else
                            state.skipped = state.skipped + 1
                            local okName, name = pcall(GetAbilityName, abilityId)
                            state.skippedNames[#state.skippedNames + 1] =
                                (okName and name and name ~= "") and zo_strformat("<<C:1>>", name)
                                or tostring(abilityId)
                        end
                    end
                end
            end
        end

        if onReport then onReport(state) end
    end)

    return true
end

-- ------------------------------------------------------------- Kits de CP ----
--
-- Ranurar una estrella de CP por codigo (verificado contra
-- esoui/ingame/champion/championassignableactionbar.lua y contra
-- WW.LoadCP en Wizard's Wardrobe, en produccion):
--   PrepareChampionPurchaseRequest()
--   AddHotbarSlotToChampionPurchaseRequest(slotIndex, championSkillId)  -- por slot que cambia
--   SendChampionPurchaseRequest()
-- Ninguna es protegida, pero el juego impone un cooldown real de ~30 s tras
-- cada cambio (CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN); se seguimiento
-- via EVENT_CHAMPION_PURCHASE_RESULT, igual que WW. CRITICO (docs/concept.md
-- 4.3.1): solo se envian los slots que realmente cambian respecto a lo ya
-- ranurado, nunca una peticion completa de los 12 aunque no haga falta.

local cpCooldownRemaining = 0
local cpCooldownTrackingRegistered = false

local function EnsureCpCooldownTracking()
    if cpCooldownTrackingRegistered then return end
    if type(EVENT_MANAGER) ~= "table" or EVENT_CHAMPION_PURCHASE_RESULT == nil then return end
    cpCooldownTrackingRegistered = true

    EVENT_MANAGER:RegisterForEvent("EZOArmory_CPPurchaseResult", EVENT_CHAMPION_PURCHASE_RESULT,
        function(_, result)
            if result == CHAMPION_PURCHASE_SUCCESS then
                cpCooldownRemaining = 31
            end
        end)
    EVENT_MANAGER:RegisterForUpdate("EZOArmory_CPCooldownTick", 1000, function()
        if cpCooldownRemaining > 0 then
            cpCooldownRemaining = cpCooldownRemaining - 1
        end
    end)
end

-- Los CP no estan en cooldown ahora mismo (aparte de estar fuera de combate).
function Equip.IsCpReady()
    return cpCooldownRemaining <= 0
end

-- Aplica un kit de CP. onReport(state) al terminar.
-- state al terminar: { slotted, already, skipped, skippedNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplyCpKit(kitId, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    local kit = EZOArmory.Champion and EZOArmory.Champion.GetKit(kitId)
    if not kit or not kit.stars then
        if onReport then onReport({ error = "empty" }) end
        return false
    end
    if HOTBAR_CATEGORY_CHAMPION == nil or type(GetSlotBoundId) ~= "function" then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    EnsureCpCooldownTracking()

    local queuedReason
    if not Equip.IsReady() then
        queuedReason = "combat"
    elseif not Equip.IsCpReady() then
        queuedReason = "cpCooldown"
    end

    local state = {
        slotted = 0,
        already = 0,
        skipped = 0,
        skippedNames = {},
        queued = queuedReason ~= nil,
    }

    if state.queued and type(Equip.onQueued) == "function" then
        Equip.onQueued(queuedReason)
    end

    local task = LibAsync:Create("EZOArmory_EquipCp")
    task:WaitUntil(function()
        return Equip.IsReady() and Equip.IsCpReady()
    end):Then(function()
        local diffs = {}
        for slot = EZOArmory.Champion.SLOT_FIRST, EZOArmory.Champion.SLOT_LAST do
            local starId = tonumber(kit.stars[slot]) or 0
            if starId ~= 0 then
                local okCurrent, current = pcall(GetSlotBoundId, slot, HOTBAR_CATEGORY_CHAMPION)
                current = (okCurrent and tonumber(current)) or 0

                if current == starId then
                    state.already = state.already + 1
                else
                    local slottable = type(GetChampionSkillType) == "function"
                        and type(CanChampionSkillTypeBeSlotted) == "function"
                        and CanChampionSkillTypeBeSlotted(GetChampionSkillType(starId)) == true
                    local spent = type(GetNumPointsSpentOnChampionSkill) == "function"
                        and (tonumber(GetNumPointsSpentOnChampionSkill(starId)) or 0) > 0

                    if slottable and spent then
                        diffs[#diffs + 1] = { slot = slot, starId = starId }
                    else
                        state.skipped = state.skipped + 1
                        local okName, name = pcall(GetChampionSkillName, starId)
                        state.skippedNames[#state.skippedNames + 1] =
                            (okName and name and name ~= "") and zo_strformat("<<C:1>>", name)
                            or tostring(starId)
                    end
                end
            end
        end

        if #diffs == 0 then
            if onReport then onReport(state) end
            return
        end

        if type(PrepareChampionPurchaseRequest) ~= "function"
            or type(AddHotbarSlotToChampionPurchaseRequest) ~= "function"
            or type(SendChampionPurchaseRequest) ~= "function" then
            if onReport then onReport({ error = "empty" }) end
            return
        end

        PrepareChampionPurchaseRequest()
        for _, diff in ipairs(diffs) do
            AddHotbarSlotToChampionPurchaseRequest(diff.slot, diff.starId)
            state.slotted = state.slotted + 1
        end
        SendChampionPurchaseRequest()

        if onReport then onReport(state) end
    end)

    return true
end
