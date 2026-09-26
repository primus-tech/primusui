--[[
    PrimusUI Module: PUISellValue (Hybrid Item Pricing & Vendor Sell Value Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Features:
    1. Hybrid Resolution Hierarchy:
       - Tier 1: Built-in Static DB (PUISellValue.StaticDB) seeded from pfUI/pfQuest item data.
       - Tier 2: Autonomous Live Realm-Learning Cache (PrimusGlobalDB.PUISellValue.realms[GetRealmName()].prices[itemID]).
    2. Universal Tooltip Injection:
       - Hooks SetBagItem, SetInventoryItem, SetHyperlink, SetAction, SetCraftItem,
         SetTradeSkillItem, SetLootItem, SetLootRollItem, SetQuestItem, SetQuestLogItem,
         SetInboxItem, SetSendMailItem, SetAuctionItem, SetAuctionSellItem, SetTradePlayerItem,
         SetTradeTargetItem, and ItemRefTooltip.
       - Formats single prices: "Sell: 1g 25s 40c"
       - Formats stack prices (>1): "Sell (x5): 7g 27s 00c (1g 25s 40c ea)"
       - Strictly suppresses injection when MerchantFrame is open to prevent duplicate rows.
    3. Autonomous Live Auto-Learning:
       - Silently captures native vendor prices during MERCHANT_SHOW, MERCHANT_UPDATE,
         and interactive container scans via a dedicated hidden tooltip engine.
    4. Options Flare & Console Router:
       - Master toggles in GUI and '/pui sell' diagnostic CLI.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUISellValue = Primus.PUISellValue or {}
Primus.PUISellValue = PUISellValue
_G.PUISellValue = PUISellValue
Primus:RegisterModule("PUISellValue", PUISellValue, "Player")

local DB      = Primus.DB
local Events  = Primus.Events
local Utils   = Primus.Utils
local Media   = Primus.Media
local Debug   = Primus.Debug
local Console = Primus.Console

local sellDB = DB:RegisterNamespace("PUISellValue", {
    enabled = true,
    showSinglePrice = true,
    showStackPrice = true,
    showNoSellValue = false,
    realms = {},
})

-- Ensure global storage alias for external scripts / macros
if _G.PrimusGlobalDB then
    _G.PrimusGlobalDB.PUISellValue = sellDB.data
end

-- Dedicated Hidden Tooltip for Definitive 1.12 Vendor Money Capture
local scanTip = CreateFrame("GameTooltip", "Primus_SellValueScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

local lastScannedMoney = 0
scanTip:SetScript("OnTooltipAddMoney", function()
    lastScannedMoney = arg1 or 0
end)
scanTip:SetScript("OnTooltipCleared", function()
    lastScannedMoney = 0
end)

-- =========================================================================
-- REALM CACHE MANAGEMENT
-- =========================================================================

function PUISellValue:GetRealmData()
    local realm = GetRealmName() or "Default"
    if not sellDB.data.realms then
        sellDB.data.realms = {}
    end
    if not sellDB.data.realms[realm] then
        sellDB.data.realms[realm] = {
            prices = {},
            learnedCount = 0,
        }
    end
    -- Keep global alias synchronized
    if _G.PrimusGlobalDB and not _G.PrimusGlobalDB.PUISellValue then
        _G.PrimusGlobalDB.PUISellValue = sellDB.data
    end
    return sellDB.data.realms[realm]
end

function PUISellValue:LearnPrice(itemID, price)
    if not itemID or not price or price < 0 then return false end
    itemID = tonumber(itemID)
    price = tonumber(price)
    if not itemID or not price then return false end

    local rData = self:GetRealmData()
    if not rData.prices then rData.prices = {} end

    if rData.prices[itemID] ~= price then
        local isNew = (rData.prices[itemID] == nil)
        rData.prices[itemID] = price
        if isNew then
            rData.learnedCount = (rData.learnedCount or 0) + 1
        end
        return true
    end
    return false
end

-- =========================================================================
-- HYBRID PRICE RESOLUTION ENGINE
-- =========================================================================

function PUISellValue:ExtractItemID(itemLinkOrString)
    if not itemLinkOrString then return nil end
    if type(itemLinkOrString) == "number" then
        return itemLinkOrString
    end
    local _, _, idStr = string.find(itemLinkOrString, "item:(%d+)")
    if idStr then
        return tonumber(idStr)
    end
    return tonumber(itemLinkOrString)
end

function PUISellValue:GetSellPrice(item)
    if not item then return nil end
    local itemID = self:ExtractItemID(item)
    if not itemID then return nil end

    -- 1. Tier 2: Live Realm Auto-Learning Cache
    local rData = self:GetRealmData()
    if rData and rData.prices and rData.prices[itemID] ~= nil then
        return rData.prices[itemID], "REALM_CACHE"
    end

    -- 2. Tier 1: Built-in Static DB
    if PUISellValue.StaticDB and PUISellValue.StaticDB[itemID] ~= nil then
        return PUISellValue.StaticDB[itemID], "STATIC_DB"
    end

    -- 3. Query PUIQuest Canonical Database
    if Primus.PUIQuest and Primus.PUIQuest.Database then
        local puiPrice = Primus.PUIQuest.Database:GetItemVendorPrice(itemID)
        if puiPrice and puiPrice > 0 then
            return puiPrice, "PUIQUEST_DB"
        end
    end

    return nil, nil
end

-- =========================================================================
-- AUTONOMOUS LIVE MERCHANT SCANNER
-- =========================================================================

function PUISellValue:ScanBagsAtMerchant()
    if not MerchantFrame or not MerchantFrame:IsShown() then return 0 end

    local newLearned = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        if numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemID = self:ExtractItemID(link)
                    if itemID then
                        local _, count = GetContainerItemInfo(bag, slot)
                        count = (count and count > 0) and count or 1

                        lastScannedMoney = 0
                        scanTip:ClearLines()
                        scanTip:SetBagItem(bag, slot)

                        if lastScannedMoney > 0 then
                            local unitPrice = math.floor(lastScannedMoney / count)
                            if unitPrice > 0 then
                                if self:LearnPrice(itemID, unitPrice) then
                                    newLearned = newLearned + 1
                                end
                            end
                        elseif lastScannedMoney == 0 then
                            -- Item has zero vendor sell price (unsellable quest item / soulbound currency)
                            -- Record as 0 to cache definitive zero sell value
                            if self:LearnPrice(itemID, 0) then
                                newLearned = newLearned + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return newLearned
end

-- =========================================================================
-- UNIVERSAL TOOLTIP INJECTION ENGINE
-- =========================================================================

local function FormatPriceRow(singlePrice, count)
    count = (count and count > 0) and count or 1

    if singlePrice == 0 then
        return "|cffffd100Sell:|r", "|cff888888No sell value|r"
    end

    if count > 1 and sellDB:Get("showStackPrice", true) then
        local totalPrice = singlePrice * count
        local totalStr = Utils.FormatMoney(totalPrice)
        local eachStr = Utils.FormatMoney(singlePrice)
        local leftText = string.format("|cffffd100Sell (x%d):|r", count)
        local rightText = string.format("%s (%s ea)", totalStr, eachStr)
        return leftText, rightText
    else
        local priceStr = Utils.FormatMoney(singlePrice)
        return "|cffffd100Sell:|r", priceStr
    end
end

function PUISellValue:InjectTooltipPrice(tooltip, itemID, count)
    if not tooltip or not sellDB:Get("enabled", true) then return end
    if tooltip._primusSellValueInjected then return end

    -- Strictly suppress when MerchantFrame is open (Blizzard native row renders)
    if MerchantFrame and MerchantFrame:IsShown() then return end

    if not itemID then return end
    itemID = tonumber(itemID)
    if not itemID then return end

    local price, source = self:GetSellPrice(itemID)
    if price == nil then return end

    if price == 0 and not sellDB:Get("showNoSellValue", false) then
        return
    end

    local leftText, rightText = FormatPriceRow(price, count)
    tooltip:AddDoubleLine(leftText, rightText)
    tooltip._primusSellValueInjected = true
    tooltip:Show()
end

local function ClearTooltipFlag(tooltip)
    if tooltip then
        tooltip._primusSellValueInjected = nil
    end
end

-- Extract itemID and item count from various Blizzard frame contexts
local function HookTooltip(tooltip)
    if not tooltip or tooltip._primusSellHooked then return end
    tooltip._primusSellHooked = true

    -- 1. Bag Items
    local origSetBagItem = tooltip.SetBagItem
    tooltip.SetBagItem = function(self, bag, slot)
        ClearTooltipFlag(self)
        local r1, r2, r3, r4 = origSetBagItem(self, bag, slot)
        local link = GetContainerItemLink(bag, slot)
        if link then
            local itemID = PUISellValue:ExtractItemID(link)
            local _, count = GetContainerItemInfo(bag, slot)
            PUISellValue:InjectTooltipPrice(self, itemID, count)
        end
        return r1, r2, r3, r4
    end

    -- 2. Inventory Items
    local origSetInventoryItem = tooltip.SetInventoryItem
    tooltip.SetInventoryItem = function(self, unit, slot)
        ClearTooltipFlag(self)
        local r1, r2, r3, r4 = origSetInventoryItem(self, unit, slot)
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local itemID = PUISellValue:ExtractItemID(link)
            local count = GetInventoryItemCount(unit, slot) or 1
            PUISellValue:InjectTooltipPrice(self, itemID, count)
        end
        return r1, r2, r3, r4
    end

    -- 3. Hyperlinks
    local origSetHyperlink = tooltip.SetHyperlink
    tooltip.SetHyperlink = function(self, link)
        ClearTooltipFlag(self)
        local r1, r2, r3, r4 = origSetHyperlink(self, link)
        if link then
            local cleanLink = Utils.ExtractLink(link) or link
            local itemID = PUISellValue:ExtractItemID(cleanLink)
            PUISellValue:InjectTooltipPrice(self, itemID, 1)
        end
        return r1, r2, r3, r4
    end

    -- 4. Action Bar Items
    if tooltip.SetAction then
        local origSetAction = tooltip.SetAction
        tooltip.SetAction = function(self, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetAction(self, slot)
            local count = GetActionCount(slot) or 1
            local textLeft1 = _G[self:GetName() .. "TextLeft1"]
            if textLeft1 and textLeft1:GetText() then
                local name = textLeft1:GetText()
                -- Check if item exists with this name via GetItemInfo
                local _, link = GetItemInfo(name)
                if link then
                    local itemID = PUISellValue:ExtractItemID(link)
                    PUISellValue:InjectTooltipPrice(self, itemID, count)
                end
            end
            return r1, r2, r3, r4
        end
    end

    -- 5. Crafting Reagents
    if tooltip.SetCraftItem then
        local origSetCraftItem = tooltip.SetCraftItem
        tooltip.SetCraftItem = function(self, skillIndex, reagentIndex)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetCraftItem(self, skillIndex, reagentIndex)
            local link = GetCraftReagentItemLink(skillIndex, reagentIndex)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetCraftReagentInfo(skillIndex, reagentIndex)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 6. TradeSkill Items & Reagents
    if tooltip.SetTradeSkillItem then
        local origSetTradeSkillItem = tooltip.SetTradeSkillItem
        tooltip.SetTradeSkillItem = function(self, skillIndex, reagentIndex)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetTradeSkillItem(self, skillIndex, reagentIndex)
            if reagentIndex then
                local link = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
                if link then
                    local itemID = PUISellValue:ExtractItemID(link)
                    local _, _, count = GetTradeSkillReagentInfo(skillIndex, reagentIndex)
                    PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
                end
            else
                local link = GetTradeSkillItemLink(skillIndex)
                if link then
                    local itemID = PUISellValue:ExtractItemID(link)
                    PUISellValue:InjectTooltipPrice(self, itemID, 1)
                end
            end
            return r1, r2, r3, r4
        end
    end

    -- 7. Loot Slots
    if tooltip.SetLootItem then
        local origSetLootItem = tooltip.SetLootItem
        tooltip.SetLootItem = function(self, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetLootItem(self, slot)
            local link = GetLootSlotLink(slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetLootSlotInfo(slot)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 8. Loot Roll Items
    if tooltip.SetLootRollItem then
        local origSetLootRollItem = tooltip.SetLootRollItem
        tooltip.SetLootRollItem = function(self, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetLootRollItem(self, slot)
            local link = GetLootRollItemLink(slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                PUISellValue:InjectTooltipPrice(self, itemID, 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 9. Quest Rewards & Choices
    if tooltip.SetQuestItem then
        local origSetQuestItem = tooltip.SetQuestItem
        tooltip.SetQuestItem = function(self, qtype, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetQuestItem(self, qtype, slot)
            local link = GetQuestItemLink(qtype, slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetQuestItemInfo(qtype, slot)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 10. Quest Log Rewards
    if tooltip.SetQuestLogItem then
        local origSetQuestLogItem = tooltip.SetQuestLogItem
        tooltip.SetQuestLogItem = function(self, qtype, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetQuestLogItem(self, qtype, slot)
            local link = GetQuestLogItemLink(qtype, slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetQuestLogItemInfo(qtype, slot)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 11. Mail Inbox & Send Items
    if tooltip.SetInboxItem then
        local origSetInboxItem = tooltip.SetInboxItem
        tooltip.SetInboxItem = function(self, index, attachIndex)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetInboxItem(self, index, attachIndex)
            if GetInboxItemLink then
                local link = GetInboxItemLink(index, attachIndex or 1)
                if link then
                    local itemID = PUISellValue:ExtractItemID(link)
                    local _, _, _, count = GetInboxItem(index, attachIndex or 1)
                    PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
                end
            end
            return r1, r2, r3, r4
        end
    end

    if tooltip.SetSendMailItem then
        local origSetSendMailItem = tooltip.SetSendMailItem
        tooltip.SetSendMailItem = function(self, index)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetSendMailItem(self, index)
            if GetSendMailItemLink then
                local link = GetSendMailItemLink(index)
                if link then
                    local itemID = PUISellValue:ExtractItemID(link)
                    local _, _, _, count = GetSendMailItem(index)
                    PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
                end
            end
            return r1, r2, r3, r4
        end
    end

    -- 12. Auction House Items
    if tooltip.SetAuctionItem then
        local origSetAuctionItem = tooltip.SetAuctionItem
        tooltip.SetAuctionItem = function(self, atype, index)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetAuctionItem(self, atype, index)
            local link = GetAuctionItemLink(atype, index)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetAuctionItemInfo(atype, index)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- 13. Trade Window
    if tooltip.SetTradePlayerItem then
        local origSetTradePlayerItem = tooltip.SetTradePlayerItem
        tooltip.SetTradePlayerItem = function(self, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetTradePlayerItem(self, slot)
            local link = GetTradePlayerItemLink(slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetTradePlayerItemInfo(slot)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    if tooltip.SetTradeTargetItem then
        local origSetTradeTargetItem = tooltip.SetTradeTargetItem
        tooltip.SetTradeTargetItem = function(self, slot)
            ClearTooltipFlag(self)
            local r1, r2, r3, r4 = origSetTradeTargetItem(self, slot)
            local link = GetTradeTargetItemLink(slot)
            if link then
                local itemID = PUISellValue:ExtractItemID(link)
                local _, _, count = GetTradeTargetItemInfo(slot)
                PUISellValue:InjectTooltipPrice(self, itemID, count or 1)
            end
            return r1, r2, r3, r4
        end
    end

    -- Clear state on hide or tooltip clear
    local origOnHide = tooltip:GetScript("OnHide")
    tooltip:SetScript("OnHide", function()
        ClearTooltipFlag(this)
        if origOnHide then origOnHide() end
    end)

    local origOnTooltipCleared = tooltip:GetScript("OnTooltipCleared")
    tooltip:SetScript("OnTooltipCleared", function()
        ClearTooltipFlag(this)
        if origOnTooltipCleared then origOnTooltipCleared() end
    end)
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUISellValue:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUISellValue", "Player", {
        title = "PUISellValue: Vendor Pricing Engine",
        description = "Hybrid vendor sell price resolution engine with universal tooltip injection and autonomous realm learning.",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        fields = {
            {
                key = "enabled",
                label = "Enable PUISellValue Tooltip Price Injection",
                type = "checkbox",
                default = true,
                get = function() return sellDB:Get("enabled", true) end,
                set = function(val)
                    sellDB:Set("enabled", val)
                    if val then PUISellValue:OnEnable() else PUISellValue:OnDisable() end
                end,
            },
            {
                key = "showSinglePrice",
                label = "Display Single Item Unit Sell Value",
                type = "checkbox",
                default = true,
                get = function() return sellDB:Get("showSinglePrice", true) end,
                set = function(val) sellDB:Set("showSinglePrice", val) end,
            },
            {
                key = "showStackPrice",
                label = "Display Total Stack Sell Value For Multiples",
                type = "checkbox",
                default = true,
                get = function() return sellDB:Get("showStackPrice", true) end,
                set = function(val) sellDB:Set("showStackPrice", val) end,
            },
            {
                key = "showNoSellValue",
                label = "Show 'No Sell Value' Notice on Unsellable Items",
                type = "checkbox",
                default = false,
                get = function() return sellDB:Get("showNoSellValue", false) end,
                set = function(val) sellDB:Set("showNoSellValue", val) end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUISellValue:OnInitialize()
    self:RegisterOptionsFlare()

    -- Synchronize global alias
    if _G.PrimusGlobalDB then
        _G.PrimusGlobalDB.PUISellValue = sellDB.data
    end

    -- CLI Router Integration
    if Console and Console.RegisterSubCommand then
        Console:RegisterSubCommand("sell", function(args)
            PUISellValue:HandleSlashCommand(args)
        end, "Vendor sell price diagnostics & realm cache status (/pui sell)")
    end

    -- Hook Tooltips
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)
end

function PUISellValue:OnEnable()
    -- Merchant Interaction Auto-Learning
    Events:Register("MERCHANT_SHOW", "PUISellValue", function()
        local count = PUISellValue:ScanBagsAtMerchant()
        if count > 0 then
            Debug:Info("PUISellValue", string.format("Learned %d new vendor prices from inventory.", count))
        end
    end)

    Events:Register("MERCHANT_UPDATE", "PUISellValue", function()
        PUISellValue:ScanBagsAtMerchant()
    end)
end

function PUISellValue:OnDisable()
    Events:UnregisterOwner("PUISellValue")
end

-- =========================================================================
-- CLI DIAGNOSTICS HANDLER
-- =========================================================================

function PUISellValue:HandleSlashCommand(args)
    local rData = self:GetRealmData()
    local realm = GetRealmName() or "Default"
    local learned = rData.learnedCount or Utils.Count(rData.prices)
    local staticCount = Utils.Count(PUISellValue.StaticDB or {})

    if not args or args == "" or args == "status" then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("=== PrimusUI: PUISellValue Engine Status ===", "69ccf0"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Active Realm: |cffffd100%s|r", realm))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Learned Realm Items: |cff00ff00%d|r", learned))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Tier 1 Static DB Items: |cff00ff00%d|r", staticCount))
        DEFAULT_CHAT_FRAME:AddMessage("• Subcommands: |cffffffff/pui sell scan|r (scan bags), |cffffffff/pui sell price <itemID/link>|r, |cffffffff/pui sell clear|r")
        return
    end

    local tokens = Utils.Split(args, " ")
    local cmd = string.lower(tokens[1] or "")

    if cmd == "scan" then
        if not MerchantFrame or not MerchantFrame:IsShown() then
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUISellValue]: You must be at a vendor window to scan and learn item prices.", "ffbb33"))
            return
        end
        local newCount = self:ScanBagsAtMerchant()
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUISellValue]: Scanned inventory at merchant. Learned %d new item prices.", newCount), "69ccf0"))
    elseif cmd == "price" then
        local target = tokens[2]
        if not target then
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUISellValue]: Usage: /pui sell price <itemID or itemLink>", "ffbb33"))
            return
        end
        local itemID = self:ExtractItemID(target)
        if not itemID then
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUISellValue]: Invalid item ID or link specified.", "ff4444"))
            return
        end
        local price, source = self:GetSellPrice(itemID)
        if price then
            local srcText = (source == "REALM_CACHE") and "Learned Realm Cache" or "Static Built-In DB"
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUISellValue]: Item %d Sell Price: %s (Source: %s)", itemID, Utils.FormatMoney(price), srcText), "69ccf0"))
        else
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUISellValue]: No sell price known for item %d.", itemID), "ffbb33"))
        end
    elseif cmd == "clear" then
        rData.prices = {}
        rData.learnedCount = 0
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUISellValue]: Cleared learned price cache for realm '%s'.", realm), "ffbb33"))
    else
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUISellValue]: Unknown command. Use '/pui sell' for status.", "ff4444"))
    end
end
