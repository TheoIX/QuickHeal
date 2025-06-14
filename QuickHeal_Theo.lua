-- QuickHeal_Theo.lua (Turtle WoW-Compatible, Holy Strike Rank 8 priority with healing fallback)

local BOOKTYPE_SPELL = "spell"
local lastHolyStrikeTime = 0
local HOLY_STRIKE_COOLDOWN = 6 -- seconds

-- Utility: Find lowest HP % friendly unit
local function Theo_GetLowestHPTarget()
    local bestUnit, lowestHP = nil, 1
    local units = { "player", "party1", "party2", "party3", "party4" }
    for i = 1, 40 do table.insert(units, "raid" .. i) end
    for _, unit in ipairs(units) do
        if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
            local hp = UnitHealth(unit)
            local maxhp = UnitHealthMax(unit)
            if maxhp > 0 then
                local percent = hp / maxhp
                if percent < lowestHP then
                    lowestHP = percent
                    bestUnit = unit
                end
            end
        end
    end
    return bestUnit, lowestHP
end

local function Theo_CastDivineShieldIfLow()
    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    if maxhp > 0 and (hp / maxhp) < 0.25 then
        CastSpellByName("Divine Shield")
    end
end

local function Theo_CastPerceptionIfReady()
    CastSpellByName("Perception")
end

local function Theo_UseWarmthOfForgiveness()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    if maxMana == 0 or (mana / maxMana) >= 0.85 then return end
    for slot = 13, 14 do
        local item = GetInventoryItemLink("player", slot)
        if item and string.find(item, "Warmth of Forgiveness") then
            UseInventoryItem(slot)
        end
    end
end

local function Theo_CastHolyStrike()
    local now = GetTime()
    if now - lastHolyStrikeTime < HOLY_STRIKE_COOLDOWN then return false end

    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
        and IsSpellInRange("Holy Strike", "target") == 1 and CheckInteractDistance("target", 3) then

        local success = CastSpellByName("Holy Strike(Rank 8)")
        if success ~= nil then
            AttackTarget()
            lastHolyStrikeTime = now
            return true
        end
    end
    return false
end

local function Theo_CastHolyShockIfReady(target)
    CastSpellByName("Holy Shock", target)
end

function QuickTheo_Command()
    Theo_CastPerceptionIfReady()
    Theo_UseWarmthOfForgiveness()

    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    if maxhp > 0 and (hp / maxhp) < 0.25 then
        Theo_CastDivineShieldIfLow()
        return
    end

    local target, hpPercent = Theo_GetLowestHPTarget()

    Theo_CastHolyStrike()

    if not target then
        return
    end

    Theo_CastHolyShockIfReady(target)

    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    if hasJudgement and hpPercent < 0.5 then
        CastSpellByName("Holy Light(Rank 9)")
        SpellTargetUnit(target)
        return
    end

    local spellID, _ = QuickHeal_Paladin_FindSpellToUse(target)
    if spellID then
        CastSpell(spellID, BOOKTYPE_SPELL)
        SpellTargetUnit(target)
    end
end

-- Ensure safe registration after login
local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitQuickTheo)
