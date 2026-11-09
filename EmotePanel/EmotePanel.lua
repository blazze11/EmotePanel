-- EmotePanel.lua
local AddonName = "EmotePanel"
local addonVersion = C_AddOns.GetAddOnMetadata(AddonName, "Version") or "Unknown"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"
_G["BINDING_NAME_CLICK EmotePanelCombatInput:Toggle"] = "Open or Close Emote Panel"
_G["BINDING_NAME_CLICK EmotePanelCombatInput:TogglePet"] = "Open or Close Pet Wheel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

local PANEL_WIDTH, PANEL_HEIGHT = 432, 652
local WHEEL_SIZE = 382
local SECTOR_COUNT = 8
local SECTOR_ANGLE = 2 * math.pi / SECTOR_COUNT
local RANGE_CHECK_INTERVAL = 0.2
local ACTIONS_TITLE = "Actions"
local PET_TITLE = "Pet"
local WHEEL_ATLAS = "gamepad-radial-menu-wheelbg"
local SELECTION_ATLAS = "gamepad-radial-menu-selected"
local ICON_BORDER = "gamepad-actionbar-circleslot-border-normal"
local SELECTED_ICON_BORDER = "gamepad-actionbar-circleslot-border-selected"
local ICON_PATH = "Interface\\Icons\\"
local PANEL_ATLAS = "gamepad-footer-slot-bg"
local PANEL_BORDER_ATLAS = "gamepad-footer-slot-frameneutral"
local FOCUS_ATLAS = "gamepad-footer-slot-framefocused"
local LAUNCHER_ICON = "gamepad-radial-icon-chat"
local SIT_INDEX = 30 -- Favorites store the original emote slot number.
local SELECTION_CHAT_TYPES = { emote = "TEXT_EMOTE", say = "SAY", party = "PARTY" }
local SELECTION_COLORS = {
    emote = { 1, 0.5, 0.25 },
    say = { 1, 1, 1 },
    party = { 0.67, 0.67, 1 },
    command = { 0.82, 0.54, 1 },
    panel = { 0.42, 0.95, 0.83 },
    profession = { 1, 0.61, 0.32 },
    pet = { 0.9, 0.55, 1 },
}
local COMBAT_DISABLED_COLOR = { 0.55, 0.55, 0.55 }
local PET_AUTOCAST_SELECTION_ON = { 1, 0.76, 0.35 }
local PET_AUTOCAST_SELECTION_OFF = { 0.44, 0.71, 1 }
local PET_ACTIVE_GLOW = { 0.67, 0.94, 0.4, 0.9 }
local PET_AUTOCAST_GLOW = { 1, 0.76, 0.35, 0.85 }

local GLYPH_STYLES = {
    xbox = {
        name = "Xbox", prefix = "gamepad-xbox1-",
        icons = {
            PAD1 = "buttona", PAD2 = "buttonb", PAD3 = "buttonx", PAD4 = "buttony",
            PADLSHOULDER = "trigger-lb", PADRSHOULDER = "trigger-rb",
            PADLSTICKAXIS = "stick-l", PADRSTICKAXIS = "stick-r",
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

local function GamepadGlyph(key, fallback, size)
    local style = GLYPH_STYLES[EmotePanelSavedVars.controllerGlyphs]
    local atlas = style and GetStyleAtlas(style, key)
    local icons = InputIconTextureSetUtility
    if not atlas and icons and icons.GetActiveInputIconButtonTextures(key) then
        atlas = icons.GetNormalActiveInputIconButtonTexture(key)
    end
    if type(atlas) ~= "string" then atlas = GetStyleAtlas(GLYPH_STYLES.xbox, key) end
    if atlas then return CreateAtlasMarkup(atlas, size or 32, size or 32) end
    return fallback
end

local function SetGlyphPrompt(fontString, render)
    glyphPrompts[fontString] = render
    fontString:SetText(render())
end

local DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
local ANCHOR_OFFSETS = {
    TOPLEFT = {-0.5, 0.5}, TOP = {0, 0.5}, TOPRIGHT = {0.5, 0.5},
    LEFT = {-0.5, 0}, CENTER = {0, 0}, RIGHT = {0.5, 0},
    BOTTOMLEFT = {-0.5, -0.5}, BOTTOM = {0, -0.5}, BOTTOMRIGHT = {0.5, -0.5},
}

local function GetIconPath(icon)
    if type(icon) == "number" or icon:find("\\", 1, true) or icon:sub(1, 6) == "atlas:" then return icon end
    return ICON_PATH .. icon
end

local function SetIconTexture(texture, icon, crop)
    local atlas = type(icon) == "string" and icon:match("^atlas:(.+)$")
    if atlas then
        texture:SetAtlas(atlas)
    else
        texture:SetTexture(icon)
        if crop and (type(icon) == "number" or icon:lower():find(ICON_PATH:lower(), 1, true)) then
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function GetEntryIcon(mode, index, data)
    local overrides = EmotePanelSavedVars.customIcons
    local icon = overrides and overrides[mode] and overrides[mode][index]
    if type(icon) == "number" and icon > 0 or type(icon) == "string" and icon ~= "" then
        return GetIconPath(icon)
    end
    return GetIconPath(data.icon)
end

local function SaveEntryIcon(mode, index, icon)
    local overrides = EmotePanelSavedVars.customIcons
    overrides[mode] = overrides[mode] or {}
    overrides[mode][index] = icon
end

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



local function OpenSettings()
    if EmotePanel.combatView then return end
    EmotePanel.frame:Hide()
    Settings.OpenToCategory(EmotePanel.settingsCategoryID)
end

local function RunOnTargetPlayer(action)
    if not UnitIsHumanPlayer("target") then return end
    local name = GetUnitName("target", true)
    if not issecretvalue(name) and name and name ~= "" then
        action(name)
    end
end

local function OpenWho()
    if Kiosk.IsEnabled() or C_GameRules.IsGameRuleActive(Enum.GameRule.IngameWhoListDisabled) then return end
    local query = WhoFrame_GetDefaultWhoCommand()
    ShowWhoPanel()
    WhoFrameEditBox:SetText(query)
    C_FriendList.SendWho(query, Enum.SocialWhoOrigin.Chat)
end

local function MarkTarget(marker)
    local current = GetRaidTargetIndex("target")
    -- A secret marker can only use the native toggle behavior.
    if issecretvalue(current) or current ~= marker then
        SetRaidTarget("target", marker)
    end
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
            { name = "Talk",     action = "talk",      actionType = "emote", icon = "atlas:gamepad-radial-icon-chat" },
            { name = "Thank",    action = "thank",     actionType = "emote", icon = "INV_Misc_Gift_01" },
            { name = "Threaten", action = "threaten",  actionType = "emote", icon = "Ability_Physical_Taunt_purple" },
            { name = "Wave",     action = "wave",      actionType = "emote", icon = "Spell_Holy_LayOnHands" },
            { name = "Yes",      action = "nod",       actionType = "emote", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "Sit",      action = "sit",       actionType = "emote", icon = "INV_FISHINGCHAIR" },
        }
    },
    -- Saved chat overrides and favorites refer to the slots in these two lists. Append new messages.
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",              action = "hey o/",                   actionType = "say", icon = "Spell_Misc_EmotionHappy" },
            { name = "Well played",         action = "nice one!",                actionType = "say", icon = "Achievement_General_StayClassy" },
            { name = "Thanks",              action = "ty, appreciate it",        actionType = "say", icon = "INV_Misc_GiftWrap_01" },
            { name = "No problem",          action = "np :)",                    actionType = "say", icon = "Spell_Holy_BlessingOfProtection" },
            { name = "BRB",                 action = "brb, one sec",             actionType = "say", icon = "INV_Misc_PocketWatch_01" },
            { name = "Bye",                 action = "cya!",                     actionType = "say", icon = "INV_Garrison_Hearthstone" },
            { name = "LFG nearby",          action = "anyone wanna group up?",   actionType = "say", icon = "atlas:gamepad-radial-icon-groupfinder" },
            { name = "Quest",               action = "you on this quest too?",   actionType = "say", icon = "atlas:gamepad-radial-icon-quests" },
            { name = "Gratz",               action = "grats!",                   actionType = "say", icon = "INV_Misc_CelebrationCake_01" },
            { name = "Trade",               action = "wanna trade?",             actionType = "say", icon = "INV_Misc_Coin_01" },
            { name = "Mind if I sit?",      action = "mind if i sit here?",      actionType = "say", icon = "INV_FISHINGCHAIR" },
            { name = "Join the Fire",       action = "come hang by the fire :)", actionType = "say", icon = "INV_Camelot_Camping_WelcomingCampfire" },
            { name = "Thanks for the Fire", action = "ty for the fire!",         actionType = "say", icon = "INV_Drink_08" },
            { name = "How's Leveling?",     action = "how's leveling going?",    actionType = "say", icon = "inv_misc_map02" },
            { name = "Offer Help",          action = "need a hand with that?",   actionType = "say", icon = "Spell_Holy_Heal" },
            { name = "Offer Food",          action = "anyone need food?",        actionType = "say", icon = "INV_Misc_Food_57" },
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me",      action = "this way",                     actionType = "party", icon = "Ability_Hunter_Pathfinding" },
            { name = "Need Break",     action = "quick bio break?",             actionType = "party", icon = "INV_Drink_05" },
            { name = "Thanks Group",   action = "gg, ty for the run!",          actionType = "party", icon = "INV_Misc_GiftWrap_02" },
            { name = "Good Job",       action = "nice one, team",               actionType = "party", icon = "Achievement_Level_10" },
            { name = "Ready?",         action = "rdy for next?",                actionType = "party", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "OOM",            action = "oom, drinking",                actionType = "party", icon = "INV_Potion_76" },
            { name = "Wait",           action = "hold up, wait for everyone",   actionType = "party", icon = "INV_Misc_PocketWatch_02" },
            { name = "Pulling",        action = "pulling now",                  actionType = "party", icon = "Ability_Hunter_SniperShot" },
            { name = "CC",             action = "can someone cc my target?",    actionType = "party", icon = "Spell_Nature_Polymorph" },
            { name = "Help",           action = "need a hand here",             actionType = "party", icon = "Spell_Holy_Resurrection" },
            { name = "Ready",          action = "ready when you are",           actionType = "party", icon = "Ability_Warrior_Vigilance" },
            { name = "My Bad",         action = "my bad",                       actionType = "party", icon = "Spell_Misc_EmotionSad" },
            { name = "Adds",           action = "got adds",                     actionType = "party", icon = "Ability_Warrior_BattleShout" },
            { name = "Interrupt",      action = "kick next cast pls",           actionType = "party", icon = "Ability_Kick" },
            { name = "Need a Rez",     action = "can i get a rez?",             actionType = "party", icon = "Spell_Holy_Redemption" },
            { name = "Campfire Break", action = "wanna stop at that campfire?", actionType = "party", icon = "INV_Camelot_Camping_CampfireNearby" },
        }
    },
    commands = {
        title = "Commands",
        list = {
            -- Saved commands and favorites refer to these slot numbers. Append new entries.
            { name = "Invite Target",   action = "invite",     actionType = "command", icon = "atlas:friendslist-invitebutton-default-normal",
                preview = "Invite the targeted player to your group",
                run = function() RunOnTargetPlayer(C_PartyInfo.InviteUnit) end },
            { name = "Inspect Target",  action = "inspect",    actionType = "command", icon = "INV_Professions_Inscription_ScribesMagnifyingGlass_Gold",
                preview = "Open the target's inspection window",
                run = function() InspectUnit("target") end },
            { name = "Trade Target",    action = "trade",      actionType = "command", icon = "INV_Misc_Coin_02",
                preview = "Request a trade with your target",
                run = function() InitiateTrade("target") end },
            { name = "Follow Target",   action = "follow",     actionType = "command", icon = "Ability_Tracking",
                preview = "Follow your target",
                run = function() FollowUnit("") end },
            { name = "Befriend Target", action = "friend",     actionType = "command", icon = "atlas:friends-icon-addFriend",
                preview = "Add the targeted player to your friends list",
                run = function()
                    if C_GameRules.IsGameRuleActive(Enum.GameRule.IngameFriendsListDisabled) then return end
                    if not UnitIsHumanPlayer("target") then
                        ToggleFriendsPanel()
                    elseif C_FriendList.IsLegacyFriendSystemEnabled() then
                        RunOnTargetPlayer(C_FriendList.AddFriend)
                    end
                end },
            { name = "Roll",            action = "roll",       actionType = "command", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
                preview = "Roll a number from 1 to 100",
                run = function() RandomRoll(1, 100) end },
            { name = "Ready Check",     action = "readycheck", actionType = "command", icon = "Interface\\RaidFrame\\ReadyCheck-Ready",
                preview = "Start a ready check as group leader or assistant",
                run = function()
                    if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then C_PartyInfo.DoReadyCheck() end
                end },
            { name = "Who",             action = "who",        actionType = "command", icon = "INV_SideTab_WhoList_c60",
                preview = "Open the Who list and search nearby levels in this zone",
                run = OpenWho },
            { name = "Chat Channels",   action = "leave",      actionType = "command", icon = "atlas:chatframe-button-icon-voicechat",
                preview = "Open Chat Channels",
                run = function() ToggleChannelFrame() end },
            { name = "Reload UI",       action = "reload",     actionType = "command", icon = "INV_Misc_Gear_01",
                preview = "Reload the game interface",
                run = ReloadUI },
            { name = "Pull in 5s",      action = (SLASH_COUNTDOWN1 or "/countdown") .. " 5", actionType = "command", icon = "INV_Misc_PocketWatch_01",
                preview = "Start a 5-second pull countdown",
                run = function() C_PartyInfo.DoCountdown(5) end },
            { name = "Pull in 10s",     action = (SLASH_COUNTDOWN1 or "/countdown") .. " 10", actionType = "command", icon = "INV_Misc_PocketWatch_03",
                preview = "Start a 10-second pull countdown",
                run = function() C_PartyInfo.DoCountdown(10) end },
            { name = "Mark Skull",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " !8", actionType = "command", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8",
                preview = "Mark your target with Skull",
                run = function() MarkTarget(8) end },
            { name = "Mark Cross",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " !7", actionType = "command", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7",
                preview = "Mark your target with Cross",
                run = function() MarkTarget(7) end },
            { name = "Clear Mark",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " 0", actionType = "command", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady",
                preview = "Remove the raid marker from your target",
                run = function() SetRaidTarget("target", 0) end },
            { name = "Dismount",        action = SLASH_DISMOUNT1 or "/dismount", actionType = "command", icon = "Ability_Mount_RidingHorse",
                preview = "Dismount from your current mount",
                run = function() Dismount() end },
            { name = "Settings",        action = "ep config", actionType = "command", icon = "atlas:gamepad-radial-icon-gamemenu",
                preview = "Open EmotePanel settings",
                run = OpenSettings },
            { name = "Leave Group",     action = "leavegroup", actionType = "command", icon = "atlas:128-redbutton-exit",
                preview = "Leave your current party or raid",
                available = IsInGroup,
                run = function()
                    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
                        if ConfirmOrLeaveParty then
                            ConfirmOrLeaveParty()
                        else
                            C_PartyInfo.LeaveParty(LE_PARTY_CATEGORY_INSTANCE)
                        end
                    else
                        C_PartyInfo.LeaveParty()
                    end
                end },
        }
    }
}

-- Favorites and icon overrides use these slots. Append new shortcuts.
PANEL_MODES.panels = {
    title = "Game Panels",
    list = {
        { name = "Character Info", icon = "atlas:gamepad-radial-icon-character", secureClick = "CharacterMicroButton" },
        { name = "Spellbook", icon = "atlas:gamepad-radial-icon-spellbook", open = function() PlayerSpellsUtil.ToggleSpellBookFrame() end },
        { name = "Talents", icon = "atlas:gamepad-radial-icon-talents", open = function() PlayerSpellsUtil.ToggleClassTalentOrSpecFrame() end },
        { name = "Legacy", icon = "atlas:gamepad-radial-icon-legacy", open = function() ToggleLegacySystemUI() end },
        { name = "Quest Log", icon = "atlas:gamepad-radial-icon-quests", open = function() ToggleQuestLog() end },
        { name = "Guilds & Communities", icon = "atlas:gamepad-radial-icon-communities", open = function() ToggleGuildFrame() end },
        { name = "Group Finder", icon = "atlas:gamepad-radial-icon-groupfinder", open = function() ToggleGroupFinderFrame() end },
        { name = "Account Collections", icon = "atlas:gamepad-radial-icon-collections", open = function() ToggleCollectionsJournal() end },
        { name = "Mounts", icon = "INV_Horse3Saddle008_Chestnut", open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_MOUNTS) end },
        { name = "Pets", icon = "INV_ArfusPet_Classic", open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS) end },
        { name = "Toys", icon = "INV_SideTab_ToyBox_c60", open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_TOYS) end },
        { name = "Calendar", icon = "atlas:gamepad-radial-icon-calendar", open = function() ToggleCalendar() end },
        { name = "Friends", icon = "atlas:gamepad-radial-icon-social", open = function() ToggleFriendsFrame(FRIEND_TAB_FRIENDS) end },
        { name = "Inventory", icon = "atlas:gamepad-radial-icon-bags", open = function() ToggleAllBags() end },
        { name = "World Map", icon = "inv_misc_map02", open = function() ToggleWorldMap() end },
    },
}
for _, entry in ipairs(PANEL_MODES.panels.list) do
    entry.actionType = "panel"
end

local modeOrder = { "emotes", "chat", "party", "commands", "panels" }
local categoryOrder = { "emotes", "voicedEmotes", "chat", "party", "commands", "panels" }
local voicedEmoteTitle = "Voiced Emotes"
local voicedEmoteTokens, nativeEmotes, nativeEmoteIDs = {}, {}, {}
local customEntryTypes = {
    emotes = { actionType = "emote", icon = "Spell_Misc_EmotionHappy", label = "Emote" },
    chat = { actionType = "say", icon = "atlas:gamepad-radial-icon-chat", label = "Say" },
    party = { actionType = "party", icon = "atlas:gamepad-radial-icon-communities", label = "Party" },
    commands = { actionType = "command", icon = "INV_Misc_Gear_01", label = "Command" },
}
local categoryPages = {}
-- The Actions ring keeps the saved "macros" category key for order, icons and favorites.
local actionsByID, actionIDs = {}, {}
local carriedActionItems = {}
local petActions = {}
local petEntries = {}
local petPages = {}
local petUnavailableReason
local characterGUID
local professionPage = { mode = "professions", title = "Professions", count = 0, entries = {} }
local categoryEntries = {
    { category = "favorites", name = "Favorites", icon = "atlas:collections-icon-favorites" },
    { category = "emotes", name = "Emotes", icon = "Spell_Misc_EmotionHappy", actionType = "emote" },
    { category = "voicedEmotes", name = voicedEmoteTitle, icon = "Ability_Warrior_BattleShout", actionType = "emote" },
    { category = "chat", name = "Say Chat", icon = "atlas:gamepad-radial-icon-chat", actionType = "say" },
    { category = "party", name = "Party Chat", icon = "atlas:gamepad-radial-icon-communities", actionType = "party" },
    { category = "commands", name = "Commands", icon = "INV_Misc_Gear_01", actionType = "command" },
    { category = "panels", name = "Game Panels", icon = "atlas:gamepad-radial-icon-character", actionType = "panel" },
    { category = "professions", name = "Professions", icon = "INV_Misc_Note_06", actionType = "profession" },
}
local categoryByID = {}
for _, entry in ipairs(categoryEntries) do categoryByID[entry.category] = entry end
local categoryWheel
local learnedProfessions = {}
local professionsBySkillLine = {}
local currentPageIndex, currentPage
local favorites, visibleFavorites
local grouped

local function IsCategoryWheelEnabled()
    return EmotePanelSavedVars.categoryWheel ~= false
end

local function GetStorageMode(category)
    return category == "voicedEmotes" and "emotes" or category
end

local function GetEmoteToken(data)
    if data.token then return data.token end
    local alias = data.action:upper()
    return (hash_EmoteTokenList and hash_EmoteTokenList["/" .. alias]) or (alias == "BRAVO" and "APPLAUD") or alias
end

local function LoadNativeEmotes()
    local labels = {}
    local skipTokens = { FORTHEALLIANCE = true, FORTHEHORDE = true, LEAN = true }
    for index = 1, MAXEMOTEINDEX or 0 do
        local prefix = "EMOTE" .. index
        local token = _G[prefix .. "_TOKEN"]
        if token and not labels[token] then labels[token] = _G[prefix .. "_CMD1"] end
    end
    for _, data in ipairs(PANEL_MODES.emotes.list) do skipTokens[GetEmoteToken(data)] = true end
    for _, token in ipairs(TextEmoteSpeechList or {}) do voicedEmoteTokens[token] = true end

    local icons = {
        BEG = "INV_Misc_Coin_01", CHICKEN = "INV_Misc_Food_15", EAT = "INV_Misc_Food_57",
        SHY = "Spell_Misc_EmotionAfraid", SLEEP = "INV_MISC_NightelfBedroll",
        HELPME = "Spell_Holy_Resurrection", INCOMING = "Ability_Hunter_MarkedForDeath",
        CHARGE = "Ability_Warrior_Charge", FLEE = "Ability_Rogue_Sprint",
        ATTACKMYTARGET = "Ability_Hunter_Assassinate", OOM = "INV_Potion_76",
        FOLLOW = "Ability_Hunter_Pathfinding", WAIT = "INV_Misc_PocketWatch_02",
        HEALME = "Spell_Holy_Heal", OPENFIRE = "Ability_Hunter_SniperShot",
        HELLO = "Spell_Holy_LayOnHands", WELCOME = "Spell_Misc_EmotionHappy",
        CONGRATULATE = "INV_Misc_CelebrationCake_01", FLIRT = "Spell_Shadow_SoothingKiss",
        JOKE = "INV_Helm_LaughingSkull_01", RASP = "INV_Misc_Horn_01", TRAIN = "Ability_Foundryraid_TrainDeath",
    }
    local names = {
        HELPME = "Help Me", ATTACKMYTARGET = "Attack My Target", OOM = "Out of Mana",
        FOLLOW = "Follow Me", HEALME = "Heal Me", OPENFIRE = "Open Fire", JOKE = "Silly",
    }
    local function AddEmotes(tokens)
        for _, token in ipairs(tokens) do
            local id = "native:" .. token
            if not skipTokens[token] and not nativeEmotes[id] then
                local action = (labels[token] or token:lower()):gsub("^/", "")
                nativeEmotes[id] = {
                    name = names[token] or (action:gsub("^%l", string.upper)),
                    action = action,
                    actionType = "emote",
                    token = token,
                    icon = icons[token] or 3750314,
                }
                table.insert(nativeEmoteIDs, id)
            end
        end
    end
    AddEmotes(EmoteList or {})
    AddEmotes(TextEmoteSpeechList or {})
end

local function ReadLearnedProfessions(...)
    local entries, seen = {}, {}
    for slot = 1, select("#", ...) do
        local index = select(slot, ...)
        if index then
            local name, icon, rank, maxRank, spells, offset, skillLine = GetProfessionInfo(index)
            if name and skillLine and skillLine > 0 and not seen[skillLine] then
                seen[skillLine] = true
                local canCraft = false
                for spell = 1, spells do
                    local info = C_SpellBook.GetSpellBookItemInfo(offset + spell, Enum.SpellBookSpellBank.Player)
                    if info and info.spellID and C_TradeSkillUI.CanTradeSkillShowCraftingUI(info.spellID) then
                        canCraft = true
                        break
                    end
                end
                entries[#entries + 1] = {
                    skillLine = skillLine,
                    name = name,
                    icon = icon or "INV_Misc_QuestionMark",
                    rank = rank,
                    maxRank = maxRank,
                    isPrimary = slot <= 2,
                    canCraft = canCraft,
                    actionType = "profession",
                }
            end
        end
    end
    return entries
end

local function GetEntryData(mode, index)
    if mode == "categories" then return categoryByID[index] end
    if mode == "macros" then return actionsByID[index] end
    if mode == "pet" then return petEntries[index] end
    if mode == "professions" then return professionsBySkillLine[index] end
    if mode == "emotes" and type(index) == "string" then return nativeEmotes[index] end
    local config = PANEL_MODES[mode]
    if config and type(index) == "number" and index < 0 then
        local entries = EmotePanelSavedVars.entries[mode]
        return entries and entries[-index]
    end
    return config and config.list[index]
end

local function GetDirectActionKey(kind, id)
    return kind .. ":" .. characterGUID .. ":" .. id
end

local function ReadActions()
    wipe(actionsByID)
    wipe(actionIDs)
    local accountCount, characterCount = GetNumMacros()
    local accountLimit = (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS)
        or MAX_ACCOUNT_MACROS
    if not characterGUID then
        local character = UnitGUID("player")
        if not (issecretvalue and issecretvalue(character)) and character then characterGUID = character end
    end
    local function ReadScope(first, count, prefix, scope)
        for index = first, first + count - 1 do
            local name, icon = GetMacroInfo(index)
            if name and name ~= "" then
                local id = prefix .. name:lower()
                if actionsByID[id] == nil then
                    table.insert(actionIDs, id)
                    actionsByID[id] = {
                        name = name, icon = icon or "INV_Misc_QuestionMark", macroIndex = index,
                        preview = scope .. " macro", actionType = "macro",
                    }
                else
                    -- A saved name must resolve to exactly one macro in its scope.
                    actionsByID[id] = false
                end
            end
        end
    end
    ReadScope(1, accountCount, "account:", "Account")
    if accountLimit and characterGUID then
        ReadScope(accountLimit + 1, characterCount, characterGUID .. ":", "Character")
    end
    for _, data in ipairs(EmotePanelSavedVars.directActions[characterGUID] or {}) do
        local key = GetDirectActionKey(data.actionType, data.actionID)
        actionsByID[key] = data
        table.insert(actionIDs, key)
    end
end

local function RefreshCarriedActionItems()
    local changed = false
    for _, data in ipairs(EmotePanelSavedVars.directActions[characterGUID] or {}) do
        if data.actionType == "item" then
            local id = data.actionID
            local count = C_Item.GetItemCount(id)
            local available = not issecretvalue(count) and count > 0
            if not available then
                local equipped = C_Item.IsEquippedItem(id)
                available = not issecretvalue(equipped) and equipped
            end
            if available ~= carriedActionItems[id] then
                carriedActionItems[id] = available
                changed = true
            end
        end
    end
    return changed
end

local function ReadPetActions()
    wipe(petActions)
    wipe(petEntries)
    petUnavailableReason = nil
    if not EmotePanel.supportsPetWheel then return end
    if C_ActionBar.HasVehicleActionBar() then
        petUnavailableReason = "Pet actions unavailable in a vehicle"
        return
    end
    local hasBar, visible, dead = PetHasActionBar(), UnitIsVisible("pet"), UnitIsDead("pet")
    if not issecretvalue(dead) and dead then petUnavailableReason = "Pet is dead" end
    if issecretvalue(hasBar) or issecretvalue(visible) or issecretvalue(dead) or not hasBar or not visible or dead then return end
    for slot = 1, NUM_PET_ACTION_SLOTS do
        local name, icon, isToken, isActive, canAutocast, autocast, spellID = GetPetActionInfo(slot)
        if not (issecretvalue(name) or issecretvalue(icon) or issecretvalue(isToken)) and name then
            local active = not issecretvalue(isActive) and not not isActive
            local movePending
            if isToken and name == "PET_ACTION_MOVE_TO" then
                local pending = C_PetInfo.IsPetOrderMoveToPending()
                movePending = not issecretvalue(pending) and pending
                active = active or movePending
            end
            local token = isToken and name
            if isToken then name, icon = _G[name], _G[icon] end
            if type(name) == "string" and name ~= "" then
                local key = token and "token:" .. token
                    or not issecretvalue(spellID) and type(spellID) == "number" and spellID > 0 and "spell:" .. spellID
                    or "name:" .. name
                if issecretvalue(autocast) then
                    autocast = nil
                else
                    autocast = not not autocast
                end
                local attack = active and IsPetAttackAction(slot)
                petActions[slot] = {
                    key = key, name = name, icon = icon or "INV_Misc_QuestionMark", actionType = "pet", actionID = slot,
                    canAutocast = not issecretvalue(canAutocast) and not not canAutocast,
                    autocast = autocast,
                    active = active,
                    movePending = movePending,
                    attacking = not issecretvalue(attack) and attack,
                }
                petEntries[key] = petEntries[key] or petActions[slot]
            end
        end
    end
end

local function GetPetAutocastMacro(data)
    local command = SLASH_PET_AUTOCASTTOGGLE1 or "/petautocasttoggle"
    if data.canAutocast and not data.name:find("[%c;%[%]]") and IsSecureCmd(command) then
        return command .. " " .. data.name
    end
end

local function ForEachEntry(category, callback)
    if category == "categories" then
        for _, entry in ipairs(categoryEntries) do callback(entry.category, entry) end
        return
    end
    if category == "macros" then
        for _, id in ipairs(actionIDs) do
            if actionsByID[id] then callback(id, actionsByID[id]) end
        end
        return
    end
    if category == "pet" then
        for slot = 1, NUM_PET_ACTION_SLOTS do
            local data = petActions[slot]
            if data and petEntries[data.key] == data then callback(data.key, data) end
        end
        return
    end
    if category == "professions" then
        for _, data in ipairs(learnedProfessions) do callback(data.skillLine, data) end
        return
    end
    local mode = GetStorageMode(category)
    local function Add(index, data)
        if mode ~= "emotes" or (voicedEmoteTokens[GetEmoteToken(data)] == true) == (category == "voicedEmotes") then
            callback(index, data)
        end
    end
    for index, data in ipairs(PANEL_MODES[mode].list) do Add(index, data) end
    if mode == "emotes" then
        for _, id in ipairs(nativeEmoteIDs) do Add(id, nativeEmotes[id]) end
    end
    for index, data in ipairs(EmotePanelSavedVars.entries[mode] or {}) do Add(-index, data) end
end

local function IsEntryHidden(mode, index)
    if mode == "macros" then return not EmotePanelSavedVars.selectedMacros[index] end
    local hidden = EmotePanelSavedVars.hiddenEntries[mode]
    return hidden and hidden[index]
end

local function IsEntryAvailable(data)
    return data and (not data.available or data.available()) and (data.actionType ~= "item" or carriedActionItems[data.actionID])
end

local function IsEntryVisible(mode, index)
    return not IsEntryHidden(mode, index) and IsEntryAvailable(GetEntryData(mode, index))
end

local function SaveEntryVisibility(mode, index, shown)
    if mode == "macros" then
        EmotePanelSavedVars.selectedMacros[index] = shown and true or nil
    else
        local hidden = EmotePanelSavedVars.hiddenEntries
        hidden[mode] = hidden[mode] or {}
        hidden[mode][index] = not shown or nil
    end
end

local function GetOrderedEntryIDs(category, keepUnavailable)
    local defaultOrder, available = {}, {}
    ForEachEntry(category, function(index)
        table.insert(defaultOrder, index)
        available[index] = true
    end)

    local savedOrder = EmotePanelSavedVars.entryOrder[category]
    if type(savedOrder) ~= "table" then return defaultOrder end

    local entries, seen = {}, {}
    local function Add(index)
        if seen[index] then return end
        seen[index] = true
        table.insert(entries, index)
    end
    for _, index in ipairs(savedOrder) do
        if (type(index) == "number" or type(index) == "string") and (available[index] or keepUnavailable) then
            Add(index)
        end
    end
    for _, index in ipairs(defaultOrder) do Add(index) end
    return entries
end

local function GetVisibleEntryIDs(category)
    local mode = GetStorageMode(category)
    local entries = {}
    for _, index in ipairs(GetOrderedEntryIDs(category)) do
        if IsEntryVisible(mode, index) then table.insert(entries, index) end
    end
    return entries
end

local function BuildPetPages()
    if not EmotePanel.supportsPetWheel then return end
    EmotePanel.combatLayoutDirty = true
    local entries = GetVisibleEntryIDs("pet")
    local previous = petPages[1] and petPages[1].entries
    if previous and #previous == #entries then
        for index, key in ipairs(entries) do
            if previous[index] ~= key then
                previous = nil
                break
            end
        end
        -- Status changes should leave presses on the current page intact.
        if previous then return end
    end
    wipe(petPages)
    -- Pet pages use negative IDs so main-wheel paging never visits them.
    local count = math.max(1, math.ceil(#entries / SECTOR_COUNT))
    for page = 1, count do
        local first = (page - 1) * SECTOR_COUNT + 1
        petPages[page] = {
            mode = "pet", first = first, entries = entries, count = math.min(SECTOR_COUNT, #entries - first + 1),
            title = count == 1 and PET_TITLE or ("%s  %d / %d"):format(PET_TITLE, page, count),
            left = page > 1 and 1 - page or nil,
            right = page < count and -page - 1 or nil,
        }
    end
end

local function SwapOrder(order, entry, neighbor)
    local from, to
    for position, id in ipairs(order) do
        if id == entry then from = position end
        if id == neighbor then to = position end
    end
    if not (from and to) then return false end
    order[from], order[to] = order[to], order[from]
    return true
end

local function MoveOrderedEntry(category, index, neighbor)
    if not neighbor then return false end
    -- Retain saved positions for entries that are unavailable on this character.
    local order = GetOrderedEntryIDs(category, true)
    if not SwapOrder(order, index, neighbor) then return false end
    EmotePanelSavedVars.entryOrder[category] = order
    return true
end

local function BuildCategoryPages()
    wipe(categoryPages)
    local function AddPages(category, title)
        local mode = GetStorageMode(category)
        local entries = GetVisibleEntryIDs(category)
        local pageCount = math.ceil(#entries / SECTOR_COUNT)
        for page = 1, pageCount do
            -- Actions advance left from the opening page.
            local number = mode == "macros" and pageCount - page + 1 or page
            local first = (number - 1) * SECTOR_COUNT + 1
            local pageIndex = mode == "panels" and number or #categoryPages + 1
            table.insert(categoryPages, pageIndex, {
                mode = mode,
                category = category,
                first = first,
                entries = entries,
                count = math.min(SECTOR_COUNT, #entries - first + 1),
                title = ("%s  %d / %d"):format(title, number, pageCount),
            })
        end
    end
    for _, category in ipairs(categoryOrder) do
        AddPages(category, category == "voicedEmotes" and voicedEmoteTitle or PANEL_MODES[category].title)
    end
    table.insert(categoryPages, professionPage)
    AddPages("macros", ACTIONS_TITLE)
end

local function RefreshVisibleFavorites()
    EmotePanel.combatLayoutDirty = true
    visibleFavorites = {}
    for _, entry in ipairs(favorites) do
        if IsEntryVisible(entry.mode, entry.index) then
            table.insert(visibleFavorites, entry)
        end
    end
end

local function RefreshProfessionPage()
    professionPage.entries = GetVisibleEntryIDs("professions")
    professionPage.count = #professionPage.entries
end

local function RefreshProfessions()
    learnedProfessions = ReadLearnedProfessions(GetProfessions())
    professionsBySkillLine = {}
    for _, entry in ipairs(learnedProfessions) do
        professionsBySkillLine[entry.skillLine] = entry
    end
    RefreshProfessionPage()
    RefreshVisibleFavorites()
end

local function FavoritePageCount()
    return math.max(1, math.ceil(#visibleFavorites / SECTOR_COUNT))
end

local function GetPage(index)
    if index < 0 then return petPages[-index] end
    local count = FavoritePageCount()
    if index > count then return categoryPages[index - count] end
    local first = (index - 1) * SECTOR_COUNT + 1
    return {
        mode = "favorites",
        first = first,
        count = math.min(SECTOR_COUNT, #visibleFavorites - first + 1),
        title = count == 1 and "Favorites" or ("Favorites  %d / %d"):format(index, count),
    }
end

local function GetCategoryPageRange(category)
    local offset = FavoritePageCount()
    if category == "favorites" then return 1, offset end
    local first, last
    for index, page in ipairs(categoryPages) do
        if (page.category or page.mode) == category then
            first = first or index + offset
            last = index + offset
        end
    end
    return first, last
end

local function GetScrollPages(index, page, nested)
    if page.mode == "pet" then return page.right, page.left end
    if page.mode == "categories" then
        local _, firstActions = GetCategoryPageRange("macros")
        return firstActions, nil
    end
    if not index then return end

    if page.mode == "macros" then
        -- Actions are stored in reverse order for the controller's left shortcut.
        local last, first = GetCategoryPageRange("macros")
        local previous = index < first and index + 1 or (nested and 0 or last - 1)
        return index > last and index - 1 or nil, previous
    end
    if nested then
        local first, last = GetCategoryPageRange(page.category or page.mode)
        return index < last and index + 1 or nil, index > first and index - 1 or nil
    end
    -- Favorites-first is a single list. Scroll through Actions in page-number order at its end.
    local lastActions, firstActions = GetCategoryPageRange("macros")
    local last = lastActions and lastActions - 1 or FavoritePageCount() + #categoryPages
    return index < last and index + 1 or firstActions, index > 1 and index - 1 or nil
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
            if type(entry) == "table" then
                -- Keep character-specific favorites even when the entry is unavailable.
                local valid = GetEntryData(entry.mode, entry.index) or
                    (entry.mode == "professions" and type(entry.index) == "number" and entry.index > 0 and entry.index % 1 == 0) or
                    (entry.mode == "macros" and type(entry.index) == "string")
                if valid and not FindFavorite(entry.mode, entry.index) then
                    table.insert(favorites, { mode = entry.mode, index = entry.index })
                end
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

local function GetSectorEntry(sector, page)
    page = page or currentPage
    if not sector or sector < 1 or sector > page.count then return end
    if page.mode == "pet" and page.actions then
        -- Keep the secure mapping to native slots and show what each slot currently does.
        local slot = page.actions[sector].value
        local data = slot and petActions[slot]
        if data then return "pet", data.key, data end
        return
    end
    if page.snapshot then return unpack(page.snapshot[sector]) end
    local mode = page.mode
    if mode == "categories" then
        local id = page.entries[sector]
        return mode, id, GetEntryData(mode, id)
    end
    local index = (page.first or 1) + sector - 1
    if mode == "favorites" then
        local entry = visibleFavorites[index]
        mode, index = entry.mode, entry.index
    else
        index = page.entries[index]
    end
    return mode, index, GetEntryData(mode, index)
end

function EmotePanel:RememberAction(sector)
    if not EmotePanelSavedVars.rememberLastAction then return end
    local mode, key, data = GetSectorEntry(sector)
    if not data then return end
    local last = { pageMode = currentPage.mode, mode = mode, key = key }
    if mode == "pet" then
        self.lastPetAction = last
    else
        self.lastAction = last
    end
    if not self.combatView then self:SyncCombatResume() end
end

function EmotePanel:FindRememberedSector(page)
    local last = page.mode == "pet" and self.lastPetAction or self.lastAction
    if not last or last.pageMode ~= page.mode then return end
    for sector = 1, page.count do
        local mode, key, data = GetSectorEntry(sector, page)
        if mode == last.mode and key == last.key and data then
            return sector
        end
    end
end

local function IsSecureWheelAction(data)
    return data.actionType == "macro" or data.actionType == "spell" or data.actionType == "item" or data.actionType == "pet"
end

local function RequiresOutOfCombat(data)
    return data.secureClick ~= nil or IsSecureWheelAction(data)
end

local function IsCombatItemMissing(data)
    return EmotePanel.combatView and data.actionType == "item" and not carriedActionItems[data.actionID]
end

local function IsCombatBlocked(data)
    return InCombatLockdown() and (data.secureClick ~= nil
        or IsCombatItemMissing(data) or (not EmotePanel.combatView and IsSecureWheelAction(data)))
end

local function GetSlashCommand(mode, index, data)
    local override = GetCustomMessage(mode, index)
    if data.run and (not override or override:gsub("^/+", ""):lower() == data.action:gsub("^/+", ""):lower()) then
        return
    end
    return "/" .. (override or data.action):gsub("^/+", "")
end

local function GetEntryPreview(mode, index, data)
    if mode == "categories" then return "Open " .. data.name end
    if mode == "macros" then return data.preview end
    if mode == "pet" then
        if data.movePending then return "Choose a destination" end
        if data.attacking then return "Attacking" end
        if data.canAutocast then
            if data.autocast == nil then return "Autocast status unavailable" end
            return data.autocast and "Autocast on" or "Autocast off"
        end
        return data.active and "Active" or "Pet action"
    end
    if data.actionType == "emote" then return "/" .. data.action end
    if data.actionType == "panel" then return "Open " .. data.name end
    if data.actionType == "profession" then
        local kind = data.isPrimary and "Primary profession" or "Secondary profession"
        local action = data.canCraft and "Open crafting" or "Open professions overview"
        return ("%s · %d / %d\n%s"):format(kind, data.rank, data.maxRank, action)
    end
    if data.actionType == "command" then return GetSlashCommand(mode, index, data) or data.preview end
    return GetCustomMessage(mode, index) or data.action
end

local function GetAvailableChatBox()
    local activeBox = ChatFrameUtil.GetActiveWindow()
    local editBox = ChatFrameUtil.ChooseBoxForSend()
    if not editBox then return end
    local draft = editBox:GetText()
    if (activeBox and activeBox:HasFocus()) or issecretvalue(draft) or draft ~= "" then
        print("EmotePanel: Finish your current chat draft before using a command.")
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

local function ExecuteAction(mode, index, data, fromMouse, sector)
    if data.actionType == "emote" then
        -- The native chat edit box treats a truthy return as a restriction.
        local restricted = C_ChatInfo.PerformEmote(GetEmoteToken(data))
        if EmotePanel.combatDebug then
            EmotePanel:CombatDebug("Emote", restricted and "rejected" or "accepted",
                "chat lockdown " .. tostring(C_ChatInfo.InChatMessagingLockdown()))
        elseif restricted then
            print("EmotePanel: WoW could not perform that emote.")
        end
        if not restricted then FinishOrdinaryAction(sector) end
    elseif data.actionType == "panel" then
        if data.secureClick then
            CloseAfterAction()
            print("EmotePanel: Character Info can only open from the wheel outside combat. "
                .. "Use WoW's Character Info keybind or the Character button in the micro menu.")
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
    elseif IsSecureWheelAction(data) then
        if InCombatLockdown() then print("EmotePanel: Spells, items, and macros can be used from the wheel outside combat.") end
    elseif data.actionType == "command" then
        local command = GetSlashCommand(mode, index, data)
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
        local message = GetCustomMessage(mode, index) or data.action
        local channel = data.actionType == "say" and "SAY" or "PARTY"
        if channel == "PARTY" and not IsInGroup() then
            print("EmotePanel: Join a group to send a party message.")
            return
        end
        C_ChatInfo.SendChatMessage(message, channel)
        FinishOrdinaryAction(sector)
    end
end

local function RefreshCategorySettings()
    local panel = _G[AddonName .. "CategoriesPanel"]
    if panel and panel:IsVisible() then panel:refresh() end
end

StaticPopupDialogs["EMOTEPANEL_RESET_BUTTON"] = {
    text = "Restore the default icon and any editable name or text?\n\n%s",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data.index then
            if EmotePanelSavedVars.customMessages and EmotePanelSavedVars.customMessages[data.mode] then
                EmotePanelSavedVars.customMessages[data.mode][data.index] = nil
            end
            if EmotePanelSavedVars.customButtonNames and EmotePanelSavedVars.customButtonNames[data.mode] then
                EmotePanelSavedVars.customButtonNames[data.mode][data.index] = nil
            end

            SaveEntryIcon(data.mode, data.index, nil)
            if EmotePanel.frame:IsShown() then EmotePanel:RefreshWheel() end
            if data.mode == "categories" then RefreshCategorySettings() end

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

StaticPopupDialogs["EMOTEPANEL_DISCARD_ENTRY"] = {
    text = "Discard your unsaved changes?\n\n%s",
    button1 = "Discard",
    button2 = "Keep editing",
    OnAccept = function(_, dialog) dialog:Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EMOTEPANEL_RESET_ALL"] = {
    text = "Reset custom icons, names, and text on wheel entries?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        EmotePanelSavedVars.customMessages = {}
        EmotePanelSavedVars.customButtonNames = {}
        EmotePanelSavedVars.customIcons = {}
        RefreshCategorySettings()

        if EmotePanel.frame and EmotePanel.frame:IsShown() then
            EmotePanel:RefreshWheel()
        end

        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsShown() then
            helpPanel:refresh()
        end

        print("|cFF00FF00EmotePanel:|r Wheel entry overrides reset.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local resetOnLogout

StaticPopupDialogs["EMOTEPANEL_RESET_SETTINGS"] = {
    text = "%s",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(_, reset) reset() end,
    OnHide = function() EmotePanel:UpdateSecureWheelInput() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local GAMEPAD_DISABLED_TIP = "Enable WoW controller input with /console GamePadEnable 1."
local GAMEPAD_BETA_TIP = "Gamepad (Beta) is unsupported. Turn off Enable Gamepad UI in Options > Gameplay > Gamepad."

local function HasGamepadWheelBinding(pet)
    for slot = 1, 2 do
        local key = EmotePanel:GetWheelBinding(slot, pet)
        if key and IsBindingForGamePad(key) then return true end
    end
    return false
end

local function PrintLoginWarnings()
    local warnings = {}
    if not EmotePanel:HasWheelBinding() then
        warnings[#warnings + 1] = "No wheel keybind is set. Assign Open or Close Emote Panel in /ep config under Controller Setup."
    end

    if not C_CVar.GetCVarBool("GamePadEnable")
        and (HasGamepadWheelBinding() or (EmotePanel.supportsPetWheel and HasGamepadWheelBinding(true))) then
        warnings[#warnings + 1] = GAMEPAD_DISABLED_TIP
    end
    if InputUtil.IsGamepadUIEnabled() then
        warnings[#warnings + 1] = GAMEPAD_BETA_TIP
    end
    if #warnings > 0 then
        print("|cffff0000EmotePanel: " .. table.concat(warnings, " ") .. "|r")
    end
end

local function IsWheelPopupVisible()
    return StaticPopup_Visible("EMOTEPANEL_DISCARD_ENTRY") or StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON")
        or StaticPopup_Visible("EMOTEPANEL_RESET_ALL")
        or StaticPopup_Visible("EMOTEPANEL_RESET_SETTINGS")
end

local function FindEditorConfirmation()
    return StaticPopup_FindVisible("EMOTEPANEL_DISCARD_ENTRY") or StaticPopup_FindVisible("EMOTEPANEL_RESET_BUTTON")
end

local function ShowEditorConfirmation(dialog, which, data)
    dialog.nameBox:ClearFocus()
    dialog.messageBox:ClearFocus()
    local popup = StaticPopupDialogs[which]
    local hint = ("%s %s    %s %s"):format(
        GamepadGlyph("PAD1", "A"), popup.button1, GamepadGlyph("PAD2", "B"), popup.button2)
    StaticPopup_Show(which, hint, nil, data)
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

local function AddSettingsTooltip(control, title, text, label)
    local function Show(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
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

local function CreateCloseButton(frame)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetNormalAtlas("128-redbutton-exit")
    close:SetPushedAtlas("128-redbutton-exit-Pressed")
    close:SetHighlightAtlas("128-redbutton-exit-Highlight")
    close:SetScript("OnClick", function() frame:Hide() end)
    return close
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
    AddSettingsTooltip(box, labelText, labelText == "Name" and "Set the name shown on the wheel." or "Edit the message or command sent by this entry.", label)
    SkinPanel(box)

    local focus = AddAtlas(box, FOCUS_ATLAS, "BORDER")
    focus:SetAllPoints()
    focus:Hide()
    box:HookScript("OnEditFocusGained", function() focus:Show() end)
    box:HookScript("OnEditFocusLost", function() focus:Hide() end)
    box.label = label
    return box
end

local function CreateIconPicker(dialog)
    local columns, rows = 8, 5
    local pageSize = columns * rows
    local extraFooterHeight = 52
    local picker = CreateFrame("Frame", nil, dialog)
    picker:SetSize(392, 342 + extraFooterHeight)
    picker:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    picker:SetFrameLevel(dialog:GetFrameLevel() + 10)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:EnableMouseWheel(true)
    SkinPanel(picker)
    CreateCloseButton(picker)

    local wheelIcons, seen = {}, {}
    for _, mode in ipairs(modeOrder) do
        for _, data in ipairs(PANEL_MODES[mode].list) do
            local icon = GetIconPath(data.icon)
            if not seen[icon] then
                table.insert(wheelIcons, icon)
                seen[icon] = #wheelIcons
            end
        end
    end

    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    local function CreateOutline(parent, edgeSize, r, g, b)
        local outline = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = edgeSize })
        outline:SetBackdropBorderColor(r, g, b, 1)
        return outline
    end

    local cursor = CreateOutline(picker, 5, 0.07, 0.05, 0.02)
    cursor:SetFrameLevel(picker:GetFrameLevel() + 3)
    local cursorGold = CreateOutline(cursor, 3, 1, 0.82, 0.22)
    cursorGold:SetPoint("TOPLEFT", 1, -1)
    cursorGold:SetPoint("BOTTOMRIGHT", -1, 1)

    local preview = picker:CreateTexture(nil, "ARTWORK")
    preview:SetSize(46, 46)
    preview:SetPoint("BOTTOMLEFT", 111, 31 + extraFooterHeight)
    local selectedLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("LEFT", preview, "RIGHT", 8, 8)
    selectedLabel:SetText("Selected")
    local status = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", preview, "RIGHT", 8, -9)
    local navigationHint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    navigationHint:SetPoint("BOTTOM", 0, 42)
    SetGlyphPrompt(navigationHint, function()
        return ("%s Select    %s %s Page"):format(
            GamepadGlyph("DIRPAD", "D-pad"), GamepadGlyph("PADLSHOULDER", "LB"), GamepadGlyph("PADRSHOULDER", "RB"))
    end)
    local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("BOTTOM", 0, 8)
    local function RenderHint()
        return ("%s Choose    %s Back    %s %s"):format(
            GamepadGlyph("PAD1", "A"), GamepadGlyph("PAD2", "B"), GamepadGlyph("PAD4", "Y"),
            picker.library and "Wheel Icons" or "Library")
    end
    SetGlyphPrompt(hint, RenderHint)

    local buttons = {}
    local function UpdateCursor()
        local button = buttons[picker.selected]
        local shown = button ~= nil and button.value ~= nil
        cursor:SetShown(shown)
        preview:SetShown(shown)
        if shown then
            cursor:ClearAllPoints()
            cursor:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
            cursor:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
            SetIconTexture(preview, button.value)
        end
    end

    local function Choose(icon)
        dialog.pendingIcon = icon
        SetIconTexture(dialog.icon, icon)
        picker:Hide()
    end

    function picker:GetIconCount()
        return self.library and self.provider:GetNumIcons() or #wheelIcons
    end

    function picker:Refresh()
        local count = self:GetIconCount()
        local pages = math.ceil(count / pageSize)
        local offset = (self.page - 1) * pageSize
        self.selected = math.min(self.selected, count - offset)
        title:SetText(self.library and "WoW Icon Library" or "Wheel Icons")
        hint:SetText(RenderHint())
        self.libraryButton:SetText(self.library and "Wheel" or "Library")
        status:SetFormattedText("%d / %d", self.page, pages)
        for index, button in ipairs(buttons) do
            local absoluteIndex = offset + index
            local icon
            if absoluteIndex <= count then
                if self.library then
                    icon = self.provider:GetIconByIndex(absoluteIndex)
                else
                    icon = wheelIcons[absoluteIndex]
                end
            end
            button.value = icon
            button:SetShown(icon ~= nil)
            if icon then
                SetIconTexture(button.icon, icon)
                button.current:SetShown(icon == dialog.pendingIcon)
            end
        end
        UpdateCursor()
    end

    function picker:MoveSelection(delta)
        local count = math.min(pageSize, self:GetIconCount() - (self.page - 1) * pageSize)
        self.selected = math.max(1, math.min(self.selected + delta, count))
        UpdateCursor()
    end

    function picker:ChangePage(delta)
        local lastPage = math.ceil(self:GetIconCount() / pageSize)
        local page = math.max(1, math.min(self.page + delta, lastPage))
        if page ~= self.page then
            self.page = page
            self:Refresh()
        end
    end

    function picker:ToggleLibrary()
        if not self.provider then
            self.provider = CreateFromMixins(IconDataProviderMixin)
            self.provider:Init(IconDataProviderExtraType.None)
        end
        self.library = not self.library
        local index
        if self.library then
            index = self.provider:GetIndexOfIcon(dialog.pendingIcon)
        else
            index = seen[dialog.pendingIcon]
        end
        index = index or 1
        self.page = math.ceil(index / pageSize)
        self.selected = (index - 1) % pageSize + 1
        self:Refresh()
    end

    function picker:ChooseSelected()
        local button = buttons[self.selected]
        if button and button.value then Choose(button.value) end
    end

    for index = 1, pageSize do
        local button = CreateFrame("Button", nil, picker)
        button:SetSize(38, 38)
        button:SetPoint("TOPLEFT", 23 + ((index - 1) % columns) * 44, -43 - math.floor((index - 1) / columns) * 42)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.current = button:CreateTexture(nil, "OVERLAY")
        button.current:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        button.current:SetSize(16, 16)
        button.current:SetPoint("BOTTOMRIGHT", -2, 2)
        button:SetHighlightAtlas(FOCUS_ATLAS)
        button:SetScript("OnClick", function()
            if button.value then Choose(button.value) end
        end)
        buttons[index] = button
    end

    local previous = CreateTextButton(picker, "<")
    previous:SetSize(27, 24)
    previous:SetPoint("BOTTOMLEFT", 23, 43 + extraFooterHeight)
    previous:SetScript("OnClick", function() picker:ChangePage(-1) end)
    local nextPage = CreateTextButton(picker, ">")
    nextPage:SetSize(27, 24)
    nextPage:SetPoint("BOTTOMLEFT", 56, 43 + extraFooterHeight)
    nextPage:SetScript("OnClick", function() picker:ChangePage(1) end)
    local default = CreateTextButton(picker, "Default")
    default:SetSize(63, 24)
    default:SetPoint("BOTTOMRIGHT", -23, 43 + extraFooterHeight)
    default:SetScript("OnClick", function() Choose(dialog.defaultIcon) end)
    local library = CreateTextButton(picker, "Library")
    picker.libraryButton = library
    library:SetSize(63, 24)
    library:SetPoint("RIGHT", default, "LEFT", -6, 0)
    library:SetScript("OnClick", function() picker:ToggleLibrary() end)

    picker:SetScript("OnMouseWheel", function(_, delta) picker:ChangePage(delta > 0 and -1 or 1) end)
    picker:SetScript("OnShow", function()
        local index = seen[dialog.pendingIcon] or 1
        picker.page = math.ceil(index / pageSize)
        picker.selected = (index - 1) % pageSize + 1
        picker.library = false
        picker:Refresh()
    end)
    picker:SetScript("OnHide", function()
        if picker.provider then
            picker.provider:Release()
            picker.provider = nil
        end
    end)
    picker:Hide()
    return picker
end

local function CreateCustomMessageDialog()
    local dialog = CreateFrame("Frame", "EmotePanelCustomMessageDialog", UIParent)
    dialog:SetSize(320, 310)
    dialog:SetPoint("CENTER", 0, 200)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetAttribute("nodeignore", true)
    SkinPanel(dialog)
    dialog.closeButton = CreateCloseButton(dialog)
    AddSettingsTooltip(dialog.closeButton, "Close", "Close the editor. You will be asked before discarding changes.")

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -18)
    dialog.title = title

    local nameBox = CreateEditorField(dialog, "Name", -51, 18)
    local messageBox = CreateEditorField(dialog, "Message or command", -114, 255)
    nameBox:SetScript("OnTabPressed", function()
        if messageBox:IsShown() then messageBox:SetFocus() end
    end)
    messageBox:SetScript("OnTabPressed", function() nameBox:SetFocus() end)
    dialog:SetScript("OnHide", function()
        nameBox:ClearFocus()
        messageBox:ClearFocus()
        if dialog.picker then dialog.picker:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_DISCARD_ENTRY")
    end)

    local iconButton = CreateTextButton(dialog, "Choose Icon")
    iconButton:SetSize(142, 30)
    iconButton:SetPoint("TOP", 20, -180)
    AddSettingsTooltip(iconButton, "Choose Icon", "Choose artwork from the wheel icons or WoW's icon library.")
    local icon = dialog:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("RIGHT", iconButton, "LEFT", -8, 0)
    iconButton:SetScript("OnClick", function()
        nameBox:ClearFocus()
        messageBox:ClearFocus()
        if not dialog.picker then dialog.picker = CreateIconPicker(dialog) end
        dialog.picker:Show()
    end)

    local placement = CreateFrame("Frame", nil, dialog)
    placement:SetSize(276, 108)
    local placementTitle = placement:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placementTitle:SetPoint("TOPLEFT")
    placementTitle:SetText("Wheel Placement")
    local location = placement:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    location:SetPoint("TOPLEFT", placementTitle, "BOTTOMLEFT", 0, -5)
    location:SetJustifyH("LEFT")
    local show = CreateFrame("CheckButton", nil, placement, "UICheckButtonTemplate")
    show:SetSize(24, 24)
    show:SetPoint("TOPLEFT", 0, -48)
    local showLabel = placement:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    showLabel:SetPoint("LEFT", show, "RIGHT", 4, 0)
    showLabel:SetText("Show on wheel")
    AddSettingsTooltip(show, "Show on wheel", "Choose whether this entry appears on the wheel. Save to apply the change.", showLabel)
    local up = CreateTextButton(placement, "Up")
    up:SetSize(40, 24)
    up:SetPoint("TOPLEFT", 0, -77)
    up:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(up, "Move up", "Move this entry one place earlier. Save to apply the change.")
    local down = CreateTextButton(placement, "Down")
    down:SetSize(48, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(down, "Move down", "Move this entry one place later. Save to apply the change.")
    local moveLabel = placement:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moveLabel:SetPoint("LEFT", down, "RIGHT", 8, 0)
    placement.location, placement.show = location, show
    placement.up, placement.down, placement.moveLabel = up, down, moveLabel
    dialog.placement = placement

    local editHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editHint:SetPoint("BOTTOM", 0, 52)
    SetGlyphPrompt(editHint, function()
        return ("%s Choose Icon    %s Save    %s Back"):format(
            GamepadGlyph("PAD4", "Y"), GamepadGlyph("PAD1", "A"), GamepadGlyph("PAD2", "B"))
    end)
    dialog.errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.errorText:SetPoint("BOTTOM", 0, 86)
    dialog.errorText:SetTextColor(1, 0.4, 0.4)

    local saveButton = CreateTextButton(dialog, "Save")
    saveButton:SetSize(86, 28)
    saveButton:SetPoint("BOTTOMLEFT", 22, 16)
    AddSettingsTooltip(saveButton, "Save", "Apply the icon, text, and placement changes.")
    local resetButton = CreateTextButton(dialog, "Reset")
    resetButton:SetSize(86, 28)
    resetButton:SetPoint("BOTTOM", 0, 16)
    AddSettingsTooltip(resetButton, "Reset", "Restore this entry's default icon, name, and text.")
    local cancelButton = CreateTextButton(dialog, "Cancel")
    cancelButton:SetSize(86, 28)
    cancelButton:SetPoint("BOTTOMRIGHT", -22, 16)
    AddSettingsTooltip(cancelButton, "Cancel", "Close the editor. You will be asked before discarding changes.")

    dialog.nameBox = nameBox
    dialog.messageBox = messageBox
    dialog.saveButton = saveButton
    dialog.resetButton = resetButton
    dialog.cancelButton = cancelButton
    dialog.iconButton = iconButton
    dialog.icon = icon
    local placementHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    placementHint:SetPoint("BOTTOM", 0, 86)
    SetGlyphPrompt(placementHint, function()
        local hint = ("%s Show on wheel    %s Move"):format(
            GamepadGlyph("PAD3", "X"), GamepadGlyph("DIRPADVERTICAL", "D-pad up/down"))
        if resetButton:IsShown() then hint = hint .. "    " .. GamepadGlyph("PADLSHOULDER", "LB") .. " Reset" end
        return hint
    end)
    dialog.placementHint = placementHint
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
        if cursor and not InCombatLockdown() and not EmotePanel.frame:IsVisible() then
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

    return frame
end

-- Sectors start at twelve o'clock and advance clockwise.
local function SectorAt(x, y)
    local index = math.floor(math.atan2(x, y) / SECTOR_ANGLE + 0.5) % SECTOR_COUNT + 1
    if index <= currentPage.count then return index end
end

local function HasEditableText(data)
    return data.custom or data.actionType == "say" or data.actionType == "party" or data.actionType == "command"
end

local function GetEntryName(mode, index, data)
    return ((mode == "categories" or HasEditableText(data)) and GetCustomButtonName(mode, index)) or data.name
end

local function SetSelectionTint(texture, color)
    texture:SetDesaturated(color ~= nil)
    if color then
        texture:SetVertexColor(unpack(color))
    else
        texture:SetVertexColor(1, 1, 1)
    end
end

local function ApplySelectedTint(self, data, blocked)
    local color = blocked and COMBAT_DISABLED_COLOR or SELECTION_COLORS[data.actionType]
    local chatType = SELECTION_CHAT_TYPES[data.actionType]
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
        local _, _, data = GetSectorEntry(index)
        local blocked = data ~= nil and IsCombatBlocked(data) or false
        slot.combatBlocked = blocked
        slot:SetAlpha(blocked and 0.55 or 1)
        if data and index == self.selected then ApplySelectedTint(self, data, blocked) end
    end
end

local WHEEL_STATUS_COLORS = {
    warning = { 1, 0.55, 0.51 },
    cooldown = { 1, 0.77, 0.45 },
    active = { 0.75, 0.92, 0.55 },
    normal = { 1, 1, 1 },
}

local function GetWheelEntryPreview(mode, key, data, slot)
    if not IsSecureWheelAction(data) then return GetEntryPreview(mode, key, data) end
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

local function SetWheelEntryPreview(self, mode, key, data)
    local preview, color = GetWheelEntryPreview(mode, key, data, self.slots[self.selected])
    self.messagePreview:SetText(preview:gsub("|", "||"))
    self.messagePreview:SetTextColor(unpack(color or WHEEL_STATUS_COLORS.normal))
end

function EmotePanel:RefreshSelectedActionFeedback()
    if not self.frame:IsShown() then return end
    local mode, key, data = GetSectorEntry(self.selected)
    if data and IsSecureWheelAction(data) then
        SetWheelEntryPreview(self, mode, key, data)
    end
end

function EmotePanel:Select(index, showTooltip)
    if index then
        if currentPage.count == 0 then return end
        index = (index - 1) % currentPage.count + 1
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
    local mode, slot, data = GetSectorEntry(index)
    if not data then
        self.highlight:Hide()
        local empty = ""
        if currentPage.mode == "pet" then
            if not next(petActions) then
                empty = petUnavailableReason or "No active pet actions"
            elseif index then
                empty = "Empty pet slot"
            end
        end
        self.selectionName:SetText(empty)
        self.messagePreview:SetText("")
        if showTooltip then self:ShowWheelEntryTooltip(nil) end
        self:RefreshGamepadHint()
        return
    end
    self.highlight:Show()
    if mode ~= "pet" then self.slots[index].border:SetAtlas(SELECTED_ICON_BORDER) end
    local angle = (index - 1) * SECTOR_ANGLE
    local radius = self.highlightRadius
    self.highlight:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)
    -- Blizzard's highlight atlas points down before rotation.
    self.highlight:SetRotation(math.pi - angle)
    ApplySelectedTint(self, data, IsCombatBlocked(data))
    self.selectionName:SetText(GetEntryName(mode, slot, data))
    SetWheelEntryPreview(self, mode, slot, data)
    self:RefreshGamepadHint()
    if showTooltip then self:ShowWheelEntryTooltip(index) end
end

local function PlacementName(category)
    if category == "categories" then return "Categories" end
    if category == "macros" then return ACTIONS_TITLE end
    if category == "pet" then return PET_TITLE end
    return categoryByID[category].name
end

local function GetPlacementOrder(category)
    if category ~= "favorites" then return GetOrderedEntryIDs(category, true) end
    local order = {}
    for position, entry in ipairs(favorites) do order[position] = entry end
    return order
end

local function SetupPlacement(controls, category, context, mode, index, data)
    local favoriteIndex = FindFavorite(mode, index)
    local favorite = favoriteIndex and favorites[favoriteIndex]
    local entry = context == "favorites" and favorite or index
    local originalOrder = GetPlacementOrder(context)
    local order = {}
    for position, id in ipairs(originalOrder) do order[position] = id end
    local swaps = {}
    local originallyShown = not IsEntryHidden(mode, index)
    controls.show:SetChecked(originallyShown)
    controls.moveLabel:SetText("Move in " .. PlacementName(context))

    local function VisibleOrder(scope)
        local visible = {}
        local inFavorites = scope == "favorites"
        local target = inFavorites and favorite or index
        local source = scope == context and order or GetPlacementOrder(scope)
        for _, id in ipairs(source) do
            local shown
            if id == target then
                shown = controls.show:GetChecked() and IsEntryAvailable(data)
            elseif inFavorites then
                shown = IsEntryVisible(id.mode, id.index)
            else
                shown = IsEntryVisible(mode, id)
            end
            if shown then visible[#visible + 1] = id end
        end
        return visible
    end

    local function Location(scope, visible)
        local name = PlacementName(scope)
        if not controls.show:GetChecked() then return name .. " · Hidden" end
        if not IsEntryAvailable(data) then
            return name .. (data.actionType == "item" and " · Not carried" or " · Unavailable")
        end
        local target = scope == "favorites" and favorite or index
        for position, id in ipairs(visible) do
            if id == target then
                return ("%s · Page %d · Slot %d"):format(name,
                    math.floor((position - 1) / SECTOR_COUNT) + 1, (position - 1) % SECTOR_COUNT + 1)
            end
        end
        return name .. " · Unavailable"
    end

    local previous, nextEntry
    local function RefreshPlacement()
        local visible = VisibleOrder(context)
        previous, nextEntry = nil, nil
        for position, id in ipairs(visible) do
            if id == entry then previous, nextEntry = visible[position - 1], visible[position + 1] end
        end
        controls.up:SetEnabled(previous ~= nil)
        controls.down:SetEnabled(nextEntry ~= nil)
        local text = Location(category, context == category and visible or VisibleOrder(category))
        if favorite then
            text = text .. "\n" .. Location("favorites", context == "favorites" and visible or VisibleOrder("favorites"))
        end
        controls.location:SetText(text)
    end
    local function Move(neighbor)
        if neighbor and SwapOrder(order, entry, neighbor) then
            swaps[#swaps + 1] = neighbor
            RefreshPlacement()
        end
    end
    controls.show:SetScript("OnClick", RefreshPlacement)
    controls.up:SetScript("OnClick", function() Move(previous) end)
    controls.down:SetScript("OnClick", function() Move(nextEntry) end)
    RefreshPlacement()

    local function IsReordered()
        for position, id in ipairs(order) do
            if originalOrder[position] ~= id then return true end
        end
        return false
    end
    local function VisibilityChanged()
        return (not not controls.show:GetChecked()) ~= originallyShown
    end
    local function SavePlacement(categoryChanged)
        local shown = not not controls.show:GetChecked()
        if shown ~= originallyShown then SaveEntryVisibility(mode, index, shown) end
        local reordered = false
        if (not categoryChanged or context == "favorites") and IsReordered() then
            local saved = context == "favorites" and favorites or GetPlacementOrder(context)
            for _, neighbor in ipairs(swaps) do
                if SwapOrder(saved, entry, neighbor) then reordered = true end
            end
            if reordered and context ~= "favorites" then EmotePanelSavedVars.entryOrder[context] = saved end
        end
        return reordered or shown ~= originallyShown
    end
    return SavePlacement, function() return VisibilityChanged() or IsReordered() end
end

local function RevealEditedEntry(panel, context, mode, index)
    if context == "categories" then
        if currentPage == categoryWheel then
            for sector, id in ipairs(categoryWheel.entries) do
                if id == index then
                    panel:DisplayPage(nil, categoryWheel, sector)
                    return
                end
            end
        end
        return
    end
    local first, last = GetCategoryPageRange(context)
    if not first then return end
    for pageIndex = first, last do
        local page = GetPage(pageIndex)
        for sector = 1, page.count do
            local entryMode, entryIndex = GetSectorEntry(sector, page)
            if entryMode == mode and entryIndex == index then
                panel:ShowPage(pageIndex, sector)
                return
            end
        end
    end
    panel:ShowPage(context == "macros" and last or first)
end

function EmotePanel:SetupEditorGamepad()
    local dialog = self.customMessageDialog
    if dialog and not dialog.gamepadReady and self.bindGamepadButtons and not InCombatLockdown() then
        self.bindGamepadButtons(dialog)
        dialog.gamepadReady = true
    end
end

function EmotePanel:EditButton(mode, index, data, fromSettings, context)
    if not self.customMessageDialog then
        self.customMessageDialog = CreateCustomMessageDialog()
        self.customMessageDialog:HookScript("OnShow", function() self:UpdateSecureWheelInput() end)
        self.customMessageDialog:HookScript("OnHide", function() self:UpdateSecureWheelInput() end)
    end

    local dialog = self.customMessageDialog
    StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
    StaticPopup_Hide("EMOTEPANEL_DISCARD_ENTRY")
    self:SetupEditorGamepad()
    dialog.fromSettings = fromSettings
    local creating = index == nil
    if creating then
        local config = customEntryTypes[mode]
        data = { name = "", action = "", icon = config.icon, actionType = config.actionType, custom = true }
    end
    local editingCategory = mode == "categories"
    local editableText = not editingCategory and HasEditableText(data)
    local editableName = editingCategory or editableText
    local nativeCommand = data.actionType == "command" and data.run ~= nil
    local iconTop = editableText and 180 or editableName and 114 or 60
    dialog.title:SetText(editingCategory and "Customize Category" or "Customize Entry")
    dialog:SetHeight(iconTop + 130 + (data.custom and 28 or 0) + (creating and 0 or 145))
    dialog.errorText:SetPoint("BOTTOM", 0, creating and 86 or 120)
    dialog.placement:SetShown(not creating)
    dialog.placementHint:SetShown(not creating)
    local savePlacement, hasPlacementChanges
    if not creating then
        local category = mode == "emotes" and voicedEmoteTokens[GetEmoteToken(data)] == true and "voicedEmotes" or mode
        context = context or (not fromSettings and currentPage.mode == "favorites" and "favorites") or category
        dialog.placement:ClearAllPoints()
        dialog.placement:SetPoint("TOPLEFT", dialog, "TOPLEFT", 22, -iconTop - 38)
        savePlacement, hasPlacementChanges = SetupPlacement(dialog.placement, category, context, mode, index, data)
    end
    dialog.nameBox:SetShown(editableName)
    dialog.nameBox.label:SetShown(editableName)
    dialog.messageBox:SetShown(editableText)
    dialog.messageBox.label:SetShown(editableText)
    dialog.messageBox.label:SetText(nativeCommand and "Slash override (optional)" or data.actionType == "emote" and "Emote (e.g. /wave)"
        or data.actionType == "command" and "Slash command" or "Message")
    dialog.resetButton:SetShown(not data.custom)
    dialog.placementHint:SetText(glyphPrompts[dialog.placementHint]())
    dialog.iconButton:SetPoint("TOP", 20, -iconTop)
    local previousName = GetEntryName(mode, index, data)
    local previousMessage = editableText and (GetCustomMessage(mode, index) or data.action) or ""
    if nativeCommand then previousMessage = GetSlashCommand(mode, index, data) or "" end
    dialog.nameBox:SetText(previousName)
    dialog.messageBox:SetText(previousMessage)
    dialog.defaultIcon = GetIconPath(data.custom and customEntryTypes[mode].icon or data.icon)
    local previousIcon = GetEntryIcon(mode, index, data)
    dialog.pendingIcon = previousIcon
    SetIconTexture(dialog.icon, dialog.pendingIcon)
    local function RequestClose()
        if FindEditorConfirmation() then return end
        local textChanged = (editableName and dialog.nameBox:GetText() ~= previousName)
            or (editableText and dialog.messageBox:GetText() ~= previousMessage)
        if textChanged or dialog.pendingIcon ~= previousIcon or (hasPlacementChanges and hasPlacementChanges()) then
            ShowEditorConfirmation(dialog, "EMOTEPANEL_DISCARD_ENTRY", dialog)
        else
            dialog:Hide()
        end
    end
    dialog.closeButton:SetScript("OnClick", RequestClose)
    dialog.cancelButton:SetScript("OnClick", RequestClose)
    dialog.saveButton:SetScript("OnClick", function()
        if savePlacement and InCombatLockdown() then
            dialog.errorText:SetText("Save entry changes after combat.")
            return
        end
        local categoryChanged
        if data.custom then
            local name = dialog.nameBox:GetText():match("^%s*(.-)%s*$")
            local action = dialog.messageBox:GetText():match("^%s*(.-)%s*$")
            if name == "" or action == "" then
                dialog.errorText:SetText("Enter a name and text.")
                return
            end
            if mode == "emotes" then
                action = action:gsub("^/+", "")
                local token = hash_EmoteTokenList and hash_EmoteTokenList["/" .. action:upper()]
                if not token then
                    dialog.errorText:SetText("Enter a WoW emote such as /wave.")
                    return
                end
                categoryChanged = voicedEmoteTokens[GetEmoteToken(data)] ~= voicedEmoteTokens[token]
                data.token = token
            elseif mode == "commands" and not action:match("^/[^/%s]") then
                dialog.errorText:SetText("Start the command with /.")
                return
            end
            data.name, data.action, data.icon = name, action, dialog.pendingIcon
            if creating then
                local entries = EmotePanelSavedVars.entries
                entries[mode] = entries[mode] or {}
                table.insert(entries[mode], data)
            end
        elseif editingCategory then
            local name = dialog.nameBox:GetText():match("^%s*(.-)%s*$")
            if name == "" then
                dialog.errorText:SetText("Enter a category name.")
                return
            end
            SaveCustomButtonName(mode, index, name ~= data.name and name or nil)
        elseif editableText then
            local name = dialog.nameBox:GetText()
            local message = dialog.messageBox:GetText()
            if name ~= "" and (message ~= "" or nativeCommand) then
                if name ~= previousName then
                    SaveCustomButtonName(mode, index, name ~= data.name and name or nil)
                end
                if message ~= previousMessage then
                    SaveCustomMessage(mode, index, message ~= "" and message ~= data.action and message or nil)
                end
            end
        end
        if not data.custom then
            SaveEntryIcon(mode, index, dialog.pendingIcon ~= dialog.defaultIcon and dialog.pendingIcon or nil)
        end
        local placementChanged = savePlacement and savePlacement(categoryChanged)
        if creating or categoryChanged or placementChanged then
            self:RefreshEntryPages()
            if placementChanged and not fromSettings and self.frame:IsShown() then
                RevealEditedEntry(self, context, mode, index)
            end
        elseif self.frame:IsShown() then
            self:RefreshWheel()
        end
        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
        if editingCategory then RefreshCategorySettings() end
        dialog:Hide()
    end)
    dialog.errorText:SetText("")
    dialog.resetButton:SetScript("OnClick", function()
        if FindEditorConfirmation() then return end
        ShowEditorConfirmation(dialog, "EMOTEPANEL_RESET_BUTTON", {
            mode = mode,
            index = index,
            dialog = dialog,
        })
    end)
    dialog:Show()
end

function EmotePanel:RefreshPetAutocast(selection)
    ReadPetActions()
    self:RefreshWheel(selection)
end

function EmotePanel:ActivateSector(index, mouseButton, fromMouse)
    local mode, slot, data = GetSectorEntry(index)
    if not data or (data.available and not data.available()) then return end
    if mode == "pet" then return end -- Pet commands and autocast use secure clicks.
    if currentPage == categoryWheel then
        if mouseButton == "LeftButton" then
            local first = GetCategoryPageRange(data.category)
            if first then
                self:ShowPage(first, 1)
            else
                self:DisplayPage(nil, { mode = data.category, title = data.name, count = 0 })
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
    if mouseButton == "LeftButton" and data.actionType == "command" and (fromMouse or data.run == ReloadUI) then
        local command = GetSlashCommand(mode, slot, data)
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
    elseif mouseButton == "RightButton" then
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
        for sector = 1, currentPage.count do
            local _, _, data = GetSectorEntry(sector)
            if data and RequiresOutOfCombat(data) then
                local x, y = self.wheel:GetCenter()
                if not x then break end
                button = button or self:CreateSecureWheelInput()
                local pet = currentPage.mode == "pet"
                if button:GetAttribute("pet-wheel") ~= pet then
                    button:Hide()
                    button:SetAttribute("pet-wheel", pet)
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

function EmotePanel:CreateWheel()
    local wheel = CreateFrame("Button", nil, self.frame)
    wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
    wheel:SetPoint("TOP", 0, -54)
    wheel:EnableMouse(true)
    wheel:RegisterForClicks("LeftButtonUp")
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

        local petStatus = AddAtlas(slot, SELECTED_ICON_BORDER, "OVERLAY")
        petStatus:SetSize(slot:GetWidth() + 4, slot:GetHeight() + 4)
        petStatus:SetPoint("CENTER")
        petStatus:SetDesaturated(true)
        petStatus:Hide()
        slot.petStatus = petStatus

        slot.border = AddAtlas(slot, ICON_BORDER, "OVERLAY")
        slot.border:SetAllPoints()
        slot.pressedBorder = AddAtlas(slot, "gamepad-actionbar-circleslot-border-pressed", "OVERLAY")
        slot.pressedBorder:SetAllPoints()
        slot.pressedBorder:Hide()

        slot.favorite = AddAtlas(slot, "collections-icon-favorites", "OVERLAY")
        slot.favorite:SetSize(16, 16)
        slot.favorite:SetPoint("TOPRIGHT", 3, 3)
        self.slots[index] = slot
    end

    local function SectorUnderCursor(includeCenter, cursorX, cursorY)
        local centerX, centerY = wheel:GetCenter()
        local scale = wheel:GetEffectiveScale()
        local x, y = cursorX / scale - centerX, cursorY / scale - centerY
        local distanceSquared = x * x + y * y
        if distanceSquared < innerRadius ^ 2 then
            if includeCenter then return 0 end
        elseif distanceSquared <= outerRadius ^ 2 then
            return SectorAt(x, y)
        end
    end

    local lastX, lastY, mouseDownButton, mouseDownSector, mouseDownPage
    local function UpdateMouseSelection()
        if not self.frame:IsShown() or not self:CanUseWheel() then return end
        local x, y = GetCursorPosition()
        if x == lastX and y == lastY then return end
        lastX, lastY = x, y
        local index = SectorUnderCursor(false, x, y)
        if mouseDownButton and self.wheelPressInput == mouseDownButton and index ~= mouseDownSector then
            self:SetWheelPressed(nil, mouseDownButton)
        end
        if index and not self.combatView then self:Select(index) end
        self:ShowWheelEntryTooltip(index, true)
    end
    local function StopMouseSelection()
        if mouseDownButton then self:SetWheelPressed(nil, mouseDownButton) end
        wheel:SetScript("OnUpdate", nil)
        lastX, lastY = nil, nil
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if self.wheelTooltipFromMouse and GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
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
            mouseDownSector = SectorUnderCursor(mouseButton == "RightButton", GetCursorPosition())
            mouseDownPage = currentPage
            if mouseButton == "LeftButton" or (mouseButton == "RightButton" and currentPage.mode == "pet") then
                self:SetWheelPressed(mouseDownSector, mouseButton)
            end
        end
    end
    local function TakeMouseClick(mouseButton)
        if mouseButton ~= mouseDownButton then return end
        self:SetWheelPressed(nil, mouseButton)
        local pressedSector, pressedPage = mouseDownSector, mouseDownPage
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if not pressedSector or pressedPage ~= currentPage or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(mouseButton == "RightButton", GetCursorPosition())
        if index == pressedSector then return index end
    end
    local function FinishClick(index, mouseButton, fromMouse)
        if not index then return end
        if index == 0 then
            self:BackOrClose()
        else
            self:ActivateSector(index, mouseButton, fromMouse)
        end
        if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
    end
    local function SetMouseScripts(button)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", function(_, delta)
            if delta == 0 or not self:CanUseWheel() then return end
            local nextPage, previousPage = GetScrollPages(currentPageIndex, currentPage, IsCategoryWheelEnabled())
            local destination = delta > 0 and nextPage or delta < 0 and previousPage
            if destination == 0 then
                self:ShowStartPage()
            elseif destination then
                self:ShowPage(destination, 1)
            end
        end)
        button:SetScript("OnEnter", StartMouseSelection)
        button:SetScript("OnLeave", StopMouseSelection)
        button:HookScript("OnHide", StopMouseSelection)
        button:SetScript("OnMouseDown", MouseDown)
        button:SetScript("OnMouseUp", function(_, mouseButton)
            -- The pet proxy handles right-click in the secure click context.
            if mouseButton ~= "LeftButton"
                and (button == wheel or mouseButton ~= "RightButton" or currentPage.mode ~= "pet") then
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
        button:SetSize(WHEEL_SIZE, WHEEL_SIZE)
        button:SetFrameStrata("DIALOG")
        button:EnableMouse(true)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("_onshow", [[
            self:SetBindingClick(true, "PAD1", self:GetName(), "WheelActivate")
            if self:GetAttribute("pet-wheel") then
                self:SetBindingClick(true, "PAD3", self:GetName(), "WheelAutocast")
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
            button:SetAttribute("action", nil)
            button:SetAttribute("clickbutton", nil)
        end
        local clickedSector, ranSecureAction, ranAutocast, controllerPage, autocastPage
        button:HookScript("OnHide", function() controllerPage, autocastPage = nil, nil end)
        button:SetScript("PreClick", function(_, input, down)
            clickedSector, ranSecureAction, ranAutocast = nil, false, false
            if InCombatLockdown() then return end
            ClearAction()
            if down then
                if input == "WheelActivate" then controllerPage = currentPage end
                if input == "WheelAutocast" then autocastPage = currentPage end
                if (input == "WheelActivate" or input == "WheelAutocast") and not IsModifierKeyDown()
                    and GetBindingFromClick(input == "WheelActivate" and "PAD1" or "PAD3") ~= "TOGGLEGAMEMENU" then
                    self:SetWheelPressed(self.selected, input)
                end
                return
            end
            self:SetWheelPressed(nil, input)
            local pressedPage, pressedAutocastPage = controllerPage, autocastPage
            if input == "WheelActivate" then
                controllerPage = nil
                -- The binding has received the release. Resume capturing ordinary input.
                self.gamepadInput:SetPropagateKeyboardInput(false)
            elseif input == "WheelAutocast" then
                autocastPage = nil
                self.gamepadInput:SetPropagateKeyboardInput(false)
            end
            if not (self.frame:IsShown() and self:CanUseWheel()) then return end
            local toggleAutocast = currentPage.mode == "pet" and (input == "RightButton" or input == "WheelAutocast")
            if input == "LeftButton" or (toggleAutocast and input == "RightButton") then
                clickedSector = TakeMouseClick(input)
            elseif toggleAutocast and pressedAutocastPage == currentPage and not IsModifierKeyDown() then
                clickedSector = self.selected
            elseif input == "WheelActivate" and (not pressedPage or pressedPage == currentPage)
                and not IsModifierKeyDown() then
                if GetBindingFromClick("PAD1") == "TOGGLEGAMEMENU" then
                    self.frame:Hide()
                    return
                end
                clickedSector = self.selected
            end
            local _, _, data = GetSectorEntry(clickedSector)
            if not data then return end
            if toggleAutocast then
                ReadPetActions()
                local current = petActions[data.actionID]
                local macro = current and current.key == data.key and GetPetAutocastMacro(current)
                if macro then
                    button:SetAttribute("type", "macro")
                    button:SetAttribute("macrotext", macro)
                    ranAutocast = true
                end
                return
            end
            local target = data.secureClick and _G[data.secureClick]
            if target then
                button:SetAttribute("type", "click")
                button:SetAttribute("clickbutton", target)
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
            elseif data.actionType == "pet" then
                button:SetAttribute("type", "pet")
                button:SetAttribute("action", data.actionID)
                ranSecureAction = true
            end
        end)
        button:HookScript("PostClick", function(_, input)
            if not InCombatLockdown() then ClearAction() end
            if ranAutocast then
                self:RefreshPetAutocast(clickedSector)
                if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
            elseif ranSecureAction then
                self:RememberAction(clickedSector)
                self:Select(clickedSector)
                if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
                CloseAfterAction()
            else
                FinishClick(clickedSector, "LeftButton", input == "LeftButton")
            end
        end)
        self.secureWheelInput = button
        return button
    end
end

function EmotePanel:ShowWheelEntryTooltip(sector, fromMouse)
    local owned = GameTooltip:IsOwned(self.wheel)
    if EmotePanelSavedVars.showWheelTooltips ~= true then
        if owned then GameTooltip:Hide() end
        return
    end
    local mode, key, data = GetSectorEntry(sector)
    if not data or IsCombatItemMissing(data) or (not fromMouse and not IsSecureWheelAction(data)) then
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
        GameTooltip:SetText(GetEntryName(mode, key, data))
    end
    if not native or kind == "pet" then
        local preview = kind == "pet" and GetWheelEntryPreview(mode, key, data, self.slots[sector])
        GameTooltip:AddLine(preview and preview ~= "" and preview or GetEntryPreview(mode, key, data), 1, 1, 1, true)
    end
    if kind == "macro" then
        local body
        if currentPage.actions then
            local action = currentPage.actions[sector]
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
            if not InCombatLockdown() and GetPetAutocastMacro(data) then
                GameTooltip:AddLine("Right-click to toggle autocast", 0.7, 0.7, 0.7)
            end
        else
            if currentPage ~= categoryWheel or not InCombatLockdown() then
                GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
            end
            if currentPage ~= categoryWheel then
                local hint = FindFavorite(mode, key) and "Middle-click to remove favorite" or "Middle-click to favorite"
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
    local _, _, data = GetSectorEntry(index)
    if data and self.frame:IsShown() and self:CanUseWheel() and not IsCombatBlocked(data) then
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
    end
    local _, item = GetMacroItem(data.macroIndex)
    if not issecretvalue(item) and item then return item end
    local spellID = GetMacroSpell(data.macroIndex)
    if not issecretvalue(spellID) then return nil, spellID end
end

local function SetDuration(cooldown, duration)
    if not issecretvalue(duration) and duration then
        cooldown:SetCooldownFromDurationObject(duration, true)
        return true
    end
    cooldown:Clear()
end

local function UpdateActionCooldown(slot, data)
    local cooldown, swipe = slot.cooldown, slot.cooldownSwipe
    local start, duration, enabled
    if data.actionType == "pet" then
        start, duration, enabled = GetPetActionCooldown(data.actionID)
    else
        local item, spellID = GetActionItemOrSpell(data)
        if item then
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
        local data = shown and select(3, GetSectorEntry(index))
        local active = false
        if data and IsSecureWheelAction(data) and not IsCombatItemMissing(data) then
            slot.cooldown:SetHideCountdownNumbers(not showNumbers)
            active = UpdateActionCooldown(slot, data)
        else
            slot.cooldown:Clear()
            slot.cooldownSwipe:Clear()
            slot.recharge:Clear()
        end
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
        AddAtlas(effect, "gamepad-actionbar-circleslot-interrupt", "OVERLAY"):SetAllPoints()
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
    local shown = self.frame:IsShown() and (currentPage.mode == "macros" or currentPage.mode == "favorites")
    local castID, duration, channel
    if shown then castID, duration, channel = GetPlayerCast() end
    for index, slot in ipairs(self.slots) do
        local data = shown and select(3, GetSectorEntry(index))
        local spellID
        if data and IsSecureWheelAction(data) and data.actionType ~= "pet" and not IsCombatItemMissing(data) then
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
        local data = shown and not slot.combatBlocked and select(3, GetSectorEntry(index))
        local inRange
        if canCheck and data and IsSecureWheelAction(data) then inRange = GetActionInRange(data) end
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

function EmotePanel:RefreshWheel(selection)
    self:SetWheelPressed(nil)
    self:RefreshWheelFooter()
    self.leftPageArrow:SetShown(self.canPageLeft == true)
    self.rightPageArrow:SetShown(self.canPageRight == true)
    for index, slot in ipairs(self.slots) do
        local mode, entryIndex, data = GetSectorEntry(index)
        local used = data ~= nil
        if data then
            SetIconTexture(slot.icon, GetEntryIcon(mode, entryIndex, data), true)
            slot.border:SetAtlas(ICON_BORDER)
            SetSelectionTint(slot.border)
            slot.favorite:SetShown(currentPage.mode ~= "favorites" and FindFavorite(mode, entryIndex) ~= nil)
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
    local hasEntries = currentPage.count > 0
    if hasEntries then
        if nextSelection or not self.combatView then
            self:Select(math.min(nextSelection or 1, currentPage.count))
        else
            self:Select(nil)
        end
    else
        self.highlight:Hide()
        local emptyText = currentPage.mode == "favorites" and "No favorites" or "No visible entries"
        if currentPage.mode == "categories" then
            emptyText = "No visible categories"
        elseif currentPage.mode == "professions" then
            emptyText = #learnedProfessions > 0 and "No visible professions" or "No learned professions"
        elseif currentPage.mode == "pet" then
            emptyText = next(petActions) and "No visible pet actions" or petUnavailableReason or "No active pet actions"
        end
        self.selectionName:SetText(emptyText)
        self.messagePreview:SetText("")
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
    local frame = self.frame
    local rowY = -31
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
        self:UpdateSecureWheelInput()
    end)

    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("CENTER", frame, "TOP", 0, rowY)
    self.titleText:SetWidth(206)
    self.titleText:SetJustifyH("CENTER")
    self.titleText:SetWordWrap(false)
    self.titleText:SetTextColor(1, 0.96, 0.87)
    self.titleText:SetText(currentPage.title)

    self.leftPageArrow = AddAtlas(frame, "common-icon-backarrow", "OVERLAY")
    self.leftPageArrow:SetSize(14, 22)
    self.leftPageArrow:SetPoint("CENTER", frame, "TOP", -118, rowY)
    self.rightPageArrow = AddAtlas(frame, "common-icon-forwardarrow", "OVERLAY")
    self.rightPageArrow:SetSize(14, 22)
    self.rightPageArrow:SetPoint("CENTER", frame, "TOP", 118, rowY)

    local footer = AddAtlas(frame, "gamepad-radial-menu-bottomtext", "BORDER")
    footer:SetSize(410, 102)
    footer:SetPoint("TOP", 0, -439)
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

    self.messagePreview = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.messagePreview:SetPoint("TOP", footer, "BOTTOM", 0, -7)
    self.messagePreview:SetWidth(386)
    self.messagePreview:SetJustifyH("CENTER")
    self.messagePreview:SetWordWrap(true)
    self.messagePreview:SetNonSpaceWrap(true)
    self:RefreshWheelFooter()
    frame:HookScript("OnShow", function()
        if self.combatView then return end
        ReadPetActions()
        BuildPetPages()
        if RefreshCarriedActionItems() then BuildCategoryPages() end
        RefreshProfessions()
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
    local legend = EmotePanelSavedVars.showKeybindLegend ~= false
    self.legendFooter:SetShown(legend)
    self.navigationHint:SetShown(legend)
    self.gamepadHint:SetShown(legend)
    self.messagePreview:SetShown(currentPage.mode ~= "emotes" and currentPage.mode ~= "voicedEmotes")
    self.messagePreview:ClearAllPoints()
    self.messagePreview:SetPoint("TOP", legend and self.legendFooter or self.selectionName, "BOTTOM", 0, -7)
end

function EmotePanel:RefreshControllerPrompts()
    self:RefreshGamepadHint()
    for fontString, render in pairs(glyphPrompts) do fontString:SetText(render()) end
end

function EmotePanel:RefreshGamepadHint()
    local navigation = GamepadGlyph("PADLSTICKAXIS", "Left stick") .. " / "
        .. GamepadGlyph("PADRSTICKAXIS", "Right stick") .. " "
        .. GamepadGlyph("DIRPADVERTICAL", "Up/Down") .. " Select"
    if currentPage.mode == "categories" then
        if self.canPageLeft then
            navigation = navigation .. "       " .. GamepadGlyph("PADDLEFT", "Left") .. " / "
                .. GamepadGlyph("PADLSHOULDER", "LB") .. " " .. ACTIONS_TITLE
        end
    elseif currentPage.mode == "macros" and self.canGoBack then
        local _, last = GetCategoryPageRange("macros")
        local toCategories = currentPageIndex == last
        if self.combatView then toCategories = currentPage.right == 0 end
        local destination = toCategories and "Categories" or "Previous page"
        navigation = navigation .. "       " .. GamepadGlyph("PADDRIGHT", "Right") .. " / "
            .. GamepadGlyph("PADRSHOULDER", "RB") .. " " .. destination
    elseif currentPage.mode == "pet" and (self.canPageLeft or self.canPageRight) then
        local direction = self.canPageRight
        navigation = navigation .. "       "
            .. (direction and GamepadGlyph("PADDRIGHT", "Right") or GamepadGlyph("PADDLEFT", "Left"))
            .. " / " .. (direction and GamepadGlyph("PADRSHOULDER", "RB") or GamepadGlyph("PADLSHOULDER", "LB"))
            .. (direction and " Next page" or " Previous page")
    elseif self.canPageLeft then
        navigation = navigation .. "       " .. GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " / "
            .. GamepadGlyph("PADLSHOULDER", "LB") .. " " .. GamepadGlyph("PADRSHOULDER", "RB") .. " Page"
    end
    self.navigationHint:SetText(navigation)
    local mode, slot, data = GetSectorEntry(self.selected)
    local actions
    if currentPage.mode == "categories" then
        actions = data and GamepadGlyph("PAD1", "A") .. " Open    " or ""
        if data and not self.combatView and not InCombatLockdown() then
            actions = actions .. GamepadGlyph("PAD4", "Y") .. " Edit    "
        end
    elseif data then
        local favoriteAction = FindFavorite(mode, slot) and "Unfavorite" or "Favorite"
        local primaryAction = (data.actionType == "profession" or data.actionType == "panel") and "Open" or "Use"
        actions = IsCombatItemMissing(data) and "Not carried"
            or IsCombatBlocked(data) and "Unavailable in combat"
            or GamepadGlyph("PAD1", "A") .. " " .. primaryAction
        if mode == "pet" then
            local macro = GetPetAutocastMacro(data)
            local pet = self.combatView and UnitName("pet")
            if macro and (not InCombatLockdown() or (self.combatView and not issecretvalue(pet)
                and pet == self.combatAutocastPet and currentPage.actions[self.selected].autocast == macro)) then
                local prompt = data.autocast == nil and "Autocast" or data.autocast and "Disable" or "Activate"
                actions = actions .. "    " .. GamepadGlyph("PAD3", "X") .. " " .. prompt
            end
        elseif not self.combatView then
            actions = actions .. "    " .. GamepadGlyph("PAD3", "X") .. " " .. favoriteAction
                .. "    " .. GamepadGlyph("PAD4", "Y") .. " Edit"
        end
        actions = actions .. "    "
    elseif currentPage.mode == "pet" or currentPage == professionPage or IsCategoryWheelEnabled() then
        actions = ""
    else
        actions = "Browse pages and press " .. GamepadGlyph("PAD3", "X") .. " to add    "
    end
    self.gamepadHint:SetText(actions .. GamepadGlyph("PAD2", "B") .. (self.canGoBack and " Back" or " Close"))
end

function EmotePanel:DisplayPage(index, page, selection)
    if self.combatView then return end
    currentPageIndex = index
    currentPage = page
    local nested = IsCategoryWheelEnabled()
    local pet = page.mode == "pet"
    local inCategory = nested and page ~= categoryWheel and not pet
    local canPage = not nested
    local actionsShortcut = nested and page.mode == "macros"
    if inCategory then
        local first, last = GetCategoryPageRange(page.category or page.mode)
        canPage = first ~= last
        if actionsShortcut then canPage = index > first end
    end
    self.canGoBack = inCategory
    if pet then
        self.canPageLeft = page.left ~= nil
        self.canPageRight = page.right ~= nil
    else
        self.canPageLeft = canPage or (page == categoryWheel and GetCategoryPageRange("macros") ~= nil)
        self.canPageRight = canPage or actionsShortcut
    end
    self.titleText:SetText(currentPage.title)
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self:RefreshWheel(selection)
end

function EmotePanel:ShowPage(index, selection)
    self:DisplayPage(index, GetPage(index), selection)
end

local function MakeCategoryWheel()
    local entries = GetVisibleEntryIDs("categories")
    return { mode = "categories", title = "Categories", entries = entries, count = #entries }
end

function EmotePanel:BuildCombatLayout()
    local pages, nested = {}, IsCategoryWheelEnabled()
    local last = FavoritePageCount() + #categoryPages
    local function AddPage(id, source)
        local page = { mode = source.mode, first = source.first, count = source.count, title = source.title, snapshot = {}, actions = {} }
        page.scrollUp, page.scrollDown = GetScrollPages(id, source, nested)
        for sector = 1, source.count do
            local mode, key, data = GetSectorEntry(sector, source)
            page.snapshot[sector] = { mode, key, data }
            local kind, value = data and data.actionType
            if source.mode == "categories" then
                kind, value = "page", GetCategoryPageRange(data.category)
                if not value then
                    value = #pages + 1
                    pages[value] = { mode = data.category, title = data.name, count = 0, snapshot = {}, actions = {}, back = 0 }
                end
            elseif source.mode == "pet" then
                kind, value = "pet", data and data.actionID
            elseif kind == "macro" then
                local name, _, body = GetMacroInfo(data.macroIndex)
                if name == data.name and type(body) == "string" then value = body end
            elseif kind == "spell" then
                value = data.actionID
            elseif kind == "item" then
                value = "item:" .. data.actionID
            elseif not data.secureClick then
                kind, value = "ordinary", true
            end
            page.actions[sector] = { kind = kind, value = value }
            if source.mode == "pet" and data then
                page.actions[sector].autocast = GetPetAutocastMacro(data)
            end
        end
        pages[id] = page
        return page
    end

    for index = 1, last do
        local source = GetPage(index)
        local page = AddPage(index, source)
        if not nested then
            page.left, page.right = (index - 2) % last + 1, index % last + 1
        else
            local first, final = GetCategoryPageRange(source.category or source.mode)
            page.back = 0
            if source.mode == "macros" then
                if index > first then page.left = index - 1 end
                page.right = index < final and index + 1 or 0
            elseif first ~= final then
                page.left = index > first and index - 1 or final
                page.right = index < final and index + 1 or first
            end
        end
    end
    if nested then
        local categories = AddPage(0, MakeCategoryWheel())
        local _, lastActions = GetCategoryPageRange("macros")
        categories.left = lastActions
    end
    for index, source in ipairs(petPages) do
        local page = AddPage(-index, source)
        page.left, page.right = source.left, source.right
    end
    return pages, nested and 0 or 1, petPages[1] and -1 or nil
end

function EmotePanel:ShowCombatPage(index, selection)
    local page = self.combatPages[index]
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
    currentPageIndex, currentPage = index, page
    self.canPageLeft = page.left ~= nil
    self.canPageRight = page.right ~= nil
    self.canGoBack = page.back ~= nil
    self.titleText:SetText(page.title)
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self.selected = nil
    self:RefreshWheel(selection)
end

function EmotePanel:CloseCombatDisplay()
    if not self.combatView then return end
    self.frame:Hide()
    self.combatView = nil
    table.insert(UISpecialFrames, self.frame:GetName())
    if self.gamepadInput then self.gamepadInput:Show() end
    if not InCombatLockdown() then self:LoadPosition() end
    self:ShowStartPage()
end

function EmotePanel:ActivateCombatSector(sector, fromMouse)
    if not self.combatView then return end
    local _, _, data = GetSectorEntry(sector)
    if data and data.actionType ~= "emote" then
        self:CombatDebug("Shortcut", data.actionType, "sector " .. sector)
    end
    self:ActivateSector(sector, "LeftButton", fromMouse)
end

function EmotePanel:ShowStartPage(resume)
    if self.combatView then return end
    self.combatLayoutDirty = true
    if IsCategoryWheelEnabled() then
        categoryWheel = MakeCategoryWheel()
    end
    if resume and EmotePanelSavedVars.rememberLastAction and self.lastAction then
        for index = 1, FavoritePageCount() + #categoryPages do
            local page = GetPage(index)
            local sector = self:FindRememberedSector(page)
            if sector then
                self:DisplayPage(index, page, sector)
                return
            end
        end
    end
    if IsCategoryWheelEnabled() then
        self:DisplayPage(nil, categoryWheel, 1)
    else
        self:ShowPage(1, 1)
    end
end

function EmotePanel:ShowPetStartPage()
    self.combatLayoutDirty = true
    if EmotePanelSavedVars.rememberLastAction and self.lastPetAction then
        for index, page in ipairs(petPages) do
            local sector = self:FindRememberedSector(page)
            if sector then
                self:ShowPage(-index, sector)
                return
            end
        end
    end
    self:ShowPage(-1, 1)
end

function EmotePanel:BackOrClose()
    if IsCategoryWheelEnabled() and currentPage ~= categoryWheel and currentPage.mode ~= "pet" then
        local category = currentPage.category or currentPage.mode
        for index, id in ipairs(categoryWheel.entries) do
            if id == category then
                self:DisplayPage(nil, categoryWheel, index)
                return
            end
        end
        self:ShowStartPage()
        return
    end
    self.frame:Hide()
end

function EmotePanel:RefreshEntryPages()
    RefreshCarriedActionItems()
    BuildCategoryPages()
    BuildPetPages()
    RefreshProfessionPage()
    RefreshVisibleFavorites()
    if currentPage.mode == "pet" then
        self:RefreshPetPage()
    else
        self:ShowStartPage()
    end
end

function EmotePanel:RefreshPetPage()
    if self.combatView then
        self:RefreshWheel()
    else
        self:ShowPage(math.max(currentPageIndex, -#petPages), self.selected)
    end
end

local function RefreshActionPicker(kind)
    local picker = _G[AddonName .. "ActionsPanel"]
    if picker and picker:IsVisible() and picker.kind == kind then picker:refresh() end
end

function EmotePanel:SetActionSelected(key, data, selected)
    local saved = EmotePanelSavedVars
    if selected and not actionsByID[key] then
        saved.directActions[characterGUID] = saved.directActions[characterGUID] or {}
        table.insert(saved.directActions[characterGUID], data)
        actionsByID[key] = data
        table.insert(actionIDs, key)
    end
    SaveEntryVisibility("macros", key, selected)
    self:RefreshEntryPages()
    local helpPanel = _G[AddonName .. "HelpPanel"]
    if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
    if data and data.actionType == "item" then RefreshActionPicker("item") end
end

function EmotePanel:RefreshCurrentEntryPages()
    if self.combatView or currentPage.mode == "pet" then
        BuildCategoryPages()
        RefreshVisibleFavorites()
        self:RefreshWheel()
        return
    end
    local category = currentPage.category or currentPage.mode
    local first, last = GetCategoryPageRange(category)
    local actions = category == "macros"
    local pageOffset = currentPageIndex and first
        and (actions and last - currentPageIndex or currentPageIndex - first) or 0
    BuildCategoryPages()
    RefreshVisibleFavorites()

    local newFirst, newLast = GetCategoryPageRange(category)
    if newFirst then
        local page = actions and math.max(newFirst, newLast - pageOffset) or math.min(newFirst + pageOffset, newLast)
        self:ShowPage(page, self.selected)
    elseif first and IsCategoryWheelEnabled() and not actions then
        self:DisplayPage(nil, { mode = category, title = PANEL_MODES[category].title, count = 0 })
    elseif first then
        self:ShowStartPage()
    elseif currentPage == categoryWheel then
        self:DisplayPage(nil, categoryWheel, self.selected)
    end
end

function EmotePanel:RefreshGroupEntries()
    local inGroup = not not IsInGroup()
    if inGroup == grouped then return end
    grouped = inGroup
    self:RefreshCurrentEntryPages()
end

function EmotePanel:CycleMode(direction)
    if currentPage.mode == "pet" then
        local destination = direction < 0 and currentPage.left or direction > 0 and currentPage.right
        if destination then self:ShowPage(destination, 1) end
        return
    end
    if currentPage == categoryWheel then
        local _, lastActions = GetCategoryPageRange("macros")
        if direction < 0 and lastActions then self:ShowPage(lastActions, 1) end
        return
    end
    if not currentPageIndex then return end
    local first, last = 1, FavoritePageCount() + #categoryPages
    if IsCategoryWheelEnabled() then
        first, last = GetCategoryPageRange(currentPage.category or currentPage.mode)
        if currentPage.mode == "macros" then
            local nextPage = currentPageIndex + direction
            if nextPage > last then
                self:ShowStartPage()
            elseif nextPage >= first then
                self:ShowPage(nextPage, 1)
            end
            return
        end
        if first == last then return end
    end
    self:ShowPage((currentPageIndex - first + direction) % (last - first + 1) + first, 1)
end

function EmotePanel:ToggleFavorite()
    if currentPage == categoryWheel or currentPage.mode == "pet" then return end
    local mode, slot, data = GetSectorEntry(self.selected)
    if not data then return end
    local previousPageCount = FavoritePageCount()
    local position = FindFavorite(mode, slot)
    if position then
        table.remove(favorites, position)
    else
        table.insert(favorites, { mode = mode, index = slot })
    end
    RefreshVisibleFavorites()

    local newPageCount = FavoritePageCount()
    local page = currentPageIndex
    if currentPage.mode == "favorites" then
        page = math.min(page, newPageCount)
    else
        page = page + newPageCount - previousPageCount
    end
    self:ShowPage(page, self.selected)
    local helpPanel = _G[AddonName .. "HelpPanel"]
    if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
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
    local actions = {
        PADDUP = function() if self.selected then self:Select(self.selected - 1, true) end end,
        PADDDOWN = function() if self.selected then self:Select(self.selected + 1, true) end end,
        PADDLEFT = PreviousPage,
        PADDRIGHT = NextPage,
        PADLSHOULDER = PreviousPage,
        PADRSHOULDER = NextPage,
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
        PADDUP = function() self.customMessageDialog.placement.up:Click() end,
        PADDDOWN = function() self.customMessageDialog.placement.down:Click() end,
    }
    local function ResetEntry() self.customMessageDialog.resetButton:Click() end
    local function ClickEditorConfirmation(which, index)
        local popup = StaticPopup_FindVisible(which)
        if popup then StaticPopup_OnClick(popup, index) end
    end
    local confirmationActions = {
        EMOTEPANEL_RESET_BUTTON = {
            PAD1 = function() ClickEditorConfirmation("EMOTEPANEL_RESET_BUTTON", 1) end,
            PAD2 = function() ClickEditorConfirmation("EMOTEPANEL_RESET_BUTTON", 2) end,
        },
        EMOTEPANEL_DISCARD_ENTRY = {
            PAD1 = function() ClickEditorConfirmation("EMOTEPANEL_DISCARD_ENTRY", 1) end,
            PAD2 = function() ClickEditorConfirmation("EMOTEPANEL_DISCARD_ENTRY", 2) end,
        },
    }
    local pickerActions = {
        PADDUP = function() self.customMessageDialog.picker:MoveSelection(-8) end,
        PADDDOWN = function() self.customMessageDialog.picker:MoveSelection(8) end,
        PADDLEFT = function() self.customMessageDialog.picker:MoveSelection(-1) end,
        PADDRIGHT = function() self.customMessageDialog.picker:MoveSelection(1) end,
        PADLSHOULDER = function() self.customMessageDialog.picker:ChangePage(-1) end,
        PADRSHOULDER = function() self.customMessageDialog.picker:ChangePage(1) end,
        PAD1 = function() self.customMessageDialog.picker:ChooseSelected() end,
        PAD2 = function() self.customMessageDialog.picker:Hide() end,
        PAD4 = function() self.customMessageDialog.picker:ToggleLibrary() end,
    }
    local function GetAction(key)
        if key == "PADFORWARD" or GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
            return CloseForGameMenu
        end
        local dialog = self.customMessageDialog
        local editing = dialog and dialog:IsShown()
        if editing then
            local popup = FindEditorConfirmation()
            if popup then return confirmationActions[popup.which][key] end
        end
        if IsWheelPopupVisible() then return end
        if editing then
            if dialog.picker and dialog.picker:IsShown() then return pickerActions[key] end
            if dialog.nameBox:HasFocus() or dialog.messageBox:HasFocus() then return end
            if key == "PADLSHOULDER" and dialog.resetButton:IsShown() then return ResetEntry end
            return editorActions[key] or (dialog.placement:IsShown() and placementActions[key])
        end
        if key ~= "PAD4" or (self.selected and currentPage.mode ~= "pet") then return actions[key] end
    end
    local function BindGamepadButtons(target, visibilityOwner)
        local pressed = {}
        local activationPage
        local function PropagateButton(propagate)
            if not InCombatLockdown() then target:SetPropagateKeyboardInput(propagate) end
            return propagate
        end
        local function UseSecureBinding(key)
            return (key == "PAD1" or (key == "PAD3" and currentPage.mode == "pet"))
                and self.secureWheelInput and self.secureWheelInput:IsShown()
        end
        target:SetScript("OnGamePadButtonDown", function(_, key)
            if UseSecureBinding(key) then return PropagateButton(true) end
            local action = GetAction(key)
            if not action or (action ~= CloseForGameMenu and IsModifierKeyDown()) then return PropagateButton(true) end
            pressed[key] = action
            if action == actions.PAD1 then
                activationPage = currentPage
                self:SetWheelPressed(self.selected, key)
            end
            return PropagateButton(false)
        end)
        target:SetScript("OnGamePadButtonUp", function(_, key)
            self:SetWheelPressed(nil, key)
            local action = pressed[key]
            pressed[key] = nil
            if UseSecureBinding(key) or not action then return PropagateButton(true) end
            PropagateButton(false)
            if action == actions.PAD1 and activationPage ~= currentPage then return false end
            if action == GetAction(key) then
                if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
                action()
            end
            return false
        end)
        local owner = visibilityOwner or target
        owner:HookScript("OnHide", function() wipe(pressed) end)
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
        if index then self:Select(index, true) end
    end
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

    local position = EmotePanelSavedVars.positions.emotePanel or DEFAULT_POSITION

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
    local position = EmotePanelSavedVars.positions.emotePanel or DEFAULT_POSITION
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

function EmotePanel:SetPositionOffsets(x, y)
    local maxX, maxY = GetPositionLimits(self.frame)
    EmotePanelSavedVars.positions.emotePanel = {
        point = "CENTER", relativePoint = "CENTER",
        x = math.max(-maxX, math.min(x, maxX)),
        y = math.max(-maxY, math.min(y, maxY)),
    }
    self:LoadPosition()
end

function EmotePanel:Initialize()
    EmotePanelSavedVars = EmotePanelSavedVars or {}
    EmotePanelSavedVars.customIcons = EmotePanelSavedVars.customIcons or {}
    EmotePanelSavedVars.entries = EmotePanelSavedVars.entries or {}
    EmotePanelSavedVars.hiddenEntries = EmotePanelSavedVars.hiddenEntries or {}
    if type(EmotePanelSavedVars.selectedMacros) ~= "table" then EmotePanelSavedVars.selectedMacros = {} end
    if type(EmotePanelSavedVars.directActions) ~= "table" then EmotePanelSavedVars.directActions = {} end
    if type(EmotePanelSavedVars.entryOrder) ~= "table" then EmotePanelSavedVars.entryOrder = {} end
    LoadNativeEmotes()
    local class = UnitClassBase("player")
    self.supportsPetWheel = not issecretvalue(class) and (class == "HUNTER" or class == "WARLOCK")
    ReadPetActions()
    BuildPetPages()
    ReadActions()
    RefreshCarriedActionItems()
    LoadFavorites()
    grouped = not not IsInGroup()
    RefreshProfessions()
    BuildCategoryPages()
    currentPageIndex = 1
    currentPage = GetPage(1)

    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateControls()
    self:RefreshWheel()
    self:LoadPosition()
    local rangeElapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        -- An already queued ConsolePort update can show the cursor again.
        HideConsolePortCursor()
        if currentPage.mode ~= "macros" and currentPage.mode ~= "favorites" and currentPage.mode ~= "pet" then return end
        rangeElapsed = rangeElapsed + elapsed
        if rangeElapsed >= RANGE_CHECK_INTERVAL then
            rangeElapsed = 0
            self:RefreshActionRanges()
        end
    end)
    self.frame:HookScript("OnHide", function()
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
    self.frame:HookScript("OnShow", function() self:SetWheelMovementCapture(true) end)
    self.frame:HookScript("OnShow", function(frame) SetConsolePortCursorObstructed(frame, true) end)
    self.frame:HookScript("OnHide", function(frame) SetConsolePortCursorObstructed(frame, false) end)

    -- Blizzard closes special windows separately from the protected Escape handlers.
    table.insert(UISpecialFrames, self.frame:GetName())
end

local categoryIDs = {}

local function GetActionChoices(kind)
    local choices, seen = {}, {}
    local function Add(key, data)
        if seen[key] then return end
        seen[key] = true
        choices[#choices + 1] = { key = key, data = data }
    end
    local function AddDirect(id, name, icon)
        if issecretvalue(id) or not id or issecretvalue(name) or not name or issecretvalue(icon) then return end
        Add(GetDirectActionKey(kind, id), {
            actionType = kind, actionID = id, name = name, icon = icon or "INV_Misc_QuestionMark",
            preview = kind == "spell" and "Spell" or "Item",
        })
    end

    if characterGUID and kind == "spell" then
        local bank = Enum.SpellBookSpellBank.Player
        local itemTypes = Enum.SpellBookItemType
        for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
            if line and not line.shouldHide and (not line.offSpecID or line.offSpecID == 0) then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if info and info.itemType == itemTypes.Spell and not info.isPassive and not info.isOffSpec then
                        local name = info.name
                        if info.subName and info.subName ~= "" then name = name .. " (" .. info.subName .. ")" end
                        AddDirect(info.spellID, name, info.iconID)
                    elseif info and info.itemType == itemTypes.Flyout then
                        local _, _, count = GetFlyoutInfo(info.actionID)
                        for flyoutSlot = 1, count or 0 do
                            local id, overrideID, known = GetFlyoutSlotInfo(info.actionID, flyoutSlot)
                            local spellID = overrideID and overrideID > 0 and overrideID or id
                            if known and spellID and not C_Spell.IsSpellPassive(spellID) then
                                local spell = C_Spell.GetSpellInfo(spellID)
                                if spell then AddDirect(spellID, spell.name, spell.iconID) end
                            end
                        end
                    end
                end
            end
        end
    elseif characterGUID and kind == "item" then
        for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and not issecretvalue(info.itemID) and info.itemID then
                    local id = info.itemID
                    local usable = C_Item.IsUsableItem(id)
                    if not seen[GetDirectActionKey(kind, id)] and not issecretvalue(usable) and usable then
                        AddDirect(id, C_Item.GetItemNameByID(id), info.iconFileID)
                    end
                end
            end
        end
    end

    -- Keep unavailable items visible only while selected, so players can uncheck them.
    for _, key in ipairs(actionIDs) do
        local data = actionsByID[key]
        if data and data.actionType == kind
            and (kind ~= "item" or carriedActionItems[data.actionID] or not IsEntryHidden("macros", key)) then
            Add(key, data)
        end
    end
    table.sort(choices, function(a, b)
        if a.data.name == b.data.name then return a.key < b.key end
        return a.data.name < b.data.name
    end)
    return choices
end

local function CreateListIcon(row, anchor, relativePoint)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", anchor, relativePoint, 4, 0)
    return icon
end

local function CreateActionPicker(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "ActionsPanel", mainPanel)
    panel.name = ACTIONS_TITLE
    panel.kind = "spell"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ACTIONS_TITLE)
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Check an entry to add it to Actions. Uncheck it to remove it from the wheel.")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    local rows, tabs = {}, {}
    local firstTab
    for _, tab in ipairs({
        {"spell", "Abilities", "Choose learned spells for the Actions wheel."},
        {"item", "Items", "Choose carried or equipped items for the Actions wheel."},
        {"macro", "Macros", "Choose saved account or character macros for the Actions wheel."},
    }) do
        local kind, label, tooltip = unpack(tab)
        local button = CreateTextButton(panel, label)
        button:SetSize(96, 25)
        button:SetDisabledFontObject(GameFontDisable)
        AddSettingsTooltip(button, label, tooltip)
        button:SetPoint("TOPLEFT", description, "BOTTOMLEFT", #tabs * 102, -10)
        button:SetScript("OnClick", function()
            panel.kind = kind
            scroll:SetVerticalScroll(0)
            panel:refresh()
        end)
        tabs[#tabs + 1] = { kind = kind, button = button }
        firstTab = firstTab or button
    end
    scroll:SetPoint("TOPLEFT", firstTab, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)

    local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 0, -6)
    empty:SetText("No entries available.")

    function panel:refresh()
        for _, tab in ipairs(tabs) do tab.button:SetEnabled(tab.kind ~= self.kind) end
        local choices = GetActionChoices(self.kind)
        local width = scroll:GetWidth()
        content:SetSize(width, math.max(28, #choices * 28))
        empty:SetShown(#choices == 0)
        for index, choice in ipairs(choices) do
            local row = rows[index]
            if not row then
                row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                row:SetSize(24, 24)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
                row.icon = CreateListIcon(row, row, "RIGHT")
                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.label:SetJustifyH("LEFT")
                row.label:SetWordWrap(false)
                AddSettingsTooltip(row, "Show in Actions", "Check to add this action to the wheel. Uncheck to remove it.")
                row:SetScript("OnClick", function(button)
                    local entry = button.choice
                    EmotePanel:SetActionSelected(entry.key, entry.data, button:GetChecked())
                end)
                rows[index] = row
            end
            row.choice = choice
            row:SetHitRectInsets(0, math.min(0, 24 - width), 0, 0)
            row.label:SetWidth(math.max(1, width - 64))
            row:SetChecked(not IsEntryHidden("macros", choice.key))
            SetIconTexture(row.icon, GetEntryIcon("macros", choice.key, choice.data))
            local name = GetEntryName("macros", choice.key, choice.data)
            if self.kind == "macro" then
                name = name .. "  ·  " .. choice.data.preview
            elseif self.kind == "item" and actionsByID[choice.key] and not carriedActionItems[choice.data.actionID] then
                name = name .. "  ·  Not carried"
            end
            row.label:SetText(name:gsub("|", "||"))
            row:Show()
        end
        for index = #choices + 1, #rows do rows[index]:Hide() end
    end
    panel:SetScript("OnShow", panel.refresh)
    scroll:HookScript("OnSizeChanged", function()
        if panel:IsVisible() then panel:refresh() end
    end)
    return panel
end

local function CreateHelpPanel(mainPanel)
    local helpPanel = CreateFrame("Frame", AddonName .. "HelpPanel", mainPanel)
    helpPanel.name = "Entries"
    helpPanel.parent = AddonName

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    helpTitle:SetPoint("TOPLEFT", 16, -16)
    helpTitle:SetText("Wheel Entry List")

    local section = "favorites"
    local listModes = { "favorites", "macros", unpack(categoryOrder) }
    table.insert(listModes, "professions")
    if EmotePanel.supportsPetWheel then table.insert(listModes, "pet") end
    local sectionPicker = CreateFrame("DropdownButton", AddonName .. "EntrySection", helpPanel, "WowStyle1DropdownTemplate")
    sectionPicker:SetWidth(168)
    sectionPicker:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -10)
    AddSettingsTooltip(sectionPicker, "Entry section", "Choose which group of wheel entries to view or edit.")
    sectionPicker:SetupMenu(function(_, root)
        for _, mode in ipairs(listModes) do
            local name = mode == "macros" and ACTIONS_TITLE
                or mode == "pet" and PET_TITLE
                or mode == "voicedEmotes" and voicedEmoteTitle or mode == "professions" and professionPage.title
                or mode == "favorites" and "Favorites" or PANEL_MODES[mode].title
            root:CreateRadio(name, function(value) return section == value end, function(value) helpPanel:SelectSection(value) end, mode)
        end
    end)

    local sectionAction = CreateTextButton(helpPanel, "Choose Actions")
    sectionAction:SetSize(112, 24)
    sectionAction:SetPoint("LEFT", sectionPicker, "RIGHT", 8, 0)
    AddSettingsTooltip(sectionAction, "Manage entries", "Add a custom entry to this section or choose spells, items, and macros for Actions.")
    sectionAction:SetScript("OnClick", function()
        if section == "macros" then
            if EmotePanel.combatView then return end
            EmotePanel.frame:Hide()
            Settings.OpenToCategory(categoryIDs.actions)
        elseif customEntryTypes[section] then
            EmotePanel:EditButton(section, nil, nil, true)
        end
    end)
    local resetOrder = CreateTextButton(helpPanel, "Reset Order")
    resetOrder:SetSize(100, 24)
    resetOrder:SetPoint("LEFT", sectionPicker, "RIGHT", 128, 0)
    resetOrder:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(resetOrder, "Reset Order", "Restore the selected section's default entry order.")
    resetOrder:SetScript("OnClick", function()
        EmotePanelSavedVars.entryOrder[section] = nil
        EmotePanel:RefreshEntryPages()
        helpPanel:refresh()
    end)

    local up = CreateTextButton(helpPanel, "Up")
    up:SetSize(48, 24)
    up:SetPoint("TOPLEFT", sectionPicker, "BOTTOMLEFT", 0, -8)
    up:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(up, "Move up", "Move the selected entry one place earlier in this section.")
    local down = CreateTextButton(helpPanel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(down, "Move down", "Move the selected entry one place later in this section.")
    local moveHint = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    moveHint:SetPoint("LEFT", down, "RIGHT", 8, 0)
    moveHint:SetText("Move selected entry")

    -- Create and store scroll frame reference both locally and globally
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", helpPanel,
        "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -30, 20)

    helpPanel.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    local rows, previousRows = {}, nil
    scrollFrame.content = content
    scrollFrame:SetScrollChild(content)

    local selectedEntry, selectedRow
    local function UpdateMoveButtons()
        up:SetEnabled(selectedRow ~= nil and selectedRow.previousID ~= nil)
        down:SetEnabled(selectedRow ~= nil and selectedRow.nextID ~= nil)
    end
    UpdateMoveButtons()

    local function MoveSelected(neighbor)
        if not neighbor or not selectedRow:move(neighbor) then return end
        helpPanel:refresh()
        if not selectedRow then return end
        local offset, height = scrollFrame:GetVerticalScroll(), scrollFrame:GetHeight()
        local top = selectedRow.orderY
        local bottom = top + selectedRow:GetHeight()
        if top < offset then
            scrollFrame:SetVerticalScroll(top)
        elseif bottom > offset + height then
            scrollFrame:SetVerticalScroll(bottom - height)
        end
    end
    up:SetScript("OnClick", function() MoveSelected(selectedRow and selectedRow.previousID) end)
    down:SetScript("OnClick", function() MoveSelected(selectedRow and selectedRow.nextID) end)

    local function CreateSelectableRow(move)
        local row = CreateFrame("Button", nil, content)
        row.move = move
        row.selection = AddAtlas(row, FOCUS_ATLAS)
        row.selection:SetAllPoints()
        row:SetHighlightAtlas(FOCUS_ATLAS)
        row:SetScript("OnClick", function()
            if selectedRow then selectedRow.selection:Hide() end
            selectedEntry = row.favoriteEntry or row
            selectedRow = row
            row.selection:Show()
            UpdateMoveButtons()
        end)
        return row
    end

    local function PlaceOrderRow(row, width, y, previousID, nextID)
        row.previousID, row.nextID = previousID, nextID
        row.orderY = y
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        local isSelected = selectedEntry == (row.favoriteEntry or row)
        row.selection:SetShown(isSelected)
        if isSelected then selectedRow = row end
    end

    local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 4, -8)
    local favoriteRows = {}

    local function CreateFavoriteRow()
        local row = CreateSelectableRow(function(self, neighbor)
            local entry = self.favoriteEntry
            if not SwapOrder(favorites, entry, neighbor) then return false end
            RefreshVisibleFavorites()
            EmotePanel:ShowStartPage()
            return true
        end)
        row.icon = CreateListIcon(row, row, "LEFT")
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(true)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        AddSettingsTooltip(row, "Favorite", "Select this favorite to move it up or down.")
        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT")
        AddSettingsTooltip(edit, "Edit entry", "Customize this entry's icon, text, or wheel placement.")
        edit:SetScript("OnClick", function()
            local entry = row.favoriteEntry
            local data = GetEntryData(entry.mode, entry.index)
            if data then EmotePanel:EditButton(entry.mode, entry.index, data, true, "favorites") end
        end)
        return row
    end

    local function RefreshFavoriteRows(width)
        local entries, labels, icons = {}, {}, {}
        for _, entry in ipairs(favorites) do
            local mode, index = entry.mode, entry.index
            local data = GetEntryData(mode, index)
            if data then
                entries[#entries + 1] = entry
                local preview = GetEntryPreview(mode, index, data):gsub("\n", " · ")
                labels[#entries] = (GetEntryName(mode, index, data) .. "  ·  " .. preview):gsub("|", "||")
                icons[#entries] = GetEntryIcon(mode, index, data)
            end
        end

        local y = 0
        empty:SetShown(#entries == 0)
        for position, entry in ipairs(entries) do
            local row = favoriteRows[position]
            if not row then
                row = CreateFavoriteRow()
                favoriteRows[position] = row
            end
            row.favoriteEntry = entry
            PlaceOrderRow(row, width, y, entries[position - 1], entries[position + 1])
            SetIconTexture(row.icon, icons[position])
            row.name:SetWidth(math.max(1, width - 96))
            row.name:SetText(labels[position])
            row:SetHeight(math.max(28, row.name:GetStringHeight() + 8))
            row:Show()
            y = y + row:GetHeight()
        end
        for position = #entries + 1, #favoriteRows do favoriteRows[position]:Hide() end
        return y + 12
    end

    local function CreateEntryRow(category, mode, index)
        local row = CreateSelectableRow(function(_, neighbor)
            if not MoveOrderedEntry(category, index, neighbor) then return false end
            EmotePanel:RefreshEntryPages()
            return true
        end)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT")
        AddSettingsTooltip(check, "Show on wheel", "Choose whether this entry appears on the wheel.")
        check:SetScript("OnClick", function(self)
            if mode == "macros" then
                EmotePanel:SetActionSelected(index, GetEntryData(mode, index), self:GetChecked())
            else
                SaveEntryVisibility(mode, index, self:GetChecked())
                EmotePanel:RefreshEntryPages()
            end
        end)
        row.check = check
        row.icon = CreateListIcon(row, check, "RIGHT")
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(true)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        AddSettingsTooltip(row, "Wheel entry", "Select this entry to move it up or down.")
        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT")
        AddSettingsTooltip(edit, "Edit entry", "Customize this entry's icon, text, or wheel placement.")
        edit:SetScript("OnClick", function()
            local data = GetEntryData(mode, index)
            if data then EmotePanel:EditButton(mode, index, data, true, category) end
        end)

        return row
    end

    helpPanel.refresh = function()
        selectedRow = nil
        local width = scrollFrame:GetWidth()
        content:SetWidth(width)
        if previousRows then
            for _, row in pairs(previousRows) do row:Hide() end
        end
        local config = customEntryTypes[section]
        sectionAction:SetShown(section == "macros" or config ~= nil)
        sectionAction:SetText(config and "Add " .. config.label or "Choose Actions")
        resetOrder:SetShown(section ~= "favorites")
        resetOrder:SetEnabled(EmotePanelSavedVars.entryOrder[section] ~= nil)
        empty:SetText(section == "pet" and "Summon a pet with an action bar to edit its entries."
            or "No entries in this section.")
        if section == "favorites" then
            previousRows = favoriteRows
            content:SetHeight(math.max(28, RefreshFavoriteRows(width)))
        else
            local mode = GetStorageMode(section)
            local sectionRows = rows[section] or {}
            rows[section], previousRows = sectionRows, sectionRows
            local entries = GetOrderedEntryIDs(section)
            if section == "macros" then
                local enabled = {}
                for _, index in ipairs(entries) do
                    if not IsEntryHidden(mode, index) then enabled[#enabled + 1] = index end
                end
                entries = enabled
            end
            empty:SetShown(#entries == 0)
            local y = 0
            for position, index in ipairs(entries) do
                local data = GetEntryData(mode, index)
                local row = sectionRows[index]
                if not row then
                    row = CreateEntryRow(section, mode, index)
                    sectionRows[index] = row
                end
                PlaceOrderRow(row, width, y, entries[position - 1], entries[position + 1])
                SetIconTexture(row.icon, GetEntryIcon(mode, index, data))
                row.label:SetWidth(math.max(1, width - 120))
                local preview = GetEntryPreview(mode, index, data):gsub("\n", " · ")
                local label = GetEntryName(mode, index, data) .. "  ·  " .. preview
                row.label:SetText(label:gsub("|", "||"))
                row:SetHeight(math.max(28, row.label:GetStringHeight() + 8))
                row.check:SetChecked(not IsEntryHidden(mode, index))
                row:Show()
                y = y + row:GetHeight()
            end
            content:SetHeight(math.max(28, y))
        end
        if not selectedRow then selectedEntry = nil end
        UpdateMoveButtons()
    end
    function helpPanel:SelectSection(mode)
        if section ~= mode then
            section = mode
            selectedEntry = nil
            scrollFrame:SetVerticalScroll(0)
        end
        self:refresh()
        sectionPicker:GenerateMenu()
    end

    helpPanel:SetScript("OnShow", function(self)
        if not EmotePanel.frame:IsShown() then RefreshProfessions() end
        self:refresh()
    end)
    helpPanel:SetScript("OnHide", function()
        local dialog = EmotePanel.customMessageDialog
        if dialog and dialog.fromSettings then dialog:Hide() end
    end)
    scrollFrame:HookScript("OnSizeChanged", function()
        if helpPanel:IsVisible() then
            helpPanel:refresh()
        end
    end)

    return helpPanel
end

local function CreateCategoriesPanel(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "CategoriesPanel", mainPanel)
    panel.name = "Categories"
    panel.parent = AddonName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Category Wheel")

    local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    toggle:SetSize(24, 24)
    toggle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    local toggleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    toggleLabel:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    toggleLabel:SetText("Open on Category Wheel")
    AddSettingsTooltip(toggle, "Open on Category Wheel", "Start on the category shortcuts. Turn this off to start on Favorites.", toggleLabel)

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -10)
    description:SetText("Select a category to move it. Use Edit to change its name or icon.")

    local selected
    local up = CreateTextButton(panel, "Up")
    up:SetSize(48, 24)
    up:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    up:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(up, "Move up", "Move the selected category one place earlier on the wheel.")
    local down = CreateTextButton(panel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(down, "Move down", "Move the selected category one place later on the wheel.")
    local placement = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    placement:SetPoint("LEFT", down, "RIGHT", 8, 0)
    local function MoveSelected(step)
        if not selected or not IsCategoryWheelEnabled() then return end
        local order = GetOrderedEntryIDs("categories")
        for position, id in ipairs(order) do
            if id == selected and MoveOrderedEntry("categories", id, order[position + step]) then
                panel:refresh()
                EmotePanel:ShowStartPage()
                break
            end
        end
    end
    up:SetScript("OnClick", function() MoveSelected(-1) end)
    down:SetScript("OnClick", function() MoveSelected(1) end)

    local reset = CreateTextButton(panel, "Reset Order")
    reset:SetSize(100, 24)
    reset:SetPoint("TOPLEFT", 16, -386)
    reset:SetDisabledFontObject(GameFontDisable)
    AddSettingsTooltip(reset, "Reset Order", "Restore the stock category order.")
    reset:SetScript("OnClick", function()
        if not IsCategoryWheelEnabled() then return end
        EmotePanelSavedVars.entryOrder.categories = nil
        panel:refresh()
        EmotePanel:ShowStartPage()
    end)
    local resetCategories = CreateTextButton(panel, "Reset Categories")
    resetCategories:SetSize(128, 24)
    resetCategories:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    AddSettingsTooltip(resetCategories, "Reset Categories", "Turn on the Category Wheel and restore its default names, icons, order, and visibility.")
    resetCategories:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS",
            "Turn on Category Wheel and restore its default names, icons, order, and visibility?", nil, function()
                EmotePanelSavedVars.categoryWheel = nil
                EmotePanelSavedVars.hiddenEntries.categories = nil
                EmotePanelSavedVars.entryOrder.categories = nil
                EmotePanelSavedVars.customIcons.categories = nil
                if EmotePanelSavedVars.customButtonNames then EmotePanelSavedVars.customButtonNames.categories = nil end
                panel:refresh()
                EmotePanel:ShowStartPage()
            end)
    end)

    local rows = {}
    for _, entry in ipairs(categoryEntries) do
        local id = entry.category
        local row = CreateFrame("Button", nil, panel)
        row.selection = AddAtlas(row, FOCUS_ATLAS)
        row.selection:SetAllPoints()
        row:SetHighlightAtlas(FOCUS_ATLAS)
        row:SetScript("OnClick", function()
            selected = id
            panel:refresh()
        end)
        row:SetHeight(30)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT")
        check:SetScript("OnClick", function(self)
            if not IsCategoryWheelEnabled() then return end
            SaveEntryVisibility("categories", id, self:GetChecked())
            panel:refresh()
            EmotePanel:ShowStartPage()
        end)
        row.check = check

        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT", -6, 0)
        AddSettingsTooltip(edit, "Edit category", "Customize this category's name, icon, or wheel placement.")
        edit:SetScript("OnClick", function() EmotePanel:EditButton("categories", id, entry, true) end)
        row.icon = CreateListIcon(row, check, "RIGHT")
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", edit, "LEFT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        AddSettingsTooltip(check, entry.name, "Choose whether this category appears on the Category Wheel.")
        AddSettingsTooltip(row, entry.name, "Select this category to move it up or down.")
        rows[id] = row
    end

    function panel:refresh()
        local enabled = IsCategoryWheelEnabled()
        toggle:SetChecked(enabled)
        reset:SetEnabled(enabled and EmotePanelSavedVars.entryOrder.categories ~= nil)
        local order = GetOrderedEntryIDs("categories")
        local slot = 0
        up:SetEnabled(false)
        down:SetEnabled(false)
        placement:SetText(enabled and "Select a category" or "Category Wheel off")
        for position, id in ipairs(order) do
            local row = rows[id]
            local data = categoryByID[id]
            local name = GetEntryName("categories", id, data):gsub("|", "||")
            row.label:SetText(name)
            SetIconTexture(row.icon, GetEntryIcon("categories", id, data))
            local y = -136 - (position - 1) * 30
            row:SetPoint("TOPLEFT", 16, y)
            row:SetPoint("TOPRIGHT", -24, y)
            row:SetAlpha(enabled and 1 or 0.5)
            local visible = not IsEntryHidden("categories", id)
            if visible then slot = slot + 1 end
            row.check:SetChecked(visible)
            row.check:SetEnabled(enabled)
            row:SetEnabled(enabled)
            row.selection:SetShown(enabled and id == selected)
            if enabled and id == selected then
                placement:SetText(name .. " · " .. (visible and "Slot " .. slot or "Hidden"))
                up:SetEnabled(position > 1)
                down:SetEnabled(position < #order)
            end
        end
    end

    toggle:SetScript("OnClick", function(self)
        EmotePanelSavedVars.categoryWheel = not not self:GetChecked()
        panel:refresh()
        EmotePanel:ShowStartPage()
    end)
    panel:SetScript("OnShow", panel.refresh)
    panel:refresh()
    return panel
end

local function CreatePositionControls(panel, anchor)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -13)
    title:SetText("Wheel position")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    description:SetJustifyH("LEFT")
    description:SetText("50% is centered. Higher values move the wheel right or up.")

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetSize(420, 82)
    controls:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    local function CreateSlider(axis, labelText, y)
        local slider = CreateFrame("Frame", AddonName .. "Position" .. axis, controls, "MinimalSliderWithSteppersTemplate")
        slider:SetSize(250, 20)
        slider:SetPoint("TOPLEFT", 108, y)
        slider:Init(50, 0, 100, 100)
        local label = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("RIGHT", slider, "LEFT", -10, 0)
        label:SetText(labelText)
        local direction = axis == "X" and "right" or "up"
        local tooltip = "Move the wheel " .. direction .. " by increasing the percentage. 50% centers this axis."
        AddSettingsTooltip(slider, labelText, tooltip, label)
        AddSettingsTooltip(slider.Slider, labelText, tooltip)
        AddSettingsTooltip(slider.Back, labelText, "Decrease this axis by one percentage point.")
        AddSettingsTooltip(slider.Forward, labelText, "Increase this axis by one percentage point.")
        slider.percentText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        slider.percentText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
        return slider
    end
    local xSlider = CreateSlider("X", "Horizontal (X)", -2)
    local ySlider = CreateSlider("Y", "Vertical (Y)", -28)

    local refreshing
    local function SetPercent(slider, percent)
        slider.percentText:SetText(("%d%%"):format(percent))
    end
    local function RefreshSlider(slider, offset, limit)
        local percent = limit > 0 and math.max(0, math.min(100, RoundOffset(50 + 50 * offset / limit))) or 50
        slider:SetEnabled(limit > 0)
        slider:SetValue(percent)
        SetPercent(slider, percent)
    end
    function panel:refreshPosition()
        local x, y = EmotePanel:GetPositionOffsets()
        local maxX, maxY = GetPositionLimits(EmotePanel.frame)
        refreshing = true
        RefreshSlider(xSlider, x, maxX)
        RefreshSlider(ySlider, y, maxY)
        refreshing = nil
    end

    local function OnValueChanged(slider, value)
        if refreshing then return end
        local x, y = EmotePanel:GetPositionOffsets()
        local maxX, maxY = GetPositionLimits(EmotePanel.frame)
        local percent = RoundOffset(value)
        local fraction = (percent - 50) / 50
        if slider == xSlider then
            x = RoundOffset(fraction * maxX)
        else
            y = RoundOffset(fraction * maxY)
        end
        EmotePanel:SetPositionOffsets(x, y)
        SetPercent(slider, percent)
    end
    local valueChanged = MinimalSliderWithSteppersMixin.Event.OnValueChanged
    xSlider:RegisterCallback(valueChanged, OnValueChanged, xSlider)
    ySlider:RegisterCallback(valueChanged, OnValueChanged, ySlider)

    local reset = CreateTextButton(controls, "Reset Position")
    reset:SetSize(116, 24)
    reset:SetPoint("BOTTOMLEFT", 0, 0)
    AddSettingsTooltip(reset, "Reset Position", "Return both position sliders to 50% and center the wheel.")
    reset:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS", "Return the wheel to the center of the screen?", nil, function()
            EmotePanelSavedVars.positions.emotePanel = nil
            EmotePanel:LoadPosition()
            panel:refreshPosition()
        end)
    end)
    return controls
end

local function CreateCustomizationPanel(mainPanel)
    local panel = CreateFrame("Frame", AddonName .. "CustomizationPanel", mainPanel)
    panel.name = "Customization"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Customization")

    local glyphLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    glyphLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    glyphLabel:SetText("Controller glyphs")
    local glyphDropdown = CreateFrame("DropdownButton", AddonName .. "GlyphStyle", panel, "WowStyle1DropdownTemplate")
    glyphDropdown:SetWidth(150)
    glyphDropdown:SetPoint("LEFT", glyphLabel, "RIGHT", 8, 0)
    AddSettingsTooltip(glyphDropdown, "Controller glyphs", "Choose which controller icons appear in prompts. Automatic follows WoW's active icon set.", glyphLabel)
    glyphDropdown:SetupMenu(function(_, root)
        local function IsSelected(value) return GetGlyphStyle() == value end
        local function Select(value)
            EmotePanelSavedVars.controllerGlyphs = value ~= "auto" and value or nil
            EmotePanel:RefreshControllerPrompts()
        end
        root:CreateRadio("Automatic", IsSelected, Select, "auto")
        for _, value in ipairs({"xbox", "playstation", "switch"}) do
            local style = GLYPH_STYLES[value]
            if GetStyleAtlas(style, "PAD1") then root:CreateRadio(style.name, IsSelected, Select, value) end
        end
    end)

    local display = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    display:SetPoint("TOPLEFT", glyphLabel, "BOTTOMLEFT", 0, -16)
    display:SetText("Wheel Display")
    local legend = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    legend:SetSize(24, 24)
    legend:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -4)
    local legendLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    legendLabel:SetPoint("LEFT", legend, "RIGHT", 4, 0)
    legendLabel:SetText("Show keybind legend")
    AddSettingsTooltip(legend, "Show keybind legend", "Show the controller shortcuts below the wheel.", legendLabel)
    legend:SetScript("OnClick", function(self)
        EmotePanelSavedVars.showKeybindLegend = not not self:GetChecked()
        EmotePanel:RefreshWheelFooter()
    end)

    local position = CreatePositionControls(panel, legend)
    local overrides = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    overrides:SetPoint("TOPLEFT", position, "BOTTOMLEFT", 0, -15)
    overrides:SetText("Entry overrides")
    local reset = CreateTextButton(panel, "Reset All Entry Overrides")
    reset:SetSize(190, 24)
    reset:SetPoint("TOPLEFT", overrides, "BOTTOMLEFT", 0, -6)
    AddSettingsTooltip(reset, "Reset All Entry Overrides", "Restore default icons, names, and text for built-in entries.")
    reset:SetScript("OnClick", function() StaticPopup_Show("EMOTEPANEL_RESET_ALL") end)
    local function Refresh(self)
        legend:SetChecked(EmotePanelSavedVars.showKeybindLegend ~= false)
        self:refreshPosition()
    end
    panel.OnRefresh = Refresh
    panel:SetScript("OnShow", Refresh)
    Refresh(panel)
    return panel
end

local function CreateWheelBindingControls(panel, header)
    local bindingColumn = 102
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetText("Wheel Keybind")

    local capture = CreateFrame("Frame", nil, panel)
    capture:Hide()
    capture:SetAllPoints(panel)
    capture:SetFrameStrata("TOOLTIP")
    local slot, input, chord
    local buttons = {}
    local function ControllerTip()
        if InputUtil.IsGamepadUIEnabled() then return GAMEPAD_BETA_TIP end
        if not C_CVar.GetCVarBool("GamePadEnable") then return "Check Enable WoW controller input to use your controller." end
        return "Assign a keyboard key or controller button."
    end
    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    local titles = {"Primary wheel keybind", "Secondary wheel keybind"}
    local petLabel
    if EmotePanel.supportsPetWheel then
        titles[3] = "Primary pet wheel keybind"
        titles[4] = "Secondary pet wheel keybind"
        petLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        petLabel:SetText("Pet Keybind")
    end

    local function BindingSlot(index)
        if index > 2 then return index - 2, true end
        return index, false
    end
    local function SetBindingAt(index, key)
        local bindingSlot, pet = BindingSlot(index)
        return EmotePanel:SetWheelBinding(bindingSlot, key, pet)
    end

    function panel:RefreshWheelBindings()
        for index, button in ipairs(buttons) do
            local key = EmotePanel:GetWheelBinding(BindingSlot(index))
            button:SetText(slot == index and "Press a key..." or key and (GetBindingText(key) or key) or "Not bound")
        end
    end

    for index, title in ipairs(titles) do
        local button = CreateTextButton(panel, "Not bound")
        button:SetSize(114, 24)
        if index == 1 then
            button:SetPoint("TOPLEFT", header, "BOTTOMLEFT", bindingColumn, -8)
            label:SetPoint("LEFT", button, "LEFT", -bindingColumn, 0)
        elseif index == 3 then
            button:SetPoint("TOPLEFT", buttons[1], "BOTTOMLEFT", 0, -6)
            petLabel:SetPoint("LEFT", button, "LEFT", -bindingColumn, 0)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 10, 0)
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouseButton)
            local sameSlot = slot == index
            capture:Hide()
            if InCombatLockdown() then
                status:SetText("Set the wheel keybind outside combat.")
            elseif mouseButton == "RightButton" then
                local success, message = SetBindingAt(index, nil)
                status:SetText(success and ControllerTip() or message)
                panel:RefreshWheelBindings()
            elseif not sameSlot then
                slot = index
                capture:EnableKeyboard(true)
                capture:EnableGamePadButton(true)
                capture:SetPropagateKeyboardInput(false)
                capture:Show()
                status:SetText("Press a keyboard key or controller button. Esc cancels.")
                panel:RefreshWheelBindings()
            end
        end)
        AddSettingsTooltip(button, title, "Click and press a keyboard key or controller button to assign it and replace its current WoW binding. Right-click clears this binding. The keybind works in and out of combat.", index == 1 and label or index == 3 and petLabel or nil)
        buttons[index] = button
    end
    status:SetPoint("TOPLEFT", buttons[3] or buttons[1], "BOTTOMLEFT", -bindingColumn, -6)
    status:SetWidth(370)
    status:SetJustifyH("LEFT")
    panel.wheelBindingButtons = buttons

    local gamepadCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    gamepadCheck:SetSize(24, 24)
    gamepadCheck:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -5)
    local gamepadLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    gamepadLabel:SetPoint("LEFT", gamepadCheck, "RIGHT", 4, 0)
    gamepadLabel:SetText("Enable WoW controller input")
    AddSettingsTooltip(gamepadCheck, "Enable WoW controller input",
        "Changes WoW's GamePadEnable setting for the entire game.", gamepadLabel)

    local function OnInputDown(_, key)
        if not slot then return end
        if key == "ESCAPE" then
            capture:Hide()
        elseif not input and not IsKeyPressIgnoredForBinding(key) then
            input = key
            chord = CreateKeyChordStringUsingMetaKeyState(key)
        end
    end
    local function OnInputUp(_, key)
        if not slot or input ~= key then return end
        local selectedSlot, binding = slot, chord
        capture:Hide()
        local success, message = SetBindingAt(selectedSlot, binding)
        status:SetText(success and ControllerTip() or message)
        panel:RefreshWheelBindings()
    end
    capture:SetScript("OnKeyDown", OnInputDown)
    capture:SetScript("OnKeyUp", OnInputUp)
    capture:SetScript("OnGamePadButtonDown", OnInputDown)
    capture:SetScript("OnGamePadButtonUp", OnInputUp)
    capture:SetScript("OnHide", function()
        slot, input, chord = nil, nil, nil
        status:SetText(ControllerTip())
        panel:RefreshWheelBindings()
    end)
    function panel:CancelWheelBindingCapture() capture:Hide() end
    function panel:RefreshControllerSetup()
        gamepadCheck:SetChecked(C_CVar.GetCVarBool("GamePadEnable") == true)
        if not slot then status:SetText(ControllerTip()) end
    end
    gamepadCheck:SetScript("OnClick", function(self)
        local value = self:GetChecked() and "1" or "0"
        capture:Hide()
        local success = C_CVar.SetCVar("GamePadEnable", value)
        panel:RefreshControllerSetup()
        if not success then status:SetText("WoW could not change GamePadEnable.") end
    end)
    panel:HookScript("OnHide", panel.CancelWheelBindingCapture)
    panel:RefreshWheelBindings()
    return gamepadCheck
end

local function CreateInterfaceOptions()
    -- Create the main panel (General Settings)
    local mainPanel = CreateFrame("Frame", AddonName .. "OptionsPanel", UIParent)
    mainPanel.name = AddonName

    -- Title at the top
    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("EmotePanel Options")
    local version = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 10, 0)
    version:SetText("v" .. addonVersion)

    local setup = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    setup:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    setup:SetText("Controller Setup")
    local gamepadCheck = CreateWheelBindingControls(mainPanel, setup)

    local behavior = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    behavior:SetPoint("TOPLEFT", gamepadCheck, "BOTTOMLEFT", 0, -16)
    behavior:SetText("Wheel behavior")

    local closeCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    closeCheck:SetSize(24, 24)
    closeCheck:SetPoint("TOPLEFT", behavior, "BOTTOMLEFT", 0, -5)
    closeCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.closePanelAfterAction = not not self:GetChecked()
        EmotePanel:SyncCombatWheel(true)
    end)
    local closeLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    closeLabel:SetPoint("LEFT", closeCheck, "RIGHT", 4, 0)
    closeLabel:SetText("Close panel after action")
    AddSettingsTooltip(closeCheck, "Close panel after action", "Close the wheel after most actions. Ordinary shortcuts such as emotes keep the combat wheel open.", closeLabel)

    local rememberCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    rememberCheck:SetSize(24, 24)
    rememberCheck:SetPoint("TOPLEFT", closeCheck, "BOTTOMLEFT", 0, -4)
    rememberCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.rememberLastAction = self:GetChecked() and true or nil
        if not self:GetChecked() then EmotePanel.lastAction, EmotePanel.lastPetAction = nil, nil end
        EmotePanel:SyncCombatWheel(true)
    end)
    local rememberLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rememberLabel:SetPoint("LEFT", rememberCheck, "RIGHT", 4, 0)
    rememberLabel:SetText("Remember last Action")
    AddSettingsTooltip(rememberCheck, "Remember last Action", "Reopen at the last action you used. The remembered action clears on logout or UI reload.", rememberLabel)

    local cooldownCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    cooldownCheck:SetSize(24, 24)
    cooldownCheck:SetPoint("TOPLEFT", rememberCheck, "BOTTOMLEFT", 0, -4)
    cooldownCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.macroCooldowns = not not self:GetChecked()
        EmotePanel:RefreshActionCooldowns()
    end)
    local cooldownLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cooldownLabel:SetPoint("LEFT", cooldownCheck, "RIGHT", 4, 0)
    cooldownLabel:SetText("Show action cooldowns")
    AddSettingsTooltip(cooldownCheck, "Show action cooldowns", "Show cooldown countdown numbers on Actions, Favorites, and the Pet Wheel. The circular swipe stays visible with numbers off.", cooldownLabel)

    local movementCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    movementCheck:SetSize(24, 24)
    movementCheck:SetPoint("TOPLEFT", cooldownCheck, "BOTTOMLEFT", 0, -4)
    movementCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.lockMovementStick = not not self:GetChecked()
    end)
    local movementLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    movementLabel:SetPoint("LEFT", movementCheck, "RIGHT", 4, 0)
    movementLabel:SetText("Lock movement stick")
    AddSettingsTooltip(movementCheck, "Lock movement stick", "Block character movement from the stick while a wheel is open and until you center it after closing. Turn this off to move while aiming.", movementLabel)

    local tooltipCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    tooltipCheck:SetSize(24, 24)
    tooltipCheck:SetPoint("TOPLEFT", movementCheck, "BOTTOMLEFT", 0, -4)
    tooltipCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.showWheelTooltips = self:GetChecked() and true or nil
        if not self:GetChecked() then EmotePanel:ShowWheelEntryTooltip(nil) end
    end)
    local tooltipLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tooltipLabel:SetPoint("LEFT", tooltipCheck, "RIGHT", 4, 0)
    tooltipLabel:SetText("Show wheel tooltips")
    AddSettingsTooltip(tooltipCheck, "Show wheel tooltips", "Show entry tooltips on mouse hover or when you aim at spells, items, macros, or pet actions with the controller.", tooltipLabel)

    local customizationPanel = CreateCustomizationPanel(mainPanel)
    EmotePanel.customizationPanel = customizationPanel
    local helpPanel = CreateHelpPanel(mainPanel)
    local actionPicker = CreateActionPicker(mainPanel)
    local categoriesPanel = CreateCategoriesPanel(mainPanel)

    local pagesTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pagesTitle:SetPoint("TOPLEFT", tooltipCheck, "BOTTOMLEFT", 0, -16)
    pagesTitle:SetText("More settings")
    local pageLinks = {
        {"categories", "Categories", "Enable Category Wheel and arrange its segments.\nTurn it off to open on Favorites."},
        {"customization", "Customization", "Learn how to edit icons and text or reset overrides."},
        {"help", "Entries", "Show, hide, reorder, and edit actions.\nManage spells, items, and saved macros."},
    }
    local previous = pagesTitle
    for _, page in ipairs(pageLinks) do
        local button = CreateTextButton(mainPanel, page[2])
        button:SetSize(120, 24)
        button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
        button:SetScript("OnClick", function()
            if EmotePanel.combatView then return end
            EmotePanel.frame:Hide()
            Settings.OpenToCategory(categoryIDs[page[1]])
        end)
        local help = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        help:SetPoint("LEFT", button, "RIGHT", 12, 0)
        help:SetJustifyH("LEFT")
        help:SetText(page[3])
        AddSettingsTooltip(button, page[2], page[3], help)
        previous = button
    end

    local resetTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    resetTitle:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -16)
    resetTitle:SetText("Reset settings")

    local resetGeneral = CreateTextButton(mainPanel, "Reset General")
    resetGeneral:SetSize(120, 24)
    resetGeneral:SetPoint("TOPLEFT", resetTitle, "BOTTOMLEFT", 0, -6)
    AddSettingsTooltip(resetGeneral, "Reset General", "Restore the defaults for wheel behavior, cooldown numbers, stick lock, and wheel tooltips.")
    resetGeneral:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS", "Restore default wheel behavior?", nil, function()
            EmotePanelSavedVars.closePanelAfterAction = nil
            EmotePanelSavedVars.rememberLastAction = nil
            EmotePanelSavedVars.macroCooldowns = nil
            EmotePanelSavedVars.lockMovementStick = nil
            EmotePanelSavedVars.showWheelTooltips = nil
            EmotePanel.lastAction, EmotePanel.lastPetAction = nil, nil
            closeCheck:SetChecked(true)
            rememberCheck:SetChecked(false)
            cooldownCheck:SetChecked(true)
            movementCheck:SetChecked(true)
            tooltipCheck:SetChecked(false)
            EmotePanel:ShowWheelEntryTooltip(nil)
            EmotePanel:RefreshActionCooldowns()
            EmotePanel:SyncCombatWheel(true)
        end)
    end)

    local resetAddon = CreateTextButton(mainPanel, "Reset to Defaults")
    resetAddon:SetSize(128, 24)
    resetAddon:SetPoint("LEFT", resetGeneral, "RIGHT", 8, 0)
    AddSettingsTooltip(resetAddon, "Reset to Defaults", "Restore all EmotePanel defaults for every character and reload the UI. WoW keybinds stay assigned.")
    resetAddon:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS",
            "Reset EmotePanel for all characters?\n\nThis clears saved settings, custom entries, Favorites, and Action selections, then reloads the UI. WoW keybinds stay assigned.",
            nil, function()
                if InCombatLockdown() then
                    print("|cFF00FF00EmotePanel:|r Reset the addon outside combat.")
                    return
                end
                -- Keep the current settings available until the UI saves them on reload.
                resetOnLogout = true
                ReloadUI()
            end)
    end)

    local function Refresh()
        mainPanel:RefreshWheelBindings()
        mainPanel:RefreshControllerSetup()
        closeCheck:SetChecked(EmotePanelSavedVars.closePanelAfterAction ~= false)
        rememberCheck:SetChecked(EmotePanelSavedVars.rememberLastAction == true)
        cooldownCheck:SetChecked(EmotePanelSavedVars.macroCooldowns ~= false)
        movementCheck:SetChecked(EmotePanelSavedVars.lockMovementStick ~= false)
        tooltipCheck:SetChecked(EmotePanelSavedVars.showWheelTooltips == true)
    end
    mainPanel.OnRefresh = Refresh
    mainPanel:HookScript("OnShow", Refresh)
    Refresh()

    -- Register all panels with the Settings system
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(category)
    EmotePanel.settingsCategoryID = category:GetID()

    categoryIDs.categories = Settings.RegisterCanvasLayoutSubcategory(category, categoriesPanel, categoriesPanel.name):GetID()
    categoryIDs.customization = Settings.RegisterCanvasLayoutSubcategory(category, customizationPanel, customizationPanel.name):GetID()
    local helpCategory = Settings.RegisterCanvasLayoutSubcategory(category, helpPanel, helpPanel.name)
    categoryIDs.help = helpCategory:GetID()
    categoryIDs.actions = Settings.RegisterCanvasLayoutSubcategory(category, actionPicker, actionPicker.name):GetID()

    return mainPanel
end

function EmotePanel:ToggleWheel(pet)
    local frame = self.frame
    pet = pet == true
    if not frame or self.combatView or (pet and (not self.supportsPetWheel or InCombatLockdown())) then return end
    if frame:IsShown() then
        local sameWheel = (currentPage.mode == "pet") == pet
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

function EmotePanel_Toggle()
    EmotePanel:ToggleWheel(false)
end

local function UseLauncher(mouseButton)
    if mouseButton == "RightButton" then
        if EmotePanel.settingsCategoryID and not InCombatLockdown() then OpenSettings() end
    else
        EmotePanel_Toggle()
    end
end

-- Blizzard registers this callback from the TOC when populating the Addon Compartment.
function EmotePanel_OnAddonCompartmentClick(_, mouseButton)
    UseLauncher(mouseButton)
end

local function CreateMinimapButton()
    local minimap = Minimap
    if not minimap then return end

    local button = CreateFrame("Button", "EmotePanelMinimapButton", minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    local icon = AddAtlas(button, LAUNCHER_ICON, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function SetPosition(angle)
        local radiusX, radiusY = minimap:GetWidth() / 2, minimap:GetHeight() / 2
        button:ClearAllPoints()
        button:SetPoint("CENTER", minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
    end
    local angle = EmotePanelSavedVars.minimapAngle
    SetPosition(type(angle) == "number" and angle or math.rad(225))

    local function DragButton()
        local centerX, centerY = minimap:GetCenter()
        if not centerX then return end
        local x, y = InputUtil.GetCursorPosition(minimap)
        local newAngle = math.atan2(y - centerY, x - centerX)
        EmotePanelSavedVars.minimapAngle = newAngle
        SetPosition(newAngle)
    end
    local function StopDragging()
        button:SetScript("OnUpdate", nil)
    end
    local function HideTooltip()
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end
    button:SetScript("OnDragStart", function()
        HideTooltip()
        button:SetScript("OnUpdate", DragButton)
    end)
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnClick", function(_, mouseButton) UseLauncher(mouseButton) end)
    button:SetScript("OnEnter", function()
        if button:GetScript("OnUpdate") then return end
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("EmotePanel v" .. addonVersion)
        GameTooltip:AddLine("Left-click to open or close the wheel.")
        GameTooltip:AddLine("Right-click for settings. Drag to move.")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnHide", function()
        StopDragging()
        HideTooltip()
    end)
end

local function ShowPagingHelp()
    local left = GamepadGlyph("PADLSHOULDER", "LB", 16)
    local right = GamepadGlyph("PADRSHOULDER", "RB", 16)
    print(("  %s / %s or %s changes pages."):format(
        left, right, GamepadGlyph("DIRPADHORIZONTAL", "D-pad left/right", 16)))
    print("  Scroll up for the next page or down for the previous page. Scrolling stops at the ends.")
    print("  Scroll up from Categories to open Actions. Scroll down from Actions page 1 to return.")
    print("  Gold arrows show the available controller paging directions.")
    print("  Right-click the center of the wheel to go back or close it.")
    print(("  From the opening Favorites or Categories page, use %s or %s for Actions."):format(
        left, GamepadGlyph("PADDLEFT", "D-pad left", 16)))
    if EmotePanel.supportsPetWheel then
        print("  Assign either Pet Keybind slot under Controller Setup to open or close the separate Pet Wheel.")
        print("  In /ep list, choose Pet to reorder, hide, or customize your active pet's entries.")
        print("  The Pet wheel dims unavailable actions and explains range and cooldown under the selected entry.")
        print(("  %s or right-click toggles autocast on supported pet abilities."):format(
            GamepadGlyph("PAD3", "X", 16)))
        print("  The Pet selector is violet by default, green for active commands and stances, gold for autocast on, and blue for autocast off.")
    end
end

local function ShowHelp()
    local function Glyph(key, fallback) return GamepadGlyph(key, fallback, 16) end
    print("|cFF00FF00EmotePanel commands|r")
    print("  /ep or /emotepanel - Toggle the regular wheel")
    print("  /ep config - Open EmotePanel settings")
    print("               Use Reset to Defaults to reset the whole addon")
    print("  /ep list - Reorder Favorites and manage wheel entries")
    print("  /ep actions - Choose spells, items, and saved macros for the Actions wheel")
    print("                Uncheck a Not carried item to remove it from the Items list")
    print("  /ep categories - Rename, customize, and reorder Category Wheel shortcuts")
    print("  /ep reset - Ask to reset custom icons, names, and text")
    print("  /ep debug - Show combat debug status")
    print("  /ep debug on or /ep debug off - Turn combat logging on or off for this session")
    print("  /ep scroll - Show paging controls (legacy command)")
    print("  /ep help - Show this command list")
    print("|cFF00FF00Wheel controls|r")
    print("  Assign Open or Close Emote Panel in /ep config under Controller Setup for spells, items, and macros in combat.")
    print("  Check Enable WoW controller input in Controller Setup to turn on GamePadEnable.")
    print("  " .. GAMEPAD_BETA_TIP)
    print("  Category Wheel and action cooldown numbers are on by default.")
    print("  Actions, Favorites, and the Pet Wheel show a circular swipe for cooldowns, including the GCD.")
    print("  Wheel icons depress when pressed. Spell icons show casts, charge recovery, interrupts, and proc glows.")
    print("  Enable Show wheel tooltips in /ep config to see details when hovering or aiming.")
    print("  The wheel uses its own controller navigation and pauses the ConsolePort interface cursor.")
    print("  Emote, Say, and Party highlights use WoW's chat colors.")
    print("  Emotes and Voiced Emotes show the selected name and control legend.")
    print("  Turn off Lock movement stick in /ep config to move while aiming the wheel.")
    print("  Enable Remember last Action in /ep config to reopen at the last action until logout or /reload.")
    print("  In /ep config under Customization, drag the position sliders or click their arrows. 50% is centered.")
    print(("  %s / %s or %s Select."):format(
        Glyph("PADLSTICKAXIS", "Left stick"), Glyph("PADRSTICKAXIS", "Right stick"), Glyph("DIRPADVERTICAL", "D-pad up/down")))
    print(("  %s Open or use. %s Back or close."):format(Glyph("PAD1", "A"), Glyph("PAD2", "B")))
    print(("  On the regular wheel, %s or right-click edits. %s or middle-click toggles a favorite."):format(
        Glyph("PAD4", "Y"), Glyph("PAD3", "X")))
    print(("  In Customize Entry, %s toggles visibility, %s moves the entry, %s resets, and %s goes back."):format(
        Glyph("PAD3", "X"), Glyph("DIRPADVERTICAL", "D-pad up/down"), Glyph("PADLSHOULDER", "LB"), Glyph("PAD2", "B")))
    print("  Customize Entry asks before discarding unsaved changes.")
    print("  Say Chat and Party Chat each have 16 defaults, including messages for campfires.")
    ShowPagingHelp()
end

local function HandleSlashCommand(msg)
    local command, option = string.match(msg, "^%s*(%S*)%s*(%S*)")
    command = command:lower()
    if command == "debug" then
        option = option:lower()
        if option == "on" or option == "off" then
            EmotePanel.combatDebug = option == "on"
        elseif option ~= "" then
            print("EmotePanel: Use /ep debug for status, /ep debug on to start, or /ep debug off to stop.")
            return
        end
        if EmotePanel.combatDebug then
            local input = EmotePanel.combatInput
            local page = input and input:IsShown() and EmotePanel.combatPages[input:GetAttribute("page")]
            EmotePanel:CombatDebug("Status", "on", "combat " .. tostring(InCombatLockdown()),
                EmotePanel.combatBindingReady and "keybind ready" or "keybind missing",
                page and page.title or "wheel closed")
        else
            print("EmotePanel combat debug off.")
        end
        return
    end
    if EmotePanel.combatView and command ~= "help" then
        print("EmotePanel: Use the wheel keybind to close the combat wheel first.")
        return
    end

    if command == "" then
        EmotePanel_Toggle()
    elseif command == "help" then
        ShowHelp()
    elseif command == "list" then
        if categoryIDs.help then
            EmotePanel.frame:Hide()
            EmotePanelHelpPanel:SelectSection("favorites")
            Settings.OpenToCategory(categoryIDs.help)
        else
            print("|cFF00FF00EmotePanel:|r Could not open help panel. Try '/ep config' instead.")
        end
    elseif command == "config" then
        OpenSettings()
    elseif command == "actions" and categoryIDs.actions then
        EmotePanel.frame:Hide()
        Settings.OpenToCategory(categoryIDs.actions)
    elseif command == "categories" and categoryIDs.categories then
        EmotePanel.frame:Hide()
        Settings.OpenToCategory(categoryIDs.categories)
    elseif command == "scroll" then
        ShowPagingHelp()
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
    if event == "PLAYER_LOGOUT" then
        if resetOnLogout then
            EmotePanelSavedVars = nil
            resetOnLogout = nil
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if EmotePanel.combatDebug then
            local addon, action = ...
            if not issecretvalue(addon) and addon == AddonName then EmotePanel:CombatDebug("WoW restriction", event, action) end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        EmotePanel:SetWheelPressed(nil)
        if event == "PLAYER_REGEN_ENABLED" then
            if EmotePanel.supportsPetWheel then
                ReadPetActions()
                BuildPetPages()
            end
            if not EmotePanel.gamepadReady then EmotePanel:SetupGamepad() end
            EmotePanel:SetupEditorGamepad()
            EmotePanel:LoadPosition()
            RestoreConsolePortCursor()
        else
            EmotePanel.optionsPanel:CancelWheelBindingCapture()
            if (EmotePanel.combatBindingReady or currentPage.mode == "pet") and not EmotePanel.combatView then
                EmotePanel.frame:StopMovingOrSizing()
                EmotePanel.frame:Hide()
            end
        end
        if EmotePanel.frame:IsShown() then
            EmotePanel:RefreshCombatAppearance()
            EmotePanel:RefreshActionCooldowns()
            EmotePanel:RefreshActionRanges()
            EmotePanel:RefreshGamepadHint()
        end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        EmotePanel:UpdateSecureWheelInput()
        EmotePanel:SyncCombatWheel(true)
        local panel = EmotePanel.customizationPanel
        if panel:IsVisible() then panel:refreshPosition() end
    elseif event == "UPDATE_BINDINGS" or event == "GAME_PAD_ACTIVE_CHANGED" then
        EmotePanel:SyncCombatWheel(true)
        if EmotePanel.optionsPanel then EmotePanel.optionsPanel:RefreshWheelBindings() end
    elseif event == "CVAR_UPDATE" then
        local name = ...
        if name == "GamePadEnable" or name == "InputDeviceInterfaceStyle" then
            EmotePanel.optionsPanel:RefreshControllerSetup()
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        if RefreshCarriedActionItems() then
            EmotePanel:RefreshCurrentEntryPages()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" and EmotePanel.frame:IsShown() then
            EmotePanel:RefreshActionCooldowns()
        end
        RefreshActionPicker("item")
    elseif event == "SPELLS_CHANGED" then
        RefreshActionPicker("spell")
    elseif event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "PET_ORDER_MOVE_TO_PENDING_CHANGED"
        or (event == "UNIT_PET" and ... == "player") or (event == "UNIT_FLAGS" and ... == "pet") then
        ReadPetActions()
        BuildPetPages()
        if EmotePanel.frame:IsShown() and currentPage.mode == "pet" then
            EmotePanel:RefreshPetPage()
        else
            EmotePanel:SyncCombatWheel()
        end
        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
    elseif event == "PET_BAR_UPDATE_USABLE" then
        if EmotePanel.frame:IsShown() and currentPage.mode == "pet" then EmotePanel:RefreshActionRanges() end
    elseif CAST_EVENTS[event] then
        local unit, _, spellID = ...
        if EmotePanel.frame:IsShown() and not issecretvalue(unit) and unit == "player" then
            local interrupted = event == "UNIT_SPELLCAST_INTERRUPTED" and not issecretvalue(spellID) and spellID
            EmotePanel:RefreshSpellFeedback(interrupted)
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if EmotePanel.frame:IsShown() then EmotePanel:RefreshSpellFeedback() end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_STATE"
        or event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_TARGET_CHANGED" or event == "PET_BAR_UPDATE_COOLDOWN" then
        if EmotePanel.frame:IsShown() then
            EmotePanel:RefreshActionCooldowns()
            if event == "PLAYER_TARGET_CHANGED" then EmotePanel:RefreshActionRanges() end
        end
    elseif event == "UPDATE_MACROS" then
        ReadActions()
        EmotePanel:RefreshEntryPages()
        local helpPanel = _G[AddonName .. "HelpPanel"]
        if helpPanel and helpPanel:IsVisible() then helpPanel:refresh() end
        RefreshActionPicker("macro")
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" and not characterGUID then
            ReadActions()
            EmotePanel:RefreshEntryPages()
        end
        EmotePanel:RefreshGroupEntries()
        if event == "PLAYER_ENTERING_WORLD" then
            EmotePanel:SyncCombatWheel(true)
            local initialLogin, reloadingUI = ...
            if initialLogin or reloadingUI then PrintLoginWarnings() end
        end
    elseif event == "SKILL_LINES_CHANGED" then
        local helpPanel = _G[AddonName .. "HelpPanel"]
        local listShown = helpPanel and helpPanel:IsVisible()
        if EmotePanel.combatView then
            RefreshProfessions()
            if listShown then helpPanel:refresh() end
            return
        end
        if EmotePanel.frame:IsShown() then
            local mode, slot = GetSectorEntry(EmotePanel.selected)
            local previousPageCount = FavoritePageCount()
            local wasFavoritePage = currentPage.mode == "favorites"
            RefreshProfessions()
            if listShown then helpPanel:refresh() end
            if not currentPageIndex or currentPage.mode == "pet" then return end
            local pageCount = FavoritePageCount()
            local page = currentPageIndex + pageCount - previousPageCount
            if wasFavoritePage then
                page = math.min(currentPageIndex, pageCount)
                for position, entry in ipairs(visibleFavorites) do
                    if entry.mode == mode and entry.index == slot then
                        EmotePanel:ShowPage(math.floor((position - 1) / SECTOR_COUNT) + 1, (position - 1) % SECTOR_COUNT + 1)
                        return
                    end
                end
            elseif currentPage == professionPage then
                for sector, skillLine in ipairs(professionPage.entries) do
                    if skillLine == slot then
                        EmotePanel:ShowPage(page, sector)
                        return
                    end
                end
            end
            EmotePanel:ShowPage(page)
        elseif listShown then
            RefreshProfessions()
            helpPanel:refresh()
        end
    elseif event == "ADDON_LOADED" and select(1, ...) == "ConsolePort_Cursor" and EmotePanel.frame then
        self:UnregisterEvent("ADDON_LOADED")
        if EmotePanel.frame:IsVisible() then SetConsolePortCursorObstructed(EmotePanel.frame, true) end
    elseif event == "ADDON_LOADED" and select(1, ...) == AddonName then
        EmotePanel:Initialize()
        EmotePanel.optionsPanel = CreateInterfaceOptions()
        CreateMinimapButton()
        self:RegisterEvent("PLAYER_LOGOUT")
        local _, cursorLoaded = C_AddOns.IsAddOnLoaded("ConsolePort_Cursor")
        if cursorLoaded then self:UnregisterEvent("ADDON_LOADED") end
        self:RegisterEvent("SKILL_LINES_CHANGED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("UPDATE_MACROS")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELL_UPDATE_CHARGES")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        for castEvent in pairs(CAST_EVENTS) do self:RegisterUnitEvent(castEvent, "player") end
        self:RegisterEvent("BAG_UPDATE_COOLDOWN")
        self:RegisterEvent("BAG_UPDATE_DELAYED")
        self:RegisterEvent("ACTIONBAR_UPDATE_STATE")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("UPDATE_BINDINGS")
        self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
        self:RegisterEvent("CVAR_UPDATE")
        self:RegisterEvent("ADDON_ACTION_BLOCKED")
        self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        if EmotePanel.supportsPetWheel then
            self:RegisterEvent("PET_BAR_UPDATE")
            self:RegisterEvent("PET_ORDER_MOVE_TO_PENDING_CHANGED")
            self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
            self:RegisterEvent("PET_BAR_UPDATE_USABLE")
            self:RegisterEvent("PET_UI_UPDATE")
            self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
            self:RegisterEvent("UNIT_PET")
            self:RegisterEvent("UNIT_FLAGS")
        end
        if not InCombatLockdown() then EmotePanel:SetupGamepad() end

        -- Print login message
        print("|cFF00FF00EmotePanel|r loaded. Type |cFFFFFF00/ep help|r for commands and instructions.")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
