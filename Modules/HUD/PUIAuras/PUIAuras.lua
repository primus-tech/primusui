--[[
    PrimusUI Module: PUIAuras (Modern Virtual Buff & Debuff Grid)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Replaces Blizzard's legacy 2006 BuffFrame with a sleek, customizable aura grid
    featuring live duration countdowns, weapon enchant tracking, dispel borders,
    right-click buff cancellation, and native Mover integration.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIAuras = Primus.PUIAuras or {}
Primus.PUIAuras = PUIAuras
_G.PUIAuras = PUIAuras
Primus:RegisterModule("PUIAuras", PUIAuras, "HUD")

local DB      = Primus.DB
local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Time    = Primus.Time
local PUIMover = Primus.PUIMover
local Auras   = Primus.PUICombatAuras
local Console = Primus.Console

local aurasDB = DB:RegisterNamespace("PUIAuras", {
    iconSize = 30,
    spacing = 4,
    buffsPerRow = 8,
    growthDirection = "LEFT", -- LEFT or RIGHT
})

local auraButtons = {}
local containerFrame = nil
local maxAuraSlots = 32

-- Format remaining duration (seconds to string)
local function FormatDuration(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- Create an individual aura slot button
local function CreateAuraButton(index, parent)
    local size = aurasDB:Get("iconSize", 30) or 30
    local btn = CreateFrame("Button", "Primus_PUIAuraBtn_" .. index, parent)
    btn:SetWidth(size)
    btn:SetHeight(size)
    btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
    btn:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    btn:RegisterForClicks("RightButtonUp")
    btn:Hide()

    -- Icon texture
    local icon = btn:CreateTexture(nil, "BORDER")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    -- Duration text
    local duration = btn:CreateFontString(nil, "OVERLAY")
    duration:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    duration:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    duration:SetTextColor(1, 1, 0.4)
    btn.duration = duration

    -- Stack count
    local count = btn:CreateFontString(nil, "OVERLAY")
    count:SetFont(Media:Fetch("font", "Default"), 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    count:SetTextColor(1, 1, 1)
    btn.count = count

    -- Tooltip & Cancel interaction
    btn:SetScript("OnEnter", function()
        if btn.buffIndex then
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetPlayerBuff(btn.buffIndex)
        elseif btn.isWeaponEnchant then
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetInventoryItem("player", btn.weaponSlot)
        end
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" and btn.buffIndex and not btn.isDebuff then
            CancelPlayerBuff(btn.buffIndex)
        end
    end)

    auraButtons[index] = btn
    return btn
end

-- Refresh and update all player aura icons
function PUIAuras:UpdateAuras()
    if not containerFrame then return end

    local size = aurasDB:Get("iconSize", 30) or 30
    local spacing = aurasDB:Get("spacing", 4) or 4
    local perRow = aurasDB:Get("buffsPerRow", 8) or 8
    local activeSlot = 0

    -- 1. Check Temporary Weapon Enchants (Main Hand & Off Hand)
    local hasMainHand, mainHandExp, _, hasOffHand, offHandExp = GetWeaponEnchantInfo()

    if hasMainHand then
        activeSlot = activeSlot + 1
        local btn = auraButtons[activeSlot] or CreateAuraButton(activeSlot, containerFrame)
        btn.buffIndex = nil
        btn.isDebuff = false
        btn.isWeaponEnchant = true
        btn.weaponSlot = 16
        btn.icon:SetTexture(GetInventoryItemTexture("player", 16) or "Interface\\Icons\\INV_Sword_04")
        btn.duration:SetText(FormatDuration((mainHandExp or 0) / 1000))
        btn.count:SetText("")
        btn:SetBackdropBorderColor(0.8, 0.4, 0.0, 1) -- Orange border for weapon buff
        btn:Show()
    end

    if hasOffHand then
        activeSlot = activeSlot + 1
        local btn = auraButtons[activeSlot] or CreateAuraButton(activeSlot, containerFrame)
        btn.buffIndex = nil
        btn.isDebuff = false
        btn.isWeaponEnchant = true
        btn.weaponSlot = 17
        btn.icon:SetTexture(GetInventoryItemTexture("player", 17) or "Interface\\Icons\\INV_Sword_04")
        btn.duration:SetText(FormatDuration((offHandExp or 0) / 1000))
        btn.count:SetText("")
        btn:SetBackdropBorderColor(0.8, 0.4, 0.0, 1)
        btn:Show()
    end

    -- 2. Check Player Buffs
    for i = 0, 31 do
        local buffIndex, untilCancelled = GetPlayerBuff(i, "HELPFUL")
        if buffIndex > -1 then
            activeSlot = activeSlot + 1
            local btn = auraButtons[activeSlot] or CreateAuraButton(activeSlot, containerFrame)
            btn.buffIndex = buffIndex
            btn.isDebuff = false
            btn.isWeaponEnchant = false

            local texture = GetPlayerBuffTexture(buffIndex)
            local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
            local stacks = GetPlayerBuffApplications(buffIndex)

            btn.icon:SetTexture(texture)
            btn.duration:SetText(FormatDuration(timeLeft))
            btn.count:SetText((stacks and stacks > 1) and tostring(stacks) or "")
            btn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
            btn:Show()
        end
    end

    -- 3. Check Player Debuffs
    for i = 0, 15 do
        local debuffIndex = GetPlayerBuff(i, "HARMFUL")
        if debuffIndex > -1 then
            activeSlot = activeSlot + 1
            local btn = auraButtons[activeSlot] or CreateAuraButton(activeSlot, containerFrame)
            btn.buffIndex = debuffIndex
            btn.isDebuff = true
            btn.isWeaponEnchant = false

            local texture = GetPlayerBuffTexture(debuffIndex)
            local timeLeft = GetPlayerBuffTimeLeft(debuffIndex)
            local stacks = GetPlayerBuffApplications(debuffIndex)
            local debuffType = GetPlayerBuffDispelType(debuffIndex) or "None"

            btn.icon:SetTexture(texture)
            btn.duration:SetText(FormatDuration(timeLeft))
            btn.count:SetText((stacks and stacks > 1) and tostring(stacks) or "")

            local color = Auras and Auras.DispelColors and (Auras.DispelColors[debuffType] or Auras.DispelColors["None"]) or { r = 0.8, g = 0.2, b = 0.2 }
            btn:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            btn:Show()
        end
    end

    -- Hide remaining unused buttons
    for i = activeSlot + 1, maxAuraSlots do
        if auraButtons[i] then
            auraButtons[i]:Hide()
        end
    end

    -- Arrange visible buttons in grid
    for i = 1, activeSlot do
        local btn = auraButtons[i]
        local row = math.floor((i - 1) / perRow)
        local col = Utils.Mod(i - 1, perRow)

        btn:ClearAllPoints()
        local xOfs = -(col * (size + spacing))
        local yOfs = -(row * (size + spacing + 14))
        btn:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", xOfs, yOfs)
    end
end

function PUIAuras:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIAuras", {
        name = "PUIAuras",
        category = "HUD",
        label = "Auras & Buffs",
        icon = "Interface\Icons\Spell_Holy_AuraMastery",
        desc = "Modern player buff, debuff, and weapon enchant display with duration sweeps.",
    })
end

function PUIAuras:OnInitialize()
    self:RegisterOptionsFlare()
    -- 1. Cleanly disable Blizzard's legacy Buff frames
    if BuffFrame then
        BuffFrame:Hide()
        BuffFrame:UnregisterAllEvents()
    end
    if TemporaryEnchantFrame then
        TemporaryEnchantFrame:Hide()
        TemporaryEnchantFrame:UnregisterAllEvents()
    end

    -- 2. Create Master Primus PUIAuras Container Frame
    containerFrame = CreateFrame("Frame", "Primus_PUIAuras", UIParent)
    containerFrame:SetWidth(280)
    containerFrame:SetHeight(120)
    containerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -13)
    containerFrame:SetMovable(true)

    -- Register with PUIMover
    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(containerFrame, "PUIAuras", "PUIAuras: Buff & Debuff Grid", "HUD")
    end

    -- 3. Register Events & Update Tickers
    Events:Register("PLAYER_AURAS_CHANGED", self, function()
        PUIAuras:UpdateAuras()
    end)

    -- 1-second ticker for smooth duration countdowns
    Time:Every(1.0, function()
        PUIAuras:UpdateAuras()
    end)

    -- Subcommand registration via Console Router
    if Console and Console.RegisterSubCommand then
        Console:RegisterSubCommand("auras", function()
            local mover = PUIMover or Primus.PUIMover
            if mover and mover.Unlock then mover:Unlock("HUD") end
        end, "PUIAuras buff & debuff tracker (/pui auras)")
    end

    -- Initial render
    self:UpdateAuras()
end
