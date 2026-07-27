# Changelog

All notable changes to EZOArmory are documented here.

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
