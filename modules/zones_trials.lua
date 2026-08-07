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
        },
    },
    {
        tag = "DSR", zoneId = 1344, order = 11, name = "Dreadsail Reef",
        bosses = {
            { key = "lylanar_turlassil", name = "Lylanar and Turlassil", nameEs = "Lylanar y Turlassil" },
            { key = "reef_guardian", name = "Reef Guardian", nameEs = "Guardián del arrecife" },
            { key = "taleria", name = "Tideborn Taleria", nameEs = "Taleria Nacida de las mareas" },
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

-- Indices de busqueda construidos una sola vez.
Z._byZoneId = {}
Z._byTag = {}
for _, trial in ipairs(Z.TRIALS) do
    Z._byZoneId[trial.zoneId] = trial
    Z._byTag[trial.tag] = trial
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

-- Nombre a mostrar en la interfaz: lo aprendido manda, porque es lo que el
-- jugador lee de verdad en su pantalla.
function Z.GetBossLabel(trial, boss)
    if not boss then return "" end
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
    return nil
end
