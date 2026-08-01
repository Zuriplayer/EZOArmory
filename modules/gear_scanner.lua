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

-- Iconos nativos de ESO para cada slot. Se usan como pista visual compacta de
-- donde va cada pieza de un kit.
--
-- La ruta va SIN barra inicial: es el formato que acepta el marcado en linea
-- |tancho:alto:ruta|t de las etiquetas, el mismo que usa el icono de ayuda del
-- encabezado. Con barra inicial el icono no se dibuja.
Gear.SLOT_TEXTURES = {
    head       = "EsoUI/Art/CharacterWindow/gearSlot_head.dds",
    shoulders  = "EsoUI/Art/CharacterWindow/gearSlot_shoulders.dds",
    chest      = "EsoUI/Art/CharacterWindow/gearSlot_chest.dds",
    waist      = "EsoUI/Art/CharacterWindow/gearSlot_belt.dds",
    hands      = "EsoUI/Art/CharacterWindow/gearSlot_hands.dds",
    legs       = "EsoUI/Art/CharacterWindow/gearSlot_legs.dds",
    feet       = "EsoUI/Art/CharacterWindow/gearSlot_feet.dds",
    neck       = "EsoUI/Art/CharacterWindow/gearSlot_neck.dds",
    ring1      = "EsoUI/Art/CharacterWindow/gearSlot_ring.dds",
    ring2      = "EsoUI/Art/CharacterWindow/gearSlot_ring.dds",
    main       = "EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds",
    off        = "EsoUI/Art/CharacterWindow/gearSlot_offHand.dds",
    backupMain = "EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds",
    backupOff  = "EsoUI/Art/CharacterWindow/gearSlot_offHand.dds",
}

function Gear.GetSlotTexture(slotKey)
    return Gear.SLOT_TEXTURES[slotKey]
end

-- Categoria de un slot a efectos de pista: armor, jewelry, weaponsFront o
-- weaponsBack. Devuelve nil si el slot no existe.
function Gear.GetSlotCategory(slotKey)
    local def = Gear._defByKey[slotKey]
    if not def then return nil end
    if def.category == "armor" or def.category == "jewelry" then
        return def.category
    end
    if def.bars and def.bars.back then
        return "weaponsBack"
    end
    return "weaponsFront"
end

Gear.CATEGORY_ORDER = { "armor", "jewelry", "weaponsFront", "weaponsBack" }

-- Categorias presentes en una lista de slots, en orden canonico.
function Gear.GetCategoryKeys(slots)
    local present = {}
    for _, slotKey in ipairs(slots or {}) do
        local category = Gear.GetSlotCategory(slotKey)
        if category then present[category] = true end
    end
    local keys = {}
    for _, category in ipairs(Gear.CATEGORY_ORDER) do
        if present[category] then
            keys[#keys + 1] = category
        end
    end
    return keys
end

-- Iconos reales de los items en unos slots dados, en orden canonico. Se usan
-- como pista visual a todo color (los iconos de slot son siluetas grises que no
-- se pueden aclarar por tinte).
function Gear.IconsForSlots(scan, slots)
    local icons = {}
    if not scan then return icons end
    local ordered = Gear.SortSlots(slots)
    for _, slotKey in ipairs(ordered) do
        local entry = scan.slots[slotKey]
        if entry and entry.icon and entry.icon ~= "" then
            icons[#icons + 1] = entry.icon
        end
    end
    return icons
end

-- Ordena una lista de slots segun el orden canonico de SLOT_DEFS.
function Gear.SortSlots(slots)
    local rank = {}
    for index, def in ipairs(Gear.SLOT_DEFS) do
        rank[def.key] = index
    end
    local sorted = {}
    for _, slotKey in ipairs(slots or {}) do
        sorted[#sorted + 1] = slotKey
    end
    table.sort(sorted, function(a, b)
        return (rank[a] or 99) < (rank[b] or 99)
    end)
    return sorted
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

    local armorType = nil
    if type(GetItemLinkArmorType) == "function" then
        local okArmor, value = pcall(GetItemLinkArmorType, itemLink)
        if okArmor and value ~= nil and value ~= ARMORTYPE_NONE then
            armorType = value
        end
    end

    -- Tipo de arma (WEAPONTYPE_*): lo usa el rol automatico de una build
    -- (baston de curacion -> sanador, escudo -> tanque, baston de hielo -> duda).
    local weaponType = nil
    if type(GetItemLinkWeaponType) == "function" then
        local okWeapon, value = pcall(GetItemLinkWeaponType, itemLink)
        if okWeapon and value ~= nil and value ~= WEAPONTYPE_NONE then
            weaponType = value
        end
    end

    local info = ReadSetInfo(itemLink)
    local itemName = ""
    if type(GetItemName) == "function" then
        local okName, name = pcall(GetItemName, bag, slot)
        if okName and name then
            itemName = tostring(name)
        end
    end

    local icon = ""
    if type(GetItemLinkIcon) == "function" then
        local okIcon, iconPath = pcall(GetItemLinkIcon, itemLink)
        if okIcon and iconPath and iconPath ~= "" then
            icon = tostring(iconPath)
        end
    end

    return {
        itemId = Gear.ReadItemId(bag, slot),
        itemLink = itemLink,
        itemName = itemName,
        icon = icon,
        armorType = armorType,
        weaponType = weaponType,
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
            icon = "",
            armorType = nil,
            weaponType = nil,
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
                entry.icon = described.icon
                entry.armorType = described.armorType
                entry.weaponType = described.weaponType
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

-- Constante EQUIP_SLOT_* asociada a un slot conceptual, para EquipItem.
function Gear.GetEquipSlotId(slotKey)
    local def = Gear._defByKey[slotKey]
    if not def then return nil end
    local value = _G[def.const]
    if type(value) == "number" then
        return value
    end
    return nil
end

-- Localiza un item por su identidad estable, en equipo puesto y mochila (no en
-- el banco: mover desde alli requiere accion del jugador). Devuelve {bag, slot}
-- o nil. Recorre primero el equipo puesto, para detectar "ya lo llevas".
function Gear.FindItemById(itemId)
    if itemId == nil or type(GetBagSize) ~= "function" then
        return nil
    end

    local bags = {}
    if BAG_WORN ~= nil then bags[#bags + 1] = BAG_WORN end
    if BAG_BACKPACK ~= nil then bags[#bags + 1] = BAG_BACKPACK end

    for _, bag in ipairs(bags) do
        local size = GetBagSize(bag) or 0
        for slot = 0, size do
            if Gear.ReadItemId(bag, slot) == itemId then
                return { bag = bag, slot = slot }
            end
        end
    end
    return nil
end

-- Construye las entradas del selector de captura a partir del equipo puesto.
-- Devuelve una lista ordenada de entradas estructuradas (la interfaz compone la
-- etiqueta localizada):
--   { kind = "all",  value = "all",            count, slots }
--   { kind = "set",  value = "set:<setId>",    setId, name, count, slots }
--   { kind = "slot", value = "slot:<slotKey>", slotKey, name, slots }
--
-- Un set con dos o mas piezas equipadas se ofrece como una sola entrada y sus
-- piezas NO se listan por separado: capturar el set entero es lo util. Solo se
-- listan como sueltas las piezas que realmente lo son: miticos, armas sin set y
-- sets de los que se lleva una unica pieza.
function Gear.GetCaptureEntries(scan)
    scan = scan or Gear.ScanWorn()
    local entries = {}

    local wornSlots = {}
    local setOrder = {}
    local sets = {}

    for _, slotKey in ipairs(scan.order) do
        local entry = scan.slots[slotKey]
        if entry and entry.hasItem then
            wornSlots[#wornSlots + 1] = slotKey

            if entry.setId ~= 0 then
                local bucket = sets[entry.setId]
                if not bucket then
                    bucket = { setId = entry.setId, name = entry.setName, slots = {} }
                    sets[entry.setId] = bucket
                    setOrder[#setOrder + 1] = bucket
                end
                bucket.slots[#bucket.slots + 1] = slotKey
            end
        end
    end

    -- "Todo" primero.
    entries[#entries + 1] = {
        kind = "all",
        value = "all",
        count = #wornSlots,
        slots = wornSlots,
    }

    -- Sets con dos o mas piezas, ordenados por nombre.
    local multiPieceSets = {}
    for _, bucket in ipairs(setOrder) do
        if #bucket.slots >= 2 then
            multiPieceSets[#multiPieceSets + 1] = bucket
        end
    end
    table.sort(multiPieceSets, function(a, b) return tostring(a.name) < tostring(b.name) end)

    local coveredBySet = {}
    for _, bucket in ipairs(multiPieceSets) do
        for _, slotKey in ipairs(bucket.slots) do
            coveredBySet[slotKey] = true
        end
        entries[#entries + 1] = {
            kind = "set",
            value = "set:" .. tostring(bucket.setId),
            setId = bucket.setId,
            name = bucket.name,
            count = #bucket.slots,
            slots = bucket.slots,
            icons = Gear.IconsForSlots(scan, bucket.slots),
        }
    end

    -- Piezas realmente sueltas: lo que no forma parte de un set de varias.
    for _, slotKey in ipairs(wornSlots) do
        if not coveredBySet[slotKey] then
            local entry = scan.slots[slotKey]
            local label = entry.setName
            if label == nil or label == "" then
                label = entry.itemName
            end
            if label == nil or label == "" then
                label = slotKey
            end
            entries[#entries + 1] = {
                kind = "slot",
                value = "slot:" .. slotKey,
                slotKey = slotKey,
                name = label,
                slots = { slotKey },
                icons = Gear.IconsForSlots(scan, { slotKey }),
                armorType = entry.armorType,
            }
        end
    end

    return entries
end

-- Resuelve el valor elegido en el selector a la lista de slots a capturar,
-- contra el equipo puesto en ese momento.
function Gear.ResolveCaptureSlots(value, scan)
    scan = scan or Gear.ScanWorn()
    local slots = {}

    if value == nil or value == "all" then
        for _, slotKey in ipairs(scan.order) do
            if scan.slots[slotKey].hasItem then
                slots[#slots + 1] = slotKey
            end
        end
        return slots
    end

    local kind, rest = string.match(tostring(value), "^(%a+):(.+)$")
    if kind == "slot" then
        if scan.slots[rest] and scan.slots[rest].hasItem then
            slots[#slots + 1] = rest
        end
    elseif kind == "set" then
        local setId = tonumber(rest) or 0
        for _, slotKey in ipairs(scan.order) do
            local entry = scan.slots[slotKey]
            if entry.hasItem and entry.setId == setId then
                slots[#slots + 1] = slotKey
            end
        end
    end

    return slots
end
