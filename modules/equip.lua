-- Equipado de kits mediante una cola con LibAsync.
--
-- Hechos verificados (contra Wizard's Wardrobe, en produccion):
--   - EquipItem(sourceBag, sourceSlot, destEquipSlot) NO es funcion protegida.
--   - Pero el equipo NO se puede cambiar en combate ni muerto: WW condiciona el
--     cambio a not IsUnitInCombat("player") and not IsUnitDeadOrReincarnating.
--   - Mover desde el banco SI es protegido, asi que las piezas deben estar en la
--     mochila (BAG_BACKPACK) o ya puestas.
--   - GetItemLinkStacks(itemLink) -> bagCount, bankCount, ... SI funciona a
--     distancia (sin haber visitado el banco): es la misma API que pinta la
--     linea "Bank: X" en cualquier tooltip de item, en cualquier sitio
--     (verificado en esoui/publicallingames/tooltip/itemtooltips.lua). Se usa
--     solo para avisar de donde esta una pieza que falta, nunca para moverla.
--
-- Este modulo no crea globales de trabajo pesado ni corre en cada frame salvo
-- mientras aplica un equipado. LibAsync es opcional: sin el, el equipado no esta
-- disponible pero el resto del addon sigue funcionando.

EZOArmory = EZOArmory or {}
EZOArmory.Equip = EZOArmory.Equip or {}

local Equip = EZOArmory.Equip

-- Se puede cambiar equipo ahora mismo.
function Equip.IsReady()
    if type(IsUnitInCombat) == "function" and IsUnitInCombat("player") then
        return false
    end
    if type(IsUnitDeadOrReincarnating) == "function" and IsUnitDeadOrReincarnating("player") then
        return false
    end
    return true
end

-- El equipado requiere LibAsync para repartir el trabajo entre frames.
function Equip.IsAvailable()
    return LibAsync ~= nil
end

-- Aviso de "esto no se aplica todavia, esta esperando". Vive aqui, y no en la
-- ventana, porque hasta 0.11.19 cada punto de equipado manual asignaba su
-- propio Equip.onQueued y el equipado AUTOMATICO no asignaba ninguno: cuando
-- el auto-equipado se quedaba en cola por combate no avisaba de nada, y no
-- habia forma de distinguir "no ha funcionado" de "esta esperando". Ademas,
-- al ser una sola variable de modulo, el aviso que salia dependia del ultimo
-- equipado manual hecho en esa sesion. Ahora el mensaje por defecto es comun
-- a las dos rutas; Equip.onQueued se respeta si alguien lo asigna, para no
-- romper a quien lo use.
local function NotifyQueued(reason)
    if type(Equip.onQueued) == "function" then
        Equip.onQueued(reason)
        return
    end
    if not EZOArmory.Print then return end
    if reason == "cpCooldown" then
        EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED_CP_COOLDOWN))
    else
        EZOArmory.Print(GetString(EZOARM_MSG_EQUIP_QUEUED))
    end
end

-- Construye la lista de objetivos a partir del analisis de coherencia de unos
-- kits: para cada slot asignado, el item concreto y su constante de equip slot.
--
-- El resultado se ORDENA por el orden canonico de Gear.SLOT_DEFS (armadura,
-- joyeria, armas). Antes se recorria assignment con pairs(), que en Lua no
-- garantiza ningun orden y puede variar entre ejecuciones: con piezas que se
-- intercambian de slot (los dos anillos, un arma que pasa de barra frontal a
-- trasera) el resultado dependia del orden y por eso a veces hacia falta
-- repetir el equipado. WW usa igualmente una lista fija (WW.GEARSLOTS).
local function BuildTargets(analysis)
    local targets = {}
    if not analysis or not analysis.assignment then
        return targets
    end

    local rank = {}
    for index, def in ipairs(EZOArmory.Gear.SLOT_DEFS) do
        rank[def.key] = index
    end

    for slotKey, piece in pairs(analysis.assignment) do
        local equipSlot = EZOArmory.Gear.GetEquipSlotId(slotKey)
        if equipSlot ~= nil and piece.itemId then
            targets[#targets + 1] = {
                slotKey = slotKey,
                equipSlot = equipSlot,
                itemId = piece.itemId,
                itemLink = piece.itemLink,
                itemName = piece.itemName,
                setName = piece.setName,
            }
        end
    end

    table.sort(targets, function(a, b)
        return (rank[a.slotKey] or 99) < (rank[b.slotKey] or 99)
    end)
    return targets
end

-- Si un item no esta en equipo puesto ni mochila, pregunta si al menos esta en
-- el banco (informativo: no se puede mover desde alli sin accion del jugador).
-- GetItemLinkStacks es la misma API que alimenta la linea "Bank: X" de
-- cualquier tooltip de item, en cualquier sitio - no hace falta haber entrado
-- al banco ni llevar un registro por personaje.
local function IsInBank(itemLink)
    if not itemLink or itemLink == "" or type(GetItemLinkStacks) ~= "function" then
        return false
    end
    local ok, _, bankCount = pcall(GetItemLinkStacks, itemLink)
    return ok and (tonumber(bankCount) or 0) > 0
end

-- Margen antes de comprobar si las piezas se han puesto de verdad. EquipItem
-- NO surte efecto en el mismo frame: es una peticion al servidor y la bolsa
-- se actualiza despues (por eso existe EVENT_INVENTORY_SINGLE_SLOT_UPDATE).
-- Wizard's Wardrobe no verifica nada tras EquipItem y mete esperas explicitas
-- de 500 ms por este mismo motivo ("Be sure to give enough time so backbar can
-- find new location", WizardsWardrobe.lua). 0.11.17 comprobaba el slot en el
-- mismo frame de la llamada, lo que podia contar como fallida una pieza que
-- si se estaba equipando.
local EQUIP_VERIFY_DELAY_MS = 600

-- Margen tras mover una pieza que ya estaba puesta en otro slot de equipo.
-- Ese caso reubica dos slots a la vez (lo que estaba en el destino sale), y sin
-- margen la pieza siguiente puede localizarse en una posicion que el juego
-- todavia no ha actualizado. Mismo valor que usa WW para el equivalente.
local WORN_SWAP_SETTLE_MS = 500

-- Equipa un objetivo. Muta el contador de estado. Las piezas que se llegan a
-- pedir se apuntan en "attempted" para comprobarlas al final, no aqui.
local function EquipOne(target, state, attempted)
    -- Ya puesto en el slot correcto: nada que hacer.
    local wornId = EZOArmory.Gear.ReadItemId(BAG_WORN, target.equipSlot)
    if wornId ~= nil and wornId == target.itemId then
        state.already = state.already + 1
        return
    end

    -- Se localiza en el momento (las posiciones cambian al equipar).
    local location = EZOArmory.Gear.FindItemById(target.itemId)
    if not location then
        local label = target.itemName ~= "" and target.itemName or (target.setName ~= "" and target.setName or target.slotKey)
        if IsInBank(target.itemLink) then
            state.inBank = state.inBank + 1
            state.inBankNames[#state.inBankNames + 1] = label
        else
            state.missing = state.missing + 1
            state.missingNames[#state.missingNames + 1] = label
        end
        return
    end

    if type(EquipItem) ~= "function" then return end

    -- location.bag puede ser BAG_WORN: la pieza esta puesta, pero en OTRO slot
    -- de equipo (los dos anillos intercambiados, un arma que pasa de la barra
    -- frontal a la trasera). Hasta 0.11.23 ese caso solo se contaba como
    -- "wornElsewhere" y no se tocaba, asi que la pieza de la build anterior se
    -- quedaba puesta en el slot de destino: es la causa principal de tener que
    -- repetir el equipado varias veces. EquipItem acepta BAG_WORN como origen
    -- y hace el intercambio; verificado contra Wizard's Wardrobe en
    -- produccion, cuyo GetItemLocation recorre { BAG_WORN, BAG_BACKPACK } y
    -- pasa lo que encuentre directamente a EquipItem.
    local fromWorn = location.bag == BAG_WORN
    if fromWorn then
        state.wornElsewhere = state.wornElsewhere + 1
    end

    EquipItem(location.bag, location.slot, target.equipSlot)
    attempted[#attempted + 1] = target
    -- Devuelve si el origen era equipo puesto: en ese caso el intercambio
    -- reubica DOS slots y conviene dejar un margen antes de seguir, o la
    -- siguiente pieza puede localizarse en un sitio que ya no es el suyo. WW
    -- hace lo mismo para el caso mano principal -> respaldo ("Be sure to give
    -- enough time so backbar can find new location").
    return fromWorn
end

-- Comprueba, ya con margen, cuales de las piezas pedidas estan realmente
-- puestas. Se hace en una pasada al final y no justo tras cada EquipItem
-- porque el cambio no es inmediato (ver EQUIP_VERIFY_DELAY_MS). Sigue
-- mereciendo la pena verificar: si el combate empieza a mitad del lote, las
-- peticiones restantes no surten efecto, y sin esto se informaria de piezas
-- equipadas que no lo estan. Mismo principio que verificar el CP contra
-- EVENT_CHAMPION_PURCHASE_RESULT (0.11.14) en vez de fiarse del envio.
local function VerifyEquipped(attempted, state)
    for _, target in ipairs(attempted) do
        local wornId = EZOArmory.Gear.ReadItemId(BAG_WORN, target.equipSlot)
        if wornId ~= nil and wornId == target.itemId then
            state.equipped = state.equipped + 1
        else
            local label = target.itemName ~= "" and target.itemName
                or (target.setName ~= "" and target.setName or target.slotKey)
            state.failed = state.failed + 1
            state.failedNames[#state.failedNames + 1] = label
        end
    end
end

-- Aplica los kits indicados. onReport(state) se llama al terminar (o con un
-- estado de error). Devuelve true si se ha iniciado el proceso.
--
-- state al terminar: { equipped, already, missing, wornElsewhere, failed,
--                       missingNames, inBank, inBankNames, failedNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplyKits(kitIds, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    if not (EZOArmory.Kits and EZOArmory.Coherence) then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local resolved = EZOArmory.Kits.ResolveKits(kitIds)
    local analysis = EZOArmory.Coherence.Analyze(resolved)
    local targets = BuildTargets(analysis)

    if #targets == 0 then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local state = {
        equipped = 0,
        already = 0,
        missing = 0,
        wornElsewhere = 0,
        failed = 0,
        missingNames = {},
        inBank = 0,
        inBankNames = {},
        failedNames = {},
        queued = not Equip.IsReady(),
    }

    if state.queued then
        NotifyQueued("combat")
    end

    local attempted = {}

    local task = LibAsync:Create("EZOArmory_Equip")
    task:WaitUntil(function()
        return Equip.IsReady()
    end):Then(function(innerTask)
        -- Se vuelve a comprobar "listo" ANTES DE CADA PIEZA, no solo una vez
        -- para todo el lote: un lote largo se reparte entre varios frames
        -- (For:Do de LibAsync), y si el combate empieza a mitad, las piezas
        -- restantes fallarian en silencio sin este chequeo repetido. Patron
        -- verificado contra Wizard's Wardrobe en produccion (WW.MoveItems,
        -- WizardsWardrobe.lua): repite WaitUntil(IsReadyToSwap) dentro del
        -- propio bucle, pieza a pieza, en vez de una vez para todo el lote.
        innerTask:For(1, #targets):Do(function(index)
            innerTask:WaitUntil(function()
                return Equip.IsReady()
            end):Then(function(pieceTask)
                if EquipOne(targets[index], state, attempted) then
                    -- Solo cuando la pieza venia de otro slot de equipo: ese
                    -- intercambio mueve dos slots a la vez y la siguiente
                    -- pieza necesita que el juego haya asentado las
                    -- posiciones antes de localizarla.
                    pieceTask:Delay(WORN_SWAP_SETTLE_MS, function() end)
                end
            end)
        end):Then(function(verifyTask)
            -- Margen antes de comprobar: las peticiones de equipado que
            -- acabamos de enviar todavia pueden estar en vuelo.
            verifyTask:Delay(EQUIP_VERIFY_DELAY_MS, function()
                VerifyEquipped(attempted, state)
                if onReport then onReport(state) end
            end)
        end)
    end)

    return true
end

-- ------------------------------------------------------- Kits de habilidades ----
--
-- Ranurar una habilidad por codigo (verificado contra el manager nativo,
-- esoui/ingame/skills/actionbarassignmentmanager.lua, y contra
-- WW.SlotSkill/WW.LoadSkills en Wizard's Wardrobe, en produccion):
--   ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)
--       :AssignSkillToSlotByAbilityId(slotIndex, abilityId)
-- No es funcion protegida (llamada Lua normal, sin keybind), pero fuera de
-- combate: RESPEC_RESULT_IS_IN_COMBAT es un resultado de fallo esperado.
-- Antes de ranurar se comprueba que la habilidad este comprada
-- (SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id):GetSkillData()
-- :IsPurchased()), igual que hace WW, por si el kit se capturo en otro
-- personaje o antes de un respec. Solo se toca lo que difiere de lo ya
-- ranurado (mismo principio de aplicacion idempotente que el equipo).

-- Aplica un kit de habilidades. onReport(state) al terminar.
-- state al terminar: { slotted, already, skipped, skippedNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplySkillKit(kitId, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    local kit = EZOArmory.Skills and EZOArmory.Skills.GetKit(kitId)
    if not kit or not kit.bars then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    local state = {
        slotted = 0,
        already = 0,
        skipped = 0,
        skippedNames = {},
        queued = not Equip.IsReady(),
    }

    if state.queued then
        NotifyQueued("combat")
    end

    local task = LibAsync:Create("EZOArmory_EquipSkills")
    task:WaitUntil(function()
        return Equip.IsReady()
    end):Then(function()
        if type(ACTION_BAR_ASSIGNMENT_MANAGER) ~= "table"
            or type(GetSlotBoundId) ~= "function" then
            if onReport then onReport({ error = "empty" }) end
            return
        end

        for hotbar = EZOArmory.Skills.HOTBAR_FRONT, EZOArmory.Skills.HOTBAR_BACK do
            local hotbarData = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbar)
            local bar = kit.bars[hotbar] or {}
            for slot = EZOArmory.Skills.SLOT_FIRST, EZOArmory.Skills.SLOT_LAST do
                local abilityId = tonumber(bar[slot]) or 0
                if abilityId ~= 0 then
                    local okCurrent, current = pcall(GetSlotBoundId, slot, hotbar)
                    current = (okCurrent and tonumber(current)) or 0

                    if current == abilityId then
                        state.already = state.already + 1
                    else
                        local purchased = false
                        if type(SKILLS_DATA_MANAGER) == "table" then
                            local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
                            purchased = progressionData ~= nil
                                and progressionData:GetSkillData() ~= nil
                                and progressionData:GetSkillData():IsPurchased() == true
                        end

                        if purchased and hotbarData then
                            hotbarData:AssignSkillToSlotByAbilityId(slot, abilityId)
                            state.slotted = state.slotted + 1
                        else
                            state.skipped = state.skipped + 1
                            local okName, name = pcall(GetAbilityName, abilityId)
                            state.skippedNames[#state.skippedNames + 1] =
                                (okName and name and name ~= "") and zo_strformat("<<C:1>>", name)
                                or tostring(abilityId)
                        end
                    end
                end
            end
        end

        if onReport then onReport(state) end
    end)

    return true
end

-- ------------------------------------------------------------- Kits de CP ----
--
-- Ranurar una estrella de CP por codigo (verificado contra
-- esoui/ingame/champion/championassignableactionbar.lua y contra
-- WW.LoadCP en Wizard's Wardrobe, en produccion):
--   PrepareChampionPurchaseRequest()
--   AddHotbarSlotToChampionPurchaseRequest(slotIndex, championSkillId)  -- por slot que cambia
--   SendChampionPurchaseRequest()
-- Ninguna es protegida, pero el juego impone un cooldown real de ~30 s tras
-- cada cambio (CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN); se seguimiento
-- via EVENT_CHAMPION_PURCHASE_RESULT, igual que WW. CRITICO (docs/concept.md
-- 4.3.1): solo se envian los slots que realmente cambian respecto a lo ya
-- ranurado, nunca una peticion completa de los 12 aunque no haga falta.

local cpCooldownRemaining = 0
local cpCooldownTrackingRegistered = false

-- EVENT_MANAGER es GetEventManager(), un objeto del motor: su type() es
-- "userdata", NO "table" (esoui/app/globals/globals.lua:1). Comprobarlo con
-- type(...) == "table" era siempre falso, y de ahi salieron dos fallos que
-- estuvieron activos desde 0.11.14:
--   - SendAndVerifyCp abortaba con error "empty" en cuanto habia UNA estrella
--     que cambiar, asi que aplicar un kit de CP no funcionaba nunca. Solo
--     "funcionaba" el caso sin diferencias, que sale antes por otro camino y
--     por eso parecia correcto.
--   - El seguimiento del cooldown no llegaba a registrarse, asi que el
--     contador se quedaba en 0 y IsCpReady() era siempre verdadero.
-- context_tracker.lua ya aceptaba userdata; era equip.lua el que discrepaba.
local function HasEventManager()
    local kind = type(EVENT_MANAGER)
    return kind == "userdata" or kind == "table"
end

local function EnsureCpCooldownTracking()
    if cpCooldownTrackingRegistered then return end
    if not HasEventManager() or EVENT_CHAMPION_PURCHASE_RESULT == nil then return end
    cpCooldownTrackingRegistered = true

    EVENT_MANAGER:RegisterForEvent("EZOArmory_CPPurchaseResult", EVENT_CHAMPION_PURCHASE_RESULT,
        function(_, result)
            if result == CHAMPION_PURCHASE_SUCCESS then
                cpCooldownRemaining = 31
            end
        end)
    EVENT_MANAGER:RegisterForUpdate("EZOArmory_CPCooldownTick", 1000, function()
        if cpCooldownRemaining > 0 then
            cpCooldownRemaining = cpCooldownRemaining - 1
        end
    end)
end

-- Los CP no estan en cooldown ahora mismo (aparte de estar fuera de combate).
function Equip.IsCpReady()
    return cpCooldownRemaining <= 0
end

-- Maximo de reintentos automaticos ante un fallo transitorio (cooldown o
-- entrar en combate justo entre la comprobacion previa y el envio). Acotado
-- para no reintentar sin fin si el fallo resulta no ser transitorio de
-- verdad.
local MAX_CP_RETRIES = 1
local cpRequestCounter = 0

-- Envia las estrellas que difieren y ESPERA la confirmacion real del
-- servidor (EVENT_CHAMPION_PURCHASE_RESULT) antes de contarlas como
-- ranuradas. Antes se contaban en el momento de enviar la peticion, sin saber
-- si el servidor la habia aceptado; con el cooldown de por medio, un fallo
-- silencioso ahi habria informado "ranuradas" sin que lo estuvieran de
-- verdad.
--
-- CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN / _IN_COMBAT se tratan como
-- transitorios: se reintenta una vez, esperando a que vuelva a cumplirse la
-- condicion. Cualquier otro resultado de fallo (disciplina equivocada,
-- estrella no comprada, CP desactivado en esta zona...) no es transitorio:
-- reintentar la misma peticion fallaria igual, asi que se cuenta como
-- omitida en vez de como ranurada.
local function SendAndVerifyCp(diffs, state, attempt, onReport)
    if #diffs == 0 then
        if onReport then onReport(state) end
        return
    end

    -- Si de verdad faltara alguna de estas, el kit NO esta vacio: no se puede
    -- enviar. Informar "empty" aqui daba el mensaje "el kit no tiene nada que
    -- ranurar", que es falso y mando la investigacion al sitio equivocado
    -- (a mirar el kit, que estaba perfecto). Ahora se distingue y se registra
    -- cual falta, para no volver a quedarse a ciegas.
    if type(PrepareChampionPurchaseRequest) ~= "function"
        or type(AddHotbarSlotToChampionPurchaseRequest) ~= "function"
        or type(SendChampionPurchaseRequest) ~= "function"
        or not HasEventManager() or EVENT_CHAMPION_PURCHASE_RESULT == nil then
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "CP unavailable: prepare=%s add=%s send=%s eventManager=%s resultEvent=%s",
                type(PrepareChampionPurchaseRequest),
                type(AddHotbarSlotToChampionPurchaseRequest),
                type(SendChampionPurchaseRequest),
                type(EVENT_MANAGER),
                tostring(EVENT_CHAMPION_PURCHASE_RESULT)))
        end
        if onReport then onReport({ error = "cpUnavailable" }) end
        return
    end

    PrepareChampionPurchaseRequest()
    for _, diff in ipairs(diffs) do
        AddHotbarSlotToChampionPurchaseRequest(diff.slot, diff.starId)
    end

    cpRequestCounter = cpRequestCounter + 1
    local eventNamespace = "EZOArmory_CPResult_" .. tostring(cpRequestCounter)
    local settled = false

    local function Settle(result)
        if settled then return end
        settled = true
        EVENT_MANAGER:UnregisterForEvent(eventNamespace, EVENT_CHAMPION_PURCHASE_RESULT)

        -- El resultado numerico del servidor es la unica pista fiable de por
        -- que una peticion no ha surtido efecto, y hasta ahora no quedaba
        -- registrado en ningun sitio: si no era exito, se contaba como omitida
        -- y se perdia el motivo.
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "CP result: attempt=%d diffs=%d result=%s (success=%s cooldown=%s inCombat=%s)",
                attempt, #diffs, tostring(result),
                tostring(CHAMPION_PURCHASE_SUCCESS),
                tostring(CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN),
                tostring(CHAMPION_PURCHASE_IN_COMBAT)))
        end

        if result == CHAMPION_PURCHASE_SUCCESS then
            state.slotted = state.slotted + #diffs
            if onReport then onReport(state) end
            return
        end

        local transient = result == CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN
            or result == CHAMPION_PURCHASE_IN_COMBAT

        -- attempt cuenta intentos ya hechos (1 = el primer envio, no un
        -- reintento). "<=" y no "<": con MAX_CP_RETRIES=1 debe reintentar
        -- tras el primer fallo (1 <= 1) y parar tras el segundo (2 <= 1 es
        -- falso), es decir, 1 reintento real = 2 intentos en total.
        if transient and attempt <= MAX_CP_RETRIES then
            if result == CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN then
                -- El servidor dice que aun hay cooldown aunque nuestro
                -- contador local ya hubiera llegado a 0: se resincroniza con
                -- la realidad en vez de reintentar de inmediato otra vez.
                cpCooldownRemaining = 31
            end
            local retryTask = LibAsync:Create("EZOArmory_EquipCp_Retry")
            retryTask:WaitUntil(function()
                return Equip.IsReady() and Equip.IsCpReady()
            end):Then(function()
                SendAndVerifyCp(diffs, state, attempt + 1, onReport)
            end)
            return
        end

        -- Fallo no transitorio, o reintentos agotados: se cuentan como
        -- omitidas para que el informe no diga "ranuradas" sin serlo.
        for _, diff in ipairs(diffs) do
            state.skipped = state.skipped + 1
            local okName, name = pcall(GetChampionSkillName, diff.starId)
            state.skippedNames[#state.skippedNames + 1] =
                (okName and name and name ~= "") and zo_strformat("<<C:1>>", name) or tostring(diff.starId)
        end
        if onReport then onReport(state) end
    end

    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
        Settle(result)
    end)
    SendChampionPurchaseRequest()

    -- Salvaguarda: si por lo que sea el evento nunca llega (desconexion,
    -- caso raro no contemplado), el informe no se queda colgado para
    -- siempre esperando.
    zo_callLater(function()
        if not settled then
            Settle(CHAMPION_PURCHASE_INTERNAL_ERROR)
        end
    end, 8000)
end

-- Aplica un kit de CP. onReport(state) al terminar.
-- state al terminar: { slotted, already, skipped, skippedNames }
-- state de error: { error = "noLibAsync" | "empty" }
function Equip.ApplyCpKit(kitId, onReport)
    if not Equip.IsAvailable() then
        if onReport then onReport({ error = "noLibAsync" }) end
        return false
    end
    local kit = EZOArmory.Champion and EZOArmory.Champion.GetKit(kitId)
    if not kit or not kit.stars then
        if onReport then onReport({ error = "empty" }) end
        return false
    end
    if HOTBAR_CATEGORY_CHAMPION == nil or type(GetSlotBoundId) ~= "function" then
        if onReport then onReport({ error = "empty" }) end
        return false
    end

    EnsureCpCooldownTracking()

    local queuedReason
    if not Equip.IsReady() then
        queuedReason = "combat"
    elseif not Equip.IsCpReady() then
        queuedReason = "cpCooldown"
    end

    local state = {
        slotted = 0,
        already = 0,
        skipped = 0,
        skippedNames = {},
        queued = queuedReason ~= nil,
    }

    if state.queued then
        NotifyQueued(queuedReason)
    end

    local task = LibAsync:Create("EZOArmory_EquipCp")
    task:WaitUntil(function()
        return Equip.IsReady() and Equip.IsCpReady()
    end):Then(function()
        local diffs = {}
        for slot = EZOArmory.Champion.SLOT_FIRST, EZOArmory.Champion.SLOT_LAST do
            local starId = tonumber(kit.stars[slot]) or 0
            if starId ~= 0 then
                local okCurrent, current = pcall(GetSlotBoundId, slot, HOTBAR_CATEGORY_CHAMPION)
                current = (okCurrent and tonumber(current)) or 0

                if current == starId then
                    state.already = state.already + 1
                else
                    local slottable = type(GetChampionSkillType) == "function"
                        and type(CanChampionSkillTypeBeSlotted) == "function"
                        and CanChampionSkillTypeBeSlotted(GetChampionSkillType(starId)) == true
                    local spent = type(GetNumPointsSpentOnChampionSkill) == "function"
                        and (tonumber(GetNumPointsSpentOnChampionSkill(starId)) or 0) > 0

                    if slottable and spent then
                        diffs[#diffs + 1] = { slot = slot, starId = starId }
                        -- Cada grupo de slots pertenece a una disciplina y el
                        -- servidor rechaza la peticion ENTERA con
                        -- CHAMPION_PURCHASE_CHAMPION_BAR_WRONG_DISCIPLINE si
                        -- una sola estrella no encaja. Se registra la
                        -- disciplina de la estrella que entra y la de la que
                        -- ocupa ahora ese slot: si no coinciden, ese es el
                        -- motivo de que no se aplique nada.
                        if EZOArmory.DebugLog and EZOArmory.Champion.GetStarDisciplineType then
                            EZOArmory.DebugLog(string.format(
                                "CP diff: slot=%d star=%d disc=%s currentStar=%d currentDisc=%s",
                                slot, starId,
                                tostring(EZOArmory.Champion.GetStarDisciplineType(starId)),
                                current,
                                tostring(current ~= 0
                                    and EZOArmory.Champion.GetStarDisciplineType(current) or nil)))
                        end
                    else
                        state.skipped = state.skipped + 1
                        local okName, name = pcall(GetChampionSkillName, starId)
                        state.skippedNames[#state.skippedNames + 1] =
                            (okName and name and name ~= "") and zo_strformat("<<C:1>>", name)
                            or tostring(starId)
                        if EZOArmory.DebugLog then
                            EZOArmory.DebugLog(string.format(
                                "CP skip: slot=%d star=%d slottable=%s spent=%s",
                                slot, starId, tostring(slottable), tostring(spent)))
                        end
                    end
                end
            end
        end

        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "CP apply: kit=%s diffs=%d already=%d skipped=%d cooldown=%d",
                tostring(kitId), #diffs, state.already, state.skipped, cpCooldownRemaining))
        end

        SendAndVerifyCp(diffs, state, 1, onReport)
    end)

    return true
end
