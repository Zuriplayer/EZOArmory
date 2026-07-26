-- Motor de coherencia (la piedra angular).
--
-- Logica pura: no llama a ninguna API de ESO ni toca SavedVariables. Recibe un
-- loadout ya resuelto (lista de kits con sus slots asignados) y devuelve un
-- informe de incoherencias. Tambien puede contrastar el loadout declarado
-- contra el equipo realmente llevado (snapshot de gear_scanner).
--
-- Un "kit" declara que un set concreto debe ocupar unos slots conceptuales:
--   { name = "Ansuul 5 body", setId = 693, setName = "Ansuul's Torment",
--     slots = { "head", "chest", "shoulders", "waist", "hands" }, maxEquipped = 5 }
--
-- Un "loadout" es un conjunto de kits que en conjunto deberian cubrir la build.

EZOArmory = EZOArmory or {}
EZOArmory.Coherence = EZOArmory.Coherence or {}

local Coherence = EZOArmory.Coherence

-- Universo canonico de slots de una build completa (14 items). El orden es
-- estable. Se deriva de Gear.SLOT_DEFS si esta disponible; si no, cae a esta
-- lista interna equivalente para que el modulo sea autonomo.
local FALLBACK_SLOT_KEYS = {
    "head", "chest", "shoulders", "waist", "hands", "legs", "feet",
    "neck", "ring1", "ring2",
    "main", "off", "backupMain", "backupOff",
}

local function GetCanonicalSlotKeys()
    if EZOArmory.Gear and EZOArmory.Gear.SLOT_DEFS then
        local keys = {}
        for _, def in ipairs(EZOArmory.Gear.SLOT_DEFS) do
            keys[#keys + 1] = def.key
        end
        if #keys > 0 then
            return keys
        end
    end
    return FALLBACK_SLOT_KEYS
end

local function BuildSlotLookup(slotKeys)
    local lookup = {}
    for _, key in ipairs(slotKeys) do
        lookup[key] = true
    end
    return lookup
end

-- Severidades de las incoherencias.
Coherence.SEVERITY = {
    ERROR = "error",     -- rompe la build (conflicto, imposible)
    WARNING = "warning", -- probablemente no deseado (slot sin asignar)
}

local function AddIssue(issues, issue)
    issues[#issues + 1] = issue
end

-- Analiza un loadout declarativo.
--
-- loadout: { kits = { kit, ... } }  (kits ya resueltos, no ids)
-- options (opcional): {
--     expectedSlots = { slotKey, ... },  -- universo a exigir (default: los 14)
--     defaultMax = 5,                    -- tope de piezas si el kit no trae maxEquipped
-- }
--
-- Devuelve:
--   {
--     ok = boolean,                 -- true si no hay issues de severidad ERROR
--     issues = { {type, severity, ...}, ... },
--     slotAssignment = { [slotKey] = { kitName, setId, setName } },  -- primer kit que reclama el slot
--     unassigned = { slotKey, ... },
--   }
function Coherence.Analyze(loadout, options)
    options = options or {}
    local defaultMax = tonumber(options.defaultMax) or 5
    local expectedSlots = options.expectedSlots or GetCanonicalSlotKeys()
    local validSlot = BuildSlotLookup(GetCanonicalSlotKeys())

    local issues = {}
    local slotAssignment = {}
    local kits = (loadout and loadout.kits) or {}

    for _, kit in ipairs(kits) do
        local kitName = tostring(kit.name or "?")
        local slots = kit.slots or {}
        local slotCount = #slots

        -- Kit vacio: no asigna ningun slot.
        if slotCount == 0 then
            AddIssue(issues, {
                type = "emptyKit",
                severity = Coherence.SEVERITY.WARNING,
                kitName = kitName,
                setId = kit.setId,
                setName = kit.setName,
            })
        end

        -- Set sobreasignado: mas slots que su maximo de piezas.
        local kitMax = tonumber(kit.maxEquipped)
        local effectiveMax = kitMax and kitMax > 0 and kitMax or defaultMax
        if slotCount > effectiveMax then
            AddIssue(issues, {
                type = "setOverfill",
                severity = Coherence.SEVERITY.ERROR,
                kitName = kitName,
                setId = kit.setId,
                setName = kit.setName,
                assigned = slotCount,
                maxEquipped = effectiveMax,
            })
        end

        -- Recorre los slots del kit: valida y detecta conflictos.
        for _, slotKey in ipairs(slots) do
            if not validSlot[slotKey] then
                AddIssue(issues, {
                    type = "unknownSlot",
                    severity = Coherence.SEVERITY.ERROR,
                    kitName = kitName,
                    slot = slotKey,
                })
            else
                local existing = slotAssignment[slotKey]
                if existing then
                    AddIssue(issues, {
                        type = "slotConflict",
                        severity = Coherence.SEVERITY.ERROR,
                        slot = slotKey,
                        kitName = kitName,
                        setName = kit.setName,
                        otherKitName = existing.kitName,
                        otherSetName = existing.setName,
                    })
                else
                    slotAssignment[slotKey] = {
                        kitName = kitName,
                        setId = kit.setId,
                        setName = kit.setName,
                    }
                end
            end
        end
    end

    -- Slots sin asignar dentro del universo esperado.
    local unassigned = {}
    for _, slotKey in ipairs(expectedSlots) do
        if not slotAssignment[slotKey] then
            unassigned[#unassigned + 1] = slotKey
            AddIssue(issues, {
                type = "unassignedSlot",
                severity = Coherence.SEVERITY.WARNING,
                slot = slotKey,
            })
        end
    end

    -- ok = sin errores (los warnings no invalidan la build).
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
        slotAssignment = slotAssignment,
        unassigned = unassigned,
    }
end

-- Contrasta un loadout declarado contra el equipo realmente llevado.
--
-- analysis: resultado de Coherence.Analyze (para el slotAssignment esperado).
-- scan: snapshot de EZOArmory.Gear.ScanWorn().
--
-- Devuelve { matches = bool, mismatches = { {slot, expectedSetId, expectedSetName,
--   actualSetId, actualSetName}, ... } }.
function Coherence.CompareToEquipped(analysis, scan)
    local mismatches = {}
    if not analysis or not scan or not scan.slots then
        return { matches = false, mismatches = mismatches }
    end

    for slotKey, expected in pairs(analysis.slotAssignment or {}) do
        local worn = scan.slots[slotKey]
        local actualSetId = worn and worn.setId or 0
        if actualSetId ~= (expected.setId or 0) then
            mismatches[#mismatches + 1] = {
                slot = slotKey,
                expectedSetId = expected.setId or 0,
                expectedSetName = expected.setName or "",
                actualSetId = actualSetId,
                actualSetName = worn and worn.setName or "",
            }
        end
    end

    return { matches = #mismatches == 0, mismatches = mismatches }
end
