--[[
    PrimusUI Module: PUITalk (Social View, Friends List & Guild Roster Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Tab 3 (Social) real-time Friends list and Guild roster.
    - Status indicators (Online/AFK/DND/Guildie).
    - Class-colored player names, level, current zone, and note formatting.
    - 1-Click [💬 DM] button switching directly to Tab 2 and opening conversation.
    - Periodic roster polling and event-driven updates.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Media   = Primus.Media
local Utils   = Primus.Utils

-- =========================================================================
-- SOCIAL ROW CREATION & VIRTUALIZATION
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

-- =========================================================================
-- REFRESH & POPULATE SOCIAL ROSTER
-- =========================================================================

function PUITalk:RefreshSocialView()
    local masterFrame = self.masterFrame
    if not masterFrame or not masterFrame.viewSocial or not masterFrame.viewSocial:IsShown() then return end

    local container = masterFrame.viewSocial.socialContainer
    local socialMode = self.db:Get("activeSocialTab") or "friends"

    -- Highlight Sub-Tab Buttons
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
                local row = self.friendRows[rowCount] or CreateSocialRow(container, rowCount)
                self.friendRows[rowCount] = row

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

        masterFrame.tabSocial.text:SetText(string.format("👥 Social (%d/%d)", onlineFriendsCount, totalFriendsCount))
    else
        -- Guild Roster View
        if IsInGuild() then
            local numGuild = GetNumGuildMembers()
            for i = 1, math.min(numGuild, 40) do
                local name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i)
                if online and name and name ~= UnitName("player") then
                    rowCount = rowCount + 1
                    local row = self.guildRows[rowCount] or CreateSocialRow(container, rowCount)
                    self.guildRows[rowCount] = row

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
        if self.friendRows[i] then self.friendRows[i]:Hide() end
        if self.guildRows[i] then self.guildRows[i]:Hide() end
    end
end
