-- Menu contextual del inventario para guardar/sacar builds del banco.
--
-- LibCustomMenu es una dependencia EXTERNA y OPCIONAL. La norma de la familia
-- EZO solo tenia autorizada LibAsync como excepcion; esta segunda excepcion la
-- pidio Ricardo expresamente al elegir el menu contextual como interfaz. Se
-- declara como OptionalDependsOn, no como DependsOn: sin la libreria el resto
-- del addon funciona igual, solo se pierde el menu (y EZOArmory.Storage sigue
-- siendo accesible por codigo).
--
-- La libreria es de dominio publico (Unlicense), asi que no hay problema de
-- licencia al depender de ella.

EZOArmory = EZOArmory or {}
EZOArmory.StorageMenu = EZOArmory.StorageMenu or {}

local StorageMenu = EZOArmory.StorageMenu
local registered = false

local function Report(state, isWithdraw)
    if not EZOArmory.Print then return end

    if state.error == "noBank" then
        EZOArmory.Print(GetString(EZOARM_MSG_STORAGE_NO_BANK))
        return
    end

    EZOArmory.Print(zo_strformat(
        GetString(isWithdraw and EZOARM_MSG_STORAGE_WITHDRAWN or EZOARM_MSG_STORAGE_DEPOSITED),
        state.moved))

    -- Lo equipado no se mueve nunca (decision de alcance), pero hay que
    -- decirlo o parecera que faltan piezas por guardar.
    if state.worn > 0 then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_STORAGE_WORN), table.concat(state.wornNames, ", ")))
    end
    if state.missing > 0 then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_STORAGE_MISSING), table.concat(state.missingNames, ", ")))
    end
    if state.noSpace > 0 then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_STORAGE_NO_SPACE), table.concat(state.noSpaceNames, ", ")))
    end
    if state.failed > 0 then
        EZOArmory.Print(zo_strformat(
            GetString(EZOARM_MSG_STORAGE_FAILED), table.concat(state.failedNames, ", ")))
    end
    if state.aborted then
        EZOArmory.Print(GetString(EZOARM_MSG_STORAGE_ABORTED))
    end
end

-- Entradas de submenu, una por build. Se construyen en el momento de abrir el
-- menu para que refleje las builds actuales.
local function BuildEntries(isWithdraw)
    local entries = {}
    for _, build in ipairs(EZOArmory.Builds.ListBuilds()) do
        local buildId = build.id
        entries[#entries + 1] = {
            label = tostring(build.name),
            callback = function()
                if isWithdraw then
                    EZOArmory.Storage.Withdraw(buildId, function(state) Report(state, true) end)
                else
                    EZOArmory.Storage.Deposit(buildId, function(state) Report(state, false) end)
                end
            end,
        }
    end
    return entries
end

function StorageMenu.Init()
    if registered then return end

    -- Cada motivo de rendirse se registra: sin esto, "no aparece el menu" no
    -- distingue entre libreria ausente, libreria vieja que el juego no carga,
    -- o que el registro si ocurrio y el problema esta en otro sitio.
    local libKind = type(LibCustomMenu)
    if libKind ~= "table" or type(LibCustomMenu.RegisterContextMenu) ~= "function" then
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "StorageMenu: LibCustomMenu no disponible (type=%s). "
                .. "Suele ser que el juego no la carga por APIVersion vieja: "
                .. "activa 'permitir addons desactualizados'.", libKind))
        end
        return
    end
    if type(AddCustomSubMenuItem) ~= "function" then
        if EZOArmory.DebugLog then
            EZOArmory.DebugLog("StorageMenu: falta AddCustomSubMenuItem")
        end
        return
    end

    registered = true
    if EZOArmory.DebugLog then
        EZOArmory.DebugLog("StorageMenu: menu contextual registrado")
    end

    LibCustomMenu:RegisterContextMenu(function()
        -- Solo tiene sentido con el banco o un baul abierto: fuera de ahi el
        -- movimiento es imposible y las entradas solo estorbarian.
        local bankOpen = type(IsBankOpen) == "function" and IsBankOpen()
        local builds = (EZOArmory.Builds and EZOArmory.Storage)
            and #EZOArmory.Builds.ListBuilds() or -1

        if EZOArmory.DebugLog then
            EZOArmory.DebugLog(string.format(
                "StorageMenu: clic derecho, bankOpen=%s builds=%d",
                tostring(bankOpen), builds))
        end

        if not bankOpen then return end
        if builds <= 0 then return end

        AddCustomSubMenuItem(GetString(EZOARM_MENU_WITHDRAW_BUILD), BuildEntries(true))
        AddCustomSubMenuItem(GetString(EZOARM_MENU_DEPOSIT_BUILD), BuildEntries(false))
    end, LibCustomMenu.CATEGORY_SECONDARY)
end
