-- Modelo de datos de kits y loadouts + CRUD sobre SavedVariables.
--
-- Sin API de ESO: solo estructura de datos. La lectura de equipo vive en
-- gear_scanner.lua y el analisis en coherence.lua.
--
-- Kit:      { id, name, setId, setName, slots = { slotKey, ... }, maxEquipped }
-- Loadout:  { id, name, kitIds = { kitId, ... }, trialTag, bossKey }

EZOArmory = EZOArmory or {}
EZOArmory.Kits = EZOArmory.Kits or {}

local Kits = EZOArmory.Kits

-- Garantiza que el almacen existe en SavedVariables. Devuelve nil si aun no hay
-- SavedVariables cargadas (no deberia pasar tras Initialize).
local function Store()
    local sv = EZOArmory.sv
    if not sv then
        return nil
    end
    sv.kits = sv.kits or {}
    sv.loadouts = sv.loadouts or {}
    sv.seq = sv.seq or { kit = 0, loadout = 0 }
    if sv.seq.kit == nil then sv.seq.kit = 0 end
    if sv.seq.loadout == nil then sv.seq.loadout = 0 end
    return sv
end

local function NextId(sv, kind, prefix)
    sv.seq[kind] = (tonumber(sv.seq[kind]) or 0) + 1
    return prefix .. tostring(sv.seq[kind])
end

local function CopySlots(slots)
    local copy = {}
    if type(slots) == "table" then
        for _, slotKey in ipairs(slots) do
            copy[#copy + 1] = tostring(slotKey)
        end
    end
    return copy
end

-- ------------------------------------------------------------------ Kits ----

function Kits.CreateKit(name, setId, setName, slots, maxEquipped)
    local sv = Store()
    if not sv then return nil end

    local id = NextId(sv, "kit", "kit")
    local kit = {
        id = id,
        name = tostring(name or id),
        setId = tonumber(setId) or 0,
        setName = tostring(setName or ""),
        slots = CopySlots(slots),
        maxEquipped = tonumber(maxEquipped) or 0,
    }
    sv.kits[id] = kit
    return id, kit
end

function Kits.GetKit(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.kits[id]
end

function Kits.UpdateKit(id, fields)
    local kit = Kits.GetKit(id)
    if not kit or type(fields) ~= "table" then return false end
    if fields.name ~= nil then kit.name = tostring(fields.name) end
    if fields.setId ~= nil then kit.setId = tonumber(fields.setId) or 0 end
    if fields.setName ~= nil then kit.setName = tostring(fields.setName) end
    if fields.slots ~= nil then kit.slots = CopySlots(fields.slots) end
    if fields.maxEquipped ~= nil then kit.maxEquipped = tonumber(fields.maxEquipped) or 0 end
    return true
end

function Kits.DeleteKit(id)
    local sv = Store()
    if not sv or id == nil then return false end
    if sv.kits[id] == nil then return false end
    sv.kits[id] = nil
    -- Limpia referencias en loadouts.
    for _, loadout in pairs(sv.loadouts) do
        if type(loadout.kitIds) == "table" then
            for i = #loadout.kitIds, 1, -1 do
                if loadout.kitIds[i] == id then
                    table.remove(loadout.kitIds, i)
                end
            end
        end
    end
    return true
end

function Kits.ListKits()
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, kit in pairs(sv.kits) do
        list[#list + 1] = kit
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

-- -------------------------------------------------------------- Loadouts ----

function Kits.CreateLoadout(name, kitIds, trialTag, bossKey)
    local sv = Store()
    if not sv then return nil end

    local id = NextId(sv, "loadout", "loadout")
    local ids = {}
    if type(kitIds) == "table" then
        for _, kitId in ipairs(kitIds) do
            ids[#ids + 1] = tostring(kitId)
        end
    end
    local loadout = {
        id = id,
        name = tostring(name or id),
        kitIds = ids,
        trialTag = trialTag and tostring(trialTag) or nil,
        bossKey = bossKey and tostring(bossKey) or nil,
    }
    sv.loadouts[id] = loadout
    return id, loadout
end

function Kits.GetLoadout(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.loadouts[id]
end

function Kits.DeleteLoadout(id)
    local sv = Store()
    if not sv or id == nil then return false end
    if sv.loadouts[id] == nil then return false end
    sv.loadouts[id] = nil
    return true
end

function Kits.ListLoadouts()
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, loadout in pairs(sv.loadouts) do
        list[#list + 1] = loadout
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

-- Resuelve un loadout a la estructura que espera el motor de coherencia:
--   { name, kits = { kit, ... } }  (kits reales, ignorando ids inexistentes)
function Kits.ResolveLoadout(id)
    local loadout = Kits.GetLoadout(id)
    if not loadout then return nil end

    local resolvedKits = {}
    for _, kitId in ipairs(loadout.kitIds or {}) do
        local kit = Kits.GetKit(kitId)
        if kit then
            resolvedKits[#resolvedKits + 1] = kit
        end
    end

    return { name = loadout.name, kits = resolvedKits }
end

-- Atajo: resuelve y analiza un loadout con el motor de coherencia.
function Kits.AnalyzeLoadout(id, options)
    local resolved = Kits.ResolveLoadout(id)
    if not resolved then return nil end
    if not (EZOArmory.Coherence and EZOArmory.Coherence.Analyze) then return nil end
    return EZOArmory.Coherence.Analyze(resolved, options)
end
