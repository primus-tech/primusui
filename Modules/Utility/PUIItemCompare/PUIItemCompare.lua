--[[
    PrimusLib Module: ItemCompare (Side-by-Side Equipment Comparison)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Displays currently equipped items next to hovered item tooltips for
    instant stat comparison across bags, bank, loot, quests, merchant, and chat links,
    seamlessly unifying native Merchant comparison with universal bag/loot/quest comparison.
    
    Includes strict context constraints to prevent comparison tooltips from appearing
    on hotbars, action buttons, spells, buffs, character sheet self-hover, or identical gear.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIItemCompare = Primus.PUIItemCompare or {}
Primus.PUIItemCompare = PUIItemCompare
_G.PUIItemCompare = PUIItemCompare
Primus:RegisterModule("PUIItemCompare", PUIItemCompare, "Utility")

local DB     = Primus.DB
local Media  = Primus.Media
local Events = Primus.Events
local Utils  = Primus.Utils

local compareDB = DB:RegisterNamespace("PUIItemCompare", {
    enabled = true,
})

-- Equipment Slot Mapping for Vanilla 1.12
local SLOT_MAP = {
    ["INVTYPE_HEAD"]           = { 1 },
    ["INVTYPE_NECK"]           = { 2 },
    ["INVTYPE_SHOULDER"]       = { 3 },
    ["INVTYPE_BODY"]           = { 4 },
    ["INVTYPE_CHEST"]          = { 5 },
    ["INVTYPE_ROBE"]           = { 5 },
    ["INVTYPE_WAIST"]          = { 6 },
    ["INVTYPE_LEGS"]           = { 7 },
    ["INVTYPE_FEET"]           = { 8 },
    ["INVTYPE_WRIST"]          = { 9 },
    ["INVTYPE_HAND"]           = { 10 },
    ["INVTYPE_FINGER"]         = { 11, 12 },
    ["INVTYPE_TRINKET"]        = { 13, 14 },
    ["INVTYPE_CLOAK"]          = { 15 },
    ["INVTYPE_WEAPON"]         = { 16, 17 },
    ["INVTYPE_SHIELD"]         = { 17 },
    ["INVTYPE_2HWEAPON"]       = { 16 },
    ["INVTYPE_WEAPONMAINHAND"] = { 16 },
    ["INVTYPE_WEAPONOFFHAND"]  = { 17 },
    ["INVTYPE_HOLDABLE"]       = { 17 },
    ["INVTYPE_RANGED"]         = { 18 },
    ["INVTYPE_THROWN"]         = { 18 },
    ["INVTYPE_RANGEDRIGHT"]    = { 18 },
    ["INVTYPE_RELIC"]          = { 18 },
}

-- Comparison Tooltips
local compareTip1 = CreateFrame("GameTooltip", "Primus_CompareTooltip1", UIParent, "GameTooltipTemplate")
local compareTip2 = CreateFrame("GameTooltip", "Primus_CompareTooltip2", UIParent, "GameTooltipTemplate")

local function StyleTooltip(tip)
    if not tip then return end
    tip:SetBackdrop(Media:Fetch("border", "1Pixel"))
    tip:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    tip:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
end

local function HideComparisonTooltips()
    if compareTip1 and compareTip1:IsShown() then compareTip1:Hide() end
    if compareTip2 and compareTip2:IsShown() then compareTip2:Hide() end
end

-- Synchronize comparison tooltip visibility with parent tooltip
local function SyncVisibility()
    if not GameTooltip:IsShown() and not ItemRefTooltip:IsShown() then
        HideComparisonTooltips()
    end
end
compareTip1:SetScript("OnUpdate", SyncVisibility)
compareTip2:SetScript("OnUpdate", SyncVisibility)

-- Safe helper to get tooltip owner frame in Vanilla 1.12
local function GetTooltipOwner(tip)
    if not tip then return nil end
    if tip._owner then return tip._owner end
    if this and (type(this) == "table" or type(this) == "userdata") then
        return this
    end
    return nil
end

-- Hook Blizzard's native Merchant comparison tooltips for consistent Primus styling
local function SkinBlizzardShoppingTooltips()
    if ShoppingTooltip1 then
        StyleTooltip(ShoppingTooltip1)
        ShoppingTooltip1:SetFrameStrata("TOOLTIP")
    end
    if ShoppingTooltip2 then
        StyleTooltip(ShoppingTooltip2)
        ShoppingTooltip2:SetFrameStrata("TOOLTIP")
    end
end

local function GetItemID(link)
    if not link or type(link) ~= "string" then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    return id and tonumber(id) or nil
end

local isComparing = false

local function ShowComparison(parentTooltip, itemLink)
    if isComparing then return end
    if not parentTooltip or parentTooltip == compareTip1 or parentTooltip == compareTip2 then
        HideComparisonTooltips()
        return
    end

    if not compareDB:Get("enabled", true) or not itemLink then
        HideComparisonTooltips()
        return
    end

    -- =========================================================================
    -- CONSTRAINT 1: Suppress on Action Buttons, Hotbars, Spells & Character Slots
    -- =========================================================================
    local owner = GetTooltipOwner(parentTooltip)
    if owner and (type(owner) == "table" or type(owner) == "userdata") then
        local name = (owner.GetName and owner:GetName()) or ""
        if owner.action
            or (name ~= "" and (
                string.find(name, "ActionButton")
                or string.find(name, "MultiBar")
                or string.find(name, "BonusActionButton")
                or string.find(name, "PetActionButton")
                or string.find(name, "Shapeshift")
                or string.find(name, "PUIHotbar")
                or string.find(name, "PUIButton")
                or string.find(name, "PUI_Hotbar")
                or string.find(name, "MainMenuBar")
                or string.find(name, "SpellButton")
                or string.find(name, "PaperDollItemSlotButton")
                or string.find(name, "Character.*Slot")
            )) then
            HideComparisonTooltips()
            return
        end
    end

    -- =========================================================================
    -- CONSTRAINT 2: Suppress duplicate compare tips during MerchantFrame hover
    -- =========================================================================
    if MerchantFrame and MerchantFrame:IsShown() and parentTooltip == GameTooltip and MerchantFrame.itemHover then
        HideComparisonTooltips()
        return
    end

    -- =========================================================================
    -- CONSTRAINT 3: Valid Equippable Item Check
    -- =========================================================================
    local cleanLink = Utils.ExtractLink(itemLink) or itemLink
    local _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(cleanLink)
    if not itemEquipLoc or not SLOT_MAP[itemEquipLoc] then
        HideComparisonTooltips()
        return
    end

    local slots = SLOT_MAP[itemEquipLoc]
    local slot1 = slots[1]
    local slot2 = slots[2]

    local link1 = slot1 and GetInventoryItemLink("player", slot1)
    local link2 = slot2 and GetInventoryItemLink("player", slot2)
    local id1 = link1 and GetItemID(link1)
    local id2 = link2 and GetItemID(link2)
    local hoverID = GetItemID(cleanLink)

    local hasEquipped1 = (link1 ~= nil)
    local hasEquipped2 = (link2 ~= nil)

    -- =========================================================================
    -- CONSTRAINT 4: Self-Comparison & Smart Dual-Slot Deduction
    -- =========================================================================
    if not hasEquipped1 and not hasEquipped2 then
        HideComparisonTooltips()
        return
    end

    -- Single-slot item check: if hovered item is identical to equipped, do not compare
    if not slot2 then
        if hasEquipped1 and hoverID and id1 and (hoverID == id1) then
            HideComparisonTooltips()
            return
        end
    else
        -- Dual-slot item (Rings, Trinkets, Weapons):
        -- If both slots match the hovered item, nothing to compare
        if hoverID and id1 and id2 and (hoverID == id1) and (hoverID == id2) then
            HideComparisonTooltips()
            return
        end

        -- If slot 1 matches the hovered item, compare only against slot 2
        if hoverID and id1 and (hoverID == id1) then
            slot1 = slot2
            link1 = link2
            id1 = id2
            hasEquipped1 = hasEquipped2
            slot2 = nil
            hasEquipped2 = false
        -- If slot 2 matches the hovered item, compare only against slot 1
        elseif hoverID and id2 and (hoverID == id2) then
            slot2 = nil
            hasEquipped2 = false
        end
    end

    if not hasEquipped1 and not hasEquipped2 then
        HideComparisonTooltips()
        return
    end

    isComparing = true

    -- Determine optimal screen anchoring side (Left vs Right of parent tooltip)
    local parentLeft = (parentTooltip.GetLeft and parentTooltip:GetLeft()) or 0
    local neededWidth = hasEquipped2 and 440 or 220
    local anchorSide = "LEFT"
    if parentLeft < neededWidth then
        anchorSide = "RIGHT"
    end

    -- Display Primary Equipped Item Tooltip
    if hasEquipped1 then
        compareTip1:SetOwner(parentTooltip, "ANCHOR_NONE")
        compareTip1:ClearAllPoints()
        if anchorSide == "LEFT" then
            compareTip1:SetPoint("TOPRIGHT", parentTooltip, "TOPLEFT", -4, 0)
        else
            compareTip1:SetPoint("TOPLEFT", parentTooltip, "TOPRIGHT", 4, 0)
        end
        compareTip1:SetInventoryItem("player", slot1)
        StyleTooltip(compareTip1)
        compareTip1:Show()
    else
        compareTip1:Hide()
    end

    -- Display Secondary Equipped Item Tooltip (e.g. 2nd ring / 2nd trinket / offhand)
    if hasEquipped2 and slot2 then
        local anchorTarget = hasEquipped1 and compareTip1 or parentTooltip
        compareTip2:SetOwner(anchorTarget, "ANCHOR_NONE")
        compareTip2:ClearAllPoints()
        if anchorSide == "LEFT" then
            compareTip2:SetPoint("TOPRIGHT", anchorTarget, "TOPLEFT", -4, 0)
        else
            compareTip2:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", 4, 0)
        end
        compareTip2:SetInventoryItem("player", slot2)
        StyleTooltip(compareTip2)
        compareTip2:Show()
    else
        compareTip2:Hide()
    end

    isComparing = false
end

-- Hook standard 1.12 Tooltip Item Setters & Non-Item Suppressors
local function HookTooltipMethods(tip)
    if not tip then return end

    -- Track owner safely on SetOwner
    if tip.SetOwner then
        local origSetOwner = tip.SetOwner
        tip.SetOwner = function(self, owner, anchor, a1, a2, a3)
            self._owner = owner
            return origSetOwner(self, owner, anchor, a1, a2, a3)
        end
    end

    -- Item setters that trigger comparison
    Events:Hook(tip, "SetBagItem", function(self, bag, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetContainerItemLink(bag, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetInventoryItem", function(self, unit, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local numSlot = tonumber(slot)
        if (unit ~= "player") or (numSlot and numSlot > 19) then
            local link = (numSlot and numSlot >= 1) and GetInventoryItemLink(unit, slot) or nil
            if link then
                ShowComparison(self, link)
            else
                HideComparisonTooltips()
            end
        else
            HideComparisonTooltips()
        end
    end)

    Events:Hook(tip, "SetQuestItem", function(self, qtype, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetQuestItemLink(qtype, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetQuestLogItem", function(self, qtype, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetQuestLogItemLink(qtype, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetLootItem", function(self, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetLootSlotLink(slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetLootRollItem", function(self, slot)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetLootRollItemLink(slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetInboxItem", function(self, index, attachIndex)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetInboxItemLink and GetInboxItemLink(index, attachIndex)
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    Events:Hook(tip, "SetSendMailItem", function(self, index)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetSendMailItemLink and GetSendMailItemLink(index)
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    Events:Hook(tip, "SetTradePlayerItem", function(self, index)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetTradePlayerItemLink and GetTradePlayerItemLink(index)
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    Events:Hook(tip, "SetTradeTargetItem", function(self, index)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetTradeTargetItemLink and GetTradeTargetItemLink(index)
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    Events:Hook(tip, "SetAuctionItem", function(self, atype, index)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetAuctionItemLink and GetAuctionItemLink(atype, index)
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    Events:Hook(tip, "SetAuctionSellItem", function(self)
        if self == compareTip1 or self == compareTip2 then return end
        local link = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
        if link then ShowComparison(self, link) else HideComparisonTooltips() end
    end)

    -- TradeSkill Crafted Items (TradeSkillFrame)
    Events:Hook(tip, "SetTradeSkillItem", function(self, skillIndex, reagentIndex)
        if self == compareTip1 or self == compareTip2 then return end
        if reagentIndex then
            HideComparisonTooltips()
            return
        end
        local link = GetTradeSkillItemLink and GetTradeSkillItemLink(skillIndex)
        local skillName = nil
        if not link and GetTradeSkillInfo then
            skillName = GetTradeSkillInfo(skillIndex)
            if skillName then
                local _, l = GetItemInfo(skillName)
                link = l
            end
        end
        if not link then
            local textLeft1 = _G[self:GetName() .. "TextLeft1"]
            if textLeft1 and textLeft1:GetText() then
                local tName = textLeft1:GetText()
                local _, l = GetItemInfo(tName)
                link = l or tName
            end
        end
        local baseDB = Primus.PUIBasePriceDB or _G.PUIBasePriceDB
        if link and not string.find(tostring(link), "item:") and baseDB and baseDB.GetItemID then
            local id = baseDB:GetItemID(link)
            if id then link = "item:" .. id .. ":0:0:0" end
        end
        if link then
            ShowComparison(self, link)
        else
            HideComparisonTooltips()
        end
    end)

    -- Craft Items (CraftFrame)
    Events:Hook(tip, "SetCraftItem", function(self, skillIndex, reagentIndex)
        if self == compareTip1 or self == compareTip2 then return end
        if reagentIndex then
            HideComparisonTooltips()
            return
        end
        local link = GetCraftItemLink and GetCraftItemLink(skillIndex)
        local craftName = nil
        if not link and GetCraftInfo then
            craftName = GetCraftInfo(skillIndex)
            if craftName then
                local _, l = GetItemInfo(craftName)
                link = l
            end
        end
        if not link then
            local textLeft1 = _G[self:GetName() .. "TextLeft1"]
            if textLeft1 and textLeft1:GetText() then
                local tName = textLeft1:GetText()
                local _, l = GetItemInfo(tName)
                link = l or tName
            end
        end
        local baseDB = Primus.PUIBasePriceDB or _G.PUIBasePriceDB
        if link and not string.find(tostring(link), "item:") and baseDB and baseDB.GetItemID then
            local id = baseDB:GetItemID(link)
            if id then link = "item:" .. id .. ":0:0:0" end
        end
        if link then
            ShowComparison(self, link)
        else
            HideComparisonTooltips()
        end
    end)

    Events:Hook(tip, "SetHyperlink", function(self, link)
        if self == compareTip1 or self == compareTip2 then return end
        local cleanLink = Utils.ExtractLink(link) or link
        ShowComparison(self, cleanLink)
    end)

    -- Non-item setters that MUST suppress/hide comparison tooltips
    Events:Hook(tip, "SetAction", function(self, slot)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetPetAction", function(self, slot)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetShapeshift", function(self, slot)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetSpell", function(self, spellId, bookType)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetUnit", function(self, unit)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetPlayerBuff", function(self, buffIndex)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetUnitBuff", function(self, unit, buffIndex)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetUnitDebuff", function(self, unit, buffIndex)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "SetTrackingSpell", function(self)
        HideComparisonTooltips()
    end)

    Events:Hook(tip, "ClearLines", function(self)
        HideComparisonTooltips()
    end)

    Events:HookScript(tip, "OnHide", function(self)
        if self == GameTooltip or self == ItemRefTooltip then
            HideComparisonTooltips()
        end
    end)
end

function PUIItemCompare:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIItemCompare", {
        name = "PUIItemCompare",
        category = "Utility",
        label = "Item Comparison",
        icon = "Interface\\Icons\\INV_Sword_04",
        desc = "Side-by-side equipment comparison tooltips across merchant, bags, bank, loot, and chat.",
    })
end

function PUIItemCompare:OnInitialize()
    self:RegisterOptionsFlare()
    StyleTooltip(compareTip1)
    StyleTooltip(compareTip2)
    SkinBlizzardShoppingTooltips()
    HookTooltipMethods(GameTooltip)
    HookTooltipMethods(ItemRefTooltip)

    -- Re-skin ShoppingTooltips whenever MerchantFrame opens
    Events:Register("MERCHANT_SHOW", "PUIItemCompare", function()
        SkinBlizzardShoppingTooltips()
    end)
end
