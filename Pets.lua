local _, NS = ...

-- Hunter pets: OneForAll's pet families, tameable beasts, ability teachers and rare tames only list what this
-- character has tamed. A family counts once you have had a pet of it (tamed, active or in the stable); a beast
-- once you have tamed that creature. Ability names and ranks stay, only their teacher lists are trimmed.
-- New ones show after the next /reload.

local M = { key = "pets", label = "Hunter pets" }
NS.AddModule(M)

local GetSpellInfo = GetSpellInfo or (C_Spell and C_Spell.GetSpellName)
local TAME_BEAST = 1515

local db
local counts = { families = { 0, 0 }, rares = { 0, 0 } }
local pending -- { npc, family, time } while a Tame Beast is being cast

local function npcFromGUID(guid)
  if type(guid) ~= "string" or NS.IsSecret(guid) then return end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Pet" then return tonumber(id) end
end

local function family(unit)
  local f = UnitCreatureFamily and UnitCreatureFamily(unit)
  if type(f) == "string" and not NS.IsSecret(f) then return f end
end

local function record(npc, fam)
  if npc then db.pets.npcs[npc] = true end
  if fam then db.pets.families[fam] = true end
end

local function recordPet()
  if not UnitExists("pet") then return end
  record(npcFromGUID(UnitGUID("pet")), family("pet"))
  if pending and GetTime() - pending.time < 60 then record(pending.npc, pending.family) end
  pending = nil
end

local function recordStable()
  local FLT = NS.FLT
  if type(FLT.GetStabledPets) == "function" then
    local ok, list = pcall(FLT.GetStabledPets, FLT)
    if ok and type(list) == "table" then
      for _, p in pairs(list) do if type(p) == "table" and type(p.family) == "string" then record(nil, p.family) end end
    end
  end
  if GetStablePetInfo then
    for i = 1, (NUM_PET_STABLE_SLOTS or 2) do
      local _, _, _, fam = GetStablePetInfo(i)
      if type(fam) == "string" then record(nil, fam) end
    end
  end
end

local function castStart(unit, _, spellID)
  if unit ~= "player" then return end
  if spellID == TAME_BEAST or (GetSpellInfo and spellID and GetSpellInfo(spellID) == "Tame Beast") then
    pending = { npc = npcFromGUID(UnitGUID("target")), family = family("target"), time = GetTime() }
  end
end

local function isList(t)
  if t == nil then return true end
  if type(t) ~= "table" then return false end
  for _, v in ipairs(t) do if type(v) ~= "table" then return false end end
  return true
end

local function tamed(b) return b.npcID ~= nil and db.pets.npcs[b.npcID] end

function M.apply(FLT, saved)
  db = saved
  db.pets = db.pets or {}
  db.pets.families = db.pets.families or {}
  db.pets.npcs = db.pets.npcs or {}
  local fams, abil, rares = FLT.PET_FAMILIES, FLT.PET_ABILITIES, FLT.PET_RARES
  if type(fams) ~= "table" then return false, "pet families not found" end
  for _, f in ipairs(fams) do
    if type(f) ~= "table" or type(f.name) ~= "string" or not isList(f.tames) then return false, "pet families look different" end
  end
  if not isList(abil) or not isList(rares) then return false, "pet data looks different" end
  for _, a in ipairs(abil or {}) do
    if not isList(a.ranks) then return false, "pet abilities look different" end
    for _, rk in ipairs(a.ranks or {}) do
      if not isList(rk.learnFrom) then return false, "pet abilities look different" end
    end
  end

  if not NS.IsOn("pets") then counts = nil; return true end -- switched off: OneForAll shows everything, taming still records
  local totalF = #fams
  NS.FilterInPlace(fams, function(f) return db.pets.families[f.name] end)
  for _, f in ipairs(fams) do
    if f.tames then NS.FilterInPlace(f.tames, tamed) end
  end
  counts.families = { #fams, totalF }
  for _, a in ipairs(abil or {}) do
    for _, rk in ipairs(a.ranks or {}) do
      if rk.learnFrom then NS.FilterInPlace(rk.learnFrom, tamed) end
    end
  end
  if rares then
    local totalR = #rares
    NS.FilterInPlace(rares, tamed)
    counts.rares = { #rares, totalR }
  end
  return true
end

M.events = {
  PLAYER_LOGIN = function() recordPet(); recordStable() end,
  UNIT_PET = function(unit) if unit == "player" then recordPet() end end,
  UNIT_SPELLCAST_START = castStart,
  UNIT_SPELLCAST_CHANNEL_START = castStart,
  PET_STABLE_SHOW = recordStable,
  PET_STABLE_UPDATE = recordStable,
}

NS.Counter("pets", function()
  if counts then return string.format("%d of %d families", counts.families[1], counts.families[2]) end
end)

function M.status()
  if not counts then return "not hidden (switched off)" end
  local beasts = 0
  for _ in pairs(db.pets.npcs) do beasts = beasts + 1 end
  return string.format("%d of %d families and %d of %d rare tames shown, %d beasts tamed", counts.families[1],
    counts.families[2], counts.rares[1], counts.rares[2], beasts)
end
