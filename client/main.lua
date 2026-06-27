local VORPCore = exports.vorp_core:GetCore()

Lang = {}
local phrases = Locales[Config.Language] or Locales['en'] or {}

function Lang:t(key, ...)
    local phrase = phrases[key]
    if phrase then
        return string.format(phrase, ...)
    end
    return key
end

print('devchacha-weed Loaded')
