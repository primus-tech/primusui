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
        description = "Integrated quest navigation, 25,000+ item/NPC database, world map overlays, and Turtle WoW extensions.",
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
            {
                key = "showMinimapPins",
                label = "Show Minimap Directional Navigation Arrow",
                type = "checkbox",
                default = true,
                get = function() return PUIQuest.db:Get("showMinimapPins", true) end,
                set = function(val)
                    PUIQuest.db:Set("showMinimapPins", val)
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
    end)

    Events:Register("PLAYER_ENTERING_WORLD", "PUIQuest", function()
        if PUIQuest.Quest then PUIQuest.Quest:Initialize() end
        if PUIQuest.Map then PUIQuest.Map:Update() end
    end)

    -- Minimap Ticker (0.25s)
    Time:Every(0.25, "PUIQuest", function()
        if PUIQuest.Tracker then PUIQuest.Tracker:Update() end
    end)
end

function PUIQuest:OnDisable()
    Events:UnregisterOwner("PUIQuest")
    Time:CancelAll("PUIQuest")
    if PUIQuest.Map then PUIQuest.Map:ClearPins() end
    if PUIQuest.Tracker then PUIQuest.Tracker:SetFocus(nil) end
end

-- =========================================================================
-- CLI DIAGNOSTICS HANDLER
-- =========================================================================

function PUIQuest:HandleSlashCommand(args)
    if not args or args == "" or args == "status" then
        local turtleActive = PUIQuest.db:Get("turtleMode", true)
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("=== PrimusUI: PUIQuest Engine Status ===", "69ccf0"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("• Turtle WoW Extensions: |cffffd100%s|r", turtleActive and "ACTIVE" or "DISABLED"))
        DEFAULT_CHAT_FRAME:AddMessage("• Subcommands: |cffffffff/pui db|r (Browser), |cffffffff/pui quest focus <title>|r, |cffffffff/pui quest turtle <on|off>|r")
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
            DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Cleared quest focus.", "ffbb33"))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(Utils.ColorText("[PUIQuest]: Unknown subcommand. Use '/pui quest' for status.", "ff4444"))
    end
end
