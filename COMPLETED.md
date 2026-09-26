# PrimusUI: Completed Features & Systems Log (COMPLETED)

> **Target:** Vanilla WoW 1.12.1 (Interface `11200` | Lua 5.0.2)  
> **Repository:** `Interface/AddOns/PrimusUI`  
> **Last Verified:** 2026-09-23

---

## 🏛️ Tier 1: Core Foundation & Controller Runtime (`Core/`)

- [x] **100% Canonical PUI Architecture Standardization (Zero Aliasing / Zero Shims):**
  - Standardized all 68 active source files, directories, local tables, module registrations, and DB namespaces across all 4 tiers.
  - Purged all legacy and double-prefix naming artifacts.
  - Guaranteed zero table aliases and zero metatable proxy shims across the entire codebase.
- [x] **Announce & Listen Micro-Kernel Lifecycle & Discovery Handshake:**
  - Decoupled load-time module announcement (`Primus:RegisterModule`) from game login execution.
  - Staged 2-phase boot sequencer (`OnInitialize` &rarr; `OnEnable`) at `PLAYER_LOGIN`.
  - Dynamic provisioning of SavedVariables namespaces, Options flares, and Mover targets.
- [x] **Strict Single Domain Ownership & Request-Driven Interaction Model:**
  - Enforced exclusive domain ownership (`PUIHotbars` owns action bars; `PUIBags` owns containers; `PUIUnitFrames` owns unit frames; `PUIChat` owns chat).
  - Banned direct foreign frame mutations in favor of public API requests and decoupled Signal Bus broadcasting (`Events:Fire`).
- [x] **SavedVariables Automatic Schema Migration (`Core/DB/`):**
  - Seamless deep-copy migration from legacy non-PUI keys (`"Bags"` &rarr; `"PUIBags"`, `"UnitFrames"` &rarr; `"PUIUnitFrames"`) on first boot without resetting user configurations.
- [x] **Bootstrap & Lifecycle Engine (`Core/Bootstrap/`):**
  - Major/minor version election system preventing multi-instance collisions.
  - Staged lifecycle boot sequencer (`BOOT` &rarr; `INITIALIZING` &rarr; `READY`).
  - Public module registration API (`Primus:RegisterModule`).
  - Strict Module Lifecycle Engine (`Primus:EnableModule`, `Primus:DisableModule`, `Primus:ToggleModule`, `Primus:IsModuleEnabled`) with DB persistence and event/timer teardown.
  - Distributed Options subsystem anchor (`Primus.Options`).
- [x] **Event Bus & Dispatcher (`Core/Events/`):**
  - Single master event listener frame routing events to subscribed modules.
  - Custom software signal bus (`Fire`/`RegisterSignal`).
  - Safe callback wrapping preventing runtime errors from halting event loops.
  - Clean lifecycle teardown via `Events:UnregisterAll(owner)`.
- [x] **Memory & Table Recycling Pool (`Core/Memory/`):**
  - Zero-allocation table pool (`AcquireTable`, `ReleaseTable`).
  - Garbage collection throttles and diagnostic stats via `/pui memory`.
- [x] **Time & Ticker Engine (`Core/Time/`):**
  - Centralized master `OnUpdate` ticker replacing per-frame script updates.
  - High-precision one-shot timers (`Time:After`) and repeating tickers (`Time:Every`) with module `owner` tracking.
  - Lifecycle purging via `Time:CancelAll(owner)`.
- [x] **Profile Database IO & Profile Manager (`Core/DB/`):**
  - Dual-layer storage: Account-wide `PrimusGlobalDB` and character-specific `PrimusCharDB`.
  - Profile switching, defaults inheritance, and namespace isolation (`DB:RegisterNamespace`).
  - Full Profile Management Engine (`DB:GetProfiles`, `DB:GetCurrentProfile`, `DB:SaveProfile`, `DB:LoadProfile`, `DB:DeleteProfile`, `DB:CopyProfile`).
- [x] **Lua 5.0.2 Utility & Click-Casting Primitives (`Core/Utils/`):**
  - String trimming, regex splitting, deep table copying, and hex color formatting.
  - Built-in 1.12.1 unconstrained click-casting primitive (`Primus.Utils.CastOnUnit`) with target preservation (`TargetLastTarget`).
  - Automated 1-click group cleanse scanner (`Primus.Utils.CleanseNextMember`).
- [x] **Distributed Options Flare Hub & Master Command Center (`Core/Config/`):**
  - Flare protocol handshake (`Primus.Options:RegisterModuleOptions`) with zero upfront widget memory allocations.
  - Master Command Center GUI with 25% Left / 75% Right layout split.
  - Category filter dropdown and scrollable module list with live `[x]` enable/disable checkboxes.
  - Profile IO management controls (Save, Load, Delete, Selector dropdown) and quick utilities (Unlock UI, HoverBind, Reload UI).
  - Dynamic LoD right canvas with persistent panel caching and real-time `[ACTIVE]` / `[DISABLED]` status indicator badge.
  - Built-in System Flare (Table pool diagnostics, GC button, error inspector, global UI scale, core QoL toggles).
  - Blizzard Escape Game Menu integration (`GameMenuButtonPrimus`).
- [x] **Media & Skinning Registry (`Core/Media/`):**
  - Central registry for flat statusbar textures, pixel fonts, borders, and UI sound effects.
- [x] **Widget Factory (`Core/Widgets/`):**
  - Fluent constructors for frames, status bars, checkboxes, sliders, dropdown menus, and edit boxes.
- [x] **Categorized PUIMover Engine & Floating Control Dock (`Modules/Utility/PUIMover/`):**
  - Categorized frame isolation (`BARS`, `UNITS`, `HUD`, `PLAYER`, `CLASS`, `SOCIAL`, `UTILITY`).
  - Top-centered Floating Mover Control Dock with interactive category pill buttons.
  - Magnetic fullscreen alignment grid (`[GRID]`) and 1-pixel precision nudging controls (`[▲] [▼] [◄] [►]`).
  - Category-selective CLI commands (`/pui move bars`, `/pui move units`, `/pui move hud`, `/pui move class`).
- [x] **Contextual State Machine & Combat Focus Engine ("Zen") (`Core/State/`):**
  - State-driven combat transitions tracking `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`.
  - Strict Action Bar Permanence Rule (rotational ability bars never hidden).
  - Selective blackout system for Minimap, Quest Tracker, Micro Menu, Bag Bar, and Inactive Chat.
  - Smooth 0.25s exponential fades via `Anim:Fade` with Hover-to-Peek support (3.0s delay).
- [x] **Hover-to-Bind Keybinding Engine (`Core/Keybind/`):**
  - Dynamic keybinding mode via `/pui bind` or `/hoverbind`.
- [x] **Centralized Console & Slash Router (`Core/Console/`):**
  - Master command parser for `/pui` and `/primus` with sub-command dispatch and routing.
  - 100% purged all rogue global `SLASH_*` variables from module source files.
- [x] **Inter-Addon Communication Bus (`Core/Comm/`):**
  - Prefix-multiplexed messaging bus over `SendAddonMessage` with data serialization.
- [x] **Diagnostics & Error Trap (`Core/Debug/`):**
  - `pcall` safe wrapper (`SafeCall`) and in-game error trace log (`/pui errors`).
- [x] **Lua 5.0.2 Utility Engine (`Core/Utils/`):**
  - String trimming, regex splitting, deep table copying, and hex color formatting.

---

## ⚔️ Tier 2: World, Combat & Navigation Engines (`Modules/`)

- [x] **Precision Combat Signal Bus & Swing Timer Suite (`PUICombatLog`, `PUIHud`, `PUIHunter`, `PUIWarrior`):**
  - Expanded `PUICombatLog` with complete 1.12 pattern coverage for Melee Hits/Crits/Glancings, Hunter Auto-Shot, Wand Shoot, Miss/Dodge/Parry/Block defense resets, and Hostile mob strikes on player.
  - Resolved `Events:Register` vs `Events:Listen` Signal Bus protocol across `PUIHud`, `PUIHunter`, and `PUIWarrior`.
  - Upgraded `PUIHud` Timing Rails with dynamic ranged vs melee speed resolution (`UnitRangedDamage` vs `UnitAttackSpeed`), remaining countdown formatting (`Auto 1.8s` / `Swing 1.2s`), and auto-repeat handlers.
  - Linked `PUIHunter` Auto-Shot bar directly to verified shot releases from the combat log rather than a blind loop.
  - Resolved `PUIItemStats.lua:38` nil table indexing bug, along with companion updates in `PUICharacterSheet.lua` and `PUICastBar.lua`.
- [x] **PUIHotbars Action Bars & Multi-Faction Watchbar Suite (`Modules/Bars/PUIHotbars/`):**
  - Modular sub-file deconstruction: `Buttons.lua` (skinning, pure scaling, range/mana ticker, grid persistence), `XPBar.lua` (Multi-Faction XP & Rep watchbar), `MicroBags.lua` (Micro Menu & Bag Bar virtualization), `PUIHotbars.lua` (Matrix layout coordinator, 120-slot paging engine).
  - Decoupled Independent Anchors: Separate, unconstrained anchors on `UIParent` for Bars 1–5, Stance Bar, and Pet Bar, registered with `PUIMover` under `"BARS"` (eliminating chained anchor collapse).
  - Blizzard FrameXML MultiActionBar Neutralization: Hooked `MultiActionBar_Update()`, synchronized `SHOW_MULTI_ACTIONBAR_1..4 = 1`, and forced `ALWAYS_SHOW_MULTIBARS = 1` to prevent default UI from hiding active bars.
  - Universal 60-Button Grid Persistence: Enforced `btn.showgrid = 1` and `ActionButton_ShowGrid(btn)` with 1-pixel borders and dark backdrop slots so empty slots remain visible.
  - Multi-Faction XP & Reputation Watchbar (`PUIXPBar.lua`):
    - Automated Silent Character Sheet Poller (`ScanFactions`): Non-destructively scans `ReputationFrame`, temporarily expanding collapsed headers and restoring them, discovering 100% of character factions.
    - Multi-Track Presentation Modes: Stacked Multi-Bar Array (1–4 faction bars + XP bar), Single Adaptive Cycle Bar (Left-Click / Wheel cycling), and Split Dual-Tier Bar.
    - Real-Time Session Reputation Telemetry (`CHAT_MSG_COMBAT_FACTION_CHANGE`) with net session deltas (`+500 Rep`) and auto-focus on gain.
    - In-Bar Right-Click Quick Faction Selector Menu (`Primus_PUIHotbars_RepMenu`), Shift-Click chat progress announcer, and dual-column leveling/faction tooltip.
  - Dynamic Matrix Grid Engine: Independent Rows (1–12) and Columns (1–12) configuration per bar (`12x1`, `1x12`, `6x2`, `2x6`, `3x4`, `4x3`).
  - Pure Scaling (Zero Texture Cropping): Native `(0.0, 1.0, 0.0, 1.0)` texture coordinates with 1-pixel transparent border overlays.
  - Complete suppression of default Blizzard action bar artwork (textures, gryphons, paging buttons).
  - Out-of-range red tinting, out-of-mana blue tinting, and hover tooltip feedback.
  - Comprehensive Options Flare in `/pui hotbars` with explicit toggles for all 5 bars, Stance, Pet, XP, Micro, Bags, matrix sliders, and faction watch settings.
- [x] **Modular Unit Frames Suite (`Modules/Units/UnitFrames/` & `UnitBase/`):**
  - Player, Target, Target-of-Target, Pet, Party (1..4), and Compact 40-Man Raid Grid.
  - Class-Aware and Spellbook-Aware Click-to-Heal / Click-Casting Matrix (`UnitBase:HandleUnitClick`) with target preservation (`TargetLastTarget()`).
  - Dynamic spell and rank fallbacks (e.g. `Purify` if `Cleanse` unlearned, `Heal` if `Greater Heal` unlearned).
  - Class-Aware Debuff Highlight Border Engine prioritizing dispellable debuffs by class (Curse, Magic, Poison, Disease).
  - 40-Yard Range Fading (`Range:IsUnitInRange`) and Heal Prediction overlay (`HealComm`).
  - Clean suppression and event unregistration of default Blizzard unit frames.
  - Options Flare Handshake and standardized `OnEnable`/`OnDisable` lifecycle.
- [x] **Tactical Reaction Engine & Decursive Emergency Action Hub (`Modules/Combat/Tactical/`):**
  - 4-layer Aggro vs. AoE Discrimination Pipeline (Melee white hit guarantee, ToT validation, 150ms temporal deduplication, ability blacklist).
  - 2-Click "Claim & Execute" emergency peel workflow (Red alert -> Amber claimed -> Emerald green resolved).
  - 1-Click Decursive Smart Group Cleanse (`Tactical:CleanseNext` / `/pui cleanse`) with spellbook-aware debuff filtering.
  - Inter-client claim syncing over `Primus.Comm` (`PRI_TAC`).
  - Class-specific emergency actions for all 9 classes.
  - Options Flare Handshake and standardized `OnEnable`/`OnDisable` lifecycle.
- [x] **PUIHud: Precision Vertical HUD & Dual-Swing Timing Suite (`Modules/HUD/PUIHud/`):**
  - Modular 6-File Sub-Architecture:
    - `Wings.lua`: Vertical Player HP/Power & Target HP/Power wings with bottom-to-top statusbars, class coloring, and level tags.
    - `MiniBars.lua`: Dedicated Bar 10 Cockpit Mini-Bars (Slots `109..116`) with native 1.12.1 drag-and-drop (`PickupAction`/`PlaceAction`), click-casting (`UseAction`), pure scaling `(0, 1, 0, 1)`, and range/mana tinting.
    - `ActiveAssist.lua`: 2-Click Threat Peel & MT Focus Fire assist state machine (Alert &rarr; Claimed &rarr; Resolved).
    - `Timers.lua`: Dual-swing timing rails (Player MH/OH/Ranged + Enemy melee cadence) & GCD rail.
    - `Triage.lua`: Central triage array (Top MT pins, critical HP queue, and Emerald Green heal reassurance flash).
    - `PUIHud.lua`: Master coordinator, 0.04s situational alpha easing engine (20% idle, 80% target, 100% combat/low HP), and Options Flare handshake.
- [x] **PUIAuras Aura Management Suite (`Modules/HUD/PUIAuras/`):**
  - Buff and debuff tracking with timers, tooltips, and positioning.

---

- [x] **PUIBags & PUIBank Unified Containers (`Modules/Player/PUIBags/` & `PUIBank/`):**
  - Consolidated single-window inventory and bank with live search filtering and item quality borders.
  - Interactive top bag bar tray (Bags 0–4) with 1-click header toggle button.
  - Plain left-click bag space highlight filtering (dimming unselected bags to 20% alpha) with active gold border indicator.
  - Shift-click / drag bag pickup & swap (`PickupBagFromSlot(invSlot)`).
  - Native 1.12.1 `UI-MoneyIcons` spritesheet integration with dynamic right-to-left layout.
  - Offline persistent caching for Bank container.
- [x] **PUIQuestWatch: Persistent Advanced Quest Tracker (`Modules/Player/PUIQuestWatch/`):**
  - Completely neutralized Blizzard 5-minute auto-expiry bug (`AutoQuestWatch_OnUpdate`).
  - Fixed Blizzard `tremove` array index corruption bug in quest watch lists.
  - Title-based SavedVariables persistence across reloads, relogs, and disconnects.
  - Difficulty colored level headers (`[11] Quest Title`) and completion preservation (`• Complete (Ready to turn in)`).
  - PUIMover integration under `"PLAYER"` category with multi-anchor stretching protection.
  - Slash command registration via `Primus.Console:RegisterSubCommand`.
- [x] **Character Sheet & Item Stats (`Modules/Player/PUICharacterSheet/` & `PUIItemStats/`):**
  - Gear score / iLvl calculator, durability indicators, and extended stat scanner (+Healing, +Spell Dmg, Hit, Crit, MP5).
- [x] **Item Compare (`Modules/Utility/PUIItemCompare/`):**
  - Side-by-side equipment comparison tooltips.
- [x] **PUISpellbook: Traditional 2-Page Spellbook Spread (`Modules/Player/PUISpellbook/`):**
  - Classic 2-column, 2-page spread (6 spells left + 6 spells right = 12 per view) with central spine divider.
  - Multi-rank flyout dropdown per spell card enabling 1-click downranking and `PickupSpell` drag-to-bar assignment.
  - Live search header with real-time query recalculation and filtering across tabs/pages.
  - Right-side discipline skill tabs (General, Class Specs, Pet Spells) with active selection highlights.
  - Authentic page-turn audio triggers (`igSpellBookOpen`, `igSpellBookClose`, `igSpellBookPage`).
  - 5 customizable RGBA visual theme presets (Sleek Obsidian, Antique Parchment, Midnight Arcane, Fel Emerald, Crimson Horde) in `/pui config` and `/pui spellbook [theme]`.
  - MoverEngine integration (`PLAYER` category) and `P` keybind / `SpellBookFrame` virtualization.
- [x] **PUIProfessions Tracker (`Modules/Professions/PUIProfessions/`):**
  - Recipe catalog, craftable item counters, and reagent acquisition tracker.
- [x] **PUIGathering Tracker (`Modules/Gathering/PUIGathering/`):**
  - Mining and herbalism node recording with minimap pin tracking.
- [x] **Vendor Suite & Merchant Automation (`Modules/Player/Vendor/`):**
  - Embedded `[Sell Greys]` button and `[x] Auto-Sell` checkbox directly on `MerchantFrame` (deactivated by default).
  - 100% Vanilla 1.12.1 `GetItemInfo` 9-value unpack engine compliance.
  - Strict protection filter preserving all wearable equipment (weapons, armor, cloth/leather/mail/plate, accessories).
  - Automated gear repairs when interacting with repair-capable merchants and live diagnostic tool `/pui vendor debug`.
- [x] **Class Nuance Suite (`Modules/Classes/*`):**
  - **Warrior:** Stance detection, rage bar, sunder armor counter, and threat/intervene scanner.
  - **Rogue:** 2-second energy ticker, combo point display, pickpocket helper, and auto-lockpick.
  - **Mage:** Major cooldown tracker, mana gem manager, and portal shortcuts.
  - **Priest:** 5-second spirit mana regen ticker, shadowform tracker, and dispel monitor.
  - **Warlock:** Soul shard manager, healthstone/soulstone generator, and curse timer.
  - **Hunter:** Auto-shot swing bar, ammo counter, pet happiness & diet scanner.
  - **Druid:** Shapeshift power tracker, feral energy ticker, and innervate/rebirth monitor.
  - **Shaman:** 4-element totem timers, Reincarnation/Ankh tracker, and weapon imbue monitor.
  - **Paladin:** Party/Raid 5-minute blessing assignment matrix and seal/judgment monitor.

---

## 💬 Tier 4: Interaction, Social & Content Modules (`Modules/`)

- [x] **PUITalk Unified Communication Suite (`Modules/Social/PUITalk/`):**
  - Consolidates `PUIChat` and `PUIMessenger` into a single 3-tab modern social communication hub.
  - **Tab 1 (`[💬 Chat]`):** Virtualized game channels, class-colored names, clickable web URLs with 1-click copy popup, sticky channels, fast mousewheel scrolling, and chat history copy frame `[C]`.
  - **Tab 2 (`[✉️ Messages]`):** Direct whisper conversation sub-tabs, session message history, unread badge counters, audio chimes, and double-send elimination.
  - **Tab 3 (`[👥 Social]`):** Real-time Friends list and Guild roster with online status, level, class, zone, and 1-click `[💬 DM]` button switching to Tab 2.
  - Docked universal input edit box with context pills (`#General`, `To: <Player>`, `Social`).
  - Integrated Whisper Diversion suppressing whispers from main chat log and routing to Tab 2.
- [x] **Inspect Suite (`Modules/Utility/Inspect/`):**
  - Throttled inspect queue preventing client lockups, with target gear and talent tree caching.
- [x] **Master Loot Assistant (`Modules/Social/MasterLoot/`):**
  - Raid roll tracker, countdown timer, and master loot distribution helper.
- [x] **Mailbox Enhancer (`Modules/Utility/Mailbox/`):**
  - "Take All" mass mail collection, recipient auto-fill, and cash collection summary.
- [x] **PUIMerchant & Auction Enhancer (`Modules/Utility/PUIMerchant/` & `AuctionHouse/`):**
  - Unit price calculation, quick buyout shortcuts, and market pricing history.
- [x] **FastLoot & AutoMechanics (`Modules/Utility/FastLoot/` & `AutoMechanics/`):**
  - Instant single-frame auto-looting, auto-dismount on action, and auto-stand on spell cast.
- [x] **PUIDock Frame (`Modules/Utility/PUIDock/`):**
  - Dockable sliding sidebar panels for quick utility access.
- [x] **PUIRoleplay Roleplaying Suite (`Modules/Social/PUIRoleplay/`):**
  - Modular 8-subfile architecture (`PUIConstants.lua`, `PUIComms.lua`, `PUIRPSheet.lua`, `PUIGlance.lua`, `PUITooltip.lua`, `PUIDirectory.lua`, `PUIEmotes.lua`, `PUIRoleplay.lua`).
  - 100% two-way wire-protocol compatibility with TurtleRP (`TTRP` channel, DrunkEncode/Decode codec, M/T/D packet parser, 30s telemetry pings).
  - Standalone operation with zero dependency on the TurtleRP addon.
  - High-definition PrimusUI dark glassmorphic UI design (1-pixel borders, class-colored headers, status pills).
  - Target At-A-Glance HUD Pill with 3 interactive glance widgets and `[Bio]` button registered with `PUIMover` (`"PUIRPGlance"` under `SOCIAL`).
  - Character Profile Sheet & Editor (General, RP Style Preferences, Glances, Bio ScrollBox, Notes, 4 profile slots, icon picker).
  - Non-intrusive GameTooltip RP metadata styling (RP Name, Title, Pronouns, IC/OOC badges, IC/OOC notes).
  - Searchable RP Player Directory with live filter and World Map RP player location pins.
  - Long-form RP chat/emote composer overcoming 255-char limit with automatic multi-chunk transmission and quote formatting.

---

## 🏆 Sprint 1 Complete Architectural Milestone (All 7 Components Verified)

- [x] **Component 1 (Core Lifecycle Runtime & DB Profiles):** Dynamic module enable/disable, event & timer isolation, profile deep-copy, save/load/delete, and profile switching.
- [x] **Component 2 (Distributed Options Flare Hub & Master GUI Redesign):** 25% Left Command Center / 75% Right dynamic LoD canvas, category dropdown filter, profile IO controls, frame caching, and live `[x]` sidebar toggles.
- [x] **Component 3 (PUIHotbars Virtualization & 120-Slot Paging Tunnels):** Modular 4-file deconstruction (`Buttons.lua`, `XPBar.lua`, `MicroBags.lua`, `PUIHotbars.lua`), Rows/Cols matrix math (1..12), pure scaling without texture cropping, and stance/form condition gateway.
- [x] **Component 4 (PUIHud 6-File Modular Deconstruction & Bar 10 Mini-Bars):** Deconstructed into `Wings.lua`, `MiniBars.lua` (Slots 109..116), `ActiveAssist.lua`, `Timers.lua`, `Triage.lua`, and `PUIHud.lua` (0.04s situational easing).
- [x] **Component 5 (Click-Casting & Decursive Engine Integration):** Universal click-to-heal dispatcher with spellbook/rank awareness, class-aware debuff highlight borders, and 1-click `/pui cleanse` emergency trigger.
- [x] **Component 6 (Distributed Options Flare Decentralization across all 35 Modules):** Standardized Options Flare handshake and strict `OnEnable()`/`OnDisable()` lifecycle across all Player, Utility, Gathering, Professions, Social, Combat, and Class modules.
- [x] **Component 7 (TOC Audit, Technical Debt Cleanup & Lua 5.0.2 Verification):** `Modules\Combat\Range\Range.lua` restored to TOC, orphaned `AuctionHouse.lua` removed, and 100% pass on repository-wide Lua 5.0.2 static AST validation across all 68 files.
- [x] **Component 8 (Universal Flare Protocol & Table Identity Invariance):** Standardized module headers (`local PUI<Name> = Primus.PUI<Name> or {}`), eliminated top-level cross-module upvalues in Core (`Console.lua`, `Options.lua`, `Bootstrap.lua`), and achieved 100% Flare registration coverage across all 45 modules with zero upvalue/load-order bugs.

