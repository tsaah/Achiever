-- Achievement flag/criteria constants and a bitwise-AND polyfill.
-- Real WotLK 3.3.5 values, pulled from Blizzard's FrameXML\Constants.lua --
-- not present in 1.12 at all, since achievements didn't exist yet.

-- The client's own locale, e.g. "zhCN" -- a real 1.12 client only ever
-- reports one of enUS/koKR/frFR/deDE/zhCN/zhTW/esES/esMX (ruRU/ptBR/itIT/
-- jaJP didn't exist as client locale slots until the 2.1.0/TBC pre-patch).
-- Not consulted by Achiever itself -- a locale-override addon (e.g.
-- Achiever-zhCN) checks GetLocale() directly before overwriting any text --
-- this is just a simple, always-available piece of info for other code
-- (and a future settings UI) to read.
AchieverLocale = GetLocale();

CRITERIA_TYPE_ACHIEVEMENT = 8;

ACHIEVEMENT_FLAGS_STATISTIC = 1;
ACHIEVEMENT_FLAGS_HIDDEN = 2;
ACHIEVEMENT_FLAGS_SUMM = 8;
ACHIEVEMENT_FLAGS_MAX_USED = 16;
ACHIEVEMENT_FLAGS_REQ_COUNT = 32;
ACHIEVEMENT_FLAGS_HAS_PROGRESS_BAR = 128;
NUM_ACHIEVEMENT_FLAGS = 3;

ACHIEVEMENT_CRITERIA_PROGRESS_BAR = 1;
ACHIEVEMENT_CRITERIA_HIDDEN = 2;
NUM_ACHIEVEMENT_CRITERIA_FLAGS = 2;

-- Not part of Blizzard's client-side Constants.lua (money formatting is
-- decided server-side in the real game and handed to the addon as an
-- already-formatted GetStatistic string) -- backported here from the
-- server-side AchievementCriteriaFlags enum (mangos/TrinityCore/vmangos:
-- ACHIEVEMENT_CRITERIA_FLAG_MONEY_COUNTER = 0x20) so Router.lua's GetStatistic
-- mock can tell which stats are gold amounts. Confirmed against
-- Data\Criteria.lua: every criteria whose description reads like a gold
-- total/spend (types 59/60/62/63/65/66/67/80/83/85/86 -- vendor gold, respec
-- cost, travel cost, postage, quest-reward gold, gold looted, auction
-- gold/bids/sales, highest gold owned) carries flags=32 and nothing else in
-- that data does.
ACHIEVEMENT_CRITERIA_MONEY_COUNTER = 32;

WATCHFRAME_MAXACHIEVEMENTS = 10;

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
-- (Tracker.lua) and as GetAchievementCriteriaInfo's underlying
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
	if (not frame or not frame:IsVisible()) then return false end
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom();
	if (not (left and right and top and bottom)) then return false end
	local x, y = GetCursorPosition();
	local scale = frame:GetEffectiveScale();
	x, y = x / scale, y / scale;
	return x >= left and x <= right and y >= bottom and y <= top;
end

function GameTooltip_ShowStatusBar(tooltip, min, max, value, text)
	tooltip:AddLine(" ");
	tooltip:AddLine(text or (value .. " / " .. max), 1, 1, 1);
end

-- `IsModifiedClick` (added ~2.0) doesn't exist in 1.12 -- there's no
-- user-configurable "modified click" binding system at all here, only the
-- hardcoded shift-click-to-link behavior other vanilla frames already use.
-- The achievement UI only ever asks about "CHATLINK", so that's the only
-- click type this maps to a real modifier; anything else (e.g. the
-- WotLK-only QUESTWATCHTOGGLE binding type) simply isn't a thing in 1.12.
function IsModifiedClick(clickType)
	if (clickType and clickType ~= "CHATLINK") then
		return false;
	end
	return IsShiftKeyDown();
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
	local tabName = tab:GetName();
	local buttonMiddle = _G[tabName.."Middle"];
	local buttonMiddleDisabled = _G[tabName.."MiddleDisabled"];
	local sideWidths = 2 * _G[tabName.."Left"]:GetWidth();
	local tabText = _G[tabName.."Text"];
	local width, tabWidth;
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
function UIDropDownMenu_CreateInfo()
	return {};
end

-- Lua 5.0 has no bitwise operators or `bit` library. Every caller in the
-- achievement UI only tests a single power-of-two flag, so a generic
-- AND-via-division implementation is enough (no need for a full bit lib).
bit = bit or {};
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
