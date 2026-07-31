# Changelog

All notable changes to EZOArmory are documented here.

## 0.8.7

- Fix: the 0.8.5 armor-weight hover text did nothing for kits that had no
  armorType stored on the piece (typically kits captured before the addon
  started saving that field) - it just silently fell back to repeating the
  set name with no new information, which read as a broken/pointless
  tooltip. Now, if the captured piece has no usable armor weight, EZOArmory
  tries to read it live from the exact item if it can still be located in
  your bags, and only if that also fails does it say "unknown weight"
  explicitly instead of showing nothing extra at all.
- The weight is now only ever appended for armor slots (head, shoulders,
  chest, waist, hands, legs, feet) - jewelry and weapon pieces never had a
  weight to show in the first place, so they no longer risk a stray
  "(unknown weight)".

## 0.8.6

- Add: the Equip button in the window now works for Skill and CP kits too,
  not just Gear. Skill kits slot both bars via
  ACTION_BAR_ASSIGNMENT_MANAGER:AssignSkillToSlotByAbilityId (not a protected
  function, but out of combat only, and skipped per-ability if it is not
  unlocked on this character). CP kits slot stars via
  PrepareChampionPurchaseRequest/AddHotbarSlotToChampionPurchaseRequest/
  SendChampionPurchaseRequest, tracking the game's real ~30s cooldown
  (EVENT_CHAMPION_PURCHASE_RESULT) so a kit requested during cooldown queues
  and applies automatically once it clears. Both only touch slots that
  actually differ from what is already slotted, same idempotent-apply
  principle as gear (critical for CP given the cooldown). Both patterns
  verified against Wizard's Wardrobe's WW.SlotSkill/WW.LoadCP in production
  and against the native skill/champion managers in the ESOUI source.

## 0.8.5

- Fix: two Gear kits for the same set and slot (e.g. a light and a medium
  Slimecraw head) were indistinguishable in the window, since the icon is
  identical and armor weight was shown nowhere. The row's name-hover summary
  now appends the piece's armor weight (light/medium/heavy) next to its set
  or item name, and hovering an individual gear icon shows the same weight
  even when the exact item is no longer in your bags (bank, other
  character...) - previously that case just showed a generic "not available"
  with no identifying info at all.
- Promoted ArmorTypeLabel from the LAM panel into a shared EZOArmory.*
  function (same pattern as RoleLabel in 0.8.4), since the window now needs
  the same light/medium/heavy label the LAM panel already had.

## 0.8.4

- Add: new "Assign" tab in the dedicated window, moving trial/boss kit
  assignment out of the (now frozen) LAM settings panel. Pick a trial and a
  target (trial default, trash, or a specific boss), see which Gear kits are
  assigned there for your active role, add or remove kits, clear the target,
  and equip either that target's kits or whatever applies to your current
  location - all without touching Settings. Skill and CP kits are still not
  assignable per target (only equippable standalone); that stays on the
  roadmap.
- Native dropdowns for trial/target/kit pickers, built at runtime with
  WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox") +
  ZO_ComboBox_ObjectFromContainer (pattern verified against LibScrollableMenu
  and BanditsUserInterface, since this addon builds its window UI in pure
  Lua with no XML of its own).
- Promoted role detection (IsRoleAuto/GetActiveRole) and role display
  (RoleLabel) from the LAM panel into shared EZOArmory.* functions, since the
  new Assign tab needed the exact same active-role logic the LAM panel
  already had; both now call the same code instead of duplicating it.

## 0.8.3

- Add: rename button for the selected kit in any of the three window tabs
  (Gear/Skills/CP), using a native text-entry dialog.
- Fix: after visiting the Gear tab, switching to Skills or CP could leave the
  kit name floating on top of the ability icons or CP star chips instead of
  sitting above them as a header line. Kit rows are pooled and reused across
  tabs, and only the Gear layout re-anchors the name label (to sit vertically
  centered next to its icons); that anchor was never reset when the same row
  got reused for a different category. Row cleanup now always restores the
  default top-anchored name position before each fill.

## 0.8.2

- Gear kit rows are back to a single compact line (icons and name side by
  side), instead of the name-above-icons layout 0.8.0 introduced for visual
  consistency with skill/CP rows. Gear does not need the extra line skill kits
  do (two full bars) or CP kits do (variable star lines), so the earlier
  compact layout reads better and wastes far less vertical space in the list.

## 0.8.1

- Fix: CP stars grouped incorrectly (stars from different disciplines mixed
  into the same coloured line). The cause was using GetChampionSkillType,
  which returns whether a star is passive or slottable, not its discipline -
  there is no direct "star to discipline" API. Champion.GetStarDisciplineType
  now builds the correct mapping once by walking every discipline and its
  stars (GetNumChampionDisciplines / GetChampionDisciplineId /
  GetChampionDisciplineType / GetNumChampionDisciplineSkills /
  GetChampionSkillId), the same way the game's own champion data manager does
  it, and caches the result.
- Skill kit icons (weapon and abilities) are noticeably larger (36px, up from
  24-28) so both bars read clearly at a glance. Fixed a related bug where the
  back bar's vertical position was computed from the smaller gear icon size
  instead of the skill icon size, which would have made it overlap the front
  bar once the icons grew.

## 0.8.0

- Skill kit rows now show both action bars graphically, weapon plus five
  abilities plus ultimate each, exactly like the native action bar. Every
  ability icon has its own real tooltip (AbilityTooltip), same as hovering an
  ability in your own bar.
- CP kit rows now show every Champion star as its own text "chip", grouped by
  discipline (each tree starts on its own line, flowing to further lines if it
  does not fit) and coloured in that discipline's official colour
  (ZO_CP_BAR_GLOW_COLORS, the same table the native Champion Points screen
  uses). Hovering an individual star shows its real ChampionSkillTooltip.
- Row height is now calculated per row instead of fixed, since a skill kit
  needs two lines of icons and a CP kit needs as many lines as its stars
  require to fit - rows no longer waste space or risk overlapping.
- Gear kit rows moved the name above the icons (previously beside them), to
  keep the three categories visually consistent.

## 0.7.3

- Fix: hovering a skill kit's weapon icon showed the weapon's item tooltip
  (set, trait...), which is not the point of a skill kit. It now shows that
  bar's abilities instead, matching what hovering the kit name already showed.
- CP kit hover now groups the Champion stars by discipline (Warfare, Fitness,
  Craft), each line colored in that discipline's official colour (the same
  ZO_CP_BAR_GLOW_COLORS used by the native Champion Points screen), instead of
  one flat list.

## 0.7.2

- Fix: kit rows were truncated to a handful of characters even for short names
  ("Slimecraw..." instead of "Slimecraw - Head (1)"). The row width was
  anchored to the scroll's ScrollChild, whose own width auto-fits to its
  children per ZOS's official template (resizeToFitDescendents) rather than
  stretching to the scroll area - anchoring the row's width to it created a
  circular dependency that collapsed to the content's minimum width. Rows now
  anchor their width to the scroll container itself, which has a real,
  deterministic width.
- Skill and CP kits now show a content preview directly in the row text (the
  abilities on each bar, or the Champion stars), not only on hover, since they
  have little or no icon to identify them by at a glance.

## 0.7.1

- Fix: kit row names with no fixed height or single-line mode would word-wrap
  and overflow into the row below, since rows sit at fixed positions rather
  than a chained layout. A long name overlapped the next row's icons and text,
  making the list look scrambled. Names now use a fixed row height and
  single-line ellipsis truncation, matching the standard ESO list-row pattern.

## 0.7.0

- The window now has real content: three category tabs (Gear kits, Skill kits,
  CP kits) with a scrollable list. Replaces the placeholder text.
- Real hover tooltips, not the LAM text-markup workaround: hovering a gear
  piece's icon shows the actual native item tooltip (resolved live from your
  bags, so it reflects the item's current state), and hovering a kit's name
  shows a composed summary (every piece, both skill bars with their weapon, or
  every Champion star).
- Click a row to select it; Equip and Delete buttons appear for the selection
  (Equip only for gear kits, reusing the existing equip engine).
- Champion Point star icons are not shown per star: no verified ESO API for a
  per-star icon texture was found, so CP kit rows are text-only with the
  hover summary. Ability icons per skill slot (beyond the weapon icons already
  shown) are left for a later pass if useful.

## 0.6.2

- Fix: the "EZOArmory" keybind category never appeared in Controls. The action
  name `EZOARMORY_TOGGLE_WINDOW` needs a matching global string
  `SI_BINDING_NAME_EZOARMORY_TOGGLE_WINDOW` registered by the addon (the same
  way `Open Command Panel` is registered for EZOTools) for the client to render
  its keybind row; `Bindings.xml` alone declaring the action is not enough. That
  string, plus the category color string, now live in the localization tables
  and are applied through the normal language init, matching the family
  pattern exactly.

## 0.6.1

- Fix: the window could not be dragged. It toggled the window's movable flag on
  every mouse-down/mouse-up instead of leaving it permanently movable, unlike
  the pattern ZOS itself uses for a child control dragging its parent
  (`performancemeter.xml`: `movable="true"` set once, the child only calls
  `StartMoving`/`StopMovingOrResizing` on the parent). The window is now
  movable from creation and the header just starts/stops the drag.

## 0.6.0

- EZOArmory now has its own window, opened with a keybind (bind "Open EZOArmory"
  under Controls) or with `/ezoarmory`. It is movable by its header, remembers
  its position, and shows the trial and boss you are in, live.
- This is the frame the interface will be built on: kit lists, the twelve-slot
  grid with coherence colours, per-boss assignments for gear, skill and CP kits,
  and hover tooltips. The settings panel keeps working as before meanwhile.
- The window follows the family HUD rule (visible only in the hud and hudui
  scenes) and is deliberately not registered with `family.layout`, which is for
  free-position HUD surfaces rather than management windows.

## 0.5.1

- Automatic names for single armour pieces now include the armour weight, so a
  light and a medium head of the same set become "Slimecraw - Head (light)" and
  "Slimecraw - Head (medium)" instead of a numbered pair. The weight also shows
  in the capture selector, and pieces now store their armour type for the
  upcoming window tooltips.

## 0.5.0

- Skill kits: capture both action bars (five abilities plus ultimate each) into
  their own kit space, separate from gear kits. Each skill kit stores the
  weapons you were holding, shown as front/back bar icons in the list, since
  abilities depend on the weapon type. Optional name; unnamed captures become
  Skills 1, Skills 2...
- Champion Point kits: capture the twelve slotted Champion stars, with optional
  or automatic naming (CP 1, CP 2...). Two captures with the same stars in a
  different order count as the same kit.
- "Capture everything worn as kits" now also captures the current skill bars and
  Champion stars, each into its own section.
- Deduplication by real content applies to all three kinds: identical gear,
  identical bars or identical stars are skipped and reported, never duplicated.

## 0.4.2

- New "Equip this target's kits" button: equips the build assigned to the trial
  and target selected in the panel, wherever you are. "Equip for my current
  location" only works inside a trial (it reads where you actually are), which
  made it look broken when pressed elsewhere.
- Together with EZOCore 0.1.20, the settings panel no longer jumps back to the
  top when adding or removing kits: the scroll position is preserved across the
  forced rebuild.

## 0.4.1

- Capturing no longer creates duplicate kits. A capture is compared against
  existing kits by real content — the exact item instances in the exact slots —
  and if an identical kit exists nothing is created: single capture tells you
  which kit already holds those pieces (and selects it), and capture-everything
  counts it as skipped. Kits with the same name but genuinely different pieces
  are still allowed and numbered.

## 0.4.0

- Automatic role detection: the active profile (damage, tank or healer) now
  follows the role selected in the game's group finder, so each role keeps its
  own assignment space without manual switching. A checkbox turns this off to
  pick the role by hand.
- Assignments reworked to the sketched layout: the section now has its own kit
  selector (with the piece icons), Add/Remove buttons next to it, and the kits
  assigned to the target listed below, one per line with their icons, so you can
  see what each kit contributes. Kits already assigned to the current target are
  marked with a green + in the selector, since dropdown entries cannot be
  disabled individually in LibAddonMenu.

## 0.3.2

- Fix: adding a kit to a target did nothing visible. The panel options were
  registered as a pre-built table, so build-time content (the "Kits assigned
  here" summary) was frozen and never refreshed; the assignment was saved but
  not shown. The options are now registered as a function that EZOCore re-runs on
  each rebuild, so the summary and the other dynamic content update live.

## 0.3.1

- Fix: a target can now hold more than one kit. The multi-select list only let
  one through, so assigning is now done by picking a kit in Saved kits and using
  Add / Remove buttons, with the current kits shown under the target. Clear
  empties the target so it inherits the trial default again.

## 0.3.0

- Assignments: for the active role, assign kits to each trial and target — the
  trial default, Trash, and every boss or miniboss independently. A target can
  hold one kit with everything or several kits, none are mandatory, and a target
  with nothing of its own inherits the trial default. Kits are picked with a
  multi-select list.
- "Equip for my current location" reads where you are (trial and boss from the
  live context) and equips the assigned build for that spot, or the trash build,
  waiting until out of combat.
- The trial catalogue stays self-contained; EZOTools' catalogue is trial-level
  only (no bosses) and cross-addon reuse is avoided by family policy.

## 0.2.0

- First equipping support (Phase 2): "Equip selected kit" puts on the pieces of
  the selected kit. The addon now acts, not just analyses.
- Gear can only be changed out of combat, so if you are fighting the equip is
  queued and applied the moment combat ends (via LibAsync). Pieces are located in
  worn gear and backpack; anything in the bank is reported as missing, since
  moving from the bank needs direct player interaction.
- Reports what was equipped, what was already on, and what could not be found.
- LibAsync added as an optional add-on; equipping is disabled with a clear
  message if it is not installed, while the rest of the addon keeps working.

## 0.1.10

- Kit and capture icons now use each item's real, full-colour inventory icon
  instead of the grey slot silhouettes. The silhouette textures cannot be
  brightened (colour markup only multiplies), so they always looked dim; item
  icons are naturally bright and also identify the piece.

## 0.1.9

- Slot icons are now drawn white so they stand out, instead of inheriting the
  dimmed dropdown text colour.
- "Capture everything worn as kits" now also captures loose pieces (mythics,
  setless weapons, a single piece of a set), not only multi-piece sets. Single
  pieces are named with their exact slot, for example "Slimecraw - Head".

## 0.1.8

- Fix: the slot icons did not render. Inline texture markup needs the path
  without a leading slash, the same form the header help icon already used.
- Icons now lead the label instead of trailing it, so they survive the text
  truncation LibAddonMenu applies to long entries.

## 0.1.7

- Kits and capture options now show the native ESO icons of the slots they
  occupy, so a body kit and a jewelry-and-weapons kit of the same set are told
  apart at a glance.
- Kits captured in bulk are named after the set's key word plus where it sits
  ("Null Arca - armour"), keeping two kits of the same set distinct. Repeated
  names are numbered instead of skipped, so no capture is lost silently.
- The capture list no longer repeats the individual pieces of a set that is
  already offered whole. Only genuinely loose items are listed: mythics, weapons
  with no set, and sets you are wearing a single piece of.

## 0.1.6

- The capture selector now shows where each option's pieces are: a compact
  category hint for sets (for example "armour" or "jewelry + weapons") and the
  exact slot for individual pieces, which also tells the two rings apart.
- New "Capture every worn set as a kit" button: creates one kit per set you are
  wearing in a single step, each named after the set's key word (for example
  "Null Arca" from "Perfected Slivers of the Null Arca"), keeping the full set
  name inside the kit. Sets that already have a kit with that name are skipped.

## 0.1.5

- The "Pieces to capture" selector is now built from the gear you are wearing:
  "everything equipped", each worn set with its piece count and name (for example
  "Perfected Slivers of the Null Arca (5)"), and every individual piece by name so
  you can capture a single loose piece. Replaces the previous fixed slot presets.

## 0.1.4

- Fix: the saved-kit dropdown now updates as soon as a kit is created or deleted.
  Under EZOCore the settings controls are renamed, so the previous in-place
  refresh silently did nothing; it now refreshes in place when running without
  EZOCore and forces a panel rebuild through the family.settings service when
  running under it.
- Settings sections are now flat (headings instead of collapsible submenus) so a
  panel rebuild no longer closes the section you are working in.

## 0.1.3

- Fix: the "New kit name" field was still a tiny box. Inside a submenu LibAddonMenu
  computes the editbox width from the parent width, which is zero at build time,
  so the box collapsed. Setting isExtraWide makes it fill the row regardless.

## 0.1.2

- Fix attempt: gave the "New kit name" field a full width (insufficient on its
  own; see 0.1.3).

## 0.1.1

- Kit management in the settings panel: pick the active role, name a kit, choose
  which equipped slots to capture (body five, head and shoulders, full armour,
  jewelry, jewelry with front weapons, either weapon bar, or everything) and
  create it from the gear you are wearing. Saved kits can be listed, inspected
  and deleted.
- New **Analyse current gear** action reporting which set bonuses are actually
  active on each weapon bar, so a set left incomplete on the back bar becomes
  visible.
- Design settled (see `docs/concept.md`): kits hold concrete items, gear is
  swapped automatically or manually per trial, three role profiles per character
  and a phased UI.
- Data model reworked around concrete pieces: kits keyed by slot with stable
  item identity, role profiles, and per-trial assignments with inheritance from
  a trial default to trash and individual bosses.
- Coherence engine now validates **per weapon bar** (12 active pieces), handling
  two-handed weapons as two pieces, and adds duplicated-item, multiple-mythic and
  availability checks.
- Gear scanner reports stable item ids and can locate pieces across worn and
  backpack bags.

## 0.1.0

Initial scaffold.

- Addon skeleton for the EZO family: manifest, versioning tool, bilingual
  localization (EN/ES), optional LibDebugLogger diagnostics, SavedVariables and
  a LibAddonMenu settings panel with the shared EZO purple info headers.
- Trial and boss reference data for all 14 trials (`modules/zones_trials.lua`),
  keyed by zone id with ordered boss lists.
- EZOCore integration: addon registration, settings-panel registration with LAM
  fallback, language-preference consumer and debug controller. Works standalone
  when EZOCore is absent.
