local _, NS = ...

-- Zone level ranges: OneForAll shows a zone's level range at the top right of its map and after its name on the
-- continent map, from FLT.ZONE_LEVELS[uiMapID] = { min, max }. Only zones this character has stood in keep
-- their range. A newly entered zone gets its range back straight away; OneForAll reads it fresh for the zone
-- map, while the continent map's name list is built once per session and picks it up after the next /reload.

local M = { key = "zones", label = "Zone level ranges" }
NS.AddModule(M)

local db, levels
local hidden = {} -- uiMapID -> range taken out of OneForAll's table
local total = 0

local function reveal(id)
  local range = hidden[id]
  if range then
    levels[id] = range
    hidden[id] = nil
  end
end

-- the map you are on and the maps it lies in (a cave lies in its zone), up to the continent
local function enter()
  if IsInInstance and IsInInstance() then return end
  local id = C_Map.GetBestMapForUnit("player")
  for _ = 1, 6 do
    if type(id) ~= "number" or id == 0 then return end
    local info = C_Map.GetMapInfo(id)
    if not info or (Enum and Enum.UIMapType and info.mapType and info.mapType <= Enum.UIMapType.Continent) then return end
    if not db.zones[id] then db.zones[id] = true end
    reveal(id)
    id = info.parentMapID
  end
end

function M.apply(FLT, saved)
  db = saved
  db.zones = db.zones or {}
  levels = FLT.ZONE_LEVELS
  if type(levels) ~= "table" then return false, "zone level list not found" end
  for id, range in pairs(levels) do
    if type(id) ~= "number" or type(range) ~= "table" or type(range[1]) ~= "number" then
      return false, "zone level entries look different"
    end
  end
  for id, range in pairs(levels) do
    total = total + 1
    if not db.zones[id] then hidden[id] = range end
  end
  for id in pairs(hidden) do levels[id] = nil end
  return true
end

local function enterSoon() NS.Debounce(M, "zones-enter", 1, enter) end

M.events = {
  PLAYER_LOGIN = function()
    enter()
    C_Timer.NewTicker(5, function() if M.active then NS.Safe(M, enter) end end)
  end,
  ZONE_CHANGED_NEW_AREA = enterSoon,
  PLAYER_ENTERING_WORLD = enterSoon,
}

function M.status()
  local shown = 0
  for _ in pairs(levels) do shown = shown + 1 end
  return string.format("%d of %d zones", shown, total)
end
