--[[
    PrimusLib Module: ItemCompare (Side-by-Side Equipment Comparison)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Displays currently equipped items next to hovered item tooltips for
    instant stat comparison across bags, bank, loot, quests, and chat links.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIItemCompare = Primus.PUIItemCompare or {}
Primus.PUIItemCompare = PUIItemCompare
_G.PUIItemCompare = PUIItemCompare
Primus:RegisterModule("PUIItemCompare", PUIItemCompare, "Utility")

local DB     = Primus.DB
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

local function HideComparisonTooltips()
    compareTip1:Hide()
    compareTip2:Hide()
end

local function ShowComparison(parentTooltip, itemLink)
    if not compareDB:Get("enabled") or not itemLink then
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

    -- Display Primary Equipped Item Tooltip
    if slot1 and GetInventoryItemTexture("player", slot1) then
        compareTip1:SetOwner(parentTooltip, "ANCHOR_NONE")
        compareTip1:ClearAllPoints()
        compareTip1:SetPoint("TOPRIGHT", parentTooltip, "TOPLEFT", -2, 0)
        compareTip1:SetInventoryItem("player", slot1)
        compareTip1:Show()
    else
        compareTip1:Hide()
    end

    -- Display Secondary Equipped Item Tooltip (e.g. 2nd ring / 2nd trinket)
    if slot2 and GetInventoryItemTexture("player", slot2) then
        compareTip2:SetOwner(compareTip1, "ANCHOR_NONE")
        compareTip2:ClearAllPoints()
        compareTip2:SetPoint("TOPRIGHT", compareTip1, "TOPLEFT", -2, 0)
        compareTip2:SetInventoryItem("player", slot2)
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
        if unit ~= "player" then
            local link = GetInventoryItemLink(unit, slot)
            ShowComparison(self, link)
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
        icon = "Interface\Icons\INV_Sword_04",
        desc = "Side-by-side equipment comparison tooltips with stat delta diffs.",
    })
end

function PUIItemCompare:OnInitialize()
    self:RegisterOptionsFlare()
    HookTooltipMethods(GameTooltip)
    HookTooltipMethods(ItemRefTooltip)
end
