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

    -- Look up first valid objective or turn-in coordinate
    local mapZone = GetCurrentMapZone()
    local endUnits = q.data["end"] and q.data["end"]["U"]
    if endUnits then
        for _, uID in pairs(endUnits) do
            local unit = PUIQuest.Database:FindUnit(uID)
            if unit and unit.spawns and unit.spawns[mapZone] then
                local first = unit.spawns[mapZone][1]
                if first then
                    activeTargetCoord = { x = first[1] / 100, y = first[2] / 100, zone = mapZone }
                    break
                end
            end
        end
    end

    if not activeTargetCoord then
        local objUnits = q.data["obj"] and q.data["obj"]["U"]
        if objUnits then
            for _, uID in pairs(objUnits) do
                local unit = PUIQuest.Database:FindUnit(uID)
                if unit and unit.spawns and unit.spawns[mapZone] then
                    local first = unit.spawns[mapZone][1]
                    if first then
                        activeTargetCoord = { x = first[1] / 100, y = first[2] / 100, zone = mapZone }
                        break
                    end
                end
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
