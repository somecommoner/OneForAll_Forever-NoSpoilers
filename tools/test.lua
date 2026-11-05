-- Offline test for OneForAll_NoSpoilers: loads OneForAll's real data files and our addon with a small
-- stand-in for the WoW API, then plays through a fresh character, discoveries and a second login.
-- Usage: lua5.4 test_nospoilers.lua <OneForAll dir> <NoSpoilers dir>

local OFA, NSDIR = arg[1], arg[2]
local unpack = table.unpack
local fails = 0
local function check(cond, what)
  if cond then print("  ok   " .. what) else print("  FAIL " .. what); fails = fails + 1 end
end

-- WoW API stand-in -----------------------------------------------------------------------------------
local chat, popups, timers, tickers = {}, {}, {}, {}
local world -- per-session state
local function api()
  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  _G.strsplit = function(sep, s)
    local out = {}
    for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
    return unpack(out)
  end
  _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
  _G.StaticPopupDialogs = {}
  _G.StaticPopup_Show = function(_, text) popups[#popups + 1] = text end
  _G.ReloadUI = function() end
  _G.SlashCmdList = {}
  _G.C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn end,
  }
  local frames = {}
  local stubMeta
  local function stub() return setmetatable({}, stubMeta) end
  stubMeta = { __index = function() return function() return stub() end end }
  _G.CreateFrame = function()
    local f = setmetatable({ events = {} }, stubMeta)
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(what, fn) if what == "OnEvent" then self.onEvent = fn end end
    function f:GetChecked() return true end
    frames[#frames + 1] = f
    return f
  end
  _G.fire = function(event, ...)
    for _, f in ipairs(frames) do
      if f.onEvent and (f.events[event]) then f.onEvent(f, event, ...) end
    end
  end
  _G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end
  -- fake world: every map is a 1000 x 1000 yard square, maps side by side on continent 1
  _G.C_Map = {
    GetWorldPosFromMapPos = function(mapID, v) return 1, CreateVector2D(mapID * 2000 + v.x * 1000, v.y * 1000) end,
    GetBestMapForUnit = function() return world.map end,
    GetPlayerMapPosition = function() return world.x and CreateVector2D(world.x, world.y) end,
    GetMapInfo = function(id)
      if id == 9999 then return { mapID = id, mapType = 2 } end
      return { mapID = id, mapType = 3, parentMapID = 9999 }
    end,
  }
  _G.IsInInstance = function() return world.instance ~= nil, world.instance and world.instance.kind end
  _G.GetInstanceInfo = function()
    local i = world.instance or {}
    return i.name, i.kind, 0, "", 5, 0, false, i.id
  end
  _G.Enum = { UIMapType = { Continent = 2 } }
  _G.UnitClass = function() return "Hunter", "HUNTER" end
  _G.UnitExists = function(u) return u == "pet" and world.pet ~= nil end
  _G.UnitGUID = function(u) return u == "pet" and world.pet and world.pet.guid or nil end
  _G.UnitCreatureFamily = function(u) return u == "pet" and world.pet and world.pet.family or nil end
  _G.GetTime = function() return 100 end
  _G.IsPlayerSpell = function(s) return world.spells[s] == true end
  _G.GetItemCount = function(id) return world.bags[id] and 1 or 0 end
  _G.GetInventoryItemID = function() return nil end
  _G.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #world.bagList or 0 end,
    GetContainerItemID = function(_, slot) return world.bagList[slot] end,
  }
  _G.C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetNumQuestLogEntries = function() return 0 end,
    GetInfo = function() return nil end }
  _G.GetQuestID = function() return world.questDetail end
end

local function runTimers()
  for _ = 1, 5 do
    local list = timers; timers = {}
    for _, fn in ipairs(list) do fn() end
  end
end

-- Loading ---------------------------------------------------------------------------------------------
local function tocFiles(dir, name)
  local list = {}
  for line in io.lines(dir .. "/" .. name) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then list[#list + 1] = line:gsub("\\", "/") end
  end
  return list
end

local function loadOneForAll()
  local FLT = {}
  local isData = function(f)
    return f:match("^Data/") or f == "Data.lua" or f == "ExtraData.lua" or f == "ProfessionData.lua"
      or f == "DungeonRegistry.lua" or f == "DungeonData.lua"
  end
  for _, f in ipairs(tocFiles(OFA, "OneForAll.toc")) do
    if isData(f) then
      local chunk = assert(loadfile(OFA .. "/" .. f))
      chunk("OneForAll", FLT)
    end
  end
  -- the bits of OneForAll's code that we call
  FLT.ShowNews = function() FLT.newsShown = true end
  FLT.resets = 0
  FLT.MapLandmarks = { _reset = function() FLT.resets = FLT.resets + 1 end, Refresh = function() end }
  FLT.FindMapID = function(self, zone) return self.MAP_IDS[zone] end
  FLT.GetStabledPets = function() return {} end
  _G.OneForAll = FLT
  return FLT
end

local function loadAddon()
  local NS = {}
  for _, f in ipairs(tocFiles(NSDIR, "OneForAll_NoSpoilers.toc")) do
    local chunk = assert(loadfile(NSDIR .. "/" .. f))
    chunk("OneForAll_NoSpoilers", NS)
  end
  return NS
end

local function session(saved, settings)
  chat, popups, timers, tickers = {}, {}, {}, {}
  world = { spells = {}, bags = {}, bagList = {} }
  api()
  local FLT = loadOneForAll()
  local full = {
    dungeons = #FLT.DUNGEONS, flight = #FLT.MAP_LANDMARKS.flight, books = #FLT.BOOKS,
    firstFlight = FLT.MAP_LANDMARKS.flight[1], firstBook = FLT.BOOKS[1],
    firstSetItem = FLT.ARMORY_SETS[1].i[1][1], firstSet = FLT.ARMORY_SETS[1].n, firstSetSize = #FLT.ARMORY_SETS[1].i,
    recipe = FLT.PROFESSION_RECIPES["Alchemy"][1].s,
    zones = (function() local n = 0; for _ in pairs(FLT.ZONE_LEVELS) do n = n + 1 end; return n end)(),
    weaponMaster = FLT.WEAPON_TRAINERS[1],
    campingItem = FLT.CAMPING_PROFESSIONS[1].items[1],
    campingProf = FLT.CAMPING_PROFESSIONS[1].profession,
    enchantItem = (function() for _, o in ipairs(FLT.ENCHANT_OPTIONS) do if o.i and not o.s then return o end end end)(),
    enchantCount = #FLT.ENCHANT_OPTIONS,
    tier = FLT.BOOK_REWARD_TIERS[1],
    campSpell = (function()
      local item = FLT.CAMPING_PROFESSIONS[1].items[1].id
      for _, list in pairs(FLT.PROFESSION_RECIPES) do for _, r in ipairs(list) do if r.i == item then return r.s end end end
    end)(),
    overlays = next(FLT.MAP_OVERLAYS) ~= nil,
    giver = (function()
      local raw = FLT.QUEST_PINS[1429] -- Elwynn Forest
      local x, y, name = raw:match("!([%d.]+),([%d.]+),([^\n]*)")
      return { map = 1429, x = tonumber(x), y = tonumber(y), name = name }
    end)(),
    pinCounts = (function()
      local giv, turn = 0, 0
      for _, raw in pairs(FLT.QUEST_PINS) do
        for line in raw:gmatch("[^\n]+") do
          if line:sub(1, 1) == "!" then giv = giv + 1 elseif line:sub(1, 1) == "?" then turn = turn + 1 end
        end
      end
      return { giv, turn }
    end)(),
    rewardLine = FLT.QUEST_REWARDS.items:match("^[^\n]+"),
  }
  _G.OneForAllNoSpoilersCharDB = saved
  _G.OneForAllNoSpoilersDB = settings
  local NS = loadAddon()
  fire("ADDON_LOADED", "OneForAll")
  fire("ADDON_LOADED", "OneForAll_NoSpoilers")
  return FLT, NS, full
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

-- 1. Fresh character -----------------------------------------------------------------------------------
print("Session 1: fresh character")
local FLT, NS, full = session(nil)
print(("  data: %d dungeons, %d flight masters, %d books"):format(full.dungeons, full.flight, full.books))
check(full.dungeons > 30 and full.flight > 50 and full.books > 20, "OneForAll data loaded")
check(#chat == 0, "no warnings at load (" .. table.concat(chat, " | ") .. ")")
check(#FLT.DUNGEONS == 0, "no dungeons shown")
check(#FLT.MAP_LANDMARKS.flight == 0 and #FLT.ZONE_TRANSITIONS == 0 and #FLT.SKYBORNE_SPOTS.ley == 0, "no landmarks shown")
check(#FLT.BOOKS == 0, "no books shown")
local recipes = 0
for _, l in pairs(FLT.PROFESSION_RECIPES) do recipes = recipes + #l end
check(recipes == 0 and #FLT.MERCHANT_RECIPES == 0, "no recipes shown")
check(#FLT.ARMORY_SETS == 0 and #FLT.ARMORY_REPUTATION == 0, "no armory sets or factions shown")
check(#FLT.PET_FAMILIES == 0 and #FLT.PET_RARES == 0, "no pet families or rares shown")
check(full.overlays and next(FLT.MAP_OVERLAYS) == nil, "Remove Fog data emptied")
check(FLT.QUEST_REWARDS.items == "", "no Gear Planner quest rewards shown")
local giv, turn = 0, 0
for _, raw in pairs(FLT.QUEST_PINS) do
  for line in raw:gmatch("[^\n]+") do
    if line:sub(1, 1) == "!" then giv = giv + 1 elseif line:sub(1, 1) == "?" then turn = turn + 1 end
  end
end
check(giv == 0 and full.pinCounts[1] > 1000, "no quest givers on the map (of " .. full.pinCounts[1] .. ")")
check(turn == full.pinCounts[2], "all " .. turn .. " turn-in spots kept")
check(next(FLT.ZONE_LEVELS) == nil and full.zones > 30, "no zone level ranges shown (of " .. full.zones .. ")")
check(#FLT.WEAPON_TRAINERS == 0, "no weapon masters shown")
check(#FLT.CAMPING_PROFESSIONS == 0, "no camping items shown")
check(#FLT.ENCHANT_OPTIONS == 0 and full.enchantCount > 50, "no Gear Planner enchants shown (of " .. full.enchantCount .. ")")
check(#FLT.BOOK_REWARD_TIERS == 0, "no book reward tiers shown")
FLT.ShowNews()
check(not FLT.newsShown, "What's New does not open")

fire("PLAYER_LOGIN")
runTimers()
check(#tickers == 2, "position and zone tickers started")

-- walk towards the first flight master (fake world: 1 % of a map = 10 yards)
local fm = full.firstFlight
world.map, world.y = fm[1], fm[3] / 100
world.x = fm[2] / 100 + 0.30 -- 300 yards
tickers[1](); runTimers()
check(#FLT.MAP_LANDMARKS.flight == 0, "flight master hidden at 300 yards")
world.x = fm[2] / 100 + 0.15 -- 150 yards
tickers[1](); runTimers()
check(#FLT.MAP_LANDMARKS.flight == 0, "flight master hidden at 150 yards")
world.x = fm[2] / 100 + 0.05 -- 50 yards
tickers[1](); runTimers()
check(#FLT.MAP_LANDMARKS.flight >= 1, "flight master revealed at 50 yards")
check(FLT.resets > 0, "OneForAll's map index asked to rebuild")
fire("ZONE_CHANGED_NEW_AREA"); runTimers()
check(FLT.ZONE_LEVELS[fm[1]] ~= nil, "zone level range shown straight away after entering the zone")
local zn = 0; for _ in pairs(FLT.ZONE_LEVELS) do zn = zn + 1 end
check(zn == 1, "only that zone's range shown")
-- walk up to a weapon master
local wm = full.weaponMaster
world.map, world.x, world.y = wm.map, wm.x / 100 + 0.02, wm.y / 100
tickers[1](); runTimers()
check(#FLT.WEAPON_TRAINERS >= 1, "weapon master " .. wm.name .. " revealed when near")

-- walk up to a quest giver in Elwynn Forest
local g = full.giver
world.map, world.x, world.y = g.map, g.x / 100 + 0.03, g.y / 100
tickers[1](); runTimers()
check(FLT.QUEST_PINS[g.map]:find("!" .. g.x .. "," .. g.y .. "," .. g.name, 1, true) ~= nil, "quest giver " .. g.name .. " back in the map data when near")

-- walk up to the first book
local b = full.firstBook
world.map, world.x, world.y = FLT.MAP_IDS[b.zone], b.x / 100 + 0.03, b.y / 100
tickers[1](); runTimers()
local found = false
for _, x in ipairs(FLT.BOOKS) do if x == b then found = true end; print("    revealed book: " .. x.name .. " (" .. x.zone .. ")") end
check(found, "book revealed within ~30 yards")

-- enter the Deadmines
world.instance = { name = "The Deadmines", kind = "party", id = 36 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(#popups == 1 and popups[1]:find("Deadmines"), "reload prompt for the Deadmines")
check(#FLT.DUNGEONS == 0, "dungeon list unchanged until reload")
world.instance = { name = "Dire Maul", kind = "party", id = 429 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(popups[2] and popups[2]:find("DM: East") and popups[2]:find("DM: North"), "Dire Maul wings counted together: " .. tostring(popups[2]))
world.instance = nil

-- learn a recipe, see an armory item, tame a bear
world.spells[full.recipe] = true
fire("SPELLS_CHANGED"); runTimers()
fire("CHAT_MSG_LOOT", "Bob receives loot: |cffa335ee|Hitem:" .. full.firstSetItem .. "::::::::60:::::|h[Thing]|h|r.")
world.pet = { guid = "Pet-0-4379-0-3-1196-0100D6C1D8", family = "Bear" }
fire("UNIT_PET", "player")
local rewardQuest = tonumber(full.rewardLine:match("^%d+,%d+,(%d+)"))
world.questDetail = rewardQuest
fire("QUEST_DETAIL")
world.questDetail = full.tier.questID
fire("QUEST_DETAIL")
local campSpell = full.campSpell
world.spells[campSpell] = true
fire("SPELLS_CHANGED"); runTimers()
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:" .. full.enchantItem.i .. "::::::::60:::::|h[Kit]|h|r.")

local db = _G.OneForAllNoSpoilersCharDB
check(db.recipes[full.recipe], "recipe recorded as learnt")
check(db.items[full.firstSetItem], "armory item recorded as seen")
check(db.pets.npcs[1196] and db.pets.families["Bear"], "tamed bear recorded")
check(db.quests[rewardQuest], "offered quest recorded")

SlashCmdList.ONEFORALLNOSPOILERS("status")
for _, line in ipairs(chat) do print("    " .. line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- 2. Next login with the saved progress -------------------------------------------------------------------
print("Session 2: same character after /reload")
local saved = db
FLT, NS, full = session(saved)
local names = {}
for _, d in ipairs(FLT.DUNGEONS) do names[#names + 1] = d.name end
check(#FLT.DUNGEONS == 4, "4 dungeons shown: " .. table.concat(names, ", "))
check(#FLT.MAP_LANDMARKS.flight >= 1 and FLT.MAP_LANDMARKS.flight[1][5] == fm[5], "flight master still shown")
local again = false
for _, x in ipairs(FLT.BOOKS) do if x.itemId == full.firstBook.itemId then again = true end end
check(again and #FLT.BOOKS == 2, "both revealed books still shown")
local hasRecipe = false
for _, r in ipairs(FLT.PROFESSION_RECIPES["Alchemy"]) do if r.s == full.recipe then hasRecipe = true end end
check(hasRecipe, "learnt recipe shown")
check(#FLT.CAMPING_PROFESSIONS == 1 and FLT.CAMPING_PROFESSIONS[1].profession == full.campingProf
  and #FLT.CAMPING_PROFESSIONS[1].items == 1 and FLT.CAMPING_PROFESSIONS[1].items[1].id == full.campingItem.id,
  "camping item " .. full.campingItem.name .. " shown")
local ench = false
for _, o in ipairs(FLT.ENCHANT_OPTIONS) do if o == full.enchantItem or o.i == full.enchantItem.i then ench = true end end
check(ench, "Gear Planner enchant " .. full.enchantItem.n .. " shown (" .. #FLT.ENCHANT_OPTIONS .. " options)")
check(#FLT.BOOK_REWARD_TIERS == 1 and FLT.BOOK_REWARD_TIERS[1].questID == full.tier.questID, "book reward tier shown")
check(FLT.ZONE_LEVELS[fm[1]] ~= nil, "entered zone's range still shown")
check(#FLT.WEAPON_TRAINERS >= 1, "weapon master still shown")
check(FLT.QUEST_PINS[full.giver.map]:find("," .. full.giver.name, 1, true) ~= nil, "met quest giver still shown")
check(NS.CounterText("dungeons") == "4 of 37 discovered", "options page count: " .. NS.CounterText("dungeons"))
check(#FLT.ARMORY_SETS >= 1 and FLT.ARMORY_SETS[1].i[1][1] == full.firstSetItem, "set with the seen item shown (" .. #FLT.ARMORY_SETS .. " sets)")
check(FLT.ARMORY_SETS[1].n == full.firstSet .. " (1/" .. full.firstSetSize .. " seen)", "set name shows pieces seen: " .. FLT.ARMORY_SETS[1].n)
check(#FLT.PET_FAMILIES == 1 and FLT.PET_FAMILIES[1].name == "Bear" and #FLT.PET_FAMILIES[1].tames == 1, "Bear family with the tamed beast")
local lines = {}
for l in FLT.QUEST_REWARDS.items:gmatch("[^\n]+") do lines[#lines + 1] = l end
check(#lines >= 1 and FLT.QUEST_REWARDS.items:find(full.rewardLine, 1, true), #lines .. " Gear Planner reward line(s) of the offered quest shown")

-- 3. Parts switched off in the options ---------------------------------------------------------------------
print("Session 3: Dungeons and Library Books switched off")
FLT, NS, full = session({}, { off = { dungeons = true, books = true } })
check(#FLT.DUNGEONS == full.dungeons, "all dungeons shown")
check(#FLT.BOOKS == full.books, "all books shown")
check(#FLT.BOOK_REWARD_TIERS == 3, "all book reward tiers shown")
check(#FLT.MAP_LANDMARKS.flight == 0, "flight masters still hidden")
fire("PLAYER_LOGIN"); runTimers()
world.instance = { name = "The Deadmines", kind = "party", id = 36 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(#popups == 0, "no reload prompt while dungeons are switched off")
check(_G.OneForAllNoSpoilersCharDB.dungeons["The Deadmines"], "entering still recorded")
NS.SetOn("dungeons", true)
check(NS.SwitchesChanged(), "switching dungeons back on is noticed as needing a reload")

-- 4. OneForAll data in an unexpected shape ---------------------------------------------------------------
print("Session 4: OneForAll changed its dungeon data")
chat, popups, timers, tickers = {}, {}, {}, {}
world = { spells = {}, bags = {}, bagList = {} }
api()
FLT = loadOneForAll()
FLT.DUNGEONS[1] = "something new"
_G.OneForAllNoSpoilersCharDB = nil
_G.OneForAllNoSpoilersDB = nil
loadAddon()
fire("ADDON_LOADED", "OneForAll_NoSpoilers")
check(#FLT.DUNGEONS == full.dungeons, "dungeon list left untouched")
check(#chat == 1 and chat[1]:find("Dungeons are not hidden"), "one chat notice: " .. tostring(chat[1]))
check(#FLT.BOOKS == 0, "other parts still work")

-- 5. Legacy System: dungeons show once cleared -------------------------------------------------------------
print("Session 5: Legacy record (dungeons show once cleared)")
local function legacyApi(flags, crit)
  _G.UnitFactionGroup = function() return "Horde" end
  _G.GetAchievementInfo = function(id) if crit[id] then return id, "Spelunker", 10, false, nil, nil, nil, "", flags end end
  _G.GetAchievementNumCriteria = function(id) return #crit[id] end
  _G.GetAchievementCriteriaInfo = function(id, j) return crit[id][j][1], 0, crit[id][j][2] end
end
local crit = {
  [62031] = { { "Ragefire Chasm or Hall of Thanes", false }, { "The Deadmines", false }, { "Wailing Caverns", false } },
  [62032] = { { "Blackfathom Deeps", false }, { "Somewhere New", false } },
  [62033] = { { "Uldaman", false } },
}
FLT, NS, full = session({})
legacyApi(0, crit)
db = _G.OneForAllNoSpoilersCharDB
fire("PLAYER_LOGIN"); runTimers()
world.instance = { name = "The Deadmines", kind = "party", id = 36 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(#popups == 0 and not db.dungeons["The Deadmines"], "entering a tracked dungeon reveals nothing")
world.instance = { name = "The Stockade", kind = "party", id = 34 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(#popups == 1 and db.dungeons["The Stockade"], "entering an untracked dungeon reveals it")
crit[62031][3][2] = true
fire("CRITERIA_UPDATE"); runTimers()
check(#popups == 2 and popups[2]:find("Wailing Caverns") and db.dungeons["Wailing Caverns"], "clearing Wailing Caverns reveals it")
crit[62031][1][2] = true
fire("CRITERIA_UPDATE"); runTimers()
check(db.dungeons["Ragefire Chasm"] and not db.dungeons["Hall of Thanes"], "Ragefire or Hall of Thanes: only the Horde one")
check(#chat == 0, "no chat notice (" .. table.concat(chat, " | ") .. ")")
NS.Print = function(t) chat[#chat + 1] = t end
SlashCmdList.ONEFORALLNOSPOILERS("legacy")
check(chat[1] and chat[1]:find("tracks 6 dungeons; this character has cleared 2", 1, true), "summary: " .. tostring(chat[1]))
check(chat[3] and chat[3]:find("Somewhere New", 1, true), "unmatched criterion listed")
SlashCmdList.ONEFORALLNOSPOILERS("status")
local st = ""
for _, line in ipairs(chat) do if line:find("^Dungeons:") then st = line end end
check(st:find("once cleared", 1, true), "status: " .. st:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))

print("Session 6: account-wide Legacy record")
FLT, NS, full = session({})
legacyApi(0x20000, crit)
db = _G.OneForAllNoSpoilersCharDB
fire("PLAYER_LOGIN"); runTimers()
world.instance = { name = "Uldaman", kind = "party", id = 70 }
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(db.dungeons["Uldaman"] and not db.dungeons["Wailing Caverns"], "falls back to entering; other characters' clears ignored")
check(#chat == 1 and chat[1]:find("account-wide", 1, true), "one chat notice: " .. table.concat(chat, " | "))
fire("PLAYER_ENTERING_WORLD"); runTimers()
check(#chat == 1, "notice not repeated")

print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
