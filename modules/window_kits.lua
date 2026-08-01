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
local CATEGORY_ASSIGN = "assign"
-- Builds va primero: es la unidad completa y equipable, y a partir de ahora el
-- punto de entrada natural. Las pestanas de kits son los bloques con los que se
-- componen.
local CATEGORY_BUILDS = "builds"
local CATEGORIES = {
    CATEGORY_BUILDS, CATEGORY_GEAR, CATEGORY_SKILLS, CATEGORY_CP, CATEGORY_ASSIGN,
}

-- Layout de la pestana Assign: bloque superior de altura fija (rol, trial,
-- objetivo, build) mas una barra de accion fija abajo. Alturas fijas a
-- proposito (no por contenido, como Gear/Skills/CP) para evitar los bugs de
-- anclaje variable ya sufridos en esas categorias: la pestana Assign es un
-- panel corto y de forma estable, no una lista larga.
local ASSIGN_LABEL_WIDTH = 70
local ASSIGN_ROW_HEIGHT = 26
local ASSIGN_ROW_GAP = 6
local ASSIGN_TARGET_DEFAULT = "default"

WK.state = WK.state or {
    category = CATEGORY_BUILDS,
    selectedId = nil,
    assignTrialTag = nil,
    assignTargetKey = nil,
}

-- ---------------------------------------------------------- Tooltips ----

-- Peso de armadura de una pieza: el capturado si es valido: si no (kits
-- capturados antes de que el addon guardara este dato), se intenta leer en
-- vivo del item si todavia esta localizable en las bolsas.
local function ResolveArmorTypeLabel(piece)
    local label = EZOArmory.ArmorTypeLabel(piece.armorType)
    if label then return label end

    if piece.itemId and EZOArmory.Gear and EZOArmory.Gear.FindItemById
        and type(GetItemLink) == "function" and type(GetItemLinkArmorType) == "function" then
        local location = EZOArmory.Gear.FindItemById(piece.itemId)
        if location then
            local ok, link = pcall(GetItemLink, location.bag, location.slot)
            if ok and link and link ~= "" then
                local okArmor, armorType = pcall(GetItemLinkArmorType, link)
                if okArmor then
                    return EZOArmory.ArmorTypeLabel(armorType)
                end
            end
        end
    end
    return nil
end

-- Etiqueta de una pieza guardada: set (o nombre del item) + peso de armadura
-- si el slot es de armadura, por ejemplo "Slimecraw (Medium)". Es la unica
-- forma de distinguir a simple vista dos kits de un mismo set y slot pero
-- distinto peso (p.ej. dos cabezas de Slimecraw, una ligera y otra media), ya
-- que el icono es el mismo. Si no se puede determinar el peso (ni capturado ni
-- en vivo) se dice explicitamente en vez de omitirlo en silencio.
local function PieceSummaryLabel(piece, slotKey)
    local label = piece.setName ~= "" and piece.setName or piece.itemName
    local def = slotKey and EZOArmory.Gear and EZOArmory.Gear.GetSlotDef
        and EZOArmory.Gear.GetSlotDef(slotKey)
    if def and def.category == "armor" then
        local armorLabel = ResolveArmorTypeLabel(piece) or GetString(EZOARM_ARMOR_UNKNOWN)
        label = string.format("%s (%s)", tostring(label), armorLabel)
    end
    return tostring(label)
end

-- Tooltip de una pieza al pasar el raton por su icono. Si el item ya no esta
-- en las bolsas (banco, otro personaje...) no hay link real que mostrar; en
-- vez de un generico "no disponible" sin mas, se usan los datos capturados
-- (nombre, set, peso) para que la pieza se pueda identificar igualmente.
local function ShowItemTooltip(anchor, piece, slotKey)
    local itemId = piece and piece.itemId
    local location = itemId
        and EZOArmory.Gear and EZOArmory.Gear.FindItemById and EZOArmory.Gear.FindItemById(itemId)
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
        local text = GetString(EZOARM_WINDOW_TOOLTIP_NOT_AVAILABLE)
        if piece then
            text = PieceSummaryLabel(piece, slotKey) .. "\n" .. text
        end
        ZO_Tooltips_ShowTextTooltip(anchor, RIGHT, text)
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

-- Los tooltips reales (item, habilidad, estrella de CP) se comparten con la
-- pestana de builds, que pinta los mismos elementos. Se exponen aqui en vez de
-- duplicarlos alli: son los que ya estan verificados contra produccion.
WK.ShowItemTooltip = function(anchor, piece, slotKey) return ShowItemTooltip(anchor, piece, slotKey) end
WK.HideItemTooltip = HideItemTooltip
WK.ShowAbilityTooltip = ShowAbilityTooltip
WK.HideAbilityTooltip = HideAbilityTooltip
WK.ShowChampionTooltip = ShowChampionTooltip
WK.HideChampionTooltip = HideChampionTooltip

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

WK.ShowTextSummary = ShowTextSummary
WK.HideTextSummary = HideTextSummary

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

-- Restaura el nombre a su posicion de cabecera (linea propia arriba de la
-- fila). Gear lo re-ancla a su propio layout de una linea en FillGearRow;
-- este reset hace falta porque las filas se reciclan entre categorias y, sin
-- el, un nombre re-anclado por Gear se quedaba centrado verticalmente encima
-- de las habilidades/estrellas al reutilizar esa fila para Skills o CP.
local function ResetNameLabelAnchor(row)
    row.nameLabel:ClearAnchors()
    row.nameLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 6, 0)
    row.nameLabel:SetAnchor(TOPRIGHT, row, TOPRIGHT, -6, 0)
end

-- Oculta todo el contenido reutilizable de una fila antes de rellenarla de
-- nuevo, para que restos de la categoria/kit anterior no se cuelen.
local function ClearRowContent(row)
    ResetNameLabelAnchor(row)
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

local function GetKit(category, id)
    if category == CATEGORY_SKILLS then
        return EZOArmory.Skills.GetKit(id)
    elseif category == CATEGORY_CP then
        return EZOArmory.Champion.GetKit(id)
    end
    return EZOArmory.Kits.GetKit(id)
end

local function RenameKit(category, id, name)
    if category == CATEGORY_SKILLS then
        return EZOArmory.Skills.RenameKit(id, name)
    elseif category == CATEGORY_CP then
        return EZOArmory.Champion.RenameKit(id, name)
    end
    return EZOArmory.Kits.RenameKit(id, name)
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
            icon:SetHandler("OnMouseEnter", function(control) ShowItemTooltip(control, piece, slotKey) end)
            icon:SetHandler("OnMouseExit", HideItemTooltip)
        end
        if piece then
            summaryLines[#summaryLines + 1] = string.format("%s: %s", slotKey, PieceSummaryLabel(piece, slotKey))
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

-- Alterna entre la vista de lista (Gear/Skills/CP) y el panel de Assign:
-- ambas viven en la misma region de "content" y solo una esta visible.
-- Tres vistas comparten la region de contenido y solo una esta visible: la
-- lista de kits (Gear/Skills/CP), el panel de asignaciones y la pestana de
-- builds.
function WK.RefreshVisibility()
    local isAssign = WK.state.category == CATEGORY_ASSIGN
    local isBuilds = WK.state.category == CATEGORY_BUILDS
    local isKitList = not isAssign and not isBuilds

    if WK.countLabel then WK.countLabel:SetHidden(not isKitList) end
    if WK.scrollContainer then WK.scrollContainer:SetHidden(not isKitList) end
    if WK.actionBar then WK.actionBar:SetHidden(not isKitList) end
    if WK.assignRoot then WK.assignRoot:SetHidden(not isAssign) end
    if EZOArmory.WindowBuilds and EZOArmory.WindowBuilds.root then
        EZOArmory.WindowBuilds.root:SetHidden(not isBuilds)
    end
end

function WK.SetCategory(category)
    WK.state.category = category
    WK.state.selectedId = nil
    WK.RefreshVisibility()
    if category == CATEGORY_ASSIGN then
        WK.RefreshAssignPanel()
    elseif category == CATEGORY_BUILDS then
        EZOArmory.WindowBuilds.Refresh()
    else
        WK.Refresh()
    end
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

-- Etiqueta del boton de captura segun la categoria: lo que se lee del
-- personaje es distinto en cada una.
local CAPTURE_STRING = {
    [CATEGORY_GEAR] = "EZOARM_WINDOW_CAPTURE_GEAR",
    [CATEGORY_SKILLS] = "EZOARM_WINDOW_CAPTURE_SKILLS",
    [CATEGORY_CP] = "EZOARM_WINDOW_CAPTURE_CP",
}

function WK.RefreshActionBar()
    if not WK.deleteButton then return end
    local hasSelection = WK.state.selectedId ~= nil
    WK.deleteButton:SetHidden(not hasSelection)
    if WK.renameButton then
        WK.renameButton:SetHidden(not hasSelection)
    end
    if WK.equipButton then
        WK.equipButton:SetHidden(not hasSelection or WK.state.category == CATEGORY_ASSIGN)
    end
    if WK.captureButton then
        local stringName = CAPTURE_STRING[WK.state.category]
        WK.captureButton:SetHidden(stringName == nil)
        if stringName then
            WK.captureButton:SetText(GetString(_G[stringName]))
        end
    end
end

local function OnDeleteClicked()
    if not WK.state.selectedId then return end
    DeleteKit(WK.state.category, WK.state.selectedId)
    WK.state.selectedId = nil
    WK.Refresh()
end

-- Captura desde el personaje lo que corresponda a la pestana actual. Las tres
-- categorias ya deduplican por contenido real en el modelo, asi que capturar
-- algo que ya esta memorizado no crea un kit repetido: se avisa y se deja como
-- estaba.
local function OnCaptureClicked()
    local category = WK.state.category
    if not EZOArmory.Print then return end

    if category == CATEGORY_GEAR then
        local _, created, reused = EZOArmory.Kits.CaptureWornAsKits(nil, EZOArmory.BuildKitName)
        EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_KITS_CAPTURED_ALL), created, reused))
    elseif category == CATEGORY_SKILLS then
        local name = EZOArmory.AutoKitName(EZOARM_AUTONAME_SKILLS, EZOArmory.Skills.ListKits)
        local id, existing, reason = EZOArmory.Skills.CreateKitFromCurrent(name)
        if id then
            EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_SKILL_KIT_CREATED), name))
        elseif reason == "duplicate" and existing then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_SKILL_KIT_DUPLICATE), tostring(existing.name)))
        else
            EZOArmory.Print(GetString(EZOARM_MSG_SKILL_KIT_EMPTY))
        end
    elseif category == CATEGORY_CP then
        local name = EZOArmory.AutoKitName(EZOARM_AUTONAME_CP, EZOArmory.Champion.ListKits)
        local id, existing, reason = EZOArmory.Champion.CreateKitFromCurrent(name)
        if id then
            EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_CP_KIT_CREATED), name))
        elseif reason == "duplicate" and existing then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_CP_KIT_DUPLICATE), tostring(existing.name)))
        else
            EZOArmory.Print(GetString(EZOARM_MSG_CP_KIT_EMPTY))
        end
    else
        return
    end

    WK.Refresh()
end

-- Dialogo de renombrado, patron verificado en produccion (Wizard's Wardrobe,
-- WWG.ShowEditDialog): editBox = {} en el registro, texto inicial via
-- initialEditText, y ZO_Dialogs_GetEditBoxText(dialog) en el boton de
-- confirmar. Registrado con ZO_Dialogs_RegisterCustomDialog (API real, no la
-- tabla ESO_Dialogs directa), siguiendo el patron ya usado en EZOTools.
local RENAME_DIALOG_NAME = "EZOARMORY_RENAME_KIT"
local renameDialogRegistered = false

local function EnsureRenameDialog()
    if renameDialogRegistered then return true end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return false end

    ZO_Dialogs_RegisterCustomDialog(RENAME_DIALOG_NAME, {
        canQueue = true,
        title = { text = GetString(EZOARM_DIALOG_RENAME_TITLE) },
        mainText = { text = GetString(EZOARM_DIALOG_RENAME_TEXT) },
        editBox = {},
        buttons = {
            [1] = {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local category = WK.state.category
                    local kitId = WK.state.selectedId
                    if not kitId then return end
                    local input = ZO_Dialogs_GetEditBoxText(dialog)
                    if input and input ~= "" then
                        RenameKit(category, kitId, input)
                        WK.Refresh()
                    end
                end,
            },
            [2] = {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
        },
    })
    renameDialogRegistered = true
    return true
end

local function OnRenameClicked()
    if not WK.state.selectedId then return end
    if not EnsureRenameDialog() or type(ZO_Dialogs_ShowDialog) ~= "function" then return end
    local kit = GetKit(WK.state.category, WK.state.selectedId)
    if not kit then return end
    ZO_Dialogs_ShowDialog(RENAME_DIALOG_NAME, nil, { initialEditText = tostring(kit.name or "") })
end

-- Lanza el equipado de una lista de kitIds y reporta el resultado en chat.
-- Compartido por el boton Equip de la pestana Gear y por Equip Target/Equip
-- Here de la pestana Assign (misma logica que EquipKitIds en menu.lua).
local function EquipKitIds(kitIds)
    if not (EZOArmory.Equip and EZOArmory.Equip.ApplyKits) then return end

    EZOArmory.Equip.onQueued = function()
        if EZOArmory.Print then EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED)) end
    end
    EZOArmory.Equip.ApplyKits(kitIds, function(state)
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
        if state.missing > 0 and state.missingNames and #state.missingNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_EQUIP_MISSING), table.concat(state.missingNames, ", ")))
        end
    end)
end

-- Ranura un kit de habilidades (ambas barras) via Equip.ApplySkillKit.
local function EquipSkillKit(kitId)
    if not (EZOArmory.Equip and EZOArmory.Equip.ApplySkillKit) then return end

    EZOArmory.Equip.onQueued = function()
        if EZOArmory.Print then EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED)) end
    end
    EZOArmory.Equip.ApplySkillKit(kitId, function(state)
        if not EZOArmory.Print then return end
        if state.error == "noLibAsync" then
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
            return
        end
        if state.error == "empty" then
            EZOArmory.Print(GetString(EZOARM_MSG_SKILL_EQUIP_EMPTY))
            return
        end
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_SKILL_EQUIP_DONE), state.slotted, state.already, state.skipped))
        if state.skipped > 0 and state.skippedNames and #state.skippedNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_SKILL_EQUIP_SKIPPED), table.concat(state.skippedNames, ", ")))
        end
    end)
end

-- Ranura un kit de CP (las 12 estrellas) via Equip.ApplyCpKit. El aviso de
-- cola distingue combate de cooldown de CP (Equip.onQueued recibe el motivo).
local function EquipCpKit(kitId)
    if not (EZOArmory.Equip and EZOArmory.Equip.ApplyCpKit) then return end

    EZOArmory.Equip.onQueued = function(reason)
        if not EZOArmory.Print then return end
        if reason == "cpCooldown" then
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED_CP_COOLDOWN))
        else
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED))
        end
    end
    EZOArmory.Equip.ApplyCpKit(kitId, function(state)
        if not EZOArmory.Print then return end
        if state.error == "noLibAsync" then
            EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
            return
        end
        if state.error == "empty" then
            EZOArmory.Print(GetString(EZOARM_MSG_CP_EQUIP_EMPTY))
            return
        end
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_CP_EQUIP_DONE), state.slotted, state.already, state.skipped))
        if state.skipped > 0 and state.skippedNames and #state.skippedNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_CP_EQUIP_SKIPPED), table.concat(state.skippedNames, ", ")))
        end
    end)
end

local function OnEquipClicked()
    if not WK.state.selectedId then return end
    if WK.state.category == CATEGORY_GEAR then
        EquipKitIds({ WK.state.selectedId })
    elseif WK.state.category == CATEGORY_SKILLS then
        EquipSkillKit(WK.state.selectedId)
    elseif WK.state.category == CATEGORY_CP then
        EquipCpKit(WK.state.selectedId)
    end
end

-- ------------------------------------------------------------- Pestanas ----

local TAB_STRING = {
    [CATEGORY_BUILDS] = "EZOARM_WINDOW_TAB_BUILDS",
    [CATEGORY_GEAR] = "EZOARM_WINDOW_TAB_GEAR",
    [CATEGORY_SKILLS] = "EZOARM_WINDOW_TAB_SKILLS",
    [CATEGORY_CP] = "EZOARM_WINDOW_TAB_CP",
    [CATEGORY_ASSIGN] = "EZOARM_WINDOW_TAB_ASSIGN",
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

-- ------------------------------------------------------- Asignaciones ----
--
-- Pestana Assign: asigna una BUILD a cada trial/objetivo, por rol activo.
--
-- Antes se asignaban kits sueltos y habia que combinarlos hasta completar el
-- equipo; ahora una build ya lo lleva todo (equipo + habilidades + CP), asi
-- que a cada objetivo le corresponde UNA build. Misma herencia de siempre: un
-- objetivo sin build propia usa la "default" de su trial.
--
-- Las asignaciones por kits del modelo anterior siguen funcionando como
-- respaldo si un objetivo no tiene build (Builds.ResolveForTarget), para no
-- invalidar lo que ya estuviera configurado; se muestran marcadas como
-- heredadas del modelo antiguo.

local function EnsureAssignState()
    if WK.state.assignTrialTag == nil then
        local contextTrial = EZOArmory.Context and EZOArmory.Context.GetTrial and EZOArmory.Context.GetTrial()
        if contextTrial then
            WK.state.assignTrialTag = contextTrial.tag
        elseif EZOArmory.Zones and EZOArmory.Zones.TRIALS[1] then
            WK.state.assignTrialTag = EZOArmory.Zones.TRIALS[1].tag
        end
    end
    WK.state.assignTargetKey = WK.state.assignTargetKey or ASSIGN_TARGET_DEFAULT
end

-- Objetivos de una trial: default (fallback), trash, y cada boss/miniboss.
local function GetAssignTargetChoices(trialTag)
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

-- Rellena un ZO_ComboBox con entradas (label, value) y deja el texto mostrado
-- en sync con currentValue. onSelect(value) se llama al elegir una entrada.
-- Patron verificado (LibScrollableMenu, BanditsUserInterface): el combo se
-- crea con CreateControlFromVirtual "ZO_ComboBox" y su objeto Lua se obtiene
-- con ZO_ComboBox_ObjectFromContainer.
local function PopulateCombo(comboControl, labels, values, currentValue, onSelect)
    local combo = ZO_ComboBox_ObjectFromContainer(comboControl)
    combo:SetSortsItems(false)
    combo:ClearItems()
    local selectedLabel
    for i, label in ipairs(labels) do
        local value = values[i]
        local entry = combo:CreateItemEntry(label, function()
            onSelect(value)
        end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if value == currentValue then
            selectedLabel = label
        end
    end
    combo:UpdateItems()
    combo:SetSelectedItemText(selectedLabel or "")
end

local function PopulateTrialCombo()
    local labels, values = {}, {}
    for _, trial in ipairs(EZOArmory.Zones.TRIALS) do
        labels[#labels + 1] = trial.name
        values[#values + 1] = trial.tag
    end
    PopulateCombo(WK.assignTrialCombo, labels, values, WK.state.assignTrialTag, function(value)
        WK.state.assignTrialTag = value
        WK.state.assignTargetKey = ASSIGN_TARGET_DEFAULT
        WK.RefreshAssignPanel()
    end)
end

local function PopulateTargetCombo()
    local labels, values = GetAssignTargetChoices(WK.state.assignTrialTag)
    PopulateCombo(WK.assignTargetCombo, labels, values, WK.state.assignTargetKey, function(value)
        WK.state.assignTargetKey = value
        WK.RefreshAssignPanel()
    end)
end

-- Selector de build para el objetivo actual. Elegir en el desplegable asigna
-- directamente (una build por objetivo, no hay lista que componer); la primera
-- entrada desasigna. Las incompletas se pueden asignar pero se marcan: no se
-- equiparan hasta arreglarlas.
local function PopulateBuildCombo()
    local labels = { GetString(EZOARM_BUILD_NONE_SELECTED) }
    local values = { "" }
    for _, build in ipairs(EZOArmory.Builds.ListBuilds()) do
        local label = tostring(build.name)
        if not EZOArmory.Builds.Analyze(build).complete then
            label = label .. " " .. GetString(EZOARM_ASSIGN_INCOMPLETE_MARK)
        end
        labels[#labels + 1] = label
        values[#values + 1] = build.id
    end

    local role = EZOArmory.GetActiveRole()
    local stored = EZOArmory.Builds.GetStoredTrialAssignment(
        role, WK.state.assignTrialTag, WK.state.assignTargetKey) or ""

    PopulateCombo(WK.assignBuildCombo, labels, values, stored, function(value)
        EZOArmory.Builds.SetTrialAssignment(
            EZOArmory.GetActiveRole(), WK.state.assignTrialTag, WK.state.assignTargetKey,
            value ~= "" and value or nil)
        WK.RefreshAssignPanel()
    end)
end

-- Que se aplicaria realmente en este objetivo: build propia, heredada del
-- default de la trial, o los kits del modelo anterior si aun no tiene build.
local function RefreshAssignSummary()
    local label = WK.assignSummaryLabel
    if not label then return end

    local resolved = EZOArmory.Builds.ResolveForTarget(
        EZOArmory.GetActiveRole(), WK.state.assignTrialTag, WK.state.assignTargetKey)

    if not resolved then
        label:SetText(GetString(EZOARM_ASSIGN_NOTHING))
        label:SetColor(0.6, 0.6, 0.65, 1)
        return
    end

    if resolved.kind == "kits" then
        local names = {}
        for _, kitId in ipairs(resolved.kitIds) do
            local kit = EZOArmory.Kits.GetKit(kitId)
            if kit then names[#names + 1] = tostring(kit.name) end
        end
        label:SetText(zo_strformat(
            GetString(EZOARM_ASSIGN_LEGACY_KITS), table.concat(names, ", ")))
        label:SetColor(1, 0.8, 0.35, 1)
        return
    end

    local build = EZOArmory.Builds.GetBuild(resolved.buildId)
    local complete = EZOArmory.Builds.Analyze(build).complete
    local text = zo_strformat(GetString(resolved.source == "inherited"
        and EZOARM_ASSIGN_INHERITED or EZOARM_ASSIGN_OWN), tostring(build.name))
    if complete then
        label:SetText(text)
        label:SetColor(0.45, 0.9, 0.5, 1)
    else
        label:SetText(text .. " - " .. GetString(EZOARM_ASSIGN_INCOMPLETE))
        label:SetColor(1, 0.45, 0.45, 1)
    end
end

local function OnAssignClearClicked()
    EZOArmory.Builds.SetTrialAssignment(
        EZOArmory.GetActiveRole(), WK.state.assignTrialTag, WK.state.assignTargetKey, nil)
    WK.RefreshAssignPanel()
end

-- Informe por partes del equipado, compartido con la pestana Builds para que
-- el mensaje sea el mismo se equipe desde donde se equipe.
local function ReportEquipPart(part, state)
    if EZOArmory.WindowBuilds and EZOArmory.WindowBuilds.ReportEquipPart then
        EZOArmory.WindowBuilds.ReportEquipPart(part, state)
    end
end

-- Traduce a chat el motivo por el que no se ha equipado nada.
local function PrintNotEquipped(reason, trialTag)
    if not EZOArmory.Print then return end
    if reason == "incomplete" then
        EZOArmory.Print(GetString(EZOARM_MSG_BUILD_INCOMPLETE))
        return
    end
    local trial = EZOArmory.Zones.GetTrialByTag(trialTag)
    EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_EQUIP_NO_ASSIGNMENT),
        trial and trial.name or tostring(trialTag)))
end

-- Equipa lo asignado al objetivo seleccionado en el panel (con herencia). No
-- depende de donde estes: sirve para probar y para prepararte antes de entrar.
local function OnAssignEquipTargetClicked()
    local mode, reason = EZOArmory.Builds.EquipForTarget(
        EZOArmory.GetActiveRole(), WK.state.assignTrialTag, WK.state.assignTargetKey,
        ReportEquipPart)
    if not mode then
        PrintNotEquipped(reason, WK.state.assignTrialTag)
    end
end

-- Equipa lo aplicable a donde estas ahora mismo, segun el contexto en vivo.
local function OnAssignEquipHereClicked()
    local trial, targetKey = EZOArmory.Builds.GetCurrentTarget()
    if not trial then
        if EZOArmory.Print then EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_NO_TRIAL)) end
        return
    end

    local mode, reason = EZOArmory.Builds.EquipForTarget(
        EZOArmory.GetActiveRole(), trial.tag, targetKey, ReportEquipPart)
    if not mode then
        PrintNotEquipped(reason, trial.tag)
    end
end

function WK.RefreshAssignPanel()
    if not WK.assignRoot then return end
    EnsureAssignState()
    if WK.assignRoleLabel then
        WK.assignRoleLabel:SetText(zo_strformat(
            GetString(EZOARM_WINDOW_ASSIGN_ROLE), EZOArmory.RoleLabel(EZOArmory.GetActiveRole())))
    end
    PopulateTrialCombo()
    PopulateTargetCombo()
    PopulateBuildCombo()
    RefreshAssignSummary()
end

-- Fila etiqueta + combo nativo, ancho de ambos lados (mismo truco de anclas
-- TOPLEFT+TOPRIGHT que las filas de Gear/Skills/CP: fija el ancho, la altura
-- la da SetHeight). El combo se crea con CreateControlFromVirtual "ZO_ComboBox"
-- + ZO_ComboBox_ObjectFromContainer, patron verificado (LibScrollableMenu,
-- BanditsUserInterface) para crear dropdowns nativos sin XML propio.
local function CreateAssignComboRow(parent, name, labelStringId, y)
    local label = WM:CreateControl(nil, parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(0.75, 0.75, 0.8, 1)
    label:SetDimensions(ASSIGN_LABEL_WIDTH, ASSIGN_ROW_HEIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    label:SetText(GetString(labelStringId))

    local combo = WM:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    combo:SetHeight(ASSIGN_ROW_HEIGHT)
    combo:SetAnchor(TOPLEFT, label, TOPRIGHT, 8, 0)
    combo:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
    return combo
end

-- Construye la pestana Assign completa (bloque fijo + barra de accion fija
-- abajo) dentro de "content", oculta hasta que se seleccione esa pestana.
local function CreateAssignPanel(content)
    local assignRoot = WM:CreateControl(nil, content, CT_CONTROL)
    assignRoot:SetAnchorFill(content)
    assignRoot:SetHidden(true)
    WK.assignRoot = assignRoot

    local roleLabel = WM:CreateControl(nil, assignRoot, CT_LABEL)
    roleLabel:SetFont("ZoFontGameBold")
    roleLabel:SetColor(0.85, 0.85, 0.9, 1)
    roleLabel:SetAnchor(TOPLEFT, assignRoot, TOPLEFT, 0, 0)
    WK.assignRoleLabel = roleLabel

    local trialY = 24
    local targetY = trialY + ASSIGN_ROW_HEIGHT + ASSIGN_ROW_GAP
    WK.assignTrialCombo = CreateAssignComboRow(
        assignRoot, "EZOArmoryAssignTrialCombo", EZOARM_OPTION_ASSIGN_TRIAL, trialY)
    WK.assignTargetCombo = CreateAssignComboRow(
        assignRoot, "EZOArmoryAssignTargetCombo", EZOARM_OPTION_ASSIGN_TARGET, targetY)

    -- Una build por objetivo: basta un desplegable, sin lista que componer.
    local buildY = targetY + ASSIGN_ROW_HEIGHT + ASSIGN_ROW_GAP
    WK.assignBuildCombo = CreateAssignComboRow(
        assignRoot, "EZOArmoryAssignBuildCombo", EZOARM_WINDOW_TAB_BUILDS, buildY)

    local summaryHeaderY = buildY + ASSIGN_ROW_HEIGHT + 14
    local summaryHeader = WM:CreateControl(nil, assignRoot, CT_LABEL)
    summaryHeader:SetFont("ZoFontGameBold")
    summaryHeader:SetColor(0.85, 0.85, 0.9, 1)
    summaryHeader:SetAnchor(TOPLEFT, assignRoot, TOPLEFT, 0, summaryHeaderY)
    summaryHeader:SetText(GetString(EZOARM_ASSIGN_APPLIES_HERE))

    -- Que se aplicaria de verdad aqui, resolviendo herencia y respaldo por
    -- kits: sin esto no se distingue "sin asignar" de "hereda del default".
    local summaryLabel = WM:CreateControl(nil, assignRoot, CT_LABEL)
    summaryLabel:SetFont("ZoFontGame")
    summaryLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    summaryLabel:SetAnchor(TOPLEFT, assignRoot, TOPLEFT, 0, summaryHeaderY + 22)
    summaryLabel:SetAnchor(TOPRIGHT, assignRoot, TOPRIGHT, 0, summaryHeaderY + 22)
    WK.assignSummaryLabel = summaryLabel

    -- Barra de accion fija abajo (Equip Target / Equip Here / Clear), mismo
    -- estilo y orden (dangerous a la derecha) que la barra de Gear/Skills/CP.
    local assignActionBar = WM:CreateControl(nil, assignRoot, CT_CONTROL)
    assignActionBar:SetDimensions(1, 26)
    assignActionBar:SetAnchor(BOTTOMLEFT, assignRoot, BOTTOMLEFT, 0, 0)
    assignActionBar:SetAnchor(BOTTOMRIGHT, assignRoot, BOTTOMRIGHT, 0, 0)

    local clearButton = WM:CreateControl(nil, assignActionBar, CT_BUTTON)
    clearButton:SetDimensions(160, 24)
    clearButton:SetAnchor(BOTTOMRIGHT, assignActionBar, BOTTOMRIGHT, 0, 0)
    clearButton:SetFont("ZoFontGameBold")
    clearButton:SetNormalFontColor(1, 0.55, 0.55, 1)
    clearButton:SetMouseOverFontColor(1, 0.3, 0.3, 1)
    clearButton:SetText(GetString(EZOARM_OPTION_ASSIGN_CLEAR))
    clearButton:SetHandler("OnClicked", OnAssignClearClicked)

    local equipHereButton = WM:CreateControl(nil, assignActionBar, CT_BUTTON)
    equipHereButton:SetDimensions(160, 24)
    equipHereButton:SetAnchor(RIGHT, clearButton, LEFT, -12, 0)
    equipHereButton:SetFont("ZoFontGameBold")
    equipHereButton:SetNormalFontColor(0.6, 1, 0.6, 1)
    equipHereButton:SetMouseOverFontColor(0.4, 1, 0.4, 1)
    equipHereButton:SetText(GetString(EZOARM_OPTION_EQUIP_HERE))
    equipHereButton:SetHandler("OnClicked", OnAssignEquipHereClicked)

    local equipTargetButton = WM:CreateControl(nil, assignActionBar, CT_BUTTON)
    equipTargetButton:SetDimensions(160, 24)
    equipTargetButton:SetAnchor(RIGHT, equipHereButton, LEFT, -12, 0)
    equipTargetButton:SetFont("ZoFontGameBold")
    equipTargetButton:SetNormalFontColor(0.6, 1, 0.6, 1)
    equipTargetButton:SetMouseOverFontColor(0.4, 1, 0.4, 1)
    equipTargetButton:SetText(GetString(EZOARM_OPTION_EQUIP_TARGET))
    equipTargetButton:SetHandler("OnClicked", OnAssignEquipTargetClicked)
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
    WK.actionBar = actionBar

    -- Anchos ajustados para que el grupo de la izquierda (capturar, que lee del
    -- personaje) y el de la derecha (acciones sobre el kit seleccionado) quepan
    -- a la vez en la barra sin solaparse.
    local deleteButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    deleteButton:SetDimensions(110, 24)
    deleteButton:SetAnchor(BOTTOMRIGHT, actionBar, BOTTOMRIGHT, 0, 0)
    deleteButton:SetFont("ZoFontGameBold")
    deleteButton:SetNormalFontColor(1, 0.55, 0.55, 1)
    deleteButton:SetMouseOverFontColor(1, 0.3, 0.3, 1)
    deleteButton:SetText(GetString(EZOARM_WINDOW_BTN_DELETE))
    deleteButton:SetHandler("OnClicked", OnDeleteClicked)
    deleteButton:SetHidden(true)
    WK.deleteButton = deleteButton

    local renameButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    renameButton:SetDimensions(110, 24)
    renameButton:SetAnchor(RIGHT, deleteButton, LEFT, -12, 0)
    renameButton:SetFont("ZoFontGameBold")
    renameButton:SetNormalFontColor(0.8, 0.85, 1, 1)
    renameButton:SetMouseOverFontColor(0.6, 0.75, 1, 1)
    renameButton:SetText(GetString(EZOARM_WINDOW_BTN_RENAME))
    renameButton:SetHandler("OnClicked", OnRenameClicked)
    renameButton:SetHidden(true)
    WK.renameButton = renameButton

    -- A la izquierda, separado de las acciones sobre el kit seleccionado: no
    -- opera sobre la seleccion, lee del personaje.
    local captureButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    captureButton:SetDimensions(210, 24)
    captureButton:SetAnchor(BOTTOMLEFT, actionBar, BOTTOMLEFT, 0, 0)
    captureButton:SetFont("ZoFontGameBold")
    captureButton:SetNormalFontColor(0.85, 0.85, 0.9, 1)
    captureButton:SetMouseOverFontColor(1, 1, 1, 1)
    captureButton:SetText(GetString(EZOARM_WINDOW_CAPTURE_GEAR))
    captureButton:SetHandler("OnClicked", OnCaptureClicked)
    WK.captureButton = captureButton

    local equipButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    equipButton:SetDimensions(110, 24)
    equipButton:SetAnchor(RIGHT, renameButton, LEFT, -12, 0)
    equipButton:SetFont("ZoFontGameBold")
    equipButton:SetNormalFontColor(0.6, 1, 0.6, 1)
    equipButton:SetMouseOverFontColor(0.4, 1, 0.4, 1)
    equipButton:SetText(GetString(EZOARM_WINDOW_BTN_EQUIP))
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
    WK.scrollContainer = scrollContainer

    EnsureRows(listRoot, scrollContainer)

    CreateAssignPanel(content)
    EZOArmory.WindowBuilds.Create(content)

    WK.RefreshTabs()
    WK.Refresh()
    WK.RefreshVisibility()
    if WK.state.category == CATEGORY_BUILDS then
        EZOArmory.WindowBuilds.Refresh()
    end

    return root
end
