--[[
    PrimusUI: PUIRoleplay Comms Engine (PUIComms.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (100% TurtleRP Wire Protocol Compatibility)
--]]

local Primus = _G.Primus
local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Comms = {}
PUIRoleplay.Comms = Comms

local channelName = "TTRP"
local minChatLevel = 10
local timeBetweenPings = 30

-- Throttling & Deduplication State
local lastRequestTimes = {}  -- [playerName .. "_" .. requestType] = timestamp
local lastDataSentTime = {}  -- [dataPrefix] = timestamp
local globalLastSendTime = 0
local lastPingSentTime = 0

-- Wire protocol data keys matching TurtleRP 1-to-1
local dataKeys = {
    ["M"] = { "keyM", "icon", "full_name", "race", "class", "class_color", "ooc_info", "ic_info", "currently_ic", "ooc_pronouns", "ic_pronouns", "nsfw" },
    ["T"] = { "keyT", "atAGlance1", "atAGlance1Title", "atAGlance1Icon", "atAGlance2", "atAGlance2Title", "atAGlance2Icon", "atAGlance3", "atAGlance3Title", "atAGlance3Icon", "experience", "walkups", "injury", "romance", "death" },
    ["D"] = { "keyD", "description" }
}
dataKeys["MR"] = dataKeys["M"]
dataKeys["TR"] = dataKeys["T"]
dataKeys["DR"] = dataKeys["D"]

--------------------------------------------------------------------------------
-- Drunk Codec (Protects Wire Packets from Slurred Speech)
--------------------------------------------------------------------------------
local DrunkSuffix = string.gsub(SLURRED_SPEECH or "...hic!", "%%s(.+)", "%1$")

function Comms:DrunkEncode(text)
    if not text then return "" end
    text = string.gsub(text, "s", "°")
    text = string.gsub(text, "S", "§")
    return text
end

function Comms:DrunkDecode(text)
    if not text then return "" end
    text = string.gsub(text, "°", "s")
    text = string.gsub(text, "§", "S")
    text = string.gsub(text, DrunkSuffix, "")
    return text
end

--------------------------------------------------------------------------------
-- Channel Sending via ChatThrottleLib or Native Fallback
--------------------------------------------------------------------------------
function Comms:CanChat()
    local chanNumber = GetChannelName(channelName)
    if chanNumber and chanNumber > 0 then
        return true
    end
    local chanNumberLower = GetChannelName(string.lower(channelName))
    if chanNumberLower and chanNumberLower > 0 then
        return true
    end
    local chanList = { GetChannelList() }
    for i = 1, table.getn(chanList), 2 do
        if string.lower(tostring(chanList[i+1] or "")) == string.lower(channelName) then
            return true
        end
    end
    return false
end

function Comms:SendChannelMessage(message, priority)
    local chanNumber = GetChannelName(channelName)
    if not chanNumber or chanNumber == 0 then
        chanNumber = GetChannelName(string.lower(channelName))
    end
    if not chanNumber or chanNumber == 0 then
        local chanList = { GetChannelList() }
        for i = 1, table.getn(chanList), 2 do
            if string.lower(tostring(chanList[i+1] or "")) == string.lower(channelName) then
                chanNumber = tonumber(chanList[i])
                break
            end
        end
    end

    if not chanNumber or chanNumber == 0 then return end

    local encoded = self:DrunkEncode(message)
    local prio = priority or "BULK"
    if _G.ChatThrottleLib then
        _G.ChatThrottleLib:SendChatMessage(prio, channelName, encoded, "CHANNEL", nil, chanNumber)
    else
        SendChatMessage(encoded, "CHANNEL", nil, chanNumber)
    end
end

--------------------------------------------------------------------------------
-- Channel Handshake & Join
--------------------------------------------------------------------------------
function Comms:JoinRPChannel()
    local chanList = { GetChannelList() }
    local found = false
    if chanList and table.getn(chanList) > 0 then
        for i = 1, table.getn(chanList), 2 do
            local chName = tostring(chanList[i+1] or "")
            if string.lower(chName) == string.lower(channelName) then
                found = true
                break
            end
        end
    end
    if not found then
        JoinChannelByName(channelName)
    end
    
    -- Send initial announcement pings spaced safely
    Primus.Time:After(3.0, function()
        Comms:SendPing("A")
    end, PUIRoleplay)
end

--------------------------------------------------------------------------------
-- Presence Pings (P & A)
--------------------------------------------------------------------------------
function Comms:SendPing(pingType)
    if not self:CanChat() then return end
    
    local curTime = time()
    -- If TurtleRP is running its own ping loop, don't duplicate periodic pings
    if _G.TurtleRP and _G.TurtleRP.canChat and _G.TurtleRP.canChat() and pingType == "P" then
        return
    end

    -- Throttle ping broadcasts to minimum 15s interval
    if (curTime - lastPingSentTime) < 15 and pingType == "P" then
        return
    end
    lastPingSentTime = curTime

    local pType = pingType or "P"
    local zoneText = GetZoneText() or ""
    local msg = pType .. zoneText
    
    local settings = PUIRoleplay:GetSettings() or {}
    if settings and (settings.share_location == "1" or settings.share_location == 1 or settings.share_location == true) then
        local x, y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then
            local posX = math.floor(x * 10000) / 10000
            local posY = math.floor(y * 10000) / 10000
            msg = msg .. "~" .. posX .. "~" .. posY .. "~1.1.0"
        else
            msg = msg .. "~false~false~1.1.0"
        end
    else
        msg = msg .. "~false~false~1.1.0"
    end
    
    self:SendChannelMessage(msg, "NORMAL")
end

function Comms:StartPingTicker()
    Primus.Time:Every(timeBetweenPings, function()
        Comms:SendPing("P")
    end, PUIRoleplay)
end

--------------------------------------------------------------------------------
-- Helper String Splitting (Safe for Lua 5.0.2)
--------------------------------------------------------------------------------
local function SplitString(str, delimiter, targetTable)
    local result = targetTable or {}
    for k in pairs(result) do result[k] = nil end
    if not str or str == "" then return result end
    
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from, true)
    local i = 1
    while delim_from do
        result[i] = string.sub(str, from, delim_from - 1)
        i = i + 1
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from, true)
    end
    result[i] = string.sub(str, from)
    table.setn(result, i)
    return result
end

--------------------------------------------------------------------------------
-- Request Dispatcher (M, T, D) with Anti-Flood Deduplication
--------------------------------------------------------------------------------
function Comms:SendRequest(requestType, playerName)
    if not self:CanChat() or not playerName or playerName == "" or playerName == UnitName("player") then
        return
    end
    
    local curTime = time()
    -- Global throttle: minimum 1.5s between ANY request sent to the channel
    if (curTime - globalLastSendTime) < 1.5 then
        return
    end
    
    -- Per-player per-request-type cooldown: 45 seconds
    local reqKey = playerName .. "_" .. requestType
    if lastRequestTimes[reqKey] and (curTime - lastRequestTimes[reqKey]) < 45 then
        return
    end
    
    lastRequestTimes[reqKey] = curTime
    globalLastSendTime = curTime
    
    local charInfo = PUIRoleplay:GetCharacterData(playerName)
    local key = charInfo and charInfo["key" .. requestType]
    if key and key ~= "" then
        self:SendChannelMessage(requestType .. ":" .. playerName .. "~" .. key, "BULK")
    else
        self:SendChannelMessage(requestType .. ":" .. playerName .. "~NO_KEY", "BULK")
    end
end

--------------------------------------------------------------------------------
-- Build Outbound Payload for Local Character
--------------------------------------------------------------------------------
function Comms:BuildPayload(dataPrefix)
    local keys = dataKeys[dataPrefix]
    if not keys then return "" end
    
    local myInfo = PUIRoleplay:GetMyProfile()
    local parts = {}
    for i, dataRef in ipairs(keys) do
        if i ~= 1 then -- skip key as it is sent in packet header
            local val = myInfo[dataRef] or ""
            if dataRef == "description" then
                val = string.gsub(val, "\n", "@N")
                if val == "" then val = " " end
            end
            table.insert(parts, tostring(val))
        end
    end
    
    local payload = ""
    for i, v in ipairs(parts) do
        if i == 1 then
            payload = v
        else
            payload = payload .. "~" .. v
        end
    end
    return payload
end

--------------------------------------------------------------------------------
-- Chunking Outbound Data (>200 chars)
--------------------------------------------------------------------------------
function Comms:SendData(dataPrefix)
    local curTime = time()
    -- Throttle outbound responses: don't broadcast the same data type more than once every 4 seconds
    if lastDataSentTime[dataPrefix] and (curTime - lastDataSentTime[dataPrefix]) < 4 then
        return
    end
    lastDataSentTime[dataPrefix] = curTime

    local payload = self:BuildPayload(dataPrefix)
    local myInfo = PUIRoleplay:GetMyProfile()
    local myKey = myInfo["key" .. dataPrefix] or "PUI10"
    
    local splitLength = 200
    local totalLen = string.len(payload)
    local numChunks = math.ceil(totalLen / splitLength)
    if numChunks == 0 then numChunks = 1 end
    
    local chunks = {}
    for i = 1, numChunks do
        local startIdx = (i - 1) * splitLength + 1
        local endIdx = i * splitLength
        if endIdx > totalLen then endIdx = totalLen end
        chunks[i] = string.sub(payload, startIdx, endIdx)
    end
    
    local totalChunks = table.getn(chunks)
    for i = 1, totalChunks do
        local packet = dataPrefix .. "R:p~" .. myKey .. "~" .. i .. "~" .. totalChunks .. "~" .. chunks[i]
        self:SendChannelMessage(packet, "BULK")
    end
end

--------------------------------------------------------------------------------
-- Inbound Packet Parsing & Reassembly
--------------------------------------------------------------------------------
local msgSplitTable = {}
local pingSplitTable = {}

function Comms:OnChatMessage(msg, sender)
    if not msg or not sender or sender == "" then return end
    
    local decoded = self:DrunkDecode(msg)
    local colonStart = string.find(decoded, ":")
    
    if colonStart then
        local dataPrefix = string.sub(decoded, 1, colonStart - 1)
        local tildeStart = string.find(decoded, "~", colonStart)
        
        if tildeStart then
            local targetName = string.sub(decoded, colonStart + 1, tildeStart - 1)
            
            -- Query addressed to me?
            if targetName == UnitName("player") then
                if self:CanChat() and (dataPrefix == "M" or dataPrefix == "T" or dataPrefix == "D") then
                    local myInfo = PUIRoleplay:GetMyProfile()
                    local keyFromMsg = string.sub(decoded, tildeStart + 1)
                    local myKey = myInfo["key" .. dataPrefix]
                    
                    if keyFromMsg == "NO_KEY" or keyFromMsg ~= myKey then
                        self:SendData(dataPrefix)
                    end
                end
            elseif (targetName == "p" or string.sub(dataPrefix, -1) == "R") and (dataPrefix == "MR" or dataPrefix == "TR" or dataPrefix == "DR") then
                -- Response packet (MR, TR, DR)
                self:ProcessResponse(dataPrefix, sender, decoded)
            end
        end
    else
        -- Presence Pings (P or A)
        local firstChar = string.sub(decoded, 1, 1)
        if firstChar == "P" or firstChar == "A" then
            self:ProcessPing(sender, decoded)
        end
    end
end

function Comms:ProcessResponse(dataPrefix, sender, msg)
    local tildePos = string.find(msg, "~")
    if not tildePos then return end
    
    local dataSlice = string.sub(msg, tildePos)
    local parts = SplitString(dataSlice, "~", msgSplitTable)
    -- parts: [1]="" (before first ~), [2]=key, [3]=chunkIndex, [4]=totalChunks, [5..N]=payload
    
    local key = parts[2]
    local chunkIdx = tonumber(parts[3])
    local totalChunks = tonumber(parts[4])
    
    if not key or key == "" or not chunkIdx or not totalChunks then
        return
    end
    
    local charData = PUIRoleplay:GetOrCreateCharacterData(sender)
    if not charData["temp" .. dataPrefix] or chunkIdx == 1 then
        charData["temp" .. dataPrefix] = key .. "~"
    end
    
    local totalParts = table.getn(parts)
    local chunkPayload = ""
    for i = 5, totalParts do
        chunkPayload = chunkPayload .. (parts[i] or "") .. (i == totalParts and "" or "~")
    end
    charData["temp" .. dataPrefix] = (charData["temp" .. dataPrefix] or "") .. chunkPayload
    
    -- When all chunks received, parse and store into character record
    if chunkIdx == totalChunks then
        local rawJoined = charData["temp" .. dataPrefix]
        local tokens = SplitString(rawJoined, "~", {})
        local schema = dataKeys[dataPrefix]
        
        if schema then
            for i, keyName in ipairs(schema) do
                local val = tokens[i] or ""
                if keyName == "description" then
                    val = string.gsub(val, "@N", "\n")
                end
                charData[keyName] = val
            end
        end
        charData["temp" .. dataPrefix] = nil
        
        -- Broadcast update to UI listeners
        PUIRoleplay:OnDataReceived(dataPrefix, sender)
    end
end

function Comms:ProcessPing(sender, msg)
    if not sender or sender == "" or sender == UnitName("player") then return end

    local zoneText = string.sub(msg, 2)
    PUIRoleplay:RecordQueryablePlayer(sender)
    
    local charData = PUIRoleplay:GetOrCreateCharacterData(sender)
    local strs = SplitString(zoneText, "~", pingSplitTable)
    if table.getn(strs) >= 3 then
        charData["zone"] = strs[1] or ""
        charData["zoneX"] = strs[2] or ""
        charData["zoneY"] = strs[3] or ""
    else
        charData["zone"] = zoneText
    end

    -- Trigger directory and map pin updates (NO automatic M request here to prevent channel flooding)
    PUIRoleplay:OnPingReceived(sender)
end
