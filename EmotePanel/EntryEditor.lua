local AddonName, ns = ...
local EmotePanel = ns.panel

local Widgets = ns.Widgets
local PlayWheelSound = Widgets.PlayWheelSound
local ControllerGlyph = Widgets.GamepadGlyph
local Entries = ns.Entries
local Pages = ns.Pages
local SettingsUI = ns.SettingsUI

local function AddHoverSound(button)
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT) end
    end)
end

StaticPopupDialogs["EMOTEPANEL_RESET_BUTTON"] = {
    text = "Restore the default icon and any editable name or text?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data.index then
            if EmotePanelSavedVars.customMessages and EmotePanelSavedVars.customMessages[data.mode] then
                EmotePanelSavedVars.customMessages[data.mode][data.index] = nil
            end
            if EmotePanelSavedVars.customButtonNames and EmotePanelSavedVars.customButtonNames[data.mode] then
                EmotePanelSavedVars.customButtonNames[data.mode][data.index] = nil
            end

            Entries.SaveEntryIcon(data.mode, data.index, nil)
            if EmotePanel.frame:IsShown() then EmotePanel:RefreshWheel() end
            if data.mode == "categories" then SettingsUI.RefreshCategorySettings() end
            if data.mode == "macros" then ns.ActionPicker.Refresh() end

            if data.dialog then
                data.dialog:Hide()
            end

            -- Use the proper refresh call
            local helpPanel = _G[AddonName .. "HelpPanel"]
            if helpPanel and helpPanel:IsShown() then
                helpPanel:refresh()
            end

            print("|cFF00FF00EmotePanel:|r Button has been reset")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_DISCARD_ENTRY"] = {
    text = "Discard your unsaved changes?",
    button1 = "Discard",
    button2 = "Keep editing",
    OnAccept = function(_, dialog) dialog:Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_RESET_ICON"] = {
    text = "Use the default icon for this entry?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(_, reset) reset() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_DELETE_ENTRY"] = {
    text = "Delete %s from EmotePanel?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(_, delete) delete() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function EmotePanel:ConfirmDeleteEntry(mode, index, data, dialog)
    Widgets.ShowConfirmation("EMOTEPANEL_DELETE_ENTRY", data.name:gsub("|", "||"), function()
        if not Entries.DeleteCustomEntry(mode, index, data) then return end
        self.settingsWindow:FocusEntry(_G[AddonName .. "HelpPanel"], nil)
        if dialog then dialog:Hide() end
    end)
end

local function ShowEditorConfirmation(dialog, which, data)
    dialog.nameBox:ClearFocus()
    dialog.messageBox:ClearFocus()
    Widgets.ShowConfirmation(which, nil, data)
end

local function AddDialogChrome(frame)
    frame.Bg:SetColorTexture(0.12, 0.09, 0.07, 0.97)
    Widgets.SetChatPortrait(frame)

    -- Keep the nested picker above the editor's native portrait, border, and title.
    local level = frame:GetFrameLevel()
    frame.PortraitContainer:SetFrameLevel(level + 1)
    frame.NineSlice:SetFrameLevel(level + 2)
    frame.TitleContainer:SetFrameLevel(level + 3)
    local close = frame.CloseButton
    close:SetFrameLevel(level + 3)
    close:SetScript("OnClick", function() frame:Hide() end)
    AddHoverSound(close)
    return frame.TitleContainer.TitleText, close
end

local function CreateContentPane(parent)
    local pane = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    pane.Bg:SetColorTexture(0.06, 0.043, 0.03, 0.94)
    return pane
end

local function AddControllerFooter(frame, height)
    local background = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    background:SetPoint("BOTTOMLEFT", 5, 5)
    background:SetPoint("BOTTOMRIGHT", -5, 5)
    background:SetHeight(height)
    background:SetColorTexture(0.07, 0.052, 0.038, 0.95)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("BOTTOMLEFT", background, "TOPLEFT", 12, 0)
    divider:SetPoint("BOTTOMRIGHT", background, "TOPRIGHT", -12, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0.65, 0.48, 0.27, 0.38)
end

local function CreateEditorField(dialog, labelText, y, maxLetters)
    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 22, y)
    label:SetText(labelText)

    local box = CreateFrame("EditBox", nil, dialog, "LargeInputBoxTemplate")
    box:SetSize(338, 30)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(10, 10, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters)
    local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", 10, 0)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(false)
    hint:Hide()
    local function RefreshHint()
        local text = hint:GetText()
        hint:SetShown(text and text ~= "" and box:GetText() == "" and not box:HasFocus())
    end
    function box:SetHintText(text)
        hint:SetText(text or "")
        RefreshHint()
    end
    box:HookScript("OnTextChanged", RefreshHint)
    box:HookScript("OnEditFocusGained", RefreshHint)
    box:HookScript("OnEditFocusLost", RefreshHint)
    Widgets.AddSettingsTooltip(box, labelText, labelText == "Name" and "Set the name shown on the wheel." or "Edit the message or command sent by this entry.", label)

    local function TintInputBorder(r, g, b)
        box.Left:SetVertexColor(r, g, b)
        box.Middle:SetVertexColor(r, g, b)
        box.Right:SetVertexColor(r, g, b)
    end
    box:HookScript("OnEditFocusGained", function()
        TintInputBorder(1, 0.82, 0.5)
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT)
    end)
    box:HookScript("OnEditFocusLost", function() TintInputBorder(1, 1, 1) end)
    box.label = label
    return box
end

local function CreateIconPicker(dialog)
    local columns, rows = 8, 5
    local pageSize = columns * rows
    local extraFooterHeight = 100
    local gridTop = 95
    local picker = CreateFrame("Frame", nil, dialog, "PortraitFrameTemplate")
    picker:SetSize(392, 307 + gridTop + extraFooterHeight)
    picker:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    picker:SetFrameLevel(dialog:GetFrameLevel() + 10)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    local title = AddDialogChrome(picker)
    title:SetText("Choose Icon")
    AddControllerFooter(picker, 118)
    local gridInset = CreateContentPane(picker)
    gridInset:SetPoint("TOPLEFT", 15, -gridTop)
    gridInset:SetPoint("BOTTOMRIGHT", picker, "TOPRIGHT", -15, -gridTop - 222)

    local sourceTitle = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sourceTitle:SetPoint("BOTTOMLEFT", gridInset, "TOPLEFT", 8, 9)
    local wheelTab = Widgets.CreateSideTab(picker, "Wheel Icons", "Interface\\Icons\\INV_Misc_Book_11", function()
        if picker.library then picker:ToggleLibrary() end
    end)
    wheelTab:SetPoint("TOPLEFT", picker, "TOPRIGHT", -1, -gridTop)
    local libraryTab = Widgets.CreateSideTab(picker, "WoW Icon Library", "Interface\\Icons\\INV_Misc_Book_09", function()
        if not picker.library then picker:ToggleLibrary() end
    end)
    libraryTab:SetPoint("TOPLEFT", wheelTab, "BOTTOMLEFT")
    picker:SetClampRectInsets(0, wheelTab:GetWidth(), 0, 0)

    local wheelIcons, seen = {}, {}
    for _, mode in ipairs(Entries.modeOrder) do
        for _, data in ipairs(Entries.PANEL_MODES[mode].list) do
            local icon = data and Widgets.GetIconPath(data.icon)
            if icon and not seen[icon] then
                table.insert(wheelIcons, icon)
                seen[icon] = #wheelIcons
            end
        end
    end

    local function CreateOutline(parent, edgeSize, r, g, b)
        local outline = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = edgeSize })
        outline:SetBackdropBorderColor(r, g, b, 1)
        return outline
    end

    local cursor = CreateOutline(picker, 5, 0.07, 0.05, 0.02)
    cursor:SetFrameLevel(picker:GetFrameLevel() + 3)
    local cursorGold = CreateOutline(cursor, 3, 1, 0.82, 0.22)
    cursorGold:SetPoint("TOPLEFT", 1, -1)
    cursorGold:SetPoint("BOTTOMRIGHT", -1, 1)

    local preview = picker:CreateTexture(nil, "ARTWORK")
    preview:SetSize(46, 46)
    preview:SetPoint("BOTTOMLEFT", 111, 31 + extraFooterHeight)
    local selectedLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("LEFT", preview, "RIGHT", 8, 8)
    selectedLabel:SetText("Selected")
    local status = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", preview, "RIGHT", 8, -9)
    local navigationHint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    navigationHint:SetPoint("BOTTOM", 0, 82)
    Widgets.SetGlyphPrompt(navigationHint, function()
        return ("%s Select    %s/%s Page"):format(
            ControllerGlyph("DIRPAD", "D-pad"), ControllerGlyph("PADLSHOULDER", "LB"), ControllerGlyph("PADRSHOULDER", "RB"))
    end)
    local jumpHint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    jumpHint:SetPoint("BOTTOM", 0, 45)
    Widgets.SetGlyphPrompt(jumpHint, function()
        return ("%s + %s/%s 10 pages"):format(
            ControllerGlyph("PAD3", "X"), ControllerGlyph("PADLSHOULDER", "LB"), ControllerGlyph("PADRSHOULDER", "RB"))
    end)
    local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("BOTTOM", 0, 8)
    local function RenderHint()
        return ("%s Choose   %s Back   %s %s   %s Default"):format(
            ControllerGlyph("PAD1", "A"), ControllerGlyph("PAD2", "B"), ControllerGlyph("PAD4", "Y"),
            picker.library and "Wheel Icons" or "Library", ControllerGlyph("PADRSTICK", "R3"))
    end
    Widgets.SetGlyphPrompt(hint, RenderHint)

    local buttons = {}
    local previous, nextPage
    local function UpdateCursor()
        local button = buttons[picker.selected]
        local shown = button ~= nil and button.value ~= nil
        cursor:SetShown(shown)
        preview:SetShown(shown)
        if shown then
            cursor:ClearAllPoints()
            cursor:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
            cursor:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
            Widgets.SetIconTexture(preview, button.value)
        end
    end

    local function Choose(icon)
        dialog.pendingIcon = icon
        Widgets.SetIconTexture(dialog.icon, icon)
        picker:Hide()
    end
    function picker:ResetIcon()
        Widgets.ShowConfirmation("EMOTEPANEL_RESET_ICON", nil, function() Choose(dialog.defaultIcon) end)
    end

    function picker:GetIconCount()
        return self.library and self.provider:GetNumIcons() or #wheelIcons
    end

    function picker:Refresh()
        local count = self:GetIconCount()
        local pages = math.ceil(count / pageSize)
        local offset = (self.page - 1) * pageSize
        self.selected = math.min(self.selected, count - offset)
        hint:SetText(RenderHint())
        sourceTitle:SetText(self.library and "WoW Icon Library" or "Wheel Icons")
        wheelTab:SetChecked(not self.library)
        libraryTab:SetChecked(self.library)
        status:SetFormattedText("%d / %d", self.page, pages)
        previous:SetEnabled(self.page > 1)
        nextPage:SetEnabled(self.page < pages)
        for index, button in ipairs(buttons) do
            local absoluteIndex = offset + index
            local icon
            if absoluteIndex <= count then
                if self.library then
                    icon = self.provider:GetIconByIndex(absoluteIndex)
                else
                    icon = wheelIcons[absoluteIndex]
                end
            end
            button.value = icon
            button:SetShown(icon ~= nil)
            if icon then
                Widgets.SetIconTexture(button.icon, icon)
                button.current:SetShown(icon == dialog.pendingIcon)
            end
        end
        UpdateCursor()
    end

    function picker:MoveSelection(delta)
        local count = math.min(pageSize, self:GetIconCount() - (self.page - 1) * pageSize)
        local selected = math.max(1, math.min(self.selected + delta, count))
        if selected == self.selected then return end
        self.selected = selected
        UpdateCursor()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
    end

    function picker:ChangePage(delta)
        local lastPage = math.ceil(self:GetIconCount() / pageSize)
        local page = math.max(1, math.min(self.page + delta, lastPage))
        if page ~= self.page then
            self.page = page
            self:Refresh()
            PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
            return true
        end
        return false
    end

    function picker:ToggleLibrary()
        if dialog.CancelNavigationRepeat then dialog.CancelNavigationRepeat() end
        if not self.provider then
            self.provider = CreateFromMixins(IconDataProviderMixin)
            self.provider:Init(IconDataProviderExtraType.None)
        end
        self.library = not self.library
        local index
        if self.library then
            index = self.provider:GetIndexOfIcon(dialog.pendingIcon)
        else
            index = seen[dialog.pendingIcon]
        end
        index = index or 1
        self.page = math.ceil(index / pageSize)
        self.selected = (index - 1) % pageSize + 1
        self:Refresh()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
    end

    function picker:ChooseSelected()
        local button = buttons[self.selected]
        if button and button.value then Choose(button.value) end
    end

    for index = 1, pageSize do
        local button = CreateFrame("Button", nil, picker)
        button:SetSize(38, 38)
        button:SetPoint("TOPLEFT", gridInset, "TOPLEFT", 8 + ((index - 1) % columns) * 44,
            -8 - math.floor((index - 1) / columns) * 42)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.current = button:CreateTexture(nil, "OVERLAY")
        button.current:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        button.current:SetSize(16, 16)
        button.current:SetPoint("BOTTOMRIGHT", -2, 2)
        button:SetHighlightAtlas(Widgets.FOCUS_ATLAS)
        AddHoverSound(button)
        button:SetScript("OnClick", function()
            if button.value then Choose(button.value) end
        end)
        buttons[index] = button
    end

    local function PageWithMouse(direction)
        picker:ChangePage(direction * (IsShiftKeyDown() and 10 or 1))
    end
    previous = Widgets.CreateRedButton(picker, "<")
    previous:SetSize(27, 24)
    previous:SetPoint("BOTTOMLEFT", 23, 43 + extraFooterHeight)
    previous:SetScript("OnClick", function() PageWithMouse(-1) end)
    nextPage = Widgets.CreateRedButton(picker, ">")
    nextPage:SetSize(27, 24)
    nextPage:SetPoint("BOTTOMLEFT", 56, 43 + extraFooterHeight)
    nextPage:SetScript("OnClick", function() PageWithMouse(1) end)
    Widgets.AddSettingsTooltip(previous, "Previous page", "Shift-click to go back ten pages.")
    Widgets.AddSettingsTooltip(nextPage, "Next page", "Shift-click to go forward ten pages.")
    local default = Widgets.CreateRedButton(picker, "Default")
    default:SetSize(63, 24)
    default:SetPoint("BOTTOMRIGHT", -23, 43 + extraFooterHeight)
    default:SetScript("OnClick", function() picker:ResetIcon() end)
    for _, button in ipairs({previous, nextPage, default, wheelTab, libraryTab}) do AddHoverSound(button) end
    picker:SetScript("OnMouseWheel", function(_, delta)
        if delta ~= 0 then PageWithMouse(delta > 0 and -1 or 1) end
    end)
    picker:SetScript("OnShow", function()
        local index = seen[dialog.pendingIcon] or 1
        picker.page = math.ceil(index / pageSize)
        picker.selected = (index - 1) % pageSize + 1
        picker.library = false
        picker:Refresh()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_OPEN)
    end)
    picker:SetScript("OnHide", function()
        StaticPopup_Hide("EMOTEPANEL_RESET_ICON")
        if dialog.CancelNavigationRepeat then dialog.CancelNavigationRepeat() end
        if picker.provider then
            picker.provider:Release()
            picker.provider = nil
        end
    end)
    picker:Hide()
    picker:HookScript("OnHide", function()
        if dialog:IsShown() then PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_CLOSE) end
    end)
    Widgets.MakeTitleDraggable(picker)
    return picker
end

local function CreateCustomMessageDialog()
    local dialog = CreateFrame("Frame", "EmotePanelCustomMessageDialog", UIParent, "PortraitFrameTemplate")
    dialog:SetSize(384, 310)
    dialog:SetPoint("CENTER", 0, 200)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetAttribute("nodeignore", true)
    dialog.title, dialog.closeButton = AddDialogChrome(dialog)
    AddControllerFooter(dialog, 140)
    Widgets.AddSettingsTooltip(dialog.closeButton, "Close", "Close the editor. You will be asked before discarding changes.")

    local nameBox = CreateEditorField(dialog, "Name", -63, 18)
    local messageBox = CreateEditorField(dialog, "Message or command", -126, 255)
    nameBox:SetScript("OnTabPressed", function()
        if messageBox:IsShown() then messageBox:SetFocus() end
    end)
    messageBox:SetScript("OnTabPressed", function() nameBox:SetFocus() end)
    dialog:SetScript("OnHide", function()
        nameBox:ClearFocus()
        messageBox:ClearFocus()
        if dialog.picker then dialog.picker:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_DISCARD_ENTRY")
    end)

    local iconButton = Widgets.CreateRedButton(dialog, "Choose Icon")
    iconButton:SetSize(142, 30)
    iconButton:SetPoint("TOP", 20, -180)
    Widgets.AddSettingsTooltip(iconButton, "Choose Icon", "Choose artwork from the wheel icons or WoW's icon library.")
    local icon = dialog:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("RIGHT", iconButton, "LEFT", -8, 0)
    iconButton:SetScript("OnClick", function()
        nameBox:ClearFocus()
        messageBox:ClearFocus()
        if not dialog.picker then dialog.picker = CreateIconPicker(dialog) end
        dialog.picker:Show()
    end)

    local placement = CreateContentPane(dialog)
    placement:SetHeight(154)
    local placementTitle = placement:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    placementTitle:SetPoint("TOPLEFT", 14, -13)
    placementTitle:SetText("Wheel Placement")
    local show = CreateFrame("CheckButton", nil, placement, "MinimalCheckboxTemplate")
    show:SetSize(24, 24)
    show:SetPoint("TOPRIGHT", -60, -9)
    local showLabel = placement:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    showLabel:SetPoint("LEFT", show, "RIGHT", 4, 0)
    showLabel:SetText("Visible")
    Widgets.AddSettingsTooltip(show, "Visible", "Choose whether this entry appears on the wheel. Save to apply the change.", showLabel)

    local function CreatePositionRow(y)
        local row = CreateFrame("Frame", nil, placement)
        row:SetPoint("TOPLEFT", 12, y)
        row:SetPoint("TOPRIGHT", -12, y)
        row:SetHeight(43)
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT")
        line:SetPoint("TOPRIGHT")
        line:SetHeight(1)
        line:SetColorTexture(0.65, 0.48, 0.27, 0.35)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", 2, -7)
        row.location = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.location:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        return row
    end
    placement.categoryRow = CreatePositionRow(-48)
    placement.favoritesRow = CreatePositionRow(-96)
    placement.favoritesRow.name:SetText("Favorites")

    local function AddMoveButtons(row, offset)
        row.up = Widgets.CreateRedButton(row, "Up")
        row.up:SetSize(38, 26)
        row.up:SetPoint("LEFT", row, "RIGHT", offset, -2)
        Widgets.AddSettingsTooltip(row.up, "Move up", "Move this entry one place earlier. Save to apply the change.")
        row.down = Widgets.CreateRedButton(row, "Down")
        row.down:SetSize(48, 26)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 6, 0)
        Widgets.AddSettingsTooltip(row.down, "Move down", "Move this entry one place later. Save to apply the change.")
        row.highlight = Widgets.CreateSettingsHighlight(row)
        row.highlight:SetAllPoints()
        AddHoverSound(row.up)
        AddHoverSound(row.down)
    end
    AddMoveButtons(placement.categoryRow, -94)
    AddMoveButtons(placement.favoritesRow, -198)
    placement.show = show
    local favoriteButton = Widgets.CreateRedButton(placement.favoritesRow, "Favorite")
    favoriteButton:SetSize(96, 26)
    favoriteButton:SetPoint("RIGHT", placement.favoritesRow, "RIGHT", -2, -2)
    Widgets.AddSettingsTooltip(favoriteButton, "Favorites", "Add or remove this entry from Favorites. Save to apply the change.")
    placement.favoriteButton = favoriteButton
    dialog.placement = placement

    local editHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editHint:SetPoint("BOTTOM", 0, 52)
    Widgets.SetGlyphPrompt(editHint, function()
        local hint = ("%s Choose Icon    %s Save    %s Back"):format(
            ControllerGlyph("PAD4", "Y"), ControllerGlyph("PAD1", "A"), ControllerGlyph("PAD2", "B"))
        if placement:IsShown() and placement.favoritesRow:IsShown() then
            hint = hint .. "    " .. ControllerGlyph("DIRPADHORIZONTAL", "Left/Right") .. " Row"
        end
        return hint
    end)
    dialog.editHint = editHint
    dialog.errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.errorText:SetPoint("BOTTOM", 0, 86)
    dialog.errorText:SetTextColor(1, 0.4, 0.4)

    local saveButton = Widgets.CreateRedButton(dialog, "Save")
    saveButton:SetSize(86, 28)
    saveButton:SetPoint("BOTTOMLEFT", 22, 16)
    Widgets.AddSettingsTooltip(saveButton, "Save", "Apply the icon, text, and placement changes.")
    local resetButton = Widgets.CreateRedButton(dialog, "Reset")
    resetButton:SetSize(86, 28)
    resetButton:SetPoint("BOTTOM", 0, 16)
    Widgets.AddSettingsTooltip(resetButton, "Reset", "Restore this entry's default icon, name, and text.")
    local deleteButton = Widgets.CreateRedButton(dialog, "Delete")
    deleteButton:SetSize(86, 28)
    deleteButton:SetPoint("BOTTOM", 0, 16)
    Widgets.AddSettingsTooltip(deleteButton, "Delete", "Permanently remove this custom entry.")
    local cancelButton = Widgets.CreateRedButton(dialog, "Cancel")
    cancelButton:SetSize(86, 28)
    cancelButton:SetPoint("BOTTOMRIGHT", -22, 16)
    Widgets.AddSettingsTooltip(cancelButton, "Cancel", "Close the editor. You will be asked before discarding changes.")
    for _, button in ipairs({iconButton, show, favoriteButton, saveButton, resetButton, deleteButton, cancelButton}) do AddHoverSound(button) end

    dialog.nameBox = nameBox
    dialog.messageBox = messageBox
    dialog.saveButton = saveButton
    dialog.resetButton = resetButton
    dialog.deleteButton = deleteButton
    dialog.cancelButton = cancelButton
    dialog.iconButton = iconButton
    dialog.icon = icon
    local placementHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    placementHint:SetPoint("BOTTOM", 0, 96)
    Widgets.SetGlyphPrompt(placementHint, function()
        local hint = ("%s Visible    %s Move"):format(
            ControllerGlyph("PAD3", "X"), ControllerGlyph("DIRPADVERTICAL", "D-pad"))
        if resetButton:IsShown() then hint = hint .. "    " .. ControllerGlyph("PADLSHOULDER", "LB") .. " Reset" end
        if deleteButton:IsShown() then hint = hint .. "    " .. ControllerGlyph("PADLSHOULDER", "LB") .. " Delete" end
        if favoriteButton:IsShown() then
            hint = hint .. "    " .. ControllerGlyph("PADRSHOULDER", "RB") .. " " .. favoriteButton:GetText()
        end
        return hint
    end)
    dialog.placementHint = placementHint
    dialog:Hide()

    dialog:SetMovable(true)
    dialog:SetUserPlaced(true)
    dialog:SetClampedToScreen(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    return dialog
end

local function PlacementName(category)
    if category == "categories" then return "Categories" end
    if category == "macros" then return Pages.ACTIONS_TITLE end
    if category == "pet" then return Pages.PET_TITLE end
    return Entries.categoryByID[category].name
end

local function GetPlacementOrder(category)
    if category ~= "favorites" then return Entries.GetOrderedEntryIDs(category, true) end
    local order = {}
    for position, entry in ipairs(Entries.GetFavorites()) do order[position] = entry end
    return order
end

local function SetupPlacement(controls, category, context, mode, index, data)
    local favoriteIndex = Entries.FindFavorite(mode, index)
    local originallyFavorite = favoriteIndex ~= nil
    local isFavorite = originallyFavorite
    local favorite = favoriteIndex and Entries.GetFavorites()[favoriteIndex] or {mode = mode, index = index}
    local canFavorite = mode ~= "categories" and mode ~= "pet" and not data.automatic
    local originalCategoryOrder = GetPlacementOrder(category)
    local originalFavoritesOrder = GetPlacementOrder("favorites")
    if not originallyFavorite then originalFavoritesOrder[#originalFavoritesOrder + 1] = favorite end
    local categoryOrder, favoritesOrder = CopyTable(originalCategoryOrder, true), CopyTable(originalFavoritesOrder, true)
    local categoryMoves, favoriteMoves = {}, {}
    local originallyShown = not Entries.IsEntryHidden(mode, index)
    controls.show:SetChecked(originallyShown)
    controls.categoryRow.name:SetText(PlacementName(category))
    controls.favoritesRow:SetShown(canFavorite)
    controls:SetHeight(canFavorite and 154 or 105)
    local function SelectRow(row)
        controls.activeRow = row
        controls.categoryRow.highlight:SetShown(row == controls.categoryRow)
        controls.favoritesRow.highlight:SetShown(row == controls.favoritesRow)
    end
    function controls:SelectMoveRow(direction)
        SelectRow(direction < 0 and self.categoryRow or self.favoritesRow)
    end
    SelectRow(context == "favorites" and controls.favoritesRow or controls.categoryRow)

    local function VisibleOrder(scope)
        local visible = {}
        local inFavorites = scope == "favorites"
        local target = inFavorites and favorite or index
        local source = inFavorites and favoritesOrder or categoryOrder
        for _, id in ipairs(source) do
            local shown
            if id == target then
                shown = (not inFavorites or isFavorite) and controls.show:GetChecked() and Entries.IsEntryAvailable(data)
            elseif inFavorites then
                shown = Entries.IsEntryVisible(id.mode, id.index)
            else
                shown = Entries.IsEntryVisible(mode, id)
            end
            if shown then visible[#visible + 1] = id end
        end
        return visible
    end

    local function Location(scope, visible)
        if not controls.show:GetChecked() then return "Hidden" end
        if not Entries.IsEntryAvailable(data) then
            return data.actionType == "item" and "Not carried" or "Unavailable"
        end
        local target = scope == "favorites" and favorite or index
        for position, id in ipairs(visible) do
            if id == target then
                return ("Page %d · Slot %d"):format(
                    math.floor((position - 1) / ns.SECTOR_COUNT) + 1, (position - 1) % ns.SECTOR_COUNT + 1)
            end
        end
        return "Unavailable"
    end

    local function RefreshRow(row, scope, entry, order, moves)
        local visible = VisibleOrder(scope)
        local previous, nextEntry
        for position, id in ipairs(visible) do
            if id == entry then previous, nextEntry = visible[position - 1], visible[position + 1] end
        end
        row.location:SetText(scope == "favorites" and not isFavorite and "Not added" or Location(scope, visible))
        local function SetMove(button, neighbor)
            button:SetEnabled(neighbor ~= nil)
            button:SetScript("OnClick", function()
                if not neighbor or not Entries.SwapOrder(order, entry, neighbor) then return end
                moves[#moves + 1] = neighbor
                SelectRow(row)
                RefreshRow(row, scope, entry, order, moves)
                PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
            end)
        end
        SetMove(row.up, previous)
        SetMove(row.down, nextEntry)
    end
    local function RefreshPlacement()
        RefreshRow(controls.categoryRow, category, index, categoryOrder, categoryMoves)
        if canFavorite then
            RefreshRow(controls.favoritesRow, "favorites", favorite, favoritesOrder, favoriteMoves)
        end
        controls.favoriteButton:SetText(isFavorite and "Unfavorite" or "Favorite")
        Widgets.RefreshGlyphPrompt(controls:GetParent().placementHint)
    end
    controls.show:SetScript("OnClick", function()
        if mode == "categories" and controls.show:GetChecked() and not Entries.CanShowCategory(index) then
            controls.show:SetChecked(false)
            Widgets.ShowError(Entries.categoryLimitMessage)
            return
        end
        RefreshPlacement()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT)
    end)
    controls.favoriteButton:SetShown(canFavorite)
    controls.favoriteButton:SetScript("OnClick", function()
        isFavorite = not isFavorite
        RefreshPlacement()
    end)
    RefreshPlacement()

    local function IsReordered(order, original)
        for position, entry in ipairs(order) do
            if entry ~= original[position] then return true end
        end
        return false
    end
    local function SavePlacement(categoryChanged)
        local shown = not not controls.show:GetChecked()
        if shown ~= originallyShown then Entries.SaveEntryVisibility(mode, index, shown) end
        local reordered = false
        if not categoryChanged and IsReordered(categoryOrder, originalCategoryOrder) then
            local saved = GetPlacementOrder(category)
            for _, neighbor in ipairs(categoryMoves) do
                if Entries.SwapOrder(saved, index, neighbor) then reordered = true end
            end
            if reordered then EmotePanelSavedVars.entryOrder[category] = saved end
        end
        local favoriteChanged = isFavorite ~= originallyFavorite
        local savedFavoriteIndex = Entries.FindFavorite(mode, index)
        if favoriteChanged and (savedFavoriteIndex ~= nil) ~= isFavorite then
            Entries.ToggleFavorite(mode, index)
            savedFavoriteIndex = Entries.FindFavorite(mode, index)
        end
        if isFavorite and savedFavoriteIndex and IsReordered(favoritesOrder, originalFavoritesOrder) then
            local savedFavorite = Entries.GetFavorites()[savedFavoriteIndex]
            for _, neighbor in ipairs(favoriteMoves) do
                if Entries.MoveFavorite(savedFavorite, neighbor) then reordered = true end
            end
        end
        return reordered or shown ~= originallyShown or favoriteChanged
    end
    return SavePlacement, function()
        return (not not controls.show:GetChecked()) ~= originallyShown or isFavorite ~= originallyFavorite
            or IsReordered(categoryOrder, originalCategoryOrder)
            or (isFavorite and IsReordered(favoritesOrder, originalFavoritesOrder))
    end
end

local function RevealEditedEntry(panel, context, mode, index)
    if context == "categories" then
        if Pages.currentPage == Pages.categoryWheel then
            for sector, id in ipairs(Pages.categoryWheel.entries) do
                if id == index then
                    panel:DisplayPage(nil, Pages.categoryWheel, sector)
                    return
                end
            end
        end
        return
    end
    local first, last = Pages.GetCategoryPageRange(context)
    if not first then return end
    for pageIndex = first, last do
        local page = Pages.GetPage(pageIndex)
        for sector = 1, page.count do
            local entryMode, entryIndex = Pages.GetSectorEntry(sector, page)
            if entryMode == mode and entryIndex == index then
                panel:ShowPage(pageIndex, sector)
                return
            end
        end
    end
    panel:ShowPage(context == "macros" and last or first)
end

function EmotePanel:SetupEditorGamepad()
    local dialog = self.customMessageDialog
    if dialog and not dialog.gamepadReady and self.bindGamepadButtons and not InCombatLockdown() then
        self.bindGamepadButtons(dialog)
        dialog.gamepadReady = true
    end
end

function EmotePanel:EditButton(mode, index, data, fromSettings, context)
    if not self.customMessageDialog then
        self.customMessageDialog = CreateCustomMessageDialog()
        self.customMessageDialog:HookScript("OnShow", function()
            self:UpdateSecureWheelInput()
            PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_OPEN)
        end)
        self.customMessageDialog:HookScript("OnHide", function()
            self:UpdateSecureWheelInput()
            PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_CLOSE)
        end)
    end

    local dialog = self.customMessageDialog
    StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
    StaticPopup_Hide("EMOTEPANEL_DISCARD_ENTRY")
    self:SetupEditorGamepad()
    dialog.fromSettings = fromSettings
    local creating = index == nil
    local config = creating and Entries.customEntryTypes[mode]
    if creating then
        data = { name = "", action = "", icon = config.icon, actionType = config.actionType, custom = true }
    end
    local editingCategory = mode == "categories"
    local editableText = not editingCategory and Entries.HasEditableText(data)
    local editableName = editingCategory or editableText
    local nativeCommand = data.actionType == "command" and (data.run or data.raidMarker)
    local iconTop = editableText and 192 or editableName and 126 or 72
    dialog.title:SetText(config and config.addLabel or editingCategory and "Customize Category" or "Customize Entry")
    dialog:SetHeight(iconTop + 192)
    dialog.errorText:SetPoint("BOTTOM", 0, creating and 92 or 155)
    dialog.placement:SetShown(not creating)
    dialog.placementHint:SetShown(not creating)
    local savePlacement, hasPlacementChanges
    if not creating then
        local category = mode == "emotes" and Entries.voicedEmoteTokens[Entries.GetEmoteToken(data)] == true and "voicedEmotes" or mode
        if Entries.IsPlayerInteraction(mode, index) then category = "interactions" end
        context = context or (not fromSettings and Pages.currentPage.mode == "favorites" and "favorites") or category
        dialog.placement:ClearAllPoints()
        dialog.placement:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -iconTop - 44)
        dialog.placement:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -24, -iconTop - 44)
        savePlacement, hasPlacementChanges = SetupPlacement(dialog.placement, category, context, mode, index, data)
        dialog:SetHeight(iconTop + 224 + dialog.placement:GetHeight())
    end
    dialog.nameBox:SetShown(editableName)
    dialog.nameBox.label:SetShown(editableName)
    dialog.messageBox:SetShown(editableText)
    dialog.messageBox.label:SetShown(editableText)
    dialog.messageBox.label:SetText(nativeCommand and "Slash override (optional)" or data.actionType == "emote" and "Emote (/wave or /me text)"
        or data.actionType == "command" and "Slash command" or "Message")
    dialog.resetButton:SetShown(not data.custom)
    dialog.deleteButton:SetShown(data.custom and not creating)
    Widgets.RefreshGlyphPrompt(dialog.placementHint)
    Widgets.RefreshGlyphPrompt(dialog.editHint)
    dialog.iconButton:SetPoint("TOP", creating and 19 or 20, -iconTop)
    local previousName = Entries.GetEntryName(mode, index, data)
    local previousMessage = editableText and (Entries.GetCustomMessage(mode, index) or data.action) or ""
    if nativeCommand then previousMessage = Entries.GetSlashCommand(mode, index, data) or "" end
    dialog.nameBox:SetText(previousName)
    dialog.messageBox:SetText(previousMessage)
    dialog.nameBox:SetHintText(config and config.nameHint)
    dialog.messageBox:SetHintText(config and config.messageHint)
    dialog.defaultIcon = data.custom and Widgets.GetIconPath(Entries.customEntryTypes[mode].icon)
        or Entries.GetDefaultEntryIcon(data)
    local previousIcon = Entries.GetEntryIcon(mode, index, data)
    dialog.pendingIcon = previousIcon
    Widgets.SetIconTexture(dialog.icon, dialog.pendingIcon)
    local function RequestClose()
        if Widgets.GetConfirmation() then return end
        local textChanged = (editableName and dialog.nameBox:GetText() ~= previousName)
            or (editableText and dialog.messageBox:GetText() ~= previousMessage)
        if textChanged or dialog.pendingIcon ~= previousIcon or (hasPlacementChanges and hasPlacementChanges()) then
            ShowEditorConfirmation(dialog, "EMOTEPANEL_DISCARD_ENTRY", dialog)
        else
            dialog:Hide()
        end
    end
    dialog.closeButton:SetScript("OnClick", RequestClose)
    dialog.cancelButton:SetScript("OnClick", RequestClose)
    dialog.saveButton:SetScript("OnClick", function()
        if savePlacement and InCombatLockdown() then
            dialog.errorText:SetText("Save entry changes after combat.")
            return
        end
        if editingCategory and dialog.placement.show:GetChecked() and not Entries.CanShowCategory(index) then
            Widgets.ShowError(Entries.categoryLimitMessage)
            return
        end
        local categoryChanged
        if data.custom then
            local name = dialog.nameBox:GetText():match("^%s*(.-)%s*$")
            local action = dialog.messageBox:GetText():match("^%s*(.-)%s*$")
            if name == "" or action == "" then
                dialog.errorText:SetText("Enter a name and text.")
                return
            end
            if mode == "emotes" then
                local text = Entries.GetCustomEmoteText(action)
                local token
                if text then
                    action = "/me " .. text
                else
                    action = action:gsub("^/+", "")
                    token = hash_EmoteTokenList and hash_EmoteTokenList["/" .. action:upper()]
                    if not token then
                        dialog.errorText:SetText("Enter /wave or /me followed by your text.")
                        return
                    end
                end
                categoryChanged = Entries.voicedEmoteTokens[Entries.GetEmoteToken(data)] ~= Entries.voicedEmoteTokens[token]
                data.token = token
            elseif mode == "commands" and not action:match("^/[^/%s]") then
                dialog.errorText:SetText("Start the command with /.")
                return
            end
            data.name, data.action, data.icon = name, action, dialog.pendingIcon
            if creating then
                local entries = EmotePanelSavedVars.entries
                entries[mode] = entries[mode] or {}
                table.insert(entries[mode], data)
            end
        elseif editingCategory then
            local name = dialog.nameBox:GetText():match("^%s*(.-)%s*$")
            if name == "" then
                dialog.errorText:SetText("Enter a category name.")
                return
            end
            Entries.SaveCustomButtonName(mode, index, name ~= data.name and name or nil)
        elseif editableText then
            local name = dialog.nameBox:GetText()
            local message = dialog.messageBox:GetText()
            if name ~= "" and (message ~= "" or nativeCommand) then
                if name ~= previousName then
                    Entries.SaveCustomButtonName(mode, index, name ~= data.name and name or nil)
                end
                if message ~= previousMessage then
                    Entries.SaveCustomMessage(mode, index, message ~= "" and message ~= data.action and message or nil)
                end
            end
        end
        if not data.custom then
            Entries.SaveEntryIcon(mode, index, dialog.pendingIcon ~= dialog.defaultIcon and dialog.pendingIcon or nil)
        end
        local placementChanged = savePlacement and savePlacement(categoryChanged)
        if creating or categoryChanged or placementChanged then
            self:RefreshEntryPages()
            if placementChanged and not fromSettings and self.frame:IsShown() then
                RevealEditedEntry(self, context, mode, index)
            end
        elseif self.frame:IsShown() then
            self:RefreshWheel()
        end
        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
        if editingCategory then SettingsUI.RefreshCategorySettings() end
        if mode == "macros" then ns.ActionPicker.Refresh() end
        dialog:Hide()
    end)
    dialog.errorText:SetText("")
    dialog.resetButton:SetScript("OnClick", function()
        if Widgets.GetConfirmation() then return end
        ShowEditorConfirmation(dialog, "EMOTEPANEL_RESET_BUTTON", {
            mode = mode,
            index = index,
            dialog = dialog,
        })
    end)
    dialog.deleteButton:SetScript("OnClick", function()
        dialog.nameBox:ClearFocus()
        dialog.messageBox:ClearFocus()
        self:ConfirmDeleteEntry(mode, index, data, dialog)
    end)
    dialog:Show()
end
