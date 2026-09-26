--[[
    PrimusUI Module: PUITalk (Direct Messages, DM Sub-Tabs & Whisper Routing)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Tab 2 (Messages) conversation manager with isolated per-player sub-tabs.
    - Persistent session message history.
    - Authoritative incoming/outgoing whisper processing (zero double-send).
    - Unread counters and header notification badges.
    - Audio chime alerts on incoming whispers.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Media   = Primus.Media

-- =========================================================================
-- DIRECT MESSAGES (DMs) & SUB-TABS (TAB 2)
-- =========================================================================

function PUITalk:RefreshDMTabs()
    local masterFrame = self.masterFrame
    if not masterFrame or not masterFrame.viewMessages then return end

    local tabBar = masterFrame.viewMessages.dmTabBar
    local xOffset = 0
    local totalUnread = 0

    for key, tab in pairs(self.dmTabs) do
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

        if key == self.activeDMKey then
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
    if self.masterFrame then self.masterFrame:Show() end

    if not self.dmTabs[key] then
        self.dmTabs[key] = {
            key = key,
            name = targetName,
            unread = 0,
        }
        if not self.conversationHistory[key] then
            self.conversationHistory[key] = {}
        end
    end

    self:SelectMasterTab(2)
    self:SelectDMTab(key)
end

function PUITalk:SelectDMTab(key)
    if not self.dmTabs[key] then return end
    self.activeDMKey = key
    self.dmTabs[key].unread = 0

    local tab = self.dmTabs[key]
    if self.masterFrame and self.masterFrame.contextPill then
        self.masterFrame.contextPill.text:SetText("To: " .. tab.name)
    end

    -- Reload messages into DM frame
    if self.masterFrame and self.masterFrame.viewMessages then
        local msgFrame = self.masterFrame.viewMessages.msgFrame
        msgFrame:Clear()
        local history = self.conversationHistory[key] or {}
        local count = table.getn(history)
        for i = 1, count do
            local entry = history[i]
            msgFrame:AddMessage(entry.msg, entry.r, entry.g, entry.b)
        end
        msgFrame:ScrollToBottom()
    end

    self:RefreshDMTabs()
    if self.masterFrame and self.masterFrame.editBox and self.masterFrame:IsShown() and not UnitAffectingCombat("player") then
        self.masterFrame.editBox:SetFocus()
    end
end

function PUITalk:CloseDMTab(key)
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

function PUITalk:AddDMMessage(key, sender, text, isOutgoing, r, g, b)
    if not self.conversationHistory[key] then
        self.conversationHistory[key] = {}
    end

    local timestamp = self:GetTimestamp()
    local formattedMsg = ""

    if isOutgoing then
        formattedMsg = string.format("%s |cffffd100[You]:|r %s", timestamp, text)
        r, g, b = r or 1.0, g or 1.0, b or 0.8
    else
        formattedMsg = string.format("%s |cff00ccff[%s]:|r %s", timestamp, sender, text)
        r, g, b = r or 0.4, g or 0.9, b or 1.0
    end

    table.insert(self.conversationHistory[key], { msg = formattedMsg, r = r, g = g, b = b })

    local isViewingThisDM = self.masterFrame and self.masterFrame:IsShown() and (self.db:Get("activeMasterTab") == 2) and (self.activeDMKey == key)

    if isViewingThisDM then
        self.masterFrame.viewMessages.msgFrame:AddMessage(formattedMsg, r, g, b)
        self.masterFrame.viewMessages.msgFrame:ScrollToBottom()
    else
        if self.dmTabs[key] then
            self.dmTabs[key].unread = (self.dmTabs[key].unread or 0) + 1
        end
        self:RefreshDMTabs()
    end

    if self.db:Get("playSounds", true) and not isOutgoing then
        PlaySound("TellMessage")
    end
end
