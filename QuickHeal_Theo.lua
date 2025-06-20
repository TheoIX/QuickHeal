-- QuickTheo integrated with cooldown checks and LunaUF mouseover casting

local BOOKTYPE_SPELL = "spell"

local QuickTheo_EnableTrinkets = false
local QuickTheo_EnableRacial = false
local QuickTheo_EnableMouseover = false
local QuickTheo_EnableEmergency = false
local QuickTheo_SealTime = 0
local QuickTheo_LastHolyLightCastTime = 0
local QuickTheo_LastSealCast = nil
local QuickTheo_LastHealedTarget = nil

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

local function HasSealOfWisdom()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name and string.find(name, "Seal of Wisdom") then
            return true
        end
    end
    return false
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

    if isValidTarget() and IsSpellReady("Holy Strike") then
        CastSpellByName("Holy Strike")
        AttackTarget()
        QuickTheo_WaitingForJudgement = false
        return true
    end

    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
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
                if (IsSpellInRange("Holy Shock", unit) == 1 or IsSpellInRange("Flash of Light", unit) == 1)
                    and percent < lowestHP
                    and UnitName(unit) ~= QuickTheo_LastHealedTarget then
                    lowestHP = percent
                    bestUnit = unit
                end
            end
        end
    end

    -- fallback to last healed if no better option found
    if not bestUnit then
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
    end

    return bestUnit, lowestHP
end

local function QuickTheo_MouseoverHeal()
    if UnitExists("mouseover") and UnitIsFriend("player", "mouseover") and not UnitIsDeadOrGhost("mouseover") then
        if IsSpellReady("Flash of Light") then
            CastSpellByName("Flash of Light")
            SpellTargetUnit("mouseover")
            QuickTheo_LastHealedTarget = UnitName("mouseover")
            return true
        end
    end
    return false
end

function QuickTheo_RunLogic()
    if QuickTheo_EnableMouseover and QuickTheo_MouseoverHeal and QuickTheo_MouseoverHeal() then return end

    if QuickTheo_EnableRacial and IsSpellReady("Perception") then
        CastSpellByName("Perception")
    end

    if QuickTheo_EnableTrinkets then
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    for slot = 13, 14 do
        local item = GetInventoryItemLink("player", slot)
        if item then
            -- Warmth of Forgiveness (only if mana < 85%)
            if string.find(item, "Warmth of Forgiveness") and maxMana > 0 and (mana / maxMana) < 0.85 then
                local start, duration, enable = GetInventoryItemCooldown("player", slot)
                if enable == 1 and (start == 0 or duration == 0) then
                    UseInventoryItem(slot)
                end
            end

            -- Eye of the Dead (if multiple injured raid members)
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
                if injuredCount >= 5 then -- significant raid damage
                    local start, duration, enable = GetInventoryItemCooldown("player", slot)
                    if enable == 1 and (start == 0 or duration == 0) then
                        UseInventoryItem(slot)
                    end
                end
            end
        end
    end
end

    if QuickTheo_EnableEmergency and (UnitHealth("player") / UnitHealthMax("player")) < 0.20 then
        if IsSpellReady("Divine Shield") then
            CastSpellByName("Divine Shield")
        end
    end

    if IsSpellReady("Holy Strike") and Theo_CastHolyStrike and Theo_CastHolyStrike() then return end

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
        return
    end

    local target, hpPercent = Theo_GetLowestHPTarget()
    if not target then return end

    local currentTime = GetTime()
    if hasJudgement and hpPercent < 0.5 and IsSpellReady("Holy Light(Rank 9)") and (currentTime - QuickTheo_LastHolyLightCastTime > 2) then
        QuickTheo_LastHolyLightCastTime = currentTime
        QuickTheo_LastHealedTarget = UnitName(target)
        CastSpellByName("Holy Light(Rank 9)")
        SpellTargetUnit(target)
        return
    end

    if Theo_CastHolyShockIfReady then
        Theo_CastHolyShockIfReady(target)
    end

    local spellID = QuickHeal_Paladin_FindSpellToUse(target)
    if spellID then
        QuickTheo_LastHealedTarget = UnitName(target)
        CastSpell(spellID, BOOKTYPE_SPELL)
        SpellTargetUnit(target)
    end
end

function Theo_CastHolyShockIfReady(target)
    if not IsSpellReady("Holy Shock") then return end
    if IsSpellInRange("Holy Shock", target) ~= 1 then return end

    local hp = UnitHealth(target)
    local maxhp = UnitHealthMax(target)
    local percent = (maxhp > 0) and (hp / maxhp) or 1
    local hasDaybreak = QuickHeal_DetectBuff(target, "spell_holy_surgeoflight")

    if not hasDaybreak or percent < 0.8 then
        QuickTheo_LastHealedTarget = UnitName(target)
        CastSpellByName("Holy Shock", target)
    end
end

function QuickTheo_Command()
    QuickTheo_RunLogic()
end

local function QuickTheo_ToggleOptions()
    QuickTheo_EnableRacial = not QuickTheo_EnableRacial
    QuickTheo_EnableTrinkets = not QuickTheo_EnableTrinkets
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Racial: " .. (QuickTheo_EnableRacial and "ON" or "OFF") ..
        " | Trinkets: " .. (QuickTheo_EnableTrinkets and "ON" or "OFF"))
end

local function QuickTheo_ToggleMouseover()
    QuickTheo_EnableMouseover = not QuickTheo_EnableMouseover
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Mouseover casting: " .. (QuickTheo_EnableMouseover and "ON" or "OFF"))
end

local function QuickTheo_ToggleEmergency()
    QuickTheo_EnableEmergency = not QuickTheo_EnableEmergency
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[QuickTheo] Emergency logic (Divine Shield, Healthstone, Potion): " .. (QuickTheo_EnableEmergency and "ON" or "OFF"))
end

local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SLASH_QUICKTOGGLE1 = "/qhtoggles"
    SLASH_QHMOUSE1 = "/qhmouse"
    SLASH_QHEMERGENCY1 = "/qhemergency"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
    SlashCmdList["QUICKTOGGLE"] = QuickTheo_ToggleOptions
    SlashCmdList["QHMOUSE"] = QuickTheo_ToggleMouseover
    SlashCmdList["QHEMERGENCY"] = QuickTheo_ToggleEmergency
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", InitQuickTheo)
