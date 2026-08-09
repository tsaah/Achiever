-- Options tab: Debug Mode, Show-patch-on-achievements, Force Patch, Language.
-- All persisted settings live directly on AchieverDB (character-specific),
-- read/written with a bare inline nil-check -- same convention every other
-- AchieverDB field already uses (trackerLocked, boundDefaultKeyV2, etc. --
-- see Achiever.lua/Tracker.lua), never eagerly defaulted at load time.

function AchievementFrameOptions_OnLoad(self)
	AchievementFrameOptions_Refresh();
end

function AchievementFrameOptions_OnShow(self)
	AchievementFrameOptions_Refresh();
end

-- Safe to call before AchieverDB exists yet (this pane's own OnLoad can fire
-- that early, since it's just XML frame creation) -- it's a no-op until
-- Achiever.lua's ADDON_LOADED handler has run; AchievementFrameOptions_OnShow
-- re-runs this once the player actually opens the tab, by which point
-- AchieverDB is always ready.
--
-- Also re-runs both dropdowns' UIDropDownMenu_Initialize: their own OnLoad
-- (AchievementFrameForcePatchDropDown_OnLoad / _LanguageDropDown_OnLoad)
-- already calls this once, but that fires at XML-parse time -- same
-- too-early load-order hazard as AchievementFrame_OnLoad's tab bug -- so
-- AchieverDB is still nil then and every _Initialize's "is this the saved
-- value" check falls through to the default entry. Re-initializing here,
-- well after ADDON_LOADED, is what makes the displayed text match the
-- actually-persisted forcePatch/language value after a reload.
function AchievementFrameOptions_Refresh()
	if (not AchieverDB) then return end
	AchievementFrameOptionsDebugModeCheckbox:SetChecked(AchieverDB.debugMode);
	AchievementFrameOptionsShowPatchCheckbox:SetChecked(AchieverDB.showPatchOnAchievements);
	AchievementFrameOptions_UpdateVisibility();
	UIDropDownMenu_Initialize(AchievementFrameOptionsForcePatchDropDown, AchievementFrameForcePatchDropDown_Initialize);
	UIDropDownMenu_Initialize(AchievementFrameOptionsLanguageDropDown, AchievementFrameLanguageDropDown_Initialize);
end

function AchievementFrameOptions_UpdateVisibility()
	if (AchieverDB and AchieverDB.debugMode) then
		AchievementFrameOptionsShowPatchCheckbox:Show();
		AchievementFrameOptionsForcePatchDropDown:Show();
	else
		AchievementFrameOptionsShowPatchCheckbox:Hide();
		AchievementFrameOptionsForcePatchDropDown:Hide();
	end
end

-- Debug Mode and Force Patch both change what Achiever_GetServerPatch()
-- returns (debug mode gates whether AchieverDB.forcePatch is honored at
-- all), which changes which categories/achievements IsCategoryPatchExcluded/
-- IsAchievementVisible let through -- so both need to rebuild the category
-- LIST itself (AchievementFrameCategories_GetCategoryList), not just
-- re-render whatever list was already built (AchievementFrameCategories_Update
-- alone does the latter -- see AchievementFrameBaseTab_OnClick in
-- AchievementUI.lua for the same paired-call pattern on tab switch).
function AchievementFrameOptions_RefreshPatchFiltering()
	AchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES);
	AchievementFrameCategories_Update();
	if (AchievementFrameAchievements:IsShown()) then
		AchievementFrameAchievements_ForceUpdate();
	end
end

function AchievementFrameDebugModeCheckbox_OnClick(self)
	AchieverDB.debugMode = self:GetChecked() and true or false;
	AchievementFrameOptions_UpdateVisibility();
	AchievementFrameOptions_RefreshPatchFiltering();
end

function AchievementFrameShowPatchCheckbox_OnClick(self)
	AchieverDB.showPatchOnAchievements = self:GetChecked() and true or false;
	if (AchievementFrameAchievements:IsShown()) then
		AchievementFrameAchievements_ForceUpdate();
	end
end

-- ===== Force Patch dropdown =====
-- Real UIDropDownMenuTemplate (Options.xml), driven by the same
-- UIDropDownMenu_* globals every Blizzard combobox uses. Two 1.12-specific
-- gotchas already documented at AchievementFrameFilterDropDown's site
-- (AchievementUI.lua) apply here too: UIDropDownMenu_Initialize's callback
-- receives only the numeric menu level (never self), so the dropdown frame
-- is referenced by its global name directly rather than trusting an
-- incoming parameter; and a clicked button's chosen value travels through
-- info.arg1, not info.value. Unlike that hand-rolled shape, the popup
-- menu's anchor doesn't need a manual self.relativeTo/xOffset/yOffset
-- workaround here -- ToggleDropDownMenu's default anchoring
-- (dropDownFrame:GetName().."Left", the template's own real texture
-- region) works out of the box once the frame actually has a "$parentLeft".
function AchievementFrameForcePatchDropDown_OnLoad(self)
	UIDropDownMenu_Initialize(self, AchievementFrameForcePatchDropDown_Initialize);
	UIDropDownMenu_SetWidth(150, self);
end

function AchievementFrameForcePatchDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	info.text = ACHIEVER_FORCE_PATCH_AUTO;
	info.value = "auto";
	info.arg1 = "auto";
	info.func = AchievementFrameForcePatchDropDownButton_OnClick;
	if (not (AchieverDB and AchieverDB.forcePatch)) then
		info.checked = 1;
		UIDropDownMenu_SetText(ACHIEVER_FORCE_PATCH_AUTO, AchievementFrameOptionsForcePatchDropDown);
	else
		info.checked = nil;
	end
	UIDropDownMenu_AddButton(info);

	for _, patch in ipairs(Achiever_GetAvailablePatches()) do
		info.text = tostring(patch);
		info.value = patch;
		info.arg1 = patch;
		info.func = AchievementFrameForcePatchDropDownButton_OnClick;
		if (AchieverDB and AchieverDB.forcePatch == patch) then
			info.checked = 1;
			UIDropDownMenu_SetText(tostring(patch), AchievementFrameOptionsForcePatchDropDown);
		else
			info.checked = nil;
		end
		UIDropDownMenu_AddButton(info);
	end
end

function AchievementFrameForcePatchDropDownButton_OnClick(value)
	AchievementFrame_SetForcePatch(value);
end

function AchievementFrame_SetForcePatch(value)
	if (value == "auto") then
		AchieverDB.forcePatch = nil;
		UIDropDownMenu_SetText(ACHIEVER_FORCE_PATCH_AUTO, AchievementFrameOptionsForcePatchDropDown);
	else
		AchieverDB.forcePatch = value;
		UIDropDownMenu_SetText(tostring(value), AchievementFrameOptionsForcePatchDropDown);
	end
	AchievementFrameOptions_RefreshPatchFiltering();
end

-- ===== Language dropdown =====
-- Same real UIDropDownMenuTemplate shape again. Selecting a language only
-- takes effect after /reload -- each Achiever-<locale> addon already
-- decided whether to activate at its own load time, before this click
-- handler could ever run (see Achiever.lua's ADDON_LOADED handler, which
-- re-applies AchieverDB.language to Achiever_ForceLocale early on every
-- subsequent load).
function AchievementFrameLanguageDropDown_OnLoad(self)
	UIDropDownMenu_Initialize(self, AchievementFrameLanguageDropDown_Initialize);
	UIDropDownMenu_SetWidth(150, self);
end

function AchievementFrameLanguageDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	info.text = ACHIEVER_LANGUAGE_DEFAULT;
	info.value = "default";
	info.arg1 = "default";
	info.func = AchievementFrameLanguageDropDownButton_OnClick;
	if (not (AchieverDB and AchieverDB.language)) then
		info.checked = 1;
		UIDropDownMenu_SetText(ACHIEVER_LANGUAGE_DEFAULT, AchievementFrameOptionsLanguageDropDown);
	else
		info.checked = nil;
	end
	UIDropDownMenu_AddButton(info);

	for _, locale in ipairs(Achiever_GetAvailableLocales()) do
		info.text = locale;
		info.value = locale;
		info.arg1 = locale;
		info.func = AchievementFrameLanguageDropDownButton_OnClick;
		if (AchieverDB and AchieverDB.language == locale) then
			info.checked = 1;
			UIDropDownMenu_SetText(locale, AchievementFrameOptionsLanguageDropDown);
		else
			info.checked = nil;
		end
		UIDropDownMenu_AddButton(info);
	end
end

function AchievementFrameLanguageDropDownButton_OnClick(value)
	AchievementFrame_SetLanguage(value);
end

function AchievementFrame_SetLanguage(value)
	if (value == "default") then
		AchieverDB.language = nil;
		UIDropDownMenu_SetText(ACHIEVER_LANGUAGE_DEFAULT, AchievementFrameOptionsLanguageDropDown);
	else
		AchieverDB.language = value;
		UIDropDownMenu_SetText(value, AchievementFrameOptionsLanguageDropDown);
	end
	Achiever_ForceLocale = AchieverDB.language;
	DEFAULT_CHAT_FRAME:AddMessage(ACHIEVER_LANGUAGE_RELOAD_NOTICE);
end
