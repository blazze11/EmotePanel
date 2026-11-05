-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

local PANEL_WIDTH, PANEL_HEIGHT = 432, 548
local WHEEL_SIZE = 382
local SECTOR_COUNT = 8
local SECTOR_ANGLE = 2 * math.pi / SECTOR_COUNT
local WHEEL_ATLAS = "gamepad-radial-menu-wheelbg"
local SELECTION_ATLAS = "gamepad-radial-menu-selected"
local ICON_BORDER = "gamepad-actionbar-circleslot-border-normal"
local SELECTED_ICON_BORDER = "gamepad-actionbar-circleslot-border-selected"
local ICON_PATH = "Interface\\Icons\\"
local PANEL_ATLAS = "gamepad-footer-slot-bg"
local PANEL_BORDER_ATLAS = "gamepad-footer-slot-frameneutral"
local FOCUS_ATLAS = "gamepad-footer-slot-framefocused"
local SIT_INDEX = 30 -- Favorites store the original emote slot number.
local SELECTION_COLORS = {
    say = { 0.36, 0.84, 1 },
    party = { 0.48, 1, 0.46 },
    command = { 0.82, 0.54, 1 },
}

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
        title = "Emotes",
        list = {
            { name = "Angry",    action = "angry",    actionType = "emote", icon = "Spell_Misc_EmotionAngry" },
            { name = "Applause", action = "bravo",    actionType = "emote", icon = "Spell_Holy_DivineHymn" },
            { name = "Blush",    action = "blush",    actionType = "emote", icon = "INV_Misc_Flower_02" },
            { name = "Bow",      action = "bow",      actionType = "emote", icon = "Ability_Warrior_Vigilance" },
            { name = "Cackle",   action = "cackle",   actionType = "emote", icon = "INV_Helm_LaughingSkull_01" },
            { name = "Cheer",    action = "cheer",    actionType = "emote", icon = "Ability_Warrior_BattleShout" },
            { name = "Cry",      action = "cry",      actionType = "emote", icon = "Spell_Misc_EmotionSad" },
            { name = "Dance",    action = "dance",    actionType = "emote", icon = "INV_Misc_FireDancer_01" },
            { name = "Facepalm", action = "facepalm", actionType = "emote", icon = "Spell_Holy_BlindingHeal" },
            { name = "Flex",     action = "flex",     actionType = "emote", icon = "Ability_Warrior_StrengthOfArms" },
            { name = "Golfclap", action = "golfclap", actionType = "emote", icon = "Spell_Holy_SealOfWisdom" },
            { name = "Goodbye",  action = "bye",      actionType = "emote", icon = "Spell_Magic_LesserInvisibilty" },
            { name = "Hug",      action = "hug",      actionType = "emote", icon = "Spell_druid_bearhug" },
            { name = "Kiss",     action = "kiss",     actionType = "emote", icon = "Spell_Shadow_SoothingKiss" },
            { name = "Kneel",    action = "kneel",    actionType = "emote", icon = "Ability_Stealth" },
            { name = "Laugh",    action = "laugh",    actionType = "emote", icon = "Spell_Misc_EmotionHappy" },
            { name = "No",       action = "no",       actionType = "emote", icon = "Spell_Holy_SealOfSalvation" },
            { name = "Point",    action = "point",    actionType = "emote", icon = "Ability_Hunter_MarkedForDeath" },
            { name = "Roar",     action = "roar",     actionType = "emote", icon = "Ability_Druid_ChallangingRoar" },
            { name = "Rude",     action = "rude",     actionType = "emote", icon = "Ability_Physical_Taunt" },
            { name = "Salute",   action = "salute",    actionType = "emote", icon = "INV_Misc_Head_Human_01" },
            { name = "Sigh",     action = "sigh",      actionType = "emote", icon = "Spell_Nature_Sleep" },
            { name = "Sorry",    action = "apologize", actionType = "emote", icon = "Spell_Holy_PrayerOfMendingtga" },
            { name = "Stand",    action = "stand",     actionType = "emote", icon = "Ability_Warrior_SecondWind" },
            { name = "Talk",     action = "talk",      actionType = "emote", icon = "UI_Chat" },
            { name = "Thank",    action = "thank",     actionType = "emote", icon = "INV_Misc_Gift_01" },
            { name = "Threaten", action = "threaten",  actionType = "emote", icon = "Ability_Physical_Taunt_purple" },
            { name = "Wave",     action = "wave",      actionType = "emote", icon = "Spell_Holy_LayOnHands" },
            { name = "Yes",      action = "nod",       actionType = "emote", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "Sit",      action = "sit",       actionType = "emote", icon = "INV_FISHINGCHAIR" },
        }
    },
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",      action = "Hello! Hope you're having a great day!", actionType = "say", icon = "Spell_Misc_EmotionHappy" },
            { name = "Well played", action = "Well played! That was awesome!",         actionType = "say", icon = "Achievement_General_StayClassy" },
            { name = "Thanks",      action = "Thank you! Really appreciate it!",       actionType = "say", icon = "INV_Misc_GiftWrap_01" },
            { name = "No problem",  action = "No problem! Happy to help!",             actionType = "say", icon = "Spell_Holy_BlessingOfProtection" },
            { name = "BRB",         action = "Be right back, quick break",             actionType = "say", icon = "INV_Misc_PocketWatch_01" },
            { name = "Bye",         action = "Farewell! Have a great adventure!",      actionType = "say", icon = "INV_Garrison_Hearthstone" },
            { name = "LFG",         action = "Looking for group! Anyone interested?",  actionType = "say", icon = "INV_Misc_GroupLooking" },
            { name = "Quest",       action = "Anyone working on this quest?",          actionType = "say", icon = "INV_Misc_Book_09" },
            { name = "Gratz",       action = "Congratulations!",                       actionType = "say", icon = "INV_Misc_CelebrationCake_01" },
            { name = "Trade",       action = "Would you like to trade?",               actionType = "say", icon = "INV_Misc_Coin_01" },
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me",    action = "Follow me please!",                     actionType = "party", icon = "Ability_Hunter_Pathfinding" },
            { name = "Need Break",   action = "Need a quick break! Back in 5 minutes", actionType = "party", icon = "INV_Drink_05" },
            { name = "Thanks Group", action = "Thanks everyone for the great run!",    actionType = "party", icon = "INV_Misc_GiftWrap_02" },
            { name = "Good Job",     action = "Great job team! Well executed!",        actionType = "party", icon = "Achievement_Level_10" },
            { name = "Ready Check",  action = "Everyone ready to continue?",           actionType = "party", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "OOM",          action = "Out of mana, need to drink!",           actionType = "party", icon = "INV_Potion_76" },
            { name = "Wait",         action = "Please wait for everyone!",             actionType = "party", icon = "INV_Misc_PocketWatch_02" },
            { name = "Pulling",      action = "Pulling in 5 seconds!",                 actionType = "party", icon = "Ability_Hunter_SniperShot" },
            { name = "CC",           action = "Please use crowd control!",             actionType = "party", icon = "Spell_Nature_Polymorph" },
            { name = "Help",         action = "Need help here!",                       actionType = "party", icon = "Spell_Holy_Resurrection" },
        }
    },
    commands = {
        title = "Commands",
        list = {
            -- Saved commands and favorites refer to these slot numbers. Append new entries.
            { name = "Invite Target",   action = "invite",     actionType = "command", icon = "INV_Misc_GroupNeedMore" },
            { name = "Inspect Target",  action = "inspect",    actionType = "command", icon = "INV_Professions_Inscription_ScribesMagnifyingGlass_Gold" },
            { name = "Trade Target",    action = "trade",      actionType = "command", icon = "INV_Misc_Coin_02" },
            { name = "Follow Target",   action = "follow",     actionType = "command", icon = "Ability_Tracking" },
            { name = "Befriend Target", action = "friend",     actionType = "command", icon = "INV_ValentinesCard01" },
            { name = "Roll",            action = "roll",       actionType = "command", icon = "INV_Misc_Dice_02" },
            { name = "Ready Check",     action = "readycheck", actionType = "command", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "Who",             action = "who",        actionType = "command", icon = "INV_Misc_Spyglass_02" },
            { name = "Leave Channel",   action = "leave",      actionType = "command", icon = "Spell_Shadow_Teleport" },
            { name = "Reload UI",       action = "reload",     actionType = "command", icon = "INV_Misc_Gear_01" },
            { name = "Pull in 5s",      action = (SLASH_COUNTDOWN1 or "/countdown") .. " 5", actionType = "command", icon = "INV_Misc_PocketWatch_01" },
            { name = "Pull in 10s",     action = (SLASH_COUNTDOWN1 or "/countdown") .. " 10", actionType = "command", icon = "INV_Misc_PocketWatch_03" },
            { name = "Mark Skull",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " !8", actionType = "command", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8" },
            { name = "Mark Cross",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " !7", actionType = "command", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7" },
            { name = "Clear Mark",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " 0", actionType = "command", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
            { name = "Dismount",        action = SLASH_DISMOUNT1 or "/dismount", actionType = "command", icon = "Ability_Mount_RidingHorse" },
        }
    }
}

local modeOrder = { "emotes", "chat", "party", "commands" }
local categoryPages = {}
for _, mode in ipairs(modeOrder) do
    local config = PANEL_MODES[mode]
    local pageCount = math.ceil(#config.list / SECTOR_COUNT)
    for first = 1, #config.list, SECTOR_COUNT do
        local number = math.floor((first - 1) / SECTOR_COUNT) + 1
        table.insert(categoryPages, {
            mode = mode,
            first = first,
            count = math.min(SECTOR_COUNT, #config.list - first + 1),
            title = ("%s  %d / %d"):format(config.title, number, pageCount),
        })
    end
end
local currentPageIndex, currentPage
local favorites

local function FavoritePageCount()
    return math.max(1, math.ceil(#favorites / SECTOR_COUNT))
end

local function GetPage(index)
    local count = FavoritePageCount()
    if index > count then return categoryPages[index - count] end
    local first = (index - 1) * SECTOR_COUNT + 1
    return {
        mode = "favorites",
        first = first,
        count = math.min(SECTOR_COUNT, #favorites - first + 1),
        title = count == 1 and "Favorites" or ("Favorites  %d / %d"):format(index, count),
    }
end

local function FindFavorite(mode, index)
    for position, entry in ipairs(favorites) do
        if entry.mode == mode and entry.index == index then return position end
    end
end

local function LoadFavorites()
    local saved = EmotePanelSavedVars.favorites
    favorites = {}
    if type(saved) == "table" then
        for _, entry in ipairs(saved) do
            local mode = type(entry) == "table" and PANEL_MODES[entry.mode]
            if mode and mode.list[entry.index] and not FindFavorite(entry.mode, entry.index) then
                table.insert(favorites, { mode = entry.mode, index = entry.index })
            end
        end
    end
    if not EmotePanelSavedVars.sitFavoriteAdded then
        if not FindFavorite("emotes", SIT_INDEX) then
            table.insert(favorites, 1, { mode = "emotes", index = SIT_INDEX })
        end
        EmotePanelSavedVars.sitFavoriteAdded = true
    end
    EmotePanelSavedVars.favorites = favorites
end

local function GetSectorEntry(sector)
    if not sector or sector < 1 or sector > currentPage.count then return end
    local mode = currentPage.mode
    local index = currentPage.first + sector - 1
    if mode == "favorites" then
        local entry = favorites[index]
        mode, index = entry.mode, entry.index
    end
    return mode, index, PANEL_MODES[mode].list[index]
end

local targetCommands = {
    ["/inspect"] = "target",
    ["/trade"] = "target",
    ["/invite"] = "name",
    ["/follow"] = "name",
    ["/friend"] = "name",
    ["/addfriend"] = "name",
    ["/tm"] = "marker",
    ["/targetmarker"] = "marker",
}
for key, kind in pairs({
    INSPECT = "target", TRADE = "target", INVITE = "name",
    REQUEST_INVITE = "name", FOLLOW = "name", FRIENDS = "name", TARGET_MARKER = "marker",
}) do
    local index = 1
    while _G["SLASH_" .. key .. index] do
        targetCommands[_G["SLASH_" .. key .. index]:lower()] = kind
        index = index + 1
    end
end

local function HasLockedTarget()
    return UnitExists("target") and not IsTargetLoose()
end

local function NeedsLockedTarget(verb, arguments)
    local kind = targetCommands[verb]
    if kind == "target" then return true end
    if kind == "name" then return arguments == "" end
    if kind == "marker" then
        if not arguments:find("[", 1, true) then return true end
        local _, unit = SecureCmdOptionParse(arguments)
        return issecretvalue(unit) or not unit or unit == "target"
    end
    return false
end

local function ExecuteAction(mode, index, data)
    if data.actionType == "emote" then
        local alias = "/" .. data.action:upper()
        local token = hash_EmoteTokenList and hash_EmoteTokenList[alias] or data.action:upper()
        local targetName = not HasLockedTarget() and "none" or nil
        C_ChatInfo.PerformEmote(token, targetName)
    elseif data.actionType == "command" then
        local command = GetCustomMessage(mode, index) or data.action
        command = "/" .. command:gsub("^/+", "")
        if not HasLockedTarget() then
            local verb, arguments = command:match("^(%S+)%s*(.-)%s*$")
            if verb and NeedsLockedTarget(verb:lower(), arguments) then
                print("EmotePanel: Select a target first.")
                return
            end
            local emote = arguments == "" and hash_EmoteTokenList and hash_EmoteTokenList[verb:upper()]
            if emote then
                EmotePanel.frame:Hide()
                C_ChatInfo.PerformEmote(emote, "none")
                return
            end
        end
        local activeBox = ChatFrameUtil.GetActiveWindow()
        local editBox = ChatFrameUtil.ChooseBoxForSend()
        if not editBox then return end
        local draft = editBox:GetText()
        if (activeBox and activeBox:HasFocus()) or issecretvalue(draft) or draft ~= "" then
            print("EmotePanel: Finish your current chat draft before using a command.")
            return
        end
        EmotePanel.frame:Hide()
        editBox:SetText(command)
        editBox:SendMessage()
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
local function AddAtlas(parent, atlas, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAtlas(atlas)
    return texture
end

local function SkinPanel(frame)
    AddAtlas(frame, PANEL_ATLAS):SetAllPoints()
    AddAtlas(frame, PANEL_BORDER_ATLAS, "BORDER"):SetAllPoints()
end

local function CreateTextButton(parent, text)
    local button = CreateFrame("Button", nil, parent)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    button:SetFontString(label)
    button:SetNormalFontObject(GameFontHighlight)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetText(text)
    button:SetNormalAtlas(PANEL_ATLAS)
    AddAtlas(button, PANEL_BORDER_ATLAS, "BORDER"):SetAllPoints()
    button:SetHighlightAtlas(FOCUS_ATLAS)
    return button
end

local function CreateCloseButton(frame)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetNormalAtlas("128-redbutton-exit")
    close:SetPushedAtlas("128-redbutton-exit-Pressed")
    close:SetHighlightAtlas("128-redbutton-exit-Highlight")
    close:SetScript("OnClick", function() frame:Hide() end)
end

local function CreateEditorField(dialog, labelText, y, maxLetters)
    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 22, y)
    label:SetText(labelText)

    local box = CreateFrame("EditBox", nil, dialog, "InputBoxScriptTemplate")
    box:SetSize(276, 30)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(10, 10, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters)
    SkinPanel(box)

    local focus = AddAtlas(box, FOCUS_ATLAS, "BORDER")
    focus:SetAllPoints()
    focus:Hide()
    box:HookScript("OnEditFocusGained", function() focus:Show() end)
    box:HookScript("OnEditFocusLost", function() focus:Hide() end)
    return box
end

local function CreateCustomMessageDialog()
    local dialog = CreateFrame("Frame", "EmotePanelCustomMessageDialog", UIParent)
    dialog:SetSize(320, 222)
    dialog:SetPoint("CENTER", 0, 200)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    SkinPanel(dialog)
    CreateCloseButton(dialog)

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Customize Entry")

    local nameBox = CreateEditorField(dialog, "Name", -51, 18)
    local messageBox = CreateEditorField(dialog, "Message or command", -114, 255)
    nameBox:SetScript("OnTabPressed", function() messageBox:SetFocus() end)
    messageBox:SetScript("OnTabPressed", function() nameBox:SetFocus() end)
    dialog:SetScript("OnHide", function()
        nameBox:ClearFocus()
        messageBox:ClearFocus()
    end)

    local saveButton = CreateTextButton(dialog, "Save")
    saveButton:SetSize(86, 28)
    saveButton:SetPoint("BOTTOMLEFT", 22, 16)
    local resetButton = CreateTextButton(dialog, "Reset")
    resetButton:SetSize(86, 28)
    resetButton:SetPoint("BOTTOM", 0, 16)
    local cancelButton = CreateTextButton(dialog, "Cancel")
    cancelButton:SetSize(86, 28)
    cancelButton:SetPoint("BOTTOMRIGHT", -22, 16)
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)

    dialog.nameBox = nameBox
    dialog.messageBox = messageBox
    dialog.saveButton = saveButton
    dialog.resetButton = resetButton
    dialog:Hide()

    dialog:SetMovable(true)
    dialog:SetUserPlaced(true)
    dialog:SetClampedToScreen(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    return dialog
end

-- EmotePanel Methods
function EmotePanel:CreateMainFrame()
    self.frame = CreateFrame("Frame", AddonName .. "Frame", UIParent)
    local frame = self.frame

    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    return frame
end

-- Sectors start at twelve o'clock and advance clockwise.
local function SectorAt(x, y)
    local index = math.floor(math.atan2(x, y) / SECTOR_ANGLE + 0.5) % SECTOR_COUNT + 1
    if index <= currentPage.count then return index end
end

local function GetEntryName(mode, index, data)
    if data.actionType == "emote" then
        return data.name
    end
    return GetCustomButtonName(mode, index) or data.name
end

local function SetSelectionTint(texture, color)
    texture:SetDesaturated(color ~= nil)
    if color then
        texture:SetVertexColor(unpack(color))
    else
        texture:SetVertexColor(1, 1, 1)
    end
end

function EmotePanel:Select(index)
    if currentPage.count == 0 then return end
    index = (index - 1) % currentPage.count + 1
    if index == self.selected then return end

    if self.selected then
        local previousBorder = self.slots[self.selected].border
        previousBorder:SetAtlas(ICON_BORDER)
        SetSelectionTint(previousBorder)
    end
    self.selected = index
    self.highlight:Show()
    local border = self.slots[index].border
    border:SetAtlas(SELECTED_ICON_BORDER)
    local angle = (index - 1) * SECTOR_ANGLE
    local radius = self.highlightRadius
    self.highlight:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)
    -- Blizzard's highlight atlas points down before rotation.
    self.highlight:SetRotation(math.pi - angle)
    local mode, slot, data = GetSectorEntry(index)
    local color = SELECTION_COLORS[data.actionType]
    SetSelectionTint(self.highlight, color)
    SetSelectionTint(border, color)
    self.selectionName:SetText(GetEntryName(mode, slot, data))
    self:RefreshGamepadHint()
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
    local mode, slot, data = GetSectorEntry(index)
    if not data then return end
    self:Select(index)
    if mouseButton == "MiddleButton" then
        self:ToggleFavorite()
    elseif mouseButton == "RightButton" then
        if data.actionType ~= "emote" then
            self:EditButton(mode, slot, data)
        end
    elseif mouseButton == "LeftButton" then
        ExecuteAction(mode, slot, data)
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

    self.wheelArt = AddAtlas(wheel, WHEEL_ATLAS)
    self.wheelArt:SetAllPoints()
    self.highlight = AddAtlas(wheel, SELECTION_ATLAS, "ARTWORK")

    local wheelInfo = C_Texture.GetAtlasInfo(WHEEL_ATLAS) or { width = 525 }
    local highlightInfo = C_Texture.GetAtlasInfo(SELECTION_ATLAS) or { width = 177, height = 168 }
    local scale = WHEEL_SIZE / wheelInfo.width
    self.highlight:SetSize(highlightInfo.width * scale, highlightInfo.height * scale)
    self.highlightRadius = 150 * scale
    local innerRadius, outerRadius = 75 * scale, 234 * scale

    self.slots = {}
    for index = 1, SECTOR_COUNT do
        local slot = CreateFrame("Frame", nil, wheel)
        slot:SetSize(46, 46)
        local angle = (index - 1) * SECTOR_ANGLE
        local radius = self.highlightRadius
        slot:SetPoint("CENTER", wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)

        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("CENTER")
        local mask = slot:CreateMaskTexture()
        mask:SetAtlas("CircleMask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        slot.icon = icon
        slot.border = AddAtlas(slot, ICON_BORDER, "OVERLAY")
        slot.border:SetAllPoints()

        slot.favorite = AddAtlas(slot, "collections-icon-favorites", "OVERLAY")
        slot.favorite:SetSize(16, 16)
        slot.favorite:SetPoint("TOPRIGHT", 3, 3)
        self.slots[index] = slot
    end

    local function SectorUnderCursor(cursorX, cursorY)
        local centerX, centerY = wheel:GetCenter()
        local scale = wheel:GetEffectiveScale()
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        local distanceSquared = x * x + y * y
        if distanceSquared >= innerRadius ^ 2 and distanceSquared <= outerRadius ^ 2 then
            return SectorAt(x, y)
        end
    end

    local lastX, lastY, mouseDownButton, mouseDownSector, mouseDownPage
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
        local mode, slot, data = GetSectorEntry(index)
        GameTooltip:SetOwner(wheel, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText(GetEntryName(mode, slot, data))
        local action = GetCustomMessage(mode, slot) or data.action
        GameTooltip:AddLine(action, 1, 1, 1, true)
        if data.actionType ~= "emote" then
            GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
        end
        local favoriteHint = FindFavorite(mode, slot) and "Middle-click to remove favorite" or "Middle-click to favorite"
        GameTooltip:AddLine(favoriteHint, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end
    local function StopMouseSelection()
        wheel:SetScript("OnUpdate", nil)
        lastX, lastY = nil, nil
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
    end
    wheel:SetScript("OnEnter", function()
        wheel:SetScript("OnUpdate", UpdateMouseSelection)
        UpdateMouseSelection()
    end)
    wheel:SetScript("OnLeave", StopMouseSelection)
    wheel:SetScript("OnHide", StopMouseSelection)
    wheel:SetScript("OnMouseDown", function(_, mouseButton)
        if (mouseButton == "LeftButton" or mouseButton == "RightButton" or mouseButton == "MiddleButton")
            and self:CanUseWheel() then
            mouseDownButton = mouseButton
            mouseDownSector = SectorUnderCursor(GetCursorPosition())
            mouseDownPage = currentPageIndex
        end
    end)
    wheel:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton ~= mouseDownButton then return end
        local pressedSector, pressedPage = mouseDownSector, mouseDownPage
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if not pressedSector or pressedPage ~= currentPageIndex or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(GetCursorPosition())
        if index == pressedSector then
            if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
            self:ActivateSector(index, mouseButton)
        end
    end)
end

function EmotePanel:RefreshWheel(selection)
    for index, slot in ipairs(self.slots) do
        local used = index <= currentPage.count
        if used then
            local mode, entryIndex, data = GetSectorEntry(index)
            if data.icon:find("\\", 1, true) then
                slot.icon:SetTexture(data.icon)
                slot.icon:SetTexCoord(0, 1, 0, 1)
            else
                slot.icon:SetTexture(ICON_PATH .. data.icon)
                slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            slot.border:SetAtlas(ICON_BORDER)
            SetSelectionTint(slot.border)
            slot.favorite:SetShown(currentPage.mode ~= "favorites" and FindFavorite(mode, entryIndex) ~= nil)
        end
        slot:SetShown(used)
    end
    local nextSelection = selection or self.selected or 1
    self.selected = nil
    local hasEntries = currentPage.count > 0
    if hasEntries then
        self:Select(math.min(nextSelection, currentPage.count))
    else
        self.highlight:Hide()
        self.selectionName:SetText("No favorites")
        self:RefreshGamepadHint()
    end
end

function EmotePanel:CreateControls()
    local frame = self.frame
    local header = AddAtlas(frame, "gamepad-radial-menu-toptext", "BORDER")
    header:SetSize(374, 58)
    header:SetPoint("TOP", 0, -2)

    local dragArea = CreateFrame("Frame", nil, frame)
    dragArea:SetSize(206, 50)
    dragArea:SetPoint("TOP", 0, -2)
    dragArea:EnableMouse(true)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnDragStart", function() frame:StartMoving() end)
    dragArea:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    local caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("TOP", 0, -10)
    caption:SetTextColor(0.91, 0.76, 0.49)
    caption:SetText("EMOTE WHEEL")

    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", 0, -26)
    self.titleText:SetTextColor(1, 0.96, 0.87)
    self.titleText:SetText(currentPage.title)

    for direction = -1, 1, 2 do
        local arrow = CreateFrame("Button", nil, frame)
        local atlas = direction < 0 and "common-icon-backarrow" or "common-icon-forwardarrow"
        arrow:SetSize(14, 22)
        arrow:SetPoint("TOP", direction * 118, -21)
        arrow:SetNormalAtlas(atlas)
        arrow:SetHighlightAtlas(atlas, "ADD")
        arrow:SetScript("OnClick", function() self:CycleMode(direction) end)
    end

    CreateCloseButton(frame)

    local help = CreateTextButton(frame, "?")
    help:SetSize(28, 28)
    help:SetPoint("TOPLEFT", 11, -11)
    help:SetScript("OnClick", function()
        frame:Hide()
        Settings.OpenToCategory(self.settingsCategoryID)
    end)

    local footer = AddAtlas(frame, "gamepad-radial-menu-bottomtext", "BORDER")
    footer:SetSize(410, 102)
    footer:SetPoint("BOTTOM", 0, 7)

    self.selectionName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.selectionName:SetPoint("TOP", 0, -421)
    self.selectionName:SetWidth(386)
    self.selectionName:SetWordWrap(false)
    self.selectionName:SetTextColor(1, 0.96, 0.87)
    self.navigationHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.navigationHint:SetPoint("TOP", 0, -470)
    self.gamepadHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.gamepadHint:SetPoint("TOP", 0, -507)
    frame:HookScript("OnShow", function() self:ShowPage(1, 1) end)
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
    local mode, slot, data = GetSectorEntry(self.selected)
    local actions
    if data then
        local favoriteAction = FindFavorite(mode, slot) and "Unfavorite" or "Favorite"
        actions = GamepadGlyph("PAD1", "A") .. " Use    "
            .. GamepadGlyph("PAD3", "X") .. " " .. favoriteAction .. "    "
        if data.actionType ~= "emote" then
            actions = actions .. GamepadGlyph("PAD4", "Y") .. " Edit    "
        end
    else
        actions = "Browse pages and press " .. GamepadGlyph("PAD3", "X") .. " to add    "
    end
    self.gamepadHint:SetText(actions .. GamepadGlyph("PAD2", "B") .. " Close")
end

function EmotePanel:ShowPage(index, selection)
    currentPageIndex = index
    currentPage = GetPage(index)
    self.titleText:SetText(currentPage.title)
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self:RefreshWheel(selection)
end

function EmotePanel:CycleMode(direction)
    local total = FavoritePageCount() + #categoryPages
    self:ShowPage((currentPageIndex - 1 + direction) % total + 1, 1)
end

function EmotePanel:ToggleFavorite()
    local mode, slot, data = GetSectorEntry(self.selected)
    if not data then return end
    local previousPageCount = FavoritePageCount()
    local position = FindFavorite(mode, slot)
    if position then
        table.remove(favorites, position)
    else
        table.insert(favorites, { mode = mode, index = slot })
    end

    local newPageCount = FavoritePageCount()
    local page = currentPageIndex
    if currentPage.mode == "favorites" then
        page = math.min(page, newPageCount)
    else
        page = page + newPageCount - previousPageCount
    end
    self:ShowPage(page, self.selected)
end

function EmotePanel:SetupGamepad()
    local frame = self.frame
    local pressed = {}
    local actions = {
        PADDUP = function() if self.selected then self:Select(self.selected - 1) end end,
        PADDDOWN = function() if self.selected then self:Select(self.selected + 1) end end,
        PADDLEFT = function() self:CycleMode(-1) end,
        PADDRIGHT = function() self:CycleMode(1) end,
        PAD1 = function() self:ActivateSector(self.selected, "LeftButton") end,
        PAD2 = function() frame:Hide() end,
        PAD3 = function() self:ToggleFavorite() end,
        PAD4 = function() self:ActivateSector(self.selected, "RightButton") end,
    }
    local function CanUsePanelControls(key)
        if not self:CanUseWheel() then return false end
        if key == "PAD4" then
            local _, _, data = GetSectorEntry(self.selected)
            return data and data.actionType ~= "emote"
        end
        return true
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
            local index = SectorAt(x, y)
            if index then self:Select(index) end
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
    LoadFavorites()
    currentPageIndex = 1
    currentPage = GetPage(1)

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
        "MinimalScrollFrameTemplate")
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
    instructions3:SetText("Selecting a command submits it immediately through WoW chat.")

    -- Add button to reset all custom messages
    local resetCustomButton = CreateTextButton(customizationPanel, "Reset All Custom Messages")
    resetCustomButton:SetSize(200, 26)
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
    print("  X/Square or middle-click: add or remove a favorite. The wheel opens on Favorites.")
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
        print("EmotePanel: Use the page arrows or D-pad left/right to browse the wheel.")
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
