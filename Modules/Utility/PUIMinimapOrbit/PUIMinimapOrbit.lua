--[[
    PrimusLib Module: MinimapOrbit (Minimap Button Bag / MBB)
    Target: Vanilla WoW 1.12.1 (Lua 5.0.2)
    
    Discovers, intercepts, and docks scattered 3rd-party minimap buttons
    into a clean, collapsible button drawer.
--]]

local _G = getglobals and getglobals() or _G or getfenv(0)
local Primus = _G.Primus
if not Primus then return end

local PUIMinimapOrbit = Primus.PUIMinimapOrbit or {}
Primus.PUIMinimapOrbit = PUIMinimapOrbit
_G.PUIMinimapOrbit = PUIMinimapOrbit
Primus:RegisterModule("PUIMinimapOrbit", PUIMinimapOrbit, "Utility")

local DB      = Primus.DB
local Widgets = Primus.Widgets
local Media   = Primus.Media
local Utils   = Primus.Utils
local Events  = Primus.Events
local Time    = Primus.Time

local orbitDB = DB:RegisterNamespace("PUIMinimapOrbit", {
    enabled = true,
    collapsed = true,
    layout = "VERTICAL", -- VERTICAL or HORIZONTAL
})

local dockedButtons = {}
local dockFrame = nil
local toggleButton = nil

-- Known button patterns in Vanilla 1.12
local function IsMinimapButton(name, frame)
    if not name or not frame then return false end
    if frame == Minimap or frame == MinimapCluster or frame == toggleButton then return false end

    -- Pattern matching
    local lower = string.lower(name)
    if string.find(lower, "minimap") and (string.find(lower, "button") or string.find(lower, "icon") or string.find(lower, "toggle")) then
        return true
    end

    -- Specific known legacy addon icons
    if name == "FuBarMinimapContainer" or name == "KLHTM_MinimapButton" or 
       name == "Gatherer_MinimapOptionsButton" or name == "WIM_IconFrame" or
       name == "AtlasButton" or name == "CT_RASets_MinimapButton" then
        return true
    end

    return false
end

-- Collect and re-anchor buttons into the dock
function PUIMinimapOrbit:CollectButtons()
    if not dockFrame then return end

    dockedButtons = {}
    for globalName, obj in pairs(_G) do
        if type(obj) == "table" and type(globalName) == "string" and obj.SetPoint then
            if IsMinimapButton(globalName, obj) then
                table.insert(dockedButtons, obj)
            end
        end
    end

    -- Arrange in dock
    local count = table.getn(dockedButtons)
    for i = 1, count do
        local btn = dockedButtons[i]
        btn:ClearAllPoints()
        btn:SetParent(dockFrame)
        if i == 1 then
            btn:SetPoint("TOPLEFT", dockFrame, "TOPLEFT", 4, -4)
        else
            btn:SetPoint("TOP", dockedButtons[i - 1], "BOTTOM", 0, -4)
        end
    end

    dockFrame:SetHeight(math.max(30, count * 36 + 8))
end

function PUIMinimapOrbit:RegisterOptionsFlare()
    if not Primus.Options or not Primus.Options.RegisterModuleOptions then return end
    Primus.Options:RegisterModuleOptions("PUIMinimapOrbit", {
        name = "PUIMinimapOrbit",
        category = "Utility",
        label = "Minimap Orbit",
        icon = "Interface\Icons\INV_Misc_Compass_01",
        desc = "Consolidates add-on minimap buttons into a sleek expandable orbit pill.",
    })
end

function PUIMinimapOrbit:OnInitialize()
    self:RegisterOptionsFlare()
    -- Create the Main Orbit Toggle Button on Minimap
    toggleButton = CreateFrame("Button", "Primus_MinimapOrbitBtn", Minimap)
    toggleButton:SetWidth(24)
    toggleButton:SetHeight(24)
    toggleButton:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
    toggleButton:SetBackdrop(Media:Fetch("border", "1Pixel"))
    toggleButton:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
    toggleButton:SetBackdropBorderColor(0.3, 0.6, 1.0, 1.0)

    local icon = toggleButton:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    icon:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Create Dock Container Frame
    dockFrame = CreateFrame("Frame", "Primus_MinimapOrbitDock", toggleButton)
    dockFrame:SetWidth(36)
    dockFrame:SetHeight(100)
    dockFrame:SetPoint("TOPRIGHT", toggleButton, "BOTTOMRIGHT", 0, -5)
    dockFrame:SetBackdrop(Media:Fetch("border", "1Pixel"))
    dockFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    dockFrame:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    dockFrame:Hide()

    toggleButton:SetScript("OnClick", function()
        if dockFrame:IsShown() then
            dockFrame:Hide()
        else
            PUIMinimapOrbit:CollectButtons()
            dockFrame:Show()
        end
    end)

    -- Delayed scan after all addons finish loading
    Time:After(3.0, function()
        if orbitDB:Get("enabled") then
            PUIMinimapOrbit:CollectButtons()
        end
    end)
end
