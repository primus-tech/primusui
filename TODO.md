# PrimusUI: Development Backlog & Roadmap (TODO)

> **Status:** Active Development  
> **Target Platform:** Vanilla WoW 1.12.1 (Interface 11200 / Lua 5.0.2)  
> **Source Documents:** [`TRUTH.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/TRUTH.md) | [`DESIRED_FEATURES.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/DESIRED_FEATURES.md) | [`AUDIT.md`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/AUDIT.md)

---

## 🚀 Active Architecture & Core Refactors (Current Sprint)

### 1. Distributed Module Options & "Flare" Handshake Architecture
- [x] **Core Options Flare Registry (`Core/Config/Options.lua`):**
  - [x] Implement `Primus.Options:RegisterModuleOptions(id, meta, builderFunc)` in Core.
  - [x] Store lightweight registration descriptors on boot with zero upfront widget allocation.
- [x] **Master Options GUI Redesign (Left-Right Split):**
  - [x] **Left 25% Static Command Center:**
    - [x] **Top Half:** Category dropdown filter with category grouping.
    - [x] **Top Half:** Compact Scroll Box with instant `[x]` enable/disable checkboxes for all registered modules.
    - [x] **Bottom Half:** Complete Profile IO Management:
      - [x] Profile selector dropdown & profile name edit box.
      - [x] `[Save Profile]` button with deep-copy persistence.
      - [x] `[Load Profile]` button with instant module state restoration.
      - [x] `[Delete Profile]` button with confirmation safety popup.
      - [x] `[Unlock UI]`, `[HoverBind]`, and `[Reload UI]` quick-action utilities.
  - [x] **Right 75% Dynamic LoD Canvas:**
    - [x] Clean viewport container that dynamically executes the active module's `builderFunc` on demand.
    - [x] Cache constructed module option panels after first render to eliminate garbage churn.
    - [x] Real-time `[ACTIVE]` / `[DISABLED]` status indicator badge.
- [x] **Decentralize Module Flares:**
  - [x] Send up individual module flares from their respective directories across all 35 modules.

---

### 2. PUIMover Utility Module Refactor (`Modules/Utility/PUIMover/`)
- [x] **Module Relocation & Setup:**
  - [x] Create `Modules/Utility/PUIMover/PUIMover.lua` and register via `Primus:RegisterModule("PUIMover", PUIMover, "Utility")`.
  - [x] Remove `Core/Mover/Mover.lua` to keep `Core/` purely headless.
  - [x] Refactor all modules across the codebase to directly use `PUIMover` / `Primus.PUIMover` with zero aliasing.
- [x] **Features & Engine Integration:**
  - [x] Port categorized frame isolation (`BARS`, `UNITS`, `HUD`, `PLAYER`, `CLASS`, `SOCIAL`, `UTILITY`).
  - [x] Top-centered Floating Mover Control Dock with interactive category pill buttons.
  - [x] Magnetic fullscreen alignment grid (`[GRID]`) and 1-pixel precision nudging controls (`[▲] [▼] [◄] [►]`).
  - [x] Coordinate snapping and persistent position serialization via `PrimusCharDB` / `PrimusGlobalDB`.
  - [x] Register `/pui move [category]` command routing.
  - [x] Create `PUIMover` options panel and send up its flare to the Core Options hub.

---

### 3. Strict Module Lifecycle Engine (`OnEnable` & `OnDisable`)
- [x] **Standardize Lifecycle Handlers:**
  - [x] Implement explicit `OnEnable()` and `OnDisable()` methods across all modules.
- [x] **Clean Runtime Teardown:**
  - [x] Ensure toggling any module off in the sidebar unregisters its event subscriptions via `Events:UnregisterOwner(owner)`.
  - [x] Cancel module `Time` tickers and hide all visible frame elements cleanly without requiring a `/reload`.


---

### 4. PUIHotbars Engine Virtualization, ID Reuse & Sub-File Breakdown (`Modules/Bars/PUIHotbars/`)
- [x] **Pure Scaling & Icon Cropping Elimination:**
  - [x] Remove all artificial `SetTexCoord(0.07, 0.93, 0.07, 0.93)` zoom cropping from button and icon renderers.
  - [x] Enforce pure frame-dimension scaling (`btn:SetWidth` / `btn:SetHeight`).
- [x] **120-Slot ID Reuse Pool & Dynamic Paging Tunnels:**
  - [x] Implement abstract slot ID allocator across Blizzard's 120 action slots (`1..120`).
  - [x] Implement Paging Tunnel condition gateway evaluating stances (Warrior, Druid, Rogue), stealth, modifiers (Shift/Ctrl/Alt), and manual paging without multi-frame stacking or flicker.
- [x] **Deconstruct Monolithic `PUIHotbars.lua` into Modular Sub-files:**
  - [x] `Modules/Bars/PUIHotbars/PUIHotbars.lua`: Core bar manager, decoupled independent anchors (Bars 1–5, Stance, Pet), Blizzard FrameXML neutralization, dynamic matrix orchestrator, and event routing.
  - [x] `Modules/Bars/PUIHotbars/PUIButtons.lua`: Button skinning, 1px backdrop overlays, hotkey formatting, pure scaling, range/mana tinting ticker, and empty slot grid persistence.
  - [x] `Modules/Bars/PUIHotbars/PUIXPBar.lua`: Multi-Faction XP & Reputation watchbar with silent Character Sheet polling, stacked/cycle/split modes, session telemetry, right-click quick menu, and hover tooltip.
  - [x] `Modules/Bars/PUIHotbars/PUIMicroBags.lua`: Dockable Micro Menu bar and Bag Bar virtualization with 1px styling.
- [x] **Dynamic Matrix Sliders (Rows & Columns per Bar):**
  - [x] Implement Rows (1–12) and Columns (1–12) math for Bars 1–5, Stance Bar, and Pet Bar (enabling 1x12, 12x1, 6x2, 2x6, 3x4, 4x3).
  - [x] Dynamically compute frame dimensions and button point math.
- [x] **HUD Mini-Bar Integration (`Bar 10: Slots 109..120`):**
  - [x] Map 4 dedicated buttons to Left HUD Wing (`109..112`) and 4 buttons to Right HUD Wing (`113..116`).
  - [x] Enable native drag-and-drop from Spellbook/Bags with zero stance collisions.
- [x] **TOC & Options Handshake:**
  - [x] Update `PrimusUI.toc` with the 4 modular sub-file entries.
  - [x] Send up `PUIHotbars` settings flare to Core Options hub.

---

### 5. PUIHud 6-File Modular Deconstruction & Bar 10 Integration (`Modules/HUD/PUIHud/`)
- [x] **Deconstruct Monolithic `PUIHud.lua` into 6 Dedicated Sub-Files:**
  - [x] `Modules/HUD/PUIHud/PUIWings.lua`: Vertical Player & Target vitals (HP/Power), class coloring, reaction coloring, level tags.
  - [x] `Modules/HUD/PUIHud/PUIMiniBars.lua`: Dedicated Bar 10 Cockpit Mini-Bars (Slots `109..116`).
  - [x] `Modules/HUD/PUIHud/PUIActiveAssist.lua`: Smart threat peel (Left) & MT Focus Fire (Right) buttons.
  - [x] `Modules/HUD/PUIHud/PUITimers.lua`: Dual-swing timers (MH/OH/Ranged + Enemy melee cadence) and GCD/Interrupt rails.
  - [x] `Modules/HUD/PUIHud/PUITriage.lua`: Central Triage Array with emergency MT monitoring and emerald reassurance flash.
  - [x] `Modules/HUD/PUIHud/PUIHud.lua`: Master coordinator, dynamic alpha easing, and options flare handshake.

---

### 6. Canonical PUI Architecture Standardization & Single Domain Ownership
- [x] **100% PUI Canonical Nomenclature Across All 68 Files:**
  - [x] Standardize all directories, file names, local tables, module registrations, DB namespaces, options flares, and mover keys to `PUI<Name>`.
  - [x] Strict Zero-Aliasing and Zero-Shims enforcement.
- [x] **Announce & Listen Micro-Kernel Handshake:**
  - [x] Core discovery desk at boot with automatic dynamic variable and namespace provisioning.
- [x] **Strict Single Domain Ownership & Request Model:**
  - [x] Enforce exclusive domain ownership with requests routed via public APIs and the decoupled Signal Bus.
- [x] **SavedVariables Automatic Schema Migration (`Core/DB/DB.lua`):**
- [x] **TOC & Engine Verification:**
  - [x] Update `PrimusUI.toc` with all 6 `PUIHud` sub-files in order.
  - [x] Pass static Lua 5.0.2 syntax audit with 0 forbidden operators.

---

### 7. Symmetrical PUIHud Cockpit & Tight "U" Cradle Engine (`Modules/HUD/PUIHud/`)
- [x] **Tight "U" Cockpit Cradle (Slots 109..120):**
  - [x] **Left Flank (Outer to Inner):** Vertical Player Auras (8 slots) &rarr; Player Vital Wing (HP/Power) &rarr; Left Mini-Bar (`cockpitBar1`, Slots 109..112, inside facing character).
  - [x] **Right Flank (Inner to Outer):** Right Mini-Bar (`cockpitBar2`, Slots 113..116, inside facing character) &rarr; Target Vital Wing (HP/Power) &rarr; Vertical Target Auras (8 slots).
  - [x] **Bottom Flank (Top to Bottom):** Bottom Mini-Bar (`cockpitBar3`, Slots 117..120, inside base of U) &rarr; Dual Swing Timers &rarr; HUD Cast Bar &rarr; GCD Ticker Rail.
- [x] **Live Aura Column Engine:**
  - [x] Dynamic 8-slot aura columns rendered with 22x22px icons, duration tickers, and class/type border highlights on the outermost wings.

---

### 8. Class Nuance Major Ability & Signature Spell Engine (`Modules/Classes/`)
- [x] **Full 9-Class Suite Tracking:**
  - [x] **`PUIPriest`:** Psychic Scream, Fear Ward, Silence, Inner Focus, Power Infusion, Desperate Prayer.
  - [x] **`PUIPaladin`:** Blessing of Protection, Divine Shield, Divine Protection, Blessing of Freedom, Hammer of Justice, Lay on Hands, Divine Intervention.
  - [x] **`PUIDruid`:** Barkskin, Nature's Swiftness, Frenzied Regeneration, Tranquility, Innervate, Rebirth.
  - [x] **`PUIMage`:** Blink, Cone of Cold, Frost Nova, Ice Barrier, Blast Wave, Presence of Mind, Arcane Power, Combustion, Ice Block, Evocation, Cold Snap.
  - [x] **`PUIWarrior`:** Shield Wall, Last Stand, Challenging Shout, Taunt, Mocking Blow, Recklessness, Retaliation, Death Wish, Berserker Rage.
  - [x] **`PUIRogue`:** Vanish, Blind, Evasion, Sprint, Preparation, Adrenaline Rush, Blade Flurry, Kick.
  - [x] **`PUIShaman`:** Reincarnation (Jesus Rezz), Mana Tide Totem, Nature's Swiftness, Elemental Mastery, Earth Shock.
  - [x] **`PUIWarlock`:** Soulstone Resurrection, Death Coil, Howl of Terror, Shadowburn, Soul Link, Amplify Curse, Fel Domination.
  - [x] **`PUIHunter`:** Tranquilizing Shot, Feign Death, Rapid Fire, Bestial Wrath, Scatter Shot, Deterrence, Intimidation.
- [x] **Unified API & Auto-Spellbook Discovery:**
  - [x] Expose `PUI<Class>:GetMajorCooldowns()` returning structured lists `{ name, short, tex, icon, duration, remaining, isReady, spellId }`.
  - [x] Automatic spellbook re-scanning on `SPELLS_CHANGED`, `LEARNED_SPELL_IN_TAB`, and `PLAYER_ENTERING_WORLD`.
  - [x] Smart docking with `PUIHud` when active and fallback to standalone `PUIMover` frames when standalone.

---

## 🧭 Navigation & Minimap Suite (Tier 2 Roadmap)

### 4. PUIMMButtons: Minimap Button Collector (`Modules/Utility/PUIMMButtons/`)
- [ ] **Automated Addon Button Discovery:**
  - [ ] Implement recursive scanner detecting non-Blizzard addon minimap buttons (`*_MinimapButton`, `*MinimapFrame`, `LibDBIcon*`, DBM, KTM, Atlas, etc.).
  - [ ] Re-parent discovered buttons to the `PUIMMButtons` dock without breaking click handlers or scripts.
- [ ] **Blizzard Button Inclusion Controls:**
  - [ ] Option to capture standard Blizzard icons (Mail, Tracking, Battlefield/PvP queue, Day/Night clock, Zoom buttons).
- [ ] **Dock Layouts & Presentation:**
  - [ ] Configurable dock styles: Horizontal strip, Vertical bar, or Pop-out drawer (`◀️`) with mouseover auto-collapse.
  - [ ] Normalize icons into crisp 20x20px or 24x24px squares with 1-pixel border styling.
  - [ ] Reposition mouseover tooltips cleanly away from the dock edges.
- [ ] **Options Flare:** Build `PUIMMButtons` settings panel (dock mode, icon size, spacing, Blizzard toggles).

---

### 5. PUIMinimapper: Minimap Shaper, Sizer & Coordinates (`Modules/Navigation/PUIMinimapper/`)
- [ ] **Multi-Geometry Minimap Masking:**
  - [ ] Implement shape shaders/masks: Modern Square, Sleek Hexagon, Octagon, Classic Round, and Frameless Minimalist.
- [ ] **Sizing, Scaling & Alpha:**
  - [ ] Dimension sliders (120px to 260px) and global scale multiplier.
  - [ ] Situational alpha adjustments (exploration vs combat fading via Combat Zen).
- [ ] **Integrated Coordinate HUD:**
  - [ ] Real-time high-precision Player coordinates (`XX.X, YY.Y`) and Cursor coordinates.
  - [ ] Configurable font styling and anchor snapping (Top, Bottom, or Inside-Overlay).
- [ ] **Controls & Art Stripping:**
  - [ ] Mouse-wheel scroll zoom in/out with 10s auto-reset back to default outer view.
  - [ ] Suppress default Blizzard compass ring, zone header, and redundant border textures.
- [ ] **PUIMover Integration:**
  - [ ] Register minimap container with `PUIMover` under `HUD` / `UTILITY` category for visual dragging and snapping.
- [ ] **Options Flare:** Build `PUIMinimapper` settings panel (shape picker, dimension sliders, coordinate toggles).

---

## 📌 Immediate Critical Fixes & Technical Debt
 
- [x] **`Range` Module TOC Fix (`Modules/Combat/Range/`):**
  - [x] Add `Modules\Combat\Range\Range.lua` to `PrimusUI.toc` so `UnitFrames.lua` can access `Primus.Range` for 40-yard party frame range fading.
- [x] **Orphaned `AuctionHouse` Cleanup (`Modules/Utility/AuctionHouse/`):**
  - [x] Deprecate and remove orphaned `Modules/Utility/AuctionHouse/AuctionHouse.lua` (superseded by `PUIMerchant.lua`).
- [ ] **`Priest` Nuance Suite Expansion (`Modules/Classes/Priest/`):**
  - [ ] Add Shadowform state tracker and Dispel/Abolish monitoring alongside the 5-second FSR mana bar.


---

## 🎯 Tier 2: World, Combat & Navigation Engines

- [x] **`PUIUnitFrames` Click-Casting & Raid Cleansing Engine (`Modules/Units/PUIUnitFrames/` & `UnitBase/`):**
  - [x] Implement mouse-click binding matrix (Left, Right, Middle, Button 4/5, Shift/Ctrl/Alt combinations) with class-curated defaults.
  - [x] Spellbook known-spell verification (`Utils.IsSpellKnown`) and dynamic rank/spell fallbacks.
  - [x] Programmatic unit casting via `Primus.Utils.CastOnUnit` with target preservation (`TargetLastTarget()`).
  - [x] Class-aware debuff highlight border coloring (Magic, Curse, Poison, Disease).
  - [x] 40-yard range dimming via `Primus.Range` and `HealComm` incoming heal prediction sync.
- [x] **`PUITactical` Decursive & Smart Cleansing Engine (`Modules/Combat/PUITactical/`):**
  - [x] Automated class-aware group debuff scanner (`Primus.Utils.CleanseNextMember` / `Tactical:CleanseNext`).
  - [x] One-button smart cleanse keybind / `/pui cleanse` subcommand / ActiveAssist HUD button.
- [ ] **`CombatText` Module (`Modules/Combat/CombatText/`):**
  - [ ] Implement floating/scrolling combat text engine for damage, healing, crits, and procs.
  - [ ] Support custom font animations, color coding by school (Fire, Shadow, Frost, Physical), and icon badges.
  - [ ] Provide configurable arc, straight-up, or split-scroll trajectories.
- [ ] **`WorldMap` Enhancement Module (`Modules/Navigation/WorldMap/`):**
  - [ ] Add player & cursor coordinates to `WorldMapFrame`.
  - [ ] Support windowed / scalable mode for `WorldMapFrame` without taking over the full screen.
  - [ ] Add map pin overlay system for custom waypoints, quest objectives, and gathering nodes.
- [ ] **`QuestLog` Tracker Module (`Modules/Player/QuestLog/`):**
  - [ ] Extended quest objective tracker with collapsible headers and progress percentages.
  - [ ] Quest level display in the quest title list (`[60] In Dreams`).
  - [ ] Integrated quest timer and quest reward preview.

---

## 🎯 Tier 3: Player & Character Sub-Modules

- [ ] **`Bags` & Inventory Advanced Innovations (`Modules/Player/Bags/`):**
  - [ ] Implement the automated bag defragmentation & auto-sort algorithm (`[SORT]`).
  - [ ] Build collapsible bottom bag dock with interactive bag highlight filter (spotlights selected bag, dims other slots to 20%).
  - [ ] Add single-button Master Bag Bar mode with live slot badge (`[34/80]`).
  - [ ] Build three layout presentation presets:
    - *Preset 1:* Unified Continuous Grid.
    - *Preset 2:* Grouped by Bag Containers.
    - *Preset 3:* Categorized Smart Auto-Sort (Weapons/Armor, Consumables, Trade Goods, Quest, Junk, Free).
- [x] **`Reputation` Module / Multi-Faction Watchbar (`Modules/Bars/PUIHotbars/PUIXPBar.lua`):**
  - [x] Add a dedicated reputation watchbar with smooth XP-style fill transitions.
  - [x] Standing level text formatting (`Revered 12,450 / 21,000 [59%]`).
  - [x] Auto-switch active watched faction on reputation gain.
  - [x] Silent non-destructive deep polling of Character Sheet Reputation tab.
  - [x] Stacked multi-bar array (1..4 bars), adaptive single cycle, and split dual-tier modes.
- [ ] **`MacroManager` Module (`Modules/Utility/MacroManager/`):**
  - [ ] Extended macro editor with syntax highlighting and script length expansion.
  - [ ] Icon browser with search filter for macro icons.

---

## 🎯 Tier 4: Interaction, Social & Content Sub-Modules

- [x] **`PUIRoleplay` Roleplaying Suite (`Modules/Social/PUIRoleplay/`):**
  - [x] 100% two-way wire-protocol compatibility with TurtleRP over the `TTRP` channel (DrunkEncode/Decode, M/T/D packet parser, 30s pings).
  - [x] Standalone operation without requiring the TurtleRP addon.
  - [x] High-definition PrimusUI dark glassmorphic UI design (1-pixel borders, status pills).
  - [x] Target At-A-Glance HUD Pill with 3 glance buttons & `[Bio]` button registered with `PUIMover` under `SOCIAL`.
  - [x] Character Profile Sheet & Editor (General, RP Style, Glances, Bio, Notes, Profile switcher, Icon browser).
  - [x] GameTooltip RP metadata injection (RP name, title, pronouns, IC/OOC badges).
  - [x] Searchable RP Player Directory (`/rp dir`) & World Map RP player location pins.
  - [x] Long-form RP chat/emote composer (`/rp chat`) with multi-chunk sending & quote highlighting.
- [ ] **`Guild & Roster` Module (`Modules/Social/Guild/`):**
  - [ ] Enhanced guild roster with sortable columns (Level, Class, Rank, Zone, Public Note, Officer Note).
  - [ ] Offline member tracking and last-online timestamps.
- [ ] **`Raid & Party Management` Module (`Modules/Social/RaidTools/`):**
  - [ ] Raid marker bar (Skull, Cross, Square, Moon, Triangle, Diamond, Circle, Star).
  - [ ] Automated pull timer with raid warning broadcast (`/rw Pull in 5... 4... 3...`).
  - [ ] Ready check monitor with visual status grid for 40-man raid groups.
- [ ] **`Battlegrounds` Module (`Modules/Content/Battlegrounds/`):**
  - [ ] **Warsong Gulch:** Flag carrier tracker with class color, health bar, and direction indicator.
  - [ ] **Arathi Basin:** Real-time node capture countdown timers and resource race predictor.
  - [ ] **Alterac Valley:** Graveyard and tower status timers, boss health monitors, and reinforcement count.
- [ ] **`Dungeon & Instances` Module (`Modules/Content/Instances/`):**
  - [ ] Instance lockout overview (`/raidinfo`) with expiration countdowns.
  - [ ] Hourly instance reset counter (tracking the 5 instances per hour limit).

---

## 📦 Core Infrastructure & Quality Assurance

- [ ] **Core L10n Engine (`Core/L10n/`):** Create a centralized localization engine supporting English (`enUS`), German (`deDE`), French (`frFR`), and Chinese (`zhCN`) locale dictionaries.
- [ ] **Release Automation:** Update `Tools/package.sh` to include automated zip generation with integrity checksums.
- [ ] **In-Game Profiling:** Verify memory usage remains under 10 MB with all modules active during 40-man raid combat.
