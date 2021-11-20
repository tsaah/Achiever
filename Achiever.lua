local ACHIEVER_ADDON_NAME = 'Achiever'
local ACHIEVER_ADDON_VERSION = '0.0.1.0'
local ACHIEVER_ADDON_CHANNEL = 'ACHIEVER'
local ACHIEVER_ADDON_DEBUG = true
local Achiever = CreateFrame("Frame")

function log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf33333fcui: |cffff55ff'.. (msg or 'nil'))
end

Achiever:RegisterEvent("ADDON_LOADED")
Achiever:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
Achiever:RegisterEvent("CHAT_MSG_ADDON")
Achiever:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
Achiever:RegisterEvent("PLAYER_ENTERING_WORLD")

Achiever.version = ACHIEVER_ADDON_VERSION
Achiever.channel = ACHIEVER_ADDON_CHANNEL
Achiever.channelIndex = 0

Achiever:SetScript("OnEvent", function()
	if (not event) then
		return
	elseif (event == "ADDON_LOADED" and arg1 == 'ACHIEVER_ADDON_NAME') then
		Achiever.init()
	elseif (event == 'CHAT_MSG_CHANNEL_LEAVE') then
	elseif (event == 'CHAT_MSG_ADDON') then
	elseif (event == 'CHAT_MSG_CHANNEL_NOTICE') then
		if arg9 == Achiever.channel and arg1 == 'YOU_JOINED' then
			Achiever.channelIndex = arg8
		end
	elseif (event == 'PLAYER_ENTERING_WORLD') then
	end
end)

function Achiever.init()
	SendAddonMessage('ACHI', 'ACHI|' .. Achiever.version)
	-- addon should send a message with version ACHI:version
end

local hookChatFrame = function(frame)
    if (not frame) then
		print('Achiever failed to hook chat frame')
        return
    end

    local original = frame.AddMessage
    if original then
        frame.AddMessage = function(t, message, ...)
			if string.find(message, 'ACHI|', 1, true) then
				processServerMessage(message)
				if ACHIEVER_ADDON_DEBUG then
					DEFAULT_CHAT_FRAME:AddMessage('|cf33333fcui: |cffff55ff'.. (message or 'nil'))
				end
				return false --hide this message
			end
            original(t, message, unpack(arg))
        end
    else
		DEFAULT_CHAT_FRAME:AddMessage('|cf33333fcui: |cffff55ff'.. 'Tried to hook non-chat frame.')
    end
end

-- Achiever = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0", "AceDB-2.0")


-- Achiever:RegisterDB("achieverDB", "achieverDBpc")
-- Achiever:RegisterDefaults("profile", {
-- } )





function Achiever:OnInitialize()
	-- Achiever.cmdTable = { type='group', handler = Achiever, args = {
	-- 	test = {
	-- 		type = 'execute',
	-- 		name = 'test',
	-- 		desc = 'show test achievement',
	-- 		usage = '/achieve test',
	-- 		func = function()
	-- 			print("test")
	-- 				achieverLibnotify:ShowPopup("TEXT", 'NOTE', 31, 'Interface\\QuestFrame\\UI-QuestLog-BookIcon', math.floor(35/15), 'TITLE')
	-- 			end,
	-- 	},
	-- 	-- msg = {
	-- 	--     type = 'text',
	-- 	--     name = 'msg',
	-- 	--     desc = 'The message text to be displayed',
	-- 	--     usage = "<Your message here>",
	-- 	--     get = "GetMessage",
	-- 	--     set = "SetMessage"
	-- 	-- }
	-- }}
	-- Achiever:RegisterChatCommand({"/achie", "/achiever"}, Achiever.cmdTable)

	Achiever.checkAndJoinAchieverChannel()
end

function Achiever:OnDisable()
end

function Achiever:OnEnable()
	-- self:RegisterEvent("CHAT_MSG_CHANNEL")
	self:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Achiever:PLAYER_ENTERING_WORLD()
	-- Achiever.sendMyVersion()  -- send to other group members
	hookChatFrame(ChatFrame1) -- hide achiever server messages
end

-- function Achiever:CHAT_MSG_CHANNEL()
	-- process server messages like achievement earned or criteria changed or other
	-- local params = split(arg1, "|")
	-- if (params[1] ~= "ACHI") then return end
	-- if (params[2] == "AE") then
	-- 	local achievementId = tonumber(params[3])

	-- 	local breadcrumbs = split(params[4], '/')
	-- 	local breadcrumbsSize = table.getn(breadcrumbs)
	-- 	local achievementName = breadcrumbs[breadcrumbsSize - 1]

	-- 	local achievementNameFlags = tonumber(params[5])
	-- 	local achievementDescription = params[6]
	-- 	local achievementDescriptionFlags = tonumber(params[7])
	-- 	local achievementCategoryId = tonumber(params[8])
	-- 	local achievementPoints = tonumber(params[9])
	-- 	local achievementOrderInCategory = tonumber(params[10])
	-- 	local achievementFlags = tonumber(params[11])
	-- 	local achievementIcon = tonumber(params[12])
	-- 	local achievementTitleReward = params[13]
	-- 	local achievementTitleRewardFlags = tonumber(params[14])
	-- 	local achievementCount = tonumber(params[15])
	-- 	local achievementRefAchievement = tonumber(params[16])
	-- 	local achievementCategoryName = params[17]
	-- 	local achievementCategoryNameFlags = tonumber(params[18])
	-- 	local achievementCategorySortOrder = tonumber(params[19])

	-- 	local icon = 'Interface\\AddOns\\Achiever\\textures\\' .. iconTable[achievementIcon]

	-- 	achieverLibnotify:ShowPopup(achievementName, '', achievementPoints, icon, 2)
	-- elseif (params[2] == "ACU") then
	-- 	local criteriaId = tonumber(params[3])
	-- 	local criteriaRefAchievement = tonumber(params[4])
	-- 	local criteriaProgressCounter = tonumber(params[5])
	-- 	local criteriaTimestamp = tonumber(params[6])
	-- end
-- end

function Achiever:CHAT_MSG_CHANNEL_LEAVE()
	Achiever.checkAndJoinAchieverChannel()
end

function Achiever:CHAT_MSG_ADDON()
	if arg1 ~= Achiever.channel then return end
	-- process addon messages like version out of date or achievement / criteria data requests or title changes ...
end

function Achiever:CHAT_MSG_CHANNEL_NOTICE()
	if arg9 == Achiever.channel and arg1 == 'YOU_JOINED' then
		Achiever.channelIndex = arg8
	end
end

function Achiever.checkAndJoinAchieverChannel()
    local lastVal = 0
    local chanList = { GetChannelList() }

    for _, value in next, chanList do
        if value == Achiever.channel then
            Achiever.channelIndex = lastVal
            break
        end
        lastVal = value
    end

    if Achiever.channelIndex == 0 then
        --lfdebug('not in chan, joining')
        JoinChannelByName(Achiever.channel)
    else
        --lfdebug('in chan, chilling LFT.channelIndex = ' .. LFT.channelIndex)
    end
end


function processServerMessage()
	local params = split(arg1, "|")
	if (params[1] ~= "ACHI") then return end
	if (params[2] == "AE") then
		local achievementId = tonumber(params[3])

		local breadcrumbs = split(params[4], '/')
		local breadcrumbsSize = table.getn(breadcrumbs)
		local achievementName = breadcrumbs[breadcrumbsSize - 1]

		local achievementNameFlags = tonumber(params[5])
		local achievementDescription = params[6]
		local achievementDescriptionFlags = tonumber(params[7])
		local achievementCategoryId = tonumber(params[8])
		local achievementPoints = tonumber(params[9])
		local achievementOrderInCategory = tonumber(params[10])
		local achievementFlags = tonumber(params[11])
		local achievementIcon = tonumber(params[12])
		local achievementTitleReward = params[13]
		local achievementTitleRewardFlags = tonumber(params[14])
		local achievementCount = tonumber(params[15])
		local achievementRefAchievement = tonumber(params[16])
		local achievementCategoryName = params[17]
		local achievementCategoryNameFlags = tonumber(params[18])
		local achievementCategorySortOrder = tonumber(params[19])

		local icon = 'Interface\\AddOns\\Achiever\\textures\\' .. iconTable[achievementIcon]

		achieverLibnotify:ShowPopup(achievementName, '', achievementPoints, icon, 2)
	elseif (params[2] == "ACU") then
		local criteriaId = tonumber(params[3])
		local criteriaRefAchievement = tonumber(params[4])
		local criteriaProgressCounter = tonumber(params[5])
		local criteriaTimestamp = tonumber(params[6])
	end
end
