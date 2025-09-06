-- QuickTheoDPS: Retribution Paladin DPS macro for Turtle WoW (1.12)
QuickTheo_LionheartMode = false
QuickTheo_UseSealOfRighteousness = false
QuickTheo_UseWisdomFallback = false
QuickTheo_UseHolyShock = false
QuickTheo_UseConsecration = false
QuickTheo_HolyMightExpireTime = 0
QuickTheo_ZealMode = false
QuickTheo_ZealStacks = 0
local theoUseTrinkets = false

local BOOKTYPE_SPELL = "spell"

local function IsSpellReady(spellName)
    for i = 1, 300 do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if spellName == name or (rank and spellName == name .. "(" .. rank .. ")") then
            local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
            return enabled == 1 and (start == 0 or duration == 0), start, duration
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
    if not TheoDPS_IsTargetValid() or (IsSpellInRange("Holy Strike", "target") ~= 1 and IsSpellInRange("Judgement", "target") ~= 1) then
        RunScript('UnitXP("target", "nearestEnemy")')
    end
end

local function TheoDPS_HasBuff(buffName)
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

local function TheoDPS_CastStrike()
    if not TheoDPS_IsTargetValid() then
        return false
    end

    local inRange = IsSpellInRange("Holy Strike", "target") == 1 or IsSpellInRange("Crusader Strike", "target") == 1
    if not inRange then return false 
end

if QuickTheo_LionheartMode then
        if IsSpellReady("Crusader Strike") then
            CastSpellByName("Crusader Strike")
            return true
        end
        return false
    end

    local hasZeal = TheoDPS_HasBuff("Zeal")

    -- Zeal Mode logic: always cast 3 Crusader Strikes when Zeal is missing
    if QuickTheo_ZealMode and QuickTheo_ZealStacks < 3 then
        local crusaderReady = IsSpellReady("Crusader Strike")
        if crusaderReady then
            CastSpellByName("Crusader Strike")
            QuickTheo_ZealStacks = QuickTheo_ZealStacks + 1
            return true
        else
            return false -- wait for Crusader cooldown
        end
    elseif QuickTheo_ZealMode and hasZeal and QuickTheo_ZealStacks >= 3 then
        -- Zeal rotation completed and buff is present, resume normal logic
    elseif QuickTheo_ZealMode and not hasZeal and QuickTheo_ZealStacks >= 3 then
        -- Reset and restart Zeal logic
        QuickTheo_ZealStacks = 0
        return false
    end
   
    local hasHolyMight = TheoDPS_HasBuff("Holy Might")
    local holyReady, holyStart, holyDur = IsSpellReady("Holy Strike")
    local holyCooldownLeft = holyReady and 0 or (holyStart + holyDur - GetTime())
    local holyMightLeft = math.max(0, QuickTheo_HolyMightExpireTime - GetTime())

    if not hasHolyMight and holyReady then
        CastSpellByName("Holy Strike")
        QuickTheo_HolyMightExpireTime = GetTime() + 20
        QuickTheo_ZealStacks = 0
        return true
    end

    if holyMightLeft > 0 and math.abs(holyMightLeft - holyCooldownLeft) <= 2 and holyReady then
        CastSpellByName("Holy Strike")
        QuickTheo_ZealStacks = 0
        return true
    end

    if hasHolyMight and IsSpellReady("Crusader Strike") then
        CastSpellByName("Crusader Strike")
        return true
    end

    return false
end

local function TheoDPS_CastAppropriateSeal()
    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (maxMana > 0) and (mana / maxMana) or 1

    local preferredSeal = QuickTheo_UseSealOfRighteousness and "Seal of Righteousness" or "Seal of Command"

    if QuickTheo_UseWisdomFallback and manaPercent <= 0.20 then
        if not TheoDPS_HasBuff("Seal of Wisdom") and IsSpellReady("Seal of Wisdom") then
            CastSpellByName("Seal of Wisdom")
            return true
        end
    else
        if not TheoDPS_HasBuff(preferredSeal) and IsSpellReady(preferredSeal) then
            CastSpellByName(preferredSeal)
            return true
        end
    end
    return false
end

local function TheoDPS_CastJudgement()
    if not TheoDPS_IsTargetValid() then return false end
    if IsSpellInRange("Judgement", "target") ~= 1 then return false end

    if IsSpellReady("Judgement") then
        CastSpellByName("Judgement")
        return true
    end
    return false
end

local function TheoDPS_CastHolyShock()
    if not QuickTheo_UseHolyShock then return false end
    if not IsSpellReady("Holy Shock") then return false end

    local hp, maxhp = UnitHealth("player"), UnitHealthMax("player")
    local hpct = (maxhp and maxhp > 0) and (hp / maxhp) or 1

    if hpct < 0.50 then
        -- Heal yourself without changing target
        CastSpellByName("Holy Shock")
        SpellTargetUnit("player")
        return true
    else
        -- Damage your current target if valid and in range
        if not TheoDPS_IsTargetValid() then return false end
        if IsSpellInRange("Holy Shock", "target") ~= 1 then return false end
        CastSpellByName("Holy Shock")
        return true
    end
end

local function TheoDPS_CastExorcism()
    TheoDPS_TargetEnemyIfNeeded()
    if not TheoDPS_IsTargetValid() then return false end
    if not UnitCreatureType("target") then
        return false
    end

    local creatureType = UnitCreatureType("target")
    if (creatureType == "Undead" or creatureType == "Demon") and IsSpellReady("Exorcism") and IsSpellInRange("Exorcism", "target") == 1 then
        CastSpellByName("Exorcism")
        return true
    end
    return false
end

local function TheoDPS_CastHammerOfWrath()
    TheoDPS_TargetEnemyIfNeeded()
    if not TheoDPS_IsTargetValid() then return false end
    if UnitHealth("target") / UnitHealthMax("target") > 0.20 then return false end
    if UnitHealth("target") < 5000 then return false end

    if IsSpellReady("Hammer of Wrath") and IsSpellInRange("Hammer of Wrath", "target") == 1 then
        CastSpellByName("Hammer of Wrath")
        return true
    end
    return false
end

local function TheoDPS_CastRepentance()
    if UnitLevel("target") ~= -1 then return false end
    if UnitHealth("target") <= 10000 then return false end

    if IsSpellReady("Repentance") and IsSpellInRange("Repentance", "target") == 1 then
        CastSpellByName("Repentance")
        return true
    end
    return false
end

local function TheoDPS_CastConsecration()
    if not QuickTheo_UseConsecration then return false end

    local mana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPercent = (maxMana > 0) and (mana / maxMana) or 0

    if IsSpellReady("Consecration") then
        if manaPercent <= 0.50 then
            -- Use Rank 1 when conserving mana
            CastSpellByName("Consecration(Rank 1)")
            return true
        else
            -- Use highest rank when healthy on mana
            CastSpellByName("Consecration")
            return true
        end
    end
    return false
end

local function QuickTheo_ToggleLionheartMode()
    QuickTheo_LionheartMode = not QuickTheo_LionheartMode
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Lionheart Mode: " .. (QuickTheo_LionheartMode and "ON" or "OFF"))
end

local function QuickTheo_ToggleZealMode()
    QuickTheo_ZealMode = not QuickTheo_ZealMode
    QuickTheo_ZealStacks = 0
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Zeal Mode: " .. (QuickTheo_ZealMode and "ON" or "OFF"))
end

local function QuickTheo_ToggleWisdomFallback()
    QuickTheo_UseWisdomFallback = not QuickTheo_UseWisdomFallback
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Wisdom Fallback at 20%: " .. (QuickTheo_UseWisdomFallback and "ON" or "OFF"))
end

local function QuickTheo_ToggleConsecration()
    QuickTheo_UseConsecration = not QuickTheo_UseConsecration
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Consecration: " .. (QuickTheo_UseConsecration and "ON" or "OFF"))
end

local function QuickTheo_ToggleSealOfRighteousness()
    QuickTheo_UseSealOfRighteousness = not QuickTheo_UseSealOfRighteousness
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Seal Preference: " .. (QuickTheo_UseSealOfRighteousness and "Righteousness" or "Command"))
end

local function QuickTheoDPS_RunLogic()
    if IsSpellReady("Perception") then
        CastSpellByName("Perception")
        return
    end


    TheoDPS_TargetEnemyIfNeeded()

    if TheoDPS_CastStrike() then return end
    if TheoDPS_CastAppropriateSeal() then return end
    if TheoDPS_CastJudgement() then return end
    if TheoDPS_CastHolyShock() then return end
    if TheoDPS_CastExorcism() then return end
    if TheoDPS_CastHammerOfWrath() then return end
    if TheoDPS_CastRepentance() then return end
    if TheoDPS_CastConsecration() then return end
end

function QuickTheoDPS_Command()
    
     if theoUseTrinkets then
        -- slot 13
        local start13, _, enable13 = GetInventoryItemCooldown("player", 13)
        if enable13 == 1 and start13 == 0 then
            UseInventoryItem(13)
        end
        -- slot 14
        local start14, _, enable14 = GetInventoryItemCooldown("player", 14)
        if enable14 == 1 and start14 == 0 then
            UseInventoryItem(14)
        end
    end

    QuickTheoDPS_RunLogic()
end

local function InitQuickTheoDPS()
    SLASH_QUICKTHEODPS1 = "/qhtheodps"
    SlashCmdList["QUICKTHEODPS"] = QuickTheoDPS_Command
    SLASH_QHWISDOM1 = "/qhwisdom"
    SlashCmdList["QHWISDOM"] = QuickTheo_ToggleWisdomFallback
    SLASH_QHCONSECRATION1 = "/qhconsecration"
    SlashCmdList["QHCONSECRATION"] = QuickTheo_ToggleConsecration
    SLASH_QHSPELLRET1 = "/qhspellret"
    SlashCmdList["QHSPELLRET"] = QuickTheo_ToggleSealOfRighteousness
    SLASH_QHZEAL1 = "/zealmode"
    SlashCmdList["QHZEAL"] = QuickTheo_ToggleZealMode
    SLASH_QHLIONHEART1 = "/lionheart"
    SlashCmdList["QHLIONHEART"] = QuickTheo_ToggleLionheartMode
end

SLASH_SHOCKADIN1 = "/shockadin"
SlashCmdList["SHOCKADIN"] = function()
    QuickTheo_UseHolyShock = not QuickTheo_UseHolyShock
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[QuickTheo] Holy Shock: " ..
        (QuickTheo_UseHolyShock and "ON" or "OFF"))
end

-- 2) Register its own slash (won’t collide with other addons)
SLASH_THEOUSETRINKETS1 = "/usetrinkets"
SlashCmdList["THEOUSETRINKETS"] = function()
    theoUseTrinkets = not theoUseTrinkets
    if theoUseTrinkets then
        DEFAULT_CHAT_FRAME:AddMessage("Theo Trinkets: ON", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Theo Trinkets: OFF", 1, 0, 0)
    end
end


local dpsFrame = CreateFrame("Frame")
dpsFrame:RegisterEvent("PLAYER_LOGIN")
dpsFrame:SetScript("OnEvent", InitQuickTheoDPS)
