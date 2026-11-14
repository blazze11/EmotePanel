local AddonName, ns = ...
local EmotePanel = ns.panel

local Widgets = ns.Widgets
local PlayWheelSound = Widgets.PlayWheelSound
local Entries = ns.Entries
local Pages = ns.Pages
local Wheel = ns.Wheel
local Input = ns.Input
local CombatWheel = ns.CombatWheel

local RANGE_CHECK_INTERVAL = 0.2
local FADE_IN_DURATION = 0.16
local FADE_OUT_DURATION = 0.12
local PAGE_TRANSITION_DURATION = 0.09
local TEXT_SHADOW_ALPHA = 0.65
local PREVIEW_ROW_HEIGHT = 18
local TITLE_Y = -31
local PANEL_WIDTH, PANEL_HEIGHT = 432, 652
local WHEEL_SIZE = 382
local WHEEL_TOP_OFFSET = 54
local ICON_SLOT_SIZE = 46
local SECTOR_ANGLE = 2 * math.pi / ns.SECTOR_COUNT
local WHEEL_ATLAS = "gamepad-radial-menu-wheelbg"
local SELECTION_ATLAS = "gamepad-radial-menu-selected"
local ICON_BORDER = "gamepad-actionbar-circleslot-border-normal"
local SELECTED_ICON_BORDER = "gamepad-actionbar-circleslot-border-selected"
local SELECTION_CHAT_TYPES = { emote = "TEXT_EMOTE", say = "SAY", party = "PARTY" }
local SELECTION_COLORS = {
    emote = { 1, 0.5, 0.25 },
    say = { 1, 1, 1 },
    party = { 0.67, 0.67, 1 },
    command = { 0.82, 0.54, 1 },
    submenu = { 1, 0.35, 0.36 },
    favorites = { 1, 0.83, 0.33 },
    voicedEmotes = { 1, 0.55, 0.73 },
    interactions = { 0.53, 0.8, 0.28 },
    spell = { 0.39, 0.72, 1 },
    item = { 0.38, 0.95, 0.57 },
    macro = { 0.95, 0.53, 0.9 },
    action = { 0.88, 0.9, 0.38 },
    panel = { 0.42, 0.95, 0.83 },
    profession = { 1, 0.61, 0.32 },
    pet = { 0.9, 0.55, 1 },
}
local COMBAT_DISABLED_COLOR = { 0.55, 0.55, 0.55 }
local PET_AUTOCAST_SELECTION_ON = { 1, 0.76, 0.35 }
local PET_AUTOCAST_SELECTION_OFF = { 0.44, 0.71, 1 }
local PET_ACTIVE_GLOW = { 0.67, 0.94, 0.4, 0.9 }
local PET_AUTOCAST_GLOW = { 1, 0.76, 0.35, 0.85 }
local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
local ANCHOR_OFFSETS = {
    TOPLEFT = {-0.5, 0.5}, TOP = {0, 0.5}, TOPRIGHT = {0.5, 0.5},
    LEFT = {-0.5, 0}, CENTER = {0, 0}, RIGHT = {0.5, 0},
    BOTTOMLEFT = {-0.5, -0.5}, BOTTOM = {0, -0.5}, BOTTOMRIGHT = {0.5, -0.5},
}

function EmotePanel:CreateMainFrame()
    self.frame = CreateFrame("Frame", AddonName .. "Frame", UIParent)
    local frame = self.frame

    frame:SetAttribute("nodeignore", true)
    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(PANEL_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    -- Keep the artwork visible during fade-out after the input frame has closed.
    local display = CreateFrame("Frame", nil, UIParent)
    display:SetAllPoints(frame)
    display:SetFrameStrata("DIALOG")
    display:SetFrameLevel(frame:GetFrameLevel())
    display:SetAttribute("nodeignore", true)
    display:EnableMouse(false)
    display:SetAlpha(0)
    display:Hide()
    self.wheelDisplay = display

    return frame
end

local function IsCombatItemMissing(data)
    return EmotePanel.combatView and data.actionType == "item" and not data.automatic
        and not Entries.IsActionItemCarried(data.actionID)
end

local function IsCombatBlocked(mode, key, data)
    return InCombatLockdown() and (Entries.IsOutOfCombat(mode, key, data) or data.secureClick ~= nil
        or IsCombatItemMissing(data) or (not EmotePanel.combatView and Entries.IsSecureWheelAction(data)))
end

local function IsWheelEntryBlocked(mode, key, data)
    return IsCombatBlocked(mode, key, data) or Entries.GetUnavailableReason(mode, key, data) ~= nil
end

local function SetSelectionTint(texture, color)
    texture:SetDesaturated(color ~= nil)
    if color then
        texture:SetVertexColor(unpack(color))
    else
        texture:SetVertexColor(1, 1, 1)
    end
end

local function GetSelectionType(mode, key, data)
    if Entries.IsPlayerInteraction(mode, key) then return "interactions" end
    if Entries.GetRaidMarker(mode, key, data) then return "submenu" end
    if mode == "emotes" and Entries.voicedEmoteTokens[Entries.GetEmoteToken(data)] then
        return "voicedEmotes"
    end
    return SELECTION_COLORS[data.category] and data.category or data.actionType
end

local function ApplySelectedTint(self, mode, key, data, blocked)
    local selectionType = GetSelectionType(mode, key, data)
    local color = blocked and COMBAT_DISABLED_COLOR or SELECTION_COLORS[selectionType]
    local chatType = SELECTION_CHAT_TYPES[selectionType]
    local chatColor = not blocked and chatType and ChatTypeInfo and ChatTypeInfo[chatType]
    if chatColor and chatColor.r and chatColor.g and chatColor.b then
        color = { chatColor.r, chatColor.g, chatColor.b }
    end
    if not blocked and data.actionType == "pet" then
        if data.canAutocast and data.autocast ~= nil then
            color = data.autocast and PET_AUTOCAST_SELECTION_ON or PET_AUTOCAST_SELECTION_OFF
        elseif data.active then
            color = PET_ACTIVE_GLOW
        end
    end
    SetSelectionTint(self.highlight, color)
    if data.actionType ~= "pet" then SetSelectionTint(self.slots[self.selected].border, color) end
end

function EmotePanel:RefreshCombatAppearance()
    for index, slot in ipairs(self.slots) do
        local mode, key, data = Pages.GetSectorEntry(index)
        local blocked = data ~= nil and IsWheelEntryBlocked(mode, key, data) or false
        if slot.combatBlocked ~= blocked then
            slot.combatBlocked = blocked
            slot:SetAlpha(blocked and 0.55 or 1)
            slot.icon:SetDesaturated(blocked or slot.actionOnCooldown == true)
        end
        if data and index == self.selected then ApplySelectedTint(self, mode, key, data, blocked) end
    end
end

local WHEEL_STATUS_COLORS = {
    warning = { 1, 0.55, 0.51 },
    cooldown = { 1, 0.77, 0.45 },
    active = { 0.75, 0.92, 0.55 },
    normal = { 1, 1, 1 },
}

local function GetWheelEntryPreview(mode, key, data, slot)
    if data.actionType == "action" and not Entries.HasExtraAction() then
        return "Currently unavailable", WHEEL_STATUS_COLORS.warning
    end
    if InCombatLockdown() and Entries.IsOutOfCombat(mode, key, data) then
        return "Unavailable in combat", WHEEL_STATUS_COLORS.warning
    end
    local reason = Entries.GetUnavailableReason(mode, key, data)
    if reason then return reason, WHEEL_STATUS_COLORS.warning end
    if not Entries.IsSecureWheelAction(data) then return Entries.GetEntryPreview(mode, key, data) end
    if data.movePending then return "Choose a destination" end
    if slot.outOfRange then return "Out of range", WHEEL_STATUS_COLORS.warning end
    if slot.actionOnCooldown then return "On cooldown", WHEEL_STATUS_COLORS.cooldown end
    if slot.petUnusable then return "Currently unavailable", WHEEL_STATUS_COLORS.warning end
    if mode == "pet" and data.active then
        local color = WHEEL_STATUS_COLORS.active
        if data.attacking then return "Attacking", color end
        if key:find("^token:PET_MODE_") then return "Current stance", color end
        if key == "token:PET_ACTION_FOLLOW" or key == "token:PET_FOLLOW" then
            return "Following you", color
        end
        if key == "token:PET_ACTION_STAY" or key == "token:PET_ACTION_WAIT" or key == "token:PET_WAIT" then
            return "Holding position", color
        end
    end
    return ""
end

local function RefreshTextShadow(text)
    local shadow = text.shadow
    local content = text:GetText()
    if not text:IsShown() or issecretvalue(content) or not content or content == "" then
        shadow:Hide()
        return
    end

    local width, height = text:GetStringWidth(), text:GetStringHeight()
    if issecretvalue(width) or issecretvalue(height) then
        shadow:Hide()
        return
    end
    shadow:SetSize(math.min(width, 386) + 54, height + 20)
    shadow:Show()
end

local function RefreshPreviewLayout(self)
    local preview = self.messagePreview
    RefreshTextShadow(preview)
    local height = preview:GetStringHeight()
    local rowHeight = issecretvalue(height) and PREVIEW_ROW_HEIGHT or math.max(PREVIEW_ROW_HEIGHT, height)
    if self.previewRowHeight == rowHeight then return end
    self.previewRowHeight = rowHeight
    self.legendHint:SetPoint("TOP", self.selectionName, "BOTTOM", 0, -14 - rowHeight)
    self.legendFooter:SetPoint("TOP", self.selectionName, "BOTTOM", 0, -11 - rowHeight)
end

local function SetWheelEntryPreview(self, mode, key, data)
    local preview, color = GetWheelEntryPreview(mode, key, data, self.slots[self.selected])
    self.messagePreview:SetText(preview:gsub("|", "||"))
    self.messagePreview:SetTextColor(unpack(color or WHEEL_STATUS_COLORS.normal))
    RefreshPreviewLayout(self)
end

function EmotePanel:RefreshSelectedActionFeedback()
    if not self.frame:IsShown() then return end
    local mode, key, data = Pages.GetSectorEntry(self.selected)
    if data and data.contextualInvite then
        local label = Entries.GetInviteLabel(mode, key, data) or Entries.GetEntryName(mode, key, data)
        if self.selectionName:GetText() ~= label then
            self.selectionName:SetText(label)
            RefreshTextShadow(self.selectionName)
        end
    end
    if data and (data.unavailableReason or data.outOfCombat or Entries.IsSecureWheelAction(data)) then
        SetWheelEntryPreview(self, mode, key, data)
    end
end

local function PositionHighlight(self, angle)
    local radius = self.highlightRadius
    self.highlight:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)
    -- Blizzard's highlight atlas points down before rotation.
    self.highlight:SetRotation(math.pi - angle)
end

local vibrationActive
local function PulseWheelVibration()
    if vibrationActive or EmotePanelSavedVars.wheelVibration ~= true
        or not C_GamePad.SetVibration or not C_GamePad.IsEnabled() then return end
    vibrationActive = true
    C_GamePad.SetVibration("High", 0.25)
    C_Timer.After(0.045, function()
        C_GamePad.SetVibration("High", 0)
        vibrationActive = nil
    end)
end

function EmotePanel:Select(index, showTooltip, sound, fromController)
    if index then
        if Pages.currentPage.count == 0 then return end
        index = (index - 1) % Pages.currentPage.count + 1
        if index == self.selected then
            if showTooltip then self:ShowWheelEntryTooltip(index) end
            return
        end
    end

    if self.selected then
        local previousBorder = self.slots[self.selected].border
        previousBorder:SetAtlas(ICON_BORDER)
        SetSelectionTint(previousBorder)
    end
    self.selected = index
    local mode, slot, data = Pages.GetSectorEntry(index)
    if not data then
        self.highlight:Hide()
        local empty = ""
        if Pages.currentPage.mode == "pet" then
            local hasActions, reason = Entries.GetPetAvailability()
            if not hasActions then
                empty = reason or "No active pet actions"
            elseif index then
                empty = "Empty pet slot"
            end
        end
        self.selectionName:SetText(empty)
        self.messagePreview:SetText("")
        RefreshTextShadow(self.selectionName)
        RefreshPreviewLayout(self)
        if showTooltip then self:ShowWheelEntryTooltip(nil) end
        self:RefreshGamepadHint()
        return
    end
    self.highlight:Show()
    if mode ~= "pet" then self.slots[index].border:SetAtlas(SELECTED_ICON_BORDER) end
    PositionHighlight(self, (index - 1) * SECTOR_ANGLE)
    PlayWheelSound(sound)
    if fromController then PulseWheelVibration() end
    ApplySelectedTint(self, mode, slot, data, IsWheelEntryBlocked(mode, slot, data))
    self.selectionName:SetText(Entries.GetInviteLabel(mode, slot, data) or Entries.GetEntryName(mode, slot, data))
    RefreshTextShadow(self.selectionName)
    SetWheelEntryPreview(self, mode, slot, data)
    self:RefreshGamepadHint()
    if showTooltip then self:ShowWheelEntryTooltip(index) end
end

local function CreateIconSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(ICON_SLOT_SIZE, ICON_SLOT_SIZE)
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(38, 38)
    icon:SetPoint("CENTER")
    local mask = slot:CreateMaskTexture()
    mask:SetAtlas("CircleMask")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    slot.icon = icon
    return slot
end

function EmotePanel:CreateWheel()
    local wheel = CreateFrame("Button", nil, self.frame)
    wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    wheel:SetPoint("TOP", 0, -WHEEL_TOP_OFFSET)
    wheel:EnableMouse(true)
    wheel:RegisterForClicks("LeftButtonUp")
    self.wheel = wheel

    local display = CreateFrame("Frame", nil, self.wheelDisplay)
    display:SetAllPoints(wheel)
    self.wheelArt = Widgets.AddAtlas(display, WHEEL_ATLAS)
    self.wheelArt:SetAllPoints()
    self.highlight = Widgets.AddAtlas(display, SELECTION_ATLAS, "ARTWORK")
    local clearMark = CreateIconSlot(display)
    clearMark:SetPoint("CENTER")
    Widgets.SetIconTexture(clearMark.icon, Entries.CLEAR_MARK_ICON, true)
    clearMark.border = Widgets.AddAtlas(clearMark, ICON_BORDER, "OVERLAY")
    clearMark.border:SetAllPoints()
    clearMark:Hide()
    self.clearMarkIcon = clearMark

    local wheelInfo = C_Texture.GetAtlasInfo(WHEEL_ATLAS) or { width = 525 }
    local highlightInfo = C_Texture.GetAtlasInfo(SELECTION_ATLAS) or { width = 177, height = 168 }
    local scale = WHEEL_SIZE / wheelInfo.width
    self.highlight:SetSize(highlightInfo.width * scale, highlightInfo.height * scale)
    self.highlightRadius = 150 * scale

    local slots = CreateFrame("Frame", nil, display)
    slots:SetAllPoints()
    slots:SetFrameLevel(display:GetFrameLevel())
    self.wheelSlots = slots
    self.slots = {}
    for index = 1, ns.SECTOR_COUNT do
        local slot = CreateIconSlot(slots)
        local angle = (index - 1) * SECTOR_ANGLE
        local radius = self.highlightRadius
        slot:SetPoint("CENTER", wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)

        local icon = slot.icon

        local cooldownSwipe = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldownSwipe:SetAllPoints(icon)
        cooldownSwipe:EnableMouse(false)
        cooldownSwipe:SetDrawSwipe(true)
        cooldownSwipe:SetSwipeTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", 0, 0, 0, 0.64)
        cooldownSwipe:SetDrawEdge(false)
        cooldownSwipe:SetDrawBling(false)
        cooldownSwipe:SetHideCountdownNumbers(true)
        slot.cooldownSwipe = cooldownSwipe

        local recharge = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        recharge:SetFrameLevel(cooldownSwipe:GetFrameLevel() + 2)
        recharge:SetAllPoints(icon)
        recharge:EnableMouse(false)
        recharge:SetDrawSwipe(false)
        recharge:SetDrawEdge(true)
        recharge:SetUseCircularEdge(true)
        recharge:SetDrawBling(false)
        recharge:SetHideCountdownNumbers(true)
        slot.recharge = recharge

        local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetFrameLevel(recharge:GetFrameLevel() + 1)
        cooldown:SetAllPoints(icon)
        cooldown:EnableMouse(false)
        cooldown:SetDrawSwipe(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetScript("OnCooldownDone", function()
            slot.icon:SetDesaturated(slot.combatBlocked)
            if slot.actionOnCooldown then
                slot.actionOnCooldown = false
                self:RefreshSelectedActionFeedback()
            end
        end)
        slot.cooldown = cooldown

        local countOverlay = CreateFrame("Frame", nil, slot)
        countOverlay:SetAllPoints(icon)
        countOverlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)
        slot.countText = countOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        slot.countText:SetPoint("BOTTOMRIGHT", -1, 0)

        local petStatus = Widgets.AddAtlas(slot, SELECTED_ICON_BORDER, "OVERLAY")
        petStatus:SetSize(slot:GetWidth() + 4, slot:GetHeight() + 4)
        petStatus:SetPoint("CENTER")
        petStatus:SetDesaturated(true)
        petStatus:Hide()
        slot.petStatus = petStatus

        slot.border = Widgets.AddAtlas(slot, ICON_BORDER, "OVERLAY")
        slot.border:SetAllPoints()
        slot.pressedBorder = Widgets.AddAtlas(slot, "gamepad-actionbar-circleslot-border-pressed", "OVERLAY")
        slot.pressedBorder:SetAllPoints()
        slot.pressedBorder:Hide()

        slot.favorite = Widgets.AddAtlas(slot, "collections-icon-favorites", "OVERLAY")
        slot.favorite:SetSize(16, 16)
        slot.favorite:SetPoint("TOPRIGHT", 3, 3)
        self.slots[index] = slot
    end
    self:SetupWheelMouse(wheel, 75 * scale, 234 * scale)
end

function EmotePanel:SetClearMarkHovered(hovered)
    self.clearMarkIcon.border:SetAtlas(hovered and SELECTED_ICON_BORDER or ICON_BORDER)
    if not hovered or EmotePanelSavedVars.showWheelTooltips ~= true then return end
    if self.wheelTooltipFromMouse and not self.wheelTooltipSector and GameTooltip:IsOwned(self.wheel)
        and GameTooltip:IsShown() then return end
    self.wheelTooltipSector, self.wheelTooltipFromMouse = nil, true
    GameTooltip:SetOwner(self.wheel, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:SetText("Clear Mark")
    GameTooltip:Show()
end

function EmotePanel:ShowWheelEntryTooltip(sector, fromMouse)
    local owned = GameTooltip:IsOwned(self.wheel)
    if EmotePanelSavedVars.showWheelTooltips ~= true then
        if owned then GameTooltip:Hide() end
        return
    end
    local mode, key, data = Pages.GetSectorEntry(sector)
    if not data or IsCombatItemMissing(data) or (not fromMouse and not Entries.IsSecureWheelAction(data)) then
        if owned and (not fromMouse or self.wheelTooltipFromMouse) then GameTooltip:Hide() end
        return
    end
    if owned and GameTooltip:IsShown() and self.wheelTooltipSector == sector
        and self.wheelTooltipFromMouse == fromMouse then return end

    self.wheelTooltipSector, self.wheelTooltipFromMouse = sector, fromMouse
    local anchor = fromMouse and "ANCHOR_CURSOR_RIGHT" or "ANCHOR_RIGHT"
    GameTooltip:SetOwner(self.wheel, anchor)
    local kind, native = data.actionType
    if kind == "spell" then
        native = GameTooltip:SetSpellByID(data.actionID, false, true)
    elseif kind == "item" then
        native = GameTooltip:SetItemByID(data.actionID)
    elseif kind == "pet" then
        native = GameTooltip:SetPetAction(data.actionID)
    end
    if not native then
        if native == false then GameTooltip:SetOwner(self.wheel, anchor) end
        GameTooltip:SetText(Entries.GetInviteLabel(mode, key, data) or Entries.GetEntryName(mode, key, data))
    end
    if not native or kind == "pet" then
        local preview = (kind == "pet" or data.unavailableReason) and GetWheelEntryPreview(mode, key, data, self.slots[sector])
        preview = preview and preview ~= "" and preview or Entries.GetEntryPreview(mode, key, data)
        if preview ~= "" then GameTooltip:AddLine(preview:gsub("|", "||"), 1, 1, 1, true) end
    end
    if kind == "macro" then
        local body
        if Pages.currentPage.actions then
            local action = Pages.currentPage.actions[sector]
            if action.kind == "macro" then body = action.value end
        else
            local name, _, text = GetMacroInfo(data.macroIndex)
            if not issecretvalue(name) and name == data.name then body = text end
        end
        if not issecretvalue(body) and type(body) == "string" and body ~= "" then
            GameTooltip:AddLine((body:gsub("|", "||")), 1, 1, 1, true)
        end
    end
    if fromMouse and not self.combatView then
        if mode == "pet" then
            if not InCombatLockdown() and CombatWheel.GetPetAutocastMacro(data) then
                GameTooltip:AddLine("Right-click to toggle autocast", 0.7, 0.7, 0.7)
            end
        elseif mode ~= "targetMarkers" and not data.automatic then
            if Pages.currentPage ~= Pages.categoryWheel or not InCombatLockdown() then
                GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
            end
            if Pages.currentPage ~= Pages.categoryWheel then
                local hint = Entries.FindFavorite(mode, key) and "Middle-click to remove favorite" or "Middle-click to favorite"
                GameTooltip:AddLine(hint, 0.7, 0.7, 0.7)
            end
        end
    end
    GameTooltip:Show()
end

function EmotePanel:SetWheelPressed(index, input)
    if not index and input and input ~= self.wheelPressInput then return end
    if self.wheelPressSector then
        local slot = self.slots[self.wheelPressSector]
        slot.pressedBorder:Hide()
        slot.border:Show()
        slot.icon:SetPoint("CENTER")
    end
    self.wheelPressSector, self.wheelPressInput = nil, nil
    local mode, key, data = Pages.GetSectorEntry(index)
    if data and self.frame:IsShown() and self:CanUseWheel() and not IsWheelEntryBlocked(mode, key, data) then
        local slot = self.slots[index]
        self.wheelPressSector, self.wheelPressInput = index, input
        slot.border:Hide()
        slot.pressedBorder:Show()
        slot.icon:SetPoint("CENTER", 0, -2)
    end
end

local function GetActionItemOrSpell(data)
    if data.actionType == "item" then
        return data.actionID
    elseif data.actionType == "spell" then
        return nil, data.actionID
    elseif data.actionType == "action" or data.actionType == "pet" then
        return
    end
    local _, item = GetMacroItem(data.macroIndex)
    if not issecretvalue(item) and item then return item end
    local spellID = GetMacroSpell(data.macroIndex)
    if not issecretvalue(spellID) then return nil, spellID end
end

local function GetActionDisplayCount(data, item, spellID)
    if item then
        local count = C_Item.GetItemCount(item)
        if not issecretvalue(count) then return count > 999 and "999+" or tostring(count) end
    elseif spellID then
        return C_Spell.GetSpellDisplayCount(spellID, 999, "999+")
    elseif data.actionType == "action" and Entries.HasExtraAction() then
        return C_ActionBar.GetActionDisplayCount(data.actionID, 999, "999+")
    end
    return ""
end

local function SetDuration(cooldown, duration)
    if not issecretvalue(duration) and duration then
        cooldown:SetCooldownFromDurationObject(duration, true)
        return true
    end
    cooldown:Clear()
end

local function UpdateActionCooldown(slot, data, item, spellID)
    local cooldown, swipe = slot.cooldown, slot.cooldownSwipe
    local start, duration, enabled
    if data.actionType == "pet" then
        start, duration, enabled = GetPetActionCooldown(data.actionID)
    elseif data.actionType == "action" and Entries.HasExtraAction() then
        SetDuration(swipe, C_ActionBar.GetActionCooldownDuration(data.actionID, false))
        SetDuration(slot.recharge, C_ActionBar.GetActionChargeDuration(data.actionID))
        local actionDuration = C_ActionBar.GetActionCooldownDuration(data.actionID, true)
        return SetDuration(cooldown, actionDuration) and actionDuration:IsActive()
    elseif item then
        start, duration, enabled = C_Item.GetItemCooldown(item)
    elseif spellID then
        -- Pass the duration objects through without reading restricted cooldown times.
        SetDuration(swipe, C_Spell.GetSpellCooldownDuration(spellID, false))
        SetDuration(slot.recharge, C_Spell.GetSpellChargeDuration(spellID))
        -- A spell's GCD should animate without graying out the icon or showing numbers.
        local spellDuration = C_Spell.GetSpellCooldownDuration(spellID, true)
        if SetDuration(cooldown, spellDuration) then
            return spellDuration:IsActive()
        end
        return false
    end
    slot.recharge:Clear()
    if not (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enabled))
        and enabled and enabled ~= 0 and start and duration and start > 0 and duration > 0 and start + duration > GetTime() then
        cooldown:SetCooldown(start, duration)
        swipe:SetCooldown(start, duration)
        return true
    end
    cooldown:Clear()
    swipe:Clear()
    return false
end

function EmotePanel:RefreshActionCooldowns()
    local shown = self.frame:IsShown()
    local showNumbers = EmotePanelSavedVars.macroCooldowns ~= false
    for index, slot in ipairs(self.slots) do
        local data = shown and select(3, Pages.GetSectorEntry(index))
        local active = false
        local count = ""
        if data and Entries.IsSecureWheelAction(data) and not IsCombatItemMissing(data) then
            local item, spellID = GetActionItemOrSpell(data)
            slot.cooldown:SetHideCountdownNumbers(not showNumbers)
            active = UpdateActionCooldown(slot, data, item, spellID)
            count = GetActionDisplayCount(data, item, spellID)
        else
            slot.cooldown:Clear()
            slot.cooldownSwipe:Clear()
            slot.recharge:Clear()
        end
        -- Native display strings can be secret in combat. Pass them straight to the font string.
        slot.countText:SetText(count)
        slot.actionOnCooldown = not issecretvalue(active) and active
        slot.icon:SetDesaturated(slot.combatBlocked or active)
    end
    self:RefreshSelectedActionFeedback()
end

local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_START = true,
    UNIT_SPELLCAST_EMPOWER_UPDATE = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
}

local function GetPlayerCast()
    local spellID = select(9, UnitCastingInfo("player"))
    if not issecretvalue(spellID) and spellID then
        return spellID, UnitCastingDuration("player"), false
    end
    local channelID, empowered = select(8, UnitChannelInfo("player"))
    if issecretvalue(channelID) or not channelID then return end
    if empowered then return channelID, UnitEmpoweredChannelDuration("player"), false end
    return channelID, UnitChannelDuration("player"), true
end

local function ShowCastProgress(slot, duration, channel)
    local bar = slot.castProgress
    if not bar then
        bar = CreateFrame("StatusBar", nil, slot)
        bar:EnableMouse(false)
        bar:SetFrameLevel(slot.cooldownSwipe:GetFrameLevel() + 1)
        bar:SetAllPoints(slot.icon)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        local mask = bar:CreateMaskTexture()
        mask:SetAtlas("CircleMask")
        mask:SetAllPoints(bar)
        bar:GetStatusBarTexture():AddMaskTexture(mask)
        slot.castProgress = bar
    end
    bar:GetStatusBarTexture():SetAtlas(channel and "UI-HUD-ActionBar-Channel-Fill" or "UI-HUD-ActionBar-Cast-Fill")
    bar:SetAlpha(0.7)
    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
        channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    bar:Show()
end

local function ShowInterrupt(slot)
    local effect = slot.interrupt
    if not effect then
        effect = CreateFrame("Frame", nil, slot)
        effect:SetAllPoints(slot)
        effect:SetFrameLevel(slot.cooldown:GetFrameLevel() + 1)
        Widgets.AddAtlas(effect, "gamepad-actionbar-circleslot-interrupt", "OVERLAY"):SetAllPoints()
        local fade = effect:CreateAnimationGroup()
        local alpha = fade:CreateAnimation("Alpha")
        alpha:SetDuration(0.4)
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(0)
        fade:SetScript("OnFinished", function() effect:Hide() end)
        effect.fade = fade
        slot.interrupt = effect
    end
    effect.fade:Stop()
    effect:Show()
    effect.fade:Play()
end

local function SetProcGlow(slot, shown)
    local alert = slot.procGlow
    if shown then
        if not alert then
            alert = CreateFrame("Frame", nil, slot, "ActionButtonSpellAlertTemplate")
            alert:SetPoint("CENTER")
            alert:SetSize(slot:GetWidth() * 1.4, slot:GetHeight() * 1.4)
            alert.ProcStartFlipbook:SetSize(slot:GetWidth() * 1.8, slot:GetHeight() * 1.8)
            alert:SetFrameLevel(slot.cooldown:GetFrameLevel() + 1)
            slot.procGlow = alert
        end
        if not alert:IsShown() then
            alert:Show()
            alert.ProcStartAnim:Play()
        end
    elseif alert then
        alert.ProcStartAnim:Stop()
        alert.ProcLoop:Stop()
        alert:Hide()
    end
end

function EmotePanel:RefreshSpellFeedback(interrupted)
    local shown = self.frame:IsShown() and (Pages.currentPage.mode == "macros" or Pages.currentPage.mode == "favorites")
    local castID, duration, channel
    if shown then castID, duration, channel = GetPlayerCast() end
    for index, slot in ipairs(self.slots) do
        local data = shown and select(3, Pages.GetSectorEntry(index))
        local spellID
        if data and Entries.IsSecureWheelAction(data) and data.actionType ~= "pet" and not IsCombatItemMissing(data) then
            local item
            item, spellID = GetActionItemOrSpell(data)
            if item then spellID = select(2, C_Item.GetItemSpell(item)) end
            if issecretvalue(spellID) then spellID = nil end
        end
        if slot.feedbackSpellID ~= spellID then
            SetProcGlow(slot, false)
            if slot.interrupt then
                slot.interrupt.fade:Stop()
                slot.interrupt:Hide()
            end
            slot.feedbackSpellID = spellID
        end
        local wasInterrupted = spellID and spellID == interrupted
        if spellID and spellID == castID and not wasInterrupted and not issecretvalue(duration) and duration then
            ShowCastProgress(slot, duration, channel)
        elseif slot.castProgress then
            slot.castProgress:Hide()
        end
        if wasInterrupted then ShowInterrupt(slot) end
        local proc = spellID and C_SpellActivationOverlay.IsSpellOverlayed(spellID)
        SetProcGlow(slot, not issecretvalue(proc) and proc)
    end
end

local function GetActionInRange(data)
    if data.actionType == "pet" then
        local checksRange, inRange = select(8, GetPetActionInfo(data.actionID))
        if not issecretvalue(checksRange) and checksRange then return inRange end
        return
    end
    local item, spellID = GetActionItemOrSpell(data)
    if item then
        local checksRange = C_Item.ItemHasRange(item)
        if not issecretvalue(checksRange) and checksRange then
            return C_Item.IsItemInRange(item, "target")
        end
    elseif spellID then
        return C_Spell.IsSpellInRange(spellID, "target")
    end
end

function EmotePanel:RefreshActionRanges()
    local shown = self.frame:IsShown()
    local hasTarget = shown and UnitExists("target")
    local canCheck = not issecretvalue(hasTarget) and hasTarget
    for index, slot in ipairs(self.slots) do
        local data = shown and not slot.combatBlocked and select(3, Pages.GetSectorEntry(index))
        local inRange
        if canCheck and data and Entries.IsSecureWheelAction(data) then inRange = GetActionInRange(data) end
        local outOfRange = not issecretvalue(inRange) and inRange == false
        local usable
        if data and data.actionType == "pet" then usable = GetPetActionSlotUsable(data.actionID) end
        local petUnusable = not issecretvalue(usable) and usable == false
        if outOfRange ~= slot.outOfRange or petUnusable ~= slot.petUnusable then
            slot.outOfRange = outOfRange
            slot.petUnusable = petUnusable
            local brightness = petUnusable and 0.55 or 1
            local greenAndBlue = outOfRange and 0.3 * brightness or brightness
            slot.icon:SetVertexColor(brightness, greenAndBlue, greenAndBlue)
        end
    end
    self:RefreshSelectedActionFeedback()
end

local function SetPetAttackPulse(texture, attacking)
    local pulse = texture.attackPulse
    if attacking then
        if not pulse then
            pulse = texture:CreateAnimationGroup()
            pulse:SetLooping("BOUNCE")
            local alpha = pulse:CreateAnimation("Alpha")
            alpha:SetFromAlpha(0.45)
            alpha:SetToAlpha(0.9)
            alpha:SetDuration(0.6)
            texture.attackPulse = pulse
        end
        if not pulse:IsPlaying() then pulse:Play() end
    elseif pulse then
        pulse:Stop()
    end
end

function EmotePanel:RefreshSpellIcons()
    for index, slot in ipairs(self.slots) do
        local mode, key, data = Pages.GetSectorEntry(index)
        if data and data.actionType == "spell" and not data.automatic then
            Widgets.SetIconTexture(slot.icon, Entries.GetEntryIcon(mode, key, data), true)
        end
    end
end

function EmotePanel:RefreshWheel(selection)
    if not self.frame:IsShown() and self.wheelDisplay:IsShown() then
        -- Combat close can select a new page while the old one is still fading.
        self.pendingWheelRefresh = { selection = selection }
        self:UpdateSecureWheelInput()
        self:SyncCombatWheel()
        return
    end
    self.pendingWheelRefresh = nil
    self.titleText:SetText(Pages.currentPage.title)
    self.clearMarkIcon:SetShown(Pages.currentPage.mode == "targetMarkers")
    self:SetWheelPressed(nil)
    self:RefreshWheelFooter()
    self.leftPageArrow:SetShown(self.canPageLeft == true)
    self.rightPageArrow:SetShown(self.canPageRight == true)
    for index, slot in ipairs(self.slots) do
        local mode, entryIndex, data = Pages.GetSectorEntry(index)
        local used = data ~= nil
        if data then
            Widgets.SetIconTexture(slot.icon, Entries.GetEntryIcon(mode, entryIndex, data), true)
            slot.border:SetAtlas(ICON_BORDER)
            SetSelectionTint(slot.border)
            slot.favorite:SetShown(Pages.currentPage.mode ~= "favorites" and Entries.FindFavorite(mode, entryIndex) ~= nil)
            used = not IsCombatItemMissing(data)
        end
        local statusColor
        if data and mode == "pet" then
            statusColor = data.active and PET_ACTIVE_GLOW or data.canAutocast and data.autocast and PET_AUTOCAST_GLOW
        end
        if statusColor then slot.petStatus:SetVertexColor(unpack(statusColor)) end
        slot.petStatus:SetShown(not not statusColor)
        SetPetAttackPulse(slot.petStatus, data and mode == "pet" and data.attacking and self.frame:IsShown())
        slot:SetShown(used)
    end
    local nextSelection = selection or self.selected
    self.selected = nil
    self:RefreshCombatAppearance()
    self:RefreshActionCooldowns()
    self:RefreshActionRanges()
    self:RefreshSpellFeedback()
    local hasEntries = Pages.currentPage.count > 0
    if hasEntries then
        if nextSelection or not self.combatView then
            self:Select(math.min(nextSelection or 1, Pages.currentPage.count))
        else
            self:Select(nil)
        end
    else
        self.highlight:Hide()
        local emptyText = Pages.currentPage.mode == "favorites" and "No favorites" or "No visible entries"
        if Pages.currentPage.mode == "categories" then
            emptyText = "No visible categories"
        elseif Pages.currentPage.mode == "professions" then
            emptyText = Entries.HasLearnedProfessions() and "No visible professions" or "No learned professions"
        elseif Pages.currentPage.mode == "pet" then
            local hasActions, reason = Entries.GetPetAvailability()
            emptyText = hasActions and "No visible pet actions" or reason or "No active pet actions"
        end
        self.selectionName:SetText(emptyText)
        self.messagePreview:SetText("")
        RefreshTextShadow(self.selectionName)
        RefreshPreviewLayout(self)
        self:RefreshGamepadHint()
    end
    self:UpdateSecureWheelInput()
    self:SyncCombatWheel()
    if GameTooltip:IsOwned(self.wheel) and GameTooltip:IsShown() then
        local sector = self.wheelTooltipFromMouse and self.wheelTooltipSector or self.selected
        self.wheelTooltipSector = nil
        self:ShowWheelEntryTooltip(sector, self.wheelTooltipFromMouse)
    end
end

function EmotePanel:CreateControls()
    local frame = self.wheelDisplay
    local header = Widgets.AddAtlas(frame, "gamepad-radial-menu-toptext", "BORDER")
    header:SetSize(374, 58)
    header:SetPoint("TOP", 0, -2)

    local dragArea = CreateFrame("Frame", nil, self.frame)
    dragArea:SetSize(206, 50)
    dragArea:SetPoint("TOP", 0, -2)
    dragArea:EnableMouse(true)
    dragArea:RegisterForDrag("LeftButton")
    dragArea:SetScript("OnDragStart", function() self.frame:StartMoving() end)
    dragArea:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        self:SavePosition()
        self:UpdateSecureWheelInput()
    end)

    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("CENTER", frame, "TOP", 0, TITLE_Y)
    self.titleText:SetWidth(206)
    self.titleText:SetJustifyH("CENTER")
    self.titleText:SetWordWrap(false)
    self.titleText:SetTextColor(1, 0.96, 0.87)
    self.titleText:SetText(Pages.currentPage.title)

    self.leftPageArrow = Widgets.AddAtlas(frame, "common-icon-backarrow", "OVERLAY")
    self.leftPageArrow:SetSize(14, 22)
    self.leftPageArrow:SetPoint("CENTER", frame, "TOP", -118, TITLE_Y)
    self.rightPageArrow = Widgets.AddAtlas(frame, "common-icon-forwardarrow", "OVERLAY")
    self.rightPageArrow:SetSize(14, 22)
    self.rightPageArrow:SetPoint("CENTER", frame, "TOP", 118, TITLE_Y)

    local footer = Widgets.AddAtlas(frame, "gamepad-radial-menu-bottomtext", "BORDER")
    footer:SetSize(410, 102)
    self.legendFooter = footer

    self.selectionName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.selectionName:SetPoint("TOP", 0, -421)
    self.selectionName:SetWidth(386)
    self.selectionName:SetWordWrap(false)
    self.selectionName:SetTextColor(1, 0.96, 0.87)
    self.navigationHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.navigationHint:SetPoint("CENTER", footer, "CENTER", 0, 18.5)
    self.gamepadHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.gamepadHint:SetPoint("CENTER", footer, "CENTER", 0, -18.5)

    self.legendHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.legendHint:SetTextColor(0.8, 0.77, 0.7)
    self.legendAlpha = 0

    self.messagePreview = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.messagePreview:SetPoint("TOP", self.selectionName, "BOTTOM", 0, -7)
    self.messagePreview:SetWidth(386)
    self.messagePreview:SetJustifyH("CENTER")
    self.messagePreview:SetWordWrap(true)
    self.messagePreview:SetNonSpaceWrap(true)

    for _, text in ipairs({self.selectionName, self.legendHint, self.messagePreview}) do
        local shadow = frame:CreateTexture(nil, "BACKGROUND")
        shadow:SetTexture("Interface\\AddOns\\" .. AddonName .. "\\Art\\WheelTextShadow")
        shadow:SetPoint("CENTER", text, "CENTER")
        shadow:SetAlpha(TEXT_SHADOW_ALPHA)
        text.shadow = shadow
        shadow:Hide()
    end

    RefreshPreviewLayout(self)
    self:RefreshLegendHint()
    self:RefreshWheelFooter()
    self.frame:HookScript("OnShow", function()
        if self.combatView then return end
        if EmotePanelSavedVars.followCursorCenter then self:LoadPosition() end
        Entries.ReadPetActions()
        Pages.BuildPetPages()
        if Entries.RefreshCarriedActionItems() then Pages.BuildCategoryPages() end
        Pages.RefreshProfessions()
        if self.openingPetWheel then
            self:ShowPetStartPage()
        else
            self:ShowStartPage(true)
        end
    end)
    if InputDeviceIconSetManager then
        InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(self.RefreshControllerPrompts, self)
    end
end

function EmotePanel:RefreshWheelFooter()
    local alwaysShow = EmotePanelSavedVars.showKeybindLegend ~= false
    local alpha = alwaysShow and 1 or self.legendAlpha
    local legend = alpha > 0
    local hint = not alwaysShow and alpha < 1 and EmotePanelSavedVars.showLegendHint ~= false
        and Input.CanToggleLegend() and C_CVar.GetCVarBool("GamePadEnable")
    self.legendFooter:SetShown(legend)
    self.legendFooter:SetAlpha(alpha)
    self.navigationHint:SetShown(legend)
    self.navigationHint:SetAlpha(alpha)
    self.gamepadHint:SetShown(legend)
    self.gamepadHint:SetAlpha(alpha)
    self.legendHint:SetShown(hint)
    self.legendHint:SetAlpha(1 - alpha)
    RefreshTextShadow(self.legendHint)
    self.legendHint.shadow:SetAlpha(TEXT_SHADOW_ALPHA * (1 - alpha))
    self.messagePreview:Show()
end

function EmotePanel:ToggleWheelLegend()
    if self.frame:IsShown() and self:CanUseWheel() and Input.CanToggleLegend() then
        self.legendExpanded = not self.legendExpanded
    end
end

function EmotePanel:RefreshLegendHint()
    self.legendHint:SetText(Widgets.GamepadGlyph("PADBACK", "View / Select") .. " Show controls")
    RefreshTextShadow(self.legendHint)
end

function EmotePanel:RefreshControllerPrompts()
    self:RefreshGamepadHint()
    self:RefreshLegendHint()
    Widgets.RefreshGlyphPrompts()
end

function EmotePanel:RefreshGamepadHint()
    local navigation = Widgets.GamepadGlyph("PADLSTICKAXIS", "Left stick") .. " / "
        .. Widgets.GamepadGlyph("PADRSTICKAXIS", "Right stick") .. " "
        .. Widgets.GamepadGlyph("DIRPADVERTICAL", "Up/Down") .. " Select"
    if Pages.currentPage.mode == "categories" then
        if self.canPageLeft then
            navigation = navigation .. "       " .. Widgets.GamepadGlyph("PADDLEFT", "Left") .. " / "
                .. Widgets.GamepadGlyph("PADLSHOULDER", "LB") .. " " .. Pages.ACTIONS_TITLE
        end
    elseif Pages.currentPage.mode == "macros" and self.canGoBack and self.canPageRight then
        local _, last = Pages.GetCategoryPageRange("macros")
        local toCategories = Pages.currentPageIndex == last
        if self.combatView then toCategories = Pages.currentPage.right == 0 end
        local destination = toCategories and "Categories" or "Previous page"
        navigation = navigation .. "       " .. Widgets.GamepadGlyph("PADDRIGHT", "Right") .. " / "
            .. Widgets.GamepadGlyph("PADRSHOULDER", "RB") .. " " .. destination
    elseif self.canPageLeft ~= self.canPageRight then
        local direction = self.canPageRight
        navigation = navigation .. "       "
            .. (direction and Widgets.GamepadGlyph("PADDRIGHT", "Right") or Widgets.GamepadGlyph("PADDLEFT", "Left"))
            .. " / " .. (direction and Widgets.GamepadGlyph("PADRSHOULDER", "RB") or Widgets.GamepadGlyph("PADLSHOULDER", "LB"))
            .. (direction and " Next page" or " Previous page")
    elseif self.canPageLeft then
        navigation = navigation .. "       " .. Widgets.GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " / "
            .. Widgets.GamepadGlyph("PADLSHOULDER", "LB") .. " " .. Widgets.GamepadGlyph("PADRSHOULDER", "RB") .. " Page"
    end
    self.navigationHint:SetText(navigation)
    local mode, slot, data = Pages.GetSectorEntry(self.selected)
    local actions
    if Pages.currentPage.mode == "categories" then
        actions = data and (IsCombatBlocked(mode, slot, data) and "Unavailable in combat    "
            or Widgets.GamepadGlyph("PAD1", "A") .. " Open    ") or ""
        if data and not self.combatView and not InCombatLockdown() then
            actions = actions .. Widgets.GamepadGlyph("PAD4", "Y") .. " Edit    "
        end
    elseif data then
        local favoriteAction = Entries.FindFavorite(mode, slot) and "Unfavorite" or "Favorite"
        local primaryAction = (data.actionType == "profession" or data.actionType == "panel" or data.actionType == "submenu") and "Open" or "Use"
        actions = IsCombatItemMissing(data) and "Not carried"
            or IsCombatBlocked(mode, slot, data) and "Unavailable in combat"
            or Entries.GetUnavailableReason(mode, slot, data)
            or Widgets.GamepadGlyph("PAD1", "A") .. " " .. primaryAction
        if mode == "pet" then
            local macro = CombatWheel.GetPetAutocastMacro(data)
            local pet = self.combatView and UnitName("pet")
            if macro and (not InCombatLockdown() or (self.combatView and not issecretvalue(pet)
                and pet == self.combatAutocastPet and Pages.currentPage.actions[self.selected].autocast == macro)) then
                local prompt = data.autocast == nil and "Autocast" or data.autocast and "Disable" or "Activate"
                actions = actions .. "    " .. Widgets.GamepadGlyph("PAD3", "X") .. " " .. prompt
            end
        elseif mode ~= "targetMarkers" and not self.combatView and not data.automatic then
            actions = actions .. "    " .. Widgets.GamepadGlyph("PAD3", "X") .. " " .. favoriteAction
                .. "    " .. Widgets.GamepadGlyph("PAD4", "Y") .. " Edit"
            if not Input.CanToggleLegend() and self:GetRemovableWheelAction() then
                actions = actions .. "    " .. Widgets.GamepadGlyph("PADBACK", "Select") .. " Remove"
            end
        end
        actions = actions .. "    "
    elseif Pages.currentPage.mode == "pet" or Pages.currentPage == Pages.professionPage or Pages.IsCategoryWheelEnabled() then
        actions = ""
    else
        actions = "Browse pages and press " .. Widgets.GamepadGlyph("PAD3", "X") .. " to add    "
    end
    if Pages.currentPage.mode == "targetMarkers" then
        if data then actions = actions .. Widgets.GamepadGlyph("PAD4", "Y") .. " Mark Self    " end
        actions = actions .. Widgets.GamepadGlyph("PAD3", "X") .. " Clear Mark    "
    end
    self.gamepadHint:SetText(actions .. Widgets.GamepadGlyph("PAD2", "B") .. (self.canGoBack and " Back" or " Close"))
end

local function RoundOffset(value)
    if value < 0 then return math.ceil(value - 0.5) end
    return math.floor(value + 0.5)
end

function EmotePanel:SavePosition()
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end

    local point, _, relativePoint, x, y = self.frame:GetPoint()
    local position = {
        point = point,
        relativePoint = relativePoint,
        x = RoundOffset(x),
        y = RoundOffset(y),
    }
    if EmotePanelSavedVars.followCursorCenter and self:GetCursorCenterFraction() then
        local _, manualY = self:GetPositionOffsets()
        self:SetPositionOffsets(x, manualY)
        if self.customizationPanel then self.customizationPanel:refreshPosition() end
        return
    end
    EmotePanelSavedVars.positions.emotePanel = position
    if position.x ~= x or position.y ~= y then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, relativePoint, position.x, position.y)
    end
    if self.customizationPanel then self.customizationPanel:refreshPosition() end
    self:SyncCombatWheel(true)
end

function EmotePanel:LoadPosition()
    if self.combatView or (InCombatLockdown() and self.combatBindingReady) then return end
    if not EmotePanelSavedVars then EmotePanelSavedVars = {} end
    if not EmotePanelSavedVars.positions then EmotePanelSavedVars.positions = {} end

    local position = self:GetWheelPosition()

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
    self:UpdateSecureWheelInput()
    self:SyncCombatWheel(true)
end

function EmotePanel:GetPositionOffsets()
    local positions = EmotePanelSavedVars.positions
    local position = positions and positions.emotePanel or DEFAULT_POSITION
    local point = ANCHOR_OFFSETS[position.point]
    local relativePoint = ANCHOR_OFFSETS[position.relativePoint]
    local x, y = position.x, position.y
    -- Translate older dragged positions without changing their saved anchor.
    if point and relativePoint and (position.point ~= "CENTER" or position.relativePoint ~= "CENTER") then
        x = x + relativePoint[1] * UIParent:GetWidth() - point[1] * self.frame:GetWidth()
        y = y + relativePoint[2] * UIParent:GetHeight() - point[2] * self.frame:GetHeight()
    end
    return x, y
end

local function GetPositionLimits(frame)
    return math.max(0, math.floor((UIParent:GetWidth() - frame:GetWidth()) / 2)),
        math.max(0, math.floor((UIParent:GetHeight() - frame:GetHeight()) / 2))
end

function EmotePanel:GetCursorCenterFraction()
    local value = C_CVar.GetCVar("CursorCenteredYPos")
    if issecretvalue(value) then return end
    value = tonumber(value)
    if value and value >= 0 and value <= 1 then return value end
end

function EmotePanel:GetWheelPosition()
    local positions = EmotePanelSavedVars.positions
    local position = positions and positions.emotePanel or DEFAULT_POSITION
    if not EmotePanelSavedVars.followCursorCenter then return position end
    local fraction = self:GetCursorCenterFraction()
    if not fraction then return position end

    local x = self:GetPositionOffsets()
    local maxX, maxY = GetPositionLimits(self.frame)
    local wheelCenter = self.frame:GetHeight() / 2 - WHEEL_TOP_OFFSET - WHEEL_SIZE / 2
    local y = UIParent:GetHeight() * (fraction - 0.5) - wheelCenter
    return {
        point = "CENTER",
        relativePoint = "CENTER",
        x = math.max(-maxX, math.min(x, maxX)),
        y = math.max(-maxY, math.min(y, maxY)),
    }
end

function EmotePanel:SetPositionOffsets(x, y)
    local maxX, maxY = GetPositionLimits(self.frame)
    EmotePanelSavedVars.positions.emotePanel = {
        point = "CENTER", relativePoint = "CENTER",
        x = math.max(-maxX, math.min(x, maxX)),
        y = math.max(-maxY, math.min(y, maxY)),
    }
    self:LoadPosition()
end

local function SetupWheelFade(self)
    local display = self.wheelDisplay
    local alpha = 0
    local function FinishFade()
        display:SetScript("OnUpdate", nil)
        if alpha == 0 then
            display:Hide()
            local pending = self.pendingWheelRefresh
            if pending then self:RefreshWheel(pending.selection) end
        end
    end
    local function FadeTo(target, duration)
        if target == 1 then display:Show() end
        if alpha == target then
            FinishFade()
            return
        end
        display:SetScript("OnUpdate", function(_, elapsed)
            local step = elapsed / duration
            if target == 1 then
                alpha = math.min(target, alpha + step)
            else
                alpha = math.max(target, alpha - step)
            end
            display:SetAlpha(alpha)
            if alpha == target then FinishFade() end
        end)
    end
    self.frame:HookScript("OnShow", function()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_OPEN)
        FadeTo(1, FADE_IN_DURATION)
    end)
    self.frame:HookScript("OnHide", function()
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_CLOSE)
        FadeTo(0, FADE_OUT_DURATION)
    end)
end

local function DrawPageTransition(self, progress)
    local alpha = 0.8 + 0.2 * progress
    self.wheelSlots:SetAlpha(alpha)
    self.titleText:SetAlpha(alpha)
end

function EmotePanel:AnimateWheelPage(navigation)
    if navigation and self.frame:IsShown() then
        PlayWheelSound(SOUNDKIT.GAMEPAD_RADIAL_MENU_TAB_OVER)
        self.pageTransition = 0
        DrawPageTransition(self, 0)
    elseif self.pageTransition then
        self.pageTransition = nil
        DrawPageTransition(self, 1)
    end
end

function EmotePanel:InitializeWheel()
    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateControls()
    self:RefreshWheel()
    self:LoadPosition()
    local rangeElapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        if EmotePanelSavedVars.showKeybindLegend == false then
            local alpha = self.legendAlpha
            if self.legendExpanded then
                self.legendAlpha = math.min(1, alpha + elapsed / FADE_IN_DURATION)
            else
                self.legendAlpha = math.max(0, alpha - elapsed / FADE_OUT_DURATION)
            end
            if self.legendAlpha ~= alpha then self:RefreshWheelFooter() end
        end
        if self.pageTransition then
            self.pageTransition = self.pageTransition + elapsed
            if self.pageTransition >= PAGE_TRANSITION_DURATION then
                self:AnimateWheelPage()
            else
                DrawPageTransition(self, self.pageTransition / PAGE_TRANSITION_DURATION)
            end
        end
        -- An already queued ConsolePort update can show the cursor again.
        Input.HideConsolePortCursor()
        local page = Pages.currentPage
        local checksInteractions = page.category == "interactions" or page.mode == "favorites"
        if not checksInteractions and page.mode ~= "macros" and page.mode ~= "pet" then return end
        rangeElapsed = rangeElapsed + elapsed
        if rangeElapsed >= RANGE_CHECK_INTERVAL then
            rangeElapsed = 0
            if checksInteractions then
                self:RefreshCombatAppearance()
                local _, _, data = Pages.GetSectorEntry(self.selected)
                if data and data.interactDistance then self:RefreshGamepadHint() end
            end
            self:RefreshActionRanges()
        end
    end)
    self.frame:HookScript("OnHide", function()
        self.legendExpanded = nil
        if self.legendAlpha > 0 then
            self.legendAlpha = 0
            self:RefreshWheelFooter()
        end
        self:AnimateWheelPage()
        self:StopWheelMouseTooltip()
        if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
        self:SetWheelMovementCapture(false)
        self:SetWheelPressed(nil)
        for _, slot in ipairs(self.slots) do SetPetAttackPulse(slot.petStatus, false) end
        self:RefreshSpellFeedback()
        self:UpdateSecureWheelInput()
        if not self.combatView and self.gamepadInput then self.gamepadInput:Show() end
        if self.customMessageDialog then self.customMessageDialog:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_RESET_ALL")
        StaticPopup_Hide("EMOTEPANEL_RESET_SETTINGS")
    end)

    -- Hide by default
    self.frame:Hide()
    SetupWheelFade(self)
    self.frame:HookScript("OnShow", function() self:SetWheelMovementCapture(true) end)
    self.frame:HookScript("OnShow", function(frame) Input.SetConsolePortCursorObstructed(frame, true) end)
    self.frame:HookScript("OnHide", function(frame) Input.SetConsolePortCursorObstructed(frame, false) end)

    -- Blizzard closes special windows separately from the protected Escape handlers.
    table.insert(UISpecialFrames, self.frame:GetName())
end

local function HandleDisplayChanged()
    EmotePanel:UpdateSecureWheelInput()
    EmotePanel:SyncCombatWheel(true)
    local panel = EmotePanel.customizationPanel
    if panel:IsVisible() then panel:refreshPosition() end
end

local function HandleSpellcast(event, unit, _, spellID)
    if EmotePanel.frame:IsShown() and not issecretvalue(unit) and unit == "player" then
        local interrupted = event == "UNIT_SPELLCAST_INTERRUPTED" and not issecretvalue(spellID) and spellID
        EmotePanel:RefreshSpellFeedback(interrupted)
    end
end

Wheel.CAST_EVENTS = CAST_EVENTS
Wheel.GetPositionLimits = GetPositionLimits
Wheel.RoundOffset = RoundOffset
Wheel.SECTOR_ANGLE = SECTOR_ANGLE
Wheel.WHEEL_SIZE = WHEEL_SIZE
Wheel.TOP_OFFSET = WHEEL_TOP_OFFSET
Wheel.CLEAR_MARK_RADIUS = ICON_SLOT_SIZE / 2
Wheel.HandleDisplayChanged = HandleDisplayChanged
Wheel.HandleSpellcast = HandleSpellcast
