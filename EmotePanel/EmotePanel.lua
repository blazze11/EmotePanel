-- EmotePanel.lua
local AddonName = "EmotePanel"
local EmotePanel = {}
BINDING_HEADER_EMOTEPANEL = "Emote Panel"
_G["BINDING_NAME_Open Emote Panel"] = "Open or Close Emote Panel"

-- Initialize the addon namespace
_G[AddonName] = EmotePanel

local PANEL_WIDTH, PANEL_HEIGHT = 432, 652
local WHEEL_SIZE = 382
local SECTOR_COUNT = 8
local SECTOR_ANGLE = 2 * math.pi / SECTOR_COUNT
local WHEEL_STICKS = { Movement = true, Left = true, Camera = true, Right = true }
local WHEEL_ATLAS = "gamepad-radial-menu-wheelbg"
local SELECTION_ATLAS = "gamepad-radial-menu-selected"
local ICON_BORDER = "gamepad-actionbar-circleslot-border-normal"
local SELECTED_ICON_BORDER = "gamepad-actionbar-circleslot-border-selected"
local ICON_PATH = "Interface\\Icons\\"
local PANEL_ATLAS = "gamepad-footer-slot-bg"
local PANEL_BORDER_ATLAS = "gamepad-footer-slot-frameneutral"
local FOCUS_ATLAS = "gamepad-footer-slot-framefocused"
local SIT_INDEX = 30 -- Favorites store the original emote slot number.
local SELECTION_COLORS = {
    say = { 0.36, 0.84, 1 },
    party = { 0.48, 1, 0.46 },
    command = { 0.82, 0.54, 1 },
    panel = { 0.42, 0.95, 0.83 },
    profession = { 1, 0.61, 0.32 },
}

-- Default positions for the panels
local DEFAULT_POSITIONS = {
    emotePanel = {
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = 0
    },
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
        }
    }
}

-- Favorites and icon overrides use these slots. Append new shortcuts.
PANEL_MODES.panels = {
    title = "Game Panels",
    list = {
        { name = "Character Info", icon = "atlas:gamepad-radial-icon-character", open = function() EmotePanel:ShowCharacterLauncher() end },
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
local professionPage = { mode = "professions", title = "Professions", count = 0, entries = {} }
local categoryWheel = {
    mode = "categories", title = "Categories", count = SECTOR_COUNT, entries = {
        { category = "favorites", name = "Favorites", icon = "atlas:collections-icon-favorites" },
        { category = "emotes", name = "Emotes", icon = "Spell_Misc_EmotionHappy", actionType = "emote" },
        { category = "voicedEmotes", name = voicedEmoteTitle, icon = "Ability_Warrior_BattleShout", actionType = "emote" },
        { category = "chat", name = "Say Chat", icon = "atlas:gamepad-radial-icon-chat", actionType = "say" },
        { category = "party", name = "Party Chat", icon = "atlas:gamepad-radial-icon-communities", actionType = "party" },
        { category = "commands", name = "Commands", icon = "INV_Misc_Gear_01", actionType = "command" },
        { category = "panels", name = "Game Panels", icon = "atlas:gamepad-radial-icon-character", actionType = "panel" },
        { category = "professions", name = "Professions", icon = "INV_Misc_Note_06", actionType = "profession" },
    },
}
local learnedProfessions = {}
local professionsBySkillLine = {}
local currentPageIndex, currentPage
local favorites, visibleFavorites

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
    if mode == "professions" then return professionsBySkillLine[index] end
    if mode == "emotes" and type(index) == "string" then return nativeEmotes[index] end
    local config = PANEL_MODES[mode]
    if config and type(index) == "number" and index < 0 then
        local entries = EmotePanelSavedVars.entries[mode]
        return entries and entries[-index]
    end
    return config and config.list[index]
end

local function ForEachEntry(category, callback)
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
    local hidden = EmotePanelSavedVars.hiddenEntries[mode]
    return hidden and hidden[index]
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
        if not IsEntryHidden(mode, index) then table.insert(entries, index) end
    end
    return entries
end

local function BuildCategoryPages()
    wipe(categoryPages)
    for _, category in ipairs(categoryOrder) do
        local mode = GetStorageMode(category)
        local title = category == "voicedEmotes" and voicedEmoteTitle or PANEL_MODES[mode].title
        local entries = GetVisibleEntryIDs(category)
        local pageCount = math.ceil(#entries / SECTOR_COUNT)
        for first = 1, #entries, SECTOR_COUNT do
            local number = math.floor((first - 1) / SECTOR_COUNT) + 1
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
    table.insert(categoryPages, professionPage)
end

local function RefreshVisibleFavorites()
    visibleFavorites = {}
    for _, entry in ipairs(favorites) do
        if GetEntryData(entry.mode, entry.index) and not IsEntryHidden(entry.mode, entry.index) then
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
                -- Keep profession favorites across characters and temporary unlearning.
                local valid = GetEntryData(entry.mode, entry.index) or
                    (entry.mode == "professions" and type(entry.index) == "number" and entry.index > 0 and entry.index % 1 == 0)
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

local function GetSectorEntry(sector)
    if not sector or sector < 1 or sector > currentPage.count then return end
    local mode = currentPage.mode
    if currentPage == categoryWheel then return mode, sector, categoryWheel.entries[sector] end
    local index = (currentPage.first or 1) + sector - 1
    if mode == "favorites" then
        local entry = visibleFavorites[index]
        mode, index = entry.mode, entry.index
    else
        index = currentPage.entries[index]
    end
    return mode, index, GetEntryData(mode, index)
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
    if EmotePanelSavedVars.closePanelAfterAction ~= false then EmotePanel.frame:Hide() end
end

local function ExecuteAction(mode, index, data, fromMouse)
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
        C_ChatInfo.PerformEmote(token)
        CloseAfterAction()
    elseif data.actionType == "panel" then
        CloseAfterAction()
        data.open()
    elseif data.actionType == "profession" then
        local canCraft = data.canCraft
        if fromMouse and canCraft then
            local current = C_TradeSkillUI.GetBaseProfessionInfo()
            if not current or current.professionID ~= index then
                -- Let TRADE_SKILL_SHOW open the native UI after the hardware click.
                if C_TradeSkillUI.OpenTradeSkill(index) then
                    CloseAfterAction()
                    return
                end
                canCraft = false
            end
        end
        if not ProfessionsFrame_LoadUI() then return end
        CloseAfterAction()
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
    elseif data.actionType == "command" then
        local command = GetSlashCommand(mode, index, data)
        if not command then
            data.run()
            CloseAfterAction()
            return
        end
        local editBox = GetAvailableChatBox()
        if not editBox then return end
        CloseAfterAction()
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
        CloseAfterAction()
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
    text = "Reset icon and text overrides? Added entries and visibility choices are kept.",
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

        print("|cFF00FF00EmotePanel:|r All custom entries have been reset")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
local function AddAtlas(parent, atlas, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAtlas(atlas)
    return texture
end

local function SkinPanel(frame)
    AddAtlas(frame, PANEL_ATLAS):SetAllPoints()
    AddAtlas(frame, PANEL_BORDER_ATLAS, "BORDER"):SetAllPoints()
end

function EmotePanel:ShowCharacterLauncher()
    if InCombatLockdown() or not CharacterMicroButton then
        print("EmotePanel: Use WoW's Character Info binding or Character button.")
        return
    end

    local button = self.characterLauncher
    if not button then
        -- Keep the protected button separate so the wheel can still update in combat.
        button = CreateFrame("Button", AddonName .. "CharacterLauncher", UIParent,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate,SecureHandlerShowHideTemplate")
        button:Hide()
        button:SetSize(290, 76)
        button:SetPoint("CENTER")
        button:SetFrameStrata("DIALOG")
        button:EnableMouse(true)
        SkinPanel(button)
        button:SetHighlightAtlas(FOCUS_ATLAS)

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetText("Open Character Info\nClick or A / Cross · B / Circle to cancel")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("*type1", "click")
        button:SetAttribute("*clickbutton1", CharacterMicroButton)
        button:SetAttribute("_onshow", [[
            local name = self:GetName()
            self:SetBindingClick(true, "PAD1", name, "LeftButton")
            self:SetBindingClick(true, "PAD2", name, "RightButton")
            self:SetBindingClick(true, "PADFORWARD", name, "RightButton")
        ]])
        button:SetAttribute("_onhide", [[ self:ClearBindings() ]])
        button:SetAttribute("_onstate-combat", [[ if newstate == "combat" then self:Hide() end ]])
        RegisterStateDriver(button, "combat", "[combat] combat; peace")
        button:HookScript("PostClick", function()
            if not InCombatLockdown() then button:Hide() end
        end)
        table.insert(UISpecialFrames, button:GetName())
        self.characterLauncher = button
    end
    self.frame:Hide()
    button:Show()
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
    local picker = CreateFrame("Frame", nil, dialog)
    picker:SetSize(392, 342)
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
    preview:SetPoint("BOTTOMLEFT", 111, 31)
    local selectedLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("LEFT", preview, "RIGHT", 8, 8)
    selectedLabel:SetText("Selected")
    local status = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", preview, "RIGHT", 8, -9)
    local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", 0, 10)

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
        hint:SetText(self.library and "D-pad: Select   LB/RB: Page   A: Choose   B: Back   Y: Wheel Icons"
            or "D-pad: Select   LB/RB: Page   A: Choose   B: Back   Y: Library")
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
    previous:SetPoint("BOTTOMLEFT", 23, 43)
    previous:SetScript("OnClick", function() picker:ChangePage(-1) end)
    local nextPage = CreateTextButton(picker, ">")
    nextPage:SetSize(27, 24)
    nextPage:SetPoint("BOTTOMLEFT", 56, 43)
    nextPage:SetScript("OnClick", function() picker:ChangePage(1) end)
    local default = CreateTextButton(picker, "Default")
    default:SetSize(63, 24)
    default:SetPoint("BOTTOMRIGHT", -23, 43)
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
    dialog:SetSize(320, 278)
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

    local editHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editHint:SetPoint("BOTTOM", 0, 52)
    editHint:SetText("Y / Triangle: Choose Icon    A / Cross: Save")
    dialog.errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.errorText:SetPoint("BOTTOM", 0, 72)
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

function EmotePanel:Select(index)
    if currentPage.count == 0 then return end
    index = (index - 1) % currentPage.count + 1
    if index == self.selected then return end

    if self.selected then
        local previousBorder = self.slots[self.selected].border
        previousBorder:SetAtlas(ICON_BORDER)
        SetSelectionTint(previousBorder)
    end
    self.selected = index
    self.highlight:Show()
    local border = self.slots[index].border
    border:SetAtlas(SELECTED_ICON_BORDER)
    local angle = (index - 1) * SECTOR_ANGLE
    local radius = self.highlightRadius
    self.highlight:SetPoint("CENTER", self.wheel, "CENTER", math.sin(angle) * radius, math.cos(angle) * radius)
    -- Blizzard's highlight atlas points down before rotation.
    self.highlight:SetRotation(math.pi - angle)
    local mode, slot, data = GetSectorEntry(index)
    local color = SELECTION_COLORS[data.actionType]
    SetSelectionTint(self.highlight, color)
    SetSelectionTint(border, color)
    self.selectionName:SetText(GetEntryName(mode, slot, data))
    self.messagePreview:SetText(GetEntryPreview(mode, slot, data):gsub("|", "||"))
    self:RefreshGamepadHint()
end

function EmotePanel:EditButton(mode, index, data, fromSettings)
    if not self.customMessageDialog then
        self.customMessageDialog = CreateCustomMessageDialog()
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
    dialog:SetHeight(data.custom and 306 or editableText and 278 or 165)
    dialog.nameBox:SetShown(editableText)
    dialog.nameBox.label:SetShown(editableText)
    dialog.messageBox:SetShown(editableText)
    dialog.messageBox.label:SetShown(editableText)
    dialog.messageBox.label:SetText(nativeCommand and "Slash override (optional)" or data.actionType == "emote" and "Emote (e.g. /wave)"
        or data.actionType == "command" and "Slash command" or "Message")
    dialog.resetButton:SetShown(not data.custom)
    dialog.iconButton:SetPoint("TOP", 20, editableText and -180 or -60)
    local previousName = GetEntryName(mode, index, data)
    local previousMessage = editableText and (GetCustomMessage(mode, index) or data.action) or ""
    if nativeCommand then previousMessage = GetSlashCommand(mode, index, data) or "" end
    dialog.nameBox:SetText(previousName)
    dialog.messageBox:SetText(previousMessage)
    dialog.defaultIcon = GetIconPath(data.custom and customEntryTypes[mode].icon or data.icon)
    dialog.pendingIcon = GetEntryIcon(mode, index, data)
    SetIconTexture(dialog.icon, dialog.pendingIcon)
    dialog.saveButton:SetScript("OnClick", function()
        if data.custom then
            local name = dialog.nameBox:GetText():match("^%s*(.-)%s*$")
            local action = dialog.messageBox:GetText():match("^%s*(.-)%s*$")
            local moved
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
                moved = voicedEmoteTokens[GetEmoteToken(data)] ~= voicedEmoteTokens[token]
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
            if creating or moved then
                self:RefreshEntryPages()
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
        if self.frame:IsShown() then self:RefreshWheel() end
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
    if not data then return end
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
        ExecuteAction(mode, slot, data, true)
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
        ExecuteAction(mode, slot, data)
    end
end

function EmotePanel:CanUseWheel()
    return not ((self.customMessageDialog and self.customMessageDialog:IsShown())
        or StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON") or StaticPopup_Visible("EMOTEPANEL_RESET_ALL"))
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
    wheel:SetScript("OnEnter", function()
        wheel:SetScript("OnUpdate", UpdateMouseSelection)
        UpdateMouseSelection()
    end)
    wheel:SetScript("OnLeave", StopMouseSelection)
    wheel:SetScript("OnHide", StopMouseSelection)
    wheel:SetScript("OnMouseDown", function(_, mouseButton)
        if (mouseButton == "LeftButton" or mouseButton == "RightButton" or mouseButton == "MiddleButton")
            and self:CanUseWheel() then
            mouseDownButton = mouseButton
            mouseDownSector = SectorUnderCursor(GetCursorPosition())
            mouseDownPage = currentPage
        end
    end)
    local function FinishClick(mouseButton)
        if mouseButton ~= mouseDownButton then return end
        local pressedSector, pressedPage = mouseDownSector, mouseDownPage
        mouseDownButton, mouseDownSector, mouseDownPage = nil, nil, nil
        if not pressedSector or pressedPage ~= currentPage or not self:CanUseWheel() then return end
        local index = SectorUnderCursor(GetCursorPosition())
        if index == pressedSector then
            self:ActivateSector(index, mouseButton, true)
            if GameTooltip:IsOwned(wheel) then GameTooltip:Hide() end
        end
    end
    -- Left-click commands need the button's hardware click context.
    wheel:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then FinishClick(mouseButton) end
    end)
    wheel:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton ~= "LeftButton" then FinishClick(mouseButton) end
    end)
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
        end
        slot:SetShown(used)
    end
    local nextSelection = selection or self.selected or 1
    self.selected = nil
    local hasEntries = currentPage.count > 0
    if hasEntries then
        self:Select(math.min(nextSelection, currentPage.count))
    else
        self.highlight:Hide()
        local emptyText = currentPage.mode == "favorites" and "No favorites" or "No visible entries"
        if currentPage.mode == "professions" then
            emptyText = #learnedProfessions > 0 and "No visible professions" or "No learned professions"
        end
        self.selectionName:SetText(emptyText)
        self.messagePreview:SetText("")
        self:RefreshGamepadHint()
    end
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

    CreateCloseButton(frame)

    local help = CreateTextButton(frame, "?")
    help:SetSize(28, 28)
    help:SetPoint("TOPLEFT", 11, -11)
    help:SetScript("OnClick", OpenSettings)

    local footer = AddAtlas(frame, "gamepad-radial-menu-bottomtext", "BORDER")
    footer:SetSize(410, 102)
    footer:SetPoint("TOP", 0, -439)

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
    frame:HookScript("OnShow", function()
        RefreshProfessions()
        self:ShowStartPage()
    end)
    if InputDeviceIconSetManager then
        InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(self.RefreshGamepadHint, self)
    end
end

local function GamepadGlyph(key, fallback)
    local icons = InputIconTextureSetUtility
    if icons and icons.GetActiveInputIconButtonTextures(key) then
        local atlas = icons.GetNormalActiveInputIconButtonTexture(key)
        if type(atlas) == "string" then
            return CreateAtlasMarkup(atlas, 32, 32)
        end
    end
    return fallback
end

function EmotePanel:RefreshGamepadHint()
    local navigation = GamepadGlyph("PADLSTICKAXIS", "Left stick") .. " / "
        .. GamepadGlyph("PADRSTICKAXIS", "Right stick") .. " "
        .. GamepadGlyph("DIRPADVERTICAL", "Up/Down") .. " Select"
    if self.pageArrows[1]:IsShown() then
        navigation = navigation .. "       " .. GamepadGlyph("DIRPADHORIZONTAL", "Left/Right") .. " / "
            .. GamepadGlyph("PADLSHOULDER", "LB") .. " " .. GamepadGlyph("PADRSHOULDER", "RB") .. " Page"
    end
    self.navigationHint:SetText(navigation)
    local mode, slot, data = GetSectorEntry(self.selected)
    local actions
    if currentPage == categoryWheel then
        actions = GamepadGlyph("PAD1", "A") .. " Open    "
    elseif data then
        local favoriteAction = FindFavorite(mode, slot) and "Unfavorite" or "Favorite"
        local primaryAction = (data.actionType == "profession" or data.actionType == "panel") and "Open" or "Use"
        actions = GamepadGlyph("PAD1", "A") .. " " .. primaryAction .. "    "
            .. GamepadGlyph("PAD3", "X") .. " " .. favoriteAction .. "    "
            .. GamepadGlyph("PAD4", "Y") .. " Edit    "
    elseif currentPage == professionPage or EmotePanelSavedVars.categoryWheel then
        actions = ""
    else
        actions = "Browse pages and press " .. GamepadGlyph("PAD3", "X") .. " to add    "
    end
    self.gamepadHint:SetText(actions .. GamepadGlyph("PAD2", "B") .. (self.backButton:IsShown() and " Back" or " Close"))
end

function EmotePanel:DisplayPage(index, page, selection)
    currentPageIndex = index
    currentPage = page
    local nested = EmotePanelSavedVars.categoryWheel
    local inCategory = nested and page ~= categoryWheel
    local canPage = not nested
    if inCategory then
        local first, last = GetCategoryPageRange(page.category or page.mode)
        canPage = first ~= last
    end
    self.backButton:SetShown(inCategory == true)
    for _, arrow in ipairs(self.pageArrows) do arrow:SetShown(canPage) end
    self.titleText:SetText(currentPage.title)
    if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
    self:RefreshWheel(selection)
end

function EmotePanel:ShowPage(index, selection)
    self:DisplayPage(index, GetPage(index), selection)
end

function EmotePanel:ShowStartPage()
    if EmotePanelSavedVars.categoryWheel then
        self:DisplayPage(nil, categoryWheel, 1)
    else
        self:ShowPage(1, 1)
    end
end

function EmotePanel:BackOrClose()
    if EmotePanelSavedVars.categoryWheel and currentPage ~= categoryWheel then
        local category = currentPage.category or currentPage.mode
        for index, entry in ipairs(categoryWheel.entries) do
            if entry.category == category then
                self:DisplayPage(nil, categoryWheel, index)
                return
            end
        end
    end
    self.frame:Hide()
end

function EmotePanel:RefreshEntryPages()
    BuildCategoryPages()
    RefreshProfessionPage()
    RefreshVisibleFavorites()
    self:ShowStartPage()
end

function EmotePanel:CycleMode(direction)
    if not currentPageIndex then return end
    local first, last = 1, FavoritePageCount() + #categoryPages
    if EmotePanelSavedVars.categoryWheel then
        first, last = GetCategoryPageRange(currentPage.category or currentPage.mode)
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
end

function EmotePanel:SetupGamepad()
    local frame = self.frame
    local pressed = {}
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
        if StaticPopup_Visible("EMOTEPANEL_RESET_BUTTON") or StaticPopup_Visible("EMOTEPANEL_RESET_ALL") then return end
        local dialog = self.customMessageDialog
        if dialog and dialog:IsShown() then
            if dialog.picker and dialog.picker:IsShown() then return pickerActions[key] end
            if not dialog.nameBox:HasFocus() and not dialog.messageBox:HasFocus() then return editorActions[key] end
            return
        end
        if key ~= "PAD4" or self.selected then return actions[key] end
    end
    frame:SetScript("OnGamePadButtonDown", function(_, key)
        local action = GetAction(key)
        if not action or (action ~= CloseForGameMenu and IsModifierKeyDown()) then return true end
        pressed[key] = action
        return false
    end)
    frame:SetScript("OnGamePadButtonUp", function(_, key)
        local action = pressed[key]
        if not action then return true end
        pressed[key] = nil
        if action == GetAction(key) then
            if GameTooltip:IsOwned(self.wheel) then GameTooltip:Hide() end
            action()
        end
        return false
    end)
    frame:SetScript("OnGamePadStick", function(_, stick, x, y)
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
    frame:EnableGamePadButton(true)
    frame:EnableGamePadStick(true)
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

function EmotePanel:Initialize()
    EmotePanelSavedVars = EmotePanelSavedVars or {}
    EmotePanelSavedVars.customIcons = EmotePanelSavedVars.customIcons or {}
    EmotePanelSavedVars.entries = EmotePanelSavedVars.entries or {}
    EmotePanelSavedVars.hiddenEntries = EmotePanelSavedVars.hiddenEntries or {}
    if type(EmotePanelSavedVars.entryOrder) ~= "table" then EmotePanelSavedVars.entryOrder = {} end
    LoadNativeEmotes()
    LoadFavorites()
    RefreshProfessions()
    BuildCategoryPages()
    currentPageIndex = 1
    currentPage = GetPage(1)

    self:CreateMainFrame()
    self:CreateWheel()
    self:CreateControls()
    self:RefreshWheel()
    self:LoadPosition()
    self.frame:HookScript("OnHide", function()
        if self.customMessageDialog then self.customMessageDialog:Hide() end
        StaticPopup_Hide("EMOTEPANEL_RESET_BUTTON")
        StaticPopup_Hide("EMOTEPANEL_RESET_ALL")
    end)

    -- Hide by default
    self.frame:Hide()

    -- Blizzard closes special windows separately from the protected Escape handlers.
    table.insert(UISpecialFrames, self.frame:GetName())
end

local function CreateHelpPanel(mainPanel)
    local helpPanel = CreateFrame("Frame", AddonName .. "HelpPanel", mainPanel)
    helpPanel.name = "Entries"
    helpPanel.parent = AddonName

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    helpTitle:SetPoint("TOPLEFT", 16, -16)
    helpTitle:SetText("Wheel Entry List")

    local description = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", helpTitle, "BOTTOMLEFT", 0, -8)
    description:SetText("Use Up or Down to reorder entries.\nUncheck an entry to hide it from its category and Favorites.")

    local previousButton
    for _, mode in ipairs(modeOrder) do
        local config = customEntryTypes[mode]
        if config then
            local button = CreateTextButton(helpPanel, "Add " .. config.label)
            button:SetSize(92, 25)
            if previousButton then
                button:SetPoint("LEFT", previousButton, "RIGHT", 6, 0)
            else
                button:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -10)
            end
            button:SetScript("OnClick", function() EmotePanel:EditButton(mode, nil, nil, true) end)
            previousButton = button
        end
    end

    -- Create and store scroll frame reference both locally and globally
    local scrollFrame = CreateFrame("ScrollFrame", AddonName .. "ListScrollFrame", helpPanel,
        "MinimalScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -47)
    scrollFrame:SetPoint("BOTTOMRIGHT", helpPanel, "BOTTOMRIGHT", -30, 20)

    helpPanel.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    local headers, rows, resetButtons = {}, {}, {}
    scrollFrame.content = content
    scrollFrame:SetScrollChild(content)

    local listModes = { unpack(categoryOrder) }
    table.insert(listModes, "professions")
    for _, mode in ipairs(listModes) do
        local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetText(mode == "professions" and professionPage.title
            or mode == "voicedEmotes" and voicedEmoteTitle or PANEL_MODES[mode].title)
        headers[mode] = header
        rows[mode] = {}

        local reset = CreateTextButton(content, "Reset Order")
        reset:SetSize(100, 24)
        reset:SetDisabledFontObject(GameFontDisable)
        reset:SetScript("OnClick", function()
            EmotePanelSavedVars.entryOrder[mode] = nil
            EmotePanel:RefreshEntryPages()
            helpPanel:refresh()
        end)
        resetButtons[mode] = reset
    end

    local function CreateEntryRow(category, mode, index)
        local row = CreateFrame("Frame", nil, content)
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("LEFT")
        check:SetScript("OnClick", function(self)
            local hidden = EmotePanelSavedVars.hiddenEntries
            hidden[mode] = hidden[mode] or {}
            hidden[mode][index] = not self:GetChecked() or nil
            EmotePanel:RefreshEntryPages()
        end)
        row.check = check
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(true)
        row.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        local edit = CreateTextButton(row, "Edit")
        edit:SetSize(54, 24)
        edit:SetPoint("RIGHT")
        edit:SetScript("OnClick", function()
            local data = GetEntryData(mode, index)
            if data then EmotePanel:EditButton(mode, index, data, true) end
        end)

        local function Move(neighbor)
            if not neighbor then return end
            -- Retain saved positions for professions learned on another character.
            local order = GetOrderedEntryIDs(category, true)
            local from, to
            for position, id in ipairs(order) do
                if id == index then from = position end
                if id == neighbor then to = position end
            end
            if not (from and to) then return end
            order[from], order[to] = order[to], order[from]
            EmotePanelSavedVars.entryOrder[category] = order
            EmotePanel:RefreshEntryPages()
            helpPanel:refresh()
        end

        row.down = CreateTextButton(row, "Down")
        row.down:SetSize(48, 24)
        row.down:SetDisabledFontObject(GameFontDisable)
        row.down:SetPoint("RIGHT", edit, "LEFT", -4, 0)
        row.down:SetScript("OnClick", function() Move(row.nextID) end)
        row.up = CreateTextButton(row, "Up")
        row.up:SetSize(40, 24)
        row.up:SetDisabledFontObject(GameFontDisable)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -4, 0)
        row.up:SetScript("OnClick", function() Move(row.previousID) end)
        return row
    end

    helpPanel.refresh = function()
        local width = scrollFrame:GetWidth()
        content:SetWidth(width)
        local y = 0
        for _, mode in ipairs(listModes) do
            local storageMode = GetStorageMode(mode)
            headers[mode]:SetPoint("TOPLEFT", 0, -y)
            resetButtons[mode]:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            resetButtons[mode]:SetEnabled(EmotePanelSavedVars.entryOrder[mode] ~= nil)
            y = y + 28
            local modeRows = rows[mode]
            for _, row in pairs(modeRows) do row:Hide() end
            local entries = GetOrderedEntryIDs(mode)
            for position, index in ipairs(entries) do
                local data = GetEntryData(storageMode, index)
                local row = modeRows[index]
                if not row then
                    row = CreateEntryRow(mode, storageMode, index)
                    modeRows[index] = row
                end
                row.previousID, row.nextID = entries[position - 1], entries[position + 1]
                row.up:SetEnabled(row.previousID ~= nil)
                row.down:SetEnabled(row.nextID ~= nil)
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetWidth(width)
                row.label:SetWidth(math.max(1, width - 186))
                local preview = GetEntryPreview(storageMode, index, data):gsub("\n", " · ")
                local name = GetEntryName(storageMode, index, data)
                local label = name .. "  ·  " .. preview
                row.label:SetText(label:gsub("|", "||"))
                row:SetHeight(math.max(28, row.label:GetStringHeight() + 8))
                row.check:SetChecked(not IsEntryHidden(storageMode, index))
                row:Show()
                y = y + row:GetHeight()
            end
            y = y + 12
        end
        content:SetHeight(y)
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

local function CreateCustomizationPanel(mainPanel)
    local customizationPanel = CreateFrame("Frame", AddonName .. "CustomizationPanel", mainPanel)
    customizationPanel.name = "Customization"
    customizationPanel.parent = AddonName

    -- Add customization settings
    local customTitle = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    customTitle:SetPoint("TOPLEFT", 16, -16)
    customTitle:SetText("Wheel Customization")

    -- Add instructions
    local instructions1 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions1:SetPoint("TOPLEFT", customTitle, "BOTTOMLEFT", 0, -8)
    instructions1:SetText("Right-click any sector or press Y/Triangle to edit its icon.")

    local instructions2 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions2:SetPoint("TOPLEFT", instructions1, "BOTTOMLEFT", 0, -8)
    instructions2:SetText("Say, Party, and Command entries also support custom names and text.")

    local instructions3 = customizationPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    instructions3:SetPoint("TOPLEFT", instructions2, "BOTTOMLEFT", 0, -8)
    instructions3:SetText("Built-in commands use WoW actions. Custom slash commands use chat.")

    -- Reset overrides separately from added entries.
    local resetCustomButton = CreateTextButton(customizationPanel, "Reset Overrides")
    resetCustomButton:SetSize(200, 26)
    resetCustomButton:SetPoint("TOPLEFT", instructions3, "BOTTOMLEFT", 0, -10)

    -- Click handlers
    resetCustomButton:SetScript("OnClick", function()
        StaticPopup_Show("EMOTEPANEL_RESET_ALL")
    end)

    return customizationPanel
end

local categoryIDs = {}

local function CreateInterfaceOptions()
    -- Create the main panel (General Settings)
    local mainPanel = CreateFrame("Frame", AddonName .. "OptionsPanel", UIParent)
    mainPanel.name = AddonName

    -- Title at the top
    local title = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("EmotePanel Options")

    -- Description
    local description = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Open with /ep or bind Open or Close Emote Panel in Keybindings.\nAim either stick to select a sector or use the D-pad.")

    local closeCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    closeCheck:SetSize(24, 24)
    closeCheck:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    closeCheck:SetChecked(EmotePanelSavedVars.closePanelAfterAction ~= false)
    closeCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.closePanelAfterAction = not not self:GetChecked()
    end)
    local closeLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    closeLabel:SetPoint("LEFT", closeCheck, "RIGHT", 4, 0)
    closeLabel:SetText("Close panel after action")

    local categoryCheck = CreateFrame("CheckButton", nil, mainPanel, "UICheckButtonTemplate")
    categoryCheck:SetSize(24, 24)
    categoryCheck:SetPoint("TOPLEFT", closeCheck, "BOTTOMLEFT", 0, -8)
    categoryCheck:SetChecked(EmotePanelSavedVars.categoryWheel == true)
    categoryCheck:SetScript("OnClick", function(self)
        EmotePanelSavedVars.categoryWheel = not not self:GetChecked()
        EmotePanel:ShowStartPage()
    end)
    local categoryLabel = mainPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    categoryLabel:SetPoint("LEFT", categoryCheck, "RIGHT", 4, 0)
    categoryLabel:SetText("Open on Category Wheel")

    -- Create panels using our panel creation functions
    local customizationPanel = CreateCustomizationPanel(mainPanel)
    local helpPanel = CreateHelpPanel(mainPanel)

    -- Register all panels with the Settings system
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(category)
    EmotePanel.settingsCategoryID = category:GetID()

    Settings.RegisterCanvasLayoutSubcategory(category, customizationPanel, customizationPanel.name)
    local helpCategory = Settings.RegisterCanvasLayoutSubcategory(category, helpPanel, helpPanel.name)
    categoryIDs.help = helpCategory:GetID()

    return mainPanel
end

-- Global toggle function
function EmotePanel_Toggle()
    local frame = EmotePanel.frame
    if not frame then return end
    local launcher = EmotePanel.characterLauncher
    if launcher and launcher:IsShown() then
        if not InCombatLockdown() then launcher:Hide() end
        return
    end
    frame:SetShown(not frame:IsShown())
end

local function ShowHelp()
    print("|cFF00FF00EmotePanel Commands:|r")
    print("  /ep - Toggle EmotePanel")
    print("  /ep help - Show this help message")
    print("  Either stick or D-pad up/down: select. LB/RB or D-pad left/right: change page.")
    print("  A/Cross: open or use. B/Circle: go back or close. Y/Triangle or right-click: edit an action.")
    print("  X/Square or middle-click: add or remove a favorite.")
    print("  Enable Open on Category Wheel in settings to browse by category. The default opens on Favorites.")
    print("  Game Panels follows Favorites. Panel shortcuts and learned professions can be favorited.")
    print("  /ep config - Open settings panel")
    print("  /ep reset - Reset icon and text overrides")
    print("  /ep list - Show, hide, reorder, edit, or add wheel entries")
end

local function HandleSlashCommand(msg)
    local command = string.match(msg, "^%s*(%S*)")
    command = command:lower()

    if command == "" then
        EmotePanel_Toggle()
    elseif command == "help" then
        ShowHelp()
    elseif command == "list" then
        if categoryIDs.help then
            EmotePanel.frame:Hide()
            Settings.OpenToCategory(categoryIDs.help)
        else
            print("|cFF00FF00EmotePanel:|r Could not open help panel. Try '/ep config' instead.")
        end
    elseif command == "config" then
        OpenSettings()
    elseif command == "scroll" then
        print("EmotePanel: Use LB/RB, D-pad left/right, or the page arrows to browse the wheel.")
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
    if event == "PLAYER_REGEN_ENABLED" then
        EmotePanel:SetupGamepad()
        self:UnregisterEvent(event)
    elseif event == "SKILL_LINES_CHANGED" then
        local helpPanel = _G[AddonName .. "HelpPanel"]
        local listShown = helpPanel and helpPanel:IsVisible()
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
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("SKILL_LINES_CHANGED")
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            EmotePanel:SetupGamepad()
        end

        -- Print login message
        print("|cFF00FF00EmotePanel|r loaded. Type |cFFFFFF00/ep help|r for commands and instructions.")
    end
end

-- Create and setup event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
