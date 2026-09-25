--[[
    PrimusLib Module: FastLoot (Instant Single-Frame Auto-Loot)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Picks up all items instantly upon opening a loot container/corpse
    without the default animation delay.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIFastLoot = Primus.PUIFastLoot or {}
Primus.PUIFastLoot = PUIFastLoot
_G.PUIFastLoot = PUIFastLoot
Primus:RegisterModule("PUIFastLoot", PUIFastLoot, "Utility")

local DB     = Primus.DB
local Events = Primus.Events
local Utils  = Primus.Utils

local fastLootDB = DB:RegisterNamespace("PUIFastLoot", {
    enabled = true,
    autoClose = true,
})

function PUIFastLoot:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIFastLoot", {
        name = "PUIFastLoot",
        category = "Utility",
        label = "Fast Loot",
        icon = "Interface\Icons\INV_Misc_Bag_10_Blue",
        desc = "Instant 0-delay auto-looting from mobs, containers, and quest nodes.",
    })
end

function PUIFastLoot:OnInitialize()
    self:RegisterOptionsFlare()
    Events:Register("LOOT_OPENED", self, function()
        if not fastLootDB:Get("enabled") then return end

        local numItems = GetNumLootItems()
        if numItems > 0 then
            for i = numItems, 1, -1 do
                LootSlot(i)
            end
        end

        if fastLootDB:Get("autoClose") and numItems > 0 then
            -- Check if all items taken
            if GetNumLootItems() == 0 then
                CloseLoot()
            end
        end
    end)
end
