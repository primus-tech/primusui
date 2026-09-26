--[[
    PrimusUI Module: PUITalk (Core State, Cache & String Utilities)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Shared module state and database namespace registration.
    - Player class caching and class color string formatting.
    - Chat cleaning, timestamp generation, channel coloring, and URL linkification.
    - Unread state tracking, conversation management, and roster lookup for tab-completion.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUITalk = Primus.PUITalk or {}
Primus.PUITalk = PUITalk
_G.PUITalk = PUITalk
Primus:RegisterModule("PUITalk", PUITalk, "Social")

local DB     = Primus.DB
local Utils  = Primus.Utils

-- Database Namespace
PUITalk.db = DB:RegisterNamespace("PUITalk", {
    enabled          = true,
    divertWhispers   = true,   -- Suppresses whispers from main chat log and routes to Tab 2
    autoPopDMs       = false,  -- Automatically switch to Tab 2 on incoming whisper
    playSounds       = true,   -- Sound alerts on incoming direct messages
    classColors      = true,   -- Class colored player names
    stickyChannels   = true,   -- Sticky chat channels across /say, /guild, /party, /raid
    mousewheelScroll = true,   -- Mousewheel fast scrolling on chat frames
    chatCopy         = true,   -- In-place selection and clipboard copy tools
    activeMasterTab  = 1,      -- 1: Chat, 2: Messages, 3: Social
    activeSocialTab  = "friends", -- "friends" or "guild"
    width            = 450,
    height           = 230,
    channels         = {
        SAY          = true,
        YELL         = true,
        EMOTE        = true,
        PARTY        = true,
        RAID         = true,
        GUILD        = true,
        OFFICER      = true,
        GENERAL      = true,
        TRADE        = true,
        LOCALDEFENSE = true,
        LFG          = true,
        WORLD        = true,
        SYSTEM       = true,
        MONSTER      = true,
        LOOT         = true,
    },
})

function PUITalk:IsChannelEnabled(chanKey)
    local ch = self.db:Get("channels")
    if not ch then return true end
    if ch[chanKey] == nil then return true end
    return ch[chanKey]
end

function PUITalk:SetChannelEnabled(chanKey, enabled)
    local ch = self.db:Get("channels") or {}
    ch[chanKey] = enabled
    self.db:Set("channels", ch)
end

-- Shared State
PUITalk.playerClassCache     = {}
PUITalk.chatBuffers          = {}
PUITalk.dmTabs               = {}
PUITalk.activeDMKey          = nil
PUITalk.conversationHistory   = {}
PUITalk.unreadCounts         = {}
PUITalk.lastWhisperSender    = nil
PUITalk.friendRows           = {}
PUITalk.guildRows            = {}
PUITalk.copyButtons          = {}

for i = 1, 7 do
    PUITalk.chatBuffers[i] = {}
end

-- =========================================================================
-- UNREAD STATE MANAGEMENT & ROSTER HELPERS
-- =========================================================================

function PUITalk:GetTotalUnreadCount()
    local total = 0
    for k, count in pairs(self.unreadCounts) do
        if count and count > 0 then
            total = total + count
        end
    end
    return total
end

function PUITalk:GetUnreadCount(key)
    if not key then return 0 end
    return self.unreadCounts[string.lower(key)] or 0
end

function PUITalk:IncrementUnread(key)
    if not key then return end
    key = string.lower(key)
    self.unreadCounts[key] = (self.unreadCounts[key] or 0) + 1
    if self.dmTabs[key] then
        self.dmTabs[key].unread = self.unreadCounts[key]
    end
end

function PUITalk:MarkAsRead(key)
    if not key then return end
    key = string.lower(key)
    self.unreadCounts[key] = 0
    if self.dmTabs[key] then
        self.dmTabs[key].unread = 0
    end
end

function PUITalk:ClearDMHistory(key)
    if not key then return end
    key = string.lower(key)
    self.conversationHistory[key] = {}
    if self.masterFrame and self.masterFrame.viewMessages and (self.activeDMKey == key) then
        self.masterFrame.viewMessages.msgFrame:Clear()
    end
end

function PUITalk:CloseDMConversation(key)
    if not key then return end
    key = string.lower(key)
    self:MarkAsRead(key)
    if self.dmTabs[key] then
        if self.dmTabs[key].button then
            self.dmTabs[key].button:Hide()
            self.dmTabs[key].button = nil
        end
        self.dmTabs[key] = nil
    end

    if self.activeDMKey == key then
        self.activeDMKey = nil
        for nextKey, _ in pairs(self.dmTabs) do
            self:SelectDMTab(nextKey)
            return
        end
        if self.masterFrame and self.masterFrame.viewMessages then
            self.masterFrame.viewMessages.msgFrame:Clear()
        end
    end
    self:RefreshDMTabs()
end

function PUITalk:GetRosterNames()
    local names = {}
    local seen = {}

    local function add(n)
        if n and n ~= "" and not seen[n] then
            seen[n] = true
            table.insert(names, n)
        end
    end

    -- Friends
    local numFriends = GetNumFriends()
    for i = 1, numFriends do
        local n, _, _, _, connected = GetFriendInfo(i)
        if connected and n then add(n) end
    end

    -- Guild
    if IsInGuild() then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local n, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and n then add(n) end
        end
    end

    -- Party / Raid
    for i = 1, 4 do
        if UnitExists("party" .. i) then add(UnitName("party" .. i)) end
    end
    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
        if UnitExists("raid" .. i) then add(UnitName("raid" .. i)) end
    end

    return names
end

-- =========================================================================
-- CLASS COLORING & STRING UTILITIES
-- =========================================================================

local function CacheUnitClass(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and class then
        PUITalk.playerClassCache[name] = class
    end
end

function PUITalk:UpdateClassCache()
    CacheUnitClass("player")
    CacheUnitClass("target")

    for i = 1, 4 do
        CacheUnitClass("party" .. i)
    end

    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
        CacheUnitClass("raid" .. i)
    end

    if IsInGuild() then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local name, _, _, _, class = GetGuildRosterInfo(i)
            if name and class then
                PUITalk.playerClassCache[name] = class
            end
        end
    end

    local numFriends = GetNumFriends()
    for i = 1, numFriends do
        local name, _, class = GetFriendInfo(i)
        if name and class then
            PUITalk.playerClassCache[name] = class
        end
    end
end

function PUITalk:GetColoredName(name)
    if not name or not self.db:Get("classColors") then return name end
    local class = self.playerClassCache[name]
    if class then
        local r, g, b = Utils.GetClassColor(class)
        local hex = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
        return string.format("|cff%s%s|r", hex, name)
    end
    return name
end

function PUITalk:CleanChatText(str)
    if not str then return "" end
    str = string.gsub(str, "|H.-|h(.-)|h", "%1")
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    return str
end

function PUITalk:LinkifyURLs(text)
    if not text then return text end
    local patterns = {
        "(https?://%S+)",
        "(www%.%S+)",
        "(discord%.gg/%S+)",
        "(github%.com/%S+)",
    }
    for _, pat in ipairs(patterns) do
        text = string.gsub(text, pat, "|cff69ccf0|Hurl:%1|h[%1]|h|r")
    end
    return text
end

function PUITalk:GetTimestamp()
    local hour, minute = GetGameTime()
    return string.format("[%02d:%02d]", hour, minute)
end

-- Channel Default Colors (RGB)
PUITalk.CHANNEL_COLORS = {
    ["SAY"]          = { r = 1.00, g = 1.00, b = 1.00 },
    ["YELL"]         = { r = 1.00, g = 0.25, b = 0.25 },
    ["EMOTE"]        = { r = 1.00, g = 0.50, b = 0.25 },
    ["PARTY"]        = { r = 0.67, g = 0.67, b = 1.00 },
    ["RAID"]         = { r = 1.00, g = 0.50, b = 0.00 },
    ["RAID_WARNING"] = { r = 1.00, g = 0.28, b = 0.00 },
    ["GUILD"]        = { r = 0.25, g = 1.00, b = 0.25 },
    ["OFFICER"]      = { r = 0.25, g = 0.75, b = 0.25 },
    ["WHISPER"]      = { r = 1.00, g = 0.50, b = 1.00 },
    ["SYSTEM"]       = { r = 1.00, g = 1.00, b = 0.00 },
    ["CHANNEL"]      = { r = 0.90, g = 0.75, b = 0.60 },
    ["MONSTER"]      = { r = 1.00, g = 0.85, b = 0.40 },
    ["LOOT"]         = { r = 0.00, g = 0.67, b = 0.00 },
}

function PUITalk:GetChannelColor(chanType)
    local col = self.CHANNEL_COLORS[chanType]
    if col then return col.r, col.g, col.b end
    return 1.0, 1.0, 1.0
end
