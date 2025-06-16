-- QuickHeal_Theo.lua (Manual Trigger Version with Toggles)

local BOOKTYPE_SPELL = "spell"
local lastHolyStrikeTime = 0
local HOLY_STRIKE_COOLDOWN = 6
local lastDivineShieldTime = 0
local DIVINE_SHIELD_COOLDOWN = 300
local lastPerceptionTime = 0
local PERCEPTION_COOLDOWN = 180

-- Toggles
local QuickTheo_EnableTrinkets = true
local QuickTheo_EnableRacial = true

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
                local inShockRange = IsSpellInRange("Holy Shock", unit) == 1
                local inHealRange = IsSpellInRange("Flash of Light", unit) == 1 or IsSpellInRange("Holy Light", unit) == 1
                if (inShockRange or inHealRange) and percent < lowestHP then
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
        local success = CastSpellByName("Divine Shield")
        if success ~= nil then
            lastDivineShieldTime = now
        end
    end
end

local function Theo_CastPerceptionIfReady()
    if not QuickTheo_EnableRacial then return end
    local now = GetTime()
    if now - lastPerceptionTime >= PERCEPTION_COOLDOWN then
        local success = CastSpellByName("Perception")
        if success ~= nil then
            lastPerceptionTime = now
        end
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
    local now = GetTime()

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

    if now - lastHolyStrikeTime >= HOLY_STRIKE_COOLDOWN and isValidTarget() then
        local success = CastSpellByName("Holy Strike(Rank 8)")
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
        if success ~= nil then
            AttackTarget()
            lastHolyStrikeTime = now
            return true
        end
    end

    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    return false
end

local function Theo_CastHolyShockIfReady(target)
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    CastSpellByName("Holy Shock", target)
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

-- Main logic (manual trigger)
function QuickTheo_RunLogic()
    Theo_CastPerceptionIfReady()
    Theo_UseWarmthOfForgiveness()

    local hp = UnitHealth("player")
    local maxhp = UnitHealthMax("player")
    if maxhp > 0 and (hp / maxhp) < 0.25 then
        Theo_CastDivineShieldIfLow()
    end

    if Theo_CastHolyStrike() then return end

    local target, hpPercent = Theo_GetLowestHPTarget()
    if not target then return end

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

-- Slash command: /qhtheo
function QuickTheo_Command()
    QuickTheo_RunLogic()
end

-- Slash command: /qhtoggles
function QuickTheo_ToggleOptions()
    QuickTheo_EnableRacial = not QuickTheo_EnableRacial
    QuickTheo_EnableTrinkets = not QuickTheo_EnableTrinkets

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Racial: " .. (QuickTheo_EnableRacial and "ON" or "OFF") ..
        " | Trinkets: " .. (QuickTheo_EnableTrinkets and "ON" or "OFF"))
end

-- Register both slash commands
local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SLASH_QUICKTOGGLE1 = "/qhtoggles"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
    SlashCmdList["QUICKTOGGLE"] = QuickTheo_ToggleOptions
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitQuickTheo)
