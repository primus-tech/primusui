--[[
    PrimusUI Module: PUITalk (Blizzard Chat Suppression & Chat Event Subscriptions)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Permanent suppression of default Blizzard chat frames (ChatFrame1..7, tabs, editbox).
    - DEFAULT_CHAT_FRAME.AddMessage hook capturing 100% of addon prints and engine notices.
    - Native chat event subscriptions with granular channel filtering.
    - Authoritative direct message event routing (CHAT_MSG_WHISPER, CHAT_MSG_WHISPER_INFORM).
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Events  = Primus.Events

-- =========================================================================
-- 1. BLIZZARD CHAT FRAME SUPPRESSION & ADDOUN ROUTING
-- =========================================================================

function PUITalk:SuppressBlizzardChat()
    if DEFAULT_CHAT_FRAME and not DEFAULT_CHAT_FRAME.primusPUITalkHooked then
        local origAddMessage = DEFAULT_CHAT_FRAME.AddMessage
        DEFAULT_CHAT_FRAME.AddMessage = function(self, text, r, g, b, id)
            if text then
                PUITalk:AddChatMessage(tostring(text), r, g, b)
            end
        end
        DEFAULT_CHAT_FRAME.primusPUITalkHooked = true
    end

    for i = 1, 7 do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:UnregisterAllEvents()
            cf:ClearAllPoints()
            cf:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
            cf:SetWidth(1)
            cf:SetHeight(1)
            cf:SetAlpha(0)
            cf:EnableMouse(false)
            cf:Hide()
        end

        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:UnregisterAllEvents()
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
            tab:SetAlpha(0)
            tab:EnableMouse(false)
            tab:Hide()
        end
    end

    if ChatFrameEditBox then
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
        ChatFrameEditBox:Hide()

        if not ChatFrameEditBox._primusPUITalkHooked then
            ChatFrameEditBox._primusPUITalkHooked = true
            local origInsert = ChatFrameEditBox.Insert
            ChatFrameEditBox.Insert = function(self, text)
                if PUITalk.FocusInput then
                    PUITalk:FocusInput("")
                end
                if PUITalk.masterFrame and PUITalk.masterFrame.editBox then
                    if PUITalk.masterFrame.editBox.Insert then
                        PUITalk.masterFrame.editBox:Insert(text)
                    else
                        local cur = PUITalk.masterFrame.editBox:GetText() or ""
                        PUITalk.masterFrame.editBox:SetText(cur .. text)
                    end
                    return
                end
                if origInsert then origInsert(self, text) end
            end

            local origIsVisible = ChatFrameEditBox.IsVisible
            ChatFrameEditBox.IsVisible = function(self)
                if PUITalk.IsInputFocused and PUITalk:IsInputFocused() then
                    return 1
                end
                if PUITalk.masterFrame and PUITalk.masterFrame.editBox and PUITalk.masterFrame.editBox.hasFocus then
                    return 1
                end
                if origIsVisible then return origIsVisible(self) end
                return nil
            end
        end
    end

    if not _G.Primus_Original_SetItemRef and SetItemRef then
        _G.Primus_Original_SetItemRef = SetItemRef
        SetItemRef = function(link, text, button)
            if link and string.sub(link, 1, 4) == "url:" then
                if PUITalk.ShowURLCopyPopup then
                    PUITalk:ShowURLCopyPopup(string.sub(link, 5))
                    return
                end
            end
            if _G.Primus_Original_SetItemRef then
                return _G.Primus_Original_SetItemRef(link, text, button)
            end
        end
    end

    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton.Show = function() end
    end
end

-- =========================================================================
-- 2. GAME CHAT EVENT DISPATCHERS
-- =========================================================================

function PUITalk:RegisterChatEvents()
    -- Say & Yell
    Events:Register("CHAT_MSG_SAY", "PUITalk_Chat", function(owner, event, msg, sender, lang)
        if not PUITalk:IsChannelEnabled("SAY") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffffffff[Say]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("SAY")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_YELL", "PUITalk_Chat", function(owner, event, msg, sender, lang)
        if not PUITalk:IsChannelEnabled("YELL") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4040[Yell]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("YELL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Emotes
    Events:Register("CHAT_MSG_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("EMOTE") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff8040[Emote]|r %s %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("EMOTE")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_TEXT_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("EMOTE") then return end
        local formatted = string.format("%s |cffff8040%s|r", PUITalk:GetTimestamp(), msg)
        local r, g, b = PUITalk:GetChannelColor("EMOTE")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Party & Raid
    Events:Register("CHAT_MSG_PARTY", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("PARTY") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffaaaaee[Party]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("PARTY")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("RAID") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff7f00[Raid]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID_LEADER", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("RAID") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4800[Raid Leader]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID_WARNING")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID_WARNING", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("RAID") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4800[Raid Warning]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID_WARNING")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Guild & Officer
    Events:Register("CHAT_MSG_GUILD", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("GUILD") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cff40ff40[Guild]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("GUILD")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_OFFICER", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("OFFICER") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cff40c040[Officer]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("OFFICER")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Standard & Custom Channels
    Events:Register("CHAT_MSG_CHANNEL", "PUITalk_Chat", function(owner, event, msg, sender, lang, channelName, target, afk, zoneID, channelNumber, channelNameBase)
        local cNum = tonumber(channelNumber) or 0
        local cName = channelNameBase or channelName or "Channel"
        local lowerName = string.lower(cName .. " " .. (channelName or ""))
        local filterKey = "WORLD"

        if cNum == 1 or string.find(lowerName, "general") then
            filterKey = "GENERAL"
        elseif cNum == 2 or string.find(lowerName, "trade") then
            filterKey = "TRADE"
        elseif cNum == 3 or string.find(lowerName, "defense") or string.find(lowerName, "localdefense") then
            filterKey = "LOCALDEFENSE"
        elseif cNum == 4 or string.find(lowerName, "lookingforgroup") or string.find(lowerName, "lfg") then
            filterKey = "LFG"
        end

        if not PUITalk:IsChannelEnabled(filterKey) then return end

        local colored = PUITalk:GetColoredName(sender)
        local chanBadge = string.format("[%s. %s]", tostring(cNum > 0 and cNum or ""), cName)
        local formatted = string.format("%s |cffe6c099%s|r [%s]: %s", PUITalk:GetTimestamp(), chanBadge, colored, msg)
        local r, g, b = PUITalk:GetChannelColor("CHANNEL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- System & Notices
    Events:Register("CHAT_MSG_SYSTEM", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)

    Events:Register("CHAT_MSG_CHANNEL_NOTICE", "PUITalk_Chat", function(owner, event, action, _, _, channelName)
        local formatted = string.format("%s |cff888888[%s]: %s|r", PUITalk:GetTimestamp(), channelName or "Channel", action or "")
        PUITalk:AddChatMessage(formatted, 0.6, 0.6, 0.6)
    end)

    -- Monster Emotes / Say / Yell
    Events:Register("CHAT_MSG_MONSTER_SAY", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffffd100[%s]:|r %s", PUITalk:GetTimestamp(), sender or "Monster", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.85, 0.4)
    end)

    Events:Register("CHAT_MSG_MONSTER_YELL", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffff4040[%s yells]:|r %s", PUITalk:GetTimestamp(), sender or "Monster", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.35, 0.35)
    end)

    Events:Register("CHAT_MSG_MONSTER_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffff8040%s %s|r", PUITalk:GetTimestamp(), sender or "", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.5, 0.25)
    end)

    -- Skills & Tradeskills
    Events:Register("CHAT_MSG_SKILL", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SKILL") then return end
        local formatted = string.format("%s |cff70b0ff%s|r", PUITalk:GetTimestamp(), msg)
        local r, g, b = PUITalk:GetChannelColor("SKILL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_SPELL_TRADESKILLS", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SKILL") then return end
        local formatted = string.format("%s |cff70b0ff%s|r", PUITalk:GetTimestamp(), msg)
        local r, g, b = PUITalk:GetChannelColor("SKILL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Combat Info: XP, Honor, Rep, Misc
    Events:Register("CHAT_MSG_COMBAT_XP_GAIN", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("COMBAT_INFO") then return end
        local formatted = string.format("%s |cff70b0ff%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.45, 0.70, 1.0)
    end)

    Events:Register("CHAT_MSG_COMBAT_HONOR_GAIN", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("COMBAT_INFO") then return end
        local formatted = string.format("%s |cffdfb8ff%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.87, 0.72, 1.0)
    end)

    Events:Register("CHAT_MSG_COMBAT_FACTION_CHANGE", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("COMBAT_INFO") then return end
        local formatted = string.format("%s |cff80d0ff%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.50, 0.80, 1.0)
    end)

    Events:Register("CHAT_MSG_COMBAT_MISC_INFO", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("COMBAT_INFO") then return end
        local formatted = string.format("%s |cffaaaaaa%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.65, 0.65, 0.65)
    end)

    -- Opening & Pet Notices
    Events:Register("CHAT_MSG_OPENING", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)

    Events:Register("CHAT_MSG_PET_INFO", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)

    -- Battlegrounds
    Events:Register("CHAT_MSG_BATTLEGROUND", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("RAID") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff7f00[BG]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_BATTLEGROUND_LEADER", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("RAID") then return end
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4800[BG Leader]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID_WARNING")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_BG_SYSTEM_NEUTRAL", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cffffd100[BG]:|r %s", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.85, 0.0)
    end)

    Events:Register("CHAT_MSG_BG_SYSTEM_ALLIANCE", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cff0070dd[Alliance]:|r %s", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.0, 0.44, 0.87)
    end)

    Events:Register("CHAT_MSG_BG_SYSTEM_HORDE", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("SYSTEM") then return end
        local formatted = string.format("%s |cffff2020[Horde]:|r %s", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.13, 0.13)
    end)

    -- Raid Boss & Monster Whispers
    Events:Register("CHAT_MSG_RAID_BOSS_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffff4800[%s]:|r %s", PUITalk:GetTimestamp(), sender or "Boss", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.28, 0.0)
    end)

    Events:Register("CHAT_MSG_RAID_BOSS_WHISPER", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffff4800[%s whispers]:|r %s", PUITalk:GetTimestamp(), sender or "Boss", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.28, 0.0)
    end)

    Events:Register("CHAT_MSG_MONSTER_WHISPER", "PUITalk_Chat", function(owner, event, msg, sender)
        if not PUITalk:IsChannelEnabled("MONSTER") then return end
        local formatted = string.format("%s |cffffd100[%s whispers]:|r %s", PUITalk:GetTimestamp(), sender or "Monster", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.85, 0.4)
    end)

    -- Ignored & Filtered
    Events:Register("CHAT_MSG_IGNORED", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffff4444%s is ignoring you.|r", PUITalk:GetTimestamp(), sender or "Player")
        PUITalk:AddChatMessage(formatted, 1.0, 0.27, 0.27)
    end)

    Events:Register("CHAT_MSG_FILTERED", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffff4444%s is not receiving whispers.|r", PUITalk:GetTimestamp(), sender or "Player")
        PUITalk:AddChatMessage(formatted, 1.0, 0.27, 0.27)
    end)

    -- Level Up & Character Points
    Events:Register("PLAYER_LEVEL_UP", "PUITalk_Chat", function(owner, event, level, hp, mp, talentPoints)
        local formatted = string.format("%s |cffffff00You have reached level %d!|r", PUITalk:GetTimestamp(), tonumber(level) or 1)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
        if talentPoints and tonumber(talentPoints) and tonumber(talentPoints) > 0 then
            PUITalk:AddChatMessage(string.format("%s |cffffff00You have gained %d talent points.|r", PUITalk:GetTimestamp(), tonumber(talentPoints)), 1.0, 1.0, 0.0)
        end
    end)

    Events:Register("CHARACTER_POINTS_CHANGED", "PUITalk_Chat", function(owner, event, change1, change2)
        if change2 and tonumber(change2) and tonumber(change2) > 0 then
            local _, cp2 = UnitCharacterPoints("player")
            if cp2 and cp2 > 0 then
                local formatted = string.format("%s |cffffff00You now have %d unspent talent points.|r", PUITalk:GetTimestamp(), cp2)
                PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
            end
        end
    end)

    -- Loot & Money
    Events:Register("CHAT_MSG_LOOT", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("LOOT") then return end
        local formatted = string.format("%s |cff00cc00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.0, 0.8, 0.0)
    end)

    Events:Register("CHAT_MSG_MONEY", "PUITalk_Chat", function(owner, event, msg)
        if not PUITalk:IsChannelEnabled("LOOT") then return end
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)

    -- Whispers
    Events:Register("CHAT_MSG_WHISPER", "PUITalk_Chat", function(owner, event, msg, sender)
        PUITalk.lastWhisperSender = sender
        local key = string.lower(sender)
        if PUITalk.AddDMMessage then
            PUITalk:AddDMMessage(key, sender, msg, false)
        end
        if PUITalk.db:Get("autoPopDMs") then
            if PUITalk.OpenDMConversation then PUITalk:OpenDMConversation(sender) end
        else
            if PUITalk.RefreshDMTabs then PUITalk:RefreshDMTabs() end
        end
    end)

    Events:Register("CHAT_MSG_WHISPER_INFORM", "PUITalk_Chat", function(owner, event, msg, recipient)
        local key = string.lower(recipient)
        if PUITalk.AddDMMessage then
            PUITalk:AddDMMessage(key, UnitName("player"), msg, true)
        end
    end)
end
