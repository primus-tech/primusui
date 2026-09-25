--[[
    PrimusUI Module: PUIBank (Unified Bank with Offline Persistent Caching)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides a modern unified bank container for slots -1 and 5–10,
    plus offline SavedVariables caching for browsing bank items anywhere.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIBank = Primus.PUIBank or {}
Primus.PUIBank = PUIBank
_G.PUIBank = PUIBank
Primus:RegisterModule("PUIBank", PUIBank, "Player")

local DB       = Primus.DB
local Widgets  = Primus.Widgets
local Media    = Primus.Media
local Utils    = Primus.Utils
local Events   = Primus.Events
local PUIMover = Primus.PUIMover

-- Quality border colors
local QUALITY_COLORS = {
    [0] = { r = 0.6, g = 0.6, b = 0.6 }, -- Poor (Grey)
    [1] = { r = 1.0, g = 1.0, b = 1.0 }, -- Common (White)
    [2] = { r = 0.1, g = 1.0, b = 0.0 }, -- Uncommon (Green)
    [3] = { r = 0.0, g = 0.4, b = 0.9 }, -- Rare (Blue)
    [4] = { r = 0.6, g = 0.2, b = 0.9 }, -- Epic (Purple)
    [5] = { r = 1.0, g = 0.5, b = 0.0 }, -- Legendary (Orange)
}

-- Character-specific bank cache
local bankDB = DB:RegisterNamespace("PUIBankCache", {
    cachedItems = {}, -- [slotIndex] = { texture, count, link, name, quality, bagID, slotID }
    cachedBags  = {}, -- [bagIndex] = { texture, link, numSlots }
    lastScanned = "",
}, true)

local bankFrame    = nil
local bankSlots    = {}
local bagButtons   = {}
local isBankOpen   = false
local searchFilter = ""

-- Create a clean Bank Slot button (Zero Blizzard BankTemplate dependency)
local function CreateBankSlot(parent, index)
    local slot = CreateFrame("Button", "Primus_PUIBankSlot_" .. index, parent)
    slot:SetWidth(34)
    slot:SetHeight(34)
    slot:SetBackdrop(Media:Fetch("border", "1Pixel"))
    slot:SetBackdropColor(0.08, 0.08, 0.10, 0.9)
    slot:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

    -- Icon texture
    local icon = slot:CreateTexture(slot:GetName() .. "Icon", "BORDER")
    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot.icon = icon

    -- Stack count
    local count = slot:CreateFontString(slot:GetName() .. "Count", "OVERLAY")
    count:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    slot.count = count

    -- Highlight texture
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

        if isBankOpen and bagID and slotID then
            if IsShiftKeyDown() then
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
        else
            -- Offline view
            if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() and link then
                ChatFrameEditBox:Insert(link)
            end
        end
    end)

    slot:SetScript("OnDragStart", function()
        if isBankOpen and this.bagID and this.slotID then
            PickupContainerItem(this.bagID, this.slotID)
        end
    end)

    slot:SetScript("OnReceiveDrag", function()
        if isBankOpen and this.bagID and this.slotID then
            PickupContainerItem(this.bagID, this.slotID)
        end
    end)

    slot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if isBankOpen and this.bagID and this.slotID then
            local texture = GetContainerItemInfo(this.bagID, this.slotID)
            if texture then
                GameTooltip:SetBagItem(this.bagID, this.slotID)
                GameTooltip:Show()
            end
        elseif this.itemLink then
            local rawLink = Utils.ExtractLink(this.itemLink)
            if rawLink then
                GameTooltip:SetHyperlink(rawLink)
                GameTooltip:Show()
            end
        end
    end)

    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    slot.SplitStack = function(self, split)
        if isBankOpen and self.bagID and self.slotID and split and split > 0 then
            SplitContainerItem(self.bagID, self.slotID, split)
        end
    end

    bankSlots[index] = slot
    return slot
end

-- Save live bank contents to DB
function PUIBank:SaveBankCache()
    local cache = {}
    local slotIndex = 0

    -- 1. Main Bank Container (-1) (24 slots)
    for slotID = 1, 24 do
        slotIndex = slotIndex + 1
        local texture, count, locked, quality = GetContainerItemInfo(-1, slotID)
        local link = GetContainerItemLink(-1, slotID)
        if texture then
            local name = link and GetItemInfo(link) or ""
            cache[slotIndex] = {
                texture = texture,
                count   = count or 1,
                link    = link,
                name    = name or "",
                quality = quality or 1,
                bagID   = -1,
                slotID  = slotID,
                locked  = locked,
            }
        else
            cache[slotIndex] = {
                bagID  = -1,
                slotID = slotID,
            }
        end
    end

    -- 2. Bank Bags (5 to 10)
    local bagCache = {}
    for bagIndex = 1, 6 do
        local bagID = bagIndex + 4 -- Bags 5..10
        local invSlot = 67 + bagIndex -- Bank bag inventory slots 68..73
        local bagTexture = GetInventoryItemTexture("player", invSlot)
        local bagLink = GetInventoryItemLink("player", invSlot)
        local numSlots = GetContainerNumSlots(bagID)

        bagCache[bagIndex] = {
            texture  = bagTexture,
            link     = bagLink,
            numSlots = numSlots or 0,
        }

        if numSlots > 0 then
            for slotID = 1, numSlots do
                slotIndex = slotIndex + 1
                local texture, count, locked, quality = GetContainerItemInfo(bagID, slotID)
                local link = GetContainerItemLink(bagID, slotID)
                if texture then
                    local name = link and GetItemInfo(link) or ""
                    cache[slotIndex] = {
                        texture = texture,
                        count   = count or 1,
                        link    = link,
                        name    = name or "",
                        quality = quality or 1,
                        bagID   = bagID,
                        slotID  = slotID,
                        locked  = locked,
                    }
                else
                    cache[slotIndex] = {
                        bagID  = bagID,
                        slotID = slotID,
                    }
                end
            end
        end
    end

    bankDB:Set("cachedItems", cache)
    bankDB:Set("cachedBags", bagCache)
    bankDB:Set("lastScanned", date("%Y-%m-%d %H:%M"))
end

-- Refresh Bank UI (Live or Offline Cache)
function PUIBank:UpdateBankSlots()
    if not bankFrame or not bankFrame:IsShown() then return end

    if isBankOpen then
        self:SaveBankCache()
    end

    local cache = bankDB:Get("cachedItems") or {}
    local totalItems = table.getn(cache)
    if totalItems < 24 then totalItems = 24 end

    local freeCount = 0
    local totalCount = 0

    for i = 1, 140 do
        local slotBtn = bankSlots[i]
        local item = cache[i]

        if item then
            totalCount = totalCount + 1
            slotBtn.bagID = item.bagID
            slotBtn.slotID = item.slotID
            slotBtn.itemLink = item.link
            slotBtn.itemCount = item.count

            if item.texture then
                slotBtn.icon:SetTexture(item.texture)
                slotBtn.icon:Show()

                if item.count and item.count > 1 then
                    slotBtn.count:SetText(item.count)
                    slotBtn.count:Show()
                else
                    slotBtn.count:Hide()
                end

                if item.locked then
                    slotBtn.icon:SetVertexColor(0.4, 0.4, 0.4)
                else
                    slotBtn.icon:SetVertexColor(1, 1, 1)
                end

                -- Quality Border
                if item.quality and QUALITY_COLORS[item.quality] then
                    local c = QUALITY_COLORS[item.quality]
                    slotBtn:SetBackdropBorderColor(c.r, c.g, c.b, 1)
                else
                    slotBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
                end

                -- Search Filtering
                if searchFilter ~= "" and item.name then
                    if string.find(string.lower(item.name), string.lower(searchFilter)) then
                        slotBtn:SetAlpha(1.0)
                    else
                        slotBtn:SetAlpha(0.2)
                    end
                else
                    slotBtn:SetAlpha(1.0)
                end
            else
                freeCount = freeCount + 1
                slotBtn.icon:Hide()
                slotBtn.count:Hide()
                slotBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
                slotBtn:SetAlpha(searchFilter ~= "" and 0.2 or 1.0)
            end

            slotBtn:Show()
        else
            if slotBtn then
                slotBtn:Hide()
            end
        end
    end

    -- Update title & status
    if bankFrame.title then
        if isBankOpen then
            bankFrame.title:SetText("Bank")
        else
            local last = bankDB:Get("lastScanned") or "Never"
            bankFrame.title:SetText("Bank (Offline: " .. last .. ")")
        end
    end

    if bankFrame.infoText then
        bankFrame.infoText:SetText(string.format("Free: %d / %d", freeCount, totalCount))
    end
end

function PUIBank:CreateBankUI()
    if bankFrame then return bankFrame end

    -- Create Bank Window
    bankFrame = Widgets:CreatePanel(UIParent, "PUIBank", 360, 480)
    bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    bankFrame:Hide()

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "Primus_PUIBankSearchBox", bankFrame)
    searchBox:SetWidth(150)
    searchBox:SetHeight(18)
    searchBox:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 10, -28)
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
        PUIBank:UpdateBankSlots()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        searchBox:ClearFocus()
        searchBox:SetText("Search...")
        searchFilter = ""
        PUIBank:UpdateBankSlots()
    end)

    -- Free Space Text
    local infoText = bankFrame:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    infoText:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -10, -32)
    infoText:SetTextColor(0.8, 0.8, 0.8)
    bankFrame.infoText = infoText

    -- Slot Container
    local slotContainer = CreateFrame("Frame", nil, bankFrame)
    slotContainer:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 10, -52)
    slotContainer:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -10, 10)
    bankFrame.slotContainer = slotContainer

    -- Create 140 maximum potential bank slots (8 columns grid)
    for i = 1, 140 do
        local slot = CreateBankSlot(slotContainer, i)
        local row = math.floor((i - 1) / 8)
        local col = Utils.Mod(i - 1, 8)
        slot:SetPoint("TOPLEFT", slotContainer, "TOPLEFT", col * 42, -(row * 42))
        slot:Hide()
    end

    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(bankFrame, "PUIBank", "PUIBank: Unified Bank", "PLAYER")
    end

    return bankFrame
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIBank:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIBank", "Player", {
        title = "PUIBank: Unified Bank & Offline Cache",
        description = "Unified bank interface with character inventory persistence and search.",
        fields = {
            {
                key = "enabled",
                label = "Enable Unified Bank Frame",
                type = "checkbox",
                default = true,
                get = function() return true end,
                set = function(val)
                    if val then PUIBank:OnEnable() else PUIBank:OnDisable() end
                end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT DISPATCH
-- =========================================================================

function PUIBank:OnInitialize()
    self:RegisterOptionsFlare()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("bank", function()
            if bankFrame and bankFrame:IsShown() then
                bankFrame:Hide()
            else
                if not bankFrame then PUIBank:CreateBankUI() end
                bankFrame:Show()
                PUIBank:UpdateBankSlots()
            end
        end, "Toggle Unified Bank Frame (/pui bank)")
    end
end

function PUIBank:OnEnable()
    -- Hook Bank Events & Suppress Blizzard Legacy BankFrame
    Events:Register("BANKFRAME_OPENED", "PUIBank", function()
        isBankOpen = true
        if BankFrame then
            BankFrame:Hide()
            BankFrame:UnregisterAllEvents()
        end
        if not bankFrame then PUIBank:CreateBankUI() end
        bankFrame:Show()
        PUIBank:UpdateBankSlots()
    end)

    Events:Register("BANKFRAME_CLOSED", "PUIBank", function()
        isBankOpen = false
        if bankFrame then bankFrame:Hide() end
    end)

    Events:Register("PLAYERBANKSLOTS_CHANGED", "PUIBank", function()
        if isBankOpen then
            PUIBank:UpdateBankSlots()
        end
    end)

    Events:Register("PLAYERBANKBAGSLOTS_CHANGED", "PUIBank", function()
        if isBankOpen then
            PUIBank:UpdateBankSlots()
        end
    end)

    Events:Register("ITEM_LOCK_CHANGED", "PUIBank", function()
        if isBankOpen and bankFrame and bankFrame:IsShown() then
            PUIBank:UpdateBankSlots()
        end
    end)
end

function PUIBank:OnDisable()
    Events:UnregisterOwner("PUIBank")
    if bankFrame and bankFrame:IsShown() then
        bankFrame:Hide()
    end
end
