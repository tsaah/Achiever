-- Tracker.lua
-- On-screen "watch frame" for tracked achievements -- what Achiever_WatchFrame_Update
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

	row:SetScript("OnEnter", function(frame)
		local this = frame or this
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_TRACKER_ROW_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(frame, buttonArg)
		local this = frame or this
		local arg1 = buttonArg or arg1
		if not this.achievementId then return end
		if arg1 == "RightButton" then
			AchievementButton_ToggleTracking(this.achievementId)
		else
			ShowUIPanel(AchieverAchievementFrame)
			AchieverAchievementFrame_SelectAchievement(this.achievementId)
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
	local _, name, points, completed, _, _, _, description, flags = Achiever_GetAchievementInfo(id)
	local text = "|cffffd200" .. (name or "") .. "|r"

	-- Achievements like 1832 "Tastes Like Chicken" (sample 50 dishes out of a
	-- shared ~100-entry criteria list) carry far too many individual criteria
	-- to list one-per-line here without making the tracker unusable -- same
	-- reason AchievementObjectives_DisplayCriteria (AchievementUI.lua)
	-- collapses these into a single aggregate progress bar instead of a
	-- per-criterion breakdown. Mirrors that same ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR
	-- check and reqQuantity resolution exactly, showing the achievement's own
	-- description (there's no per-criterion text worth showing individually
	-- here, unlike the real progress bar widget which pairs this same count
	-- with a description shown elsewhere in the full achievement UI) plus one
	-- "current / total" count instead of a real StatusBar widget.
	if (flags and bit.band(flags, ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR) == ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR) then
		local reqQuantity
		if (bit.band(flags, ACHIEVEMENT_FLAGS_REQ_COUNT) == ACHIEVEMENT_FLAGS_REQ_COUNT) then
			reqQuantity = Achiever_GetAchievementMinimumCriteria(id)
		else
			local _, _, _, _, rq = Achiever_GetAchievementCriteriaInfo(id, 1)
			reqQuantity = rq
		end
		local quantity = Achiever_GetStatistic(id)
		local color = completed and "|cff20ff20" or "|cffffffff"
		text = text .. "\n" .. color .. "- " .. (description or "") .. " (" .. (quantity or 0) .. " / " .. (reqQuantity or 0) .. ")|r"
		return text
	end

	local numCriteria = Achiever_GetAchievementNumCriteria(id)
	for i = 1, numCriteria do
		local criteriaString, _, critCompleted, _, reqQuantity, _, _, _, quantityString = Achiever_GetAchievementCriteriaInfo(id, i)
		if (criteriaString and criteriaString ~= "") then
			local line = criteriaString
			-- Checking quantityString itself (not just reqQuantity > 0):
			-- Achiever_GetAchievementCriteriaInfo (Router.lua) only fills in
			-- quantityString once it actually has progress info to show (the
			-- achievement is already completed, or the server has sent SOME
			-- progress for this criterion) -- an untouched criterion with a
			-- real reqQuantity (e.g. 940's "complete this quest" criteria,
			-- reqQuantity=1, never touched yet) still has an empty
			-- quantityString, and reqQuantity > 0 alone was appending an
			-- empty " ()" for it.
			if (quantityString and quantityString ~= "") then
				-- quantityString is already the fully-formatted "current /
				-- required" text (letter-suffixed gold/silver/copper for
				-- money-flagged criteria, plain numbers otherwise) -- see
				-- Achiever_GetAchievementCriteriaInfo in Router.lua.
				line = line .. " (" .. quantityString .. ")"
			end
			local color = critCompleted and "|cff20ff20" or "|cffffffff"
			text = text .. "\n" .. color .. "- " .. line .. "|r"
		end
	end

	return text
end

function Achiever_Tracker_Update()
	if not trackerFrame then return end

	local ids = { Achiever_GetTrackedAchievements() }
	local numTracked = table.getn(ids)

	if numTracked == 0 then
		-- Safety net alongside the OnDragStart IsShown() guard above: forces
		-- the movable state to clear if this hide happens mid-drag, rather
		-- than relying solely on OnDragStop firing normally.
		trackerFrame:StopMovingOrSizing()
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

-- Also called directly by Achiever_WatchFrame_Update (see Constants.lua's old stub,
-- now removed) via that name, since AchievementButton_ToggleTracking's own
-- tracked/untracked branches call Achiever_WatchFrame_Update() rather than this.
function Achiever_WatchFrame_Update()
	Achiever_Tracker_Update()
end

function Achiever_Tracker_Initialize()
	-- BackdropTemplate doesn't exist on 1.12.1 at all (confirmed via live
	-- testing: CreateFrame(): "Couldn't find inherited node
	-- 'BackdropTemplate'") -- SetBackdrop/SetBackdropColor below are native
	-- Frame methods there, available with no special template. Modern
	-- clients (8.0+, including Classic Era) removed those from the base
	-- Frame type, so BackdropTemplate is genuinely required there. A plain
	-- WOW_PROJECT_ID check is enough here (unlike AchievementUI.xml's own
	-- BackdropTemplate uses, which needed the AchieverBackdropCompat XML
	-- indirection instead) since this is just a runtime string argument to
	-- CreateFrame, not special syntax.
	trackerFrame = CreateFrame("Frame", "AchieverTrackerFrame", UIParent, WOW_PROJECT_ID and "BackdropTemplate" or nil)
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
	-- AchieverAchievementFrameHeader needing its own drag handlers in Achiever.lua.
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
	lockCheckbox:SetScript("OnClick", function(frame)
		local this = frame or this
		AchieverDB.trackerLocked = this:GetChecked() and true or false
	end)
	lockCheckbox:SetScript("OnEnter", function(frame)
		local this = frame or this
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_TRACKER_LOCK_TOOLTIP, 1, 1, 1)
		GameTooltip:Show()
	end)
	lockCheckbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	trackerHeader:SetScript("OnDragStart", function()
		-- IsShown() guard: see Achiever.lua's matching AchieverAchievementFrame
		-- fix for the full explanation -- trackerFrame gets :Hide()'d whenever
		-- nothing is tracked (Achiever_Tracker_Update), and this header sits
		-- right next to the minimap by default, a much more frequently-clicked
		-- area than the main panel's own screen region.
		if not AchieverDB.trackerLocked and trackerFrame:IsShown() then
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
