local _, NS = ...

-- Armory: item sets and reputation rewards only list items this character has owned or seen. Seen means the
-- game showed its link: in a loot window, a loot roll, a loot chat line ("X receives loot"), at a vendor or
-- as a quest reward. A set or faction with nothing seen yet is left out. Only items that appear in the
-- Armory are remembered. New ones show after the next /reload.

local M = { key = "armory", label = "Armory sets and rewards" }
NS.AddModule(M)

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetSlotItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

local db
local relevant = {} -- every item ID in the Armory data
local counts = { sets = { 0, 0 }, factions = { 0, 0 } }

local function see(id)
  if type(id) == "number" and relevant[id] then db.items[id] = true end
end

local function seeLink(link)
  if type(link) ~= "string" or NS.IsSecret(link) then return end
  for id in link:gmatch("item:(%d+)") do see(tonumber(id)) end
end

local function scanBags(first, last)
  if not (GetNumSlots and GetSlotItemID) then return end
  for bag = first, last do
    for slot = 1, GetNumSlots(bag) or 0 do see(GetSlotItemID(bag, slot)) end
  end
end

local function scanOwned()
  scanBags(0, NUM_BAG_SLOTS or 4)
  for slot = 1, 19 do see(GetInventoryItemID("player", slot)) end
end

local function scanBank()
  local bags = NUM_BAG_SLOTS or 4
  scanBags(BANK_CONTAINER or -1, BANK_CONTAINER or -1)
  scanBags(bags + 1, bags + (NUM_BANKBAGSLOTS or 7))
end

local function scanLoot()
  for i = 1, (GetNumLootItems and GetNumLootItems()) or 0 do seeLink(GetLootSlotLink(i)) end
end

local function scanMerchant()
  for i = 1, (GetMerchantNumItems and GetMerchantNumItems()) or 0 do seeLink(GetMerchantItemLink(i)) end
end

local function scanQuest()
  for i = 1, (GetNumQuestChoices and GetNumQuestChoices()) or 0 do seeLink(GetQuestItemLink("choice", i)) end
  for i = 1, (GetNumQuestRewards and GetNumQuestRewards()) or 0 do seeLink(GetQuestItemLink("reward", i)) end
end

local function validItems(items)
  if type(items) ~= "table" then return false end
  for _, it in ipairs(items) do
    if type(it) ~= "table" or type(it[1]) ~= "number" then return false end
  end
  return true
end

-- keeps the seen items of each entry and drops entries with none; returns shown, total.
-- markNames: an entry with pieces still unseen gets "(seen/all seen)" after its name, as OneForAll counts
-- the pieces it is given ("Owned 1 / 1").
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
      for _, it in ipairs(e.i) do relevant[it[1]] = true end
    end
  end
  if type(sets) == "table" then counts.sets = { filter(sets, true) } end
  if type(rep) == "table" then counts.factions = { filter(rep) } end
  return true
end

M.events = {
  PLAYER_LOGIN = scanOwned,
  BAG_UPDATE_DELAYED = scanOwned,
  PLAYER_EQUIPMENT_CHANGED = function() NS.Debounce(M, "armory-equip", 1, scanOwned) end,
  BANKFRAME_OPENED = scanBank,
  PLAYERBANKSLOTS_CHANGED = function() NS.Debounce(M, "armory-bank", 1, scanBank) end,
  LOOT_READY = scanLoot,
  LOOT_OPENED = scanLoot,
  START_LOOT_ROLL = function(rollID) if GetLootRollItemLink then seeLink(GetLootRollItemLink(rollID)) end end,
  CHAT_MSG_LOOT = function(text) seeLink(text) end,
  MERCHANT_SHOW = scanMerchant,
  MERCHANT_UPDATE = scanMerchant,
  QUEST_DETAIL = scanQuest,
  QUEST_COMPLETE = scanQuest,
}

function M.status()
  local seen = 0
  for _ in pairs(db.items) do seen = seen + 1 end
  return string.format("%d of %d sets and %d of %d factions shown, %d items seen", counts.sets[1], counts.sets[2],
    counts.factions[1], counts.factions[2], seen)
end
