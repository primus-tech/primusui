--[[
    PrimusUI Module: PUITalk (Unified Modern Chat, Direct Messages & Social Hub)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Consolidates:
    - PUIChat: Modern chat styling, class colors, URL clicks, sticky channels, chat copy.
    - PUIMessenger: Isolated whisper DMs, unread badges, audio alerts, and live social roster.
    
    Provides 3 Master Top-Level Tabs:
    1. [💬 Chat]    - Virtualized game channels, class-colored names, clickable URLs, copy frame, whisper diversion.
    2. [✉️ Messages] - Isolated DM conversation sub-tabs, session history, unread counters, no double-send.
    3. [👥 Social]   - Real-time Friends list & Guild roster with online status, level, zone, and 1-click [DM] action.
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

local DB       = Primus.DB
local Widgets  = Primus.Widgets
local Media    = Primus.Media
local Utils    = Primus.Utils
local Events   = Primus.Events
local Time     = Primus.Time
local PUIMover = Primus.PUIMover

local talkDB = DB:RegisterNamespace("PUITalk", {
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
})

-- Player Class Cache
local playerClassCache = {}

-- Message Buffers for ChatFrame 1..7 (for Chat Copy feature)
local chatBuffers = {}
for i = 1, 7 do
    chatBuffers[i] = {}
end

-- UI Frames & State
local masterFrame  = nil
local copyFrame    = nil
local urlFrame     = nil
local copyButtons  = {}

-- Conversation & DM State
local dmTabs = {}
local activeDMKey = nil
local conversationHistory = {}
local lastWhisperSender = nil

-- Social Roster Cache
local friendRows = {}
local guildRows = {}

-- =========================================================================
-- 1. CLASS COLORING & STRING UTILITIES
-- =========================================================================

local function CacheUnitClass(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and class then
        playerClassCache[name] = class
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
                playerClassCache[name] = class
            end
        end
    end

    local numFriends = GetNumFriends()
    for i = 1, numFriends do
        local name, _, class = GetFriendInfo(i)
        if name and class then
            playerClassCache[name] = class
        end
    end
end

function PUITalk:GetColoredName(name)
    if not name or not talkDB:Get("classColors") then return name end
    local class = playerClassCache[name]
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

local function GetTimestamp()
    local hour, minute = GetGameTime()
    return string.format("[%02d:%02d]", hour, minute)
end

-- =========================================================================
-- 2. CHAT COPY WINDOW & URL CLICK MODAL
-- =========================================================================

function PUITalk:CreateCopyFrame()
    if copyFrame then return copyFrame end

    local f = CreateFrame("Frame", "Primus_ChatCopyFrame", UIParent)
    f:SetWidth(580)
    f:SetHeight(420)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(Media:Fetch("border", "1Pixel"))
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    f:SetBackdropBorderColor(0.20, 0.45, 0.85, 1.0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    tinsert(UISpecialFrames, "Primus_ChatCopyFrame")

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    header:SetHeight(28)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.10, 0.14, 0.22, 1.0)
    header:SetBackdropBorderColor(0.20, 0.40, 0.70, 1.0)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText(Utils.ColorText("Primus Chat Copy", "69ccf0") .. " |cffaaaaaa// Select text & Press Ctrl+C|r")
    f.titleText = title

    local closeX = CreateFrame("Button", nil, header)
    closeX:SetWidth(18)
    closeX:SetHeight(18)
    closeX:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    closeX:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeX:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    closeX:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local cX = closeX:CreateFontString(nil, "OVERLAY")
    cX:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    cX:SetPoint("CENTER", closeX, "CENTER", 0, 0)
    cX:SetText("X")
    closeX:SetScript("OnClick", function() f:Hide() end)

    -- Subheader
    local subHeader = CreateFrame("Frame", nil, f)
    subHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    subHeader:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    subHeader:SetHeight(22)
    subHeader:SetBackdrop(Media:Fetch("border", "1Pixel"))
    subHeader:SetBackdropColor(0.08, 0.09, 0.12, 0.9)
    subHeader:SetBackdropBorderColor(0.20, 0.25, 0.35, 0.8)

    local subText = subHeader:CreateFontString(nil, "OVERLAY")
    subText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    subText:SetPoint("LEFT", subHeader, "LEFT", 8, 0)
    subText:SetText("Chat History Log")
    f.subText = subText

    -- Scroll & EditBox
    local editContainer = CreateFrame("Frame", nil, f)
    editContainer:SetPoint("TOPLEFT", subHeader, "BOTTOMLEFT", 0, -4)
    editContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 40)
    editContainer:SetBackdrop(Media:Fetch("border", "1Pixel"))
    editContainer:SetBackdropColor(0.03, 0.04, 0.05, 1.0)
    editContainer:SetBackdropBorderColor(0.18, 0.22, 0.30, 1.0)

    local scroll = CreateFrame("ScrollFrame", "Primus_ChatCopyScrollFrame", editContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", editContainer, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", editContainer, "BOTTOMRIGHT", -26, 6)

    local editBox = CreateFrame("EditBox", "Primus_ChatCopyEditBox", scroll)
    editBox:SetWidth(520)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(Media:Fetch("font", "Default"), 10, "")
    editBox:SetTextColor(0.95, 0.95, 0.95, 1.0)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnTextChanged", function()
        local s = this:GetParent()
        if s and s.UpdateScrollChildRect then
            s:UpdateScrollChildRect()
        end
    end)
    scroll:SetScrollChild(editBox)
    f.editBox = editBox
    f.scroll = scroll

    -- Footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    footer:SetHeight(32)

    local selectBtn = CreateFrame("Button", nil, footer)
    selectBtn:SetWidth(130)
    selectBtn:SetHeight(22)
    selectBtn:SetPoint("LEFT", footer, "LEFT", 4, 0)
    selectBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    selectBtn:SetBackdropColor(0.15, 0.25, 0.15, 1.0)
    selectBtn:SetBackdropBorderColor(0.30, 0.80, 0.30, 1.0)
    local sTxt = selectBtn:CreateFontString(nil, "OVERLAY")
    sTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    sTxt:SetPoint("CENTER", 0, 0)
    sTxt:SetText("Select All / Copy")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText(0)
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: Text highlighted! Press Ctrl+C to copy.", "69ccf0"))
    end)

    local clearBtn = CreateFrame("Button", nil, footer)
    clearBtn:SetWidth(90)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", selectBtn, "RIGHT", 8, 0)
    clearBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    clearBtn:SetBackdropColor(0.20, 0.10, 0.10, 1.0)
    clearBtn:SetBackdropBorderColor(0.80, 0.30, 0.30, 1.0)
    local clTxt = clearBtn:CreateFontString(nil, "OVERLAY")
    clTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    clTxt:SetPoint("CENTER", 0, 0)
    clTxt:SetText("Clear Buffer")
    clearBtn:SetScript("OnClick", function()
        local idx = f.activeFrameIndex or 1
        chatBuffers[idx] = {}
        editBox:SetText("")
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[Primus Talk]: Cleared chat buffer for Tab %d.", idx), "69ccf0"))
    end)

    local closeBtn = CreateFrame("Button", nil, footer)
    closeBtn:SetWidth(75)
    closeBtn:SetHeight(22)
    closeBtn:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
    closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeBtn:SetBackdropColor(0.15, 0.15, 0.18, 1.0)
    closeBtn:SetBackdropBorderColor(0.35, 0.35, 0.40, 1.0)
    local clMainTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    clMainTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    clMainTxt:SetPoint("CENTER", 0, 0)
    clMainTxt:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    copyFrame = f
    return f
end

function PUITalk:OpenCopyFrame(chatIndex)
    chatIndex = tonumber(chatIndex) or 1
    if chatIndex < 1 or chatIndex > 7 then chatIndex = 1 end

    local f = self:CreateCopyFrame()
    f.activeFrameIndex = chatIndex

    local tabName = _G["ChatFrame" .. chatIndex .. "Tab"] and _G["ChatFrame" .. chatIndex .. "Tab"]:GetText() or ("Chat " .. chatIndex)
    f.titleText:SetText(string.format("%s |cffaaaaaa// Tab: %s (Ctrl+C to Copy)|r", Utils.ColorText("Primus Chat Copy", "69ccf0"), tabName))

    local buffer = chatBuffers[chatIndex] or {}
    local totalLines = table.getn(buffer)
    f.subText:SetText(string.format("Logged %d messages from %s. Click 'Select All / Copy' to grab all text.", totalLines, tabName))

    local lines = {}
    for i = 1, totalLines do
        local entry = buffer[i]
        local clean = self:CleanChatText(entry.text)
        table.insert(lines, string.format("[%s] %s", entry.time, clean))
    end

    local fullText = table.concat(lines, "\n")
    f.editBox:SetText(fullText)
    f:Show()
    f:Raise()

    f.editBox:SetFocus()
    f.editBox:HighlightText(0)
end

function PUITalk:ShowURLCopyPopup(url)
    if not urlFrame then
        local f = CreateFrame("Frame", "Primus_URLCopyFrame", UIParent)
        f:SetWidth(420)
        f:SetHeight(100)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop(Media:Fetch("border", "1Pixel"))
        f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
        f:SetBackdropBorderColor(0.20, 0.50, 0.90, 1.0)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
        tinsert(UISpecialFrames, "Primus_URLCopyFrame")

        local title = f:CreateFontString(nil, "OVERLAY")
        title:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
        title:SetText(Utils.ColorText("Primus Web Link Copy", "69ccf0") .. " |cffaaaaaa(Press Ctrl+C to copy)|r")

        local eb = CreateFrame("EditBox", "Primus_URLEditBox", f)
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 36)
        eb:SetBackdrop(Media:Fetch("border", "1Pixel"))
        eb:SetBackdropColor(0.03, 0.04, 0.05, 1.0)
        eb:SetBackdropBorderColor(0.25, 0.35, 0.50, 1.0)
        eb:SetFont(Media:Fetch("font", "Default"), 11, "")
        eb:SetTextColor(1, 1, 0.4)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f.editBox = eb

        local copyBtn = CreateFrame("Button", nil, f)
        copyBtn:SetWidth(90)
        copyBtn:SetHeight(20)
        copyBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
        copyBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
        copyBtn:SetBackdropColor(0.15, 0.25, 0.15, 1.0)
        copyBtn:SetBackdropBorderColor(0.30, 0.80, 0.30, 1.0)
        local cTxt = copyBtn:CreateFontString(nil, "OVERLAY")
        cTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
        cTxt:SetPoint("CENTER", 0, 0)
        cTxt:SetText("Select / Copy")
        copyBtn:SetScript("OnClick", function()
            eb:SetFocus()
            eb:HighlightText(0)
        end)

        local closeBtn = CreateFrame("Button", nil, f)
        closeBtn:SetWidth(70)
        closeBtn:SetHeight(20)
        closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
        closeBtn:SetBackdropColor(0.15, 0.15, 0.18, 1.0)
        closeBtn:SetBackdropBorderColor(0.35, 0.35, 0.40, 1.0)
        local clTxt = closeBtn:CreateFontString(nil, "OVERLAY")
        clTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
        clTxt:SetPoint("CENTER", 0, 0)
        clTxt:SetText("Done")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        urlFrame = f
    end

    urlFrame.editBox:SetText(url or "")
    urlFrame:Show()
    urlFrame:Raise()
    urlFrame.editBox:SetFocus()
    urlFrame.editBox:HighlightText(0)
end

-- =========================================================================
-- 3. CHATFRAME HOOKS, DOCKED [C] BUTTONS & SCROLLING
-- =========================================================================

local function AttachCopyButtons()
    if not talkDB:Get("chatCopy") then return end

    for i = 1, 7 do
        local cf = _G["ChatFrame" .. i]
        if cf and not copyButtons[i] then
            local btn = CreateFrame("Button", "Primus_ChatCopyBtn_" .. i, cf)
            btn:SetWidth(18)
            btn:SetHeight(18)
            btn:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -2)
            btn:SetFrameLevel(cf:GetFrameLevel() + 5)
            btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
            btn:SetBackdropColor(0.08, 0.10, 0.14, 0.85)
            btn:SetBackdropBorderColor(0.30, 0.50, 0.80, 0.8)

            local txt = btn:CreateFontString(nil, "OVERLAY")
            txt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
            txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
            txt:SetText("C")
            txt:SetTextColor(0.40, 0.80, 1.00)
            btn.text = txt

            btn.frameIndex = i
            btn:SetScript("OnEnter", function()
                this:SetBackdropColor(0.18, 0.28, 0.45, 1.0)
                this:SetBackdropBorderColor(0.50, 0.85, 1.0, 1.0)
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Primus Chat Copy", 0.4, 0.8, 1.0)
                GameTooltip:AddLine(string.format("Click to copy text from Chat Tab %d.", this.frameIndex or 1), 1, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                this:SetBackdropColor(0.08, 0.10, 0.14, 0.85)
                this:SetBackdropBorderColor(0.30, 0.50, 0.80, 0.8)
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", function()
                PUITalk:OpenCopyFrame(this.frameIndex)
            end)

            copyButtons[i] = btn
        end
    end
end

local function SetupChatHooks()
    for i = 1, 7 do
        local cf = _G["ChatFrame" .. i]
        if cf and not cf.primusBufferHooked then
            local frameIdx = i
            local origAddMessage = cf.AddMessage
            cf.AddMessage = function(self, text, r, g, b, id)
                if text then
                    -- Whisper Diversion Check
                    if talkDB:Get("divertWhispers") and id then
                        local msgType = id
                        if msgType == "WHISPER" or msgType == "WHISPER_INFORM" then
                            -- Cleanly suppressed from ChatFrame1 when diversion is enabled
                            return
                        end
                    end

                    local timeStamp = date("%H:%M:%S")
                    local rawText = tostring(text)
                    table.insert(chatBuffers[frameIdx], { time = timeStamp, text = rawText })
                    if table.getn(chatBuffers[frameIdx]) > 300 then
                        table.remove(chatBuffers[frameIdx], 1)
                    end
                    text = PUITalk:LinkifyURLs(text)
                end
                return origAddMessage(self, text, r, g, b, id)
            end
            cf.primusBufferHooked = true
        end
    end

    -- Hook SetItemRef to handle clicked URL links
    if not _G.Primus_OriginalSetItemRef then
        _G.Primus_OriginalSetItemRef = SetItemRef
        SetItemRef = function(link, text, button)
            if link and string.sub(link, 1, 4) == "url:" then
                local url = string.sub(link, 5)
                PUITalk:ShowURLCopyPopup(url)
                return
            end
            return _G.Primus_OriginalSetItemRef(link, text, button)
        end
    end
end

local function SetupMousewheelScrolling()
    if not talkDB:Get("mousewheelScroll") then return end

    for i = 1, 7 do
        local cf = _G["ChatFrame" .. i]
        if cf and not cf.primusScrolled then
            cf:EnableMouseWheel(true)
            cf:SetScript("OnMouseWheel", function()
                if arg1 > 0 then
                    if IsShiftKeyDown() then
                        this:ScrollToTop()
                    else
                        this:ScrollUp()
                        this:ScrollUp()
                        this:ScrollUp()
                    end
                else
                    if IsShiftKeyDown() then
                        this:ScrollToBottom()
                    else
                        this:ScrollDown()
                        this:ScrollDown()
                        this:ScrollDown()
                    end
                end
            end)
            cf.primusScrolled = true
        end
    end
end

local function SetupStickyChannels()
    if not talkDB:Get("stickyChannels") then return end
    local channels = { "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL" }
    local count = table.getn(channels)
    for i = 1, count do
        local chan = channels[i]
        if ChatTypeInfo[chan] then
            ChatTypeInfo[chan].sticky = 1
        end
    end
end

-- =========================================================================
-- 4. PUITALK MASTER FRAME & TAB ORCHESTRATION
-- =========================================================================

function PUITalk:CreateMasterFrame()
    if masterFrame then return masterFrame end

    local f = CreateFrame("Frame", "Primus_PUITalkFrame", UIParent)
    f:SetWidth(440)
    f:SetHeight(320)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 40)
    f:SetBackdrop(Media:Fetch("border", "1Pixel"))
    f:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
    f:SetBackdropBorderColor(0.20, 0.45, 0.85, 1.0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    tinsert(UISpecialFrames, "Primus_PUITalkFrame")

    -- ---------------------------------------------------------------------
    -- Master Top Rail (3 Master Tabs + Utility Buttons)
    -- ---------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    header:SetHeight(28)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.10, 0.13, 0.18, 1.0)
    header:SetBackdropBorderColor(0.20, 0.35, 0.60, 1.0)
    f.header = header

    -- Tab 1: [💬 Chat]
    local tabChat = CreateFrame("Button", "Primus_PUITalkTab_1", header)
    tabChat:SetWidth(95)
    tabChat:SetHeight(22)
    tabChat:SetPoint("LEFT", header, "LEFT", 4, 0)
    tabChat:SetBackdrop(Media:Fetch("border", "1Pixel"))
    local tabChatText = tabChat:CreateFontString(nil, "OVERLAY")
    tabChatText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    tabChatText:SetPoint("CENTER", 0, 0)
    tabChatText:SetText("💬 Chat")
    tabChat.text = tabChatText
    tabChat:SetScript("OnClick", function() PUITalk:SelectMasterTab(1) end)
    f.tabChat = tabChat

    -- Tab 2: [✉️ Messages]
    local tabMessages = CreateFrame("Button", "Primus_PUITalkTab_2", header)
    tabMessages:SetWidth(115)
    tabMessages:SetHeight(22)
    tabMessages:SetPoint("LEFT", tabChat, "RIGHT", 4, 0)
    tabMessages:SetBackdrop(Media:Fetch("border", "1Pixel"))
    local tabMsgText = tabMessages:CreateFontString(nil, "OVERLAY")
    tabMsgText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    tabMsgText:SetPoint("CENTER", 0, 0)
    tabMsgText:SetText("✉️ Messages")
    tabMessages.text = tabMsgText
    tabMessages:SetScript("OnClick", function() PUITalk:SelectMasterTab(2) end)
    f.tabMessages = tabMessages

    -- Tab 3: [👥 Social]
    local tabSocial = CreateFrame("Button", "Primus_PUITalkTab_3", header)
    tabSocial:SetWidth(110)
    tabSocial:SetHeight(22)
    tabSocial:SetPoint("LEFT", tabMessages, "RIGHT", 4, 0)
    tabSocial:SetBackdrop(Media:Fetch("border", "1Pixel"))
    local tabSocialText = tabSocial:CreateFontString(nil, "OVERLAY")
    tabSocialText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    tabSocialText:SetPoint("CENTER", 0, 0)
    tabSocialText:SetText("👥 Social")
    tabSocial.text = tabSocialText
    tabSocial:SetScript("OnClick", function() PUITalk:SelectMasterTab(3) end)
    f.tabSocial = tabSocial

    -- Window Controls on Right ([C] Copy, [⚙️] Config, [✖] Close)
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeBtn:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    closeBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    closeText:SetPoint("CENTER", 0, 0)
    closeText:SetText("X")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local copyBtn = CreateFrame("Button", nil, header)
    copyBtn:SetWidth(18)
    copyBtn:SetHeight(18)
    copyBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    copyBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    copyBtn:SetBackdropColor(0.1, 0.2, 0.35, 0.9)
    copyBtn:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
    local cpText = copyBtn:CreateFontString(nil, "OVERLAY")
    cpText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    cpText:SetPoint("CENTER", 0, 0)
    cpText:SetText("C")
    cpText:SetTextColor(0.4, 0.85, 1.0)
    copyBtn:SetScript("OnClick", function() PUITalk:OpenCopyFrame(1) end)

    -- ---------------------------------------------------------------------
    -- Universal Docked Input EditBox (Bottom)
    -- ---------------------------------------------------------------------
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    footer:SetHeight(24)
    footer:SetBackdrop(Media:Fetch("border", "1Pixel"))
    footer:SetBackdropColor(0.04, 0.05, 0.07, 1.0)
    footer:SetBackdropBorderColor(0.20, 0.35, 0.60, 1.0)
    f.footer = footer

    local contextPill = CreateFrame("Frame", nil, footer)
    contextPill:SetPoint("LEFT", footer, "LEFT", 2, 0)
    contextPill:SetWidth(80)
    contextPill:SetHeight(20)
    contextPill:SetBackdrop(Media:Fetch("border", "1Pixel"))
    contextPill:SetBackdropColor(0.12, 0.16, 0.24, 1.0)
    contextPill:SetBackdropBorderColor(0.3, 0.6, 1.0, 0.8)
    local contextText = contextPill:CreateFontString(nil, "OVERLAY")
    contextText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    contextText:SetPoint("CENTER", 0, 0)
    contextText:SetText("#General")
    contextPill.text = contextText
    f.contextPill = contextPill

    local editBox = CreateFrame("EditBox", "Primus_PUITalkUniversalInput", footer)
    editBox:SetPoint("LEFT", contextPill, "RIGHT", 4, 0)
    editBox:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
    editBox:SetHeight(20)
    editBox:SetFont(Media:Fetch("font", "Default"), 10, "")
    editBox:SetAutoFocus(false)
    editBox:SetHistoryLines(30)
    editBox:SetScript("OnEnterPressed", function()
        local text = this:GetText()
        if text and text ~= "" then
            PUITalk:HandleInputSubmit(text)
            this:AddHistoryLine(text)
            this:SetText("")
        end
    end)
    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    f.editBox = editBox

    -- ---------------------------------------------------------------------
    -- Viewport Container
    -- ---------------------------------------------------------------------
    local viewport = CreateFrame("Frame", "Primus_PUITalkViewport", f)
    viewport:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    viewport:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
    f.viewport = viewport

    -- ---------------------------------------------------------------------
    -- TAB 1 VIEW: 💬 CHAT
    -- ---------------------------------------------------------------------
    local viewChat = CreateFrame("Frame", "Primus_PUITalkViewChat", viewport)
    viewChat:SetAllPoints(viewport)
    viewChat:SetBackdrop(Media:Fetch("border", "1Pixel"))
    viewChat:SetBackdropColor(0.04, 0.04, 0.06, 0.8)
    viewChat:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.8)

    local chatHelpText = viewChat:CreateFontString(nil, "OVERLAY")
    chatHelpText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    chatHelpText:SetPoint("TOPLEFT", viewChat, "TOPLEFT", 6, -6)
    chatHelpText:SetText(Utils.ColorText("Game Chat Channels", "69ccf0") .. " |cff888888(Whispers routed to Messages Tab)|r")

    local chatScroll = CreateFrame("ScrollingMessageFrame", "Primus_PUITalkChatStream", viewChat)
    chatScroll:SetPoint("TOPLEFT", viewChat, "TOPLEFT", 6, -24)
    chatScroll:SetPoint("BOTTOMRIGHT", viewChat, "BOTTOMRIGHT", -6, 6)
    chatScroll:SetFont(Media:Fetch("font", "Default"), 10, "")
    chatScroll:SetJustifyH("LEFT")
    chatScroll:SetFading(false)
    chatScroll:SetMaxLines(400)
    chatScroll:EnableMouseWheel(true)
    chatScroll:SetScript("OnMouseWheel", function()
        if arg1 > 0 then chatScroll:ScrollUp() else chatScroll:ScrollDown() end
    end)
    viewChat.scroll = chatScroll
    f.viewChat = viewChat

    -- ---------------------------------------------------------------------
    -- TAB 2 VIEW: ✉️ MESSAGES (DMs)
    -- ---------------------------------------------------------------------
    local viewMessages = CreateFrame("Frame", "Primus_PUITalkViewMessages", viewport)
    viewMessages:SetAllPoints(viewport)
    viewMessages:SetBackdrop(Media:Fetch("border", "1Pixel"))
    viewMessages:SetBackdropColor(0.04, 0.04, 0.06, 0.8)
    viewMessages:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.8)

    -- DM Sub-Tab Rail
    local dmTabBar = CreateFrame("Frame", "Primus_PUITalkDMTabBar", viewMessages)
    dmTabBar:SetPoint("TOPLEFT", viewMessages, "TOPLEFT", 4, -4)
    dmTabBar:SetPoint("TOPRIGHT", viewMessages, "TOPRIGHT", -4, -4)
    dmTabBar:SetHeight(22)
    viewMessages.dmTabBar = dmTabBar

    -- DM Message Frame
    local dmMsgFrame = CreateFrame("ScrollingMessageFrame", "Primus_PUITalkDMFrame", viewMessages)
    dmMsgFrame:SetPoint("TOPLEFT", dmTabBar, "BOTTOMLEFT", 2, -4)
    dmMsgFrame:SetPoint("BOTTOMRIGHT", viewMessages, "BOTTOMRIGHT", -6, 6)
    dmMsgFrame:SetFont(Media:Fetch("font", "Default"), 10, "")
    dmMsgFrame:SetJustifyH("LEFT")
    dmMsgFrame:SetFading(false)
    dmMsgFrame:SetMaxLines(400)
    dmMsgFrame:EnableMouseWheel(true)
    dmMsgFrame:SetScript("OnMouseWheel", function()
        if arg1 > 0 then dmMsgFrame:ScrollUp() else dmMsgFrame:ScrollDown() end
    end)
    viewMessages.msgFrame = dmMsgFrame
    f.viewMessages = viewMessages

    -- ---------------------------------------------------------------------
    -- TAB 3 VIEW: 👥 SOCIAL (Friends & Guild)
    -- ---------------------------------------------------------------------
    local viewSocial = CreateFrame("Frame", "Primus_PUITalkViewSocial", viewport)
    viewSocial:SetAllPoints(viewport)
    viewSocial:SetBackdrop(Media:Fetch("border", "1Pixel"))
    viewSocial:SetBackdropColor(0.04, 0.04, 0.06, 0.8)
    viewSocial:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.8)

    -- Social Sub-Navigation ([Friends] | [Guild] | [Add Friend] | [Refresh])
    local socialNav = CreateFrame("Frame", nil, viewSocial)
    socialNav:SetPoint("TOPLEFT", viewSocial, "TOPLEFT", 4, -4)
    socialNav:SetPoint("TOPRIGHT", viewSocial, "TOPRIGHT", -4, -4)
    socialNav:SetHeight(22)

    local btnFriends = CreateFrame("Button", nil, socialNav)
    btnFriends:SetWidth(75)
    btnFriends:SetHeight(20)
    btnFriends:SetPoint("LEFT", socialNav, "LEFT", 0, 0)
    btnFriends:SetBackdrop(Media:Fetch("border", "1Pixel"))
    local bfTxt = btnFriends:CreateFontString(nil, "OVERLAY")
    bfTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    bfTxt:SetPoint("CENTER", 0, 0)
    bfTxt:SetText("Friends")
    btnFriends.text = bfTxt
    btnFriends:SetScript("OnClick", function()
        talkDB:Set("activeSocialTab", "friends")
        PUITalk:RefreshSocialView()
    end)
    viewSocial.btnFriends = btnFriends

    local btnGuild = CreateFrame("Button", nil, socialNav)
    btnGuild:SetWidth(75)
    btnGuild:SetHeight(20)
    btnGuild:SetPoint("LEFT", btnFriends, "RIGHT", 4, 0)
    btnGuild:SetBackdrop(Media:Fetch("border", "1Pixel"))
    local bgTxt = btnGuild:CreateFontString(nil, "OVERLAY")
    bgTxt:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    bgTxt:SetPoint("CENTER", 0, 0)
    bgTxt:SetText("Guild")
    btnGuild.text = bgTxt
    btnGuild:SetScript("OnClick", function()
        talkDB:Set("activeSocialTab", "guild")
        PUITalk:RefreshSocialView()
    end)
    viewSocial.btnGuild = btnGuild

    local btnRefresh = CreateFrame("Button", nil, socialNav)
    btnRefresh:SetWidth(65)
    btnRefresh:SetHeight(20)
    btnRefresh:SetPoint("RIGHT", socialNav, "RIGHT", 0, 0)
    btnRefresh:SetBackdrop(Media:Fetch("border", "1Pixel"))
    btnRefresh:SetBackdropColor(0.12, 0.16, 0.22, 1.0)
    btnRefresh:SetBackdropBorderColor(0.25, 0.45, 0.70, 1.0)
    local brTxt = btnRefresh:CreateFontString(nil, "OVERLAY")
    brTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    brTxt:SetPoint("CENTER", 0, 0)
    brTxt:SetText("🔄 Refresh")
    btnRefresh:SetScript("OnClick", function()
        ShowFriends()
        if IsInGuild() then GuildRoster() end
        PUITalk:RefreshSocialView()
    end)

    local socialContainer = CreateFrame("Frame", "Primus_PUITalkSocialList", viewSocial)
    socialContainer:SetPoint("TOPLEFT", socialNav, "BOTTOMLEFT", 0, -4)
    socialContainer:SetPoint("BOTTOMRIGHT", viewSocial, "BOTTOMRIGHT", -4, 4)
    viewSocial.socialContainer = socialContainer
    f.viewSocial = viewSocial

    -- Register with PUIMover
    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(f, "PUITalk", "PUITalk: Unified Chat & Social Hub", "SOCIAL")
    end

    masterFrame = f
    PUITalk:SelectMasterTab(talkDB:Get("activeMasterTab") or 1)
    return f
end

-- =========================================================================
-- 5. TAB SWITCHING & RENDERING LOGIC
-- =========================================================================

function PUITalk:SelectMasterTab(tabIndex)
    if not masterFrame then return end
    talkDB:Set("activeMasterTab", tabIndex)

    -- Update Tab Button Highlights
    local tabs = { masterFrame.tabChat, masterFrame.tabMessages, masterFrame.tabSocial }
    for i = 1, 3 do
        local btn = tabs[i]
        if i == tabIndex then
            btn:SetBackdropColor(0.18, 0.26, 0.40, 1.0)
            btn:SetBackdropBorderColor(0.40, 0.75, 1.0, 1.0)
            btn.text:SetTextColor(1.0, 1.0, 1.0)
        else
            btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
            btn:SetBackdropBorderColor(0.20, 0.28, 0.40, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    -- Toggle Viewports
    masterFrame.viewChat:Hide()
    masterFrame.viewMessages:Hide()
    masterFrame.viewSocial:Hide()

    if tabIndex == 1 then
        masterFrame.viewChat:Show()
        masterFrame.contextPill.text:SetText("#General")
    elseif tabIndex == 2 then
        masterFrame.viewMessages:Show()
        PUITalk:RefreshDMTabs()
        if activeDMKey and dmTabs[activeDMKey] then
            masterFrame.contextPill.text:SetText("To: " .. (dmTabs[activeDMKey].name or activeDMKey))
        else
            masterFrame.contextPill.text:SetText("Whisper")
        end
    elseif tabIndex == 3 then
        masterFrame.viewSocial:Show()
        masterFrame.contextPill.text:SetText("Social")
        PUITalk:RefreshSocialView()
    end
end

-- =========================================================================
-- 6. DIRECT MESSAGES (DMs) & SUB-TABS (TAB 2)
-- =========================================================================

function PUITalk:RefreshDMTabs()
    if not masterFrame or not masterFrame.viewMessages then return end

    local tabBar = masterFrame.viewMessages.dmTabBar
    local xOffset = 0
    local totalUnread = 0

    for key, tab in pairs(dmTabs) do
        local btn = tab.button
        if not btn then
            btn = CreateFrame("Button", "Primus_PUITalkDMTab_" .. key, tabBar)
            btn:SetHeight(20)
            btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
            btn.key = key

            local text = btn:CreateFontString(nil, "OVERLAY")
            text:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
            text:SetPoint("CENTER", btn, "CENTER", -6, 0)
            btn.text = text

            local close = CreateFrame("Button", nil, btn)
            close:SetWidth(12)
            close:SetHeight(12)
            close:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            local cT = close:CreateFontString(nil, "OVERLAY")
            cT:SetFont(Media:Fetch("font", "Default"), 8, "")
            cT:SetPoint("CENTER", close, "CENTER", 0, 0)
            cT:SetText("x")
            cT:SetTextColor(0.8, 0.4, 0.4)
            close:SetScript("OnClick", function()
                PUITalk:CloseDMTab(this:GetParent().key)
            end)
            btn.closeBtn = close

            btn:SetScript("OnClick", function()
                PUITalk:SelectDMTab(this.key)
            end)
            tab.button = btn
        end

        local displayName = tab.name
        if tab.unread and tab.unread > 0 then
            displayName = displayName .. string.format(" |cffffcc00(%d)|r", tab.unread)
            totalUnread = totalUnread + tab.unread
        end

        btn.text:SetText(displayName)
        local textWidth = btn.text:GetStringWidth() or 40
        local btnWidth = math.max(55, textWidth + 20)
        btn:SetWidth(btnWidth)

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", tabBar, "LEFT", xOffset, 0)
        xOffset = xOffset + btnWidth + 3

        if key == activeDMKey then
            btn:SetBackdropColor(0.18, 0.26, 0.40, 1.0)
            btn:SetBackdropBorderColor(0.40, 0.75, 1.0, 1.0)
            btn.text:SetTextColor(1.0, 1.0, 1.0)
        else
            btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
            btn:SetBackdropBorderColor(0.20, 0.28, 0.40, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
        btn:Show()
    end

    -- Update Top Header Tab 2 Unread Pill
    if totalUnread > 0 then
        masterFrame.tabMessages.text:SetText(string.format("✉️ Messages |cffffcc00(%d)|r", totalUnread))
    else
        masterFrame.tabMessages.text:SetText("✉️ Messages")
    end
end

function PUITalk:OpenDMConversation(targetName)
    if not targetName or targetName == "" then return end
    local key = string.lower(targetName)

    self:CreateMasterFrame()
    masterFrame:Show()

    if not dmTabs[key] then
        dmTabs[key] = {
            key = key,
            name = targetName,
            unread = 0,
        }
        if not conversationHistory[key] then
            conversationHistory[key] = {}
        end
    end

    self:SelectMasterTab(2)
    self:SelectDMTab(key)
end

function PUITalk:SelectDMTab(key)
    if not dmTabs[key] then return end
    activeDMKey = key
    dmTabs[key].unread = 0

    local tab = dmTabs[key]
    masterFrame.contextPill.text:SetText("To: " .. tab.name)

    -- Reload messages
    masterFrame.viewMessages.msgFrame:Clear()
    local history = conversationHistory[key] or {}
    local count = table.getn(history)
    for i = 1, count do
        local entry = history[i]
        masterFrame.viewMessages.msgFrame:AddMessage(entry.msg, entry.r, entry.g, entry.b)
    end
    masterFrame.viewMessages.msgFrame:ScrollToBottom()

    self:RefreshDMTabs()
    if masterFrame.editBox and masterFrame:IsShown() and not UnitAffectingCombat("player") then
        masterFrame.editBox:SetFocus()
    end
end

function PUITalk:CloseDMTab(key)
    if dmTabs[key] then
        if dmTabs[key].button then
            dmTabs[key].button:Hide()
            dmTabs[key].button = nil
        end
        dmTabs[key] = nil
    end

    if activeDMKey == key then
        activeDMKey = nil
        for nextKey, _ in pairs(dmTabs) do
            self:SelectDMTab(nextKey)
            return
        end
        if masterFrame and masterFrame.viewMessages then
            masterFrame.viewMessages.msgFrame:Clear()
        end
    end
    self:RefreshDMTabs()
end

function PUITalk:AddDMMessage(key, sender, text, isOutgoing, r, g, b)
    if not conversationHistory[key] then
        conversationHistory[key] = {}
    end

    local timestamp = GetTimestamp()
    local formattedMsg = ""

    if isOutgoing then
        formattedMsg = string.format("%s |cffffd100[You]:|r %s", timestamp, text)
        r, g, b = r or 1.0, g or 1.0, b or 0.8
    else
        formattedMsg = string.format("%s |cff00ccff[%s]:|r %s", timestamp, sender, text)
        r, g, b = r or 0.4, g or 0.9, b or 1.0
    end

    table.insert(conversationHistory[key], { msg = formattedMsg, r = r, g = g, b = b })

    local isViewingThisDM = masterFrame and masterFrame:IsShown() and (talkDB:Get("activeMasterTab") == 2) and (activeDMKey == key)

    if isViewingThisDM then
        masterFrame.viewMessages.msgFrame:AddMessage(formattedMsg, r, g, b)
        masterFrame.viewMessages.msgFrame:ScrollToBottom()
    else
        if dmTabs[key] then
            dmTabs[key].unread = (dmTabs[key].unread or 0) + 1
        end
        self:RefreshDMTabs()
    end

    if talkDB:Get("playSounds", true) and not isOutgoing then
        PlaySound("TellMessage")
    end
end

-- =========================================================================
-- 7. SOCIAL & FRIENDS ROSTER (TAB 3)
-- =========================================================================

local function CreateSocialRow(parent, index)
    local row = CreateFrame("Button", "Primus_PUITalkSocialRow_" .. index, parent)
    row:SetWidth(420)
    row:SetHeight(20)
    row:SetBackdrop(Media:Fetch("border", "1Pixel"))
    row:SetBackdropColor(0.06, 0.08, 0.12, 0.6)
    row:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.6)

    local statusDot = row:CreateTexture(nil, "ARTWORK")
    statusDot:SetWidth(7)
    statusDot:SetHeight(7)
    statusDot:SetPoint("LEFT", row, "LEFT", 6, 0)
    statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    statusDot:SetVertexColor(0.2, 1.0, 0.4)
    row.statusDot = statusDot

    local nameText = row:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    nameText:SetPoint("LEFT", statusDot, "RIGHT", 6, 0)
    nameText:SetWidth(100)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local infoText = row:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 8, "")
    infoText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    infoText:SetWidth(180)
    infoText:SetJustifyH("LEFT")
    infoText:SetTextColor(0.75, 0.75, 0.75)
    row.infoText = infoText

    local dmBtn = CreateFrame("Button", nil, row)
    dmBtn:SetWidth(45)
    dmBtn:SetHeight(16)
    dmBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    dmBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    dmBtn:SetBackdropColor(0.12, 0.22, 0.38, 0.9)
    dmBtn:SetBackdropBorderColor(0.3, 0.6, 1.0, 1)
    local dmTxt = dmBtn:CreateFontString(nil, "OVERLAY")
    dmTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    dmTxt:SetPoint("CENTER", 0, 0)
    dmTxt:SetText("💬 DM")
    dmTxt:SetTextColor(0.4, 0.85, 1.0)
    dmBtn:SetScript("OnClick", function()
        local parentRow = this:GetParent()
        if parentRow and parentRow.targetName then
            PUITalk:OpenDMConversation(parentRow.targetName)
        end
    end)
    row.dmBtn = dmBtn

    row:SetScript("OnClick", function()
        if this.targetName then
            PUITalk:OpenDMConversation(this.targetName)
        end
    end)

    return row
end

function PUITalk:RefreshSocialView()
    if not masterFrame or not masterFrame.viewSocial or not masterFrame.viewSocial:IsShown() then return end

    local container = masterFrame.viewSocial.socialContainer
    local socialMode = talkDB:Get("activeSocialTab") or "friends"

    -- Highlight Sub-Tab
    if socialMode == "friends" then
        masterFrame.viewSocial.btnFriends:SetBackdropColor(0.18, 0.26, 0.40, 1.0)
        masterFrame.viewSocial.btnFriends:SetBackdropBorderColor(0.40, 0.75, 1.0, 1.0)
        masterFrame.viewSocial.btnFriends.text:SetTextColor(1, 1, 1)
        masterFrame.viewSocial.btnGuild:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
        masterFrame.viewSocial.btnGuild:SetBackdropBorderColor(0.20, 0.28, 0.40, 0.8)
        masterFrame.viewSocial.btnGuild.text:SetTextColor(0.7, 0.7, 0.7)
    else
        masterFrame.viewSocial.btnGuild:SetBackdropColor(0.18, 0.26, 0.40, 1.0)
        masterFrame.viewSocial.btnGuild:SetBackdropBorderColor(0.40, 0.75, 1.0, 1.0)
        masterFrame.viewSocial.btnGuild.text:SetTextColor(1, 1, 1)
        masterFrame.viewSocial.btnFriends:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
        masterFrame.viewSocial.btnFriends:SetBackdropBorderColor(0.20, 0.28, 0.40, 0.8)
        masterFrame.viewSocial.btnFriends.text:SetTextColor(0.7, 0.7, 0.7)
    end

    local rowCount = 0
    local onlineFriendsCount = 0
    local totalFriendsCount = GetNumFriends()

    if socialMode == "friends" then
        for i = 1, totalFriendsCount do
            local name, level, class, area, connected, status = GetFriendInfo(i)
            if connected and name then
                onlineFriendsCount = onlineFriendsCount + 1
                rowCount = rowCount + 1
                local row = friendRows[rowCount] or CreateSocialRow(container, rowCount)
                friendRows[rowCount] = row

                row.targetName = name
                local r, g, b = Utils.GetClassColor(class or "")
                row.nameText:SetText(name)
                row.nameText:SetTextColor(r, g, b)

                local statusStr = (status and status ~= "") and (" (" .. status .. ")") or ""
                row.infoText:SetText(string.format("Lvl %s %s - %s%s", tostring(level or "?"), class or "", area or "Unknown", statusStr))
                row.statusDot:SetVertexColor(0.2, 1.0, 0.4)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(rowCount - 1) * 22)
                row:Show()
            end
        end

        -- Update top header tab text
        masterFrame.tabSocial.text:SetText(string.format("👥 Social (%d/%d)", onlineFriendsCount, totalFriendsCount))
    else
        -- Guild Roster
        if IsInGuild() then
            local numGuild = GetNumGuildMembers()
            for i = 1, math.min(numGuild, 40) do
                local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
                if online and name and name ~= UnitName("player") then
                    rowCount = rowCount + 1
                    local row = guildRows[rowCount] or CreateSocialRow(container, rowCount)
                    guildRows[rowCount] = row

                    row.targetName = name
                    local r, g, b = Utils.GetClassColor(class or "")
                    row.nameText:SetText(name)
                    row.nameText:SetTextColor(r, g, b)
                    row.infoText:SetText(string.format("Lvl %s %s <%s> - %s", tostring(level or "?"), class or "", rank or "", zone or "Unknown"))
                    row.statusDot:SetVertexColor(0.2, 0.8, 1.0) -- Cyan for guildies

                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(rowCount - 1) * 22)
                    row:Show()
                end
            end
        end
    end

    -- Hide unused rows
    for i = rowCount + 1, 50 do
        if friendRows[i] then friendRows[i]:Hide() end
        if guildRows[i] then guildRows[i]:Hide() end
    end
end

-- =========================================================================
-- 8. INPUT DISPATCH & SLASH HANDLING
-- =========================================================================

function PUITalk:HandleInputSubmit(text)
    if not text or text == "" then return end

    local currentTab = talkDB:Get("activeMasterTab") or 1

    if currentTab == 2 and activeDMKey and dmTabs[activeDMKey] then
        -- Direct Whisper Mode
        local targetName = dmTabs[activeDMKey].name or activeDMKey
        SendChatMessage(text, "WHISPER", nil, targetName)
        -- Message will be added to history authoritatively via CHAT_MSG_WHISPER_INFORM
    else
        -- Standard Chat Execution
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox, text)
    end
end

-- =========================================================================
-- 9. OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUITalk:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUITalk", {
        name = "Social_Talk",
        category = "Social",
        label = "PUITalk (Unified Chat & Social Hub)",
        options = {
            {
                key = "divertWhispers",
                type = "checkbox",
                label = "Divert Whispers to Messages Tab",
                desc = "Filters whispers out of standard game chat, routing them cleanly to Tab 2.",
                default = true,
                get = function() return talkDB:Get("divertWhispers") end,
                set = function(v) talkDB:Set("divertWhispers", v) end,
            },
            {
                key = "playSounds",
                type = "checkbox",
                label = "Play Sound Notification on Whisper",
                desc = "Plays an audio chime when an incoming direct message is received.",
                default = true,
                get = function() return talkDB:Get("playSounds") end,
                set = function(v) talkDB:Set("playSounds", v) end,
            },
            {
                key = "autoPopDMs",
                type = "checkbox",
                label = "Auto-Open Messages Tab on Whisper",
                desc = "Automatically displays the PUITalk window and selects Tab 2 on incoming whisper.",
                default = false,
                get = function() return talkDB:Get("autoPopDMs") end,
                set = function(v) talkDB:Set("autoPopDMs", v) end,
            },
            {
                key = "classColors",
                type = "checkbox",
                label = "Class Colored Names",
                desc = "Colors player names by their character class across chat and social tabs.",
                default = true,
                get = function() return talkDB:Get("classColors") end,
                set = function(v)
                    talkDB:Set("classColors", v)
                    PUITalk:UpdateClassCache()
                end,
            },
            {
                key = "stickyChannels",
                type = "checkbox",
                label = "Sticky Chat Channels",
                desc = "Remembers last chat channel across /say, /party, /guild, /raid.",
                default = true,
                get = function() return talkDB:Get("stickyChannels") end,
                set = function(v)
                    talkDB:Set("stickyChannels", v)
                    if v then SetupStickyChannels() end
                end,
            },
            {
                key = "mousewheelScroll",
                type = "checkbox",
                label = "Mousewheel Fast Scrolling",
                desc = "Enables mousewheel fast scrolling on chat frames (Shift: Top/Bottom).",
                default = true,
                get = function() return talkDB:Get("mousewheelScroll") end,
                set = function(v)
                    talkDB:Set("mousewheelScroll", v)
                    if v then SetupMousewheelScrolling() end
                end,
            },
            {
                key = "chatCopy",
                type = "checkbox",
                label = "Chat Copy [C] Button",
                desc = "Shows docked [C] button on chat tabs for 1-click clipboard copying.",
                default = true,
                get = function() return talkDB:Get("chatCopy") end,
                set = function(v)
                    talkDB:Set("chatCopy", v)
                    if v then
                        AttachCopyButtons()
                        for i = 1, 7 do
                            if copyButtons[i] then copyButtons[i]:Show() end
                        end
                    else
                        for i = 1, 7 do
                            if copyButtons[i] then copyButtons[i]:Hide() end
                        end
                    end
                end,
            },
        },
    })
end

-- =========================================================================
-- 10. LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUITalk:OnInitialize()
    SetupChatHooks()
    AttachCopyButtons()
    SetupMousewheelScrolling()
    SetupStickyChannels()
    self:UpdateClassCache()
    self:RegisterOptionsFlare()
    self:CreateMasterFrame()

    -- Console Subcommand Registrations
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("talk", function(argParam, parts)
            argParam = Utils.Trim(argParam or "")
            if parts and parts[2] == "copy" then
                local idx = tonumber(parts[3]) or 1
                PUITalk:OpenCopyFrame(idx)
            else
                if masterFrame and masterFrame:IsShown() then
                    masterFrame:Hide()
                else
                    PUITalk:CreateMasterFrame()
                    masterFrame:Show()
                end
            end
        end, "PUITalk Unified Communication Suite (/pui talk [copy 1-7])")

        -- Backward compatibility aliases
        Primus.Console:RegisterAlias("chat", "talk")
        Primus.Console:RegisterAlias("messenger", "talk")
    end
end

function PUITalk:OnEnable()
    AttachCopyButtons()
    for i = 1, 7 do
        if copyButtons[i] and talkDB:Get("chatCopy") then
            copyButtons[i]:Show()
        end
    end

    -- Incoming Whisper Interception
    Events:Register("CHAT_MSG_WHISPER", "PUITalk", function(owner, event, msg, sender)
        lastWhisperSender = sender
        local key = string.lower(sender)
        PUITalk:AddDMMessage(key, sender, msg, false)
        if talkDB:Get("autoPopDMs") then
            PUITalk:OpenDMConversation(sender)
        else
            PUITalk:RefreshDMTabs()
        end
    end)

    -- Authoritative Outgoing Whisper Interception (Eliminates Double Send!)
    Events:Register("CHAT_MSG_WHISPER_INFORM", "PUITalk", function(owner, event, msg, recipient)
        local key = string.lower(recipient)
        PUITalk:AddDMMessage(key, UnitName("player"), msg, true)
    end)

    -- Social & Class Cache Update Events
    Events:Register("PLAYER_ENTERING_WORLD", "PUITalk", function()
        AttachCopyButtons()
        PUITalk:UpdateClassCache()
    end)
    Events:Register("PARTY_MEMBERS_CHANGED", "PUITalk", function() PUITalk:UpdateClassCache() end)
    Events:Register("RAID_ROSTER_UPDATE", "PUITalk", function() PUITalk:UpdateClassCache() end)
    Events:Register("GUILD_ROSTER_UPDATE", "PUITalk", function()
        PUITalk:UpdateClassCache()
        PUITalk:RefreshSocialView()
    end)
    Events:Register("FRIENDLIST_UPDATE", "PUITalk", function()
        PUITalk:UpdateClassCache()
        PUITalk:RefreshSocialView()
    end)
    Events:Register("PLAYER_TARGET_CHANGED", "PUITalk", function() CacheUnitClass("target") end)

    -- Periodic Social Roster Polling (10s)
    Time:Every(10.0, function()
        if masterFrame and masterFrame:IsShown() and (talkDB:Get("activeMasterTab") == 3) then
            ShowFriends()
            if IsInGuild() then GuildRoster() end
            PUITalk:RefreshSocialView()
        end
    end, "PUITalk")
end

function PUITalk:OnDisable()
    Time:CancelAll("PUITalk")
    Events:UnregisterOwner("PUITalk")

    for i = 1, 7 do
        if copyButtons[i] then
            copyButtons[i]:Hide()
        end
    end

    if copyFrame and copyFrame:IsShown() then copyFrame:Hide() end
    if urlFrame and urlFrame:IsShown() then urlFrame:Hide() end
    if masterFrame and masterFrame:IsShown() then masterFrame:Hide() end
end
