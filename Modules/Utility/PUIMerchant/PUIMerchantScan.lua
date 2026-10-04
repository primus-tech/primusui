--[[
    PrimusUI Module: PUIMerchant (15-Second Patient Scanner Engine & Ingestion Pipeline)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. Server-Safe 15.0s Patient AH Scanner Loop (strictly respecting OctoWoW DDoS rate limiters).
    2. Real-time 1-second countdown updates for UI displays.
    3. Asynchronous page query watchdog (25.0s timeout with 3 retries).
    4. Categorized Scanning Scopes (All, Trade Goods, Consumables, Weapons/Armor).
    5. Tier 2 Passive Browse Sniffer for organic auction browsing.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMerchant = Primus.PUIMerchant or {}
Primus.PUIMerchant = PUIMerchant

local DB    = Primus.DB
local Utils = Primus.Utils
local Time  = Primus.Time
local Items = Primus.Items

-- Scanner State Variables
local isScanning = false
local isPaused = false
local scanPage = 0
local totalPages = 1
local totalAuctionsCataloged = 0
local isWaitingForNextPage = false
local lastQueryTime = 0
local pageCooldownEnd = 0
local pageRetries = 0
local maxRetries = 3
local currentScope = 0 -- 0 = All, 6 = Trade Goods, 4 = Consumables, 1 = Weapons, 2 = Armor

local PAGE_COOLDOWN = 15.0  -- 15-second inter-page delay to guarantee safety on DDoS-limited servers
local SCAN_TIMEOUT  = 25.0  -- 25-second watchdog for slow server responses

-- In-memory accumulator table for active scan batch
local scanAccumulator = {}

PUIMerchant.scannerState = {
    isScanning = false,
    isPaused = false,
    scanPage = 0,
    totalPages = 1,
    totalCataloged = 0,
    remainingCooldown = 0,
    statusText = "Ready",
}

-- Update scanner state snapshot for UI components
local function UpdateScannerState(statusMsg)
    PUIMerchant.scannerState.isScanning = isScanning
    PUIMerchant.scannerState.isPaused = isPaused
    PUIMerchant.scannerState.scanPage = scanPage
    PUIMerchant.scannerState.totalPages = totalPages
    PUIMerchant.scannerState.totalCataloged = totalAuctionsCataloged
    
    local now = GetTime()
    local rem = math.floor(pageCooldownEnd - now)
    if rem < 0 then rem = 0 end
    PUIMerchant.scannerState.remainingCooldown = rem

    if statusMsg then
        PUIMerchant.scannerState.statusText = statusMsg
    end

    if PUIMerchant.UpdateFlyoutScannerUI then
        PUIMerchant:UpdateFlyoutScannerUI()
    end
end

-- =========================================================================
-- SCANNER CONTROL INTERFACE
-- =========================================================================

-- Start Full or Scoped AH Scan
function PUIMerchant:StartScan(scopeCategory)
    if not AuctionFrame or not AuctionFrame:IsShown() then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: Open the Auction House to run an AH scan.", "ffbb33"))
        return
    end

    if isScanning then
        if isPaused then
            self:ResumeScan()
        else
            self:PauseScan()
        end
        return
    end

    if not CanSendAuctionQuery() then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: AH query is temporarily on cooldown. Please wait a moment.", "ffbb33"))
        return
    end

    isScanning = true
    isPaused = false
    scanPage = 0
    totalPages = 1
    totalAuctionsCataloged = 0
    isWaitingForNextPage = false
    pageRetries = 0
    currentScope = scopeCategory or 0
    scanAccumulator = {}

    lastQueryTime = GetTime()
    pageCooldownEnd = lastQueryTime + PAGE_COOLDOWN

    local scopeName = "All Categories"
    if currentScope == 6 then scopeName = "Trade Goods"
    elseif currentScope == 4 then scopeName = "Consumables"
    elseif currentScope == 1 then scopeName = "Weapons"
    elseif currentScope == 2 then scopeName = "Armor" end

    UpdateScannerState(string.format("Requesting Page 1 (%s)...", scopeName))
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: Starting 15s-Paced Scan [%s]...", scopeName), "69ccf0"))

    QueryAuctionItems("", nil, nil, 0, currentScope, 0, 0, 0, 0, 0)
end

-- Pause Active Scan
function PUIMerchant:PauseScan()
    if not isScanning or isPaused then return end
    isPaused = true
    UpdateScannerState("Scan Paused")
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: AH scan paused. Click Resume in the flyout to continue.", "ffbb33"))
end

-- Resume Paused Scan
function PUIMerchant:ResumeScan()
    if not isScanning or not isPaused then return end
    isPaused = false
    lastQueryTime = GetTime()
    pageCooldownEnd = lastQueryTime + PAGE_COOLDOWN
    isWaitingForNextPage = true
    UpdateScannerState(string.format("Resuming at Page %d/%d...", scanPage + 1, totalPages))
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIMerchant]: Resuming AH scan...", "69ccf0"))
end

-- Stop Active Scan
function PUIMerchant:StopScan()
    if not isScanning then return end
    isScanning = false
    isPaused = false
    isWaitingForNextPage = false

    -- Ingest whatever data was accumulated before stopping
    self:FlushScanAccumulator()

    UpdateScannerState(string.format("Stopped (%d cataloged)", totalAuctionsCataloged))
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: AH scan stopped. %d listings cataloged.", totalAuctionsCataloged), "ffbb33"))
end

-- Process Returned Auction Batch
function PUIMerchant:ProcessScanResults()
    if not isScanning or isPaused then return end

    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")

    -- Initial query latency / empty results fallback with retry
    if (not totalAuctions or totalAuctions == 0) and numBatchAuctions == 0 and scanPage == 0 then
        if pageRetries < maxRetries then
            pageRetries = pageRetries + 1
            isWaitingForNextPage = true
            lastQueryTime = GetTime()
            pageCooldownEnd = lastQueryTime + PAGE_COOLDOWN
            UpdateScannerState(string.format("Waiting on AH server (retry %d)...", pageRetries))
            return
        else
            self:FinishScan()
            return
        end
    end

    if totalAuctions and totalAuctions > 0 then
        totalPages = math.ceil(totalAuctions / (NUM_AUCTION_ITEMS_PER_PAGE or 50))
    end

    if numBatchAuctions and numBatchAuctions > 0 then
        for i = 1, numBatchAuctions do
            local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice = GetAuctionItemInfo("list", i)
            if name and count and count > 0 then
                local unitPrice = 0
                if buyoutPrice and buyoutPrice > 0 then
                    unitPrice = math.floor(buyoutPrice / count)
                elseif minBid and minBid > 0 then
                    unitPrice = math.floor(minBid / count)
                end

                if unitPrice > 0 then
                    local clean = self:CleanItemName(name)
                    if clean and clean ~= "" then
                        if not scanAccumulator[clean] then
                            scanAccumulator[clean] = {
                                prices = {},
                                meta = {
                                    texture = texture,
                                    quality = quality or 1,
                                    itemLevel = level or 1,
                                }
                            }
                        end
                        table.insert(scanAccumulator[clean].prices, unitPrice)
                        totalAuctionsCataloged = totalAuctionsCataloged + 1
                    end
                end
            end
        end
    end

    scanPage = scanPage + 1
    pageRetries = 0

    if scanPage >= totalPages or (numBatchAuctions == 0 and scanPage > 1) then
        self:FinishScan()
    else
        isWaitingForNextPage = true
        lastQueryTime = GetTime()
        pageCooldownEnd = lastQueryTime + PAGE_COOLDOWN
        UpdateScannerState(string.format("Page %d/%d (%d items) - Cooldown 15s...", scanPage, totalPages, totalAuctionsCataloged))
    end
end

-- Flush Accumulator to Database
function PUIMerchant:FlushScanAccumulator()
    local realm = GetRealmName() or "Default"
    for itemName, acc in pairs(scanAccumulator) do
        if acc.prices and table.getn(acc.prices) > 0 then
            self:RecordItemScanBatch(itemName, acc.prices, acc.meta, realm)
        end
    end
    scanAccumulator = {}
end

-- Complete Scan
function PUIMerchant:FinishScan()
    isScanning = false
    isPaused = false
    isWaitingForNextPage = false

    self:FlushScanAccumulator()

    local realm = GetRealmName() or "Default"
    local realmData = self:GetRealmPriceData(realm)
    realmData.lastScan = Time:GetServerTimestamp()
    realmData.totalListings = totalAuctionsCataloged

    UpdateScannerState(string.format("Scan Complete! (%d cataloged)", totalAuctionsCataloged))
    DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIMerchant]: AH Scan Complete! %d listings cataloged across %d pages.", totalAuctionsCataloged, scanPage), "69ccf0"))
end

-- =========================================================================
-- PASSIVE BROWSE SNIFFER (Tier 2 Ingestion)
-- =========================================================================

function PUIMerchant:SniffBrowsePage()
    if isScanning then return end
    if not AuctionFrame or not AuctionFrame:IsShown() then return end

    local numBatchAuctions = GetNumAuctionItems("list")
    if not numBatchAuctions or numBatchAuctions == 0 then return end

    local realm = GetRealmName() or "Default"
    for i = 1, numBatchAuctions do
        local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice = GetAuctionItemInfo("list", i)
        if name and count and count > 0 then
            local unitPrice = 0
            if buyoutPrice and buyoutPrice > 0 then
                unitPrice = math.floor(buyoutPrice / count)
            elseif minBid and minBid > 0 then
                unitPrice = math.floor(minBid / count)
            end

            if unitPrice > 0 then
                self:RecordSingleAuction(name, unitPrice, {
                    texture = texture,
                    quality = quality or 1,
                    itemLevel = level or 1,
                }, realm)
            end
        end
    end
end

-- =========================================================================
-- ASYNCHRONOUS SCANNER TICKER & WATCHDOG
-- =========================================================================

function PUIMerchant:InitScannerTicker()
    -- Fast 0.25s loop for query dispatch & watchdog
    Time:Every(0.25, function()
        if not isScanning or isPaused then return end

        local now = GetTime()

        -- Auto-abort if player closes AH mid-scan
        if not AuctionFrame or not AuctionFrame:IsShown() then
            PUIMerchant:StopScan()
            return
        end

        -- Dispatch next page once cooldown elapsed and server ready
        if isWaitingForNextPage then
            if now >= pageCooldownEnd and CanSendAuctionQuery() then
                isWaitingForNextPage = false
                lastQueryTime = now
                pageCooldownEnd = now + PAGE_COOLDOWN
                UpdateScannerState(string.format("Querying Page %d/%d (%d items)...", scanPage + 1, totalPages, totalAuctionsCataloged))
                QueryAuctionItems("", nil, nil, 0, currentScope, 0, scanPage, 0, 0, 0)
            end
        else
            -- Watchdog: detect dropped packets or server lag (> SCAN_TIMEOUT seconds)
            if (now - lastQueryTime) > SCAN_TIMEOUT then
                if pageRetries < maxRetries then
                    pageRetries = pageRetries + 1
                    lastQueryTime = now
                    pageCooldownEnd = now + PAGE_COOLDOWN
                    if CanSendAuctionQuery() then
                        UpdateScannerState(string.format("Retrying Page %d/%d (attempt %d)...", scanPage + 1, totalPages, pageRetries))
                        QueryAuctionItems("", nil, nil, 0, currentScope, 0, scanPage, 0, 0, 0)
                    else
                        isWaitingForNextPage = true
                    end
                else
                    PUIMerchant:FinishScan()
                end
            end
        end
    end, "PUIMerchantScanner")

    -- 1.0s UI Countdown Ticker
    Time:Every(1.0, function()
        if not isScanning then return end
        if isWaitingForNextPage and not isPaused then
            local now = GetTime()
            local rem = math.floor(pageCooldownEnd - now)
            if rem > 0 then
                UpdateScannerState(string.format("Page %d/%d (%d items) - Next in %ds...", scanPage, totalPages, totalAuctionsCataloged, rem))
            end
        end
    end, "PUIMerchantCountdown")
end
