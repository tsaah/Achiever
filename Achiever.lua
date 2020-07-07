

Achiever = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0", "AceDB-2.0")



Achiever:RegisterDB("achieverDB", "achieverDBpc")
Achiever:RegisterDefaults("profile", {
} )
-- type = 0, 0 - common, 1 - group, 2 - progress, 3 - count, 4 - time, 5 - statistic
-- faction = 0, 0 - both, 1 - aliance, 2 - horde
-- complete = 0, 0 - not coompleted, 1 - completed
-- category = "",
-- text = "",
-- icon = "",
-- shield = 0, 0 - 3 different shields
-- score = 0,
-- date = "",
-- achievementPartsState = {},  achievements ids
-- min = 0,
-- max = 0,
-- current = 0,
-- time = 0,
-- value = 0,
-- criteria = 0
Achiever:RegisterDefaults("char", {
	achievements = {
		-- level
		[0] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 10.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_10_resize", shield = 0, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 10 },
		[1] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 20.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_20_resize", shield = 0, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 20 },
		[2] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 30.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_30_resize", shield = 1, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 30 },
		[3] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 40.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_40_resize", shield = 2, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 40 },
		[4] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 50.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_50_resize", shield = 2, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 50 },
		[5] = { type = 0, faction = 0, complete = 0, category = "Character", text = "Reach Level 60.", icon = "Interface\\AddOns\\Achiever\\textures\\achievement_level_60_resize", shield = 3, score = 10, date = "", achievementPartsState = {}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 60 },
		-- meta level
		[6] = { type = 1, faction = 0, complete = 0, category = "Character", text = "", icon = "", shield = 3, score = 10, date = "", achievementPartsState = { 0, 1, 2, 3, 4, 5}, min = 0, max = 0, current = 0, time = 0, value = 0, criteria = 0 },
		-- gold loot progress
		[7] = { type = 2, faction = 0, complete = 0, category = "Got My Mind On My Money", text = "Loot 1 copper.", icon = "Interface\\Icons\\INV_Misc_Coin_06", shield = 0, score = 0, date = "", achievementPartsState = {}, min = 0, max = 1, current = 0, time = 0, value = 0, criteria = 1 },

	},
	exploration = { -- type 0 - world
		["Elwynn Forest"] = {
			[""] = { v = 0, t = 0, l = 0 },
			["Brackwell Pumpkin Patch"] = { v = 0, t = 0, l = 8 },
			["Crystal Lake"] = { v = 0, t = 0, l = 7 },
			["Eastvale Logging Camp"] = { v = 0, t = 0, l = 6 },
			["Echo Ridge Mine"] = { v = 0, t = 0, l = 0 },
			["Fargodeep Mine"] = { v = 0, t = 0, l = 5 },
			["Forest's Edge"] = { v = 0, t = 0, l = 8 },
			["Goldshire"] = { v = 0, t = 0, l = 5 },
			["Heroes' Vigil"] = { v = 0, t = 0, l = 0 },
			["Jasperlode Mine"] = { v = 0, t = 0, l = 8 },
			["Jerod's Landing"] = { v = 0, t = 0, l = 8 },
			["Mirror Lake"] = { v = 0, t = 0, l = 0 },
			["Mirror Lake Orchard"] = { v = 0, t = 0, l = 0 },
			["Northshire Abbey"] = { v = 0, t = 0, l = 0 },
			["Northshire River"] = { v = 0, t = 0, l = 0 },
			["Northshire Valley"] = { v = 0, t = 0, l = 0 },
			["Northshire Vineyards"] = { v = 0, t = 0, l = 0 },
			["Ridgepoint Tower"] = { v = 0, t = 0, l = 8 },
			["Stone Cairn Lake"] = { v = 0, t = 0, l = 8 },
			["Stormwind Mountains"] = { v = 0, t = 0, l = 10 },
			["The Maclure Vineyards"] = { v = 0, t = 0, l = 6 },
			["The Stonefield Farm"] = { v = 0, t = 0, l = 6 },
			["Thieves Camp"] = { v = 0, t = 0, l = 0 },
			["Thunder Falls"] = { v = 0, t = 0, l = 0 },
			["Tower of Azora"] = { v = 0, t = 0, l = 8 },
			["Westbrook Garrison"] = { v = 0, t = 0, l = 8 },
		}
	}
} )



function Achiever:OnInitialize()
	Achiever.cmdTable = { type='group', handler = Achiever, args = {
		test = {
			type = 'execute',
			name = 'test',
			desc = 'show test achievement',
			usage = '/ahieve test',
			func = function()
					achieverLibnotify:ShowPopup("TEXT", 'NOTE', 31, 'Interface\\QuestFrame\\UI-QuestLog-BookIcon', math.floor(35/15), 'TITLE')
				end,
		},
		-- msg = {
		--     type = 'text',
		--     name = 'msg',
		--     desc = 'The message text to be displayed',
		--     usage = "<Your message here>",
		--     get = "GetMessage",
		--     set = "SetMessage"
		-- }
	}}
	Achiever:RegisterChatCommand({"/achie", "/achiever"}, Achiever.cmdTable)
end

function Achiever:OnEnable()


	self:RegisterEvent("PLAYER_LEVEL_UP")

	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_SLOT_CLEARED")

	self:RegisterEvent("QUEST_WATCH_UPDATE")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")


	self:RegisterEvent("MINIMAP_ZONE_CHANGED")



	self:RegisterEvent("CHAT_MSG_SYSTEM")



	-- self:RegisterEvent("PLAYER_MONEY")

	-- self:RegisterEvent("QUEST_ACCEPTED")
	-- self:RegisterEvent("QUEST_ACCEPT_CONFIRM")
	-- self:RegisterEvent("QUEST_COMPLETE")
	-- self:RegisterEvent("QUEST_POI_UPDATE")
	-- self:RegisterEvent("QUEST_QUERY_COMPLETE")
	-- self:RegisterEvent("QUEST_DETAIL")
	-- self:RegisterEvent("QUEST_FINISHED")
	-- self:RegisterEvent("QUEST_GREETING")
	-- self:RegisterEvent("QUEST_ITEM_UPDATE")
	-- self:RegisterEvent("QUEST_LOG_UPDATE")
	-- self:RegisterEvent("QUEST_PROGRESS")
	-- self:RegisterEvent("QUEST_WATCH_UPDATE")
	-- self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end

function Achiever:OnDisable()
end


---- player level
function Achiever:PLAYER_LEVEL_UP()
	local level = arg1
	for id = 0, 5, 1 do
		local achievement = self.db.char.achievements[id]
		if (level >= achievement.criteria) then
			self.db.char.achievements[id].complete = 1
		end
		if (level == achievement.criteria) then
			achieverLibnotify:ShowPopup(self.db.char.achievements[id].category, self.db.char.achievements[id].text, self.db.char.achievements[id].score, self.db.char.achievements[id].icon, self.db.char.achievements[id].shield)
		end
	end

end


---- money looted
local money = 0
local moneySlot = 0

function Achiever:LOOT_OPENED()
	local numItems = GetNumLootItems()
	money = 0
	moneySlot = 0
	if numItems == 0 then
		return
	end
	for slotID = 1, numItems, 1 do
		local texture, itemName, quantity, quality = GetLootSlotInfo( slotID )
		if LootSlotIsCoin(slotID) then
			money = lootName2Copper(itemName)
			moneySlot = slotID
		end
	end
end

function Achiever:LOOT_SLOT_CLEARED()
	if (arg1 == moneySlot) then
		local id = 7
		local grades = {1, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000, 25000, 50000, 75000, 100000, 250000, 500000, 750000, 1000000, 2500000, 5000000, 7500000, 10000000, 25000000, 50000000, 75000000, 100000000 }
		local a = self.db.char.achievements[id]
		local before = a.current
		local current = before + money
		self.db.char.achievements[id].current = current
		for i, v in pairs( grades ) do
			if ((v > before) and (v <= current) and (current >= self.db.char.achievements[id].max)) then
				achieverLibnotify:ShowPopup(self.db.char.achievements[id].category, self.db.char.achievements[id].text, self.db.char.achievements[id].score, self.db.char.achievements[id].icon, self.db.char.achievements[id].shield)
				self.db.char.achievements[id].max = v
				local ammount = copper2text(grades[i + 1] or v * 10)
				self.db.char.achievements[id].text = "Loot "..ammount
				if (v == 75) then
					self.db.char.achievements[id].icon = "Interface\\Icons\\INV_Misc_Coin_05"
					self.db.char.achievements[id].shield = 1
				elseif (v >= 100) then
					self.db.char.achievements[id].icon = "Interface\\Icons\\INV_Misc_Coin_04"
					self.db.char.achievements[id].shield = 0
				elseif (v >= 7500) then
					self.db.char.achievements[id].icon = "Interface\\Icons\\INV_Misc_Coin_03"
					self.db.char.achievements[id].shield = 1
				elseif (v >= 10000) then
					self.db.char.achievements[id].icon = "Interface\\Icons\\INV_Misc_Coin_02"
					self.db.char.achievements[id].shield = 2
				elseif (v >= 1000000) then
					self.db.char.achievements[id].icon = "Interface\\Icons\\INV_Misc_Coin_01"
					self.db.char.achievements[id].shield = 3
				end
			end
		end
	end
end


---- quest completion
local questQueue = nil
function Achiever:QUEST_WATCH_UPDATE()
	questQueue = arg1
end
function Achiever:UNIT_QUEST_LOG_CHANGED()
	if questQueue and arg1 == 'player' then
		local title, level, tag, header, collapsed, complete = GetQuestLogTitle(questQueue)
		if complete then
			achieverLibnotify:ShowPopup(title, '', level, 'Interface\\QuestFrame\\UI-QuestLog-BookIcon', math.floor(level), 'Completed')
		end
		questQueue = nil
	end
end



---- exploration
function Achiever:MINIMAP_ZONE_CHANGED()
	local zonetext = GetZoneText()   -- Returns the zone text (e.g. "Stormwind City").
	local realzonetext = GetRealZoneText()   -- Returns either instance name or zone name
	local subzonetext = GetSubZoneText()   -- Returns the subzone text (e.g. "The Canals").

	if zonetext ~= realzonetext then
		print(zonetext)
		print(realzonetext)
	end


	local v = self.db.char.exploration[zonetext][subzonetext].v
	local l = self.db.char.exploration[zonetext][subzonetext].l
	if v == 0 then
		self.db.char.exploration[zonetext][subzonetext].v = 1
		if subzonetext ~= '' then
			achieverLibnotify:ShowPopup(subzonetext, zonetext, l, 'Interface\\WorldMap\\WorldMap-MagnifyingGlass', math.floor(l / 15), 'Discovered')
		else
			achieverLibnotify:ShowPopup(zonetext, '', l, 'Interface\\WorldMap\\WorldMap-MagnifyingGlass', math.floor(l / 15), 'Discovered')
		end
	end


	-- local location = zonetext
	-- if subzonetext ~= '' then
	-- 	location = location .. ': ' .. subzonetext
	-- end
	-- print(location)
	-- Print("-------")
end
