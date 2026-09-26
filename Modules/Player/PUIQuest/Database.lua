--[[
    PrimusUI Module: PUIQuest (Canonical Multi-Indexed Database Engine)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Provides high-speed lookups across items, quests, NPCs, objects, and coordinates
    directly on PUIQuest.DB with zero legacy globals.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuest = Primus.PUIQuest or {}
Primus.PUIQuest = PUIQuest
_G.PUIQuest = PUIQuest

local Database = {}
PUIQuest.Database = Database

local Utils = Primus.Utils

-- Reverse name lookup indices: [lowerName] = id
local itemIndex = {}
local questIndex = {}
local unitIndex = {}
local objectIndex = {}
local isIndexed = false

function Database:BuildIndices()
    local DB = PUIQuest.DB
    if not DB then return end

    -- 1. Index Items
    local itemLoc = DB["items"] and (DB["items"]["enUS"] or DB["items"]["loc"])
    if itemLoc then
        for id, name in pairs(itemLoc) do
            if type(name) == "string" then
                itemIndex[string.lower(name)] = id
            end
        end
    end

    -- 2. Index Quests
    local questLoc = DB["quests"] and (DB["quests"]["enUS"] or DB["quests"]["loc"])
    if questLoc then
        for id, qData in pairs(questLoc) do
            local title = type(qData) == "table" and qData[1] or qData
            if type(title) == "string" then
                questIndex[string.lower(title)] = id
            end
        end
    end

    -- 3. Index Units
    local unitLoc = DB["units"] and (DB["units"]["enUS"] or DB["units"]["loc"])
    if unitLoc then
        for id, name in pairs(unitLoc) do
            if type(name) == "string" then
                unitIndex[string.lower(name)] = id
            end
        end
    end

    -- 4. Index Objects
    local objectLoc = DB["objects"] and (DB["objects"]["enUS"] or DB["objects"]["loc"])
    if objectLoc then
        for id, name in pairs(objectLoc) do
            if type(name) == "string" then
                objectIndex[string.lower(name)] = id
            end
        end
    end

    isIndexed = true
end

function Database:Reload()
    itemIndex = {}
    questIndex = {}
    unitIndex = {}
    objectIndex = {}
    self:BuildIndices()
end

-- =========================================================================
-- QUERY PRIMITIVES
-- =========================================================================

function Database:FindItem(nameOrID)
    if not isIndexed then self:BuildIndices() end
    local DB = PUIQuest.DB
    if not DB or not DB["items"] then return nil end

    local id = tonumber(nameOrID)
    if not id and type(nameOrID) == "string" then
        id = itemIndex[string.lower(nameOrID)]
    end
    if not id then return nil end

    local data = DB["items"]["data"] and DB["items"]["data"][id]
    local loc = DB["items"]["enUS"] and DB["items"]["enUS"][id]
    return {
        id = id,
        name = loc or ("Item #" .. id),
        data = data or {},
    }
end

function Database:FindQuest(nameOrID)
    if not isIndexed then self:BuildIndices() end
    local DB = PUIQuest.DB
    if not DB or not DB["quests"] then return nil end

    local id = tonumber(nameOrID)
    if not id and type(nameOrID) == "string" then
        id = questIndex[string.lower(nameOrID)]
    end
    if not id then return nil end

    local data = DB["quests"]["data"] and DB["quests"]["data"][id]
    local loc = DB["quests"]["enUS"] and DB["quests"]["enUS"][id]
    local title = type(loc) == "table" and loc[1] or loc
    local desc = type(loc) == "table" and loc[2] or ""
    local objText = type(loc) == "table" and loc[3] or ""

    return {
        id = id,
        title = title or ("Quest #" .. id),
        desc = desc,
        objText = objText,
        data = data or {},
    }
end

function Database:FindUnit(nameOrID)
    if not isIndexed then self:BuildIndices() end
    local DB = PUIQuest.DB
    if not DB or not DB["units"] then return nil end

    local id = tonumber(nameOrID)
    if not id and type(nameOrID) == "string" then
        id = unitIndex[string.lower(nameOrID)]
    end
    if not id then return nil end

    local data = DB["units"]["data"] and DB["units"]["data"][id]
    local loc = DB["units"]["enUS"] and DB["units"]["enUS"][id]

    return {
        id = id,
        name = loc or ("Unit #" .. id),
        spawns = data or {},
    }
end

function Database:FindObject(nameOrID)
    if not isIndexed then self:BuildIndices() end
    local DB = PUIQuest.DB
    if not DB or not DB["objects"] then return nil end

    local id = tonumber(nameOrID)
    if not id and type(nameOrID) == "string" then
        id = objectIndex[string.lower(nameOrID)]
    end
    if not id then return nil end

    local data = DB["objects"]["data"] and DB["objects"]["data"][id]
    local loc = DB["objects"]["enUS"] and DB["objects"]["enUS"][id]

    return {
        id = id,
        name = loc or ("Object #" .. id),
        spawns = data or {},
    }
end

-- Resolve vendor price if item is sold by vendors
function Database:GetItemVendorPrice(itemID)
    local item = self:FindItem(itemID)
    if not item or not item.data then return nil end

    local v = item.data["V"]
    if v then
        for vendorID, count in pairs(v) do
            -- In pfDB, V table contains vendor info
            return tonumber(count) or 0
        end
    end
    return nil
end

-- Search entities by prefix or keyword
function Database:Search(query, category, maxResults)
    if not query or query == "" then return {} end
    if not isIndexed then self:BuildIndices() end

    maxResults = maxResults or 50
    category = category and string.lower(category) or "all"
    query = string.lower(query)

    local results = {}
    local count = 0

    local function CheckMatch(tbl, catName)
        for name, id in pairs(tbl) do
            if string.find(name, query, 1, true) then
                count = count + 1
                table.insert(results, { id = id, name = name, category = catName })
                if count >= maxResults then return true end
            end
        end
        return false
    end

    if category == "all" or category == "quests" then
        if CheckMatch(questIndex, "Quests") then return results end
    end
    if category == "all" or category == "items" then
        if CheckMatch(itemIndex, "Items") then return results end
    end
    if category == "all" or category == "units" then
        if CheckMatch(unitIndex, "Units") then return results end
    end
    if category == "all" or category == "objects" then
        if CheckMatch(objectIndex, "Objects") then return results end
    end

    return results
end
