--[[
    PrimusUI Module: PUIQuest (Master In-Game Database & Quest Navigation Controller)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    100% Canonical PUI Architecture (Zero Aliases / Zero Shims / Zero Metatable Proxies)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIQuest = Primus.PUIQuest or {}
Primus.PUIQuest = PUIQuest
_G.PUIQuest = PUIQuest
Primus:RegisterModule("PUIQuest", PUIQuest, "Player")

local DB      = Primus.DB
local Events  = Primus.Events
local Utils   = Primus.Utils
local Console = Primus.Console
local Time    = Primus.Time
local Debug   = Primus.Debug

PUIQuest.db = DB:RegisterNamespace("PUIQuest", {
    enabled             = true,
    turtleMode          = true,   -- Enable Turtle WoW / Custom Extensions
    showWorldMapPins    = true,
    showMinimapPins     = true,
    showRouteLines      = true,   -- Glowing route trails connecting player to target
    showAvailableQuests = true,
    showTurnIns         = true,
    showObjectives      = true,
})

-- Ensure global storage alias for external scripts
if _G.PrimusGlobalDB then
    _G.PrimusGlobalDB.PUIQuest = PUIQuest.db.data
end

-- =========================================================================
-- PUBLIC NAVIGATION HANDSHAKE API
-- =========================================================================

function PUIQuest:FocusQuest(questTitle)
    if PUIQuest.Tracker then
        PUIQuest.Tracker:SetFocus(questTitle)
    end
    if PUIQuest.Map then
        PUIQuest.Map:Update()
    end
    if questTitle then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText(string.format("[PUIQuest]: Focused objective target: %s", questTitle), "69ccf0"))
    end
end

function PUIQuest:GetFocusedQuest()
    if PUIQuest.Tracker then
        return PUIQuest.Tracker:GetFocus()
    end
    return nil
end

-- =========================================================================
-- OPTIONS FLARE REGISTRATION
-- =========================================================================

function PUIQuest:RegisterOptionsFlare()
    local Options = Primus.Options
    if not Options or not Options.RegisterModuleOptions then return end

    Options:RegisterModuleOptions("PUIQuest", "Player", {
        title = "PUIQuest: Database & Quest Engine",
        description = "Integrated quest navigation, 25,000+ item/NPC database, world map overlays, route connection lines, and Turtle WoW extensions.",
        icon = "Interface\\Icons\\INV_Misc_Map02",
        fields = {
            {
                key = "enabled",
                label = "Enable PUIQuest Navigation & Database",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("enabled", true) end,
                set = function(val)
                    PUIQuest.db:Set("enabled", val)
                    if val then PUIQuest:OnEnable() else PUIQuest:OnDisable() end
                end,
            },
            {
                key = "turtleMode",
                label = "Enable Turtle WoW Database Extensions",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("turtleMode", true) end,
                set = function(val)
                    PUIQuest.db:Set("turtleMode", val)
                    if val and PUIQuest.Patchtable then
                        PUIQuest.Patchtable:Apply()
                    end
                    if PUIQuest.Map then PUIQuest.Map:Update() end
                end,
            },
            {
                key = "showMinimapPins",
                label = "Show 3D HUD Navigation Arrow & Minimap Radar",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showMinimapPins", true) end,
                set = function(val)
                    PUIQuest.db:Set("showMinimapPins", val)
                    if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
                end,
            },
            {
                key = "showRouteLines",
                label = "Show Dynamic Route Connection Lines on Map",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showRouteLines", true) end,
                set = function(val)
                    PUIQuest.db:Set("showRouteLines", val)
                    if PUIQuest.Map then PUIQuest.Map:Update() end
                end,
            },
            {
                key = "showWorldMapPins",
                label = "Show Quest POI Overlays on World Map",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showWorldMapPins", true) end,
                set = function(val)
                    PUIQuest.db:Set("showWorldMapPins", val)
                    if PUIQuest.Map then PUIQuest.Map:Update() end
                end,
            },
            {
                key = "showAvailableQuests",
                label = "Show Available Quests (!) on World Map",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showAvailableQuests", true) end,
                set = function(val)
                    PUIQuest.db:Set("showAvailableQuests", val)
                    if PUIQuest.Map then PUIQuest.Map:Update() end
                end,
            },
            {
                key = "showTurnIns",
                label = "Show Active Turn-In Badges (?) on World Map",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showTurnIns", true) end,
                set = function(val)
                    PUIQuest.db:Set("showTurnIns", val)
                    if PUIQuest.Map then PUIQuest.Map:Update() end
                end,
            },
        },
    })
end

-- =========================================================================
-- LIFECYCLE & EVENT ROUTING
-- =========================================================================

function PUIQuest:OnInitialize()
    self:RegisterOptionsFlare()

    -- Apply Turtle WoW patches if enabled
    if PUIQuest.db:Get("turtleMode", true) and PUIQuest.Patchtable then
        PUIQuest.Patchtable:Apply()
    end

    if PUIQuest.Database then
        PUIQuest.Database:BuildIndices()
    end

    if PUIQuest.Quest then
        PUIQuest.Quest:Initialize()
    end

    -- CLI Router Integration
    if Console and Console.RegisterSubCommand then
        Console:RegisterSubCommand("quest", function(args)
            PUIQuest:HandleSlashCommand(args)
        end, "PUIQuest navigation & database status (/pui quest)")
        Console:RegisterSubCommand("db", function(args)
            if PUIQuest.Browser then
                PUIQuest.Browser:Toggle()
            end
        end, "Open in-game database browser (/pui db)")
    end
end

function PUIQuest:OnEnable()
    Events:Register("WORLD_MAP_UPDATE", "PUIQuest", function()
        if PUIQuest.Map then PUIQuest.Map:Update() end
    end)

    Events:Register("QUEST_LOG_UPDATE", "PUIQuest", function()
        if PUIQuest.Map then PUIQuest.Map:Update() end
        if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
    end)

    Events:Register("ZONE_CHANGED", "PUIQuest", function()
        if PUIQuest.Map then PUIQuest.Map:Update() end
        if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
    end)

    Events:Register("ZONE_CHANGED_NEW_AREA", "PUIQuest", function()
        if PUIQuest.Map then PUIQuest.Map:Update() end
        if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
    end)

    Events:Register("PLAYER_ENTERING_WORLD", "PUIQuest", function()
        if PUIQuest.Quest then PUIQuest.Quest:Initialize() end
        if PUIQuest.Map then PUIQuest.Map:Update() end
        if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
    end)

    -- Real-time WorldMap Route & Pin Ticker (0.3s when WorldMap is open)
    Time:Every(0.3, function()
        if WorldMapFrame and WorldMapFrame:IsVisible() and PUIQuest.Map then
            PUIQuest.Map:Update()
        end
    end, nil, "PUIQuest")
end

function PUIQuest:OnDisable()
    Events:UnregisterOwner("PUIQuest")
    Time:CancelAll("PUIQuest")
    if PUIQuest.Map then
        PUIQuest.Map:ClearPins()
        PUIQuest.Map:ClearRoute()
    end
    if PUIQuest.Tracker then
        PUIQuest.Tracker:SetFocus(nil)
    end
end

-- =========================================================================
-- CLI DIAGNOSTICS HANDLER
-- =========================================================================

function PUIQuest:HandleSlashCommand(args)
    if not args or args == "" or args == "status" then
        local turtleActive = PUIQuest.db:Get("turtleMode", true)
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("=== PrimusUI: PUIQuest Engine Status ===", "69ccf0"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Turtle WoW Extensions: |cffffd100%s|r", turtleActive and "ACTIVE" or "DISABLED"))
        DEFAULT_CHAT_FRAME:AddMessage("• Subcommands: |cffffffff/pui db|r (Browser), |cffffffff/pui quest focus <title>|r, |cffffffff/pui quest arrow|r (Test Arrow), |cffffffff/pui quest debug|r")
        return
    end

    local tokens = Utils.Split(args, " ")
    local cmd = string.lower(tokens[1] or "")

    if cmd == "browser" or cmd == "db" or cmd == "show" then
        if PUIQuest.Browser then PUIQuest.Browser:Toggle() end
    elseif cmd == "turtle" then
        local state = string.lower(tokens[2] or "")
        if state == "on" or state == "1" or state == "enable" then
            PUIQuest.db:Set("turtleMode", true)
            if PUIQuest.Patchtable then PUIQuest.Patchtable:Apply() end
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Turtle WoW extensions enabled.", "69ccf0"))
        elseif state == "off" or state == "0" or state == "disable" then
            PUIQuest.db:Set("turtleMode", false)
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Turtle WoW extensions disabled.", "ffbb33"))
        end
        if PUIQuest.Map then PUIQuest.Map:Update() end
    elseif cmd == "focus" or cmd == "track" then
        table.remove(tokens, 1)
        local title = table.concat(tokens, " ")
        if title and title ~= "" then
            self:FocusQuest(title)
        else
            self:FocusQuest(nil)
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Reset to automatic closest-quest navigation.", "ffbb33"))
        end
    elseif cmd == "arrow" or cmd == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("=== PUIQuest Navigation Diagnostics ===", "69ccf0"))
        local px, py = GetPlayerMapPosition("player")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Player Pos: |cffffd100%.2f, %.2f|r (Zone: %s / %s)", (px or 0)*100, (py or 0)*100, tostring(GetZoneText()), tostring(GetRealZoneText())))
        
        if PUIQuest.Tracker then
            if PUIQuest.Tracker.ResetFacingModel then
                PUIQuest.Tracker:ResetFacingModel()
            end
            if PUIQuest.Tracker.GetFacingInfo then
                local pf, src = PUIQuest.Tracker:GetFacingInfo()
                local deg = math.floor(math.deg(pf or 0) + 0.5)
                DEFAULT_CHAT_FRAME:AddMessage(string.format("• Player Facing: |cffffd100%d°|r (%.2f rad) via |cff69ccf0%s|r", deg, pf or 0, src or "None"))
            end
        end

        if Minimap then
            local ch = { Minimap:GetChildren() }
            local chCount = table.getn(ch)
            local details = {}
            for i = 1, chCount do
                local c = ch[i]
                if c and c.GetFacing then
                    local ok, f = pcall(function() return c:GetFacing() end)
                    if ok and type(f) == "number" then
                        table.insert(details, string.format("#%d: %.1f°", i, math.deg(f)))
                    end
                end
            end
            if table.getn(details) > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("• Minimap Frames (%d total): %s", chCount, table.concat(details, ", ")))
            end
        end

        local activeTarget = PUIQuest.Tracker and PUIQuest.Tracker:GetActiveTarget()
        if activeTarget then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("• Active Target: |cff00ff00%s|r (%s)", activeTarget.title or "None", activeTarget.text or ""))
            if activeTarget.isDifferentZone then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("• Target Zone: |cffffbb33%s|r (Different Zone)", activeTarget.zoneName or "Unknown"))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("• Distance: |cffffffff%d yd|r (Coords: %.1f, %.1f)", activeTarget.yards or 0, (activeTarget.x or 0)*100, (activeTarget.y or 0)*100))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("• Active Target: |cffff4444None found (Check quest log)|r")
        end
        local numLog = GetNumQuestLogEntries() or 0
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Quest Log Entries: |cffffffff%d|r", numLog))
        if PUIQuest.Tracker then
            PUIQuest.Tracker:Update()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Unknown subcommand. Use '/pui quest' for status.", "ff4444"))
    end
end
