local AddonName, ns = ...
-- Other TOC files attach methods and module interfaces before ADDON_LOADED.
local EmotePanel = {}
ns.panel = EmotePanel
_G[AddonName] = EmotePanel
ns.Widgets = {}
ns.Entries = {}
ns.Pages = {}
ns.Bindings = {}
ns.Wheel = {}
ns.Input = {}
ns.CombatWheel = {}
ns.SettingsUI = {}
ns.ActionPicker = {}

local Widgets = ns.Widgets
local Entries = ns.Entries
local Pages = ns.Pages
local Wheel = ns.Wheel
local collectionEvents = {
    COMPANION_LEARNED = "mount",
    COMPANION_UNLEARNED = "mount",
    PET_JOURNAL_LIST_UPDATE = "companion",
    TOYS_UPDATED = "toy",
}
local collectionsDirty
local Input = ns.Input
local CombatWheel = ns.CombatWheel
local SettingsUI = ns.SettingsUI
local ActionPicker = ns.ActionPicker

ns.version = C_AddOns.GetAddOnMetadata(AddonName, "Version") or "Unknown"
ns.SECTOR_COUNT = 8
local LAUNCHER_ICON = "gamepad-radial-icon-chat"

function EmotePanel:Initialize()
    Entries.InitializeSavedEntries()
    Input.InitializeRepeatTiming()
    local class = UnitClassBase("player")
    self.supportsPetWheel = not issecretvalue(class) and (class == "HUNTER" or class == "WARLOCK")
    Pages.Initialize()
    self:InitializeWheel()
    ns.Profiles.InitializeWhenReady()
end

function EmotePanel_Toggle()
    EmotePanel:ToggleWheel(false)
end

local function UseLauncher(mouseButton)
    if mouseButton ~= "RightButton" and EmotePanel.settingsCategoryID then
        SettingsUI.ToggleSettings()
    end
end

-- Blizzard registers this callback from the TOC when populating the Addon Compartment.
function EmotePanel_OnAddonCompartmentClick(_, mouseButton)
    UseLauncher(mouseButton)
end

local function CreateMinimapButton()
    local minimap = Minimap
    if not minimap then return end

    local button = CreateFrame("Button", "EmotePanelMinimapButton", minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    local icon = Widgets.AddAtlas(button, LAUNCHER_ICON, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function SetPosition(angle)
        local radiusX, radiusY = minimap:GetWidth() / 2, minimap:GetHeight() / 2
        button:ClearAllPoints()
        button:SetPoint("CENTER", minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
    end
    function EmotePanel:RefreshMinimapPosition()
        local angle = EmotePanelSavedVars.minimapAngle
        SetPosition(type(angle) == "number" and angle or math.rad(225))
    end
    EmotePanel:RefreshMinimapPosition()

    local function DragButton()
        local centerX, centerY = minimap:GetCenter()
        if not centerX then return end
        local x, y = InputUtil.GetCursorPosition(minimap)
        local newAngle = math.atan2(y - centerY, x - centerX)
        EmotePanelSavedVars.minimapAngle = newAngle
        SetPosition(newAngle)
    end
    local function StopDragging()
        button:SetScript("OnUpdate", nil)
    end
    local function HideTooltip()
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end
    button:SetScript("OnDragStart", function()
        HideTooltip()
        button:SetScript("OnUpdate", DragButton)
    end)
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnClick", function(_, mouseButton) UseLauncher(mouseButton) end)
    button:SetScript("OnEnter", function()
        if button:GetScript("OnUpdate") then return end
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("EmotePanel v" .. ns.version)
        GameTooltip:AddLine("Left-click to open or close settings.")
        GameTooltip:AddLine("Use your Wheel Keybind to open the wheel. Drag to move.")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", function()
        StopDragging()
        HideTooltip()
    end)
end

local function HandleSlashCommand(msg)
    local command, option = string.match(msg, "^%s*(%S*)%s*(%S*)")
    command = command:lower()
    if command == "debug" then
        option = option:lower()
        if option == "on" or option == "off" then
            EmotePanel.combatDebug = option == "on"
        elseif option ~= "" then
            Widgets.ShowError("Use /ep debug for status, /ep debug on to start, or /ep debug off to stop.")
            return
        end
        if EmotePanel.combatDebug then
            local input = EmotePanel.combatInput
            local page = input and input:IsShown() and EmotePanel.combatPages[input:GetAttribute("page")]
            EmotePanel:CombatDebug("Status", "on", "combat " .. tostring(InCombatLockdown()),
                EmotePanel.combatBindingReady and "keybind ready" or "keybind missing",
                page and page.title or "wheel closed")
        else
            print("EmotePanel combat debug off.")
        end
        return
    end
    if EmotePanel.combatView then
        Widgets.ShowError("Use the wheel keybind to close the combat wheel first.")
        return
    end
    if InCombatLockdown() and (command == "" or command == "config" or command == "setup" or command == "list" or command == "actions"
        or command == "categories" or command == "profiles" or command == "help" or command == "scroll" or command == "new") then
        Widgets.ShowError("Settings are unavailable in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
        return
    end

    if command == "help" or command == "scroll" then
        SettingsUI.OpenSettings("guide")
    elseif command == "new" then
        SettingsUI.OpenSettings("new")
    elseif command == "list" then
        SettingsUI.OpenSettings("help")
        if EmotePanel.settingsWindow:IsShown() then EmotePanelHelpPanel:SelectSection("favorites") end
    elseif command == "" then
        SettingsUI.ToggleSettings()
    elseif command == "config" then
        SettingsUI.OpenSettings()
    elseif command == "setup" then
        SettingsUI.OpenWheelBindingSetup()
    elseif command == "actions" then
        SettingsUI.OpenSettings("actions")
    elseif command == "profiles" then
        SettingsUI.OpenSettings("profiles")
    elseif command == "categories" then
        SettingsUI.OpenSettings("categories")
    elseif command == "reset" then
        SettingsUI.ConfirmResetToDefaults()
    else
        Widgets.ShowError("Unknown command. Open /ep help to see available commands.")
    end
end

-- Register slash commands
SLASH_EMOTEPANEL1 = "/emotepanel"
SLASH_EMOTEPANEL2 = "/ep"
SlashCmdList["EMOTEPANEL"] = HandleSlashCommand

local function InitializeAddon(eventFrame)
    EmotePanel:Initialize()
    EmotePanel.optionsPanel = SettingsUI.CreateInterfaceOptions()
    CreateMinimapButton()
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    ActionPicker.HookConsolePortActionMenus()
    eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("SPELL_TEXT_UPDATE")
    eventFrame:RegisterEvent("SPELL_UPDATE_ICON")
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    eventFrame:RegisterUnitEvent("UNIT_QUEST_LOG_CHANGED", "player")
    eventFrame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("UPDATE_MACROS")
    for event in pairs(collectionEvents) do eventFrame:RegisterEvent(event) end
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    eventFrame:RegisterEvent("SPELL_UPDATE_USES")
    eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    for castEvent in pairs(Wheel.CAST_EVENTS) do eventFrame:RegisterUnitEvent(castEvent, "player") end
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    eventFrame:RegisterEvent("UI_SCALE_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
    eventFrame:RegisterEvent("CVAR_UPDATE")
    eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    if EmotePanel.supportsPetWheel then
        eventFrame:RegisterEvent("PET_STABLE_SHOW")
        eventFrame:RegisterEvent("PET_STABLE_UPDATE")
        eventFrame:RegisterEvent("PET_BAR_UPDATE")
        eventFrame:RegisterEvent("PET_ORDER_MOVE_TO_PENDING_CHANGED")
        eventFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("PET_BAR_UPDATE_USABLE")
        eventFrame:RegisterEvent("PET_UI_UPDATE")
        eventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
        eventFrame:RegisterEvent("UNIT_PET")
        eventFrame:RegisterEvent("UNIT_FLAGS")
    end
    if not InCombatLockdown() then EmotePanel:SetupGamepad() end

    print(("|cFF00FF00EmotePanel v%s|r loaded. Type |cFFFFFF00/ep help|r for help or |cFFFFFF00/ep new|r for release notes."):format(ns.version))
end

-- Event handling
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGOUT" then
        ns.Profiles.SaveActive()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        CombatWheel.ReportRestriction(event, ...)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_DISABLED" then
            local confirmation = Widgets.GetConfirmation()
            if confirmation then StaticPopup_Hide(confirmation.which) end
            SettingsUI.SuspendForCombat()
        end
        Input.HandleCombatTransition(event)
        if event == "PLAYER_REGEN_ENABLED" then
            if not ns.Profiles.ready then ns.Profiles.InitializeWhenReady() end
            SettingsUI.CheckLoginBindingWarning()
            if collectionsDirty then
                collectionsDirty = nil
                EmotePanel:RefreshCurrentEntryPages()
            end
            Pages.HandleAutomaticActionsChanged()
            SettingsUI.RestoreAfterCombat()
        end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        if EmotePanelSavedVars.followCursorCenter then EmotePanel:LoadPosition() end
        local settings = EmotePanel.settingsWindow
        if settings:IsShown() then settings:FitToScreen() end
        Wheel.HandleDisplayChanged()
    elseif event == "UPDATE_BINDINGS" or event == "GAME_PAD_ACTIVE_CHANGED" then
        if event == "UPDATE_BINDINGS" then
            ns.Profiles.InitializeWhenReady()
            SettingsUI.CheckLoginBindingWarning()
        end
        EmotePanel:RefreshWheelFooter()
        EmotePanel:RefreshGamepadHint()
        EmotePanel:SyncCombatWheel(true)
        if EmotePanel.optionsPanel then EmotePanel.optionsPanel:RefreshWheelBindings() end
    elseif event == "CVAR_UPDATE" then
        local name = ...
        if name and name:lower() == "cursorcenteredypos" and EmotePanelSavedVars.followCursorCenter then
            EmotePanel:LoadPosition()
            EmotePanel.customizationPanel:refreshPosition()
        elseif name == "GamePadEnable" or name == "InputDeviceInterfaceStyle" then
            EmotePanel.optionsPanel:RefreshControllerSetup()
            EmotePanel:RefreshWheelFooter()
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        Pages.HandleCarriedItemsChanged()
        if event == "BAG_UPDATE_DELAYED" then Pages.HandleAutomaticActionsChanged() end
    elseif event == "SPELL_TEXT_UPDATE" then
        ActionPicker.Refresh("spell")
        SettingsUI.RefreshEntryList()
    elseif event == "SPELL_UPDATE_ICON" or event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW" then
        if EmotePanel.frame:IsShown() then EmotePanel:RefreshSpellIcons() end
        ActionPicker.Refresh("spell")
        SettingsUI.RefreshEntryList()
    elseif event == "SPELLS_CHANGED" then
        Entries.ReadActions()
        ActionPicker.Refresh("spell")
        EmotePanel:RefreshCurrentEntryPages()
        Pages.HandleAutomaticActionsChanged()
    elseif event == "QUEST_WATCH_LIST_CHANGED" or event == "QUEST_DATA_LOAD_RESULT" or event == "UNIT_QUEST_LOG_CHANGED"
        or event == "UPDATE_EXTRA_ACTIONBAR" or event == "ACTIONBAR_SLOT_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        Pages.HandleAutomaticActionsChanged()
    elseif event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "PET_ORDER_MOVE_TO_PENDING_CHANGED"
        or (event == "UNIT_PET" and ... == "player") or (event == "UNIT_FLAGS" and ... == "pet") then
        Pages.HandlePetActionsChanged()
    elseif event == "PET_BAR_UPDATE_USABLE" then
        if EmotePanel.frame:IsShown() and Pages.currentPage.mode == "pet" then EmotePanel:RefreshActionAvailability() end
    elseif event == "SPELL_UPDATE_USABLE" then
        if EmotePanel.frame:IsShown() then EmotePanel:RefreshActionAvailability() end
    elseif Wheel.CAST_EVENTS[event] then
        Wheel.HandleSpellcast(event, ...)
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if EmotePanel.frame:IsShown() then EmotePanel:RefreshSpellFeedback() end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "SPELL_UPDATE_USES"
        or event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_STATE"
        or event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_TARGET_CHANGED" or event == "PET_BAR_UPDATE_COOLDOWN" then
        if EmotePanel.frame:IsShown() then
            EmotePanel:RefreshActionCooldowns()
            if event == "PLAYER_TARGET_CHANGED" then
                if Pages.currentPage.category == "interactions" or Pages.currentPage.mode == "favorites" then
                    EmotePanel:RefreshWheel()
                end
                EmotePanel:RefreshCombatAppearance()
                EmotePanel:RefreshSelectedActionFeedback()
                EmotePanel:RefreshActionAvailability()
                EmotePanel:RefreshGamepadHint()
            end
        end
    elseif collectionEvents[event] then
        if InCombatLockdown() or EmotePanel.combatView then
            collectionsDirty = true
        else
            EmotePanel:RefreshCurrentEntryPages()
            ActionPicker.Refresh(collectionEvents[event])
            SettingsUI.RefreshEntryList()
        end
    elseif event == "UPDATE_MACROS" then
        Entries.HandleMacrosChanged()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" and not Entries.HasCharacter() then
            Entries.ReadActions()
            EmotePanel:RefreshEntryPages()
        end
        EmotePanel:RefreshGroupEntries()
        if EmotePanel.frame:IsShown() and (Pages.currentPage.category == "interactions" or Pages.currentPage.mode == "favorites") then
            EmotePanel:RefreshWheel()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            if not ns.Profiles.ready then ns.Profiles.InitializeWhenReady() end
            Pages.HandleAutomaticActionsChanged()
            EmotePanel:SyncCombatWheel(true)
            local initialLogin, reloadingUI = ...
            if initialLogin or reloadingUI then SettingsUI.ShowLoginWarnings()
            else SettingsUI.CheckLoginBindingWarning() end
        end
    elseif event == "SKILL_LINES_CHANGED" then
        Pages.HandleProfessionsChanged()
    elseif event == "ADDON_LOADED" and select(1, ...) == "ConsolePort_Cursor" and EmotePanel.frame then
        if EmotePanel.frame:IsVisible() then Input.SetConsolePortCursorObstructed(EmotePanel.frame, true) end
        if EmotePanel.settingsWindow:IsVisible() then Input.SetConsolePortCursorObstructed(EmotePanel.settingsWindow, true) end
    elseif event == "ADDON_LOADED" and select(1, ...) == "ConsolePort_Menu" and EmotePanel.frame then
        ActionPicker.HookConsolePortActionMenus()
    elseif event == "ADDON_LOADED" and select(1, ...) == AddonName then
        InitializeAddon(self)
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
