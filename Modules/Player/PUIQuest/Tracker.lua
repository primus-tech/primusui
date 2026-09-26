--[[
    PrimusUI Module: PUIQuest (Minimap Radar & 3D HUD Navigation Arrow Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Features:
    1. 3D HUD Navigation Arrow: Rotating MDX pointer model with real-time distance in yards.
    2. Multi-Zone Objective Resolution: Accurately maps both standard zones and subzones (including Turtle WoW).
    3. Dynamic Objective Resolution: Intelligently prioritizes slay/interact/loot objectives before turn-in NPCs.
    4. Auto-Targeting Closest Active Quest: Auto-detects closest tracked or quest log objective.
    5. Cross-Zone Guidance: Clearly indicates destination zone when objective is in another area.
    6. Minimap Perimeter Radar: Rotating 3D edge blip pointing towards active objective.
    7. PUIMover Support: Move and anchor the HUD navigation arrow anywhere.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuest = Primus.PUIQuest or {}
Primus.PUIQuest = PUIQuest
_G.PUIQuest = PUIQuest

local Tracker = {}
PUIQuest.Tracker = Tracker

local Utils   = Primus.Utils
local Media   = Primus.Media
local Events  = Primus.Events
local PUIMover = Primus.PUIMover

-- State Variables
local hudArrow          = nil
local hudModel          = nil
local hudDistText       = nil
local hudTitleText      = nil
local minimapPin        = nil
local minimapModel      = nil

local manualFocusQuest  = nil
local currentActiveData = nil
local lastPlayerX       = 0
local lastPlayerY       = 0
local estimatedFacing   = 0

-- =========================================================================
-- WIDGET CREATION (3D HUD ARROW & MINIMAP RADAR)
-- =========================================================================

local function CreateHUDArrow()
    if hudArrow then return hudArrow end

    hudArrow = CreateFrame("Button", "PUIQuestHUDArrow", UIParent)
    hudArrow:SetWidth(150)
    hudArrow:SetHeight(52)
    hudArrow:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    hudArrow:SetFrameStrata("MEDIUM")
    hudArrow:SetClampedToScreen(true)
    hudArrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Glassmorphic pill backdrop
    hudArrow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    hudArrow:SetBackdropColor(0.06, 0.08, 0.12, 0.85)
    hudArrow:SetBackdropBorderColor(0.20, 0.35, 0.55, 0.90)

    -- 3D Model Pointer
    local model = CreateFrame("Model", "PUIQuestHUDArrowModel", hudArrow)
    model:SetWidth(42)
    model:SetHeight(42)
    model:SetPoint("TOP", hudArrow, "TOP", 0, 4)
    model:SetModel("Interface\\Minimap\\ROTATING-MINIMAPARROW.mdx")
    model:SetModelScale(0.85)
    model:SetPosition(0, 0, 0)
    if model.SetCamera then model:SetCamera(0) end
    hudModel = model

    -- Distance FontString
    local dist = hudArrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dist:SetPoint("TOP", model, "BOTTOM", 0, 4)
    local distFont = (Media and Media.Fetch and Media:Fetch("font", "Default")) or "Fonts\\FRIZQT__.TTF"
    dist:SetFont(distFont, 11, "OUTLINE")
    dist:SetTextColor(1.0, 1.0, 1.0)
    hudDistText = dist

    -- Quest / Objective Title FontString
    local title = hudArrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", dist, "BOTTOM", 0, -1)
    local titleFont = (Media and Media.Fetch and Media:Fetch("font", "Default")) or "Fonts\\FRIZQT__.TTF"
    title:SetFont(titleFont, 10, "OUTLINE")
    title:SetTextColor(0.9, 0.8, 0.5)
    title:SetWidth(144)
    title:SetJustifyH("CENTER")
    hudTitleText = title

    -- Self-driving real-time update loop (throttled to 0.1s)
    local updateElapsed = 0
    hudArrow:SetScript("OnUpdate", function()
        updateElapsed = updateElapsed + (arg1 or 0.05)
        if updateElapsed >= 0.10 then
            updateElapsed = 0
            Tracker:Update()
        end
    end)

    -- Interactive Scripts
    hudArrow:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            Tracker:SetFocus(nil)
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Reset to automatic closest-quest navigation.", "69ccf0"))
        else
            if currentActiveData and currentActiveData.title then
                if not QuestLogFrame:IsVisible() then
                    ShowUIPanel(QuestLogFrame)
                end
                if Primus.PUIQuestWatch and Primus.PUIQuestWatch.FindQuestLogIndex then
                    local qIdx = Primus.PUIQuestWatch:FindQuestLogIndex(currentActiveData.title)
                    if qIdx and qIdx > 0 then
                        QuestLog_SetSelection(qIdx)
                        QuestLog_Update()
                    end
                end
            end
        end
    end)

    hudArrow:SetScript("OnEnter", function()
        if not currentActiveData then return end
        GameTooltip:SetOwner(hudArrow, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(currentActiveData.title or "Quest Target", 1.0, 0.82, 0.0)
        if currentActiveData.text and currentActiveData.text ~= "" then
            GameTooltip:AddLine(string.format("Objective: |cffffffff%s|r", currentActiveData.text), 0.4, 0.85, 1.0)
        end
        if currentActiveData.isDifferentZone then
            GameTooltip:AddLine(string.format("Destination: |cffffbb33%s|r", currentActiveData.zoneName or "Other Zone"), 1.0, 0.82, 0.2)
        elseif currentActiveData.yards then
            GameTooltip:AddLine(string.format("Distance: |cffffffff%d yards|r", currentActiveData.yards), 0.7, 0.7, 0.7)
        end
        if currentActiveData.x and currentActiveData.y and not currentActiveData.isDifferentZone then
            GameTooltip:AddLine(string.format("Coords: |cffffd100%.1f, %.1f|r", currentActiveData.x * 100, currentActiveData.y * 100), 0.6, 0.6, 0.6)
        end
        if manualFocusQuest then
            GameTooltip:AddLine("Status: |cffffbb33Manually Locked|r (Right-Click to unlock)", 1.0, 0.7, 0.2)
        else
            GameTooltip:AddLine("Status: |cff00ff00Auto-Targeting Closest|r", 0.5, 1.0, 0.5)
        end
        GameTooltip:AddLine("Left-Click: Open in Quest Log", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    hudArrow:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Register with PUIMover
    if PUIMover and PUIMover.Register then
        PUIMover:Register(hudArrow, "PUIQuestHUDArrow", "Quest Navigation Arrow", "HUD")
    end

    hudArrow:Hide()
    return hudArrow
end

local function CreateMinimapPin()
    if minimapPin then return minimapPin end

    minimapPin = CreateFrame("Button", "PUIQuest_MinimapNavArrow", Minimap)
    minimapPin:SetWidth(22)
    minimapPin:SetHeight(22)
    minimapPin:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    minimapPin:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    -- 3D Model for Minimap Edge
    local model = CreateFrame("Model", "PUIQuest_MinimapNavModel", minimapPin)
    model:SetAllPoints(minimapPin)
    model:SetModel("Interface\\Minimap\\ROTATING-MINIMAPARROW.mdx")
    model:SetModelScale(0.55)
    model:SetPosition(0, 0, 0)
    if model.SetCamera then model:SetCamera(0) end
    minimapModel = model

    minimapPin:SetScript("OnClick", function()
        if currentActiveData and currentActiveData.title then
            if not QuestLogFrame:IsVisible() then ShowUIPanel(QuestLogFrame) end
        end
    end)

    minimapPin:Hide()
    return minimapPin
end

-- =========================================================================
-- ZONE ALIASES & MULTI-ZONE COORDINATE RESOLVER
-- =========================================================================

local function GetPlayerZoneAliases()
    local aliases = {}

    local mapContinent = GetCurrentMapContinent()
    local mapZone = GetCurrentMapZone()
    if mapContinent > 0 and mapZone > 0 then
        local zoneNames = { GetMapZones(mapContinent) }
        local mzName = zoneNames[mapZone]
        if mzName and mzName ~= "" then
            aliases[string.lower(mzName)] = true
        end
    end

    local z = GetZoneText and GetZoneText()
    if z and z ~= "" then aliases[string.lower(z)] = true end

    local rz = GetRealZoneText and GetRealZoneText()
    if rz and rz ~= "" then aliases[string.lower(rz)] = true end

    local sz = GetSubZoneText and GetSubZoneText()
    if sz and sz ~= "" then aliases[string.lower(sz)] = true end

    local mz = GetMinimapZoneText and GetMinimapZoneText()
    if mz and mz ~= "" then aliases[string.lower(mz)] = true end

    return aliases, mapZone
end

local function ExtractZoneCoords(spawnsTbl, playerZones, currentMapZoneID)
    if not spawnsTbl then return {}, {} end
    local coordsList = spawnsTbl.coords or (type(spawnsTbl[1]) == "table" and spawnsTbl)
    if not coordsList then return {}, {} end

    local DB = PUIQuest.DB
    if not DB or not DB["zones"] then return {}, {} end

    local zonesLoc = DB["zones"]["enUS"] or DB["zones"]["loc"]
    local zonesData = DB["zones"]["data"]
    if not zonesLoc then return {}, {} end

    local localResults = {}
    local worldResults = {}

    for _, c in pairs(coordsList) do
        local x = c[1]
        local y = c[2]
        local zID = c[3]

        if zID and x and y then
            local zName = zonesLoc[zID]
            local isLocal = false
            local resolvedX = x / 100
            local resolvedY = y / 100
            local resolvedZoneName = zName or "Zone"

            -- Direct zone match
            if zName and playerZones[string.lower(zName)] then
                isLocal = true
            elseif currentMapZoneID and currentMapZoneID > 0 and zID == currentMapZoneID then
                isLocal = true
            elseif zonesData and zonesData[zID] then
                -- Parent zone projection
                local pID, w, h, ox, oy = unpack(zonesData[zID])
                if pID and pID > 0 then
                    local pName = zonesLoc[pID]
                    if pName and (playerZones[string.lower(pName)] or (currentMapZoneID and pID == currentMapZoneID)) then
                        resolvedX = ((x * (w or 100) / 100) + (ox or 0)) / 100
                        resolvedY = ((y * (h or 100) / 100) + (oy or 0)) / 100
                        resolvedZoneName = pName
                        isLocal = true
                    end
                end
            end

            local entry = {
                x = resolvedX,
                y = resolvedY,
                zoneID = zID,
                zoneName = resolvedZoneName,
            }

            if isLocal then
                table.insert(localResults, entry)
            else
                table.insert(worldResults, entry)
            end
        end
    end

    return localResults, worldResults
end

-- Find the best objective coordinate for a given quest
local function ResolveQuestObjective(questTitle, playerZones, currentMapZoneID, playerX, playerY, isComplete)
    if not questTitle or questTitle == "" then return nil end
    local q = PUIQuest.Database:FindQuest(questTitle)
    if not q or not q.data then return nil end

    -- Check completion state if not explicitly passed
    if isComplete == nil then
        local numEntries = GetNumQuestLogEntries() or 0
        for i = 1, numEntries do
            local title, _, _, isHeader, _, comp = GetQuestLogTitle(i)
            if not isHeader and title and string.lower(title) == string.lower(questTitle) then
                isComplete = comp
                break
            end
        end
    end

    local bestLocalCoord = nil
    local bestLocalDist = 999999
    local bestLocalText = nil

    local firstWorldCoord = nil
    local firstWorldText = nil

    local function Evaluate(spawns, labelText)
        if not spawns then return end
        local localCoords, worldCoords = ExtractZoneCoords(spawns, playerZones, currentMapZoneID)

        for _, coord in ipairs(localCoords) do
            local dx = coord.x - playerX
            local dy = coord.y - playerY
            local distSq = dx * dx + dy * dy
            if distSq < bestLocalDist then
                bestLocalDist = distSq
                bestLocalCoord = coord
                bestLocalText = labelText
            end
        end

        if not firstWorldCoord and table.getn(worldCoords) > 0 then
            firstWorldCoord = worldCoords[1]
            firstWorldText = labelText
        end
    end

    -- If Quest is COMPLETE: Point to Turn-in NPC / Object
    if isComplete == 1 or isComplete == true then
        local endUnits = q.data["end"] and q.data["end"]["U"]
        if endUnits then
            for _, uID in pairs(endUnits) do
                local unit = PUIQuest.Database:FindUnit(uID)
                if unit and unit.spawns then
                    Evaluate(unit.spawns, "Turn in: " .. unit.name)
                end
            end
        end
        local endObjects = q.data["end"] and q.data["end"]["O"]
        if endObjects then
            for _, oID in pairs(endObjects) do
                local obj = PUIQuest.Database:FindObject(oID)
                if obj and obj.spawns then
                    Evaluate(obj.spawns, "Turn in: " .. obj.name)
                end
            end
        end
    else
        -- If Quest is IN PROGRESS: Check Slay/Interact/Loot objectives FIRST

        -- 1. Unit Objectives (Slay / Talk)
        local objUnits = q.data["obj"] and q.data["obj"]["U"]
        if objUnits then
            for _, uID in pairs(objUnits) do
                local unit = PUIQuest.Database:FindUnit(uID)
                if unit and unit.spawns then
                    Evaluate(unit.spawns, "Slay: " .. unit.name)
                end
            end
        end

        -- 2. Object Objectives (Interact / Nodes)
        local objObjects = q.data["obj"] and q.data["obj"]["O"]
        if objObjects then
            for _, oID in pairs(objObjects) do
                local obj = PUIQuest.Database:FindObject(oID)
                if obj and obj.spawns then
                    Evaluate(obj.spawns, "Interact: " .. obj.name)
                end
            end
        end

        -- 3. Item Objectives (Drops / Chests / Vendors)
        local objItems = q.data["obj"] and q.data["obj"]["I"]
        if objItems then
            for _, iID in pairs(objItems) do
                local item = PUIQuest.Database:FindItem(iID)
                if item and item.data then
                    -- Dropped by Units
                    if item.data["U"] then
                        for uID in pairs(item.data["U"]) do
                            local unit = PUIQuest.Database:FindUnit(uID)
                            if unit and unit.spawns then
                                Evaluate(unit.spawns, "Loot: " .. item.name .. " (" .. unit.name .. ")")
                            end
                        end
                    end
                    -- Looted from Objects / Containers
                    if item.data["O"] then
                        for oID in pairs(item.data["O"]) do
                            local obj = PUIQuest.Database:FindObject(oID)
                            if obj and obj.spawns then
                                Evaluate(obj.spawns, "Gather: " .. item.name)
                            end
                        end
                    end
                    -- Purchased from Vendors
                    if item.data["V"] then
                        for vID in pairs(item.data["V"]) do
                            local vendor = PUIQuest.Database:FindUnit(vID)
                            if vendor and vendor.spawns then
                                Evaluate(vendor.spawns, "Buy: " .. item.name)
                            end
                        end
                    end
                end
            end
        end

        -- 4. Fallback if no specific objective coords: Check Turn-In
        if not bestLocalCoord and not firstWorldCoord then
            local endUnits = q.data["end"] and q.data["end"]["U"]
            if endUnits then
                for _, uID in pairs(endUnits) do
                    local unit = PUIQuest.Database:FindUnit(uID)
                    if unit and unit.spawns then
                        Evaluate(unit.spawns, "Turn in: " .. unit.name)
                    end
                end
            end
            local endObjects = q.data["end"] and q.data["end"]["O"]
            if endObjects then
                for _, oID in pairs(endObjects) do
                    local obj = PUIQuest.Database:FindObject(oID)
                    if obj and obj.spawns then
                        Evaluate(obj.spawns, "Turn in: " .. obj.name)
                    end
                end
            end
        end

        -- 5. Final Fallback: Starter NPC
        if not bestLocalCoord and not firstWorldCoord then
            local startUnits = q.data["start"] and q.data["start"]["U"]
            if startUnits then
                for _, uID in pairs(startUnits) do
                    local unit = PUIQuest.Database:FindUnit(uID)
                    if unit and unit.spawns then
                        Evaluate(unit.spawns, "Start: " .. unit.name)
                    end
                end
            end
        end
    end

    if bestLocalCoord then
        return {
            x = bestLocalCoord.x,
            y = bestLocalCoord.y,
            title = questTitle,
            text = bestLocalText or questTitle,
            zoneID = bestLocalCoord.zoneID,
            zoneName = bestLocalCoord.zoneName,
            isDifferentZone = false,
        }
    elseif firstWorldCoord then
        return {
            x = firstWorldCoord.x,
            y = firstWorldCoord.y,
            title = questTitle,
            text = firstWorldText or questTitle,
            zoneID = firstWorldCoord.zoneID,
            zoneName = firstWorldCoord.zoneName,
            isDifferentZone = true,
        }
    end

    return nil
end

-- =========================================================================
-- PUBLIC API & FOCUS MANAGEMENT
-- =========================================================================

function Tracker:SetFocus(questTitle)
    manualFocusQuest = questTitle
    self:Update()
end

function Tracker:GetFocus()
    return manualFocusQuest
end

function Tracker:GetActiveTarget()
    return currentActiveData
end

-- =========================================================================
-- LIVE REAL-TIME RADAR & ARROW UPDATE
-- =========================================================================

function Tracker:Update()
    if not PUIQuest.db or not PUIQuest.db:Get("enabled", true) or not PUIQuest.db:Get("showMinimapPins", true) then
        if hudArrow then hudArrow:Hide() end
        if minimapPin then minimapPin:Hide() end
        currentActiveData = nil
        return
    end

    -- Ensure map engine is synchronized with current player location
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        SetMapToCurrentZone()
    end

    local px, py = GetPlayerMapPosition("player")
    px = px or 0
    py = py or 0

    -- Estimate player facing if GetPlayerFacing is unavailable
    if px > 0 and py > 0 and (px ~= lastPlayerX or py ~= lastPlayerY) then
        local mdx = px - lastPlayerX
        local mdy = py - lastPlayerY
        if (mdx * mdx + mdy * mdy) > 0.000001 then
            estimatedFacing = math.atan2(mdx, -mdy)
        end
        lastPlayerX = px
        lastPlayerY = py
    end

    local playerZones, mapZone = GetPlayerZoneAliases()

    -- Find target: either manual focus, tracked list, or active quest log
    local resolvedTarget = nil

    if manualFocusQuest then
        resolvedTarget = ResolveQuestObjective(manualFocusQuest, playerZones, mapZone, px, py)
    else
        local trackedList = Primus.PUIQuestWatch and Primus.PUIQuestWatch.GetTrackedList and Primus.PUIQuestWatch:GetTrackedList() or {}
        local nearestLocalTarget = nil
        local nearestLocalDist = 999999
        local fallbackWorldTarget = nil
        local hasTracked = false

        for qTitle in pairs(trackedList) do
            hasTracked = true
            local cand = ResolveQuestObjective(qTitle, playerZones, mapZone, px, py)
            if cand then
                if not cand.isDifferentZone then
                    local cdx = cand.x - px
                    local cdy = cand.y - py
                    local cdist = cdx * cdx + cdy * cdy
                    if cdist < nearestLocalDist then
                        nearestLocalDist = cdist
                        nearestLocalTarget = cand
                    end
                elseif not fallbackWorldTarget then
                    fallbackWorldTarget = cand
                end
            end
        end

        -- Fallback: If no target found from tracked list, check all active Quest Log entries
        if not nearestLocalTarget and not fallbackWorldTarget then
            local numEntries = GetNumQuestLogEntries() or 0
            for i = 1, numEntries do
                local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
                if not isHeader and title then
                    local cand = ResolveQuestObjective(title, playerZones, mapZone, px, py, isComplete)
                    if cand then
                        if not cand.isDifferentZone then
                            local cdx = cand.x - px
                            local cdy = cand.y - py
                            local cdist = cdx * cdx + cdy * cdy
                            if cdist < nearestLocalDist then
                                nearestLocalDist = cdist
                                nearestLocalTarget = cand
                            end
                        elseif not fallbackWorldTarget then
                            fallbackWorldTarget = cand
                        end
                    end
                end
            end
        end

        resolvedTarget = nearestLocalTarget or fallbackWorldTarget
    end

    if not resolvedTarget then
        if hudArrow then hudArrow:Hide() end
        if minimapPin then minimapPin:Hide() end
        currentActiveData = nil
        return
    end

    -- 1. UPDATE 3D HUD NAVIGATION ARROW
    local arrow = CreateHUDArrow()
    arrow:Show()
    if hudModel then
        hudModel:Show()
        hudModel:SetModel("Interface\\Minimap\\ROTATING-MINIMAPARROW.mdx")
    end

    if resolvedTarget.isDifferentZone then
        resolvedTarget.yards = nil
        currentActiveData = resolvedTarget

        if hudModel then hudModel:SetFacing(0) end
        hudDistText:SetText(string.format("|cffffbb33In %s|r", resolvedTarget.zoneName or "Other Area"))
        hudTitleText:SetText(resolvedTarget.text or resolvedTarget.title or "Quest Objective")
        if minimapPin then minimapPin:Hide() end
        return
    end

    -- In-zone calculations
    local tx = resolvedTarget.x
    local ty = resolvedTarget.y
    local dx = tx - px
    local dy = ty - py
    local dist = math.sqrt(dx * dx + dy * dy)
    local yards = math.floor(dist * 1800)

    resolvedTarget.yards = yards
    currentActiveData = resolvedTarget

    -- Calculate Angles
    local targetAngle = math.atan2(dx, -dy)
    local playerFacing = (GetPlayerFacing and GetPlayerFacing()) or estimatedFacing or 0
    local diff = targetAngle - playerFacing

    if hudModel then
        hudModel:SetFacing(diff)
    end

    -- Dynamic Text & Coloring
    if yards < 15 or dist < 0.008 then
        hudDistText:SetText("|cff00ff00Arrived!|r")
    else
        local absAngle = math.abs(math.mod(diff + math.pi, 2 * math.pi) - math.pi)
        if absAngle < 0.35 then
            hudDistText:SetText(string.format("|cff00ff00%d yd|r", yards))
        elseif absAngle < 1.0 then
            hudDistText:SetText(string.format("|cffffd100%d yd|r", yards))
        else
            hudDistText:SetText(string.format("|cffff8822%d yd|r", yards))
        end
    end

    hudTitleText:SetText(resolvedTarget.text or resolvedTarget.title or "Quest Objective")

    -- 2. UPDATE MINIMAP RADAR PIN
    local mPin = CreateMinimapPin()
    mPin:Show()
    if minimapModel then
        minimapModel:Show()
        minimapModel:SetFacing(diff)
    end

    local radius = 54
    local mmDist = dist * 250
    if mmDist > radius then
        local nx = math.sin(diff) * radius
        local ny = math.cos(diff) * radius
        mPin:ClearAllPoints()
        mPin:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
    else
        local nx = math.sin(diff) * mmDist
        local ny = math.cos(diff) * mmDist
        mPin:ClearAllPoints()
        mPin:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
    end
end
