local _G, _ = _G or getfenv()
local function warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf3f3f66cWARN: |cffff55ff'.. (msg or 'nil'))
end

SLASH_ACHIEVERALERT1 = "/acal"
SlashCmdList.ACHIEVERALERT = function(id)
	AlertFrame_ShowAchievementEarned(tonumber(id))
end

local config = {}

-- original values
-- config.alert = {}
-- config.alert.anchor = {}
-- config.alert.anchor.parentSide = 'BOTTOM'
-- config.alert.anchor.x = 0
-- config.alert.anchor.y = 128
-- config.alert.growUp = true
-- config.alert.max = 2
-- config.alert.tryAttachToRollFrame = true


-- my values
config.alert = {}
config.alert.anchor = {}
config.alert.anchor.parentSide = 'TOP'
config.alert.anchor.x = 0
config.alert.anchor.y = -216
config.alert.growUp = false
config.alert.max = 5
config.alert.tryAttachToRollFrame = false

MAX_ACHIEVEMENT_ALERTS = config.alert.max;

function AlertFrame_ShowAchievementEarned(id)
	if (id == nil) then
        warn('provide an achievement id')
        return
    end
    local x = achieverDB.achievements.data[tonumber(id)]
    if (x == nil) then
        warn('no achievement with id ' .. id)
        return
    end
	-- if ( not AchievementFrame ) then
	-- 	AchievementFrame_LoadUI();
	-- end
	AchievementAlertFrame_ShowAlert(tonumber(id))
end

function AlertFrame_FixAnchors()
	AchievementAlertFrame_FixAnchors();
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
	-- frame.waitAndAnimOut:Stop();
	-- frame.waitAndAnimOut.animOut:SetStartDelay(1);
end

function AlertFrame_ResumeOutAnimation(frame)
	frame.wait = false
	-- frame.waitAndAnimOut:Play();
end

-- [[ AchievementAlertFrame ]] --
function AchievementAlertFrame_OnLoad (self)
	self.glow = _G[self:GetName() .. "Glow"];
	self.shine = _G[self:GetName() .. "Shine"];
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
	PlaySoundFile([[Interface\AddOns\Achiever\sounds\AchievementEarned.mp3]], 'SFX');
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

	if (icon) then
		local iconFromTable = iconTable[icon]
		if (iconFromTable) then
			_G[frame:GetName() .. "IconTexture"]:SetTexture(iconFromTable);
			_G[frame:GetName() .. "IconTexture"]:SetTexture([[Interface\AddOns\Achiever\textures\]] .. iconFromTable);
		end
	end

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

function AchievementAlertFrame_OnUpdate(self)
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
