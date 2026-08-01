-- Panel de configuracion LibAddonMenu.
EZOArmory_Menu = EZOArmory_Menu or {}

local ADDON_NAME = "EZOArmory"
local PANEL_ID = ADDON_NAME .. "_Options"
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"
local KIT_LIST_REFERENCE = "EZOArmoryKitListDropdown"

-- Header informativo compartido del estandar LAM de la familia EZO:
-- nombre + icono de informacion morado (#B040FF), ayuda general en el tooltip.
local function CreateInfoHeader(name, tooltip)
    return {
        type = "header",
        name = zo_strformat(
            "<<1>> |cB040FF|t26:26:<<2>>:inheritcolor|t|r",
            tostring(name or ""),
            INFO_HEADER_TEXTURE
        ),
        tooltip = tooltip,
    }
end

local function Print(message)
    if EZOArmory.Print then
        EZOArmory.Print(message)
    end
end

-- Estado de sesion del panel. No se persiste.
local function Runtime()
    EZOArmory.runtime = EZOArmory.runtime or {}
    local runtime = EZOArmory.runtime
    runtime.newKitName = runtime.newKitName or ""
    runtime.capturePreset = runtime.capturePreset or "all"
    -- Asignaciones: trial y objetivo seleccionados en el panel. Por defecto, la
    -- trial en la que estas ahora (si aplica), o la primera del catalogo.
    if runtime.selectedTrialTag == nil then
        local contextTrial = EZOArmory.Context
            and EZOArmory.Context.GetTrial
            and EZOArmory.Context.GetTrial()
        if contextTrial then
            runtime.selectedTrialTag = contextTrial.tag
        elseif EZOArmory.Zones and EZOArmory.Zones.TRIALS[1] then
            runtime.selectedTrialTag = EZOArmory.Zones.TRIALS[1].tag
        end
    end
    runtime.selectedTargetKey = runtime.selectedTargetKey or "default"
    -- Kit elegido en el selector propio de la seccion Asignaciones.
    runtime.assignKitId = runtime.assignKitId or nil
    return runtime
end

-- ------------------------------------------------------------- Idioma ------

local function GetLanguageChoices()
    return {
        GetString(EZOARM_OPTION_LANGUAGE_AUTO),
        GetString(EZOARM_OPTION_LANGUAGE_EN),
        GetString(EZOARM_OPTION_LANGUAGE_ES),
    }
end

local function GetConfiguredLanguage()
    if EZOArmory.sv and EZOArmory.sv.general and EZOArmory.sv.general.language then
        return EZOArmory.sv.general.language
    end
    return EZOArmory.GetDefaultLanguage()
end

local function LanguageValueToLabel(value)
    if value == "en" then return GetString(EZOARM_OPTION_LANGUAGE_EN) end
    if value == "es" then return GetString(EZOARM_OPTION_LANGUAGE_ES) end
    return GetString(EZOARM_OPTION_LANGUAGE_AUTO)
end

local function LabelToLanguageValue(label)
    if label == GetString(EZOARM_OPTION_LANGUAGE_EN) then return "en" end
    if label == GetString(EZOARM_OPTION_LANGUAGE_ES) then return "es" end
    return "auto"
end

local function IsLanguageLocked()
    return EZOArmory.IsLanguageManagedByEZOCore and EZOArmory.IsLanguageManagedByEZOCore()
end

-- --------------------------------------------------------------- Roles -----

local RoleLabel = EZOArmory.RoleLabel

local function GetRoleChoices()
    local labels, values = {}, {}
    for _, role in ipairs(EZOArmory.Kits.ROLES) do
        labels[#labels + 1] = RoleLabel(role)
        values[#values + 1] = role
    end
    return labels, values
end

local IsRoleAuto = EZOArmory.IsRoleAuto
local GetActiveRole = EZOArmory.GetActiveRole

-- ------------------------------------------------------- Asignaciones ------

local ASSIGN_TARGET_DEFAULT = "default"

local function GetTrialChoices()
    local labels, values = {}, {}
    for _, trial in ipairs(EZOArmory.Zones.TRIALS) do
        labels[#labels + 1] = trial.name
        values[#values + 1] = trial.tag
    end
    return labels, values
end

-- Objetivos de una trial: default (fallback), trash, y cada boss/miniboss.
local function GetTargetChoices(trialTag)
    local labels = { GetString(EZOARM_TARGET_DEFAULT), GetString(EZOARM_TARGET_TRASH) }
    local values = { ASSIGN_TARGET_DEFAULT, EZOArmory.Kits.TARGET_TRASH }
    local trial = EZOArmory.Zones.GetTrialByTag(trialTag)
    if trial then
        for _, boss in ipairs(trial.bosses) do
            labels[#labels + 1] = boss.name
            values[#values + 1] = boss.key
        end
    end
    return labels, values
end

-- ---------------------------------------------------------- Presets kit ----

local ICON_SIZE = 24
local ICON_MAX = 6

local SlotLabel = EZOArmory.SlotLabel

-- Tira de iconos con los slots ocupados, en orden canonico. Es la pista visual
-- que distingue de un vistazo un kit de cuerpo de uno de joyeria y armas.
--
-- Mismo marcado que el icono de ayuda del encabezado (ruta sin barra inicial y
-- inheritcolor), que es el formato verificado como funcional en este panel.
-- Tira con los iconos reales de los items (a todo color), como pista visual.
-- Se usan los iconos de item y no las siluetas de slot porque estas son grises
-- y el tinte de color en ESO solo multiplica: no se pueden aclarar.
--
-- Las rutas de GetItemLinkIcon llevan barra inicial, que el marcado en linea
-- |t|t no acepta; se quita. Se limita el numero de iconos para no empujar el
-- nombre fuera del desplegable.
local function IconStrip(iconPaths)
    local parts = {}
    for index, path in ipairs(iconPaths or {}) do
        if index > ICON_MAX then break end
        local clean = tostring(path):gsub("^/", "")
        parts[#parts + 1] = string.format("|t%d:%d:%s|t", ICON_SIZE, ICON_SIZE, clean)
    end
    return table.concat(parts, "")
end

local ArmorTypeLabel = EZOArmory.ArmorTypeLabel
local BuildKitName = EZOArmory.BuildKitName

-- Construye las opciones del selector de captura leyendo el equipo puesto:
-- "todo", cada set de dos o mas piezas, y solo las piezas realmente sueltas
-- (miticos, armas sin set, sets de los que llevas una unica pieza).
local function GetCaptureChoices()
    local labels, values = {}, {}
    for _, entry in ipairs(EZOArmory.Gear.GetCaptureEntries()) do
        local label
        if entry.kind == "all" then
            label = string.format("%s (%d)", GetString(EZOARM_PRESET_ALL), entry.count or 0)
        elseif entry.kind == "set" then
            label = string.format("%s (%d)", tostring(entry.name), entry.count or 0)
        else
            label = string.format("%s - %s", tostring(entry.name), SlotLabel(entry.slotKey))
            local armorLabel = ArmorTypeLabel(entry.armorType)
            if armorLabel then
                label = string.format("%s (%s)", label, armorLabel)
            end
        end

        -- Los iconos van delante: LAM recorta el texto largo con puntos
        -- suspensivos, y al final se perderian justo en los nombres largos.
        local icons = IconStrip(entry.icons)
        if icons ~= "" then
            label = icons .. " " .. label
        end

        labels[#labels + 1] = label
        values[#values + 1] = entry.value
    end
    return labels, values
end

-- ------------------------------------------------------- Listado de kits ---

-- Etiqueta estandar de un kit: iconos de sus piezas + nombre + numero de piezas.
local function KitLabel(kit)
    local label = string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit))
    local icons = IconStrip(EZOArmory.Kits.GetKitIcons(kit))
    if icons ~= "" then
        label = icons .. " " .. label
    end
    return label
end

local kitChoices, kitChoiceValues = {}, {}

local function RefreshKitChoices()
    for index = #kitChoices, 1, -1 do kitChoices[index] = nil end
    for index = #kitChoiceValues, 1, -1 do kitChoiceValues[index] = nil end

    for _, kit in ipairs(EZOArmory.Kits.ListKits()) do
        kitChoices[#kitChoices + 1] = KitLabel(kit)
        kitChoiceValues[#kitChoiceValues + 1] = kit.id
    end

    local runtime = Runtime()
    -- Si el kit seleccionado ya no existe, apunta al primero disponible.
    local stillThere = false
    for _, id in ipairs(kitChoiceValues) do
        if id == runtime.selectedKitId then
            stillThere = true
            break
        end
    end
    if not stillThere then
        runtime.selectedKitId = kitChoiceValues[1]
    end

end

-- Fuerza un rebuild del panel un frame despues. Bajo EZOCore los controles se
-- renombran y no se pueden actualizar por "reference"; reconstruir es la via
-- fiable para reflejar cambios de opciones dinamicas (listas, dropdowns
-- dependientes). Se aplaza para no destruir el control cuyo callback corre ahora.
local function ForcePanelRebuild()
    if not (EZOCore and type(EZOCore.GetService) == "function") then
        return
    end
    local settings = EZOCore:GetService("family.settings", 1)
    if settings and type(settings.RefreshCurrentPanel) == "function" then
        zo_callLater(function()
            pcall(function()
                settings:RefreshCurrentPanel(true)
            end)
        end, 50)
    end
end

-- Empuja la lista de kits actualizada al control visible. Sin EZOCore se
-- actualiza en el sitio por "reference"; bajo EZOCore se fuerza el rebuild.
local function RefreshKitDropdown()
    RefreshKitChoices()

    local control = _G[KIT_LIST_REFERENCE]
    if control and type(control.UpdateChoices) == "function" then
        control:UpdateChoices(kitChoices, kitChoiceValues)
        return
    end

    ForcePanelRebuild()
end

-- ------------------------------------------------------------- Acciones ----

local function CaptureKit()
    local runtime = Runtime()
    local name = tostring(runtime.newKitName or "")
    if name == "" then
        Print(GetString(EZOARM_MSG_KIT_NEED_NAME))
        return
    end

    local slots = EZOArmory.Gear.ResolveCaptureSlots(runtime.capturePreset)
    local id, kit, reason = EZOArmory.Kits.CreateKitFromWorn(name, slots, nil)
    if reason == "duplicate" and kit then
        -- Mismas piezas exactas que un kit existente: no se crea otro.
        runtime.selectedKitId = kit.id
        Print(zo_strformat(GetString(EZOARM_MSG_KIT_DUPLICATE), tostring(kit.name)))
        return
    end
    if not id or not kit then
        Print(GetString(EZOARM_MSG_KIT_NO_PIECES))
        return
    end

    local pieceCount = EZOArmory.Kits.CountPieces(kit)
    if pieceCount == 0 then
        EZOArmory.Kits.DeleteKit(id)
        Print(GetString(EZOARM_MSG_KIT_NO_PIECES))
        return
    end

    runtime.newKitName = ""
    runtime.selectedKitId = id
    RefreshKitDropdown()
    Print(zo_strformat(GetString(EZOARM_MSG_KIT_CREATED), name, pieceCount))
end

local AutoName = EZOArmory.AutoKitName

local function CaptureAllSets()
    local role = GetActiveRole()
    local created, skipped = EZOArmory.Kits.CaptureAllSets(role, BuildKitName)

    -- Tambien captura las barras de habilidades y los CP actuales, cada uno en
    -- su propio espacio, con nombre automatico y sin duplicar.
    local skillId, _, skillReason = EZOArmory.Skills.CreateKitFromCurrent(
        AutoName(EZOARM_AUTONAME_SKILLS, EZOArmory.Skills.ListKits))
    if skillId then
        created = created + 1
    elseif skillReason == "duplicate" then
        skipped = skipped + 1
    end

    local cpId, _, cpReason = EZOArmory.Champion.CreateKitFromCurrent(
        AutoName(EZOARM_AUTONAME_CP, EZOArmory.Champion.ListKits))
    if cpId then
        created = created + 1
    elseif cpReason == "duplicate" then
        skipped = skipped + 1
    end

    RefreshKitDropdown()
    ForcePanelRebuild()
    Print(zo_strformat(GetString(EZOARM_MSG_KITS_CAPTURED_ALL), created, skipped))
end

-- ------------------------------------------------- Kits de habilidades -----

local function SkillKitLabel(kit)
    local label = string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Skills.CountAbilities(kit))
    local weaponIcons = {}
    local front = EZOArmory.Skills.GetWeaponIcon(kit, EZOArmory.Skills.HOTBAR_FRONT)
    local back = EZOArmory.Skills.GetWeaponIcon(kit, EZOArmory.Skills.HOTBAR_BACK)
    if front then weaponIcons[#weaponIcons + 1] = front end
    if back then weaponIcons[#weaponIcons + 1] = back end
    local icons = IconStrip(weaponIcons)
    if icons ~= "" then
        label = icons .. " " .. label
    end
    return label
end

local function GetSkillKitChoices()
    local labels, values = {}, {}
    for _, kit in ipairs(EZOArmory.Skills.ListKits()) do
        labels[#labels + 1] = SkillKitLabel(kit)
        values[#values + 1] = kit.id
    end
    return labels, values
end

local function CaptureSkillKit()
    local runtime = Runtime()
    local name = tostring(runtime.newSkillKitName or "")
    if name == "" then
        name = AutoName(EZOARM_AUTONAME_SKILLS, EZOArmory.Skills.ListKits)
    end

    local id, kit, reason = EZOArmory.Skills.CreateKitFromCurrent(name)
    if reason == "duplicate" and kit then
        runtime.selectedSkillKitId = kit.id
        Print(zo_strformat(GetString(EZOARM_MSG_SKILL_KIT_DUPLICATE), tostring(kit.name)))
        return
    end
    if reason == "empty" or not id then
        Print(GetString(EZOARM_MSG_SKILL_KIT_EMPTY))
        return
    end

    runtime.newSkillKitName = ""
    runtime.selectedSkillKitId = id
    ForcePanelRebuild()
    Print(zo_strformat(GetString(EZOARM_MSG_SKILL_KIT_CREATED), name))
end

local function ShowSelectedSkillKit()
    local runtime = Runtime()
    local kit = EZOArmory.Skills.GetKit(runtime.selectedSkillKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end

    local function BarLine(hotbar, barStringId)
        local names = EZOArmory.Skills.GetBarAbilityNames(kit, hotbar)
        local weapons = kit.weapons or {}
        local ref = (hotbar == EZOArmory.Skills.HOTBAR_BACK) and weapons.backupMain or weapons.main
        local weaponName = ref and ref.itemName or "-"
        Print(string.format("%s [%s]: %s",
            GetString(barStringId), tostring(weaponName), table.concat(names, ", ")))
    end

    Print(tostring(kit.name) .. ":")
    BarLine(EZOArmory.Skills.HOTBAR_FRONT, EZOARM_MSG_BAR_FRONT)
    BarLine(EZOArmory.Skills.HOTBAR_BACK, EZOARM_MSG_BAR_BACK)
end

local function DeleteSelectedSkillKit()
    local runtime = Runtime()
    local kit = EZOArmory.Skills.GetKit(runtime.selectedSkillKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end
    local name = tostring(kit.name)
    EZOArmory.Skills.DeleteKit(runtime.selectedSkillKitId)
    ForcePanelRebuild()
    Print(zo_strformat(GetString(EZOARM_MSG_SKILL_KIT_DELETED), name))
end

-- --------------------------------------------------------- Kits de CP ------

local function GetCpKitChoices()
    local labels, values = {}, {}
    for _, kit in ipairs(EZOArmory.Champion.ListKits()) do
        labels[#labels + 1] = string.format(
            "%s (%d)", tostring(kit.name), EZOArmory.Champion.CountStars(kit))
        values[#values + 1] = kit.id
    end
    return labels, values
end

local function CaptureCpKit()
    local runtime = Runtime()
    local name = tostring(runtime.newCpKitName or "")
    if name == "" then
        name = AutoName(EZOARM_AUTONAME_CP, EZOArmory.Champion.ListKits)
    end

    local id, kit, reason = EZOArmory.Champion.CreateKitFromCurrent(name)
    if reason == "duplicate" and kit then
        runtime.selectedCpKitId = kit.id
        Print(zo_strformat(GetString(EZOARM_MSG_CP_KIT_DUPLICATE), tostring(kit.name)))
        return
    end
    if reason == "empty" or not id then
        Print(GetString(EZOARM_MSG_CP_KIT_EMPTY))
        return
    end

    runtime.newCpKitName = ""
    runtime.selectedCpKitId = id
    ForcePanelRebuild()
    Print(zo_strformat(GetString(EZOARM_MSG_CP_KIT_CREATED), name))
end

local function ShowSelectedCpKit()
    local runtime = Runtime()
    local kit = EZOArmory.Champion.GetKit(runtime.selectedCpKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end
    local names = EZOArmory.Champion.GetStarNames(kit)
    Print(string.format("%s: %s", tostring(kit.name), table.concat(names, ", ")))
end

local function DeleteSelectedCpKit()
    local runtime = Runtime()
    local kit = EZOArmory.Champion.GetKit(runtime.selectedCpKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end
    local name = tostring(kit.name)
    EZOArmory.Champion.DeleteKit(runtime.selectedCpKitId)
    ForcePanelRebuild()
    Print(zo_strformat(GetString(EZOARM_MSG_CP_KIT_DELETED), name))
end

local function DeleteSelectedKit()
    local runtime = Runtime()
    local kit = EZOArmory.Kits.GetKit(runtime.selectedKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end

    local name = tostring(kit.name)
    EZOArmory.Kits.DeleteKit(runtime.selectedKitId)
    RefreshKitDropdown()
    Print(zo_strformat(GetString(EZOARM_MSG_KIT_DELETED), name))
end

-- Lanza el equipado de una lista de kitIds y reporta el resultado en chat.
local function EquipKitIds(kitIds)
    EZOArmory.Equip.onQueued = function()
        Print(GetString(EZOARM_MSG_EQUIP_QUEUED))
    end

    EZOArmory.Equip.ApplyKits(kitIds, function(state)
        if state.error == "noLibAsync" then
            Print(GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
            return
        end
        if state.error == "empty" then
            Print(GetString(EZOARM_MSG_EQUIP_EMPTY))
            return
        end

        Print(zo_strformat(
            GetString(EZOARM_MSG_EQUIP_DONE), state.equipped, state.already, state.missing))
        if state.missing > 0 and #state.missingNames > 0 then
            Print(zo_strformat(
                GetString(EZOARM_MSG_EQUIP_MISSING), table.concat(state.missingNames, ", ")))
        end
    end)
end

local function EquipSelectedKit()
    local runtime = Runtime()
    if not EZOArmory.Kits.GetKit(runtime.selectedKitId) then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end
    EquipKitIds({ runtime.selectedKitId })
end

-- Informe por partes, el mismo que usa la ventana: equipar un objetivo puede
-- aplicar una build entera (equipo + habilidades + CP), no solo equipo.
local function ReportEquipPart(part, state)
    if EZOArmory.WindowBuilds and EZOArmory.WindowBuilds.ReportEquipPart then
        EZOArmory.WindowBuilds.ReportEquipPart(part, state)
    end
end

local function PrintNotEquipped(reason, trialTag)
    if reason == "incomplete" then
        Print(GetString(EZOARM_MSG_BUILD_INCOMPLETE))
        return
    end
    local trial = EZOArmory.Zones.GetTrialByTag(trialTag)
    Print(zo_strformat(GetString(EZOARM_MSG_EQUIP_NO_ASSIGNMENT),
        trial and trial.name or tostring(trialTag)))
end

-- Equipa lo asignado al objetivo seleccionado en el panel (con herencia). No
-- depende de donde estes: sirve para probar y para prepararte antes de entrar.
-- Resuelve por build y, si el objetivo aun no tiene, por los kits de antes.
local function EquipSelectedTarget()
    local runtime = Runtime()
    local mode, reason = EZOArmory.Builds.EquipForTarget(
        GetActiveRole(), runtime.selectedTrialTag, runtime.selectedTargetKey, ReportEquipPart)
    if not mode then
        PrintNotEquipped(reason, runtime.selectedTrialTag)
    end
end

-- Equipa lo aplicable a donde estas ahora mismo, segun el contexto.
local function EquipForCurrentLocation()
    local trial, targetKey = EZOArmory.Builds.GetCurrentTarget()
    if not trial then
        Print(GetString(EZOARM_MSG_EQUIP_NO_TRIAL))
        return
    end

    local mode, reason = EZOArmory.Builds.EquipForTarget(
        GetActiveRole(), trial.tag, targetKey, ReportEquipPart)
    if not mode then
        PrintNotEquipped(reason, trial.tag)
    end
end

-- Kits actualmente asignados al objetivo seleccionado (sin herencia).
local function CurrentTargetKitIds()
    local runtime = Runtime()
    return EZOArmory.Kits.GetStoredAssignment(
        GetActiveRole(), runtime.selectedTrialTag, runtime.selectedTargetKey)
end

local function IsKitOnCurrentTarget(kitId)
    for _, id in ipairs(CurrentTargetKitIds()) do
        if id == kitId then
            return true
        end
    end
    return false
end

-- Resumen del objetivo actual: una linea por kit con sus iconos, para ver de un
-- vistazo que aporta cada kit a la build.
local function CurrentTargetSummary()
    local ids = CurrentTargetKitIds()
    if #ids == 0 then
        return GetString(EZOARM_MSG_ASSIGN_EMPTY)
    end
    local lines = {}
    for _, id in ipairs(ids) do
        local kit = EZOArmory.Kits.GetKit(id)
        if kit then
            lines[#lines + 1] = KitLabel(kit)
        end
    end
    return table.concat(lines, "\n")
end

-- Choices del selector de kits de la seccion Asignaciones: iconos + nombre, y
-- una marca delante en los que ya estan asignados al objetivo actual (LAM no
-- permite deshabilitar entradas sueltas de un desplegable).
local function GetAssignKitChoices()
    local labels, values = {}, {}
    for _, kit in ipairs(EZOArmory.Kits.ListKits()) do
        local label = KitLabel(kit)
        if IsKitOnCurrentTarget(kit.id) then
            label = GetString(EZOARM_ASSIGNED_MARK) .. " " .. label
        end
        labels[#labels + 1] = label
        values[#values + 1] = kit.id
    end
    return labels, values
end

local function AddAssignKitToTarget()
    local runtime = Runtime()
    if not EZOArmory.Kits.GetKit(runtime.assignKitId) then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end
    if IsKitOnCurrentTarget(runtime.assignKitId) then
        return -- ya esta
    end
    local ids = CurrentTargetKitIds()
    ids[#ids + 1] = runtime.assignKitId
    EZOArmory.Kits.SetAssignment(
        GetActiveRole(), runtime.selectedTrialTag, runtime.selectedTargetKey, ids)
    ForcePanelRebuild()
end

local function RemoveAssignKitFromTarget()
    local runtime = Runtime()
    if not runtime.assignKitId then return end
    local ids = CurrentTargetKitIds()
    local kept = {}
    for _, id in ipairs(ids) do
        if id ~= runtime.assignKitId then
            kept[#kept + 1] = id
        end
    end
    EZOArmory.Kits.SetAssignment(
        GetActiveRole(), runtime.selectedTrialTag, runtime.selectedTargetKey,
        #kept > 0 and kept or nil)
    ForcePanelRebuild()
end

local function ClearTarget()
    local runtime = Runtime()
    EZOArmory.Kits.SetAssignment(
        GetActiveRole(), runtime.selectedTrialTag, runtime.selectedTargetKey, nil)
    ForcePanelRebuild()
end

local function ShowSelectedKit()
    local runtime = Runtime()
    local kit = EZOArmory.Kits.GetKit(runtime.selectedKitId)
    if not kit then
        Print(GetString(EZOARM_MSG_KIT_NONE_SELECTED))
        return
    end

    -- Una sola linea compacta: nombre del kit y sus piezas por slot.
    local parts = {}
    for _, def in ipairs(EZOArmory.Gear.SLOT_DEFS) do
        local piece = kit.pieces and kit.pieces[def.key]
        if piece then
            local label = piece.setName
            if label == nil or label == "" then
                label = piece.itemName or "?"
            end
            parts[#parts + 1] = string.format("%s: %s", def.key, label)
        end
    end

    Print(string.format("%s -> %s", tostring(kit.name), table.concat(parts, ", ")))
end

local BAR_STRING = {
    front = "EZOARM_MSG_BAR_FRONT",
    back = "EZOARM_MSG_BAR_BACK",
}

local function DescribeBar(barResult)
    local parts = {}
    for _, bucket in pairs(barResult.sets or {}) do
        local maxEquipped = bucket.maxEquipped or 0
        if maxEquipped > 0 then
            parts[#parts + 1] = string.format("%s %d/%d", bucket.setName, bucket.count, maxEquipped)
        else
            parts[#parts + 1] = string.format("%s %d", bucket.setName, bucket.count)
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return GetString(EZOARM_MSG_NO_SETS)
    end
    return table.concat(parts, ", ")
end

local function AnalyzeWornGear()
    local loadout = EZOArmory.Kits.BuildLoadoutFromWorn()
    local analysis = EZOArmory.Coherence.Analyze(loadout)

    for _, bar in ipairs(EZOArmory.Gear.BARS) do
        local barResult = analysis.bars[bar]
        if barResult then
            local stringId = _G[BAR_STRING[bar] or ""]
            local barName = stringId and GetString(stringId) or bar
            Print(string.format(
                "%s: %s (%d %s)",
                barName,
                DescribeBar(barResult),
                barResult.pieces or 0,
                GetString(EZOARM_MSG_PIECES)
            ))
        end
    end

    if EZOArmory.DebugLog then
        EZOArmory.DebugLog(string.format(
            "Worn analysis: ok=%s issues=%d",
            tostring(analysis.ok), #analysis.issues))
    end
end

-- --------------------------------------------------------------- Panel -----

local function BuildOptions()
    local roleLabels, roleValues = GetRoleChoices()
    local presetLabels, presetValues = GetCaptureChoices()
    local trialLabels, trialValues = GetTrialChoices()
    local targetLabels, targetValues = GetTargetChoices(Runtime().selectedTrialTag)
    local assignKitLabels, assignKitValues = GetAssignKitChoices()
    local skillKitLabels, skillKitValues = GetSkillKitChoices()
    local cpKitLabels, cpKitValues = GetCpKitChoices()
    RefreshKitChoices()

    -- Secciones planas (header + controles). No se usan submenus colapsables:
    -- un rebuild del panel bajo EZOCore recrea los controles y colapsaria los
    -- submenus, cerrando la seccion en la que estas trabajando.
    return {
        CreateInfoHeader(
            GetString(EZOARM_OPTION_GENERAL),
            GetString(EZOARM_OPTION_GENERAL_HEADER_TOOLTIP)
        ),
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_LANGUAGE),
            tooltip = GetString(EZOARM_OPTION_LANGUAGE_TOOLTIP),
            choices = GetLanguageChoices(),
            getFunc = function()
                return LanguageValueToLabel(GetConfiguredLanguage())
            end,
            setFunc = function(label)
                local value = LabelToLanguageValue(label)
                if EZOArmory.sv and EZOArmory.sv.general then
                    EZOArmory.sv.general.language = value
                end
                EZOArmory.ApplyLanguagePreference(value)
            end,
            disabled = function()
                return IsLanguageLocked() == true
            end,
            default = LanguageValueToLabel("auto"),
        },
        {
            type = "checkbox",
            name = GetString(EZOARM_OPTION_DEBUG_MODE),
            tooltip = GetString(EZOARM_OPTION_DEBUG_MODE_TOOLTIP),
            getFunc = function()
                return EZOArmory.IsDebugModeEnabled()
            end,
            setFunc = function(value)
                EZOArmory.SetDebugModeEnabled(value == true)
            end,
            default = false,
        },
        CreateInfoHeader(
            GetString(EZOARM_OPTION_KITS),
            GetString(EZOARM_OPTION_KITS_HEADER_TOOLTIP)
        ),
        {
            type = "checkbox",
            name = GetString(EZOARM_OPTION_ROLE_AUTO),
            tooltip = GetString(EZOARM_OPTION_ROLE_AUTO_TOOLTIP),
            getFunc = IsRoleAuto,
            setFunc = function(value)
                if EZOArmory.sv and EZOArmory.sv.general then
                    EZOArmory.sv.general.roleMode = (value == true) and "auto" or "manual"
                end
                ForcePanelRebuild()
            end,
            default = true,
            width = "half",
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_ROLE),
            tooltip = GetString(EZOARM_OPTION_ROLE_TOOLTIP),
            choices = roleLabels,
            choicesValues = roleValues,
            getFunc = GetActiveRole,
            setFunc = function(value)
                if EZOArmory.sv and EZOArmory.sv.general then
                    EZOArmory.sv.general.role = value
                end
                -- Las asignaciones son por rol: reconstruye para reflejarlas.
                ForcePanelRebuild()
            end,
            disabled = IsRoleAuto,
            default = "dd",
            width = "half",
        },
        {
            type = "editbox",
            name = GetString(EZOARM_OPTION_KIT_NAME),
            tooltip = GetString(EZOARM_OPTION_KIT_NAME_TOOLTIP),
            getFunc = function()
                return Runtime().newKitName
            end,
            setFunc = function(value)
                Runtime().newKitName = tostring(value or "")
            end,
            isMultiline = false,
            -- isExtraWide ancla el contenedor a ambos lados y evita el calculo
            -- de ancho de LAM que da 0 y colapsa el campo.
            isExtraWide = true,
            width = "full",
            default = "",
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_KIT_PRESET),
            tooltip = GetString(EZOARM_OPTION_KIT_PRESET_TOOLTIP),
            choices = presetLabels,
            choicesValues = presetValues,
            getFunc = function()
                return Runtime().capturePreset
            end,
            setFunc = function(value)
                Runtime().capturePreset = value
            end,
            default = "all",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_CAPTURE),
            tooltip = GetString(EZOARM_OPTION_KIT_CAPTURE_TOOLTIP),
            func = CaptureKit,
            width = "full",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_CAPTURE_ALL),
            tooltip = GetString(EZOARM_OPTION_KIT_CAPTURE_ALL_TOOLTIP),
            func = CaptureAllSets,
            width = "full",
        },
        {
            type = "dropdown",
            reference = KIT_LIST_REFERENCE,
            name = GetString(EZOARM_OPTION_KIT_LIST),
            tooltip = GetString(EZOARM_OPTION_KIT_LIST_TOOLTIP),
            choices = kitChoices,
            choicesValues = kitChoiceValues,
            getFunc = function()
                return Runtime().selectedKitId
            end,
            setFunc = function(value)
                Runtime().selectedKitId = value
            end,
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_EQUIP),
            tooltip = GetString(EZOARM_OPTION_KIT_EQUIP_TOOLTIP),
            func = EquipSelectedKit,
            width = "full",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_SHOW),
            tooltip = GetString(EZOARM_OPTION_KIT_SHOW_TOOLTIP),
            func = ShowSelectedKit,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_DELETE),
            tooltip = GetString(EZOARM_OPTION_KIT_DELETE_TOOLTIP),
            func = DeleteSelectedKit,
            isDangerous = true,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_ANALYZE_WORN),
            tooltip = GetString(EZOARM_OPTION_ANALYZE_WORN_TOOLTIP),
            func = AnalyzeWornGear,
            width = "full",
        },
        CreateInfoHeader(
            GetString(EZOARM_OPTION_SKILL_KITS),
            GetString(EZOARM_OPTION_SKILL_KITS_HEADER_TOOLTIP)
        ),
        {
            type = "editbox",
            name = GetString(EZOARM_OPTION_SKILL_KIT_NAME),
            tooltip = GetString(EZOARM_OPTION_SKILL_KIT_NAME_TOOLTIP),
            getFunc = function()
                return Runtime().newSkillKitName or ""
            end,
            setFunc = function(value)
                Runtime().newSkillKitName = tostring(value or "")
            end,
            isMultiline = false,
            isExtraWide = true,
            width = "full",
            default = "",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_SKILL_KIT_CAPTURE),
            tooltip = GetString(EZOARM_OPTION_SKILL_KIT_CAPTURE_TOOLTIP),
            func = CaptureSkillKit,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_SKILL_KIT_LIST),
            tooltip = GetString(EZOARM_OPTION_SKILL_KIT_LIST_TOOLTIP),
            choices = skillKitLabels,
            choicesValues = skillKitValues,
            getFunc = function()
                return Runtime().selectedSkillKitId
            end,
            setFunc = function(value)
                Runtime().selectedSkillKitId = value
            end,
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_SHOW),
            tooltip = GetString(EZOARM_OPTION_SKILL_KIT_SHOW_TOOLTIP),
            func = ShowSelectedSkillKit,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_DELETE),
            tooltip = GetString(EZOARM_OPTION_SKILL_KIT_DELETE_TOOLTIP),
            func = DeleteSelectedSkillKit,
            isDangerous = true,
            width = "half",
        },
        CreateInfoHeader(
            GetString(EZOARM_OPTION_CP_KITS),
            GetString(EZOARM_OPTION_CP_KITS_HEADER_TOOLTIP)
        ),
        {
            type = "editbox",
            name = GetString(EZOARM_OPTION_CP_KIT_NAME),
            tooltip = GetString(EZOARM_OPTION_CP_KIT_NAME_TOOLTIP),
            getFunc = function()
                return Runtime().newCpKitName or ""
            end,
            setFunc = function(value)
                Runtime().newCpKitName = tostring(value or "")
            end,
            isMultiline = false,
            isExtraWide = true,
            width = "full",
            default = "",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_CP_KIT_CAPTURE),
            tooltip = GetString(EZOARM_OPTION_CP_KIT_CAPTURE_TOOLTIP),
            func = CaptureCpKit,
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_CP_KIT_LIST),
            tooltip = GetString(EZOARM_OPTION_CP_KIT_LIST_TOOLTIP),
            choices = cpKitLabels,
            choicesValues = cpKitValues,
            getFunc = function()
                return Runtime().selectedCpKitId
            end,
            setFunc = function(value)
                Runtime().selectedCpKitId = value
            end,
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_SHOW),
            tooltip = GetString(EZOARM_OPTION_CP_KIT_SHOW_TOOLTIP),
            func = ShowSelectedCpKit,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_KIT_DELETE),
            tooltip = GetString(EZOARM_OPTION_CP_KIT_DELETE_TOOLTIP),
            func = DeleteSelectedCpKit,
            isDangerous = true,
            width = "half",
        },
        CreateInfoHeader(
            GetString(EZOARM_OPTION_ASSIGN),
            GetString(EZOARM_OPTION_ASSIGN_HEADER_TOOLTIP)
        ),
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_ASSIGN_TRIAL),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_TRIAL_TOOLTIP),
            choices = trialLabels,
            choicesValues = trialValues,
            getFunc = function()
                return Runtime().selectedTrialTag
            end,
            setFunc = function(value)
                local runtime = Runtime()
                runtime.selectedTrialTag = value
                runtime.selectedTargetKey = ASSIGN_TARGET_DEFAULT
                ForcePanelRebuild()
            end,
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_ASSIGN_TARGET),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_TARGET_TOOLTIP),
            choices = targetLabels,
            choicesValues = targetValues,
            getFunc = function()
                return Runtime().selectedTargetKey
            end,
            setFunc = function(value)
                Runtime().selectedTargetKey = value
                ForcePanelRebuild()
            end,
        },
        {
            type = "dropdown",
            name = GetString(EZOARM_OPTION_ASSIGN_PICK),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_PICK_TOOLTIP),
            choices = assignKitLabels,
            choicesValues = assignKitValues,
            getFunc = function()
                return Runtime().assignKitId
            end,
            setFunc = function(value)
                Runtime().assignKitId = value
            end,
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_ASSIGN_ADD),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_ADD_TOOLTIP),
            func = AddAssignKitToTarget,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_ASSIGN_REMOVE),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_REMOVE_TOOLTIP),
            func = RemoveAssignKitFromTarget,
            width = "half",
        },
        {
            type = "description",
            title = GetString(EZOARM_OPTION_ASSIGN_CURRENT),
            text = CurrentTargetSummary(),
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_EQUIP_TARGET),
            tooltip = GetString(EZOARM_OPTION_EQUIP_TARGET_TOOLTIP),
            func = EquipSelectedTarget,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_EQUIP_HERE),
            tooltip = GetString(EZOARM_OPTION_EQUIP_HERE_TOOLTIP),
            func = EquipForCurrentLocation,
            width = "half",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_ASSIGN_CLEAR),
            tooltip = GetString(EZOARM_OPTION_ASSIGN_CLEAR_TOOLTIP),
            func = ClearTarget,
            isDangerous = true,
            width = "half",
        },
    }
end

function EZOArmory_Menu.Refresh()
    RefreshKitChoices()
end

function EZOArmory_Menu.Init()
    if not LibAddonMenu2 then
        return
    end

    local panelData = {
        type = "panel",
        name = "EZOArmory",
        displayName = "E|cB040FFZ|rOArmory",
        author = EZOArmory.AUTHOR,
        version = EZOArmory.ADDON_VERSION,
        ezoStage = "development",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    -- A EZOCore se le pasa la FUNCION: la re-ejecuta en cada rebuild, asi el
    -- contenido calculado en build (descripcion de la asignacion, listas) se
    -- refresca. LAM directo no desenvuelve funciones, asi que ahi se pasa la
    -- tabla ya construida (su panel no se reconstruye en vivo de todos modos).
    if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
        local registered = EZOCore:RegisterSettingsPanel(ADDON_NAME, PANEL_ID, panelData, BuildOptions)
        if registered then
            EZOArmory.ezoSettingsRegistered = true
            return
        end
    end

    EZOArmory._lamPanel = LibAddonMenu2:RegisterAddonPanel(PANEL_ID, panelData)
    LibAddonMenu2:RegisterOptionControls(PANEL_ID, BuildOptions())
end
