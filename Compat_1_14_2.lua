-- Per-client compat shim, loaded only by Achiever_Vanilla.toc (never by
-- Achiever.toc) -- see Compat_1_12_1.lua's header comment for why this is a
-- separate per-client file rather than a runtime-guarded block in a shared
-- file: `#` and `%` are invalid syntax under 1.12.1's Lua 5.0 parser, so
-- these definitions can't exist in any file 1.12.1 also loads, guarded or
-- not, without breaking that client at load time (Lua parses a whole
-- chunk, including unreached branches, before executing any of it).
--
-- Lua 5.1 (this client's runtime) removed table.getn/getn and math.mod/mod
-- entirely, replaced by the `#` operator and the `%` operator (5.0 only had
-- math.mod() as a function; `%` itself didn't exist as an operator until
-- 5.1). Every caller elsewhere in this addon (Router.lua/AchievementUI.lua/
-- Tracker.lua/Constants.lua's bit.band/etc.) calls table.getn/math.mod
-- directly, matching 1.12.1's native Lua 5.0 API, so these polyfills exist
-- purely to make those same calls keep working here rather than rewriting
-- every call site to branch on client version.
--
-- Still guarded, even though this file's client-exclusivity is what
-- actually fixes the original parse-time bug (see above) -- matches this
-- addon's established never-overwrite-unconditionally style elsewhere
-- (Constants.lua's GameTooltip_ShowStatusBar/IsModifiedClick/etc.), in case
-- some other addon or a future client update ever provides its own.
if not table.getn then
	function table.getn(t)
		return #t;
	end
end
getn = getn or table.getn;

if not math.mod then
	function math.mod(a, b)
		return a % b;
	end
end
mod = mod or math.mod;
