
-- cache.TAB_ID_PLAYER = 1
-- cache.TAB_ID_GUILD = 2
-- cache.TAB_ID_STATS = 3

-- cache.CTYPE_KILL_NPC = 1

-- cache.selectedTab = cache.TAB_ID_PLAYER

-- local lastAchievementID, lastCategoryID = 0, 0
local function log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf33333fcui: |cffff55ff'.. (msg or 'nil'))
end


Achiever.createCriteria = function(id, achievementId, type, assetId, quantity, startEvent, startAsset, failEvent, failAsset, descryptions, descriptionMask, flags, timerStartEvent, timerAssetId, timerTime, uiOrder)
    return {
        id, achievementId, type, assetId, quantity, startEvent, startAsset, failEvent, failAsset, descryptions, descriptionMask, flags, timerStartEvent, timerAssetId, timerTime, uiOrder,
    }
end


Achiever.createAchievement = function(id, faction, instanceId, supercedes, titles, titleMask, descriptions, descriptionMask,
    category, points, uiOrder, flags, iconId, rewards, rewardMask, minimumCriteria, sharesCriteria)
    if (supercedes ~= 0) then Achiever.cache.achievements[supercedes].nextAchievement = id end
    local result = {
        id = id, faction = faction, instanceId = instanceId, supercedes = supercedes,
        titles = titles, title = titles[1], titleMask=titleMask, descriptions=descriptions, description = descriptions[1], descriptionMask=descriptionMask,
        category=category, points=points, uiOrder=uiOrder, flags=flags, iconId=iconId, rewards=rewards, reward = rewards[1], rewardMask=rewardMask, minimumCriteria=minimumCriteria, sharesCriteria=sharesCriteria,
        nextAchievement=0,
        criterias = {},
        criteriasSorted = {},
        -- AddCriteria = function(self, id, achievementId, type, assetId, quantity, startEvent, startAsset, failEvent, failAsset, descryptions, descriptionMask, flags, timerStartEvent, timerAssetId, timerTime, uiOrder)
        --     local result = Criteria(id, achievementId, type, assetId, quantity, startEvent, startAsset, failEvent, failAsset, descryptions, descriptionMask, flags, timerStartEvent, timerAssetId, timerTime, uiOrder)
        --     self.criterias[result.id] = result
        --     self.criteriasSorted[getn(self.criteriasSorted) + 1] = criteria
        --     return result
        -- end,
        GetCriteria = function(self, id)
            return self.criterias[id]
        end,
        GetCriterias = function(self)
            return self.criterias
        end,
        GetCriteriasSorted = function(self)
            return self.criteriasSorted
        end,
        SetNext = function(self, achievement)
            self.nextID = achievement.id
            achievement.previousID = self.id
        end,
        GetNextID = function(self)
            return self.nextID or nil
        end,
        GetPreviousID = function(self)
            return self.previousID or nil
        end,
        SetRewardText = function(self, text)
            self.rewardText = text
        end,
        GetRewardText = function(self)
            return self.rewardText or nil
        end,
        SetHordeOnly = function(self)
            self.faction = true
            if not self:IsFactionValid() then self:deactivateCriterias() end
        end,
        SetAllianceOnly = function(self)
            self.faction = false
            if not self:IsFactionValid() then self:deactivateCriterias() end
        end,
        SetUnavailable = function(self)
            self.unavailable = true
            self:deactivateCriterias()
        end,
        SetAnyCompletable = function(self)
            self.anyCompletable = trueGetAchievements
        end,
        IsAnyCompletable = function(self)
            return self.anyCompletable or false
        end,
        IsFactionValid = function(self)
            return self.faction == nil or self.faction == (UnitFactionGroup('player') == 'Horde')
        end,
        IsAvailable = function(self)
            return self.unavailable ~= true and self:IsFactionValid()
        end,
        deactivateCriterias = function(self)
            for _, criteria in pairs(self.criterias) do
                criteria.deactivated = true
            end
        end
    }
    return result
end


Achiever.createCategory = function(id, parentID, names, uiOrder)
    local name = names[1]
    local result = {
        id = id,
        parentID = parentID or -1,
        names = names,
        name = names[1],
        nameMask = nameMask,
        uiOrder = uiOrder,
        achievements = {},
        -- CreateAchievement = function(self, id, faction, instanceId, supercedes, titles, titleMask, descriptions, descriptionMask,
        --     category, points, uiOrder, flags, iconId, rewards, rewardMask, minimumCriteria, sharesCriteria)
        --     local result = Achievement(id, faction, instanceId, supercedes, titles, titleMask, descriptions, descriptionMask,
        --     category, points, uiOrder, flags, iconId, rewards, rewardMask, minimumCriteria, sharesCriteria)
        --     achievements[result.id] = result
        --     return result
        -- end,
        GetAchievement = function(self, id)
            return this.achievements[id]
        end,
        GetAchievements = function(self)
            return this.achievements
        end
    }
    return result
end

-- function initCache()
--     log('test')
--     for id, v in pairs(G_achievementCategory) do
--         cache.categories[id] = Category(v[1], v[2], { v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14], v[15], v[16], v[17], v[18] }, v[19], v[20] )
--     end
--     for id, v in pairs(G_achievement) do
--         local result = Achievement(v[1], v[2], v[3], v[4],
--             { v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14], v[15], v[16], v[17], v[18], v[19], v[20] }, v[21],
--             { v[22], v[23], v[24], v[25], v[26], v[27], v[28], v[29], v[30], v[31], v[32], v[33], v[34], v[35], v[36], v[37] }, v[38],
--             v[39], v[40], v[41], v[42], v[43],
--             { v[44], v[45], v[46], v[47], v[48], v[49], v[50], v[51], v[52], v[53], v[54], v[55], v[56], v[57], v[58], v[59] }, v[60],
--             v[61], v[62]
--         )
--         -- cache.categories[result.category].achievements[result.id] = result
--     end
--     -- for id, v in pairs(G_achievementCriteria) do
--     --     local result = cache.achievements[v[2]].AddCriteria(v[1], v[2], { v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13], v[14], v[15], v[16], v[17], v[18] }, v[19], v[20] )
--     -- end
-- end

-- function GetCategoryList()
--     if (not cache.cachedCategoryList) then
--         cache.cachedCategoryList = {}
--         for id,entry in pairs(G_achievementCategory) do
--             if (entry[2] ~= 1) then
--                 table.insert(cache.cachedCategoryList, id)
--             end
--         end
--     end
--     -- return mock_GetCategoryList()
--     return cache.cachedCategoryList
-- end

-- function GetGuildCategoryList()
--     return {}
-- end

-- function GetStatisticsCategoryList()
--     if (not cache.cachedStatisticsCategoryList) then
--         cache.cachedStatisticsCategoryList = {}
--         for id,entry in pairs(G_achievementCategory) do
--             if (entry[2] == 1) then
--                 table.insert(cache.cachedStatisticsCategoryList, id)
--             end
--         end
--     end
--     return cache.cachedStatisticsCategoryList
-- end

-- -- total, completed, incompleted
-- function GetCategoryNumAchievements(categoryID, includeAll, completion)
--     includeAll = includeAll or false

--     local total, completed, incompleted = 0, 0, 0

--     local category = getCategory(categoryID)
--     local completion = completion or cache.completion.completed[id]
--     if category then
--         for aid, achievement in pairs(G_achievement) do
--             if (achievement[2] == categoryID) then
--     --         if IsAchievementVisible(achievement, includeAll) then
--     --             total = total + 1
--     --             if completion:IsAchievementCompleted(aid) then
--     --                 completed = completed + 1
--     --             else
--     --                 incompleted = incompleted + 1
--     --             end
--     --         end
--             end
--         end
--     end

--     return total, completed, incompleted
-- end

-- function GetCategoryInfo(categoryID)
--     local entry = G_achievementCategory[categoryID]
--     if (not entry) then return '', -1, 0 end
--     local title = entry[3]
--     local parentCategoryID = entry[2]
--     local flags = entry[19]
--     return title, parentCategoryID, flags
-- end

-- -- id, name, points, completed, month, day, year, description, flags, icon, rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(achievementID or categoryID, index)
-- -- 1	id	Number	Achievement ID.
-- -- 2	name	String	The Name of the Achievement.
-- -- 3	points	Number	Points awarded for completing this achievement.
-- -- 4	completed	Boolean	Returns true/false depending if you've completed this achievement on any character.
-- -- 5	month	Number	Month this was completed. Returns nil if Completed is false.
-- -- 6	day	Number	Day this was completed. Returns nil if Completed is false.
-- -- 7	year	Number	Year this was completed. Returns nil if Completed is false. Returns number of years since 2000.
-- -- 8	description	String	The Description of the Achievement.
-- -- 9	flags	Number	A bitfield that indicates achievement properties:
-- --        0x01 - Achievement is a statistic
-- --        0x02 - Achievement should be hidden
-- --        0x80 - Progress Bar
-- -- 10	icon	Number	The fileID of the icon used for this achievement
-- -- 11	rewardText	String	Text describing the reward you get for completing this achievement.
-- -- 12	isGuild	Boolean	Returns true/false depending if this is a guild achievement.
-- -- 13	wasEarnedByMe	Boolean	Returns true/false depending if you've completed this achievement on this character.
-- -- function mock_GetAchievementInfo(id, index)
-- --     local name = 'Level 1337'
-- -- 	local points = 50
-- -- 	local icon = [[Interface\icons\Spell_Holy_Redemption]]
-- --     return 6, name, points, true, 3, 3, 2021, 'done kool stuff', 1, icon, 'reward text', false, true
-- -- end
-- function GetAchievementInfo(id, index)
--     local ach = nil
--     if index then
--         local category = G_achievementCategory(id)
--         if category then
--             local achs = {}
--             local completion = cache.completion.completed[id]
--     --         local completion = cmanager:GetLocal()
--     --         for _, achievement in pairs(category:GetAchievements()) do
--     --             if IsAchievementVisible(achievement) then
--     --                 achs[#achs + 1] = achievement
--     --             end
--     --         end
--     --         if index <= #achs then
--     --             table.sort(achs, function(a, b)
--     --                 local completedA, completedB = completion:IsAchievementCompleted(a.id), completion:IsAchievementCompleted(b.id)
--     --                 if completedA and completedB then return defaultAchievementOrderComparator(a, b) end
--     --                 if completedA then return true end
--     --                 if completedB then return false end
--     --                 local previousA, previousB = a:GetPreviousID(), b:GetPreviousID()
--     --                 completedA = (previousA and completion:IsAchievementCompleted(previousA)) or false
--     --                 completedB = (previousB and completion:IsAchievementCompleted(previousB)) or false
--     --                 if completedA and completedB then return previousA < previousB end
--     --                 if completedA then return true end
--     --                 if completedB then return false end
--     --                 return defaultAchievementOrderComparator(a, b)
--     --             end)
--     --             ach = achs[index]
--     --         end
--         end
--     else
--         ach = G_achievement(id)
--     end
--     if ach then
--     --     local completion = cmanager:GetLocal()
--         local icon = iconTable[ach[43]] -- ach.icon
--         icon = [[Interface\AddOns\Achiever\textures\icons\]] .. icon
--         local completed, earnedBy = false, nil
--         local month, day, year
--     --     if completion:IsAchievementCompleted(ach.id) then
--     --         local time = completion:GetAchievementCompletionTime(ach.id)
--     --         month, day, year = tonumber(date('%m', time)), tonumber(date('%d', time)), tonumber(date('%y', time))
--     --         completed, earnedBy = true, UnitName('player')
--     --     end
--         return ach[1], ach[5], ach[40], completed, month, day, year, ach[22], ach[42] or 0, icon, ach[44], false, completed, earnedBy, false
--         -- return ach.id, ach.name, ach.points, completed, month, day, year, ach.description, ach.flags or 0, icon, ach:GetRewardText(), false, completed, earnedBy, false
--     end
--     return 1, '', 0, false, nil, nil, nil, '', 0, 0, '', false, false, '', false
--     -- return mock_GetAchievementInfo(id, index)
-- end








-- ---------------- local helpers
-- local function getCategory(id)
--     if id == -1 then return { -1,-1,"summary","","","","","","","","","","","","","","","",16712190,1} end
--     return G_achievementCategory[id]
-- end

-- local function isAvailable(achievement)
--     return isFactionValid(achievementId)
-- end

-- local function IsFactionValid(achievement)
--     local faction = UnitFactionGroup('player')
--     if (achievement[2] == nil) then return false
--     elseif (achievement[2] == -1) then return true
--     elseif (achievement[2] == 0 and faction == 'Horde') then return true
--     elseif (achievement[2] == 1 and faction == 'Alliance') then return true
--     end
--     return false
-- end

-- local function IsAchievementVisible(achievement, includeAll)
--     local achievementID = achievement[1]
--     if not isAvailable(achievementID) then return false end
--     if includeAll then return true end
--     if cache.completion.completed[achievementID] then
--         local nextID = achievement:GetNextID()
--         if not nextID then return true end
--         return not completion:IsAchievementCompleted(nextID)
--     end
--     if achievement.points == 0 then return false end
--     local previousID = achievement:GetPreviousID()
--     if not previousID then return true end
--     return completion:IsAchievementCompleted(previousID)
-- end