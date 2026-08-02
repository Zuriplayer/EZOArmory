-- Builds: la unidad completa y equipable del addon.
--
-- Un KIT es un bloque suelto (5 piezas de un set, joyeria+armas, un monster,
-- un mitico, las dos barras de habilidades, las 12 estrellas de CP). Un kit
-- por si solo no es equipable de forma coherente: le faltan slots.
--
-- Una BUILD compone kits hasta cubrirlo todo:
--   - varios kits de equipo (armadura + joyeria + armas)
--   - un kit de habilidades (las dos barras)
--   - un kit de CP (las doce estrellas)
--
-- Una build es lo que de verdad se equipa, y a partir de aqui es tambien lo
-- que se asignara a trials y bosses (hoy las asignaciones siguen siendo por
-- kits de equipo; ver Builds.GetTrialReadyBuilds y docs/concept.md).
--
-- Este modulo NO construye interfaz. Solo modelo, validacion y rol.
--
-- Rol de una build (SOLO interno de EZOArmory: no toca el rol del buscador de
-- grupo del juego, que se sigue leyendo con GetSelectedLFGRole). Se deduce de
-- las armas, con el orden de prioridad que pidio el diseno:
--   1. baston de curacion en cualquier barra -> sanador
--   2. escudo                                -> tanque
--   3. baston de hielo (sin lo anterior)     -> DUDA: hay tanques que no
--      llevan escudo pero si baston de hielo, y no se puede decidir solo
--      por el arma. Se marca como dudoso en vez de adivinar mal.
--   4. armas de ataque                       -> dd
-- El jugador puede forzar el rol; entonces build.role manda sobre la deteccion.
--
-- WEAPONTYPE_* y GetItemLinkWeaponType(itemLink) verificados en
-- ESOUIDocumentation.txt; los iconos de rol son los nativos del juego
-- (ZO_GetKeyboardRoleIcon / EsoUI/Art/LFG/LFG_icon_*.dds, confirmados en
-- esoui/publicallingames/globals/sharedtextures.lua).

EZOArmory = EZOArmory or {}
EZOArmory.Builds = EZOArmory.Builds or {}

local Builds = EZOArmory.Builds

Builds.ROLE_DD = "dd"
Builds.ROLE_TANK = "tank"
Builds.ROLE_HEALER = "healer"
-- No es un rol del juego: es "no se puede deducir del equipo".
Builds.ROLE_UNCERTAIN = "uncertain"

Builds.STATUS_OK = "ok"
Builds.STATUS_WARNING = "warning"
Builds.STATUS_ERROR = "error"

-- Slots de arma, en orden de barra frontal y luego trasera.
local WEAPON_SLOTS = { "main", "off", "backupMain", "backupOff" }

local function Store()
    local sv = EZOArmory.sv
    if not sv then return nil end
    sv.builds = sv.builds or {}
    sv.seq = sv.seq or {}
    sv.seq.build = tonumber(sv.seq.build) or 0
    return sv
end

-- ---------------------------------------------------------------- CRUD ----

function Builds.CreateBuild(name)
    local sv = Store()
    if not sv then return nil end

    sv.seq.build = sv.seq.build + 1
    local id = "build" .. tostring(sv.seq.build)
    local build = {
        id = id,
        name = tostring(name or id),
        gearKitIds = {},
        skillKitId = nil,
        cpKitId = nil,
        role = nil, -- nil = automatico por armas
    }
    sv.builds[id] = build
    return id, build
end

-- Crea una build entera desde lo que se lleva puesto ahora mismo, sin tener
-- que preparar los kits antes: captura el equipo (un kit por set, mas cada
-- pieza suelta), las dos barras de habilidades y las estrellas de CP, y compone
-- la build con todo ello.
--
-- Nada se duplica: si ya existe un kit con exactamente ese contenido se
-- reutiliza en vez de crear otro igual (principio de aplicacion idempotente,
-- docs/concept.md 4.3.1). Asi, copiar dos veces el mismo equipo no llena el
-- listado de kits repetidos.
--
-- Devuelve (buildId, summary) con
-- summary = { gearCreated, gearReused, skillNew, cpNew }.
function Builds.CreateFromCurrent(name)
    local sv = Store()
    if not sv then return nil end

    local gearKitIds, gearCreated, gearReused =
        EZOArmory.Kits.CaptureWornAsKits(nil, EZOArmory.BuildKitName)

    -- Habilidades y CP: se reutiliza el kit existente si el contenido coincide
    -- (CreateKitFromCurrent devuelve el kit ya guardado como "duplicate").
    local skillId, skillExisting = EZOArmory.Skills.CreateKitFromCurrent(
        EZOArmory.AutoKitName(EZOARM_AUTONAME_SKILLS, EZOArmory.Skills.ListKits))
    local skillKitId = skillId or (skillExisting and skillExisting.id) or nil

    local cpId, cpExisting = EZOArmory.Champion.CreateKitFromCurrent(
        EZOArmory.AutoKitName(EZOARM_AUTONAME_CP, EZOArmory.Champion.ListKits))
    local cpKitId = cpId or (cpExisting and cpExisting.id) or nil

    local buildId, build = Builds.CreateBuild(name)
    if not build then return nil end

    build.gearKitIds = gearKitIds
    build.skillKitId = skillKitId
    build.cpKitId = cpKitId

    return buildId, {
        gearCreated = gearCreated,
        gearReused = gearReused,
        skillNew = skillId ~= nil,
        cpNew = cpId ~= nil,
    }
end

function Builds.GetBuild(id)
    local sv = Store()
    if not sv or id == nil then return nil end
    return sv.builds[id]
end

function Builds.DeleteBuild(id)
    local sv = Store()
    if not sv or id == nil or sv.builds[id] == nil then return false end
    sv.builds[id] = nil
    Builds.ForgetBuildAssignments(id)
    return true
end

function Builds.RenameBuild(id, name)
    local build = Builds.GetBuild(id)
    if not build then return false end
    build.name = tostring(name or build.name)
    return true
end

function Builds.ListBuilds()
    local sv = Store()
    local list = {}
    if not sv then return list end
    for _, build in pairs(sv.builds) do
        list[#list + 1] = build
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

-- Rol forzado por el jugador. nil vuelve a dejarlo en automatico.
function Builds.SetRoleOverride(id, role)
    local build = Builds.GetBuild(id)
    if not build then return false end
    if role == Builds.ROLE_DD or role == Builds.ROLE_TANK or role == Builds.ROLE_HEALER then
        build.role = role
    else
        build.role = nil
    end
    return true
end

-- ------------------------------------------------- Composicion de kits ----

function Builds.HasGearKit(build, kitId)
    for _, id in ipairs(build and build.gearKitIds or {}) do
        if id == kitId then return true end
    end
    return false
end

function Builds.AddGearKit(id, kitId)
    local build = Builds.GetBuild(id)
    if not build or not EZOArmory.Kits.GetKit(kitId) then return false end
    if Builds.HasGearKit(build, kitId) then return false end
    build.gearKitIds[#build.gearKitIds + 1] = kitId
    return true
end

function Builds.RemoveGearKit(id, kitId)
    local build = Builds.GetBuild(id)
    if not build then return false end
    for index = #build.gearKitIds, 1, -1 do
        if build.gearKitIds[index] == kitId then
            table.remove(build.gearKitIds, index)
            return true
        end
    end
    return false
end

function Builds.SetSkillKit(id, skillKitId)
    local build = Builds.GetBuild(id)
    if not build then return false end
    build.skillKitId = skillKitId
    return true
end

function Builds.SetCpKit(id, cpKitId)
    local build = Builds.GetBuild(id)
    if not build then return false end
    build.cpKitId = cpKitId
    return true
end

-- Quita de todas las builds cualquier referencia a un kit borrado. Lo llaman
-- los DeleteKit de Kits/Skills/Champion para no dejar builds apuntando a kits
-- fantasma.
function Builds.ForgetKit(kitId)
    local sv = Store()
    if not sv or kitId == nil then return end
    for _, build in pairs(sv.builds) do
        for index = #build.gearKitIds, 1, -1 do
            if build.gearKitIds[index] == kitId then
                table.remove(build.gearKitIds, index)
            end
        end
        if build.skillKitId == kitId then build.skillKitId = nil end
        if build.cpKitId == kitId then build.cpKitId = nil end
    end
end

-- Kits de equipo de la build que todavia existen, ya resueltos.
function Builds.ResolveGearKits(build)
    local kits = {}
    for _, kitId in ipairs(build and build.gearKitIds or {}) do
        local kit = EZOArmory.Kits.GetKit(kitId)
        if kit then
            kits[#kits + 1] = kit
        end
    end
    return kits
end

-- ------------------------------------------------------- Rol por armas ----

-- Tipo de arma de una pieza: el guardado al capturar y, si el kit es anterior
-- a que se guardara ese dato, leido en vivo del item si sigue localizable.
local function ResolveWeaponType(entry)
    local stored = tonumber(entry and entry.weaponType)
    if stored and stored ~= 0 then
        return stored
    end
    if not (entry and entry.itemId) then return nil end
    if not (EZOArmory.Gear and EZOArmory.Gear.FindItemById)
        or type(GetItemLink) ~= "function"
        or type(GetItemLinkWeaponType) ~= "function" then
        return nil
    end
    local location = EZOArmory.Gear.FindItemById(entry.itemId)
    if not location then return nil end
    local okLink, link = pcall(GetItemLink, location.bag, location.slot)
    if not okLink or not link or link == "" then return nil end
    local okType, weaponType = pcall(GetItemLinkWeaponType, link)
    if not okType then return nil end
    return weaponType
end

Builds.ResolveWeaponType = ResolveWeaponType

-- Deduce el rol a partir de las armas asignadas. Devuelve nil si la build no
-- tiene ningun arma todavia (no hay nada de lo que deducirlo).
function Builds.DetectRole(assignment)
    local hasHealStaff, hasShield, hasFrostStaff, hasAnyWeapon = false, false, false, false

    for _, slotKey in ipairs(WEAPON_SLOTS) do
        local entry = assignment and assignment[slotKey]
        if entry then
            local weaponType = ResolveWeaponType(entry)
            if weaponType then
                hasAnyWeapon = true
                if WEAPONTYPE_HEALING_STAFF and weaponType == WEAPONTYPE_HEALING_STAFF then
                    hasHealStaff = true
                elseif WEAPONTYPE_SHIELD and weaponType == WEAPONTYPE_SHIELD then
                    hasShield = true
                elseif WEAPONTYPE_FROST_STAFF and weaponType == WEAPONTYPE_FROST_STAFF then
                    hasFrostStaff = true
                end
            end
        end
    end

    if not hasAnyWeapon then return nil end
    if hasHealStaff then return Builds.ROLE_HEALER end
    if hasShield then return Builds.ROLE_TANK end
    -- Baston de hielo sin escudo: puede ser un tanque de hielo o un dd de
    -- hielo. No se adivina.
    if hasFrostStaff then return Builds.ROLE_UNCERTAIN end
    return Builds.ROLE_DD
end

-- Rol efectivo: el forzado por el jugador si lo hay, si no el deducido.
function Builds.GetEffectiveRole(build, assignment)
    if build and build.role then
        return build.role, true
    end
    return Builds.DetectRole(assignment), false
end

local ROLE_ICON = {}
if LFG_ROLE_DPS then ROLE_ICON[Builds.ROLE_DD] = LFG_ROLE_DPS end
if LFG_ROLE_TANK then ROLE_ICON[Builds.ROLE_TANK] = LFG_ROLE_TANK end
if LFG_ROLE_HEAL then ROLE_ICON[Builds.ROLE_HEALER] = LFG_ROLE_HEAL end

-- Icono del rol. Para dd/tanque/sanador se usan los iconos nativos del juego;
-- para "duda" el icono generico de ayuda, que es el que ya usa la familia EZO
-- para marcar informacion pendiente.
function Builds.GetRoleIcon(role)
    if role == Builds.ROLE_UNCERTAIN then
        return "EsoUI/Art/Miscellaneous/help_icon.dds"
    end
    local lfgRole = ROLE_ICON[role]
    if lfgRole and type(ZO_GetKeyboardRoleIcon) == "function" then
        local ok, icon = pcall(ZO_GetKeyboardRoleIcon, lfgRole)
        if ok and icon then return icon end
    end
    return nil
end

local ROLE_STRING = {
    [Builds.ROLE_DD] = "EZOARM_ROLE_DD",
    [Builds.ROLE_TANK] = "EZOARM_ROLE_TANK",
    [Builds.ROLE_HEALER] = "EZOARM_ROLE_HEALER",
    [Builds.ROLE_UNCERTAIN] = "EZOARM_ROLE_UNCERTAIN",
}

function Builds.GetRoleLabel(role)
    local stringId = _G[ROLE_STRING[role or ""] or ""]
    if stringId then
        return GetString(stringId)
    end
    return GetString(EZOARM_ROLE_UNKNOWN)
end

-- --------------------------------------------------------- Validacion ----

-- Comprueba que las habilidades del kit encajan con las armas de la build:
-- un kit capturado con arco no sirve tal cual en una barra con baston. Solo
-- se puede comprobar si ambas partes conocen su tipo de arma.
local function CheckWeaponCoherence(build, assignment, issues)
    local skillKit = build.skillKitId and EZOArmory.Skills.GetKit(build.skillKitId)
    if not skillKit or not skillKit.weapons then return end

    local pairsToCheck = {
        { slotKey = "main", ref = skillKit.weapons.main, bar = "front" },
        { slotKey = "backupMain", ref = skillKit.weapons.backupMain, bar = "back" },
    }

    for _, check in ipairs(pairsToCheck) do
        local entry = assignment and assignment[check.slotKey]
        local buildWeapon = entry and ResolveWeaponType(entry)
        local skillWeapon = check.ref and ResolveWeaponType(check.ref)
        if buildWeapon and skillWeapon and buildWeapon ~= skillWeapon then
            issues[#issues + 1] = {
                type = "weaponMismatch",
                severity = EZOArmory.Coherence.SEVERITY.WARNING,
                bar = check.bar,
                slot = check.slotKey,
                skillKitName = tostring(skillKit.name),
            }
        end
    end
end

-- Analiza una build completa: coherencia del equipo (motor ya existente) mas
-- lo que solo tiene sentido a nivel de build (falta el kit de habilidades o el
-- de CP, armas incoherentes con las habilidades).
--
-- Devuelve:
--   { status, ok, issues, analysis, assignment, role, roleForced, complete }
function Builds.Analyze(build)
    local issues = {}
    if not build then
        return {
            status = Builds.STATUS_ERROR,
            ok = false,
            issues = issues,
            complete = false,
        }
    end

    local gearKits = Builds.ResolveGearKits(build)
    local analysis = EZOArmory.Coherence.Analyze({ kits = gearKits })

    -- Las incidencias del equipo son tambien incidencias de la build.
    for _, issue in ipairs(analysis.issues or {}) do
        issues[#issues + 1] = issue
    end

    if #gearKits == 0 then
        issues[#issues + 1] = {
            type = "noGearKits",
            severity = EZOArmory.Coherence.SEVERITY.ERROR,
        }
    end

    -- Una build sin habilidades o sin CP no esta completa: no se puede
    -- equipar entera, que es justo lo que distingue una build de un kit.
    if not (build.skillKitId and EZOArmory.Skills.GetKit(build.skillKitId)) then
        issues[#issues + 1] = {
            type = "noSkillKit",
            severity = EZOArmory.Coherence.SEVERITY.ERROR,
        }
    end
    if not (build.cpKitId and EZOArmory.Champion.GetKit(build.cpKitId)) then
        issues[#issues + 1] = {
            type = "noCpKit",
            severity = EZOArmory.Coherence.SEVERITY.ERROR,
        }
    end

    CheckWeaponCoherence(build, analysis.assignment, issues)

    local hasError, hasWarning = false, false
    for _, issue in ipairs(issues) do
        if issue.severity == EZOArmory.Coherence.SEVERITY.ERROR then
            hasError = true
        elseif issue.severity == EZOArmory.Coherence.SEVERITY.WARNING then
            hasWarning = true
        end
    end

    local status = Builds.STATUS_OK
    if hasError then
        status = Builds.STATUS_ERROR
    elseif hasWarning then
        status = Builds.STATUS_WARNING
    end

    local role, roleForced = Builds.GetEffectiveRole(build, analysis.assignment)

    return {
        status = status,
        ok = not hasError,
        issues = issues,
        analysis = analysis,
        assignment = analysis.assignment,
        role = role,
        roleForced = roleForced,
        complete = not hasError,
    }
end

-- Builds que se pueden asignar a una trial: solo las que estan completas.
-- Pensado para la fase siguiente, en la que las trials pasan a equipar builds
-- enteras en vez de kits sueltos.
function Builds.GetTrialReadyBuilds()
    local ready = {}
    for _, build in ipairs(Builds.ListBuilds()) do
        if Builds.Analyze(build).complete then
            ready[#ready + 1] = build
        end
    end
    return ready
end

-- ------------------------------------------- Asignacion a trials/bosses ----
--
-- Las trials asignan BUILDS, no kits sueltos: una build ya lo lleva todo, asi
-- que a cada objetivo le corresponde UNA build (no una lista, como pasaba con
-- los kits, que habia que combinar para completar el equipo).
--
-- Misma herencia que tenian los kits: un objetivo sin build propia usa la
-- "default" de su trial. Guardado aparte de las asignaciones por kits
-- (profiles[role].buildAssignments) para no pisarlas mientras dura la
-- transicion; ver Builds.ResolveForTarget.

Builds.TARGET_DEFAULT = "default"

local function EnsureProfile(sv, role)
    sv.profiles = sv.profiles or {}
    sv.profiles[role] = sv.profiles[role] or {}
    sv.profiles[role].buildAssignments = sv.profiles[role].buildAssignments or {}
    return sv.profiles[role]
end

local function IsValidRole(role)
    for _, known in ipairs(EZOArmory.Kits.ROLES) do
        if known == role then return true end
    end
    return false
end

local function TrialTable(sv, role, trialTag, create)
    local profile = EnsureProfile(sv, role)
    local assignments = profile.buildAssignments
    if assignments[trialTag] == nil then
        if not create then return nil end
        assignments[trialTag] = {}
    end
    return assignments[trialTag]
end

-- Asigna una build a un objetivo. targetKey puede ser "default", "trash" o la
-- clave de un boss. buildId = nil borra la asignacion.
function Builds.SetTrialAssignment(role, trialTag, targetKey, buildId)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil or targetKey == nil then
        return false
    end

    local trial = TrialTable(sv, role, tostring(trialTag), true)
    if not trial then return false end

    if buildId == nil or not Builds.GetBuild(buildId) then
        trial[tostring(targetKey)] = nil
        return true
    end
    trial[tostring(targetKey)] = tostring(buildId)
    return true
end

-- Build asignada a un objetivo, aplicando herencia. Segundo valor: "own" si es
-- suya, "inherited" si viene del default de la trial, o nil si no hay nada.
function Builds.GetTrialAssignment(role, trialTag, targetKey)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil then
        return nil, nil
    end

    local trial = TrialTable(sv, role, tostring(trialTag), false)
    if not trial then return nil, nil end

    local own = targetKey and trial[tostring(targetKey)] or nil
    if own and Builds.GetBuild(own) then
        return own, "own"
    end

    local fallback = trial[Builds.TARGET_DEFAULT]
    if fallback and Builds.GetBuild(fallback) then
        return fallback, "inherited"
    end

    return nil, nil
end

-- Build guardada EN el objetivo, sin herencia. Para editar: refleja lo que hay
-- puesto en ese objetivo concreto (nil si hereda del default).
function Builds.GetStoredTrialAssignment(role, trialTag, targetKey)
    local sv = Store()
    if not sv or not IsValidRole(role) or trialTag == nil or targetKey == nil then
        return nil
    end
    local trial = TrialTable(sv, role, tostring(trialTag), false)
    local stored = trial and trial[tostring(targetKey)]
    if stored and Builds.GetBuild(stored) then
        return stored
    end
    return nil
end

-- Quita una build borrada de todas las asignaciones, para no dejar objetivos
-- apuntando a una build que ya no existe. La llama Builds.DeleteBuild, que
-- esta definida antes en el archivo: por eso vive en la tabla Builds y no como
-- local (la busqueda se resuelve al llamar, no al crear la funcion).
function Builds.ForgetBuildAssignments(buildId)
    local sv = Store()
    if not sv or buildId == nil then return end
    for _, profile in pairs(sv.profiles or {}) do
        for _, trial in pairs(profile.buildAssignments or {}) do
            for targetKey, assigned in pairs(trial) do
                if assigned == buildId then
                    trial[targetKey] = nil
                end
            end
        end
    end
    if Builds.ForgetSubstitute then
        Builds.ForgetSubstitute(sv, buildId)
    end
end

-- Que aplica en un objetivo, resolviendo la transicion de kits a builds: manda
-- la build asignada y, si no hay ninguna, se recurre a los kits que ese
-- objetivo tuviera asignados de antes (asignaciones heredadas del modelo
-- anterior, todavia editables desde el panel de opciones).
--
-- Devuelve { kind = "build", buildId, source } o { kind = "kits", kitIds } o nil.
function Builds.ResolveForTarget(role, trialTag, targetKey)
    local buildId, source = Builds.GetTrialAssignment(role, trialTag, targetKey)
    if buildId then
        return { kind = "build", buildId = buildId, source = source }
    end

    local kitIds = EZOArmory.Kits.GetAssignment(role, trialTag, targetKey)
    if kitIds and #kitIds > 0 then
        return { kind = "kits", kitIds = kitIds }
    end

    return nil
end

-- ------------------------------------------------- Builds sustitutas ----
--
-- Dos builds de respaldo (trash y boss) que se usan cuando en donde estas no
-- hay nada asignado: una trial sin asignacion, una mazmorra o el mundo. Con
-- boss delante se equipa la de boss; sin boss, la de trash.
--
-- Mismo concepto que las "substitute setups" de Wizard's Wardrobe, incluida su
-- advertencia: fuera de las trials la deteccion de boss depende de que la zona
-- declare unidades "bossN", y no todas lo hacen (las mazmorras antiguas suelen
-- ir peor que las nuevas). Por eso viene desactivado y con interruptor por
-- tipo de zona.

Builds.SUBSTITUTE_TRASH = "trash"
Builds.SUBSTITUTE_BOSS = "boss"

local SUBSTITUTE_DEFAULTS = {
    enabled = false,
    trials = true,
    dungeons = true,
    overland = false,
}

function Builds.GetSubstituteSettings()
    local sv = EZOArmory.sv
    if not sv then return SUBSTITUTE_DEFAULTS end
    sv.general = sv.general or {}
    local settings = sv.general.substitute
    if type(settings) ~= "table" then
        settings = {}
        sv.general.substitute = settings
    end
    for key, value in pairs(SUBSTITUTE_DEFAULTS) do
        if settings[key] == nil then
            settings[key] = value
        end
    end
    return settings
end

function Builds.SetSubstituteSetting(key, value)
    local settings = Builds.GetSubstituteSettings()
    if SUBSTITUTE_DEFAULTS[key] == nil then return false end
    settings[key] = value == true
    return true
end

function Builds.SetSubstitute(role, kind, buildId)
    local sv = Store()
    if not sv or not IsValidRole(role) then return false end
    if kind ~= Builds.SUBSTITUTE_TRASH and kind ~= Builds.SUBSTITUTE_BOSS then
        return false
    end
    local profile = EnsureProfile(sv, role)
    profile.substitute = profile.substitute or {}
    profile.substitute[kind] = (buildId and Builds.GetBuild(buildId)) and tostring(buildId) or nil
    return true
end

function Builds.GetSubstitute(role, kind)
    local sv = Store()
    if not sv or not IsValidRole(role) then return nil end
    local profile = sv.profiles and sv.profiles[role]
    local stored = profile and profile.substitute and profile.substitute[kind]
    if stored and Builds.GetBuild(stored) then
        return stored
    end
    return nil
end

-- Quita una build borrada tambien de las sustitutas. En la tabla Builds
-- porque la llama ForgetBuildAssignments, definida antes en el archivo.
function Builds.ForgetSubstitute(sv, buildId)
    for _, profile in pairs(sv.profiles or {}) do
        local substitute = profile.substitute
        if substitute then
            for kind, assigned in pairs(substitute) do
                if assigned == buildId then
                    substitute[kind] = nil
                end
            end
        end
    end
end

-- Si el tipo de zona actual admite sustitutas segun los interruptores.
-- Verificado contra WW: GetCurrentZoneDungeonDifficulty() devuelve
-- DUNGEON_DIFFICULTY_NONE (0) en mundo abierto y > 0 en mazmorra.
local function SubstituteAllowedHere(inTrial)
    local settings = Builds.GetSubstituteSettings()
    if not settings.enabled then return false end
    if inTrial then
        return settings.trials == true
    end
    if type(GetCurrentZoneDungeonDifficulty) ~= "function" then
        return settings.overland == true
    end
    local ok, difficulty = pcall(GetCurrentZoneDungeonDifficulty)
    if not ok then return false end
    if (tonumber(difficulty) or 0) > 0 then
        return settings.dungeons == true
    end
    return settings.overland == true
end

-- Build sustituta aplicable ahora mismo, o nil. bossActive decide cual de las
-- dos; el tipo de zona decide si se usa alguna.
function Builds.ResolveSubstitute(role, inTrial, bossActive)
    if not SubstituteAllowedHere(inTrial) then return nil end
    local kind = bossActive and Builds.SUBSTITUTE_BOSS or Builds.SUBSTITUTE_TRASH
    return Builds.GetSubstitute(role, kind), kind
end

-- Que corresponde equipar en el sitio exacto donde estas ahora mismo, incluida
-- la sustituta si no hay nada asignado. Es el punto unico que usa el equipado
-- automatico.
--
-- Devuelve la misma forma que ResolveForTarget, con kind = "substitute"
-- cuando el respaldo es el que aplica.
function Builds.ResolveForCurrentContext(role)
    local context = EZOArmory.Context and EZOArmory.Context.GetState and EZOArmory.Context.GetState()
    if not context then return nil end

    -- Lo asignado explicitamente manda siempre sobre la sustituta.
    if context.trial then
        local targetKey = context.matchedBoss and context.matchedBoss.key or EZOArmory.Kits.TARGET_TRASH
        local resolved = Builds.ResolveForTarget(role, context.trial.tag, targetKey)
        if resolved then
            return resolved
        end
    end

    local buildId, kind = Builds.ResolveSubstitute(role, context.trial ~= nil, context.bossActive == true)
    if buildId then
        return { kind = "substitute", buildId = buildId, substituteKind = kind }
    end
    return nil
end

-- --------------------------------------------------------- Equipado ----

-- Equipa una build entera: equipo, habilidades y CP. Cada parte respeta sus
-- propias reglas (fuera de combate, cooldown de CP, aplicar solo lo que
-- cambia); ver modules/equip.lua. onReport(part, state) se llama una vez por
-- parte ("gear" | "skills" | "cp") para poder informar de cada una.
function Builds.Equip(buildId, onReport)
    local build = Builds.GetBuild(buildId)
    if not build then return false end

    local function report(part)
        return function(state)
            if onReport then onReport(part, state) end
        end
    end

    if #build.gearKitIds > 0 then
        EZOArmory.Equip.ApplyKits(build.gearKitIds, report("gear"))
    end
    if build.skillKitId then
        EZOArmory.Equip.ApplySkillKit(build.skillKitId, report("skills"))
    end
    if build.cpKitId then
        EZOArmory.Equip.ApplyCpKit(build.cpKitId, report("cp"))
    end

    return true
end

-- Equipa lo que corresponda a un objetivo de una trial. Devuelve el modo
-- aplicado ("build" | "kits") o nil si no habia nada asignado; el segundo
-- valor es el motivo cuando no se equipa ("none" | "incomplete").
--
-- onReport es el mismo callback por partes de Builds.Equip; con asignaciones
-- antiguas por kits solo llega la parte "gear", que es todo lo que aquellas
-- sabian describir.
function Builds.EquipForTarget(role, trialTag, targetKey, onReport)
    local resolved = Builds.ResolveForTarget(role, trialTag, targetKey)
    if not resolved then
        return nil, "none"
    end

    if resolved.kind == "kits" then
        EZOArmory.Equip.ApplyKits(resolved.kitIds, function(state)
            if onReport then onReport("gear", state) end
        end)
        return "kits"
    end

    -- Una build incompleta no se equipa, igual que desde la pestana Builds.
    if not Builds.Analyze(Builds.GetBuild(resolved.buildId)).complete then
        return nil, "incomplete"
    end

    Builds.Equip(resolved.buildId, onReport)
    return "build"
end

-- Objetivo aplicable donde estas ahora mismo: el boss detectado o, si no hay
-- ninguno, el trash de la trial (que a su vez hereda del default).
-- Devuelve (trial, targetKey) o nil si no estas en una trial.
function Builds.GetCurrentTarget()
    local context = EZOArmory.Context and EZOArmory.Context.GetState and EZOArmory.Context.GetState()
    local trial = context and context.trial
    if not trial then return nil end
    local targetKey = context.matchedBoss and context.matchedBoss.key or EZOArmory.Kits.TARGET_TRASH
    return trial, targetKey
end
