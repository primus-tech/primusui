--[[
    PrimusUI Module: PUIBags (All-In-One Unified Inventory)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides a modern unified bag window for bags 0–4 with item search,
    quality-colored borders, free slot counter, equipped bag bar tray (with hide/show toggle),
    and live Gold/Silver/Copper money display.
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
    enabled     = true,
    cols        = 8,
    slotSize    = 34,
    spacing     = 4,
    showBagTray = true, -- Toggleable 5 equipped bag tray
})

local bagFrame         = nil
local bagSlots         = {}
local bagTraySlots     = {}
local searchFilter     = ""
local highlightedBagID = nil

-- Quality Color borders
local QUALITY_COLORS = {
    [0] = { r = 0.6, g = 0.6, b = 0.6 }, -- Poor (Grey)
    [1] = { r = 1.0, g = 1.0, b = 1.0 }, -- Common (White)
    [2] = { r = 0.1, g = 1.0, b = 0.0 }, -- Uncommon (Green)
    [3] = { r = 0.0, g = 0.4, b = 0.9 }, -- Rare (Blue)
    [4] = { r = 0.6, g = 0.2, b = 0.9 }, -- Epic (Purple)
    [5] = { r = 1.0, g = 0.5, b = 0.0 }, -- Legendary (Orange)
}

-- =========================================================================
-- MONEY DISPLAY HELPER
-- =========================================================================

local function UpdateMoneyDisplay()
    if not bagFrame or not bagFrame.copperText or not bagFrame.moneyFrame then return end

    local copper = GetMoney() or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor(Utils.Mod(copper, 10000) / 100)
    local cop = Utils.Mod(copper, 100)

    local rightOffset = 0

    -- Copper
    bagFrame.copperIcon:ClearAllPoints()
    bagFrame.copperIcon:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
    bagFrame.copperIcon:Show()
    rightOffset = rightOffset + 14

    bagFrame.copperText:ClearAllPoints()
    bagFrame.copperText:SetText(cop)
    bagFrame.copperText:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
    bagFrame.copperText:Show()
    local cWidth = bagFrame.copperText:GetStringWidth() or 12
    rightOffset = rightOffset + cWidth + 6

    -- Silver
    if silver > 0 or gold > 0 then
        bagFrame.silverIcon:ClearAllPoints()
        bagFrame.silverIcon:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
        bagFrame.silverIcon:Show()
        rightOffset = rightOffset + 14

        bagFrame.silverText:ClearAllPoints()
        bagFrame.silverText:SetText(silver)
        bagFrame.silverText:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
        bagFrame.silverText:Show()
        local sWidth = bagFrame.silverText:GetStringWidth() or 12
        rightOffset = rightOffset + sWidth + 6
    else
        bagFrame.silverText:Hide()
        bagFrame.silverIcon:Hide()
    end

    -- Gold
    if gold > 0 then
        bagFrame.goldIcon:ClearAllPoints()
        bagFrame.goldIcon:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
        bagFrame.goldIcon:Show()
        rightOffset = rightOffset + 14

        bagFrame.goldText:ClearAllPoints()
        bagFrame.goldText:SetText(gold)
        bagFrame.goldText:SetPoint("RIGHT", bagFrame.moneyFrame, "RIGHT", -rightOffset, 0)
        bagFrame.goldText:Show()
    else
        bagFrame.goldText:Hide()
        bagFrame.goldIcon:Hide()
    end
end

-- =========================================================================
-- EQUIPPED BAG TRAY SLOTS (Bags 0 to 4)
-- =========================================================================

local function CreateBagTraySlot(parent, bagID)
    local slot = CreateFrame("Button", "Primus_PUIBagTraySlot_" .. bagID, parent)
    slot:SetWidth(28)
    slot:SetHeight(28)
    slot:SetBackdrop(Media:Fetch("border", "1Pixel"))
    slot:SetBackdropColor(0.08, 0.08, 0.10, 0.9)
    slot:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    slot:SetPoint("LEFT", parent, "LEFT", bagID * 32, 0)

    local icon = slot:CreateTexture(slot:GetName() .. "Icon", "BORDER")
    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot.icon = icon

    local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(slot)

    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")

    slot:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            -- Shift-Click: Pick up or swap the bag!
            if bagID == 0 then
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIBags]: The backpack cannot be unequipped.", "ffbb33"))
                return
            end
            local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
            if invSlot then
                if CursorHasItem() then
                    PutItemInBag(invSlot)
                else
                    PickupBagFromSlot(invSlot)
                end
            end
        else
            -- Plain Click: Highlight bag space or place bag if holding one on cursor
            if CursorHasItem() and bagID > 0 then
                local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
                if invSlot then
                    PutItemInBag(invSlot)
                    return
                end
            end

            -- Toggle highlight for this bag in the unified window
            if highlightedBagID == bagID then
                highlightedBagID = nil
            else
                highlightedBagID = bagID
            end
            PUIBags:UpdateBagSlots()
        end
    end)

    slot:SetScript("OnDragStart", function()
        if bagID == 0 then return end
        local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
        if invSlot then
            PickupBagFromSlot(invSlot)
        end
    end)

    slot:SetScript("OnReceiveDrag", function()
        if bagID == 0 then return end
        local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
        if invSlot then
            PutItemInBag(invSlot)
        end
    end)

    slot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        if bagID == 0 then
            GameTooltip:SetText("Backpack (16 Slots)", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Your primary inventory container.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("|cffffd100Left-Click:|r Highlight backpack slots", 1.0, 1.0, 1.0)
            GameTooltip:Show()
        else
            local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
            if invSlot then
                local hasItem = GetInventoryItemTexture("player", invSlot)
                if hasItem then
                    GameTooltip:SetInventoryItem("player", invSlot)
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine("|cffffd100Left-Click:|r Highlight this bag's slots", 1.0, 1.0, 1.0)
                    GameTooltip:AddLine("|cffffd100Shift-Click / Drag:|r Pick up or swap bag", 1.0, 1.0, 1.0)
                else
                    GameTooltip:SetText(string.format("Bag Slot %d", bagID), 1.0, 0.82, 0.0)
                    GameTooltip:AddLine("Empty bag slot. Drag a bag here to equip it.", 0.7, 0.7, 0.7)
                    GameTooltip:AddLine(" ", 1, 1, 1)
                    GameTooltip:AddLine("|cffffd100Left-Click:|r Highlight this bag's slots", 1.0, 1.0, 1.0)
                    GameTooltip:AddLine("|cffffd100Shift-Click / Drag:|r Place or equip bag", 1.0, 1.0, 1.0)
                end
                GameTooltip:Show()
            end
        end
    end)

    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    bagTraySlots[bagID] = slot
    return slot
end

local function UpdateBagTray()
    if not bagFrame or not bagFrame.bagTray then return end

    local showTray = bagsDB:Get("showBagTray", true)
    if not showTray then
        bagFrame.bagTray:Hide()
        for bagID = 0, 4 do
            if bagTraySlots[bagID] then bagTraySlots[bagID]:Hide() end
        end
        return
    end

    bagFrame.bagTray:Show()

    for bagID = 0, 4 do
        local slot = bagTraySlots[bagID] or CreateBagTraySlot(bagFrame.bagTray, bagID)
        slot:ClearAllPoints()
        slot:SetPoint("LEFT", bagFrame.bagTray, "LEFT", bagID * 32, 0)

        local isSelected = (highlightedBagID == bagID)
        local isAnySelected = (highlightedBagID ~= nil)
        local baseAlpha = (isAnySelected and not isSelected) and 0.45 or 1.0

        if isSelected then
            -- Bright highlight border on selected bag button
            slot:SetBackdropBorderColor(1.0, 0.85, 0.10, 1)
        elseif bagID == 0 then
            slot.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
            slot.icon:Show()
            slot:SetBackdropBorderColor(0.85, 0.70, 0.20, baseAlpha)
        else
            local invSlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
            local texture = invSlot and GetInventoryItemTexture("player", invSlot)
            if texture then
                slot.icon:SetTexture(texture)
                slot.icon:Show()
                local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", invSlot)
                if quality and QUALITY_COLORS[quality] then
                    local c = QUALITY_COLORS[quality]
                    slot:SetBackdropBorderColor(c.r, c.g, c.b, baseAlpha)
                else
                    slot:SetBackdropBorderColor(0.2, 0.6, 1.0, baseAlpha)
                end
            else
                slot.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                slot.icon:Show()
                slot:SetBackdropBorderColor(0.25, 0.25, 0.30, baseAlpha)
            end
        end
        slot:Show()
    end
end

-- =========================================================================
-- CONTAINER ITEM SLOTS
-- =========================================================================

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

-- Refresh bag slot items, bag tray, and dynamic grid layout
function PUIBags:UpdateBagSlots()
    if not bagFrame or not bagFrame:IsShown() then return end

    local cols = bagsDB:Get("cols") or 8
    local size = bagsDB:Get("slotSize") or 34
    local spacing = bagsDB:Get("spacing") or 4
    local showTray = bagsDB:Get("showBagTray", true)

    local slotIndex = 0
    local freeSlots = 0
    local totalSlots = 0

    -- Update Bag Tray
    UpdateBagTray()

    -- Adjust Slot Container vertical anchor based on Bag Tray visibility
    bagFrame.slotContainer:ClearAllPoints()
    if showTray then
        bagFrame.slotContainer:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -62)
        bagFrame.slotContainer:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -10, 32)
    else
        bagFrame.slotContainer:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -32)
        bagFrame.slotContainer:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -10, 32)
    end

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

                    -- Calculate slot visibility & opacity based on highlightedBagID and searchFilter
                    local slotAlpha = 1.0
                    if highlightedBagID ~= nil and bagID ~= highlightedBagID then
                        slotAlpha = 0.20
                    end
                    if searchFilter ~= "" and itemLink then
                        local itemName = GetItemInfo(itemLink)
                        if itemName and not string.find(string.lower(itemName), string.lower(searchFilter)) then
                            slotAlpha = 0.20
                        end
                    end
                    slotBtn:SetAlpha(slotAlpha)
                else
                    freeSlots = freeSlots + 1
                    slotBtn.icon:Hide()
                    slotBtn.count:Hide()
                    slotBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

                    local slotAlpha = 1.0
                    if highlightedBagID ~= nil and bagID ~= highlightedBagID then
                        slotAlpha = 0.20
                    elseif searchFilter ~= "" then
                        slotAlpha = 0.20
                    end
                    slotBtn:SetAlpha(slotAlpha)
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

    -- Dynamically resize bag window to fit active slots and panels
    if totalSlots > 0 then
        local rows = math.ceil(totalSlots / cols)
        local gridWidth = cols * (size + spacing) - spacing
        local panelWidth = math.max(gridWidth + 20, 260)
        local gridHeight = rows * (size + spacing)
        local extraHeight = (showTray and 62 or 32) + 36 -- Top padding + bottom footer
        local panelHeight = gridHeight + extraHeight

        bagFrame:SetWidth(panelWidth)
        bagFrame:SetHeight(panelHeight)
    end

    -- Update info text (Free Slots)
    if bagFrame.infoText then
        bagFrame.infoText:SetText(string.format("Free: %d / %d", freeSlots, totalSlots))
    end

    -- Update Money Display
    UpdateMoneyDisplay()
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

-- Toggle Bag Tray (Equipped Bags 0-4)
function PUIBags:ToggleBagTray()
    local cur = bagsDB:Get("showBagTray", true)
    bagsDB:Set("showBagTray", not cur)
    if bagFrame and bagFrame.trayToggleBtn then
        bagFrame.trayToggleBtn:SetBackdropBorderColor(not cur and 0.8 or 0.3, not cur and 0.65 or 0.3, not cur and 0.2 or 0.35, 1)
    end
    self:UpdateBagSlots()
end

-- =========================================================================
-- INITIALIZATION & UI CONSTRUCTION
-- =========================================================================

function PUIBags:OnInitialize()
    -- Create Unified Bag Frame
    bagFrame = Widgets:CreatePanel(UIParent, "PUIBags", 324, 240)
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
        highlightedBagID = nil
    end)

    -- Header Controls: Search EditBox
    local searchBox = CreateFrame("EditBox", "Primus_PUIBagSearchBox", bagFrame)
    searchBox:SetWidth(120)
    searchBox:SetHeight(18)
    searchBox:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -8)
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

    -- Bag Tray Toggle Button (Header)
    local trayToggleBtn = CreateFrame("Button", "Primus_PUIBagTrayToggleBtn", bagFrame)
    trayToggleBtn:SetWidth(18)
    trayToggleBtn:SetHeight(18)
    trayToggleBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    trayToggleBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    trayToggleBtn:SetBackdropColor(0.08, 0.08, 0.10, 0.9)
    local isTrayShown = bagsDB:Get("showBagTray", true)
    trayToggleBtn:SetBackdropBorderColor(isTrayShown and 0.8 or 0.3, isTrayShown and 0.65 or 0.3, isTrayShown and 0.2 or 0.35, 1)

    local trayIcon = trayToggleBtn:CreateTexture(nil, "ARTWORK")
    trayIcon:SetPoint("TOPLEFT", trayToggleBtn, "TOPLEFT", 1, -1)
    trayIcon:SetPoint("BOTTOMRIGHT", trayToggleBtn, "BOTTOMRIGHT", -1, 1)
    trayIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    trayIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    trayToggleBtn:SetScript("OnClick", function()
        PUIBags:ToggleBagTray()
    end)
    trayToggleBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Toggle Bag Bar", 1.0, 0.82, 0.0)
        GameTooltip:AddLine("Show or hide the 5 equipped bag slots (Backpack + Bags 1-4).", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    trayToggleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    bagFrame.trayToggleBtn = trayToggleBtn

    -- Free Space Text (Header Right)
    local infoText = bagFrame:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    infoText:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -26, -11)
    infoText:SetTextColor(0.8, 0.8, 0.8)
    bagFrame.infoText = infoText

    -- Bag Tray Container Frame
    local bagTray = CreateFrame("Frame", "Primus_PUIBagTrayContainer", bagFrame)
    bagTray:SetHeight(30)
    bagTray:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -30)
    bagTray:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -10, -30)
    bagFrame.bagTray = bagTray

    -- Pre-create the 5 bag tray slots
    for b = 0, 4 do
        CreateBagTraySlot(bagTray, b)
    end

    -- Container for slot grid
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -62)
    slotContainer:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -10, 32)
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

    -- Footer: Money Display Frame (Native Vanilla 1.12.1 Coin Icons & Text)
    local moneyFrame = CreateFrame("Frame", "Primus_PUIBagMoneyFrame", bagFrame)
    moneyFrame:SetHeight(20)
    moneyFrame:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", 10, 6)
    moneyFrame:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -10, 6)

    -- Copper
    local copperIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    copperIcon:SetWidth(13)
    copperIcon:SetHeight(13)
    copperIcon:SetTexture("Interface\\MoneyFrame\\UI-MoneyIcons")
    copperIcon:SetTexCoord(0.5, 0.75, 0, 1)

    local copperText = moneyFrame:CreateFontString(nil, "OVERLAY")
    copperText:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    copperText:SetTextColor(1, 1, 1)

    -- Silver
    local silverIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    silverIcon:SetWidth(13)
    silverIcon:SetHeight(13)
    silverIcon:SetTexture("Interface\\MoneyFrame\\UI-MoneyIcons")
    silverIcon:SetTexCoord(0.25, 0.5, 0, 1)

    local silverText = moneyFrame:CreateFontString(nil, "OVERLAY")
    silverText:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    silverText:SetTextColor(1, 1, 1)

    -- Gold
    local goldIcon = moneyFrame:CreateTexture(nil, "ARTWORK")
    goldIcon:SetWidth(13)
    goldIcon:SetHeight(13)
    goldIcon:SetTexture("Interface\\MoneyFrame\\UI-MoneyIcons")
    goldIcon:SetTexCoord(0, 0.25, 0, 1)

    local goldText = moneyFrame:CreateFontString(nil, "OVERLAY")
    goldText:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    goldText:SetTextColor(1, 1, 1)

    bagFrame.moneyFrame = moneyFrame
    bagFrame.copperIcon = copperIcon
    bagFrame.copperText = copperText
    bagFrame.silverIcon = silverIcon
    bagFrame.silverText = silverText
    bagFrame.goldIcon = goldIcon
    bagFrame.goldText = goldText

    moneyFrame:EnableMouse(true)
    moneyFrame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Player Currency", 1.0, 0.82, 0.0)
        GameTooltip:AddLine(Utils.FormatMoney(GetMoney() or 0), 1, 1, 1)
        GameTooltip:Show()
    end)
    moneyFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        description = "Single-window inventory frame with item search, quality borders, bag bar tray, and money display.",
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
                key = "showBagTray",
                label = "Show Equipped Bags Bar (Bags 0-4)",
                type = "checkbox",
                default = true,
                get = function() return bagsDB:Get("showBagTray", true) end,
                set = function(val)
                    bagsDB:Set("showBagTray", val)
                    if bagFrame then PUIBags:UpdateBagSlots() end
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
    Events:Register("PLAYER_MONEY", "PUIBags", function()
        UpdateMoneyDisplay()
    end)
    Events:Register("UNIT_INVENTORY_CHANGED", "PUIBags", function(unit)
        if unit == "player" and bagFrame and bagFrame:IsShown() then
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
