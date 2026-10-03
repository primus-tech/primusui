--[[
    PrimusUI: PUIRoleplay World Map Pins Engine (PUIMapPins.lua)
    Target: Vanilla WoW 1.12.1 / Turtle WoW (RP Character World Map Pin Overlays)
    Architecture: Strict TRUTH.md compliance (Zero Aliases, Zero Shims)
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIRoleplay = Primus.PUIRoleplay or {}
Primus.PUIRoleplay = PUIRoleplay

local Directory = PUIRoleplay.Directory or {}
PUIRoleplay.Directory = Directory

local mapPins = {}

--------------------------------------------------------------------------------
-- World Map RP Location Pins
--------------------------------------------------------------------------------
function Directory:UpdateWorldMapPins()
    if not WorldMapFrame or not WorldMapFrame:IsVisible() then return end

    for _, pin in ipairs(mapPins) do
        pin:Hide()
    end

    local mapWidth = WorldMapDetailFrame:GetWidth()
    local mapHeight = WorldMapDetailFrame:GetHeight()
    local curMapZone = GetCurrentMapZone()
    local continent = GetCurrentMapContinent()
    local zones = { GetMapZones(continent) }
    local currentZoneName = zones[curMapZone]

    local allChars = PUIRoleplay:GetAllKnownCharacters()
    local pinCount = 1

    for name, data in pairs(allChars) do
        if name ~= UnitName("player") and data.zoneX and data.zoneY then
            local zX = tonumber(data.zoneX)
            local zY = tonumber(data.zoneY)

            local dZone = PUIRoleplay.Protocols and PUIRoleplay.Protocols.DrunkDecode and PUIRoleplay.Protocols:DrunkDecode(data.zone or "") or (data.zone or "")
            if zX and zY and (dZone == currentZoneName or currentZoneName == "" or not currentZoneName) then
                local pin = mapPins[pinCount]
                if not pin then
                    pin = CreateFrame("Button", nil, WorldMapDetailFrame)
                    pin:SetWidth(16)
                    pin:SetHeight(16)
                    pin:SetFrameStrata("TOOLTIP")

                    local tex = pin:CreateTexture(nil, "ARTWORK")
                    tex:SetAllPoints(pin)
                    tex:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
                    pin.tex = tex

                    pin:SetScript("OnEnter", function()
                        if this.charName then
                            WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
                            WorldMapTooltip:AddLine(this.fullName or this.charName, 0.0, 0.8, 1.0)
                            WorldMapTooltip:AddLine(this.isIC and "Status: In Character (IC)" or "Status: Out of Character (OOC)", 0.8, 0.8, 0.8)
                            WorldMapTooltip:Show()
                        end
                    end)
                    pin:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
                    pin:SetScript("OnClick", function()
                        if this.charName then Directory:ShowPlayerFlyout(this.charName) end
                    end)
                    table.insert(mapPins, pin)
                end

                pin.charName = name
                pin.fullName = data.full_name
                pin.isIC = (data.currently_ic == "1")

                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", zX * mapWidth, -zY * mapHeight)
                pin:Show()

                pinCount = pinCount + 1
            end
        end
    end
end
