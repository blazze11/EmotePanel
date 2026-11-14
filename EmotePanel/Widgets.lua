local AddonName, ns = ...

local Widgets = ns.Widgets

local ICON_PATH = "Interface\\Icons\\"
-- These radial icons have art in Forever's HUD sheet, but their atlas names
-- do not resolve for addon textures. The bounds are pixels in the 2048px sheet.
local RADIAL_ICON_SHEET = "Interface\\HUD\\UIRadialMenuc60"
local RADIAL_ICON_SHEET_SIZE = 2048
local RADIAL_ICON_BOUNDS = {
    ["gamepad-radial-icon-group-up-c60"] = { 1264, 1487, 870, 1084 },
    ["gamepad-radial-icon-emotes-up-c60"] = { 206, 409, 1463, 1690 },
    ["gamepad-radial-icon-macros-up-c60"] = { 875, 1084, 1, 186 },
    ["gamepad-radial-icon-targeting-up-c60"] = { 1489, 1698, 870, 1083 },
    ["gamepad-radial-icon-professions-c60"] = { 1482, 1692, 658, 864 },
}
local PANEL_ATLAS = "gamepad-footer-slot-bg"
local PANEL_BORDER_ATLAS = "gamepad-footer-slot-frameneutral"
local FOCUS_ATLAS = "gamepad-footer-slot-framefocused"
local GLYPH_SIZE = 32
local GLYPH_STYLES = {
    xbox = {
        name = "Xbox", prefix = "gamepad-xbox1-",
        icons = {
            PAD1 = "buttona", PAD2 = "buttonb", PAD3 = "buttonx", PAD4 = "buttony",
            PADLSHOULDER = "trigger-lb", PADRSHOULDER = "trigger-rb",
            PADLSTICKAXIS = "stick-l", PADRSTICKAXIS = "stick-r",
            PADBACK = "view",
            DIRPAD = "dpadall", DIRPADHORIZONTAL = "dpadleftright", DIRPADVERTICAL = "dpadupdown",
            PADDLEFT = "dpadleft", PADDRIGHT = "dpadright",
        },
    },
    playstation = {
        name = "PlayStation", prefix = "gamepad-ps-",
        icons = {
            PAD1 = "buttoncrox", PAD2 = "buttoncircle", PAD3 = "buttonsquare", PAD4 = "buttontriangle",
            PADLSHOULDER = "triggerl1", PADRSHOULDER = "triggerr1",
            PADLSTICKAXIS = "stickl", PADRSTICKAXIS = "stickr",
            PADBACK = "touchpad",
            DIRPAD = "dpadall", DIRPADHORIZONTAL = "dpadleftright", DIRPADVERTICAL = "dpadupdown",
            PADDLEFT = "dpadleft", PADDRIGHT = "dpadright",
        },
    },
    switch = {
        name = "Nintendo Switch", prefix = "gamepad-switch-128x-",
        icons = {
            PAD1 = "face-b", PAD2 = "face-a", PAD3 = "face-y", PAD4 = "face-x",
            PADLSHOULDER = "shoulder-l", PADRSHOULDER = "shoulder-r",
            PADLSTICKAXIS = "stick-l", PADRSTICKAXIS = "stick-r",
            PADBACK = "minus",
            DIRPAD = "dpad-all", DIRPADHORIZONTAL = "dpad-leftright", DIRPADVERTICAL = "dpad-updown",
            PADDLEFT = "dpad-left", PADDRIGHT = "dpad-right",
        },
    },
}
local glyphPrompts = {}

local function GetStyleAtlas(style, key)
    local icon = style.icons[key]
    if not icon then return end
    local atlas = style.prefix .. icon .. "-normal"
    if C_Texture.GetAtlasInfo(atlas) then return atlas end
end

local function GetGlyphStyle()
    local style = EmotePanelSavedVars.controllerGlyphs
    if GLYPH_STYLES[style] and GetStyleAtlas(GLYPH_STYLES[style], "PAD1") then return style end
    return "auto"
end

local function GamepadGlyph(key, fallback)
    local style = GLYPH_STYLES[EmotePanelSavedVars.controllerGlyphs]
    local atlas = style and GetStyleAtlas(style, key)
    local icons = InputIconTextureSetUtility
    if not atlas and icons and icons.GetActiveInputIconButtonTextures(key) then
        atlas = icons.GetNormalActiveInputIconButtonTexture(key)
    end
    if type(atlas) ~= "string" then atlas = GetStyleAtlas(GLYPH_STYLES.xbox, key) end
    if atlas then return CreateAtlasMarkup(atlas, GLYPH_SIZE, GLYPH_SIZE) end
    return fallback
end

local function SetGlyphPrompt(fontString, render)
    glyphPrompts[fontString] = render
    fontString:SetText(render())
end

local function GetIconPath(icon)
    if type(icon) == "number" or icon:find("\\", 1, true) or icon:sub(1, 6) == "atlas:" then return icon end
    return ICON_PATH .. icon
end

local function SetIconTexture(texture, icon, crop)
    -- Wheel slots and picker cells are reused across both atlases and loose icons.
    texture:SetTexture(nil)
    local atlas = type(icon) == "string" and icon:match("^atlas:(.+)$")
    if atlas then
        local bounds = RADIAL_ICON_BOUNDS[atlas]
        if bounds and texture:SetTexture(RADIAL_ICON_SHEET) then
            local left, right, top, bottom = unpack(bounds)
            local size = RADIAL_ICON_SHEET_SIZE
            texture:SetTexCoord(left / size, right / size, top / size, bottom / size)
            return
        end
        texture:SetAtlas(atlas, false, nil, true)
        if texture:GetAtlas() then return end
        if atlas == "ui-eventpoi-horn-big-2x" and texture:SetTexture("Interface\\Minimap\\UIEventPOIIcons2x") then
            texture:SetTexCoord(1 / 256, 65 / 256, 67 / 256, 131 / 256)
            return
        end
        if atlas == "transmog-icon-favorite-2x" then
            texture:SetAtlas("transmog-icon-favorite", false, nil, true)
            if texture:GetAtlas() then return end
        end
        icon = ICON_PATH .. "INV_Misc_QuestionMark"
    elseif icon and texture:SetTexture(icon) then
        if crop and (type(icon) == "number" or icon:lower():find(ICON_PATH:lower(), 1, true)) then
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
        return
    else
        icon = ICON_PATH .. "INV_Misc_QuestionMark"
    end
    texture:SetTexture(icon)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function AddAtlas(parent, atlas, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAtlas(atlas)
    return texture
end

local function SkinPanel(frame)
    AddAtlas(frame, PANEL_ATLAS):SetAllPoints()
    AddAtlas(frame, PANEL_BORDER_ATLAS, "BORDER"):SetAllPoints()
end

local function SetChatPortrait(frame)
    frame:SetPortraitAtlasRaw("gamepad-radial-icon-chat")
    frame:SetPortraitTextureSizeAndOffset(48, 2, 1)

    local container = frame.PortraitContainer
    local background = container:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("CENTER", frame:GetPortrait(), "CENTER")
    background:SetSize(56, 56)
    background:SetColorTexture(0.12, 0.09, 0.07, 1)
    local mask = container:CreateMaskTexture()
    mask:SetAtlas("CircleMask")
    mask:SetAllPoints(background)
    background:AddMaskTexture(mask)
end

local function CreateRedButton(parent, text)
    local button = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
    button:SetText(text)
    return button
end

local function SetEntryEdit(row, edit)
    row.EditSetting = edit
    local function OnMouseUp(_, button, inside)
        if button == "RightButton" and inside and (not row.CanEditSetting or row:CanEditSetting()) then
            if GameTooltip:IsShown() then GameTooltip:Hide() end
            row:EditSetting()
        end
    end
    row:HookScript("OnMouseUp", OnMouseUp)
    if row.check then row.check:HookScript("OnMouseUp", OnMouseUp) end
end

local function AddSettingsTooltip(control, title, text, label)
    control.settingsFocusLabel = title
    control.settingsFocusText = label
    control.settingsFocusDescription = text
    local function Show(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end
    local function Hide(owner)
        if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    end
    local function Bind(target)
        target:HookScript("OnEnter", Show)
        target:HookScript("OnLeave", Hide)
        target:HookScript("OnHide", Hide)
    end
    Bind(control)
    if label then
        local hover = CreateFrame("Frame", nil, control:GetParent())
        hover:SetAllPoints(label)
        hover:EnableMouseMotion(true)
        hover:SetAttribute("nodeignore", true)
        Bind(hover)
    end
end

local function CreateSideTab(parent, title, icon, onClick)
    local tab = CreateFrame("Button", nil, parent, "LargeSideTabButtonTemplate")
    tab.Icon:SetTexture(icon)
    tab:SetFillToInterior(true)
    tab:SetScript("OnMouseDown", nil)
    tab:SetScript("OnMouseUp", nil)
    tab:SetScript("OnClick", onClick)
    AddSettingsTooltip(tab, title, "")
    return tab
end

local function MakeTitleDraggable(frame)
    local title = frame.TitleContainer
    frame:SetMovable(true)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:HookScript("OnHide", function() frame:StopMovingOrSizing() end)
end

local function CreateListIcon(row, anchor, relativePoint)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", anchor, relativePoint, 4, 0)
    return icon
end

local function RefreshGlyphPrompts()
    for fontString, render in pairs(glyphPrompts) do fontString:SetText(render()) end
end

local function RefreshGlyphPrompt(fontString)
    fontString:SetText(glyphPrompts[fontString]())
end

local function ShowError(message, gameError)
    if gameError then
        UIErrorsFrame:TryDisplayMessage(gameError, message, RED_FONT_COLOR:GetRGB())
    else
        UIErrorsFrame:AddExternalErrorMessage(message)
    end
end

local function PlayWheelSound(sound)
    if sound and EmotePanelSavedVars.wheelSounds ~= false then PlaySound(sound, "SFX", true) end
end

local confirmation, confirmationInput, confirmationCursor

local function GetActiveConfirmationCursor()
    local cursor = _G.ConsolePortCursor
    if cursor then
        local shown = cursor:IsShown()
        if not issecretvalue(shown) and shown then return cursor end
    end
end

local function GetConfirmationButton(key)
    if key == "PAD2" then return 2 end
    local cursor = GetActiveConfirmationCursor()
    if not cursor then return 1 end
    -- A/Cross follows ConsolePort's highlight. An unrelated node is not a confirmation.
    local node = cursor.GetCurrentNode and cursor:GetCurrentNode()
    if issecretvalue(node) or not node then return end
    if node == confirmation:GetButton(1) and node:IsEnabled() then return 1 end
    if node == confirmation:GetButton(2) and node:IsEnabled() then return 2 end
end

local function RefreshConfirmationPrompts()
    if not confirmation or InCombatLockdown() then return end
    local info = StaticPopupDialogs[confirmation.which]
    local accept = GetActiveConfirmationCursor() and info.button1 or GamepadGlyph("PAD1", "A") .. " " .. info.button1
    confirmation:GetButton(1):SetText(accept)
    confirmation:GetButton(2):SetText(GamepadGlyph("PAD2", "B") .. " " .. info.button2)
    confirmation:Resize()
end

local function CreateConfirmationInput()
    local input = CreateFrame("Frame", AddonName .. "ConfirmationInput", UIParent)
    input:SetFrameStrata("TOOLTIP")
    input:Hide()
    local pressed, pressedButton
    input:SetScript("OnGamePadButtonDown", function(self, key)
        if InCombatLockdown() then return end
        local handled = key == "PAD1" or key == "PAD2"
        if confirmation and handled then pressed, pressedButton = key, GetConfirmationButton(key) end
        self:SetPropagateKeyboardInput(not handled)
    end)
    input:SetScript("OnGamePadButtonUp", function(self, key)
        if InCombatLockdown() then return end
        local handled = key == "PAD1" or key == "PAD2"
        self:SetPropagateKeyboardInput(not handled)
        if confirmation and handled and key == pressed then
            local button = pressedButton
            pressed, pressedButton = nil, nil
            if button and button == GetConfirmationButton(key) then StaticPopup_OnClick(confirmation, button) end
        end
    end)
    input:SetScript("OnHide", function() pressed, pressedButton = nil, nil end)
    return input
end

local function ShowConfirmation(which, text, data)
    if confirmation then return end
    if InCombatLockdown() then
        ShowError("Settings confirmations are unavailable in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
        return
    end
    if ns.panel.optionsPanel then ns.panel.optionsPanel:CancelWheelBindingCapture() end
    local dialog = StaticPopup_Show(which, text, nil, data, nil, function(closed)
        if confirmation ~= closed then return end
        confirmation = nil
        if confirmationInput then confirmationInput:Hide() end
        ns.panel:UpdateSecureWheelInput()
    end)
    if not dialog then return end

    confirmation = dialog
    local cursor = _G.ConsolePortCursor
    if cursor and cursor ~= confirmationCursor then
        confirmationCursor = cursor
        cursor:HookScript("OnShow", RefreshConfirmationPrompts)
        cursor:HookScript("OnHide", RefreshConfirmationPrompts)
    end
    RefreshConfirmationPrompts()
    confirmationInput = confirmationInput or CreateConfirmationInput()
    confirmationInput:EnableGamePadButton(true)
    confirmationInput:Show()
    ns.panel:UpdateSecureWheelInput()
end

local function CreateSettingsHighlight(control, mouseSelection)
    local highlight = control:CreateTexture(nil, "BACKGROUND", nil, 2)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetDesaturated(true)
    if mouseSelection then
        local r, g, b = NORMAL_FONT_COLOR:GetRGB()
        highlight:SetVertexColor(r, g, b, 0.82)
    else
        highlight:SetVertexColor(0.65, 0.83, 1, 0.82)
    end
    highlight:SetBlendMode("ADD")
    return highlight
end

Widgets.CreateSettingsHighlight = CreateSettingsHighlight
Widgets.ShowConfirmation = ShowConfirmation
Widgets.GetConfirmation = function() return confirmation end

Widgets.AddAtlas = AddAtlas
Widgets.AddSettingsTooltip = AddSettingsTooltip
Widgets.CreateSideTab = CreateSideTab
Widgets.MakeTitleDraggable = MakeTitleDraggable
Widgets.CreateRedButton = CreateRedButton
Widgets.SetEntryEdit = SetEntryEdit
Widgets.FOCUS_ATLAS = FOCUS_ATLAS
Widgets.GLYPH_STYLES = GLYPH_STYLES
Widgets.GamepadGlyph = GamepadGlyph
Widgets.GetGlyphStyle = GetGlyphStyle
Widgets.GetStyleAtlas = GetStyleAtlas
Widgets.SetGlyphPrompt = SetGlyphPrompt
Widgets.SetIconTexture = SetIconTexture
Widgets.SkinPanel = SkinPanel
Widgets.SetChatPortrait = SetChatPortrait
Widgets.GetIconPath = GetIconPath
Widgets.RefreshGlyphPrompts = RefreshGlyphPrompts
Widgets.RefreshGlyphPrompt = RefreshGlyphPrompt
Widgets.CreateListIcon = CreateListIcon
Widgets.ShowError = ShowError
Widgets.PlayWheelSound = PlayWheelSound
