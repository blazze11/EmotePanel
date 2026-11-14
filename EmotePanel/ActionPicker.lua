local AddonName, ns = ...
local EmotePanel = ns.panel

local ActionPicker = ns.ActionPicker
local Widgets = ns.Widgets
local Entries = ns.Entries
local Pages = ns.Pages

local hookedMenus = {}

local function GetMenuItemAction(menu)
    local bag, slot = menu:GetBagAndSlot()
    if issecretvalue(bag) or issecretvalue(slot) or type(bag) ~= "number" or type(slot) ~= "number" then return end
    return Entries.GetItemAction(C_Container.GetContainerItemInfo(bag, slot), true)
end

local function HookConsolePortActionMenu(menu, getAction)
    if hookedMenus[menu] or type(menu.AddUtilityRingCommand) ~= "function"
        or type(menu.AddCommand) ~= "function" then return end

    function menu:EmotePanelSetAction(change)
        if InCombatLockdown() then return end
        local key, data = getAction(self)
        if not key or key ~= change.key then return end
        local selected = not Entries.IsEntryHidden("macros", key)
        if selected == change.selected then return end
        EmotePanel:SetActionSelected(key, data, change.selected)
        self:Hide()
    end

    -- ConsolePort sizes and focuses the popup after it adds the ring rows.
    hooksecurefunc(menu, "AddUtilityRingCommand", function(self)
        if InCombatLockdown() then return end
        local key = getAction(self)
        if not key then return end
        local add = Entries.IsEntryHidden("macros", key)
        local label = add and "Add to EmotePanel Actions" or "Remove from EmotePanel Actions"
        self:AddCommand(label, "EmotePanelSetAction", {key = key, selected = add})
    end)
    hookedMenus[menu] = true
end

local function GetMenuSpellAction(menu)
    return Entries.GetSpellAction(menu:GetSpellID())
end

function ActionPicker.HookConsolePortActionMenus()
    if ConsolePortItemMenu and type(ConsolePortItemMenu.GetBagAndSlot) == "function" then
        HookConsolePortActionMenu(ConsolePortItemMenu, GetMenuItemAction)
    end
    if ConsolePortSpellMenu and type(ConsolePortSpellMenu.GetSpellID) == "function" then
        HookConsolePortActionMenu(ConsolePortSpellMenu, GetMenuSpellAction)
    end
end

function ActionPicker.Refresh(kind)
    local picker = _G[AddonName .. "ActionsPanel"]
    if picker and picker:IsVisible() and (not kind or picker.kind == kind) then picker:refresh() end
end

function ActionPicker.Create(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "ActionsPanel", mainPanel)
    panel.name = Pages.ACTIONS_TITLE
    panel.kind = "spell"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(Pages.ACTIONS_TITLE)
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Check an entry to add it to Actions. Uncheck it to remove it from the wheel.")

    local automaticCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    automaticCheck:SetSize(24, 24)
    automaticCheck:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)
    automaticCheck:SetChecked(EmotePanelSavedVars.automaticWheelActions ~= false)
    automaticCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.automaticWheelActions = not not self:GetChecked()
        Pages.HandleAutomaticActionsChanged()
    end)
    local automaticLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    automaticLabel:SetPoint("LEFT", automaticCheck, "RIGHT", 4, 0)
    automaticLabel:SetText("Automatic quest items and abilities")
    Widgets.AddSettingsTooltip(automaticCheck, "Automatic quest items and abilities",
        "Add tracked quest items, temporary abilities, and Leave Group when grouped.", automaticLabel)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    local rows, tabs = {}, {}
    local function SelectSource(index)
        local source = tabs[index]
        if panel.kind == source.kind then return end
        panel.kind = source.kind
        scroll:SetVerticalScroll(0)
        panel:refresh()
        local first = rows[1]
        EmotePanel.settingsWindow:FocusEntry(panel, first and first:IsShown() and first or source.button)
        Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
    end
    function panel:StepActionSource(direction)
        for index, source in ipairs(tabs) do
            if source.kind == self.kind then
                SelectSource((index - 1 + direction) % #tabs + 1)
                return
            end
        end
    end

    local highestRank = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    highestRank:SetSize(24, 24)
    highestRank:SetPoint("TOPLEFT", automaticCheck, "BOTTOMLEFT", 0, -4)
    local highestRankLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    highestRankLabel:SetPoint("LEFT", highestRank, "RIGHT", 4, 0)
    highestRankLabel:SetText("Highest learned rank only")
    Widgets.AddSettingsTooltip(highestRank, "Highest learned rank only",
        "Hide lower ranks from this list. Manage ranks already on the wheel under Entries.", highestRankLabel)
    highestRank:SetScript("OnClick", function(self)
        EmotePanelSavedVars.highestSpellRankOnly = not not self:GetChecked()
        scroll:SetVerticalScroll(0)
        panel:refresh()
    end)
    for index, tab in ipairs({
        {"spell", "Abilities", "Choose learned spells for the Actions wheel."},
        {"item", "Items", "Choose carried or equipped items for the Actions wheel."},
        {"macro", "Macros", "Choose saved account or character macros for the Actions wheel."},
    }) do
        local kind, label, tooltip = unpack(tab)
        local button = Widgets.CreateRedButton(panel, label)
        button:SetSize(96, 25)
        button:SetDisabledFontObject(GameFontDisable)
        Widgets.AddSettingsTooltip(button, label, tooltip)
        if index > 1 then button:SetPoint("LEFT", tabs[index - 1].button, "RIGHT", 6, 0) end
        button:SetScript("OnClick", function() SelectSource(index) end)
        tabs[#tabs + 1] = { kind = kind, button = button }
    end
    local headerAnchor
    scroll:SetPoint("TOPLEFT", tabs[1].button, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)

    local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 0, -6)
    empty:SetText("No entries available.")

    function panel:refresh()
        automaticCheck:SetChecked(EmotePanelSavedVars.automaticWheelActions ~= false)
        local showRanks = self.kind == "spell"
        highestRank:SetShown(showRanks)
        highestRankLabel:SetShown(showRanks)
        highestRank:SetChecked(EmotePanelSavedVars.highestSpellRankOnly ~= false)
        local anchor = showRanks and highestRank or automaticCheck
        if headerAnchor ~= anchor then
            headerAnchor = anchor
            tabs[1].button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
        end
        for _, tab in ipairs(tabs) do
            if tab.kind == self.kind then tab.button:LockHighlight() else tab.button:UnlockHighlight() end
        end
        local choices = Entries.GetActionChoices(self.kind)
        local width = scroll:GetWidth()
        content:SetSize(width, math.max(28, #choices * 28))
        empty:SetShown(#choices == 0)
        for index, choice in ipairs(choices) do
            local row = rows[index]
            if not row then
                row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                row:SetSize(24, 24)
                row.orderY = (index - 1) * 28
                row:SetPoint("TOPLEFT", 0, -row.orderY)
                row.icon = Widgets.CreateListIcon(row, row, "RIGHT")
                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.label:SetJustifyH("LEFT")
                row.label:SetWordWrap(false)
                Widgets.AddSettingsTooltip(row, "Actions", "Click to add or remove. Right-click an added action to edit it.")
                row.settingsFocusText = row.label
                function row:CanEditSetting() return self:GetChecked() end
                Widgets.SetEntryEdit(row, function(self)
                    local entry = self.choice
                    EmotePanel:EditButton("macros", entry.key, entry.data, true)
                end)
                row:SetScript("OnClick", function(button)
                    local entry = button.choice
                    EmotePanel:SetActionSelected(entry.key, entry.data, button:GetChecked())
                end)
                rows[index] = row
            end
            row.choice = choice
            row:SetHitRectInsets(0, math.min(0, 24 - width), 0, 0)
            row.label:SetWidth(math.max(1, width - 64))
            row:SetChecked(not Entries.IsEntryHidden("macros", choice.key))
            Widgets.SetIconTexture(row.icon, Entries.GetEntryIcon("macros", choice.key, choice.data))
            local name = choice.name
            row.settingsFocusLabel = name:gsub("|", "||")
            if self.kind == "macro" then
                name = name .. "  ·  " .. choice.data.preview
            elseif self.kind == "item" and Entries.GetEntryData("macros", choice.key) and not Entries.IsActionItemCarried(choice.data.actionID) then
                name = name .. "  ·  Not carried"
            end
            row.label:SetText(name:gsub("|", "||"))
            row:Show()
        end
        for index = #choices + 1, #rows do rows[index]:Hide() end
    end
    panel:SetScript("OnShow", panel.refresh)
    scroll:HookScript("OnSizeChanged", function()
        if panel:IsVisible() then panel:refresh() end
    end)
    return panel
end
