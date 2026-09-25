--[[
    PrimusUI Module: PUIHud - Central Triage Array & Heal Flash
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides tactical situational awareness:
    - Top Pins: Real-time MT1, MT2, MA vitals and 1-click targeting
    - Heal Flash: Emerald green peripheral pulse and toast on incoming heals
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIHud = Primus.PUIHud or {}
Primus.PUIHud = PUIHud

local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils
local DB      = Primus.DB
local Anim    = Primus.Anim

local triageContainer = nil
local triageTopPins   = {}
local healFlashFrame  = nil

-- =========================================================================
-- TRIAGE ARRAY BUILDER
-- =========================================================================

function PUIHud:BuildTriage(parent)
    local hudDB = DB:GetNamespace("PUIHud")
    local gap = hudDB and hudDB:Get("centerGap", 120) or 120

    -- 1. Triage Container
    triageContainer = CreateFrame("Frame", "Primus_PUIHud_TriageArray", parent)
    triageContainer:SetWidth(gap)
    triageContainer:SetHeight(70)
    triageContainer:SetPoint("TOP", parent, "TOP", 0, -10)
    triageContainer:EnableMouse(false)

    -- 2. Top Pins (MT1, MT2, MA)
    for i = 1, 3 do
        local pin = CreateFrame("Button", "Primus_PUIHud_TriagePin_" .. i, triageContainer)
        pin:SetWidth(gap / 3 - 2)
        pin:SetHeight(16)
        pin:SetPoint("TOPLEFT", triageContainer, "TOPLEFT", (i - 1) * (gap / 3 + 1), 0)
        pin:SetBackdrop(Media:Fetch("border", "1Pixel"))
        pin:SetBackdropColor(0.10, 0.15, 0.20, 0.80)
        pin:SetBackdropBorderColor(0.30, 0.60, 0.90, 0.90)

        local pinBar = Widgets:CreateStatusBar(pin, gap / 3 - 4, 12, 0, 100)
        pinBar:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pinBar:SetStatusBarColor(0.20, 0.70, 0.30, 1.0)
        pin.bar = pinBar

        local pText = pinBar:CreateFontString(nil, "OVERLAY")
        pText:SetFont(Media:Fetch("font", "Default"), 7, "OUTLINE")
        pText:SetPoint("CENTER", pinBar, "CENTER", 0, 0)
        pText:SetTextColor(1, 1, 1)
        pin.text = pText

        pin:RegisterForClicks("LeftButtonUp")
        pin:SetScript("OnClick", function()
            if this.unit and UnitExists(this.unit) then
                TargetUnit(this.unit)
            end
        end)
        pin:Hide()
        triageTopPins[i] = pin
    end

    -- 3. Reassurance Emerald Green Flash Frame
    healFlashFrame = CreateFrame("Frame", "Primus_PUIHud_HealFlash", parent)
    healFlashFrame:SetWidth(gap + 80)
    healFlashFrame:SetHeight(26)
    healFlashFrame:SetPoint("CENTER", parent, "CENTER", 0, 20)
    healFlashFrame:SetBackdrop(Media:Fetch("border", "1Pixel"))
    healFlashFrame:SetBackdropColor(0.10, 0.75, 0.25, 0.85)
    healFlashFrame:SetBackdropBorderColor(0.30, 1.00, 0.40, 1.0)

    local hfText = healFlashFrame:CreateFontString(nil, "OVERLAY")
    hfText:SetFont(Media:Fetch("font", "Default"), 9, "OUTLINE")
    hfText:SetPoint("CENTER", healFlashFrame, "CENTER", 0, 0)
    hfText:SetTextColor(1, 1, 1)
    healFlashFrame.text = hfText
    healFlashFrame:Hide()

    self.triageContainer = triageContainer
    self.triageTopPins   = triageTopPins
    self.healFlashFrame  = healFlashFrame
end

-- =========================================================================
-- TRIAGE ARRAY UPDATES
-- =========================================================================

function PUIHud:UpdateTriageArray()
    local hudDB = DB:GetNamespace("PUIHud")
    if not triageContainer or (hudDB and not hudDB:Get("showTriageArray", true)) then
        if triageContainer then triageContainer:Hide() end
        return
    else
        triageContainer:Show()
    end

    local pinIndex = 0
    local raidMembers = GetNumRaidMembers()

    if raidMembers > 0 then
        for i = 1, raidMembers do
            local rName, rank, subgroup, level, class, fileName, zone, online, isDead, role = GetRaidRosterInfo(i)
            if role == "MAINTANK" or role == "MAINASSIST" then
                pinIndex = pinIndex + 1
                local pin = triageTopPins[pinIndex]
                if pin then
                    local unit = "raid" .. i
                    local curHP, maxHP, pctHP = Utils.GetUnitHealth(unit)
                    pin.unit = unit
                    pin.bar:SetMinMaxValues(0, maxHP)
                    pin.bar:SetValue(curHP)
                    pin.text:SetText(string.format("%s %d%%", string.sub(rName or "Tank", 1, 8), pctHP))
                    pin:Show()
                end
            end
            if pinIndex >= 3 then break end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            pinIndex = pinIndex + 1
            local pin = triageTopPins[pinIndex]
            if pin then
                local unit = "party" .. i
                local curHP, maxHP, pctHP = Utils.GetUnitHealth(unit)
                local pName = UnitName(unit) or ("Party" .. i)
                pin.unit = unit
                pin.bar:SetMinMaxValues(0, maxHP)
                pin.bar:SetValue(curHP)
                pin.text:SetText(string.format("%s %d%%", string.sub(pName, 1, 8), pctHP))
                pin:Show()
            end
            if pinIndex >= 3 then break end
        end
    end

    for j = pinIndex + 1, 3 do
        if triageTopPins[j] then triageTopPins[j]:Hide() end
    end
end

-- =========================================================================
-- HEAL REASSURANCE FLASH
-- =========================================================================

function PUIHud:FlashIncomingHeal(healerName, spellName)
    if not healFlashFrame then return end
    healFlashFrame.text:SetText(string.format("|cff33ff33✨ Incoming Heal:|r %s from %s", spellName or "Heal", healerName or "Healer"))
    healFlashFrame:SetAlpha(1.0)
    healFlashFrame:Show()

    if Anim and Anim.Fade then
        Anim:Fade(healFlashFrame, 1.2, 1.0, 0.0)
    else
        -- Fallback hide
        healFlashFrame:Hide()
    end
end
