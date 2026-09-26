--[[
    PrimusUI Module: PUITalk (Master Orchestrator & Frame Architecture)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Consolidates:
    - PUIChat: Modern chat styling, class colors, URL clicks, sticky channels, chat copy.
    - PUIMessenger: Isolated whisper DMs, unread badges, audio alerts, and live social roster.
    
    Provides 3 Master Top-Level Tabs blended directly into the primary Chat Frame:
    1. [💬 Chat]     - Docked ChatFrame1 stream, class-colored names, clickable URLs, copy frame, whisper diversion.
    2. [✉️ Messages] - Isolated DM conversation sub-tabs, session history, unread counters, no double-send.
    3. [👥 Social]   - Real-time Friends list & Guild roster with online status, level, zone, and 1-click [DM] action.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Time    = Primus.Time
local PUIMover = Primus.PUIMover

local masterFrame = nil

-- =========================================================================
-- 1. MASTER FRAME CONSTRUCTION & DOCKING
-- =========================================================================

function PUITalk:CreateMasterFrame()
    if masterFrame then return masterFrame end

    local f = CreateFrame("Frame", "Primus_PUITalkFrame", UIParent)
    f:SetWidth(self.db:Get("width") or 450)
    f:SetHeight(self.db:Get("height") or 230)
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 36)
    f:SetBackdrop(Media:Fetch("border", "1Pixel"))
    f:SetBackdropColor(0.06, 0.07, 0.09, 0.95)
    f:SetBackdropBorderColor(0.20, 0.45, 0.85, 1.0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    tinsert(UISpecialFrames, "Primus_PUITalkFrame")

    -- ---------------------------------------------------------------------
    -- Top Master Rail (3 Master Tabs + Utility Buttons)
    -- ---------------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    header:SetHeight(26)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.10, 0.13, 0.18, 1.0)
    header:SetBackdropBorderColor(0.20, 0.35, 0.60, 1.0)
    f.header = header

    -- Tab 1: [💬 Chat]
    local tabChat = CreateFrame("Button", "Primus_PUITalkTab_1", header)
    tabChat:SetWidth(95)
    tabChat:SetHeight(20)
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
    tabMessages:SetHeight(20)
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
    tabSocial:SetHeight(20)
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
    -- Master Viewport Container
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
    viewChat:SetBackdropColor(0.04, 0.04, 0.06, 0.6)
    viewChat:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.6)

    -- Dock default Blizzard ChatFrame1 right into the viewChat container!
    PUITalk:DockDefaultChatFrame(viewChat)
    f.viewChat = viewChat

    -- ---------------------------------------------------------------------
    -- TAB 2 VIEW: ✉️ MESSAGES (DMs)
    -- ---------------------------------------------------------------------
    local viewMessages = CreateFrame("Frame", "Primus_PUITalkViewMessages", viewport)
    viewMessages:SetAllPoints(viewport)
    viewMessages:SetBackdrop(Media:Fetch("border", "1Pixel"))
    viewMessages:SetBackdropColor(0.04, 0.04, 0.06, 0.8)
    viewMessages:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.8)

    local dmTabBar = CreateFrame("Frame", "Primus_PUITalkDMTabBar", viewMessages)
    dmTabBar:SetPoint("TOPLEFT", viewMessages, "TOPLEFT", 4, -4)
    dmTabBar:SetPoint("TOPRIGHT", viewMessages, "TOPRIGHT", -4, -4)
    dmTabBar:SetHeight(22)
    viewMessages.dmTabBar = dmTabBar

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
        PUITalk.db:Set("activeSocialTab", "friends")
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
        PUITalk.db:Set("activeSocialTab", "guild")
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
    self.masterFrame = f
    PUITalk:SelectMasterTab(self.db:Get("activeMasterTab") or 1)
    return f
end

-- =========================================================================
-- 2. TAB SWITCHING LOGIC
-- =========================================================================

function PUITalk:SelectMasterTab(tabIndex)
    if not masterFrame then return end
    self.db:Set("activeMasterTab", tabIndex)

    -- Update Tab Button Visuals
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

    -- Toggle Viewports & Manage ChatFrame1 Visibility
    masterFrame.viewChat:Hide()
    masterFrame.viewMessages:Hide()
    masterFrame.viewSocial:Hide()

    if tabIndex == 1 then
        masterFrame.viewChat:Show()
        if ChatFrame1 then ChatFrame1:Show() end
        masterFrame.contextPill.text:SetText("#General")
    elseif tabIndex == 2 then
        masterFrame.viewMessages:Show()
        if ChatFrame1 then ChatFrame1:Hide() end
        self:RefreshDMTabs()
        if self.activeDMKey and self.dmTabs[self.activeDMKey] then
            masterFrame.contextPill.text:SetText("To: " .. (self.dmTabs[self.activeDMKey].name or self.activeDMKey))
        else
            masterFrame.contextPill.text:SetText("Whisper")
        end
    elseif tabIndex == 3 then
        masterFrame.viewSocial:Show()
        if ChatFrame1 then ChatFrame1:Hide() end
        masterFrame.contextPill.text:SetText("Social")
        self:RefreshSocialView()
    end
end

-- =========================================================================
-- 3. INPUT SUBMISSION HANDLER
-- =========================================================================

function PUITalk:HandleInputSubmit(text)
    if not text or text == "" then return end

    local currentTab = self.db:Get("activeMasterTab") or 1

    if currentTab == 2 and self.activeDMKey and self.dmTabs[self.activeDMKey] then
        -- Direct Whisper Mode
        local targetName = self.dmTabs[self.activeDMKey].name or self.activeDMKey
        SendChatMessage(text, "WHISPER", nil, targetName)
    else
        -- Standard Chat Execution
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox, text)
    end
end

-- =========================================================================
-- 4. OPTIONS FLARE REGISTRATION
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
                get = function() return PUITalk.db:Get("divertWhispers") end,
                set = function(v) PUITalk.db:Set("divertWhispers", v) end,
            },
            {
                key = "playSounds",
                type = "checkbox",
                label = "Play Sound Notification on Whisper",
                desc = "Plays an audio chime when an incoming direct message is received.",
                default = true,
                get = function() return PUITalk.db:Get("playSounds") end,
                set = function(v) PUITalk.db:Set("playSounds", v) end,
            },
            {
                key = "autoPopDMs",
                type = "checkbox",
                label = "Auto-Open Messages Tab on Whisper",
                desc = "Automatically displays the PUITalk window and selects Tab 2 on incoming whisper.",
                default = false,
                get = function() return PUITalk.db:Get("autoPopDMs") end,
                set = function(v) PUITalk.db:Set("autoPopDMs", v) end,
            },
            {
                key = "classColors",
                type = "checkbox",
                label = "Class Colored Names",
                desc = "Colors player names by their character class across chat and social tabs.",
                default = true,
                get = function() return PUITalk.db:Get("classColors") end,
                set = function(v)
                    PUITalk.db:Set("classColors", v)
                    PUITalk:UpdateClassCache()
                end,
            },
            {
                key = "stickyChannels",
                type = "checkbox",
                label = "Sticky Chat Channels",
                desc = "Remembers last chat channel across /say, /party, /guild, /raid.",
                default = true,
                get = function() return PUITalk.db:Get("stickyChannels") end,
                set = function(v)
                    PUITalk.db:Set("stickyChannels", v)
                    if v then PUITalk:SetupStickyChannels() end
                end,
            },
            {
                key = "mousewheelScroll",
                type = "checkbox",
                label = "Mousewheel Fast Scrolling",
                desc = "Enables mousewheel fast scrolling on chat frames (Shift: Top/Bottom).",
                default = true,
                get = function() return PUITalk.db:Get("mousewheelScroll") end,
                set = function(v)
                    PUITalk.db:Set("mousewheelScroll", v)
                    if v then PUITalk:SetupMousewheelScrolling() end
                end,
            },
            {
                key = "chatCopy",
                type = "checkbox",
                label = "Chat Copy [C] Button",
                desc = "Shows docked [C] button on chat tabs for 1-click clipboard copying.",
                default = true,
                get = function() return PUITalk.db:Get("chatCopy") end,
                set = function(v)
                    PUITalk.db:Set("chatCopy", v)
                    if v then
                        PUITalk:AttachCopyButtons()
                        for i = 1, 7 do
                            if PUITalk.copyButtons[i] then PUITalk.copyButtons[i]:Show() end
                        end
                    else
                        for i = 1, 7 do
                            if PUITalk.copyButtons[i] then PUITalk.copyButtons[i]:Hide() end
                        end
                    end
                end,
            },
        },
    })
end

-- =========================================================================
-- 5. LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUITalk:OnInitialize()
    self:SetupChatHooks()
    self:AttachCopyButtons()
    self:SetupMousewheelScrolling()
    self:SetupStickyChannels()
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
    self:AttachCopyButtons()
    for i = 1, 7 do
        if self.copyButtons[i] and self.db:Get("chatCopy") then
            self.copyButtons[i]:Show()
        end
    end

    -- Incoming Whisper Interception
    Events:Register("CHAT_MSG_WHISPER", "PUITalk", function(owner, event, msg, sender)
        PUITalk.lastWhisperSender = sender
        local key = string.lower(sender)
        PUITalk:AddDMMessage(key, sender, msg, false)
        if PUITalk.db:Get("autoPopDMs") then
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
        PUITalk:AttachCopyButtons()
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
    Events:Register("PLAYER_TARGET_CHANGED", "PUITalk", function()
        if UnitExists("target") then
            local name = UnitName("target")
            local _, class = UnitClass("target")
            if name and class then
                PUITalk.playerClassCache[name] = class
            end
        end
    end)

    -- Periodic Social Roster Polling (10s)
    Time:Every(10.0, function()
        if masterFrame and masterFrame:IsShown() and (PUITalk.db:Get("activeMasterTab") == 3) then
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
        if self.copyButtons[i] then
            self.copyButtons[i]:Hide()
        end
    end

    if copyFrame and copyFrame:IsShown() then copyFrame:Hide() end
    if urlFrame and urlFrame:IsShown() then urlFrame:Hide() end
    if masterFrame and masterFrame:IsShown() then masterFrame:Hide() end
end
