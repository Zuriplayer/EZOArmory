# EZOArmory

Loadout, gear-set, Champion Point and skill manager for ESO trials and bosses.
Part of the EZO addon family.

> Status: **development (0.1.0)** — early scaffold. The build-management engine is
> under construction; this release lays down the addon skeleton, the trial/boss
> reference data and the EZOCore integration.

## What it does

EZOArmory manages builds by **composing reusable kits** instead of storing a
full gear snapshot for every boss:

- **Named kits** (the core idea): a kit is a block of concrete pieces, such as
  "Null Arca — 5 body", "Ansuul — jewelry and weapons", a 2-piece monster set, a
  mythic or a single loose piece. You define a kit once and reuse it everywhere.
- **Assign kits per encounter**: each trial has a default set of kits, and you
  only override the trash or the specific bosses that need something different.
  Change a kit and every encounter using it updates automatically.
- **Three role profiles** per character: damage, tank and healer. Kits are shared
  across the character; the assignments belong to each role.
- **Automatic or manual gear swap**, chosen per trial.
- **Coherence engine**: validates a build **per weapon bar** — only 12 pieces
  count at a time, since armour and jewelry always apply but weapons only count
  on the active bar. It flags slot conflicts, sets asking for more pieces than
  they allow, duplicated items, more than one mythic, incomplete bars and pieces
  that are not currently available to equip.
- **Trial and boss awareness**: recognises all 14 trials by zone and their
  bosses, and detects boss encounters outside trials.
- **Skill kits**: memorise both action bars together with the weapons they were
  captured with (shown as front/back bar icons), kept apart from gear kits.
- **Champion Point kits**: memorise the twelve slotted Champion stars; two
  captures with the same stars count as the same kit.
- **One-step capture** of everything: gear sets, loose pieces, skill bars and
  Champion stars, each into its own section, never duplicating an existing kit.
- **Configurable pop-up window** (HUD) showing the current context and warnings.

Gear pieces must be in your backpack: moving items out of the bank requires
direct player interaction and cannot be automated. Skills and Champion Points can
only be changed out of combat, and Champion Points have an in-game cooldown.

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
