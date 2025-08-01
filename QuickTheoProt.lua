-- QuickTheoProt.lua: Protection Paladin tanking helper for Turtle WoW (1.12)
-- Installation:
-- 1) Place this folder at Interface/AddOns/QuickTheoProt/
-- 2) Create QuickTheoProt.toc alongside this .lua with:
--    ## Interface: 11302
--    ## Title: QuickTheoProt
--    QuickTheoProt.lua

local BOOKTYPE_SPELL = "spell"

-- State: track whether Judgement casting is enabled (hysteresis)
local judgementEnabled = true

-- Mode toggles: Main Tank and Off Tank
local trinketMode = false
local mainTankMode = false
local offTankMode = false
-- at the top, alongside your other mode toggles:
local farmMode = false
local function GetThreatPct(unit)
  -- try TWThreat first
  local api = _G["TWThreatAPI"]
  if api and api.threats then
    local n = UnitName(unit)
    return tonumber(api.threats[n]) or 0
  end
  -- fallback to Blizzard API
  local _, _, pctScaled = UnitDetailedThreatSituation("player", unit)
  return pctScaled or 0
end

-- Player damage detection: has taken damage if health below max
local function PlayerTookDamage()
    return UnitHealth("player") < UnitHealthMax("player")
end

-- in your Prot logic:
-- local threatPct = GetThreatPct("target")
-- if threatPct < 80 then
 -- CastSpellByName 
-- else
  -- keep your normal rotation (e.g. Judgments, Crusader Strike, etc.)
-- end


-- Workaround buff detection using tooltip (adapted from QuickTheoDPS)
local function TheoProt_HasBuff(buffName)
    for i = 1, 40 do
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:SetUnitBuff("player", i)
        local text = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if text and string.find(text, buffName) then
            return true
        end
    end
    return false
end

-- Helper: equip a libram by name using UseContainerItem (WoW 1.12)
local function EquipLibram(itemName)
    local equipped = GetInventoryItemLink("player", 16)
    if equipped and strfind(equipped, itemName, 1, true) then return true end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and strfind(link, itemName, 1, true) then
                UseContainerItem(bag, slot)
                return true
            end
        end
    end
    return false
end

local function TheoProt_TargetHasDebuff(debuffName)
    for i = 1, 16 do
        local name = UnitDebuff("target", i)
        if name == debuffName then
            return true
        end
    end
    return false
end

-- Utility: check spell cooldown by scanning the spellbook
local function IsSpellReady(spellName)
    for idx = 1, 300 do
        local name, rank = GetSpellName(idx, BOOKTYPE_SPELL)
        if not name then break end
        local full = (rank and rank ~= "") and (name .. "(" .. rank .. ")") or name
        if spellName == name or spellName == full then
            local start, duration, enabled = GetSpellCooldown(idx, BOOKTYPE_SPELL)
            return enabled == 1 and (duration == 0 or (start + duration) <= GetTime())
        end
    end
    return false
end

-- helper: cast Holy Shock on yourself if <70% HP
local function Theo_CastHolyShockSelf()
    local hpPct = (UnitHealth("player") / UnitHealthMax("player")) * 100
    if IsSpellReady("Holy Shock") and hpPct < 70 then
        CastSpellByName("Holy Shock")
        SpellTargetUnit("player")
        return true
    end
    return false
end

-- Cast Exorcism on demons or undead if ready
local function Theo_CastExorcism()
    if IsSpellReady("Exorcism")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target") then
        local cType = UnitCreatureType("target")
        if cType == "Demon" or cType == "Undead" then
            CastSpellByName("Exorcism")
            SpellTargetUnit("target")
            return true
        end
    end
    return false
end

-- Cast Holy Strike if ready and target in melee range
local function Theo_CastHolyStrike()
    if IsSpellReady("Holy Strike")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and IsSpellInRange("Holy Strike", "target") == 1 then
        CastSpellByName("Holy Strike")
        SpellTargetUnit("target")
        return true
    end
    return false
end

-- Cast Crusader Strike
local function Theo_CastCrusaderStrike()
    if IsSpellReady("Crusader Strike")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and IsSpellInRange("Crusader Strike", "target") == 1 then
        CastSpellByName("Crusader Strike")
        SpellTargetUnit("target")
        return true
    end
    return false
end

local function Theo_CastHammerOfWrath()
    if IsSpellReady("Hammer of Wrath")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and (UnitHealth("target") / UnitHealthMax("target") * 100) <= 20 then
        CastSpellByName("Hammer of Wrath")
        SpellTargetUnit("target")
        return true
    end
    return false
end

-- Cast Consecration with libram swap if enemy within interact distance
local function Theo_CastConsecration()
    if IsSpellReady("Consecration")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and CheckInteractDistance("target", 1) then
        CastSpellByName("Consecration")
        return true
    end
    return false
end

-- Cast Holy Shield with libram swap if buff missing
local function Theo_CastHolyShield()
    if TheoProt_HasBuff("Holy Shield") then return false end
    if IsSpellReady("Holy Shield")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target") then
        CastSpellByName("Holy Shield")
        return true
    end
    return false
end

-- Cast Seal of Righteousness if buff missing
local function Theo_CastSealOfRighteousness()
    if TheoProt_HasBuff("Seal of Righteousness") then return false end
    if IsSpellReady("Seal of Righteousness") then
        CastSpellByName("Seal of Righteousness")
        return true
    end
    return false
end

-- Cast Seal of Wisdom if buff missing
local function Theo_CastSealOfWisdom()
    if TheoProt_HasBuff("Seal of Wisdom") then return false end
    if IsSpellReady("Seal of Wisdom") then
        CastSpellByName("Seal of Wisdom")
        return true
    end
    return false
end

-- Cast the proper “strike” when Holy Shock isn’t available
local function Theo_CastStrike()
    -- if Holy Shock is on CD, dump into Crusader Strike
    if not IsSpellReady("Holy Shock") and IsSpellReady("Crusader Strike") then
        CastSpellByName("Crusader Strike")
        return true
    end
    -- otherwise use Holy Strike whenever it’s ready
    if IsSpellReady("Holy Strike") then
        CastSpellByName("Holy Strike")
        return true
    end
    return false
end

-- Cast Seal of Light if buff missing
local function Theo_CastSealOfLight()
    -- don't recast if we already have the buff
    if TheoProt_HasBuff("Seal of Light") then 
        return false 
    end
    -- if it’s off cooldown, cast it
    if IsSpellReady("Seal of Light") then
        CastSpellByName("Seal of Light")
        return true
    end
    return false
end

-- Cast Judgement if ready and in range
local function Theo_CastJudgement()
    if IsSpellReady("Judgement")
       and UnitExists("target") and UnitCanAttack("player","target")
       and not UnitIsDeadOrGhost("target")
       and IsSpellInRange("Judgement","target")==1
       and ( TheoProt_HasBuff("Seal of Wisdom")
          or TheoProt_HasBuff("Seal of Light")
          or TheoProt_HasBuff("Seal of Righteousness") )
       and not TheoProt_TargetHasDebuff("Judgement of Wisdom")
       and not TheoProt_TargetHasDebuff("Judgement of Light")
    then
        CastSpellByName("Judgement")
        return true
    end
    return false
end
 
function QuickTheoProt()
    RunScript('UnitXP("target", "nearestEnemy")')
   
    -- 0) Trinket usage (only fire on‑use trinkets)
    if trinketMode then
        -- slot 13
        local start13, duration13, enable13 = GetInventoryItemCooldown("player", 13)
        if enable13 == 1 and start13 == 0 then
            UseInventoryItem(13)
        end
        -- slot 14
        local start14, duration14, enable14 = GetInventoryItemCooldown("player", 14)
        if enable14 == 1 and start14 == 0 then
            UseInventoryItem(14)
        end
    end

  
    if mainTankMode then
        local targetHPpct = (UnitHealth("target") / UnitHealthMax("target")) * 100

        -- Debug message to confirm MT mode runs
        local threatPct = GetThreatPct("target"); 
    if threatPct and threatPct > 0 then 
        DEFAULT_CHAT_FRAME:AddMessage("TWThreat Active - Threat: "..threatPct.."%", 0, 1, 0) 
    end

        -- Priority #1: Hammer of Wrath (below 20% HP)
        if targetHPpct <= 20 and Theo_CastHammerOfWrath() then return end

        -- Execute standard MT rotation clearly and sequentially
        if Theo_CastHolyStrike() then return end
        if Theo_CastHolyShield() then return end
        if Theo_CastSealOfRighteousness() then return end
        if Theo_CastJudgement() then return end
        if Theo_CastConsecration() then return end

        return  -- Explicit exit for MT logic
    end


    -- Off Tank Mode
    if offTankMode then
        if PlayerTookDamage() and Theo_CastHolyShield() then
            return
        end
        if Theo_CastHolyStrike() then return end
        if Theo_CastSealOfRighteousness() then return end
        if Theo_CastJudgement() then return end
        return  -- ensure no standard behavior is checked
    end

if farmMode then

    
    -- 1) Seal logic: switch between Seal of Light and Seal of Wisdom based on your HP/Mana
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPct = (currentMana / maxMana) * 100

    if manaPct < 95 then
        judgementEnabled = false
    elseif manaPct > 99 then
        judgementEnabled = true
    end

    if judgementEnabled then
        if Theo_CastSealOfRighteousness() then return end
        if Theo_CastJudgement() then return end
    else
        if Theo_CastSealOfWisdom() then return end
    end

    --1) Cast Judgement if rules met
    if Theo_CastJudgement() then return end

    -- 3) Holy Shock on self <70% HP
    if Theo_CastHolyShockSelf() then return end

    -- 2) Strike logic: Holy Shock fallback
    if Theo_CastStrike() then return end

    -- 4) Consecration
    if Theo_CastConsecration() then return end

    -- 5) Holy Shield
    if Theo_CastHolyShield() then return end

    if Theo_CastExorcism() then return end
    -- nothing left to do
    if Theo_CastHammerOfWrath() then return end
    return
end


    -- Standard Behavior (Only runs if both MT and OT are disabled)
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPct = (currentMana / maxMana) * 100

    if manaPct < 40 then
        judgementEnabled = false
    elseif manaPct > 75 then
        judgementEnabled = true
    end

    if judgementEnabled then
        if Theo_CastSealOfRighteousness() then return end
        if Theo_CastJudgement() then return end
    else
        if Theo_CastSealOfWisdom() then return end
    end

    if Theo_CastExorcism() then return end
    if Theo_CastHolyStrike() then return end
    if Theo_CastConsecration() then return end
    if Theo_CastHolyShield() then return end
end


-- Event frame: apply Righteous Fury on login and after death
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("QuickTheoProt loaded! Use /quicktheoprot or /qhtprot", 0, 1, 0)
    end
    if not TheoProt_HasBuff("Righteous Fury") then
        CastSpellByName("Righteous Fury")
    end
end)

-- Slash registration
SLASH_QUICKTHEOPROT1 = "/quicktheoprot"
SLASH_QUICKTHEOPROT2 = "/qhtprot"
SlashCmdList["QUICKTHEOPROT"] = QuickTheoProt

-- Main Tank Mode toggle: /mtmode
SLASH_MAINTANKMODE1 = "/mtmode"
SlashCmdList["MAINTANKMODE"] = function()
    mainTankMode = not mainTankMode
    if mainTankMode then
        DEFAULT_CHAT_FRAME:AddMessage("Main Tank Mode ENABLED", 0, 1, 0)
        offTankMode = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("Main Tank Mode DISABLED", 1, 0, 0)
    end
end

-- Off Tank Mode toggle: /otmode
SLASH_OFFTANKMODE1 = "/otmode"
SlashCmdList["OFFTANKMODE"] = function()
    offTankMode = not offTankMode
    if offTankMode then
        DEFAULT_CHAT_FRAME:AddMessage("Off Tank Mode ENABLED", 0, 1, 0)
        mainTankMode = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("Off Tank Mode DISABLED", 1, 0, 0)
    end
end

-- add the FarmMode slash-command toggle
SLASH_FARMMODE1 = "/farmmode"
SlashCmdList["FARMMODE"] = function()
    farmMode = not farmMode
    if farmMode then
        DEFAULT_CHAT_FRAME:AddMessage("Farm Mode ENABLED", 0, 1, 0)
        -- ensure other modes are off
        mainTankMode = false
        offTankMode  = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("Farm Mode DISABLED", 1, 0, 0)
    end
end

-- Trinket Mode toggle: /trinketmode
SLASH_TRINKETMODE1 = "/trinketmode"
SlashCmdList["TRINKETMODE"] = function()
    trinketMode = not trinketMode
    if trinketMode then
        DEFAULT_CHAT_FRAME:AddMessage("Trinket Mode ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Trinket Mode DISABLED", 1, 0, 0)
    end
end
