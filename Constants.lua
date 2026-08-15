-- Achievement flag/criteria constants and a bitwise-AND polyfill.
-- Real WotLK 3.3.5 values, pulled from Blizzard's FrameXML\Constants.lua --
-- not present in 1.12 at all, since achievements didn't exist yet.
--
-- CONFIRMED ROOT CAUSE (live 1.14.2 testing, extensive bisection): modern
-- clients' own core Interface\FrameXML\Constants.lua -- NOT
-- Blizzard_AchievementUI, which doesn't even exist on this client, but the
-- always-loaded core file -- already defines several of these exact same
-- global names, and Interface\FrameXML\WatchFrame.lua (the real, always-
-- running Objective Tracker, not an addon, not content-gated) reads
-- ACHIEVEMENT_CRITERIA_PROGRESS_BAR as part of its regular update cycle.
-- Unconditionally overwriting these globals every login -- insecure addon
-- code writing into values Blizzard's own continuously-running secure UI
-- code depends on -- was tainting execution and blocking action bar clicks
-- and world interaction ("Achiever has been blocked from an action only
-- available to the Blizzard UI") from the moment of login onward, since
-- WatchFrame's update cycle runs constantly rather than once. Every
-- assignment below is now guarded the same way as the bit.band/table.getn/
-- math.mod polyfills further down this file: only ever fires where the real
-- thing is missing, so 1.12.1 (which genuinely never defines any of these)
-- is completely unaffected, while modern clients keep Blizzard's own real
-- values untouched.

-- The client's own locale, e.g. "zhCN" -- a real 1.12 client only ever
-- reports one of enUS/koKR/frFR/deDE/zhCN/zhTW/esES/esMX (ruRU/ptBR/itIT/
-- jaJP didn't exist as client locale slots until the 2.1.0/TBC pre-patch).
-- Not consulted by Achiever itself -- a locale-override addon (e.g.
-- Achiever-zhCN) checks GetLocale() directly before overwriting any text --
-- this is just a simple, always-available piece of info for other code
-- (and a future settings UI) to read.
AchieverLocale = GetLocale();

CRITERIA_TYPE_ACHIEVEMENT = CRITERIA_TYPE_ACHIEVEMENT or 8;

ACHIEVEMENT_FLAGS_STATISTIC = ACHIEVEMENT_FLAGS_STATISTIC or 1;
ACHIEVEMENT_FLAGS_HIDDEN = ACHIEVEMENT_FLAGS_HIDDEN or 2;
ACHIEVEMENT_FLAGS_SUMM = ACHIEVEMENT_FLAGS_SUMM or 8;
ACHIEVEMENT_FLAGS_MAX_USED = ACHIEVEMENT_FLAGS_MAX_USED or 16;
ACHIEVEMENT_FLAGS_REQ_COUNT = ACHIEVEMENT_FLAGS_REQ_COUNT or 32;
ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR = ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR or 128;
NUM_ACHIEVEMENT_FLAGS = NUM_ACHIEVEMENT_FLAGS or 3;

ACHIEVEMENT_CRITERIA_PROGRESS_BAR = ACHIEVEMENT_CRITERIA_PROGRESS_BAR or 1;
ACHIEVEMENT_CRITERIA_HIDDEN = ACHIEVEMENT_CRITERIA_HIDDEN or 2;
NUM_ACHIEVEMENT_CRITERIA_FLAGS = NUM_ACHIEVEMENT_CRITERIA_FLAGS or 2;

-- achievement_category_dbc's real "Feats of Strength" row id (Data\Categories.lua) --
-- Router.lua's Achiever_RebuildIndices redirects a retired achievement here once its
-- Data\Retirements.lua patch is reached, matching the server-side ACHIEVEMENT_CATEGORY_FEATS_OF_STRENGTH
-- constant in AchievementMgr.h.
ACHIEVER_CATEGORY_FEATS_OF_STRENGTH = 81;

-- Not part of Blizzard's client-side Constants.lua (money formatting is
-- decided server-side in the real game and handed to the addon as an
-- already-formatted Achiever_GetStatistic string) -- backported here from the
-- server-side AchievementCriteriaFlags enum (mangos/TrinityCore/vmangos:
-- ACHIEVEMENT_CRITERIA_FLAG_MONEY_COUNTER = 0x20) so Router.lua's Achiever_GetStatistic
-- mock can tell which stats are gold amounts. Confirmed against
-- Data\Criteria.lua: every criteria whose description reads like a gold
-- total/spend (types 59/60/62/63/65/66/67/80/83/85/86 -- vendor gold, respec
-- cost, travel cost, postage, quest-reward gold, gold looted, auction
-- gold/bids/sales, highest gold owned) carries flags=32 and nothing else in
-- that data does.
ACHIEVEMENT_CRITERIA_MONEY_COUNTER = 32;

WATCHFRAME_MAXACHIEVEMENTS = WATCHFRAME_MAXACHIEVEMENTS or 10;

-- FuBar_MoneyFu (a real, working addon on this exact client -- see
-- MoneyFu.lua's OnInitialize/UpdateText) displays money as separate
-- Texture+FontString pairs sliced from the single combined
-- Interface\MoneyFrame\UI-MoneyIcons sheet (vanilla never got WotLK's split
-- per-coin UI-GoldIcon/UI-SilverIcon/UI-CopperIcon files), rather than a
-- single formatted string -- confirmed via that same TexCoord slicing
-- (0/.25/.5/.75 quarters) MoneyFu itself uses. AchievementStatButton_OnLoad
-- builds an equivalent gold/silver/copper icon+text row for money-flagged
-- stats; this just centralizes the shared copper->gold/silver/copper split
-- math (matches MoneyFu:UpdateText's own floor/mod arithmetic).
function Achiever_SplitMoney(money)
	local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
	local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
	local copper = mod(money, COPPER_PER_SILVER);
	return gold, silver, copper;
end

-- WoW's |T..|t inline texture-escape markup (what WotLK's own
-- GOLD_AMOUNT_TEXTURE/SILVER_AMOUNT_TEXTURE/COPPER_AMOUNT_TEXTURE,
-- GlobalStrings.lua, use to embed coin icons in plain text) isn't supported
-- by this 1.12 client at all -- confirmed absent from every Lua file in
-- wow-vanilla-original-interface-files (Blizzard's own 1.12 FrameXML never
-- uses it, unlike the WotLK tree), and verified in-game to print literally
-- instead of rendering. So plain letter suffixes (matching WotLK's own
-- GetMoneyString colorblind-mode fallback, MoneyFrame.lua, for this same
-- "can't always show an icon" reason) are what's usable in arbitrary text --
-- real icon textures are only used where a dedicated Texture widget can be
-- positioned instead, i.e. the achievement-detail progress bar
-- (AchievementProgressBar_SetMoneyText, AchievementUI.lua), not here.
ACHIEVER_GOLD_SYMBOL = "g";
ACHIEVER_SILVER_SYMBOL = "s";
ACHIEVER_COPPER_SYMBOL = "c";

-- Mirrors WotLK's GetMoneyString (MoneyFrame.lua): each denomination only
-- appears if non-zero, except copper is forced to show when the total is
-- zero. Used for the watch-frame tracker's money-flagged criteria text
-- (Tracker.lua) and as Achiever_GetAchievementCriteriaInfo's underlying
-- "current / required" text for money criteria (Router.lua) -- see
-- ACHIEVEMENT_CRITERIA_MONEY_COUNTER.
function Achiever_FormatMoney(money)
	local gold, silver, copper = Achiever_SplitMoney(money);
	local result, separator = "", "";
	if (gold > 0) then
		result = gold .. ACHIEVER_GOLD_SYMBOL;
		separator = " ";
	end
	if (silver > 0) then
		result = result .. separator .. silver .. ACHIEVER_SILVER_SYMBOL;
		separator = " ";
	end
	if (copper > 0 or result == "") then
		result = result .. separator .. copper .. ACHIEVER_COPPER_SYMBOL;
	end
	return result;
end

-- `IsMouseOver` (added ~3.0) and `GameTooltip_ShowStatusBar` (achievement-era
-- WotLK addition) don't exist in 1.12 -- small standalone replacements
-- rather than relying on uncertain widget-metatable patching.
function Achiever_IsMouseOverFrame(frame)
	if (type(frame) ~= "table" or not frame.IsVisible or not frame:IsVisible()) then return false end
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom();
	if (not (left and right and top and bottom)) then return false end
	local x, y = GetCursorPosition();
	local scale = frame:GetEffectiveScale();
	x, y = x / scale, y / scale;
	return x >= left and x <= right and y >= bottom and y <= top;
end

-- CONFIRMED (live 1.14.2 testing): this bare, non-"Achiever_"-prefixed name
-- is a real, generic Blizzard tooltip utility (used throughout the UI for
-- status-bar-style tooltips -- health/mana/XP/reputation bars, cooldowns,
-- etc. -- not achievement-specific at all) that still exists on modern
-- clients despite the comment above only having verified its absence from
-- 1.12.1. Guarded like everything else in this file: only defined where the
-- real one doesn't already exist.
if not GameTooltip_ShowStatusBar then
	function GameTooltip_ShowStatusBar(tooltip, min, max, value, text)
		tooltip:AddLine(" ");
		tooltip:AddLine(text or (value .. " / " .. max), 1, 1, 1);
	end
end

-- `IsModifiedClick` (added ~2.0) doesn't exist in 1.12 -- there's no
-- user-configurable "modified click" binding system at all here, only the
-- hardcoded shift-click-to-link behavior other vanilla frames already use.
-- The achievement UI only ever asks about "CHATLINK", so that's the only
-- click type this maps to a real modifier; anything else (e.g. the
-- WotLK-only QUESTWATCHTOGGLE binding type) simply isn't a thing in 1.12.
-- CONFIRMED (live 1.14.2 testing): this bare, non-"Achiever_"-prefixed name
-- is a real, modern Blizzard API (added in patch 2.0, so definitely present
-- on Classic Era despite the comment above only having verified its absence
-- from 1.12.1) used throughout click handling generally, not just chat
-- links -- Achiever's simplified version returning false for every
-- clickType except "CHATLINK" is directly wrong if Blizzard's own code ever
-- calls the real one with anything else. Guarded like everything else in
-- this file: only defined where the real one doesn't already exist.
if not IsModifiedClick then
	function IsModifiedClick(clickType)
		if (clickType and clickType ~= "CHATLINK") then
			return false;
		end
		return IsShiftKeyDown();
	end
end

-- Vanilla's native PanelTemplates_Tab_OnClick/_TabResize take a different
-- argument order/signature than what the WotLK-era achievement UI code
-- expects (vanilla: Tab_OnClick(frame) using implicit this:GetID();
-- TabResize(padding, tab, ...)). Forked under new names -- confirmed by the
-- old backport attempt hitting this same issue -- rather than overriding the
-- natives, since other addons/default UI still rely on vanilla's own
-- signatures. PanelTemplates_SelectTab/_DeselectTab/_SetDisabledTabState take
-- a single `tab` param in both vanilla and WotLK, so those aren't forked.
function Achiever_PanelTemplates_Tab_OnClick(tabButton, frame)
	Achiever_PanelTemplates_SetTab(frame, tabButton:GetID());
end

function Achiever_PanelTemplates_SetTab(frame, id)
	frame.selectedTab = id;
	Achiever_PanelTemplates_UpdateTabs(frame);
end

function Achiever_PanelTemplates_UpdateTabs(frame)
	if (frame.selectedTab) then
		if (not frame.numTabs) then
			return;
		end
		for i = 1, frame.numTabs do
			local tab = _G[frame:GetName().."Tab"..i];
			if (tab.isDisabled) then
				PanelTemplates_SetDisabledTabState(tab);
			elseif (i == frame.selectedTab) then
				PanelTemplates_SelectTab(tab);
			else
				PanelTemplates_DeselectTab(tab);
			end
		end
	end
end

function Achiever_PanelTemplates_TabResize(tab, padding, absoluteSize, maxWidth, absoluteTextSize)
	-- Guard against a non-Frame tab -- confirmed via live 1.12.1 testing
	-- that this function's only caller (AchievementUI.xml's
	-- AchieverAchievementFrameTabButtonTemplate <OnShow>, passing self or
	-- this) can get a completely unrelated addon's own internal table here
	-- (confirmed via live diagnostic: ChatThrottleLib's table, presumably
	-- left in the shared global `this` by its own OnUpdate driver frame
	-- running moments before this button's Show() cascades from a Lua-side
	-- call) -- `this` is a single shared global that this client doesn't
	-- reliably rebind for every script context, so any other addon's most
	-- recent script execution can leak through. Purely cosmetic (auto-sizes
	-- the tab to fit its text) -- skipping it just leaves the tab at its
	-- default XML width instead of erroring.
	if (type(tab) ~= "table" or not tab.GetName) then return; end

	local tabName = tab:GetName();
	local buttonMiddle = _G[tabName.."Middle"];
	local buttonMiddleDisabled = _G[tabName.."MiddleDisabled"];
	local sideWidths = 2 * _G[tabName.."Left"]:GetWidth();
	local tabText = _G[tabName.."Text"];
	local width, tabWidth;
	-- Matches Blizzard's own PanelTemplates_TabResize exactly (confirmed
	-- against wow-wotlk-original-interface-files\Interface\FrameXML\UIPanelTemplates.lua)
	-- -- this function's own logic was never the problem. The real cause of
	-- tab2/tab3 measuring near-zero on 1.14.2 was their ButtonText genuinely
	-- having no font object assigned at all (confirmed live: GetFont()
	-- returned nil/garbage-height there, vs a real font on tab1) -- fixed
	-- upstream, at AchieverAchievementFrame_OnShow's reliable-handlers loop
	-- (AchievementUI.lua), by explicitly assigning a font before this ever
	-- runs, rather than here.
	if (not absoluteTextSize) then
		tabText:SetWidth(0);
	end
	local textWidth = absoluteTextSize or tabText:GetWidth();

	if (absoluteSize) then
		if (absoluteSize < sideWidths) then
			width = 1;
			tabWidth = sideWidths;
		else
			width = absoluteSize - sideWidths;
			tabWidth = absoluteSize;
		end
		tabText:SetWidth(width);
	else
		width = textWidth + (padding or 24);
		if (maxWidth and width > maxWidth) then
			width = maxWidth + (padding or 24);
			tabText:SetWidth(width);
		else
			tabText:SetWidth(0);
		end
		tabWidth = width + sideWidths;
	end

	if (buttonMiddle) then buttonMiddle:SetWidth(width); end
	if (buttonMiddleDisabled) then buttonMiddleDisabled:SetWidth(width); end

	tab:SetWidth(tabWidth);
	local highlightTexture = _G[tabName.."HighlightTexture"];
	if (highlightTexture) then highlightTexture:SetWidth(tabWidth); end
end

function Achiever_PanelTemplates_SetNumTabs(frame, numTabs)
	frame.numTabs = numTabs;
end

-- `UIDropDownMenu_CreateInfo` doesn't exist in vanilla's UIDropDownMenu.lua
-- (added later as a convenience constructor); vanilla's own
-- `UIDropDownMenu_AddButton`/`_Initialize` are otherwise compatible.
-- Guarded like everything else in this file, for the same reason as
-- GameTooltip_ShowStatusBar/IsModifiedClick above: this comment's own
-- premise (added later as a convenience constructor) means it likely
-- already exists, with real default fields, on modern clients.
if not UIDropDownMenu_CreateInfo then
	function UIDropDownMenu_CreateInfo()
		return {};
	end
end

-- table.getn/getn's Lua-5.1-only polyfill lives in Compat_1_14_2.lua, not
-- here -- see that file's header comment for why a runtime `if not
-- table.getn then ... end` guard in this shared file isn't enough (it's a
-- PARSE-TIME syntax problem on 1.12.1's Lua 5.0, not just a runtime one).

-- Vanilla's real UIDropDownMenu_SetText signature is (text, dropDownFrame).
-- Confirmed via live 1.14.2 testing that modern clients changed the argument
-- order to (dropDownFrame, text) at some point after vanilla -- calling with
-- the vanilla order there fed a string into the frame-typed parameter,
-- crashing UIDropDownMenu_SetText's own internals on frame:GetName().
-- WOW_PROJECT_ID is a modern-only global (introduced well after 1.12.1,
-- used by addons to detect which client "project" they're running on) that
-- reliably distinguishes the two without a version-number comparison.
function Achiever_UIDropDownMenu_SetText(text, dropDownFrame)
	if WOW_PROJECT_ID then
		UIDropDownMenu_SetText(dropDownFrame, text);
	else
		UIDropDownMenu_SetText(text, dropDownFrame);
	end
end

-- Same vanilla-vs-modern argument-order swap as Achiever_UIDropDownMenu_SetText
-- above, confirmed the same way (UIDropDownMenu_SetWidth's own internals
-- indexed a number where a frame was expected when called with the vanilla
-- (width, dropDownFrame) order on 1.14.2).
function Achiever_UIDropDownMenu_SetWidth(width, dropDownFrame)
	if WOW_PROJECT_ID then
		UIDropDownMenu_SetWidth(dropDownFrame, width);
	else
		UIDropDownMenu_SetWidth(width, dropDownFrame);
	end
end

-- Vanilla's PlaySound(soundName) took a string identifier; modern clients
-- (confirmed via live 1.14.2 testing: "Usage: PlaySound(soundKitID, ...)")
-- require a numeric SoundKitID instead and hard-error on a string. Rather
-- than maintain a name->SoundKitID mapping (risking the wrong sound playing
-- if any of this addon's 1.12 sound names don't have a clean modern
-- equivalent), pcall just skips the sound gracefully wherever the string
-- form isn't accepted -- losing a sound effect is far less costly than a
-- Lua error interrupting whatever triggered it (e.g. opening the panel).
function Achiever_PlaySound(soundName)
	pcall(PlaySound, soundName);
end

-- math.mod/mod's Lua-5.1-only polyfill lives in Compat_1_14_2.lua, not
-- here -- same reason as table.getn/getn above: `%` is invalid syntax under
-- 1.12.1's Lua 5.0 parser (5.0 only has the math.mod() function; `%` and
-- math.fmod were added in 5.1), so a runtime guard in this shared file
-- isn't enough to keep 1.12.1 loading.

-- Lua 5.0 has no bitwise operators or `bit` library. Every caller in the
-- achievement UI only tests a single power-of-two flag, so a generic
-- AND-via-division implementation is enough (no need for a full bit lib).
--
-- bit.band itself MUST be guarded the same way as every other polyfill in
-- this file (confirmed via the WotLK reference tree: core, always-loaded
-- Interface\FrameXML\AutoComplete.lua/EquipmentManager.lua/VehicleMenuBar.lua/
-- WatchFrame.lua all call bit.band directly) -- Classic Era ships a real,
-- native `bit` library, and `function bit.band(a, b) ... end` without a
-- guard doesn't create a new global, it overwrites the .band field on that
-- SAME shared table object every other file (Achiever's own or Blizzard's)
-- already holds a reference to. That's a far more pervasive taint vector
-- than any single achievement-specific global: bit.band is generic,
-- low-level, flag-checking plumbing used throughout core UI code, not just
-- achievement/objective-tracker code, which fits "blocked on literally any
-- click" better than anything else found so far.
bit = bit or {};
if not bit.band then
	function bit.band(a, b)
		local result = 0;
		local bitVal = 1;
		while a > 0 or b > 0 do
			local aBit = math.mod(a, 2);
			local bBit = math.mod(b, 2);
			if aBit == 1 and bBit == 1 then
				result = result + bitVal;
			end
			a = math.floor(a / 2);
			b = math.floor(b / 2);
			bitVal = bitVal * 2;
		end
		return result;
	end
end
