--[[
    PrimusUI: PUIRoleplay Master Module Coordinator (PUIRoleplay.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (100% TurtleRP Wire Compatibility & Dark Theme)
--]]

local Primus = _G.Primus
local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay
_G.PUIRoleplay = PUIRoleplay
Primus:RegisterModule("PUIRoleplay", PUIRoleplay, "Social")

local db = nil

local defaultCharTemplate = {
    keyM = "PUI10",
    keyT = "PUI20",
    keyD = "PUI30",
    nsfw = "0",
    icon = "1",
    full_name = "",
    title = "",
    race = "",
    class = "",
    class_color = "FFFFFF",
    ic_info = "",
    ooc_info = "",
    ic_pronouns = "",
    ooc_pronouns = "",
    currently_ic = "1",
    atAGlance1 = "",
    atAGlance1Title = "",
    atAGlance1Icon = "",
    atAGlance2 = "",
    atAGlance2Title = "",
    atAGlance2Icon = "",
    atAGlance3 = "",
    atAGlance3Title = "",
    atAGlance3Icon = "",
    experience = "a",
    walkups = "a",
    injury = "b",
    romance = "e",
    death = "b",
    description = "",
    notes = ""
}

local defaults = {
    selected_profile = "0",
    profiles = {
        ["0"] = defaultCharTemplate,
        ["1"] = defaultCharTemplate,
        ["2"] = defaultCharTemplate,
        ["3"] = defaultCharTemplate
    },
    character_notes = {},
    known_characters = {},
    queryable_players = {},
    settings = {
        share_location = "1",
        show_nsfw = "0",
        bgs = "off",
        show_glance_bar = true,
        show_icon_tray = true,
    }
}

--------------------------------------------------------------------------------
-- Key Generation
--------------------------------------------------------------------------------
local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
function PUIRoleplay:GenerateKey()
    local key = ""
    local len = string.len(alphabet)
    for i = 1, 5 do
        local r = math.random(1, len)
        key = key .. string.sub(alphabet, r, r)
    end
    return key
end

--------------------------------------------------------------------------------
-- Database & Profile Helpers
--------------------------------------------------------------------------------
function PUIRoleplay:GetData()
    if db and db.data then
        return db.data
    end
    return defaults
end

function PUIRoleplay:GetActiveProfileSlot()
    local data = self:GetData()
    return data.selected_profile or "0"
end

function PUIRoleplay:SetActiveProfileSlot(slot)
    local data = self:GetData()
    data.selected_profile = tostring(slot)
    if not data.profiles then data.profiles = {} end
    if not data.profiles[data.selected_profile] then
        data.profiles[data.selected_profile] = Primus.Utils.DeepCopy(defaultCharTemplate)
    end
    self:SyncGlobalBridges()
end

function PUIRoleplay:GetMyProfile()
    local data = self:GetData()
    local slot = self:GetActiveProfileSlot()
    if not data.profiles then data.profiles = {} end
    if not data.profiles[slot] then
        data.profiles[slot] = Primus.Utils.DeepCopy(defaultCharTemplate)
    end
    local prof = data.profiles[slot]
    if not prof.full_name or prof.full_name == "" then
        prof.full_name = UnitName("player") or "Player"
    end
    if not prof.race or prof.race == "" then
        prof.race = UnitRace("player") or ""
    end
    if not prof.class or prof.class == "" then
        prof.class = UnitClass("player") or ""
        local cData = PUIRoleplay.ClassData[prof.class]
        if cData then prof.class_color = cData[4] end
    end
    return prof
end

function PUIRoleplay:SaveMyProfile(prof)
    local data = self:GetData()
    local slot = self:GetActiveProfileSlot()
    if not data.profiles then data.profiles = {} end
    data.profiles[slot] = prof
    self:SyncGlobalBridges()
end

function PUIRoleplay:GetCharacterData(name)
    if not name or name == "" then return nil end
    if name == UnitName("player") then return self:GetMyProfile() end
    local data = self:GetData()
    if not data.known_characters then data.known_characters = {} end
    return data.known_characters[name]
end

function PUIRoleplay:GetOrCreateCharacterData(name)
    if not name or name == "" then return {} end
    if name == UnitName("player") then return self:GetMyProfile() end
    local data = self:GetData()
    if not data.known_characters then data.known_characters = {} end
    if not data.known_characters[name] then
        data.known_characters[name] = {}
    end
    return data.known_characters[name]
end

function PUIRoleplay:GetAllKnownCharacters()
    local data = self:GetData()
    if not data.known_characters then data.known_characters = {} end
    return data.known_characters
end

function PUIRoleplay:SetCharacterNote(name, note)
    if not name or name == "" then return end
    local data = self:GetData()
    if not data.character_notes then data.character_notes = {} end
    data.character_notes[name] = note
    self:SyncGlobalBridges()
end

function PUIRoleplay:GetCharacterNote(name)
    if not name or name == "" then return "" end
    local data = self:GetData()
    if not data.character_notes then data.character_notes = {} end
    return data.character_notes[name] or ""
end

function PUIRoleplay:GetSettings()
    local data = self:GetData()
    if not data.settings then data.settings = defaults.settings end
    return data.settings
end

function PUIRoleplay:GetICState()
    local prof = self:GetMyProfile()
    return prof.currently_ic or "1"
end

function PUIRoleplay:SetICState(state)
    local prof = self:GetMyProfile()
    prof.currently_ic = tostring(state)
    prof.keyM = self:GenerateKey()
    self:SaveMyProfile(prof)
    if self.Glance then
        self.Glance:UpdateTarget()
    end
    if self.Tray and self.Tray.UpdateICButton then
        self.Tray:UpdateICButton()
    end
end

function PUIRoleplay:RecordQueryablePlayer(name)
    if not name or name == "" then return end
    local data = self:GetData()
    if not data.queryable_players then data.queryable_players = {} end
    data.queryable_players[name] = time()
    self:SyncGlobalBridges()
end

function PUIRoleplay:IsPlayerOnline(name)
    if not name or name == "" then return false end
    if name == UnitName("player") then return true end
    local data = self:GetData()
    if data and data.queryable_players and data.queryable_players[name] then
        local lastSeen = data.queryable_players[name]
        if type(lastSeen) == "number" and lastSeen > (time() - 90) then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Global Bridges (100% Seamless TurtleRP Cross-Compatibility)
--------------------------------------------------------------------------------
function PUIRoleplay:SyncGlobalBridges()
    local data = self:GetData()
    if not data.known_characters then data.known_characters = {} end
    if not data.profiles then data.profiles = {} end
    if not data.queryable_players then data.queryable_players = {} end
    if not data.settings then data.settings = defaults.settings end

    _G.TurtleRPCharacters = data.known_characters
    _G.TurtleRPCharacterInfo = self:GetMyProfile()
    _G.TurtleRPPlayerProfiles = data.profiles
    _G.TurtleRPQueryablePlayers = data.queryable_players
    _G.TurtleRPSettings = data.settings
    
    if UnitName("player") then
        _G.TurtleRPCharacters[UnitName("player")] = _G.TurtleRPCharacterInfo
    end
end

--------------------------------------------------------------------------------
-- Network Events / Updates Callback
--------------------------------------------------------------------------------
function PUIRoleplay:OnDataReceived(dataPrefix, playerName)
    self:SyncGlobalBridges()
    
    -- Refresh open sheet if viewing this player
    if self.Sheet and Primus_PUIRoleplay_Sheet and Primus_PUIRoleplay_Sheet:IsVisible() then
        self.Sheet:Refresh()
    end
    
    -- Refresh glance bar if this is our target
    if UnitName("target") == playerName and self.Glance then
        self.Glance:RenderTargetData(playerName)
    end

    -- Refresh directory if open
    if self.Directory and Primus_PUIRoleplay_Directory and Primus_PUIRoleplay_Directory:IsVisible() then
        self.Directory:RefreshList()
    end
end

function PUIRoleplay:OnPingReceived(sender)
    self:SyncGlobalBridges()
    if self.Directory then
        self.Directory:UpdateWorldMapPins()
        if Primus_PUIRoleplay_Directory and Primus_PUIRoleplay_Directory:IsVisible() then
            self.Directory:RefreshList()
        end
    end
end

--------------------------------------------------------------------------------
-- Module Lifecycle (OnInitialize, OnEnable, OnDisable)
--------------------------------------------------------------------------------
function PUIRoleplay:OnInitialize()
    db = Primus.DB:RegisterNamespace("PUIRoleplay", defaults)
    
    -- If known_characters is empty but TurtleRP has saved data in _G, copy it over
    local data = self:GetData()
    if data and data.known_characters then
        if _G.TurtleRPCharacters and type(_G.TurtleRPCharacters) == "table" then
            for k, v in pairs(_G.TurtleRPCharacters) do
                if not data.known_characters[k] and type(v) == "table" then
                    data.known_characters[k] = Primus.Utils.DeepCopy(v)
                end
            end
        end
        if _G.TurtleRPQueryablePlayers and type(_G.TurtleRPQueryablePlayers) == "table" then
            if not data.queryable_players then data.queryable_players = {} end
            for k, v in pairs(_G.TurtleRPQueryablePlayers) do
                if not data.queryable_players[k] then
                    data.queryable_players[k] = v
                end
            end
        end
    end

    -- Initialize default fields if missing
    local myProf = self:GetMyProfile()
    if not myProf.keyM or myProf.keyM == "" then myProf.keyM = self:GenerateKey() end
    if not myProf.keyT or myProf.keyT == "" then myProf.keyT = self:GenerateKey() end
    if not myProf.keyD or myProf.keyD == "" then myProf.keyD = self:GenerateKey() end
    
    self:SyncGlobalBridges()
    
    -- Register Options Flare
    self:RegisterFlare()
    
    -- Register Console Subcommands
    Primus.Console:RegisterSubCommand("rp", function(args)
        if args == "dir" or args == "directory" then
            PUIRoleplay:OpenDirectory()
        elseif args == "chat" or args == "compose" then
            PUIRoleplay.Emotes:OpenComposer()
        elseif args == "bar" or args == "tray" then
            if PUIRoleplay.Tray then PUIRoleplay.Tray:Toggle() end
        else
            PUIRoleplay:OpenProfile()
        end
    end, "Roleplaying suite (/pui rp [dir|chat|tray])")
    
    Primus.Console:RegisterSubCommand("ttrp", function(args)
        PUIRoleplay:OpenProfile()
    end, "TurtleRP profile compatibility shortcut")
    
    -- Top-level slash command shortcuts
    SLASH_PUIRP1 = "/rp"
    SlashCmdList["PUIRP"] = function(msg)
        if msg == "dir" or msg == "directory" then
            PUIRoleplay:OpenDirectory()
        elseif msg == "chat" or msg == "compose" then
            PUIRoleplay.Emotes:OpenComposer()
        elseif msg == "bar" or msg == "tray" then
            if PUIRoleplay.Tray then PUIRoleplay.Tray:Toggle() end
        elseif msg == "ic" then
            PUIRoleplay:SetICState("1")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffPrimus RP:|r Status set to |cff40af6f[IC]|r")
        elseif msg == "ooc" then
            PUIRoleplay:SetICState("0")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffPrimus RP:|r Status set to |cffd3681e[OOC]|r")
        else
            PUIRoleplay:OpenProfile()
        end
    end
    
    SLASH_PUITTRP1 = "/ttrp"
    SlashCmdList["PUITTRP"] = SlashCmdList["PUIRP"]
end

function PUIRoleplay:OnEnable()
    -- Register Comms Channel Listener
    Primus.Events:Register("CHAT_MSG_CHANNEL", self, function(owner, event, msg, sender, lang, chanStr, target, flags, zoneId, chanNum, chanName)
        local ch = string.lower(chanName or "")
        local cs = string.lower(chanStr or "")
        if ch == "ttrp" or cs == "ttrp" or string.find(cs, "ttrp") then
            PUIRoleplay.Comms:OnChatMessage(msg, sender)
        end
    end)

    -- Channel Notices (e.g. You Joined TTRP)
    Primus.Events:Register("CHAT_MSG_CHANNEL_NOTICE", self, function(owner, event, noticeType, sender, _, chanStr, _, _, _, chanNum, chanName)
        local ch = string.lower(chanName or "")
        local cs = string.lower(chanStr or "")
        if ch == "ttrp" or cs == "ttrp" or string.find(cs, "ttrp") then
            if noticeType == "YOU_JOINED" or noticeType == "YOU_CHANGED" then
                PUIRoleplay.Comms:SendPing("A")
            end
        end
    end)

    -- Player entering world
    Primus.Events:Register("PLAYER_ENTERING_WORLD", self, function()
        PUIRoleplay.Comms:JoinRPChannel()
    end)
    
    -- Target & Mouseover Updates
    Primus.Events:Register("PLAYER_TARGET_CHANGED", self, function()
        if PUIRoleplay.Glance then
            PUIRoleplay.Glance:UpdateTarget()
        end
        if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
            local name = UnitName("target")
            if name then
                PUIRoleplay.Comms:SendRequest("T", name)
            end
        end
    end)

    Primus.Events:Register("UPDATE_MOUSEOVER_UNIT", self, function()
        if UnitIsPlayer("mouseover") and not UnitIsUnit("mouseover", "player") then
            local name = UnitName("mouseover")
            if name then
                PUIRoleplay.Comms:SendRequest("M", name)
            end
        end
    end)
    
    -- World Map & Area updates
    Primus.Events:Register("WORLD_MAP_UPDATE", self, function()
        if PUIRoleplay.Directory then
            PUIRoleplay.Directory:UpdateWorldMapPins()
        end
    end)
    
    Primus.Events:Register("ZONE_CHANGED_NEW_AREA", self, function()
        if PUIRoleplay.Directory then
            PUIRoleplay.Directory:UpdateWorldMapPins()
        end
    end)
    
    -- Join Channel & Start Telemetry
    self.Comms:JoinRPChannel()
    self.Comms:StartPingTicker()
    
    -- Initialize Tooltip enhancements
    self.Tooltip:Initialize()

    -- Initialize & Show RP Quick Bar (Tray)
    local s = self:GetSettings()
    if s.show_icon_tray ~= false and self.Tray then
        self.Tray:Show()
    end
end

function PUIRoleplay:OnDisable()
    Primus.Events:UnregisterOwner(self)
    Primus.Time:CancelAll(self)
    
    if Primus_PUIRoleplay_Sheet then Primus_PUIRoleplay_Sheet:Hide() end
    if Primus_PUIRoleplay_GlanceBar then Primus_PUIRoleplay_GlanceBar:Hide() end
    if Primus_PUIRoleplay_Directory then Primus_PUIRoleplay_Directory:Hide() end
    if self.Tray then self.Tray:Hide() end
end

--------------------------------------------------------------------------------
-- Options Flare Hub Integration
--------------------------------------------------------------------------------
function PUIRoleplay:RegisterFlare()
    if not Primus.Options then return end
    
    Primus.Options:RegisterModuleOptions("PUIRoleplay", {
        title = "Roleplaying (PUIRP)",
        category = "Social",
        order = 4,
        desc = "Full-featured Roleplaying suite with 100% TurtleRP wire-protocol compatibility, At-A-Glance HUD pill, and dark theme."
    }, function(parent)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetWidth(parent:GetWidth())
        frame:SetHeight(400)
        
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
        title:SetText("|cff00ccffRoleplaying Suite Settings|r")
        
        -- Show RP Quick Bar Checkbox
        local trayCB = Primus.Widgets:CreateCheckButton(frame, "Show RP Quick Action Bar (Tray)", PUIRoleplay:GetSettings().show_icon_tray ~= false, function(checked)
            local s = PUIRoleplay:GetSettings()
            s.show_icon_tray = checked
            if checked and PUIRoleplay.Tray then
                PUIRoleplay.Tray:Show()
            elseif PUIRoleplay.Tray then
                PUIRoleplay.Tray:Hide()
            end
        end)
        trayCB:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

        -- Share Location Checkbox
        local shareLocCB = Primus.Widgets:CreateCheckButton(frame, "Share Location on RP World Map", PUIRoleplay:GetSettings().share_location == "1", function(checked)
            local s = PUIRoleplay:GetSettings()
            s.share_location = checked and "1" or "0"
        end)
        shareLocCB:SetPoint("TOPLEFT", trayCB, "BOTTOMLEFT", 0, -8)
        
        -- Disable in BGs Checkbox
        local bgsCB = Primus.Widgets:CreateCheckButton(frame, "Disable RP overlays in Battlegrounds", PUIRoleplay:GetSettings().bgs == "off", function(checked)
            local s = PUIRoleplay:GetSettings()
            s.bgs = checked and "off" or "on"
        end)
        bgsCB:SetPoint("TOPLEFT", shareLocCB, "BOTTOMLEFT", 0, -8)
        
        -- NSFW Filter Checkbox
        local nsfwCB = Primus.Widgets:CreateCheckButton(frame, "Show NSFW Roleplay Profiles", PUIRoleplay:GetSettings().show_nsfw == "1", function(checked)
            local s = PUIRoleplay:GetSettings()
            s.show_nsfw = checked and "1" or "0"
        end)
        nsfwCB:SetPoint("TOPLEFT", bgsCB, "BOTTOMLEFT", 0, -8)
        
        -- Action Buttons
        local openSheetBtn = Primus.Widgets:CreateButton(frame, "Open Profile Editor", 160, 24, function()
            PUIRoleplay:OpenProfile()
        end)
        openSheetBtn:SetPoint("TOPLEFT", nsfwCB, "BOTTOMLEFT", 0, -16)
        
        local openDirBtn = Primus.Widgets:CreateButton(frame, "Open RP Directory", 160, 24, function()
            PUIRoleplay:OpenDirectory()
        end)
        openDirBtn:SetPoint("LEFT", openSheetBtn, "RIGHT", 12, 0)
        
        local openCompBtn = Primus.Widgets:CreateButton(frame, "Compose Emote", 160, 24, function()
            PUIRoleplay.Emotes:OpenComposer()
        end)
        openCompBtn:SetPoint("TOPLEFT", openSheetBtn, "BOTTOMLEFT", 0, -8)

        local toggleTrayBtn = Primus.Widgets:CreateButton(frame, "Toggle RP Bar", 160, 24, function()
            if PUIRoleplay.Tray then PUIRoleplay.Tray:Toggle() end
        end)
        toggleTrayBtn:SetPoint("LEFT", openCompBtn, "RIGHT", 12, 0)
        
        return frame
    end)
end
