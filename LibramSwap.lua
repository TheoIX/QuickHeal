-- LibramSwap.lua
-- Author: You
-- Version: 1.0
-- Description: A Turtle WoW 1.12 addon that automatically equips the correct libram before casting specific Paladin spells.
-- Usage: Drop this file into your addon folder and list it in the .toc file. Toggle with /libramswap.
-- Default state: OFF (use /libramswap to enable)

-- Toggle flag (default OFF)
local LibramSwapEnabled = false

-- Mapping from spell names to libram items
local LibramMap = {
    ["Consecration"]         = "Libram of the Faithful",
    ["Holy Shield"]          = "Libram of the Dreamguard",
    ["Holy Light"]           = "Libram of Radiance",
    ["Flash of Light"]       = "Libram of Light",
    ["Cleanse"]              = "Libram of Grace",
    ["Hammer of Justice"]    = "Libram of the Justicar",
    ["Hand of Freedom"]      = "Libram of the Resolute",
    ["Crusader Strike"]      = "Libram of the Eternal Tower",
    ["Holy Strike"]          = "Libram of the Eternal Tower",
    ["Seal of Wisdom"]       = "Libram of Hope",
    ["Seal of Light"]        = "Libram of Hope",
    ["Seal of Justice"]      = "Libram of Hope",
    ["Seal of Command"]      = "Libram of Hope",
    ["Seal of the Crusader"] = "Libram of Hope",
    ["Seal of Righteousness"] = "Libram of Hope",
}

-- Check for an item in bags, return bag and slot or nil
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

-- Equip the specified libram from your bags using HasItemInBags
local function EquipLibram(itemName)
    local bag, slot = HasItemInBags(itemName)
    if bag and slot then
        UseContainerItem(bag, slot)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAFF[LibramSwap]: Equipped|r " .. itemName)
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555[LibramSwap]: Could not find|r " .. itemName)
        return false
    end
end

-- Override CastSpellByName to equip the proper libram before casting
local Original_CastSpellByName = CastSpellByName
function CastSpellByName(spellName, bookType)
    if LibramSwapEnabled then
        local libram = LibramMap[spellName]
        if libram then
            local currentLink = GetInventoryItemLink("player", 17)
            if not (currentLink and string.find(currentLink, libram)) then
                EquipLibram(libram)
            end
        end
    end
    return Original_CastSpellByName(spellName, bookType)
end

-- Also override CastSpell for addons that use spellbook index casting
local Original_CastSpell = CastSpell
function CastSpell(spellIndex, bookType)
    if LibramSwapEnabled then
        local spellName = GetSpellName(spellIndex, bookType)
        local libram = LibramMap[spellName]
        if libram then
            local currentLink = GetInventoryItemLink("player", 17)
            if not (currentLink and string.find(currentLink, libram)) then
                EquipLibram(libram)
            end
        end
    end
    return Original_CastSpell(spellIndex, bookType)
end

-- Register slash command just like TheoMode style at bottom
SLASH_LIBRAMSWAP1 = "/libramswap"
SlashCmdList["LIBRAMSWAP"] = function()
    LibramSwapEnabled = not LibramSwapEnabled
    if LibramSwapEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("LibramSwap ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("LibramSwap DISABLED", 1, 0, 0)
    end
end
