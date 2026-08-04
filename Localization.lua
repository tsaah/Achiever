-- Real WotLK enUS locale hooks -- empty no-ops in the enUS client itself
-- (only overridden by non-English locale files), ported here just so the
-- ~5 call sites in AchievementUI.lua have something to call.

function AchievementFrameSummary_LocalizeButton (button)
end

function AchievementButton_LocalizeMiniAchievement (frame)
end

function AchievementButton_LocalizeProgressBar (frame)
end

function AchievementButton_LocalizeMetaAchievement (frame)
end

function AchievementFrame_LocalizeCriteria (frame)
end
