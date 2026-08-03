-- Salida tecnica opcional; el chat queda para mensajes funcionales cortos.
local ADDON_NAME = "EZOArmory"

local logger
local loggerUnavailable = false

local function GetLogger()
    if loggerUnavailable then
        return nil
    end

    if logger then
        return logger
    end

    local lib = _G.LibDebugLogger
    if type(lib) ~= "function" and type(lib) ~= "table" then
        loggerUnavailable = true
        return nil
    end

    local ok, created = false, nil
    if type(lib) == "function" then
        ok, created = pcall(lib, ADDON_NAME)
    end
    if (not ok or created == nil) and type(lib) == "table" and type(lib.Create) == "function" then
        ok, created = pcall(function()
            return lib:Create(ADDON_NAME)
        end)
    end

    if ok and created then
        logger = created
        loggerUnavailable = false
        return logger
    end

    loggerUnavailable = true
    return nil
end

function EZOArmory.DebugLog(message)
    if not EZOArmory.sv or not EZOArmory.sv.general or EZOArmory.sv.general.debugMode ~= true then
        return
    end

    local log = GetLogger()
    if log and type(log.Debug) == "function" then
        pcall(function()
            log:Debug(tostring(message))
        end)
    end
end

function EZOArmory.GetDebugLogger()
    return GetLogger()
end

-- Volcado de geometria de un control: nombre, si acepta raton y su rectangulo
-- en pantalla. Sirve para diagnosticar por que un control no recibe el cursor
-- sin poder ejecutar el juego: se lee luego del SavedVariables de
-- LibDebugLogger. No hace nada con el modo depuracion apagado.
function EZOArmory.DebugDumpControl(label, control)
    if not control then
        EZOArmory.DebugLog(tostring(label) .. ": nil")
        return
    end
    local ok, info = pcall(function()
        local left, top, right, bottom = control:GetScreenRect()
        return string.format(
            "%s: mouse=%s hidden=%s rect=%d,%d %dx%d",
            tostring(label),
            tostring(control.IsMouseEnabled and control:IsMouseEnabled()),
            tostring(control.IsHidden and control:IsHidden()),
            left or -1, top or -1, (right or 0) - (left or 0), (bottom or 0) - (top or 0))
    end)
    EZOArmory.DebugLog(ok and info or (tostring(label) .. ": <error>"))
end
