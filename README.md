# EZOArmory

Loadout, gear-set, Champion Point and skill manager for ESO trials and bosses.
Part of the EZO addon family.

> Status: **development (0.1.0)** — early scaffold. The build-management engine is
> under construction; this release lays down the addon skeleton, the trial/boss
> reference data and the EZOCore integration.

## What it does

EZOArmory manages builds by **composing reusable kits** instead of storing a
full gear snapshot for every boss:

- **Named kits** (the building block): a kit is a block of concrete pieces, such
  as "Null Arca — 5 body", "Ansuul — jewelry and weapons", a 2-piece monster set,
  a mythic or a single loose piece. You define a kit once and reuse it everywhere.
- **Builds** (what you actually equip): a build composes gear kits, one skill kit
  and one CP kit into something complete. A kit on its own is not coherently
  equippable — it has gaps — while a build covers everything. EZOArmory checks
  every build and refuses to equip an incomplete one, showing exactly what is
  missing or conflicting. Each build gets a role of its own, worked out from its
  weapons: a healing staff means healer, a shield means tank, an ice staff
  without either is flagged as unclear (some tanks run ice staff without a
  shield), and attack weapons on both bars mean damage. You can override it. This
  role is internal to EZOArmory and never touches your group finder role.
- **Assign a build per encounter**: each trial has a default build, and you only
  override the trash or the specific bosses that need something different. One
  build per target, since a build already covers everything. Change the build
  and every encounter using it follows automatically.
- **Three role profiles** per character: damage, tank and healer. Kits are shared
  across the character; the assignments belong to each role.
- **Inventory marker**: items that belong to one of your kits get a purple Z in
  the backpack, bank, guild bank and the deconstruction and improvement panels,
  so you can see at a glance what not to destroy. Hovering it lists the kits and
  builds that use the piece.
- **Substitute builds**: a trash build and a boss build used wherever nothing is
  assigned - a trial you never set up, a dungeon, the open world. EZOArmory
  equips the boss one while a boss is present and the trash one otherwise.
  Off by default, with a switch per zone type, and experimental outside trials:
  it depends on the zone declaring its bosses, which not all of them do.
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
- **Its own window**, opened with a keybind or `/ezoarmory`, showing the current
  trial and boss. Its **Builds** tab lists every build with its role, its status
  and the pieces, abilities and stars that make it up — hover any of them for the
  real in-game tooltip — and equips a whole build in one click. A separate editor
  view builds one up from your kits and reports what still needs fixing. The
  remaining tabs browse gear, skill and Champion Point kits with the same real
  tooltips, and assign a build to each trial and boss. The twelve-slot coherence
  grid is still being built here.

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
