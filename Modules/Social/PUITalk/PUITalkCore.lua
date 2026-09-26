--[[
    PrimusUI Module: PUITalk (Core State, Cache & String Utilities)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Shared module state, database namespace registration, and backwards-compatibility aliases.
    - Player class caching and class color string formatting.
    - Chat cleaning, timestamp generation, and URL linkification.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUITalk = Primus.PUITalk or {}
Primus.PUITalk = PUITalk
_G.PUITalk = PUITalk
Primus:RegisterModule("PUITalk", PUITalk, "Social")

-- Backwards compatibility aliases for existing module references
Primus.PUIChat = PUITalk
_G.PUIChat = PUITalk
Primus.PUIMessenger = PUITalk
_G.PUIMessenger = PUITalk

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
    chatCopy         = true,   -- Docked [C] button on chat frames for quick copy
    activeMasterTab  = 1,      -- 1: Chat, 2: Messages, 3: Social
    activeSocialTab  = "friends", -- "friends" or "guild"
    width            = 450,
    height           = 230,
})

-- Shared State
PUITalk.playerClassCache   = {}
PUITalk.chatBuffers        = {}
PUITalk.dmTabs             = {}
PUITalk.activeDMKey        = nil
PUITalk.conversationHistory = {}
PUITalk.lastWhisperSender  = nil
PUITalk.friendRows         = {}
PUITalk.guildRows          = {}
PUITalk.copyButtons        = {}

for i = 1, 7 do
    PUITalk.chatBuffers[i] = {}
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
