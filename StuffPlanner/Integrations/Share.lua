-- CONTRAT
-- Partage des confirmations de quête (protocole : Engine/Sync.lua) en guilde et en groupe, par AceComm-3.0
-- (ChatThrottleLib, priorité "BULK"). Option share.enabled, coupée par défaut : rien n'est envoyé ni lu.
-- Envoi : confirmations locales seulement (jamais celles reçues), regroupées FLUSH_DELAY s ; jamais en combat
--   ni sous restriction de messages (Compat.ChatRestricted) : reporté. À l'activation, à SP_DATA_READY et à
--   GROUP_JOINED : les ANNOUNCE dernières confirmations du collecteur, une fois par canal et par COOLDOWN s ;
--   annonce bloquée : un seul report en attente (canaux fusionnés, ou tous si l'un des appels n'en précise pas).
-- Réception : messages des autres joueurs ; Sync.decode (message entier rejeté et compté), dédoublonné ;
--   Data.observe kind "peer" (sous toute observation locale) ; un SP_QUEST_OBSERVED par message qui change
--   une quête. Reçu en combat : gardé (MAX_INBOX messages, les suivants perdus) et traité après.
--   ns.Share.PREFIX -> "StuffPlanner" ; FLUSH_DELAY 30 ; ANNOUNCE 20 ; COOLDOWN 600 ; MAX_INBOX 20
--   ns.Share.setTransport(t) : t.send(prefix, message, channel), t.after(seconds, fn), t.now() -> secondes
--   ns.Share.channels() -> {"GUILD"?, Compat.GroupChannel()?}
--   ns.Share.queue(record) -> bool : vrai si mise en file (option active, Sync.entry valide, jamais envoyée)
--   ns.Share.flush() -> messages envoyés ; ns.Share.announce(channels?) -> messages envoyés
--   ns.Share.receive(message, channel, sender) -> quêtes changées
--   ns.Share.stats() -> {sent, received, rejected, applied} (copie)

local _, ns = ...

local Share = {}
ns.Share = Share

Share.PREFIX = "StuffPlanner"
Share.FLUSH_DELAY = 30
Share.ANNOUNCE = 20
Share.COOLDOWN = 600
Share.MAX_INBOX = 20

local Sync = ns.Sync
local transport
local pending, sentSeen, receivedSeen, inbox, lastAnnounce, counters, flushScheduled
-- Annonce reportée (combat, restriction) : un seul report, canaux fusionnés ; all = tous les canaux du moment.
local wanted

local function reset()
    pending, inbox, lastAnnounce = {}, {}, {}
    sentSeen, receivedSeen = Sync.newSeen(), Sync.newSeen()
    counters = { sent = 0, received = 0, rejected = 0, applied = 0 }
    flushScheduled, wanted = false, nil
end
reset()

function Share.setTransport(t)
    transport = t
    reset()
end

local function enabled()
    return ns.Options.get("share.enabled") == true
end

local function blocked()
    return InCombatLockdown() or ns.Compat.ChatRestricted()
end

local function playerName()
    return UnitName("player")
end

local function isSelf(sender)
    return type(sender) ~= "string" or sender:match("^[^%-]+") == playerName()
end

function Share.channels()
    local list = {}
    if ns.Compat.InGuild() then
        list[#list + 1] = "GUILD"
    end
    list[#list + 1] = ns.Compat.GroupChannel()
    return list
end

local function send(entries, channels)
    local count = 0
    for _, message in ipairs(Sync.encode(entries)) do
        for _, channel in ipairs(channels) do
            transport.send(Share.PREFIX, message, channel)
            count = count + 1
        end
    end
    counters.sent = counters.sent + count
    return count
end

local function retryLater(fn)
    if InCombatLockdown() then
        ns:RunOutOfCombat(fn)
    else
        transport.after(Share.FLUSH_DELAY, fn)
    end
end

function Share.flush()
    flushScheduled = false
    if not (transport and enabled()) then
        pending = {}
        return 0
    end
    if #pending == 0 then
        return 0
    end
    if blocked() then
        flushScheduled = true
        retryLater(Share.flush)
        return 0
    end
    local entries = pending
    pending = {}
    return send(entries, Share.channels())
end

function Share.queue(record)
    if not (transport and enabled()) then
        return false
    end
    local entry = Sync.entry(record)
    if not (entry and Sync.fresh(sentSeen, entry)) then
        return false
    end
    pending[#pending + 1] = entry
    if not flushScheduled then
        flushScheduled = true
        transport.after(Share.FLUSH_DELAY, Share.flush)
    end
    return true
end

local function recentEntries()
    local records = ns.Collector and ns.Collector.records() or {}
    local entries, seen = {}, Sync.newSeen()
    for i = #records, 1, -1 do
        local entry = Sync.entry(records[i])
        if entry and Sync.fresh(seen, entry) then
            table.insert(entries, 1, entry)
            if #entries >= Share.ANNOUNCE then
                break
            end
        end
    end
    return entries
end

local function announceLater()
    local request = wanted
    wanted = nil
    local channels
    if not request.all then
        channels = {}
        for channel in pairs(request.channels) do
            channels[#channels + 1] = channel
        end
        table.sort(channels)
    end
    Share.announce(channels)
end

local function deferAnnounce(channels)
    local first = wanted == nil
    wanted = wanted or { channels = {} }
    if channels then
        for _, channel in ipairs(channels) do
            wanted.channels[channel] = true
        end
    else
        wanted.all = true
    end
    if first then
        retryLater(announceLater)
    end
end

function Share.announce(channels)
    if not (transport and enabled()) then
        return 0
    end
    if blocked() then
        deferAnnounce(channels)
        return 0
    end
    local now, due = transport.now(), {}
    for _, channel in ipairs(channels or Share.channels()) do
        local last = lastAnnounce[channel]
        if not last or now - last >= Share.COOLDOWN then
            due[#due + 1] = channel
        end
    end
    local entries = recentEntries()
    if #due == 0 or #entries == 0 then
        return 0
    end
    for _, channel in ipairs(due) do
        lastAnnounce[channel] = now
    end
    for _, entry in ipairs(entries) do
        Sync.fresh(sentSeen, entry)
    end
    return send(entries, due)
end

local function apply(message)
    local entries = Sync.decode(message)
    if not entries then
        counters.rejected = counters.rejected + 1
        return 0
    end
    local changed, lastID = 0, nil
    for _, entry in ipairs(Sync.dedup(entries, receivedSeen)) do
        if ns.Data.observe({ kind = "peer", questID = entry.questID, level = entry.level, mapID = entry.mapID,
            rewards = entry.rewards, choices = entry.choices, npcID = entry.npcID, x = entry.x, y = entry.y }) then
            changed, lastID = changed + 1, entry.questID
        end
    end
    counters.applied = counters.applied + changed
    if lastID then
        ns:Send("SP_QUEST_OBSERVED", lastID)
    end
    return changed
end

local function drainInbox()
    local queue = inbox
    inbox = {}
    for _, message in ipairs(queue) do
        apply(message)
    end
end

function Share.receive(message, channel, sender) -- luacheck: ignore 212/channel
    if not enabled() or isSelf(sender) or not (ns.Data and ns.Data.ready()) then
        return 0
    end
    counters.received = counters.received + 1
    if InCombatLockdown() then
        if #inbox < Share.MAX_INBOX then
            inbox[#inbox + 1] = message
            if #inbox == 1 then
                ns:RunOutOfCombat(drainInbox)
            end
        end
        return 0
    end
    return apply(message)
end

function Share.stats()
    return { sent = counters.sent, received = counters.received, rejected = counters.rejected,
        applied = counters.applied }
end

-- Branchement en jeu : AceComm-3.0 (absent des tests, qui passent leur transport).
local AceComm = LibStub and LibStub("AceComm-3.0", true)
if not (AceComm and ns.NewModule) then
    return
end

local module = ns:NewModule("Share", "AceEvent-3.0")
AceComm:Embed(module)

function module:OnEnable()
    Share.setTransport({
        send = function(prefix, message, channel)
            module:SendCommMessage(prefix, message, channel, nil, "BULK")
        end,
        after = C_Timer.After,
        now = GetTime,
    })
    self:RegisterComm(Share.PREFIX, function(_, message, channel, sender)
        Share.receive(message, channel, sender)
    end)
    self:RegisterEvent("GROUP_JOINED", function()
        local group = ns.Compat.GroupChannel()
        if group then
            Share.announce({ group })
        end
    end)
end

ns:On("SP_DATA_READY", function()
    Share.announce()
end)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key == "share.enabled" and value then
        Share.announce()
    end
end)
