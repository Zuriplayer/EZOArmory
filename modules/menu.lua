-- Panel de configuracion LibAddonMenu.
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

local function BuildOptions()
    return {
        {
            type = "submenu",
            name = GetString(EZOARM_OPTION_GENERAL),
            controls = {
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
            },
        },
    }
end

function EZOArmory_Menu.Refresh()
    if EZOArmory._lamPanel and LibAddonMenu2 and type(LibAddonMenu2.util) == "table" then
        -- Deja que LAM refresque los valores mostrados si el panel es propio.
        if type(LibAddonMenu2.util.RequestRefreshIfNeeded) == "function" then
            LibAddonMenu2.util.RequestRefreshIfNeeded(EZOArmory._lamPanel)
        end
    end
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

    local options = BuildOptions()

    if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
        local registered = EZOCore:RegisterSettingsPanel(ADDON_NAME, PANEL_ID, panelData, options)
        if registered then
            EZOArmory.ezoSettingsRegistered = true
            return
        end
    end

    EZOArmory._lamPanel = LibAddonMenu2:RegisterAddonPanel(PANEL_ID, panelData)
    LibAddonMenu2:RegisterOptionControls(PANEL_ID, options)
end
