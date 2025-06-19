-- QuickTheoDPS: Retribution Paladin DPS macro for Turtle WoW (1.12)

local BOOKTYPE_SPELL = "spell"

local function IsSpellReady(spellName)
    for i = 1, 300 do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if spellName == name or (rank and spellName == name .. "(" .. rank .. ")") then
            local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
            return enabled == 1 and (start == 0 or duration == 0)
        end
    end
    return false
end

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

local function TheoDPS_HasPlayerBuff(buffName)
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

local function TheoDPS_CastAppropriateSeal()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (maxMana > 0) and (mana / maxMana) or 1

    if manaPercent > 0.20 then
        if not TheoDPS_HasPlayerBuff("Seal of Command") and IsSpellReady("Seal of Command") then
            CastSpellByName("Seal of Command")
            return true
        end
    else
        if not TheoDPS_HasPlayerBuff("Seal of Wisdom") and IsSpellReady("Seal of Wisdom") then
            CastSpellByName("Seal of Wisdom")
            return true
        end
    end
    return false
end

local function TheoDPS_CastStrike()
    if not TheoDPS_IsTargetValid() then return false end

    local inRange = IsSpellInRange("Holy Strike", "target") == 1 or IsSpellInRange("Crusader Strike", "target") == 1
    if not inRange then return false end

    local hasHolyMight = TheoDPS_HasPlayerBuff("Holy Might")
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

