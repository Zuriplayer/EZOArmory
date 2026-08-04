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

    EZOARM_WINDOW_TAB_GEAR = "Gear kits",
    EZOARM_WINDOW_TAB_SKILLS = "Skill kits",
    EZOARM_WINDOW_TAB_CP = "CP kits",
    EZOARM_WINDOW_TAB_ASSIGN = "Assign",
    EZOARM_WINDOW_ASSIGN_ROLE = "Role: <<1>>",
    EZOARM_ASSIGN_APPLIES_HERE = "What applies here",
    EZOARM_ASSIGN_NOTHING = "Nothing assigned, and the trial has no default either.",
    EZOARM_ASSIGN_OWN = "<<1>>",
    EZOARM_ASSIGN_INHERITED = "<<1>> (inherited from the trial default)",
    EZOARM_ASSIGN_INCOMPLETE = "incomplete, it will not be equipped",
    EZOARM_ASSIGN_INCOMPLETE_MARK = "(!)",
    EZOARM_ASSIGN_LEGACY_KITS = "Old kit assignment: <<1>>. Assign a build to replace it.",

    -- Substitute builds
    EZOARM_AUTOEQUIP_LABEL = "Auto-equip",
    EZOARM_AUTOEQUIP_HINT = "When on, EZOArmory equips things for you as you move around: the build assigned to wherever you are (trial default, trash, a specific boss), or the substitute build below if nothing is assigned and it applies to this kind of zone. When off, nothing equips itself - everything stays manual.",
    EZOARM_SUBSTITUTE_HEADER = "Substitute builds",
    EZOARM_SUBSTITUTE_HINT = "Used wherever nothing is assigned: boss in sight equips the boss build, otherwise the trash one. Outside trials this depends on the zone declaring its bosses, which not every zone does - older dungeons tend to be worse than newer ones.",
    EZOARM_SUBSTITUTE_TRIALS = "Trials",
    EZOARM_SUBSTITUTE_DUNGEONS = "Dungeons",
    EZOARM_SUBSTITUTE_OVERLAND = "Overland",
    EZOARM_SUBSTITUTE_TRASH = "Trash build",
    EZOARM_SUBSTITUTE_BOSS = "Boss build",
    EZOARM_MSG_AUTO_EQUIP = "Equipping <<1>>.",

    -- Inventory marker
    EZOARM_OPTION_INVENTORY_MARKER = "Mark saved pieces in the inventory",
    EZOARM_OPTION_INVENTORY_MARKER_TOOLTIP = "Puts a purple Z on any inventory item that belongs to one of your kits, so you can see at a glance what not to deconstruct or sell. Hovering it tells you where it is used. Takes effect after a reload.",
    EZOARM_MARKER_IN_KITS = "Kits: <<1>>",
    EZOARM_MARKER_IN_BUILDS = "Builds: <<1>>",
    EZOARM_WINDOW_KIT_COUNT = "<<1>> kit(s)",
    EZOARM_WINDOW_NO_KITS = "No kits in this category yet. Capture some from Settings > EZO > EZOArmory.",
    EZOARM_WINDOW_TOOLTIP_NOT_AVAILABLE = "Not currently available in your bags.",

    EZOARM_OPTION_GENERAL = "General",
    EZOARM_OPTION_GENERAL_HEADER_TOOLTIP = "Core EZOArmory options: language and diagnostics.",

    EZOARM_OPTION_LANGUAGE = "Language",
    EZOARM_OPTION_LANGUAGE_TOOLTIP = "Language used by EZOArmory. Automatic follows the ESO client language.",
    EZOARM_OPTION_LANGUAGE_AUTO = "Automatic",
    EZOARM_OPTION_LANGUAGE_EN = "English",
    EZOARM_OPTION_LANGUAGE_ES = "Spanish",

    EZOARM_OPTION_DEBUG_MODE = "Debug mode",
    EZOARM_OPTION_DEBUG_MODE_TOOLTIP = "Send technical diagnostics to LibDebugLogger. Does not affect normal play.",

    EZOARM_OPTION_RESET_DEFAULTS = "Restore default settings",
    EZOARM_OPTION_RESET_DEFAULTS_TOOLTIP = "Resets language, role mode, the inventory marker, auto-equip and the window's position and size back to their defaults. Does not touch your kits, builds or assignments.",
    EZOARM_DIALOG_RESET_TITLE = "Restore default settings",
    EZOARM_DIALOG_RESET_TEXT = "This resets language, role mode, the inventory marker, auto-equip and the window back to their defaults. Your kits, builds and assignments are not touched. Continue?",
    EZOARM_MSG_RESET_DONE = "Settings restored to their defaults.",

    -- Role
    EZOARM_OPTION_ROLE = "Active role",
    EZOARM_OPTION_ROLE_TOOLTIP = "Role profile used for kit assignments. The kits themselves are shared across the character.",
    EZOARM_OPTION_ROLE_AUTO = "Detect role automatically",
    EZOARM_OPTION_ROLE_AUTO_TOOLTIP = "Use the role you have selected in the game's group finder (tank, healer or damage) as the active profile. Each role keeps its own assignments. Untick to pick the role by hand.",
    EZOARM_ROLE_DD = "Damage",
    EZOARM_ROLE_TANK = "Tank",
    EZOARM_ROLE_HEALER = "Healer",
    EZOARM_ROLE_UNCERTAIN = "Unclear",
    EZOARM_ROLE_UNKNOWN = "No role",

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
    EZOARM_ARMOR_UNKNOWN = "unknown weight",

    EZOARM_CAT_ARMOR = "armour",
    EZOARM_CAT_JEWELRY = "jewelry",
    EZOARM_CAT_WEAPONS_FRONT = "weapons",
    EZOARM_CAT_WEAPONS_BACK = "weapons (back)",

    EZOARM_MSG_KITS_CAPTURED_ALL = "Created <<1>> kits, <<2>> already existed.",
    -- Textos de boton de la ventana: cortos a proposito, el ancho de la barra
    -- de acciones es fijo y los largos del panel de opciones no caben.
    EZOARM_WINDOW_CAPTURE_GEAR = "Capture worn gear",
    EZOARM_WINDOW_CAPTURE_SKILLS = "Capture bars",
    EZOARM_WINDOW_CAPTURE_CP = "Capture stars",
    EZOARM_WINDOW_BTN_EQUIP = "Equip kit",
    EZOARM_WINDOW_BTN_RENAME = "Rename",
    EZOARM_WINDOW_BTN_DELETE = "Delete",
    EZOARM_BTN_EQUIP_SHORT = "Equip",

    EZOARM_DIALOG_RENAME_TITLE = "Rename kit",
    EZOARM_DIALOG_RENAME_TEXT = "New name for this kit:",

    EZOARM_MSG_EQUIP_QUEUED = "In combat: EZOArmory will equip the kit as soon as you are out of combat.",
    EZOARM_MSG_EQUIP_DONE = "Equipped <<1>>, already on <<2>>, missing <<3>>.",
    EZOARM_MSG_EQUIP_MISSING = "Not available in your backpack: <<1>>.",
    EZOARM_MSG_EQUIP_IN_BANK = "In your bank, not your backpack: <<1>>.",
    EZOARM_MSG_EQUIP_NO_LIBASYNC = "Equipping needs the LibAsync add-on. Install it to enable this.",
    EZOARM_MSG_EQUIP_EMPTY = "The selected kit has nothing to equip.",
    EZOARM_MSG_EQUIP_QUEUED_CP_COOLDOWN = "Champion Points are on cooldown: EZOArmory will slot the kit as soon as it is available.",

    -- Skill kits
    EZOARM_MSG_SKILL_KIT_CREATED = "Skill kit created: <<1>>.",
    EZOARM_MSG_SKILL_KIT_DUPLICATE = "Not created: the skill kit <<1>> already holds exactly these bars.",
    EZOARM_MSG_SKILL_KIT_EMPTY = "No abilities slotted to capture.",
    EZOARM_AUTONAME_SKILLS = "Skills",
    EZOARM_MSG_SKILL_EQUIP_DONE = "Slotted <<1>>, already set <<2>>, skipped <<3>>.",
    EZOARM_MSG_SKILL_EQUIP_SKIPPED = "Not unlocked, skipped: <<1>>.",
    EZOARM_MSG_SKILL_EQUIP_EMPTY = "The selected skill kit has nothing to slot.",

    -- CP kits
    EZOARM_MSG_CP_KIT_CREATED = "CP kit created: <<1>>.",
    EZOARM_MSG_CP_KIT_DUPLICATE = "Not created: the CP kit <<1>> already holds exactly these stars.",
    EZOARM_MSG_CP_KIT_EMPTY = "No Champion stars slotted to capture.",
    EZOARM_MSG_CP_EQUIP_DONE = "Slotted <<1>>, already set <<2>>, skipped <<3>>.",
    -- No dice "not purchased": desde que se verifica el resultado real del
    -- servidor (equip.lua SendAndVerifyCp), una estrella tambien puede
    -- quedar aqui por otro motivo (disciplina equivocada, CP desactivado en
    -- esta zona, cooldown agotados los reintentos...), no solo por no estar
    -- comprada.
    EZOARM_MSG_CP_EQUIP_SKIPPED = "Skipped, not slotted: <<1>>.",
    EZOARM_MSG_CP_EQUIP_EMPTY = "The selected CP kit has nothing to slot.",

    -- Builds
    EZOARM_WINDOW_TAB_BUILDS = "Builds",
    EZOARM_BUILD_COUNT = "<<1>> build(s)",
    EZOARM_BUILD_NO_BUILDS = "No builds yet.",
    EZOARM_BUILD_EMPTY_HINT = "A build is what you actually equip: it combines your gear kits with one skill kit and one CP kit.\n\nPress |cFFFFFFNew build|r below to create one and give it a name. Its editor opens right away, and that is where you add kits to it.",
    EZOARM_BUILD_EDIT_HINT = "Select a build to equip or edit it. Double-click it to jump straight to its kits.",
    EZOARM_BUILD_EDITOR_TITLE = "Build: <<1>>",
    EZOARM_BUILD_NEW = "New build",
    EZOARM_BUILD_FROM_WORN = "Copy worn setup",
    EZOARM_BUILD_EQUIP = "Equip build",
    EZOARM_BUILD_DELETE = "Delete build",
    EZOARM_MSG_BUILD_FROM_WORN = "Build <<1>> created from what you are wearing: <<2>> new kit(s), <<3>> reused.",
    EZOARM_BUILD_EDIT = "Edit build",
    EZOARM_BUILD_BACK = "Back to list",
    EZOARM_BUILD_AUTONAME = "Build",
    EZOARM_DIALOG_BUILD_NAME_TITLE = "Build name",
    EZOARM_DIALOG_BUILD_NAME_TEXT = "Name for this build:",
    EZOARM_BUILD_SECTION_GEAR = "Gear kits in this build",
    EZOARM_BUILD_SECTION_SKILLS = "Skill kit",
    EZOARM_BUILD_SECTION_CP = "CP kit",
    EZOARM_BUILD_SECTION_ROLE = "Role",
    EZOARM_BUILD_SECTION_ISSUES = "Checks",
    EZOARM_BUILD_ROLE_AUTO = "Automatic (<<1>>)",
    EZOARM_BUILD_ADD_GEAR_KIT = "Add gear kit",
    EZOARM_BUILD_NONE_SELECTED = "(none selected)",
    EZOARM_BUILD_ALL_GOOD = "Everything checks out.",
    EZOARM_MSG_BUILD_CREATED = "Build created: <<1>>.",
    EZOARM_MSG_BUILD_DELETED = "Build deleted: <<1>>.",
    EZOARM_MSG_BUILD_INCOMPLETE = "That build is incomplete: fix the errors before equipping it.",
    EZOARM_MSG_BUILD_PART_GEAR = "Gear:",
    EZOARM_MSG_BUILD_PART_SKILLS = "Skills:",
    EZOARM_MSG_BUILD_PART_CP = "CP:",

    -- Build checks
    EZOARM_ISSUE_NO_GEAR_KITS = "No gear kits: the build has nothing to wear.",
    EZOARM_ISSUE_NO_SKILL_KIT = "No skill kit assigned.",
    EZOARM_ISSUE_NO_CP_KIT = "No CP kit assigned.",
    EZOARM_ISSUE_SLOT_CONFLICT = "<<1>>: two kits claim this slot (<<2>> and <<3>>).",
    EZOARM_ISSUE_UNASSIGNED_SLOT = "<<1>>: nothing assigned on the <<2>> bar.",
    EZOARM_ISSUE_SET_OVERFILL = "<<1>>: <<2>> pieces on the <<3>> bar, but the set only counts <<4>>.",
    EZOARM_ISSUE_MULTIPLE_MYTHICS = "More than one mythic: only one can be worn.",
    EZOARM_ISSUE_DUPLICATE_ITEM = "The same item is used in two slots (<<1>> and <<2>>).",
    EZOARM_ISSUE_BAR_INCOMPLETE = "<<1>> bar: only <<2>> of <<3>> pieces count.",
    EZOARM_ISSUE_WEAPON_MISMATCH = "<<1>> bar: the skill kit <<2>> was captured with a different weapon.",
    EZOARM_ISSUE_EMPTY_KIT = "The kit <<1>> has no pieces.",
    EZOARM_ISSUE_UNKNOWN_SLOT = "Unknown slot in the kit <<1>>: <<2>>.",
    EZOARM_AUTONAME_CP = "CP",

    EZOARM_OPTION_ASSIGN_TRIAL = "Trial",
    EZOARM_OPTION_ASSIGN_TARGET = "Target",
    EZOARM_TARGET_DEFAULT = "Trial default (fallback)",
    EZOARM_TARGET_TRASH = "Trash",
    EZOARM_OPTION_ASSIGN_PICK = "Kit",
    EZOARM_OPTION_ASSIGN_CLEAR = "Clear this target",

    EZOARM_OPTION_EQUIP_TARGET = "Equip this target's kits",
    EZOARM_OPTION_EQUIP_HERE = "Equip for my current location",
    EZOARM_MSG_EQUIP_NO_TRIAL = "You are not in a trial right now.",
    EZOARM_MSG_EQUIP_NO_ASSIGNMENT = "No kits assigned for here in <<1>> (and no trial default).",

    EZOARM_OPTION_ANALYZE_WORN = "Analyse current gear",
    EZOARM_OPTION_ANALYZE_WORN_TOOLTIP = "Report which set bonuses are actually active on each weapon bar with the gear you are wearing. Only 12 pieces count at a time, so a set spread over jewelry and front weapons will not be complete on the back bar.",

    -- Mensajes
    EZOARM_MSG_BAR_FRONT = "Front bar",
    EZOARM_MSG_BAR_BACK = "Back bar",
    EZOARM_MSG_PIECES = "pieces",
    EZOARM_MSG_NO_SETS = "no set pieces",
}
