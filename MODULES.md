# PrimusUI: Module Catalog & PUI Standardization Roadmap

> **Target Platform:** Vanilla WoW 1.12.1 (Interface 11200 / Lua 5.0.2)  
> **Architecture Standard:** Strict `PUI<Name>` Module Naming Convention  
> **Aliasing Policy:** ZERO aliasing across the entire codebase. Direct, explicit naming only.

---

## 🎯 Standardization Goal

To achieve total architectural consistency, all modular components in PrimusUI are standardized to follow the **`PUI<FeatureName>`** nomenclature across:
1. **Directory & File Names:** `Modules/<Category>/PUI<Name>/PUI<Name>.lua`
2. **Local Module Tables:** `local PUI<Name> = {}`
3. **Module Registrations:** `Primus:RegisterModule("PUI<Name>", PUI<Name>, "<Category>")`
4. **TOC Entries:** `Modules\<Category>\PUI<Name>\PUI<Name>.lua`
5. **Database Namespaces:** `DB:RegisterNamespace("PUI<Name>", ...)`
6. **Mover Keys & Global Frames:** Direct usage without aliases.

---

## 📊 Complete Module Inventory & Refactoring Matrix

### 1. Action Bars & HUD (3 Modules)

| Current Name | Target Standard Name | File Path / Sub-Files | Status |
| :--- | :--- | :--- | :--- |
| `PUIHotbars` | `PUIHotbars` | `Modules/Bars/PUIHotbars/`<br>• `PUIHotbars.lua` (Master Orchestrator & Layout)<br>• `PUIButtons.lua` (Skinning, Pure Scaling & Range Ticker)<br>• `PUIXPBar.lua` (Integrated XP & Rep Bar)<br>• `PUIMicroBags.lua` (Micro Menu & Bag Bar) | ✅ **DONE** |
| `PUIHud` | `PUIHud` | `Modules/HUD/PUIHud/`<br>• `PUIHud.lua` (Master Coordinator)<br>• `PUIWings.lua` (Vertical Vitals Wings)<br>• `PUIMiniBars.lua` (Bar 10 Mini-Bars)<br>• `PUIActiveAssist.lua` (Threat Peel & MT Assist)<br>• `PUITimers.lua` (Dual-Swing & GCD Rails)<br>• `PUITriage.lua` (Triage Array & Flash) | ✅ **DONE** |
| `PUIAuras` | `PUIAuras` | `Modules/HUD/PUIAuras/PUIAuras.lua` | ✅ **DONE** |

---

### 2. Unit Frame Suite (2 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUIUnitBase` | `PUIUnitBase` | `Modules/Units/PUIUnitBase/PUIUnitBase.lua` | ✅ **DONE** |
| `PUIUnitFrames` | `PUIUnitFrames` | `Modules/Units/PUIUnitFrames/PUIUnitFrames.lua` | ✅ **DONE** |

---

### 3. Combat Engines (8 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUICastBar` | `PUICastBar` | `Modules/Combat/PUICastBar/PUICastBar.lua` | ✅ **DONE** |
| `PUICooldowns` | `PUICooldowns` | `Modules/Combat/PUICooldowns/PUICooldowns.lua` | ✅ **DONE** |
| `PUICombatLog` | `PUICombatLog` | `Modules/Combat/PUICombatLog/PUICombatLog.lua` | ✅ **DONE** |
| `PUICombatAuras` | `PUICombatAuras` | `Modules/Combat/PUICombatAuras/PUICombatAuras.lua` | ✅ **DONE** |
| `PUIThreat` | `PUIThreat` | `Modules/Combat/PUIThreat/PUIThreat.lua` | ✅ **DONE** |
| `PUIHealComm` | `PUIHealComm` | `Modules/Combat/PUIHealComm/PUIHealComm.lua` | ✅ **DONE** |
| `PUITactical` | `PUITactical` | `Modules/Combat/PUITactical/PUITactical.lua` | ✅ **DONE** |
| `PUIRange` | `PUIRange` | `Modules/Combat/PUIRange/PUIRange.lua` | ✅ **DONE** |

---

### 4. Utility & Meta-UI Suite (9 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUIMover` | `PUIMover` | `Modules/Utility/PUIMover/PUIMover.lua` | ✅ **DONE** |
| `PUIDock` | `PUIDock` | `Modules/Utility/PUIDock/PUIDock.lua` | ✅ **DONE** |
| `PUIMerchant` | `PUIMerchant` | `Modules/Utility/PUIMerchant/PUIMerchant.lua` | ✅ **DONE** |
| `PUIFastLoot` | `PUIFastLoot` | `Modules/Utility/PUIFastLoot/PUIFastLoot.lua` | ✅ **DONE** |
| `PUIAutoMechanics` | `PUIAutoMechanics` | `Modules/Utility/PUIAutoMechanics/PUIAutoMechanics.lua` | ✅ **DONE** |
| `PUIItemCompare` | `PUIItemCompare` | `Modules/Utility/PUIItemCompare/PUIItemCompare.lua` | ✅ **DONE** |
| `PUIMinimapOrbit` | `PUIMinimapOrbit` | `Modules/Utility/PUIMinimapOrbit/PUIMinimapOrbit.lua` | ✅ **DONE** |
| `PUIMailbox` | `PUIMailbox` | `Modules/Utility/PUIMailbox/PUIMailbox.lua` | ✅ **DONE** |
| `PUIInspect` | `PUIInspect` | `Modules/Utility/PUIInspect/PUIInspect.lua` | ✅ **DONE** |

---

### 5. Player & Character Suite (11 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUISpellbook` | `PUISpellbook` | `Modules/Player/PUISpellbook/PUISpellbook.lua` | ✅ **DONE** |
| `PUIBags` | `PUIBags` | `Modules/Player/PUIBags/PUIBags.lua` | ✅ **DONE** |
| `PUIBank` | `PUIBank` | `Modules/Player/PUIBank/PUIBank.lua` | ✅ **DONE** |
| `PUICharacterSheet` | `PUICharacterSheet` | `Modules/Player/PUICharacterSheet/PUICharacterSheet.lua` | ✅ **DONE** |
| `PUIItemStats` | `PUIItemStats` | `Modules/Player/PUIItemStats/PUIItemStats.lua` | ✅ **DONE** |
| `PUIVendor` | `PUIVendor` | `Modules/Player/PUIVendor/PUIVendor.lua` | ✅ **DONE** |
| `PUISellValue` | `PUISellValue` | `Modules/Player/PUISellValue/PUISellValue.lua` | 📋 **PLANNED** |
| `PUIReagents` | `PUIReagents` | `Modules/Player/PUIReagents/PUIReagents.lua` | ✅ **DONE** |
| `PUITalents` | `PUITalents` | `Modules/Player/PUITalents/PUITalents.lua` | ✅ **DONE** |
| `PUIQuestWatch` | `PUIQuestWatch` | `Modules/Player/PUIQuestWatch/PUIQuestWatch.lua` | ✅ **DONE** |
| `PUIQuestHelper` | `PUIQuestHelper` | `Modules/Player/PUIQuestHelper/PUIQuestHelper.lua` | 📋 **PLANNED** |

---

### 6. Social & Communication Suite (3 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUITalk` | `PUITalk` | `Modules/Social/PUITalk/PUITalk.lua` | ✅ **DONE** |
| `PUIMasterLoot` | `PUIMasterLoot` | `Modules/Social/PUIMasterLoot/PUIMasterLoot.lua` | ✅ **DONE** |
| `PUIRoleplay` | `PUIRoleplay` | `Modules/Social/PUIRoleplay/`<br>• `PUIConstants.lua`<br>• `PUIComms.lua`<br>• `PUIRPSheet.lua`<br>• `PUIGlance.lua`<br>• `PUITooltip.lua`<br>• `PUIDirectory.lua`<br>• `PUIEmotes.lua`<br>• `PUIRoleplay.lua` | ✅ **DONE** |

---

### 7. Gathering & Professions (2 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUIGathering` | `PUIGathering` | `Modules/Gathering/PUIGathering/PUIGathering.lua` | ✅ **DONE** |
| `PUIProfessions` | `PUIProfessions` | `Modules/Professions/PUIProfessions/PUIProfessions.lua` | ✅ **DONE** |

---

### 8. Class Nuance Suite (9 Modules)

| Current Name | Target Standard Name | File Path | Status |
| :--- | :--- | :--- | :--- |
| `PUIDruid` | `PUIDruid` | `Modules/Classes/PUIDruid/PUIDruid.lua` | ✅ **DONE** |
| `PUIHunter` | `PUIHunter` | `Modules/Classes/PUIHunter/PUIHunter.lua` | ✅ **DONE** |
| `PUIMage` | `PUIMage` | `Modules/Classes/PUIMage/PUIMage.lua` | ✅ **DONE** |
| `PUIPaladin` | `PUIPaladin` | `Modules/Classes/PUIPaladin/PUIPaladin.lua` | ✅ **DONE** |
| `PUIPriest` | `PUIPriest` | `Modules/Classes/PUIPriest/PUIPriest.lua` | ✅ **DONE** |
| `PUIRogue` | `PUIRogue` | `Modules/Classes/PUIRogue/PUIRogue.lua` | ✅ **DONE** |
| `PUIShaman` | `PUIShaman` | `Modules/Classes/PUIShaman/PUIShaman.lua` | ✅ **DONE** |
| `PUIWarlock` | `PUIWarlock` | `Modules/Classes/PUIWarlock/PUIWarlock.lua` | ✅ **DONE** |
| `PUIWarrior` | `PUIWarrior` | `Modules/Classes/PUIWarrior/PUIWarrior.lua` | ✅ **DONE** |

---

## 🏛️ Reference: Core Foundation (Tier 1 Controllers)

Core Foundation subsystems remain under `Core/` and are attached to the `Primus` controller table without the `PUI` prefix:

- [`Core/Bootstrap/Bootstrap.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Bootstrap/Bootstrap.lua) (`Primus`)
- [`Core/State/State.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/State/State.lua) (`Primus.Zen` / `Primus.State`)
- [`Core/Config/Options.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Config/Options.lua) (`Primus.Options`)
- [`Core/DB/DB.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/DB/DB.lua) (`Primus.DB`)
- [`Core/Events/Events.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Events/Events.lua) (`Primus.Events`)
- [`Core/Time/Time.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Time/Time.lua) (`Primus.Time`)
- [`Core/Memory/Memory.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Memory/Memory.lua) (`Primus.Memory`)
- [`Core/Widgets/Widgets.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Widgets/Widgets.lua) (`Primus.Widgets`)
- [`Core/Media/Media.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Media/Media.lua) (`Primus.Media`)
- [`Core/Keybind/Keybind.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Keybind/Keybind.lua) (`Primus.Keybind`)
- [`Core/Console/Console.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Console/Console.lua) (`Primus.Console`)
- [`Core/Anim/Anim.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Anim/Anim.lua) (`Primus.Anim`)
- [`Core/Comm/Comm.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Comm/Comm.lua) (`Primus.Comm`)
- [`Core/Debug/Debug.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Debug/Debug.lua) (`Primus.Debug`)
- [`Core/Utils/Utils.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Utils/Utils.lua) (`Primus.Utils`)
