-- Defaults y SavedVariables centralizados.
EZOArmory.savedVars = EZOArmory.savedVars or {}

function EZOArmory.savedVars.Init()
    local world = GetWorldName()
    local defaults = {
        general = {
            language = EZOArmory.GetDefaultLanguage(),
            debugMode = false,
            unlockHud = false,
        },
        -- Kits de sets con nombre (piedra angular). Se detallara su esquema
        -- en el modulo kits.lua. Estructura por nombre para busqueda estable.
        kits = {},
        -- Loadouts: combinaciones de kits asignadas a trial/boss.
        loadouts = {},
        -- Grupos de Champion Points con nombre (pulls, bosses, especial).
        cpGroups = {},
        -- Slots de habilidades con nombre para barra principal/secundaria.
        skillSets = {},
        -- Ventana emergente (HUD). Posicion y aspecto.
        window = {
            enabled = true,
            x = 0,
            y = 0,
            backgroundOpacity = 86,
            showBorder = true,
        },
    }

    EZOArmory.sv = ZO_SavedVars:NewCharacterIdSettings("EZOArmory_Saved", 1, world, defaults)

    -- Normalizacion defensiva de la seccion general.
    EZOArmory.sv.general = EZOArmory.sv.general or {}
    EZOArmory.sv.general.language = EZOArmory.sv.general.language or defaults.general.language
    EZOArmory.sv.general.debugMode = EZOArmory.sv.general.debugMode or defaults.general.debugMode
    EZOArmory.sv.general.unlockHud = false

    EZOArmory.sv.kits = EZOArmory.sv.kits or defaults.kits
    EZOArmory.sv.loadouts = EZOArmory.sv.loadouts or defaults.loadouts
    EZOArmory.sv.cpGroups = EZOArmory.sv.cpGroups or defaults.cpGroups
    EZOArmory.sv.skillSets = EZOArmory.sv.skillSets or defaults.skillSets
    EZOArmory.sv.window = EZOArmory.sv.window or defaults.window
end
