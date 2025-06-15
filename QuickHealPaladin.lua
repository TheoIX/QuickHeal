local function writeLine(s,r,g,b)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(s, r or 1, g or 1, b or 0.5)
    end
end

function QuickHeal_Paladin_GetRatioHealthyExplanation()
    local RatioHealthy = QuickHeal_GetRatioHealthy();
    local RatioFull = QuickHealVariables["RatioFull"];

    if RatioHealthy >= RatioFull then
        return QUICKHEAL_SPELL_HOLY_LIGHT .. " will never be used in combat. ";
    else
        if RatioHealthy > 0 then
            return QUICKHEAL_SPELL_HOLY_LIGHT .. " will only be used in combat if the target has more than " .. RatioHealthy*100 .. "% life, and only if the healing done is greater than the greatest " .. QUICKHEAL_SPELL_FLASH_OF_LIGHT .. " available. ";
        else
            return QUICKHEAL_SPELL_HOLY_LIGHT .. " will only be used in combat if the healing done is greater than the greatest " .. QUICKHEAL_SPELL_FLASH_OF_LIGHT .. " available. ";
        end
    end
end

function QuickHeal_Paladin_FindSpellToUse(Target, healType, multiplier, forceMaxHPS)
    local SpellID = nil;
    local HealSize = 0;
    local Overheal = false;

    -- +Healing-PenaltyFactor = (1-((20-LevelLearnt)*0.0375)) for all spells learnt before level 20
    local PF1 = 0.2875;
    local PF6 = 0.475;
    local PF14 = 0.775;

    -- Local aliases to access main module functionality and settings
    local RatioFull = QuickHealVariables["RatioFull"];
    local RatioHealthy = QuickHeal_GetRatioHealthy();
    local UnitHasHealthInfo = QuickHeal_UnitHasHealthInfo;
    local EstimateUnitHealNeed = QuickHeal_EstimateUnitHealNeed;
    local GetSpellIDs = QuickHeal_GetSpellIDs;
    local debug = QuickHeal_debug;

    -- Detect Daybreak on target
    local dbMod = QuickHeal_DetectBuff(Target,"Spell_Holy_AuraMastery");
    if dbMod then dbMod = 1.2 else dbMod = 1 end;
    debug("Daybreak healing modifier",dbMod);

    -- Get a list of ranks available of 'Flash of Light' and 'Holy Light'
    local SpellIDsHL = GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local SpellIDsFL = GetSpellIDs(QUICKHEAL_SPELL_FLASH_OF_LIGHT);
    local maxRankHL = table.getn(SpellIDsHL);
    local maxRankFL = table.getn(SpellIDsFL);
    local NoFL = maxRankFL < 1;
    debug(string.format("Found HL up to rank %d, and found FL up to rank %d", maxRankHL, maxRankFL))

    --Get max HealRanks that are allowed to be used
    local downRankFH = QuickHealVariables.DownrankValueFH  -- rank for 1.5 sec heals
    local downRankNH = QuickHealVariables.DownrankValueNH -- rank for < 1.5 sec heals


    -- below changed to not differentiate between in or out if combat. Original code down below
    -- Find suitable SpellID based on the defined criteria
    local k = 1;
    local K = 1;
    if InCombat then
        local k = 0.9; -- In combat means that target is loosing life while casting, so compensate
        local K = 0.8; -- k for fast spells (FL) and K for slow spells (HL)            3 = 4 | 3 < 4 | 3 > 4
    end

    -- Return immediatly if no player needs healing
    if not Target then
        return SpellID,HealSize;
    end

    if multiplier == nil then
        jgpprint(">>> multiplier is NIL <<<")
        --if multiplier > 1.0 then
        --    Overheal = true;
        --end
    elseif multiplier == 1.0 then
        jgpprint(">>> multiplier is " .. multiplier .. " <<<")
    elseif multiplier > 1.0 then
        jgpprint(">>> multiplier is " .. multiplier .. " <<<")
        Overheal = true;
    end

    -- Determine health and healneed of target
    local healneed;
    local Health;

    if QuickHeal_UnitHasHealthInfo(Target) then
        -- Full info available
        healneed = UnitHealthMax(Target) - UnitHealth(Target) - HealComm:getHeal(UnitName(Target)); -- Implementatin for HealComm
        if Overheal then
            healneed = healneed * multiplier;
        else
            --
        end
        Health = UnitHealth(Target) / UnitHealthMax(Target);
    else
        -- Estimate target health
        healneed = QuickHeal_EstimateUnitHealNeed(Target,true); -- needs HealComm implementation maybe
        if Overheal then
            healneed = healneed * multiplier;
        else
            --
        end
        Health = UnitHealth(Target)/100;
    end

    -- if BonusScanner is running, get +Healing bonus
    local Bonus = 0;
    if (BonusScanner) then
        Bonus = tonumber(BonusScanner:GetBonus("HEAL"));
        debug(string.format("Equipment Healing Bonus: %d", Bonus));
    end

    -- Calculate healing bonus
    local healMod15 = (1.5/3.5) * Bonus;
    local healMod25 = (2.5/3.5) * Bonus;
    debug("Final Healing Bonus (1.5,2.5)", healMod15,healMod25);

    local InCombat = UnitAffectingCombat('player') or UnitAffectingCombat(Target);

    -- Healing Light Talent (increases healing by 4% per rank)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,6);
    local hlMod = 4*talentRank/100 + 1;
    debug(string.format("Healing Light talentmodification: %f", hlMod))

    local TargetIsHealthy = Health >= RatioHealthy;
    local ManaLeft = UnitMana('player');

    if TargetIsHealthy then
        debug("Target is healthy",Health);
    end

    -- Detect proc of 'Hand of Edward the Odd' mace (next spell is instant cast)
    if QuickHeal_DetectBuff('player',"Spell_Holy_SearingLight") then
        debug("BUFF: Hand of Edward the Odd (out of combat healing forced)");
        InCombat = false;
    end

    -- Detect proc of 'Holy Judgement' (next Holy Light is fast cast)
if QuickHeal_DetectBuff('player', "ability_paladin_judgementblue") then
    debug("BUFF: Holy Judgement detected");

    local SpellIDsHL = QuickHeal_GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local rank9ID = SpellIDsHL and SpellIDsHL[9];

    if rank9ID then
        local foundTarget = nil;

        -- Check raid or party members (including self)
        local unitsToCheck = {"player", "target", "party1", "party2", "party3", "party4", "raid1", "raid2", "raid3", "raid4", "raid5",
                              "raid6", "raid7", "raid8", "raid9", "raid10", "raid11", "raid12", "raid13", "raid14", "raid15", "raid16",
                              "raid17", "raid18", "raid19", "raid20", "raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27",
                              "raid28", "raid29", "raid30", "raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40"}

        for _, unit in ipairs(unitsToCheck) do
            if UnitExists(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) then
                local health = UnitHealth(unit)
                local maxHealth = UnitHealthMax(unit)
                if maxHealth > 0 and (health / maxHealth) < 0.5 then
                    foundTarget = unit
                    break
                end
            end
        end

        if foundTarget then
            debug("Casting Rank 9 Holy Light on: " .. foundTarget);
            CastSpell(rank9ID, "spell");
            SpellTargetUnit(foundTarget);
            return -- Skip rest of healing logic this tick
        end
    end

    debug("No valid low-health target found for Holy Judgement; falling back to regular healing.");
end


    -- Get total healing modifier (factor) caused by healing target debuffs
    local HDB = QuickHeal_GetHealModifier(Target);
    debug("Target debuff healing modifier",HDB);
    healneed = healneed/HDB;

    -- Detect Daybreak on target
    local dbMod = QuickHeal_DetectBuff(Target,"Spell_Holy_AuraMastery");
    if dbMod then dbMod = 1.2 else dbMod = 1 end;
    debug("Daybreak healing modifier",dbMod);

    -- Get a list of ranks available of 'Flash of Light' and 'Holy Light'
    local SpellIDsHL = GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local SpellIDsFL = GetSpellIDs(QUICKHEAL_SPELL_FLASH_OF_LIGHT);
    local maxRankHL = table.getn(SpellIDsHL);
    local maxRankFL = table.getn(SpellIDsFL);
    local NoFL = maxRankFL < 1;
    debug(string.format("Found HL up to rank %d, and found FL up to rank %d", maxRankHL, maxRankFL))

    --Get max HealRanks that are allowed to be used
    local downRankFH = QuickHealVariables.DownrankValueFH  -- rank for 1.5 sec heals
    local downRankNH = QuickHealVariables.DownrankValueNH -- rank for < 1.5 sec heals


    -- below changed to not differentiate between in or out if combat. Original code down below
    -- Find suitable SpellID based on the defined criteria
    local k = 1;
    local K = 1;
    if InCombat then
        local k = 0.9; -- In combat means that target is loosing life while casting, so compensate
        local K = 0.8; -- k for fast spells (FL) and K for slow spells (HL)            3 = 4 | 3 < 4 | 3 > 4
    end

    if not forceMaxHPS or not InCombat then
        if Health < RatioFull then
            if maxRankFL >=1                                                                                                                      and SpellIDsFL[1] then SpellID = SpellIDsFL[1]; HealSize = (67+healMod15)*hlMod*dbMod else SpellID = SpellIDsFL[1]; HealSize = (43+healMod25*PF1)*hlMod*dbMod end -- Default to rank 1 of FL
            if healneed     > (102+healMod15)*hlMod*dbMod*k and ManaLeft >= 50  and maxRankFL >=2 and downRankFH >= 2                              and SpellIDsFL[2] then SpellID = SpellIDsFL[2]; HealSize = (102+healMod15)*hlMod*dbMod      end
            if healneed     > (153+healMod15)*hlMod*dbMod*k and ManaLeft >= 70  and maxRankFL >=3 and downRankFH >= 3                              and SpellIDsFL[3] then SpellID = SpellIDsFL[3]; HealSize = (153+healMod15)*hlMod*dbMod      end
            if healneed     > (206+healMod15)*hlMod*dbMod*k and ManaLeft >= 90  and maxRankFL >=4 and downRankFH >= 4                              and SpellIDsFL[4] then SpellID = SpellIDsFL[4]; HealSize = (206+healMod15)*hlMod*dbMod      end
            if healneed     > (278+healMod15)*hlMod*dbMod*k and ManaLeft >= 115 and maxRankFL >=5 and downRankFH >= 5                              and SpellIDsFL[5] then SpellID = SpellIDsFL[5]; HealSize = (278+healMod15)*hlMod*dbMod      end
            if healneed     > (348+healMod15)*hlMod*dbMod*k and ManaLeft >= 140 and maxRankFL >=6 and downRankFH >= 6                              and SpellIDsFL[6] then SpellID = SpellIDsFL[6]; HealSize = (348+healMod15)*hlMod*dbMod      end
	    if healneed     > (428+healMod15)*hlMod*dbMod*k and ManaLeft >= 180 and maxRankFL >=7 and downRankFH >= 7                              and SpellIDsFL[7] then SpellID = SpellIDsFL[7]; HealSize = (428+healMod15)*hlMod*dbMod      end
            
        end
    else
        if ManaLeft >= 35  and maxRankFL >=1 and downRankFH >= 1 and SpellIDsFL[1] then SpellID = SpellIDsFL[1]; HealSize = (67+healMod15)*hlMod*dbMod end
        if ManaLeft >= 50  and maxRankFL >=2 and downRankFH >= 2 and SpellIDsFL[2] then SpellID = SpellIDsFL[2]; HealSize = (102+healMod15)*hlMod*dbMod end
        if ManaLeft >= 70  and maxRankFL >=3 and downRankFH >= 3 and SpellIDsFL[3] then SpellID = SpellIDsFL[3]; HealSize = (153+healMod15)*hlMod*dbMod end
        if ManaLeft >= 90  and maxRankFL >=4 and downRankFH >= 4 and SpellIDsFL[4] then SpellID = SpellIDsFL[4]; HealSize = (206+healMod15)*hlMod*dbMod end
        if ManaLeft >= 115 and maxRankFL >=5 and downRankFH >= 5 and SpellIDsFL[5] then SpellID = SpellIDsFL[5]; HealSize = (278+healMod15)*hlMod*dbMod end
        if ManaLeft >= 140 and maxRankFL >=6 and downRankFH >= 6 and SpellIDsFL[6] then SpellID = SpellIDsFL[6]; HealSize = (348+healMod15)*hlMod*dbMod end
	if ManaLeft >= 180 and maxRankFL >=7 and downRankFH >= 7 and SpellIDsFL[7] then SpellID = SpellIDsFL[7]; HealSize = (428+healMod15)*hlMod*dbMod end
    end
    return SpellID,HealSize*HDB;
end

function QuickHeal_Paladin_FindHealSpellToUseNoTarget(maxhealth, healDeficit, healType, multiplier, forceMaxHPS, forceMaxRank, hdb, incombat)
    local SpellID = nil;
    local HealSize = 0;
    local Overheal = false;

    if multiplier == nil then
        jgpprint(">>> multiplier is NIL <<<")
        --if multiplier > 1.0 then
        --    Overheal = true;
        --end
    elseif multiplier == 1.0 then
        jgpprint(">>> multiplier is " .. multiplier .. " <<<")
    elseif multiplier > 1.0 then
        jgpprint(">>> multiplier is " .. multiplier .. " <<<")
        Overheal = true;
    end

    -- +Healing-PenaltyFactor = (1-((20-LevelLearnt)*0.0375)) for all spells learnt before level 20
    local PF1 = 0.2875;
    local PF6 = 0.475;
    local PF14 = 0.775;

    -- Local aliases to access main module functionality and settings
    local RatioFull = QuickHealVariables["RatioFull"];
    local RatioHealthy = QuickHeal_GetRatioHealthy();
    local UnitHasHealthInfo = QuickHeal_UnitHasHealthInfo;
    local EstimateUnitHealNeed = QuickHeal_EstimateUnitHealNeed;
    local GetSpellIDs = QuickHeal_GetSpellIDs;
    local debug = QuickHeal_debug;

    -- Determine health and heal need of target
    local healneed = healDeficit * multiplier;
    local Health = healDeficit / maxhealth;

    -- if BonusScanner is running, get +Healing bonus
    local Bonus = 0;
    if (BonusScanner) then
        Bonus = tonumber(BonusScanner:GetBonus("HEAL"));
        debug(string.format("Equipment Healing Bonus: %d", Bonus));
    end

    -- Calculate healing bonus
    local healMod15 = (1.5/3.5) * Bonus;
    local healMod25 = (2.5/3.5) * Bonus;
    debug("Final Healing Bonus (1.5,2.5)", healMod15,healMod25);

    local InCombat = UnitAffectingCombat('player') or incombat;

    -- Healing Light Talent (increases healing by 4% per rank)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,6);
    local hlMod = 4*talentRank/100 + 1;
    debug(string.format("Healing Light talentmodification: %f", hlMod))

    local TargetIsHealthy = Health >= RatioHealthy;
    local ManaLeft = UnitMana('player');

    if TargetIsHealthy then
        debug("Target is healthy",Health);
    end

    -- Detect proc of 'Hand of Edward the Odd' mace (next spell is instant cast)
    if QuickHeal_DetectBuff('player',"Spell_Holy_SearingLight") then
        debug("BUFF: Hand of Edward the Odd (out of combat healing forced)");
        InCombat = false;
    end

    -- Detect proc of 'Holy Judgement" (next Holy Light is fast cast)
    if QuickHeal_DetectBuff('player',"ability_paladin_judgementblue") then
        debug("BUFF: Holy Judgement (out of combat healing forced)");
        InCombat = false;
    end

    -- Get total healing modifier (factor) caused by healing target debuffs
    --local HDB = QuickHeal_GetHealModifier(Target);
    --debug("Target debuff healing modifier",HDB);
    healneed = healneed/hdb;


    -- Detect Daybreak on target
    local dbMod = QuickHeal_DetectBuff(Target,"Spell_Holy_AuraMastery");
    if dbMod then dbMod = 1.2 else dbMod = 1 end;
    debug("Daybreak healing modifier",dbMod);

    -- Get a list of ranks available of 'Flash of Light' and 'Holy Light'
    local SpellIDsHL = GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local SpellIDsFL = GetSpellIDs(QUICKHEAL_SPELL_FLASH_OF_LIGHT);
    local maxRankHL = table.getn(SpellIDsHL);
    local maxRankFL = table.getn(SpellIDsFL);
    local maxRankHS = table.getn(SpellIDsHS);
    local NoFL = maxRankFL < 1;
    debug(string.format("Found HL up to rank %d, and found FL up to rank %d", maxRankHL, maxRankFL))

    --Get max HealRanks that are allowed to be used
    local downRankFH = QuickHealVariables.DownrankValueFH  -- rank for 1.5 sec heals
    local downRankNH = QuickHealVariables.DownrankValueNH -- rank for < 1.5 sec heals


    -- below changed to not differentiate between in or out if combat. Original code down below
    -- Find suitable SpellID based on the defined criteria
    local k = 1;
    local K = 1;
    if InCombat then
        local k = 0.9; -- In combat means that target is loosing life while casting, so compensate
        local K = 0.8; -- k for fast spells (FL) and K for slow spells (HL)            3 = 4 | 3 < 4 | 3 > 4
    end

    if not forceMaxHPS or not InCombat then
        if Health < RatioFull then
            if maxRankFL >=1                                                                                                                      and SpellIDsFL[1] then SpellID = SpellIDsFL[1]; HealSize = (67+healMod15)*hlMod*dbMod else SpellID = SpellIDsFL[1]; HealSize = (43+healMod25*PF1)*hlMod*dbMod end -- Default to rank 1 of FL
            if healneed     > (102+healMod15)*hlMod*dbMod*k and ManaLeft >= 50  and maxRankFL >=2 and downRankFH >= 2                              and SpellIDsFL[2] then SpellID = SpellIDsFL[2]; HealSize = (102+healMod15)*hlMod*dbMod      end
            if healneed     > (153+healMod15)*hlMod*dbMod*k and ManaLeft >= 70  and maxRankFL >=3 and downRankFH >= 3                              and SpellIDsFL[3] then SpellID = SpellIDsFL[3]; HealSize = (153+healMod15)*hlMod*dbMod      end
            if healneed     > (206+healMod15)*hlMod*dbMod*k and ManaLeft >= 90  and maxRankFL >=4 and downRankFH >= 4                              and SpellIDsFL[4] then SpellID = SpellIDsFL[4]; HealSize = (206+healMod15)*hlMod*dbMod      end
            if healneed     > (278+healMod15)*hlMod*dbMod*k and ManaLeft >= 115 and maxRankFL >=5 and downRankFH >= 5                              and SpellIDsFL[5] then SpellID = SpellIDsFL[5]; HealSize = (278+healMod15)*hlMod*dbMod      end
            if healneed     > (348+healMod15)*hlMod*dbMod*k and ManaLeft >= 140 and maxRankFL >=6 and downRankFH >= 6                              and SpellIDsFL[6] then SpellID = SpellIDsFL[6]; HealSize = (348+healMod15)*hlMod*dbMod      end
	    if healneed     > (428+healMod15)*hlMod*dbMod*k and ManaLeft >= 180 and maxRankFL >=7 and downRankFH >= 7                              and SpellIDsFL[7] then SpellID = SpellIDsFL[7]; HealSize = (428+healMod15)*hlMod*dbMod      end

        end
    else
        if ManaLeft >= 35  and maxRankFL >=1 and downRankFH >= 1 and SpellIDsFL[1] then SpellID = SpellIDsFL[1]; HealSize = (67+healMod15)*hlMod*dbMod end
        if ManaLeft >= 50  and maxRankFL >=2 and downRankFH >= 2 and SpellIDsFL[2] then SpellID = SpellIDsFL[2]; HealSize = (102+healMod15)*hlMod*dbMod end
        if ManaLeft >= 70  and maxRankFL >=3 and downRankFH >= 3 and SpellIDsFL[3] then SpellID = SpellIDsFL[3]; HealSize = (153+healMod15)*hlMod*dbMod end
        if ManaLeft >= 90  and maxRankFL >=4 and downRankFH >= 4 and SpellIDsFL[4] then SpellID = SpellIDsFL[4]; HealSize = (206+healMod15)*hlMod*dbMod end
        if ManaLeft >= 115 and maxRankFL >=5 and downRankFH >= 5 and SpellIDsFL[5] then SpellID = SpellIDsFL[5]; HealSize = (278+healMod15)*hlMod*dbMod end
        if ManaLeft >= 140 and maxRankFL >=6 and downRankFH >= 6 and SpellIDsFL[6] then SpellID = SpellIDsFL[6]; HealSize = (348+healMod15)*hlMod*dbMod end
	if ManaLeft >= 180 and maxRankFL >=7 and downRankFH >= 7 and SpellIDsFL[7] then SpellID = SpellIDsFL[7]; HealSize = (428+healMod15)*hlMod*dbMod end
    end

    return SpellID,HealSize*hdb;
end

function QuickHeal_Paladin_FindHoTSpellToUse(Target, healType, forceMaxRank)
    local SpellID = nil;
    local HealSize = 0;

    -- +Healing-PenaltyFactor = (1-((20-LevelLearnt)*0.0375)) for all spells learnt before level 20
    local PF1 = 0.2875;
    local PF6 = 0.475;
    local PF14 = 0.775;

    -- Local aliases to access main module functionality and settings
    local RatioFull = QuickHealVariables["RatioFull"];
    local RatioHealthy = QuickHeal_GetRatioHealthy();
    local UnitHasHealthInfo = QuickHeal_UnitHasHealthInfo;
    local EstimateUnitHealNeed = QuickHeal_EstimateUnitHealNeed;
    local GetSpellIDs = QuickHeal_GetSpellIDs;
    local debug = QuickHeal_debug;

    -- Return immediately if no player needs healing
    if not Target then
        return SpellID,HealSize;
    end

    -- Determine health and heal need of target
    local healneed;
    local Health;
    if UnitHasHealthInfo(Target) then
        -- Full info available
        healneed = UnitHealthMax(Target) - UnitHealth(Target)
        Health = UnitHealth(Target) / UnitHealthMax(Target);
    else
        -- Estimate target health
        healneed = EstimateUnitHealNeed(Target,true);
        Health = UnitHealth(Target)/100;
    end

    -- if BonusScanner is running, get +Healing bonus
    local Bonus = 0;
    if (BonusScanner) then
        Bonus = tonumber(BonusScanner:GetBonus("HEAL"));
        debug(string.format("Equipment Healing Bonus: %d", Bonus));
    end

    -- Calculate healing bonus
    local healMod15 = (1.5/3.5) * Bonus;
    local healMod25 = (2.5/3.5) * Bonus;
    debug("Final Healing Bonus (1.5,2.5)", healMod15,healMod25);

    local InCombat = UnitAffectingCombat('player') or UnitAffectingCombat(Target);

    -- Healing Light Talent (increases healing by 4% per rank)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,6);
    local hlMod = 4*talentRank/100 + 1;
    debug(string.format("Healing Light talentmodification: %f", hlMod))

    -- Divine Favor Talent (increases Holy shock effect by 5% per rank, as crit is 50% bonus only)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,13);
    local dfMod = 5*talentRank/100 + 1;
    debug(string.format("Divine Favor talentmodification: %f", dfMod))

    local TargetIsHealthy = Health >= RatioHealthy;
    local ManaLeft = UnitMana('player');

    if TargetIsHealthy then
        debug("Target is healthy",Health);
    end

    -- Detect Daybreak on target
    local dbMod = QuickHeal_DetectBuff(Target,"Spell_Holy_AuraMastery");
    if dbMod then dbMod = 1.2 else dbMod = 1 end;
    debug("Daybreak healing modifier",dbMod);

    -- Get total healing modifier (factor) caused by healing target debuffs
    local HDB = QuickHeal_GetHealModifier(Target);
    debug("Target debuff healing modifier",HDB);
    healneed = healneed/HDB;

    -- Get a list of ranks available of 'Flash of Light' and 'Holy Light' and 'Holy Shock'
    local SpellIDsHL = GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local SpellIDsFL = GetSpellIDs(QUICKHEAL_SPELL_FLASH_OF_LIGHT);
    local SpellIDsHS = GetSpellIDs(QUICKHEAL_SPELL_HOLY_SHOCK);
    local maxRankHL = table.getn(SpellIDsHL);
    local maxRankFL = table.getn(SpellIDsFL);
    local maxRankHS = table.getn(SpellIDsHS);
    local NoFL = maxRankFL < 1;
    debug(string.format("Found HL up to rank %d, and found FL up to rank %d and found HS up to rank %d", maxRankHL, maxRankFL, maxRankHS))

    --Get max HealRanks that are allowed to be used
    local downRankFH = QuickHealVariables.DownrankValueFH  -- rank for 1.5 sec heals
    local downRankNH = QuickHealVariables.DownrankValueNH -- rank for < 1.5 sec heals


    QuickHeal_debug(string.format("healneed: %f  target: %s  healType: %s  forceMaxRank: %s", healneed, Target, healType, tostring(forceMaxRank)));

    if healType == "hot" then
        if not forceMaxHPS then
            SpellID = SpellIDsHS[1]; HealSize = (315+healMod15)*dfMod*dbMod^1.5; -- Default to Holy Shock(Rank 1)
            if healneed >(360+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 335 and maxRankHS >=2 and SpellIDsHS[2] then SpellID = SpellIDsHS[2]; HealSize = (360+healMod15)*dfMod*dbMod^1.5 end
            if healneed >(500+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 410 and maxRankHS >=3 and SpellIDsHS[3] then SpellID = SpellIDsHS[3]; HealSize = (500+healMod15)*dfMod*dbMod^1.5 end
	    if healneed >(655+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 485 and maxRankHS >=4 and SpellIDsHS[4] then SpellID = SpellIDsHS[4]; HealSize = (655+healMod15)*dfMod*dbMod^1.5 end
        else
            SpellID = SpellIDsHS[4]; HealSize = (655+healMod15)*dfMod*dbMod^1.5
            if maxRankHS >=2 and SpellIDsHS[2] then SpellID = SpellIDsHS[2]; HealSize = (360+healMod15)*dfMod*dbMod^1.5 end
            if maxRankHS >=3 and SpellIDsHS[3] then SpellID = SpellIDsHS[3]; HealSize = (500+healMod15)*dfMod*dbMod^1.5 end
	    if maxRankHS >=4 and SpellIDsHS[4] then SpellID = SpellIDsHS[4]; HealSize = (655+healMod15)*dfMod*dbMod^1.5 end
        end
    end

    return SpellID,HealSize*HDB;
end

function QuickHeal_Paladin_FindHoTSpellToUseNoTarget(maxhealth, healDeficit, healType, multiplier, forceMaxHPS, forceMaxRank, hdb)
    local SpellID = nil;
    local HealSize = 0;

    -- +Healing-PenaltyFactor = (1-((20-LevelLearnt)*0.0375)) for all spells learnt before level 20
    local PF1 = 0.2875;
    local PF6 = 0.475;
    local PF14 = 0.775;

    -- Local aliases to access main module functionality and settings
    local RatioFull = QuickHealVariables["RatioFull"];
    local RatioHealthy = QuickHeal_GetRatioHealthy();
    local UnitHasHealthInfo = QuickHeal_UnitHasHealthInfo;
    local EstimateUnitHealNeed = QuickHeal_EstimateUnitHealNeed;
    local GetSpellIDs = QuickHeal_GetSpellIDs;
    local debug = QuickHeal_debug;

    -- Return immediately if no player needs healing
    if not Target then
        return SpellID,HealSize;
    end

    -- Determine health and heal need of target
    local healneed;
    local Health;
    if UnitHasHealthInfo(Target) then
        -- Full info available
        healneed = UnitHealthMax(Target) - UnitHealth(Target)
        Health = UnitHealth(Target) / UnitHealthMax(Target);
    else
        -- Estimate target health
        healneed = EstimateUnitHealNeed(Target,true);
        Health = UnitHealth(Target)/100;
    end

    -- if BonusScanner is running, get +Healing bonus
    local Bonus = 0;
    if (BonusScanner) then
        Bonus = tonumber(BonusScanner:GetBonus("HEAL"));
        debug(string.format("Equipment Healing Bonus: %d", Bonus));
    end

    -- Calculate healing bonus
    local healMod15 = (1.5/3.5) * Bonus;
    local healMod25 = (2.5/3.5) * Bonus;
    debug("Final Healing Bonus (1.5,2.5)", healMod15,healMod25);

    local InCombat = UnitAffectingCombat('player') or UnitAffectingCombat(Target);

    -- Healing Light Talent (increases healing by 4% per rank)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,6);
    local hlMod = 4*talentRank/100 + 1;
    debug(string.format("Healing Light talentmodification: %f", hlMod))

    -- Divine Favor Talent (increases Holy shock effect by 5% per rank, as crit is 50% bonus only)
    local _,_,_,_,talentRank,_ = GetTalentInfo(1,13);
    local dfMod = 5*talentRank/100 + 1;
    debug(string.format("Divine Favor talentmodification: %f", dfMod))

    local TargetIsHealthy = Health >= RatioHealthy;
    local ManaLeft = UnitMana('player');

    if TargetIsHealthy then
        debug("Target is healthy",Health);
    end

    -- Detect Daybreak on target
    local dbMod = QuickHeal_DetectBuff(Target,"Spell_Holy_AuraMastery");
    if dbMod then dbMod = 1.2 else dbMod = 1 end;
    debug("Daybreak healing modifier",dbMod);

    -- Get total healing modifier (factor) caused by healing target debuffs
    local HDB = QuickHeal_GetHealModifier(Target);
    debug("Target debuff healing modifier",HDB);
    healneed = healneed/HDB;

    -- Get a list of ranks available of 'Flash of Light' and 'Holy Light' and 'Holy Shock'
    local SpellIDsHL = GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT);
    local SpellIDsFL = GetSpellIDs(QUICKHEAL_SPELL_FLASH_OF_LIGHT);
    local SpellIDsHS = GetSpellIDs(QUICKHEAL_SPELL_HOLY_SHOCK);
    local maxRankHL = table.getn(SpellIDsHL);
    local maxRankFL = table.getn(SpellIDsFL);
    local maxRankHS = table.getn(SpellIDsHS);
    local NoFL = maxRankFL < 1;
    debug(string.format("Found HL up to rank %d, and found FL up to rank %d and found HS up to rank %d", maxRankHL, maxRankFL, maxRankHS))

    --Get max HealRanks that are allowed to be used
    local downRankFH = QuickHealVariables.DownrankValueFH  -- rank for 1.5 sec heals
    local downRankNH = QuickHealVariables.DownrankValueNH -- rank for < 1.5 sec heals


    SpellID = SpellIDsHS[1]; HealSize = (315+healMod15)*dfMod*dbMod^1.5; -- Default to Holy Shock(Rank 1)
    if healneed >(360+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 335 and maxRankHS >=2 and SpellIDsHS[2] then SpellID = SpellIDsHS[2]; HealSize = (360+healMod15)*dfMod*dbMod^1.5 end
    if healneed >(500+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 410 and maxRankHS >=3 and SpellIDsHS[3] then SpellID = SpellIDsHS[3]; HealSize = (500+healMod15)*dfMod*dbMod^1.5 end
    if healneed >(655+healMod15)*dfMod*dbMod^1.5 and ManaLeft >= 485 and maxRankHS >=4 and SpellIDsHS[4] then SpellID = SpellIDsHS[4]; HealSize = (655+healMod15)*dfMod*dbMod^1.5 end

    return SpellID,HealSize*hdb;
end



function QuickHeal_Command_Paladin(msg)

    local _, _, arg1, arg2, arg3 = string.find(msg, "%s?(%w+)%s?(%w+)%s?(%w+)")

    -- match 3 arguments
    if arg1 ~= nil and arg2 ~= nil and arg3 ~= nil then
        if arg1 == "player" or arg1 == "target" or arg1 == "targettarget" or arg1 == "party" or arg1 == "subgroup" or arg1 == "mt" or arg1 == "nonmt" then
            if arg2 == "heal" and arg3 == "max" then
                --writeLine(QuickHealData.name .. " qh " .. arg1 .. " HEAL(maxHPS)", 0, 1, 0);
                QuickHeal(arg1, nil, nil, true);
                return;
            end
            if arg2 == "hot" and arg3 == "fh" then
                --writeLine(QuickHealData.name .. " qh " .. arg1 .. " HOT(max rank & no hp check)", 0, 1, 0);
                QuickHOT(arg1, nil, nil, true, true);
                return;
            end
            if arg2 == "hot" and arg3 == "max" then
                --writeLine(QuickHealData.name .. " qh " .. arg1 .. " HOT(max rank)", 0, 1, 0);
                QuickHOT(arg1, nil, nil, true, false);
                return;
            end
        end
    end

    -- match 2 arguments
    local _, _, arg4, arg5= string.find(msg, "%s?(%w+)%s?(%w+)")

    if arg4 ~= nil and arg5 ~= nil then
        if arg4 == "debug" then
            if arg5 == "on" then
                QHV.DebugMode = true;
                --writeLine(QuickHealData.name .. " debug mode enabled", 0, 0, 1);
                return;
            elseif arg5 == "off" then
                QHV.DebugMode = false;
                --writeLine(QuickHealData.name .. " debug mode disabled", 0, 0, 1);
                return;
            end
        end
        if arg4 == "heal" and arg5 == "max" then
            --writeLine(QuickHealData.name .. " HEAL (max)", 0, 1, 0);
            QuickHeal(nil, nil, nil, true);
            return;
        end
        if arg4 == "hot" and arg5 == "max" then
            --writeLine(QuickHealData.name .. " HOT (max)", 0, 1, 0);
            QuickHOT(nil, nil, nil, true, false);
            return;
        end
        if arg4 == "hot" and arg5 == "fh" then
            --writeLine(QuickHealData.name .. " FH (max rank & no hp check)", 0, 1, 0);
            QuickHOT(nil, nil, nil, true, true);
            return;
        end
        if arg4 == "player" or arg4 == "target" or arg4 == "targettarget" or arg4 == "party" or arg4 == "subgroup" or arg4 == "mt" or arg4 == "nonmt" then
            if arg5 == "hot" then
                --writeLine(QuickHealData.name .. " qh " .. arg1 .. " HOT", 0, 1, 0);
                QuickHOT(arg1, nil, nil, false, false);
                return;
            end
            if arg5 == "heal" then
                --writeLine(QuickHealData.name .. " qh " .. arg1 .. " HEAL", 0, 1, 0);
                QuickHeal(arg1, nil, nil, false);
                return;
            end
        end
    end

    -- match 1 argument
    local cmd = string.lower(msg)

    if cmd == "cfg" then
        QuickHeal_ToggleConfigurationPanel();
        return;
    end

    if cmd == "toggle" then
        QuickHeal_Toggle_Healthy_Threshold();
        return;
    end

    if cmd == "downrank" or cmd == "dr" then
        ToggleDownrankWindow()
        return;
    end

    if cmd == "tanklist" or cmd == "tl" then
        QH_ShowHideMTListUI();
        return;
    end

    if cmd == "reset" then
        QuickHeal_SetDefaultParameters();
        writeLine(QuickHealData.name .. " reset to default configuration", 0, 0, 1);
        QuickHeal_ToggleConfigurationPanel();
        QuickHeal_ToggleConfigurationPanel();
        return;
    end

    if cmd == "heal" then
        --writeLine(QuickHealData.name .. " HEAL", 0, 1, 0);
        QuickHeal();
        return;
    end

    if cmd == "hot" then
        --writeLine(QuickHealData.name .. " HOT", 0, 1, 0);
        QuickHOT();
        return;
    end

    if cmd == "" then
        --writeLine(QuickHealData.name .. " qh", 0, 1, 0);
        QuickHeal(nil);
        return;
    elseif cmd == "player" or cmd == "target" or cmd == "targettarget" or cmd == "party" or cmd == "subgroup" or cmd == "mt" or cmd == "nonmt" then
        --writeLine(QuickHealData.name .. " qh " .. cmd, 0, 1, 0);
        QuickHeal(cmd);
        return;
    end

    -- Print usage information if arguments do not match
    --writeLine(QuickHealData.name .. " Usage:");
    writeLine("== QUICKHEAL USAGE : PALADIN ==");
    writeLine("/qh cfg - Opens up the configuration panel.");
    writeLine("/qh toggle - Switches between High HPS and Normal HPS.  Heals (Healthy Threshold 0% or 100%).");
    writeLine("/qh downrank | dr - Opens the slider to limit QuickHeal to constrain healing to lower ranks.");
    writeLine("/qh tanklist | tl - Toggles display of the main tank list UI.");
    writeLine("/qh [mask] [type] [mod] - Heals the party/raid member that most needs it with the best suited healing spell.");
    writeLine(" [mask] constrains healing pool to:");
    writeLine("  [player] yourself");
    writeLine("  [target] your target");
    writeLine("  [targettarget] your target's target");
    writeLine("  [party] your party");
    writeLine("  [mt] main tanks (defined in the configuration panel)");
    writeLine("  [nonmt] everyone but the main tanks");
    writeLine("  [subgroup] raid subgroups (defined in the configuration panel)");

    writeLine(" [mod] (optional) modifies [heal] options:");
    writeLine("  [max] applies maximum rank HPS [heal] to subgroup members that have <100% health");
    writeLine("  [hot] modifier options:");
    writeLine("   [max] applies maximum HS rank to subgroup members that have <100% health");
    writeLine("   [fh] applies maximum HS rank to subgroup members regardless of health status");

    writeLine("/qh reset - Reset configuration to default parameters for all classes.");
end

