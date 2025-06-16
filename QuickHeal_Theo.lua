-- QuickHeal_Theo.lua

-- Find lowest HP % friendly unit
local function Theo_GetLowestHPTarget()
    local bestUnit, lowestHP = nil, 1
    local units = {
        "player", "party1", "party2", "party3", "party4",
        "raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8",
        "raid9", "raid10", "raid11", "raid12", "raid13", "raid14", "raid15",
        "raid16", "raid17", "raid18", "raid19", "raid20", "raid21", "raid22",
        "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29",
        "raid30", "raid31", "raid32", "raid33", "raid34", "raid35", "raid36",
        "raid37", "raid38", "raid39", "raid40"
    }

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

-- Cast Divine Shield if health < 25%
local function Theo_CastDivineShieldIfLow()
    local playerHP = UnitHealth("player")
    local maxHP = UnitHealthMax("player")
    if maxHP > 0 and (playerHP / maxHP) < 0.25 then
        local start, duration = GetSpellCooldown("Divine Shield")
        if duration == 0 then
            CastSpellByName("Divine Shield")
        end
    end
end

-- Use Warmth of Forgiveness trinket if mana < 85%
local function Theo_UseWarmthOfForgiveness()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    if maxMana == 0 or (mana / maxMana) >= 0.85 then return end

    for slot = 13, 14 do
        local itemName = GetInventoryItemLink("player", slot)
        if itemName and string.find(itemName, "Warmth of Forgiveness") then
            local start, duration, enable = GetInventoryItemCooldown("player", slot)
            if duration == 0 and enable == 1 then
                UseInventoryItem(slot)
            end
        end
    end
end

-- Cast Holy Strike on enemy attacking raid/player in melee range
local function Theo_CastHolyStrike()
    local start, duration = GetSpellCooldown("Holy Strike")
    if duration > 0 then return end

    local potentialTargets = {
        "target", "targettarget", "focus",
        "nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5"
    }

    local function IsThreatToGroup(enemyUnit)
        if not UnitExists(enemyUnit .. "target") then return false end
        local targetOfEnemy = enemyUnit .. "target"

        if UnitIsUnit(targetOfEnemy, "player") then return true end
        for i = 1, 4 do
            if UnitIsUnit(targetOfEnemy, "party" .. i) then return true end
        end
        for i = 1, 40 do
            if UnitIsUnit(targetOfEnemy, "raid" .. i) then return true end
        end
        return false
    end

    for _, unit in ipairs(potentialTargets) do
        if UnitExists(unit)
            and UnitCanAttack("player", unit)
            and not UnitIsDeadOrGhost(unit)
            and IsSpellInRange("Holy Strike", unit) == 1
            and CheckInteractDistance(unit, 3)
            and IsThreatToGroup(unit)
        then
            TargetUnit(unit)
            CastSpellByName("Holy Strike")
            return
        end
    end
end

-- Main logic triggered by /qhtheo
function QuickTheo_Command(msg)
    -- Step 0: Use passive tools
    Theo_UseWarmthOfForgiveness()
    Theo_CastDivineShieldIfLow()

    -- Step 1: Heal logic
    local target, hpPercent = Theo_GetLowestHPTarget()
    if not target then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0TheoHeal:|r No valid heal target found.")
        return
    end

    -- Step 2: Holy Shock if available
    local hsStart, hsDuration = GetSpellCooldown("Holy Shock")
    if hsDuration == 0 and UnitIsFriend("player", target) and not UnitIsDeadOrGhost(target) then
        CastSpellByName("Holy Shock", target)
    end

    -- Step 3: Holy Light Rank 9 if Holy Judgement is active and target < 50%
    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    if hasJudgement and hpPercent < 0.5 then
        local spellIDs = QuickHeal_GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT)
        local rank9 = spellIDs and spellIDs[9]
        if rank9 then
            CastSpell(rank9, "spell")
            SpellTargetUnit(target)
            return
        end
    end

    -- Step 4: Flash of Light (downranked)
    local spellID, healSize = QuickHeal_Paladin_FindSpellToUse(target)
    if spellID then
        CastSpell(spellID, "spell")
        SpellTargetUnit(target)
    end

    -- Step 5: Offensive - Holy Strike if valid
    Theo_CastHolyStrike()
end

-- Register the slash command
SLASH_QUICKTHEO1 = "/qhtheo"
SlashCmdList["QUICKTHEO"] = QuickTheo_Command
