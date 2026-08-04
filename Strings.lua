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
SHORTDATE = "%2$d/%1$02d/%3$02d";
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
