# QuickTheoDPS — Retribution Paladin DPS Macro (Turtle WoW 1.12)

**QuickTheoDPS** is an intelligent, automated DPS script designed for Retribution Paladins in Turtle WoW. It streamlines combat by prioritizing abilities, managing seals, and ensuring uptime of important buffs like **Holy Might** from *Holy Strike*.

## 🔧 Features

- 🧠 **Smart Priority System:** Chooses which spell to cast based on cooldowns, target status, range, mana, and buff timings.
- 🔁 **Seal Management:**
  - Automatically casts your preferred Seal (**Seal of Command** or **Righteousness**).
  - If enabled, swaps to **Seal of Wisdom** under 20% mana.
- ⚔️ **Strike Management:**
  - Maintains uptime on **Holy Might** by favoring *Holy Strike* when needed.
  - Switches to *Crusader Strike* only when Holy Might is safely active.
- 💥 **Burst & Utility:**
  - Uses **Judgement** and **Exorcism** when appropriate.
  - Casts **Hammer of Wrath** intelligently (target must have >5000 HP to avoid waste).
  - Casts **Repentance** on bosses only.
  - Uses **Consecration** when mana > 75% and toggle is enabled.
  - Automatically casts **Perception** (Human racial) if ready.
- 🎯 **Auto-Targeting:** Selects nearest enemy if none are targeted or current target is invalid (though note `UnitXP` line may be non-functional).
- 🛠️ **Cooldown & Buff Tracking:** Uses internal timing to track **Holy Might** uptime instead of relying on fragile tooltip parsing.

## 📜 Slash Commands

| Command         | Description                                                      |
|----------------|------------------------------------------------------------------|
| `/qhtheodps`    | Main DPS macro. Fires abilities based on the smart logic tree.   |
| `/qhwisdom`     | Toggles Wisdom Fallback — casts *Seal of Wisdom* under 20% mana. |
| `/qhconsecration` | Toggles Consecration usage when mana is high.                   |
| `/qhspellret`   | Toggles between *Seal of Command* and *Seal of Righteousness*.   |

## 🧠 Priority Logic Order

1. **Perception** (if ready)
2. **Target selection** (if needed)
3. **Holy/Crusader Strike** — prioritizes **Holy Strike** if:
   - Holy Might is missing, or
   - Holy Might is about to expire (within 2s of cooldown end)
4. **Seal application**
5. **Judgement**
6. **Exorcism** (vs. Undead)
7. **Hammer of Wrath** (if target <20% HP and >5000 HP)
8. **Repentance** (boss only)
9. **Consecration** (if toggled on and mana >75%)
10. **Auto Attack** fallback
