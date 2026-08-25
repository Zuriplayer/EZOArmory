# Changelog

All notable changes to EZOArmory are documented here.

## 0.11.53

- `/ezoarmoryundress` now reports **to chat** instead of to LibDebugLogger. The
  previous version's instrumentation measured nothing at all, because debug
  mode is off (as it should be) and everything was being written to a log that
  was never running. A diagnostic that depends on an option you have to
  remember to switch on is not a diagnostic.
- It also unequips **directly**, in a plain loop with no LibAsync, instead of
  going through the queue. That separates two things: if it undresses this way,
  the fault is in the queue or the button; if it does not, the fault is in the
  game call and the answer is somewhere else entirely.
- It prints, in order: whether equipment can be changed right now, free bag
  slots, how many slots have something on, how many unequip requests went out,
  any that threw, and - after a short pause - what is still worn.

## 0.11.52

- Diagnostics for undress not working. Nothing about how it works was changed
  blindly: the unequip call and its arguments were re-checked against the
  game's own code first (`RequestUnequipItem(BAG_WORN, equipSlot)`,
  `inventoryslot.lua:1137` - a plain call, not a protected one), and they are
  right, so the fault is somewhere earlier and guessing which part would just
  burn a version.
- Add `/ezoarmoryundress`: runs the undress **skipping the button and the
  dialog**. "Nothing happens when I click" covers three different faults - the
  button never calls, the dialog never shows, or the unequip does nothing - and
  they can only be told apart by testing each layer on its own.
- The whole path now logs to LibDebugLogger: the click, the confirmation, how
  many worn slots were found, how many free bag slots there are, and each
  individual unequip with whether the call went through.
- Fix: clicking undress when the dialog cannot be registered used to return in
  **silence**, which from outside looks exactly like a dead button. It now says
  so and points at the slash command.

## 0.11.51

- Fix: the experimental warning added in 0.11.50 was drawn **on top of** the
  grey explanation above it. That text wraps to three lines and only two lines'
  worth of space had been reserved for it.
- The wrapping hints on the Assign tab now have an explicit height, and the
  warning is anchored **below** the grey hint rather than at a hand-counted Y.
  These texts reflow with the window width and the translation, so their real
  height was never something to guess at; with a set height the worst case is
  an ellipsis instead of an overlap.
- The substitute-builds hint further down had the same latent problem - fitting
  its reserved space by three pixels - and got the same fix.

## 0.11.50

- Add: auto-equip is now labelled **experimental** in the Assign tab, with an
  amber warning under the switch saying what that means in practice: it leans
  on the zone declaring its bosses and on the boss rooms learned from your own
  visits, so it can equip late, equip half a build, or not fire at all. Check
  what you are wearing before a pull that matters.
- The warning is always on screen, not only while the switch is on: the person
  who needs to read it is the one still deciding whether to turn it on.

## 0.11.49

- Change: every category icon is now sourced from the game's own interface
  code, with the file each one comes from written down next to it.
  - **PVP**: `LFG_indexIcon_allianceWar_up` (the Cyrodiil campaign browser)
    instead of the main menu's AvA button.
  - **Battlegrounds**: `LFG_indexIcon_battlegrounds_up` (the battleground
    finder) instead of `menuBar_group_up`, which is the generic **group**
    icon - it did not say "battlegrounds", it said "group".
  - **Solo**: asked for with `ZO_GetZoneDisplayTypeIcon(ZONE_DISPLAY_TYPE_SOLO)`
    rather than hardcoded. It is literally the icon the game marks solo zones
    with, which is what the arenas in this category are.
  - **PVE damage / tank / healer**: unchanged - still the game's role icons via
    `ZO_GetKeyboardRoleIcon`. Role is the axis that separates those three, and
    these are the icons a player already knows from the group finder.
  - **Overland**: unchanged - the main menu's map icon. There is no
    `ZONE_DISPLAY_TYPE` for open world, and the map is the nearest thing.
- Where the game offers a function to ask for an icon, the function is used and
  the literal path is kept only as a fallback: if ZOS moves the file, the icon
  still appears.

## 0.11.48

- Change: the icon on the left of a build row now shows its **category**
  instead of its role. With the role it was the same drawing repeated down the
  whole list - nearly every build is a damage build - and the role is deduced
  from the weapons, which are already painted on the row right underneath. It
  was the least informative thing in the most visible spot.
- Builds with no category still show the role icon there, so the slot is never
  mute. The tooltip always names **both** - category as the title, role as a
  line under it - so there is no guessing which of the two is on screen, and
  the role's "unclear" warning (ice staff without a shield, which cannot be
  decided from the weapon) is not lost along the way.

## 0.11.47

- Add: an **undress** button at the bottom of the Builds tab. It takes off all
  your armour, jewelry and both weapon bars and drops them in your bag.
  Costumes, tabards, capes and poisons are left alone - they belong to no
  build, and stripping someone's costume unasked would be an unpleasant
  surprise.
- **If it does not all fit, nothing comes off.** The free bag slots are counted
  first, and if there are fewer than there are pieces, it refuses and says how
  many of each. A half-undressed character with a full bag has no idea what is
  missing and no room to fix it.
- It asks for confirmation. Undressing is undone by equipping any build, so it
  is not grave - but this is a small unlabelled icon next to six other buttons,
  and a slip of the mouse should not leave you naked mid-trial in silence.
- Same rules as equipping: not in combat, not dead, and readiness is rechecked
  before **each** piece rather than once for the batch, since fourteen
  unequips spread across several frames and a fight can start partway.
- The icon is native: it is the game's own "clear this slot" texture from the
  outfit screen (`OUTFIT_SLOT_CLEAR_TEXTURES` in
  `esoui/ingame/restyle/restyle_shared.lua`). ESO has no undress icon; this is
  the closest thing a player has already seen.
- The button chains off the left-hand row rather than centring in the bar: the
  bar's centre falls inside the left row, so centring would have overlapped
  "Update worn" - the same arithmetic that was missed in 0.11.44.

## 0.11.46

- Add: the category dropdown is now **on the build row itself**, in the gap
  between the name and the status icon. Cataloguing a long list meant opening
  the editor, choosing, going back, and repeating - which is the work this was
  supposed to remove. The dropdown stays in the editor too: the row is a
  shortcut, not a move.
- Removed the category icon from the row. With the dropdown right there
  spelling the category out in words, the icon was saying the same thing twice
  on the same line. Group headings still carry it, which is where it reads as
  a heading rather than as clutter.
- Changing a category (or the filter) repaints the list **on the next frame**,
  not inside the dropdown's own click callback: the list regroups, which means
  repainting the very control that is still dispatching the click.
- The row's header controls now anchor centre-to-centre instead of top-to-top.
  The status icon and the dropdown are shorter than the 26px header band and
  sit centred in it, so top anchors meant hand-compensating each height, and
  the name label ended up with its two anchors asking for different Y.

## 0.11.45

- Add: builds can be **catalogued** - PVE DD, PVE Tank, PVE Healer, PVP,
  Battlegrounds, Solo (arenas) and Overland - from a dropdown in the build
  editor. The category is a label only: it changes nothing about what gets
  equipped, and it is not used by any assignment. It exists so a long list of
  builds stops being a wall of names.
- The list is now **grouped by category**, each group under a heading with its
  icon and how many builds it holds. Uncategorised builds go last, so nothing
  disappears just because it has not been catalogued yet.
- Add: a **filter** above the list - all builds, one category, or only the
  uncategorised ones. With a filter on, the counter counts what is on screen
  rather than the total, and if the filter leaves the list empty it says so
  instead of looking like the builds were lost. The filter is view state: it
  lasts the session and is not saved.
- The three PVE categories reuse the game's own role icons, which is what a
  player recognises. That would put the same drawing twice on a row whose
  detected role matches its category, so in that case the row shows it once.
  When they differ it is drawn - and there the second icon says something: the
  category set by hand does not match the role deduced from the gear.
- Role and category share one row in the editor. The editor is laid out with
  fixed vertical offsets (see the note at the top of the file), so an extra
  full row would have pushed the issues list off the panel.

## 0.11.44

- Change: a build's status is now an **icon** instead of the sentence
  "Everything checks out", which took up the whole right-hand side of the row
  to say the same thing every time. Green tick when all is well, amber warning
  triangle, red cross on errors - with the number of issues beside it when
  there are any, since the icon alone cannot say *how many*.
- The full detail is unchanged: hovering either the icon or the number lists
  every issue, exactly as before.
- Icons are **native game textures**, verified as referenced in the game's own
  interface code rather than invented paths: `Buttons/accept_up.dds`,
  `Miscellaneous/ESO_Icon_Warning.dds` and `Buttons/decline_up.dds`. They are
  tinted with the existing status colours, so one symbol serves each state.

## 0.11.43

- Add: boss rooms are recognised by **position**, so the build can be equipped
  on walking in, before the pull. `EVENT_BOSSES_CHANGED` fires when the
  encounter activates, which is usually once combat has already started - and
  in combat nothing can be changed, so the boss build ended up applying after
  the fight. This is the underlying problem behind the original Spindleclutch
  report.
- Rooms are **learned automatically**: the first time a boss is detected, the
  player's position at that moment is stored as the centre of its room. From
  the next visit on, position recognises it early. Nothing to configure, and
  the position was already being logged since 0.11.23.
- A single centre plus radius per room, not a six-sided box. One point is
  enough for a boss room, and it needs no manual measuring. Where two rooms
  overlap, the nearer centre wins.
- Polls every 2 s and **stops in combat**, resuming on leaving it - the same
  interval and policy as Wizard's Wardrobe (`zones/LC.lua`). Verified that this
  is how everyone solves it: WW uses x/y/z boxes across 9 zones,
  BSCs-HowToKynesAegis does the same inline. There is no better API.
- Unlike WW, this does **not** replace `EVENT_BOSSES_CHANGED` - WW disables it
  entirely in zones with boxes. Here the event stays as the safety net for
  rooms not learned yet, and position only takes over when it recognises one.

## 0.11.42

- Fix: the CP summary in a build row covered everything to its right. It was
  anchored to the row's right edge *and* had the mouse enabled, so that wide,
  transparent control sat over the icons beyond it - which is why the pieces on
  the right showed no tooltip, and why the text appeared on top of them. It now
  takes the width of its own text. Same mechanism as the "Scroll" overlay that
  broke tooltips in 0.11.10: a control in front keeping the cursor.
- Added a trace listing which slots survive the coherence analysis and become
  equip targets. A piece dropped there - by a conflict between kits, or an
  unrecognised slot - is never attempted and appears in **no** counter in the
  report: not equipped, not already on, not failed. It vanishes without trace,
  which is exactly how "it doesn't equip the weapons" presents.

## 0.11.41

- Fix: the bank menu never appeared at a **house storage coffer**, which is the
  main place it would be used. `IsBankOpen()` returns false with a coffer open -
  the diagnostic trace recorded `bankOpen=false` with one in front - so every
  guard in the storage module refused to act.
- Reading the game's code suggested the opposite (`banking_gamepad.lua` does
  `IsBankOpen() and IsHouseBankBag(GetBankingBag())`), so this was found from
  the trace, not from the source. The measured behaviour wins.
- Open containers are now tracked through `EVENT_OPEN_BANK` / `EVENT_CLOSE_BANK`,
  which carry the actual bag and work identically for the bank, the subscriber
  bank and the ten house coffers. `Storage.IsOpen()` / `Storage.GetOpenBag()`
  replace every `IsBankOpen()` check, and deposits now go to the container
  actually open rather than assuming `BAG_BANK`.
- `IsBankOpen()` survives only as a fallback inside `GetOpenBag`, for the case
  where the open event was missed - reloading the UI with the container already
  open, for instance.

## 0.11.40

- Fix: consecutive pieces could be sent to the same destination slot and get in
  each other's way. 0.11.39 started confirming a move by the piece leaving its
  source, which is conclusive that it moved but says nothing about it having
  landed yet - so `FindFirstEmptySlotInBag` for the next piece could hand back
  that same still-empty slot. A short pause now follows each move, as Wizard's
  Wardrobe does between items. This is a strong candidate for pieces going
  missing in a batch.
- Fix: a build pointing at a gear kit that no longer exists dropped that kit's
  pieces silently, which reads exactly like "it didn't store that piece". It is
  now logged.
- Fix: if the bank closed partway through, the pieces still queued vanished
  from the report - the totals added up while pieces were plainly still
  unstored. They are now counted as not moved and listed.

## 0.11.39

- Fix: moving a piece to or from the bank checked the wrong thing. It watched
  for the item appearing in the exact free slot picked with
  `FindFirstEmptySlotInBag`, but the server need not put it there - that slot
  can be taken in the meantime, or the container reorganised. A piece that had
  in fact moved was then declared "did not arrive" after the 3 s timeout and
  counted as a failure. It now checks that the piece is **no longer at the
  source**, which is conclusive.
- Added diagnostics to the storage moves: how many pieces the build has, how
  many were queued, how many were skipped as worn or not found, and per piece
  whether it moved (and after how many polls) or not, with source and intended
  destination.

## 0.11.38

- Add: take a build's gear out of the bank, or store it, from the inventory
  right-click menu. Works with the bank, the subscriber bank and house chests
  alike - `GetBankingBag()` returns whichever container is open, so they need
  no special casing.
- **Nothing you are wearing is ever touched.** A piece of the build that is
  currently equipped is counted and reported, never unequipped. That was the
  agreed scope: it removes the case where one wrong click leaves you with no
  gear on.
- Pieces move one at a time, waiting for each to arrive before sending the
  next (100 ms polling, 3 s timeout), because the server takes time and firing
  them all at once loses pieces. Space is checked with `DoesBagHaveSpaceFor`
  first, falling back to the subscriber bank when the normal one is full and
  you have ESO Plus. Same approach as Wizard's Wardrobe's banking module, which
  is where the pattern was verified.
- The chat report distinguishes moved, left alone because worn, not found, no
  room, and did not arrive - rather than a single count that hides what
  happened.
- **New optional dependency: LibCustomMenu**, for the context menu. This is a
  second exception to the family rule that only LibAsync is allowed, requested
  explicitly when choosing the context menu as the interface. It is declared
  `OptionalDependsOn`, not `DependsOn`: without the library the add-on works
  exactly as before, only the menu is missing, and `EZOArmory.Storage` is still
  usable from code. The library is public domain (Unlicense).

## 0.11.37

- Fix: "Copy worn setup" could produce a build with no skill kit and no CP kit
  and say nothing about it. `Builds.CreateFromCurrent` collected only two of the
  three return values from `CreateKitFromCurrent`, throwing away the third -
  the reason (`"empty"` / `"duplicate"`). So when a part was not captured there
  was no message, no log line, and no way to tell "nothing was slotted" from
  "something went wrong". The reason is now kept, logged, and reported.
- The chat message after copying now lists any part that could not be captured,
  and points at assigning it by hand or using "Update worn". Previously it only
  reported the gear count, so a build missing skills and CP looked fine until
  the coherence check flagged it red much later - which is exactly how this was
  found, from a screenshot, several versions after the fact.
- This explains the two remaining issues on Ricardo's `AA Vat CON Fuego` build
  from 0.11.36: it is the only build in the saved data with neither
  `skillKitId` nor `cpKitId`, and it was created with "Copy worn setup".

## 0.11.36

- Fix: a build wearing the Oakensoul Ring was flagged with three bogus issues -
  no main hand on the back bar, no off hand on the back bar, and "only 10 of 12
  pieces count" on the back bar. Oakensoul removes the back bar entirely, so
  there is nothing there to fill: the analysis now skips that bar completely
  when the loadout carries a single-bar mythic.
- Detected by `setId`, not by name (names change with the client language). The
  id was read from real saved kit data (`setName "Oakensoul Ring"`, `setId 658`,
  `maxEquipped 1`) rather than guessed. There is no API to ask whether weapon
  swapping is locked - `EVENT_WEAPON_SWAP_LOCKED` exists but has no matching
  getter, and `GetWeaponSwapUnlockedLevel` refers to character level - so it is
  a list of set ids, `SINGLE_BAR_SET_IDS`, easy to extend if another item ever
  does the same.
- Fix: issue messages read "Back bar bar" and "Front bar bar". `BarLabel`
  already returns "Back bar", and four templates appended another " bar" (or
  " barra") around it. The templates no longer add it.

## 0.11.35

- Fix: equipping a build whose mythic differs from the one you are wearing left
  the new one unequipped. ESO only allows **one** mythic at a time, so
  `EquipItem` is rejected while the previous one is still on. The conflicting
  mythic is now unequipped first, with a settle margin before the rest of the
  batch goes through.
- This is very likely part of what made a build need several attempts to apply,
  alongside the slot-order and `wornElsewhere` causes fixed in 0.11.24.
- Detection uses the assignment data already carried by the coherence analysis
  (`maxEquipped == 1` identifies a mythic set, from `GetItemLinkSetInfo`) for
  the incoming piece, and `GetItemDisplayQuality(...) ==
  ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE` for what is currently worn - a real
  engine constant, the same approach Caro's Skill Point Saver uses, rather than
  Wizard's Wardrobe's bare `itemType == 6`.
- Nothing is unequipped when the build carries no mythic, or when the mythic
  already worn is the one wanted: keeping the old one on only blocks equipping
  when a *different* one has to go in.
- `RequestUnequipItem` is not a protected function (unlike `RequestMoveItem`),
  so it can be called directly.

## 0.11.34

- Fix: the Assign tab had two adjacent buttons that looked identical and were
  not, and one of them could silently do nothing. The small "Equip" on the
  Builds row used `GetStoredTrialAssignment` - the build stored on that exact
  target, **without inheritance** - so on a target that inherits from the
  zone's default it found nothing and returned without a word. The one below
  it, now just "Equip this target", goes through `ResolveForTarget`, which does
  resolve inheritance and old kit assignments, and reports why when it equips
  nothing.
- The redundant button is gone. One button that always does the right thing
  beats two that differ only in a case you cannot see from the interface.
- The same helper still backs the substitute rows, where equipping exactly what
  the dropdown shows is the point - but it now says so when there is no build
  selected in that row, instead of returning silently. A button that does
  nothing and says nothing reads as broken.

## 0.11.33

- Fix: "Update worn" and "Equip" overlapped in the Builds action bar. Adding a
  sixth button in 0.11.31 pushed the row past the available width: the six came
  to 810 px of buttons plus 60 of gaps = 870, against roughly 726 px of usable
  space at the default window size (900 minus the 150 px tab column and the
  body margins). With five buttons it fitted, barely.
- Widths are now counted rather than eyeballed, and the arithmetic is written
  down next to them: 610 + 60 = 670, leaving real margin. Button labels dropped
  the redundant "build" - the tab is already called Builds - which is the same
  lesson as 0.9.3: the window has a fixed width and the long option-panel
  wording does not fit in it.

## 0.11.32

- Change: "Update with worn" compares Champion kits **per discipline**, not slot
  by slot. All four slots of a discipline are active at once, so moving a star
  from the first to the third changes nothing about what the character does -
  treating that as a change was a false positive. What counts is a discipline
  carrying different stars.
- Which slot belongs to which discipline is asked to the engine via
  `GetRequiredChampionDisciplineIdForSlot(slotIndex, hotbarCategory)`, the same
  call the game uses in `championassignableactionbar.lua` and in the Armory,
  rather than assuming the twelve slots run in blocks of four. There is a
  fallback to blocks of four if the call is ever unavailable.
- When there *is* a real change, the current layout is still stored as-is, so
  equipping reproduces exactly what you have now.

## 0.11.31

- Add: "Update with worn" button in the Builds tab. Takes the build you have
  selected and brings it in line with what you are wearing right now - meant
  for the small tweak, like moving an ability to a different slot, without
  rebuilding anything.
- The part that needed care: kits are **shared** between builds. Overwriting a
  build's skill kit would silently change every other build using that same
  kit. But always creating a new one is no good either - it would orphan the
  old kit and fill the list with near-identical entries, exactly the clutter
  that had to be cleaned up by hand before. So the decision is made per kit:
  - kit used **only** by this build → overwritten in place, keeping its id and
    name, leaving no orphan and affecting nobody;
  - kit **shared** with other builds → left untouched; a kit with the new
    content is found or created and this build points at that instead.
- Champion kits compare **slot by slot** here, unlike `StarsEqual`, which sorts
  and ignores slots because for deduplication two identical sets are the same
  kit. For updating it matters: moving a star to another slot is a real change
  the equip has to reproduce.
- The chat report says which parts actually changed, and says so plainly when
  the build already matched what you were wearing.

## 0.11.30

- Vateshran Hollows now ships its four bosses - The Pyrelord, Maebroogha the
  Void Lich, Shade of the Grove and Rahdgarak - confirmed from a real run:
  0.11.29's discovery found and recorded them with the exact names
  `GetUnitName` returns. Fixing them in the table means they don't have to be
  rediscovered on every character.
- Recorded while confirming it: Vateshran's round enemies are **not** declared
  as `bossN` units, so they never arrive through `EVENT_BOSSES_CHANGED` and
  cannot be classified as minibosses - only those four bosses come through that
  way. The miniboss tier still applies where the game does mark them, which
  includes the trial minibosses added in 0.11.21 (Dreadsail Reef's Sail Ripper
  and Bow Breaker, Rockgrove's Basks-In-Snakes and Ash Titan). This is the same
  limitation Wizard's Wardrobe warns about for its substitute setups: outside
  trials, boss detection depends on the zone declaring its bosses, and not
  every zone does.

## 0.11.29

- Add: minibosses are now a distinct target level. Every zone offers three
  generic targets - trash, **miniboss** and the specific bosses - plus a third
  substitute build for minibosses. A miniboss with no build of its own falls
  back to the miniboss target, then to boss, then to trash, so nothing needs
  reconfiguring to keep working as before.
- How the split is decided, and why it isn't a hand-kept list: the game itself
  classifies units through `GetUnitDifficulty`, and paints the target frame
  from it in `esoui/ingame/unitframes/unitframes.lua:1683-1705` -
  `MONSTER_DIFFICULTY_HARD` draws `bracket_level3` (the arrows) and
  `MONSTER_DIFFICULTY_DEADLY` draws `bracket_level4` (the skull). That is
  exactly the on-screen distinction between a miniboss and a main boss, so the
  addon reads the same value instead of maintaining a list that would age with
  every patch.
- Add: bosses are now **discovered while playing**. A boss appearing in a known
  zone whose name isn't recognised is recorded with the exact name this client
  returns and with its tier, and immediately becomes assignable. Arena boss
  lists fill themselves in.
- That replaces chasing name tables for the arenas, which turned out to be a
  dead end: no reliable source publishes complete arena boss lists, and the
  translated names that do exist (Wizard's Wardrobe, CrutchAlerts) carry ESO's
  grammatical-gender suffixes (`^M`, `^f`) that `GetUnitName` does not return,
  plus different casing - so they would not have matched anyway.
- Minibosses are prefixed with `[mini]` in the target dropdown.
- Note on the Vateshran bosses reported as learned: nothing had been saved. All
  `bossNames` entries were empty, and only `default` and `trash` were assigned
  for VH. The cause was that Vateshran shipped with an empty boss list, so the
  dropdown offered no boss to select and "Learn this boss" correctly refused.
  Discovery removes that dependency entirely.

## 0.11.28

- Change: the Assign tab now shows **two separate groups**, Trials and Arenas,
  both visible and configurable at once, each with its own zone, target, build,
  summary line and its own "equip target" / "clear" buttons. 0.11.27's shared
  dropdown is gone.
- The tab scrolls, with the mouse wheel or the scrollbar, since the two groups
  plus the substitute block no longer fit on one screen.
- **The mouse wheel works again everywhere**, including the kit and build
  lists. `DisableScrollWheelArea` (the 0.11.10 fix for hover tooltips breaking
  in scrolled lists) turns off the engine's "Scroll" child, which is also what
  captures the wheel - that loss was recorded as an accepted cost. It didn't
  have to be: `ZO_Scroll_OnMouseWheel` is a global the engine's own XML calls
  as `ZO_Scroll_OnMouseWheel(self:GetParent(), delta)`, so re-binding it on the
  container itself gives identical scrolling without the overlay that stole the
  cursor. Worth doing here specifically because the Assign tab is full of
  dropdowns and checkboxes, where an overlay stealing input would be far worse
  than a missing tooltip.
- Both groups are built from one `ASSIGN_GROUPS` table and share every function
  (populate, summary, equip, clear) parameterised by group, rather than being
  duplicated - duplicating is how `window_kits` and `window_builds` drifted
  apart in the first place.
- "Equip target" and "Clear" moved from the shared bottom bar into each group,
  so there is no invisible "which group does this act on" state. The bottom bar
  keeps only what doesn't depend on the group: equip for where you are, and
  learn the boss in front of you - and "Learn this boss" now works in arenas
  too, deducing the group from where you actually are.
- Content sits on a fixed-size page control inside the ScrollChild rather than
  anchoring to both its sides, which would recreate the circular dependency
  that collapsed rows back in 0.7.2 and 0.10.1.

## 0.11.27

- Add: arenas can now have builds assigned per target, exactly like trials -
  Dragonstar Arena, Maelstrom Arena, Blackrose Prison and Vateshran Hollows.
  They appear in the Assign tab's zone dropdown below the trials, separated by
  a divider line.
- They share the trials' dropdown rather than getting a block of their own
  because the panel already uses roughly 350 of its ~470 usable pixels;
  duplicating the three controls (zone, target, build) would not fit without
  cramping everything. Sharing also means the rest of the panel - target,
  build, summary - serves both without duplication.
- `Zones.ARENAS` uses the same shape as `Zones.TRIALS`, and both feed the same
  tag/zoneId indexes, so assignments, inheritance from the trial default,
  `ResolveForTarget` and live context detection all work unchanged.
- Zone ids verified from two independent sources: BanditsUserInterface's zone
  table (in production) and, for Blackrose, Wizard's Wardrobe's `zones/BRP.lua`
  (`id = 1082`). The twelve trials both lists share also match ours exactly,
  which is what gives confidence in the rest.
- **Only Blackrose ships boss names**, because they are the only ones
  verifiable (WW defines and translates them). Dragonstar, Maelstrom and
  Vateshran deliberately ship with no boss list rather than invented data: in
  those three you can assign `default` and `trash`, which covers most of the
  use, and per-boss entries can be added once real names are confirmed.
- For substitute builds an arena deliberately does *not* count as a trial, so
  the "Trials" switch doesn't silently govern arenas; they resolve by actual
  zone type instead. Explicit arena assignments are unaffected - those resolve
  earlier.

## 0.11.26

- Fix: applying a CP kit has been broken since 0.11.14 whenever it actually had
  something to change. `EVENT_MANAGER` is `GetEventManager()`, an engine object
  whose `type()` is `"userdata"`, not `"table"`
  (`esoui/app/globals/globals.lua:1`). Two guards in `equip.lua` tested for
  `"table"` only, so they were always false:
  - `SendAndVerifyCp` bailed out with `error = "empty"` as soon as there was
    one star to change, before sending anything. A kit with no differences
    returns earlier through a different path, which is why it appeared to work
    and why the bug hid for so long.
  - `EnsureCpCooldownTracking` never registered, so `cpCooldownRemaining`
    stayed at 0 and `Equip.IsCpReady()` was always true - the ~30s cooldown was
    never actually tracked.
  `context_tracker.lua` already accepted `userdata`; it was `equip.lua` that
  disagreed with it.
- Fix: that failure reported itself as "the selected CP kit has nothing to
  slot", which was simply untrue and sent the investigation towards the kit
  data - which was perfectly fine. It is now a distinct error with an honest
  message, and the missing function is logged.
- Checked the other engine objects guarded the same way:
  `ACTION_BAR_ASSIGNMENT_MANAGER` and `SKILLS_DATA_MANAGER` are Lua objects
  (`= self`, `= ZO_CallbackObject.New(self)`), genuinely tables, so those
  checks were correct and are unchanged.

## 0.11.25

- Diagnostics: each CP slot being changed now logs the discipline of the
  incoming star alongside the discipline of the star currently in that slot.
  Slots are grouped by discipline and the server rejects the *entire* request
  with `CHAMPION_PURCHASE_CHAMPION_BAR_WRONG_DISCIPLINE` if a single star
  doesn't fit, which would look exactly like "one star won't load" - the other
  eleven matching already, so they never enter the request. This narrows the
  remaining CP hypotheses to two: wrong discipline, or the ~30s server
  cooldown.

## 0.11.24

- Fix: a piece already worn in a *different* equip slot was never moved. It was
  counted as `wornElsewhere` and skipped, with a comment deferring the case -
  so the previous build's piece stayed in the destination slot. This is the
  main reason a build could need several attempts to apply: it hits the two
  rings swapping places, and a weapon moving between the front and back bar.
  `EquipItem` accepts `BAG_WORN` as the source and performs the swap, verified
  against Wizard's Wardrobe in production (its `GetItemLocation` walks
  `{ BAG_WORN, BAG_BACKPACK }` and feeds whatever it finds straight to
  `EquipItem`).
- Fix: gear was equipped in non-deterministic order. `BuildTargets` iterated the
  assignment with `pairs()`, which guarantees no ordering in Lua and can differ
  between runs - so with pieces swapping slots the outcome depended on the
  order, which is why it sometimes worked and sometimes didn't. Targets are now
  sorted by the canonical `Gear.SLOT_DEFS` order (armour, jewellery, weapons),
  the same approach as WW's fixed `WW.GEARSLOTS` list.
- A 500 ms settle margin is left after moving a piece that came from another
  equip slot, since that swap relocates two slots at once and the next piece
  would otherwise be looked up against positions the game hasn't updated yet.
  Same value WW uses for the equivalent case.
- `wornElsewhere` now means "moved from another equip slot", not "skipped", so
  auto-equip no longer treats it as a failure worth clearing its guard for.
- Champion points: added diagnostics rather than a speculative fix. The number
  of diffs, the current cooldown, each skipped star with the reason
  (`slottable`/`spent`), and the raw server result code are now logged, since
  the result code was the one reliable clue and it was being discarded.
- Ruled out while investigating: sending only the changed CP slots is correct
  and matches the game itself - `ZO_ChampionAssignableActionBarSlot`
  `:CollectUnsavedChanges` only calls
  `AddHotbarSlotToChampionPurchaseRequest` when a slot has unsaved changes. WW
  sends all twelve, which is the outlier, not us.

## 0.11.23

- Diagnostics only, no behaviour change: `EVENT_ZONE_CHANGED` is now logged
  with all five of its values, and the boss trace additionally records the
  current subzone and the player's world position. Nothing writes to the log
  unless `debugMode` is on.
- The question being measured: `EVENT_ZONE_CHANGED` carries a `subZoneId`
  integer. If a boss room turns out to be its own subzone, that would give
  both a stable language-independent identifier and - far more valuable - a
  signal on walking through the door, before combat starts. Today everything
  waits on `Equip.IsReady()`, so a boss that engages as it spawns defers the
  whole swap until the fight is over. This is a hypothesis, hence measuring
  before building anything on it.
- The same traces record world coordinates whenever a boss appears, so if
  position-based detection is ever worth doing, the room boxes can be built
  from our own measurements rather than lifted from another add-on.
- For reference, how the game itself does it (`esoui/ingame/unitframes/
  bossbar.lua`): it iterates `boss1..bossN` over
  `BOSS_RANK_ITERATION_BEGIN..END` with `DoesUnitExist`, listens to
  `EVENT_BOSSES_CHANGED` and `EVENT_PLAYER_ACTIVATED`, sums health via
  `GetUnitPower`, and tells the compass with
  `COMPASS_FRAME:SetBossBarActive`. That is identical to what
  `Context.state.bossActive` already does - the game has no separate notion of
  "boss area", and the bar appears when the server assigns the boss unit tags,
  not when you enter the room. So there is no privileged signal being missed.

## 0.11.22

- Fix: Dreadsail Reef's first boss was never detected, in any language. The
  boss1 unit is called just "Lylanar" (same in English and Spanish);
  "Lylanar and Turlassil" is the name of the *encounter*, not of the unit, and
  that is what the table was matching `GetUnitName()` against. Boss entries now
  separate the two: `name` is what gets compared, `label` is what gets shown.
  Wizard's Wardrobe draws the same distinction (`name` vs `displayName`), which
  is how the mismatch turned up.
- Checked every trial boss against Wizard's Wardrobe's tables, entry by entry:
  with 0.11.21's four minibosses added, all 14 trials now match exactly, so no
  trial boss is missing. Halls of Fabrication was worth confirming for the same
  reason as Lylanar - it also has display names that differ from unit names
  ("Hunter-Killer" for Hunter-Killer Negatrix, "Commitee" for Reactor) - and
  our entries already used the unit names, so they were correct.

## 0.11.21

- Fix: four minibosses were missing from the trial tables, so they resolved to
  "trash" and got the trash build instead of a boss build - Dreadsail Reef's
  Sail Ripper and Bow Breaker, and Rockgrove's Basks-In-Snakes and Ash Titan.
  The effect was inconsistent rather than merely absent: a recognised boss with
  no assignment of its own falls through to the boss substitute, but an
  unrecognised one resolves to the trash target, which then matches an explicit
  trash assignment if you have one. So bosses got the boss build while
  minibosses in the same trial got the trash build.
- Names taken from Wizard's Wardrobe's own tables, which list all six DSR and
  five RG encounters. Note that WW translates "Bow Breaker" as
  "Rompecorazones", which does not match the English name and may be a mistake
  on their side; it is included in case it is right (a string that never
  matches does no harm) but it is the prime candidate for correcting with the
  "Learn this boss" button.

## 0.11.20

- Fix: auto-equip never told you when it was waiting. `Equip.onQueued` - the
  hook that prints "in combat, will equip once you are out" - was assigned
  only by the manual equip paths in `window_kits.lua`; the auto-equip route
  (`AutoEquip` -> `Builds.Equip`) assigned none, so a build queued behind
  combat produced complete silence and there was no way to tell "it didn't
  work" from "it's waiting". Worse, being a single module variable, whether
  any message appeared at all depended on which manual equip you happened to
  do last in that session. The default message now lives in `equip.lua` and
  is shared by both routes; `Equip.onQueued` is still honoured if assigned.
- Fix: gear verification was checking too early. 0.11.17 re-read the worn slot
  in the same frame as the `EquipItem` call, but equipping is a request to the
  server and the bag updates afterwards - that's why
  `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` exists, and why Wizard's Wardrobe never
  verifies after `EquipItem` and instead inserts explicit 500 ms waits ("Be
  sure to give enough time so backbar can find new location"). A piece that
  was equipping fine could therefore be reported as failed, which also cleared
  auto-equip's "already applied" guard and could re-trigger the whole equip.
  Verification now happens in a single pass at the end of the batch, after a
  600 ms margin. The check itself is still worth doing: if combat starts
  mid-batch the remaining requests genuinely don't take effect.
- Context for the Spindleclutch II report: none of the above is why a boss
  build may fail to land. Equipping waits for `Equip.IsReady()`, which is
  false in combat, so a boss that engages as it spawns pushes the whole swap
  to after the fight - documented behaviour, see the header of
  `modules/auto_equip.lua`. Trash pulls work because there's an out-of-combat
  window between them. The queue message above is what makes this visible
  rather than silent.
- Note on 0.11.17's sequencing: chaining gear -> skills -> CP means the three
  parts now need successive out-of-combat windows instead of sharing one, so
  short windows are slightly less forgiving than when they ran in parallel.
  That's the price of never slotting skills for a weapon that isn't equipped
  yet; recorded here because it is a real trade-off, not a free win.

## 0.11.19

- Add: "Learn this boss" button in the Assign tab. Standing in front of a boss
  with that boss selected as the target, it captures the name your client
  actually returns (`GetUnitName`) and stores it against the stable boss key.
  From then on that boss is detected regardless of client language, including
  the ones with no verified translation shipped (Lucent Citadel's Arcane Knot
  and all six Ossein Cage bosses).
- Why a name and not an ID: the engine exposes no persistent NPC identifier.
  There is no `GetUnitId(unitTag)` and no monster id; the `unitId` values from
  `EVENT_COMBAT_EVENT` are per-session and get reassigned on every spawn, so
  they cannot be stored. Verified against ESOUIDocumentation.txt. The only
  stable thing the engine gives per unit tag is the name, already localised.
- Wizard's Wardrobe solves the same problem by comparing localised against
  localised - `GetUnitName()` against a dropdown that also comes from its own
  `lang/<language>.lua`, so it never crosses languages. The cost it pays is
  that its stored identifier *is* the localised name, so changing client
  language orphans its saved conditions. Here the learned name is stored
  against the stable key rather than replacing it, so changing game language
  invalidates no assignment - at worst the name has to be learned again.
- The shipped `name`/`nameEs` table stays as the starting value so detection
  works out of the box without learning anything; learned names take priority.
- Learned names live in `sv.bossNames[trialTag][bossKey]` and are deliberately
  left untouched by "reset to defaults", same as kits and builds - they are
  captured data, not settings.
- Note: boss-area detection itself never depended on any of this.
  `Context.state.bossActive` comes from `DoesUnitExist("bossN")` plus
  `EVENT_BOSSES_CHANGED` - a plain engine boolean with no strings involved,
  the same pattern the native boss health bar uses (`bossbar.lua`). Trash vs
  boss switching, and therefore substitute builds, were always language-proof.
  Names only ever mattered for assigning a build to one *specific* boss.

## 0.11.18

- Fix: auto-equip did nothing at all in trials that still had old-style
  per-kit assignments left over from before the 0.10.0 switch to builds (no
  skills/CP, gear only) - even when a valid substitute build was configured
  and would otherwise have applied. `Builds.ResolveForCurrentContext` was
  treating "found an old kit assignment" the same as "found a build",
  stopping before it ever tried the substitute fallback. Now it only counts
  a real build assignment as a match; a leftover kit-only assignment falls
  through to the substitute, same as if nothing had been assigned at all.
- Fix: boss detection by name (`Zones.FindBossByName`) only ever compared
  against the English boss name hardcoded in `zones_trials.lua`, while
  `GetUnitName()` returns the name in the client's actual game language. On
  a non-English client, per-boss build assignments (the kind already used
  for Lucent Citadel and Hel Ra Citadel) silently never matched and always
  fell back to the trash target. Added the verified Spanish name for each
  boss (cross-checked against Wizard's Wardrobe's own per-language boss
  matching in production) and match against either. Two exceptions remain
  unverified - Lucent Citadel's "Arcane Knot" and all six Ossein Cage bosses
  - because Wizard's Wardrobe itself has no Spanish translation for those
  either; they'll keep falling back to trash on a Spanish client until the
  real in-game name is confirmed.

## 0.11.17

- Fix: auto-equip could leave you with a partially applied build - missing
  gear pieces that were actually in your bags, or skills slotted for a weapon
  you weren't holding yet. Root cause, found by comparing against Wizard's
  Wardrobe's production code: gear equip only checked "not in combat" once
  before a whole batch of pieces, not before each individual piece, so combat
  starting mid-batch (very plausible right when the boss that triggered the
  auto-equip engages you) silently failed the remaining pieces while still
  counting them as equipped. On top of that, gear/skills/CP were applied as
  three independent parallel tasks with no ordering between them, so skills
  could slot in before gear had actually finished.
- Fix: `EquipOne` now re-reads the worn slot after calling `EquipItem` and only
  counts a piece as equipped if the read-back confirms it - matches the same
  reasoning that led to verifying CP purchases in 0.11.14 instead of trusting
  the request was accepted. Failed pieces are reported separately in chat
  (`EZOARM_MSG_EQUIP_FAILED`), the same way missing/in-bank pieces already are.
- Fix: `Equip.ApplyKits` now re-checks "out of combat" before every single
  piece, not once for the whole batch - verified against Wizard's Wardrobe's
  `MoveItems`, which does the same per-item recheck in production.
- Fix: `Builds.Equip` now applies gear, skills and CP strictly in sequence
  (skills only start once gear's report has arrived, CP only once skills'
  has) instead of three parallel LibAsync tasks - verified against Wizard's
  Wardrobe's `LoadSetup`, which chains the three the same way.
- Fix: auto-equip's "don't repeat what's already applied" guard used to mark
  a build as done the instant it started equipping it, not when it actually
  finished. A real equip failure (as opposed to a piece genuinely missing
  from your bags) now clears that guard, so the next context change can
  retry instead of staying half-applied until you change zone.
- Boss/zone detection (world bosses, dungeons) was reviewed against Wizard's
  Wardrobe too and found already equivalent: `EVENT_BOSSES_CHANGED` is a
  generic engine event, not trial-specific, and the dungeon-vs-overland split
  already uses the same `GetCurrentZoneDungeonDifficulty()` check WW uses. No
  changes needed there.

## 0.11.16

- The build name in the Builds list now also picks up the status color
  (red for errors, amber for warnings), not just the little number next
  to it. Same coherence check as before (`Builds.Analyze`), just easier
  to spot without having to look for the number.

## 0.11.15

- Add: when equipping a gear kit, a piece that isn't worn or in your backpack
  is now checked against your bank too. If it's sitting there, the chat
  report says so explicitly instead of just "missing" - `GetItemLinkStacks`
  gives an exact bank count remotely, the same API that shows "Bank: X" on
  any item tooltip, so no visit to a banker or per-character log is needed.
  Kits captured before this update don't have the item link stored yet, so
  they'll keep reporting a plain "missing" until recaptured; new captures are
  covered automatically.

## 0.11.14

- Fix: applying a CP kit reported stars as "slotted" the moment the purchase
  request was sent, without waiting for the server's actual confirmation
  (`EVENT_CHAMPION_PURCHASE_RESULT`). On a rejection - wrong bar discipline,
  CP disabled here, cooldown, in combat, etc. - the kit report would still
  claim success even though nothing changed on the CP bar.
- Now waits for the real result before counting a star as slotted. Transient
  failures (cooldown, in combat - a timing race, not a real rejection)
  automatically retry once after the bar is ready again; everything else is
  honestly counted as skipped instead of slotted, with a safety timeout in
  case the server never answers.
- Reworded the "skipped" CP chat message: it no longer says "not purchased",
  since a skip can now also mean the server rejected the request for another
  reason, not just that the star wasn't unlocked.

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
