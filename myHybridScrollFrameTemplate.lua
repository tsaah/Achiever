--[[-----------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------]]--

local round = function (num) return math.floor(num + .5); end

function HybridScrollFrame_OnLoad (self)
	self:EnableMouse(true);
end

function HybridScrollFrame_OnValueChanged (frame, value)
	HybridScrollFrame_SetOffset(frame, value);
	HybridScrollFrame_UpdateButtonStates(frame, value);
end

function HybridScrollFrame_UpdateButtonStates(frame, currValue)
	if ( not currValue ) then
		currValue = frame.scrollBar:GetValue();
	end

	frame.scrollUp:Enable();
	frame.scrollDown:Enable();

	local minVal, maxVal = frame.scrollBar:GetMinMaxValues();
	if ( currValue >= maxVal ) then
		frame.scrollBar.thumbTexture:Show();
		if ( frame.scrollDown ) then
			frame.scrollDown:Disable()
		end
	end
	if ( currValue <= minVal ) then
		frame.scrollBar.thumbTexture:Show();
		if ( frame.scrollUp ) then
			frame.scrollUp:Disable();
		end
	end
end

function HybridScrollFrame_OnMouseWheel (self, delta, stepSize)
	if ( not self.scrollBar:IsVisible() ) then
		return;
	end

	local minVal, maxVal = 0, self.range;
	stepSize = stepSize or self.stepSize or self.buttonHeight;
	if ( delta == 1 ) then
		self.scrollBar:SetValue(max(minVal, self.scrollBar:GetValue() - stepSize));
	else
		self.scrollBar:SetValue(min(maxVal, self.scrollBar:GetValue() + stepSize));
	end
end

function HybridScrollFrameScrollButton_OnUpdate (self, elapsed)
	self.timeSinceLast = self.timeSinceLast + elapsed;
	if ( self.timeSinceLast >= ( self.updateInterval or 0.08 ) ) then
		if ( not IsMouseButtonDown("LeftButton") ) then
			self:SetScript("OnUpdate", nil);
		elseif ( self:IsMouseOver() ) then
			local parent = self.parent or self:GetParent():GetParent();
			HybridScrollFrame_OnMouseWheel (parent, self.direction, (self.stepSize or parent.buttonHeight/3));
			self.timeSinceLast = 0;
		end
	end
end

function HybridScrollFrameScrollButton_OnClick (self, button, down)
	local parent = self.parent or self:GetParent():GetParent();

	if ( down ) then
		self.timeSinceLast = (self.timeToStart or -0.2);
		self:SetScript("OnUpdate", HybridScrollFrameScrollButton_OnUpdate);
		HybridScrollFrame_OnMouseWheel (parent, self.direction);
		PlaySound("UChatScrollButton");
	else
		self:SetScript("OnUpdate", nil);
	end
end

function HybridScrollFrame_Update (self, totalHeight, displayedHeight)
	local range = totalHeight - self:GetHeight();
	if ( range > 0 and self.scrollBar ) then
		local minVal, maxVal = self.scrollBar:GetMinMaxValues();
		if ( math.floor(self.scrollBar:GetValue()) >= math.floor(maxVal) ) then
			self.scrollBar:SetMinMaxValues(0, range)
			if ( math.floor(self.scrollBar:GetValue()) ~= math.floor(range) ) then
				self.scrollBar:SetValue(range);
            else
				HybridScrollFrame_SetOffset(self, range); -- If we've scrolled to the bottom, we need to recalculate the offset.
			end
		else
			self.scrollBar:SetMinMaxValues(0, range)
		end
	-- 	-- self.scrollBar:Enable();
		HybridScrollFrame_UpdateButtonStates(self);
	-- 	self.scrollBar:Show();
		self.scrollBar:SetAlpha(1)
	elseif ( self.scrollBar ) then
		self.scrollBar:SetValue(0);
		if ( self.scrollBar.doNotHide ) then
			self.scrollBar:Disable();
			self.scrollUp:Disable();
			self.scrollDown:Disable();
			self.scrollBar.thumbTexture:Hide();
		else
			-- self.scrollBar:Hide();
			self.scrollBar:SetAlpha(0)
		end
	end

	self.range = range;
	self.scrollChild:SetHeight(displayedHeight);
	self:UpdateScrollChildRect();
end

function HybridScrollFrame_GetOffset (self)
	return math.floor(self.offset or 0), (self.offset or 0);
end

function HybridScrollFrameScrollChild_OnLoad (self)
	self:GetParent().scrollChild = self;
end

function HybridScrollFrame_ExpandButton (self, offset, height)
	self.largeButtonTop = round(offset);
	self.largeButtonHeight = round(height)
	HybridScrollFrame_SetOffset(self, self.scrollBar:GetValue());
end

function HybridScrollFrame_CollapseButton (self)
	self.largeButtonTop = nil;
	self.largeButtonHeight = nil;
end

function HybridScrollFrame_SetOffset (frame, offset)
	local buttons = frame.buttons
	local buttonHeight = frame.buttonHeight;
	local element, overflow;

	local scrollHeight = 0;

	local largeButtonTop = frame.largeButtonTop
	if ( largeButtonTop and offset >= largeButtonTop ) then
		local largeButtonHeight = frame.largeButtonHeight;
		-- Initial offset...
		element = largeButtonTop / buttonHeight;

		if ( offset >= (largeButtonTop + largeButtonHeight) ) then
			element = element + 1;

			local leftovers = (offset - (largeButtonTop + largeButtonHeight) );

			element = element + ( leftovers / buttonHeight );
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

	if ( math.floor(frame.offset or 0) ~= math.floor(element) and frame.update ) then
		frame.offset = element;
		frame.update();
	else
		frame.offset = element;
	end

	frame:SetVerticalScroll(scrollHeight);
end

function HybridScrollFrame_CreateButtons (frame, buttonTemplate, initialOffsetX, initialOffsetY, initialPoint, initialRelative, offsetX, offsetY, point, relativePoint)
	local scrollChild = frame.scrollChild;
	local button, buttonHeight, buttons, numButtons;

	local buttonName = frame:GetName() .. "Button";

	initialPoint = initialPoint or "TOPLEFT";
	initialRelative = initialRelative or "TOPLEFT";
	point = point or "TOPLEFT";
	relativePoint = relativePoint or "BOTTOMLEFT";
	offsetX = offsetX or 0;
	offsetY = offsetY or 0;

	if ( frame.buttons ) then
		buttons = frame.buttons;
		buttonHeight = buttons[1]:GetHeight();
	else
		button = CreateFrame("BUTTON", buttonName .. 1, scrollChild, buttonTemplate);
		buttonHeight = button:GetHeight();
		button:SetPoint(initialPoint, scrollChild, initialRelative, initialOffsetX, initialOffsetY);
		buttons = {}
		tinsert(buttons, button);
	end

	frame.buttonHeight = round(buttonHeight);

	local numButtons = math.ceil(frame:GetHeight() / buttonHeight) + 1;

	for i = getn(buttons) + 1, numButtons do
		button = CreateFrame("BUTTON", buttonName .. i, scrollChild, buttonTemplate);
		button:SetPoint(point, buttons[i-1], relativePoint, offsetX, offsetY);
		tinsert(buttons, button);
	end

	scrollChild:SetWidth(frame:GetWidth())
	scrollChild:SetHeight(numButtons * buttonHeight);
	frame:SetVerticalScroll(0);
	frame:UpdateScrollChildRect();

	frame.buttons = buttons;
	local scrollBar = frame.scrollBar;
	scrollBar:SetMinMaxValues(0, numButtons * buttonHeight)
	scrollBar:SetValueStep(.005);
	scrollBar:SetValue(0);
end
