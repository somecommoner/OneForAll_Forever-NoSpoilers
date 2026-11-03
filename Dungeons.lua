local _, NS = ...

-- Dungeons and raids: a dungeon exists in OneForAll (Dungeons tab, entrance icon, Gear Planner sources,
-- "Drops from" tooltips, quest sharing) once this character has been inside it.
--
-- OneForAll builds its dungeon views once per session, so a newly entered dungeon is added at the next
-- reload; a prompt offers one. Which dungeon you are in follows OneForAll's own way (FLT.FindCurrentDungeon):
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
  if #names > 0 then NS.AskReload("Discovered: " .. table.concat(names, ", ") .. ".") end
end

local function check()
  local inInstance, kind = IsInInstance()
  if not inInstance or (kind ~= "party" and kind ~= "raid") then return end
  discover(currentDungeons())
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
  NS.FilterInPlace(list, function(d) return db.dungeons[d.name] end)
  return true
end

M.events = {
  PLAYER_ENTERING_WORLD = checkSoon,
  ZONE_CHANGED_NEW_AREA = checkSoon,
}

function M.status()
  local n = 0
  for _, d in ipairs(all) do if db.dungeons[d.name] then n = n + 1 end end
  return string.format("%d of %d discovered", n, #all)
end
