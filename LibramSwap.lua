-- LibramSwap.lua
-- Optimized version with skip-swap if already equipped and 1.2s throttle

-- Localize WoW API calls and Lua globals for performance
local GetContainerNumSlots  = GetContainerNumSlots
local GetContainerItemLink  = GetContainerItemLink
local UseContainerItem      = UseContainerItem
local GetInventoryItemLink  = GetInventoryItemLink
local GetSpellName          = GetSpellName
local string_find           = string.find
local GetTime               = GetTime

-- Toggle flag
local LibramSwapEnabled = false
local lastEquippedLibram = nil
local lastSwapTime = 0

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
    ["Seal of the Crusader"] = "Libram of Fervor",
    ["Seal of Righteousness"] = "Libram of Hope",
    ["Devotion Aura"]        = "Libram of Truth",
    ["Blessing of Might"]    = "Libram of Veracity",
    ["Blessing of Wisdom"]   = "Libram of Veracity",
    ["Blessing of Kings"]    = "Libram of Veracity",
    ["Blessing of Sanctuary"] = "Libram of Veracity",
    ["Blessing of Light"]    = "Libram of Veracity",
    ["Blessing of Salvation"] = "Libram of Veracity",
    ["Greater Blessing of Might"] = "Libram of Veracity",
    ["Greater Blessing of Wisdom"] = "Libram of Veracity",
    ["Greater Blessing of Kings"] = "Libram of Veracity",
    ["Greater Blessing of Sanctuary"] = "Libram of Veracity",
    ["Greater Blessing of Light"] = "Libram of Veracity",
    ["Greater Blessing of Salvation"] = "Libram of Veracity",
}

-- Check for an item in bags, return bag and slot or nil
local function HasItemInBags(itemName)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string_find(link, itemName) then
                return bag, slot
            end
        end
    end
    return nil
end

-- Equip libram only if not already equipped and 1.2s since last swap
local function EquipLibram(itemName)
    if lastEquippedLibram == itemName and GetInventoryItemLink("player", 17) and string_find(GetInventoryItemLink("player", 17), itemName) then
        return false
    end
    local now = GetTime()
    if now - lastSwapTime < 1.2 then return false end

    local bag, slot = HasItemInBags(itemName)
    if bag and slot then
        UseContainerItem(bag, slot)
        lastEquippedLibram = itemName
        lastSwapTime = now
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAAAFF[LibramSwap]: Equipped|r " .. itemName)
        return true
    end
    return false
end

-- Override CastSpellByName
local Original_CastSpellByName = CastSpellByName
function CastSpellByName(spellName, bookType)
    if LibramSwapEnabled then
        local libram = LibramMap[spellName]
        if spellName == "Flash of Light" and not HasItemInBags("Libram of Light") then
            libram = "Libram of Divinity"
        elseif spellName == "Holy Strike" and not HasItemInBags("Libram of the Eternal Tower") then
            libram = "Libram of Radiance"
        end
        if libram then EquipLibram(libram) end
    end
    return Original_CastSpellByName(spellName, bookType)
end

-- Override CastSpell
local Original_CastSpell = CastSpell
function CastSpell(spellIndex, bookType)
    if LibramSwapEnabled then
        local spellName = GetSpellName(spellIndex, bookType)
        local libram = LibramMap[spellName]
        if spellName == "Flash of Light" and not HasItemInBags("Libram of Light") then
            libram = "Libram of Divinity"
        elseif spellName == "Holy Strike" and not HasItemInBags("Libram of the Eternal Tower") then
            libram = "Libram of Radiance"
        end
        if libram then EquipLibram(libram) end
    end
    return Original_CastSpell(spellIndex, bookType)
end

-- Slash command
SLASH_LIBRAMSWAP1 = "/libramswap"
SlashCmdList["LIBRAMSWAP"] = function()
    LibramSwapEnabled = not LibramSwapEnabled
    if LibramSwapEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("LibramSwap ENABLED", 0, 1, 0)
    else
        DEFAULT_CHAT_FRAME:AddMessage("LibramSwap DISABLED", 1, 0, 0)
    end
end
