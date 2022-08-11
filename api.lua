local _G, _ = _G or getfenv()
local function debug(msg)
	-- DEFAULT_CHAT_FRAME:AddMessage('|cffc663fcDEBUG: |cffff55ff'.. (msg or 'nil'))
end
local function warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf3f3f66cWARN: |cffff55ff'.. (msg or 'nil'))
end
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

function AchievementCategoryButton_Localize(button)

end


local function IsAchievementCompleted(id)
    local achievementCompletion = achieverDBpc.achievements[tonumber(id)]
    local completed = false
    if (achievementCompletion) then
        completed = true;
    else
        completed = false;
    end
    return completed;
end

local function GetPreviousID(id)
    return achieverDB.achievements.previousById[tonumber(id)]
end

local function GetNextID(id)
    return achieverDB.achievements.nextById[tonumber(id)]
end

local function IsAchievementVisible(id, includeAll)
    if (not id) then return false end
    if (includeAll) then return true end
    if (IsAchievementCompleted(id)) then
        local nextId = GetNextID(id)
        if (not nextId) then return true end
        return not IsAchievementCompleted(nextId)
    end
    if (achieverDB.achievements.data[id].points == 0) then return false end
    local previousId = GetPreviousID(id)
    if (not previousId) then return true end
    return IsAchievementCompleted(previousId)
end

local function defaultAchievementOrderComparator(a, b)
    local aOrder = a.order or 0
    local bOrder = b.order or 0
    if (aOrder ~= bOrder) then return aOrder < bOrder end
    return a.id < b.id
end

local function GetCategory(categotyId)
    return achieverDB.categories.data[categotyId];
end

local function GetAchievement(achievementId)
    return achieverDB.achievements.data[achievementId];
end

local function GetAchievementCompletionTime(achievementId)
    return achieverDBpc.achievements[achievementId].date;
end

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
-- function mock_GetAchievementInfo(id, index)
--     local name = 'Level 1337'
-- 	local points = 50
-- 	local icon = [[Interface\icons\Spell_Holy_Redemption]]
--     return 6, name, points, true, 3, 3, 2021, 'done kool stuff', 1, icon, 'reward text', false, true
-- end
function GetAchievementInfo(id, index, includeAll)
    local ach = nil
    local playerAch = nil
    local all = includeAll or false
    if (index) then
        local category = GetCategory(id)
        if (category) then
            local achs = {}
            for _, aid in pairs(achieverDB.achievements.byCategory[tonumber(id)]) do
                if IsAchievementVisible(aid, all) then
                    table.insert(achs, GetAchievement(aid))
                end
            end
            if index <= getn(achs) then
                table.sort(achs, function(a, b)
                    local completedA, completedB = IsAchievementCompleted(a.id), IsAchievementCompleted(b.id)
                    if (completedA and completedB) then return defaultAchievementOrderComparator(a, b) end
                    if (completedA) then return true end
                    if (completedB) then return false end
                    local previousA, previousB = GetPreviousID(a.id), GetPreviousID(b.id)
                    completedA = (previousA and IsAchievementCompleted(previousA)) or false
                    completedB = (previousB and IsAchievementCompleted(previousB)) or false
                    if (completedA and completedB) then return previousA < previousB end
                    if (completedA) then return true end
                    if (completedB) then return false end
                    return defaultAchievementOrderComparator(a, b)
                end)
                ach = achs[index]
            end
        end
    else
        ach = GetAchievement(id)
    end
    if (ach) then
        local icon = ach.icon
        local completed, earnedBy = false, nil
        local month, day, year
        local reward = ''
        if (ach.titleReward ~= '0') then reward = ach.titleReward; end
        if (IsAchievementCompleted(ach.id)) then
            debug('GetAchievementInfo '.. ach.id)
            local time = GetAchievementCompletionTime(ach.id)
            month, day, year = tonumber(date('%m', time)), tonumber(date('%d', time)), tonumber(date('%y', time))
            -- local month, day, year = playerAch.month, playerAch.day, playerAch.year
            completed, earnedBy = true, UnitName('player')

        end
        return ach.id, ach.name, ach.points, completed, month, day, year, ach.description, ach.flags or 0, icon, reward, false, completed, earnedBy, false
    end
    return 1, 'INVALID ACHIEVEMENT', 0, false, nil, nil, nil, '', 0, 0, '', false, false, '', false
end

function GetCategoryList()
    local result = {}

    for id, v in pairs(achieverDB.categories.data) do
        if (id ~= 1 and v.parentId ~= 1) then
            table.insert(result, id)
        end
    end

    table.sort(result)
    return result
end

-- category (number) - AchievementID of a statistic or statistic category.
function GetStatistic(id)
    local value = 0
    local criteriaIdList = achieverDB.criteria.byAchievement[id]
    if (criteriaIdList) then
        if (table.getn(criteriaIdList) >= 1) then
            local cCriteria = achieverDBpc.criteria[criteriaIdList[1]]
            if (cCriteria) then
                value = achieverDBpc.criteria[criteriaIdList[1]].counter
            end
        end
    end

    return value
end

function GetStatisticsCategoryList()
    local result = {}
    local rootStatCategoryIdList = achieverDB.categories.byParent['1'];
    for i, v in pairs(rootStatCategoryIdList) do
        table.insert(result, v)
        local subStatCategoryIdList = achieverDB.categories.byParent[tostring(v)];
        if (subStatCategoryIdList) then
            for ii, vv in pairs(subStatCategoryIdList) do
                table.insert(result, vv)
            end
        end
    end
    table.sort(result)
    return result
end

-- title, parentCategoryID, flags = GetCategoryInfo(categoryID)
function GetCategoryInfo(categoryID)
    local category = GetCategory(categoryID)
    if (category) then return category.name, category.parentId, category.order end
    return '', -1, 0
end

-- total, completed, incompleted
function GetCategoryNumAchievements(categoryID, includeAll, completion)
    local id = categoryID
    if (id == -2) then
        id = 1;
    end



    includeAll = includeAll or false

    local total, completed, incompleted = 0, 0, 0

    local category = achieverDB.categories.data[tonumber(id)];
    if (category) then
        local achievements = achieverDB.achievements.byCategory[category.id]
        if (achievements) then
            -- debug('GetCategoryNumAchievements ' .. table.getn(achievements))
            for _, aid in pairs(achievements) do
                if (IsAchievementVisible(aid, includeAll)) then
                    total = total + 1
                    if (IsAchievementCompleted(aid)) then
                        completed = completed + 1
                    else
                        incompleted = incompleted + 1
                    end
                end
            end
        end
    end

    return total, completed, incompleted
end

function GetPreviousAchievement(achievementID)
    return GetPreviousID(achievementID)
end

-- return The ID of the Achievement and whether it's completed
function GetNextAchievement(achievementID)
    local nextID = GetNextID(achievementID)
    if (nextID) then return nextID, IsAchievementCompleted(nextID) end
    return nil, false
end

-- total, completed
function GetNumCompletedAchievements(inGuildView)
    local completed = 0
    for _ in pairs(achieverDBpc.achievements) do completed = completed + 1 end

    local total = 0;
    for _ in pairs(achieverDB.achievements.data) do total = total + 1 end
    return total, completed
end

-- Returns a list of (up to 10) currently tracked achievements.
function GetTrackedAchievements()
    return {}
end

function GetTotalAchievementPoints(inGuildView)
    local points = 0
    for id, _ in pairs(achieverDBpc.achievements) do
        points = points + achieverDB.achievements.data[id].points
    end
    return points
end

function GetAchievementCategory(achievementID)
    local achievement = achieverDB.achievements.data[achievementID]
    if (not achievement) then return -1 end
    return achievement.categoryId
end

-- Return the ID's of the last 5 completed Achievements.
function GetLatestCompletedAchievements(inGuildView)

    local completedAchievemenIdHash = {}
    local count = 0
    for k, v in pairs(achieverDBpc.achievements) do
        count = count + 1
        completedAchievemenIdHash[count] = k
    end
    if (count == 0) then return end
    if (count == 1) then return completedAchievemenIdHash[1] end
    table.sort(completedAchievemenIdHash, function(a, b)
        local delta = achieverDBpc.achievements[a].date - achieverDBpc.achievements[b].date
        if (delta ~= 0) then return delta > 0 end
        return a > b
    end)
    local res = {}
    local resCount = 0
    for _, achievementId in pairs(completedAchievemenIdHash) do
        resCount = resCount + 1
        res[resCount] = achievementId
        if (resCount == 5) then break end
    end
    if (resCount == 2) then return res[1], res[2] end
    if (resCount == 3) then return res[1], res[2], res[3] end
    if (resCount == 4) then return res[1], res[2], res[3], res[4] end
    return res[1], res[2], res[3], res[4], res[5]
end

function GetAchievementGuildRep()
    return false, false, 0
end

function IsTrackedAchievement()
    return false
end

function SetFocusedAchievement(achievementID)

end

local function _GetAchievementCriteria(aid, c)
    -- if (not c or not c.name) then
    --     return '', 0, false, 0, 0, '', 0, 0, '', 0, false, 0, 0
    -- end
    -- local criteria = achieverDB.criteria.data[]
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
end

-- criteriaString, criteriaType, completed, quantity, reqQuantity,
--  charName, flags, assetID, quantityString, criteriaID, eligible =
--    GetAchievementCriteriaInfo(achievementID, criteriaIndex [, countHidden])
function GetAchievementCriteriaInfo(achievementID, criteriaIndex)

    local pCriteria = nil
    local criteria = nil
    local criteriaIdList = achieverDB.criteria.byAchievement[achievementID]
    local criteriaID = nil
    if (criteriaIdList) then
        criteriaId = criteriaIdList[criteriaIndex]
        if (criteriaId) then
            criteria = achieverDB.criteria.data[criteriaId]
            pCriteria = achieverDBpc.criteria[criteriaId]
        end
        if (not criteriaId or not criteria) then
            return 'INVALID CRITERIA', 0, false, 0, 0, '', 0, 0, '', 0
        end
    end

    local name = criteria.name
    local criteriaType = criteria.type
    local quantity = 0
    local reqQuantity = criteria.count
    local completed = false
    local charName = UnitName('player')
    local quantityString = ''
    local flags = criteria.flags
    local assetId = criteria.assetId

    if (pCriteria) then
        quantity = pCriteria.counter
        completed = reqQuantity == quantity
        quantityStr = quantity .. ' / ' .. reqQuantity
    end

    return name, criteriaType, completed, quantity, reqQuantity, charName, flags, assedId, quantityString, criteriaId
    -- local achievement = GetAchievement(achievementID)
    -- if (achievement) then
    --     local criterias = achievement:GetCriteriasSorted()
    --     local criteriaCount = table.getn(criterias)
    --     if (criteriaIndex <= criteriaCount) then
    --         return _GetAchievementCriteria(achievementID, criterias[criteriaIndex])
    --     end
    -- end
    -- return _GetAchievementCriteria()
end

function GetAchievementCriteriaInfoByID(achievementID, criteriaID)
    -- local achievement = db:GetAchiev[ement(achievementID)
    -- if achievement then
    --     return _GetAchievementCriteria(achievementID, achievement:GetCriteria(criteriaID))
    -- end
    -- return _GetAchievementCriteria()
end

function GetAchievementNumCriteria(achievementID)
    local total = 0
    local achievement = achieverDB.achievements.data[achievementID]
    if (achievement) then
        local criteriaList = achieverDB.criteria.byAchievement[achievementID]
        if (criteriaList) then
            for _, criteriaId in pairs(achieverDB.criteria.byAchievement[achievementID]) do
                local criteria = achieverDB.criteria.data[criteriaId];
                if (criteria) then
                    if (criteria.name) then total = total + 1 end
                end
            end
        end
    end
    return total
end

function ClearAchievementComparisonUnit()

end

function SetAchievementComparisonUnit(unit)

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
end

function GetComparisonCategoryNumAchievements(categoryID, includeAll)
    -- local _, completed = GetCategoryNumAchievements(categoryID, includeAll, cmanager:GetTarget())
    -- return completed
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
end

function GetNumTrackedAchievements()
    return 0
end

local lastSearchResult = {}

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
end

function GetNumFilteredAchievements()
    return table.getn(lastSearchResult)
end

function GetFilteredAchievementID(index)
    return lastSearchResult[index].id
end