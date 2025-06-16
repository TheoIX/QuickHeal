82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
126
127
128
129
130
131
132
133
134
135
136
137
138
139
140
141
142
143
144
145
146
147
148
149
150
151
152
153
154
155
156
157
158
159
160
161
162
163
-- QuickHeal_Theo.lua (Turtle WoW-Compatible + Initialization Fix)
    local bestUnit, lowestHP = nil, 1
    local i, holyStrikeIndex = 1, nil
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        if name == "Holy Strike" then holyStrikeIndex = i break end
        i = i + 1
    end
    if not holyStrikeIndex then return end
    local start, duration = GetSpellCooldown(holyStrikeIndex, BOOKTYPE_SPELL)
    if duration > 0 then return end
    for _, unit in ipairs(slots) do
        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDeadOrGhost(unit)
            and IsSpellInRange("Holy Strike", unit) == 1 and CheckInteractDistance(unit, 3)
            and isThreatToGroup(unit) then
            local originalTarget = UnitExists("target") and UnitName("target")
            TargetUnit(unit)
            CastSpell(holyStrikeIndex, BOOKTYPE_SPELL)
            if originalTarget then TargetByName(originalTarget, true) end
            return
        end
    end
end

local function Theo_CastHolyShockIfReady(target)
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        if name == "Holy Shock" then
            local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
            if duration == 0 then
                CastSpell(i, BOOKTYPE_SPELL)
                SpellTargetUnit(target)
            end
            break
        end
        i = i + 1
    end
end

function QuickTheo_Command()
    Theo_CastPerceptionIfReady()
    Theo_UseWarmthOfForgiveness()
    Theo_CastDivineShieldIfLow()

    local target, hpPercent = Theo_GetLowestHPTarget()
    if not target then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0TheoHeal:|r No valid heal target found.")
        return
    end

    Theo_CastHolyShockIfReady(target)

    local hasJudgement = QuickHeal_DetectBuff("player", "ability_paladin_judgementblue")
    if hasJudgement and hpPercent < 0.5 then
        local ids = QuickHeal_GetSpellIDs(QUICKHEAL_SPELL_HOLY_LIGHT)
        if ids and ids[9] then
            CastSpell(ids[9], BOOKTYPE_SPELL)
            SpellTargetUnit(target)
            return
        end
    end

    local spellID, _ = QuickHeal_Paladin_FindSpellToUse(target)
    if spellID then
        CastSpell(spellID, BOOKTYPE_SPELL)
        SpellTargetUnit(target)
    end

    Theo_CastHolyStrike()
end

-- Ensure safe registration after login
local function InitQuickTheo()
    SLASH_QUICKTHEO1 = "/qhtheo"
    SlashCmdList["QUICKTHEO"] = QuickTheo_Command
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", InitQuickTheo)
