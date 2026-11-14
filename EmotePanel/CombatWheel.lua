local AddonName, ns = ...
local EmotePanel = ns.panel

local Pages = ns.Pages
local Entries = ns.Entries
local Bindings = ns.Bindings
local Input = ns.Input
local CombatWheel = ns.CombatWheel
local Widgets = ns.Widgets
local Wheel = ns.Wheel
local LIVE_PET_PAGE = -100

local function GetPetAutocastMacro(data)
    local command = SLASH_PET_AUTOCASTTOGGLE1 or "/petautocasttoggle"
    if data.canAutocast and not data.name:find("[%c;%[%]]") and IsSecureCmd(command) then
        return command .. " " .. data.name
    end
end

function EmotePanel:CombatDebug(group, ...)
    if not self.combatDebug then return end
    local fields = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if issecretvalue(value) then
            fields[#fields + 1] = "<secret>"
        elseif value ~= nil then
            fields[#fields + 1] = tostring(value)
        end
    end
    print(("EmotePanel debug [%s] %s"):format(group, table.concat(fields, " | ")))
end

function EmotePanel:BuildCombatLayout()
    -- Project the live layout into the IDs and action values consumed by restricted handlers.
    local pages, nested = {}, Pages.IsCategoryWheelEnabled()
    local last = Pages.GetMainPageCount()
    local function AddPage(id, source)
        local page = Pages.GetPageNavigation(id, source)
        page.mode, page.category = source.mode, source.category
        page.first, page.count, page.title = source.first, source.count, source.title
        page.snapshot, page.actions = {}, {}
        for sector = 1, source.count do
            local mode, key, data = Pages.GetSectorEntry(sector, source, true)
            if data and data.fixedSector then data = nil end
            page.snapshot[sector] = { mode, key, data }
            local kind, value = data and data.actionType
            local outOfCombat = data and Entries.IsOutOfCombat(mode, key, data)
            local marker = data and Entries.GetRaidMarker(mode, key, data)
            if source.mode == "categories" and not outOfCombat then
                local destination, empty = Pages.GetCategoryDestination(data)
                kind, value = data.actionType == "submenu" and "submenu" or "page", destination or #pages + 1
                if empty then
                    empty.back = Pages.GetPageNavigation(nil, empty).back
                    empty.snapshot, empty.actions = {}, {}
                    pages[value] = empty
                end
            elseif source.mode == "pet" then
                kind, value = "pet", data and data.actionID
            elseif kind == "submenu" then
                value = Pages.TARGET_MARKER_START
            elseif marker then
                kind, value = "raidtarget", marker
            elseif kind == "macro" then
                local name, _, body = GetMacroInfo(data.macroIndex)
                if name == data.name and type(body) == "string" then value = body end
            elseif kind == "spell" then
                value = data.actionID
            elseif kind == "item" then
                value = "item:" .. data.actionID
            elseif kind == "action" then
                value = data.actionID
            elseif data and not data.secureClick and not outOfCombat then
                kind, value = "ordinary", true
            end
            page.actions[sector] = { kind = kind, value = value }
            if source.mode == "pet" and data then
                page.actions[sector].autocast = GetPetAutocastMacro(data)
            end
        end
        pages[id] = page
    end

    for index = 1, last do AddPage(index, Pages.GetPage(index)) end
    AddPage(Pages.TARGET_MARKER_START, Pages.GetPage(Pages.TARGET_MARKER_START))
    if nested then AddPage(0, Pages.MakeCategoryWheel()) end
    local petCount = Pages.GetPetPageCount()
    local firstPetPage = Pages.GetPage(-1)
    local petName = firstPetPage and UnitName("pet")
    local dead = firstPetPage and UnitIsDead("pet")
    if issecretvalue(petName) then petName = nil end
    local cached = EmotePanel.combatPetLayout
    local reused
    if firstPetPage and firstPetPage.count == 0 and #Entries.GetOrderedEntryIDs("pet") == 0 then
        if cached and petName and cached.name == petName and not issecretvalue(dead) and dead then
            for index, page in ipairs(cached.pages) do pages[-index] = page end
            reused = true
        end
        -- A pet can become available after lockdown. Prepare native slot clicks now,
        -- and let the display read the live bar after the pet returns.
        petCount = math.ceil(NUM_PET_ACTION_SLOTS / ns.SECTOR_COUNT)
        for index = 1, petCount do
            local first = (index - 1) * ns.SECTOR_COUNT + 1
            local id = LIVE_PET_PAGE - index + 1
            local left = index > 1 and id + 1 or nil
            local right = index < petCount and id - 1 or nil
            local page = {
                mode = "pet", first = first, count = math.min(ns.SECTOR_COUNT, NUM_PET_ACTION_SLOTS - first + 1),
                title = petCount == 1 and firstPetPage.title or ("%s  %d / %d"):format(firstPetPage.title, index, petCount),
                left = left, right = right, scrollUp = right, scrollDown = left, actions = {},
            }
            for sector = 1, page.count do
                page.actions[sector] = { kind = "pet", value = first + sector - 1 }
            end
            pages[id] = page
        end
    else
        for index = 1, petCount do AddPage(-index, Pages.GetPage(-index)) end
        if firstPetPage and firstPetPage.count > 0 and petName then
            local snapshot = {}
            for index = 1, petCount do snapshot[index] = pages[-index] end
            EmotePanel.combatPetLayout = { name = petName, pages = snapshot }
        end
    end
    local petStart = pages[-1] and -1 or pages[LIVE_PET_PAGE] and LIVE_PET_PAGE
    return pages, nested and 0 or 1, petStart, reused and petName or nil
end

function EmotePanel:ShowCombatPage(index, selection, navigation)
    local page = self.combatPages[index]
    local changedPage = self.combatView and index ~= Pages.currentPageIndex
    if page.mode == "pet" and (not self.combatView or Pages.currentPage.mode ~= "pet") then
        Entries.ReadPetActions()
    end
    if not self.combatView then
        self.combatView = true
        if self.gamepadInput then self.gamepadInput:Hide() end
        if self.customMessageDialog then self.customMessageDialog:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_RESET_ALL")
        StaticPopup_Hide("EMOTEPANEL_RESET_SETTINGS")
        for index, name in ipairs(UISpecialFrames) do
            if name == self.frame:GetName() then
                table.remove(UISpecialFrames, index)
                break
            end
        end
        local point, relativePoint, x, y = unpack(self.combatPosition)
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, relativePoint, x, y)
        self.frame:Show()
    end
    Pages.SetDisplayedPage(index, page)
    self.canPageLeft = page.left ~= nil
    self.canPageRight = page.right ~= nil
    self.canGoBack = page.back ~= nil
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self.selected = nil
    self:RefreshWheel(selection)
    if changedPage then self:AnimateWheelPage(navigation) end
end

function EmotePanel:CloseCombatDisplay()
    if not self.combatView then return end
    self.frame:Hide()
    self.combatView = nil
    table.insert(UISpecialFrames, self.frame:GetName())
    if self.gamepadInput then self.gamepadInput:Show() end
    if not InCombatLockdown() then self:LoadPosition() end
    self:ShowStartPage()
    Pages.HandleAutomaticActionsChanged()
end

function EmotePanel:ActivateCombatSector(sector, fromMouse)
    if not self.combatView then return end
    local _, _, data = Pages.GetSectorEntry(sector)
    if data and data.actionType ~= "emote" then
        self:CombatDebug("Shortcut", data.actionType, "sector " .. sector)
    end
    self:ActivateSector(sector, "LeftButton", fromMouse)
end

-- Only restricted handlers may change these bindings or action attributes in combat.
local BIND = [[
    self:ClearBindings()
    local name = self:GetName()
    if self:IsShown() then
        self:SetBindingClick(true, "PAD1", name, self:GetAttribute("accept"))
        self:SetBindingClick(true, "PAD2", name, "Back")
        if self:GetAttribute("toggle-legend") then self:SetBindingClick(true, "PADBACK", name, "ToggleLegend") end
        if self:GetAttribute("pet-wheel") then
            self:SetBindingClick(true, "PAD3", name, "PetAutocast")
        elseif self:GetAttribute("submenu-origin") then
            self:SetBindingClick(true, "PAD3", name, "ClearMark")
            self:SetBindingClick(true, "PAD4", name, "MarkSelf")
        end
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
    self:SetAttribute("legend-pressed", nil)
    self:SetAttribute("submenu-origin", nil)
    self:SetAttribute("submenu-sector", nil)
    self:RunAttribute("bind-input")
]]

local SHOW_PAGE = [[
    local page, sector, navigation = ...
    self:SetAttribute("page", page)
    self:SetAttribute("sector", sector)
    self:SetAttribute("press-page", nil)
    self:SetAttribute("press-target", nil)
    self:SetAttribute("press-button", nil)
    self:CallMethod("DrawPage", page, sector, navigation)
]]

local MARK_TARGET = [[
    local marker, unit = ...
    self:SetAttribute("unit", unit)
    self:SetAttribute("marker", marker)
    self:SetAttribute("action", marker == 0 and "clear" or "set")
    self:SetAttribute("type", "raidtarget")
    self:SetAttribute("commit", true)
]]

-- Coordinates are relative to the same panel bounds used by the display.
local HIT = [[
    local button = ...
    local x, y = self:GetMousePosition()
    if not x then return end
    x, y = x * self:GetWidth(), y * self:GetHeight()
    x, y = x - self:GetAttribute("wheel-x"), y - self:GetAttribute("wheel-y")
    local distance = x * x + y * y
    if button == "LeftButton" and self:GetAttribute("submenu-origin")
        and distance <= self:GetAttribute("clear-mark-radius-squared") then
        return "ClearMark"
    end
    if distance < self:GetAttribute("inner-squared") then
        if button == "RightButton" then return "Back" end
        return
    end
    if distance > self:GetAttribute("outer-squared") then return end
    return math.floor(math.atan2(x, y) / (math.pi / 4) + 0.5) % 8 + 1
]]

local PRE_CLICK = [[
    self:SetAttribute("type", nil)
    self:SetAttribute("commit", nil)
    self:SetAttribute("autocast-commit", nil)
    local combat = SecureCmdOptionParse("[combat] 1; 0") == "1"
    if button == "Toggle" or button == "TogglePet" then
        if down then return end
        local pet = button == "TogglePet"
        local prefix = pet and "pet-" or ""
        local start = self:GetAttribute(prefix .. "start")
        if start == nil then return end
        if not combat then
            self:CallMethod("ToggleDisplay", pet)
        elseif self:IsShown() and self:GetAttribute("pet-wheel") == pet then
            self:RunAttribute("close-wheel")
        elseif pet and SecureCmdOptionParse("[@pet,exists] 1; 0") ~= "1" then
            self:CallMethod("ShowUnavailable", "no-pet")
        elseif pet and SecureCmdOptionParse("[@pet,exists,nodead] 1; 0") ~= "1" then
            self:CallMethod("ShowUnavailable", "dead-pet")
        else
            self:SetAttribute("pet-wheel", pet)
            self:SetAttribute("submenu-origin", nil)
            self:SetAttribute("submenu-sector", nil)
            if not self:IsShown() then
                self:Show()
            end
            local page = self:GetAttribute(prefix .. "resume-page") or start
            local sector = self:GetAttribute(prefix .. "resume-sector")
            local cachedPet = pet and self:GetAttribute("cached-pet")
            if cachedPet then
                local _, activePet = PlayerPetSummary()
                if activePet ~= cachedPet then
                    page, sector = self:GetAttribute("live-pet-page"), nil
                elseif page <= self:GetAttribute("live-pet-page") then
                    page, sector = start, nil
                end
            end
            self:RunAttribute("show-page", page, sector)
            self:RunAttribute("bind-input")
        end
        return
    end
    if not combat or not self:IsVisible() then return end
    if button == "ToggleLegend" then
        if down then
            self:SetAttribute("legend-pressed", not IsModifierKeyDown())
        else
            local pressed = self:GetAttribute("legend-pressed")
            self:SetAttribute("legend-pressed", nil)
            if pressed and not IsModifierKeyDown() then self:CallMethod("ToggleLegend") end
        end
        return
    end

    local page = self:GetAttribute("page")
    local prefix = "p" .. page .. "-"
    local count = self:GetAttribute(prefix .. "count")
    local target = button
    if button == "LeftButton" or button == "RightButton" then target = self:RunAttribute("hit", button) end
    local markSelf = button == "MarkSelf"
    if markSelf and not self:GetAttribute("submenu-origin") then return end
    local toggleAutocast = button == "PetAutocast" or (button == "RightButton" and type(target) == "number")
    if toggleAutocast and not self:GetAttribute("pet-wheel") then
        if button == "PetAutocast" then return end
        target = nil
    end
    if down then
        if button == "Accept" or button == "PetAutocast" or markSelf then
            target = nil
            if not IsModifierKeyDown() then
                target = self:RunAttribute("aim", count) or self:GetAttribute("sector")
            end
        end
        self:SetAttribute("press-page", page)
        self:SetAttribute("press-target", target)
        self:SetAttribute("press-button", button)
        if type(target) == "number" then self:CallMethod("DrawPress", button, target) end
        return
    end
    local pressedTarget = self:GetAttribute("press-target")
    local pressed = self:GetAttribute("press-page") == page and self:GetAttribute("press-button") == button
    if button == "Accept" or button == "PetAutocast" or markSelf then target = pressedTarget end
    self:SetAttribute("press-page", nil)
    self:SetAttribute("press-target", nil)
    self:SetAttribute("press-button", nil)
    self:CallMethod("DrawPress", button)
    if not target or not pressed or pressedTarget ~= target or (toggleAutocast and type(target) ~= "number") then
        if button == "Accept" then self:CallMethod("DebugClick", "Input", "A/Cross canceled", "page " .. page) end
        return
    end

    if target == "Close" then
        self:RunAttribute("close-wheel")
    elseif target == "Left" or target == "Right" or target == "Back" then
        local destination = self:GetAttribute(prefix .. target)
        if target == "Back" and destination == true then
            local origin = self:GetAttribute("submenu-origin")
            local sector = self:GetAttribute("submenu-sector")
            self:SetAttribute("submenu-origin", nil)
            self:SetAttribute("submenu-sector", nil)
            if origin then self:RunAttribute("show-page", origin, sector, true) end
            self:RunAttribute("bind-input")
        elseif destination then
            self:RunAttribute("show-page", destination, nil, true)
        elseif target == "Back" then self:RunAttribute("close-wheel") end
    elseif target == "ClearMark" then
        if not self:GetAttribute("submenu-origin") or (button ~= "LeftButton" and IsModifierKeyDown()) then return end
        local unit = SecureCmdOptionParse("[@target,exists] target; player")
        self:RunAttribute("mark-target", 0, unit)
    elseif target == "Up" or target == "Down" then
        if count > 0 then
            local sector = self:GetAttribute("sector")
            if sector then
                sector = sector + (target == "Up" and -1 or 1)
                if self:GetAttribute("stop-at-segment-ends") and (sector < 1 or sector > count) then return end
                sector = (sector - 1) % count + 1
            else
                sector = target == "Up" and count or 1
            end
            self:SetAttribute("sector", sector)
            self:CallMethod("DrawSelection", sector, true, true)
        end
    elseif type(target) == "number" then
        if IsModifierKeyDown() and button ~= "LeftButton" then return end
        local sector = target
        if sector > count then return end
        self:SetAttribute("sector", sector)
        self:CallMethod("DrawSelection", sector)
        local kind = self:GetAttribute(prefix .. sector .. "-kind")
        local value = self:GetAttribute(prefix .. sector .. "-value")
        if kind == "pet" and (HasVehicleActionBar() or SecureCmdOptionParse("[@pet,exists,nodead] 1; 0") ~= "1") then
            return
        end
        if kind == "action" and not HasExtraActionBar() then return end
        if kind == "raidtarget" and not markSelf and SecureCmdOptionParse("[@target,exists] 1; 0") ~= "1" then
            self:CallMethod("ShowUnavailable", "no-target", sector)
            return
        end
        if toggleAutocast then
            local macro = self:GetAttribute(prefix .. sector .. "-autocast")
            local petName = self:GetAttribute("autocast-pet")
            if macro and petName then
                local _, activePet = PlayerPetSummary()
                if activePet == petName then
                    self:SetAttribute("macrotext", macro)
                    self:SetAttribute("type", "macro")
                    self:SetAttribute("autocast-commit", true)
                end
            end
            return
        end
        if value == nil then
            self:CallMethod("ShowUnavailable", kind, sector)
            return
        end
        if kind == "submenu" then
            self:SetAttribute("submenu-origin", page)
            self:SetAttribute("submenu-sector", sector)
            self:RunAttribute("show-page", value, 1, true)
            self:RunAttribute("bind-input")
        elseif kind == "page" then
            self:RunAttribute("show-page", value, nil, true)
        else
            if self:GetAttribute("remember-last-action") and not self:GetAttribute("submenu-origin") then
                local resumePrefix = self:GetAttribute("pet-wheel") and "pet-" or ""
                self:SetAttribute(resumePrefix .. "resume-page", page)
                self:SetAttribute(resumePrefix .. "resume-sector", sector)
                self:CallMethod("RememberAction", sector)
            end
            if kind == "ordinary" then
                -- CallMethod cannot return the outcome to the secure close handler.
                self:CallMethod("UseOrdinary", sector, button == "LeftButton")
            elseif kind == "spell" or kind == "item" or kind == "macro" then
                self:SetAttribute(kind == "macro" and "macrotext" or kind, value)
                self:SetAttribute("type", kind)
                self:SetAttribute("commit", true)
            elseif kind == "raidtarget" then
                self:RunAttribute("mark-target", value, markSelf and "player" or "target")
            elseif kind == "pet" or kind == "action" then
                self:SetAttribute("action", value)
                self:SetAttribute("type", kind)
                self:SetAttribute("commit", true)
            end
        end
    end
]]

local POST_CLICK = [[
    local kind = self:GetAttribute("type")
    local close = self:GetAttribute("commit") and self:GetAttribute("close-after-action")
    if self:GetAttribute("autocast-commit") then
        self:CallMethod("RefreshPetAutocast")
    elseif kind then
        self:CallMethod("FinishSecureAction", kind, close, button)
    end
    self:SetAttribute("type", nil)
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("action", nil)
    self:SetAttribute("marker", nil)
    self:SetAttribute("unit", nil)
    self:SetAttribute("macrotext", nil)
    if close then
        self:RunAttribute("close-wheel")
    end
    self:SetAttribute("commit", nil)
    self:SetAttribute("autocast-commit", nil)
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
    local button = CreateFrame("Button", Bindings.INPUT_NAME, UIParent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:Hide()
    button:SetAttribute("nodeignore", true)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    button:SetClampedToScreen(true)
    button:EnableMouse(true)
    button:EnableMouseWheel(true)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("bind-input", BIND)
    button:SetAttribute("close-wheel", CLOSE)
    button:SetAttribute("mark-target", MARK_TARGET)
    button:SetAttribute("show-page", SHOW_PAGE)
    button:SetAttribute("hit", HIT)
    button:SetAttribute("aim", AIM)
    button:SetAttribute("_onstate-combat", [[
        if newstate ~= "combat" then self:RunAttribute("close-wheel") end
    ]])
    button:SetAttribute("_onstate-pet", [[
        if newstate ~= "alive" and self:IsShown() and self:GetAttribute("pet-wheel") then
            self:RunAttribute("close-wheel")
        end
    ]])
    function button:ToggleDisplay(pet) EmotePanel:ToggleWheel(pet) end
    function button:DrawPage(page, sector, navigation)
        EmotePanel:CombatDebug("Wheel", EmotePanel.combatPages[page].title)
        EmotePanel:ShowCombatPage(page, sector, navigation)
    end
    function button:CloseDisplay() EmotePanel:CloseCombatDisplay() end
    function button:DrawSelection(sector, showTooltip, dpad)
        EmotePanel:Select(sector, showTooltip, dpad and SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER, dpad)
    end
    function button:DrawPress(input, sector) EmotePanel:SetWheelPressed(sector, input) end
    function button:ToggleLegend() EmotePanel:ToggleWheelLegend() end
    function button:RememberAction(sector) EmotePanel:RememberAction(sector) end
    function button:UseOrdinary(sector, fromMouse) EmotePanel:ActivateCombatSector(sector, fromMouse) end
    function button:RefreshPetAutocast() EmotePanel:RefreshPetAutocast() end
    function button:ShowUnavailable(kind, sector)
        if kind == "no-pet" or kind == "dead-pet" then
            Widgets.ShowError(kind == "dead-pet" and "Pet is dead" or "No pet summoned")
            return
        end
        if kind == "no-target" then
            Widgets.ShowError(ERR_GENERIC_NO_TARGET, LE_GAME_ERR_GENERIC_NO_TARGET)
            return
        end
        if EmotePanel.combatDebug then EmotePanel:CombatDebug("Unavailable", kind, "sector " .. sector) end
        Widgets.ShowError("Unavailable in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
    end
    function button:FinishSecureAction(kind, close, input)
        if EmotePanel.combatDebug then
            local movementHeld = close and EmotePanelSavedVars.lockMovementStick ~= false and Input.GetHeldMovementStick()
            local page = EmotePanel.combatPages[self:GetAttribute("page")]
            EmotePanel:CombatDebug("Secure click", kind, page.title, "sector " .. self:GetAttribute("sector"),
                input, movementHeld and "movement held until neutral" or nil)
        end
    end
    function button:DebugClick(...) EmotePanel:CombatDebug(...) end
    button:SetScript("OnEnter", function() EmotePanel:StartWheelMouseTooltip() end)
    button:SetScript("OnLeave", function()
        EmotePanel:StopWheelMouseTooltip()
        EmotePanel:SetWheelPressed(nil, "LeftButton")
        EmotePanel:SetWheelPressed(nil, "RightButton")
    end)
    button:SetScript("OnUpdate", function(input)
        if not EmotePanel.combatView then return end
        local page = EmotePanel.combatPages[input:GetAttribute("page")]
        local selected, aim
        local pressed = input:GetAttribute("press-button")
        if pressed == "Accept" or pressed == "PetAutocast" then
            selected = input:GetAttribute("press-target")
        else
            aim = ReadAim(input, page.count)
            selected = aim or input:GetAttribute("sector")
        end
        if selected ~= EmotePanel.selected or aim then
            EmotePanel:Select(selected, true, aim and SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT, aim ~= nil)
        end
    end)
    SecureHandlerWrapScript(button, "PreClick", button, PRE_CLICK)
    SecureHandlerWrapScript(button, "PostClick", button, POST_CLICK)
    SecureHandlerWrapScript(button, "OnMouseWheel", button, [[
        if offset == 0 or not self:IsVisible() then return end
        local page = self:GetAttribute("page")
        if not page then return end
        local direction = offset > 0 and "ScrollUp" or "ScrollDown"
        local destination = self:GetAttribute("p" .. page .. "-" .. direction)
        if destination then self:RunAttribute("show-page", destination, nil, true) end
    ]])
    self.combatInput = button
    return button
end

function EmotePanel:SyncCombatResume()
    local button = self.combatInput
    if not button or InCombatLockdown() or self.combatView then return end
    local pageIndex, selection, petPage, petSelection
    if EmotePanelSavedVars.rememberLastAction then
        for index, page in pairs(self.combatPages) do
            local sector = self:FindRememberedSector(page)
            if sector and page.actions[sector].value ~= nil then
                if page.mode == "pet" then
                    petPage, petSelection = index, sector
                else
                    pageIndex, selection = index, sector
                end
            end
        end
    end
    button:SetAttribute("resume-page", pageIndex)
    button:SetAttribute("resume-sector", selection)
    button:SetAttribute("pet-resume-page", petPage)
    button:SetAttribute("pet-resume-sector", petSelection)
end

function EmotePanel:SyncCombatWheel(refreshControls)
    -- Keep the snapshot and protected attributes fixed while combat owns the wheel.
    if InCombatLockdown() or self.combatView or not self.wheel or self.migratingWheelBinding then return end
    if not refreshControls and not self.combatLayoutDirty then return end
    local legacyKeys = Bindings.GetLegacyWheelKeys()
    local hasPetBinding = self.supportsPetWheel and self:HasWheelBinding(true)
    if #legacyKeys == 0 and not self:HasWheelBinding() and not hasPetBinding and not self.combatInput then return end
    local new = not self.combatInput
    local button = self.combatInput or CreateCombatInput(self)
    if new or refreshControls then self:ConfigureCombatInput(button) end

    if new or self.combatLayoutDirty then
        local pages, start, petStart, cachedPet = self:BuildCombatLayout()
        self.combatPages = pages
        self.combatLayoutDirty = nil
        button:SetAttribute("start", start)
        button:SetAttribute("stop-at-segment-ends", EmotePanelSavedVars.stopAtSegmentEnds == true)
        button:SetAttribute("pet-start", petStart)
        button:SetAttribute("cached-pet", cachedPet)
        local petName = petStart and UnitName("pet")
        self.combatAutocastPet = not issecretvalue(petName) and petName or nil
        button:SetAttribute("autocast-pet", self.combatAutocastPet)
        for index, page in pairs(pages) do
            local prefix = "p" .. index .. "-"
            button:SetAttribute(prefix .. "count", page.count)
            button:SetAttribute(prefix .. "Left", page.left)
            button:SetAttribute(prefix .. "Right", page.right)
            button:SetAttribute(prefix .. "Back", page.back)
            button:SetAttribute(prefix .. "ScrollUp", page.scrollUp)
            button:SetAttribute(prefix .. "ScrollDown", page.scrollDown)
            for sector, entry in ipairs(page.actions) do
                button:SetAttribute(prefix .. sector .. "-kind", entry.kind)
                button:SetAttribute(prefix .. sector .. "-value", entry.value)
                if entry.kind == "pet" then
                    button:SetAttribute(prefix .. sector .. "-autocast", entry.autocast)
                end
            end
        end
    end
    self:SyncCombatResume()
    if new then
        RegisterStateDriver(button, "combat", "[combat] combat; peace")
        if self.supportsPetWheel then RegisterStateDriver(button, "pet", "[@pet,exists,nodead] alive; unavailable") end
    end
    Bindings.MigrateWheelBindings(self, legacyKeys)

    self.combatBindingReady = self:HasWheelBinding()
end

function EmotePanel:ConfigureCombatInput(button)
    button:SetAttribute("accept", GetBindingFromClick("PAD1") == "TOGGLEGAMEMENU" and "Close" or "Accept")
    button:SetAttribute("live-pet-page", LIVE_PET_PAGE)
    button:SetAttribute("toggle-legend", Input.CanToggleLegend())
    button:SetAttribute("close-after-action", EmotePanelSavedVars.closePanelAfterAction ~= false)
    button:SetAttribute("remember-last-action", EmotePanelSavedVars.rememberLastAction == true)

    local width, height = self.frame:GetSize()
    local position = self:GetWheelPosition()
    local point, relativePoint, x, y = position.point, position.relativePoint, position.x, position.y
    self.combatPosition = { point, relativePoint, x, y }
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint(point, UIParent, relativePoint, x, y)
    local wheelRadius = self.wheel:GetWidth() / 2
    local wheelInfo = C_Texture.GetAtlasInfo("gamepad-radial-menu-wheelbg") or { width = 525 }
    local scale = wheelRadius * 2 / wheelInfo.width
    button:SetAttribute("wheel-x", width / 2)
    button:SetAttribute("wheel-y", height - Wheel.TOP_OFFSET - wheelRadius)
    button:SetAttribute("inner-squared", (75 * scale) ^ 2)
    button:SetAttribute("outer-squared", (234 * scale) ^ 2)
    button:SetAttribute("clear-mark-radius-squared", Wheel.CLEAR_MARK_RADIUS ^ 2)

    local stickCount = 0
    local stickIndex = 0
    while true do
        local name = C_GamePad.StickIndexToConfigName(stickIndex)
        if not name then break end
        if Input.STICKS[name] then
            stickCount = stickCount + 1
            button:SetAttribute("stick-" .. stickCount, stickIndex + 1)
        end
        stickIndex = stickIndex + 1
    end
    button:SetAttribute("stick-count", stickCount)
end

local function ReportRestriction(event, addon, action)
    if EmotePanel.combatDebug then
        if not issecretvalue(addon) and addon == AddonName then EmotePanel:CombatDebug("WoW restriction", event, action) end
    end
end

CombatWheel.GetPetAutocastMacro = GetPetAutocastMacro
CombatWheel.ReportRestriction = ReportRestriction
