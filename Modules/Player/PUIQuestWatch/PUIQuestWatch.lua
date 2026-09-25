--[[
    PrimusUI Module: PUIQuestWatch (Bulletproof Quest Objective Tracker & Persistence Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Features:
    1. Permanent Quest Tracking: Fixes Blizzard's 5-minute AutoQuestWatch expiration bug and tremove table key bug.
    2. Title-Based SavedVariables Persistence: Retains tracked quests across sessions, /reload, and quest log index shifts.
    3. Multi-Anchor Conflict Fix: Prevents UIParent_ManageFramePositions from dual-anchoring and distorting QuestWatchFrame.
    4. Enhanced Visuals:
       - Difficulty-colored quest titles with level brackets: [11] Quest Title.
       - Clean objective status bullets with (Complete) highlights.
       - Displays "Ready for turn-in" for quests without leaderboards so they never disappear on completion.
    5. Interactive Clickable Headers:
       - Left-Click on quest header: Opens Quest Log and selects that quest.
       - Shift-Click on quest header: Inserts quest link in chat or untracks quest.
    6. Zen Engine & PUIMover Integration:
       - Works smoothly with State.lua / Hider.lua combat fading and hover-to-peek.
       - Full support for PUIMover custom positioning without position snapping.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuestWatch = Primus.PUIQuestWatch or {}
Primus.PUIQuestWatch = PUIQuestWatch
_G.PUIQuestWatch = PUIQuestWatch
Primus:RegisterModule("PUIQuestWatch", PUIQuestWatch, "Player")

local DB       = Primus.DB
local Utils    = Primus.Utils
local Events   = Primus.Events
local PUIMover = Primus.PUIMover

-- Persistent Database for Quest Tracking
local questDB = DB:RegisterNamespace("PUIQuestWatch", {
    enabled               = true,
    trackedQuests         = {},     -- [questTitle] = true
    autoWatchNew          = true,   -- Automatically watch newly accepted quests
    autoWatchProgress     = true,   -- Automatically watch quests when objectives update
    showLevels            = true,   -- Display [Level] in front of quest titles
    maxWatches            = 10,     -- Support up to 10 watched quests
    lineSpacing           = 2,      -- Spacing between objective lines
    questSpacing          = 6,      -- Spacing between distinct quests
})

-- Internal Runtime State
PUIQuestWatch.headerButtons    = {}
PUIQuestWatch.allocatedLines   = 21
PUIQuestWatch.isReconciling    = false
PUIQuestWatch.isInitialized    = false
PUIQuestWatch.cachedLogEntries = 0

-- Quest Difficulty Colors (Matches Blizzard standard with refined contrast)
local DIFFICULTY_COLORS = {
    ["impossible"]    = { r = 1.00, g = 0.15, b = 0.15 }, -- Red (+5 or higher)
    ["verydifficult"] = { r = 1.00, g = 0.50, b = 0.20 }, -- Orange (+3 to +4)
    ["difficult"]     = { r = 1.00, g = 0.85, b = 0.10 }, -- Yellow (-2 to +2)
    ["standard"]      = { r = 0.25, g = 0.85, b = 0.25 }, -- Green (Green range)
    ["trivial"]       = { r = 0.60, g = 0.60, b = 0.60 }, -- Gray (Trivial / Low level)
    ["header"]        = { r = 0.90, g = 0.80, b = 0.50 }, -- Gold Header
}

-- =========================================================================
-- UTILITY & LOOKUP HELPERS
-- =========================================================================

-- Get color based on player level difference
function PUIQuestWatch:GetQuestColor(level)
    if not level or level <= 0 then
        return DIFFICULTY_COLORS["standard"]
    end
    local playerLevel = UnitLevel("player") or 1
    local levelDiff = level - playerLevel
    if levelDiff >= 5 then
        return DIFFICULTY_COLORS["impossible"]
    elseif levelDiff >= 3 then
        return DIFFICULTY_COLORS["verydifficult"]
    elseif levelDiff >= -2 then
        return DIFFICULTY_COLORS["difficult"]
    elseif -levelDiff <= (GetQuestGreenRange and GetQuestGreenRange() or 5) then
        return DIFFICULTY_COLORS["standard"]
    else
        return DIFFICULTY_COLORS["trivial"]
    end
end

-- Find the current quest log index for a given quest title
function PUIQuestWatch:FindQuestLogIndex(targetTitle)
    if not targetTitle or targetTitle == "" then return nil end
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if not isHeader and title and title == targetTitle then
            return i, level, questTag, isComplete
        end
    end
    return nil
end

-- =========================================================================
-- PERSISTENCE & TRACKING ENGINE
-- =========================================================================

-- Get tracked quests table from DB
function PUIQuestWatch:GetTrackedList()
    local list = questDB:Get("trackedQuests")
    if type(list) ~= "table" then
        list = {}
        questDB:Set("trackedQuests", list)
    end
    return list
end

-- Check if a quest is tracked by title or index
function PUIQuestWatch:IsTracked(questIndexOrTitle)
    local title = questIndexOrTitle
    if type(questIndexOrTitle) == "number" then
        title = GetQuestLogTitle(questIndexOrTitle)
    end
    if not title then return false end
    local tracked = self:GetTrackedList()
    return tracked[title] == true
end

-- Track a quest permanently
function PUIQuestWatch:TrackQuest(questIndexOrTitle)
    local questIndex, title
    if type(questIndexOrTitle) == "number" then
        questIndex = questIndexOrTitle
        title = GetQuestLogTitle(questIndex)
    else
        title = questIndexOrTitle
        questIndex = self:FindQuestLogIndex(title)
    end

    if not title or title == "" then return false end

    local tracked = self:GetTrackedList()
    local maxWatches = questDB:Get("maxWatches", 10)

    -- Count current tracked quests
    local count = 0
    for _ in pairs(tracked) do count = count + 1 end

    if count >= maxWatches and not tracked[title] then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(string.format("Quest Tracker: Cannot track more than %d quests.", maxWatches), 1.0, 0.2, 0.2, 1.0)
        end
        return false
    end

    tracked[title] = true
    questDB:Set("trackedQuests", tracked)

    -- Synchronize with native C client watch list if index is valid
    if questIndex and questIndex > 0 then
        if not IsQuestWatched(questIndex) then
            AddQuestWatch(questIndex)
        end
    end

    self:UpdateTracker()
    return true
end

-- Untrack a quest
function PUIQuestWatch:UntrackQuest(questIndexOrTitle)
    local questIndex, title
    if type(questIndexOrTitle) == "number" then
        questIndex = questIndexOrTitle
        title = GetQuestLogTitle(questIndex)
    else
        title = questIndexOrTitle
        questIndex = self:FindQuestLogIndex(title)
    end

    if not title or title == "" then return false end

    local tracked = self:GetTrackedList()
    tracked[title] = nil
    questDB:Set("trackedQuests", tracked)

    -- Remove from native C client watch list
    if questIndex and questIndex > 0 then
        if IsQuestWatched(questIndex) then
            RemoveQuestWatch(questIndex)
        end
    end

    self:UpdateTracker()
    return true
end

-- Toggle tracking on/off
function PUIQuestWatch:ToggleQuest(questIndexOrTitle)
    if self:IsTracked(questIndexOrTitle) then
        return self:UntrackQuest(questIndexOrTitle)
    else
        return self:TrackQuest(questIndexOrTitle)
    end
end

-- Clear all tracked quests
function PUIQuestWatch:ClearAllTracked()
    questDB:Set("trackedQuests", {})
    for i = 1, (GetNumQuestWatches and GetNumQuestWatches() or 0) do
        local qIndex = GetQuestIndexForWatch(1)
        if qIndex then
            RemoveQuestWatch(qIndex)
        end
    end
    self:UpdateTracker()
end

-- Reconcile and restore tracked quests from SavedVariables into WoW engine
function PUIQuestWatch:ReconcileQuests()
    if self.isReconciling then return end
    self.isReconciling = true

    local tracked = self:GetTrackedList()
    local numEntries = GetNumQuestLogEntries()

    for i = 1, numEntries do
        local title, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader and title and tracked[title] then
            if not IsQuestWatched(i) then
                AddQuestWatch(i)
            end
        end
    end

    -- Clean up quests in DB that are no longer in the quest log (abandoned or completed/turned in)
    for savedTitle in pairs(tracked) do
        local found = false
        for i = 1, numEntries do
            local title, _, _, isHeader = GetQuestLogTitle(i)
            if not isHeader and title == savedTitle then
                found = true
                break
            end
        end
        if not found then
            tracked[savedTitle] = nil
        end
    end
    questDB:Set("trackedQuests", tracked)

    self.isReconciling = false
    self:UpdateTracker()
end

-- =========================================================================
-- DYNAMIC FONTSTRING ALLOCATOR & INTERACTIVE HEADERS
-- =========================================================================

-- Ensure a QuestWatchLine fontstring exists
function PUIQuestWatch:GetWatchLine(index)
    local line = _G["QuestWatchLine" .. index]
    if not line and QuestWatchFrame then
        line = QuestWatchFrame:CreateFontString("QuestWatchLine" .. index, "ARTWORK", "QuestWatchFontTemplate")
        if not line then
            line = QuestWatchFrame:CreateFontString("QuestWatchLine" .. index, "ARTWORK", "GameFontHighlight")
        end
        self.allocatedLines = math.max(self.allocatedLines, index)
    end
    return line
end

-- Get or create an interactive clickable header button for a quest
function PUIQuestWatch:GetHeaderButton(index)
    local btn = self.headerButtons[index]
    if not btn and QuestWatchFrame then
        btn = CreateFrame("Button", "PUIQuestWatchHeaderButton" .. index, QuestWatchFrame)
        btn:SetHeight(16)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Highlight texture on hover
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.25)
        hl:SetAllPoints(btn)
        btn.highlight = hl

        btn:SetScript("OnClick", function()
            if not btn.questIndex or not btn.questTitle then return end

            if IsShiftKeyDown() then
                -- Shift-Click: Insert quest link in chat, or untrack
                if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                    local link = "[" .. btn.questTitle .. "]"
                    ChatFrameEditBox:Insert(link)
                else
                    PUIQuestWatch:UntrackQuest(btn.questTitle)
                end
            else
                -- Left-Click: Open Quest Log directly to this quest
                if not QuestLogFrame:IsVisible() then
                    ShowUIPanel(QuestLogFrame)
                end
                local curIndex = PUIQuestWatch:FindQuestLogIndex(btn.questTitle) or btn.questIndex
                if curIndex and curIndex > 0 then
                    QuestLog_SetSelection(curIndex)
                    QuestLog_Update()
                end
            end
        end)

        btn:SetScript("OnEnter", function()
            if btn.titleLine then
                btn.titleLine:SetTextColor(1.0, 0.90, 0.30)
            end
            if GameTooltip and btn.questTitle then
                GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
                GameTooltip:ClearLines()
                local qIndex = PUIQuestWatch:FindQuestLogIndex(btn.questTitle) or btn.questIndex
                local _, level, questTag = GetQuestLogTitle(qIndex or 0)
                local headerText = (level and ("[" .. level .. "] ") or "") .. btn.questTitle
                if questTag and questTag ~= "" then
                    headerText = headerText .. " (" .. questTag .. ")"
                end
                GameTooltip:AddLine(headerText, 1.0, 0.82, 0.0)
                GameTooltip:AddLine("Left-Click: Open in Quest Log", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Shift-Click: Untrack / Link in Chat", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function()
            if btn.titleLine and btn.originalColor then
                local c = btn.originalColor
                btn.titleLine:SetTextColor(c.r, c.g, c.b)
            end
            if GameTooltip then GameTooltip:Hide() end
        end)

        self.headerButtons[index] = btn
    end
    return btn
end

-- =========================================================================
-- BULLETPROOF QUEST TRACKER RENDERER (QuestWatch_Update Overhaul)
-- =========================================================================

function PUIQuestWatch:UpdateTracker()
    if not QuestWatchFrame then return end
    if not questDB:Get("enabled", true) then
        QuestWatchFrame:Hide()
        return
    end

    local tracked = self:GetTrackedList()
    local showLevels = questDB:Get("showLevels", true)
    local lineSpacing = questDB:Get("lineSpacing", 2)
    local questSpacing = questDB:Get("questSpacing", 6)

    local lineIndex = 1
    local headerIndex = 1
    local questWatchMaxWidth = 0
    local prevLine = nil

    -- Gather all active tracked quests
    local numEntries = GetNumQuestLogEntries()
    local activeTracked = {}

    for i = 1, numEntries do
        local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        if not isHeader and title and tracked[title] then
            table.insert(activeTracked, {
                index = i,
                title = title,
                level = level,
                questTag = questTag,
                isComplete = isComplete,
            })
        end
    end

    -- Render each tracked quest
    for qIdx, qData in ipairs(activeTracked) do
        local questIndex = qData.index
        local title = qData.title
        local level = qData.level
        local questTag = qData.questTag
        local isComplete = qData.isComplete
        local numObjectives = GetNumQuestLeaderBoards(questIndex) or 0

        -- 1. TITLE LINE
        local titleLine = self:GetWatchLine(lineIndex)
        if titleLine then
            local tagStr = ""
            if questTag and questTag ~= "" then
                if questTag == "ELITE" or questTag == "Elite" then
                    tagStr = "+"
                elseif questTag == "DUNGEON" or questTag == "Dungeon" then
                    tagStr = " [D]"
                elseif questTag == "RAID" or questTag == "Raid" then
                    tagStr = " [R]"
                elseif questTag == "PVP" or questTag == "PvP" then
                    tagStr = " [PvP]"
                end
            end

            local levelPrefix = ""
            if showLevels and level and level > 0 then
                levelPrefix = "[" .. level .. tagStr .. "] "
            end

            titleLine:SetText(levelPrefix .. title)
            local color = self:GetQuestColor(level)
            titleLine:SetTextColor(color.r, color.g, color.b)

            titleLine:ClearAllPoints()
            if lineIndex == 1 then
                titleLine:SetPoint("TOPLEFT", QuestWatchFrame, "TOPLEFT", 0, -2)
            else
                titleLine:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -questSpacing)
            end
            titleLine:Show()

            local titleWidth = titleLine:GetWidth() or 0
            if titleWidth > questWatchMaxWidth then
                questWatchMaxWidth = titleWidth
            end

            -- Overlay clickable header button
            local headerBtn = self:GetHeaderButton(headerIndex)
            if headerBtn then
                headerBtn:ClearAllPoints()
                headerBtn:SetPoint("TOPLEFT", titleLine, "TOPLEFT", -2, 2)
                headerBtn:SetWidth(math.max(titleWidth + 4, 120))
                headerBtn:SetHeight((titleLine:GetHeight() or 14) + 4)
                headerBtn.questIndex = questIndex
                headerBtn.questTitle = title
                headerBtn.titleLine = titleLine
                headerBtn.originalColor = color
                headerBtn:Show()
                headerIndex = headerIndex + 1
            end

            prevLine = titleLine
            lineIndex = lineIndex + 1

            -- 2. OBJECTIVES LINES
            local objectivesFinished = 0
            if numObjectives > 0 then
                for j = 1, numObjectives do
                    local objText, objType, finished = GetQuestLogLeaderBoard(j, questIndex)
                    local objLine = self:GetWatchLine(lineIndex)
                    if objLine and objText and objText ~= "" then
                        objLine:SetText("  • " .. objText)

                        if finished then
                            objLine:SetTextColor(0.40, 1.00, 0.40) -- Bright light green for completed
                            objectivesFinished = objectivesFinished + 1
                        else
                            objLine:SetTextColor(0.85, 0.85, 0.85) -- Clean high-legibility light gray
                        end

                        objLine:ClearAllPoints()
                        objLine:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -lineSpacing)
                        objLine:Show()

                        local objWidth = objLine:GetWidth() or 0
                        if objWidth > questWatchMaxWidth then
                            questWatchMaxWidth = objWidth
                        end

                        prevLine = objLine
                        lineIndex = lineIndex + 1
                    end
                end
            else
                -- Quest has no leaderboards (e.g. event quest, talk to NPC) or ready to turn in
                local objLine = self:GetWatchLine(lineIndex)
                if objLine then
                    if isComplete then
                        objLine:SetText("  • Complete (Ready to turn in)")
                        objLine:SetTextColor(0.20, 1.00, 0.20)
                    else
                        objLine:SetText("  • Speak with questgiver")
                        objLine:SetTextColor(1.00, 0.85, 0.30)
                    end

                    objLine:ClearAllPoints()
                    objLine:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -lineSpacing)
                    objLine:Show()

                    local objWidth = objLine:GetWidth() or 0
                    if objWidth > questWatchMaxWidth then
                        questWatchMaxWidth = objWidth
                    end

                    prevLine = objLine
                    lineIndex = lineIndex + 1
                end
            end

            -- If all objectives complete, indicate on quest header
            if numObjectives > 0 and objectivesFinished == numObjectives then
                titleLine:SetText(levelPrefix .. title .. " (Complete)")
                titleLine:SetTextColor(1.00, 0.85, 0.20)
            end
        end
    end

    -- Hide unused watch lines
    for i = lineIndex, self.allocatedLines do
        local line = _G["QuestWatchLine" .. i]
        if line then line:Hide() end
    end

    -- Hide unused header buttons
    for i = headerIndex, table.getn(self.headerButtons) do
        local btn = self.headerButtons[i]
        if btn then btn:Hide() end
    end

    -- Update tracking indicator in Quest Log
    if QuestLogTrackTracking then
        if table.getn(activeTracked) > 0 then
            QuestLogTrackTracking:SetVertexColor(0, 1.0, 0)
        else
            QuestLogTrackTracking:SetVertexColor(1.0, 0, 0)
        end
    end

    -- Sizing & Frame Visibility
    if lineIndex == 1 then
        QuestWatchFrame:Hide()
        return
    else
        QuestWatchFrame:Show()
        local calculatedHeight = (lineIndex - 1) * 14 + (table.getn(activeTracked) * questSpacing) + 12
        local calculatedWidth = math.max(questWatchMaxWidth + 16, 200)
        QuestWatchFrame:SetHeight(calculatedHeight)
        QuestWatchFrame:SetWidth(calculatedWidth)
    end

    -- Stabilize Anchor against Blizzard UIParent_ManageFramePositions reset
    self:StabilizeAnchor()
end

-- =========================================================================
-- ANCHOR STABILIZATION & MOVER PRESERVATION
-- =========================================================================

function PUIQuestWatch:StabilizeAnchor()
    if not QuestWatchFrame then return end

    -- Check if PUIMover has a custom saved position for QuestWatchFrame
    local mover = PUIMover or Primus.PUIMover
    local moverPos = mover and mover.GetPosition and mover:GetPosition("QuestWatchFrame")

    if moverPos and moverPos.point then
        QuestWatchFrame:ClearAllPoints()
        QuestWatchFrame:SetPoint(moverPos.point or "TOPRIGHT", UIParent, moverPos.relativePoint or "TOPRIGHT", moverPos.x or -10, moverPos.y or -200)
        if QuestWatchFrame.SetUserPlaced then
            QuestWatchFrame:SetUserPlaced(true)
        end
    else
        -- If no custom position, keep cleanly anchored below MinimapCluster without conflicting points
        local point, relativeTo = QuestWatchFrame:GetPoint()
        if not point or point ~= "TOPRIGHT" or relativeTo ~= MinimapCluster then
            QuestWatchFrame:ClearAllPoints()
            local anchorFrame = MinimapCluster or UIParent
            QuestWatchFrame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", -10, -15)
        end
    end
end

-- =========================================================================
-- BLIZZARD BUG OVERRIDES & INTERCEPTIONS
-- =========================================================================

local function InterceptBlizzardQuestWatch()
    -- 1. Completely neutralize Blizzard's 5-minute AutoQuestWatch_OnUpdate countdown
    _G.AutoQuestWatch_OnUpdate = function(elapsed)
        -- No-op: Quests never expire on a timer in PrimusUI!
    end

    -- 2. Override AutoQuestWatch_Insert to prevent table key corruption
    _G.AutoQuestWatch_Insert = function(questIndex, watchTimer)
        if not questIndex or questIndex <= 0 then return end
        PUIQuestWatch:TrackQuest(questIndex)
    end

    -- 3. Override AutoQuestWatch_Update
    _G.AutoQuestWatch_Update = function(questIndex)
        if not questIndex or questIndex <= 0 then return end
        if questDB:Get("autoWatchProgress", true) then
            PUIQuestWatch:TrackQuest(questIndex)
        else
            PUIQuestWatch:UpdateTracker()
        end
    end

    -- 4. Override AutoQuestWatch_CheckDeleted to safely clean up removed quests
    _G.AutoQuestWatch_CheckDeleted = function()
        PUIQuestWatch:ReconcileQuests()
    end

    -- 5. Override global QuestWatch_Update with our enhanced renderer
    _G.QuestWatch_Update = function()
        PUIQuestWatch:UpdateTracker()
    end

    -- 6. Hook QuestLogTitleButton_OnClick for Shift-Click tracking toggle
    if QuestLogTitleButton_OnClick then
        local origTitleClick = QuestLogTitleButton_OnClick
        _G.QuestLogTitleButton_OnClick = function(button)
            if IsShiftKeyDown() and not this.isHeader then
                if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                    origTitleClick(button)
                    return
                end

                local questIndex = this:GetID() + (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0)
                PUIQuestWatch:ToggleQuest(questIndex)

                QuestLog_SetSelection(questIndex)
                QuestLog_Update()
                return
            end
            origTitleClick(button)
        end
    end

    -- 7. Hook UIParent_ManageFramePositions so it doesn't corrupt QuestWatchFrame anchors
    if UIParent_ManageFramePositions then
        local origManage = UIParent_ManageFramePositions
        _G.UIParent_ManageFramePositions = function()
            if origManage then origManage() end
            PUIQuestWatch:StabilizeAnchor()
        end
    end
end

-- =========================================================================
-- EVENT DISPATCHER
-- =========================================================================

function PUIQuestWatch:OnEvent(event, arg1, arg2, arg3)
    if event == "PLAYER_ENTERING_WORLD" then
        if not self.isInitialized then
            self.isInitialized = true
            InterceptBlizzardQuestWatch()
        end
        self:ReconcileQuests()
        self:StabilizeAnchor()

    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        self:ReconcileQuests()

    elseif event == "QUEST_WATCH_UPDATE" then
        -- arg1 is questIndex
        if questDB:Get("autoWatchProgress", true) and arg1 then
            self:TrackQuest(arg1)
        else
            self:UpdateTracker()
        end

    elseif event == "QUEST_FINISHED" or event == "QUEST_COMPLETE" then
        self:ReconcileQuests()

    elseif event == "UI_INFO_MESSAGE" then
        -- Detect quest acceptance message if autoWatchNew is enabled
        if questDB:Get("autoWatchNew", true) and arg1 then
            -- Reconcile quests shortly after quest acceptance
            self:ReconcileQuests()
        end
    end
end

-- =========================================================================
-- INITIALIZATION & SLASH COMMANDS
-- =========================================================================

function PUIQuestWatch:Initialize()
    Events:Register("PLAYER_ENTERING_WORLD", function() self:OnEvent("PLAYER_ENTERING_WORLD") end)
    Events:Register("QUEST_LOG_UPDATE",      function() self:OnEvent("QUEST_LOG_UPDATE") end)
    Events:Register("UNIT_QUEST_LOG_CHANGED", function(unit) if unit == "player" then self:OnEvent("UNIT_QUEST_LOG_CHANGED") end end)
    Events:Register("QUEST_WATCH_UPDATE",    function(qIndex) self:OnEvent("QUEST_WATCH_UPDATE", qIndex) end)
    Events:Register("QUEST_FINISHED",        function() self:OnEvent("QUEST_FINISHED") end)
    Events:Register("QUEST_COMPLETE",        function() self:OnEvent("QUEST_COMPLETE") end)
    Events:Register("UI_INFO_MESSAGE",       function(msg) self:OnEvent("UI_INFO_MESSAGE", msg) end)

    InterceptBlizzardQuestWatch()

    -- Register with PUIMover
    if PUIMover and PUIMover.Register and QuestWatchFrame then
        PUIMover:Register(QuestWatchFrame, "QuestWatchFrame", "Quest Tracker", "UTILITY")
    end
end

-- Slash Commands
if Primus.Console and Primus.Console.RegisterSubCommand then
    Primus.Console:RegisterSubCommand("quest", function(argParam, parts)
        local cmd = string.lower(argParam or "")

        if cmd == "clear" then
            PUIQuestWatch:ClearAllTracked()
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuestWatch]: Cleared all tracked quests.", "69ccf0"))
        elseif cmd == "levels" then
            local cur = questDB:Get("showLevels", true)
            questDB:Set("showLevels", not cur)
            PUIQuestWatch:UpdateTracker()
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuestWatch]: Quest levels " .. (not cur and "enabled." or "disabled."), "69ccf0"))
        elseif cmd == "autowatch" then
            local cur = questDB:Get("autoWatchProgress", true)
            questDB:Set("autoWatchProgress", not cur)
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuestWatch]: Auto-watch on progress " .. (not cur and "enabled." or "disabled."), "69ccf0"))
        else
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuestWatch]: Commands: /pui quest clear | /pui quest levels | /pui quest autowatch", "ffbb33"))
        end
    end, "Quest Tracker & Watchlist Manager")
end
