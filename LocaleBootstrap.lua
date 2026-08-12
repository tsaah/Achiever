-- LocaleBootstrap.lua
-- Loads the correct Achiever-<locale> addon as early as possible -- before
-- any chrome-creating file below this one in Achiever.toc (Tracker.lua,
-- AchievementUI.lua/.xml, Options.lua/.xml) -- so text="GLOBAL_NAME" XML
-- attributes and one-time Lua table literals (e.g. AchievementUI.lua's
-- AchievementFrameFilters) see the translated value instead of Strings.lua's
-- still-English default. Strings.lua and Router.lua (which builds Achiever.db
-- from the Data\*.lua files) have both already loaded by this point in the
-- .toc list, so both the chrome globals a locale addon overwrites and the
-- Achiever.db entries a locale addon patches already exist.
--
-- Deliberately GetLocale()-only, NOT AchieverDB-aware: AchieverDB (like every
-- other SavedVariables/SavedVariablesPerCharacter global declared in
-- Achiever.toc) is only populated by the client once ALL of "Achiever"'s own
-- files -- through Achiever.lua, the very last one -- have finished loading,
-- immediately before ADDON_LOADED fires for "Achiever". That's the same rule
-- Router.lua's own comment above Achiever_RebuildIndices() documents for
-- AchieverAccountProgress/AchieverCharacterProgress; AchieverDB is declared
-- via the identical "## SavedVariablesPerCharacter" directive, so it's no
-- exception. Reading AchieverDB.language here would always see nil.
--
-- The Options-panel language override is instead resolved later, correctly,
-- in Achiever.lua's ADDON_LOADED handler -- which also re-stamps the handful
-- of chrome widgets that were already created before that point could run
-- (see Achiever_ReapplyLocaleChrome in AchievementUI.lua).
Achiever_BootstrapLocale = GetLocale();
if (Achiever_BootstrapLocale == "enUS") then
	Achiever_BootstrapLocale = nil;
end

if (Achiever_BootstrapLocale) then
	Achiever_ForceLocale = Achiever_BootstrapLocale;
	LoadAddOn("Achiever-" .. Achiever_BootstrapLocale);
end
