--[[
    PrimusLib Module: ItemCompare (Side-by-Side Equipment Comparison)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Displays currently equipped items next to hovered item tooltips for
    instant stat comparison across bags, bank, loot, quests, merchant, and chat links,
    while cleanly suppressing redundant Blizzard default comparison tooltips.
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
    if compareTip1 then compareTip1:Hide() end
    if compareTip2 then compareTip2:Hide() end
end

-- Suppress Blizzard's unstyled duplicate comparison tooltips on MerchantFrame & PaperDoll
local function SuppressBlizzardShoppingTooltips()
    if ShoppingTooltip1 then
        ShoppingTooltip1:Hide()
        ShoppingTooltip1:SetScript("OnShow", function()
            if compareDB:Get("enabled", true) then
                this:Hide()
            end
        end)
    end
    if ShoppingTooltip2 then
        ShoppingTooltip2:Hide()
        ShoppingTooltip2:SetScript("OnShow", function()
            if compareDB:Get("enabled", true) then
                this:Hide()
            end
        end)
    end
end

local function ShowComparison(parentTooltip, itemLink)
    if not compareDB:Get("enabled", true) or not itemLink or not parentTooltip then
        HideComparisonTooltips()
        return
    end

    local cleanLink = Utils.ExtractLink(itemLink) or itemLink
    local _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(cleanLink)
    if not itemEquipLoc or not SLOT_MAP[itemEquipLoc] then
        HideComparisonTooltips()
        return
    end

    local slots = SLOT_MAP[itemEquipLoc]
    local slot1 = slots[1]
    local slot2 = slots[2]

    local hasEquipped1 = slot1 and GetInventoryItemTexture("player", slot1)
    local hasEquipped2 = slot2 and GetInventoryItemTexture("player", slot2)

    if not hasEquipped1 and not hasEquipped2 then
        HideComparisonTooltips()
        return
    end

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
    if hasEquipped2 then
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
end

-- Hook standard 1.12 Tooltip Item Setters
local function HookTooltipMethods(tip)
    if not tip then return end

    Events:Hook(tip, "SetBagItem", function(self, bag, slot)
        local link = GetContainerItemLink(bag, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetInventoryItem", function(self, unit, slot)
        local numSlot = tonumber(slot)
        if (unit ~= "player") or (numSlot and numSlot > 19 and numSlot <= 23) then
            local link = (numSlot and numSlot >= 1 and numSlot <= 23) and GetInventoryItemLink(unit, slot) or nil
            if link then
                ShowComparison(self, link)
            else
                HideComparisonTooltips()
            end
        else
            HideComparisonTooltips()
        end
    end)

    Events:Hook(tip, "SetMerchantItem", function(self, slot)
        local link = GetMerchantItemLink(slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetQuestItem", function(self, qtype, slot)
        local link = GetQuestItemLink(qtype, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetQuestLogItem", function(self, qtype, slot)
        local link = GetQuestLogItemLink(qtype, slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetLootItem", function(self, slot)
        local link = GetLootSlotLink(slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetLootRollItem", function(self, slot)
        local link = GetLootRollItemLink(slot)
        ShowComparison(self, link)
    end)

    Events:Hook(tip, "SetHyperlink", function(self, link)
        local cleanLink = Utils.ExtractLink(link) or link
        ShowComparison(self, cleanLink)
    end)

    Events:HookScript(tip, "OnHide", function()
        HideComparisonTooltips()
    end)
end

function PUIItemCompare:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIItemCompare", {
        name = "PUIItemCompare",
        category = "Utility",
        label = "Item Comparison",
        icon = "Interface\\Icons\\INV_Sword_04",
        desc = "Side-by-side equipment comparison tooltips with stat delta diffs.",
    })
end

function PUIItemCompare:OnInitialize()
    self:RegisterOptionsFlare()
    StyleTooltip(compareTip1)
    StyleTooltip(compareTip2)
    SuppressBlizzardShoppingTooltips()
    HookTooltipMethods(GameTooltip)
    HookTooltipMethods(ItemRefTooltip)
end
