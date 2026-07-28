EZOARMORY_STRINGS_EN = {
    -- -------------------------------------------------------------------------
    -- Keybind category and names (shown in the Controls screen).
    -- Deben definirse aqui, no en Bindings.xml: ESO resuelve estos SI_* desde
    -- las cadenas registradas por el addon (ZO_CreateStringId/SafeAddString).
    -- Sin ellas la categoria no aparece en Controles.
    -- -------------------------------------------------------------------------
    SI_BINDING_CATEGORY_EZOARMORY = "E|cB040FFZ|rOArmory",
    SI_BINDING_NAME_EZOARMORY_TOGGLE_WINDOW = "Open EZOArmory",

    EZOARM_MSG_INIT = "EZOArmory loaded. Type /ezoarmory to open the window.",

    EZOARM_WINDOW_CONTEXT_NONE = "Not in a trial",
    EZOARM_WINDOW_PLACEHOLDER = "The kit lists, the twelve-slot grid and the per-boss assignments are being built here.\n\nFor now use Settings > EZO > EZOArmory.",

    EZOARM_OPTION_GENERAL = "General",
    EZOARM_OPTION_GENERAL_HEADER_TOOLTIP = "Core EZOArmory options: language and diagnostics.",

    EZOARM_OPTION_LANGUAGE = "Language",
    EZOARM_OPTION_LANGUAGE_TOOLTIP = "Language used by EZOArmory. Automatic follows the ESO client language.",
    EZOARM_OPTION_LANGUAGE_AUTO = "Automatic",
    EZOARM_OPTION_LANGUAGE_EN = "English",
    EZOARM_OPTION_LANGUAGE_ES = "Spanish",

    EZOARM_OPTION_DEBUG_MODE = "Debug mode",
    EZOARM_OPTION_DEBUG_MODE_TOOLTIP = "Send technical diagnostics to LibDebugLogger. Does not affect normal play.",

    -- Kits
    EZOARM_OPTION_KITS = "Kits",
    EZOARM_OPTION_KITS_HEADER_TOOLTIP = "A kit is a reusable block of gear pieces, such as five body pieces of one set or a two-piece monster set. Create a kit once and assign it to as many encounters as you need. Kits are shared by the whole character; only the assignments belong to each role.",

    EZOARM_OPTION_ROLE = "Active role",
    EZOARM_OPTION_ROLE_TOOLTIP = "Role profile used for kit assignments. The kits themselves are shared across the character.",
    EZOARM_OPTION_ROLE_AUTO = "Detect role automatically",
    EZOARM_OPTION_ROLE_AUTO_TOOLTIP = "Use the role you have selected in the game's group finder (tank, healer or damage) as the active profile. Each role keeps its own assignments. Untick to pick the role by hand.",
    EZOARM_ROLE_DD = "Damage",
    EZOARM_ROLE_TANK = "Tank",
    EZOARM_ROLE_HEALER = "Healer",

    EZOARM_OPTION_KIT_NAME = "New kit name",
    EZOARM_OPTION_KIT_NAME_TOOLTIP = "Name for the kit you are about to capture, for example \"Null Arca 5 body\".",

    EZOARM_OPTION_KIT_PRESET = "Pieces to capture",
    EZOARM_OPTION_KIT_PRESET_TOOLTIP = "Built from the gear you are wearing: everything, a whole set with its piece count, or a single piece by name. The list refreshes when the panel is reopened or after capturing a kit.",
    EZOARM_PRESET_ALL = "Everything equipped",

    EZOARM_SLOT_HEAD = "Head",
    EZOARM_SLOT_SHOULDERS = "Shoulders",
    EZOARM_SLOT_CHEST = "Chest",
    EZOARM_SLOT_WAIST = "Waist",
    EZOARM_SLOT_HANDS = "Hands",
    EZOARM_SLOT_LEGS = "Legs",
    EZOARM_SLOT_FEET = "Feet",
    EZOARM_SLOT_NECK = "Necklace",
    EZOARM_SLOT_RING1 = "Ring 1",
    EZOARM_SLOT_RING2 = "Ring 2",
    EZOARM_SLOT_MAIN = "Main hand",
    EZOARM_SLOT_OFF = "Off hand",
    EZOARM_SLOT_BACKUP_MAIN = "Main hand (back)",
    EZOARM_SLOT_BACKUP_OFF = "Off hand (back)",

    EZOARM_ARMOR_LIGHT = "light",
    EZOARM_ARMOR_MEDIUM = "medium",
    EZOARM_ARMOR_HEAVY = "heavy",

    EZOARM_CAT_ARMOR = "armour",
    EZOARM_CAT_JEWELRY = "jewelry",
    EZOARM_CAT_WEAPONS_FRONT = "weapons",
    EZOARM_CAT_WEAPONS_BACK = "weapons (back)",

    EZOARM_OPTION_KIT_CAPTURE = "Capture from equipped gear",
    EZOARM_OPTION_KIT_CAPTURE_TOOLTIP = "Create a kit from the pieces you are wearing right now, limited to the selection above.",

    EZOARM_OPTION_KIT_CAPTURE_ALL = "Capture everything worn as kits",
    EZOARM_OPTION_KIT_CAPTURE_ALL_TOOLTIP = "Create kits from everything you are wearing in a single step: one per multi-piece set, plus one for each loose piece (mythics, setless weapons, or a single piece of a set such as a Slimecraw head). It also captures your current skill bars and Champion stars as their own kits, listed in their own sections. Each gear kit is named after its key word plus where it sits, for example \"Null Arca - armour\". Anything identical to an existing kit is skipped, so re-running never creates duplicates.",
    EZOARM_MSG_KITS_CAPTURED_ALL = "Created <<1>> kits, skipped <<2>>.",

    EZOARM_OPTION_KIT_LIST = "Saved kits",
    EZOARM_OPTION_KIT_LIST_TOOLTIP = "Select a saved kit. The number in brackets is how many pieces it holds.",
    EZOARM_OPTION_KIT_DELETE = "Delete selected kit",
    EZOARM_OPTION_KIT_DELETE_TOOLTIP = "Remove the selected kit and any reference to it in the role assignments.",
    EZOARM_OPTION_KIT_SHOW = "Show selected kit",
    EZOARM_OPTION_KIT_SHOW_TOOLTIP = "Print the pieces stored in the selected kit.",

    EZOARM_OPTION_KIT_EQUIP = "Equip selected kit",
    EZOARM_OPTION_KIT_EQUIP_TOOLTIP = "Put on the pieces of the selected kit. Gear can only be changed out of combat, so if you are fighting it waits and equips the moment combat ends. Pieces must be in your backpack; anything in the bank is reported as missing.",
    EZOARM_MSG_EQUIP_QUEUED = "In combat: EZOArmory will equip the kit as soon as you are out of combat.",
    EZOARM_MSG_EQUIP_DONE = "Equipped <<1>>, already on <<2>>, missing <<3>>.",
    EZOARM_MSG_EQUIP_MISSING = "Not available in your backpack: <<1>>.",
    EZOARM_MSG_EQUIP_NO_LIBASYNC = "Equipping needs the LibAsync add-on. Install it to enable this.",
    EZOARM_MSG_EQUIP_EMPTY = "The selected kit has nothing to equip.",

    -- Skill kits
    EZOARM_OPTION_SKILL_KITS = "Skill kits",
    EZOARM_OPTION_SKILL_KITS_HEADER_TOOLTIP = "A skill kit memorises both action bars (five abilities plus the ultimate on each). The weapons equipped when capturing are stored with it and shown as icons for the front and back bar, since abilities depend on the weapon type. Skill kits live apart from gear kits.",
    EZOARM_OPTION_SKILL_KIT_NAME = "New skill kit name",
    EZOARM_OPTION_SKILL_KIT_NAME_TOOLTIP = "Optional. Leave empty to name it automatically (Skills 1, Skills 2...).",
    EZOARM_OPTION_SKILL_KIT_CAPTURE = "Capture current skill bars",
    EZOARM_OPTION_SKILL_KIT_CAPTURE_TOOLTIP = "Memorise the abilities currently slotted on both bars, together with the weapons you are holding. Nothing is created if an identical skill kit already exists.",
    EZOARM_OPTION_SKILL_KIT_LIST = "Saved skill kits",
    EZOARM_OPTION_SKILL_KIT_LIST_TOOLTIP = "Select a saved skill kit. The icons are the weapons of the front and back bar it was captured with; the number is how many abilities it holds.",
    EZOARM_OPTION_SKILL_KIT_SHOW_TOOLTIP = "Print each bar of the selected skill kit with its weapon and abilities.",
    EZOARM_OPTION_SKILL_KIT_DELETE_TOOLTIP = "Remove the selected skill kit.",
    EZOARM_MSG_SKILL_KIT_CREATED = "Skill kit created: <<1>>.",
    EZOARM_MSG_SKILL_KIT_DUPLICATE = "Not created: the skill kit <<1>> already holds exactly these bars.",
    EZOARM_MSG_SKILL_KIT_EMPTY = "No abilities slotted to capture.",
    EZOARM_MSG_SKILL_KIT_DELETED = "Skill kit deleted: <<1>>.",
    EZOARM_AUTONAME_SKILLS = "Skills",

    -- CP kits
    EZOARM_OPTION_CP_KITS = "Champion Point kits",
    EZOARM_OPTION_CP_KITS_HEADER_TOOLTIP = "A CP kit memorises the twelve slotted Champion stars. Kits with the same stars in a different order count as the same kit. Applying CP has an in-game cooldown, so these kits are meant to be applied when preparing, not mid-fight.",
    EZOARM_OPTION_CP_KIT_NAME = "New CP kit name",
    EZOARM_OPTION_CP_KIT_NAME_TOOLTIP = "Optional. Leave empty to name it automatically (CP 1, CP 2...).",
    EZOARM_OPTION_CP_KIT_CAPTURE = "Capture current Champion stars",
    EZOARM_OPTION_CP_KIT_CAPTURE_TOOLTIP = "Memorise the Champion stars currently slotted. Nothing is created if a kit with the same stars already exists.",
    EZOARM_OPTION_CP_KIT_LIST = "Saved CP kits",
    EZOARM_OPTION_CP_KIT_LIST_TOOLTIP = "Select a saved CP kit. The number is how many stars it holds.",
    EZOARM_OPTION_CP_KIT_SHOW_TOOLTIP = "Print the stars of the selected CP kit.",
    EZOARM_OPTION_CP_KIT_DELETE_TOOLTIP = "Remove the selected CP kit.",
    EZOARM_MSG_CP_KIT_CREATED = "CP kit created: <<1>>.",
    EZOARM_MSG_CP_KIT_DUPLICATE = "Not created: the CP kit <<1>> already holds exactly these stars.",
    EZOARM_MSG_CP_KIT_EMPTY = "No Champion stars slotted to capture.",
    EZOARM_MSG_CP_KIT_DELETED = "CP kit deleted: <<1>>.",
    EZOARM_AUTONAME_CP = "CP",

    EZOARM_OPTION_ASSIGN = "Assignments",
    EZOARM_OPTION_ASSIGN_HEADER_TOOLTIP = "Assign kits to each trial and target. Assignments belong to the active role. Pick a kit in Saved kits above, then add it here. A target can hold one kit with everything or several kits, and you do not have to fill them all. For every trial you set Trash and each boss independently; a target with nothing of its own falls back to the trial default.",
    EZOARM_OPTION_ASSIGN_TRIAL = "Trial",
    EZOARM_OPTION_ASSIGN_TRIAL_TOOLTIP = "Which trial you are setting up.",
    EZOARM_OPTION_ASSIGN_TARGET = "Target",
    EZOARM_OPTION_ASSIGN_TARGET_TOOLTIP = "Where in the trial these kits apply: the trial default (used when a target has nothing of its own), Trash, or a specific boss or miniboss.",
    EZOARM_TARGET_DEFAULT = "Trial default (fallback)",
    EZOARM_TARGET_TRASH = "Trash",
    EZOARM_OPTION_ASSIGN_PICK = "Kit",
    EZOARM_OPTION_ASSIGN_PICK_TOOLTIP = "Pick the kit to add to or remove from this target. Kits already assigned here are marked in the list.",
    EZOARM_ASSIGNED_MARK = "|c00FF00+|r",
    EZOARM_OPTION_ASSIGN_CURRENT = "Kits assigned here",
    EZOARM_MSG_ASSIGN_EMPTY = "(none - inherits the trial default)",
    EZOARM_OPTION_ASSIGN_ADD = "Add kit here",
    EZOARM_OPTION_ASSIGN_ADD_TOOLTIP = "Add the kit picked above to this target. A target can hold several kits.",
    EZOARM_OPTION_ASSIGN_REMOVE = "Remove kit",
    EZOARM_OPTION_ASSIGN_REMOVE_TOOLTIP = "Remove the kit picked above from this target.",
    EZOARM_OPTION_ASSIGN_CLEAR = "Clear this target",
    EZOARM_OPTION_ASSIGN_CLEAR_TOOLTIP = "Remove every kit from this target so it inherits the trial default again.",

    EZOARM_OPTION_EQUIP_TARGET = "Equip this target's kits",
    EZOARM_OPTION_EQUIP_TARGET_TOOLTIP = "Equip the kits assigned to the trial and target selected above, wherever you are. Useful for testing and for preparing before entering.",
    EZOARM_OPTION_EQUIP_HERE = "Equip for my current location",
    EZOARM_OPTION_EQUIP_HERE_TOOLTIP = "Equip the kits assigned to where you are right now: the active role's build for the current boss, or the trash build, of the trial you are in. Waits until out of combat.",
    EZOARM_MSG_EQUIP_NO_TRIAL = "You are not in a trial right now.",
    EZOARM_MSG_EQUIP_NO_ASSIGNMENT = "No kits assigned for here in <<1>> (and no trial default).",

    EZOARM_OPTION_ANALYZE_WORN = "Analyse current gear",
    EZOARM_OPTION_ANALYZE_WORN_TOOLTIP = "Report which set bonuses are actually active on each weapon bar with the gear you are wearing. Only 12 pieces count at a time, so a set spread over jewelry and front weapons will not be complete on the back bar.",

    -- Mensajes
    EZOARM_MSG_KIT_NEED_NAME = "Give the kit a name first.",
    EZOARM_MSG_KIT_NO_PIECES = "Nothing captured. Check that you are wearing the selected slots.",
    EZOARM_MSG_KIT_CREATED = "Kit created: <<1>> (<<2>> pieces).",
    EZOARM_MSG_KIT_DUPLICATE = "Not created: the kit <<1>> already holds exactly these pieces.",
    EZOARM_MSG_KIT_DELETED = "Kit deleted: <<1>>.",
    EZOARM_MSG_KIT_NONE_SELECTED = "No kit selected.",
    EZOARM_MSG_BAR_FRONT = "Front bar",
    EZOARM_MSG_BAR_BACK = "Back bar",
    EZOARM_MSG_PIECES = "pieces",
    EZOARM_MSG_NO_SETS = "no set pieces",
}
