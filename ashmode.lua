-- ashmode.lua (cleaned version)

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

QuickHeal_EnableMouseoverFL7 = false
Ash_EnableUtilities = false
Ash_LastPerception = 0
Ash_LastWarmth = 0
Ash_LastEye = 0

QuickHeal_EnableAshmode = false
local AshMode_LastHealedTarget = nil
local Ash_LastHolyLightTime = 0

-- =========================================
-- Core AshMode Logic
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

local function Ash_UseUtilities()
    if not Ash_EnableUtilities then return end
    local now = GetTime()

    -- Perception Logic
    if now - Ash_LastPerception > 180 then
        if IsSpellReady("Perception") then
            CastSpellByName("Perception")
            Ash_LastPerception = now
        end
    end

    -- Trinket Logic
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")

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

function Ash_CastHolyStrike()
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    Ash_UseUtilities()

    local function isValidTarget()
        return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
            and not UnitIsPlayer("target") and IsSpellInRange("Holy Strike", "target") == 1 and CheckInteractDistance("target", 3)
    end

    if not isValidTarget() then
        RunScript('UnitXP("target", "nearestEnemy")')
    end

    if isValidTarget() then
        local sharedReady = GetSharedCooldown({"Holy Strike", "Crusader Strike"})
        if sharedReady then
            if IsCrusaderStrikeConditionMet() and IsSpellReady("Crusader Strike") then
                CastSpellByName("Crusader Strike")
                RunScript('UnitXP("target", "nearestEnemy")')
                return true
            elseif IsSpellReady("Holy Strike") then
                CastSpellByName("Holy Strike")
                RunScript('UnitXP("target", "nearestEnemy")')
                return true
            end
        end
    end
    return false
end

function Ash_CastHolyShock()
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

function Ash_CastHolyLight()
    local now = GetTime()
    if now - Ash_LastHolyLightTime < 2 then return false end

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
        Ash_LastHolyLightTime = now
        return true
    end
    return false
end

-- =========================================
-- Logic Hooking
-- =========================================

local function AshQHHandler()
    if QuickHeal_EnableMouseoverFL7 then
        local focus = GetMouseFocus()
        local unit = focus and focus.unit

        if unit and UnitExists(unit)
        and UnitIsFriend("player", unit)
        and not UnitIsDeadOrGhost(unit)
        and IsSpellInRange("Flash of Light(Rank 7)", unit) == 1
        and IsSpellReady("Flash of Light") then
            CastSpellByName("Flash of Light(Rank 7)")
            SpellTargetUnit(unit)
            return
        end
    end

    if QuickHeal_EnableAshmode then
        local casted = Ash_CastHolyStrike()
        casted = Ash_CastHolyShock()  or casted
        casted = Ash_CastHolyLight()  or casted
        if not casted then
            QuickHeal()
        end
    else
        QuickHeal()
    end
end

-- =========================================
-- Slash Commands
-- =========================================

SLASH_ASHMODE1 = "/ashmode"
SlashCmdList["ASHMODE"] = function()
    QuickHeal_EnableAshmode = not QuickHeal_EnableAshmode
    if QuickHeal_EnableAshmode then
        DEFAULT_CHAT_FRAME:AddMessage("AshMode ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("AshMode DISABLED", 1, 0, 0)
    end
end

SLASH_ASHFL7TOGGLE1 = "/ashfl7"
SlashCmdList["ASHFL7TOGGLE"] = function()
    QuickHeal_EnableMouseoverFL7 = not QuickHeal_EnableMouseoverFL7
    if QuickHeal_EnableMouseoverFL7 then
        DEFAULT_CHAT_FRAME:AddMessage("Ash Mouseover FL7 ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Ash Mouseover FL7 DISABLED", 1, 0, 0)
    end
end

SLASH_ASHTOGGLES1 = "/ashtoggles"
SlashCmdList["ASHTOGGLES"] = function()
    Ash_EnableUtilities = not Ash_EnableUtilities
    if Ash_EnableUtilities then
        DEFAULT_CHAT_FRAME:AddMessage("Ash Utility Toggles ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Ash Utility Toggles DISABLED", 1, 0, 0)
    end
end

SlashCmdList["ASHQH"] = AshQHHandler
SLASH_ASHQH1 = "/ashqh"
