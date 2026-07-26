-- Arranque principal del addon.
EZOArmory = EZOArmory or {}
local EZOA = EZOArmory

local ADDON_NAME = "EZOArmory"
local LANGUAGE_INHERIT = "inherit"
local LANGUAGE_AUTO = "auto"
EZOA.LANGUAGE_INHERIT = LANGUAGE_INHERIT
EZOA.LANGUAGE_AUTO = LANGUAGE_AUTO

local languageCallbackRegistered = false
local ezocoreRegistered = false
local debugControllerRegistered = false

local function Print(message)
    if LibChatMessage then
        LibChatMessage(ADDON_NAME, "EZOA"):Print(tostring(message))
    else
        d(tostring(message))
    end
end

EZOA.Print = Print

local function GetClientLanguage()
    if type(GetCVar) == "function" then
        local language = zo_strlower(tostring(GetCVar("Language.2") or ""))
        local prefix = language:sub(1, 2)
        if prefix == "es" then return "es" end
        if prefix == "en" then return "en" end
    end
    return "en"
end

function EZOA.GetDefaultLanguage()
    return LANGUAGE_AUTO
end

function EZOA.GetClientLanguage()
    return GetClientLanguage()
end

function EZOA.IsLanguageManagedByEZOCore()
    if not (EZOCore and type(EZOCore.IsLanguageGloballyManaged) == "function") then
        return false
    end
    local ok, managed = pcall(function()
        return EZOCore:IsLanguageGloballyManaged()
    end)
    return ok and managed == true
end

function EZOA.GetEffectiveLanguage(language)
    language = tostring(language or EZOA.GetDefaultLanguage())
    if EZOA.IsLanguageManagedByEZOCore() then
        local ok, inherited = pcall(function()
            return EZOCore:GetLanguage()
        end)
        if ok and (inherited == "es" or inherited == "en") then
            return inherited
        end
    end
    if language == LANGUAGE_INHERIT then
        language = LANGUAGE_AUTO
    end
    if language == "es" or language == "en" then
        return language
    end
    return GetClientLanguage()
end

function EZOA.IsForcedLanguage(language)
    language = tostring(language or EZOA.GetDefaultLanguage())
    if EZOA.IsLanguageManagedByEZOCore() then
        return false
    end
    return language == "es" or language == "en"
end

function EZOA.ApplyLanguagePreference(language)
    local configuredLanguage = tostring(language or EZOA.GetDefaultLanguage())
    if EZOArmory_Lang and EZOArmory_Lang.Apply then
        EZOArmory_Lang.Apply(configuredLanguage)
    end
end

function EZOA.RegisterEZOCoreLanguageCallback()
    if languageCallbackRegistered
        or not (EZOCore and type(EZOCore.RegisterCallback) == "function") then
        return false
    end

    local eventName = EZOCore.EVENT_LANGUAGE_CHANGED or "EZO_CORE_LANGUAGE_CHANGED"
    local ok, result = pcall(function()
        return EZOCore:RegisterCallback(eventName, function()
            if EZOA.sv and EZOA.sv.general then
                EZOA.ApplyLanguagePreference(EZOA.sv.general.language or EZOA.GetDefaultLanguage())
                if EZOArmory_Menu and EZOArmory_Menu.Refresh then
                    EZOArmory_Menu.Refresh()
                end
            end
        end)
    end)
    languageCallbackRegistered = ok and result == true
    return languageCallbackRegistered
end

function EZOA.RegisterWithEZOCore()
    if ezocoreRegistered
        or not (EZOCore and type(EZOCore.RegisterAddon) == "function") then
        return false
    end

    local ok, result = pcall(function()
        return EZOCore:RegisterAddon({
            id = "ezoarmory",
            name = EZOA.ADDON_NAME or ADDON_NAME,
            version = EZOA.ADDON_VERSION or "0.0.0",
            addOnVersion = 100,
            apiVersion = 1,
            capabilities = {
                "gear.loadouts",
                "gear.setKits",
                "family.debug.controller",
                "family.language.consumer",
                "family.layout.consumer",
                "family.settings.consumer",
            },
        })
    end)

    ezocoreRegistered = ok and result == true
    return ezocoreRegistered
end

function EZOA.IsDebugModeEnabled()
    return EZOA.sv and EZOA.sv.general and EZOA.sv.general.debugMode == true
end

function EZOA.SetDebugModeEnabled(enabled)
    if not (EZOA.sv and EZOA.sv.general) then
        return false
    end
    EZOA.sv.general.debugMode = enabled == true
    return EZOA.sv.general.debugMode == (enabled == true)
end

function EZOA.RegisterDebugWithEZOCore()
    if debugControllerRegistered
        or not (EZOCore and type(EZOCore.GetService) == "function") then
        return false
    end

    local service = EZOCore:GetService("family.debug", 1)
    if not service or type(service.RegisterController) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return service:RegisterController({
            id = "ezoarmory.debug",
            addonId = "ezoarmory",
            addonName = "EZOArmory",
            name = function() return GetString(EZOARM_OPTION_DEBUG_MODE) end,
            isEnabled = EZOA.IsDebugModeEnabled,
            setEnabled = function(enabled)
                return EZOA.SetDebugModeEnabled(enabled == true)
            end,
        })
    end)

    debugControllerRegistered = ok and result == true
    return debugControllerRegistered
end

function EZOA:Initialize()
    if self.savedVars and self.savedVars.Init then
        self.savedVars.Init()
    end

    local language = self.sv and self.sv.general and self.sv.general.language or EZOA.GetDefaultLanguage()
    EZOA.ApplyLanguagePreference(language)
    EZOA.RegisterEZOCoreLanguageCallback()
    EZOA.RegisterWithEZOCore()
    EZOA.RegisterDebugWithEZOCore()
    self.runtime = self.runtime or {}

    if self.DebugLog then
        self.DebugLog("SavedVariables loaded")
    end

    if EZOArmory.Context and EZOArmory.Context.Init then
        EZOArmory.Context.Init()
    end

    if EZOArmory_Menu and EZOArmory_Menu.Init then
        EZOArmory_Menu.Init()
    end

    Print(GetString(EZOARM_MSG_INIT))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EZOArmory:Initialize()
end)
