--[[
    PrimusUI: PUIRoleplay GameTooltip RP Enhancer (PUITooltip.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (PUITooltip Unit Provider Integration)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Tooltip = {}
PUIRoleplay.Tooltip = Tooltip

--------------------------------------------------------------------------------
-- Provider Registration
--------------------------------------------------------------------------------
function Tooltip:Initialize()
    local PUITooltip = Primus.PUITooltip
    if PUITooltip and PUITooltip.RegisterUnitProvider then
        PUITooltip:RegisterUnitProvider("PUIRoleplay", 1, function(tt, unit, unitName, isPlayer)
            if isPlayer then
                Tooltip:EnhancePlayerTooltip(tt, unit, unitName)
            end
        end)
    end
end

function Tooltip:Disable()
    local PUITooltip = Primus.PUITooltip
    if PUITooltip and PUITooltip.UnregisterUnitProvider then
        PUITooltip:UnregisterUnitProvider("PUIRoleplay")
    end
end

--------------------------------------------------------------------------------
-- Format & Inject RP Metadata into Tooltip
--------------------------------------------------------------------------------
function Tooltip:EnhancePlayerTooltip(tooltip, unit, playerName)
    unit = unit or "mouseover"
    if not UnitIsPlayer(unit) then return end
    
    playerName = playerName or UnitName(unit)
    if not playerName then return end

    local isSelf = (playerName == UnitName("player"))
    local charData = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(playerName)
    
    -- Request fresh M data if missing
    if not isSelf and (not charData or not charData.keyM or not charData.full_name or charData.full_name == "") then
        if PUIRoleplay.Comms and PUIRoleplay.Comms.SendRequest then
            PUIRoleplay.Comms:SendRequest("M", playerName)
        end
    end
    
    if not charData or not charData.keyM then return end
    
    local fullName = charData.full_name or playerName
    local title = charData.title or ""
    local class = charData.class or UnitClass(unit) or ""
    local classColor = charData.class_color or (PUIRoleplay.ClassData and PUIRoleplay.ClassData[class] and PUIRoleplay.ClassData[class][4]) or "FFFFFF"
    local isIC = (charData.currently_ic == "1")
    local icBadge = isIC and "|cff40af6f(IC)|r" or "|cffd3681e(OOC)|r"
    
    -- Pronouns
    local pronouns = isIC and charData.ic_pronouns or charData.ooc_pronouns
    local pronounText = (pronouns and pronouns ~= "") and (" |cffffcc80(" .. pronouns .. ")|r") or ""
    
    -- Format First Line
    local line1 = _G[tooltip:GetName() .. "TextLeft1"]
    if line1 then
        local displayName = "|cff" .. classColor .. fullName .. "|r " .. icBadge .. pronounText
        line1:SetText(displayName)
    end
    
    -- Add RP Title if present
    if title and title ~= "" then
        tooltip:AddLine("<" .. title .. ">", 0.0, 0.8, 1.0)
    end
    
    -- Add IC / OOC Snippets if present
    local icInfo = charData.ic_info
    if icInfo and icInfo ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine("IC Info:", 0.25, 0.75, 0.45)
        tooltip:AddLine(icInfo, 0.85, 0.85, 0.85, true)
    end
    
    local oocInfo = charData.ooc_info
    if oocInfo and oocInfo ~= "" then
        tooltip:AddLine(" ")
        tooltip:AddLine("OOC Info:", 0.85, 0.55, 0.2)
        tooltip:AddLine(oocInfo, 0.85, 0.85, 0.85, true)
    end
    
    tooltip:Show()
end
