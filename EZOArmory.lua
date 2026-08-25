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

-- Neutraliza el area de rueda de raton de un ZO_ScrollContainer (su hijo
-- llamado "Scroll", NO el ScrollChild que aloja el contenido, y NO la barra de
-- desplazamiento). Verificado en esoui/libraries/zo_templates/scrolltemplates
-- (ZO_Scroll_Initialize guarda ese hijo como self.scroll) y confirmado con
-- log de depuracion propio: esa area cubre TODO el visible de la lista, por
-- delante de las filas, y el motor la vuelve a habilitar sola
-- (ZO_Scroll_UpdateScrollBar: scroll:SetMouseEnabled(scrollEnabled)) cada vez
-- que hay contenido para desplazar. Justo entonces dejaban de recibir el
-- cursor los elementos de las filas por debajo (iconos de equipo, de
-- habilidad, chips de CP): con listas cortas (sin scroll) nunca se activaba y
-- funcionaba; con listas largas si, y dejaba de funcionar.
--
-- Se sobreescribe el metodo por instancia (no una funcion global) para que
-- cualquier futura llamada del propio motor tambien quede anulada, sin tener
-- que perseguir cuando se dispara.
--
-- La rueda del raton NO se pierde por ello: se vuelve a enganchar a mano en el
-- propio contenedor, que no tapa a nadie. ZO_Scroll_OnMouseWheel es una
-- funcion global del motor (esoui/libraries/zo_templates/scrolltemplates.lua)
-- y es exactamente la que el area "Scroll" invocaba desde su XML
-- (ZO_Scroll_OnMouseWheel(self:GetParent(), delta)), asi que llamarla
-- directamente da el mismo desplazamiento sin necesidad de ese area. Hasta
-- 0.11.27 se daba por perdida la rueda como coste asumido del arreglo; no
-- hacia falta.
function EZOA.DisableScrollWheelArea(scrollContainer)
    if not scrollContainer or type(scrollContainer.GetNamedChild) ~= "function" then
        return
    end
    local scrollArea = scrollContainer:GetNamedChild("Scroll")
    if not scrollArea or type(scrollArea.SetMouseEnabled) ~= "function" then
        return
    end
    scrollArea:SetMouseEnabled(false)
    scrollArea.SetMouseEnabled = function() end

    -- Rueda sobre el contenedor: mismo efecto que tenia el area desactivada.
    if type(scrollContainer.SetHandler) == "function"
        and type(ZO_Scroll_OnMouseWheel) == "function" then
        scrollContainer:SetMouseEnabled(true)
        scrollContainer:SetHandler("OnMouseWheel", function(control, delta)
            ZO_Scroll_OnMouseWheel(control, delta)
        end)
    end

    if EZOA.DebugLog then
        EZOA.DebugLog("DisableScrollWheelArea: applied to " .. tostring(scrollContainer:GetName()))
    end
end

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

    if EZOArmory.Markers and EZOArmory.Markers.Init then
        EZOArmory.Markers.Init()
    end

    -- Rastreo de banco/cofre abierto. Va antes del menu: es lo que decide si
    -- las entradas se muestran, y hace falta aunque no exista LibCustomMenu.
    if EZOArmory.Storage and EZOArmory.Storage.InitEvents then
        EZOArmory.Storage.InitEvents()
    end

    -- Menu contextual del inventario para guardar/sacar builds del banco. Se
    -- rinde solo si falta LibCustomMenu, que es opcional a proposito.
    if EZOArmory.StorageMenu and EZOArmory.StorageMenu.Init then
        EZOArmory.StorageMenu.Init()
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

    -- Diagnostico de desvestir. Escribe POR CHAT, no al log: la version
    -- anterior mandaba todo esto a LibDebugLogger y con el modo depuracion
    -- apagado (que es lo normal) no media absolutamente nada. Un diagnostico
    -- que depende de una opcion que hay que acordarse de encender no sirve.
    --
    -- Ademas desequipa DIRECTAMENTE, en un bucle normal y sin LibAsync, en vez
    -- de por la cola de Equip.UndressAll. Asi separa dos cosas: si por aqui se
    -- desviste, el fallo esta en la cola o en el boton; si tampoco, esta en la
    -- llamada del juego y hay que mirar hacia otro lado.
    SLASH_COMMANDS["/ezoarmoryundress"] = function()
        local Gear = EZOA.Gear
        if not Gear then
            Print("EZOArmory: modulo Gear no cargado.")
            return
        end

        Print(string.format("EZOArmory: listo=%s, huecos libres=%s",
            tostring(EZOA.Equip and EZOA.Equip.IsReady()),
            tostring(type(GetNumBagFreeSlots) == "function"
                and GetNumBagFreeSlots(BAG_BACKPACK) or "?")))

        local found, sent, failed = 0, 0, {}
        for _, def in ipairs(Gear.SLOT_DEFS) do
            local equipSlot = Gear.GetEquipSlotId(def.key)
            if equipSlot == nil then
                failed[#failed + 1] = def.key .. ":sin-constante"
            elseif HasItemInSlot(BAG_WORN, equipSlot) then
                found = found + 1
                local ok, err = pcall(RequestUnequipItem, BAG_WORN, equipSlot)
                if ok then
                    sent = sent + 1
                else
                    failed[#failed + 1] = def.key .. ":" .. tostring(err)
                end
            end
        end

        Print(string.format("EZOArmory: %d puestas, %d peticiones enviadas.",
            found, sent))
        if #failed > 0 then
            Print("EZOArmory: fallos -> " .. table.concat(failed, " | "))
        end

        -- Se comprueba despues, no en el momento: la peticion de desequipar no
        -- es instantanea y contar aqui mismo diria siempre que no ha pasado.
        zo_callLater(function()
            local stillOn = {}
            for _, def in ipairs(Gear.SLOT_DEFS) do
                local equipSlot = Gear.GetEquipSlotId(def.key)
                if equipSlot and HasItemInSlot(BAG_WORN, equipSlot) then
                    stillOn[#stillOn + 1] = def.key
                end
            end
            if #stillOn == 0 then
                Print("EZOArmory: no queda nada puesto.")
            else
                Print("EZOArmory: siguen puestas -> " .. table.concat(stillOn, ", "))
            end
        end, 800)
    end
    Print(GetString(EZOARM_MSG_INIT))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EZOArmory:Initialize()
end)
