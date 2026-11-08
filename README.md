# EmotePanel for WoW: Forever

EmotePanel is an eight-slot wheel for controller and mouse. Keep spells, items, saved macros, emotes, quick chat, professions, and Blizzard panel shortcuts within reach. The wheel opens on Categories by default, and Favorites gives you a page for the entries you use most.

## Get started

1. Download the Forever ZIP from [GitHub Releases](https://github.com/blazze11/EmotePanel/releases) or [CurseForge](https://www.curseforge.com/wow/addons/emote-panel/files).
2. Extract the `EmotePanel` folder into `World of Warcraft/_forever_/Interface/AddOns/`. Enable EmotePanel in the AddOns menu and run `/reload` if you're updating while logged in.
3. Assign a wheel keybind under **Controller Setup** at the top of `/ep config`. Use this keybind for combat spells, items, and macros. Use `/ep` for the regular wheel.
4. For controller play, install and enable **ConsolePort**. Turn off Blizzard's **Enable Gamepad UI** under **Options → Gameplay → Gamepad**. Gamepad (Beta) can override addon keybinds.

This branch targets **WoW: Forever 1.60.1** (interface `16001`).

## Build your wheel

- **`/ep actions`** opens the Abilities, Items, and Macros picker. Click a row to add it and click again to remove it. Page left from Favorites or Categories to reach Actions.
- **`/ep list`** opens Favorites in Entries. Switch sections to show, hide, edit, and reorder entries. Select a row once and use the fixed **Up / Down** buttons.
- **`/ep categories`** sets up the Category Wheel, which opens by default. Choose which categories appear and where they go.
- **`/ep config`** lets you set wheel keybinds, turn on **Remember last Action** for the current session, and position the wheel with percentage sliders and arrows. Hover over controls for tooltips. Use **Reset to Defaults** to reset EmotePanel across all characters while keeping your WoW keybinds.

Actions and Favorites show countdown numbers on cooldowns and tint icons red when WoW reports the target is out of range. Use **Show action cooldowns** to hide the numbers. Say and Party each start with 16 quick messages, including campfire conversation starters.

With a controller, you can show, hide, reorder, and reset an entry in **Customize Entry**. The editor asks before you discard unsaved changes, and the ConsolePort cursor stays out of the way while the wheel is open.

The minimap button and **Addon Compartment** entry open the wheel with a left-click and settings with a right-click outside combat.

## Controls

| Action | Controller | Mouse or keyboard |
| --- | --- | --- |
| Select a slot | Either stick or D-pad up/down | Hover |
| Change page | LB/RB or D-pad left/right | Header arrows |
| Use the selected entry | A / Cross | Left-click |
| Add or remove a favorite | X / Square | Middle-click |
| Customize an entry | Y / Triangle | Right-click |
| Go back or close the wheel | B / Circle | Back or the close button |
| Dismiss the wheel | Start/Menu | Esc |

See the [full guide](EmotePanel/README.md) for combat behavior, customization, and every slash command. See the [changelog](CHANGELOG.md) for release details.

## AI assistance

OpenAI Codex helped develop and document the Forever port. Automated checks use a simulated WoW UI. Live behavior also depends on the client and input setup.
