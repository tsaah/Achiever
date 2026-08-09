-- Achiever.lua
-- Scaffold: a Ctrl+A keybind and a minimap button both toggle the
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
	if AchievementFrame_ToggleAchievementFrame then
		AchievementFrame_ToggleAchievementFrame()
	end
end

-- Makes the (otherwise fixed-position) achievement window draggable, with
-- its position persisted to AchieverDB the same way the minimap button's
-- is. Done here rather than in AchievementUI.xml/.lua so those stay a
-- faithful port of Blizzard's files. ShowUIPanel's own panel-management re-anchors the frame
-- on every show (per its UIPanelWindows entry), so the saved position has to
-- be re-applied *after* that happens -- since this client has no
-- hooksecurefunc, that means wrapping the original AchievementFrame_OnShow
-- rather than hooking it.
--
-- AchievementFrameHeader (the title/watermark strip) is a separate child
-- frame with enableMouse="true" of its own, positioned right over the top of
-- AchievementFrame -- exactly where someone would naturally grab to drag.
-- That intercepts the mouse there, so AchievementFrame's own OnDragStart
-- never fires for it; the header needs its own drag handlers that move the
-- *parent* frame, not itself.
local function Achiever_MakeAchievementFrameMovable()
	local function SaveAchievementFramePosition()
		local point, _, relativePoint, x, y = AchievementFrame:GetPoint()
		AchieverDB.achievementFramePos = { point = point, relativePoint = relativePoint, x = x, y = y }
	end

	AchievementFrame:SetMovable(true)
	AchievementFrame:RegisterForDrag("LeftButton")
	AchievementFrame:SetScript("OnDragStart", function()
		AchievementFrame:StartMoving()
	end)
	AchievementFrame:SetScript("OnDragStop", function()
		AchievementFrame:StopMovingOrSizing()
		SaveAchievementFramePosition()
	end)

	AchievementFrameHeader:EnableMouse(true)
	AchievementFrameHeader:RegisterForDrag("LeftButton")
	AchievementFrameHeader:SetScript("OnDragStart", function()
		AchievementFrame:StartMoving()
	end)
	AchievementFrameHeader:SetScript("OnDragStop", function()
		AchievementFrame:StopMovingOrSizing()
		SaveAchievementFramePosition()
	end)

	local originalOnShow = AchievementFrame_OnShow
	AchievementFrame_OnShow = function()
		originalOnShow()
		if AchieverDB.achievementFramePos then
			local p = AchieverDB.achievementFramePos
			AchievementFrame:ClearAllPoints()
			AchievementFrame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
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
		Achiever_Toggle()
	end)

	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(ACHIEVER_MINIMAP_TOOLTIP_TITLE)
		GameTooltip:AddLine(ACHIEVER_MINIMAP_TOOLTIP_LINE1, 1, 1, 1)
		GameTooltip:AddLine(ACHIEVER_MINIMAP_TOOLTIP_LINE2, 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	button:SetScript("OnDragStart", function()
		if IsShiftKeyDown() then
			this:StartMoving()
		end
	end)

	button:SetScript("OnDragStop", function()
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
local function Achiever_HookItemRef()
	local originalSetItemRef = SetItemRef
	SetItemRef = function(link, text, button)
		local _, _, id = string.find(link, "^achievement:(%d+)")
		if id then
			ShowUIPanel(AchievementFrame)
			AchievementFrame_SelectAchievement(tonumber(id))
			return
		end
		originalSetItemRef(link, text, button)
	end
end

-- Local-mode-first handshake: join the shared channel and send a ping
-- carrying our last-known progress-sync timestamp. Mirrors
-- PizzaSlices/src/channel.lua's own join-then-send pattern (that addon's
-- messages are confirmed reaching this server) closely, but actively polls
-- GetChannelName until membership is actually confirmed rather than just
-- waiting a fixed delay and hoping the join landed in time -- there's no
-- reliable way to know in advance how long a custom channel join takes to
-- register server-side, so "keep checking until true" is more robust than
-- any fixed guess.
--
-- SendAddonMessage cannot target a custom channel at all in this client --
-- confirmed via ChatThrottleLib.lua (vendored in aux-addon/DPSMate), which
-- wraps SendChatMessage with all 4 real params (text, chattype, language,
-- destination) but wraps SendAddonMessage with only 3 (prefix, text,
-- chattype), no destination slot at all -- so plain SendChatMessage is the
-- only way to reach an arbitrary channel here. Any recognized reply
-- (handled in Router.lua's Achiever_ProcessServerMessage, fed by the chat
-- hook below) switches Achiever.mode to "server" on its own; absent a
-- reply, Achiever just stays in local mode.
local HANDSHAKE_CHANNEL_NAME = "ACHI"
local HANDSHAKE_POLL_INTERVAL_SECONDS = 1
local READY_ANNOUNCE_DELAY_SECONDS = 3

-- GetChannelList()'s flat return mixes indices/names/instance IDs together;
-- comparing every element against the channel name (matching
-- PizzaSlices/src/channel.lua exactly) just harmlessly no-ops on whichever
-- entries aren't the name string.
local function Achiever_IsInChannel(name)
	local channels = { GetChannelList() }
	for _, channel in next, channels do
		if channel == name then
			return true
		end
	end
	return false
end

-- Printed once Achiever.mode has had a real chance to settle (a round trip
-- for any server reply), not immediately after sending, so it reports
-- "server" correctly instead of always showing the pre-reply "local" default.
local function Achiever_AnnounceReady()
	local version = GetAddOnMetadata("Achiever", "Version") or "0"
	DEFAULT_CHAT_FRAME:AddMessage(format(ACHIEVER_LOADED_MESSAGE, version, Achiever.mode))
end

local function Achiever_SendHandshake()
	local channelIndex = GetChannelName(HANDSHAKE_CHANNEL_NAME)
	if not channelIndex or channelIndex <= 0 then return end
	SendChatMessage(Achiever_GetHandshakeMessage(), "CHANNEL", nil, channelIndex)
	if (AchieverDB and AchieverDB.debugMode) then
		DEFAULT_CHAT_FRAME:AddMessage(format(ACHIEVER_HANDSHAKE_SENT_MESSAGE, HANDSHAKE_CHANNEL_NAME, channelIndex))
	end

	local elapsed = 0
	local readyFrame = CreateFrame("Frame")
	readyFrame:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed >= READY_ANNOUNCE_DELAY_SECONDS then
			this:SetScript("OnUpdate", nil)
			Achiever_AnnounceReady()
		end
	end)
end

-- Sends right away if already in the channel (e.g. it survived a /reload),
-- otherwise joins and re-checks once a second -- retrying the join each
-- time -- until Achiever_IsInChannel confirms membership.
local function Achiever_JoinHandshakeChannelAndSend()
	if Achiever_IsInChannel(HANDSHAKE_CHANNEL_NAME) then
		Achiever_SendHandshake()
		return
	end

	JoinChannelByName(HANDSHAKE_CHANNEL_NAME)

	local elapsed = 0
	local joinPollFrame = CreateFrame("Frame")
	joinPollFrame:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed < HANDSHAKE_POLL_INTERVAL_SECONDS then return end
		elapsed = 0

		if Achiever_IsInChannel(HANDSHAKE_CHANNEL_NAME) then
			this:SetScript("OnUpdate", nil)
			Achiever_SendHandshake()
		else
			JoinChannelByName(HANDSHAKE_CHANNEL_NAME)
		end
	end)
end

-- Any chat message can carry server-sent "ACHI" payloads (system text, says,
-- whispers, etc.), so every chat window's AddMessage is wrapped rather than
-- listening for one specific CHAT_MSG_* event.
local function Achiever_HookChatFrames()
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
					local handled = Achiever_ProcessServerMessage and Achiever_ProcessServerMessage(msg);
					if (handled and not (AchieverDB and AchieverDB.debugMode)) then
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
eventFrame:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" and arg1 == "Achiever" then
		AchieverDB = AchieverDB or {}
		-- Applied here, before any dependent Achiever-<locale> addon's own
		-- file executes (guaranteed by their "## Dependencies: Achiever"),
		-- since each one only ever decides whether to activate once, at its
		-- own load time -- a later change from the Options pane can't
		-- retroactively affect an addon that already decided not to load.
		Achiever_ForceLocale = AchieverDB.language;

		Achiever_CreateMinimapButton()
		Achiever_HookChatFrames()
		Achiever_MakeAchievementFrameMovable()
		Achiever_HookItemRef()
		Achiever_Tracker_Initialize()
		Achiever_JoinHandshakeChannelAndSend()

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
			if not GetBindingKey("ACHIEVER_TOGGLE") then
				SetBinding("CTRL-A", "ACHIEVER_TOGGLE")
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
