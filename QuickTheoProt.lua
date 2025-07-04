-- QuickTheoProt.lua: Protection Paladin tanking helper for Turtle WoW (1.12)
-- Installation:
-- 1) Place this folder at Interface/AddOns/QuickTheoProt/
-- 2) Create QuickTheoProt.toc alongside this .lua with:
--    ## Interface: 11302
--    ## Title: QuickTheoProt
--    QuickTheoProt.lua

local BOOKTYPE_SPELL = "spell"

-- State: track whether Judgement casting is enabled (hysteresis)
local judgementEnabled = true

-- Workaround buff detection using tooltip (adapted from QuickTheoDPS)
local function TheoProt_HasBuff(buffName)
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

-- Helper: equip a libram by name using UseContainerItem (WoW 1.12)
local function EquipLibram(itemName)
    local equipped = GetInventoryItemLink("player", 16)
    if equipped and strfind(equipped, itemName, 1, true) then return true end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and strfind(link, itemName, 1, true) then
                UseContainerItem(bag, slot)
                return true
            end
        end
    end
    return false
end

-- Utility: check spell cooldown by scanning the spellbook
local function IsSpellReady(spellName)
    for idx = 1, 300 do
        local name, rank = GetSpellName(idx, BOOKTYPE_SPELL)
        if not name then break end
        local full = (rank and rank ~= "") and (name .. "(" .. rank .. ")") or name
        if spellName == name or spellName == full then
            local start, duration, enabled = GetSpellCooldown(idx, BOOKTYPE_SPELL)
            return enabled == 1 and (duration == 0 or (start + duration) <= GetTime())
        end
    end
    return false
end

-- Cast Exorcism on demons or undead if ready
local function Theo_CastExorcism()
    if IsSpellReady("Exorcism")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target") then
        local cType = UnitCreatureType("target")
        if cType == "Demon" or cType == "Undead" then
            CastSpellByName("Exorcism")
            SpellTargetUnit("target")
            return true
        end
    end
    return false
end

-- Cast Holy Strike if ready and target in melee range
local function Theo_CastHolyStrike()
    if IsSpellReady("Holy Strike")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and IsSpellInRange("Holy Strike", "target") == 1 then
        CastSpellByName("Holy Strike")
        SpellTargetUnit("target")
        return true
    end
    return false
end

-- Cast Consecration with libram swap if enemy within interact distance
local function Theo_CastConsecration()
    if IsSpellReady("Consecration")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and CheckInteractDistance("target", 1) then
        EquipLibram("Libram of the Faithful")
        CastSpellByName("Consecration")
        return true
    end
    return false
end

-- Cast Holy Shield with libram swap if buff missing
local function Theo_CastHolyShield()
    if TheoProt_HasBuff("Holy Shield") then return false end
    if IsSpellReady("Holy Shield")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target") then
        EquipLibram("Libram of the Dreamguard")
        CastSpellByName("Holy Shield")
        return true
    end
    return false
end

-- Cast Seal of Righteousness if buff missing
local function Theo_CastSealOfRighteousness()
    if TheoProt_HasBuff("Seal of Righteousness") then return false end
    if IsSpellReady("Seal of Righteousness") then
        CastSpellByName("Seal of Righteousness")
        return true
    end
    return false
end

-- Cast Seal of Wisdom if buff missing
local function Theo_CastSealOfWisdom()
    if TheoProt_HasBuff("Seal of Wisdom") then return false end
    if IsSpellReady("Seal of Wisdom") then
        CastSpellByName("Seal of Wisdom")
        return true
    end
    return false
end

-- Cast Judgement if ready and in range
local function Theo_CastJudgement()
    if IsSpellReady("Judgement")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target")
       and IsSpellInRange("Judgement", "target") == 1 then
        CastSpellByName("Judgement")
        SpellTargetUnit("target")
        return true
    end
    return false
end
 


-- Main tanking handler with buff/judgement hysteresis and combat rotation
function QuickTheoProt()
RunScript('UnitXP("target", "nearestEnemy")')
    -- Mana and judgement state
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    local manaPct = (currentMana / maxMana) * 100

    -- Hysteresis: disable Judgement below 40%, re-enable above 75%
    if manaPct < 40 then
        judgementEnabled = false
    elseif manaPct > 75 then
        judgementEnabled = true
    end

    -- Seal and Judgement logic
    if judgementEnabled then
        if Theo_CastSealOfRighteousness() then return end
        if Theo_CastJudgement() then return end
    else
        if Theo_CastSealOfWisdom() then return end
    end

    -- Combat rotation
    if Theo_CastExorcism() then return end
    if Theo_CastHolyStrike() then return end
    if Theo_CastConsecration() then return end
    if Theo_CastHolyShield() then return end
end

-- Auto-attack on target changes
local autoFrame = CreateFrame("Frame")
autoFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
autoFrame:SetScript("OnEvent", EnsureAutoAttack)

-- Event frame: apply Righteous Fury on login and after death
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("QuickTheoProt loaded! Use /quicktheoprot or /qhtprot", 0, 1, 0)
    end
    if not TheoProt_HasBuff("Righteous Fury") then
        CastSpellByName("Righteous Fury")
    end
end)

-- Slash registration
SLASH_QUICKTHEOPROT1 = "/quicktheoprot"
SLASH_QUICKTHEOPROT2 = "/qhtprot"
SlashCmdList["QUICKTHEOPROT"] = QuickTheoProt
