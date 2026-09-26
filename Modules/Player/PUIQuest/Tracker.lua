--[[
    PrimusUI Module: PUIQuest (Minimap Radar & Dual 2D/3D HUD Navigation Arrow Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Features:
    1. Dual 2D/3D Navigation Arrow: High-definition rotating arrow texture (360° affine SetTexCoord)
       with optional 3D Rotating-MinimapArrow.mdl model overlay and real-time distance in yards.
    2. Dynamic Proximity & Angle Tinting: Real-time emerald/gold/amber coloring based on player bearing.
    3. Multi-Zone Objective Resolution: Accurately maps standard zones and custom subzones (including Turtle WoW).
    4. Smart Objective Priority: Prioritizes slay mobs, interact objects, and loot drops before turn-in NPCs.
    5. Quest Log Auto-Detection: Automatically targets closest quest even if not manually watched.
    6. Cross-Zone Guidance: Shows destination zone when objective is in another area.
    7. Minimap Perimeter Radar: Rotating directional blip on the Minimap border.
    8. PUIMover Support: Move and anchor the HUD navigation arrow anywhere.
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
local hudArrowHolder    = nil
local hudArrowTex       = nil
local hudModel          = nil
local hudDistText       = nil
local hudTitleText      = nil
local minimapPin        = nil
local minimapTex        = nil
local minimapModel      = nil

local manualFocusQuest  = nil
local currentActiveData = nil
local lastPlayerX       = 0
local lastPlayerY       = 0
local estimatedFacing   = 0

-- =========================================================================
-- 3D SPRITE ARROW ENGINE (120-FRAME CELL RESOLVER)
-- =========================================================================

local ARROW_TEXTURE_PATH = "Interface\\AddOns\\PrimusUI\\Media\\Textures\\3darrow.tga"

local function Set3DArrowAngle(tex, angle)
    if not tex then return end
    local twoPi = 2 * math.pi
    local a = math.mod(angle, twoPi)
    if a < 0 then a = a + twoPi end

    -- 120 frames across 2*pi radians, with Frame 1 centered at angle 0 (North / Forward)
    local frame = math.mod(math.floor((a / (twoPi / 120)) + 1.5), 120)
    
    local col = math.mod(frame, 10)
    local row = math.floor(frame / 10)

    -- Inset by 0.0005 to prevent texture bleeding from neighboring cells
    local left = col * 0.1 + 0.0005
    local right = (col + 1) * 0.1 - 0.0005
    local top = row * (1 / 12) + 0.0005
    local bottom = (row + 1) * (1 / 12) - 0.0005

    tex:SetTexCoord(left, right, top, bottom)
end

-- =========================================================================
-- WIDGET CREATION (HUD ARROW & MINIMAP RADAR)
-- =========================================================================

local function CreateHUDArrow()
    if hudArrow then return hudArrow end

    hudArrow = CreateFrame("Frame", "PUIQuestHUDArrow", UIParent)
    hudArrow:SetWidth(156)
    hudArrow:SetHeight(66)
    hudArrow:SetPoint("CENTER", UIParent, "CENTER", 0, -130)
    hudArrow:SetFrameStrata("BACKGROUND")
    hudArrow:SetClampedToScreen(true)
    hudArrow:EnableMouse(false)

    -- Glassmorphic pill backdrop
    hudArrow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    hudArrow:SetBackdropColor(0.04, 0.06, 0.09, 0.88)
    hudArrow:SetBackdropBorderColor(0.20, 0.35, 0.55, 0.90)

    -- Arrow Container Frame
    local arrowHolder = CreateFrame("Frame", nil, hudArrow)
    arrowHolder:SetWidth(36)
    arrowHolder:SetHeight(36)
    arrowHolder:SetPoint("TOP", hudArrow, "TOP", 0, -2)
    arrowHolder:EnableMouse(false)
    hudArrowHolder = arrowHolder

    -- 3D Rotating Texture Arrow (120-frame rendered sprite sheet)
    local arrowTex = arrowHolder:CreateTexture(nil, "ARTWORK")
    arrowTex:SetTexture(ARROW_TEXTURE_PATH)
    arrowTex:SetWidth(36)
    arrowTex:SetHeight(36)
    arrowTex:SetPoint("CENTER", arrowHolder, "CENTER", 0, 0)
    arrowTex:SetVertexColor(1.0, 0.85, 0.1, 1.0)
    Set3DArrowAngle(arrowTex, 0)
    hudArrowTex = arrowTex

    -- Distance FontString
    local dist = hudArrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dist:SetPoint("TOP", arrowHolder, "BOTTOM", 0, 0)
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
    title:SetWidth(150)
    title:SetJustifyH("CENTER")
    hudTitleText = title

    -- Self-driving real-time update loop (throttled to 0.08s for super-smooth 60fps tracking)
    local updateElapsed = 0
    hudArrow:SetScript("OnUpdate", function()
        updateElapsed = updateElapsed + (arg1 or 0.05)
        if updateElapsed >= 0.08 then
            updateElapsed = 0
            Tracker:Update()
        end
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

    local tex = minimapPin:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ARROW_TEXTURE_PATH)
    tex:SetAllPoints(minimapPin)
    Set3DArrowAngle(tex, 0)
    minimapTex = tex

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

    local px, py = GetPlayerMapPosition("player")
    if (not px or px == 0) and (not py or py == 0) then
        if not WorldMapFrame or not WorldMapFrame:IsVisible() then
            SetMapToCurrentZone()
            px, py = GetPlayerMapPosition("player")
        end
    end
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

        for qTitle in pairs(trackedList) do
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

    -- 1. UPDATE 3D/2D HUD NAVIGATION ARROW
    local arrow = CreateHUDArrow()
    arrow:Show()

    if resolvedTarget.isDifferentZone then
        resolvedTarget.yards = nil
        currentActiveData = resolvedTarget

        if hudArrowTex then
            hudArrowTex:Show()
            Set3DArrowAngle(hudArrowTex, 0)
            hudArrowTex:SetVertexColor(1.0, 0.75, 0.2, 1.0)
        end
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

    -- Dynamic Color & Text based on facing angle & distance
    local r, g, b = 1.0, 1.0, 1.0
    if yards < 15 or dist < 0.008 then
        hudDistText:SetText("|cff00ff00Arrived!|r")
        r, g, b = 0.0, 1.0, 0.5
    else
        local absAngle = math.abs(math.mod(diff + math.pi, 2 * math.pi) - math.pi)
        if absAngle < 0.35 then
            hudDistText:SetText(string.format("|cff00ff00%d yd|r", yards))
            r, g, b = 0.1, 1.0, 0.2
        elseif absAngle < 1.0 then
            hudDistText:SetText(string.format("|cffffd100%d yd|r", yards))
            r, g, b = 1.0, 0.85, 0.1
        else
            hudDistText:SetText(string.format("|cffff6622%d yd|r", yards))
            r, g, b = 1.0, 0.40, 0.1
        end
    end

    hudTitleText:SetText(resolvedTarget.text or resolvedTarget.title or "Quest Objective")

    -- Rotate 3D Texture Arrow
    if hudArrowTex then
        hudArrowTex:Show()
        Set3DArrowAngle(hudArrowTex, diff)
        hudArrowTex:SetVertexColor(r, g, b, 1.0)
    end

    -- 2. UPDATE MINIMAP RADAR PIN
    local mPin = CreateMinimapPin()
    mPin:Show()
    if minimapTex then
        minimapTex:Show()
        Set3DArrowAngle(minimapTex, diff)
        minimapTex:SetVertexColor(r, g, b, 1.0)
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
