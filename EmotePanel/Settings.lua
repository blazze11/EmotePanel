local AddonName, ns = ...
local EmotePanel = ns.panel

local Widgets = ns.Widgets
local ActionPicker = ns.ActionPicker
local Entries = ns.Entries
local Pages = ns.Pages
local Wheel = ns.Wheel
local Input = ns.Input
local SettingsUI = ns.SettingsUI

local function OpenSettings(page)
    local window = EmotePanel.settingsWindow
    if not window or EmotePanel.combatView or InCombatLockdown() then return end
    EmotePanel.frame:Hide()
    if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    window:SelectPage(page or "general")
    window:Show()
end

local function CycleSetting(values, current, direction)
    for index, value in ipairs(values) do
        if value == current then return values[(index - 1 + direction) % #values + 1] end
    end
    return values[1]
end

local function GetVisibleEntryList()
    local panel = _G[AddonName .. "HelpPanel"]
    if panel and panel:IsVisible() then return panel end
end

local function RefreshEntryList()
    local panel = GetVisibleEntryList()
    if panel then panel:refresh() end
end

local function RefreshCategorySettings()
    local panel = _G[AddonName .. "CategoriesPanel"]
    if panel and panel:IsVisible() then panel:refresh() end
end

StaticPopupDialogs["EMOTEPANEL_RESET_ALL"] = {
    text = "Reset custom icons, names, and text on wheel entries?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        EmotePanelSavedVars.customMessages = {}
        EmotePanelSavedVars.customButtonNames = {}
        EmotePanelSavedVars.customIcons = {}
        RefreshCategorySettings()

        if EmotePanel.frame and EmotePanel.frame:IsShown() then
            EmotePanel:RefreshWheel()
        end

        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsShown() then
            helpPanel:refresh()
        end

        print("|cFF00FF00EmotePanel:|r Wheel entry overrides reset.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_RESET_SETTINGS"] = {
    text = "%s",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(_, reset) reset() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_REMOVE_FROM_GROUP"] = {
    text = "Remove %s from your group?",
    button1 = "Remove",
    button2 = "Cancel",
    OnAccept = function(_, remove) remove() end,
    timeout = 0,
    hideOnEscape = true,
    preferredIndex = 3,
}

local GAMEPAD_DISABLED_TIP = "Enable WoW controller input with /console GamePadEnable 1."
local GAMEPAD_BETA_TIP = "Gamepad (Beta) is unsupported. Turn off Enable Gamepad UI in Options > Gameplay > Gamepad."

local function HasGamepadWheelBinding(pet)
    for slot = 1, 2 do
        local key = EmotePanel:GetWheelBinding(slot, pet)
        if key and IsBindingForGamePad(key) then return true end
    end
    return false
end

local function ShowLoginWarnings()
    if not EmotePanel:HasWheelBinding() then
        UIErrorsFrame:AddExternalWarningMessage("No wheel keybind is set. Assign one under Controller Setup in /ep config.")
    end

    if not C_CVar.GetCVarBool("GamePadEnable")
        and (HasGamepadWheelBinding() or (EmotePanel.supportsPetWheel and HasGamepadWheelBinding(true))) then
        UIErrorsFrame:AddExternalWarningMessage(GAMEPAD_DISABLED_TIP)
    end
    if InputUtil.IsGamepadUIEnabled() then
        UIErrorsFrame:AddExternalWarningMessage(GAMEPAD_BETA_TIP)
    end
end

local resetOnLogout

local function CreateHelpPanel(mainPanel)
    local helpPanel = CreateFrame("Frame", AddonName .. "HelpPanel", mainPanel)
    helpPanel.name = "Entries"

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    helpTitle:SetPoint("TOPLEFT", 16, -16)
    helpTitle:SetText("Wheel Entry List")

    local section = "favorites"
    local listModes = { "favorites", "macros", unpack(Pages.categoryOrder) }
    table.insert(listModes, "professions")
    if EmotePanel.supportsPetWheel then table.insert(listModes, "pet") end
    local sectionPicker = CreateFrame("DropdownButton", AddonName .. "EntrySection", helpPanel, "WowStyle1DropdownTemplate")
    sectionPicker:SetWidth(168)
    sectionPicker:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -10)
    Widgets.AddSettingsTooltip(sectionPicker, "Entry section", "Choose which group of wheel entries to view or edit.")
    sectionPicker:SetupMenu(function(_, root)
        for _, mode in ipairs(listModes) do
            local name = mode == "macros" and Pages.ACTIONS_TITLE
                or mode == "pet" and Pages.PET_TITLE
                or mode == "voicedEmotes" and Entries.voicedEmoteTitle or mode == "professions" and Pages.professionPage.title
                or mode == "favorites" and "Favorites" or Entries.PANEL_MODES[mode].title
            root:CreateRadio(name, function(value) return section == value end, function(value) helpPanel:SelectSection(value) end, mode)
        end
    end)
    function sectionPicker:StepSetting(direction)
        helpPanel:SelectSection(CycleSetting(listModes, section, direction))
    end

    local sectionAction = Widgets.CreateRedButton(helpPanel, "Choose Actions")
    sectionAction:SetSize(112, 24)
    sectionAction:SetPoint("TOPLEFT", sectionPicker, "BOTTOMLEFT", 0, -8)
    Widgets.AddSettingsTooltip(sectionAction, "Manage entries", "Add a custom entry to this section or choose spells, items, and macros for Actions.")
    sectionAction:SetScript("OnClick", function()
        if section == "macros" then
            OpenSettings("actions")
        elseif Entries.customEntryTypes[section] then
            EmotePanel:EditButton(section, nil, nil, true)
        end
    end)
    local resetOrder = Widgets.CreateRedButton(helpPanel, "Reset Order")
    resetOrder:SetSize(100, 24)
    resetOrder:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(resetOrder, "Reset Order", "Restore the selected section's default entry order.")
    resetOrder:SetScript("OnClick", function()
        local target = section
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS", "Restore the default order for this entry section?", function()
            EmotePanelSavedVars.entryOrder[target] = nil
            EmotePanel:RefreshEntryPages()
            helpPanel:refresh()
        end)
    end)
    sectionAction.settingsPeer, resetOrder.settingsPeer = resetOrder, sectionAction
    helpPanel.settingsShortcuts = {PAD3 = sectionAction, PADRSTICK = resetOrder}

    local up = Widgets.CreateRedButton(helpPanel, "Up")
    up:SetSize(48, 24)
    up:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(up, "Move up", "Move the selected entry one place earlier in this section.")
    local down = Widgets.CreateRedButton(helpPanel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(down, "Move down", "Move the selected entry one place later in this section.")
    local edit = Widgets.CreateRedButton(helpPanel, "Edit")
    edit:SetSize(54, 24)
    edit:SetPoint("LEFT", down, "RIGHT", 8, 0)
    edit:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(edit, "Edit selected entry", "Customize the selected entry's icon, text, or wheel placement.")
    local moveHint = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    moveHint:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    moveHint:SetText("Move selected entry")

    local resetBesideAction, moveAnchor
    local function LayoutHeader(showAction, showReset)
        sectionAction:SetShown(showAction)
        resetOrder:SetShown(showReset)
        if resetBesideAction ~= showAction then
            resetBesideAction = showAction
            resetOrder:ClearAllPoints()
            if showAction then
                resetOrder:SetPoint("LEFT", sectionAction, "RIGHT", 8, 0)
            else
                resetOrder:SetPoint("TOPLEFT", sectionAction, "TOPLEFT")
            end
        end
        local anchor = (showAction or showReset) and sectionAction or sectionPicker
        if moveAnchor ~= anchor then
            moveAnchor = anchor
            up:ClearAllPoints()
            up:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        end
    end

    -- Create and store scroll frame reference both locally and globally
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", helpPanel,
        "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -30, 20)

    helpPanel.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    local rows, previousRows = {}, nil
    local listWidth
    scrollFrame.content = content
    scrollFrame:SetScrollChild(content)

    local selectedEntry, selectedRow
    edit:SetScript("OnClick", function()
        if selectedRow then selectedRow:EditSetting() end
    end)
    local function UpdateMoveButtons()
        up:SetEnabled(selectedRow ~= nil and selectedRow.previousID ~= nil)
        down:SetEnabled(selectedRow ~= nil and selectedRow.nextID ~= nil)
        edit:SetEnabled(selectedRow ~= nil)
    end
    UpdateMoveButtons()

    function helpPanel:ClearSelection()
        if not selectedRow then return end
        selectedRow.selection:Hide()
        selectedEntry, selectedRow = nil, nil
        UpdateMoveButtons()
    end

    local function ScrollToRow(row)
        local offset, height = scrollFrame:GetVerticalScroll(), scrollFrame:GetHeight()
        local top = row.orderY
        local bottom = top + row:GetHeight()
        if top < offset then
            scrollFrame:SetVerticalScroll(top)
        elseif bottom > offset + height then
            scrollFrame:SetVerticalScroll(bottom - height)
        end
    end
    local function MoveSelected(neighbor)
        if not neighbor or not selectedRow:move(neighbor) then return end
        helpPanel:refresh()
        if selectedRow then ScrollToRow(selectedRow) end
    end
    up:SetScript("OnClick", function() MoveSelected(selectedRow and selectedRow.previousID) end)
    down:SetScript("OnClick", function() MoveSelected(selectedRow and selectedRow.nextID) end)

    local favoriteRows = {}
    local function CreateSelectableRow(move)
        local row = CreateFrame("Button", nil, content)
        row.move = move
        row.selection = Widgets.CreateSettingsHighlight(row, true)
        row.selection:SetAllPoints()
        row:SetHighlightAtlas(Widgets.FOCUS_ATLAS)
        row:GetHighlightTexture():SetAlpha(0.35)
        row.favorite = Widgets.AddAtlas(row, "collections-icon-favorites", "OVERLAY")
        row.favorite:SetSize(16, 16)
        row.favorite:SetPoint("RIGHT", -6, 0)
        row:SetScript("OnClick", function()
            if selectedRow == row then
                helpPanel:ClearSelection()
            else
                helpPanel:ClearSelection()
                selectedEntry, selectedRow = row.favoriteEntry or row, row
                row.selection:Show()
                UpdateMoveButtons()
            end
            EmotePanel.settingsWindow:FocusEntry(helpPanel, nil)
        end)
        function row:MoveSetting(step)
            local neighbor = step < 0 and self.previousID or step > 0 and self.nextID or nil
            local destination = self.favoriteEntry and favoriteRows[self.favoritePosition + step] or self
            if not neighbor or not self:move(neighbor) then return end
            helpPanel:refresh()
            EmotePanel.settingsWindow:FocusEntry(helpPanel, destination)
            return true
        end
        return row
    end

    local function PlaceOrderRow(row, width, y, previousID, nextID)
        row.previousID, row.nextID = previousID, nextID
        row.orderY = y
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        local isSelected = selectedEntry == (row.favoriteEntry or row)
        row.selection:SetShown(isSelected)
        if isSelected then selectedRow = row end
    end

    local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 4, -8)

    local function CreateFavoriteRow()
        local row = CreateSelectableRow(function(self, neighbor)
            local entry = self.favoriteEntry
            if not Entries.MoveFavorite(entry, neighbor) then return false end
            Pages.RefreshVisibleFavorites()
            EmotePanel:ShowStartPage()
            return true
        end)
        row.icon = Widgets.CreateListIcon(row, row, "LEFT")
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(true)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        Widgets.AddSettingsTooltip(row, "Favorite", "Click to select. Right-click to edit.")
        Widgets.SetEntryEdit(row, function()
            local entry = row.favoriteEntry
            local data = Entries.GetEntryData(entry.mode, entry.index)
            if data then EmotePanel:EditButton(entry.mode, entry.index, data, true, "favorites") end
        end)
        function row:GetCustomEntry()
            local entry = self.favoriteEntry
            return entry.mode, entry.index, Entries.GetEntryData(entry.mode, entry.index)
        end
        return row
    end

    local function RefreshFavoriteRows(width)
        local entries, labels, icons = {}, {}, {}
        for _, entry in ipairs(Entries.GetFavorites()) do
            local mode, index = entry.mode, entry.index
            local data = Entries.GetEntryData(mode, index)
            if data and (mode ~= "panels" or Entries.IsEntryAvailable(data)) then
                entries[#entries + 1] = entry
                local preview = Entries.GetEntryPreview(mode, index, data):gsub("\n", " · ")
                local name = Entries.GetEntryName(mode, index, data)
                labels[#entries] = (preview ~= "" and name .. "  ·  " .. preview or name):gsub("|", "||")
                icons[#entries] = Entries.GetEntryIcon(mode, index, data)
            end
        end

        local y = 0
        empty:SetShown(#entries == 0)
        for position, entry in ipairs(entries) do
            local row = favoriteRows[position]
            if not row then
                row = CreateFavoriteRow()
                favoriteRows[position] = row
            end
            row.favoriteEntry = entry
            row.favoritePosition = position
            PlaceOrderRow(row, width, y, entries[position - 1], entries[position + 1])
            Widgets.SetIconTexture(row.icon, icons[position])
            row.favorite:Show()
            row.name:SetWidth(math.max(1, width - 60))
            row.name:SetText(labels[position])
            row:SetHeight(math.max(28, row.name:GetStringHeight() + 8))
            row:Show()
            y = y + row:GetHeight()
        end
        for position = #entries + 1, #favoriteRows do favoriteRows[position]:Hide() end
        return y + 12
    end

    local function CreateEntryRow(category, mode, index)
        local row = CreateSelectableRow(function(_, neighbor)
            if not Entries.MoveOrderedEntry(category, index, neighbor) then return false end
            EmotePanel:RefreshEntryPages()
            return true
        end)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT")
        Widgets.AddSettingsTooltip(check, "Show on wheel", "Choose whether this entry appears on the wheel.")
        check:SetScript("OnClick", function(self)
            if mode == "macros" then
                EmotePanel:SetActionSelected(index, Entries.GetEntryData(mode, index), self:GetChecked())
            else
                Entries.SaveEntryVisibility(mode, index, self:GetChecked())
                EmotePanel:RefreshEntryPages()
            end
        end)
        row.check = check
        row.icon = Widgets.CreateListIcon(row, check, "RIGHT")
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(true)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        check.settingsFocusText = row.label
        Widgets.AddSettingsTooltip(row, "Wheel entry", "Click to select. Right-click to edit.")
        Widgets.SetEntryEdit(row, function()
            local data = Entries.GetEntryData(mode, index)
            if data then EmotePanel:EditButton(mode, index, data, true, category) end
        end)
        function row:GetCustomEntry()
            return mode, index, Entries.GetEntryData(mode, index)
        end

        return row
    end

    helpPanel.refresh = function()
        local config = Entries.customEntryTypes[section]
        LayoutHeader(section == "macros" or config ~= nil, section ~= "favorites")
        local width = scrollFrame:GetWidth()
        -- The viewport can still be unlaid out when the tab first shows.
        listWidth = width > 0 and width or nil
        if width <= 0 then return end
        selectedRow = nil
        content:SetWidth(width)
        if previousRows then
            for _, row in pairs(previousRows) do row:Hide() end
        end
        sectionAction:SetWidth(config and 206 or 112)
        sectionAction:SetText(config and config.addLabel or "Choose Actions")
        resetOrder:SetEnabled(EmotePanelSavedVars.entryOrder[section] ~= nil)
        empty:SetText(section == "pet" and "Summon a pet with an action bar to edit its entries."
            or "No entries in this section.")
        if section == "favorites" then
            previousRows = favoriteRows
            content:SetHeight(math.max(28, RefreshFavoriteRows(width)))
        else
            local mode = Entries.GetStorageMode(section)
            local sectionRows = rows[section] or {}
            rows[section], previousRows = sectionRows, sectionRows
            local entries = Entries.GetOrderedEntryIDs(section)
            if section == "macros" then
                local enabled = {}
                for _, index in ipairs(entries) do
                    if not Entries.IsEntryHidden(mode, index) then enabled[#enabled + 1] = index end
                end
                entries = enabled
            end
            empty:SetShown(#entries == 0)
            local y = 0
            for position, index in ipairs(entries) do
                local data = Entries.GetEntryData(mode, index)
                local row = sectionRows[index]
                if not row then
                    row = CreateEntryRow(section, mode, index)
                    sectionRows[index] = row
                end
                PlaceOrderRow(row, width, y, entries[position - 1], entries[position + 1])
                Widgets.SetIconTexture(row.icon, Entries.GetEntryIcon(mode, index, data))
                row.favorite:SetShown(Entries.FindFavorite(mode, index) ~= nil)
                row.label:SetWidth(math.max(1, width - 84))
                local preview = Entries.GetEntryPreview(mode, index, data):gsub("\n", " · ")
                local name = Entries.GetEntryName(mode, index, data)
                local label = preview ~= "" and name .. "  ·  " .. preview or name
                row.label:SetText(label:gsub("|", "||"))
                row:SetHeight(math.max(28, row.label:GetStringHeight() + 8))
                row.check:SetChecked(not Entries.IsEntryHidden(mode, index))
                row:Show()
                y = y + row:GetHeight()
            end
            content:SetHeight(math.max(28, y))
        end
        if not selectedRow then selectedEntry = nil end
        UpdateMoveButtons()
        EmotePanel.settingsWindow:RefreshFocusPrompt()
    end
    function helpPanel:SelectSection(mode)
        if section ~= mode then
            section = mode
            selectedEntry = nil
            scrollFrame:SetVerticalScroll(0)
        end
        self:refresh()
        sectionPicker:GenerateMenu()
    end

    helpPanel:SetScript("OnShow", function(self)
        if not EmotePanel.frame:IsShown() then Pages.RefreshProfessions() end
        self:refresh()
    end)
    helpPanel:SetScript("OnHide", function()
        helpPanel:ClearSelection()
        local dialog = EmotePanel.customMessageDialog
        if dialog and dialog.fromSettings then dialog:Hide() end
    end)
    scrollFrame:HookScript("OnSizeChanged", function(_, width)
        if width > 0 and width ~= listWidth and helpPanel:IsVisible() then
            helpPanel:refresh()
        end
    end)

    return helpPanel
end

local function CreateCategoriesPanel(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "CategoriesPanel", mainPanel)
    panel.name = "Categories"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Category Wheel")

    local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    toggle:SetSize(24, 24)
    toggle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    local toggleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    toggleLabel:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    toggleLabel:SetText("Open on Category Wheel")
    Widgets.AddSettingsTooltip(toggle, "Open on Category Wheel", "Start on the category shortcuts. Turn this off to start on Favorites.", toggleLabel)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -10)
    description:SetText("Choose up to eight categories. Select a row to move or edit it.")

    local selected
    local rows = {}
    local up = Widgets.CreateRedButton(panel, "Up")
    up:SetSize(48, 24)
    up:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    up:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(up, "Move up", "Move the selected category one place earlier on the wheel.")
    local down = Widgets.CreateRedButton(panel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(down, "Move down", "Move the selected category one place later on the wheel.")
    local edit = Widgets.CreateRedButton(panel, "Edit")
    edit:SetSize(54, 24)
    edit:SetPoint("LEFT", down, "RIGHT", 8, 0)
    edit:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(edit, "Edit selected category", "Customize the selected category's name, icon, or wheel placement.")
    edit:SetScript("OnClick", function()
        if selected then rows[selected]:EditSetting() end
    end)
    local placement = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    placement:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    local function MoveCategory(category, step)
        if not category or not Pages.IsCategoryWheelEnabled() then return end
        local order = Entries.GetOrderedEntryIDs("categories")
        for position, id in ipairs(order) do
            if id == category and Entries.MoveOrderedEntry("categories", id, order[position + step]) then
                panel:refresh()
                EmotePanel:ShowStartPage()
                return true
            end
        end
    end
    up:SetScript("OnClick", function() MoveCategory(selected, -1) end)
    down:SetScript("OnClick", function() MoveCategory(selected, 1) end)

    local reset = Widgets.CreateRedButton(panel, "Reset Order")
    reset:SetSize(100, 24)
    reset:SetDisabledFontObject(GameFontDisable)
    Widgets.AddSettingsTooltip(reset, "Reset Order", "Restore the stock category order.")
    reset:SetScript("OnClick", function()
        if not Pages.IsCategoryWheelEnabled() then return end
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS", "Restore the default category order?", function()
            EmotePanelSavedVars.entryOrder.categories = nil
            panel:refresh()
            EmotePanel:ShowStartPage()
        end)
    end)
    panel.settingsShortcuts = {PADRSTICK = reset}
    local resetCategories = Widgets.CreateRedButton(panel, "Reset Categories")
    resetCategories:SetSize(128, 24)
    resetCategories:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    Widgets.AddSettingsTooltip(resetCategories, "Reset Categories", "Turn on the Category Wheel and restore its default names, icons, order, and visibility.")
    resetCategories:SetScript("OnClick", function()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS",
            "Turn on Category Wheel and restore its default names, icons, order, and visibility?", function()
                EmotePanelSavedVars.categoryWheel = nil
                EmotePanelSavedVars.hiddenEntries.categories = nil
                EmotePanelSavedVars.entryOrder.categories = nil
                EmotePanelSavedVars.customIcons.categories = nil
                if EmotePanelSavedVars.customButtonNames then EmotePanelSavedVars.customButtonNames.categories = nil end
                panel:refresh()
                EmotePanel:ShowStartPage()
            end)
    end)

    for _, entry in ipairs(Entries.categoryEntries) do
        local id = entry.category
        local row = CreateFrame("Button", nil, panel)
        row.selection = Widgets.CreateSettingsHighlight(row, true)
        row.selection:SetAllPoints()
        row:SetHighlightAtlas(Widgets.FOCUS_ATLAS)
        row:GetHighlightTexture():SetAlpha(0.35)
        row:SetScript("OnClick", function()
            if selected == id then
                panel:ClearSelection()
            else
                selected = id
                panel:refresh()
            end
            EmotePanel.settingsWindow:FocusEntry(panel, nil)
        end)
        function row:MoveCategory(step)
            return MoveCategory(id, step)
        end
        row:SetHeight(30)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT")
        check:SetScript("OnClick", function(self)
            if not Pages.IsCategoryWheelEnabled() then return end
            if not Entries.SaveEntryVisibility("categories", id, self:GetChecked()) then
                self:SetChecked(false)
                Widgets.ShowError(Entries.categoryLimitMessage)
                return
            end
            panel:refresh()
            EmotePanel:ShowStartPage()
        end)
        row.check = check

        row.icon = Widgets.CreateListIcon(row, check, "RIGHT")
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        Widgets.AddSettingsTooltip(check, entry.name, "Choose whether this category appears on the Category Wheel.")
        check.settingsFocusText = row.label
        Widgets.AddSettingsTooltip(row, entry.name, "Click to select. Right-click to edit.")
        Widgets.SetEntryEdit(row, function() EmotePanel:EditButton("categories", id, entry, true) end)
        rows[id] = row
    end

    function panel:ClearSelection()
        if not selected then return end
        selected = nil
        self:refresh()
    end

    function panel:refresh()
        local enabled = Pages.IsCategoryWheelEnabled()
        toggle:SetChecked(enabled)
        reset:SetEnabled(enabled and EmotePanelSavedVars.entryOrder.categories ~= nil)
        local order = Entries.GetOrderedEntryIDs("categories")
        local slot = 0
        up:SetEnabled(false)
        down:SetEnabled(false)
        edit:SetEnabled(selected ~= nil)
        placement:SetText(enabled and "Select a category" or "Category Wheel off")
        for position, id in ipairs(order) do
            local row = rows[id]
            local data = Entries.categoryByID[id]
            local name = Entries.GetEntryName("categories", id, data):gsub("|", "||")
            row.label:SetText(name)
            Widgets.SetIconTexture(row.icon, Entries.GetEntryIcon("categories", id, data))
            local y = -136 - (position - 1) * 30
            row:SetPoint("TOPLEFT", 16, y)
            row:SetPoint("TOPRIGHT", -24, y)
            row:SetAlpha(enabled and 1 or 0.5)
            local visible = not Entries.IsEntryHidden("categories", id)
            if visible then slot = slot + 1 end
            row.check:SetChecked(visible)
            row.check:SetEnabled(enabled)
            row.MoveSetting = enabled and row.MoveCategory or nil
            row.selection:SetShown(id == selected)
            if enabled and id == selected then
                placement:SetText(name .. " · " .. (visible and "Slot " .. slot or "Hidden"))
                up:SetEnabled(position > 1)
                down:SetEnabled(position < #order)
            end
        end
        reset:SetPoint("TOPLEFT", rows[order[#order]], "BOTTOMLEFT", 0, -10)
    end

    toggle:SetScript("OnClick", function(self)
        EmotePanelSavedVars.categoryWheel = not not self:GetChecked()
        panel:refresh()
        EmotePanel:ShowStartPage()
    end)
    panel:SetScript("OnShow", panel.refresh)
    panel:SetScript("OnHide", panel.ClearSelection)
    panel:refresh()
    return panel
end

local function CreatePositionControls(panel, anchor)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -13)
    title:SetText("Wheel position")

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetSize(420, 109)
    controls:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local cursorCenter = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    cursorCenter:SetSize(24, 24)
    cursorCenter:SetPoint("TOPLEFT", 0, 0)
    local cursorLabel = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cursorLabel:SetPoint("LEFT", cursorCenter, "RIGHT", 4, 0)
    cursorLabel:SetText("Cursor Center Position")
    Widgets.AddSettingsTooltip(cursorCenter, "Cursor Center Position",
        "Align the wheel vertically with WoW's centered cursor and targeting. Turn this off to use your saved Vertical (Y) position.", cursorLabel)
    local cursorPercent = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cursorPercent:SetPoint("LEFT", cursorLabel, "RIGHT", 8, 0)
    cursorCenter:SetScript("OnClick", function(self)
        EmotePanelSavedVars.followCursorCenter = self:GetChecked() and true or nil
        EmotePanel:LoadPosition()
        panel:refreshPosition()
    end)
    local function CreateSlider(axis, labelText, y)
        local slider = CreateFrame("Frame", AddonName .. "Position" .. axis, controls, "MinimalSliderWithSteppersTemplate")
        slider:SetSize(250, 20)
        slider:SetPoint("TOPLEFT", 108, y)
        slider:Init(50, 0, 100, 100)
        local label = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("RIGHT", slider, "LEFT", -10, 0)
        label:SetText(labelText)
        local direction = axis == "X" and "right" or "up"
        local tooltip = "Move the wheel " .. direction .. " by increasing the percentage. 50% centers this axis."
        Widgets.AddSettingsTooltip(slider, labelText, tooltip, label)
        Widgets.AddSettingsTooltip(slider.Slider, labelText, tooltip)
        Widgets.AddSettingsTooltip(slider.Back, labelText, "Decrease this axis by one percentage point.")
        Widgets.AddSettingsTooltip(slider.Forward, labelText, "Increase this axis by one percentage point.")
        function slider:StepSetting(direction)
            self:SetValue(self.Slider:GetValue() + direction)
        end
        slider.percentText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        slider.percentText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
        return slider
    end
    local xSlider = CreateSlider("X", "Horizontal (X)", -29)
    local ySlider = CreateSlider("Y", "Vertical (Y)", -55)

    local refreshing
    local function SetPercent(slider, percent)
        slider.percentText:SetText(("%d%%"):format(percent))
    end
    local function RefreshSlider(slider, offset, limit, locked)
        local percent = limit > 0 and math.max(0, math.min(100, Wheel.RoundOffset(50 + 50 * offset / limit))) or 50
        slider:SetEnabled(limit > 0 and not locked)
        slider:SetValue(percent)
        SetPercent(slider, percent)
    end
    function panel:refreshPosition()
        local x, y = EmotePanel:GetPositionOffsets()
        local maxX, maxY = Wheel.GetPositionLimits(EmotePanel.frame)
        refreshing = true
        RefreshSlider(xSlider, x, maxX)
        local following = EmotePanelSavedVars.followCursorCenter == true
        local fraction = EmotePanel:GetCursorCenterFraction()
        cursorCenter:SetChecked(following)
        cursorPercent:SetText(fraction and ("%g%%"):format(Wheel.RoundOffset(fraction * 1000) / 10) or "")
        RefreshSlider(ySlider, y, maxY, following and fraction ~= nil)
        refreshing = nil
    end

    local function OnValueChanged(slider, value)
        if refreshing or (slider == ySlider and EmotePanelSavedVars.followCursorCenter and EmotePanel:GetCursorCenterFraction()) then return end
        local x, y = EmotePanel:GetPositionOffsets()
        local maxX, maxY = Wheel.GetPositionLimits(EmotePanel.frame)
        local percent = Wheel.RoundOffset(value)
        local fraction = (percent - 50) / 50
        if slider == xSlider then
            x = Wheel.RoundOffset(fraction * maxX)
        else
            y = Wheel.RoundOffset(fraction * maxY)
        end
        EmotePanel:SetPositionOffsets(x, y)
        SetPercent(slider, percent)
    end
    local valueChanged = MinimalSliderWithSteppersMixin.Event.OnValueChanged
    xSlider:RegisterCallback(valueChanged, OnValueChanged, xSlider)
    ySlider:RegisterCallback(valueChanged, OnValueChanged, ySlider)

    local reset = Widgets.CreateRedButton(controls, "Reset Position")
    reset:SetSize(116, 24)
    reset:SetPoint("BOTTOMLEFT", 0, 0)
    Widgets.AddSettingsTooltip(reset, "Reset Position", "Reset both position sliders and enable Cursor Center Position.")
    reset:SetScript("OnClick", function()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS", "Reset both position sliders and enable Cursor Center Position?", function()
            EmotePanelSavedVars.followCursorCenter = true
            EmotePanelSavedVars.positions.emotePanel = nil
            EmotePanel:LoadPosition()
            panel:refreshPosition()
        end)
    end)
    return controls
end

local function CreateCustomizationPanel(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "CustomizationPanel", mainPanel)
    panel.name = "Customization"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Customization")

    local glyphLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    glyphLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    glyphLabel:SetText("Controller glyphs")
    local glyphDropdown = CreateFrame("DropdownButton", AddonName .. "GlyphStyle", panel, "WowStyle1DropdownTemplate")
    glyphDropdown:SetWidth(150)
    glyphDropdown:SetPoint("LEFT", glyphLabel, "RIGHT", 8, 0)
    Widgets.AddSettingsTooltip(glyphDropdown, "Controller glyphs", "Choose which controller icons appear in prompts. Automatic follows WoW's active icon set.", glyphLabel)
    local function SelectGlyphStyle(value)
        EmotePanelSavedVars.controllerGlyphs = value ~= "auto" and value or nil
        EmotePanel:RefreshControllerPrompts()
    end
    local function GlyphStyles()
        local styles = {"auto"}
        for _, value in ipairs({"xbox", "playstation", "switch"}) do
            if Widgets.GetStyleAtlas(Widgets.GLYPH_STYLES[value], "PAD1") then styles[#styles + 1] = value end
        end
        return styles
    end
    glyphDropdown:SetupMenu(function(_, root)
        local function IsSelected(value) return Widgets.GetGlyphStyle() == value end
        for _, value in ipairs(GlyphStyles()) do
            root:CreateRadio(value == "auto" and "Automatic" or Widgets.GLYPH_STYLES[value].name, IsSelected, SelectGlyphStyle, value)
        end
    end)
    function glyphDropdown:StepSetting(direction)
        SelectGlyphStyle(CycleSetting(GlyphStyles(), Widgets.GetGlyphStyle(), direction))
        self:GenerateMenu()
    end

    local display = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    display:SetPoint("TOPLEFT", glyphLabel, "BOTTOMLEFT", 0, -16)
    display:SetText("Display and feedback")
    local legend = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    legend:SetSize(24, 24)
    legend:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -4)
    local legendLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    legendLabel:SetPoint("LEFT", legend, "RIGHT", 4, 0)
    legendLabel:SetText("Show keybind legend")
    Widgets.AddSettingsTooltip(legend, "Show keybind legend", "Keep the shortcuts visible below the wheel. Turn this off to toggle them with View / Select.", legendLabel)
    legend:SetScript("OnClick", function(self)
        EmotePanelSavedVars.showKeybindLegend = not not self:GetChecked()
        EmotePanel.legendExpanded, EmotePanel.legendAlpha = nil, 0
        EmotePanel:RefreshWheelFooter()
        EmotePanel:SyncCombatWheel(true)
    end)

    local legendHint = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    legendHint:SetSize(24, 24)
    legendHint:SetPoint("LEFT", legend, "RIGHT", 186, 0)
    local legendHintLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    legendHintLabel:SetPoint("LEFT", legendHint, "RIGHT", 4, 0)
    legendHintLabel:SetText("Show legend hint")
    Widgets.AddSettingsTooltip(legendHint, "Show legend hint", "Show the View / Select prompt when the legend is hidden. The shortcut also works with this hint off.", legendHintLabel)
    legendHint:SetScript("OnClick", function(self)
        EmotePanelSavedVars.showLegendHint = not not self:GetChecked()
        EmotePanel:RefreshWheelFooter()
    end)

    local cooldownCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cooldownCheck:SetSize(24, 24)
    cooldownCheck:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 0, -8)
    cooldownCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.macroCooldowns = not not self:GetChecked()
        EmotePanel:RefreshActionCooldowns()
    end)
    local cooldownLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cooldownLabel:SetPoint("LEFT", cooldownCheck, "RIGHT", 4, 0)
    cooldownLabel:SetText("Show action cooldowns")
    Widgets.AddSettingsTooltip(cooldownCheck, "Show action cooldowns", "Show cooldown countdown numbers on Actions, Favorites, and the Pet Wheel. The circular swipe stays visible with numbers off.", cooldownLabel)

    local tooltipCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    tooltipCheck:SetSize(24, 24)
    tooltipCheck:SetPoint("TOPLEFT", cooldownCheck, "BOTTOMLEFT", 0, -8)
    tooltipCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.showWheelTooltips = self:GetChecked() and true or nil
        if not self:GetChecked() then EmotePanel:ShowWheelEntryTooltip(nil) end
    end)
    local tooltipLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tooltipLabel:SetPoint("LEFT", tooltipCheck, "RIGHT", 4, 0)
    tooltipLabel:SetText("Show wheel tooltips")
    Widgets.AddSettingsTooltip(tooltipCheck, "Show wheel tooltips", "Show tooltips for spells, items, macros, and pet actions when you hover with the mouse or highlight them with the controller.", tooltipLabel)

    local soundCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    soundCheck:SetSize(24, 24)
    soundCheck:SetPoint("TOPLEFT", tooltipCheck, "BOTTOMLEFT", 0, -8)
    soundCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.wheelSounds = not not self:GetChecked()
    end)
    local soundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 4, 0)
    soundLabel:SetText("Wheel sounds")
    Widgets.AddSettingsTooltip(soundCheck, "Wheel sounds", "Play navigation sounds on both wheels, in Customize Entry, and in the icon picker.", soundLabel)

    local vibrationCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    vibrationCheck:SetSize(24, 24)
    vibrationCheck:SetPoint("LEFT", soundCheck, "RIGHT", 186, 0)
    vibrationCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.wheelVibration = self:GetChecked() and true or nil
    end)
    local vibrationLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    vibrationLabel:SetPoint("LEFT", vibrationCheck, "RIGHT", 4, 0)
    vibrationLabel:SetText("Wheel vibration")
    Widgets.AddSettingsTooltip(vibrationCheck, "Wheel vibration", "Feel a short pulse when the stick or D-pad moves to a new wheel segment.", vibrationLabel)

    local position = CreatePositionControls(panel, soundCheck)
    local overrides = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    overrides:SetPoint("TOPLEFT", position, "BOTTOMLEFT", 0, -15)
    overrides:SetText("Entry overrides")
    local reset = Widgets.CreateRedButton(panel, "Reset All Entry Overrides")
    reset:SetSize(190, 24)
    reset:SetPoint("TOPLEFT", overrides, "BOTTOMLEFT", 0, -6)
    Widgets.AddSettingsTooltip(reset, "Reset All Entry Overrides", "Restore default icons, names, and text for built-in entries.")
    reset:SetScript("OnClick", function() Widgets.ShowConfirmation("EMOTEPANEL_RESET_ALL") end)
    local function Refresh(self)
        legend:SetChecked(EmotePanelSavedVars.showKeybindLegend ~= false)
        legendHint:SetChecked(EmotePanelSavedVars.showLegendHint ~= false)
        cooldownCheck:SetChecked(EmotePanelSavedVars.macroCooldowns ~= false)
        tooltipCheck:SetChecked(EmotePanelSavedVars.showWheelTooltips == true)
        soundCheck:SetChecked(EmotePanelSavedVars.wheelSounds ~= false)
        vibrationCheck:SetChecked(EmotePanelSavedVars.wheelVibration == true)
        self:refreshPosition()
    end
    panel.OnRefresh = Refresh
    panel:SetScript("OnShow", Refresh)
    Refresh(panel)
    return panel
end

local function CreateWheelBindingControls(panel, header)
    local timeout, cancelHold = 5, 0.65
    local bindingColumn = 102
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetText("Wheel Keybind")

    local capture = CreateFrame("Frame", nil, panel)
    capture:Hide()
    capture:SetAllPoints(UIParent)
    capture:SetFrameStrata("TOOLTIP")
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    local shade = capture:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.4)

    local dialog = CreateFrame("Frame", nil, capture, "PortraitFrameTemplate")
    dialog:SetSize(352, 162)
    dialog:SetPoint("CENTER", EmotePanel.settingsWindow, "CENTER")
    Widgets.SetChatPortrait(dialog)
    dialog.Bg:SetColorTexture(0.12, 0.09, 0.07, 1)
    dialog.CloseButton:SetScript("OnClick", function() capture:Hide() end)
    local prompt = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    prompt:SetPoint("TOP", 0, -47)
    prompt:SetText("Press a keyboard key or controller button.")
    local cancelHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cancelHint:SetPoint("TOP", 0, -73)
    Widgets.SetGlyphPrompt(cancelHint, function()
        return ("Hold %s or press Esc to cancel."):format(Widgets.GamepadGlyph("PAD2", "B/Circle"))
    end)

    local slot, input, chord, remaining, held, shownSeconds
    local buttons = {}
    local function ControllerTip()
        if InputUtil.IsGamepadUIEnabled() then return GAMEPAD_BETA_TIP end
        if not C_CVar.GetCVarBool("GamePadEnable") then return "Check Enable WoW controller input to use your controller." end
        return "Assign a keyboard key or controller button."
    end
    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local cancel = Widgets.CreateRedButton(dialog, "Cancel")
    cancel:SetSize(124, 28)
    cancel:SetPoint("BOTTOM", 0, 16)
    cancel:SetScript("OnClick", function() capture:Hide() end)
    cancel:Hide()
    local function ShowCapturePrompt()
        local seconds = math.ceil(remaining)
        if seconds == shownSeconds then return end
        shownSeconds = seconds
        cancel:SetText(("Cancel (%d)"):format(seconds))
    end
    local titles = {"Primary wheel keybind", "Secondary wheel keybind"}
    local petLabel
    if EmotePanel.supportsPetWheel then
        titles[3] = "Primary pet wheel keybind"
        titles[4] = "Secondary pet wheel keybind"
        petLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        petLabel:SetText("Pet Keybind")
    end

    local function BindingSlot(index)
        if index > 2 then return index - 2, true end
        return index, false
    end
    local function SetBindingAt(index, key)
        local bindingSlot, pet = BindingSlot(index)
        return EmotePanel:SetWheelBinding(bindingSlot, key, pet)
    end

    function panel:RefreshWheelBindings()
        for index, button in ipairs(buttons) do
            local key = EmotePanel:GetWheelBinding(BindingSlot(index))
            button:SetText(slot == index and "Press a key..." or key and (GetBindingText(key) or key) or "Not bound")
        end
    end

    for index, title in ipairs(titles) do
        local button = Widgets.CreateRedButton(panel, "Not bound")
        button:SetSize(114, 24)
        if index == 1 then
            button:SetPoint("TOPLEFT", header, "BOTTOMLEFT", bindingColumn, -24)
            label:SetPoint("LEFT", button, "LEFT", -bindingColumn, 0)
        elseif index == 3 then
            button:SetPoint("TOPLEFT", buttons[1], "BOTTOMLEFT", 0, -6)
            petLabel:SetPoint("LEFT", button, "LEFT", -bindingColumn, 0)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 10, 0)
        end
        if index <= 2 then
            local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            heading:SetPoint("BOTTOM", button, "TOP", 0, 3)
            heading:SetText(index == 1 and "Primary" or "Secondary")
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouseButton)
            local sameSlot = slot == index
            capture:Hide()
            if InCombatLockdown() then
                status:SetText("Set the wheel keybind outside combat.")
            elseif mouseButton == "RightButton" then
                local success, message = SetBindingAt(index, nil)
                status:SetText(success and ControllerTip() or message)
                panel:RefreshWheelBindings()
            elseif not sameSlot then
                slot, remaining, held = index, timeout, 0
                if GameTooltip:IsShown() then GameTooltip:Hide() end
                dialog.TitleContainer.TitleText:SetText(title)
                ShowCapturePrompt()
                cancel:Show()
                capture:EnableKeyboard(true)
                capture:EnableGamePadButton(true)
                capture:SetPropagateKeyboardInput(false)
                capture:Show()
                panel:RefreshWheelBindings()
            end
        end)
        Widgets.AddSettingsTooltip(button, title, "Click and press a keyboard key or controller button to assign it and replace its current WoW binding. Right-click clears this binding. The keybind works in and out of combat.", index == 1 and label or index == 3 and petLabel or nil)
        button.clearSettingBinding = true
        buttons[index] = button
    end
    status:SetPoint("TOPLEFT", buttons[3] or buttons[1], "BOTTOMLEFT", -bindingColumn, -6)
    status:SetWidth(370)
    status:SetJustifyH("LEFT")
    panel.wheelBindingButtons = buttons

    local gamepadCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    gamepadCheck:SetSize(24, 24)
    gamepadCheck:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -5)
    local gamepadLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    gamepadLabel:SetPoint("LEFT", gamepadCheck, "RIGHT", 4, 0)
    gamepadLabel:SetText("Enable WoW controller input")
    Widgets.AddSettingsTooltip(gamepadCheck, "Enable WoW controller input",
        "Changes WoW's GamePadEnable setting for the entire game.", gamepadLabel)

    local function OnInputDown(_, key)
        if not slot then return end
        if key == "ESCAPE" then
            capture:Hide()
        elseif not input and not IsKeyPressIgnoredForBinding(key) then
            input = key
            chord = CreateKeyChordStringUsingMetaKeyState(key)
        end
    end
    local function OnInputUp(_, key)
        if not slot or input ~= key then return end
        local selectedSlot, binding = slot, chord
        capture:Hide()
        local success, message = SetBindingAt(selectedSlot, binding)
        status:SetText(success and ControllerTip() or message)
        panel:RefreshWheelBindings()
    end
    capture:SetScript("OnKeyDown", OnInputDown)
    capture:SetScript("OnKeyUp", OnInputUp)
    capture:SetScript("OnGamePadButtonDown", OnInputDown)
    capture:SetScript("OnGamePadButtonUp", OnInputUp)
    capture:SetScript("OnUpdate", function(self, elapsed)
        if not slot then return end
        remaining = remaining - elapsed
        if chord == "PAD2" then held = held + elapsed end
        if remaining <= 0 or held >= cancelHold then
            self:Hide()
        else
            ShowCapturePrompt()
        end
    end)
    capture:SetScript("OnHide", function()
        slot, input, chord, shownSeconds = nil, nil, nil, nil
        cancel:Hide()
        if not InCombatLockdown() then
            capture:EnableKeyboard(false)
            capture:EnableGamePadButton(false)
        end
        status:SetText(ControllerTip())
        panel:RefreshWheelBindings()
    end)
    function panel:CancelWheelBindingCapture() capture:Hide() end
    function panel:IsCapturingWheelBinding() return slot ~= nil end
    function panel:RefreshControllerSetup()
        gamepadCheck:SetChecked(C_CVar.GetCVarBool("GamePadEnable") == true)
        if not slot then status:SetText(ControllerTip()) end
    end
    gamepadCheck:SetScript("OnClick", function(self)
        local value = self:GetChecked() and "1" or "0"
        capture:Hide()
        local success = C_CVar.SetCVar("GamePadEnable", value)
        panel:RefreshControllerSetup()
        if not success then status:SetText("WoW could not change GamePadEnable.") end
    end)
    panel:HookScript("OnHide", panel.CancelWheelBindingCapture)
    panel:RefreshWheelBindings()
    return gamepadCheck
end

local PAGING_COLUMN = 278

local function CreateNavigationRepeatControls(panel, anchor)
    local refreshing
    local step = Input.NAVIGATION_REPEAT_STEP
    local function CreateCheck(section, text, tip)
        local check = CreateFrame("CheckButton", nil, section, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        local label = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(text)
        Widgets.AddSettingsTooltip(check, text, tip, label)
        return check
    end
    local function CreateTimingSlider(section, name, text, previous, timing, tooltip)
        local title = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -7)
        title:SetText(text)
        local slider = CreateFrame("Frame", AddonName .. name, section, "MinimalSliderWithSteppersTemplate")
        slider:SetSize(176, 20)
        slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, 0)
        slider:Init(timing.default, timing.min, timing.max, (timing.max - timing.min) / step)
        slider.Slider:SetObeyStepOnDrag(true)
        Widgets.AddSettingsTooltip(slider, text, tooltip)
        Widgets.AddSettingsTooltip(slider.Slider, text, tooltip, title)
        function slider:StepSetting(direction)
            self:SetValue(self.Slider:GetValue() + direction * step)
        end

        local valueText = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if refreshing then return end
            local milliseconds = Wheel.RoundOffset(value / step) * step
            EmotePanelSavedVars[timing.key] = milliseconds
            valueText:SetText(("%d ms"):format(milliseconds))
        end, slider)
        return slider, function(enabled)
            local milliseconds = Input.GetNavigationRepeatTime(timing)
            slider:SetEnabled(enabled)
            slider:SetValue(milliseconds)
            valueText:SetText(("%d ms"):format(milliseconds))
        end
    end
    local function CreateControls(heading, unit, title, input, stopKey, stopTip, x, prefix, timing)
        local section = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
        section:SetSize(264, 190)
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, -12)
        section.Bg:SetColorTexture(0.06, 0.043, 0.03, 0.94)

        local sectionTitle = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sectionTitle:SetPoint("TOPLEFT", 12, -10)
        sectionTitle:SetText(heading)
        local repeatCheck = CreateCheck(section, title, "Hold " .. input .. " to repeat navigation on either wheel outside combat.")
        repeatCheck:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -7)
        local stop = CreateCheck(section, "Stop at ends", stopTip)
        stop:SetPoint("TOPLEFT", repeatCheck, "BOTTOMLEFT", 0, -4)
        stop:SetScript("OnClick", function(self)
            EmotePanelSavedVars[stopKey] = self:GetChecked() and true or nil
            EmotePanel:RefreshNavigationLimits()
        end)
        local delay, RefreshDelay = CreateTimingSlider(section, prefix .. "Delay", "Initial delay", stop, timing.delay,
            "Time before the first " .. unit .. " repeat.")
        local _, RefreshInterval = CreateTimingSlider(section, prefix .. "Interval", "Repeat interval", delay, timing.interval,
            "Time between " .. unit .. " repeats.")
        local function Refresh()
            local enabled = EmotePanelSavedVars[timing.enabledKey] ~= false
            repeatCheck:SetChecked(enabled)
            stop:SetChecked(EmotePanelSavedVars[stopKey] == true)
            refreshing = true
            RefreshDelay(enabled)
            RefreshInterval(enabled)
            refreshing = nil
        end
        repeatCheck:SetScript("OnClick", function(self)
            EmotePanelSavedVars[timing.enabledKey] = not not self:GetChecked()
            Refresh()
        end)
        local function Reset()
            EmotePanelSavedVars[timing.enabledKey] = nil
            EmotePanelSavedVars[timing.delay.key] = nil
            EmotePanelSavedVars[timing.interval.key] = nil
            Refresh()
        end
        return section, Refresh, Reset
    end
    local segments, RefreshSegments, ResetSegments = CreateControls("Segments", "segment", "Repeat segments", "D-pad up or down",
        "stopAtSegmentEnds", "Stop D-pad selection at the first and last segment on the current page.",
        0, "Repeat", Input.navigationRepeatTiming)
    local paging, RefreshPaging, ResetPaging = CreateControls("Paging", "page", "Repeat paging", "D-pad left or right or a shoulder button",
        "stopAtPageEnds", "Stop controller paging at the first and last page of the current list.",
        PAGING_COLUMN, "PageRepeat", Input.pagingRepeatTiming)
    local function Refresh()
        RefreshSegments()
        RefreshPaging()
    end
    local function Reset()
        ResetSegments()
        ResetPaging()
    end
    local reset = Widgets.CreateRedButton(panel, "Reset repeat")
    reset:SetSize(104, 22)
    reset:SetPoint("TOPLEFT", paging, "BOTTOMLEFT", 0, -16)
    reset:SetScript("OnClick", function()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS", "Restore default repeat toggles and timing?", Reset)
    end)
    Widgets.AddSettingsTooltip(reset, "Reset repeat", "Restore both repeat toggles and all four timing sliders to their defaults.")
    return Refresh, Reset, segments
end

local function CreateSettingsWindow()
    local width, height = 584, 650
    local sideTabWidth = 0
    local window = CreateFrame("Frame", AddonName .. "SettingsWindow", UIParent, "PortraitFrameTemplate")
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:Hide()
    window.Bg:SetColorTexture(0.12, 0.09, 0.07, 1)
    Widgets.SetChatPortrait(window)
    window.TitleContainer.TitleText:SetText("EmotePanel")
    window.CloseButton:SetScript("OnClick", function() window:Hide() end)
    Widgets.MakeTitleDraggable(window)
    table.insert(UISpecialFrames, window:GetName())

    local footer = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", -12, 10)
    footer:SetHeight(106)
    footer.Bg:SetColorTexture(0.06, 0.043, 0.03, 1)
    local focusLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusLabel:SetPoint("TOPLEFT", 14, -6)
    focusLabel:SetPoint("TOPRIGHT", -14, -6)
    focusLabel:SetJustifyH("CENTER")
    focusLabel:SetWordWrap(false)
    local focusDescription = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    focusDescription:SetPoint("TOPLEFT", 14, -40)
    focusDescription:SetPoint("TOPRIGHT", -14, -40)
    focusDescription:SetJustifyH("CENTER")
    focusDescription:SetWordWrap(true)
    focusDescription:SetMaxLines(2)
    local hint = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("BOTTOM", 0, 3)
    function window:FitToScreen()
        local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
        if screenWidth > 32 and screenHeight > 32 then
            self:SetScale(math.min(1, (screenWidth - 32) / (width + sideTabWidth), (screenHeight - 32) / height))
        end
    end

    local pages, tabs, activePage, activeIndex = {}, {}, nil, nil
    local selected
    local function PageShortcut(key)
        local shortcuts = activePage and activePage.view.settingsShortcuts
        local button = shortcuts and shortcuts[key]
        if button and button:IsShown() and button:IsEnabled() then return button end
    end
    local function CanEdit(control)
        return control and control.EditSetting and (not control.CanEditSetting or control:CanEditSetting())
    end
    local function CanDelete(control)
        if not control or not control.GetCustomEntry or not control:IsVisible() then return false end
        local _, _, data = control:GetCustomEntry()
        return data and data.custom == true
    end

    Widgets.SetGlyphPrompt(focusLabel, function()
        local parts = {}
        if selected then parts[1] = selected.settingsFocusLabel end
        local function Add(key, fallback, text)
            parts[#parts + 1] = Widgets.GamepadGlyph(key, fallback) .. " " .. text
        end
        if CanEdit(selected) then Add("PAD4", "Y", "Edit") end
        if CanDelete(selected) then Add("PADBACK", "Select", "Delete") end
        if selected and selected.MoveSetting then Add("DIRPADHORIZONTAL", "Left/Right", "Reorder") end
        local choose = PageShortcut("PAD3")
        if choose then Add("PAD3", "X", choose:GetText()) end
        local editShortcut = PageShortcut("PAD4")
        if editShortcut then Add("PAD4", "Y", editShortcut:GetText()) end
        if PageShortcut("PADRSTICK") then Add("PADRSTICK", "R3", "Reset Order") end
        return table.concat(parts, "    ")
    end)
    Widgets.SetGlyphPrompt(hint, function()
        local Glyph = Widgets.GamepadGlyph
        local peer = selected and selected.settingsPeer
        local detail = selected and selected.clearSettingBinding and ("    %s Clear"):format(Glyph("PAD3", "X"))
            or selected and selected.StepSetting and ("    %s Change"):format(Glyph("DIRPADHORIZONTAL", "Left/Right"))
            or peer and peer:IsShown() and peer:IsEnabled() and ("    %s Across"):format(Glyph("DIRPADHORIZONTAL", "Left/Right"))
            or activePage and activePage.view.StepActionSource and ("    %s Sources"):format(Glyph("DIRPADHORIZONTAL", "Left/Right"))
            or ""
        local action = selected and selected.clearSettingBinding and "Assign"
            or selected and selected.check and selected.check:IsEnabled() and "Toggle" or "Select"
        return ("%s/%s Tabs    %s Move    %s %s    %s Close%s"):format(
            Glyph("PADLSHOULDER", "LB"), Glyph("PADRSHOULDER", "RB"), Glyph("DIRPADVERTICAL", "Up/Down"),
            Glyph("PAD1", "A"), action, Glyph("PAD2", "B"), detail)
    end)

    function window:RefreshFocusPrompt()
        Widgets.RefreshGlyphPrompt(focusLabel)
        focusDescription:SetText(selected and selected.settingsFocusDescription or "")
        Widgets.RefreshGlyphPrompt(hint)
    end

    local function Focus(control)
        if selected then selected.settingsFocusHighlight:Hide() end
        selected = control
        if control and control.selection and activePage.view.ClearSelection then
            activePage.view:ClearSelection()
        end
        window:RefreshFocusPrompt()
        if not control then return end

        local parent, row = control, nil
        while parent and parent ~= window do
            if parent.orderY then
                row = parent
            elseif row and parent:IsObjectType("ScrollFrame") then
                local offset = parent:GetVerticalScroll()
                local bottom = row.orderY + row:GetHeight()
                if row.orderY < offset then
                    parent:SetVerticalScroll(row.orderY)
                elseif bottom > offset + parent:GetHeight() then
                    parent:SetVerticalScroll(math.min(parent:GetVerticalScrollRange(), bottom - parent:GetHeight()))
                end
                break
            end
            parent = parent:GetParent()
        end
        local highlight = control.settingsFocusHighlight
        if not highlight then
            highlight = Widgets.CreateSettingsHighlight(control)
            highlight:SetPoint("TOPLEFT", control, "TOPLEFT")
            control.settingsFocusHighlight = highlight
        end
        local right = control:GetRight()
        local labelRight = control.settingsFocusText and control.settingsFocusText:GetRight()
        local extension = right and labelRight and math.max(0, labelRight - right) or 0
        highlight:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", extension, 0)
        highlight:Show()
    end

    function window:FocusEntry(view, row)
        if self:IsShown() and activePage and activePage.view == view then Focus(row) end
    end

    local function GetControls()
        local controls = {}
        local function Collect(frame, scrollTop, rowY)
            if not frame:IsShown() then return end
            if frame:IsObjectType("ScrollFrame") then scrollTop = frame:GetTop() end
            if scrollTop and frame.orderY then rowY = scrollTop - frame.orderY - frame:GetHeight() / 2 end
            if frame.settingsFocusLabel and (frame.StepSetting or frame:IsObjectType("Button")) then
                if (not frame.IsEnabled or frame:IsEnabled()) and (not frame.IsSliderEnabled or frame:IsSliderEnabled()) then
                    local x, y = frame:GetCenter()
                    if x and y then
                        controls[#controls + 1] = {frame = frame, x = x, y = math.floor((rowY or y) / 8 + 0.5), order = #controls + 1}
                    end
                end
                if frame.StepSetting or frame.MoveSetting and frame:IsEnabled() then return end
            end
            for _, child in ipairs({frame:GetChildren()}) do Collect(child, scrollTop, rowY) end
        end
        if activePage then Collect(activePage.view) end
        table.sort(controls, function(a, b)
            if a.y ~= b.y then return a.y > b.y end
            if a.x ~= b.x then return a.x < b.x end
            return a.order < b.order
        end)
        return controls
    end

    local function FocusFirst()
        local first = GetControls()[1]
        Focus(first and first.frame)
    end

    local function MoveVertical(controls, index, step)
        local limit = step < 0 and 1 or #controls
        if not index then return controls[step < 0 and #controls or 1].frame end
        local current, nearest = controls[index], nil
        for position = index + step, limit, step do
            local candidate = controls[position]
            if candidate.y ~= current.y then
                if nearest and candidate.y ~= nearest.y then break end
                if not nearest or math.abs(candidate.x - current.x) < math.abs(nearest.x - current.x) then
                    nearest = candidate
                end
            end
        end
        return (nearest or current).frame
    end

    local function FindFocusedIndex(controls)
        for index, control in ipairs(controls) do
            if control.frame == selected then return index end
        end
    end

    local verticalSteps = {PADDUP = -1, PADDDOWN = 1}
    local horizontalSteps = {PADDLEFT = -1, PADDRIGHT = 1}
    local repeatInterval = 0.175
    local repeatKey, repeatRemaining, repeatControl
    local function StepVertical(key)
        local controls = GetControls()
        local nextControl
        if #controls > 0 then
            nextControl = MoveVertical(controls, FindFocusedIndex(controls), verticalSteps[key])
        end
        if nextControl == selected then return false end
        Focus(nextControl)
        Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT)
        return true
    end

    local function StepNavigation(key, control)
        if not control then return StepVertical(key) end
        if control ~= selected or not control:IsVisible() then return false end
        local step = horizontalSteps[key]
        if control.MoveSetting then return control:MoveSetting(step) end
        if not control.IsSliderEnabled or not control:IsSliderEnabled() then return false end
        local value = control.Slider:GetValue()
        control:StepSetting(step)
        return control.Slider:GetValue() ~= value
    end

    function window:SelectPage(key)
        repeatKey = nil
        for index, page in ipairs(pages) do
            local active = page.key == key
            page.view:SetShown(active)
            tabs[index]:SetChecked(active)
            if active then activePage, activeIndex = page, index end
        end
        self.activePage = key
        if self:IsShown() then FocusFirst() else Focus(nil) end
    end

    function window:AddPage(key, label, icon, view)
        local tab = Widgets.CreateSideTab(self, label, icon, function()
            if self.activePage == key then return end
            self:SelectPage(key)
            Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
        end)
        if #tabs == 0 then
            tab:SetPoint("TOPLEFT", self, "TOPRIGHT", -1, -42)
            sideTabWidth = tab:GetWidth()
            self:SetClampRectInsets(0, sideTabWidth, 0, 0)
        else
            tab:SetPoint("TOPLEFT", tabs[#tabs], "BOTTOMLEFT")
        end
        tabs[#tabs + 1] = tab
        pages[#pages + 1] = {key = key, view = view}
        view:Hide()
    end

    local pressed = {}
    local function IsSettingsInput(key)
        local dialog = EmotePanel.customMessageDialog
        if Widgets.GetConfirmation() or (dialog and dialog:IsShown()) then return false end
        if EmotePanel.optionsPanel:IsCapturingWheelBinding() then return false end
        return verticalSteps[key] ~= nil or horizontalSteps[key] ~= nil
            or key == "PAD1" or key == "PAD2" or key == "PADLSHOULDER" or key == "PADRSHOULDER"
            or key == "PAD3" and selected and selected.clearSettingBinding
            or key == "PADBACK" and CanDelete(selected)
            or key == "PAD4" and CanEdit(selected) or PageShortcut(key) ~= nil
    end
    window:SetScript("OnGamePadButtonDown", function(self, key)
        if InCombatLockdown() then return end
        local handled = IsSettingsInput(key) == true
        self:SetPropagateKeyboardInput(not handled)
        if pressed[key] then return end
        if not handled then return end
        repeatKey = nil
        local control = horizontalSteps[key] and selected and (selected.IsSliderEnabled or selected.MoveSetting) and selected
        if verticalSteps[key] or control then
            pressed[key] = "step"
            if StepNavigation(key, control) then
                repeatKey, repeatRemaining = key, repeatInterval
                repeatControl = control and selected
            end
        else
            pressed[key] = true
        end
    end)
    window:SetScript("OnGamePadButtonUp", function(self, key)
        if InCombatLockdown() then return end
        local handled = pressed[key]
        pressed[key] = nil
        if key == repeatKey then repeatKey = nil end
        self:SetPropagateKeyboardInput(not handled)
        if not handled or handled == "step" or not IsSettingsInput(key) then return end
        if key == "PAD2" then
            self:Hide()
        elseif key == "PADLSHOULDER" or key == "PADRSHOULDER" then
            local step = key == "PADLSHOULDER" and -1 or 1
            self:SelectPage(pages[(activeIndex - 1 + step) % #pages + 1].key)
            Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
        elseif activePage.view.StepActionSource and (key == "PADDLEFT" or key == "PADDRIGHT") then
            activePage.view:StepActionSource(key == "PADDLEFT" and -1 or 1)
        elseif key == "PADBACK" then
            EmotePanel:ConfirmDeleteEntry(selected:GetCustomEntry())
        elseif PageShortcut(key) then
            PageShortcut(key):Click("LeftButton")
            self:RefreshFocusPrompt()
        elseif key == "PAD4" then
            if GameTooltip:IsShown() then GameTooltip:Hide() end
            selected:EditSetting()
        else
            local controls = GetControls()
            local index = FindFocusedIndex(controls)
            if #controls == 0 then Focus(nil); return end
            if not index then
                Focus(controls[1].frame)
            elseif selected.StepSetting then
                selected:StepSetting(key == "PADDLEFT" and -1 or 1)
            elseif key == "PADDLEFT" or key == "PADDRIGHT" then
                local step = key == "PADDLEFT" and -1 or 1
                local peer = controls[index + step]
                if peer and peer.y == controls[index].y then Focus(peer.frame) end
            elseif key == "PAD1" or key == "PAD3" then
                if selected.selection then
                    if key == "PAD1" and selected.check and selected.check:IsEnabled() then
                        selected.check:Click("LeftButton")
                    end
                else
                    selected:Click(key == "PAD3" and "RightButton" or "LeftButton")
                end
                self:RefreshFocusPrompt()
            end
        end
    end)
    window:SetScript("OnShow", function(self)
        self:FitToScreen()
        self:EnableGamePadButton(true)
        Input.SetConsolePortCursorObstructed(self, true)
        FocusFirst()
    end)
    window:SetScript("OnUpdate", function(_, elapsed)
        Input.HideConsolePortCursor()
        if not repeatKey then return end
        if InCombatLockdown() or not IsSettingsInput(repeatKey) then
            repeatKey = nil
            return
        end
        repeatRemaining = repeatRemaining - elapsed
        if repeatRemaining > 0 then return end
        if StepNavigation(repeatKey, repeatControl) then
            repeatRemaining = repeatInterval
            -- Favorites reuse row frames by position. Follow the moved entry's focus.
            if repeatControl then repeatControl = selected end
        else
            repeatKey = nil
        end
    end)
    window:HookScript("OnHide", function(self)
        pressed = {}
        repeatKey = nil
        Focus(nil)
        local dialog = EmotePanel.customMessageDialog
        if dialog and dialog.fromSettings then dialog:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_SETTINGS")
        StaticPopup_Hide("EMOTEPANEL_RESET_ALL")
        Input.SetConsolePortCursorObstructed(self, false)
    end)
    return window, footer
end

local function CreateWheelBehaviorPanel(canvas)
    local panel = CreateFrame("Frame", AddonName .. "BehaviorPanel", canvas)
    panel:SetAllPoints(canvas)
    local behavior = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    behavior:SetPoint("TOPLEFT", 16, -16)
    behavior:SetText("Wheel Behavior")

    local opening = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    opening:SetPoint("TOPLEFT", behavior, "BOTTOMLEFT", 0, -20)
    opening:SetText("Opening and actions")

    local closeCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    closeCheck:SetSize(24, 24)
    closeCheck:SetPoint("TOPLEFT", opening, "BOTTOMLEFT", 0, -8)
    closeCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.closePanelAfterAction = not not self:GetChecked()
        EmotePanel:SyncCombatWheel(true)
    end)
    local closeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    closeLabel:SetPoint("LEFT", closeCheck, "RIGHT", 4, 0)
    closeLabel:SetText("Close panel after action")
    Widgets.AddSettingsTooltip(closeCheck, "Close panel after action", "Close the wheel after most actions. Ordinary shortcuts such as emotes keep the combat wheel open.", closeLabel)

    local rememberCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    rememberCheck:SetSize(24, 24)
    rememberCheck:SetPoint("TOPLEFT", closeCheck, "BOTTOMLEFT", 0, -8)
    rememberCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.rememberLastAction = self:GetChecked() and true or nil
        if not self:GetChecked() then EmotePanel.lastAction, EmotePanel.lastPetAction = nil, nil end
        EmotePanel:SyncCombatWheel(true)
    end)
    local rememberLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rememberLabel:SetPoint("LEFT", rememberCheck, "RIGHT", 4, 0)
    rememberLabel:SetText("Remember last Action")
    Widgets.AddSettingsTooltip(rememberCheck, "Remember last Action", "Reopen at the last action you used. The remembered action clears on logout or UI reload.", rememberLabel)

    local navigation = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    navigation:SetPoint("TOPLEFT", rememberCheck, "BOTTOMLEFT", 0, -24)
    navigation:SetText("Navigation")

    local movementCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    movementCheck:SetSize(24, 24)
    movementCheck:SetPoint("TOPLEFT", navigation, "BOTTOMLEFT", 0, -8)
    movementCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.lockMovementStick = not not self:GetChecked()
    end)
    local movementLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    movementLabel:SetPoint("LEFT", movementCheck, "RIGHT", 4, 0)
    movementLabel:SetText("Lock movement stick")
    Widgets.AddSettingsTooltip(movementCheck, "Lock movement stick", "Blocks stick movement while the wheel is open and until you center the stick after closing it. With this off, stick movement can interrupt casts or channels.", movementLabel)

    local RefreshNavigationRepeat, ResetNavigationRepeat, segmentSettings = CreateNavigationRepeatControls(panel, movementCheck)

    local resetBehavior = Widgets.CreateRedButton(panel, "Reset Wheel Behavior")
    resetBehavior:SetSize(152, 24)
    resetBehavior:SetPoint("TOPLEFT", segmentSettings, "BOTTOMLEFT", 0, -16)
    Widgets.AddSettingsTooltip(resetBehavior, "Reset Wheel Behavior", "Restore the defaults for this tab.")
    resetBehavior:SetScript("OnClick", function()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS", "Restore default wheel behavior?", function()
            EmotePanelSavedVars.closePanelAfterAction = nil
            EmotePanelSavedVars.rememberLastAction = nil
            EmotePanelSavedVars.lockMovementStick = nil
            EmotePanelSavedVars.stopAtSegmentEnds = nil
            EmotePanelSavedVars.stopAtPageEnds = nil
            EmotePanel.lastAction, EmotePanel.lastPetAction = nil, nil
            closeCheck:SetChecked(true)
            rememberCheck:SetChecked(false)
            movementCheck:SetChecked(true)
            ResetNavigationRepeat()
            EmotePanel:RefreshNavigationLimits()
            EmotePanel:SyncCombatWheel(true)
        end)
    end)

    local function Refresh()
        closeCheck:SetChecked(EmotePanelSavedVars.closePanelAfterAction ~= false)
        rememberCheck:SetChecked(EmotePanelSavedVars.rememberLastAction == true)
        movementCheck:SetChecked(EmotePanelSavedVars.lockMovementStick ~= false)
        RefreshNavigationRepeat()
    end
    panel.OnRefresh = Refresh
    panel:HookScript("OnShow", Refresh)
    Refresh()

    return panel
end

local function CreateGuidePanel(parent)
    local panel = CreateFrame("Frame", AddonName .. "GuidePanel", parent)
    local pages = {
        {"Start Here", {
            {"Set up your wheel keybinds",
                "On the General tab, assign a Wheel Keybind. If you play a Hunter or Warlock, you can also assign a Pet Keybind. Press either binding to open its wheel."},
            {"Gamepad keybinds",
                "Select a keybind slot and press the button you want to assign. On the wheel, use either stick to highlight a segment, or press D-pad up or down to move one segment at a time.\n\n"
                .. "From Categories, use the left shoulder button to open Actions. Add abilities, items, or macros in the Actions settings tab first. Each type has its own highlight color. Use Back to return, or use the right shoulder button from the first Actions page when paging can wrap.\n\n"
                .. "With a segment highlighted, use the buttons above to open or use it, edit it, or add or remove it from Favorites.",
                "{PAD1} Open / Use    {PAD4} Edit    {PAD3} Favorite    {PAD2} Back"},
            {"Mouse and keyboard",
                "Click a keybind slot, then press the key you want to assign. On the wheel, left-click to open or use a segment, right-click to edit it, and middle-click to add or remove it from Favorites. Scroll up from Categories to open Actions. Use your assigned keybind to open the wheel. To open settings, type {/ep} or left-click the minimap icon or EmotePanel in the Addon Compartment.",
                "{MOUSELEFT}    {MOUSERIGHT}    {MOUSEMIDDLE}"},
        }},
        {"Categories - Social", {
            {"Open a category", "Open a category to see its entries. Highlight an entry to preview it, then use it when you're ready. If the control legend is off, press View / Select to show or hide it."},
            {"Favorites", "Keeps shortcuts you've saved from across the wheel. Sit is added by default.\nExamples: Sit, Backpack, Wave, World Map"},
            {"Emotes", "Makes your character perform an emote. You can also write your own {/me} emote.\nExamples: Wave, Bow, Dance, Sit"},
            {"Voiced Emotes", "Plays a voiced emote from your character.\nExamples: Help Me, Attack My Target, Out of Mana, Follow Me"},
            {"Say Chat", "Sends a message to nearby players.\nExamples: Hello!, Well played, Thanks, Offer Help"},
            {"Party Chat", "Sends a message to your party.\nExamples: Follow Me, Need Break, Ready?, Need a Rez"},
            {"Gamepad", "", "{PADLSTICKAXIS} or {DIRPADVERTICAL} Highlight    {PAD1} Open or use    {PAD2} Return"},
            {"Mouse and keyboard", "", "{MOUSELEFT} Open or use    {MOUSERIGHT} the center to return"},
        }},
        {"Categories - Game Shortcuts", {
            {"Choose your shortcuts", "These categories open game windows or run common commands. Choose which categories appear under Settings, on the Categories tab. To add a slash command, choose Commands in Entries, select Add custom command, and enter a command such as {/roll 20}."},
            {"Commands", "Opens your bags and runs common commands.\nExamples: Backpack, Dismount, Roll, Ready Check"},
            {"Player Interactions", "Enable this category on the Categories tab. Target another player for shortcuts such as Inspect, Trade, and Invite. Leave Group is available while grouped."},
            {"Game Panels", "Opens WoW windows outside combat.\nExamples: World Map, Quest Log, Character Info, Spellbook"},
            {"Professions", "Opens professions your character has learned. Available outside combat.\nExamples: Alchemy, Blacksmithing, Cooking, Fishing"},
            {"Target Marker", "Marks your target or your own character. Open it from Categories or Commands.\nExamples: Mark Skull, Mark Cross, Mark Moon, Mark Star"},
            {"Gamepad", "", "{PADLSTICKAXIS} or {DIRPADVERTICAL} Highlight    {PAD1} Open or use    {PAD2} Return"},
            {"Mouse and keyboard", "", "{MOUSELEFT} Open or use    {MOUSERIGHT} the center to return"},
        }},
        {"Chat and Emotes", {
            {"Send and write messages",
                "1. Open Say Chat to speak to nearby players or Party Chat to message your group. Use an entry to send its message.\n"
                .. "2. To write your own, open Entries in Settings. In Say Chat, choose Add custom message. In Party Chat, choose Add custom party message.\n"
                .. "3. Give it a name you'll recognize on the wheel, such as Ask for a break. Enter the message, such as \"Can we take a quick break?\", and save it.\n"
                .. "4. Open the same category on the wheel and use your new entry. To write a custom emote instead, choose Emotes, select Add custom emote, and enter something like {/me offers everyone a snack.}"},
            {"Gamepad", "", "{DIRPADHORIZONTAL} Change section with the dropdown highlighted    {PAD3} Add an entry    {PAD1} Save or use"},
            {"Mouse and keyboard",
                "Choose a section, open its Add button, and click Save when you're done. Click the entry on the wheel to send it.",
                "{MOUSELEFT}"},
        }},
        {"Spells, Items, and Macros", {
            {"Add actions to the wheel",
                "1. Open the Actions tab in Settings. Choose Abilities, Items, or Macros.\n"
                .. "2. Check a spell, carried item, or saved macro to add it. Uncheck it to remove it. Try a healing spell or a potion.\n"
                .. "3. Open the main wheel with your assigned keybind. From Categories, open Actions and use the entry you added. Use your wheel keybind in combat.\n"
                .. "4. Automatic quest items and abilities is on by default. It adds tracked quest items and temporary abilities. Uncheck it in Actions to turn it off.\n"
                .. "5. With ConsolePort, open Options on a usable item in your bags or an active spell in the spellbook. Choose Add to EmotePanel Actions. Use the same menu to remove it."},
            {"Gamepad", "", "{DIRPADHORIZONTAL} Switch between Abilities, Items, and Macros    {PAD1} Check an entry or use it on the wheel    {PADLSHOULDER} Open Actions from Categories"},
            {"Mouse and keyboard",
                "Choose a list and check an entry. Scroll up from Categories to open Actions, then click the entry to use it.",
                "{MOUSELEFT}"},
        }},
        {"Edit, Reorder, Hide, and Favorite", {
            {"Customize what appears",
                "1. Edit an entry. Highlight it on the wheel or find it under Entries. Open its editor to change its icon or edit a custom message. To change the icon, open Choose Icon, pick one, then save the entry.\n"
                .. "2. Move or hide an entry. In Entries, choose its section and find the row. Move it up or down to change its position. Uncheck it to hide it. Check it again to bring it back.\n"
                .. "3. Arrange the opening wheel. Open Categories to move or hide category shortcuts. You can show up to eight at a time.\n"
                .. "4. Add a Favorite. Open Commands on the wheel and highlight Backpack. Favorite it, then go back and open Favorites to find it. Use the same control to remove it. You can also choose Favorite or Unfavorite in the entry editor, then save."},
            {"Gamepad", "", "{PAD4} Edit or open Choose Icon    {PAD1} Choose an icon, save, or toggle a checkbox    {DIRPADHORIZONTAL} Move a focused row    {PAD3} Favorite a highlighted wheel entry"},
            {"Mouse and keyboard",
                "Edit an entry with Right-Click. Select a row with Left-Click, then click Up or Down to move it. Click its checkbox to hide or show it. Middle-Click a wheel entry to favorite it.",
                "{MOUSERIGHT}    {MOUSELEFT}    {MOUSEMIDDLE}"},
        }},
        {"Pet Wheel", {
            {"Use pet commands",
                "1. If you play a Hunter or Warlock, assign a Pet Keybind on the General tab.\n"
                .. "2. Summon a living pet and press that binding. Pick a command such as Follow and use it.\n"
                .. "3. To toggle autocast, highlight a pet ability that supports it and use the autocast control."},
            {"Gamepad", "", "{PAD1} Use a pet command    {PAD3} Toggle autocast"},
            {"Mouse and keyboard",
                "Left-Click to use a pet command. Right-Click a supported pet ability to toggle autocast.",
                "{MOUSELEFT}    {MOUSERIGHT}"},
        }},
        {"Target Markers", {
            {"Mark a target",
                "1. Open Target Marker from Categories or Commands. Use your assigned wheel keybind to open the wheel in combat.\n"
                .. "2. Highlight a mark such as Skull. Apply it to your target or use Mark Self to put it on your character.\n"
                .. "3. Use Clear Mark to remove the mark from your target. With no target selected, Clear Mark removes your own mark."},
            {"Gamepad", "", "{PAD1} Mark target    {PAD4} Mark self    {PAD3} Clear mark"},
            {"Mouse and keyboard",
                "Left-Click a marker to mark your target. To mark yourself with the mouse, select your character first. Click the center icon to clear the mark.",
                "{MOUSELEFT}"},
        }},
        {"Slash Commands", {
            {"Mouse and keyboard", "Open chat, type a command, and press Enter."},
            {"/ep or /emotepanel", "Open EmotePanel Settings."},
            {"/ep config", "Open EmotePanel Settings."},
            {"/ep list", "Open Entries on Favorites."},
            {"/ep actions", "Choose spells, items, and macros for the wheel."},
            {"/ep categories", "Choose and arrange categories."},
            {"/ep reset", "Ask to restore the original icons, names, and text for built-in entries."},
            {"/ep debug", "Check whether combat logging is on."},
            {"/ep debug on or /ep debug off", "Turn combat logging on or off for this session."},
            {"/ep help or /ep scroll", "Open this guide."},
        }},
    }

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local count = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    count:SetPoint("TOPRIGHT", -20, -18)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 44)
    local glyphFallbacks = {
        PADLSTICKAXIS = "Stick",
        PAD1 = "A/Cross", PAD2 = "B/Circle", PAD3 = "X/Square", PAD4 = "Y/Triangle",
        PADLSHOULDER = "LB/L1", PADRSHOULDER = "RB/R1",
        DIRPADVERTICAL = "D-pad up/down", DIRPADHORIZONTAL = "D-pad left/right",
    }
    local mouseButtons = {
        MOUSELEFT = {label = "Left-Click", atlas = "newplayertutorial-icon-mouse-leftbutton"},
        MOUSERIGHT = {label = "Right-Click", atlas = "newplayertutorial-icon-mouse-rightbutton"},
        MOUSEMIDDLE = {label = "Middle-Click", texture = "Interface\\AddOns\\" .. AddonName .. "\\Art\\MouseMiddle"},
    }
    local function RenderGuideText(text)
        return (text:gsub("{([^{}]+)}", function(token)
            if token:sub(1, 1) == "/" then return "|cff80c8ff" .. token .. "|r" end
            local mouse = mouseButtons[token]
            if mouse then
                local label = "|cff36e7ec" .. mouse.label .. "|r"
                if mouse.texture then return ("%s |T%s:%d:%d|t"):format(label, mouse.texture, 24, 24) end
                if C_Texture.GetAtlasInfo(mouse.atlas) then
                    return label .. " " .. CreateAtlasMarkup(mouse.atlas, 24, 24)
                end
                return label
            end
            return Widgets.GamepadGlyph(token, glyphFallbacks[token])
        end))
    end
    local function RenderGuideBody(text)
        text = text:gsub("\n(%d+%. )", "\n\n|cffffd100%1|r")
        return RenderGuideText((text:gsub("^(%d+%. )", "|cffffd100%1|r")))
    end
    local rows = {}
    local maxRows = 0
    for _, page in ipairs(pages) do maxRows = math.max(maxRows, #page[2]) end
    for index = 1, maxRows do
        local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        local body = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        heading:SetJustifyH("LEFT")
        body:SetJustifyH("LEFT")
        body:SetWordWrap(true)
        local controls = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        controls:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
        controls:SetPoint("TOPRIGHT", heading, "BOTTOMRIGHT", 0, -4)
        controls:SetJustifyH("LEFT")
        local row = {heading = heading, body = body, controls = controls, prompts = ""}
        Widgets.SetGlyphPrompt(controls, function() return RenderGuideText(row.prompts) end)
        rows[index] = row
    end

    local previous = Widgets.CreateRedButton(panel, "Previous Page")
    previous:SetSize(124, 26)
    previous:SetPoint("BOTTOMLEFT", 16, 10)
    previous:Show()
    local nextPage = Widgets.CreateRedButton(panel, "Next Page")
    nextPage:SetSize(124, 26)
    nextPage:SetPoint("BOTTOMRIGHT", -20, 10)
    nextPage:Show()
    Widgets.AddSettingsTooltip(previous, "Previous Page", "Go to the previous guide page.")
    Widgets.AddSettingsTooltip(nextPage, "Next Page", "Go to the next guide page.")
    panel.settingsShortcuts = {PAD3 = nextPage, PAD4 = previous}
    local currentPage
    local function ShowPage(index, turnPage)
        currentPage = index
        local page = pages[index]
        title:SetText(page[1])
        count:SetText(("%d / %d"):format(index, #pages))
        local reference = index == #pages
        local overview = index == 2 or index == 3
        local gap = index == 1 and 22 or (reference and 10 or (overview and 8 or 14))
        local anchor = content
        for rowIndex, row in ipairs(rows) do
            local heading, body, controls = row.heading, row.body, row.controls
            local entry = page[2][rowIndex]
            heading:SetShown(entry ~= nil)
            local hasBody = entry ~= nil and entry[2] ~= ""
            body:SetShown(hasBody)
            controls:SetShown(entry ~= nil and entry[3] ~= nil)
            if entry then
                local offset = rowIndex == 1 and -6 or -gap
                heading:ClearAllPoints()
                local edge = rowIndex == 1 and "TOP" or "BOTTOM"
                heading:SetPoint("TOPLEFT", anchor, edge .. "LEFT", 0, offset)
                heading:SetPoint("TOPRIGHT", anchor, edge .. "RIGHT", 0, offset)
                if reference and rowIndex > 1 then
                    heading:SetTextColor(0.5, 0.78, 1)
                else
                    heading:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
                end
                heading:SetText(entry[1])
                body:ClearAllPoints()
                local textAnchor = entry[3] and controls or heading
                body:SetPoint("TOPLEFT", textAnchor, "BOTTOMLEFT", 0, -3)
                body:SetPoint("TOPRIGHT", textAnchor, "BOTTOMRIGHT", 0, -3)
                body:SetText(RenderGuideBody(entry[2]))
                controls:SetWordWrap(index ~= 1)
                controls:SetHeight(index == 1 and 36 or 0)
                row.prompts = entry[3] or ""
                Widgets.RefreshGlyphPrompt(controls)
                anchor = hasBody and body or textAnchor
            end
        end
        previous:SetEnabled(index > 1)
        nextPage:SetEnabled(index < #pages)
        local window = EmotePanel.settingsWindow
        if turnPage then
            window:FocusEntry(panel, nextPage:IsEnabled() and nextPage or previous)
            Widgets.PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
        end
    end
    previous:SetScript("OnClick", function() ShowPage(currentPage - 1, true) end)
    nextPage:SetScript("OnClick", function() ShowPage(currentPage + 1, true) end)
    panel:SetScript("OnShow", function() ShowPage(1) end)
    return panel
end

local function CreateInterfaceOptions()
    local window, footer = CreateSettingsWindow()
    EmotePanel.settingsWindow = window
    local canvas = CreateFrame("Frame", nil, window)
    canvas:SetPoint("TOPLEFT", 10, -53)
    canvas:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 2, 3)
    local mainPanel = CreateFrame("Frame", AddonName .. "OptionsPanel", canvas)
    mainPanel:SetAllPoints(canvas)
    mainPanel.name = AddonName

    -- Title at the top
    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("EmotePanel Options")
    local version = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 10, 0)
    version:SetText("v" .. ns.version)

    local setup = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    setup:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    setup:SetText("Controller Setup")
    local gamepadCheck = CreateWheelBindingControls(mainPanel, setup)

    local behaviorPanel = CreateWheelBehaviorPanel(canvas)
    local customizationPanel = CreateCustomizationPanel(canvas)
    EmotePanel.customizationPanel = customizationPanel
    local helpPanel = CreateHelpPanel(canvas)
    local actionPicker = ActionPicker.Create(canvas)
    local categoriesPanel = CreateCategoriesPanel(canvas)
    local guidePanel = CreateGuidePanel(canvas)
    for _, page in ipairs({customizationPanel, helpPanel, actionPicker, categoriesPanel, guidePanel}) do
        page:SetAllPoints(canvas)
    end

    local resetAddon = Widgets.CreateRedButton(mainPanel, "Reset to Defaults")
    resetAddon:SetSize(128, 24)
    resetAddon:SetPoint("TOPLEFT", gamepadCheck, "BOTTOMLEFT", 0, -22)
    Widgets.AddSettingsTooltip(resetAddon, "Reset to Defaults", "Restore all EmotePanel defaults for every character and reload the UI. WoW keybinds stay assigned.")
    resetAddon:SetScript("OnClick", function()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_SETTINGS",
            "Reset EmotePanel for all characters?\n\nThis clears saved settings, custom entries, Favorites, and Action selections, then reloads the UI. WoW keybinds stay assigned.",
            function()
                if InCombatLockdown() then
                    Widgets.ShowError("Reset the addon outside combat.", LE_GAME_ERR_AFFECTING_COMBAT)
                    return
                end
                -- Keep the current settings available until the UI saves them on reload.
                resetOnLogout = true
                ReloadUI()
            end)
    end)

    local function Refresh()
        mainPanel:RefreshWheelBindings()
        mainPanel:RefreshControllerSetup()
    end
    mainPanel.OnRefresh = Refresh
    mainPanel:HookScript("OnShow", Refresh)
    Refresh()

    local icons = "Interface\\Icons\\"
    window:AddPage("guide", "Help", icons .. "INV_Misc_Book_11", guidePanel)
    window:AddPage("general", "General", icons .. "INV_Misc_Gear_01", mainPanel)
    window:AddPage("behavior", "Wheel Behavior", icons .. "INV_Misc_PocketWatch_01", behaviorPanel)
    window:AddPage("customization", "Customization", icons .. "INV_Inscription_Tradeskill01", customizationPanel)
    window:AddPage("categories", "Categories", icons .. "INV_Misc_Note_01", categoriesPanel)
    window:AddPage("help", "Entries", icons .. "INV_Misc_Clipboard01", helpPanel)
    window:AddPage("actions", "Actions", icons .. "Spell_Arcane_Arcane01", actionPicker)
    window:SelectPage("general")

    local launcher = CreateFrame("Frame", nil, UIParent)
    local open = CreateFrame("Button", nil, launcher, "SharedButtonSmallTemplate")
    open:SetPoint("TOPLEFT", 16, -16)
    open:SetWidth(202)
    open:SetText("Open EmotePanel Settings")
    open:SetScript("OnClick", function() OpenSettings() end)
    local category = Settings.RegisterCanvasLayoutCategory(launcher, AddonName)
    Settings.RegisterAddOnCategory(category)
    EmotePanel.settingsCategoryID = category:GetID()

    window:HookScript("OnHide", function() mainPanel:CancelWheelBindingCapture() end)
    return mainPanel
end

local function HandleLogout()
    if resetOnLogout then
        EmotePanelSavedVars = nil
        resetOnLogout = nil
    end
end

SettingsUI.CreateInterfaceOptions = CreateInterfaceOptions
SettingsUI.GAMEPAD_BETA_TIP = GAMEPAD_BETA_TIP
SettingsUI.OpenSettings = OpenSettings
SettingsUI.ShowLoginWarnings = ShowLoginWarnings
SettingsUI.RefreshCategorySettings = RefreshCategorySettings
SettingsUI.HandleLogout = HandleLogout
SettingsUI.GetVisibleEntryList = GetVisibleEntryList
SettingsUI.RefreshEntryList = RefreshEntryList
