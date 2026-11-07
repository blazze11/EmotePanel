"""Exercise EmotePanel startup, navigation, and saved slots with a Lua 5.1 UI mock."""
import os
import sys
from pathlib import Path
from xml.etree import ElementTree

if os.environ.get("LUA_TEST_DEPS"):
    sys.path.insert(0, os.environ["LUA_TEST_DEPS"])
from lupa.lua51 import LuaRuntime

tests = Path(__file__).resolve().parent
addon = tests.parent / "EmotePanel"
toc = dict(line[3:].split(": ", 1) for line in (addon / "EmotePanel.toc").read_text().splitlines() if line.startswith("## "))
assert toc["Interface"] == "16001"
bindings = ElementTree.parse(addon / "Bindings.xml").getroot()
opener = bindings.find("./Binding[@name='CLICK EmotePanelCombatInput:Toggle']")
assert opener is not None and opener.attrib["runOnUp"] == "true"
legacy = bindings.find("./Binding[@name='Open Emote Panel']")
assert legacy.attrib["hidden"] == "true" and legacy.text.strip() == "EmotePanel_Toggle()"

lua = LuaRuntime()
lua.execute((tests / "options_mock.lua").read_text())
lua.globals().addonVersion = toc["Version"]
lua.globals().addonCompartmentCallback = toc["AddonCompartmentFunc"]


def load_addon():
    for name in ("EmotePanel.lua", "CombatWheel.lua"):
        lua.execute((addon / name).read_text())


lua.execute("""
    local baseWidget = Widget
    function Widget()
        local widget = baseWidget()
        widget.SetMaxLines = function() end
        widget.SetNonSpaceWrap = function(self, value) self.nonSpaceWrap = value end
        widget.GetStringHeight = function() return 14 end
        widget.HasFocus = function(self) return self.focus == true end
        widget.SetNormalFontObject = function() end
        widget.SetHighlightFontObject = function() end
        widget.SetDisabledFontObject = function() end
        widget.SetTextInsets = function() end
        widget.SetNormalAtlas = function(self, atlas) self.normalAtlas = atlas end
        widget.SetPushedAtlas = function(self, atlas) self.pushedAtlas = atlas end
        widget.SetHighlightAtlas = function(self, atlas) self.highlightAtlas = atlas end
        local createTexture = widget.CreateTexture
        function widget:CreateTexture(...)
            local texture = createTexture(self, ...)
            texture.AddMaskTexture = function(region, mask) region.mask = mask end
            texture.SetTexCoord = function(region, ...) region.texCoords = {...} end
            return texture
        end
        widget.CreateMaskTexture = widget.CreateTexture
        return widget
    end

    local baseCreateFrame = CreateFrame
    UIParent = Widget()
    accountMacros, characterMacros, macroRuns = {}, {}, {}
    playerGUID = "Player-1-1"
    Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
    function UnitGUID(unit) assert(unit == "player"); return playerGUID end
    function GetNumMacros() return #accountMacros, #characterMacros end
    local function FindMacro(index)
        return index <= 120 and accountMacros[index] or characterMacros[index - 120]
    end
    function GetMacroInfo(index)
        local macro = FindMacro(index)
        if macro then return unpack(macro) end
    end
    function GetMacroSpell(index)
        local macro = FindMacro(index)
        return macro and macro.spell
    end
    function GetMacroItem(index)
        local macro = FindMacro(index)
        if macro and macro.item then return "Item name", macro.item end
    end
    spellCooldowns, itemCooldowns, cooldownQueries = {}, {}, 0
    spellRanges, itemRanges = {}, {}
    function UnitExists(unit)
        assert(unit == "target")
        return targetExists
    end
    cooldownTime = 100
    function GetTime() return cooldownTime end
    function MockSpellCooldown(active)
        return { IsActive = function() return active end }
    end
    directRuns, bagItems, equippedItems = {}, {}, {}
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and #bagItems or 0 end,
        GetContainerItemInfo = function(bag, slot)
            assert(bag == 0)
            return {itemID = bagItems[slot], iconFileID = 9903}
        end,
    }
    C_Spell = { GetSpellCooldownDuration = function(id, ignoreGCD)
        assert(ignoreGCD)
        cooldownQueries = cooldownQueries + 1
        return spellCooldowns[id]
    end }
    C_Item = { GetItemCooldown = function(link)
        cooldownQueries = cooldownQueries + 1
        return unpack(assert(itemCooldowns[link]))
    end }
    function C_Spell.IsSpellInRange(id, unit)
        assert(unit == "target" and targetExists)
        return spellRanges[id]
    end
    function C_Item.ItemHasRange(id) return itemRanges[id] ~= nil end
    function C_Item.IsItemInRange(id, unit)
        assert(unit == "target" and targetExists)
        return itemRanges[id]
    end
    function C_Spell.IsSpellPassive(id) return id == 992 end
    function C_Spell.GetSpellInfo(id)
        if id == 995 then return {name = "Flyout Spell", iconID = 9905} end
    end
    function GetFlyoutInfo(id) assert(id == 77); return "Flyout", nil, 1 end
    function GetFlyoutSlotInfo(id, slot) assert(id == 77 and slot == 1); return 995, 0, true end
    function C_Item.GetItemNameByID(id) if id == 993 then return "Direct Item" end end
    function C_Item.GetItemCount(id)
        local count = 0
        for _, item in ipairs(bagItems) do if item == id then count = count + 1 end end
        return count
    end
    function C_Item.IsEquippedItem(id) return equippedItems[id] == true end
    function C_Item.IsUsableItem(id) return id == 993 end
    local restricted = false
    local function runRestricted(callback, ...)
        local previous = restricted
        restricted = true
        local results = {callback(...)}
        restricted = previous
        return unpack(results)
    end
    function SecureHandlerWrapScript(frame, script, header, snippet)
        assert(frame == header)
        local callback = assert(loadstring("return function(self, button, down) " .. snippet .. " end"))()
        frame:SetScript(script, function(...) runRestricted(callback, ...) end)
    end
    function newtable(...) return {...} end
    gameBindings, savedBindingSets = {}, {}
    function GetBindingKey(name)
        local keys = {}
        for key, action in pairs(gameBindings) do
            if action == name then keys[#keys + 1] = key end
        end
        return unpack(keys)
    end
    function SetBindingClick(key, name, button)
        assert(not combat and gameBindings[key] == "Open Emote Panel")
        gameBindings[key] = "CLICK " .. name .. ":" .. button
        return true
    end
    function GetCurrentBindingSet() return 2 end
    function SaveBindings(set) table.insert(savedBindingSets, set) end
    function SecureCmdOptionParse(condition)
        assert(restricted and condition == "[combat] 1; 0")
        return combat and "1" or "0"
    end
    C_GamePad = {
        StickIndexToConfigName = function(index) return ({[0] = "Movement", [1] = "Camera"})[index] end,
        GetDeviceMappedState = function() return gamepadState end,
        IsEnabled = function() return gamepadEnabled == true end,
        GetAllDeviceIDs = function() return gamepadDevices or {} end,
    }
    GetGamePadState = C_GamePad.GetDeviceMappedState
    combatRuns = {}
    function CreateFrame(kind, name, parent, template)
        local frame = baseCreateFrame(kind, name, parent, template)
        if name then _G[name] = frame end
        frame.GetName = function() return name end
        frame.GetPoint = function(self) return unpack(self.point or {}) end
        frame.GetSize = function(self) return self:GetWidth(), self:GetHeight() end
        frame.SetHitRectInsets = function(self, ...) self.hitInsets = {...} end
        frame.RegisterForClicks = function(self, ...)
            assert(kind == "Button")
            self.registeredClicks = {...}
        end
        frame.UnregisterEvent = function(self, event) self.events[event] = nil end
        frame.EnableGamePadButton = function(self, enabled)
            assert(not combat)
            self.gamepad = enabled
        end
        frame.EnableGamePadStick = function(self, enabled)
            assert(not combat)
            self.stick = enabled
        end
        frame.SetPropagateKeyboardInput = function(self, propagate)
            assert(not combat)
            self.propagate = propagate
        end
        frame.GetCenter = function() return 230, 250 end
        frame.Click = function(self, button) self.scripts.OnClick(self, button) end
        if kind == "Cooldown" then
            frame.SetDrawSwipe = function(self, value) self.drawSwipe = value end
            frame.SetDrawEdge = function(self, value) self.drawEdge = value end
            frame.SetDrawBling = function(self, value) self.drawBling = value end
            frame.SetHideCountdownNumbers = function(self, value) self.hideNumbers = value end
            frame.SetCooldown = function(self, startTime, duration)
                self.timer = {startTime, duration}
            end
            frame.SetCooldownFromDurationObject = function(self, duration, clearIfZero)
                assert(clearIfZero and not issecretvalue(duration))
                self.timer = duration
            end
            frame.Clear = function(self) self.timer = nil end
        end
        if template and template:find("SecureActionButtonTemplate", 1, true) then
            assert(not combat and parent == UIParent)
            frame.attributes = {}
            frame.SetAttribute = function(self, name, value)
                assert(not combat or restricted, "Insecure action attribute write during combat")
                self.attributes[name] = value
            end
            frame.GetAttribute = function(self, name) return self.attributes[name] end
            frame.RunAttribute = function(self, name, ...)
                assert(restricted)
                local args = {}
                for index = 1, select("#", ...) do
                    local value = select(index, ...)
                    local kind = type(value)
                    if not issecretvalue(value) and (kind == "string" or kind == "number" or kind == "boolean") then
                        args[index] = value
                    end
                end
                return assert(loadstring("return function(self, ...) " .. self.attributes[name] .. " end"))()(
                    self, unpack(args, 1, select("#", ...)))
            end
            frame.CallMethod = function(self, name, ...)
                assert(restricted)
                restricted = false
                self[name](self, ...)
                restricted = true
            end
            frame.GetMousePosition = function() return secureMouseX, secureMouseY end
            frame.SetBindingClick = function(self, priority, key, target, button)
                assert(priority and target == name and (not combat or restricted))
                self.bindings[key] = button
            end
            frame.ClearBindings = function(self)
                assert(not combat or restricted)
                self.bindings = {}
            end
            local show, hide = frame.Show, frame.Hide
            frame.Show = function(self) assert(not combat or restricted); show(self) end
            frame.Hide = function(self) assert(not combat or restricted); hide(self) end
            frame:ClearBindings()
            for _, event in ipairs({"OnShow", "OnHide"}) do
                frame:SetScript(event, function(self)
                    local snippet = self.attributes["_" .. event:lower()]
                    if snippet then assert(loadstring("return function(self) " .. snippet .. " end"))()(self) end
                end)
            end
            frame.Click = function(self, button, down)
                if self.scripts.PreClick then self.scripts.PreClick(self, button, down) end
                if not down and combat and self.attributes.type then
                    assert(name == "EmotePanelCombatInput" and self:IsShown())
                    local kind = self.attributes.type
                    assert(kind == "spell" or kind == "item" or kind == "macro")
                    table.insert(combatRuns, {kind, self.attributes[kind == "macro" and "macrotext" or kind], button})
                elseif not down and self.attributes.type == "macro" then
                    local index = self.attributes.macro
                    local macro = GetMacroInfo(index)
                    assert(macro and self:IsShown() and not combat)
                    table.insert(macroRuns, { index, macro })
                elseif not down and self.attributes.type == "click" then
                    assert(self:IsShown() and self.attributes.useOnKeyDown == false and not combat)
                    self.attributes.clickbutton:Click(button)
                elseif not down and (self.attributes.type == "spell" or self.attributes.type == "item") then
                    assert(self:IsShown() and not combat)
                    local kind = self.attributes.type
                    table.insert(directRuns, {kind, self.attributes[kind], button})
                end
                if self.scripts.PostClick then self.scripts.PostClick(self, button, down) end
            end
        end
        frame.IsVisible = frame.IsShown
        frame.SetUserPlaced = function() end
        assert(template ~= "UIPanelDialogTemplate" and template ~= "UIPanelButtonTemplate")
        if template == "InputBoxScriptTemplate" and name then
            assert(name == "EmotePanelPositionX" or name == "EmotePanelPositionY")
        end
        assert(template ~= "UIPanelCloseButton")
        frame.template = template
        if template == "ScrollFrameTemplate" then
            frame.ScrollBar = Widget()
            frame:SetHeight(160)
            frame.GetVerticalScrollRange = function(self)
                return math.max(0, self.child:GetHeight() - self:GetHeight())
            end
        end
        return frame
    end

    UISpecialFrames = {}
    GameMenuEscPriority = { AddOn = 8 }
    function RegisterGameMenuEscHandler()
        error("The wheel must stay out of Blizzard's Escape handler list")
    end
    function CloseSpecialWindows()
        local closed = false
        for _, name in ipairs(UISpecialFrames) do
            local frame = _G[name]
            if frame and frame:IsShown() then
                frame:Hide()
                closed = true
            end
        end
        return closed
    end
    menuBindings = { PADBACK = "TOGGLEGAMEMENU", ESCAPE = "TOGGLEGAMEMENU" }
    function GetBindingFromClick(key) return menuBindings[key] end
    StaticPopupDialogs = {}
    SlashCmdList = {}
    InputUtil = {
        IsGamepadUIEnabled = function() return nativeGamepadUI == true end,
        GetCursorPosition = function(frame)
            local scale = frame:GetEffectiveScale()
            return cursorX / scale, cursorY / scale
        end,
    }
    C_AddOns = {
        IsAddOnLoaded = function(name)
            assert(name == "ConsolePort")
            return consolePortLoaded or consolePortLoading or false, consolePortLoaded == true
        end,
        GetAddOnMetadata = function(name, field)
            assert(name == "EmotePanel" and field == "Version")
            return addonVersion
        end,
    }
    function IsUsingGamepad() return usingGamepad == true end
    combat = true
    function InCombatLockdown() return combat end
    function IsModifierKeyDown() return modified end
    function wipe(t) for key in pairs(t) do t[key] = nil end end
    function StaticPopup_Show(name, text, _, data)
        popup, popupText, popupData = name, text, data
        return true
    end
    function StaticPopup_Visible(name) return popup == name end
    function StaticPopup_Hide(name) if popup == name then popup = nil end end
    GameTooltip = Widget()
    function GameTooltip:SetOwner(owner) self.owner = owner end
    function GameTooltip:IsOwned(owner) return self:IsShown() and self.owner == owner end
    function GameTooltip:AddLine() end
    function GetCursorPosition() return cursorX, cursorY end
    function CreateFromMixins(mixin)
        local object = {}
        for name, value in pairs(mixin) do object[name] = value end
        return object
    end
    IconDataProviderExtraType = { None = 1 }
    IconDataProviderMixin = {
        Init = function(self, kind)
            assert(kind == IconDataProviderExtraType.None)
            self.ready = true
        end,
        GetNumIcons = function(self) assert(self.ready); return 43 end,
        GetIconByIndex = function(self, index) assert(self.ready); return 130000 + index end,
        GetIndexOfIcon = function(self, icon)
            assert(self.ready)
            if type(icon) == "number" and icon >= 130001 and icon <= 130043 then return icon - 130000 end
        end,
        Release = function(self) self.ready = false; iconProviderReleased = true end,
    }
    C_Texture = {
        GetAtlasInfo = function(atlas)
            if atlas == "gamepad-radial-menu-wheelbg" then return { width = 525, height = 525 } end
            if atlas == "gamepad-radial-menu-selected" then return { width = 177, height = 168 } end
            for _, prefix in ipairs(availableGlyphFamilies or {}) do
                if atlas:sub(1, #prefix) == prefix then return { width = 32, height = 32 } end
            end
        end,
    }
    glyphStyle = "Letters"
    InputIconTextureSetUtility = {
        GetActiveInputIconButtonTextures = function() return glyphStyle end,
        GetNormalActiveInputIconButtonTexture = function(key) return glyphStyle .. "-" .. key end,
    }
    InputDeviceIconSetManager = {
        RegisterActiveInputDeviceIconSetUpdatedCallback = function(_, refresh, owner)
            RefreshGlyphs = function() refresh(owner) end
        end,
    }
    function CreateAtlasMarkup(atlas, width, height)
        assert(width == height and (width == 16 or width == 18 or width == 20 or width == 32))
        return "<" .. atlas .. ">"
    end
    SLASH_COUNTDOWN1 = "/countdown"
    SLASH_TARGET_MARKER1 = "/targetmarker"
    SLASH_DISMOUNT1 = "/dismount"
    learnedSkills = {}
    function GetProfessions() return unpack(learnedSkills, 1, 7) end
    local skillInfo = {
        [1] = {"Mining", 130101, 100, 150, 1, 10, 186},
        [2] = {"Engineering", 130102, 95, 150, 1, 20, 202},
        [4] = {"Fishing", 130104, 42, 75, 1, 40, 356},
        [5] = {"Cooking", 130105, 80, 150, 2, 50, 185},
        [7] = {"First Aid", 130107, 64, 75, 1, 70, 129},
    }
    function GetProfessionInfo(index) return unpack(skillInfo[index]) end
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, Flyout = 2 }, BagIndex = { Backpack = 0 } }
    mockSpellBook = {}
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #mockSpellBook} end,
        GetSpellBookItemInfo = function(index, bank)
            assert(bank == Enum.SpellBookSpellBank.Player)
            return mockSpellBook[index] or { spellID = index }
        end,
    }
    C_TradeSkillUI = {
        CanTradeSkillShowCraftingUI = function(spellID)
            return spellID == 21 or spellID == 52 or spellID == 71
        end,
        GetBaseProfessionInfo = function() return currentProfession end,
        OpenTradeSkill = function(skillLine)
            if expectMouseCraft then
                assert(EmotePanel.frame:IsShown() and professionLoads == expectedProfessionLoads)
            end
            tradeOpenCalls = (tradeOpenCalls or 0) + 1
            openedProfession = skillLine
            return craftOpens
        end,
    }
    professionLoads = 0
    function ProfessionsFrame_LoadUI()
        professionLoads = professionLoads + 1
        return true
    end
    function OpenProfessionUIToSkillLine(skillLine) reopenedProfession = skillLine end
    ProfessionsFrame = { SelectBookPage = function() selectedProfessionOverview = true end }
    function ShowUIPanel(panel)
        assert(panel == ProfessionsFrame)
        shownProfessionOverview = true
    end
    local function RecordPanel(name, arg)
        assert(EmotePanel.frame:IsShown() == (expectWheelOpen == true))
        openedPanel, openedPanelArg = name, arg
    end
    function TapWheelButton(panel, key)
        local frame = panel.gamepadInput
        local proxy = panel.secureWheelInput
        local binding = proxy and proxy.bindings[key]
        assert(frame.scripts.OnGamePadButtonDown(frame, key) == (binding ~= nil))
        if binding then
            assert(frame.propagate, "Controller down must propagate to the secure binding")
            local runs, previousPanel = #macroRuns, openedPanel
            proxy:Click(binding, true)
            assert(#macroRuns == runs and openedPanel == previousPanel)
        end
        assert(frame.scripts.OnGamePadButtonUp(frame, key) == (binding ~= nil))
        if binding then
            assert(frame.propagate, "Controller up must propagate to the secure binding")
            proxy:Click(binding, false)
            assert(not frame.propagate)
        end
    end
    function ToggleCharacter() error("The wheel must not open Character Info from addon Lua") end
    CharacterMicroButton = {
        Click = function(self, button)
            assert(self == CharacterMicroButton and (button == "LeftButton" or button == "WheelActivate"))
            openedPanel, openedPanelArg = "Character Info", "PaperDollFrame"
        end,
    }
    function RegisterStateDriver(frame, state, condition)
        assert(state == "combat" and condition == "[combat] combat; peace")
        local callback = assert(loadstring("return function(self, newstate) " .. frame.attributes["_onstate-combat"] .. " end"))()
        frame.combatChanged = function(...) runRestricted(callback, ...) end
        frame:combatChanged(combat and "combat" or "peace")
    end
    PlayerSpellsUtil = {
        ToggleSpellBookFrame = function() RecordPanel("Spellbook") end,
        ToggleClassTalentOrSpecFrame = function() RecordPanel("Talents") end,
    }
    function ToggleLegacySystemUI() RecordPanel("Legacy") end
    function ToggleQuestLog() RecordPanel("Quest Log") end
    function ToggleGuildFrame() RecordPanel("Guilds & Communities") end
    function ToggleGroupFinderFrame() RecordPanel("Group Finder") end
    COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS = 1
    COLLECTIONS_JOURNAL_TAB_INDEX_PETS = 2
    COLLECTIONS_JOURNAL_TAB_INDEX_TOYS = 3
    function ToggleCollectionsJournal(tab) RecordPanel("Account Collections", tab) end
    function ToggleCalendar() RecordPanel("Calendar") end
    FRIEND_TAB_FRIENDS = 1
    function ToggleFriendsFrame(tab) RecordPanel("Friends", tab) end
    function ToggleAllBags() RecordPanel("Inventory") end
    function ToggleWorldMap() RecordPanel("World Map") end
    nativeActions = {}
    local function RecordNative(name, ...)
        table.insert(nativeActions, {name, ...})
    end
    humanTarget, targetName, groupLeader = true, "Player-Realm", true
    function UnitIsHumanPlayer(unit) assert(unit == "target"); return humanTarget end
    function GetUnitName(unit, full) assert(unit == "target" and full); return targetName end
    function UnitIsGroupLeader(unit) assert(unit == "player"); return groupLeader end
    function UnitIsGroupAssistant(unit) assert(unit == "player"); return groupAssistant end
    C_PartyInfo = {
        InviteUnit = function(name) RecordNative("invite", name) end,
        DoCountdown = function(seconds) RecordNative("countdown", seconds) end,
        DoReadyCheck = function() RecordNative("readycheck") end,
        LeaveParty = function(category)
            assert(inGroup)
            RecordNative("leaveGroup", category)
        end,
    }
    Enum.GameRule = { IngameWhoListDisabled = 1, IngameFriendsListDisabled = 2 }
    Enum.SocialWhoOrigin = { Chat = 1 }
    Kiosk = { IsEnabled = function() return false end }
    C_GameRules = { IsGameRuleActive = function(rule) return rule == disabledRule end }
    C_FriendList = {
        IsLegacyFriendSystemEnabled = function() return true end,
        AddFriend = function(name) RecordNative("friend", name) end,
        SendWho = function(query, origin) RecordNative("who", query, origin) end,
    }
    function WhoFrame_GetDefaultWhoCommand() return "z-Stormwind 12-18" end
    function ShowWhoPanel() whoShown = true end
    WhoFrameEditBox = { SetText = function(_, query) assert(whoShown); whoText = query end }
    function ToggleFriendsPanel() RecordNative("friends") end
    function InspectUnit(unit) RecordNative("inspect", unit) end
    function InitiateTrade(unit) RecordNative("trade", unit) end
    function FollowUnit(name, exact) RecordNative("follow", name, exact) end
    function RandomRoll(low, high) RecordNative("roll", low, high) end
    inGroup = true
    LE_PARTY_CATEGORY_INSTANCE = 2
    function IsInGroup(category)
        if category == LE_PARTY_CATEGORY_INSTANCE then return inInstanceGroup end
        return inGroup
    end
    function ConfirmOrLeaveParty() RecordNative("confirmLeaveInstance") end
    function ToggleChannelFrame() RecordNative("channels") end
    function GetRaidTargetIndex(unit) assert(unit == "target"); return currentMarker end
    function SetRaidTarget(unit, marker) RecordNative("marker", unit, marker) end
    function Dismount() RecordNative("dismount") end
    local nextCategory = 20
    settingsSubcategories = {}
    local function Category()
        nextCategory = nextCategory + 1
        local id = nextCategory
        return { GetID = function() return id end }
    end
    Settings = {
        RegisterCanvasLayoutCategory = Category,
        RegisterCanvasLayoutSubcategory = function(_, _, name)
            local category = Category()
            settingsSubcategories[name] = category:GetID()
            return category
        end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function(id, section) openedCategory, openedSection = id, section end,
    }
    EmoteList = {
        "WAVE", "BOW", "DANCE", "APPLAUD", "BEG", "CHICKEN", "CRY", "EAT", "FLEX", "KISS", "LAUGH",
        "POINT", "ROAR", "RUDE", "SALUTE", "SHY", "TALK", "STAND", "SIT", "SLEEP", "KNEEL", "LEAN",
    }
    TextEmoteSpeechList = {
        "HELPME", "INCOMING", "CHARGE", "FLEE", "ATTACKMYTARGET", "OOM", "FOLLOW", "WAIT", "HEALME",
        "CHEER", "OPENFIRE", "RASP", "HELLO", "BYE", "NOD", "NO", "THANK", "WELCOME", "CONGRATULATE",
        "FLIRT", "JOKE", "TRAIN", "FORTHEALLIANCE",
    }
    MAXEMOTEINDEX = 3
    EMOTE1_TOKEN, EMOTE1_CMD1 = "ATTACKMYTARGET", "/attacktarget"
    EMOTE2_TOKEN, EMOTE2_CMD1 = "FOLLOW", "/followme"
    EMOTE3_TOKEN, EMOTE3_CMD1 = "JOKE", "/silly"
    faction = "Alliance"
    function UnitFactionGroup(unit) assert(unit == "player"); return faction end
    hash_EmoteTokenList = { ["/BRAVO"] = "APPLAUD", ["/WAVE"] = "WAVE", ["/CHEER"] = "CHEER" }
    actions = {}
    C_ChatInfo = {
        PerformEmote = function(token, ...)
            assert(select("#", ...) == 0, "Emotes should use the client's default target")
            if denyEmote then return true end
            table.insert(actions, {token})
            return false
        end,
        InChatMessagingLockdown = function() return denyEmote == true end,
        SendChatMessage = function(message, channel)
            table.insert(actions, {message, channel})
        end,
    }
    secretDraft = {}
    function issecretvalue(value) return value == secretDraft end
    commandCount = 0
    reloadCount = 0
    function ReloadUI()
        assert(EmotePanel.frame:IsShown() and draft == nil)
        reloadSelection = EmotePanel.selected
        reloadCount = reloadCount + 1
    end
    local commandBox = {
        GetText = function() return draft or "" end,
        SetText = function(_, text) draft = text end,
        SendMessage = function()
            assert(type(draft) == "string" and draft:sub(1, 1) == "/")
            command = draft
            draft = nil
            commandCount = commandCount + 1
        end,
    }
    ChatFrameUtil = {
        GetActiveWindow = function()
            return { HasFocus = function() return chatFocused end }
        end,
        ChooseBoxForSend = function() return commandBox end,
        OpenChat = function() error("Selecting a command should submit it directly") end,
    }
    EmotePanelSavedVars = {
        scrollBarStyle = true,
        customIcons = { panels = { [7] = 4630421 } },
        customMessages = {
            chat = {"Saved say", [9] = "Saved ninth"},
            party = {"Saved party"},
            commands = {"/roll 20"},
        },
        customButtonNames = { chat = {"Greeting", [9] = "Ninth"} },
        positions = { emotePanel = { point = "CENTER", relativePoint = "CENTER", x = 40, y = -25 } },
    }
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "Other")
    assert(not EmotePanel.frame)
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    local frame = panel.frame
    assert(not frame:IsShown() and not panel.gamepadInput and events.events.PLAYER_REGEN_ENABLED)
    assert(frame.point[4] == 40 and frame.point[5] == -25)
    assert(not CloseSpecialWindows())
    EmotePanel_Toggle()
    assert(CloseSpecialWindows() and not frame:IsShown())
    assert(not CloseSpecialWindows())
    combat = false
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
    local input = panel.gamepadInput
    assert(input.gamepad and input.stick)

    local function down(key) return input.scripts.OnGamePadButtonDown(input, key) end
    local function up(key) return input.scripts.OnGamePadButtonUp(input, key) end
    local function tap(key) TapWheelButton(panel, key) end
    local function goToEmotes()
        repeat tap("PADDRIGHT") until not panel.titleText:GetText():find("^Favorites")
        assert(panel.titleText:GetText() == "Game Panels  1 / 2")
        tap("PADDRIGHT")
        assert(panel.titleText:GetText() == "Game Panels  2 / 2")
        tap("PADDRIGHT")
        assert(panel.titleText:GetText() == "Emotes  1 / 4")
    end

    EmotePanel_Toggle()
    assert(frame:IsShown() and panel.titleText:GetText() == "Favorites")
    assert(panel.selectionName:GetText() == "Sit" and #EmotePanelSavedVars.favorites == 1)
    assert(panel.messagePreview:GetText() == "/sit")
    assert(panel.slots[1].icon.path:find("INV_FISHINGCHAIR", 1, true))
    local originalPrint, emoteMessages = print, {}
    print = function(message) emoteMessages[#emoteMessages + 1] = message end
    tap("PAD1")
    print = originalPrint
    assert(actions[1][1] == "SIT" and not frame:IsShown() and #emoteMessages == 0)
    table.remove(actions, 1)
    EmotePanelSavedVars.closePanelAfterAction = false
    EmotePanel_Toggle()
    tap("PAD4")
    local sitEditor = panel.customMessageDialog
    assert(sitEditor:IsShown() and not sitEditor.nameBox:IsShown() and not sitEditor.messageBox:IsShown())
    function AssertEditorPromptClear(dialog)
        local hint
        for _, widget in ipairs(widgets) do
            if (widget:GetText() or ""):find(" Choose Icon    ", 1, true) then hint = widget end
        end
        local iconBottom = -dialog.iconButton.point[3] + dialog.iconButton:GetHeight()
        local promptTop = dialog:GetHeight() - hint.point[3] - 32
        assert(promptTop - iconBottom >= 10)
    end
    AssertEditorPromptClear(sitEditor)
    tap("PAD4")
    local picker = sitEditor.picker
    assert(picker:IsShown() and not picker.library)
    local cursor, preview, assignedTile
    for _, widget in ipairs(widgets) do
        if widget.parent == picker then
            if widget.backdrop and widget.backdrop.edgeSize == 5 then cursor = widget end
            if widget.path == sitEditor.defaultIcon and widget:GetWidth() == 46 then preview = widget end
            if widget.value == sitEditor.defaultIcon then assignedTile = widget end
        end
    end
    assert(cursor and preview and assignedTile)
    assert(cursor.points.TOPLEFT[2] == assignedTile and assignedTile.current:IsShown())
    tap("PADDRIGHT")
    assert(cursor.points.TOPLEFT[2] ~= assignedTile and preview.path ~= sitEditor.defaultIcon)
    assert(assignedTile.current:IsShown())
    tap("PAD4")
    assert(picker.library)
    tap("PADRSHOULDER")
    tap("PADDRIGHT")
    tap("PAD1")
    assert(iconProviderReleased and not picker:IsShown() and sitEditor.pendingIcon == 130042)
    assert(panel.slots[1].icon.path:find("INV_FISHINGCHAIR", 1, true))
    tap("PAD1")
    assert(not sitEditor:IsShown() and panel.slots[1].icon.path == 130042)
    assert(EmotePanelSavedVars.customIcons.emotes[30] == 130042)
    tap("PAD4")
    tap("PAD4")
    tap("PAD4")
    assert(picker.library and picker.page == 2 and picker.selected == 2 and preview.path == 130042)
    tap("PAD4")
    for _, widget in ipairs(widgets) do
        if widget.parent == picker and widget:GetText() == "Default" then
            widget:Click("LeftButton")
            break
        end
    end
    assert(sitEditor.pendingIcon == sitEditor.defaultIcon and not picker:IsShown())
    tap("PAD2")
    assert(EmotePanelSavedVars.customIcons.emotes[30] == 130042)
    tap("PAD3")
    assert(not panel.highlight:IsShown() and panel.selectionName:GetText() == "No favorites")
    assert(panel.messagePreview:GetText() == "")
    assert(panel.gamepadHint:GetText():find("<Letters%-PAD3>"))
    tap("PAD1")
    tap("PAD3")
    tap("PADDDOWN")
    assert(not panel.selected and #actions == 0 and #EmotePanelSavedVars.favorites == 0)
    tap("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Professions" and panel.selectionName:GetText() == "No learned professions")
    assert(not panel.slots[1]:IsShown() and not panel.highlight:IsShown())
    tap("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Commands  3 / 3")
    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Professions")
    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Favorites")
    goToEmotes()
    assert(frame:IsShown() and panel.titleText:GetText() == "Emotes  1 / 4")
    local wheel = panel.wheel
    local hint = panel.gamepadHint
    local navigationAnchor, actionAnchor = panel.navigationHint.point, hint.point
    assert(navigationAnchor[1] == "CENTER" and actionAnchor[1] == "CENTER")
    assert(navigationAnchor[2] == actionAnchor[2] and navigationAnchor[2].atlas == "gamepad-radial-menu-bottomtext")
    assert(navigationAnchor[3] == "CENTER" and actionAnchor[3] == "CENTER")
    assert(navigationAnchor[4] == 0 and actionAnchor[4] == 0)
    assert(navigationAnchor[5] == 18.5 and actionAnchor[5] == -18.5)
    assert(panel.navigationHint:GetText():find("<Letters%-PADLSTICKAXIS>"))
    assert(panel.navigationHint:GetText():find("<Letters%-PADRSTICKAXIS>"))
    assert(panel.navigationHint:GetText():find("<Letters%-DIRPADVERTICAL> Select"))
    assert(panel.navigationHint:GetText():find("<Letters%-PADLSHOULDER>"))
    assert(panel.navigationHint:GetText():find("<Letters%-PADRSHOULDER> Page"))
    assert(hint:GetText():find("<Letters%-PAD1> Use"))
    assert(hint:GetText():find("Edit"))
    assert(panel.messagePreview.point[2] == navigationAnchor[2] and panel.messagePreview.point[3] == "BOTTOM")
    assert(panel.messagePreview.wordWrap and panel.messagePreview.nonSpaceWrap)
    glyphStyle = "Shapes"
    RefreshGlyphs()
    assert(hint:GetText():find("<Shapes%-PAD2> Close"))
    glyphStyle = nil
    RefreshGlyphs()
    assert(hint:GetText():find("A Use"))
    glyphStyle = "Shapes"
    assert(panel.selected == 1 and panel.selectionName:GetText() == "Angry")
    assert(panel.selectionName.point[1] == "TOP" and panel.selectionName.point[3] == -421)
    assert(not panel.selectionCaption and not panel.selectionIndex)
    assert(panel.slots[1].icon.path:find("Spell_Misc_EmotionAngry", 1, true))
    assert(panel.slots[1].icon.mask.atlas == "CircleMask")
    assert(panel.slots[1].border.atlas == "gamepad-actionbar-circleslot-border-selected")
    assert(panel.wheelArt.atlas == "gamepad-radial-menu-wheelbg" and #panel.slots == 8)
    assert(panel.highlight.atlas == "gamepad-radial-menu-selected")
    local foundAtlases = {}
    for _, widget in ipairs(widgets) do
        if widget.parent == frame and (widget.atlas or widget.normalAtlas) then
            foundAtlases[widget.atlas or widget.normalAtlas] = true
            assert(widget.atlas ~= "gamepad-footer-slot-bg" and widget.atlas ~= "gamepad-footer-slot-frameneutral")
        end
    end
    assert(foundAtlases["gamepad-radial-menu-toptext"] and foundAtlases["gamepad-radial-menu-bottomtext"])
    assert(foundAtlases["128-redbutton-exit"] and foundAtlases["common-icon-backarrow"])
    assert(panel.slots[1].point[4] == 0 and panel.slots[1].point[5] > 0)
    tap("PADDUP")
    assert(panel.selected == 8)
    tap("PADDDOWN")
    assert(panel.selected == 1)
    assert(up("PAD1") == true and #actions == 0)
    modified = true
    assert(down("PAD1") == true)
    modified = false

    local function stick(side, x, y) return input.scripts.OnGamePadStick(input, side, x, y) end
    assert(stick("Movement", 1, 0) == false and panel.selected == 3)
    assert(stick("Movement", 0, 0) == true and panel.selected == 3)
    assert(stick("Left", 0, 1) == false and panel.selected == 1)
    assert(stick("Other", 1, 0) == true and panel.selected == 1)
    assert(stick("Camera", 0.1, 0.1) == false and panel.selected == 1)
    local step = math.pi / 4
    for index = 1, 8 do
        local angle = (index - 1) * step
        assert(stick("Movement", math.sin(angle), math.cos(angle)) == false and panel.selected == index)
    end
    for index = 1, 8 do
        local angle = (index - 1) * step
        assert(stick("Camera", math.sin(angle), math.cos(angle)) == false and panel.selected == index)
    end
    assert(stick("Camera", math.sin(step), math.cos(step)) == false and panel.selected == 2)
    assert(stick("Camera", 0, 0) == false and panel.selected == 2 and #actions == 0)
    assert(math.abs(panel.highlight.rotation - (math.pi - step)) < 1e-8)
    assert(panel.slots[1].border.atlas == "gamepad-actionbar-circleslot-border-normal")
    assert(panel.slots[2].border.atlas == "gamepad-actionbar-circleslot-border-selected")
    tap("PAD1")
    assert(actions[1][1] == "APPLAUD")

    local function setCursor(angle, radius)
        local x, y = wheel:GetCenter()
        cursorX = x + math.sin(angle) * radius
        cursorY = y + math.cos(angle) * radius
    end
    local function releaseMouse(button)
        wheel.scripts.OnMouseUp(wheel, button)
        if button == "LeftButton" then
            assert(wheel.registeredClicks[1] == "LeftButtonUp" and #wheel.registeredClicks == 1)
            wheel:Click(button)
        end
    end
    local function mouse(button)
        wheel.scripts.OnMouseDown(wheel, button)
        releaseMouse(button)
    end
    setCursor(0, 0)
    wheel.scripts.OnEnter(wheel)
    mouse("LeftButton")
    setCursor(0, 190)
    mouse("LeftButton")
    setCursor(0, 136)
    releaseMouse("LeftButton")
    assert(#actions == 1)
    wheel.scripts.OnMouseDown(wheel, "LeftButton")
    setCursor(step, 136)
    releaseMouse("LeftButton")
    assert(#actions == 1)
    setCursor(6 * step, 136)
    wheel.scripts.OnUpdate(wheel)
    assert(panel.selected == 7 and GameTooltip:IsOwned(wheel))
    mouse("LeftButton")
    assert(actions[2][1] == "DANCE")
    wheel.scripts.OnLeave(wheel)
    assert(not wheel.scripts.OnUpdate and not GameTooltip:IsOwned(wheel))

    local firstSlot = panel.slots[1]
    tap("PADDRIGHT")
    assert(panel.selectionName:GetText() == "Flex")
    tap("PADDRIGHT")
    tap("PADDRIGHT")
    assert(panel.titleText:GetText() == "Emotes  4 / 4" and not panel.slots[8]:IsShown())
    assert(panel.selectionName:GetText() == "Sit")
    for index = 1, 7 do
        local angle = (index - 1) * step
        assert(stick("Right", math.sin(angle), math.cos(angle)) == false and panel.selected == index)
    end
    assert(stick("Right", -1, 0) == false and panel.selected == 7)
    tap("PADDRIGHT")
    assert(panel.titleText:GetText() == "Voiced Emotes  1 / 3" and panel.selectionName:GetText() == "Cheer")
    tap("PADDRIGHT")
    tap("PADDRIGHT")
    assert(panel.titleText:GetText() == "Voiced Emotes  3 / 3")
    tap("PADDRIGHT")
    assert(panel.selected == 1 and panel.slots[1] == firstSlot)
    assert(panel.selectionName:GetText() == "Greeting" and panel.slots[8]:IsShown())
    assert(panel.messagePreview:GetText() == "Saved say")
    assert(panel.slots[1].icon.path:find("Spell_Misc_EmotionHappy", 1, true))
    assert(hint:GetText():find("<Shapes%-PAD4> Edit"))
    tap("PAD1")
    assert(actions[3][1] == "Saved say" and actions[3][2] == "SAY")

    tap("PADDRIGHT")
    assert(panel.titleText:GetText() == "Say Chat  2 / 2")
    assert(panel.selectionName:GetText() == "Ninth" and not panel.slots[3]:IsShown())
    setCursor(2 * step, 136)
    mouse("LeftButton")
    assert(#actions == 3)
    tap("PAD1")
    assert(actions[4][1] == "Saved ninth" and actions[4][2] == "SAY")
    tap("PAD4")
    local overflowDialog = panel.customMessageDialog
    assert(overflowDialog.messageBox:GetText() == "Saved ninth")
    overflowDialog.messageBox:SetText("Updated ninth | test")
    tap("PAD4")
    overflowDialog.picker:MoveSelection(2 - overflowDialog.picker.selected)
    tap("PAD1")
    overflowDialog.saveButton:Click("LeftButton")
    assert(EmotePanelSavedVars.customMessages.chat[9] == "Updated ninth | test")
    assert(panel.messagePreview:GetText() == "Updated ninth || test")
    assert(panel.slots[1].icon.path:find("Spell_Holy_DivineHymn", 1, true))
    assert(EmotePanelSavedVars.customMessages.chat[1] == "Saved say")
    tap("PADDLEFT")

    tap("PAD4")
    local dialog = panel.customMessageDialog
    assert(dialog:IsShown() and #actions == 4)
    dialog.nameBox:SetFocus()
    assert(down("PAD1") == true and down("PAD4") == true)
    assert(stick("Camera", 1, 0) == true and stick("Movement", 1, 0) == true)
    dialog.nameBox:ClearFocus()
    dialog.nameBox:SetText("Edited")
    dialog.messageBox:SetText("Updated say")
    panel:CycleMode(1)
    panel:CycleMode(1)
    dialog.saveButton:Click("LeftButton")
    assert(EmotePanelSavedVars.customMessages.chat[1] == "Updated say")
    assert(panel.selectionName:GetText() == "Follow Me")
    tap("PAD1")
    assert(actions[5][1] == "Saved party" and actions[5][2] == "PARTY")
    tap("PADDLEFT")
    tap("PADDLEFT")
    setCursor(0, 136)
    mouse("RightButton")
    EmotePanelSavedVars.customIcons.chat[1] = 130001
    dialog.resetButton:Click("LeftButton")
    panel:CycleMode(1)
    StaticPopupDialogs[popup].OnAccept(nil, popupData)
    popup = nil
    assert(not EmotePanelSavedVars.customMessages.chat[1])
    assert(not EmotePanelSavedVars.customIcons.chat[1])
    assert(EmotePanelSavedVars.customMessages.party[1] == "Saved party")

    EmotePanelSavedVars.closePanelAfterAction = true
    tap("PADDRIGHT")
    tap("PADDRIGHT")
    tap("PADDRIGHT")
    chatFocused = true
    tap("PAD1")
    assert(not command and frame:IsShown())
    chatFocused = false
    draft = "unsent text"
    tap("PAD1")
    assert(not command and frame:IsShown() and draft == "unsent text")
    draft = secretDraft
    tap("PAD1")
    assert(not command and frame:IsShown() and draft == secretDraft)
    draft = nil
    tap("PAD1")
    assert(command == "/roll 20" and commandCount == 1 and not frame:IsShown())
    EmotePanel_Toggle()
    tap("PAD2")
    assert(not frame:IsShown())

    EmotePanel_Toggle()
    tap("PADFORWARD")
    assert(not frame:IsShown())
    EmotePanel_Toggle()
    goToEmotes()
    tap("PAD4")
    tap("PAD4")
    assert(dialog.picker:IsShown())
    tap("PADBACK")
    assert(not frame:IsShown() and not dialog:IsShown() and not dialog.picker:IsShown())
    EmotePanel_Toggle()
    goToEmotes()
    tap("PAD4")
    tap("PAD4")
    assert(dialog.picker:IsShown())
    assert(CloseSpecialWindows())
    assert(not frame:IsShown() and not dialog:IsShown() and not dialog.picker:IsShown())
    EmotePanel_Toggle()
    StaticPopup_Show("EMOTEPANEL_RESET_ALL")
    tap("PADFORWARD")
    assert(not frame:IsShown() and not popup)

    EmotePanel_Toggle()
    goToEmotes()
    tap("PAD3")
    assert(panel.slots[1].favorite:IsShown())
    assert(panel.slots[1].favorite.atlas == "collections-icon-favorites")
    assert(hint:GetText():find("Unfavorite"))
    for _ = 1, 7 do tap("PADDRIGHT") end
    setCursor(0, 136)
    mouse("MiddleButton")
    assert(EmotePanelSavedVars.favorites[2].mode == "chat")
    tap("PADDRIGHT")
    tap("PAD3")
    assert(EmotePanelSavedVars.favorites[3].index == 9)
    tap("PADDRIGHT")
    tap("PAD3")
    assert(EmotePanelSavedVars.favorites[4].mode == "party")
    for _ = 1, 3 do tap("PADDRIGHT") end
    assert(panel.titleText:GetText() == "Commands  2 / 3")
    panel:Select(3)
    assert(panel.selectionName:GetText() == "Pull in 5s")
    tap("PAD3")
    panel:Select(5)
    assert(panel.slots[5].icon.path:find("UI-RaidTargetingIcon_8", 1, true))
    tap("PAD1")
    assert(nativeActions[#nativeActions][1] == "marker" and nativeActions[#nativeActions][3] == 8)
    assert(commandCount == 1)
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Favorites" and panel.selectionName:GetText() == "Angry")
    assert(not panel.highlight.desaturated and panel.highlight.color[1] == 1)
    panel:Select(2)
    assert(panel.highlight.desaturated and panel.highlight.color[3] == 1 and panel.highlight.color[2] == 0.84)
    assert(panel.slots[2].border.desaturated and panel.slots[2].border.color[1] == 0.36)
    panel:Select(4)
    assert(panel.highlight.color[2] == 1 and panel.highlight.color[3] == 0.46)
    assert(not panel.slots[2].border.desaturated and panel.slots[2].border.color[1] == 1)
    panel:Select(5)
    assert(panel.highlight.color[1] == 0.82 and panel.highlight.color[3] == 1)
    panel:Select(1)
    assert(not panel.highlight.desaturated and panel.highlight.color[2] == 1)
    assert(not panel.slots[1].favorite:IsShown())
    assert(panel.slots[3].icon.path:find("Spell_Holy_DivineHymn", 1, true))
    assert(panel.slots[4].icon.path:find("Ability_Hunter_Pathfinding", 1, true))
    assert(panel.slots[5].icon.path:find("INV_Misc_PocketWatch_01", 1, true))
    EmotePanelSavedVars.closePanelAfterAction = false
    tap("PAD1")
    assert(actions[#actions][1] == "ANGRY")
    panel:Select(3)
    tap("PAD1")
    assert(actions[#actions][1] == "Updated ninth | test" and actions[#actions][2] == "SAY")
    tap("PAD4")
    assert(dialog.messageBox:GetText() == "Updated ninth | test")
    dialog:Hide()
    panel:Select(5)
    EmotePanelSavedVars.closePanelAfterAction = true
    tap("PAD1")
    assert(nativeActions[#nativeActions][1] == "countdown" and nativeActions[#nativeActions][2] == 5)
    assert(commandCount == 1)

    EmotePanel_Toggle()
    goToEmotes()
    for index = 2, 5 do
        panel:Select(index)
        tap("PAD3")
    end
    assert(#EmotePanelSavedVars.favorites == 9 and panel.titleText:GetText() == "Emotes  1 / 4")
    for _ = 1, 3 do tap("PADDLEFT") end
    assert(panel.titleText:GetText() == "Favorites  2 / 2" and panel.selectionName:GetText() == "Cackle")
    tap("PAD3")
    assert(#EmotePanelSavedVars.favorites == 8 and panel.titleText:GetText() == "Favorites")
    assert(panel.slots[8]:IsShown())

    for _ = 1, 14 do tap("PADDRIGHT") end
    assert(panel.titleText:GetText() == "Commands  1 / 3")
    assert(panel.messagePreview:GetText() == "/roll 20")
    EmotePanelSavedVars.customMessages.commands[1] = "/inv"
    tap("PAD1")
    assert(command == "/inv" and commandCount == 2 and not frame:IsShown())
    EmotePanel_Toggle()
    for _ = 1, 14 do tap("PADDRIGHT") end
    EmotePanelSavedVars.customMessages.commands[1] = "/inv Player"
    tap("PAD1")
    assert(command == "/inv Player" and commandCount == 3 and not frame:IsShown())
    EmotePanel_Toggle()
    for _ = 1, 14 do tap("PADDRIGHT") end
    EmotePanelSavedVars.customMessages.commands[1] = "/targetmarker [@focus] 8"
    tap("PAD1")
    assert(command == "/targetmarker [@focus] 8" and commandCount == 4)
    EmotePanel_Toggle()
    for _ = 1, 14 do tap("PADDRIGHT") end
    EmotePanelSavedVars.customMessages.commands[1] = "/wave"
    local previousActions = #actions
    tap("PAD1")
    assert(command == "/wave" and commandCount == 5 and #actions == previousActions)
    EmotePanelSavedVars.customMessages.commands[1] = "/roll 20"

    EmotePanel_Toggle()
    for _ = 1, 15 do tap("PADDRIGHT") end
    assert(panel.titleText:GetText() == "Commands  2 / 3")
    setCursor(step, 136)
    draft = "unsent text"
    mouse("LeftButton")
    assert(reloadCount == 0 and draft == "unsent text" and frame:IsShown())
    draft = nil
    wheel.scripts.OnMouseDown(wheel, "LeftButton")
    wheel.scripts.OnMouseUp(wheel, "LeftButton")
    assert(reloadCount == 0 and commandCount == 5 and frame:IsShown())
    wheel:Click("LeftButton")
    assert(reloadCount == 1 and reloadSelection == 1 and commandCount == 5 and not frame:IsShown())
    EmotePanel_Toggle()
    for _ = 1, 15 do tap("PADDRIGHT") end
    panel:Select(2)
    assert(panel.messagePreview:GetText() == "Reload the game interface")
    tap("PAD1")
    assert(reloadCount == 2 and reloadSelection == 2 and commandCount == 5 and not frame:IsShown())

    local function activateCommand(index, withMouse)
        EmotePanel_Toggle()
        for _ = 1, index > 8 and 15 or 14 do tap("PADDRIGHT") end
        local sector = (index - 1) % 8 + 1
        panel:Select(sector)
        assert(not panel.messagePreview:GetText():match("^/"))
        if withMouse then
            setCursor((sector - 1) * step, 136)
            mouse("LeftButton")
        else
            tap("PAD1")
        end
        assert(not frame:IsShown() and commandCount == 5)
    end

    EmotePanelSavedVars.customMessages.commands[1] = nil
    local expectedNative = {
        {"invite", "Player-Realm"}, {"inspect", "target"}, {"trade", "target"}, {"follow", ""},
        {"friend", "Player-Realm"}, {"roll", 1, 100}, {"readycheck"}, {"who", "z-Stormwind 12-18", 1},
        {"channels"}, false, {"countdown", 5}, {"countdown", 10},
        {"marker", "target", 8}, {"marker", "target", 7}, {"marker", "target", 0}, {"dismount"},
    }
    for index, expected in ipairs(expectedNative) do
        if expected then
            local count = #nativeActions
            activateCommand(index, index % 2 == 0)
            assert(#nativeActions == count + 1)
            local actual = nativeActions[#nativeActions]
            assert(actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3])
        end
    end
    assert(whoText == "z-Stormwind 12-18")

    local count = #nativeActions
    targetName = secretDraft
    activateCommand(1, true)
    activateCommand(5)
    groupLeader = false
    activateCommand(7)
    currentMarker = 8
    activateCommand(13)
    assert(#nativeActions == count)
    currentMarker = secretDraft
    activateCommand(13, true)
    assert(#nativeActions == count + 1 and nativeActions[#nativeActions][3] == 8)
    currentMarker = nil
    draft = "unsent text"
    activateCommand(6)
    assert(draft == "unsent text" and nativeActions[#nativeActions][1] == "roll")
    draft = nil
    EmotePanelSavedVars.customMessages.commands[1] = "/roll 20"

    local originalPrint, helpLines = print, {}
    print = function(line) table.insert(helpLines, line) end
    SlashCmdList.EMOTEPANEL("help")
    local help = table.concat(helpLines, " ")
    for _, command in ipairs({
        "/ep or /emotepanel", "/ep config", "/ep list", "/ep actions", "/ep categories", "/ep reset",
        "/ep debug -", "/ep debug on", "/ep debug off", "/ep scroll", "/ep help",
    }) do
        assert(help:find(command, 1, true), "Missing help for " .. command)
    end
    assert(help:find("Reorder Favorites", 1, true) and help:find("Open or Close Emote Panel", 1, true))
    helpLines = {}
    SlashCmdList.EMOTEPANEL("scroll off")
    assert(table.concat(helpLines, " "):find("page arrows change pages", 1, true))
    print = originalPrint
    assert(EmotePanelSavedVars.scrollBarStyle)
    SlashCmdList.EMOTEPANEL("config")
    assert(openedCategory == 21)
    SlashCmdList.EMOTEPANEL("list")
    assert(openedCategory == settingsSubcategories.Entries)
    local saved = EmotePanelSavedVars.favorites

    learnedSkills = { [1] = 1, [2] = 2, [4] = 4, [5] = 5, [7] = 7 }
    EmotePanel_Toggle()
    tap("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Professions")
    assert(panel.selectionName:GetText() == "Mining")
    assert(panel.messagePreview:GetText():find("Primary profession") and panel.messagePreview:GetText():find("100 / 150", 1, true))
    assert(panel.slots[1].icon.path == 130101 and panel.slots[5].icon.path == 130107 and not panel.slots[6]:IsShown())
    assert(panel.gamepadHint:GetText():find("Favorite"))
    panel:Select(4)
    assert(panel.selectionName:GetText() == "Cooking")
    assert(panel.messagePreview:GetText():find("Secondary profession") and panel.messagePreview:GetText():find("Open crafting"))
    learnedSkills[1] = nil
    events.scripts.OnEvent(events, "SKILL_LINES_CHANGED")
    assert(panel.selected == 3 and panel.selectionName:GetText() == "Cooking")
    assert(panel.slots[1].icon.path == 130102 and not panel.slots[5]:IsShown())
    tap("PAD4")
    assert(not dialog.nameBox:IsShown() and not dialog.messageBox:IsShown())
    tap("PAD4")
    tap("PAD1")
    tap("PAD1")
    assert(EmotePanelSavedVars.customIcons.professions[185] == panel.slots[3].icon.path)
    tap("PAD3")
    assert(panel.titleText:GetText() == "Professions" and panel.slots[3].favorite:IsShown())
    assert(saved[9].mode == "professions" and saved[9].index == 185)
    craftOpens = true
    tap("PAD1")
    assert(openedProfession == 185 and not frame:IsShown() and not shownProfessionOverview)

    EmotePanel_Toggle()
    tap("PADLSHOULDER")
    panel:Select(3)
    currentProfession = { professionID = 185 }
    tap("PAD1")
    assert(reopenedProfession == 185 and not frame:IsShown())
    currentProfession = nil
    EmotePanel_Toggle()
    tap("PADLSHOULDER")
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Fishing" and panel.messagePreview:GetText():find("Open professions overview"))
    tap("PAD1")
    assert(selectedProfessionOverview and shownProfessionOverview and not frame:IsShown())
    selectedProfessionOverview, shownProfessionOverview = nil, nil
    craftOpens = false
    EmotePanel_Toggle()
    tap("PADLSHOULDER")
    panel:Select(4)
    tap("PAD1")
    assert(openedProfession == 129 and shownProfessionOverview and not frame:IsShown())

    EmotePanel_Toggle()
    tap("PADRSHOULDER")
    assert(panel.selectionName:GetText() == "Cooking")
    assert(panel.slots[1].icon.path == EmotePanelSavedVars.customIcons.professions[185])
    craftOpens, openedProfession = true, nil
    tap("PAD1")
    assert(openedProfession == 185 and not frame:IsShown())

    EmotePanel_Toggle()
    tap("PADLSHOULDER")
    setCursor(2 * step, 136)
    expectMouseCraft, expectedProfessionLoads = true, professionLoads
    openedProfession, shownProfessionOverview = nil, nil
    mouse("LeftButton")
    assert(openedProfession == 185 and not shownProfessionOverview and not frame:IsShown())
    assert(professionLoads == expectedProfessionLoads)
    EmotePanel_Toggle()
    tap("PADRSHOULDER") -- Cooking in Favorites
    setCursor(0, 136)
    craftOpens = false
    local previousTradeOpens = tradeOpenCalls
    mouse("LeftButton")
    assert(tradeOpenCalls == previousTradeOpens + 1 and openedProfession == 185)
    assert(professionLoads == expectedProfessionLoads + 1 and shownProfessionOverview and not frame:IsShown())
    expectMouseCraft = nil

    -- Each shortcut opens on the first press with unbound controls.
    local panelActions = {
        {"Character Info", "PaperDollFrame"}, {"Spellbook"}, {"Talents"}, {"Legacy"},
        {"Quest Log"}, {"Guilds & Communities"}, {"Group Finder"}, {"Account Collections"},
        {"Account Collections", 1, "Mounts"}, {"Account Collections", 2, "Pets"}, {"Account Collections", 3, "Toys"},
        {"Calendar"}, {"Friends", 1}, {"Inventory"}, {"World Map"},
    }
    local panelAtlases = {
        "character", "spellbook", "talents", "legacy", "quests", "communities",
        "groupfinder", "collections", [12] = "calendar", [13] = "social", [14] = "bags",
    }
    local panelIcons = {
        [9] = "INV_Horse3Saddle008_Chestnut", [10] = "INV_ArfusPet_Classic",
        [11] = "INV_SideTab_ToyBox_c60", [15] = "inv_misc_map02",
    }
    for index, expected in ipairs(panelActions) do
        EmotePanel_Toggle()
        tap("PADRSHOULDER") -- Favorites overflow
        assert(panel.selectionName:GetText() == "Cooking")
        tap("PADRSHOULDER") -- Game Panels 1
        if index > 8 then tap("PADRSHOULDER") end
        local sector = (index - 1) % 8 + 1
        if index == 7 then
            assert(panel.slots[sector].icon.path == 4630421)
            EmotePanelSavedVars.customIcons.panels[7] = nil
            panel:RefreshWheel()
        end
        if panelAtlases[index] then
            assert(panel.slots[sector].icon.atlas == "gamepad-radial-icon-" .. panelAtlases[index])
        else
            assert(panel.slots[sector].icon.path:find(panelIcons[index], 1, true))
        end
        if index == 7 then
            EmotePanelSavedVars.customIcons.panels[7] = 4630421
            panel:RefreshWheel()
        end
        panel:Select(sector)
        assert(panel.selectionName:GetText() == (expected[3] or expected[1]))
        assert(panel.messagePreview:GetText() == "Open " .. (expected[3] or expected[1]))
        openedPanel, openedPanelArg = nil, nil
        tap("PAD1")
        assert(openedPanel == expected[1] and openedPanelArg == expected[2])
        assert(not frame:IsShown() and not panel.secureWheelInput:IsShown())
    end

    EmotePanel_Toggle()
    tap("PADRSHOULDER")
    tap("PADRSHOULDER")
    local proxy = assert(panel.secureWheelInput)
    assert(proxy:IsShown() and proxy.bindings.PAD1 == "WheelActivate")
    setCursor(0, 136)
    proxy.scripts.OnMouseDown(proxy, "LeftButton")
    setCursor(2 * step, 136)
    openedPanel = nil
    proxy:Click("LeftButton")
    assert(not openedPanel and frame:IsShown())

    EmotePanelSavedVars.closePanelAfterAction = false
    setCursor(0, 136)
    proxy.scripts.OnMouseDown(proxy, "LeftButton")
    proxy:Click("LeftButton")
    assert(openedPanel == "Character Info" and frame:IsShown())
    assert(not proxy.attributes.type and not proxy.attributes.clickbutton)

    tap("PAD3")
    EmotePanel_Toggle()
    EmotePanel_Toggle()
    tap("PADRSHOULDER")
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Character Info" and proxy:IsShown())
    openedPanel = nil
    tap("PAD1")
    assert(openedPanel == "Character Info" and frame:IsShown())
    tap("PAD3")
    assert(not proxy:IsShown() and not next(proxy.bindings))
    EmotePanelSavedVars.closePanelAfterAction = true

    tap("PADRSHOULDER")
    assert(proxy:IsShown())
    combat = true
    proxy:combatChanged("combat")
    local combatEvent
    for _, widget in ipairs(widgets) do
        if widget.events.PLAYER_REGEN_DISABLED then combatEvent = widget end
    end
    assert(combatEvent)
    combatEvent.scripts.OnEvent(combatEvent, "PLAYER_REGEN_DISABLED")
    assert(panel.slots[1].icon.desaturated and panel.slots[1]:GetAlpha() < 1)
    assert(not panel.slots[2].icon.desaturated and panel.slots[2]:GetAlpha() == 1)
    assert(panel.highlight.desaturated and panel.gamepadHint:GetText():find("Unavailable in combat", 1, true))
    panel:Select(2)
    assert(not panel.gamepadHint:GetText():find("Unavailable in combat", 1, true))
    panel:Select(1)
    assert(not proxy:IsShown() and not next(proxy.bindings))
    openedPanel = nil
    tap("PAD1")
    assert(not openedPanel and not frame:IsShown())
    combat = false
    EmotePanel_Toggle()
    tap("PADRSHOULDER")
    tap("PADRSHOULDER")
    tap("PADRSHOULDER")
    panel:Select(6)
    tap("PAD4")
    assert(not dialog.nameBox:IsShown() and not dialog.messageBox:IsShown())
    assert(dialog.icon.atlas == "gamepad-radial-icon-bags")
    tap("PAD4")
    tap("PAD4")
    tap("PAD1")
    tap("PAD1")
    local bagIcon = panel.slots[6].icon.path
    assert(bagIcon == 130001 and EmotePanelSavedVars.customIcons.panels[14] == bagIcon)
    tap("PAD3")
    assert(saved[10].mode == "panels" and saved[10].index == 14 and panel.slots[6].favorite:IsShown())
    tap("PAD2")
    EmotePanel_Toggle()
    tap("PADRSHOULDER")
    assert(panel.selectionName:GetText() == "Cooking")
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Inventory" and panel.slots[2].icon.path == bagIcon)
    learnedSkills[5] = nil
    events.scripts.OnEvent(events, "SKILL_LINES_CHANGED")
    assert(panel.selected == 1 and panel.selectionName:GetText() == "Inventory" and #saved == 10)
    tap("PAD1")
    assert(openedPanel == "Inventory" and not frame:IsShown())
    table.insert(saved, {mode = "emotes", index = 1})
    table.insert(saved, {mode = "commands", index = 999})
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    EmotePanel_Toggle()
    assert(#EmotePanelSavedVars.favorites == 10 and EmotePanel.titleText:GetText() == "Favorites  1 / 2")
    EmotePanel:Select(3)
    assert(EmotePanel.selectionName:GetText() == "Ninth")
    EmotePanel:Select(5)
    assert(EmotePanel.selectionName:GetText() == "Pull in 5s")
    EmotePanel:CycleMode(1)
    assert(EmotePanel.selectionName:GetText() == "Inventory" and not EmotePanel.slots[2]:IsShown())
    learnedSkills[5] = 5
    events.scripts.OnEvent(events, "SKILL_LINES_CHANGED")
    assert(EmotePanel.selected == 2 and EmotePanel.selectionName:GetText() == "Inventory")
    EmotePanel:Select(1)
    assert(EmotePanel.selectionName:GetText() == "Cooking")
    EmotePanel:ToggleFavorite()
    assert(EmotePanel.selectionName:GetText() == "Inventory" and #EmotePanelSavedVars.favorites == 9)
    EmotePanel:ToggleFavorite()
    assert(EmotePanel.titleText:GetText() == "Favorites" and #EmotePanelSavedVars.favorites == 8)
    EmotePanelSavedVars.sitFavoriteAdded = nil
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    EmotePanel_Toggle()
    assert(EmotePanel.titleText:GetText() == "Favorites  1 / 2")
    assert(#EmotePanelSavedVars.favorites == 9 and EmotePanel.selectionName:GetText() == "Sit")
    assert(EmotePanel.slots[1].icon.path == 130042)
    EmotePanel:Select(2)
    assert(EmotePanel.selectionName:GetText() == "Angry")

    local panel = EmotePanel
    local settings = EmotePanelHelpPanel
    local function FindOption(label, parent)
        for _, widget in ipairs(widgets) do
            if widget:GetText() == label and widget.point[2].parent == parent then
                return widget.point[2]
            end
        end
        error("Option missing: " .. label)
    end
    local closeCheck = FindOption("Close panel after action", panel.optionsPanel)
    local categoryCheck = FindOption("Open on Category Wheel", EmotePanelCategoriesPanel)
    assert(closeCheck and closeCheck:GetChecked())
    assert(not categoryCheck:GetChecked())
    closeCheck:SetChecked(false)
    closeCheck:Click("LeftButton")
    assert(EmotePanelSavedVars.closePanelAfterAction == false)
    SlashCmdList.EMOTEPANEL("list")
    settings:Show()
    local sitFavorite
    for _, widget in ipairs(widgets) do
        if widget.parent == settings.scrollFrame.content and widget.favoriteEntry
            and widget.favoriteEntry.mode == "emotes" and widget.favoriteEntry.index == 30 then
            sitFavorite = widget
        end
    end
    assert(sitFavorite and sitFavorite.icon.path == 130042)
    local function ClickButton(parent, text)
        for _, widget in ipairs(widgets) do
            if widget.parent == parent and widget:GetText() == text then
                widget:Click("LeftButton")
                return
            end
        end
        error("Button missing: " .. text)
    end
    local sections = { Sit = "emotes", ["Character Info"] = "panels", Cooking = "professions",
        Roll = "commands", ["Small Roll"] = "commands", Campfire = "chat", ["World Map"] = "panels" }
    local function FindCheckbox(name)
        settings:SelectSection(assert(sections[name]))
        local prefix = name .. "  ·  "
        for _, widget in ipairs(widgets) do
            if (widget:GetText() or ""):sub(1, #prefix) == prefix and widget.point then
                local icon = widget.point[2]
                local row = type(icon) == "table" and icon.parent
                if row and row.icon == icon and row:IsShown() and row.parent == settings.scrollFrame.content then
                    return row.check
                end
            end
        end
        error("Entry missing: " .. name)
    end
    local function SetVisible(name, visible)
        local checkbox = FindCheckbox(name)
        assert(checkbox:GetChecked() ~= visible)
        checkbox:SetChecked(visible)
        checkbox:Click("LeftButton")
    end
    assert(FindCheckbox("Sit").parent.icon.path == 130042)
    SetVisible("Sit", false)
    assert(EmotePanelSavedVars.hiddenEntries.emotes[30] and #EmotePanelSavedVars.favorites == 9)
    assert(panel.titleText:GetText() == "Favorites" and panel.selectionName:GetText() == "Angry")
    SetVisible("Sit", true)
    assert(panel.selectionName:GetText() == "Sit" and panel.slots[1].icon.path == 130042)
    SetVisible("Character Info", false)
    SetVisible("Cooking", false)
    assert(EmotePanelSavedVars.hiddenEntries.panels[1] and EmotePanelSavedVars.hiddenEntries.professions[185])
    ClickButton(FindCheckbox("Roll").parent, "Edit")
    local rollEditor = panel.customMessageDialog
    AssertEditorPromptClear(rollEditor)
    assert(rollEditor.messageBox.label:GetText() == "Slash override (optional)" and rollEditor.messageBox:GetText() == "")
    rollEditor.messageBox:SetText("/roll 42")
    rollEditor.saveButton:Click("LeftButton")
    assert(EmotePanelSavedVars.customMessages.commands[6] == "/roll 42")
    ClickButton(FindCheckbox("Roll").parent, "Edit")
    assert(rollEditor.messageBox:GetText() == "/roll 42")
    rollEditor.messageBox:SetText("")
    rollEditor.saveButton:Click("LeftButton")
    assert(not EmotePanelSavedVars.customMessages.commands[6])
    ClickButton(FindCheckbox("Roll").parent, "Edit")
    rollEditor.placement.show:SetChecked(false)
    rollEditor.placement.show:Click("LeftButton")
    assert(rollEditor.placement.location:GetText() == "Commands · Hidden")
    assert(FindCheckbox("Roll"):GetChecked())
    rollEditor.saveButton:Click("LeftButton")
    assert(not FindCheckbox("Roll"):GetChecked())
    ClickButton(FindCheckbox("Roll").parent, "Edit")
    rollEditor.placement.show:SetChecked(true)
    rollEditor.placement.show:Click("LeftButton")
    rollEditor.saveButton:Click("LeftButton")
    assert(FindCheckbox("Roll"):GetChecked())

    local function AddEntry(kind, name, message)
        settings:SelectSection(({ Command = "commands", Say = "chat", Party = "party", Emote = "emotes" })[kind])
        ClickButton(settings, "Add " .. kind)
        local dialog = panel.customMessageDialog
        assert(dialog:IsShown() and not dialog.resetButton:IsShown())
        AssertEditorPromptClear(dialog)
        dialog.nameBox:SetText(name)
        dialog.messageBox:SetText(message)
        dialog.saveButton:Click("LeftButton")
        return dialog
    end
    local dialog = AddEntry("Command", "Small Roll", "roll 6")
    assert(dialog:IsShown() and dialog.errorText:GetText():find("with /", 1, true))
    dialog.messageBox:SetText("/roll 6")
    dialog.saveButton:Click("LeftButton")
    assert(not dialog:IsShown() and FindCheckbox("Small Roll"):GetChecked())
    assert(not AddEntry("Say", "Campfire", "Anyone have a campfire nearby?"):IsShown())
    assert(not AddEntry("Party", "Summon", "Could I get a summon?"):IsShown())
    assert(not AddEntry("Emote", "Wave Hello", "/wave"):IsShown())
    assert(not AddEntry("Emote", "Rally Cheer", "/cheer"):IsShown())
    ClickButton(FindCheckbox("Campfire").parent, "Edit")
    assert(dialog.messageBox:GetText() == "Anyone have a campfire nearby?")
    dialog.messageBox:SetText("Is there a campfire nearby?")
    dialog.saveButton:Click("LeftButton")
    settings:Hide()

    EmotePanel_Toggle()
    local function GoToPage(title)
        for _ = 1, 24 do
            if panel.titleText:GetText() == title then return end
            panel:CycleMode(1)
        end
        error("Page missing: " .. title)
    end
    GoToPage("Game Panels  1 / 2")
    assert(panel.selectionName:GetText() == "Spellbook")
    expectWheelOpen = true
    panel:ActivateSector(1, "LeftButton")
    assert(openedPanel == "Spellbook" and panel.frame:IsShown())
    expectWheelOpen = nil
    GoToPage("Professions")
    assert(panel.slots[3].icon.path ~= EmotePanelSavedVars.customIcons.professions[185])
    panel:ActivateSector(1, "LeftButton")
    assert(panel.frame:IsShown())
    GoToPage("Emotes  4 / 4")
    panel:ActivateSector(8, "LeftButton")
    assert(actions[#actions][1] == "WAVE")
    GoToPage("Voiced Emotes  2 / 3")
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Attack My Target" and panel.messagePreview:GetText() == "/attacktarget")
    panel:ToggleFavorite()
    assert(EmotePanelSavedVars.favorites[10].mode == "emotes"
        and EmotePanelSavedVars.favorites[10].index == "native:ATTACKMYTARGET")
    panel:ToggleFavorite()
    panel:ActivateSector(2, "LeftButton")
    assert(actions[#actions][1] == "ATTACKMYTARGET")
    GoToPage("Voiced Emotes  3 / 3")
    faction = "Horde"
    panel:ActivateSector(7, "LeftButton")
    assert(actions[#actions][1] == "FORTHEHORDE")
    faction = "Alliance"
    panel:ActivateSector(8, "LeftButton")
    assert(panel.selectionName:GetText() == "Rally Cheer" and actions[#actions][1] == "CHEER")
    GoToPage("Say Chat  2 / 2")
    panel:ActivateSector(3, "LeftButton")
    assert(actions[#actions][1] == "Is there a campfire nearby?" and actions[#actions][2] == "SAY")
    GoToPage("Party Chat  2 / 2")
    local previousActions = #actions
    inGroup = false
    panel:ActivateSector(3, "LeftButton")
    assert(#actions == previousActions)
    inGroup = true
    panel:ActivateSector(3, "LeftButton")
    assert(actions[#actions][1] == "Could I get a summon?" and actions[#actions][2] == "PARTY")
    GoToPage("Commands  3 / 3")
    panel:Select(1)
    assert(panel.selectionName:GetText() == "Settings")
    openedCategory = nil
    panel:ActivateSector(1, "LeftButton")
    assert(openedCategory == panel.settingsCategoryID and not panel.frame:IsShown())
    EmotePanel_Toggle()
    GoToPage("Commands  3 / 3")
    panel:Select(3)
    panel:ToggleFavorite()
    assert(EmotePanelSavedVars.favorites[10].mode == "commands" and EmotePanelSavedVars.favorites[10].index == -1)
    panel:ActivateSector(3, "LeftButton")
    assert(command == "/roll 6" and panel.frame:IsShown())
    EmotePanel_Toggle()
    settings:Show()
    SetVisible("Small Roll", false)
    assert(EmotePanelSavedVars.hiddenEntries.commands[-1] and #EmotePanelSavedVars.favorites == 10)
    local mapRow = FindCheckbox("World Map").parent
    local up, down
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Up" then up = widget end
        if widget.parent == settings and widget:GetText() == "Down" then down = widget end
    end
    assert(up and down and not up.enabled and not down.enabled)
    mapRow:Click("LeftButton")
    assert(mapRow.selection:IsShown() and up.enabled and not down.enabled)
    local oldY = mapRow.point[3]
    for _ = 1, 11 do up:Click("LeftButton") end
    assert(mapRow.point[3] > oldY and mapRow.selection:IsShown() and down.enabled)
    down:Click("LeftButton")
    local scroll = settings.scrollFrame
    local rowTop = -mapRow.point[3]
    assert(rowTop >= scroll:GetVerticalScroll()
        and rowTop + mapRow:GetHeight() <= scroll:GetVerticalScroll() + scroll:GetHeight())
    SetVisible("World Map", false)
    SetVisible("World Map", true)
    EmotePanel_Toggle()
    GoToPage("Game Panels  1 / 2")
    panel:Select(4) -- The fifth ordered entry, with Character Info hidden.
    assert(panel.selectionName:GetText() == "World Map")
    EmotePanel_Toggle()
    settings:Hide()
    categoryCheck:SetChecked(true)
    categoryCheck:Click("LeftButton")
    assert(EmotePanelSavedVars.categoryWheel == true)
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    assert(EmotePanelSavedVars.closePanelAfterAction == false)
    local closeCheck, categoryCheck
    for _, widget in ipairs(widgets) do
        if widget:GetText() == "Close panel after action" then closeCheck = widget.point[2] end
        if widget:GetText() == "Open on Category Wheel" then categoryCheck = widget.point[2] end
    end
    assert(closeCheck and closeCheck:GetChecked() == false)
    assert(categoryCheck and categoryCheck:GetChecked())
    assert(#EmotePanelSavedVars.favorites == 10 and EmotePanelSavedVars.entries.commands[1].name == "Small Roll")
    assert(EmotePanelSavedVars.hiddenEntries.commands[-1])

    local frame = panel.frame
    local input = panel.gamepadInput
    local function tap(key)
        assert(input.scripts.OnGamePadButtonDown(input, key) == false)
        assert(input.scripts.OnGamePadButtonUp(input, key) == false)
    end
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Categories")
    assert(not panel.backButton:IsShown() and not panel.pageArrows[1]:IsShown())
    local categories = {
        {"Favorites", "Favorites  1 / 2"}, {"Emotes", "Emotes  1 / 4"},
        {"Voiced Emotes", "Voiced Emotes  1 / 3"}, {"Say Chat", "Say Chat  1 / 2"},
        {"Party Chat", "Party Chat  1 / 2"}, {"Commands", "Commands  1 / 3"},
        {"Game Panels", "Game Panels  1 / 2"}, {"Professions", "Professions"},
    }
    for sector, category in ipairs(categories) do
        assert(panel.slots[sector]:IsShown() and not panel.slots[sector].favorite:IsShown())
        panel:Select(sector)
        assert(panel.selectionName:GetText() == category[1])
        tap("PAD1")
        assert(panel.titleText:GetText() == category[2] and panel.backButton:IsShown())
        tap("PAD2")
        assert(panel.titleText:GetText() == "Categories" and panel.selected == sector)
    end

    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Categories")
    local priorActions, priorFavorites = #actions, #EmotePanelSavedVars.favorites
    tap("PAD3")
    tap("PAD4")
    assert(#EmotePanelSavedVars.favorites == priorFavorites and not panel.customMessageDialog)
    panel:Select(5)
    tap("PAD1")
    tap("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Party Chat  2 / 2")
    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Party Chat  1 / 2")
    inGroup = true
    tap("PAD1")
    assert(#actions == priorActions + 1 and actions[#actions][2] == "PARTY" and frame:IsShown())
    panel.backButton:Click("LeftButton")
    assert(panel.titleText:GetText() == "Categories" and panel.selected == 5)

    local wheel = panel.wheel
    local x, y = wheel:GetCenter()
    cursorX, cursorY = x + 136, y
    wheel.scripts.OnMouseDown(wheel, "LeftButton")
    wheel:Click("LeftButton")
    assert(panel.titleText:GetText() == "Voiced Emotes  1 / 3")
    panel.backButton:Click("LeftButton")
    assert(panel.titleText:GetText() == "Categories" and panel.selected == 3)

    panel:Select(7)
    tap("PAD1")
    panel:Select(4)
    assert(panel.selectionName:GetText() == "World Map")
    panel.backButton:Click("LeftButton")
    SlashCmdList.EMOTEPANEL("list")
    local settings = EmotePanelHelpPanel
    settings:Show()
    settings:SelectSection("panels")
    local resetOrder
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Reset Order" and widget.enabled then
            assert(not resetOrder)
            resetOrder = widget
        end
    end
    assert(resetOrder)
    resetOrder:Click("LeftButton")
    assert(not resetOrder.enabled and not EmotePanelSavedVars.entryOrder.panels)
    assert(EmotePanelSavedVars.hiddenEntries.panels[1] and #EmotePanelSavedVars.favorites == 10)
    settings:Hide()
    EmotePanel_Toggle()
    panel:Select(7)
    tap("PAD1")
    tap("PADRSHOULDER")
    local diagonal = 136 / math.sqrt(2)
    cursorX, cursorY = x - diagonal, y - diagonal -- Character Info is hidden in this fixture.
    openedPanel = nil
    expectWheelOpen = true
    wheel.scripts.OnMouseDown(wheel, "LeftButton")
    wheel:Click("LeftButton")
    expectWheelOpen = nil
    assert(openedPanel == "World Map" and frame:IsShown())
    panel.backButton:Click("LeftButton")

    EmotePanelSavedVars.closePanelAfterAction = true
    panel:Select(5)
    tap("PAD1")
    assert(frame:IsShown())
    tap("PAD1")
    assert(not frame:IsShown())
    EmotePanelSavedVars.closePanelAfterAction = false
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Categories")

    local hiddenChat = {[-1] = true}
    for index = 1, 11 do hiddenChat[index] = true end
    local oldHiddenChat = EmotePanelSavedVars.hiddenEntries.chat
    EmotePanelSavedVars.hiddenEntries.chat = hiddenChat
    panel:RefreshEntryPages()
    panel:Select(4)
    tap("PAD1")
    assert(panel.titleText:GetText() == "Say Chat" and panel.selectionName:GetText() == "No visible entries")
    tap("PADRSHOULDER")
    events.scripts.OnEvent(events, "SKILL_LINES_CHANGED")
    assert(panel.titleText:GetText() == "Say Chat" and not panel.selected)
    tap("PAD2")
    tap("PAD2")
    assert(not frame:IsShown())
    EmotePanelSavedVars.hiddenEntries.chat = oldHiddenChat
    panel:RefreshEntryPages()

    categoryCheck:SetChecked(false)
    categoryCheck:Click("LeftButton")
    assert(EmotePanelSavedVars.categoryWheel == false)
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Favorites  1 / 2")
    panel:CycleMode(1)
    assert(panel.slots[1]:IsShown() and not panel.slots[2]:IsShown())
    EmotePanelSavedVars.hiddenEntries.commands[-1] = nil
    panel:RefreshEntryPages()
    panel:CycleMode(1)
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Small Roll")

    local function setGrouped(value)
        inGroup = value
        assert(events.events.GROUP_ROSTER_UPDATE)
        events.scripts.OnEvent(events, "GROUP_ROSTER_UPDATE")
    end
    setGrouped(false)
    repeat panel:CycleMode(1) until panel.titleText:GetText() == "Commands  3 / 3"
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Small Roll" and not panel.slots[3]:IsShown())
    setGrouped(true)
    assert(panel.titleText:GetText() == "Commands  3 / 3")
    panel:Select(2)
    assert(panel.selectionName:GetText() == "Leave Group")
    local previousNativeActions = #nativeActions
    assert(panel.gamepadInput.scripts.OnGamePadButtonDown(panel.gamepadInput, "PAD1") == false)
    setGrouped(false)
    assert(panel.gamepadInput.scripts.OnGamePadButtonUp(panel.gamepadInput, "PAD1") == false)
    assert(#nativeActions == previousNativeActions and panel.selectionName:GetText() == "Small Roll")
    setGrouped(true)
    panel:Select(2)
    tap("PAD1")
    assert(nativeActions[#nativeActions][1] == "leaveGroup" and not nativeActions[#nativeActions][2])
    inInstanceGroup = true
    tap("PAD1")
    assert(nativeActions[#nativeActions][1] == "confirmLeaveInstance")
    inInstanceGroup = false
    panel:ToggleFavorite()
    assert(#EmotePanelSavedVars.favorites == 11)
    EmotePanel_Toggle()
    EmotePanel_Toggle()
    panel:CycleMode(1)
    panel:Select(3)
    assert(panel.selectionName:GetText() == "Leave Group")
    setGrouped(false)
    assert(panel.titleText:GetText() == "Favorites  2 / 2" and not panel.slots[3]:IsShown())
    assert(#EmotePanelSavedVars.favorites == 11)
    setGrouped(true)
    panel:Select(3)
    assert(panel.selectionName:GetText() == "Leave Group")

    local hiddenCommands = {[-1] = true}
    for index = 1, 17 do hiddenCommands[index] = true end
    EmotePanelSavedVars.hiddenEntries.commands = hiddenCommands
    categoryCheck:SetChecked(true)
    categoryCheck:Click("LeftButton")
    panel:RefreshEntryPages()
    panel:Select(6)
    tap("PAD1")
    assert(panel.selectionName:GetText() == "Leave Group")
    setGrouped(false)
    assert(panel.titleText:GetText() == "Commands" and not panel.selected)
    setGrouped(true)
    assert(panel.selectionName:GetText() == "Leave Group")
""")
lua.execute("""
    local panel = EmotePanel
    local events
    for _, widget in ipairs(widgets) do
        if widget.events.UPDATE_MACROS then events = widget end
    end
    local frame = panel.frame
    local function tap(key) TapWheelButton(panel, key) end
    local function updateMacros()
        assert(events.events.UPDATE_MACROS)
        events.scripts.OnEvent(events, "UPDATE_MACROS")
    end
    local settings = EmotePanelActionsPanel
    local function findMacroOption(text)
        for _, widget in ipairs(widgets) do
            if widget.choice and widget.parent.parent.parent == settings and widget:IsShown()
                and widget.label:GetText() == text then return widget end
        end
    end
    accountMacros = {{"Shared", 111, spell = 123}, {"Duplicate", 222}, {"Duplicate", 333}}
    characterMacros = {{"Shared", 444, item = "item:456"}}
    spellCooldowns[123] = MockSpellCooldown(true)
    itemCooldowns["item:456"] = {100, 120, true}
    updateMacros()
    assert(panel.titleText:GetText() == "Categories" and not panel.pageArrows[1]:IsShown())
    SlashCmdList.EMOTEPANEL("actions")
    settings:Show()
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Macros" then widget:Click("LeftButton") end
    end
    local account = assert(findMacroOption("Shared  ·  Account macro"))
    local character = assert(findMacroOption("Shared  ·  Character macro"))
    assert(not findMacroOption("Duplicate  ·  Account macro"))
    assert(not account:GetChecked() and not character:GetChecked())
    account:SetChecked(true)
    account:Click("LeftButton")
    character:SetChecked(true)
    character:Click("LeftButton")
    settings:Hide()
    EmotePanel_Toggle()
    assert(panel.pageArrows[1]:IsShown() and not panel.pageArrows[2]:IsShown())
    tap("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  1 / 1")
    assert(panel.slots[1].icon.path == 111 and panel.slots[2].icon.path == 444)
    targetExists = true
    spellRanges[123], itemRanges["item:456"] = false, false
    events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
    assert(panel.slots[1].icon.color[2] < 1 and panel.slots[2].icon.color[2] < 1)
    targetExists = false
    events.scripts.OnEvent(events, "PLAYER_TARGET_CHANGED")
    assert(panel.slots[1].icon.color[2] == 1 and panel.slots[2].icon.color[2] == 1)
    assert(panel.messagePreview:GetText() == "Account macro")
    local spellTimer, itemTimer = panel.slots[1].cooldown, panel.slots[2].cooldown
    local cooldownCheck
    for _, widget in ipairs(widgets) do
        if widget:GetText() == "Show action cooldowns" then cooldownCheck = widget.point[2] end
    end
    assert(cooldownCheck.parent == panel.optionsPanel and not cooldownCheck:GetChecked())
    assert(spellTimer.hideNumbers and itemTimer.hideNumbers)
    assert(panel.slots[1].icon.desaturated and panel.slots[2].icon.desaturated)
    cooldownCheck:SetChecked(true)
    cooldownCheck:Click("LeftButton")
    assert(EmotePanelSavedVars.macroCooldowns and spellTimer.timer == spellCooldowns[123])
    assert(spellTimer.allPoints == panel.slots[1].icon and spellTimer.mouse == false)
    assert(spellTimer.hideNumbers == false and spellTimer.drawSwipe == false)
    assert(itemTimer.timer[1] == 100 and itemTimer.timer[2] == 120)
    local function cooldownEvent(event)
        assert(events.events[event])
        events.scripts.OnEvent(events, event)
    end
    spellCooldowns[123] = secretDraft
    cooldownEvent("SPELL_UPDATE_COOLDOWN")
    assert(not spellTimer.timer and not panel.slots[1].icon.desaturated)
    spellCooldowns[123] = MockSpellCooldown(secretDraft)
    cooldownEvent("SPELL_UPDATE_COOLDOWN")
    assert(spellTimer.timer == spellCooldowns[123] and panel.slots[1].icon.desaturated == secretDraft)
    spellTimer.scripts.OnCooldownDone(spellTimer)
    assert(not panel.slots[1].icon.desaturated)
    spellCooldowns[123] = MockSpellCooldown(false)
    cooldownEvent("SPELL_UPDATE_COOLDOWN")
    assert(not panel.slots[1].icon.desaturated)
    spellCooldowns[123] = MockSpellCooldown(true)
    cooldownTime = 220
    cooldownEvent("BAG_UPDATE_COOLDOWN")
    assert(not itemTimer.timer and not panel.slots[2].icon.desaturated)
    itemCooldowns["item:456"] = {200, 120, true}
    assert(not panel.pageArrows[1]:IsShown() and panel.pageArrows[2]:IsShown())
    assert(panel.navigationHint:GetText():find("Categories", 1, true))
    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Categories")
    assert(not spellTimer.timer and not itemTimer.timer and not panel.slots[1].icon.desaturated)
    tap("PADDLEFT")
    tap("PADDRIGHT")
    assert(panel.titleText:GetText() == "Categories")
    panel.pageArrows[1]:Click("LeftButton")
    panel.pageArrows[2]:Click("LeftButton")
    assert(panel.titleText:GetText() == "Categories")
    tap("PADLSHOULDER")
    tap("PAD2")
    assert(panel.titleText:GetText() == "Categories")
    panel.pageArrows[1]:Click("LeftButton")
    panel:Select(2)
    tap("PAD3")
    local proxy = assert(panel.secureWheelInput)
    assert(proxy:IsShown() and proxy.bindings.PAD1 == "WheelActivate")
    tap("PAD1")
    assert(frame:IsShown() and #macroRuns == 1 and macroRuns[1][1] == 121)
    local x, y = panel.wheel:GetCenter()
    cursorX, cursorY = x, y + 136
    proxy.scripts.OnMouseDown(proxy, "LeftButton")
    proxy:Click("LeftButton")
    assert(frame:IsShown() and #macroRuns == 2 and macroRuns[2][1] == 1)
    proxy.scripts.OnMouseDown(proxy, "LeftButton")
    cursorX, cursorY = x, y
    proxy:Click("LeftButton")
    assert(#macroRuns == 2)
    tap("PAD4")
    assert(panel.customMessageDialog:IsShown() and not proxy:IsShown() and not next(proxy.bindings))
    tap("PAD2")
    assert(proxy:IsShown() and proxy.bindings.PAD1 == "WheelActivate")

    table.insert(accountMacros, 1, {"Earlier", 555})
    tap("PAD1")
    assert(#macroRuns == 2)
    updateMacros()
    assert(not proxy:IsShown() and not next(proxy.bindings))
    tap("PADLSHOULDER")
    tap("PAD1")
    assert(#macroRuns == 3 and macroRuns[3][1] == 2)
    combat = true
    proxy:combatChanged("combat")
    events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
    assert(panel.slots[1].icon.desaturated and panel.slots[2].icon.desaturated)
    spellTimer.scripts.OnCooldownDone(spellTimer)
    assert(panel.slots[1].icon.desaturated and panel.slots[1]:GetAlpha() < 1)
    assert(not proxy:IsShown() and not next(proxy.bindings))
    tap("PAD1")
    assert(frame:IsShown() and not proxy:IsShown() and #macroRuns == 3)
    combat = false
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
    assert(proxy:IsShown() and panel.slots[1].icon.desaturated and panel.slots[1]:GetAlpha() == 1)
    EmotePanelSavedVars.closePanelAfterAction = true
    gamepadState = {sticks = {{x = 0, y = 1}}}
    tap("PAD1")
    assert(#macroRuns == 4 and not frame:IsShown() and not proxy:IsShown() and not next(proxy.bindings))
    assert(not panel.wheelMovementGuard:IsShown())
    gamepadState = nil
    local queriesBefore = cooldownQueries
    cooldownEvent("BAG_UPDATE_COOLDOWN")
    assert(cooldownQueries == queriesBefore)
    EmotePanel_Toggle()
    panel:Select(1)
    tap("PAD1")
    tap("PADRSHOULDER")
    assert(panel.titleText:GetText() == "Favorites  2 / 2")
    local favoriteTimer
    for _, slot in ipairs(panel.slots) do
        if slot:IsShown() and slot.icon.path == 444 then favoriteTimer = slot.cooldown end
    end
    assert(favoriteTimer and favoriteTimer.timer[1] == 200 and favoriteTimer.timer[2] == 120)
    cooldownCheck:SetChecked(false)
    cooldownCheck:Click("LeftButton")
    assert(not EmotePanelSavedVars.macroCooldowns and favoriteTimer.hideNumbers)
    cooldownCheck:SetChecked(true)
    cooldownCheck:Click("LeftButton")
    assert(favoriteTimer.timer)
    frame:Hide()
    EmotePanelSavedVars.categoryWheel = false
    playerGUID = "Player-1-2"
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    assert(EmotePanelSavedVars.favorites[12].mode == "macros")
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Favorites  1 / 2")
    panel:CycleMode(-1)
    assert(panel.titleText:GetText() == "Actions  1 / 1" and panel.slots[1].icon.path == 111)
    assert(panel.slots[1].cooldown.timer == spellCooldowns[123])
    assert(not panel.slots[2]:IsShown())
    panel:CycleMode(1)
    assert(panel.titleText:GetText() == "Favorites  1 / 2")
""")
lua.execute("""
    local panel = EmotePanel
    local settings = EmotePanelCategoriesPanel
    SlashCmdList.EMOTEPANEL("categories")
    assert(openedCategory == settingsSubcategories.Categories and not panel.frame:IsShown())
    local toggle, commands, favorites, emotes
    for _, widget in ipairs(widgets) do
        local text = widget:GetText()
        local check = widget.points and widget.points.LEFT and widget.points.LEFT[2]
        if type(check) == "table" then
            if check.parent == settings and text == "Open on Category Wheel" then
                toggle = check
            elseif check.parent and check.parent.parent == settings then
                if text == "Commands" then commands = check end
                if text == "Favorites" then favorites = check end
                if text == "Emotes" then emotes = check end
            end
        end
    end
    assert(toggle and not toggle:GetChecked())
    assert(commands:GetChecked() and not commands.enabled and commands.parent.alpha < 1)
    local up, down
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Up" then up = widget end
        if widget.parent == settings and widget:GetText() == "Down" then down = widget end
    end
    assert(not up.enabled and not down.enabled)
    toggle:SetChecked(true)
    toggle:Click("LeftButton")
    commands.parent:Click("LeftButton")
    assert(commands.enabled and commands.parent.alpha == 1 and up.enabled)
    for _ = 1, 5 do up:Click("LeftButton") end
    assert(not up.enabled and down.enabled and commands.parent.selection:IsShown())
    for _, check in ipairs({favorites, emotes}) do
        check:SetChecked(false)
        check:Click("LeftButton")
    end
    EmotePanel_Toggle()
    assert(panel.selectionName:GetText() == "Commands" and not panel.slots[7]:IsShown())
    panel:ActivateSector(1, "LeftButton")
    assert(panel.titleText:GetText():find("^Commands"))
    panel:BackOrClose()
    assert(panel.titleText:GetText() == "Categories" and panel.selectionName:GetText() == "Commands")
    toggle:SetChecked(false)
    toggle:Click("LeftButton")
    assert(panel.titleText:GetText():find("^Favorites") and not favorites.enabled and not favorites:GetChecked())
    toggle:SetChecked(true)
    toggle:Click("LeftButton")
    assert(panel.selectionName:GetText() == "Commands")
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Categories" and panel.selectionName:GetText() == "Commands")
    assert(panel.slots[6]:IsShown() and not panel.slots[7]:IsShown())
    local settings = EmotePanelCategoriesPanel
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Reset Order" then
            assert(widget.enabled)
            widget:Click("LeftButton")
            assert(not widget.enabled)
        end
    end
    assert(panel.selectionName:GetText() == "Voiced Emotes" and not panel.slots[7]:IsShown())
    for _, widget in ipairs(widgets) do
        if widget.parent and widget.parent.parent == settings and widget:GetChecked() then
            widget:SetChecked(false)
            widget:Click("LeftButton")
        end
    end
    assert(panel.selectionName:GetText() == "No visible categories" and not panel.highlight:IsShown())
    assert(panel.pageArrows[1]:IsShown()) -- Selected macros are still accessible.
    panel:BackOrClose()
    assert(not panel.frame:IsShown())
""")
lua.execute("""
    local panel = EmotePanel
    local options = panel.optionsPanel
    local xBox, yBox = EmotePanelPositionX, EmotePanelPositionY
    assert(xBox.template == "InputBoxScriptTemplate" and yBox.template == "InputBoxScriptTemplate")
    local function findButton(parent, text)
        for _, widget in ipairs(widgets) do
            if widget.parent == parent and widget:GetText() == text then return widget end
        end
        error("Button missing: " .. text)
    end
    local function confirmReset()
        assert(popup == "EMOTEPANEL_RESET_SETTINGS")
        StaticPopupDialogs[popup].OnAccept(nil, popupData)
        StaticPopup_Hide(popup)
    end
    for _, page in ipairs({"Categories", "Entries", "Customization"}) do
        findButton(options, page):Click("LeftButton")
        assert(openedCategory == settingsSubcategories[page])
    end
    UIParent:SetSize(1400, 900)
    local saved = EmotePanelSavedVars
    saved.positions.emotePanel = {point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -24, y = 40}
    panel:LoadPosition()
    EmotePanelCustomizationPanel:Show()
    assert(panel.frame.point[1] == "BOTTOMRIGHT")
    assert(xBox:GetText() == "460.0" and yBox:GetText() == "-84.0")

    local apply = findButton(xBox.parent, "Apply")
    xBox:SetText("1e999")
    apply:Click("LeftButton")
    assert(saved.positions.emotePanel.point == "BOTTOMRIGHT")
    xBox:SetText("125.5")
    yBox:SetText("-50")
    apply:Click("LeftButton")
    assert(panel.frame.point[1] == "CENTER" and panel.frame.point[4] == 125.5 and panel.frame.point[5] == -50)
    assert(saved.positions.emotePanel.x == 125.5 and saved.positions.emotePanel.y == -50)
    assert(xBox:GetText() == "125.5" and yBox:GetText() == "-50.0")
    panel.frame:SetPoint("CENTER", UIParent, "CENTER", -40, 30)
    panel:SavePosition()
    assert(xBox:GetText() == "-40.0" and yBox:GetText() == "30.0")

    local resetPosition = findButton(xBox.parent, "Reset Position")
    resetPosition:Click("LeftButton")
    assert(popup == "EMOTEPANEL_RESET_SETTINGS" and saved.positions.emotePanel.x == -40)
    StaticPopup_Hide(popup) -- Cancel.
    assert(saved.positions.emotePanel.x == -40)
    resetPosition:Click("LeftButton")
    confirmReset()
    assert(not saved.positions.emotePanel and panel.frame.point[1] == "CENTER")
    assert(panel.frame.point[4] == 0 and panel.frame.point[5] == 0 and xBox:GetText() == "0.0")

    local displayChecks = {}
    for _, widget in ipairs(widgets) do
        local label = widget:GetText()
        if label == "Show Help button (?)" or label == "Show Close button (X)" or label == "Show keybind legend" then
            local check = widget.point[2]
            if check.parent == EmotePanelCustomizationPanel then displayChecks[label] = check end
        end
    end
    local helpCheck = assert(displayChecks["Show Help button (?)"])
    local closeCheck = assert(displayChecks["Show Close button (X)"])
    local legendCheck = assert(displayChecks["Show keybind legend"])
    assert(helpCheck:GetChecked() and closeCheck:GetChecked() and legendCheck:GetChecked())
    helpCheck:SetChecked(false)
    helpCheck:Click("LeftButton")
    assert(not saved.showHelpButton and not panel.helpButton:IsShown() and panel.closeButton:IsShown())
    closeCheck:SetChecked(false)
    closeCheck:Click("LeftButton")
    assert(not saved.showCloseButton and not panel.closeButton:IsShown() and panel.legendFooter:IsShown())
    legendCheck:SetChecked(false)
    legendCheck:Click("LeftButton")
    assert(not saved.showKeybindLegend and not panel.legendFooter:IsShown())
    assert(not panel.navigationHint:IsShown() and not panel.gamepadHint:IsShown())
    assert(panel.messagePreview.point[2] == panel.selectionName)
    for _, check in pairs(displayChecks) do
        check:SetChecked(true)
        check:Click("LeftButton")
    end
    assert(panel.helpButton:IsShown() and panel.closeButton:IsShown() and panel.legendFooter:IsShown())
    assert(panel.messagePreview.point[2] == panel.legendFooter)

    saved.closePanelAfterAction = false
    findButton(options, "Reset General"):Click("LeftButton")
    assert(saved.closePanelAfterAction == false and saved.macroCooldowns)
    confirmReset()
    assert(saved.closePanelAfterAction == nil and not saved.macroCooldowns and saved.categoryWheel)

    local favorites, icons, entryVisibility = saved.favorites, saved.customIcons, saved.hiddenEntries.panels
    findButton(EmotePanelCategoriesPanel, "Reset Categories"):Click("LeftButton")
    assert(saved.categoryWheel and saved.hiddenEntries.categories)
    confirmReset()
    assert(not saved.categoryWheel and not saved.hiddenEntries.categories and not saved.entryOrder.categories)
    assert(saved.favorites == favorites and saved.customIcons == icons and saved.hiddenEntries.panels == entryVisibility)
""")
lua.execute("""
    local events
    for _, widget in ipairs(widgets) do
        if widget.events.UPDATE_MACROS then events = widget end
    end
    local panel = EmotePanel
    for index = 1, 8 do
        local name = "Extra " .. index
        table.insert(accountMacros, {name, 111})
        EmotePanelSavedVars.selectedMacros["account:" .. name:lower()] = true
    end
    EmotePanelSavedVars.categoryWheel = true
    events.scripts.OnEvent(events, "UPDATE_MACROS")
    if not panel.frame:IsShown() then EmotePanel_Toggle() end
    assert(panel.titleText:GetText() == "Categories")
    TapWheelButton(panel, "PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    assert(panel.pageArrows[1]:IsShown() and panel.pageArrows[2]:IsShown())
    TapWheelButton(panel, "PADDLEFT")
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    assert(not panel.pageArrows[1]:IsShown() and panel.pageArrows[2]:IsShown())
    assert(panel.navigationHint:GetText():find("Previous page", 1, true))
    TapWheelButton(panel, "PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    panel.pageArrows[2]:Click("LeftButton")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    TapWheelButton(panel, "PADDRIGHT")
    assert(panel.titleText:GetText() == "Categories")

    EmotePanelSavedVars.categoryWheel = false
    panel:ShowStartPage()
    local startTitle = panel.titleText:GetText()
    panel.pageArrows[1]:Click("LeftButton")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    TapWheelButton(panel, "PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    TapWheelButton(panel, "PADDLEFT")
    assert(panel.titleText:GetText() == "Professions")
    TapWheelButton(panel, "PADDRIGHT")
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    TapWheelButton(panel, "PADRSHOULDER")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    panel.pageArrows[2]:Click("LeftButton")
    assert(panel.titleText:GetText() == startTitle)
    EmotePanelSavedVars.categoryWheel = true
    panel.frame:Hide()
""")
lua.execute("""
    local panel, dropdown = EmotePanel, EmotePanelGlyphStyle
    availableGlyphFamilies = {"gamepad-xbox1-", "gamepad-ps-"}
    dropdown:GenerateMenu()
    assert(dropdown.choices.auto.selected and dropdown.choices.xbox and dropdown.choices.playstation)
    assert(not dropdown.choices.switch)
    table.insert(availableGlyphFamilies, "gamepad-switch-128x-")
    dropdown:GenerateMenu()
    assert(dropdown.choices.switch)

    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Categories")
    panel:ActivateSector(1, "LeftButton")
    panel:ActivateSector(1, "RightButton")
    local editor = panel.customMessageDialog
    assert(editor:IsShown())
    editor.iconButton:Click("LeftButton")
    assert(editor.picker:IsShown())
    local function HasPrompt(fragment)
        for _, widget in ipairs(widgets) do
            if (widget:GetText() or ""):find(fragment, 1, true) then return true end
        end
    end
    dropdown.choices.playstation.select()
    assert(EmotePanelSavedVars.controllerGlyphs == "playstation")
    assert(panel.gamepadHint:GetText():find("<gamepad-ps-buttoncrox-normal> Use", 1, true))
    assert(HasPrompt("<gamepad-ps-buttontriangle-normal> Choose Icon"))
    assert(HasPrompt("<gamepad-ps-buttoncrox-normal> Choose"))
    glyphStyle = "Letters"
    RefreshGlyphs()
    assert(panel.gamepadHint:GetText():find("<gamepad-ps-buttoncrox-normal>", 1, true))
    dropdown.choices.switch.select()
    assert(panel.gamepadHint:GetText():find("<gamepad-switch-128x-face-b-normal>", 1, true))
    dropdown.choices.auto.select()
    assert(not EmotePanelSavedVars.controllerGlyphs)
    assert(panel.gamepadHint:GetText():find("<Letters-PAD1>", 1, true))
""")
lua.execute("""
    local panel, picker = EmotePanel, EmotePanelActionsPanel
    local events
    for _, widget in ipairs(widgets) do
        if widget.events.BAG_UPDATE_DELAYED then events = widget end
    end
    local function fire(event)
        assert(events.events[event])
        events.scripts.OnEvent(events, event)
    end
    local function findButton(parent, text)
        for _, widget in ipairs(widgets) do
            if widget.parent == parent and widget:GetText() == text then return widget end
        end
    end
    local function row(name)
        local result
        for _, widget in ipairs(widgets) do
            if widget.choice and widget.parent.parent.parent == picker and widget:IsShown()
                and widget.label:GetText() == name then
                assert(not result, "Duplicate choice for " .. name)
                result = widget
            end
        end
        return result
    end
    local entriesPanel = EmotePanelHelpPanel
    local function entryRow(name)
        for _, widget in ipairs(widgets) do
            if widget.parent == entriesPanel.scrollFrame.content and widget.label and widget:IsShown()
                and widget.label:GetText() == name then return widget end
        end
    end
    local function clickChoice(choice)
        choice:SetChecked(not choice:GetChecked())
        choice:Click("LeftButton")
    end
    local function iconSector(icon)
        for index, slot in ipairs(panel.slots) do
            if slot:IsShown() and slot.icon.path == icon then return index end
        end
    end

    local saved = EmotePanelSavedVars
    local originalMacroOrder = {"account:extra 1", "account:shared"}
    saved.entryOrder.macros = originalMacroOrder
    saved.closePanelAfterAction = false
    saved.macroCooldowns = true
    spellCooldowns[991] = MockSpellCooldown(true)
    itemCooldowns[993] = {220, 180, true}
    mockSpellBook = {
        {itemType = 1, spellID = 991, name = "Direct Spell", subName = "Rank 2", iconID = 9901},
        {itemType = 1, spellID = 992, name = "Passive Spell", isPassive = true},
        {itemType = 1, spellID = 994, name = "Off Spec Spell", isOffSpec = true},
        {itemType = 2, actionID = 77},
    }
    bagItems = {993, 993, 999}

    SlashCmdList.EMOTEPANEL("list")
    assert(not panel.frame:IsShown())
    assert(EmotePanelEntrySection.choices.favorites.selected)
    EmotePanelEntrySection.choices.macros.select()
    assert(findButton(entriesPanel, "Choose Actions")):Click("LeftButton")
    assert(openedCategory == settingsSubcategories.Actions)
    SlashCmdList.EMOTEPANEL("actions")
    assert(openedCategory == settingsSubcategories.Actions)
    picker:Show()
    entriesPanel:Show()
    assert(not row("Passive Spell") and not row("Off Spec Spell"))
    assert(row("Flyout Spell"))
    local spell = assert(row("Direct Spell (Rank 2)"))
    assert(not spell:GetChecked() and spell.hitInsets[2] < 0)
    assert(not entryRow("Direct Spell (Rank 2)  ·  Spell"))
    clickChoice(spell)
    local selectedSpell = assert(entryRow("Direct Spell (Rank 2)  ·  Spell"))
    assert(selectedSpell.icon.path == 9901 and selectedSpell.icon.path == spell.icon.path)
    selectedSpell:Click("LeftButton")
    local moveUp = assert(findButton(entriesPanel, "Up"))
    local moveDown = assert(findButton(entriesPanel, "Down"))
    assert(selectedSpell.selection:IsShown() and (moveUp.enabled or moveDown.enabled))
    clickChoice(spell)
    assert(not saved.selectedMacros[spell.choice.key] and not entryRow("Direct Spell (Rank 2)  ·  Spell"))
    assert(not moveUp.enabled and not moveDown.enabled)
    clickChoice(spell)
    assert(saved.selectedMacros[spell.choice.key])
    assert(not selectedSpell.selection:IsShown())
    findButton(picker, "Macros"):Click("LeftButton")
    local macro = assert(row("Shared  ·  Account macro"))
    assert(macro:GetChecked() and entryRow("Shared  ·  Account macro"))
    clickChoice(macro)
    assert(not saved.selectedMacros["account:shared"] and not entryRow("Shared  ·  Account macro"))
    clickChoice(macro)
    assert(saved.selectedMacros["account:shared"])
    assert(originalMacroOrder[1] == "account:extra 1" and originalMacroOrder[2] == "account:shared")
    findButton(picker, "Items"):Click("LeftButton")
    local item = assert(row("Direct Item"))
    assert(not entryRow("Direct Item  ·  Item"))
    clickChoice(item)
    assert(#saved.directActions[playerGUID] == 2)
    local itemCheck = assert(entryRow("Direct Item  ·  Item")).check
    clickChoice(itemCheck)
    assert(not entryRow("Direct Item  ·  Item"))
    picker:refresh()
    assert(not item:GetChecked())
    clickChoice(item)
    entriesPanel:Hide()
    picker:Hide()

    EmotePanel_Toggle()
    panel:CycleMode(-1)
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    panel:CycleMode(-1)
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    local spellSector = assert(iconSector(9901))
    local spellIcon = panel.slots[spellSector].icon
    targetExists = true
    spellRanges[991] = false
    fire("PLAYER_TARGET_CHANGED")
    assert(spellIcon.color[2] < 1 and spellIcon.desaturated)
    spellRanges[991] = true
    panel.frame.scripts.OnUpdate(panel.frame, 0.2)
    assert(spellIcon.color[2] == 1 and spellIcon.desaturated)
    spellRanges[991] = false
    panel.frame.scripts.OnUpdate(panel.frame, 0.2)
    assert(spellIcon.color[2] < 1)
    spellRanges[991] = secretDraft
    panel.frame.scripts.OnUpdate(panel.frame, 0.2)
    assert(spellIcon.color[2] == 1)
    local spellAngle = (spellSector - 1) * math.pi / 4
    local input = panel.gamepadInput
    input.scripts.OnGamePadStick(input, "Movement", math.sin(spellAngle), math.cos(spellAngle))
    input.scripts.OnGamePadStick(input, "Movement", 0, 0)
    assert(panel.selected == spellSector)
    assert(panel.slots[panel.selected].cooldown.timer == spellCooldowns[991])
    TapWheelButton(panel, "PAD1")
    assert(#directRuns == 1 and directRuns[1][1] == "spell" and directRuns[1][2] == 991)
    assert(directRuns[1][3] == "WheelActivate" and panel.frame:IsShown())

    local itemSector = assert(iconSector(9903))
    local proxy = panel.secureWheelInput
    local x, y = panel.wheel:GetCenter()
    local angle = (itemSector - 1) * math.pi / 4
    cursorX, cursorY = x + math.sin(angle) * 136, y + math.cos(angle) * 136
    proxy.scripts.OnMouseDown(proxy, "LeftButton")
    proxy:Click("LeftButton")
    assert(#directRuns == 2 and directRuns[2][1] == "item" and directRuns[2][2] == "item:993")
    assert(directRuns[2][3] == "LeftButton")
    assert(not proxy.attributes.type and not proxy.attributes.spell and not proxy.attributes.item)

    panel:ToggleFavorite()
    local itemKey = "item:" .. playerGUID .. ":993"
    assert(saved.favorites[#saved.favorites].index == itemKey)
    spellRanges[991], itemRanges[993] = false, false
    bagItems, equippedItems = {}, {[993] = true}
    fire("PLAYER_EQUIPMENT_CHANGED")
    assert(iconSector(9903))
    equippedItems = {}
    fire("PLAYER_EQUIPMENT_CHANGED")
    assert(not iconSector(9903) and panel.titleText:GetText() == "Actions  2 / 2")
    assert(saved.selectedMacros[itemKey])
    bagItems = {993}
    fire("BAG_UPDATE_DELAYED")
    assert(iconSector(9903))

    panel:BackOrClose()
    panel:ActivateSector(1, "LeftButton")
    panel:CycleMode(1)
    assert(panel.slots[assert(iconSector(9903))].cooldown.timer[2] == 180)
    combat = true
    proxy:combatChanged("combat")
    fire("PLAYER_REGEN_DISABLED")
    local itemFavorite = panel.slots[assert(iconSector(9903))]
    assert(itemFavorite.icon.desaturated and itemFavorite:GetAlpha() < 1 and itemFavorite.icon.color[2] == 1)
    panel:BackOrClose()
    panel:CycleMode(-1)
    panel:CycleMode(-1)
    assert(panel.slots[assert(iconSector(9901))].icon.desaturated)
    assert(panel.slots[assert(iconSector(9903))].icon.desaturated)
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(panel.slots[assert(iconSector(9901))].icon.desaturated)
    assert(panel.slots[assert(iconSector(9903))].icon.desaturated)
    panel:BackOrClose()
    panel:ActivateSector(1, "LeftButton")
    panel:CycleMode(1)
    assert(itemFavorite.icon.desaturated and itemFavorite:GetAlpha() == 1)
    assert(itemFavorite.icon.color[2] < 1)
    targetExists = false
    fire("PLAYER_TARGET_CHANGED")
    assert(itemFavorite.icon.color[2] == 1)
    bagItems = {}
    fire("BAG_UPDATE_DELAYED")
    assert(not iconSector(9903) and panel.titleText:GetText():find("^Favorites"))
    SlashCmdList.EMOTEPANEL("actions")
    picker:Show()
    local missing = assert(row("Direct Item  ·  Not carried"))
    assert(missing:GetChecked())
    entriesPanel:Show()
    assert(entryRow("Direct Item  ·  Item"))
    clickChoice(missing)
    assert(not saved.selectedMacros[itemKey] and not entryRow("Direct Item  ·  Item"))
    entriesPanel:Hide()
    bagItems = {993}
    fire("BAG_UPDATE_DELAYED")
    item = assert(row("Direct Item"))
    assert(not item:GetChecked())
    picker:Hide()
    EmotePanel_Toggle()
    panel:CycleMode(-1)
    panel:CycleMode(-1)
    assert(not iconSector(9903))
    SlashCmdList.EMOTEPANEL("actions")
    picker:Show()
    clickChoice(assert(row("Direct Item")))
    assert(saved.selectedMacros[itemKey])
    picker:Hide()

    -- Going from nine available actions to eight and back keeps page 1 selected.
    saved.selectedMacros["account:extra 7"] = nil
    saved.selectedMacros["account:extra 8"] = nil
    panel:RefreshEntryPages()
    EmotePanel_Toggle()
    panel:CycleMode(-1)
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    bagItems = {}
    fire("BAG_UPDATE_DELAYED")
    assert(panel.titleText:GetText() == "Actions  1 / 1")
    bagItems = {993}
    fire("BAG_UPDATE_DELAYED")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    saved.selectedMacros["account:extra 7"] = true
    saved.selectedMacros["account:extra 8"] = true
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    EmotePanel_Toggle()
    panel:CycleMode(-1)
    panel:CycleMode(-1)
    assert(panel.titleText:GetText() == "Actions  2 / 2")
    assert(panel.slots[3].icon.path == 9903 and panel.slots[3].cooldown.timer[2] == 180)
    playerGUID = "Player-1-3"
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    EmotePanel_Toggle()
    EmotePanel:CycleMode(-1)
    EmotePanel:CycleMode(-1)
    assert(EmotePanel.titleText:GetText() == "Actions  2 / 2")
    assert(EmotePanel.slots[1]:IsShown() and not EmotePanel.slots[2]:IsShown())
    playerGUID = "Player-1-2"
    wheelKey = "PADPADDLE1"
    gameBindings[wheelKey] = "Open Emote Panel"
    gameBindings["CTRL-F9"] = "Open Emote Panel"
    gameBindings["F8"] = "TOGGLEGAMEMENU"
    accountMacros[2][3] = "/cast Original Spell"
    EmotePanelSavedVars.closePanelAfterAction = false
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    local input = assert(panel.combatInput)
    local movementGuard = assert(panel.wheelMovementGuard)
    local function fire(event)
        assert(events.events[event])
        events.scripts.OnEvent(events, event)
    end
    local function enterCombat()
        combat = true
        input:combatChanged("combat")
        fire("PLAYER_REGEN_DISABLED")
    end
    local function leaveCombat()
        combat = false
        input:combatChanged("peace")
        fire("PLAYER_REGEN_ENABLED")
    end
    local function key(keyName)
        local binding = input.bindings[keyName]
        if not binding then
            local name, button = (gameBindings[keyName] or ""):match("^CLICK ([^:]+):(.+)$")
            assert(name == input:GetName())
            binding = assert(button)
        end
        input:Click(binding, true)
        input:Click(binding, false)
    end
    local function pointAt(sector)
        local angle = (sector - 1) * math.pi / 4
        secureMouseX = (input.attributes["wheel-x"] + 136 * math.sin(angle)) / input:GetWidth()
        secureMouseY = (input.attributes["wheel-y"] + 136 * math.cos(angle)) / input:GetHeight()
    end
    assert(not next(input.bindings) and not input:IsShown())
    local direct = "CLICK EmotePanelCombatInput:Toggle"
    assert(gameBindings[wheelKey] == direct and gameBindings["CTRL-F9"] == direct)
    assert(gameBindings["F8"] == "TOGGLEGAMEMENU" and #savedBindingSets == 1 and savedBindingSets[1] == 2)
    key(wheelKey)
    assert(panel.frame:IsShown() and not input:IsShown())
    key(wheelKey)
    assert(not panel.frame:IsShown())
    -- The saved direct binding opens even before the combat state driver updates.
    combat = true
    fire("PLAYER_REGEN_DISABLED")
    assert(not next(input.bindings))
    key(wheelKey)
    input:combatChanged("combat")
    assert(input:IsShown() and panel.frame:IsShown() and not panel.gamepadInput:IsShown())
    assert(panel.titleText:GetText() == "Categories" and not next(combatRuns))
    local originalPrint, message = print
    print = function(line) message = line end
    SlashCmdList.EMOTEPANEL("list")
    print = originalPrint
    assert(input:IsShown() and message:find("close the combat wheel first", 1, true))
    key("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    key("PADDDOWN")
    key("PADDDOWN")
    assert(panel.selectionName:GetText() == "Shared")
    gamepadState = {sticks = {{x = 1, y = 1}}}
    key("PAD1")
    assert(#combatRuns == 1 and combatRuns[1][1] == "macro" and combatRuns[1][2] == "/cast Original Spell")
    assert(input:IsShown() and panel.slots[2].icon.desaturated and panel.slots[2]:GetAlpha() == 1)
    assert(not movementGuard:IsShown())
    gamepadState = nil
    assert(not panel.customMessageDialog and not popup)

    -- Edits cannot redirect an already loaded sector to a different macro.
    accountMacros[2][3] = "/cast Updated Spell"
    fire("UPDATE_MACROS")
    key("PAD1")
    assert(#combatRuns == 2 and combatRuns[2][2] == "/cast Original Spell")

    -- A release after a page change cannot fire a different entry.
    input:Click("Accept", true)
    key("PADDLEFT")
    input:Click("Accept", false)
    assert(#combatRuns == 2 and panel.titleText:GetText() == "Actions  2 / 2")
    targetExists = true
    fire("PLAYER_TARGET_CHANGED")
    assert(panel.slots[2].icon.color[2] < 1 and panel.slots[2].icon.desaturated)
    targetExists = false
    fire("PLAYER_TARGET_CHANGED")
    assert(panel.slots[2].icon.color[2] == 1)
    gamepadState = {sticks = {{x = 0, y = 0}, {x = 1, y = 1}}}
    input.scripts.OnUpdate(input)
    assert(panel.selectionName:GetText() == "Direct Spell (Rank 2)")
    input:Click("Accept", true)
    gamepadState = nil
    input.scripts.OnUpdate(input)
    assert(panel.selectionName:GetText() == "Direct Spell (Rank 2)")
    input:Click("Accept", false)
    assert(#combatRuns == 3 and combatRuns[3][1] == "spell" and combatRuns[3][2] == 991)
    gamepadState = nil

    bagItems = {}
    fire("BAG_UPDATE_DELAYED")
    assert(not panel.slots[3]:IsShown() and panel.slots[2]:IsShown())
    bagItems = {993}
    fire("BAG_UPDATE_DELAYED")
    assert(panel.slots[3]:IsShown() and panel.slots[3].icon.path == 9903)

    pointAt(3)
    input:Click("LeftButton", true)
    pointAt(2)
    input:Click("LeftButton", false)
    assert(#combatRuns == 3)
    pointAt(3)
    input:Click("LeftButton", true)
    input:Click("LeftButton", false)
    assert(#combatRuns == 4 and combatRuns[4][1] == "item" and combatRuns[4][2] == "item:993")
    assert(not input.attributes.type and not input.attributes.item)
    secureMouseX, secureMouseY = (input:GetWidth() / 2 + 118) / input:GetWidth(), (input:GetHeight() - 28) / input:GetHeight()
    input:Click("LeftButton", true)
    input:Click("LeftButton", false)
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    key("ESCAPE")
    assert(not input:IsShown() and not panel.frame:IsShown() and panel.gamepadInput:IsShown())
    assert(not next(input.bindings))
    SlashCmdList.EMOTEPANEL("")
    assert(panel.frame:IsShown() and not input:IsShown())

    key(wheelKey)
    key("PAD1") -- No aim and no D-pad selection.
    assert(panel.titleText:GetText() == "Categories" and not panel.highlight:IsShown())
    key("PADDDOWN")
    key("PAD1") -- Favorites category
    key("PADDRIGHT")
    local favoriteSector
    for index, slot in ipairs(panel.slots) do
        if slot:IsShown() and slot.icon.path == 9903 then favoriteSector = index end
    end
    pointAt(assert(favoriteSector))
    input:Click("LeftButton", true)
    input:Click("LeftButton", false)
    assert(#combatRuns == 5 and combatRuns[5][1] == "item")
    leaveCombat()
    assert(not input:IsShown() and not panel.frame:IsShown() and not next(input.bindings))

    EmotePanelSavedVars.closePanelAfterAction = true
    panel:SyncCombatWheel(true)
    enterCombat()
    key(wheelKey)
    key("PADLSHOULDER")
    key("PADDDOWN")
    key("PADDDOWN")
    key("PAD1")
    assert(#combatRuns == 6 and combatRuns[6][2] == "/cast Updated Spell")
    assert(not input:IsShown() and not panel.frame:IsShown())
    assert(not movementGuard:IsShown())

    local originalPrint, trace = print, {}
    print = function(message) table.insert(trace, message) end
    local function traced(fragment)
        for _, line in ipairs(trace) do
            if line:find(fragment, 1, true) then return true end
        end
    end
    SlashCmdList.EMOTEPANEL("debug on")
    key(wheelKey)
    key("PADLSHOULDER")
    key("PADLSHOULDER")
    gamepadState = {sticks = {{x = 1, y = 1}, {x = 0, y = 0}}}
    local beforeClick = #trace
    key("PAD1")
    assert(#combatRuns == 7 and combatRuns[7][1] == "spell" and combatRuns[7][2] == 991)
    assert(not input:IsShown() and not panel.frame:IsShown() and not next(input.bindings))
    assert(movementGuard:IsShown() and movementGuard.stick and not movementGuard.mouse)
    assert(#trace == beforeClick + 1 and traced("[Secure click] spell | Actions  2 / 2 | sector 2 | Accept | movement held until neutral"))
    local function stick(name, x, y) return movementGuard.scripts.OnGamePadStick(movementGuard, name, x, y) end
    assert(not stick("Left", 1, 1) and not stick("Movement", 1, 1))
    assert(stick("Camera", 1, 1) and stick("Right", 1, 1))
    movementGuard.scripts.OnUpdate(movementGuard)
    assert(movementGuard:IsShown())
    assert(stick("Left", 0, 0) and movementGuard:IsShown())
    gamepadState = {sticks = {{x = 0, y = 0}}}
    assert(stick("Movement", 0, 0) and not movementGuard:IsShown())
    gamepadState = nil
    leaveCombat()

    enterCombat()
    key(wheelKey)
    SlashCmdList.EMOTEPANEL("debug on")
    gamepadState = {sticks = {{x = 1, y = 1}}}
    input.scripts.OnUpdate(input)
    assert(panel.selectionName:GetText() == "Emotes")
    gamepadState = nil
    input.scripts.OnUpdate(input)
    assert(not panel.highlight:IsShown())
    key("PAD1")
    assert(panel.titleText:GetText() == "Categories")
    gamepadState = {sticks = {{x = 1, y = 1}}}
    input:Click("Accept", true)
    gamepadState = nil
    input:Click("Accept", false)
    assert(panel.titleText:GetText():find("^Emotes"))
    assert(traced("[Wheel] Emotes"))
    local previousActions = #actions
    denyEmote = true
    key("PADDDOWN")
    key("PAD1")
    assert(#actions == previousActions and input:IsShown() and panel.frame:IsShown())
    assert(traced("[Emote] rejected | chat lockdown true"))
    events.scripts.OnEvent(events, "ADDON_ACTION_BLOCKED", "OtherAddon", "OtherCall")
    events.scripts.OnEvent(events, "ADDON_ACTION_BLOCKED", "EmotePanel", "ExampleCall")
    assert(traced("ADDON_ACTION_BLOCKED | ExampleCall") and not traced("OtherCall"))
    SlashCmdList.EMOTEPANEL("debug off")
    local lastTrace = #trace
    key("PAD1")
    assert(#actions == previousActions and input:IsShown() and #trace == lastTrace + 1)
    assert(trace[#trace] == "EmotePanel: WoW could not perform that emote.")
    denyEmote = false
    key("PAD1")
    assert(#actions == previousActions + 1 and #trace == lastTrace + 1 and input:IsShown())
    leaveCombat()
    print = originalPrint

    EmotePanelSavedVars.categoryWheel = false
    panel:ShowStartPage()
    enterCombat()
    key(wheelKey)
    assert(panel.titleText:GetText():find("^Favorites"))
    key("PADLSHOULDER")
    assert(panel.titleText:GetText() == "Actions  1 / 2")
    key("PADRSHOULDER")
    assert(panel.titleText:GetText():find("^Favorites"))
    key(wheelKey)
    assert(not input:IsShown() and not panel.frame:IsShown())
    leaveCombat()
""")
lua.execute("""
    EmotePanelSavedVars = { favorites = {}, sitFavoriteAdded = true }
    for index = 1, 9 do
        table.insert(EmotePanelSavedVars.favorites, { mode = "emotes", index = index })
    end
    table.insert(EmotePanelSavedVars.favorites, 2, { mode = "professions", index = 99999 })
    gameBindings["F9"] = "CLICK EmotePanelCombatInput:Toggle"
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local panel = EmotePanel
    local settings = EmotePanelHelpPanel
    SlashCmdList.EMOTEPANEL("list")
    settings:Show()
    local function favoriteRow(index)
        for _, row in ipairs(widgets) do
            local entry = row.favoriteEntry
            if row.parent == settings.scrollFrame.content and row:IsShown() and entry
                and entry.mode == "emotes" and entry.index == index then
                return row
            end
        end
        error("Missing favorite row " .. index)
    end
    local up, down
    for _, widget in ipairs(widgets) do
        if widget.parent == settings and widget:GetText() == "Up" then up = widget end
        if widget.parent == settings and widget:GetText() == "Down" then down = widget end
    end
    favoriteRow(1):Click("LeftButton")
    assert(not up.enabled and down.enabled)
    down:Click("LeftButton")
    down:Click("LeftButton")
    local saved = EmotePanelSavedVars.favorites
    assert(saved[4].index == 1 and favoriteRow(1).selection:IsShown())
    assert(not favoriteRow(2).selection:IsShown())
    up:Click("LeftButton")
    assert(saved[1].index == 2 and saved[2].index == 99999 and saved[3].index == 1)
    favoriteRow(9):Click("LeftButton")
    assert(up.enabled and not down.enabled and not favoriteRow(1).selection:IsShown())
    up:Click("LeftButton")
    assert(saved[9].index == 9 and saved[10].index == 8 and favoriteRow(9).selection:IsShown() and down.enabled)
    reorderedName = favoriteRow(9).name:GetText():match("^(.-)  ·  ")
    settings:Hide()

    EmotePanel_Toggle()
    assert(panel.titleText:GetText() == "Favorites  1 / 2")
    panel:Select(8)
    assert(panel.selectionName:GetText() == reorderedName)
    panel:ActivateSector(8, "RightButton")
    local editor = panel.customMessageDialog
    assert(editor.placement.location:GetText():find("Favorites · Page 1 · Slot 8", 1, true))
    editor.placement.down:Click("LeftButton")
    assert(editor.placement.location:GetText():find("Favorites · Page 2 · Slot 1", 1, true))
    assert(saved[9].index == 9, "Reordering stays in the draft until Save")
    for _, widget in ipairs(widgets) do
        if widget.parent == editor and widget:GetText() == "Cancel" then widget:Click("LeftButton") end
    end
    assert(not editor:IsShown() and saved[9].index == 9)
    panel:ActivateSector(8, "RightButton")
    editor.placement.down:Click("LeftButton")
    editor.saveButton:Click("LeftButton")
    assert(saved[10].index == 9 and panel.titleText:GetText() == "Favorites  2 / 2")
    assert(panel.selected == 1 and panel.selectionName:GetText() == reorderedName)
    panel:ActivateSector(1, "RightButton")
    editor.placement.up:Click("LeftButton")
    editor.saveButton:Click("LeftButton")
    assert(saved[9].index == 9 and panel.selected == 8)
    EmotePanel_Toggle()

    combat = true
    local input = assert(panel.combatInput)
    input:combatChanged("combat")
    events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
    input:Click("Toggle", false)
    assert(panel.combatView and panel.titleText:GetText() == "Favorites  1 / 2")
    panel:Select(8)
    assert(panel.selectionName:GetText() == reorderedName)
    combat = false
    input:combatChanged("peace")
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    assert(EmotePanelSavedVars.favorites[2].index == 99999)
    EmotePanel_Toggle()
    EmotePanel:Select(8)
    assert(EmotePanel.selectionName:GetText() == reorderedName)
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local function fire(event, ...)
        assert(events.events[event])
        events.scripts.OnEvent(events, event, ...)
    end

    local originalPrint = print
    local messages = {}
    print = function(message) messages[#messages + 1] = message end
    local function expectWarning(consolePort, native, binding)
        assert(#messages == 1, "Expected one combined chat warning")
        local message = table.remove(messages)
        assert(message:match("^|cffff0000EmotePanel: .+|r$"), "The warning should be red")
        assert((message:find("Install and enable ConsolePort", 1, true) ~= nil) == consolePort)
        assert((message:find("Gamepad (Beta) is unsupported", 1, true) ~= nil) == native)
        assert((message:find("No wheel keybind is set. Assign Open or Close Emote Panel", 1, true) ~= nil) == binding)
    end

    combat, gamepadEnabled, usingGamepad, nativeGamepadUI = false, true, false, false
    consolePortLoaded, consolePortLoading = false, false
    gamepadDevices, gameBindings = {}, {}
    fire("PLAYER_ENTERING_WORLD", true, false)
    expectWarning(false, false, true)
    gameBindings = { F8 = "CLICK EmotePanelCombatInput:Toggle" }
    fire("PLAYER_ENTERING_WORLD", false, true)
    assert(#messages == 0, "A keyboard binding should clear the warning")

    gamepadDevices = { 1 }
    gameBindings = { PADPADDLE1 = "CLICK EmotePanelCombatInput:Toggle" }
    consolePortLoaded = true
    fire("PLAYER_ENTERING_WORLD", true, false)
    assert(#messages == 0, "The recommended setup with a wheel binding should not warn")

    nativeGamepadUI = true
    fire("PLAYER_ENTERING_WORLD", true, false)
    expectWarning(false, true, false)
    assert(nativeGamepadUI and not popup)
    fire("PLAYER_ENTERING_WORLD", false, false)
    fire("GAME_PAD_ACTIVE_CHANGED")
    assert(#messages == 0, "Zoning and device changes should not repeat the login warning")

    consolePortLoaded, consolePortLoading = false, true
    gameBindings = {}
    fire("PLAYER_ENTERING_WORLD", false, true)
    expectWarning(true, true, true)
    assert(nativeGamepadUI and not popup and not EmotePanel.controllerWarning)

    nativeGamepadUI, consolePortLoaded, consolePortLoading = false, true, false
    fire("PLAYER_ENTERING_WORLD", true, false)
    expectWarning(false, false, true)

    consolePortLoaded = false
    gameBindings = { PADPADDLE1 = "CLICK EmotePanelCombatInput:Toggle" }
    fire("PLAYER_ENTERING_WORLD", true, false)
    expectWarning(true, false, false)
    print = originalPrint
""")
lua.execute("""
    Minimap = Widget()
    Minimap:SetSize(198, 198)
    Minimap:SetScale(0.8)
    function Minimap:GetCenter() return 230, 250 end
    EmotePanelSavedVars.minimapAngle = nil
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local frame = EmotePanel.frame
    local button = assert(EmotePanelMinimapButton)
    assert(button:GetParent() == Minimap and button.point[2] == Minimap)
    assert(button.registeredClicks[1] == "LeftButtonUp" and button.registeredClicks[2] == "RightButtonUp")

    button:Click("LeftButton")
    assert(frame:IsShown())
    button:Click("RightButton")
    assert(not frame:IsShown() and openedCategory == EmotePanel.settingsCategoryID)
    local launch = assert(_G[addonCompartmentCallback])
    launch("EmotePanel", "LeftButton")
    assert(frame:IsShown())
    launch("EmotePanel", "LeftButton")
    assert(not frame:IsShown())
    openedCategory = nil
    combat = true
    launch("EmotePanel", "RightButton")
    assert(not openedCategory)
    combat = false
    launch("EmotePanel", "RightButton")
    assert(openedCategory == EmotePanel.settingsCategoryID)

    local versionLabel
    for _, widget in ipairs(widgets) do
        local anchor = widget.point and widget.point[2]
        if widget.point and widget.point[1] == "LEFT"
            and type(anchor) == "table" and anchor:GetText() == "EmotePanel Options" then
            versionLabel = widget
        end
    end
    assert(versionLabel and versionLabel:GetText() == "v" .. addonVersion)
    button.GetScript = function(self, name) return self.scripts[name] end
    button.scripts.OnEnter(button)
    assert(GameTooltip:IsOwned(button) and GameTooltip:GetText() == "EmotePanel v" .. addonVersion)
    button.scripts.OnDragStart(button)
    assert(not GameTooltip:IsShown())
    cursorX, cursorY = 230 * 0.8, 350 * 0.8
    button.scripts.OnUpdate(button)
    assert(math.abs(button.point[4]) < 0.001 and math.abs(button.point[5] - 99) < 0.001)
    assert(math.abs(EmotePanelSavedVars.minimapAngle - math.pi / 2) < 0.001)
    button.scripts.OnDragStop(button)
    assert(not button.scripts.OnUpdate)
""")
load_addon()
lua.execute("""
    local events = widgets[#widgets]
    events.scripts.OnEvent(events, "ADDON_LOADED", "EmotePanel")
    local button = EmotePanelMinimapButton
    assert(math.abs(button.point[4]) < 0.001 and math.abs(button.point[5] - 99) < 0.001)
""")
print("PASS: secure combat dispatch, controller warnings and glyphs, minimap and compartment launchers, settings and resets, categories, action picker and item availability, spells, items, macros and cooldowns, group commands, entry and Favorites order, navigation, visibility, and command submission")
