-- Guardar y sacar las piezas de una build del banco o de un baul de casa.
--
-- Hechos verificados (contra Wizard's Wardrobe en produccion,
-- modules/WizardsWardrobeBanking.lua, y la documentacion oficial):
--
--   - RequestMoveItem ES una funcion protegida, pero se puede llamar con
--     CallSecureProtected("RequestMoveItem", ...) SIN necesidad de que la
--     accion venga de un clic: WW la invoca desde un temporizador y funciona.
--   - Solo se puede mover con el banco/baul ABIERTO (IsBankOpen). No existe
--     forma de depositar "desde el campo".
--   - GetBankingBag() devuelve la bolsa abierta, asi que lo mismo vale para el
--     banco normal, el de suscriptor y los baules de casa
--     (BAG_HOUSE_BANK_ONE..TEN) sin tratarlos por separado.
--   - Hay que mover UNA pieza cada vez y esperar a que llegue: el servidor
--     tarda, y mandarlas todas de golpe pierde piezas por el camino. WW
--     comprueba la llegada cada 100 ms y aborta a los 3 s.
--   - DoesBagHaveSpaceFor antes de cada movimiento; si el banco normal se
--     llena y hay ESO Plus, se sigue en el de suscriptor.
--
-- ALCANCE DELIBERADO: no se toca NADA de lo que llevas puesto. Una pieza de la
-- build que este equipada se cuenta aparte y se avisa, pero no se desequipa.
-- Decision de Ricardo: evita el caso destructivo de quedarte sin equipo por
-- pulsar donde no era.

EZOArmory = EZOArmory or {}
EZOArmory.Storage = EZOArmory.Storage or {}

local Storage = EZOArmory.Storage

-- Cada cuanto se comprueba si la pieza ha llegado a su destino, y cuantas
-- veces antes de rendirse. Mismos valores que WW: 100 ms x 30 = 3 s.
local ARRIVAL_POLL_MS = 100
local ARRIVAL_MAX_TRIES = 30

local moveCounter = 0

-- Bolsas donde puede estar una pieza guardada (no equipada).
local function StorageBags()
    local bags = {}
    if BAG_BANK ~= nil then bags[#bags + 1] = BAG_BANK end
    if BAG_SUBSCRIBER_BANK ~= nil then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    -- La bolsa abierta puede ser un baul de casa, que no esta en la lista de
    -- arriba; GetBankingBag la devuelve sea cual sea.
    if type(GetBankingBag) == "function" then
        local ok, banking = pcall(GetBankingBag)
        if ok and banking then
            local known = false
            for _, bag in ipairs(bags) do
                if bag == banking then known = true break end
            end
            if not known then bags[#bags + 1] = banking end
        end
    end
    return bags
end

-- Todas las piezas de los kits de equipo de una build, sin repetir. Se usan
-- los kits enteros y no el reparto de coherencia: si un kit tiene cinco
-- piezas, se quieren las cinco, gane o no cada slot en el analisis.
function Storage.GetBuildItemIds(buildId)
    local build = EZOArmory.Builds and EZOArmory.Builds.GetBuild(buildId)
    if not build then return {} end

    local seen = {}
    local items = {}
    for _, kitId in ipairs(build.gearKitIds or {}) do
        local kit = EZOArmory.Kits.GetKit(kitId)
        for _, piece in pairs((kit and kit.pieces) or {}) do
            if piece.itemId and not seen[piece.itemId] then
                seen[piece.itemId] = true
                items[#items + 1] = {
                    itemId = piece.itemId,
                    itemName = piece.itemName,
                    setName = piece.setName,
                }
            end
        end
    end
    return items
end

-- Localiza una pieza en las bolsas indicadas. Devuelve bag, slot o nil.
local function FindInBags(itemId, bags)
    for _, bag in ipairs(bags) do
        local size = (type(GetBagSize) == "function" and GetBagSize(bag)) or 0
        for slot = 0, size do
            if EZOArmory.Gear.ReadItemId(bag, slot) == itemId then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- Mueve la lista de una en una, esperando a que cada pieza llegue antes de
-- seguir. Mover en lote no vale: el servidor tarda y se pierden piezas.
local function MoveNext(queue, destBag, state, onDone)
    if #queue == 0 then
        if onDone then onDone(state) end
        return
    end

    local entry = table.remove(queue, 1)

    -- El banco puede haberse cerrado a mitad del proceso.
    if type(IsBankOpen) == "function" and not IsBankOpen() then
        state.aborted = true
        if onDone then onDone(state) end
        return
    end

    local target = destBag
    if type(DoesBagHaveSpaceFor) == "function"
        and not DoesBagHaveSpaceFor(target, entry.bag, entry.slot) then
        -- Banco lleno: con ESO Plus queda el de suscriptor.
        if target == BAG_BANK and BAG_SUBSCRIBER_BANK ~= nil
            and type(IsESOPlusSubscriber) == "function" and IsESOPlusSubscriber()
            and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, entry.bag, entry.slot) then
            target = BAG_SUBSCRIBER_BANK
        else
            state.noSpace = state.noSpace + 1
            state.noSpaceNames[#state.noSpaceNames + 1] = entry.label
            MoveNext(queue, destBag, state, onDone)
            return
        end
    end

    local destSlot = type(FindFirstEmptySlotInBag) == "function"
        and FindFirstEmptySlotInBag(target) or nil
    if not destSlot then
        state.noSpace = state.noSpace + 1
        state.noSpaceNames[#state.noSpaceNames + 1] = entry.label
        MoveNext(queue, destBag, state, onDone)
        return
    end

    if type(CallSecureProtected) ~= "function" then
        state.failed = state.failed + 1
        state.failedNames[#state.failedNames + 1] = entry.label
        MoveNext(queue, destBag, state, onDone)
        return
    end
    CallSecureProtected("RequestMoveItem", entry.bag, entry.slot, target, destSlot, 1)

    moveCounter = moveCounter + 1
    local namespace = "EZOArmory_Move_" .. tostring(moveCounter)
    local tries = 0

    EVENT_MANAGER:RegisterForUpdate(namespace, ARRIVAL_POLL_MS, function()
        tries = tries + 1

        if EZOArmory.Gear.ReadItemId(target, destSlot) == entry.itemId then
            EVENT_MANAGER:UnregisterForUpdate(namespace)
            state.moved = state.moved + 1
            MoveNext(queue, destBag, state, onDone)
            return
        end

        if tries >= ARRIVAL_MAX_TRIES then
            EVENT_MANAGER:UnregisterForUpdate(namespace)
            state.failed = state.failed + 1
            state.failedNames[#state.failedNames + 1] = entry.label
            MoveNext(queue, destBag, state, onDone)
        end
    end)
end

-- Prepara el trabajo: localiza cada pieza en las bolsas de origen, aparta las
-- que estan equipadas (no se tocan) y las que no aparecen.
local function BuildQueue(buildId, sourceBags)
    local queue = {}
    local state = {
        moved = 0,
        worn = 0,
        missing = 0,
        failed = 0,
        noSpace = 0,
        wornNames = {},
        missingNames = {},
        failedNames = {},
        noSpaceNames = {},
        aborted = false,
    }

    for _, item in ipairs(Storage.GetBuildItemIds(buildId)) do
        local label = (item.itemName ~= "" and item.itemName)
            or (item.setName ~= "" and item.setName) or tostring(item.itemId)

        -- Equipada: se cuenta y se deja en paz (ver ALCANCE arriba).
        local wornBag, wornSlot = FindInBags(item.itemId, { BAG_WORN })
        if wornBag then
            state.worn = state.worn + 1
            state.wornNames[#state.wornNames + 1] = label
        else
            local bag, slot = FindInBags(item.itemId, sourceBags)
            if bag then
                queue[#queue + 1] = { itemId = item.itemId, bag = bag, slot = slot, label = label }
            else
                state.missing = state.missing + 1
                state.missingNames[#state.missingNames + 1] = label
            end
        end
        -- wornSlot no se usa: la pieza no se mueve.
        local _ = wornSlot
    end

    return queue, state
end

-- Saca del banco (o baul abierto) a la mochila todas las piezas de la build.
function Storage.Withdraw(buildId, onDone)
    if type(IsBankOpen) ~= "function" or not IsBankOpen() then
        if onDone then onDone({ error = "noBank" }) end
        return false
    end
    local queue, state = BuildQueue(buildId, StorageBags())
    MoveNext(queue, BAG_BACKPACK, state, onDone)
    return true
end

-- Guarda en el banco (o baul abierto) las piezas de la build que estan en la
-- mochila. Lo equipado no se toca.
function Storage.Deposit(buildId, onDone)
    if type(IsBankOpen) ~= "function" or not IsBankOpen() then
        if onDone then onDone({ error = "noBank" }) end
        return false
    end

    local destBag = BAG_BANK
    if type(GetBankingBag) == "function" then
        local ok, banking = pcall(GetBankingBag)
        if ok and banking then destBag = banking end
    end

    local queue, state = BuildQueue(buildId, { BAG_BACKPACK })
    MoveNext(queue, destBag, state, onDone)
    return true
end
