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

-- Posicion completa, solo para las trazas de diagnostico de mas abajo.
local function DescribePosition()
    if type(GetUnitWorldPosition) ~= "function" then
        return "pos=?"
    end
    local zoneId, x, y, z = GetUnitWorldPosition("player")
    return string.format("zone=%s x=%s y=%s z=%s",
        tostring(zoneId), tostring(x), tostring(y), tostring(z))
end

-- Ultima subzona vista (EVENT_ZONE_CHANGED). No se persiste: solo sirve para
-- correlacionar en el log si el cambio de subzona ocurre ANTES de que aparezca
-- la unidad de boss. Ver el bloque de instrumentacion al final del fichero.
local lastSubZoneId = nil
local lastSubZoneName = nil

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
            -- Se registran tambien subzona y posicion para poder decidir con
            -- datos, y no por suposicion, dos cosas: (1) si la sala de un boss
            -- es una subzona propia -- lo que daria un identificador numerico
            -- estable Y un aviso ANTES de entrar en combate, que es lo que hoy
            -- impide equipar a tiempo en un boss que engancha al aparecer; y
            -- (2) las coordenadas reales de cada sala, por si acaba
            -- interesando detectar por posicion (medidas por nosotros, no
            -- copiadas de otro addon).
            EZOArmory.DebugLog(string.format(
                "Bosses changed: active=%s primary=%s matched=%s subzone=%s(%s) %s",
                tostring(Context.state.bossActive),
                tostring(Context.state.primaryBoss),
                tostring(Context.state.matchedBoss and Context.state.matchedBoss.key or nil),
                tostring(lastSubZoneName),
                tostring(lastSubZoneId),
                DescribePosition()
            ))
        end
        FireChanged()
    end
end

-- Instrumentacion de diagnostico: EVENT_ZONE_CHANGED lleva subZoneId, un
-- entero. Si al cruzar la puerta de la sala de un boss llega un subZoneId
-- nuevo, tendriamos identificador estable e independiente del idioma y, sobre
-- todo, aviso anticipado (antes del combate). No cambia ningun comportamiento:
-- solo anota, y DebugLog ya no escribe nada si debugMode esta apagado.
local function OnZoneChangedDetail(_, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
    lastSubZoneId = subZoneId
    lastSubZoneName = subZoneName
    if not EZOArmory.DebugLog then return end

    -- Sin "and/or" aqui a proposito: con IsUnitInCombat devolviendo false, el
    -- atajo caeria en la rama del "?" y el log diria "desconocido" justo en el
    -- caso que interesa medir (llegar a la sala FUERA de combate).
    local inCombat = "?"
    if type(IsUnitInCombat) == "function" then
        inCombat = tostring(IsUnitInCombat("player"))
    end

    EZOArmory.DebugLog(string.format(
        "Zone detail: zone=%s(%s) subzone=%s(%s) new=%s inCombat=%s %s",
        tostring(zoneName), tostring(zoneId),
        tostring(subZoneName), tostring(subZoneId),
        tostring(newSubzone),
        inCombat,
        DescribePosition()
    ))
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
    -- Solo diagnostico (ver OnZoneChangedDetail): no altera el estado publico
    -- ni dispara callbacks, unicamente anota subzona y posicion en el log.
    if type(EVENT_ZONE_CHANGED) ~= "nil" then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ContextZoneDetail", EVENT_ZONE_CHANGED, OnZoneChangedDetail)
    end

    eventsRegistered = true
end
