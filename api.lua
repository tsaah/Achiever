-- AddTrackedAchievement(achievementId) -- Add an achievement to tracking.
-- CanShowAchievementUI() -- Returns if the AchievementUI can be displayed
-- --ClearAchievementComparisonUnit() - Remove the unit being compared.
-- --GetAchievementCategory(achievementID) - Return the category number of the requested achievement.
-- --GetAchievementComparisonInfo(achievementID, comparisonNum) - Returns status of achievement for comparison player.
-- --GetAchievementCriteriaInfo(achievementID, criteriaIndex) - Returns information about the requested criteria.
-- --GetAchievementCriteriaInfoByID(achievementID, criteriaID) - Returns information about the requested criteria. (added 5.0.4)
-- --GetAchievementInfo(achievementID) or (category, offset) - Returns information about the requested Achievement.
-- GetAchievementInfoFromCriteria(id) -- Returns information about the requested Achievement.
-- GetAchievementLink(achievementID) -- Returns a achievementLink for the specified Achievement.
-- --GetAchievementNumCriteria(achievementID) - Return the number of criteria the requested Achievement has.
-- GetAchievementNumRewards(achievementID) -- Return the number of rewards the requested Achievement has.
-- --GetCategoryInfo(category) - Return information about the requested category
-- --GetCategoryList() - Returns the list of Achievement categories.
-- --GetCategoryNumAchievements(category) - Return the total Achievements and number completed for the specific category.
-- --GetComparisonAchievementPoints() - Return the total number of achievement points the comparison unit has earned.
-- --GetComparisonCategoryNumAchievements(achievementID)
-- GetComparisonStatistic(achievementID) -- Return the value of the requested statistic for the comparison player.
-- --GetLatestCompletedAchievements() - Return the ID's of the last 5 completed Achievements.
-- GetLatestCompletedComparisonAchievements()
-- GetLatestUpdatedComparisonStats()
-- GetLatestUpdatedStats() -- Return the ID's of the last 5 updated Statistics.
-- --GetNextAchievement(achievementID)
-- GetNumComparisonCompletedAchievements()
-- --GetNumCompletedAchievements([guildOnly]) - Returns total and completed number of achievements, or only guild.
-- --GetPreviousAchievement(achievementID) - Return previous related achievements.
-- GetStatistic(achievementID) -- Return the value of the requested statistic.
-- --GetStatisticsCategoryList() - Returns the list of Statistic categories.
-- --GetTotalAchievementPoints([guildOnly]) - Return the total, or only guild, achievement points earned.
-- --GetTrackedAchievements() - Return the AchievementID of the currently tracked achievements
-- --GetNumTrackedAchievements() - Return the total number of the currently tracked achievements
-- RemoveTrackedAchievement(achievementID) - Stops an achievement from being tracked
-- --SetAchievementComparisonUnit(unitId) - Set the unit to be compared to.


-- local db = CA_Database
-- local cmanager = CA_CompletionManager
-- local loc = SexyLib:Localization('Classic Achievements')

-- function SwitchAchievementSearchTab(index)
    -- db:SetSelectedTab(index)
-- end

-- local function GetCategoryList_(id)
    -- local result = {}
    -- for cid, _ in pairs(db:GetTab(id):GetCategories()) do
        -- result[#result + 1] = cid
    -- end
    -- table.sort(result)
    -- return result
-- end
function mock_GetCategoryList()
    return {'ttt', 'bbb'} --[6] = 'Categoty 6', [7] = 'Categoty 7', [8] = 'Categoty 8', [9] = 'Categoty 91', [12] = 'Categoty 12',}
end
function GetCategoryList()
    -- return GetCategoryList_(db.TAB_ID_PLAYER)
    return mock_GetCategoryList()
end

function mock_GetGuildCategoryList()
    return {} --[6] = 'Categoty 54', [7] = 'Categoty 73',}
end
function GetGuildCategoryList()
    -- return GetCategoryList_(db.TAB_ID_GUILD)
    return mock_GetGuildCategoryList()
end


function mock_GetStatisticsCategoryList()
    return {'mmm', 'fff'} -- [1] = 'Stat Categoty 1', [2] = 'Stat Categoty 2', [3] = 'Stat Categoty 3', [5] = 'Stat Categoty 5',}
end
function GetStatisticsCategoryList()
    -- return GetCategoryList_(db.TAB_ID_STATS)
    return mock_GetStatisticsCategoryList()
end

-- local function IsAchievementVisible(achievement, includeAll)
--     -- if not achievement:IsAvailable() then return false end
--     -- if includeAll then return true end
--     -- local completion = cmanager:GetLocal()
--     -- if completion:IsAchievementCompleted(achievement.id) then
--     --     local nextID = achievement:GetNextID()
--     --     if not nextID then return true end
--     --     return not completion:IsAchievementCompleted(nextID)
--     -- end
--     -- if achievement.points == 0 then return false end
--     -- local previousID = achievement:GetPreviousID()
--     -- if not previousID then return true end
--     -- return completion:IsAchievementCompleted(previousID)
-- end

function mock_GetCategoryNumAchievements(categoryID, includeAll, completion)
    local total, completed, incompleted = 2, 0, 0;
    return total, completed; --, incompleted;
end
-- total, completed, incompleted
function GetCategoryNumAchievements(categoryID, includeAll, completion)
    log('GetCategoryNumAchievements')
    -- includeAll = includeAll or false

    -- local total, completed, incompleted = 0, 0, 0

    -- local category = db:GetCategory(categoryID)
    -- local completion = completion or cmanager:GetLocal()
    -- if category then
    --     for aid, achievement in pairs(category:GetAchievements()) do
    --         if IsAchievementVisible(achievement, includeAll) then
    --             total = total + 1
    --             if completion:IsAchievementCompleted(aid) then
    --                 completed = completed + 1
    --             else
    --                 incompleted = incompleted + 1
    --             end
    --         end
    --     end
    -- end

    -- return total, completed, incompleted
    return mock_GetCategoryNumAchievements(categoryID, includeAll, completion)
end

function mock_GetCategoryInfo(categoryID)
    return 'title', -1, 0
end
-- title, parentCategoryID, flags = GetCategoryInfo(categoryID)
function GetCategoryInfo(categoryID)
    -- local category = db:GetCategory(categoryID)
    -- if category then return category.name, category.parentID, 0 end
    -- return '', -1, 0
    return mock_GetCategoryInfo(categoryID)
end

-- local function defaultAchievementOrderComparator(a, b)
--     local aPriority = a.priority or 0
--     local bPriority = b.priority or 0
--     if aPriority ~= bPriority then return aPriority < bPriority end
--     return a.id < b.id
-- end

-- id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(achievementID or categoryID, index)
-- 1	id	Number	Achievement ID.
-- 2	name	String	The Name of the Achievement.
-- 3	points	Number	Points awarded for completing this achievement.
-- 4	completed	Boolean	Returns true/false depending if you've completed this achievement on any character.
-- 5	month	Number	Month this was completed. Returns nil if Completed is false.
-- 6	day	Number	Day this was completed. Returns nil if Completed is false.
-- 7	year	Number	Year this was completed. Returns nil if Completed is false. Returns number of years since 2000.
-- 8	description	String	The Description of the Achievement.
-- 9	flags	Number	A bitfield that indicates achievement properties:
--        0x01 - Achievement is a statistic
--        0x02 - Achievement should be hidden
--        0x80 - Progress Bar
-- 10	icon	Number	The fileID of the icon used for this achievement
-- 11	rewardText	String	Text describing the reward you get for completing this achievement.
-- 12	isGuild	Boolean	Returns true/false depending if this is a guild achievement.
-- 13	wasEarnedByMe	Boolean	Returns true/false depending if you've completed this achievement on this character.
function mock_GetAchievementInfo(id, index)
    local name = 'Level 1337'
	local points = 50
	local icon = [[Interface\icons\Spell_Holy_Redemption]]
    return 6, name, points, true, 3, 3, 2021, 'done kool stuff', 1, icon, 'reward text', false, true
end
function GetAchievementInfo(id, index)
    -- local ach = nil
    -- if index then
    --     local category = db:GetCategory(id)
    --     if category then
    --         local achs = {}
    --         local completion = cmanager:GetLocal()
    --         for _, achievement in pairs(category:GetAchievements()) do
    --             if IsAchievementVisible(achievement) then
    --                 achs[#achs + 1] = achievement
    --             end
    --         end
    --         if index <= #achs then
    --             table.sort(achs, function(a, b)
    --                 local completedA, completedB = completion:IsAchievementCompleted(a.id), completion:IsAchievementCompleted(b.id)
    --                 if completedA and completedB then return defaultAchievementOrderComparator(a, b) end
    --                 if completedA then return true end
    --                 if completedB then return false end
    --                 local previousA, previousB = a:GetPreviousID(), b:GetPreviousID()
    --                 completedA = (previousA and completion:IsAchievementCompleted(previousA)) or false
    --                 completedB = (previousB and completion:IsAchievementCompleted(previousB)) or false
    --                 if completedA and completedB then return previousA < previousB end
    --                 if completedA then return true end
    --                 if completedB then return false end
    --                 return defaultAchievementOrderComparator(a, b)
    --             end)
    --             ach = achs[index]
    --         end
    --     end
    -- else
    --     ach = db:GetAchievement(id)
    -- end
    -- if ach then
    --     local completion = cmanager:GetLocal()
    --     local icon = ach.icon
    --     if strsub(icon, 1, 1) == '-' then
    --         icon = [[Interface\ICONS\]] .. strsub(icon, 2, strlen(icon))
    --     else
    --         icon = [[Interface\AddOns\ClassicAchievements\textures\icons\]] .. icon
    --     end
    --     local completed, earnedBy = false, nil
    --     local month, day, year
    --     if completion:IsAchievementCompleted(ach.id) then
    --         local time = completion:GetAchievementCompletionTime(ach.id)
    --         month, day, year = tonumber(date('%m', time)), tonumber(date('%d', time)), tonumber(date('%y', time))
    --         completed, earnedBy = true, UnitName('player')
    --     end
    --     return ach.id, ach.name, ach.points, completed, month, day, year, ach.description, ach.flags or 0, icon, ach:GetRewardText(), false, completed, earnedBy, false
    -- end
    -- return 1, '', 0, false, nil, nil, nil, '', 0, 0, '', false, false, '', false
    return mock_GetAchievementInfo(id, index)
end

function mock_GetPreviousAchievement(achievementID)
    return 0
end
function GetPreviousAchievement(achievementID)
    -- local achievement = db:GetAchievement(achievementID)
    -- if achievement then return achievement:GetPreviousID() end
    -- return nil
    return mock_GetPreviousAchievement(achievementID)
end

function mock_GetNextAchievement(achievementID)
    return nil, false
end
-- return The ID of the Achievement and whether it's completed
function GetNextAchievement(achievementID)
    -- local achievement = db:GetAchievement(achievementID)
    -- if achievement then
    --     local nextID = achievement:GetNextID()
    --     if nextID then return nextID, cmanager:GetLocal():IsAchievementCompleted(nextID) end
    -- end
    -- return nil, false
    return mock_GetNextAchievement(achievementID)
end

function mock_GetNumCompletedAchievements(inGuildView)
    return 0, 0
end
-- total, completed
function GetNumCompletedAchievements(inGuildView)
    -- local total, completed = 0, 0
    -- local completion = cmanager:GetLocal()
    -- local tab = db:GetTabSpecial(inGuildView)
    -- if tab then
    --     for _, category in pairs(tab:GetCategories()) do
    --         local t, c = GetCategoryNumAchievements(category.id, true, completion)
    --         total = total + t
    --         completed = completed + c
    --     end
    -- end
    -- return total, completed
    return mock_GetNumCompletedAchievements(inGuildView)
end

function mock_GetTrackedAchievements()
    return {}
end
-- Returns a list of (up to 10) currently tracked achievements.
function GetTrackedAchievements()
    -- return {}
    return mock_GetTrackedAchievements()
end

function mock_GetTotalAchievementPoints(inGuildView)
    return 220
end
function GetTotalAchievementPoints(inGuildView)
    -- local points = 0
    -- local completion = cmanager:GetLocal()
    -- local tab = db:GetTabSpecial(inGuildView)
    -- for _, category in pairs(tab:GetCategories()) do
    --     for _, achievement in pairs(category:GetAchievements()) do
    --         if completion:IsAchievementCompleted(achievement.id) then points = points + achievement.points end
    --     end
    -- end
    -- return points
    return mock_GetTotalAchievementPoints(inGuildView)
end

function mock_GetAchievementCategory(achievementID)
    return -1
end
function GetAchievementCategory(achievementID)
    -- local tab = db:GetSelectedTab()
    -- for cid, category in pairs(tab:GetCategories()) do
    --     for id, achievement in pairs(category:GetAchievements()) do
    --         if id == achievementID then return cid end
    --     end
    -- end
    -- return -1
    return mock_GetAchievementCategory(achievementID)
end

function mock_GetLatestCompletedAchievements(inGuildView)
    return
end
-- Return the ID's of the last 5 completed Achievements.
function GetLatestCompletedAchievements(inGuildView)
    -- local result = {}
    -- local completion = cmanager:GetLocal()
    -- local tab = db:GetTabSpecial(inGuildView)
    -- if tab then
    --     for _, category in pairs(tab:GetCategories()) do
    --         for _, achievement in pairs(category:GetAchievements()) do
    --             if completion:IsAchievementCompleted(achievement.id) then
    --                 result[#result + 1] = achievement
    --             end
    --         end
    --     end
    -- end
    -- if #result == 0 then return end
    -- if #result == 1 then return result[1].id end
    -- table.sort(result, function(a, b)
    --     local delta = completion:GetAchievementCompletionTime(a.id) - completion:GetAchievementCompletionTime(b.id)
    --     if delta ~= 0 then return delta > 0 end
    --     return a.id > b.id
    -- end)
    -- local res = {}
    -- for _, achievement in pairs(result) do
    --     res[#res + 1] = achievement.id
    --     if #res == 5 then break end
    -- end
    -- if #res == 2 then return res[1], res[2] end
    -- if #res == 3 then return res[1], res[2], res[3] end
    -- if #res == 4 then return res[1], res[2], res[3], res[4] end
    -- return res[1], res[2], res[3], res[4], res[5]
    return mock_GetLatestCompletedAchievements(inGuildView)
end

function mock_GetAchievementGuildRep()
    return false, false, 0
end
function GetAchievementGuildRep()
    -- return false, false, 0
    return mock_GetAchievementGuildRep()
end

function mock_IsTrackedAchievement()
    return false
end
function IsTrackedAchievement()
    -- return false
    return mock_IsTrackedAchievement()
end

function mock_SetFocusedAchievement(achievementID)
end
function SetFocusedAchievement(achievementID)
    mock_SetFocusedAchievement(achievementID)
end

-- local function _GetAchievementCriteria(aid, c)
    -- if not c or not c.name then
    --     return '', 0, false, 0, 0, '', 0, 0, '', 0, false, 0, 0
    -- end
    -- local completion = cmanager:GetLocal()
    -- local quantity = completion:GetCriteriaProgression(aid, c.id)
    -- local requiredQuantity = c.quantity
    -- local quantityStr = nil
    -- if requiredQuantity then
    --     if c.quantityFormat then
    --         quantityStr = c.quantityFormat(quantity, requiredQuantity)
    --     else
    --         quantityStr = quantity .. ' / ' .. requiredQuantity
    --     end
    -- end
    -- local assetID = 0
    -- if c.data and c.data[1] then assetID = c.data[1] end
    -- return c.name, c.type, completion:IsCriteriaCompleted(aid, c.id), quantity, requiredQuantity, '', c.flags, assetID, quantityStr, c.id, true, 0, 0
-- end

function mock_GetAchievementCriteriaInfo(achievementID, criteriaIndex)
    return 'Criteria X', 6, false, 12, 32, 'Bebebe', 1, 4, 'some quantyty', 6, true, 0, 0
end
-- criteriaString, criteriaType, completed, quantity, reqQuantity,
--  charName, flags, assetID, quantityString, criteriaID, eligible =
--    GetAchievementCriteriaInfo(achievementID, criteriaIndex [, countHidden])
function GetAchievementCriteriaInfo(achievementID, criteriaIndex)
    -- local achievement = db:GetAchievement(achievementID)
    -- if achievement then
    --     local criterias = achievement:GetCriteriasSorted()
    --     if criteriaIndex <= #criterias then
    --         return _GetAchievementCriteria(achievementID, criterias[criteriaIndex])
    --     end
    -- end
    -- return _GetAchievementCriteria()
    return mock_GetAchievementCriteriaInfo(achievementID, criteriaIndex)
end

function mock_GetAchievementCriteriaInfoByID(achievementID, criteriaID)
    return 'Criteria X', 7, false, 33, 90, 'Bebebe', 1, 0, 'some quantyty', 6, true, 0, 0
end
function GetAchievementCriteriaInfoByID(achievementID, criteriaID)
    -- local achievement = db:GetAchievement(achievementID)
    -- if achievement then
    --     return _GetAchievementCriteria(achievementID, achievement:GetCriteria(criteriaID))
    -- end
    -- return _GetAchievementCriteria()
    return mock_GetAchievementCriteriaInfoByID(achievementID, criteriaID)
end

function mock_GetAchievementNumCriteria(achievementID)
    return 1
end
function GetAchievementNumCriteria(achievementID)
    -- local total = 0
    -- local achievement = db:GetAchievement(achievementID)
    -- if achievement then
    --     for _, criteria in pairs(achievement:GetCriterias()) do
    --         if criteria.name then total = total + 1 end
    --     end
    -- end
    -- return total
    return mock_GetAchievementNumCriteria(achievementID)
end

function mock_ClearAchievementComparisonUnit()
end
function ClearAchievementComparisonUnit()
    mock_ClearAchievementComparisonUnit()
end

function mock_SetAchievementComparisonUnit(unit)
end
function SetAchievementComparisonUnit(unit)
    mock_SetAchievementComparisonUnit(unit)
end

function mock_GetAchievementComparisonInfo(id)
    return false, nil, nil, nil
end
-- return completed, month, day, year
function GetAchievementComparisonInfo(id)
    -- local completion = cmanager:GetTarget()
    -- if not completion:IsAchievementCompleted(id) then
    --     return false, nil, nil, nil
    -- else
    --     local time = completion:GetAchievementCompletionTime(id)
    --     local month, day, year = tonumber(date('%m', time)), tonumber(date('%d', time)), tonumber(date('%y', time))
    --     return true, day, month, year
    -- end
    return mock_GetAchievementComparisonInfo(id)
end

function mock_GetComparisonCategoryNumAchievements(categoryID, includeAll)
    return {}
end
function GetComparisonCategoryNumAchievements(categoryID, includeAll)
    -- local _, completed = GetCategoryNumAchievements(categoryID, includeAll, cmanager:GetTarget())
    -- return completed
    return mock_GetComparisonCategoryNumAchievements(categoryID, includeAll)
end

function mock_GetComparisonAchievementPoints()
    return 0
end
function GetComparisonAchievementPoints()
    -- local points = 0
    -- local completion = cmanager:GetTarget()
    -- local tab = db:GetTab(db.TAB_ID_PLAYER)
    -- for _, category in pairs(tab:GetCategories()) do
    --     for _, achievement in pairs(category:GetAchievements()) do
    --         if completion:IsAchievementCompleted(achievement.id) then points = points + achievement.points end
    --     end
    -- end
    -- return points
    return mock_GetComparisonAchievementPoints()
end

function mock_GetNumTrackedAchievements()
    return 0
end
function GetNumTrackedAchievements()
    -- return 0
    return mock_GetNumTrackedAchievements()
end

-- local lastSearchResult = {}

function mock_SetAchievementSearchString(text)
    return true
end
function SetAchievementSearchString(text)
    -- text = string.lower(text)
    -- lastSearchResult = {}
    -- for _, category in pairs(db:GetSelectedTab():GetCategories()) do
    --     for _, ach in pairs(category:GetAchievements()) do
    --         if string.find(string.lower(ach.name), text) and IsAchievementVisible(ach) then lastSearchResult[#lastSearchResult + 1] = ach end
    --     end
    -- end
    -- local completion = cmanager:GetLocal()
    -- table.sort(lastSearchResult, function(a, b)
    --     local completedA, completedB = completion:IsAchievementCompleted(a.id), completion:IsAchievementCompleted(b.id)
    --     if completedA and completedB then return a.id < b.id end
    --     if completedA then return true end
    --     if completedB then return false end
    --     return a.id < b.id
    -- end)
    -- return true
    return mock_SetAchievementSearchString(text)
end

function mock_GetNumFilteredAchievements()
    return 0
end
function GetNumFilteredAchievements()
    -- return #lastSearchResult
    return mock_GetNumFilteredAchievements()
end

function GetFilteredAchievementID(index)
    return 0
end
function GetFilteredAchievementID(index)
    -- return lastSearchResult[index].id
    return mock_GetFilteredAchievementID(index)
end

-- AchievementAlertSystem.canShowMoreConditionFunc = function() return true end
