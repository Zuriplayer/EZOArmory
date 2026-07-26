-- Defaults y SavedVariables centralizados.
EZOArmory.savedVars = EZOArmory.savedVars or {}

function EZOArmory.savedVars.Init()
    local world = GetWorldName()
    local defaults = {
        general = {
            language = EZOArmory.GetDefaultLanguage(),
            debugMode = false,
            unlockHud = false,
            role = "dd",
        },
        -- Kits de piezas concretas (piedra angular), comunes al personaje.
        -- Esquema completo en modules/kits.lua.
        kits = {},
        -- Perfiles por rol: asignaciones de kits por trial/boss y modo de
        -- equipado. Los rellena kits.lua bajo demanda.
        profiles = {},
        -- Contadores de identificadores incrementales.
        seq = { kit = 0 },
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
    EZOArmory.sv.general.role = EZOArmory.sv.general.role or defaults.general.role

    EZOArmory.sv.kits = EZOArmory.sv.kits or defaults.kits
    EZOArmory.sv.profiles = EZOArmory.sv.profiles or defaults.profiles
    EZOArmory.sv.seq = EZOArmory.sv.seq or defaults.seq
    EZOArmory.sv.seq.kit = tonumber(EZOArmory.sv.seq.kit) or 0
    EZOArmory.sv.cpGroups = EZOArmory.sv.cpGroups or defaults.cpGroups
    EZOArmory.sv.skillSets = EZOArmory.sv.skillSets or defaults.skillSets
    EZOArmory.sv.window = EZOArmory.sv.window or defaults.window
end
