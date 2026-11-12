-- CONTRAT
-- Canaux de messages d'addon (guilde, groupe) et restrictions d'envoi. Détection par fonctionnalité,
-- à chaque appel ; sans l'API : réponse prudente, jamais d'erreur. Charger après Compat.lua.
--   ns.Compat.ChatRestricted() -> bool : vrai si l'envoi de messages d'addon est interdit maintenant
--     (C_ChatInfo.InChatMessagingLockdown, AreOutgoingAddonChatMessagesRestricted : Forever, API 12.x)
--   ns.Compat.InGuild() -> bool
--   ns.Compat.GroupChannel() -> "INSTANCE_CHAT" | "RAID" | "PARTY" | nil (pas de groupe)

local _, ns = ...

local Compat = ns.Compat

local function call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, ...)
    return ok and value or nil
end

function Compat.ChatRestricted()
    local chat = C_ChatInfo
    if not chat then
        return false
    end
    return call(chat.InChatMessagingLockdown) == true or call(chat.AreOutgoingAddonChatMessagesRestricted) == true
end

function Compat.InGuild()
    return call(IsInGuild) == true
end

function Compat.GroupChannel()
    local instance = LE_PARTY_CATEGORY_INSTANCE
    if instance and call(IsInGroup, instance) then
        return "INSTANCE_CHAT"
    end
    if call(IsInRaid) then
        return "RAID"
    end
    if call(IsInGroup) then
        return "PARTY"
    end
    return nil
end
