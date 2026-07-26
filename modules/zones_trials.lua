-- Datos de referencia de las trials del juego y sus bosses.
--
-- Modulo de datos puro: no llama a ninguna API de ESO. La deteccion en vivo
-- (zona actual, boss bajo combate) vive en context_tracker.lua, que compara
-- GetUnitName("boss1".."boss6") contra los nombres de esta tabla.
--
-- Nombres de trial y bosses en ingles, en orden de encuentro. Los nombres son
-- de referencia para etiquetado; la deteccion real usa los nombres localizados
-- que devuelve el cliente. "key" es un identificador estable y minusculo para
-- guardar asignaciones en SavedVariables sin depender del idioma.

EZOArmory = EZOArmory or {}
EZOArmory.Zones = EZOArmory.Zones or {}
local Z = EZOArmory.Zones

-- Ordenadas por antiguedad de lanzamiento (order = prioridad clasica).
Z.TRIALS = {
    {
        tag = "AA", zoneId = 638, order = 1, name = "Aetherian Archive",
        bosses = {
            { key = "stormatro", name = "Lightning Storm Atronach" },
            { key = "stoneatro", name = "Foundation Stone Atronach" },
            { key = "varlariel", name = "Varlariel" },
            { key = "mage", name = "The Mage" },
        },
    },
    {
        tag = "SO", zoneId = 639, order = 2, name = "Sanctum Ophidia",
        bosses = {
            { key = "mantikora", name = "Possessed Mantikora" },
            { key = "stonebreaker", name = "Stonebreaker" },
            { key = "ozara", name = "Ozara" },
            { key = "serpent", name = "The Serpent" },
        },
    },
    {
        tag = "HRC", zoneId = 636, order = 3, name = "Hel Ra Citadel",
        bosses = {
            { key = "rakotu", name = "Ra Kotu" },
            { key = "yokeda_rokdun", name = "Yokeda Rok'dun" },
            { key = "yokeda_kai", name = "Yokeda Kai" },
            { key = "warrior", name = "The Warrior" },
        },
    },
    {
        tag = "MOL", zoneId = 725, order = 4, name = "Maw of Lorkhaj",
        bosses = {
            { key = "zhajhassa", name = "Zhaj'hassa the Forgotten" },
            { key = "twins", name = "Twins" },
            { key = "rakkhat", name = "Rakkhat" },
        },
    },
    {
        tag = "HOF", zoneId = 975, order = 5, name = "Halls of Fabrication",
        bosses = {
            { key = "hunterkiller", name = "Hunter-Killer Negatrix" },
            { key = "factotum", name = "Pinnacle Factotum" },
            { key = "archcustodian", name = "Archcustodian" },
            { key = "reactor", name = "Reactor" },
            { key = "general", name = "Assembly General" },
        },
    },
    {
        tag = "AS", zoneId = 1000, order = 6, name = "Asylum Sanctorium",
        bosses = {
            { key = "felms", name = "Saint Felms the Bold" },
            { key = "llothis", name = "Saint Llothis the Pious" },
            { key = "olms", name = "Saint Olms the Just" },
        },
    },
    {
        tag = "CR", zoneId = 1051, order = 7, name = "Cloudrest",
        bosses = {
            { key = "zmaja", name = "Z'Maja" },
            { key = "galenwe", name = "Shade of Galenwe" },
            { key = "siroria", name = "Shade of Siroria" },
            { key = "relequen", name = "Shade of Relequen" },
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
            { key = "yandir", name = "Yandir the Butcher" },
            { key = "vrol", name = "Captain Vrol" },
            { key = "falgravn", name = "Lord Falgravn" },
        },
    },
    {
        tag = "RG", zoneId = 1263, order = 10, name = "Rockgrove",
        bosses = {
            { key = "oaxiltso", name = "Oaxiltso" },
            { key = "bahsei", name = "Flame-Herald Bahsei" },
            { key = "xalvakka", name = "Xalvakka" },
        },
    },
    {
        tag = "DSR", zoneId = 1344, order = 11, name = "Dreadsail Reef",
        bosses = {
            { key = "lylanar_turlassil", name = "Lylanar and Turlassil" },
            { key = "reef_guardian", name = "Reef Guardian" },
            { key = "taleria", name = "Tideborn Taleria" },
        },
    },
    {
        tag = "SE", zoneId = 1427, order = 12, name = "Sanity's Edge",
        bosses = {
            { key = "descender", name = "Spiral Descender" },
            { key = "yaseyla", name = "Exarchanic Yaseyla" },
            { key = "twelvane", name = "Archwizard Twelvane" },
            { key = "ansuul", name = "Ansuul the Tormentor" },
        },
    },
    {
        tag = "LC", zoneId = 1478, order = 13, name = "Lucent Citadel",
        bosses = {
            { key = "ryelaz", name = "Count Ryelaz and Zilyesset" },
            { key = "cavot_agnan", name = "Cavot Agnan" },
            { key = "orphic", name = "Orphic Shattered Shard" },
            { key = "knot", name = "Arcane Knot" },
        },
    },
    {
        tag = "OC", zoneId = 1548, order = 14, name = "Ossein Cage",
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
-- el texto dado (comparacion exacta, sensible al idioma de los datos). Pensado
-- para que context_tracker.lua resuelva un nombre de unidad a un boss conocido.
function Z.FindBossByName(trial, unitName)
    if not trial or not trial.bosses or unitName == nil or unitName == "" then
        return nil
    end
    for _, boss in ipairs(trial.bosses) do
        if boss.name == unitName then
            return boss
        end
    end
    return nil
end
