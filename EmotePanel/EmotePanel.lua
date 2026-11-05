-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

-- Constants
local BUTTON_HEIGHT = 26
local ROW_HEIGHT = 30
local BUTTON_WIDTH = 162
local VISIBLE_ROWS = 6
local HEADER_CENTER_Y = -16
local LIST_SIDE_INSET = 30
local LIST_TOP_INSET = 38
local LIST_BOTTOM_INSET = 54
local PANEL_WIDTH = 236
local PANEL_HEIGHT = LIST_TOP_INSET + VISIBLE_ROWS * ROW_HEIGHT + LIST_BOTTOM_INSET

-- Default positions for the panels
local DEFAULT_POSITIONS = {
    emotePanel = {
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = 0
    },
}

local DEFAULT_SETTINGS = {
    scrollBarStyle = false
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

            EmotePanel:CreateButtons()

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
            EmotePanel:CreateButtons()
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
    frame.Title:SetPoint("CENTER", frame, "TOP", 0, HEADER_CENTER_Y)

    local closeButton = _G[frame:GetName() .. "Close"]
    closeButton:ClearAllPoints()
    closeButton:SetPoint("RIGHT", frame, "TOPRIGHT", -6, HEADER_CENTER_Y)
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
    self.frame = CreateFrame("Frame", AddonName .. "Frame", UIParent, "UIPanelDialogTemplate")
    local frame = self.frame

    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    SetUpDialogHeader(frame)

    -- Make frame draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    return frame
end

function EmotePanel:CreateScrollFrame()
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ScrollFrame", self.frame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", LIST_SIDE_INSET, -LIST_TOP_INSET)
    scrollFrame:SetPoint("BOTTOMRIGHT", -LIST_SIDE_INSET, LIST_BOTTOM_INSET)
    scrollFrame.ScrollBar.scrollStep = ROW_HEIGHT
    scrollFrame:HookScript("OnScrollRangeChanged", function(frame)
        if not EmotePanelSavedVars.scrollBarStyle then
            frame.ScrollBar:Hide()
        end
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(PANEL_WIDTH - 2 * LIST_SIDE_INSET)
    scrollFrame:SetScrollChild(content)
    self.scrollFrame = scrollFrame
    self.scrollContent = content
    self:SetScrollBarStyle(EmotePanelSavedVars.scrollBarStyle)
end

function EmotePanel:SetScrollBarStyle(enabled)
    EmotePanelSavedVars.scrollBarStyle = enabled
    self.scrollFrame.ScrollBar:SetShown(enabled)
end

function EmotePanel:Select(index)
    local count = #PANEL_MODES[currentMode].list
    if self.selected then
        self.buttons[self.selected]:UnlockHighlight()
    end
    self.selected = math.max(1, math.min(index, count))
    self.buttons[self.selected]:LockHighlight()

    local top = (self.selected - 1) * ROW_HEIGHT
    local scrollFrame = self.scrollFrame
    local offset = scrollFrame:GetVerticalScroll()
    local bottomOffset = top + ROW_HEIGHT - scrollFrame:GetHeight()
    if top < offset then
        scrollFrame:SetVerticalScroll(top)
    elseif bottomOffset > offset then
        scrollFrame:SetVerticalScroll(math.min(bottomOffset, scrollFrame:GetVerticalScrollRange()))
    end
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
            self:CreateButtons()

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

function EmotePanel:CreateButtons(selection)
    local mode = currentMode
    local list = PANEL_MODES[mode].list
    self.scrollContent:SetHeight(#list * ROW_HEIGHT)
    self.buttons = self.buttons or {}

    for index, data in ipairs(list) do
        local button = self.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, self.scrollContent, "UIPanelButtonTemplate")
            button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
            button:SetPoint("TOP", 0, -(index - 1) * ROW_HEIGHT)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            self.buttons[index] = button
        end

        local customizable = data.actionType ~= "emote"
        button.customizable = customizable
        local customName = customizable and GetCustomButtonName(mode, index)
        local customMessage = customizable and GetCustomMessage(mode, index)
        button:SetText((customName or data.name) .. (customMessage and "*" or ""))
        button:SetScript("OnEnter", function(row)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row:GetText())
            GameTooltip:AddLine(customMessage or data.action, 1, 1, 1, true)
            if data.actionType == "command" then
                GameTooltip:AddLine("Opens in chat for confirmation", 0.7, 0.7, 0.7)
            end
            if customizable then
                GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "LeftButton" then
                self:Select(index)
                ExecuteAction(mode, index, data)
            elseif mouseButton == "RightButton" and customizable then
                self:EditButton(mode, index, data)
            end
        end)
        button:Show()
    end

    for index = #list + 1, #self.buttons do
        self.buttons[index]:Hide()
    end
    self:Select(selection or self.selected or 1)
end

function EmotePanel:CreateControls()
    local frame = self.frame
    self.titleText = frame.Title
    self.titleText:SetText(PANEL_MODES[currentMode].title)

    local previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    previous:SetSize(24, 18)
    previous:SetPoint("CENTER", frame, "TOP", -66, HEADER_CENTER_Y)
    previous:SetText("<")
    previous:SetScript("OnClick", function()
        self:CycleMode(-1)
    end)

    local nextPage = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextPage:SetSize(24, 18)
    nextPage:SetPoint("CENTER", frame, "TOP", 66, HEADER_CENTER_Y)
    nextPage:SetText(">")
    nextPage:SetScript("OnClick", function()
        self:CycleMode(1)
    end)

    local help = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    help:SetSize(21, 21)
    help:SetPoint("BOTTOMRIGHT", -9, 10)
    help:SetText("?")
    help:SetScript("OnClick", function()
        frame:Hide()
        Settings.OpenToCategory(self.settingsCategoryID)
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 12)
    hint:SetPoint("BOTTOMRIGHT", help, "BOTTOMLEFT", -8, 2)
    hint:SetJustifyH("CENTER")
    self.gamepadHint = hint
    frame:HookScript("OnShow", function()
        self:RefreshGamepadHint()
    end)
    if InputDeviceIconSetManager then
        InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(self.RefreshGamepadHint, self)
    end
end

local function GamepadGlyph(key, fallback)
    local icons = InputIconTextureSetUtility
    if icons and icons.GetActiveInputIconButtonTextures(key) then
        local atlas = icons.GetNormalActiveInputIconButtonTexture(key)
        if type(atlas) == "string" then
            return CreateAtlasMarkup(atlas, 16, 16)
        end
    end
    return fallback
end

function EmotePanel:RefreshGamepadHint()
    local direction = GamepadGlyph("DIRPADVERTICAL", "Up/Down") .. " Select    "
        .. GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " Page"
    local actions = GamepadGlyph("PAD1", "A") .. " Use    "
    if self.buttons and self.buttons[self.selected].customizable then
        actions = actions .. GamepadGlyph("PAD4", "Y") .. " Edit    "
    end
    self.gamepadHint:SetText(direction .. "\n" .. actions .. GamepadGlyph("PAD2", "B") .. " Close")
end

function EmotePanel:CycleMode(direction)
    currentModeIndex = (currentModeIndex - 1 + direction) % #modeOrder + 1
    currentMode = modeOrder[currentModeIndex]
    self.titleText:SetText(PANEL_MODES[currentMode].title)
    GameTooltip:Hide()
    self.scrollFrame:SetVerticalScroll(0)
    self:CreateButtons(1)
    self:RefreshGamepadHint()
end

function EmotePanel:ClickSelected(mouseButton)
    local scrollFrame = self.scrollFrame
    local top = (self.selected - 1) * ROW_HEIGHT
    local offset = scrollFrame:GetVerticalScroll()
    if top < offset or top + BUTTON_HEIGHT > offset + scrollFrame:GetHeight() then
        self:Select(self.selected)
        return
    end
    self.buttons[self.selected]:Click(mouseButton)
end

function EmotePanel:SetupGamepad()
    local frame = self.frame
    local pressed = {}
    local actions = {
        PADDUP = function() self:Select(self.selected - 1) end,
        PADDDOWN = function() self:Select(self.selected + 1) end,
        PADDLEFT = function() self:CycleMode(-1) end,
        PADDRIGHT = function() self:CycleMode(1) end,
        PAD1 = function() self:ClickSelected("LeftButton") end,
        PAD2 = function() frame:Hide() end,
        PAD4 = function() self:ClickSelected("RightButton") end,
    }
    local function CanUsePanelControls(key)
        return (key ~= "PAD4" or self.buttons[self.selected].customizable)
            and not ((self.customMessageDialog and self.customMessageDialog:IsShown())
            or StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON") or StaticPopup_Visible("EMOTEPANEL_RESET_ALL"))
    end
    frame:SetScript("OnGamePadButtonDown", function(_, key)
        if not actions[key] or IsModifierKeyDown() or not CanUsePanelControls(key) then
            return true
        end
        pressed[key] = true
        return false
    end)
    frame:SetScript("OnGamePadButtonUp", function(_, key)
        if not pressed[key] then
            return true
        end
        pressed[key] = nil
        if CanUsePanelControls(key) then
            actions[key]()
        end
        return false
    end)
    frame:SetScript("OnHide", function()
        wipe(pressed)
        if self.customMessageDialog then
            self.customMessageDialog:Hide()
        end
    end)
    frame:EnableGamePadButton(true)
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

-- Modify the Initialize function to set default scroll style
function EmotePanel:Initialize()
    -- Initialize saved variables
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if EmotePanelSavedVars.scrollBarStyle == nil then
        EmotePanelSavedVars.scrollBarStyle = DEFAULT_SETTINGS.scrollBarStyle
    end

    self:CreateMainFrame()
    self:CreateScrollFrame()
    self:CreateControls()
    self:CreateButtons()
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
    helpTitle:SetText("Button & Message List")

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
    customTitle:SetText("Button Customization")

    -- Add instructions
    local instructions1 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions1:SetPoint("TOPLEFT", customTitle, "BOTTOMLEFT", 0, -8)
    instructions1:SetText("You can customize chat and party messages by right-clicking the buttons in the main panel.")

    local instructions2 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions2:SetPoint("TOPLEFT", instructions1, "BOTTOMLEFT", 0, -8)
    instructions2:SetText("Use the button below to reset all custom messages.")

    local instructions3 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions3:SetPoint("TOPLEFT", instructions2, "BOTTOMLEFT", 0, -8)
    instructions3:SetText("Commands open in chat. Confirm them there to run them.")

    -- Add button to reset all custom messages
    local resetCustomButton = CreateFrame("Button", nil, customizationPanel, "UIPanelButtonTemplate")
    resetCustomButton:SetSize(200, BUTTON_HEIGHT)
    resetCustomButton:SetText("Reset All Custom Messages")
    resetCustomButton:SetPoint("TOPLEFT", instructions3, "BOTTOMLEFT", 0, -10)

    -- Click handlers
    resetCustomButton:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_ALL")
    end)

    return customizationPanel
end

local function CreateAppearancePanel(mainPanel)
    local appearancePanel = CreateFrame("Frame", AddonName .. "AppearancePanel", mainPanel)
    appearancePanel.name = "Appearance"
    appearancePanel.parent = AddonName

    -- Add appearance settings
    local appearanceTitle = appearancePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    appearanceTitle:SetPoint("TOPLEFT", 16, -16)
    appearanceTitle:SetText("Appearance Settings")

    -- Add description
    local description = appearancePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", appearanceTitle, "BOTTOMLEFT", 0, -8)
    description:SetText("Customize the appearance of your EmotePanel.")

    local scrollStyleCheckbox = CreateFrame("CheckButton", nil, appearancePanel, "UICheckButtonTemplate")
    scrollStyleCheckbox:SetSize(26, 26)
    scrollStyleCheckbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)

    -- Set the checkbox text
    local checkboxText = appearancePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkboxText:SetPoint("LEFT", scrollStyleCheckbox, "RIGHT", 4, 0)
    checkboxText:SetText("Show scrollbar")

    -- Add tooltip
    scrollStyleCheckbox.tooltipText = "Toggle between basic scrolling and the standard UI scrollbar"

    -- Set initial state from saved variables
    scrollStyleCheckbox:SetChecked(EmotePanelSavedVars.scrollBarStyle)

    -- Update the checkbox script
    scrollStyleCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        EmotePanel:SetScrollBarStyle(checked)
    end)

    -- Store reference to checkbox for refresh function
    appearancePanel.scrollStyleCheckbox = scrollStyleCheckbox

    -- Add refresh method
    appearancePanel:SetScript("OnShow", function(self)
        self.scrollStyleCheckbox:SetChecked(EmotePanelSavedVars.scrollBarStyle)
    end)

    return appearancePanel
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
    description:SetText("Open with /ep or bind Open or Close Emote Panel in Keybindings.\nUse the D-pad to select a row or change pages.")

    -- Create panels using our panel creation functions
    local appearancePanel = CreateAppearancePanel(mainPanel)
    local customizationPanel = CreateCustomizationPanel(mainPanel)
    local helpPanel = CreateHelpPanel(mainPanel)

    -- Register all panels with the Settings system
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(category)
    EmotePanel.settingsCategoryID = category:GetID()

    Settings.RegisterCanvasLayoutSubcategory(category, appearancePanel, appearancePanel.name)
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
    print("  D-pad up/down: select. Left/right: change page. A/Cross: use. B/Circle: close.")
    print("  Y/Triangle or right-click: edit a Say, Party, or Command button.")
    print("  /ep config - Open settings panel")
    print("  /ep scroll [on|off] - Toggle scrollbar style")
    print("  /ep reset - Reset all custom messages")
    print("  /ep list - Show emote list panel")
end

local function HandleSlashCommand(msg)
    -- Split the message into command and parameter
    local command, param = string.match(msg, "^(%S*)%s*(.-)$")
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
        if param == "on" then
            EmotePanel:SetScrollBarStyle(true)
        elseif param == "off" then
            EmotePanel:SetScrollBarStyle(false)
        else
            print("|cFF00FF00EmotePanel:|r Usage: /ep scroll [on|off]")
        end
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
