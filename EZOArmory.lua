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

-- Rol seleccionado en el buscador de grupo del jugador, traducido a los roles
-- del addon. Devuelve "tank", "healer", "dd" o nil si no se puede detectar.
function EZOA.GetDetectedRole()
    if type(GetSelectedLFGRole) ~= "function" then
        return nil
    end
    local ok, role = pcall(GetSelectedLFGRole)
    if not ok then
        return nil
    end
    if role == LFG_ROLE_TANK then
        return "tank"
    end
    if role == LFG_ROLE_HEAL then
        return "healer"
    end
    if role == LFG_ROLE_DPS then
        return "dd"
    end
    return nil
end

local ROLE_STRING = {
    dd = "EZOARM_ROLE_DD",
    tank = "EZOARM_ROLE_TANK",
    healer = "EZOARM_ROLE_HEALER",
}

-- Nombre mostrable de un rol ("dd"/"tank"/"healer"). Compartido por el panel
-- LAM y la pestana de asignaciones de la ventana propia.
function EZOA.RoleLabel(role)
    local stringId = _G[ROLE_STRING[role] or ""]
    if stringId then
        return GetString(stringId)
    end
    return tostring(role)
end

local SLOT_LABEL_STRING = {
    head = "EZOARM_SLOT_HEAD",
    shoulders = "EZOARM_SLOT_SHOULDERS",
    chest = "EZOARM_SLOT_CHEST",
    waist = "EZOARM_SLOT_WAIST",
    hands = "EZOARM_SLOT_HANDS",
    legs = "EZOARM_SLOT_LEGS",
    feet = "EZOARM_SLOT_FEET",
    neck = "EZOARM_SLOT_NECK",
    ring1 = "EZOARM_SLOT_RING1",
    ring2 = "EZOARM_SLOT_RING2",
    main = "EZOARM_SLOT_MAIN",
    off = "EZOARM_SLOT_OFF",
    backupMain = "EZOARM_SLOT_BACKUP_MAIN",
    backupOff = "EZOARM_SLOT_BACKUP_OFF",
}

-- Nombre mostrable de un slot de equipo. Compartido por el panel LAM y por las
-- revisiones de build de la ventana propia.
function EZOA.SlotLabel(slotKey)
    local stringId = _G[SLOT_LABEL_STRING[slotKey or ""] or ""]
    if stringId then
        return GetString(stringId)
    end
    return tostring(slotKey)
end

-- Nombre mostrable de una barra ("front" / "back").
function EZOA.BarLabel(bar)
    if bar == "back" then
        return GetString(EZOARM_MSG_BAR_BACK)
    end
    return GetString(EZOARM_MSG_BAR_FRONT)
end

local ARMOR_TYPE_STRING = {}
if ARMORTYPE_LIGHT then ARMOR_TYPE_STRING[ARMORTYPE_LIGHT] = "EZOARM_ARMOR_LIGHT" end
if ARMORTYPE_MEDIUM then ARMOR_TYPE_STRING[ARMORTYPE_MEDIUM] = "EZOARM_ARMOR_MEDIUM" end
if ARMORTYPE_HEAVY then ARMOR_TYPE_STRING[ARMORTYPE_HEAVY] = "EZOARM_ARMOR_HEAVY" end

-- Peso de armadura mostrable ("Light"/"Medium"/"Heavy") o nil si la pieza no
-- es armadura (joyeria, armas). Compartido por el panel LAM (nombre sugerido
-- al capturar) y la ventana propia (distinguir piezas del mismo set y slot).
function EZOA.ArmorTypeLabel(armorType)
    local sid = _G[ARMOR_TYPE_STRING[armorType] or ""]
    if sid then
        return GetString(sid)
    end
    return nil
end

local CATEGORY_STRING = {
    armor = "EZOARM_CAT_ARMOR",
    jewelry = "EZOARM_CAT_JEWELRY",
    weaponsFront = "EZOARM_CAT_WEAPONS_FRONT",
    weaponsBack = "EZOARM_CAT_WEAPONS_BACK",
}

-- Pista textual compacta de donde va un kit: categorias presentes.
local function CategoryHint(slots)
    local parts = {}
    for _, category in ipairs(EZOArmory.Gear.GetCategoryKeys(slots)) do
        local stringId = _G[CATEGORY_STRING[category] or ""]
        parts[#parts + 1] = stringId and GetString(stringId) or category
    end
    return table.concat(parts, " + ")
end

-- Nombre sugerido al capturar: palabra clave del set mas su ubicacion, para que
-- dos kits del mismo set en sitios distintos no se confundan. Para una pieza
-- unica se usa el slot exacto y, si es armadura, su peso (asi una cabeza ligera
-- y una media del mismo set no acaban con el mismo nombre numerado).
-- Compartido por el panel LAM y por la captura desde la ventana propia.
function EZOA.BuildKitName(setName, slots, entry)
    local keyword = EZOArmory.Kits.KeywordFromSetName(setName)
    local hint
    if slots and #slots == 1 then
        hint = EZOA.SlotLabel(slots[1])
        local armorLabel = entry and EZOA.ArmorTypeLabel(entry.armorType)
        if armorLabel then
            hint = string.format("%s (%s)", hint, armorLabel)
        end
    else
        hint = CategoryHint(slots)
    end
    if hint == nil or hint == "" then
        return keyword
    end
    return string.format("%s - %s", keyword, hint)
end

-- Nombre automatico libre dentro de una lista de kits ya existentes:
-- "Skills 1", "Skills 2"... Se usa al capturar sin dar nombre.
function EZOA.AutoKitName(baseStringId, listFn)
    local taken = {}
    for _, kit in ipairs(listFn()) do
        taken[tostring(kit.name)] = true
    end
    local base = GetString(baseStringId)
    local index = 1
    while taken[base .. " " .. index] do
        index = index + 1
    end
    return base .. " " .. index
end

function EZOA.IsRoleAuto()
    return EZOA.sv
        and EZOA.sv.general
        and EZOA.sv.general.roleMode ~= "manual"
end

-- Rol activo: en modo automatico, el rol elegido en el buscador de grupo del
-- juego; si no se puede detectar (o en modo manual), el guardado en opciones.
-- Unica fuente de verdad para el rol: la usan tanto el panel LAM como la
-- pestana de asignaciones de la ventana propia.
function EZOA.GetActiveRole()
    if EZOA.IsRoleAuto() then
        local detected = EZOA.GetDetectedRole()
        if detected then
            return detected
        end
    end
    if EZOA.sv and EZOA.sv.general and EZOA.sv.general.role then
        return EZOA.sv.general.role
    end
    return "dd"
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

    -- Despues del contexto: se suscribe a sus cambios.
    if EZOArmory.AutoEquip and EZOArmory.AutoEquip.Init then
        EZOArmory.AutoEquip.Init()
    end

    if EZOArmory_Menu and EZOArmory_Menu.Init then
        EZOArmory_Menu.Init()
    end

    if EZOA.Window and EZOA.Window.Init then
        EZOA.Window.Init()
    end

    SLASH_COMMANDS["/ezoarmory"] = function()
        EZOArmory_ToggleWindow()
    end

    Print(GetString(EZOARM_MSG_INIT))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EZOArmory:Initialize()
end)
