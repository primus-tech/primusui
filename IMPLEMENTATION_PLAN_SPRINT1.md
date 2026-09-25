# Implementation Plan - Sprint 1: Distributed Options Flare Architecture, PUIHotbars Engine & Click-Casting

## Overview
This plan details the full implementation of **Sprint 1** from [`TODO.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/TODO.md), [`TRUTH.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/TRUTH.md), and [`DESIRED_FEATURES.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/DESIRED_FEATURES.md).

*(Note: The `PUIMover` utility module refactoring has already been fully completed across the codebase with zero aliasing).*

Sprint 1 delivers the following foundational architectural upgrades alongside critical technical debt fixes:
1. **Distributed Module Options & "Flare" Handshake Architecture (`Core/Config/Options.lua`):** Decentralize monolithic options into self-registering module "flares" with zero upfront memory allocation, dynamic LoD canvas rendering, and a left-right (25% / 75%) Master Command Center GUI with real-time enable/disable toggles and full Profile IO management.
2. **Strict Module Lifecycle Engine (`OnEnable` & `OnDisable`):** Standardize module runtime state transitions (`Primus:EnableModule`, `Primus:DisableModule`) with automatic event/timer unhooking (`Events:UnregisterAll`, `Time:CancelAll`) and instant UI element show/hide.
3. **`PUIHotbars` Engine Virtualization, ID Reuse & Sub-File Deconstruction (`Modules/Bars/PUIHotbars/`):**
   - **Sub-File Breakdown:** Decompose `PUIHotbars.lua` into 4 focused sub-files (`PUIHotbars.lua`, `Buttons.lua`, `XPBar.lua`, `MicroBags.lua`).
   - **Pure Scaling (Zero Texture Cropping):** Remove all `SetTexCoord(0.07, 0.93, 0.07, 0.93)` zoom clipping in favor of native texture coordinates and frame geometry scaling.
   - **120-Slot ID Reuse Pool & Paging Tunnels:** Dynamic condition resolver routing visual buttons to backend slots (`1..120`) across stances (Warrior, Druid, Rogue), stealth, modifiers (Shift/Ctrl/Alt), and pages without multi-frame stacking/flicker.
   - **Dynamic Matrix Sliders:** Independent **Rows** (1–12) and **Columns** (1–12) sliders for each bar (supporting `12x1`, `1x12`, `6x2`, `2x6`, `3x4`, `4x3`).
4. **`PUIHud` Cockpit Mini-Bars (Bar 10 Dedicated Allocation):**
   - Allocate **Bar 10 (`Slots 109..120`)** with 4 dedicated buttons on the Left Wing (`109..112`) and 4 buttons on the Right Wing (`113..116`) featuring native drag-and-drop from Spellbook/Bags and zero stance collisions.
5. **1.12.1 Unprotected Click-Casting & Automated Cleansing:**
   - **`PUIUnitFrames` Click-Casting:** Built-in HealBot/Clique direct execution (`Primus.Utils.CastOnUnit`) on player/target/party/raid frames with target preservation (`TargetLastTarget()`).
   - **`PUITactical` Decursive Engine:** Automated group debuff scanner (`Primus.Utils.CleanseNextMember`) for instant 1-click cleansing.
6. **Immediate Critical Fixes:** Add missing `Modules\Combat\Range\Range.lua` to `PrimusUI.toc` and eliminate orphaned `Modules\Utility\AuctionHouse\AuctionHouse.lua`.

---

## User Review Required

> [!IMPORTANT]
> **Zero Upfront Widget Allocation & LoD Caching:**
> Under the Flare Architecture, modules register only a metadata descriptor on boot (`Primus.Options:RegisterModuleOptions`). The right-hand options canvas executes the module's `builderFunc(parentCanvas)` *only when selected by the user*, caching the constructed frame for subsequent visits. This eliminates garbage churn and upfront frame allocation.

> [!NOTE]
> **120-Slot Allocation Strategy:**
> - `Bars 1–6 (Slots 1–72)`: On-screen visual hotbars (Bars 1–5 + secondary).
> - `Bars 7–9 (Slots 73–108)`: Stance & Form Paging Tunnels (Stealth, Battle, Defensive, Berserker, Cat, Bear, Prowl).
> - `Bar 10 (Slots 109–120)`: Dedicated HUD Cockpit Mini-Bars (4 Left + 4 Right + 4 ActiveAssist) with native drag-and-drop and zero stance collisions.

---

## Proposed Changes

### Component 1: Core Foundation & Lifecycle Runtime

#### [MODIFY] [Bootstrap.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Bootstrap/Bootstrap.lua)
- Implement `Primus:EnableModule(moduleName)`:
  - Verifies module exists and is currently disabled.
  - Calls `moduleObj:OnEnable()` safely via `Debug:SafeCall`.
  - Sets `moduleObj.enabled = true`.
  - Updates DB enabled state.
  - Fires `Events:Fire("MODULE_ENABLED", moduleName)`.
- Implement `Primus:DisableModule(moduleName)`:
  - Verifies module exists and is currently enabled.
  - Calls `moduleObj:OnDisable()` safely via `Debug:SafeCall`.
  - Sets `moduleObj.enabled = false`.
  - Invokes `Events:UnregisterAll(moduleObj)` to unhook all events/signals.
  - Invokes `Time:CancelAll(moduleObj)` to purge active tickers.
  - Updates DB enabled state.
  - Fires `Events:Fire("MODULE_DISABLED", moduleName)`.
- Implement `Primus:IsModuleEnabled(moduleName)` and `Primus:ToggleModule(moduleName)`.
- Add `Primus.Options = Primus.Options or {}`.

#### [MODIFY] [Utils.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Utils/Utils.lua)
- Implement `Primus.Utils.CastOnUnit(unit, spellName)`:
  - Programmatically executes `TargetUnit(unit)` &rarr; `CastSpellByName(spellName)` &rarr; `TargetLastTarget()` / `ClearTarget()`.
- Implement `Primus.Utils.CleanseNextMember(cleanseSpell, targetDebuffType)`:
  - Iterates over `player` and `party1..4` / `raid1..40`, queries `UnitDebuff(unit, d)`, and executes `CastOnUnit`.

#### [MODIFY] [Time.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Time/Time.lua)
- Support owner tracking on timers (`node.owner = owner`).
- Implement `Time:CancelAll(owner)` to cancel all scheduled one-shots and tickers associated with a module/owner upon disable.

#### [MODIFY] [DB.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/DB/DB.lua)
- Add Profile Management APIs:
  - `DB:GetProfiles()`: Returns array of existing profile names.
  - `DB:GetCurrentProfile()`: Returns active profile name.
  - `DB:SaveProfile(profileName)`: Deep-copies current namespaces into `PrimusGlobalDB.profiles[profileName]`.
  - `DB:LoadProfile(profileName)`: Restores profile namespaces from `PrimusGlobalDB.profiles[profileName]`, syncs all namespace handles, and fires `Events:Fire("PROFILE_CHANGED", profileName)`.
  - `DB:DeleteProfile(profileName)`: Deletes profile (cannot delete active profile or "Default").
  - `DB:CopyProfile(sourceName, targetName)`: Copies settings between profiles.

#### [MODIFY] [PrimusUI.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/PrimusUI.lua)
- Update boot sequence in `InitializeAll()` to check module enabled state (from DB / module table) during Phase 3 and call `Primus:EnableModule(moduleName)` cleanly.

---

### Component 2: Distributed Options Flare Hub & Master GUI Redesign

#### [MODIFY] [Options.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Config/Options.lua)
- **Flare Registration Registry:**
  - Implement `Primus.Options:RegisterModuleOptions(id, meta, builderFunc)` and `Primus:RegisterModuleOptions(id, meta, builderFunc)`.
  - Support metadata: `{ title = "...", category = "...", icon = "...", order = 1, desc = "...", dbKey = "..." }`.
  - Keep registrations in a lightweight table with zero upfront UI widget allocations.
- **Dynamic LoD Canvas & Caching:**
  - Viewport scroll container on the right 75%.
  - On module selection, checks `cachedPanels[id]`. If nil, calls `builderFunc(canvas)` and caches the returned frame.
  - Renders top header banner with module title, category, description, and real-time `[ACTIVE]` / `[DISABLED]` status indicator.
- **Left 25% Static Command Center (Split Layout):**
  - **Top Half:**
    - Category filter dropdown (`All Categories`, `Action Bars`, `Combat & HUD`, `Unit Frames`, `Player & Bags`, `Utility & Layout`, `Social & Chat`, `Economy & Trade`, `Class Suite`, `System`).
    - Scrollable module list with clickable rows for panel selection and instant `[x]` enable/disable checkboxes.
  - **Bottom Half:**
    - Profile dropdown selector.
    - Profile Name EditBox + `[Save Profile]` button.
    - `[Load Profile]` button.
    - `[Delete Profile]` button (with confirmation popup).
    - Quick Action Utilities: `[Reset Defaults]`, `[Unlock UI]`, `[Reload UI]`.
- **System Options Flare:**
  - Register the Core System options flare ("System") covering memory pool stats, GC trigger, and `/errors` log viewer.

---

### Component 3: PUIHotbars Sub-File Deconstruction & Paging Engine

Decompose `PUIHotbars.lua` into 4 modular sub-files in `Modules/Bars/PUIHotbars/`:

#### [NEW] [Buttons.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Bars/PUIHotbars/Buttons.lua)
- Implement `PUIHotbars:StyleButton(btn, size)`:
  - **Pure Scaling:** Retain full `(0.0, 1.0, 0.0, 1.0)` texture coordinates (zero `SetTexCoord` cropping).
  - 1-Pixel backdrop overlay creation and hover feedback.
  - Hotkey abbreviation formatter (`ALT-` &rarr; `a`, `Mouse Wheel Up` &rarr; `WU`).
- 0.15s real-time Range (`IsActionInRange`) and Mana (`IsUsableAction`) vertex color tinting ticker.

#### [NEW] [XPBar.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Bars/PUIHotbars/XPBar.lua)
- Implement `BuildXPBar()` and `PUIHotbars:UpdateXP()`:
  - Custom status bars for Experience, Rested Bonus, and Watched Faction Reputation.
  - Detailed hover tooltip formatting.

#### [NEW] [MicroBags.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Bars/PUIHotbars/MicroBags.lua)
- Virtualize Blizzard's Micro Menu buttons into `Primus_PUIHotbars_MicroBar`.
- Virtualize Bag and Keyring buttons into `Primus_PUIHotbars_BagBar`.
- Register both containers with `PUIMover` under `BARS` category.

#### [MODIFY] [PUIHotbars.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Bars/PUIHotbars/PUIHotbars.lua)
- **120-Slot Paging Tunnel Resolver:**
  - Dynamic page resolution: `PUIHotbars:ResolveActivePage(barIndex)` handling stances (`UPDATE_BONUSACTIONBAR`, `UPDATE_SHAPESHIFT_FORMS`), stealth, and modifiers.
  - Real-time action ID routing: `PUIHotbars:GetButtonActionID(barIndex, buttonIndex)` without multi-frame stacking.
- **Dynamic Matrix Layout Engine:**
  - Implement dynamic `Rows` (1–12) and `Columns` (1–12) math for Bars 1–5, Stance Bar, and Pet Bar (supporting `12x1`, `1x12`, `6x2`, `2x6`, `3x4`, `4x3`).
- **Options Flare:** Build `PUIHotbars` settings panel with Rows/Cols sliders, button size, spacing, and range/mana toggles.

---

### Component 4: PUIHud Cockpit Mini-Bars (Bar 10 Integration)

#### [MODIFY] [PUIHud.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/HUD/PUIHud/PUIHud.lua)
- Implement 4 Left + 4 Right HUD Wing Mini-Bars mapped directly to **Bar 10 (`Slots 109..120`)**:
  - Left Wing: Slots `109, 110, 111, 112`.
  - Right Wing: Slots `113, 114, 115, 116`.
  - ActiveAssist / Emergency: Slots `117, 118, 119, 120`.
- Native drag-and-drop support from Spellbook/Bags with zero stance collisions.
- Full Range checking (`IsActionInRange`) and Cooldown sweep integration.

---

### Component 5: PUIUnitFrames Click-Casting & PUITactical Decursive

#### [MODIFY] [UnitFrames.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Units/UnitFrames/UnitFrames.lua)
- Implement Click-to-Heal / Click-Casting handler on Player, Target, Party, and Raid unit buttons:
  - Supports Left, Right, Middle, Button 4/5 + Shift/Ctrl/Alt combinations.
  - Direct execution via `Primus.Utils.CastOnUnit(unit, spellName)` with target preservation.
- Debuff highlight border coloring (Magic, Curse, Poison, Disease).
- 40-yard range fading via `Primus.Range` and `HealComm` incoming heal prediction overlay.

#### [MODIFY] [Tactical.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Combat/Tactical/Tactical.lua)
- Implement 1-Click Decursive scan trigger via `Primus.Utils.CleanseNextMember`.
- ActiveAssist emergency rescue button execution.

---

### Component 6: Decentralize Options & Standardize Module Lifecycles

Extract inline configuration panels from `Options.lua` and implement clean `OnEnable`/`OnDisable` in:
- [PUISpellbook.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/PUISpellbook/PUISpellbook.lua) (Spellbook & Themes)
- [Bags.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/Bags/Bags.lua) & [Bank.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/Bank/Bank.lua) (Containers)
- [Vendor.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/Vendor/Vendor.lua) & [PUIDock.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/PUIDock/PUIDock.lua) (General QoL)
- [PUIMerchant.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/PUIMerchant/PUIMerchant.lua) & [PUIGathering.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Gathering/PUIGathering/PUIGathering.lua) & [PUIProfessions.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Professions/PUIProfessions/PUIProfessions.lua) (Economy)
- [PUIMessenger.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Social/PUIMessenger/PUIMessenger.lua) & [Chat.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Social/Chat/Chat.lua) & [MasterLoot.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Social/MasterLoot/MasterLoot.lua) (Social)
- [PUIMover.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/PUIMover/PUIMover.lua) (Layout & Mover Grid Settings)
- [Modules/Classes/](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Classes) (Class Nuance Suite)

---

### Component 7: TOC & Technical Debt Fixes

#### [MODIFY] [PrimusUI.toc](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/PrimusUI.toc)
- Add `Modules\Combat\Range\Range.lua` (under Combat & HUD Engines).
- Add `Modules\Bars\PUIHotbars\Buttons.lua`, `XPBar.lua`, and `MicroBags.lua` (under Action Bars).
- Remove `Modules\Utility\AuctionHouse\AuctionHouse.lua`.

#### [DELETE] [AuctionHouse.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/AuctionHouse/AuctionHouse.lua)
- Remove redundant orphaned file (fully superseded by `PUIMerchant.lua`).

---

## Verification Plan

### Automated Static Analysis & Syntax Verification
- Run syntax and block verification on every modified and newly created `.lua` file to verify strict Lua 5.0.2 compatibility:
  ```bash
  for f in $(find Core Modules -name "*.lua"); do python3 -c "..." "$f"; done
  ```

### Manual Verification Scenarios
1. **Options GUI Redesign & Flare Discovery:**
   - Run `/pui` to open Master Command Center (25% Left / 75% Right split).
   - Verify category filter dropdown, scrollable module list, and Profile IO controls.
   - Click each module row and confirm Right 75% dynamic LoD canvas renders on demand.
2. **PUIHotbars Dynamic Rows & Columns Matrix:**
   - Change Bar 1 to 6 Columns x 2 Rows (`6x2`). Verify buttons wrap and frame geometry updates.
   - Change Bar 4 to 2 Columns x 6 Rows (`2x6`). Verify clean vertical sidebar layout.
   - Verify icons display with full native texture without cropped border edges.
3. **PUIHotbars Stance Paging Tunnels:**
   - Switch between Battle, Defensive, and Berserker stance on Warrior (or Bear/Cat on Druid / Stealth on Rogue).
   - Verify Bar 1 dynamic paging swaps slot IDs without frame flicker or stance collision.
4. **PUIHud Bar 10 Cockpit Mini-Bars:**
   - Drag spells/items from Spellbook/Bags onto Left/Right HUD mini-bars (Slots `109..116`).
   - Verify clicks cast spells natively, range tinting updates, and stance swaps do not overwrite HUD buttons.
5. **PUIUnitFrames Click-Casting:**
   - Bind `Shift + LeftClick` to *Flash Heal* and click a party/raid frame in combat.
   - Verify spell casts on that member and player's offensive target is preserved via `TargetLastTarget()`.
6. **PUITactical Decursive Scanning:**
   - Trigger a curse/magic/poison on a group member and press the cleanse keybind / click ActiveAssist.
   - Verify unit is cleansed and previous target is restored.
7. **Profile IO Operations:**
   - Save "TestProfile", modify settings, reload, and verify persistence.
