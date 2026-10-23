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
            -- Marca morada en el inventario sobre las piezas que estan en
            -- algun kit o build (modules/markers.lua).
            inventoryMarker = true,
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
        -- Nombres de boss aprendidos del cliente: bossNames[trialTag][bossKey]
        -- = nombre tal cual lo devuelve GetUnitName() en ESTE cliente. Lo
        -- rellena el boton "aprender" de la pestana Assign. La clave sigue
        -- siendo la key estable, asi que cambiar el idioma del juego no
        -- invalida las asignaciones: como mucho hay que volver a aprender el
        -- nombre. Ver modules/zones_trials.lua.
        bossNames = {},
        -- Bosses vistos jugando en zonas conocidas:
        -- discoveredBosses[zoneTag][key] = { name, tier }. "tier" es "mini" o
        -- "boss" segun MONSTER_DIFFICULTY, que es como los distingue el propio
        -- juego en el marco del objetivo. Se rellena solo; ver
        -- modules/zones_trials.lua.
        discoveredBosses = {},
        -- Salas de boss aprendidas: bossRooms[zoneTag][bossKey] =
        -- { x, y, z, radius }. Se aprenden solas la primera vez que se detecta
        -- cada boss, y sirven para reconocer la sala ANTES de que empiece el
        -- combate (en combate no se puede equipar nada). Ver
        -- modules/zones_trials.lua.
        bossRooms = {},
        -- Ventana emergente (HUD). Posicion y aspecto. x/y NO llevan valor por
        -- defecto a proposito: window.lua los usa como senal de "nunca se ha
        -- movido" (SetAnchor CENTER en vez de TOPLEFT+x,y). Si aqui llevaran 0,
        -- tonumber(0) es verdadero y la ventana se ancalaria siempre en la
        -- esquina superior izquierda en un perfil nuevo, nunca centrada.
        window = {
            enabled = true,
            backgroundOpacity = 86,
            showBorder = true,
        },
    }

    EZOArmory.sv = ZO_SavedVars:NewCharacterIdSettings("EZOArmory_Saved", 1, world, defaults)

    -- -------------------------------------------- Catalogo de bosses ----
    --
    -- discoveredBosses y bossRooms son conocimiento del MUNDO, no del
    -- personaje: donde esta Rakkhat y si es mini o boss no depende de con
    -- quien entres. Guardarlos por personaje obligaba a cada PJ a aprenderlo
    -- todo otra vez desde cero, y en el fichero guardado se veian los mismos
    -- bosses repetidos perfil a perfil.
    --
    -- Van en un ambito de CUENTA aparte (ZO_SavedVars:NewAccountWide sobre la
    -- misma variable guardada), asi que lo que aprende un personaje lo saben
    -- todos. El resto de ajustes sigue siendo por personaje: los kits, las
    -- builds y las asignaciones si son suyos.
    local accountDefaults = {
        discoveredBosses = {},
        bossRooms = {},
    }
    EZOArmory.svAccount = ZO_SavedVars:NewAccountWide(
        "EZOArmory_Saved", 1, "shared", accountDefaults)

    EZOArmory.svAccount.discoveredBosses = EZOArmory.svAccount.discoveredBosses or {}
    EZOArmory.svAccount.bossRooms = EZOArmory.svAccount.bossRooms or {}

    -- Migracion: lo que cada personaje habia aprendido por su cuenta se FUSIONA
    -- en el catalogo comun, sin borrar nada. Se fusiona y no se sobrescribe
    -- porque cada PJ puede haber visto bosses distintos; lo primero que llegue
    -- gana, que para estos datos da igual (el nombre y el nivel de un boss no
    -- cambian segun quien lo mire).
    --
    -- No se borra el original: si algo saliera mal, el dato viejo sigue ahi.
    local function MergeInto(target, source)
        if type(source) ~= "table" then return 0 end
        local added = 0
        for zoneKey, entries in pairs(source) do
            if type(entries) == "table" then
                target[zoneKey] = target[zoneKey] or {}
                for key, value in pairs(entries) do
                    if target[zoneKey][key] == nil then
                        target[zoneKey][key] = value
                        added = added + 1
                    end
                end
            end
        end
        return added
    end

    local migratedBosses = MergeInto(EZOArmory.svAccount.discoveredBosses, EZOArmory.sv.discoveredBosses)
    local migratedRooms = MergeInto(EZOArmory.svAccount.bossRooms, EZOArmory.sv.bossRooms)
    if (migratedBosses > 0 or migratedRooms > 0) and EZOArmory.DebugLog then
        EZOArmory.DebugLog(string.format(
            "Catalogo compartido: %d boss(es) y %d sala(s) fusionadas desde este personaje",
            migratedBosses, migratedRooms))
    end

    -- Normalizacion defensiva de la seccion general.
    EZOArmory.sv.general = EZOArmory.sv.general or {}
    EZOArmory.sv.general.language = EZOArmory.sv.general.language or defaults.general.language
    EZOArmory.sv.general.debugMode = EZOArmory.sv.general.debugMode or defaults.general.debugMode
    EZOArmory.sv.general.unlockHud = false
    if EZOArmory.sv.general.inventoryMarker == nil then
        EZOArmory.sv.general.inventoryMarker = defaults.general.inventoryMarker
    end
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

-- Restaura los AJUSTES a sus valores por defecto: idioma, rol, marca de
-- inventario, equipado automatico y posicion/tamano de la ventana. NO toca el
-- contenido guardado del jugador (kits/builds/asignaciones): "restaurar
-- valores por defecto" es para cuando la configuracion se ha desordenado o la
-- ventana se ha perdido fuera de pantalla, no para vaciar la biblioteca de
-- kits. Boton en el panel de opciones (menu.lua), con dialogo de confirmacion.
function EZOArmory.savedVars.ResetToDefaults()
    local sv = EZOArmory.sv
    if not sv then return false end

    sv.general = sv.general or {}
    sv.general.language = EZOArmory.GetDefaultLanguage()
    sv.general.debugMode = false
    sv.general.role = "dd"
    sv.general.roleMode = "auto"
    sv.general.inventoryMarker = true
    -- Se reconstruye solo con SUBSTITUTE_DEFAULTS en el siguiente acceso
    -- (Builds.GetSubstituteSettings), sin duplicar aqui esos valores.
    sv.general.substitute = nil

    -- x/y fuera a proposito, igual que en los defaults de Init: sin ellos la
    -- ventana nace centrada en vez de en la esquina superior izquierda.
    sv.window = {
        enabled = true,
        backgroundOpacity = 86,
        showBorder = true,
    }

    return true
end
