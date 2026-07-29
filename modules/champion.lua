-- Kits de Puntos de Campeon: memorizan las 12 estrellas slotteadas.
--
-- APIs de ESO usadas (verificadas contra Wizard's Wardrobe, en produccion):
--   GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION) -> championSkillId
--   GetChampionSkillName(championSkillId)
--   Slots de campeon: 1..12.
--
-- Solo memorizan y comparan; la aplicacion de CP llega en una fase posterior
-- (con su cooldown de ~30 s y el principio de aplicar solo la diferencia).

EZOArmory = EZOArmory or {}
EZOArmory.Champion = EZOArmory.Champion or {}

local Champion = EZOArmory.Champion

Champion.SLOT_FIRST = 1
Champion.SLOT_LAST = 12

local function Store()
    local sv = EZOArmory.sv
    if not sv then return nil end
    sv.cpKits = sv.cpKits or {}
    sv.seq = sv.seq or {}
    sv.seq.cpKit = tonumber(sv.seq.cpKit) or 0
    return sv
end

-- Captura las estrellas slotteadas: { [1..12] = championSkillId }.
function Champion.CaptureSlotted()
    local stars = {}
    if type(GetSlotBoundId) ~= "function" or HOTBAR_CATEGORY_CHAMPION == nil then
        return stars
    end
    for slot = Champion.SLOT_FIRST, Champion.SLOT_LAST do
        local ok, starId = pcall(GetSlotBoundId, slot, HOTBAR_CATEGORY_CHAMPION)
        stars[slot] = (ok and tonumber(starId)) or 0
    end
    return stars
end

-- Conjunto ordenado de estrellas (ignora el slot concreto): dos kits con las
-- mismas estrellas en distinto orden son realmente el mismo.
local function SortedStars(stars)
    local list = {}
    for slot = Champion.SLOT_FIRST, Champion.SLOT_LAST do
        local starId = tonumber(stars and stars[slot]) or 0
        if starId ~= 0 then
            list[#list + 1] = starId
        end
    end
    table.sort(list)
    return list
end

function Champion.StarsEqual(a, b)
    local listA = SortedStars(a)
    local listB = SortedStars(b)
    if #listA ~= #listB then
        return false
    end
    for index = 1, #listA do
        if listA[index] ~= listB[index] then
            return false
        end
    end
    return true
end

function Champion.FindKitByStars(stars)
    local sv = Store()
    if not sv then return nil end
    for _, kit in pairs(sv.cpKits) do
        if Champion.StarsEqual(kit.stars, stars) then
            return kit
        end
    end
    return nil
end

-- Crea un kit de CP desde lo slotteado ahora. Con las mismas estrellas que un
-- kit existente devuelve (nil, kitExistente, "duplicate").
function Champion.CreateKitFromCurrent(name)
    local sv = Store()
    if not sv then return nil end

    local stars = Champion.CaptureSlotted()
    if #SortedStars(stars) == 0 then
        return nil, nil, "empty"
    end

    local existing = Champion.FindKitByStars(stars)
    if existing then
        return nil, existing, "duplicate"
    end

    sv.seq.cpKit = sv.seq.cpKit + 1
    local id = "cpkit" .. tostring(sv.seq.cpKit)
    local kit = {
        id = id,
        name = tostring(name or id),
        stars = stars,
    }
    sv.cpKits[id] = kit
    return id, kit
end

function Champion.GetKit(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.cpKits[id]
end

function Champion.DeleteKit(id)
    local sv = Store()
    if not sv or id == nil or sv.cpKits[id] == nil then return false end
    sv.cpKits[id] = nil
    return true
end

function Champion.ListKits()
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, kit in pairs(sv.cpKits) do
        list[#list + 1] = kit
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

function Champion.CountStars(kit)
    return #SortedStars(kit and kit.stars)
end

-- Nombres de las estrellas del kit, en orden de slot (para el detalle).
function Champion.GetStarNames(kit)
    local names = {}
    if type(GetChampionSkillName) ~= "function" then return names end
    for slot = Champion.SLOT_FIRST, Champion.SLOT_LAST do
        local starId = tonumber(kit and kit.stars and kit.stars[slot]) or 0
        if starId ~= 0 then
            local ok, name = pcall(GetChampionSkillName, starId)
            if ok and name and name ~= "" then
                names[#names + 1] = zo_strformat("<<C:1>>", name)
            end
        end
    end
    return names
end

-- Estrellas del kit agrupadas por disciplina/arbol de CP (Guerra, Forma
-- Fisica, Mundo), en el orden en que aparecen sus primeras estrellas.
-- Devuelve { { disciplineType, names = { ... } }, ... }.
function Champion.GetStarsByDiscipline(kit)
    local groups = {}
    if type(GetChampionSkillType) ~= "function" or type(GetChampionSkillName) ~= "function" then
        return groups
    end

    local byType = {}
    for slot = Champion.SLOT_FIRST, Champion.SLOT_LAST do
        local starId = tonumber(kit and kit.stars and kit.stars[slot]) or 0
        if starId ~= 0 then
            local okName, name = pcall(GetChampionSkillName, starId)
            local okType, disciplineType = pcall(GetChampionSkillType, starId)
            if okName and name and name ~= "" and okType then
                local group = byType[disciplineType]
                if not group then
                    group = { disciplineType = disciplineType, names = {} }
                    byType[disciplineType] = group
                    groups[#groups + 1] = group
                end
                group.names[#group.names + 1] = zo_strformat("<<C:1>>", name)
            end
        end
    end

    return groups
end
