-- Equipado automatico al cambiar el contexto (zona o boss).
--
-- Escucha el seguimiento de contexto (modules/context_tracker.lua) y aplica lo
-- que corresponda al sitio exacto donde estas, resuelto por
-- Builds.ResolveForCurrentContext: primero lo asignado a esa trial/boss y, si
-- no hay nada, la build sustituta (boss o trash) si esta activada para ese tipo
-- de zona.
--
-- Dos salvaguardas importantes:
--
--   1. No se re-aplica lo mismo. El contexto puede dispararse varias veces
--      seguidas (cambio de zona, aparicion y desaparicion de bosses) y cada
--      aplicacion crea una tarea de LibAsync que espera a estar fuera de
--      combate. Sin este filtro se acumularian tareas identicas, y en CP cada
--      envio gasta parte del cooldown de ~30 s. Es el mismo principio de
--      aplicacion idempotente del resto del addon (docs/concept.md 4.3.1),
--      aplicado en el disparador.
--
--   2. El equipo no se cambia en combate. No hace falta comprobarlo aqui:
--      modules/equip.lua ya espera a salir de combate. Lo que si implica es
--      que si el boss aparece cuando ya estas peleando, el cambio se aplicara
--      al terminar; entrar andando en la sala del boss antes de empezar es lo
--      que hace que llegue a tiempo.

EZOArmory = EZOArmory or {}
EZOArmory.AutoEquip = EZOArmory.AutoEquip or {}

local AutoEquip = EZOArmory.AutoEquip

local registered = false
local lastAppliedBuildId = nil
local lastZoneId = nil

function AutoEquip.IsEnabled()
    local settings = EZOArmory.Builds.GetSubstituteSettings()
    return settings.enabled == true
end

-- Olvida lo ultimo aplicado, para que el siguiente cambio de contexto vuelva a
-- equipar aunque coincida. Lo usa el cambio de zona y cualquier cambio manual
-- de configuracion.
function AutoEquip.Reset()
    lastAppliedBuildId = nil
end

local function ApplyResolved(resolved)
    if resolved.kind ~= "build" and resolved.kind ~= "substitute" then
        -- Las asignaciones antiguas por kits no se equipan solas: son equipo
        -- suelto, sin habilidades ni CP, y aplicarlas automaticamente daria una
        -- build a medias sin avisar.
        return false
    end

    local build = EZOArmory.Builds.GetBuild(resolved.buildId)
    if not build then return false end
    if not EZOArmory.Builds.Analyze(build).complete then
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "AutoEquip: skipped incomplete build %s", tostring(build.name)))
        end
        return false
    end

    if resolved.buildId == lastAppliedBuildId then
        return false
    end
    lastAppliedBuildId = resolved.buildId

    if EZOArmory.Print then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_AUTO_EQUIP), tostring(build.name)))
    end
    EZOArmory.Builds.Equip(resolved.buildId, function(part, state)
        if EZOArmory.WindowBuilds and EZOArmory.WindowBuilds.ReportEquipPart then
            EZOArmory.WindowBuilds.ReportEquipPart(part, state)
        end
    end)
    return true
end

local function OnContextChanged(state)
    if not AutoEquip.IsEnabled() then return end

    -- Cambiar de zona invalida lo aplicado: en la nueva puede tocar otra cosa
    -- aunque el jugador siga llevando lo mismo puesto.
    if state.zoneId ~= lastZoneId then
        lastZoneId = state.zoneId
        AutoEquip.Reset()
    end

    local resolved = EZOArmory.Builds.ResolveForCurrentContext(EZOArmory.GetActiveRole())
    if not resolved then return end
    ApplyResolved(resolved)
end

function AutoEquip.Init()
    if registered then return end
    if not (EZOArmory.Context and EZOArmory.Context.RegisterCallback) then return end
    EZOArmory.Context.RegisterCallback(OnContextChanged)
    registered = true
end
