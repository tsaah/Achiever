-- Locale strings the achievement UI references that don't exist in 1.12's
-- client strings at all (achievements didn't exist yet). Real WotLK 3.3.5
-- enUS text, pulled from Blizzard's FrameXML\GlobalStrings.lua.

-- Display strings for Bindings.xml's "ACHIEVER_TOGGLE" binding: the Key
-- Bindings UI looks these up by name (BINDING_HEADER_<header> for the
-- section title, BINDING_NAME_<name> for the action label) and falls back
-- to the raw XML attribute text if they're missing.
BINDING_HEADER_ACHIEVER = "Achiever";
BINDING_NAME_ACHIEVER_TOGGLE = "Toggle Achievements Window";

ACHIEVEMENT_SUMMARY_CATEGORY = "Summary";
FEAT_OF_STRENGTH_DESCRIPTION = "Feats of Strength are accomplishments that players will find very difficult if not impossible to earn.  Worth no points, Feats of Strength are a collection of past glories on Azeroth.";
ACHIEVEMENTS_COMPLETED_CATEGORY = "%s Achievements Earned";
ACHIEVEMENTFRAME_FILTER_ALL = "All";
ACHIEVEMENTFRAME_FILTER_COMPLETED = "Earned";
ACHIEVEMENTFRAME_FILTER_INCOMPLETE = "Incomplete";
SHORTDATE = "%1$d/%2$02d/%3$02d";
ACHIEVEMENT_WATCH_TOO_MANY = "You may only track %d achievements at a time.";
ERR_ACHIEVEMENT_WATCH_COMPLETED = "This achievement has already been completed.";
SUMMARY_ACHIEVEMENT_INCOMPLETE = "Achievement Incomplete";
SUMMARY_ACHIEVEMENT_INCOMPLETE_TEXT = "Satisfy the requirements for each achievement to gain points, rewards, and glory!";
INCOMPLETE = "Incomplete";
ACHIEVEMENTS = "Achievements";
ACHIEVEMENTS_COMPLETED = "Achievements Earned";
ACHIEVEMENT_CATEGORY_PROGRESS = "Progress Overview";
ACHIEVEMENT_TITLE = "Achievement Points";
LATEST_UNLOCKED_ACHIEVEMENTS = "Recent Achievements";
NO_COMPLETED_ACHIEVEMENTS = "You have not earned any achievements recently";
STATISTICS = "Statistics";
TRACK_ACHIEVEMENT = "Track";
TRACK_ACHIEVEMENT_TOOLTIP = "Check to track this achievement.";
UNTRACK_ACHIEVEMENT_TOOLTIP = "Uncheck to stop tracking this achievement.";
ACHIEVEMENT_META_COMPLETED_DATE = "Completed %s";
ACHIEVEMENT_UNLOCKED = "Achievement Earned";

-- Achiever's own UI chrome text (not ported from Blizzard -- these don't
-- exist anywhere in WotLK's GlobalStrings.lua) -- centralized here the same
-- way so a locale-override addon (e.g. Achiever-zhCN) can overwrite them by
-- name, same as the strings above.
ACHIEVER_TRACKER_HEADER = "Tracked Achievements";
ACHIEVER_TRACKER_ROW_TOOLTIP = "Left-click to view. Right-click to stop tracking.";
ACHIEVER_TRACKER_LOCK_TOOLTIP = "Lock tracker position";
ACHIEVER_MINIMAP_TOOLTIP_TITLE = "Achiever";
ACHIEVER_MINIMAP_TOOLTIP_LINE1 = "Left-click to toggle achievements.";
ACHIEVER_MINIMAP_TOOLTIP_LINE2 = "Shift-drag to move this button.";
ACHIEVER_LOADED_MESSAGE = "|cffffd200Achiever|r addon %s is running %s mode.";
ACHIEVER_HANDSHAKE_SENT_MESSAGE = "|cffffd200Achiever|r: handshake sent on channel %s (index %d).";
ACHIEVER_WARN_NO_ACHIEVEMENT_ID = "provide an achievement id";
ACHIEVER_WARN_NO_ACHIEVEMENT_WITH_ID = "no achievement with id %s";
ACHIEVER_INVALID_ACHIEVEMENT_NAME = "INVALID ACHIEVEMENT";

ACHIEVER_OPTIONS_TAB_LABEL = "Options";
ACHIEVER_DEBUG_MODE_LABEL = "Debug Mode";
ACHIEVER_SHOW_PATCH_LABEL = "Show patch on achievements";
ACHIEVER_FORCE_PATCH_LABEL = "Force patch";
ACHIEVER_FORCE_PATCH_AUTO = "Auto (server-reported)";
ACHIEVER_LANGUAGE_LABEL = "Language";
ACHIEVER_LANGUAGE_DEFAULT = "Default (English)";

-- Summary tab's 8 fixed root-category progress bars (AchievementUI.xml
-- $parentCategory1..8) -- addon-defined dashboard labels, not achievement/
-- category database text, so they belong here rather than behind
-- GetCategoryInfo's live DB lookup. English text matches this server's
-- current Data/Categories.lua root-category names exactly (ids
-- 92/96/97/95/168/169/201/155).
ACHIEVER_SUMMARY_CATEGORY_GENERAL = "General";
ACHIEVER_SUMMARY_CATEGORY_QUESTS = "Quests";
ACHIEVER_SUMMARY_CATEGORY_EXPLORATION = "Exploration";
ACHIEVER_SUMMARY_CATEGORY_PVP = "Player vs. Player";
ACHIEVER_SUMMARY_CATEGORY_DUNGEONS_AND_RAIDS = "Dungeons & Raids";
ACHIEVER_SUMMARY_CATEGORY_PROFESSIONS = "Professions";
ACHIEVER_SUMMARY_CATEGORY_REPUTATION = "Reputation";
ACHIEVER_SUMMARY_CATEGORY_WORLD_EVENTS = "World Events";
