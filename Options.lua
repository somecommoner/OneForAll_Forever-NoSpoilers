local _, NS = ...

-- Options page in the game's own settings: Options > AddOns > OneForAll NoSpoilers (/ofans opens it).
-- One switch per part with a short description and its progress. Switches are account-wide and take effect
-- after a reload; a "Reload now" button shows once something was changed. Registered like other addons in
-- this client do (Settings.RegisterCanvasLayoutCategory), with the older InterfaceOptions call as fallback.

local TITLE = "OneForAll NoSpoilers"
local ROW = 46

local category, panel
local rows = {}

local function refresh()
  if not panel then return end
  for _, r in ipairs(rows) do
    local s = r.switch
    r.check:SetChecked(NS.IsOnSaved(s.key))
    local m = NS.byKey[s.part]
    local text
    if m and m.failed then
      text = "|cffff6060Not working: OneForAll changed|r"
    elseif NS.IsOn(s.key) ~= NS.IsOnSaved(s.key) then
      text = "|cffffd200After a reload|r"
    elseif not NS.IsOn(s.key) then
      text = "|cff909090Off|r"
    else
      text = NS.CounterText(s.key)
    end
    r.count:SetText(text)
  end
  panel.reload:SetShown(NS.SwitchesChanged())
end

local function build()
  panel = CreateFrame("Frame")
  panel.name = TITLE

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(TITLE)

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetText("Hides OneForAll content until this character has discovered it. A part that is switched off shows"
    .. " everything, but still records what you discover. Switches apply to all characters, after a reload.")

  local reload = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reload:SetSize(120, 22)
  reload:SetPoint("TOPRIGHT", -16, -12)
  reload:SetText("Reload now")
  reload:SetScript("OnClick", function() ReloadUI() end)
  panel.reload = reload

  local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -4, -12)
  sf:SetPoint("BOTTOMRIGHT", -30, 12)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(560, #NS.SWITCHES * ROW)
  sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(self, w) if w and w > 0 then child:SetWidth(w) end end)

  for i, s in ipairs(NS.SWITCHES) do
    local row = CreateFrame("Frame", nil, child)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
    row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    row:SetHeight(ROW)

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 0, -2)
    check:SetScript("OnClick", function(self)
      NS.SetOn(s.key, self:GetChecked() and true or false)
      refresh()
    end)

    local count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("TOPRIGHT", -4, -8)
    count:SetWidth(190)
    count:SetJustifyH("RIGHT")

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -5)
    label:SetText(s.label)

    local desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    desc:SetPoint("RIGHT", count, "LEFT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText(s.desc)

    rows[#rows + 1] = { switch = s, check = check, count = count }
  end

  panel:SetScript("OnShow", refresh)
  refresh()
end

local function register()
  if category or not NS.FLT then return end -- nothing to set when OneForAll was not found
  build()
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    category = panel
  end
end

function NS.OpenOptions()
  if category and Settings and Settings.OpenToCategory and category ~= panel then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif category and InterfaceOptionsFrame_OpenToCategory then
    -- the old frame needs two calls the first time
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  else
    SlashCmdList.ONEFORALLNOSPOILERS("status")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  local ok, err = pcall(register)
  if not ok then NS.Print("The options page could not be created (" .. tostring(err) .. "). /ofans status still works.") end
end)
