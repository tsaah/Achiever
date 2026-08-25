-- Achiever.lua
-- Scaffold: a Y keybind and a minimap button both toggle the
-- achievement window; the minimap button's own position persists across
-- sessions via AchieverDB.
--
-- The keybind is a named action ("ACHIEVER_TOGGLE") declared in Bindings.xml,
-- the same pattern aux-addon and TurtleCalendar use: the file must NOT be
-- listed in Achiever.toc, since that's what makes the client auto-load it
-- through its dedicated Bindings parser (which understands <Binding>) rather
-- than the generic FrameXML/UI-XML loader (which doesn't -- MessageBox's
-- Bindings.xml *is* listed in MessageBox.toc and throws "Unknown frame type:
-- Binding" as a result). Named bindings also show up in the standard Key
-- Bindings UI under the "Achiever" header, unlike a CLICK-target binding.

local MINIMAP_BUTTON_SIZE = 31
local MINIMAP_ICON_SIZE = 20
local MINIMAP_BORDER_SIZE = 53

-- Toggle used by both the keybind (Bindings.xml) and the minimap button's
-- left-click: opens the real achievement window.
function Achiever_Toggle()
	if AchieverAchievementFrame_ToggleAchieverAchievementFrame then
		AchieverAchievementFrame_ToggleAchieverAchievementFrame()
	end
end

-- Makes the (otherwise fixed-position) achievement window draggable, with
-- its position persisted to AchieverDB the same way the minimap button's
-- is. Done here rather than in AchievementUI.xml/.lua so those stay a
-- faithful port of Blizzard's files. ShowUIPanel's own panel-management re-anchors the frame
-- on every show (per its UIPanelWindows entry), so the saved position has to
-- be re-applied *after* that happens -- since this client has no
-- hooksecurefunc, that means wrapping the original AchieverAchievementFrame_OnShow
-- rather than hooking it.
--
-- AchieverAchievementFrameHeader (the title/watermark strip) is a separate child
-- frame with enableMouse="true" of its own, positioned right over the top of
-- AchieverAchievementFrame -- exactly where someone would naturally grab to drag.
-- That intercepts the mouse there, so AchieverAchievementFrame's own OnDragStart
-- never fires for it; the header needs its own drag handlers that move the
-- *parent* frame, not itself.
local function Achiever_MakeAchieverAchievementFrameMovable()
	local function SaveAchieverAchievementFramePosition()
		local point, _, relativePoint, x, y = AchieverAchievementFrame:GetPoint()
		AchieverDB.achievementFramePos = { point = point, relativePoint = relativePoint, x = x, y = y }
	end

	-- IsShown() guard on both OnDragStart handlers: confirmed via live 1.14.2
	-- testing that clicking in the screen region the panel occupies WHILE
	-- IT'S HIDDEN still triggered a drag-start (StartMoving on a frame
	-- that's not actually visible/interactable), which then never got a
	-- matching OnDragStop -- the engine treats the mouse button as
	-- permanently held until /reload. RegisterForDrag apparently doesn't
	-- respect hidden state as reliably here as ordinary click handling does;
	-- an explicit check is cheap insurance regardless of the exact mechanism.
	AchieverAchievementFrame:SetMovable(true)
	AchieverAchievementFrame:RegisterForDrag("LeftButton")
	AchieverAchievementFrame:SetScript("OnDragStart", function()
		if not AchieverAchievementFrame:IsShown() then return end
		AchieverAchievementFrame:StartMoving()
	end)
	AchieverAchievementFrame:SetScript("OnDragStop", function()
		AchieverAchievementFrame:StopMovingOrSizing()
		SaveAchieverAchievementFramePosition()
	end)

	AchieverAchievementFrameHeader:EnableMouse(true)
	AchieverAchievementFrameHeader:RegisterForDrag("LeftButton")
	AchieverAchievementFrameHeader:SetScript("OnDragStart", function()
		if not AchieverAchievementFrame:IsShown() then return end
		AchieverAchievementFrame:StartMoving()
	end)
	AchieverAchievementFrameHeader:SetScript("OnDragStop", function()
		AchieverAchievementFrame:StopMovingOrSizing()
		SaveAchieverAchievementFramePosition()
	end)

	local function RepositionAchieverAchievementFrame()
		if AchieverDB.achievementFramePos then
			local p = AchieverDB.achievementFramePos
			AchieverAchievementFrame:ClearAllPoints()
			AchieverAchievementFrame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
		end
	end

	-- Same taint-safe split as Achiever_HookItemRef above: reassigning the
	-- global's value (below, 1.12.1-only) is exactly the pattern confirmed to
	-- taint every subsequent call to it on modern clients, even though this
	-- particular global is Achiever's own rather than a real Blizzard one --
	-- issecurevariable marks any addon-code write to ANY global as
	-- insecure/addon-owned regardless of whose name it is, and this frame's
	-- OnShow can run through a secure/hardware-event context (the Y
	-- keybind), so a tainted value here can propagate the same way the
	-- SetItemRef case did. hooksecurefunc only appends a callback without
	-- replacing the original's identity, which is what keeps that path clean.
	if WOW_PROJECT_ID then
		hooksecurefunc("AchieverAchievementFrame_OnShow", RepositionAchieverAchievementFrame)
	else
		local originalOnShow = AchieverAchievementFrame_OnShow
		AchieverAchievementFrame_OnShow = function()
			originalOnShow()
			RepositionAchieverAchievementFrame()
		end
	end
end

-- pfUI-family convention (matches pfQuest/menu.lua's pfQuestIcon exactly):
-- parented directly to Minimap, freely positioned (not locked to an orbit
-- angle), and only actually draggable while Shift is held -- so a plain
-- left-click never accidentally relocates the button.
local function Achiever_CreateMinimapButton()
	local button = CreateFrame("Button", "AchieverMinimapButton", Minimap)
	button:SetWidth(MINIMAP_BUTTON_SIZE)
	button:SetHeight(MINIMAP_BUTTON_SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetClampedToScreen(true)
	button:SetMovable(true)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(MINIMAP_ICON_SIZE)
	icon:SetHeight(MINIMAP_ICON_SIZE)
	icon:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-TinyShield")
	-- The source .blp is a 32x32 canvas but the shield art only fills its
	-- upper-left 20x18 px (the rest is transparent padding); without this
	-- crop the whole canvas gets stretched into the icon square, so the
	-- shield renders small, top-anchored, and washed out by empty space.
	icon:SetTexCoord(0, 0.625, 0, 0.5625)
	icon:SetPoint("CENTER", button, "CENTER", 1, 1)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetWidth(MINIMAP_BORDER_SIZE)
	border:SetHeight(MINIMAP_BORDER_SIZE)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	button:SetScript("OnClick", function()
		-- Modern-client (1.14.2+) equivalent of the 1.12.1 PLAYER_LOGIN
		-- default-bind below (see boundDefaultKeyV2's comment for why
		-- SetBinding/SaveBindings can't be attempted unconditionally at
		-- login there -- they need a real hardware-event-driven secure
		-- execution context, which PLAYER_LOGIN's own timeline doesn't
		-- have). A genuine button click does qualify, and this is the one
		-- click every new character makes anyway (to open the window), so
		-- this piggybacks the one-time attempt onto it instead of asking
		-- for a separate action.
		if WOW_PROJECT_ID and not AchieverDB.boundDefaultKeyModern then
			if not GetBindingKey("ACHIEVER_TOGGLE") then
				SetBinding("Y", "ACHIEVER_TOGGLE")
				local bindingSet = GetCurrentBindingSet()
				if bindingSet then
					SaveBindings(bindingSet)
				end
			end
			AchieverDB.boundDefaultKeyModern = true
		end

		Achiever_Toggle()
	end)

	button:SetScript("OnEnter", function(frame)
		local this = frame or this
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_MINIMAP_TOOLTIP_TITLE)
		GameTooltip:AddLine(ACHIEVER_MINIMAP_TOOLTIP_LINE1, 1, 1, 1)
		GameTooltip:AddLine(ACHIEVER_MINIMAP_TOOLTIP_LINE2, 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	button:SetScript("OnDragStart", function(frame)
		local this = frame or this
		if IsShiftKeyDown() then
			this:StartMoving()
		end
	end)

	button:SetScript("OnDragStop", function(frame)
		local this = frame or this
		this:StopMovingOrSizing()
		local point, _, relativePoint, x, y = this:GetPoint()
		AchieverDB.minimapButtonPos = { point = point, relativePoint = relativePoint, x = x, y = y }
	end)

	if AchieverDB.minimapButtonPos then
		local p = AchieverDB.minimapButtonPos
		button:ClearAllPoints()
		button:SetPoint(p.point, Minimap, p.relativePoint, p.x, p.y)
	else
		button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
	end
end

-- 1.12's real SetItemRef (Interface\FrameXML\ItemRef.lua) only special-cases
-- "player" links; every other type falls through to
-- ItemRefTooltip:SetHyperlink(link), which has no idea what an "achievement"
-- link is (that type doesn't exist until WotLK). Wrapped, not replaced, so
-- item/spell/quest/player links keep working exactly as before -- only
-- "achievement:<id>:..." links get intercepted here. Matches the
-- ShowUIPanel-then-select pattern AlertFrames.lua's own achievement-toast
-- click handler already uses.
--
-- CONFIRMED ROOT CAUSE (live 1.14.2 testing via issecurevariable("SetItemRef")
-- right after reproducing the action-bar block: returned false, "Achiever" --
-- the only tainted global found out of every other suspect checked, all of
-- which came back clean after this session's other fixes). The save-then-
-- reassign pattern below replaces the global's VALUE with an Achiever-owned
-- closure, which is what marks it insecure -- every subsequent real item/
-- spell/quest link click (not just achievement links) then runs through
-- Achiever-tainted execution before falling through to the real handler.
-- hooksecurefunc (TBC+, so 1.12.1 still can't use it -- CLAUDE.md) doesn't
-- replace the target's identity/value at all, only appends a secure-context
-- callback that runs after the original -- confirmed by Blizzard's own docs
-- as the standard taint-safe way to observe (not replace) a function. It
-- can't skip the original's own execution the way the 1.12.1 branch below
-- does, but that's harmless here: "achievement:<id>" is never a link
-- Blizzard's own SetItemRef could resolve to anything meaningful anyway
-- (this exact link type doesn't exist pre-WotLK and this server's real
-- achievement UI never loads), so letting it run first and effectively no-op
-- before this fires is a non-issue.
local function Achiever_HookItemRef()
	if WOW_PROJECT_ID then
		hooksecurefunc("SetItemRef", function(link, text, button)
			local _, _, id = string.find(link, "^achievement:(%d+)")
			if id then
				ShowUIPanel(AchieverAchievementFrame)
				AchieverAchievementFrame_SelectAchievement(tonumber(id))
			end
		end)
		return
	end

	local originalSetItemRef = SetItemRef
	SetItemRef = function(link, text, button)
		local _, _, id = string.find(link, "^achievement:(%d+)")
		if id then
			ShowUIPanel(AchieverAchievementFrame)
			AchieverAchievementFrame_SelectAchievement(tonumber(id))
			return
		end
		originalSetItemRef(link, text, button)
	end
end

-- Handshake: ping the server with our last-known progress-sync timestamp so
-- it can reply with anything newer. Sent via SendChatMessage(..., "WHISPER",
-- ...) on both clients -- confirmed this server's HandleAddonMessage
-- (AchievementMgr.cpp) intercepts any recognized "ACHI\t..." message BEFORE
-- whisper-delivery/target-validation runs (it's called from
-- HandleChatMessageOpcode's non-LANG_ADDON branch, ahead of the type-switch
-- that would resolve a real whisper target), so the whisper target doesn't
-- need to exist or be online and this never actually reaches a real player
-- regardless of the name used -- confirmed live the same way. Any recognized
-- reply (handled in Router.lua's Achiever_ProcessServerMessage, fed by the
-- chat hook below) switches Achiever.mode to "server" on its own; absent a
-- reply, Achiever just stays in local mode.
--
-- Used to be CHANNEL-based on 1.12.1 only -- join a dedicated "ACHI"
-- channel, then send to it, modeled on PizzaSlices/src/channel.lua (a
-- confirmed-working reference for reaching a custom channel on this exact
-- server) -- since 1.14.2's hardware-event restriction on CHANNEL-type sends
-- (see below) doesn't apply to 1.12.1, so there was no forcing reason to
-- avoid it there. But the join step turned out to be a real liability on its
-- own: live testing found a same-session character-select relog (no client
-- restart) where GetChannelName reported a valid window-slot index a moment
-- before GetChannelList's real membership caught up to the new session, made
-- a send look successful when the server's own HandleAddonMessage log showed
-- it never actually arrived, and -- since the retry loop stopped as soon as
-- a send looked successful -- stranded Achiever in local mode for the rest
-- of the session. Whisper has no join/membership step at all to race
-- against, so switching 1.12.1 to it too sidesteps that whole class of bug
-- rather than patching it again next time a different ordering shows up.
--
-- Why WHISPER instead of CHANNEL on 1.14.2+ specifically: CHANNEL-type
-- SendChatMessage from insecure/addon-driven Lua (as opposed to a genuine
-- player keystroke) is silently blocked there -- confirmed via live
-- source-level server debugging (a breakpoint at the top of
-- WorldSession::HandleChatMessageOpcode never fires for this addon's
-- automatic handshake attempt, with or without a retry loop, whether the
-- channel is given by index or by name). This is a real, documented Blizzard
-- restriction, not a bug here or in HermesProxy: official Blizzard forum
-- threads ("SendChatMessage to Channel without hardware event") describe
-- this exact symptom -- SAY/YELL/CHANNEL-type SendChatMessage require a
-- genuine hardware event, added in retail patch 8.2.5 and ported to Classic
-- in patch 1.13.3, and explicitly note SAY/YELL are NOT gated this way
-- (confirmed live: a SAY-type send from the same kind of insecure context
-- does reach the server). WHISPER is also not on that gated list.
local HANDSHAKE_POLL_INTERVAL_SECONDS = 1
-- The loaded message waits for the handshake FIRST: on a confirming reply it
-- prints "server" the moment the mode flips, and only after this many seconds
-- without one does it fall back to reporting the (still-)local mode. Generous
-- on purpose -- the initial whisper can be silently dropped while the world
-- is still entering (retrying once a second), and the server-side replay of a
-- long achievement history can itself take seconds -- so "local" is only ever
-- reported when the handshake really did fail to complete, not merely
-- because it was slow. If the reply lands after even this window, the retry
-- loop re-announces with the standard loaded message (see
-- Achiever.announcedMode).
local READY_ANNOUNCE_DELAY_SECONDS = 10

-- Doesn't need to be a real/online character. Deliberately distinct from any
-- plausible tester character name to avoid ever colliding with a genuine
-- "can't whisper yourself" client-side restriction (untested territory,
-- trivially avoided by just not using a real name here).
local HANDSHAKE_WHISPER_TARGET = "AchieverServer"

-- Printed only once the handshake outcome is known: immediately when a
-- server reply confirms "server" mode, or after READY_ANNOUNCE_DELAY_SECONDS
-- without any reply (still "local"). Records the mode it actually printed
-- (Achiever.announcedMode) so the handshake loop can tell whether the
-- announcement went out before the server reply landed, and re-announce with
-- this same message in that case -- the guarded one-shot below, so the
-- late-reply path has to clear the marker first
local function Achiever_AnnounceReady()
	if (Achiever.announcedMode) then return end
	local version = GetAddOnMetadata("Achiever", "Version") or "0"
	DEFAULT_CHAT_FRAME:AddMessage(format(ACHIEVER_LOADED_MESSAGE, version, Achiever.mode))
	Achiever.announcedMode = Achiever.mode
end

-- Shared transport for every client->server protocol message (handshake,
-- sync request, ...). Global (not local) so Options.lua's Sync button can
-- call it too. Always WHISPER, on both clients -- see the comment above
-- HANDSHAKE_POLL_INTERVAL_SECONDS for why. Unlike the old CHANNEL path this
-- has no membership/join precondition to fail, so it always returns true;
-- kept as a return value (not a void call) so callers don't need to change
-- if a future transport ever needs to report failure again.
function Achiever_SendProtocolMessage(text)
	SendChatMessage(text, "WHISPER", nil, HANDSHAKE_WHISPER_TARGET)
	return true
end

-- Returns true if the handshake actually went out, false if it bailed --
-- see Achiever_SendProtocolMessage above for the transport detail.
local function Achiever_SendHandshake()
	if not Achiever_SendProtocolMessage(Achiever_GetHandshakeMessage()) then return false end

	if (AchieverDB and AchieverDB.debugMode) then
		DEFAULT_CHAT_FRAME:AddMessage(format(ACHIEVER_HANDSHAKE_SENT_WHISPER_MESSAGE, HANDSHAKE_WHISPER_TARGET))
	end

	return true
end

-- Options-panel "Sync" button entry point (global -- called from Options.lua).
-- Achiever.pendingSync is a scratch buffer Router.lua's SYNC_AC/SYNC_CR
-- handlers accumulate into; SYNC_DONE atomically swaps it into
-- AchieverCharacterProgress so an interrupted sync (no reply, disconnect
-- mid-sync) leaves local data untouched rather than partially overwritten.
-- Clicking Sync again before a reply arrives just discards the in-flight
-- buffer -- acceptable for a manual, low-frequency action.
function Achiever_RequestSync()
	Achiever.pendingSync = { achievements = {}, criteria = {} };
	if not Achiever_SendProtocolMessage(Achiever_GetSyncMessage()) then
		Achiever.pendingSync = nil;
		DEFAULT_CHAT_FRAME:AddMessage(ACHIEVER_SYNC_NOT_READY_MESSAGE);
		return;
	end
	DEFAULT_CHAT_FRAME:AddMessage(ACHIEVER_SYNC_REQUESTED_MESSAGE);
end

-- Sends right away, then keeps resending once a second until Achiever.mode
-- is actually confirmed as "server" by a real reply -- not just until a send
-- call reported success, since whisper has no channel-join/membership
-- precondition left to fail on, so Achiever_SendProtocolMessage always
-- "succeeds" from Lua's perspective regardless of whether the packet
-- actually reached the server. Confirmed via live testing (both a HELLO sent
-- this early right at ADDON_LOADED, before the world is fully ready, and a
-- same-session character-select relog) that a single unconfirmed attempt can
-- be silently dropped with no error, and since this used to just stop after
-- one attempt, that left Achiever stuck in local mode for the rest of the
-- session with no further attempts. Resending is harmless/idempotent -- the
-- server just repeats the same catch-up data.
--
-- This loop is also the single state machine that owns the loaded
-- announcement: nothing about local-vs-server is printed until the handshake
-- has actually decided it. Handshake confirmed (mode flipped to "server") --
-- the announcement goes out right here as "server". Still unconfirmed after
-- READY_ANNOUNCE_DELAY_SECONDS -- the announcement goes out as "local".
-- Should the reply land even after that deadline, the mode switch still
-- happens and the standard loaded message is printed once more, this time
-- reading "server" -- but the announcement never prints anything the
-- handshake hasn't actually confirmed.
local function Achiever_SendHandshakeWithRetry()
	Achiever_SendHandshake()

	-- elapsed: seconds since the last resend (reset on each send);
	-- totalElapsed: seconds since the first HELLO (the announcement deadline)
	local elapsed = 0
	local totalElapsed = 0
	local lastTime = GetTime()
	local retryFrame = CreateFrame("Frame")
	-- OnUpdate only fires while a frame IsShown() -- confirmed via
	-- ChatThrottleLib.lua's and PizzaSlices/src/channel.lua's own bare
	-- OnUpdate-driver frames, both of which explicitly manage Show/Hide as
	-- their on/off switch rather than assuming CreateFrame's default state.
	-- CreateFrame frames default to shown, so this is normally a no-op, but
	-- explicit is cheap insurance against silently never ticking at all.
	--
	-- No positional params in the closure -- confirmed via Blizzard's own
	-- 1.12.1 FrameXML (WorldFrame.lua's WorldFrame_OnUpdate(elapsed),
	-- UnitFrame.lua's UnitFrame_OnUpdate(elapsed)) that this client passes
	-- exactly ONE argument to any OnUpdate script -- the elapsed time itself,
	-- never the frame -- while modern clients pass TWO (self, elapsed), so a
	-- modern-shaped signature silently misreads the sole 1.12.1 argument.
	-- Zero-parameter closures driven by GetTime() sidestep that difference
	-- entirely, correct on both clients.
	retryFrame:Show()
	retryFrame:SetScript("OnUpdate", function()
		if Achiever.mode == "server" then
			retryFrame:SetScript("OnUpdate", nil)
			-- Handshake confirmed -- the announcement's primary trigger
			if (not Achiever.announcedMode) then
				Achiever_AnnounceReady();
			elseif (Achiever.announcedMode == "local") then
				-- The deadline already announced "local" before this reply
				-- landed: re-announce with the standard loaded line, which
				-- now reads "server" -- same message, corrected mode
				Achiever.announcedMode = nil;
				Achiever_AnnounceReady();
			end
			return
		end
		local now = GetTime()
		elapsed = elapsed + (now - lastTime)
		totalElapsed = totalElapsed + (now - lastTime)
		lastTime = now
		-- Deadline passed with no confirmation: report local once. Retrying
		-- continues afterward regardless -- the mode switch must not depend
		-- on the announcement having happened
		if (not Achiever.announcedMode and totalElapsed >= READY_ANNOUNCE_DELAY_SECONDS) then
			Achiever_AnnounceReady();
		end
		if elapsed < HANDSHAKE_POLL_INTERVAL_SECONDS then return end
		elapsed = 0
		if (AchieverDB and AchieverDB.debugMode) then
			DEFAULT_CHAT_FRAME:AddMessage(format(ACHIEVER_HANDSHAKE_RETRY_DEBUG_MESSAGE, HANDSHAKE_WHISPER_TARGET));
		end
		Achiever_SendProtocolMessage(Achiever_GetHandshakeMessage())
	end)
end

-- Any chat message can carry server-sent "ACHI" payloads, so this needs to
-- catch messages regardless of which specific CHAT_MSG_* event they arrive
-- as -- in practice just the dedicated "ACHI" channel (CHAT_MSG_CHANNEL),
-- with CHAT_MSG_SYSTEM kept as a reasonable fallback.
--
-- Modern clients: a plain RegisterEvent/OnEvent listener on an ordinary
-- frame, NOT hooking anything on the chat frames themselves. Confirmed via
-- research this is the only genuinely taint-safe option: even Blizzard's own
-- official ChatFrame_AddMessageEventFilter API (tried first) has a
-- documented, unresolved taint issue for some event types (the "Whisper
-- Messenger" addon's own changelog: "the chat filter closure taints
-- SetLastTellTarget... there is no taint-safe alternative"), and directly
-- overwriting ChatFrameN.AddMessage (the original 1.12.1 approach, kept
-- below unconditionally there) let Achiever's own code run inside the same
-- call chain as unrelated combat/ability messages on 1.14.2, tainting that
-- whole execution and blocking action bar clicks and world interaction
-- ("Achiever has been blocked from an action only available to the Blizzard
-- UI"). A plain event subscriber never touches the chat frames' own display
-- machinery at all -- it's the same pattern combat-log/chat-parsing addons
-- (damage meters, etc.) use universally without taint issues, since the
-- event fires to it completely independently of whatever the chat frames
-- themselves do with the same event.
--
-- The plain listener above can only observe messages, not suppress display,
-- so ACHI-prefixed system lines are also suppressed separately below via
-- ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ...) -- confirmed via
-- research that the taint issue in the "Whisper Messenger" changelog cited
-- above is specific to CHAT_MSG_WHISPER (it corrupts SetLastTellTarget,
-- whisper-reply state only whisper's own dispatch path touches), not a
-- blanket problem with the filter API; several established addons filter
-- CHAT_MSG_SYSTEM this exact way with no reported taint issues. Deliberately
-- NOT extended to CHAT_MSG_WHISPER/CHAT_MSG_WHISPER_INFORM (the outgoing
-- handshake's own self-echo) -- that's the one event type with an actual
-- confirmed taint precedent. 1.12.1 keeps full suppression via the original
-- approach below, which has no taint system to interact badly with in the
-- first place.
local function Achiever_HookChatFrames()
	local function HandleMessage(msg)
		local handled = Achiever_ProcessServerMessage and Achiever_ProcessServerMessage(msg);
		return (handled and not (AchieverDB and AchieverDB.debugMode));
	end

	if WOW_PROJECT_ID then
		local listener = CreateFrame("Frame");
		listener:RegisterEvent("CHAT_MSG_CHANNEL");
		listener:RegisterEvent("CHAT_MSG_SYSTEM");
		-- Named params, not `...` -- confirmed via live 1.12.1 testing
		-- ("unexpected symbol '...'") that `...` can't be referenced at all
		-- beyond a function's own parameter-list declaration on 1.12.1's Lua
		-- 5.0 parser, not even forwarded as a plain call argument to
		-- select() -- and this whole file loads on both clients regardless
		-- of the WOW_PROJECT_ID runtime check (Lua parses a whole chunk,
		-- including unreached branches, before executing any of it). The
		-- message text CHAT_MSG_CHANNEL/CHAT_MSG_SYSTEM carry is always
		-- their first argument, but this checks a generous handful of
		-- leading positions rather than just the first, in case of any
		-- off-by-one uncertainty in exactly how many real params this
		-- client binds before the legacy arg1-style globals would've taken
		-- over on 1.12.1 (moot here since this branch never runs there).
		listener:SetScript("OnEvent", function(frame, event, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
			local args = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 };
			for i = 1, 10 do
				local v = args[i];
				if type(v) == "string" and string.find(v, "^ACHI") then
					HandleMessage(v);
					return;
				end
			end
		end);

		-- Suppresses ACHI-prefixed system lines from display outside debug
		-- mode. securecall wraps the registration itself, not the filter
		-- callback -- Whisper Messenger's changelog documents that calling
		-- ChatFrame_AddMessageEventFilter directly from insecure/addon code
		-- taints Blizzard's shared filter dispatch table; securecall calls
		-- it as if from secure/Blizzard-native code instead. The filter
		-- callback body itself still runs as ordinary Achiever code every
		-- time a system message arrives -- that's expected and matches how
		-- every other addon filtering CHAT_MSG_SYSTEM this way works. Reads
		-- AchieverDB.debugMode live on every call, so toggling debug mode in
		-- Options takes effect immediately with no extra wiring needed.
		securecall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", function(self, event, msg)
			return type(msg) == "string" and string.find(msg, "^ACHI") and not (AchieverDB and AchieverDB.debugMode);
		end)
		return;
	end

	local globals = getfenv(0)
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = globals["ChatFrame" .. i]
		if chatFrame then
			local original = chatFrame.AddMessage
			chatFrame.AddMessage = function(self, msg, r, g, b)
				if msg and string.find(msg, "^ACHI") then
					-- A recognized protocol line is suppressed from chat
					-- unless debug mode is on -- this hook only ever
					-- intercepted for parsing, it never actually stopped the
					-- original AddMessage, so every incoming ACHI;... line
					-- was showing up as plain chat text to every player.
					if (HandleMessage(msg)) then
						return;
					end
				end
				original(self, msg, r, g, b)
			end
		end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
-- Anonymous function passed straight to SetScript -- confirmed via live
-- 1.14.2 testing (see the identical fix in Router.lua) that this doesn't
-- reliably get the legacy this/event/arg1 globals populated, unlike XML
-- inline scripts. Since this whole handler gates minimap button creation,
-- the chat-message hook that parses incoming ACHI server data, frame
-- dragging, tracker init, the handshake channel join, and the keybind
-- attempt, if its condition never matched on 1.14.2 none of that ever ran --
-- a plausible unifying explanation for several previously-separate symptoms
-- (empty categories because server data never arrived, frame not movable,
-- no keybind attempted at all rather than attempted-and-blocked). Shadowing
-- with locals that prefer the real modern params but fall back to the
-- legacy globals fixes 1.14.2 while leaving 1.12.1 (which never passes real
-- params here) completely unchanged.
eventFrame:SetScript("OnEvent", function(frame, ev, addonName)
	local this = frame or this
	local event = ev or event
	local arg1 = addonName or arg1
	if event == "ADDON_LOADED" and arg1 == "Achiever" then
		AchieverDB = AchieverDB or {}
		-- Priority: explicit Options-panel override (AchieverDB.language)
		-- beats GetLocale() (already resolved by LocaleBootstrap.lua, and
		-- possibly already loaded from it, mid-.toc) beats English (nil --
		-- do nothing). This is the one place AchieverDB is actually
		-- readable -- see LocaleBootstrap.lua's own comment for why it
		-- can't be resolved any earlier than this handler.
		Achiever_ForceLocale = AchieverDB.language or Achiever_BootstrapLocale;

		-- If the resolved override differs from whatever LocaleBootstrap.lua
		-- already loaded (including "nothing loaded, GetLocale() was enUS"),
		-- load the right one now -- LoadAddOn is a harmless no-op if it's
		-- already loaded. Achiever.db and every Strings.lua chrome global
		-- become correct immediately either way.
		if (Achiever_ForceLocale and Achiever_ForceLocale ~= Achiever_BootstrapLocale) then
			LoadAddOn("Achiever-" .. Achiever_ForceLocale)
		end

		-- Re-stamp the chrome that was already created at file-parse time
		-- (Options.xml/AchievementUI.xml's text="GLOBAL_NAME" widgets,
		-- AchievementUI.lua's AchieverAchievementFrameFilters table literal) before
		-- this handler ever ran -- the LoadAddOn call above (or
		-- LocaleBootstrap.lua's earlier one) only just overwrote the
		-- underlying globals; nothing re-reads them into already-created
		-- widgets on its own.
		Achiever_ReapplyLocaleChrome()
		Achiever_CreateMinimapButton()
		Achiever_HookChatFrames()
		Achiever_MakeAchieverAchievementFrameMovable()
		Achiever_HookItemRef()
		Achiever_Tracker_Initialize()
		Achiever_SendHandshakeWithRetry()

		this:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		-- Achiever_Tracker_Initialize() (ADDON_LOADED time) already ran its
		-- own Achiever_Tracker_Update(), but "Achiever" loads alphabetically
		-- before "pfUI", so pfUI.font_default wasn't set yet at that point --
		-- pfUI only loads its SavedVariables config and resolves its fonts
		-- once *its own* ADDON_LOADED fires. Re-running here (PLAYER_LOGIN
		-- fires after every addon, pfUI included, has finished loading)
		-- picks up the real font instead of leaving it on the fallback.
		if Achiever_Tracker_Update then
			Achiever_Tracker_Update()
		end

		-- Achiever_ReapplyLocaleChrome() (ADDON_LOADED time) already ran once,
		-- but on 1.12.1 that turned out to be too early: live diagnostic
		-- confirmed the explicit LoadAddOn("Achiever-" .. Achiever_ForceLocale)
		-- call at ADDON_LOADED time (above) does NOT synchronously finish
		-- executing the locale addon's files before returning on this
		-- client -- the locale addon's own stringOverrides loop was confirmed
		-- to run (and correctly set e.g. ACHIEVEMENTS) only AFTER
		-- Achiever_ReapplyLocaleChrome had already read the still-English
		-- globals and stamped them onto the tab/header/filter widgets, with
		-- nothing ever re-stamping them afterward -- unlike achievement/
		-- category names, which read Achiever.db live every time the panel
		-- renders and so picked up the translation correctly regardless of
		-- timing. Re-running here, at the same "everything is definitely
		-- loaded by now" checkpoint the Achiever_Tracker_Update() call above
		-- already relies on for the exact same class of problem (pfUI's font
		-- not ready at ADDON_LOADED time either), re-stamps the chrome with
		-- whatever the globals actually hold by now. Not moving the ADDON_LOADED-time
		-- call, since PLAYER_LOGIN doesn't fire again on its own if a player
		-- changes AchieverDB.language without a fresh login (that path goes
		-- through ReloadUI() instead -- see Options.lua's Language dropdown
		-- comment -- so PLAYER_LOGIN firing after every such reload is what
		-- makes this reliable, not something ADDON_LOADED alone would give).
		if Achiever_ReapplyLocaleChrome then
			Achiever_ReapplyLocaleChrome()
		end

		-- Binding sets aren't ready yet at ADDON_LOADED time, so the
		-- default keybind is assigned here instead. Only ever force it
		-- once; a later manual rebind or clear by the user (including via
		-- the Key Bindings UI, now that Bindings.xml exposes "Achiever")
		-- is never overwritten again.
		--
		-- boundDefaultKeyV2 (not the old boundDefaultKey) so that
		-- characters who already logged in under the previous CLICK-target
		-- scheme -- which set the old flag without ever registering
		-- "ACHIEVER_TOGGLE" -- still get the new named binding applied once.
		if not AchieverDB.boundDefaultKeyV2 then
			-- SetBinding/SaveBindings were completely unprotected in 1.12.1 (no taint
			-- system existed yet), but modern clients (1.14.2+) only allow them from a
			-- real user-input-driven secure execution context -- PLAYER_LOGIN firing on
			-- its own timeline doesn't qualify, so this throws a protected-function
			-- violation there ("blocked from an action only available to the Blizzard
			-- UI"). This used to be pcall-wrapped, on the assumption that catching the
			-- error was enough -- confirmed via research that it is NOT: pcall prevents
			-- the visible Lua error, but does NOT prevent the resulting taint from
			-- spreading into the rest of that execution (here, PLAYER_LOGIN's handler,
			-- which also sets up tracker/handshake/etc. in the same call), which is a
			-- plausible root cause for action bars/world-interaction getting blocked
			-- for the rest of the session. The only actually-safe fix is to never
			-- attempt the protected call at all on clients where it's restricted --
			-- WOW_PROJECT_ID is a modern-only global, so this is unconditionally
			-- skipped there; the user falls back to the minimap icon or binding it
			-- manually via Key Bindings (Bindings.xml already exposes "Achiever"
			-- there either way). Zero behavior change on 1.12.1.
			if not WOW_PROJECT_ID and not GetBindingKey("ACHIEVER_TOGGLE") then
				SetBinding("Y", "ACHIEVER_TOGGLE")
				local bindingSet = GetCurrentBindingSet()
				if bindingSet then
					SaveBindings(bindingSet)
				end
			end
			AchieverDB.boundDefaultKeyV2 = true
		end

		this:UnregisterEvent("PLAYER_LOGIN")
	end
end)
