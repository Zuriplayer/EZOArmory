-- Capa sencilla para elegir idioma sin complicar el addon.
EZOArmory_Lang = EZOArmory_Lang or {}

local function ApplyString(id, value, version)
    local stringId = _G[id]
    if stringId == nil then
        ZO_CreateStringId(id, value)
        stringId = _G[id]
    end

    if stringId ~= nil then
        SafeAddString(stringId, value, version)
    end
end

function EZOArmory_Lang.Apply(language)
    local effectiveLanguage = language
    if EZOArmory and type(EZOArmory.GetEffectiveLanguage) == "function" then
        effectiveLanguage = EZOArmory.GetEffectiveLanguage(language)
    end

    local source = (effectiveLanguage == "es" and EZOARMORY_STRINGS_ES) or EZOARMORY_STRINGS_EN
    if not source then return end

    EZOArmory_Lang._stringVersion = (tonumber(EZOArmory_Lang._stringVersion) or 0) + 1
    for key, value in pairs(source) do
        ApplyString(key, value, EZOArmory_Lang._stringVersion)
    end

    EZOArmory_Lang.current = (effectiveLanguage == "es") and "es" or "en"
    EZOArmory_Lang.configured = tostring(language or "auto")
end
