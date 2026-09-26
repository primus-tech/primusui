--[[
    PrimusUI Module: PUITalk (Autonomous Chat Engine, Event Subscriptions & Selection)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - 100% Autonomous Chat Engine taking over all game channels and addon messages.
    - Permanent suppression of default Blizzard chat frames (ChatFrame1..7).
    - Event routing for SAY, YELL, PARTY, RAID, GUILD, OFFICER, CHANNELS, SYSTEM, LOOT, EMOTES.
    - Timestamping, class-colored player names, and clickable web URLs.
    - In-place drag-highlight selectable text mode and popout copy modal.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Hider   = Primus.Hider

local copyFrame = nil
local urlFrame  = nil

-- =========================================================================
-- 1. ADD MESSAGE TO PUITALK CHAT STREAM
-- =========================================================================

function PUITalk:AddChatMessage(text, r, g, b, isRaw)
    if not text or text == "" then return end

    r = r or 1.0
    g = g or 1.0
    b = b or 1.0

    local timeStamp = self:GetTimestamp()
    local cleanText = self:CleanChatText(text)
    table.insert(self.chatBuffers[1], { time = timeStamp, text = cleanText })
    if table.getn(self.chatBuffers[1]) > 400 then
        table.remove(self.chatBuffers[1], 1)
    end

    local formatted = text
    if not isRaw then
        formatted = self:LinkifyURLs(text)
    end

    if self.masterFrame and self.masterFrame.viewChat and self.masterFrame.viewChat.msgFrame then
        local msgFrame = self.masterFrame.viewChat.msgFrame
        msgFrame:AddMessage(formatted, r, g, b)
    end
end

-- =========================================================================
-- 2. GAME CHAT EVENT DISPATCHERS
-- =========================================================================

function PUITalk:RegisterChatEvents()
    -- Say & Yell
    Events:Register("CHAT_MSG_SAY", "PUITalk_Chat", function(owner, event, msg, sender, lang)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffffffff[Say]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("SAY")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_YELL", "PUITalk_Chat", function(owner, event, msg, sender, lang)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4040[Yell]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("YELL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Emotes
    Events:Register("CHAT_MSG_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff8040[Emote]|r %s %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("EMOTE")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_TEXT_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffff8040%s|r", PUITalk:GetTimestamp(), msg)
        local r, g, b = PUITalk:GetChannelColor("EMOTE")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Party & Raid
    Events:Register("CHAT_MSG_PARTY", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffaaaaee[Party]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("PARTY")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff7f00[Raid]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID_LEADER", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4800[Raid Leader]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID_WARNING")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_RAID_WARNING", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cffff4800[Raid Warning]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("RAID_WARNING")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Guild & Officer
    Events:Register("CHAT_MSG_GUILD", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cff40ff40[Guild]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("GUILD")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    Events:Register("CHAT_MSG_OFFICER", "PUITalk_Chat", function(owner, event, msg, sender)
        local colored = PUITalk:GetColoredName(sender)
        local formatted = string.format("%s |cff40c040[Officer]|r [%s]: %s", PUITalk:GetTimestamp(), colored, msg)
        local r, g, b = PUITalk:GetChannelColor("OFFICER")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- Custom & Standard Channels (General, Trade, LocalDefense, LFG, World)
    Events:Register("CHAT_MSG_CHANNEL", "PUITalk_Chat", function(owner, event, msg, sender, lang, channelName, target, channelNumber)
        local colored = PUITalk:GetColoredName(sender)
        local cNum = channelNumber or ""
        local cName = channelName or "Channel"
        local chanBadge = string.format("[%s. %s]", tostring(cNum), cName)
        local formatted = string.format("%s |cffe6c099%s|r [%s]: %s", PUITalk:GetTimestamp(), chanBadge, colored, msg)
        local r, g, b = PUITalk:GetChannelColor("CHANNEL")
        PUITalk:AddChatMessage(formatted, r, g, b)
    end)

    -- System, AFK, DND, Notice
    Events:Register("CHAT_MSG_SYSTEM", "PUITalk_Chat", function(owner, event, msg)
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)

    Events:Register("CHAT_MSG_CHANNEL_NOTICE", "PUITalk_Chat", function(owner, event, action, _, _, channelName)
        local formatted = string.format("%s |cff888888[%s]: %s|r", PUITalk:GetTimestamp(), channelName or "Channel", action or "")
        PUITalk:AddChatMessage(formatted, 0.6, 0.6, 0.6)
    end)

    -- Monster Emotes / Say / Yell
    Events:Register("CHAT_MSG_MONSTER_SAY", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffffd100[%s]:|r %s", PUITalk:GetTimestamp(), sender or "Monster", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.85, 0.4)
    end)

    Events:Register("CHAT_MSG_MONSTER_YELL", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffff4040[%s yells]:|r %s", PUITalk:GetTimestamp(), sender or "Monster", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.35, 0.35)
    end)

    Events:Register("CHAT_MSG_MONSTER_EMOTE", "PUITalk_Chat", function(owner, event, msg, sender)
        local formatted = string.format("%s |cffff8040%s %s|r", PUITalk:GetTimestamp(), sender or "", msg)
        PUITalk:AddChatMessage(formatted, 1.0, 0.5, 0.25)
    end)

    -- Loot & Money
    Events:Register("CHAT_MSG_LOOT", "PUITalk_Chat", function(owner, event, msg)
        local formatted = string.format("%s |cff00cc00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 0.0, 0.8, 0.0)
    end)

    Events:Register("CHAT_MSG_MONEY", "PUITalk_Chat", function(owner, event, msg)
        local formatted = string.format("%s |cffffff00%s|r", PUITalk:GetTimestamp(), msg)
        PUITalk:AddChatMessage(formatted, 1.0, 1.0, 0.0)
    end)
end

-- =========================================================================
-- 3. PERMANENT BLIZZARD CHAT FRAME SUPPRESSION & ADDOUN ROUTING
-- =========================================================================

function PUITalk:SuppressBlizzardChat()
    -- Hook DEFAULT_CHAT_FRAME to capture 100% of addon output and print statements
    if DEFAULT_CHAT_FRAME and not DEFAULT_CHAT_FRAME.primusPUITalkHooked then
        local origAddMessage = DEFAULT_CHAT_FRAME.AddMessage
        DEFAULT_CHAT_FRAME.AddMessage = function(self, text, r, g, b, id)
            if text then
                PUITalk:AddChatMessage(tostring(text), r, g, b)
            end
        end
        DEFAULT_CHAT_FRAME.primusPUITalkHooked = true
    end

    -- Suppress Blizzard Chat Frames 1..7 into dummy frame
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

    -- Suppress ChatFrameEditBox
    if ChatFrameEditBox then
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
        ChatFrameEditBox:Hide()
    end
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton.Show = function() end
    end
end

-- =========================================================================
-- 4. CLICKABLE URL & COPY DIALOG MODALS
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

    local editContainer = CreateFrame("Frame", nil, f)
    editContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
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
    local f = self:CreateCopyFrame()
    local buffer = self.chatBuffers[1] or {}
    local totalLines = table.getn(buffer)
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
-- 5. IN-PLACE SELECTABLE CHAT OVERLAY (CLICK, DRAG-HIGHLIGHT, & CTRL+C)
-- =========================================================================

function PUITalk:CreateSelectableOverlay(parent, modeName)
    if not parent then return nil end
    if parent.selectOverlay then return parent.selectOverlay end

    local overlay = CreateFrame("Frame", "Primus_PUITalkSelectOverlay_" .. (modeName or "Chat"), parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 15)
    overlay:SetBackdrop(Media:Fetch("border", "1Pixel"))
    overlay:SetBackdropColor(0.04, 0.05, 0.07, 0.98)
    overlay:SetBackdropBorderColor(0.20, 0.50, 0.90, 1.0)
    overlay:EnableMouse(true)
    overlay:Hide()

    local topBar = CreateFrame("Frame", nil, overlay)
    topBar:SetPoint("TOPLEFT", overlay, "TOPLEFT", 4, -4)
    topBar:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -4, -4)
    topBar:SetHeight(20)
    topBar:SetBackdrop(Media:Fetch("border", "1Pixel"))
    topBar:SetBackdropColor(0.10, 0.14, 0.22, 1.0)
    topBar:SetBackdropBorderColor(0.25, 0.45, 0.75, 1.0)

    local backBtn = CreateFrame("Button", nil, topBar)
    backBtn:SetWidth(110)
    backBtn:SetHeight(16)
    backBtn:SetPoint("LEFT", topBar, "LEFT", 2, 0)
    backBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    backBtn:SetBackdropColor(0.15, 0.20, 0.30, 1.0)
    backBtn:SetBackdropBorderColor(0.30, 0.60, 0.90, 1.0)
    local bkTxt = backBtn:CreateFontString(nil, "OVERLAY")
    bkTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    bkTxt:SetPoint("CENTER", 0, 0)
    bkTxt:SetText("◀ Return to Live")
    backBtn.text = bkTxt
    backBtn:SetScript("OnClick", function()
        PUITalk:ToggleSelectableMode()
    end)

    local selectAllBtn = CreateFrame("Button", nil, topBar)
    selectAllBtn:SetWidth(75)
    selectAllBtn:SetHeight(16)
    selectAllBtn:SetPoint("LEFT", backBtn, "RIGHT", 4, 0)
    selectAllBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    selectAllBtn:SetBackdropColor(0.15, 0.25, 0.15, 1.0)
    selectAllBtn:SetBackdropBorderColor(0.30, 0.80, 0.30, 1.0)
    local saTxt = selectAllBtn:CreateFontString(nil, "OVERLAY")
    saTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    saTxt:SetPoint("CENTER", 0, 0)
    saTxt:SetText("Select All")
    selectAllBtn.text = saTxt

    local infoText = topBar:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    infoText:SetPoint("LEFT", selectAllBtn, "RIGHT", 6, 0)
    infoText:SetPoint("RIGHT", topBar, "RIGHT", -4, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetText(Utils.ColorText("Selectable Mode", "69ccf0") .. " |cffaaaaaa// Drag to highlight, Ctrl+C to copy|r")

    local scroll = CreateFrame("ScrollFrame", "Primus_PUITalkSelectScroll_" .. (modeName or "Chat"), overlay, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -24, 6)

    local editBox = CreateFrame("EditBox", "Primus_PUITalkSelectEdit_" .. (modeName or "Chat"), scroll)
    editBox:SetWidth(380)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(Media:Fetch("font", "Default"), 10, "")
    editBox:SetTextColor(0.95, 0.95, 0.95, 1.0)
    editBox:SetScript("OnEscapePressed", function()
        PUITalk:ToggleSelectableMode()
    end)
    editBox:SetScript("OnTextChanged", function()
        local s = this:GetParent()
        if s and s.UpdateScrollChildRect then
            s:UpdateScrollChildRect()
        end
    end)
    scroll:SetScrollChild(editBox)

    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText(0)
    end)

    overlay.scroll = scroll
    overlay.editBox = editBox
    overlay.topBar = topBar
    parent.selectOverlay = overlay
    return overlay
end

function PUITalk:ToggleSelectableMode(tabIndex)
    tabIndex = tabIndex or self.db:Get("activeMasterTab") or 1
    local masterFrame = self.masterFrame
    if not masterFrame then return end

    if tabIndex == 1 then
        local viewChat = masterFrame.viewChat
        if not viewChat then return end
        local overlay = viewChat.selectOverlay or self:CreateSelectableOverlay(viewChat, "Chat")

        if overlay:IsShown() then
            overlay:Hide()
            if viewChat.msgFrame then viewChat.msgFrame:Show() end
        else
            local buffer = self.chatBuffers[1] or {}
            local totalLines = table.getn(buffer)
            local lines = {}
            for i = 1, totalLines do
                local entry = buffer[i]
                local clean = self:CleanChatText(entry.text)
                table.insert(lines, string.format("[%s] %s", entry.time, clean))
            end
            local fullText = table.concat(lines, "\n")
            overlay.editBox:SetText(fullText)
            overlay:Show()
            if viewChat.msgFrame then viewChat.msgFrame:Hide() end
            overlay.editBox:SetFocus()
            overlay.scroll:ScrollToBottom()
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: Selectable chat mode active! Click & drag mouse to highlight, Ctrl+C to copy.", "69ccf0"))
        end
    elseif tabIndex == 2 then
        local viewMessages = masterFrame.viewMessages
        if not viewMessages then return end
        local overlay = viewMessages.selectOverlay or self:CreateSelectableOverlay(viewMessages, "Messages")

        if overlay:IsShown() then
            overlay:Hide()
            if viewMessages.msgFrame then viewMessages.msgFrame:Show() end
        else
            local activeKey = self.activeDMKey or ""
            local history = self.conversationHistory[activeKey] or {}
            local count = table.getn(history)
            local lines = {}
            for i = 1, count do
                local entry = history[i]
                local clean = self:CleanChatText(entry.msg)
                table.insert(lines, clean)
            end
            local fullText = table.concat(lines, "\n")
            overlay.editBox:SetText(fullText)
            overlay:Show()
            if viewMessages.msgFrame then viewMessages.msgFrame:Hide() end
            overlay.editBox:SetFocus()
            overlay.scroll:ScrollToBottom()
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: Selectable messages mode active! Click & drag mouse to highlight, Ctrl+C to copy.", "69ccf0"))
        end
    end
end
