-- Pestana "Builds" de la ventana propia: listado y editor.
--
-- Se monta dentro del area de contenido de window_kits y alterna dos vistas
-- sobre el mismo espacio:
--   - LISTA:  una fila por build con su rol, estado y los elementos que la
--             componen (equipo, habilidades, CP), cada uno con su tooltip real.
--   - EDITOR: composicion de la build (que kits la forman) y las revisiones.
--
-- Los tooltips reales se reutilizan de window_kits (WK.Show*Tooltip), que son
-- los ya verificados contra produccion; aqui no se duplica esa logica.
--
-- Igual que la pestana Assign, el layout usa alturas y desplazamientos FIJOS
-- en vez de calcularlos por contenido: las filas de altura variable de
-- Gear/Skills/CP causaron bugs reales de anclaje, y este panel tiene forma
-- estable.

EZOArmory = EZOArmory or {}
EZOArmory.WindowBuilds = EZOArmory.WindowBuilds or {}

local WB = EZOArmory.WindowBuilds
local WM = WINDOW_MANAGER

local ROLE_ICON_SIZE = 26
local GEAR_ICON_SIZE = 24
local GEAR_ICON_GAP = 2
local ABILITY_ICON_SIZE = 24
local ABILITY_ICON_GAP = 2
local ABILITIES_PER_BAR = 6
local MAX_GEAR_ICONS = 14
local MAX_ABILITY_ICONS = ABILITIES_PER_BAR * 2

-- Fila de build: tres lineas (cabecera, equipo, habilidades + CP).
local BUILD_ROW_HEADER_H = 26
local BUILD_ROW_GEAR_H = GEAR_ICON_SIZE + 4
local BUILD_ROW_SKILL_H = ABILITY_ICON_SIZE + 4
local BUILD_ROW_HEIGHT = BUILD_ROW_HEADER_H + BUILD_ROW_GEAR_H + BUILD_ROW_SKILL_H + 6
local BUILD_ROW_SPACING = 8
local MAX_BUILD_ROWS = 16

-- Editor.
local ED_LABEL_WIDTH = 110
local ED_ROW_HEIGHT = 26
local ED_ROW_GAP = 6
local ED_LIST_ROW_HEIGHT = 20
local ED_LIST_ROW_GAP = 3
local MAX_ED_GEAR_ROWS = 6
local MAX_ISSUE_ROWS = 7

local STATUS_COLOR = {
    ok = { 0.45, 0.9, 0.5 },
    warning = { 1, 0.8, 0.35 },
    error = { 1, 0.45, 0.45 },
}

-- Iconos de estado. Texturas NATIVAS del juego, verificadas contra el codigo
-- fuente de la interfaz (aparecen referenciadas en esoui): no son rutas
-- inventadas ni arte propio. Se tinen con STATUS_COLOR, asi que el mismo
-- simbolo vale para el color que toque.
local STATUS_ICON_SIZE = 20
local STATUS_ICON = {
    ok = "EsoUI/Art/Buttons/accept_up.dds",
    warning = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds",
    error = "EsoUI/Art/Buttons/decline_up.dds",
}

-- Categoria: icono en la fila y cabecera de grupo en la lista.
local CATEGORY_ICON_SIZE = 18
local ROW_COMBO_WIDTH = 150
local ROW_COMBO_HEIGHT = 22
-- Mismo alto que los botones de texto de la barra (CreateActionButton usa 24):
-- encadenado a ellos, uno mas alto sobresaldria por arriba de la barra.
local UNDRESS_BUTTON_SIZE = 24
local UNDRESS_BUTTON_IDLE_ALPHA = 0.65
local GROUP_HEADER_H = 22
local GROUP_HEADER_GAP = 6
-- Una cabecera por categoria mas la de "sin catalogar". Fijo y con holgura:
-- las cabeceras se crean una vez y se reciclan, como las filas.
local MAX_GROUP_HEADERS = 12

local NAME_COLOR_DEFAULT = { 0.92, 0.92, 0.95 }

WB.state = WB.state or {
    view = "list",     -- "list" | "editor"
    selectedId = nil,
    editingId = nil,
    pickGearKitId = nil,
    filter = "all",    -- "all" | id de categoria | Builds.CATEGORY_NONE
}

-- ------------------------------------------------------------- Textos ----

-- Traduce una incidencia del motor de coherencia (o de la propia build) a una
-- linea legible. Cada tipo tiene su plantilla con los datos que aporta.
local function IssueText(issue)
    local slot = EZOArmory.SlotLabel
    local bar = EZOArmory.BarLabel
    local t = issue.type

    if t == "noGearKits" then
        return GetString(EZOARM_ISSUE_NO_GEAR_KITS)
    elseif t == "noSkillKit" then
        return GetString(EZOARM_ISSUE_NO_SKILL_KIT)
    elseif t == "noCpKit" then
        return GetString(EZOARM_ISSUE_NO_CP_KIT)
    elseif t == "slotConflict" then
        return zo_strformat(GetString(EZOARM_ISSUE_SLOT_CONFLICT),
            slot(issue.slot), tostring(issue.kitName), tostring(issue.otherKitName))
    elseif t == "unassignedSlot" then
        return zo_strformat(GetString(EZOARM_ISSUE_UNASSIGNED_SLOT), slot(issue.slot), bar(issue.bar))
    elseif t == "setOverfill" then
        return zo_strformat(GetString(EZOARM_ISSUE_SET_OVERFILL),
            tostring(issue.setName), issue.count, bar(issue.bar), issue.maxEquipped)
    elseif t == "multipleMythics" then
        return GetString(EZOARM_ISSUE_MULTIPLE_MYTHICS)
    elseif t == "duplicateItem" then
        return zo_strformat(GetString(EZOARM_ISSUE_DUPLICATE_ITEM), slot(issue.slot), slot(issue.otherSlot))
    elseif t == "barIncomplete" then
        return zo_strformat(GetString(EZOARM_ISSUE_BAR_INCOMPLETE), bar(issue.bar), issue.pieces, issue.expected)
    elseif t == "weaponMismatch" then
        return zo_strformat(GetString(EZOARM_ISSUE_WEAPON_MISMATCH), bar(issue.bar), tostring(issue.skillKitName))
    elseif t == "emptyKit" then
        return zo_strformat(GetString(EZOARM_ISSUE_EMPTY_KIT), tostring(issue.kitName))
    elseif t == "unknownSlot" then
        return zo_strformat(GetString(EZOARM_ISSUE_UNKNOWN_SLOT), tostring(issue.kitName), tostring(issue.slot))
    end
    return tostring(t)
end

local function StatusColor(status)
    local color = STATUS_COLOR[status] or STATUS_COLOR.error
    return color[1], color[2], color[3], 1
end

-- Igual que en la pestana Assign: combos nativos creados en runtime con
-- CreateControlFromVirtual + ZO_ComboBox_ObjectFromContainer.
--
-- Vive aqui arriba, y no en la seccion del editor donde nacio, porque ahora
-- tambien lo usan las filas de la lista, que se construyen antes.
local function PopulateCombo(comboControl, labels, values, currentValue, onSelect)
    local combo = ZO_ComboBox_ObjectFromContainer(comboControl)
    combo:SetSortsItems(false)
    combo:ClearItems()
    local selectedLabel
    for i, label in ipairs(labels) do
        local value = values[i]
        local entry = combo:CreateItemEntry(label, function() onSelect(value) end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if value == currentValue then
            selectedLabel = label
        end
    end
    combo:UpdateItems()
    combo:SetSelectedItemText(selectedLabel or GetString(EZOARM_BUILD_NONE_SELECTED))
end

-- Opciones de categoria para los desplegables. "Sin catalogar" va la primera
-- donde se elige la categoria de una build (es el valor de partida) y la
-- ultima en el filtro, para que ahi coincida con el orden de los grupos de la
-- lista, donde las sin catalogar cierran el listado.
local function CategoryChoices(noneFirst)
    local labels, values = {}, {}
    if noneFirst then
        labels[1] = EZOArmory.Builds.GetCategoryLabel(nil)
        values[1] = EZOArmory.Builds.CATEGORY_NONE
    end
    for _, entry in ipairs(EZOArmory.Builds.CATEGORIES) do
        labels[#labels + 1] = EZOArmory.Builds.GetCategoryLabel(entry.id)
        values[#values + 1] = entry.id
    end
    if not noneFirst then
        labels[#labels + 1] = EZOArmory.Builds.GetCategoryLabel(nil)
        values[#values + 1] = EZOArmory.Builds.CATEGORY_NONE
    end
    return labels, values
end

-- Cambiar la categoria reordena la lista entera (las builds se agrupan por
-- ella), y eso no se puede hacer desde dentro del propio callback del combo:
-- se estaria repintando el control que aun esta despachando su clic. Se deja
-- para el fotograma siguiente.
local function SetCategoryAndRefresh(buildId, value, refresh)
    EZOArmory.Builds.SetCategory(buildId, value)
    zo_callLater(refresh, 0)
end

-- ------------------------------------------------------- Fila de build ----

-- OJO: la fila NO se habilita para el raton (ver el mismo aviso en
-- window_kits): al hacerlo en 0.11.3 se quedaba ella con el cursor y los
-- iconos hijos dejaban de recibir OnMouseEnter.
local function CreateBuildRow(parent, index)
    local row = WM:CreateControl("EZOArmoryBuildRow" .. index, parent, CT_CONTROL)
    row:SetHeight(BUILD_ROW_HEIGHT)

    local bg = WM:CreateControl(nil, row, CT_BACKDROP)
    bg:SetAnchorFill(row)
    bg:SetEdgeTexture(nil, 1, 1, 1, 0)
    bg:SetCenterColor(1, 1, 1, 0.04)
    bg:SetHidden(true)
    row.selectionBg = bg

    local roleIcon = WM:CreateControl(nil, row, CT_TEXTURE)
    roleIcon:SetDimensions(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
    roleIcon:SetAnchor(TOPLEFT, row, TOPLEFT, 6, 0)
    roleIcon:SetMouseEnabled(true)
    roleIcon:SetHidden(true)
    row.roleIcon = roleIcon

    local name = WM:CreateControl(nil, row, CT_LABEL)
    name:SetFont("ZoFontGameBold")
    name:SetColor(NAME_COLOR_DEFAULT[1], NAME_COLOR_DEFAULT[2], NAME_COLOR_DEFAULT[3], 1)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetHeight(BUILD_ROW_HEADER_H)
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Anclas LEFT/RIGHT, no TOPLEFT/TOPRIGHT: los vecinos de esta linea (el
    -- desplegable de categoria, el icono de estado) son mas bajos que la banda
    -- de cabecera y van centrados en ella, asi que con anclas TOP* habria que
    -- compensar a mano la altura de cada uno, y las dos anclas de esta
    -- etiqueta acabarian pidiendo Y distintas. Centro contra centro cuadra
    -- solo, sin numeros magicos.
    name:SetAnchor(LEFT, roleIcon, RIGHT, 8, 0)
    name:SetMouseEnabled(true)
    row.nameLabel = name

    -- Estado, a la derecha: un icono en vez de una frase. Ocupaba todo el lado
    -- derecho de la fila para decir siempre lo mismo; el icono lo resume y
    -- deja el sitio libre. El detalle sigue estando en el emergente.
    local statusIcon = WM:CreateControl(nil, row, CT_TEXTURE)
    statusIcon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    statusIcon:SetAnchor(TOPRIGHT, row, TOPRIGHT, -6, (BUILD_ROW_HEADER_H - STATUS_ICON_SIZE) / 2)
    statusIcon:SetMouseEnabled(true)
    row.statusIcon = statusIcon

    -- Cuando hay algo que revisar, el numero acompana al icono: "cuantas" es
    -- informacion que el icono solo no da.
    local status = WM:CreateControl(nil, row, CT_LABEL)
    status:SetFont("ZoFontGameSmall")
    status:SetHeight(BUILD_ROW_HEADER_H)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    -- Centro contra centro, por el mismo motivo que la etiqueta del nombre:
    -- el icono de estado es mas bajo que la banda de cabecera y va centrado
    -- en ella, asi que anclar TOP con TOP arrastraria ese desfase a todo lo
    -- que se encadene despues por la izquierda.
    status:SetAnchor(RIGHT, statusIcon, LEFT, -4, 0)
    status:SetMouseEnabled(true)
    row.statusLabel = status

    -- Categoria en la propia fila. El hueco entre el nombre y el estado
    -- estaba vacio, y catalogar quince builds de una en una entrando y
    -- saliendo del editor es justo el trabajo que esto viene a quitar. La
    -- misma opcion sigue en el editor: aqui es un atajo, no un traslado.
    --
    -- Ocupa solo la banda de la cabecera (26 px), asi que no se pone por
    -- delante de las filas de iconos de abajo: un control ancho con el raton
    -- activado tapando iconos es el fallo que ya se arreglo tres veces (ver
    -- el aviso de cpLabel).
    local categoryCombo = WM:CreateControlFromVirtual(
        "EZOArmoryBuildRowCategory" .. index, row, "ZO_ComboBox")
    categoryCombo:SetDimensions(ROW_COMBO_WIDTH, ROW_COMBO_HEIGHT)
    categoryCombo:SetAnchor(RIGHT, status, LEFT, -8, 0)
    ZO_ComboBox_ObjectFromContainer(categoryCombo):SetFont("ZoFontGameSmall")
    row.categoryCombo = categoryCombo

    name:SetAnchor(RIGHT, categoryCombo, LEFT, -8, 0)

    row.gearIcons = {}
    for i = 1, MAX_GEAR_ICONS do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(GEAR_ICON_SIZE, GEAR_ICON_SIZE)
        icon:SetMouseEnabled(true)
        icon:SetHidden(true)
        row.gearIcons[i] = icon
    end

    row.abilityIcons = {}
    for i = 1, MAX_ABILITY_ICONS do
        local icon = WM:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(ABILITY_ICON_SIZE, ABILITY_ICON_SIZE)
        icon:SetMouseEnabled(true)
        icon:SetHidden(true)
        row.abilityIcons[i] = icon
    end

    local cpLabel = WM:CreateControl(nil, row, CT_LABEL)
    cpLabel:SetFont("ZoFontGameSmall")
    cpLabel:SetColor(0.8, 0.8, 0.85, 1)
    cpLabel:SetHeight(BUILD_ROW_SKILL_H)
    cpLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    cpLabel:SetMouseEnabled(true)
    cpLabel:SetHidden(true)
    row.cpLabel = cpLabel

    -- Un clic selecciona; el doble clic va directo a los kits de esa build,
    -- que es lo que casi siempre se quiere hacer con ella.
    local function OnRowClick(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        WB.SelectBuild(row.buildId)
    end
    local function OnRowDoubleClick(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not row.buildId then return end
        WB.SelectBuild(row.buildId)
        WB.EditSelected()
    end

    row:SetHandler("OnMouseUp", OnRowClick)
    row:SetHandler("OnMouseDoubleClick", OnRowDoubleClick)
    name:SetHandler("OnMouseUp", OnRowClick)
    name:SetHandler("OnMouseDoubleClick", OnRowDoubleClick)

    return row
end

local function ClearBuildRow(row)
    for _, icon in ipairs(row.gearIcons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
    for _, icon in ipairs(row.abilityIcons) do
        icon:SetHidden(true)
        icon:SetHandler("OnMouseEnter", nil)
        icon:SetHandler("OnMouseExit", nil)
    end
    row.cpLabel:SetHidden(true)
    row.cpLabel:SetHandler("OnMouseEnter", nil)
    row.cpLabel:SetHandler("OnMouseExit", nil)
    row.roleIcon:SetHandler("OnMouseEnter", nil)
    row.roleIcon:SetHandler("OnMouseExit", nil)
    row.statusLabel:SetHandler("OnMouseEnter", nil)
    row.statusLabel:SetHandler("OnMouseExit", nil)
    -- Las filas se reciclan entre builds: sin limpiar esto, el emergente de
    -- una build anterior se quedaria pegado al icono de la siguiente.
    row.statusIcon:SetHandler("OnMouseEnter", nil)
    row.statusIcon:SetHandler("OnMouseExit", nil)
end

-- Cabecera de grupo de la lista: icono de la categoria y su nombre.
local function CreateGroupHeader(parent, index)
    local header = WM:CreateControl("EZOArmoryBuildGroup" .. index, parent, CT_CONTROL)
    header:SetHeight(GROUP_HEADER_H)

    local icon = WM:CreateControl(nil, header, CT_TEXTURE)
    icon:SetDimensions(CATEGORY_ICON_SIZE, CATEGORY_ICON_SIZE)
    icon:SetAnchor(LEFT, header, LEFT, 6, 0)
    icon:SetHidden(true)
    header.icon = icon

    local label = WM:CreateControl(nil, header, CT_LABEL)
    label:SetFont("ZoFontGameBold")
    label:SetColor(0.65, 0.62, 0.78, 1)
    label:SetHeight(GROUP_HEADER_H)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(LEFT, icon, RIGHT, 6, 0)
    header.label = label

    -- Linea fina bajo el titulo, para que el grupo se lea como bloque.
    local line = WM:CreateControl(nil, header, CT_BACKDROP)
    line:SetHeight(1)
    line:SetAnchor(BOTTOMLEFT, header, BOTTOMLEFT, 6, 0)
    line:SetAnchor(BOTTOMRIGHT, header, BOTTOMRIGHT, -6, 0)
    line:SetEdgeTexture(nil, 1, 1, 1, 0)
    line:SetCenterColor(0.55, 0.5, 0.7, 0.35)

    header:SetHidden(true)
    return header
end

-- Pinta las piezas de equipo de la build en orden canonico de slot, cada una
-- con su tooltip de item real.
local function FillRowGear(row, report)
    local WK = EZOArmory.WindowKits
    local slots = EZOArmory.Gear.SLOT_DEFS
    local index = 0
    local previous

    for _, def in ipairs(slots) do
        local entry = report.assignment and report.assignment[def.key]
        if entry and entry.icon and entry.icon ~= "" and index < MAX_GEAR_ICONS then
            index = index + 1
            local icon = row.gearIcons[index]
            icon:SetTexture(entry.icon)
            icon:SetHidden(false)
            icon:ClearAnchors()
            if previous then
                icon:SetAnchor(LEFT, previous, RIGHT, GEAR_ICON_GAP, 0)
            else
                icon:SetAnchor(TOPLEFT, row, TOPLEFT, 6, BUILD_ROW_HEADER_H)
            end
            local slotKey = def.key
            icon:SetHandler("OnMouseEnter", function(control)
                WK.ShowItemTooltip(control, entry, slotKey)
            end)
            icon:SetHandler("OnMouseExit", WK.HideItemTooltip)
            previous = icon
        end
    end
end

-- Pinta las dos barras del kit de habilidades y un resumen de CP, cada uno con
-- su tooltip real (habilidad y estrellas).
local function FillRowSkillsAndCp(row, build)
    local WK = EZOArmory.WindowKits
    local y = BUILD_ROW_HEADER_H + BUILD_ROW_GEAR_H
    local index = 0
    local previous

    local skillKit = build.skillKitId and EZOArmory.Skills.GetKit(build.skillKitId)
    if skillKit then
        for hotbar = EZOArmory.Skills.HOTBAR_FRONT, EZOArmory.Skills.HOTBAR_BACK do
            for _, entry in ipairs(EZOArmory.Skills.GetBarAbilityEntries(skillKit, hotbar)) do
                if index >= MAX_ABILITY_ICONS then break end
                if entry.icon and entry.icon ~= "" then
                    index = index + 1
                    local icon = row.abilityIcons[index]
                    icon:SetTexture(entry.icon)
                    icon:SetHidden(false)
                    icon:ClearAnchors()
                    if previous then
                        -- Un hueco algo mayor separa la barra trasera de la frontal.
                        local gap = (index == ABILITIES_PER_BAR + 1) and (ABILITY_ICON_GAP + 10) or ABILITY_ICON_GAP
                        icon:SetAnchor(LEFT, previous, RIGHT, gap, 0)
                    else
                        icon:SetAnchor(TOPLEFT, row, TOPLEFT, 6, y)
                    end
                    local abilityId = entry.abilityId
                    icon:SetHandler("OnMouseEnter", function(control)
                        WK.ShowAbilityTooltip(control, abilityId)
                    end)
                    icon:SetHandler("OnMouseExit", WK.HideAbilityTooltip)
                    previous = icon
                end
            end
        end
    end

    local cpKit = build.cpKitId and EZOArmory.Champion.GetKit(build.cpKitId)
    if cpKit then
        local cpLabel = row.cpLabel
        cpLabel:SetText(string.format("%s (%d)",
            tostring(cpKit.name), EZOArmory.Champion.CountStars(cpKit)))
        cpLabel:SetHidden(false)
        cpLabel:ClearAnchors()
        if previous then
            cpLabel:SetAnchor(LEFT, previous, RIGHT, 14, 0)
        else
            cpLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 6, y)
        end

        -- SIN ancla derecha, y con ancho medido del propio texto. Antes se
        -- estiraba hasta el borde de la fila, y como ademas lleva el raton
        -- activado (para su emergente), ese control ancho y transparente
        -- cubria todo lo que quedara a su derecha: los iconos de ahi dejaban
        -- de recibir el cursor y no mostraban su emergente. Mismo mecanismo
        -- que el area "Scroll" que rompio los emergentes en 0.11.10: un
        -- control por delante que se queda con el raton.
        local textWidth = (cpLabel.GetTextWidth and cpLabel:GetTextWidth()) or 0
        cpLabel:SetWidth(textWidth > 0 and textWidth + 4 or 120)

        -- El detalle por estrella ya se ve en la pestana CP; aqui basta un
        -- resumen agrupado por arbol al pasar el raton.
        local lines = {}
        for _, group in ipairs(EZOArmory.Champion.GetStarsByDiscipline(cpKit)) do
            local names = {}
            for _, star in ipairs(group.stars) do
                names[#names + 1] = star.name
            end
            lines[#lines + 1] = table.concat(names, ", ")
        end
        cpLabel:SetHandler("OnMouseEnter", function(control)
            WK.ShowTextSummary(control, cpKit.name, lines)
        end)
        cpLabel:SetHandler("OnMouseExit", WK.HideTextSummary)
    end
end

local function FillBuildRow(row, build)
    local WK = EZOArmory.WindowKits
    local report = EZOArmory.Builds.Analyze(build)

    row.nameLabel:SetText(tostring(build.name))
    -- El nombre se tine tambien con el color de estado (igual que el numero
    -- de la derecha) para que un problema salte a la vista sin tener que
    -- fijarse en el numerito: rojo si hay algun error, ambar si solo son
    -- avisos, y el color normal si todo esta bien.
    if report.status == EZOArmory.Builds.STATUS_OK then
        row.nameLabel:SetColor(NAME_COLOR_DEFAULT[1], NAME_COLOR_DEFAULT[2], NAME_COLOR_DEFAULT[3], 1)
    else
        row.nameLabel:SetColor(StatusColor(report.status))
    end

    -- El icono de la izquierda pasa a llevar la CATEGORIA, no el rol.
    --
    -- Con el rol se veia siempre lo mismo: casi todas las builds son de dano,
    -- asi que era el mismo dibujo repetido fila tras fila. Ademas el rol se
    -- deduce de las armas, y las armas ya estan pintadas en la propia fila
    -- justo debajo: era el dato menos informativo del sitio mas visible.
    --
    -- Sin categoria puesta se sigue pintando el rol, para no dejar el hueco
    -- mudo. El emergente dice SIEMPRE las dos cosas (categoria y rol), asi
    -- que no hay que adivinar cual de los dos se esta viendo, y el aviso de
    -- "duda" del rol -baston de hielo sin escudo, que no se puede decidir por
    -- el arma- no se pierde por el camino.
    local roleIcon = EZOArmory.Builds.GetRoleIcon(report.role)
    local rowIcon = EZOArmory.Builds.GetCategoryIcon(build.category) or roleIcon
    if rowIcon then
        row.roleIcon:SetTexture(rowIcon)
        row.roleIcon:SetHidden(false)
    else
        row.roleIcon:SetHidden(true)
    end

    local roleLabel = EZOArmory.Builds.GetRoleLabel(report.role)
    local roleTitle = report.roleForced and roleLabel
        or zo_strformat(GetString(EZOARM_BUILD_ROLE_AUTO), roleLabel)
    local iconLines = {
        zo_strformat(GetString(EZOARM_BUILD_ROW_ROLE_LINE), roleTitle),
    }
    row.roleIcon:SetHandler("OnMouseEnter", function(control)
        WK.ShowTextSummary(control,
            EZOArmory.Builds.GetCategoryLabel(build.category), iconLines)
    end)
    row.roleIcon:SetHandler("OnMouseExit", WK.HideTextSummary)

    -- Las filas se reciclan, asi que el desplegable se rellena de cero en
    -- cada refresco: si no, se quedaria mostrando la categoria de la build
    -- que ocupaba antes esta fila.
    local labels, values = CategoryChoices(true)
    PopulateCombo(row.categoryCombo, labels, values,
        build.category or EZOArmory.Builds.CATEGORY_NONE, function(value)
            SetCategoryAndRefresh(build.id, value, WB.RefreshList)
        end)

    -- Estado: icono (correcto / aviso / error) y, si hay algo que revisar, el
    -- numero al lado. Sin texto largo: ocupaba todo el ancho derecho.
    local issueCount = #report.issues
    row.statusIcon:SetTexture(STATUS_ICON[report.status] or STATUS_ICON.error)
    row.statusIcon:SetColor(StatusColor(report.status))
    row.statusLabel:SetText(issueCount == 0 and "" or tostring(issueCount))
    row.statusLabel:SetColor(StatusColor(report.status))

    local issueLines = {}
    for _, issue in ipairs(report.issues) do
        issueLines[#issueLines + 1] = IssueText(issue)
    end
    -- El mismo emergente en el icono y en el numero: el detalle no se pierde
    -- al quitar el texto, solo deja de ocupar sitio.
    local function ShowIssues(control)
        WK.ShowTextSummary(control, GetString(EZOARM_BUILD_SECTION_ISSUES),
            #issueLines > 0 and issueLines or { GetString(EZOARM_BUILD_ALL_GOOD) })
    end
    row.statusLabel:SetHandler("OnMouseEnter", ShowIssues)
    row.statusLabel:SetHandler("OnMouseExit", WK.HideTextSummary)
    row.statusIcon:SetHandler("OnMouseEnter", ShowIssues)
    row.statusIcon:SetHandler("OnMouseExit", WK.HideTextSummary)

    FillRowGear(row, report)
    FillRowSkillsAndCp(row, build)
end

-- --------------------------------------------------------- Lista ----

function WB.SelectBuild(buildId)
    WB.state.selectedId = buildId
    for _, row in ipairs(WB.rows or {}) do
        row.selectionBg:SetHidden(row.buildId ~= buildId or buildId == nil)
    end
    WB.RefreshActionBar()
end

-- Reparte las builds en grupos por categoria, en el orden declarado en
-- Builds.CATEGORIES (no el de la lista: asi los grupos salen siempre en el
-- mismo sitio) y con las no catalogadas al final. Devuelve solo los grupos que
-- pasan el filtro y que tienen algo dentro.
local function GroupBuilds(list, filter)
    local NONE = EZOArmory.Builds.CATEGORY_NONE
    local groups = {}

    local function Collect(categoryId)
        if filter ~= "all" and filter ~= categoryId then return end
        local builds = {}
        for _, build in ipairs(list) do
            local own = build.category or NONE
            if own == categoryId then
                builds[#builds + 1] = build
            end
        end
        if #builds > 0 then
            groups[#groups + 1] = { categoryId = categoryId, builds = builds }
        end
    end

    for _, entry in ipairs(EZOArmory.Builds.CATEGORIES) do
        Collect(entry.id)
    end
    Collect(NONE)

    return groups
end

function WB.RefreshList()
    if not WB.rows or not WB.listRoot then return end

    local list = EZOArmory.Builds.ListBuilds()
    local scrollbarWidth = (type(ZO_SCROLL_BAR_WIDTH) == "number" and ZO_SCROLL_BAR_WIDTH or 16) + 8
    local row1Width = WB.scrollContainer and WB.scrollContainer:GetWidth() or 0
    local yOffset = 0
    local stillSelected = false

    -- Ancho explicito, medido del contenedor externo. NO se ancla el lado
    -- derecho de la fila a ese contenedor: el ScrollChild se desplaza al hacer
    -- scroll y el contenedor no, asi que una fila anclada a ambos se deforma al
    -- desplazarse y el alto real del contenido sale mal (por eso el scroll no
    -- llegaba a la ultima fila). Tampoco se puede anclar al ScrollChild, que se
    -- autoajusta a sus hijos y crearia un ciclo.
    local rowWidth = (row1Width or 0) - scrollbarWidth
    if rowWidth <= 0 then
        rowWidth = nil
    end

    local groups = GroupBuilds(list, WB.state.filter or "all")
    -- Con un solo grupo la cabecera no aporta nada: o se ha filtrado por esa
    -- categoria, o todas las builds estan en ella.
    local showHeaders = #groups > 1
    local rowIndex, headerIndex = 0, 0
    local shown = 0

    for _, group in ipairs(groups) do
        if showHeaders and headerIndex < MAX_GROUP_HEADERS then
            headerIndex = headerIndex + 1
            local header = WB.groupHeaders[headerIndex]
            local icon = EZOArmory.Builds.GetCategoryIcon(group.categoryId)
            header:ClearAnchors()
            header:SetAnchor(TOPLEFT, WB.listRoot, TOPLEFT, 0, yOffset)
            if rowWidth then
                header:SetWidth(rowWidth)
            end
            header.icon:SetTexture(icon or "")
            header.icon:SetHidden(icon == nil)
            header.label:SetText(string.format("%s (%d)",
                EZOArmory.Builds.GetCategoryLabel(group.categoryId), #group.builds))
            header:SetHidden(false)
            yOffset = yOffset + GROUP_HEADER_H + GROUP_HEADER_GAP
        end

        for _, build in ipairs(group.builds) do
            if rowIndex >= MAX_BUILD_ROWS then break end
            rowIndex = rowIndex + 1
            local row = WB.rows[rowIndex]
            row.buildId = build.id
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, WB.listRoot, TOPLEFT, 0, yOffset)
            if rowWidth then
                row:SetWidth(rowWidth)
            end
            row:SetHidden(false)
            ClearBuildRow(row)
            FillBuildRow(row, build)

            row.selectionBg:SetHidden(build.id ~= WB.state.selectedId)
            if build.id == WB.state.selectedId then
                stillSelected = true
            end
            yOffset = yOffset + BUILD_ROW_HEIGHT + BUILD_ROW_SPACING
            shown = shown + 1
        end
    end

    for i = rowIndex + 1, MAX_BUILD_ROWS do
        WB.rows[i].buildId = nil
        WB.rows[i]:SetHidden(true)
    end
    for i = headerIndex + 1, MAX_GROUP_HEADERS do
        WB.groupHeaders[i]:SetHidden(true)
    end

    if not stillSelected then
        WB.state.selectedId = nil
    end

    -- El contador cuenta lo que se ve, no lo que hay: con un filtro puesto,
    -- decir el total confundiria mas que ayudar.
    if WB.countLabel then
        if #list == 0 then
            WB.countLabel:SetText(GetString(EZOARM_BUILD_NO_BUILDS))
        else
            WB.countLabel:SetText(zo_strformat(GetString(EZOARM_BUILD_COUNT), shown))
        end
    end

    -- Sin builds la lista queda vacia y no se ve por donde empezar, asi que el
    -- cartel explica que es una build y donde se le anaden los kits. Con builds
    -- ya creadas basta una linea recordando el atajo, salvo que sea el filtro
    -- el que las este escondiendo: eso hay que decirlo, o parece que se han
    -- perdido.
    if WB.emptyHint then
        local hint
        if #list == 0 then
            hint = GetString(EZOARM_BUILD_EMPTY_HINT)
        elseif shown == 0 then
            hint = GetString(EZOARM_BUILD_NONE_IN_FILTER)
        else
            hint = GetString(EZOARM_BUILD_EDIT_HINT)
        end
        WB.emptyHint:SetText(hint)
    end

    -- Sin SetHeight a mano: el ScrollChild se autoajusta a sus filas. Ver el
    -- comentario equivalente en window_kits.

    WB.RefreshActionBar()
end

-- --------------------------------------------------------- Editor ----

local function EditingBuild()
    return EZOArmory.Builds.GetBuild(WB.state.editingId)
end

local function PopulateRoleCombo(build, report)
    -- La primera opcion deja el rol en automatico y muestra cual se deduce.
    local detected = EZOArmory.Builds.DetectRole(report.assignment)
    local labels = {
        zo_strformat(GetString(EZOARM_BUILD_ROLE_AUTO), EZOArmory.Builds.GetRoleLabel(detected)),
        EZOArmory.Builds.GetRoleLabel(EZOArmory.Builds.ROLE_DD),
        EZOArmory.Builds.GetRoleLabel(EZOArmory.Builds.ROLE_TANK),
        EZOArmory.Builds.GetRoleLabel(EZOArmory.Builds.ROLE_HEALER),
    }
    local values = {
        "auto",
        EZOArmory.Builds.ROLE_DD,
        EZOArmory.Builds.ROLE_TANK,
        EZOArmory.Builds.ROLE_HEALER,
    }
    PopulateCombo(WB.roleCombo, labels, values, build.role or "auto", function(value)
        EZOArmory.Builds.SetRoleOverride(build.id, value ~= "auto" and value or nil)
        WB.RefreshEditor()
    end)
end

-- Categoria de la build: solo etiqueta, no cambia nada de lo que se equipa.
-- Sirve para agrupar y filtrar la lista cuando hay muchas builds.
local function PopulateCategoryCombo(build)
    local labels, values = CategoryChoices(true)
    PopulateCombo(WB.categoryCombo, labels, values,
        build.category or EZOArmory.Builds.CATEGORY_NONE, function(value)
            SetCategoryAndRefresh(build.id, value, WB.RefreshEditor)
        end)
end

local function RefreshEditorGearRows(build)
    for i, row in ipairs(WB.edGearRows) do
        local kitId = build.gearKitIds[i]
        local kit = kitId and EZOArmory.Kits.GetKit(kitId)
        if kit then
            row.nameLabel:SetText(string.format(
                "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit)))
            row:SetHidden(false)
            row.removeButton:SetHandler("OnClicked", function()
                EZOArmory.Builds.RemoveGearKit(build.id, kitId)
                WB.RefreshEditor()
            end)
        else
            row:SetHidden(true)
        end
    end
end

local function PopulateGearPickCombo(build)
    local labels, values = {}, {}
    for _, kit in ipairs(EZOArmory.Kits.ListKits()) do
        if not EZOArmory.Builds.HasGearKit(build, kit.id) then
            labels[#labels + 1] = string.format(
                "%s (%d)", tostring(kit.name), EZOArmory.Kits.CountPieces(kit))
            values[#values + 1] = kit.id
        end
    end
    -- El kit elegido puede haber dejado de estar disponible (se acaba de
    -- anadir a la build, o se borro): en ese caso se apunta al primero libre.
    local stillThere = false
    for _, id in ipairs(values) do
        if id == WB.state.pickGearKitId then
            stillThere = true
            break
        end
    end
    if not stillThere then
        WB.state.pickGearKitId = values[1]
    end
    PopulateCombo(WB.gearPickCombo, labels, values, WB.state.pickGearKitId, function(value)
        WB.state.pickGearKitId = value
    end)
end

local function PopulateSkillCombo(build)
    local labels, values = { GetString(EZOARM_BUILD_NONE_SELECTED) }, { "" }
    for _, kit in ipairs(EZOArmory.Skills.ListKits()) do
        labels[#labels + 1] = string.format(
            "%s (%d)", tostring(kit.name), EZOArmory.Skills.CountAbilities(kit))
        values[#values + 1] = kit.id
    end
    PopulateCombo(WB.skillCombo, labels, values, build.skillKitId or "", function(value)
        EZOArmory.Builds.SetSkillKit(build.id, value ~= "" and value or nil)
        WB.RefreshEditor()
    end)
end

local function PopulateCpCombo(build)
    local labels, values = { GetString(EZOARM_BUILD_NONE_SELECTED) }, { "" }
    for _, kit in ipairs(EZOArmory.Champion.ListKits()) do
        labels[#labels + 1] = string.format(
            "%s (%d)", tostring(kit.name), EZOArmory.Champion.CountStars(kit))
        values[#values + 1] = kit.id
    end
    PopulateCombo(WB.cpCombo, labels, values, build.cpKitId or "", function(value)
        EZOArmory.Builds.SetCpKit(build.id, value ~= "" and value or nil)
        WB.RefreshEditor()
    end)
end

local function RefreshIssueRows(report)
    for i, label in ipairs(WB.issueRows) do
        local issue = report.issues[i]
        if issue then
            label:SetText("- " .. IssueText(issue))
            label:SetColor(StatusColor(issue.severity == EZOArmory.Coherence.SEVERITY.ERROR
                and EZOArmory.Builds.STATUS_ERROR or EZOArmory.Builds.STATUS_WARNING))
            label:SetHidden(false)
        else
            label:SetHidden(true)
        end
    end
    -- Si hay mas incidencias que filas, la ultima avisa de cuantas faltan.
    local overflow = #report.issues - #WB.issueRows
    if overflow > 0 then
        local last = WB.issueRows[#WB.issueRows]
        last:SetText(string.format("- (+%d)", overflow + 1))
        last:SetHidden(false)
    end
    WB.issuesOkLabel:SetHidden(#report.issues > 0)
end

function WB.RefreshEditor()
    local build = EditingBuild()
    if not build then return end
    local report = EZOArmory.Builds.Analyze(build)

    WB.edNameLabel:SetText(zo_strformat(GetString(EZOARM_BUILD_EDITOR_TITLE), build.name))
    PopulateRoleCombo(build, report)
    PopulateCategoryCombo(build)
    RefreshEditorGearRows(build)
    PopulateGearPickCombo(build)
    PopulateSkillCombo(build)
    PopulateCpCombo(build)
    RefreshIssueRows(report)
end

-- --------------------------------------------------- Vistas y acciones ----

function WB.SetView(view)
    WB.state.view = view
    local isEditor = view == "editor"
    if WB.listPanel then WB.listPanel:SetHidden(isEditor) end
    if WB.editorPanel then WB.editorPanel:SetHidden(not isEditor) end
    if isEditor then
        WB.RefreshEditor()
    else
        WB.RefreshList()
    end
    WB.RefreshActionBar()
end

function WB.RefreshActionBar()
    if not WB.listActionBar then return end
    local isEditor = WB.state.view == "editor"
    WB.listActionBar:SetHidden(isEditor)
    WB.editorActionBar:SetHidden(not isEditor)

    local hasSelection = WB.state.selectedId ~= nil
    WB.editButton:SetHidden(not hasSelection)
    WB.deleteButton:SetHidden(not hasSelection)
    WB.equipButton:SetHidden(not hasSelection)
    if WB.updateWornButton then
        WB.updateWornButton:SetHidden(not hasSelection)
    end
end

-- Dialogo de nombre, mismo patron verificado que el renombrado de kits
-- (editBox en el registro, initialEditText al mostrar,
-- ZO_Dialogs_GetEditBoxText al confirmar).
local NAME_DIALOG = "EZOARMORY_BUILD_NAME"
local nameDialogRegistered = false
local pendingNameAction = nil

local function EnsureNameDialog()
    if nameDialogRegistered then return true end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return false end

    ZO_Dialogs_RegisterCustomDialog(NAME_DIALOG, {
        canQueue = true,
        title = { text = GetString(EZOARM_DIALOG_BUILD_NAME_TITLE) },
        mainText = { text = GetString(EZOARM_DIALOG_BUILD_NAME_TEXT) },
        editBox = {},
        buttons = {
            [1] = {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local input = ZO_Dialogs_GetEditBoxText(dialog)
                    if input and input ~= "" and pendingNameAction then
                        pendingNameAction(input)
                    end
                    pendingNameAction = nil
                end,
            },
            [2] = {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function() pendingNameAction = nil end,
            },
        },
    })
    nameDialogRegistered = true
    return true
end

local function AskForName(initialText, onConfirm)
    if not EnsureNameDialog() or type(ZO_Dialogs_ShowDialog) ~= "function" then return end
    pendingNameAction = onConfirm
    ZO_Dialogs_ShowDialog(NAME_DIALOG, nil, { initialEditText = tostring(initialText or "") })
end

-- Nombre automatico libre: "Build 1", "Build 2"...
local function AutoBuildName()
    local taken = {}
    for _, build in ipairs(EZOArmory.Builds.ListBuilds()) do
        taken[tostring(build.name)] = true
    end
    local base = GetString(EZOARM_BUILD_AUTONAME)
    local index = 1
    while taken[base .. " " .. index] do
        index = index + 1
    end
    return base .. " " .. index
end

local function OnNewClicked()
    AskForName(AutoBuildName(), function(name)
        local id = EZOArmory.Builds.CreateBuild(name)
        if not id then return end
        if EZOArmory.Print then
            EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_BUILD_CREATED), name))
        end
        WB.state.editingId = id
        WB.state.selectedId = id
        WB.SetView("editor")
    end)
end

-- Crea una build con todo lo que se lleva puesto, sin tener que preparar kits
-- antes: los crea (o reutiliza los que ya existan con el mismo contenido) y
-- compone la build de una vez. Es el atajo para memorizar la build que llevas
-- ahora mismo.
local function OnCopyWornClicked()
    AskForName(AutoBuildName(), function(name)
        local id, summary = EZOArmory.Builds.CreateFromCurrent(name)
        if not id then return end
        if EZOArmory.Print then
            EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_BUILD_FROM_WORN),
                name, summary.gearCreated, summary.gearReused))

            -- Si alguna parte no se ha podido capturar hay que DECIRLO. Antes
            -- solo se informaba del equipo, asi que una build que salia sin
            -- habilidades ni CP parecia correcta hasta que el analisis de
            -- coherencia la marcaba en rojo mucho despues.
            local missing = {}
            if not summary.skillKitId then
                missing[#missing + 1] = GetString(EZOARM_MSG_BUILD_PART_SKILLS)
            end
            if not summary.cpKitId then
                missing[#missing + 1] = GetString(EZOARM_MSG_BUILD_PART_CP)
            end
            if #missing > 0 then
                EZOArmory.Print(zo_strformat(
                    GetString(EZOARM_MSG_BUILD_FROM_WORN_MISSING), table.concat(missing, ", ")))
            end
        end
        WB.state.editingId = id
        WB.state.selectedId = id
        WB.SetView("list")
    end)
end

-- Actualiza la build seleccionada con lo que llevas puesto ahora. Pensado para
-- el retoque pequeno: mover una habilidad de sitio, cambiar una pieza. Los
-- kits que solo usa esta build se actualizan en su sitio; los compartidos no
-- se tocan y la build pasa a apuntar a otro (ver Builds.UpdateFromCurrent).
local function OnUpdateFromWornClicked()
    local build = EZOArmory.Builds.GetBuild(WB.state.selectedId)
    if not build then return end

    local summary = EZOArmory.Builds.UpdateFromCurrent(build.id)
    if not summary or not EZOArmory.Print then return end

    local changed = {}
    if summary.gear ~= "unchanged" then changed[#changed + 1] = GetString(EZOARM_MSG_BUILD_PART_GEAR) end
    if summary.skills ~= "unchanged" then changed[#changed + 1] = GetString(EZOARM_MSG_BUILD_PART_SKILLS) end
    if summary.cp ~= "unchanged" then changed[#changed + 1] = GetString(EZOARM_MSG_BUILD_PART_CP) end

    if #changed == 0 then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_BUILD_UPDATED_NOTHING), tostring(build.name)))
    else
        EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_BUILD_UPDATED),
            tostring(build.name), table.concat(changed, ", ")))
    end

    WB.RefreshList()
end

local function OnRenameClicked()
    local build = EditingBuild()
    if not build then return end
    AskForName(build.name, function(name)
        EZOArmory.Builds.RenameBuild(build.id, name)
        WB.RefreshEditor()
    end)
end

-- Abre el editor de la build seleccionada: la vista donde se le anaden kits.
-- Publica porque tambien la usa el doble clic sobre una fila.
function WB.EditSelected()
    if not WB.state.selectedId then return end
    WB.state.editingId = WB.state.selectedId
    WB.SetView("editor")
end

local function OnEditClicked()
    WB.EditSelected()
end

local function OnDeleteClicked()
    local build = EZOArmory.Builds.GetBuild(WB.state.selectedId)
    if not build then return end
    local name = tostring(build.name)
    EZOArmory.Builds.DeleteBuild(build.id)
    WB.state.selectedId = nil
    if EZOArmory.Print then
        EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_BUILD_DELETED), name))
    end
    WB.RefreshList()
end

local PART_STRING = {
    gear = "EZOARM_MSG_BUILD_PART_GEAR",
    skills = "EZOARM_MSG_BUILD_PART_SKILLS",
    cp = "EZOARM_MSG_BUILD_PART_CP",
}

-- Informe en chat de una parte del equipado de una build. Publica porque la
-- pestana Assign equipa las mismas builds y debe informar igual.
function WB.ReportEquipPart(part, state)
    if not EZOArmory.Print then return end
    local stringName = PART_STRING[part]
    local prefix = stringName and GetString(_G[stringName]) or ""

    if state.error == "noLibAsync" then
        EZOArmory.Print(prefix .. " " .. GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
        return
    end
    if state.error == "empty" then
        return
    end

    if part == "gear" then
        EZOArmory.Print(prefix .. " " .. zo_strformat(
            GetString(EZOARM_MSG_EQUIP_DONE), state.equipped, state.already, state.missing))
        if state.missing > 0 and state.missingNames and #state.missingNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_EQUIP_MISSING), table.concat(state.missingNames, ", ")))
        end
        if state.inBank and state.inBank > 0 and state.inBankNames and #state.inBankNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_EQUIP_IN_BANK), table.concat(state.inBankNames, ", ")))
        end
        if state.failed and state.failed > 0 and state.failedNames and #state.failedNames > 0 then
            EZOArmory.Print(zo_strformat(
                GetString(EZOARM_MSG_EQUIP_FAILED), table.concat(state.failedNames, ", ")))
        end
    else
        local doneString = (part == "skills") and EZOARM_MSG_SKILL_EQUIP_DONE or EZOARM_MSG_CP_EQUIP_DONE
        EZOArmory.Print(prefix .. " " .. zo_strformat(
            GetString(doneString), state.slotted, state.already, state.skipped))
    end
end

-- Equipado rapido: equipo, habilidades y CP de una vez. Se niega a equipar una
-- build incompleta, que es justo lo que la validacion existe para evitar.
local function OnEquipClicked()
    local build = EZOArmory.Builds.GetBuild(WB.state.selectedId)
    if not build then return end

    if not EZOArmory.Builds.Analyze(build).complete then
        if EZOArmory.Print then
            EZOArmory.Print(GetString(EZOARM_MSG_BUILD_INCOMPLETE))
        end
        return
    end

    EZOArmory.Builds.Equip(build.id, WB.ReportEquipPart)
end

-- ------------------------------------------------------------ Desvestir ----

local UNDRESS_DIALOG = "EZOARMORY_UNDRESS"
local undressDialogRegistered = false

function WB.ReportUndress(state)
    if not EZOArmory.Print then return end

    if state.error == "empty" then
        EZOArmory.Print(GetString(EZOARM_MSG_UNDRESS_EMPTY))
        return
    end
    if state.error == "noSpace" then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_UNDRESS_NO_SPACE), state.needed, state.free))
        return
    end
    if state.error then
        EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_NO_LIBASYNC))
        return
    end

    EZOArmory.Print(zo_strformat(GetString(EZOARM_MSG_UNDRESS_DONE), state.removed))
    if state.failed > 0 then
        local names = {}
        for _, key in ipairs(state.failedKeys) do
            names[#names + 1] = EZOArmory.SlotLabel(key)
        end
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_UNDRESS_FAILED), table.concat(names, ", ")))
    end
end

-- Se confirma antes. Quitarse catorce piezas se deshace equipando cualquier
-- build, asi que grave no es, pero es un boton pequeno y sin texto al lado de
-- otros seis: un resbalon del raton no deberia dejarte desnudo en mitad de
-- una trial sin haber dicho nada.
local function EnsureUndressDialog()
    if undressDialogRegistered then return true end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return false end

    ZO_Dialogs_RegisterCustomDialog(UNDRESS_DIALOG, {
        canQueue = true,
        title = { text = GetString(EZOARM_DIALOG_UNDRESS_TITLE) },
        mainText = { text = GetString(EZOARM_DIALOG_UNDRESS_TEXT) },
        buttons = {
            [1] = {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function()
                    if EZOArmory.DebugLog then
                        EZOArmory.DebugLog("Undress: confirmed")
                    end
                    EZOArmory.Equip.UndressAll(WB.ReportUndress)
                end,
            },
            [2] = {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
        },
    })
    undressDialogRegistered = true
    return true
end

local function OnUndressClicked()
    if EZOArmory.DebugLog then EZOArmory.DebugLog("Undress: button clicked") end

    -- Sin dialogos disponibles no se hace a la brava: mejor no hacer nada que
    -- desvestir sin preguntar. Pero SE DICE: una rama que se va en silencio es
    -- indistinguible desde fuera de un boton que no llama a nada, y esa
    -- confusion ya ha costado varias versiones en este addon.
    if not EnsureUndressDialog() or type(ZO_Dialogs_ShowDialog) ~= "function" then
        if EZOArmory.Print then
            EZOArmory.Print(GetString(EZOARM_MSG_UNDRESS_NO_DIALOG))
        end
        return
    end
    ZO_Dialogs_ShowDialog(UNDRESS_DIALOG)
end

-- ---------------------------------------------------------- Construccion ----

-- "half" parte la fila en dos para meter dos combos cortos donde antes iba
-- uno: el punto TOP del padre es el centro de su borde superior, asi que sirve
-- de mitad sin tener que calcular anchos (que ademas cambian con la ventana).
local function CreateComboRow(parent, name, labelStringId, y, half)
    local label = WM:CreateControl(nil, parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(0.75, 0.75, 0.8, 1)
    label:SetDimensions(half and (ED_LABEL_WIDTH - 30) or ED_LABEL_WIDTH, ED_ROW_HEIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(GetString(labelStringId))

    local combo = WM:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    combo:SetHeight(ED_ROW_HEIGHT)
    combo:SetAnchor(TOPLEFT, label, TOPRIGHT, 8, 0)

    if half == "left" then
        label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
        combo:SetAnchor(TOPRIGHT, parent, TOP, -12, y)
    elseif half == "right" then
        label:SetAnchor(TOPLEFT, parent, TOP, 12, y)
        combo:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
    else
        label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
        combo:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
    end
    return combo
end

local function CreateActionButton(parent, width, text, normalColor, overColor, handler)
    local button = WM:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 24)
    button:SetFont("ZoFontGameBold")
    button:SetNormalFontColor(normalColor[1], normalColor[2], normalColor[3], 1)
    button:SetMouseOverFontColor(overColor[1], overColor[2], overColor[3], 1)
    button:SetText(text)
    button:SetHandler("OnClicked", handler)
    return button
end

-- Opciones del filtro: todas, cada categoria, y las sin catalogar al final
-- (mismo orden que los grupos de la lista, para no tener dos ordenes
-- distintos de las mismas categorias).
local function PopulateFilterCombo()
    if not WB.filterCombo then return end
    local labels, values = CategoryChoices(false)
    table.insert(labels, 1, GetString(EZOARM_FILTER_ALL))
    table.insert(values, 1, "all")

    PopulateCombo(WB.filterCombo, labels, values, WB.state.filter or "all", function(value)
        WB.state.filter = value
        -- Mismo motivo que en SetCategoryAndRefresh: no se repinta la lista
        -- desde dentro del callback del combo que la esta despachando.
        zo_callLater(WB.RefreshList, 0)
    end)
end

local function CreateListPanel(content)
    local panel = WM:CreateControl(nil, content, CT_CONTROL)
    panel:SetAnchorFill(content)
    WB.listPanel = panel

    -- Filtro por categoria, arriba a la derecha. Va aqui y no en el editor
    -- porque es estado de la vista, no de ninguna build: se recuerda mientras
    -- dure la sesion y no se guarda.
    local filterCombo = WM:CreateControlFromVirtual(
        "EZOArmoryBuildFilterCombo", panel, "ZO_ComboBox")
    filterCombo:SetDimensions(190, 24)
    filterCombo:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, -2)
    WB.filterCombo = filterCombo

    local countLabel = WM:CreateControl(nil, panel, CT_LABEL)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(0.7, 0.7, 0.75, 1)
    countLabel:SetHeight(24)
    countLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    countLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    countLabel:SetAnchor(TOPRIGHT, filterCombo, TOPLEFT, -12, 0)
    WB.countLabel = countLabel

    local actionBar = WM:CreateControl(nil, panel, CT_CONTROL)
    actionBar:SetDimensions(1, 26)
    actionBar:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)
    actionBar:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
    WB.listActionBar = actionBar

    -- Seis botones en una sola fila: hay que contar el ancho, no ponerlo a ojo.
    -- El area util es el ancho de la ventana menos la columna de pestanas (150)
    -- y los margenes del cuerpo (~24): unos 726 px con la ventana por defecto
    -- (900). Con los anchos anteriores los seis sumaban 810 mas 60 de
    -- separaciones = 870, y por eso "Update worn" y "Equip" se montaban uno
    -- encima del otro. Ahora suman 610 + 60 = 670, con margen de sobra.
    --
    -- Los textos van cortos a proposito por lo mismo (misma leccion que en
    -- 0.9.3): estamos en la pestana Builds, repetir "build" en cada boton solo
    -- gasta ancho.
    local BTN_GAP = 12

    local deleteButton = CreateActionButton(actionBar, 95, GetString(EZOARM_BUILD_DELETE),
        { 1, 0.55, 0.55 }, { 1, 0.3, 0.3 }, OnDeleteClicked)
    deleteButton:SetAnchor(BOTTOMRIGHT, actionBar, BOTTOMRIGHT, 0, 0)
    deleteButton:SetHidden(true)
    WB.deleteButton = deleteButton

    local editButton = CreateActionButton(actionBar, 90, GetString(EZOARM_BUILD_EDIT),
        { 0.8, 0.85, 1 }, { 0.6, 0.75, 1 }, OnEditClicked)
    editButton:SetAnchor(RIGHT, deleteButton, LEFT, -BTN_GAP, 0)
    editButton:SetHidden(true)
    WB.editButton = editButton

    local equipButton = CreateActionButton(actionBar, 95, GetString(EZOARM_BUILD_EQUIP),
        { 0.6, 1, 0.6 }, { 0.4, 1, 0.4 }, OnEquipClicked)
    equipButton:SetAnchor(RIGHT, editButton, LEFT, -BTN_GAP, 0)
    equipButton:SetHidden(true)
    WB.equipButton = equipButton

    local newButton = CreateActionButton(actionBar, 90, GetString(EZOARM_BUILD_NEW),
        { 0.85, 0.85, 0.9 }, { 1, 1, 1 }, OnNewClicked)
    newButton:SetAnchor(BOTTOMLEFT, actionBar, BOTTOMLEFT, 0, 0)

    local copyWornButton = CreateActionButton(actionBar, 120, GetString(EZOARM_BUILD_FROM_WORN),
        { 0.6, 1, 0.6 }, { 0.4, 1, 0.4 }, OnCopyWornClicked)
    copyWornButton:SetAnchor(LEFT, newButton, RIGHT, BTN_GAP, 0)

    -- Solo tiene sentido con una build elegida, asi que se oculta igual que
    -- Equip/Edit hasta que haya seleccion.
    local updateWornButton = CreateActionButton(actionBar, 120, GetString(EZOARM_BUILD_UPDATE_FROM_WORN),
        { 1, 0.85, 0.45 }, { 1, 0.7, 0.2 }, OnUpdateFromWornClicked)
    updateWornButton:SetAnchor(LEFT, copyWornButton, RIGHT, BTN_GAP, 0)
    updateWornButton:SetHidden(true)
    WB.updateWornButton = updateWornButton

    -- Desvestir, en el hueco entre los tres botones de la izquierda (354 px
    -- con sus separaciones) y los tres de la derecha (304): de los ~726
    -- utiles quedan unos 68 libres, asi que entra un boton de icono pero no
    -- uno con texto.
    --
    -- Encadenado al ultimo de la izquierda, NO centrado en la barra: el
    -- centro de la barra cae en 363 y la fila izquierda termina en 354, asi
    -- que centrarlo lo dejaria montado encima de "Update worn". Misma
    -- leccion que en 0.11.44, cuando "Update worn" y "Equip" se pisaron por
    -- meter un boton mas sin hacer la cuenta.
    --
    -- No depende de que haya build elegida, asi que no se oculta con la
    -- seleccion como hacen Equip, Edit y Borrar. Se ancla igualmente al boton
    -- de actualizar, que si se oculta: un control oculto conserva su sitio,
    -- asi que la posicion no baila al seleccionar y deseleccionar.
    --
    -- Icono NATIVO: es el que usa el propio juego para "vaciar este slot" en
    -- la pantalla de estilo (tabla OUTFIT_SLOT_CLEAR_TEXTURES en
    -- esoui/ingame/restyle/restyle_shared.lua). ESO no tiene ningun icono de
    -- "desvestir", y este es el que mas se le parece de los que el jugador ya
    -- ha visto en el juego.
    local undressButton = WM:CreateControl(nil, actionBar, CT_BUTTON)
    undressButton:SetDimensions(UNDRESS_BUTTON_SIZE, UNDRESS_BUTTON_SIZE)
    undressButton:SetAnchor(LEFT, updateWornButton, RIGHT, BTN_GAP, 0)
    undressButton:SetNormalTexture("EsoUI/Art/Restyle/gearSlot_chest_remove.dds")
    undressButton:SetMouseOverTexture("EsoUI/Art/Restyle/gearSlot_chest_remove.dds")
    undressButton:SetHandler("OnClicked", OnUndressClicked)
    undressButton:SetHandler("OnMouseEnter", function(control)
        control:SetAlpha(1)
        EZOArmory.WindowKits.ShowTextSummary(control, GetString(EZOARM_UNDRESS),
            { GetString(EZOARM_UNDRESS_TOOLTIP) })
    end)
    undressButton:SetHandler("OnMouseExit", function(control)
        control:SetAlpha(UNDRESS_BUTTON_IDLE_ALPHA)
        EZOArmory.WindowKits.HideTextSummary()
    end)
    -- Apagado en reposo: es la unica accion de la barra que no construye ni
    -- equipa nada, y no tiene que pedir la vista tanto como las demas.
    undressButton:SetAlpha(UNDRESS_BUTTON_IDLE_ALPHA)

    -- Cartel de ayuda entre el contador y la lista. Su alto cambia con el
    -- texto y la lista se ancla debajo, asi que la cadena de anclas absorbe
    -- sola la diferencia entre el texto largo (sin builds) y el corto.
    local emptyHint = WM:CreateControl(nil, panel, CT_LABEL)
    emptyHint:SetFont("ZoFontGame")
    emptyHint:SetColor(0.7, 0.7, 0.78, 1)
    emptyHint:SetVerticalAlignment(TEXT_ALIGN_TOP)
    emptyHint:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 0, 8)
    emptyHint:SetAnchor(TOPRIGHT, countLabel, BOTTOMRIGHT, 0, 8)
    WB.emptyHint = emptyHint

    local scrollContainer = WM:CreateControlFromVirtual(
        "EZOArmoryBuildScroll", panel, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, emptyHint, BOTTOMLEFT, 0, 10)
    scrollContainer:SetAnchor(BOTTOMRIGHT, actionBar, TOPRIGHT, 0, -8)

    local listRoot = scrollContainer:GetNamedChild("ScrollChild")
    listRoot:SetResizeToFitPadding(0, 20)
    WB.listRoot = listRoot
    WB.scrollContainer = scrollContainer
    -- Mismo motivo que en window_kits.lua: el area de rueda de raton del
    -- ZO_ScrollContainer se auto-habilita al desbordar contenido y cubre toda
    -- la lista por delante de las filas. Aqui no se habia notado con pocas
    -- builds, pero es el mismo control de ZOS y le pasaria lo mismo con mas.
    EZOArmory.DisableScrollWheelArea(scrollContainer)

    -- Las cabeceras se crean antes que las filas para que queden por detras
    -- en el orden de dibujo; ninguna tiene el raton activado, asi que no se
    -- pisan los emergentes de los iconos (ver el aviso de CreateBuildRow).
    WB.groupHeaders = {}
    for i = 1, MAX_GROUP_HEADERS do
        WB.groupHeaders[i] = CreateGroupHeader(listRoot, i)
    end

    WB.rows = {}
    for i = 1, MAX_BUILD_ROWS do
        WB.rows[i] = CreateBuildRow(listRoot, i)
    end

    PopulateFilterCombo()
end

local function CreateEditorPanel(content)
    local panel = WM:CreateControl(nil, content, CT_CONTROL)
    panel:SetAnchorFill(content)
    panel:SetHidden(true)
    WB.editorPanel = panel

    local nameLabel = WM:CreateControl(nil, panel, CT_LABEL)
    nameLabel:SetFont("ZoFontGameLargeBold")
    nameLabel:SetColor(0.92, 0.92, 0.95, 1)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nameLabel:SetHeight(28)
    nameLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    WB.edNameLabel = nameLabel

    local renameButton = CreateActionButton(panel, 120, GetString(EZOARM_WINDOW_BTN_RENAME),
        { 0.8, 0.85, 1 }, { 0.6, 0.75, 1 }, OnRenameClicked)
    renameButton:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    nameLabel:SetAnchor(TOPRIGHT, renameButton, TOPLEFT, -12, 0)

    -- Rol y categoria comparten fila. El editor se monta con desplazamientos
    -- verticales FIJOS (ver cabecera del archivo), asi que anadir una fila
    -- entera empujaria la lista de incidencias fuera del panel; ademas son dos
    -- etiquetas cortas y sobra ancho.
    local roleY = 36
    WB.roleCombo = CreateComboRow(
        panel, "EZOArmoryBuildRoleCombo", EZOARM_BUILD_SECTION_ROLE, roleY, "left")
    WB.categoryCombo = CreateComboRow(
        panel, "EZOArmoryBuildCategoryCombo", EZOARM_BUILD_CATEGORY, roleY, "right")

    local gearHeaderY = roleY + ED_ROW_HEIGHT + 12
    local gearHeader = WM:CreateControl(nil, panel, CT_LABEL)
    gearHeader:SetFont("ZoFontGameBold")
    gearHeader:SetColor(0.85, 0.85, 0.9, 1)
    gearHeader:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, gearHeaderY)
    gearHeader:SetText(GetString(EZOARM_BUILD_SECTION_GEAR))

    local gearListY = gearHeaderY + 20
    WB.edGearRows = {}
    for i = 1, MAX_ED_GEAR_ROWS do
        local rowY = gearListY + (i - 1) * (ED_LIST_ROW_HEIGHT + ED_LIST_ROW_GAP)
        local row = WM:CreateControl(nil, panel, CT_CONTROL)
        row:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, rowY)
        row:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, rowY)
        row:SetHeight(ED_LIST_ROW_HEIGHT)
        row:SetHidden(true)

        local removeButton = CreateActionButton(row, 18, "x",
            { 1, 0.55, 0.55 }, { 1, 0.3, 0.3 }, nil)
        removeButton:SetHeight(ED_LIST_ROW_HEIGHT)
        removeButton:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
        row.removeButton = removeButton

        local rowName = WM:CreateControl(nil, row, CT_LABEL)
        rowName:SetFont("ZoFontGame")
        rowName:SetColor(0.9, 0.9, 0.92, 1)
        rowName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        rowName:SetHeight(ED_LIST_ROW_HEIGHT)
        rowName:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        rowName:SetAnchor(TOPRIGHT, removeButton, TOPLEFT, -6, 0)
        row.nameLabel = rowName

        WB.edGearRows[i] = row
    end

    local pickY = gearListY + MAX_ED_GEAR_ROWS * (ED_LIST_ROW_HEIGHT + ED_LIST_ROW_GAP) + 4
    WB.gearPickCombo = CreateComboRow(
        panel, "EZOArmoryBuildGearPickCombo", EZOARM_OPTION_ASSIGN_PICK, pickY)

    local addButton = CreateActionButton(panel, 180, GetString(EZOARM_BUILD_ADD_GEAR_KIT),
        { 0.6, 1, 0.6 }, { 0.4, 1, 0.4 }, function()
            local build = EditingBuild()
            if not build or not WB.state.pickGearKitId then return end
            EZOArmory.Builds.AddGearKit(build.id, WB.state.pickGearKitId)
            WB.RefreshEditor()
        end)
    addButton:SetAnchor(TOPLEFT, panel, TOPLEFT, ED_LABEL_WIDTH + 8, pickY + ED_ROW_HEIGHT + 6)

    local skillY = pickY + ED_ROW_HEIGHT + 6 + 30
    WB.skillCombo = CreateComboRow(
        panel, "EZOArmoryBuildSkillCombo", EZOARM_BUILD_SECTION_SKILLS, skillY)

    local cpY = skillY + ED_ROW_HEIGHT + ED_ROW_GAP
    WB.cpCombo = CreateComboRow(panel, "EZOArmoryBuildCpCombo", EZOARM_BUILD_SECTION_CP, cpY)

    local issuesHeaderY = cpY + ED_ROW_HEIGHT + 12
    local issuesHeader = WM:CreateControl(nil, panel, CT_LABEL)
    issuesHeader:SetFont("ZoFontGameBold")
    issuesHeader:SetColor(0.85, 0.85, 0.9, 1)
    issuesHeader:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, issuesHeaderY)
    issuesHeader:SetText(GetString(EZOARM_BUILD_SECTION_ISSUES))

    local issuesListY = issuesHeaderY + 20
    WB.issueRows = {}
    for i = 1, MAX_ISSUE_ROWS do
        local rowY = issuesListY + (i - 1) * ED_LIST_ROW_HEIGHT
        local label = WM:CreateControl(nil, panel, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetHeight(ED_LIST_ROW_HEIGHT)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, rowY)
        label:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, rowY)
        label:SetHidden(true)
        WB.issueRows[i] = label
    end

    local okLabel = WM:CreateControl(nil, panel, CT_LABEL)
    okLabel:SetFont("ZoFontGameSmall")
    okLabel:SetColor(StatusColor(EZOArmory.Builds.STATUS_OK))
    okLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, issuesListY)
    okLabel:SetText(GetString(EZOARM_BUILD_ALL_GOOD))
    WB.issuesOkLabel = okLabel

    local actionBar = WM:CreateControl(nil, panel, CT_CONTROL)
    actionBar:SetDimensions(1, 26)
    actionBar:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)
    actionBar:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
    WB.editorActionBar = actionBar

    local backButton = CreateActionButton(actionBar, 160, GetString(EZOARM_BUILD_BACK),
        { 0.85, 0.85, 0.9 }, { 1, 1, 1 }, function() WB.SetView("list") end)
    backButton:SetAnchor(BOTTOMLEFT, actionBar, BOTTOMLEFT, 0, 0)
end

-- Construye la pestana completa dentro de "content" y la devuelve.
function WB.Create(content)
    if WB.root then return WB.root end

    local root = WM:CreateControl(nil, content, CT_CONTROL)
    root:SetAnchorFill(content)
    root:SetHidden(true)
    WB.root = root

    CreateListPanel(root)
    CreateEditorPanel(root)

    WB.SetView("list")
    return root
end

-- Refresco al entrar en la pestana.
function WB.Refresh()
    if WB.state.view == "editor" and EditingBuild() then
        WB.RefreshEditor()
    else
        WB.SetView("list")
    end
end
