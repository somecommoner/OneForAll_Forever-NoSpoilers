local _, NS = ...

-- Gear Planner enchants: the Gear Planner suggests enchants, armor kits, scopes, spurs, shield spikes and the
-- like for each slot from FLT.ENCHANT_OPTIONS. Only options this character can know about stay: the recipe is
-- learnt (see Professions.lua), or the item that applies it has been owned or seen (see Items.lua). Enchanting
-- enchants are spells, not items, so they only show for enchanters. New ones show after the next /reload.

local M = { key = "enchants", label = "Gear Planner enchants" }
NS.AddModule(M)

local counts = { 0, 0 }

function M.apply(FLT, saved)
  saved.recipes = saved.recipes or {}
  saved.items = saved.items or {}
  local list = FLT.ENCHANT_OPTIONS
  if type(list) ~= "table" then return false, "enchant list not found" end
  for _, o in ipairs(list) do
    if type(o) ~= "table" then return false, "enchant entries look different" end
  end
  local total = #list
  for _, o in ipairs(list) do
    if type(o.s) == "number" then NS.WatchRecipeSpell(o.s) end
    if type(o.i) == "number" then NS.WatchItem(o.i) end
  end
  NS.FilterInPlace(list, function(o)
    return (o.s ~= nil and saved.recipes[o.s]) or (o.i ~= nil and saved.items[o.i])
  end)
  counts = { #list, total }
  return true
end

function M.status()
  return string.format("%d of %d enchant options shown", counts[1], counts[2])
end
