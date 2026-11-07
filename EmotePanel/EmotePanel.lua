-- EmotePanel.lua
local AddonName = "EmotePanel"
local addonVersion = C_AddOns.GetAddOnMetadata(AddonName, "Version") or "Unknown"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"
_G["BINDING_NAME_CLICK EmotePanelCombatInput:Toggle"] = "Open or Close Emote Panel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

local PANEL_WIDTH, PANEL_HEIGHT = 432, 652
local WHEEL_SIZE = 382
local SECTOR_COUNT = 8
local SECTOR_ANGLE = 2 * math.pi / SECTOR_COUNT
local RANGE_CHECK_INTERVAL = 0.2
local ACTIONS_TITLE = "Actions"
local WHEEL_STICKS = { Movement = true, Left = true, Camera = true, Right = true }
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
local SELECTION_COLORS = {
    say = { 0.36, 0.84, 1 },
    party = { 0.48, 1, 0.46 },
    command = { 0.82, 0.54, 1 },
    panel = { 0.42, 0.95, 0.83 },
    profession = { 1, 0.61, 0.32 },
}
local COMBAT_DISABLED_COLOR = { 0.55, 0.55, 0.55 }

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
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",      action = "Hey!",                                   actionType = "say", icon = "Spell_Misc_EmotionHappy" },
            { name = "Well played", action = "Well played!",                           actionType = "say", icon = "Achievement_General_StayClassy" },
            { name = "Thanks",      action = "Thanks for the help!",                   actionType = "say", icon = "INV_Misc_GiftWrap_01" },
            { name = "No problem",  action = "No problem!",                            actionType = "say", icon = "Spell_Holy_BlessingOfProtection" },
            { name = "BRB",         action = "Be right back.",                         actionType = "say", icon = "INV_Misc_PocketWatch_01" },
            { name = "Bye",         action = "See you around!",                        actionType = "say", icon = "INV_Garrison_Hearthstone" },
            { name = "LFG nearby",  action = "Anyone nearby want to group up?",        actionType = "say", icon = "atlas:gamepad-radial-icon-groupfinder" },
            { name = "Quest",       action = "Anyone on this quest want to team up?",   actionType = "say", icon = "atlas:gamepad-radial-icon-quests" },
            { name = "Gratz",       action = "Congratulations!",                       actionType = "say", icon = "INV_Misc_CelebrationCake_01" },
            { name = "Trade",       action = "Would you like to trade?",               actionType = "say", icon = "INV_Misc_Coin_01" },
        }
    },
    party = {
        title = "Party Chat",
        list = {
            { name = "Follow Me",    action = "Follow me this way.",                   actionType = "party", icon = "Ability_Hunter_Pathfinding" },
            { name = "Need Break",   action = "Can we take a quick break?",             actionType = "party", icon = "INV_Drink_05" },
            { name = "Thanks Group", action = "Thanks for the run!",                   actionType = "party", icon = "INV_Misc_GiftWrap_02" },
            { name = "Good Job",     action = "Nice work, everyone!",                  actionType = "party", icon = "Achievement_Level_10" },
            { name = "Ready?",       action = "Everyone ready for the next pull?",     actionType = "party", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
            { name = "OOM",          action = "Out of mana. Please wait while I drink.", actionType = "party", icon = "INV_Potion_76" },
            { name = "Wait",         action = "Hold the pull. Let's regroup first.",   actionType = "party", icon = "INV_Misc_PocketWatch_02" },
            { name = "Pulling",      action = "Pulling now. Stay with me.",             actionType = "party", icon = "Ability_Hunter_SniperShot" },
            { name = "CC",           action = "Please use crowd control on my target.", actionType = "party", icon = "Spell_Nature_Polymorph" },
            { name = "Help",         action = "I need help with these mobs!",          actionType = "party", icon = "Spell_Holy_Resurrection" },
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

local function GetStorageMode(category)
    return category == "voicedEmotes" and "emotes" or category
end

local function GetEmoteToken(data)
    if data.token then return data.token end
    local alias = data.action:upper()
    return (hash_EmoteTokenList and hash_EmoteTokenList["/" .. alias]) or (alias == "BRAVO" and "APPLAUD") or alias
end

local function IsFactionEmote(token)
    return token == "FORTHEALLIANCE" or token == "FORTHEHORDE"
end

local function LoadNativeEmotes()
    local labels, existing = {}, {}
    for index = 1, MAXEMOTEINDEX or 0 do
        local prefix = "EMOTE" .. index
        local token = _G[prefix .. "_TOKEN"]
        if token and not labels[token] then labels[token] = _G[prefix .. "_CMD1"] end
    end
    for _, data in ipairs(PANEL_MODES.emotes.list) do existing[GetEmoteToken(data)] = true end
    for _, token in ipairs(TextEmoteSpeechList or {}) do voicedEmoteTokens[token] = true end

    local icons = {
        BEG = "INV_Misc_Coin_01", CHICKEN = "INV_Misc_Food_57", EAT = "INV_Misc_Food_15",
        SHY = "Spell_Misc_EmotionSad", SLEEP = "Spell_Nature_Sleep", LEAN = "Ability_Warrior_SecondWind",
        HELPME = "Spell_Holy_Resurrection", INCOMING = "Ability_Hunter_MarkedForDeath",
        CHARGE = "Ability_Warrior_Charge", FLEE = "Ability_Rogue_Sprint",
        ATTACKMYTARGET = "Ability_Warrior_BattleShout", OOM = "INV_Potion_76",
        FOLLOW = "Ability_Hunter_Pathfinding", WAIT = "INV_Misc_PocketWatch_02",
        HEALME = "Spell_Holy_Heal", OPENFIRE = "Ability_Hunter_SniperShot",
        HELLO = "Spell_Holy_LayOnHands", WELCOME = "Spell_Misc_EmotionHappy",
        CONGRATULATE = "INV_Misc_CelebrationCake_01", FLIRT = "Spell_Shadow_SoothingKiss",
        JOKE = "INV_Helm_LaughingSkull_01",
    }
    local names = {
        HELPME = "Help Me", ATTACKMYTARGET = "Attack My Target", OOM = "Out of Mana",
        FOLLOW = "Follow Me", HEALME = "Heal Me", OPENFIRE = "Open Fire", JOKE = "Silly",
    }
    local function AddEmotes(tokens)
        for _, token in ipairs(tokens) do
            local faction = IsFactionEmote(token)
            local id = "native:" .. (faction and "FACTION" or token)
            if not existing[token] and not nativeEmotes[id] then
                local action = (labels[token] or token:lower()):gsub("^/", "")
                nativeEmotes[id] = {
                    name = faction and "Faction Cheer" or names[token] or (action:gsub("^%l", string.upper)),
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
    if not nativeEmotes["native:FACTION"] then
        local faction = UnitFactionGroup("player", true)
        local token = faction == "Alliance" and "FORTHEALLIANCE" or faction == "Horde" and "FORTHEHORDE"
        if token then
            voicedEmoteTokens[token] = true
            AddEmotes({ token })
        end
    end
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
    if mode == "macros" then return actionsByID[index] end
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
    if page.snapshot then return unpack(page.snapshot[sector]) end
    local mode = page.mode
    if mode == "categories" then
        local id = page.entries[sector]
        return mode, id, categoryByID[id]
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
    local mode, key = GetSectorEntry(sector)
    if not mode then return end
    self.lastAction = { pageMode = currentPage.mode, mode = mode, key = key }
    if not self.combatView then self:SyncCombatResume() end
end

function EmotePanel:FindRememberedSector(page)
    local last = self.lastAction
    if not last or last.pageMode ~= page.mode then return end
    for sector = 1, page.count do
        local mode, key = GetSectorEntry(sector, page)
        if mode == last.mode and key == last.key then return sector end
    end
end

local function IsSecureWheelAction(data)
    return data.actionType == "macro" or data.actionType == "spell" or data.actionType == "item"
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
        local token = GetEmoteToken(data)
        if IsFactionEmote(token) then
            local faction = UnitFactionGroup("player", true)
            if faction == "Alliance" then
                token = "FORTHEALLIANCE"
            elseif faction == "Horde" then
                token = "FORTHEHORDE"
            end
        end
        -- The native chat edit box treats a truthy return as a restriction.
        local restricted = C_ChatInfo.PerformEmote(token)
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

StaticPopupDialogs["EMOTEPANEL_RESET_BUTTON"] = {
    text = "Reset this entry to its default icon, name, and text?",
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
    text = "Reset custom icons, names, and text on wheel entries?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        EmotePanelSavedVars.customMessages = {}
        EmotePanelSavedVars.customButtonNames = {}
        EmotePanelSavedVars.customIcons = {}

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

local function PrintLoginWarnings()
    local warnings = {}
    if not EmotePanel:HasWheelBinding() then
        warnings[#warnings + 1] = "No wheel keybind is set. Assign Open or Close Emote Panel in Options > Keybindings > Emote Panel."
    end

    local native = InputUtil.IsGamepadUIEnabled()
    if native or IsUsingGamepad() or (C_GamePad.IsEnabled() and #C_GamePad.GetAllDeviceIDs() > 0) then
        local _, loaded = C_AddOns.IsAddOnLoaded("ConsolePort")
        if not loaded then
            warnings[#warnings + 1] = "Install and enable ConsolePort for recommended controller support."
        end
    end
    if native then
        warnings[#warnings + 1] = "Gamepad (Beta) is unsupported because it can override addon keybinds. Turn off Enable Gamepad UI in Options > Gameplay > Gamepad."
    end
    if #warnings > 0 then
        print("|cffff0000EmotePanel: " .. table.concat(warnings, " ") .. "|r")
    end
end

local function IsResetPopupVisible()
    return StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON") or StaticPopup_Visible("EMOTEPANEL_RESET_ALL")
        or StaticPopup_Visible("EMOTEPANEL_RESET_SETTINGS")
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
        if dialog.picker then dialog.picker:Hide() end
    end)

    local iconButton = CreateTextButton(dialog, "Choose Icon")
    iconButton:SetSize(142, 30)
    iconButton:SetPoint("TOP", 20, -180)
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
    local up = CreateTextButton(placement, "Up")
    up:SetSize(40, 24)
    up:SetPoint("TOPLEFT", 0, -77)
    up:SetDisabledFontObject(GameFontDisable)
    local down = CreateTextButton(placement, "Down")
    down:SetSize(48, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    local moveLabel = placement:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moveLabel:SetPoint("LEFT", down, "RIGHT", 8, 0)
    placement.location, placement.show = location, show
    placement.up, placement.down, placement.moveLabel = up, down, moveLabel
    dialog.placement = placement

    local editHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editHint:SetPoint("BOTTOM", 0, 52)
    SetGlyphPrompt(editHint, function()
        return ("%s Choose Icon    %s Save"):format(GamepadGlyph("PAD4", "Y"), GamepadGlyph("PAD1", "A"))
    end)
    dialog.errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.errorText:SetPoint("BOTTOM", 0, 86)
    dialog.errorText:SetTextColor(1, 0.4, 0.4)

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
    dialog.iconButton = iconButton
    dialog.icon = icon
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

local function HasEditableText(data)
    return data.custom or data.actionType == "say" or data.actionType == "party" or data.actionType == "command"
end

local function GetEntryName(mode, index, data)
    if mode == "categories" then return data.name end
    return (HasEditableText(data) and GetCustomButtonName(mode, index)) or data.name
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
    SetSelectionTint(self.highlight, color)
    SetSelectionTint(self.slots[self.selected].border, color)
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

function EmotePanel:Select(index)
    if index then
        if currentPage.count == 0 then return end
        index = (index - 1) % currentPage.count + 1
        if index == self.selected then return end
    end

    if self.selected then
        local previousBorder = self.slots[self.selected].border
        previousBorder:SetAtlas(ICON_BORDER)
        SetSelectionTint(previousBorder)
    end
    self.selected = index
    if not index then
        self.highlight:Hide()
        self.selectionName:SetText("")
        self.messagePreview:SetText("")
        self:RefreshGamepadHint()
        return
    end
    self.highlight:Show()
    local border = self.slots[index].border
    border:SetAtlas(SELECTED_ICON_BORDER)
    local angle = (index - 1) * SECTOR_ANGLE
    local radius = self.highlightRadius
    self.highlight:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)
    -- Blizzard's highlight atlas points down before rotation.
    self.highlight:SetRotation(math.pi - angle)
    local mode, slot, data = GetSectorEntry(index)
    ApplySelectedTint(self, data, IsCombatBlocked(data))
    self.selectionName:SetText(GetEntryName(mode, slot, data))
    self.messagePreview:SetText(GetEntryPreview(mode, slot, data):gsub("|", "||"))
    self:RefreshGamepadHint()
end

local function PlacementName(category)
    if category == "macros" then return ACTIONS_TITLE end
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
    local order = GetPlacementOrder(context)
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

    return function(categoryChanged)
        local shown = not not controls.show:GetChecked()
        if shown ~= originallyShown then SaveEntryVisibility(mode, index, shown) end
        local reordered = false
        if #swaps > 0 and (not categoryChanged or context == "favorites") then
            local saved = context == "favorites" and favorites or GetPlacementOrder(context)
            for _, neighbor in ipairs(swaps) do
                if SwapOrder(saved, entry, neighbor) then reordered = true end
            end
            if reordered and context ~= "favorites" then EmotePanelSavedVars.entryOrder[context] = saved end
        end
        return reordered or shown ~= originallyShown
    end
end

local function RevealEditedEntry(panel, context, mode, index)
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

function EmotePanel:EditButton(mode, index, data, fromSettings, context)
    if not self.customMessageDialog then
        self.customMessageDialog = CreateCustomMessageDialog()
        self.customMessageDialog:HookScript("OnShow", function() self:UpdateSecureWheelInput() end)
        self.customMessageDialog:HookScript("OnHide", function() self:UpdateSecureWheelInput() end)
    end

    local dialog = self.customMessageDialog
    dialog.fromSettings = fromSettings
    local creating = index == nil
    if creating then
        local config = customEntryTypes[mode]
        data = { name = "", action = "", icon = config.icon, actionType = config.actionType, custom = true }
    end
    local editableText = HasEditableText(data)
    local nativeCommand = data.actionType == "command" and data.run ~= nil
    local iconTop = editableText and 180 or 60
    dialog:SetHeight(iconTop + 130 + (data.custom and 28 or 0) + (creating and 0 or 111))
    dialog.placement:SetShown(not creating)
    local savePlacement
    if not creating then
        local category = mode == "emotes" and voicedEmoteTokens[GetEmoteToken(data)] == true and "voicedEmotes" or mode
        context = context or (not fromSettings and currentPage.mode == "favorites" and "favorites") or category
        dialog.placement:ClearAllPoints()
        dialog.placement:SetPoint("TOPLEFT", dialog, "TOPLEFT", 22, -iconTop - 38)
        savePlacement = SetupPlacement(dialog.placement, category, context, mode, index, data)
    end
    dialog.nameBox:SetShown(editableText)
    dialog.nameBox.label:SetShown(editableText)
    dialog.messageBox:SetShown(editableText)
    dialog.messageBox.label:SetShown(editableText)
    dialog.messageBox.label:SetText(nativeCommand and "Slash override (optional)" or data.actionType == "emote" and "Emote (e.g. /wave)"
        or data.actionType == "command" and "Slash command" or "Message")
    dialog.resetButton:SetShown(not data.custom)
    dialog.iconButton:SetPoint("TOP", 20, -iconTop)
    local previousName = GetEntryName(mode, index, data)
    local previousMessage = editableText and (GetCustomMessage(mode, index) or data.action) or ""
    if nativeCommand then previousMessage = GetSlashCommand(mode, index, data) or "" end
    dialog.nameBox:SetText(previousName)
    dialog.messageBox:SetText(previousMessage)
    dialog.defaultIcon = GetIconPath(data.custom and customEntryTypes[mode].icon or data.icon)
    dialog.pendingIcon = GetEntryIcon(mode, index, data)
    SetIconTexture(dialog.icon, dialog.pendingIcon)
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
        dialog:Hide()
    end)
    dialog.errorText:SetText("")
    dialog.resetButton:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_BUTTON", nil, nil, {
            mode = mode,
            index = index,
            dialog = dialog,
        })
    end)
    dialog:Show()
end

function EmotePanel:ActivateSector(index, mouseButton, fromMouse)
    local mode, slot, data = GetSectorEntry(index)
    if not data or (data.available and not data.available()) then return end
    if currentPage == categoryWheel then
        if mouseButton == "LeftButton" then
            local first = GetCategoryPageRange(data.category)
            if first then
                self:ShowPage(first, 1)
            else
                self:DisplayPage(nil, { mode = data.category, title = data.name, count = 0 })
            end
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
        or IsResetPopupVisible())
end

function EmotePanel:UpdateSecureWheelInput()
    if InCombatLockdown() then return end
    local button = self.secureWheelInput
    if self.frame:IsShown() and self:CanUseWheel() then
        for sector = 1, currentPage.count do
            local _, _, data = GetSectorEntry(sector)
            if RequiresOutOfCombat(data) then
                local x, y = self.wheel:GetCenter()
                if not x then break end
                button = button or self:CreateSecureWheelInput()
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

        local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:EnableMouse(false)
        cooldown:SetDrawSwipe(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetScript("OnCooldownDone", function()
            slot.icon:SetDesaturated(slot.combatBlocked)
        end)
        slot.cooldown = cooldown

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
        GameTooltip:AddLine(GetEntryPreview(mode, slot, data), 1, 1, 1, true)
        if currentPage ~= categoryWheel then
            GameTooltip:AddLine("Right-click to edit", 0.7, 0.7, 0.7)
            local favoriteHint = FindFavorite(mode, slot) and "Middle-click to remove favorite" or "Middle-click to favorite"
            GameTooltip:AddLine(favoriteHint, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end
    local function StopMouseSelection()
        wheel:SetScript("OnUpdate", nil)
        lastX, lastY = nil, nil
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
    end
    local function StartMouseSelection()
        wheel:SetScript("OnUpdate", UpdateMouseSelection)
        UpdateMouseSelection()
    end
    local function MouseDown(_, mouseButton)
        if (mouseButton == "LeftButton" or mouseButton == "RightButton" or mouseButton == "MiddleButton")
            and self:CanUseWheel() then
            mouseDownButton = mouseButton
            mouseDownSector = SectorUnderCursor(GetCursorPosition())
            mouseDownPage = currentPage
        end
    end
    local function TakeMouseClick(mouseButton)
        if mouseButton ~= mouseDownButton then return end
        local pressedSector, pressedPage = mouseDownSector, mouseDownPage
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if not pressedSector or pressedPage ~= currentPage or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(GetCursorPosition())
        if index == pressedSector then return index end
    end
    local function FinishClick(index, mouseButton, fromMouse)
        if not index then return end
        self:ActivateSector(index, mouseButton, fromMouse)
        if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
    end
    local function SetMouseScripts(button)
        button:SetScript("OnEnter", StartMouseSelection)
        button:SetScript("OnLeave", StopMouseSelection)
        button:HookScript("OnHide", StopMouseSelection)
        button:SetScript("OnMouseDown", MouseDown)
        button:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton ~= "LeftButton" then FinishClick(TakeMouseClick(mouseButton), mouseButton, true) end
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
        button:SetSize(WHEEL_SIZE, WHEEL_SIZE)
        button:SetFrameStrata("DIALOG")
        button:EnableMouse(true)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("_onshow", [[
            self:SetBindingClick(true, "PAD1", self:GetName(), "WheelActivate")
        ]])
        button:SetAttribute("_onhide", [[ self:ClearBindings() ]])
        button:SetAttribute("_onstate-combat", [[ if newstate == "combat" then self:Hide() end ]])
        RegisterStateDriver(button, "combat", "[combat] combat; peace")
        SetMouseScripts(button)
        local function ClearAction()
            button:SetAttribute("type", nil)
            button:SetAttribute("macro", nil)
            button:SetAttribute("spell", nil)
            button:SetAttribute("item", nil)
            button:SetAttribute("clickbutton", nil)
        end
        local clickedSector, ranSecureAction, controllerPage
        button:HookScript("OnHide", function() controllerPage = nil end)
        button:SetScript("PreClick", function(_, input, down)
            clickedSector, ranSecureAction = nil, false
            if InCombatLockdown() then return end
            ClearAction()
            if down then
                if input == "WheelActivate" then controllerPage = currentPage end
                return
            end
            local pressedPage = controllerPage
            if input == "WheelActivate" then
                controllerPage = nil
                -- The binding has received the release. Resume capturing ordinary input.
                self.gamepadInput:SetPropagateKeyboardInput(false)
            end
            if not (self.frame:IsShown() and self:CanUseWheel()) then return end
            if input == "LeftButton" then
                clickedSector = TakeMouseClick(input)
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
            end
        end)
        button:HookScript("PostClick", function(_, input)
            if not InCombatLockdown() then ClearAction() end
            if ranSecureAction then
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

local function UpdateActionCooldown(cooldown, data)
    local item, spellID = GetActionItemOrSpell(data)
    if item then
        local startTime, duration, enabled = C_Item.GetItemCooldown(item)
        if not (issecretvalue(startTime) or issecretvalue(duration) or issecretvalue(enabled))
            and enabled and startTime > 0 and duration > 0 and startTime + duration > GetTime() then
            cooldown:SetCooldown(startTime, duration)
            return true
        end
    elseif spellID then
        -- Keep the duration opaque so Lua never needs to read restricted cooldown times.
        local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
        if not issecretvalue(duration) and duration then
            cooldown:SetCooldownFromDurationObject(duration, true)
            -- The texture accepts a secret boolean directly.
            return duration:IsActive()
        end
    end
    cooldown:Clear()
    return false
end

function EmotePanel:RefreshActionCooldowns()
    local shown = self.frame:IsShown()
    local showNumbers = EmotePanelSavedVars.macroCooldowns == true
    for index, slot in ipairs(self.slots) do
        local data = shown and select(3, GetSectorEntry(index))
        local active = false
        if data and IsSecureWheelAction(data) and not IsCombatItemMissing(data) then
            slot.cooldown:SetHideCountdownNumbers(not showNumbers)
            active = UpdateActionCooldown(slot.cooldown, data)
        else
            slot.cooldown:Clear()
        end
        slot.icon:SetDesaturated(slot.combatBlocked or active)
    end
end

local function GetActionInRange(data)
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
    local hasTarget = self.frame:IsShown() and UnitExists("target")
    local canCheck = not issecretvalue(hasTarget) and hasTarget
    for index, slot in ipairs(self.slots) do
        local data = canCheck and not slot.combatBlocked and select(3, GetSectorEntry(index))
        local inRange
        if data and IsSecureWheelAction(data) then inRange = GetActionInRange(data) end
        local outOfRange = not issecretvalue(inRange) and inRange == false
        if outOfRange ~= slot.outOfRange then
            slot.outOfRange = outOfRange
            local greenAndBlue = outOfRange and 0.3 or 1
            slot.icon:SetVertexColor(1, greenAndBlue, greenAndBlue)
        end
    end
end

function EmotePanel:RefreshWheel(selection)
    for index, slot in ipairs(self.slots) do
        local used = index <= currentPage.count
        if used then
            local mode, entryIndex, data = GetSectorEntry(index)
            SetIconTexture(slot.icon, GetEntryIcon(mode, entryIndex, data), true)
            slot.border:SetAtlas(ICON_BORDER)
            SetSelectionTint(slot.border)
            slot.favorite:SetShown(currentPage.mode ~= "favorites" and FindFavorite(mode, entryIndex) ~= nil)
            used = not IsCombatItemMissing(data)
        end
        slot:SetShown(used)
    end
    local nextSelection = selection or self.selected
    self.selected = nil
    self:RefreshCombatAppearance()
    self:RefreshActionCooldowns()
    self:RefreshActionRanges()
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
        end
        self.selectionName:SetText(emptyText)
        self.messagePreview:SetText("")
        self:RefreshGamepadHint()
    end
    self:UpdateSecureWheelInput()
    self:SyncCombatWheel()
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
        self:UpdateSecureWheelInput()
    end)

    local caption = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("TOP", 0, -10)
    caption:SetTextColor(0.91, 0.76, 0.49)
    caption:SetText("EMOTE WHEEL")

    self.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText:SetPoint("TOP", 0, -26)
    self.titleText:SetTextColor(1, 0.96, 0.87)
    self.titleText:SetText(currentPage.title)

    self.pageArrows = {}
    for direction = -1, 1, 2 do
        local arrow = CreateFrame("Button", nil, frame)
        local atlas = direction < 0 and "common-icon-backarrow" or "common-icon-forwardarrow"
        arrow:SetSize(14, 22)
        arrow:SetPoint("TOP", direction * 118, -21)
        arrow:SetNormalAtlas(atlas)
        arrow:SetHighlightAtlas(atlas, "ADD")
        arrow:SetScript("OnClick", function() self:CycleMode(direction) end)
        table.insert(self.pageArrows, arrow)
    end

    self.backButton = CreateTextButton(frame, "Back")
    self.backButton:SetSize(40, 24)
    self.backButton:SetPoint("TOP", -152, -13)
    self.backButton:SetScript("OnClick", function() self:BackOrClose() end)
    self.backButton:Hide()

    self.closeButton = CreateCloseButton(frame)

    local help = CreateTextButton(frame, "?")
    help:SetSize(28, 28)
    help:SetPoint("TOPLEFT", 11, -11)
    help:SetScript("OnClick", OpenSettings)
    self.helpButton = help

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
    self:RefreshWheelDisplay()
    frame:HookScript("OnShow", function()
        if self.combatView then return end
        if RefreshCarriedActionItems() then BuildCategoryPages() end
        RefreshProfessions()
        self:ShowStartPage(true)
    end)
    if InputDeviceIconSetManager then
        InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(self.RefreshControllerPrompts, self)
    end
end

function EmotePanel:RefreshWheelDisplay()
    local saved = EmotePanelSavedVars
    self.helpButton:SetShown(saved.showHelpButton ~= false)
    self.closeButton:SetShown(saved.showCloseButton ~= false)
    local legend = saved.showKeybindLegend ~= false
    self.legendFooter:SetShown(legend)
    self.navigationHint:SetShown(legend)
    self.gamepadHint:SetShown(legend)
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
    if currentPage.mode == "categories" and self.pageArrows[1]:IsShown() then
        navigation = navigation .. "       " .. GamepadGlyph("PADDLEFT", "Left") .. " / "
            .. GamepadGlyph("PADLSHOULDER", "LB") .. " " .. ACTIONS_TITLE
    elseif currentPage.mode == "macros" and self.backButton:IsShown() then
        local _, last = GetCategoryPageRange("macros")
        local toCategories = currentPageIndex == last
        if self.combatView then toCategories = currentPage.right == 0 end
        local destination = toCategories and "Categories" or "Previous page"
        navigation = navigation .. "       " .. GamepadGlyph("PADDRIGHT", "Right") .. " / "
            .. GamepadGlyph("PADRSHOULDER", "RB") .. " " .. destination
    elseif self.pageArrows[1]:IsShown() then
        navigation = navigation .. "       " .. GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " / "
            .. GamepadGlyph("PADLSHOULDER", "LB") .. " " .. GamepadGlyph("PADRSHOULDER", "RB") .. " Page"
    end
    self.navigationHint:SetText(navigation)
    local mode, slot, data = GetSectorEntry(self.selected)
    local actions
    if currentPage.mode == "categories" then
        actions = data and GamepadGlyph("PAD1", "A") .. " Open    " or ""
    elseif data then
        local favoriteAction = FindFavorite(mode, slot) and "Unfavorite" or "Favorite"
        local primaryAction = (data.actionType == "profession" or data.actionType == "panel") and "Open" or "Use"
        actions = IsCombatItemMissing(data) and "Not carried"
            or IsCombatBlocked(data) and "Unavailable in combat"
            or GamepadGlyph("PAD1", "A") .. " " .. primaryAction
        if not self.combatView then
            actions = actions .. "    " .. GamepadGlyph("PAD3", "X") .. " " .. favoriteAction
                .. "    " .. GamepadGlyph("PAD4", "Y") .. " Edit"
        end
        actions = actions .. "    "
    elseif currentPage == professionPage or EmotePanelSavedVars.categoryWheel then
        actions = ""
    else
        actions = "Browse pages and press " .. GamepadGlyph("PAD3", "X") .. " to add    "
    end
    self.gamepadHint:SetText(actions .. GamepadGlyph("PAD2", "B") .. (self.backButton:IsShown() and " Back" or " Close"))
end

function EmotePanel:DisplayPage(index, page, selection)
    if self.combatView then return end
    currentPageIndex = index
    currentPage = page
    local nested = EmotePanelSavedVars.categoryWheel
    local inCategory = nested and page ~= categoryWheel
    local canPage = not nested
    local actionsShortcut = nested and page.mode == "macros"
    if inCategory then
        local first, last = GetCategoryPageRange(page.category or page.mode)
        canPage = first ~= last
        if actionsShortcut then canPage = index > first end
    end
    self.backButton:SetShown(inCategory == true)
    self.pageArrows[1]:SetShown(canPage or (page == categoryWheel and GetCategoryPageRange("macros") ~= nil))
    self.pageArrows[2]:SetShown(canPage or actionsShortcut == true)
    self.titleText:SetText(currentPage.title)
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self:RefreshWheel(selection)
end

function EmotePanel:ShowPage(index, selection)
    self:DisplayPage(index, GetPage(index), selection)
end

local function MakeCategoryWheel()
    local entries = {}
    for _, id in ipairs(GetOrderedEntryIDs("categories")) do
        if not IsEntryHidden("categories", id) then table.insert(entries, id) end
    end
    return { mode = "categories", title = "Categories", entries = entries, count = #entries }
end

function EmotePanel:BuildCombatLayout()
    local pages, nested = {}, EmotePanelSavedVars.categoryWheel == true
    local last = FavoritePageCount() + #categoryPages
    local function AddPage(id, source)
        local page = { mode = source.mode, count = source.count, title = source.title, snapshot = {}, actions = {} }
        for sector = 1, source.count do
            local mode, key, data = GetSectorEntry(sector, source)
            page.snapshot[sector] = { mode, key, data }
            local kind, value = data.actionType
            if source.mode == "categories" then
                kind, value = "page", GetCategoryPageRange(data.category)
                if not value then
                    value = #pages + 1
                    pages[value] = { mode = data.category, title = data.name, count = 0, snapshot = {}, actions = {}, back = 0 }
                end
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
    return pages, nested and 0 or 1
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
    self.pageArrows[1]:SetShown(page.left ~= nil)
    self.pageArrows[2]:SetShown(page.right ~= nil)
    self.backButton:SetShown(page.back ~= nil)
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
    if EmotePanelSavedVars.categoryWheel then
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
    if EmotePanelSavedVars.categoryWheel then
        self:DisplayPage(nil, categoryWheel, 1)
    else
        self:ShowPage(1, 1)
    end
end

function EmotePanel:BackOrClose()
    if EmotePanelSavedVars.categoryWheel and currentPage ~= categoryWheel then
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
    RefreshProfessionPage()
    RefreshVisibleFavorites()
    self:ShowStartPage()
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
end

function EmotePanel:RefreshCurrentEntryPages()
    if self.combatView then
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
    elseif first and EmotePanelSavedVars.categoryWheel and not actions then
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
    if currentPage == categoryWheel and direction < 0 then
        local _, last = GetCategoryPageRange("macros")
        if last then self:ShowPage(last, 1) end
        return
    end
    if not currentPageIndex then return end
    local first, last = 1, FavoritePageCount() + #categoryPages
    if EmotePanelSavedVars.categoryWheel then
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
    if currentPage == categoryWheel then return end
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
    self:CreateWheelMovementGuard()
    local frame = self.frame
    local input = CreateFrame("Frame", nil, frame)
    input:SetAllPoints(frame)
    self.gamepadInput = input
    local pressed = {}
    local activationPage
    local function PropagateButton(propagate)
        if not InCombatLockdown() then input:SetPropagateKeyboardInput(propagate) end
        return propagate
    end
    local function CloseForGameMenu() frame:Hide() end
    local function PreviousPage() self:CycleMode(-1) end
    local function NextPage() self:CycleMode(1) end
    local actions = {
        PADDUP = function() if self.selected then self:Select(self.selected - 1) end end,
        PADDDOWN = function() if self.selected then self:Select(self.selected + 1) end end,
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
        PAD2 = function() self.customMessageDialog:Hide() end,
        PAD4 = function() self.customMessageDialog.iconButton:Click() end,
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
        if IsResetPopupVisible() then return end
        local dialog = self.customMessageDialog
        if dialog and dialog:IsShown() then
            if dialog.picker and dialog.picker:IsShown() then return pickerActions[key] end
            if not dialog.nameBox:HasFocus() and not dialog.messageBox:HasFocus() then return editorActions[key] end
            return
        end
        if key ~= "PAD4" or self.selected then return actions[key] end
    end
    input:SetScript("OnGamePadButtonDown", function(_, key)
        if key == "PAD1" and self.secureWheelInput and self.secureWheelInput:IsShown() then return PropagateButton(true) end
        local action = GetAction(key)
        if not action or (action ~= CloseForGameMenu and IsModifierKeyDown()) then return PropagateButton(true) end
        pressed[key] = action
        if action == actions.PAD1 then activationPage = currentPage end
        return PropagateButton(false)
    end)
    input:SetScript("OnGamePadButtonUp", function(_, key)
        if key == "PAD1" and self.secureWheelInput and self.secureWheelInput:IsShown() then
            pressed[key] = nil
            return PropagateButton(true)
        end
        local action = pressed[key]
        if not action then return PropagateButton(true) end
        pressed[key] = nil
        PropagateButton(false)
        if action == actions.PAD1 and activationPage ~= currentPage then return false end
        if action == GetAction(key) then
            if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
            action()
        end
        return false
    end)
    input:SetScript("OnGamePadStick", function(_, stick, x, y)
        if not WHEEL_STICKS[stick] or IsModifierKeyDown() or not self:CanUseWheel() then
            return true
        end
        -- Let the movement stick's neutral event stop movement that started before the wheel opened.
        if (stick == "Movement" or stick == "Left") and x == 0 and y == 0 then
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
    end)
    input:EnableGamePadButton(true)
    input:EnableGamePadStick(true)
    self.gamepadReady = true
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

function EmotePanel:SetPositionOffsets(x, y)
    local maxX = math.max(0, (UIParent:GetWidth() - self.frame:GetWidth()) / 2)
    local maxY = math.max(0, (UIParent:GetHeight() - self.frame:GetHeight()) / 2)
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
        if currentPage.mode ~= "macros" and currentPage.mode ~= "favorites" then return end
        rangeElapsed = rangeElapsed + elapsed
        if rangeElapsed >= RANGE_CHECK_INTERVAL then
            rangeElapsed = 0
            self:RefreshActionRanges()
        end
    end)
    self.frame:HookScript("OnHide", function()
        self:UpdateSecureWheelInput()
        if not self.combatView and self.gamepadInput then self.gamepadInput:Show() end
        if self.customMessageDialog then self.customMessageDialog:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_RESET_ALL")
        StaticPopup_Hide("EMOTEPANEL_RESET_SETTINGS")
    end)

    -- Hide by default
    self.frame:Hide()

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

    -- Keep saved entries selectable even while unavailable, including entries added by older builds.
    for _, key in ipairs(actionIDs) do
        local data = actionsByID[key]
        if data and data.actionType == kind then Add(key, data) end
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
    for _, tab in ipairs({{"spell", "Abilities"}, {"item", "Items"}, {"macro", "Macros"}}) do
        local kind, label = unpack(tab)
        local button = CreateTextButton(panel, label)
        button:SetSize(96, 25)
        button:SetDisabledFontObject(GameFontDisable)
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
    local sectionPicker = CreateFrame("DropdownButton", AddonName .. "EntrySection", helpPanel, "WowStyle1DropdownTemplate")
    sectionPicker:SetWidth(168)
    sectionPicker:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -10)
    sectionPicker:SetupMenu(function(_, root)
        for _, mode in ipairs(listModes) do
            local name = mode == "macros" and ACTIONS_TITLE
                or mode == "voicedEmotes" and voicedEmoteTitle or mode == "professions" and professionPage.title
                or mode == "favorites" and "Favorites" or PANEL_MODES[mode].title
            root:CreateRadio(name, function(value) return section == value end, function(value) helpPanel:SelectSection(value) end, mode)
        end
    end)

    local sectionAction = CreateTextButton(helpPanel, "Choose Actions")
    sectionAction:SetSize(112, 24)
    sectionAction:SetPoint("LEFT", sectionPicker, "RIGHT", 8, 0)
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
    resetOrder:SetScript("OnClick", function()
        EmotePanelSavedVars.entryOrder[section] = nil
        EmotePanel:RefreshEntryPages()
        helpPanel:refresh()
    end)

    local up = CreateTextButton(helpPanel, "Up")
    up:SetSize(48, 24)
    up:SetPoint("TOPLEFT", sectionPicker, "BOTTOMLEFT", 0, -8)
    up:SetDisabledFontObject(GameFontDisable)
    local down = CreateTextButton(helpPanel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
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
        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT")
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
        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT")
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
        empty:SetText("No entries in this section.")
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

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -10)
    description:SetText("Select a category to move it. Uncheck it to hide its segment.")

    local selected
    local up = CreateTextButton(panel, "Up")
    up:SetSize(48, 24)
    up:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    up:SetDisabledFontObject(GameFontDisable)
    local down = CreateTextButton(panel, "Down")
    down:SetSize(56, 24)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)
    down:SetDisabledFontObject(GameFontDisable)
    local placement = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    placement:SetPoint("LEFT", down, "RIGHT", 8, 0)
    local function MoveSelected(step)
        if not selected or not EmotePanelSavedVars.categoryWheel then return end
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
    reset:SetScript("OnClick", function()
        if not EmotePanelSavedVars.categoryWheel then return end
        EmotePanelSavedVars.entryOrder.categories = nil
        panel:refresh()
        EmotePanel:ShowStartPage()
    end)
    local resetCategories = CreateTextButton(panel, "Reset Categories")
    resetCategories:SetSize(128, 24)
    resetCategories:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    resetCategories:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS",
            "Turn off Category Wheel and restore its default category order and visibility?", nil, function()
                EmotePanelSavedVars.categoryWheel = nil
                EmotePanelSavedVars.hiddenEntries.categories = nil
                EmotePanelSavedVars.entryOrder.categories = nil
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
            if not EmotePanelSavedVars.categoryWheel then return end
            local hidden = EmotePanelSavedVars.hiddenEntries
            hidden.categories = hidden.categories or {}
            hidden.categories[id] = not self:GetChecked() or nil
            panel:refresh()
            EmotePanel:ShowStartPage()
        end)
        row.check = check

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(entry.name)
        rows[id] = row
    end

    function panel:refresh()
        local enabled = EmotePanelSavedVars.categoryWheel == true
        toggle:SetChecked(enabled)
        reset:SetEnabled(enabled and EmotePanelSavedVars.entryOrder.categories ~= nil)
        local order = GetOrderedEntryIDs("categories")
        local slot = 0
        up:SetEnabled(false)
        down:SetEnabled(false)
        placement:SetText(enabled and "Select a category" or "Category Wheel off")
        for position, id in ipairs(order) do
            local row = rows[id]
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
                placement:SetText(categoryByID[id].name .. " · " .. (visible and "Slot " .. slot or "Hidden"))
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
    description:SetText("Offsets from screen center. Dragging the wheel also saves its position.")

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetSize(420, 44)
    controls:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -8)
    local function CreateOffsetBox(axis, labelText, x)
        local label = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, 0)
        label:SetText(labelText)
        local box = CreateFrame("EditBox", AddonName .. "Position" .. axis, controls, "InputBoxScriptTemplate")
        SkinPanel(box)
        box:SetSize(90, 24)
        box:SetPoint("BOTTOMLEFT", controls, "BOTTOMLEFT", x + 5, 0)
        box:SetFontObject(GameFontHighlight)
        box:SetTextColor(1, 1, 1, 1)
        box:SetJustifyH("CENTER")
        box:SetTextInsets(6, 6, 0, 0)
        box:SetAutoFocus(false)
        box:SetMaxLetters(12)
        return box
    end
    local xBox = CreateOffsetBox("X", "Horizontal (X)", 0)
    local yBox = CreateOffsetBox("Y", "Vertical (Y)", 112)
    local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -6)
    status:SetJustifyH("LEFT")

    function panel:refreshPosition()
        local x, y = EmotePanel:GetPositionOffsets()
        xBox:SetText(("%.1f"):format(x))
        yBox:SetText(("%.1f"):format(y))
        status:SetText("Positive X moves right. Positive Y moves up.")
    end

    local function Apply()
        local x, y = tonumber(xBox:GetText()), tonumber(yBox:GetText())
        if not (x and y and math.abs(x) < math.huge and math.abs(y) < math.huge) then
            status:SetText("Enter a number for both X and Y.")
            return
        end
        EmotePanel:SetPositionOffsets(x, y)
        xBox:ClearFocus()
        yBox:ClearFocus()
        panel:refreshPosition()
    end

    for _, box in ipairs({xBox, yBox}) do
        box:SetScript("OnEnterPressed", Apply)
        box:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            panel:refreshPosition()
        end)
    end
    local apply = CreateTextButton(controls, "Apply")
    apply:SetSize(64, 24)
    apply:SetPoint("BOTTOMLEFT", 224, 0)
    apply:SetScript("OnClick", Apply)

    local reset = CreateTextButton(controls, "Reset Position")
    reset:SetSize(116, 24)
    reset:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS", "Return the wheel to the center of the screen?", nil, function()
            EmotePanelSavedVars.positions.emotePanel = nil
            EmotePanel:LoadPosition()
            panel:refreshPosition()
        end)
    end)
    return status
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
    local checks = {}
    local anchor = display
    for _, option in ipairs({
        {"showHelpButton", "Show Help button (?)"},
        {"showCloseButton", "Show Close button (X)"},
        {"showKeybindLegend", "Show keybind legend"},
    }) do
        local key, text = unpack(option)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(text)
        check:SetScript("OnClick", function(self)
            EmotePanelSavedVars[key] = not not self:GetChecked()
            EmotePanel:RefreshWheelDisplay()
        end)
        checks[key] = check
        anchor = check
    end

    local position = CreatePositionControls(panel, anchor)
    local overrides = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    overrides:SetPoint("TOPLEFT", position, "BOTTOMLEFT", 0, -15)
    overrides:SetText("Entry overrides")
    local reset = CreateTextButton(panel, "Reset All Entry Overrides")
    reset:SetSize(190, 24)
    reset:SetPoint("TOPLEFT", overrides, "BOTTOMLEFT", 0, -6)
    reset:SetScript("OnClick", function() StaticPopup_Show("EMOTEPANEL_RESET_ALL") end)
    local function Refresh(self)
        for key, check in pairs(checks) do check:SetChecked(EmotePanelSavedVars[key] ~= false) end
        self:refreshPosition()
    end
    panel:SetScript("OnShow", Refresh)
    Refresh(panel)
    return panel
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
    setup:SetText("Controller setup")
    local controllerHelp = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    controllerHelp:SetPoint("TOPLEFT", setup, "BOTTOMLEFT", 0, -6)
    controllerHelp:SetText("Enable ConsolePort and turn off Gamepad (Beta).")
    local keybind = CreateTextButton(mainPanel, "Wheel Keybind")
    keybind:SetSize(115, 24)
    keybind:SetPoint("TOPLEFT", controllerHelp, "BOTTOMLEFT", 0, -8)
    keybind:SetScript("OnClick", function()
        if InCombatLockdown() or not Settings.KEYBINDINGS_CATEGORY_ID then return end
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_EMOTEPANEL)
    end)

    local behavior = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    behavior:SetPoint("TOPLEFT", keybind, "BOTTOMLEFT", 0, -16)
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

    local closeHelp = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    closeHelp:SetPoint("TOPLEFT", closeCheck, "BOTTOMLEFT", 0, -4)
    closeHelp:SetText("Uncheck to keep the wheel open after most actions.")

    local rememberCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    rememberCheck:SetSize(24, 24)
    rememberCheck:SetPoint("TOPLEFT", closeHelp, "BOTTOMLEFT", 0, -4)
    rememberCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.rememberLastAction = self:GetChecked() and true or nil
        if not self:GetChecked() then EmotePanel.lastAction = nil end
        EmotePanel:SyncCombatWheel(true)
    end)
    local rememberLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rememberLabel:SetPoint("LEFT", rememberCheck, "RIGHT", 4, 0)
    rememberLabel:SetText("Remember last Action")

    local cooldownCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    cooldownCheck:SetSize(24, 24)
    cooldownCheck:SetPoint("TOPLEFT", rememberCheck, "BOTTOMLEFT", 0, -4)
    cooldownCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.macroCooldowns = self:GetChecked() and true or nil
        EmotePanel:RefreshActionCooldowns()
    end)
    local cooldownLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cooldownLabel:SetPoint("LEFT", cooldownCheck, "RIGHT", 4, 0)
    cooldownLabel:SetText("Show action cooldowns")

    local customizationPanel = CreateCustomizationPanel(mainPanel)
    EmotePanel.customizationPanel = customizationPanel
    local helpPanel = CreateHelpPanel(mainPanel)
    local actionPicker = CreateActionPicker(mainPanel)
    local categoriesPanel = CreateCategoriesPanel(mainPanel)

    local pagesTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pagesTitle:SetPoint("TOPLEFT", cooldownCheck, "BOTTOMLEFT", 0, -12)
    pagesTitle:SetText("More settings")
    local pageLinks = {
        {"categories", "Categories", "Enable Category Wheel and arrange its segments.\nWith it off, the wheel opens on Favorites."},
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
        previous = button
    end

    local resetTitle = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    resetTitle:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -11)
    resetTitle:SetText("Reset settings")

    local resetGeneral = CreateTextButton(mainPanel, "Reset General")
    resetGeneral:SetSize(120, 24)
    resetGeneral:SetPoint("TOPLEFT", resetTitle, "BOTTOMLEFT", 0, -7)
    resetGeneral:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_SETTINGS", "Restore default wheel behavior?", nil, function()
            EmotePanelSavedVars.closePanelAfterAction = nil
            EmotePanelSavedVars.rememberLastAction = nil
            EmotePanelSavedVars.macroCooldowns = nil
            EmotePanel.lastAction = nil
            closeCheck:SetChecked(true)
            rememberCheck:SetChecked(false)
            cooldownCheck:SetChecked(false)
            EmotePanel:RefreshActionCooldowns()
            EmotePanel:SyncCombatWheel(true)
        end)
    end)

    local function Refresh()
        closeCheck:SetChecked(EmotePanelSavedVars.closePanelAfterAction ~= false)
        rememberCheck:SetChecked(EmotePanelSavedVars.rememberLastAction == true)
        cooldownCheck:SetChecked(EmotePanelSavedVars.macroCooldowns == true)
    end
    mainPanel:SetScript("OnShow", Refresh)
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

-- Global toggle function
function EmotePanel_Toggle()
    local frame = EmotePanel.frame
    if not frame or EmotePanel.combatView then return end
    if not frame:IsShown() and InCombatLockdown() and EmotePanel.combatBindingReady and EmotePanel.gamepadInput then
        EmotePanel.gamepadInput:Hide()
    end
    frame:SetShown(not frame:IsShown())
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
    print(("  %s / %s, %s, or the page arrows change pages."):format(
        left, right, GamepadGlyph("DIRPADHORIZONTAL", "D-pad left/right", 16)))
    print(("  From the opening Favorites or Categories page, use %s or %s for Actions."):format(
        left, GamepadGlyph("PADDLEFT", "D-pad left", 16)))
end

local function ShowHelp()
    local function Glyph(key, fallback) return GamepadGlyph(key, fallback, 16) end
    print("|cFF00FF00EmotePanel commands|r")
    print("  /ep or /emotepanel - Toggle the regular wheel")
    print("  /ep config - Open EmotePanel settings")
    print("  /ep list - Reorder Favorites and manage wheel entries")
    print("  /ep actions - Choose spells, items, and saved macros for the Actions wheel")
    print("  /ep categories - Set up and reorder the opening Category Wheel")
    print("  /ep reset - Ask to reset custom icons, names, and text")
    print("  /ep debug - Show combat debug status")
    print("  /ep debug on or /ep debug off - Turn combat logging on or off for this session")
    print("  /ep scroll - Show paging controls (legacy command)")
    print("  /ep help - Show this command list")
    print("|cFF00FF00Wheel controls|r")
    print("  In combat, use Open or Close Emote Panel in WoW's Keybindings for spells, items, and macros.")
    print("  Enable Remember last Action in /ep config to reopen at the last action until logout or /reload.")
    print(("  %s / %s or %s Select."):format(
        Glyph("PADLSTICKAXIS", "Left stick"), Glyph("PADRSTICKAXIS", "Right stick"), Glyph("DIRPADVERTICAL", "D-pad up/down")))
    print(("  %s Open or use. %s Back or close."):format(Glyph("PAD1", "A"), Glyph("PAD2", "B")))
    print(("  On the regular wheel, %s or right-click edits. %s or middle-click toggles a favorite."):format(
        Glyph("PAD4", "Y"), Glyph("PAD3", "X")))
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
local function RefreshActionPicker(kind)
    local picker = _G[AddonName .. "ActionsPanel"]
    if picker and picker:IsVisible() and picker.kind == kind then picker:refresh() end
end

local function OnEvent(self, event, ...)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if EmotePanel.combatDebug then
            local addon, action = ...
            if not issecretvalue(addon) and addon == AddonName then EmotePanel:CombatDebug("WoW restriction", event, action) end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            if not EmotePanel.gamepadReady then EmotePanel:SetupGamepad() end
            EmotePanel:LoadPosition()
        else
            if EmotePanel.combatBindingReady and not EmotePanel.combatView then
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
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        if RefreshCarriedActionItems() then
            EmotePanel:RefreshCurrentEntryPages()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" and EmotePanel.frame:IsShown() then
            EmotePanel:RefreshActionCooldowns()
        end
        RefreshActionPicker("item")
    elseif event == "SPELLS_CHANGED" then
        RefreshActionPicker("spell")
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_STATE"
        or event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_TARGET_CHANGED" then
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
            if not currentPageIndex then return end
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
    elseif event == "ADDON_LOADED" and select(1, ...) == AddonName then
        EmotePanel:Initialize()
        EmotePanel.optionsPanel = CreateInterfaceOptions()
        CreateMinimapButton()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("SKILL_LINES_CHANGED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("UPDATE_MACROS")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELL_UPDATE_CHARGES")
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
        self:RegisterEvent("ADDON_ACTION_BLOCKED")
        self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        if not InCombatLockdown() then EmotePanel:SetupGamepad() end

        -- Print login message
        print("|cFF00FF00EmotePanel|r loaded. Type |cFFFFFF00/ep help|r for commands and instructions.")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
