# EZOArmory

Loadout, gear-set, Champion Point and skill manager for ESO trials and bosses.
Part of the EZO addon family.

> Status: **development (0.1.0)** — early scaffold. The build-management engine is
> under construction; this release lays down the addon skeleton, the trial/boss
> reference data and the EZOCore integration.

## What it does

EZOArmory helps you keep the right build for every trial and every boss:

- **Named set kits** (the core idea): define a kit as a gear set plus the slots
  it should occupy (for example "Ansuul — 5 body" or "Pearlescent — jewelry +
  weapons"). Kits are the building blocks of a loadout.
- **Loadouts**: combine named kits into a full 12-slot build assigned to a trial
  or a specific boss.
- **Coherence engine**: validates a loadout and flags inconsistencies — a slot
  claimed by two different sets, a set asking for more than 5 pieces, unassigned
  slots — and contrasts it against what you actually have equipped.
- **Trial and boss awareness**: recognises all 14 trials by zone and their
  bosses, and detects boss encounters outside trials.
- **Champion Point groups**: named CP groups (for example one for pulls, one for
  bosses, plus a special one).
- **Skill sets**: named ability layouts for the front and back weapon bars.
- **Configurable pop-up window** (HUD): shows where you are (trial/boss), which
  loadout applies and any inconsistencies or reminders.

Food and drink are intentionally out of scope.

## Requirements

- **Required:** LibAddonMenu-2.0
- **Optional:** LibChatMessage, LibDebugLogger, DebugLogViewer, EZOCore

EZOArmory works standalone. When EZOCore is installed it registers under
`Settings > EZO`, shares the family language preference, uses shared diagnostics
and registers its movable window with the family layout service.

## Installation

Install into `Documents/Elder Scrolls Online/live/AddOns/EZOArmory`. During
development the folder is a symlink to the repository at `E:\dev\EZOArmory`.

## Testing

- The addon loads without Lua errors.
- `/reloadui` works.
- The LibAddonMenu settings panel opens (or the EZO panel when EZOCore is present).
- Language and debug preferences persist.

## License

MIT. See [LICENSE](LICENSE).
