# EmotePanel for WoW: Forever

EmotePanel is an eight-slice wheel for controller and mouse. Use it for
regular and voiced emotes, quick chat, game actions, learned professions,
and shortcuts to Blizzard panels. The wheel opens on **Favorites** by default. You can also start on a
customizable category wheel.

## Install

Copy the inner `EmotePanel` folder from this repository into
`World of Warcraft/_forever_/Interface/AddOns/`. The installed folder
should contain `EmotePanel.toc`, `EmotePanel.lua`, and `Bindings.xml`.
Enable **EmotePanel** in the AddOns menu. If the game is already open
and the addon was previously installed, run `/reload`.

This branch targets **WoW: Forever 1.60.1** (interface `16001`).

## Controls

<img width="616" height="716" alt="wheel_preview" src="https://github.com/user-attachments/assets/c5234349-ac2c-43ed-b23b-25b30910a1a1" />

Type `/ep` to open the wheel, or assign **Open or Close Emote Panel**
under **Options → Keybindings → Emote Panel**.

| Action | Controller | Mouse or keyboard |
| --- | --- | --- |
| Select a slice | Either stick or D-pad up/down | Hover |
| Change page | LB/RB or D-pad left/right | Header arrows |
| Use the selected entry | A / Cross | Left-click |
| Add or remove a favorite | X / Square | Middle-click |
| Edit an entry | Y / Triangle | Right-click |
| Go back or close the wheel | B / Circle | Back or the close button |
| Dismiss the wheel | Start/Menu | Esc |

Drag the header to move the wheel. The selected entry's message or
action description appears below it.

## Customize

<img width="444" height="394" alt="custom_text" src="https://github.com/user-attachments/assets/c54b35a4-1355-4567-88e6-6bc82b51dda9" />

- Open **Settings → AddOns → EmotePanel**, use the **Settings** entry
  on the Commands wheel, or type `/ep config`.
- Open **Categories** or type `/ep categories` to enable Category Wheel
  and choose its visible segments and order.
- Open **Entries** or type `/ep list` to show, hide, reorder, or edit entries.
  Hidden entries also disappear from Favorites until you restore them.
- Check saved WoW macros under **Macros** in Entries. Page left from
  Favorites or Categories to reach them. In Category Wheel mode, page
  right from the last Macros page to return to Categories. Macros run
  directly outside combat and can be added to Favorites.
- Add your own emotes, Say messages, Party messages, or slash commands.
  Use the icon picker to give each entry its own icon.
- Uncheck **Close panel after action** to keep the wheel open while
  using entries. Settings and the Character Info confirmation close the
  wheel to take focus.
- The main settings page includes wheel position, controller glyph style,
  and separate resets for position, general settings, categories, and
  icon or text overrides.
  
<img width="596" height="569" alt="custom_icons" src="https://github.com/user-attachments/assets/0f9f0349-ae86-4a17-a7a9-08bb23878c41" />

## Game actions

Built-in commands such as Ready Check, Roll, and pull countdowns use
WoW's own actions. Custom slash commands use chat, and an open chat
draft is preserved. Party messages require a group. **Leave Group**
appears in Commands while grouped. **World Map** is in Game Panels.

The Professions page lists only professions learned by the current
character. To open **Character Info** from the wheel outside combat,
select the entry and confirm with a second click or A / Cross. In
combat, use WoW's Character Info binding or micro menu.

Use `/ep help` for the in-game command list.

<img width="1122" height="908" alt="select_add_edit" src="https://github.com/user-attachments/assets/8e63bb03-e450-4405-8396-edab9ba32f86" />

## AI assistance

OpenAI Codex helped develop and document the Forever port. Automated
checks use a simulated WoW UI and cannot verify every behavior in the
live client.
