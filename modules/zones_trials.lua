-- Datos de referencia de las trials del juego y sus bosses.
--
-- No llama a ninguna API de ESO (solo lee/escribe la tabla de SavedVariables).
-- La deteccion en vivo (zona actual, boss bajo combate) vive en
-- context_tracker.lua, que resuelve GetUnitName("boss1".."boss6") a un boss de
-- esta tabla con Z.FindBossByName.
--
-- "key" es el identificador estable y minusculo con el que se guardan las
-- asignaciones en SavedVariables. NO depende del idioma ni del nombre: es lo
-- unico que se persiste como identidad del boss.
--
-- COMO SE IDENTIFICA UN BOSS (y por que asi):
--
-- El motor NO expone ningun ID persistente de NPC. No existe
-- GetUnitId(unitTag) ni un monsterId; los unitId de EVENT_COMBAT_EVENT son de
-- sesion (se reasignan en cada spawn), asi que no sirven para guardar nada.
-- Lo unico estable que da el motor por unitTag es el nombre... ya localizado
-- al idioma del cliente. Verificado contra ESOUIDocumentation.txt.
--
-- Wizard's Wardrobe resuelve esto comparando localizado contra localizado: el
-- nombre que devuelve GetUnitName() contra el que el usuario eligio de un
-- desplegable que tambien sale de su lang/<idioma>.lua. Nunca cruza idiomas.
-- El precio que paga es que su identificador guardado ES el nombre
-- localizado, asi que cambiar el idioma del cliente deja sus condiciones
-- huerfanas.
--
-- Aqui se hace lo mismo pero conservando la key estable: el nombre real que
-- devuelve ESTE cliente se APRENDE (boton "aprender" de la pestana Assign,
-- Z.LearnBossName) y se guarda asociado a la key, no en su lugar. Cambiar el
-- idioma del juego no invalida ninguna asignacion; como mucho hay que volver
-- a aprender el nombre.
--
-- "name" (ingles) y "nameEs" (espanol, verificado contra el lang/es.lua de
-- Wizard's Wardrobe en produccion) son solo el valor inicial, para que la
-- deteccion funcione de entrada sin tener que aprender nada. Lo aprendido
-- tiene prioridad sobre ambos.
--
-- Sin nameEs verificado (ni WW lo tiene): "Arcane Knot" (LC) y los seis de
-- Ossein Cage. Esos hay que aprenderlos con el boton si el cliente no esta en
-- ingles - que es justamente para lo que existe.

EZOArmory = EZOArmory or {}
EZOArmory.Zones = EZOArmory.Zones or {}
local Z = EZOArmory.Zones

-- Ordenadas por antiguedad de lanzamiento (order = prioridad clasica).
Z.TRIALS = {
    {
        tag = "AA", zoneId = 638, order = 1, name = "Aetherian Archive",
        bosses = {
            { key = "stormatro", name = "Lightning Storm Atronach", nameEs = "Atronach tormenta de relámpagos" },
            { key = "stoneatro", name = "Foundation Stone Atronach", nameEs = "Atronach de piedra fundamental" },
            { key = "varlariel", name = "Varlariel" },
            { key = "mage", name = "The Mage", nameEs = "El Mago" },
        },
    },
    {
        tag = "SO", zoneId = 639, order = 2, name = "Sanctum Ophidia",
        bosses = {
            { key = "mantikora", name = "Possessed Mantikora", nameEs = "Manticora poseída" },
            { key = "stonebreaker", name = "Stonebreaker", nameEs = "Rompedor de piedras" },
            { key = "ozara", name = "Ozara" },
            { key = "serpent", name = "The Serpent", nameEs = "La Serpiente" },
        },
    },
    {
        tag = "HRC", zoneId = 636, order = 3, name = "Hel Ra Citadel",
        bosses = {
            { key = "rakotu", name = "Ra Kotu" },
            { key = "yokeda_rokdun", name = "Yokeda Rok'dun" },
            { key = "yokeda_kai", name = "Yokeda Kai" },
            { key = "warrior", name = "The Warrior", nameEs = "El Guerrero" },
        },
    },
    {
        tag = "MOL", zoneId = 725, order = 4, name = "Maw of Lorkhaj",
        bosses = {
            { key = "zhajhassa", name = "Zhaj'hassa the Forgotten", nameEs = "Zhaj'hassa el Olvidado" },
            { key = "twins", name = "Twins", nameEs = "Gemelos" },
            { key = "rakkhat", name = "Rakkhat" },
        },
    },
    {
        tag = "HOF", zoneId = 975, order = 5, name = "Halls of Fabrication",
        bosses = {
            { key = "hunterkiller", name = "Hunter-Killer Negatrix", nameEs = "Cazador-Asesino Negatrix" },
            { key = "factotum", name = "Pinnacle Factotum", nameEs = "Factótum del pináculo" },
            { key = "archcustodian", name = "Archcustodian", nameEs = "Arcucustodio" },
            { key = "reactor", name = "Reactor" },
            { key = "general", name = "Assembly General", nameEs = "General de la Asamblea" },
        },
    },
    {
        tag = "AS", zoneId = 1000, order = 6, name = "Asylum Sanctorium",
        bosses = {
            { key = "felms", name = "Saint Felms the Bold", nameEs = "San Felms el Audaz" },
            { key = "llothis", name = "Saint Llothis the Pious", nameEs = "San Llothis el Piadoso" },
            { key = "olms", name = "Saint Olms the Just", nameEs = "San Olms el Justo" },
        },
    },
    {
        tag = "CR", zoneId = 1051, order = 7, name = "Cloudrest",
        bosses = {
            { key = "zmaja", name = "Z'Maja" },
            { key = "galenwe", name = "Shade of Galenwe", nameEs = "Sombra de Galenwe" },
            { key = "siroria", name = "Shade of Siroria", nameEs = "Sombra de Siroria" },
            { key = "relequen", name = "Shade of Relequen", nameEs = "Sombra de Relequen" },
        },
    },
    {
        tag = "SS", zoneId = 1121, order = 8, name = "Sunspire",
        bosses = {
            { key = "lokkestiiz", name = "Lokkestiiz" },
            { key = "yolnahkriin", name = "Yolnahkriin" },
            { key = "nahviintaas", name = "Nahviintaas" },
        },
    },
    {
        tag = "KA", zoneId = 1196, order = 9, name = "Kyne's Aegis",
        bosses = {
            { key = "yandir", name = "Yandir the Butcher", nameEs = "Yandir el Carnicero" },
            { key = "vrol", name = "Captain Vrol", nameEs = "Capitán Vrol" },
            { key = "falgravn", name = "Lord Falgravn" },
        },
    },
    {
        tag = "RG", zoneId = 1263, order = 10, name = "Rockgrove",
        bosses = {
            { key = "oaxiltso", name = "Oaxiltso" },
            { key = "bahsei", name = "Flame-Herald Bahsei", nameEs = "Bahsei, heraldo de las llamas" },
            { key = "xalvakka", name = "Xalvakka" },
            -- Minibosses. Sin ellos se resolvian como "trash" y recibian la
            -- build de trash en vez de la de boss.
            { key = "basks_in_snakes", name = "Basks-In-Snakes", nameEs = "Disfrutador de serpientes" },
            { key = "ash_titan", name = "Ash Titan", nameEs = "Titán de cenizas" },
        },
    },
    {
        tag = "DSR", zoneId = 1344, order = 11, name = "Dreadsail Reef",
        bosses = {
            -- La unidad boss1 se llama solo "Lylanar" (igual en ingles y en
            -- espanol); "Lylanar and Turlassil" es el nombre del encuentro,
            -- no el de la unidad. Por eso van separados: "name" es contra lo
            -- que se compara GetUnitName y "label" es lo que se muestra. WW
            -- hace la misma distincion (name vs displayName). Antes se
            -- comparaba contra el nombre del encuentro y este boss no se
            -- detectaba nunca, en ningun idioma.
            { key = "lylanar_turlassil", name = "Lylanar", label = "Lylanar and Turlassil" },
            { key = "reef_guardian", name = "Reef Guardian", nameEs = "Guardián del arrecife" },
            { key = "taleria", name = "Tideborn Taleria", nameEs = "Taleria Nacida de las mareas" },
            -- Minibosses. Sin ellos se resolvian como "trash" y recibian la
            -- build de trash en vez de la de boss.
            { key = "sail_ripper", name = "Sail Ripper", nameEs = "Desgarrador de velas" },
            -- OJO: WW traduce Bow Breaker como "Rompecorazones", que no cuadra
            -- con el nombre en ingles y podria ser un error suyo. Se deja por
            -- si acierta (una cadena que no case no hace dano), pero es el
            -- candidato numero uno a corregir con el boton "aprender este boss".
            { key = "bow_breaker", name = "Bow Breaker", nameEs = "Rompecorazones" },
        },
    },
    {
        tag = "SE", zoneId = 1427, order = 12, name = "Sanity's Edge",
        bosses = {
            { key = "descender", name = "Spiral Descender", nameEs = "Descensor espiral" },
            { key = "yaseyla", name = "Exarchanic Yaseyla", nameEs = "Yaseyla Exarcanica" },
            { key = "twelvane", name = "Archwizard Twelvane", nameEs = "Archimago Twelvane" },
            { key = "ansuul", name = "Ansuul the Tormentor", nameEs = "Ansuul el Atormentador" },
        },
    },
    {
        tag = "LC", zoneId = 1478, order = 13, name = "Lucent Citadel",
        bosses = {
            { key = "ryelaz", name = "Count Ryelaz and Zilyesset", nameEs = "Conde Ryelaz y Zilyesset" },
            { key = "cavot_agnan", name = "Cavot Agnan" },
            { key = "orphic", name = "Orphic Shattered Shard", nameEs = "Fragmento Despedazado Órfico" },
            -- "Arcane Knot": sin traduccion verificada (ni WW la tiene en es.lua).
            { key = "knot", name = "Arcane Knot" },
        },
    },
    {
        tag = "OC", zoneId = 1548, order = 14, name = "Ossein Cage",
        -- Los 6 bosses de esta trial no tienen traduccion al espanol
        -- verificada (WW tampoco la tiene en es.lua): con cliente en espanol
        -- seguiran sin detectarse por nombre hasta verificarlo contra el
        -- nombre real en juego.
        bosses = {
            { key = "gedna_relvel", name = "Red Witch Gedna Relvel" },
            { key = "fleshcraft", name = "Hall of Fleshcraft" },
            { key = "ranyu", name = "Tortured Ranyu" },
            { key = "jynorah_skorkhif", name = "Jynorah and Skorkhif" },
            { key = "thisa", name = "Blood Drinker Thisa" },
            { key = "kazpian", name = "Overfiend Kazpian" },
        },
    },
}

-- ------------------------------------------------------------- Arenas ----
--
-- Misma estructura que TRIALS a proposito: asi toda la maquinaria existente
-- (buildAssignments por tag, herencia desde el default, ResolveForTarget,
-- deteccion de contexto) vale igual sin tocar nada. Lo unico que las
-- distingue es "category", que usa la interfaz para listarlas aparte.
--
-- zoneId verificados por doble fuente: la tabla de zonas de
-- BanditsUserInterface (BUI_Events.lua, en produccion) y, para Blackrose,
-- tambien Wizard's Wardrobe (zones/BRP.lua, id = 1082). Las 12 trials que
-- ambas listas comparten coinciden ademas con las de arriba, lo que da
-- confianza en el resto de la lista.
--
-- SOLO Blackrose trae bosses: son los unicos verificables (WW los define y
-- traduce). Maelstrom, Vateshran y Dragonstar se quedan sin lista de bosses
-- porque NO tengo sus nombres verificados y no se inventan: en esas tres se
-- puede asignar "default" y "trash", que es lo que cubre la mayor parte del
-- uso, y los bosses concretos se pueden ir aprendiendo (boton "aprender este
-- boss") cuando se anadan a la tabla.
Z.ARENAS = {
    {
        tag = "DSA", zoneId = 635, order = 1, name = "Dragonstar Arena",
        category = "arena", bosses = {},
    },
    {
        tag = "MSA", zoneId = 677, order = 2, name = "Maelstrom Arena",
        category = "arena", bosses = {},
    },
    {
        tag = "BRP", zoneId = 1082, order = 3, name = "Blackrose Prison",
        category = "arena",
        bosses = {
            { key = "ennodius", name = "Battlemage Ennodius", nameEs = "Hechicero de Batalla Ennodius" },
            { key = "tames_the_beast", name = "Tames-The-Beast", nameEs = "Domador de Bestias" },
            { key = "minara", name = "Lady Minara" },
            { key = "all_of_them", name = "All of them", nameEs = "Todos ellos" },
            { key = "drakeeh", name = "Drakeeh the Unchained", nameEs = "Drakeeh el Desencadenado" },
        },
    },
    {
        tag = "VH", zoneId = 1227, order = 4, name = "Vateshran Hollows",
        category = "arena", bosses = {},
    },
}

-- Marca de categoria en las trials, para que la interfaz pueda separarlas de
-- las arenas sin depender de en que tabla estan.
for _, trial in ipairs(Z.TRIALS) do
    trial.category = trial.category or "trial"
end

-- Indices de busqueda construidos una sola vez. Incluyen trials Y arenas: los
-- tags son unicos entre las dos listas, asi que un solo indice basta y todo lo
-- que resuelve por tag o por zoneId funciona igual para ambas.
Z._byZoneId = {}
Z._byTag = {}
for _, list in ipairs({ Z.TRIALS, Z.ARENAS }) do
    for _, zone in ipairs(list) do
        Z._byZoneId[zone.zoneId] = zone
        Z._byTag[zone.tag] = zone
    end
end

function Z.GetTrialByZoneId(zoneId)
    if zoneId == nil then return nil end
    return Z._byZoneId[zoneId]
end

function Z.GetTrialByTag(tag)
    if tag == nil then return nil end
    return Z._byTag[tag]
end

function Z.IsTrialZone(zoneId)
    return Z.GetTrialByZoneId(zoneId) ~= nil
end

function Z.IsArena(zone)
    return zone ~= nil and zone.category == "arena"
end

-- --------------------------------------- Boss principal vs miniboss ----
--
-- COMO LO DISTINGUE EL JUEGO (verificado, no es una convencion nuestra):
-- GetUnitDifficulty(unitTag) devuelve UIMonsterDifficulty, y el marco del
-- objetivo se pinta segun ese valor en
-- esoui/ingame/unitframes/unitframes.lua:1683-1705:
--   MONSTER_DIFFICULTY_HARD   -> targetUnitFrame_bracket_level3 (las flechas)
--   MONSTER_DIFFICULTY_DEADLY -> targetUnitFrame_bracket_level4 (la calavera)
-- Es decir, la diferencia que se ve en pantalla entre un miniboss y un boss
-- principal sale de ese dato del motor. Por eso se clasifica con el, en vez de
-- mantener a mano una lista de "cual es mini", que envejeceria con cada parche
-- y ademas no existe publicada en ningun sitio fiable para las arenas.
Z.BOSS_TIER_MINI = "mini"
Z.BOSS_TIER_BOSS = "boss"

function Z.GetBossTierForUnit(unitTag)
    if type(GetUnitDifficulty) ~= "function" then
        return Z.BOSS_TIER_BOSS
    end
    local ok, difficulty = pcall(GetUnitDifficulty, unitTag)
    if not ok then return Z.BOSS_TIER_BOSS end

    -- Solo DEADLY cuenta como boss principal. Cualquier otra cosa que llegue
    -- marcada como bossN (HARD y por debajo) es un miniboss.
    if MONSTER_DIFFICULTY_DEADLY ~= nil and difficulty == MONSTER_DIFFICULTY_DEADLY then
        return Z.BOSS_TIER_BOSS
    end
    return Z.BOSS_TIER_MINI
end

-- ------------------------------------------------ Bosses descubiertos ----
--
-- Las arenas no tienen publicada en ningun sitio fiable una lista completa de
-- bosses, y los nombres traducidos que si se encuentran (Wizard's Wardrobe,
-- CrutchAlerts) traen los sufijos de genero de ESO ("^M", "^f") que
-- GetUnitName NO devuelve, ademas de usar formas distintas. Perseguir esas
-- tablas seria fragil y quedaria incompleto.
--
-- Asi que el addon los descubre jugando: cuando aparece un boss en una zona
-- conocida y su nombre no se reconoce, se guarda con el nombre EXACTO que da
-- este cliente y con su nivel (mini o boss) leido del motor. La lista se
-- puebla sola, en cualquier idioma, y vale igual para contenido futuro.

local function DiscoveredStore(create)
    local sv = EZOArmory.sv
    if not sv then return nil end
    if not sv.discoveredBosses then
        if not create then return nil end
        sv.discoveredBosses = {}
    end
    return sv.discoveredBosses
end

-- Clave estable para un boss descubierto. Se deriva del nombre porque es lo
-- unico que hay, pero se guarda aparte del nombre para que renombrar o
-- recapturar no rompa las asignaciones ya hechas.
local function DiscoveredKey(unitName)
    return "found_" .. tostring(unitName)
end

function Z.GetDiscoveredBosses(zoneTag)
    local store = DiscoveredStore(false)
    local perZone = store and store[zoneTag]
    if not perZone then return {} end

    local list = {}
    for key, entry in pairs(perZone) do
        list[#list + 1] = {
            key = key,
            name = entry.name,
            tier = entry.tier,
            discovered = true,
        }
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

-- Registra un boss visto en vivo. Devuelve true si era nuevo.
function Z.DiscoverBoss(zoneTag, unitName, tier)
    if zoneTag == nil or unitName == nil or unitName == "" then return false end

    local store = DiscoveredStore(true)
    if not store then return false end
    store[zoneTag] = store[zoneTag] or {}

    local key = DiscoveredKey(unitName)
    local existing = store[zoneTag][key]
    if existing then
        -- Ya conocido: solo se refresca el nivel, por si la primera vez se
        -- leyo antes de que el motor tuviera el dato definitivo.
        existing.tier = tier or existing.tier
        return false
    end

    store[zoneTag][key] = { name = tostring(unitName), tier = tier or Z.BOSS_TIER_BOSS }
    return true
end

-- ------------------------------------------- Nombres de boss aprendidos ----
--
-- Lo que devuelve GetUnitName() en ESTE cliente, guardado por key estable.
-- Ver la explicacion completa en la cabecera del fichero.

local function BossNameStore(create)
    local sv = EZOArmory.sv
    if not sv then return nil end
    if not sv.bossNames then
        if not create then return nil end
        sv.bossNames = {}
    end
    return sv.bossNames
end

-- Guarda el nombre real de un boss tal cual lo ve este cliente. Un nombre
-- vacio borra lo aprendido (vuelve a name/nameEs).
function Z.LearnBossName(trialTag, bossKey, unitName)
    if trialTag == nil or bossKey == nil then return false end
    local store = BossNameStore(true)
    if not store then return false end

    if unitName == nil or unitName == "" then
        if store[trialTag] then store[trialTag][bossKey] = nil end
        return true
    end

    store[trialTag] = store[trialTag] or {}
    store[trialTag][bossKey] = tostring(unitName)
    return true
end

function Z.GetLearnedBossName(trialTag, bossKey)
    if trialTag == nil or bossKey == nil then return nil end
    local store = BossNameStore(false)
    local perTrial = store and store[trialTag]
    return perTrial and perTrial[bossKey] or nil
end

-- Nombre a mostrar en la interfaz. "label" manda cuando existe: solo se pone
-- donde el nombre de la unidad no describe bien el encuentro (Lylanar, que es
-- realmente "Lylanar and Turlassil"), y ahi la etiqueta identifica mejor el
-- objetivo en una lista de asignaciones. Si no hay label, lo aprendido, que
-- es lo que el jugador lee de verdad en su pantalla.
function Z.GetBossLabel(trial, boss)
    if not boss then return "" end
    if boss.label then return boss.label end
    local learned = trial and Z.GetLearnedBossName(trial.tag, boss.key)
    return learned or boss.name or tostring(boss.key)
end

-- Devuelve el boss (tabla {key, name}) de una trial cuyo nombre coincide con
-- el texto dado. Orden de comprobacion: primero lo aprendido de este cliente
-- (lo mas fiable, sale del propio GetUnitName), luego el nombre en ingles y
-- el nombre en espanol como valor inicial. No hace falta detectar el idioma:
-- se compara contra todos los nombres conocidos de cada boss.
-- Lo usa context_tracker.lua para resolver un nombre de unidad a un boss.
function Z.FindBossByName(trial, unitName)
    if not trial or not trial.bosses or unitName == nil or unitName == "" then
        return nil
    end
    for _, boss in ipairs(trial.bosses) do
        if Z.GetLearnedBossName(trial.tag, boss.key) == unitName then
            return boss
        end
    end
    for _, boss in ipairs(trial.bosses) do
        if boss.name == unitName or boss.nameEs == unitName then
            return boss
        end
    end
    -- Descubiertos jugando: guardan el nombre exacto de este cliente, asi que
    -- la comparacion es fiable sin depender de idioma.
    for _, boss in ipairs(Z.GetDiscoveredBosses(trial.tag)) do
        if boss.name == unitName then
            return boss
        end
    end
    return nil
end

-- Todos los objetivos-boss de una zona: los de la tabla mas los descubiertos
-- jugando. Es lo que alimenta el desplegable de objetivos.
function Z.GetZoneBosses(zone)
    if not zone then return {} end

    local list = {}
    for _, boss in ipairs(zone.bosses or {}) do
        list[#list + 1] = boss
    end

    -- Los descubiertos que ya esten en la tabla (mismo nombre) no se repiten.
    for _, found in ipairs(Z.GetDiscoveredBosses(zone.tag)) do
        local duplicate = false
        for _, boss in ipairs(zone.bosses or {}) do
            if boss.name == found.name or boss.nameEs == found.name
                or Z.GetLearnedBossName(zone.tag, boss.key) == found.name then
                duplicate = true
                break
            end
        end
        if not duplicate then
            list[#list + 1] = found
        end
    end

    return list
end
