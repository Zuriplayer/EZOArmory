EZOARMORY_STRINGS_EN = {
    EZOARM_MSG_INIT = "EZOArmory loaded.",

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

    EZOARM_CAT_ARMOR = "armour",
    EZOARM_CAT_JEWELRY = "jewelry",
    EZOARM_CAT_WEAPONS_FRONT = "weapons",
    EZOARM_CAT_WEAPONS_BACK = "weapons (back)",

    EZOARM_OPTION_KIT_CAPTURE = "Capture from equipped gear",
    EZOARM_OPTION_KIT_CAPTURE_TOOLTIP = "Create a kit from the pieces you are wearing right now, limited to the selection above.",

    EZOARM_OPTION_KIT_CAPTURE_ALL = "Capture everything worn as kits",
    EZOARM_OPTION_KIT_CAPTURE_ALL_TOOLTIP = "Create kits from everything you are wearing in a single step: one per multi-piece set, plus one for each loose piece (mythics, setless weapons, or a single piece of a set such as a Slimecraw head). Each kit is named after its key word plus where it sits, for example \"Null Arca - armour\" or \"Slimecraw - Head\", so the same set used in different slots stays distinct. The full name is kept inside the kit and repeated names are numbered rather than skipped.",
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

    EZOARM_OPTION_ASSIGN = "Assignments",
    EZOARM_OPTION_ASSIGN_HEADER_TOOLTIP = "Assign kits to each trial and target. Assignments belong to the active role. For every trial you set the kits for Trash and for each boss independently; a target can hold one kit with everything or several kits, and you do not have to fill them all. A boss with nothing set falls back to the trial default.",
    EZOARM_OPTION_ASSIGN_TRIAL = "Trial",
    EZOARM_OPTION_ASSIGN_TRIAL_TOOLTIP = "Which trial you are setting up.",
    EZOARM_OPTION_ASSIGN_TARGET = "Target",
    EZOARM_OPTION_ASSIGN_TARGET_TOOLTIP = "Where in the trial these kits apply: the trial default (used when a target has nothing of its own), Trash, or a specific boss or miniboss.",
    EZOARM_TARGET_DEFAULT = "Trial default (fallback)",
    EZOARM_TARGET_TRASH = "Trash",
    EZOARM_OPTION_ASSIGN_KITS = "Kits for this target",
    EZOARM_OPTION_ASSIGN_KITS_TOOLTIP = "Pick the kits that make up the build for this target. Selecting none clears it so it inherits the trial default.",

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
    EZOARM_MSG_KIT_DELETED = "Kit deleted: <<1>>.",
    EZOARM_MSG_KIT_NONE_SELECTED = "No kit selected.",
    EZOARM_MSG_BAR_FRONT = "Front bar",
    EZOARM_MSG_BAR_BACK = "Back bar",
    EZOARM_MSG_PIECES = "pieces",
    EZOARM_MSG_NO_SETS = "no set pieces",
}
