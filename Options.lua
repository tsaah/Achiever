-- Options tab: Debug Mode, Show-patch-on-achievements, Force Patch, Language.
-- All persisted settings live directly on AchieverDB (character-specific),
-- read/written with a bare inline nil-check -- same convention every other
-- AchieverDB field already uses (trackerLocked, boundDefaultKeyV2, etc. --
-- see Achiever.lua/Tracker.lua), never eagerly defaulted at load time.

function AchieverAchievementFrameOptions_OnLoad(self)
	AchieverAchievementFrameOptions_Refresh();
end

function AchieverAchievementFrameOptions_OnShow(self)
	AchieverAchievementFrameOptions_Refresh();

	-- AchieverAchievementFrameOptionsDebugModeCheckbox/ShowPatchCheckbox's own
	-- inline <OnClick> (Options.xml) relies on this/self binding for that
	-- script instance -- same class of issue already found and fixed for
	-- AchieverAchievementFrameTab3 (AchievementUI.lua's tab loop): both are
	-- declared in this same Options.xml, which loads later in Achiever.toc
	-- than AchievementUI.xml, giving more opportunity for another addon's
	-- most-recently-run script to leave something in the shared `this`
	-- global before this checkbox's own OnClick fires. Overriding with
	-- SetScript here uses a direct global reference, sidestepping the
	-- problem entirely -- same fix shape as the tab buttons. Gated so this
	-- only actually attaches once, not every time this pane shows.
	if (not AchieverAchievementFrameOptionsDebugModeCheckbox.reliableClickAttached) then
		AchieverAchievementFrameOptionsDebugModeCheckbox.reliableClickAttached = true;
		AchieverAchievementFrameOptionsDebugModeCheckbox:SetScript("OnClick", function()
			AchieverAchievementFrameDebugModeCheckbox_OnClick(AchieverAchievementFrameOptionsDebugModeCheckbox);
		end);
	end
	if (not AchieverAchievementFrameOptionsShowPatchCheckbox.reliableClickAttached) then
		AchieverAchievementFrameOptionsShowPatchCheckbox.reliableClickAttached = true;
		AchieverAchievementFrameOptionsShowPatchCheckbox:SetScript("OnClick", function()
			AchieverAchievementFrameShowPatchCheckbox_OnClick(AchieverAchievementFrameOptionsShowPatchCheckbox);
		end);
	end
	if (not AchieverAchievementFrameOptionsSyncButton.reliableClickAttached) then
		AchieverAchievementFrameOptionsSyncButton.reliableClickAttached = true;
		AchieverAchievementFrameOptionsSyncButton:SetScript("OnClick", function()
			Achiever_RequestSync();
		end);
	end
end

-- Safe to call before AchieverDB exists yet (this pane's own OnLoad can fire
-- that early, since it's just XML frame creation) -- it's a no-op until
-- Achiever.lua's ADDON_LOADED handler has run; AchieverAchievementFrameOptions_OnShow
-- re-runs this once the player actually opens the tab, by which point
-- AchieverDB is always ready.
--
-- Also re-runs both dropdowns' UIDropDownMenu_Initialize: their own OnLoad
-- (AchieverAchievementFrameForcePatchDropDown_OnLoad / _LanguageDropDown_OnLoad)
-- already calls this once, but that fires at XML-parse time -- same
-- too-early load-order hazard as AchieverAchievementFrame_OnLoad's tab bug -- so
-- AchieverDB is still nil then and every _Initialize's "is this the saved
-- value" check falls through to the default entry. Re-initializing here,
-- well after ADDON_LOADED, is what makes the displayed text match the
-- actually-persisted forcePatch/language value after a reload.
function AchieverAchievementFrameOptions_Refresh()
	if (not AchieverDB) then return end
	AchieverAchievementFrameOptionsDebugModeCheckbox:SetChecked(AchieverDB.debugMode);
	AchieverAchievementFrameOptionsShowPatchCheckbox:SetChecked(AchieverDB.showPatchOnAchievements);
	AchieverAchievementFrameOptions_UpdateVisibility();
	UIDropDownMenu_Initialize(AchieverAchievementFrameOptionsForcePatchDropDown, AchieverAchievementFrameForcePatchDropDown_Initialize);
	UIDropDownMenu_Initialize(AchieverAchievementFrameOptionsLanguageDropDown, AchieverAchievementFrameLanguageDropDown_Initialize);
end

function AchieverAchievementFrameOptions_UpdateVisibility()
	if (AchieverDB and AchieverDB.debugMode) then
		AchieverAchievementFrameOptionsShowPatchCheckbox:Show();
		AchieverAchievementFrameOptionsForcePatchDropDown:Show();
	else
		AchieverAchievementFrameOptionsShowPatchCheckbox:Hide();
		AchieverAchievementFrameOptionsForcePatchDropDown:Hide();
	end
end

-- Debug Mode and Force Patch both change what Achiever_GetServerPatch()
-- returns (debug mode gates whether AchieverDB.forcePatch is honored at
-- all), which changes which categories/achievements IsCategoryPatchExcluded/
-- IsAchievementVisible let through -- so both need to rebuild the category
-- LIST itself (AchieverAchievementFrameCategories_GetCategoryList), not just
-- re-render whatever list was already built (AchieverAchievementFrameCategories_Update
-- alone does the latter -- see AchieverAchievementFrameBaseTab_OnClick in
-- AchievementUI.lua for the same paired-call pattern on tab switch).
function AchieverAchievementFrameOptions_RefreshPatchFiltering()
	AchieverAchievementFrameCategories_GetCategoryList(ACHIEVEMENTUI_CATEGORIES);
	AchieverAchievementFrameCategories_Update();
	if (AchieverAchievementFrameAchievements:IsShown()) then
		AchieverAchievementFrameAchievements_ForceUpdate();
	end
end

function AchieverAchievementFrameDebugModeCheckbox_OnClick(self)
	if (type(self) ~= "table" or not self.GetChecked) then return; end

	AchieverDB.debugMode = self:GetChecked() and true or false;
	AchieverAchievementFrameOptions_UpdateVisibility();
	-- debugMode gates whether AchieverDB.forcePatch is honored at all (Achiever_GetServerPatch),
	-- so toggling it can change the effective patch just as much as the dropdown itself --
	-- same rebuild need as AchieverAchievementFrame_SetForcePatch above.
	Achiever_RebuildIndices();
	AchieverAchievementFrameOptions_RefreshPatchFiltering();
	-- Immediately shows/hides raw ACHI protocol traffic in chat to match the
	-- new setting (Achiever.lua) -- no need to relog for this to take effect.
	Achiever_UpdateChannelChatVisibility();
end

function AchieverAchievementFrameShowPatchCheckbox_OnClick(self)
	if (type(self) ~= "table" or not self.GetChecked) then return; end

	AchieverDB.showPatchOnAchievements = self:GetChecked() and true or false;
	if (AchieverAchievementFrameAchievements:IsShown()) then
		AchieverAchievementFrameAchievements_ForceUpdate();
	end
end

-- ===== Force Patch dropdown =====
-- Real UIDropDownMenuTemplate (Options.xml), driven by the same
-- UIDropDownMenu_* globals every Blizzard combobox uses. Two 1.12-specific
-- gotchas already documented at AchieverAchievementFrameFilterDropDown's site
-- (AchievementUI.lua) apply here too: UIDropDownMenu_Initialize's callback
-- receives only the numeric menu level (never self), so the dropdown frame
-- is referenced by its global name directly rather than trusting an
-- incoming parameter; and a clicked button's chosen value travels through
-- info.arg1, not info.value. Unlike that hand-rolled shape, the popup
-- menu's anchor doesn't need a manual self.relativeTo/xOffset/yOffset
-- workaround here -- ToggleDropDownMenu's default anchoring
-- (dropDownFrame:GetName().."Left", the template's own real texture
-- region) works out of the box once the frame actually has a "$parentLeft".
function AchieverAchievementFrameForcePatchDropDown_OnLoad(self)
	-- Guard against a non-Frame self -- see AchievementIcon_OnLoad's
	-- matching guard comment (AchievementUI.lua, top of file).
	if (type(self) ~= "table" or not self.GetName) then return; end

	UIDropDownMenu_Initialize(self, AchieverAchievementFrameForcePatchDropDown_Initialize);
	Achiever_UIDropDownMenu_SetWidth(150, self);
end

function AchieverAchievementFrameForcePatchDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	info.text = ACHIEVER_FORCE_PATCH_AUTO;
	info.value = "auto";
	info.arg1 = "auto";
	info.func = AchieverAchievementFrameForcePatchDropDownButton_OnClick;
	if (not (AchieverDB and AchieverDB.forcePatch)) then
		info.checked = 1;
		Achiever_UIDropDownMenu_SetText(ACHIEVER_FORCE_PATCH_AUTO, AchieverAchievementFrameOptionsForcePatchDropDown);
	else
		info.checked = nil;
	end
	UIDropDownMenu_AddButton(info);

	for _, patch in ipairs(Achiever_GetAvailablePatches()) do
		info.text = tostring(patch);
		info.value = patch;
		info.arg1 = patch;
		info.func = AchieverAchievementFrameForcePatchDropDownButton_OnClick;
		if (AchieverDB and AchieverDB.forcePatch == patch) then
			info.checked = 1;
			Achiever_UIDropDownMenu_SetText(tostring(patch), AchieverAchievementFrameOptionsForcePatchDropDown);
		else
			info.checked = nil;
		end
		UIDropDownMenu_AddButton(info);
	end
end

-- info.func is called by Blizzard's UIDropDownMenu internals as
-- func(self, arg1, arg2, checked) -- self is the clicked BUTTON widget, not
-- the chosen value (that's arg1, per this file's own header comment on why
-- info.value can't be trusted here). A single-parameter `(value)` signature
-- silently bound to that button instead, so AchieverDB.forcePatch ended up
-- holding a dropdown-button table instead of a patch number -- confirmed
-- via live 1.14.2 testing ("attempt to compare table with number" in
-- Router.lua, the corrupted value's own field names -- Highlight/Icon/
-- invisibleButton -- matching a UIDropDownMenuButtonTemplate instance).
function AchieverAchievementFrameForcePatchDropDownButton_OnClick(self, value)
	AchieverAchievementFrame_SetForcePatch(value);
end

function AchieverAchievementFrame_SetForcePatch(value)
	if (value == "auto") then
		AchieverDB.forcePatch = nil;
		Achiever_UIDropDownMenu_SetText(ACHIEVER_FORCE_PATCH_AUTO, AchieverAchievementFrameOptionsForcePatchDropDown);
	else
		AchieverDB.forcePatch = value;
		Achiever_UIDropDownMenu_SetText(tostring(value), AchieverAchievementFrameOptionsForcePatchDropDown);
	end
	-- Retirement's category/chain-splice overrides are baked into the indices at rebuild
	-- time (see Achiever_RebuildIndices), so changing the effective patch here needs an
	-- explicit rebuild -- unlike the plain visibility filtering RefreshPatchFiltering below
	-- already handles live.
	Achiever_RebuildIndices();
	AchieverAchievementFrameOptions_RefreshPatchFiltering();
end

-- ===== Language dropdown =====
-- Same real UIDropDownMenuTemplate shape again. Selecting a language only
-- takes effect on the next load -- each Achiever-<locale> addon already
-- decided whether to activate at its own load time, before this click
-- handler could ever run (see Achiever.lua's ADDON_LOADED handler, which
-- re-applies AchieverDB.language to Achiever_ForceLocale early on every
-- subsequent load) -- so AchieverAchievementFrame_SetLanguage below triggers a
-- ReloadUI() itself rather than just telling the player to /reload.
function AchieverAchievementFrameLanguageDropDown_OnLoad(self)
	if (type(self) ~= "table" or not self.GetName) then return; end

	UIDropDownMenu_Initialize(self, AchieverAchievementFrameLanguageDropDown_Initialize);
	Achiever_UIDropDownMenu_SetWidth(150, self);
end

function AchieverAchievementFrameLanguageDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	info.text = ACHIEVER_LANGUAGE_DEFAULT;
	info.value = "default";
	info.arg1 = "default";
	info.func = AchieverAchievementFrameLanguageDropDownButton_OnClick;
	if (not (AchieverDB and AchieverDB.language)) then
		info.checked = 1;
		Achiever_UIDropDownMenu_SetText(ACHIEVER_LANGUAGE_DEFAULT, AchieverAchievementFrameOptionsLanguageDropDown);
	else
		info.checked = nil;
	end
	UIDropDownMenu_AddButton(info);

	for _, locale in ipairs(Achiever_GetAvailableLocales()) do
		info.text = locale;
		info.value = locale;
		info.arg1 = locale;
		info.func = AchieverAchievementFrameLanguageDropDownButton_OnClick;
		if (AchieverDB and AchieverDB.language == locale) then
			info.checked = 1;
			Achiever_UIDropDownMenu_SetText(locale, AchieverAchievementFrameOptionsLanguageDropDown);
		else
			info.checked = nil;
		end
		UIDropDownMenu_AddButton(info);
	end
end

-- See AchieverAchievementFrameForcePatchDropDownButton_OnClick's matching
-- comment -- same bug, same fix: info.func receives (self, arg1, ...), not
-- just the chosen value as its first argument.
function AchieverAchievementFrameLanguageDropDownButton_OnClick(self, value)
	AchieverAchievementFrame_SetLanguage(value);
end

function AchieverAchievementFrame_SetLanguage(value)
	local newLanguage = (value ~= "default") and value or nil;
	if (newLanguage == AchieverDB.language) then
		-- Already the active language (e.g. re-clicking the current
		-- selection) -- nothing changed, so nothing to reload.
		return;
	end
	AchieverDB.language = newLanguage;
	if (value == "default") then
		Achiever_UIDropDownMenu_SetText(ACHIEVER_LANGUAGE_DEFAULT, AchieverAchievementFrameOptionsLanguageDropDown);
	else
		Achiever_UIDropDownMenu_SetText(value, AchieverAchievementFrameOptionsLanguageDropDown);
	end
	ReloadUI();
end
