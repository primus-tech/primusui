--[[
    PrimusLib: Bulletproof Diagnostic & Auto-Popup Error Catcher
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Commands: /error, /errors, /bug, /bugs, /err
    Features:
    1. Intercepts all Lua errors, syntax warnings, and Blizzard message() calls.
    2. Automatic pop-up window immediately on error with full call stack trace.
    3. Multi-line selectable editbox with 1-click 'Copy / Select All' for Ctrl+C / Cmd+C.
    4. Loop deduplication to protect FPS and memory on rapid repeat errors.
    5. Error history navigation (< Previous, Next >), Clear, and 1-Click Reload UI.
    6. Suppresses default Blizzard ScriptErrors dialog.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local Debug = Primus.Debug or {}
Primus.Debug = Debug

local Utils = Primus.Utils

Debug.errorLog = {}
Debug.capturedErrors = {}
Debug.currentIndex = 1
Debug.logCount = 0
Debug.maxLogs = 100
Debug.logLevel = 1
Debug.errorFrame = nil
Debug.autoPopup = true

local LEVEL_COLORS = {
    [1] = "ff4444", -- Error (Red)
    [2] = "ffbb33", -- Warn  (Yellow)
    [3] = "33b5e5", -- Info  (Blue)
    [4] = "99cc00", -- Debug (Green)
}

-- Safe execution wrapper (Lua 5.0 pcall compliant)
function Debug:SafeCall(func, a1, a2, a3, a4, a5, a6, a7, a8)
    if type(func) ~= "function" then return false, "Not a function" end
    local success, err = pcall(func, a1, a2, a3, a4, a5, a6, a7, a8)
    if not success then
        local stack = debugstack and debugstack(2, 20, 20) or ""
        self:CaptureError(tostring(err), stack)
    end
    return success, err
end

-- Helper to extract Addon Name from error path
local function DetectAddonName(str)
    if not str then return "Unknown" end
    local _, _, addon = string.find(str, "AddOns\\([^\\]+)")
    if addon then return addon end
    if string.find(str, "FrameXML") then return "Blizzard FrameXML" end
    return "Custom Script"
end

-- Record and format an error in the legacy log
function Debug:Error(tag, message)
    self:Log(1, tag, message)
end

function Debug:Warn(tag, message)
    self:Log(2, tag, message)
end

function Debug:Info(tag, message)
    self:Log(3, tag, message)
end

function Debug:Log(level, tag, message)
    if level > self.logLevel then return end

    local timestamp = date("%H:%M:%S")
    local entry = {
        level = level,
        tag = tag or "System",
        message = tostring(message or ""),
        time = timestamp,
    }

    self.logCount = self.logCount + 1
    table.insert(self.errorLog, entry)
    if table.getn(self.errorLog) > self.maxLogs then
        table.remove(self.errorLog, 1)
    end

    local colorHex = LEVEL_COLORS[level] or "ffffff"
    local prefix = string.format("|cff%s[%s][%s][%s]:|r", colorHex, timestamp, "Primus", tag)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. tostring(message))
    end
end

-- Dump a table structure for in-game inspection
function Debug:Dump(t, maxDepth, currentDepth)
    maxDepth = maxDepth or 2
    currentDepth = currentDepth or 0

    if type(t) ~= "table" then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(tostring(t)) end
        return
    end

    local indent = string.rep("  ", currentDepth)
    for k, v in pairs(t) do
        if type(v) == "table" and currentDepth < maxDepth then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(indent .. tostring(k) .. " = {") end
            self:Dump(v, maxDepth, currentDepth + 1)
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(indent .. "}") end
        else
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(indent .. tostring(k) .. " = " .. tostring(v)) end
        end
    end
end

-- =========================================================================
-- GLOBAL ERROR CATCHER & AUTOMATIC POP-UP INSPECTOR
-- =========================================================================

-- Show Error Popup Window immediately
function Debug:ShowErrorPopup()
    local f = self:CreateErrorFrame()
    if not f then return end
    self:RefreshErrorFrame()
    f:Show()
    f:Raise()
    if f.editBox then
        f.editBox:SetFocus()
        f.editBox:HighlightText()
    end
end

-- Capture and record a Lua error
function Debug:CaptureError(msg, stack)
    msg = tostring(msg or "Unknown script error")
    stack = tostring(stack or (debugstack and debugstack(2, 20, 20) or ""))
    local timeStr = date("%H:%M:%S")

    -- Check for repeat error to deduplicate and protect FPS/memory
    local numErrors = table.getn(self.capturedErrors)
    for i = 1, numErrors do
        local existing = self.capturedErrors[i]
        if existing.msg == msg and existing.stack == stack then
            existing.count = existing.count + 1
            existing.lastSeen = timeStr
            if self.errorFrame and self.errorFrame:IsShown() and self.currentIndex == i then
                self:RefreshErrorFrame()
            end
            return
        end
    end

    local addon = DetectAddonName(msg)
    if addon == "Unknown" or addon == "Custom Script" then
        addon = DetectAddonName(stack)
    end

    local entry = {
        msg = msg,
        stack = stack,
        firstSeen = timeStr,
        lastSeen = timeStr,
        count = 1,
        addon = addon,
    }

    table.insert(self.capturedErrors, entry)
    self.currentIndex = table.getn(self.capturedErrors)

    -- Auto Pop-Up the Error Inspector Window immediately
    if self.autoPopup then
        self:ShowErrorPopup()
    end
end

-- Create the Error Inspector GUI window
function Debug:CreateErrorFrame()
    if self.errorFrame then return self.errorFrame end

    local parent = UIParent or WorldFrame
    local f = CreateFrame("Frame", "Primus_ErrorFrame", parent)
    f:SetWidth(600)
    f:SetHeight(420)
    f:SetPoint("CENTER", parent, "CENTER", 0, 50)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    -- Allow ESC key to close error popup
    if UISpecialFrames then
        table.insert(UISpecialFrames, "Primus_ErrorFrame")
    end

    -- Title Bar Header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
    title:SetText("|cffff4444Primus Error Catcher|r |cffaaaaaa// Script Error Inspector|r")
    f.titleText = title

    local closeX = CreateFrame("Button", nil, f)
    closeX:SetWidth(24)
    closeX:SetHeight(24)
    closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -12)
    closeX:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeX:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeX:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeX:SetScript("OnClick", function() f:Hide() end)

    -- Status Subheader
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    statusText:SetText("No errors captured.")
    f.statusText = statusText

    local countText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -18)
    countText:SetText("")
    f.countText = countText

    -- ScrollFrame & EditBox Container
    local editContainer = CreateFrame("Frame", nil, f)
    editContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -56)
    editContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 44)
    editContainer:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    editContainer:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    editContainer:SetBackdropBorderColor(0.3, 0.3, 0.4, 1.0)

    local scroll = CreateFrame("ScrollFrame", "Primus_ErrorScrollFrame", editContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", editContainer, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", editContainer, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "Primus_ErrorEditBox", scroll)
    editBox:SetWidth(520)
    editBox:SetHeight(280)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(99999)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetTextColor(0.95, 0.95, 0.95, 1.0)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnTextChanged", function()
        local s = this:GetParent()
        if s and s.UpdateScrollChildRect then
            s:UpdateScrollChildRect()
        end
    end)
    scroll:SetScrollChild(editBox)
    f.editBox = editBox
    f.scroll = scroll

    -- Bottom Controls Footer
    local prevBtn = CreateFrame("Button", "Primus_ErrorPrevBtn", f, "UIPanelButtonTemplate")
    prevBtn:SetWidth(80)
    prevBtn:SetHeight(22)
    prevBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    prevBtn:SetText("< Previous")
    prevBtn:SetScript("OnClick", function()
        if Debug.currentIndex > 1 then
            Debug.currentIndex = Debug.currentIndex - 1
            Debug:RefreshErrorFrame()
            if editBox then editBox:SetFocus() editBox:HighlightText() end
        end
    end)
    f.prevBtn = prevBtn

    local nextBtn = CreateFrame("Button", "Primus_ErrorNextBtn", f, "UIPanelButtonTemplate")
    nextBtn:SetWidth(80)
    nextBtn:SetHeight(22)
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    nextBtn:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        if Debug.currentIndex < table.getn(Debug.capturedErrors) then
            Debug.currentIndex = Debug.currentIndex + 1
            Debug:RefreshErrorFrame()
            if editBox then editBox:SetFocus() editBox:HighlightText() end
        end
    end)
    f.nextBtn = nextBtn

    -- 1-Click Copy / Select All Button
    local copyBtn = CreateFrame("Button", "Primus_ErrorCopyBtn", f, "UIPanelButtonTemplate")
    copyBtn:SetWidth(130)
    copyBtn:SetHeight(22)
    copyBtn:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
    copyBtn:SetText("Copy / Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[Primus Errors]: Text highlighted! Press Ctrl+C (Cmd+C) to copy.|r")
        end
    end)

    -- Clear All Button
    local clearBtn = CreateFrame("Button", "Primus_ErrorClearBtn", f, "UIPanelButtonTemplate")
    clearBtn:SetWidth(80)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        Debug:ClearErrors()
    end)

    -- Reload UI Button
    local reloadBtn = CreateFrame("Button", "Primus_ErrorReloadBtn", f, "UIPanelButtonTemplate")
    reloadBtn:SetWidth(80)
    reloadBtn:SetHeight(22)
    reloadBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -85, 14)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)

    -- Close Button
    local closeMain = CreateFrame("Button", "Primus_ErrorCloseBtn", f, "UIPanelButtonTemplate")
    closeMain:SetWidth(65)
    closeMain:SetHeight(22)
    closeMain:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    closeMain:SetText("Close")
    closeMain:SetScript("OnClick", function() f:Hide() end)

    self.errorFrame = f
    return f
end

-- Refresh error view
function Debug:RefreshErrorFrame()
    local f = self:CreateErrorFrame()
    if not f then return end

    local total = table.getn(self.capturedErrors)
    if total == 0 then
        f.titleText:SetText("|cffff4444Primus Error Catcher|r |cffaaaaaa// No Errors|r")
        f.statusText:SetText("|cff888888No Lua errors captured in this session. All clear!|r")
        f.countText:SetText("")
        f.editBox:SetText("No errors captured.")
        f.prevBtn:Disable()
        f.nextBtn:Disable()
        return
    end

    if self.currentIndex < 1 then self.currentIndex = 1 end
    if self.currentIndex > total then self.currentIndex = total end

    local entry = self.capturedErrors[self.currentIndex]
    f.titleText:SetText(string.format("|cffff4444Primus Error Catcher|r |cffaaaaaa// Error %d of %d|r", self.currentIndex, total))
    f.statusText:SetText(string.format("Source: |cff69ccf0%s|r  |  Time: |cffffffff%s|r", entry.addon, entry.lastSeen))
    f.countText:SetText(string.format("Occurrences: |cffffcc00%d|r", entry.count))

    local _, pClass = UnitClass("player")
    local pLevel = UnitLevel("player") or 60
    local pZone = GetZoneText() or "Unknown"

    local report = string.format([[============================================================
  PRIMUS ERROR REPORT [Error %d of %d]
============================================================
Date/Time   : %s (First Seen: %s, Occurrences: %d)
AddOn/Source: %s
Player Info : Level %d %s (Zone: %s)
Client      : WoW 1.12.1 (Interface 11200)

------------------------------------------------------------
[ERROR MESSAGE]:
%s

------------------------------------------------------------
[CALL STACK]:
%s
============================================================]], self.currentIndex, total, entry.lastSeen, entry.firstSeen, entry.count, entry.addon, pLevel, pClass or "Unknown", pZone, entry.msg, entry.stack)

    f.editBox:SetText(report)

    if self.currentIndex > 1 then f.prevBtn:Enable() else f.prevBtn:Disable() end
    if self.currentIndex < total then f.nextBtn:Enable() else f.nextBtn:Disable() end
end

-- Clear all captured errors
function Debug:ClearErrors()
    Utils.Wipe(self.capturedErrors)
    self.currentIndex = 1
    self:RefreshErrorFrame()
    if self.errorFrame then self.errorFrame:Hide() end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[Primus Errors]: Cleared all captured error logs.|r")
    end
end

-- Toggle window
function Debug:ToggleErrorFrame()
    local f = self:CreateErrorFrame()
    if f:IsShown() then
        f:Hide()
    else
        self:ShowErrorPopup()
    end
end

-- =========================================================================
-- GLOBAL ERROR INTERCEPTION & SUPPRESSION ENGINE
-- =========================================================================

local function PrimusGlobalErrorHandler(errMsg)
    local stack = debugstack and debugstack(2, 20, 20) or ""
    Debug:CaptureError(errMsg, stack)
end

-- Install global error handler
local function InstallGlobalErrorHandler()
    if seterrorhandler then
        seterrorhandler(PrimusGlobalErrorHandler)
    end

    if _G.message then
        _G.message = function(msg)
            local stack = debugstack and debugstack(2, 20, 20) or ""
            Debug:CaptureError(msg, stack)
        end
    end

    if ScriptErrors_OnError then
        ScriptErrors_OnError = function(msg)
            local stack = debugstack and debugstack(2, 20, 20) or ""
            Debug:CaptureError(msg, stack)
        end
    end

    if ScriptErrors then
        ScriptErrors:UnregisterAllEvents()
        ScriptErrors:Hide()
        ScriptErrors:ClearAllPoints()
        ScriptErrors:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -2000, 2000)
        ScriptErrors:SetScript("OnShow", function() this:Hide() end)
    end
end

-- Initial install
InstallGlobalErrorHandler()

-- Event-driven re-installation to ensure Blizzard FrameXML does not override our handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    InstallGlobalErrorHandler()
end)

-- Sub-command registration via Primus Console
if Primus.Console and Primus.Console.RegisterSubCommand then
    Primus.Console:RegisterSubCommand("errors", function(argParam)
        argParam = Utils.Trim(argParam or "")
        if argParam == "clear" then
            Debug:ClearErrors()
        elseif argParam == "test" then
            error("Primus Error Catcher Test: copy/paste verification test error!")
        else
            Debug:ToggleErrorFrame()
        end
    end, "Display runtime error inspector GUI (/pui errors [clear|test])")
    
    if Primus.Console.RegisterAlias then
        Primus.Console:RegisterAlias("error", "errors")
        Primus.Console:RegisterAlias("bugs", "errors")
        Primus.Console:RegisterAlias("bug", "errors")
        Primus.Console:RegisterAlias("err", "errors")
    end
end

