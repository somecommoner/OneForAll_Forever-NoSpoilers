local _, NS = ...

-- Places: map landmarks (flight masters, ships, zeppelins, the tram, zone transitions, Skyborne spots) and
-- Library Books appear once this character has been close to them.
--
-- Where the character has been is kept as a trail of cells: about 40 yards in world coordinates, plus 1 % of
-- the zone map as a fallback for clients or places without world coordinates. A place counts as "been close"
-- when a trail cell lies within REACH cells of it (about 80-100 yards). Both the trail and OneForAll's data
-- are turned into cells with the same client function, so the two always line up.
--
-- New discoveries are put back into OneForAll's list straight away. OneForAll builds its map icon index once,
-- so we ask it to rebuild with FLT.MapLandmarks._reset; if a later OneForAll version drops that function,
-- new icons simply appear after the next /reload instead.

local M = { key = "places", label = "Map icons and books" }
NS.AddModule(M)

local WORLD_CELL = 40 -- yards
local MAP_CELL = 1 -- percent of the zone map
local REACH = 2 -- cells

local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local IsQuestDone = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted

local db, trail
local hidden = {} -- every entry taken out of OneForAll's lists (revealed ones stay, marked)
local bucketW, bucketM = {}, {} -- cell -> hidden entries there, for the trail check
local counts = {} -- source name -> { shown, total }
local skipped = {} -- sources left untouched (data looked different)
local live -- true once OneForAll's map index could be rebuilt

local function vecXY(v)
  if not v then return end
  if v.GetXY then
    local ok, x, y = pcall(v.GetXY, v)
    if ok then return x, y end
  end
  if v.x and v.y then return v.x, v.y end
end

local function key(a, b) return a .. ":" .. b end

-- mapID + position (0..1) -> continent, world cell
local function worldCell(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
  if not ok or type(cont) ~= "number" then return end
  local wx, wy = vecXY(pos)
  if type(wx) ~= "number" or type(wy) ~= "number" then return end
  return cont, math.floor(wx / WORLD_CELL), math.floor(wy / WORLD_CELL)
end

local function mapCell(x, y) return math.floor(x * 100 / MAP_CELL), math.floor(y * 100 / MAP_CELL) end

local function near(cells, cx, cy)
  if not cells then return false end
  for dx = -REACH, REACH do
    for dy = -REACH, REACH do
      if cells[key(cx + dx, cy + dy)] then return true end
    end
  end
  return false
end

local function place(e)
  local mapID, x, y = e.getPos(e.item)
  e.mapID, e.x, e.y = mapID, x, y
  if not mapID then return end
  e.wc, e.wx, e.wy = worldCell(mapID, x, y)
  e.mx, e.my = mapCell(x, y)
end

local function visited(e)
  if not e.mapID then return false end
  if e.wc and near(trail.w[e.wc], e.wx, e.wy) then return true end
  return near(trail.m[e.mapID], e.mx, e.my)
end

local function addTo(bucket, k1, k2, e)
  local t = bucket[k1]
  if not t then t = {}; bucket[k1] = t end
  local l = t[k2]
  if not l then l = {}; t[k2] = l end
  l[#l + 1] = e
end

local function index(e)
  if not e.mapID then return end
  if e.wc then addTo(bucketW, e.wc, key(e.wx, e.wy), e) end
  addTo(bucketM, e.mapID, key(e.mx, e.my), e)
end

-- OneForAll: rebuild the map icon index and redraw if the map is open
local function refreshMap()
  local LM = NS.FLT.MapLandmarks
  if type(LM) ~= "table" then return end
  if type(LM._reset) == "function" then
    LM._reset()
    live = true
  else
    live = false
  end
  if type(LM.Refresh) == "function" then pcall(LM.Refresh) end
end

local function reveal(e)
  if e.revealed then return end
  e.revealed = true
  table.insert(e.list, e.item)
  local c = counts[e.source]
  if c then c[1] = c[1] + 1 end
  if e.onReveal then e.onReveal(e.item) end
  NS.Debounce(M, "places-map", 0.3, refreshMap)
end

-- Sources ---------------------------------------------------------------------------------------------

-- { mapID, x, y, ... } with x / y in percent: OneForAll's landmark, Skyborne and zone transition lists
local function arrayPos(item)
  local mapID, x, y = item[1], item[2], item[3]
  if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then return mapID, x / 100, y / 100 end
end

local function bookPos(b)
  if type(b.x) ~= "number" or type(b.y) ~= "number" or type(b.zone) ~= "string" then return end
  local FLT = NS.FLT
  local id = type(FLT.MAP_IDS) == "table" and FLT.MAP_IDS[b.zone] or nil
  if not id and type(FLT.FindMapID) == "function" then
    local ok, r = pcall(FLT.FindMapID, FLT, b.zone)
    if ok then id = r end
  end
  if type(id) ~= "number" then return end
  return id, b.x / 100, b.y / 100
end

-- Takes the undiscovered entries out of one OneForAll list. needPos: every entry must have a position,
-- otherwise the list looks different from what we expect and stays as it is.
local function filterList(name, list, getPos, opts)
  if type(list) ~= "table" then return end
  for _, item in ipairs(list) do
    if type(item) ~= "table" then skipped[#skipped + 1] = name; return end
    if opts.needPos and not getPos(item) then skipped[#skipped + 1] = name; return end
  end
  local entries = {}
  local removed = NS.FilterInPlace(list, function(item)
    local e = { item = item, list = list, getPos = getPos, source = name, onReveal = opts.onReveal }
    place(e)
    if (opts.known and opts.known(item)) or visited(e) then return true end
    entries[item] = e
    return false
  end)
  for _, item in ipairs(removed) do
    local e = entries[item]
    hidden[#hidden + 1] = e
    index(e)
  end
  counts[name] = { #list, #list + #removed }
end

-- Trail -----------------------------------------------------------------------------------------------

local function mark(cells, k1, cx, cy, bucket)
  local t = cells[k1]
  if not t then t = {}; cells[k1] = t end
  local k = key(cx, cy)
  if t[k] then return end
  t[k] = true
  local b = bucket[k1]
  if not b then return end
  for dx = -REACH, REACH do
    for dy = -REACH, REACH do
      local l = b[key(cx + dx, cy + dy)]
      if l then for _, e in ipairs(l) do reveal(e) end end
    end
  end
end

local function tick()
  if IsInInstance and IsInInstance() then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return end
  local x, y = vecXY(C_Map.GetPlayerMapPosition(mapID, "player"))
  if type(x) ~= "number" or type(y) ~= "number" or NS.IsSecret(x) or NS.IsSecret(y) then return end
  if x == 0 and y == 0 then return end
  local mx, my = mapCell(x, y)
  mark(trail.m, mapID, mx, my, bucketM)
  local wc, wx, wy = worldCell(mapID, x, y)
  if wc then mark(trail.w, wc, wx, wy, bucketW) end
end

-- Books you own or turned in count as found, also without a position
local function checkBooks()
  for _, e in ipairs(hidden) do
    if not e.revealed and e.source == "books" then
      local b = e.item
      local has = type(b.itemId) == "number" and GetItemCount and (GetItemCount(b.itemId, true) or 0) > 0
      local done = type(b.questId) == "number" and IsQuestDone and IsQuestDone(b.questId)
      if has or done then reveal(e) end
    end
  end
end

-- At login the map data is certainly ready: place everything again (positions that could not be read at
-- load time get a second chance) and rebuild the cell index.
local function login()
  wipe(bucketW); wipe(bucketM)
  for _, e in ipairs(hidden) do
    if not e.revealed then
      place(e)
      if visited(e) then reveal(e) else index(e) end
    end
  end
  checkBooks()
  C_Timer.NewTicker(1, function() if M.active then NS.Safe(M, tick) end end)
end

-- Part ------------------------------------------------------------------------------------------------

function M.apply(FLT, saved)
  db = saved
  db.trail = db.trail or {}
  db.trail.w = db.trail.w or {}
  db.trail.m = db.trail.m or {}
  db.books = db.books or {}
  trail = db.trail

  local lm = FLT.MAP_LANDMARKS
  if type(lm) == "table" then
    for _, sub in ipairs({ "flight", "zeppelin", "ship", "air", "tram" }) do
      filterList(sub, lm[sub], arrayPos, { needPos = true })
    end
  end
  if type(FLT.SKYBORNE_SPOTS) == "table" then
    filterList("ley lines", FLT.SKYBORNE_SPOTS.ley, arrayPos, { needPos = true })
    filterList("convergences", FLT.SKYBORNE_SPOTS.conv, arrayPos, { needPos = true })
  end
  filterList("zone transitions", FLT.ZONE_TRANSITIONS, arrayPos, { needPos = true })
  filterList("books", FLT.BOOKS, bookPos, {
    known = function(b) return b.itemId ~= nil and db.books[b.itemId] end,
    onReveal = function(b) if b.itemId ~= nil then db.books[b.itemId] = true end end,
  })

  if not next(counts) then return false, "none of OneForAll's map or book lists were found" end
  if #skipped > 0 then
    NS.Print("Left these unhidden because their data looks different: " .. table.concat(skipped, ", ") .. ".")
  end
  return true
end

M.events = {
  PLAYER_LOGIN = login,
  BAG_UPDATE_DELAYED = checkBooks,
  BANKFRAME_OPENED = checkBooks,
  QUEST_TURNED_IN = function() NS.Debounce(M, "places-books", 1, checkBooks) end,
}

function M.status()
  local icons, iconsTotal = 0, 0
  for name, c in pairs(counts) do
    if name ~= "books" then icons, iconsTotal = icons + c[1], iconsTotal + c[2] end
  end
  local b = counts.books or { 0, 0 }
  local cells = 0
  for _, t in pairs(trail.w) do for _ in pairs(t) do cells = cells + 1 end end
  local liveText = live == false and ", new icons after /reload" or ""
  return string.format("%d of %d map icons, %d of %d books, %d places visited%s", icons, iconsTotal, b[1], b[2], cells, liveText)
end
