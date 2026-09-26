--[[
    PrimusUI Module: PUIQuest (Minimap Radar & 3D HUD Navigation Arrow)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Features:
    1. 3D HUD Navigation Arrow: Rotating MDX pointer model with real-time distance in yards.
    2. Dynamic Closest-Objective Auto-Targeting: Automatically guides to nearest tracked quest objective.
    3. Minimap Perimeter Radar: Edge-tracking radar blip pointing towards active objective.
    4. PUIMover Support: Move and anchor the HUD navigation arrow anywhere.
    5. Interactive Tooltips & Click Routing: 1-click open quest log or clear manual lock.
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
local hudFallback       = nil
local hudDistText       = nil
local hudTitleText      = nil
local minimapPin        = nil

local manualFocusQuest  = nil
local currentActiveData = nil -- { x = 0.5, y = 0.5, title = "...", text = "...", yards = 0 }
local lastPlayerX       = 0
local lastPlayerY       = 0
local estimatedFacing   = 0

-- =========================================================================
-- WIDGET CREATION (3D HUD ARROW & MINIMAP RADAR)
-- =========================================================================

local function CreateHUDArrow()
    if hudArrow then return hudArrow end

    hudArrow = CreateFrame("Button", "PUIQuestHUDArrow", UIParent)
    hudArrow:SetWidth(140)
    hudArrow:SetHeight(54)
    hudArrow:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    hudArrow:SetFrameStrata("MEDIUM")
    hudArrow:SetClampedToScreen(true)
    hudArrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 3D Model Pointer
    local model = CreateFrame("Model", "PUIQuestHUDArrowModel", hudArrow)
    model:SetWidth(44)
    model:SetHeight(44)
    model:SetPoint("TOP", hudArrow, "TOP", 0, 2)
    model:SetModel("Interface\\Minimap\\ROTATING-MINIMAPARROW.mdx")
    model:SetModelScale(0.85)
    model:SetPosition(0, 0, 0)
    hudModel = model

    -- 2D Fallback Texture
    local fallback = hudArrow:CreateTexture(nil, "ARTWORK")
    fallback:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    fallback:SetPoint("CENTER", model, "CENTER", 0, 0)
    fallback:SetWidth(26)
    fallback:SetHeight(26)
    fallback:Hide()
    hudFallback = fallback

    -- Distance FontString
    local dist = hudArrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dist:SetPoint("TOP", model, "BOTTOM", 0, 2)
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
    title:SetWidth(138)
    title:SetJustifyH("CENTER")
    hudTitleText = title

    -- Interactive Scripts
    hudArrow:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            -- Right click: Clear manual lock
            Tracker:SetFocus(nil)
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Reset to automatic closest-quest navigation.", "69ccf0"))
        else
            -- Left click: Open Quest Log to focused quest
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
        if currentActiveData.yards then
            GameTooltip:AddLine(string.format("Distance: |cffffffff%d yards|r", currentActiveData.yards), 0.7, 0.7, 0.7)
        end
        if currentActiveData.x and currentActiveData.y then
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
    minimapPin:SetWidth(24)
    minimapPin:SetHeight(24)
    minimapPin:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    minimapPin:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    local tex = minimapPin:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    tex:SetAllPoints(minimapPin)
    minimapPin.texture = tex

    minimapPin:SetScript("OnClick", function()
        if currentActiveData and currentActiveData.title then
            if not QuestLogFrame:IsVisible() then ShowUIPanel(QuestLogFrame) end
        end
    end)

    minimapPin:Hide()
    return minimapPin
end

-- =========================================================================
-- COORDINATE EXTRACTION & ZONE RESOLUTION
-- =========================================================================

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
                table.insert(results, { x = x / 100, y = y / 100, zoneID = zID })
            elseif zonesData and zonesData[zID] then
                local pID, w, h, ox, oy = unpack(zonesData[zID])
                local pName = zonesLoc[pID]
                if pName and (pName == currentZoneName or pID == currentZoneID) then
                    local px = (x * (w or 100) / 100) + (ox or 0)
                    local py = (y * (h or 100) / 100) + (oy or 0)
                    table.insert(results, { x = px / 100, y = py / 100, zoneID = pID })
                end
            end
        end
    end
    return results
end

-- Find the best/nearest objective coordinate for a given quest
local function ResolveQuestObjective(questTitle, currentZoneName, currentZoneID, playerX, playerY)
    if not questTitle or questTitle == "" then return nil end
    local q = PUIQuest.Database:FindQuest(questTitle)
    if not q or not q.data then return nil end

    local bestCoord = nil
    local bestDist = 999999
    local bestText = nil

    local function EvaluateCoords(coords, labelText)
        for _, coord in ipairs(coords) do
            local dx = coord.x - playerX
            local dy = coord.y - playerY
            local distSq = dx * dx + dy * dy
            if distSq < bestDist then
                bestDist = distSq
                bestCoord = coord
                bestText = labelText
            end
        end
    end

    -- 1. Check Turn-in NPC (if complete)
    local endUnits = q.data["end"] and q.data["end"]["U"]
    if endUnits then
        for _, uID in pairs(endUnits) do
            local unit = PUIQuest.Database:FindUnit(uID)
            if unit and unit.spawns then
                local coords = GetZoneCoords(unit.spawns, currentZoneName, currentZoneID)
                EvaluateCoords(coords, "Turn in: " .. unit.name)
            end
        end
    end

    -- 2. Check Unit Objectives
    local objUnits = q.data["obj"] and q.data["obj"]["U"]
    if objUnits then
        for _, uID in pairs(objUnits) do
            local unit = PUIQuest.Database:FindUnit(uID)
            if unit and unit.spawns then
                local coords = GetZoneCoords(unit.spawns, currentZoneName, currentZoneID)
                EvaluateCoords(coords, "Slay: " .. unit.name)
            end
        end
    end

    -- 3. Check Object Objectives
    local objObjects = q.data["obj"] and q.data["obj"]["O"]
    if objObjects then
        for _, oID in pairs(objObjects) do
            local obj = PUIQuest.Database:FindObject(oID)
            if obj and obj.spawns then
                local coords = GetZoneCoords(obj.spawns, currentZoneName, currentZoneID)
                EvaluateCoords(coords, "Interact: " .. obj.name)
            end
        end
    end

    -- 4. Check Item Drops
    local objItems = q.data["obj"] and q.data["obj"]["I"]
    if objItems then
        for _, iID in pairs(objItems) do
            local item = PUIQuest.Database:FindItem(iID)
            if item and item.data and item.data["U"] then
                for uID in pairs(item.data["U"]) do
                    local unit = PUIQuest.Database:FindUnit(uID)
                    if unit and unit.spawns then
                        local coords = GetZoneCoords(unit.spawns, currentZoneName, currentZoneID)
                        EvaluateCoords(coords, "Loot: " .. item.name)
                    end
                end
            end
        end
    end

    if bestCoord then
        return {
            x = bestCoord.x,
            y = bestCoord.y,
            title = questTitle,
            text = bestText or questTitle,
            zoneID = bestCoord.zoneID,
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

    -- Ensure map engine is synchronized with current zone when map isn't open
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then
        SetMapToCurrentZone()
    end

    local px, py = GetPlayerMapPosition("player")
    if not px or not py or (px == 0 and py == 0) then
        if hudArrow then hudArrow:Hide() end
        if minimapPin then minimapPin:Hide() end
        currentActiveData = nil
        return
    end

    -- Estimate player facing if GetPlayerFacing is unavailable
    if px ~= lastPlayerX or py ~= lastPlayerY then
        local mdx = px - lastPlayerX
        local mdy = py - lastPlayerY
        if (mdx * mdx + mdy * mdy) > 0.000001 then
            estimatedFacing = math.atan2(mdx, -mdy)
        end
        lastPlayerX = px
        lastPlayerY = py
    end

    local mapContinent = GetCurrentMapContinent()
    local mapZone = GetCurrentMapZone()
    local currentZoneName = nil
    if mapContinent > 0 and mapZone > 0 then
        local zoneNames = { GetMapZones(mapContinent) }
        currentZoneName = zoneNames[mapZone]
    end
    if not currentZoneName then
        currentZoneName = GetZoneText and GetZoneText() or ""
    end

    -- Find target: either manual focus or nearest tracked quest
    local resolvedTarget = nil

    if manualFocusQuest then
        resolvedTarget = ResolveQuestObjective(manualFocusQuest, currentZoneName, mapZone, px, py)
    else
        -- Auto-Target: Scan all tracked quests in PUIQuestWatch
        local trackedList = Primus.PUIQuestWatch and Primus.PUIQuestWatch.GetTrackedList and Primus.PUIQuestWatch:GetTrackedList() or {}
        local nearestTarget = nil
        local nearestDist = 999999

        for qTitle in pairs(trackedList) do
            local cand = ResolveQuestObjective(qTitle, currentZoneName, mapZone, px, py)
            if cand then
                local cdx = cand.x - px
                local cdy = cand.y - py
                local cdist = cdx * cdx + cdy * cdy
                if cdist < nearestDist then
                    nearestDist = cdist
                    nearestTarget = cand
                end
            end
        end

        resolvedTarget = nearestTarget
    end

    if not resolvedTarget then
        if hudArrow then hudArrow:Hide() end
        if minimapPin then minimapPin:Hide() end
        currentActiveData = nil
        return
    end

    -- Target Math & Distance
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

    -- 1. UPDATE 3D HUD NAVIGATION ARROW
    local arrow = CreateHUDArrow()
    arrow:Show()

    if hudModel then
        hudModel:SetFacing(diff)
    end

    -- Dynamic Text & Coloring
    if yards < 15 or dist < 0.008 then
        hudDistText:SetText("|cff00ff00Arrived!|r")
    else
        -- Proximity angle coloring
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
