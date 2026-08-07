-- Datos de referencia de las trials del juego y sus bosses.
--
-- Modulo de datos puro: no llama a ninguna API de ESO. La deteccion en vivo
-- (zona actual, boss bajo combate) vive en context_tracker.lua, que compara
-- GetUnitName("boss1".."boss6") contra los nombres de esta tabla.
--
-- Nombres de trial y bosses en ingles, en orden de encuentro. "key" es un
-- identificador estable y minusculo para guardar asignaciones en
-- SavedVariables sin depender del idioma.
--
-- "nameEs" es el nombre real que devuelve GetUnitName() con el cliente en
-- espanol (verificado contra Wizard's Wardrobe en produccion, que ya
-- distingue boss por nombre en varios idiomas: lang/es.lua, claves
-- WW_<TRIAL>_<BOSS>). Z.FindBossByName compara contra los dos nombres sin
-- necesidad de detectar el idioma: antes, con solo el nombre en ingles, la
-- asignacion por boss concreto (ej. LC/HRC) nunca coincidia con un cliente no
-- ingles y caia siempre a trash en silencio.
--
-- Sin traduccion verificada todavia (ni siquiera WW la tiene en su es.lua):
-- "Arcane Knot" (LC) y las seis de Ossein Cage (OC). En esos, con cliente en
-- espanol, seguira sin detectar el boss concreto hasta que se verifique el
-- nombre real (mas facil: leerlo tal cual aparece en juego y pasarlo).

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

-- Devuelve el boss (tabla {key, name}) de una trial cuyo nombre coincide con
-- el texto dado. Compara contra el nombre en ingles y, si lo hay, el nombre
-- en espanol (nameEs) -- sin necesidad de detectar el idioma del cliente: da
-- igual cual de los dos devuelva GetUnitName(), uno de los dos coincidira.
-- Pensado para que context_tracker.lua resuelva un nombre de unidad a un
-- boss conocido.
function Z.FindBossByName(trial, unitName)
    if not trial or not trial.bosses or unitName == nil or unitName == "" then
        return nil
    end
    for _, boss in ipairs(trial.bosses) do
        if boss.name == unitName or boss.nameEs == unitName then
            return boss
        end
    end
    return nil
end
