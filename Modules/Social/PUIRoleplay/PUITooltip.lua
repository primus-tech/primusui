--[[
    PrimusUI: PUIRoleplay GameTooltip RP Enhancer (PUITooltip.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (Non-Intrusive Tooltip Injection)
--]]

local Primus = _G.Primus
local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Tooltip = {}
PUIRoleplay.Tooltip = Tooltip

--------------------------------------------------------------------------------
-- Tooltip Script Hooking
--------------------------------------------------------------------------------
function Tooltip:Initialize()
    local oldOnShow = GameTooltip:GetScript("OnShow")
    GameTooltip:SetScript("OnShow", function()
        if oldOnShow then oldOnShow() end
        if UnitIsPlayer("mouseover") then
            Tooltip:EnhancePlayerTooltip("mouseover")
        end
    end)
end

--------------------------------------------------------------------------------
-- Format & Inject RP Metadata into GameTooltip
--------------------------------------------------------------------------------
function Tooltip:EnhancePlayerTooltip(unit)
    if not UnitIsPlayer(unit) then return end
    
    local playerName = UnitName(unit)
    local isSelf = (playerName == UnitName("player"))
    local charData = isSelf and PUIRoleplay:GetMyProfile() or PUIRoleplay:GetCharacterData(playerName)
    
    -- Request fresh M data if another player
    if not isSelf then
        PUIRoleplay.Comms:SendRequest("M", playerName)
    end
    
    if not charData or not charData.keyM then return end
    
    local fullName = charData.full_name or playerName
    local title = charData.title or ""
    local class = charData.class or UnitClass(unit) or ""
    local classColor = charData.class_color or (PUIRoleplay.ClassData[class] and PUIRoleplay.ClassData[class][4]) or "FFFFFF"
    local isIC = (charData.currently_ic == "1")
    local icBadge = isIC and "|cff40af6f(IC)|r" or "|cffd3681e(OOC)|r"
    
    -- Pronouns
    local pronouns = isIC and charData.ic_pronouns or charData.ooc_pronouns
    local pronounText = (pronouns and pronouns ~= "") and (" |cffffcc80(" .. pronouns .. ")|r") or ""
    
    -- Format First Line
    local line1 = getglobal("GameTooltipTextLeft1")
    if line1 then
        local displayName = "|cff" .. classColor .. fullName .. "|r " .. icBadge .. pronounText
        line1:SetText(displayName)
    end
    
    -- Add RP Title if present
    if title and title ~= "" then
        GameTooltip:AddLine("<" .. title .. ">", 0.0, 0.8, 1.0)
    end
    
    -- Add IC / OOC Snippets if present
    local icInfo = charData.ic_info
    if icInfo and icInfo ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("IC Info:", 0.25, 0.75, 0.45)
        GameTooltip:AddLine(icInfo, 0.85, 0.85, 0.85, true)
    end
    
    local oocInfo = charData.ooc_info
    if oocInfo and oocInfo ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("OOC Info:", 0.85, 0.55, 0.2)
        GameTooltip:AddLine(oocInfo, 0.85, 0.85, 0.85, true)
    end
    
    GameTooltip:Show()
end
