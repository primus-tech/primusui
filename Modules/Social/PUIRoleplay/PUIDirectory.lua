--[[
    PrimusUI: PUIRoleplay Directory & World Map Pins (PUIDirectory.lua)
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

--------------------------------------------------------------------------------
-- Build Directory UI Window
--------------------------------------------------------------------------------
function Directory:BuildFrame()
    if dirFrame then return dirFrame end
    
    local f = CreateFrame("Frame", "Primus_PUIRoleplay_Directory", UIParent)
    f:SetWidth(520)
    f:SetHeight(480)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
            this:SetBackdropColor(0.0, 0.35, 0.55, 0.6)
            this:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0)
            
            if this.targetPlayerName then
                local data = PUIRoleplay:GetCharacterData(this.targetPlayerName)
                if data then
                    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                    local fullName = data.full_name or this.targetPlayerName
                    local colorHex = data.class_color or "FFFFFF"
                    GameTooltip:AddLine("|cff" .. colorHex .. fullName .. "|r (|cff888888" .. this.targetPlayerName .. "|r)")
                    
                    local isOnline = PUIRoleplay:IsPlayerOnline(this.targetPlayerName)
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
                    
                    if data.race and data.race ~= "" or data.class and data.class ~= "" then
                        GameTooltip:AddLine((data.race or "") .. " " .. (data.class or ""), 0.8, 0.8, 0.8)
                    end
                    if data.zone and data.zone ~= "" then
                        GameTooltip:AddLine("Zone: |cffffffff" .. data.zone .. "|r", 0.7, 0.7, 0.7)
                    end
                    if data.ic_pronouns and data.ic_pronouns ~= "" then
                        GameTooltip:AddLine("Pronouns: |cffffffff" .. data.ic_pronouns .. "|r", 0.6, 0.6, 0.6)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffClick|r to open RP Profile Sheet.", 0.2, 0.8, 0.2)
                    GameTooltip:Show()
                end
            end
        end)
        
        row:SetScript("OnLeave", function()
            this:SetBackdropColor(0.04, 0.04, 0.05, (math.mod(i, 2) == 0) and 0.85 or 0.45)
            this:SetBackdropBorderColor(0.14, 0.14, 0.17, 1.0)
            GameTooltip:Hide()
        end)
        
        row:SetScript("OnClick", function()
            if this.targetPlayerName then
                PUIRoleplay:OpenProfile(this.targetPlayerName)
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
    
    dirFrame = f
    return f
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
    
    local matched = {}
    local totalFound = 0
    local onlineCount = 0
    
    for name, data in pairs(allChars) do
        if data and (showNSFW or data.nsfw == "0" or data.nsfw == "" or data.nsfw == nil) then
            totalFound = totalFound + 1
            local isOnline = PUIRoleplay:IsPlayerOnline(name)
            if isOnline then onlineCount = onlineCount + 1 end
            
            local fullName = data.full_name or name
            local zone = data.zone or ""
            local class = data.class or ""
            local classColor = data.class_color or "FFFFFF"
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
    
    for i = 1, VISIBLE_ROWS do
        local row = f.rows[i]
        local itemIdx = f.currentOffset + i
        local item = matched[itemIdx]
        
        if item then
            row.targetPlayerName = item.rawName
            
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
            
            row.zoneTxt:SetText(item.zone ~= "" and item.zone or "|cff555555Unknown|r")
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
                            PUIRoleplay:OpenProfile(this.charName)
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
