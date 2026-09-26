--[[
    PrimusUI Module: PUIQuest (Minimap Radar & Rotating HUD Navigation Arrow)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides real-time distance calculations and a rotating navigation arrow
    pointing directly toward the active focused quest objective.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuest = Primus.PUIQuest or {}
Primus.PUIQuest = PUIQuest
_G.PUIQuest = PUIQuest

local Tracker = {}
PUIQuest.Tracker = Tracker

local Utils  = Primus.Utils
local Media  = Primus.Media
local Events = Primus.Events

-- State & Elements
local navArrow = nil
local activeFocusQuest = nil
local activeTargetCoord = nil -- { x = 0.5, y = 0.5, zone = 1 }

local function CreateNavArrow()
    if navArrow then return navArrow end

    navArrow = CreateFrame("Button", "PUIQuest_MinimapNavArrow", Minimap)
    navArrow:SetWidth(28)
    navArrow:SetHeight(28)
    navArrow:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    navArrow:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    local tex = navArrow:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
    tex:SetAllPoints(navArrow)
    navArrow.texture = tex

    navArrow:Hide()
    return navArrow
end

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

function Tracker:SetFocus(questTitle)
    activeFocusQuest = questTitle
    activeTargetCoord = nil

    if not questTitle then
        if navArrow then navArrow:Hide() end
        return
    end

    local q = PUIQuest.Database:FindQuest(questTitle)
    if not q or not q.data then
        if navArrow then navArrow:Hide() end
        return
    end

    -- Look up first valid objective or turn-in coordinate in current map zone
    local mapContinent = GetCurrentMapContinent()
    local mapZone = GetCurrentMapZone()
    local currentZoneName = nil
    if mapContinent > 0 and mapZone > 0 then
        local zoneNames = { GetMapZones(mapContinent) }
        currentZoneName = zoneNames[mapZone]
    end

    -- 1. Check Turn-in
    local endUnits = q.data["end"] and q.data["end"]["U"]
    if endUnits then
        for _, uID in pairs(endUnits) do
            local unit = PUIQuest.Database:FindUnit(uID)
            if unit and unit.spawns then
                local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                if coords[1] then
                    activeTargetCoord = coords[1]
                    break
                end
            end
        end
    end

    -- 2. Check Unit Objectives
    if not activeTargetCoord then
        local objUnits = q.data["obj"] and q.data["obj"]["U"]
        if objUnits then
            for _, uID in pairs(objUnits) do
                local unit = PUIQuest.Database:FindUnit(uID)
                if unit and unit.spawns then
                    local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                    if coords[1] then
                        activeTargetCoord = coords[1]
                        break
                    end
                end
            end
        end
    end

    -- 3. Check Object Objectives
    if not activeTargetCoord then
        local objObjects = q.data["obj"] and q.data["obj"]["O"]
        if objObjects then
            for _, oID in pairs(objObjects) do
                local obj = PUIQuest.Database:FindObject(oID)
                if obj and obj.spawns then
                    local coords = GetZoneCoords(obj.spawns, currentZoneName, mapZone)
                    if coords[1] then
                        activeTargetCoord = coords[1]
                        break
                    end
                end
            end
        end
    end

    -- 4. Check Item Drop Objectives
    if not activeTargetCoord then
        local objItems = q.data["obj"] and q.data["obj"]["I"]
        if objItems then
            for _, iID in pairs(objItems) do
                local item = PUIQuest.Database:FindItem(iID)
                if item and item.data and item.data["U"] then
                    for uID in pairs(item.data["U"]) do
                        local unit = PUIQuest.Database:FindUnit(uID)
                        if unit and unit.spawns then
                            local coords = GetZoneCoords(unit.spawns, currentZoneName, mapZone)
                            if coords[1] then
                                activeTargetCoord = coords[1]
                                break
                            end
                        end
                    end
                end
                if activeTargetCoord then break end
            end
        end
    end

    if activeTargetCoord then
        if not navArrow then CreateNavArrow() end
        navArrow:Show()
    else
        if navArrow then navArrow:Hide() end
    end
end

function Tracker:GetFocus()
    return activeFocusQuest
end

function Tracker:Update()
    if not activeFocusQuest or not activeTargetCoord then
        if navArrow then navArrow:Hide() end
        return
    end

    if not PUIQuest.db or not PUIQuest.db:Get("showMinimapPins", true) or not PUIQuest.db:Get("enabled", true) then
        if navArrow then navArrow:Hide() end
        return
    end

    local px, py = GetPlayerMapPosition("player")
    if not px or not py or (px == 0 and py == 0) then
        if navArrow then navArrow:Hide() end
        return
    end

    local tx = activeTargetCoord.x
    local ty = activeTargetCoord.y
    local dx = tx - px
    local dy = ty - py
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.005 then
        -- Arrived at objective
        if navArrow then navArrow:Hide() end
        return
    end

    if not navArrow then CreateNavArrow() end
    navArrow:Show()

    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local angle = math.atan2(-dx, dy) - facing
    local radius = 54
    local nx = math.sin(angle) * radius
    local ny = math.cos(angle) * radius

    navArrow:ClearAllPoints()
    navArrow:SetPoint("CENTER", Minimap, "CENTER", nx, ny)
end
