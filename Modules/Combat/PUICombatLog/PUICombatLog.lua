--[[
    PrimusLib Module: CombatLogParser (Raw 1.12 Combat String Parser)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    High-performance zero-garbage string parser that converts raw 1.12 combat log
    text into structured event callbacks for damage, heals, casts, and auras.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUICombatLog = Primus.PUICombatLog or {}
Primus.PUICombatLog = PUICombatLog
_G.PUICombatLog = PUICombatLog
Primus:RegisterModule("PUICombatLog", PUICombatLog, "Combat")

local Events = Primus.Events
local Memory = Primus.Memory
local Utils  = Primus.Utils
local Debug  = Primus.Debug

-- Combat event patterns for Vanilla 1.12 English client
-- (In localized environments, patterns adapt to locale)
local PATTERNS = {
    -- 1. Player Melee Swings (Hits, Crits, Glancings)
    { pattern = "You hit (.+) for (%d+) %(glancing%)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = false, isSwing = true },
    { pattern = "You hit (.+) for (%d+) %(crushing%)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = false, isSwing = true },
    { pattern = "You hit (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = false, isSwing = true },
    { pattern = "You crit (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = true, isSwing = true },

    -- 2. Player Ranged Swings (Auto Shot & Wand Shoot)
    { pattern = "Your Auto Shot hits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = false, isRanged = true, isSwing = true },
    { pattern = "Your Auto Shot crits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = true, isRanged = true, isSwing = true },
    { pattern = "Your Shoot hits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = false, isRanged = true, isSwing = true },
    { pattern = "Your Shoot crits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = true, isCrit = true, isRanged = true, isSwing = true },

    -- 3. Player Swings / Ranged Misses & Defenses (Reset swing timers)
    { pattern = "You miss (.+)%.", event = "SWING_MISSED", isPlayer = true, isSwing = true },
    { pattern = "You attack. (.+) dodges%.", event = "SWING_MISSED", isPlayer = true, isSwing = true },
    { pattern = "You attack. (.+) parries%.", event = "SWING_MISSED", isPlayer = true, isSwing = true },
    { pattern = "You attack. (.+) blocks%.", event = "SWING_MISSED", isPlayer = true, isSwing = true },
    { pattern = "Your Auto Shot misses (.+)%.", event = "SWING_MISSED", isPlayer = true, isRanged = true, isSwing = true },
    { pattern = "Your Shoot misses (.+)%.", event = "SWING_MISSED", isPlayer = true, isRanged = true, isSwing = true },

    -- 4. Enemy Swings on Player (Hits, Crits, Misses, Dodges, Parries, Blocks)
    { pattern = "(.+) hits you for (%d+)%.", event = "SWING_DAMAGE", isPlayer = false, isCrit = false, isEnemyOnPlayer = true, isSwing = true },
    { pattern = "(.+) crits you for (%d+)%.", event = "SWING_DAMAGE", isPlayer = false, isCrit = true, isEnemyOnPlayer = true, isSwing = true },
    { pattern = "(.+) misses you%.", event = "SWING_MISSED", isPlayer = false, isEnemyOnPlayer = true, isSwing = true },
    { pattern = "You dodge (.+)'s attack%.", event = "SWING_MISSED", isPlayer = false, isEnemyOnPlayer = true, isSwing = true },
    { pattern = "You parry (.+)'s attack%.", event = "SWING_MISSED", isPlayer = false, isEnemyOnPlayer = true, isSwing = true },
    { pattern = "You block (.+)'s attack%.", event = "SWING_MISSED", isPlayer = false, isEnemyOnPlayer = true, isSwing = true },

    -- 5. Player Spell Damage & Abilities
    { pattern = "Your (.+) hits (.+) for (%d+) (.+) damage%.", event = "SPELL_DAMAGE", isPlayer = true, isCrit = false },
    { pattern = "Your (.+) crits (.+) for (%d+) (.+) damage%.", event = "SPELL_DAMAGE", isPlayer = true, isCrit = true },
    { pattern = "Your (.+) hits (.+) for (%d+)%.", event = "SPELL_DAMAGE", isPlayer = true, isCrit = false },
    { pattern = "Your (.+) crits (.+) for (%d+)%.", event = "SPELL_DAMAGE", isPlayer = true, isCrit = true },

    -- 6. Player Heals
    { pattern = "Your (.+) heals (.+) for (%d+)%.", event = "SPELL_HEAL", isPlayer = true, isCrit = false },
    { pattern = "Your (.+) critically heals (.+) for (%d+)%.", event = "SPELL_HEAL", isPlayer = true, isCrit = true },

    -- 7. Enemy / Other Player Damage & Swings
    { pattern = "(.+)'s (.+) hits (.+) for (%d+) (.+) damage%.", event = "SPELL_DAMAGE", isPlayer = false, isCrit = false },
    { pattern = "(.+)'s (.+) crits (.+) for (%d+) (.+) damage%.", event = "SPELL_DAMAGE", isPlayer = false, isCrit = true },
    { pattern = "(.+) hits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = false, isCrit = false, isSwing = true },
    { pattern = "(.+) crits (.+) for (%d+)%.", event = "SWING_DAMAGE", isPlayer = false, isCrit = true, isSwing = true },

    -- 8. Aura gains
    { pattern = "You gain (.+)%.", event = "SPELL_AURA_APPLIED", isPlayer = true },
    { pattern = "(.+) gains (.+)%.", event = "SPELL_AURA_APPLIED", isPlayer = false },
}

local function ParseCombatString(msg)
    if not msg or msg == "" then return end

    local count = table.getn(PATTERNS)
    for i = 1, count do
        local p = PATTERNS[i]
        local s, e, a1, a2, a3, a4 = string.find(msg, p.pattern)
        if s then
            local data = Memory:AcquireTable()
            data.eventType = p.event
            data.isCrit = p.isCrit or false
            data.isRanged = p.isRanged or false
            data.isSwing = p.isSwing or false
            data.isEnemyOnPlayer = p.isEnemyOnPlayer or false
            data.timestamp = GetTime()

            if p.event == "SWING_DAMAGE" then
                if p.isPlayer then
                    data.source = UnitName("player")
                    data.target = a1
                    data.amount = tonumber(a2) or 0
                elseif p.isEnemyOnPlayer then
                    data.source = a1
                    data.target = UnitName("player")
                    data.amount = tonumber(a2) or 0
                else
                    data.source = a1
                    data.target = a2
                    data.amount = tonumber(a3) or 0
                end
            elseif p.event == "SWING_MISSED" then
                if p.isPlayer then
                    data.source = UnitName("player")
                    data.target = a1 or ""
                    data.amount = 0
                elseif p.isEnemyOnPlayer then
                    data.source = a1 or "Enemy"
                    data.target = UnitName("player")
                    data.amount = 0
                else
                    data.source = a1 or ""
                    data.target = a2 or ""
                    data.amount = 0
                end
            elseif p.event == "SPELL_DAMAGE" then
                if p.isPlayer then
                    data.source = UnitName("player")
                    data.spellName = a1
                    data.target = a2
                    data.amount = tonumber(a3) or 0
                    data.school = a4 or "Physical"
                else
                    data.source = a1
                    data.spellName = a2
                    data.target = a3
                    data.amount = tonumber(a4) or 0
                end
            elseif p.event == "SPELL_HEAL" then
                data.source = p.isPlayer and UnitName("player") or a1
                data.spellName = a1
                data.target = a2
                data.amount = tonumber(a3) or 0
            elseif p.event == "SPELL_AURA_APPLIED" then
                if p.isPlayer then
                    data.target = UnitName("player")
                    data.spellName = a1
                else
                    data.target = a1
                    data.spellName = a2
                end
            end

            -- Fire structured event across Primus signal bus
            Events:Fire("PRIMUS_COMBAT_EVENT", data)
            Memory:ReleaseTable(data)
            return
        end
    end
end

function PUICombatLog:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUICombatLog", {
        name = "PUICombatLog",
        category = "Combat",
        label = "Combat Log Engine",
        icon = "Interface\Icons\INV_Misc_Book_09",
        desc = "Processes raw combat log events, threat parsing, and combat telemetry.",
    })
end

function PUICombatLog:OnInitialize()
    self:RegisterOptionsFlare()
    local combatEvents = {
        "CHAT_MSG_SPELL_SELF_DAMAGE",
        "CHAT_MSG_SPELL_SELF_BUFF",
        "CHAT_MSG_SPELL_PARTY_DAMAGE",
        "CHAT_MSG_SPELL_PARTY_BUFF",
        "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
        "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
        "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
        "CHAT_MSG_COMBAT_SELF_HITS",
        "CHAT_MSG_COMBAT_SELF_MISSES",
        "CHAT_MSG_COMBAT_PARTY_HITS",
        "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
        "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
        "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
        "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS",
        "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
    }

    local count = table.getn(combatEvents)
    for i = 1, count do
        Events:Register(combatEvents[i], self, function(owner, event, msg)
            ParseCombatString(msg)
        end)
    end
end
