local _, ns = ...
local EmotePanel = ns.panel

local Widgets = ns.Widgets
local Entries = ns.Entries
local SettingsUI = ns.SettingsUI
local ActionPicker = ns.ActionPicker

local SIT_INDEX = 30 -- Favorites store the original emote slot number.
local OLD_INVENTORY_INDEX = 14
local INVENTORY_INDEX = 19 -- Saved slot in Commands.
local OLD_REAGENT_BAG_INDEX = 20
local CLEAR_MARK_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local function IsSecureWheelAction(data)
    return data.actionType == "macro" or data.actionType == "spell" or data.actionType == "item"
        or data.actionType == "pet" or data.actionType == "action"
end

local function RequiresOutOfCombat(data)
    return data.secureClick ~= nil or IsSecureWheelAction(data)
end

local function HasExtraAction()
    local active = C_ActionBar.HasExtraActionBar()
    return not issecretvalue(active) and active == true
end

local function GetDefaultEntryIcon(data)
    -- Spell icons such as Call Pet can change after the action was saved.
    if data.actionType == "spell" and not data.automatic then
        local current, _, conditional = C_Spell.GetSpellTexture(data.actionID)
        if not issecretvalue(conditional) and conditional and conditional > 0 then return conditional end
        if not issecretvalue(current) and current and current > 0 then return current end
    end
    return Widgets.GetIconPath(data.icon)
end

local function GetEntryIcon(mode, index, data)
    if data.actionType == "action" and HasExtraAction() then
        local texture = C_ActionBar.GetActionTexture(data.actionID)
        if not issecretvalue(texture) and texture then return texture end
    end
    local overrides = EmotePanelSavedVars.customIcons
    local icon = overrides and overrides[mode] and overrides[mode][index]
    if type(icon) == "number" and icon > 0 or type(icon) == "string" and icon ~= "" then
        return Widgets.GetIconPath(icon)
    end
    return GetDefaultEntryIcon(data)
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

local function HasOtherPlayerTarget()
    local human, selfTarget = UnitIsHumanPlayer("target"), UnitIsUnit("player", "target")
    return not issecretvalue(human) and not issecretvalue(selfTarget) and human and not selfTarget
end

local function OtherPlayerTargetWarning(data)
    if not HasOtherPlayerTarget() then return "Select another player first." end
    if data.interactDistance then
        local inRange = CheckInteractDistance("target", data.interactDistance)
        if not issecretvalue(inRange) and inRange == false then return "Out of range" end
    end
end

local function RunOnTargetPlayer(action)
    if not HasOtherPlayerTarget() then return end
    local name = GetUnitName("target", true)
    if not issecretvalue(name) and name and name ~= "" then
        action(name)
    end
end

local function IsTargetInOwnGroup()
    local party, raid = UnitInParty("target"), UnitInRaid("target")
    local partySecret, raidSecret = issecretvalue(party), issecretvalue(raid)
    if (not partySecret and party) or (not raidSecret and raid) then return true end
    if not partySecret and not raidSecret then return false end
end

local function GetRemovablePlayer()
    if InCombatLockdown() or not HasOtherPlayerTarget() then return end
    local raid, party = UnitInRaid("target"), UnitInParty("target")
    if issecretvalue(raid) or issecretvalue(party) or not (raid or party) then return end
    local _, instanceType = IsInInstance()
    local queued, challenge = HasLFGRestrictions(), C_PartyInfo.ChallengeModeRestrictionsActive()
    if issecretvalue(instanceType) or issecretvalue(queued) or issecretvalue(challenge)
        or instanceType == "arena" or instanceType == "pvp" or queued or challenge then return end
    local leader = UnitIsGroupLeader("player")
    if issecretvalue(leader) then return end
    if not leader then
        if not raid then return end
        local assistant = UnitIsGroupAssistant("player")
        local targetLeader, targetAssistant = UnitIsGroupLeader("target"), UnitIsGroupAssistant("target")
        if issecretvalue(assistant) or issecretvalue(targetLeader) or issecretvalue(targetAssistant)
            or not assistant or targetLeader or targetAssistant then return end
    end
    local name, guid = GetUnitName("target", true), UnitGUID("target")
    if not issecretvalue(name) and not issecretvalue(guid) and name and name ~= "" and guid then return name, guid end
end

local function CanRemoveTarget()
    return GetRemovablePlayer() ~= nil
end

local function ConfirmRemoveTarget()
    local name, guid = GetRemovablePlayer()
    if not name then return end
    Widgets.ShowConfirmation("EMOTEPANEL_REMOVE_FROM_GROUP", name:gsub("|", "||"), function()
        local currentName, currentGUID = GetRemovablePlayer()
        if currentName == name and currentGUID == guid then
            C_PartyInfo.UninviteUnit(name, nil, true)
        else
            Widgets.ShowError("You can no longer remove that player. Select them again to retry.")
        end
    end)
end

local function GetTargetInviteType()
    if not HasOtherPlayerTarget() then return end
    if IsTargetInOwnGroup() ~= false then return end
    local canCooperate = UnitCanCooperate("player", "target")
    if issecretvalue(canCooperate) or not canCooperate then return end
    if not IsInGroup() then
        local grouped = UnitInAnyGroup("target", LE_PARTY_CATEGORY_HOME)
        if not issecretvalue(grouped) and grouped then return "REQUEST_INVITE" end
    end
    local guid = UnitGUID("target")
    if GetDisplayedInviteType and not issecretvalue(guid) then
        local kind = GetDisplayedInviteType(guid)
        if not issecretvalue(kind) then return kind end
    end
    return "INVITE"
end

local function InviteOrRequest()
    local kind = GetTargetInviteType()
    if not kind then return end
    local full = kind == "SUGGEST_INVITE" and C_PartyInfo.IsPartyFull and C_PartyInfo.IsPartyFull()
    if not issecretvalue(full) and full then
        Widgets.ShowError(ERR_GROUP_FULL)
        return
    end
    if kind == "REQUEST_INVITE" then
        if C_PartyInfo.RequestInviteFromUnit then RunOnTargetPlayer(C_PartyInfo.RequestInviteFromUnit) end
    else
        RunOnTargetPlayer(C_PartyInfo.InviteUnit)
    end
end

local function OpenWho()
    if Kiosk.IsEnabled() or C_GameRules.IsGameRuleActive(Enum.GameRule.IngameWhoListDisabled) then return end
    local query = WhoFrame_GetDefaultWhoCommand()
    ShowWhoPanel()
    WhoFrameEditBox:SetText(query)
    C_FriendList.SendWho(query, Enum.SocialWhoOrigin.Chat)
end

local PANEL_MODES = {
    emotes = {
        title = "Emotes",
        list = {
            { name = "Angry",    action = "angry",    actionType = "emote", icon = "Spell_Misc_EmotionAngry" },
            { name = "Applause", action = "bravo",    actionType = "emote", icon = "Spell_Holy_DivineHymn" },
            { name = "Blush",    action = "blush",    actionType = "emote", icon = "INV_Misc_Flower_02" },
            { name = "Bow",      action = "bow",      actionType = "emote", icon = "Ability_Warrior_Vigilance" },
            { name = "Cackle",   action = "cackle",   actionType = "emote", icon = "ui_embercourt-emoji-elated" },
            { name = "Cheer",    action = "cheer",    actionType = "emote", icon = "Ability_Warrior_BattleShout" },
            { name = "Cry",      action = "cry",      actionType = "emote", icon = "Spell_Misc_EmotionSad" },
            { name = "Dance",    action = "dance",    actionType = "emote", icon = "INV_Misc_FireDancer_01" },
            { name = "Facepalm", action = "facepalm", actionType = "emote", icon = "INV_Mask_03" },
            { name = "Flex",     action = "flex",     actionType = "emote", icon = "Ability_Warrior_StrengthOfArms" },
            { name = "Golfclap", action = "golfclap", actionType = "emote", icon = "Spell_Nature_ThunderClap" },
            { name = "Goodbye",  action = "bye",      actionType = "emote", icon = "INV_Garrison_Hearthstone" },
            { name = "Hug",      action = "hug",      actionType = "emote", icon = "Spell_druid_bearhug" },
            { name = "Kiss",     action = "kiss",     actionType = "emote", icon = "Spell_Shadow_SoothingKiss" },
            { name = "Kneel",    action = "kneel",    actionType = "emote", icon = "Ability_Stealth" },
            { name = "Laugh",    action = "laugh",    actionType = "emote", icon = "ui_embercourt-emoji-elated" },
            { name = "No",       action = "no",       actionType = "emote", icon = "Spell_Holy_SealOfSalvation" },
            { name = "Point",    action = "point",    actionType = "emote", icon = "Ability_Hunter_MarkedForDeath" },
            { name = "Roar",     action = "roar",     actionType = "emote", icon = "Ability_Druid_ChallangingRoar" },
            { name = "Rude",     action = "rude",     actionType = "emote", icon = "Ability_Physical_Taunt" },
            { name = "Salute",   action = "salute",    actionType = "emote", icon = "INV_Misc_Head_Human_01" },
            { name = "Sigh",     action = "sigh",      actionType = "emote", icon = "Spell_Nature_Sleep" },
            { name = "Sorry",    action = "apologize", actionType = "emote", icon = "Spell_Misc_EmotionSad" },
            { name = "Stand",    action = "stand",     actionType = "emote", icon = "Ability_Warrior_SecondWind" },
            { name = "Talk",     action = "talk",      actionType = "emote", icon = "Warrior_DisruptingShout" },
            { name = "Thank",    action = "thank",     actionType = "emote", icon = "INV_Misc_Gift_01" },
            { name = "Threaten", action = "threaten",  actionType = "emote", icon = "Ability_Physical_Taunt_purple" },
            { name = "Wave",     action = "wave",      actionType = "emote", icon = "Spell_Holy_LayOnHands" },
            { name = "Yes",      action = "nod",       actionType = "emote", icon = "Ability_Warrior_StrengthOfArms" },
            { name = "Sit",      action = "sit",       actionType = "emote", icon = "INV_FISHINGCHAIR" },
        }
    },
    -- Saved chat overrides and favorites refer to the slots in these two lists. Append new messages.
    chat = {
        title = "Say Chat",
        list = {
            { name = "Hello!",              action = "hey o/",                   actionType = "say", icon = "Achievement_Reputation_01" },
            { name = "Well played",         action = "nice one!",                actionType = "say", icon = "Achievement_General_StayClassy" },
            { name = "Thanks",              action = "ty, appreciate it",        actionType = "say", icon = "INV_Misc_GiftWrap_01" },
            { name = "No problem",          action = "np :)",                    actionType = "say", icon = "Spell_Holy_BlessingOfProtection" },
            { name = "BRB",                 action = "brb, one sec",             actionType = "say", icon = "INV_Misc_PocketWatch_01" },
            { name = "Bye",                 action = "cya!",                     actionType = "say", icon = "INV_Garrison_Hearthstone" },
            { name = "LFG nearby",          action = "anyone wanna group up?",   actionType = "say", icon = "INV_Misc_GroupNeedMore" },
            { name = "Quest",               action = "you on this quest too?",   actionType = "say", icon = "INV_Scroll_03" },
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
            { name = "Good Job",       action = "nice one, team",               actionType = "party", icon = "Spell_Holy_ChampionsGrace" },
            { name = "Ready?",         action = "rdy for next?",                actionType = "party", icon = "INV_Misc_PocketWatch_01" },
            { name = "OOM",            action = "oom, drinking",                actionType = "party", icon = "INV_Potion_76" },
            { name = "Wait",           action = "hold up, wait for everyone",   actionType = "party", icon = "INV_Misc_PocketWatch_02" },
            { name = "Pulling",        action = "pulling now",                  actionType = "party", icon = "Ability_Hunter_SniperShot" },
            { name = "CC",             action = "can someone cc my target?",    actionType = "party", icon = "Spell_Nature_Polymorph" },
            { name = "Help",           action = "need a hand here",             actionType = "party", icon = "Spell_Holy_Heal" },
            { name = "Ready",          action = "ready when you are",           actionType = "party", icon = "Ability_Warrior_Charge" },
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
            { name = "Invite / Request to Join", action = "invite", actionType = "command", icon = "atlas:friendslist-invitebutton-default-normal",
                contextualInvite = true,
                preview = "Invite the targeted player to your group",
                run = InviteOrRequest },
            { name = "Inspect Target",  action = "inspect",    actionType = "command", icon = "INV_Professions_Inscription_ScribesMagnifyingGlass_Gold",
                outOfCombat = true,
                preview = "Open the target's inspection window",
                run = function() InspectUnit("target") end },
            { name = "Trade Target",    action = "trade",      actionType = "command", icon = "INV_Misc_Coin_02",
                interactDistance = 2,
                preview = "Request a trade with your target",
                run = function() InitiateTrade("target") end },
            { name = "Follow Target",   action = "follow",     actionType = "command", icon = "Ability_Tracking",
                interactDistance = 4,
                preview = "Follow your target",
                run = function() FollowUnit("") end },
            { name = "Add Friend",     action = "friend",     actionType = "command", icon = "atlas:friends-icon-addFriend",
                preview = "Add the targeted player to your friends list",
                run = function()
                    if not C_GameRules.IsGameRuleActive(Enum.GameRule.IngameFriendsListDisabled)
                        and C_FriendList.IsLegacyFriendSystemEnabled() then
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
                outOfCombat = true,
                preview = "Open the Who list and search nearby levels in this zone",
                run = OpenWho },
            { name = "Chat Channels",   action = "leave",      actionType = "command", icon = "atlas:chatframe-button-icon-voicechat",
                outOfCombat = true,
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
                raidMarker = 8 },
            { name = "Mark Cross",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " !7", actionType = "command", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7",
                preview = "Mark your target with Cross",
                raidMarker = 7 },
            { name = "Clear Mark",      action = (SLASH_TARGET_MARKER1 or "/tm") .. " 0", actionType = "command", icon = CLEAR_MARK_ICON,
                preview = "Remove the raid marker from your target",
                raidMarker = 0 },
            { name = "Dismount",        action = SLASH_DISMOUNT1 or "/dismount", actionType = "command", icon = "Ability_Mount_RidingHorse",
                preview = "Dismount from your current mount",
                run = function() Dismount() end },
            { name = "Settings",        action = "ep config", actionType = "command", icon = "atlas:gamepad-radial-icon-gamemenu",
                outOfCombat = true,
                preview = "Open EmotePanel settings",
                run = function() SettingsUI.OpenSettings() end },
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
            { name = "Backpack", actionType = "panel", icon = "atlas:gamepad-radial-icon-bags", open = function() ToggleAllBags() end },
            false, -- Retired Reagent Bag slot.
            { name = "Target Marker", actionType = "submenu", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8",
                preview = "Open the Target Marker wheel" },
            { name = "View Talents", action = "inspecttalents", actionType = "command", icon = "Ability_Marksmanship", outOfCombat = true,
                preview = "View the targeted player's talents",
                run = function()
                    local button = UnitPopupInspectTalentsButtonMixin
                    local context = {unit = "target"}
                    local guid = UnitGUID("target")
                    if not issecretvalue(guid) and guid and button and button:IsEnabled(context) then
                        button:OnClick(context)
                    end
                end },
            { name = "Duel", action = "duel", actionType = "command", icon = "Ability_DualWield", outOfCombat = true,
                interactDistance = 3,
                preview = "Challenge the targeted player to a duel",
                run = function() StartDuel("target", true) end },
            [25] = { name = "Remove from Group", action = "uninvite", actionType = "command", icon = "atlas:128-redbutton-minus",
                outOfCombat = true, fixedSector = 8, available = CanRemoveTarget,
                preview = "Remove the targeted player from your party or raid",
                run = ConfirmRemoveTarget },
        }
    }
}

-- Favorites and icon overrides use these slots. Append new shortcuts.
local function HasSummonedPet()
    local exists = UnitExists("pet")
    return not issecretvalue(exists) and exists == true
end

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
        { name = "Companion Pets", icon = "INV_ArfusPet_Classic", open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS) end },
        { name = "Toys", icon = "INV_SideTab_ToyBox_c60", open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_TOYS) end },
        { name = "Calendar", icon = "atlas:gamepad-radial-icon-calendar", open = function() ToggleCalendar() end },
        { name = "Friends", icon = "atlas:gamepad-radial-icon-social", open = function() ToggleFriendsFrame(FRIEND_TAB_FRIENDS) end },
        false, -- Retired Inventory slot. Keep World Map at its saved index.
        { name = "World Map", icon = "inv_misc_map02", open = function() ToggleWorldMap() end },
        { name = "Game Menu", icon = "atlas:gamepad-radial-icon-gamemenu", open = function() GameMenuFrame_Show() end },
        { name = "Reputation", icon = "INV_Misc_TabardPVP_01", open = function() ToggleCharacter("ReputationFrame") end },
        { name = "Currency", icon = "INV_Misc_Coin_01", open = function() CharacterFrame:ToggleTokenFrame() end },
        { name = "PvP", icon = "atlas:Crosshair_PVP_128", open = function() ToggleCharacter("PVPRankFrame") end },
        { name = "Pet Spellbook", icon = "Ability_Hunter_BeastCall",
            available = function() return EmotePanel.supportsPetWheel end,
            unavailableReason = function() if not HasSummonedPet() then return "No pet summoned" end end,
            open = function() PlayerSpellsUtil.ToggleSpellBookFrame(PlayerSpellsUtil.SpellBookCategories.Pet) end },
        { name = "Cooldown Settings", icon = "INV_Misc_PocketWatch_01", open = function() CooldownViewerSettings:TogglePanel() end },
        { name = "Appearances", icon = "INV_Chest_Cloth_17",
            open = function() ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_APPEARANCES) end },
    },
}
local defaultPanelOrder = {
    15, 5, 1, 3, 2, 7, 4, 17, -- World Map through Reputation
    6, 13, 19, 18, 9, 10, 22, 8, -- Guilds & Communities through Account Collections
    12, 20, 11, 21, 16, -- Calendar through Game Menu
}
-- Keep saved command IDs stable, including the old standalone markers.
local LEAVE_GROUP_INDEX = 18
local AUTOMATIC_LEAVE_GROUP = "auto:leave-group"
local defaultCommandOrder = {19, 16, 6, 7, 11, 12, 21, 8, 9, 17, 10}
local interactionOrder = {2, 22, 5, 4, 3, 23, 1, 25, LEAVE_GROUP_INDEX}
local interactionIDs = {}
PANEL_MODES.interactions = { title = "Player Interactions" }
local commands = PANEL_MODES.commands.list
for _, index in ipairs(interactionOrder) do
    interactionIDs[index] = true
    if index ~= LEAVE_GROUP_INDEX then commands[index].unavailableReason = OtherPlayerTargetWarning end
end
local targetMarkers = { [7] = commands[14], [8] = commands[13] }
for marker, name in ipairs({"Star", "Circle", "Diamond", "Triangle", "Moon", "Square"}) do
    targetMarkers[marker] = {
        name = "Mark " .. name, actionType = "command", raidMarker = marker,
        icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. marker,
        preview = "Mark your target with " .. name,
    }
end
for _, entry in ipairs(PANEL_MODES.panels.list) do
    if entry then
        entry.actionType = "panel"
        entry.outOfCombat = true
    end
end

local modeOrder = { "emotes", "chat", "party", "commands", "panels" }
local voicedEmoteTitle = "Voiced Emotes"
local voicedEmoteTokens, nativeEmotes, nativeEmoteIDs = {}, {}, {}
local customEntryTypes = {
    emotes = { actionType = "emote", icon = "INV_Misc_Note_04", addLabel = "Add custom emote",
        nameHint = "e.g. Wave hello", messageHint = "e.g. /wave or /me offers everyone a snack" },
    chat = { actionType = "say", icon = "INV_Letter_01", addLabel = "Add custom message",
        nameHint = "e.g. Say hello", messageHint = "e.g. Hello, everyone!" },
    party = { actionType = "party", icon = "INV_Letter_11", addLabel = "Add custom party message",
        nameHint = "e.g. Ask for a break", messageHint = "e.g. Can we take a quick break?" },
    commands = { actionType = "command", icon = "INV_Misc_Gear_01", addLabel = "Add custom command",
        nameHint = "e.g. Small Roll", messageHint = "e.g. /roll 20" },
}
-- The Actions ring keeps the saved "macros" category key for order, icons and favorites.
local actionsByID, actionIDs = {}, {}
local automaticActions, automaticActionIDs = {}, {}
local carriedActionItems = {}
local petActions = {}
local petEntries = {}
local categoryEntries = {
    { category = "favorites", name = "Favorites", icon = "atlas:transmog-icon-favorite-2x" },
    { category = "emotes", name = "Emotes", icon = "atlas:gamepad-radial-icon-emotes-up-c60", actionType = "emote", defaultHidden = true },
    { category = "professions", name = "Professions", icon = "atlas:gamepad-radial-icon-professions-c60", actionType = "profession", outOfCombat = true },
    { category = "voicedEmotes", name = voicedEmoteTitle, icon = "atlas:ui-eventpoi-horn-big-2x", actionType = "emote", defaultHidden = true },
    { category = "chat", name = "Say Chat", icon = "atlas:gamepad-radial-icon-chat", actionType = "say" },
    { category = "party", name = "Party Chat", icon = "atlas:gamepad-radial-icon-communities", actionType = "party" },
    { category = "commands", name = "Commands", icon = "atlas:gamepad-radial-icon-macros-up-c60", actionType = "command" },
    { category = "panels", name = "Game Panels", icon = "atlas:gamepad-radial-icon-character", actionType = "panel", outOfCombat = true },
    { category = "targetMarkers", name = "Target Marker", icon = "atlas:gamepad-radial-icon-targeting-up-c60", actionType = "submenu" },
    { category = "interactions", name = PANEL_MODES.interactions.title, icon = "atlas:gamepad-radial-icon-group-up-c60" },
}
local categoryByID = {}
for _, entry in ipairs(categoryEntries) do categoryByID[entry.category] = entry end
local characterGUID, petUnavailableReason, favorites
local learnedProfessions = {}
local professionsBySkillLine = {}
local function GetStorageMode(category)
    if category == "interactions" then return "commands" end
    return category == "voicedEmotes" and "emotes" or category
end

local function GetCustomEmoteText(action)
    return action:match("^/[mM][eE]%s+(%S.*)$")
end

local function GetEmoteToken(data)
    if data.token then return data.token end
    if GetCustomEmoteText(data.action) then return end
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
        BEG = "INV_Misc_Coin_01", CHICKEN = "Spell_Magic_PolymorphChicken", EAT = "INV_Misc_Food_57",
        SHY = "Spell_Misc_EmotionAfraid", SLEEP = "INV_MISC_NightelfBedroll",
        HELPME = "Spell_Holy_Resurrection", INCOMING = "Ability_Hunter_MarkedForDeath",
        CHARGE = "Ability_Warrior_Charge", FLEE = "Ability_Rogue_Sprint",
        ATTACKMYTARGET = "Ability_Hunter_Assassinate", OOM = "INV_Potion_76",
        FOLLOW = "Ability_Hunter_Pathfinding", WAIT = "INV_Misc_PocketWatch_02",
        HEALME = "Spell_Holy_Heal", OPENFIRE = "Ability_Hunter_SniperShot",
        HELLO = "Spell_Holy_LayOnHands", WELCOME = "INV_Misc_Gift_01",
        CONGRATULATE = "INV_Misc_CelebrationCake_01", FLIRT = "Spell_Shadow_SoothingKiss",
        JOKE = "INV_Pet_Babymurlocs_Pink", RASP = "INV_Misc_Horn_01", TRAIN = "Ability_Foundryraid_TrainDeath",
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
                    outOfCombat = true,
                }
            end
        end
    end
    return entries
end
local function ReadProfessions()
    learnedProfessions = ReadLearnedProfessions(GetProfessions())
    professionsBySkillLine = {}
    for _, entry in ipairs(learnedProfessions) do
        professionsBySkillLine[entry.skillLine] = entry
    end
end

local function GetEntryData(mode, index)
    if mode == "targetMarkers" then return targetMarkers[index] end
    if mode == "categories" then return categoryByID[index] end
    if mode == "macros" then return automaticActions[index] or actionsByID[index] end
    if mode == "pet" then return petEntries[index] end
    if mode == "professions" then return professionsBySkillLine[index] end
    if mode == "emotes" and type(index) == "string" then return nativeEmotes[index] end
    local config = PANEL_MODES[mode]
    if config and type(index) == "number" and index < 0 then
        local entries = EmotePanelSavedVars.entries[mode]
        return entries and entries[-index] or nil
    end
    return config and config.list[index]
end

local function GetDirectActionKey(kind, id)
    return kind .. ":" .. characterGUID .. ":" .. id
end

local function ReadAutomaticActions()
    if EmotePanelSavedVars.automaticWheelActions == false and #automaticActionIDs == 0 then return false end
    local entries, ids = {}, {}
    local function Add(kind, id, name, icon, preview)
        if issecretvalue(id) or type(id) ~= "number" or id <= 0 then return end
        local key = "auto:" .. kind .. ":" .. id
        if entries[key] then return end
        if issecretvalue(name) or type(name) ~= "string" then name = preview end
        if issecretvalue(icon) or not icon then icon = "INV_Misc_QuestionMark" end
        ids[#ids + 1] = key
        entries[key] = { actionType = kind, actionID = id, name = name, icon = icon, preview = preview, automatic = true }
    end
    if EmotePanelSavedVars.automaticWheelActions ~= false then
        if ExtraActionButton1 and HasExtraAction() then
            local name = BINDING_NAME_EXTRAACTIONBUTTON1 or "Extra Action"
            local bar = C_ActionBar.GetExtraBarIndex()
            if not issecretvalue(bar) and bar > 0 then
                local slot = ExtraActionButton1:GetID() + (bar - 1) * NUM_ACTIONBAR_BUTTONS
                Add("action", slot, name, nil, "Temporary action")
            end
        end
        local count = C_QuestLog.GetNumQuestWatches()
        if not issecretvalue(count) then
            for watch = 1, count do
                local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(watch)
                if not issecretvalue(questID) and questID then
                    local index = C_QuestLog.GetLogIndexForQuestID(questID)
                    if not issecretvalue(index) and index then
                        local link, icon = GetQuestLogSpecialItemInfo(index)
                        if not issecretvalue(link) and type(link) == "string" then
                            Add("item", C_Item.GetItemInfoInstant(link), link:match("%[([^%]]+)%]"), icon, "Tracked quest item")
                        end
                    end
                end
            end
        end
        local abilities = C_ZoneAbility.GetActiveAbilities()
        if not issecretvalue(abilities) then
            for _, ability in ipairs(abilities) do
                if not issecretvalue(ability) then
                    local id = ability.spellID
                    if not issecretvalue(id) and id then
                        Add("spell", id, C_Spell.GetSpellName(id), C_ZoneAbility.GetZoneAbilityIcon(id), "Zone ability")
                    end
                end
            end
        end
        local leaveGroup = PANEL_MODES.commands.list[LEAVE_GROUP_INDEX]
        if leaveGroup.available() then
            local key = AUTOMATIC_LEAVE_GROUP
            ids[#ids + 1] = key
            entries[key] = {
                actionType = "command", action = leaveGroup.action, name = leaveGroup.name,
                icon = leaveGroup.icon, preview = leaveGroup.preview, run = leaveGroup.run,
                available = leaveGroup.available, automatic = true,
            }
        end
    end
    local changed = #ids ~= #automaticActionIDs
    if not changed then
        for index, key in ipairs(ids) do
            local old, new = automaticActions[key], entries[key]
            if key ~= automaticActionIDs[index] or new.name ~= old.name or new.icon ~= old.icon then
                changed = true
                break
            end
        end
    end
    if changed then automaticActions, automaticActionIDs = entries, ids end
    return changed
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

local function ForEachEntry(category, callback)
    if category == "panels" then
        for _, index in ipairs(defaultPanelOrder) do callback(index, PANEL_MODES.panels.list[index]) end
        return
    end
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
    local list = PANEL_MODES[mode].list
    if mode == "commands" then
        for _, index in ipairs(category == "interactions" and interactionOrder or defaultCommandOrder) do Add(index, list[index]) end
        if category == "interactions" then return end
    else
        for index, data in ipairs(list) do
            if data then Add(index, data) end
        end
    end
    if mode == "emotes" then
        for _, id in ipairs(nativeEmoteIDs) do Add(id, nativeEmotes[id]) end
    end
    for index, data in ipairs(EmotePanelSavedVars.entries[mode] or {}) do
        if data then Add(-index, data) end
    end
end

local function IsEntryHidden(mode, index)
    if mode == "macros" then return not EmotePanelSavedVars.selectedMacros[index] end
    local hidden = EmotePanelSavedVars.hiddenEntries[mode]
    if hidden and hidden[index] ~= nil then return hidden[index] end
    return mode == "categories" and categoryByID[index] and categoryByID[index].defaultHidden
end

local function IsEntryAvailable(data)
    return data and (not data.available or data.available()) and (data.actionType ~= "item" or carriedActionItems[data.actionID])
end

local function IsEntryVisible(mode, index)
    return not IsEntryHidden(mode, index) and IsEntryAvailable(GetEntryData(mode, index))
end

local function GetOrderedEntryIDs(category, keepUnavailable)
    local defaultOrder, available = {}, {}
    ForEachEntry(category, function(index, data)
        local isAvailable = category ~= "panels" or IsEntryAvailable(data)
        if isAvailable or keepUnavailable then table.insert(defaultOrder, index) end
        available[index] = isAvailable
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
        local legacyMarker = category == "commands" and (index == 13 or index == 14 or index == 15)
        local belongs = (category ~= "commands" or (not interactionIDs[index] and index ~= OLD_REAGENT_BAG_INDEX))
            and (category ~= "interactions" or interactionIDs[index])
        if belongs and (type(index) == "number" or type(index) == "string") and (available[index] or keepUnavailable or legacyMarker) then
            Add(index)
        end
    end
    for _, index in ipairs(defaultOrder) do Add(index) end
    return entries
end

local function GetVisibleEntryIDs(category)
    local mode = GetStorageMode(category)
    local entries = {}
    local fixed
    for _, index in ipairs(GetOrderedEntryIDs(category)) do
        local data = GetEntryData(mode, index)
        if category == "interactions" and data.fixedSector then
            if not IsEntryHidden(mode, index) then fixed = index end
        elseif IsEntryVisible(mode, index) then
            table.insert(entries, index)
            if mode == "categories" and #entries == ns.SECTOR_COUNT then break end
        end
    end
    if fixed then
        local sector = GetEntryData(mode, fixed).fixedSector
        for position = #entries + 1, sector - 1 do entries[position] = false end
        table.insert(entries, sector, fixed)
    end
    return entries
end

local function CanShowCategory(index)
    return not IsEntryHidden("categories", index) or #GetVisibleEntryIDs("categories") < ns.SECTOR_COUNT
end

local function SaveEntryVisibility(mode, index, shown)
    if mode == "categories" and shown and not CanShowCategory(index) then return false end
    if mode == "macros" then
        EmotePanelSavedVars.selectedMacros[index] = shown and true or nil
    else
        local hidden = EmotePanelSavedVars.hiddenEntries
        hidden[mode] = hidden[mode] or {}
        local defaultHidden = mode == "categories" and categoryByID[index] and categoryByID[index].defaultHidden
        hidden[mode][index] = not shown
        if hidden[mode][index] == not not defaultHidden then hidden[mode][index] = nil end
    end
    return true
end

local function GetWheelActionIDs()
    local entries = {}
    for _, key in ipairs(automaticActionIDs) do
        local data = automaticActions[key]
        local manualKey = data.actionID and characterGUID and GetDirectActionKey(data.actionType, data.actionID)
        if key ~= AUTOMATIC_LEAVE_GROUP and (not manualKey or not IsEntryVisible("macros", manualKey)) then
            entries[#entries + 1] = key
        end
    end
    for _, key in ipairs(GetVisibleEntryIDs("macros")) do entries[#entries + 1] = key end
    return entries, automaticActions[AUTOMATIC_LEAVE_GROUP] and AUTOMATIC_LEAVE_GROUP
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

local function GetSlashCommand(mode, index, data)
    if data.fixedSector then return end
    local override = not data.automatic and GetCustomMessage(mode, index)
    if (data.run or data.raidMarker) and (not override or override:gsub("^/+", ""):lower() == data.action:gsub("^/+", ""):lower()) then
        return
    end
    return "/" .. (override or data.action):gsub("^/+", "")
end

local function GetRaidMarker(mode, index, data)
    if mode == "targetMarkers" then return data.raidMarker end
    if data.raidMarker and not GetSlashCommand(mode, index, data) then return data.raidMarker end
end

local function IsOutOfCombat(mode, index, data)
    -- A custom slash override can replace the built-in panel action.
    return data.outOfCombat and (data.actionType ~= "command" or not GetSlashCommand(mode, index, data))
end

local function GetUnavailableReason(mode, index, data)
    if data.unavailableReason and (data.actionType ~= "command" or not GetSlashCommand(mode, index, data)) then
        if data.contextualInvite and HasOtherPlayerTarget() and not GetTargetInviteType() then
            return "Group invitations are unavailable for this player."
        end
        return data.unavailableReason(data)
    end
end

local function IsInviteHidden(mode, index, data)
    return data.contextualInvite and IsTargetInOwnGroup() == true and not GetSlashCommand(mode, index, data)
end

local function GetInviteLabel(mode, index, data)
    if data.run ~= InviteOrRequest or GetSlashCommand(mode, index, data) then return end
    local kind = GetTargetInviteType()
    if kind == "REQUEST_INVITE" then return REQUEST_INVITE or "Request to Join" end
    if kind == "SUGGEST_INVITE" then return SUGGEST_INVITE or "Suggest Invite" end
    if kind == "INVITE" then return PARTY_INVITE or "Invite" end
end

local function GetEntryPreview(mode, index, data)
    if mode == "categories" then return "Open " .. data.name end
    if mode == "targetMarkers" or data.actionType == "submenu" then return data.preview end
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
    if data.actionType == "emote" then
        return GetCustomEmoteText(data.action) or ns.emoteText[GetEmoteToken(data)] or ""
    end
    if data.actionType == "panel" then return "Open " .. data.name end
    if data.actionType == "profession" then
        local kind = data.isPrimary and "Primary profession" or "Secondary profession"
        local action = data.canCraft and "Open crafting" or "Open professions overview"
        return ("%s · %d / %d\n%s"):format(kind, data.rank, data.maxRank, action)
    end
    if data.actionType == "command" then
        if data.run == InviteOrRequest and not GetSlashCommand(mode, index, data) then
            local kind = GetTargetInviteType()
            if kind == "REQUEST_INVITE" then return "Ask to join the targeted player's group" end
            if kind == "SUGGEST_INVITE" then return "Suggest inviting the targeted player to your group" end
        end
        return GetSlashCommand(mode, index, data) or data.preview
    end
    return GetCustomMessage(mode, index) or data.action
end

local function HasEditableText(data)
    return not data.fixedSector and (data.custom or data.actionType == "say" or data.actionType == "party" or data.actionType == "command")
end

local requestedSpellText = {}
local function GetEntryName(mode, index, data)
    if data.actionType == "spell" and not data.automatic then
        local subtext = data.spellSubName
        if not subtext then
            local id = data.actionID
            subtext = C_Spell.GetSpellSubtext(id)
            if not issecretvalue(subtext) and subtext == "" and not requestedSpellText[id] then
                requestedSpellText[id] = true
                C_Spell.RequestLoadSpellData(id)
            end
        end
        if not issecretvalue(subtext) and subtext and subtext ~= "" then
            local suffix = " (" .. subtext .. ")"
            if data.name:sub(-#suffix) ~= suffix then return data.name .. suffix end
        end
    end
    return ((mode == "categories" or HasEditableText(data)) and GetCustomButtonName(mode, index)) or data.name
end

function EmotePanel:SetActionSelected(key, data, selected, keepPage)
    local saved = EmotePanelSavedVars
    if selected and not actionsByID[key] then
        saved.directActions[characterGUID] = saved.directActions[characterGUID] or {}
        table.insert(saved.directActions[characterGUID], data)
        actionsByID[key] = data
        table.insert(actionIDs, key)
    end
    SaveEntryVisibility("macros", key, selected)
    if keepPage then
        self:RefreshCurrentEntryPages()
    else
        self:RefreshEntryPages()
    end
    SettingsUI.RefreshEntryList()
    if data and (data.actionType == "item" or data.actionType == "spell") then ActionPicker.Refresh(data.actionType) end
end

local function GetDirectAction(kind, id, name, icon)
    if not characterGUID or issecretvalue(id) or not id or issecretvalue(name) or not name or issecretvalue(icon) then return end
    return GetDirectActionKey(kind, id), {
        actionType = kind, actionID = id, name = name, icon = icon or "INV_Misc_QuestionMark",
        preview = kind == "spell" and "Spell" or "Item",
    }
end

local function GetItemAction(info, includeSelected)
    if not characterGUID or issecretvalue(info) or not info then return end
    local id = info.itemID
    if issecretvalue(id) or not id then return end
    if includeSelected then
        local key = GetDirectActionKey("item", id)
        if not IsEntryHidden("macros", key) then return key, actionsByID[key] end
    end
    local usable = C_Item.IsUsableItem(id)
    if not issecretvalue(usable) and usable then
        return GetDirectAction("item", id, C_Item.GetItemNameByID(id), info.iconFileID)
    end
end

local function VisitSpellbookActions(visit, requestedID, checkRanks)
    local function VisitSpell(id, name, icon, baseID, subName, lowRank)
        if issecretvalue(id) or not id then return end
        if requestedID and requestedID ~= id and (issecretvalue(baseID) or requestedID ~= baseID) then return end
        local key, data = GetDirectAction("spell", id, name, icon)
        if key then
            if not issecretvalue(subName) and subName and subName ~= "" then data.spellSubName = subName end
            return visit(key, data, lowRank)
        end
    end
    local bank, itemTypes = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType
    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line and not line.shouldHide and (not line.offSpecID or line.offSpecID == 0) then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if info and info.itemType == itemTypes.Spell and not info.isPassive and not info.isOffSpec then
                    local lowRank = checkRanks and C_SpellBook.IsSpellBookItemLowRank(slot, bank)
                    if VisitSpell(info.spellID, info.name, info.iconID, info.actionID, info.subName, lowRank) then return end
                elseif info and info.itemType == itemTypes.Flyout then
                    local _, _, count = GetFlyoutInfo(info.actionID)
                    for flyoutSlot = 1, count or 0 do
                        local id, overrideID, known = GetFlyoutSlotInfo(info.actionID, flyoutSlot)
                        local spellID = overrideID and overrideID > 0 and overrideID or id
                        if known and spellID and not C_Spell.IsSpellPassive(spellID) then
                            local spell = C_Spell.GetSpellInfo(spellID)
                            if spell then
                                local memberSlot = checkRanks and C_SpellBook.FindSpellBookSlotForSpell(spellID, true, false)
                                local lowRank = memberSlot and C_SpellBook.IsSpellBookItemLowRank(memberSlot, bank)
                                if VisitSpell(spellID, spell.name, spell.iconID, id, nil, lowRank) then return end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function GetSpellAction(spellID)
    if not characterGUID or issecretvalue(spellID) or type(spellID) ~= "number" then return end
    local key, data
    VisitSpellbookActions(function(foundKey, foundData)
        key, data = foundKey, foundData
        return true
    end, spellID)
    return key, data
end

local function GetActionChoices(kind)
    local choices, seen = {}, {}
    local highestOnly = kind == "spell" and EmotePanelSavedVars.highestSpellRankOnly ~= false
    local function Add(key, data)
        if not key or seen[key] then return end
        seen[key] = true
        choices[#choices + 1] = { key = key, data = data, name = GetEntryName("macros", key, data) }
    end
    if characterGUID and kind == "spell" then
        if highestOnly then
            local lowRanks = {}
            VisitSpellbookActions(function(key, data, lowRank)
                if lowRank then lowRanks[key] = true end
                Add(key, data)
            end, nil, true)
            for index = #choices, 1, -1 do
                if lowRanks[choices[index].key] then table.remove(choices, index) end
            end
        else
            VisitSpellbookActions(Add)
        end
    elseif characterGUID and kind == "item" then
        for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                Add(GetItemAction(C_Container.GetContainerItemInfo(bag, slot)))
            end
        end
    end

    -- Keep unavailable items visible only while selected, so players can uncheck them.
    for _, key in ipairs(actionIDs) do
        local data = actionsByID[key]
        if not highestOnly and data and data.actionType == kind
            and (kind ~= "item" or carriedActionItems[data.actionID] or not IsEntryHidden("macros", key)) then
            Add(key, data)
        end
    end
    table.sort(choices, function(a, b)
        if a.name == b.name then return a.key < b.key end
        return a.name < b.name
    end)
    return choices
end

local function HasCharacter()
    return characterGUID ~= nil
end

local function GetFavorites()
    -- The saved array is also the session's source of truth. Callers read it
    -- here and use ToggleFavorite or MoveFavorite to change it.
    return favorites
end

local function ToggleFavorite(mode, index)
    local position = FindFavorite(mode, index)
    if position then
        table.remove(favorites, position)
    else
        table.insert(favorites, { mode = mode, index = index })
    end
end

local function MoveFavorite(entry, neighbor)
    return SwapOrder(favorites, entry, neighbor)
end

local function DeleteCustomEntry(mode, index, data)
    if InCombatLockdown() or not customEntryTypes[mode] or type(index) ~= "number"
        or index >= 0 or not data or not data.custom or GetEntryData(mode, index) ~= data then return end

    local saved = EmotePanelSavedVars
    -- Retain the slot so other saved entry IDs keep pointing at the same entries.
    saved.entries[mode][-index] = false
    local favorite = FindFavorite(mode, index)
    if favorite then table.remove(favorites, favorite) end
    for _, field in ipairs({"customIcons", "customMessages", "customButtonNames", "hiddenEntries"}) do
        local overrides = saved[field] and saved[field][mode]
        if overrides then overrides[index] = nil end
    end
    for _, category in ipairs(mode == "emotes" and {"emotes", "voicedEmotes"} or {mode}) do
        local order = saved.entryOrder[category]
        for position = #(order or {}), 1, -1 do
            if order[position] == index then table.remove(order, position) end
        end
    end
    local last = EmotePanel.lastAction
    if last and last.mode == mode and last.key == index then EmotePanel.lastAction = nil end
    EmotePanel:RefreshEntryPages()
    SettingsUI.RefreshEntryList()
    return true
end

local function GetPetAction(slot)
    return petActions[slot]
end

local function GetPetAvailability()
    return next(petActions) ~= nil, petUnavailableReason
end

local function HasLearnedProfessions()
    return #learnedProfessions > 0
end

local function IsActionItemCarried(id)
    return carriedActionItems[id]
end

local function MigrateInventory(saved)
    for _, overrides in ipairs({ saved.customIcons, saved.hiddenEntries }) do
        local panels = overrides.panels
        if type(panels) == "table" and panels[OLD_INVENTORY_INDEX] ~= nil then
            overrides.commands = overrides.commands or {}
            if overrides.commands[INVENTORY_INDEX] == nil then
                overrides.commands[INVENTORY_INDEX] = panels[OLD_INVENTORY_INDEX]
            end
            panels[OLD_INVENTORY_INDEX] = nil
        end
        local commands = overrides.commands
        if type(commands) == "table" and commands[OLD_REAGENT_BAG_INDEX] ~= nil then
            if commands[INVENTORY_INDEX] == nil then commands[INVENTORY_INDEX] = commands[OLD_REAGENT_BAG_INDEX] end
            commands[OLD_REAGENT_BAG_INDEX] = nil
        end
    end
    if type(saved.favorites) == "table" then
        for _, entry in ipairs(saved.favorites) do
            if type(entry) == "table" and entry.mode == "panels" and entry.index == OLD_INVENTORY_INDEX then
                entry.mode, entry.index = "commands", INVENTORY_INDEX
            elseif type(entry) == "table" and entry.mode == "commands" and entry.index == OLD_REAGENT_BAG_INDEX then
                entry.index = INVENTORY_INDEX
            end
        end
    end
    local order = saved.entryOrder.panels
    if type(order) == "table" then
        for position = #order, 1, -1 do
            if order[position] == OLD_INVENTORY_INDEX then table.remove(order, position) end
        end
    end
    order = saved.entryOrder.commands
    if type(order) == "table" then
        local hasInventory
        for _, index in ipairs(order) do
            if index == INVENTORY_INDEX then hasInventory = true end
        end
        for position = #order, 1, -1 do
            if order[position] == OLD_REAGENT_BAG_INDEX then
                if hasInventory then table.remove(order, position) else order[position] = INVENTORY_INDEX end
                hasInventory = true
            end
        end
    end
end

local function InitializeSavedEntries()
    EmotePanelSavedVars = EmotePanelSavedVars or {followCursorCenter = true}
    EmotePanelSavedVars.customIcons = EmotePanelSavedVars.customIcons or {}
    EmotePanelSavedVars.entries = EmotePanelSavedVars.entries or {}
    EmotePanelSavedVars.hiddenEntries = EmotePanelSavedVars.hiddenEntries or {}
    if type(EmotePanelSavedVars.selectedMacros) ~= "table" then EmotePanelSavedVars.selectedMacros = {} end
    if type(EmotePanelSavedVars.directActions) ~= "table" then EmotePanelSavedVars.directActions = {} end
    if type(EmotePanelSavedVars.entryOrder) ~= "table" then EmotePanelSavedVars.entryOrder = {} end
    local orders = EmotePanelSavedVars.entryOrder
    local order = orders.interactions
    if type(order) == "table" then
        local hasInvite
        for _, index in ipairs(order) do
            if index == 1 then hasInvite = true end
        end
        for position = #order, 1, -1 do
            if order[position] == 24 then
                if hasInvite then table.remove(order, position) else order[position] = 1 end
                hasInvite = true
            end
        end
    end
    local savedFavorites = EmotePanelSavedVars.favorites
    if type(savedFavorites) == "table" then
        for _, entry in ipairs(savedFavorites) do
            if type(entry) == "table" and entry.mode == "commands" and entry.index == 24 then entry.index = 1 end
        end
    end
    for _, field in ipairs({"customIcons", "customButtonNames", "customMessages", "hiddenEntries"}) do
        local commands = EmotePanelSavedVars[field] and EmotePanelSavedVars[field].commands
        if type(commands) == "table" and commands[24] ~= nil then
            if commands[1] == nil then commands[1] = commands[24] end
            commands[24] = nil
        end
    end
    if type(orders.commands) == "table" then
        local moved, hasMoved = {}, false
        for _, index in ipairs(orders.commands) do
            if interactionIDs[index] then
                hasMoved = true
                if index ~= LEAVE_GROUP_INDEX then moved[#moved + 1] = index end
            end
        end
        if hasMoved then
            if #moved > 0 and not orders.interactions then orders.interactions = moved end
            for position = #orders.commands, 1, -1 do
                if interactionIDs[orders.commands[position]] then table.remove(orders.commands, position) end
            end
        end
    end
    local visibleCategories = 0
    for _, id in ipairs(GetOrderedEntryIDs("categories")) do
        if not IsEntryHidden("categories", id) then
            visibleCategories = visibleCategories + 1
            if visibleCategories > ns.SECTOR_COUNT then SaveEntryVisibility("categories", id, false) end
        end
    end
    MigrateInventory(EmotePanelSavedVars)
    LoadNativeEmotes()
end

local function HandleMacrosChanged()
    ReadActions()
    EmotePanel:RefreshEntryPages()
    SettingsUI.RefreshEntryList()
    ActionPicker.Refresh("macro")
end

Entries.FindFavorite = FindFavorite
Entries.CLEAR_MARK_ICON = CLEAR_MARK_ICON
Entries.GetActionChoices = GetActionChoices
Entries.GetItemAction = GetItemAction
Entries.GetSpellAction = GetSpellAction
Entries.GetCustomMessage = GetCustomMessage
Entries.GetEmoteToken = GetEmoteToken
Entries.GetCustomEmoteText = GetCustomEmoteText
Entries.GetEntryData = GetEntryData
Entries.DeleteCustomEntry = DeleteCustomEntry
Entries.GetEntryIcon = GetEntryIcon
Entries.GetDefaultEntryIcon = GetDefaultEntryIcon
Entries.GetEntryName = GetEntryName
Entries.GetInviteLabel = GetInviteLabel
Entries.IsInviteHidden = IsInviteHidden
Entries.GetEntryPreview = GetEntryPreview
Entries.GetOrderedEntryIDs = GetOrderedEntryIDs
Entries.GetSlashCommand = GetSlashCommand
Entries.GetRaidMarker = GetRaidMarker
Entries.IsPlayerInteraction = function(mode, index) return mode == "commands" and interactionIDs[index] end
Entries.GetStorageMode = GetStorageMode
Entries.GetUnavailableReason = GetUnavailableReason
Entries.GetVisibleEntryIDs = GetVisibleEntryIDs
Entries.HasEditableText = HasEditableText
Entries.IsEntryAvailable = IsEntryAvailable
Entries.HasSummonedPet = HasSummonedPet
Entries.IsEntryHidden = IsEntryHidden
Entries.IsEntryVisible = IsEntryVisible
Entries.IsOutOfCombat = IsOutOfCombat
Entries.LoadFavorites = LoadFavorites
Entries.MoveOrderedEntry = MoveOrderedEntry
Entries.PANEL_MODES = PANEL_MODES
Entries.ReadActions = ReadActions
Entries.ReadPetActions = ReadPetActions
Entries.ReadProfessions = ReadProfessions
Entries.RefreshCarriedActionItems = RefreshCarriedActionItems
Entries.ReadAutomaticActions = ReadAutomaticActions
Entries.GetWheelActionIDs = GetWheelActionIDs
Entries.HasExtraAction = HasExtraAction
Entries.SaveCustomButtonName = SaveCustomButtonName
Entries.SaveCustomMessage = SaveCustomMessage
Entries.SaveEntryIcon = SaveEntryIcon
Entries.SaveEntryVisibility = SaveEntryVisibility
Entries.CanShowCategory = CanShowCategory
Entries.categoryLimitMessage = "Hide a category first. The Category Wheel holds up to eight."
Entries.SwapOrder = SwapOrder
Entries.categoryByID = categoryByID
Entries.categoryEntries = categoryEntries
Entries.customEntryTypes = customEntryTypes
Entries.modeOrder = modeOrder
Entries.voicedEmoteTitle = voicedEmoteTitle
Entries.voicedEmoteTokens = voicedEmoteTokens
Entries.IsSecureWheelAction = IsSecureWheelAction
Entries.RequiresOutOfCombat = RequiresOutOfCombat
Entries.HasCharacter = HasCharacter
Entries.GetFavorites = GetFavorites
Entries.ToggleFavorite = ToggleFavorite
Entries.MoveFavorite = MoveFavorite
Entries.GetPetAction = GetPetAction
Entries.GetPetAvailability = GetPetAvailability
Entries.HasLearnedProfessions = HasLearnedProfessions
Entries.IsActionItemCarried = IsActionItemCarried
Entries.InitializeSavedEntries = InitializeSavedEntries
Entries.HandleMacrosChanged = HandleMacrosChanged
