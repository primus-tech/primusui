--[[
    PrimusUI Module: PUIMerchant (Data & Statistical Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. Daily Partitioning Key Generator (YYYYMMDD / Server Epoch).
    2. Quantile & Quartile Calculator:
       - Average & Total Volume (N)
       - Median (50th percentile)
       - Core Fair Market Cluster (Median +- 15%) & Volume
       - Low Tier (Cheapest 35%) Average & Volume (Sniping/Bargain Floor)
       - High Tier (Top 35%) Average & Volume (Ceiling/Overpriced)
    3. Rolling 7-Day & 14-Day Running Averages & Medians.
    4. 14-Day History Pruner to prevent SavedVariables bloat.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMerchant = Primus.PUIMerchant or {}
Primus.PUIMerchant = PUIMerchant
_G.PUIMerchant = PUIMerchant

local DB    = Primus.DB
local Utils = Primus.Utils
local Time  = Primus.Time
local Items = Primus.Items

-- Register DB Namespace
local merchantDB = DB:RegisterNamespace("PUIMerchant", {
    enabled = true,
    quickBuyout = true,
    showTooltipPrices = true,
    showTooltipSparkline = true,
    flyoutSide = "RIGHT", -- "LEFT" or "RIGHT"
    flyoutOpen = true,
    realms = {},
    priceData = {},
})
PUIMerchant.db = merchantDB

-- Clean Item Name Extractor
function PUIMerchant:CleanItemName(linkOrName)
    if not linkOrName then return nil end
    local s, e, name = string.find(tostring(linkOrName), "%[(.+)%]")
    return name or linkOrName
end

-- Get Day Key (YYYYMMDD integer, e.g., 20261003)
function PUIMerchant:GetDayKey(timestamp)
    timestamp = timestamp or Time:GetServerTimestamp()
    if date then
        local dStr = date("%Y%m%d", timestamp)
        local dNum = tonumber(dStr)
        if dNum and dNum > 0 then return dNum end
    end
    -- Fallback: Day Epoch integer
    return math.floor(timestamp / 86400)
end

-- Get Realm Market Container
function PUIMerchant:GetRealmPriceData(realm)
    realm = realm or GetRealmName() or "Default"
    if not merchantDB.data.realms then
        merchantDB.data.realms = {}
    end
    if not merchantDB.data.realms[realm] then
        merchantDB.data.realms[realm] = {
            priceData = {},
            lastScan = 0,
            totalListings = 0,
        }
    end
    return merchantDB.data.realms[realm]
end

-- =========================================================================
-- STATISTICAL QUANTILE ENGINE (Average, Median +-15%, Low 35%, High 35%)
-- =========================================================================

-- Calculates comprehensive distribution metrics from a sorted price array [p1, p2, ..., pN]
function PUIMerchant:CalculateQuantiles(sortedPrices)
    local n = table.getn(sortedPrices)
    if not n or n == 0 then return nil end

    -- 1. Mean (Average) & Total Sum
    local totalSum = 0
    for i = 1, n do
        totalSum = totalSum + sortedPrices[i]
    end
    local mean = math.floor(totalSum / n)

    -- 2. Median (50th Percentile)
    local median
    if math.mod(n, 2) == 1 then
        median = sortedPrices[math.floor(n / 2) + 1]
    else
        local mid = math.floor(n / 2)
        median = math.floor((sortedPrices[mid] + sortedPrices[mid + 1]) / 2)
    end
    if median <= 0 then median = mean end

    -- 3. Core Market Zone (Median +- 15%)
    local coreMin = math.floor(median * 0.85)
    local coreMax = math.floor(median * 1.15)
    local coreVolume = 0
    local coreSum = 0
    for i = 1, n do
        local p = sortedPrices[i]
        if p >= coreMin and p <= coreMax then
            coreVolume = coreVolume + 1
            coreSum = coreSum + p
        end
    end
    local coreAvg = (coreVolume > 0) and math.floor(coreSum / coreVolume) or median

    -- 4. Low Tier (Cheapest 35% of listings)
    local lowCount = math.floor(n * 0.35)
    if lowCount < 1 then lowCount = 1 end
    if lowCount > n then lowCount = n end

    local lowSum = 0
    for i = 1, lowCount do
        lowSum = lowSum + sortedPrices[i]
    end
    local lowAvg = math.floor(lowSum / lowCount)
    local lowMin = sortedPrices[1]
    local lowMax = sortedPrices[lowCount]

    -- 5. High Tier (Most expensive 35% of listings)
    local highCount = math.floor(n * 0.35)
    if highCount < 1 then highCount = 1 end
    if highCount > n then highCount = n end

    local highStartIndex = n - highCount + 1
    if highStartIndex < 1 then highStartIndex = 1 end

    local highSum = 0
    local actualHighCount = 0
    for i = highStartIndex, n do
        highSum = highSum + sortedPrices[i]
        actualHighCount = actualHighCount + 1
    end
    if actualHighCount < 1 then actualHighCount = 1 end
    local highAvg = math.floor(highSum / actualHighCount)
    local highMin = sortedPrices[highStartIndex]
    local highMax = sortedPrices[n]

    return {
        totalVolume = n,
        mean        = mean,
        median      = median,
        coreMin     = coreMin,
        coreMax     = coreMax,
        coreAvg     = coreAvg,
        coreVolume  = coreVolume,
        lowAvg      = lowAvg,
        lowMin      = lowMin,
        lowMax      = lowMax,
        lowVolume   = lowCount,
        highAvg     = highAvg,
        highMin     = highMin,
        highMax     = highMax,
        highVolume  = actualHighCount,
    }
end

-- Recalculates Rolling 7-Day & 14-Day Metrics across historical snapshots
function PUIMerchant:RecalculateRollingAverages(pData)
    if not pData or not pData.history then return end

    local totalVol7d = 0
    local sumMean7d  = 0
    local medians7d  = {}

    local totalVol14d = 0
    local sumMean14d  = 0

    -- Extract sorted day keys
    local dayKeys = {}
    for dayKey, _ in pairs(pData.history) do
        table.insert(dayKeys, dayKey)
    end
    table.sort(dayKeys)

    local numDays = table.getn(dayKeys)
    if numDays == 0 then return end

    -- 7-Day window: Take up to last 7 recorded days
    local start7 = (numDays > 7) and (numDays - 6) or 1
    for i = start7, numDays do
        local dKey = dayKeys[i]
        local dayStat = pData.history[dKey]
        if dayStat and dayStat.totalVolume and dayStat.totalVolume > 0 then
            totalVol7d = totalVol7d + dayStat.totalVolume
            sumMean7d  = sumMean7d + (dayStat.mean * dayStat.totalVolume)
            table.insert(medians7d, dayStat.median)
        end
    end

    if totalVol7d > 0 then
        pData.runningAvg7d = math.floor(sumMean7d / totalVol7d)
    else
        pData.runningAvg7d = pData.latestMinBuyout or 0
    end

    table.sort(medians7d)
    local medCount = table.getn(medians7d)
    if medCount > 0 then
        pData.runningMedian7d = medians7d[math.floor(medCount / 2) + 1] or medians7d[1]
    else
        pData.runningMedian7d = pData.runningAvg7d
    end

    -- 14-Day window: Take up to last 14 recorded days
    local start14 = (numDays > 14) and (numDays - 13) or 1
    for i = start14, numDays do
        local dKey = dayKeys[i]
        local dayStat = pData.history[dKey]
        if dayStat and dayStat.totalVolume and dayStat.totalVolume > 0 then
            totalVol14d = totalVol14d + dayStat.totalVolume
            sumMean14d  = sumMean14d + (dayStat.mean * dayStat.totalVolume)
        end
    end

    if totalVol14d > 0 then
        pData.runningAvg14d = math.floor(sumMean14d / totalVol14d)
    else
        pData.runningAvg14d = pData.runningAvg7d
    end
end

-- =========================================================================
-- RECORDING & INGESTION
-- =========================================================================

-- Ingests a full list of unit prices collected for an item during a scan
function PUIMerchant:RecordItemScanBatch(cleanName, prices, itemMeta, realm)
    if not cleanName or cleanName == "" or not prices then return end
    local n = table.getn(prices)
    if n == 0 then return end

    table.sort(prices)

    local quantiles = self:CalculateQuantiles(prices)
    if not quantiles then return end

    local realmData = self:GetRealmPriceData(realm)
    local pData = realmData.priceData[cleanName]
    local now = Time:GetServerTimestamp()
    local todayKey = self:GetDayKey(now)

    if not pData then
        pData = {
            name             = cleanName,
            texture          = itemMeta and itemMeta.texture or nil,
            quality          = itemMeta and itemMeta.quality or 1,
            itemClass        = itemMeta and itemMeta.itemClass or "Trade Goods",
            itemLevel        = itemMeta and itemMeta.itemLevel or 1,
            latestMinBuyout  = prices[1] or 0,
            lastSeen         = now,
            history          = {},
        }
        realmData.priceData[cleanName] = pData
    else
        pData.latestMinBuyout = prices[1] or pData.latestMinBuyout or 0
        pData.lastSeen = now
        if itemMeta then
            if itemMeta.texture then pData.texture = itemMeta.texture end
            if itemMeta.quality then pData.quality = itemMeta.quality end
            if itemMeta.itemLevel then pData.itemLevel = itemMeta.itemLevel end
            if itemMeta.itemClass then pData.itemClass = itemMeta.itemClass end
        end
    end

    if not pData.history then pData.history = {} end
    pData.history[todayKey] = quantiles

    self:RecalculateRollingAverages(pData)

    -- Legacy fallback
    if not merchantDB.data.priceData then merchantDB.data.priceData = {} end
    merchantDB.data.priceData[cleanName] = {
        minBuyout   = pData.latestMinBuyout,
        totalBuyout = pData.runningAvg7d or pData.latestMinBuyout,
        count       = quantiles.totalVolume,
        lastSeen    = now,
    }
end

-- Ingests a single observation (e.g. from passive browsing or targeted query)
function PUIMerchant:RecordSingleAuction(itemName, unitPrice, itemMeta, realm)
    if not itemName or not unitPrice or unitPrice <= 0 then return end
    local clean = self:CleanItemName(itemName)
    if not clean or clean == "" then return end

    local realmData = self:GetRealmPriceData(realm)
    local pData = realmData.priceData[clean]
    local now = Time:GetServerTimestamp()
    local todayKey = self:GetDayKey(now)

    if not pData then
        pData = {
            name             = clean,
            texture          = itemMeta and itemMeta.texture or nil,
            quality          = itemMeta and itemMeta.quality or 1,
            itemClass        = itemMeta and itemMeta.itemClass or "Trade Goods",
            itemLevel        = itemMeta and itemMeta.itemLevel or 1,
            latestMinBuyout  = unitPrice,
            lastSeen         = now,
            runningAvg7d     = unitPrice,
            runningMedian7d  = unitPrice,
            history          = {},
        }
        realmData.priceData[clean] = pData
    else
        if not pData.latestMinBuyout or unitPrice < pData.latestMinBuyout or pData.latestMinBuyout == 0 then
            pData.latestMinBuyout = unitPrice
        end
        pData.lastSeen = now
    end

    if not pData.history then pData.history = {} end
    local todayStat = pData.history[todayKey]

    if not todayStat then
        pData.history[todayKey] = {
            totalVolume = 1,
            mean        = unitPrice,
            median      = unitPrice,
            coreMin     = math.floor(unitPrice * 0.85),
            coreMax     = math.floor(unitPrice * 1.15),
            coreAvg     = unitPrice,
            coreVolume  = 1,
            lowAvg      = unitPrice,
            lowMin      = unitPrice,
            lowMax      = unitPrice,
            lowVolume   = 1,
            highAvg     = unitPrice,
            highMin     = unitPrice,
            highMax     = unitPrice,
            highVolume  = 1,
        }
    else
        -- Incremental running blend for single observation
        local oldVol = todayStat.totalVolume or 1
        local newVol = oldVol + 1
        todayStat.totalVolume = newVol
        todayStat.mean = math.floor(((todayStat.mean * oldVol) + unitPrice) / newVol)
        if unitPrice < (todayStat.lowMin or unitPrice) then todayStat.lowMin = unitPrice end
        if unitPrice > (todayStat.highMax or unitPrice) then todayStat.highMax = unitPrice end
        if unitPrice >= todayStat.coreMin and unitPrice <= todayStat.coreMax then
            todayStat.coreVolume = (todayStat.coreVolume or 0) + 1
        end
    end

    self:RecalculateRollingAverages(pData)
end

-- 14-Day History Pruning Engine (Purges entries older than maxDays)
function PUIMerchant:PruneOldHistory(realm, maxDays)
    maxDays = maxDays or 14
    local realmData = self:GetRealmPriceData(realm)
    if not realmData or not realmData.priceData then return 0 end

    local now = Time:GetServerTimestamp()
    local cutoffDayKey = self:GetDayKey(now - (maxDays * 86400))
    local totalPurged = 0

    for itemName, pData in pairs(realmData.priceData) do
        if pData.history then
            for dayKey, _ in pairs(pData.history) do
                if dayKey < cutoffDayKey then
                    pData.history[dayKey] = nil
                    totalPurged = totalPurged + 1
                end
            end
            self:RecalculateRollingAverages(pData)
        end
    end

    return totalPurged
end

-- Comprehensive Item Metric Lookup
function PUIMerchant:GetItemMetrics(itemName, realm)
    if not itemName then return nil end
    local clean = self:CleanItemName(itemName)
    if not clean or clean == "" then return nil end

    local realmData = self:GetRealmPriceData(realm)
    local pData = realmData and realmData.priceData and realmData.priceData[clean]

    if not pData then
        -- Check legacy global
        local legacy = merchantDB.data.priceData and merchantDB.data.priceData[clean]
        if legacy and legacy.minBuyout and legacy.minBuyout > 0 then
            return {
                name            = clean,
                latestMinBuyout = legacy.minBuyout,
                runningAvg7d    = math.floor(legacy.totalBuyout / (legacy.count or 1)),
                runningMedian7d = math.floor(legacy.totalBuyout / (legacy.count or 1)),
                totalVolume     = legacy.count or 1,
                lastSeen        = legacy.lastSeen or 0,
                history         = {},
            }
        end
        return nil
    end

    return pData
end
