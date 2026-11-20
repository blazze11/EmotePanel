local AddonName, ns = ...
local EmotePanel = ns.panel

local Entries = ns.Entries
local Bindings = ns.Bindings
local Pages = ns.Pages
local Wheel = ns.Wheel
local Input = ns.Input
local CombatWheel = ns.CombatWheel
local Widgets = ns.Widgets

local NAVIGATION_REPEAT_STEP = 10
local navigationRepeatTiming = {
    enabledKey = "repeatWheelSegments",
    delay = { key = "wheelRepeatDelay", default = 300, min = 100, max = 1000 },
    interval = { key = "wheelRepeatInterval", default = 130, min = 50, max = 500 },
}
local pagingRepeatTiming = {
    enabledKey = "repeatWheelPaging",
    delay = { key = "wheelPageRepeatDelay", default = 300, min = 100, max = 1000 },
    interval = { key = "wheelPageRepeatInterval", default = 130, min = 50, max = 500 },
}

local function InitializeRepeatTiming()
    local saved = EmotePanelSavedVars
    if saved.repeatWheelNavigation ~= nil then
        if saved.repeatWheelSegments == nil then saved.repeatWheelSegments = saved.repeatWheelNavigation end
        if saved.repeatWheelPaging == nil then saved.repeatWheelPaging = saved.repeatWheelNavigation end
        saved.repeatWheelNavigation = nil
    end
    if saved.splitWheelRepeatTiming then return end
    for _, kind in ipairs({"delay", "interval"}) do
        local key = pagingRepeatTiming[kind].key
        if saved[key] == nil then
            saved[key] = saved[navigationRepeatTiming[kind].key]
        end
    end
    saved.splitWheelRepeatTiming = true
end

local function GetNavigationRepeatTime(timing)
    local value = EmotePanelSavedVars[timing.key]
    if type(value) ~= "number" or value ~= value then return timing.default end
    local rounded = math.floor(value / NAVIGATION_REPEAT_STEP + 0.5) * NAVIGATION_REPEAT_STEP
    return math.max(timing.min, math.min(timing.max, rounded))
end

local function IsWheelPopupVisible()
    return Widgets.GetConfirmation() ~= nil
end

local function CanToggleLegend()
    return EmotePanelSavedVars.showKeybindLegend == false and not Bindings.IsWheelOpener("PADBACK")
end

local function GetAvailableChatBox()
    local activeBox = ChatFrameUtil.GetActiveWindow()
    local editBox = ChatFrameUtil.ChooseBoxForSend()
    if not editBox then return end
    local draft = editBox:GetText()
    if (activeBox and activeBox:HasFocus()) or issecretvalue(draft) or draft ~= "" then
        Widgets.ShowError("Finish your current chat draft before using a command.")
        return
    end
    return editBox
end

local function CloseAfterAction()
    if not EmotePanel.combatView and EmotePanelSavedVars.closePanelAfterAction ~= false then EmotePanel.frame:Hide() end
end

local function FinishOrdinaryAction(sector)
    if not EmotePanel.combatView then EmotePanel:RememberAction(sector) end
    CloseAfterAction()
end

local function HasRaidMarkerTarget()
    if SecureCmdOptionParse("[@target,exists] 1; 0") == "1" then return true end
    Widgets.ShowError(ERR_GENERIC_NO_TARGET, LE_GAME_ERR_GENERIC_NO_TARGET)
end

local function ShowRaidMarkerCombatError()
    if HasRaidMarkerTarget() and InCombatLockdown() then
        Widgets.ShowError("Use the wheel keybind to mark a target in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
    end
end

local function ExecuteAction(mode, index, data, fromMouse, sector)
    if data.actionType == "submenu" then
        EmotePanel:ShowTargetMarkers()
    elseif data.actionType == "mount" then
        local _, _, _, active = C_MountJournal.GetMountInfoByID(data.actionID)
        FinishOrdinaryAction(sector)
        if not issecretvalue(active) and active then
            C_MountJournal.Dismiss()
        else
            C_MountJournal.SummonByID(data.actionID)
        end
    elseif data.actionType == "companion" then
        local id = Entries.GetCompanionID(data.actionID, data.profileSpecies)
        if not id then return end
        local summoned = C_PetJournal.IsCurrentlySummoned(id)
        if not issecretvalue(summoned) and summoned then
            FinishOrdinaryAction(sector)
            C_PetJournal.DismissSummonedPet(id)
        else
            local canSummon, _, reason = C_PetJournal.GetPetSummonInfo(id)
            if issecretvalue(canSummon) or not canSummon then
                Widgets.ShowError(not issecretvalue(reason) and reason or "That companion pet cannot be summoned here.")
                return
            end
            FinishOrdinaryAction(sector)
            C_PetJournal.SummonPetByGUID(id)
        end
    elseif data.actionType == "emote" then
        local text = Entries.GetCustomEmoteText(data.action)
        if text then
            if C_ChatInfo.InChatMessagingLockdown() then
                Widgets.ShowError("WoW could not send that custom emote.")
                return
            end
            C_ChatInfo.SendChatMessage(text, "EMOTE")
            FinishOrdinaryAction(sector)
            return
        end
        -- The native chat edit box treats a truthy return as a restriction.
        local restricted = C_ChatInfo.PerformEmote(Entries.GetEmoteToken(data))
        if EmotePanel.combatDebug then
            EmotePanel:CombatDebug("Emote", restricted and "rejected" or "accepted",
                "chat lockdown " .. tostring(C_ChatInfo.InChatMessagingLockdown()))
        end
        if restricted then
            Widgets.ShowError("WoW could not perform that emote.")
        else
            FinishOrdinaryAction(sector)
        end
    elseif data.actionType == "panel" then
        if data.secureClick then
            CloseAfterAction()
            Widgets.ShowError("Use WoW's Character Info keybind or the Character button in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
        else
            FinishOrdinaryAction(sector)
            data.open()
        end
    elseif data.actionType == "profession" then
        local canCraft = data.canCraft
        if fromMouse and canCraft then
            local current = C_TradeSkillUI.GetBaseProfessionInfo()
            if not current or current.professionID ~= index then
                -- Let TRADE_SKILL_SHOW open the native UI after the hardware click.
                if C_TradeSkillUI.OpenTradeSkill(index) then
                    FinishOrdinaryAction(sector)
                    return
                end
                canCraft = false
            end
        end
        if not ProfessionsFrame_LoadUI() then return end
        FinishOrdinaryAction(sector)
        if canCraft then
            local current = C_TradeSkillUI.GetBaseProfessionInfo()
            if current and current.professionID == index then
                OpenProfessionUIToSkillLine(index)
                return
            end
            if not fromMouse and C_TradeSkillUI.OpenTradeSkill(index) then return end
        end
        ProfessionsFrame:SelectBookPage()
        ShowUIPanel(ProfessionsFrame)
    elseif Entries.IsSecureWheelAction(data) then
        if InCombatLockdown() then
            Widgets.ShowError("Use the wheel keybind to use this action in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
        end
    elseif Entries.GetRaidMarker(mode, index, data) then
        ShowRaidMarkerCombatError()
    elseif data.actionType == "command" then
        local command = Entries.GetSlashCommand(mode, index, data)
        if not command then
            if not EmotePanel.combatView then EmotePanel:RememberAction(sector) end
            data.run()
            CloseAfterAction()
            return
        end
        local editBox = GetAvailableChatBox()
        if not editBox then return end
        FinishOrdinaryAction(sector)
        editBox:SetText(command)
        editBox:SendMessage()
    else
        local message = Entries.GetCustomMessage(mode, index) or data.action
        local channel = data.actionType == "say" and "SAY" or "PARTY"
        if channel == "PARTY" and not IsInGroup() then
            Widgets.ShowError("Join a group to send a party message.")
            return
        end
        C_ChatInfo.SendChatMessage(message, channel)
        FinishOrdinaryAction(sector)
    end
end

local function HideConsolePortCursor()
    local cursor = _G.ConsolePortCursor
    if not cursor or type(cursor.SetEnabled) ~= "function" or InCombatLockdown() then return end
    local shown = cursor:IsShown()
    if not issecretvalue(shown) and shown then
        cursor:SetEnabled(false)
        return cursor
    end
end

local function RestoreConsolePortCursor()
    if not EmotePanel.suspendedConsolePortCursor or InCombatLockdown() then return end
    -- Let ConsolePort finish processing the visibility or combat transition first.
    C_Timer.After(0, function()
        local cursor = EmotePanel.suspendedConsolePortCursor
        local settings = EmotePanel.settingsWindow
        if cursor and not InCombatLockdown() and not EmotePanel.frame:IsVisible() and not (settings and settings:IsVisible()) then
            EmotePanel.suspendedConsolePortCursor = nil
            cursor:SetEnabled(true)
        end
    end)
end

local function SetConsolePortCursorObstructed(frame, obstructed)
    local consolePort = _G.ConsolePort
    if consolePort and consolePort.SetCursorObstructor then
        consolePort:SetCursorObstructor(frame, obstructed)
    end
    if obstructed then
        -- ConsolePort's stack handler leaves its on-demand cursor active.
        EmotePanel.suspendedConsolePortCursor = HideConsolePortCursor() or EmotePanel.suspendedConsolePortCursor
    else
        RestoreConsolePortCursor()
    end
end

-- Sectors start at twelve o'clock and advance clockwise.
local function SectorAt(x, y)
    local index = math.floor(math.atan2(x, y) / Wheel.SECTOR_ANGLE + 0.5) % ns.SECTOR_COUNT + 1
    if index <= Pages.currentPage.count then return index end
end

function EmotePanel:RefreshPetAutocast(selection)
    Entries.ReadPetActions()
    self:RefreshWheel(selection)
end

local PING_INPUT_UNITS = {
    Accept = "target", WheelActivate = "target", LeftButton = "target",
    PingSelf = "player", MiddleButton = "player",
}
Input.PING_INPUT_UNITS = PING_INPUT_UNITS

function EmotePanel:ActivateSector(index, mouseButton, fromMouse)
    local mode, slot, data = Pages.GetSectorEntry(index)
    if not data or (data.available and not data.available()) then return end
    if mode == "pet" then return end -- Pet commands and autocast use secure clicks.
    if mode == "pings" then return end -- Pings use secure macro clicks.
    if mouseButton == "LeftButton" and InCombatLockdown() and Entries.IsOutOfCombat(mode, slot, data) then
        self:Select(index)
        Widgets.ShowError(data.name .. " is unavailable in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
        return
    end
    if mouseButton == "LeftButton" and data.unavailableReason then
        local reason = Entries.GetUnavailableReason(mode, slot, data)
        if reason then
            self:Select(index)
            Widgets.ShowError(reason)
            return
        end
    end
    if Pages.currentPage == Pages.categoryWheel then
        if mouseButton == "LeftButton" then
            if data.actionType == "submenu" then
                self:ShowTargetMarkers()
            else
                local first, empty = Pages.GetCategoryDestination(data)
                if first then
                    self:ShowPage(first, 1, true)
                else
                    self:DisplayPage(nil, empty, nil, true)
                end
            end
        elseif mouseButton == "RightButton" and not InCombatLockdown() then
            self:Select(index)
            self:EditButton(mode, slot, data)
        end
        return
    end
    if fromMouse and mouseButton == "LeftButton" and data.actionType == "profession" and data.canCraft then
        ExecuteAction(mode, slot, data, true, index)
        return
    end
    if mouseButton == "LeftButton" and mode ~= "targetMarkers" and data.actionType == "command" and (fromMouse or data.run == ReloadUI) then
        local command = Entries.GetSlashCommand(mode, slot, data)
        local verb = command and command:match("^%S+"):upper()
        local reload = SlashCmdList.RELOAD
        if (not command and data.run == ReloadUI) or (fromMouse and verb and
            (verb == "/RELOAD" or (reload and hash_SlashCmdList and hash_SlashCmdList[verb] == reload))) then
            if GetAvailableChatBox() then
                -- Request reload before changing focus or updating the wheel.
                ReloadUI()
                CloseAfterAction()
            end
            return
        end
    end
    self:Select(index)
    if mouseButton == "MiddleButton" then
        self:ToggleFavorite()
    elseif mouseButton == "RightButton" and mode ~= "targetMarkers" and not data.automatic then
        self:EditButton(mode, slot, data)
    elseif mouseButton == "LeftButton" then
        ExecuteAction(mode, slot, data, nil, index)
    end
end

function EmotePanel:CanUseWheel()
    return not ((self.customMessageDialog and self.customMessageDialog:IsShown())
        or IsWheelPopupVisible())
end

function EmotePanel:UpdateSecureWheelInput()
    if InCombatLockdown() then return end
    local button = self.secureWheelInput
    if self.frame:IsShown() and self:CanUseWheel() then
        for sector = 1, Pages.currentPage.count do
            local mode, key, data = Pages.GetSectorEntry(sector)
            if data and (Entries.NeedsSecureInput(data) or Entries.GetRaidMarker(mode, key, data)) then
                local x, y = self.wheel:GetCenter()
                if not x then break end
                button = button or self:CreateSecureWheelInput()
                local pet = Pages.currentPage.mode == "pet"
                local markers = Pages.currentPage.mode == "targetMarkers"
                local pings = Pages.currentPage.mode == "pings"
                if button:GetAttribute("pet-wheel") ~= pet or button:GetAttribute("target-markers") ~= markers
                    or button:GetAttribute("ping-wheel") ~= pings then
                    button:Hide()
                    button:SetAttribute("pet-wheel", pet)
                    button:SetAttribute("target-markers", markers)
                    button:SetAttribute("ping-wheel", pings)
                end
                button:SetScale(self.wheel:GetEffectiveScale() / UIParent:GetEffectiveScale())
                button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
                button:SetFrameLevel(self.wheel:GetFrameLevel() + 2)
                button:Show()
                return
            end
        end
    end
    if button then button:Hide() end
end

local function GetCategoryAt(page, sector)
    if page == Pages.categoryWheel then return page.entries[sector] end
end

local function IsSameActivation(page, sector, category)
    -- A refresh may replace Categories while the same entry remains under the press.
    if category then return GetCategoryAt(Pages.currentPage, sector) == category end
    return page == Pages.currentPage
end

function EmotePanel:SetupWheelMouse(wheel, innerRadius, outerRadius)
    local function SectorUnderCursor(mouseButton, cursorX, cursorY)
        local centerX, centerY = wheel:GetCenter()
        local scale = wheel:GetEffectiveScale()
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        local distanceSquared = x * x + y * y
        if mouseButton == "LeftButton" and Pages.currentPage.mode == "targetMarkers"
            and distanceSquared <= Wheel.CLEAR_MARK_RADIUS ^ 2 then
            return "ClearMark"
        end
        if distanceSquared < innerRadius ^ 2 then
            if mouseButton == "RightButton" then return 0 end
        elseif distanceSquared <= outerRadius ^ 2 then
            return SectorAt(x, y)
        end
    end

    local lastX, lastY, mouseDownButton, mouseDownSector, mouseDownPage, mouseDownCategory
    local function UpdateMouseSelection()
        if not self.frame:IsShown() or not self:CanUseWheel() then return end
        local x, y = GetCursorPosition()
        if x == lastX and y == lastY then return end
        lastX, lastY = x, y
        local hit = SectorUnderCursor("LeftButton", x, y)
        local index = type(hit) == "number" and hit or nil
        self:SetClearMarkHovered(hit == "ClearMark")
        if mouseDownButton and self.wheelPressInput == mouseDownButton and index ~= mouseDownSector then
            self:SetWheelPressed(nil, mouseDownButton)
        end
        if index and not self.combatView then self:Select(index, nil, SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT) end
        if hit ~= "ClearMark" then self:ShowWheelEntryTooltip(index, true) end
    end
    local function StopMouseSelection()
        if mouseDownButton then self:SetWheelPressed(nil, mouseDownButton) end
        wheel:SetScript("OnUpdate", nil)
        lastX, lastY = nil, nil
        self:SetClearMarkHovered(false)
        mouseDownButton, mouseDownSector, mouseDownPage, mouseDownCategory = nil, nil, nil, nil
        if self.wheelTooltipFromMouse then self.wheelTooltip:Hide() end
    end
    local function StartMouseSelection()
        wheel:SetScript("OnUpdate", UpdateMouseSelection)
        UpdateMouseSelection()
    end
    self.StartWheelMouseTooltip = StartMouseSelection
    self.StopWheelMouseTooltip = StopMouseSelection
    local function MouseDown(_, mouseButton)
        if (mouseButton == "LeftButton" or mouseButton == "RightButton" or mouseButton == "MiddleButton")
            and self:CanUseWheel() then
            mouseDownButton = mouseButton
            mouseDownSector = SectorUnderCursor(mouseButton, GetCursorPosition())
            mouseDownPage = Pages.currentPage
            mouseDownCategory = GetCategoryAt(mouseDownPage, mouseDownSector)
            if mouseButton == "LeftButton" or (mouseButton == "MiddleButton" and Pages.currentPage.mode == "pings")
                or (mouseButton == "RightButton" and Pages.currentPage.mode == "pet") then
                self:SetWheelPressed(type(mouseDownSector) == "number" and mouseDownSector or nil, mouseButton)
            end
        end
    end
    local function TakeMouseClick(mouseButton)
        if mouseButton ~= mouseDownButton then return end
        self:SetWheelPressed(nil, mouseButton)
        local pressedSector, pressedPage, pressedCategory = mouseDownSector, mouseDownPage, mouseDownCategory
        mouseDownButton, mouseDownSector, mouseDownPage, mouseDownCategory = nil, nil, nil, nil
        if not pressedSector or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(mouseButton, GetCursorPosition())
        if index == pressedSector and IsSameActivation(pressedPage, index, pressedCategory) then return index end
    end
    local function FinishClick(index, mouseButton, fromMouse)
        if not index then return end
        if index == "ClearMark" then
            if InCombatLockdown() then
                Widgets.ShowError("Use the wheel keybind to clear a mark in combat.", LE_GAME_ERR_AFFECTING_COMBAT)
            end
        elseif index == 0 then
            self:BackOrClose()
        else
            self:ActivateSector(index, mouseButton, fromMouse)
        end
        self.wheelTooltip:Hide()
    end
    local function SetMouseScripts(button)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(_, delta)
            if delta == 0 or not self:CanUseWheel() then return end
            local nextPage, previousPage = Pages.GetScrollPages(Pages.currentPageIndex, Pages.currentPage, Pages.IsCategoryWheelEnabled())
            local destination = delta > 0 and nextPage or delta < 0 and previousPage
            if destination == 0 then
                self:ShowStartPage(nil, true)
            elseif destination then
                self:ShowPage(destination, 1, true)
            end
        end)
        button:SetScript("OnEnter", StartMouseSelection)
        button:SetScript("OnLeave", StopMouseSelection)
        button:HookScript("OnHide", StopMouseSelection)
        button:SetScript("OnMouseDown", MouseDown)
        button:SetScript("OnMouseUp", function(_, mouseButton)
            -- The secure proxy handles self pings and pet autocast clicks.
            if mouseButton ~= "LeftButton"
                and (button == wheel or not ((mouseButton == "MiddleButton" and Pages.currentPage.mode == "pings")
                    or (mouseButton == "RightButton" and Pages.currentPage.mode == "pet"))) then
                FinishClick(TakeMouseClick(mouseButton), mouseButton, true)
            end
        end)
    end
    SetMouseScripts(wheel)
    -- Left-click commands need the button's hardware click context.
    wheel:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then FinishClick(TakeMouseClick(mouseButton), mouseButton, true) end
    end)

    function self:CreateSecureWheelInput()
        -- Keep the secure input separate from the wheel so normal pages still work in combat.
        local button = CreateFrame("Button", AddonName .. "SecureWheelInput", UIParent,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate,SecureHandlerShowHideTemplate")
        button:Hide()
        button:SetAttribute("nodeignore", true)
        button:SetSize(Wheel.WHEEL_SIZE, Wheel.WHEEL_SIZE)
        button:SetFrameStrata("DIALOG")
        button:EnableMouse(true)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("_onshow", [[
            self:SetBindingClick(true, "PAD1", self:GetName(), "WheelActivate")
            if self:GetAttribute("pet-wheel") then
                self:SetBindingClick(true, "PAD3", self:GetName(), "WheelAutocast")
            elseif self:GetAttribute("target-markers") then
                self:SetBindingClick(true, "PAD3", self:GetName(), "ClearMark")
                self:SetBindingClick(true, "PAD4", self:GetName(), "MarkSelf")
            elseif self:GetAttribute("ping-wheel") then
                self:SetBindingClick(true, "PAD4", self:GetName(), "PingSelf")
            end
        ]])
        button:SetAttribute("_onhide", [[ self:ClearBindings() ]])
        button:SetAttribute("_onstate-combat", [[ if newstate == "combat" then self:Hide() end ]])
        RegisterStateDriver(button, "combat", "[combat] combat; peace")
        SetMouseScripts(button)
        local function ClearAction()
            button:SetAttribute("type", nil)
            button:SetAttribute("macro", nil)
            button:SetAttribute("macrotext", nil)
            button:SetAttribute("spell", nil)
            button:SetAttribute("item", nil)
            button:SetAttribute("toy", nil)
            button:SetAttribute("action", nil)
            button:SetAttribute("marker", nil)
            button:SetAttribute("unit", nil)
            button:SetAttribute("clickbutton", nil)
        end
        local function SetRaidMarkerAction(marker, unit)
            button:SetAttribute("type", "raidtarget")
            button:SetAttribute("action", marker == 0 and "clear" or "set")
            button:SetAttribute("marker", marker)
            button:SetAttribute("unit", unit)
        end
        local function ClearMarker()
            SetRaidMarkerAction(0, SecureCmdOptionParse("[@target,exists] target; player"))
        end
        local clickedSector, ranSecureAction, ranAutocast, controllerPage, autocastPage, clearPage, selfMarkPage
        local pingPage, pingInput
        button:HookScript("OnHide", function()
            controllerPage, autocastPage, clearPage, selfMarkPage = nil, nil, nil, nil
            pingPage, pingInput = nil, nil
        end)
        button:SetScript("PreClick", function(_, input, down)
            clickedSector, ranSecureAction, ranAutocast = nil, false, false
            if InCombatLockdown() then return end
            ClearAction()
            local isPing = Pages.currentPage.mode == "pings"
            local pingUnit = isPing and PING_INPUT_UNITS[input]
            local pingGamepad = isPing and (input == "WheelActivate" or input == "PingSelf")
            if down then
                if pingGamepad then
                    if not IsModifierKeyDown() then
                        pingPage, pingInput = Pages.currentPage, input
                        self:SetWheelPressed(self.selected, input)
                    end
                    return
                end
                if input == "WheelActivate" then controllerPage = Pages.currentPage end
                if input == "WheelAutocast" then autocastPage = Pages.currentPage end
                if input == "ClearMark" then clearPage = Pages.currentPage end
                if input == "MarkSelf" then selfMarkPage = Pages.currentPage end
                local pad = input == "WheelActivate" and "PAD1" or input == "WheelAutocast" and "PAD3"
                if not IsModifierKeyDown() and (input == "MarkSelf" or
                    (pad and GetBindingFromClick(pad) ~= "TOGGLEGAMEMENU")) then
                    self:SetWheelPressed(self.selected, input)
                end
                return
            end
            self:SetWheelPressed(nil, input)
            if pingUnit then
                if pingGamepad then
                    local matches = pingPage == Pages.currentPage and pingInput == input
                    pingPage, pingInput = nil, nil
                    self.gamepadInput:SetPropagateKeyboardInput(false)
                    if not matches or IsModifierKeyDown() then return end
                    if input == "WheelActivate" and GetBindingFromClick("PAD1") == "TOGGLEGAMEMENU" then
                        self.frame:Hide()
                        return
                    end
                    clickedSector = self.selected
                else
                    clickedSector = TakeMouseClick(input)
                end
                local _, _, data = Pages.GetSectorEntry(clickedSector)
                if not (data and self.frame:IsShown() and self:CanUseWheel()) then return end
                local command = Entries.GetPingCommand()
                local condition = "[@" .. pingUnit .. ",exists]"
                if not command then return end
                if SecureCmdOptionParse(condition .. " 1; 0") ~= "1" then
                    Widgets.ShowError(ERR_GENERIC_NO_TARGET)
                    return
                end
                button:SetAttribute("type", "macro")
                button:SetAttribute("macrotext", command .. " " .. condition .. " " .. data.actionID)
                ranSecureAction = true
                return
            end
            local pressedPage, pressedAutocastPage = controllerPage, autocastPage
            if input == "WheelActivate" then
                controllerPage = nil
                -- The binding has received the release. Resume capturing ordinary input.
                self.gamepadInput:SetPropagateKeyboardInput(false)
            elseif input == "WheelAutocast" then
                autocastPage = nil
                self.gamepadInput:SetPropagateKeyboardInput(false)
            elseif input == "ClearMark" then
                local pressedPage = clearPage
                clearPage = nil
                self.gamepadInput:SetPropagateKeyboardInput(false)
                if self.frame:IsShown() and self:CanUseWheel() and pressedPage == Pages.currentPage
                    and pressedPage.mode == "targetMarkers" and not IsModifierKeyDown() then
                    ClearMarker()
                    ranSecureAction = true
                end
                return
            end
            local markSelf = input == "MarkSelf"
            if markSelf then
                local pressedPage = selfMarkPage
                selfMarkPage = nil
                self.gamepadInput:SetPropagateKeyboardInput(false)
                if pressedPage ~= Pages.currentPage or pressedPage.mode ~= "targetMarkers" or IsModifierKeyDown() then return end
            end
            if not (self.frame:IsShown() and self:CanUseWheel()) then return end
            local toggleAutocast = Pages.currentPage.mode == "pet" and (input == "RightButton" or input == "WheelAutocast")
            if input == "LeftButton" or (toggleAutocast and input == "RightButton") then
                clickedSector = TakeMouseClick(input)
                if clickedSector == "ClearMark" then
                    clickedSector = nil
                    ClearMarker()
                    ranSecureAction = true
                    return
                end
            elseif markSelf then
                clickedSector = self.selected
            elseif toggleAutocast and pressedAutocastPage == Pages.currentPage and not IsModifierKeyDown() then
                clickedSector = self.selected
            elseif input == "WheelActivate" and pressedPage == Pages.currentPage
                and not IsModifierKeyDown() then
                if GetBindingFromClick("PAD1") == "TOGGLEGAMEMENU" then
                    self.frame:Hide()
                    return
                end
                clickedSector = self.selected
            end
            local mode, key, data = Pages.GetSectorEntry(clickedSector)
            if not data then return end
            if toggleAutocast then
                Entries.ReadPetActions()
                local current = Entries.GetPetAction(data.actionID)
                local macro = current and current.key == data.key and CombatWheel.GetPetAutocastMacro(current)
                if macro then
                    button:SetAttribute("type", "macro")
                    button:SetAttribute("macrotext", macro)
                    ranAutocast = true
                end
                return
            end
            local target = data.secureClick and _G[data.secureClick]
            local marker = Entries.GetRaidMarker(mode, key, data)
            if target then
                button:SetAttribute("type", "click")
                button:SetAttribute("clickbutton", target)
                ranSecureAction = true
            elseif marker and (markSelf or SecureCmdOptionParse("[@target,exists] 1; 0") == "1") then
                SetRaidMarkerAction(marker, markSelf and "player" or "target")
                ranSecureAction = true
            elseif data.actionType == "macro" and GetMacroInfo(data.macroIndex) == data.name then
                button:SetAttribute("type", "macro")
                button:SetAttribute("macro", data.macroIndex)
                ranSecureAction = true
            elseif data.actionType == "spell" then
                button:SetAttribute("type", "spell")
                button:SetAttribute("spell", data.actionID)
                ranSecureAction = true
            elseif data.actionType == "item" then
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. data.actionID)
                ranSecureAction = true
            elseif data.actionType == "toy" then
                button:SetAttribute("type", "toy")
                button:SetAttribute("toy", data.actionID)
                ranSecureAction = true
            elseif data.actionType == "pet" or (data.actionType == "action" and Entries.HasExtraAction()) then
                button:SetAttribute("type", data.actionType)
                button:SetAttribute("action", data.actionID)
                ranSecureAction = true
            end
        end)
        button:HookScript("PostClick", function(_, input)
            if not InCombatLockdown() then ClearAction() end
            if ranAutocast then
                self:RefreshPetAutocast(clickedSector)
                self.wheelTooltip:Hide()
            elseif ranSecureAction then
                if clickedSector then
                    self:RememberAction(clickedSector)
                    self:Select(clickedSector)
                end
                self.wheelTooltip:Hide()
                CloseAfterAction()
            else
                FinishClick(clickedSector, "LeftButton", input == "LeftButton")
            end
        end)
        self.secureWheelInput = button
        return button
    end
end

function EmotePanel:SetupGamepad()
    local frame = self.frame
    local input = CreateFrame("Frame", nil, frame)
    input:SetAllPoints(frame)
    self.gamepadInput = input
    local function CloseForGameMenu()
        if self.customMessageDialog then self.customMessageDialog:Hide() end
        frame:Hide()
    end
    local function PreviousPage() self:CycleMode(-1) end
    local function NextPage() self:CycleMode(1) end
    local function ToggleLegend() self:ToggleWheelLegend() end
    local function RemoveAction()
        local key, data = self:GetRemovableWheelAction()
        if key then self:SetActionSelected(key, data, false, true) end
    end
    local function StepSegment(direction)
        if not self.selected then return end
        local sector = self.selected + direction
        if EmotePanelSavedVars.stopAtSegmentEnds and (sector < 1 or sector > Pages.currentPage.count) then return end
        self:Select(sector, true, SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER, true)
    end
    local navigationActions = {
        PADDUP = function() StepSegment(-1) end,
        PADDDOWN = function() StepSegment(1) end,
        PADDLEFT = PreviousPage,
        PADDRIGHT = NextPage,
        PADLSHOULDER = PreviousPage,
        PADRSHOULDER = NextPage,
    }
    local actions = {
        PAD1 = function() self:ActivateSector(self.selected, "LeftButton") end,
        PAD2 = function() self:BackOrClose() end,
        PAD3 = function() self:ToggleFavorite() end,
        PAD4 = function() self:ActivateSector(self.selected, "RightButton") end,
    }
    local editorActions = {
        PAD1 = function() self.customMessageDialog.saveButton:Click() end,
        PAD2 = function() self.customMessageDialog.cancelButton:Click() end,
        PAD4 = function() self.customMessageDialog.iconButton:Click() end,
    }
    local placementActions = {
        PAD3 = function()
            local show = self.customMessageDialog.placement.show
            show:SetChecked(not show:GetChecked())
            show:GetScript("OnClick")(show)
        end,
        PADDUP = function() self.customMessageDialog.placement.activeRow.up:Click() end,
        PADDDOWN = function() self.customMessageDialog.placement.activeRow.down:Click() end,
    }
    local function SelectCategoryRow() self.customMessageDialog.placement:SelectMoveRow(-1) end
    local function SelectFavoritesRow() self.customMessageDialog.placement:SelectMoveRow(1) end
    local function ResetEntry() self.customMessageDialog.resetButton:Click() end
    local function DeleteEntry() self.customMessageDialog.deleteButton:Click() end
    local function ToggleEditorFavorite() self.customMessageDialog.placement.favoriteButton:Click() end
    local function PageIconPicker(direction, pages)
        return self.customMessageDialog.picker:ChangePage(direction * (pages or 1))
    end
    local function PreviousIconPage(pages) return PageIconPicker(-1, pages) end
    local function NextIconPage(pages) return PageIconPicker(1, pages) end
    local pickerActions = {
        PADDUP = function() self.customMessageDialog.picker:MoveSelection(-8) end,
        PADDDOWN = function() self.customMessageDialog.picker:MoveSelection(8) end,
        PADDLEFT = function() self.customMessageDialog.picker:MoveSelection(-1) end,
        PADDRIGHT = function() self.customMessageDialog.picker:MoveSelection(1) end,
        PADLSHOULDER = PreviousIconPage,
        PADRSHOULDER = NextIconPage,
        PAD1 = function() self.customMessageDialog.picker:ChooseSelected() end,
        PAD2 = function() self.customMessageDialog.picker:Hide() end,
        PAD4 = function() self.customMessageDialog.picker:ToggleLibrary() end,
        PADRSTICK = function() self.customMessageDialog.picker:ResetIcon() end,
    }
    local function GetAction(key)
        if key == "PADBACK" then
            if Bindings.IsWheelOpener(key) then return end
            if self:CanUseWheel() and not IsModifierKeyDown() then
                if CanToggleLegend() and not InCombatLockdown() then return ToggleLegend end
                if self:GetRemovableWheelAction() then return RemoveAction end
            end
        end
        if key == "PADFORWARD" or GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
            return CloseForGameMenu
        end
        local dialog = self.customMessageDialog
        local editing = dialog and dialog:IsShown()
        if IsWheelPopupVisible() then return end
        if editing then
            if dialog.picker and dialog.picker:IsShown() then return pickerActions[key] end
            if dialog.nameBox:HasFocus() or dialog.messageBox:HasFocus() then return end
            if key == "PADLSHOULDER" and dialog.resetButton:IsShown() then return ResetEntry end
            if key == "PADLSHOULDER" and dialog.deleteButton:IsShown() then return DeleteEntry end
            if key == "PADRSHOULDER" and dialog.placement:IsShown()
                and dialog.placement.favoriteButton:IsShown() then return ToggleEditorFavorite end
            if dialog.placement:IsShown() and dialog.placement.favoritesRow:IsShown() then
                if key == "PADDLEFT" then return SelectCategoryRow end
                if key == "PADDRIGHT" then return SelectFavoritesRow end
            end
            return editorActions[key] or (dialog.placement:IsShown() and placementActions[key])
        end
        if key ~= "PAD4" or (self.selected and Pages.currentPage.mode ~= "pet") then
            return navigationActions[key] or actions[key]
        end
    end
    local function RunAction(action, pages)
        self.wheelTooltip:Hide()
        return action(pages)
    end
    local function BindGamepadButtons(target, visibilityOwner)
        local pressed = {}
        local activationPage, activationSector, activationCategory
        local removalPage, removalSector
        local repeatKey, repeatRemaining, repeatTiming, repeatAction
        local iconJumpHeld
        local function PropagateButton(propagate)
            if not InCombatLockdown() then target:SetPropagateKeyboardInput(propagate) end
            return propagate
        end
        local function UseSecureBinding(key)
            local mode = Pages.currentPage.mode
            return (key == "PAD1" or (key == "PAD3" and mode == "pet")
                or ((key == "PAD3" or key == "PAD4") and mode == "targetMarkers")
                or (key == "PAD4" and mode == "pings"))
                and self.secureWheelInput and self.secureWheelInput:IsShown()
        end
        target:SetScript("OnGamePadButtonDown", function(_, key)
            -- A navigation key handled on press must not step again on release.
            if pressed[key] == false then return PropagateButton(false) end
            repeatKey = nil
            if UseSecureBinding(key) then return PropagateButton(true) end
            local action = GetAction(key)
            if not action and key == "PAD3" and target == self.customMessageDialog
                and target.picker and target.picker:IsShown() and not IsWheelPopupVisible()
                and not IsModifierKeyDown() and not InCombatLockdown() then
                pressed[key], iconJumpHeld = false, true
                return PropagateButton(false)
            end
            if not action or (action ~= CloseForGameMenu and IsModifierKeyDown()) then return PropagateButton(true) end
            local timing
            local iconPaging = action == PreviousIconPage or action == NextIconPage
            if target == input and action == navigationActions[key] then
                timing = (action == PreviousPage or action == NextPage) and pagingRepeatTiming or navigationRepeatTiming
            elseif iconPaging then
                timing = pagingRepeatTiming
            end
            if timing and not self.combatView and not InCombatLockdown() then
                pressed[key] = false
                PropagateButton(false)
                local jump = iconPaging and iconJumpHeld
                local advanced = RunAction(action, jump and 10 or nil)
                if not jump and advanced ~= false and EmotePanelSavedVars[timing.enabledKey] ~= false then
                    repeatKey, repeatAction, repeatTiming = key, action, timing
                    repeatRemaining = GetNavigationRepeatTime(timing.delay) / 1000
                end
                return false
            end
            pressed[key] = action
            if action == actions.PAD1 then
                activationPage, activationSector = Pages.currentPage, self.selected
                activationCategory = GetCategoryAt(activationPage, activationSector)
                if activationCategory then self:CombatDebug("Input", "A/Cross pressed", activationCategory) end
                self:SetWheelPressed(activationSector, key)
            elseif action == RemoveAction then
                removalPage, removalSector = Pages.currentPage, self.selected
            end
            return PropagateButton(false)
        end)
        target:SetScript("OnGamePadButtonUp", function(_, key)
            self:SetWheelPressed(nil, key)
            local action = pressed[key]
            pressed[key] = nil
            if key == "PAD3" then iconJumpHeld = nil end
            if repeatKey == key then repeatKey = nil end
            if action == false then return PropagateButton(false) end
            if UseSecureBinding(key) or not action then return PropagateButton(true) end
            PropagateButton(false)
            if action == actions.PAD1 then
                if not IsSameActivation(activationPage, activationSector, activationCategory) then
                    self:CombatDebug("Input", "A/Cross canceled", "entry changed")
                    return false
                end
                if activationCategory and action == GetAction(key) then
                    -- A rebuilt Categories page may reset selection while the button is held.
                    local sector = activationSector
                    if activationPage == Pages.currentPage then sector = self.selected end
                    self:CombatDebug("Input", "A/Cross opening category", GetCategoryAt(Pages.currentPage, sector))
                    self:ActivateSector(sector, "LeftButton")
                    return false
                end
            end
            if action == RemoveAction and (removalPage ~= Pages.currentPage or removalSector ~= self.selected
                or IsModifierKeyDown()) then return false end
            if action == GetAction(key) then
                RunAction(action)
            end
            return false
        end)
        local owner = visibilityOwner or target
        local function CancelNavigationRepeat()
            repeatKey, iconJumpHeld = nil, nil
        end
        local function ClearButtons()
            CancelNavigationRepeat()
            activationPage, activationSector, activationCategory = nil, nil, nil
            wipe(pressed)
        end
        owner:HookScript("OnHide", ClearButtons)
        if target == input then
            target:HookScript("OnHide", ClearButtons)
        end
        target:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
        target:SetScript("OnEvent", function(_, _, isActive)
            -- The first gamepad input can make the device active mid-press.
            if activationCategory then
                self:CombatDebug("Input", "Gamepad active " .. tostring(isActive), activationCategory)
            end
            if not isActive then
                self:SetWheelPressed(nil, "PAD1")
                self:SetWheelPressed(nil, "WheelActivate")
                ClearButtons()
            end
        end)
        target.CancelNavigationRepeat = CancelNavigationRepeat
        target:SetScript("OnUpdate", function(_, elapsed)
            if not repeatKey then return end
            if EmotePanelSavedVars[repeatTiming.enabledKey] == false or self.combatView or InCombatLockdown()
                or IsModifierKeyDown() or GetAction(repeatKey) ~= repeatAction then
                repeatKey = nil
                return
            end
            repeatRemaining = repeatRemaining - elapsed
            if repeatRemaining <= 0 then
                -- Check the physical button in case focus changed before its release arrived.
                local index = C_GamePad.ButtonBindingToIndex(repeatKey)
                local state = C_GamePad.GetDeviceMappedState()
                local held = index and state and state.buttons and state.buttons[index + 1]
                if held ~= true then
                    pressed[repeatKey], repeatKey = nil, nil
                    return
                end
                repeatRemaining = GetNavigationRepeatTime(repeatTiming.interval) / 1000
                if RunAction(repeatAction) == false then repeatKey = nil end
            end
        end)
        target:EnableGamePadButton(true)
    end
    self.bindGamepadButtons = BindGamepadButtons
    BindGamepadButtons(input, frame)
    self:CreateWheelMovementGuard()
    self.gamepadReady = true
end

function EmotePanel:AimWheel(x, y)
    if x * x + y * y >= 0.25 then
        local index = SectorAt(x, y)
        if index then self:Select(index, true, SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT, true) end
    end
end

function EmotePanel:ToggleWheel(pet)
    local frame = self.frame
    pet = pet == true
    if not frame or self.combatView or (GameMenuFrame and GameMenuFrame:IsShown())
        or (pet and (not self.supportsPetWheel or InCombatLockdown())) then return end
    if pet and not (frame:IsShown() and Pages.currentPage.mode == "pet") then
        if not Entries.HasSummonedPet() then
            Widgets.ShowError("No pet summoned")
            return
        end
        local dead = UnitIsDead("pet")
        if not issecretvalue(dead) and dead then
            Widgets.ShowError("Pet is dead")
            return
        end
    end
    if self.settingsWindow and self.settingsWindow:IsShown() then self.settingsWindow:Hide() end
    if frame:IsShown() then
        local sameWheel = (Pages.currentPage.mode == "pet") == pet
        frame:Hide()
        if sameWheel then return end
    end
    if InCombatLockdown() and self.combatBindingReady and self.gamepadInput then
        self.gamepadInput:Hide()
    end
    self.openingPetWheel = pet
    frame:Show()
    self.openingPetWheel = nil
end

local STICKS = { Movement = true, Left = true, Camera = true, Right = true }

local function MovementStickHeld(index)
    local state = C_GamePad.GetDeviceMappedState()
    local stick = state and state.sticks and state.sticks[index]
    return stick and (stick.x ~= 0 or stick.y ~= 0)
end

local function GetHeldMovementStick()
    local index, leftIndex = 0
    local name = C_GamePad.StickIndexToConfigName(index)
    while name and name ~= "Movement" do
        if name == "Left" then leftIndex = index + 1 end
        index = index + 1
        name = C_GamePad.StickIndexToConfigName(index)
    end
    local movementIndex = name and index + 1 or leftIndex
    if movementIndex and MovementStickHeld(movementIndex) then
        return movementIndex, name or "Left"
    end
end

function EmotePanel:CreateWheelMovementGuard()
    -- Button handlers change their propagation to reach WoW bindings. This frame handles only sticks.
    local guard = CreateFrame("Frame", nil, UIParent)
    guard:Hide()
    guard:SetAttribute("nodeignore", true)
    guard:SetFrameStrata("TOOLTIP")
    guard:SetPropagateKeyboardInput(false)
    guard:EnableGamePadStick(true)
    guard:SetScript("OnGamePadStick", function(frame, stick, x, y)
        local movement = stick == "Movement" or stick == "Left"
        local lockMovement = EmotePanelSavedVars.lockMovementStick ~= false
        local neutral = x == 0 and y == 0
        if frame.wheelOpen then
            if not STICKS[stick] then return true end
            if movement and neutral then return true end
            if IsModifierKeyDown() or not self:CanUseWheel() then return not (movement and lockMovement) end
            if not self.combatView and self.gamepadInput:IsShown() then self:AimWheel(x, y) end
            return movement and not lockMovement
        end
        if not movement or not lockMovement then return true end
        if not neutral then return false end
        if stick == frame.movementStick then frame:Hide() end
        return true
    end)
    guard:SetScript("OnUpdate", function(frame)
        if not frame.wheelOpen and (EmotePanelSavedVars.lockMovementStick == false
            or not MovementStickHeld(frame.movementIndex)) then frame:Hide() end
    end)
    self.wheelMovementGuard = guard
    self:SetWheelMovementCapture(self.frame:IsShown())
end

function EmotePanel:SetWheelMovementCapture(open)
    local guard = self.wheelMovementGuard
    if not guard then return end
    guard.wheelOpen = open
    if open then
        guard:Show()
    elseif EmotePanelSavedVars.lockMovementStick ~= false then
        guard.movementIndex, guard.movementStick = GetHeldMovementStick()
        guard:SetShown(guard.movementIndex ~= nil)
    else
        guard:Hide()
    end
end

local function HandleCombatTransition(event)
    EmotePanel:SetWheelPressed(nil)
    if event == "PLAYER_REGEN_ENABLED" then
        if not EmotePanel.gamepadReady then EmotePanel:SetupGamepad() end
        EmotePanel:SetupEditorGamepad()
        if not EmotePanel:ResumeCombatWheel() then
            if EmotePanel.supportsPetWheel then
                Entries.ReadPetActions()
                Pages.BuildPetPages()
            end
            EmotePanel:LoadPosition()
        end
        RestoreConsolePortCursor()
    else
        if EmotePanel.gamepadInput then EmotePanel.gamepadInput.CancelNavigationRepeat() end
        local dialog = EmotePanel.customMessageDialog
        if dialog and dialog.CancelNavigationRepeat then dialog.CancelNavigationRepeat() end
        EmotePanel.optionsPanel:CancelWheelBindingCapture()
        if (EmotePanel.combatBindingReady or Pages.currentPage.mode == "pet") and not EmotePanel.combatView then
            EmotePanel.frame:StopMovingOrSizing()
            EmotePanel.frame:Hide()
        end
    end
    if EmotePanel.frame:IsShown() then
        if Pages.currentPage.category == "interactions" or Pages.currentPage.mode == "favorites" then
            EmotePanel:RefreshWheel()
        end
        EmotePanel:RefreshCombatAppearance()
        EmotePanel:RefreshActionCooldowns()
        EmotePanel:RefreshActionAvailability()
        EmotePanel:RefreshGamepadHint()
    end
end

Input.GetHeldMovementStick = GetHeldMovementStick
Input.CanToggleLegend = CanToggleLegend
Input.GetNavigationRepeatTime = GetNavigationRepeatTime
Input.navigationRepeatTiming = navigationRepeatTiming
Input.pagingRepeatTiming = pagingRepeatTiming
Input.InitializeRepeatTiming = InitializeRepeatTiming
Input.NAVIGATION_REPEAT_STEP = NAVIGATION_REPEAT_STEP
Input.HideConsolePortCursor = HideConsolePortCursor
Input.STICKS = STICKS
Input.SetConsolePortCursorObstructed = SetConsolePortCursorObstructed
Input.HandleCombatTransition = HandleCombatTransition
