-- theomode.lua

local BOOKTYPE_SPELL = "spell"

-- =========================================
-- Utility Functions
-- =========================================

local function IsSpellReady(spellName)
    for i = 1, 300 do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if spellName == name or (rank and spellName == name .. "(" .. rank .. ")") then
            local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
            return enabled == 1 and (start == 0 or duration == 0), start, duration
        end
    end
    return false, 0, 0
end

local function GetSharedCooldown(spellNames)
    for i = 1, 300 do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        for _, s in ipairs(spellNames) do
            if name == s or (rank and name .. "(" .. rank .. ")" == s) then
                local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
                return enabled == 1 and (start == 0 or duration == 0), start, duration
            end
        end
    end
    return false, 0, 0
end

local function HasSealOfWisdom()
    for i = 1, 40 do
        local buff = UnitBuff("player", i)
        if not buff then break end
        if string.find(buff, "Seal of Wisdom") then
            return true
        end
    end
    return false
end

local function QuickHeal_DetectBuff(unit, texture)
    for i = 1, 40 do
        local icon = UnitBuff(unit, i)
        if not icon then break end
        if string.find(icon, texture) then
            return true
        end
    end
    return false
end

-- =========================================
-- Globals & Toggles
-- =========================================

Theo_EnableUtilities = false
Theo_LastPerception = 0
Theo_LastWarmth = 0
Theo_LastEye = 0

QuickHeal_EnableTheomode = false
local TheoMode_LastHealedTarget = nil
local QuickTheo_SealTime = 0
local QuickTheo_LastSealCast = nil
local QuickTheo_WaitingForJudgement = false
local Theo_LastHolyLightTime = 0

-- =========================================
-- Core TheoMode Logic
-- =========================================

local function IsCrusaderStrikeConditionMet()
    local hasInjuredNearby = false
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            local hp = UnitHealth(unit)
            local maxhp = UnitHealthMax(unit)
            if maxhp > 0 and (hp / maxhp) < 0.97 and CheckInteractDistance(unit, 3) then
                hasInjuredNearby = true
                break
            end
        end
    end

    local ready, start, duration = IsSpellReady("Holy Shock")
    local cooldownRemaining = 0
    if not ready then
        cooldownRemaining = duration - (GetTime() - start)
    end

    return not hasInjuredNearby and cooldownRemaining > 15
end

local function Theo_UseUtilities()
    if not Theo_EnableUtilities then return end
    local now = GetTime()

    if now - Theo_LastPerception > 180 then
        local ready = IsSpellReady("Perception")
        if ready then
            CastSpellByName("Perception")
            Theo_LastPerception = now
        end
    end

    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")

    for slot = 13, 14 do
        local item = GetInventoryItemLink("player", slot)
        if item then
            if string.find(item, "Warmth of Forgiveness") and maxMana > 0 and (mana / maxMana) < 0.85 then
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

function Theo_CastHolyStrike()
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    Theo_UseUtilities()

    local function isValidTarget()
        return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
            and not UnitIsPlayer("target") and IsSpellInRange("Holy Strike", "target") == 1 and CheckInteractDistance("target", 3)
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

    if not isValidTarget() then
        TargetNearestEnemy()
    end

    if isValidTarget() then
        local sharedReady = GetSharedCooldown({"Holy Strike", "Crusader Strike"})
        if sharedReady then
            if IsCrusaderStrikeConditionMet() and IsSpellReady("Crusader Strike") then
                CastSpellByName("Crusader Strike")
                AttackTarget()
                QuickTheo_WaitingForJudgement = false
                return true
            elseif IsSpellReady("Holy Strike") then
                CastSpellByName("Holy Strike")
                AttackTarget()
                QuickTheo_WaitingForJudgement = false
                return true
            end
        end
    end
    return false
end

function Theo_CastHolyShock()
    local holyShockReady = IsSpellReady("Holy Shock")
    if not holyShockReady then return false end

    local bestTarget = nil
    local hasDaybreak = false
    local lowestHP = 1
    local units = { "player", "party1", "party2", "party3", "party4" }
    for i = 1, 40 do table.insert(units, "raid" .. i) end

    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            local hp = UnitHealth(unit)
            local maxhp = UnitHealthMax(unit)
            if maxhp > 0 then
                local hpRatio = hp / maxhp
                if hpRatio < 0.8 and IsSpellInRange("Holy Shock", unit) == 1 then
                    local hasBuff = false
                    for j = 1, 40 do
                        local buff = UnitBuff(unit, j)
                        if not buff then break end
                        if string.find(buff, "Daybreak") then
                            hasBuff = true
                            break
                        end
                    end
                    if hasBuff and (not hasDaybreak or hpRatio < lowestHP) then
                        bestTarget = unit
                        hasDaybreak = true
                        lowestHP = hpRatio
                    elseif not hasDaybreak and hpRatio < lowestHP then
                        bestTarget = unit
                        lowestHP = hpRatio
                    end
                end
            end
        end
    end

    if bestTarget then
        CastSpellByName("Holy Shock")
        SpellTargetUnit(bestTarget)
        return true
    end
    return false
end

function Theo_CastHolyLight()
    local now = GetTime()
    if now - Theo_LastHolyLightTime < 2 then return false end

    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    if not hasJudgement or not IsSpellReady("Holy Light") then return false end

    local lowestTarget = nil
    local lowestHP = 1
    local units = { "player", "party1", "party2", "party3", "party4" }
    for i = 1, 40 do table.insert(units, "raid" .. i) end

    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            local hp = UnitHealth(unit)
            local maxhp = UnitHealthMax(unit)
            if maxhp > 0 then
                local hpRatio = hp / maxhp
                if hpRatio < 0.3 and IsSpellInRange("Holy Light", unit) == 1 then
                    if hpRatio < lowestHP then
                        lowestTarget = unit
                        lowestHP = hpRatio
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
-- Logic Hooking
-- =========================================

local function HookTheoModeLogic()
    if not QuickHeal_Theo_Hooked and type(QuickHeal_Command_Paladin) == "function" then
        local original = QuickHeal_Command_Paladin
        QuickHeal_Command_Paladin = function(msg)
    if QuickHeal_EnableTheomode then
        local casted = Theo_CastHolyShock()
        casted = Theo_CastHolyLight() or casted
        casted = Theo_CastHolyStrike() or casted
                if not casted and msg ~= "hot" then original(msg) end
            else
        if msg ~= "hot" and msg ~= "shock" and msg ~= "light" then
            original(msg)
        end
            end
        end
        QuickHeal_Theo_Hooked = true
    end
end
HookTheoModeLogic()

-- =========================================
-- Slash Commands
-- =========================================

SLASH_THEOMODE1 = "/theomode"
SlashCmdList["THEOMODE"] = function()
    QuickHeal_EnableTheomode = not QuickHeal_EnableTheomode
    if QuickHeal_EnableTheomode then
        DEFAULT_CHAT_FRAME:AddMessage("TheoMode ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("TheoMode DISABLED", 1, 0, 0)
    end
end

SLASH_THEOTOGGLES1 = "/theotoggles"
SlashCmdList["THEOTOGGLES"] = function()
    Theo_EnableUtilities = not Theo_EnableUtilities
    if Theo_EnableUtilities then
        DEFAULT_CHAT_FRAME:AddMessage("Theo Utility Toggles ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Theo Utility Toggles DISABLED", 1, 0, 0)
    end
end

SLASH_THEOQH1 = "/theoqh"
SlashCmdList["THEOQH"] = function(msg)
    if QuickHeal_Command_Paladin then
        QuickHeal_Command_Paladin(msg)
    else
        DEFAULT_CHAT_FRAME:AddMessage("QuickHeal not loaded.", 1, 0, 0)
    end
end
