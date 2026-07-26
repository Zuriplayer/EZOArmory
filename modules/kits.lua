-- Modelo de datos: kits de piezas concretas, perfiles de rol y asignaciones.
--
-- Sin API de ESO salvo la captura desde el equipo puesto, que delega en
-- EZOArmory.Gear. El analisis vive en coherence.lua.
--
-- Kit:   { id, name, role, pieces = { [slotKey] = { itemId, itemName, setId,
--                                                   setName, maxEquipped, twoHand } } }
--
-- Los kits son comunes al personaje. Las asignaciones son por rol:
--   profiles[role].assignments[trialTag].default   -> kits por defecto de la trial
--   profiles[role].assignments[trialTag].trash     -> opcional, para trash
--   profiles[role].assignments[trialTag][bossKey]  -> opcional, sobrescribe
--
-- Un objetivo sin asignacion propia hereda el "default" de su trial.

EZOArmory = EZOArmory or {}
EZOArmory.Kits = EZOArmory.Kits or {}

local Kits = EZOArmory.Kits

Kits.ROLES = { "dd", "tank", "healer" }
Kits.TARGET_TRASH = "trash"

local function Store()
    local sv = EZOArmory.sv
    if not sv then
        return nil
    end
    sv.kits = sv.kits or {}
    sv.profiles = sv.profiles or {}
    for _, role in ipairs(Kits.ROLES) do
        sv.profiles[role] = sv.profiles[role] or {}
        sv.profiles[role].assignments = sv.profiles[role].assignments or {}
        sv.profiles[role].autoEquip = sv.profiles[role].autoEquip or {}
    end
    sv.seq = sv.seq or {}
    sv.seq.kit = tonumber(sv.seq.kit) or 0
    return sv
end

local function IsValidRole(role)
    for _, known in ipairs(Kits.ROLES) do
        if known == role then return true end
    end
    return false
end

-- ------------------------------------------------------------------ Kits ----

local function CopyPiece(piece)
    return {
        itemId = piece.itemId and tostring(piece.itemId) or nil,
        itemName = tostring(piece.itemName or ""),
        setId = tonumber(piece.setId) or 0,
        setName = tostring(piece.setName or ""),
        maxEquipped = tonumber(piece.maxEquipped) or 0,
        twoHand = piece.twoHand == true,
    }
end

function Kits.CreateKit(name, pieces, role)
    local sv = Store()
    if not sv then return nil end

    sv.seq.kit = sv.seq.kit + 1
    local id = "kit" .. tostring(sv.seq.kit)

    local stored = {}
    if type(pieces) == "table" then
        for slotKey, piece in pairs(pieces) do
            if type(piece) == "table" then
                stored[tostring(slotKey)] = CopyPiece(piece)
            end
        end
    end

    local kit = {
        id = id,
        name = tostring(name or id),
        role = IsValidRole(role) and role or nil,
        pieces = stored,
    }
    sv.kits[id] = kit
    return id, kit
end

-- Captura un kit desde el equipo que se lleva puesto ahora mismo.
-- slotKeys: lista de slots a capturar. Si se omite, captura todos los ocupados.
function Kits.CreateKitFromWorn(name, slotKeys, role)
    if not (EZOArmory.Gear and EZOArmory.Gear.ScanWorn) then
        return nil
    end

    local scan = EZOArmory.Gear.ScanWorn()
    local pieces = {}

    local keys = slotKeys
    if type(keys) ~= "table" or #keys == 0 then
        keys = scan.order
    end

    for _, slotKey in ipairs(keys) do
        local worn = scan.slots[slotKey]
        if worn and worn.hasItem then
            pieces[slotKey] = {
                itemId = worn.itemId,
                itemName = worn.itemName,
                setId = worn.setId,
                setName = worn.setName,
                maxEquipped = worn.maxEquipped,
                twoHand = worn.twoHand,
            }
        end
    end

    return Kits.CreateKit(name, pieces, role)
end

function Kits.GetKit(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.kits[id]
end

function Kits.RenameKit(id, name)
    local kit = Kits.GetKit(id)
    if not kit then return false end
    kit.name = tostring(name or kit.name)
    return true
end

-- Fija o limpia una pieza concreta del kit. piece = nil elimina el slot.
function Kits.SetKitPiece(id, slotKey, piece)
    local kit = Kits.GetKit(id)
    if not kit or slotKey == nil then return false end
    kit.pieces = kit.pieces or {}
    if piece == nil then
        kit.pieces[tostring(slotKey)] = nil
    else
        kit.pieces[tostring(slotKey)] = CopyPiece(piece)
    end
    return true
end

function Kits.DeleteKit(id)
    local sv = Store()
    if not sv or id == nil or sv.kits[id] == nil then return false end
    sv.kits[id] = nil

    -- Limpia referencias en todas las asignaciones de todos los roles.
    for _, profile in pairs(sv.profiles) do
        for _, trial in pairs(profile.assignments or {}) do
            for _, kitIds in pairs(trial) do
                if type(kitIds) == "table" then
                    for i = #kitIds, 1, -1 do
                        if kitIds[i] == id then
                            table.remove(kitIds, i)
                        end
                    end
                end
            end
        end
    end
    return true
end

function Kits.ListKits(role)
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, kit in pairs(sv.kits) do
        if role == nil or kit.role == nil or kit.role == role then
            list[#list + 1] = kit
        end
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

-- Cuenta cuantas piezas declara un kit (util para la interfaz).
function Kits.CountPieces(kit)
    local count = 0
    for _ in pairs(kit and kit.pieces or {}) do
        count = count + 1
    end
    return count
end

-- ---------------------------------------------------------- Asignaciones ----

local function TrialTable(sv, role, trialTag, create)
    local profile = sv.profiles[role]
    if not profile then return nil end
    local assignments = profile.assignments
    if assignments[trialTag] == nil then
        if not create then return nil end
        assignments[trialTag] = {}
    end
    return assignments[trialTag]
end

-- Asigna una lista de kits a un objetivo. targetKey puede ser:
--   "default"  -> valor por defecto de la trial
--   "trash"    -> trash de esa trial
--   <bossKey>  -> un boss concreto
function Kits.SetAssignment(role, trialTag, targetKey, kitIds)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil or targetKey == nil then
        return false
    end

    local trial = TrialTable(sv, role, tostring(trialTag), true)
    if not trial then return false end

    if kitIds == nil then
        trial[tostring(targetKey)] = nil
        return true
    end

    local ids = {}
    for _, kitId in ipairs(kitIds) do
        if Kits.GetKit(kitId) then
            ids[#ids + 1] = tostring(kitId)
        end
    end
    trial[tostring(targetKey)] = ids
    return true
end

-- Devuelve los kitIds aplicables a un objetivo, aplicando herencia.
-- Segundo valor: "own" si la asignacion es propia, "inherited" si viene del
-- default de la trial, o nil si no hay nada.
function Kits.GetAssignment(role, trialTag, targetKey)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil then
        return nil, nil
    end

    local trial = TrialTable(sv, role, tostring(trialTag), false)
    if not trial then return nil, nil end

    local own = targetKey and trial[tostring(targetKey)] or nil
    if own and #own > 0 then
        return own, "own"
    end

    local fallback = trial.default
    if fallback and #fallback > 0 then
        return fallback, "inherited"
    end

    return nil, nil
end

-- Modo de equipado por trial: automatico o manual.
function Kits.SetAutoEquip(role, trialTag, enabled)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil then return false end
    sv.profiles[role].autoEquip[tostring(trialTag)] = enabled == true
    return true
end

function Kits.IsAutoEquip(role, trialTag)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil then return false end
    return sv.profiles[role].autoEquip[tostring(trialTag)] == true
end

-- ------------------------------------------------------------- Analisis ----

-- Resuelve una lista de kitIds al formato que espera el motor de coherencia.
function Kits.ResolveKits(kitIds)
    local resolved = {}
    for _, kitId in ipairs(kitIds or {}) do
        local kit = Kits.GetKit(kitId)
        if kit then
            resolved[#resolved + 1] = kit
        end
    end
    return { kits = resolved }
end

-- Atajo: resuelve y analiza los kits asignados a un objetivo.
function Kits.AnalyzeTarget(role, trialTag, targetKey)
    local kitIds = Kits.GetAssignment(role, trialTag, targetKey)
    if not kitIds then return nil end
    if not (EZOArmory.Coherence and EZOArmory.Coherence.Analyze) then return nil end
    return EZOArmory.Coherence.Analyze(Kits.ResolveKits(kitIds))
end
