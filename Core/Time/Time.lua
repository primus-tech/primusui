--[[
    PrimusLib: Centralized Time & Ticker Engine
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides high-performance, single-frame OnUpdate timer management,
    delays, intervals, throttles, and debounces with zero-garbage node pooling.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local Time   = Primus.Time
local Memory = Primus.Memory
local Debug  = Primus.Debug
local Utils  = Primus.Utils

-- Active Timers list and ID counter
local activeTimers = {}
local activeCount  = 0
local timerIDCounter = 0

-- Keyed throttles and debounces
local throttles = {}
local debounces = {}

-- Central Driver Frame
local tickerFrame = CreateFrame("Frame", "Primus_TickerFrame")
tickerFrame:Hide()

local function Ticker_OnUpdate()
    local elapsed = arg1
    if not elapsed or elapsed <= 0 then return end

    local i = 1
    while i <= activeCount do
        local timer = activeTimers[i]
        if timer then
            timer.remaining = timer.remaining - elapsed
            if timer.remaining <= 0 then
                -- Execute timer callback safely
                if timer.callback then
                    Debug:SafeCall(timer.callback, timer.arg)
                end

                if timer.repeating and not timer.cancelled then
                    timer.remaining = timer.interval
                    i = i + 1
                else
                    -- Remove one-shot or cancelled timer
                    table.remove(activeTimers, i)
                    activeCount = activeCount - 1
                    Memory:ReleaseTable(timer)
                end
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    if activeCount == 0 then
        tickerFrame:Hide()
    end
end

tickerFrame:SetScript("OnUpdate", Ticker_OnUpdate)

local function EnsureTickerRunning()
    if activeCount > 0 and not tickerFrame:IsShown() then
        tickerFrame:Show()
    end
end

-- Schedule a one-shot delay (like C_Timer.After)
function Time:After(delaySeconds, callback, callbackArg, owner)
    if not callback or type(callback) ~= "function" then return nil end
    delaySeconds = math.max(0, delaySeconds or 0)

    timerIDCounter = timerIDCounter + 1
    local node = Memory:AcquireTable()
    node.id = timerIDCounter
    node.remaining = delaySeconds
    node.interval = delaySeconds
    node.callback = callback
    node.arg = callbackArg
    node.owner = owner
    node.repeating = false
    node.cancelled = false

    activeCount = activeCount + 1
    activeTimers[activeCount] = node

    EnsureTickerRunning()
    return node.id
end

-- Schedule a repeating interval (like C_Timer.NewTicker)
function Time:Every(intervalSeconds, callback, callbackArg, owner)
    if not callback or type(callback) ~= "function" then return nil end
    intervalSeconds = math.max(0.01, intervalSeconds or 1)

    timerIDCounter = timerIDCounter + 1
    local node = Memory:AcquireTable()
    node.id = timerIDCounter
    node.remaining = intervalSeconds
    node.interval = intervalSeconds
    node.callback = callback
    node.arg = callbackArg
    node.owner = owner
    node.repeating = true
    node.cancelled = false

    activeCount = activeCount + 1
    activeTimers[activeCount] = node

    EnsureTickerRunning()
    return node.id
end

-- Cancel a timer by ID or node reference
function Time:Cancel(timerId)
    if not timerId then return end
    for i = 1, activeCount do
        local timer = activeTimers[i]
        if timer and (timer.id == timerId or timer == timerId) then
            timer.cancelled = true
            timer.repeating = false
            timer.remaining = 0
            return true
        end
    end
    return false
end

-- Cancel all timers associated with an owner (e.g. on module disable)
function Time:CancelAll(owner)
    if not owner then return false end
    local cancelledAny = false
    for i = 1, activeCount do
        local timer = activeTimers[i]
        if timer and timer.owner == owner then
            timer.cancelled = true
            timer.repeating = false
            timer.remaining = 0
            cancelledAny = true
        end
    end
    return cancelledAny
end

-- Throttle: Only executes callback once every `delaySeconds` for a given key
function Time:Throttle(key, delaySeconds, callback, callbackArg)
    if not key or not callback then return false end
    local now = GetTime()
    local lastRun = throttles[key] or 0

    if (now - lastRun) >= delaySeconds then
        throttles[key] = now
        Debug:SafeCall(callback, callbackArg)
        return true
    end
    return false
end

-- Debounce: Delays execution until `delaySeconds` have passed without new calls
function Time:Debounce(key, delaySeconds, callback, callbackArg)
    if not key or not callback then return end

    if debounces[key] then
        self:Cancel(debounces[key])
    end

    local timerId = self:After(delaySeconds, function()
        debounces[key] = nil
        Debug:SafeCall(callback, callbackArg)
    end)

    debounces[key] = timerId
end

-- Format seconds into clean shorthand text (e.g. 45s, 3m 20s, 1h 15m, 2d)
function Time:FormatShort(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "0s" end
    if seconds < 60 then
        return string.format("%ds", math.ceil(seconds))
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = math.floor(Utils.Mod(seconds, 60))
        if s > 0 then
            return string.format("%dm %ds", m, s)
        else
            return string.format("%dm", m)
        end
    elseif seconds < 86400 then
        local h = math.floor(seconds / 3600)
        local m = math.floor(Utils.Mod(seconds, 3600) / 60)
        if m > 0 then
            return string.format("%dh %dm", h, m)
        else
            return string.format("%dh", h)
        end
    else
        local d = math.floor(seconds / 86400)
        return string.format("%dd", d)
    end
end
Time.FormatShort = function(selfOrSec, maybeSec)
    local s = (type(selfOrSec) == "table" and maybeSec) or selfOrSec
    return Time:FormatShort(s)
end

-- Get server / system epoch timestamp
function Time:GetServerTimestamp()
    return (time and time()) or math.floor(GetTime())
end
Time.GetServerTimestamp = function(self)
    return Time:GetServerTimestamp()
end

