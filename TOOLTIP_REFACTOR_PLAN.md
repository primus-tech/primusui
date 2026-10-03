# Implementation Plan: PUITooltip Universal Architecture & Single-Owner Refactor

> **Target Platform:** World of Warcraft: Vanilla 1.12.1 (Client Build 5875 | Interface `11200` | Lua 5.0.2)  
> **Repository:** `Interface/AddOns/PrimusUI`  
> **Module Target:** `Modules/Utility/PUITooltip/`  
> **Compliance:** Strict `TRUTH.md` Axioms (Zero Aliasing, Zero Shims, Single-Owner Model, Canonical `PUI<Name>`)

---

## User Review Required

> [!IMPORTANT]
> **Single Resource Ownership Enforcement:**
> Under this refactor, `PUITooltip` becomes the **sole owner** of all Blizzard tooltip hooks (`GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1/2`, `GameTooltipStatusBar`). All raw hooking code in `PUISellValue`, `PUIMerchant`, `PUIRoleplay`, and `PUIItemCompare` will be extracted and replaced with clean provider registrations:
> - `PUITooltip:RegisterUnitProvider(id, priority, callback)`
> - `PUITooltip:RegisterItemProvider(id, priority, callback)`
> - `PUITooltip:RegisterSpellProvider(id, priority, callback)`

> [!NOTE]
> **Zero-Allocation Background Scanner Pool:**
> `PUITooltip` provides a single, high-performance recycled scan tooltip (`Primus_PUITooltip_ScanTooltip`), allowing `PUIItemStats`, `Utils.lua`, and `PUICharacterSheet` to scan item links, bags, and durability without instantiating redundant tooltip frames or allocating temporary tables.

---

## Proposed Changes

### Component 1: Core `PUITooltip` Suite (`Modules/Utility/PUITooltip/`)

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipConstants.lua`
- Declare `Primus.PUITooltip = Primus.PUITooltip or {}`.
- Define database defaults:
  ```lua
  local defaultSettings = {
      anchorMode = "SMART_CORNER", -- "SMART_CORNER", "CURSOR", "MOVER"
      itemQualityBorders = true,
      showHealthBar = true,
      showTargetOfTarget = true,
      showGuildRank = true,
      hideInCombat = false,
      hideInBattlegrounds = false,
  }
  ```
- Define quality color hex codes (`0` Poor through `6` Artifact), reaction colors, power colors, and anchor presets.

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipSkin.lua`
- Implement `Skin:ApplyBackdrop(tooltip)` using `Primus.Media:Fetch("border", "1Pixel")` with RGBA `(0.05, 0.05, 0.07, 0.95)` and border `(0.25, 0.25, 0.30, 1.0)`.
- Implement `Skin:SetQualityBorder(tooltip, quality)` to color tooltip edges according to item rarity.
- Implement `Skin:StyleStatusBar(statusBar)` to apply flat status bar texture, 1px border, reaction/class coloring, and centered health text (`HP / MaxHP (Percentage%)`).
- Apply skinning to `GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1`, `ShoppingTooltip2`, and `WorldMapTooltip`.

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipAnchor.lua`
- Create draggable mover anchor frame `Primus_PUITooltip_Anchor`.
- Register with `PUIMover` category `"Utility"`.
- Hook `GameTooltip_SetDefaultAnchor(tooltip, parent)`:
  - If `anchorMode == "CURSOR"`: calls `tooltip:SetOwner(parent, "ANCHOR_CURSOR")`.
  - If `anchorMode == "MOVER"`: anchors tooltip directly to `Primus_PUITooltip_Anchor`.
  - If `anchorMode == "SMART_CORNER"`: anchors to bottom-right of screen, dynamically flipping vertically if near screen edges.

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipUnit.lua`
- Hook `OnTooltipSetUnit` / `SetUnit`:
  - **Player Formatting:** Class-colored name, level difficulty color, race, class, guild line (`<Guild Name>` white + rank in gray), Target-of-Target (`Targeting: [Unit]`), PvP flag, AFK/DND tags.
  - **NPC Formatting:** Reaction-colored name (Hostile red, Neutral yellow, Friendly green, Tapped gray), level, classification (`Elite`, `Boss`, `Rare`).
  - **Health Bar:** Updates `GameTooltipStatusBar` with numeric text and reaction/class color.
- Iterate and dispatch unit context to all registered Unit Providers (`unitProviders` sorted by priority).

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipItem.lua`
- Centralize master hooks for all item and spell setter methods on `GameTooltip` and `ItemRefTooltip`:
  - `SetBagItem`, `SetInventoryItem`, `SetHyperlink`, `SetAction`, `SetCraftItem`, `SetTradeSkillItem`, `SetLootItem`, `SetQuestItem`, `SetQuestLogItem`, `SetInboxItem`, `SetSendMailItem`, `SetAuctionItem`, `SetMerchantItem`, `SetBuybackItem`.
- Extract item metadata (`itemID`, `link`, `count`, `quality`, `bag`, `slot`).
- Apply quality border color.
- Sequentially execute registered Item Providers (`itemProviders` sorted by priority), allowing providers to append custom lines (`AddLine`, `AddDoubleLine`).

#### [NEW] `Modules/Utility/PUITooltip/PUITooltipScanner.lua`
- Create recycled, zero-allocation background scanner `Primus_PUITooltip_ScanTooltip`.
- Expose methods:
  - `PUITooltip:ScanBagItem(bag, slot)`
  - `PUITooltip:ScanInventoryItem(unit, slot)`
  - `PUITooltip:ScanHyperlink(link)`
- Returns parsed left/right text lines without string garbage churn.

#### [NEW] `Modules/Utility/PUITooltip/PUITooltip.lua`
- Coordinate master module lifecycle (`OnInitialize`, `OnEnable`, `OnDisable`).
- Announce to Core: `Primus:RegisterModule("PUITooltip", PUITooltip, "Utility")`.
- Expose Public Provider & Drawing API:
  - `PUITooltip:RegisterUnitProvider(id, priority, callback)`
  - `PUITooltip:RegisterItemProvider(id, priority, callback)`
  - `PUITooltip:RegisterSpellProvider(id, priority, callback)`
  - `PUITooltip:AddLine(tooltip, text, r, g, b, wrap)`
  - `PUITooltip:AddDoubleLine(tooltip, leftText, rightText, lr, lg, lb, rr, rg, rb)`
  - `PUITooltip:SetQualityBorder(tooltip, quality)`
- Register Flare Options under `Utility -> Tooltips` in `/pui options`.

---

### Component 2: Provider Migrations & De-duplication

#### [MODIFY] [PrimusUI.toc](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/PrimusUI.toc)
- Add the `PUITooltip` file suite under `## Utility Modules`:
  ```toc
  Modules\Utility\PUITooltip\PUITooltipConstants.lua
  Modules\Utility\PUITooltip\PUITooltipSkin.lua
  Modules\Utility\PUITooltip\PUITooltipAnchor.lua
  Modules\Utility\PUITooltip\PUITooltipUnit.lua
  Modules\Utility\PUITooltip\PUITooltipItem.lua
  Modules\Utility\PUITooltip\PUITooltipScanner.lua
  Modules\Utility\PUITooltip\PUITooltip.lua
  ```

#### [MODIFY] [PUISellValue.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/PUISellValue/PUISellValue.lua)
- Remove all raw `GameTooltip` method hooks (`SetBagItem`, `SetInventoryItem`, `SetHyperlink`, etc.).
- Register with `PUITooltip` as an Item Provider in `PUISellValue:OnEnable()`:
  ```lua
  local PUITooltip = Primus.PUITooltip
  if PUITooltip and PUITooltip.RegisterItemProvider then
      PUITooltip:RegisterItemProvider("PUISellValue", 10, function(tt, data)
          PUISellValue:OnTooltipProcess(tt, data)
      end)
  end
  ```

#### [MODIFY] [PUIMerchant.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/PUIMerchant/PUIMerchant.lua)
- Remove all raw `GameTooltip` hooks for market price injection.
- Register as an Item Provider:
  ```lua
  local PUITooltip = Primus.PUITooltip
  if PUITooltip and PUITooltip.RegisterItemProvider then
      PUITooltip:RegisterItemProvider("PUIMerchant", 20, function(tt, data)
          PUIMerchant:OnTooltipProcess(tt, data)
      end)
  end
  ```

#### [MODIFY] [PUITooltip.lua (in PUIRoleplay)](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Social/PUIRoleplay/PUITooltip.lua)
- Remove raw `GameTooltip` hooks and `UPDATE_MOUSEOVER_UNIT` handlers.
- Refactor into a Unit Provider:
  ```lua
  local PUITooltip = Primus.PUITooltip
  if PUITooltip and PUITooltip.RegisterUnitProvider then
      PUITooltip:RegisterUnitProvider("PUIRoleplay", 1, function(tt, unit, name, isPlayer)
          PUIRoleplay.Tooltip:EnhanceUnitTooltip(tt, unit, name, isPlayer)
      end)
  end
  ```

#### [MODIFY] [PUIItemCompare.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Utility/PUIItemCompare/PUIItemCompare.lua)
- Remove raw `GameTooltip` show/hide hooks.
- Delegate side-by-side comparison anchoring and display to `PUITooltip:RegisterItemProvider("PUIItemCompare", 30, ...)`.

#### [MODIFY] [PUIItemStats.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Modules/Player/PUIItemStats/PUIItemStats.lua) and [Utils.lua](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/Utils/Utils.lua)
- Deprecate local `scanTooltip` creations in favor of `Primus.PUITooltip:ScanBagItem()` and `Primus.PUITooltip:ScanHyperlink()`.

---

## Verification Plan

### Automated / Syntax & Load Tests
1. Verify TOC order and module registration in `PrimusUI.toc`.
2. Check for zero runtime Lua syntax errors under Lua 5.0.2 constraints.

### Manual In-Game Functional Verification
1. **Skinning Verification:**
   - Hover over items in bags, inventory, spellbook, and chat hyperlinks.
   - Verify 1-pixel dark borders and item quality border colors (e.g. epic purple for epics, uncommon green for greens).
2. **Unit Mouseover Verification:**
   - Hover over friendly players, hostile players, friendly NPCs, and enemy mobs.
   - Verify class-colored names, level difficulty colors, guild + rank, Target-of-Target line, and health status bar.
3. **Provider Integration Verification:**
   - **PUIRoleplay:** Hover over an RP character & verify RP name, title, IC/OOC badge, and glances render.
   - **PUISellValue:** Hover over vendor-sellable items & verify price footers render without clipping.
   - **PUIMerchant:** Hover over auctionable items & verify AH market value lines render cleanly below vendor sell price.
   - **PUIItemCompare:** Hold `Shift` while hovering over gear & verify shopping tooltips appear side-by-side with dark skinning.
4. **Anchoring Verification:**
   - Change anchor mode in `/pui options` between `SMART_CORNER`, `CURSOR`, and `MOVER`.
   - Open `/pui move` and verify `Primus_PUITooltip_Anchor` drags and persists its position.
