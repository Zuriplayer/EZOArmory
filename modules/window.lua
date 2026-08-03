-- Ventana propia de EZOArmory: marco, cabecera, movimiento y visibilidad.
--
-- Esqueleto de la Fase 3. El contenido (listas de kits, rejilla de 12 slots,
-- pestanas por objetivo, tooltips) se monta encima de esta base.
--
-- APIs de ESO usadas (patron verificado en la familia EZO, EZOChat):
--   WINDOW_MANAGER:CreateTopLevelWindow / CreateControl (CT_BACKDROP, CT_LABEL,
--   CT_BUTTON), SetAnchor/SetDimensions/SetHidden/SetMovable/StartMoving,
--   SetClampedToScreen, SCENE_MANAGER (IsShowing, RegisterCallback,
--   SetInUIMode), ZO_Tooltips_ShowTextTooltip/HideTextTooltip, PlaySound.
--
-- Reglas de la familia aplicadas:
--   - Visible solo en las escenas hud / hudui (whitelist de HUD).
--   - No se registra en family.layout: ese servicio es para superficies de HUD
--     de posicion libre con modo mover, no para ventanas de gestion.
--   - El keybind se declara en Bindings.xml propio; no se tocan las teclas del
--     jugador, que asigna la suya en Controles.

EZOArmory = EZOArmory or {}
EZOArmory.Window = EZOArmory.Window or {}

local Window = EZOArmory.Window
local WM = WINDOW_MANAGER

local WINDOW_NAME = "EZOArmoryWindow"
local DEFAULT_WIDTH = 900
local DEFAULT_HEIGHT = 600
local MIN_WIDTH = 640
local MIN_HEIGHT = 420
local HEADER_HEIGHT = 34
local CLOSE_SIZE = 26
local TITLE_PURPLE = "B040FF"

local function IsHudScene()
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then
        return true
    end
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

local function SavedWindow()
    local sv = EZOArmory.sv
    if not sv then return nil end
    sv.window = sv.window or {}
    return sv.window
end

function Window.SavePosition()
    local saved = SavedWindow()
    if not saved or not Window.control then return end
    saved.x = Window.control:GetLeft()
    saved.y = Window.control:GetTop()
end

-- Vuelve a centrar la ventana y su tamano por defecto, en vivo (sin esperar a
-- un reload). Lo usa "Restaurar valores por defecto" del panel de opciones.
function Window.ResetPosition()
    local saved = SavedWindow()
    if saved then
        saved.x = nil
        saved.y = nil
    end
    if not Window.control then return end
    Window.control:ClearAnchors()
    Window.control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    Window.control:SetDimensions(DEFAULT_WIDTH, DEFAULT_HEIGHT)
end

-- Aplica la visibilidad efectiva: solo se ve si el jugador la ha abierto y
-- ademas estamos en una escena permitida.
function Window.RefreshVisibility()
    if not Window.control then return end
    local shouldShow = Window.requestedVisible == true and IsHudScene()
    Window.control:SetHidden(not shouldShow)
end

local function CreateHeader(parent)
    local header = WM:CreateControl(nil, parent, CT_BACKDROP)
    header:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetEdgeTexture(nil, 1, 1, 1, 0)
    header:SetCenterColor(0.09, 0.05, 0.13, 0.95)

    local title = WM:CreateControl(nil, header, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(1, 1, 1, 1)
    title:SetText("E|c" .. TITLE_PURPLE .. "Z|rOArmory")
    title:SetAnchor(LEFT, header, LEFT, 12, 0)

    -- Contexto en vivo: en que trial/boss estas. Confirma que la ventana esta
    -- conectada al seguimiento de contexto.
    local context = WM:CreateControl(nil, header, CT_LABEL)
    context:SetFont("ZoFontGameSmall")
    context:SetColor(0.75, 0.75, 0.8, 1)
    context:SetAnchor(LEFT, title, RIGHT, 16, 0)
    Window.contextLabel = context

    local close = WM:CreateControl(nil, header, CT_BUTTON)
    close:SetDimensions(CLOSE_SIZE, CLOSE_SIZE)
    close:SetAnchor(RIGHT, header, RIGHT, -8, 0)
    close:SetFont("ZoFontGameBold")
    close:SetNormalFontColor(1, 1, 1, 1)
    close:SetMouseOverFontColor(1, 0.7, 0.7, 1)
    close:SetPressedFontColor(1, 0.4, 0.4, 1)
    close:SetText("X")
    close:SetHandler("OnClicked", function() Window.Hide() end)

    return header
end

-- Texto de contexto: trial y boss actuales, o fuera de trial.
function Window.RefreshContext()
    if not Window.contextLabel then return end
    local text = GetString(EZOARM_WINDOW_CONTEXT_NONE)

    local Context = EZOArmory.Context
    if Context and Context.GetState then
        local state = Context.GetState()
        if state.trial then
            local target
            if state.matchedBoss then
                target = state.matchedBoss.name
            elseif state.bossActive then
                target = state.primaryBoss or GetString(EZOARM_TARGET_TRASH)
            else
                target = GetString(EZOARM_TARGET_TRASH)
            end
            text = string.format("%s - %s", state.trial.name, tostring(target))
        elseif state.bossActive then
            text = tostring(state.primaryBoss or "")
        end
    end

    Window.contextLabel:SetText(text)
end

function Window.Create()
    if Window.control then
        return Window.control
    end

    local saved = SavedWindow() or {}

    local w = WM:CreateTopLevelWindow(WINDOW_NAME)
    w:SetDimensions(
        math.max(MIN_WIDTH, tonumber(saved.width) or DEFAULT_WIDTH),
        math.max(MIN_HEIGHT, tonumber(saved.height) or DEFAULT_HEIGHT))
    if tonumber(saved.x) and tonumber(saved.y) then
        w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.x, saved.y)
    else
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    w:SetHidden(true)
    -- Movable de forma permanente, como el patron oficial de ZOS para arrastrar
    -- una TopLevelControl desde un control hijo (ver performancemeter.xml:
    -- movable="true" fijo, el hijo solo llama StartMoving/StopMovingOrResizing
    -- sobre el padre). No se alterna por clic.
    w:SetMovable(true)
    w:SetMouseEnabled(true)
    w:SetClampedToScreen(true)
    -- Disparador principal del guardado de posicion: el evento nativo
    -- OnMoveStop, que la TopLevelControl dispara ella misma al terminar
    -- CUALQUIER arrastre, independientemente de donde acabe el cursor.
    -- Patron verificado en produccion (EZOChat, modules/ui.lua): mas fiable
    -- que depender solo del OnMouseUp del hijo que inicio el arrastre, que
    -- podria no dispararse si el cursor se separa del header durante un
    -- arrastre rapido. El OnMouseUp de la cabecera (mas abajo) se deja como
    -- respaldo; llamar SavePosition dos veces no tiene coste.
    w:SetHandler("OnMoveStop", function()
        Window.SavePosition()
    end)

    local background = WM:CreateControl(nil, w, CT_BACKDROP)
    background:SetAnchorFill(w)
    background:SetEdgeTexture(nil, 1, 1, 1, 0)
    background:SetCenterColor(0, 0, 0, 0.88)
    Window.background = background

    local header = CreateHeader(w)
    Window.header = header

    -- Solo se arrastra desde la cabecera, para no mover la ventana al
    -- interactuar con el contenido. Patron oficial ZOS: el hijo (header) llama
    -- StartMoving/StopMovingOrResizing sobre el padre (w), que ya es movable de
    -- forma permanente.
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if EZOArmory.DebugLog then EZOArmory.DebugLog("Window header mousedown, starting move") end
        w:StartMoving()
    end)
    header:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        w:StopMovingOrResizing()
        Window.SavePosition()
    end)

    -- Cuerpo: contenedor donde se montara el contenido de las siguientes fases.
    local body = WM:CreateControl(nil, w, CT_CONTROL)
    body:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 12, 10)
    body:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -12, -12)
    Window.body = body

    if EZOArmory.WindowKits and EZOArmory.WindowKits.Create then
        EZOArmory.WindowKits.Create(body)
    end

    Window.control = w
    return w
end

function Window.Show()
    Window.Create()
    if not IsHudScene() then
        -- Fuera de HUD no se muestra; se recordara la intencion para cuando
        -- se vuelva a una escena permitida.
        Window.requestedVisible = true
        return false
    end

    Window.requestedVisible = true
    Window.RefreshContext()
    Window.RefreshVisibility()
    if EZOArmory.WindowKits and EZOArmory.WindowKits.RefreshActive then
        -- Refleja cambios hechos por el panel LAM mientras la ventana estaba
        -- cerrada, en la pestana en la que se quedo el jugador.
        EZOArmory.WindowKits.RefreshActive()
    end

    -- El raton hace falta para interactuar con la ventana.
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        SCENE_MANAGER:SetInUIMode(true, false)
    end
    if type(PlaySound) == "function" and SOUNDS and SOUNDS.DEFAULT_WINDOW_OPEN then
        PlaySound(SOUNDS.DEFAULT_WINDOW_OPEN)
    end
    return true
end

function Window.Hide()
    Window.requestedVisible = false
    Window.RefreshVisibility()
    if type(PlaySound) == "function" and SOUNDS and SOUNDS.DEFAULT_WINDOW_CLOSE then
        PlaySound(SOUNDS.DEFAULT_WINDOW_CLOSE)
    end
end

function Window.IsShown()
    return Window.control ~= nil and Window.control:IsHidden() == false
end

function Window.Toggle()
    if Window.IsShown() then
        Window.Hide()
    else
        Window.Show()
    end
end

function Window.Init()
    Window.Create()

    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            Window.RefreshVisibility()
        end)
    end

    -- Mantiene el contexto de la cabecera al dia mientras la ventana este abierta.
    if EZOArmory.Context and EZOArmory.Context.RegisterCallback then
        EZOArmory.Context.RegisterCallback(function()
            if Window.IsShown() then
                Window.RefreshContext()
            end
        end)
    end
end

-- Punto de entrada global del keybind (Bindings.xml) y del comando de chat.
function EZOArmory_ToggleWindow()
    if EZOArmory.Window and EZOArmory.Window.Toggle then
        EZOArmory.Window.Toggle()
    end
end
