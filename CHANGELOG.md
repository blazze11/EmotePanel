# EmotePanel changelog

## 0.22.22 for WoW: Forever (unreleased)

- Enable **Remember last Action** in General settings to reopen the wheel at the last-used entry. The checkbox is saved, and the remembered entry clears on logout or UI reload.
- Suspend the ConsolePort interface cursor while the wheel is open, including when the cursor was opened manually.
- Use the controller to toggle visibility, reorder entries, and confirm Reset in **Customize Entry**. The dialog shows the corresponding glyphs, including Back.

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
