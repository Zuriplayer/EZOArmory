-- Motor de coherencia (la piedra angular).
--
-- Logica pura: no llama a ninguna API de ESO ni toca SavedVariables. Recibe un
-- conjunto de kits ya resueltos y devuelve un informe.
--
-- Un kit declara piezas concretas por slot:
--   {
--     name = "Arca Nula 5 ropa",
--     pieces = {
--       chest = { itemId = "...", setId = 693, setName = "...", maxEquipped = 5 },
--       ...
--     },
--   }
--
-- Regla fundamental del juego: solo cuentan 12 piezas a la vez. La armadura (7)
-- y la joyeria (3) cuentan siempre; las armas solo en su barra. Por eso el
-- analisis se hace POR BARRA (frontal y trasera), no sobre un unico conjunto.

EZOArmory = EZOArmory or {}
EZOArmory.Coherence = EZOArmory.Coherence or {}

local Coherence = EZOArmory.Coherence

Coherence.SEVERITY = {
    ERROR = "error",     -- rompe la build
    WARNING = "warning", -- probablemente no deseado
}

Coherence.PIECES_PER_BAR = 12

-- Un set con maximo de 1 pieza es un mitico; solo se puede llevar uno.
local MYTHIC_MAX_EQUIPPED = 1

local FALLBACK_BARS = { "front", "back" }

local function GetBars()
    if EZOArmory.Gear and EZOArmory.Gear.BARS then
        return EZOArmory.Gear.BARS
    end
    return FALLBACK_BARS
end

local function GetBarSlotKeys(bar)
    if EZOArmory.Gear and EZOArmory.Gear.GetBarSlotKeys then
        return EZOArmory.Gear.GetBarSlotKeys(bar)
    end
    return {}
end

local function GetSlotDef(slotKey)
    if EZOArmory.Gear and EZOArmory.Gear.GetSlotDef then
        return EZOArmory.Gear.GetSlotDef(slotKey)
    end
    return nil
end

local function AddIssue(issues, issue)
    issues[#issues + 1] = issue
end

-- Reparte las piezas de todos los kits en un mapa slot -> pieza, detectando
-- conflictos (dos kits reclamando el mismo slot) e items repetidos.
local function BuildAssignment(kits, issues)
    local assignment = {}
    local itemOwners = {}

    for _, kit in ipairs(kits) do
        local kitName = tostring(kit.name or "?")
        local pieces = kit.pieces or {}
        local pieceCount = 0

        for slotKey, piece in pairs(pieces) do
            pieceCount = pieceCount + 1

            if GetSlotDef(slotKey) == nil then
                AddIssue(issues, {
                    type = "unknownSlot",
                    severity = Coherence.SEVERITY.ERROR,
                    kitName = kitName,
                    slot = slotKey,
                })
            else
                local existing = assignment[slotKey]
                if existing then
                    AddIssue(issues, {
                        type = "slotConflict",
                        severity = Coherence.SEVERITY.ERROR,
                        slot = slotKey,
                        kitName = kitName,
                        setName = piece.setName,
                        otherKitName = existing.kitName,
                        otherSetName = existing.setName,
                    })
                else
                    assignment[slotKey] = {
                        kitName = kitName,
                        itemId = piece.itemId,
                        itemName = piece.itemName,
                        -- icon/armorType/weaponType se arrastran para que la
                        -- interfaz pueda pintar y describir la pieza asignada
                        -- (y para el rol automatico de una build) sin volver a
                        -- buscar el kit de origen.
                        icon = piece.icon or "",
                        armorType = tonumber(piece.armorType),
                        weaponType = tonumber(piece.weaponType),
                        setId = tonumber(piece.setId) or 0,
                        setName = piece.setName or "",
                        maxEquipped = tonumber(piece.maxEquipped) or 0,
                        twoHand = piece.twoHand == true,
                    }
                end

                -- El mismo item fisico no puede ocupar dos slots a la vez.
                local itemId = piece.itemId
                if itemId then
                    local owner = itemOwners[itemId]
                    if owner then
                        AddIssue(issues, {
                            type = "duplicateItem",
                            severity = Coherence.SEVERITY.ERROR,
                            itemId = itemId,
                            itemName = piece.itemName,
                            slot = slotKey,
                            otherSlot = owner,
                        })
                    else
                        itemOwners[itemId] = slotKey
                    end
                end
            end
        end

        if pieceCount == 0 then
            AddIssue(issues, {
                type = "emptyKit",
                severity = Coherence.SEVERITY.WARNING,
                kitName = kitName,
            })
        end
    end

    return assignment
end

-- Analiza una barra: cuenta piezas por set, detecta huecos y sobreasignacion.
local function AnalyzeBar(bar, assignment, issues)
    local slotKeys = GetBarSlotKeys(bar)
    local sets = {}
    local unassigned = {}
    local totalPieces = 0
    local skip = {}

    -- Primera pasada: un arma a dos manos ocupa su slot y anula el secundario.
    for _, slotKey in ipairs(slotKeys) do
        local entry = assignment[slotKey]
        local def = GetSlotDef(slotKey)
        if entry and entry.twoHand and def and def.pairSlot then
            skip[def.pairSlot] = true
        end
    end

    for _, slotKey in ipairs(slotKeys) do
        local entry = assignment[slotKey]

        if entry then
            -- Un arma a dos manos cuenta como dos piezas del set.
            local weight = entry.twoHand and 2 or 1
            totalPieces = totalPieces + weight

            if entry.setId ~= 0 then
                local bucket = sets[entry.setId]
                if not bucket then
                    bucket = {
                        setId = entry.setId,
                        setName = entry.setName,
                        maxEquipped = entry.maxEquipped,
                        count = 0,
                        slots = {},
                    }
                    sets[entry.setId] = bucket
                end
                bucket.count = bucket.count + weight
                bucket.slots[#bucket.slots + 1] = slotKey
            end
        elseif not skip[slotKey] then
            unassigned[#unassigned + 1] = slotKey
            AddIssue(issues, {
                type = "unassignedSlot",
                severity = Coherence.SEVERITY.WARNING,
                bar = bar,
                slot = slotKey,
            })
        end
    end

    -- Un set no puede aportar mas piezas de las que admite.
    for _, bucket in pairs(sets) do
        if bucket.maxEquipped > 0 and bucket.count > bucket.maxEquipped then
            AddIssue(issues, {
                type = "setOverfill",
                severity = Coherence.SEVERITY.ERROR,
                bar = bar,
                setId = bucket.setId,
                setName = bucket.setName,
                count = bucket.count,
                maxEquipped = bucket.maxEquipped,
            })
        end
        bucket.complete = bucket.maxEquipped > 0 and bucket.count >= bucket.maxEquipped
    end

    if totalPieces < Coherence.PIECES_PER_BAR then
        AddIssue(issues, {
            type = "barIncomplete",
            severity = Coherence.SEVERITY.WARNING,
            bar = bar,
            pieces = totalPieces,
            expected = Coherence.PIECES_PER_BAR,
        })
    end

    return {
        bar = bar,
        sets = sets,
        unassigned = unassigned,
        pieces = totalPieces,
    }
end

-- Un unico mitico por personaje (los miticos son sets de 1 pieza).
local function CheckMythics(assignment, issues)
    local mythics = {}
    local seen = {}
    for slotKey, entry in pairs(assignment) do
        if entry.maxEquipped == MYTHIC_MAX_EQUIPPED and entry.setId ~= 0 and not seen[entry.setId] then
            seen[entry.setId] = true
            mythics[#mythics + 1] = { slot = slotKey, setId = entry.setId, setName = entry.setName }
        end
    end

    if #mythics > 1 then
        AddIssue(issues, {
            type = "multipleMythics",
            severity = Coherence.SEVERITY.ERROR,
            mythics = mythics,
        })
    end

    return mythics
end

-- Analiza un conjunto de kits.
--
-- loadout: { kits = { kit, ... } }
--
-- Devuelve:
--   {
--     ok,                     -- sin incidencias de severidad ERROR
--     issues,                 -- lista de incidencias
--     assignment,             -- slot -> pieza asignada
--     bars = { front = {...}, back = {...} },  -- recuento por barra
--     mythics,
--   }
--
-- Nota de diseno: que un set no llegue a su maximo en una barra NO se considera
-- incidencia. Es lo normal (un set de joyeria y armas frontales queda a 3 en la
-- barra trasera de forma intencionada). El recuento por barra se devuelve como
-- dato para que la interfaz lo muestre y el jugador juzgue.
function Coherence.Analyze(loadout)
    local issues = {}
    local kits = (loadout and loadout.kits) or {}

    local assignment = BuildAssignment(kits, issues)
    local mythics = CheckMythics(assignment, issues)

    local bars = {}
    for _, bar in ipairs(GetBars()) do
        bars[bar] = AnalyzeBar(bar, assignment, issues)
    end

    local ok = true
    for _, issue in ipairs(issues) do
        if issue.severity == Coherence.SEVERITY.ERROR then
            ok = false
            break
        end
    end

    return {
        ok = ok,
        issues = issues,
        assignment = assignment,
        bars = bars,
        mythics = mythics,
    }
end

-- Comprueba que las piezas del analisis estan disponibles para equipar.
-- locationIndex viene de EZOArmory.Gear.BuildItemLocationIndex().
function Coherence.CheckAvailability(analysis, locationIndex)
    local missing = {}
    if not analysis or not locationIndex then
        return { available = false, missing = missing }
    end

    for slotKey, entry in pairs(analysis.assignment or {}) do
        if entry.itemId and locationIndex[entry.itemId] == nil then
            missing[#missing + 1] = {
                slot = slotKey,
                itemId = entry.itemId,
                itemName = entry.itemName,
                setName = entry.setName,
            }
        end
    end

    return { available = #missing == 0, missing = missing }
end

-- Contrasta el conjunto declarado contra lo que se lleva puesto ahora mismo.
-- scan viene de EZOArmory.Gear.ScanWorn().
function Coherence.CompareToEquipped(analysis, scan)
    local mismatches = {}
    if not analysis or not scan or not scan.slots then
        return { matches = false, mismatches = mismatches }
    end

    for slotKey, expected in pairs(analysis.assignment or {}) do
        local worn = scan.slots[slotKey]
        local wornItemId = worn and worn.itemId or nil
        if wornItemId ~= expected.itemId then
            mismatches[#mismatches + 1] = {
                slot = slotKey,
                expectedItemId = expected.itemId,
                expectedItemName = expected.itemName,
                expectedSetName = expected.setName,
                actualItemName = worn and worn.itemName or "",
                actualSetName = worn and worn.setName or "",
            }
        end
    end

    return { matches = #mismatches == 0, mismatches = mismatches }
end
