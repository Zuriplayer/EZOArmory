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
    bossTier = nil,     -- "mini" | "boss" segun GetUnitDifficulty, o nil
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


-- Contenido instanciado: trial, arena o mazmorra. Es donde el juego declara
-- unidades bossN de forma fiable, y por tanto donde el catalogo automatico
-- tiene sentido. El mundo abierto queda fuera a proposito: alli marca como
-- boss cosas que no lo son y el catalogo se llenaria de ruido.

-- Archivo Infinito. Se pregunta al juego con IsInstanceEndlessDungeon(), que
-- es API oficial (verificada en ESOUIDocumentation.txt y usada por el propio
-- juego en ingame/endlessdungeon/endlessdungeonmanager.lua:175), en vez de
-- comparar contra el zoneId 1436 a mano: asi sigue valiendo si manana anaden
-- otro archivo.
--
-- Alli NO se memoriza nada, ni bosses ni salas, y es deliberado:
--
--   - Es contenido procedural. Los bosses salen de una baraja y las salas se
--     recombinan en cada partida, asi que una posicion aprendida hoy no
--     significa nada manana: reconoceria una sala donde no esta.
--   - Y no hace falta. Lo unico que cambia lo que hay que llevar puesto es si
--     delante tienes trash, un mini o un boss, y eso el juego ya lo dice en
--     vivo: lo marca con un tag bossN y GetUnitDifficulty da el nivel. El
--     nombre concreto del boss no aporta nada cuando no se repite.
--
-- O sea que el Archivo Infinito funciona con las builds sustitutas de trash,
-- mini y boss, sin catalogo y sin que haya que configurar nada por boss.
--
-- El juego ofrece ademas el contador de progreso (GetEndlessDungeonCounterValue
-- con ENDLESS_DUNGEON_COUNTER_TYPE_STAGE / _CYCLE / _ARC) por si algun dia
-- hiciera falta saber en que punto de la partida estas. Hoy no hace falta:
-- el tag bossN llega igual y es mas directo.
local function IsEndlessArchive()
    if type(IsInstanceEndlessDungeon) ~= "function" then return false end
    local ok, isEndless = pcall(IsInstanceEndlessDungeon)
    return ok and isEndless == true
end
--
-- IsUnitInDungeon + IsPlayerInRaid es la pareja que usa Wizard's Wardrobe en
-- produccion (modules/WizardsWardrobeFood.lua:25); ambas verificadas en
-- ESOUIDocumentation.txt. Se acepta ademas cualquier zona de nuestra propia
-- tabla como red de seguridad, por si alguna arena no contara como mazmorra
-- para el juego.
local function IsInstancedContent()
    if Context.state.trial ~= nil then
        return true
    end
    if type(IsUnitInDungeon) == "function" then
        local ok, inDungeon = pcall(IsUnitInDungeon, "player")
        if ok and inDungeon then return true end
    end
    if type(IsPlayerInRaid) == "function" then
        local ok, inRaid = pcall(IsPlayerInRaid)
        if ok and inRaid then return true end
    end
    return false
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

    -- En una zona que no esta en la tabla (mazmorra), el boss se resuelve
    -- contra lo que el catalogo haya aprendido de ella. Sin esto, matchedBoss
    -- quedaba nil en mazmorras y solo se reconocia el boss por posicion, que
    -- es un camino mas lento y que no siempre llega: hay salas que aun no se
    -- han aprendido.
    if not matched and primary and Zones and Zones.GetZoneKey
        and Zones.DiscoveredKeyFor then
        local zoneKey = Zones.GetZoneKey(Context.state.zoneId)
        local known = zoneKey and Zones.GetDiscoveredBosses
            and Zones.GetDiscoveredBosses(zoneKey) or {}
        for _, boss in ipairs(known) do
            if boss.name == primary then
                matched = boss
                break
            end
        end
    end

    -- ------------------------------------------- Catalogo automatico ----
    --
    -- Todo boss que aparezca en contenido instanciado se apunta solo, con el
    -- nombre EXACTO que da este cliente y con su nivel (mini o boss) leido del
    -- motor. Sin pulsar nada y sin recargar: la tabla se puebla jugando.
    --
    -- Antes esto solo pasaba dentro de las 18 trials y arenas de la tabla,
    -- porque el catalogo se indexaba por su "tag" y una mazmorra no tenia
    -- clave donde guardarse. Ahora cualquier zona instanciada tiene la suya
    -- (Zones.GetZoneKey), asi que las mazmorras tambien aprenden.
    --
    -- Se descubren TODOS los bosses presentes, no solo el primero: en un
    -- encuentro de varios, los demas se perdian.
    local zoneKey = Zones and Zones.GetZoneKey and Zones.GetZoneKey(Context.state.zoneId)
    if Context.state.bossActive and zoneKey and Zones and Zones.DiscoverBoss
        and IsInstancedContent() and not IsEndlessArchive() then
        local maxBosses = (type(BOSS_RANK_ITERATION_END) == "number" and BOSS_RANK_ITERATION_END) or 6
        for index = 1, maxBosses do
            local unitTag = "boss" .. tostring(index)
            local name = DoesUnitExist(unitTag) and GetUnitName(unitTag) or nil
            if name and name ~= "" then
                -- El nivel se lee de ESA unidad, no de boss1: hay encuentros
                -- donde boss1 ni existe (Crutch documenta que Felms y Llothis
                -- son los dos "boss2"), y leerlo del tag equivocado da un
                -- nivel inventado.
                local tier = Zones.GetBossTierForUnit(unitTag)
                if Zones.DiscoverBoss(zoneKey, name, tier, Context.state.zoneId) then
                    -- Solo cuando es NUEVO de verdad, no en cada encuentro:
                    -- descubrir un boss pasa pocas veces por sesion, asi que
                    -- una linea avisa de que el catalogo funciona sin llegar
                    -- a molestar.
                    Zones.Announce(zo_strformat(GetString(EZOARM_MSG_BOSS_LEARNED),
                        tostring(name), Zones.GetTierLabel(tier),
                        Zones.GetZoneLabel(zoneKey, Context.state.zoneId)))
                end

                -- APRENDIZAJE AUTOMATICO DE LA SALA, para CUALQUIER boss y no
                -- solo para los que ya estaban en la tabla. Antes se exigia
                -- "matched", asi que los recien descubiertos -justo los que
                -- mas falta les hace- no aprendian su posicion nunca.
                --
                -- Cuando el encuentro se activa ya sueles estar dentro de la
                -- sala (a menudo en combate, que es el problema de fondo), asi
                -- que esa posicion sirve de centro. Solo se aprende si no
                -- habia nada guardado: la del primer avistamiento vale tanto
                -- como cualquiera, y reescribirla cada vez haria que el centro
                -- fuese saltando segun donde estuvieras al entrar.
                local bossKey = Zones.DiscoveredKeyFor and Zones.DiscoveredKeyFor(name)
                if bossKey and Zones.LearnBossRoom and Zones.GetBossRoom
                    and not Zones.GetBossRoom(zoneKey, bossKey)
                    and type(GetUnitWorldPosition) == "function" then
                    local ok, _, px, py, pz = pcall(GetUnitWorldPosition, "player")
                    if ok and px then
                        Zones.LearnBossRoom(zoneKey, bossKey, px, py, pz)
                        if EZOArmory.DebugLog then
                            EZOArmory.DebugLog(string.format(
                                "Boss room learned: %s/%s at %s,%s,%s",
                                tostring(zoneKey), tostring(bossKey),
                                tostring(px), tostring(py), tostring(pz)))
                        end
                    end
                end
            end
        end
    end

    if matched ~= Context.state.matchedBoss then
        changed = true
    end
    Context.state.matchedBoss = matched

    -- Nivel del boss presente, para poder resolver los objetivos genericos
    -- "mini" y "boss" aunque no haya asignacion para ese boss concreto.
    --
    -- Se lee del PRIMER TAG QUE EXISTA, no de "boss1" a secas. Hay encuentros
    -- donde boss1 no existe en absoluto y el primero es boss2 -- CrutchAlerts
    -- lo documenta con Felms y Llothis, y por eso usa GetFirstValidBossTag en
    -- vez de boss1. Leyendo de un tag inexistente, el nivel salia inventado y
    -- la build de mini o de boss se elegia mal sin dar ningun error.
    if Context.state.bossActive and Zones and Zones.GetBossTierForUnit then
        local tierTag = nil
        local maxBosses = (type(BOSS_RANK_ITERATION_END) == "number" and BOSS_RANK_ITERATION_END) or 6
        for index = 1, maxBosses do
            local candidate = "boss" .. tostring(index)
            if DoesUnitExist(candidate) then
                tierTag = candidate
                break
            end
        end
        Context.state.bossTier = (matched and matched.tier)
            or (tierTag and Zones.GetBossTierForUnit(tierTag))
    else
        Context.state.bossTier = nil
    end

    return changed
end

-- ------------------------------------- Deteccion por posicion ----
--
-- Sondeo cada 2 s de la posicion del jugador contra las salas aprendidas, para
-- reconocer el boss ANTES de que el encuentro se active. Mismo intervalo y
-- misma politica que Wizard's Wardrobe (zones/LC.lua): el bucle se PARA en
-- combate y se reanuda al salir, porque en combate no se puede cambiar nada y
-- comprobarlo no sirve de nada.
--
-- A diferencia de WW, esto NO sustituye a EVENT_BOSSES_CHANGED: lo complementa.
-- WW llega a desactivar el evento en las zonas con cajas; aqui el evento sigue
-- siendo la red de seguridad para salas que aun no se han aprendido.
local POSITION_POLL_MS = 2000
local positionLoopName = ADDON_NAME .. "_RoomPoll"
local positionLoopRunning = false

local function CheckRoomByPosition()
    if not Zones then return end
    -- Con el encuentro ya activo manda el evento: es mas fiable que la
    -- posicion y no hay que pisarlo.
    if Context.state.bossActive then return end
    if type(GetUnitWorldPosition) ~= "function" then return end

    local ok, _, x, y, z = pcall(GetUnitWorldPosition, "player")
    if not ok or not x then return end

    -- Dos caminos, segun la zona este o no en la tabla. En las conocidas se
    -- buscan sus bosses declarados; en una mazmorra no hay lista que recorrer,
    -- asi que se van a ver las salas aprendidas de esa zona. Sin esto, las
    -- salas que ahora se aprenden en mazmorras no las consultaria nadie.
    local zone = Context.state.trial
    local matched
    local label
    if zone and Zones.FindBossByPosition then
        matched = Zones.FindBossByPosition(zone, x, y, z)
        label = zone.tag
    elseif Zones.FindBossByPositionInZone and Zones.GetZoneKey then
        label = Zones.GetZoneKey(Context.state.zoneId)
        matched = label and Zones.FindBossByPositionInZone(label, x, y, z)
    end

    if matched == Context.state.matchedBoss then return end

    Context.state.matchedBoss = matched
    -- El nivel tambien sale de la sala reconocida: es lo que permite equipar
    -- la build de mini o de boss ANTES de que empiece el encuentro, que es
    -- todo el objetivo de reconocer por posicion.
    Context.state.bossTier = matched and matched.tier or nil
    if EZOArmory.DebugLog then
        EZOArmory.DebugLog(string.format(
            "Room by position: %s (zona %s)",
            tostring(matched and matched.key or nil), tostring(label)))
    end
    FireChanged()
end

local function StopPositionLoop()
    if not positionLoopRunning then return end
    positionLoopRunning = false
    EVENT_MANAGER:UnregisterForUpdate(positionLoopName)
end

local function StartPositionLoop()
    if positionLoopRunning then return end
    -- Dentro de contenido instanciado, sea o no una de las zonas de la tabla:
    -- en mazmorras tambien se aprenden salas ahora, y si el bucle solo
    -- arrancara en las conocidas nadie las consultaria. En mundo abierto no se
    -- aprende nada, asi que ahi no hay nada que reconocer y el bucle sobra.
    if not IsInstancedContent() then return end
    -- En el Archivo Infinito no se aprenden salas, asi que no hay ninguna que
    -- reconocer y el sondeo solo gastaria.
    if IsEndlessArchive() then return end
    if type(IsUnitInCombat) == "function" and IsUnitInCombat("player") then return end
    positionLoopRunning = true
    EVENT_MANAGER:RegisterForUpdate(positionLoopName, POSITION_POLL_MS, CheckRoomByPosition)
end

local function OnCombatStateChanged(_, inCombat)
    if inCombat then
        StopPositionLoop()
    else
        StartPositionLoop()
    end
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

    -- El sondeo de salas solo corre dentro de zonas conocidas.
    if Context.state.trial then
        StartPositionLoop()
    else
        StopPositionLoop()
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

    -- El sondeo de salas se para en combate y se reanuda al salir, igual que
    -- hace WW: en combate no se puede equipar nada, asi que comprobar la
    -- posicion no aporta y solo gasta.
    if type(EVENT_PLAYER_COMBAT_STATE) ~= "nil" then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ContextCombat",
            EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    end

    -- Arranque: si ya estas dentro de una zona conocida al cargar.
    StartPositionLoop()

    eventsRegistered = true
end
