-- Kits de Puntos de Campeon: memorizan las 12 estrellas slotteadas.
--
-- APIs de ESO usadas (verificadas contra Wizard's Wardrobe, en produccion):
--   GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION) -> championSkillId
--   GetChampionSkillName(championSkillId)
--   Slots de campeon: 1..12.
--
-- Solo memorizan y comparan; la aplicacion de CP llega en una fase posterior
-- (con su cooldown de ~30 s y el principio de aplicar solo la diferencia).
--
-- Disciplina (arbol) de una estrella: NO existe una API directa
-- "championSkillId -> disciplina". GetChampionSkillType(starId) devuelve si la
-- estrella es pasiva o sloteable, no su arbol (confirmado comparando contra
-- esoui/ingame/champion/championdatamanager.lua: la disciplina de una estrella
-- solo se conoce porque el objeto nativo la construye DESDE la disciplina, no
-- al reves). El propio ZO_ChampionDataManager del juego construye esa relacion
-- recorriendo cada disciplina y sus estrellas
-- (GetNumChampionDisciplines/GetChampionDisciplineId/GetChampionDisciplineType/
-- GetNumChampionDisciplineSkills/GetChampionSkillId); este modulo hace lo mismo
-- una sola vez y cachea el resultado, ya que la relacion es fija por parche.

EZOArmory = EZOArmory or {}
EZOArmory.Champion = EZOArmory.Champion or {}

local Champion = EZOArmory.Champion

Champion.SLOT_FIRST = 1
Champion.SLOT_LAST = 12

-- Mapa championSkillId -> CHAMPION_DISCIPLINE_TYPE_*, calculado una sola vez.
local starDisciplineCache = nil

local function BuildStarDisciplineMap()
    local map = {}
    if type(GetNumChampionDisciplines) ~= "function"
        or type(GetChampionDisciplineId) ~= "function"
        or type(GetChampionDisciplineType) ~= "function"
        or type(GetNumChampionDisciplineSkills) ~= "function"
        or type(GetChampionSkillId) ~= "function" then
        return map
    end

    local okCount, disciplineCount = pcall(GetNumChampionDisciplines)
    if not okCount or not disciplineCount then return map end

    for disciplineIndex = 1, disciplineCount do
        local okId, disciplineId = pcall(GetChampionDisciplineId, disciplineIndex)
        if okId and disciplineId then
            local okType, disciplineType = pcall(GetChampionDisciplineType, disciplineId)
            local okSkillCount, skillCount = pcall(GetNumChampionDisciplineSkills, disciplineIndex)
            if okType and okSkillCount and skillCount then
                for skillIndex = 1, skillCount do
                    local okSkillId, starId = pcall(GetChampionSkillId, disciplineIndex, skillIndex)
                    if okSkillId and starId then
                        map[starId] = disciplineType
                    end
                end
            end
        end
    end

    return map
end

-- Disciplina/arbol de una estrella (CHAMPION_DISCIPLINE_TYPE_*), o nil.
function Champion.GetStarDisciplineType(starId)
    if not starDisciplineCache then
        starDisciplineCache = BuildStarDisciplineMap()
    end
    return starDisciplineCache[starId]
end

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

function Champion.RenameKit(id, name)
    local kit = Champion.GetKit(id)
    if not kit then return false end
    kit.name = tostring(name or kit.name)
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
-- Devuelve { { disciplineType, stars = { { starId, name }, ... } }, ... }.
function Champion.GetStarsByDiscipline(kit)
    local groups = {}
    if type(GetChampionSkillName) ~= "function" then
        return groups
    end

    local byType = {}
    for slot = Champion.SLOT_FIRST, Champion.SLOT_LAST do
        local starId = tonumber(kit and kit.stars and kit.stars[slot]) or 0
        if starId ~= 0 then
            local okName, name = pcall(GetChampionSkillName, starId)
            local disciplineType = Champion.GetStarDisciplineType(starId)
            if okName and name and name ~= "" then
                local group = byType[disciplineType]
                if not group then
                    group = { disciplineType = disciplineType, stars = {} }
                    byType[disciplineType] = group
                    groups[#groups + 1] = group
                end
                group.stars[#group.stars + 1] = {
                    starId = starId,
                    name = zo_strformat("<<C:1>>", name),
                }
            end
        end
    end

    return groups
end
