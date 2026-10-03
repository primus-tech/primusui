--[[
    PrimusUI: PUIRoleplay Directory & Matchmaking Card Browser (PUIDirectory.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Modern RP Discovery & Matchmaking)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Directory = {}
PUIRoleplay.Directory = Directory

local dirFrame = nil
local mapPins = {}
local VISIBLE_ROWS = 14
local ROW_HEIGHT = 26

Directory.sortField = "status"
Directory.sortAsc = true
Directory.activeFlyoutTab = 1
Directory.selectedPlayer = nil
Directory.activeFilter = "ALL" -- ALL, IC, LGBTQ, ADULT18, ROMANCE, ADVENTURE, TAVERN

--------------------------------------------------------------------------------
-- Build Directory UI Window & Flyout
--------------------------------------------------------------------------------
function Directory:BuildFrame()
    if dirFrame then return dirFrame end

    local f = CreateFrame("Frame", "Primus_PUIRoleplay_Directory", UIParent)
    f:SetWidth(560)
    f:SetHeight(520)
    f:SetPoint("CENTER", UIParent, "CENTER", -120, 0)
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
    titleText:SetText("|cff00ccffPRIMUS|r |cffffffffRP DIRECTORY & DISCOVERY|r")

    local totalText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    totalText:SetText("|cff888888(Scanning #OWPRP / #TTRP...)|r")
    f.totalText = totalText

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Ping / Broadcast Button in Title Bar
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
        GameTooltip:AddLine("Broadcasts discovery pings across #OWPRP and #TTRP channels.", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.10, 0.15, 0.22, 0.9)
        GameTooltip:Hide()
    end)
    scanBtn:SetScript("OnClick", function()
        PUIRoleplay.Comms:SendPing("P")
        PUIRoleplay.Comms:SendPing("A")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffPrimus RP:|r Broadcasted presence ping on |cffffcc00#OWPRP / #TTRP|r.")
        Directory:RefreshList(f.searchEB:GetText() or "")
    end)

    -- Search EditBox
    local searchEB = CreateFrame("EditBox", nil, f)
    searchEB:SetWidth(536)
    searchEB:SetHeight(22)
    searchEB:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
    searchEB:SetAutoFocus(false)
    searchEB:SetFontObject(GameFontHighlightSmall)
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

    -- Filter Chips / Category Buttons
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", 0, -4)
    filterBar:SetWidth(536)
    filterBar:SetHeight(22)

    local filterDefs = {
        { id = "ALL", label = "All Roleplayers" },
        { id = "IC", label = "IC Only" },
        { id = "LGBTQ", label = "|cffff0000L|cffff7f00G|cffffff00B|cff00ff00T|cff0000ffQ|cff9400d3+|r" },
        { id = "ROMANCE", label = "|cffff80ccRomance|r" },
        { id = "ADVENTURE", label = "|cff00ff88Adventure|r" },
        { id = "TAVERN", label = "|cffffcc00Tavern|r" },
        { id = "ADULT18", label = "|cffff335518+ Adult|r" }
    }

    f.filterButtons = {}
    local chipWidth = 73
    for cIdx, item in ipairs(filterDefs) do
        local cBtn = CreateFrame("Button", nil, filterBar)
        cBtn:SetWidth(chipWidth)
        cBtn:SetHeight(20)
        cBtn:SetPoint("TOPLEFT", filterBar, "TOPLEFT", (cIdx - 1) * (chipWidth + 4), 0)
        cBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        cBtn:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
        cBtn:SetBackdropBorderColor(0.22, 0.22, 0.28, 1.0)

        local cbTxt = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cbTxt:SetPoint("CENTER", cBtn, "CENTER", 0, 0)
        cbTxt:SetText(item.label)
        cBtn.text = cbTxt
        cBtn.filterId = item.id

        cBtn:SetScript("OnClick", function()
            Directory.activeFilter = this.filterId
            for _, b in ipairs(f.filterButtons) do
                if b.filterId == Directory.activeFilter then
                    b:SetBackdropColor(0.0, 0.45, 0.70, 0.95)
                    b:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
                else
                    b:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
                    b:SetBackdropBorderColor(0.22, 0.22, 0.28, 1.0)
                end
            end
            Directory:RefreshList(f.searchEB:GetText() or "")
        end)

        table.insert(f.filterButtons, cBtn)
    end

    -- Sortable Table Header Row
    local headerRow = CreateFrame("Frame", nil, f)
    headerRow:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -6)
    headerRow:SetWidth(518)
    headerRow:SetHeight(22)
    headerRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerRow:SetBackdropColor(0.08, 0.09, 0.12, 1.0)
    headerRow:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)

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

    local btnStatus = CreateSortHeaderButton(nil, 84, "Status", "status")
    btnStatus:SetPoint("LEFT", headerRow, "LEFT", 2, 0)
    f.btnStatus = btnStatus

    local btnName = CreateSortHeaderButton(nil, 240, "Roleplayer / Full Name", "name")
    btnName:SetPoint("LEFT", btnStatus, "RIGHT", 4, 0)
    f.btnName = btnName

    local btnZone = CreateSortHeaderButton(nil, 184, "Current Zone / Vicinity", "zone")
    btnZone:SetPoint("LEFT", btnName, "RIGHT", 4, 0)
    f.btnZone = btnZone

    -- Scroll Frame / Rows Container
    f.currentOffset = 0
    f.matchedItems = {}
    f.rows = {}

    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetWidth(518)
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
        statusTxt:SetPoint("LEFT", row, "LEFT", 6, 0)
        statusTxt:SetWidth(80)
        statusTxt:SetJustifyH("LEFT")
        row.statusTxt = statusTxt

        local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameTxt:SetPoint("LEFT", row, "LEFT", 90, 0)
        nameTxt:SetWidth(236)
        nameTxt:SetJustifyH("LEFT")
        row.nameTxt = nameTxt

        local zoneTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        zoneTxt:SetPoint("LEFT", row, "LEFT", 330, 0)
        zoneTxt:SetWidth(180)
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
                    local statusStr = not isOnline and "|cff777788Offline|r" or (isIC and "|cff00ff88In Character (IC)|r" or "|cffffaa00Out of Character (OOC)|r")
                    GameTooltip:AddLine("Status: " .. statusStr, 1, 1, 1)

                    if data.title and data.title ~= "" then
                        GameTooltip:AddLine("<" .. data.title .. ">", 0.0, 0.85, 1.0)
                    end
                    if data.apparent_age and data.apparent_age ~= "" then
                        GameTooltip:AddLine("Age: |cffffffff" .. data.apparent_age .. "|r", 0.8, 0.8, 0.8)
                    end
                    if data.lgbtqia_friendly ~= false then
                        GameTooltip:AddLine("|cffff0000[|cffff7f00LGBTQIA+|cff9400d3 Friendly Safe Space]|r", 1, 1, 1)
                    end
                    if data.adult_18plus_flag == true then
                        GameTooltip:AddLine("|cffff3355[18+ Adult-Oriented Profile]|r", 1, 0.3, 0.3)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffClick|r to open Discovery Card flyout.", 0.2, 0.8, 0.2)
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

    -- Scrollbar Slider
    local scrollbar = CreateFrame("Slider", "Primus_PUIRoleplay_DirectoryScrollBar", f)
    scrollbar:SetWidth(14)
    scrollbar:SetPoint("TOPLEFT", headerRow, "TOPRIGHT", 4, 0)
    scrollbar:SetPoint("BOTTOMLEFT", headerRow, "BOTTOMRIGHT", 4, -(VISIBLE_ROWS * (ROW_HEIGHT + 1) + 2))
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValue(0)
    scrollbar:SetValueStep(1)
    scrollbar:SetFrameLevel(f:GetFrameLevel() + 25)
    scrollbar:EnableMouse(true)
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    scrollbar:SetBackdropColor(0.02, 0.03, 0.05, 0.9)
    scrollbar:SetBackdropBorderColor(0.18, 0.20, 0.26, 1.0)

    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(0.0, 0.7, 1.0, 0.9)
    thumb:SetWidth(12)
    thumb:SetHeight(32)
    scrollbar:SetThumbTexture(thumb)

    scrollbar:SetScript("OnValueChanged", function()
        Directory:UpdateScroll(math.floor(this:GetValue()))
    end)
    scrollbar:SetScript("OnMouseWheel", function()
        local current = this:GetValue()
        if arg1 > 0 then
            this:SetValue(math.max(0, current - 1))
        elseif arg1 < 0 then
            local _, maxVal = this:GetMinMaxValues()
            this:SetValue(math.min(maxVal, current + 1))
        end
    end)
    f.scrollbar = scrollbar

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

    Directory:BuildFlyout(f)
    dirFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Build Right-Hand Profile Discovery Flyout Sidecar
--------------------------------------------------------------------------------
function Directory:BuildFlyout(parent)
    local flyout = CreateFrame("Frame", "Primus_PUIRoleplay_DirFlyout", parent)
    flyout:SetWidth(440)
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

    -- Title Bar
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
    titleText:SetText("|cff00ccffDISCOVERY CARD PREVIEW|r")

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

    -- Quick Action Buttons in Title Bar
    local inspectBtn = CreateFrame("Button", nil, titleBar)
    inspectBtn:SetWidth(76)
    inspectBtn:SetHeight(18)
    inspectBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    inspectBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    inspectBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.9)
    inspectBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    local iLbl = inspectBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iLbl:SetPoint("CENTER", inspectBtn, "CENTER", 0, 0)
    iLbl:SetText("|cff00ccff[Profile]|r")
    inspectBtn:SetScript("OnClick", function()
        if Directory.selectedPlayer then
            PUIRoleplay:OpenProfile(Directory.selectedPlayer)
        end
    end)

    local whisperBtn = CreateFrame("Button", nil, titleBar)
    whisperBtn:SetWidth(62)
    whisperBtn:SetHeight(18)
    whisperBtn:SetPoint("RIGHT", inspectBtn, "LEFT", -4, 0)
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
        if Directory.selectedPlayer and ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. Directory.selectedPlayer .. " ")
        end
    end)

    -- Header Profile Summary Card
    local headerBox = CreateFrame("Frame", nil, flyout)
    headerBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -32)
    headerBox:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -8, -32)
    headerBox:SetHeight(84)
    headerBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
    headerBox:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)

    local avatarTex = headerBox:CreateTexture(nil, "ARTWORK")
    avatarTex:SetWidth(52)
    avatarTex:SetHeight(52)
    avatarTex:SetPoint("TOPLEFT", headerBox, "TOPLEFT", 8, -8)
    avatarTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    flyout.avatarTex = avatarTex

    local nameStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameStr:SetPoint("TOPLEFT", avatarTex, "TOPRIGHT", 10, 0)
    nameStr:SetText("Adventurer")
    flyout.nameStr = nameStr

    local titleStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleStr:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -2)
    titleStr:SetTextColor(0.0, 0.85, 1.0)
    flyout.titleStr = titleStr

    local demoTags = headerBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    demoTags:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -2)
    flyout.demoTags = demoTags

    local statusPill = CreateFrame("Frame", nil, headerBox)
    statusPill:SetWidth(100)
    statusPill:SetHeight(20)
    statusPill:SetPoint("TOPRIGHT", headerBox, "TOPRIGHT", -8, -8)
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

    -- Flyout Tabs: Appearance (1), Style & ERP (2), Lore (3), Notes (4)
    local tabNames = { "Appearance", "Style / ERP", "Lore", "Notes" }
    local tabs = {}
    for i = 1, 4 do
        local tBtn = CreateFrame("Button", nil, flyout)
        tBtn:SetWidth(102)
        tBtn:SetHeight(22)
        tBtn:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8 + (i - 1) * 106, -120)
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
    contentBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -142)
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

    -- Panel 1: Glances & Appearance
    local p1 = CreateFrame("Frame", nil, contentBox)
    p1:SetAllPoints(contentBox)
    flyout.p1 = p1

    local lfBadgeDisplay = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lfBadgeDisplay:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -8)
    lfBadgeDisplay:SetWidth(408)
    lfBadgeDisplay:SetJustifyH("LEFT")
    p1.lfBadgeDisplay = lfBadgeDisplay

    p1.glanceCards = {}
    for i = 1, 5 do
        local gCard = CreateFrame("Frame", nil, p1)
        gCard:SetWidth(408)
        gCard:SetHeight(48)
        gCard:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -32 - (i - 1) * 52)
        gCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        gCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        gCard:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)

        local gIcon = gCard:CreateTexture(nil, "ARTWORK")
        gIcon:SetWidth(32)
        gIcon:SetHeight(32)
        gIcon:SetPoint("TOPLEFT", gCard, "TOPLEFT", 6, -8)
        gIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        gCard.icon = gIcon

        local gTitle = gCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gTitle:SetPoint("TOPLEFT", gIcon, "TOPRIGHT", 6, 0)
        gTitle:SetPoint("TOPRIGHT", gCard, "TOPRIGHT", -6, 0)
        gTitle:SetJustifyH("LEFT")
        gCard.title = gTitle

        local gDesc = gCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gDesc:SetPoint("TOPLEFT", gTitle, "BOTTOMLEFT", 0, -2)
        gDesc:SetPoint("BOTTOMRIGHT", gCard, "BOTTOMRIGHT", -6, 4)
        gDesc:SetJustifyH("LEFT")
        gCard.desc = gDesc

        p1.glanceCards[i] = gCard
    end

    -- Panel 2: Style & ERP
    local p2 = CreateFrame("Frame", nil, contentBox)
    p2:SetAllPoints(contentBox)
    p2:Hide()
    flyout.p2 = p2

    p2.styleRows = {}
    local styleMeta = {
        { key = "relationship_status", label = "Relationship Status" },
        { key = "walkup_policy", label = "Walk-Up Preferences" },
        { key = "combat_preference", label = "Combat & Conflict Resolution" },
        { key = "injury_consent", label = "Combat Injury Tolerance" },
        { key = "permadeath_consent", label = "Character Death Willingness" },
        { key = "erp_preference", label = "ERP Preference & Tone" }
    }

    for i, meta in ipairs(styleMeta) do
        local sCard = CreateFrame("Frame", nil, p2)
        sCard:SetWidth(408)
        sCard:SetHeight(42)
        sCard:SetPoint("TOPLEFT", p2, "TOPLEFT", 8, -8 - (i - 1) * 46)
        sCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        sCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        sCard:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)

        local sLbl = sCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", sCard, "TOPLEFT", 8, -4)
        sLbl:SetText("|cff00e5ff" .. meta.label .. ":|r")

        local valTxt = sCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valTxt:SetPoint("TOPLEFT", sLbl, "BOTTOMLEFT", 0, -2)
        valTxt:SetText("Not Specified")
        sCard.valTxt = valTxt
        sCard.key = meta.key

        p2.styleRows[i] = sCard
    end

    -- Panel 3: Lore & History
    local p3 = CreateFrame("Frame", nil, contentBox)
    p3:SetAllPoints(contentBox)
    p3:Hide()
    flyout.p3 = p3

    local bioScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_FlyoutBioScroll", p3, "UIPanelScrollFrameTemplate")
    bioScroll:SetPoint("TOPLEFT", p3, "TOPLEFT", 8, -8)
    bioScroll:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -26, 8)

    local bioChild = CreateFrame("Frame", nil, bioScroll)
    bioChild:SetWidth(380)
    bioChild:SetHeight(800)
    bioScroll:SetScrollChild(bioChild)

    local bioText = bioChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bioText:SetPoint("TOPLEFT", bioChild, "TOPLEFT", 4, -4)
    bioText:SetWidth(370)
    bioText:SetJustifyH("LEFT")
    bioText:SetJustifyV("TOP")
    bioText:SetText("No history recorded.")
    p3.bioText = bioText
    p3.bioChild = bioChild
    p3.bioScroll = bioScroll

    -- Panel 4: Notes
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
    notesEB:SetWidth(380)
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

    if index == 1 then flyout.p1:Show()
    elseif index == 2 then flyout.p2:Show()
    elseif index == 3 then flyout.p3:Show()
    elseif index == 4 then flyout.p4:Show()
    end
end

function Directory:ShowPlayerFlyout(charName)
    if not charName then return end
    local f = self:BuildFrame()
    Directory.selectedPlayer = charName

    if PUIRoleplay.Comms and PUIRoleplay.Comms.SendRequest then
        PUIRoleplay.Comms:SendRequest("M", charName)
        PUIRoleplay.Comms:SendRequest("T", charName)
        PUIRoleplay.Comms:SendRequest("D", charName)
        PUIRoleplay.Comms:SendRequest("L", charName)
        PUIRoleplay.Comms:SendRequest("X", charName)
    end

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

    local iconIdx = tonumber(data.icon) or 1
    flyout.avatarTex:SetTexture("Interface\\Icons\\" .. (PUIRoleplay.Icons[iconIdx] or "INV_Misc_QuestionMark"))

    local colorHex = data.class_color or "00ccff"
    local fullName = (data.full_name and data.full_name ~= "") and data.full_name or name
    flyout.nameStr:SetText("|cff" .. colorHex .. fullName .. "|r")

    local titleStr = (data.title and data.title ~= "") and ("<" .. data.title .. ">") or ("|cff888888" .. name .. "|r")
    flyout.titleStr:SetText(titleStr)

    local age = data.apparent_age or "Unknown Age"
    local ori = (data.show_orientation ~= false and data.orientation) or "Private"
    local lgbtq = (data.lgbtqia_friendly ~= false) and " |cffff0000[|cffff7f00LGBTQIA+|cff9400d3]|r" or ""
    local adult18 = (data.adult_18plus_flag == true) and " |cffff3355[18+]|r" or ""
    flyout.demoTags:SetText(string.format("|cff00ccff[%s]|r |cffff80cc[%s]|r%s%s", age, ori, lgbtq, adult18))

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

    -- Panel 1: Looking For & Glances
    local lfStr = "Looking For:"
    local lf = data.looking_for or {}
    if lf.adventure then lfStr = lfStr .. " |cff00ff88[Adventure]|r" end
    if lf.romance then lfStr = lfStr .. " |cffff80cc[Romance]|r" end
    if lf.casual_tavern then lfStr = lfStr .. " |cffffcc00[Tavern]|r" end
    if lf.combat then lfStr = lfStr .. " |cffff4444[Combat]|r" end
    if lf.political_guild then lfStr = lfStr .. " |cff00ccff[Guild]|r" end
    if lf.mentorship then lfStr = lfStr .. " |cffb080ff[Mentorship]|r" end
    flyout.p1.lfBadgeDisplay:SetText(lfStr)

    for i = 1, 5 do
        local gCard = flyout.p1.glanceCards[i]
        local glance = (data.glances and data.glances[i]) or {}
        local gTitle = glance.title or data["atAGlance" .. i .. "Title"] or ""
        local gText = glance.text or data["atAGlance" .. i] or ""
        local gIcon = glance.icon or ""
        local gIconIdx = tonumber(data["atAGlance" .. i .. "Icon"]) or 0

        if gIcon ~= "" then
            gCard.icon:SetTexture("Interface\\Icons\\" .. gIcon)
        elseif gIconIdx > 0 and PUIRoleplay.Icons[gIconIdx] then
            gCard.icon:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[gIconIdx])
        else
            gCard.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        if gTitle ~= "" or gText ~= "" then
            gCard.title:SetText("|cffffd100" .. gTitle .. "|r")
            gCard.desc:SetText(gText)
            gCard:Show()
        else
            gCard.title:SetText("|cff666666(Empty Glance Slot " .. i .. ")|r")
            gCard.desc:SetText("")
            gCard:Show()
        end
    end

    -- Panel 2: Style Rows
    for _, sCard in ipairs(flyout.p2.styleRows) do
        local val = data[sCard.key] or "Not Specified"
        sCard.valTxt:SetText("|cffffffff" .. tostring(val) .. "|r")
    end

    -- Panel 3: Lore
    local bioStr = ""
    if data.motto and data.motto ~= "" then
        bioStr = bioStr .. "|cffffd100Motto:|r \"" .. data.motto .. "\"\n\n"
    end
    if data.birth_city and data.birth_city ~= "" then
        bioStr = bioStr .. "|cff00e5ffBirthplace:|r " .. data.birth_city .. "    |cff00e5ffHome:|r " .. (data.home_city or "") .. "\n\n"
    end
    if data.history then
        for chIdx = 1, 6 do
            local chText = data.history["chapter" .. chIdx]
            if chText and chText ~= "" then
                bioStr = bioStr .. "|cff00e5ff--- Chapter " .. chIdx .. " ---|r\n" .. chText .. "\n\n"
            end
        end
    end
    if bioStr == "" then
        bioStr = data.description or "No detailed biography recorded."
    end
    flyout.p3.bioText:SetText(bioStr)

    -- Panel 4: Notes
    flyout.p4.notesEB:SetText(PUIRoleplay:GetCharacterNote(name) or "")

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

    local playerName = UnitName("player")
    local myZone = GetZoneText() or ""
    if myZone == "" then myZone = GetMinimapZoneText() or GetRealZoneText() or "" end

    local matched = {}
    local totalFound = 0
    local onlineCount = 0
    local hasPlayer = false

    local filterMode = Directory.activeFilter or "ALL"

    for name, data in pairs(allChars) do
        if data then
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

            -- Filter checks
            local passesFilter = true
            if filterMode == "IC" and not isIC then passesFilter = false end
            if filterMode == "LGBTQ" and (data.lgbtqia_friendly == false) then passesFilter = false end
            if filterMode == "ADULT18" and (data.adult_18plus_flag ~= true and (not data.looking_for or not data.looking_for.adult_18plus)) then passesFilter = false end
            if filterMode == "ROMANCE" and (not data.looking_for or not data.looking_for.romance) then passesFilter = false end
            if filterMode == "ADVENTURE" and (not data.looking_for or not data.looking_for.adventure) then passesFilter = false end
            if filterMode == "TAVERN" and (not data.looking_for or not data.looking_for.casual_tavern) then passesFilter = false end

            local statusRank = isOnline and (isIC and 1 or 2) or 3

            if passesFilter then
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
    end

    if not hasPlayer and playerName then
        local myProf = PUIRoleplay:GetMyProfile() or {}
        local _, pClass = UnitClass("player")
        local colorHex = (PUIRoleplay.ClassData and PUIRoleplay.ClassData[pClass] and PUIRoleplay.ClassData[pClass][4]) or "FFFFFF"
        local myFullName = (myProf.full_name and myProf.full_name ~= "") and myProf.full_name or playerName
        local isIC = (myProf.currently_ic == "1")
        local currentZone = (myZone ~= "") and myZone or "Unknown"

        local passesFilter = true
        if filterMode == "IC" and not isIC then passesFilter = false end
        if filterMode == "LGBTQ" and (myProf.lgbtqia_friendly == false) then passesFilter = false end
        if filterMode == "ADULT18" and (myProf.adult_18plus_flag ~= true) then passesFilter = false end
        if filterMode == "ROMANCE" and (not myProf.looking_for or not myProf.looking_for.romance) then passesFilter = false end
        if filterMode == "ADVENTURE" and (not myProf.looking_for or not myProf.looking_for.adventure) then passesFilter = false end
        if filterMode == "TAVERN" and (not myProf.looking_for or not myProf.looking_for.casual_tavern) then passesFilter = false end

        if passesFilter then
            if query == "" or string.find(string.lower(playerName), query) or string.find(string.lower(myFullName), query) or string.find(string.lower(currentZone), query) then
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
    end

    table.sort(matched, function(a, b)
        if Directory.sortField == "status" then
            if a.statusRank ~= b.statusRank then
                return Directory.sortAsc and (a.statusRank < b.statusRank) or (a.statusRank > b.statusRank)
            end
            return string.lower(a.fullName ~= "" and a.fullName or a.rawName) < string.lower(b.fullName ~= "" and b.fullName or b.rawName)
        elseif Directory.sortField == "name" then
            local nameA = string.lower(a.fullName ~= "" and a.fullName or a.rawName)
            local nameB = string.lower(b.fullName ~= "" and b.fullName or b.rawName)
            if nameA ~= nameB then
                return Directory.sortAsc and (nameA < nameB) or (nameA > nameB)
            end
            return a.statusRank < b.statusRank
        elseif Directory.sortField == "zone" then
            local zoneA = string.lower(a.zone or "")
            local zoneB = string.lower(b.zone or "")
            if zoneA ~= zoneB then
                return Directory.sortAsc and (zoneA < zoneB) or (zoneA > zoneB)
            end
            return string.lower(a.fullName ~= "" and a.fullName or a.rawName) < string.lower(b.fullName ~= "" and b.fullName or b.rawName)
        end
        return a.statusRank < b.statusRank
    end)

    f.matchedItems = matched

    local function GetSortArrow(field)
        if Directory.sortField == field then
            return Directory.sortAsc and " |cff00e5ff▲|r" or " |cff00e5ff▼|r"
        end
        return ""
    end

    if f.btnStatus then f.btnStatus.text:SetText("Status" .. GetSortArrow("status")) end
    if f.btnName then f.btnName.text:SetText("Roleplayer / Full Name" .. GetSortArrow("name")) end
    if f.btnZone then f.btnZone.text:SetText("Current Zone / Vicinity" .. GetSortArrow("zone")) end

    if f.totalText then
        f.totalText:SetText("|cff00ccff" .. table.getn(matched) .. "|r shown (|cff00ff66" .. onlineCount .. " online|r)")
    end

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

            if Directory.selectedPlayer == item.rawName then
                row:SetBackdropColor(0.08, 0.18, 0.28, 0.95)
                row:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            else
                row:SetBackdropColor(0.04, 0.04, 0.05, (math.mod(i, 2) == 0) and 0.85 or 0.45)
                row:SetBackdropBorderColor(0.14, 0.14, 0.17, 1.0)
            end

            local statusText = not item.isOnline and "|cff777788○ Off|r" or (item.isIC and "|cff00ff88● IC|r" or "|cffffaa00● OOC|r")
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
    PUIRoleplay.Comms:SendPing("P")
    Directory:RefreshList(f.searchEB and f.searchEB:GetText() or "")
end

--------------------------------------------------------------------------------
-- World Map RP Location Pins
--------------------------------------------------------------------------------
function Directory:UpdateWorldMapPins()
    if not WorldMapFrame:IsVisible() then return end

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
                    tex:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
                    pin.tex = tex

                    pin:SetScript("OnEnter", function()
                        if this.charName then
                            WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
                            WorldMapTooltip:AddLine(this.fullName or this.charName, 0.0, 0.8, 1.0)
                            WorldMapTooltip:AddLine(this.isIC and "Status: In Character (IC)" or "Status: Out of Character (OOC)", 0.8, 0.8, 0.8)
                            WorldMapTooltip:Show()
                        end
                    end)
                    pin:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
                    pin:SetScript("OnClick", function()
                        if this.charName then Directory:ShowPlayerFlyout(this.charName) end
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
