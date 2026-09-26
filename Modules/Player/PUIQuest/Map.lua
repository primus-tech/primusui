--[[
    PrimusUI Module: PUIQuest (World Map POI Overlay & Clustering Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Renders high-performance pooled POI pins directly onto WorldMapButton
    with interactive tooltips, clustering, level colors, and zero memory allocations.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuest = Primus.PUIQuest or {}
Primus.PUIQuest = PUIQuest
_G.PUIQuest = PUIQuest

local Map = {}
PUIQuest.Map = Map

local Utils  = Primus.Utils
local Media  = Primus.Media
local Events = Primus.Events

-- Pin Pool & Active Pins
local pinPool = {}
local activePins = {}
local pinIndex = 0

-- Difficulty Colors
local DIFFICULTY_COLORS = {
    ["impossible"]    = { r = 1.00, g = 0.15, b = 0.15 }, -- Red
    ["verydifficult"] = { r = 1.00, g = 0.50, b = 0.20 }, -- Orange
    ["difficult"]     = { r = 1.00, g = 0.85, b = 0.10 }, -- Yellow
    ["standard"]      = { r = 0.25, g = 0.85, b = 0.25 }, -- Green
    ["trivial"]       = { r = 0.60, g = 0.60, b = 0.60 }, -- Gray
}

local function GetDifficultyColor(level)
    if not level or level <= 0 then return DIFFICULTY_COLORS["standard"] end
    local pLevel = UnitLevel("player") or 1
    local diff = level - pLevel
    if diff >= 5 then
        return DIFFICULTY_COLORS["impossible"]
    elseif diff >= 3 then
        return DIFFICULTY_COLORS["verydifficult"]
    elseif diff >= -2 then
        return DIFFICULTY_COLORS["difficult"]
    elseif -diff <= (GetQuestGreenRange and GetQuestGreenRange() or 5) then
        return DIFFICULTY_COLORS["standard"]
    else
        return DIFFICULTY_COLORS["trivial"]
    end
end

-- =========================================================================
-- PIN POOL ENGINE
-- =========================================================================

local function CreatePin()
    pinIndex = pinIndex + 1
    local pin = CreateFrame("Button", "PUIQuest_MapPin_" .. pinIndex, WorldMapButton)
    pin:SetWidth(18)
    pin:SetHeight(18)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 6)

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(pin)
    pin.icon = icon

    local text = pin:CreateFontString(nil, "OVERLAY")
    text:SetFont(Media:Fetch("font", "Default"), 11, "OUTLINE")
    text:SetPoint("CENTER", pin, "CENTER", 0, 0)
    pin.label = text

    -- Tooltip Handlers
    pin:SetScript("OnEnter", function()
        if not this.data then return end
        WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
        WorldMapTooltip:ClearLines()

        local d = this.data
        local col = GetDifficultyColor(d.level)
        WorldMapTooltip:AddLine(d.title or "Quest", col.r, col.g, col.b)

        if d.pinType == "AVAILABLE" then
            WorldMapTooltip:AddLine(string.format("Quest Giver: |cffffffff%s|r", d.npcName or "NPC"), 1, 0.82, 0)
            WorldMapTooltip:AddLine("Status: Available Quest", 0.7, 0.7, 0.7)
            if d.minLevel and d.minLevel > 1 then
                WorldMapTooltip:AddLine(string.format("Requires Level: %d", d.minLevel), 0.6, 0.6, 0.6)
            end
        elseif d.pinType == "TURNIN" then
            WorldMapTooltip:AddLine(string.format("Turn In: |cffffffff%s|r", d.npcName or "NPC"), 1, 0.82, 0)
            WorldMapTooltip:AddLine("Status: |cff00ff00Ready for Turn-in|r", 0.7, 1.0, 0.7)
        elseif d.pinType == "OBJECTIVE" then
            WorldMapTooltip:AddLine(string.format("Objective: |cffffffff%s|r", d.objText or "Objective"), 0.4, 0.85, 1.0)
            if d.targetName then
                WorldMapTooltip:AddLine(string.format("Target: |cffffffff%s|r", d.targetName), 0.8, 0.8, 0.8)
            end
        elseif d.pinType == "TRACK" then
            WorldMapTooltip:AddLine(string.format("Node: |cffffffff%s|r", d.targetName or "Tracked Node"), 0.2, 1.0, 0.4)
        end

        WorldMapTooltip:AddLine("Left-Click: Focus Navigation Arrow", 0.5, 0.5, 0.5)
        WorldMapTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        WorldMapTooltip:Hide()
    end)

    pin:SetScript("OnClick", function()
        if this.data and this.data.title then
            PUIQuest:FocusQuest(this.data.title)
        end
    end)

    return pin
end

local function AcquirePin()
    if table.getn(pinPool) > 0 then
        local pin = table.remove(pinPool)
        pin:Show()
        return pin
    end
    return CreatePin()
end

function Map:ClearPins()
    for i = 1, table.getn(activePins) do
        local pin = activePins[i]
        pin:Hide()
        pin.data = nil
        table.insert(pinPool, pin)
    end
    activePins = {}
end

-- =========================================================================
-- Extract and project coordinates matching current map zone (including subzone scaling)
local function GetZoneCoords(spawnsTbl, currentZoneName, currentZoneID)
    if not spawnsTbl or not spawnsTbl.coords then return {} end
    local DB = PUIQuest.DB
    if not DB or not DB["zones"] then return {} end

    local zonesLoc = DB["zones"]["enUS"] or DB["zones"]["loc"]
    local zonesData = DB["zones"]["data"]
    if not zonesLoc then return {} end

    local results = {}
    for _, c in pairs(spawnsTbl.coords) do
        local x = c[1]
        local y = c[2]
        local zID = c[3]

        if zID and x and y then
            local zName = zonesLoc[zID]
            if zName and (zName == currentZoneName or zID == currentZoneID) then
                table.insert(results, { x = x, y = y, zoneID = zID })
            elseif zonesData and zonesData[zID] then
                local pID, w, h, ox, oy = unpack(zonesData[zID])
                local pName = zonesLoc[pID]
                if pName and (pName == currentZoneName or pID == currentZoneID) then
                    local px = (x * (w or 100) / 100) + (ox or 0)
                    local py = (y * (h or 100) / 100) + (oy or 0)
                    table.insert(results, { x = px, y = py, zoneID = pID })
                end
            end
        end
    end
    return results
end

-- =========================================================================
-- WORLD MAP UPDATE RENDERER
-- =========================================================================

function Map:Update()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end
    if not PUIQuest.db or not PUIQuest.db:Get("showWorldMapPins", true) or not PUIQuest.db:Get("enabled", true) then
        self:ClearPins()
        return
    end

    self:ClearPins()

    local mapContinent = GetCurrentMapContinent()
    local mapZone = GetCurrentMapZone()
    if mapContinent <= 0 or mapZone <= 0 then return end

    local zoneNames = { GetMapZones(mapContinent) }
    local currentZoneName = zoneNames[mapZone]
    if not currentZoneName then return end

    local w = WorldMapButton:GetWidth()
    local h = WorldMapButton:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end

    local DB = PUIQuest.DB
    if not DB then return end

    -- 1. Scan Active Quests in Log
    local numEntries = GetNumQuestLogEntries()
    for qIndex = 1, numEntries do
        local title, level, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(qIndex)
        if not isHeader and title then
            local q = PUIQuest.Database:FindQuest(title)
            if q and q.data then
                -- Turn-in pin if completed
                if isComplete and isComplete > 0 and PUIQuest.db:Get("showTurnIns", true) then
                    local endUnits = q.data["end"] and q.data["end"]["U"]
                    if endUnits then
                        for _, uID in pairs(endUnits) do
                            local unit = PUIQuest.Database:FindUnit(uID)
                            if unit and unit.spawns then
                                local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                                for _, coord in pairs(coords) do
                                    local pin = AcquirePin()
                                    pin:ClearAllPoints()
                                    pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", (coord.x / 100) * w, -(coord.y / 100) * h)
                                    pin.icon:SetTexture(nil)
                                    pin.label:SetText("?")
                                    pin.label:SetTextColor(1.0, 0.82, 0.0)
                                    pin.data = {
                                        title = title,
                                        level = level,
                                        npcName = unit.name,
                                        pinType = "TURNIN",
                                    }
                                    table.insert(activePins, pin)
                                end
                            end
                        end
                    end
                elseif not isComplete and PUIQuest.db:Get("showObjectives", true) then
                    -- In-progress Unit Objectives
                    local objUnits = q.data["obj"] and q.data["obj"]["U"]
                    if objUnits then
                        for oIdx, uID in pairs(objUnits) do
                            local unit = PUIQuest.Database:FindUnit(uID)
                            if unit and unit.spawns then
                                local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                                for _, coord in pairs(coords) do
                                    local pin = AcquirePin()
                                    pin:ClearAllPoints()
                                    pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", (coord.x / 100) * w, -(coord.y / 100) * h)
                                    pin.icon:SetTexture(nil)
                                    pin.label:SetText(tostring(oIdx))
                                    pin.label:SetTextColor(0.4, 0.85, 1.0)
                                    pin.data = {
                                        title = title,
                                        level = level,
                                        targetName = unit.name,
                                        objText = "Slay " .. unit.name,
                                        pinType = "OBJECTIVE",
                                    }
                                    table.insert(activePins, pin)
                                end
                            end
                        end
                    end

                    -- In-progress Object Objectives
                    local objObjects = q.data["obj"] and q.data["obj"]["O"]
                    if objObjects then
                        for oIdx, oID in pairs(objObjects) do
                            local obj = PUIQuest.Database:FindObject(oID)
                            if obj and obj.spawns then
                                local coords = GetZoneCoords(obj.spawns, currentZoneName, mapZone)
                                for _, coord in pairs(coords) do
                                    local pin = AcquirePin()
                                    pin:ClearAllPoints()
                                    pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", (coord.x / 100) * w, -(coord.y / 100) * h)
                                    pin.icon:SetTexture(nil)
                                    pin.label:SetText(tostring(oIdx))
                                    pin.label:SetTextColor(0.4, 0.85, 1.0)
                                    pin.data = {
                                        title = title,
                                        level = level,
                                        targetName = obj.name,
                                        objText = "Interact with " .. obj.name,
                                        pinType = "OBJECTIVE",
                                    }
                                    table.insert(activePins, pin)
                                end
                            end
                        end
                    end

                    -- In-progress Item Loot Objectives
                    local objItems = q.data["obj"] and q.data["obj"]["I"]
                    if objItems then
                        for oIdx, iID in pairs(objItems) do
                            local item = PUIQuest.Database:FindItem(iID)
                            if item and item.data and item.data["U"] then
                                for uID in pairs(item.data["U"]) do
                                    local unit = PUIQuest.Database:FindUnit(uID)
                                    if unit and unit.spawns then
                                        local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                                        for _, coord in pairs(coords) do
                                            local pin = AcquirePin()
                                            pin:ClearAllPoints()
                                            pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", (coord.x / 100) * w, -(coord.y / 100) * h)
                                            pin.icon:SetTexture(nil)
                                            pin.label:SetText(tostring(oIdx))
                                            pin.label:SetTextColor(0.4, 0.85, 1.0)
                                            pin.data = {
                                                title = title,
                                                level = level,
                                                targetName = unit.name,
                                                objText = "Loot " .. item.name .. " from " .. unit.name,
                                                pinType = "OBJECTIVE",
                                            }
                                            table.insert(activePins, pin)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Available Quests in Zone
    if PUIQuest.db:Get("showAvailableQuests", true) then
        local pLevel = UnitLevel("player") or 1
        local questData = DB["quests"] and DB["quests"]["data"]
        if questData then
            for qID, qInfo in pairs(questData) do
                local minLvl = qInfo["min"] or 1
                local qLvl = qInfo["lvl"] or minLvl
                if pLevel >= minLvl and qInfo["start"] and qInfo["start"]["U"] then
                    for _, uID in pairs(qInfo["start"]["U"]) do
                        local unit = PUIQuest.Database:FindUnit(uID)
                        if unit and unit.spawns then
                            local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                            if table.getn(coords) > 0 then
                                -- Check if already active in log
                                local qEntry = PUIQuest.Database:FindQuest(qID)
                                local qTitle = qEntry and qEntry.title or ("Quest #" .. qID)
                                local inLog = false
                                for i = 1, numEntries do
                                    if GetQuestLogTitle(i) == qTitle then inLog = true; break end
                                end

                                if not inLog then
                                    for _, coord in pairs(coords) do
                                        local pin = AcquirePin()
                                        pin:ClearAllPoints()
                                        pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", (coord.x / 100) * w, -(coord.y / 100) * h)
                                        pin.icon:SetTexture(nil)
                                        local col = GetDifficultyColor(qLvl)
                                        pin.label:SetText("!")
                                        pin.label:SetTextColor(col.r, col.g, col.b)
                                        pin.data = {
                                            title = qTitle,
                                            level = qLvl,
                                            minLevel = minLvl,
                                            npcName = unit.name,
                                            pinType = "AVAILABLE",
                                        }
                                        table.insert(activePins, pin)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
