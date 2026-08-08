# Achiever
## An Achievement addon for modded vmangos server
[My modded vmangos branch homebrew/achievements is here: https://github.com/tsaah/core/tree/hb-achievements](https://github.com/tsaah/core/tree/hb-achievements)
[My achievement database editor is here: https://github.com/tsaah/achievement_editor.git](https://github.com/tsaah/achievement_editor)

[![Achiever addon](https://i.postimg.cc/Kz1WLNMy/Achiever-Summary.jpg)](https://i.postimg.cc/Kz1WLNMy/Achiever-Summary.jpg)

## Features:
- toggles by Ctrl-A binding or minimap icon
- gets character achievement and criteria updates from server
- shows achievements summary, achievements, stats and splash

## TODO and not working addon side:
- [x] stat and summary display
- [x] achievement filtering
- [x] achievement tracking
- [x] feats of strength
- [x] movable frame
- [x] missing icons on achievements
- [x] gap near main scroll bar
- [x] gap at tab buttons
- [x] no mousemove
- [x] broken minimap button
- [x] remove extra summary on statistics
- [x] tab button has incorrect highlight
- [x] statistics page categories shouldn't expand, just select
- [x] select character category by default when switched to statistics
- [x] add mouse scroll onto scrollbars
- [x] shift click on achievement to link to chat
- [x] achievement tracker
- [x] achievement filter combobox
- [x] statistics about gold should be formatted as money
- [x] statistics that is 0 should be displayed as --
- [ ] think on comparison
- [ ] game tooltip bars
- [ ] no automated icon extraction - we currently copy all the icons from wotlk - but we need to copy only used for achievements
- [ ] no patch filtering yet
- [ ] add new tab for settings
  - [ ] enable/disable addon tracking checkboxes and tracker frame
  - [ ] enable/disable filteer combobox
- [ ] colorize meta achievements
- [ ] add guild achievements support and tab
- [ ] exploration achievement criterias displayed as progress bars
- [ ] some money related achievements incorrectly display moneys
- [ ] update static addon data from server
- [ ] support localization
- [ ] hide expand button when no criteria present

## TODO and not working server side:
- [x] vmangos patch filtering on categories and achievements
- [ ] comparison events
- [ ] exploration and loremaster achievements

## TODO and not working database side:
- [ ] mask out all non relevant categories/achievements by patch
- [ ] update existing categories/achievements/criterias so they become relevant for vanilla
- [ ] add new categories/achievements/criterias relevant for vanilla
- [x] write a tool so it will help manage categories/achievements/criterias


