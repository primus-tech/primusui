--[[
    PrimusUI: PUIRoleplay Directory Profile Flyout Sidecar (PUIDirFlyout.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Multi-Tab Character Detail Drawer)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Directory = PUIRoleplay.Directory or {}
PUIRoleplay.Directory = Directory

--------------------------------------------------------------------------------
-- Build Right-Hand Profile Discovery Flyout Sidecar
--------------------------------------------------------------------------------
function Directory:BuildFlyout(parent)
    local flyout = CreateFrame("Frame", "Primus_PUIRoleplay_DirFlyout", parent)
    flyout:SetWidth(440)
    flyout:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
    flyout:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
    flyout:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    flyout:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    flyout:SetBackdropBorderColor(0.20, 0.22, 0.28, 1.0)
    flyout:EnableMouse(true)
    flyout:Hide()
    parent.flyout = flyout

    -- Title Bar
    local titleBar = CreateFrame("Frame", nil, flyout)
    titleBar:SetPoint("TOPLEFT", flyout, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    titleBar:SetBackdropColor(0.11, 0.12, 0.15, 1.0)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cff00ccffDISCOVERY CARD PREVIEW|r")

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetWidth(18)
    closeBtn:SetHeight(18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        flyout:Hide()
        Directory.selectedPlayer = nil
        Directory:RefreshList()
    end)

    -- Quick Action Buttons
    local inspectBtn = CreateFrame("Button", nil, titleBar)
    inspectBtn:SetWidth(76)
    inspectBtn:SetHeight(18)
    inspectBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    inspectBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    inspectBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.9)
    inspectBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    local iLbl = inspectBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iLbl:SetPoint("CENTER", inspectBtn, "CENTER", 0, 0)
    iLbl:SetText("|cff00ccff[Profile]|r")
    inspectBtn:SetScript("OnClick", function()
        if Directory.selectedPlayer then
            PUIRoleplay:OpenProfile(Directory.selectedPlayer)
        end
    end)

    local whisperBtn = CreateFrame("Button", nil, titleBar)
    whisperBtn:SetWidth(62)
    whisperBtn:SetHeight(18)
    whisperBtn:SetPoint("RIGHT", inspectBtn, "LEFT", -4, 0)
    whisperBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    whisperBtn:SetBackdropColor(0.10, 0.14, 0.20, 0.9)
    whisperBtn:SetBackdropBorderColor(0.0, 0.6, 0.9, 0.8)
    local wLbl = whisperBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wLbl:SetPoint("CENTER", whisperBtn, "CENTER", 0, 0)
    wLbl:SetText("|cff00ccffWhisper|r")
    whisperBtn:SetScript("OnClick", function()
        if Directory.selectedPlayer and ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. Directory.selectedPlayer .. " ")
        end
    end)

    -- Header Profile Summary Card
    local headerBox = CreateFrame("Frame", nil, flyout)
    headerBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -32)
    headerBox:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -8, -32)
    headerBox:SetHeight(84)
    headerBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
    headerBox:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)

    local avatarTex = headerBox:CreateTexture(nil, "ARTWORK")
    avatarTex:SetWidth(52)
    avatarTex:SetHeight(52)
    avatarTex:SetPoint("TOPLEFT", headerBox, "TOPLEFT", 8, -8)
    avatarTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    flyout.avatarTex = avatarTex

    local nameStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameStr:SetPoint("TOPLEFT", avatarTex, "TOPRIGHT", 10, 0)
    nameStr:SetText("Adventurer")
    flyout.nameStr = nameStr

    local titleStr = headerBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleStr:SetPoint("TOPLEFT", nameStr, "BOTTOMLEFT", 0, -2)
    titleStr:SetTextColor(0.0, 0.85, 1.0)
    flyout.titleStr = titleStr

    local demoTags = headerBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    demoTags:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -2)
    flyout.demoTags = demoTags

    local statusPill = CreateFrame("Frame", nil, headerBox)
    statusPill:SetWidth(100)
    statusPill:SetHeight(20)
    statusPill:SetPoint("TOPRIGHT", headerBox, "TOPRIGHT", -8, -8)
    statusPill:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local statusPillText = statusPill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusPillText:SetPoint("CENTER", statusPill, "CENTER", 0, 0)
    statusPill.text = statusPillText
    flyout.statusPill = statusPill

    -- Flyout Tabs: Appearance (1), Style & ERP (2), Lore (3), Notes (4)
    local tabNames = { "Appearance", "Style / ERP", "Lore", "Notes" }
    local tabs = {}
    for i = 1, 4 do
        local tBtn = CreateFrame("Button", nil, flyout)
        tBtn:SetWidth(102)
        tBtn:SetHeight(22)
        tBtn:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8 + (i - 1) * 106, -120)
        tBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 0 }
        })
        tBtn:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        tBtn:SetBackdropBorderColor(0.22, 0.24, 0.28, 1.0)

        local tTxt = tBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tTxt:SetPoint("CENTER", tBtn, "CENTER", 0, 0)
        tTxt:SetText(tabNames[i])
        tBtn.text = tTxt
        tBtn.tabIdx = i

        tBtn:SetScript("OnClick", function()
            Directory:SelectFlyoutTab(this.tabIdx)
        end)
        tabs[i] = tBtn
    end
    flyout.tabs = tabs

    -- Content Container Box
    local contentBox = CreateFrame("Frame", nil, flyout)
    contentBox:SetPoint("TOPLEFT", flyout, "TOPLEFT", 8, -142)
    contentBox:SetPoint("BOTTOMRIGHT", flyout, "BOTTOMRIGHT", -8, 8)
    contentBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    contentBox:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    contentBox:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)
    flyout.contentBox = contentBox

    -- Panel 1: Glances & Appearance
    local p1 = CreateFrame("Frame", nil, contentBox)
    p1:SetAllPoints(contentBox)
    flyout.p1 = p1

    local lfBadgeDisplay = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lfBadgeDisplay:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -8)
    lfBadgeDisplay:SetWidth(408)
    lfBadgeDisplay:SetJustifyH("LEFT")
    p1.lfBadgeDisplay = lfBadgeDisplay

    p1.glanceCards = {}
    for i = 1, 5 do
        local gCard = CreateFrame("Frame", nil, p1)
        gCard:SetWidth(408)
        gCard:SetHeight(48)
        gCard:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -32 - (i - 1) * 52)
        gCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        gCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        gCard:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)

        local gIcon = gCard:CreateTexture(nil, "ARTWORK")
        gIcon:SetWidth(32)
        gIcon:SetHeight(32)
        gIcon:SetPoint("TOPLEFT", gCard, "TOPLEFT", 6, -8)
        gIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        gCard.icon = gIcon

        local gTitle = gCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gTitle:SetPoint("TOPLEFT", gIcon, "TOPRIGHT", 6, 0)
        gTitle:SetPoint("TOPRIGHT", gCard, "TOPRIGHT", -6, 0)
        gTitle:SetJustifyH("LEFT")
        gCard.title = gTitle

        local gDesc = gCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gDesc:SetPoint("TOPLEFT", gTitle, "BOTTOMLEFT", 0, -2)
        gDesc:SetPoint("BOTTOMRIGHT", gCard, "BOTTOMRIGHT", -6, 4)
        gDesc:SetJustifyH("LEFT")
        gCard.desc = gDesc

        p1.glanceCards[i] = gCard
    end

    -- Panel 2: Style & ERP
    local p2 = CreateFrame("Frame", nil, contentBox)
    p2:SetAllPoints(contentBox)
    p2:Hide()
    flyout.p2 = p2

    p2.styleRows = {}
    local styleMeta = {
        { key = "relationship_status", label = "Relationship Status" },
        { key = "walkup_policy", label = "Walk-Up Preferences" },
        { key = "combat_preference", label = "Combat & Conflict Resolution" },
        { key = "injury_consent", label = "Combat Injury Tolerance" },
        { key = "permadeath_consent", label = "Character Death Willingness" },
        { key = "erp_preference", label = "ERP Preference & Tone" }
    }

    for i, meta in ipairs(styleMeta) do
        local sCard = CreateFrame("Frame", nil, p2)
        sCard:SetWidth(408)
        sCard:SetHeight(42)
        sCard:SetPoint("TOPLEFT", p2, "TOPLEFT", 8, -8 - (i - 1) * 46)
        sCard:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        sCard:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
        sCard:SetBackdropBorderColor(0.18, 0.20, 0.24, 1.0)

        local sLbl = sCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", sCard, "TOPLEFT", 8, -4)
        sLbl:SetText("|cff00e5ff" .. meta.label .. ":|r")

        local valTxt = sCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valTxt:SetPoint("TOPLEFT", sLbl, "BOTTOMLEFT", 0, -2)
        valTxt:SetText("Not Specified")
        sCard.valTxt = valTxt
        sCard.key = meta.key

        p2.styleRows[i] = sCard
    end

    -- Panel 3: Lore & History
    local p3 = CreateFrame("Frame", nil, contentBox)
    p3:SetAllPoints(contentBox)
    p3:Hide()
    flyout.p3 = p3

    local bioScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_FlyoutBioScroll", p3, "UIPanelScrollFrameTemplate")
    bioScroll:SetPoint("TOPLEFT", p3, "TOPLEFT", 8, -8)
    bioScroll:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -26, 8)

    local bioChild = CreateFrame("Frame", nil, bioScroll)
    bioChild:SetWidth(380)
    bioChild:SetHeight(800)
    bioScroll:SetScrollChild(bioChild)

    local bioText = bioChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bioText:SetPoint("TOPLEFT", bioChild, "TOPLEFT", 4, -4)
    bioText:SetWidth(370)
    bioText:SetJustifyH("LEFT")
    bioText:SetJustifyV("TOP")
    bioText:SetText("No history recorded.")
    p3.bioText = bioText
    p3.bioChild = bioChild
    p3.bioScroll = bioScroll

    -- Panel 4: Notes
    local p4 = CreateFrame("Frame", nil, contentBox)
    p4:SetAllPoints(contentBox)
    p4:Hide()
    flyout.p4 = p4

    local nHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nHeader:SetPoint("TOPLEFT", p4, "TOPLEFT", 8, -8)
    nHeader:SetText("|cffffd100Private Notes for this Adventurer (Saved Locally):|r")

    local notesScroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_FlyoutNotesScroll", p4, "UIPanelScrollFrameTemplate")
    notesScroll:SetPoint("TOPLEFT", p4, "TOPLEFT", 8, -26)
    notesScroll:SetPoint("BOTTOMRIGHT", p4, "BOTTOMRIGHT", -26, 8)
    notesScroll:EnableMouse(true)

    local notesEB = CreateFrame("EditBox", nil, notesScroll)
    notesEB:SetWidth(380)
    notesEB:SetHeight(400)
    notesEB:SetMultiLine(true)
    notesEB:EnableMouse(true)
    notesEB:SetAutoFocus(false)
    notesEB:SetFontObject(GameFontHighlightSmall)
    notesEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    notesEB:SetTextInsets(4, 4, 4, 4)
    notesScroll:SetScrollChild(notesEB)
    p4.notesEB = notesEB

    notesScrollBg = p4
    notesEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    notesEB:SetScript("OnTextChanged", function()
        if Directory.selectedPlayer and flyout.isRefreshing ~= true then
            PUIRoleplay:SetCharacterNote(Directory.selectedPlayer, this:GetText())
        end
    end)
end

function Directory:SelectFlyoutTab(index)
    Directory.activeFlyoutTab = index
    local f = Directory:BuildFrame()
    local flyout = f.flyout
    if not flyout then return end

    for i = 1, 4 do
        local tab = flyout.tabs[i]
        if i == index then
            tab:SetBackdropColor(0.16, 0.18, 0.24, 1.0)
            tab:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            tab.text:SetTextColor(0.0, 0.90, 1.0)
        else
            tab:SetBackdropColor(0.06, 0.06, 0.08, 0.9)
            tab:SetBackdropBorderColor(0.20, 0.22, 0.26, 1.0)
            tab.text:SetTextColor(0.70, 0.70, 0.75)
        end
    end

    flyout.p1:Hide()
    flyout.p2:Hide()
    flyout.p3:Hide()
    flyout.p4:Hide()

    if index == 1 then flyout.p1:Show()
    elseif index == 2 then flyout.p2:Show()
    elseif index == 3 then flyout.p3:Show()
    elseif index == 4 then flyout.p4:Show()
    end
end

function Directory:ShowPlayerFlyout(charName)
    if not charName then return end
    local f = Directory:BuildFrame()
    Directory.selectedPlayer = charName

    if PUIRoleplay.Comms and PUIRoleplay.Comms.SendRequest then
        PUIRoleplay.Comms:SendRequest("M", charName)
        PUIRoleplay.Comms:SendRequest("T", charName)
        PUIRoleplay.Comms:SendRequest("D", charName)
        PUIRoleplay.Comms:SendRequest("L", charName)
        PUIRoleplay.Comms:SendRequest("X", charName)
    end

    Directory:RefreshFlyout()
    f.flyout:Show()
    Directory:RefreshList()
end

function Directory:RefreshFlyout()
    local f = Directory:BuildFrame()
    local flyout = f.flyout
    if not flyout or not Directory.selectedPlayer then return end

    local name = Directory.selectedPlayer
    local isSelf = (name == UnitName("player"))
    local data = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(name)
    if not data then return end

    flyout.isRefreshing = true

    local iconIdx = tonumber(data.icon) or 1
    flyout.avatarTex:SetTexture("Interface\\Icons\\" .. (PUIRoleplay.Icons[iconIdx] or "INV_Misc_QuestionMark"))

    local colorHex = data.class_color or "00ccff"
    local fullName = (data.full_name and data.full_name ~= "") and data.full_name or name
    flyout.nameStr:SetText("|cff" .. colorHex .. fullName .. "|r")

    local titleStr = (data.title and data.title ~= "") and ("<" .. data.title .. ">") or ("|cff888888" .. name .. "|r")
    flyout.titleStr:SetText(titleStr)

    local age = data.apparent_age or "Unknown Age"
    local ori = (data.show_orientation ~= false and data.orientation) or "Private"
    local lgbtq = (data.lgbtqia_friendly ~= false) and " |cffff0000[|cffff7f00LGBTQIA+|cff9400d3]|r" or ""
    local adult18 = (data.adult_18plus_flag == true) and " |cffff3355[18+]|r" or ""
    flyout.demoTags:SetText(string.format("|cff00ccff[%s]|r |cffff80cc[%s]|r%s%s", age, ori, lgbtq, adult18))

    local isOnline = isSelf or PUIRoleplay:IsPlayerOnline(name)
    local isIC = (data.currently_ic == "1")
    if not isOnline then
        flyout.statusPill:SetBackdropColor(0.25, 0.25, 0.28, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.4, 0.4, 0.45, 1.0)
        flyout.statusPill.text:SetText("|cff888888OFFLINE|r")
    elseif isIC then
        flyout.statusPill:SetBackdropColor(0.08, 0.45, 0.15, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.2, 0.85, 0.3, 1.0)
        flyout.statusPill.text:SetText("|cff40ff66IN CHARACTER|r")
    else
        flyout.statusPill:SetBackdropColor(0.45, 0.25, 0.05, 0.9)
        flyout.statusPill:SetBackdropBorderColor(0.85, 0.5, 0.15, 1.0)
        flyout.statusPill.text:SetText("|cffffaa00OUT OF CHAR|r")
    end

    local lfStr = "Looking For:"
    local lf = data.looking_for or {}
    if lf.adventure then lfStr = lfStr .. " |cff00ff88[Adventure]|r" end
    if lf.romance then lfStr = lfStr .. " |cffff80cc[Romance]|r" end
    if lf.casual_tavern then lfStr = lfStr .. " |cffffcc00[Tavern]|r" end
    if lf.combat then lfStr = lfStr .. " |cffff4444[Combat]|r" end
    if lf.political_guild then lfStr = lfStr .. " |cff00ccff[Guild]|r" end
    if lf.mentorship then lfStr = lfStr .. " |cffb080ff[Mentorship]|r" end
    flyout.p1.lfBadgeDisplay:SetText(lfStr)

    for i = 1, 5 do
        local gCard = flyout.p1.glanceCards[i]
        local glance = (data.glances and data.glances[i]) or {}
        local gTitle = glance.title or data["atAGlance" .. i .. "Title"] or ""
        local gText = glance.text or data["atAGlance" .. i] or ""
        local gIcon = glance.icon or ""
        local gIconIdx = tonumber(data["atAGlance" .. i .. "Icon"]) or 0

        if gIcon ~= "" then
            gCard.icon:SetTexture("Interface\\Icons\\" .. gIcon)
        elseif gIconIdx > 0 and PUIRoleplay.Icons[gIconIdx] then
            gCard.icon:SetTexture("Interface\\Icons\\" .. PUIRoleplay.Icons[gIconIdx])
        else
            gCard.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        if gTitle ~= "" or gText ~= "" then
            gCard.title:SetText("|cffffd100" .. gTitle .. "|r")
            gCard.desc:SetText(gText)
            gCard:Show()
        else
            gCard.title:SetText("|cff666666(Empty Glance Slot " .. i .. ")|r")
            gCard.desc:SetText("")
            gCard:Show()
        end
    end

    for _, sCard in ipairs(flyout.p2.styleRows) do
        local val = data[sCard.key] or "Not Specified"
        sCard.valTxt:SetText("|cffffffff" .. tostring(val) .. "|r")
    end

    local bioStr = ""
    if data.motto and data.motto ~= "" then
        bioStr = bioStr .. "|cffffd100Motto:|r \"" .. data.motto .. "\"\n\n"
    end
    if data.birth_city and data.birth_city ~= "" then
        bioStr = bioStr .. "|cff00e5ffBirthplace:|r " .. data.birth_city .. "    |cff00e5ffHome:|r " .. (data.home_city or "") .. "\n\n"
    end
    if data.history then
        for chIdx = 1, 6 do
            local chText = data.history["chapter" .. chIdx]
            if chText and chText ~= "" then
                bioStr = bioStr .. "|cff00e5ff--- Chapter " .. chIdx .. " ---|r\n" .. chText .. "\n\n"
            end
        end
    end
    if bioStr == "" then
        bioStr = data.description or "No detailed biography recorded."
    end
    flyout.p3.bioText:SetText(bioStr)

    flyout.p4.notesEB:SetText(PUIRoleplay:GetCharacterNote(name) or "")

    Directory:SelectFlyoutTab(Directory.activeFlyoutTab)
    flyout.isRefreshing = false
end
