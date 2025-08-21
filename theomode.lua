-- TheoMode — Holy Paladin healer core (Turtle WoW 1.12)
-- Hardened Holy Shock heal-only with no visible target swap; keeps enemy target for melee weave
-- Date: 2025-08-21 (fix: nil Theo_CastHolyShock; repaired broken helper; removed stray return)

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

-- Optional: bag scan (kept from your file)
local function HasItemInBags(itemName)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, itemName) then
                return bag, slot
            end
        end
    end
    return nil
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
        if string.find(buff, "Seal of Wisdom") then return true end
    end
    return false
end

local function QuickHeal_DetectBuff(unit, texture)
    for i = 1, 40 do
        local icon = UnitBuff(unit, i)
        if not icon then break end
        if string.find(icon, texture) then return true end
    end
    return false
end

-- ============================================================
-- Anti-auto-damage wrappers (no visible friendly swap)
-- ============================================================
-- For hybrid spells like Holy Shock: if you have a hostile target, auto-resolution can choose damage.
-- This wrapper briefly clears hostile target (so there is NO target), casts on the chosen friendly via
-- unit-aware helper or cursor, then restores your previous target. To the eye, it does not flicker.
local function Theo_NoSwapCastOnUnit(spellName, unit)
    if not UnitExists(unit) or not UnitIsFriend("player", unit) or UnitIsDeadOrGhost(unit) then
        return false
    end

    local hadTarget = UnitExists("target")
    local prevWasHostile = hadTarget and UnitCanAttack("player", "target")

    -- Only clear if hostile; if your current target is friendly, we keep it
    if prevWasHostile then ClearTarget() end

    -- Try SuperWoW/Cleveroid direct unit casts
    if type(CR_SpellOnUnit) == "function" then
        local ok = CR_SpellOnUnit(spellName, unit)
        if prevWasHostile and hadTarget then TargetLastTarget() end
        if ok then return true end
    end
    if type(CR_CastSpellOnUnit) == "function" then
        local ok = CR_CastSpellOnUnit(spellName, unit)
        if prevWasHostile and hadTarget then TargetLastTarget() end
        if ok then return true end
    end
    if type(CastSpellByNameEx) == "function" then
        local ok = CastSpellByNameEx(spellName, unit)
        if prevWasHostile and hadTarget then TargetLastTarget() end
        if ok then return true end
    end

    -- Cursor resolve path
    CastSpellByName(spellName)
    if SpellIsTargeting() then
        SpellTargetUnit(unit)
        if prevWasHostile and hadTarget then TargetLastTarget() end
        return true
    end

    -- Hardened fallback (momentary friendly target then restore)
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

-- Legacy hardened helper (kept for clarity where used directly)
local function Theo_SafeCastOnFriendlyUnit(spellName, unit)
    if not UnitExists(unit) or not UnitIsFriend("player", unit) or UnitIsDeadOrGhost(unit) then
        return false
    end
    local hadTarget = UnitExists("target")
    local hostileBefore = hadTarget and UnitCanAttack("player", "target")
    if hostileBefore then ClearTarget() end
    TargetUnit(unit)
    CastSpellByName(spellName)
    if SpellIsTargeting() then SpellTargetUnit(unit) end
    if SpellIsTargeting() then
        SpellStopTargeting()
        if hadTarget then TargetLastTarget() end
        return false
    end
    if hadTarget then TargetLastTarget() else ClearTarget() end
    return true
end

-- =========================================
-- Globals & Toggles
-- =========================================
QuickHeal_EnableMouseoverFL7 = QuickHeal_EnableMouseoverFL7 or false
Theo_EnableUtilities = Theo_EnableUtilities or false
Theo_LastPerception = Theo_LastPerception or 0
Theo_LastWarmth = Theo_LastWarmth or 0
Theo_LastEye = Theo_LastEye or 0

QuickHeal_EnableTheomode = QuickHeal_EnableTheomode or false
local TheoMode_LastHealedTarget = nil
local QuickTheo_SealTime = QuickTheo_SealTime or 0
local QuickTheo_LastSealCast = QuickTheo_LastSealCast
local QuickTheo_WaitingForJudgement = QuickTheo_WaitingForJudgement or false
local Theo_LastHolyLightTime = Theo_LastHolyLightTime or 0

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

    -- Perception Logic
    if now - Theo_LastPerception > 180 then
        if IsSpellReady("Perception") then
            CastSpellByName("Perception")
            Theo_LastPerception = now
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
        RunScript('UnitXP("target", "nearestEnemy")')
    end

    if isValidTarget() then
        local sharedReady = GetSharedCooldown({"Holy Strike", "Crusader Strike"})
        if sharedReady then
            if IsCrusaderStrikeConditionMet() and IsSpellReady("Crusader Strike") then
                CastSpellByName("Crusader Strike")
                RunScript('UnitXP("target", "nearestEnemy")')
                QuickTheo_WaitingForJudgement = false
                return true
            elseif IsSpellReady("Holy Strike") then
                CastSpellByName("Holy Strike")
                RunScript('UnitXP("target", "nearestEnemy")')
                QuickTheo_WaitingForJudgement = false
                return true
            end
        end
    end
    return false
end

-- New Holy Shock with no-swap cast + guaranteed heal
function Theo_CastHolyShock()
    local ready = IsSpellReady("Holy Shock")
    if not ready then return false end

    -- evaluate lowest <70% in range
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

local function TheoQHHandler()
    if QuickHeal_EnableMouseoverFL7 then
        local focus = GetMouseFocus()
        local unit = focus and focus.unit
        if unit and UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit)
           and IsSpellInRange("Flash of Light(Rank 7)", unit) == 1 and IsSpellReady("Flash of Light") then
            CastSpellByName("Flash of Light(Rank 7)")
            SpellTargetUnit(unit)
            return
        end
    end

    if QuickHeal_EnableTheomode then
        -- healer-first ordering
        if Theo_CastHolyShock() then return end
        if Theo_CastHolyLight() then return end
        if Theo_CastHolyStrike() then return end
        QuickHeal()
    else
        QuickHeal()
    end
end

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

SLASH_THEOFL7TOGGLE1 = "/theofl7"
SlashCmdList["THEOFL7TOGGLE"] = function()
    QuickHeal_EnableMouseoverFL7 = not QuickHeal_EnableMouseoverFL7
    if QuickHeal_EnableMouseoverFL7 then
        DEFAULT_CHAT_FRAME:AddMessage("Theo Mouseover FL7 ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Theo Mouseover FL7 DISABLED", 1, 0, 0)
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

SlashCmdList["THEOQH"] = TheoQHHandler
SLASH_THEOQH1 = "/theoqh"
