# EmotePanel changelog

## 0.24.0 for WoW: Forever

- **Settings and Help.** A WoW Social-style settings window adds side tabs, controller shortcuts, reset confirmations, and a five-second keybind dialog. Confirmation dialogs respect the ConsolePort cursor. `/ep help` opens a nine-page guide. Open settings with `/ep` or by left-clicking the minimap or Addon Compartment shortcut. Open either wheel with its assigned keybind. Wheel position can follow WoW’s vertical cursor center and does by default on fresh installs.
- **Wheel navigation.** Mouse and gamepad category selection survives background refreshes. Both wheels fade in and out and offer optional sounds and vibration. Toggle the control legend with View / Select and optionally hide its prompt. Segment and page repeat have separate timings adjustable in 10 ms steps outside combat. Either can stop at its ends in or out of combat.
- **Actions.** Add or remove spells and items from ConsolePort's spellbook and bag menus. Automatic quest items and abilities and Highest learned rank only are on by default. Wheel icons show item counts and spell charges. Call Pet updates its icon after a stable swap.
- **Commands and Game Panels.** Backpack toggles all bags from Commands. Game Panels adds shortcuts such as Reputation, PvP, and Appearances. Protected shortcuts, including Chat Channels, dim in combat.
- **Target Markers.** Open all eight marks from Categories or Commands. Press Y/Triangle to mark yourself. X/Square or the center icon clears your target's mark, or your own when you have no target. Use your assigned wheel keybind in combat.
- **Pet Wheel.** Revive your pet in combat and reopen the wheel with its prepared order and autocast shortcuts when available. The wheel closes when the pet dies or is dismissed. Pet Spellbook dims when no pet is summoned.
- **Entries and Favorites.** Updated Blizzard artwork for categories, emotes, and quick messages. Fixed stale segment icons when a texture fails to load. Categories and action types have distinct highlight colors. Professions and Player Interactions replace Emotes and Voiced Emotes on the default Category Wheel. Gold stars identify favorited entries. Add or remove Favorites and reorder an entry in both its category and Favorites from the same editor.
- **Custom entries.** Preview emote text, add custom `/me` emotes, and delete custom entries with confirmation. Creation dialogs show example hints in empty fields.
- **Player Interactions.** Find Inspect, View Talents, Add Friend, Follow, Trade, Duel, contextual Invite, Remove from Group with confirmation, and Leave Group. Leave Group also gets its own final Actions page when automatic entries are enabled.

## 0.23.0 for WoW: Forever

- **Pet Wheel for Hunters and Warlocks.** Assign up to two keybinds in Controller Setup. Use pet commands and toggle supported autocast in combat. Glows mark autocast and active commands or stances. Use **Entries → Pet** to reorder, hide, or customize actions.
- **Custom categories.** Give each shortcut its own name and icon. The Categories settings page shows its current icon.
- **Clearer action feedback.** See circular cooldowns, including the global cooldown, plus spell cast progress, interrupts, charges, and procs. Turn on **Show wheel tooltips** to see spell, item, macro, and pet details.
- **Mouse navigation.** Scroll up for the next page and down for the previous page. Right-click the center to go back or close. Scroll up from Categories to open Actions and down from Actions page 1 to return.
- **Controller setup.** Toggle WoW controller input in the addon settings. ConsolePort is optional. Turn off Blizzard's **Gamepad (Beta)** UI. Assigning a wheel keybind replaces an existing binding on that input.
- **Movement stick.** The stick stays locked through button presses. Turn off **Lock movement stick** if you want to move while aiming.
- **Emotes and chat.** Highlights use your WoW chat colors. Emote pages keep the control legend and hide the slash preview. Removed Lean and Faction Cheer from the built-in list.

## 0.22.31 for WoW: Forever

- Set your wheel keybind right in **Controller Setup**. Categories and cooldown numbers are on by default, and settings have hover tips.
- Turn on **Remember last Action** to reopen the wheel at the last entry you used during this session. The ConsolePort cursor stays out of the way while the wheel is open.
- Say and Party each have **16 quick messages**, including campfire conversation starters. Default entries have distinct icons within each category, and Chicken and Eat swapped icons.
- Edit wheel entries with your controller. The editor shows button prompts and asks before discarding unsaved changes.
- Move the wheel with percentage sliders and arrow buttons. Uncheck an item marked **Not carried** to remove it from the Items list.
- Use **Reset to Defaults** to clear EmotePanel settings and customizations for all characters and reload the UI. Your WoW keybinds stay assigned.

## 0.22.19 for WoW: Forever

Changes since 0.21.4. Requires WoW: Forever 1.60.1 (interface `16001`).

### Actions wheel

- The former Macros wheel is now **Actions**. Add learned spells, carried or equipped items, and saved WoW macros directly.
- Open **`/ep actions`** or **Entries → Actions → Choose Actions**. The **Abilities**, **Items**, and **Macros** lists use a click-to-toggle selection.
- Add Actions to Favorites alongside emotes, chat messages, commands, professions, and panel shortcuts.
- Direct spell and item choices are saved for the current character. Account and character macros are listed separately and follow the saved macro by name and scope.
- A depleted item drops out of the wheel. It remains checked in the picker as **Not carried**, where you can remove it. Carry or equip it again to bring it back.
- Entries lists the selected Actions. Unchecking one removes it from that list and from the wheel.
- Paging left from Favorites or Categories opens Actions on page 1. Continue left through later Actions pages, or page right from page 1 to return.
- **Cooldowns** desaturate spell and item icons, including macro icons when WoW reports an associated spell or item. Spell indicators skip the global cooldown.
- **Show action cooldowns** enables optional countdown numbers. The setting is available in General.
- **Range** tints Actions and Favorites icons red when WoW reports that the current target is out of range.

### Combat and controller input

- Bind **Open or Close Emote Panel** to open the combat wheel. Existing assignments to the old opener migrate when possible outside combat.
- Use **A / Cross** or left-click to activate spells, items, and saved macros from Actions or Favorites in combat. WoW still applies its normal action restrictions.
- The combat wheel uses the layout and saved macro text loaded before combat. When an item runs out mid-fight, its sector becomes empty and the surrounding slots keep their positions until the layout can refresh.
- Aim with a stick and press **A / Cross**. Releasing the stick before releasing the button preserves the chosen sector. Centering the stick without confirming clears the temporary highlight or returns it to the last confirmed selection.
- Use D-pad up/down to select a sector that stays highlighted. Changing pages clears a pending selection.
- If a spell, item, or macro closes the combat wheel, the movement stick stays captured until it returns to neutral. This prevents a held stick from immediately interrupting a cast.
- Outside combat, the regular wheel keeps your selection when the stick centers. Center the movement stick before confirming a cast to avoid walking.
- Character Info is dimmed in combat and shows **Unavailable in combat**. Use WoW's normal Character Info binding or micro-menu button there.
- Ordinary shortcuts such as emotes leave the combat wheel open. **`/ep`** continues to open the regular wheel for emotes, chat, and other shortcuts.
- Corrected emote feedback. Successful emotes show WoW's usual chat line and follow the regular wheel's close-after-action setting. An actual restriction still shows feedback.
- Use **`/ep debug on`** to trace wheel pages, secure clicks, emote results, and WoW restriction events. **`/ep debug off`** stops logging, and **`/ep debug`** shows its status.

### Entries, Favorites, and Categories

- Entries shows one section at a time. The dropdown covers Favorites, Actions, Emotes, Voiced Emotes, Say Chat, Party Chat, Commands, Game Panels, and Professions.
- **`/ep list`** opens on Favorites. Each row displays its current wheel icon, including any override.
- Click an entry once and use the fixed **Up / Down** buttons. The selection follows the entry, and the list scrolls to keep it in view.
- Favorites can be moved across page boundaries. Saved ordering is used by the regular and combat wheels.
- Category ordering also uses a fixed **Up / Down** pair. The selected category displays its wheel slot or **Hidden**.
- Section-specific **Add** buttons create custom entries where supported. **Choose Actions** is available in the Actions section.
- Entries and the action picker use the newer WoW scrollbar.
- **Reset Order** restores a section's order. **Reset Categories** restores category visibility and order and turns off the Category Wheel.

### Customize Entry

- The editor is available from wheel entries and from the **Edit** button in Entries and Favorites.
- **Wheel Placement** shows an entry's page and slot, plus its Favorites position if it has one. Hidden or unavailable entries show their status.
- **Show on wheel** controls visibility. Hiding an entry preserves its saved order, customization, and Favorite status.
- Move the entry within its section, or within Favorites when editing from Favorites.
- **Save** applies placement and customization together. **Cancel** discards the draft. Saving a move from the wheel follows the entry to its new slot.

### Settings and launchers

- General has a **Wheel Keybind** shortcut, the close-after-action setting, and the countdown option.
- Customization contains glyph style, wheel position, and **Reset All Entry Overrides**. The X and Y fields refresh after dragging, applying a position, or resetting it.
- **Wheel Display** has separate switches for the Help button, Close button, and keybind legend. Hiding the legend moves the selected entry's text up.
- A draggable minimap button remembers its position. It and the native Addon Compartment entry toggle the wheel with left-click and open settings with right-click outside combat.
- The version appears in the settings header and minimap tooltip.
- A red login message points out a missing wheel keybind. For controller users it also flags a missing or inactive ConsolePort setup and Blizzard Gamepad (Beta) when applicable.
- **`/ep help`** lists the current shortcuts, including the action picker, category settings, and debug commands.

### Upgrading

- Update the existing EmotePanel folder and run **`/reload`**. Your saved settings, wheel order, and Favorites remain available.
- Verify **Open or Close Emote Panel** under **Options → Keybindings → Emote Panel** before using the combat wheel.
- For controller use, enable **ConsolePort** and turn off Blizzard's **Enable Gamepad UI**. Gamepad (Beta) can override addon keybinds.
