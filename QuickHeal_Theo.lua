local BOOKTYPE_SPELL = "spell"
local lastDivineShieldTime = 0
local DIVINE_SHIELD_COOLDOWN = 300
local lastPerceptionTime = 0
local PERCEPTION_COOLDOWN = 180

local QuickTheo_WaitingForJudgement = false
local QuickTheo_LastHolyLightTarget = nil
local QuickTheo_EnableTrinkets = true
local QuickTheo_EnableRacial = true

-- ✅ Uses your addon’s shared buff detection system
local function HasSealOfWisdom()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name and string.find(name, "Seal of Wisdom") then
            return true
        end
    end
    return false
end

local function IsSpellOnCooldown(spellName)
    if not spellName or type(spellName) ~= "string" then return false end
    for i = 1, 300 do
        local name, _ = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if name == spellName then
            local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
            return start and duration and duration > 1.0
        end
    end
    return false
end

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
                if (IsSpellInRange("Holy Shock", unit) == 1 or IsSpellInRange("Flash of Light", unit) == 1) and percent < lowestHP then
                    lowestHP = percent
                    bestUnit = unit
                end
            end
        end
    end
    return bestUnit, lowestHP
end

local function Theo_CastDivineShieldIfLow()
    local now = GetTime()
    if now - lastDivineShieldTime < DIVINE_SHIELD_COOLDOWN then return end
    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    if maxhp > 0 and (hp / maxhp) < 0.25 then
        CastSpellByName("Divine Shield")
        lastDivineShieldTime = now
    end
end

local function Theo_CastPerceptionIfReady()
    if not QuickTheo_EnableRacial then return end
    local now = GetTime()
    if now - lastPerceptionTime >= PERCEPTION_COOLDOWN then
        CastSpellByName("Perception")
        lastPerceptionTime = now
    end
end

local function Theo_UseWarmthOfForgiveness()
    if not QuickTheo_EnableTrinkets then return end
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
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    local function isValidTarget()
        return UnitExists("target")
            and UnitCanAttack("player", "target")
            and not UnitIsDeadOrGhost("target")
            and not UnitIsPlayer("target")
            and IsSpellInRange("Holy Strike", "target") == 1
            and CheckInteractDistance("target", 3)
    end

    if not isValidTarget() then
        RunScript('UnitXP("target", "nearestEnemy")')
    end

    if not IsSpellOnCooldown("Holy Strike") and isValidTarget() then
        CastSpellByName("Holy Strike")
        AttackTarget()
        QuickTheo_WaitingForJudgement = false
        return true
    end

    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    return false
end

local function Theo_CastHolyShockIfReady(target)
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    CastSpellByName("Holy Shock", target)
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

function QuickTheo_RunLogic()
    Theo_CastPerceptionIfReady()
    Theo_UseWarmthOfForgiveness()

    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    if maxhp > 0 and (hp / maxhp) < 0.25 then
        Theo_CastDivineShieldIfLow()
    end

    if Theo_CastHolyStrike() then return end

    -- ✅ Detect Judgement Blue using your addon’s official method
    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    if hasJudgement then
        QuickTheo_WaitingForJudgement = false
    else
        local targetValid = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target")
        local judgementRange = IsSpellInRange("Judgement", "target") == 1

        if QuickTheo_WaitingForJudgement then
            CastSpellByName("Judgement")
            QuickTheo_WaitingForJudgement = false
            return
        elseif targetValid
            and judgementRange
            and IsSpellOnCooldown("Holy Strike")
            and not HasSealOfWisdom()
        then
            CastSpellByName("Seal of Wisdom")
            QuickTheo_WaitingForJudgement = true
            return
        end
    end

    -- ✅ Healing logic
    local target, hpPercent = Theo_GetLowestHPTarget()
    if not target then return end

    Theo_CastHolyShockIfReady(target)

    if hasJudgement and hpPercent < 0.5 then
        if QuickTheo_LastHolyLightTarget ~= target then
            CastSpellByName("Holy Light(Rank 9)")
            SpellTargetUnit(target)
            QuickTheo_LastHolyLightTarget = target
            return
        end
    else
        QuickTheo_LastHolyLightTarget = nil
    end

    local spellID = QuickHeal_Paladin_FindSpellToUse(target)
    if spellID then
        CastSpell(spellID, BOOKTYPE_SPELL)
        SpellTargetUnit(target)
    end
end

function QuickTheo_Command()
    QuickTheo_RunLogic()
end

function QuickTheo_ToggleOptions()
    QuickTheo_EnableRacial = not QuickTheo_EnableRacial
    QuickTheo_EnableTrinkets = not QuickTheo_EnableTrinkets
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Racial: " .. (QuickTheo_EnableRacial and "ON" or "OFF") ..
        " | Trinkets: " .. (QuickTheo_EnableTrinkets and "ON" or "OFF"))
end

local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SLASH_QUICKTOGGLE1 = "/qhtoggles"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
    SlashCmdList["QUICKTOGGLE"] = QuickTheo_ToggleOptions
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitQuickTheo)
