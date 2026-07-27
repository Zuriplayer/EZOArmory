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
