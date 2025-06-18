-- QuickTheo integrated with cooldown checks and LunaUF mouseover casting

local BOOKTYPE_SPELL = "spell"

local QuickTheo_EnableTrinkets = true
local QuickTheo_EnableRacial = true
local QuickTheo_EnableMouseover = false
local QuickTheo_SealTime = 0

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

local function QuickTheo_MouseoverHeal()
    if QuickTheo_EnableMouseover and UnitExists("mouseover") and UnitIsFriend("player", "mouseover") and not UnitIsDeadOrGhost("mouseover") then
        if IsSpellReady("Flash of Light") then
            CastSpellByName("Flash of Light")
            SpellTargetUnit("mouseover")
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[QuickTheo] Casting Flash of Light on mouseover target")
            return true
        end
    end
    return false
end

local function Theo_CastHolyShockIfReady(target)
    if not IsSpellReady("Holy Shock") then return end

    if IsSpellInRange("Holy Shock", target) ~= 1 then return end

    local hp = UnitHealth(target)
    local maxhp = UnitHealthMax(target)
    local percent = (maxhp > 0) and (hp / maxhp) or 1
    local hasDaybreak = QuickHeal_DetectBuff(target, "spell_holy_surgeoflight")

    -- Always cast if no Daybreak is present, or if target is under 80%
    if not hasDaybreak or percent < 0.8 then
        CastSpellByName("Holy Shock", target)
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[QuickTheo] Casting Holy Shock on " .. target)
    end
end


    function QuickTheo_RunLogic()
    if QuickTheo_EnableMouseover and QuickTheo_MouseoverHeal() then return end

    if QuickTheo_EnableRacial and IsSpellReady("Perception") then
        CastSpellByName("Perception")
    end

    if QuickTheo_EnableTrinkets then
        local mana = UnitMana("player")
        local maxMana = UnitManaMax("player")
        if maxMana > 0 and (mana / maxMana) < 0.85 then
            for slot = 13, 14 do
                local item = GetInventoryItemLink("player", slot)
                if item and string.find(item, "Warmth of Forgiveness") then
                    local start, duration, enable = GetInventoryItemCooldown("player", slot)
                    if enable == 1 and (start == 0 or duration == 0) then
                        UseInventoryItem(slot)
                    end
                end
            end
        end
    end

    if (UnitHealth("player") / UnitHealthMax("player")) < 0.20 then
        if IsSpellReady("Divine Shield") then
            CastSpellByName("Divine Shield")
        else
            local usedEmergencyItem = false
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local itemLink = GetContainerItemLink(bag, slot)
                    if itemLink and string.find(itemLink, "Healthstone") then
                        local start, duration, enable = GetContainerItemCooldown(bag, slot)
                        if enable == 1 and (start == 0 or duration == 0) then
                            UseContainerItem(bag, slot)
                            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[QuickTheo] Using emergency Healthstone")
                            usedEmergencyItem = true
                            break
                        end
                    end
                end
                if usedEmergencyItem then break end
            end
            if not usedEmergencyItem then
                for bag = 0, 4 do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local itemLink = GetContainerItemLink(bag, slot)
                        if itemLink and string.find(itemLink, "Healing Potion") then
                            local start, duration, enable = GetContainerItemCooldown(bag, slot)
                            if enable == 1 and (start == 0 or duration == 0) then
                                UseContainerItem(bag, slot)
                                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[QuickTheo] Using emergency healing potion")
                                usedEmergencyItem = true
                                break
                            end
                        end
                    end
                    if usedEmergencyItem then break end
                end
            end
        end
    end

    local hasJudgementBuff = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    local targetValid = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsPlayer("target")
    local judgementRange = IsSpellInRange("Judgement", "target") == 1

    if IsSpellReady("Holy Strike") and Theo_CastHolyStrike() then return end

    -- Seal of Wisdom + Judgement Combo (only if no Holy Judgement and Holy Strike is on cooldown)
    if targetValid and judgementRange and not HasSealOfWisdom() and not QuickHeal_DetectBuff("player", "ability_paladin_judgementblue") and not IsSpellReady("Holy Strike") and IsSpellReady("Judgement") then
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

    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")

    Theo_CastHolyShockIfReady(target)

    if hasJudgement and hpPercent < 0.5 and IsSpellReady("Holy Light(Rank 9)") then
        CastSpellByName("Holy Light(Rank 9)")
        SpellTargetUnit(target)
        QuickTheo_LastHolyLightTarget = target
        return
    else
        QuickTheo_LastHolyLightTarget = nil
    end

    local spellID = QuickHeal_Paladin_FindSpellToUse(target)
    if not spellID then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[QuickTheo] No valid healing spell found for target: " .. (target or "nil"))
    end
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

function QuickTheo_ToggleMouseover()
    QuickTheo_EnableMouseover = not QuickTheo_EnableMouseover
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Mouseover casting: " .. (QuickTheo_EnableMouseover and "ON" or "OFF"))
end

local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SLASH_QUICKTOGGLE1 = "/qhtoggles"
    SLASH_QHMOUSE1 = "/qhmouse"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
    SlashCmdList["QUICKTOGGLE"] = QuickTheo_ToggleOptions
    SlashCmdList["QHMOUSE"] = QuickTheo_ToggleMouseover
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitQuickTheo)
