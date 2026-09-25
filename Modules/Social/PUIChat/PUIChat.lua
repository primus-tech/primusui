--[[
    PrimusLib Module: Social_Chat (Modernized Chat Frame, Copy/Paste & URL Clicker)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. Chat Copy & Paste on all ChatFrame1..7 tabs via docked [C] button and /chat copy.
    2. Clickable URL links that pop up a 1-click copy box for web links & Discord.
    3. Class-colored player names in all channels.
    4. Mousewheel fast scrolling across ChatFrame1..7 (Shift: Top/Bottom, Normal: 3 lines).
    5. Sticky Chat Channels (remembers last chat channel across /say, /party, /guild, /raid).
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIChat = Primus.PUIChat or {}
Primus.PUIChat = PUIChat
_G.PUIChat = PUIChat
Primus:RegisterModule("PUIChat", PUIChat, "Social")

local DB      = Primus.DB
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events

local chatDB = DB:RegisterNamespace("PUIChat", {
    enabled = true,
    stickyChannels = true,
    classColors = true,
    mousewheelScroll = true,
    chatCopy = true,
})

-- Player Class Cache
local playerClassCache = {}

-- Message Buffers for ChatFrame 1..7
local chatBuffers = {}
for i = 1, 7 do
    chatBuffers[i] = {}
end

local copyButtons = {}
local copyFrame = nil
local urlFrame = nil

-- Cache Class of a Unit or Name
local function CacheUnitClass(unit)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if name and class then
        playerClassCache[name] = class
    end
end

-- Update Class Cache from Group & Guild
function PUIChat:UpdateClassCache()
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

-- Get Class-Colored Name String
local function GetColoredName(name)
    if not name or not chatDB:Get("classColors") then return name end

    local class = playerClassCache[name]
    if class then
        local r, g, b = Utils.GetClassColor(class)
        local hex = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
        return string.format("|cff%s%s|r", hex, name)
    end
    return name
end

-- Clean color codes and hyperlink wrappers for pure clipboard copy
local function CleanChatText(str)
    if not str then return "" end
    -- Convert hyperlinks: |Hitem:1234:0:0:0|h[Thunderfury]|h -> [Thunderfury]
    str = string.gsub(str, "|H.-|h(.-)|h", "%1")
    -- Strip color codes: |cff123456...|r -> ...
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    return str
end

-- Format URL links in chat to be clickable hyperlinks
local function LinkifyURLs(text)
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

-- =========================================================================
-- CHAT BUFFERING & CHAT COPY WINDOW
-- =========================================================================

function PUIChat:CreateCopyFrame()
    if copyFrame then return copyFrame end

    local f = CreateFrame("Frame", "Primus_ChatCopyFrame", UIParent)
    f:SetWidth(580)
    f:SetHeight(420)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(Media:Fetch("border", "1Pixel"))
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    f:SetBackdropBorderColor(0.20, 0.45, 0.85, 1.0) -- Primus Blue Accent
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    -- ESC closes window
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

    -- ScrollFrame & EditBox Container
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
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Chat]: Text highlighted! Press Ctrl+C (Cmd+C) to copy.", "69ccf0"))
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
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[Primus Chat]: Cleared chat buffer for Tab %d.", idx), "69ccf0"))
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

function PUIChat:OpenCopyFrame(chatIndex)
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
        local clean = CleanChatText(entry.text)
        table.insert(lines, string.format("[%s] %s", entry.time, clean))
    end

    local fullText = table.concat(lines, "\n")
    f.editBox:SetText(fullText)
    f:Show()
    f:Raise()

    -- Focus and select all by default so user can just hit Ctrl+C!
    f.editBox:SetFocus()
    f.editBox:HighlightText(0)
end

-- =========================================================================
-- CLICKABLE URL POPUP DIALOG
-- =========================================================================

function PUIChat:ShowURLCopyPopup(url)
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
-- SETUP HOOKS & ATTACHMENTS
-- =========================================================================

local function AttachCopyButtons()
    if not chatDB:Get("chatCopy") then return end

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
                PUIChat:OpenCopyFrame(this.frameIndex)
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
                    local timeStamp = date("%H:%M:%S")
                    local rawText = tostring(text)
                    table.insert(chatBuffers[frameIdx], { time = timeStamp, text = rawText })
                    if table.getn(chatBuffers[frameIdx]) > 300 then
                        table.remove(chatBuffers[frameIdx], 1)
                    end
                    -- Enhance URLs in chat
                    text = LinkifyURLs(text)
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
                PUIChat:ShowURLCopyPopup(url)
                return
            end
            return _G.Primus_OriginalSetItemRef(link, text, button)
        end
    end
end

-- Setup Mousewheel Scrolling on Chat Frames
local function SetupMousewheelScrolling()
    if not chatDB:Get("mousewheelScroll") then return end

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

-- Configure Sticky Channels
local function SetupStickyChannels()
    if not chatDB:Get("stickyChannels") then return end

    local channels = { "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL" }
    local count = table.getn(channels)
    for i = 1, count do
        local chan = channels[i]
        ChatTypeInfo[chan].sticky = 1
    end
end

function PUIChat:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIChat", {
        name = "Social_Chat",
        category = "Social",
        label = "Enhanced Chat",
        options = {
            {
                key = "stickyChannels",
                type = "checkbox",
                label = "Sticky Chat Channels",
                desc = "Remembers last chat channel across /say, /party, /guild, /raid.",
                default = true,
                get = function() return chatDB:Get("stickyChannels") end,
                set = function(v)
                    chatDB:Set("stickyChannels", v)
                    if v then SetupStickyChannels() end
                end,
            },
            {
                key = "classColors",
                type = "checkbox",
                label = "Class Colored Names",
                desc = "Color player names by their character class in all channels.",
                default = true,
                get = function() return chatDB:Get("classColors") end,
                set = function(v)
                    chatDB:Set("classColors", v)
                    PUIChat:UpdateClassCache()
                end,
            },
            {
                key = "mousewheelScroll",
                type = "checkbox",
                label = "Mousewheel Fast Scrolling",
                desc = "Enable mousewheel scrolling across ChatFrame1..7 (Shift: Top/Bottom).",
                default = true,
                get = function() return chatDB:Get("mousewheelScroll") end,
                set = function(v)
                    chatDB:Set("mousewheelScroll", v)
                    if v then SetupMousewheelScrolling() end
                end,
            },
            {
                key = "chatCopy",
                type = "checkbox",
                label = "Chat Copy [C] Button",
                desc = "Show docked [C] button on chat tabs for 1-click clipboard copying.",
                default = true,
                get = function() return chatDB:Get("chatCopy") end,
                set = function(v)
                    chatDB:Set("chatCopy", v)
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

function PUIChat:OnInitialize()
    SetupChatHooks()
    AttachCopyButtons()
    SetupMousewheelScrolling()
    SetupStickyChannels()
    self:UpdateClassCache()
    self:RegisterOptionsFlare()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("chat", function(argParam, parts)
            argParam = Utils.Trim(argParam or "")
            if parts and parts[2] == "copy" then
                local idx = tonumber(parts[3]) or 1
                PUIChat:OpenCopyFrame(idx)
            else
                PUIChat:UpdateClassCache()
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Chat]: Enhanced chat active. Class colors, sticky channels, mousewheel scrolling, and Chat Copy [C] enabled.", "69ccf0"))
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("  Type /pui chat copy [1-7] or click the [C] button on any chat frame to copy text.", "ffd100"))
            end
        end, "Enhanced Chat Engine (/pui chat [copy 1-7])")
    end
end

function PUIChat:OnEnable()
    AttachCopyButtons()
    for i = 1, 7 do
        if copyButtons[i] and chatDB:Get("chatCopy") then
            copyButtons[i]:Show()
        end
    end

    Events:Register("PLAYER_ENTERING_WORLD", self, function()
        AttachCopyButtons()
    end)
    Events:Register("PARTY_MEMBERS_CHANGED", self, function() PUIChat:UpdateClassCache() end)
    Events:Register("RAID_ROSTER_UPDATE", self, function() PUIChat:UpdateClassCache() end)
    Events:Register("GUILD_ROSTER_UPDATE", self, function() PUIChat:UpdateClassCache() end)
    Events:Register("FRIENDLIST_UPDATE", self, function() PUIChat:UpdateClassCache() end)
    Events:Register("PLAYER_TARGET_CHANGED", self, function() CacheUnitClass("target") end)
end

function PUIChat:OnDisable()
    Events:UnregisterOwner(self)
    for i = 1, 7 do
        if copyButtons[i] then
            copyButtons[i]:Hide()
        end
    end
    if copyFrame then copyFrame:Hide() end
    if urlFrame then urlFrame:Hide() end
end

