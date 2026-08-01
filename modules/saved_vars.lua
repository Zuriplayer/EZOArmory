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
            -- auto: el rol activo se detecta del rol elegido en el buscador de
            -- grupo; manual: se usa el seleccionado en el panel.
            roleMode = "auto",
        },
        -- Kits de piezas concretas (piedra angular), comunes al personaje.
        -- Esquema completo en modules/kits.lua.
        kits = {},
        -- Perfiles por rol: asignaciones de kits por trial/boss y modo de
        -- equipado. Los rellena kits.lua bajo demanda.
        profiles = {},
        -- Builds: composicion completa y equipable (varios kits de equipo + un
        -- kit de habilidades + un kit de CP). Esquema en modules/builds.lua.
        builds = {},
        -- Contadores de identificadores incrementales.
        seq = { kit = 0, skillKit = 0, cpKit = 0, build = 0 },
        -- Kits de habilidades (modules/skills.lua) y de CP (modules/champion.lua).
        skillKits = {},
        cpKits = {},
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
    if EZOArmory.sv.general.roleMode ~= "manual" then
        EZOArmory.sv.general.roleMode = "auto"
    end

    EZOArmory.sv.kits = EZOArmory.sv.kits or defaults.kits
    EZOArmory.sv.profiles = EZOArmory.sv.profiles or defaults.profiles
    EZOArmory.sv.seq = EZOArmory.sv.seq or defaults.seq
    EZOArmory.sv.seq.kit = tonumber(EZOArmory.sv.seq.kit) or 0
    EZOArmory.sv.seq.skillKit = tonumber(EZOArmory.sv.seq.skillKit) or 0
    EZOArmory.sv.seq.cpKit = tonumber(EZOArmory.sv.seq.cpKit) or 0
    EZOArmory.sv.seq.build = tonumber(EZOArmory.sv.seq.build) or 0
    EZOArmory.sv.skillKits = EZOArmory.sv.skillKits or defaults.skillKits
    EZOArmory.sv.cpKits = EZOArmory.sv.cpKits or defaults.cpKits
    EZOArmory.sv.builds = EZOArmory.sv.builds or defaults.builds
    -- Limpieza de placeholders antiguos que nunca llegaron a usarse.
    EZOArmory.sv.cpGroups = nil
    EZOArmory.sv.skillSets = nil
    EZOArmory.sv.window = EZOArmory.sv.window or defaults.window
end
