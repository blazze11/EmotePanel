-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

local PANEL_WIDTH, PANEL_HEIGHT = 432, 524
local WHEEL_SIZE = 382
local LABEL_RADIUS = 136
local FULL_TURN = 2 * math.pi
local MEDIA = "Interface\\AddOns\\EmotePanel\\Media\\"

-- Default positions for the panels
local DEFAULT_POSITIONS = {
    emotePanel = {
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = 0
    },
}

local function GetCustomMessage(mode, index)
    if not EmotePanelSavedVars.customMessages then
        EmotePanelSavedVars.customMessages = {}
    end
    if not EmotePanelSavedVars.customMessages[mode] then
        EmotePanelSavedVars.customMessages[mode] = {}
    end
    return EmotePanelSavedVars.customMessages[mode][index]
end

local function SaveCustomMessage(mode, index, message)
    if not EmotePanelSavedVars.customMessages then
        EmotePanelSavedVars.customMessages = {}
    end
    if not EmotePanelSavedVars.customMessages[mode] then
        EmotePanelSavedVars.customMessages[mode] = {}
    end
    EmotePanelSavedVars.customMessages[mode][index] = message
end

local function GetCustomButtonName(mode, index)
    if not EmotePanelSavedVars.customButtonNames then
        EmotePanelSavedVars.customButtonNames = {}
    end
    if not EmotePanelSavedVars.customButtonNames[mode] then
        EmotePanelSavedVars.customButtonNames[mode] = {}
    end
    return EmotePanelSavedVars.customButtonNames[mode][index]
end

local function SaveCustomButtonName(mode, index, name)
    if not EmotePanelSavedVars.customButtonNames then
        EmotePanelSavedVars.customButtonNames = {}
    end
    if not EmotePanelSavedVars.customButtonNames[mode] then
        EmotePanelSavedVars.customButtonNames[mode] = {}
    end
    EmotePanelSavedVars.customButtonNames[mode][index] = name
end



local PANEL_MODES = {
    emotes = {
        title = "Emotes 1",
        list = {
            { name = "Angry",    action = "angry",    actionType = "emote" },
            { name = "Applause", action = "bravo",    actionType = "emote" },
            { name = "Blush",    action = "blush",    actionType = "emote" },
            { name = "Bow",      action = "bow",      actionType = "emote" },
            { name = "Cackle",   action = "cackle",   actionType = "emote" },
            { name = "Cheer",    action = "cheer",    actionType = "emote" },
            { name = "Cry",      action = "cry",      actionType = "emote" },
            { name = "Dance",    action = "dance",    actionType = "emote" },
            { name = "Facepalm", action = "facepalm", actionType = "emote" },
            { name = "Flex",     action = "flex",     actionType = "emote" },
        }
    },
    emotes2 = {
        title = "Emotes 2",
        list = {
            { name = "Golfclap", action = "golfclap", actionType = "emote" },
            { name = "Goodbye",  action = "bye",      actionType = "emote" },
            { name = "Hug",      action = "hug",      actionType = "emote" },
            { name = "Kiss",     action = "kiss",     actionType = "emote" },
            { name = "Kneel",    action = "kneel",    actionType = "emote" },
            { name = "Laugh",    action = "laugh",    actionType = "emote" },
            { name = "No",       action = "no",       actionType = "emote" },
            { name = "Point",    action = "point",    actionType = "emote" },
            { name = "Roar",     action = "roar",     actionType = "emote" },
            { name = "Rude",     action = "rude",     actionType = "emote" },
        }
    },
    emotes3 = {
        title = "Emotes 3",
        list = {
            { name = "Salute",   action = "salute",    actionType = "emote" },
            { name = "Sigh",     action = "sigh",      actionType = "emote" },
            { name = "Sorry",    action = "apologize", actionType = "emote" },
            { name = "Stand",    action = "stand",     actionType = "emote" },
            { name = "Talk",     action = "talk",      actionType = "emote" },
            { name = "Thank",    action = "thank",     actionType = "emote" },
            { name = "Threaten", action = "threaten",  actionType = "emote" },
            { name = "Wave",     action = "wave",      actionType = "emote" },
            { name = "Yes",      action = "nod",       actionType = "emote" },
        }
    },
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",      action = "Hello! Hope you're having a great day!", actionType = "say" },
            { name = "Well played", action = "Well played! That was awesome!",         actionType = "say" },
            { name = "Thanks",      action = "Thank you! Really appreciate it!",       actionType = "say" },
            { name = "No problem",  action = "No problem! Happy to help!",             actionType = "say" },
            { name = "BRB",         action = "Be right back, quick break",             actionType = "say" },
            { name = "Bye",         action = "Farewell! Have a great adventure!",      actionType = "say" },
            { name = "LFG",         action = "Looking for group! Anyone interested?",  actionType = "say" },
            { name = "Quest",       action = "Anyone working on this quest?",          actionType = "say" },
            { name = "Gratz",       action = "Congratulations!",                       actionType = "say" },
            { name = "Trade",       action = "Would you like to trade?",               actionType = "say" },
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me",    action = "Follow me please!",                     actionType = "party" },
            { name = "Need Break",   action = "Need a quick break! Back in 5 minutes", actionType = "party" },
            { name = "Thanks Group", action = "Thanks everyone for the great run!",    actionType = "party" },
            { name = "Good Job",     action = "Great job team! Well executed!",        actionType = "party" },
            { name = "Ready Check",  action = "Everyone ready to continue?",           actionType = "party" },
            { name = "OOM",          action = "Out of mana, need to drink!",           actionType = "party" },
            { name = "Wait",         action = "Please wait for everyone!",             actionType = "party" },
            { name = "Pulling",      action = "Pulling in 5 seconds!",                 actionType = "party" },
            { name = "CC",           action = "Please use crowd control!",             actionType = "party" },
            { name = "Help",         action = "Need help here!",                       actionType = "party" },
        }
    },
    commands = {
        title = "Commands",
        list = {
            { name = "Invite Target",   action = "invite",     actionType = "command" },
            { name = "Inspect Target",  action = "inspect",    actionType = "command" },
            { name = "Trade Target",    action = "trade",      actionType = "command" },
            { name = "Follow Target",   action = "follow",     actionType = "command" },
            { name = "Befriend Target", action = "friend",     actionType = "command" },
            { name = "Roll",            action = "roll",       actionType = "command" },
            { name = "Ready Check",     action = "readycheck", actionType = "command" },
            { name = "Who",             action = "who",        actionType = "command" },
            { name = "Leave Channel",   action = "leave",      actionType = "command" },
            { name = "Reload UI",       action = "reload",     actionType = "command" },
        }
    }
}

local modeOrder = { "emotes", "emotes2", "emotes3", "chat", "party", "commands" }
local currentModeIndex = 1
local currentMode = modeOrder[currentModeIndex]

local function ExecuteAction(mode, index, data)
    if data.actionType == "emote" then
        local alias = "/" .. data.action:upper()
        local token = hash_EmoteTokenList and hash_EmoteTokenList[alias] or data.action:upper()
        C_ChatInfo.PerformEmote(token)
    elseif data.actionType == "command" then
        local editBox = ChatFrameUtil.GetActiveWindow()
        if editBox and editBox:HasFocus() then
            print("EmotePanel: Finish your current chat draft before opening a command.")
            return
        end
        local command = GetCustomMessage(mode, index) or data.action
        EmotePanel.frame:Hide()
        ChatFrameUtil.OpenChat("/" .. command:gsub("^/+", ""))
    else
        local message = GetCustomMessage(mode, index) or data.action
        local channel = data.actionType == "say" and "SAY" or "PARTY"
        C_ChatInfo.SendChatMessage(message, channel)
    end
end

local function RefreshListContent(helpPanel)
    local scrollFrame = helpPanel.scrollFrame
    local content = scrollFrame.content
    local rowIndex, y = 0, 0

    for _, mode in ipairs(modeOrder) do
        local header = content.headers[mode]
        header:SetPoint("TOPLEFT", 0, -y)
        y = y + 24

        for i, data in ipairs(PANEL_MODES[mode].list) do
            rowIndex = rowIndex + 1
            local row = content.rows[rowIndex]
            local customName = GetCustomButtonName(mode, i)
            local customMsg = GetCustomMessage(mode, i)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetWidth(content:GetWidth())
            row:SetText((customName or data.name) .. " - " .. (customMsg or data.action) .. (customMsg and " *" or ""))
            y = y + row:GetStringHeight() + 6
        end
        y = y + 12
    end
    content:SetHeight(y)
end

StaticPopupDialogs["EMOTEPANEL_RESET_BUTTON"] = {
    text = "Are you sure you want to reset this button?\nThis will remove any custom message.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data.index then
            if EmotePanelSavedVars.customMessages[data.mode] then
                EmotePanelSavedVars.customMessages[data.mode][data.index] = nil
            end
            if EmotePanelSavedVars.customButtonNames[data.mode] then
                EmotePanelSavedVars.customButtonNames[data.mode][data.index] = nil
            end

            EmotePanel:RefreshWheel()

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

StaticPopupDialogs["EMOTEPANEL_RESET_ALL"] = {
    text = "Are you sure you want to reset all custom messages?\nThis cannot be undone.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        EmotePanelSavedVars.customMessages = {}
        EmotePanelSavedVars.customButtonNames = {}

        if EmotePanel.frame then
            EmotePanel:RefreshWheel()
        end

        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsShown() then
            helpPanel:refresh()
        end

        print("|cFF00FF00EmotePanel:|r All custom messages have been reset")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
local function SetUpDialogHeader(frame)
    frame.Title:ClearAllPoints()
    frame.Title:SetPoint("CENTER", frame, "TOP", 0, -16)

    local closeButton = _G[frame:GetName() .. "Close"]
    closeButton:ClearAllPoints()
    closeButton:SetPoint("RIGHT", frame, "TOPRIGHT", -6, -16)
end

local function CreateCustomMessageDialog()
    local dialog = CreateFrame("Frame", "EmotePanelCustomMessageDialog", UIParent, "UIPanelDialogTemplate")
    dialog:SetSize(280, 200)
    dialog:SetPoint("CENTER", 0, 200)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)

    SetUpDialogHeader(dialog)
    dialog.Title:SetText("Customize Button")

    -- Name Label
    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOP", 0, -40)
    nameLabel:SetText("Button Name:")

    -- Name EditBox
    local nameBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    nameBox:SetSize(230, 22)
    nameBox:SetPoint("TOP", 2.5, -60)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(18)

    -- Message Label
    local messageLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageLabel:SetPoint("TOP", 0, -90)
    messageLabel:SetText("Message:")

    -- Message EditBox
    local messageBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    messageBox:SetSize(230, 22)
    messageBox:SetPoint("TOP", 2.5, -110)
    messageBox:SetAutoFocus(false)
    messageBox:SetMaxLetters(255)

    -- Save Button
    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 22)
    saveButton:SetPoint("BOTTOMLEFT", 20, 20)
    saveButton:SetText("Save")

    -- Reset Button
    local resetButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resetButton:SetSize(80, 22)
    resetButton:SetPoint("BOTTOM", 0, 20)
    resetButton:SetText("Reset")

    -- Cancel Button
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 22)
    cancelButton:SetPoint("BOTTOMRIGHT", -20, 20)
    cancelButton:SetText("Cancel")

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    -- Tab between fields
    nameBox:SetScript("OnTabPressed", function()
        messageBox:SetFocus()
    end)
    messageBox:SetScript("OnTabPressed", function()
        nameBox:SetFocus()
    end)

    dialog.nameBox = nameBox
    dialog.messageBox = messageBox
    dialog.saveButton = saveButton
    dialog.resetButton = resetButton
    dialog:Hide()


    dialog:SetMovable(true)
    dialog:SetUserPlaced(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", function()
        dialog:StopMovingOrSizing()
    end)

    return dialog
end
-- EmotePanel Methods
function EmotePanel:CreateMainFrame()
    self.frame = CreateFrame("Frame", AddonName .. "Frame", UIParent, "BackdropTemplate")
    local frame = self.frame

    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.063, 0.088, 0.97)
    frame:SetBackdropBorderColor(0.23, 0.34, 0.40, 1)

    -- Drag the panel by its header or margins.
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    return frame
end

-- Sectors start at twelve o'clock and advance clockwise.
local function SectorAt(x, y, count)
    local step = FULL_TURN / count
    return math.floor(math.atan2(x, y) / step + 0.5) % count + 1
end

local function GetEntryName(mode, index, data)
    if data.actionType == "emote" then
        return data.name
    end
    return GetCustomButtonName(mode, index) or data.name
end

function EmotePanel:Select(index)
    local list = PANEL_MODES[currentMode].list
    index = (index - 1) % #list + 1
    if index == self.selected then return end

    if self.selected then
        self.labels[self.selected]:SetTextColor(0.86, 0.91, 0.94)
    end
    self.selected = index
    self.labels[index]:SetTextColor(1, 1, 1)
    self.highlight:SetRotation(-(index - 1) * FULL_TURN / #list)
    self.selectionName:SetText(GetEntryName(currentMode, index, list[index]))
    self.selectionIndex:SetFormattedText("%02d / %02d", index, #list)
end

function EmotePanel:EditButton(mode, index, data)
    if not self.customMessageDialog then
        self.customMessageDialog = CreateCustomMessageDialog()
    end

    local dialog = self.customMessageDialog
    dialog.nameBox:SetText(GetCustomButtonName(mode, index) or data.name)
    dialog.messageBox:SetText(GetCustomMessage(mode, index) or data.action)
    dialog.saveButton:SetScript("OnClick", function()
        local name = dialog.nameBox:GetText()
        local message = dialog.messageBox:GetText()
        if name ~= "" and message ~= "" then
            SaveCustomButtonName(mode, index, name)
            SaveCustomMessage(mode, index, message)
            self:RefreshWheel()

            local helpPanel = _G[AddonName .. "HelpPanel"]
            if helpPanel and helpPanel:IsVisible() then
                helpPanel:refresh()
            end
        end
        dialog:Hide()
    end)
    dialog.resetButton:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_BUTTON", nil, nil, {
            mode = mode,
            index = index,
            dialog = dialog,
        })
    end)
    dialog:Show()
end

function EmotePanel:ActivateSector(index, mouseButton)
    local list = PANEL_MODES[currentMode].list
    local data = list[index]
    self:Select(index)
    if mouseButton == "RightButton" then
        if data.actionType ~= "emote" then
            self:EditButton(currentMode, index, data)
        end
    elseif mouseButton == "LeftButton" then
        ExecuteAction(currentMode, index, data)
    end
end

function EmotePanel:CanUseWheel()
    return not ((self.customMessageDialog and self.customMessageDialog:IsShown())
        or StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON") or StaticPopup_Visible("EMOTEPANEL_RESET_ALL"))
end

function EmotePanel:CreateWheel()
    local wheel = CreateFrame("Frame", nil, self.frame)
    wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    wheel:SetPoint("TOP", 0, -54)
    wheel:EnableMouse(true)
    self.wheel = wheel

    self.wheelArt = wheel:CreateTexture(nil, "BACKGROUND")
    self.wheelArt:SetAllPoints()
    self.highlight = wheel:CreateTexture(nil, "ARTWORK")
    self.highlight:SetAllPoints()

    self.labels = {}
    local maxEntries = 0
    for _, mode in ipairs(modeOrder) do
        maxEntries = math.max(maxEntries, #PANEL_MODES[mode].list)
    end
    for index = 1, maxEntries do
        local label = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetWidth(99)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
        self.labels[index] = label
    end

    local selectionCaption = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selectionCaption:SetPoint("CENTER", 0, 35)
    selectionCaption:SetTextColor(0.48, 0.79, 0.79)
    selectionCaption:SetText("SELECTED")

    self.selectionName = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.selectionName:SetPoint("CENTER")
    self.selectionName:SetWidth(126)
    self.selectionName:SetMaxLines(2)
    self.selectionName:SetTextColor(0.96, 0.99, 1)

    self.selectionIndex = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.selectionIndex:SetPoint("CENTER", 0, -35)
    self.selectionIndex:SetTextColor(0.64, 0.76, 0.83)

    local function SectorUnderCursor(cursorX, cursorY)
        local centerX, centerY = wheel:GetCenter()
        local scale = wheel:GetEffectiveScale()
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        local distanceSquared = x * x + y * y
        if distanceSquared >= 77 * 77 and distanceSquared <= 185 * 185 then
            return SectorAt(x, y, #PANEL_MODES[currentMode].list)
        end
    end

    local lastX, lastY, mouseDownButton, mouseDownSector
    local function UpdateMouseSelection()
        local x, y = GetCursorPosition()
        if x == lastX and y == lastY then return end
        lastX, lastY = x, y
        if not self:CanUseWheel() then return end

        local index = SectorUnderCursor(x, y)
        if not index then
            if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
            return
        end
        if index == self.selected and GameTooltip:IsShown() and GameTooltip:IsOwned(wheel) then return end
        self:Select(index)
        local data = PANEL_MODES[currentMode].list[index]
        GameTooltip:SetOwner(wheel, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText(GetEntryName(currentMode, index, data))
        local action = GetCustomMessage(currentMode, index) or data.action
        GameTooltip:AddLine(action, 1, 1, 1, true)
        if data.actionType ~= "emote" then
            GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end
    local function StopMouseSelection()
        wheel:SetScript("OnUpdate", nil)
        lastX, lastY = nil, nil
        mouseDownButton, mouseDownSector = nil, nil
        if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
    end
    wheel:SetScript("OnEnter", function()
        wheel:SetScript("OnUpdate", UpdateMouseSelection)
        UpdateMouseSelection()
    end)
    wheel:SetScript("OnLeave", StopMouseSelection)
    wheel:SetScript("OnHide", StopMouseSelection)
    wheel:SetScript("OnMouseDown", function(_, mouseButton)
        if (mouseButton == "LeftButton" or mouseButton == "RightButton") and self:CanUseWheel() then
            mouseDownButton = mouseButton
            mouseDownSector = SectorUnderCursor(GetCursorPosition())
        end
    end)
    wheel:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton ~= mouseDownButton then return end
        local pressedSector = mouseDownSector
        mouseDownButton, mouseDownSector = nil, nil
        if not pressedSector or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(GetCursorPosition())
        if index == pressedSector then
            if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
            self:ActivateSector(index, mouseButton)
        end
    end)
end

function EmotePanel:RefreshWheel(selection)
    local list = PANEL_MODES[currentMode].list
    local count = #list
    self.wheelArt:SetTexture(MEDIA .. "Wheel" .. count .. ".tga")
    self.highlight:SetTexture(MEDIA .. "Selection" .. count .. ".tga")
    for index, label in ipairs(self.labels) do
        local data = list[index]
        if data then
            local angle = (index - 1) * FULL_TURN / count
            label:ClearAllPoints()
            label:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * LABEL_RADIUS, math.cos(angle) * LABEL_RADIUS)
            local name = GetEntryName(currentMode, index, data)
            local customMessage = data.actionType ~= "emote" and GetCustomMessage(currentMode, index)
            label:SetText(name .. (customMessage and "*" or ""))
            label:SetTextColor(0.86, 0.91, 0.94)
        end
        label:SetShown(data ~= nil)
    end
    local nextSelection = selection or self.selected or 1
    self.selected = nil
    self:Select(nextSelection)
end

local function CreateTextButton(parent, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 28)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("CENTER")
    button:SetFontString(label)
    button:SetNormalFontObject(GameFontHighlightLarge)
    button:SetHighlightFontObject(GameFontNormalLarge)
    button:SetText(text)
    return button
end

function EmotePanel:CreateControls()
    local frame = self.frame
    local caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("TOP", 0, -10)
    caption:SetTextColor(0.48, 0.79, 0.79)
    caption:SetText("EMOTE WHEEL")

    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", 0, -26)
    self.titleText:SetTextColor(0.96, 0.99, 1)
    self.titleText:SetText(PANEL_MODES[currentMode].title)

    for direction = -1, 1, 2 do
        local arrow = CreateTextButton(frame, direction < 0 and "<" or ">")
        arrow:SetPoint("TOP", direction * 92, -19)
        arrow:SetScript("OnClick", function() self:CycleMode(direction) end)
    end

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -10, -10)

    local help = CreateTextButton(frame, "?")
    help:SetPoint("TOPLEFT", 8, -8)
    help:SetScript("OnClick", function()
        frame:Hide()
        Settings.OpenToCategory(self.settingsCategoryID)
    end)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 22, -442)
    divider:SetPoint("TOPRIGHT", -22, -442)
    divider:SetHeight(1)
    divider:SetColorTexture(0.23, 0.34, 0.40, 1)

    self.navigationHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.navigationHint:SetPoint("TOP", 0, -446)
    self.gamepadHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.gamepadHint:SetPoint("TOP", 0, -483)
    frame:HookScript("OnShow", function() self:RefreshGamepadHint() end)
    if InputDeviceIconSetManager then
        InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(self.RefreshGamepadHint, self)
    end
end

local function GamepadGlyph(key, fallback)
    local icons = InputIconTextureSetUtility
    if icons and icons.GetActiveInputIconButtonTextures(key) then
        local atlas = icons.GetNormalActiveInputIconButtonTexture(key)
        if type(atlas) == "string" then
            return CreateAtlasMarkup(atlas, 32, 32)
        end
    end
    return fallback
end

function EmotePanel:RefreshGamepadHint()
    self.navigationHint:SetText(GamepadGlyph("PADRSTICKAXIS", "Right stick") .. " "
        .. GamepadGlyph("DIRPADVERTICAL", "Up/Down") .. " Select       "
        .. GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " Page")
    local actions = GamepadGlyph("PAD1", "A") .. " Use       "
    if PANEL_MODES[currentMode].list[1].actionType ~= "emote" then
        actions = actions .. GamepadGlyph("PAD4", "Y") .. " Edit       "
    end
    self.gamepadHint:SetText(actions .. GamepadGlyph("PAD2", "B") .. " Close")
end

function EmotePanel:CycleMode(direction)
    currentModeIndex = (currentModeIndex - 1 + direction) % #modeOrder + 1
    currentMode = modeOrder[currentModeIndex]
    self.titleText:SetText(PANEL_MODES[currentMode].title)
    GameTooltip:Hide()
    self:RefreshWheel(1)
    self:RefreshGamepadHint()
end

function EmotePanel:SetupGamepad()
    local frame = self.frame
    local pressed = {}
    local actions = {
        PADDUP = function() self:Select(self.selected - 1) end,
        PADDDOWN = function() self:Select(self.selected + 1) end,
        PADDLEFT = function() self:CycleMode(-1) end,
        PADDRIGHT = function() self:CycleMode(1) end,
        PAD1 = function() self:ActivateSector(self.selected, "LeftButton") end,
        PAD2 = function() frame:Hide() end,
        PAD4 = function() self:ActivateSector(self.selected, "RightButton") end,
    }
    local function CanUsePanelControls(key)
        local data = PANEL_MODES[currentMode].list[self.selected]
        return (key ~= "PAD4" or data.actionType ~= "emote") and self:CanUseWheel()
    end
    frame:SetScript("OnGamePadButtonDown", function(_, key)
        if not actions[key] or IsModifierKeyDown() or not CanUsePanelControls(key) then
            return true
        end
        pressed[key] = true
        return false
    end)
    frame:SetScript("OnGamePadButtonUp", function(_, key)
        if not pressed[key] then return true end
        pressed[key] = nil
        if CanUsePanelControls(key) then
            if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
            actions[key]()
        end
        return false
    end)
    frame:SetScript("OnGamePadStick", function(_, stick, x, y)
        if (stick ~= "Camera" and stick ~= "Right") or IsModifierKeyDown() or not self:CanUseWheel() then
            return true
        end
        if x * x + y * y >= 0.25 then
            if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
            self:Select(SectorAt(x, y, #PANEL_MODES[currentMode].list))
        end
        return false
    end)
    frame:HookScript("OnHide", function()
        wipe(pressed)
        if self.customMessageDialog then
            self.customMessageDialog:Hide()
        end
    end)
    frame:EnableGamePadButton(true)
    frame:EnableGamePadStick(true)
end

function EmotePanel:SavePosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end

    local point, _, relativePoint, x, y = self.frame:GetPoint()
    EmotePanelSavedVars.positions.emotePanel = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

function EmotePanel:LoadPosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end

    local position = EmotePanelSavedVars.positions.emotePanel or DEFAULT_POSITIONS.emotePanel

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
end

function EmotePanel:Initialize()
    EmotePanelSavedVars = EmotePanelSavedVars or {}

    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateControls()
    self:RefreshWheel()
    self:LoadPosition()

    -- Hide by default
    self.frame:Hide()

    -- Make ESC key close the frame
    table.insert(UISpecialFrames, self.frame:GetName())
end

local function CreateHelpPanel(mainPanel)
    local helpPanel = CreateFrame("Frame", AddonName .. "HelpPanel", mainPanel)
    helpPanel.name = "List"
    helpPanel.parent = AddonName

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    helpTitle:SetPoint("TOPLEFT", 16, -16)
    helpTitle:SetText("Emote & Message List")

    -- Create and store scroll frame reference both locally and globally
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", helpPanel,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -30, 20)

    helpPanel.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content.headers = {}
    content.rows = {}
    scrollFrame.content = content
    scrollFrame:SetScrollChild(content)

    for _, mode in ipairs(modeOrder) do
        local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetText(PANEL_MODES[mode].title)
        content.headers[mode] = header
        for _ in ipairs(PANEL_MODES[mode].list) do
            local row = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row:SetJustifyH("LEFT")
            table.insert(content.rows, row)
        end
    end

    helpPanel.refresh = function(self)
        content:SetWidth(scrollFrame:GetWidth())
        RefreshListContent(self)
    end
    helpPanel:SetScript("OnShow", helpPanel.refresh)
    scrollFrame:HookScript("OnSizeChanged", function()
        if helpPanel:IsVisible() then
            helpPanel:refresh()
        end
    end)

    return helpPanel
end

local function CreateCustomizationPanel(mainPanel)
    local customizationPanel = CreateFrame("Frame", AddonName .. "CustomizationPanel", mainPanel)
    customizationPanel.name = "Customization"
    customizationPanel.parent = AddonName

    -- Add customization settings
    local customTitle = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    customTitle:SetPoint("TOPLEFT", 16, -16)
    customTitle:SetText("Wheel Customization")

    -- Add instructions
    local instructions1 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions1:SetPoint("TOPLEFT", customTitle, "BOTTOMLEFT", 0, -8)
    instructions1:SetText("Right-click a Say, Party, or Command sector, or select it and press Y/Triangle to edit.")

    local instructions2 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions2:SetPoint("TOPLEFT", instructions1, "BOTTOMLEFT", 0, -8)
    instructions2:SetText("Use the button below to reset all custom messages.")

    local instructions3 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions3:SetPoint("TOPLEFT", instructions2, "BOTTOMLEFT", 0, -8)
    instructions3:SetText("Commands open in chat. Confirm them there to run them.")

    -- Add button to reset all custom messages
    local resetCustomButton = CreateFrame("Button", nil, customizationPanel, "UIPanelButtonTemplate")
    resetCustomButton:SetSize(200, 26)
    resetCustomButton:SetText("Reset All Custom Messages")
    resetCustomButton:SetPoint("TOPLEFT", instructions3, "BOTTOMLEFT", 0, -10)

    -- Click handlers
    resetCustomButton:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_ALL")
    end)

    return customizationPanel
end

local categoryIDs = {}

local function CreateInterfaceOptions()
    -- Create the main panel (General Settings)
    local mainPanel = CreateFrame("Frame", AddonName .. "OptionsPanel", UIParent)
    mainPanel.name = AddonName

    -- Title at the top
    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("EmotePanel Options")

    -- Description
    local description = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Open with /ep or bind Open or Close Emote Panel in Keybindings.\nAim the right stick to select a sector or use the D-pad.")

    -- Create panels using our panel creation functions
    local customizationPanel = CreateCustomizationPanel(mainPanel)
    local helpPanel = CreateHelpPanel(mainPanel)

    -- Register all panels with the Settings system
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(category)
    EmotePanel.settingsCategoryID = category:GetID()

    Settings.RegisterCanvasLayoutSubcategory(category, customizationPanel, customizationPanel.name)
    local helpCategory = Settings.RegisterCanvasLayoutSubcategory(category, helpPanel, helpPanel.name)
    categoryIDs.help = helpCategory:GetID()

    return mainPanel
end

-- Global toggle function
function EmotePanel_Toggle()
    local frame = EmotePanel.frame
    if not frame then return end
    frame:SetShown(not frame:IsShown())
end

local function ShowHelp()
    print("|cFF00FF00EmotePanel Commands:|r")
    print("  /ep - Toggle EmotePanel")
    print("  /ep help - Show this help message")
    print("  Right stick or D-pad up/down: select. D-pad left/right: change page.")
    print("  A/Cross: use. B/Circle: close. Y/Triangle or right-click: edit a Say, Party, or Command sector.")
    print("  /ep config - Open settings panel")
    print("  /ep reset - Reset all custom messages")
    print("  /ep list - Show emote list panel")
end

local function HandleSlashCommand(msg)
    local command = string.match(msg, "^%s*(%S*)")
    command = command:lower()

    if command == "" then
        EmotePanel_Toggle()
    elseif command == "help" then
        ShowHelp()
    elseif command == "list" then
        if categoryIDs.help then
            EmotePanel.frame:Hide()
            Settings.OpenToCategory(categoryIDs.help)
        else
            print("|cFF00FF00EmotePanel:|r Could not open help panel. Try '/ep config' instead.")
        end
    elseif command == "config" then
        EmotePanel.frame:Hide()
        Settings.OpenToCategory(EmotePanel.settingsCategoryID)
    elseif command == "scroll" then
        print("EmotePanel: All entries are visible on the wheel.")
    elseif command == "reset" then
        StaticPopup_Show("EMOTEPANEL_RESET_ALL")
    else
        print("|cFF00FF00EmotePanel:|r Unknown command. Type /ep help for a list of commands.")
    end
end

-- Register slash commands
SLASH_EMOTEPANEL1 = "/emotepanel"
SLASH_EMOTEPANEL2 = "/ep"
SlashCmdList["EMOTEPANEL"] = HandleSlashCommand

-- Event handling
local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        EmotePanel:SetupGamepad()
        self:UnregisterEvent(event)
    elseif event == "ADDON_LOADED" and select(1, ...) == AddonName then
        EmotePanel:Initialize()
        EmotePanel.optionsPanel = CreateInterfaceOptions()
        self:UnregisterEvent("ADDON_LOADED")
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            EmotePanel:SetupGamepad()
        end

        -- Print login message
        print("|cFF00FF00EmotePanel|r loaded. Type |cFFFFFF00/ep help|r for commands and instructions.")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
