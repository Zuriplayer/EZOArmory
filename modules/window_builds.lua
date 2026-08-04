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

WB.state = WB.state or {
    view = "list",     -- "list" | "editor"
    selectedId = nil,
    editingId = nil,
    pickGearKitId = nil,
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
    name:SetColor(0.92, 0.92, 0.95, 1)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetHeight(BUILD_ROW_HEADER_H)
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    name:SetAnchor(TOPLEFT, roleIcon, TOPRIGHT, 8, 0)
    name:SetMouseEnabled(true)
    row.nameLabel = name

    -- Estado (correcto / avisos / errores), alineado a la derecha.
    local status = WM:CreateControl(nil, row, CT_LABEL)
    status:SetFont("ZoFontGameSmall")
    status:SetHeight(BUILD_ROW_HEADER_H)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    status:SetAnchor(TOPRIGHT, row, TOPRIGHT, -6, 0)
    status:SetMouseEnabled(true)
    row.statusLabel = status
    name:SetAnchor(TOPRIGHT, status, TOPLEFT, -8, 0)

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
        cpLabel:SetAnchor(RIGHT, row, RIGHT, -6, 0)

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

    local roleIcon = EZOArmory.Builds.GetRoleIcon(report.role)
    if roleIcon then
        row.roleIcon:SetTexture(roleIcon)
        row.roleIcon:SetHidden(false)
    else
        row.roleIcon:SetHidden(true)
    end

    -- El rol se explica al pasar el raton: si es automatico o forzado, y por
    -- que "duda" cuando no se puede deducir del arma.
    local roleLabel = EZOArmory.Builds.GetRoleLabel(report.role)
    local roleTitle = report.roleForced and roleLabel
        or zo_strformat(GetString(EZOARM_BUILD_ROLE_AUTO), roleLabel)
    row.roleIcon:SetHandler("OnMouseEnter", function(control)
        WK.ShowTextSummary(control, roleTitle, nil)
    end)
    row.roleIcon:SetHandler("OnMouseExit", WK.HideTextSummary)

    -- Estado: correcto, o el numero de cosas a revisar, en su color.
    local issueCount = #report.issues
    if issueCount == 0 then
        row.statusLabel:SetText(GetString(EZOARM_BUILD_ALL_GOOD))
    else
        row.statusLabel:SetText(tostring(issueCount))
    end
    row.statusLabel:SetColor(StatusColor(report.status))

    local issueLines = {}
    for _, issue in ipairs(report.issues) do
        issueLines[#issueLines + 1] = IssueText(issue)
    end
    row.statusLabel:SetHandler("OnMouseEnter", function(control)
        WK.ShowTextSummary(control, GetString(EZOARM_BUILD_SECTION_ISSUES),
            #issueLines > 0 and issueLines or { GetString(EZOARM_BUILD_ALL_GOOD) })
    end)
    row.statusLabel:SetHandler("OnMouseExit", WK.HideTextSummary)

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

    for index, row in ipairs(WB.rows) do
        local build = list[index]
        if build then
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
        else
            row.buildId = nil
            row:SetHidden(true)
        end
    end

    if not stillSelected then
        WB.state.selectedId = nil
    end

    if WB.countLabel then
        if #list == 0 then
            WB.countLabel:SetText(GetString(EZOARM_BUILD_NO_BUILDS))
        else
            WB.countLabel:SetText(zo_strformat(GetString(EZOARM_BUILD_COUNT), #list))
        end
    end

    -- Sin builds la lista queda vacia y no se ve por donde empezar, asi que el
    -- cartel explica que es una build y donde se le anaden los kits. Con builds
    -- ya creadas basta una linea recordando el atajo.
    if WB.emptyHint then
        WB.emptyHint:SetText(#list == 0
            and GetString(EZOARM_BUILD_EMPTY_HINT)
            or GetString(EZOARM_BUILD_EDIT_HINT))
    end

    -- Sin SetHeight a mano: el ScrollChild se autoajusta a sus filas. Ver el
    -- comentario equivalente en window_kits.

    WB.RefreshActionBar()
end

-- --------------------------------------------------------- Editor ----

-- Igual que en la pestana Assign: combos nativos creados en runtime con
-- CreateControlFromVirtual + ZO_ComboBox_ObjectFromContainer.
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
        end
        WB.state.editingId = id
        WB.state.selectedId = id
        WB.SetView("list")
    end)
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

-- ---------------------------------------------------------- Construccion ----

local function CreateComboRow(parent, name, labelStringId, y)
    local label = WM:CreateControl(nil, parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(0.75, 0.75, 0.8, 1)
    label:SetDimensions(ED_LABEL_WIDTH, ED_ROW_HEIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, y)
    label:SetText(GetString(labelStringId))

    local combo = WM:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    combo:SetHeight(ED_ROW_HEIGHT)
    combo:SetAnchor(TOPLEFT, label, TOPRIGHT, 8, 0)
    combo:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, y)
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

local function CreateListPanel(content)
    local panel = WM:CreateControl(nil, content, CT_CONTROL)
    panel:SetAnchorFill(content)
    WB.listPanel = panel

    local countLabel = WM:CreateControl(nil, panel, CT_LABEL)
    countLabel:SetFont("ZoFontGameSmall")
    countLabel:SetColor(0.7, 0.7, 0.75, 1)
    countLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    countLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, 0, 0)
    WB.countLabel = countLabel

    local actionBar = WM:CreateControl(nil, panel, CT_CONTROL)
    actionBar:SetDimensions(1, 26)
    actionBar:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, 0)
    actionBar:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, 0)
    WB.listActionBar = actionBar

    -- Grupo izquierdo (crear) y derecho (acciones sobre la build seleccionada)
    -- dimensionados para caber a la vez: con los anchos anteriores se solapaban
    -- en cuanto habia una build seleccionada.
    local deleteButton = CreateActionButton(actionBar, 120, GetString(EZOARM_BUILD_DELETE),
        { 1, 0.55, 0.55 }, { 1, 0.3, 0.3 }, OnDeleteClicked)
    deleteButton:SetAnchor(BOTTOMRIGHT, actionBar, BOTTOMRIGHT, 0, 0)
    deleteButton:SetHidden(true)
    WB.deleteButton = deleteButton

    local editButton = CreateActionButton(actionBar, 110, GetString(EZOARM_BUILD_EDIT),
        { 0.8, 0.85, 1 }, { 0.6, 0.75, 1 }, OnEditClicked)
    editButton:SetAnchor(RIGHT, deleteButton, LEFT, -12, 0)
    editButton:SetHidden(true)
    WB.editButton = editButton

    local equipButton = CreateActionButton(actionBar, 120, GetString(EZOARM_BUILD_EQUIP),
        { 0.6, 1, 0.6 }, { 0.4, 1, 0.4 }, OnEquipClicked)
    equipButton:SetAnchor(RIGHT, editButton, LEFT, -12, 0)
    equipButton:SetHidden(true)
    WB.equipButton = equipButton

    local newButton = CreateActionButton(actionBar, 110, GetString(EZOARM_BUILD_NEW),
        { 0.85, 0.85, 0.9 }, { 1, 1, 1 }, OnNewClicked)
    newButton:SetAnchor(BOTTOMLEFT, actionBar, BOTTOMLEFT, 0, 0)

    local copyWornButton = CreateActionButton(actionBar, 170, GetString(EZOARM_BUILD_FROM_WORN),
        { 0.6, 1, 0.6 }, { 0.4, 1, 0.4 }, OnCopyWornClicked)
    copyWornButton:SetAnchor(LEFT, newButton, RIGHT, 12, 0)

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

    WB.rows = {}
    for i = 1, MAX_BUILD_ROWS do
        WB.rows[i] = CreateBuildRow(listRoot, i)
    end
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

    local roleY = 36
    WB.roleCombo = CreateComboRow(panel, "EZOArmoryBuildRoleCombo", EZOARM_BUILD_SECTION_ROLE, roleY)

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
