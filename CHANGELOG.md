# EmotePanel Changelog

## [0.0.2] - 2024-12-26
Version 0.0.2 (Current)
Added

New settings panel with multiple tabs:

General Settings tab for basic configuration
Appearance tab for visual customization
Customization tab for button management
Help tab with comprehensive list of commands and buttons


Customizable chat messages for Say and Party chat buttons
Customizable button names
Two scrollbar styles (basic and standard UI template)
Button tooltips showing message content and customization status
Custom message indicator (*) for modified buttons
"Reset All Custom Messages" functionality
Panel position saving between sessions
Panel cycling with left arrow button
Help panel toggle with question mark button
Improved panel dragging and positioning

-Interface Updates

Redesigned main panel with UIPanelDialogTemplate
Added proper close button positioning
Implemented custom message dialog for button editing
Added tooltip system for all buttons

-System Features

SavedVariables implementation for:

Custom messages
Custom button names
Panel positions
Scrollbar style preference


Slash commands:

/ep or /emotepanel - Toggle panel
/ep scroll [on|off] - Toggle scrollbar style
/ep config - Open settings panel
/ep list - open list panel


Categories
Emotes (3 Panels)

Basic emotes (angry, applause, blush, etc.)
Social emotes (golfclap, goodbye, hug, etc.)
Additional emotes (salute, sigh, sorry, etc.)

Chat

Say chat quick messages
Party chat quick messages
Common game commands

## [0.0.1]
Basic emote panel functionality
Simple button layout
Basic slash command support