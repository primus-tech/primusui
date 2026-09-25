--[[
    PrimusUI: PUIRoleplay Directory & Master-Detail Flyout (PUIDirectory.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Modern RP Discovery)
--]]

local Primus = _G.Primus
local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Directory = {}
PUIRoleplay.Directory = Directory

local dirFrame = nil
local mapPins = {}
local VISIBLE_ROWS = 15
local ROW_HEIGHT = 23

Directory.sortField = "status"
Directory.sortAsc = true
Directory.activeFlyoutTab = 1
Directory.selectedPlayer = nil

--------------------------------------------------------------------------------
-- Build Directory UI Window & Flyout
--------------------------------------------------------------------------------
function Directory:BuildFrame()
    if dirFrame then return dirFrame end
    
    local f = CreateFrame("Frame", "Primus_PUIRoleplay_Directory", UIParent)
    f:SetWidth(520)
    f:SetHeight(480)
    f:SetPoint("CENTER", UIParent, "CENTER", -100, 0)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    f:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)
    table.insert(UISpecialFrames, "Primus_PUIRoleplay_Directory")
    
    -- Title Bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    titleBar:SetBackdropColor(0.11, 0.12, 0.15, 1.0)
    
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cff00ccffPRIMUS|r |cffffffffRP DIRECTORY|r")
    
    local totalText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    totalText:SetText("|cff888888(Scanning #ttrp...)|r")
    f.totalText = totalText

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    -- Scan / Ping Button in Title Bar
    local scanBtn = CreateFrame("Button", nil, titleBar)
    scanBtn:SetWidth(90)
    scanBtn:SetHeight(18)
    scanBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    scanBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    scanBtn:SetBackdropColor(0.10, 0.15, 0.22, 0.9)
    scanBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    
    local scanLabel = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scanLabel:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    scanLabel:SetText("|cff00ccff[ Ping / Scan ]|r")
    
    scanBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.0, 0.35, 0.55, 0.9)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Broadcast Presence Ping", 0.0, 0.8, 1.0)
        GameTooltip:AddLine("Broadcasts an announcement ping over #ttrp and requests info from active roleplayers.", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.10, 0.15, 0.22, 0.9)
        GameTooltip:Hide()
    end)
    scanBtn:SetScript("OnClick", function()
        PUIRoleplay.Comms:SendPing("P")
        PUIRoleplay.Comms:SendPing("A")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffPrimus RP:|r Broadcasted presence ping on |cffffcc00#ttrp|r.")
        Directory:RefreshList(f.searchEB:GetText() or "")
    end)

    -- Search EditBox
    local searchEB = CreateFrame("EditBox", nil, f)
    searchEB:SetWidth(496)
    searchEB:SetHeight(22)
    searchEB:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    searchEB:SetAutoFocus(false)
    searchEB:SetFontObject(GameFontHighlight)
    searchEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    searchEB:SetTextInsets(8, 8, 2, 2)
    searchEB:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    searchEB:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    searchEB:SetBackdropBorderColor(0.30, 0.30, 0.38, 1.0)
    
    searchEB:SetScript("OnEditFocusGained", function()
        this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        this:SetBackdropColor(0.08, 0.10, 0.14, 1.0)
    end)
    searchEB:SetScript("OnEditFocusLost", function()
        this:SetBackdropBorderColor(0.30, 0.30, 0.38, 1.0)
        this:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    end)
    searchEB:SetScript("OnEscapePressed", function()
        this:SetText("")
        this:ClearFocus()
        Directory:RefreshList("")
    end)
    searchEB:SetScript("OnTextChanged", function()
        Directory:RefreshList(this:GetText() or "")
    end)
    f.searchEB = searchEB
    
    -- Sortable Table Header Row
    local headerRow = CreateFrame("Frame", nil, f)
    headerRow:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -6)
    headerRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -64)
    headerRow:SetHeight(22)
    headerRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerRow:SetBackdropColor(0.08, 0.09, 0.12, 1.0)
    headerRow:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)
    
    -- Helper to create Sortable Header Buttons
    local function CreateSortHeaderButton(name, width, text, fieldKey)
        local btn = CreateFrame("Button", name, headerRow)
        btn:SetHeight(18)
        btn:SetWidth(width)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        btn:SetBackdropColor(0.05, 0.06, 0.08, 0.8)
        btn:SetBackdropBorderColor(0.16, 0.18, 0.22, 1.0)
        
        local fontStr = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fontStr:SetPoint("LEFT", btn, "LEFT", 6, 0)
        fontStr:SetText(text)
        btn.text = fontStr
        btn.fieldKey = fieldKey
        
        btn:SetScript("OnEnter", function()
            this:SetBackdropColor(0.12, 0.16, 0.24, 1.0)
            this:SetBackdropBorderColor(0.0, 0.70, 0.95, 0.9)
        end)
        btn:SetScript("OnLeave", function()
            this:SetBackdropColor(0.05, 0.06, 0.08, 0.8)
            this:SetBackdropBorderColor(0.16, 0.18, 0.22, 1.0)
        end)
        btn:SetScript("OnClick", function()
            if Directory.sortField == this.fieldKey then
                Directory.sortAsc = not Directory.sortAsc
            else
                Directory.sortField = this.fieldKey
                Directory.sortAsc = true
            end
            Directory:RefreshList()
        end)
        return btn
    end
    
    local btnStatus = CreateSortHeaderButton(nil, 88, "Status", "status")
    btnStatus:SetPoint("LEFT", headerRow, "LEFT", 2, 0)
    f.btnStatus = btnStatus
    
    local btnName = CreateSortHeaderButton(nil, 234, "Adventurer / RP Name", "name")
    btnName:SetPoint("LEFT", btnStatus, "RIGHT", 4, 0)
    f.btnName = btnName
    
    local btnZone = CreateSortHeaderButton(nil, 160, "Current Zone", "zone")
    btnZone:SetPoint("LEFT", btnName, "RIGHT", 4, 0)
    f.btnZone = btnZone
    
    -- Scroll Frame / Rows Container
    f.currentOffset = 0
    f.matchedItems = {}
    f.rows = {}
    
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetWidth(496)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -(i - 1) * (ROW_HEIGHT + 1) - 2)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        row:SetBackdropColor(0.04, 0.04, 0.05, (math.mod(i, 2) == 0) and 0.85 or 0.45)
        row:SetBackdropBorderColor(0.14, 0.14, 0.17, 1.0)
        
        local statusTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusTxt:SetPoint("LEFT", row, "LEFT", 8, 0)
        statusTxt:SetWidth(84)
        statusTxt:SetJustifyH("LEFT")
        row.statusTxt = statusTxt
        
        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameTxt:SetPoint("LEFT", row, "LEFT", 96, 0)
        nameTxt:SetWidth(230)
        nameTxt:SetJustifyH("LEFT")
        row.nameTxt = nameTxt
        
        local zoneTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        zoneTxt:SetPoint("LEFT", row, "LEFT", 334, 0)
        zoneTxt:SetWidth(155)
        zoneTxt:SetJustifyH("LEFT")
        row.zoneTxt = zoneTxt
        
        row:SetScript("OnEnter", function()
            if Directory.selectedPlayer ~= this.targetPlayerName then
                this:SetBackdropColor(0.0, 0.35, 0.55, 0.6)
                this:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0)
            end
            
            if this.targetPlayerName then
                local isSelf = (this.targetPlayerName == UnitName("player"))
                local data = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(this.targetPlayerName)
                if data then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    local fullName = (data.full_name and data.full_name ~= "") and data.full_name or this.targetPlayerName
                    local colorHex = data.class_color or "FFFFFF"
                    GameTooltip:AddLine("|cff" .. colorHex .. fullName .. "|r (|cff888888" .. this.targetPlayerName .. "|r)")
                    
                    local isOnline = isSelf or PUIRoleplay:IsPlayerOnline(this.targetPlayerName)
                    local isIC = (data.currently_ic == "1")
                    local statusStr = ""
                    if not isOnline then
                        statusStr = "|cff777788Offline|r"
                    elseif isIC then
                        statusStr = "|cff00ff88In Character (IC)|r"
                    else
                        statusStr = "|cffffaa00Out of Character (OOC)|r"
                    end
                    GameTooltip:AddLine("Status: " .. statusStr, 1, 1, 1)
                    
                    local race = (data.race and data.race ~= "") and data.race or (isSelf and UnitRace("player") or "")
                    local class = (data.class and data.class ~= "") and data.class or (isSelf and UnitClass("player") or "")
                    if race ~= "" or class ~= "" then
                        GameTooltip:AddLine(race .. " " .. class, 0.8, 0.8, 0.8)
                    end
                    local zone = (isSelf and (GetZoneText() or "")) or data.zone or ""
                    if zone ~= "" then
                        GameTooltip:AddLine("Zone: |cffffffff" .. zone .. "|r", 0.7, 0.7, 0.7)
                    end
                    if data.ic_pronouns and data.ic_pronouns ~= "" then
                        GameTooltip:AddLine("Pronouns: |cffffffff" .. data.ic_pronouns .. "|r", 0.6, 0.6, 0.6)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffClick|r to preview RP Profile flyout.", 0.2, 0.8, 0.2)
                    GameTooltip:Show()
                end
            end
        end)
        
        row:SetScript("OnLeave", function()
            if Directory.selectedPlayer == this.targetPlayerName then
                this:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
                this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            else
                this:SetBackdropColor(0.04, 0.04, 0.05, (math.mod(i, 2) == 0) and 0.85 or 0.45)
                this:SetBackdropBorderColor(0.14, 0.14, 0.17, 1.0)
            end
            GameTooltip:Hide()
        end)
        
        row:SetScript("OnClick", function()
            if this.targetPlayerName then
                Directory:ShowPlayerFlyout(this.targetPlayerName)
            end
        end)
        
        f.rows[i] = row
    end

    -- Scrollbar Slider on Right
    local scrollbar = CreateFrame("Slider", "Primus_PUIRoleplay_DirectoryScrollBar", f)
    scrollbar:SetWidth(12)
    scrollbar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -66)
    scrollbar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 16)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValue(0)
    scrollbar:SetValueStep(1)
    scrollbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    scrollbar:SetBackdropColor(0.03, 0.03, 0.05, 0.8)
    scrollbar:SetBackdropBorderColor(0.15, 0.15, 0.2, 1.0)
    
    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(0.0, 0.6, 0.9, 0.8)
    thumb:SetWidth(10)
    thumb:SetHeight(24)
    scrollbar:SetThumbTexture(thumb)
    
    scrollbar:SetScript("OnValueChanged", function()
        Directory:UpdateScroll(math.floor(this:GetValue()))
    end)
    f.scrollbar = scrollbar

    -- Mousewheel support
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function()
        local current = scrollbar:GetValue()
        if arg1 > 0 then
            scrollbar:SetValue(math.max(0, current - 1))
        elseif arg1 < 0 then
            local _, maxVal = scrollbar:GetMinMaxValues()
            scrollbar:SetValue(math.min(maxVal, current + 1))
        end
    end)
    
    -- Construct Right-Hand Profile Flyout Drawer
    Directory:BuildFlyout(f)
    
    dirFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Build Right-Hand Profile Flyout Sidecar
--------------------------------------------------------------------------------
function Directory:BuildFlyout(parent)
    local flyout = CreateFrame("Frame", "Primus_PUIRoleplay_DirFlyout", parent)
    flyout:SetWidth(420)
    flyout:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
    flyout:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
    flyout:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    flyout:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    flyout:SetBackdropBorderColor(0.20, 0.22, 0.28, 1.0)
    flyout:EnableMouse(true)
    flyout:Hide()
    parent.flyout = flyout
    
    -- Flyout Title Bar
    local titleBar = CreateFrame("Frame", nil, flyout)
    titleBar:SetPoint("TOPLEFT", flyout, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    titleBar:SetBackdropColor(0.11, 0.12, 0.15, 1.0)
    
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cff00ccffRP PROFILE PREVIEW|r")
    
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        flyout:Hide()
        Directory.selectedPlayer = nil
        Directory:RefreshList()
    end)
    
    -- Quick Actions in Title Bar (Target / Whisper)
    local targetBtn = CreateFrame("Button", nil, titleBar)
    targetBtn:SetWidth(56)
    targetBtn:SetHeight(18)
    targetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    targetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    targetBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.9)
    targetBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    local tLbl = targetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tLbl:SetPoint("CENTER", targetBtn, "CENTER", 0, 0)
    tLbl:SetText("|cff00ccffTarget|r")
    targetBtn:SetScript("OnClick", function()
        if Directory.selectedPlayer then
            TargetByName(Directory.selectedPlayer)
        end
    end)
    
    local whisperBtn = CreateFrame("Button", nil, titleBar)
    whisperBtn:SetWidth(62)
    whisperBtn:SetHeight(18)
    whisperBtn:SetPoint("RIGHT", targetBtn, "LEFT", -4, 0)
    whisperBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    whisperBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.9)
    whisperBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    local wLbl = whisperBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wLbl:SetPoint("CENTER", whisperBtn, "CENTER", 0, 0)
    wLbl:SetText("|cff00ccffWhisper|r")
    whisperBtn:SetScript("OnClick", function()
        if Directory.selectedPlayer then
            if ChatFrame_OpenChat then
                ChatFrame_OpenChat("/w " .. Directory.selectedPlayer .. " ")
            end
        end
    end)
    
    -- Header Profile Summary Box
    local headerBox = CreateFrame("Frame", nil, flyout)
    headerBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -32)
    headerBox:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -8, -32)
    headerBox:SetHeight(68)
    headerBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
    headerBox:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)
    
    local avatarTex = headerBox:CreateTexture(nil, "ARTWORK")
    avatarTex:SetWidth(44)
    avatarTex:SetHeight(44)
    avatarTex:SetPoint("TOPLEFT", headerBox, "TOPLEFT", 8, -12)
    avatarTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    flyout.avatarTex = avatarTex
    
    local nameStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameStr:SetPoint("TOPLEFT", avatarTex, "TOPRIGHT", 10, -2)
    nameStr:SetText("Adventurer")
    flyout.nameStr = nameStr
    
    local titleStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleStr:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -2)
    titleStr:SetText("")
    flyout.titleStr = titleStr
    
    local raceClassStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raceClassStr:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -2)
    raceClassStr:SetText("")
    flyout.raceClassStr = raceClassStr
    
    local statusPill = CreateFrame("Frame", nil, headerBox)
    statusPill:SetWidth(100)
    statusPill:SetHeight(20)
    statusPill:SetPoint("TOPRIGHT", headerBox, "TOPRIGHT", -8, -10)
    statusPill:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local statusPillText = statusPill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusPillText:SetPoint("CENTER", statusPill, "CENTER", 0, 0)
    statusPill.text = statusPillText
    flyout.statusPill = statusPill
    
    -- Flyout Tabs: Glances (1), RP Style (2), Bio (3), Notes (4)
    local tabNames = { "Glances", "RP Style", "Bio", "Notes" }
    local tabs = {}
    for i = 1, 4 do
        local tBtn = CreateFrame("Button", nil, flyout)
        tBtn:SetWidth(98)
        tBtn:SetHeight(22)
        tBtn:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8 + (i - 1) * 102, -104)
        tBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 0 }
        })
        tBtn:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        tBtn:SetBackdropBorderColor(0.22, 0.24, 0.28, 1.0)
        
        local tTxt = tBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tTxt:SetPoint("CENTER", tBtn, "CENTER", 0, 0)
        tTxt:SetText(tabNames[i])
        tBtn.text = tTxt
        tBtn.tabIdx = i
        
        tBtn:SetScript("OnClick", function()
            Directory:SelectFlyoutTab(this.tabIdx)
        end)
        tabs[i] = tBtn
    end
    flyout.tabs = tabs
    
    -- Content Container Box
    local contentBox = CreateFrame("Frame", nil, flyout)
    contentBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -126)
    contentBox:SetPoint("BOTTOMRIGHT", flyout, "BOTTOMRIGHT", -8, 8)
    contentBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    contentBox:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    contentBox:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)
    flyout.contentBox = contentBox
    
    -- -------------------------------------------------------------------------
    -- Panel 1: Glances & Current IC Info
    -- -------------------------------------------------------------------------
    local p1 = CreateFrame("Frame", nil, contentBox)
    p1:SetAllPoints(contentBox)
    flyout.p1 = p1
    
    local pronounsLine = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pronounsLine:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -8)
    pronounsLine:SetText("")
    p1.pronounsLine = pronounsLine
    
    local icInfoLine = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icInfoLine:SetPoint("TOPLEFT", pronounsLine, "BOTTOMLEFT", 0, -4)
    icInfoLine:SetWidth(388)
    icInfoLine:SetJustifyH("LEFT")
    icInfoLine:SetText("")
    p1.icInfoLine = icInfoLine
    
    -- 3 Glance Cards
    p1.glanceCards = {}
    for i = 1, 3 do
        local gCard = CreateFrame("Frame", nil, p1)
        gCard:SetWidth(388)
        gCard:SetHeight(74)
        gCard:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -50 - (i - 1) * 78)
        gCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        gCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        gCard:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)
        
        local gIcon = gCard:CreateTexture(nil, "ARTWORK")
        gIcon:SetWidth(28)
        gIcon:SetHeight(28)
        gIcon:SetPoint("TOPLEFT", gCard, "TOPLEFT", 6, -6)
        gIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        gCard.icon = gIcon
        
        local gTitle = gCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gTitle:SetPoint("TOPLEFT", gIcon, "TOPRIGHT", 6, 0)
        gTitle:SetPoint("TOPRIGHT", gCard, "TOPRIGHT", -6, 0)
        gTitle:SetJustifyH("LEFT")
        gTitle:SetText("")
        gCard.title = gTitle
        
        local gDesc = gCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gDesc:SetPoint("TOPLEFT", gTitle, "BOTTOMLEFT", 0, -3)
        gDesc:SetPoint("BOTTOMRIGHT", gCard, "BOTTOMRIGHT", -6, 4)
        gDesc:SetJustifyH("LEFT")
        gDesc:SetJustifyV("TOP")
        gDesc:SetText("")
        gCard.desc = gDesc
        
        p1.glanceCards[i] = gCard
    end
    
    -- -------------------------------------------------------------------------
    -- Panel 2: RP Style Badges
    -- -------------------------------------------------------------------------
    local p2 = CreateFrame("Frame", nil, contentBox)
    p2:SetAllPoints(contentBox)
    p2:Hide()
    flyout.p2 = p2
    
    p2.styleRows = {}
    local styleMeta = {
        { key = "walkups", label = "Walk-Up Preference" },
        { key = "romance", label = "Relationship / Romance" },
        { key = "injury", label = "Combat Injury Tolerance" },
        { key = "death", label = "Character Death Willingness" },
        { key = "experience", label = "Roleplay Experience" }
    }
    
    for i, meta in ipairs(styleMeta) do
        local sCard = CreateFrame("Frame", nil, p2)
        sCard:SetWidth(388)
        sCard:SetHeight(52)
        sCard:SetPoint("TOPLEFT", p2, "TOPLEFT", 8, -8 - (i - 1) * 56)
        sCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        sCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        sCard:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)
        
        local sLbl = sCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", sCard, "TOPLEFT", 8, -6)
        sLbl:SetText("|cff00e5ff" .. meta.label .. ":|r")
        
        local valBadge = CreateFrame("Frame", nil, sCard)
        valBadge:SetPoint("TOPLEFT", sCard, "TOPLEFT", 8, -24)
        valBadge:SetPoint("BOTTOMRIGHT", sCard, "BOTTOMRIGHT", -8, 6)
        valBadge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        valBadge:SetBackdropColor(0.10, 0.12, 0.16, 0.9)
        valBadge:SetBackdropBorderColor(0.24, 0.28, 0.34, 1.0)
        
        local valTxt = valBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valTxt:SetPoint("CENTER", valBadge, "CENTER", 0, 0)
        valTxt:SetText("Not Specified")
        sCard.valTxt = valTxt
        sCard.key = meta.key
        
        p2.styleRows[i] = sCard
    end
    
    -- -------------------------------------------------------------------------
    -- Panel 3: Full Character Biography
    -- -------------------------------------------------------------------------
    local p3 = CreateFrame("Frame", nil, contentBox)
    p3:SetAllPoints(contentBox)
    p3:Hide()
    flyout.p3 = p3
    
    local bioScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_FlyoutBioScroll", p3, "UIPanelScrollFrameTemplate")
    bioScroll:SetPoint("TOPLEFT", p3, "TOPLEFT", 8, -8)
    bioScroll:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -26, 8)
    
    local bioChild = CreateFrame("Frame", nil, bioScroll)
    bioChild:SetWidth(360)
    bioChild:SetHeight(600)
    bioScroll:SetScrollChild(bioChild)
    
    local bioText = bioChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bioText:SetPoint("TOPLEFT", bioChild, "TOPLEFT", 4, -4)
    bioText:SetWidth(350)
    bioText:SetJustifyH("LEFT")
    bioText:SetJustifyV("TOP")
    bioText:SetText("No biography written yet.")
    p3.bioText = bioText
    p3.bioChild = bioChild
    p3.bioScroll = bioScroll
    
    -- -------------------------------------------------------------------------
    -- Panel 4: Private Notes (Local Storage)
    -- -------------------------------------------------------------------------
    local p4 = CreateFrame("Frame", nil, contentBox)
    p4:SetAllPoints(contentBox)
    p4:Hide()
    flyout.p4 = p4
    
    local nHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nHeader:SetPoint("TOPLEFT", p4, "TOPLEFT", 8, -8)
    nHeader:SetText("|cffffd100Private Notes for this Adventurer (Saved Locally):|r")
    
    local notesScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_FlyoutNotesScroll", p4, "UIPanelScrollFrameTemplate")
    notesScroll:SetPoint("TOPLEFT", p4, "TOPLEFT", 8, -26)
    notesScroll:SetPoint("BOTTOMRIGHT", p4, "BOTTOMRIGHT", -26, 8)
    notesScroll:EnableMouse(true)
    
    local notesEB = CreateFrame("EditBox", nil, notesScroll)
    notesEB:SetWidth(360)
    notesEB:SetHeight(400)
    notesEB:SetMultiLine(true)
    notesEB:EnableMouse(true)
    notesEB:SetAutoFocus(false)
    notesEB:SetFontObject(GameFontHighlightSmall)
    notesEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    notesEB:SetTextInsets(4, 4, 4, 4)
    notesScroll:SetScrollChild(notesEB)
    p4.notesEB = notesEB
    
    notesScroll:SetScript("OnMouseDown", function() notesEB:SetFocus() end)
    notesEB:SetScript("OnMouseDown", function() this:SetFocus() end)
    notesEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    notesEB:SetScript("OnTextChanged", function()
        if Directory.selectedPlayer and flyout.isRefreshing ~= true then
            PUIRoleplay:SetCharacterNote(Directory.selectedPlayer, this:GetText())
        end
    end)
end

--------------------------------------------------------------------------------
-- Flyout Tab Switching
--------------------------------------------------------------------------------
function Directory:SelectFlyoutTab(index)
    Directory.activeFlyoutTab = index
    local f = self:BuildFrame()
    local flyout = f.flyout
    if not flyout then return end
    
    for i = 1, 4 do
        local tab = flyout.tabs[i]
        if i == index then
            tab:SetBackdropColor(0.16, 0.18, 0.24, 1.0)
            tab:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            tab.text:SetTextColor(0.0, 0.90, 1.0)
        else
            tab:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
            tab:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)
            tab.text:SetTextColor(0.70, 0.70, 0.75)
        end
    end
    
    flyout.p1:Hide()
    flyout.p2:Hide()
    flyout.p3:Hide()
    flyout.p4:Hide()
    
    if index == 1 then flyout.p1:Show() end
    if index == 2 then flyout.p2:Show() end
    if index == 3 then flyout.p3:Show() end
    if index == 4 then flyout.p4:Show() end
end

--------------------------------------------------------------------------------
-- Show & Refresh Player Flyout
--------------------------------------------------------------------------------
function Directory:ShowPlayerFlyout(charName)
    if not charName then return end
    local f = self:BuildFrame()
    Directory.selectedPlayer = charName
    
    -- Request fresh packets from wire
    PUIRoleplay.Comms:SendRequest("M", charName)
    PUIRoleplay.Comms:SendRequest("T", charName)
    PUIRoleplay.Comms:SendRequest("D", charName)
    
    Directory:RefreshFlyout()
    f.flyout:Show()
    Directory:RefreshList()
end

function Directory:RefreshFlyout()
    local f = self:BuildFrame()
    local flyout = f.flyout
    if not flyout or not Directory.selectedPlayer then return end
    
    local name = Directory.selectedPlayer
    local isSelf = (name == UnitName("player"))
    local data = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(name)
    if not data then return end
    
    flyout.isRefreshing = true
    
    local _, pClass = UnitClass("player")
    local pRace = UnitRace("player") or ""
    local myZone = GetZoneText() or ""
    if myZone == "" then myZone = GetMinimapZoneText() or GetRealZoneText() or "" end
    
    -- Header fields
    local iconIdx = tonumber(data.icon) or 0
    if iconIdx > 0 and PUIRoleplay.Icons[iconIdx] then
        flyout.avatarTex:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[iconIdx])
    else
        flyout.avatarTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    local colorHex = data.class_color or (isSelf and PUIRoleplay.ClassData and PUIRoleplay.ClassData[pClass] and PUIRoleplay.ClassData[pClass][4]) or "FFFFFF"
    local fullName = (data.full_name and data.full_name ~= "") and data.full_name or name
    flyout.nameStr:SetText("|cff" .. colorHex .. fullName .. "|r")
    
    local title = data.title or ""
    if title ~= "" then
        flyout.titleStr:SetText("|cff00e5ff" .. title .. "|r (|cff888888" .. name .. "|r)")
    else
        flyout.titleStr:SetText("|cff888888" .. name .. "|r")
    end
    
    local race = (data.race and data.race ~= "") and data.race or (isSelf and pRace or "")
    local class = (data.class and data.class ~= "") and data.class or (isSelf and pClass or "")
    local zone = (isSelf and myZone ~= "") and myZone or (data.zone or "")
    local raceClassDisplay = (race ~= "" or class ~= "") and (race .. " " .. class) or ""
    if zone ~= "" then
        raceClassDisplay = raceClassDisplay .. " |cff888888(|r|cffffffff" .. zone .. "|r|cff888888)|r"
    end
    flyout.raceClassStr:SetText(raceClassDisplay)
    
    local isOnline = isSelf or PUIRoleplay:IsPlayerOnline(name)
    local isIC = (data.currently_ic == "1")
    if not isOnline then
        flyout.statusPill:SetBackdropColor(0.25, 0.25, 0.28, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.4, 0.4, 0.45, 1.0)
        flyout.statusPill.text:SetText("|cff888888OFFLINE|r")
    elseif isIC then
        flyout.statusPill:SetBackdropColor(0.08, 0.45, 0.15, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.2, 0.85, 0.3, 1.0)
        flyout.statusPill.text:SetText("|cff40ff66IN CHARACTER|r")
    else
        flyout.statusPill:SetBackdropColor(0.45, 0.25, 0.05, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.85, 0.5, 0.15, 1.0)
        flyout.statusPill.text:SetText("|cffffaa00OUT OF CHAR|r")
    end
    
    -- Panel 1: Glances
    local icPr = data.ic_pronouns or ""
    local oocPr = data.ooc_pronouns or ""
    local prStr = ""
    if icPr ~= "" then prStr = "IC: |cffffffff" .. icPr .. "|r  " end
    if oocPr ~= "" then prStr = prStr .. "OOC: |cffffffff" .. oocPr .. "|r" end
    flyout.p1.pronounsLine:SetText(prStr)
    
    local icInfo = data.ic_info or ""
    if icInfo ~= "" then
        flyout.p1.icInfoLine:SetText("|cff55ff88Status:|r " .. icInfo)
    else
        flyout.p1.icInfoLine:SetText("")
    end
    
    for i = 1, 3 do
        local gCard = flyout.p1.glanceCards[i]
        local gIconIdx = tonumber(data["atAGlance" .. i .. "Icon"]) or 0
        if gIconIdx > 0 and PUIRoleplay.Icons[gIconIdx] then
            gCard.icon:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[gIconIdx])
        else
            gCard.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        local gTitle = data["atAGlance" .. i .. "Title"] or ""
        local gDesc = data["atAGlance" .. i] or ""
        if gTitle ~= "" or gDesc ~= "" then
            gCard.title:SetText(gTitle ~= "" and ("|cffffd100" .. gTitle .. "|r") or "|cff888888(No Title)|r")
            gCard.desc:SetText(gDesc ~= "" and gDesc or "|cff666666(No Description)|r")
            gCard:Show()
        else
            gCard.title:SetText("|cff666666(Empty Glance Slot)|r")
            gCard.desc:SetText("")
            gCard:Show()
        end
    end
    
    -- Panel 2: RP Style Badges
    for _, sCard in ipairs(flyout.p2.styleRows) do
        local code = data[sCard.key] or "d"
        local optText = PUIRoleplay.DropdownOptions and PUIRoleplay.DropdownOptions[sCard.key] and PUIRoleplay.DropdownOptions[sCard.key][code]
        sCard.valTxt:SetText(optText and ("|cffffffff" .. optText .. "|r") or "|cff777777Not Specified|r")
    end
    
    -- Panel 3: Bio
    local bioStr = data.description or ""
    if bioStr ~= "" then
        flyout.p3.bioText:SetText(bioStr)
    else
        flyout.p3.bioText:SetText("|cff777777No character biography provided.|r")
    end
    
    -- Panel 4: Notes
    local note = PUIRoleplay:GetCharacterNote(name) or ""
    flyout.p4.notesEB:SetText(note)
    
    Directory:SelectFlyoutTab(Directory.activeFlyoutTab)
    flyout.isRefreshing = false
end

--------------------------------------------------------------------------------
-- Directory Refresh & Render Logic
--------------------------------------------------------------------------------
function Directory:RefreshList(filterText)
    local f = self:BuildFrame()
    local query = string.lower(filterText or (f.searchEB and f.searchEB:GetText()) or "")
    local allChars = PUIRoleplay:GetAllKnownCharacters()
    local settings = PUIRoleplay:GetSettings() or {}
    local showNSFW = (settings.show_nsfw == "1" or settings.show_nsfw == 1)
    
    local playerName = UnitName("player")
    local myZone = GetZoneText() or ""
    if myZone == "" then myZone = GetMinimapZoneText() or GetRealZoneText() or "" end
    
    local matched = {}
    local totalFound = 0
    local onlineCount = 0
    local hasPlayer = false
    
    for name, data in pairs(allChars) do
        if data and (showNSFW or data.nsfw == "0" or data.nsfw == "" or data.nsfw == nil) then
            totalFound = totalFound + 1
            local isSelf = (name == playerName)
            if isSelf then hasPlayer = true end
            
            local isOnline = isSelf or PUIRoleplay:IsPlayerOnline(name)
            if isOnline then onlineCount = onlineCount + 1 end
            
            local fullName = (data.full_name and data.full_name ~= "") and data.full_name or name
            local zone = isSelf and ((myZone ~= "") and myZone or (data.zone or "")) or (data.zone or "")
            local class = (data.class and data.class ~= "") and data.class or (isSelf and UnitClass("player") or "")
            local classColor = data.class_color or (isSelf and PUIRoleplay.ClassData and PUIRoleplay.ClassData[UnitClass("player")] and PUIRoleplay.ClassData[UnitClass("player")][4]) or "FFFFFF"
            local isIC = (data.currently_ic == "1")
            
            -- Status category: 1 = IC (Online), 2 = OOC (Online), 3 = Offline
            local statusRank = 3
            if isOnline then
                statusRank = isIC and 1 or 2
            end
            
            if query == "" or string.find(string.lower(name), query) or string.find(string.lower(fullName), query) or string.find(string.lower(zone), query) or string.find(string.lower(class), query) then
                table.insert(matched, {
                    rawName = name,
                    fullName = fullName,
                    class = class,
                    classColor = classColor,
                    isIC = isIC,
                    isOnline = isOnline,
                    statusRank = statusRank,
                    zone = zone
                })
            end
        end
    end
    
    -- Always inject current player if not already in known_characters
    if not hasPlayer and playerName then
        local myProf = PUIRoleplay:GetMyProfile() or {}
        local _, pClass = UnitClass("player")
        local pRace = UnitRace("player") or ""
        local colorHex = (PUIRoleplay.ClassData and PUIRoleplay.ClassData[pClass] and PUIRoleplay.ClassData[pClass][4]) or "FFFFFF"
        local myFullName = (myProf.full_name and myProf.full_name ~= "") and myProf.full_name or playerName
        local isIC = (myProf.currently_ic == "1")
        local currentZone = (myZone ~= "") and myZone or "Unknown"
        
        if query == "" or string.find(string.lower(playerName), query) or string.find(string.lower(myFullName), query) or string.find(string.lower(currentZone), query) or (pClass and string.find(string.lower(pClass), query)) then
            table.insert(matched, {
                rawName = playerName,
                fullName = myFullName,
                class = pClass or "",
                classColor = colorHex,
                isIC = isIC,
                isOnline = true,
                statusRank = isIC and 1 or 2,
                zone = currentZone
            })
            totalFound = totalFound + 1
            onlineCount = onlineCount + 1
        end
    end
    
    -- Dynamic Field Sorting (Status, Name, Zone)
    table.sort(matched, function(a, b)
        if Directory.sortField == "status" then
            if a.statusRank ~= b.statusRank then
                if Directory.sortAsc then
                    return a.statusRank < b.statusRank
                else
                    return a.statusRank > b.statusRank
                end
            end
            return string.lower(a.fullName ~= "" and a.fullName or a.rawName) < string.lower(b.fullName ~= "" and b.fullName or b.rawName)
        elseif Directory.sortField == "name" then
            local nameA = string.lower(a.fullName ~= "" and a.fullName or a.rawName)
            local nameB = string.lower(b.fullName ~= "" and b.fullName or b.rawName)
            if nameA ~= nameB then
                if Directory.sortAsc then
                    return nameA < nameB
                else
                    return nameA > nameB
                end
            end
            return a.statusRank < b.statusRank
        elseif Directory.sortField == "zone" then
            local zoneA = string.lower(a.zone or "")
            local zoneB = string.lower(b.zone or "")
            if zoneA ~= zoneB then
                if zoneA == "" then return false end
                if zoneB == "" then return true end
                if Directory.sortAsc then
                    return zoneA < zoneB
                else
                    return zoneA > zoneB
                end
            end
            return string.lower(a.fullName ~= "" and a.fullName or a.rawName) < string.lower(b.fullName ~= "" and b.fullName or b.rawName)
        end
        return a.statusRank < b.statusRank
    end)
    
    f.matchedItems = matched
    
    -- Update Header Column Sort Indicators
    local function GetSortArrow(field)
        if Directory.sortField == field then
            return Directory.sortAsc and " |cff00e5ff▲|r" or " |cff00e5ff▼|r"
        end
        return ""
    end
    
    if f.btnStatus then f.btnStatus.text:SetText("Status" .. GetSortArrow("status")) end
    if f.btnName then f.btnName.text:SetText("Adventurer / RP Name" .. GetSortArrow("name")) end
    if f.btnZone then f.btnZone.text:SetText("Current Zone" .. GetSortArrow("zone")) end
    
    -- Update stats
    if f.totalText then
        f.totalText:SetText("|cff00ccff" .. totalFound .. "|r found (|cff00ff66" .. onlineCount .. " online|r)")
    end
    
    -- Update ScrollBar
    local totalMatched = table.getn(matched)
    local maxOffset = math.max(0, totalMatched - VISIBLE_ROWS)
    f.scrollbar:SetMinMaxValues(0, maxOffset)
    if f.currentOffset > maxOffset then
        f.currentOffset = maxOffset
    end
    f.scrollbar:SetValue(f.currentOffset)
    
    self:UpdateScroll(f.currentOffset)
end

function Directory:UpdateScroll(offset)
    local f = self:BuildFrame()
    f.currentOffset = offset or 0
    local matched = f.matchedItems or {}
    local playerName = UnitName("player")
    local myZone = GetZoneText() or ""
    if myZone == "" then myZone = GetMinimapZoneText() or GetRealZoneText() or "" end
    
    for i = 1, VISIBLE_ROWS do
        local row = f.rows[i]
        local itemIdx = f.currentOffset + i
        local item = matched[itemIdx]
        
        if item then
            row.targetPlayerName = item.rawName
            
            -- Selection highlight if currently open in flyout
            if Directory.selectedPlayer == item.rawName then
                row:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
                row:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            else
                row:SetBackdropColor(0.04, 0.04, 0.05, (math.mod(i, 2) == 0) and 0.85 or 0.45)
                row:SetBackdropBorderColor(0.14, 0.14, 0.17, 1.0)
            end
            
            -- Explicit Status: IC, OOC, or Offline
            local statusText = ""
            if not item.isOnline then
                statusText = "|cff777788○ Offline|r"
            elseif item.isIC then
                statusText = "|cff00ff88● IC|r"
            else
                statusText = "|cffffaa00● OOC|r"
            end
            row.statusTxt:SetText(statusText)
            
            local colorHex = item.classColor or "FFFFFF"
            local displayName = "|cff" .. colorHex .. item.fullName .. "|r"
            if item.fullName ~= item.rawName then
                displayName = displayName .. " |cff666677(" .. item.rawName .. ")|r"
            end
            row.nameTxt:SetText(displayName)
            
            local displayZone = item.zone
            if item.rawName == playerName and (not displayZone or displayZone == "" or displayZone == "Unknown") then
                displayZone = myZone
            end
            row.zoneTxt:SetText((displayZone and displayZone ~= "") and displayZone or "|cff555555Unknown|r")
            row:Show()
        else
            row.targetPlayerName = nil
            row:Hide()
        end
    end
end

function PUIRoleplay:OpenDirectory()
    local f = Directory:BuildFrame()
    f:Show()
    
    -- Send presence ping on opening to refresh online state from channel
    PUIRoleplay.Comms:SendPing("P")
    
    Directory:RefreshList(f.searchEB and f.searchEB:GetText() or "")
end

--------------------------------------------------------------------------------
-- World Map RP Location Pins
--------------------------------------------------------------------------------
function Directory:UpdateWorldMapPins()
    if not WorldMapFrame:IsVisible() then return end
    
    -- Hide existing pins
    for _, pin in ipairs(mapPins) do
        pin:Hide()
    end
    
    local mapWidth = WorldMapDetailFrame:GetWidth()
    local mapHeight = WorldMapDetailFrame:GetHeight()
    local curMapZone = GetCurrentMapZone()
    local continent = GetCurrentMapContinent()
    local zones = { GetMapZones(continent) }
    local currentZoneName = zones[curMapZone]
    
    local allChars = PUIRoleplay:GetAllKnownCharacters()
    local pinCount = 1
    
    for name, data in pairs(allChars) do
        if name ~= UnitName("player") and data.zoneX and data.zoneY then
            local zX = tonumber(data.zoneX)
            local zY = tonumber(data.zoneY)
            
            if zX and zY and (data.zone == currentZoneName or currentZoneName == "" or not currentZoneName) then
                local pin = mapPins[pinCount]
                if not pin then
                    pin = CreateFrame("Button", nil, WorldMapDetailFrame)
                    pin:SetWidth(16)
                    pin:SetHeight(16)
                    pin:SetFrameStrata("TOOLTIP")
                    
                    local tex = pin:CreateTexture(nil, "ARTWORK")
                    tex:SetAllPoints(pin)
                    tex:SetTexture("Interface\\AddOns\\TurtleRP\\images\\WorldMapPlayerIconTRP.blp")
                    pin.tex = tex
                    
                    pin:SetScript("OnEnter", function()
                        if this.charName then
                            WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
                            WorldMapTooltip:AddLine(this.fullName or this.charName, 0.0, 0.8, 1.0)
                            if this.isIC then
                                WorldMapTooltip:AddLine("Status: In Character (IC)", 0.25, 0.85, 0.45)
                            else
                                WorldMapTooltip:AddLine("Status: Out of Character (OOC)", 0.85, 0.5, 0.2)
                            end
                            WorldMapTooltip:Show()
                        end
                    end)
                    pin:SetScript("OnLeave", function()
                        WorldMapTooltip:Hide()
                    end)
                    pin:SetScript("OnClick", function()
                        if this.charName then
                            Directory:ShowPlayerFlyout(this.charName)
                        end
                    end)
                    table.insert(mapPins, pin)
                end
                
                pin.charName = name
                pin.fullName = data.full_name
                pin.isIC = (data.currently_ic == "1")
                
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", zX * mapWidth, -zY * mapHeight)
                pin:Show()
                
                pinCount = pinCount + 1
            end
        end
    end
end
