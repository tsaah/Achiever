local _G = getfenv(0)
local function warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf3f3f66cWARN: |cffff55ff'.. (msg or 'nil'))
end

local config = {}
config.alert = {}
config.alert.anchor = {}
config.alert.anchor.parentSide = 'BOTTOM'
config.alert.anchor.x = 0
config.alert.anchor.y = 140
config.alert.growUp = false
config.alert.max = 5
config.alert.tryAttachToRollFrame = false

-- Real Blizzard global on 1.14.2 (core AlertFrames.lua, = 2), read by
-- Blizzard's own DungeonCompletionAlertFrame_FixAnchors/
-- AchievementAlertFrame_GetAlertFrame as a loop bound over its own
-- AchievementAlertFrameN-named frames -- unrelated to Achiever's own
-- AchieverAchievementAlertFrameN pool (sized via config.alert.max directly,
-- never reads this global), so there's no reason to touch it there at all.
MAX_ACHIEVEMENT_ALERTS = MAX_ACHIEVEMENT_ALERTS or config.alert.max;

function Achiever_AlertFrame_ShowAchievementEarned(id)
	if (id == nil) then
		warn(ACHIEVER_WARN_NO_ACHIEVEMENT_ID)
		return
	end
	local _, name = Achiever_GetAchievementInfo(tonumber(id))
	if (not name or name == ACHIEVER_INVALID_ACHIEVEMENT_NAME) then
		warn(format(ACHIEVER_WARN_NO_ACHIEVEMENT_WITH_ID, id))
		return
	end
	AchieverAchievementAlertFrame_ShowAlert(tonumber(id))
end

function Achiever_AlertFrame_FixAnchors()
	AchieverAchievementAlertFrame_FixAnchors();
end

function Achiever_AlertFrame_AnimateIn(frame)
	-- Wrapped in a closure over the already-known-good `frame` rather than
	-- registered directly -- 1.12.1 passes OnUpdate scripts exactly one
	-- argument (elapsed time), never the frame (confirmed via Blizzard's own
	-- FrameXML, e.g. WorldFrame.lua's WorldFrame_OnUpdate(elapsed); see the
	-- matching comment on Achiever.lua's Achiever_SendHandshake for the full
	-- writeup). Registering AchieverAchievementAlertFrame_OnUpdate directly as
	-- the raw script let that stray elapsed number land in its own `frame`
	-- parameter, masking the real frame. Calling it explicitly here instead
	-- means it always receives the real frame as an ordinary Lua argument.
	frame:SetScript("OnUpdate", function()
		AchieverAchievementAlertFrame_OnUpdate(frame)
	end);
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

function Achiever_AlertFrame_StopOutAnimation(frame)
	frame.wait = true
end

function Achiever_AlertFrame_ResumeOutAnimation(frame)
	frame.wait = false
end

-- [[ AchieverAchievementAlertFrame ]] --
-- Guard against a non-Frame this -- see AchievementIcon_OnLoad's matching
-- guard comment (AchievementUI.lua, top of file). Also called explicitly by
-- AchieverAchievementAlertFrame_GetAlertFrame as a reliable fallback, since
-- this template is instantiated via a dynamic Lua-side CreateFrame() call.
function AchieverAchievementAlertFrame_OnLoad(frame)
	local this = frame or this;
	if (type(this) ~= "table" or not this.GetName) then return; end

	this.glow = _G[this:GetName() .. "Glow"];
	this.shine = _G[this:GetName() .. "Shine"];
	this:RegisterForClicks("LeftButtonUp");
end

function AchieverAchievementAlertFrame_FixAnchors()
	-- Temporary (here's hoping) workaround so that achievement alerts are anchored to loot roll windows. Eventually we want one system to handle placement for both alerts.
	if ( not AchieverAchievementAlertFrame1 ) then
		-- We haven't displayed any achievement alerts yet, so there's nothing to reanchor (read: this got called by LootFrame.lua)
		return;
	end
	if (not config.alert.tryAttachToRollFrame) then return end

	for i=NUM_GROUP_LOOT_FRAMES, 1, -1  do
		local frame = _G["GroupLootFrame"..i];
		if ( frame and frame:IsShown() ) then
			AchieverAchievementAlertFrame1:SetPoint("BOTTOM", frame, "TOP", 0, 10);
			return;
		end
	end

	AchieverAchievementAlertFrame1:SetPoint("BOTTOM", UIParent, config.alert.anchor.parentSide, config.alert.anchor.x, config.alert.anchor.y);
end

function AchieverAchievementAlertFrame_ShowAlert (achievementID)
	PlaySoundFile([[Interface\AddOns\Achiever\sounds\AchievementEarned.mp3]], 'SFX');
	local frame = AchieverAchievementAlertFrame_GetAlertFrame();
	local _, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(achievementID);
	if ( not frame ) then
		-- We ran out of frames! Bail!
		return;
	end

	_G[frame:GetName() .. "Name"]:SetText(name);

	local shield = _G[frame:GetName() .. "Shield"];
	-- Explicit fallback for AchieverAchievementShield_OnLoad (sets
	-- shield.points/.icon, used just below) -- same dynamic-CreateFrame
	-- risk as AchieverAchievementAlertFrame_OnLoad above.
	if ( not shield.points ) then
		AchieverAchievementShield_OnLoad(shield);
	end
	AchieverAchievementShield_SetPoints(points, shield.points, GameFontNormal, GameFontNormalSmall);
	if ( points == 0 ) then
		shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
	else
		shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
	end

	if (icon) then
		_G[frame:GetName() .. "IconTexture"]:SetTexture(icon);
	end

	frame.id = achievementID;

	Achiever_AlertFrame_AnimateIn(frame);

	Achiever_AlertFrame_FixAnchors();
end

function AchieverAchievementAlertFrame_GetAlertFrame()
	local name, frame, previousFrame;
	for i=1, config.alert.max do
		name = "AchieverAchievementAlertFrame"..i;
		frame = _G[name];
		if ( frame ) then
			if ( not frame:IsShown() ) then
				return frame;
			end
		else
			frame = CreateFrame("Button", name, UIParent, "AchieverAchievementAlertFrameTemplate");
			-- Explicit fallback for AchieverAchievementAlertFrame_OnLoad --
			-- see that function's own comment. Gated on `not frame.glow` so
			-- this is a no-op on a frame whose own OnLoad already worked.
			if ( not frame.glow ) then
				AchieverAchievementAlertFrame_OnLoad(frame);
			end
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

function AchieverAchievementAlertFrame_OnClick(frame, button, down)
	local this = frame or this;
	local id = this.id;
	if ( not id ) then
		return;
	end

	CloseAllWindows();
	ShowUIPanel(AchieverAchievementFrame);

	local _, _, _, achCompleted = Achiever_GetAchievementInfo(id);
	if ( achCompleted and (ACHIEVEMENTUI_SELECTEDFILTER == AchieverAchievementFrameFilters[ACHIEVEMENT_FILTER_INCOMPLETE].func) ) then
		AchieverAchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	elseif ( (not achCompleted) and (ACHIEVEMENTUI_SELECTEDFILTER == AchieverAchievementFrameFilters[ACHIEVEMENT_FILTER_COMPLETE].func) ) then
		AchieverAchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	end

	AchieverAchievementFrame_SelectAchievement(id)
end

function AchieverAchievementAlertFrame_OnHide()
	Achiever_AlertFrame_FixAnchors();
end

function AchieverAchievementAlertFrame_OnUpdate(frame)
	-- `frame` is always the real frame now -- Achiever_AlertFrame_AnimateIn
	-- calls this explicitly via a closure rather than registering it as the
	-- raw OnUpdate script, so no `or this` fallback is needed (that fallback
	-- was exactly what let a stray elapsed-time number masquerade as the
	-- frame on 1.12.1 when this was registered directly).
	local this = frame;
	local newFrameTime = GetTime()
	local elapsed = newFrameTime - this.oldFrameTime
	this.oldFrameTime = newFrameTime

	local state = this.state;
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
