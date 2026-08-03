# Changelog

All notable changes to EZOArmory are documented here.

## 0.11.13

- Fix: the window did not reliably remember its position. Saving it only
  happened from the header's OnMouseUp, which requires the cursor to still be
  over the header at release - easy to miss on a fast drag. It now also saves
  from the window's own native OnMoveStop event, which fires whenever a drag
  ends regardless of where the cursor is (same verified pattern as EZOChat).
  Also fixed a related bug: the saved defaults had x/y pre-set to 0, which
  looks like "a saved position of the top-left corner" rather than "never
  moved", so a fresh profile always spawned there instead of centred.
- Add: **"Restore default settings"** button in the LAM panel, with a
  confirmation dialog. Resets language, role mode, the inventory marker,
  auto-equip and the window's position/size back to their defaults. Does not
  touch kits, builds or assignments - this is for when settings get into a
  bad state or the window wanders off-screen, not for clearing your library.
- **Major LAM cleanup.** Removed everything the window now covers on its own:
  capturing/listing/equipping/renaming/deleting gear, skill and CP kits, and
  the old kit-based trial/boss assignment screen (superseded by the Assign
  tab's build-based one, with inheritance, substitutes and auto-equip). LAM
  keeps only what has no window equivalent: language, the inventory marker,
  debug mode, role mode, a live analysis of gear currently worn, and the new
  reset button. Also removed 64 language keys that were now unused in both
  languages, keeping en/es in exact parity.

## 0.11.12

- Add: a clear, prominent **"Auto-equip"** master switch at the top of the
  Assign tab, above the trial/target/build pickers. It governs all automatic
  equipping - both the build explicitly assigned to wherever you are and the
  substitute (trash/boss) builds below - not just the substitutes. Previously
  this was one small checkbox labelled "Enable" buried inside the "Substitute
  builds" block, which made it look like it only toggled the fallback feature
  rather than automatic equipping as a whole.
- The substitute block below it now only holds the per-zone-type scope
  (Trials/Dungeons/Overland); the master switch replaces its old "Enable"
  checkbox, so there is exactly one place that turns automatic equipping on or
  off.

## 0.11.11

- Confirmed fixed: hover tooltips now work in every scrollable list. Applied
  the same scroll-wheel-area fix from 0.11.10 to the Builds tab too, since it
  is the identical ZOS control and would hit the same problem once a build
  list grows long enough to need scrolling, even though it happened to work
  with the shorter list already tested.
- Removed the diagnostic logging added in 0.11.9/0.11.10 (control geometry
  dumps, per-hover log lines) now that it has done its job. The defensive
  pcall guard around the item tooltip call from 0.11.6 stays, since a raised
  error there could still silently kill the whole hover handler.

## 0.11.10

- Experimental fix for the Gear/Skill/CP kit list still not showing hover
  tooltips despite the geometry looking correct in the 0.11.9 diagnostic dump:
  ZOS's own scroll template auto-enables the mouse on the scroll area's "Scroll"
  child (distinct from the scrollbar) whenever there is content to scroll,
  covering the whole visible list in front of the rows. That is a real,
  source-verified ZOS behaviour, and it correlates with when the icons stopped
  receiving the cursor. That area is now permanently disabled for the kit
  list's scroll container. Cost: no more mouse-wheel scrolling while hovering
  the list itself; dragging the scrollbar still works.
- Applied only to the kit tabs for now, not to Builds, which already works -
  isolating the change avoids risking a regression in what is currently fine
  while this gets confirmed.

## 0.11.9

- Diagnostic only, no behaviour change. With debug mode on, refreshing a kit or
  build list now records the geometry of the whole chain - scroll container,
  scroll area, scroll child, first row, first icon - along with which of them
  accept the mouse. Four attempts at fixing the missing hover tooltips by
  reasoning have failed, so this measures the controls instead of guessing at
  them.

## 0.11.8

- Fix: hovering elements gave no tooltip in exactly the lists that had a
  scrollbar, and worked in the ones that fitted on screen. The scroll child
  auto-sizes to its rows, and the code was also setting its height by hand.
  The two disagree once the content is taller than the visible area - which is
  precisely when a scrollbar appears - leaving the container's rectangle
  inconsistent with what is drawn: rows still rendered but stopped receiving
  the cursor. The manual height is gone; the container sizes itself, which is
  what LibAddonMenu does with this same container and why its controls keep
  their tooltips inside a scrolling panel.

## 0.11.7

- Gear icons in kit rows anchored their first icon by the LEFT point, which is
  vertically centred, while the skill and CP elements that do receive the
  cursor anchor from TOPLEFT. The debug log settled it: hovering a gear icon
  logged nothing at all, so the handler was never running and the problem was
  the icon's hit area, not the tooltip. Gear icons now use the same anchoring
  as the elements that work.

## 0.11.6

- The item tooltip path is now fully guarded. If InitializeTooltip or SetLink
  raised, the error aborted the whole hover handler and nothing at all was
  shown - not even the fallback text that exists precisely for pieces that
  cannot be read. A failure there now falls through to that text instead of
  killing the tooltip outright. This is the one thing gear hovering does that
  the working ability and CP hovers do not.
- With debug mode on, gear icons now log the hover and which tooltip path was
  taken, matching the probe added to build rows in 0.11.5.

## 0.11.5

- Revert the two changes from 0.11.3 and 0.11.4 that were meant to fix hover
  tooltips and made things worse. Mouse-enabling the row was wrong: the row
  then took the cursor itself and the icons that previously did work - skill
  abilities and CP stars - stopped responding. The explicit draw level on
  icons did not help either, so it is gone too.
- Kept from 0.11.4: the gear kit name no longer shows its redundant tooltip.
  That part was a real improvement and is unrelated to the hover problem.
- With debug mode on, hovering a gear or ability icon in a build row now logs
  it. That tells apart "the cursor never reaches the icon" from "it reaches it
  but the tooltip does not appear", which is the thing still to determine.

## 0.11.4

- Gear kit rows no longer show a tooltip on the kit name. It listed the set in
  each slot, which is exactly what the row already shows, so it added nothing -
  and since the name spans most of the row width it was the thing under the
  cursor most of the time, hiding the per-piece tooltips behind it. The useful
  information is per piece, and that lives on each icon: hover an icon to get
  that item's real tooltip, including its armour weight.
- Interactive icons in both the kit and build rows are now drawn above their
  siblings, so the icon is what receives the cursor rather than whatever label
  happens to sit near it.

## 0.11.3

- Fix attempt: hovering the pieces, abilities and CP inside a build row gave no
  tooltip. The row control that holds them was never mouse-enabled, so the row
  area did not take part in cursor detection and its children could be skipped.
  Both the build rows and the kit rows are now mouse-enabled.

## 0.11.2

- The Assign tab's dropdowns were far wider than their contents needed. They
  are now trimmed on the right, and the space that frees up holds a small
  Equip button on each row that has a build behind it: the build assigned to
  the selected target, and the two substitute builds. One click equips it,
  which makes trying a substitute out without travelling to the zone
  practical. Every dropdown reserves the same right-hand gap so they all line
  up whether or not they have a button.
- Those buttons equip exactly what the dropdown shows, with no inheritance -
  that is what "Equip this target's kits" in the action bar is for. They
  refuse incomplete builds, like every other equip path.

## 0.11.1

- Add: **inventory marker**. Any item that belongs to one of your kits gets a
  purple Z in the inventory, so you can see at a glance what not to
  deconstruct or sell; hovering it lists the kits and builds that use it.
  Marks the backpack, bank, guild bank and the deconstruction and improvement
  panels - the places where a piece of a build actually gets destroyed. On by
  default, switchable in the settings panel. It matches by the same item
  identity the kits store, so it marks the exact saved instance rather than
  another copy of the same item.
- Fix: the substitute build labels were cut off ("Trash bui"). The label column
  was sized for the shortest label rather than the longest.

## 0.11.0

- Add: **substitute builds** and the automatic equipping that drives them. Two
  fallback builds, a trash one and a boss one, are used wherever nothing is
  assigned - a trial you never set up, a dungeon, the open world. When a boss
  is present the boss build is equipped, otherwise the trash one. Same idea as
  Wizard's Wardrobe's substitute setups.
- Off by default, with a switch per zone type (trials / dungeons / overland),
  set from the Assign tab. Outside trials this leans on the zone declaring
  "boss" units, which not every zone does - older dungeons tend to be worse
  than newer ones - so it is worth treating as experimental.
- Anything explicitly assigned to a trial target still wins over the
  substitute; the substitute only fills the gaps.
- Auto equipping refuses to apply an incomplete build, ignores the legacy kit
  assignments (equipping those automatically would silently give you a
  half-build with no skills or CP), and will not re-apply a build it just
  applied - repeated context changes would otherwise stack identical LibAsync
  tasks and burn part of the ~30s Champion Point cooldown for nothing.
- Note that gear cannot change during combat: if the boss appears once you are
  already fighting, the swap lands when combat ends. Walking into the boss
  area beforehand is what makes it arrive in time.

## 0.10.1

- Fix: with more builds (or kits) than fit on screen, scrolling down never
  fully revealed the last one. Rows anchored their left edge to the scroll
  child and their right edge to the outer container - but the scroll child
  moves as you scroll while the container does not, so rows were skewed while
  scrolling and the content height the scrollbar is computed from came out
  wrong. Rows are now positioned with a single anchor inside the scroll child
  and given an explicit width measured from the container, which is both stable
  while scrolling and correct for the height calculation. Affects every
  scrolling list: builds and the three kit tabs.
- Opening the window now refreshes whichever tab you left it on, instead of
  always refreshing the kit list. Besides being correct, that is the point
  where containers finally have their real width, which the rows need in order
  to size themselves.

## 0.10.0

Trials now assign builds instead of loose kits, completing the pivot started
in 0.9.0.

- The Assign tab assigns **one build** per trial target (trial default, trash
  or a specific boss) instead of a list of gear kits. A build already covers
  everything, so there is nothing left to combine - picking it in the dropdown
  assigns it, and the old add/remove list is gone. Trial-default inheritance
  works exactly as before: a target with no build of its own uses the trial's.
- "What applies here" now spells out what would actually be equipped at that
  target and why - its own build, one inherited from the trial default, or an
  old kit assignment - so an empty target is distinguishable from an
  inheriting one.
- Equipping a target now applies the whole build (gear, skills and CP), not
  just gear. An incomplete build is refused with the same message the Builds
  tab gives, rather than half-equipping.
- **Existing kit assignments are neither deleted nor migrated.** If a target
  has no build assigned but does have kits from the old model, those kits are
  still equipped, and the panel labels them as an old assignment so you know
  to replace them. Builds.ResolveForTarget is the single place that decides.
- The settings panel's "Equip this target's kits" and "Equip for my current
  location" go through the same resolution, so they no longer disagree with
  the window about what applies where.
- Deleting a build now clears it from any trial or boss it was assigned to.

## 0.9.3

- Fix: the buttons at the bottom of the window overlapped and printed on top of
  each other. The left-hand group (capture / new build / copy worn) and the
  right-hand group (equip, edit, rename, delete) were each sized as if they had
  the bar to themselves, so together they were wider than the bar and collided
  as soon as something was selected. Both groups are now sized to fit
  side by side, with shorter button labels to match.
- Fix: the build buttons said "kit" - "Equip selected kit", "Delete selected
  kit" - because they reused the kit tab's strings. They now read "Equip build"
  and "Delete build", which is what they actually do.

## 0.9.2

- Add: a capture button in the Gear, Skill and CP kit tabs, so you can read
  what you are currently wearing or have slotted straight from the window
  instead of going to the settings panel. All three already deduplicated by
  real content, so capturing something you have already saved does not create
  a twin: it tells you which existing kit already holds it and leaves things
  alone. Gear reports how many kits were new and how many already existed.
- Add: **"Copy everything I'm wearing"** in the Builds tab. It creates a whole
  build from your current gear, bars and Champion stars without you having to
  prepare any kits first - it captures them for you (one kit per set plus each
  loose piece, a skill kit and a CP kit), reuses any that already exist with
  the same content, and composes the build out of them. Copying the same setup
  twice therefore does not fill your kit list with duplicates.
- Kits.CaptureWornAsKits now returns the ids of every kit covering what you
  wear, both freshly created and pre-existing, which is what makes composing a
  build from worn gear possible. CaptureAllSets keeps its old counting
  signature on top of it for the settings panel.
- BuildKitName and the auto-naming helper moved to shared EZOArmory.*
  functions, since both the settings panel and the window now capture kits and
  must name them identically.

## 0.9.1

- Fix: there was no visible way to find where kits get added to a build. The
  editor that does it only appears after you select an existing build and press
  "Edit build", so with no builds created yet the Builds tab looked empty and
  the only assignment screen you could find was the Assign tab - which is the
  trial one, not the build one. The Builds tab now explains what a build is and
  points at the "New build" button, and once you have builds it reminds you
  that double-clicking one jumps straight to its kits.
- Add: double-click a build to open its editor directly.
- The editor now titles itself "Build: <name>" and its kit section reads "Gear
  kits in this build", so it is unambiguous which build you are composing.

## 0.9.0

The addon pivots from being trial-centric to being build-centric.

- Add: **builds**. A kit is a building block and is not coherently equippable on
  its own - it has gaps. A build composes gear kits plus one skill kit and one
  CP kit into something complete, and that is now the thing you equip. Builds
  live in `sv.builds`; see `modules/builds.lua`.
- Add: **Builds tab** in the window, now the first tab and the default one. It
  lists every build with its role icon, its check status and the actual pieces,
  abilities and CP it is made of - hovering any of them gives the real in-game
  tooltip - and equips the whole build (gear, skills and CP) in one click. A
  separate editor view composes a build from your kits, lets you override its
  role, and lists exactly what is wrong with it.
- Add: **automatic build role**, worked out from the weapons: healing staff ->
  healer, shield -> tank, ice staff with neither -> unclear (deliberately not
  guessed, since some tanks run ice staff without a shield and some damage
  builds run ice staff too), attack weapons -> damage. Overridable per build.
  This is internal to EZOArmory and never touches the game's group finder role.
  Weapon type read with GetItemLinkWeaponType; role icons are the game's own
  (ZO_GetKeyboardRoleIcon).
- Add: build-level checks on top of the existing per-bar coherence engine - no
  gear kits, no skill kit, no CP kit, and a skill kit captured with a different
  weapon than the bar it is used on (abilities depend on the weapon). A build
  with any error refuses to equip; warnings do not block.
- Gear pieces now also store their weapon type, and deleting a kit removes it
  from any build that used it instead of leaving a dangling reference.
- Trials still assign kits for now. The model is already prepared for them to
  assign whole builds instead (`Builds.GetTrialReadyBuilds`); see
  docs/concept.md section 3.

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
