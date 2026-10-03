--[[
    PrimusUI: PUIRoleplay Comms Engine (PUIComms.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Multi-Channel OWPRP, TTRP, xtensionxtooltip2, MyRolePlay)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Comms = {}
PUIRoleplay.Comms = Comms

local minChatLevel = 1
local timeBetweenPings = 30

-- Active Channels Matrix
local primaryChannel = "OWPRP"
local fallbackChannels = { "TTRP", "xtensionxtooltip2", "MyRolePlay" }

-- Throttling & Deduplication State
local lastRequestTimes = {}  -- [playerName .. "_" .. requestType] = timestamp
local lastDataSentTime = {}  -- [dataPrefix] = timestamp
local globalLastSendTime = 0
local lastPingSentTime = 0

-- Multi-Protocol Wire Data Schemas
local dataKeys = {
    ["M"] = { "keyM", "icon", "full_name", "race", "class", "class_color", "ooc_info", "ic_info", "currently_ic", "ooc_pronouns", "ic_pronouns", "nsfw", "title", "prefix", "nickname", "house_name", "apparent_age", "gender_identity", "lgbtqia_friendly", "orientation", "show_orientation" },
    ["T"] = { "keyT", "atAGlance1", "atAGlance1Title", "atAGlance1Icon", "atAGlance2", "atAGlance2Title", "atAGlance2Icon", "atAGlance3", "atAGlance3Title", "atAGlance3Icon", "atAGlance4", "atAGlance4Title", "atAGlance4Icon", "atAGlance5", "atAGlance5Title", "atAGlance5Icon", "experience", "walkups", "injury", "romance", "death", "combat_preference" },
    ["D"] = { "keyD", "description", "eye_color", "height", "weight", "body_build", "current_emotion" },
    ["L"] = { "keyL", "birth_city", "home_city", "motto", "faction_clan", "history1", "history2", "history3", "history4", "history5", "history6" },
    ["X"] = { "keyX", "relationship_status", "looking_adventure", "looking_romance", "looking_combat", "looking_tavern", "looking_guild", "looking_adult", "looking_mentorship", "adult_18plus_flag", "erp_preference", "ooc_boundaries" }
}
dataKeys["MR"] = dataKeys["M"]
dataKeys["TR"] = dataKeys["T"]
dataKeys["DR"] = dataKeys["D"]
dataKeys["LR"] = dataKeys["L"]
dataKeys["XR"] = dataKeys["X"]

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
-- Multi-Channel Resolver & Verification
--------------------------------------------------------------------------------
function Comms:GetChannelID(name)
    if not name then return nil end
    local num = GetChannelName(name)
    if num and num > 0 then return num end
    num = GetChannelName(string.lower(name))
    if num and num > 0 then return num end

    local chanList = { GetChannelList() }
    local count = table.getn(chanList)
    for i = 1, count, 2 do
        if string.lower(tostring(chanList[i+1] or "")) == string.lower(name) then
            return tonumber(chanList[i])
        end
    end
    return nil
end

function Comms:CanChat(targetChannel)
    if (UnitLevel("player") or 0) < minChatLevel then
        return false
    end
    if targetChannel then
        local id = self:GetChannelID(targetChannel)
        return (id and id > 0)
    end
    -- Check if ANY of our registered channels are joined
    if self:GetChannelID(primaryChannel) then return true end
    for _, ch in ipairs(fallbackChannels) do
        if self:GetChannelID(ch) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Channel Sending via ChatThrottleLib or Native Fallback
--------------------------------------------------------------------------------
function Comms:SendToChannel(channel, message, priority)
    local chanNumber = self:GetChannelID(channel)
    if not chanNumber or chanNumber == 0 then return end

    local encoded = self:DrunkEncode(message)
    local prio = priority or "BULK"
    if _G.ChatThrottleLib then
        _G.ChatThrottleLib:SendChatMessage(prio, channel, encoded, "CHANNEL", nil, chanNumber)
    else
        SendChatMessage(encoded, "CHANNEL", nil, chanNumber)
    end
end

function Comms:SendBroadcastMessage(message, priority)
    if not self:CanChat() then return end

    -- Broadcast to primary high-bandwidth channel (OWPRP)
    if self:GetChannelID(primaryChannel) then
        self:SendToChannel(primaryChannel, message, priority)
    end

    -- Also mirror to TurtleRP channel for cross-addon compatibility
    if self:GetChannelID("TTRP") then
        self:SendToChannel("TTRP", message, priority)
    end
end

--------------------------------------------------------------------------------
-- Channel Handshake & Join All Multi-Channels
--------------------------------------------------------------------------------
function Comms:JoinRPChannel()
    if (UnitLevel("player") or 0) < minChatLevel then
        return
    end

    local allChannels = { primaryChannel, "TTRP", "xtensionxtooltip2", "MyRolePlay" }
    for _, ch in ipairs(allChannels) do
        if not self:GetChannelID(ch) then
            JoinChannelByName(ch)
        end
    end

    -- Send initial announcement pings spaced safely
    Primus.Time:After(3.0, function()
        if Comms:CanChat() then
            Comms:SendPing("A")
        end
    end, PUIRoleplay)
end

--------------------------------------------------------------------------------
-- Presence Pings (P & A)
--------------------------------------------------------------------------------
function Comms:SendPing(pingType)
    if not self:CanChat() then return end
    
    local curTime = time()
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
            msg = msg .. "~" .. posX .. "~" .. posY .. "~1.2.0"
        else
            msg = msg .. "~false~false~1.2.0"
        end
    else
        msg = msg .. "~false~false~1.2.0"
    end
    
    self:SendBroadcastMessage(msg, "NORMAL")
end

function Comms:StartPingTicker()
    Primus.Time:Every(timeBetweenPings, function()
        if Comms:CanChat() then
            Comms:SendPing("P")
        end
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
-- Request Dispatcher (M, T, D, L, X) with Anti-Flood Deduplication
--------------------------------------------------------------------------------
function Comms:SendRequest(requestType, playerName)
    if not self:CanChat() or not playerName or playerName == "" or playerName == UnitName("player") then
        return
    end
    
    local curTime = time()
    -- Global throttle: minimum 1.5s between ANY request sent to channels
    if (curTime - globalLastSendTime) < 1.5 then
        return
    end
    
    -- Per-player per-request-type cooldown: 30 seconds
    local reqKey = playerName .. "_" .. requestType
    if lastRequestTimes[reqKey] and (curTime - lastRequestTimes[reqKey]) < 30 then
        return
    end
    
    lastRequestTimes[reqKey] = curTime
    globalLastSendTime = curTime
    
    local charInfo = PUIRoleplay:GetCharacterData(playerName)
    local key = charInfo and charInfo["key" .. requestType]
    local packet = requestType .. ":" .. playerName .. "~" .. (key and key ~= "" and key or "NO_KEY")
    self:SendBroadcastMessage(packet, "BULK")
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
            local val = ""
            
            -- Map nested fields from profile structure
            if dataRef == "description" or dataRef == "appearance_desc" then
                val = myInfo.appearance_desc or myInfo.description or ""
                val = string.gsub(val, "\n", "@N")
                if val == "" then val = " " end
            elseif string.find(dataRef, "atAGlance") then
                local _, _, idx, prop = string.find(dataRef, "atAGlance(%d)(.*)")
                local gIdx = tonumber(idx)
                if gIdx and myInfo.glances and myInfo.glances[gIdx] then
                    local g = myInfo.glances[gIdx]
                    if prop == "Title" then val = g.title or ""
                    elseif prop == "Icon" then val = g.icon or ""
                    else val = g.text or "" end
                else
                    val = myInfo[dataRef] or ""
                end
            elseif string.find(dataRef, "history(%d)") then
                local _, _, cIdx = string.find(dataRef, "history(%d)")
                local chKey = "chapter" .. cIdx
                if myInfo.history and myInfo.history[chKey] then
                    val = string.gsub(myInfo.history[chKey], "\n", "@N")
                end
            elseif string.find(dataRef, "looking_") then
                local _, _, cat = string.find(dataRef, "looking_(.*)")
                if myInfo.looking_for and myInfo.looking_for[cat] ~= nil then
                    val = myInfo.looking_for[cat] and "1" or "0"
                end
            elseif dataRef == "lgbtqia_friendly" or dataRef == "show_orientation" or dataRef == "adult_18plus_flag" then
                val = myInfo[dataRef] and "1" or "0"
            else
                val = myInfo[dataRef] or ""
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
    -- Throttle outbound responses: don't broadcast the same data type more than once every 3 seconds
    if lastDataSentTime[dataPrefix] and (curTime - lastDataSentTime[dataPrefix]) < 3 then
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
        self:SendBroadcastMessage(packet, "BULK")
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
                if self:CanChat() and (dataPrefix == "M" or dataPrefix == "T" or dataPrefix == "D" or dataPrefix == "L" or dataPrefix == "X") then
                    local myInfo = PUIRoleplay:GetMyProfile()
                    local keyFromMsg = string.sub(decoded, tildeStart + 1)
                    local myKey = myInfo["key" .. dataPrefix]
                    
                    if keyFromMsg == "NO_KEY" or keyFromMsg ~= myKey then
                        self:SendData(dataPrefix)
                    end
                end
            elseif (targetName == "p" or string.sub(dataPrefix, -1) == "R") and (dataPrefix == "MR" or dataPrefix == "TR" or dataPrefix == "DR" or dataPrefix == "LR" or dataPrefix == "XR") then
                -- Response packet (MR, TR, DR, LR, XR)
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
                if keyName == "description" or keyName == "appearance_desc" then
                    val = string.gsub(val, "@N", "\n")
                end
                
                -- Map to structured fields
                if string.find(keyName, "atAGlance") then
                    if not charData.glances then charData.glances = {} end
                    local _, _, gIdx, prop = string.find(keyName, "atAGlance(%d)(.*)")
                    local idx = tonumber(gIdx)
                    if idx then
                        if not charData.glances[idx] then charData.glances[idx] = { active = true, icon = "INV_Misc_QuestionMark", title = "", text = "" } end
                        if prop == "Title" then charData.glances[idx].title = val
                        elseif prop == "Icon" then charData.glances[idx].icon = val
                        else charData.glances[idx].text = val end
                        if charData.glances[idx].title ~= "" or charData.glances[idx].text ~= "" then
                            charData.glances[idx].active = true
                        end
                    end
                elseif string.find(keyName, "history(%d)") then
                    if not charData.history then charData.history = {} end
                    local _, _, cIdx = string.find(keyName, "history(%d)")
                    charData.history["chapter" .. cIdx] = string.gsub(val, "@N", "\n")
                elseif string.find(keyName, "looking_") then
                    if not charData.looking_for then charData.looking_for = {} end
                    local _, _, cat = string.find(keyName, "looking_(.*)")
                    charData.looking_for[cat] = (val == "1")
                elseif keyName == "lgbtqia_friendly" or keyName == "show_orientation" or keyName == "adult_18plus_flag" then
                    charData[keyName] = (val == "1")
                else
                    charData[keyName] = val
                end
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

    -- Trigger directory and map pin updates
    PUIRoleplay:OnPingReceived(sender)
end
