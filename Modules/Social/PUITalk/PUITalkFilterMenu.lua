--[[
    PrimusUI Module: PUITalk (Channel Filter Context Menu)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    - Floating Channel Filter context menu (Primus_PUITalkChannelMenu).
    - Granular channel toggle buttons (Say, Trade, General, LFG, World, Loot, etc.).
    - [✓ All On] and [✗ All Off] bulk toggle controls.
    - Screen-boundary aware auto-docking positioning.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus or not Primus.PUITalk then return end

local PUITalk = Primus.PUITalk
local Media   = Primus.Media
local Utils   = Primus.Utils

local channelMenuFrame = nil

local CHANNEL_MENU_ITEMS = {
    { key = "SAY",          label = "Say & Yell",          color = "ffffff" },
    { key = "EMOTE",        label = "Emotes",              color = "ff8040" },
    { key = "PARTY",        label = "Party",               color = "aaaaee" },
    { key = "RAID",         label = "Raid & Warnings",     color = "ff7f00" },
    { key = "GUILD",        label = "Guild",               color = "40ff40" },
    { key = "OFFICER",      label = "Officer",             color = "40c040" },
    { key = "GENERAL",      label = "1. General",          color = "e6c099" },
    { key = "TRADE",        label = "2. Trade",            color = "e6c099" },
    { key = "LOCALDEFENSE", label = "3. Local Defense",    color = "e6c099" },
    { key = "LFG",          label = "4. LookingForGroup",  color = "e6c099" },
    { key = "WORLD",        label = "World / Custom",      color = "e6c099" },
    { key = "SYSTEM",       label = "System Messages",     color = "ffff00" },
    { key = "MONSTER",      label = "Monster Say/Emotes",  color = "ffd100" },
    { key = "LOOT",         label = "Loot & Money",        color = "00cc00" },
}

function PUITalk:CreateChannelContextMenu()
    if channelMenuFrame then return channelMenuFrame end

    local menu = CreateFrame("Frame", "Primus_PUITalkChannelMenu", UIParent)
    menu:SetWidth(190)
    menu:SetHeight(335)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(100)
    menu:SetBackdrop(Media:Fetch("border", "1Pixel"))
    menu:SetBackdropColor(0.06, 0.07, 0.10, 0.98)
    menu:SetBackdropBorderColor(0.20, 0.50, 0.90, 1.0)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:Hide()

    tinsert(UISpecialFrames, "Primus_PUITalkChannelMenu")

    local header = CreateFrame("Frame", nil, menu)
    header:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4)
    header:SetHeight(22)
    header:SetBackdrop(Media:Fetch("border", "1Pixel"))
    header:SetBackdropColor(0.10, 0.14, 0.22, 1.0)
    header:SetBackdropBorderColor(0.25, 0.45, 0.75, 1.0)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    title:SetPoint("LEFT", header, "LEFT", 6, 0)
    title:SetText(Utils.ColorText("Channel Filters", "69ccf0"))

    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetWidth(14)
    closeBtn:SetHeight(14)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    closeBtn:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    closeBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    local cX = closeBtn:CreateFontString(nil, "OVERLAY")
    cX:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    cX:SetPoint("CENTER", 0, 0)
    cX:SetText("x")
    closeBtn:SetScript("OnClick", function() menu:Hide() end)

    local rows = {}
    local yOffset = -28

    for i, item in ipairs(CHANNEL_MENU_ITEMS) do
        local row = CreateFrame("Button", nil, menu)
        row:SetWidth(178)
        row:SetHeight(17)
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, yOffset)
        row:SetBackdrop(Media:Fetch("border", "1Pixel"))
        row:SetBackdropColor(0.08, 0.10, 0.14, 0.6)
        row:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.6)

        local check = row:CreateFontString(nil, "OVERLAY")
        check:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
        check:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.check = check

        local label = row:CreateFontString(nil, "OVERLAY")
        label:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
        label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        label:SetText(Utils.ColorText(item.label, item.color))
        row.label = label

        row.chanKey = item.key
        row.itemLabel = item.label

        row:SetScript("OnEnter", function()
            this:SetBackdropColor(0.15, 0.22, 0.35, 1.0)
            this:SetBackdropBorderColor(0.30, 0.60, 1.0, 1.0)
        end)
        row:SetScript("OnLeave", function()
            this:SetBackdropColor(0.08, 0.10, 0.14, 0.6)
            this:SetBackdropBorderColor(0.15, 0.20, 0.30, 0.6)
        end)
        row:SetScript("OnClick", function()
            local cur = PUITalk:IsChannelEnabled(this.chanKey)
            local newState = not cur
            PUITalk:SetChannelEnabled(this.chanKey, newState)
            PUITalk:RefreshChannelContextMenu()
            if DEFAULT_CHAT_FRAME then
                local status = newState and "|cff00ff00ENABLED|r" or "|cffff4040DISABLED|r"
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: " .. (this.itemLabel or this.chanKey) .. " channel is now " .. status .. ".", "69ccf0"))
            end
        end)

        rows[i] = row
        yOffset = yOffset - 18
    end

    local footer = CreateFrame("Frame", nil, menu)
    footer:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 4, 4)
    footer:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
    footer:SetHeight(20)

    local btnAllOn = CreateFrame("Button", nil, footer)
    btnAllOn:SetWidth(88)
    btnAllOn:SetHeight(18)
    btnAllOn:SetPoint("LEFT", footer, "LEFT", 2, 0)
    btnAllOn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    btnAllOn:SetBackdropColor(0.12, 0.20, 0.12, 1.0)
    btnAllOn:SetBackdropBorderColor(0.25, 0.60, 0.25, 1.0)
    local onTxt = btnAllOn:CreateFontString(nil, "OVERLAY")
    onTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    onTxt:SetPoint("CENTER", 0, 0)
    onTxt:SetText("✓ All On")
    btnAllOn:SetScript("OnClick", function()
        for _, it in ipairs(CHANNEL_MENU_ITEMS) do
            PUITalk:SetChannelEnabled(it.key, true)
        end
        PUITalk:RefreshChannelContextMenu()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: All channels ENABLED.", "69ccf0"))
        end
    end)

    local btnAllOff = CreateFrame("Button", nil, footer)
    btnAllOff:SetWidth(88)
    btnAllOff:SetHeight(18)
    btnAllOff:SetPoint("RIGHT", footer, "RIGHT", -2, 0)
    btnAllOff:SetBackdrop(Media:Fetch("border", "1Pixel"))
    btnAllOff:SetBackdropColor(0.20, 0.12, 0.12, 1.0)
    btnAllOff:SetBackdropBorderColor(0.60, 0.25, 0.25, 1.0)
    local offTxt = btnAllOff:CreateFontString(nil, "OVERLAY")
    offTxt:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
    offTxt:SetPoint("CENTER", 0, 0)
    offTxt:SetText("✗ All Off")
    btnAllOff:SetScript("OnClick", function()
        for _, it in ipairs(CHANNEL_MENU_ITEMS) do
            PUITalk:SetChannelEnabled(it.key, false)
        end
        PUITalk:RefreshChannelContextMenu()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Primus Talk]: All channels DISABLED.", "69ccf0"))
        end
    end)

    menu.rows = rows
    channelMenuFrame = menu
    return menu
end

function PUITalk:RefreshChannelContextMenu()
    if not channelMenuFrame or not channelMenuFrame.rows then return end
    for _, row in ipairs(channelMenuFrame.rows) do
        local enabled = self:IsChannelEnabled(row.chanKey)
        if enabled then
            row.check:SetText("|cff00ff00[x]|r")
        else
            row.check:SetText("|cff888888[ ]|r")
        end
    end
end

function PUITalk:ToggleChannelContextMenu(anchor)
    local menu = self:CreateChannelContextMenu()
    if menu:IsShown() then
        menu:Hide()
    else
        self:RefreshChannelContextMenu()
        menu:ClearAllPoints()
        if anchor then
            local top = anchor:GetTop() or 0
            local screenHeight = UIParent:GetHeight() or 768
            if top > (screenHeight * 0.6) then
                menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
            else
                menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
            end
        else
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            menu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end
        menu:Show()
        menu:Raise()
    end
end
