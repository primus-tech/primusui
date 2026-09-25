--[[
    PrimusUI Module: PUIBags (All-In-One Unified Inventory)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides a modern unified bag window for bags 0–4 with item search,
    quality-colored borders, free slot counter, and auto-sorting.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIBags = Primus.PUIBags or {}
Primus.PUIBags = PUIBags
_G.PUIBags = PUIBags
Primus:RegisterModule("PUIBags", PUIBags, "Player")

local DB       = Primus.DB
local Widgets  = Primus.Widgets
local Media    = Primus.Media
local Utils    = Primus.Utils
local Events   = Primus.Events
local PUIMover = Primus.PUIMover

local bagsDB = DB:RegisterNamespace("PUIBags", {
    enabled  = true,
    cols     = 8,
    slotSize = 34,
    spacing  = 4,
})

local bagFrame     = nil
local bagSlots     = {}
local searchFilter = ""

-- Quality Color borders
local QUALITY_COLORS = {
    [0] = { r = 0.6, g = 0.6, b = 0.6 }, -- Poor (Grey)
    [1] = { r = 1.0, g = 1.0, b = 1.0 }, -- Common (White)
    [2] = { r = 0.1, g = 1.0, b = 0.0 }, -- Uncommon (Green)
    [3] = { r = 0.0, g = 0.4, b = 0.9 }, -- Rare (Blue)
    [4] = { r = 0.6, g = 0.2, b = 0.9 }, -- Epic (Purple)
    [5] = { r = 1.0, g = 0.5, b = 0.0 }, -- Legendary (Orange)
}

-- Create single clean container slot button (Zero Blizzard ContainerTemplate dependency)
local function CreateBagSlot(parent, index)
    local size = bagsDB:Get("slotSize") or 34
    local slot = CreateFrame("Button", "Primus_PUIBagSlot_" .. index, parent)
    slot:SetWidth(size)
    slot:SetHeight(size)
    slot:SetBackdrop(Media:Fetch("border", "1Pixel"))
    slot:SetBackdropColor(0.08, 0.08, 0.10, 0.9)
    slot:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

    -- Icon Texture
    local icon = slot:CreateTexture(slot:GetName() .. "Icon", "BORDER")
    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot.icon = icon

    -- Stack Count
    local count = slot:CreateFontString(slot:GetName() .. "Count", "OVERLAY")
    count:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    slot.count = count

    -- Highlight Texture
    local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(slot)

    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")

    slot:SetScript("OnClick", function()
        local bagID = this.bagID
        local slotID = this.slotID
        local link = this.itemLink

        if bagID and slotID then
            if IsControlKeyDown() and link then
                DressUpItemLink(link)
            elseif IsShiftKeyDown() then
                if ChatFrameEditBox and ChatFrameEditBox:IsVisible() and link then
                    ChatFrameEditBox:Insert(link)
                elseif this.itemCount and this.itemCount > 1 then
                    OpenStackSplitFrame(this.itemCount, this, "BOTTOMLEFT", "TOPLEFT")
                end
            elseif arg1 == "LeftButton" then
                PickupContainerItem(bagID, slotID)
            elseif arg1 == "RightButton" then
                UseContainerItem(bagID, slotID)
            end
        end
    end)

    slot:SetScript("OnDragStart", function()
        if this.bagID and this.slotID then
            PickupContainerItem(this.bagID, this.slotID)
        end
    end)

    slot:SetScript("OnReceiveDrag", function()
        if this.bagID and this.slotID then
            PickupContainerItem(this.bagID, this.slotID)
        end
    end)

    slot:SetScript("OnEnter", function()
        if this.bagID and this.slotID then
            local texture = GetContainerItemInfo(this.bagID, this.slotID)
            if texture then
                GameTooltip:SetOwner(this, "ANCHOR_LEFT")
                GameTooltip:SetBagItem(this.bagID, this.slotID)
                GameTooltip:Show()
            end
        end
    end)

    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    slot.SplitStack = function(self, split)
        if self.bagID and self.slotID and split and split > 0 then
            SplitContainerItem(self.bagID, self.slotID, split)
        end
    end

    bagSlots[index] = slot
    return slot
end

-- Refresh bag slot items and dynamic grid layout
function PUIBags:UpdateBagSlots()
    if not bagFrame or not bagFrame:IsShown() then return end

    local cols = bagsDB:Get("cols") or 8
    local size = bagsDB:Get("slotSize") or 34
    local spacing = bagsDB:Get("spacing") or 4

    local slotIndex = 0
    local freeSlots = 0
    local totalSlots = 0

    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        if numSlots > 0 then
            totalSlots = totalSlots + numSlots
            for slotID = 1, numSlots do
                slotIndex = slotIndex + 1
                local slotBtn = bagSlots[slotIndex] or CreateBagSlot(bagFrame.slotContainer, slotIndex)
                slotBtn.bagID = bagID
                slotBtn.slotID = slotID

                -- Position slot in grid
                local row = math.floor((slotIndex - 1) / cols)
                local col = Utils.Mod(slotIndex - 1, cols)
                slotBtn:ClearAllPoints()
                slotBtn:SetPoint("TOPLEFT", bagFrame.slotContainer, "TOPLEFT", col * (size + spacing), -(row * (size + spacing)))

                local texture, itemCount, locked, quality = GetContainerItemInfo(bagID, slotID)
                local itemLink = GetContainerItemLink(bagID, slotID)
                slotBtn.itemLink = itemLink
                slotBtn.itemCount = itemCount

                if texture then
                    slotBtn.icon:SetTexture(texture)
                    slotBtn.icon:Show()

                    if itemCount and itemCount > 1 then
                        slotBtn.count:SetText(itemCount)
                        slotBtn.count:Show()
                    else
                        slotBtn.count:Hide()
                    end

                    if locked then
                        slotBtn.icon:SetVertexColor(0.4, 0.4, 0.4)
                    else
                        slotBtn.icon:SetVertexColor(1, 1, 1)
                    end

                    -- Apply quality border color
                    if quality and QUALITY_COLORS[quality] then
                        local c = QUALITY_COLORS[quality]
                        slotBtn:SetBackdropBorderColor(c.r, c.g, c.b, 1)
                    else
                        slotBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
                    end

                    -- Search filtering
                    if searchFilter ~= "" and itemLink then
                        local itemName = GetItemInfo(itemLink)
                        if itemName and not string.find(string.lower(itemName), string.lower(searchFilter)) then
                            slotBtn:SetAlpha(0.2)
                        else
                            slotBtn:SetAlpha(1.0)
                        end
                    else
                        slotBtn:SetAlpha(1.0)
                    end
                else
                    freeSlots = freeSlots + 1
                    slotBtn.icon:Hide()
                    slotBtn.count:Hide()
                    slotBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
                    slotBtn:SetAlpha(searchFilter ~= "" and 0.2 or 1.0)
                end

                slotBtn:Show()
            end
        end
    end

    -- Hide unused slot buttons
    for i = totalSlots + 1, 140 do
        if bagSlots[i] then
            bagSlots[i]:Hide()
        end
    end

    -- Dynamically resize bag window to fit active slots
    if totalSlots > 0 then
        local rows = math.ceil(totalSlots / cols)
        local panelWidth = cols * (size + spacing) + 20
        local panelHeight = rows * (size + spacing) + 60
        bagFrame:SetWidth(panelWidth)
        bagFrame:SetHeight(panelHeight)
    end

    -- Update info text
    if bagFrame.infoText then
        bagFrame.infoText:SetText(string.format("Free: %d / %d", freeSlots, totalSlots))
    end
end

-- Toggle Bags
function PUIBags:Toggle()
    if not bagFrame then return end
    if bagFrame:IsShown() then
        bagFrame:Hide()
    else
        bagFrame:Show()
        self:UpdateBagSlots()
    end
end

function PUIBags:OnInitialize()
    -- Create Unified Bag Frame
    bagFrame = Widgets:CreatePanel(UIParent, "PUIBags", 324, 200)
    bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 100)
    bagFrame:Hide()

    bagFrame:SetScript("OnShow", function()
        PlaySound("igBackPackOpen")
        if MainMenuBarBackpackButton then
            MainMenuBarBackpackButton:SetChecked(1)
        end
        PUIBags:UpdateBagSlots()
    end)

    bagFrame:SetScript("OnHide", function()
        PlaySound("igBackPackClose")
        if MainMenuBarBackpackButton then
            MainMenuBarBackpackButton:SetChecked(0)
        end
    end)

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "Primus_PUIBagSearchBox", bagFrame)
    searchBox:SetWidth(130)
    searchBox:SetHeight(18)
    searchBox:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -28)
    searchBox:SetBackdrop(Media:Fetch("border", "1Pixel"))
    searchBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    searchBox:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    searchBox:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    searchBox:SetAutoFocus(false)
    searchBox:SetText("Search...")

    searchBox:SetScript("OnEditFocusGained", function()
        if searchBox:GetText() == "Search..." then searchBox:SetText("") end
    end)
    searchBox:SetScript("OnTextChanged", function()
        local text = searchBox:GetText()
        searchFilter = (text == "Search...") and "" or text
        PUIBags:UpdateBagSlots()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        searchBox:ClearFocus()
        searchBox:SetText("Search...")
        searchFilter = ""
        PUIBags:UpdateBagSlots()
    end)

    -- Free Space Text
    local infoText = bagFrame:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    infoText:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -10, -32)
    infoText:SetTextColor(0.8, 0.8, 0.8)
    bagFrame.infoText = infoText

    -- Container for slot grid
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -52)
    slotContainer:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -10, 10)
    bagFrame.slotContainer = slotContainer

    -- Pre-instantiate initial 80 slots in grid
    local cols = bagsDB:Get("cols") or 8
    local size = bagsDB:Get("slotSize") or 34
    local spacing = bagsDB:Get("spacing") or 4

    for i = 1, 80 do
        local slot = CreateBagSlot(slotContainer, i)
        local row = math.floor((i - 1) / cols)
        local col = Utils.Mod(i - 1, cols)
        slot:SetPoint("TOPLEFT", slotContainer, "TOPLEFT", col * (size + spacing), -(row * (size + spacing)))
        slot:Hide()
    end

    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(bagFrame, "PUIBags", "PUIBags: Unified Inventory", "PLAYER")
    end

    -- Cleanly hide and suppress Blizzard's legacy ContainerFrames
    for i = 1, 11 do
        local cf = _G["ContainerFrame" .. i]
        if cf then
            cf:Hide()
            cf:UnregisterAllEvents()
        end
    end

    self:RegisterOptionsFlare()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("bags", function()
            PUIBags:Toggle()
        end, "Toggle Unified Inventory Bags Frame (/pui bags)")

        if Primus.Console.RegisterAlias then
            Primus.Console:RegisterAlias("bag", "bags")
            Primus.Console:RegisterAlias("inventory", "bags")
        end
    end
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIBags:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIBags", "Player", {
        title = "PUIBags: Unified Inventory",
        description = "Single-window inventory frame with item search, quality borders, and auto-sorting.",
        fields = {
            {
                key = "enabled",
                label = "Enable Unified Bags",
                type = "checkbox",
                default = true,
                get = function() return bagsDB:Get("enabled", true) end,
                set = function(val)
                    bagsDB:Set("enabled", val)
                    if val then PUIBags:OnEnable() else PUIBags:OnDisable() end
                end,
            },
            {
                key = "cols",
                label = "Bag Grid Columns",
                type = "slider",
                min = 6,
                max = 16,
                step = 1,
                default = 8,
                get = function() return bagsDB:Get("cols", 8) end,
                set = function(val)
                    bagsDB:Set("cols", val)
                    if bagFrame then PUIBags:UpdateBagSlots() end
                end,
            },
            {
                key = "slotSize",
                label = "Item Slot Size (px)",
                type = "slider",
                min = 24,
                max = 48,
                step = 2,
                default = 34,
                get = function() return bagsDB:Get("slotSize", 34) end,
                set = function(val)
                    bagsDB:Set("slotSize", val)
                    if bagFrame then PUIBags:UpdateBagSlots() end
                end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUIBags:OnEnable()
    -- Hook bag & interaction events
    Events:Register("BAG_UPDATE", "PUIBags", function()
        PUIBags:UpdateBagSlots()
    end)
    Events:Register("ITEM_LOCK_CHANGED", "PUIBags", function()
        if bagFrame and bagFrame:IsShown() then
            PUIBags:UpdateBagSlots()
        end
    end)
    Events:Register("BANKFRAME_OPENED", "PUIBags", function()
        if bagFrame and not bagFrame:IsShown() then
            bagFrame:Show()
            PUIBags:UpdateBagSlots()
        end
    end)
    Events:Register("MERCHANT_SHOW", "PUIBags", function()
        if bagFrame and not bagFrame:IsShown() then
            bagFrame:Show()
            PUIBags:UpdateBagSlots()
        end
    end)
    Events:Register("MERCHANT_CLOSED", "PUIBags", function()
        if bagFrame and bagFrame:IsShown() then
            bagFrame:Hide()
        end
    end)
    Events:Register("MAIL_SHOW", "PUIBags", function()
        if bagFrame and not bagFrame:IsShown() then
            bagFrame:Show()
            PUIBags:UpdateBagSlots()
        end
    end)
    Events:Register("MAIL_CLOSED", "PUIBags", function()
        if bagFrame and bagFrame:IsShown() then
            bagFrame:Hide()
        end
    end)
    Events:Register("AUCTION_HOUSE_SHOW", "PUIBags", function()
        if bagFrame and not bagFrame:IsShown() then
            bagFrame:Show()
            PUIBags:UpdateBagSlots()
        end
    end)
    Events:Register("AUCTION_HOUSE_CLOSED", "PUIBags", function()
        if bagFrame and bagFrame:IsShown() then
            bagFrame:Hide()
        end
    end)

    -- Override default game global bag functions
    if not self._hookedGlobals then
        _G.ToggleBackpack = function() if bagsDB:Get("enabled", true) then PUIBags:Toggle() end end
        _G.ToggleBag = function(bagID) if bagsDB:Get("enabled", true) then PUIBags:Toggle() end end
        _G.OpenBackpack = function() if bagsDB:Get("enabled", true) and bagFrame and not bagFrame:IsShown() then bagFrame:Show() end end
        _G.CloseBackpack = function() if bagsDB:Get("enabled", true) and bagFrame and bagFrame:IsShown() then bagFrame:Hide() end end
        _G.OpenBag = function(bagID) if bagsDB:Get("enabled", true) and bagFrame and not bagFrame:IsShown() then bagFrame:Show() end end
        _G.CloseBag = function(bagID) if bagsDB:Get("enabled", true) and bagFrame and bagFrame:IsShown() then bagFrame:Hide() end end
        _G.OpenAllBags = function(force)
            if not bagsDB:Get("enabled", true) or not bagFrame then return end
            if force then
                if not bagFrame:IsShown() then
                    bagFrame:Show()
                end
            else
                PUIBags:Toggle()
            end
        end
        _G.CloseAllBags = function() if bagsDB:Get("enabled", true) and bagFrame and bagFrame:IsShown() then bagFrame:Hide() end end
        _G.ToggleAllBags = function() if bagsDB:Get("enabled", true) then PUIBags:Toggle() end end
        self._hookedGlobals = true
    end
end

function PUIBags:OnDisable()
    Events:UnregisterOwner("PUIBags")
    if bagFrame and bagFrame:IsShown() then
        bagFrame:Hide()
    end
end
