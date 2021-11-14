-- grabbed from shaguNotify at https://github.com/shagu/ShaguNotify

achieverLibnotify = {}
achieverLibnotify.window = {}

achieverLibnotify.max_window = 5

function achieverLibnotify:CreateFrame()
  local frame = CreateFrame("Button", "MyAchievment", UIParent)

  frame:SetWidth(400)
  frame:SetHeight(117)
  frame:SetFrameStrata("DIALOG")
  frame:Hide()

  do -- animations
    frame:SetScript("OnShow", function()
      this.modifyA = 1
      this.modifyB = 0
      this.stateA = 0
      this.stateB = 0
      this.animate = true

      this.showTime = GetTime()
    end)

    frame:SetScript("OnUpdate", function()
      if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + .01 end

      if this.animate == true then
        if this.stateA > .50 and this.modifyA == 1 then
          this.modifyB = 1
        end

        if this.stateA > .75 then
          this.modifyA = -1
        end

        if this.stateB > .50 then
          this.modifyB = -1
        end

        this.stateA = this.stateA + this.modifyA/50
        this.stateB = this.stateB + this.modifyB/50

        this.glow:SetGradientAlpha("HORIZONTAL",
          this.stateA, this.stateA, this.stateA, this.stateA,
          this.stateB, this.stateB, this.stateB, this.stateB)

        this.shine:SetGradientAlpha("VERTICAL",
          this.stateA, this.stateA, this.stateA, this.stateA,
          this.stateB, this.stateB, this.stateB, this.stateB)

        if this.stateA < 0 and this.stateB < 0 then
          this.animate = false
        end
      end

      if this.showTime + 5 < GetTime() then
        this:SetAlpha(this:GetAlpha() - .05)
        if this:GetAlpha() <= 0 then
          this:Hide()
          this:SetAlpha(1)
        end
      end
    end)
  end

  frame.background = frame:CreateTexture("background", "BACKGROUND")
  frame.background:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Alert-Background")
  frame.background:SetPoint("TOPLEFT", 0, 0)
  frame.background:SetPoint("BOTTOMRIGHT", 0, 0)
  frame.background:SetTexCoord(0, .605, 0, .703)

  frame.unlocked = frame:CreateFontString("Unlocked", "DIALOG", "GameFontBlack")
  frame.unlocked:SetWidth(260)
  frame.unlocked:SetHeight(16)
  frame.unlocked:SetPoint("TOP", 9, -30)
  frame.unlocked:SetText("Achievement Earned")

  frame.name = frame:CreateFontString("Name", "DIALOG", "GameFontHighlight")
  frame.name:SetWidth(312)
  frame.name:SetHeight(21)
  frame.name:SetPoint("BOTTOMLEFT", 94, 49)
  frame.name:SetPoint("BOTTOMRIGHT", -78, 49)

  frame.note = frame:CreateFontString("Note", "DIALOG", "GameFontBlack")
  frame.note:SetWidth(312)
  frame.note:SetHeight(21)
  frame.note:SetPoint("BOTTOM", 9, 30)
  frame.note:SetAlpha(0.80)


  frame.glow = frame:CreateTexture("glow", "OVERLAY")
  frame.glow:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Alert-Glow")
  frame.glow:SetBlendMode("ADD")
  frame.glow:SetWidth(520)
  frame.glow:SetHeight(222)
  frame.glow:SetPoint("CENTER", 0, 0)
  frame.glow:SetTexCoord(0, 0.78125, 0, 0.66796875)
  frame.glow:SetAlpha(0)

  frame.shine = frame:CreateTexture("shine", "OVERLAY")
  frame.shine:SetBlendMode("ADD")
  frame.shine:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Alert-Glow")
  frame.shine:SetWidth(87)
  frame.shine:SetHeight(94)
  frame.shine:SetPoint("BOTTOMLEFT", 0, 8)
  frame.shine:SetTexCoord(0.78125, 0.912109375, 0, 0.28125)
  frame.shine:SetAlpha(0)

  frame.icon = CreateFrame("Frame", "icon", frame)
  frame.icon:SetWidth(161)
  frame.icon:SetHeight(161)
  frame.icon:SetPoint("TOPLEFT", -34, 21)

  frame.icon.bling = frame.icon:CreateTexture("bling", "BORDER")
  frame.icon.bling:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Bling")
  frame.icon.bling:SetPoint("CENTER", -1, 1)
  frame.icon.bling:SetWidth(151)
  frame.icon.bling:SetHeight(151)

  frame.icon.texture = frame.icon:CreateTexture("texture", "ARTWORK")
  frame.icon.texture:SetPoint("CENTER", 0, 4)
  frame.icon.texture:SetWidth(65)
  frame.icon.texture:SetHeight(65)

  frame.icon.overlay = frame.icon:CreateTexture("overlay", "OVERLAY")
  frame.icon.overlay:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-IconFrame")
  frame.icon.overlay:SetPoint("CENTER", -1, 3)
  frame.icon.overlay:SetHeight(94)
  frame.icon.overlay:SetWidth(94)
  frame.icon.overlay:SetTexCoord(0, 0.5625, 0, 0.5625)

  frame.shield = CreateFrame("Frame", "shield", frame)
  frame.shield:SetWidth(83)
  frame.shield:SetHeight(83)
  frame.shield:SetPoint("TOPRIGHT", -14, -19)

  frame.shield.icon = frame.shield:CreateTexture("icon", "BACKGROUND")
  frame.shield.icon:SetTexture("Interface\\AddOns\\Achiever\\textures\\UI-Achievement-Shields")
  frame.shield.icon:SetWidth(68)
  frame.shield.icon:SetHeight(62)
  frame.shield.icon:SetPoint("TOPRIGHT", 1, -10)

  frame.shield.points = frame.shield:CreateFontString("Name", "DIALOG", "GameFontWhite")
  frame.shield.points:SetPoint("CENTER", 7, 3)
  frame.shield.points:SetWidth(83)
  frame.shield.points:SetHeight(83)

  return frame
end

function achieverLibnotify:ShowPopup(text, note, points, icon, shield, title)

  for i = 1, achieverLibnotify.max_window do
    if not achieverLibnotify.window[i]:IsVisible() then
      achieverLibnotify.window[i].unlocked:SetText(title or "Achievement Earned")
      achieverLibnotify.window[i].name:SetText(text or "TEXT")
      achieverLibnotify.window[i].icon.texture:SetTexture(icon or "Interface\\QuestFrame\\UI-QuestLog-BookIcon")

      achieverLibnotify.window[i].note:SetText(note or "NOTE")

      if shield == 0 then
        achieverLibnotify.window[i].shield.icon:SetTexCoord(.5, 1 , .5 , 1)
      elseif shield == 1 then
        achieverLibnotify.window[i].shield.icon:SetTexCoord(.5, 1 , 0 , .5)
      elseif shield == 2 then
        achieverLibnotify.window[i].shield.icon:SetTexCoord(0, .5 , .5 , 1)
      elseif shield == 3 then
        achieverLibnotify.window[i].shield.icon:SetTexCoord(0, .5 , 0 , .5)
      end

      achieverLibnotify.window[i].shield.points:SetText(points or "10")
      achieverLibnotify.window[i]:Show()

      return
    end
  end
end

for i = 1, achieverLibnotify.max_window do
  achieverLibnotify.window[i] = achieverLibnotify:CreateFrame()
  achieverLibnotify.window[i]:SetPoint("TOP", 0, 0 - (100 * i))
end
