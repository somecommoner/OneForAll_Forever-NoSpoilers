local _, NS = ...

-- What's New: OneForAll opens its "Noteworthy changes" window through FLT.ShowNews (at login, /ofa news and
-- the Settings button). That one public function is replaced with a short chat note.
local News = { key = "news", label = "What's New window" }
NS.AddModule(News)

function News.apply(FLT)
  if not NS.IsOn("news") then return true end
  if type(FLT.ShowNews) ~= "function" then return false, "its window function was not found" end
  FLT.ShowNews = function() NS.Print("OneForAll's What's New window is hidden.") end
  return true
end
function News.status() return NS.IsOn("news") and "hidden" or "shown (switched off)" end

-- Remove Fog: OneForAll's Quality of Life option uncovers unexplored map areas from FLT.MAP_OVERLAYS.
-- Emptying that table makes the option uncover nothing; the game's own explored areas are unaffected.
local Fog = { key = "fog", label = "Remove Fog" }
NS.AddModule(Fog)

function Fog.apply(FLT)
  if not NS.IsOn("fog") then return true end
  if type(FLT.MAP_OVERLAYS) ~= "table" then return false, "its map data was not found" end
  wipe(FLT.MAP_OVERLAYS)
  return true
end
function Fog.status() return NS.IsOn("fog") and "disabled" or "left to OneForAll's setting (switched off)" end

-- Book alerts once: OneForAll's "Library Book nearby" popup comes up every time you come back near a book you
-- haven't picked up. FLT:ShowNearbyBookAlert (its one public function for it) is wrapped so each book alerts
-- this character only the first time. Seen books are kept per character by item ID.
local BookAlert = { key = "bookalert", label = "Book alerts once" }
NS.AddModule(BookAlert)

function BookAlert.apply(FLT, db)
  db.bookAlerted = db.bookAlerted or {}
  if not NS.IsOn("bookalert") then return true end
  local show = FLT.ShowNearbyBookAlert
  if type(show) ~= "function" then return false, "its book alert function was not found" end
  FLT.ShowNearbyBookAlert = function(self, book, ...)
    local id = type(book) == "table" and book.itemId or nil
    if id ~= nil then
      if db.bookAlerted[id] then return end
      db.bookAlerted[id] = true
    end
    return show(self, book, ...)
  end
  return true
end
function BookAlert.status()
  if not NS.IsOn("bookalert") then return "every time (switched off)" end
  local n = 0
  for _ in pairs(NS.db.bookAlerted or {}) do n = n + 1 end
  return "once per book (" .. n .. " alerted)"
end
