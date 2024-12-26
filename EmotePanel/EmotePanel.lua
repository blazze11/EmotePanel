-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
local helpPanelScrollFrame = nil

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

-- Constants
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 130
local PANEL_WIDTH = 200
local PANEL_HEIGHT = 200



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
    scrollBarStyle = false -- false = basic, true = UI template
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
            { name = "Yes",      action = "nod",       actionType = "emote" },
        }
    },
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",        action = "Hello!",                     actionType = "say" },
            { name = "Well played",   action = "Well played!",               actionType = "say" },
            { name = "Thanks",        action = "Thank you!",                 actionType = "say" },
            { name = "No problem",    action = "No problem!",                actionType = "say" },
            { name = "BRB",           action = "Be right back, quick break", actionType = "say" },
            { name = "Bye",           action = "Bye!",                       actionType = "say" },
            { name = "LFG",           action = "Want to group up?",          actionType = "say" },
            { name = "Placeholder 1", action = "Placeholder 1",              actionType = "say" },
            { name = "Placeholder 1", action = "Placeholder 1",              actionType = "say" },
            { name = "Placeholder 1", action = "Placeholder 1",              actionType = "say" },
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me",     action = "Follow me please!",   actionType = "party" },
            { name = "Need Break",    action = "Need a quick break!", actionType = "party" },
            { name = "Thanks Group",  action = "Thanks everyone!",    actionType = "party" },
            { name = "Good Job",      action = "Great job team!",     actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
            { name = "Placeholder 1", action = "Placeholder 1",       actionType = "party" },
        }
    },
    commands = {
        title = "Commands",
        list = {
            { name = "Reload",          action = "reload",        actionType = "command" },
            { name = "Invite Target",   action = "invite",        actionType = "command" },
            { name = "Inspect Target",  action = "inspect",       actionType = "command" },
            { name = "Trade Target",    action = "trade",         actionType = "command" },
            { name = "Follow Target",   action = "follow",        actionType = "command" },
            { name = "Befriend Target", action = "friend",        actionType = "command" },
            { name = "Roll",            action = "roll",          actionType = "command" },
            { name = "Help",            action = "help",          actionType = "command" },
            { name = "Placeholder 1",   action = "Placeholder 1", actionType = "command" },
            { name = "Placeholder 1",   action = "Placeholder 1", actionType = "command" },
        }
    }
}

local modeOrder = { "chat", "party", "emotes", "emotes2", "emotes3", "commands" }
local currentMode = "chat"
local currentModeIndex = 1

local function ExecuteAction(data)
    if data.actionType == "emote" then
        DoEmote(data.action:upper())
    elseif data.actionType == "say" then
        local customMsg = GetCustomMessage("chat", data.index)
        SendChatMessage(customMsg or data.action, "SAY")
    elseif data.actionType == "party" then
        local customMsg = GetCustomMessage("party", data.index)
        SendChatMessage(customMsg or data.action, "PARTY")
    elseif data.actionType == "command" then
        local customMsg = GetCustomMessage("commands", data.index)
        DEFAULT_CHAT_FRAME.editBox:SetText("/" .. (customMsg or data.action))
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox)
    end
end

local function RefreshListContent(helpPanel)
    -- Get the scroll frame from our global reference or the panel itself
    local scrollFrame = helpPanelScrollFrame or helpPanel.scrollFrame
    if not scrollFrame then return end

    -- Clear existing content
    if scrollFrame.content then
        scrollFrame.content:Hide()
        scrollFrame.content = nil
    end

    -- Create new content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() - 30)
    scrollFrame.content = content

    local lastElement = nil
    local totalHeight = 0

    -- Recreate our list inside the content frame
    for _, mode in ipairs(modeOrder) do
        local modeHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        if not lastElement then
            modeHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 50, 0)
        else
            modeHeader:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
        end
        modeHeader:SetText(PANEL_MODES[mode].title .. ":")
        lastElement = modeHeader
        totalHeight = totalHeight + 10

        local currentConfig = PANEL_MODES[mode]
        local list = currentConfig.list

        for i, data in ipairs(list) do
            local customName = GetCustomButtonName(mode, i)
            local customMsg = GetCustomMessage(mode, i)

            local displayName = customName or data.name
            local displayAction = customMsg or data.action

            local listText = content:CreateFontString(nil, "ARTWORK", "GameFontWhite")
            listText:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -5)
            listText:SetText(displayName .. " - " .. displayAction .. (customMsg and " *" or ""))
            lastElement = listText
            totalHeight = totalHeight + 10
        end
    end

    content:SetHeight(totalHeight)
    scrollFrame:SetScrollChild(content)
end

StaticPopupDialogs["EMOTEPANEL_RESET_BUTTON"] = {
    text = "Are you sure you want to reset this button?\nThis will remove any custom message.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data.index then
            if EmotePanelSavedVars.customMessages[currentMode] then
                EmotePanelSavedVars.customMessages[currentMode][data.index] = nil
            end
            if EmotePanelSavedVars.customButtonNames[currentMode] then
                EmotePanelSavedVars.customButtonNames[currentMode][data.index] = nil
            end

            if data.button then
                data.button:SetText(data.defaultName)
            end

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
-- Create Dialog Frame
local function CreateCustomMessageDialog()
    local dialog = CreateFrame("Frame", "EmotePanelCustomMessageDialog", UIParent, "UIPanelDialogTemplate")
    dialog:SetSize(280, 200)
    dialog:SetPoint("CENTER", 0, 200)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)

    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Customize Button")

    -- Name Label
    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOP", 0, -40)
    nameLabel:SetText("Button Name:")

    -- Name EditBox
    local nameBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    nameBox:SetSize(230, 22)
    nameBox:SetPoint("TOP", 2.5, -60)
    nameBox:SetMaxLetters(18)

    -- Message Label
    local messageLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageLabel:SetPoint("TOP", 0, -90)
    messageLabel:SetText("Message:")

    -- Message EditBox
    local messageBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    messageBox:SetSize(230, 22)
    messageBox:SetPoint("TOP", 2.5, -110)
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

    local closeButton = _G[dialog:GetName() .. "Close"]
    if closeButton then
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 1.5, 1.5)
        closeButton:SetFrameLevel(dialog:GetFrameLevel() + 1)
    end

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
    frame:SetUserPlaced(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    -- Get the close button that was created by UIPanelDialogTemplate
    local closeButton = _G[frame:GetName() .. "Close"]
    if closeButton then
        -- Clear the existing position
        closeButton:ClearAllPoints()
        -- Set the new position - for example, moving it to the top-left corner
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1.5, 1.5)
        -- Optionally adjust the frame level if needed
        closeButton:SetFrameLevel(frame:GetFrameLevel() + 1)
    end

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
    -- Clean up existing scroll frame if it exists
    if self.scrollFrame then
        self.scrollFrame:Hide()
        self.scrollFrame:SetParent(nil)
        self.scrollContent:Hide()
        self.scrollContent:SetParent(nil)
    end

    -- Create scroll frame based on saved style
    if EmotePanelSavedVars.scrollBarStyle then
        self.scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ScrollFrame", self.frame,
            "UIPanelScrollFrameTemplate")
    else
        self.scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ScrollFrame", self.frame)
    end

    self.scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 30, -30)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -30, 10)

    -- Create content frame
    local content = CreateFrame("Frame", AddonName .. "ScrollContent", self.scrollFrame)
    content:SetWidth(150)
    self.scrollFrame:SetScrollChild(content)

    -- Enable mouse wheel scrolling (only needed for basic style)
    if not EmotePanelSavedVars.scrollBarStyle then
        self.scrollFrame:EnableMouseWheel(true)
        self.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local max = self:GetVerticalScrollRange()
            local newScroll = current - (delta * BUTTON_HEIGHT)
            self:SetVerticalScroll(math.max(0, math.min(newScroll, max)))
        end)
    end

    self.scrollContent = content
end

-- Change ToggleScrollBarStyle to SetScrollBarStyle
function EmotePanel:SetScrollBarStyle(enabled)
    -- Set the saved setting directly
    EmotePanelSavedVars.scrollBarStyle = enabled

    -- Rebuild the scroll frame
    self:CreateScrollFrame()

    -- Recreate buttons to properly attach them to the new scroll content
    self:CreateButtons()

    -- Reset scroll position
    self.scrollFrame:SetVerticalScroll(0)

    -- Provide feedback to the user
    local style = enabled and "UI Template" or "Basic"
    print("|cFF00FF00EmotePanel:|r Scroll style changed to " .. style)
end

function EmotePanel:CreateButtons()
    if self.buttons then
        for _, button in ipairs(self.buttons) do
            button:Hide()
            button:SetParent(nil)
        end
    end

    self.buttons = {}
    local currentConfig = PANEL_MODES[currentMode]
    local list = currentConfig.list

    local totalHeight = #list * BUTTON_HEIGHT
    self.scrollContent:SetHeight(totalHeight)

    for i, data in ipairs(list) do
        local button = CreateFrame("Button", AddonName .. "Button" .. i, self.scrollContent, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_WIDTH, 30)
        data.index = i -- Store the index in the data

        -- Add tooltip functionality
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            if data.actionType == "say" or data.actionType == "party" or data.actionType == "command" then
                local customName = GetCustomButtonName(currentMode, i)
                local customMsg = GetCustomMessage(currentMode, i)
                GameTooltip:SetText((customName or data.name) .. (customMsg and "*" or ""))
            else
                GameTooltip:SetText(data.name)
            end
            -- Show custom message if it exists, otherwise show default
            local customMsg = GetCustomMessage(currentMode, i)
            if customMsg then
                GameTooltip:AddLine("Message: " .. customMsg, 0, 1, 0)   -- Custom message in green
            else
                GameTooltip:AddLine("Message: " .. data.action, 1, 1, 1) -- Default message in white
            end

            -- Add right-click hint for customizable buttons
            if data.actionType == "say" or data.actionType == "party" or data.actionType == "command" then
                GameTooltip:AddLine(data.actionType, 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7) -- Grey text
            end

            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        -- Set button text based on custom message if available
        if data.actionType == "say" or data.actionType == "party" or data.actionType == "command" then
            local customName = GetCustomButtonName(currentMode, i)
            local customMsg = GetCustomMessage(currentMode, i)
            button:SetText((customName or data.name) .. (customMsg and "*" or ""))
        else
            button:SetText(data.name)
        end

        button:SetPoint("TOP", self.scrollContent, "TOP", 0, -((i - 1) * (BUTTON_HEIGHT + 10)))

        -- Left click handler
        button:SetScript("OnClick", function(self, buttonClick)
            if buttonClick == "LeftButton" then
                ExecuteAction(data)
            elseif buttonClick == "RightButton" and (data.actionType == "say" or data.actionType == "party" or data.actionType == "command") then
                -- Show custom message dialog
                if not EmotePanel.customMessageDialog then
                    EmotePanel.customMessageDialog = CreateCustomMessageDialog()
                end

                local dialog = EmotePanel.customMessageDialog
                local currentButton = button -- Store reference to current button

                -- Set current values
                dialog.nameBox:SetText(GetCustomButtonName(currentMode, i) or data.name)
                dialog.messageBox:SetText(GetCustomMessage(currentMode, i) or data.action)

                dialog.saveButton:SetScript("OnClick", function()
                    local newName = dialog.nameBox:GetText()
                    local newMessage = dialog.messageBox:GetText()

                    if newName ~= "" and newMessage ~= "" then
                        SaveCustomButtonName(currentMode, i, newName)
                        SaveCustomMessage(currentMode, i, newMessage)
                        currentButton:SetText(newName .. "*")

                        print("|cFF00FF00EmotePanel:|r Button saved")

                        -- Refresh help panel if it exists and is shown
                        if EmotePanel.optionsPanel then
                            local helpPanel = _G[AddonName .. "HelpPanel"]
                            if helpPanel and helpPanel:IsShown() then
                                RefreshListContent(helpPanel)
                            end
                        end
                    end
                    dialog:Hide()
                end)

                dialog.resetButton:SetScript("OnClick", function()
                    StaticPopup_Show("EMOTEPANEL_RESET_BUTTON", nil, nil, {
                        index = i,
                        dialog = dialog,
                        button = currentButton,
                        defaultName = data.name,
                        defaultAction = data.action

                    }
                    ) -- Refresh help panel if it exists and is shown
                    if EmotePanel.optionsPanel then
                        local helpPanel = _G[AddonName .. "HelpPanel"]
                        if helpPanel and helpPanel:IsShown() then
                            RefreshListContent(helpPanel)
                        end
                    end
                end)
                dialog:Show()
            end
        end)

        -- Enable right-click functionality
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        table.insert(self.buttons, button)
    end
end

function EmotePanel:CreateControls()
    -- Title
    self.titleText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.titleText:SetPoint("TOP", self.frame, "TOP", 0, -10)
    self.titleText:SetText(PANEL_MODES[currentMode].title)

    -- Mode cycle button
    local modeButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    modeButton:SetPoint("CENTER", self.frame, "CENTER", -75, -15)
    modeButton:SetSize(24, 24)
    modeButton:SetText("<")
    modeButton:SetScript("OnClick", function()
        local newTitle = self:CycleMode()
        self.titleText:SetText(newTitle)
        self:CreateButtons()
        self.scrollFrame:SetVerticalScroll(0)
    end)

    -- List toggle button
    local listButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    listButton:SetPoint("CENTER", self.frame, "BOTTOM", -75, 25)
    listButton:SetSize(24, 24)
    listButton:SetText("?")
    listButton:SetScript("OnClick", function()
        Settings.OpenToCategory(AddonName)
    end)
end

function EmotePanel:CycleMode()
    currentModeIndex = currentModeIndex % #modeOrder + 1
    currentMode = modeOrder[currentModeIndex]
    return PANEL_MODES[currentMode].title
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
    tinsert(UISpecialFrames, self.frame:GetName())
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
    helpPanelScrollFrame = scrollFrame -- Store global reference

    -- Add refresh method
    helpPanel.refresh = function(self)
        RefreshListContent(self)
    end

    -- Set up initial content
    RefreshListContent(helpPanel)

    -- OnShow handler
    helpPanel:SetScript("OnShow", function(self)
        self:refresh()
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
    instructions3:SetText("This action cannot be undone!")

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

    -- Create scroll style checkbox with proper template
    local scrollStyleCheckbox = CreateFrame("CheckButton", AddonName .. "ScrollStyleCheckbox", appearancePanel,
        "InterfaceOptionsCheckButtonTemplate")
    scrollStyleCheckbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)

    -- Set the checkbox text
    local checkboxText = _G[scrollStyleCheckbox:GetName() .. "Text"]
    checkboxText:SetText("Show Scrollbar")

    -- Add tooltip
    scrollStyleCheckbox.tooltipText = "Toggle between basic scrolling and the standard UI scrollbar"

    -- Set initial state from saved variables
    scrollStyleCheckbox:SetChecked(EmotePanelSavedVars.scrollBarStyle)

    -- Update the checkbox script
    scrollStyleCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        EmotePanelSavedVars.scrollBarStyle = checked
        EmotePanel:SetScrollBarStyle(checked)
    end)

    -- Store reference to checkbox for refresh function
    appearancePanel.scrollStyleCheckbox = scrollStyleCheckbox

    -- Add refresh method
    appearancePanel.refresh = function(self)
        self.scrollStyleCheckbox:SetChecked(EmotePanelSavedVars.scrollBarStyle)
    end

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
    description:SetText("Configure settings for the EmotePanel addon.")

    -- Create panels using our panel creation functions
    local appearancePanel = CreateAppearancePanel(mainPanel)
    local customizationPanel = CreateCustomizationPanel(mainPanel)
    local helpPanel = CreateHelpPanel(mainPanel)

    -- Register all panels with the Settings system
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    category.ID = AddonName
    Settings.RegisterAddOnCategory(category)

    -- Register subcategories and store their IDs
    local appearanceCategory = Settings.RegisterCanvasLayoutSubcategory(category, appearancePanel, appearancePanel.name)
    appearanceCategory.ID = AddonName .. ".Appearance"
    categoryIDs.appearance = appearanceCategory.ID

    local customizationCategory = Settings.RegisterCanvasLayoutSubcategory(category, customizationPanel,
        customizationPanel.name)
    customizationCategory.ID = AddonName .. ".Customization"
    categoryIDs.customization = customizationCategory.ID

    local helpCategory = Settings.RegisterCanvasLayoutSubcategory(category, helpPanel, helpPanel.name)
    helpCategory.ID = AddonName .. ".Help"
    categoryIDs.help = helpCategory.ID

    return mainPanel
end

-- Global toggle function
function EmotePanel_Toggle()
    if EmotePanel.frame:IsShown() then
        -- Panel is shown, cycle to next mode
        local title = EmotePanel:CycleMode()
        EmotePanel.titleText:SetText(title)
        EmotePanel:CreateButtons()
        EmotePanel.scrollFrame:SetVerticalScroll(0)
    else
        -- Panel is hidden, just show it
        EmotePanel.frame:Show()
    end
end

local function ShowHelp()
    print("|cFF00FF00EmotePanel Commands:|r")
    print("  /ep - Toggle EmotePanel")
    print("  /ep help - Show this help message")
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
            Settings.OpenToCategory(categoryIDs.help)
        else
            print("|cFF00FF00EmotePanel:|r Could not open help panel. Try '/ep config' instead.")
        end
    elseif command == "config" then
        Settings.OpenToCategory(AddonName)
    elseif command == "scroll" then
        if param == "on" then
            EmotePanelSavedVars.scrollBarStyle = true
            EmotePanel:SetScrollBarStyle(true)
        elseif param == "off" then
            EmotePanelSavedVars.scrollBarStyle = false
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
    if event == "ADDON_LOADED" and select(1, ...) == AddonName then
        EmotePanel:Initialize()
        EmotePanel.optionsPanel = CreateInterfaceOptions()
        self:UnregisterEvent("ADDON_LOADED")

        -- Print login message
        print("|cFF00FF00EmotePanel|r loaded. Type |cFFFFFF00/ep help|r for commands and instructions.")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
