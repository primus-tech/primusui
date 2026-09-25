--[[
    PrimusUI: Contextual State Machine & Combat Focus Engine ("Combat Zen")
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides intelligent state-driven interface focus transitions:
    - Smoothly fades non-essential peripheral clutter during combat.
    - Strictly enforces the Action Bar Permanence Rule (rotational ability bars never hide).
    - Supports Hover-to-Peek for instant 3.0s temporary reveal of faded elements.
    - Seamlessly integrates with Primus.Anim easing engine.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local State   = Primus.State
local DB      = Primus.DB
local Events  = Primus.Events
local Anim    = Primus.Anim
local Time    = Primus.Time
local Utils   = Primus.Utils
local Console = Primus.Console

-- Persistent State Database
local stateDB = DB:RegisterNamespace("Zen", {
    enabled            = true,
    fadeMinimap        = true,
    fadeQuestTracker   = true,
    fadeCornerFrames   = false,
    fadeMicroMenu      = true,
    fadeBagBar         = true,
    fadeChat           = true,
    combatAlpha        = 0.0,
    idleAlpha          = 1.0,
    fadeDuration       = 0.25,
    peekDuration       = 3.0,
})

local inCombat = false
local peekTimers = {}
local hookedFrames = {}

-- Retrieve target elements to manage
local function GetManagedFrames()
    local frames = {}

    -- 1. Minimap & Zone Header
    if stateDB:Get("fadeMinimap", true) then
        if MinimapCluster then table.insert(frames, { frame = MinimapCluster, key = "Minimap" })
        elseif Minimap then table.insert(frames, { frame = Minimap, key = "Minimap" }) end
    end

    -- 2. Quest Objective Tracker
    if stateDB:Get("fadeQuestTracker", true) then
        if QuestWatchFrame then table.insert(frames, { frame = QuestWatchFrame, key = "QuestWatch" }) end
    end

    -- 3. Micro Menu Bar (PUIHotbars)
    if stateDB:Get("fadeMicroMenu", true) then
        local microBar = _G["Primus_PUIHotbars_MicroBar"]
        if microBar and microBar:IsShown() then
            table.insert(frames, { frame = microBar, key = "MicroMenu" })
        end
    end

    -- 4. Bag Bar (PUIHotbars)
    if stateDB:Get("fadeBagBar", true) then
        local bagBar = _G["Primus_PUIHotbars_BagBar"]
        if bagBar and bagBar:IsShown() then
            table.insert(frames, { frame = bagBar, key = "BagBar" })
        end
    end

    -- 5. Chat Frames Inactive Dimming
    if stateDB:Get("fadeChat", true) then
        if ChatFrame1 and ChatFrame1:IsShown() then
            table.insert(frames, { frame = ChatFrame1, key = "Chat1" })
        end
    end

    -- 6. Corner Legacy Frames (Optional)
    if stateDB:Get("fadeCornerFrames", false) then
        if PlayerFrame and PlayerFrame:IsShown() then table.insert(frames, { frame = PlayerFrame, key = "PlayerFrame" }) end
        if TargetFrame and TargetFrame:IsShown() then table.insert(frames, { frame = TargetFrame, key = "TargetFrame" }) end
    end

    return frames
end

-- Peek / Wake Up a Faded Frame temporarily
function State:PeekFrame(frame, key)
    if not frame then return end
    key = key or tostring(frame)

    -- Cancel existing peek timer
    if peekTimers[key] then
        peekTimers[key] = nil
    end

    -- Fade in smoothly
    Anim:Fade(frame, 0.15, frame:GetAlpha() or 0, 1.0)

    -- Schedule fade out if still in combat
    peekTimers[key] = GetTime() + stateDB:Get("peekDuration", 3.0)
end

-- Hook Hover-to-Peek mouseover handlers
local function HookHoverToPeek(fEntry)
    local frame = fEntry.frame
    local key = fEntry.key
    if not frame or hookedFrames[key] then return end
    hookedFrames[key] = true

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end

    local origEnter = frame:GetScript("OnEnter")
    frame:SetScript("OnEnter", function()
        if origEnter then origEnter() end
        if inCombat and stateDB:Get("enabled", true) then
            State:PeekFrame(frame, key)
        end
    end)
end

-- Apply State Transition (Combat vs Out of Combat)
function State:ApplyState(force)
    if not stateDB:Get("enabled", true) and not force then return end

    local targetAlpha = inCombat and stateDB:Get("combatAlpha", 0.0) or stateDB:Get("idleAlpha", 1.0)
    local duration = stateDB:Get("fadeDuration", 0.25)
    local managed = GetManagedFrames()
    local count = table.getn(managed)

    for i = 1, count do
        local entry = managed[i]
        local f = entry.frame
        if f then
            HookHoverToPeek(entry)
            local curAlpha = f:GetAlpha() or 1.0
            if math.abs(curAlpha - targetAlpha) > 0.05 then
                Anim:Fade(f, duration, curAlpha, targetAlpha)
            end
        end
    end
end

-- Enter Combat
function State:OnEnterCombat()
    inCombat = true
    self:ApplyState()
end

-- Exit Combat
function State:OnExitCombat()
    inCombat = false
    self:ApplyState()
end

-- Ticker for Peek Expirations & Mouse Proximity (0.1s)
local function PeekTicker()
    if not inCombat or not stateDB:Get("enabled", true) then return end

    local now = GetTime()
    local duration = stateDB:Get("fadeDuration", 0.25)
    local combatAlpha = stateDB:Get("combatAlpha", 0.0)

    for key, expireTime in pairs(peekTimers) do
        if now >= expireTime then
            peekTimers[key] = nil
            local managed = GetManagedFrames()
            local count = table.getn(managed)
            for i = 1, count do
                if managed[i].key == key and managed[i].frame then
                    local f = managed[i].frame
                    Anim:Fade(f, duration, f:GetAlpha() or 1.0, combatAlpha)
                end
            end
        end
    end
end

-- =========================================================================
-- INITIALIZATION
-- =========================================================================

function State:OnInitialize()
    Events:Register("PLAYER_REGEN_DISABLED", self, function()
        State:OnEnterCombat()
    end)

    Events:Register("PLAYER_REGEN_ENABLED", self, function()
        State:OnExitCombat()
    end)

    Events:Register("PLAYER_ENTERING_WORLD", self, function()
        inCombat = UnitAffectingCombat("player") and true or false
        State:ApplyState(true)
    end)

    -- Periodic Peek Monitor
    Time:Every(0.1, PeekTicker)

    -- Register Subcommand under Master Console
    if Console and Console.RegisterSubCommand then
        Console:RegisterSubCommand("zen", function(argParam)
            argParam = Utils.Trim(argParam or "")
            if argParam == "toggle" then
                local cur = stateDB:Get("enabled", true)
                stateDB:Set("enabled", not cur)
                State:ApplyState(true)
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[Zen]: State Focus is now " .. (not cur and "ENABLED" or "DISABLED"), "69ccf0"))
            else
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("=== PrimusUI Zen Engine ===", "69ccf0"))
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("Status: ", "ffbb33") .. (stateDB:Get("enabled", true) and "|cff33ff33ACTIVE|r" or "|cffff4444DISABLED|r"))
                DEFAULT_CHAT_FRAME:AddMessage("Automatically strips peripheral clutter during combat while preserving rotational action bars.")
                DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("Commands: /pui zen toggle", "ffd100"))
            end
        end, "Zen Focus Engine (/pui zen [toggle])")

        
    end
end

-- Self-register module lifecycle
Primus:RegisterModule("Zen", State, "Core")
