-- TheoMode — Holy Paladin core (Turtle WoW 1.12)
-- Strict melee gate for HS/CS + safe returns + optional UI error suppression
-- Clean rebuild to fix syntax error

local BOOKTYPE_SPELL = "spell"

-- =========================================
-- UTILITIES
-- =========================================
local function IsSpellReady(spellName)
  for i = 1, 300 do
    local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    if spellName == name or (rank and spellName == name .. "(" .. rank .. ")") then
      local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
      return enabled == 1 and (start == 0 or duration == 0), start or 0, duration or 0
    end
  end
  return false, 0, 0
end

local function GetSharedCooldown(spellNames)
  for i = 1, 300 do
    local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    for _, s in ipairs(spellNames) do
      if name == s or (rank and (name .. "(" .. rank .. ")") == s) then
        local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
        return enabled == 1 and (start == 0 or duration == 0), start or 0, duration or 0
      end
    end
  end
  return false, 0, 0
end

local function QuickHeal_DetectBuff(unit, texture)
  for i = 1, 40 do
    local icon = UnitBuff(unit, i)
    if not icon then break end
    if string.find(icon, texture) then return true end
  end
  return false
end

local function HasSealOfWisdom()
  for i = 1, 40 do
    local tex = UnitBuff("player", i)
    if not tex then break end
    if string.find(tex, "Seal of Wisdom") then return true end
  end
  return false
end

-- =========================================
-- RANGE & CAST HELPERS
-- =========================================
local function InTrueMelee(unit)
  unit = unit or "target"
  if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitCanAttack("player", unit) then
    return false
  end
  local hs = IsSpellInRange("Holy Strike", unit)
  local cs = IsSpellInRange("Crusader Strike", unit)
  return hs == 1 and cs == 1
end

local function DidCDStart(spellName)
  local ready1, s1, d1 = IsSpellReady(spellName)
  CastSpellByName(spellName)
  local ready2, s2, d2 = IsSpellReady(spellName)
  return ready1 and (not ready2 or s2 ~= s1 or d2 ~= d1)
end

-- Cast on a friendly unit without leaving you on a friendly target after
local function Theo_NoSwapCastOnUnit(spellName, unit)
  if not UnitExists(unit) or not UnitIsFriend("player", unit) or UnitIsDeadOrGhost(unit) then
    return false
  end
  local hadTarget = UnitExists("target")
  local prevHostile = hadTarget and UnitCanAttack("player", "target")
  if prevHostile then ClearTarget() end

  -- SuperWoW/Cleveroid paths
  if type(CR_SpellOnUnit) == "function" then
    local ok = CR_SpellOnUnit(spellName, unit)
    if prevHostile and hadTarget then TargetLastTarget() end
    if ok then return true end
  end
  if type(CR_CastSpellOnUnit) == "function" then
    local ok2 = CR_CastSpellOnUnit(spellName, unit)
    if prevHostile and hadTarget then TargetLastTarget() end
    if ok2 then return true end
  end

  -- Cursor targeting path
  CastSpellByName(spellName)
  if SpellIsTargeting() then
    SpellTargetUnit(unit)
    if prevHostile and hadTarget then TargetLastTarget() end
    return true
  end

  -- Hardened fallback
  local had = UnitExists("target")
  local hostile = had and UnitCanAttack("player", "target")
  if hostile then ClearTarget() end
  TargetUnit(unit)
  CastSpellByName(spellName)
  if SpellIsTargeting() then SpellTargetUnit(unit) end
  if SpellIsTargeting() then
    SpellStopTargeting()
    if had then TargetLastTarget() end
    return false
  end
  if had then TargetLastTarget() else ClearTarget() end
  return true
end

-- =========================================
-- GLOBALS & TOGGLES
-- =========================================
QuickHeal_EnableMouseoverFL7 = QuickHeal_EnableMouseoverFL7 or false
QuickHeal_EnableTheomode     = QuickHeal_EnableTheomode     or false
Theo_EnableUtilities         = Theo_EnableUtilities         or false
Theo_LastPerception = Theo_LastPerception or 0
Theo_LastWarmth = Theo_LastWarmth or 0
Theo_LastEye = Theo_LastEye or 0

local TheoMode_LastHealedTarget = nil
local Theo_LastHolyLightTime = Theo_LastHolyLightTime or 0
local QuickTheo_SealTime     = QuickTheo_SealTime or 0
local QuickTheo_LastSealCast = QuickTheo_LastSealCast
local QuickTheo_WaitingForJudgement = QuickTheo_WaitingForJudgement or false

-- UI error suppression (defaults to hidden per user)
Theo_SuppressUIErrors = (Theo_SuppressUIErrors ~= false)
local function Theo_SetErrorSuppression(on)
  if UIErrorsFrame then
    if on and UIErrorsFrame.UnregisterEvent then
      UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    elseif (not on) and UIErrorsFrame.RegisterEvent then
      UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
  end
end
Theo_SetErrorSuppression(Theo_SuppressUIErrors)

-- =========================================
-- ROTATION HELPERS
-- =========================================
local function IsCrusaderStrikeConditionMet()
  local hasInjuredNearby = false
  for i = 1, 40 do
    local unit = "raid" .. i
    if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
      local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
      if maxhp and maxhp > 0 then
        if (hp / maxhp) < 0.97 and CheckInteractDistance(unit, 3) then
          hasInjuredNearby = true
          break
        end
      end
    end
  end

  local ready, start, duration = IsSpellReady("Holy Shock")
  local remaining = 0
  if not ready then remaining = duration - (GetTime() - start) end
  return (not hasInjuredNearby) and remaining > 15
end

local function Theo_UseUtilities()
    if not Theo_EnableUtilities then return end
    local now = GetTime()

    -- Perception Logic
    if now - Theo_LastPerception > 180 then
        if IsSpellReady("Perception") then
            CastSpellByName("Perception")
            Theo_LastPerception = now
        end
    end

    for slot = 13, 14 do
        local item = GetInventoryItemLink("player", slot)
        if item then
            if string.find(item, "Warmth of Forgiveness") and (mana / maxMana) < 0.85 then
                local start, duration, enable = GetInventoryItemCooldown("player", slot)
                if enable == 1 and (start == 0 or duration == 0) then
                    UseInventoryItem(slot)
                end
            end
            if string.find(item, "Eye of the Dead") then
                local injuredCount = 0
                for i = 1, 40 do
                    local unit = "raid" .. i
                    if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
                        local hp = UnitHealth(unit)
                        local maxhp = UnitHealthMax(unit)
                        if maxhp > 0 and (hp / maxhp) < 0.8 then
                            injuredCount = injuredCount + 1
                        end
                    end
                end
                if injuredCount >= 5 then
                    local start, duration, enable = GetInventoryItemCooldown("player", slot)
                    if enable == 1 and (start == 0 or duration == 0) then
                        UseInventoryItem(slot)
                    end
                end
            end
        end
    end
end

-- =========================================
-- SPELLS
-- =========================================
function Theo_CastHolyStrike()
  Theo_UseUtilities()

  local function isValidTarget()
    return UnitExists("target")
       and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and InTrueMelee("target")
  end

  if not isValidTarget() then
    -- user-requested targeting script
    if type(RunScript) == "function" then
      RunScript('UnitXP("target", "nearestEnemy")')
    end
  end

  local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    local targetValid = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target")
    local judgementRange = IsSpellInRange("Judgement", "target") == 1

    if targetValid and judgementRange and not HasSealOfWisdom() and not hasJudgement and not IsSpellReady("Holy Strike") and IsSpellReady("Judgement") then
        if IsSpellReady("Seal of Wisdom") and QuickTheo_LastSealCast ~= "Seal of Wisdom" then
            CastSpellByName("Seal of Wisdom")
            QuickTheo_LastSealCast = "Seal of Wisdom"
            QuickTheo_SealTime = GetTime()
        end
        for i = 1, 300 do
            local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
            if not name then break end
            if name == "Judgement" then
                CastSpell(i, BOOKTYPE_SPELL)
                QuickTheo_LastSealCast = nil
                break
            end
        end
        return true
    end

  if isValidTarget() then
    local sharedReady = GetSharedCooldown({"Holy Strike", "Crusader Strike"})
    if sharedReady then
      if IsCrusaderStrikeConditionMet() and IsSpellReady("Crusader Strike") then
        if DidCDStart("Crusader Strike") then
          QuickTheo_WaitingForJudgement = false
          return true
        end
      elseif IsSpellReady("Holy Strike") then
        if DidCDStart("Holy Strike") then
          QuickTheo_WaitingForJudgement = false
          return true
        end
      end
    end
  end
  return false
end

function Theo_CastHolyShock()
  local ready = IsSpellReady("Holy Shock")
  if not ready then return false end

  local best, bestR = nil, 1
  local units = {"player", "party1", "party2", "party3", "party4"}
  for i = 1, 40 do table.insert(units, "raid"..i) end

  for _, u in ipairs(units) do
    if UnitExists(u) and UnitIsFriend("player", u) and not UnitIsDeadOrGhost(u) then
      local hp, maxhp = UnitHealth(u), UnitHealthMax(u)
      if maxhp and maxhp > 0 then
        local r = hp / maxhp
        if r < bestR and r < 0.70 and IsSpellInRange("Holy Shock", u) == 1 then
          best, bestR = u, r
        end
      end
    end
  end

  if not best then return false end
  return Theo_NoSwapCastOnUnit("Holy Shock", best)
end

function Theo_CastHolyLight()
  local now = GetTime()
  if now - Theo_LastHolyLightTime < 2 then return false end

  local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
  if not hasJudgement then return false end
  local ready = IsSpellReady("Holy Light")
  if not ready then return false end

  local lowestTarget, lowestHP = nil, 1
  local units = {"player", "party1", "party2", "party3", "party4"}
  for i = 1, 40 do table.insert(units, "raid" .. i) end

  for _, unit in ipairs(units) do
    if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
      local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
      if maxhp and maxhp > 0 then
        local ratio = hp / maxhp
        if ratio < 0.30 and IsSpellInRange("Holy Light", unit) == 1 then
          if ratio < lowestHP then
            lowestTarget, lowestHP = unit, ratio
          end
        end
      end
    end
  end

  if lowestTarget then
    CastSpellByName("Holy Light(Rank 9)")
    SpellTargetUnit(lowestTarget)
    Theo_LastHolyLightTime = now
    return true
  end
  return false
end

-- =========================================
-- MAIN HANDLER
-- =========================================
local function TheoQHHandler()
  if QuickHeal_EnableMouseoverFL7 then
    local focus = GetMouseFocus()
    local unit = focus and focus.unit
    if unit and UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit)
       and IsSpellInRange("Flash of Light(Rank 7)", unit) == 1 then
      local ready = IsSpellReady("Flash of Light")
      if ready then
        CastSpellByName("Flash of Light(Rank 7)")
        SpellTargetUnit(unit)
        return
      end
    end
  end

  if QuickHeal_EnableTheomode then
    if Theo_CastHolyStrike() then return end
    if Theo_CastHolyShock() then return end
    if Theo_CastHolyLight() then return end
    if type(QuickHeal) == "function" then QuickHeal() end
  else
    if type(QuickHeal) == "function" then QuickHeal() end
  end
end

-- =========================================
-- SLASH COMMANDS
-- =========================================
SLASH_THEOMODE1 = "/theomode"
SlashCmdList["THEOMODE"] = function()
  QuickHeal_EnableTheomode = not QuickHeal_EnableTheomode
  DEFAULT_CHAT_FRAME:AddMessage("TheoMode: " .. (QuickHeal_EnableTheomode and "ENABLED" or "DISABLED"), 1, 1, 0)
end

SLASH_THEOFL7TOGGLE1 = "/theofl7"
SlashCmdList["THEOFL7TOGGLE"] = function()
  QuickHeal_EnableMouseoverFL7 = not QuickHeal_EnableMouseoverFL7
  DEFAULT_CHAT_FRAME:AddMessage("Theo Mouseover FL7: " .. (QuickHeal_EnableMouseoverFL7 and "ENABLED" or "DISABLED"), 1, 1, 0)
end

SLASH_THEOTOGGLES1 = "/theotoggles"
SlashCmdList["THEOTOGGLES"] = function()
  Theo_EnableUtilities = not Theo_EnableUtilities
  DEFAULT_CHAT_FRAME:AddMessage("Theo Utilities: " .. (Theo_EnableUtilities and "ENABLED" or "DISABLED"), 1, 1, 0)
end

SLASH_THEOERRORS1 = "/theoerrors"
SlashCmdList["THEOERRORS"] = function()
  Theo_SuppressUIErrors = not Theo_SuppressUIErrors
  Theo_SetErrorSuppression(Theo_SuppressUIErrors)
  DEFAULT_CHAT_FRAME:AddMessage("Theo UI errors: " .. (Theo_SuppressUIErrors and "HIDDEN" or "SHOWN"), 1, 1, 0)
end

SLASH_THEOQH1 = "/theoqh"
SlashCmdList["THEOQH"] = TheoQHHandler

