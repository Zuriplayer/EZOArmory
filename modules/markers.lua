-- Marca en el inventario las piezas que forman parte de algun kit o build.
--
-- Una "Z" morada (el color de la familia EZO, #B040FF) sobre la fila del item,
-- con un emergente al pasar el raton que dice en que kits y builds se usa. Asi
-- se sabe de un vistazo que no hay que descomponer ni vender esa pieza.
--
-- Patron verificado contra Wizard's Wardrobe (modules/WizardsWardrobeMarkers):
--   SecurePostHook(inventory.dataTypes[1], "setupCallback", fn)
-- SecurePostHook no esta en la fuente Lua de ESOUI (lo provee el motor), pero
-- es API estable de addons: la usan WW, AwesomeGuildStore y BanditsUserInterface
-- en produccion.
--
-- La marca es un CT_LABEL con el texto "Z" y no una textura: asi no hace falta
-- distribuir un .dds propio, y el color sale identico al de la familia.
--
-- La identidad del item es la misma que usan los kits
-- (Id64ToString(GetItemUniqueId(bag, slot))), asi que la marca senala la
-- instancia concreta guardada, no "otra igual".

EZOArmory = EZOArmory or {}
EZOArmory.Markers = EZOArmory.Markers or {}

local Markers = EZOArmory.Markers

-- Morado de la familia EZO (#B040FF).
local MARK_R, MARK_G, MARK_B = 0.69, 0.25, 1.0
local MARK_SIZE = 16

local marksByControlName = {}
local index = nil
local hooked = false

function Markers.IsEnabled()
    local sv = EZOArmory.sv
    if not sv or not sv.general then return true end
    return sv.general.inventoryMarker ~= false
end

-- Invalida el indice. Lo llaman los modulos de datos cuando cambia algo que
-- afecta a que piezas estan en uso o a como se llaman.
function Markers.Invalidate()
    index = nil
end

-- itemId -> { kits = { nombre, ... }, builds = { nombre, ... } }
local function BuildIndex()
    local result = {}
    if not (EZOArmory.Kits and EZOArmory.Kits.ListKits) then
        return result
    end

    -- Que builds usan cada kit, para poder nombrarlas en el emergente.
    local buildsByKit = {}
    if EZOArmory.Builds and EZOArmory.Builds.ListBuilds then
        for _, build in ipairs(EZOArmory.Builds.ListBuilds()) do
            for _, kitId in ipairs(build.gearKitIds or {}) do
                buildsByKit[kitId] = buildsByKit[kitId] or {}
                buildsByKit[kitId][#buildsByKit[kitId] + 1] = tostring(build.name)
            end
        end
    end

    local function AddOnce(list, value)
        for _, existing in ipairs(list) do
            if existing == value then return end
        end
        list[#list + 1] = value
    end

    for _, kit in ipairs(EZOArmory.Kits.ListKits()) do
        for _, piece in pairs(kit.pieces or {}) do
            local itemId = piece.itemId
            if itemId then
                local entry = result[itemId]
                if not entry then
                    entry = { kits = {}, builds = {} }
                    result[itemId] = entry
                end
                AddOnce(entry.kits, tostring(kit.name))
                for _, buildName in ipairs(buildsByKit[kit.id] or {}) do
                    AddOnce(entry.builds, buildName)
                end
            end
        end
    end

    return result
end

local function EnsureIndex()
    if not index then
        index = BuildIndex()
    end
    return index
end

local function TooltipText(entry)
    local lines = {}
    if #entry.kits > 0 then
        lines[#lines + 1] = zo_strformat(
            GetString(EZOARM_MARKER_IN_KITS), table.concat(entry.kits, ", "))
    end
    if #entry.builds > 0 then
        lines[#lines + 1] = zo_strformat(
            GetString(EZOARM_MARKER_IN_BUILDS), table.concat(entry.builds, ", "))
    end
    return table.concat(lines, "\n")
end

-- Una marca por control de fila, reutilizada: las filas del inventario son un
-- pool que se recicla al desplazarse, asi que crear una marca nueva por
-- refresco iria acumulando controles sin fin.
local function GetMark(control)
    local name = control:GetName()
    local mark = marksByControlName[name]
    if not mark then
        mark = WINDOW_MANAGER:CreateControl(name .. "EZOArmoryMark", control, CT_LABEL)
        mark:SetFont("ZoFontGameBold")
        mark:SetColor(MARK_R, MARK_G, MARK_B, 1)
        mark:SetText("Z")
        mark:SetDimensions(MARK_SIZE, MARK_SIZE)
        mark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        mark:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        mark:SetDrawLayer(3)
        mark:SetMouseEnabled(true)
        mark:SetHidden(true)
        mark:SetAnchor(RIGHT, control, LEFT, 38, 0)
        marksByControlName[name] = mark
    end
    return mark
end

local function AddMark(control)
    if not Markers.IsEnabled() then return end
    local dataEntry = control and control.dataEntry
    local slot = dataEntry and dataEntry.data
    if not slot or slot.bagId == nil or slot.slotIndex == nil then return end
    if type(GetItemUniqueId) ~= "function" or type(Id64ToString) ~= "function" then return end

    local ok, uniqueId = pcall(GetItemUniqueId, slot.bagId, slot.slotIndex)
    if not ok or not uniqueId then return end
    local itemId = Id64ToString(uniqueId)

    local mark = GetMark(control)
    local entry = EnsureIndex()[itemId]
    mark:SetHidden(entry == nil)
    if not entry then
        mark:SetHandler("OnMouseEnter", nil)
        mark:SetHandler("OnMouseExit", nil)
        return
    end

    mark:SetHandler("OnMouseEnter", function(self)
        if type(ZO_Tooltips_ShowTextTooltip) == "function" then
            ZO_Tooltips_ShowTextTooltip(self, RIGHT, TooltipText(entry))
        end
    end)
    mark:SetHandler("OnMouseExit", function()
        if type(ZO_Tooltips_HideTextTooltip) == "function" then
            ZO_Tooltips_HideTextTooltip()
        end
    end)
end

-- Inventarios marcados, los mismos que WW: mochila, banco, banco de hermandad
-- y los paneles de descomponer y mejorar, que es justo donde uno se arriesga a
-- destruir una pieza que forma parte de una build.
local function GetInventories()
    return {
        ZO_PlayerInventoryBackpack,
        ZO_PlayerBankBackpack,
        ZO_GuildBankBackpack,
        ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack,
        ZO_SmithingTopLevelImprovementPanelInventoryBackpack,
    }
end

function Markers.Init()
    if hooked then return end
    if not Markers.IsEnabled() then return end
    if type(SecurePostHook) ~= "function" then return end

    for _, inventory in ipairs(GetInventories()) do
        local dataType = inventory and inventory.dataTypes and inventory.dataTypes[1]
        if dataType then
            SecurePostHook(dataType, "setupCallback", function(control)
                AddMark(control)
            end)
        end
    end

    hooked = true
end
