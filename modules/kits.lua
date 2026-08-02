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
        icon = tostring(piece.icon or ""),
        armorType = tonumber(piece.armorType),
        weaponType = tonumber(piece.weaponType),
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
    if EZOArmory.Markers then EZOArmory.Markers.Invalidate() end
    return id, kit
end

-- Captura un kit desde el equipo que se lleva puesto ahora mismo.
-- slotKeys: lista de slots a capturar. Si se omite, captura todos los ocupados.
-- Identidad de una pieza para comparar kits: la instancia concreta del item.
-- Con itemId disponible se usa ese; si no, el itemLink como respaldo.
local function PieceIdentity(piece)
    if piece == nil then return nil end
    if piece.itemId and piece.itemId ~= "" then
        return "id:" .. tostring(piece.itemId)
    end
    if piece.itemLink and piece.itemLink ~= "" then
        return "link:" .. tostring(piece.itemLink)
    end
    return nil
end

-- Dos conjuntos de piezas son el mismo kit si cubren exactamente los mismos
-- slots y en cada slot esta la misma instancia de item.
function Kits.PiecesEqual(a, b)
    a = a or {}
    b = b or {}
    for slotKey, piece in pairs(a) do
        if PieceIdentity(piece) ~= PieceIdentity(b[slotKey]) then
            return false
        end
    end
    for slotKey in pairs(b) do
        if a[slotKey] == nil then
            return false
        end
    end
    return true
end

-- Busca un kit existente con exactamente las mismas piezas. Devuelve el kit o nil.
function Kits.FindKitByPieces(pieces)
    local sv = Store()
    if not sv then return nil end
    for _, kit in pairs(sv.kits) do
        if Kits.PiecesEqual(kit.pieces, pieces) then
            return kit
        end
    end
    return nil
end

-- Crea un kit desde el equipo puesto. Si ya existe un kit con exactamente las
-- mismas piezas, NO crea un duplicado: devuelve (nil, kitExistente, "duplicate").
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
                icon = worn.icon,
                armorType = worn.armorType,
                weaponType = worn.weaponType,
                setId = worn.setId,
                setName = worn.setName,
                maxEquipped = worn.maxEquipped,
                twoHand = worn.twoHand,
            }
        end
    end

    local existing = Kits.FindKitByPieces(pieces)
    if existing and next(pieces) ~= nil then
        return nil, existing, "duplicate"
    end

    return Kits.CreateKit(name, pieces, role)
end

-- Extrae una palabra clave corta del nombre completo de un set, quitando la
-- parafernalia habitual. Ej: "Perfected Slivers of the Null Arca" -> "Null Arca".
-- Es una heuristica pensada para nombres en ingles; si no reconoce el patron
-- devuelve el nombre tal cual (el nombre completo se conserva en las piezas).
function Kits.KeywordFromSetName(setName)
    local name = tostring(setName or "")
    -- Quita el prefijo de calidad perfeccionada (EN/ES).
    name = name:gsub("^[Pp]erfected%s+", "")
    name = name:gsub("^[Pp]erfeccionad[oa]s?%s+", "")
    -- Se queda con lo que va tras el ultimo " of the " o " of ".
    local afterOfThe = name:match(".* of the (.+)$")
    if afterOfThe and afterOfThe ~= "" then
        name = afterOfThe
    else
        local afterOf = name:match(".* of (.+)$")
        if afterOf and afterOf ~= "" then
            name = afterOf
        end
    end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return tostring(setName or "")
    end
    return name
end

-- Devuelve los slots de un kit ordenados canonicamente.
function Kits.GetKitSlots(kit)
    local slots = {}
    for slotKey in pairs(kit and kit.pieces or {}) do
        slots[#slots + 1] = slotKey
    end
    if EZOArmory.Gear and EZOArmory.Gear.SortSlots then
        return EZOArmory.Gear.SortSlots(slots)
    end
    table.sort(slots)
    return slots
end

-- Iconos reales de las piezas de un kit, en orden canonico de slot.
function Kits.GetKitIcons(kit)
    local icons = {}
    for _, slotKey in ipairs(Kits.GetKitSlots(kit)) do
        local piece = kit.pieces and kit.pieces[slotKey]
        if piece and piece.icon and piece.icon ~= "" then
            icons[#icons + 1] = piece.icon
        end
    end
    return icons
end

-- Nombre libre: si "base" ya existe, prueba "base 2", "base 3"...
function Kits.UniqueKitName(base, taken)
    base = tostring(base or "kit")
    taken = taken or {}
    if not taken[base] then
        return base
    end
    local index = 2
    while taken[base .. " " .. index] do
        index = index + 1
    end
    return base .. " " .. index
end

-- Crea de una vez un kit por cada bloque que se lleva puesto: cada set de dos o
-- mas piezas y ademas cada pieza suelta (miticos, armas sin set, o una sola
-- pieza de un set). No crea el kit de "todo el equipo".
--
-- nameBuilder(name, slots) es opcional y permite que la capa de interfaz
-- componga un nombre localizado con la ubicacion, por ejemplo
-- "Null Arca - joyeria + armas" o "Slimecraw - Cabeza". Sin el, se usa solo la
-- palabra clave.
--
-- Los nombres repetidos se numeran en vez de saltarse, para no perder capturas
-- en silencio.
--
-- Devuelve (kitIds, creados, reutilizados): la lista incluye TANTO los kits
-- recien creados COMO los que ya existian con exactamente el mismo contenido,
-- porque quien compone una build desde el equipo puesto necesita los ids de
-- todos ellos, no solo de los nuevos. Es la aplicacion del principio de no
-- duplicar lo que ya esta memorizado.
function Kits.CaptureWornAsKits(role, nameBuilder)
    if not (EZOArmory.Gear and EZOArmory.Gear.GetCaptureEntries) then
        return {}, 0, 0
    end

    local taken = {}
    for _, kit in ipairs(Kits.ListKits()) do
        taken[tostring(kit.name)] = true
    end

    local kitIds, created, reused = {}, 0, 0
    for _, entry in ipairs(EZOArmory.Gear.GetCaptureEntries()) do
        if entry.kind == "set" or entry.kind == "slot" then
            local base
            if type(nameBuilder) == "function" then
                local ok, built = pcall(nameBuilder, entry.name, entry.slots, entry)
                if ok and built and built ~= "" then
                    base = built
                end
            end
            base = base or Kits.KeywordFromSetName(entry.name)

            local name = Kits.UniqueKitName(base, taken)
            local id, existing, reason = Kits.CreateKitFromWorn(name, entry.slots, role)
            if id then
                kitIds[#kitIds + 1] = id
                created = created + 1
                taken[name] = true
            elseif reason == "duplicate" and existing then
                kitIds[#kitIds + 1] = existing.id
                reused = reused + 1
            end
        end
    end

    return kitIds, created, reused
end

-- Igual, pero devolviendo solo el recuento (creados, omitidos), que es lo que
-- necesita el panel LAM.
function Kits.CaptureAllSets(role, nameBuilder)
    local _, created, reused = Kits.CaptureWornAsKits(role, nameBuilder)
    return created, reused
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
    if EZOArmory.Markers then EZOArmory.Markers.Invalidate() end
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
    if EZOArmory.Markers then EZOArmory.Markers.Invalidate() end
    return true
end

function Kits.DeleteKit(id)
    local sv = Store()
    if not sv or id == nil or sv.kits[id] == nil then return false end
    sv.kits[id] = nil

    -- Las builds que lo componian dejarian de ser validas en silencio.
    if EZOArmory.Builds and EZOArmory.Builds.ForgetKit then
        EZOArmory.Builds.ForgetKit(id)
    end
    if EZOArmory.Markers then EZOArmory.Markers.Invalidate() end

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

-- Devuelve la lista de kitIds guardada EN un objetivo, sin aplicar herencia.
-- Pensado para editar: refleja lo que hay puesto en ese objetivo concreto (vacio
-- si hereda del default). Filtra kits que ya no existan.
function Kits.GetStoredAssignment(role, trialTag, targetKey)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil or targetKey == nil then
        return {}
    end
    local trial = TrialTable(sv, role, tostring(trialTag), false)
    local stored = trial and trial[tostring(targetKey)]
    if type(stored) ~= "table" then
        return {}
    end
    local result = {}
    for _, kitId in ipairs(stored) do
        if Kits.GetKit(kitId) then
            result[#result + 1] = kitId
        end
    end
    return result
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

-- Construye un conjunto analizable a partir del equipo que se lleva puesto.
-- Sirve para responder "que bonus tengo activos ahora mismo" sin necesidad de
-- tener kits ni asignaciones creadas.
function Kits.BuildLoadoutFromWorn()
    if not (EZOArmory.Gear and EZOArmory.Gear.ScanWorn) then
        return { kits = {} }
    end

    local scan = EZOArmory.Gear.ScanWorn()
    local pieces = {}
    for slotKey, entry in pairs(scan.slots) do
        if entry.hasItem then
            pieces[slotKey] = {
                itemId = entry.itemId,
                itemName = entry.itemName,
                setId = entry.setId,
                setName = entry.setName,
                maxEquipped = entry.maxEquipped,
                twoHand = entry.twoHand,
            }
        end
    end

    return { kits = { { name = "worn", pieces = pieces } } }
end

-- Atajo: resuelve y analiza los kits asignados a un objetivo.
function Kits.AnalyzeTarget(role, trialTag, targetKey)
    local kitIds = Kits.GetAssignment(role, trialTag, targetKey)
    if not kitIds then return nil end
    if not (EZOArmory.Coherence and EZOArmory.Coherence.Analyze) then return nil end
    return EZOArmory.Coherence.Analyze(Kits.ResolveKits(kitIds))
end
