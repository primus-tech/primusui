--[[
    PrimusUI: PUIRoleplay Profile Sheet & Editor (PUIRPSheet.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (PrimusUI Dark Design System)
--]]

local Primus = _G.Primus
local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Sheet = {}
PUIRoleplay.Sheet = Sheet

local sheetFrame = nil
local activeTab = 1
local targetPlayerName = nil
local isViewingSelf = true
local currentEditingGlance = 1

--------------------------------------------------------------------------------
-- UI Creation Helpers
--------------------------------------------------------------------------------
local function Create1PxBackdrop(parent, r, g, b, a, borderR, borderG, borderB, borderA)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(r or 0.08, g or 0.08, b or 0.10, a or 0.95)
    frame:SetBackdropBorderColor(borderR or 0.25, borderG or 0.25, borderB or 0.28, borderA or 1.0)
    return frame
end

local function CreateStyledEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetWidth(width)
    eb:SetHeight(height)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlight)
    eb:SetTextColor(1.0, 1.0, 1.0, 1.0)
    eb:SetTextInsets(6, 6, 2, 2)
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    eb:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    eb:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)
    
    eb:SetScript("OnEditFocusGained", function()
        this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        this:SetBackdropColor(0.10, 0.10, 0.14, 1.0)
    end)
    eb:SetScript("OnEditFocusLost", function()
        this:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)
        this:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    end)
    eb:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    return eb
end

--------------------------------------------------------------------------------
-- Master Profile Sheet Frame Construction
--------------------------------------------------------------------------------
function Sheet:BuildFrame()
    if sheetFrame then return sheetFrame end
    
    local f = CreateFrame("Frame", "Primus_PUIRoleplay_Sheet", UIParent)
    f:SetWidth(450)
    f:SetHeight(560)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    f:SetBackdropColor(0.07, 0.07, 0.09, 0.96)
    f:SetBackdropBorderColor(0.22, 0.22, 0.26, 1.0)
    table.insert(UISpecialFrames, "Primus_PUIRoleplay_Sheet")
    
    -- Title Bar / Header
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    titleBar:SetBackdropColor(0.12, 0.12, 0.15, 1.0)
    
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cff00ccffPRIMUS|r |cffffffffROLEPLAY PROFILE|r")
    
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    -- Character Summary Header Area
    local headerArea = CreateFrame("Frame", nil, f)
    headerArea:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    headerArea:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -36)
    headerArea:SetHeight(74)
    
    local iconBtn = CreateFrame("Button", nil, headerArea)
    iconBtn:SetWidth(48)
    iconBtn:SetHeight(48)
    iconBtn:SetPoint("TOPLEFT", headerArea, "TOPLEFT", 4, -4)
    iconBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    iconBtn:SetBackdropColor(0, 0, 0, 1)
    iconBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    
    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconBtn, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    iconBtn.tex = iconTex
    iconBtn:SetScript("OnClick", function()
        if isViewingSelf then
            Sheet:OpenIconPicker(function(selectedIconIndex)
                local profile = PUIRoleplay:GetMyProfile()
                profile.icon = tostring(selectedIconIndex)
                profile.keyM = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(profile)
                Sheet:Refresh()
            end)
        end
    end)
    f.iconBtn = iconBtn
    
    -- Character Full Name EditBox/Text
    local nameEB = CreateStyledEditBox(headerArea, 220, 22)
    nameEB:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, 0)
    nameEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.full_name = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    f.nameEB = nameEB
    
    -- Title / Suffix EditBox
    local titleEB = CreateStyledEditBox(headerArea, 220, 20)
    titleEB:SetPoint("TOPLEFT", nameEB, "BOTTOMLEFT", 0, -4)
    titleEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.title = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    f.titleEB = titleEB
    
    -- Race & Class Label
    local raceClassText = headerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raceClassText:SetPoint("TOPLEFT", titleEB, "BOTTOMLEFT", 2, -4)
    raceClassText:SetText("Human Paladin")
    f.raceClassText = raceClassText
    
    -- IC / OOC Status Pill Toggle
    local icBtn = CreateFrame("Button", nil, headerArea)
    icBtn:SetWidth(68)
    icBtn:SetHeight(24)
    icBtn:SetPoint("TOPRIGHT", headerArea, "TOPRIGHT", -4, -4)
    icBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    
    local icText = icBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icText:SetPoint("CENTER", icBtn, "CENTER", 0, 0)
    icText:SetText("IC")
    icBtn.text = icText
    
    icBtn:SetScript("OnClick", function()
        if isViewingSelf then
            local curState = PUIRoleplay:GetICState()
            local newState = (curState == "1") and "0" or "1"
            PUIRoleplay:SetICState(newState)
            Sheet:Refresh()
        end
    end)
    f.icBtn = icBtn
    
    ----------------------------------------------------------------------------
    -- Tab Bar (General, Style, Biography, Notes/Profiles)
    ----------------------------------------------------------------------------
    local tabNames = { "General", "RP Style", "Biography", "Notes" }
    local tabs = {}
    for i = 1, 4 do
        local tab = CreateFrame("Button", nil, f)
        tab:SetWidth(104)
        tab:SetHeight(24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 108, -114)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 0 }
        })
        
        local tText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tText:SetPoint("CENTER", tab, "CENTER", 0, 0)
        tText:SetText(tabNames[i])
        tab.text = tText
        tab.index = i
        
        tab:SetScript("OnClick", function()
            Sheet:SelectTab(this.index)
        end)
        tabs[i] = tab
    end
    f.tabs = tabs
    
    -- Content Container
    local contentBox = Create1PxBackdrop(f, 0.05, 0.05, 0.07, 0.95, 0.22, 0.22, 0.26, 1.0)
    contentBox:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -138)
    contentBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    f.contentBox = contentBox
    
    ----------------------------------------------------------------------------
    -- Panel 1: General & At-A-Glance
    ----------------------------------------------------------------------------
    local p1 = CreateFrame("Frame", nil, contentBox)
    p1:SetAllPoints(contentBox)
    f.panel1 = p1
    
    -- Pronouns
    local prLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 12, -10)
    prLabel:SetText("|cff00e5ffPronouns (IC / OOC):|r")
    
    local icPrEB = CreateStyledEditBox(p1, 95, 20)
    icPrEB:SetPoint("TOPLEFT", prLabel, "BOTTOMLEFT", 0, -3)
    icPrEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.ic_pronouns = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    p1.icPrEB = icPrEB
    
    local oocPrEB = CreateStyledEditBox(p1, 95, 20)
    oocPrEB:SetPoint("LEFT", icPrEB, "RIGHT", 8, 0)
    oocPrEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.ooc_pronouns = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    p1.oocPrEB = oocPrEB
    
    -- IC Info
    local icInfoLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icInfoLabel:SetPoint("TOPLEFT", icPrEB, "BOTTOMLEFT", 0, -8)
    icInfoLabel:SetText("|cff55ff88IC Summary / Status:|r")
    
    local icInfoEB = CreateStyledEditBox(p1, 404, 20)
    icInfoEB:SetPoint("TOPLEFT", icInfoLabel, "BOTTOMLEFT", 0, -3)
    icInfoEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.ic_info = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    p1.icInfoEB = icInfoEB
    
    -- OOC Info
    local oocInfoLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oocInfoLabel:SetPoint("TOPLEFT", icInfoEB, "BOTTOMLEFT", 0, -8)
    oocInfoLabel:SetText("|cffff9933OOC Notes / Boundary Info:|r")
    
    local oocInfoEB = CreateStyledEditBox(p1, 404, 20)
    oocInfoEB:SetPoint("TOPLEFT", oocInfoLabel, "BOTTOMLEFT", 0, -3)
    oocInfoEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.ooc_info = this:GetText()
            profile.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    p1.oocInfoEB = oocInfoEB
    
    -- At-A-Glance Cards Section Header
    local glanceHeader = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glanceHeader:SetPoint("TOPLEFT", oocInfoEB, "BOTTOMLEFT", 0, -12)
    glanceHeader:SetText("|cffffd100AT A GLANCE (3 Visual Traits):|r")
    
    -- 3 Glance Cards
    p1.glanceCards = {}
    for i = 1, 3 do
        local card = Create1PxBackdrop(p1, 0.06, 0.06, 0.08, 0.95, 0.28, 0.28, 0.35, 1.0)
        card:SetWidth(404)
        card:SetHeight(52)
        card:SetPoint("TOPLEFT", glanceHeader, "BOTTOMLEFT", 0, -6 - (i - 1) * 58)
        
        local gBtn = CreateFrame("Button", nil, card)
        gBtn:SetWidth(38)
        gBtn:SetHeight(38)
        gBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -7)
        gBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        gBtn:SetBackdropColor(0, 0, 0, 1)
        gBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
        
        local gTex = gBtn:CreateTexture(nil, "ARTWORK")
        gTex:SetPoint("TOPLEFT", gBtn, "TOPLEFT", 1, -1)
        gTex:SetPoint("BOTTOMRIGHT", gBtn, "BOTTOMRIGHT", -1, 1)
        gTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        gBtn.tex = gTex
        gBtn.cardIndex = i
        
        gBtn:SetScript("OnClick", function()
            if isViewingSelf then
                local idx = this.cardIndex
                Sheet:OpenIconPicker(function(selectedIconIndex)
                    local profile = PUIRoleplay:GetMyProfile()
                    profile["atAGlance" .. idx .. "Icon"] = tostring(selectedIconIndex)
                    profile.keyT = PUIRoleplay:GenerateKey()
                    PUIRoleplay:SaveMyProfile(profile)
                    Sheet:Refresh()
                end)
            end
        end)
        card.iconBtn = gBtn
        
        local gTitleEB = CreateStyledEditBox(card, 345, 18)
        gTitleEB:SetPoint("TOPLEFT", gBtn, "TOPRIGHT", 8, 2)
        gTitleEB:SetTextColor(1.0, 0.90, 0.30, 1.0)
        gTitleEB.cardIndex = i
        gTitleEB:SetScript("OnTextChanged", function()
            if isViewingSelf and f.isRefreshing ~= true then
                local profile = PUIRoleplay:GetMyProfile()
                profile["atAGlance" .. this.cardIndex .. "Title"] = this:GetText()
                profile.keyT = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(profile)
            end
        end)
        card.titleEB = gTitleEB
        
        local gDescEB = CreateStyledEditBox(card, 345, 18)
        gDescEB:SetPoint("TOPLEFT", gTitleEB, "BOTTOMLEFT", 0, -2)
        gDescEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
        gDescEB.cardIndex = i
        gDescEB:SetScript("OnTextChanged", function()
            if isViewingSelf and f.isRefreshing ~= true then
                local profile = PUIRoleplay:GetMyProfile()
                profile["atAGlance" .. this.cardIndex] = this:GetText()
                profile.keyT = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(profile)
            end
        end)
        card.descEB = gDescEB
        
        p1.glanceCards[i] = card
    end
    
    ----------------------------------------------------------------------------
    -- Panel 2: RP Style & Preferences
    ----------------------------------------------------------------------------
    local p2 = CreateFrame("Frame", nil, contentBox)
    p2:SetAllPoints(contentBox)
    p2:Hide()
    f.panel2 = p2
    
    local styleKeys = { "experience", "walkups", "injury", "romance", "death" }
    local styleLabels = {
        "Roleplay Experience Level:",
        "Walk-Up Preferences:",
        "Combat Injury Tolerance:",
        "Romance / Relationship Status:",
        "Character Death Willingness:"
    }
    
    p2.buttons = {}
    for i, key in ipairs(styleKeys) do
        local lbl = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", p2, "TOPLEFT", 16, -14 - (i - 1) * 72)
        lbl:SetText("|cff00e5ff" .. styleLabels[i] .. "|r")
        
        local options = PUIRoleplay.DropdownOptions[key] or {}
        local optRow = CreateFrame("Frame", nil, p2)
        optRow:SetWidth(400)
        optRow:SetHeight(38)
        optRow:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
        
        local col = 0
        for optKey, optText in pairs(options) do
            local optBtn = CreateFrame("Button", nil, optRow)
            optBtn:SetWidth(125)
            optBtn:SetHeight(20)
            optBtn:SetPoint("TOPLEFT", optRow, "TOPLEFT", math.mod(col, 3) * 130, -math.floor(col / 3) * 22)
            optBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            optBtn:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
            optBtn:SetBackdropBorderColor(0.30, 0.35, 0.42, 1.0)
            
            local btnText = optBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("CENTER", optBtn, "CENTER", 0, 0)
            btnText:SetText(optText)
            btnText:SetTextColor(0.90, 0.90, 0.95)
            optBtn.text = btnText
            optBtn.styleKey = key
            optBtn.optKey = optKey
            
            optBtn:SetScript("OnClick", function()
                if isViewingSelf then
                    local profile = PUIRoleplay:GetMyProfile()
                    profile[this.styleKey] = this.optKey
                    profile.keyT = PUIRoleplay:GenerateKey()
                    PUIRoleplay:SaveMyProfile(profile)
                    Sheet:Refresh()
                end
            end)
            
            table.insert(p2.buttons, optBtn)
            col = col + 1
        end
    end
    
    ----------------------------------------------------------------------------
    -- Panel 3: Full Biography / Description
    ----------------------------------------------------------------------------
    local p3 = CreateFrame("Frame", nil, contentBox)
    p3:SetAllPoints(contentBox)
    p3:Hide()
    f.panel3 = p3
    
    local bioLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bioLabel:SetPoint("TOPLEFT", p3, "TOPLEFT", 14, -10)
    bioLabel:SetText("|cff00e5ffDetailed Character Appearance & Biography:|r")
    
    local bioCharCount = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bioCharCount:SetPoint("TOPRIGHT", p3, "TOPRIGHT", -14, -10)
    bioCharCount:SetText("0 / 1000")
    bioCharCount:SetTextColor(0.85, 0.85, 0.90)
    p3.charCount = bioCharCount
    
    local bioScrollBg = Create1PxBackdrop(p3, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
    bioScrollBg:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -26)
    bioScrollBg:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -10, 10)
    
    local scrollBox = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_BioScroll", p3, "UIPanelScrollFrameTemplate")
    scrollBox:SetPoint("TOPLEFT", bioScrollBg, "TOPLEFT", 4, -4)
    scrollBox:SetPoint("BOTTOMRIGHT", bioScrollBg, "BOTTOMRIGHT", -24, 4)
    
    local bioEB = CreateFrame("EditBox", nil, scrollBox)
    bioEB:SetWidth(380)
    bioEB:SetHeight(340)
    bioEB:SetMultiLine(true)
    bioEB:SetMaxLetters(1000)
    bioEB:SetAutoFocus(false)
    bioEB:SetFontObject(GameFontHighlight)
    bioEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    bioEB:SetTextInsets(6, 6, 6, 6)
    scrollBox:SetScrollChild(bioEB)
    p3.bioEB = bioEB
    
    bioEB:SetScript("OnTextChanged", function()
        local len = string.len(this:GetText() or "")
        p3.charCount:SetText(len .. " / 1000")
        if isViewingSelf and f.isRefreshing ~= true then
            local profile = PUIRoleplay:GetMyProfile()
            profile.description = this:GetText()
            profile.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(profile)
        end
    end)
    bioEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    
    ----------------------------------------------------------------------------
    -- Panel 4: Notes & Multi-Profiles
    ----------------------------------------------------------------------------
    local p4 = CreateFrame("Frame", nil, contentBox)
    p4:SetAllPoints(contentBox)
    p4:Hide()
    f.panel4 = p4
    
    -- Profile Switcher Section (Self Only)
    local profHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profHeader:SetPoint("TOPLEFT", p4, "TOPLEFT", 14, -10)
    profHeader:SetText("|cff00e5ffCharacter Profile Slots:|r")
    p4.profHeader = profHeader
    
    p4.profBtns = {}
    for i = 0, 3 do
        local pBtn = CreateFrame("Button", nil, p4)
        pBtn:SetWidth(92)
        pBtn:SetHeight(24)
        pBtn:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", i * 98, -6)
        pBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        
        local pbText = pBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pbText:SetPoint("CENTER", pBtn, "CENTER", 0, 0)
        pbText:SetText("Profile " .. i)
        pbText:SetTextColor(0.90, 0.90, 0.95)
        pBtn.text = pbText
        pBtn.slot = tostring(i)
        
        pBtn:SetScript("OnClick", function()
            if isViewingSelf then
                PUIRoleplay:SetActiveProfileSlot(this.slot)
                Sheet:Refresh()
            end
        end)
        p4.profBtns[i] = pBtn
    end
    
    -- Character Private Notes Section
    local notesHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notesHeader:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", 0, -42)
    notesHeader:SetText("|cffffd100Private Character Notes (Saved Locally):|r")
    p4.notesHeader = notesHeader
    
    local notesScrollBg = Create1PxBackdrop(p4, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
    notesScrollBg:SetPoint("TOPLEFT", notesHeader, "BOTTOMLEFT", 0, -6)
    notesScrollBg:SetPoint("BOTTOMRIGHT", p4, "BOTTOMRIGHT", -10, 10)
    
    local notesScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_NotesScroll", p4, "UIPanelScrollFrameTemplate")
    notesScroll:SetPoint("TOPLEFT", notesScrollBg, "TOPLEFT", 4, -4)
    notesScroll:SetPoint("BOTTOMRIGHT", notesScrollBg, "BOTTOMRIGHT", -24, 4)
    
    local notesEB = CreateFrame("EditBox", nil, notesScroll)
    notesEB:SetWidth(380)
    notesEB:SetHeight(260)
    notesEB:SetMultiLine(true)
    notesEB:SetAutoFocus(false)
    notesEB:SetFontObject(GameFontHighlight)
    notesEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    notesEB:SetTextInsets(6, 6, 6, 6)
    notesScroll:SetScrollChild(notesEB)
    p4.notesEB = notesEB
    
    notesEB:SetScript("OnTextChanged", function()
        if f.isRefreshing ~= true then
            local currentTarget = targetPlayerName or UnitName("player")
            PUIRoleplay:SetCharacterNote(currentTarget, this:GetText())
        end
    end)
    notesEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    
    sheetFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Tab Switching & Visual State
--------------------------------------------------------------------------------
function Sheet:SelectTab(index)
    activeTab = index
    local f = self:BuildFrame()
    for i = 1, 4 do
        if i == index then
            f.tabs[i]:SetBackdropColor(0.18, 0.18, 0.24, 1.0)
            f.tabs[i]:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            f.tabs[i].text:SetTextColor(1.0, 1.0, 1.0)
        else
            f.tabs[i]:SetBackdropColor(0.06, 0.06, 0.09, 0.9)
            f.tabs[i]:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
            f.tabs[i].text:SetTextColor(0.85, 0.85, 0.90)
        end
    end
    
    f.panel1:Hide()
    f.panel2:Hide()
    f.panel3:Hide()
    f.panel4:Hide()
    
    if index == 1 then f.panel1:Show() end
    if index == 2 then f.panel2:Show() end
    if index == 3 then f.panel3:Show() end
    if index == 4 then f.panel4:Show() end
end

--------------------------------------------------------------------------------
-- Refresh Sheet Display
--------------------------------------------------------------------------------
function Sheet:Refresh()
    local f = self:BuildFrame()
    f.isRefreshing = true
    
    local target = targetPlayerName or UnitName("player")
    isViewingSelf = (target == UnitName("player"))
    
    local charData = isViewingSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(target)
    if not charData then charData = {} end
    
    -- Icon
    local iconIdx = tonumber(charData.icon) or 1
    local iconFile = PUIRoleplay.Icons[iconIdx] or "INV_Misc_QuestionMark"
    f.iconBtn.tex:SetTexture("Interface\\Icons\\" .. iconFile)
    
    -- Names
    local name = charData.full_name or target
    f.nameEB:SetText(name)
    f.nameEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    f.titleEB:SetText(charData.title or "")
    f.titleEB:SetTextColor(0.0, 0.85, 1.0, 1.0)
    
    -- Race & Class
    local race = charData.race or (isViewingSelf and UnitRace("player") or "")
    local class = charData.class or (isViewingSelf and UnitClass("player") or "")
    local colorHex = charData.class_color or "00ccff"
    f.raceClassText:SetText(race .. " |cff" .. colorHex .. class .. "|r")
    
    -- IC / OOC State Pill
    local isIC = (charData.currently_ic == "1")
    if isIC then
        f.icBtn:SetBackdropColor(0.08, 0.45, 0.15, 0.9)
        f.icBtn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1.0)
        f.icBtn.text:SetText("IN CHARACTER")
        f.icBtn.text:SetTextColor(0.4, 1.0, 0.5)
    else
        f.icBtn:SetBackdropColor(0.45, 0.25, 0.05, 0.9)
        f.icBtn:SetBackdropBorderColor(0.85, 0.5, 0.15, 1.0)
        f.icBtn.text:SetText("OUT OF CHAR")
        f.icBtn.text:SetTextColor(1.0, 0.7, 0.3)
    end
    
    -- Panel 1: General & Glances
    f.panel1.icPrEB:SetText(charData.ic_pronouns or "")
    f.panel1.icPrEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    f.panel1.oocPrEB:SetText(charData.ooc_pronouns or "")
    f.panel1.oocPrEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    f.panel1.icInfoEB:SetText(charData.ic_info or "")
    f.panel1.icInfoEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    f.panel1.oocInfoEB:SetText(charData.ooc_info or "")
    f.panel1.oocInfoEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    
    for i = 1, 3 do
        local card = f.panel1.glanceCards[i]
        local gIconIdx = tonumber(charData["atAGlance" .. i .. "Icon"]) or 0
        if gIconIdx > 0 and PUIRoleplay.Icons[gIconIdx] then
            card.iconBtn.tex:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[gIconIdx])
        else
            card.iconBtn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        card.titleEB:SetText(charData["atAGlance" .. i .. "Title"] or "")
        card.titleEB:SetTextColor(1.0, 0.90, 0.30, 1.0)
        card.descEB:SetText(charData["atAGlance" .. i] or "")
        card.descEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    
    -- Panel 2: Style Buttons
    for _, btn in ipairs(f.panel2.buttons) do
        local curVal = charData[btn.styleKey]
        if curVal == btn.optKey then
            btn:SetBackdropColor(0.0, 0.50, 0.80, 1.0)
            btn:SetBackdropBorderColor(0.0, 0.90, 1.0, 1.0)
            btn.text:SetTextColor(1.0, 1.0, 1.0)
        else
            btn:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
            btn:SetBackdropBorderColor(0.30, 0.35, 0.42, 1.0)
            btn.text:SetTextColor(0.90, 0.90, 0.95)
        end
    end
    
    -- Panel 3: Bio
    f.panel3.bioEB:SetText(charData.description or "")
    f.panel3.bioEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    
    -- Panel 4: Notes & Profiles
    local activeSlot = PUIRoleplay:GetActiveProfileSlot()
    for i = 0, 3 do
        local pBtn = f.panel4.profBtns[i]
        if tostring(i) == activeSlot then
            pBtn:SetBackdropColor(0.0, 0.50, 0.80, 1.0)
            pBtn:SetBackdropBorderColor(0.0, 0.90, 1.0, 1.0)
            pBtn.text:SetTextColor(1.0, 1.0, 1.0)
        else
            pBtn:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
            pBtn:SetBackdropBorderColor(0.30, 0.35, 0.42, 1.0)
            pBtn.text:SetTextColor(0.90, 0.90, 0.95)
        end
    end
    f.panel4.notesEB:SetText(PUIRoleplay:GetCharacterNote(target) or "")
    f.panel4.notesEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    
    f.isRefreshing = false
end

--------------------------------------------------------------------------------
-- Open Profile Method
--------------------------------------------------------------------------------
function PUIRoleplay:OpenProfile(playerName)
    targetPlayerName = playerName or UnitName("player")
    local f = Sheet:BuildFrame()
    f:Show()
    Sheet:SelectTab(1)
    Sheet:Refresh()
    
    -- If targeting another player, request fresh metadata from network
    if targetPlayerName ~= UnitName("player") then
        PUIRoleplay.Comms:SendRequest("M", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("T", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("D", targetPlayerName)
    end
end

--------------------------------------------------------------------------------
-- Icon Picker Modal
--------------------------------------------------------------------------------
local iconPickerFrame = nil
function Sheet:OpenIconPicker(onSelectCallback)
    if not iconPickerFrame then
        local p = CreateFrame("Frame", "Primus_PUIRoleplay_IconPicker", sheetFrame)
        p:SetWidth(380)
        p:SetHeight(320)
        p:SetPoint("CENTER", sheetFrame, "CENTER", 0, 0)
        p:SetFrameStrata("DIALOG")
        p:EnableMouse(true)
        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        p:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
        p:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0)
        
        local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
        title:SetText("|cff00ccffSELECT ICON|r")
        
        local close = CreateFrame("Button", nil, p)
        close:SetWidth(18)
        close:SetHeight(18)
        close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
        close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        close:SetScript("OnClick", function() p:Hide() end)
        
        -- Filter box
        local searchEB = CreateStyledEditBox(p, 356, 20)
        searchEB:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -28)
        p.searchEB = searchEB
        
        -- Icon grid buttons (6 rows x 8 cols = 48 icons per page)
        local iconGrid = {}
        for r = 1, 6 do
            for c = 1, 8 do
                local idx = (r - 1) * 8 + c
                local btn = CreateFrame("Button", nil, p)
                btn:SetWidth(38)
                btn:SetHeight(38)
                btn:SetPoint("TOPLEFT", searchEB, "BOTTOMLEFT", (c - 1) * 44, -10 - (r - 1) * 42)
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, tileSize = 0, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                btn:SetBackdropColor(0, 0, 0, 1)
                btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
                
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
                tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
                btn.tex = tex
                
                btn:SetScript("OnClick", function()
                    if this.iconIndex and iconPickerFrame.callback then
                        iconPickerFrame.callback(this.iconIndex)
                    end
                    iconPickerFrame:Hide()
                end)
                table.insert(iconGrid, btn)
            end
        end
        p.iconGrid = iconGrid
        
        searchEB:SetScript("OnTextChanged", function()
            Sheet:UpdateIconGrid(this:GetText() or "")
        end)
        
        iconPickerFrame = p
    end
    
    iconPickerFrame.callback = onSelectCallback
    iconPickerFrame:Show()
    iconPickerFrame.searchEB:SetText("")
    Sheet:UpdateIconGrid("")
end

function Sheet:UpdateIconGrid(searchTerm)
    if not iconPickerFrame then return end
    local query = string.lower(searchTerm or "")
    local matched = {}
    
    for idx, iconName in ipairs(PUIRoleplay.Icons) do
        if query == "" or string.find(string.lower(iconName), query) then
            table.insert(matched, idx)
            if table.getn(matched) >= 48 then break end
        end
    end
    
    for i, btn in ipairs(iconPickerFrame.iconGrid) do
        local iconIdx = matched[i]
        if iconIdx then
            btn.iconIndex = iconIdx
            btn.tex:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[iconIdx])
            btn:Show()
        else
            btn.iconIndex = nil
            btn:Hide()
        end
    end
end
