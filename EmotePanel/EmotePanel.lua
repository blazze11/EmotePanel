-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = CreateFrame("Frame", AddonName .. "Frame", UIParent, "BackdropTemplate")
local buttons = {}
local currentMode = "emotes" -- Track current display mode
local scrollFrame -- Moved to file scope so we can access it in multiple functions


-- Expanded Emote list with more emotes
local EMOTE_LIST = {
    { name = "Apologize", emote = "apologize" },
    { name = "Bow", emote = "bow" },
    { name = "Cheer", emote = "cheer" },
    { name = "Cry", emote = "cry" },
    { name = "Dance", emote = "dance" },
    { name = "Facepalm", emote = "facepalm" },
    { name = "Flex", emote = "flex" },
    { name = "Goodbye", emote = "bye" },
    { name = "Hug", emote = "hug" },
    { name = "Kneel", emote = "kneel" },
    { name = "Kiss", emote = "kiss" },
    { name = "Laugh", emote = "laugh" },
    { name = "No", emote = "no" },
    { name = "Point", emote = "point" },
    { name = "Roar", emote = "roar" },
    { name = "Rude", emote = "rude" },
    { name = "Salute", emote = "salute" },
    { name = "Sexy", emote = "sexy" },
    { name = "Sit", emote = "sit" },
    { name = "Sleep", emote = "sleep" },
    { name = "Stand", emote = "stand" },
    { name = "Talk", emote = "talk" },
    { name = "Train", emote = "train" },
    { name = "Wave", emote = "wave" },
    { name = "Yes", emote = "nod" }
}

local CHAT_LIST = {
    { name = "Hello!", message = "Hello everyone! Hope you're having a great day!" },
    { name = "Good Fight", message = "Great fight everyone! Well played!" },
    { name = "Thanks", message = "Thank you for the help!" },
    { name = "BRB", message = "Be right back, quick break" },
    { name = "Good Night", message = "Good night everyone! Thanks for the group!" },
    { name = "LFG", message = "Looking for group! Anyone want to team up?" }
    -- Add more chat messages as needed
}

-- Function to clear existing buttons
local function ClearButtons()
    for _, button in ipairs(buttons) do
        button:Hide()
        button:SetParent(nil)
    end
    wipe(buttons)
end

-- Function to create buttons based on current mode
local function CreateButtons(content)
    ClearButtons()
    
    local list = currentMode == "emotes" and EMOTE_LIST or CHAT_LIST

    -- Set content height dynamically based on number of buttons
    local buttonHeight = 35 -- Height of each button plus spacing
    local totalHeight = #list * buttonHeight
    content:SetHeight(totalHeight)    
    
    for i, data in ipairs(list) do
        local button = CreateFrame("Button", AddonName .. "Button" .. i, content, "UIPanelButtonTemplate")
        button:SetSize(140, 30)
        button:SetText(data.name)
        button:SetPoint("TOP", content, "TOP", 0, -((i-1) * 35))
        
        -- Different click handlers based on mode
        if currentMode == "emotes" then
            button:SetScript("OnClick", function()
                DoEmote(data.emote:upper())
            end)
        else
            button:SetScript("OnClick", function()
                SendChatMessage(data.message, "SAY")
            end)
        end
        
        table.insert(buttons, button)
    end
end

-- Global toggle function for keybinding
function EmotePanel_Toggle()
    if EmotePanel:IsShown() then
        EmotePanel:Hide()
    else
        EmotePanel:Show()
    end
end

-- Initialization function
function EmotePanel:Initialize()
    -- Set up the main frame
    self:SetWidth(170)
    self:SetHeight(190)
    self:SetPoint("CENTER")
    self:SetMovable(true)
    self:SetUserPlaced(true)
    self:SetClampedToScreen(true)
    self:EnableMouse(true)
    
    -- Background
    self:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    self:SetBackdropColor(0, 0, 0, 0.7)
    self:SetBackdropBorderColor(1, 1, 1, 1)

    -- Drag functionality
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", self.StartMoving)
    self:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SavePosition()
    end)

    -- Create scroll frame
    scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ScrollFrame", self)  -- Assigned to file scope variable
    scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -60) -- Adjusted to make room for mode button
    scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -10, 10)

    -- Create content frame for scrolling
    local content = CreateFrame("Frame", AddonName .. "ScrollContent", scrollFrame)
    content:SetWidth(150)
    --content:SetHeight(1000) -- Set a large enough height for all items
    scrollFrame:SetScrollChild(content)

    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 35)
        newScroll = math.max(0, math.min(newScroll, max))
        self:SetVerticalScroll(newScroll)
    end)

    -- Title
    local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", self, "TOP", 0, -10)
    title:SetText("Emote Panel")

    -- Mode Toggle Button
    local modeButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    modeButton:SetSize(140, 20)
    modeButton:SetPoint("TOP", title, "BOTTOM", 0, -5)
    modeButton:SetText("Switch to Chat")
    modeButton:SetScript("OnClick", function()
        currentMode = currentMode == "emotes" and "chat" or "emotes"
        modeButton:SetText(currentMode == "emotes" and "Switch to Chat" or "Switch to Emotes")
        title:SetText(currentMode == "emotes" and "Emote Panel" or "Chat Panel")
        CreateButtons(content)
        scrollFrame:SetVerticalScroll(0) -- Reset scroll position to top
    end)

    -- Close button
    local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", self, "TOPRIGHT")
    closeButton:SetScript("OnClick", function() 
        self:Hide() 
    end)

    -- Create initial buttons
    CreateButtons(content)

    -- Hide by default
    self:Hide()

    -- Make ESC key close the frame
    tinsert(UISpecialFrames, self:GetName())
end

-- Save and load position (unchanged)
function EmotePanel:SavePosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    local point, _, relativePoint, x, y = self:GetPoint()
    EmotePanelSavedVars.point = point
    EmotePanelSavedVars.relativePoint = relativePoint
    EmotePanelSavedVars.x = x
    EmotePanelSavedVars.y = y
end

function EmotePanel:LoadPosition()
    if EmotePanelSavedVars and EmotePanelSavedVars.point then
        self:ClearAllPoints()
        self:SetPoint(
            EmotePanelSavedVars.point, 
            UIParent, 
            EmotePanelSavedVars.relativePoint, 
            EmotePanelSavedVars.x, 
            EmotePanelSavedVars.y
        )
    end
end

-- Slash commands (unchanged)
SLASH_EMOTEPANEL1 = "/emotepanel"
SLASH_EMOTEPANEL2 = "/ep"
SlashCmdList["EMOTEPANEL"] = EmotePanel_Toggle

-- Event handling (unchanged)
EmotePanel:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == AddonName then
        self:Initialize()
        self:LoadPosition()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

EmotePanel:RegisterEvent("ADDON_LOADED")