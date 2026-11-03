local _, NS = ...

-- Armory: item sets and reputation rewards only list items this character has owned or seen (see Items.lua).
-- A set or faction with nothing seen yet is left out. A set with pieces still unseen gets "(1/6 seen)" after its
-- name, as OneForAll counts only the pieces it is given. New ones show after the next /reload.

local M = { key = "armory", label = "Armory sets and rewards" }
NS.AddModule(M)

local db
local counts = { sets = { 0, 0 }, factions = { 0, 0 } }

local function validItems(items)
  if type(items) ~= "table" then return false end
  for _, it in ipairs(items) do
    if type(it) ~= "table" or type(it[1]) ~= "number" then return false end
  end
  return true
end

-- keeps the seen items of each entry and drops entries with none; returns shown, total
local function filter(list, markNames)
  local total = #list
  for _, e in ipairs(list) do
    local all = #e.i
    NS.FilterInPlace(e.i, function(it) return db.items[it[1]] end)
    if markNames and #e.i > 0 and #e.i < all and type(e.n) == "string" then
      e.n = string.format("%s (%d/%d seen)", e.n, #e.i, all)
    end
  end
  NS.FilterInPlace(list, function(e) return #e.i > 0 end)
  return #list, total
end

function M.apply(FLT, saved)
  db = saved
  db.items = db.items or {}
  local sets, rep = FLT.ARMORY_SETS, FLT.ARMORY_REPUTATION
  if type(sets) ~= "table" and type(rep) ~= "table" then return false, "Armory data not found" end
  for _, list in ipairs({ sets or {}, rep or {} }) do
    for _, e in ipairs(list) do
      if type(e) ~= "table" or not validItems(e.i) then return false, "Armory entries look different" end
    end
  end
  for _, list in ipairs({ sets or {}, rep or {} }) do
    for _, e in ipairs(list) do
      for _, it in ipairs(e.i) do NS.WatchItem(it[1]) end
    end
  end
  if not NS.IsOn("armory") then counts = nil; return true end -- switched off: OneForAll shows everything
  if type(sets) == "table" then counts.sets = { filter(sets, true) } end
  if type(rep) == "table" then counts.factions = { filter(rep) } end
  return true
end

NS.Counter("armory", function()
  if counts then return string.format("%d of %d sets", counts.sets[1], counts.sets[2]) end
end)

function M.status()
  if not counts then return "not hidden (switched off)" end
  return string.format("%d of %d sets and %d of %d factions shown", counts.sets[1], counts.sets[2],
    counts.factions[1], counts.factions[2])
end
