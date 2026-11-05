local _, NS = ...

-- Dungeons and raids: a dungeon exists in OneForAll (Dungeons tab, entrance icon, Gear Planner sources,
-- "Drops from" tooltips, quest sharing) once this character has cleared it.
--
-- Cleared means done in the Legacy System (Forever's achievements): the Spelunker achievements have one
-- criterion per dungeon. "Ragefire Chasm or Hall of Thanes" counts the one on the player's side.
-- Dungeons the Legacy record doesn't track, and raids (their criteria are bosses), show once entered.
-- If the record can't be read or is account-wide (it would reveal what other characters did), every
-- dungeon shows once entered.
--
-- OneForAll builds its dungeon views once per session, so a new dungeon is added at the next reload; a
-- prompt offers one. Which dungeon you are in follows OneForAll's own way (FLT.FindCurrentDungeon):
-- the instance ID, the map for Scarlet Monastery's wings, else the name. Wings that share one instance and
-- cannot be told apart (Dire Maul, Blackrock Spire) are all counted as entered.

local M = { key = "dungeons", label = "Dungeons" }
NS.AddModule(M)

local db
local all = {} -- OneForAll's full dungeon list, as loaded

local function normalize(s)
  return (tostring(s or ""):lower():gsub("^the ", ""):gsub("[^%w]", ""))
end

local function currentDungeons()
  local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  local uiMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local byID = {}
  for _, d in ipairs(all) do
    if d.instanceID and instanceID and d.instanceID == instanceID then
      if d.uiMaps and uiMap then
        for _, m in ipairs(d.uiMaps) do if m == uiMap then return { d } end end
      end
      byID[#byID + 1] = d
    end
  end
  if #byID > 0 then return byID end
  local wanted = normalize(name)
  if wanted == "" then return {} end
  for _, d in ipairs(all) do
    if normalize(d.name) == wanted then return { d } end
  end
  -- loose match ("Excavation Site" vs "Excavation Site: Wetlands")
  for _, d in ipairs(all) do
    local dn = normalize(d.name)
    if dn:find(wanted, 1, true) or wanted:find(dn, 1, true) then return { d } end
  end
  return {}
end

local function discover(list)
  local names = {}
  for _, d in ipairs(list) do
    if not db.dungeons[d.name] then
      db.dungeons[d.name] = true
      names[#names + 1] = d.short or d.name
    end
  end
  if #names > 0 and NS.IsOn("dungeons") then NS.AskReload("Discovered: " .. table.concat(names, ", ") .. ".") end
end

local LEGACY = { 62031, 62032, 62033 } -- Novice, Experienced and Master Spelunker
local ACCOUNT_WIDE = 0x20000 -- achievement flag

-- Returns { covered = {name = true}, done = {name = true}, unmatched = {criterion names} },
-- or nil and a reason when the record can't be used.
local function readLegacy()
  if not (GetAchievementInfo and GetAchievementNumCriteria and GetAchievementCriteriaInfo) then
    return nil, "this client has no achievement functions"
  end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local r = { covered = {}, done = {}, unmatched = {} }
  for _, id in ipairs(LEGACY) do
    local aid, _, _, _, _, _, _, _, flags = GetAchievementInfo(id)
    if not aid or type(flags) ~= "number" then return nil, "the Spelunker achievements were not found" end
    if flags % (2 * ACCOUNT_WIDE) >= ACCOUNT_WIDE then return nil, "the Legacy record is account-wide" end
    for j = 1, GetAchievementNumCriteria(id) or 0 do
      local cname, _, cdone = GetAchievementCriteriaInfo(id, j)
      local options, matches = {}, {}
      for part in (tostring(cname) .. " or "):gmatch("(.-) or ") do options[normalize(part)] = true end
      for _, d in ipairs(all) do
        if options[normalize(d.name)] then matches[#matches + 1] = d end
      end
      if #matches == 0 then r.unmatched[#r.unmatched + 1] = tostring(cname) end
      for _, d in ipairs(matches) do
        r.covered[d.name] = true
        if cdone and (#matches == 1 or d.territory == faction) then r.done[d.name] = true end
      end
    end
  end
  return r
end

local legacyProblem -- why the Legacy record isn't used, once known
local function check()
  local ok, r, reason = pcall(readLegacy)
  if not (ok and r) then
    reason = ok and reason or tostring(r)
    if legacyProblem == nil and NS.IsOn("dungeons") then
      NS.Print("Dungeons show once entered, not cleared: " .. reason .. ".")
    end
    legacyProblem = reason
    r = { covered = {}, done = {} }
  else
    legacyProblem = false
  end
  local list = {}
  for _, d in ipairs(all) do
    if r.done[d.name] then list[#list + 1] = d end
  end
  local inInstance, kind = IsInInstance()
  if inInstance and (kind == "party" or kind == "raid") then
    for _, d in ipairs(currentDungeons()) do
      if not r.covered[d.name] then list[#list + 1] = d end
    end
  end
  discover(list)
end

-- /ofans legacy
function M.legacySummary()
  local ok, r, reason = pcall(readLegacy)
  if not (ok and r) then
    NS.Print("Dungeons show once entered, not cleared: " .. tostring(ok and reason or r) .. ".")
    return
  end
  local tracked, cleared, untracked = 0, 0, {}
  for _, d in ipairs(all) do
    if r.covered[d.name] then
      tracked = tracked + 1
      if r.done[d.name] then cleared = cleared + 1 end
    elseif not d.raid then
      untracked[#untracked + 1] = d.short or d.name
    end
  end
  NS.Print(string.format("The Legacy record is per character. It tracks %d dungeons; this character has cleared %d.", tracked, cleared))
  if #untracked > 0 then NS.Print("Shown once entered (not tracked): " .. table.concat(untracked, ", ")) end
  if #r.unmatched > 0 then NS.Print("Criteria with no OneForAll dungeon: " .. table.concat(r.unmatched, ", ")) end
end

-- after a loading screen the map can take a moment to settle (Scarlet Monastery wings)
local function checkSoon() NS.Debounce(M, "dungeons-check", 2, check) end

function M.reveal(text)
  local wanted = normalize(text)
  if wanted == "" then NS.Print("Usage: /ofans reveal <dungeon name>"); return end
  local list = {}
  for _, d in ipairs(all) do
    if normalize(d.name):find(wanted, 1, true) or normalize(d.short):find(wanted, 1, true) then list[#list + 1] = d end
  end
  if #list == 0 then NS.Print("No dungeon matches \"" .. text .. "\"."); return end
  local before = 0
  for _ in pairs(db.dungeons) do before = before + 1 end
  discover(list)
  local after = 0
  for _ in pairs(db.dungeons) do after = after + 1 end
  if after == before then NS.Print("Already discovered.") end
end

function M.apply(FLT, saved)
  db = saved
  db.dungeons = db.dungeons or {}
  local list = FLT.DUNGEONS
  if type(list) ~= "table" then return false, "dungeon list not found" end
  for _, d in ipairs(list) do
    if type(d) ~= "table" or type(d.name) ~= "string" then return false, "dungeon entries look different" end
  end
  for i, d in ipairs(list) do all[i] = d end
  -- switched off: OneForAll shows them all, entering still records
  if NS.IsOn("dungeons") then NS.FilterInPlace(list, function(d) return db.dungeons[d.name] end) end
  return true
end

M.events = {
  PLAYER_ENTERING_WORLD = checkSoon,
  ZONE_CHANGED_NEW_AREA = checkSoon,
  CRITERIA_UPDATE = checkSoon, -- a clear shows straight away
}

local function discovered()
  local n = 0
  for _, d in ipairs(all) do if db.dungeons[d.name] then n = n + 1 end end
  return string.format("%d of %d discovered", n, #all)
end
NS.Counter("dungeons", function() return M.active and discovered() end)

function M.status()
  if not NS.IsOn("dungeons") then return discovered() .. " (not hidden: switched off)" end
  if legacyProblem then return discovered() .. " (once entered: " .. legacyProblem .. ")" end
  return discovered() .. " (once cleared)"
end
