--[[
    PrimusUI: PUIRoleplay Protocols & Data Codecs (PUIProtocols.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Wire Serialization, Drunk Codec & Tokens)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Protocols = {}
PUIRoleplay.Protocols = Protocols

--------------------------------------------------------------------------------
-- Multi-Protocol Wire Data Schemas
--------------------------------------------------------------------------------
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

Protocols.DataKeys = dataKeys

--------------------------------------------------------------------------------
-- Drunk Codec (Protects Wire Packets from Slurred Speech)
--------------------------------------------------------------------------------
local DrunkSuffix = string.gsub(SLURRED_SPEECH or "...hic!", "%%s(.+)", "%1$")

function Protocols:DrunkEncode(text)
    if not text then return "" end
    text = string.gsub(text, "s", "°")
    text = string.gsub(text, "S", "§")
    return text
end

function Protocols:DrunkDecode(text)
    if not text then return "" end
    text = string.gsub(text, "°", "s")
    text = string.gsub(text, "§", "S")
    text = string.gsub(text, DrunkSuffix, "")
    return text
end

--------------------------------------------------------------------------------
-- String Splitting Utility (Safe for Lua 5.0.2)
--------------------------------------------------------------------------------
function Protocols:SplitString(str, delimiter, targetTable)
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
-- Build Outbound Wire Payload
--------------------------------------------------------------------------------
function Protocols:BuildPayload(dataPrefix, profile)
    local keys = dataKeys[dataPrefix]
    if not keys then return "" end

    local prof = profile or PUIRoleplay:GetMyProfile()
    local payload = dataPrefix .. ":"
    local count = table.getn(keys)

    for i = 1, count do
        local key = keys[i]
        local val = prof[key]

        -- Special handling for glances & looking_for nested structures
        if not val then
            if key == "looking_adventure" then val = (prof.looking_for and prof.looking_for.adventure) and "1" or "0"
            elseif key == "looking_romance" then val = (prof.looking_for and prof.looking_for.romance) and "1" or "0"
            elseif key == "looking_combat" then val = (prof.looking_for and prof.looking_for.combat) and "1" or "0"
            elseif key == "looking_tavern" then val = (prof.looking_for and prof.looking_for.casual_tavern) and "1" or "0"
            elseif key == "looking_guild" then val = (prof.looking_for and prof.looking_for.political_guild) and "1" or "0"
            elseif key == "looking_adult" then val = (prof.looking_for and prof.looking_for.adult_18plus) and "1" or "0"
            elseif key == "looking_mentorship" then val = (prof.looking_for and prof.looking_for.mentorship) and "1" or "0"
            elseif key == "adult_18plus_flag" then val = (prof.adult_18plus_flag == true) and "1" or "0"
            elseif key == "lgbtqia_friendly" then val = (prof.lgbtqia_friendly ~= false) and "1" or "0"
            elseif key == "show_orientation" then val = (prof.show_orientation ~= false) and "1" or "0"
            elseif string.find(key, "^history%d$") then
                local chNum = string.sub(key, 8)
                val = (prof.history and prof.history["chapter" .. chNum]) or ""
            end
        end

        local strVal = tostring(val or "")
        if strVal == "true" then strVal = "1"
        elseif strVal == "false" then strVal = "0"
        end

        payload = payload .. strVal
        if i < count then
            payload = payload .. "~"
        end
    end

    return payload
end

--------------------------------------------------------------------------------
-- Parse Inbound Wire Payload
--------------------------------------------------------------------------------
function Protocols:ParsePayload(dataPrefix, chunks, playerName, targetChar)
    local keys = dataKeys[dataPrefix]
    if not keys or not targetChar then return end

    local totalChunks = table.getn(chunks)
    for i = 1, totalChunks do
        local key = keys[i]
        if key then
            local val = chunks[i]
            if val == "nil" or val == "NO_KEY" then val = "" end

            targetChar[key] = val

            -- Map wire fields to internal rich schema
            if key == "looking_adventure" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.adventure = (val == "1" or val == "true")
            elseif key == "looking_romance" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.romance = (val == "1" or val == "true")
            elseif key == "looking_combat" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.combat = (val == "1" or val == "true")
            elseif key == "looking_tavern" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.casual_tavern = (val == "1" or val == "true")
            elseif key == "looking_guild" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.political_guild = (val == "1" or val == "true")
            elseif key == "looking_adult" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.adult_18plus = (val == "1" or val == "true")
            elseif key == "looking_mentorship" then
                if not targetChar.looking_for then targetChar.looking_for = {} end
                targetChar.looking_for.mentorship = (val == "1" or val == "true")
            elseif key == "adult_18plus_flag" then
                targetChar.adult_18plus_flag = (val == "1" or val == "true")
            elseif key == "lgbtqia_friendly" then
                targetChar.lgbtqia_friendly = (val == "1" or val == "true")
            elseif key == "show_orientation" then
                targetChar.show_orientation = (val ~= "0" and val ~= "false")
            elseif string.find(key, "^history%d$") then
                local chNum = string.sub(key, 8)
                if not targetChar.history then targetChar.history = {} end
                targetChar.history["chapter" .. chNum] = val
            elseif string.find(key, "^atAGlance(%d)Title$") then
                local gIdx = tonumber(string.match(key, "%d"))
                if gIdx then
                    if not targetChar.glances then targetChar.glances = {} end
                    if not targetChar.glances[gIdx] then targetChar.glances[gIdx] = {} end
                    targetChar.glances[gIdx].title = val
                end
            elseif string.find(key, "^atAGlance(%d)$") then
                local gIdx = tonumber(string.match(key, "%d"))
                if gIdx then
                    if not targetChar.glances then targetChar.glances = {} end
                    if not targetChar.glances[gIdx] then targetChar.glances[gIdx] = {} end
                    targetChar.glances[gIdx].text = val
                end
            end
        end
    end
end
