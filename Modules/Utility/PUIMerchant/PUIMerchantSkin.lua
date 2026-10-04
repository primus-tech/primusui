--[[
    PrimusUI Module: PUIMerchant (Auction House Dark Glass Skin & Dockable Control Flyout)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. PrimusUI Dark Glass 1-Pixel Theme for AuctionFrame (Browse, Bids, Auctions).
    2. User-Chosen Dockable Flyout Control Drawer (Left or Right side).
    3. Real-time Scanner UI with 15s Countdown, Progress Bar, and Scope Presets.
    4. Quick Shortcuts (Market Explorer, Deal Sniper, DB Pruning).
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMerchant = Primus.PUIMerchant or {}
Primus.PUIMerchant = PUIMerchant

local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils

local flyoutFrame = nil
local flyoutToggleBtn = nil
local scanActionButton = nil
local scanStatusLabel = nil
local scanCountdownLabel = nil
local scanProgressBar = nil

-- =========================================================================
-- AUCTION HOUSE FRAME DARK GLASS RESKIN
-- =========================================================================

local function SkinEditBox(editBox)
    if not editBox or editBox.primusSkinned then return end
    editBox:SetBackdrop(Media:Fetch("border", "1Pixel"))
    editBox:SetBackdropColor(0.04, 0.04, 0.06, 0.90)
    editBox:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
    editBox:SetTextInsets(4, 4, 0, 0)
    editBox.primusSkinned = true
end

local function SkinButton(btn, text)
    if not btn or btn.primusSkinned then return end
    btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    btn:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
    if text and btn.SetText then btn:SetText(text) end

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.20, 0.22, 0.28, 1.0)
        btn:SetBackdropBorderColor(0.40, 0.70, 1.00, 1.0)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
    end)
    btn.primusSkinned = true
end

local function SkinTab(tab)
    if not tab or tab.primusSkinned then return end
    local tabName = tab:GetName()
    if _G[tabName .. "Left"] then _G[tabName .. "Left"]:Hide() end
    if _G[tabName .. "Middle"] then _G[tabName .. "Middle"]:Hide() end
    if _G[tabName .. "Right"] then _G[tabName .. "Right"]:Hide() end
    if _G[tabName .. "LeftDisabled"] then _G[tabName .. "LeftDisabled"]:Hide() end
    if _G[tabName .. "MiddleDisabled"] then _G[tabName .. "MiddleDisabled"]:Hide() end
    if _G[tabName .. "RightDisabled"] then _G[tabName .. "RightDisabled"]:Hide() end

    tab:SetBackdrop(Media:Fetch("border", "1Pixel"))
    tab:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    tab:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)

    -- Cyan active indicator underline
    local indicator = tab:CreateTexture(nil, "OVERLAY")
    indicator:SetTexture(Media:Fetch("texture", "Solid") or "Interface\\Buttons\\WHITE8X8")
    indicator:SetVertexColor(0.20, 0.75, 1.0, 1.0)
    indicator:SetHeight(2)
    indicator:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 2, 1)
    indicator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 1)
    indicator:Hide()
    tab.primusIndicator = indicator

    tab.primusSkinned = true
end

function PUIMerchant:SkinAuctionHouse()
    if not AuctionFrame or AuctionFrame.primusSkinned then return end

    -- Hide Blizzard standard textures
    local texturesToHide = {
        "AuctionFrameTopLeft", "AuctionFrameTop", "AuctionFrameTopRight",
        "AuctionFrameBotLeft", "AuctionFrameBot", "AuctionFrameBotRight",
    }
    for _, texName in ipairs(texturesToHide) do
        local tex = _G[texName]
        if tex then tex:Hide() end
    end

    if AuctionPortraitTexture then AuctionPortraitTexture:Hide() end

    -- Main AuctionFrame Container
    AuctionFrame:SetBackdrop(Media:Fetch("border", "1Pixel"))
    AuctionFrame:SetBackdropColor(0.06, 0.06, 0.09, 0.96)
    AuctionFrame:SetBackdropBorderColor(0.20, 0.20, 0.25, 1.0)

    -- Title Styling
    if AuctionTitleText then
        AuctionTitleText:SetFont(Media:Fetch("font", "Default"), 13, "OUTLINE")
        AuctionTitleText:SetTextColor(0.4, 0.8, 1.0)
        AuctionTitleText:ClearAllPoints()
        AuctionTitleText:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 18, -12)
    end

    -- Close Button
    if AuctionFrameCloseButton then
        AuctionFrameCloseButton:SetPoint("TOPRIGHT", AuctionFrame, "TOPRIGHT", 2, -10)
    end

    -- Tabs
    for i = 1, 3 do
        local tab = _G["AuctionFrameTab" .. i]
        if tab then
            SkinTab(tab)
        end
    end

    -- Browse Tab Elements
    SkinEditBox(BrowseName)
    SkinEditBox(BrowseMinLevel)
    SkinEditBox(BrowseMaxLevel)
    SkinButton(BrowseSearchButton, "Search")
    SkinButton(BrowseResetButton, "Reset")
    SkinButton(BrowseBidButton, "Bid")
    SkinButton(BrowseBuyoutButton, "Buyout")
    SkinButton(BrowseCloseButton, "Close")

    -- Auctions Tab Elements
    if StartPriceGold then SkinEditBox(StartPriceGold) end
    if StartPriceSilver then SkinEditBox(StartPriceSilver) end
    if StartPriceCopper then SkinEditBox(StartPriceCopper) end
    if BuyoutPriceGold then SkinEditBox(BuyoutPriceGold) end
    if BuyoutPriceSilver then SkinEditBox(BuyoutPriceSilver) end
    if BuyoutPriceCopper then SkinEditBox(BuyoutPriceCopper) end
    if AuctionsCreateAuctionButton then SkinButton(AuctionsCreateAuctionButton, "Create Auction") end
    if AuctionsCancelAuctionButton then SkinButton(AuctionsCancelAuctionButton, "Cancel Auction") end
    if AuctionsCloseButton then SkinButton(AuctionsCloseButton, "Close") end

    -- Bids Tab Elements
    if BidBidButton then SkinButton(BidBidButton, "Bid") end
    if BidBuyoutButton then SkinButton(BidBuyoutButton, "Buyout") end
    if BidCloseButton then SkinButton(BidCloseButton, "Close") end

    AuctionFrame.primusSkinned = true
end

-- =========================================================================
-- DOCKABLE FLYOUT CONTROL DRAWER (LEFT / RIGHT)
-- =========================================================================

function PUIMerchant:UpdateFlyoutAnchor()
    if not flyoutFrame or not AuctionFrame then return end

    local side = PUIMerchant.db:Get("flyoutSide", "RIGHT")
    flyoutFrame:ClearAllPoints()

    if side == "LEFT" then
        flyoutFrame:SetPoint("TOPRIGHT", AuctionFrame, "TOPLEFT", -2, 0)
        flyoutFrame:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMLEFT", -2, 0)
        if flyoutToggleBtn then
            flyoutToggleBtn:ClearAllPoints()
            flyoutToggleBtn:SetPoint("TOPRIGHT", flyoutFrame, "TOPLEFT", -1, -20)
            flyoutToggleBtn.text:SetText(PUIMerchant.db:Get("flyoutOpen", true) and "<" or ">")
        end
    else
        flyoutFrame:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 2, 0)
        flyoutFrame:SetPoint("BOTTOMLEFT", AuctionFrame, "BOTTOMRIGHT", 2, 0)
        if flyoutToggleBtn then
            flyoutToggleBtn:ClearAllPoints()
            flyoutToggleBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPRIGHT", 1, -20)
            flyoutToggleBtn.text:SetText(PUIMerchant.db:Get("flyoutOpen", true) and ">" or "<")
        end
    end
end

function PUIMerchant:ToggleFlyout(forceState)
    if not flyoutFrame then return end
    local isOpen = (forceState ~= nil) and forceState or not PUIMerchant.db:Get("flyoutOpen", true)
    PUIMerchant.db:Set("flyoutOpen", isOpen)

    if isOpen then
        flyoutFrame:Show()
    else
        flyoutFrame:Hide()
    end

    self:UpdateFlyoutAnchor()
end

function PUIMerchant:CreateFlyoutDrawer()
    if flyoutFrame or not AuctionFrame then return end

    flyoutFrame = CreateFrame("Frame", "PUIMerchantFlyoutFrame", AuctionFrame)
    flyoutFrame:SetWidth(194)
    flyoutFrame:SetBackdrop(Media:Fetch("border", "1Pixel"))
    flyoutFrame:SetBackdropColor(0.06, 0.06, 0.09, 0.96)
    flyoutFrame:SetBackdropBorderColor(0.20, 0.20, 0.25, 1.0)
    flyoutFrame:EnableMouse(true)

    -- Toggle Tab Button (Attached to outer edge)
    flyoutToggleBtn = CreateFrame("Button", "PUIMerchantFlyoutToggleBtn", AuctionFrame)
    flyoutToggleBtn:SetWidth(16)
    flyoutToggleBtn:SetHeight(36)
    flyoutToggleBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    flyoutToggleBtn:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
    flyoutToggleBtn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)

    local toggleText = flyoutToggleBtn:CreateFontString(nil, "OVERLAY")
    toggleText:SetFont(Media:Fetch("font", "Default"), 12, "OUTLINE")
    toggleText:SetPoint("CENTER", 0, 0)
    toggleText:SetText(">")
    toggleText:SetTextColor(0.4, 0.8, 1.0)
    flyoutToggleBtn.text = toggleText

    flyoutToggleBtn:SetScript("OnClick", function()
        PUIMerchant:ToggleFlyout()
    end)

    -- Header Title
    local header = flyoutFrame:CreateFontString(nil, "OVERLAY")
    header:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    header:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -10)
    header:SetText(Utils.ColorText("PUIMerchant Controls", "69ccf0"))

    -- Dock Switch Button (Toggle Left / Right)
    local dockSwitchBtn = Widgets:CreateButton(flyoutFrame, "Dock", 42, 18, function()
        local cur = PUIMerchant.db:Get("flyoutSide", "RIGHT")
        local newSide = (cur == "RIGHT") and "LEFT" or "RIGHT"
        PUIMerchant.db:Set("flyoutSide", newSide)
        PUIMerchant:UpdateFlyoutAnchor()
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: Flyout docked to %s.", newSide), "69ccf0"))
    end)
    dockSwitchBtn:SetPoint("TOPRIGHT", flyoutFrame, "TOPRIGHT", -8, -8)

    -- Separator Line 1
    local sep1 = flyoutFrame:CreateTexture(nil, "ARTWORK")
    sep1:SetTexture(Media:Fetch("texture", "Solid") or "Interface\\Buttons\\WHITE8X8")
    sep1:SetVertexColor(0.20, 0.20, 0.25, 0.8)
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 8, -32)
    sep1:SetPoint("TOPRIGHT", flyoutFrame, "TOPRIGHT", -8, -32)

    -- Section: 15s Patient Scanner
    local scanSectionLabel = flyoutFrame:CreateFontString(nil, "OVERLAY")
    scanSectionLabel:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    scanSectionLabel:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -38)
    scanSectionLabel:SetTextColor(0.9, 0.8, 0.4)
    scanSectionLabel:SetText("15s Patient AH Scanner")

    -- Scan Action Button (Start / Pause / Resume / Stop)
    scanActionButton = Widgets:CreateButton(flyoutFrame, "Scan AH (15s)", 176, 24, function()
        PUIMerchant:StartScan(0)
    end)
    scanActionButton:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -54)
    scanActionButton:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)

    -- Stop Button (Small)
    local stopScanBtn = Widgets:CreateButton(flyoutFrame, "Stop", 176, 18, function()
        PUIMerchant:StopScan()
    end)
    stopScanBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -82)
    stopScanBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8)

    -- Progress Bar
    scanProgressBar = CreateFrame("StatusBar", nil, flyoutFrame)
    scanProgressBar:SetWidth(176)
    scanProgressBar:SetHeight(10)
    scanProgressBar:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -106)
    scanProgressBar:SetStatusBarTexture(Media:Fetch("texture", "Solid") or "Interface\\Buttons\\WHITE8X8")
    scanProgressBar:SetStatusBarColor(0.20, 0.75, 1.0, 0.85)
    scanProgressBar:SetMinMaxValues(0, 100)
    scanProgressBar:SetValue(0)
    scanProgressBar:SetBackdrop(Media:Fetch("border", "1Pixel"))
    scanProgressBar:SetBackdropColor(0.04, 0.04, 0.06, 0.90)
    scanProgressBar:SetBackdropBorderColor(0.20, 0.20, 0.25, 1.0)

    -- Scan Status Text
    scanStatusLabel = flyoutFrame:CreateFontString(nil, "OVERLAY")
    scanStatusLabel:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    scanStatusLabel:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -120)
    scanStatusLabel:SetTextColor(0.7, 0.7, 0.7)
    scanStatusLabel:SetText("Ready to scan")

    -- Scan Countdown Text (Live 1s timer)
    scanCountdownLabel = flyoutFrame:CreateFontString(nil, "OVERLAY")
    scanCountdownLabel:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    scanCountdownLabel:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -134)
    scanCountdownLabel:SetTextColor(1.0, 0.84, 0.0)
    scanCountdownLabel:SetText("")

    -- Scope Selector Buttons
    local scopeAllBtn = Widgets:CreateButton(flyoutFrame, "All", 40, 18, function() PUIMerchant:StartScan(0) end)
    scopeAllBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -152)

    local scopeMatsBtn = Widgets:CreateButton(flyoutFrame, "Trade", 42, 18, function() PUIMerchant:StartScan(6) end)
    scopeMatsBtn:SetPoint("LEFT", scopeAllBtn, "RIGHT", 3, 0)

    local scopePotsBtn = Widgets:CreateButton(flyoutFrame, "Pots", 40, 18, function() PUIMerchant:StartScan(4) end)
    scopePotsBtn:SetPoint("LEFT", scopeMatsBtn, "RIGHT", 3, 0)

    local scopeGearBtn = Widgets:CreateButton(flyoutFrame, "Gear", 42, 18, function() PUIMerchant:StartScan(2) end)
    scopeGearBtn:SetPoint("LEFT", scopePotsBtn, "RIGHT", 3, 0)

    -- Separator Line 2
    local sep2 = flyoutFrame:CreateTexture(nil, "ARTWORK")
    sep2:SetTexture(Media:Fetch("texture", "Solid") or "Interface\\Buttons\\WHITE8X8")
    sep2:SetVertexColor(0.20, 0.20, 0.25, 0.8)
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 8, -178)
    sep2:SetPoint("TOPRIGHT", flyoutFrame, "TOPRIGHT", -8, -178)

    -- Section: Quick Shortcuts & Analytics
    local toolsLabel = flyoutFrame:CreateFontString(nil, "OVERLAY")
    toolsLabel:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    toolsLabel:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -186)
    toolsLabel:SetTextColor(0.9, 0.8, 0.4)
    toolsLabel:SetText("Market Tools & Explorer")

    -- Open Offline Explorer Button
    local openExplorerBtn = Widgets:CreateButton(flyoutFrame, "Offline Market Explorer", 176, 22, function()
        if PUIMerchant.ToggleMarketExplorer then
            PUIMerchant:ToggleMarketExplorer()
        end
    end)
    openExplorerBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -202)
    openExplorerBtn:SetBackdropBorderColor(0.20, 0.75, 1.0, 0.85)

    -- Open Deal Finder / Sniping Tab Button
    local openDealsBtn = Widgets:CreateButton(flyoutFrame, "Deal Finder & Sniper", 176, 22, function()
        if PUIMerchant.ToggleMarketExplorer then
            PUIMerchant:ToggleMarketExplorer(true)
        end
    end)
    openDealsBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -228)
    openDealsBtn:SetBackdropBorderColor(0.20, 0.85, 0.35, 0.85)

    -- Prune DB Button
    local pruneBtn = Widgets:CreateButton(flyoutFrame, "Prune Old History (>14d)", 176, 20, function()
        local purged = PUIMerchant:PruneOldHistory(nil, 14)
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: Pruned %d stale entries older than 14 days.", purged), "69ccf0"))
    end)
    pruneBtn:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 9, -256)

    -- Toggles
    local qbCheck = Widgets:CreateCheckButton(flyoutFrame, "Shift+Click Quick Buyout", 12, function(selfChecked)
        PUIMerchant.db:Set("quickBuyout", selfChecked)
    end)
    qbCheck:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -284)
    qbCheck:SetChecked(PUIMerchant.db:Get("quickBuyout", true))

    local ttCheck = Widgets:CreateCheckButton(flyoutFrame, "Show Prices in Tooltips", 12, function(selfChecked)
        PUIMerchant.db:Set("showTooltipPrices", selfChecked)
    end)
    ttCheck:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -304)
    ttCheck:SetChecked(PUIMerchant.db:Get("showTooltipPrices", true))

    local sparkCheck = Widgets:CreateCheckButton(flyoutFrame, "Shift-Hover Sparkline", 12, function(selfChecked)
        PUIMerchant.db:Set("showTooltipSparkline", selfChecked)
    end)
    sparkCheck:SetPoint("TOPLEFT", flyoutFrame, "TOPLEFT", 10, -324)
    sparkCheck:SetChecked(PUIMerchant.db:Get("showTooltipSparkline", true))

    PUIMerchant.flyoutFrame = flyoutFrame
    PUIMerchant:UpdateFlyoutAnchor()

    if not PUIMerchant.db:Get("flyoutOpen", true) then
        flyoutFrame:Hide()
    end
end

-- Reactive UI Update Loop for Flyout Scanner Status
function PUIMerchant:UpdateFlyoutScannerUI()
    if not flyoutFrame or not scanActionButton then return end

    local state = PUIMerchant.scannerState
    if not state then return end

    if state.isScanning then
        if state.isPaused then
            scanActionButton:SetText("Resume Scan")
            scanActionButton:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
            scanCountdownLabel:SetText("|cffffbb33[Paused]|r")
        else
            scanActionButton:SetText("Pause Scan")
            scanActionButton:SetBackdropBorderColor(0.20, 0.75, 1.0, 1.0)
            if state.remainingCooldown > 0 then
                scanCountdownLabel:SetText(string.format("Next query: |cffffd100%ds|r", state.remainingCooldown))
            else
                scanCountdownLabel:SetText("|cff1eff00Dispatching...|r")
            end
        end

        local pct = 0
        if state.totalPages and state.totalPages > 0 then
            pct = math.floor((state.scanPage / state.totalPages) * 100)
            if pct > 100 then pct = 100 end
        end
        scanProgressBar:SetValue(pct)
        scanStatusLabel:SetText(string.format("Page %d/%d (%d items)", state.scanPage, state.totalPages, state.totalCataloged))
    else
        scanActionButton:SetText("Scan AH (15s)")
        scanActionButton:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
        scanCountdownLabel:SetText("")
        scanStatusLabel:SetText(state.statusText or "Ready to scan")
        scanProgressBar:SetValue(0)
    end
end
