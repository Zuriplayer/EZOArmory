-- Lectura del equipo llevado y localizacion de items concretos.
--
-- APIs de ESO usadas (verificadas contra uso real en EZOMetter y Wizard's Wardrobe):
--   GetItemLink(bag, slot) -> itemLink
--   GetItemLinkSetInfo(itemLink[, equipped]) ->
--       hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, numPerfectedEquipped
--   GetItemLinkEquipType(itemLink) -> equipType  (para armas a dos manos)
--   GetItemUniqueId(bag, slot) + Id64ToString(id) -> identidad estable por instancia
--   GetBagSize(bag), GetItemName(bag, slot)
--   Constantes EQUIP_SLOT_*, BAG_WORN, BAG_BACKPACK, EQUIP_TYPE_TWO_HAND
--
-- Modulo defensivo: cada global de ESO se comprueba antes de usarse.

EZOArmory = EZOArmory or {}
EZOArmory.Gear = EZOArmory.Gear or {}

local Gear = EZOArmory.Gear

-- Barras de armas. La armadura y la joyeria cuentan en ambas; las armas solo
-- en la suya. Por eso el maximo real es de 12 piezas activas por barra.
Gear.BAR_FRONT = "front"
Gear.BAR_BACK = "back"
Gear.BARS = { Gear.BAR_FRONT, Gear.BAR_BACK }

-- Slots conceptuales del personaje, en orden estable.
--   category : armor | jewelry | weapon
--   bars     : en que barras cuenta esta pieza
--   pairSlot : slot de mano secundaria asociado (solo en manos principales)
Gear.SLOT_DEFS = {
    { key = "head",       const = "EQUIP_SLOT_HEAD",        category = "armor",   bars = { front = true, back = true } },
    { key = "shoulders",  const = "EQUIP_SLOT_SHOULDERS",   category = "armor",   bars = { front = true, back = true } },
    { key = "chest",      const = "EQUIP_SLOT_CHEST",       category = "armor",   bars = { front = true, back = true } },
    { key = "waist",      const = "EQUIP_SLOT_WAIST",       category = "armor",   bars = { front = true, back = true } },
    { key = "hands",      const = "EQUIP_SLOT_HAND",        category = "armor",   bars = { front = true, back = true } },
    { key = "legs",       const = "EQUIP_SLOT_LEGS",        category = "armor",   bars = { front = true, back = true } },
    { key = "feet",       const = "EQUIP_SLOT_FEET",        category = "armor",   bars = { front = true, back = true } },
    { key = "neck",       const = "EQUIP_SLOT_NECK",        category = "jewelry", bars = { front = true, back = true } },
    { key = "ring1",      const = "EQUIP_SLOT_RING1",       category = "jewelry", bars = { front = true, back = true } },
    { key = "ring2",      const = "EQUIP_SLOT_RING2",       category = "jewelry", bars = { front = true, back = true } },
    { key = "main",       const = "EQUIP_SLOT_MAIN_HAND",   category = "weapon",  bars = { front = true }, pairSlot = "off" },
    { key = "off",        const = "EQUIP_SLOT_OFF_HAND",    category = "weapon",  bars = { front = true } },
    { key = "backupMain", const = "EQUIP_SLOT_BACKUP_MAIN", category = "weapon",  bars = { back = true }, pairSlot = "backupOff" },
    { key = "backupOff",  const = "EQUIP_SLOT_BACKUP_OFF",  category = "weapon",  bars = { back = true } },
}

Gear._defByKey = {}
for _, def in ipairs(Gear.SLOT_DEFS) do
    Gear._defByKey[def.key] = def
end

function Gear.GetSlotDef(slotKey)
    return Gear._defByKey[slotKey]
end

-- Slots que cuentan en una barra concreta (siempre 12).
function Gear.GetBarSlotKeys(bar)
    local keys = {}
    for _, def in ipairs(Gear.SLOT_DEFS) do
        if def.bars[bar] then
            keys[#keys + 1] = def.key
        end
    end
    return keys
end

-- Agrupaciones habituales de slots al crear un kit. Reflejan como se componen
-- las builds en la practica: 5 de ropa, monster en cabeza y hombros, joyeria
-- con armas frontales, etc. "slots = nil" significa todo lo que se lleve puesto.
Gear.SLOT_PRESETS = {
    { key = "body5",         slots = { "chest", "waist", "hands", "legs", "feet" } },
    { key = "headShoulders", slots = { "head", "shoulders" } },
    { key = "armor7",        slots = { "head", "shoulders", "chest", "waist", "hands", "legs", "feet" } },
    { key = "jewelry3",      slots = { "neck", "ring1", "ring2" } },
    { key = "jewelryFront5", slots = { "neck", "ring1", "ring2", "main", "off" } },
    { key = "weaponsFront",  slots = { "main", "off" } },
    { key = "weaponsBack",   slots = { "backupMain", "backupOff" } },
    { key = "all",           slots = nil },
}

function Gear.GetPresetSlots(presetKey)
    for _, preset in ipairs(Gear.SLOT_PRESETS) do
        if preset.key == presetKey then
            return preset.slots
        end
    end
    return nil
end

local function ResolveSlotId(const)
    local value = _G[const]
    if type(value) == "number" then
        return value
    end
    return nil
end

-- Identidad estable de una instancia de item.
function Gear.ReadItemId(bag, slot)
    if type(GetItemUniqueId) ~= "function" or type(Id64ToString) ~= "function" then
        return nil
    end
    local ok, uniqueId = pcall(GetItemUniqueId, bag, slot)
    if not ok or uniqueId == nil then
        return nil
    end
    local okStr, asString = pcall(Id64ToString, uniqueId)
    if okStr and asString and asString ~= "" then
        return asString
    end
    return nil
end

local function ReadSetInfo(itemLink)
    if not itemLink or itemLink == "" or type(GetItemLinkSetInfo) ~= "function" then
        return nil
    end

    local ok, hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, numPerfectedEquipped =
        pcall(GetItemLinkSetInfo, itemLink, true)
    if not ok then
        ok, hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, numPerfectedEquipped =
            pcall(GetItemLinkSetInfo, itemLink)
    end
    if not ok or not hasSet then
        return nil
    end

    numEquipped = tonumber(numEquipped) or 0
    numPerfectedEquipped = tonumber(numPerfectedEquipped) or 0

    return {
        setName = tostring(setName or ""),
        setId = tonumber(setId) or 0,
        numBonuses = tonumber(numBonuses) or 0,
        numEquipped = numEquipped + numPerfectedEquipped,
        maxEquipped = tonumber(maxEquipped) or 0,
    }
end

function Gear.IsTwoHand(itemLink)
    if not itemLink or itemLink == "" or type(GetItemLinkEquipType) ~= "function" then
        return false
    end
    if type(EQUIP_TYPE_TWO_HAND) ~= "number" then
        return false
    end
    local ok, equipType = pcall(GetItemLinkEquipType, itemLink)
    return ok and equipType == EQUIP_TYPE_TWO_HAND
end

-- Describe un item de una bolsa concreta en el formato que guardan los kits.
function Gear.DescribeItem(bag, slot)
    if type(GetItemLink) ~= "function" then
        return nil
    end
    local itemLink = GetItemLink(bag, slot)
    if not itemLink or itemLink == "" then
        return nil
    end

    local info = ReadSetInfo(itemLink)
    local itemName = ""
    if type(GetItemName) == "function" then
        local okName, name = pcall(GetItemName, bag, slot)
        if okName and name then
            itemName = tostring(name)
        end
    end

    return {
        itemId = Gear.ReadItemId(bag, slot),
        itemLink = itemLink,
        itemName = itemName,
        setId = info and info.setId or 0,
        setName = info and info.setName or "",
        maxEquipped = info and info.maxEquipped or 0,
        twoHand = Gear.IsTwoHand(itemLink),
    }
end

-- Escanea el equipo llevado. Devuelve:
--   { slots = { [slotKey] = { key, category, equipSlot, hasItem, ...descripcion } },
--     order = { slotKey, ... } }
function Gear.ScanWorn()
    local result = { slots = {}, order = {} }

    for _, def in ipairs(Gear.SLOT_DEFS) do
        local equipSlot = ResolveSlotId(def.const)
        local entry = {
            key = def.key,
            category = def.category,
            equipSlot = equipSlot,
            hasItem = false,
            itemId = nil,
            itemLink = nil,
            itemName = "",
            setId = 0,
            setName = "",
            maxEquipped = 0,
            twoHand = false,
        }

        if equipSlot ~= nil and BAG_WORN ~= nil then
            local described = Gear.DescribeItem(BAG_WORN, equipSlot)
            if described then
                entry.hasItem = true
                entry.itemId = described.itemId
                entry.itemLink = described.itemLink
                entry.itemName = described.itemName
                entry.setId = described.setId
                entry.setName = described.setName
                entry.maxEquipped = described.maxEquipped
                entry.twoHand = described.twoHand
            end
        end

        result.slots[def.key] = entry
        result.order[#result.order + 1] = def.key
    end

    return result
end

-- Indice de localizacion de items por identidad, para saber si una pieza esta
-- disponible y desde donde equiparla.
--
-- Solo recorre BAG_WORN y BAG_BACKPACK: el banco no sirve porque mover items
-- desde alli requiere una accion del jugador (RequestMoveItem es protegida).
function Gear.BuildItemLocationIndex()
    local index = {}
    if type(GetBagSize) ~= "function" then
        return index
    end

    local bags = {}
    if BAG_WORN ~= nil then bags[#bags + 1] = BAG_WORN end
    if BAG_BACKPACK ~= nil then bags[#bags + 1] = BAG_BACKPACK end

    for _, bag in ipairs(bags) do
        local size = GetBagSize(bag) or 0
        for slot = 0, size do
            local itemId = Gear.ReadItemId(bag, slot)
            if itemId and index[itemId] == nil then
                index[itemId] = { bag = bag, slot = slot }
            end
        end
    end

    return index
end

function Gear.IsSlotFilled(scan, slotKey)
    return scan and scan.slots and scan.slots[slotKey] and scan.slots[slotKey].hasItem == true
end
