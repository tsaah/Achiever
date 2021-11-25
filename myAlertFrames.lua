SLASH_ACHIEALERT1 = '/ac'
function SlashCmdList.ACHIEALERT(msg, editbox)
	JoinChannelByName('ACHIEVER')
	SendChatMessage('msg SendChatMessage', 'CHANNEL', DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName('ACHIEVER'))
	AchievementAlertFrame_ShowAlert(6)
	-- DungeonCompletionAlertFrame_ShowAlert();
end

local _G = getfenv(0)

-- ----------- CONFIG

local config = {}

-- config.alert = {}
-- config.alert.anchor = {}
-- config.alert.anchor.parentSide = 'BOTTOM'
-- config.alert.anchor.x = 0
-- config.alert.anchor.y = 128
-- config.alert.growUp = true
-- config.alert.max = 2
-- config.alert.tryAttachToRollFrame = true

config.alert = {}
config.alert.anchor = {}
config.alert.anchor.parentSide = 'TOP'
config.alert.anchor.x = 0
config.alert.anchor.y = -216
config.alert.growUp = false
config.alert.max = 5
config.alert.tryAttachToRollFrame = false


-----------------

function AlertFrame_OnLoad (self)
	self:RegisterEvent("ACHIEVEMENT_EARNED");
	-- self:RegisterEvent("LFG_COMPLETION_REWARD");
end

function AchievementAlertFrameIcon_OnLoad()
	local name = this:GetName();
	this.bling = getfenv(0)[name .. "Bling"];
	this.texture = getfenv(0)[name .. "Texture"];
	this.frame = getfenv(0)[name .. "Overlay"];

	this.Desaturate =
		function (this)
			this.bling:SetVertexColor(.6, .6, .6, 1);
			this.frame:SetVertexColor(.75, .75, .75, 1);
			this.texture:SetVertexColor(.55, .55, .55, 1);
		end

	this.Saturate =
		function (this)
			this.bling:SetVertexColor(1, 1, 1, 1);
			this.frame:SetVertexColor(1, 1, 1, 1);
			this.texture:SetVertexColor(1, 1, 1, 1);
		end
end

function AlertFrame_OnEvent(self, event, ...)
	if ( event == "ACHIEVEMENT_EARNED" ) then
		local id = arg1;

		if ( not AchievementFrame ) then
			AchievementFrame_LoadUI();
		end

		AchievementAlertFrame_ShowAlert(id);
	-- elseif ( event == "LFG_COMPLETION_REWARD" ) then
		-- DungeonCompletionAlertFrame_ShowAlert();
	end
end

function AlertFrame_FixAnchors()
	AchievementAlertFrame_FixAnchors();
	-- DungeonCompletionAlertFrame_FixAnchors();
end

function AlertFrame_AnimateIn(frame)
	frame:SetScript("OnUpdate", AchievementAlertFrame_OnUpdate);
	frame.oldFrameTime = GetTime()
	frame.elapsed = 0
	frame.fadeinDuration = 0.2;
	frame.flashDuration = 0.5;
	frame.shineStartTime = 0.3;
	frame.shineDuration = 0.85;
	frame.holdDuration = 3;
	frame.fadeoutDuration = 1.5;
	frame.wait = false
	frame:Show();
end

function AlertFrame_StopOutAnimation(frame)
	frame.wait = true
end

function AlertFrame_ResumeOutAnimation(frame)
	frame.wait = false
end

-- [[ AchievementAlertFrame ]] --
function AchievementAlertFrame_OnLoad(self)
	self.glow = getfenv(0)[self:GetName() .. "Glow"];
	self.shine = getfenv(0)[self:GetName() .. "Shine"];
	self:RegisterForClicks("LeftButtonUp");
end

function AchievementAlertFrame_FixAnchors ()
	-- Temporary (here's hoping) workaround so that achievement alerts are anchored to loot roll windows. Eventually we want one system to handle placement for both alerts.
	if ( not AchievementAlertFrame1 ) then
		-- We haven't displayed any achievement alerts yet, so there's nothing to reanchor (read: this got called by LootFrame.lua)
		return;
	end
	if (not config.alert.tryAttachToRollFrame) then return end

	for i=NUM_GROUP_LOOT_FRAMES, 1, -1  do
		local frame = _G["GroupLootFrame"..i];
		if ( frame and frame:IsShown() ) then
			AchievementAlertFrame1:SetPoint("BOTTOM", frame, "TOP", 0, 10);
			return;
		end
	end

	AchievementAlertFrame1:SetPoint("BOTTOM", UIParent, config.alert.anchor.parentSide, config.alert.anchor.x, config.alert.anchor.y);
end

function AchievementAlertFrame_ShowAlert (achievementID)
	local frame = AchievementAlertFrame_GetAlertFrame();
	local _, name, points, completed, month, day, year, description, flags, icon = GetAchievementInfo(achievementID);
	if ( not frame ) then
		-- We ran out of frames! Bail!
		return;
	end

	_G[frame:GetName() .. "Name"]:SetText(name);

	local shield = _G[frame:GetName() .. "Shield"];
	AchievementShield_SetPoints(points, shield.points, GameFontNormal, GameFontNormalSmall);
	if ( points == 0 ) then
		shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
	else
		shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
	end

	_G[frame:GetName() .. "IconTexture"]:SetTexture(icon);

	frame.id = achievementID;

	AlertFrame_AnimateIn(frame);

	AlertFrame_FixAnchors();
end

function AchievementAlertFrame_GetAlertFrame()
	local name, frame, previousFrame;
	for i=1, config.alert.max do
		name = "AchievementAlertFrame"..i;
		frame = _G[name];
		if ( frame ) then
			if ( not frame:IsShown() ) then
				return frame;
			end
		else
			frame = CreateFrame("Button", name, UIParent, "AchievementAlertFrameTemplate");
			if ( not previousFrame ) then
				frame:SetPoint("BOTTOM", UIParent, config.alert.anchor.parentSide, config.alert.anchor.x, config.alert.anchor.y);
			else
				if (config.alert.growUp) then
					frame:SetPoint("BOTTOM", previousFrame, "TOP", 0, -10);
				else
					frame:SetPoint("BOTTOM", previousFrame, "BOTTOM", 0, -88);
				end
			end
			return frame;
		end
		previousFrame = frame;
	end
	return nil;
end

function AchievementAlertFrame_OnClick (self)
	local id = self.id;
	if ( not id ) then
		return;
	end

	CloseAllWindows();
	ShowUIPanel(AchievementFrame);

	local _, _, _, achCompleted = GetAchievementInfo(id);
	if ( achCompleted and (ACHIEVEMENTUI_SELECTEDFILTER == AchievementFrameFilters[ACHIEVEMENT_FILTER_INCOMPLETE].func) ) then
		AchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	elseif ( (not achCompleted) and (ACHIEVEMENTUI_SELECTEDFILTER == AchievementFrameFilters[ACHIEVEMENT_FILTER_COMPLETE].func) ) then
		AchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	end

	AchievementFrame_SelectAchievement(id)
end

function AchievementAlertFrame_OnHide (self)
	AlertFrame_FixAnchors();
end
-------------------
function AchievementAlertFrame_OnUpdate()
	local newFrameTime = GetTime()
	local elapsed = newFrameTime - this.oldFrameTime
	this.oldFrameTime = newFrameTime

	local state = this.state;
	local alpha;
	local deltaTime = elapsed;
	--initialize
	if ( not state ) then
		state = "fadein";
		this.glow:Show();
		this.glow:SetAlpha(0);
		this.totalElapsed = 0;
	end
	this.totalElapsed = this.totalElapsed+elapsed;
	elapsed = this.elapsed + elapsed;
	if ( state == "fadein" ) then
		if ( elapsed >= this.fadeinDuration ) then
			state = "flash";
			elapsed = 0;
			this:SetAlpha(1);
			this.glow:Show();
		else
			this:SetAlpha(elapsed/this.fadeinDuration);
			this.glow:SetAlpha(elapsed/this.fadeinDuration);
		end
	elseif ( state == "flash" ) then
		if ( elapsed >= this.flashDuration ) then
			state = "hold";
			elapsed = 0;
			this.glow:Hide();
		else
			this.glow:SetAlpha(1-(elapsed/this.flashDuration));
		end
	elseif ( state == "hold" and not this.wait) then
		if ( elapsed >= this.holdDuration ) then
			state = "fadeout";
			elapsed = 0;
		end
	elseif ( state == "fadeout" and not this.wait) then
		if ( elapsed >= this.fadeoutDuration ) then
			state = nil;
			this:SetScript("OnUpdate", nil);
			this:Hide();
			this.id = nil;
		else
			this:SetAlpha(1-(elapsed/this.fadeoutDuration));
		end
	end

	--Handle shine
	local normalizedTime = this.totalElapsed - this.shineStartTime;
	if ( normalizedTime >= 0 and normalizedTime <= this.shineDuration ) then
		if ( not this.shine:IsShown() ) then
			this.shine:Show();
			this.shine:SetPoint("TOPLEFT", this, "TOPLEFT", 0, -8);
			this.shine:SetAlpha(1);
		end
		local target = 239;
		local _,_,_,x = this.shine:GetPoint();
		if ( x ~= target ) then
			x = x +(target-x)*(deltaTime/(this.shineDuration/3));
			if ( floor(abs(target - x)) == 0 ) then
				x = target;
			end
		end

		this.shine:SetPoint("TOPLEFT", this, "TOPLEFT", x, -8);
		this.shine:SetAlpha(1);
		local startShineFade = 0.8*this.shineDuration;
		if ( normalizedTime >= startShineFade ) then
			this.shine:SetAlpha(1-((normalizedTime-startShineFade)/(this.shineDuration-startShineFade)));
		end
	else
		if ( this.shine:IsShown() ) then
			this.shine:Hide();
			this.vel = nil;
		end
	end

	this.state = state;
	this.elapsed = elapsed;
end


-- [[ DungeonCompletionAlertFrame ]] --
-- function DungeonCompletionAlertFrame_OnLoad(frame)
-- 	frame.glow = frame.glowFrame.glow;
-- end

-- function DungeonCompletionAlertFrame_FixAnchors()
-- 	for i=config.alert.max, 1, -1 do
-- 		local frame = _G["AchievementAlertFrame"..i];
-- 		if ( frame and frame:IsShown() ) then
-- 			DungeonCompletionAlertFrame1:SetPoint("BOTTOM", frame, "TOP", 0, 10);
-- 			return;
-- 		end
-- 	end

-- 	for i=NUM_GROUP_LOOT_FRAMES, 1, -1 do
-- 		local frame = _G["GroupLootFrame"..i];
-- 		if ( frame and frame:IsShown() ) then
-- 			DungeonCompletionAlertFrame1:SetPoint("BOTTOM", frame, "TOP", 0, 10);
-- 			return;
-- 		end
-- 	end

-- 	DungeonCompletionAlertFrame1:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128);
-- end

-- DUNGEON_COMPLETION_MAX_REWARDS = 1;
-- function DungeonCompletionAlertFrame_ShowAlert()
-- 	PlaySound("LFG_Rewards");
-- 	local frame = DungeonCompletionAlertFrame1;
-- 	--For now we only have 1 dungeon alert frame. If you're completing more than one dungeon within ~5 seconds, tough luck.
-- 	local name, typeID, textureFilename, moneyBase, moneyVar, experienceBase, experienceVar, numStrangers, numRewards= GetLFGCompletionReward();


-- 	--Set up the rewards
-- 	local moneyAmount = moneyBase + moneyVar * numStrangers;
-- 	local experienceGained = experienceBase + experienceVar * numStrangers;

-- 	local rewardsOffset = 0;

-- 	if ( moneyAmount > 0 or experienceGained > 0 ) then --hasMiscReward ) then
-- 		SetPortraitToTexture(DungeonCompletionAlertFrame1Reward1.texture, "Interface\\Icons\\inv_misc_coin_02");
-- 		DungeonCompletionAlertFrame1Reward1.rewardID = 0;
-- 		DungeonCompletionAlertFrame1Reward1:Show();

-- 		rewardsOffset = 1;
-- 	end

-- 	for i = 1, numRewards do
-- 		local frameID = (i + rewardsOffset);
-- 		local reward = _G["DungeonCompletionAlertFrame1Reward"..frameID];
-- 		if ( not reward ) then
-- 			reward = CreateFrame("FRAME", "DungeonCompletionAlertFrame1Reward"..frameID, DungeonCompletionAlertFrame1, "DungeonCompletionAlertFrameRewardTemplate");
-- 			reward:SetID(frameID);
-- 			DUNGEON_COMPLETION_MAX_REWARDS = frameID;
-- 		end
-- 		DungeonCompletionAlertFrameReward_SetReward(reward, i);
-- 	end

-- 	local usedButtons = numRewards + rewardsOffset;
-- 	--Hide the unused ones
-- 	for i = usedButtons + 1, DUNGEON_COMPLETION_MAX_REWARDS do
-- 		_G["DungeonCompletionAlertFrame1Reward"..i]:Hide();
-- 	end

-- 	if ( usedButtons > 0 ) then
-- 		--Set up positions
-- 		local spacing = 36;
-- 		DungeonCompletionAlertFrame1Reward1:SetPoint("TOP", DungeonCompletionAlertFrame1, "TOP", -spacing/2 * usedButtons + 41, 0);
-- 		for i = 2, usedButtons do
-- 			_G["DungeonCompletionAlertFrame1Reward"..i]:SetPoint("CENTER", "DungeonCompletionAlertFrame1Reward"..(i - 1), "CENTER", spacing, 0);
-- 		end
-- 	end

-- 	--Set up the text and icons.

-- 	frame.instanceName:SetText(name);
-- 	if ( typeID == TYPEID_HEROIC_DIFFICULTY ) then
-- 		frame.heroicIcon:Show();
-- 		frame.instanceName:SetPoint("TOP", 33, -44);
-- 	else
-- 		frame.heroicIcon:Hide();
-- 		frame.instanceName:SetPoint("TOP", 25, -44);
-- 	end

-- 	frame.dungeonTexture:SetTexture("Interface\\LFGFrame\\LFGIcon-"..textureFilename);

-- 	AlertFrame_AnimateIn(frame)


-- 	AlertFrame_FixAnchors();
-- end

-- function DungeonCompletionAlertFrameReward_SetReward(frame, index)
-- 	local texturePath, quantity = GetLFGCompletionRewardItem(index);
-- 	SetPortraitToTexture(frame.texture, texturePath);
-- 	frame.rewardID = index;
-- 	frame:Show();
-- end

-- function DungeonCompletionAlertFrameReward_OnEnter(self)
-- 	AlertFrame_StopOutAnimation(self:GetParent());

-- 	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
-- 	if ( self.rewardID == 0 ) then
-- 		GameTooltip:AddLine(YOU_RECEIVED);
-- 		local name, typeID, textureFilename, moneyBase, moneyVar, experienceBase, experienceVar, numStrangers, numRewards = GetLFGCompletionReward();

-- 		local moneyAmount = moneyBase + moneyVar * numStrangers;
-- 		local experienceGained = experienceBase + experienceVar * numStrangers;

-- 		if ( experienceGained > 0 ) then
-- 			GameTooltip:AddLine(string.format(GAIN_EXPERIENCE, experienceGained));
-- 		end
-- 		if ( moneyAmount > 0 ) then
-- 			SetTooltipMoney(GameTooltip, moneyAmount, nil);
-- 		end
-- 	else
-- 		GameTooltip:SetLFGCompletionReward(self.rewardID);
-- 	end
-- 	GameTooltip:Show();
-- end

-- function DungeonCompletionAlertFrameReward_OnLeave(frame)
-- 	AlertFrame_ResumeOutAnimation(frame:GetParent());
-- 	GameTooltip:Hide();
-- end
