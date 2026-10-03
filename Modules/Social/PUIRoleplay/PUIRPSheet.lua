--[[
    PrimusUI: PUIRoleplay Profile Sheet & Editor (PUIRPSheet.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (PrimusUI Dark Design System)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Sheet = {}
PUIRoleplay.Sheet = Sheet

local sheetFrame = nil
local activeTab = 1
local activeLoreChapter = 1
local targetPlayerName = nil
local isViewingSelf = true

-- Active Dropdown Popup Tracker
local openDropdownMenu = nil

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
    eb:SetFontObject(GameFontHighlightSmall)
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

local function CreateStyledCheckbox(parent, text, onClickCallback)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetWidth(18)
    cb:SetHeight(18)
    cb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    cb:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    cb:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)

    local checkTex = cb:CreateTexture(nil, "ARTWORK")
    checkTex:SetPoint("CENTER", cb, "CENTER", 0, 0)
    checkTex:SetWidth(14)
    checkTex:SetHeight(14)
    checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkTex:Hide()
    cb.checkTex = checkTex

    if text then
        local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        lbl:SetText(text)
        cb.label = lbl
    end

    cb:SetScript("OnClick", function()
        if not isViewingSelf then return end
        local isChecked = not (this.isChecked == true)
        this.isChecked = isChecked
        if isChecked then
            this.checkTex:Show()
            this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        else
            this.checkTex:Hide()
            this:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)
        end
        if onClickCallback then
            onClickCallback(isChecked)
        end
    end)

    function cb:SetChecked(checked)
        self.isChecked = (checked == true or checked == "1" or checked == 1)
        if self.isChecked then
            self.checkTex:Show()
            self:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        else
            self.checkTex:Hide()
            self:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)
        end
    end

    return cb
end

--------------------------------------------------------------------------------
-- Custom Dark Styled Dropdown Menu Component
--------------------------------------------------------------------------------
local function CreateStyledDropdown(parent, width, height, optionsList, onSelectCallback)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width or 180)
    btn:SetHeight(height or 22)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    btn:SetBackdropBorderColor(0.30, 0.30, 0.38, 1.0)

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
    txt:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    txt:SetJustifyH("LEFT")
    txt:SetText("Select...")
    btn.text = txt

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("|cff00ccffv|r")
    btn.arrow = arrow

    -- Dropdown Menu Container
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(width or 180)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    menu:SetBackdropColor(0.06, 0.06, 0.09, 0.98)
    menu:SetBackdropBorderColor(0.0, 0.75, 1.0, 1.0)
    menu:Hide()
    menu:EnableMouse(true)
    btn.menu = menu

    btn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.09, 0.11, 0.16, 1.0)
        this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
    end)
    btn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
        this:SetBackdropBorderColor(0.30, 0.30, 0.38, 1.0)
    end)

    btn:SetScript("OnClick", function()
        if not isViewingSelf then return end
        if openDropdownMenu and openDropdownMenu ~= menu then
            openDropdownMenu:Hide()
        end
        if menu:IsShown() then
            menu:Hide()
            openDropdownMenu = nil
        else
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            menu:Show()
            openDropdownMenu = menu
        end
    end)

    function btn:SetOptions(opts, currentKey)
        self.options = opts or {}
        local count = 0
        for _ in pairs(opts) do count = count + 1 end
        menu:SetHeight(math.min(240, math.max(30, count * 20 + 6)))

        -- Clear old item buttons
        if menu.itemButtons then
            for _, b in ipairs(menu.itemButtons) do b:Hide() end
        end
        menu.itemButtons = {}

        local sortedKeys = {}
        for k in pairs(opts) do table.insert(sortedKeys, k) end
        table.sort(sortedKeys)

        local rowIdx = 0
        for _, k in ipairs(sortedKeys) do
            local valText = opts[k]
            local itemBtn = CreateFrame("Button", nil, menu)
            itemBtn:SetWidth((width or 180) - 4)
            itemBtn:SetHeight(18)
            itemBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(rowIdx * 19 + 3))

            local iTxt = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            iTxt:SetPoint("LEFT", itemBtn, "LEFT", 6, 0)
            iTxt:SetText(valText)
            itemBtn.text = iTxt
            itemBtn.optKey = k
            itemBtn.optVal = valText

            itemBtn:SetScript("OnEnter", function()
                this.text:SetTextColor(0.0, 1.0, 1.0)
            end)
            itemBtn:SetScript("OnLeave", function()
                this.text:SetTextColor(1.0, 1.0, 1.0)
            end)
            itemBtn:SetScript("OnClick", function()
                btn.selectedKey = this.optKey
                btn.text:SetText(this.optVal)
                menu:Hide()
                openDropdownMenu = nil
                if onSelectCallback then
                    onSelectCallback(this.optKey, this.optVal)
                end
            end)

            table.insert(menu.itemButtons, itemBtn)
            rowIdx = rowIdx + 1
        end

        if currentKey and opts[currentKey] then
            self.selectedKey = currentKey
            self.text:SetText(opts[currentKey])
        elseif currentKey and type(currentKey) == "string" then
            self.text:SetText(currentKey)
        end
    end

    function btn:SetSelected(key, fallbackText)
        self.selectedKey = key
        if self.options and self.options[key] then
            self.text:SetText(self.options[key])
        elseif fallbackText then
            self.text:SetText(fallbackText)
        else
            self.text:SetText(tostring(key or "Select..."))
        end
    end

    return btn
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

    -- Character Full RP Name & Title Display
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

    -- IC / OOC Status Toggle Button
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

    -- Preview Card Button
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
    local contentBox = Create1PxBackdrop(f, 0.05, 0.05, 0.07, 0.95, 0.22, 0.22, 0.26, 1.0)
    contentBox:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -144)
    contentBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    f.contentBox = contentBox

    ----------------------------------------------------------------------------
    -- TAB 1: IDENTITY & DEMOGRAPHICS
    ----------------------------------------------------------------------------
    local p1 = CreateFrame("Frame", nil, contentBox)
    p1:SetAllPoints(contentBox)
    f.panel1 = p1

    -- Row 1: First Name, Middle Name, Last Name
    local fnLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fnLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -8)
    fnLabel:SetText("|cff00e5ffFirst Name:|r")
    local fnEB = CreateStyledEditBox(p1, 155, 20)
    fnEB:SetPoint("TOPLEFT", fnLabel, "BOTTOMLEFT", 0, -2)
    fnEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.first_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.fnEB = fnEB

    local mnLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mnLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 172, -8)
    mnLabel:SetText("|cff00e5ffMiddle Name:|r")
    local mnEB = CreateStyledEditBox(p1, 155, 20)
    mnEB:SetPoint("TOPLEFT", mnLabel, "BOTTOMLEFT", 0, -2)
    mnEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.middle_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.mnEB = mnEB

    local lnLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lnLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 334, -8)
    lnLabel:SetText("|cff00e5ffSurname / Last:|r")
    local lnEB = CreateStyledEditBox(p1, 155, 20)
    lnEB:SetPoint("TOPLEFT", lnLabel, "BOTTOMLEFT", 0, -2)
    lnEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.last_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.lnEB = lnEB

    -- Row 2: Prefix, Nickname, House Name
    local pfxLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pfxLabel:SetPoint("TOPLEFT", fnEB, "BOTTOMLEFT", 0, -6)
    pfxLabel:SetText("|cff00e5ffPrefix (e.g. Sir):|r")
    local pfxEB = CreateStyledEditBox(p1, 155, 20)
    pfxEB:SetPoint("TOPLEFT", pfxLabel, "BOTTOMLEFT", 0, -2)
    pfxEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.prefix = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.pfxEB = pfxEB

    local nickLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nickLabel:SetPoint("TOPLEFT", mnEB, "BOTTOMLEFT", 0, -6)
    nickLabel:SetText("|cff00e5ffNickname / Alias:|r")
    local nickEB = CreateStyledEditBox(p1, 155, 20)
    nickEB:SetPoint("TOPLEFT", nickLabel, "BOTTOMLEFT", 0, -2)
    nickEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.nickname = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.nickEB = nickEB

    local houseLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    houseLabel:SetPoint("TOPLEFT", lnEB, "BOTTOMLEFT", 0, -6)
    houseLabel:SetText("|cff00e5ffHouse / Clan Name:|r")
    local houseEB = CreateStyledEditBox(p1, 155, 20)
    houseEB:SetPoint("TOPLEFT", houseLabel, "BOTTOMLEFT", 0, -2)
    houseEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.house_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.houseEB = houseEB

    -- Row 3: Title / Epithet
    local ttlLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ttlLabel:SetPoint("TOPLEFT", pfxEB, "BOTTOMLEFT", 0, -6)
    ttlLabel:SetText("|cff00e5ffTitle / Honorific / Epithet:|r")
    local ttlEB = CreateStyledEditBox(p1, 479, 20)
    ttlEB:SetPoint("TOPLEFT", ttlLabel, "BOTTOMLEFT", 0, -2)
    ttlEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.title = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.ttlEB = ttlEB

    -- Row 4: Apparent Age, Gender Identity Dropdown
    local ageLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ageLabel:SetPoint("TOPLEFT", ttlEB, "BOTTOMLEFT", 0, -8)
    ageLabel:SetText("|cff00e5ffApparent Age:|r")
    local ageEB = CreateStyledEditBox(p1, 230, 20)
    ageEB:SetPoint("TOPLEFT", ageLabel, "BOTTOMLEFT", 0, -2)
    ageEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.apparent_age = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.ageEB = ageEB

    local genderLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    genderLabel:SetPoint("TOPLEFT", ageLabel, "TOPLEFT", 245, 0)
    genderLabel:SetText("|cff00e5ffGender Identity:|r")
    local genderDropdown = CreateStyledDropdown(p1, 234, 20, PUIRoleplay.DropdownOptions.gender or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.gender_identity = optVal
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    genderDropdown:SetPoint("TOPLEFT", genderLabel, "BOTTOMLEFT", 0, -2)
    p1.genderDropdown = genderDropdown

    -- Row 5: IC Pronouns, OOC Pronouns
    local icPrLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icPrLabel:SetPoint("TOPLEFT", ageEB, "BOTTOMLEFT", 0, -6)
    icPrLabel:SetText("|cff00e5ffIC Pronouns (e.g. He/Him, They/Them):|r")
    local icPrEB = CreateStyledEditBox(p1, 230, 20)
    icPrEB:SetPoint("TOPLEFT", icPrLabel, "BOTTOMLEFT", 0, -2)
    icPrEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ic_pronouns = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.icPrEB = icPrEB

    local oocPrLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oocPrLabel:SetPoint("TOPLEFT", icPrLabel, "TOPLEFT", 245, 0)
    oocPrLabel:SetText("|cff00e5ffOOC Pronouns:|r")
    local oocPrEB = CreateStyledEditBox(p1, 234, 20)
    oocPrEB:SetPoint("TOPLEFT", oocPrLabel, "BOTTOMLEFT", 0, -2)
    oocPrEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ooc_pronouns = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.oocPrEB = oocPrEB

    -- Row 6: LGBTQIA+ Friendly Checkbox & Rainbow Badge
    local lgbtqBox = CreateStyledCheckbox(p1, "|cffff0000L|cffff7f00G|cffffff00B|cff00ff00T|cff0000ffQ|cff4b0082I|cff9400d3A+|r Friendly / Inclusive Safe Space Profile", function(checked)
        local p = PUIRoleplay:GetMyProfile()
        p.lgbtqia_friendly = checked
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    lgbtqBox:SetPoint("TOPLEFT", icPrEB, "BOTTOMLEFT", 0, -12)
    p1.lgbtqBox = lgbtqBox

    -- Row 7: Sexual / Romantic Orientation Dropdown & Privacy Toggle
    local oriLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oriLabel:SetPoint("TOPLEFT", lgbtqBox, "BOTTOMLEFT", 0, -10)
    oriLabel:SetText("|cff00e5ffSexual / Romantic Orientation:|r")
    local oriDropdown = CreateStyledDropdown(p1, 230, 20, PUIRoleplay.DropdownOptions.orientation or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.orientation = optVal
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    oriDropdown:SetPoint("TOPLEFT", oriLabel, "BOTTOMLEFT", 0, -2)
    p1.oriDropdown = oriDropdown

    local showOriBox = CreateStyledCheckbox(p1, "Display Orientation on Matchmaking Directory Card", function(checked)
        local p = PUIRoleplay:GetMyProfile()
        p.show_orientation = checked
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    showOriBox:SetPoint("TOPLEFT", oriDropdown, "TOPRIGHT", 15, 0)
    p1.showOriBox = showOriBox

    ----------------------------------------------------------------------------
    -- TAB 2: APPEARANCE & PHYSICALS & 5 GLANCES
    ----------------------------------------------------------------------------
    local p2 = CreateFrame("Frame", nil, contentBox)
    p2:SetAllPoints(contentBox)
    p2:Hide()
    f.panel2 = p2

    -- Row 1: Eye Color, Height, Weight, Build
    local eyeLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eyeLabel:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -8)
    eyeLabel:SetText("|cff00e5ffEye Color:|r")
    local eyeEB = CreateStyledEditBox(p2, 112, 20)
    eyeEB:SetPoint("TOPLEFT", eyeLabel, "BOTTOMLEFT", 0, -2)
    eyeEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.eye_color = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.eyeEB = eyeEB

    local hLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hLabel:SetPoint("TOPLEFT", p2, "TOPLEFT", 130, -8)
    hLabel:SetText("|cff00e5ffHeight:|r")
    local hEB = CreateStyledEditBox(p2, 112, 20)
    hEB:SetPoint("TOPLEFT", hLabel, "BOTTOMLEFT", 0, -2)
    hEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.height = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.hEB = hEB

    local wLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wLabel:SetPoint("TOPLEFT", p2, "TOPLEFT", 250, -8)
    wLabel:SetText("|cff00e5ffWeight:|r")
    local wEB = CreateStyledEditBox(p2, 112, 20)
    wEB:SetPoint("TOPLEFT", wLabel, "BOTTOMLEFT", 0, -2)
    wEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.weight = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.wEB = wEB

    local bLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bLabel:SetPoint("TOPLEFT", p2, "TOPLEFT", 370, -8)
    bLabel:SetText("|cff00e5ffBody Build:|r")
    local bEB = CreateStyledEditBox(p2, 118, 20)
    bEB:SetPoint("TOPLEFT", bLabel, "BOTTOMLEFT", 0, -2)
    bEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.body_build = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.bEB = bEB

    -- Row 2: Current Emotion / Expression
    local emoLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emoLabel:SetPoint("TOPLEFT", eyeEB, "BOTTOMLEFT", 0, -6)
    emoLabel:SetText("|cff00e5ffCurrent Emotion / Expression:|r")
    local emoEB = CreateStyledEditBox(p2, 478, 20)
    emoEB:SetPoint("TOPLEFT", emoLabel, "BOTTOMLEFT", 0, -2)
    emoEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.current_emotion = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.emoEB = emoEB

    -- Row 3: Physical Description Scrollbox (Compact)
    local descLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", emoEB, "BOTTOMLEFT", 0, -6)
    descLabel:SetText("|cff55ff88Physical Appearance Description:|r")

    local descCount = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descCount:SetPoint("TOPRIGHT", p2, "TOPRIGHT", -12, -74)
    descCount:SetText("0 / 1000")
    p2.descCount = descCount

    local descScrollBg = Create1PxBackdrop(p2, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
    descScrollBg:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -2)
    descScrollBg:SetWidth(478)
    descScrollBg:SetHeight(75)

    local descScroll = CreateFrame("ScrollFrame", "Primus_PUIRPSheet_DescScroll", p2, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", descScrollBg, "TOPLEFT", 4, -4)
    descScroll:SetPoint("BOTTOMRIGHT", descScrollBg, "BOTTOMRIGHT", -22, 4)

    local descEB = CreateFrame("EditBox", nil, descScroll)
    descEB:SetWidth(446)
    descEB:SetHeight(500)
    descEB:SetMultiLine(true)
    descEB:SetMaxLetters(1000)
    descEB:SetAutoFocus(false)
    descEB:SetFontObject(GameFontHighlightSmall)
    descEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    descEB:SetTextInsets(4, 4, 4, 4)
    descScroll:SetScrollChild(descEB)
    p2.descEB = descEB

    descScrollBg:SetScript("OnMouseDown", function() if isViewingSelf then descEB:SetFocus() end end)
    descEB:SetScript("OnTextChanged", function()
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(descScroll) end
        local len = string.len(this:GetText() or "")
        p2.descCount:SetText(len .. " / 1000")
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.appearance_desc = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    descEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    -- Row 4: 5 At-A-Glance Visual Trait Cards
    local glanceHeader = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glanceHeader:SetPoint("TOPLEFT", descScrollBg, "BOTTOMLEFT", 0, -8)
    glanceHeader:SetText("|cffffd100AT A GLANCE TRAITS (5 Visual Cards):|r")

    p2.glanceCards = {}
    for i = 1, 5 do
        local card = Create1PxBackdrop(p2, 0.05, 0.05, 0.07, 0.95, 0.22, 0.24, 0.28, 1.0)
        card:SetWidth(478)
        card:SetHeight(44)
        card:SetPoint("TOPLEFT", glanceHeader, "BOTTOMLEFT", 0, -4 - (i - 1) * 48)

        local gBtn = CreateFrame("Button", nil, card)
        gBtn:SetWidth(32)
        gBtn:SetHeight(32)
        gBtn:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
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
                    local p = PUIRoleplay:GetMyProfile()
                    if not p.glances then p.glances = {} end
                    if not p.glances[idx] then p.glances[idx] = {} end
                    local iconName = PUIRoleplay.Icons[selectedIconIndex] or "INV_Misc_QuestionMark"
                    p.glances[idx].icon = iconName
                    p["atAGlance" .. idx .. "Icon"] = tostring(selectedIconIndex)
                    p.keyT = PUIRoleplay:GenerateKey()
                    PUIRoleplay:SaveMyProfile(p)
                    Sheet:Refresh()
                end)
            end
        end)
        card.iconBtn = gBtn

        local gTitleEB = CreateStyledEditBox(card, 340, 16)
        gTitleEB:SetPoint("TOPLEFT", gBtn, "TOPRIGHT", 8, 0)
        gTitleEB:SetTextColor(1.0, 0.90, 0.30, 1.0)
        gTitleEB.cardIndex = i
        gTitleEB:SetScript("OnTextChanged", function()
            if isViewingSelf and f.isRefreshing ~= true then
                local p = PUIRoleplay:GetMyProfile()
                if not p.glances then p.glances = {} end
                if not p.glances[this.cardIndex] then p.glances[this.cardIndex] = {} end
                p.glances[this.cardIndex].title = this:GetText()
                p["atAGlance" .. this.cardIndex .. "Title"] = this:GetText()
                p.keyT = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(p)
            end
        end)
        card.titleEB = gTitleEB

        local gDescEB = CreateStyledEditBox(card, 340, 16)
        gDescEB:SetPoint("TOPLEFT", gTitleEB, "BOTTOMLEFT", 0, -2)
        gDescEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
        gDescEB.cardIndex = i
        gDescEB:SetScript("OnTextChanged", function()
            if isViewingSelf and f.isRefreshing ~= true then
                local p = PUIRoleplay:GetMyProfile()
                if not p.glances then p.glances = {} end
                if not p.glances[this.cardIndex] then p.glances[this.cardIndex] = {} end
                p.glances[this.cardIndex].text = this:GetText()
                p["atAGlance" .. this.cardIndex] = this:GetText()
                p.keyT = PUIRoleplay:GenerateKey()
                PUIRoleplay:SaveMyProfile(p)
            end
        end)
        card.descEB = gDescEB

        local activeCB = CreateStyledCheckbox(card, "Active", function(checked)
            local p = PUIRoleplay:GetMyProfile()
            if not p.glances then p.glances = {} end
            if not p.glances[i] then p.glances[i] = {} end
            p.glances[i].active = checked
            p.keyT = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end)
        activeCB:SetPoint("RIGHT", card, "RIGHT", -60, 0)
        card.activeCB = activeCB

        p2.glanceCards[i] = card
    end

    ----------------------------------------------------------------------------
    -- TAB 3: LORE & 6-CHAPTER HISTORY
    ----------------------------------------------------------------------------
    local p3 = CreateFrame("Frame", nil, contentBox)
    p3:SetAllPoints(contentBox)
    p3:Hide()
    f.panel3 = p3

    local bCityLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bCityLabel:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -8)
    bCityLabel:SetText("|cff00e5ffBirth City / Origin:|r")
    local bCityEB = CreateStyledEditBox(p3, 230, 20)
    bCityEB:SetPoint("TOPLEFT", bCityLabel, "BOTTOMLEFT", 0, -2)
    bCityEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.birth_city = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p3.bCityEB = bCityEB

    local hCityLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hCityLabel:SetPoint("TOPLEFT", bCityLabel, "TOPLEFT", 245, 0)
    hCityLabel:SetText("|cff00e5ffHome City / Residence:|r")
    local hCityEB = CreateStyledEditBox(p3, 234, 20)
    hCityEB:SetPoint("TOPLEFT", hCityLabel, "BOTTOMLEFT", 0, -2)
    hCityEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.home_city = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p3.hCityEB = hCityEB

    local mottoLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mottoLabel:SetPoint("TOPLEFT", bCityEB, "BOTTOMLEFT", 0, -6)
    mottoLabel:SetText("|cff00e5ffPersonal Motto / Creed / Battlecry:|r")
    local mottoEB = CreateStyledEditBox(p3, 479, 20)
    mottoEB:SetPoint("TOPLEFT", mottoLabel, "BOTTOMLEFT", 0, -2)
    mottoEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.motto = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p3.mottoEB = mottoEB

    local facLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    facLabel:SetPoint("TOPLEFT", mottoEB, "BOTTOMLEFT", 0, -6)
    facLabel:SetText("|cff00e5ffFaction / Clan / Order Allegiance:|r")
    local facEB = CreateStyledEditBox(p3, 479, 20)
    facEB:SetPoint("TOPLEFT", facLabel, "BOTTOMLEFT", 0, -2)
    facEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.faction_clan = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p3.facEB = facEB

    -- 6 History Chapter Tabs
    local histHeader = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    histHeader:SetPoint("TOPLEFT", facEB, "BOTTOMLEFT", 0, -10)
    histHeader:SetText("|cffffd100CHARACTER CHRONICLES & HISTORY (6 Chapters):|r")

    local chapterTitles = {
        "Chapter 1: Early Years / Origins",
        "Chapter 2: The First Trials",
        "Chapter 3: Recent Events",
        "Chapter 4: Notable Deeds",
        "Chapter 5: Personal Beliefs",
        "Chapter 6: Current Goals"
    }

    local chBtns = {}
    for i = 1, 6 do
        local cBtn = CreateFrame("Button", nil, p3)
        cBtn:SetWidth(76)
        cBtn:SetHeight(20)
        cBtn:SetPoint("TOPLEFT", histHeader, "BOTTOMLEFT", (i - 1) * 80, -4)
        cBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        cBtn:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
        cBtn:SetBackdropBorderColor(0.25, 0.25, 0.32, 1.0)

        local cbTxt = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cbTxt:SetPoint("CENTER", cBtn, "CENTER", 0, 0)
        cbTxt:SetText("Ch " .. i)
        cBtn.text = cbTxt
        cBtn.chapterIdx = i

        cBtn:SetScript("OnClick", function()
            activeLoreChapter = this.chapterIdx
            Sheet:SelectLoreChapter(this.chapterIdx)
        end)
        chBtns[i] = cBtn
    end
    p3.chBtns = chBtns

    local chTitleLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chTitleLabel:SetPoint("TOPLEFT", chBtns[1], "BOTTOMLEFT", 0, -8)
    chTitleLabel:SetText("|cff00e5ffChapter 1: Early Years / Origins|r")
    p3.chTitleLabel = chTitleLabel

    local chCount = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chCount:SetPoint("TOPRIGHT", p3, "TOPRIGHT", -12, -210)
    chCount:SetText("0 / 1000")
    p3.chCount = chCount

    local chScrollBg = Create1PxBackdrop(p3, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
    chScrollBg:SetPoint("TOPLEFT", chTitleLabel, "BOTTOMLEFT", 0, -2)
    chScrollBg:SetWidth(479)
    chScrollBg:SetHeight(180)

    local chScroll = CreateFrame("ScrollFrame", "Primus_PUIRPSheet_ChScroll", p3, "UIPanelScrollFrameTemplate")
    chScroll:SetPoint("TOPLEFT", chScrollBg, "TOPLEFT", 4, -4)
    chScroll:SetPoint("BOTTOMRIGHT", chScrollBg, "BOTTOMRIGHT", -22, 4)

    local chEB = CreateFrame("EditBox", nil, chScroll)
    chEB:SetWidth(446)
    chEB:SetHeight(800)
    chEB:SetMultiLine(true)
    chEB:SetMaxLetters(1000)
    chEB:SetAutoFocus(false)
    chEB:SetFontObject(GameFontHighlightSmall)
    chEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    chEB:SetTextInsets(4, 4, 4, 4)
    chScroll:SetScrollChild(chEB)
    p3.chEB = chEB

    chScrollBg:SetScript("OnMouseDown", function() if isViewingSelf then chEB:SetFocus() end end)
    chEB:SetScript("OnTextChanged", function()
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(chScroll) end
        local len = string.len(this:GetText() or "")
        p3.chCount:SetText(len .. " / 1000")
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            if not p.history then p.history = {} end
            p.history["chapter" .. activeLoreChapter] = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    chEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    ----------------------------------------------------------------------------
    -- TAB 4: ROLEPLAY STYLE & DYNAMICS
    ----------------------------------------------------------------------------
    local p4 = CreateFrame("Frame", nil, contentBox)
    p4:SetAllPoints(contentBox)
    p4:Hide()
    f.panel4 = p4

    local styleSections = {
        { key = "experience_level", label = "Roleplay Experience Level:", opts = PUIRoleplay.DropdownOptions.experience },
        { key = "walkup_policy", label = "Walk-Up Preferences & Policy:", opts = PUIRoleplay.DropdownOptions.walkups },
        { key = "combat_preference", label = "Combat & Conflict Resolution:", opts = PUIRoleplay.DropdownOptions.combat },
        { key = "injury_consent", label = "Character Injury Tolerance:", opts = PUIRoleplay.DropdownOptions.injury },
        { key = "permadeath_consent", label = "Character Death Willingness (Permadeath):", opts = PUIRoleplay.DropdownOptions.death }
    }

    p4.dropdowns = {}
    local curStyleY = -10
    for _, sec in ipairs(styleSections) do
        local card = Create1PxBackdrop(p4, 0.05, 0.05, 0.07, 0.8, 0.20, 0.22, 0.26, 1.0)
        card:SetWidth(478)
        card:SetHeight(52)
        card:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, curStyleY)

        local sLbl = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        sLbl:SetText("|cff00e5ff" .. sec.label .. "|r")

        local dd = CreateStyledDropdown(card, 460, 22, sec.opts or {}, function(optKey, optVal)
            local p = PUIRoleplay:GetMyProfile()
            p[sec.key] = optVal
            p.keyT = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end)
        dd:SetPoint("TOPLEFT", sLbl, "BOTTOMLEFT", 0, -2)
        p4.dropdowns[sec.key] = dd

        curStyleY = curStyleY - 58
    end

    ----------------------------------------------------------------------------
    -- TAB 5: DATING & MATCHMAKING CARD (18+ & ERP BOUNDARIES)
    ----------------------------------------------------------------------------
    local p5 = CreateFrame("Frame", nil, contentBox)
    p5:SetAllPoints(contentBox)
    p5:Hide()
    f.panel5 = p5

    local relLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    relLabel:SetPoint("TOPLEFT", p5, "TOPLEFT", 10, -8)
    relLabel:SetText("|cff00e5ffIC Relationship Status:|r")
    local relDropdown = CreateStyledDropdown(p5, 230, 22, PUIRoleplay.DropdownOptions.relationship or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.relationship_status = optVal
        p.keyX = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    relDropdown:SetPoint("TOPLEFT", relLabel, "BOTTOMLEFT", 0, -2)
    p5.relDropdown = relDropdown

    -- Looking For Matrix
    local lfLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lfLabel:SetPoint("TOPLEFT", relDropdown, "BOTTOMLEFT", 0, -10)
    lfLabel:SetText("|cffffd100Looking For / Open To (Directory Badges):|r")

    local lookingForList = {
        { key = "adventure", label = "|cff00ff88[Adventure & Quests]|r" },
        { key = "romance", label = "|cffff80cc[Romance & Dating]|r" },
        { key = "casual_tavern", label = "|cffffcc00[Casual Tavern RP]|r" },
        { key = "combat", label = "|cffff4444[Combat & Sparring]|r" },
        { key = "political_guild", label = "|cff00ccff[Guild & Politics]|r" },
        { key = "mentorship", label = "|cffb080ff[Mentorship / Student]|r" }
    }

    p5.lfCheckboxes = {}
    for idx, item in ipairs(lookingForList) do
        local col = math.mod(idx - 1, 2)
        local row = math.floor((idx - 1) / 2)
        local cb = CreateStyledCheckbox(p5, item.label, function(checked)
            local p = PUIRoleplay:GetMyProfile()
            if not p.looking_for then p.looking_for = {} end
            p.looking_for[item.key] = checked
            p.keyX = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end)
        cb:SetPoint("TOPLEFT", lfLabel, "BOTTOMLEFT", col * 240, -4 - row * 22)
        p5.lfCheckboxes[item.key] = cb
    end

    -- 18+ Section Card
    local adultCard = Create1PxBackdrop(p5, 0.08, 0.04, 0.05, 0.95, 0.50, 0.18, 0.22, 1.0)
    adultCard:SetWidth(478)
    adultCard:SetHeight(160)
    adultCard:SetPoint("TOPLEFT", lfLabel, "BOTTOMLEFT", 0, -80)

    local adultTitle = adultCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adultTitle:SetPoint("TOPLEFT", adultCard, "TOPLEFT", 8, -6)
    adultTitle:SetText("|cffff335518+ ADULT-ORIENTED RP & ERP BOUNDARIES:|r")

    local adultFlagCB = CreateStyledCheckbox(adultCard, "|cffff4466[18+] Explicit Adult-Oriented Roleplay Profile|r", function(checked)
        local p = PUIRoleplay:GetMyProfile()
        p.adult_18plus_flag = checked
        if not p.looking_for then p.looking_for = {} end
        p.looking_for.adult_18plus = checked
        p.keyX = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    adultFlagCB:SetPoint("TOPLEFT", adultTitle, "BOTTOMLEFT", 0, -4)
    p5.adultFlagCB = adultFlagCB

    local erpLabel = adultCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    erpLabel:SetPoint("TOPLEFT", adultFlagCB, "BOTTOMLEFT", 0, -6)
    erpLabel:SetText("|cff00e5ffERP Preference & Tone:|r")

    local erpDropdown = CreateStyledDropdown(adultCard, 460, 20, PUIRoleplay.DropdownOptions.erp or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.erp_preference = optVal
        p.keyX = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    erpDropdown:SetPoint("TOPLEFT", erpLabel, "BOTTOMLEFT", 0, -2)
    p5.erpDropdown = erpDropdown

    local bndLabel = adultCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bndLabel:SetPoint("TOPLEFT", erpDropdown, "BOTTOMLEFT", 0, -6)
    bndLabel:SetText("|cffffaa44OOC Safety, Triggers & Comfort Boundaries:|r")

    local bndEB = CreateStyledEditBox(adultCard, 460, 20)
    bndEB:SetPoint("TOPLEFT", bndLabel, "BOTTOMLEFT", 0, -2)
    bndEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ooc_boundaries = this:GetText()
            p.keyX = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p5.bndEB = bndEB

    ----------------------------------------------------------------------------
    -- TAB 6: PROFILES & NOTES
    ----------------------------------------------------------------------------
    local p6 = CreateFrame("Frame", nil, contentBox)
    p6:SetAllPoints(contentBox)
    p6:Hide()
    f.panel6 = p6

    local profHeader = p6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profHeader:SetPoint("TOPLEFT", p6, "TOPLEFT", 10, -8)
    profHeader:SetText("|cff00e5ffCharacter Profile Slots (Saved per Character):|r")

    p6.profBtns = {}
    for i = 0, 3 do
        local pBtn = CreateFrame("Button", nil, p6)
        pBtn:SetWidth(110)
        pBtn:SetHeight(24)
        pBtn:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", i * 118, -6)
        pBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })

        local pbText = pBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pbText:SetPoint("CENTER", pBtn, "CENTER", 0, 0)
        pbText:SetText("Profile " .. i)
        pBtn.text = pbText
        pBtn.slot = tostring(i)

        pBtn:SetScript("OnClick", function()
            if isViewingSelf then
                PUIRoleplay:SetActiveProfileSlot(this.slot)
                Sheet:Refresh()
            end
        end)
        p6.profBtns[i] = pBtn
    end

    local oocHeader = p6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oocHeader:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", 0, -42)
    oocHeader:SetText("|cff55ff88Public OOC Notes (Broadcasted over Wire):|r")

    local oocEB = CreateStyledEditBox(p6, 478, 20)
    oocEB:SetPoint("TOPLEFT", oocHeader, "BOTTOMLEFT", 0, -2)
    oocEB:SetScript("OnTextChanged", function()
        if isViewingSelf and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ooc_notes = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p6.oocEB = oocEB

    local notesHeader = p6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notesHeader:SetPoint("TOPLEFT", oocEB, "BOTTOMLEFT", 0, -10)
    notesHeader:SetText("|cffffd100Private Character / GM Notes (Saved Locally):|r")

    local notesScrollBg = Create1PxBackdrop(p6, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
    notesScrollBg:SetPoint("TOPLEFT", notesHeader, "BOTTOMLEFT", 0, -4)
    notesScrollBg:SetPoint("BOTTOMRIGHT", p6, "BOTTOMRIGHT", -10, 10)

    local notesScroll = CreateFrame("ScrollFrame", "Primus_PUIRPSheet_NotesScroll", p6, "UIPanelScrollFrameTemplate")
    notesScroll:SetPoint("TOPLEFT", notesScrollBg, "TOPLEFT", 4, -4)
    notesScroll:SetPoint("BOTTOMRIGHT", notesScrollBg, "BOTTOMRIGHT", -22, 4)

    local notesEB = CreateFrame("EditBox", nil, notesScroll)
    notesEB:SetWidth(446)
    notesEB:SetHeight(800)
    notesEB:SetMultiLine(true)
    notesEB:SetAutoFocus(false)
    notesEB:SetFontObject(GameFontHighlightSmall)
    notesEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
    notesEB:SetTextInsets(4, 4, 4, 4)
    notesScroll:SetScrollChild(notesEB)
    p6.notesEB = notesEB

    notesScrollBg:SetScript("OnMouseDown", function() notesEB:SetFocus() end)
    notesEB:SetScript("OnTextChanged", function()
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(notesScroll) end
        if f.isRefreshing ~= true then
            local target = targetPlayerName or UnitName("player")
            PUIRoleplay:SetCharacterNote(target, this:GetText())
        end
    end)
    notesEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    sheetFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Tab & Lore Navigation
--------------------------------------------------------------------------------
function Sheet:SelectTab(index)
    activeTab = index
    local f = self:BuildFrame()
    if openDropdownMenu then openDropdownMenu:Hide(); openDropdownMenu = nil end

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
    activeLoreChapter = idx
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
    Sheet:SelectLoreChapter(activeLoreChapter)

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

--------------------------------------------------------------------------------
-- Dating & Matchmaking Profile Preview Card Modal
--------------------------------------------------------------------------------
local cardPreviewFrame = nil

function Sheet:OpenCardPreviewModal(targetName)
    local target = targetName or UnitName("player")
    local isSelf = (target == UnitName("player"))
    local data = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(target)
    if not data then data = {} end

    if not cardPreviewFrame then
        local p = CreateFrame("Frame", "Primus_PUIRPSheet_CardPreview", sheetFrame)
        p:SetWidth(380)
        p:SetHeight(480)
        p:SetPoint("CENTER", sheetFrame, "CENTER", 0, 0)
        p:SetFrameStrata("DIALOG")
        p:EnableMouse(true)
        p:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        p:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
        p:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        table.insert(UISpecialFrames, "Primus_PUIRPSheet_CardPreview")

        local closeBtn = CreateFrame("Button", nil, p)
        closeBtn:SetWidth(16)
        closeBtn:SetHeight(16)
        closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() p:Hide() end)

        -- Avatar Card Image
        local avBg = Create1PxBackdrop(p, 0, 0, 0, 1, 0.35, 0.35, 0.45, 1)
        avBg:SetWidth(80)
        avBg:SetHeight(80)
        avBg:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)

        local avTex = avBg:CreateTexture(nil, "ARTWORK")
        avTex:SetPoint("TOPLEFT", avBg, "TOPLEFT", 2, -2)
        avTex:SetPoint("BOTTOMRIGHT", avBg, "BOTTOMRIGHT", -2, 2)
        p.avTex = avTex

        local nameText = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", avBg, "TOPRIGHT", 12, 0)
        p.nameText = nameText

        local titleText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        titleText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
        titleText:SetTextColor(0.0, 0.85, 1.0)
        p.titleText = titleText

        local demoPill = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        demoPill:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
        p.demoPill = demoPill

        local relText = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        relText:SetPoint("TOPLEFT", demoPill, "BOTTOMLEFT", 0, -3)
        p.relText = relText

        local sep = Create1PxBackdrop(p, 0.2, 0.25, 0.35, 0.8, 0, 0, 0, 0)
        sep:SetPoint("TOPLEFT", avBg, "BOTTOMLEFT", 0, -10)
        sep:SetWidth(348)
        sep:SetHeight(1)

        local lfHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lfHeader:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -8)
        lfHeader:SetText("|cffffd100Looking For Activities:|r")

        local lfBadges = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lfBadges:SetPoint("TOPLEFT", lfHeader, "BOTTOMLEFT", 0, -3)
        lfBadges:SetWidth(348)
        lfBadges:SetJustifyH("LEFT")
        p.lfBadges = lfBadges

        local bioHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bioHeader:SetPoint("TOPLEFT", lfBadges, "BOTTOMLEFT", 0, -10)
        bioHeader:SetText("|cff00e5ffAbout & Glance:|r")

        local bioSummary = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bioSummary:SetPoint("TOPLEFT", bioHeader, "BOTTOMLEFT", 0, -3)
        bioSummary:SetWidth(348)
        bioSummary:SetJustifyH("LEFT")
        p.bioSummary = bioSummary

        cardPreviewFrame = p
    end

    local p = cardPreviewFrame
    local iconIdx = tonumber(data.icon) or 1
    p.avTex:SetTexture("Interface\\Icons\\" .. (PUIRoleplay.Icons[iconIdx] or "INV_Misc_QuestionMark"))

    local fullRPName = data.full_name or target
    if data.first_name and data.first_name ~= "" then
        fullRPName = data.first_name .. (data.last_name and (" " .. data.last_name) or "")
    end
    p.nameText:SetText("|cffffffff" .. fullRPName .. "|r")

    local titleStr = (data.title and data.title ~= "") and ("<" .. data.title .. ">") or ""
    p.titleText:SetText(titleStr)

    local age = data.apparent_age or "Unknown Age"
    local ori = (data.show_orientation ~= false and data.orientation) or "Private"
    local lgbtq = (data.lgbtqia_friendly ~= false) and " |cffff0000[|cffff7f00LGBTQIA+|cff9400d3]|r" or ""
    local adult18 = (data.adult_18plus_flag == true) and " |cffff3355[18+]|r" or ""
    p.demoPill:SetText(string.format("|cff00ccff[%s]|r |cffff80cc[%s]|r%s%s", age, ori, lgbtq, adult18))

    p.relText:SetText("Status: |cffffffff" .. (data.relationship_status or "Single") .. "|r")

    -- Format looking for badges
    local lfStr = ""
    local lf = data.looking_for or {}
    if lf.adventure then lfStr = lfStr .. " |cff00ff88[Adventure]|r" end
    if lf.romance then lfStr = lfStr .. " |cffff80cc[Romance]|r" end
    if lf.casual_tavern then lfStr = lfStr .. " |cffffcc00[Tavern]|r" end
    if lf.combat then lfStr = lfStr .. " |cffff4444[Combat]|r" end
    if lf.political_guild then lfStr = lfStr .. " |cff00ccff[Guild]|r" end
    if lf.mentorship then lfStr = lfStr .. " |cffb080ff[Mentorship]|r" end
    if lfStr == "" then lfStr = "|cff888888No preferences listed|r" end
    p.lfBadges:SetText(lfStr)

    -- About / Glance snippet
    local snippet = data.current_emotion and ("Expression: \"" .. data.current_emotion .. "\"\n") or ""
    if data.appearance_desc and data.appearance_desc ~= "" then
        snippet = snippet .. string.sub(data.appearance_desc, 1, 200) .. "..."
    elseif data.description and data.description ~= "" then
        snippet = snippet .. string.sub(data.description, 1, 200) .. "..."
    else
        snippet = snippet .. "No description provided."
    end
    p.bioSummary:SetText(snippet)

    p:Show()
end

--------------------------------------------------------------------------------
-- Icon Picker Modal (Virtualized 2,020+ Icon Browser & Search Engine)
--------------------------------------------------------------------------------
local iconPickerFrame = nil
local GRID_COLS = 8
local GRID_ROWS = 6
local ROW_STEP = 42

local ICON_CATEGORIES = {
    { id = "ALL",     label = "All" },
    { id = "SPELL",   label = "Spells" },
    { id = "ABILITY", label = "Abilities" },
    { id = "GEAR",    label = "Gear" },
    { id = "ITEM",    label = "Items" },
    { id = "TRADE",   label = "Trade" }
}

local function MatchesIconCategory(iconName, category)
    if not category or category == "ALL" then return true end
    if not iconName then return false end
    if category == "SPELL" then
        return string.find(iconName, "^Spell_") ~= nil
    elseif category == "ABILITY" then
        return string.find(iconName, "^Ability_") ~= nil
    elseif category == "TRADE" then
        return string.find(iconName, "^Trade_") ~= nil
    elseif category == "GEAR" then
        return (string.find(iconName, "^INV_Sword")
            or string.find(iconName, "^INV_Axe")
            or string.find(iconName, "^INV_Mace")
            or string.find(iconName, "^INV_Shield")
            or string.find(iconName, "^INV_Helmet")
            or string.find(iconName, "^INV_Chest")
            or string.find(iconName, "^INV_Boots")
            or string.find(iconName, "^INV_Belt")
            or string.find(iconName, "^INV_Bracer")
            or string.find(iconName, "^INV_Gauntlets")
            or string.find(iconName, "^INV_Pants")
            or string.find(iconName, "^INV_Shoulder")
            or string.find(iconName, "^INV_Staff")
            or string.find(iconName, "^INV_Wand")
            or string.find(iconName, "^INV_Jewelry")
            or string.find(iconName, "^INV_Crown")
            or string.find(iconName, "^INV_Banner")
            or string.find(iconName, "^INV_Armor")
            or string.find(iconName, "^INV_Misc_Cape")
            or string.find(iconName, "^INV_Mask")
            or string.find(iconName, "^INV_Hammer")) ~= nil
    elseif category == "ITEM" then
        if string.find(iconName, "^Spell_") or string.find(iconName, "^Ability_") or string.find(iconName, "^Trade_") then
            return false
        end
        if MatchesIconCategory(iconName, "GEAR") then
            return false
        end
        return true
    end
    return true
end

function Sheet:UpdateIconPickerGrid()
    local p = iconPickerFrame
    if not p or not p.filteredIcons then return end

    local totalItems = table.getn(p.filteredIcons)
    local totalRows = math.ceil(totalItems / GRID_COLS)

    FauxScrollFrame_Update(p.scroll, totalRows, GRID_ROWS, ROW_STEP)
    local rowOffset = FauxScrollFrame_GetOffset(p.scroll)

    for slotIdx = 1, (GRID_COLS * GRID_ROWS) do
        local btn = p.buttons[slotIdx]
        local row = math.floor((slotIdx - 1) / GRID_COLS)
        local col = math.mod(slotIdx - 1, GRID_COLS)
        local dataIdx = ((rowOffset + row) * GRID_COLS) + col + 1

        if dataIdx <= totalItems then
            local item = p.filteredIcons[dataIdx]
            btn.iconIndex = item.index
            btn.iconName = item.name
            btn.tex:SetTexture("Interface\\Icons\\" .. item.name)

            if p.selectedIconIdx and p.selectedIconIdx == item.index then
                btn.selectedGlow:Show()
                btn:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
            else
                btn.selectedGlow:Hide()
                btn:SetBackdropBorderColor(0.25, 0.25, 0.32, 1.0)
            end

            btn:Show()
        else
            btn.iconIndex = nil
            btn.iconName = nil
            btn.selectedGlow:Hide()
            btn:Hide()
        end
    end

    if totalItems == 0 then
        p.statusText:SetText("|cffff5555No matching icons found|r")
    else
        p.statusText:SetText(string.format("|cff888899Showing %d of %d icons|r", totalItems, table.getn(PUIRoleplay.Icons or {})))
    end
end

function Sheet:FilterIconPicker(searchTerm)
    local p = iconPickerFrame
    if not p then return end

    p.filteredIcons = {}
    local q = string.lower(string.gsub(searchTerm or "", "^%s*(.-)%s*$", "%1"))
    local totalIcons = table.getn(PUIRoleplay.Icons or {})

    for i = 1, totalIcons do
        local iconName = PUIRoleplay.Icons[i]
        if iconName and MatchesIconCategory(iconName, p.activeCategory) then
            if q == "" or string.find(string.lower(iconName), q, 1, true) then
                table.insert(p.filteredIcons, { index = i, name = iconName })
            end
        end
    end

    FauxScrollFrame_SetOffset(p.scroll, 0)
    local scrollbar = getglobal("Primus_PUIRoleplay_IconScrollScrollBar")
    if scrollbar then scrollbar:SetValue(0) end

    Sheet:UpdateIconPickerGrid()
end

function Sheet:OpenIconPicker(onSelectCallback, currentSelectedIdx)
    if not iconPickerFrame then
        local p = CreateFrame("Frame", "Primus_PUIRoleplay_IconPicker", sheetFrame)
        p:SetWidth(410)
        p:SetHeight(380)
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
        table.insert(UISpecialFrames, "Primus_PUIRoleplay_IconPicker")

        local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
        title:SetText("|cff00ccffSelect Profile / Trait Icon|r")

        local close = CreateFrame("Button", nil, p)
        close:SetWidth(16)
        close:SetHeight(16)
        close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
        close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        close:SetScript("OnClick", function() p:Hide() end)

        local filterEB = CreateStyledEditBox(p, 386, 22)
        filterEB:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -28)
        filterEB:SetScript("OnTextChanged", function()
            Sheet:FilterIconPicker(this:GetText())
        end)
        filterEB:SetScript("OnEscapePressed", function()
            if this:GetText() ~= "" then
                this:SetText("")
                Sheet:FilterIconPicker("")
            else
                this:ClearFocus()
                p:Hide()
            end
        end)
        p.filterEB = filterEB

        p.categoryButtons = {}
        p.activeCategory = "ALL"

        local catBar = CreateFrame("Frame", nil, p)
        catBar:SetPoint("TOPLEFT", filterEB, "BOTTOMLEFT", 0, -5)
        catBar:SetWidth(386)
        catBar:SetHeight(20)

        local btnWidth = 61
        for cIdx, cat in ipairs(ICON_CATEGORIES) do
            local catBtn = CreateFrame("Button", nil, catBar)
            catBtn:SetWidth(btnWidth)
            catBtn:SetHeight(18)
            catBtn:SetPoint("TOPLEFT", catBar, "TOPLEFT", (cIdx - 1) * (btnWidth + 4), 0)
            catBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            catBtn:SetBackdropColor(0.07, 0.07, 0.10, 0.95)
            catBtn:SetBackdropBorderColor(0.22, 0.22, 0.28, 1.0)

            local btnText = catBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("CENTER", catBtn, "CENTER", 0, 0)
            btnText:SetText(cat.label)
            catBtn.text = btnText
            catBtn.catId = cat.id

            catBtn:SetScript("OnClick", function()
                p.activeCategory = this.catId
                for _, b in ipairs(p.categoryButtons) do
                    if b.catId == p.activeCategory then
                        b:SetBackdropColor(0.0, 0.35, 0.55, 0.95)
                        b:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
                        b.text:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    else
                        b:SetBackdropColor(0.07, 0.07, 0.10, 0.95)
                        b:SetBackdropBorderColor(0.22, 0.22, 0.28, 1.0)
                        b.text:SetTextColor(0.7, 0.7, 0.7, 1.0)
                    end
                end
                Sheet:FilterIconPicker(p.filterEB:GetText())
            end)

            table.insert(p.categoryButtons, catBtn)
        end

        local scrollBg = Create1PxBackdrop(p, 0.03, 0.03, 0.05, 1.0, 0.2, 0.2, 0.25, 1.0)
        scrollBg:SetPoint("TOPLEFT", catBar, "BOTTOMLEFT", 0, -4)
        scrollBg:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 28)

        local scroll = CreateFrame("ScrollFrame", "Primus_PUIRoleplay_IconScroll", p, "FauxScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", scrollBg, "TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -26, 4)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnVerticalScroll", function()
            FauxScrollFrame_OnVerticalScroll(ROW_STEP, function()
                Sheet:UpdateIconPickerGrid()
            end)
        end)
        scroll:SetScript("OnMouseWheel", function()
            local scrollbar = getglobal("Primus_PUIRoleplay_IconScrollScrollBar")
            if scrollbar and scrollbar:IsShown() then
                local current = scrollbar:GetValue()
                if arg1 > 0 then
                    scrollbar:SetValue(math.max(0, current - (ROW_STEP * 2)))
                else
                    local minVal, maxVal = scrollbar:GetMinMaxValues()
                    scrollbar:SetValue(math.min(maxVal, current + (ROW_STEP * 2)))
                end
            end
        end)
        p.scroll = scroll

        p.buttons = {}
        for row = 0, (GRID_ROWS - 1) do
            for col = 0, (GRID_COLS - 1) do
                local slotIdx = (row * GRID_COLS) + col + 1
                local b = CreateFrame("Button", nil, scroll)
                b:SetWidth(36)
                b:SetHeight(36)
                b:SetPoint("TOPLEFT", scroll, "TOPLEFT", col * 44 + 4, -(row * ROW_STEP + 4))
                b:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, tileSize = 0, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                b:SetBackdropColor(0.04, 0.04, 0.06, 1.0)
                b:SetBackdropBorderColor(0.25, 0.25, 0.32, 1.0)

                local tex = b:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
                tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                b.tex = tex

                local glow = b:CreateTexture(nil, "OVERLAY")
                glow:SetAllPoints(b)
                glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
                glow:SetBlendMode("ADD")
                glow:Hide()
                b.selectedGlow = glow

                b:SetScript("OnEnter", function()
                    if this.iconName then
                        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine("|cffffffff" .. this.iconName .. "|r", 1, 1, 1)
                        GameTooltip:AddLine(string.format("|cff00ccffWire Index: #%d|r", this.iconIndex or 0), 0.4, 0.8, 1)
                        GameTooltip:Show()
                    end
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                b:SetScript("OnClick", function()
                    if this.iconIndex and p.callback then
                        p.callback(this.iconIndex)
                    end
                    p:Hide()
                end)

                table.insert(p.buttons, b)
            end
        end

        local statusText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusText:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 8)
        statusText:SetText("|cff888899Showing 2020 icons|r")
        p.statusText = statusText

        local selectedText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        selectedText:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 8)
        p.selectedText = selectedText

        iconPickerFrame = p
    end

    iconPickerFrame.callback = onSelectCallback
    iconPickerFrame.selectedIconIdx = currentSelectedIdx

    if currentSelectedIdx and currentSelectedIdx > 0 and PUIRoleplay.Icons and PUIRoleplay.Icons[currentSelectedIdx] then
        iconPickerFrame.selectedText:SetText(string.format("|cffffd100Selected: #%d|r", currentSelectedIdx))
    else
        iconPickerFrame.selectedText:SetText("")
    end

    iconPickerFrame.activeCategory = "ALL"
    iconPickerFrame.filterEB:SetText("")
    Sheet:FilterIconPicker("")
    iconPickerFrame:Show()
    iconPickerFrame.filterEB:SetFocus()
end
