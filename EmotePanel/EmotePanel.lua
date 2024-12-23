-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
local ListPanel = {}

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

-- Constants
local BUTTON_HEIGHT = 35
local BUTTON_WIDTH = 130
local PANEL_WIDTH = 200
local PANEL_HEIGHT = 190
local LIST_PANEL_WIDTH = 400
local LIST_PANEL_HEIGHT = 600

-- Default positions for the panels
local DEFAULT_POSITIONS = {
    emotePanel = {
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = 0
    },
    listPanel = {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -200,
        y = 0
    }
}

local PANEL_MODES = {
    emotes = {
        title = "Emotes 1",
        list = {
            { name = "Angry", action = "angry", actionType = "emote" },
            { name = "Applause", action = "bravo", actionType = "emote" },
            { name = "Blush", action = "blush", actionType = "emote" },
            { name = "Bow", action = "bow", actionType = "emote" },
            { name = "Cackle", action = "cackle", actionType = "emote" },
            { name = "Cheer", action = "cheer", actionType = "emote" },
            { name = "Cry", action = "cry", actionType = "emote" },
            { name = "Dance", action = "dance", actionType = "emote" },
            { name = "Facepalm", action = "facepalm", actionType = "emote" },
            { name = "Flex", action = "flex", actionType = "emote" },
        }
    },
    emotes2 = {
        title = "Emotes 2",
        list = {
            { name = "Golfclap", action = "golfclap", actionType = "emote" },
            { name = "Goodbye", action = "bye", actionType = "emote" },
            { name = "Hug", action = "hug", actionType = "emote" },
            { name = "Kiss", action = "kiss", actionType = "emote" },
            { name = "Kneel", action = "kneel", actionType = "emote" },
            { name = "Laugh", action = "laugh", actionType = "emote" },
            { name = "No", action = "no", actionType = "emote" },
            { name = "Point", action = "point", actionType = "emote" },
            { name = "Roar", action = "roar", actionType = "emote" },
            { name = "Rude", action = "rude", actionType = "emote" },
        }
    },
    emotes3 = {
        title = "Emotes 3",
        list = {
            { name = "Salute", action = "salute", actionType = "emote" },
            { name = "Sigh", action = "sigh", actionType = "emote" },            
            { name = "Sorry", action = "apologize", actionType = "emote" },
            { name = "Stand", action = "stand", actionType = "emote" },
            { name = "Talk", action = "talk", actionType = "emote" },
            { name = "Thank", action = "thank", actionType = "emote" },
            { name = "Threaten", action = "threaten", actionType = "emote" },
            { name = "Wave", action = "wave", actionType = "emote" },
            { name = "Yes", action = "nod", actionType = "emote" },
        }
    },
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!", action = "Hello!", actionType = "say" },
            { name = "Well played", action = "Well played!", actionType = "say" },
            { name = "Thanks", action = "Thank you!", actionType = "say" },
            { name = "No problem", action = "No problem!", actionType = "say" },            
            { name = "BRB", action = "Be right back, quick break", actionType = "say" },
            { name = "Bye", action = "Bye!", actionType = "say" },
            { name = "LFG", action = "Want to group up?", actionType = "say" },
            { name = "Stay safe!", action = "Stay safe out there!", actionType = "say" }            
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me", action = "Follow me please!", actionType = "party" },
            { name = "Need Break", action = "Need a quick break!", actionType = "party" },
            { name = "Thanks Group", action = "Thanks everyone!", actionType = "party" },
            { name = "Good Job", action = "Great job team!", actionType = "party" }
        }
    },
    commands = {
        title = "Commands",
        list = {
            { name = "Roll", action = "/roll", actionType = "command" },
            { name = "Invite to group", action = "/invite", actionType = "command" },
            { name = "Trade with Target", action = "/trade", actionType = "command" },
            { name = "Follow Target", action = "/follow", actionType = "command" },
            { name = "Add Target as friend", action = "/friend", actionType = "command" },
        }
    }
}

local modeOrder = { "emotes", "emotes2", "emotes3", "chat", "party", "commands" }
local currentMode = "emotes"
local currentModeIndex = 1

-- Utility Functions
local function CreateBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
end

local function ExecuteAction(data)
    if data.actionType == "emote" then
        DoEmote(data.action:upper())
    elseif data.actionType == "say" then
        SendChatMessage(data.action, "SAY")
    elseif data.actionType == "party" then
        SendChatMessage(data.action, "PARTY")
    elseif data.actionType == "command" then
        DEFAULT_CHAT_FRAME.editBox:SetText(data.action)
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox)
    end
end

-- EmotePanel Methods
function EmotePanel:CreateMainFrame()
    self.frame = CreateFrame("Frame", AddonName .. "Frame", UIParent, "BackdropTemplate")
    local frame = self.frame
    
    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetUserPlaced(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    
    CreateBackdrop(frame)
    
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
    --local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ScrollFrame", self.frame)
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 30, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -30, 10)
    
    -- Create content frame
    local content = CreateFrame("Frame", AddonName .. "ScrollContent", scrollFrame)
    content:SetWidth(150)
    scrollFrame:SetScrollChild(content)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        local newScroll = current - (delta * BUTTON_HEIGHT)
        self:SetVerticalScroll(math.max(0, math.min(newScroll, max)))
    end)
    
    self.scrollFrame = scrollFrame
    self.scrollContent = content

    self:UpdateScrollbarVisibility()
end

function EmotePanel:UpdateScrollbarVisibility()
    local currentList = PANEL_MODES[currentMode].list
    if #currentList < 5 then
        self.scrollFrame.ScrollBar:Hide()
    else
        self.scrollFrame.ScrollBar:Show()
    end
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
    
    -- Set content height
    local totalHeight = #list * BUTTON_HEIGHT
    self.scrollContent:SetHeight(totalHeight)
    
    for i, data in ipairs(list) do
        local button = CreateFrame("Button", AddonName .. "Button" .. i, self.scrollContent, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_WIDTH, 30)
        button:SetText(data.name)
        button:SetPoint("TOP", self.scrollContent, "TOP", 0, -((i-1) * BUTTON_HEIGHT))
        
        button:SetScript("OnClick", function()
            ExecuteAction(data)
        end)
        
        table.insert(self.buttons, button)
    end
    self:UpdateScrollbarVisibility()
end

function EmotePanel:CreateControls()
    -- Title
    self.titleText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", self.frame, "TOP", 0, -10)
    self.titleText:SetText(PANEL_MODES[currentMode].title)
    
    -- Mode cycle button
    local modeButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    modeButton:SetPoint("CENTER", self.frame, "CENTER", -75, -15)
    modeButton:SetSize(30, 30)
    modeButton:SetText("<")
    modeButton:SetScript("OnClick", function()
        local newTitle = self:CycleMode()
        self.titleText:SetText(newTitle)
        self:CreateButtons()
        self.scrollFrame:SetVerticalScroll(0)
        self:UpdateScrollbarVisibility() 
    end)
    
    -- List toggle button
    local listButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    listButton:SetPoint("CENTER", self.frame, "CENTER", -75, -65)
    listButton:SetSize(30, 30)
    listButton:SetText("?")
    listButton:SetScript("OnClick", function()
        if ListPanel.frame:IsShown() then
            ListPanel.frame:Hide()
        else
            ListPanel.frame:Show()
        end
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT")
    closeButton:SetScript("OnClick", function()
        self.frame:Hide()
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

-- Initialize EmotePanel
function EmotePanel:Initialize()
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

-- ListPanel Methods
function ListPanel:CreateMainFrame()
    self.frame = CreateFrame("Frame", AddonName .. "ListFrame", UIParent, "BackdropTemplate")
    local frame = self.frame
    
    frame:SetWidth(LIST_PANEL_WIDTH)
    frame:SetHeight(LIST_PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetUserPlaced(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    
    CreateBackdrop(frame)
    
    -- Make frame draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    return frame
end

function ListPanel:CreateContent()
    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -30, 10)
    
    -- Create content frame
    local content = CreateFrame("Frame", AddonName .. "ListScrollContent", scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    scrollFrame:SetScrollChild(content)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", self.frame, "TOP", 0, -10)
    title:SetText("Emote Panel - All Commands")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT")
    closeButton:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Create list content
    local yOffset = 0
    for _, modeName in ipairs(modeOrder) do
        local modeData = PANEL_MODES[modeName]
        
        -- Mode header
        local modeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        modeHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
        modeHeader:SetText(modeData.title)
        yOffset = yOffset + 30
        
        -- List items
        for _, item in ipairs(modeData.list) do
            local itemText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            itemText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -yOffset)
            itemText:SetText(string.format(
                "|cFFFFFFFF%s|r - |cFF00FF00%s|r |cFF8888FF(%s)|r",
                item.name,
                item.action,
                item.actionType
            ))
            yOffset = yOffset + 20
        end
        
        yOffset = yOffset + 20 -- Add space between sections
    end
    
    content:SetHeight(yOffset)
end

function ListPanel:SavePosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end
    
    local point, _, relativePoint, x, y = self.frame:GetPoint()
    EmotePanelSavedVars.positions.listPanel = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
end

function ListPanel:LoadPosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end
    
    local position = EmotePanelSavedVars.positions.listPanel or DEFAULT_POSITIONS.listPanel
    
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
end

function ListPanel:Initialize()
    self:CreateMainFrame()
    self:CreateContent()
    self:LoadPosition()

    -- Add OnDragStop script to save position
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)    
    
    -- Hide by default
    self.frame:Hide()
    
    -- Make ESC key close the frame
    tinsert(UISpecialFrames, self.frame:GetName())
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

-- Slash command handler
local function HandleSlashCommand(msg)
    if msg == "list" then
        ListPanel.frame:Show()
    else
        EmotePanel_Toggle()
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
        ListPanel:Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")