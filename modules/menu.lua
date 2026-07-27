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

local ROLE_STRING = {
    dd = "EZOARM_ROLE_DD",
    tank = "EZOARM_ROLE_TANK",
    healer = "EZOARM_ROLE_HEALER",
}

local function RoleLabel(role)
    local stringId = _G[ROLE_STRING[role] or ""]
    if stringId then
        return GetString(stringId)
    end
    return tostring(role)
end

local function GetRoleChoices()
    local labels, values = {}, {}
    for _, role in ipairs(EZOArmory.Kits.ROLES) do
        labels[#labels + 1] = RoleLabel(role)
        values[#values + 1] = role
    end
    return labels, values
end

local function GetActiveRole()
    if EZOArmory.sv and EZOArmory.sv.general and EZOArmory.sv.general.role then
        return EZOArmory.sv.general.role
    end
    return "dd"
end

-- ---------------------------------------------------------- Presets kit ----

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

local CATEGORY_STRING = {
    armor = "EZOARM_CAT_ARMOR",
    jewelry = "EZOARM_CAT_JEWELRY",
    weaponsFront = "EZOARM_CAT_WEAPONS_FRONT",
    weaponsBack = "EZOARM_CAT_WEAPONS_BACK",
}
local CATEGORY_ORDER = { "armor", "jewelry", "weaponsFront", "weaponsBack" }

local function SlotLabel(slotKey)
    local sid = _G[SLOT_LABEL_STRING[slotKey] or ""]
    return sid and GetString(sid) or tostring(slotKey)
end

-- Categoria de un slot para la pista compacta de los sets.
local function SlotCategory(slotKey)
    local def = EZOArmory.Gear.GetSlotDef(slotKey)
    if not def then return nil end
    if def.category == "armor" or def.category == "jewelry" then
        return def.category
    end
    if def.bars and def.bars.back then
        return "weaponsBack"
    end
    return "weaponsFront"
end

-- Pista compacta de donde va un set: categorias presentes, en orden canonico.
local function CategoryHint(slots)
    local present = {}
    for _, slotKey in ipairs(slots or {}) do
        local cat = SlotCategory(slotKey)
        if cat then present[cat] = true end
    end
    local parts = {}
    for _, cat in ipairs(CATEGORY_ORDER) do
        if present[cat] then
            local sid = _G[CATEGORY_STRING[cat] or ""]
            parts[#parts + 1] = sid and GetString(sid) or cat
        end
    end
    return table.concat(parts, " + ")
end

-- Construye las opciones del selector de captura leyendo el equipo puesto:
-- "todo", cada set con su recuento y su ubicacion, y cada pieza suelta con su
-- slot para saber donde va (y desambiguar los dos anillos o las armas).
local function GetCaptureChoices()
    local labels, values = {}, {}
    for _, entry in ipairs(EZOArmory.Gear.GetCaptureEntries()) do
        local label
        if entry.kind == "all" then
            label = string.format("%s (%d)", GetString(EZOARM_PRESET_ALL), entry.count or 0)
        elseif entry.kind == "set" then
            local hint = CategoryHint(entry.slots)
            if hint ~= "" then
                label = string.format("%s (%d) - %s", tostring(entry.name), entry.count or 0, hint)
            else
                label = string.format("%s (%d)", tostring(entry.name), entry.count or 0)
            end
        else
            label = string.format("%s - %s", tostring(entry.name), SlotLabel(entry.slotKey))
        end
        labels[#labels + 1] = label
        values[#values + 1] = entry.value
    end
    return labels, values
end

-- ------------------------------------------------------- Listado de kits ---

local kitChoices, kitChoiceValues = {}, {}

local function RefreshKitChoices()
    for index = #kitChoices, 1, -1 do kitChoices[index] = nil end
    for index = #kitChoiceValues, 1, -1 do kitChoiceValues[index] = nil end

    for _, kit in ipairs(EZOArmory.Kits.ListKits()) do
        kitChoices[#kitChoices + 1] = string.format(
            "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit))
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

-- Empuja la lista actualizada al control visible.
--
-- Sin EZOCore el control conserva su "reference" como nombre global y se puede
-- actualizar en el sitio (limpio, sin reconstruir). Bajo EZOCore los controles
-- se renombran, asi que reference queda nil; en ese caso forzamos un rebuild del
-- panel via el servicio family.settings. El rebuild se aplaza un frame para no
-- destruir el control cuyo callback nos esta ejecutando.
local function RefreshKitDropdown()
    RefreshKitChoices()

    local control = _G[KIT_LIST_REFERENCE]
    if control and type(control.UpdateChoices) == "function" then
        control:UpdateChoices(kitChoices, kitChoiceValues)
        return
    end

    if EZOCore and type(EZOCore.GetService) == "function" then
        local settings = EZOCore:GetService("family.settings", 1)
        if settings and type(settings.RefreshCurrentPanel) == "function" then
            zo_callLater(function()
                pcall(function()
                    settings:RefreshCurrentPanel(true)
                end)
            end, 50)
        end
    end
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
    local id, kit = EZOArmory.Kits.CreateKitFromWorn(name, slots, nil)
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

local function CaptureAllSets()
    local role = GetActiveRole()
    local created, skipped = EZOArmory.Kits.CaptureAllSets(role)
    RefreshKitDropdown()
    Print(zo_strformat(GetString(EZOARM_MSG_KITS_CAPTURED_ALL), created, skipped))
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
            end,
            default = "dd",
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
