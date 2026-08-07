-- Router.lua
-- The single layer standing in for the entire missing WoW achievement API.
-- AchievementUI.lua only ever talks to the functions below; this file is the
-- only thing that knows about AchieverStaticData (read-only reference data)
-- and the two progress tables (AchieverAccountProgress/AchieverCharacterProgress,
-- the dynamic data). It also owns firing the synthetic achievement events the
-- 1.12 engine will never dispatch natively, and the local/server mode switch.

local _G = getfenv(0)

Achiever = Achiever or {}
Achiever.mode = Achiever.mode or "local"

local db = {
	categories = { data = {}, byParent = {} },
	achievements = { data = {}, byCategory = {}, previousById = {}, nextById = {} },
	criteria = { data = {}, byAchievement = {} },
}
Achiever.db = db

-- ===== Build the relational indices from the static reference data =====
-- (AchieverStaticData is the flat, id-keyed export from tools/export_static_achievement_data.py;
-- this derives the same byCategory/byParent/previousById/nextById/byAchievement
-- shape the query functions below need, whether that static data came from the
-- local export or was refreshed by a server-mode update.)

function Achiever_RebuildIndices()
	db.categories.data = {};
	db.categories.byParent = {};
	db.achievements.data = {};
	db.achievements.byCategory = {};
	db.achievements.previousById = {};
	db.achievements.nextById = {};
	db.criteria.data = {};
	db.criteria.byAchievement = {};

	local static = AchieverStaticData or {};

	for id, cat in pairs(static.categories or {}) do
		db.categories.data[id] = {
			id = id,
			name = cat.name,
			parentId = cat.parent,
			order = cat.uiOrder,
		};
		if cat.parent and cat.parent ~= -1 then
			db.categories.byParent[cat.parent] = db.categories.byParent[cat.parent] or {};
			table.insert(db.categories.byParent[cat.parent], id);
		end
	end

	for id, ach in pairs(static.achievements or {}) do
		db.achievements.data[id] = {
			id = id,
			name = ach.title,
			description = ach.description,
			categoryId = ach.category,
			points = ach.points,
			order = ach.uiOrder,
			flags = ach.flags,
			sharesCriteria = ach.sharesCriteria,
			-- iconTable's entries (e.g. "icons\Achievement_Level_10") are
			-- relative paths into this addon's own textures\ folder, a
			-- bulk-extracted local copy of ~3200 WotLK icons -- achievements
			-- didn't exist in 1.12, so its real Interface\Icons never had
			-- them. Prepending just "Interface\" (what the old attempt this
			-- was ported from did, and what this line did until now) only
			-- resolves by coincidence for icons that also happen to be real
			-- vanilla assets (spell/trade icons some achievements reuse);
			-- anything achievement-specific was silently left unresolvable.
			icon = (iconTable[ach.iconId] and ("Interface\\AddOns\\Achiever\\textures\\" .. iconTable[ach.iconId])) or "Interface\\Icons\\INV_Misc_QuestionMark",
			titleReward = ach.reward,
			faction = ach.faction,
			isGuild = false, -- always false for now; guild achievements may be added server-side later
		};
		db.achievements.byCategory[ach.category] = db.achievements.byCategory[ach.category] or {};
		table.insert(db.achievements.byCategory[ach.category], id);
		if ach.supercedes and ach.supercedes ~= 0 then
			db.achievements.previousById[id] = ach.supercedes;
			db.achievements.nextById[ach.supercedes] = id;
		end
	end

	for id, crit in pairs(static.criteria or {}) do
		db.criteria.data[id] = {
			id = id,
			achievementId = crit.achievementId,
			type = crit.type,
			assetId = crit.assetId,
			count = crit.quantity,
			name = crit.description,
			flags = crit.flags,
			order = crit.uiOrder,
		};
		db.criteria.byAchievement[crit.achievementId] = db.criteria.byAchievement[crit.achievementId] or {};
		table.insert(db.criteria.byAchievement[crit.achievementId], id);
	end
end

-- ===== Dynamic/progress data (SavedVariables) =====
-- Two scopes, checked together: an achievement/criteria counts as complete
-- if it's recorded in EITHER table, since whether the server ultimately
-- treats a given achievement as account-wide or character-only is a
-- server-side design decision this addon shouldn't have to assume.

local function EnsureProgressTables()
	AchieverAccountProgress = AchieverAccountProgress or {};
	AchieverAccountProgress.achievements = AchieverAccountProgress.achievements or {};
	AchieverAccountProgress.criteria = AchieverAccountProgress.criteria or {};
	-- Last known sync point for per-player progress data (see
	-- Achiever_GetHandshakeMessage) -- not the static achievement/category/
	-- criteria definitions, which this field's old name wrongly implied.
	AchieverAccountProgress.lastDynamicDataTimestamp = AchieverAccountProgress.lastDynamicDataTimestamp or 0;

	AchieverCharacterProgress = AchieverCharacterProgress or {};
	AchieverCharacterProgress.achievements = AchieverCharacterProgress.achievements or {};
	AchieverCharacterProgress.criteria = AchieverCharacterProgress.criteria or {};
	-- Tracked achievements are a per-character preference (which achievements
	-- to watch), not progress/completion data, but they still need to survive
	-- a relog -- SavedVariablesPerCharacter, same scope as the rest of this
	-- table, rather than a runtime-only local that reset on every reload.
	AchieverCharacterProgress.tracked = AchieverCharacterProgress.tracked or {};
end

local function GetAchievementCompletion(id)
	return AchieverCharacterProgress.achievements[id] or AchieverAccountProgress.achievements[id];
end

local function GetCriteriaProgress(id)
	return AchieverCharacterProgress.criteria[id] or AchieverAccountProgress.criteria[id];
end

local function IsAchievementCompleted(id)
	return GetAchievementCompletion(tonumber(id)) ~= nil;
end

-- ===== Achievement chain / visibility helpers (same logic as the proven
-- reference implementation in the old backport attempt's api.lua) =====

local function GetPreviousID(id)
	return db.achievements.previousById[tonumber(id)];
end

local function GetNextID(id)
	return db.achievements.nextById[tonumber(id)];
end

local function IsAchievementVisible(id, includeAll)
	if (not id) then return false end
	if (includeAll) then return true end
	local achievement = db.achievements.data[id];
	-- Statistics (flags & ACHIEVEMENT_FLAGS_STATISTIC) are plain counters, not
	-- part of a supercedes chain, and always carry 0 points by design -- the
	-- "hide zero-point, non-terminal chain entries" rule below is meant for
	-- real achievements only. Applying it to statistics hid literally every
	-- stat from GetCategoryNumAchievements/GetAchievementInfo(category, i),
	-- which is why the Stats tab showed categories but no stat rows.
	if (achievement and achievement.flags and bit.band(achievement.flags, ACHIEVEMENT_FLAGS_STATISTIC) == ACHIEVEMENT_FLAGS_STATISTIC) then
		return true;
	end
	if (IsAchievementCompleted(id)) then
		local nextId = GetNextID(id);
		if (not nextId) then return true end
		return not IsAchievementCompleted(nextId);
	end
	if (db.achievements.data[id].points == 0) then return false end
	local previousId = GetPreviousID(id);
	if (not previousId) then return true end
	return IsAchievementCompleted(previousId);
end

local function DefaultAchievementOrderComparator(a, b)
	local aOrder = a.order or 0;
	local bOrder = b.order or 0;
	if (aOrder ~= bOrder) then return aOrder < bOrder end
	return a.id < b.id;
end

local function GetCategory(categoryId)
	return db.categories.data[categoryId];
end

local function GetAchievement(achievementId)
	return db.achievements.data[achievementId];
end

-- ACHIEVEMENT_COMPARISON_SUMMARY_ID (-1) / ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID
-- (-2) are the "combined overview" sentinels the Summary row on the Stats tab
-- (and the Comparison tab) selects -- they don't name one real category, they
-- mean "every category, combined". GetCategoryNumAchievements/GetAchievementInfo
-- both need to resolve that the same way, or the overview page renders as an
-- empty header with nothing under it.
local function CollectCategoryAchievementIds(categoryID, includeAll)
	local ids = {};
	local numericId = tonumber(categoryID);
	if (numericId and numericId < 0) then
		for aid in pairs(db.achievements.data) do
			if (IsAchievementVisible(aid, includeAll)) then
				table.insert(ids, aid);
			end
		end
	else
		local achievements = db.achievements.byCategory[numericId];
		if (achievements) then
			for _, aid in pairs(achievements) do
				if (IsAchievementVisible(aid, includeAll)) then
					table.insert(ids, aid);
				end
			end
		end
	end
	return ids;
end

-- ===== Query API: every achievement-related global AchievementUI.lua calls =====

-- Category id 1 ("Statistics", a stable Blizzard DBC constant -- confirmed
-- against the old backport attempt's own api.lua) is its own separate tree,
-- shown via the Stats tab (GetStatisticsCategoryList) rather than here.
-- Walking the full parentId chain (not just a direct-parent check) is what
-- correctly excludes ALL of its descendants, not just its immediate children --
-- e.g. category 124 "Battlegrounds" has parent=122, and 122 itself has
-- parent=1, so 124 is a grandchild of Statistics that a shallow check misses.
local function IsUnderStatisticsRoot(id)
	local guard = 0;
	while (id and id ~= -1 and guard < 20) do
		if (id == 1) then return true end
		local cat = db.categories.data[id];
		if (not cat) then return false end
		id = cat.parentId;
		guard = guard + 1;
	end
	return false;
end

-- pairs() over db.categories.data has no defined order, and the DBC's
-- intended display order is its uiOrder column (exported as .order below),
-- not the numeric id -- e.g. id 92 "General" (order=1) is meant to show
-- before id 81 "Feats of Strength" (order=9). Ties fall back to id so the
-- sort is at least stable.
local function CompareCategoryOrder(a, b)
	local orderA = (db.categories.data[a] and db.categories.data[a].order) or 0;
	local orderB = (db.categories.data[b] and db.categories.data[b].order) or 0;
	if (orderA ~= orderB) then return orderA < orderB end
	return a < b;
end

function GetCategoryList()
	local result = {};
	for id, v in pairs(db.categories.data) do
		if (not IsUnderStatisticsRoot(id)) then
			table.insert(result, id);
		end
	end
	table.sort(result, CompareCategoryOrder);
	return result;
end

function GetStatisticsCategoryList()
	local result = {};
	local rootStatCategoryIdList = db.categories.byParent[1];
	if (rootStatCategoryIdList) then
		local roots = {};
		for _, v in pairs(rootStatCategoryIdList) do
			table.insert(roots, v);
		end
		table.sort(roots, CompareCategoryOrder);

		for _, v in ipairs(roots) do
			table.insert(result, v);
			local subStatCategoryIdList = db.categories.byParent[v];
			if (subStatCategoryIdList) then
				local subs = {};
				for _, vv in pairs(subStatCategoryIdList) do
					table.insert(subs, vv);
				end
				table.sort(subs, CompareCategoryOrder);
				for _, vv in ipairs(subs) do
					table.insert(result, vv);
				end
			end
		end
	end
	return result;
end

function GetCategoryInfo(categoryID)
	local category = GetCategory(categoryID);
	if (category) then
		local parentId = category.parentId;
		-- Category 1 ("Statistics") is never itself a navigable category --
		-- it's excluded from both GetCategoryList and GetStatisticsCategoryList --
		-- so its direct children need to report as top-level (parent -1) for
		-- the client-side tree-builder (AchievementFrameCategories_GetCategoryList)
		-- to ever treat them as roots of the Stats tab's category tree, rather
		-- than orphans that never get attached under anything.
		if (parentId == 1) then parentId = -1; end
		return category.name, parentId, category.order;
	end
	return '', -1, 0;
end

function GetCategoryNumAchievements(categoryID, includeAll)
	includeAll = includeAll or false;
	local total, completed, incompleted = 0, 0, 0;
	local ids = CollectCategoryAchievementIds(categoryID, includeAll);
	for _, aid in pairs(ids) do
		total = total + 1;
		if (IsAchievementCompleted(aid)) then
			completed = completed + 1;
		else
			incompleted = incompleted + 1;
		end
	end
	return total, completed, incompleted;
end

function GetComparisonCategoryNumAchievements(categoryID, includeAll)
	-- Comparison-vs-another-player isn't a priority right now (see plan); no data.
	return 0;
end

-- Callers always fetch an entire category's list one index at a time in a
-- tight loop (`for i=1, numStats do GetAchievementInfo(category, i) end` --
-- see AchievementFrameStats_Update/AchievementFrameAchievements_Update),
-- assuming (matching the real native API) that's an O(1) lookup. Without
-- caching, every single call rebuilt AND fully re-sorted the whole
-- candidate list from scratch, turning an O(n) loop into O(n^2 log n) --
-- for the Stats tab's default "-2" (all-categories-combined) selection
-- that's ~1817 achievements resorted ~1817 times, which is what pegged the
-- CPU and eventually crashed the client. Since every call in such a loop
-- shares the same (id, includeAll), caching the sorted list for the most
-- recently requested one collapses it back down to one sort per category.
local sortedCategoryCacheId, sortedCategoryCacheAll, sortedCategoryCacheList;

local function GetSortedCategoryAchievements(id, includeAll)
	if (sortedCategoryCacheId == id and sortedCategoryCacheAll == includeAll) then
		return sortedCategoryCacheList;
	end
	local aids = CollectCategoryAchievementIds(id, includeAll);
	local achs = {};
	for _, aid in pairs(aids) do
		table.insert(achs, GetAchievement(aid));
	end
	table.sort(achs, function(a, b)
		local completedA, completedB = IsAchievementCompleted(a.id), IsAchievementCompleted(b.id);
		if (completedA and completedB) then return DefaultAchievementOrderComparator(a, b) end
		if (completedA) then return true end
		if (completedB) then return false end
		local previousA, previousB = GetPreviousID(a.id), GetPreviousID(b.id);
		completedA = (previousA and IsAchievementCompleted(previousA)) or false;
		completedB = (previousB and IsAchievementCompleted(previousB)) or false;
		if (completedA and completedB) then return previousA < previousB end
		if (completedA) then return true end
		if (completedB) then return false end
		return DefaultAchievementOrderComparator(a, b);
	end);
	sortedCategoryCacheId = id;
	sortedCategoryCacheAll = includeAll;
	sortedCategoryCacheList = achs;
	return achs;
end

function Achiever_InvalidateSortedCategoryCache()
	sortedCategoryCacheId = nil;
	sortedCategoryCacheList = nil;
end

-- id, name, points, completed, month, day, year, description, flags, icon,
-- rewardText, isGuild, wasEarnedByMe, earnedBy = GetAchievementInfo(achievementID or categoryID, index)
function GetAchievementInfo(id, index, includeAll)
	local ach = nil;
	local all = includeAll or false;
	if (index) then
		local achs = GetSortedCategoryAchievements(id, all);
		if index <= table.getn(achs) then
			ach = achs[index];
		end
	else
		ach = GetAchievement(id);
	end

	if (ach) then
		local completed, earnedBy = false, nil;
		local month, day, year;
		local reward = '';
		if (ach.titleReward and ach.titleReward ~= '') then reward = ach.titleReward; end
		local completion = GetAchievementCompletion(ach.id);
		if (completion) then
			completed = true;
			earnedBy = UnitName('player');
			if (completion.date) then
				month, day, year = tonumber(date('%m', completion.date)), tonumber(date('%d', completion.date)), tonumber(date('%y', completion.date));
			end
		end
		return ach.id, ach.name, ach.points, completed, month, day, year, ach.description, ach.flags or 0, ach.icon, reward, ach.isGuild or false, completed, earnedBy;
	end
	return 1, 'INVALID ACHIEVEMENT', 0, false, nil, nil, nil, '', 0, 0, '', false, false, '';
end

function GetAchievementInfoFromCriteria(criteriaOrCategoryId)
	local criteria = db.criteria.data[tonumber(criteriaOrCategoryId)];
	if (criteria) then
		return GetAchievementInfo(criteria.achievementId);
	end
	return GetAchievementInfo(criteriaOrCategoryId);
end

function GetAchievementNumCriteria(achievementID)
	local total = 0;
	local achievement = db.achievements.data[achievementID];
	if (achievement) then
		local criteriaList = db.criteria.byAchievement[achievementID];
		if (criteriaList) then
			for _, criteriaId in pairs(criteriaList) do
				local criteria = db.criteria.data[criteriaId];
				if (criteria and criteria.name) then total = total + 1; end
			end
		end
	end
	return total;
end

-- criteriaString, criteriaType, completed, quantity, reqQuantity, charName,
-- flags, assetID, quantityString, criteriaID = GetAchievementCriteriaInfo(achievementID, criteriaIndex)
function GetAchievementCriteriaInfo(achievementID, criteriaIndex)
	local criteriaIdList = db.criteria.byAchievement[achievementID];
	local criteriaId, criteria;
	if (criteriaIdList) then
		criteriaId = criteriaIdList[criteriaIndex];
		if (criteriaId) then
			criteria = db.criteria.data[criteriaId];
		end
	end
	if (not criteriaId or not criteria) then
		return 'INVALID CRITERIA', 0, false, 0, 0, '', 0, 0, '', 0;
	end

	local reqQuantity = criteria.count or 0;
	local quantity = 0;
	local completed = false;
	local quantityString = '';
	local progress = GetCriteriaProgress(criteriaId);
	if (progress) then
		quantity = progress.counter or 0;
		completed = reqQuantity > 0 and quantity >= reqQuantity;
		-- Money-total criteria (loot/vendor/repair/auction/quest gold, etc.)
		-- store their counter as raw copper -- display it gold-denominated
		-- instead, same as the Statistics tab already does via
		-- Achiever_IsMoneyStatistic (see ACHIEVEMENT_CRITERIA_MONEY_COUNTER,
		-- Constants.lua).
		if (bit.band(criteria.flags or 0, ACHIEVEMENT_CRITERIA_MONEY_COUNTER) == ACHIEVEMENT_CRITERIA_MONEY_COUNTER) then
			quantityString = Achiever_FormatMoney(quantity) .. ' / ' .. Achiever_FormatMoney(reqQuantity);
		else
			quantityString = quantity .. ' / ' .. reqQuantity;
		end
	end

	return criteria.name, criteria.type, completed, quantity, reqQuantity, UnitName('player'), criteria.flags or 0, criteria.assetId or 0, quantityString, criteriaId;
end

function GetAchievementCategory(achievementID)
	local achievement = db.achievements.data[achievementID];
	if (not achievement) then return -1 end
	return achievement.categoryId;
end

function GetPreviousAchievement(achievementID)
	return GetPreviousID(achievementID);
end

function GetNextAchievement(achievementID)
	local nextID = GetNextID(achievementID);
	if (nextID) then return nextID, IsAchievementCompleted(nextID) end
	return nil, false;
end

function GetAchievementLink(id)
	local ach = GetAchievement(tonumber(id));
	if (not ach) then return nil end
	return "|cffffff00|Hachievement:" .. ach.id .. ":0000000000000000:0:0:0:0:-1:0:0:0|h[" .. ach.name .. "]|h|r";
end

function GetTotalAchievementPoints()
	local points = 0;
	for id in pairs(AchieverCharacterProgress.achievements) do
		local ach = db.achievements.data[id];
		if (ach) then points = points + ach.points; end
	end
	for id in pairs(AchieverAccountProgress.achievements) do
		if (not AchieverCharacterProgress.achievements[id]) then
			local ach = db.achievements.data[id];
			if (ach) then points = points + ach.points; end
		end
	end
	return points;
end

function GetNumCompletedAchievements()
	local completed = 0;
	local seen = {};
	for id in pairs(AchieverCharacterProgress.achievements) do
		seen[id] = true;
		completed = completed + 1;
	end
	for id in pairs(AchieverAccountProgress.achievements) do
		if (not seen[id]) then
			completed = completed + 1;
		end
	end
	local total = 0;
	for _ in pairs(db.achievements.data) do total = total + 1; end
	return total, completed;
end

function GetLatestCompletedAchievements()
	local merged = {};
	local count = 0;
	for id, v in pairs(AchieverCharacterProgress.achievements) do
		local achievement = db.achievements.data[id];
		if (achievement and not IsUnderStatisticsRoot(achievement.categoryId)) then
			count = count + 1;
			merged[count] = { id = id, date = v.date or 0 };
		end
	end
	for id, v in pairs(AchieverAccountProgress.achievements) do
		if (not AchieverCharacterProgress.achievements[id]) then
			local achievement = db.achievements.data[id];
			if (achievement and not IsUnderStatisticsRoot(achievement.categoryId)) then
				count = count + 1;
				merged[count] = { id = id, date = v.date or 0 };
			end
		end
	end
	if (count == 0) then return end
	table.sort(merged, function(a, b)
		if (a.date ~= b.date) then return a.date > b.date end
		return a.id > b.id;
	end);
	local resCount = math.min(count, 5);
	local res = {};
	for i = 1, resCount do res[i] = merged[i].id; end
	-- Must return exactly resCount values, not a fixed 5-tuple with trailing
	-- nils -- Lua 5.0's vararg calling convention preserves "5-ness" through
	-- arg.n even when some of those 5 are nil, which made
	-- AchievementFrameSummary_UpdateAchievements believe numAchievements was
	-- always 5 and call GetAchievementInfo(nil) for the missing slots,
	-- rendering them as "Invalid Achievement" instead of falling through to
	-- ACHIEVEMENTUI_DEFAULTSUMMARYACHIEVEMENTS suggestions.
	return unpack(res, 1, resCount);
end

-- Resolves which criteria list an achievement's Statistics-tab number
-- actually aggregates over: its own criteria plus, when sharesCriteria is
-- set, another achievement's criteria list too -- both, not either/or.
-- Confirmed via direct DB inspection: most sharesCriteria achievements (e.g.
-- 1336 "Creature type killed the most") have zero criteria rows of their own
-- and purely reuse another achievement's list (e.g. 107 "Creatures killed"'s
-- 10 per-creature-type criteria), but 1337 "Different creature types killed"
-- has BOTH its own extra criterion ("Critters", not tracked by 107's own SUM
-- stat) AND shares 107's same 10 -- dropping the own list there undercounts
-- by 1. The two id sets are always disjoint (owned by different achievement
-- ids in the source data), so straight concatenation is correct. Shared by
-- GetStatistic and Achiever_IsMoneyStatistic so both always aggregate over
-- the same set.
local function Achiever_GetStatCriteriaIds(id)
	local achievement = db.achievements.data[id];
	local merged = {};

	local ownList = db.criteria.byAchievement[id];
	if (ownList) then
		for _, criteriaId in pairs(ownList) do
			table.insert(merged, criteriaId);
		end
	end

	if (achievement and achievement.sharesCriteria and achievement.sharesCriteria ~= 0) then
		local sharedList = db.criteria.byAchievement[achievement.sharesCriteria];
		if (sharedList) then
			for _, criteriaId in pairs(sharedList) do
				table.insert(merged, criteriaId);
			end
		end
	end

	if (table.getn(merged) == 0) then return nil, achievement end
	return merged, achievement;
end

-- The real client's GetStatistic is a native call whose display logic
-- (sum/max/distinct-count over a criteria list, per the achievement's own
-- Flags -- SUMM/MAX_USED/REQ_COUNT) is entirely server/native-side and
-- invisible to addon Lua (confirmed: the real WotLK Blizzard_AchievementUI.lua
-- has none of this logic at all). Reimplemented here since our mock has to
-- compute it itself.
function GetStatistic(id)
	local criteriaIdList, achievement = Achiever_GetStatCriteriaIds(id);
	if (not criteriaIdList or not criteriaIdList[1]) then return 0 end

	local flags = achievement and achievement.flags or 0;

	if (bit.band(flags, ACHIEVEMENT_FLAGS_MAX_USED) == ACHIEVEMENT_FLAGS_MAX_USED) then
		-- "___ the most" stats (e.g. "Creature type killed the most") display
		-- the *name* of the winning criteria (e.g. "Humanoid"), not its raw
		-- count -- matches the real client, which shows a category name here,
		-- not a number. Falls through to the plain 0 -> "--" empty-stat path
		-- when nothing has any progress yet.
		local best = 0;
		local bestCriteriaId;
		for _, criteriaId in pairs(criteriaIdList) do
			local progress = GetCriteriaProgress(criteriaId);
			local counter = progress and (progress.counter or 0) or 0;
			if (counter > best) then
				best = counter;
				bestCriteriaId = criteriaId;
			end
		end
		if (not bestCriteriaId) then return 0 end
		local bestCriteria = db.criteria.data[bestCriteriaId];
		return (bestCriteria and bestCriteria.name) or best;
	end

	if (bit.band(flags, ACHIEVEMENT_FLAGS_REQ_COUNT) == ACHIEVEMENT_FLAGS_REQ_COUNT) then
		-- Count of criteria that have reached their required quantity --
		-- use the criteria's own Quantity when it's set (e.g. "300 skill"),
		-- else (0, as with the shared creature-kill criteria) any progress
		-- at all counts as "reached".
		local reached = 0;
		for _, criteriaId in pairs(criteriaIdList) do
			local progress = GetCriteriaProgress(criteriaId);
			local counter = progress and (progress.counter or 0) or 0;
			local criteria = db.criteria.data[criteriaId];
			local threshold = (criteria and criteria.count and criteria.count > 0) and criteria.count or 1;
			if (counter >= threshold) then reached = reached + 1 end
		end
		return reached;
	end

	if (bit.band(flags, ACHIEVEMENT_FLAGS_SUMM) == ACHIEVEMENT_FLAGS_SUMM) then
		local total = 0;
		for _, criteriaId in pairs(criteriaIdList) do
			local progress = GetCriteriaProgress(criteriaId);
			total = total + (progress and (progress.counter or 0) or 0);
		end
		return total;
	end

	-- Plain stat, no aggregation flag -- unchanged: first criteria's counter.
	local progress = GetCriteriaProgress(criteriaIdList[1]);
	return progress and (progress.counter or 0) or 0;
end

-- The real client's GetStatistic is a native call that hands back an
-- already-formatted string (money-formatted for gold stats, plain for
-- everything else); ours is a mock over a raw counter, so the UI layer needs
-- its own way to ask whether a given stat's counter is a gold amount (flagged
-- ACHIEVEMENT_CRITERIA_MONEY_COUNTER, e.g. "Total gold looted"/"Highest gold
-- owned") and should render as split gold/silver/copper icons instead of a
-- bare number. Resolved through the same sharesCriteria logic as
-- GetStatistic so the two always agree on which criteria list is in play
-- (e.g. achievement 328 "Total gold acquired" is both SUMM and money-flagged).
function Achiever_IsMoneyStatistic(id)
	local criteriaIdList = Achiever_GetStatCriteriaIds(id);
	local criteriaId = criteriaIdList and criteriaIdList[1];
	local criteria = criteriaId and db.criteria.data[criteriaId];
	return criteria and criteria.flags and bit.band(criteria.flags, ACHIEVEMENT_CRITERIA_MONEY_COUNTER) == ACHIEVEMENT_CRITERIA_MONEY_COUNTER;
end

-- Backed directly by AchieverCharacterProgress.tracked (SavedVariablesPerCharacter)
-- rather than a separate runtime-only table, so tracked achievements survive
-- a relog with no extra load/save step needed.

function GetTrackedAchievements()
	-- Real signature returns a vararg list of ids, not a table.
	local result = {};
	for id in pairs(AchieverCharacterProgress.tracked) do table.insert(result, id); end
	return unpack(result);
end

function GetNumTrackedAchievements()
	local n = 0;
	for _ in pairs(AchieverCharacterProgress.tracked) do n = n + 1; end
	return n;
end

function IsTrackedAchievement(id)
	return AchieverCharacterProgress.tracked[tonumber(id)] and true or false;
end

function AddTrackedAchievement(id)
	if (GetNumTrackedAchievements() >= WATCHFRAME_MAXACHIEVEMENTS) then return end
	AchieverCharacterProgress.tracked[tonumber(id)] = true;
	Achiever_EmitTrackedAchievementUpdate();
end

function RemoveTrackedAchievement(id)
	AchieverCharacterProgress.tracked[tonumber(id)] = nil;
	Achiever_EmitTrackedAchievementUpdate();
end

function CanShowAchievementUI()
	return true;
end

function HasCompletedAnyAchievement()
	local _, completed = GetNumCompletedAchievements();
	return completed > 0;
end

-- Comparison (inspect-another-player) — not a priority right now (see plan);
-- kept present and inert so the Comparison/Summary tabs (which share a
-- template) never error, rather than stripped.
function SetAchievementComparisonUnit(unit) end
function ClearAchievementComparisonUnit() end
function GetComparisonAchievementPoints() return 0 end
function GetAchievementComparisonInfo(id) return false, nil, nil, nil end
function GetComparisonStatistic(id) return 0 end

-- ===== Event emission =====
-- AchievementUI.lua registers for ACHIEVEMENT_EARNED/CRITERIA_UPDATE/
-- TRACKED_ACHIEVEMENT_UPDATE/INSPECT_ACHIEVEMENT_READY, none of which the
-- 1.12 engine ever fires. Router.lua owns emitting these (rather than
-- Achiever.lua's chat-parsing code doing it directly) by calling the UI's
-- OnEvent handlers straight, matching the technique the old attempt used.

-- silent skips only the toast/alert popup (AlertFrame_ShowAchievementEarned)
-- -- the achievement list/summary still refresh and the tracker still drops
-- it, since those reflect real state rather than a "you just earned this"
-- notification. Used for HELLO_UPDATE's handshake replay of
-- already-completed achievements, which shouldn't pop a splash for
-- something that happened before Achiever was even watching.
function Achiever_EmitAchievementEarned(id, silent)
	if (AchievementFrameAchievements_OnEvent) then
		AchievementFrameAchievements_OnEvent(AchievementFrameAchievements, "ACHIEVEMENT_EARNED", tonumber(id));
	end
	-- There's no single "AchievementFrameSummaryCategory" frame -- the Summary
	-- tab's per-category progress bars are 8 separate StatusBar instances
	-- (AchievementFrameSummaryCategoriesCategory1..8, one per top-level
	-- category shown there), each normally driven by its own RegisterEvent
	-- done in AchievementFrameSummaryCategory_OnShow. Calling the OnEvent
	-- handler against a nonexistent single-frame global passed self as nil
	-- and crashed on self:GetID() in AchievementFrameSummaryCategory_OnShow.
	if (AchievementFrameSummaryCategory_OnEvent) then
		for i = 1, 8 do
			local categoryBar = _G["AchievementFrameSummaryCategoriesCategory" .. i];
			if (categoryBar) then
				AchievementFrameSummaryCategory_OnEvent(categoryBar, "ACHIEVEMENT_EARNED", tonumber(id));
			end
		end
	end
	if (AchievementFrameSummary_Update) then
		AchievementFrameSummary_Update();
	end
	if (not silent and AlertFrame_ShowAchievementEarned) then
		AlertFrame_ShowAchievementEarned(tonumber(id));
	end
	-- Matches WotLK's real behavior: an achievement drops off the tracker
	-- once earned, rather than sitting there completed forever.
	if (IsTrackedAchievement(tonumber(id))) then
		RemoveTrackedAchievement(tonumber(id));
	end
end

function Achiever_EmitCriteriaUpdate(criteriaId)
	if (AchievementFrameAchievements_OnEvent) then
		AchievementFrameAchievements_OnEvent(AchievementFrameAchievements, "CRITERIA_UPDATE", tonumber(criteriaId));
	end
	if (AchievementFrameStats_OnEvent) then
		AchievementFrameStats_OnEvent(AchievementFrameStats, "CRITERIA_UPDATE", tonumber(criteriaId));
	end
	-- A tracked achievement's progress may have just changed.
	if (Achiever_Tracker_Update) then
		Achiever_Tracker_Update();
	end
end

function Achiever_EmitTrackedAchievementUpdate()
	if (AchievementFrameAchievements_OnEvent) then
		AchievementFrameAchievements_OnEvent(AchievementFrameAchievements, "TRACKED_ACHIEVEMENT_UPDATE");
	end
	if (Achiever_Tracker_Update) then
		Achiever_Tracker_Update();
	end
end

-- Marks an achievement/criteria complete locally and fires the matching
-- synthetic event(s) — used both by a future local-mode "deduce progress"
-- system and by server-mode message handling below. silent passes through
-- to Achiever_EmitAchievementEarned to suppress just the toast/alert popup.
function Achiever_RecordAchievementEarned(id, scope, earnedAt, silent)
	id = tonumber(id);
	local target = (scope == "account") and AchieverAccountProgress or AchieverCharacterProgress;
	if (target.achievements[id]) then return end
	target.achievements[id] = { date = earnedAt or time() };
	Achiever_InvalidateSortedCategoryCache(); -- completion state affects sort order
	Achiever_EmitAchievementEarned(id, silent);
end

function Achiever_RecordCriteriaProgress(id, counter, scope, updatedAt)
	id = tonumber(id);
	local target = (scope == "account") and AchieverAccountProgress or AchieverCharacterProgress;
	target.criteria[id] = { counter = counter, date = updatedAt or time() };
	Achiever_EmitCriteriaUpdate(id);
end

-- Keeps lastDynamicDataTimestamp at the latest date seen across a
-- HELLO_UPDATE replay, so next login's handshake reports an accurate sync
-- point instead of falling behind (or jumping backwards on an out-of-order
-- line).
local function Achiever_AdvanceDynamicDataTimestamp(date)
	if (date and date > (AchieverAccountProgress.lastDynamicDataTimestamp or 0)) then
		AchieverAccountProgress.lastDynamicDataTimestamp = date;
	end
end

-- ===== Local-mode-first handshake =====
-- ACHI;HELLO;<addonVersion>;<lastDynamicDataTimestamp> is sent on login as a
-- plain chat line into the shared channel (Achiever.lua owns the actual
-- SendChatMessage/AddMessage-hook plumbing) -- SendAddonMessage can't target
-- an arbitrary channel in this client at all (see Achiever.lua's handshake
-- comment), so unlike a real CHAT_MSG_ADDON prefix, the "ACHI" marker has to
-- travel inside the message body itself, since it's the only thing
-- distinguishing this protocol's lines from any other chat text in the
-- channel.
--
-- Semicolon-delimited, not pipe-delimited: WoW's chat system treats "|" as
-- the start of a formatting/hyperlink escape code, and SendChatMessage
-- validates outgoing text for well-formed escape sequences -- a raw
-- "ACHI|HELLO|..." message threw "invalid escape code in chat message"
-- (the "H" right after the first "|" reads as the start of a "|H...|h...|h"
-- hyperlink code that was never properly closed). ";" isn't a special
-- character to the chat parser, so it's safe to use freely.
--
-- If nothing recognizable comes back before the timeout, we stay in local
-- mode. Receiving ANY of the AC/CA/CR/ACV/CAV/CRV row/version messages back
-- is itself proof the server supports the protocol; folding those rows into
-- the static-data tables (server-mode sync) is the next step once there's a
-- real server to test against, so those message types currently just
-- confirm mode switch without yet updating db contents.
--
-- addonVersion is the real Achiever.toc "## Version" (not a separate
-- synthetic protocol-version counter), so the server can identify exactly
-- which client build connected. lastDynamicDataTimestamp is the client's
-- last known sync point for per-player progress data (earned achievements/
-- criteria) -- not the static achievement/category/criteria definitions,
-- which are exported offline via tools/export_static_achievement_data.py
-- and never negotiated over this live handshake at all.
function Achiever_GetHandshakeMessage()
	local addonVersion = GetAddOnMetadata("Achiever", "Version") or "0";
	return "ACHI\tHELLO;" .. addonVersion .. ";" .. (AchieverAccountProgress.lastDynamicDataTimestamp or 0);
end

function Achiever_ProcessServerMessage(message)
	local _, _, msgType = string.find(message, "^ACHI;([^;]+)");
	if (not msgType) then return false end

	-- Handshake reply sequence: after ACHI\tHELLO;..., a server that supports
	-- achievements replays this character's already-completed
	-- achievements/in-progress criteria as one HELLO_UPDATE line each (so a
	-- returning player's local save catches up with whatever happened while
	-- Achiever wasn't around -- offline progress, a different client, a
	-- fresh install, etc.), then sends a single HELLO_DONE once finished.
	-- Reuses Achiever_RecordAchievementEarned/Achiever_RecordCriteriaProgress
	-- rather than writing straight into the progress tables, so this goes
	-- through the exact same completion/dedup/event-emission logic any other
	-- progress update does (including the existing "already recorded, skip"
	-- guard in Achiever_RecordAchievementEarned, which makes replaying the
	-- same line twice harmless).
	if (msgType == "HELLO_UPDATE") then
		local _, _, updateType = string.find(message, "^ACHI;HELLO_UPDATE;([^;]+)");
		if (updateType == "AC") then
			local _, _, achievementId, earnedAt = string.find(message, "^ACHI;HELLO_UPDATE;AC;(%d+);(%d+)");
			if (achievementId and earnedAt) then
				earnedAt = tonumber(earnedAt);
				Achiever_RecordAchievementEarned(tonumber(achievementId), nil, earnedAt, true);
				Achiever_AdvanceDynamicDataTimestamp(earnedAt);
			end
		elseif (updateType == "CR") then
			local _, _, criteriaId, counter, updatedAt = string.find(message, "^ACHI;HELLO_UPDATE;CR;(%d+);(%d+);(%d+)");
			if (criteriaId and counter and updatedAt) then
				updatedAt = tonumber(updatedAt);
				Achiever_RecordCriteriaProgress(tonumber(criteriaId), tonumber(counter), nil, updatedAt);
				Achiever_AdvanceDynamicDataTimestamp(updatedAt);
			end
		end
		Achiever.mode = "server";
		return true;
	elseif (msgType == "HELLO_DONE") then
		Achiever.mode = "server";
		return true;
	end

	if (msgType == "AC" or msgType == "CA" or msgType == "CR"
			or msgType == "ACV" or msgType == "CAV" or msgType == "CRV") then
		-- TODO: fold the row/version-stamp payload into AchieverStaticData
		-- and call Achiever_RebuildIndices() once there's a live server to
		-- validate the wire format against.
		Achiever.mode = "server";
		return true;
	elseif (msgType == "CH_AC" or msgType == "CH_CR") then
		-- TODO: initial character/account progress sync.
		Achiever.mode = "server";
		return true;
	elseif (msgType == "AE") then
		-- ACHI;AE;<achievementId>;<date> -- live ChatHandler push on
		-- ACHIEVEMENT_EARNED (achievement->ID, date). Unlike HELLO_UPDATE's
		-- backdated replay this is a real "just now" event, so it's recorded
		-- non-silently and shows the normal toast alert.
		local _, _, achievementId, earnedAt = string.find(message, "^ACHI;AE;(%d+);(%d+)");
		if (achievementId and earnedAt) then
			earnedAt = tonumber(earnedAt);
			Achiever_RecordAchievementEarned(tonumber(achievementId), nil, earnedAt);
			Achiever_AdvanceDynamicDataTimestamp(earnedAt);
		end
		Achiever.mode = "server";
		return true;
	elseif (msgType == "ACU") then
		-- ACHI;ACU;<criteriaId>;<referredAchievementId>;<counter>;<date> --
		-- live ChatHandler push on criteria progress (entry->ID,
		-- entry->referredAchievement, progress->counter, progress->date).
		-- referredAchievementId isn't needed by Achiever_RecordCriteriaProgress
		-- (the criteria->achievement link already comes from the static data
		-- export), so it's parsed only to keep field positions matching the
		-- server's PSendSysMessage order.
		local _, _, criteriaId, referredAchievementId, counter, updatedAt = string.find(message, "^ACHI;ACU;(%d+);(%d+);(%d+);(%d+)");
		if (criteriaId and counter and updatedAt) then
			updatedAt = tonumber(updatedAt);
			Achiever_RecordCriteriaProgress(tonumber(criteriaId), tonumber(counter), nil, updatedAt);
			Achiever_AdvanceDynamicDataTimestamp(updatedAt);
		end
		Achiever.mode = "server";
		return true;
	end

	return false;
end

-- AchieverStaticData (from Data\*.lua) is plain addon data, already fully
-- loaded by the time this file's chunk runs (per .toc order), so building
-- the indices now is safe. AchieverAccountProgress/AchieverCharacterProgress
-- are SavedVariables, though, which the client only populates right before
-- ADDON_LOADED fires for this addon -- initializing them any earlier here
-- would silently create fresh empty tables instead of the real saved data.
Achiever_RebuildIndices();

local routerEventFrame = CreateFrame("Frame");
routerEventFrame:RegisterEvent("ADDON_LOADED");
routerEventFrame:SetScript("OnEvent", function()
	if (event == "ADDON_LOADED" and arg1 == "Achiever") then
		EnsureProgressTables();
		this:UnregisterEvent("ADDON_LOADED");
	end
end);
