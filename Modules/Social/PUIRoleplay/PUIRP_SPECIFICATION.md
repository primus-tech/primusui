# PUIRoleplay (PUIRP) — Next-Generation Roleplay Architecture Specification
**Target Platform:** OctoWoW / TurtleWoW Ecosystem (World of Warcraft 1.12.1 / Lua 5.0.2)  
**Host Framework:** PrimusUI Social Framework  
**Document Revision:** 2.0.0-COMPLETE (28-File Full Suite Implemented & Verified)  

---

## 1. Executive Summary & Vision

**PUIRoleplay (PUIRP)** is a fully realized, next-generation roleplaying suite engineered for the **OctoWoW** (1.12.1) client. It consolidates the distinct strengths of six major legacy and modern roleplaying addons into a single, cohesive, high-performance 28-file modular subsystem:

1. **Total RP 3 & MyRolePlay (MRP)**: Deep demographic granularity, psychological sliders, 5 at-a-glance slots, 4 profile slots (0..3), and companion/pet profiles.
2. **Modern Social Discovery / Matchmaking**: Dating-app-inspired directory (`PUIDirectory.lua`) with multi-tag filtering (Orientation, LGBTQIA+, 18+/Adult, ERP Boundaries, Romance Intent, Playstyle, Walkups) and 5-tab remote player flyout dossier (`PUIDirFlyout.lua`).
3. **Listener**: Proximity mention alerts, audio pings, dialogue focus, and proximity radar for busy taverns and events (`PUIListener.lua`).
4. **Emote Splitter**: Native long-form text chunking across all chat channels without truncation (`PUIEmotes.lua`).
5. **Elephant**: Persistent cross-session story archiving, scene bookmarking, and Markdown/Discord export (`PUIElephant.lua`).
6. **DiceMaster**: D20 combat engine, custom RP resources, status effects, and live typing indicators (`PUIDice.lua`).
7. **TRP3 Extended**: In-game readable letters, books, custom inventory items, and coordinate-based stashes (`PUIExtended.lua`).
8. **Universal Importer & Converter**: 1-click import from legacy addons (Total RP 2/3, MyRolePlay, FlagRSP) and single-byte string code backup (`PUIImporter.lua`).
9. **RP Quick Action Tray**: Sleek HUD tray for fast IC/OOC toggling, sheet, directory, dice, bag, letter, and walk/run switching (`PUITray.lua`).

```mermaid
graph TD
    subgraph Core Identity & Social
        A[Granular Character Sheet] --> B[Identity & Orientation Flags]
        B --> C[Matchmaking & Discovery Directory]
        A --> D[Companion & Pet Registry]
    end

    subgraph Chat & Interaction
        C --> E[Listener Focus & Radar]
        E --> F[Live Typing Indicator]
        F --> G[Native Emote Auto-Splitter]
    end

    subgraph World & Tabletop
        G --> H[DiceMaster D20 Engine]
        H --> I[Custom RP Items & Documents]
        G --> J[Elephant Story Logger]
        J --> K[Discord / Markdown Export]
    end
```

---

## 2. Character Profile & Demographic Architecture

The character sheet is upgraded to provide deep physical and narrative detail while maintaining zero clutter.

### 2.1 Identity & Nomenclature
* **Full Name Composition**: Dedicated fields for *Prefix / Title*, *First Name*, *Middle Name*, *Surname / Family Name*, *Nickname / Moniker*, and *House / Clan Affiliation*.
* **Display Format Customizer**: Allows selecting how names appear in tooltips, chat, and directory (e.g., `[Prefix] [First] [Last], [Title]` vs. `"[Nickname]" [First] [Last]`).

### 2.2 Physical Demographics & Origins
* **Age Structure**: Dual-tier age reporting:
  * *Apparent Age* (Visual presentation, e.g., "Late 20s").
  * *Actual Chronological Age* (True age, critical for Elves, Gnomes, Undead, and disguised beings).
* **Physical Metrics**: Eye Color, Height, Weight / Body Build, Complexion, and Notable Scars/Tattoos.
* **Geographical Lore**: Birthplace, Homeland / Nation, and Current Residence.
* **Current State & Mood**: Real-time emotional state (e.g., *Brooding*, *Exhausted*, *Euphoric*, *Alert*).

### 2.3 Psychological & Personality Sliders
Visual spectrum sliders allowing players to define core behavioral tendencies:
* `Chaotic` ◄──────────────────► `Lawful`
* `Cruel / Ruthless` ◄────────► `Merciful / Compassionate`
* `Pious / Devout` ◄──────────► `Pragmatic / Skeptical`
* `Cautious / Guarded` ◄──────► `Reckless / Impulsive`
* `Introverted / Stoic` ◄─────► `Extroverted / Flamboyant`

### 2.4 Extended At-A-Glance System (5 Slots)
Expanded from 3 to 5 slots, featuring categorized attribute badges:
* **Categories**: *Physical Trait*, *Distinctive Item*, *Visible Aura / Magic*, *Secret / Rumor*, *Combat Stance / Injury*.
* **Custom Attributes**: Per-glance icon selector, custom border tint, colored title, and markdown-friendly summary.

---

## 3. Adult, LGBTQIA+, & Orientation Flagging System

A structured, consent-forward tagging framework ensuring clear boundaries, player safety, and precise social discovery.

### 3.1 Content & Maturity Rating
1. **General (All Ages / PG-13)**: Standard fantasy adventure, casual banter, public tavern scenes.
2. **Mature Storytelling (18+ / Dark Lore)**: Heavy themes, graphic combat, dark magic, political horror, mature story arcs.
3. **Adult-Oriented / ERP (18+ Explicit)**: Explicit romance, erotic roleplay, private mature scenes.
* **Safety Protocols**: Global client-level toggle (*"Hide 18+ Content"*) with strict opt-in validation to ensure player protection.

### 3.2 LGBTQIA+ & Identity Tags
* **Community Flag**: Opt-in **LGBTQIA+ Friendly / Ally** badge displayed on profiles, glance pills, and tooltips.
* **Pronoun System**: Separate tracking for:
  * **IC Pronouns** (Character presentation, e.g., *She/Her*, *They/Them*, *He/Him*, *It/Its*).
  * **OOC Pronouns** (Player identity behind the screen).
* **Orientation / Sexuality Selector** (Optional / Opt-in):
  * *Heterosexual / Straight*
  * *Gay / Homosexual*
  * *Lesbian*
  * *Bisexual*
  * *Pansexual*
  * *Asexual / Demisexual*
  * *Queer / Questioning*
  * *Unspecified / Secret*

### 3.3 Relationship & Romance Intent
* **Relationship Status**: *Single*, *In a Relationship*, *Married*, *Betrothed*, *Widowed*, *Complicated*.
* **Romance Openness (IC)**:
  * *Actively Seeking Romance (IC)*
  * *Open to Natural Chemistry / Slow Burn*
  * *Platonic / Adventure Only*
  * *Closed / Taken*

---

## 4. Matchmaking & Social Discovery Engine (Directory 2.0)

Transforming the RP Directory into a modern discovery hub with dual browsing modes.

```
+---------------------------------------------------------------------------------------------------------+
| [🔍 Filter & Matchmaker Sidebar]   |  ROLEPLAY DIRECTORY: DISCOVERY FEED                                |
|-----------------------------------|---------------------------------------------------------------------|
| Presence:                         |  +---------------------------------------------------------------+  |
|  [x] In Character (IC)            |  | [Avatar] Lady Aurelia Sunstrider                              |  |
|  [ ] Looking for Contact (LFC)    |  | High Elf Mage-Scholar • Appears 25 (Real: 320) • She/Her      |  |
|  [ ] Storyteller / DM             |  | Tags: [🏳️‍🌈 LGBTQ+ Ally] [Pansexual] [18+ Mature] [Single]       |  |
|                                   |  | Romance: Open to Chemistry (IC) • Walkups: Highly Welcomed    |  |
| Identity & Orientation:           |  | Zone: Stormwind City (Mage Quarter) • Proximity: 15 yds       |  |
|  [x] LGBTQIA+ Friendly            |  | Hook: "Translating ancient Highborne astrological charts."    |  |
|  [x] Pan / Bi / Gay / Les         |  | [💬 Focus / Whisper]  [📖 View Profile]  [⭐ Bookmark]        |  |
|                                   |  +---------------------------------------------------------------+  |
| Maturity / Content:               |  +---------------------------------------------------------------+  |
|  [x] Adult / 18+ Allowed          |  | [Avatar] Grimnak Bloodfang                                    |  |
|  [ ] All Ages Only                |  | Orc Berserker • Appears 34 • He/Him                           |  |
|                                   |  | Tags: [Straight] [PG-13 Adventure] [Taken]                    |  |
| Romance Intent:                   |  | Romance: Platonic Only • Walkups: Ask OOC First               |  |
|  [x] Open to Romance (IC)         |  | Zone: Orgrimmar (Valley of Honor)                             |  |
|                                   |  | [💬 Focus / Whisper]  [📖 View Profile]  [⭐ Bookmark]        |  |
| Search Radius:                    |  +---------------------------------------------------------------+  |
|  [ Zone: Current (Elwynn) ▼ ]     |                                                                     |
+---------------------------------------------------------------------------------------------------------+
```

### 4.1 Browsing Modes
1. **Matchmaking Card Feed**: Large character cards showcasing avatar art, identity pills, compatibility flags, 1-line personality hooks, and quick-action buttons.
2. **Compact Tactical Grid**: Dense spreadsheet-style view sorted by Name, Zone, Distance, IC Status, or Last Spoke.

### 4.2 Compatibility Matrix & Filter Presets
* **Dynamic Match Badges**: Displays a subtle highlight if another player’s walkup openness, mature content settings, and romance intent align with your profile.
* **Quick Filter Tabs**:
  * *Near Me* (Proximity-based within current subzone).
  * *Dating & Romance* (Filtered for single/open characters matching orientation).
  * *Storytellers & DMs* (Filtered for campaign hosts and dungeon masters).
  * *Bookmarked / Favorites* (Quick access to regular roleplay partners).

---

## 5. Integrated Chat & Communication Suite

### 5.1 Listener Module (Proximity Radar & Dialogue Focus)
* **Smart Mention Engine**: Audio ping and visual screen pulse when your character’s first name, nickname, or full title is mentioned in `/say`, `/yell`, or `/emote`.
* **Dialogue Focus Dock**: A minimalist, semi-transparent HUD window that isolates chat between you, your target, and characters in your immediate 15-yard bubble.
* **Snooper Radar**: Sidebar list of nearby characters showing their IC status and a live counter indicating when they last spoke (e.g., *[Aurelia: 8s ago]*).

### 5.2 Native Emote Splitter
* **Zero-Truncation Posting**: Automatically monitors all outgoing chat messages. Messages exceeding the 255-character client limit are intelligently split at sentence and punctuation boundaries.
* **Sequenced Dispatch**: Posts are labeled with subtle pagination (e.g., `... [1/2]`) and dispatched via a burst-safe queue to prevent disconnections.

### 5.3 Live Typing Indicator (`...`)
* **Real-Time Composition Alert**: Transmits a lightweight channel signal when a player begins typing in an IC channel.
* **HUD & Nameplate Glow**: Displays an animated typing bubble above the player's head and on their Target Glance pill, eliminating accidental interruptions.

### 5.4 Custom Roleplay Tooltip Suite (TRP3-Style Mouseover)
Replaces the default Blizzard GameTooltip on player and companion mouseover with a rich, stylized, and fully configurable **Roleplay Tooltip**:

```
+-------------------------------------------------------------------------+
| [Avatar]  Lady Aurelia Sunstrider                                       |
|           Grand Magistrix of the Sunfury                                |
|           <House Sunstrider> [IC Guild]                                 |
|-------------------------------------------------------------------------|
| Status: [IC] In Character       |  RP Class: Highborne Arcane Scholar   |
| Race: High Elf                  |  Age: Appears 25 (Real: 320)          |
| IC Pronouns: She/Her            |  OOC Pronouns: She/They               |
|-------------------------------------------------------------------------|
| Tags: [🏳️‍🌈 LGBTQ+ Ally]  [Pansexual]  [18+ Mature]  [Single]            |
| RP Style: [Walkups Encouraged]  [Injury: By Consent]  [Romance: Open]   |
| Mood: "Studying ancient layline oscillations with intense focus."       |
|-------------------------------------------------------------------------|
| Glances: [🗡️ Runeblade]  [📜 Sealed Scroll]  [✨ Arcane Aura]  [👁️ Scar]   |
+-------------------------------------------------------------------------+
```

* **Custom Demographic Header**:
  * Character avatar icon embedded in the top-left corner.
  * Custom name and title text colored by class or custom roleplay palette.
  * IC vs. OOC Guild Affiliation tag (`<Guild Name> [IC]` or `<Guild Name> [OOC]`).
* **Identity & Status Badges**:
  * Real-time `[IC]`, `[OOC]`, `[LFC]` (Looking for Contact), or `[Storyteller / DM]` indicator.
  * Custom RP Class (e.g. *Blood Knight*, *Inquisitor*, *Apothecary*) overriding engine class.
  * Pronouns, Apparent Age, LGBTQIA+ Ally badge, and Orientation pills.
* **Current Mood & 5-Slot Glance Ribbon**:
  * 1-line real-time mood/action quote.
  * Visual row of 5 At-A-Glance icons rendered directly inside the tooltip frame.
* **Companion & Pet Tooltips**:
  * Mousing over hunter pets, warlock demons, mage elementals, or mounts displays their custom companion profile (Name, Breed, Master Name, and Physical traits).
* **Display & Anchoring Controls**:
  * Configurable tooltip anchoring (Cursor-anchored, Default GameTooltip anchor, or Fixed Smart Corner).
  * Toggle options for: Hide in Combat/Battlegrounds, Relative Level descriptor (*Formidable*, *Equal*), and Modifier Key preview (Hold `SHIFT` for full glance details).

---

## 6. Story Archiving, Tabletop & Item Systems

### 6.1 Elephant Story Logger (Persistent Roleplay Archives)
* **Session & Campaign Recording**: Automatically logs all `/say`, `/emote`, `/whisper`, and `/party` conversations into permanent SavedVariables.
* **Scene Tagging**: Built-in "Start Scene" / "End Scene" button to package specific events into named story logs.
* **Export Engine**: One-click **"Copy as Markdown / Discord Format"** to easily paste logs into character journals, wikis, or guild channels.

### 6.2 DiceMaster D20 Tabletop & Combat Engine
* **Custom RP Health & Resource Trackers**: Configurable health, stamina, and mana pools independent of in-game character stats.
* **Contextual D20 Roller**: One-click rolls with custom stat modifiers and narrative outcomes (e.g., `[D20 + 4 (Agility) = 19] Critical Success!`).
* **Custom Status Effects**: Apply and broadcast status icons (e.g., *Bleeding*, *Shielded*, *Poisoned*, *Unconscious*) visible on Target Glance pills.

### 6.3 TRP3 Extended Mechanics (Letters, Books & RP Inventory)
* **In-Game Letters & Books**: Create written documents with custom fonts, parchment backgrounds, and wax seals that can be handed to or traded with other players.
* **Custom RP Inventory**: Dedicated bag for unique roleplay items, trophies, and props.
* **Coordinate Stashes**: Plant inspectable clues or items at specific map coordinates for mystery events.

---

## 7. Network Architecture & OctoWoW Protocol

### 7.1 Protocol Structure
PUIRP implements a dual-layer communication system over the global `TTRP` channel:

```
[Standard TurtleRP Packet Layer]  --> Handles M, T, D packets & P/A pings (100% backward compatible)
[PUIRP Extended Metadata Layer]   --> Transmits X-packets for Orientation, Adult flags, Typing, & D20
```

1. **Standard Layer**: Ensures unmodified TurtleRP players can view name, title, description, and standard glances without errors.
2. **Extended Layer (`X:`)**: Broadcasts new identity tags, matchmaking metadata, typing states, and status effects to other PUIRP users.

### 7.2 Cross-Faction Discovery
Because the `TTRP` channel broadcasts globally across Alliance and Horde on OctoWoW, cross-faction profile inspection, directory searching, and map pins operate out-of-the-box with zero faction barriers.

### 7.3 DrunkCodec Multi-Byte & Encoding Normalization
To guarantee 100% interoperability across diverse client localizations (Vanilla 1.12.1 US/GB/DE/FR/RU) and TurtleRP versions:
- Standard ASCII serialization separator: `^` (caret) with fallback parsing for legacy `§` strings.
- Full multi-byte ANSI (`\167`, `\176`) and UTF-8 (`\194\167`, `\194\176`, `§`, `°`) decoding to fix missing "S" in zone names ("Stormwind City", "Stranglethorn Vale").
- Loop-safety guard in `SplitString` with a 2000-iteration hard stop.

---

## 8. Complete 28-File Modular Subsystem Manifest

The entire PUIRoleplay suite is constructed across 28 specialized, decoupled source files:

1. **`PUIConstants.lua`**: Data model, defaults, 4 profile slots (0..3), and Universal Nomenclature composition (`ComposeFullName`, `ComposeTitle`, `GetCleanDirectoryName`, `SanitizeZoneString`).
2. **`PUIIcons.lua`**: Indexed library of categorized WoW icons for profile avatars, glance pills, and custom RP items.
3. **`PUIProtocols.lua`**: Wire serialization, DrunkCodec encoding/decoding, packet packaging, and hardened `SplitString`.
4. **`PUIComms.lua`**: Multi-channel dispatcher, 30s background telemetry ping engine, live typing alerts, and packet ingestion.
5. **`PUIIconPicker.lua`**: Visual searchable icon browser modal with instant preview and category filtering.
6. **`PUICardPreview.lua`**: Real-time rendering card preview displayed alongside character profile editors.
7. **`PUIRPWidgets.lua`**: Glassmorphic widget factory for sliders, toggles, badge chips, and multi-line edit boxes.
8. **`PUIRPTabIdentity.lua`**: Identity tab controller (First/Middle/Last name, Prefix, Title, Epithet, House, Pronouns, IC/OOC).
9. **`PUIRPTabAppearance.lua`**: Appearance tab controller (Dual ages, Height, Weight, Build, Complexion, Scars, Bio).
10. **`PUIRPTabPersonality.lua`**: Personality tab controller (5 spectrum sliders: Lawful/Chaotic, Merciful/Cruel, etc.).
11. **`PUIRPTabLore.lua`**: Lore tab controller (Origins, Motto, Faction, and 6 History Chapters).
12. **`PUIRPTabRules.lua`**: Rules tab controller (RP Style, Injury/Death consent, ERP boundaries, 18+ Privacy toggles).
13. **`PUIRPTabMatchmaking.lua`**: Matchmaking tab controller (Social discovery tags, Romance intent, Walkup openness).
14. **`PUIRPTabSettings.lua`**: Settings tab controller (Profile slot switcher, Private GM notes, Export/Import triggers).
15. **`PUIRPSheet.lua`**: Master 7-tab Character Sheet window orchestrator and tab navigation engine.
16. **`PUIGlance.lua`**: Target At-A-Glance HUD pill with 5 customizable slots and `PUIMover` registration (`"PUIRPGlance"`).
17. **`PUITooltip.lua`**: Target mouseover tooltip metadata injection via `PUITooltip:RegisterUnitProvider`.
18. **`PUIDirFlyout.lua`**: 5-Tab Player Dossier Flyout Window for inspecting remote profiles with full tabs and glance ribbons.
19. **`PUIMapPins.lua`**: World Map RP Player Location Pins with cluster tooltips and zone filtering.
20. **`PUIDirectory.lua`**: Searchable Directory & Discovery Matrix with Card Feed / Tactical Grid modes and real-time filters.
21. **`PUIEmotes.lua`**: Long-Form Emote Auto-Splitter with sentence-boundary chunking over 255-character limit.
22. **`PUIListener.lua`**: Proximity Mention Radar & Focus Tracker with audio pings and proximity bubble.
23. **`PUIElephant.lua`**: Story & Scene Archiver with Markdown / Discord export.
24. **`PUIDice.lua`**: DiceMaster D20 Tabletop & Combat Engine with custom RP stats, resource bars, modifiers, and rolls.
25. **`PUIExtended.lua`**: RP Inventory Pouch & Document/Letter Forge with parchment styling and wax seals.
26. **`PUIImporter.lua`**: Multi-Addon Importer (TRP2, TRP3, MRP, FlagRSP) and single-byte string code backup.
27. **`PUITray.lua`**: RP Quick Action Bar & Immersion Toggle with IC/OOC toggle, Sheet, Directory, Dice, Bag, Letter, and Walk/Run.
28. **`PUIRoleplay.lua`**: Master Coordinator, Options Flare handshake, and slash command router (`/rp`, `/ttrp`, `/pui rp`).

---

## 9. Development Status & Milestone Verification

All 5 core development milestones are **100% Implemented, Verified, and Operational**:

- [x] **Milestone 1: Universal Bootstrap & Granular Demographics (COMPLETE)**
  - Schema expanded with Prefix, Title, Epithet, House, Dual Ages, Physical Demographics, and 5 Personality Sliders.
  - Adult/18+, ERP Boundaries, LGBTQIA+, and orientation tagging with client privacy validation.
  - 5-Slot Categorized At-A-Glance System with custom icons and border tints.
- [x] **Milestone 2: Discovery Engine & Directory 2.0 (COMPLETE)**
  - Dating/Matchmaking Card Feed with real-time tag filters.
  - Compact Tactical Grid view with proximity sorting and bookmarking.
  - 5-Tab Player Dossier Flyout Window (`PUIDirFlyout.lua`) and World Map RP Pins (`PUIMapPins.lua`).
  - Options Flare integration in `/pui config` and `/pui rp`.
- [x] **Milestone 3: Real-Time Chat & Social Suite (COMPLETE)**
  - **Listener** Dialogue Focus HUD and proximity mention alerts with audio pings.
  - Zero-truncation **Emote Auto-Splitter** with sentence-aware chunking.
  - Channel-based **Live Typing Indicator** (`...`) with glance pill animations.
- [x] **Milestone 4: Story Archiving, Tabletop & World RP (COMPLETE)**
  - **Elephant** persistent chat logger with scene bookmarking and Markdown/Discord export.
  - **DiceMaster** D20 dice engine, RP health/resource bars, and custom status buffs.
  - **TRP3 Extended** custom letter/book editor, wax seal renderer, and RP inventory pouch.
- [x] **Milestone 5: Importer & Hardening QA (COMPLETE)**
  - **PUIImporter** supporting 1-click import from Total RP 2/3, MyRolePlay, FlagRSP, and character string codes.
  - DrunkCodec multi-byte fixes, loop-safe `SplitString` (2000-iteration hard stop), and cycle-safe `Utils.DeepCopy`.

---
*End of Specification Document.*

