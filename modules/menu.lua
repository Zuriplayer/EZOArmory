-- Panel de configuracion LibAddonMenu.
--
-- Congelado desde que la ventana propia asumio la gestion de kits, builds y
-- asignaciones (fases 3-5): capturar/listar/equipar/borrar/renombrar kits de
-- equipo, habilidades y CP, componer builds y asignarlas a trial/boss, todo
-- eso vive ahora solo en la ventana. Este panel se queda con lo que NO tiene
-- equivalente alli: ajustes generales (idioma, marca de inventario, modo
-- depuracion), el modo de rol (automatico/manual), un analisis rapido de lo
-- que se lleva puesto ahora mismo, y el reset a valores por defecto.
EZOArmory_Menu = EZOArmory_Menu or {}

local ADDON_NAME = "EZOArmory"
local PANEL_ID = ADDON_NAME .. "_Options"
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"

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

-- Fuerza un rebuild del panel un frame despues. Bajo EZOCore los controles se
-- renombran y no se pueden actualizar por "reference"; reconstruir es la via
-- fiable para reflejar cambios de opciones dinamicas. Se aplaza para no
-- destruir el control cuyo callback corre ahora.
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

-- ------------------------------------------------------- Analisis rapido ---
-- Que bonus de set estan realmente activos con lo que llevas puesto AHORA
-- MISMO. Distinto de todo lo demas del panel: no lee ningun kit guardado, asi
-- que no tiene equivalente en la ventana.

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

-- ------------------------------------------------------- Reset a defaults --
-- Dialogo de confirmacion, mismo patron verificado en produccion que el
-- renombrado de kits (window_kits.lua) y el confirm de EZOTools:
-- ZO_Dialogs_RegisterCustomDialog + ZO_Dialogs_ShowDialog.

local RESET_DIALOG_NAME = "EZOARMORY_RESET_DEFAULTS"
local resetDialogRegistered = false

local function EnsureResetDialog()
    if resetDialogRegistered then return true end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return false end

    ZO_Dialogs_RegisterCustomDialog(RESET_DIALOG_NAME, {
        canQueue = true,
        title = { text = GetString(EZOARM_DIALOG_RESET_TITLE) },
        mainText = { text = GetString(EZOARM_DIALOG_RESET_TEXT) },
        buttons = {
            [1] = {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function()
                    if not (EZOArmory.savedVars and EZOArmory.savedVars.ResetToDefaults) then
                        return
                    end
                    EZOArmory.savedVars.ResetToDefaults()

                    -- Lo que no basta con releer sv se aplica en vivo aqui,
                    -- igual que hace cada setFunc normal del panel.
                    EZOArmory.ApplyLanguagePreference(EZOArmory.sv.general.language)
                    if EZOArmory.Markers then
                        EZOArmory.Markers.Invalidate()
                        EZOArmory.Markers.Init()
                    end
                    if EZOArmory.Window and EZOArmory.Window.ResetPosition then
                        EZOArmory.Window.ResetPosition()
                    end
                    if EZOArmory.AutoEquip and EZOArmory.AutoEquip.Reset then
                        EZOArmory.AutoEquip.Reset()
                    end
                    if EZOArmory.WindowKits and EZOArmory.WindowKits.RefreshAssignPanel then
                        EZOArmory.WindowKits.RefreshAssignPanel()
                    end

                    ForcePanelRebuild()
                    Print(GetString(EZOARM_MSG_RESET_DONE))
                end,
            },
            [2] = {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
        },
    })
    resetDialogRegistered = true
    return true
end

local function OnResetDefaultsClicked()
    if not EnsureResetDialog() or type(ZO_Dialogs_ShowDialog) ~= "function" then return end
    ZO_Dialogs_ShowDialog(RESET_DIALOG_NAME)
end

-- --------------------------------------------------------------- Panel -----

local function BuildOptions()
    local roleLabels, roleValues = GetRoleChoices()

    -- Seccion plana (header + controles). No se usan submenus colapsables: un
    -- rebuild del panel bajo EZOCore recrea los controles y colapsaria los
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
            name = GetString(EZOARM_OPTION_INVENTORY_MARKER),
            tooltip = GetString(EZOARM_OPTION_INVENTORY_MARKER_TOOLTIP),
            getFunc = function()
                return EZOArmory.Markers and EZOArmory.Markers.IsEnabled() or false
            end,
            setFunc = function(value)
                if EZOArmory.sv and EZOArmory.sv.general then
                    EZOArmory.sv.general.inventoryMarker = value == true
                end
                if EZOArmory.Markers then
                    EZOArmory.Markers.Invalidate()
                    -- Enganchar los inventarios solo se puede hacer una vez;
                    -- si estaba apagado al cargar, hace falta recargar.
                    EZOArmory.Markers.Init()
                end
            end,
            default = true,
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
            type = "button",
            name = GetString(EZOARM_OPTION_ANALYZE_WORN),
            tooltip = GetString(EZOARM_OPTION_ANALYZE_WORN_TOOLTIP),
            func = AnalyzeWornGear,
            width = "full",
        },
        {
            type = "button",
            name = GetString(EZOARM_OPTION_RESET_DEFAULTS),
            tooltip = GetString(EZOARM_OPTION_RESET_DEFAULTS_TOOLTIP),
            func = OnResetDefaultsClicked,
            isDangerous = true,
            width = "full",
        },
    }
end

function EZOArmory_Menu.Refresh()
    -- Ya no hay listas dinamicas que releer aqui (kits/builds se gestionan en
    -- la ventana); se deja como punto de enganche para EZOCore.
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
    -- contenido calculado en build se refresca. LAM directo no desenvuelve
    -- funciones, asi que ahi se pasa la tabla ya construida (su panel no se
    -- reconstruye en vivo de todos modos).
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
