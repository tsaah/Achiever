-- Global (not local): XML inline <Scripts> bodies run as their own separate
-- chunks, so a file-local alias here wouldn't be visible to them.
--
-- Guarded (unlike a plain unconditional assignment) because 1.14.2 already
-- has a real, native _G -- the actual global environment table the entire
-- client's own code reads/writes through, explicitly and implicitly, for
-- every single global access. Confirmed via bisection (isolating this exact
-- file reproduced the action-bar-block taint) that unconditionally
-- reassigning it here -- even to a same-content table from getfenv(0) --
-- marks the _G binding itself as insecure/Achiever-owned on every login,
-- which is a far more sweeping taint vector than any single function or
-- constant: it's the one variable name virtually all core FrameXML code
-- (any `_G[dynamicName]` lookup, e.g. ActionButton-indexed lookups) reads
-- explicitly by that exact name. 1.12.1 has no native _G at all (confirmed
-- absent, CLAUDE.md), so this guard changes nothing there -- always takes
-- the true branch, identical to the previous unconditional behavior.
if not _G then
	_G = getfenv(0);
end

-- Deliberately NOT registered in UIPanelWindows (no "doublewide" area
-- entry): that's vanilla's mutual-exclusion system for the classic
-- single-window UX (CharacterFrame/SpellBookFrame/QuestLogFrame etc. all
-- share it and evict each other -- see ShowUIPanel/SetDoublewideFrame in
-- UIParent.lua) -- registering AchieverAchievementFrame there means opening ANY
-- other doublewide-area window (skills, character sheet, quest log, ...)
-- silently hides this one. Leaving it unregistered makes ShowUIPanel/
-- HideUIPanel (already called throughout this addon) fall through to plain
-- frame:Show()/:Hide() instead (confirmed from ShowUIPanel's own source:
-- `if (not info) then frame:Show(); return end`), so it now behaves like an
-- independent floating window that stays open regardless of what else is
-- open. UISpecialFrames (below) replaces the Escape-to-close behavior that
-- registration would otherwise have provided via the doublewide slot.
tinsert(UISpecialFrames, "AchieverAchievementFrame");

ACHIEVEMENTUI_CATEGORIES = {};

ACHIEVEMENTUI_GOLDBORDER_R = 1;
ACHIEVEMENTUI_GOLDBORDER_G = 0.675;
ACHIEVEMENTUI_GOLDBORDER_B = 0.125;
ACHIEVEMENTUI_GOLDBORDER_A = 1;

ACHIEVEMENTUI_REDBORDER_R = 0.7;
ACHIEVEMENTUI_REDBORDER_G = 0.15;
ACHIEVEMENTUI_REDBORDER_B = 0.05;
ACHIEVEMENTUI_REDBORDER_A = 1;

ACHIEVEMENTUI_CATEGORIESWIDTH = 175;

ACHIEVEMENTUI_PROGRESSIVEHEIGHT = 50;
ACHIEVEMENTUI_PROGRESSIVEWIDTH = 42;

ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS = 4;

ACHIEVEMENTUI_MAXCONTENTWIDTH = 330;
local ACHIEVEMENTUI_FONTHEIGHT;						-- set in AchievementButton_OnLoad
local ACHIEVEMENTUI_MAX_LINES_COLLAPSED = 3;		-- can show 3 lines of text when achievement is collapsed

ACHIEVEMENTUI_DEFAULTSUMMARYACHIEVEMENTS = {6, 503, 116, 1176, 1017};

ACHIEVEMENT_CATEGORY_NORMAL_R = 0;
ACHIEVEMENT_CATEGORY_NORMAL_G = 0;
ACHIEVEMENT_CATEGORY_NORMAL_B = 0;
ACHIEVEMENT_CATEGORY_NORMAL_A = .9;

ACHIEVEMENT_CATEGORY_HIGHLIGHT_R = 0;
ACHIEVEMENT_CATEGORY_HIGHLIGHT_G = .6;
ACHIEVEMENT_CATEGORY_HIGHLIGHT_B = 0;
ACHIEVEMENT_CATEGORY_HIGHLIGHT_A = .65;

ACHIEVEMENTBUTTON_LABELWIDTH = 320;

ACHIEVEMENT_COMPARISON_SUMMARY_ID = -1
ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID = -2

ACHIEVEMENT_FILTER_ALL = 1;
ACHIEVEMENT_FILTER_COMPLETE = 2;
ACHIEVEMENT_FILTER_INCOMPLETE = 3;

local FEAT_OF_STRENGTH_ID = 81;

-- "Character", a stable Blizzard DBC category id (root stat category,
-- uiOrder=1). Default landing category for the Statistics tab now that its
-- fake Summary entry is hidden (see AchieverAchievementFrameCategories_GetCategoryList).
local STATS_DEFAULT_CATEGORY_ID = 130;

local trackedAchievements = {};
-- Takes a plain table (not `...`) -- confirmed via live 1.12.1 testing
-- ("unexpected symbol '...'") that even forwarding `...` as a bare call
-- argument is invalid Lua 5.0 syntax on this client's parser, not just
-- `{...}` (a table constructor with `...` inside it): 5.0 apparently only
-- ever allows `...` to appear in the exact position of a function's own
-- parameter-list declaration, nowhere else at all -- confirmed nowhere in
-- Lua 5.0's manual as a general "vararg expression" the way 5.1 has one.
-- Every call site here already only ever needs a real, dynamically-sized
-- achievement-id list (unlike ShowSubFrame/the *_OnEvent handlers below,
-- which always take a small fixed count and were converted to plain named
-- parameters instead), so this takes an explicit table built by the caller
-- via `{ Achiever_GetTrackedAchievements() }` -- capturing a function
-- call's multiple return values in a table constructor, NOT vararg
-- expansion, so it's ordinary, fully portable Lua.
local function updateTrackedAchievements (ids)
	local count = table.getn(ids);

	for i = 1, count do
		trackedAchievements[ids[i]] = true;
	end
end


-- Named function (not left as AchieverAchievementFrameTabButtonTemplate's own
-- inline <OnLoad> body) so AchieverAchievementFrame_OnShow can also call it
-- explicitly as a reliable fallback -- confirmed via live 1.12.1 testing
-- that self/this here can be a completely unrelated table left over from
-- another addon's own script (same class of issue as the Summary tab's
-- dynamically-created buttons), and that AchieverAchievementFrameTab3
-- specifically (created later by Options.xml, giving more opportunity for
-- that to happen before its own OnLoad fires) hits it while Tab1/Tab2
-- (created earlier, directly in this file) don't.
function AchieverAchievementFrameTabButton_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	_G[name.."Left"]:SetVertexColor(0.6, 0.6, 0.6);
	_G[name.."Middle"]:SetVertexColor(0.6, 0.6, 0.6);
	_G[name.."Right"]:SetVertexColor(0.6, 0.6, 0.6);
	_G[name.."LeftDisabled"]:SetPoint("TOPLEFT", 0, 2);
	self.leftHighlight = _G[name.."LeftHighlight"];
	self.middleHighlight = _G[name.."MiddleHighlight"];
	self.rightHighlight = _G[name.."RightHighlight"];
	self.text = _G[name.."Text"];
end

-- [[ AchieverAchievementFrame ]] --

function AchieverAchievementFrame_ToggleAchieverAchievementFrame(toggleStatFrame)
	AchieverAchievementFrameComparison:Hide();
	AchieverAchievementFrameTab_OnClick = AchieverAchievementFrameBaseTab_OnClick;
	if ( not toggleStatFrame ) then
		if ( AchieverAchievementFrame:IsShown() and AchieverAchievementFrame.selectedTab == 1 ) then
			HideUIPanel(AchieverAchievementFrame);
		else
			ShowUIPanel(AchieverAchievementFrame);
			AchieverAchievementFrameTab_OnClick(1);
		end
		return;
	end
	if ( AchieverAchievementFrame:IsShown() and AchieverAchievementFrame.selectedTab == 2 ) then
		HideUIPanel(AchieverAchievementFrame);
	else
		ShowUIPanel(AchieverAchievementFrame);
		AchieverAchievementFrameTab_OnClick(2);
	end
end

function AchieverAchievementFrame_DisplayComparison (unit)
	AchieverAchievementFrame.wasShown = nil;
	AchieverAchievementFrameTab_OnClick = AchieverAchievementFrameComparisonTab_OnClick;
	AchieverAchievementFrameTab_OnClick(1);
	ShowUIPanel(AchieverAchievementFrame);
	--AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameSummary);
	AchieverAchievementFrameComparison_SetUnit(unit);
	AchieverAchievementFrameComparison_ForceUpdate();
end

function AchieverAchievementFrame_OnLoad (frame)
	-- Was left calling Achiever_PanelTemplates_SetNumTabs(this, 3) unguarded
	-- (this addon's very first/outermost OnLoad, previously believed to be
	-- the one confirmed-safe case for bare `this`) until live testing showed
	-- `this` nil here too -- that earlier "confirmed working" observation
	-- predated a since-fixed XML well-formedness bug that had been
	-- preventing this exact frame from ever constructing at all in later
	-- test rounds, so it was never actually re-validated. There is no safe
	-- exception; every inline script needs the self/this fallback.
	local this = frame or self or this;
	-- The old <Backdrop> XML tag (AchievementUI.xml) that used to establish
	-- this frame's wood border is a no-op on 1.14.2+ -- see
	-- AchieverBackdropCompat's own comment (CompatTemplates_1_14_2.xml) for
	-- why -- so it's set here in Lua instead, identically on both clients.
	this:SetBackdrop({ edgeFile = "Interface\\AddOns\\Achiever\\textures\\UI-Achievement-WoodBorder", tile = true, edgeSize = 64, tileSize = 32, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
	Achiever_PanelTemplates_SetNumTabs(this, 3);
	this.selectedTab = 1;
	-- NOT Achiever_PanelTemplates_UpdateTabs(this) here -- this OnLoad fires
	-- while AchievementUI.xml is still being parsed, well before Options.xml
	-- (a separate, later-loading file) has created AchieverAchievementFrameTab3, so
	-- looking it up this early errors with "attempt to index ... nil".
	-- Deferred to AchieverAchievementFrame_OnShow instead, by which point every file
	-- has long since loaded.
end

function AchieverAchievementFrame_OnShow ()
	Achiever_PlaySound("AchievementMenuOpen");
	AchieverAchievementFrameHeaderPoints:SetText(Achiever_GetTotalAchievementPoints());

	-- Explicit, reliable fallback for AchieverAchievementFrameTabButtonTemplate's
	-- own <OnLoad> (AchieverAchievementFrameTabButton_OnLoad) -- see that
	-- function's own comment. Gated on `not tab.leftHighlight` so this is a
	-- pure no-op, not a re-run, on a tab whose own OnLoad worked fine.
	-- AchieverAchievementFrame_OnShow is the established "every file has
	-- long since loaded" checkpoint this same function already relies on
	-- just below for Achiever_PanelTemplates_UpdateTabs/Tab3's existence.
	for tabIndex = 1, 3 do
		local tab = _G["AchieverAchievementFrameTab" .. tabIndex];
		if (tab and not tab.leftHighlight) then
			AchieverAchievementFrameTabButton_OnLoad(tab);
		end

		-- AchieverAchievementFrameTabButtonTemplate's XML-declared
		-- <NormalFont inherits="GameFontNormalSmall"/> is supposed to be
		-- applied to this button's ButtonText automatically by the engine,
		-- with no Lua involved at all -- confirmed via live 1.14.2 testing
		-- that this automatic linkage doesn't reliably happen for a
		-- deselected tab specifically (tab.text:GetFont() returned nil with
		-- a garbage height, vs a real font on the selected tab, which native
		-- PanelTemplates_SelectTab happens to explicitly (re)assign a font
		-- for anyway via SetDisabledFontObject -- PanelTemplates_DeselectTab
		-- does not, relying on the automatic linkage alone). With no font
		-- object at all, GetWidth()/GetUnboundedStringWidth() both
		-- correctly measure 0, which is what made Achiever_PanelTemplates_TabResize
		-- collapse these tabs to almost nothing regardless of any fix
		-- attempted there -- the real problem was always one level
		-- upstream. Explicitly (re)assigning the font here, using the
		-- reliable `tab` reference, every time, makes this addon stop
		-- depending on that automatic linkage at all.
		if (tab and tab.text) then
			tab.text:SetFontObject(GameFontNormalSmall);
		end


		-- Each concrete tab's own inline <OnClick>/<OnEnter>/<OnLeave>
		-- (AchievementUI.xml/Options.xml) relies on this/self binding for
		-- those specific script instances -- confirmed via live 1.12.1
		-- testing that this is unreliable the same way this loop's own
		-- OnLoad fallback above already had to work around (clicks
		-- silently do nothing, hover highlight silently never shows, no
		-- error either way, since OnEnter/OnClick are each their own
		-- separate script invocation with an independent chance of getting
		-- a stale `this`). Overriding with SetScript here uses `tab`, a
		-- reliable direct global lookup with zero binding ambiguity,
		-- sidestepping the problem entirely instead of just guarding
		-- against it -- same fix shape as the category/achievement
		-- buttons' own OnClick fix. Gated on a marker so this only
		-- actually attaches once per tab, not on every frame-show.
		if (tab and not tab.reliableHandlersAttached) then
			tab.reliableHandlersAttached = true;
			local id = tabIndex;
			tab:SetScript("OnClick", function()
				-- Text offset AND font are both handled centrally now, by
				-- Achiever_PanelTemplates_UpdateTabs (Constants.lua, reached
				-- via AchieverAchievementFrameTab_OnClick below) -- see its
				-- own comment. This used to duplicate that same -5/-3
				-- SetPoint logic here too, redundantly and without the font
				-- reassignment, which is exactly the kind of scattered
				-- duplicate-source-of-truth that let the two drift out of
				-- sync in the first place.
				AchieverAchievementFrameTab_OnClick(id);
				Achiever_PlaySound("igCharacterInfoTab");
			end);
			tab:SetScript("OnEnter", function()
				if (tab.leftHighlight) then
					tab.leftHighlight:Show();
					tab.middleHighlight:Show();
					tab.rightHighlight:Show();
				end
			end);
			tab:SetScript("OnLeave", function()
				if (tab.leftHighlight) then
					tab.leftHighlight:Hide();
					tab.middleHighlight:Hide();
					tab.rightHighlight:Hide();
				end
			end);
		end
	end

	Achiever_PanelTemplates_UpdateTabs(AchieverAchievementFrame);

	-- AchieverAchievementFrameTabButtonTemplate's own inline <OnShow> has
	-- been removed entirely (AchievementUI.xml) -- this loop is now the
	-- sole call site for both clients (no client branching). Deliberately
	-- placed AFTER Achiever_PanelTemplates_UpdateTabs above, not inside the
	-- previous loop before it, unlike earlier fix attempts -- confirmed via
	-- live 1.14.2 testing that tab2/tab3 (but not tab1, the selected one)
	-- measured a real, correct text width right after being resized, but
	-- back to approximately 1 by the time anything else could read it --
	-- and neither a one-frame-deferred call nor an every-tick poll (both
	-- tried) ever let it "become" correct no matter how long either waited,
	-- which only makes sense if something running AFTER the resize was
	-- undoing it for deselected tabs specifically, not a timing gap.
	-- Achiever_PanelTemplates_UpdateTabs (just above) calls native
	-- PanelTemplates_SelectTab for the selected tab and
	-- PanelTemplates_DeselectTab for the other two -- exactly the tab1
	-- vs tab2/tab3 split observed, and Blizzard's own DeselectTab is known
	-- to swap font/state on a tab's text for the deselected look. Resizing
	-- after that native call runs, instead of before, means there's nothing
	-- left afterward that could still be touching the text.
	for tabIndex = 1, 3 do
		local tab = _G["AchieverAchievementFrameTab" .. tabIndex];
		if (tab) then
			Achiever_PanelTemplates_TabResize(tab, 10);
		end
	end
	if ( not AchieverAchievementFrame.wasShown ) then
		AchieverAchievementFrame.wasShown = true;
		AchievementCategoryButton_OnClick(AchieverAchievementFrameCategoriesContainerButton1);
	end
	UpdateMicroButtons();
	AchieverAchievementFrame_LoadTextures();
end

function AchieverAchievementFrame_OnHide ()
	Achiever_PlaySound("AchievementMenuClose");
	UpdateMicroButtons();
	AchieverAchievementFrame_ClearTextures();
	-- Safety net alongside the OnDragStart IsShown() guards in Achiever.lua:
	-- if the panel gets hidden mid-drag (e.g. Escape pressed while dragging)
	-- this forces the movable state to clear regardless of how the hide
	-- happened, rather than relying solely on OnDragStop firing normally.
	AchieverAchievementFrame:StopMovingOrSizing();
end

function AchieverAchievementFrame_ForceUpdate ()
	if ( AchieverAchievementFrameAchievements:IsShown() ) then
		AchieverAchievementFrameAchievements_ForceUpdate();
	elseif ( AchieverAchievementFrameStats:IsShown() ) then
		AchieverAchievementFrameStats_Update();
	elseif ( AchieverAchievementFrameComparison:IsShown() ) then
		AchieverAchievementFrameComparison_ForceUpdate();
	end
end

function AchieverAchievementFrameBaseTab_OnClick (id)
	Achiever_PanelTemplates_Tab_OnClick(_G["AchieverAchievementFrameTab"..id], AchieverAchievementFrame);

	local isSummary = false
	if ( id == 1 ) then
		AchieverAchievementFrameCategories:Show();
		achievementFunctions = ACHIEVEMENT_FUNCTIONS;
		AchieverAchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES); -- This needs to happen before AchieverAchievementFrame_ShowSubFrame (fix for bug 157885)
		if ( achievementFunctions.selectedCategory == "summary" ) then
			isSummary = true;
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameSummary);
		else
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameAchievements);
		end
		AchieverAchievementFrameWaterMark:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementWatermark");
	elseif ( id == 3 ) then
		-- Options isn't category-driven -- full-width pane, sidebar hidden,
		-- achievementFunctions deliberately left alone (stale from whatever
		-- tab was selected before) since nothing below reads it for id == 3.
		AchieverAchievementFrameCategories:Hide();
		AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameOptions);
	else
		AchieverAchievementFrameCategories:Show();
		achievementFunctions = STAT_FUNCTIONS;
		AchieverAchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES);
		AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameStats);
		AchieverAchievementFrameWaterMark:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-StatWatermark");
	end

	AchieverAchievementFrameCategories_Update();

	if ( not isSummary and id ~= 3 ) then
		achievementFunctions.updateFunc();
	end
end

AchieverAchievementFrameTab_OnClick = AchieverAchievementFrameBaseTab_OnClick;

function AchieverAchievementFrameComparisonTab_OnClick (id)
	if ( id == 1 ) then
		achievementFunctions = COMPARISON_ACHIEVEMENT_FUNCTIONS;
		AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonContainer);
		AchieverAchievementFrameWaterMark:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementWatermark");
	else
		achievementFunctions = COMPARISON_STAT_FUNCTIONS;
		AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonStatsContainer);
		AchieverAchievementFrameWaterMark:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-StatWatermark");
	end
	
	AchieverAchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES);
	AchieverAchievementFrameCategories_Update();
	Achiever_PanelTemplates_Tab_OnClick(_G["AchieverAchievementFrameTab"..id], AchieverAchievementFrame);
	
	achievementFunctions.updateFunc();
end

ACHIEVEMENTFRAME_SUBFRAMES = {
	"AchieverAchievementFrameSummary",
	"AchieverAchievementFrameAchievements",
	"AchieverAchievementFrameStats",
	"AchieverAchievementFrameComparison",
	"AchieverAchievementFrameComparisonContainer",
	"AchieverAchievementFrameComparisonStatsContainer",
	"AchieverAchievementFrameOptions"
};

-- Named params (not `...`) -- see updateTrackedAchievements's comment (top
-- of file) on why: `...` can't be used at all here beyond a function's own
-- parameter-list declaration on 1.12.1's Lua 5.0. Every call site already
-- only ever passes 1 or 2 real, specific frame references (never a
-- genuinely unbounded list), so this never needed to be a true vararg
-- function in the first place -- no call sites needed changing at all,
-- since Lua already leaves frame2 as nil for every 1-argument call.
function AchieverAchievementFrame_ShowSubFrame(frame1, frame2)
	local subFrame, show;
	for _, name in next, ACHIEVEMENTFRAME_SUBFRAMES  do
		subFrame = _G[name];
		show = (subFrame == frame1) or (subFrame == frame2);
		if ( show ) then
			subFrame:Show();
		else
			subFrame:Hide();
		end
	end
end

-- [[ AchieverAchievementFrameCategories ]] --

function AchieverAchievementFrameCategories_OnLoad (frame)
	local this = frame or this;
	-- See AchieverAchievementFrameAchievementsBackdrop_OnLoad's matching
	-- comment -- the old <Backdrop> XML tag is a no-op on 1.14.2+.
	this:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, edgeSize = 16, tileSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
	this:SetBackdropBorderColor(ACHIEVEMENTUI_GOLDBORDER_R, ACHIEVEMENTUI_GOLDBORDER_G, ACHIEVEMENTUI_GOLDBORDER_B, ACHIEVEMENTUI_GOLDBORDER_A);
	this.buttons = {};
	this:RegisterEvent("ADDON_LOADED");
	this:SetScript("OnEvent", AchieverAchievementFrameCategories_OnEvent);
end

function AchieverAchievementFrameCategories_OnEvent (frame, ev, addonNameArg)
	-- frame/ev/addonNameArg (not this/event/arg1) so the fallback below is a
	-- real fallback rather than a same-named parameter silently shadowing
	-- the global with an always-nil value on 1.12.1, where SetScript-attached
	-- handlers (see OnLoad above) never receive real arguments at all.
	local this = frame or this;
	local event = ev or event;
	local arg1 = addonNameArg or arg1;
	if ( event == "ADDON_LOADED" ) then
		local addonName = arg1;
		if ( addonName and addonName ~= "Achiever" ) then
			return;
		end

		AchieverAchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES);

		AchieverAchievementFrameCategoriesContainerScrollBar.ShowOriginal = AchieverAchievementFrameCategoriesContainerScrollBar.Show;
		AchieverAchievementFrameCategoriesContainerScrollBar.Show =
			function (self)
				ACHIEVEMENTUI_CATEGORIESWIDTH = 175;
				AchieverAchievementFrameCategories:SetWidth(175);
				AchieverAchievementFrameCategoriesContainer:GetScrollChild():SetWidth(175);
				AchieverAchievementFrameAchievements:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 22, 0);
				AchieverAchievementFrameStats:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 22, 0);
				AchieverAchievementFrameComparison:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 22, 0)
				AchieverAchievementFrameWaterMark:SetWidth(145);
				AchieverAchievementFrameWaterMark:SetTexCoord(0, 145/256, 0, 1);
				for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
					AchieverAchievementFrameCategories_DisplayButton(button, button.element)
				end
				self:ShowOriginal();
			end

		AchieverAchievementFrameCategoriesContainerScrollBar.HideOriginal = AchieverAchievementFrameCategoriesContainerScrollBar.Hide;
		AchieverAchievementFrameCategoriesContainerScrollBar.Hide =
			function (self)
				ACHIEVEMENTUI_CATEGORIESWIDTH = 197;
				AchieverAchievementFrameCategories:SetWidth(197);
				AchieverAchievementFrameCategoriesContainer:GetScrollChild():SetWidth(197);
				AchieverAchievementFrameAchievements:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 0, 0);
				AchieverAchievementFrameStats:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 0, 0);
				AchieverAchievementFrameComparison:SetPoint("TOPLEFT", "$parentCategories", "TOPRIGHT", 0, 0)
				AchieverAchievementFrameWaterMark:SetWidth(167);
				AchieverAchievementFrameWaterMark:SetTexCoord(0, 167/256, 0, 1);
				for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
					AchieverAchievementFrameCategories_DisplayButton(button, button.element);
				end
				self:HideOriginal();
			end

		AchieverAchievementFrameCategoriesContainerScrollBarBG:Show();
		AchieverAchievementFrameCategoriesContainer.update = AchieverAchievementFrameCategories_Update;
		-- Category count is small and fixed once the tree is built (collapsing a
		-- parent only hides its children, it never removes rows), so every row
		-- gets its own permanent button instead of a viewport-sized recycled pool --
		-- this is what actually lets the list hold a variable number of top-level
		-- categories and subcategories without needing button-recycling math.
		AchieverAchievementFrameCategoriesContainer.noVirtualize = true;
		AchieverHybridScrollFrame_CreateButtons(AchieverAchievementFrameCategoriesContainer, "AchievementCategoryTemplate", 0, 0, "TOP", "TOP", 0, 0, "TOP", "BOTTOM", table.getn(ACHIEVEMENTUI_CATEGORIES));

		-- Reliable-OnClick attachment (see AchieverAchievementFrameCategories_OnShow
		-- below) deliberately NOT done here -- confirmed via live 1.12.1
		-- testing that SetScript("OnClick", ...) attached immediately after
		-- CreateFrame(), within this same synchronous ADDON_LOADED handler,
		-- never actually fires for real mouse clicks (only a direct Lua-side
		-- call did) even though the identical code works correctly on
		-- 1.14.2 -- 1.12.1 apparently doesn't finish "settling" a freshly
		-- CreateFrame()'d button's click routing until sometime after this
		-- handler returns. This block only fixes up .label/.background via
		-- the this-binding-safe fallback (a separate, unrelated concern from
		-- click attachment).
		for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
			if (not button.label) then
				AchievementCategoryButton_OnLoad(button);
			end
		end
		AchieverAchievementFrameCategories_Update();
		this:UnregisterEvent(event)
	end
end

function AchieverAchievementFrameCategories_OnShow ()
	-- AchievementCategoryTemplate's own inline <OnClick> now passes
	-- `this or self` (AchievementUI.xml) instead of the usual `self or
	-- this` -- confirmed via live testing that `self` is not reliably nil
	-- for a genuine mouse click on this dynamically-CreateFrame()'d button
	-- on 1.12.1 (SetScript-based overrides from here couldn't work around
	-- it either, since they don't take effect for real clicks on this
	-- client for buttons created this way -- only fixing the XML-declared
	-- handler's own binding actually restored clicks). See that XML
	-- comment for the full explanation.

	AchieverAchievementFrameCategories_Update();
end

function AchieverAchievementFrameCategories_GetCategoryList (categories)
	local cats = achievementFunctions.categoryAccessor();

	-- Hide categories (and sub-categories) with zero achievements, in both
	-- the Achievements tab and the Stats tab (this function builds both --
	-- categoryAccessor is the only thing that differs). Computed up front
	-- from `cats` alone, not the `categories` table this function is about
	-- to rebuild in place: AchieverAchievementFrame_GetCategoryTotalNumAchievements
	-- reads sub-category relationships out of that same table, so calling it
	-- mid-rebuild would see a half-built tree. A top-level category still
	-- shows if any of its sub-categories has achievements, even with zero of
	-- its own -- the tree is only one level deep (matches
	-- AchieverAchievementFrame_GetCategoryTotalNumAchievements's own "not recursive"
	-- comment), so a direct-count pass plus one pass summing children into
	-- their parent is exhaustive.
	local directCount = {};
	for _, id in next, cats do
		-- includeAll=true bypasses IsAchievementVisible's chain/completion
		-- rules entirely (Router.lua), which is the right thing for normal
		-- categories -- an achievement still locked behind an earlier one
		-- in its chain should still count as "this category has content",
		-- not make it register as empty. Feats of Strength is the one
		-- category where IsAchievementVisible's own rule IS "only if
		-- earned", so bypassing it here would always count every FoS
		-- achievement that merely exists and this category would never be
		-- treated as empty even with zero actually earned. Match its real
		-- display rule instead by not bypassing it for this one category.
		local includeAll = (id ~= FEAT_OF_STRENGTH_ID);
		directCount[id] = Achiever_GetCategoryNumAchievements(id, includeAll);
	end
	local totalCount = {};
	for _, id in next, cats do
		local _, parent = Achiever_GetCategoryInfo(id);
		if ( parent == -1 ) then
			totalCount[id] = directCount[id] or 0;
		end
	end
	for _, id in next, cats do
		local _, parent = Achiever_GetCategoryInfo(id);
		if ( parent ~= -1 and totalCount[parent] ) then
			totalCount[parent] = totalCount[parent] + (directCount[id] or 0);
		end
	end

	-- table.insert's append position is table.getn(t)+1; nil'ing out entries
	-- by index (rather than table.remove) never shrinks that count in this
	-- Lua, so a subsequent tinsert would keep appending past the old (stale)
	-- length instead of starting over at 1. table.remove properly maintains
	-- it, so shrinking via remove is what actually empties the table.
	while ( table.getn(categories) > 0 ) do
		table.remove(categories);
	end
	-- Insert the fake Summary category -- achievement mode only. In stats
	-- mode this would just reopen AchieverAchievementFrameStats scrolled to the top
	-- (there's no separate stats-overview page behind it), so showing it as
	-- its own category row is redundant there.
	if ( achievementFunctions.categoryAccessor ~= Achiever_GetStatisticsCategoryList ) then
		tinsert(categories, { ["id"] = "summary" });
	end

	for i, id in next, cats do
		local _, parent = Achiever_GetCategoryInfo(id);
		if ( parent == -1 and (totalCount[id] or 0) > 0 ) then
			tinsert(categories, { ["id"] = id });
		end
	end

	-- Sub-category rows. Still built for stats mode (not just achievement
	-- mode) even though the Stats category *list* only ever shows direct
	-- children of the Statistics root as flat, non-expandable entries
	-- (see AchieverAchievementFrameCategories_Update/AchieverAchievementFrameCategories_SelectButton) --
	-- AchieverAchievementFrameStats_Update reads this same .parent relationship to
	-- group a selected top-level stat category's content-pane rows under
	-- its own sub-category headers (e.g. Character -> Wealth/Gear/...).
	local _, parent;
	for i = table.getn(cats), 1, -1 do
		_, parent = Achiever_GetCategoryInfo(cats[i]);
		if ( (directCount[cats[i]] or 0) > 0 ) then
			-- Find the parent's index first, then insert after the search
			-- completes -- inserting into `categories` mid-traversal (via next)
			-- is exactly the kind of table mutation that hung this client once
			-- the tree got big enough (the Statistics tree, after disabling
			-- patch filtering, crossed whatever size this Lua tolerates).
			local matchIndex, matchCategory;
			for j = 1, table.getn(categories) do
				if ( categories[j].id == parent ) then
					matchIndex = j;
					matchCategory = categories[j];
					break;
				end
			end
			if ( matchIndex ) then
				matchCategory.parent = true;
				matchCategory.collapsed = true;
				tinsert(categories, matchIndex + 1, { ["id"] = cats[i], ["parent"] = matchCategory.id, ["hidden"] = true});
			end
		end
	end
end

local displayCategories = {};
function AchieverAchievementFrameCategories_Update ()
	local scrollFrame = AchieverAchievementFrameCategoriesContainer

	local categories = ACHIEVEMENTUI_CATEGORIES;
	local buttons = scrollFrame.buttons;
	-- Guard against a startup race: AchieverAchievementFrameCategories_OnShow
	-- (which calls this) can fire before AchieverAchievementFrameCategories_OnEvent's
	-- own ADDON_LOADED handler has had a chance to run
	-- AchieverHybridScrollFrame_CreateButtons and populate scrollFrame.buttons --
	-- confirmed via live 1.14.2 testing (toggling the frame open via the
	-- ACHIEVER_TOGGLE keybind, right at login) that this can happen before
	-- there's anything to update yet. That same ADDON_LOADED handler calls
	-- this function again itself once buttons genuinely exist, so bailing
	-- out here is a safe no-op, not a missed update.
	if (not buttons) then return; end

	local displayCategories = displayCategories;

	while ( table.getn(displayCategories) > 0 ) do
		table.remove(displayCategories);
	end

	local selection = achievementFunctions.selectedCategory;
	if ( selection == ACHIEVEMENT_COMPARISON_SUMMARY_ID or selection == ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID ) then
		selection = "summary";
	end
	
	local parent;
	if ( selection ) then
		for i, category in next, categories do
			if ( category.id == selection ) then
				parent = category.parent;
			end
		end
	end

	-- Stats mode's category list only ever shows direct children of the
	-- Statistics root -- never reveal hidden sub-category rows there, even
	-- if `selection` would otherwise resolve to one (see
	-- AchieverAchievementFrameCategories_GetCategoryList for why the underlying
	-- .parent data is still built for stats mode regardless).
	if ( achievementFunctions.categoryAccessor == Achiever_GetStatisticsCategoryList ) then
		parent = nil;
	end

	for i, category in next, categories do
		if ( not category.hidden ) then
			tinsert(displayCategories, category);
		elseif ( parent and category.id == parent ) then
			category.collapsed = false;
			tinsert(displayCategories, category);
		elseif ( parent and category.parent and category.parent == parent ) then
			category.hidden = false;
			tinsert(displayCategories, category);
		end
	end
	
	local numCategories = table.getn(displayCategories);
	local numButtons = table.getn(buttons);

	local totalHeight = numCategories * buttons[1]:GetHeight();

	-- Every category/subcategory row has its own permanent button (pool is
	-- sized to the full tree up front -- see the noVirtualize setup above), so
	-- display position maps directly to button index; no scroll-offset
	-- remapping/button-recycling needed.
	local element
	for i = 1, numButtons do
		element = displayCategories[i];
		if ( element ) then
			AchieverAchievementFrameCategories_DisplayButton(buttons[i], element);
			if ( selection and element.id == selection ) then
				buttons[i]:LockHighlight();
			else
				buttons[i]:UnlockHighlight();
			end
			buttons[i]:Show();
		else
			buttons[i].element = nil;
			buttons[i]:Hide();
		end
	end

	AchieverHybridScrollFrame_Update(scrollFrame, totalHeight, totalHeight);

	return displayCategories;
end

function AchieverAchievementFrameCategories_DisplayButton (button, element)
	if ( not element ) then
		button.element = nil;
		button:Hide();
		return;
	end
	
	button:Show();
	if ( type(element.parent) == "number" ) then
		button:SetWidth(ACHIEVEMENTUI_CATEGORIESWIDTH - 25);
		button.label:SetFontObject("GameFontHighlight");
		button.parentID = element.parent;
		button.background:SetVertexColor(0.6, 0.6, 0.6);
	else
		button:SetWidth(ACHIEVEMENTUI_CATEGORIESWIDTH - 10);
		button.label:SetFontObject("GameFontNormal");
		button.parentID = element.parent;
		button.background:SetVertexColor(1, 1, 1);
	end
	
	local categoryName, parentID, flags;
	local numAchievements, numCompleted;
	
	local id = element.id;
	
	-- kind of janky
	if ( id == "summary" ) then
		categoryName = ACHIEVEMENT_SUMMARY_CATEGORY;
		numAchievements, numCompleted = Achiever_GetNumCompletedAchievements();
	else
		categoryName, parentID, flags = Achiever_GetCategoryInfo(id);
		numAchievements, numCompleted = AchieverAchievementFrame_GetCategoryTotalNumAchievements(id, true);
	end
	button.label:SetText(categoryName);
	button.categoryID = id;
	button.flags = flags;
	button.element = element;

	-- For the tooltip
	button.name = categoryName;
	if ( id == FEAT_OF_STRENGTH_ID ) then
		-- This is the feat of strength category since it's sorted to the end of the list
		button.text = FEAT_OF_STRENGTH_DESCRIPTION;
		button.showTooltipFunc = AchieverAchievementFrameCategory_FeatOfStrengthTooltip;
	elseif ( AchieverAchievementFrame.selectedTab == 1 ) then
		button.text = nil;
		button.numAchievements = numAchievements;
		button.numCompleted = numCompleted;
		button.numCompletedText = numCompleted.."/"..numAchievements;
		button.showTooltipFunc = AchieverAchievementFrameCategory_StatusBarTooltip;
	else
		button.showTooltipFunc = nil;
	end
end

function AchieverAchievementFrameCategory_StatusBarTooltip(self)
	if (type(self) ~= "table") then return; end

	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	GameTooltip:SetMinimumWidth(128, 1);
	GameTooltip:SetText(self.name, 1, 1, 1, nil, 1);
	GameTooltip_ShowStatusBar(GameTooltip, 0, self.numAchievements, self.numCompleted, self.numCompletedText);
	GameTooltip:Show();
end

function AchieverAchievementFrameCategory_FeatOfStrengthTooltip(self)
	if (type(self) ~= "table") then return; end

	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	GameTooltip:SetText(self.name, 1, 1, 1);
	GameTooltip:AddLine(self.text, nil, nil, nil, 1);
	GameTooltip:Show();
end

function AchieverAchievementFrameCategories_UpdateTooltip()
	local container = AchieverAchievementFrameCategoriesContainer;
	if ( not container:IsVisible() or not container.buttons ) then
		return;
	end
	
	for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
		if ( Achiever_IsMouseOverFrame(button) and button.showTooltipFunc ) then
			button:showTooltipFunc();
			break;
		end
	end
end

function AchieverAchievementFrameCategories_SelectButton (button)
	if ( not button.element ) then
		return;
	end
	local id = button.element.id;

	-- Stats mode never expands/collapses -- its category list only ever
	-- shows direct children of the Statistics root; clicking one just
	-- selects it (see AchieverAchievementFrameCategories_Update for the matching
	-- display-side restriction).
	if ( type(button.element.parent) ~= "number" and achievementFunctions.categoryAccessor ~= Achiever_GetStatisticsCategoryList ) then
		-- Is top level category (can expand/contract)
		if ( button.isSelected and button.element.collapsed == false ) then
			button.element.collapsed = true;
			for i, category in next, ACHIEVEMENTUI_CATEGORIES do
				if ( category.parent == id ) then
					category.hidden = true;
				end
			end
		else
			for i, category in next, ACHIEVEMENTUI_CATEGORIES do
				if ( category.parent == id ) then
					category.hidden = false;
				elseif ( category.parent == true ) then
					category.collapsed = true;
				elseif ( category.parent ) then
					category.hidden = true;
				end
			end
			button.element.collapsed = false;
		end
	end
	
	local buttons = AchieverAchievementFrameCategoriesContainer.buttons;
	for _, button in next, buttons do
		button.isSelected = nil;
	end
	
	button.isSelected = true;
	
	if ( id == achievementFunctions.selectedCategory ) then
		-- If this category was selected already, bail after changing collapsed states
		return
	end
	
	--Intercept "summary" category
	if ( id == "summary" ) then
		if ( achievementFunctions == ACHIEVEMENT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameSummary);
			achievementFunctions.selectedCategory = id;
			return;
		elseif (  achievementFunctions == STAT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameStats);
			achievementFunctions.selectedCategory = ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID;
			AchieverAchievementFrameStatsContainerScrollBar:SetValue(0);
		elseif ( achievementFunctions == COMPARISON_ACHIEVEMENT_FUNCTIONS ) then
			-- Put the summary stuff for comparison here, Derek!
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonContainer);
			achievementFunctions.selectedCategory = ACHIEVEMENT_COMPARISON_SUMMARY_ID;
			AchieverAchievementFrameComparisonContainerScrollBar:SetValue(0);
			AchieverAchievementFrameComparison_UpdateStatusBars(ACHIEVEMENT_COMPARISON_SUMMARY_ID);
		elseif ( achievementFunctions == COMPARISON_STAT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonStatsContainer);
			achievementFunctions.selectedCategory = ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID;
			AchieverAchievementFrameComparisonStatsContainerScrollBar:SetValue(0);
		end
		
	else
		if ( achievementFunctions == STAT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameStats);
			AchieverAchievementFrameStatsContainerScrollBar:SetValue(0);
		elseif ( achievementFunctions == ACHIEVEMENT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameAchievements);
			AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(0);
			if ( id == FEAT_OF_STRENGTH_ID ) then
				AchieverAchievementFrameFilterDropDown:Hide();
				AchieverAchievementFrameHeaderRightDDLInset:Hide();
			else
				AchieverAchievementFrameFilterDropDown:Show();
				AchieverAchievementFrameHeaderRightDDLInset:Show();
			end
		elseif ( achievementFunctions == COMPARISON_ACHIEVEMENT_FUNCTIONS ) then
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonContainer);
			AchieverAchievementFrameComparisonContainerScrollBar:SetValue(0);
			AchieverAchievementFrameComparison_UpdateStatusBars(id);
		else
			AchieverAchievementFrame_ShowSubFrame(AchieverAchievementFrameComparison, AchieverAchievementFrameComparisonStatsContainer);
			AchieverAchievementFrameComparisonStatsContainerScrollBar:SetValue(0);
		end
		achievementFunctions.selectedCategory = id;
	end
	
	if ( achievementFunctions.clearFunc ) then
		achievementFunctions.clearFunc();
	end
	
	achievementFunctions.updateFunc();
end

function AchieverAchievementFrameAchievements_OnShow()
	if ( achievementFunctions.selectedCategory == FEAT_OF_STRENGTH_ID ) then
		AchieverAchievementFrameFilterDropDown:Hide();
		AchieverAchievementFrameHeaderRightDDLInset:Hide();
	else
		AchieverAchievementFrameFilterDropDown:Show();
		AchieverAchievementFrameHeaderRightDDLInset:Show();
	end

	-- AchievementTemplate's own inline <OnClick> now passes `this or self`
	-- (AchievementUI.xml) -- see AchieverAchievementFrameCategories_OnShow's
	-- matching comment for the full explanation.
end

function AchieverAchievementFrameCategories_ClearSelection ()
	local buttons = AchieverAchievementFrameCategoriesContainer.buttons;
	for _, button in next, buttons do
		button.isSelected = nil;
		button:UnlockHighlight();
	end
	
	for i, category in next, ACHIEVEMENTUI_CATEGORIES do	
		if ( category.parent == true ) then
			category.collapsed = true;
		elseif ( category.parent ) then
			category.hidden = true;
		end
	end
end

function AchieverAchievementFrameComparison_UpdateStatusBars (id)
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(id);
	local name = Achiever_GetCategoryInfo(id);
	
	if ( id == ACHIEVEMENT_COMPARISON_SUMMARY_ID ) then
		name = ACHIEVEMENT_SUMMARY_CATEGORY;
	end
	
	local statusBar = AchieverAchievementFrameComparisonSummaryPlayerStatusBar;
	statusBar:SetMinMaxValues(0, numAchievements);
	statusBar:SetValue(numCompleted);
	statusBar.title:SetText(string.format(ACHIEVEMENTS_COMPLETED_CATEGORY, name));
	statusBar.text:SetText(numCompleted.."/"..numAchievements);

	local friendCompleted = Achiever_GetComparisonCategoryNumAchievements(id);

	statusBar = AchieverAchievementFrameComparisonSummaryFriendStatusBar;
	statusBar:SetMinMaxValues(0, numAchievements);
	statusBar:SetValue(friendCompleted);
	statusBar.text:SetText(friendCompleted.."/"..numAchievements);
end

-- [[ AchievementCategoryButton ]] --

function AchievementCategoryButton_OnLoad (frame)
	local this = frame or this;
	if (type(this) ~= "table" or not this.GetName) then return; end

	this:EnableMouse(true);
	this:EnableMouseWheel(true);

	local buttonName = this:GetName();

	this.label = _G[buttonName .. "Label"];
	this.background = _G[buttonName.."Background"];
end

function AchievementCategoryButton_OnClick (button)
	if (type(button) ~= "table" or not button.GetName) then return; end

	AchieverAchievementFrameCategories_SelectButton(button);
	AchieverAchievementFrameCategories_Update();
end

-- [[ AchieverAchievementFrameAchievements ]] --

function AchieverAchievementFrameAchievements_OnLoad (self)
	AchieverAchievementFrameAchievementsContainerScrollBar.ShowOriginal = AchieverAchievementFrameAchievementsContainerScrollBar.Show;
	AchieverAchievementFrameAchievementsContainerScrollBar.Show =
		function (self)
			AchieverAchievementFrameAchievements:SetWidth(504);
			for _, button in next, AchieverAchievementFrameAchievements.buttons do
				button:SetWidth(496);
			end
			self:ShowOriginal();
		end

	AchieverAchievementFrameAchievementsContainerScrollBar.HideOriginal = AchieverAchievementFrameAchievementsContainerScrollBar.Hide;
	AchieverAchievementFrameAchievementsContainerScrollBar.Hide =
		function (self)
			AchieverAchievementFrameAchievements:SetWidth(530);
			for _, button in next, AchieverAchievementFrameAchievements.buttons do
				button:SetWidth(522);
			end
			self:HideOriginal();
		end
		
	self:RegisterEvent("ADDON_LOADED");
	AchieverAchievementFrameAchievementsContainerScrollBarBG:Show();
	AchieverAchievementFrameAchievementsContainer.update = AchieverAchievementFrameAchievements_Update;
	AchieverHybridScrollFrame_CreateButtons(AchieverAchievementFrameAchievementsContainer, "AchievementTemplate", 0, -2);
	-- Reliable-OnClick attachment is deliberately NOT done here -- see
	-- AchieverAchievementFrameCategories_OnShow's comment for why (confirmed
	-- via live 1.12.1 testing that SetScript("OnClick", ...) attached this
	-- early, within the same synchronous ADDON_LOADED handler that just
	-- created these buttons, never actually fires for real mouse clicks on
	-- this client) -- done instead in AchieverAchievementFrameAchievements_OnShow
	-- below. Iterates AchieverAchievementFrameAchievementsContainer.buttons
	-- (populated directly by AchieverHybridScrollFrame_CreateButtons itself
	-- with the real CreateFrame() return values) rather than
	-- AchieverAchievementFrameAchievements.buttons (populated inside
	-- AchievementButton_OnLoad, which is itself subject to the same
	-- this-binding unreliability and so can't be trusted to be complete) to
	-- make sure every created row gets fixed up, not just the ones whose own
	-- OnLoad happened to succeed.
	for _, button in next, AchieverAchievementFrameAchievementsContainer.buttons do
		-- AchievementIcon_OnLoad/AchieverAchievementShield_OnLoad are each
		-- their own separate script instance for the icon/points-shield
		-- widgets NESTED inside this row -- same this-binding unreliability
		-- as everywhere else, confirmed by their own guard comments
		-- ("...can pass a non-Frame value when instantiated via a dynamic
		-- Lua-side CreateFrame() call"). If either silently no-ops, the row
		-- never gets a working .icon.texture/.shield.points/.shield.icon,
		-- and -- worse -- AchievementButton_Saturate/Desaturate (called
		-- from AchievementButton_OnLoad's own tail end) then errors calling
		-- the missing self.icon:Desaturate()/self.shield:Desaturate()
		-- methods, aborting OnLoad AFTER .label already got set but before
		-- points/icon rendering ever runs -- exactly matching "correct
		-- name, no icon, no points" reports. Fixing icon/shield up front,
		-- via a direct _G lookup (reliable regardless of whether the row's
		-- own OnLoad has run yet), before AchievementButton_OnLoad can run,
		-- means that call -- whether triggered here or later via
		-- AchievementButton_DisplayAchievement's own fallback -- always has
		-- working nested widgets to call into.
		local buttonName = button:GetName();
		local iconFrame = _G[buttonName .. "Icon"];
		local shieldFrame = _G[buttonName .. "Shield"];
		if (iconFrame and not iconFrame.texture) then
			AchievementIcon_OnLoad(iconFrame);
		end
		if (shieldFrame and not shieldFrame.icon) then
			AchieverAchievementShield_OnLoad(shieldFrame);
		end
		if (not button.label) then
			AchievementButton_OnLoad(button);
		end
	end
	-- Attached here (not left as AchievementUI.xml's own inline <OnEvent>
	-- body on this frame, now dead code for the real ADDON_LOADED event --
	-- Router.lua's synthetic ACHIEVEMENT_EARNED/etc. calls into this function
	-- directly, unaffected either way) since event/arg1 aren't reliably
	-- bound in inline script bodies beyond self.
	self:SetScript("OnEvent", AchieverAchievementFrameAchievements_OnEvent);
end

-- frame/ev/data (not self/event/...) so the fallback below is a real
-- fallback rather than a same-named parameter silently shadowing the
-- global with an always-nil value on 1.12.1, where SetScript-attached
-- handlers never receive real arguments -- confirmed the hard way on
-- AchieverAchievementFrameCategories_OnEvent's first attempt at this fix.
-- `data` (not `...`) for the same reason as updateTrackedAchievements/
-- AchieverAchievementFrame_ShowSubFrame above: `...` can't be used at all
-- here beyond a function's own parameter-list declaration on 1.12.1's Lua
-- 5.0, and every call site (both the XML OnEvent below and Router.lua's
-- direct Achiever_EmitAchievementEarned/etc. calls) already only ever
-- passes at most one extra value beyond frame+event.
function AchieverAchievementFrameAchievements_OnEvent (frame, ev, data)
	local self = frame or this;
	local event = ev or event;
	if ( event == "ADDON_LOADED" ) then
		self:RegisterEvent("ACHIEVEMENT_EARNED");
		self:RegisterEvent("CRITERIA_UPDATE");
		self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE");

		updateTrackedAchievements({ Achiever_GetTrackedAchievements() });
	elseif ( event == "ACHIEVEMENT_EARNED" ) then
		local achievementID = data;
		AchieverAchievementFrameCategories_Update();
		AchieverAchievementFrameCategories_UpdateTooltip();
		-- This has to happen before AchieverAchievementFrameAchievements_ForceUpdate() in order to achieve the behavior we want, since it clears the selection for progressive achievements.
		local selection = AchieverAchievementFrameAchievements.selection;
		AchieverAchievementFrameAchievements_ForceUpdate();
		if ( AchieverAchievementFrameAchievementsContainer:IsShown() and selection == achievementID ) then
			AchieverAchievementFrame_SelectAchievement(selection, true);
		end
		AchieverAchievementFrameHeaderPoints:SetText(Achiever_GetTotalAchievementPoints());

	elseif ( event == "CRITERIA_UPDATE" ) then
		if ( AchieverAchievementFrameAchievements.selection ) then
			local id = AchieverAchievementFrameAchievementsObjectives.id;
			local button = AchieverAchievementFrameAchievementsObjectives:GetParent();
			AchieverAchievementFrameAchievementsObjectives.id = nil;
			AchievementButton_DisplayObjectives(button, id, button.completed);
			AchieverAchievementFrameAchievements_Update();
		else
			AchieverAchievementFrameAchievementsObjectives.id = nil; -- Force redraw
		end
	elseif ( event == "TRACKED_ACHIEVEMENT_UPDATE" ) then
		for k, v in next, trackedAchievements do
			trackedAchievements[k] = nil;
		end
		
		updateTrackedAchievements({ Achiever_GetTrackedAchievements() });
	end
	
	if ( AchievementMicroButton and not AchievementMicroButton:IsShown() ) then
		AchievementMicroButton_Update();
	end
end

function AchieverAchievementFrameAchievementsBackdrop_OnLoad (self)
	if (type(self) ~= "table" or not self.SetBackdropBorderColor) then return; end

	-- The old <Backdrop> XML tag (AchievementUI.xml) that used to establish
	-- this is a no-op on 1.14.2+ -- see AchieverBackdropCompat's own comment
	-- (CompatTemplates_1_14_2.xml) for why -- so it's set here in Lua instead,
	-- identically on both clients. SetBackdropBorderColor below has no visible
	-- effect without a backdrop already set to recolor.
	self:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, edgeSize = 16, tileSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } });
	self:SetBackdropBorderColor(ACHIEVEMENTUI_GOLDBORDER_R, ACHIEVEMENTUI_GOLDBORDER_G, ACHIEVEMENTUI_GOLDBORDER_B, ACHIEVEMENTUI_GOLDBORDER_A);
	self:SetFrameLevel(self:GetFrameLevel()+1);
end

function AchieverAchievementFrameAchievements_Update ()
	local category = achievementFunctions.selectedCategory;
	if ( category == "summary" ) then
		return;
	end
	local scrollFrame = AchieverAchievementFrameAchievementsContainer
	
	local offset = AchieverHybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numAchievements, numCompleted, completedOffset = ACHIEVEMENTUI_SELECTEDFILTER(category);
	local numButtons = table.getn(buttons);
	
	-- If the current category is feats of strength and there are no entries then show the explanation text
	if ( AchieverAchievementFrame_IsFeatOfStrength() and numAchievements == 0 ) then
		AchieverAchievementFrameAchievementsFeatOfStrengthText:Show();
	else
		AchieverAchievementFrameAchievementsFeatOfStrengthText:Hide();
	end
	
	local selection = AchieverAchievementFrameAchievements.selection;
	if ( selection ) then
		AchievementButton_ResetObjectives();
	end
	
	local extraHeight = scrollFrame.largeButtonHeight or ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT

	local achievementIndex;
	local displayedHeight = 0;
	for i = 1, numButtons do
		achievementIndex = i + offset + completedOffset;
		if ( achievementIndex > numAchievements + completedOffset ) then
			buttons[i]:Hide();
		else
			AchievementButton_DisplayAchievement(buttons[i], category, achievementIndex, selection);
			displayedHeight = displayedHeight + buttons[i]:GetHeight();
		end
	end
	
	local totalHeight = numAchievements * ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT;
	totalHeight = totalHeight + (extraHeight - ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT);
	
	AchieverHybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);

	if ( selection ) then
		AchieverAchievementFrameAchievements.selection = selection;
	else
		AchieverHybridScrollFrame_CollapseButton(scrollFrame);
	end
end

function AchieverAchievementFrameAchievements_ForceUpdate ()
	if ( AchieverAchievementFrameAchievements.selection ) then
		local nextID = Achiever_GetNextAchievement(AchieverAchievementFrameAchievements.selection);
		local id, _, _, completed = Achiever_GetAchievementInfo(AchieverAchievementFrameAchievements.selection);
		if ( nextID and completed ) then
			AchieverAchievementFrameAchievements.selection = nil;
		end
	end
	AchieverAchievementFrameAchievementsObjectives:Hide();
	AchieverAchievementFrameAchievementsObjectives.id = nil;

	local buttons = AchieverAchievementFrameAchievementsContainer.buttons;
	for i, button in next, buttons do
		button.id = nil;
	end
	
	AchieverAchievementFrameAchievements_Update();
end

function AchieverAchievementFrameAchievements_ClearSelection ()
	AchievementButton_ResetObjectives();
	for _, button in next, AchieverAchievementFrameAchievements.buttons do
		button:Collapse();
		if ( not Achiever_IsMouseOverFrame(button) ) then
			button.highlight:Hide();
		end
		button.selected = nil;
		if ( not button.tracked:GetChecked() ) then
			button.tracked:Hide();
		end
		button.description:Show();
		button.hiddenDescription:Hide();
	end
	
	AchieverAchievementFrameAchievements.selection = nil;
end

-- [[ Achievement Icon ]] --

function AchievementIcon_Desaturate (self)
	self.bling:SetVertexColor(.6, .6, .6, 1);
	self.frame:SetVertexColor(.75, .75, .75, 1);
	self.texture:SetVertexColor(.55, .55, .55, 1);
end

function AchievementIcon_Saturate (self)
	self.bling:SetVertexColor(1, 1, 1, 1);
	self.frame:SetVertexColor(1, 1, 1, 1);
	self.texture:SetVertexColor(1, 1, 1, 1);
end

function AchievementIcon_OnLoad (self)
	-- Guard against a non-Frame self -- confirmed via live 1.12.1 testing
	-- that this template's own inline <OnLoad> (self or this) can pass a
	-- non-Frame value when instantiated via a dynamic Lua-side CreateFrame()
	-- call; AchieverAchievementFrameSummary_UpdateAchievements' own explicit
	-- fallback (passing the real icon frame directly) is the reliable path.
	-- type(self) == "table" alone isn't enough -- confirmed via live testing
	-- that the wrong value here is ITSELF a plain table (just not a Frame,
	-- lacking GetName/etc.), not nil and not some other primitive type.
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.bling = _G[name .. "Bling"];
	self.texture = _G[name .. "Texture"];
	self.frame = _G[name .. "Overlay"];
	
	self.Desaturate = AchievementIcon_Desaturate;
	self.Saturate = AchievementIcon_Saturate;
end

-- [[ Achievement Shield ]] --

function AchieverAchievementShield_Desaturate (self)
	self.icon:SetTexCoord(.5, 1, 0, 1);
end

function AchieverAchievementShield_Saturate (self)
	self.icon:SetTexCoord(0, .5, 0, 1);
end

function AchieverAchievementShield_OnLoad (self)
	-- See AchievementIcon_OnLoad's matching guard comment.
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.icon = _G[name .. "Icon"];
	self.points = _G[name .. "Points"];
	
	self.Desaturate = AchieverAchievementShield_Desaturate;
	self.Saturate = AchieverAchievementShield_Saturate;
end

-- [[ AchievementButton ]] --

ACHIEVEMENTBUTTON_DESCRIPTIONHEIGHT = 20;
ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT = 84;
ACHIEVEMENTBUTTON_CRITERIAROWHEIGHT = 15;
ACHIEVEMENTBUTTON_METAROWHEIGHT = 14;
ACHIEVEMENTBUTTON_MAXHEIGHT = 232;
ACHIEVEMENTBUTTON_TEXTUREHEIGHT = 128;

function AchievementButton_UpdatePlusMinusTexture (button)
	local id = button.id;
	if ( not id ) then
		return; -- This happens when we create buttons
	end

	local display = false;
	if ( Achiever_AchievementHasDisplayableCriteria(id) ) then
		display = true;
	elseif ( Achiever_GetPreviousAchievement(id) and button.completed ) then
		display = true;
	end
	
	if ( display ) then
		button.plusMinus:Show();			
		if ( button.collapsed and button.saturated ) then
			button.plusMinus:SetTexCoord(0, .5, 0, .5);
		elseif ( button.collapsed ) then
			button.plusMinus:SetTexCoord(.5, 1, 0, .5);
		elseif ( button.saturated ) then
			button.plusMinus:SetTexCoord(0, .5, .5, 1);
		else
			button.plusMinus:SetTexCoord(.5, 1, .5, 1);
		end
	else
		button.plusMinus:Hide();
	end
end

function AchievementButton_Collapse (self)
	if ( self.collapsed ) then
		return;
	end
	
	self.collapsed = true;
	AchievementButton_UpdatePlusMinusTexture(self);
	self:SetHeight(ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT);	
	_G[self:GetName() .. "Background"]:SetTexCoord(0, 1, 1-(ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT / 256), 1);
	_G[self:GetName() .. "Glow"]:SetTexCoord(0, 1, 0, ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT / 128);
	
	if ( not self.tracked:GetChecked() ) then
		self.tracked:Hide();
	end
end

function AchievementButton_Expand (self, height)
	if ( not self.collapsed ) then
		return;
	end
	
	self.collapsed = nil;
	AchievementButton_UpdatePlusMinusTexture(self);
	self:SetHeight(height);
	_G[self:GetName() .. "Background"]:SetTexCoord(0, 1, max(0, 1-(height / 256)), 1);
	_G[self:GetName() .. "Glow"]:SetTexCoord(0, 1, 0, (height+5) / 128);
end

function AchievementButton_Saturate (self)
	local name = self:GetName();
	self.saturated = true;	
	_G[name .. "TitleBackground"]:SetTexCoord(0, 0.9765625, 0, 0.3125);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal");
	_G[name .. "Glow"]:SetVertexColor(1.0, 1.0, 1.0);
	self.icon:Saturate();
	self.shield:Saturate();
	self.shield.points:SetVertexColor(1, 1, 1);
	self.reward:SetVertexColor(1, .82, 0);
	self.label:SetVertexColor(1, 1, 1);
	self.description:SetTextColor(0, 0, 0, 1);
	self.description:SetShadowOffset(0, 0);
	AchievementButton_UpdatePlusMinusTexture(self);
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
end

function AchievementButton_Desaturate (self)
	local name = self:GetName();
	self.saturated = nil;
	_G[name .. "TitleBackground"]:SetTexCoord(0, 0.9765625, 0.34375, 0.65625);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal-Desaturated");
	_G[name .. "Glow"]:SetVertexColor(.22, .17, .13);
	self.icon:Desaturate();
	self.shield:Desaturate();
	self.shield.points:SetVertexColor(.65, .65, .65);
	self.reward:SetVertexColor(.8, .8, .8);
	self.label:SetVertexColor(.65, .65, .65);
	self.description:SetTextColor(1, 1, 1, 1); 
	self.description:SetShadowOffset(1, -1);
	AchievementButton_UpdatePlusMinusTexture(self);
	self:SetBackdropBorderColor(.5, .5, .5);
end

-- See AchieverAchievementFrameCriteria_OnLoad's matching comment -- this
-- template is instantiated via the generic
-- AchieverHybridScrollFrame_CreateButtons (ListScrollFrame.lua), so there's
-- no single dedicated creation call site to add an explicit fallback next
-- to; AchievementButton_DisplayAchievement (the natural "this row is about
-- to be used" checkpoint, called every time a row's data is refreshed)
-- carries the explicit fallback call instead.
function AchievementButton_OnLoad (self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.label = _G[name .. "Label"];
	self.description = _G[name .. "Description"];
	self.hiddenDescription = _G[name .. "HiddenDescription"];
	self.reward = _G[name .. "Reward"];
	self.rewardBackground = _G[name.."RewardBackground"];
	self.icon = _G[name .. "Icon"];
	self.shield = _G[name .. "Shield"];
	self.objectives = _G[name .. "Objectives"];
	self.highlight = _G[name .. "Highlight"];
	self.dateCompleted = _G[name .. "DateCompleted"]
	self.tracked = _G[name .. "Tracked"];
	self.check = _G[name .. "Check"];
	self.plusMinus = _G[name .. "PlusMinus"];
	
	self.dateCompleted:ClearAllPoints();
	self.dateCompleted:SetPoint("TOP", self.shield, "BOTTOM", -3, 6);
	if ( not ACHIEVEMENTUI_FONTHEIGHT ) then
		local _, fontHeight = self.description:GetFont();
		ACHIEVEMENTUI_FONTHEIGHT = fontHeight;
	end
	self.description:SetHeight(ACHIEVEMENTUI_FONTHEIGHT * ACHIEVEMENTUI_MAX_LINES_COLLAPSED);
	self.description:SetWidth(ACHIEVEMENTUI_MAXCONTENTWIDTH);			
	self.hiddenDescription:SetWidth(ACHIEVEMENTUI_MAXCONTENTWIDTH);

	-- See AchieverAchievementFrameAchievementsBackdrop_OnLoad's matching
	-- comment -- the old <Backdrop> XML tag is a no-op on 1.14.2+.
	self:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, edgeSize = 16 });
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
	self.Collapse = AchievementButton_Collapse;
	self.Expand = AchievementButton_Expand;
	self.Saturate = AchievementButton_Saturate;
	self.Desaturate = AchievementButton_Desaturate;
	
	self:Collapse();
	self:Desaturate();

	AchieverAchievementFrameAchievements.buttons = AchieverAchievementFrameAchievements.buttons or {};
	tinsert(AchieverAchievementFrameAchievements.buttons, self);
end

function AchievementButton_OnClick (self, ignoreModifiers)
	if (type(self) ~= "table" or not self.GetHeight) then return; end

	if(IsModifiedClick() and not ignoreModifiers) then
		-- ChatEdit_GetActiveWindow/ChatEdit_InsertLink are TBC+ API; 1.12 only
		-- ever has the one ChatFrameEditBox, shared/repositioned across chat
		-- windows, same pattern ContainerFrame.lua's real shift-click-to-link
		-- uses (ChatFrameEditBox:IsShown() + :Insert(link)).
		if ( IsModifiedClick("CHATLINK") and ChatFrameEditBox:IsShown() ) then
			local achievementLink = Achiever_GetAchievementLink(self.id);
			if ( achievementLink ) then
				ChatFrameEditBox:Insert(achievementLink);
			end
		end
		
		return;
	end

	if ( self.selected ) then
		if ( not Achiever_IsMouseOverFrame(self) ) then
			self.highlight:Hide();
		end
		AchieverAchievementFrameAchievements_ClearSelection()
		AchieverHybridScrollFrame_CollapseButton(AchieverAchievementFrameAchievementsContainer);
		AchieverAchievementFrameAchievements_Update();
		return;
	end
	AchieverAchievementFrameAchievements_ClearSelection()
	AchieverAchievementFrameAchievements_SelectButton(self);
	AchievementButton_DisplayAchievement(self, achievementFunctions.selectedCategory, self.index, self.id);
	AchieverHybridScrollFrame_ExpandButton(AchieverAchievementFrameAchievementsContainer, ((self.index - 1) * ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT), self:GetHeight());
	AchieverAchievementFrameAchievements_Update();
	if ( not ignoreModifiers ) then
		AchieverAchievementFrameAchievements_AdjustSelection();
	end
end

function AchievementButton_ToggleTracking (id)
	if ( trackedAchievements[id] ) then
		Achiever_RemoveTrackedAchievement(id);
		AchieverAchievementFrameAchievements_ForceUpdate();
		Achiever_WatchFrame_Update();
		return;
	end
	
	local count = Achiever_GetNumTrackedAchievements();
	
	if ( count >= WATCHFRAME_MAXACHIEVEMENTS ) then
		UIErrorsFrame:AddMessage(format(ACHIEVEMENT_WATCH_TOO_MANY, WATCHFRAME_MAXACHIEVEMENTS), 1.0, 0.1, 0.1, 1.0);
		return;
	end
	
	local _, _, _, completed = Achiever_GetAchievementInfo(id)
	if ( completed ) then
		UIErrorsFrame:AddMessage(ERR_ACHIEVEMENT_WATCH_COMPLETED, 1.0, 0.1, 0.1, 1.0);
		return;
	end
	
	Achiever_AddTrackedAchievement(id);
	AchieverAchievementFrameAchievements_ForceUpdate();
	Achiever_WatchFrame_Update();
	
	return true;
end
	
function AchievementButton_DisplayAchievement (button, category, achievement, selectionID)
	-- Explicit fallback for AchievementButton_OnLoad -- see that function's
	-- own comment. Gated on `not button.label` so this is a no-op, not a
	-- double-run (AchievementButton_OnLoad's own tinsert into
	-- AchieverAchievementFrameAchievements.buttons isn't safe to run twice),
	-- on a row whose own OnLoad already worked.
	if ( not button.label ) then
		AchievementButton_OnLoad(button);
	end

	local id, name, points, completed, month, day, year, description, flags, icon, rewardText = Achiever_GetAchievementInfo(category, achievement);
	if ( not id ) then
		button:Hide();
		return;
	else
		button:Show();
	end

	button.index = achievement;
	button.element = true;
	
	if ( button.id ~= id ) then
		button.id = id;
		button.label:SetWidth(ACHIEVEMENTBUTTON_LABELWIDTH);
		button.label:SetText(name)
	
		if ( Achiever_GetPreviousAchievement(id) ) then
			-- If this is a progressive achievement, show the total score.
			AchieverAchievementShield_SetPoints(AchievementButton_GetProgressivePoints(id), button.shield.points, AchievementPointsFont, AchievementPointsFontSmall);
		else
			AchieverAchievementShield_SetPoints(points, button.shield.points, AchievementPointsFont, AchievementPointsFontSmall);
		end
			
		if ( points > 0 ) then
			button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
		else
			button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
		end
		button.description:SetText(description);
		button.hiddenDescription:SetText(description);
		button.numLines = ceil(button.hiddenDescription:GetHeight() / ACHIEVEMENTUI_FONTHEIGHT);
		button.icon.texture:SetTexture(icon);
		if ( completed and not button.completed ) then
			button.completed = true;
			button.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
			button.dateCompleted:Show();
			button:Saturate();
		elseif ( completed ) then
			button.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
		else
			button.completed = nil;
			button.dateCompleted:Hide();
			button:Desaturate();
		end
		
		if ( rewardText == "" ) then
			button.reward:Hide();
			button.rewardBackground:Hide();
		else
			button.reward:SetText(rewardText);
			button.reward:Show();
			button.rewardBackground:Show();
			if ( button.completed ) then
				button.rewardBackground:SetVertexColor(1, 1, 1);
			else
				button.rewardBackground:SetVertexColor(0.35, 0.35, 0.35);
			end
		end		
		
		if ( Achiever_IsTrackedAchievement(id) ) then
			button.check:Show();
			button.label:SetWidth(button.label:GetStringWidth() + 4); -- This +4 here is to fudge around any string width issues that arize from resizing a string set to its string width. See bug 144418 for an example.
			button.tracked:SetChecked(true);
			button.tracked:Show();
		else
			button.check:Hide();
			button.tracked:SetChecked(false);
			button.tracked:Hide();
		end
		
		AchievementButton_UpdatePlusMinusTexture(button);
	end

	-- Debug-only patch indicator (Options tab: Debug Mode + "Show patch on
	-- achievements"), inline right after the achievement name -- same
	-- format as AchieverAchievementFrameStats_SetStat uses for stat rows.
	-- Deliberately outside the "id changed" guard above, so toggling the
	-- Debug Mode / Show-patch checkboxes (which don't change any button's
	-- underlying id) still updates already-displayed rows via
	-- AchieverAchievementFrameAchievements_ForceUpdate.
	if ( AchieverDB and AchieverDB.debugMode and AchieverDB.showPatchOnAchievements ) then
		button.label:SetText(name .. " |cff3399ff(" .. (Achiever_GetAchievementPatch(id) or "?") .. ")|r");
	else
		button.label:SetText(name);
	end

	if ( id == selectionID ) then
		local achievements = AchieverAchievementFrameAchievements;
		
		achievements.selection = button.id;
		achievements.selectionIndex = button.index;
		button.selected = true;
		button.highlight:Show();		
		local height = AchievementButton_DisplayObjectives(button, button.id, button.completed);
		if ( height == ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT ) then
			button:Collapse();
		else
			button:Expand(height);
		end
		if ( not completed ) then
			button.tracked:Show();
		end
	elseif ( button.selected ) then
		button.selected = nil;
		if ( not Achiever_IsMouseOverFrame(button) ) then
			button.highlight:Hide();
		end
		button:Collapse();
		button.description:Show();
		button.hiddenDescription:Hide();
	end
	
	return id;
end

function AchieverAchievementFrameAchievements_SelectButton (button)
	local achievements = AchieverAchievementFrameAchievements;
	
	achievements.selection = button.id;
	achievements.selectionIndex = button.index;
	button.selected = true;
end

function AchievementButton_ResetObjectives ()
	AchieverAchievementFrameAchievementsObjectives:Hide();
end

function AchievementButton_DisplayObjectives (button, id, completed)
	local objectives = AchieverAchievementFrameAchievementsObjectives;
	
	objectives:ClearAllPoints();
	objectives:SetParent(button);
	objectives:Show();
	objectives.completed = completed;
	local height = 0;
	if ( objectives.id == id ) then
		local ACHIEVEMENTMODE_CRITERIA = 1;
		if ( objectives.mode == ACHIEVEMENTMODE_CRITERIA ) then
			if ( objectives:GetHeight() > 0 ) then
				objectives:SetPoint("TOP", "$parentHiddenDescription", "BOTTOM", 0, -8);
				objectives:SetPoint("LEFT", "$parentIcon", "RIGHT", -5, 0);
				objectives:SetPoint("RIGHT", "$parentShield", "LEFT", -10, 0);
			end
			height = ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT + objectives:GetHeight();
		else
			objectives:SetPoint("TOP", "$parentHiddenDescription", "BOTTOM", 0, -8);
			height = ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT + objectives:GetHeight();
		end
	elseif ( completed and Achiever_GetPreviousAchievement(id) ) then
		objectives:SetHeight(0);
		AchievementButton_ResetCriteria();
		AchievementButton_ResetProgressBars();
		AchievementButton_ResetMiniAchievements();
		AchievementButton_ResetMetas();
		AchievementObjectives_DisplayProgressiveAchievement(objectives, id);
		objectives:SetPoint("TOP", "$parentHiddenDescription", "BOTTOM", 0, -8);
		height = ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT + objectives:GetHeight();
	else
		objectives:SetHeight(0);	
		AchievementButton_ResetCriteria();
		AchievementButton_ResetProgressBars();
		AchievementButton_ResetMiniAchievements();
		AchievementButton_ResetMetas();
		AchievementObjectives_DisplayCriteria(objectives, id);
		if ( objectives:GetHeight() > 0 ) then
			objectives:SetPoint("TOP", "$parentHiddenDescription", "BOTTOM", 0, -8);
			objectives:SetPoint("LEFT", "$parentIcon", "RIGHT", -5, -25);
			objectives:SetPoint("RIGHT", "$parentShield", "LEFT", -10, 0);
		end
		height = ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT + objectives:GetHeight();
	end

	if ( height ~= ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT or button.numLines > ACHIEVEMENTUI_MAX_LINES_COLLAPSED ) then		
		button.hiddenDescription:Show();
		button.description:Hide();
		local descriptionHeight = button.hiddenDescription:GetHeight();
		height = height + descriptionHeight - ACHIEVEMENTBUTTON_DESCRIPTIONHEIGHT;
		if ( button.reward:IsShown() ) then
			height = height + 4;
		end
	end
	
	objectives.id = id;
	return height;
end

function AchieverAchievementShield_SetPoints(points, pointString, normalFont, smallFont)
	if ( points == 0 ) then
		pointString:SetText("");
		return;
	end
	if ( points <= 100 ) then
		pointString:SetFontObject(normalFont);
	else
		pointString:SetFontObject(smallFont);
	end
	pointString:SetText(points);
end

function AchievementButton_ResetTable (t)
	for k, v in next, t do
		v:Hide();
	end
end

local criteriaTable = {}

function AchievementButton_ResetCriteria ()
	AchievementButton_ResetTable(criteriaTable);
end

-- Named function (not left as AchievementCriteriaTemplate's own inline
-- <OnLoad>) so AchievementButton_GetCriteria can also call it explicitly as
-- a reliable fallback -- see AchievementIcon_OnLoad's matching guard
-- comment (top of file) for why: self/this here can be a completely
-- unrelated table when this template is instantiated via a dynamic
-- Lua-side CreateFrame() call, same as the Summary tab's buttons.
function AchieverAchievementFrameCriteria_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.name = _G[name .. "Name"];
	self.check = _G[name .. "Check"];
	self:SetScript("OnMouseUp", function(btn, button)
		btn = btn or this;
		button = button or arg1;
		if ( type(btn) == "table" and btn.GetParent and button == "LeftButton" ) then
			btn:GetParent():GetParent():Click();
		end
	end);
end

function AchievementButton_GetCriteria (index)
	local criteriaTable = criteriaTable;

	if ( criteriaTable[index] ) then
		return criteriaTable[index];
	end

	local frame = CreateFrame("FRAME", "AchieverAchievementFrameCriteria" .. index, AchieverAchievementFrameAchievements, "AchievementCriteriaTemplate");
	if ( not frame.name ) then
		AchieverAchievementFrameCriteria_OnLoad(frame);
	end
	AchieverAchievementFrame_LocalizeCriteria(frame);
	criteriaTable[index] = frame;

	return frame;
end

-- The smallest table in WoW.
local miniTable = {}

function AchievementButton_ResetMiniAchievements ()
	AchievementButton_ResetTable(miniTable);
end

-- See AchieverAchievementFrameCriteria_OnLoad's matching comment.
function AchievementMiniAchievement_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.points = _G[name .. "Points"];
	self.icon = _G[name .. "Icon"];
end

function AchievementButton_GetMiniAchievement (index)
	local miniTable = miniTable;
	if ( miniTable[index] ) then
		return miniTable[index];
	end

	local frame = CreateFrame("FRAME", "AchieverAchievementFrameMiniAchievement" .. index, AchieverAchievementFrameAchievements, "MiniAchievementTemplate");
	if ( not frame.points ) then
		AchievementMiniAchievement_OnLoad(frame);
	end
	AchievementButton_LocalizeMiniAchievement(frame);
	-- MiniAchievementTemplate's own inline <OnEnter> (AchievementUI.xml)
	-- relies on this/self binding for that script instance -- confirmed via
	-- live 1.12.1 testing that this is unreliable for this dynamically-
	-- CreateFrame()'d widget the same way it is everywhere else in this
	-- addon (a stricter type/method guard there stopped it from erroring,
	-- but also meant the guard was correctly rejecting a stale table on
	-- every single hover, so the tooltip just silently never showed
	-- instead). Overriding here with the guaranteed-correct `frame`
	-- reference sidesteps the binding problem entirely rather than working
	-- around it -- same fix shape as the achievement/category/tab buttons.
	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
		if ( frame.name ) then
			GameTooltip:AddDoubleLine(frame.name, frame.date, nil, nil, nil, .5, .5, .5);
		end
		if ( frame.desc ) then
			GameTooltip:AddLine(frame.desc, 1, 1, 1, 1);
		end
		if ( frame.numCriteria ) then
			for i = 1, frame.numCriteria do
				GameTooltip:AddLine(frame["criteria"..i]);
			end
		end
		GameTooltip:Show();
	end);
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	miniTable[index] = frame;

	return frame;
end

local progressBarTable = {};

function AchievementButton_ResetProgressBars ()
	AchievementButton_ResetTable(progressBarTable);
end

-- See AchieverAchievementFrameCriteria_OnLoad's matching comment.
function AchievementProgressBar_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	self:SetStatusBarColor(0, .6, 0, 1);
	self:SetMinMaxValues(0, 100);
	self:SetValue(0);
	self.text = _G[self:GetName() .. "Text"];
	self:GetStatusBarTexture():SetDrawLayer("BORDER");
end

function AchievementButton_GetProgressBar (index)
	local progressBarTable = progressBarTable;
	if ( progressBarTable[index] ) then
		return progressBarTable[index];
	end

	local frame = CreateFrame("STATUSBAR", "AchieverAchievementFrameProgressBar" .. index, AchieverAchievementFrameAchievements, "AchievementProgressBarTemplate");
	if ( not frame.text ) then
		AchievementProgressBar_OnLoad(frame);
	end
	AchievementButton_LocalizeProgressBar(frame);
	AchievementProgressBar_CreateMoneyWidgets(frame);
	progressBarTable[index] = frame;

	return frame;
end

local function AchievementProgressBar_CreateMoneyIcon(frame, texCoordLeft, texCoordRight)
	local icon = frame:CreateTexture(nil, "OVERLAY");
	icon:SetWidth(12);
	icon:SetHeight(12);
	icon:SetTexture([[Interface\MoneyFrame\UI-MoneyIcons]]);
	icon:SetTexCoord(texCoordLeft, texCoordRight, 0, 1);
	icon:Hide();
	return icon;
end

local function AchievementProgressBar_CreateMoneyText(frame)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	text:Hide();
	return text;
end

-- Real gold/silver/copper icon+number pairs (same Interface\MoneyFrame\UI-MoneyIcons
-- crop AchievementStatButton_OnLoad's stat-row icons use) flanking the bar's
-- centered "/" text -- one chain growing left for the "current" amount, one
-- growing right for "required" -- used instead of an inline texture-escape
-- money string, which this 1.12 client doesn't support (see
-- Achiever_FormatMoney, Constants.lua).
function AchievementProgressBar_CreateMoneyWidgets(frame)
	frame.curGoldIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0, 0.25);
	frame.curGoldText = AchievementProgressBar_CreateMoneyText(frame);
	frame.curSilverIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0.25, 0.5);
	frame.curSilverText = AchievementProgressBar_CreateMoneyText(frame);
	frame.curCopperIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0.5, 0.75);
	frame.curCopperText = AchievementProgressBar_CreateMoneyText(frame);

	frame.reqGoldIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0, 0.25);
	frame.reqGoldText = AchievementProgressBar_CreateMoneyText(frame);
	frame.reqSilverIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0.25, 0.5);
	frame.reqSilverText = AchievementProgressBar_CreateMoneyText(frame);
	frame.reqCopperIcon = AchievementProgressBar_CreateMoneyIcon(frame, 0.5, 0.75);
	frame.reqCopperText = AchievementProgressBar_CreateMoneyText(frame);
end

function AchievementProgressBar_HideMoneyWidgets(frame)
	frame.curGoldIcon:Hide(); frame.curGoldText:Hide();
	frame.curSilverIcon:Hide(); frame.curSilverText:Hide();
	frame.curCopperIcon:Hide(); frame.curCopperText:Hide();
	frame.reqGoldIcon:Hide(); frame.reqGoldText:Hide();
	frame.reqSilverIcon:Hide(); frame.reqSilverText:Hide();
	frame.reqCopperIcon:Hide(); frame.reqCopperText:Hide();
end

-- Chains a money amount's gold/silver/copper icon+number pairs outward from
-- `separator` (the bar's own centered "/" text), skipping whichever
-- denominations Achiever_FormatMoney's same omit rule would drop (so e.g.
-- "1g 5c" doesn't leave a gap where a hidden, unshown "0s" pair would have
-- sat). growLeft chains right-to-left (for the "current" amount -- innermost,
-- nearest the separator, is copper); otherwise left-to-right (for
-- "required" -- innermost is gold) -- both read gold->silver->copper left to
-- right overall, same as Achiever_FormatMoney's text order.
local function AchievementProgressBar_LayoutMoneyChain(separator, money, growLeft, icons, texts)
	local gold, silver, copper = Achiever_SplitMoney(money);
	local amounts = { gold, silver, copper };
	local showing = {
		gold > 0,
		silver > 0,
		copper > 0 or (gold == 0 and silver == 0),
	};

	local order = growLeft and { 3, 2, 1 } or { 1, 2, 3 };
	local anchor, anchorPoint = separator, growLeft and "LEFT" or "RIGHT";
	for _, denomIndex in ipairs(order) do
		local icon, text = icons[denomIndex], texts[denomIndex];
		if ( showing[denomIndex] ) then
			text:SetText(amounts[denomIndex]);
			icon:ClearAllPoints();
			text:ClearAllPoints();
			if ( growLeft ) then
				icon:SetPoint("RIGHT", anchor, anchorPoint);
				text:SetPoint("RIGHT", icon, "LEFT");
				anchor, anchorPoint = text, "LEFT";
			else
				text:SetPoint("LEFT", anchor, anchorPoint);
				icon:SetPoint("LEFT", text, "RIGHT");
				anchor, anchorPoint = icon, "RIGHT";
			end
			icon:Show();
			text:Show();
		else
			icon:Hide();
			text:Hide();
		end
	end
end

-- Replaces the progress bar's plain "current / required" text with a
-- gold/silver/copper icon+number rendering for money-flagged criteria (e.g.
-- achievement 1176, "Loot 100 gold") -- see the ACHIEVEMENT_CRITERIA_MONEY_COUNTER
-- branch in AchievementObjectives_DisplayCriteria.
function AchievementProgressBar_SetMoneyText(frame, quantity, reqQuantity)
	frame.text:SetText("/");
	AchievementProgressBar_LayoutMoneyChain(frame.text, quantity, true,
		{ frame.curGoldIcon, frame.curSilverIcon, frame.curCopperIcon },
		{ frame.curGoldText, frame.curSilverText, frame.curCopperText });
	AchievementProgressBar_LayoutMoneyChain(frame.text, reqQuantity, false,
		{ frame.reqGoldIcon, frame.reqSilverIcon, frame.reqCopperIcon },
		{ frame.reqGoldText, frame.reqSilverText, frame.reqCopperText });
end

local metaCriteriaTable = {};

function AchievementButton_ResetMetas ()
	AchievementButton_ResetTable(metaCriteriaTable);
end

-- See AchieverAchievementFrameCriteria_OnLoad's matching comment.
function AchievementMetaCriteria_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.icon = _G[name .. "Icon"];
	self.label = _G[name .. "Label"];
	self.check = _G[name .. "Check"];
	self.border = _G[name .. "Border"];
end

function AchievementButton_GetMeta (index)
	local metaCriteriaTable = metaCriteriaTable;
	if ( metaCriteriaTable[index] ) then
		return metaCriteriaTable[index];
	end

	local frame = CreateFrame("BUTTON", "AchieverAchievementFrameMeta" .. index, AchieverAchievementFrameAchievements, "MetaCriteriaTemplate");
	if ( not frame.icon ) then
		AchievementMetaCriteria_OnLoad(frame);
	end
	AchievementButton_LocalizeMetaAchievement(frame);
	metaCriteriaTable[index] = frame;

	return frame;
end

function AchievementButton_GetProgressivePoints(achievementID)
	local points;
	local _, _, progressivePoints, completed = Achiever_GetAchievementInfo(achievementID);

	while Achiever_GetPreviousAchievement(achievementID) do
		achievementID = Achiever_GetPreviousAchievement(achievementID);
		_, _, points, completed = Achiever_GetAchievementInfo(achievementID);
		progressivePoints = progressivePoints+points;
	end
	
	if ( progressivePoints ) then
		return progressivePoints;
	else
		return 0;
	end
end

local achievementList = {};

function AchievementObjectives_DisplayProgressiveAchievement (objectivesFrame, id)
	local ACHIEVEMENTMODE_PROGRESSIVE = 2;
	local achievementID = id;

	local achievementList = achievementList;
	while ( table.getn(achievementList) > 0 ) do
		table.remove(achievementList);
	end
	
	tinsert(achievementList, 1, achievementID);
	while Achiever_GetPreviousAchievement(achievementID) do
		tinsert(achievementList, 1, Achiever_GetPreviousAchievement(achievementID));
		achievementID = Achiever_GetPreviousAchievement(achievementID);
	end
	
	local i = 0;
	for index, achievementID in ipairs(achievementList) do
		local _, achievementName, points, completed, month, day, year, description, flags, iconpath = Achiever_GetAchievementInfo(achievementID);
		
		local miniAchievement = AchievementButton_GetMiniAchievement(index);
		
		miniAchievement:Show();
		miniAchievement:SetParent(objectivesFrame);
		_G[miniAchievement:GetName() .. "Icon"]:SetTexture(iconpath);
		if ( index == 1 ) then
			miniAchievement:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", -4, -4);
		elseif ( index == 7 ) then
			miniAchievement:SetPoint("TOPLEFT", miniTable[1], "BOTTOMLEFT", 0, -8);
		else
			miniAchievement:SetPoint("TOPLEFT", miniTable[index-1], "TOPRIGHT", 4, 0);
		end
		
		miniAchievement.points:SetText(points);
		
		miniAchievement.numCriteria = 0;
		if ( not ( bit.band(flags, ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR) == ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR ) ) then
			for i = 1, Achiever_GetAchievementNumCriteria(achievementID) do
				local criteriaString, criteriaType, completed = Achiever_GetAchievementCriteriaInfo(achievementID, i);
				if ( completed == false ) then
					criteriaString = "|CFF808080 - " .. criteriaString;
				else
					criteriaString = "|CFF00FF00 - " .. criteriaString;
				end
				miniAchievement["criteria" .. i] = criteriaString;
				miniAchievement.numCriteria = i;
			end
		end
		miniAchievement.name = achievementName;
		miniAchievement.desc = description;
		if ( month ) then
			miniAchievement.date = string.format(SHORTDATE, day, month, year);
		end
		i = index;
	end
	
	objectivesFrame:SetHeight(math.ceil(i/6) * ACHIEVEMENTUI_PROGRESSIVEHEIGHT);
	objectivesFrame:SetWidth(min(i, 6) * ACHIEVEMENTUI_PROGRESSIVEWIDTH);
	objectivesFrame.mode = ACHIEVEMENTMODE_PROGRESSIVE;
end

function AchieverAchievementFrame_GetCategoryNumAchievements_All (categoryID)
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(categoryID);
	
	return numAchievements, numCompleted, 0;
end

function AchieverAchievementFrame_GetCategoryNumAchievements_Complete (categoryID)
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(categoryID);
	
	return numCompleted, numCompleted, 0;
end

function AchieverAchievementFrame_GetCategoryNumAchievements_Incomplete (categoryID)
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(categoryID);
	
	return numAchievements - numCompleted, 0, numCompleted
end

ACHIEVEMENTUI_SELECTEDFILTER = AchieverAchievementFrame_GetCategoryNumAchievements_All;

AchieverAchievementFrameFilters = { {text=ACHIEVEMENTFRAME_FILTER_ALL, func= AchieverAchievementFrame_GetCategoryNumAchievements_All},
 {text=ACHIEVEMENTFRAME_FILTER_COMPLETED, func=AchieverAchievementFrame_GetCategoryNumAchievements_Complete},
{text=ACHIEVEMENTFRAME_FILTER_INCOMPLETE, func=AchieverAchievementFrame_GetCategoryNumAchievements_Incomplete} };

function AchieverAchievementFrameFilterDropDown_OnLoad (self)
	if (type(self) ~= "table") then return; end

	self.relativeTo = "AchieverAchievementFrameFilterDropDown"
	self.xOffset = -14;
	self.yOffset = 10;
	UIDropDownMenu_Initialize(self, AchieverAchievementFrameFilterDropDown_Initialize);
end

-- Vanilla's real UIDropDownMenu_Initialize calls initFunction(level) -- just
-- the numeric menu level, never the frame itself (that's a later-client
-- convention: initFunction(self, level, menuList)). Reading that number as
-- "self" here is exactly what fed a number into UIDropDownMenu_SetText's
-- `frame` param below and crashed it -- the frame is always
-- AchieverAchievementFrameFilterDropDown regardless, so it's referenced directly.
function AchieverAchievementFrameFilterDropDown_Initialize ()
	local info = UIDropDownMenu_CreateInfo();
	for i, filter in ipairs(AchieverAchievementFrameFilters) do
		info.text = filter.text;
		info.value = i;
		info.arg1 = i;
		info.func = AchieverAchievementFrameFilterDropDownButton_OnClick;
		if ( filter.func == ACHIEVEMENTUI_SELECTEDFILTER ) then
			info.checked = 1;
			Achiever_UIDropDownMenu_SetText(filter.text, AchieverAchievementFrameFilterDropDown);
		else
			info.checked = nil;
		end
		UIDropDownMenu_AddButton(info);
	end
end

-- See Achiever_UIDropDownMenu_GetClickValue's own comment (Constants.lua)
-- for why this can't just read its first parameter directly -- that was
-- correct on vanilla and crashed on 1.14.2 ("attempt to index field '?' (a
-- nil value)", the clicked button landing where the filter index was
-- expected).
function AchieverAchievementFrameFilterDropDownButton_OnClick (a, b)
	AchieverAchievementFrame_SetFilter(Achiever_UIDropDownMenu_GetClickValue(a, b));
end

function AchieverAchievementFrame_SetFilter(value)
	local func = AchieverAchievementFrameFilters[value].func;
	if ( func ~= ACHIEVEMENTUI_SELECTEDFILTER ) then
		ACHIEVEMENTUI_SELECTEDFILTER = func;
		Achiever_UIDropDownMenu_SetText(AchieverAchievementFrameFilters[value].text, AchieverAchievementFrameFilterDropDown)
		AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(0);
		AchieverAchievementFrameAchievements_ForceUpdate();
	end
end

function AchievementObjectives_DisplayCriteria (objectivesFrame, id)
	if ( not id ) then
		return;
	end

	local ACHIEVEMENTMODE_CRITERIA = 1;
	local numCriteria = Achiever_GetAchievementNumCriteria(id);
	
	if ( numCriteria == 0 ) then
		objectivesFrame.mode = ACHIEVEMENTMODE_CRITERIA;
		objectivesFrame:SetHeight(0);
		return;
	end

	-- Achievements like "Loremaster of Eastern Kingdoms" carry dozens of
	-- per-zone quest-count criteria that all sum into one overall total
	-- (ACHIEVEMENT_FLAGS_SUMM) and are each flagged ACHIEVEMENT_CRITERIA_HIDDEN
	-- -- not meant to be shown one-by-one. Real WotLK has no Lua code that
	-- renders these at all; the achievement's own ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR
	-- flag is a native-engine-only signal, same as Achiever_GetStatistic itself (see
	-- Router.lua) -- so this reimplements it the same way: one aggregate bar
	-- for the whole achievement instead of a per-criterion breakdown.
	local _, _, _, _, _, _, _, _, achievementFlags = Achiever_GetAchievementInfo(id);
	if ( achievementFlags and bit.band(achievementFlags, ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR) == ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR ) then
		-- Every contributing criterion stores the achievement's full target
		-- as its own quantity (e.g. all 63 of 1676's zone criteria carry
		-- quantity=700), so criterion 1 is as good a source as any.
		local _, _, _, _, reqQuantity = Achiever_GetAchievementCriteriaInfo(id, 1);
		local quantity = Achiever_GetStatistic(id);
		local progressBar = AchievementButton_GetProgressBar(1);
		progressBar:SetPoint("TOP", objectivesFrame, "TOP", 4, -4);
		AchievementProgressBar_HideMoneyWidgets(progressBar);
		progressBar.text:SetText(quantity .. ' / ' .. reqQuantity);
		progressBar:SetMinMaxValues(0, reqQuantity);
		progressBar:SetValue(quantity);
		progressBar:SetParent(objectivesFrame);
		progressBar:Show();

		objectivesFrame:SetHeight(ACHIEVEMENTBUTTON_CRITERIAROWHEIGHT);
		objectivesFrame.mode = ACHIEVEMENTMODE_CRITERIA;
		return;
	end

	local frameLevel = objectivesFrame:GetFrameLevel() + 1;
	
	-- Why textStrings? You try naming anything just "string" and see how happy you are.
	local textStrings, progressBars, metas = 0, 0, 0;
	
	local numRows = 0;
	local maxCriteriaWidth = 0;
	local yPos;
	for i = 1, numCriteria do	
		local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString = Achiever_GetAchievementCriteriaInfo(id, i);

		if ( bit.band(flags, ACHIEVEMENT_CRITERIA_HIDDEN) == ACHIEVEMENT_CRITERIA_HIDDEN ) then
			-- Not meant to be individually displayed (e.g. an internal
			-- per-zone counter contributing to a SUMM achievement) -- skip
			-- entirely rather than falling through to a checklist/bar branch.
		elseif ( criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID ) then
			metas = metas + 1;
			local metaCriteria = AchievementButton_GetMeta(metas);
			
			if ( metas == 1 ) then
				metaCriteria:SetPoint("TOP", objectivesFrame, "TOP", 0, -4);
				numRows = numRows + 2;
			elseif ( math.mod(metas, 2) == 0 ) then
				yPos = -((metas/2 - 1) * 28) - 8;
				metaCriteriaTable[metas-1]:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", 20, yPos);
				metaCriteria:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", 210, yPos);
			else
				metaCriteria:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", 20, -(math.ceil(metas/2 - 1) * 28) - 8);
				numRows = numRows + 2;
			end
			
			local id, achievementName, points, completed, month, day, year, description, flags, iconpath = Achiever_GetAchievementInfo(assetID);
			
			if ( month ) then
				metaCriteria.date = string.format(SHORTDATE, day, month, year);
			else
				metaCriteria.date = nil;
			end
			
			metaCriteria.id = id;
			metaCriteria.label:SetText(achievementName);
			metaCriteria.icon:SetTexture(iconpath);

			if ( objectivesFrame.completed and completed ) then
				metaCriteria.check:Show();
				metaCriteria.border:SetVertexColor(1, 1, 1, 1);
				metaCriteria.icon:SetVertexColor(1, 1, 1, 1);
				metaCriteria.label:SetShadowOffset(0, 0)
				metaCriteria.label:SetTextColor(0, 0, 0, 1);
			elseif ( completed ) then
				metaCriteria.check:Show();
				metaCriteria.border:SetVertexColor(1, 1, 1, 1);
				metaCriteria.icon:SetVertexColor(1, 1, 1, 1);
				metaCriteria.label:SetShadowOffset(1, -1)
				metaCriteria.label:SetTextColor(0, 1, 0, 1);
			else
				metaCriteria.check:Hide();
				metaCriteria.border:SetVertexColor(.75, .75, .75, 1);
				metaCriteria.icon:SetVertexColor(.55, .55, .55, 1);
				metaCriteria.label:SetShadowOffset(1, -1)
				metaCriteria.label:SetTextColor(.6, .6, .6, 1);
			end
			
			metaCriteria:SetParent(objectivesFrame);
			metaCriteria:Show();
		elseif ( bit.band(flags, ACHIEVEMENT_CRITERIA_PROGRESS_BAR) == ACHIEVEMENT_CRITERIA_PROGRESS_BAR ) then
			-- Display this criteria as a progress bar!
			progressBars = progressBars + 1;
			local progressBar = AchievementButton_GetProgressBar(progressBars);
			
			if ( progressBars == 1 ) then
				progressBar:SetPoint("TOP", objectivesFrame, "TOP", 4, -4);
			else
				progressBar:SetPoint("TOP", progressBarTable[progressBars-1], "BOTTOM", 0, 0);
			end
			
			if ( bit.band(flags, ACHIEVEMENT_CRITERIA_MONEY_COUNTER) == ACHIEVEMENT_CRITERIA_MONEY_COUNTER ) then
				AchievementProgressBar_SetMoneyText(progressBar, quantity, reqQuantity);
			else
				AchievementProgressBar_HideMoneyWidgets(progressBar);
				progressBar.text:SetText(string.format("%s", quantityString));
			end
			progressBar:SetMinMaxValues(0, reqQuantity);
			progressBar:SetValue(quantity);
			
			progressBar:SetParent(objectivesFrame);
			progressBar:Show();
			
			numRows = numRows + 1;
		else
			textStrings = textStrings + 1;
			local criteria = AchievementButton_GetCriteria(textStrings);
			criteria:ClearAllPoints();
			if ( textStrings == 1 ) then
				if ( numCriteria == 1 ) then
					criteria:SetPoint("TOP", objectivesFrame, "TOP", -14, 0);
				else
					criteria:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", 0, 0);
				end
				
			else
				criteria:SetPoint("TOPLEFT", criteriaTable[textStrings-1], "BOTTOMLEFT", 0, 0);
			end
			
			if ( objectivesFrame.completed and completed ) then
				criteria.name:SetTextColor(0, 0, 0, 1);
				criteria.name:SetShadowOffset(0, 0);
			elseif ( completed ) then
				criteria.name:SetTextColor(0, 1, 0, 1);
				criteria.name:SetShadowOffset(1, -1);
			else
				criteria.name:SetTextColor(.6, .6, .6, 1);
				criteria.name:SetShadowOffset(1, -1);
			end
			
			if ( completed ) then
				criteria.check:SetPoint("LEFT", 18, -3);
				criteria.name:SetPoint("LEFT", criteria.check, "RIGHT", 0, 2);
				criteria.check:Show();
				criteria.name:SetText(criteriaString);
			else
				criteria.check:SetPoint("LEFT", 0, -3);
				criteria.name:SetPoint("LEFT", criteria.check, "RIGHT", 5, 2);
				criteria.check:Hide();
				criteria.name:SetText("- "..criteriaString);
			end
				
			criteria:SetParent(objectivesFrame);
			criteria:Show();
			local stringWidth = criteria.name:GetStringWidth()
			criteria:SetWidth(stringWidth + criteria.check:GetWidth());
			maxCriteriaWidth = max(maxCriteriaWidth, stringWidth + criteria.check:GetWidth());

			numRows = numRows + 1;
		end
	end

	if ( textStrings > 0 and progressBars > 0 ) then
		-- If we have text criteria and progressBar criteria, display the progressBar criteria first and position the textStrings under them.
		criteriaTable[1]:ClearAllPoints();
		if ( textStrings == 1 ) then
			criteriaTable[1]:SetPoint("TOP", progressBarTable[progressBars], "BOTTOM", -14, -4);
		else
			criteriaTable[1]:SetPoint("TOP", progressBarTable[progressBars], "BOTTOM", 0, -4);
			criteriaTable[1]:SetPoint("LEFT", objectivesFrame, "LEFT", 0, 0);
		end		
	elseif ( textStrings > 1 ) then
		-- Figure out if we can make multiple columns worth of criteria instead of one long one
		local numColumns = floor(ACHIEVEMENTUI_MAXCONTENTWIDTH/maxCriteriaWidth);
		if ( numColumns > 1 ) then
			local step;
			local rows = 1;
			local position = 0;
			for i=1, table.getn(criteriaTable) do
				position = position + 1;
				if ( position > numColumns ) then
					position = position - numColumns;
					rows = rows + 1;
				end
				
				if ( rows == 1 ) then
					criteriaTable[i]:ClearAllPoints();
					criteriaTable[i]:SetPoint("TOPLEFT", objectivesFrame, "TOPLEFT", (position - 1)*(ACHIEVEMENTUI_MAXCONTENTWIDTH/numColumns), 0);
				else
					criteriaTable[i]:ClearAllPoints();
					criteriaTable[i]:SetPoint("TOPLEFT", criteriaTable[position + ((rows - 2) * numColumns)], "BOTTOMLEFT", 0, 0);
				end
			end
			numRows = ceil(numRows/numColumns);
		end
	end

	if ( metas > 0 ) then
		objectivesFrame:SetHeight(numRows * ACHIEVEMENTBUTTON_METAROWHEIGHT + 10);
	else
		objectivesFrame:SetHeight(numRows * ACHIEVEMENTBUTTON_CRITERIAROWHEIGHT);
	end
	objectivesFrame.mode = ACHIEVEMENTMODE_CRITERIA;
end

-- [[ StatsFrames ]]--

function AchieverAchievementFrameStats_OnEvent (frame, ev, ...)
	-- See AchieverAchievementFrameAchievements_OnEvent's matching comment.
	local self = frame or this;
	local event = ev or event;
	if ( event == "CRITERIA_UPDATE" and self:IsShown() ) then
		AchieverAchievementFrameStats_Update();
	end
end

function AchieverAchievementFrameStats_OnLoad (self)
	AchieverAchievementFrameStatsContainerScrollBar.ShowOriginal = AchieverAchievementFrameStatsContainerScrollBar.Show;
	AchieverAchievementFrameStatsContainerScrollBar.Show =
		function (self)
			AchieverAchievementFrameStats:SetWidth(504);
			for _, button in next, AchieverAchievementFrameStats.buttons do
				button:SetWidth(496);
			end
			self:ShowOriginal();
		end

	AchieverAchievementFrameStatsContainerScrollBar.HideOriginal = AchieverAchievementFrameStatsContainerScrollBar.Hide;
	AchieverAchievementFrameStatsContainerScrollBar.Hide =
		function (self)
			AchieverAchievementFrameStats:SetWidth(530);
			for _, button in next, AchieverAchievementFrameStats.buttons do
				button:SetWidth(522);
			end
			self:HideOriginal();
		end
		
	self:RegisterEvent("CRITERIA_UPDATE");
	AchieverAchievementFrameStatsContainerScrollBarBG:Show();
	AchieverAchievementFrameStatsContainer.update = AchieverAchievementFrameStats_Update;
	AchieverHybridScrollFrame_CreateButtons(AchieverAchievementFrameStatsContainer, "StatTemplate");
	-- See AchieverAchievementFrameAchievements_OnLoad's matching comment.
	self:SetScript("OnEvent", AchieverAchievementFrameStats_OnEvent);
end

local displayStatCategories = {};

function AchieverAchievementFrameStats_Update ()
	local category = achievementFunctions.selectedCategory;
	local scrollFrame = AchieverAchievementFrameStatsContainer;
	local offset = AchieverHybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = table.getn(buttons);
	local statHeight = 24;
	
	local numStats, numCompleted = Achiever_GetCategoryNumAchievements(category);
	
	local categories = ACHIEVEMENTUI_CATEGORIES;
	-- clear out table
	if ( achievementFunctions.lastCategory ~= category ) then
		local statCat;
		while ( table.getn(displayStatCategories) > 0 ) do
			table.remove(displayStatCategories);
		end
		-- build a list of shown category and stat id's

		tinsert(displayStatCategories, {id = category, header = true});
		for i=1, numStats do
			tinsert(displayStatCategories, {id = Achiever_GetAchievementInfo(category, i)});
		end
		-- add all the subcategories and their stat id's
		for i, cat in next, categories do
			if ( cat.parent == category ) then
				tinsert(displayStatCategories, {id = cat.id, header = true});
				numStats = Achiever_GetCategoryNumAchievements(cat.id);
				for k=1, numStats do
					tinsert(displayStatCategories, {id = Achiever_GetAchievementInfo(cat.id, k)});
				end
			end
		end
		achievementFunctions.lastCategory = category;
	end

	-- iterate through the displayStatCategories and display them
	local selection = AchieverAchievementFrameStats.selection;
	local statCount = table.getn(displayStatCategories);
	local statIndex, id, button;
	local stat;
	
	local totalHeight = statCount * statHeight;
	local displayedHeight = numButtons * statHeight;
	for i = 1, numButtons do
		button = buttons[i];
		statIndex = offset + i;
		if ( statIndex <= statCount ) then
			stat = displayStatCategories[statIndex];
			if ( stat.header ) then
				AchieverAchievementFrameStats_SetHeader(button, stat.id);
			else
				AchieverAchievementFrameStats_SetStat(button, stat.id, nil, statIndex);
			end
			button:Show();
		else
			button:Hide();
		end
	end
	AchieverHybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

function AchieverAchievementFrameStats_SetStat(button, category, index, colorIndex, isSummary)
	-- Explicit fallback for AchievementStatButton_OnLoad -- see
	-- AchievementButton_DisplayAchievement's matching comment. Gated on
	-- `not button.background` so this is a no-op, not a double-run
	-- (AchievementStatButton_OnLoad's own tinsert into parentFrame.buttons
	-- isn't safe to run twice), on a row whose own OnLoad already worked.
	if ( not button.background ) then
		AchievementStatButton_OnLoad(button, isSummary and AchieverAchievementFrameSummaryStats or AchieverAchievementFrameStats);
	end

	--Remove these variables when we know for sure we don't need them
	local id, name, points, completed, month, day, year, description, flags, icon;
	if ( not isSummary ) then
		if ( not index ) then
			id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(category);
		else
			id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(category, index);
		end
		
	else
		-- This is on the summary page
		id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfoFromCriteria(category);
	end

	button.id = id;

	if ( not colorIndex ) then
		if ( not index ) then
			message("Error, need a color index or index");
		end
		colorIndex = index;
	end
	if ( AchieverDB and AchieverDB.debugMode and AchieverDB.showPatchOnAchievements ) then
		name = name .. " |cff3399ff(" .. (Achiever_GetAchievementPatch(id) or "?") .. ")|r";
	end
	button:SetText(name);
	button.background:Show();
	-- Color every other line yellow
	if ( mod(colorIndex, 2) == 1 ) then
		button.background:SetTexCoord(0, 1, 0.1875, 0.3671875);
		button.background:SetBlendMode("BLEND");
		button.background:SetAlpha(1.0);
		button:SetHeight(24);
	else
		button.background:SetTexCoord(0, 1, 0.375, 0.5390625);
		button.background:SetBlendMode("ADD");
		button.background:SetAlpha(0.5);
		button:SetHeight(24);
	end
	
	-- Figure out the criteria
	local numCriteria = Achiever_GetAchievementNumCriteria(id);
	if ( numCriteria == 0 ) then
		-- This is no good!
	end
	-- Just show the first criteria for now
	local criteriaString, criteriaType, completed, quantityNumber, reqQuantity, charName, flags, assetID, quantity;
	local isMoneyStat = false;
	if ( not isSummary ) then
		quantity = Achiever_GetStatistic(id);
		isMoneyStat = Achiever_IsMoneyStatistic(id);
	else
		criteriaString, criteriaType, completed, quantityNumber, reqQuantity, charName, flags, assetID, quantity = Achiever_GetAchievementCriteriaInfo(category);
	end
	-- A stat that's never been progressed shows as "--", matching WotLK's real
	-- Achiever_GetStatistic (a native call that returns nil/empty for an untouched
	-- stat rather than a literal "0") -- our mock returns a plain 0 counter
	-- instead, so that has to be special-cased here rather than relying on
	-- the "not quantity" nil-check alone catching it.
	if ( not quantity or quantity == 0 ) then
		quantity = "--";
		isMoneyStat = false;
	end

	if ( isMoneyStat ) then
		button.value:Hide();
		local gold, silver, copper = Achiever_SplitMoney(quantity);
		if ( gold > 0 ) then
			button.goldIcon:Show();
			button.goldText:Show();
			button.goldText:SetText(gold);
		else
			button.goldIcon:Hide();
			button.goldText:Hide();
		end
		if ( gold > 0 or silver > 0 ) then
			button.silverIcon:Show();
			button.silverText:Show();
			button.silverText:SetText(silver);
		else
			button.silverIcon:Hide();
			button.silverText:Hide();
		end
		button.copperIcon:Show();
		button.copperText:Show();
		button.copperText:SetText(copper);
	else
		button.value:Show();
		button.value:SetText(quantity);
		AchievementStatButton_HideMoney(button);
	end

	-- Hide the header images
	button.title:Hide();
	button.left:Hide();
	button.middle:Hide();
	button.right:Hide();
	button.isHeader = false;
	-- Counter rows stay clickable/highlightable (buttons get recycled
	-- between header and stat roles as the list scrolls, so a button
	-- previously shown as a non-interactive header needs this restored).
	button:EnableMouse(true);
end

function AchieverAchievementFrameStats_SetHeader(button, id)
	-- show header
	button.left:Show();
	button.middle:Show();
	button.right:Show();
	local text;
	if ( id == ACHIEVEMENT_COMPARISON_STATS_SUMMARY_ID ) then
		text = ACHIEVEMENT_SUMMARY_CATEGORY;
	else
		text = Achiever_GetCategoryInfo(id);
	end
	button.title:SetText(text);
	button.title:Show();
	button.value:SetText("");
	button.value:Show();
	AchievementStatButton_HideMoney(button);
	button:SetText("");
	button:SetHeight(24);
	button.background:Hide();
	button.isHeader = true;
	button.id = id;
	-- Sub-category header rows are not selectable/clickable here -- disabling
	-- mouse also blocks OnEnter/OnLeave, so headers never get the counter
	-- rows' hover-brightening either.
	button:EnableMouse(false);
end

function AchievementStatButton_OnLoad(self, parentFrame)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.background = _G[name.."BG"];
	self.left = _G[name.."HeaderLeft"];
	self.middle = _G[name.."HeaderMiddle"];
	self.right = _G[name.."HeaderRight"];
	self.text = _G[name.."Text"];
	-- StatTemplate's own <ButtonText> (AchievementUI.xml) has no explicit
	-- name attribute, so _G[name.."Text"] above (pre-existing, unrelated to
	-- this fix) doesn't resolve to it -- confirmed live that self.text is
	-- genuinely nil for this template, unlike the achievement/category
	-- buttons' own separately-named "$parentText" FontStrings. It relies on
	-- its sibling <NormalFont inherits="GameFontHighlightLeft"/> being
	-- applied automatically by the engine instead, exactly the same
	-- structure as the tab buttons' template -- and confirmed via live
	-- 1.14.2 testing to have the identical failure: AchieverAchievementFrameStats_SetStat's
	-- button:SetText(name) call sets real text content that never actually
	-- renders, because that automatic ButtonText-to-NormalFont linkage
	-- doesn't reliably happen on this client (see the tab buttons' own fix
	-- for the full explanation and live diagnostic evidence). SetNormalFontObject
	-- (tried first) doesn't exist as a Button method on 1.12.1 at all
	-- ("attempt to call method 'SetNormalFontObject' (a nil value)",
	-- confirmed live) -- GetFontString() is a much more basic, long-standing
	-- Button method that returns the linked ButtonText FontString directly,
	-- regardless of whether it has an accessible global name, so
	-- :SetFontObject() (a plain FontString method) can be called on it
	-- safely on both clients.
	local buttonText = self:GetFontString();
	if (buttonText) then
		buttonText:SetFontObject(GameFontHighlightLeft);
	end
	self.title = _G[name.."Title"];
	self.value = _G[name.."Value"];
	self.value:SetVertexColor(1, 0.97, 0.6);
	self:GetHighlightTexture():SetAlpha(0.15);

	-- Money-valued stats (ACHIEVEMENT_CRITERIA_MONEY_COUNTER-flagged, e.g.
	-- "Total gold looted") render as split gold/silver/copper icon+number
	-- pairs instead of $parentValue's plain text, mirroring FuBar_MoneyFu's
	-- MoneyFuFrameGoldIcon/...Text row (same client, confirmed working
	-- pattern) -- built once here and just shown/hidden/repositioned per
	-- row in AchieverAchievementFrameStats_SetStat, same as MoneyFu's own textures
	-- are created once in OnInitialize and toggled in UpdateText.
	self.copperIcon = self:CreateTexture(nil, "OVERLAY");
	self.copperIcon:SetWidth(14);
	self.copperIcon:SetHeight(14);
	self.copperIcon:SetTexture([[Interface\MoneyFrame\UI-MoneyIcons]]);
	self.copperIcon:SetTexCoord(0.5, 0.75, 0, 1);
	self.copperIcon:SetPoint("RIGHT", self.value, "RIGHT");

	self.copperText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightRight");
	self.copperText:SetPoint("RIGHT", self.copperIcon, "LEFT");
	self.copperText:SetVertexColor(1, 0.97, 0.6);

	self.silverIcon = self:CreateTexture(nil, "OVERLAY");
	self.silverIcon:SetWidth(14);
	self.silverIcon:SetHeight(14);
	self.silverIcon:SetTexture([[Interface\MoneyFrame\UI-MoneyIcons]]);
	self.silverIcon:SetTexCoord(0.25, 0.5, 0, 1);
	self.silverIcon:SetPoint("RIGHT", self.copperText, "LEFT");

	self.silverText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightRight");
	self.silverText:SetPoint("RIGHT", self.silverIcon, "LEFT");
	self.silverText:SetVertexColor(1, 0.97, 0.6);

	self.goldIcon = self:CreateTexture(nil, "OVERLAY");
	self.goldIcon:SetWidth(14);
	self.goldIcon:SetHeight(14);
	self.goldIcon:SetTexture([[Interface\MoneyFrame\UI-MoneyIcons]]);
	self.goldIcon:SetTexCoord(0, 0.25, 0, 1);
	self.goldIcon:SetPoint("RIGHT", self.silverText, "LEFT");

	self.goldText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightRight");
	self.goldText:SetPoint("RIGHT", self.goldIcon, "LEFT");
	self.goldText:SetVertexColor(1, 0.97, 0.6);

	self.copperIcon:Hide();
	self.copperText:Hide();
	self.silverIcon:Hide();
	self.silverText:Hide();
	self.goldIcon:Hide();
	self.goldText:Hide();

	parentFrame.buttons = parentFrame.buttons or {};
	tinsert(parentFrame.buttons, self);
end

function AchievementStatButton_HideMoney(button)
	button.goldIcon:Hide();
	button.goldText:Hide();
	button.silverIcon:Hide();
	button.silverText:Hide();
	button.copperIcon:Hide();
	button.copperText:Hide();
end

function AchievementStatButton_OnClick(self)
	if ( self.isHeader ) then
		achievementFunctions.selectedCategory = self.id;
		AchieverAchievementFrameCategories_Update();
		AchieverAchievementFrameStats_Update();
	elseif ( self.summary ) then
		AchieverAchievementFrame_SelectSummaryStatistic(self.id);
	end
end

-- [[ Summary Frame ]] --
function AchieverAchievementFrameSummary_OnShow()
	if ( achievementFunctions ~= COMPARISON_ACHIEVEMENT_FUNCTIONS and achievementFunctions ~= COMPARISON_STAT_FUNCTIONS ) then
		AchieverAchievementFrameSummary:SetWidth(530);
		AchieverAchievementFrameSummary_Update();
	else
		AchieverAchievementFrameComparisonDark:Hide();
		AchieverAchievementFrameComparisonWatermark:Hide();
		AchieverAchievementFrameComparison:SetWidth(650);
		AchieverAchievementFrameSummary:SetWidth(650);
		AchieverAchievementFrameSummary_Update(true);
	end
end

function AchieverAchievementFrameSummary_Update(isCompare)
	AchieverAchievementFrameSummaryCategoriesStatusBar_Update();
	AchieverAchievementFrameSummary_UpdateAchievements({ Achiever_GetLatestCompletedAchievements() });

	-- Explicit refresh of the 8 fixed category dashboard bars (same
	-- AchieverAchievementFrameSummaryCategoriesCategory1..8 naming
	-- Achiever_ReapplyLocaleChrome's label pass above uses), rather than
	-- relying solely on each bar's own <OnShow> -- confirmed via live
	-- 1.12.1 testing that self/this comes back nil there when the Summary
	-- tab's initial Show() is cascaded from a Lua call (ShowUIPanel/tab
	-- switching) rather than a raw top-level XML-engine event, leaving the
	-- bars blank until whatever later triggers a working OnShow.
	-- AchieverAchievementFrameSummaryCategory_OnShow itself is pure
	-- recompute-and-redisplay (no non-idempotent side effects like list
	-- insertion), so calling it again here unconditionally is safe even on
	-- a client/session where the bar's own OnShow already ran fine.
	for i = 1, 8 do
		local bar = _G["AchieverAchievementFrameSummaryCategoriesCategory" .. i];
		if (bar) then
			-- AchieverAchievementFrameSummaryCategory_OnShow reads bar.text
			-- (set by AchieverAchievementFrameSummaryCategory_OnLoad), so make
			-- sure that ran first -- same nil/wrong-self risk as OnShow
			-- itself, and this bar's own <OnLoad> is just as capable of
			-- getting a bad self/this. Gated on `not bar.text` so this is a
			-- no-op, not a re-run, when the bar's own OnLoad already worked.
			if (not bar.text) then
				AchieverAchievementFrameSummaryCategory_OnLoad(bar);
			end
			AchieverAchievementFrameSummaryCategory_OnShow(bar);
		end
	end
end

-- Takes a plain table (not `...`) -- see updateTrackedAchievements's
-- comment (top of file) for the full reason. Same pattern: a real,
-- dynamically-sized achievement-id list, built by the caller via
-- `{ Achiever_GetLatestCompletedAchievements() }`.
function AchieverAchievementFrameSummary_UpdateAchievements(achievements)
	local numAchievements = table.getn(achievements);
	local id, name, points, completed, month, day, year, description, flags, icon;
	local buttons = AchieverAchievementFrameSummaryAchievements.buttons;
	local button, anchorTo, achievementID;
	local defaultAchievementCount = 1;

	for i=1, ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS do
		-- `button = buttons and buttons[i]` (not `if buttons then button =
		-- buttons[i] end`) -- the latter never resets `button` to nil when
		-- `buttons` itself is nil (true on the very first-ever call, before
		-- anything has been tinsert'ed into
		-- AchieverAchievementFrameSummaryAchievements.buttons yet), so
		-- `button` silently kept whatever frame the PREVIOUS iteration left
		-- it holding instead of being freshly looked up each time -- meaning
		-- only slot 1 ever actually got CreateFrame'd on that first call,
		-- and slots 2-4 wrongly reused slot 1's frame object instead of
		-- getting their own.
		button = buttons and buttons[i];
		if ( not button ) then
			button = CreateFrame("Button", "AchieverAchievementFrameSummaryAchievement"..i, AchieverAchievementFrameSummaryAchievements, "SummaryAchievementTemplate");

			-- Explicit fallback for AchieverAchievementFrameSummaryAchievement_OnLoad
			-- (SummaryAchievementTemplate's own <OnLoad>, which itself calls
			-- AchievementComparisonPlayerButton_OnLoad(self) first) and the
			-- nested Icon/Shield sub-frames' own <OnLoad> scripts -- confirmed
			-- via live 1.12.1 testing that this whole template chain's inline
			-- <OnLoad> scripts get a non-Frame self/this specifically when
			-- instantiated via a dynamic Lua-side CreateFrame() call like this
			-- one, unlike the addon's static top-level XML tree (whose OnLoad
			-- scripts bind correctly).
			--
			-- Icon/Shield MUST be initialized first, before the outer button --
			-- AchievementComparisonPlayerButton_OnLoad's own last line calls
			-- self:Desaturate(), which immediately calls self.icon:Desaturate(),
			-- so button.icon.Desaturate has to already exist by then (matching
			-- WoW's own normal children-before-parent OnLoad construction
			-- order, which is what this whole fallback is standing in for).
			-- The icon/shield child frames' global names are already valid
			-- immediately after CreateFrame returns -- frame naming happens
			-- structurally, independent of whether any OnLoad script ran --
			-- so they can be looked up directly here without needing
			-- button.icon/button.shield (only set by AchievementComparisonPlayerButton_OnLoad
			-- itself) yet.
			--
			-- Every branch is gated on a field it's specifically responsible
			-- for setting, so this whole block is a pure no-op, not a
			-- double-run, on a client/session where the implicit binding IS
			-- fine -- important since AchieverAchievementFrameSummaryAchievement_OnLoad's
			-- own tinsert into AchieverAchievementFrameSummaryAchievements.buttons
			-- is NOT safe to run twice for the same button.
			local iconFrame = _G["AchieverAchievementFrameSummaryAchievement" .. i .. "Icon"];
			local shieldFrame = _G["AchieverAchievementFrameSummaryAchievement" .. i .. "Shield"];
			if ( iconFrame and not iconFrame.texture ) then
				AchievementIcon_OnLoad(iconFrame);
			end
			if ( shieldFrame and not shieldFrame.icon ) then
				AchieverAchievementShield_OnLoad(shieldFrame);
			end
			if ( not button.label ) then
				AchieverAchievementFrameSummaryAchievement_OnLoad(button);
			end

			if ( i == 1 ) then
				button:SetPoint("TOPLEFT",AchieverAchievementFrameSummaryAchievementsHeader, "BOTTOMLEFT", 18, 2 );
				button:SetPoint("TOPRIGHT",AchieverAchievementFrameSummaryAchievementsHeader, "BOTTOMRIGHT", -18, 2 );
			else
				anchorTo = _G["AchieverAchievementFrameSummaryAchievement"..i-1];
				button:SetPoint("TOPLEFT",anchorTo, "BOTTOMLEFT", 0, 3 );
				button:SetPoint("TOPRIGHT",anchorTo, "BOTTOMRIGHT", 0, 3 );
			end
			
			if ( not buttons ) then
				buttons = AchieverAchievementFrameSummaryAchievements.buttons;
			end
			AchieverAchievementFrameSummary_LocalizeButton(button);
		end;
		
		if ( i <= numAchievements ) then
			achievementID = achievements[i];
			id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(achievementID);
			button.label:SetText(name);
			button.description:SetText(description);
			AchieverAchievementShield_SetPoints(points, button.shield.points, GameFontNormal, GameFontNormalSmall);
			if ( points > 0 ) then
				button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
			else
				button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
			end
			button.icon.texture:SetTexture(icon);
			button.id = id;

			if ( completed ) then
				button.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
			else
				button.dateCompleted:SetText("");
			end
			
			button:Saturate();
			button.tooltipTitle = nil;
			button:Show();
		else
			for i=defaultAchievementCount, ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS do
				achievementID = ACHIEVEMENTUI_DEFAULTSUMMARYACHIEVEMENTS[defaultAchievementCount];
				if ( not achievementID ) then
					break;
				end
				id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(achievementID);
				if ( completed ) then
					defaultAchievementCount = defaultAchievementCount+1;
				else
					id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(achievementID);
					button.label:SetText(name);
					button.description:SetText(description);
					AchieverAchievementShield_SetPoints(points, button.shield.points, GameFontNormal, GameFontNormalSmall);
					if ( points > 0 ) then
						button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
					else
						button.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
					end
					button.icon.texture:SetTexture(icon);
					button.id = id;
					if ( month ) then
						button.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
					else
						button.dateCompleted:SetText("");
					end
					button:Show();
					defaultAchievementCount = defaultAchievementCount+1;
					button:Desaturate();
					button.tooltipTitle = SUMMARY_ACHIEVEMENT_INCOMPLETE;
					button.tooltip = SUMMARY_ACHIEVEMENT_INCOMPLETE_TEXT;
					break;
				end
			end
		end
	end
	if ( numAchievements == 0 ) then
		AchieverAchievementFrameSummaryAchievementsEmptyText:Show();
	else
		AchieverAchievementFrameSummaryAchievementsEmptyText:Hide();
	end
end

function AchieverAchievementFrameSummaryCategoriesStatusBar_Update()
	local total, completed = Achiever_GetNumCompletedAchievements();
	AchieverAchievementFrameSummaryCategoriesStatusBar:SetMinMaxValues(0, total);
	AchieverAchievementFrameSummaryCategoriesStatusBar:SetValue(completed);
	AchieverAchievementFrameSummaryCategoriesStatusBarText:SetText(completed.."/"..total);
end

function AchieverAchievementFrameSummaryAchievement_OnLoad(self)
	-- See AchievementIcon_OnLoad's matching guard comment (AchievementUI.lua,
	-- top of file). AchieverAchievementFrameSummary_UpdateAchievements' own
	-- explicit fallback (passing the real button directly) is the reliable
	-- path for this template.
	if (type(self) ~= "table" or not self.GetName) then return; end

	AchievementComparisonPlayerButton_OnLoad(self);
	self.highlight = _G[self:GetName().."Highlight"];
	AchieverAchievementFrameSummaryAchievements.buttons = AchieverAchievementFrameSummaryAchievements.buttons or {};
	tinsert(AchieverAchievementFrameSummaryAchievements.buttons, self);
	self:Saturate();
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, 0.5);
	self.titleBar:SetVertexColor(1,1,1,0.5);
	self.dateCompleted:Show();
end

function AchieverAchievementFrameSummaryAchievement_OnClick(self)
	local id = self.id
	local nextID, completed = Achiever_GetNextAchievement(id);
	if ( nextID and completed ) then
		local newID;
		while ( nextID and completed ) do
			newID, completed = Achiever_GetNextAchievement(nextID);
			if ( completed ) then
				nextID = newID;
			end
		end
		id = nextID;
	end
	
	AchieverAchievementFrame_SelectAchievement(id);
end

function AchieverAchievementFrameSummaryAchievement_OnEnter(self)
	if (type(self) ~= "table" or not self.highlight) then return; end

	self.highlight:Show();
	if ( self.tooltipTitle ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(self.tooltipTitle,1,1,1);
		GameTooltip:AddLine(self.tooltip, nil, nil, nil, 1);
		GameTooltip:Show();
	end
end

function AchieverAchievementFrameSummaryCategoryButton_OnClick (self)
	if (type(self) ~= "table" or not self.GetParent) then return; end

	local id = self:GetParent():GetID();
	for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
		if ( button.categoryID == id ) then
			button:Click();
			return;
		end
	end
end

-- Fixed dashboard labels for the Summary tab's 8 hardcoded root-category
-- bars (AchievementUI.xml $parentCategory1..8, ids match Data/Categories.lua's
-- current root-category ids) -- Strings.lua text instead of Achiever_GetCategoryInfo's
-- live DB name, so these translate through the same Achiever-<locale>
-- mechanism as the rest of this tab's chrome, rather than depending on this
-- server's DB still containing those exact WotLK category ids/names.
local ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS = {
	[92] = ACHIEVER_SUMMARY_CATEGORY_GENERAL,
	[96] = ACHIEVER_SUMMARY_CATEGORY_QUESTS,
	[97] = ACHIEVER_SUMMARY_CATEGORY_EXPLORATION,
	[95] = ACHIEVER_SUMMARY_CATEGORY_PVP,
	[168] = ACHIEVER_SUMMARY_CATEGORY_DUNGEONS_AND_RAIDS,
	[169] = ACHIEVER_SUMMARY_CATEGORY_PROFESSIONS,
	[201] = ACHIEVER_SUMMARY_CATEGORY_REPUTATION,
	[155] = ACHIEVER_SUMMARY_CATEGORY_WORLD_EVENTS,
};

-- Re-stamps every widget/table above that got its text frozen from a
-- Strings.lua chrome global at file-parse/frame-creation time -- i.e.
-- everything that ISN'T re-read fresh from the global on every render (like
-- the Summary category label, AchieverAchievementFrameCategories_DisplayButton) and
-- ISN'T a virtual template lazily cloned by Lua after this point (row
-- buttons, achievement-earned toast popups -- those already see whatever the
-- global holds at their own creation time, no reapply needed). Defined here
-- (rather than up near AchieverAchievementFrameFilters, where it originally lived)
-- specifically so it can close over ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS
-- above as an upvalue and refresh it in place -- a Lua local is only visible
-- to code that comes after its declaration in the same file, so a function
-- defined earlier could never have referenced it at all.
--
-- Called from Achiever.lua's ADDON_LOADED handler, right after
-- Achiever_ForceLocale is resolved and any Achiever-<locale> addon's
-- _G[name]=value overwrite has had a chance to run -- LocaleBootstrap.lua's
-- earlier GetLocale()-driven load happens too early for AchieverDB to be
-- readable (see that file's own comment), so on a client where the only real
-- locale signal is the Options-panel dropdown (like this one), everything
-- below is still showing Strings.lua's English defaults until this runs.
-- Idempotent/harmless to call even when nothing needed retranslating.
function Achiever_ReapplyLocaleChrome()
	AchieverAchievementFrameFilters[1].text = ACHIEVEMENTFRAME_FILTER_ALL;
	AchieverAchievementFrameFilters[2].text = ACHIEVEMENTFRAME_FILTER_COMPLETED;
	AchieverAchievementFrameFilters[3].text = ACHIEVEMENTFRAME_FILTER_INCOMPLETE;

	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[92] = ACHIEVER_SUMMARY_CATEGORY_GENERAL;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[96] = ACHIEVER_SUMMARY_CATEGORY_QUESTS;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[97] = ACHIEVER_SUMMARY_CATEGORY_EXPLORATION;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[95] = ACHIEVER_SUMMARY_CATEGORY_PVP;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[168] = ACHIEVER_SUMMARY_CATEGORY_DUNGEONS_AND_RAIDS;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[169] = ACHIEVER_SUMMARY_CATEGORY_PROFESSIONS;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[201] = ACHIEVER_SUMMARY_CATEGORY_REPUTATION;
	ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[155] = ACHIEVER_SUMMARY_CATEGORY_WORLD_EVENTS;
	-- Same lookup AchieverAchievementFrameSummaryCategory_OnLoad itself uses (below),
	-- just re-run now that the table above holds fresh values -- one of the
	-- 8 fixed dashboard bars per Router.lua's own "AchieverAchievementFrameSummaryCategoriesCategory1..8"
	-- naming convention (see Achiever_EmitAchievementEarned).
	for i = 1, 8 do
		local bar = _G["AchieverAchievementFrameSummaryCategoriesCategory" .. i];
		if (bar) then
			local label = _G[bar:GetName() .. "Label"];
			if (label) then
				label:SetText(ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[bar:GetID()] or Achiever_GetCategoryInfo(bar:GetID()));
			end
		end
	end

	if (AchieverAchievementFrameTab1) then AchieverAchievementFrameTab1:SetText(ACHIEVEMENTS); end
	if (AchieverAchievementFrameTab2) then AchieverAchievementFrameTab2:SetText(STATISTICS); end
	if (AchieverAchievementFrameTab3) then AchieverAchievementFrameTab3:SetText(ACHIEVER_OPTIONS_TAB_LABEL); end

	if (AchieverAchievementFrameOptionsDebugModeCheckboxLabel) then
		AchieverAchievementFrameOptionsDebugModeCheckboxLabel:SetText(ACHIEVER_DEBUG_MODE_LABEL);
	end
	if (AchieverAchievementFrameOptionsShowPatchCheckboxLabel) then
		AchieverAchievementFrameOptionsShowPatchCheckboxLabel:SetText(ACHIEVER_SHOW_PATCH_LABEL);
	end
	if (AchieverAchievementFrameOptionsForcePatchDropDownLabel) then
		AchieverAchievementFrameOptionsForcePatchDropDownLabel:SetText(ACHIEVER_FORCE_PATCH_LABEL);
	end
	if (AchieverAchievementFrameOptionsLanguageDropDownLabel) then
		AchieverAchievementFrameOptionsLanguageDropDownLabel:SetText(ACHIEVER_LANGUAGE_LABEL);
	end

	-- $parentTitle here is a SIBLING of $parentPointBorder within the same
	-- <Layer>, both scoped to the enclosing <Frame name="$parentHeader">
	-- (AchieverAchievementFrameHeader) -- not nested inside $parentPointBorder, even
	-- though it visually sits on top of it. Real name confirmed by tracing
	-- AchievementUI.xml's actual element nesting, not by proximity/anchor
	-- references.
	if (AchieverAchievementFrameHeaderTitle) then
		AchieverAchievementFrameHeaderTitle:SetText(ACHIEVEMENT_TITLE);
	end
	if (AchieverAchievementFrameAchievementsFeatOfStrengthText) then
		AchieverAchievementFrameAchievementsFeatOfStrengthText:SetText(FEAT_OF_STRENGTH_DESCRIPTION);
	end
	if (AchieverAchievementFrameSummaryAchievementsEmptyText) then
		AchieverAchievementFrameSummaryAchievementsEmptyText:SetText(NO_COMPLETED_ACHIEVEMENTS);
	end
	if (AchieverAchievementFrameSummaryAchievementsHeaderTitle) then
		AchieverAchievementFrameSummaryAchievementsHeaderTitle:SetText(LATEST_UNLOCKED_ACHIEVEMENTS);
	end
	if (AchieverAchievementFrameSummaryCategoriesHeaderTitle) then
		AchieverAchievementFrameSummaryCategoriesHeaderTitle:SetText(ACHIEVEMENT_CATEGORY_PROGRESS);
	end
	if (AchieverAchievementFrameSummaryCategoriesStatusBarTitle) then
		AchieverAchievementFrameSummaryCategoriesStatusBarTitle:SetText(ACHIEVEMENTS_COMPLETED);
	end

	-- Not covered above -- resolved widget names not confirmed against a
	-- live client, or belonging to the Comparison (inspect-another-player)
	-- tab, which is already inert/no-data (see Router.lua's
	-- Achiever_SetAchievementComparisonUnit and friends) so translating its chrome is
	-- low priority. Verify in-game and extend this function if any of these
	-- turn out to still be visibly English: the two AchievementHeaderStatusBarTemplate
	-- instances under the Comparison tab's Player/Friend boxes
	-- ($parentPlayerStatusBarTitle / $parentFriendStatusBarTitle, the latter
	-- already hidden via this.statusBar.title:Hide() in AchievementUI.xml
	-- regardless).
end

function AchieverAchievementFrameSummaryCategory_OnLoad (self)
	-- See AchievementIcon_OnLoad's matching guard comment (AchievementUI.lua,
	-- top of file).
	if (type(self) ~= "table" or not self.GetName) then return; end

	self:SetMinMaxValues(0, 100);
	self:SetValue(0);
	local name = self:GetName();
	self.text = _G[name .. "Text"];

	local id = self:GetID();
	_G[name .. "Label"]:SetText(ACHIEVEMENTUI_SUMMARY_CATEGORY_LABELS[id] or Achiever_GetCategoryInfo(id));
end

function AchieverAchievementFrame_GetCategoryTotalNumAchievements (id, showAll)
	-- Not recursive because we only have one deep and this saves time.
	local totalAchievements, totalCompleted = 0, 0;
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(id, showAll);
	totalAchievements = totalAchievements + numAchievements;
	totalCompleted = totalCompleted + numCompleted;
	
	for _, category in next, ACHIEVEMENTUI_CATEGORIES do
		if ( category.parent == id ) then
			numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(category.id, showAll);
			totalAchievements = totalAchievements + numAchievements;
			totalCompleted = totalCompleted + numCompleted;
		end
	end
	
	return totalAchievements, totalCompleted;
end

function AchieverAchievementFrameSummaryCategory_OnEvent (self, event, ...)
	AchieverAchievementFrameSummaryCategory_OnShow(self);
end

function AchieverAchievementFrameSummaryCategory_OnShow (self)
	-- Guard against a non-Frame self -- confirmed via live 1.12.1 testing
	-- that the error is "attempt to call method 'GetID' (a nil value)", NOT
	-- "attempt to index a nil value" -- meaning self here is NOT nil, just
	-- some other truthy value lacking Frame methods (a plain `if not self`
	-- guard never actually triggers). This happens in the XML-triggered
	-- <OnShow> this is normally called from (self or this) when cascaded
	-- from a Lua-side Show() call. AchieverAchievementFrameSummary_Update's
	-- own explicit per-bar refresh loop (passing the real bar reference
	-- directly) is the reliable path; this guard just keeps the original,
	-- less-reliable XML trigger from erroring instead of silently no-oping.
	-- type(self) == "table" alone isn't enough -- confirmed via live testing
	-- that the wrong value here is ITSELF a plain table (just not a Frame),
	-- not nil and not some other primitive type.
	if (type(self) ~= "table" or not self.GetID) then return; end

	local totalAchievements, totalCompleted = AchieverAchievementFrame_GetCategoryTotalNumAchievements(self:GetID(), true);

	self.text:SetText(string.format("%d/%d", totalCompleted, totalAchievements));
	self:SetMinMaxValues(0, totalAchievements);
	self:SetValue(totalCompleted);
	self:RegisterEvent("ACHIEVEMENT_EARNED");
end

function AchieverAchievementFrameSummaryCategory_OnHide (self)
	-- See AchieverAchievementFrameSummaryCategory_OnShow's matching guard
	-- comment above.
	if (type(self) ~= "table" or not self.UnregisterEvent) then return; end

	self:UnregisterEvent("ACHIEVEMENT_EARNED");
end

function AchieverAchievementFrame_SelectAchievement(id, forceSelect)
	if ( not AchieverAchievementFrame:IsShown() and not forceSelect ) then
		return;
	end
	
	local _, _, _, achCompleted = Achiever_GetAchievementInfo(id);
	if ( achCompleted and (ACHIEVEMENTUI_SELECTEDFILTER == AchieverAchievementFrameFilters[ACHIEVEMENT_FILTER_INCOMPLETE].func) ) then
		AchieverAchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	elseif ( (not achCompleted) and (ACHIEVEMENTUI_SELECTEDFILTER == AchieverAchievementFrameFilters[ACHIEVEMENT_FILTER_COMPLETE].func) ) then
		AchieverAchievementFrame_SetFilter(ACHIEVEMENT_FILTER_ALL);
	end
	
	AchieverAchievementFrameTab_OnClick = AchieverAchievementFrameBaseTab_OnClick;
	AchieverAchievementFrameTab_OnClick(1);
	AchieverAchievementFrameSummary:Hide();
	AchieverAchievementFrameAchievements:Show();

	-- Figure out if this is part of a progressive achievement; if it is and it's incomplete, make sure the previous level was completed. If not, find the first incomplete achievement in the chain and display that instead.
	local _, _, _, completed = Achiever_GetAchievementInfo(id);
	if ( not completed and Achiever_GetPreviousAchievement(id) ) then
		local prevID = Achiever_GetPreviousAchievement(id);
		_, _, _, completed = Achiever_GetAchievementInfo(prevID);
		while ( prevID and not completed ) do
			id = prevID;
			prevID = Achiever_GetPreviousAchievement(id);
			if ( prevID ) then
				_, _, _, completed = Achiever_GetAchievementInfo(prevID);
			end
		end
	elseif ( completed ) then 
		local nextID, completed = Achiever_GetNextAchievement(id);
		if ( nextID and completed ) then
			local newID
			while ( nextID and completed ) do
				newID, completed = Achiever_GetNextAchievement(nextID);
				if ( completed ) then
					nextID = newID;
				end
			end
			id = nextID;
		end
	end
	
	AchieverAchievementFrameCategories_ClearSelection();
	local category = Achiever_GetAchievementCategory(id);
	
	local categoryIndex, parent, hidden = 0;
	for i, entry in next, ACHIEVEMENTUI_CATEGORIES do
		if ( entry.id == category ) then
			parent = entry.parent;
		end
	end
	
	for i, entry in next, ACHIEVEMENTUI_CATEGORIES do
		if ( entry.id == parent ) then
			entry.collapsed = false;
		elseif ( entry.parent == parent ) then
			entry.hidden = false;
		elseif ( entry.parent == true ) then
			entry.collapsed = true;
		elseif ( entry.parent ) then
			entry.hidden = true;
		end
	end
		
	achievementFunctions.selectedCategory = category;
	AchieverAchievementFrameCategoriesContainerScrollBar:SetValue(0);
	AchieverAchievementFrameCategories_Update();
	
	local shown, i = false, 1;
	while ( not shown ) do
		for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
			if ( button.categoryID == category and math.ceil(button:GetBottom()) >= math.ceil(AchieverAchievementFrameAchievementsContainer:GetBottom())) then
				shown = true;
			end
		end
		
		if ( not shown ) then
			local _, maxVal = AchieverAchievementFrameCategoriesContainerScrollBar:GetMinMaxValues();
			if ( AchieverAchievementFrameCategoriesContainerScrollBar:GetValue() == maxVal ) then
				--assert(false)
				return;
			else
				AchieverHybridScrollFrame_OnMouseWheel(AchieverAchievementFrameCategoriesContainer, -1);
			end			
		end
		
		-- Remove me if everything's working fine
		i = i + 1;
		if ( i > 100 ) then
			--assert(false);
			return;
		end
	end		
	
	AchieverAchievementFrameAchievements_ClearSelection();	
	AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(0);
	AchieverAchievementFrameAchievements_Update();
	
	local shown = false;
	while ( not shown ) do
		for _, button in next, AchieverAchievementFrameAchievementsContainer.buttons do
			if ( button.id == id and math.ceil(button:GetTop()) >= math.ceil(AchieverAchievementFrameAchievementsContainer:GetBottom())) then
				-- The "True" here ignores modifiers, so you don't accidentally track or link this achievement. :P
				AchievementButton_OnClick(button, true);
				
				-- We found the button!
				shown = button;
				break;
			end
		end			
		
		local _, maxVal = AchieverAchievementFrameAchievementsContainerScrollBar:GetMinMaxValues();
		if ( shown ) then
			-- If we can, move the achievement we're scrolling to to the top of the screen.
			local newHeight = AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() + AchieverAchievementFrameAchievementsContainer:GetTop() - shown:GetTop();
			newHeight = min(newHeight, maxVal);
			AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(newHeight);
		else
			if ( AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() == maxVal ) then
				--assert(false, "Failed to find achievement " .. id .. " while jumping!")
				return;
			else
				AchieverHybridScrollFrame_OnMouseWheel(AchieverAchievementFrameAchievementsContainer, -1);
			end			
		end
	end
end

function AchieverAchievementFrameAchievements_FindSelection()
	local _, maxVal = AchieverAchievementFrameAchievementsContainerScrollBar:GetMinMaxValues();
	local scrollHeight = AchieverAchievementFrameAchievementsContainer:GetHeight();
	local newHeight = 0;
	AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(0);	
	while ( not shown ) do
		for _, button in next, AchieverAchievementFrameAchievementsContainer.buttons do
			if ( button.selected ) then
				newHeight = AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() + AchieverAchievementFrameAchievementsContainer:GetTop() - button:GetTop();
				newHeight = min(newHeight, maxVal);
				AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(newHeight);					
				return;
			end
		end		
		if ( AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() == maxVal ) then		
			return;
		else
			newHeight = newHeight + scrollHeight;
			newHeight = min(newHeight, maxVal);
			AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(newHeight);
		end
	end
end

function AchieverAchievementFrameAchievements_AdjustSelection()
	local selectedButton;	
	-- check if selection is visible
	for _, button in next, AchieverAchievementFrameAchievementsContainer.buttons do
		if ( button.selected ) then
			selectedButton = button;
			break;
		end
	end	
	
	if ( not selectedButton ) then
		AchieverAchievementFrameAchievements_FindSelection();
	else
		local newHeight;
		if ( selectedButton:GetTop() > AchieverAchievementFrameAchievementsContainer:GetTop() ) then
			newHeight = AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() + AchieverAchievementFrameAchievementsContainer:GetTop() - selectedButton:GetTop();
		elseif ( selectedButton:GetBottom() < AchieverAchievementFrameAchievementsContainer:GetBottom() ) then
			if ( selectedButton:GetHeight() > AchieverAchievementFrameAchievementsContainer:GetHeight() ) then
				newHeight = AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() + AchieverAchievementFrameAchievementsContainer:GetTop() - selectedButton:GetTop();
			else
				newHeight = AchieverAchievementFrameAchievementsContainerScrollBar:GetValue() + AchieverAchievementFrameAchievementsContainer:GetBottom() - selectedButton:GetBottom();
			end
		end
		if ( newHeight ) then
			local _, maxVal = AchieverAchievementFrameAchievementsContainerScrollBar:GetMinMaxValues();
			newHeight = min(newHeight, maxVal);
			AchieverAchievementFrameAchievementsContainerScrollBar:SetValue(newHeight);					
		end
	end
end

function AchieverAchievementFrame_SelectSummaryStatistic (criteriaId)
	AchieverAchievementFrameTab_OnClick = AchieverAchievementFrameBaseTab_OnClick;
	AchieverAchievementFrameTab_OnClick(2);
	AchieverAchievementFrameStats:Show();
	AchieverAchievementFrameSummary:Hide();
	
	AchieverAchievementFrameCategories_ClearSelection();
	
	local id = Achiever_GetAchievementInfoFromCriteria(criteriaId);
	local category = Achiever_GetAchievementCategory(id);
	
	local categoryIndex, parent, hidden = 0;
	
	local categoryIndex, parent, hidden = 0;
	for i, entry in next, ACHIEVEMENTUI_CATEGORIES do
		if ( entry.id == category ) then
			parent = entry.parent;
		end
	end
	
	for i, entry in next, ACHIEVEMENTUI_CATEGORIES do
		if ( entry.id == parent ) then
			entry.collapsed = false;
		elseif ( entry.parent == parent ) then
			entry.hidden = false;
		elseif ( entry.parent == true ) then
			entry.collapsed = true;
		elseif ( entry.parent ) then
			entry.hidden = true;
		end
	end
	
	achievementFunctions.selectedCategory = category;
	AchieverAchievementFrameCategories_Update();
	AchieverAchievementFrameCategoriesContainerScrollBar:SetValue(0);
	
	local shown, i = false, 1;
	while ( not shown ) do
		for _, button in next, AchieverAchievementFrameCategoriesContainer.buttons do
			if ( button.categoryID == category and math.ceil(button:GetBottom()) >= math.ceil(AchieverAchievementFrameAchievementsContainer:GetBottom())) then
				shown = true;
			end
		end
		
		if ( not shown ) then
			local _, maxVal = AchieverAchievementFrameCategoriesContainerScrollBar:GetMinMaxValues();
			if ( AchieverAchievementFrameCategoriesContainerScrollBar:GetValue() == maxVal ) then
				assert(false)
			else
				AchieverHybridScrollFrame_OnMouseWheel(AchieverAchievementFrameCategoriesContainer, -1);
			end			
		end
		
		-- Remove me if everything's working fine
		i = i + 1;
		if ( i > 100 ) then
			assert(false);
		end
	end		
	
	AchieverAchievementFrameStats_Update();
	AchieverAchievementFrameStatsContainerScrollBar:SetValue(0);
	
	local shown, i = false, 1;
	while ( not shown ) do
		for _, button in next, AchieverAchievementFrameStatsContainer.buttons do
			if ( button.id == id and math.ceil(button:GetBottom()) >= math.ceil(AchieverAchievementFrameStatsContainer:GetBottom())) then
				AchievementStatButton_OnClick(button);
				
				-- We found the button! MAKE IT SHOWN ZOMG!
				shown = button;
			end
		end			
		
		if ( shown and AchieverAchievementFrameStatsContainerScrollBar:IsShown() ) then
			-- If we can, move the achievement we're scrolling to to the top of the screen.
			AchieverAchievementFrameStatsContainerScrollBar:SetValue(AchieverAchievementFrameStatsContainerScrollBar:GetValue() + AchieverAchievementFrameStatsContainer:GetTop() - shown:GetTop());
		elseif ( not shown ) then
			local _, maxVal = AchieverAchievementFrameStatsContainerScrollBar:GetMinMaxValues();
			if ( AchieverAchievementFrameStatsContainerScrollBar:GetValue() == maxVal ) then
				assert(false)
			else
				AchieverHybridScrollFrame_OnMouseWheel(AchieverAchievementFrameStatsContainer, -1);
			end			
		end
		
		-- Remove me if everything's working fine.
		i = i + 1;
		if ( i > 100 ) then
			assert(false);
		end
	end
end

function AchieverAchievementFrameComparison_OnLoad (self)
	AchieverAchievementFrameComparisonContainer_OnLoad(self);
	AchieverAchievementFrameComparisonStatsContainer_OnLoad(self);
	self:RegisterEvent("ACHIEVEMENT_EARNED");
	self:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
	-- See AchieverAchievementFrameAchievements_OnLoad's matching comment.
	self:SetScript("OnEvent", AchieverAchievementFrameComparison_OnEvent);
end

function AchieverAchievementFrameComparisonContainer_OnLoad (parent)
	AchieverAchievementFrameComparisonContainerScrollBar.ShowOriginal = AchieverAchievementFrameComparisonContainerScrollBar.Show;
	AchieverAchievementFrameComparisonContainerScrollBar.Show =
		function (self)
			AchieverAchievementFrameComparison:SetWidth(626);
			AchieverAchievementFrameComparisonSummaryPlayer:SetWidth(498);
			for _, button in next, AchieverAchievementFrameComparisonContainer.buttons do
				button:SetWidth(616);
				button.player:SetWidth(498);
			end
			self:ShowOriginal();
		end

	AchieverAchievementFrameComparisonContainerScrollBar.HideOriginal = AchieverAchievementFrameComparisonContainerScrollBar.Hide;
	AchieverAchievementFrameComparisonContainerScrollBar.Hide =
		function (self)
			AchieverAchievementFrameComparison:SetWidth(650);
			AchieverAchievementFrameComparisonSummaryPlayer:SetWidth(522);
			for _, button in next, AchieverAchievementFrameComparisonContainer.buttons do
				button:SetWidth(640);
				button.player:SetWidth(522);
			end
			self:HideOriginal();
		end
	
	AchieverAchievementFrameComparisonContainerScrollBarBG:Show();
	AchieverAchievementFrameComparisonContainer.update = AchieverAchievementFrameComparison_Update;
	AchieverHybridScrollFrame_CreateButtons(AchieverAchievementFrameComparisonContainer, "ComparisonTemplate", 0, -2);
end

function AchieverAchievementFrameComparisonStatsContainer_OnLoad (parent)
	AchieverAchievementFrameComparisonStatsContainerScrollBar.ShowOriginal = AchieverAchievementFrameComparisonStatsContainerScrollBar.Show;
	AchieverAchievementFrameComparisonStatsContainerScrollBar.Show =
		function (self)
			AchieverAchievementFrameComparison:SetWidth(626);
			for _, button in next, AchieverAchievementFrameComparisonStatsContainer.buttons do
				button:SetWidth(616);
			end
			self:ShowOriginal();
		end

	AchieverAchievementFrameComparisonStatsContainerScrollBar.HideOriginal = AchieverAchievementFrameComparisonStatsContainerScrollBar.Hide;
	AchieverAchievementFrameComparisonStatsContainerScrollBar.Hide =
		function (self)
			AchieverAchievementFrameComparison:SetWidth(650);
			for _, button in next, AchieverAchievementFrameComparisonStatsContainer.buttons do
				button:SetWidth(640);
			end
			self:HideOriginal();
		end
	
	AchieverAchievementFrameComparisonStatsContainerScrollBarBG:Show();
	AchieverAchievementFrameComparisonStatsContainer.update = AchieverAchievementFrameComparison_UpdateStats;
	AchieverHybridScrollFrame_CreateButtons(AchieverAchievementFrameComparisonStatsContainer, "ComparisonStatTemplate", 0, -2);
end

function AchieverAchievementFrameComparison_OnShow ()
	AchieverAchievementFrameStats:Hide();
	AchieverAchievementFrameAchievements:Hide();
	AchieverAchievementFrame:SetWidth(890);
	AchieverAchievementFrame:SetAttribute("UIPanelLayout-xOffset", 38);
	UpdateUIPanelPositions(AchieverAchievementFrame);
	AchieverAchievementFrame.isComparison = true;
end

function AchieverAchievementFrameComparison_OnHide ()
	AchieverAchievementFrame.selectedTab = nil;
	AchieverAchievementFrame:SetWidth(768);
	AchieverAchievementFrame:SetAttribute("UIPanelLayout-xOffset", 80);
	UpdateUIPanelPositions(AchieverAchievementFrame);
	AchieverAchievementFrame.isComparison = false;
	Achiever_ClearAchievementComparisonUnit();
end

-- See AchieverAchievementFrameAchievements_OnEvent's matching comment on
-- why this takes `data` instead of `...`.
function AchieverAchievementFrameComparison_OnEvent (frame, ev, data)
	local self = frame or this;
	local event = ev or event;
	if ( event == "INSPECT_ACHIEVEMENT_READY" ) then
		AchieverAchievementFrameComparisonHeaderPoints:SetText(Achiever_GetComparisonAchievementPoints());
		AchieverAchievementFrameComparison_UpdateStatusBars(achievementFunctions.selectedCategory)
	elseif ( event == "UNIT_PORTRAIT_UPDATE" ) then
		local updateUnit = data;
		if ( updateUnit and updateUnit == AchieverAchievementFrameComparisonHeaderPortrait.unit and UnitName(updateUnit) == AchieverAchievementFrameComparisonHeaderName:GetText() ) then
			SetPortraitTexture(AchieverAchievementFrameComparisonHeaderPortrait, updateUnit);
		end
	end
	
	AchieverAchievementFrameComparison_ForceUpdate();
end

function AchieverAchievementFrameComparison_SetUnit (unit)
	Achiever_ClearAchievementComparisonUnit();
	Achiever_SetAchievementComparisonUnit(unit);
	
	AchieverAchievementFrameComparisonHeaderPoints:SetText(Achiever_GetComparisonAchievementPoints());
	AchieverAchievementFrameComparisonHeaderName:SetText(UnitName(unit));
	SetPortraitTexture(AchieverAchievementFrameComparisonHeaderPortrait, unit);
	AchieverAchievementFrameComparisonHeaderPortrait.unit = unit;
	AchieverAchievementFrameComparisonHeaderPortrait.race = UnitRace(unit);
	AchieverAchievementFrameComparisonHeaderPortrait.sex = UnitSex(unit);
end

function AchieverAchievementFrameComparison_ClearSelection ()
	-- Doesn't do anything WHEE~!
end

function AchieverAchievementFrameComparison_ForceUpdate ()
	if ( achievementFunctions == COMPARISON_ACHIEVEMENT_FUNCTIONS ) then
		local buttons = AchieverAchievementFrameComparisonContainer.buttons;
		for i, button in next, buttons do
			button.id = nil;
		end
		
		AchieverAchievementFrameComparison_Update();
	elseif ( achievementFunctions == COMPARISON_STAT_FUNCTIONS ) then
		AchieverAchievementFrameComparison_UpdateStats();
	end
end

function AchieverAchievementFrameComparison_Update ()
	local category = achievementFunctions.selectedCategory;
	if ( not category or category == "summary" ) then
		return;
	end
	local scrollFrame = AchieverAchievementFrameComparisonContainer
	
	local offset = AchieverHybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numAchievements, numCompleted = Achiever_GetCategoryNumAchievements(category);
	local numButtons = table.getn(buttons);

	local achievementIndex;
	local buttonHeight = buttons[1]:GetHeight();
	for i = 1, numButtons do
		achievementIndex = i + offset;
		AchieverAchievementFrameComparison_DisplayAchievement(buttons[i], category, achievementIndex);
	end
	
	AchieverHybridScrollFrame_Update(scrollFrame, buttonHeight*numAchievements, buttonHeight*numButtons);
end

ACHIEVEMENTCOMPARISON_PLAYERSHIELDFONT1 = GameFontNormal;
ACHIEVEMENTCOMPARISON_PLAYERSHIELDFONT2 = GameFontNormalSmall;
ACHIEVEMENTCOMPARISON_FRIENDSHIELDFONT1 = GameFontNormalSmall;
ACHIEVEMENTCOMPARISON_FRIENDSHIELDFONT2 = GameFontNormalSmall;

function AchieverAchievementFrameComparison_DisplayAchievement (button, category, index)
	local id, name, points, completed, month, day, year, description, flags, icon, rewardText = Achiever_GetAchievementInfo(category, index);
	if ( not id ) then
		button:Hide();
		return;
	else
		button:Show();
	end
	
	if ( Achiever_GetPreviousAchievement(id) ) then
		-- If this is a progressive achievement, show the total score.
		points = AchievementButton_GetProgressivePoints(id);
	end
	
	if ( button.id ~= id ) then
		button.id = id;
		
		local player = button.player;
		local friend = button.friend;
		
		local friendCompleted, friendMonth, friendDay, friendYear = Achiever_GetAchievementComparisonInfo(id);
		player.label:SetText(name);		
	
		player.description:SetText(description);
	
		player.icon.texture:SetTexture(icon);
		friend.icon.texture:SetTexture(icon);
		
		if ( points > 0 ) then
			player.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
			friend.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields]]);
		else
			player.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
			friend.shield.icon:SetTexture([[Interface\AddOns\Achiever\textures\UI-Achievement-Shields-NoPoints]]);
		end
		AchieverAchievementShield_SetPoints(points, player.shield.points, ACHIEVEMENTCOMPARISON_PLAYERSHIELDFONT1, ACHIEVEMENTCOMPARISON_PLAYERSHIELDFONT2);
		AchieverAchievementShield_SetPoints(points, friend.shield.points, ACHIEVEMENTCOMPARISON_FRIENDSHIELDFONT1, ACHIEVEMENTCOMPARISON_FRIENDSHIELDFONT2);
		
		if ( completed and not player.completed ) then
			player.completed = true;
			player.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
			player.dateCompleted:Show();
			player:Saturate();
		elseif ( completed ) then
			player.dateCompleted:SetText(string.format(SHORTDATE, day, month, year));
		else
			player.completed = nil;
			player.dateCompleted:Hide();
			player:Desaturate();
		end
		
		if ( friendCompleted and not friend.completed ) then
			friend.completed = true;
			friend.status:SetText(string.format(SHORTDATE, friendDay, friendMonth, friendYear));
			friend:Saturate();
		elseif ( friendCompleted ) then
			friend.status:SetText(string.format(SHORTDATE, friendDay, friendMonth, friendYear));
		else
			friend.completed = nil;
			friend.status:SetText(INCOMPLETE);
			friend:Desaturate();
		end
	end
end

local displayStatCategories = {};
function AchieverAchievementFrameComparison_UpdateStats ()
	local category = achievementFunctions.selectedCategory;
	local scrollFrame = AchieverAchievementFrameComparisonStatsContainer;
	local offset = AchieverHybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = table.getn(buttons);
	local headerHeight = 24;
	local statHeight = 24;
	local totalHeight = 0;	
	local numStats, numCompleted = Achiever_GetCategoryNumAchievements(category);

	local categories = ACHIEVEMENTUI_CATEGORIES;
	-- clear out table
	if ( achievementFunctions.lastCategory ~= category ) then
		local statCat;
		while ( table.getn(displayStatCategories) > 0 ) do
			table.remove(displayStatCategories);
		end
		-- build a list of shown category and stat id's

		tinsert(displayStatCategories, {id = category, header = true});
		totalHeight = totalHeight+headerHeight;

		for i=1, numStats do
			tinsert(displayStatCategories, {id = Achiever_GetAchievementInfo(category, i)});
			totalHeight = totalHeight+statHeight;
		end
		achievementFunctions.lastCategory = category;
		achievementFunctions.lastHeight = totalHeight;
	else
		totalHeight = achievementFunctions.lastHeight;
	end
	
	-- add all the subcategories and their stat id's
	for i, cat in next, categories do
		if ( cat.parent == category ) then
			tinsert(displayStatCategories, {id = cat.id, header = true});
			totalHeight = totalHeight+headerHeight;
			numStats = Achiever_GetCategoryNumAchievements(cat.id);
			for k=1, numStats do
				tinsert(displayStatCategories, {id = Achiever_GetAchievementInfo(cat.id, k)});
				totalHeight = totalHeight+statHeight;
			end
		end
	end

	-- iterate through the displayStatCategories and display them
	local statCount = table.getn(displayStatCategories);
	local statIndex, id, button;
	local stat;
	local displayedHeight = 0;
	for i = 1, numButtons do
		button = buttons[i];
		statIndex = offset + i;
		if ( statIndex <= statCount ) then
			stat = displayStatCategories[statIndex];
			if ( stat.header ) then
				AchieverAchievementFrameComparisonStats_SetHeader(button, stat.id);
			else
				AchieverAchievementFrameComparisonStats_SetStat(button, stat.id, nil, statIndex);
			end
			button:Show();
		else
			button:Hide();
		end
		displayedHeight = displayedHeight+button:GetHeight();
	end
	AchieverHybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

function AchieverAchievementFrameComparisonStat_OnLoad (self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	self.background = _G[name.."BG"];
	self.left = _G[name.."HeaderLeft"];
	self.middle = _G[name.."HeaderMiddle"];
	self.right = _G[name.."HeaderRight"];
	self.left2 = _G[name.."HeaderLeft2"];
	self.middle2 = _G[name.."HeaderMiddle2"];
	self.right2 = _G[name.."HeaderRight2"];
	self.text = _G[name.."Text"];
	self.title = _G[name.."Title"];
	self.value = _G[name.."Value"];
	self.value:SetVertexColor(1, 0.97, 0.6);
	self.friendValue = _G[name.."ComparisonValue"];
	self.friendValue:SetVertexColor(1, 0.97, 0.6);
	self.mouseover = _G[name.. "Mouseover"];
end

function AchieverAchievementFrameComparisonStats_SetStat (button, category, index, colorIndex, isSummary)
--Remove these variables when we know for sure we don't need them
	local id, name, points, completed, month, day, year, description, flags, icon;
	if ( not isSummary ) then
		if ( not index ) then
			id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(category);
		else
			id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfo(category, index);
		end
		
	else
		-- This is on the summary page
		id, name, points, completed, month, day, year, description, flags, icon = Achiever_GetAchievementInfoFromCriteria(category);
	end
	
	button.id = id;
	
	if ( not colorIndex ) then
		if ( not index ) then
			message("Error, need a color index or index");
		end
		colorIndex = index;
	end
	
	button.background:Show();
	-- Color every other line yellow
	if ( mod(colorIndex, 2) == 1 ) then
		button.background:SetTexCoord(0, 1, 0.1875, 0.3671875);
		button.background:SetBlendMode("BLEND");
		button.background:SetAlpha(1.0);
		button:SetHeight(24);
	else
		button.background:SetTexCoord(0, 1, 0.375, 0.5390625);
		button.background:SetBlendMode("ADD");
		button.background:SetAlpha(0.5);
		button:SetHeight(24);
	end
	
	-- Figure out the criteria
	local numCriteria = Achiever_GetAchievementNumCriteria(id);
	if ( numCriteria == 0 ) then
		-- This is no good!
	end
	-- Just show the first criteria for now
	local criteriaString, criteriaType, completed, quantityNumber, reqQuantity, charName, flags, assetID, quantity, friendQuantity;
	if ( not isSummary ) then
		friendQuantity = Achiever_GetComparisonStatistic(id);
		quantity = Achiever_GetStatistic(id);
	else
		criteriaString, criteriaType, completed, quantityNumber, reqQuantity, charName, flags, assetID, quantity = Achiever_GetAchievementCriteriaInfo(category);
	end
	if ( not quantity ) then
		quantity = "--";
	end
	if ( not friendQuantity ) then
		friendQuantity = "--";
	end
	
	button.value:SetText(quantity);
	
	-- We're gonna use button.text here to measure string width for friendQuantity. This saves us many strings!
	button.text:SetText(friendQuantity);
	local width = button.text:GetStringWidth();
	if ( width > button.friendValue:GetWidth() ) then
		button.friendValue:SetFontObject("AchievementFont_Small");
		button.mouseover:Show();
		button.mouseover.tooltip = friendQuantity;
	else
		button.friendValue:SetFontObject("GameFontHighlightRight");
		button.mouseover:Hide();
		button.mouseover.tooltip = nil;
	end
	
	button.text:SetText(name);
	button.friendValue:SetText(friendQuantity);
	
	
	-- Hide the header images
	button.title:Hide();
	button.left:Hide();
	button.middle:Hide();
	button.right:Hide();
	button.left2:Hide();
	button.middle2:Hide();
	button.right2:Hide();
	button.isHeader = false;
end

function AchieverAchievementFrameComparisonStats_SetHeader(button, id)
	-- show header
	button.left:Show();
	button.middle:Show();
	button.right:Show();
	button.left2:Show();
	button.middle2:Show();
	button.right2:Show();
	button.title:SetText(Achiever_GetCategoryInfo(id));
	button.title:Show();
	button.friendValue:SetText("");
	button.value:SetText("");
	button.text:SetText("");
	button:SetHeight(24);
	button.background:Hide();
	button.isHeader = true;
	button.id = id;
end

function AchievementComparisonPlayerButton_Saturate (self)
	local name = self:GetName();
	_G[name .. "TitleBackground"]:SetTexCoord(0, 0.9765625, 0, 0.3125);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal");
	_G[name .. "Glow"]:SetVertexColor(1.0, 1.0, 1.0);
	self.icon:Saturate();
	self.shield:Saturate();
	self.shield.points:SetVertexColor(1, 1, 1);
	self.label:SetVertexColor(1, 1, 1);
	self.description:SetTextColor(0, 0, 0, 1);
	self.description:SetShadowOffset(0, 0);
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
end

function AchievementComparisonPlayerButton_Desaturate (self)
	local name = self:GetName();
	_G[name .. "TitleBackground"]:SetTexCoord(0, 0.9765625, 0.34375, 0.65625);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal-Desaturated");
	_G[name .. "Glow"]:SetVertexColor(.22, .17, .13);
	self.icon:Desaturate();
	self.shield:Desaturate();
	self.shield.points:SetVertexColor(.65, .65, .65);
	self.label:SetVertexColor(.65, .65, .65);
	self.description:SetTextColor(1, 1, 1, 1);
	self.description:SetShadowOffset(1, -1);
	self:SetBackdropBorderColor(.5, .5, .5);
end

function AchievementComparisonPlayerButton_OnLoad (self)
	-- See AchievementIcon_OnLoad's matching guard comment (AchievementUI.lua,
	-- top of file).
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();

	self.label = _G[name .. "Label"];
	self.description = _G[name .. "Description"];
	self.icon = _G[name .. "Icon"];
	self.shield = _G[name .. "Shield"];
	self.dateCompleted = _G[name .. "DateCompleted"];
	self.titleBar = _G[name .. "TitleBackground"];

	-- See AchieverAchievementFrameAchievementsBackdrop_OnLoad's matching
	-- comment -- the old <Backdrop> XML tag is a no-op on 1.14.2+.
	self:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, edgeSize = 16 });
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
	self.Saturate = AchievementComparisonPlayerButton_Saturate;
	self.Desaturate = AchievementComparisonPlayerButton_Desaturate;
	
	self:Desaturate();
	
	-- AchieverAchievementFrameComparison.buttons = AchieverAchievementFrameComparison.buttons or {};
	-- tinsert(AchieverAchievementFrameComparison.buttons, self);
end

function AchievementComparisonFriendButton_Saturate (self)
	local name = self:GetName();
	_G[name .. "TitleBackground"]:SetTexCoord(0.3, 0.575, 0, 0.3125);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal");
	_G[name .. "Glow"]:SetVertexColor(1.0, 1.0, 1.0);
	self.icon:Saturate();
	self.shield:Saturate();
	self.shield.points:SetVertexColor(1, 1, 1);
	self.status:SetVertexColor(1, .82, 0);
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
end

function AchievementComparisonFriendButton_Desaturate (self)
	local name = self:GetName();
	_G[name .. "TitleBackground"]:SetTexCoord(0.3, 0.575, 0.34375, 0.65625);
	_G[name .. "Background"]:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Parchment-Horizontal-Desaturated");
	_G[name .. "Glow"]:SetVertexColor(.22, .17, .13);
	self.icon:Desaturate();
	self.shield:Desaturate();
	self.shield.points:SetVertexColor(.65, .65, .65);
	self.status:SetVertexColor(.65, .65, .65);
	self:SetBackdropBorderColor(.5, .5, .5);
end

function AchievementComparisonFriendButton_OnLoad (self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	local name = self:GetName();
	
	self.status = _G[name .. "Status"];
	self.icon = _G[name .. "Icon"];
	self.shield = _G[name .. "Shield"];

	-- See AchieverAchievementFrameAchievementsBackdrop_OnLoad's matching
	-- comment -- the old <Backdrop> XML tag is a no-op on 1.14.2+.
	self:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, edgeSize = 16 });
	self:SetBackdropBorderColor(ACHIEVEMENTUI_REDBORDER_R, ACHIEVEMENTUI_REDBORDER_G, ACHIEVEMENTUI_REDBORDER_B, ACHIEVEMENTUI_REDBORDER_A);
	self.Saturate = AchievementComparisonFriendButton_Saturate;
	self.Desaturate = AchievementComparisonFriendButton_Desaturate;
	
	self:Desaturate();
end

function AchieverAchievementFrame_IsComparison()
	return AchieverAchievementFrame.isComparison;
end

function AchieverAchievementFrame_IsFeatOfStrength()
	if ( AchieverAchievementFrame.selectedTab == 1 and achievementFunctions.selectedCategory == displayCategories[table.getn(displayCategories)].id ) then
		return true;
	end
	return false;
end

ACHIEVEMENT_FUNCTIONS = {
	categoryAccessor = Achiever_GetCategoryList,
	clearFunc = AchieverAchievementFrameAchievements_ClearSelection,
	updateFunc = AchieverAchievementFrameAchievements_Update,
	selectedCategory = "summary";
}

STAT_FUNCTIONS = {
	categoryAccessor = Achiever_GetStatisticsCategoryList,
	clearFunc = nil,
	updateFunc = AchieverAchievementFrameStats_Update,
	selectedCategory = STATS_DEFAULT_CATEGORY_ID;
}

COMPARISON_ACHIEVEMENT_FUNCTIONS = {
	categoryAccessor = Achiever_GetCategoryList,
	clearFunc = AchieverAchievementFrameComparison_ClearSelection,
	updateFunc = AchieverAchievementFrameComparison_Update,
	selectedCategory = -1,
}

COMPARISON_STAT_FUNCTIONS = {
	categoryAccessor = Achiever_GetStatisticsCategoryList,
	clearFunc = AchieverAchievementFrameComparison_ClearSelection,
	updateFunc = AchieverAchievementFrameComparison_UpdateStats,
	selectedCategory = -2,
}

achievementFunctions = ACHIEVEMENT_FUNCTIONS;


ACHIEVEMENT_TEXTURES_TO_LOAD = {
	{	
		name="AchieverAchievementFrameAchievementsBackground", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementBackground",
	},
	{	
		name="AchieverAchievementFrameSummaryBackground", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementBackground",
	},
	{	
		name="AchieverAchievementFrameComparisonBackground", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementBackground",
	},
	{	
		name="AchieverAchievementFrameCategoriesBG", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-AchievementBackground",
	},
	{	
		name="AchieverAchievementFrameWaterMark", 
	},
	{	
		name="AchieverAchievementFrameHeaderLeft", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Header",
	},
	{	
		name="AchieverAchievementFrameHeaderRight", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Header",
	},
	{	
		name="AchieverAchievementFrameHeaderPointBorder", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Header",
	},
	{	
		name="AchieverAchievementFrameComparisonWatermark", 
		file="Interface\\AddOns\\Achiever\\textures\\UI-Achievement-StatsComparisonBackground",
	},
}

function AchieverAchievementFrame_ClearTextures()
	for k, v in pairs(ACHIEVEMENT_TEXTURES_TO_LOAD) do
		_G[v.name]:SetTexture(nil);
	end
end

function AchieverAchievementFrame_LoadTextures()
	for k, v in pairs(ACHIEVEMENT_TEXTURES_TO_LOAD) do
		if ( v.file ) then
			_G[v.name]:SetTexture(v.file);
		end
	end
end