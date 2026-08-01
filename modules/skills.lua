-- Kits de habilidades: memorizan las dos barras de accion y las armas con las
-- que se capturaron.
--
-- APIs de ESO usadas (verificadas contra Wizard's Wardrobe, en produccion):
--   GetSlotBoundId(slotIndex, hotbarCategory)  -> id slotteado
--   GetSlotType(slotIndex, hotbarCategory)     -> ACTION_TYPE_* (crafted)
--   GetAbilityIdForCraftedAbilityId(craftedId) -> abilityId real
--   GetAbilityIcon(abilityId), GetAbilityName(abilityId)
--   Barras: hotbar 0 (frontal) y 1 (trasera); slots de habilidad 3..8
--   (3..7 normales, 8 la ultimate).
--
-- Los kits de habilidades viven en su propio espacio (sv.skillKits), separados
-- de los kits de equipo. Guardan ademas las armas equipadas al capturar, porque
-- las habilidades dependen del tipo de arma de cada barra.

EZOArmory = EZOArmory or {}
EZOArmory.Skills = EZOArmory.Skills or {}

local Skills = EZOArmory.Skills

Skills.HOTBAR_FRONT = 0
Skills.HOTBAR_BACK = 1
Skills.SLOT_FIRST = 3
Skills.SLOT_LAST = 8

local function Store()
    local sv = EZOArmory.sv
    if not sv then return nil end
    sv.skillKits = sv.skillKits or {}
    sv.seq = sv.seq or {}
    sv.seq.skillKit = tonumber(sv.seq.skillKit) or 0
    return sv
end

-- Id de habilidad real de un slot (resolviendo habilidades de scribing).
local function ReadSlotAbility(slotIndex, hotbarCategory)
    if type(GetSlotBoundId) ~= "function" then
        return 0
    end
    local ok, slottedId = pcall(GetSlotBoundId, slotIndex, hotbarCategory)
    if not ok or slottedId == nil then
        return 0
    end

    if type(GetSlotType) == "function"
        and type(GetAbilityIdForCraftedAbilityId) == "function"
        and ACTION_TYPE_CRAFTED_ABILITY ~= nil then
        local okType, actionType = pcall(GetSlotType, slotIndex, hotbarCategory)
        if okType and actionType == ACTION_TYPE_CRAFTED_ABILITY then
            local okCrafted, realId = pcall(GetAbilityIdForCraftedAbilityId, slottedId)
            if okCrafted and realId then
                return tonumber(realId) or 0
            end
        end
    end

    return tonumber(slottedId) or 0
end

-- Captura las dos barras actuales: { [0] = { [3..8] = abilityId }, [1] = ... }
function Skills.CaptureBars()
    local bars = {}
    for hotbar = Skills.HOTBAR_FRONT, Skills.HOTBAR_BACK do
        bars[hotbar] = {}
        for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
            bars[hotbar][slot] = ReadSlotAbility(slot, hotbar)
        end
    end
    return bars
end

-- Referencia de las armas equipadas al capturar (por coherencia de barra).
local function CaptureWeaponsRef()
    local weapons = {}
    if not (EZOArmory.Gear and EZOArmory.Gear.ScanWorn) then
        return weapons
    end
    local scan = EZOArmory.Gear.ScanWorn()
    local function Ref(slotKey)
        local entry = scan.slots[slotKey]
        if entry and entry.hasItem then
            return {
                itemId = entry.itemId,
                itemName = entry.itemName,
                icon = entry.icon,
                -- weaponType permite comprobar despues que las habilidades de
                -- este kit encajan con las armas de la build donde se use.
                weaponType = entry.weaponType,
                setName = entry.setName,
                twoHand = entry.twoHand,
            }
        end
        return nil
    end
    weapons.main = Ref("main")
    weapons.off = Ref("off")
    weapons.backupMain = Ref("backupMain")
    weapons.backupOff = Ref("backupOff")
    return weapons
end

-- Dos capturas de barras son el mismo kit si cada slot de cada barra tiene la
-- misma habilidad.
function Skills.BarsEqual(a, b)
    a = a or {}
    b = b or {}
    for hotbar = Skills.HOTBAR_FRONT, Skills.HOTBAR_BACK do
        local barA = a[hotbar] or {}
        local barB = b[hotbar] or {}
        for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
            if (tonumber(barA[slot]) or 0) ~= (tonumber(barB[slot]) or 0) then
                return false
            end
        end
    end
    return true
end

function Skills.FindKitByBars(bars)
    local sv = Store()
    if not sv then return nil end
    for _, kit in pairs(sv.skillKits) do
        if Skills.BarsEqual(kit.bars, bars) then
            return kit
        end
    end
    return nil
end

-- Crea un kit de habilidades desde las barras actuales. Con contenido identico
-- a un kit existente devuelve (nil, kitExistente, "duplicate").
function Skills.CreateKitFromCurrent(name)
    local sv = Store()
    if not sv then return nil end

    local bars = Skills.CaptureBars()

    -- Sin ninguna habilidad slotteada no hay nada que memorizar.
    local any = false
    for hotbar = Skills.HOTBAR_FRONT, Skills.HOTBAR_BACK do
        for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
            if (bars[hotbar][slot] or 0) ~= 0 then
                any = true
                break
            end
        end
        if any then break end
    end
    if not any then
        return nil, nil, "empty"
    end

    local existing = Skills.FindKitByBars(bars)
    if existing then
        return nil, existing, "duplicate"
    end

    sv.seq.skillKit = sv.seq.skillKit + 1
    local id = "skillkit" .. tostring(sv.seq.skillKit)
    local kit = {
        id = id,
        name = tostring(name or id),
        bars = bars,
        weapons = CaptureWeaponsRef(),
    }
    sv.skillKits[id] = kit
    return id, kit
end

function Skills.GetKit(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.skillKits[id]
end

function Skills.DeleteKit(id)
    local sv = Store()
    if not sv or id == nil or sv.skillKits[id] == nil then return false end
    sv.skillKits[id] = nil
    if EZOArmory.Builds and EZOArmory.Builds.ForgetKit then
        EZOArmory.Builds.ForgetKit(id)
    end
    return true
end

function Skills.RenameKit(id, name)
    local kit = Skills.GetKit(id)
    if not kit then return false end
    kit.name = tostring(name or kit.name)
    return true
end

function Skills.ListKits()
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, kit in pairs(sv.skillKits) do
        list[#list + 1] = kit
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

function Skills.CountAbilities(kit)
    local count = 0
    for hotbar = Skills.HOTBAR_FRONT, Skills.HOTBAR_BACK do
        local bar = kit and kit.bars and kit.bars[hotbar] or {}
        for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
            if (tonumber(bar[slot]) or 0) ~= 0 then
                count = count + 1
            end
        end
    end
    return count
end

-- Habilidades de una barra del kit, en orden de slot, con icono y id listos
-- para pintar un icono interactivo con su propio tooltip real.
-- Devuelve { { abilityId, icon, name }, ... }.
function Skills.GetBarAbilityEntries(kit, hotbar)
    local entries = {}
    local bar = kit and kit.bars and kit.bars[hotbar] or {}
    for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
        local abilityId = tonumber(bar[slot]) or 0
        if abilityId ~= 0 then
            local icon = ""
            if type(GetAbilityIcon) == "function" then
                local okIcon, iconPath = pcall(GetAbilityIcon, abilityId)
                if okIcon and iconPath then icon = iconPath end
            end
            local name = ""
            if type(GetAbilityName) == "function" then
                local okName, abilityName = pcall(GetAbilityName, abilityId)
                if okName and abilityName then name = zo_strformat("<<C:1>>", abilityName) end
            end
            entries[#entries + 1] = { abilityId = abilityId, icon = icon, name = name }
        end
    end
    return entries
end

-- Nombres de las habilidades de una barra, en orden de slot (para el detalle).
function Skills.GetBarAbilityNames(kit, hotbar)
    local names = {}
    if type(GetAbilityName) ~= "function" then return names end
    local bar = kit and kit.bars and kit.bars[hotbar] or {}
    for slot = Skills.SLOT_FIRST, Skills.SLOT_LAST do
        local abilityId = tonumber(bar[slot]) or 0
        if abilityId ~= 0 then
            local ok, name = pcall(GetAbilityName, abilityId)
            if ok and name and name ~= "" then
                names[#names + 1] = zo_strformat("<<C:1>>", name)
            end
        end
    end
    return names
end

-- Icono del arma con la que se capturo cada barra (nil si no habia).
function Skills.GetWeaponIcon(kit, hotbar)
    local weapons = kit and kit.weapons or {}
    local ref = (hotbar == Skills.HOTBAR_BACK) and weapons.backupMain or weapons.main
    if ref and ref.icon and ref.icon ~= "" then
        return ref.icon
    end
    return nil
end
