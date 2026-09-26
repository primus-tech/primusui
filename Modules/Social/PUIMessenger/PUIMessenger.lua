--[[
    PrimusUI Module: PUIMessenger (AIM-Style Buddy List & Tabbed Chat Rooms)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. AIM-style Buddy List window with collapsible groups:
       - Online Friends (real-time friends list)
       - Online Guildies (real-time guild roster)
       - Party & Raid Members
       - Recent Conversations / DMs
    2. Tabbed Instant Message (IM) & Chat Room Windows:
       - Direct Whispers in isolated tabs with unread counters
       - Optional Tabbed Chat Rooms (#guild, #party, #raid, #say, #trade)
       - Clean high-contrast message log with mousewheel scrolling
       - Instant reply editbox with command history
       - Sound alerts on incoming messages
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMessenger = Primus.PUIMessenger or {}
Primus.PUIMessenger = PUIMessenger
_G.PUIMessenger = PUIMessenger
Primus:RegisterModule("PUIMessenger", PUIMessenger, "Social")

local DB      = Primus.DB
local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Time    = Primus.Time
local PUIMover = Primus.PUIMover

local messengerDB = DB:RegisterNamespace("PUIMessenger", {
    enabled = true,
    autoPopIM = true,
    playSounds = true,
    enableChatRooms = true,
    recentDMs = {},
})

-- UI Windows
local buddyWindow = nil
local imWindow = nil

-- Conversation & Tab Management
local tabs = {}
local activeTabKey = nil
local tabPool = {}
local recentDMs = {}

-- Message History Store per conversation key
local conversationHistory = {}

-- Channel definitions for Tabbed Chat Rooms
local ROOM_TYPES = {
    ["#guild"] = { name = "Guild", channelType = "GUILD", event = "CHAT_MSG_GUILD", color = { 0.25, 1.0, 0.25 } },
    ["#officer"] = { name = "Officer", channelType = "OFFICER", event = "CHAT_MSG_OFFICER", color = { 0.25, 0.75, 0.25 } },
    ["#party"] = { name = "Party", channelType = "PARTY", event = "CHAT_MSG_PARTY", color = { 0.67, 0.67, 1.0 } },
    ["#raid"]  = { name = "Raid",  channelType = "RAID",  event = "CHAT_MSG_RAID",  color = { 1.0, 0.5, 0.0 } },
    ["#say"]   = { name = "Say",   channelType = "SAY",   event = "CHAT_MSG_SAY",   color = { 1.0, 1.0, 1.0 } },
}

-- =========================================================================
-- MESSAGE FORMATTING & HELPERS
-- =========================================================================

local function GetTimestamp()
    local hour, minute = GetGameTime()
    return string.format("[%02d:%02d]", hour, minute)
end

local function GetClassColorHex(className)
    local r, g, b = Utils.GetClassColor(className or "")
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- =========================================================================
-- IM WINDOW & CONVERSATION TABS
-- =========================================================================

function PUIMessenger:CreateIMWindow()
    if imWindow then return imWindow end

    imWindow = CreateFrame("Frame", "Primus_PUIMessengerWindow", UIParent)
    imWindow:SetWidth(380)
    imWindow:SetHeight(280)
    imWindow:SetPoint("CENTER", UIParent, "CENTER", 80, 0)
    imWindow:SetBackdrop(Media:Fetch("border", "1Pixel"))
    imWindow:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    imWindow:SetBackdropBorderColor(0.2, 0.5, 0.9, 1) -- AIM Blue
    imWindow:SetMovable(true)
    imWindow:EnableMouse(true)
    imWindow:RegisterForDrag("LeftButton")
    imWindow:SetScript("OnDragStart", function() this:StartMoving() end)
    imWindow:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    imWindow:Hide()

    -- Title Bar / Drag Header
    local header = CreateFrame("Frame", nil, imWindow)
    header:SetPoint("TOPLEFT", imWindow, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", imWindow, "TOPRIGHT", -4, -4)
    header:SetHeight(22)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.12, 0.16, 0.24, 1.0)
    header:SetBackdropBorderColor(0.2, 0.4, 0.8, 1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)
    title:SetText(Utils.ColorText("PUIMessenger", "3399ff") .. " |cff888888(Instant Message)|r")
    imWindow.title = title

    -- Close Button [X]
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetWidth(16)
    closeBtn:SetHeight(16)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeBtn:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    closeBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetText("X")
    closeBtn:SetScript("OnClick", function() imWindow:Hide() end)

    -- Tab Bar Container
    local tabBar = CreateFrame("Frame", "Primus_PUIMessengerTabBar", imWindow)
    tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    tabBar:SetHeight(24)
    imWindow.tabBar = tabBar

    -- Active Conversation Header Info
    local infoBar = CreateFrame("Frame", nil, imWindow)
    infoBar:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -2)
    infoBar:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -2)
    infoBar:SetHeight(18)
    infoBar:SetBackdrop(Media:Fetch("border", "1Pixel"))
    infoBar:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
    infoBar:SetBackdropBorderColor(0.15, 0.2, 0.3, 0.8)
    imWindow.infoBar = infoBar

    local infoText = infoBar:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    infoText:SetPoint("LEFT", infoBar, "LEFT", 6, 0)
    infoText:SetText("Direct Conversation")
    imWindow.infoText = infoText

    -- Chat Message Display Frame (ScrollingMessageFrame)
    local msgFrame = CreateFrame("ScrollingMessageFrame", "Primus_PUIMessengerMsgFrame", imWindow)
    msgFrame:SetPoint("TOPLEFT", infoBar, "BOTTOMLEFT", 4, -4)
    msgFrame:SetPoint("BOTTOMRIGHT", imWindow, "BOTTOMRIGHT", -4, 30)
    msgFrame:SetFont(Media:Fetch("font", "Default"), 10, "")
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(300)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function()
        if arg1 > 0 then
            msgFrame:ScrollUp()
        else
            msgFrame:ScrollDown()
        end
    end)
    imWindow.msgFrame = msgFrame

    -- Message Input EditBox
    local editBox = CreateFrame("EditBox", "Primus_PUIMessengerInput", imWindow)
    editBox:SetPoint("BOTTOMLEFT", imWindow, "BOTTOMLEFT", 6, 6)
    editBox:SetPoint("BOTTOMRIGHT", imWindow, "BOTTOMRIGHT", -6, 6)
    editBox:SetHeight(20)
    editBox:SetBackdrop(Media:Fetch("border", "1Pixel"))
    editBox:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    editBox:SetBackdropBorderColor(0.2, 0.4, 0.7, 1)
    editBox:SetFont(Media:Fetch("font", "Default"), 10, "")
    editBox:SetTextInsets(6, 6, 0, 0)
    editBox:SetAutoFocus(false)
    editBox:SetHistoryLines(20)

    editBox:SetScript("OnEnterPressed", function()
        local text = this:GetText()
        if text and text ~= "" then
            PUIMessenger:SendMessage(activeTabKey, text)
            this:AddHistoryLine(text)
            this:SetText("")
        end
    end)
    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    imWindow.editBox = editBox

    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(imWindow, "PUIMessenger_IM", "PUIMessenger: Instant Message Window", "SOCIAL")
    end
    return imWindow
end

-- Refresh and Render the Tab Bar
function PUIMessenger:RefreshTabs()
    if not imWindow then return end

    local xOffset = 0
    for key, tab in pairs(tabs) do
        local btn = tab.button
        if not btn then
            btn = CreateFrame("Button", "Primus_PUIMessengerTab_" .. key, imWindow.tabBar)
            btn:SetHeight(22)
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
                PUIMessenger:CloseTab(this:GetParent().key)
            end)
            btn.closeBtn = close

            btn:SetScript("OnClick", function()
                PUIMessenger:SelectTab(this.key)
            end)
            tab.button = btn
        end

        local displayName = tab.name
        if tab.unread and tab.unread > 0 then
            displayName = displayName .. string.format(" |cffffcc00(%d)|r", tab.unread)
        end

        btn.text:SetText(displayName)
        local textWidth = btn.text:GetStringWidth() or 40
        local btnWidth = math.max(60, textWidth + 24)
        btn:SetWidth(btnWidth)

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", imWindow.tabBar, "LEFT", xOffset, 0)
        xOffset = xOffset + btnWidth + 3

        if key == activeTabKey then
            btn:SetBackdropColor(0.18, 0.24, 0.35, 1.0)
            btn:SetBackdropBorderColor(0.4, 0.7, 1.0, 1.0)
            btn.text:SetTextColor(1.0, 1.0, 1.0)
        else
            btn:SetBackdropColor(0.08, 0.10, 0.14, 0.8)
            btn:SetBackdropBorderColor(0.2, 0.25, 0.35, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
        btn:Show()
    end
end

-- Open or Switch to a Tab
function PUIMessenger:OpenConversation(targetKey, targetName, isRoom)
    self:CreateIMWindow()
    imWindow:Show()

    if not tabs[targetKey] then
        tabs[targetKey] = {
            key = targetKey,
            name = targetName or targetKey,
            isRoom = isRoom or false,
            unread = 0,
        }
        if not conversationHistory[targetKey] then
            conversationHistory[targetKey] = {}
        end
    end

    self:SelectTab(targetKey)
end

-- Select Active Tab
function PUIMessenger:SelectTab(key)
    if not tabs[key] then return end
    activeTabKey = key
    tabs[key].unread = 0

    local tab = tabs[key]
    if tab.isRoom then
        local rInfo = ROOM_TYPES[key]
        imWindow.infoText:SetText(string.format("Chat Room: |cff%s%s|r", GetClassColorHex(""), tab.name))
    else
        imWindow.infoText:SetText(string.format("Direct Message with: |cff33ccff%s|r", tab.name))
    end

    -- Reload messages into msgFrame
    imWindow.msgFrame:Clear()
    local history = conversationHistory[key] or {}
    local count = table.getn(history)
    for i = 1, count do
        local entry = history[i]
        imWindow.msgFrame:AddMessage(entry.msg, entry.r, entry.g, entry.b)
    end
    imWindow.msgFrame:ScrollToBottom()

    self:RefreshTabs()
    if imWindow and imWindow.editBox and imWindow:IsShown() and not UnitAffectingCombat("player") then
        imWindow.editBox:SetFocus()
    end
end

-- Close a Conversation Tab
function PUIMessenger:CloseTab(key)
    if tabs[key] then
        if tabs[key].button then
            tabs[key].button:Hide()
            tabs[key].button = nil
        end
        tabs[key] = nil
    end

    if activeTabKey == key then
        activeTabKey = nil
        for nextKey, _ in pairs(tabs) do
            self:SelectTab(nextKey)
            return
        end
        imWindow:Hide()
    else
        self:RefreshTabs()
    end
end

-- Append Message to Conversation History and Display
function PUIMessenger:AddChatMessage(key, sender, text, isOutgoing, r, g, b)
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

    if activeTabKey == key and imWindow and imWindow:IsShown() then
        imWindow.msgFrame:AddMessage(formattedMsg, r, g, b)
        imWindow.msgFrame:ScrollToBottom()
    else
        if tabs[key] then
            tabs[key].unread = (tabs[key].unread or 0) + 1
            self:RefreshTabs()
        end
    end

    if messengerDB:Get("playSounds", true) and not isOutgoing then
        PlaySound("TellMessage")
    end
end

-- Send Message Out via SendChatMessage
function PUIMessenger:SendMessage(key, text)
    if not key or not text or text == "" then return end

    local tab = tabs[key]
    if not tab then return end

    if tab.isRoom then
        local rInfo = ROOM_TYPES[key]
        if rInfo then
            SendChatMessage(text, rInfo.channelType)
        end
    else
        -- Direct Whisper
        SendChatMessage(text, "WHISPER", nil, tab.name)
        self:AddChatMessage(key, UnitName("player"), text, true, 1.0, 1.0, 0.8)
    end
end

-- =========================================================================
-- BUDDY LIST WINDOW (AIM CONTACT LIST)
-- =========================================================================

local buddyRows = {}

function PUIMessenger:CreateBuddyListWindow()
    if buddyWindow then return buddyWindow end

    buddyWindow = CreateFrame("Frame", "Primus_PUIBuddyList", UIParent)
    buddyWindow:SetWidth(200)
    buddyWindow:SetHeight(380)
    buddyWindow:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -140)
    buddyWindow:SetBackdrop(Media:Fetch("border", "1Pixel"))
    buddyWindow:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    buddyWindow:SetBackdropBorderColor(0.2, 0.5, 0.9, 1)
    buddyWindow:SetMovable(true)
    buddyWindow:EnableMouse(true)
    buddyWindow:RegisterForDrag("LeftButton")
    buddyWindow:SetScript("OnDragStart", function() this:StartMoving() end)
    buddyWindow:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    buddyWindow:Hide()

    -- Header / Title
    local header = CreateFrame("Frame", nil, buddyWindow)
    header:SetPoint("TOPLEFT", buddyWindow, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", buddyWindow, "TOPRIGHT", -4, -4)
    header:SetHeight(24)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.12, 0.16, 0.24, 1.0)
    header:SetBackdropBorderColor(0.2, 0.4, 0.8, 1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)
    title:SetText(Utils.ColorText("PUIMessenger: Buddy List", "3399ff"))
    buddyWindow.title = title

    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetWidth(16)
    closeBtn:SetHeight(16)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeBtn:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    closeBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local cT = closeBtn:CreateFontString(nil, "OVERLAY")
    cT:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    cT:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    cT:SetText("X")
    closeBtn:SetScript("OnClick", function() buddyWindow:Hide() end)

    -- Player Status / Presence Banner
    local statusBanner = CreateFrame("Frame", nil, buddyWindow)
    statusBanner:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    statusBanner:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    statusBanner:SetHeight(20)
    statusBanner:SetBackdrop(Media:Fetch("border", "1Pixel"))
    statusBanner:SetBackdropColor(0.08, 0.1, 0.14, 0.8)
    statusBanner:SetBackdropBorderColor(0.15, 0.2, 0.3, 0.8)

    local pNameText = statusBanner:CreateFontString(nil, "OVERLAY")
    pNameText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    pNameText:SetPoint("LEFT", statusBanner, "LEFT", 6, 0)
    local _, pClass = UnitClass("player")
    local r, g, b = Utils.GetClassColor(pClass or "WARRIOR")
    pNameText:SetText(string.format("|cff%s%s|r (Online)", GetClassColorHex(pClass), UnitName("player") or "Player"))
    buddyWindow.pNameText = pNameText

    -- Quick Room Launcher (Guild / Party / Raid)
    local roomBar = CreateFrame("Frame", nil, buddyWindow)
    roomBar:SetPoint("TOPLEFT", statusBanner, "BOTTOMLEFT", 0, -2)
    roomBar:SetPoint("TOPRIGHT", statusBanner, "BOTTOMRIGHT", 0, -2)
    roomBar:SetHeight(20)

    local function CreateRoomBtn(label, key, name, x)
        local btn = CreateFrame("Button", nil, roomBar)
        btn:SetWidth(58)
        btn:SetHeight(18)
        btn:SetPoint("LEFT", roomBar, "LEFT", x, 0)
        btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
        btn:SetBackdropColor(0.1, 0.12, 0.16, 0.9)
        btn:SetBackdropBorderColor(0.2, 0.4, 0.7, 1)
        local txt = btn:CreateFontString(nil, "OVERLAY")
        txt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(label)
        btn:SetScript("OnClick", function()
            PUIMessenger:OpenConversation(key, name, true)
        end)
        return btn
    end

    CreateRoomBtn("#Guild", "#guild", "Guild", 0)
    CreateRoomBtn("#Party", "#party", "Party", 62)
    CreateRoomBtn("#Raid", "#raid", "Raid", 124)

    -- Scrollable Buddy Container
    local listContainer = CreateFrame("Frame", nil, buddyWindow)
    listContainer:SetPoint("TOPLEFT", roomBar, "BOTTOMLEFT", 0, -4)
    listContainer:SetPoint("BOTTOMRIGHT", buddyWindow, "BOTTOMRIGHT", -4, 4)
    buddyWindow.listContainer = listContainer

    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(buddyWindow, "PUIMessenger_BuddyList", "PUIMessenger: Buddy List Window", "SOCIAL")
    end
    return buddyWindow
end

local function CreateBuddyRow(parent, index)
    local row = CreateFrame("Button", "Primus_PUIBuddyRow_" .. index, parent)
    row:SetWidth(190)
    row:SetHeight(18)
    row:SetBackdrop(Media:Fetch("border", "1Pixel"))
    row:SetBackdropColor(0.06, 0.08, 0.10, 0.6)
    row:SetBackdropBorderColor(0.12, 0.16, 0.22, 0.6)

    local statusDot = row:CreateTexture(nil, "ARTWORK")
    statusDot:SetWidth(6)
    statusDot:SetHeight(6)
    statusDot:SetPoint("LEFT", row, "LEFT", 4, 0)
    statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    statusDot:SetVertexColor(0.2, 1.0, 0.4) -- Green online
    row.statusDot = statusDot

    local nameText = row:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    nameText:SetPoint("LEFT", statusDot, "RIGHT", 4, 0)
    nameText:SetWidth(80)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local zoneText = row:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(Media:Fetch("font", "Default"), 8, "")
    zoneText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    zoneText:SetWidth(90)
    zoneText:SetJustifyH("RIGHT")
    zoneText:SetTextColor(0.65, 0.65, 0.65)
    row.zoneText = zoneText

    row:SetScript("OnClick", function()
        if this.buddyName then
            PUIMessenger:OpenConversation(string.lower(this.buddyName), this.buddyName, false)
        end
    end)

    buddyRows[index] = row
    return row
end

-- Refresh and Populate Buddy List
function PUIMessenger:UpdateBuddyList()
    if not buddyWindow or not buddyWindow:IsShown() then return end

    local rowCount = 0

    -- 1. Online Friends
    local numFriends = GetNumFriends()
    if numFriends > 0 then
        for i = 1, numFriends do
            local name, level, class, area, connected, status = GetFriendInfo(i)
            if connected and name then
                rowCount = rowCount + 1
                local row = buddyRows[rowCount] or CreateBuddyRow(buddyWindow.listContainer, rowCount)
                row.buddyName = name
                local r, g, b = Utils.GetClassColor(class or "")
                row.nameText:SetText(name)
                row.nameText:SetTextColor(r, g, b)
                row.zoneText:SetText(string.sub(area or "", 1, 14))
                row.statusDot:SetVertexColor(0.2, 1.0, 0.4)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", buddyWindow.listContainer, "TOPLEFT", 0, -(rowCount - 1) * 20)
                row:Show()
            end
        end
    end

    -- 2. Online Guild Members (if in Guild)
    if IsInGuild() then
        local numGuild = GetNumGuildMembers()
        for i = 1, math.min(numGuild, 30) do
            local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
            if online and name and name ~= UnitName("player") then
                rowCount = rowCount + 1
                local row = buddyRows[rowCount] or CreateBuddyRow(buddyWindow.listContainer, rowCount)
                row.buddyName = name
                local r, g, b = Utils.GetClassColor(class or "")
                row.nameText:SetText(name)
                row.nameText:SetTextColor(r, g, b)
                row.zoneText:SetText(string.sub(zone or "", 1, 14))
                row.statusDot:SetVertexColor(0.2, 0.8, 1.0) -- Cyan for guildies

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", buddyWindow.listContainer, "TOPLEFT", 0, -(rowCount - 1) * 20)
                row:Show()
            end
        end
    end

    -- Hide unused rows
    for i = rowCount + 1, 40 do
        if buddyRows[i] then buddyRows[i]:Hide() end
    end
end

-- =========================================================================
-- INITIALIZATION & EVENT HOOKS
-- =========================================================================

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIMessenger:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIMessenger", "Social", {
        title = "PUIMessenger: Buddy List & IM",
        description = "AIM-style buddy list, whisper tabs, and multi-channel chat rooms.",
        fields = {
            {
                key = "enabled",
                label = "Enable PUIMessenger",
                type = "checkbox",
                default = true,
                get = function() return messengerDB:Get("enabled", true) end,
                set = function(val)
                    messengerDB:Set("enabled", val)
                    if val then PUIMessenger:OnEnable() else PUIMessenger:OnDisable() end
                end,
            },
            {
                key = "autoPopIM",
                label = "Auto-Open IM Window on Incoming Whisper",
                type = "checkbox",
                default = true,
                get = function() return messengerDB:Get("autoPopIM", true) end,
                set = function(val) messengerDB:Set("autoPopIM", val) end,
            },
            {
                key = "playSounds",
                label = "Play Sound Notification on Message",
                type = "checkbox",
                default = true,
                get = function() return messengerDB:Get("playSounds", true) end,
                set = function(val) messengerDB:Set("playSounds", val) end,
            },
            {
                key = "enableChatRooms",
                label = "Enable Tabbed Chat Rooms (#guild, #party, #raid)",
                type = "checkbox",
                default = true,
                get = function() return messengerDB:Get("enableChatRooms", true) end,
                set = function(val) messengerDB:Set("enableChatRooms", val) end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUIMessenger:OnInitialize()
    self:RegisterOptionsFlare()
    self:CreateBuddyListWindow()
    self:CreateIMWindow()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("messenger", function(argParam)
            if argParam and argParam ~= "" then
                local target = string.gsub(argParam, "^%s*(.-)%s*$", "%1")
                PUIMessenger:OpenConversation(string.lower(target), target, false)
            else
                if buddyWindow and buddyWindow:IsShown() then
                    buddyWindow:Hide()
                else
                    if not buddyWindow then PUIMessenger:CreateBuddyListWindow() end
                    buddyWindow:Show()
                    PUIMessenger:UpdateBuddyList()
                end
            end
        end, "PUIMessenger Instant Messenger & Buddy List (/pui messenger [player])")
    end
end

function PUIMessenger:OnEnable()
    -- Intercept Incoming Whispers
    Events:Register("CHAT_MSG_WHISPER", "PUIMessenger", function(owner, event, msg, sender)
        local key = string.lower(sender)
        PUIMessenger:AddChatMessage(key, sender, msg, false)
        if messengerDB:Get("autoPopIM", true) then
            PUIMessenger:OpenConversation(key, sender, false)
        end
    end)

    -- Intercept Outgoing Whispers
    Events:Register("CHAT_MSG_WHISPER_INFORM", "PUIMessenger", function(owner, event, msg, recipient)
        local key = string.lower(recipient)
        PUIMessenger:AddChatMessage(key, UnitName("player"), msg, true)
    end)

    -- Intercept Chat Rooms
    Events:Register("CHAT_MSG_GUILD", "PUIMessenger", function(owner, event, msg, sender)
        if sender ~= UnitName("player") and messengerDB:Get("enableChatRooms", true) then
            PUIMessenger:AddChatMessage("#guild", sender, msg, false, 0.25, 1.0, 0.25)
        end
    end)

    Events:Register("CHAT_MSG_PARTY", "PUIMessenger", function(owner, event, msg, sender)
        if sender ~= UnitName("player") and messengerDB:Get("enableChatRooms", true) then
            PUIMessenger:AddChatMessage("#party", sender, msg, false, 0.67, 0.67, 1.0)
        end
    end)

    Events:Register("CHAT_MSG_RAID", "PUIMessenger", function(owner, event, msg, sender)
        if sender ~= UnitName("player") and messengerDB:Get("enableChatRooms", true) then
            PUIMessenger:AddChatMessage("#raid", sender, msg, false, 1.0, 0.5, 0.0)
        end
    end)

    Events:Register("FRIENDLIST_UPDATE", "PUIMessenger", function()
        PUIMessenger:UpdateBuddyList()
    end)
    Events:Register("GUILD_ROSTER_UPDATE", "PUIMessenger", function()
        PUIMessenger:UpdateBuddyList()
    end)

    -- Periodic Buddy List Refresh (10s)
    Time:Every(10.0, function()
        if buddyWindow and buddyWindow:IsShown() then
            ShowFriends()
            if IsInGuild() then GuildRoster() end
            PUIMessenger:UpdateBuddyList()
        end
    end, "PUIMessenger")
end

function PUIMessenger:OnDisable()
    Time:CancelAll("PUIMessenger")
    Events:UnregisterOwner("PUIMessenger")

    if buddyWindow and buddyWindow:IsShown() then buddyWindow:Hide() end
    if imWindow and imWindow:IsShown() then imWindow:Hide() end
end
