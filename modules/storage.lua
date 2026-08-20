-- Guardar y sacar las piezas de una build del banco o de un baul de casa.
--
-- Hechos verificados (contra Wizard's Wardrobe en produccion,
-- modules/WizardsWardrobeBanking.lua, y la documentacion oficial):
--
--   - RequestMoveItem ES una funcion protegida, pero se puede llamar con
--     CallSecureProtected("RequestMoveItem", ...) SIN necesidad de que la
--     accion venga de un clic: WW la invoca desde un temporizador y funciona.
--   - Solo se puede mover con el contenedor ABIERTO. No existe forma de
--     depositar "desde el campo".
--   - Para saber si hay uno abierto NO vale IsBankOpen(): con un cofre de
--     almacenamiento de casa devuelve false. Se rastrean EVENT_OPEN_BANK /
--     EVENT_CLOSE_BANK, que llevan la bolsa concreta y sirven igual para el
--     banco, el de suscriptor y los cofres (BAG_HOUSE_BANK_ONE..TEN).
--     Ver Storage.IsOpen / Storage.GetOpenBag.
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

-- ------------------------------------- Contenedor abierto ahora mismo ----
--
-- IsBankOpen() NO basta: con un COFRE DE ALMACENAMIENTO de casa abierto
-- devuelve false, comprobado en juego (la traza de diagnostico registro
-- "bankOpen=false" con el cofre delante). Leyendo el codigo del juego se
-- diria lo contrario -- banking_gamepad.lua hace
-- "IsBankOpen() and IsHouseBankBag(GetBankingBag())" --, pero el dato real
-- manda sobre la deduccion.
--
-- Se rastrea EVENT_OPEN_BANK / EVENT_CLOSE_BANK, que llevan la bolsa concreta
-- y valen igual para el banco, el de suscriptor y los diez cofres de casa.
local openBankBag = nil
local eventsRegistered = false

function Storage.InitEvents()
    if eventsRegistered then return end
    local kind = type(EVENT_MANAGER)
    if kind ~= "table" and kind ~= "userdata" then return end
    if EVENT_OPEN_BANK == nil or EVENT_CLOSE_BANK == nil then return end
    eventsRegistered = true

    EVENT_MANAGER:RegisterForEvent("EZOArmory_StorageOpen", EVENT_OPEN_BANK, function(_, bankBag)
        openBankBag = bankBag
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "Storage: contenedor abierto, bag=%s (cofre de casa=%s)",
                tostring(bankBag),
                tostring(type(IsHouseBankBag) == "function" and IsHouseBankBag(bankBag))))
        end
    end)

    EVENT_MANAGER:RegisterForEvent("EZOArmory_StorageClose", EVENT_CLOSE_BANK, function()
        openBankBag = nil
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog("Storage: contenedor cerrado")
        end
    end)
end

-- Bolsa de almacenamiento abierta ahora mismo, o nil. Es lo que sustituye a
-- IsBankOpen() en todo el modulo.
function Storage.GetOpenBag()
    if openBankBag ~= nil then return openBankBag end
    -- Respaldo por si el evento se perdio (recarga de interfaz con el
    -- contenedor ya abierto, por ejemplo).
    if type(IsBankOpen) == "function" and IsBankOpen() and type(GetBankingBag) == "function" then
        local ok, banking = pcall(GetBankingBag)
        if ok and banking then return banking end
    end
    return nil
end

function Storage.IsOpen()
    return Storage.GetOpenBag() ~= nil
end

-- Bolsas donde puede estar una pieza guardada (no equipada).
local function StorageBags()
    local bags = {}
    if BAG_BANK ~= nil then bags[#bags + 1] = BAG_BANK end
    if BAG_SUBSCRIBER_BANK ~= nil then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    -- La bolsa abierta puede ser un cofre de casa, que no esta en la lista de
    -- arriba. Se anade la que este abierta de verdad.
    local open = Storage.GetOpenBag()
    if open then
        local known = false
        for _, bag in ipairs(bags) do
            if bag == open then known = true break end
        end
        if not known then bags[#bags + 1] = open end
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
        -- Un kit al que la build apunta pero que ya no existe se llevaria sus
        -- piezas por delante sin decir nada. Se registra: es justo el tipo de
        -- ausencia silenciosa que se lee como "no ha guardado tal pieza".
        if not kit and EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "Storage: la build %s apunta al kit %s, que no existe",
                tostring(buildId), tostring(kitId)))
        end
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

    -- El banco puede haberse cerrado a mitad del proceso. Las piezas que
    -- quedaban se cuentan como no movidas en vez de desaparecer del informe:
    -- si no, el recuento final cuadra y aun asi faltan piezas por guardar.
    if not Storage.IsOpen() then
        state.aborted = true
        state.failed = state.failed + 1
        state.failedNames[#state.failedNames + 1] = entry.label
        for _, pending in ipairs(queue) do
            state.failed = state.failed + 1
            state.failedNames[#state.failedNames + 1] = pending.label
        end
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

        -- Se comprueba que la pieza YA NO ESTA EN EL ORIGEN, no que haya
        -- aparecido en el hueco calculado. El servidor no tiene por que
        -- ponerla justo ahi: ese hueco puede ocuparse entre medias, o el
        -- inventario reorganizarse. Vigilando el destino exacto, una pieza que
        -- SI se habia movido se daba por no llegada al agotar los 3 s y se
        -- informaba como fallo. Que desaparezca del origen es concluyente.
        if EZOArmory.Gear.ReadItemId(entry.bag, entry.slot) ~= entry.itemId then
            EVENT_MANAGER:UnregisterForUpdate(namespace)
            state.moved = state.moved + 1
            if EZOArmory.DebugLog then
                EZOArmory.DebugLog(string.format(
                    "Storage: movida %s (%d intentos)", tostring(entry.label), tries))
            end
            -- Margen antes de la siguiente. Al comprobar la salida del ORIGEN
            -- se sabe que la pieza se ha movido, pero no que ya ocupe su hueco
            -- en el destino; sin esta pausa, el FindFirstEmptySlotInBag de la
            -- pieza siguiente puede devolver ese mismo hueco todavia libre y
            -- las dos se pisarian. WW espera igualmente entre movimientos.
            zo_callLater(function()
                MoveNext(queue, destBag, state, onDone)
            end, ARRIVAL_POLL_MS)
            return
        end

        if tries >= ARRIVAL_MAX_TRIES then
            EVENT_MANAGER:UnregisterForUpdate(namespace)
            state.failed = state.failed + 1
            state.failedNames[#state.failedNames + 1] = entry.label
            if EZOArmory.DebugLog then
                EZOArmory.DebugLog(string.format(
                    "Storage: NO movida %s (origen %s:%s -> destino %s:%s)",
                    tostring(entry.label), tostring(entry.bag), tostring(entry.slot),
                    tostring(target), tostring(destSlot)))
            end
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

    if EZOArmory.DebugLog then
        EZOArmory.DebugLog(string.format(
            "Storage: build %s -> %d piezas del kit, %d en cola, %d puestas, %d no encontradas",
            tostring(buildId), #Storage.GetBuildItemIds(buildId),
            #queue, state.worn, state.missing))
    end

    return queue, state
end

-- Saca del banco (o baul abierto) a la mochila todas las piezas de la build.
function Storage.Withdraw(buildId, onDone)
    if not Storage.IsOpen() then
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
    if not Storage.IsOpen() then
        if onDone then onDone({ error = "noBank" }) end
        return false
    end

    -- La bolsa REALMENTE abierta, que puede ser un cofre de casa y no el banco.
    local destBag = Storage.GetOpenBag() or BAG_BANK

    local queue, state = BuildQueue(buildId, { BAG_BACKPACK })
    MoveNext(queue, destBag, state, onDone)
    return true
end
