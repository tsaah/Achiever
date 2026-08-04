-- Native-widget replacement for WotLK's HybridScrollFrame system (which has
-- no 1.12 equivalent at all). Rather than porting that file, this
-- reimplements the same function contract (HybridScrollFrame_CreateButtons/
-- _GetOffset/_Update/_ExpandButton/_CollapseButton/_OnMouseWheel) that
-- AchievementUI.lua already calls, built on 1.12's own ScrollFrame + Slider
-- widgets (the same approach pfUI/api/ui-widgets.lua's CreateScrollFrame
-- uses), so the achievement UI's list-management code needs no changes.
--
-- These are plain helper functions called explicitly with the scroll frame
-- as their first argument (not frame script handlers), so they don't need
-- the implicit this/event/arg1 treatment the rest of the backport does.

local function round(num) return math.floor(num + 0.5); end

function HybridScrollFrame_UpdateButtonStates(self)
	self.scrollBar:Show();
end

function HybridScrollFrame_SetOffset(self, offset)
	-- Lists too small to need button recycling (see HybridScrollFrame_CreateButtons'
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

function HybridScrollFrame_OnValueChanged(self, value)
	HybridScrollFrame_SetOffset(self, value);
	HybridScrollFrame_UpdateButtonStates(self);
end

function HybridScrollFrame_OnMouseWheel(self, delta, stepSize)
	if not self.scrollBar:IsVisible() then return; end
	local minVal, maxVal = 0, self.range or 0;
	stepSize = stepSize or self.buttonHeight or 16;
	if delta > 0 then
		self.scrollBar:SetValue(math.max(minVal, self.scrollBar:GetValue() - stepSize));
	else
		self.scrollBar:SetValue(math.min(maxVal, self.scrollBar:GetValue() + stepSize));
	end
end

function HybridScrollFrame_GetOffset(self)
	return math.floor(self.offset or 0), (self.offset or 0);
end

function HybridScrollFrame_ExpandButton(self, offset, height)
	self.largeButtonTop = round(offset);
	self.largeButtonHeight = round(height);
	HybridScrollFrame_SetOffset(self, self.scrollBar:GetValue());
end

function HybridScrollFrame_CollapseButton(self)
	self.largeButtonTop = nil;
	self.largeButtonHeight = nil;
end

function HybridScrollFrame_Update(self, totalHeight, displayedHeight)
	local range = totalHeight - self:GetHeight();
	if range > 0 and self.scrollBar then
		local minVal, maxVal = self.scrollBar:GetMinMaxValues();
		if math.floor(self.scrollBar:GetValue()) >= math.floor(maxVal) then
			self.scrollBar:SetMinMaxValues(0, range);
			if math.floor(self.scrollBar:GetValue()) ~= math.floor(range) then
				self.scrollBar:SetValue(range);
			else
				HybridScrollFrame_SetOffset(self, range);
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
	self.scrollChild:SetHeight(displayedHeight);
end

-- exactCount: for lists small enough to give every row its own permanent
-- button (see the "noVirtualize" flag above) instead of sizing the pool to
-- the viewport and recycling buttons as the user scrolls.
function HybridScrollFrame_CreateButtons(self, buttonTemplate, initialOffsetX, initialOffsetY, initialPoint, initialRelative, offsetX, offsetY, point, relativePoint, exactCount)
	local scrollChild = self.scrollChild;
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

	self.buttons = buttons;
	local scrollBar = self.scrollBar;
	scrollBar:SetMinMaxValues(0, numButtons * buttonHeight);
	scrollBar:SetValueStep(1);
	scrollBar:SetValue(0);
end

-- Script handlers wired from ListScrollFrame.xml (real frame scripts, so
-- these use the implicit this/arg1 convention).
function HybridScrollFrame_OnLoad()
	this:EnableMouse(true);
	-- Unlike WotLK's real client, this one doesn't fire OnMouseWheel on a
	-- frame just because it has that script -- EnableMouseWheel has to be
	-- called explicitly (confirmed by AchievementCategoryButton_OnLoad
	-- already needing it for per-row scrolling); without this, the
	-- OnMouseWheel handler HybridScrollFrameTemplate declares in
	-- ListScrollFrame.xml never actually fires.
	this:EnableMouseWheel(true);
end

function HybridScrollFrameScrollChild_OnLoad()
	this:GetParent().scrollChild = this;
end

function HybridScrollFrameScrollBar_OnLoad()
	this:GetParent().scrollBar = this;
	-- The scrollbar sits on top of the ScrollFrame's own mouse region, so a
	-- wheel scroll while hovering it directly needs its own handling too
	-- (see ListScrollFrame.xml's <OnMouseWheel> on this same Slider) --
	-- otherwise it falls through to the 3D camera instead of the list.
	this:EnableMouseWheel(true);
end
