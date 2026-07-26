-- Seguimiento del contexto en vivo: zona (trial o no) y boss actual.
--
-- APIs de ESO usadas (verificadas contra uso real en la familia EZO / LibCombat):
--   GetUnitWorldPosition("player") -> zoneId (primer valor de retorno)
--   EVENT_PLAYER_ACTIVATED         -> cambio de zona
--   EVENT_BOSSES_CHANGED           -> cambio de bosses
--   DoesUnitExist("bossN") / GetUnitName("bossN") / IsUnitInCombat("player")
--   BOSS_RANK_ITERATION_END        -> numero maximo de tags de boss (fallback 6)
--
-- Modulo defensivo: todas las globales de ESO se comprueban antes de usarse,
-- para que el fichero cargue sin romper incluso fuera del cliente (luacheck).

EZOArmory = EZOArmory or {}
EZOArmory.Context = EZOArmory.Context or {}

local Context = EZOArmory.Context
local Zones = EZOArmory.Zones

local ADDON_NAME = "EZOArmory"

-- Estado publico observable. No reasignar la tabla; se muta en el sitio.
Context.state = Context.state or {
    zoneId = 0,
    trial = nil,        -- tabla de Zones.TRIALS o nil si no es trial
    inTrial = false,
    bossActive = false, -- hay al menos un boss presente (sirve fuera de trials)
    bossNames = {},     -- lista de nombres de boss presentes (idioma del cliente)
    primaryBoss = nil,  -- primer nombre de boss no vacio
    matchedBoss = nil,  -- {key, name} de la trial si el nombre coincide, o nil
}

local callbacks = {}
local eventsRegistered = false

-- Registro de observadores internos del addon (no usa EZOCore: es especifico).
function Context.RegisterCallback(fn)
    if type(fn) ~= "function" then return false end
    callbacks[#callbacks + 1] = fn
    return true
end

local function FireChanged()
    for _, fn in ipairs(callbacks) do
        pcall(fn, Context.state)
    end
end

local function GetCurrentZoneId()
    if type(GetUnitWorldPosition) ~= "function" then
        return 0
    end
    local zoneId = GetUnitWorldPosition("player")
    return tonumber(zoneId) or 0
end

local function CollectBossNames()
    local names = {}
    if type(GetUnitName) ~= "function" then
        return names
    end

    local maxBosses = (type(BOSS_RANK_ITERATION_END) == "number" and BOSS_RANK_ITERATION_END) or 6
    for index = 1, maxBosses do
        local unitTag = "boss" .. tostring(index)
        local exists = type(DoesUnitExist) ~= "function" or DoesUnitExist(unitTag)
        if exists then
            local name = GetUnitName(unitTag)
            if name and name ~= "" then
                names[#names + 1] = name
            end
        end
    end
    return names
end

-- Recalcula el estado de zona a partir del zoneId actual.
local function RefreshZone()
    local zoneId = GetCurrentZoneId()
    Context.state.zoneId = zoneId
    Context.state.trial = Zones and Zones.GetTrialByZoneId(zoneId) or nil
    Context.state.inTrial = Context.state.trial ~= nil
end

-- Recalcula el estado de boss. Devuelve true si cambio algo relevante.
local function RefreshBoss()
    local names = CollectBossNames()
    local primary = names[1]
    local changed = false

    if primary ~= Context.state.primaryBoss then
        changed = true
    end
    if (#names > 0) ~= Context.state.bossActive then
        changed = true
    end

    Context.state.bossNames = names
    Context.state.bossActive = #names > 0
    Context.state.primaryBoss = primary

    -- Resolucion a boss conocido de la trial (mejor esfuerzo). Los nombres de la
    -- tabla estan en ingles; en cliente no-ingles la coincidencia exacta puede
    -- fallar y matchedBoss quedara nil, pero bossActive sigue siendo fiable.
    local matched = nil
    if Context.state.trial and primary and Zones then
        matched = Zones.FindBossByName(Context.state.trial, primary)
    end
    if matched ~= Context.state.matchedBoss then
        changed = true
    end
    Context.state.matchedBoss = matched

    return changed
end

local function OnZoneChanged()
    local previousZone = Context.state.zoneId
    RefreshZone()
    if Context.state.zoneId ~= previousZone then
        -- Al cambiar de zona, reevalua bosses (limpia estado anterior).
        RefreshBoss()
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "Zone changed: %d (%s)",
                Context.state.zoneId,
                Context.state.trial and Context.state.trial.tag or "non-trial"
            ))
        end
        FireChanged()
    end
end

local function OnBossesChanged()
    if RefreshBoss() then
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "Bosses changed: active=%s primary=%s",
                tostring(Context.state.bossActive),
                tostring(Context.state.primaryBoss)
            ))
        end
        FireChanged()
    end
end

-- API publica de consulta.
function Context.GetState()
    return Context.state
end

function Context.GetZoneId()
    return Context.state.zoneId
end

function Context.GetTrial()
    return Context.state.trial
end

function Context.IsInTrial()
    return Context.state.inTrial == true
end

function Context.IsBossActive()
    return Context.state.bossActive == true
end

function Context.GetPrimaryBossName()
    return Context.state.primaryBoss
end

function Context.GetMatchedBoss()
    return Context.state.matchedBoss
end

function Context.Init()
    if eventsRegistered or type(EVENT_MANAGER) ~= "userdata" and type(EVENT_MANAGER) ~= "table" then
        -- Sin EVENT_MANAGER no hay entorno de juego; deja el estado por defecto.
        if not eventsRegistered then
            RefreshZone()
        end
        return
    end

    -- Estado inicial.
    RefreshZone()
    RefreshBoss()

    if type(EVENT_PLAYER_ACTIVATED) ~= "nil" then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ContextZone", EVENT_PLAYER_ACTIVATED, OnZoneChanged)
    end
    if type(EVENT_BOSSES_CHANGED) ~= "nil" then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ContextBoss", EVENT_BOSSES_CHANGED, OnBossesChanged)
    end

    eventsRegistered = true
end
