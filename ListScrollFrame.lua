-- Native-widget replacement for WotLK's AchieverHybridScrollFrame system (which has
-- no 1.12 equivalent at all). Rather than porting that file, this
-- reimplements the same function contract (AchieverHybridScrollFrame_CreateButtons/
-- _GetOffset/_Update/_ExpandButton/_CollapseButton/_OnMouseWheel) that
-- AchievementUI.lua already calls, built on 1.12's own ScrollFrame + Slider
-- widgets (the same approach pfUI/api/ui-widgets.lua's CreateScrollFrame
-- uses), so the achievement UI's list-management code needs no changes.
--
-- These are plain helper functions called explicitly with the scroll frame
-- as their first argument (not frame script handlers), so they don't need
-- the implicit this/event/arg1 treatment the rest of the backport does.

local function round(num) return math.floor(num + 0.5); end

function AchieverHybridScrollFrame_UpdateButtonStates(self)
	self.scrollBar:Show();
end

function AchieverHybridScrollFrame_SetOffset(self, offset)
	-- Lists too small to need button recycling (see AchieverHybridScrollFrame_CreateButtons'
	-- exactCount param) opt out of the virtualized element/overflow math entirely:
	-- every row already has its own permanent button, so scrolling is just a plain
	-- pixel offset with nothing to re-populate.
	if (self.noVirtualize) then
		self.offset = offset;
		self:SetVerticalScroll(offset);
		return;
	end

	local buttonHeight = self.buttonHeight;
	local element, overflow, scrollHeight;

	local largeButtonTop = self.largeButtonTop;
	if largeButtonTop and offset >= largeButtonTop then
		local largeButtonHeight = self.largeButtonHeight;
		element = largeButtonTop / buttonHeight;
		if offset >= (largeButtonTop + largeButtonHeight) then
			element = element + 1;
			local leftovers = offset - (largeButtonTop + largeButtonHeight);
			element = element + (leftovers / buttonHeight);
			overflow = element - math.floor(element);
			scrollHeight = overflow * buttonHeight;
		else
			scrollHeight = math.abs(offset - largeButtonTop);
		end
	else
		element = offset / buttonHeight;
		overflow = element - math.floor(element);
		scrollHeight = overflow * buttonHeight;
	end

	if math.floor(self.offset or 0) ~= math.floor(element) and self.update then
		self.offset = element;
		self.update();
	else
		self.offset = element;
	end

	self:SetVerticalScroll(scrollHeight);
end

function AchieverHybridScrollFrame_OnValueChanged(self, value)
	AchieverHybridScrollFrame_SetOffset(self, value);
	AchieverHybridScrollFrame_UpdateButtonStates(self);
end

function AchieverHybridScrollFrame_OnMouseWheel(self, delta, stepSize)
	if not self.scrollBar:IsVisible() then return; end
	local minVal, maxVal = 0, self.range or 0;
	stepSize = stepSize or self.buttonHeight or 16;
	if delta > 0 then
		self.scrollBar:SetValue(math.max(minVal, self.scrollBar:GetValue() - stepSize));
	else
		self.scrollBar:SetValue(math.min(maxVal, self.scrollBar:GetValue() + stepSize));
	end
end

function AchieverHybridScrollFrame_GetOffset(self)
	return math.floor(self.offset or 0), (self.offset or 0);
end

function AchieverHybridScrollFrame_ExpandButton(self, offset, height)
	self.largeButtonTop = round(offset);
	self.largeButtonHeight = round(height);
	AchieverHybridScrollFrame_SetOffset(self, self.scrollBar:GetValue());
end

function AchieverHybridScrollFrame_CollapseButton(self)
	self.largeButtonTop = nil;
	self.largeButtonHeight = nil;
end

function AchieverHybridScrollFrame_Update(self, totalHeight, displayedHeight)
	local range = totalHeight - self:GetHeight();
	if range > 0 and self.scrollBar then
		local minVal, maxVal = self.scrollBar:GetMinMaxValues();
		if math.floor(self.scrollBar:GetValue()) >= math.floor(maxVal) then
			self.scrollBar:SetMinMaxValues(0, range);
			if math.floor(self.scrollBar:GetValue()) ~= math.floor(range) then
				self.scrollBar:SetValue(range);
			else
				AchieverHybridScrollFrame_SetOffset(self, range);
			end
		else
			self.scrollBar:SetMinMaxValues(0, range);
		end
		self.scrollBar:Show();
	elseif self.scrollBar then
		self.scrollBar:SetValue(0);
		self.scrollBar:Hide();
	end

	self.range = range;
	(self.scrollChild or self:GetScrollChild()):SetHeight(displayedHeight);
	-- Without this, the engine's cached scrollable range stays stuck at
	-- whatever it was computed as during OnLoad (the scroll child has no
	-- <Size> in XML, i.e. 0x0 at that point) -- SetVerticalScroll(offset > 0)
	-- then silently clamps back to 0 forever, no error, nothing visibly
	-- scrolls. Confirmed required/standard 1.12.1 API by pfQuest/quest.lua's
	-- own QuestLogDetailScrollFrame:UpdateScrollChildRect() call after
	-- resizing its scroll child the same way.
	self:UpdateScrollChildRect();
end

-- exactCount: for lists small enough to give every row its own permanent
-- button (see the "noVirtualize" flag above) instead of sizing the pool to
-- the viewport and recycling buttons as the user scrolls.
function AchieverHybridScrollFrame_CreateButtons(self, buttonTemplate, initialOffsetX, initialOffsetY, initialPoint, initialRelative, offsetX, offsetY, point, relativePoint, exactCount)
	-- self.scrollChild is set by AchieverHybridScrollFrameScrollChild_OnLoad (below),
	-- which races against whatever code calls this function during the same
	-- OnLoad chain -- confirmed losing that race for at least one container on
	-- 1.14.2 (scrollChild still nil here), producing parentless buttons that
	-- silently ignore their container's hidden state. GetScrollChild() is the
	-- engine's own native accessor for the <ScrollChild> XML element -- set
	-- during structural construction, before any OnLoad script runs at all --
	-- so it's immune to the race. Already used the same way elsewhere in this
	-- addon (AchievementUI.lua's AchieverAchievementFrameCategoriesContainer
	-- calls), confirmed working on 1.12.1 too.
	local scrollChild = self.scrollChild or self:GetScrollChild();
	local button, buttonHeight, buttons;

	local buttonName = self:GetName() .. "Button";

	initialPoint = initialPoint or "TOPLEFT";
	initialRelative = initialRelative or "TOPLEFT";
	point = point or "TOPLEFT";
	relativePoint = relativePoint or "BOTTOMLEFT";
	offsetX = offsetX or 0;
	offsetY = offsetY or 0;

	if self.buttons then
		buttons = self.buttons;
		buttonHeight = buttons[1]:GetHeight();
	else
		button = CreateFrame("Button", buttonName .. "1", scrollChild, buttonTemplate);
		buttonHeight = button:GetHeight();
		button:SetPoint(initialPoint, scrollChild, initialRelative, initialOffsetX, initialOffsetY);
		buttons = {};
		table.insert(buttons, button);
	end

	self.buttonHeight = round(buttonHeight);

	local numButtons = exactCount or (math.ceil(self:GetHeight() / buttonHeight) + 1);

	for i = table.getn(buttons) + 1, numButtons do
		button = CreateFrame("Button", buttonName .. i, scrollChild, buttonTemplate);
		button:SetPoint(point, buttons[i - 1], relativePoint, offsetX, offsetY);
		table.insert(buttons, button);
	end

	scrollChild:SetWidth(self:GetWidth());
	scrollChild:SetHeight(numButtons * buttonHeight);
	self:SetVerticalScroll(0);
	-- See the matching comment in AchieverHybridScrollFrame_Update -- same
	-- "engine's cached scrollable range never gets refreshed" clamp-to-0 bug.
	self:UpdateScrollChildRect();

	self.buttons = buttons;
	-- self.scrollBar is set by AchieverHybridScrollFrameScrollBar_OnLoad as an
	-- OnLoad side effect of the nested Slider -- same OnLoad-ordering race
	-- already found (and fixed via GetScrollChild()) for self.scrollChild
	-- above; _G fallback by name is immune to it the same way.
	local scrollBar = self.scrollBar or _G[self:GetName() .. "ScrollBar"];
	scrollBar:SetMinMaxValues(0, numButtons * buttonHeight);
	scrollBar:SetValueStep(1);
	scrollBar:SetValue(0);
end

-- Script handlers wired from ListScrollFrame.xml (real frame scripts, so
-- these use the implicit this/arg1 convention).
function AchieverHybridScrollFrame_OnLoad(frame)
	frame = frame or this;
	frame:EnableMouse(true);
	-- Unlike WotLK's real client, this one doesn't fire OnMouseWheel on a
	-- frame just because it has that script -- EnableMouseWheel has to be
	-- called explicitly (confirmed by AchievementCategoryButton_OnLoad
	-- already needing it for per-row scrolling); without this, the
	-- OnMouseWheel handler AchieverHybridScrollFrameTemplate declares in
	-- ListScrollFrame.xml never actually fires.
	frame:EnableMouseWheel(true);
	-- Attached here (not left as this template's own inline <OnMouseWheel>
	-- body, now dead code) -- see AchieverHybridScrollFrameScrollBar_OnLoad below for
	-- why: arg1 isn't reliably bound in inline script bodies beyond self.
	frame:SetScript("OnMouseWheel", function(sf, delta)
		sf = sf or this;
		delta = delta or arg1;
		AchieverHybridScrollFrame_OnMouseWheel(sf, delta);
	end);
end

-- Takes an explicit frame argument (wired from ListScrollFrame.xml as
-- AchieverHybridScrollFrameScrollChild_OnLoad(self)) instead of relying on the
-- implicit `this` global -- confirmed via live 1.14.2 testing that `this`
-- comes back nil unpredictably across many kinds of elements (not just this
-- one), throwing "attempt to index global 'this' (a nil value)". `self` is
-- the modern engine's own proper binding for "the frame this script is
-- attached to" and has proven reliable everywhere `this` isn't; falls back
-- to `this` so 1.12.1 (where inline XML scripts never bind `self` at all)
-- keeps working unchanged. (Separately: arg1 and other positional script
-- arguments beyond self are ALSO not reliably bound in inline script bodies
-- -- see AchieverHybridScrollFrameScrollBar_OnLoad below, which works around that
-- one by attaching handlers via SetScript with a real-parameter fallback
-- instead of reading arg1 directly in XML.)
function AchieverHybridScrollFrameScrollChild_OnLoad(frame)
	frame = frame or this;
	frame:GetParent().scrollChild = frame;
end

function AchieverHybridScrollFrameScrollBar_OnLoad(frame)
	frame = frame or this;
	frame:GetParent().scrollBar = frame;
	-- The scrollbar sits on top of the ScrollFrame's own mouse region, so a
	-- wheel scroll while hovering it directly needs its own handling too
	-- (see ListScrollFrame.xml's <OnMouseWheel> on this same Slider) --
	-- otherwise it falls through to the 3D camera instead of the list.
	frame:EnableMouseWheel(true);

	-- OnValueChanged/OnMouseWheel are attached here via SetScript rather than
	-- left as ListScrollFrame.xml's inline <OnValueChanged>/<OnMouseWheel>
	-- bodies (which are now dead code, harmless to leave in the XML) --
	-- confirmed via live 1.14.2 testing that while an inline script body
	-- reliably gets `self`, it does NOT reliably get `arg1` (the slider's new
	-- value came through as nil, crashing AchieverHybridScrollFrame_SetOffset's
	-- arithmetic). A named-parameter SetScript closure is the same proven
	-- fix shape already used for Achiever.lua/Router.lua's anonymous
	-- handlers: real params preferred, falling back to the legacy globals
	-- keeps 1.12.1 (which never passes real params to SetScript handlers
	-- either) working unchanged.
	frame:SetScript("OnValueChanged", function(sb, value)
		sb = sb or this;
		value = value or arg1;
		AchieverHybridScrollFrame_OnValueChanged(sb:GetParent(), value);
	end);
	frame:SetScript("OnMouseWheel", function(sb, delta)
		sb = sb or this;
		delta = delta or arg1;
		AchieverHybridScrollFrame_OnMouseWheel(sb:GetParent(), delta);
	end);
end
