--[[
    PrimusUI: PUIRoleplay Profile Sheet Tab Panels (PUIRPSheetTabs.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (6 Granular Tab Layouts)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Sheet = PUIRoleplay.Sheet or {}
PUIRoleplay.Sheet = Sheet

local SheetTabs = {}
Sheet.Tabs = SheetTabs

local openDropdownMenu = nil

--------------------------------------------------------------------------------
-- UI Component Factory Helpers
--------------------------------------------------------------------------------
function SheetTabs:Create1PxBackdrop(parent, r, g, b, a, borderR, borderG, borderB, borderA)
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

function SheetTabs:CreateStyledEditBox(parent, width, height)
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
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    return eb
end

function SheetTabs:CreateStyledCheckbox(parent, text, onClickCallback)
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
        if not Sheet:IsViewingSelf() then return end
        local isChecked = not (this.isChecked == true)
        this.isChecked = isChecked
        if isChecked then
            this.checkTex:Show()
            this:SetBackdropBorderColor(0.0, 0.85, 1.0, 1.0)
        else
            this.checkTex:Hide()
            this:SetBackdropBorderColor(0.35, 0.35, 0.42, 1.0)
        end
        if onClickCallback then onClickCallback(isChecked) end
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

function SheetTabs:CreateStyledDropdown(parent, width, height, optionsList, onSelectCallback)
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

    btn:SetScript("OnClick", function()
        if not Sheet:IsViewingSelf() then return end
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

            itemBtn:SetScript("OnEnter", function() this.text:SetTextColor(0.0, 1.0, 1.0) end)
            itemBtn:SetScript("OnLeave", function() this.text:SetTextColor(1.0, 1.0, 1.0) end)
            itemBtn:SetScript("OnClick", function()
                btn.selectedKey = this.optKey
                btn.text:SetText(this.optVal)
                menu:Hide()
                openDropdownMenu = nil
                if onSelectCallback then onSelectCallback(this.optKey, this.optVal) end
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
-- Build Tab Panels 1 to 6
--------------------------------------------------------------------------------
function SheetTabs:BuildPanel1(parent, f)
    local p1 = CreateFrame("Frame", nil, parent)
    p1:SetAllPoints(parent)
    f.panel1 = p1

    -- Names row
    local fnLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fnLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 10, -8)
    fnLabel:SetText("|cff00e5ffFirst Name:|r")
    local fnEB = self:CreateStyledEditBox(p1, 155, 20)
    fnEB:SetPoint("TOPLEFT", fnLabel, "BOTTOMLEFT", 0, -2)
    fnEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local mnEB = self:CreateStyledEditBox(p1, 155, 20)
    mnEB:SetPoint("TOPLEFT", mnLabel, "BOTTOMLEFT", 0, -2)
    mnEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local lnEB = self:CreateStyledEditBox(p1, 155, 20)
    lnEB:SetPoint("TOPLEFT", lnLabel, "BOTTOMLEFT", 0, -2)
    lnEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.last_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.lnEB = lnEB

    -- Prefix, Nick, House
    local pfxLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pfxLabel:SetPoint("TOPLEFT", fnEB, "BOTTOMLEFT", 0, -6)
    pfxLabel:SetText("|cff00e5ffPrefix (e.g. Sir):|r")
    local pfxEB = self:CreateStyledEditBox(p1, 155, 20)
    pfxEB:SetPoint("TOPLEFT", pfxLabel, "BOTTOMLEFT", 0, -2)
    pfxEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local nickEB = self:CreateStyledEditBox(p1, 155, 20)
    nickEB:SetPoint("TOPLEFT", nickLabel, "BOTTOMLEFT", 0, -2)
    nickEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local houseEB = self:CreateStyledEditBox(p1, 155, 20)
    houseEB:SetPoint("TOPLEFT", houseLabel, "BOTTOMLEFT", 0, -2)
    houseEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.house_name = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.houseEB = houseEB

    -- Title
    local ttlLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ttlLabel:SetPoint("TOPLEFT", pfxEB, "BOTTOMLEFT", 0, -6)
    ttlLabel:SetText("|cff00e5ffTitle / Honorific / Epithet:|r")
    local ttlEB = self:CreateStyledEditBox(p1, 479, 20)
    ttlEB:SetPoint("TOPLEFT", ttlLabel, "BOTTOMLEFT", 0, -2)
    ttlEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.title = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.ttlEB = ttlEB

    -- Age & Gender
    local ageLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ageLabel:SetPoint("TOPLEFT", ttlEB, "BOTTOMLEFT", 0, -8)
    ageLabel:SetText("|cff00e5ffApparent Age:|r")
    local ageEB = self:CreateStyledEditBox(p1, 230, 20)
    ageEB:SetPoint("TOPLEFT", ageLabel, "BOTTOMLEFT", 0, -2)
    ageEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local genderDropdown = self:CreateStyledDropdown(p1, 234, 20, PUIRoleplay.DropdownOptions.gender or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.gender_identity = optVal
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    genderDropdown:SetPoint("TOPLEFT", genderLabel, "BOTTOMLEFT", 0, -2)
    p1.genderDropdown = genderDropdown

    -- Pronouns
    local icPrLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icPrLabel:SetPoint("TOPLEFT", ageEB, "BOTTOMLEFT", 0, -6)
    icPrLabel:SetText("|cff00e5ffIC Pronouns (e.g. He/Him):|r")
    local icPrEB = self:CreateStyledEditBox(p1, 230, 20)
    icPrEB:SetPoint("TOPLEFT", icPrLabel, "BOTTOMLEFT", 0, -2)
    icPrEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local oocPrEB = self:CreateStyledEditBox(p1, 234, 20)
    oocPrEB:SetPoint("TOPLEFT", oocPrLabel, "BOTTOMLEFT", 0, -2)
    oocPrEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ooc_pronouns = this:GetText()
            p.keyM = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p1.oocPrEB = oocPrEB

    -- LGBTQIA+ Checkbox
    local lgbtqBox = self:CreateStyledCheckbox(p1, "|cffff0000L|cffff7f00G|cffffff00B|cff00ff00T|cff0000ffQ|cff4b0082I|cff9400d3A+|r Friendly / Inclusive Safe Space Profile", function(checked)
        local p = PUIRoleplay:GetMyProfile()
        p.lgbtqia_friendly = checked
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    lgbtqBox:SetPoint("TOPLEFT", icPrEB, "BOTTOMLEFT", 0, -12)
    p1.lgbtqBox = lgbtqBox

    -- Orientation Dropdown
    local oriLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oriLabel:SetPoint("TOPLEFT", lgbtqBox, "BOTTOMLEFT", 0, -10)
    oriLabel:SetText("|cff00e5ffSexual / Romantic Orientation:|r")
    local oriDropdown = self:CreateStyledDropdown(p1, 230, 20, PUIRoleplay.DropdownOptions.orientation or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.orientation = optVal
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    oriDropdown:SetPoint("TOPLEFT", oriLabel, "BOTTOMLEFT", 0, -2)
    p1.oriDropdown = oriDropdown

    local showOriBox = self:CreateStyledCheckbox(p1, "Display Orientation on Matchmaking Directory Card", function(checked)
        local p = PUIRoleplay:GetMyProfile()
        p.show_orientation = checked
        p.keyM = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    showOriBox:SetPoint("TOPLEFT", oriDropdown, "TOPRIGHT", 15, 0)
    p1.showOriBox = showOriBox
end

function SheetTabs:BuildPanel2(parent, f)
    local p2 = CreateFrame("Frame", nil, parent)
    p2:SetAllPoints(parent)
    p2:Hide()
    f.panel2 = p2

    local eyeLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eyeLabel:SetPoint("TOPLEFT", p2, "TOPLEFT", 10, -8)
    eyeLabel:SetText("|cff00e5ffEye Color:|r")
    local eyeEB = self:CreateStyledEditBox(p2, 112, 20)
    eyeEB:SetPoint("TOPLEFT", eyeLabel, "BOTTOMLEFT", 0, -2)
    eyeEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local hEB = self:CreateStyledEditBox(p2, 112, 20)
    hEB:SetPoint("TOPLEFT", hLabel, "BOTTOMLEFT", 0, -2)
    hEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local wEB = self:CreateStyledEditBox(p2, 112, 20)
    wEB:SetPoint("TOPLEFT", wLabel, "BOTTOMLEFT", 0, -2)
    wEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local bEB = self:CreateStyledEditBox(p2, 118, 20)
    bEB:SetPoint("TOPLEFT", bLabel, "BOTTOMLEFT", 0, -2)
    bEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.body_build = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.bEB = bEB

    local emoLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emoLabel:SetPoint("TOPLEFT", eyeEB, "BOTTOMLEFT", 0, -6)
    emoLabel:SetText("|cff00e5ffCurrent Emotion / Expression:|r")
    local emoEB = self:CreateStyledEditBox(p2, 478, 20)
    emoEB:SetPoint("TOPLEFT", emoLabel, "BOTTOMLEFT", 0, -2)
    emoEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.current_emotion = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p2.emoEB = emoEB

    local descLabel = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", emoEB, "BOTTOMLEFT", 0, -6)
    descLabel:SetText("|cff55ff88Physical Appearance Description:|r")

    local descCount = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descCount:SetPoint("TOPRIGHT", p2, "TOPRIGHT", -12, -74)
    descCount:SetText("0 / 1000")
    p2.descCount = descCount

    local descScrollBg = self:Create1PxBackdrop(p2, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
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

    descScrollBg:SetScript("OnMouseDown", function() if Sheet:IsViewingSelf() then descEB:SetFocus() end end)
    descEB:SetScript("OnTextChanged", function()
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(descScroll) end
        local len = string.len(this:GetText() or "")
        p2.descCount:SetText(len .. " / 1000")
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.appearance_desc = this:GetText()
            p.keyD = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    descEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    local glanceHeader = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glanceHeader:SetPoint("TOPLEFT", descScrollBg, "BOTTOMLEFT", 0, -8)
    glanceHeader:SetText("|cffffd100AT A GLANCE TRAITS (5 Visual Cards):|r")

    p2.glanceCards = {}
    for i = 1, 5 do
        local card = self:Create1PxBackdrop(p2, 0.05, 0.05, 0.07, 0.95, 0.22, 0.24, 0.28, 1.0)
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
            if Sheet:IsViewingSelf() then
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

        local gTitleEB = self:CreateStyledEditBox(card, 340, 16)
        gTitleEB:SetPoint("TOPLEFT", gBtn, "TOPRIGHT", 8, 0)
        gTitleEB:SetTextColor(1.0, 0.90, 0.30, 1.0)
        gTitleEB.cardIndex = i
        gTitleEB:SetScript("OnTextChanged", function()
            if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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

        local gDescEB = self:CreateStyledEditBox(card, 340, 16)
        gDescEB:SetPoint("TOPLEFT", gTitleEB, "BOTTOMLEFT", 0, -2)
        gDescEB:SetTextColor(1.0, 1.0, 1.0, 1.0)
        gDescEB.cardIndex = i
        gDescEB:SetScript("OnTextChanged", function()
            if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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

        local activeCB = self:CreateStyledCheckbox(card, "Active", function(checked)
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
end

function SheetTabs:BuildPanel3(parent, f)
    local p3 = CreateFrame("Frame", nil, parent)
    p3:SetAllPoints(parent)
    p3:Hide()
    f.panel3 = p3

    local bCityLabel = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bCityLabel:SetPoint("TOPLEFT", p3, "TOPLEFT", 10, -8)
    bCityLabel:SetText("|cff00e5ffBirth City / Origin:|r")
    local bCityEB = self:CreateStyledEditBox(p3, 230, 20)
    bCityEB:SetPoint("TOPLEFT", bCityLabel, "BOTTOMLEFT", 0, -2)
    bCityEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local hCityEB = self:CreateStyledEditBox(p3, 234, 20)
    hCityEB:SetPoint("TOPLEFT", hCityLabel, "BOTTOMLEFT", 0, -2)
    hCityEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local mottoEB = self:CreateStyledEditBox(p3, 479, 20)
    mottoEB:SetPoint("TOPLEFT", mottoLabel, "BOTTOMLEFT", 0, -2)
    mottoEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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
    local facEB = self:CreateStyledEditBox(p3, 479, 20)
    facEB:SetPoint("TOPLEFT", facLabel, "BOTTOMLEFT", 0, -2)
    facEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.faction_clan = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p3.facEB = facEB

    local histHeader = p3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    histHeader:SetPoint("TOPLEFT", facEB, "BOTTOMLEFT", 0, -10)
    histHeader:SetText("|cffffd100CHARACTER CHRONICLES & HISTORY (6 Chapters):|r")

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

    local chScrollBg = self:Create1PxBackdrop(p3, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
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

    chScrollBg:SetScript("OnMouseDown", function() if Sheet:IsViewingSelf() then chEB:SetFocus() end end)
    chEB:SetScript("OnTextChanged", function()
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(chScroll) end
        local len = string.len(this:GetText() or "")
        p3.chCount:SetText(len .. " / 1000")
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            if not p.history then p.history = {} end
            p.history["chapter" .. (Sheet.activeLoreChapter or 1)] = this:GetText()
            p.keyL = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    chEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
end

function SheetTabs:BuildPanel4(parent, f)
    local p4 = CreateFrame("Frame", nil, parent)
    p4:SetAllPoints(parent)
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
        local card = self:Create1PxBackdrop(p4, 0.05, 0.05, 0.07, 0.8, 0.20, 0.22, 0.26, 1.0)
        card:SetWidth(478)
        card:SetHeight(52)
        card:SetPoint("TOPLEFT", p4, "TOPLEFT", 10, curStyleY)

        local sLbl = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        sLbl:SetText("|cff00e5ff" .. sec.label .. "|r")

        local dd = self:CreateStyledDropdown(card, 460, 22, sec.opts or {}, function(optKey, optVal)
            local p = PUIRoleplay:GetMyProfile()
            p[sec.key] = optVal
            p.keyT = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end)
        dd:SetPoint("TOPLEFT", sLbl, "BOTTOMLEFT", 0, -2)
        p4.dropdowns[sec.key] = dd

        curStyleY = curStyleY - 58
    end
end

function SheetTabs:BuildPanel5(parent, f)
    local p5 = CreateFrame("Frame", nil, parent)
    p5:SetAllPoints(parent)
    p5:Hide()
    f.panel5 = p5

    local relLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    relLabel:SetPoint("TOPLEFT", p5, "TOPLEFT", 10, -8)
    relLabel:SetText("|cff00e5ffIC Relationship Status:|r")
    local relDropdown = self:CreateStyledDropdown(p5, 230, 22, PUIRoleplay.DropdownOptions.relationship or {}, function(optKey, optVal)
        local p = PUIRoleplay:GetMyProfile()
        p.relationship_status = optVal
        p.keyX = PUIRoleplay:GenerateKey()
        PUIRoleplay:SaveMyProfile(p)
    end)
    relDropdown:SetPoint("TOPLEFT", relLabel, "BOTTOMLEFT", 0, -2)
    p5.relDropdown = relDropdown

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
        local cb = self:CreateStyledCheckbox(p5, item.label, function(checked)
            local p = PUIRoleplay:GetMyProfile()
            if not p.looking_for then p.looking_for = {} end
            p.looking_for[item.key] = checked
            p.keyX = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end)
        cb:SetPoint("TOPLEFT", lfLabel, "BOTTOMLEFT", col * 240, -4 - row * 22)
        p5.lfCheckboxes[item.key] = cb
    end

    local adultCard = self:Create1PxBackdrop(p5, 0.08, 0.04, 0.05, 0.95, 0.50, 0.18, 0.22, 1.0)
    adultCard:SetWidth(478)
    adultCard:SetHeight(160)
    adultCard:SetPoint("TOPLEFT", lfLabel, "BOTTOMLEFT", 0, -80)

    local adultTitle = adultCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adultTitle:SetPoint("TOPLEFT", adultCard, "TOPLEFT", 8, -6)
    adultTitle:SetText("|cffff335518+ ADULT-ORIENTED RP & ERP BOUNDARIES:|r")

    local adultFlagCB = self:CreateStyledCheckbox(adultCard, "|cffff4466[18+] Explicit Adult-Oriented Roleplay Profile|r", function(checked)
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

    local erpDropdown = self:CreateStyledDropdown(adultCard, 460, 20, PUIRoleplay.DropdownOptions.erp or {}, function(optKey, optVal)
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

    local bndEB = self:CreateStyledEditBox(adultCard, 460, 20)
    bndEB:SetPoint("TOPLEFT", bndLabel, "BOTTOMLEFT", 0, -2)
    bndEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
            local p = PUIRoleplay:GetMyProfile()
            p.ooc_boundaries = this:GetText()
            p.keyX = PUIRoleplay:GenerateKey()
            PUIRoleplay:SaveMyProfile(p)
        end
    end)
    p5.bndEB = bndEB
end

function SheetTabs:BuildPanel6(parent, f)
    local p6 = CreateFrame("Frame", nil, parent)
    p6:SetAllPoints(parent)
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
            if Sheet:IsViewingSelf() then
                PUIRoleplay:SetActiveProfileSlot(this.slot)
                Sheet:Refresh()
            end
        end)
        p6.profBtns[i] = pBtn
    end

    local oocHeader = p6:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oocHeader:SetPoint("TOPLEFT", profHeader, "BOTTOMLEFT", 0, -42)
    oocHeader:SetText("|cff55ff88Public OOC Notes (Broadcasted over Wire):|r")

    local oocEB = self:CreateStyledEditBox(p6, 478, 20)
    oocEB:SetPoint("TOPLEFT", oocHeader, "BOTTOMLEFT", 0, -2)
    oocEB:SetScript("OnTextChanged", function()
        if Sheet:IsViewingSelf() and f.isRefreshing ~= true then
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

    local notesScrollBg = self:Create1PxBackdrop(p6, 0.04, 0.04, 0.07, 0.95, 0.28, 0.28, 0.35, 1.0)
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
            local target = Sheet:GetTargetPlayer() or UnitName("player")
            PUIRoleplay:SetCharacterNote(target, this:GetText())
        end
    end)
    notesEB:SetScript("OnEscapePressed", function() this:ClearFocus() end)
end
