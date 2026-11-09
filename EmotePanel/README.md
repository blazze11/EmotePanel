# EmotePanel 0.23.0

For WoW: Forever 1.60.1 (interface 16001). Open or close the wheel with
`/ep`, or assign a wheel keybind in **Controller Setup** at the top of
`/ep config`. Existing legacy assignments move to the secure binding
the next time the addon loads outside combat.

Left-click the minimap button or the **EmotePanel** entry in the **Addon
Compartment** to toggle the regular wheel. Right-click either for settings.
Drag the minimap button to move it around the map. The version appears
in the minimap tooltip and at the top of EmotePanel Options.

- Aim **either stick** directly at a sector. D-pad up/down steps around
  the wheel. Use LB/RB or D-pad left/right to change pages. Gold arrows
  beside the title show the available controller paging directions.
- Scroll up over the wheel for the next page or down for the previous
  page. Scrolling stops at the first and last pages of a category. In the
  Favorites-first layout, scrolling browses the full list and stops at either end.
- **A/Cross** opens a category or uses the highlighted action. **B/Circle**
  or right-clicking the center goes back from a category or closes the wheel.
- **Start/Menu** and controller buttons bound to **Game Menu** dismiss
  the wheel. **Esc** uses WoW's normal window closing order.
- **Y/Triangle** or right-click opens the editor for an action. Choose an
  icon from the wheel set or WoW's spell and item icon library, then save.
- **X/Square** or middle-click adds or removes the highlighted entry from
  Favorites. Favorites can mix emotes, chat messages, commands, game
  panels, and learned professions.
- The selected message or slash command appears below the control legend.
  Emotes and Voiced Emotes keep the legend and hide the slash preview.
  Press and release the left mouse button on the same sector to use it.
  Drag the centered page title to move the panel. The default position is screen center.

The wheel and selection highlight use Forever's stock eight-sector gamepad
atlases. Categories with more than eight entries continue on another page.
Game Panels use the corresponding Blizzard gamepad or Collections tab
art. Commands and messages use matching Blizzard interface icons where
available. Individual emotes keep distinct WoW icons because Blizzard's
emote wheel uses one shared icon. The selected entry's name appears between
the wheel and footer. Emotes, Say, and Party highlights use the colors
from WoW's chat settings. Commands are purple, game panels are teal,
and professions are orange. Custom icons follow their entry
into Favorites and persist after reload.

In combat, use the **Open or Close Emote Panel** keybind for protected
actions. `/ep` opens the regular wheel for chat, emotes, and other shortcuts.
Spells, items, saved macros, and pet actions use A/Cross or left-click
directly. Aim with a stick as you press A/Cross. You can release
the stick before releasing A/Cross. If you let go of the stick first, the
highlight returns to your last confirmed selection or clears. D-pad up/down
selects a sector that stays highlighted. Character Info stays dimmed and
shows **Unavailable in combat**. Emotes and other ordinary shortcuts leave
the combat wheel open. A rejected emote shows a message.

For controller use, check **Enable WoW controller input** under
**Controller Setup** in `/ep config`. This changes WoW's game-wide
`GamePadEnable` setting. Turn off **Enable Gamepad UI** under
**Options → Gameplay → Gamepad** because EmotePanel does not support
**Gamepad (Beta)**. ConsolePort is optional.
At login or UI reload, EmotePanel warns if the wheel keybind is unassigned,
Gamepad (Beta) is on, or a wheel has a controller binding and
`GamePadEnable` is off. The reminder in **Controller Setup** updates
when either controller setting changes.
The wheel handles its own controller navigation. Its controls are excluded
from ConsolePort's interface cursor. Opening the wheel suspends an active
ConsolePort cursor, including one you opened manually.

**Lock movement stick** is on by default in `/ep config`. It blocks
movement while either wheel is open and until you center the stick after
closing it. Turn it off to let the movement stick steer your character
and aim the wheel at the same time.

Combat uses the wheel layout and saved macro text loaded before the fight.
Changes take effect after combat. If an item runs out mid-fight, its icon
disappears and the surrounding sectors keep their positions until combat ends.
WoW still applies the usual combat rules to each action.

To diagnose a combat wheel problem, enter **`/ep debug on`** and reproduce it
using the wheel keybind. In chat, **EmotePanel debug** groups lines under
labels such as **Wheel**, **Secure click**, **Emote**, and **WoW restriction**.
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
Categories** or use `/ep categories`. The default category wheel has eight
shortcuts: Favorites, Emotes, Voiced Emotes, Say Chat, Party Chat, Commands,
Game Panels, and Professions. Select a category with A/Cross or left-click.
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

**Actions** holds spells, items, and saved macros. Open `/ep actions` or use
**Choose Actions** in the **Actions** section of Entries. Pick **Abilities**, **Items**, or **Macros**
and click a row to add it. Click the checked row again to remove it from
the wheel and from the Actions section in Entries. Spell and item
selections are saved for the current character.

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
prepared before the fight.

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
fight. If you swap pets in combat, the new pet's autocast controls become
available when combat ends.

Select an action and press A/Cross or left-click to use it.
Account and character macros are listed separately. Each macro selection
follows the saved macro by name and scope, so edits in WoW carry through.
If you rename a macro, select it again. Macros with duplicate names in
the same scope are skipped.

Enable **Show wheel tooltips** under **Wheel behavior** in `/ep config`
to see details on mouse hover or when selecting spells, items, macros,
and pet actions with a stick or the D-pad. Wheel tooltips are off by default.
Spells, items, and pet actions use WoW's tooltip. Macros show their
scope and command text, including the version loaded before combat.

**Actions**, **Favorites**, and the **Pet Wheel** show cooldowns with a
circular swipe over the icon. The spell global cooldown animates with the
swipe alone. Individual cooldowns also turn icons gray. Icons are tinted
red when WoW reports the current target is too close or too far away.
Below the legend, range and availability warnings use soft red, cooldowns
use amber, and active pet commands and stances use green. The line is
blank when there is no status to show.
Macros use the cooldown and range of the spell or item WoW reports.
Countdown numbers are on by default. Use **Show action cooldowns** in
`/ep config` to hide the numbers. The setting is saved account-wide.

Wheel icons depress when you press A/Cross or click. Actions and Favorites
also show spell cast and channel progress, an interrupt flash, a charge
recovery edge, and Blizzard's proc glow when a spell lights up.

Use **Add Emote**, **Add Say**, **Add Party**, or **Add Command** to create
an entry in that category. Enter a name and an emote such as `/wave`, a
message, or a slash command, then optionally choose an icon. Use **Edit**
to change an entry from the list, even when it is hidden. **Reset Overrides**
keeps added entries, visibility choices, order, and favorites.

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
In **Controller Setup**, click a keybind slot and press a keyboard key or
controller button. If the input already has a WoW binding, the wheel
replaces it. Press Esc to cancel or right-click a slot to clear it.
Bindings save to WoW's active account or character set.
Hover over settings controls for descriptions. **Reset General** restores
the defaults for wheel behavior, cooldown numbers, movement stick lock, and wheel tooltips.
Use **Reset to Defaults** in General to clear all saved EmotePanel settings,
custom entries and overrides, Favorites, and Action selections for every
character on the account. Confirm outside combat to reload the UI with the
defaults. WoW keybinds stay assigned.

Under **Customization**, use **Show keybind legend** to control whether
the controller shortcuts appear below the wheel. **Wheel position**
has two sliders that show your current position from **0%** to **100%**.
**50%** is centered. Higher X values move the wheel right, and higher Y
values move it up. Drag the slider or click its arrows to adjust it by
one percentage point at a time. Changes save immediately.
Dragging the wheel also saves its position and updates both sliders.
**Reset Position** returns the wheel to center. **Reset All Entry Overrides**
restores the original icons, names, and text for wheel entries.

Open **Customize Entry** from the wheel or an Entries row. **Wheel
Placement** shows the page and slot in its section and in Favorites, where
applicable. Use **Show on wheel** and the fixed **Up / Down** buttons to
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
their category. **Add Emote** uses WoW's voice list to choose the
category automatically.

Open **Game Panels** from the category wheel or page right past Favorites
in the default layout. The first page has
Character Info, Spellbook, Talents, Legacy, Quest Log, Guilds & Communities,
Group Finder, and Account Collections. The second has Mounts, Pets, Toys,
Calendar, Friends, Inventory, and World Map. A/Cross or left-click opens the
corresponding WoW window or tab. **Character Info** opens on the first press
or click outside combat and follows **Close panel after action**. In combat,
use WoW's normal Character Info binding or micro menu. WoW still controls
access to panels that require an unlock.

Open **Professions** from the category wheel or page left from the first
Favorites page, past any Actions pages, in the default layout. It lists only the current character's learned professions,
with up to two primaries followed by all learned secondaries. The preview
shows the skill rank. A/Cross or left-click opens crafting when available
or the WoW professions overview otherwise. Profession icons can be edited with
Y/Triangle or right-click. Favorited professions stay saved account-wide
and only appear on characters that have learned them.

Say Chat and Party Chat each start with 16 messages across two pages.
Say uses local chat for greetings, questing, and campfire conversation.
Party covers quick group coordination such as waiting for mana, calling
out adds or interrupts, and suggesting a campfire break.
Party messages require a group. **Ready?** sends a party message, and
the **Ready Check** command starts WoW's ready check for a group leader
or assistant.

**Leave Group** appears under **Commands** while you are in a party or
raid. It follows WoW's leave behavior, including any instance confirmation.
You can reorder it in Entries while solo. If favorited, it appears in
Favorites only while grouped.

Built-in commands call WoW actions directly and show a description in
the wheel and entry list. **Chat Channels** opens
WoW's channel list, where you can choose a channel to leave. **Befriend
Target** adds a friend without toggling their existing friend status.
When WoW hides the current
target marker, Skull and Cross use the native marker toggle. Custom
slash commands still submit through chat and preserve an open draft.
**Reload UI** calls WoW's reload function for either input. Leave the
slash override blank in a built-in command's editor to use its native action.

Emotes and slash commands use WoW's normal targeting rules.

In the editor, Y/Triangle opens the icon picker and A/Cross saves. In the
picker, the gold outline and large preview follow the D-pad selection.
A green check marks the entry's current icon when it is on the page.
Use LB/RB to change pages, Y/Triangle to switch libraries, and A/Cross to
choose. The Default button restores the stock icon
when you save. Say, Party, and Command entries also support editing their
name and text.

## Slash commands

| Command | What it does |
| --- | --- |
| `/ep`, `/emotepanel` | Toggle the regular wheel. Use the wheel keybind for combat spells, items, and macros. |
| `/ep config` | Open EmotePanel settings. |
| `/ep list` | Reorder Favorites and manage wheel entries. |
| `/ep actions` | Choose spells, items, and saved macros for the Actions wheel. |
| `/ep categories` | Customize and reorder Category Wheel shortcuts. |
| `/ep reset` | Ask to reset custom icons, names, and text. |
| `/ep debug` | Show combat debug status. |
| `/ep debug on`, `/ep debug off` | Turn combat logging on or off for this session. |
| `/ep scroll` | Show paging controls. |
| `/ep help` | Show the command list and wheel controls in chat. |

Help and debugging are available while the combat wheel is open. Use the
wheel keybind to close it before running the other commands. Reload the UI
after installing.

The Lua 5.1 mock checks cover both wheel layouts, mouse and controller selection, game panel
routing, learned professions, favorite persistence and paging, saved
messages, command submission, chat draft protection, and settings.

From the standalone repository root, run `python3 tests/test_emote_panel.py` with Lupa's Lua 5.1 runtime.
