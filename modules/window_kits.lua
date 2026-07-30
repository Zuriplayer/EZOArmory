-- Panel de listas de kits para la ventana propia: equipo, habilidades y CP.
--
-- Se monta dentro de Window.body. Reutiliza los modulos de datos ya validados
-- (Kits, Skills, Champion, Gear, Equip) sin duplicar logica: esta capa solo
-- construye controles y los rellena.
--
-- Tooltips reales verificados en produccion (Wizard's Wardrobe / CombatMetrics),
-- no la version LAM con marcado de texto:
--   InitializeTooltip(ItemTooltip, anchor, point, x, y, relPoint)
--   ItemTooltip:SetLink(itemLink) / ClearTooltip(ItemTooltip)               -- equipo
--   InitializeTooltip(AbilityTooltip, ...); AbilityTooltip:SetAbilityId(id) -- habilidades
--   InitializeTooltip(ChampionSkillTooltip, ...)
--     ChampionSkillTooltip:SetChampionSkill(starId, points, nil, slotted)  -- estrellas CP
--   ZO_Tooltips_ShowTextTooltip(control, point, text) para resumenes compuestos
--
-- Cada kit de habilidades muestra sus dos barras como una fila de iconos reales
-- (arma + 5 habilidades + definitiva), igual que la barra de accion nativa.
-- Cada kit de CP muestra sus estrellas como "chips" de texto individuales,
-- agrupados por arbol y coloreados con el color oficial de ese arbol
-- (ZO_CP_BAR_GLOW_COLORS, la misma tabla que usa la pantalla nativa de CP,
-- verificada en esoui/libraries/globals/defaultcolordefs.lua). Cada icono o
-- chip tiene su propio hover con el tooltip real de esa habilidad/estrella.
--
-- Las filas tienen altura VARIABLE segun la categoria y el contenido (un kit
-- de CP con muchas estrellas ocupa mas lineas que uno con pocas), asi que el
-- posicionado vertical se recalcula en cada refresco en vez de fijarse una
-- vez al crear el pool de filas.

EZOArmory = EZOArmory or {}
EZOArmory.WindowKits = EZOArmory.WindowKits or {}

local WK = EZOArmory.WindowKits
local WM = WINDOW_MANAGER

local CATEGORY_WIDTH = 150
local ROW_SPACING = 8

local ICON_SIZE = 28
local ICON_GAP = 2
local MAX_ROW_ICONS = 8

local NAME_LINE_HEIGHT = 20

-- Arma y habilidades de un kit de skills comparten tamano, mas grande que el
-- icono de equipo: son el contenido principal de esa fila (equivalente visual
-- de la barra de accion nativa), no una referencia secundaria.
local SKILL_ICON_SIZE = 36
local SKILL_ICON_GAP = 4
local ABILITIES_PER_BAR = 6 -- 5 activas + definitiva
local BAR_LINE_GAP = 6

-- Alturas de fila calculadas a partir del contenido real, con margen. Gear va
-- en una sola linea (icono + nombre al lado), asi que solo necesita el alto
-- del icono. Skills apila dos lineas de iconos bajo el nombre.
local GEAR_ROW_HEIGHT = ICON_SIZE + 8
local SKILL_ROW_HEIGHT = NAME_LINE_HEIGHT + 2 + (SKILL_ICON_SIZE * 2) + BAR_LINE_GAP + 8

local CP_CHIP_HEIGHT = 20
local CP_CHIP_PADDING = 14
local MAX_CP_CHIPS = 14

local MAX_ROWS = 26

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

local function ShowAbilityTooltip(anchor, abilityId)
    if type(InitializeTooltip) == "function" and AbilityTooltip
        and type(AbilityTooltip.SetAbilityId) == "function" then
        InitializeTooltip(AbilityTooltip, anchor, RIGHT, 6, 0, LEFT)
        AbilityTooltip:SetAbilityId(abilityId)
    end
end

local function HideAbilityTooltip()
    if type(ClearTooltip) == "function" and AbilityTooltip then
        ClearTooltip(AbilityTooltip)
    end
end

local function ShowChampionTooltip(anchor, starId)
    if type(InitializeTooltip) == "function" and ChampionSkillTooltip
        and type(ChampionSkillTooltip.SetChampionSkill) == "function" then
        InitializeTooltip(ChampionSkillTooltip, anchor, RIGHT, 6, 0, LEFT)
        ChampionSkillTooltip:SetChampionSkill(starId, nil, nil, nil)
    end
end

local function HideChampionTooltip()
    if type(ClearTooltip) == "function" and ChampionSkillTooltip then
        ClearTooltip(ChampionSkillTooltip)
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

-- Color oficial del arbol de CP (Guerra/Forma Fisica/Mundo), el mismo que usa
-- la pantalla nativa de Puntos de Campeon (ZO_CP_BAR_GLOW_COLORS, global del
-- propio juego indexada por CHAMPION_DISCIPLINE_TYPE_*).
local function GetDisciplineColor(disciplineType)
    if type(ZO_CP_BAR_GLOW_COLORS) == "table" then
        return ZO_CP_BAR_GLOW_COLORS[disciplineType]
    end
    return nil
end

-- ------------------------------------------------------------- Filas ----

-- Crea una fila reutilizable con todos los controles que puede necesitar
-- cualquiera de las tres categorias (se muestran/ocultan segun corresponda).
--
-- widthAnchor es el ZO_ScrollContainer EXTERNO, no el ScrollChild que aloja la
-- fila. Confirmado contra la plantilla oficial de ZOS
-- (esoui/libraries/zo_templates/scrolltemplates.xml): el ScrollChild solo
-- lleva un ancla TOPLEFT y "resizeToFitDescendents=true", asi que su ancho se
-- autoajusta al de SUS hijos en vez de estirarse al contenedor. Anclar el
-- ancho de la fila a el mismo (su propio padre) crea un ciclo que colapsa al
-- ancho minimo del contenido. El contenedor externo si tiene anclas
-- TOPLEFT/BOTTOMRIGHT propias y un ancho deterministico.
local function CreateRow(parent, index, widthAnchor)
    local row = WM:CreateControl("EZOArmoryKitRow" .. index, parent, CT_CONTROL)
    row.widthAnchor = widthAnchor

    local bg = WM:CreateControl(nil, row, CT_BACKDROP)
    bg:SetAnchorFill(row)
    bg:SetEdgeTexture(nil, 1, 1, 1, 0)
    bg:SetCenterColor(1, 1, 1, 0.04)
    bg:SetHidden(true)
    row.selectionBg = bg

    -- Nombre del kit, cabecera de la fila en las tres categorias.
    local name = WM:CreateControl(nil, row, CT_LABEL)
    name:SetFont("ZoFontGameBold")
    name:SetColor(0.92, 0.92, 0.95, 1)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetHeight(NAME_LINE_HEIGHT)
    name:SetAnchor(TOPLEFT, row, TOPLEFT, 6, 0)
    name:SetAnchor(TOPRIGHT, row, TOPRIGHT, -6, 0)
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

    -- Iconos de pieza de equipo (Gear kits).
    row.icons = {}
    for i = 1, MAX_ROW_ICONS do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(ICON_SIZE, ICON_SIZE)
        icon:SetHidden(true)
        icon:SetMouseEnabled(true)
        row.icons[i] = icon
    end

    -- Iconos de arma por barra (Skill kits): [1]=frontal, [2]=trasera.
    row.weaponIcons = {}
    for i = 1, 2 do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
        icon:SetHidden(true)
        icon:SetMouseEnabled(true)
        row.weaponIcons[i] = icon
    end

    -- Iconos de habilidad (Skill kits): 1..6 barra frontal, 7..12 trasera.
    row.abilityIcons = {}
    for i = 1, ABILITIES_PER_BAR * 2 do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
        icon:SetHidden(true)
        icon:SetMouseEnabled(true)
        row.abilityIcons[i] = icon
    end

    -- "Chips" de texto por estrella (CP kits), tamano dinamico segun el nombre.
    row.cpChips = {}
    for i = 1, MAX_CP_CHIPS do
        local chip = WM:CreateControl(nil, row, CT_LABEL)
        chip:SetFont("ZoFontGameSmall")
        chip:SetHeight(CP_CHIP_HEIGHT)
        chip:SetHidden(true)
        chip:SetMouseEnabled(true)
        row.cpChips[i] = chip
    end

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

-- Oculta todo el contenido reutilizable de una fila antes de rellenarla de
-- nuevo, para que restos de la categoria/kit anterior no se cuelen.
local function ClearRowContent(row)
    for _, icon in ipairs(row.icons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
    for _, icon in ipairs(row.weaponIcons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
    for _, icon in ipairs(row.abilityIcons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
    for _, chip in ipairs(row.cpChips) do
        chip:SetHidden(true)
        chip:SetHandler("OnMouseEnter", nil)
        chip:SetHandler("OnMouseExit", nil)
    end
    row.nameLabel:SetHandler("OnMouseEnter", nil)
    row.nameLabel:SetHandler("OnMouseExit", nil)
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

-- Rellena una fila de equipo en una sola linea: iconos reales de item a la
-- izquierda (cada uno con su tooltip nativo), nombre a la derecha. Mas
-- compacta que Skills/CP porque no necesita mostrar varias lineas de
-- contenido grafico. Devuelve la altura usada (fija).
local function FillGearRow(row, kit)
    local slots = EZOArmory.Kits.GetKitSlots(kit)
    local index = 0
    local summaryLines = {}
    for _, slotKey in ipairs(slots) do
        local piece = kit.pieces[slotKey]
        if piece and index < MAX_ROW_ICONS then
            index = index + 1
            local icon = row.icons[index]
            icon:SetTexture(piece.icon)
            icon:SetHidden(false)
            icon:ClearAnchors()
            if index == 1 then
                -- LEFT (no TOPLEFT): punto verticalmente centrado, para que el
                -- icono quede centrado en el alto completo de la fila.
                icon:SetAnchor(LEFT, row, LEFT, 6, 0)
            else
                icon:SetAnchor(LEFT, row.icons[index - 1], RIGHT, ICON_GAP, 0)
            end
            local itemId = piece.itemId
            icon:SetHandler("OnMouseEnter", function(control) ShowItemTooltip(control, itemId) end)
            icon:SetHandler("OnMouseExit", HideItemTooltip)
        end
        if piece then
            local label = piece.setName ~= "" and piece.setName or piece.itemName
            summaryLines[#summaryLines + 1] = string.format("%s: %s", slotKey, tostring(label))
        end
    end

    row.nameLabel:SetText(string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit)))
    row.nameLabel:ClearAnchors()
    local iconsAnchorAfter = index > 0 and row.icons[index] or nil
    if iconsAnchorAfter then
        row.nameLabel:SetAnchor(LEFT, iconsAnchorAfter, RIGHT, 10, 0)
    else
        row.nameLabel:SetAnchor(LEFT, row, LEFT, 6, 0)
    end
    row.nameLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)

    row.nameLabel:SetHandler("OnMouseEnter", function(control)
        ShowTextSummary(control, kit.name, summaryLines)
    end)
    row.nameLabel:SetHandler("OnMouseExit", HideTextSummary)

    return GEAR_ROW_HEIGHT
end

-- Coloca un icono de arma que sirve de referencia visual de la barra; su
-- hover muestra un resumen de esa barra (no el tooltip del arma en si).
local function PlaceBarWeaponIcon(row, barIndex, weaponRef, barTitle, barLines)
    local icon = row.weaponIcons[barIndex]
    if not icon or not weaponRef or not weaponRef.icon or weaponRef.icon == "" then
        return
    end
    icon:SetTexture(weaponRef.icon)
    icon:SetHidden(false)
    icon:SetHandler("OnMouseEnter", function(control) ShowTextSummary(control, barTitle, barLines) end)
    icon:SetHandler("OnMouseExit", HideTextSummary)
end

-- Coloca los iconos de habilidad de una barra, cada uno con el tooltip real
-- de esa habilidad (AbilityTooltip, verificado contra Wizard's Wardrobe).
local function PlaceBarAbilityIcons(row, kit, hotbar, iconOffset, y)
    local entries = EZOArmory.Skills.GetBarAbilityEntries(kit, hotbar)
    local previousControl = row.weaponIcons[iconOffset == 0 and 1 or 2]
    for i, entry in ipairs(entries) do
        if i > ABILITIES_PER_BAR then break end
        local icon = row.abilityIcons[iconOffset + i]
        if icon and entry.icon and entry.icon ~= "" then
            icon:SetTexture(entry.icon)
            icon:SetHidden(false)
            icon:ClearAnchors()
            if previousControl then
                icon:SetAnchor(LEFT, previousControl, RIGHT, SKILL_ICON_GAP + (i == 1 and 6 or 0), 0)
            else
                icon:SetAnchor(TOPLEFT, row, TOPLEFT, 6, y)
            end
            local abilityId = entry.abilityId
            icon:SetHandler("OnMouseEnter", function(control) ShowAbilityTooltip(control, abilityId) end)
            icon:SetHandler("OnMouseExit", HideAbilityTooltip)
            previousControl = icon
        end
    end
end

-- Rellena una fila de habilidades: nombre + dos barras graficas (arma + 5
-- habilidades + definitiva cada una), como la barra de accion nativa. Cada
-- icono tiene su propio tooltip real. Devuelve la altura usada (fija).
local function FillSkillRow(row, kit)
    row.nameLabel:SetText(string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Skills.CountAbilities(kit)))
    row.nameLabel:SetHandler("OnMouseEnter", nil)
    row.nameLabel:SetHandler("OnMouseExit", nil)

    local weapons = kit.weapons or {}
    local frontY = NAME_LINE_HEIGHT + 2
    local backY = frontY + SKILL_ICON_SIZE + BAR_LINE_GAP

    row.weaponIcons[1]:ClearAnchors()
    row.weaponIcons[1]:SetAnchor(TOPLEFT, row, TOPLEFT, 6, frontY)
    local frontNames = EZOArmory.Skills.GetBarAbilityNames(kit, EZOArmory.Skills.HOTBAR_FRONT)
    PlaceBarWeaponIcon(row, 1, weapons.main, kit.name,
        { GetString(EZOARM_MSG_BAR_FRONT) .. ": " .. table.concat(frontNames, ", ") })
    PlaceBarAbilityIcons(row, kit, EZOArmory.Skills.HOTBAR_FRONT, 0, frontY)

    row.weaponIcons[2]:ClearAnchors()
    row.weaponIcons[2]:SetAnchor(TOPLEFT, row, TOPLEFT, 6, backY)
    local backNames = EZOArmory.Skills.GetBarAbilityNames(kit, EZOArmory.Skills.HOTBAR_BACK)
    PlaceBarWeaponIcon(row, 2, weapons.backupMain, kit.name,
        { GetString(EZOARM_MSG_BAR_BACK) .. ": " .. table.concat(backNames, ", ") })
    PlaceBarAbilityIcons(row, kit, EZOArmory.Skills.HOTBAR_BACK, ABILITIES_PER_BAR, backY)

    return SKILL_ROW_HEIGHT
end

-- Rellena una fila de CP: nombre + "chips" de texto, uno por estrella,
-- agrupados por arbol (cada arbol empieza en linea nueva) y coloreados con el
-- color oficial de su arbol. Cada chip tiene su propio tooltip real
-- (ChampionSkillTooltip). Devuelve la altura realmente usada (variable segun
-- cuantas lineas hacen falta).
local function FillCpRow(row, kit)
    row.nameLabel:SetText(string.format(
        "%s (%d)", tostring(kit.name), EZOArmory.Champion.CountStars(kit)))
    row.nameLabel:SetHandler("OnMouseEnter", nil)
    row.nameLabel:SetHandler("OnMouseExit", nil)

    local availableWidth = (row.widthAnchor and row.widthAnchor.GetWidth and row.widthAnchor:GetWidth() or 400) - 40
    local groups = EZOArmory.Champion.GetStarsByDiscipline(kit)

    local marginLeft = 6
    local x, y = marginLeft, NAME_LINE_HEIGHT + 2
    local chipIndex = 0

    for _, group in ipairs(groups) do
        local color = GetDisciplineColor(group.disciplineType)
        -- Cada arbol empieza en su propia linea.
        if x > marginLeft then
            x = marginLeft
            y = y + CP_CHIP_HEIGHT
        end
        for starIndex, star in ipairs(group.stars) do
            chipIndex = chipIndex + 1
            local chip = row.cpChips[chipIndex]
            if not chip then break end

            local displayText = star.name
            if starIndex < #group.stars then
                displayText = displayText .. ","
            end
            chip:SetText(displayText)
            if color and type(color.UnpackRGBA) == "function" then
                chip:SetColor(color:UnpackRGBA())
            else
                chip:SetColor(0.85, 0.85, 0.9, 1)
            end

            local chipWidth = (chip.GetTextWidth and chip:GetTextWidth() or 80) + CP_CHIP_PADDING
            if x > marginLeft and x + chipWidth > marginLeft + availableWidth then
                x = marginLeft
                y = y + CP_CHIP_HEIGHT
            end

            chip:ClearAnchors()
            chip:SetAnchor(TOPLEFT, row, TOPLEFT, x, y)
            chip:SetHidden(false)
            local starId = star.starId
            chip:SetHandler("OnMouseEnter", function(control) ShowChampionTooltip(control, starId) end)
            chip:SetHandler("OnMouseExit", HideChampionTooltip)

            x = x + chipWidth
        end
    end

    local usedHeight = y + CP_CHIP_HEIGHT + 6
    return math.max(usedHeight, GEAR_ROW_HEIGHT)
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

-- Recorre las filas, las rellena y las posiciona una debajo de otra segun la
-- altura REAL que cada una uso (variable por categoria y, en CP, tambien por
-- cuantas estrellas/lineas hacen falta).
function WK.Refresh()
    if not WK.rows or not WK.listRoot then return end

    local list = ListForCategory(WK.state.category)
    local stillSelected = false
    local scrollbarWidth = (type(ZO_SCROLL_BAR_WIDTH) == "number" and ZO_SCROLL_BAR_WIDTH or 16) + 8
    local yOffset = 0

    for index, row in ipairs(WK.rows) do
        local kit = list[index]
        if kit then
            row.kitId = kit.id
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, WK.listRoot, TOPLEFT, 0, yOffset)
            row:SetAnchor(TOPRIGHT, row.widthAnchor, TOPRIGHT, -scrollbarWidth, yOffset)
            row:SetHidden(false)
            ClearRowContent(row)

            local usedHeight
            if WK.state.category == CATEGORY_GEAR then
                usedHeight = FillGearRow(row, kit)
            elseif WK.state.category == CATEGORY_SKILLS then
                usedHeight = FillSkillRow(row, kit)
            else
                usedHeight = FillCpRow(row, kit)
            end
            row:SetHeight(usedHeight)

            row.selectionBg:SetHidden(kit.id ~= WK.state.selectedId)
            if kit.id == WK.state.selectedId then
                stillSelected = true
            end

            yOffset = yOffset + usedHeight + ROW_SPACING
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

    WK.listRoot:SetHeight(math.max(1, yOffset))

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
