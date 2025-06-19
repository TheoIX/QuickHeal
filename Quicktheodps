-- QuickTheoDPS: Retribution Paladin DPS macro for Turtle WoW (1.12)

local function TheoDPS_IsTargetValid()
    return UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target")
        and not UnitIsPlayer("target")
end

local function TheoDPS_TargetEnemyIfNeeded()
    if not TheoDPS_IsTargetValid() then
        RunScript('UnitXP("target", "nearestEnemy")')
    end
end

local function TheoDPS_HasBuff(buffName)
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name and string.find(name, buffName) then
            return true
        end
    end
    return false
end

local function TheoDPS_CastAppropriateSeal()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (maxMana > 0) and (mana / maxMana) or 1

    if manaPercent > 0.20 then
        if not TheoDPS_HasBuff("Seal of Command") and IsSpellReady("Seal of Command") then
            CastSpellByName("Seal of Command")
            return true
        end
    else
        if not TheoDPS_HasBuff("Seal of Wisdom") and IsSpellReady("Seal of Wisdom") then
            CastSpellByName("Seal of Wisdom")
            return true
        end
    end
    return false
end

local function TheoDPS_CastStrike()
    if not TheoDPS_IsTargetValid() then return false end
    if IsSpellInRange("Holy Strike", "target") ~= 1 then return false end

    local hasHolyMight = TheoDPS_HasBuff("Holy Might")
    local strikeSpell = hasHolyMight and "Crusader Strike" or "Holy Strike"

    if IsSpellReady(strikeSpell) then
        CastSpellByName(strikeSpell)
        AttackTarget()
        return true
    end
    return false
end

local function TheoDPS_CastJudgement()
    if IsSpellReady("Judgement") and TheoDPS_IsTargetValid() and IsSpellInRange("Judgement", "target") == 1 then
        CastSpellByName("Judgement")
        return true
    end
    return false
end

local function TheoDPS_CastExorcism()
    if not TheoDPS_IsTargetValid() then return false end
    if not UnitCreatureType("target") then return false end

    local creatureType = UnitCreatureType("target")
    if creatureType == "Undead" and IsSpellReady("Exorcism") and IsSpellInRange("Exorcism", "target") == 1 then
        CastSpellByName("Exorcism")
        return true
    end
    return false
end

local function TheoDPS_CastHammerOfWrath()
    if not TheoDPS_IsTargetValid() then return false end
    if UnitHealth("target") / UnitHealthMax("target") > 0.20 then return false end

    if IsSpellReady("Hammer of Wrath") and IsSpellInRange("Hammer of Wrath", "target") == 1 then
        CastSpellByName("Hammer of Wrath")
        return true
    end
    return false
end

local function TheoDPS_CastRepentance()
    if not TheoDPS_IsTargetValid() then return false end
    if UnitLevel("target") ~= -1 then return false end -- Only cast on bosses

    if IsSpellReady("Repentance") and IsSpellInRange("Repentance", "target") == 1 then
        CastSpellByName("Repentance")
        return true
    end
    return false
end

local function TheoDPS_CastConsecration()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (maxMana > 0) and (mana / maxMana) or 0

    if manaPercent > 0.75 and IsSpellReady("Consecration") then
        CastSpellByName("Consecration")
        return true
    end
    return false
end

local function QuickTheoDPS_RunLogic()
    TheoDPS_TargetEnemyIfNeeded()

    if TheoDPS_CastAppropriateSeal() then return end
    if TheoDPS_CastStrike() then return end
    if TheoDPS_CastJudgement() then return end
    if TheoDPS_CastExorcism() then return end
    if TheoDPS_CastHammerOfWrath() then return end
    if TheoDPS_CastRepentance() then return end
    if TheoDPS_CastConsecration() then return end

    if IsSpellReady("Attack") then AttackTarget() end
end

function QuickTheoDPS_Command()
    QuickTheoDPS_RunLogic()
end

local function InitQuickTheoDPS()
    SLASH_QUICKTHEODPS1 = "/qhtheodps"
    SlashCmdList["QUICKTHEODPS"] = QuickTheoDPS_Command
end

local dpsFrame = CreateFrame("Frame")
dpsFrame:RegisterEvent("PLAYER_LOGIN")
dpsFrame:SetScript("OnEvent", InitQuickTheoDPS)
