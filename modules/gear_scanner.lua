-- Lectura del equipo llevado (BAG_WORN) slot a slot, con informacion de set.
--
-- APIs de ESO usadas (verificadas contra uso real en EZOMetter/equipment_sets):
--   GetItemLink(BAG_WORN, equipSlot) -> itemLink
--   GetItemLinkSetInfo(itemLink[, equipped]) ->
--       hasSet, setName, numBonuses, numEquipped, maxEquipped, setId, numPerfectedEquipped
--   GetItemLinkEquipType(itemLink) -> equipType (para detectar armas a dos manos)
--   Constantes EQUIP_SLOT_* y BAG_WORN.
--
-- Modulo defensivo: cada global de ESO se comprueba antes de usarse.

EZOArmory = EZOArmory or {}
EZOArmory.Gear = EZOArmory.Gear or {}

local Gear = EZOArmory.Gear

-- Slots conceptuales del personaje, en orden. "category" agrupa para la
-- interfaz y para el motor de coherencia. "const" es el nombre de la constante
-- EQUIP_SLOT_* de ESO, resuelto en tiempo de escaneo desde _G.
Gear.SLOT_DEFS = {
    { key = "head",       const = "EQUIP_SLOT_HEAD",        category = "armor" },
    { key = "chest",      const = "EQUIP_SLOT_CHEST",       category = "armor" },
    { key = "shoulders",  const = "EQUIP_SLOT_SHOULDERS",   category = "armor" },
    { key = "waist",      const = "EQUIP_SLOT_WAIST",       category = "armor" },
    { key = "hands",      const = "EQUIP_SLOT_HAND",        category = "armor" },
    { key = "legs",       const = "EQUIP_SLOT_LEGS",        category = "armor" },
    { key = "feet",       const = "EQUIP_SLOT_FEET",        category = "armor" },
    { key = "neck",       const = "EQUIP_SLOT_NECK",        category = "jewelry" },
    { key = "ring1",      const = "EQUIP_SLOT_RING1",       category = "jewelry" },
    { key = "ring2",      const = "EQUIP_SLOT_RING2",       category = "jewelry" },
    { key = "main",       const = "EQUIP_SLOT_MAIN_HAND",   category = "weaponFront" },
    { key = "off",        const = "EQUIP_SLOT_OFF_HAND",    category = "weaponFront" },
    { key = "backupMain", const = "EQUIP_SLOT_BACKUP_MAIN", category = "weaponBack" },
    { key = "backupOff",  const = "EQUIP_SLOT_BACKUP_OFF",  category = "weaponBack" },
}

local function ResolveSlotId(const)
    local value = _G[const]
    if type(value) == "number" then
        return value
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
        hasSet = true,
        setName = tostring(setName or ""),
        setId = tonumber(setId) or 0,
        numBonuses = tonumber(numBonuses) or 0,
        numEquipped = numEquipped + numPerfectedEquipped,
        maxEquipped = tonumber(maxEquipped) or 0,
    }
end

local function ReadEquipType(itemLink)
    if not itemLink or itemLink == "" or type(GetItemLinkEquipType) ~= "function" then
        return nil
    end
    local ok, equipType = pcall(GetItemLinkEquipType, itemLink)
    if ok then
        return equipType
    end
    return nil
end

local function IsTwoHandEquipType(equipType)
    -- EQUIP_TYPE_TWO_HAND es la constante nativa; comparacion defensiva.
    if type(EQUIP_TYPE_TWO_HAND) == "number" then
        return equipType == EQUIP_TYPE_TWO_HAND
    end
    return false
end

-- Escanea el equipo llevado y devuelve un snapshot por slot y agregado por set.
--
-- Estructura devuelta:
--   {
--     slots = {
--       [slotKey] = {
--         key, category, equipSlot, hasItem,
--         itemLink, setId, setName, maxEquipped, numEquipped, twoHand
--       }, ...
--     },
--     bySet = {
--       [setId] = { setId, setName, maxEquipped, slotKeys = { ... }, count }
--     },
--     order = { slotKey, ... }  -- orden estable de SLOT_DEFS
--   }
function Gear.ScanWorn()
    local result = { slots = {}, bySet = {}, order = {} }

    if BAG_WORN == nil or type(GetItemLink) ~= "function" then
        return result
    end

    for _, def in ipairs(Gear.SLOT_DEFS) do
        local equipSlot = ResolveSlotId(def.const)
        local entry = {
            key = def.key,
            category = def.category,
            equipSlot = equipSlot,
            hasItem = false,
            itemLink = nil,
            setId = 0,
            setName = "",
            maxEquipped = 0,
            numEquipped = 0,
            twoHand = false,
        }

        if equipSlot ~= nil then
            local itemLink = GetItemLink(BAG_WORN, equipSlot)
            if itemLink and itemLink ~= "" then
                entry.hasItem = true
                entry.itemLink = itemLink
                entry.twoHand = IsTwoHandEquipType(ReadEquipType(itemLink))

                local info = ReadSetInfo(itemLink)
                if info then
                    entry.setId = info.setId
                    entry.setName = info.setName
                    entry.maxEquipped = info.maxEquipped
                    entry.numEquipped = info.numEquipped

                    if info.setId ~= 0 then
                        local agg = result.bySet[info.setId]
                        if not agg then
                            agg = {
                                setId = info.setId,
                                setName = info.setName,
                                maxEquipped = info.maxEquipped,
                                slotKeys = {},
                                count = 0,
                            }
                            result.bySet[info.setId] = agg
                        end
                        agg.slotKeys[#agg.slotKeys + 1] = def.key
                        agg.count = agg.count + 1
                    end
                end
            end
        end

        result.slots[def.key] = entry
        result.order[#result.order + 1] = def.key
    end

    return result
end

-- Devuelve true si el slot conceptual esta ocupado por un item.
function Gear.IsSlotFilled(scan, slotKey)
    return scan and scan.slots and scan.slots[slotKey] and scan.slots[slotKey].hasItem == true
end
