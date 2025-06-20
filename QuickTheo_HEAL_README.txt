# QuickTheo Healing & Hybrid Combat Automation (Turtle WoW)

This Lua script is an advanced **Paladin healing and hybrid combat automation macro** designed for Turtle WoW. It blends **smart healing**, **emergency defense**, **mouse-over logic**, **Holy Shock usage**, and **strike prioritization** into one streamlined macro.

---

## 🔧 Features

- 🧠 **Smart Healing Targeting:**
  - Heals the lowest % HP friendly unit within range.
  - Avoids re-healing the most recently healed target unless necessary.
- 🖱️ **Mouseover Casting:**
  - Optional toggle for casting Flash of Light on your mouseover target.
- ⚔️ **Strike System:**
  - Chooses between *Holy Strike* and *Crusader Strike* based on:
    - Nearby allies' need for healing,
    - Holy Shock cooldown status.
- 💥 **Holy Shock Priority:**
  - Casts if `Daybreak` (Surge of Light) buff is active,
  - Or if the target is below 80% HP,
  - Or if Holy Shock spam mode is toggled on.
- 📿 **Judgement Logic:**
  - Automatically applies *Seal of Wisdom* and *Judgement* when no healing needs are pressing.
- 🧯 **Emergency Response:**
  - Automatically casts *Divine Shield* if player HP drops below 20%.
- 🎁 **Trinket Usage:**
  - Uses mana trinket (Warmth of Forgiveness) if below 85% mana.
  - Uses Eye of the Dead if 5+ raid members are below 80% HP.
- 👁️ **Racial Ability Support:**
  - Uses *Perception* if the racial toggle is enabled.

---

## 📜 Slash Commands

| Command              | Description |
|----------------------|-------------|
| `/qhtheo` or `/qt`   | Main macro — executes healing/DPS logic. |
| `/qhmouse`           | Toggles mouseover healing mode. |
| `/qhemergency`       | Toggles emergency logic (e.g. Divine Shield below 20%). |
| `/qhshockspam`       | Enables Holy Shock spam mode. |
| `/qhtoggles`         | Toggles both racial and trinket logic at once. |

---

## 🧠 Logic Flow Summary

1. **Mouseover heal** (if enabled and mouseover valid).
2. **Racial** (`Perception`) if enabled.
3. **Trinkets** (based on mana or injured allies).
4. **Emergency Shield** (<20% HP).
5. **Holy/Crusader Strike** if valid target and shared cooldown is ready.
6. **Seal + Judgement** application if needed.
7. **Holy Light (Rank 9)** if target under 50% HP and Judgement active.
8. **Holy Shock** logic (condition-based).
9. **Fallback to QuickHeal healing spell** for the lowest HP target.

---

## 💡 Customization Toggles

- `QuickTheo_EnableMouseover`: Enable/disable mouseover healing.
- `QuickTheo_EnableEmergency`: Enable emergency Divine Shield under 20% HP.
- `QuickTheo_EnableHolyShockSpam`: Force Holy Shock usage when ready.
- `QuickTheo_EnableTrinkets`: Use trinkets based on health/mana.
- `QuickTheo_EnableRacial`: Use *Perception* if ready.

---

This macro is ideal for Holy Paladins in PvE or hybrid roles who want semi-automated healing with strong control over burst DPS and survivability.
