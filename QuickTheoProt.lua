-- QuickTheoProt.lua: Protection Paladin tanking helper for Turtle WoW (1.12)
-- Installation:
-- 1) Place this folder at Interface/AddOns/QuickTheoProt/
-- 2) Create QuickTheoProt.toc alongside this .lua with:
--    ## Interface: 11302
--    ## Title: QuickTheoProt
--    QuickTheoProt.lua

local BOOKTYPE_SPELL = "spell"

-- Helper: scan UnitBuff slots for buffName
local function UnitHasBuff(unit, buffName)
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        if strfind(name, buffName, 1, true) then
            return true
        end
    end
    return false
end

-- Helper: equip a libram by name using UseContainerItem (WoW 1.12)
local function EquipLibram(itemName)
    -- If already equipped, do nothing
    local equipped = GetInventoryItemLink("player", 16)
    if equipped and strfind(equipped, itemName, 1, true) then
        return true
    end
    -- Otherwise, find in bags and equip
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

-- Cast Consecration with libram swap, enemy within interact distance
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

-- Cast Holy Shield with libram swap
local function Theo_CastHolyShield()
    if UnitHasBuff("player", "Holy Shield") then return false end
    if IsSpellReady("Holy Shield")
       and UnitExists("target") and UnitCanAttack("player", "target")
       and not UnitIsDeadOrGhost("target") then
        EquipLibram("Libram of the Dreamguard")
        CastSpellByName("Holy Shield")
        return true
    end
    return false
end

-- Main tanking handler
function QuickTheoProt()
    -- Run XP lookup first
    RunScript('UnitXP("target","nearestEnemy")')
    -- Priority rotation
    if Theo_CastHolyStrike() then return end
    if Theo_CastConsecration() then return end
    if Theo_CastHolyShield() then return end
end

-- Event frame: apply Righteous Fury on login and after death
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("QuickTheoProt loaded! Use /quicktheoprot or /qhtprot", 0, 1, 0)
    end
    if not UnitHasBuff("player", "Righteous Fury") then
        CastSpellByName("Righteous Fury")
    end
end)

-- Slash registration
SLASH_QUICKTHEOPROT1 = "/quicktheoprot"
SLASH_QUICKTHEOPROT2 = "/qhtprot"
SlashCmdList["QUICKTHEOPROT"] = QuickTheoProt

