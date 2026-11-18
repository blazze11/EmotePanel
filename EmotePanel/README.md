# EmotePanel 0.25.0 (development)

For WoW: Forever 1.60.1 (interface 16001). Type `/ep setup` outside combat and
press a key or controller button to assign your primary **Wheel Keybind**.
Choose **Wheel Keybinds** in **Help → Start Here** to open **Controller Setup**
in General. It also has a secondary key and, on a Hunter or Warlock,
**Pet Keybinds**. Use the assigned keybind to open either
wheel. Existing legacy assignments move to the secure binding
the next time the addon loads outside combat.

The main wheel and Pet Wheel briefly fade in and out. Closing releases wheel
input immediately while the artwork fades.
Selection changes immediately. Paging briefly fades in the new icons and
title while the new page is already active. Both wheels use WoW's radial
menu sounds when opening, closing, changing selection, or paging. **Wheel sounds**
on the **Customization** tab in `/ep config` is on by default and takes effect immediately.
D-pad steps use the paging sound. The cues follow WoW's Sound Effects volume.
Customize Entry and the icon picker use the same cues for opening, closing,
and navigation. The Wheel sounds setting covers them too.
**Wheel vibration** on the same tab is off by default. Enable it for a short
pulse when the stick or D-pad selects a new segment on the main or Pet Wheel.

Outside combat, hold D-pad up or down on either wheel to step through
segments. Hold D-pad left or right or a shoulder button to turn pages.
Use the **Segments** and **Paging** sections on the **Wheel Behavior** tab in
`/ep config` to control repeat independently. Each has its own **initial delay** (100 to
1,000 ms, default 300 ms) and **repeat interval** (50 to 500 ms, default
130 ms). All four sliders adjust in 10 ms steps. If you already customized
the shared timing, both pairs start with your saved values. **Reset repeat**
turns both repeat toggles back on and restores all four timings. In combat,
press once per navigation step.

Enable **Stop at ends** next to either toggle to keep controller steps at
the first and last segment or page, in and out of combat. Both options
default to off. The Pet Wheel already stops at its first and last pages.
From Categories, Left or LB still opens Actions, and Back returns to
Categories. **Reset Wheel Behavior** restores the stop options along with the
other wheel behavior defaults.

Left-click the minimap button or the **EmotePanel** entry in the **Addon
Compartment** to open or close settings.
Drag the minimap button to move it around the map. The Settings title bar
shows the addon version and active profile. The minimap tooltip also shows
the version.

**Automatic quest items and abilities** is on by default. It adds tracked quest
items, temporary zone abilities, and the Extra Action Button to the front of
**Actions**. Uncheck it on the **Actions** tab in `/ep config` to turn it off. From Categories, press
Left or LB to open Actions, or scroll up. Automatic entries follow current
availability and skip items or spells already selected in Actions. The
keybound combat wheel uses the list prepared before combat and picks up
additions and removals after combat.

- Use **either stick** to highlight a sector. D-pad up/down steps around
  the wheel. Use LB/RB or D-pad left/right to change pages. Gold arrows
  beside the title show the available controller paging directions.
- Scroll up over the wheel for the next page or down for the previous
  page. Scrolling stops at the first and last pages of a category. In the
  Favorites-first layout, scrolling browses the full list and stops at either end.
- **A/Cross** opens a category or uses the highlighted action. **B/Circle**
  or right-clicking the center goes back from a category or closes the wheel.
- **Start/Menu** and controller buttons bound to **Game Menu** dismiss
  the wheel. **Esc** uses WoW's normal window closing order. Opening the Game Menu
  closes either wheel and blocks it from reopening while the menu is visible.
- **Y/Triangle** or right-click opens the editor for an action. Choose an
  icon from the wheel set or WoW's spell and item icon library, then save.
- **X/Square** or middle-click adds or removes the highlighted entry from
  Favorites. Favorites can mix emotes, chat messages, commands, game
  panels, and learned professions.
- The selected message or command appears directly below the entry name.
  Emotes and Voiced Emotes preview WoW Forever’s English chat text for
  an emote used without a target. Emotes without a chat line show their name.
  Custom emotes preview the text you entered.
  Press and release the left mouse button on the same sector to use it.
  Drag the centered page title to move the panel. The default position is screen center.

The wheel and selection highlight use Forever's stock eight-sector gamepad
atlases. Categories with more than eight entries continue on another page.
Game Panels use the corresponding Blizzard gamepad or Collections tab
art. Commands and messages use matching Blizzard interface icons where
available. Individual emotes keep distinct WoW icons because Blizzard's
emote wheel uses one shared icon. The selected entry's name appears between
the wheel and footer. Emotes, Say Chat, and Party Chat follow WoW’s chat
colors. Favorites are gold, Voiced Emotes are rose, Commands are purple,
Game Panels are teal, Target Markers are red, Player Interactions are
olive green, and Professions are amber. Actions use blue for spells, bright green for
items, magenta for macros, and yellow-green for the extra action button.
Custom icons follow their entry
into Favorites and persist after reload.

In combat, use the **Open or Close Emote Panel** keybind to open the wheel.
Spells, items, saved macros, and pet actions use A/Cross or left-click
directly. Highlight a sector with a stick as you press A/Cross. You can release
the stick before releasing A/Cross. If you let go of the stick first, the
highlight returns to your last confirmed selection or clears. D-pad up/down
selects a sector that stays highlighted. The **Game Panels** and **Professions**
categories dim and stay closed in combat. Their entries also dim in Favorites
and in the flat layout. **Backpack** toggles all bags from
**Commands**, including in combat. Emotes and other ordinary shortcuts leave
the combat wheel open. A rejected emote shows a message.

**Commands** starts with **Backpack**. Open **Target Marker**
from Categories or Commands. Highlight one of the eight marks and press
**A/Cross** or left-click to mark your target. Press **Y/Triangle** to put
the highlighted mark on your own character.
Press **X/Square** or click the **Clear Mark** icon in the center to clear
your target's mark. With no target selected, this clears your own mark.
Press B/Circle or right-click the center to return to the entry
that opened the sub-wheel. Use the wheel keybind for markers in combat.
Target Marker is on the Category Wheel by default. To enable a hidden
category when all eight slots are filled, uncheck another category first.
If you have a custom Commands order, **Reset Order** in
**Entries → Commands** restores the new default.

Enable **Ping System** in Categories or page to it in the Favorites-first
layout. Highlight Attack, Warning, On My Way, Assist, Look, or Threat.
Press **A/Cross** or left-click to ping your current target. Press **Y/Triangle**
or middle-click to ping yourself. **B/Circle** or right-clicking the center
closes the wheel.
Use the assigned wheel keybind in combat.

For controller use, check **Enable WoW controller input** under
**Controller Setup** in `/ep config`. This changes WoW's game-wide
`GamePadEnable` setting. Turn off **Enable Gamepad UI** under
**Options → Gameplay → Gamepad** because EmotePanel does not support
**Gamepad (Beta)**. ConsolePort is optional.
If the main wheel has no keybind after login, reload, a profile switch, or a
profile reset, EmotePanel prints a red chat message pointing to `/ep setup`.
At login or UI reload, the on-screen controller warnings cover Gamepad (Beta)
and controller bindings with `GamePadEnable` off. The **Controller Setup** reminder updates
when either controller setting changes.
Blocked actions and command errors use WoW's red on-screen error text.
When a matching WoW error has a sound or voice cue, the native error
display plays it.
The wheel handles its own controller navigation. Its controls are excluded
from ConsolePort's interface cursor. Opening the wheel suspends an active
ConsolePort cursor, including one you opened manually.

**Lock movement stick** is on by default in `/ep config`. It blocks
movement while either wheel is open and until you center the stick after
closing it. With the lock off, the stick can move your character while
you use the wheel. That movement can interrupt casts or channels.

Combat uses the wheel layout and saved macro text loaded before the fight.
Changes take effect after combat. If an item runs out mid-fight, its icon
disappears and the surrounding sectors keep their positions until combat ends.
WoW still applies the usual combat rules to each action.

To diagnose a wheel input problem, enter **`/ep debug on`** and reproduce it
using the wheel keybind. In chat, **EmotePanel debug** groups lines under
labels such as **Input**, **Wheel**, **Secure click**, and **Emote**. The **Input** lines include regular wheel category presses and controller activation.
A secure click entry includes the action type, page, sector, and whether
the movement stick was held. WoW still decides whether the action succeeds.
Use **`/ep debug off`** to stop logging or **`/ep debug`** to check its
status. Logging resets on reload.

The header, footer, and editor use built-in gamepad art. Controller glyphs
are 32 UI units and follow the active controller icon set.

By default, the wheel opens on **Categories**. Favorites are saved account-wide
and continue onto more pages after the first eight. Existing custom names,
chat messages, command slots, and panel position are preserved. **Sit**
is added to Favorites once and can be removed like any other entry.
To reorder Favorites, open `/ep list`, select a favorite, and use the
**Up** and **Down** buttons above the list. Moving a favorite across a page
boundary also changes which wheel page it appears on.

Change **Open on Category Wheel** under **Settings → AddOns → EmotePanel →
Categories** or use `/ep categories`. The default order is Favorites,
Professions, Say Chat, Party Chat, Commands, Game Panels, Target Marker,
and Player Interactions. Emotes and Voiced Emotes are off by default.
Select a category with A/Cross or left-click.
LB/RB, D-pad left/right, and mouse scrolling stay within that category.
B/Circle or right-clicking the center returns to the category wheel. Uncheck the
option to return to Favorites-first paging. The setting is saved account-wide.

Each row on the Categories settings page shows its current wheel icon.
Use **Edit** to rename the category shortcut or change its icon. You can
also press Y/Triangle or right-click a category on the regular wheel
outside combat. Select a row and use **Up** or **Down** to move it, or
uncheck it to hide its segment. **Reset Order** restores the default order.
**Reset Categories** restores the default names, icons, order, and
visibility and turns on Category Wheel.
Reordering is available while Category Wheel is enabled. The Actions
shortcut opens with LB, D-pad left, or scrolling up from Categories when
you have entries in Actions. Scroll down from Actions page 1 to return to Categories.

Open **Settings → AddOns → EmotePanel → Entries** or use `/ep list`.
Use the section dropdown to see one list at a time. `/ep list` opens
**Favorites**. Each row shows its current wheel icon. Click an entry to
select it, then use **Up** and **Down** above the list to move it within
its section.
The order is saved account-wide and used in both layouts. Each page fills
clockwise from 12 o'clock. **Reset Order** restores the category's default
order. Newly added entries follow the saved order.

Uncheck an entry to hide it from its category and from Favorites.
The wheel fills the gap. Rechecking the entry restores its place in the order,
favorite status, and customization.
Empty categories are skipped, and Professions still reports when it has
no visible entries.

**Actions** holds spells, items, saved macros, mounts, companion pets, and toys. Open `/ep actions` or use
**Choose Actions** below the section dropdown in Entries. Click a source tab
or use **D-pad left/right** from anywhere on the Actions tab to switch sources.
Under **Abilities**, **Highest learned rank only** is on by default.
Uncheck it to see lower ranks.
Ranks already on the wheel can still be managed from **Entries → Actions**.
Select a row to add it. Select a checked row again to remove it from
the wheel and from the Actions section in Entries. Spell and item
selections are saved for the current character. Call Pet follows the current
pet icon after a stable swap unless you chose a custom icon.

**Mounts** and **Companion Pets** list collected entries and work outside combat.
Use a companion pet again to dismiss it. **Toy Box** lists your collected toys
under the current in-game Toy Box filters. Selected toys stay on the wheel when you
change those filters. To use a toy in combat, open the wheel with its assigned keybind.

With ConsolePort installed, open **Options** on a usable bag item or an
active spell in the spellbook. Choose **Add to EmotePanel Actions** or
**Remove from EmotePanel Actions**. The menu uses the same item and spell
selection rules as the Actions picker.

Outside combat, press **Select** while pointing at a manually added spell,
item, or macro on the main wheel to remove it from Actions. WoW maps this
input to **View** on Xbox, the **left touchpad** on PlayStation, and **−**
on Switch.
The wheel stays open. You can add the action again from the picker.

Selected items appear in Actions and Favorites while carried or equipped.
If you run out, the item stays checked in the picker as **Not carried** and
returns to the wheel when you get another. Uncheck it to remove it from the
Items list. When you carry or equip it again, it appears unchecked and you can
add it back to the wheel.

Page left from the first Favorites page or from Categories to open Actions
on page 1. Keep paging left for page 2 and beyond. Page right from page 1
to return, or use B/Circle from any Actions page in Category Wheel mode.
You can reorder, hide, or edit entries in `/ep list` and add them to Favorites.

Hunters and Warlocks can assign up to two bindings under **Pet Keybind**
in **Controller Setup** in `/ep config`. Either binding opens or closes
the separate Pet Wheel in and out of combat. By default, it shows the
active pet's actions in pet bar order.
Open **Entries → Pet** under EmotePanel settings, or choose **Pet** in
`/ep list`. Select a row and use **Up** or **Down** to reorder it, use
**Show on wheel** to hide or show it, and use **Edit** to change its icon
or wheel placement. **Reset Order** restores pet bar order. Your settings
follow each action when it moves on the pet bar. Combat uses the layout
prepared before the fight. If your pet dies before combat, the wheel can
reuse the last layout prepared for its name during the current UI session.
A pet without a matching prepared layout uses native pet-bar slots until
combat ends.

Press **A / Cross** or left-click to issue a command. Abilities that support
autocast show a soft gold ring when enabled. Active pet commands and
stances show a soft green ring. The **Attack** ring pulses while the pet is
attacking. **Move To** displays **Choose a destination** while you pick
a spot. Unavailable actions dim, and the selected entry reports when it
is out of range, on cooldown, or currently unavailable.
The controller prompt shows **X Activate** when autocast is off and
**X Disable** when it is on. Right-click the ability to toggle autocast.
The Pet selector lights up the segment, leaving the icon ring for status.
The segment is violet by default, green for active commands and stances,
gold for autocast on, and blue for autocast off.
The combat wheel uses the pet's autocast abilities prepared before the
fight. Reviving a pet with a matching prepared layout keeps its prepared
autocast controls. If the wheel only has native slots for the pet, its
autocast controls become available when combat ends.

Select an action and press A/Cross or left-click to use it.
Account and character macros are listed separately. Each macro selection
follows the saved macro by name and scope, so edits in WoW carry through.
If you rename a macro, select it again. Macros with duplicate names in
the same scope are skipped.

Enable **Show wheel tooltips** on the **Customization** tab in `/ep config`
to see details on mouse hover or when selecting spells, items, macros,
and pet actions with a stick or the D-pad. A preselected spell, item, or macro
also shows its tooltip when you page to Actions. Tooltips are centered above the
wheel's page title. Item actions show a single tooltip. Wheel tooltips are off by default.
Spells, items, and pet actions use WoW's tooltip. Macros show their
scope and command text, including the version loaded before combat.

**Actions**, **Favorites**, and the **Pet Wheel** show cooldowns with a
circular swipe over the icon. The spell global cooldown animates with the
swipe alone. Individual cooldowns also turn icons gray. Icons are tinted
red when WoW reports the current target is too close or too far away.
Spell icons turn blue when you lack mana or another resource and dim when WoW
reports the spell is otherwise unavailable.
Below the entry name, range and availability warnings use soft red, cooldowns
use amber, and active pet commands and stances use green. The line is
blank when there is no status to show.
Items show the carried quantity and spells show WoW's charge or use count
in the lower-right of the icon. Macros use the count, cooldown, and range
of the spell or item WoW reports.
Countdown numbers are on by default. Use **Show action cooldowns** under
**Customization** in `/ep config` to hide the numbers. The setting is saved account-wide.

Wheel icons depress when you press A/Cross or click. Actions and Favorites
also show spell cast and channel progress, an interrupt flash, a charge
recovery edge, and Blizzard's proc glow when a spell lights up.

Use **Add custom emote**, **Add custom message**, **Add custom party message**, or **Add custom command** to create
an entry in that category. Enter a name and an emote such as `/wave` or
`/me tests something`, a
message, or a slash command, then optionally choose an icon. Use **Edit**
to change an entry from the list, even when it is hidden. **Reset Overrides**
keeps added entries, visibility choices, order, and favorites. To remove
a custom entry, focus it in **Entries** and press **Select**, or open its
editor and use **Delete** (**LB/L1**). Confirm the deletion to remove it
from the wheel and Favorites.

**Close panel after action** is checked by default on the main EmotePanel
settings page. Uncheck it to keep the wheel open after using an entry.
Enable **Remember last Action** to reopen on the page and segment you last
used. Browsing the wheel leaves that action unchanged. The checkbox is
saved, and the remembered action clears on logout or `/reload`. If the
entry is no longer visible, the wheel uses its usual opening page.
**Controller glyphs** applies to the wheel, editor, icon picker, settings,
and help. **Automatic** follows WoW’s active icon set. You can choose Xbox,
PlayStation, or Nintendo Switch when the client has the corresponding art.
This changes the prompts. The physical controls keep their assignments.
In the settings window, **LB/RB** switches side tabs and **D-pad up/down** moves
focus. Hold **D-pad up/down** to keep moving one row at a time.
Use **D-pad left/right** to adjust a slider or cycle a dropdown. Hold
left or right on a slider to keep adjusting it one step at a time.
Press **A/Cross** to select and **B/Circle** to close. Outside combat, WoW's
**Options → AddOns → EmotePanel** also has a button to open this window.

In **Controller Setup**, focus a Primary or Secondary slot and press
**A/Cross** or click the slot to open the binding dialog. Press a keyboard
key or controller button before the five-second countdown ends. If the
input already has a WoW binding, the wheel replaces it. Hold **B/Circle**,
press **Esc**, or click **Cancel** to stop sooner. Tap **B/Circle** to assign it.
Press **X/Square** on a focused slot or right-click it to clear the binding.
Bindings save to WoW's active account or character set.
The controller footer describes the focused setting. Mouse hover shows
the same descriptions in tooltips anchored to the top right of the hovered control. **Reset Wheel Behavior**
restores the opening, action, and navigation options on its tab.
Reset buttons ask for confirmation. Press **B/Circle** to cancel or click
either labeled button. **A/Cross** activates the highlighted button when
the ConsolePort cursor is active and confirms when it is inactive.
Use `/ep reset` or **Reset to Defaults** in General to restore addon defaults
in the active profile, including its custom entries, Favorites, and Actions.
Confirm outside combat. General opens after the reset. Other profiles and
WoW keybinds are kept.

Under **Customization**, **Display and feedback** groups the keybind legend,
cooldown numbers, tooltips, and wheel sounds. When **Show keybind legend**
is off, press **View / Select** to fade the legend in, and press it again to
fade it out. Turn off **Show legend hint** to hide the small prompt. The
shortcut stays active and takes priority over quick removal while the
legend is set to toggle. You can remove actions from the Actions tab.
If View / Select is your wheel opener, it keeps opening and closing the wheel.
**Wheel position**
has two sliders that show your current position from **0%** to **100%**.
**50%** is centered. Higher X values move the wheel right, and higher Y
values move it up. Drag the slider or click its arrows to adjust it by
one percentage point at a time. Changes save immediately.
Dragging the wheel also saves its position and updates both sliders.
**Cursor Center Position** aligns the ring vertically with WoW’s centered
cursor and targeting position. It starts enabled on fresh installs, and
existing installs keep their current selection. Horizontal positioning still
works. Turn the option off to return to your saved vertical position.
**Reset Position** clears the manual offsets and enables **Cursor Center Position**. **Reset All Entry Overrides**
restores the original icons, names, and text for wheel entries.

Open **Customize Entry** from the wheel, or focus an entry in settings and
press **Y/Triangle**. You can also right-click the row. In **Actions**,
add the action to the wheel before editing it. In **Entries** and
**Categories**, left-click a row to select it for the **Edit**, **Up**, and
**Down** buttons. Click again to clear the gold selection. On a controller,
**A/Cross** toggles the focused row's checkbox when available, and D-pad
left/right reorders the focused row. Hold either direction to keep
reordering one place at a time. **R3** resets
the order when available. In **Entries**, **X/Square** opens **Choose
Actions** or the section's **Add** button.

**Wheel Placement** shows the entry’s page and slot in separate rows for
its section and Favorites. Each row has its own **Up / Down** buttons.
On a controller, **D-pad left/right** selects a row and **D-pad up/down**
reorders the entry in that row. **Save** applies both orders.
Click **Favorite** or **Unfavorite**, or press **RB/R1**, then
**Save** to update Favorites. A gold star marks favorited entries in the
Wheel Entry List. Use **Visible** and the **Up / Down** buttons to
adjust placement. On a controller, **X / Square** toggles visibility and
**D-pad up/down** moves the entry. **LB / L1** opens Reset confirmation when
available. **A / Cross** confirms and **B / Circle** backs out of the
confirmation. In the editor, **A / Cross** saves placement and customization.
**B / Circle**, **Cancel**, and the close button ask before discarding unsaved
changes. Choose **Discard** with **A / Cross** or **Keep editing** with
**B / Circle**. Add new entries from their section in Entries.

The wheel closes when opening EmotePanel settings. The **Settings** shortcut
is in **Commands** and can be favorited.

**Emotes** and **Voiced Emotes** follow the two Blizzard chat menus.
The wheel includes stock entries from both menus alongside the original
extra emotes. EmotePanel skips Lean and Faction Cheer on Forever.
Built-in entries have distinct default icons within
their category. **Add custom emote** uses WoW's voice list to choose the
category automatically. Custom `/me` text appears under **Emotes**.

Open **Game Panels** from the category wheel or page right past Favorites
in the default layout. The three default pages contain:

1. World Map, Quest Log, Character Info, Talents, Spellbook, Group Finder, Legacy, and Reputation.
2. Guilds & Communities, Friends, PvP, Currency, Mounts, Companion Pets, Appearances, and Account Collections.
3. Calendar, Pet Spellbook (Hunters and Warlocks), Toys, and Cooldown Settings.

Open WoW's Game Menu and Edit Mode with your Game Menu keybind.

Pet Spellbook dims until you summon a pet. The Pet Wheel opens with a
living summoned pet and closes if that pet dies or is dismissed, including
during combat.

If you’ve customized the order, use **Entries → Game Panels → Reset Order**
to apply this default.

A/Cross or left-click opens the corresponding WoW window or tab. **PvP**
opens the Character panel's PvP rank tab. **Cooldown Settings** opens the
Cooldown Viewer settings, and **Appearances** opens that tab in Collections.
**Character Info** opens on the first press
or click outside combat and follows **Close panel after action**. Game Panels
shortcuts become available again when combat ends. WoW still controls access
to panels that require an unlock. Existing Inventory and Reagent Bag Favorites merge into Backpack.
Inventory customizations take precedence when both shortcuts were customized.

Open **Professions** from the category wheel or page left from the first
Favorites page, past any Actions pages, in the default layout. It lists only the current character's learned professions,
with up to two primaries followed by all learned secondaries. The preview
shows the skill rank. A/Cross or left-click opens crafting when available
or the WoW professions overview otherwise. Both paths use protected windows
and are unavailable in combat. Profession icons can be edited with
Y/Triangle or right-click. Favorited professions stay saved account-wide
and only appear on characters that have learned them.

Say Chat and Party Chat each start with 16 messages across two pages.
Say uses local chat for greetings, questing, and campfire conversation.
Party covers quick group coordination such as waiting for mana, calling
out adds or interrupts, and suggesting a campfire break.
The Category Wheel and its entries use built-in WoW artwork. You can change an entry’s icon from its editor.

Party messages require a group. **Ready?** sends a party message, and
the **Ready Check** command starts WoW's ready check for a group leader
or assistant.

**Leave Group** appears under **Player Interactions** while you are in a
party or raid. It works without a selected target. Enable **Automatic quest items and abilities** to also
show it on its own final **Actions** page while grouped. Both shortcuts follow WoW's leave
behavior, including any instance confirmation.
You can reorder it in Entries while solo. If favorited, it appears in
Favorites only while grouped. Use **Entries → Player Interactions → Reset Order**
to apply the new default if you already have a custom order.

**Player Interactions** groups Inspect, View Talents, Add Friend, Follow,
Trade, Duel, and a shared Invite shortcut. Target another player first.
The shortcut changes to **Request to Join** or **Suggest Invite** according to WoW's group rules.
It is hidden when the target is already in your party or raid.
**Remove from Group** appears in slot eight when you can directly remove the
targeted party or raid member outside combat. The confirmation names the
player and supports A/Cross to remove or B/Circle to cancel. Use WoW's
group menu for **Vote to Kick**.
Trade, Follow, and Duel dim and show **Out of range** when the target is too far away.
Enable the category in **Settings → Categories** or page to it in the
Favorites-first layout. Use **Entries → Player Interactions** to reorder,
hide, or edit the shortcuts.

Built-in commands call WoW actions directly and show a description in
the wheel and entry list. The default **Inspect Target**, **Who**, and
**Settings** actions open protected windows outside combat. Settings slash
commands are also available outside combat. **Chat Channels** opens
WoW's channel list outside combat, where you can choose a channel to leave. **Befriend
Target** adds a friend without toggling their existing friend status.
During combat, Befriend Target skips opening the Friends window without a
player target.
**Mark Skull**, **Mark Cross**, and **Clear Mark** use WoW's secure
raid-marker action. A missing target triggers WoW's on-screen error
and its error cue when available. Use the wheel keybind to mark in
combat. Custom slash overrides still submit through chat and
preserve an open draft.
**Reload UI** calls WoW's reload function for either input. Leave the
slash override blank in a built-in command's editor to use its native action.

Emotes and slash commands use WoW's normal targeting rules.

In the editor, Y/Triangle opens the icon picker and A/Cross saves. The
**Wheel Placement** panel shows the entry's current page and slot.
Drag the **Choose Icon** title bar to move the picker.
In the picker, the gold outline and large preview follow the D-pad selection.
Tap LB/RB or use the arrows or mouse wheel to page backward or forward.
Hold LB/RB to repeat one page at a time using the **Repeat paging** timing.
Hold X/Square and tap LB/RB to skip ten pages backward or forward. With
the mouse, hold Shift while clicking an arrow or scrolling to skip ten pages.
A green check marks the entry's current icon when it is on the page.
Use Y/Triangle or click the **Wheel Icons** and **WoW Icon Library** side tabs to
switch sources. Use A/Cross to choose. Press **R3** or click **Default** and
confirm to restore the stock icon when you save. Say, Party, and Command entries also support editing their
name and text.

## Profiles

Open **Profiles** in Settings or type `/ep profiles`. Changes save automatically
to the active profile shown in the title bar. Each character remembers its
selection. Characters using the same profile share their changes. On first login, a profile
named **Firstname Lastname** is created automatically. New characters get fresh
addon settings while keeping assigned WoW keybinds. Upgrades from versions without
profiles copy the current setup into the character profile.

**Default** is the clean fresh-install preset and cannot be deleted or overwritten.
Editing it saves a new character copy instead. Existing profile names and explicit
named-profile selections are preserved on upgrade; names that collide receive a
numbered suffix. Character ownership uses GUIDs, including names with surnames.

Choose **Save As**, enter a new name, and confirm to duplicate your current setup.
The copy becomes active. Changes to it leave the original profile unchanged.
Use the dropdown to switch. On a controller, Confirm opens the list, up/down moves
through it, Confirm selects, and Back closes it without switching. If a wheel key
belongs to another WoW action, review the listed key and action before confirming.
At login, a conflict leaves your WoW bindings in place while other profile settings
load. Select the active profile again to review pending keys. Editing a wheel key
in General adopts your current wheel bindings. Each profile saves the minimap
button position along with the wheel position.

**Export:** choose what to include using the nested checkboxes, then Continue.
Choose **Select text** and press Ctrl+C to copy the export.

**Import:** paste the export, Continue, and review the nested checkboxes. Everything
starts checked. Continue again, enter a new profile name, and confirm **Create Profile**.
The new profile becomes active. Unchecked fields use addon defaults. Creating a new
custom entry requires both its name and message or command; an omitted icon uses
the default icon. Leaving all definition fields unchecked skips the custom entry
and its dependent order, visibility, override, and Favorite references in a new
profile. Exported references contain only the checked definition fields.
Existing profile names cannot be overwritten.

Unavailable actions remain saved and appear when learned, carried, or collected.
Missing macros resolve when a macro with the same name exists in the matching scope.
Importing shared actions maps them to the current character.

**Delete Profile** asks for confirmation and switches its characters to Default.
Use **Reset to Defaults** or `/ep reset` to reset the active profile while
keeping other profiles and your WoW keybinds. Both actions are available outside combat.

## Slash commands

| Command | What it does |
| --- | --- |
| `/ep`, `/emotepanel` | Open or close EmotePanel settings. |
| `/ep config` | Open settings on the General tab. |
| `/ep setup` | Open the primary wheel keybind dialog outside combat. |
| `/ep list` | Reorder Favorites and manage wheel entries. |
| `/ep actions` | Choose entries for the Actions wheel. |
| `/ep profiles` | Switch profiles, review pending wheel keys, Save As, delete, import, or export. |
| `/ep categories` | Customize and reorder Category Wheel shortcuts. |
| `/ep reset` | Confirm a full reset of the active profile to addon defaults, then open General. |
| `/ep debug` | Show combat debug status. |
| `/ep debug on`, `/ep debug off` | Turn combat logging on or off for this session. |
| `/ep scroll` | Open the Help guide. |
| `/ep help` | Open the Help tab in EmotePanel settings. |
| `/ep new` | Open the in-game changelog. |

The first Settings tab is **Help**. It starts with **Start Here**, followed
by category overviews, short step-by-step chapters, profile instructions, and a
slash command reference. Longer chapters continue on extra pages to keep text
above the page buttons. Gamepad and mouse controls have their own rows, and
slash commands are blue. Click **Previous Page** or **Next Page**, or press
**Y/Triangle** to go back a page and **X/Square** to go forward.
Select **New** in Settings or type `/ep new` to read the in-game changelog.
It opens at the latest release. Use the same page controls to browse older versions.
Settings and Help open outside combat. If combat closes Settings, it reopens
on the same tab when combat ends. Debugging is available during combat.
Reload the UI after installing.

## Source layout

`EmotePanel.lua` creates the private addon namespace, registers the public
callbacks and slash commands, and routes events. The TOC loads the modules
before EmotePanel's `ADDON_LOADED` event initializes saved data and live pages,
creates the wheel and settings frames, and sets up input outside combat.

| Files | Responsibility |
| --- | --- |
| `Entries.lua` | Entry definitions, discovery, and account-wide Favorites, ordering, and overrides. Action selections and custom entry IDs retain their saved keys, with direct actions scoped by character GUID. |
| `Pages.lua` | Live layouts, shared navigation links, and the displayed page. Remembered actions are session state. |
| `Wheel.lua`, `Widgets.lua` | Wheel rendering, action feedback, tooltips, and reusable UI controls. |
| `Input.lua`, `Bindings.lua` | Regular mouse and controller input, movement capture, binding lookup, and migration in the active WoW binding set. |
| `CombatWheel.lua` | Restricted handlers and the combat snapshot of page links and action attributes. |
| `Settings.lua`, `EntryEditor.lua`, `ActionPicker.lua` | Settings pages, entry and icon editing, and selection of spells, items, and macros. |

The regular wheel uses the live navigation model. The combat wheel copies its
destinations into secure attributes outside combat. Page and favorite refreshes
and pet slot changes mark the snapshot dirty. Synchronization waits until
combat lockdown and the combat display have ended. The pet display can still
read current status for the native slots already in the snapshot.

The Lua 5.1 mocks pass for both layouts, mouse and controller input,
protected dispatch, combat transitions, binding migration, and saved settings
across reloads. The user reported finding no issues while trying the 0.23.1
development build in WoW Forever.

From the standalone repository root, run `python3 tests/test_emote_panel.py` with Lupa's Lua 5.1 runtime.
