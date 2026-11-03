local _, NS = ...

-- Quest rewards: lists of rewards that belong to a quest only show once this character has seen that quest:
-- offered to you (quest window), in your quest log, or completed. New ones show after the next /reload.
--
-- * Gear Planner quest rewards: FLT.QUEST_REWARDS.items, one line per item "itemID,requiredLevel,questID[/questID],name".
--   The quest details (FLT.QUEST_REWARDS.quests) stay, as other OneForAll features such as class quest chains
--   read them. The Gear Planner's other sources follow the other parts already: dungeon loot (Dungeons),
--   crafted items (Recipes), set and reputation items (Armory), enchants (Enchants).
-- * Library Book reward tiers (Books tab): FLT.BOOK_REWARD_TIERS, one entry per tier with its questID.

local M = { key = "quests", label = "Quest rewards" }
NS.AddModule(M)

local IsQuestDone = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted

local db
local watched = {} -- quest IDs that have rewards in the filtered lists
local counts = { gear = { 0, 0 }, tiers = { 0, 0 } }

local function seen(id)
  id = tonumber(id)
  if id and watched[id] then db.quests[id] = true end
end

local function scanLog()
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if type(info) == "table" and not info.isHeader then seen(info.questID) end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
      if not isHeader then seen(questID) end
    end
  end
end

local function login()
  if IsQuestDone then
    for id in pairs(watched) do
      if not db.quests[id] and IsQuestDone(id) then db.quests[id] = true end
    end
  end
  scanLog()
end

-- Gear Planner lines; returns false, reason when the data looks different (then nothing is changed)
local function filterGear(QR)
  if type(QR) ~= "table" or type(QR.items) ~= "string" then return false, "quest reward list not found" end
  local lines = {}
  for line in QR.items:gmatch("[^\n]+") do
    local quests = line:match("^%d+,%d+,([%d/]+),")
    if not quests then return false, "quest reward entries look different" end
    lines[#lines + 1] = { line = line, quests = quests }
  end
  local on = NS.IsOn("gearquests")
  local kept = {}
  for _, l in ipairs(lines) do
    local known = false
    for q in l.quests:gmatch("%d+") do
      q = tonumber(q)
      watched[q] = true
      if db.quests[q] then known = true end
    end
    if known or not on then kept[#kept + 1] = l.line end
  end
  if on then QR.items = table.concat(kept, "\n") end
  counts.gear = on and { #kept, #lines } or nil
  return true
end

local function filterTiers(tiers)
  if type(tiers) ~= "table" then return false, "book reward tiers not found" end
  for _, t in ipairs(tiers) do
    if type(t) ~= "table" or type(t.questID) ~= "number" then return false, "book reward tiers look different" end
  end
  local total = #tiers
  for _, t in ipairs(tiers) do watched[t.questID] = true end
  if not NS.IsOn("books") then counts.tiers = nil; return true end
  NS.FilterInPlace(tiers, function(t) return db.quests[t.questID] end)
  counts.tiers = { #tiers, total }
  return true
end

function M.apply(FLT, saved)
  db = saved
  db.quests = db.quests or {}
  local gearOK, gearWhy = filterGear(FLT.QUEST_REWARDS)
  local tiersOK, tiersWhy = filterTiers(FLT.BOOK_REWARD_TIERS)
  if not gearOK and not tiersOK then return false, gearWhy end
  if not gearOK then NS.Print("Gear Planner quest rewards are not hidden: " .. gearWhy .. ".") end
  if not tiersOK then NS.Print("Library Book reward tiers are not hidden: " .. tiersWhy .. ".") end
  return true
end

M.events = {
  PLAYER_LOGIN = login,
  QUEST_DETAIL = function() if GetQuestID then seen(GetQuestID()) end end,
  QUEST_LOG_UPDATE = function() NS.Debounce(M, "quests-log", 1, scanLog) end,
  QUEST_TURNED_IN = function(id) seen(id) end,
}

local function part(c, word)
  if c then return string.format("%d of %d %s", c[1], c[2], word) end
end
NS.Counter("gearquests", function() return part(counts.gear, "shown") end)
NS.Counter("books", function() return part(counts.tiers, "reward tiers") end)

function M.status()
  return string.format("%s, %s", part(counts.gear, "Gear Planner quest rewards shown") or "Gear Planner quest rewards not hidden",
    part(counts.tiers, "book reward tiers shown") or "book reward tiers not hidden")
end
