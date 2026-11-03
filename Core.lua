local ADDON, NS = ...

-- OneForAll NoSpoilers: a companion to OneForAll that hides what this character has not discovered yet.
--
-- How it works: OneForAll loads all its data first (this addon depends on it, so it always loads second).
-- At our ADDON_LOADED, before OneForAll builds any window or map icon at PLAYER_LOGIN, each part below
-- removes the undiscovered entries from OneForAll's own data lists, in place. OneForAll's code is never
-- changed and its UI is never touched; it simply sees a smaller list. Only this character's progress is
-- saved here (IDs of what was discovered), never OneForAll's data, so new content in an OneForAll update
-- is picked up automatically.
--
-- Each part checks that the data still looks the way it expects before it changes anything. If not, it
-- leaves that data alone (OneForAll then shows everything for that part) and says so once in chat.

NS.order = {}
NS.byKey = {}

local PREFIX = "|cff66ccffOneForAll NoSpoilers:|r "
function NS.Print(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(text)) end
end

-- A part: { key=, label=, apply=function(FLT, db) -> true | false, reason, events={EVENT=fn}, status=function() -> text }
function NS.AddModule(m)
  NS.order[#NS.order + 1] = m
  NS.byKey[m.key] = m
end

-- Keeps the entries of an array for which keep(entry) is true, in order, in the same table (other addon
-- code may hold a reference to it). Returns the removed entries.
function NS.FilterInPlace(list, keep)
  local kept, removed = {}, {}
  for _, v in ipairs(list) do
    if keep(v) then kept[#kept + 1] = v else removed[#removed + 1] = v end
  end
  for i = #list, 1, -1 do list[i] = nil end
  for i, v in ipairs(kept) do list[i] = v end
  return removed
end

function NS.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Events ---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {} -- event -> { {module, fn}, ... }

function NS.Fail(m, err)
  if m.failed then return end
  m.active = false
  m.failed = tostring(err)
  NS.Print(m.label .. " stopped recording discoveries this session (" .. m.failed .. ").")
end

function NS.Safe(m, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then NS.Fail(m, err) end
end

local function on(m, event, fn)
  local list = handlers[event]
  if not list then
    -- unknown events (not in this client) are skipped
    if not pcall(frame.RegisterEvent, frame, event) then return end
    list = {}
    handlers[event] = list
  end
  list[#list + 1] = { m, fn }
end

local pending = {}
function NS.Debounce(m, key, delay, fn)
  if pending[key] then return end
  pending[key] = true
  C_Timer.After(delay, function()
    pending[key] = nil
    if m.active then NS.Safe(m, fn) end
  end)
end

-- Start ----------------------------------------------------------------------------------------------

local function start()
  local FLT = _G.OneForAll
  if type(FLT) ~= "table" then
    NS.Print("OneForAll's data was not found, so nothing is hidden.")
    return
  end
  NS.FLT = FLT
  if type(OneForAllNoSpoilersCharDB) ~= "table" then OneForAllNoSpoilersCharDB = {} end
  local db = OneForAllNoSpoilersCharDB
  db.version = 1
  NS.db = db
  for _, m in ipairs(NS.order) do
    local ok, res, reason = pcall(m.apply, FLT, db)
    if ok and res then
      m.active = true
      for event, fn in pairs(m.events or {}) do on(m, event, fn) end
    else
      m.failed = tostring(ok and (reason or "unknown reason") or res)
      NS.Print(m.label .. " are not hidden: " .. m.failed .. ". OneForAll may have changed; it shows everything for this part.")
    end
  end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" and ... == ADDON then start() end
  local list = handlers[event]
  if not list then return end
  for _, h in ipairs(list) do
    if h[1].active then NS.Safe(h[1], h[2], ...) end
  end
end)

-- Reload prompt ----------------------------------------------------------------------------------------

StaticPopupDialogs["ONEFORALL_NOSPOILERS_RELOAD"] = {
  text = "%s\n\nReload the interface so OneForAll shows it?",
  button1 = "Reload",
  button2 = "Later",
  OnAccept = function() ReloadUI() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}
function NS.AskReload(text)
  StaticPopup_Show("ONEFORALL_NOSPOILERS_RELOAD", text)
end

-- Slash commands -------------------------------------------------------------------------------------

local function status()
  for _, m in ipairs(NS.order) do
    local state
    if m.failed then state = "|cffff6060off|r (" .. m.failed .. ")"
    elseif m.active then
      local ok, text = pcall(m.status or function() return "on" end)
      state = "|cff60ff60" .. (ok and text or "on") .. "|r"
    else state = "not started" end
    NS.Print(m.label .. ": " .. state)
  end
  NS.Print("Commands: /ofans status, /ofans reveal <dungeon>, /ofans legacy")
end

-- Diagnostic for the Legacy System (Forever's achievements): can addons read it, and does it track
-- dungeons? Prints what the client reports; changes nothing.
local function legacy()
  if not (GetCategoryList and GetCategoryInfo and GetAchievementInfo) then
    NS.Print("This client has no achievement functions for addons.")
    return
  end
  local cats = GetCategoryList() or {}
  NS.Print(#cats .. " achievement categories:")
  for _, c in ipairs(cats) do
    local name = GetCategoryInfo(c)
    local n = GetCategoryNumAchievements and GetCategoryNumAchievements(c) or 0
    NS.Print(string.format("  [%s] %s: %d", tostring(c), tostring(name), n or 0))
    if type(name) == "string" and (name:find("Dungeon") or name:find("Raid") or name:find("Legacy")) then
      for i = 1, math.min(n or 0, 10) do
        local id, aname, _, completed = GetAchievementInfo(c, i)
        local crit = id and GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
        NS.Print(string.format("    %s %s (%s criteria)%s", tostring(id), tostring(aname), tostring(crit), completed and " - done" or ""))
        for j = 1, math.min(crit or 0, 6) do
          local cname, _, cdone = GetAchievementCriteriaInfo(id, j)
          NS.Print(string.format("      - %s%s", tostring(cname), cdone and " (done)" or ""))
        end
      end
    end
  end
end

SLASH_ONEFORALLNOSPOILERS1 = "/ofans"
SlashCmdList.ONEFORALLNOSPOILERS = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "legacy" then
    local ok, err = pcall(legacy)
    if not ok then NS.Print("Legacy check failed: " .. tostring(err)) end
  elseif cmd == "reveal" then
    local m = NS.byKey.dungeons
    if m and m.active and m.reveal then m.reveal(rest) else NS.Print("The dungeon part is not running.") end
  else
    status()
  end
end
