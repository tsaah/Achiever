-- Tracker.lua
-- On-screen "watch frame" for tracked achievements -- what WatchFrame_Update
-- (a no-op stub before this) is supposed to refresh. WotLK's real WatchFrame
-- doesn't exist in 1.12 at all, so this is a from-scratch widget built for
-- Achiever specifically, not a port. Styled like vanilla's own
-- QuestWatchFrame in spirit (compact drop-shadowed text, no heavy border),
-- anchored below the minimap by default, draggable via its header with
-- position persisted the same way the rest of Achiever's frames are.

local TRACKER_WIDTH = 210
local TRACKER_HEADER_HEIGHT = 16
local TRACKER_ROW_SPACING = 6

local trackerFrame
local trackerHeader
local trackerRows = {}

-- Achiever has no hard dependency on pfUI (unlike pfQuest, which assumes it
-- unconditionally), so this only picks up pfUI.font_default when pfUI is
-- actually installed/enabled, falling back to the plain default otherwise.
local function Achiever_Tracker_GetFont()
	if (pfUI and pfUI.font_default) then
		return pfUI.font_default
	end
	return STANDARD_TEXT_FONT
end

local function Achiever_Tracker_AcquireRow(index)
	local row = trackerRows[index]
	if row then return row end

	row = CreateFrame("Button", nil, trackerFrame)
	row:SetWidth(TRACKER_WIDTH)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local text = row:CreateFontString(nil, "ARTWORK")
	text:SetFont(Achiever_Tracker_GetFont(), 11, "")
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetJustifyH("LEFT")
	text:SetWidth(TRACKER_WIDTH)
	text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.text = text

	row:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_TRACKER_ROW_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function()
		if not this.achievementId then return end
		if arg1 == "RightButton" then
			AchievementButton_ToggleTracking(this.achievementId)
		else
			ShowUIPanel(AchievementFrame)
			AchievementFrame_SelectAchievement(this.achievementId)
		end
	end)

	trackerRows[index] = row
	return row
end

-- One FontString per achievement (name + all its criteria as separate
-- embedded-color-coded lines) rather than pooling per-criterion sub-widgets --
-- far simpler, and WATCHFRAME_MAXACHIEVEMENTS (10) keeps the total row count
-- small regardless.
local function Achiever_Tracker_BuildRowText(id)
	local _, name, points, completed = GetAchievementInfo(id)
	local text = "|cffffd200" .. (name or "") .. "|r"

	local numCriteria = GetAchievementNumCriteria(id)
	for i = 1, numCriteria do
		local criteriaString, _, critCompleted, _, reqQuantity, _, _, _, quantityString = GetAchievementCriteriaInfo(id, i)
		if (criteriaString and criteriaString ~= "") then
			local line = criteriaString
			if (reqQuantity and reqQuantity > 0) then
				-- quantityString is already the fully-formatted "current /
				-- required" text (letter-suffixed gold/silver/copper for
				-- money-flagged criteria, plain numbers otherwise) -- see
				-- GetAchievementCriteriaInfo in Router.lua.
				line = line .. " (" .. quantityString .. ")"
			end
			local color = critCompleted and "|cff20ff20" or "|cffffffff"
			text = text .. "\n" .. color .. line .. "|r"
		end
	end

	return text
end

function Achiever_Tracker_Update()
	if not trackerFrame then return end

	local ids = { GetTrackedAchievements() }
	local numTracked = table.getn(ids)

	if numTracked == 0 then
		trackerFrame:Hide()
		return
	end

	local totalHeight = TRACKER_HEADER_HEIGHT
	local previousRow

	-- Re-applied here (not just once at creation) since Achiever loads
	-- alphabetically before pfUI, so pfUI.font_default may not be ready yet
	-- the first time a row/header gets created at ADDON_LOADED time; by the
	-- time a user actually tracks something, pfUI has long since finished.
	local font = Achiever_Tracker_GetFont()
	trackerHeader.text:SetFont(font, 11, "")

	for i = 1, numTracked do
		local id = ids[i]
		local row = Achiever_Tracker_AcquireRow(i)
		row.achievementId = id
		row.text:SetFont(font, 11, "")
		row.text:SetText(Achiever_Tracker_BuildRowText(id))

		-- GetStringHeight doesn't exist in this client (confirmed by
		-- ModernSpellBook_'s own GetStringHeight/GetHeight fallback check);
		-- GetHeight reflects the FontString's auto-computed wrapped/
		-- multi-line height just as well here since no explicit height was
		-- ever set on it.
		local rowHeight = row.text:GetHeight()
		row:SetHeight(rowHeight)
		row:ClearAllPoints()
		if previousRow then
			row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -TRACKER_ROW_SPACING)
			totalHeight = totalHeight + TRACKER_ROW_SPACING
		else
			row:SetPoint("TOPLEFT", trackerHeader, "BOTTOMLEFT", 0, -TRACKER_ROW_SPACING)
			totalHeight = totalHeight + TRACKER_ROW_SPACING
		end
		row:Show()

		totalHeight = totalHeight + rowHeight
		previousRow = row
	end

	for i = numTracked + 1, table.getn(trackerRows) do
		trackerRows[i]:Hide()
	end

	trackerFrame:SetHeight(totalHeight)
	trackerFrame:Show()
end

-- Also called directly by WatchFrame_Update (see Constants.lua's old stub,
-- now removed) via that name, since AchievementButton_ToggleTracking's own
-- tracked/untracked branches call WatchFrame_Update() rather than this.
function WatchFrame_Update()
	Achiever_Tracker_Update()
end

function Achiever_Tracker_Initialize()
	trackerFrame = CreateFrame("Frame", "AchieverTrackerFrame", UIParent)
	trackerFrame:SetWidth(TRACKER_WIDTH)
	trackerFrame:SetHeight(1)
	trackerFrame:SetMovable(true)
	trackerFrame:SetClampedToScreen(true)
	trackerFrame:SetFrameStrata("LOW")

	-- Purely decorative padded backdrop (negative insets let it extend past
	-- the frame's own edges rather than needing to re-pad every row/header
	-- anchor) -- light and transparent so it just helps legibility over
	-- varied backgrounds without turning into an opaque panel.
	trackerFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		insets = { left = -4, right = -4, top = -4, bottom = -4 },
	})
	trackerFrame:SetBackdropColor(0, 0, 0, 0.35)

	if AchieverDB.trackerFramePos then
		local p = AchieverDB.trackerFramePos
		trackerFrame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
	else
		trackerFrame:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -20)
	end

	-- Row buttons cover the whole frame's width/height, so the container
	-- itself can never receive a drag -- same problem (and same fix) as
	-- AchievementFrameHeader needing its own drag handlers in Achiever.lua.
	trackerHeader = CreateFrame("Button", nil, trackerFrame)
	trackerHeader:SetWidth(TRACKER_WIDTH)
	trackerHeader:SetHeight(TRACKER_HEADER_HEIGHT)
	trackerHeader:SetPoint("TOPLEFT", trackerFrame, "TOPLEFT", 0, 0)
	trackerHeader:EnableMouse(true)
	trackerHeader:RegisterForDrag("LeftButton")

	local headerText = trackerHeader:CreateFontString(nil, "ARTWORK")
	headerText:SetFont(Achiever_Tracker_GetFont(), 11, "")
	headerText:SetShadowOffset(1, -1)
	headerText:SetShadowColor(0, 0, 0, 1)
	headerText:SetTextColor(1, 0.82, 0, 1)
	headerText:SetJustifyH("LEFT")
	headerText:SetPoint("TOPLEFT", trackerHeader, "TOPLEFT", 0, 0)
	trackerHeader.text = headerText
	headerText:SetText(ACHIEVER_TRACKER_HEADER)

	-- Locking only gates OnDragStart below (StartMoving never gets called),
	-- rather than unregistering the drag entirely, so nothing else about the
	-- header's mouse handling needs to change when toggled.
	local lockCheckbox = CreateFrame("CheckButton", "AchieverTrackerLockCheckbox", trackerHeader, "UICheckButtonTemplate")
	lockCheckbox:SetWidth(14)
	lockCheckbox:SetHeight(14)
	lockCheckbox:SetPoint("TOPRIGHT", trackerHeader, "TOPRIGHT", 0, 0)
	lockCheckbox:SetChecked(AchieverDB.trackerLocked)
	lockCheckbox:SetScript("OnClick", function()
		AchieverDB.trackerLocked = this:GetChecked() and true or false
	end)
	lockCheckbox:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_TRACKER_LOCK_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	lockCheckbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	trackerHeader:SetScript("OnDragStart", function()
		if not AchieverDB.trackerLocked then
			trackerFrame:StartMoving()
		end
	end)
	trackerHeader:SetScript("OnDragStop", function()
		trackerFrame:StopMovingOrSizing()
		local point, _, relativePoint, x, y = trackerFrame:GetPoint()
		AchieverDB.trackerFramePos = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)

	-- Tracked achievements persist across relogs (AchieverCharacterProgress.tracked),
	-- so there may already be some to show right now rather than waiting for
	-- the next track/untrack/criteria event to trigger a refresh.
	Achiever_Tracker_Update()
end
