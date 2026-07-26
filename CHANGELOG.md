# Changelog

All notable changes to EZOArmory are documented here.

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
