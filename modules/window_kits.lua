-- Panel de listas de kits para la ventana propia: equipo, habilidades y CP.
--
-- Se monta dentro de Window.body. Reutiliza los modulos de datos ya validados
-- (Kits, Skills, Champion, Gear, Equip) sin duplicar logica: esta capa solo
-- construye controles y los rellena.
--
-- Tooltips reales verificados contra Wizard's Wardrobe (en produccion), no la
-- version LAM con marcado de texto:
--   InitializeTooltip(ItemTooltip, anchor, point, x, y, relPoint)
--   ItemTooltip:SetLink(itemLink) / ClearTooltip(ItemTooltip)
--   ZO_Tooltips_ShowTextTooltip(control, point, text) para resumenes compuestos
--     (piezas del kit, habilidades por barra, estrellas de CP).
--
-- Las armas de un kit de habilidades son items y usan el mismo tooltip de item
-- real. Para el resto de habilidades (AbilityTooltip:SetAbilityId, verificado
-- en WW) y para iconos de estrella de CP (sin API de icono por estrella
-- encontrada) queda pendiente de una fase posterior si aporta valor.
--
-- La identidad de cada pieza (itemId) ya se guarda en los kits; el itemLink
-- real se resuelve en caliente al pasar el cursor via Gear.FindItemById, para
-- reflejar el estado actual del item (encantamiento, ubicacion) en vez de un
-- link congelado en el momento de la captura.

EZOArmory = EZOArmory or {}
EZOArmory.WindowKits = EZOArmory.WindowKits or {}

local WK = EZOArmory.WindowKits
local WM = WINDOW_MANAGER

local CATEGORY_WIDTH = 150
local ROW_HEIGHT = 42
local ROW_SPACING = 4
local ICON_SIZE = 28
local ICON_GAP = 2
local MAX_ROW_ICONS = 8
local MAX_ROWS = 40

local CATEGORY_GEAR = "gear"
local CATEGORY_SKILLS = "skills"
local CATEGORY_CP = "cp"
local CATEGORIES = { CATEGORY_GEAR, CATEGORY_SKILLS, CATEGORY_CP }

WK.state = WK.state or {
    category = CATEGORY_GEAR,
    selectedId = nil,
}

-- ---------------------------------------------------------- Tooltips ----

local function ShowItemTooltip(anchor, itemId)
    local location = EZOArmory.Gear and EZOArmory.Gear.FindItemById and EZOArmory.Gear.FindItemById(itemId)
    if location and type(GetItemLink) == "function"
        and type(InitializeTooltip) == "function" and ItemTooltip then
        local ok, link = pcall(GetItemLink, location.bag, location.slot)
        if ok and link and link ~= "" then
            InitializeTooltip(ItemTooltip, anchor, RIGHT, 6, 0, LEFT)
            ItemTooltip:SetLink(link)
            return
        end
    end
    if type(ZO_Tooltips_ShowTextTooltip) == "function" then
        ZO_Tooltips_ShowTextTooltip(anchor, RIGHT, GetString(EZOARM_WINDOW_TOOLTIP_NOT_AVAILABLE))
    end
end

local function HideItemTooltip()
    if type(ClearTooltip) == "function" and ItemTooltip then
        ClearTooltip(ItemTooltip)
    end
    if type(ZO_Tooltips_HideTextTooltip) == "function" then
        ZO_Tooltips_HideTextTooltip()
    end
end

-- Resumen compuesto (varias lineas) para el hover sobre el nombre de una fila.
local function ShowTextSummary(anchor, title, lines)
    if type(ZO_Tooltips_ShowTextTooltip) ~= "function" then return end
    local text = tostring(title or "")
    if lines and #lines > 0 then
        text = text .. "\n" .. table.concat(lines, "\n")
    end
    ZO_Tooltips_ShowTextTooltip(anchor, RIGHT, text)
end

local function HideTextSummary()
    if type(ZO_Tooltips_HideTextTooltip) == "function" then
        ZO_Tooltips_HideTextTooltip()
    end
end

-- ------------------------------------------------------------- Filas ----

-- Crea una fila reutilizable: fondo de seleccion, tira de iconos y nombre.
--
-- widthAnchor es el ZO_ScrollContainer EXTERNO, no el ScrollChild que aloja la
-- fila. Confirmado contra la plantilla oficial de ZOS
-- (esoui/libraries/zo_templates/scrolltemplates.xml): el ScrollChild solo
-- lleva un ancla TOPLEFT y "resizeToFitDescendents=true", asi que su ancho se
-- autoajusta al de SUS hijos en vez de estirarse al contenedor. Anclar el
-- ancho de la fila a el mismo (su propio padre) crea un ciclo que colapsa al
-- ancho minimo del contenido -- exactamente el truncado que se veia. El
-- contenedor externo si tiene anclas TOPLEFT/BOTTOMRIGHT propias y un ancho
-- deterministico, asi que el ancho de la fila se toma de ahi.
local function CreateRow(parent, index, widthAnchor)
    local row = WM:CreateControl("EZOArmoryKitRow" .. index, parent, CT_CONTROL)
    row:SetHeight(ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (index - 1) * (ROW_HEIGHT + ROW_SPACING))
    local scrollbarWidth = (type(ZO_SCROLL_BAR_WIDTH) == "number" and ZO_SCROLL_BAR_WIDTH or 16) + 8
    row:SetAnchor(TOPRIGHT, widthAnchor, TOPRIGHT, -scrollbarWidth, (index - 1) * (ROW_HEIGHT + ROW_SPACING))

    local bg = WM:CreateControl(nil, row, CT_BACKDROP)
    bg:SetAnchorFill(row)
    bg:SetEdgeTexture(nil, 1, 1, 1, 0)
    bg:SetCenterColor(1, 1, 1, 0.04)
    bg:SetHidden(true)
    row.selectionBg = bg

    row.icons = {}
    for i = 1, MAX_ROW_ICONS do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(ICON_SIZE, ICON_SIZE)
        if i == 1 then
            icon:SetAnchor(LEFT, row, LEFT, 6, 0)
        else
            icon:SetAnchor(LEFT, row.icons[i - 1], RIGHT, ICON_GAP, 0)
        end
        icon:SetHidden(true)
        icon:SetMouseEnabled(true)
        row.icons[i] = icon
    end

    local name = WM:CreateControl(nil, row, CT_LABEL)
    name:SetFont("ZoFontGame")
    name:SetColor(0.92, 0.92, 0.95, 1)
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Una sola linea con "..." si no cabe. Sin esto y sin altura fija, un
    -- nombre largo hace word-wrap a varias lineas y se desborda fuera de la
    -- fila (posiciones Y absolutas, no encadenadas), solapando la de abajo.
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetHeight(ROW_HEIGHT)
    name:SetAnchor(LEFT, row, LEFT, 6, 0)
    name:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    name:SetMouseEnabled(true)
    row.nameLabel = name

    row:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        WK.SelectKit(row.kitId)
    end)
    name:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        WK.SelectKit(row.kitId)
    end)

    return row
end

local function EnsureRows(parent, widthAnchor)
    WK.rows = WK.rows or {}
    if #WK.rows > 0 then return WK.rows end
    for i = 1, MAX_ROWS do
        WK.rows[i] = CreateRow(parent, i, widthAnchor)
    end
    return WK.rows
end

local function HideRowIcons(row)
    for _, icon in ipairs(row.icons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
end

-- Coloca un icono con tooltip de item real (equipo).
local function PlaceItemIcon(row, index, texture, itemId)
    local icon = row.icons[index]
    if not icon then return end
    icon:SetTexture(texture)
    icon:SetHidden(false)
    icon:SetHandler("OnMouseEnter", function(control) ShowItemTooltip(control, itemId) end)
    icon:SetHandler("OnMouseExit", HideItemTooltip)
end

-- ---------------------------------------------------- Datos por categoria ----

local function ListForCategory(category)
    if category == CATEGORY_SKILLS then
        return EZOArmory.Skills.ListKits()
    elseif category == CATEGORY_CP then
        return EZOArmory.Champion.ListKits()
    end
    return EZOArmory.Kits.ListKits()
end

local function DeleteKit(category, id)
    if category == CATEGORY_SKILLS then
        return EZOArmory.Skills.DeleteKit(id)
    elseif category == CATEGORY_CP then
        return EZOArmory.Champion.DeleteKit(id)
    end
    return EZOArmory.Kits.DeleteKit(id)
end

-- Rellena una fila para un kit de equipo: iconos reales de item + resumen.
local function FillGearRow(row, kit)
    row.nameLabel:SetText(string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit)))

    local slots = EZOArmory.Kits.GetKitSlots(kit)
    local index = 0
    local summaryLines = {}
    for _, slotKey in ipairs(slots) do
        local piece = kit.pieces[slotKey]
        if piece and index < MAX_ROW_ICONS then
            index = index + 1
            PlaceItemIcon(row, index, piece.icon, piece.itemId)
        end
        if piece then
            local label = piece.setName ~= "" and piece.setName or piece.itemName
            summaryLines[#summaryLines + 1] = string.format("%s: %s", slotKey, tostring(label))
        end
    end

    local iconsAnchorAfter = index > 0 and row.icons[index] or nil
    if iconsAnchorAfter then
        row.nameLabel:ClearAnchors()
        row.nameLabel:SetAnchor(LEFT, iconsAnchorAfter, RIGHT, 10, 0)
        row.nameLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    else
        row.nameLabel:ClearAnchors()
        row.nameLabel:SetAnchor(LEFT, row, LEFT, 6, 0)
        row.nameLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    end

    row.nameLabel:SetHandler("OnMouseEnter", function(control)
        ShowTextSummary(control, kit.name, summaryLines)
    end)
    row.nameLabel:SetHandler("OnMouseExit", HideTextSummary)
end

-- Rellena una fila para un kit de habilidades: icono de arma por barra +
-- vista previa de habilidades en el propio texto (no solo en el tooltip, para
-- poder identificar el kit sin tener que pasar el cursor).
local function FillSkillRow(row, kit)
    local frontNames = EZOArmory.Skills.GetBarAbilityNames(kit, EZOArmory.Skills.HOTBAR_FRONT)
    local backNames = EZOArmory.Skills.GetBarAbilityNames(kit, EZOArmory.Skills.HOTBAR_BACK)
    local allNames = {}
    for _, n in ipairs(frontNames) do allNames[#allNames + 1] = n end
    for _, n in ipairs(backNames) do allNames[#allNames + 1] = n end
    local preview = table.concat(allNames, ", ")

    row.nameLabel:SetText(string.format("%s: %s", tostring(kit.name), preview))

    local index = 0
    local weapons = kit.weapons or {}
    local frontRef = weapons.main
    local backRef = weapons.backupMain
    if frontRef and frontRef.icon and frontRef.icon ~= "" and index < MAX_ROW_ICONS then
        index = index + 1
        PlaceItemIcon(row, index, frontRef.icon, frontRef.itemId)
    end
    if backRef and backRef.icon and backRef.icon ~= "" and index < MAX_ROW_ICONS then
        index = index + 1
        PlaceItemIcon(row, index, backRef.icon, backRef.itemId)
    end

    local iconsAnchorAfter = index > 0 and row.icons[index] or nil
    row.nameLabel:ClearAnchors()
    if iconsAnchorAfter then
        row.nameLabel:SetAnchor(LEFT, iconsAnchorAfter, RIGHT, 10, 0)
    else
        row.nameLabel:SetAnchor(LEFT, row, LEFT, 6, 0)
    end
    row.nameLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)

    local lines = {
        GetString(EZOARM_MSG_BAR_FRONT) .. ": " .. table.concat(frontNames, ", "),
        GetString(EZOARM_MSG_BAR_BACK) .. ": " .. table.concat(backNames, ", "),
    }
    row.nameLabel:SetHandler("OnMouseEnter", function(control)
        ShowTextSummary(control, kit.name, lines)
    end)
    row.nameLabel:SetHandler("OnMouseExit", HideTextSummary)
end

-- Rellena una fila para un kit de CP: sin iconos (sin API de icono por
-- estrella verificada). La vista previa de estrellas va en el propio texto,
-- no solo en el tooltip, para identificar el kit sin pasar el cursor.
local function FillCpRow(row, kit)
    local names = EZOArmory.Champion.GetStarNames(kit)
    local preview = table.concat(names, ", ")

    row.nameLabel:SetText(string.format("%s: %s", tostring(kit.name), preview))
    row.nameLabel:ClearAnchors()
    row.nameLabel:SetAnchor(LEFT, row, LEFT, 6, 0)
    row.nameLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)

    row.nameLabel:SetHandler("OnMouseEnter", function(control)
        ShowTextSummary(control, kit.name, names)
    end)
    row.nameLabel:SetHandler("OnMouseExit", HideTextSummary)
end

-- ------------------------------------------------------------- Refresco ----

function WK.SelectKit(kitId)
    WK.state.selectedId = kitId
    for _, row in ipairs(WK.rows or {}) do
        row.selectionBg:SetHidden(row.kitId ~= kitId or kitId == nil)
    end
    if WK.RefreshActionBar then
        WK.RefreshActionBar()
    end
end

function WK.SetCategory(category)
    WK.state.category = category
    WK.state.selectedId = nil
    WK.Refresh()
    if WK.RefreshTabs then
        WK.RefreshTabs()
    end
end

function WK.Refresh()
    if not WK.rows or not WK.listRoot then return end

    local list = ListForCategory(WK.state.category)
    local stillSelected = false

    for index, row in ipairs(WK.rows) do
        local kit = list[index]
        if kit then
            row.kitId = kit.id
            HideRowIcons(row)
            if WK.state.category == CATEGORY_GEAR then
                FillGearRow(row, kit)
            elseif WK.state.category == CATEGORY_SKILLS then
                FillSkillRow(row, kit)
            else
                FillCpRow(row, kit)
            end
            row:SetHidden(false)
            row.selectionBg:SetHidden(kit.id ~= WK.state.selectedId)
            if kit.id == WK.state.selectedId then
                stillSelected = true
            end
        else
            row.kitId = nil
            row:SetHidden(true)
        end
    end

    if not stillSelected then
        WK.state.selectedId = nil
    end

    local count = #list
    if WK.countLabel then
        if count == 0 then
            WK.countLabel:SetText(GetString(EZOARM_WINDOW_NO_KITS))
        else
            WK.countLabel:SetText(zo_strformat(GetString(EZOARM_WINDOW_KIT_COUNT), count))
        end
    end

    local contentHeight = math.max(1, count) * (ROW_HEIGHT + ROW_SPACING)
    WK.listRoot:SetHeight(contentHeight)

    if WK.RefreshActionBar then
        WK.RefreshActionBar()
    end
end

-- --------------------------------------------------------- Barra de accion ----

function WK.RefreshActionBar()
    if not WK.deleteButton then return end
    local hasSelection = WK.state.selectedId ~= nil
    WK.deleteButton:SetHidden(not hasSelection)
    if WK.equipButton then
        WK.equipButton:SetHidden(not hasSelection or WK.state.category ~= CATEGORY_GEAR)
    end
end

local function OnDeleteClicked()
    if not WK.state.selectedId then return end
    DeleteKit(WK.state.category, WK.state.selectedId)
    WK.state.selectedId = nil
    WK.Refresh()
end

local function OnEquipClicked()
    if WK.state.category ~= CATEGORY_GEAR or not WK.state.selectedId then return end
    if not (EZOArmory.Equip and EZOArmory.Equip.ApplyKits) then return end

    EZOArmory.Equip.onQueued = function()
        if EZOArmory.Print then EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED)) end
    end
    EZOArmory.Equip.ApplyKits({ WK.state.selectedId }, function(state)
        if not EZOArmory.Print then return end
        if state.error == "noLibAsync" then
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
            return
        end
        if state.error == "empty" then
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_EMPTY))
            return
        end
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_EQUIP_DONE), state.equipped, state.already, state.missing))
    end)
end

-- ------------------------------------------------------------- Pestanas ----

local TAB_STRING = {
    [CATEGORY_GEAR] = "EZOARM_WINDOW_TAB_GEAR",
    [CATEGORY_SKILLS] = "EZOARM_WINDOW_TAB_SKILLS",
    [CATEGORY_CP] = "EZOARM_WINDOW_TAB_CP",
}

function WK.RefreshTabs()
    for _, category in ipairs(CATEGORIES) do
        local button = WK.tabButtons[category]
        if button then
            local isActive = category == WK.state.category
            button:SetColor(isActive and 1 or 0.65, isActive and 1 or 0.65, isActive and 1 or 0.7, 1)
        end
    end
end

local function CreateTabs(parent)
    local column = WM:CreateControl(nil, parent, CT_CONTROL)
    column:SetDimensions(CATEGORY_WIDTH, 1)
    column:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    column:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, 0)

    WK.tabButtons = {}
    local previous
    for _, category in ipairs(CATEGORIES) do
        local button = WM:CreateControl(nil, column, CT_LABEL)
        button:SetFont("ZoFontGameBold")
        button:SetMouseEnabled(true)
        button:SetText(GetString(_G[TAB_STRING[category]]))
        if previous then
            button:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 14)
        else
            button:SetAnchor(TOPLEFT, column, TOPLEFT, 4, 4)
        end
        button:SetHandler("OnMouseUp", function(_, mouseButton)
            if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
            WK.SetCategory(category)
        end)
        WK.tabButtons[category] = button
        previous = button
    end

    return column
end

-- --------------------------------------------------------------- Panel ----

-- Construye el panel completo dentro de "parent" (Window.body) y lo devuelve.
function WK.Create(parent)
    if WK.root then
        return WK.root
    end

    local root = WM:CreateControl(nil, parent, CT_CONTROL)
    root:SetAnchorFill(parent)
    WK.root = root

    CreateTabs(root)

    local content = WM:CreateControl(nil, root, CT_CONTROL)
    content:SetAnchor(TOPLEFT, root, TOPLEFT, CATEGORY_WIDTH + 12, 0)
    content:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)

    local countLabel = WM:CreateControl(nil, content, CT_LABEL)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(0.7, 0.7, 0.75, 1)
    countLabel:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)
    WK.countLabel = countLabel

    -- Barra de acciones (Equipar / Borrar), fija bajo la lista.
    local actionBar = WM:CreateControl(nil, content, CT_CONTROL)
    actionBar:SetDimensions(1, 26)
    actionBar:SetAnchor(BOTTOMLEFT, content, BOTTOMLEFT, 0, 0)
    actionBar:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, 0, 0)

    local deleteButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    deleteButton:SetDimensions(160, 24)
    deleteButton:SetAnchor(BOTTOMRIGHT, actionBar, BOTTOMRIGHT, 0, 0)
    deleteButton:SetFont("ZoFontGameBold")
    deleteButton:SetNormalFontColor(1, 0.55, 0.55, 1)
    deleteButton:SetMouseOverFontColor(1, 0.3, 0.3, 1)
    deleteButton:SetText(GetString(EZOARM_OPTION_KIT_DELETE))
    deleteButton:SetHandler("OnClicked", OnDeleteClicked)
    deleteButton:SetHidden(true)
    WK.deleteButton = deleteButton

    local equipButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    equipButton:SetDimensions(160, 24)
    equipButton:SetAnchor(RIGHT, deleteButton, LEFT, -12, 0)
    equipButton:SetFont("ZoFontGameBold")
    equipButton:SetNormalFontColor(0.6, 1, 0.6, 1)
    equipButton:SetMouseOverFontColor(0.4, 1, 0.4, 1)
    equipButton:SetText(GetString(EZOARM_OPTION_KIT_EQUIP))
    equipButton:SetHandler("OnClicked", OnEquipClicked)
    equipButton:SetHidden(true)
    WK.equipButton = equipButton

    -- Lista con scroll real (patron LAM/EZOChat: ZO_ScrollContainer + ScrollChild).
    local scrollContainer = WM:CreateControlFromVirtual(
        "EZOArmoryKitScroll", content, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 0, 8)
    scrollContainer:SetAnchor(BOTTOMRIGHT, actionBar, TOPRIGHT, 0, -8)

    local listRoot = scrollContainer:GetNamedChild("ScrollChild")
    listRoot:SetResizeToFitPadding(0, 20)
    WK.listRoot = listRoot

    EnsureRows(listRoot, scrollContainer)
    WK.RefreshTabs()
    WK.Refresh()

    return root
end
