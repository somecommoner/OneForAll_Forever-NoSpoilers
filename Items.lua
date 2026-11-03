local _, NS = ...

-- Seen items: remembers which items this character has owned or seen. Seen means the game showed its link:
-- in a loot window, a loot roll, a loot chat line ("X receives loot"), at a vendor or as a quest reward.
-- Other parts say which items matter to them with NS.WatchItem (Armory pieces, enchant items); only those
-- are saved, and they read the result from db.items when they filter.

local M = { key = "items", label = "Seen items" }
NS.AddModule(M)

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetSlotItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

local db
local watched = {}

function NS.WatchItem(id)
  if type(id) == "number" then watched[id] = true end
end

local function see(id)
  if type(id) == "number" and watched[id] then db.items[id] = true end
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

function M.apply(_, saved)
  db = saved
  db.items = db.items or {}
  return true
end

M.events = {
  PLAYER_LOGIN = scanOwned,
  BAG_UPDATE_DELAYED = scanOwned,
  PLAYER_EQUIPMENT_CHANGED = function() NS.Debounce(M, "items-equip", 1, scanOwned) end,
  BANKFRAME_OPENED = scanBank,
  PLAYERBANKSLOTS_CHANGED = function() NS.Debounce(M, "items-bank", 1, scanBank) end,
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
  local n = 0
  for _ in pairs(db.items) do n = n + 1 end
  return n .. " items owned or seen"
end
