local _, NS = ...

-- Gear Planner quest rewards: the Gear Planner suggests quest rewards from FLT.QUEST_REWARDS.items, one line
-- per item: "itemID,requiredLevel,questID[/questID],name". Only lines whose quest this character has seen
-- stay: offered to you (quest window), in your quest log, or completed. New ones show after the next
-- /reload. The quest details themselves (FLT.QUEST_REWARDS.quests) stay, as other OneForAll features such as
-- class quest chains read them.
-- The Gear Planner's other sources follow the other parts already: dungeon loot (Dungeons), crafted items
-- (Recipes), set and reputation items (Armory).

local M = { key = "gearquests", label = "Gear Planner quest rewards" }
NS.AddModule(M)

local IsQuestDone = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted

local db
local relevant = {} -- quest IDs that have gear rewards in the data
local counts = { 0, 0 }

local function seen(id)
  id = tonumber(id)
  if id and relevant[id] then db.quests[id] = true end
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
    for id in pairs(relevant) do
      if not db.quests[id] and IsQuestDone(id) then db.quests[id] = true end
    end
  end
  scanLog()
end

function M.apply(FLT, saved)
  db = saved
  db.quests = db.quests or {}
  local QR = FLT.QUEST_REWARDS
  if type(QR) ~= "table" or type(QR.items) ~= "string" then return false, "quest reward list not found" end
  local kept, total = {}, 0
  for line in QR.items:gmatch("[^\n]+") do
    local quests = line:match("^%d+,%d+,([%d/]+),")
    if not quests then return false, "quest reward entries look different" end
    total = total + 1
    local known = false
    for q in quests:gmatch("%d+") do
      q = tonumber(q)
      relevant[q] = true
      if db.quests[q] then known = true end
    end
    if known then kept[#kept + 1] = line end
  end
  QR.items = table.concat(kept, "\n")
  counts = { #kept, total }
  return true
end

M.events = {
  PLAYER_LOGIN = login,
  QUEST_DETAIL = function() if GetQuestID then seen(GetQuestID()) end end,
  QUEST_LOG_UPDATE = function() NS.Debounce(M, "quests-log", 1, scanLog) end,
  QUEST_TURNED_IN = function(id) seen(id) end,
}

function M.status()
  return string.format("%d of %d quest rewards shown", counts[1], counts[2])
end
