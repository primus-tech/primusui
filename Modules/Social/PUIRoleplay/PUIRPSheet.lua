--[[
    PrimusUI: PUIRoleplay Profile Sheet Master Controller (PUIRPSheet.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Master Window & 6-Tab Coordinator)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Sheet = PUIRoleplay.Sheet or {}
PUIRoleplay.Sheet = Sheet

local sheetFrame = nil
local activeTab = 1
Sheet.activeLoreChapter = 1
local targetPlayerName = nil
local isViewingSelf = true

function Sheet:IsViewingSelf()
    return isViewingSelf
end

function Sheet:GetTargetPlayer()
    return targetPlayerName or UnitName("player")
end

--------------------------------------------------------------------------------
-- Master Profile Sheet Frame Construction
--------------------------------------------------------------------------------
function Sheet:BuildFrame()
    if sheetFrame then return sheetFrame end

    local f = CreateFrame("Frame", "Primus_PUIRoleplay_Sheet", UIParent)
    f:SetWidth(520)
    f:SetHeight(620)
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
    headerArea:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32)
    headerArea:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -32)
    headerArea:SetHeight(84)

    -- Avatar Icon Button
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
            local curIdx = tonumber(PUIRoleplay:GetMyProfile().icon) or 1
            Sheet:OpenIconPicker(function(selectedIconIndex)
                local profile = PUIRoleplay:GetMyProfile()
                profile.icon = tostring(selectedIconIndex)
                profile.keyM = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(profile)
                Sheet:Refresh()
            end, curIdx)
        end
    end)
    f.iconBtn = iconBtn

    local iconSubLabel = headerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSubLabel:SetPoint("TOP", iconBtn, "BOTTOM", 0, -2)
    iconSubLabel:SetText("|cff666677[Avatar]|r")

    local headerName = headerArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerName:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 12, -2)
    headerName:SetText("Character Name")
    f.headerName = headerName

    local headerTitle = headerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerTitle:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", 0, -2)
    headerTitle:SetText("<Title / House>")
    headerTitle:SetTextColor(0.0, 0.85, 1.0)
    f.headerTitle = headerTitle

    local raceClassText = headerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raceClassText:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -2)
    raceClassText:SetText("Human Paladin")
    f.raceClassText = raceClassText

    local icBtn = CreateFrame("Button", nil, headerArea)
    icBtn:SetWidth(100)
    icBtn:SetHeight(22)
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

    local cardPreviewBtn = CreateFrame("Button", nil, headerArea)
    cardPreviewBtn:SetWidth(100)
    cardPreviewBtn:SetHeight(20)
    cardPreviewBtn:SetPoint("TOPRIGHT", icBtn, "BOTTOMRIGHT", 0, -4)
    cardPreviewBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    cardPreviewBtn:SetBackdropColor(0.12, 0.15, 0.22, 0.95)
    cardPreviewBtn:SetBackdropBorderColor(0.0, 0.65, 0.90, 0.8)

    local cpText = cardPreviewBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cpText:SetPoint("CENTER", cardPreviewBtn, "CENTER", 0, 0)
    cpText:SetText("|cff00ccff[Preview Card]|r")

    cardPreviewBtn:SetScript("OnClick", function()
        local target = targetPlayerName or UnitName("player")
        Sheet:OpenCardPreviewModal(target)
    end)
    f.cardPreviewBtn = cardPreviewBtn

    ----------------------------------------------------------------------------
    -- 6-Tab Navigation Bar
    ----------------------------------------------------------------------------
    local tabNames = { "Identity", "Appearance", "Lore", "RP Style", "Dating/18+", "Notes" }
    local tabs = {}
    local tabWidth = 80
    for i = 1, 6 do
        local tab = CreateFrame("Button", nil, f)
        tab:SetWidth(tabWidth)
        tab:SetHeight(24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * (tabWidth + 3), -120)
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

    -- Content Container Box
    local contentBox = CreateFrame("Frame", nil, f)
    contentBox:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -144)
    contentBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    contentBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    contentBox:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    contentBox:SetBackdropBorderColor(0.22, 0.22, 0.26, 1.0)
    f.contentBox = contentBox

    -- Build all 6 Tab Panels via Sheet.Tabs
    if Sheet.Tabs then
        Sheet.Tabs:BuildPanel1(contentBox, f)
        Sheet.Tabs:BuildPanel2(contentBox, f)
        Sheet.Tabs:BuildPanel3(contentBox, f)
        Sheet.Tabs:BuildPanel4(contentBox, f)
        Sheet.Tabs:BuildPanel5(contentBox, f)
        Sheet.Tabs:BuildPanel6(contentBox, f)
    end

    sheetFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Tab & Lore Navigation
--------------------------------------------------------------------------------
function Sheet:SelectTab(index)
    activeTab = index
    local f = self:BuildFrame()

    for i = 1, 6 do
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
    f.panel5:Hide()
    f.panel6:Hide()

    if index == 1 then f.panel1:Show()
    elseif index == 2 then f.panel2:Show()
    elseif index == 3 then f.panel3:Show()
    elseif index == 4 then f.panel4:Show()
    elseif index == 5 then f.panel5:Show()
    elseif index == 6 then f.panel6:Show()
    end
end

function Sheet:SelectLoreChapter(idx)
    Sheet.activeLoreChapter = idx
    local f = self:BuildFrame()
    local p3 = f.panel3
    local chapterTitles = {
        "Chapter 1: Early Years / Origins",
        "Chapter 2: The First Trials",
        "Chapter 3: Recent Events",
        "Chapter 4: Notable Deeds",
        "Chapter 5: Personal Beliefs",
        "Chapter 6: Current Goals"
    }
    p3.chTitleLabel:SetText("|cff00e5ff" .. (chapterTitles[idx] or ("Chapter " .. idx)) .. "|r")

    for i = 1, 6 do
        if i == idx then
            p3.chBtns[i]:SetBackdropColor(0.0, 0.45, 0.7, 1.0)
            p3.chBtns[i]:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            p3.chBtns[i].text:SetTextColor(1, 1, 1)
        else
            p3.chBtns[i]:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
            p3.chBtns[i]:SetBackdropBorderColor(0.25, 0.25, 0.32, 1.0)
            p3.chBtns[i].text:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    local target = targetPlayerName or UnitName("player")
    local data = (target == UnitName("player")) and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(target)
    local histText = (data and data.history and data.history["chapter" .. idx]) or ""
    p3.chEB:SetText(histText)
    p3.chCount:SetText(string.len(histText) .. " / 1000")
end

--------------------------------------------------------------------------------
-- Sheet Refresh Engine
--------------------------------------------------------------------------------
function Sheet:Refresh()
    local f = self:BuildFrame()
    f.isRefreshing = true

    local target = targetPlayerName or UnitName("player")
    isViewingSelf = (target == UnitName("player"))

    local charData = isViewingSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(target)
    if not charData then charData = {} end

    -- Avatar Icon
    local iconIdx = tonumber(charData.icon) or 1
    local iconFile = PUIRoleplay.Icons[iconIdx] or "INV_Misc_QuestionMark"
    f.iconBtn.tex:SetTexture("Interface\\Icons\\" .. iconFile)

    -- Header Name & Title
    local nameComposite = ""
    if charData.first_name and charData.first_name ~= "" then
        nameComposite = charData.first_name
        if charData.middle_name and charData.middle_name ~= "" then
            nameComposite = nameComposite .. " " .. charData.middle_name
        end
        if charData.last_name and charData.last_name ~= "" then
            nameComposite = nameComposite .. " " .. charData.last_name
        end
    else
        nameComposite = charData.full_name or target
    end
    f.headerName:SetText("|cffffffff" .. nameComposite .. "|r")

    local titleStr = ""
    if charData.prefix and charData.prefix ~= "" then
        titleStr = charData.prefix .. " "
    end
    if charData.title and charData.title ~= "" then
        titleStr = titleStr .. charData.title
    end
    if charData.house_name and charData.house_name ~= "" then
        titleStr = titleStr .. " of " .. charData.house_name
    end
    f.headerTitle:SetText((titleStr ~= "") and ("<" .. titleStr .. ">") or "|cff666677<No Title Recorded>|r")

    -- Race & Class
    local race = charData.race or (isViewingSelf and UnitRace("player") or "")
    local class = charData.class or (isViewingSelf and UnitClass("player") or "")
    local colorHex = charData.class_color or "00ccff"
    f.raceClassText:SetText(race .. " |cff" .. colorHex .. class .. "|r")

    -- IC / OOC Status Button
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

    -- Tab 1: Identity
    local p1 = f.panel1
    p1.fnEB:SetText(charData.first_name or "")
    p1.mnEB:SetText(charData.middle_name or "")
    p1.lnEB:SetText(charData.last_name or "")
    p1.pfxEB:SetText(charData.prefix or "")
    p1.nickEB:SetText(charData.nickname or "")
    p1.houseEB:SetText(charData.house_name or "")
    p1.ttlEB:SetText(charData.title or "")
    p1.ageEB:SetText(charData.apparent_age or "")
    p1.genderDropdown:SetSelected(charData.gender_identity or "Cisgender Male")
    p1.icPrEB:SetText(charData.ic_pronouns or "")
    p1.oocPrEB:SetText(charData.ooc_pronouns or "")
    p1.lgbtqBox:SetChecked(charData.lgbtqia_friendly ~= false)
    p1.oriDropdown:SetSelected(charData.orientation or "Heterosexual / Straight")
    p1.showOriBox:SetChecked(charData.show_orientation ~= false)

    -- Tab 2: Appearance & Glances
    local p2 = f.panel2
    p2.eyeEB:SetText(charData.eye_color or "")
    p2.hEB:SetText(charData.height or "")
    p2.wEB:SetText(charData.weight or "")
    p2.bEB:SetText(charData.body_build or "")
    p2.emoEB:SetText(charData.current_emotion or "Calm")
    local appDesc = charData.appearance_desc or charData.description or ""
    p2.descEB:SetText(appDesc)
    p2.descCount:SetText(string.len(appDesc) .. " / 1000")

    for i = 1, 5 do
        local card = p2.glanceCards[i]
        local glance = (charData.glances and charData.glances[i]) or {}
        local gTitle = glance.title or charData["atAGlance" .. i .. "Title"] or ""
        local gText = glance.text or charData["atAGlance" .. i] or ""
        local gIcon = glance.icon or ""
        local gIconIdx = tonumber(charData["atAGlance" .. i .. "Icon"]) or 0

        if gIcon ~= "" then
            card.iconBtn.tex:SetTexture("Interface\\Icons\\" .. gIcon)
        elseif gIconIdx > 0 and PUIRoleplay.Icons[gIconIdx] then
            card.iconBtn.tex:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[gIconIdx])
        else
            card.iconBtn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        card.titleEB:SetText(gTitle)
        card.descEB:SetText(gText)
        card.activeCB:SetChecked(glance.active == true or (gTitle ~= "" and gTitle ~= nil))
    end

    -- Tab 3: Lore & Origins
    local p3 = f.panel3
    p3.bCityEB:SetText(charData.birth_city or "")
    p3.hCityEB:SetText(charData.home_city or "")
    p3.mottoEB:SetText(charData.motto or "")
    p3.facEB:SetText(charData.faction_clan or "")
    Sheet:SelectLoreChapter(Sheet.activeLoreChapter or 1)

    -- Tab 4: RP Style
    local p4 = f.panel4
    p4.dropdowns["experience_level"]:SetSelected(charData.experience_level or "Experienced")
    p4.dropdowns["walkup_policy"]:SetSelected(charData.walkup_policy or "Walkups Welcome")
    p4.dropdowns["combat_preference"]:SetSelected(charData.combat_preference or "D20 Rolls (DiceMaster)")
    p4.dropdowns["injury_consent"]:SetSelected(charData.injury_consent or "Realistic / Negotiated")
    p4.dropdowns["permadeath_consent"]:SetSelected(charData.permadeath_consent or "Negotiated Only")

    -- Tab 5: Dating & 18+
    local p5 = f.panel5
    p5.relDropdown:SetSelected(charData.relationship_status or "Single & Looking")
    local lf = charData.looking_for or {}
    for k, cb in pairs(p5.lfCheckboxes) do
        cb:SetChecked(lf[k] == true)
    end
    p5.adultFlagCB:SetChecked(charData.adult_18plus_flag == true)
    p5.erpDropdown:SetSelected(charData.erp_preference or "No Adult Content (Clean RP)")
    p5.bndEB:SetText(charData.ooc_boundaries or "")

    -- Tab 6: Profiles & Notes
    local p6 = f.panel6
    local activeSlot = PUIRoleplay:GetActiveProfileSlot()
    for i = 0, 3 do
        local pBtn = p6.profBtns[i]
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
    p6.oocEB:SetText(charData.ooc_notes or charData.ooc_info or "")
    p6.notesEB:SetText(PUIRoleplay:GetCharacterNote(target) or "")

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

    if targetPlayerName ~= UnitName("player") and PUIRoleplay.Comms and PUIRoleplay.Comms.SendRequest then
        PUIRoleplay.Comms:SendRequest("M", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("T", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("D", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("L", targetPlayerName)
        PUIRoleplay.Comms:SendRequest("X", targetPlayerName)
    end
end
