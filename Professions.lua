local _, NS = ...

-- Professions: OneForAll's recipe lists (all recipes, Merchant's Favor) only hold recipes this character has
-- learnt. Learnt recipes are read from the profession window (the same functions OneForAll uses) and from
-- the spellbook (IsPlayerSpell). Recipes learnt this session show after the next /reload.

local M = { key = "professions", label = "Recipes" }
NS.AddModule(M)

local db
local allSpells = {} -- every recipe spell in OneForAll's data
local byItem = {} -- crafted item -> recipe spell
local total, shown = 0, 0

-- other parts (Gear Planner enchants) add recipe spells to watch for
function NS.WatchRecipeSpell(spell)
  if type(spell) == "number" then allSpells[spell] = true end
end

local function learn(spell)
  if type(spell) == "number" and allSpells[spell] then db.recipes[spell] = true end
end

local function scanSpellbook()
  if not IsPlayerSpell then return end
  for s in pairs(allSpells) do
    if not db.recipes[s] and IsPlayerSpell(s) then db.recipes[s] = true end
  end
end

local function linkSpell(link) return type(link) == "string" and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)")) end
local function linkItem(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) end

local function scanWindow()
  -- someone else's profession window (linked or guild): not ours
  if IsTradeSkillLinked and IsTradeSkillLinked() then return end
  if IsTradeSkillGuild and IsTradeSkillGuild() then return end
  local T = C_TradeSkillUI
  if T and T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return end
  if T and T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return end

  if T and T.GetAllRecipeIDs and T.GetRecipeInfo then
    for _, id in ipairs(T.GetAllRecipeIDs() or {}) do
      local info = T.GetRecipeInfo(id)
      if info and info.learned then learn(id) end
    end
  end
  if GetNumTradeSkills and GetTradeSkillInfo then
    for i = 1, GetNumTradeSkills() or 0 do
      local _, kind = GetTradeSkillInfo(i)
      if kind and kind ~= "header" and kind ~= "subheader" then
        local spell = GetTradeSkillRecipeLink and linkSpell(GetTradeSkillRecipeLink(i))
        if not spell and GetTradeSkillItemLink then spell = byItem[linkItem(GetTradeSkillItemLink(i))] end
        learn(spell)
      end
    end
  end
  -- the old craft window (Enchanting, Beast Training on older clients)
  if GetNumCrafts and GetCraftInfo then
    for i = 1, GetNumCrafts() or 0 do
      local _, _, kind = GetCraftInfo(i)
      if kind ~= "header" then
        local spell = GetCraftRecipeLink and linkSpell(GetCraftRecipeLink(i))
        if not spell and GetCraftItemLink then
          local link = GetCraftItemLink(i)
          spell = linkSpell(link) or byItem[linkItem(link)]
        end
        learn(spell)
      end
    end
  end
end

function M.apply(FLT, saved)
  db = saved
  db.recipes = db.recipes or {}
  local R = FLT.PROFESSION_RECIPES
  if type(R) ~= "table" then return false, "recipe list not found" end
  for _, list in pairs(R) do
    if type(list) ~= "table" then return false, "recipe lists look different" end
    for _, r in ipairs(list) do
      if type(r) ~= "table" or type(r.s) ~= "number" then return false, "recipe entries look different" end
    end
  end
  local merchant = FLT.MERCHANT_RECIPES
  local pdata = FLT.PROFESSION_DATA
  local merchantOK = type(merchant) == "table" and type(pdata) == "table"
  if merchantOK then
    for _, r in ipairs(merchant) do
      if type(r) ~= "table" or type(r.profession) ~= "string" or type(r.name) ~= "string" then merchantOK = false end
    end
  end

  for _, list in pairs(R) do
    for _, r in ipairs(list) do
      allSpells[r.s] = true
      if type(r.i) == "number" then byItem[r.i] = r.s end
      total = total + 1
    end
  end
  -- Merchant's Favor recipes are known by their spell in OneForAll's profession data
  local function merchantSpell(r)
    local p = pdata[r.profession]
    local e = type(p) == "table" and p[r.name]
    return type(e) == "table" and e.spellID or nil
  end
  if merchantOK then
    for _, r in ipairs(merchant) do
      local s = merchantSpell(r)
      if type(s) == "number" then allSpells[s] = true end
    end
  end

  for _, list in pairs(R) do
    NS.FilterInPlace(list, function(r) return db.recipes[r.s] end)
    shown = shown + #list
  end
  if merchantOK then
    NS.FilterInPlace(merchant, function(r) local s = merchantSpell(r); return s and db.recipes[s] end)
  else
    NS.Print("Merchant's Favor recipes are not hidden: their data looks different.")
  end

  -- Camping items (Professions tab): those whose recipe is learnt, matched by the crafted item
  local camping = FLT.CAMPING_PROFESSIONS
  local campingOK = type(camping) == "table"
  if campingOK then
    for _, p in ipairs(camping) do
      if type(p) ~= "table" or type(p.items) ~= "table" then campingOK = false; break end
      for _, it in ipairs(p.items) do
        if type(it) ~= "table" then campingOK = false; break end
      end
    end
  end
  if campingOK then
    for _, p in ipairs(camping) do
      NS.FilterInPlace(p.items, function(it) local s = byItem[it.id]; return s and db.recipes[s] end)
    end
    NS.FilterInPlace(camping, function(p) return #p.items > 0 end)
  elseif camping ~= nil then
    NS.Print("Camping items are not hidden: their data looks different.")
  end
  return true
end

local function soon() NS.Debounce(M, "professions-scan", 0.5, scanWindow) end
local function spellsSoon() NS.Debounce(M, "professions-spells", 2, scanSpellbook) end

M.events = {
  PLAYER_LOGIN = scanSpellbook,
  SPELLS_CHANGED = spellsSoon,
  LEARNED_SPELL_IN_TAB = spellsSoon,
  NEW_RECIPE_LEARNED = function(id) learn(id); spellsSoon() end,
  TRADE_SKILL_SHOW = soon,
  TRADE_SKILL_UPDATE = soon,
  TRADE_SKILL_LIST_UPDATE = soon,
  CRAFT_SHOW = soon,
  CRAFT_UPDATE = soon,
}

function M.status()
  local learnt = 0
  for _ in pairs(db.recipes) do learnt = learnt + 1 end
  return string.format("%d of %d recipes shown, %d learnt so far (new ones show after /reload)", shown, total, learnt)
end
