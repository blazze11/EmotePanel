local EmotePanel = EmotePanel
local INPUT_NAME = "EmotePanelCombatInput"
local WHEEL_BINDING = "CLICK " .. INPUT_NAME .. ":Toggle"
local LEGACY_BINDING = "Open Emote Panel"

-- Only restricted handlers may change these bindings or action attributes in combat.
local BIND = [[
    self:ClearBindings()
    local name = self:GetName()
    if self:IsShown() then
        self:SetBindingClick(true, "PAD1", name, self:GetAttribute("accept"))
        self:SetBindingClick(true, "PAD2", name, "Back")
        self:SetBindingClick(true, "PADFORWARD", name, "Close")
        self:SetBindingClick(true, "ESCAPE", name, "Close")
        self:SetBindingClick(true, "PADLSHOULDER", name, "Left")
        self:SetBindingClick(true, "PADDLEFT", name, "Left")
        self:SetBindingClick(true, "PADRSHOULDER", name, "Right")
        self:SetBindingClick(true, "PADDRIGHT", name, "Right")
        self:SetBindingClick(true, "PADDUP", name, "Up")
        self:SetBindingClick(true, "PADDDOWN", name, "Down")
    end
]]

local CLOSE = [[
    if self:IsShown() then
        self:Hide()
        self:CallMethod("CloseDisplay")
    end
    self:SetAttribute("press-page", nil)
    self:SetAttribute("press-target", nil)
    self:SetAttribute("press-button", nil)
    self:RunAttribute("bind-input")
]]

local SHOW_PAGE = [[
    local page, sector = ...
    self:SetAttribute("page", page)
    self:SetAttribute("sector", sector)
    self:SetAttribute("press-page", nil)
    self:SetAttribute("press-target", nil)
    self:SetAttribute("press-button", nil)
    self:CallMethod("DrawPage", page, sector)
]]

-- Coordinates are relative to the same panel bounds used by the display.
local HIT = [[
    local x, y = self:GetMousePosition()
    if not x then return end
    x, y = x * self:GetWidth(), y * self:GetHeight()
    for _, control in ipairs(newtable("Left", "Right", "Back", "Close")) do
        local left = self:GetAttribute(control .. "-left")
        local right = self:GetAttribute(control .. "-right")
        local bottom = self:GetAttribute(control .. "-bottom")
        local top = self:GetAttribute(control .. "-top")
        if left and x >= left and x <= right and y >= bottom and y <= top then return control end
    end
    x, y = x - self:GetAttribute("wheel-x"), y - self:GetAttribute("wheel-y")
    local distance = x * x + y * y
    if distance < self:GetAttribute("inner-squared") or distance > self:GetAttribute("outer-squared") then return end
    return math.floor(math.atan2(x, y) / (math.pi / 4) + 0.5) % 8 + 1
]]

local PRE_CLICK = [[
    self:SetAttribute("type", nil)
    self:SetAttribute("commit", nil)
    local combat = SecureCmdOptionParse("[combat] 1; 0") == "1"
    if button == "Toggle" then
        if down then return end
        if not combat then
            self:CallMethod("ToggleDisplay")
        elseif self:IsShown() then
            self:RunAttribute("close-wheel")
        else
            self:Show()
            self:RunAttribute("bind-input")
            local page = self:GetAttribute("resume-page") or self:GetAttribute("start")
            self:RunAttribute("show-page", page, self:GetAttribute("resume-sector"))
        end
        return
    end
    if not combat or not self:IsVisible() then return end

    local page = self:GetAttribute("page")
    local prefix = "p" .. page .. "-"
    local count = self:GetAttribute(prefix .. "count")
    local target = button
    if button == "LeftButton" then target = self:RunAttribute("hit") end
    if down then
        if button == "Accept" then
            target = nil
            if not IsModifierKeyDown() then
                target = self:RunAttribute("aim", count) or self:GetAttribute("sector")
            end
        end
        self:SetAttribute("press-page", page)
        self:SetAttribute("press-target", target)
        self:SetAttribute("press-button", button)
        return
    end
    local pressedTarget = self:GetAttribute("press-target")
    local pressed = self:GetAttribute("press-page") == page and self:GetAttribute("press-button") == button
    if button == "Accept" then target = pressedTarget end
    self:SetAttribute("press-page", nil)
    self:SetAttribute("press-target", nil)
    self:SetAttribute("press-button", nil)
    if not target or not pressed or pressedTarget ~= target then
        if button == "Accept" then self:CallMethod("DebugClick", "Input", "A/Cross canceled", "page " .. page) end
        return
    end

    if target == "Close" then
        self:RunAttribute("close-wheel")
    elseif target == "Left" or target == "Right" or target == "Back" then
        local destination = self:GetAttribute(prefix .. target)
        if destination then self:RunAttribute("show-page", destination)
        elseif target == "Back" and button ~= "LeftButton" then self:RunAttribute("close-wheel") end
    elseif target == "Up" or target == "Down" then
        if count > 0 then
            local sector = self:GetAttribute("sector")
            if sector then
                sector = (sector - 1 + (target == "Up" and -1 or 1)) % count + 1
            else
                sector = target == "Up" and count or 1
            end
            self:SetAttribute("sector", sector)
            self:CallMethod("DrawSelection", sector)
        end
    elseif type(target) == "number" then
        if IsModifierKeyDown() and button ~= "LeftButton" then return end
        local sector = target
        if sector > count then return end
        self:SetAttribute("sector", sector)
        self:CallMethod("DrawSelection", sector)
        local kind = self:GetAttribute(prefix .. sector .. "-kind")
        local value = self:GetAttribute(prefix .. sector .. "-value")
        if value == nil then
            self:CallMethod("ShowUnavailable", kind, sector)
            return
        end
        if kind == "page" then
            self:RunAttribute("show-page", value)
        else
            if self:GetAttribute("remember-last-action") then
                self:SetAttribute("resume-page", page)
                self:SetAttribute("resume-sector", sector)
                self:CallMethod("RememberAction", sector)
            end
            if kind == "ordinary" then
                -- CallMethod cannot return the outcome to the secure close handler.
                self:CallMethod("UseOrdinary", sector, button == "LeftButton")
            elseif kind == "spell" or kind == "item" or kind == "macro" then
                self:SetAttribute(kind == "macro" and "macrotext" or kind, value)
                self:SetAttribute("type", kind)
                self:SetAttribute("commit", true)
            end
        end
    end
]]

local POST_CLICK = [[
    local kind = self:GetAttribute("type")
    local close = self:GetAttribute("commit") and self:GetAttribute("close-after-action")
    if kind then self:CallMethod("FinishSecureAction", kind, close, button) end
    self:SetAttribute("type", nil)
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("macrotext", nil)
    if close then
        self:RunAttribute("close-wheel")
    end
    self:SetAttribute("commit", nil)
]]

-- Read the state inside the snippet. RunAttribute scrubs table arguments.
-- Keep the angle and dead zone in sync with ReadAim.
local AIM = [[
    local count = ...
    local state = GetGamePadState()
    if not state or IsModifierKeyDown() then return end
    local best, length = nil, 0.25
    for index = 1, self:GetAttribute("stick-count") do
        local stick = state.sticks[self:GetAttribute("stick-" .. index)]
        if stick then
            local distance = stick.x * stick.x + stick.y * stick.y
            if distance >= length then
                local sector = math.floor(math.atan2(stick.x, stick.y) / (math.pi / 4) + 0.5) % 8 + 1
                if sector <= count then best, length = sector, distance end
            end
        end
    end
    return best
]]

local STICKS = { Movement = true, Left = true, Camera = true, Right = true }

local function MovementStickHeld(index)
    local state = C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[index]
    return stick and (stick.x ~= 0 or stick.y ~= 0)
end

function EmotePanel:CreateWheelMovementGuard()
    -- Keep receiving stick input after the secure wheel and its bindings close.
    local guard = CreateFrame("Frame", nil, UIParent)
    guard:Hide()
    guard:SetFrameStrata("TOOLTIP")
    guard:EnableGamePadStick(true)
    guard:SetScript("OnGamePadStick", function(frame, stick, x, y)
        if stick ~= "Movement" and stick ~= "Left" then return true end
        if x ~= 0 or y ~= 0 then return false end
        if stick == frame.movementStick then frame:Hide() end
        return true
    end)
    guard:SetScript("OnUpdate", function(frame)
        if not MovementStickHeld(frame.movementIndex) then frame:Hide() end
    end)
    self.wheelMovementGuard = guard
end

local function HoldWheelMovement(guard)
    local index, leftIndex = 0
    local name = C_GamePad.StickIndexToConfigName(index)
    while name and name ~= "Movement" do
        if name == "Left" then leftIndex = index + 1 end
        index = index + 1
        name = C_GamePad.StickIndexToConfigName(index)
    end
    local movementIndex = name and index + 1 or leftIndex
    if movementIndex and MovementStickHeld(movementIndex) then
        guard.movementIndex = movementIndex
        guard.movementStick = name or "Left"
        guard:Show()
        return true
    end
    return false
end

local function ReadAim(button, count)
    local state = C_GamePad.GetDeviceMappedState()
    if not state or IsModifierKeyDown() then return end
    local best, length = nil, 0.25
    for index = 1, button:GetAttribute("stick-count") do
        local stick = state.sticks[button:GetAttribute("stick-" .. index)]
        if stick then
            local distance = stick.x * stick.x + stick.y * stick.y
            if distance >= length then
                local sector = math.floor(math.atan2(stick.x, stick.y) / (math.pi / 4) + 0.5) % 8 + 1
                if sector <= count then best, length = sector, distance end
            end
        end
    end
    return best
end

local function CreateCombatInput(self)
    local button = CreateFrame("Button", INPUT_NAME, UIParent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:Hide()
    button:SetAttribute("nodeignore", true)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    button:SetClampedToScreen(true)
    button:EnableMouse(true)
    button:EnableGamePadStick(true)
    button:SetScript("OnGamePadStick", function(_, stick, x, y)
        if not STICKS[stick] or IsModifierKeyDown() then return true end
        return (stick == "Movement" or stick == "Left") and x == 0 and y == 0
    end)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("bind-input", BIND)
    button:SetAttribute("close-wheel", CLOSE)
    button:SetAttribute("show-page", SHOW_PAGE)
    button:SetAttribute("hit", HIT)
    button:SetAttribute("aim", AIM)
    button:SetAttribute("_onstate-combat", [[
        if newstate ~= "combat" then self:RunAttribute("close-wheel") end
    ]])
    function button:ToggleDisplay() EmotePanel_Toggle() end
    function button:DrawPage(page, sector)
        EmotePanel:CombatDebug("Wheel", EmotePanel.combatPages[page].title)
        EmotePanel:ShowCombatPage(page, sector)
    end
    function button:CloseDisplay() EmotePanel:CloseCombatDisplay() end
    function button:DrawSelection(sector) EmotePanel:Select(sector) end
    function button:RememberAction(sector) EmotePanel:RememberAction(sector) end
    function button:UseOrdinary(sector, fromMouse) EmotePanel:ActivateCombatSector(sector, fromMouse) end
    function button:ShowUnavailable(kind, sector)
        if EmotePanel.combatDebug then
            EmotePanel:CombatDebug("Unavailable", kind, "sector " .. sector)
        else
            print("EmotePanel: Unavailable in combat.")
        end
    end
    function button:FinishSecureAction(kind, close, input)
        local movementHeld = close and HoldWheelMovement(EmotePanel.wheelMovementGuard)
        if EmotePanel.combatDebug then
            local page = EmotePanel.combatPages[self:GetAttribute("page")]
            EmotePanel:CombatDebug("Secure click", kind, page.title, "sector " .. self:GetAttribute("sector"),
                input, movementHeld and "movement held until neutral" or nil)
        end
    end
    function button:DebugClick(...) EmotePanel:CombatDebug(...) end
    button:SetScript("OnUpdate", function(input)
        if not EmotePanel.combatView then return end
        local page = EmotePanel.combatPages[input:GetAttribute("page")]
        local selected
        if input:GetAttribute("press-button") == "Accept" then
            selected = input:GetAttribute("press-target")
        else
            selected = ReadAim(input, page.count) or input:GetAttribute("sector")
        end
        if selected ~= EmotePanel.selected then EmotePanel:Select(selected) end
    end)
    SecureHandlerWrapScript(button, "PreClick", button, PRE_CLICK)
    SecureHandlerWrapScript(button, "PostClick", button, POST_CLICK)
    self.combatInput = button
    return button
end

local function SetRect(button, name, left, bottom, width, height)
    button:SetAttribute(name .. "-left", left)
    button:SetAttribute(name .. "-bottom", bottom)
    button:SetAttribute(name .. "-right", left + width)
    button:SetAttribute(name .. "-top", bottom + height)
end

function EmotePanel:HasWheelBinding()
    return GetBindingKey(WHEEL_BINDING) ~= nil
end

function EmotePanel:SyncCombatResume()
    local button = self.combatInput
    if not button or InCombatLockdown() or self.combatView then return end
    local pageIndex, selection
    if EmotePanelSavedVars.rememberLastAction and self.lastAction then
        for index, page in pairs(self.combatPages) do
            local sector = self:FindRememberedSector(page)
            if sector and page.actions[sector].value ~= nil then
                pageIndex, selection = index, sector
                break
            end
        end
    end
    button:SetAttribute("resume-page", pageIndex)
    button:SetAttribute("resume-sector", selection)
end

function EmotePanel:SyncCombatWheel(refreshControls)
    if InCombatLockdown() or self.combatView or not self.wheel or self.migratingWheelBinding then return end
    if not refreshControls and not self.combatLayoutDirty then return end
    local legacyKeys = { GetBindingKey(LEGACY_BINDING) }
    if #legacyKeys == 0 and not self:HasWheelBinding() and not self.combatInput then return end
    local new = not self.combatInput
    local button = self.combatInput or CreateCombatInput(self)
    if new or refreshControls then self:ConfigureCombatInput(button) end

    if new or self.combatLayoutDirty then
        local pages, start = self:BuildCombatLayout()
        self.combatPages = pages
        self.combatLayoutDirty = nil
        button:SetAttribute("start", start)
        for index, page in pairs(pages) do
            local prefix = "p" .. index .. "-"
            button:SetAttribute(prefix .. "count", page.count)
            button:SetAttribute(prefix .. "Left", page.left)
            button:SetAttribute(prefix .. "Right", page.right)
            button:SetAttribute(prefix .. "Back", page.back)
            for sector, entry in ipairs(page.actions) do
                button:SetAttribute(prefix .. sector .. "-kind", entry.kind)
                button:SetAttribute(prefix .. sector .. "-value", entry.value)
            end
        end
    end
    self:SyncCombatResume()
    if new then RegisterStateDriver(button, "combat", "[combat] combat; peace") end
    local bindingSet = GetCurrentBindingSet()
    if #legacyKeys > 0 and (bindingSet == 1 or bindingSet == 2) then
        -- Move only keys assigned to the previous opener. Keep the same keys
        -- in the player's active account or character binding set.
        self.migratingWheelBinding = true
        local changed = false
        for _, key in ipairs(legacyKeys) do
            if SetBindingClick(key, INPUT_NAME, "Toggle") then changed = true end
        end
        if changed then SaveBindings(bindingSet) end
        self.migratingWheelBinding = nil
    end
    self.combatBindingReady = self:HasWheelBinding()
end

function EmotePanel:ConfigureCombatInput(button)
    button:SetAttribute("accept", GetBindingFromClick("PAD1") == "TOGGLEGAMEMENU" and "Close" or "Accept")
    button:SetAttribute("close-after-action", EmotePanelSavedVars.closePanelAfterAction ~= false)
    button:SetAttribute("remember-last-action", EmotePanelSavedVars.rememberLastAction == true)

    local width, height = self.frame:GetSize()
    local position = EmotePanelSavedVars.positions and EmotePanelSavedVars.positions.emotePanel
    local point, relativePoint, x, y = "CENTER", "CENTER", 0, 0
    if position then point, relativePoint, x, y = position.point, position.relativePoint, position.x, position.y end
    self.combatPosition = { point, relativePoint, x, y }
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint(point, UIParent, relativePoint, x, y)
    local wheelRadius = self.wheel:GetWidth() / 2
    local wheelInfo = C_Texture.GetAtlasInfo("gamepad-radial-menu-wheelbg") or { width = 525 }
    local scale = wheelRadius * 2 / wheelInfo.width
    button:SetAttribute("wheel-x", width / 2)
    button:SetAttribute("wheel-y", height - 54 - wheelRadius)
    button:SetAttribute("inner-squared", (75 * scale) ^ 2)
    button:SetAttribute("outer-squared", (234 * scale) ^ 2)
    SetRect(button, "Left", width / 2 - 125, height - 43, 14, 22)
    SetRect(button, "Right", width / 2 + 111, height - 43, 14, 22)
    SetRect(button, "Back", width / 2 - 172, height - 37, 40, 24)
    SetRect(button, "Close", width - 40, height - 40, 30, 30)

    local stickCount = 0
    local stickIndex = 0
    while true do
        local name = C_GamePad.StickIndexToConfigName(stickIndex)
        if not name then break end
        if STICKS[name] then
            stickCount = stickCount + 1
            button:SetAttribute("stick-" .. stickCount, stickIndex + 1)
        end
        stickIndex = stickIndex + 1
    end
    button:SetAttribute("stick-count", stickCount)
end
