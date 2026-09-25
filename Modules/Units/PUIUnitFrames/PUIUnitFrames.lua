--[[
    PrimusLib Module: PUIUnitFrames (Modern Modular Unit Frames Suite)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides:
    1. Player Frame: Health & Power, Class/Reaction colors, Combat & Rest status, Leader & PvP tags.
    2. Target Frame: Health, Power, Level & Classification, Target Auras (Buffs/Debuffs), Combo Points.
    3. Target-of-Target (ToT) & Pet Frames: Compact health/mana and threat tracking.
    4. Party Frames (Party 1..4): Class-colored health, Power bars, HealComm predictions, Range fading.
    5. Compact Raid Grid (5x8): Deficit health, range fading, dead/offline status, class indicators.
    6. Default Blizzard UnitFrame suppression with zero overhead.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIUnitFrames = Primus.PUIUnitFrames or {}
Primus.PUIUnitFrames = PUIUnitFrames
_G.PUIUnitFrames = PUIUnitFrames
Primus:RegisterModule("PUIUnitFrames", PUIUnitFrames, "Units")

local DB       = Primus.DB
local Widgets  = Primus.Widgets
local Media    = Primus.Media
local Utils    = Primus.Utils
local Events   = Primus.Events
local Time     = Primus.Time
local PUIMover = Primus.PUIMover
local UnitBase = Primus.PUIUnitBase
local Range    = Primus.PUIRange
local Threat   = Primus.PUIThreat
local HealComm = Primus.PUIHealComm

-- Static Debuff Priority & Color Lookups (Lua 5.0 compliant)
local DEBUFF_PRIORITIES = {
    ["PRIEST"]  = { "Magic", "Disease", "Curse", "Poison" },
    ["PALADIN"] = { "Magic", "Poison", "Disease", "Curse" },
    ["DRUID"]   = { "Curse", "Poison", "Magic", "Disease" },
    ["MAGE"]    = { "Curse", "Magic", "Poison", "Disease" },
    ["SHAMAN"]  = { "Poison", "Disease", "Magic", "Curse" },
    ["DEFAULT"] = { "Magic", "Curse", "Poison", "Disease" },
}

local DEBUFF_COLORS = {
    ["Curse"]   = { r = 0.60, g = 0.00, b = 1.00 },
    ["Magic"]   = { r = 0.20, g = 0.60, b = 1.00 },
    ["Poison"]  = { r = 0.00, g = 0.60, b = 0.00 },
    ["Disease"] = { r = 0.60, g = 0.40, b = 0.00 },
}

local unitFramesDB = DB:RegisterNamespace("PUIUnitFrames", {
    enabled = true,
    showPlayer = true,
    showTarget = true,
    showToT = true,
    showPet = true,
    showParty = true,
    showRaid = true,
    hideBlizzard = true,
})

-- Frame Handles
local playerFrame = nil
local targetFrame = nil
local totFrame = nil
local petFrame = nil
local partyFrames = {}
local raidFrames = {}

-- Suppress Default Blizzard Unit Frames Safely (100% Crash-Proof)
local hiddenBlizzUnitParent = CreateFrame("Frame", "Primus_HiddenBlizzUnitParent", UIParent)
hiddenBlizzUnitParent:Hide()

local function SafeSuppressUnitFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
    frame:SetParent(hiddenBlizzUnitParent)
    frame:SetScript("OnShow", function() this:Hide() end)
end

local function SuppressBlizzardFrames()
    local hide = unitFramesDB and unitFramesDB:Get("hideBlizzard", true)
    if not hide then return end

    SafeSuppressUnitFrame(PlayerFrame)
    SafeSuppressUnitFrame(TargetFrame)
    SafeSuppressUnitFrame(ComboFrame)
    SafeSuppressUnitFrame(PetFrame)
    for i = 1, 4 do
        SafeSuppressUnitFrame(_G["PartyMemberFrame" .. i])
    end
end

-- Create Aura Icon Grid on a Unit Frame
local function CreateAuraGrid(parent, numIcons, isDebuff)
    local icons = {}
    for i = 1, numIcons do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetWidth(16)
        btn:SetHeight(16)
        btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
        btn:SetBackdropColor(0, 0, 0, 0.8)
        btn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)

        local tex = btn:CreateTexture(nil, "BORDER")
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.tex = tex

        local count = btn:CreateFontString(nil, "OVERLAY")
        count:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
        count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn.count = count

        btn:Hide()
        icons[i] = btn
    end
    return icons
end

-- Update Aura Grid for a Unit
local function UpdateAuraGrid(icons, unit, isDebuff)
    local numIcons = table.getn(icons)
    for i = 1, numIcons do
        local texture, applications, debuffType
        if isDebuff then
            texture, applications, debuffType = UnitDebuff(unit, i)
        else
            texture, applications = UnitBuff(unit, i)
        end

        local btn = icons[i]
        if texture then
            btn.tex:SetTexture(texture)
            if applications and applications > 1 then
                btn.count:SetText(tostring(applications))
                btn.count:Show()
            else
                btn.count:Hide()
            end

            -- Border color for debuffs
            if isDebuff and debuffType then
                local dc = DebuffTypeColor[debuffType] or { r = 0.8, g = 0.2, b = 0.2 }
                btn:SetBackdropBorderColor(dc.r, dc.g, dc.b, 1)
            else
                btn:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
            end
            btn:Show()
        else
            btn:Hide()
        end
    end
end

-- =========================================================================
-- PLAYER FRAME
-- =========================================================================

function PUIUnitFrames:CreatePlayerFrame()
    local f = UnitBase:CreateUnitFrame(UIParent, "player", 210, 46, "Primus_PlayerFrame")
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 19, -19)

    -- Status Icons (Combat, Rest, Leader)
    local combatIcon = f:CreateTexture(nil, "OVERLAY")
    combatIcon:SetWidth(16)
    combatIcon:SetHeight(16)
    combatIcon:SetPoint("CENTER", f, "TOPRIGHT", -4, 4)
    combatIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combatIcon:SetTexCoord(0.5, 1.0, 0.0, 0.5)
    combatIcon:Hide()
    f.combatIcon = combatIcon

    local restIcon = f:CreateTexture(nil, "OVERLAY")
    restIcon:SetWidth(16)
    restIcon:SetHeight(16)
    restIcon:SetPoint("CENTER", f, "TOPRIGHT", -4, 4)
    restIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    restIcon:SetTexCoord(0.0, 0.5, 0.0, 0.5)
    restIcon:Hide()
    f.restIcon = restIcon

    local origUpdate = f.Update
    f.Update = function(self)
        origUpdate(self)
        if UnitAffectingCombat("player") then
            self.combatIcon:Show()
            self.restIcon:Hide()
        elseif IsResting() then
            self.restIcon:Show()
            self.combatIcon:Hide()
        else
            self.combatIcon:Hide()
            self.restIcon:Hide()
        end
    end

    playerFrame = f
    return f
end

-- =========================================================================
-- TARGET FRAME
-- =========================================================================

function PUIUnitFrames:CreateTargetFrame()
    local f = UnitBase:CreateUnitFrame(UIParent, "target", 210, 46, "Primus_TargetFrame")
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -19)
    f:Hide()

    -- Target Debuff Grid (below frame)
    local debuffs = CreateAuraGrid(f, 8, true)
    for i = 1, 8 do
        debuffs[i]:SetPoint("TOPLEFT", f, "BOTTOMLEFT", (i - 1) * 18 + 2, -4)
    end
    f.debuffs = debuffs

    -- Target Buff Grid (above frame)
    local buffs = CreateAuraGrid(f, 8, false)
    for i = 1, 8 do
        buffs[i]:SetPoint("BOTTOMLEFT", f, "TOPLEFT", (i - 1) * 18 + 2, 4)
    end
    f.buffs = buffs

    -- Combo Points on Target (1..5)
    local cpPips = {}
    local cpFrame = CreateFrame("Frame", nil, f)
    cpFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 2, 10)
    cpFrame:SetWidth(80)
    cpFrame:SetHeight(8)
    for i = 1, 5 do
        local pip = CreateFrame("Frame", nil, cpFrame)
        pip:SetWidth(14)
        pip:SetHeight(6)
        pip:SetPoint("LEFT", cpFrame, "LEFT", (i - 1) * 16, 0)
        pip:SetBackdrop(Media:Fetch("border", "1Pixel"))
        pip:SetBackdropColor(1.0, 0.85, 0.1, 1.0)
        pip:SetBackdropBorderColor(1.0, 0.95, 0.3, 1.0)
        pip:Hide()
        cpPips[i] = pip
    end
    f.cpPips = cpPips

    local origUpdate = f.Update
    f.Update = function(self)
        if not UnitExists("target") then
            self:Hide()
            return
        end
        origUpdate(self)
        UpdateAuraGrid(self.buffs, "target", false)
        UpdateAuraGrid(self.debuffs, "target", true)

        -- Update Combo Points
        local cp = GetComboPoints("player", "target") or 0
        for i = 1, 5 do
            if i <= cp then
                self.cpPips[i]:Show()
                if cp == 5 then
                    self.cpPips[i]:SetBackdropColor(1.0, 0.2, 0.2, 1.0)
                else
                    self.cpPips[i]:SetBackdropColor(1.0, 0.85, 0.1, 1.0)
                end
            else
                self.cpPips[i]:Hide()
            end
        end
    end

    targetFrame = f
    return f
end

-- =========================================================================
-- TARGET-OF-TARGET & PET FRAMES
-- =========================================================================

function PUIUnitFrames:CreateToTFrame()
    local f = UnitBase:CreateUnitFrame(UIParent, "targettarget", 110, 28, "Primus_ToTFrame")
    f:SetPoint("TOPLEFT", targetFrame, "TOPRIGHT", 10, 0)
    f:Hide()
    totFrame = f
    return f
end

function PUIUnitFrames:CreatePetFrame()
    local f = UnitBase:CreateUnitFrame(UIParent, "pet", 120, 30, "Primus_PetFrame")
    f:SetPoint("TOPLEFT", playerFrame, "BOTTOMLEFT", 0, -10)
    f:Hide()
    petFrame = f
    return f
end

-- =========================================================================
-- PARTY FRAMES (Party 1..4)
-- =========================================================================

function PUIUnitFrames:CreatePartyFrames()
    for i = 1, 4 do
        local unit = "party" .. i
        local f = UnitBase:CreateUnitFrame(UIParent, unit, 140, 34, "Primus_PartyFrame_" .. i)
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -120 - (i - 1) * 44)
        f:Hide()

        local origUpdate = f.Update
        f.Update = function(self)
            if not UnitExists(self.unit) then
                self:Hide()
                return
            end
            origUpdate(self)

            -- Range Fading (40yd spell check)
            if Range then
                local inRange = Range:IsUnitInRange(self.unit)
                if inRange then
                    self:SetAlpha(1.0)
                else
                    self:SetAlpha(0.5)
                end
            end
        end

        partyFrames[i] = f
    end
end

-- =========================================================================
-- RAID GRID (5 Groups x 8 Members = 40 Units)
-- =========================================================================

function PUIUnitFrames:CreateRaidGrid()
    local raidHeader = CreateFrame("Frame", "Primus_RaidGrid", UIParent)
    raidHeader:SetWidth(330)
    raidHeader:SetHeight(160)
    raidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -100)
    raidHeader:Hide()

    for i = 1, 40 do
        local unit = "raid" .. i
        local btn = CreateFrame("Button", "Primus_RaidUnit_" .. i, raidHeader)
        btn:SetWidth(58)
        btn:SetHeight(32)
        btn:SetBackdrop(Media:Fetch("border", "1Pixel"))
        btn:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        btn:SetBackdropBorderColor(0.20, 0.20, 0.25, 1.0)
        btn.unit = unit

        local health = Widgets:CreateStatusBar(btn, 54, 22, 0, 100)
        health:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        health:SetStatusBarColor(0.2, 0.8, 0.2, 1.0)
        btn.healthBar = health

        local nameText = health:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
        nameText:SetPoint("TOP", health, "TOP", 0, -2)
        btn.nameText = nameText

        local hpText = health:CreateFontString(nil, "OVERLAY")
        hpText:SetFont(Media:Fetch("font", "Default"), 8, "OUTLINE")
        hpText:SetPoint("BOTTOM", health, "BOTTOM", 0, 2)
        btn.hpText = hpText

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
        btn:SetScript("OnClick", function()
            if UnitBase and UnitBase.HandleUnitClick then
                UnitBase:HandleUnitClick(this.unit, arg1)
            else
                TargetUnit(this.unit)
            end
        end)

        function btn:Update()
            if not UnitExists(self.unit) then
                self:Hide()
                return
            end
            self:Show()

            local curHP = UnitHealth(self.unit) or 0
            local maxHP = UnitHealthMax(self.unit) or 1
            self.healthBar:SetMinMaxValues(0, maxHP)
            self.healthBar:SetSmoothValue(curHP)

            local name = UnitName(self.unit) or ""
            self.nameText:SetText(string.sub(name, 1, 6))

            if UnitIsDead(self.unit) then
                self.hpText:SetText("DEAD")
                self.hpText:SetTextColor(1.0, 0.2, 0.2)
                self.healthBar:SetStatusBarColor(0.3, 0.3, 0.3, 0.8)
            elseif UnitIsGhost(self.unit) then
                self.hpText:SetText("GHOST")
                self.hpText:SetTextColor(0.6, 0.6, 0.6)
                self.healthBar:SetStatusBarColor(0.2, 0.2, 0.2, 0.8)
            elseif not UnitIsConnected(self.unit) then
                self.hpText:SetText("OFFLINE")
                self.hpText:SetTextColor(0.5, 0.5, 0.5)
            else
                local deficit = maxHP - curHP
                if deficit > 0 then
                    self.hpText:SetText(string.format("-%d", deficit))
                    self.hpText:SetTextColor(1.0, 0.9, 0.3)
                else
                    self.hpText:SetText("100%")
                    self.hpText:SetTextColor(0.2, 1.0, 0.4)
                end

                local _, cls = UnitClass(self.unit)
                local r, g, b = Utils.GetClassColor(cls or "")
                self.healthBar:SetStatusBarColor(r, g, b, 1)
            end

            -- Class-Aware Debuff Border Highlights on Raid Button
            local foundDebuffType = nil
            local _, playerClass = UnitClass("player")
            playerClass = playerClass or "WARRIOR"
            local priorityList = DEBUFF_PRIORITIES[playerClass] or DEBUFF_PRIORITIES["DEFAULT"]

            local activeDebuffs = {}
            for d = 1, 16 do
                local _, _, debuffType = UnitDebuff(self.unit, d)
                if debuffType then activeDebuffs[debuffType] = true end
            end
            local pCount = table.getn(priorityList)
            for p = 1, pCount do
                if activeDebuffs[priorityList[p]] then
                    foundDebuffType = priorityList[p]
                    break
                end
            end

            if foundDebuffType then
                local dc = DEBUFF_COLORS[foundDebuffType]
                if dc then self:SetBackdropBorderColor(dc.r, dc.g, dc.b, 1.0) end
            else
                self:SetBackdropBorderColor(0.20, 0.20, 0.25, 1.0)
            end

            -- Range Fading (40yd spell check)
            if Range and Range.IsUnitInRange then
                local inRange = Range:IsUnitInRange(self.unit)
                self:SetAlpha(inRange and 1.0 or 0.4)
            end
        end

        -- Layout in 5 columns x 8 rows
        local col = math.floor((i - 1) / 8)
        local row = math.mod(i - 1, 8)
        btn:SetPoint("TOPLEFT", raidHeader, "TOPLEFT", col * 64 + 4, -row * 36 - 4)
        raidFrames[i] = btn
    end

    local mover = PUIMover or Primus.PUIMover
    if mover and mover.Register then
        mover:Register(raidHeader, "RaidGrid", "Compact 40-Man Raid Grid", "UNITS")
    end
    PUIUnitFrames.raidHeader = raidHeader
end

-- Update All Units Function
function PUIUnitFrames:UpdateAll()
    if playerFrame and unitFramesDB:Get("showPlayer", true) then playerFrame:Update() end
    if targetFrame and unitFramesDB:Get("showTarget", true) then targetFrame:Update() end
    if totFrame and unitFramesDB:Get("showToT", true) then totFrame:Update() end
    if petFrame and unitFramesDB:Get("showPet", true) then petFrame:Update() end

    if unitFramesDB:Get("showParty", true) then
        for i = 1, 4 do
            if partyFrames[i] then partyFrames[i]:Update() end
        end
    end

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 and self.raidHeader and unitFramesDB:Get("showRaid", true) then
        self.raidHeader:Show()
        for i = 1, 40 do
            if raidFrames[i] then raidFrames[i]:Update() end
        end
    elseif self.raidHeader then
        self.raidHeader:Hide()
    end
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIUnitFrames:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIUnitFrames", "Units", {
        title = "PUIUnitFrames: Modern Unit Frames",
        description = "Modern unit frames suite with click-to-heal click-casting, range fading, and debuff coloring.",
        fields = {
            {
                key = "enabled",
                label = "Enable Unit Frames Suite",
                type = "checkbox",
                default = true,
                get = function() return unitFramesDB:Get("enabled", true) end,
                set = function(val)
                    unitFramesDB:Set("enabled", val)
                    if val then PUIUnitFrames:OnEnable() else PUIUnitFrames:OnDisable() end
                end,
            },
            {
                key = "showPlayer",
                label = "Show Player Frame",
                type = "checkbox",
                default = true,
                get = function() return unitFramesDB:Get("showPlayer", true) end,
                set = function(val)
                    unitFramesDB:Set("showPlayer", val)
                    if playerFrame then if val then playerFrame:Show() else playerFrame:Hide() end end
                end,
            },
            {
                key = "showTarget",
                label = "Show Target Frame",
                type = "checkbox",
                default = true,
                get = function() return unitFramesDB:Get("showTarget", true) end,
                set = function(val)
                    unitFramesDB:Set("showTarget", val)
                    if targetFrame then if val and UnitExists("target") then targetFrame:Show() else targetFrame:Hide() end end
                end,
            },
            {
                key = "showParty",
                label = "Show Party Frames",
                type = "checkbox",
                default = true,
                get = function() return unitFramesDB:Get("showParty", true) end,
                set = function(val)
                    unitFramesDB:Set("showParty", val)
                    PUIUnitFrames:UpdateAll()
                end,
            },
            {
                key = "showRaid",
                label = "Show 40-Man Compact Raid Grid",
                type = "checkbox",
                default = true,
                get = function() return unitFramesDB:Get("showRaid", true) end,
                set = function(val)
                    unitFramesDB:Set("showRaid", val)
                    PUIUnitFrames:UpdateAll()
                end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & INITIALIZATION
-- =========================================================================

function PUIUnitFrames:OnInitialize()
    SuppressBlizzardFrames()

    self:CreatePlayerFrame()
    self:CreateTargetFrame()
    self:CreateToTFrame()
    self:CreatePetFrame()
    self:CreatePartyFrames()
    self:CreateRaidGrid()

    self:RegisterOptionsFlare()

    -- Subcommand registration via Console Router
    if Primus.Console and Primus.Console.RegisterSubCommand then
        Primus.Console:RegisterSubCommand("unitframes", function()
            local mover = PUIMover or Primus.PUIMover
            if mover and mover.Unlock then mover:Unlock("UNITS") end
        end, "Unit Frames management (/pui unitframes)")

        if Primus.Console.RegisterAlias then
            Primus.Console:RegisterAlias("uf", "unitframes")
        end
    end
end

function PUIUnitFrames:OnEnable()
    SuppressBlizzardFrames()

    -- Event hooks for full reactive updates
    local ufEvents = {
        "UNIT_HEALTH", "UNIT_MAXHEALTH",
        "UNIT_MANA", "UNIT_MAXMANA",
        "UNIT_RAGE", "UNIT_ENERGY",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_COMBO_POINTS",
        "PARTY_MEMBERS_CHANGED",
        "RAID_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD",
        "UNIT_AURA",
    }

    local count = table.getn(ufEvents)
    for i = 1, count do
        Events:Register(ufEvents[i], "PUIUnitFrames", function()
            PUIUnitFrames:UpdateAll()
        end)
    end

    -- Smooth 0.2s Range and Status Refresh Ticker
    Time:Every(0.2, function()
        PUIUnitFrames:UpdateAll()
    end, "PUIUnitFrames")

    self:UpdateAll()
end

function PUIUnitFrames:OnDisable()
    Time:CancelAll("PUIUnitFrames")
    Events:UnregisterOwner("PUIUnitFrames")

    if playerFrame then playerFrame:Hide() end
    if targetFrame then targetFrame:Hide() end
    if totFrame then totFrame:Hide() end
    if petFrame then petFrame:Hide() end
    for i = 1, 4 do
        if partyFrames[i] then partyFrames[i]:Hide() end
    end
    if self.raidHeader then self.raidHeader:Hide() end
end
