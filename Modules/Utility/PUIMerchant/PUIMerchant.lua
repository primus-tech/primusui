--[[
    PrimusUI Module: PUIMerchant (Auctioneer-Style Market Cataloging & Pricing)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. Auction House Economy Scanner: Catalogs all active auctions and price histories.
    2. Statistical Market Pricing: Tracks Min Buyout, Market Average, and Seen counts.
    3. Tooltip Integration: Injects real-time market value and min buyout into all GameTooltips.
    4. Price-Per-Unit display and Shift+Click Quick Buyout on Browse listings.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMerchant = Primus.PUIMerchant or {}
Primus.PUIMerchant = PUIMerchant
_G.PUIMerchant = PUIMerchant
Primus:RegisterModule("PUIMerchant", PUIMerchant, "Utility")

local DB      = Primus.DB
local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Time    = Primus.Time

local merchantDB = DB:RegisterNamespace("PUIMerchant", {
    enabled = true,
    quickBuyout = true,
    showTooltipPrices = true,
    priceData = {}, -- [itemName] = { minBuyout = 0, totalBuyout = 0, count = 0, lastSeen = 0 }
})

local isScanning = false
local scanPage = 0
local totalAuctionsCataloged = 0
local scanBtn = nil
local scanStatusText = nil
local unitPriceLabels = {}

-- Clean Item Name Extractor
local function CleanItemName(linkOrName)
    if not linkOrName then return nil end
    local s, e, name = string.find(linkOrName, "%[(.+)%]")
    return name or linkOrName
end

-- Record an Auction Listing into the Market Database
function PUIMerchant:RecordAuction(itemName, unitPrice)
    if not itemName or not unitPrice or unitPrice <= 0 then return end

    local pData = merchantDB.priceData[itemName]
    if not pData then
        pData = {
            minBuyout = unitPrice,
            totalBuyout = unitPrice,
            count = 1,
            lastSeen = Time:GetServerTimestamp(),
        }
        merchantDB.priceData[itemName] = pData
    else
        if pData.minBuyout == 0 or unitPrice < pData.minBuyout then
            pData.minBuyout = unitPrice
        end
        pData.totalBuyout = pData.totalBuyout + unitPrice
        pData.count = pData.count + 1
        pData.lastSeen = Time:GetServerTimestamp()
    end
end

-- Get Market Price Info for an Item
function PUIMerchant:GetItemPriceInfo(itemName)
    if not itemName then return nil end
    local clean = CleanItemName(itemName)
    local pData = merchantDB.priceData[clean]
    if not pData or pData.count == 0 then return nil end

    local avgBuyout = math.floor(pData.totalBuyout / pData.count)
    return pData.minBuyout, avgBuyout, pData.count, pData.lastSeen
end

-- =========================================================================
-- FULL AH SCANNER ENGINE
-- =========================================================================

-- Start Full AH Scan
function PUIMerchant:StartScan()
    if not AuctionFrame or not AuctionFrame:IsShown() then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: Open the Auction House to run a scan.", "ffbb33"))
        return
    end

    if not CanSendAuctionQuery() then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: AH query is on cooldown. Try again in a moment.", "ffbb33"))
        return
    end

    isScanning = true
    scanPage = 0
    totalAuctionsCataloged = 0

    if scanBtn then
        scanBtn:SetText("Scanning...")
        scanBtn:Disable()
    end

    if scanStatusText then
        scanStatusText:SetText("Scanning page 0...")
        scanStatusText:Show()
    end

    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: Starting full AH catalog scan...", "69ccf0"))
    QueryAuctionItems("", nil, nil, 0, 0, 0, scanPage, 0, 0, 0)
end

-- Process Returned Auction Scan Batch
function PUIMerchant:ProcessScanResults()
    if not isScanning then return end

    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    if numBatchAuctions == 0 then
        self:FinishScan()
        return
    end

    for i = 1, numBatchAuctions do
        local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice = GetAuctionItemInfo("list", i)
        if name and count and count > 0 and buyoutPrice and buyoutPrice > 0 then
            local unitPrice = math.floor(buyoutPrice / count)
            self:RecordAuction(name, unitPrice)
            totalAuctionsCataloged = totalAuctionsCataloged + 1
        end
    end

    local totalPages = math.ceil(totalAuctions / NUM_AUCTION_ITEMS_PER_PAGE)
    scanPage = scanPage + 1

    if scanStatusText then
        scanStatusText:SetText(string.format("Page %d / %d (%d items)", scanPage, totalPages, totalAuctionsCataloged))
    end

    if scanPage < totalPages and CanSendAuctionQuery() then
        QueryAuctionItems("", nil, nil, 0, 0, 0, scanPage, 0, 0, 0)
    else
        self:FinishScan()
    end
end

-- Complete Scan
function PUIMerchant:FinishScan()
    isScanning = false
    if scanBtn then
        scanBtn:SetText("Scan AH")
        scanBtn:Enable()
    end
    if scanStatusText then
        scanStatusText:SetText(string.format("Scan Complete! (%d cataloged)", totalAuctionsCataloged))
    end
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: AH Scan Complete! %d auction listings cataloged.", totalAuctionsCataloged), "69ccf0"))
end

-- =========================================================================
-- TOOLTIP MARKET PRICE INJECTION
-- =========================================================================

local function InjectTooltipPrice(tooltip)
    if not merchantDB.showTooltipPrices then return end

    local name = _G[tooltip:GetName() .. "TextLeft1"]
    if not name or not name:GetText() then return end

    local itemName = name:GetText()
    local minBuyout, avgBuyout, seenCount = PUIMerchant:GetItemPriceInfo(itemName)

    if minBuyout and avgBuyout then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("|cffffd100PUIMerchant Market:|r", Utils.FormatMoney(avgBuyout))
        tooltip:AddDoubleLine("|cffaaaaaaMin Buyout:|r", Utils.FormatMoney(minBuyout))
        tooltip:AddDoubleLine("|cffaaaaaaSeen in AH:|r", string.format("|cff33ccff%d times|r", seenCount or 1))
        tooltip:Show()
    end
end

-- =========================================================================
-- BROWSE ROW PRICE-PER-UNIT & QUICK BUYOUT
-- =========================================================================

local function GetUnitPriceLabel(index, rowButton)
    if unitPriceLabels[index] then return unitPriceLabels[index] end

    local label = rowButton:CreateFontString(nil, "OVERLAY")
    label:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    label:SetPoint("BOTTOMRIGHT", rowButton, "BOTTOMRIGHT", -12, 2)
    label:SetTextColor(0.85, 0.85, 0.5)
    unitPriceLabels[index] = label
    return label
end

function PUIMerchant:UpdateBrowsePrices()
    if not AuctionFrame or not AuctionFrame:IsShown() then return end
    if not BrowseButton1 then return end

    local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame) or 0
    local numBatchAuctions = GetNumAuctionItems("list")

    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local rowBtn = _G["BrowseButton" .. i]
        if rowBtn and rowBtn:IsShown() then
            local index = offset + i
            local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice = GetAuctionItemInfo("list", index)
            local label = GetUnitPriceLabel(i, rowBtn)

            if count and count > 1 and buyoutPrice and buyoutPrice > 0 then
                local unitPrice = math.floor(buyoutPrice / count)
                label:SetText(string.format("(%s ea)", Utils.FormatMoney(unitPrice)))
                label:Show()
            else
                label:Hide()
            end
        else
            if unitPriceLabels[i] then unitPriceLabels[i]:Hide() end
        end
    end
end

local function HookBrowseRows()
    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local rowBtn = _G["BrowseButton" .. i]
        if rowBtn and not rowBtn.primusHooked then
            rowBtn.browseIndex = i
            rowBtn.origOnClick = rowBtn:GetScript("OnClick")
            rowBtn:SetScript("OnClick", function()
                if IsShiftKeyDown() and merchantDB.quickBuyout then
                    local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame) or 0
                    local index = offset + (this.browseIndex or this:GetID() or 1)
                    local name, _, count, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", index)
                    if buyoutPrice and buyoutPrice > 0 then
                        SetSelectedAuctionItem("list", index)
                        PlaceAuctionBid("list", index, buyoutPrice)
                        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: Quick Buyout: %s (x%d) for %s", name or "Item", count or 1, Utils.FormatMoney(buyoutPrice)), "69ccf0"))
                        return
                    end
                end
                if this.origOnClick then
                    this.origOnClick()
                end
            end)
            rowBtn.primusHooked = true
        end
    end
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIMerchant:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIMerchant", "Utility", {
        title = "PUIMerchant: Economy & Valuation",
        description = "Auction House scanner, market pricing database, and item tooltip integration.",
        fields = {
            {
                key = "enabled",
                label = "Enable PUIMerchant Economy Engine",
                type = "checkbox",
                default = true,
                get = function() return merchantDB:Get("enabled", true) end,
                set = function(val)
                    merchantDB:Set("enabled", val)
                    if val then PUIMerchant:OnEnable() else PUIMerchant:OnDisable() end
                end,
            },
            {
                key = "quickBuyout",
                label = "Shift+Click Quick Buyout on Browse Rows",
                type = "checkbox",
                default = true,
                get = function() return merchantDB:Get("quickBuyout", true) end,
                set = function(val) merchantDB:Set("quickBuyout", val) end,
            },
            {
                key = "showTooltipPrices",
                label = "Inject AH Market Prices into GameTooltips",
                type = "checkbox",
                default = true,
                get = function() return merchantDB:Get("showTooltipPrices", true) end,
                set = function(val) merchantDB:Set("showTooltipPrices", val) end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUIMerchant:OnInitialize()
    self:RegisterOptionsFlare()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("merchant", function()
            if AuctionFrame and AuctionFrame:IsShown() then
                PUIMerchant:StartScan()
            else
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: Auction & market valuation active. Open the AH and click 'Scan AH' or hover over items to see market value.", "69ccf0"))
            end
        end, "PUIMerchant AH price scanner & valuation (/pui merchant)")
    end
end

function PUIMerchant:OnEnable()
    -- Hook AH Frame Show to inject Scan AH Button
    Events:Register("AUCTION_HOUSE_SHOW", "PUIMerchant", function()
        HookBrowseRows()
        PUIMerchant:UpdateBrowsePrices()

        if not scanBtn and AuctionFrameBrowse then
            scanBtn = Widgets:CreateButton(AuctionFrameBrowse, "Scan AH", 74, 22, function()
                PUIMerchant:StartScan()
            end)
            scanBtn:SetPoint("TOPRIGHT", AuctionFrameBrowse, "TOPRIGHT", -25, -42)
            scanBtn:SetBackdropBorderColor(1.0, 0.84, 0.0, 1)

            scanStatusText = AuctionFrameBrowse:CreateFontString(nil, "OVERLAY")
            scanStatusText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
            scanStatusText:SetPoint("RIGHT", scanBtn, "LEFT", -8, 0)
            scanStatusText:SetTextColor(0.4, 0.8, 1.0)
            scanStatusText:Hide()
        end
    end)

    Events:Register("AUCTION_ITEM_LIST_UPDATE", "PUIMerchant", function()
        if isScanning then
            PUIMerchant:ProcessScanResults()
        else
            PUIMerchant:UpdateBrowsePrices()
        end
    end)

    -- Tooltip Hooks for Price Display
    if not self._hookedTooltips then
        local origSetBagItem = GameTooltip.SetBagItem
        GameTooltip.SetBagItem = function(self, bag, slot)
            local r1, r2, r3, r4 = origSetBagItem(self, bag, slot)
            InjectTooltipPrice(self)
            return r1, r2, r3, r4
        end

        local origSetInventoryItem = GameTooltip.SetInventoryItem
        GameTooltip.SetInventoryItem = function(self, unit, slot)
            local r1, r2, r3, r4 = origSetInventoryItem(self, unit, slot)
            InjectTooltipPrice(self)
            return r1, r2, r3, r4
        end

        local origSetHyperlink = GameTooltip.SetHyperlink
        GameTooltip.SetHyperlink = function(self, link)
            local r1, r2, r3, r4 = origSetHyperlink(self, link)
            InjectTooltipPrice(self)
            return r1, r2, r3, r4
        end
        self._hookedTooltips = true
    end
end

function PUIMerchant:OnDisable()
    Events:UnregisterOwner("PUIMerchant")
    if scanBtn then scanBtn:Hide() end
    if scanStatusText then scanStatusText:Hide() end
end
