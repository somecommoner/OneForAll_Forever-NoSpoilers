local _, NS = ...

-- What's New: OneForAll opens its "Noteworthy changes" window through FLT.ShowNews (at login, /ofa news and
-- the Settings button). That one public function is replaced with a short chat note.
local News = { key = "news", label = "What's New window" }
NS.AddModule(News)

function News.apply(FLT)
  if type(FLT.ShowNews) ~= "function" then return false, "its window function was not found" end
  FLT.ShowNews = function() NS.Print("OneForAll's What's New window is hidden.") end
  return true
end
function News.status() return "hidden" end

-- Remove Fog: OneForAll's Quality of Life option uncovers unexplored map areas from FLT.MAP_OVERLAYS.
-- Emptying that table makes the option uncover nothing; the game's own explored areas are unaffected.
local Fog = { key = "fog", label = "Remove Fog" }
NS.AddModule(Fog)

function Fog.apply(FLT)
  if type(FLT.MAP_OVERLAYS) ~= "table" then return false, "its map data was not found" end
  wipe(FLT.MAP_OVERLAYS)
  return true
end
function Fog.status() return "off" end
