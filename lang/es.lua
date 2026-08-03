EZOARMORY_STRINGS_ES = {
    -- -------------------------------------------------------------------------
    -- Categoria y nombres de keybind (pantalla de Controles).
    -- Deben definirse aqui, no en Bindings.xml: ESO resuelve estos SI_* desde
    -- las cadenas registradas por el addon (ZO_CreateStringId/SafeAddString).
    -- Sin ellas la categoria no aparece en Controles.
    -- -------------------------------------------------------------------------
    SI_BINDING_CATEGORY_EZOARMORY = "E|cB040FFZ|rOArmory",
    SI_BINDING_NAME_EZOARMORY_TOGGLE_WINDOW = "Abrir EZOArmory",

    EZOARM_MSG_INIT = "EZOArmory cargado. Escribe /ezoarmory para abrir la ventana.",

    EZOARM_WINDOW_CONTEXT_NONE = "Fuera de trial",

    EZOARM_WINDOW_TAB_GEAR = "Kits de equipo",
    EZOARM_WINDOW_TAB_SKILLS = "Kits de habilidades",
    EZOARM_WINDOW_TAB_CP = "Kits de CP",
    EZOARM_WINDOW_TAB_ASSIGN = "Asignar",
    EZOARM_WINDOW_ASSIGN_ROLE = "Rol: <<1>>",
    EZOARM_ASSIGN_APPLIES_HERE = "Que se aplica aqui",
    EZOARM_ASSIGN_NOTHING = "Sin asignar, y la trial tampoco tiene default.",
    EZOARM_ASSIGN_OWN = "<<1>>",
    EZOARM_ASSIGN_INHERITED = "<<1>> (heredada del default de la trial)",
    EZOARM_ASSIGN_INCOMPLETE = "incompleta, no se equipara",
    EZOARM_ASSIGN_INCOMPLETE_MARK = "(!)",
    EZOARM_ASSIGN_LEGACY_KITS = "Asignacion antigua por kits: <<1>>. Asigna una build para sustituirla.",

    -- Builds sustitutas
    EZOARM_AUTOEQUIP_LABEL = "Auto-equipar",
    EZOARM_AUTOEQUIP_HINT = "Con esto activado, EZOArmory equipa por ti segun te mueves: la build asignada a donde estes (default de la trial, trash, un boss concreto), o la build sustituta de abajo si no hay nada asignado y aplica a ese tipo de zona. Con esto desactivado, nada se equipa solo: todo queda manual.",
    EZOARM_SUBSTITUTE_HEADER = "Builds sustitutas",
    EZOARM_SUBSTITUTE_HINT = "Se usan donde no haya nada asignado: con boss delante se equipa la build de boss, si no la de trash. Fuera de las trials esto depende de que la zona declare sus bosses, y no todas lo hacen: las mazmorras antiguas suelen ir peor que las nuevas.",
    EZOARM_SUBSTITUTE_TRIALS = "Trials",
    EZOARM_SUBSTITUTE_DUNGEONS = "Mazmorras",
    EZOARM_SUBSTITUTE_OVERLAND = "Mundo",
    EZOARM_SUBSTITUTE_TRASH = "Build de trash",
    EZOARM_SUBSTITUTE_BOSS = "Build de boss",
    EZOARM_MSG_AUTO_EQUIP = "Equipando <<1>>.",

    -- Marca en inventario
    EZOARM_OPTION_INVENTORY_MARKER = "Marcar en el inventario las piezas guardadas",
    EZOARM_OPTION_INVENTORY_MARKER_TOOLTIP = "Pone una Z morada sobre cualquier item del inventario que forme parte de alguno de tus kits, para ver de un vistazo lo que no debes descomponer ni vender. Al pasar el cursor te dice donde se usa. Se aplica tras recargar la interfaz.",
    EZOARM_MARKER_IN_KITS = "Kits: <<1>>",
    EZOARM_MARKER_IN_BUILDS = "Builds: <<1>>",
    EZOARM_WINDOW_KIT_COUNT = "<<1>> kit(s)",
    EZOARM_WINDOW_NO_KITS = "Aun no hay kits en esta categoria. Captura alguno desde Ajustes > EZO > EZOArmory.",
    EZOARM_WINDOW_TOOLTIP_NOT_AVAILABLE = "No disponible ahora mismo en tu mochila.",

    EZOARM_OPTION_GENERAL = "General",
    EZOARM_OPTION_GENERAL_HEADER_TOOLTIP = "Opciones basicas de EZOArmory: idioma y diagnostico.",

    EZOARM_OPTION_LANGUAGE = "Idioma",
    EZOARM_OPTION_LANGUAGE_TOOLTIP = "Idioma que usa EZOArmory. Automatico sigue el idioma del cliente de ESO.",
    EZOARM_OPTION_LANGUAGE_AUTO = "Automatico",
    EZOARM_OPTION_LANGUAGE_EN = "Ingles",
    EZOARM_OPTION_LANGUAGE_ES = "Espanol",

    EZOARM_OPTION_DEBUG_MODE = "Modo depuracion",
    EZOARM_OPTION_DEBUG_MODE_TOOLTIP = "Envia diagnostico tecnico a LibDebugLogger. No afecta al juego normal.",

    EZOARM_OPTION_RESET_DEFAULTS = "Restaurar valores por defecto",
    EZOARM_OPTION_RESET_DEFAULTS_TOOLTIP = "Restaura idioma, modo de rol, marca de inventario, equipado automatico y la posicion/tamano de la ventana a sus valores por defecto. No toca tus kits, builds ni asignaciones.",
    EZOARM_DIALOG_RESET_TITLE = "Restaurar valores por defecto",
    EZOARM_DIALOG_RESET_TEXT = "Esto restaura idioma, modo de rol, marca de inventario, equipado automatico y la ventana a sus valores por defecto. Tus kits, builds y asignaciones no se tocan. ¿Continuar?",
    EZOARM_MSG_RESET_DONE = "Ajustes restaurados a sus valores por defecto.",

    -- Rol
    EZOARM_OPTION_ROLE = "Rol activo",
    EZOARM_OPTION_ROLE_TOOLTIP = "Perfil de rol que se usa para las asignaciones de kits. Los kits en si son comunes al personaje.",
    EZOARM_OPTION_ROLE_AUTO = "Detectar el rol automaticamente",
    EZOARM_OPTION_ROLE_AUTO_TOOLTIP = "Usa el rol que tienes elegido en el buscador de grupo del juego (tanque, sanador o dano) como perfil activo. Cada rol mantiene sus propias asignaciones. Desmarca para elegir el rol a mano.",
    EZOARM_ROLE_DD = "Dano",
    EZOARM_ROLE_TANK = "Tanque",
    EZOARM_ROLE_HEALER = "Sanador",
    EZOARM_ROLE_UNCERTAIN = "Duda",
    EZOARM_ROLE_UNKNOWN = "Sin rol",

    EZOARM_SLOT_HEAD = "Cabeza",
    EZOARM_SLOT_SHOULDERS = "Hombros",
    EZOARM_SLOT_CHEST = "Pecho",
    EZOARM_SLOT_WAIST = "Cintura",
    EZOARM_SLOT_HANDS = "Manos",
    EZOARM_SLOT_LEGS = "Piernas",
    EZOARM_SLOT_FEET = "Pies",
    EZOARM_SLOT_NECK = "Collar",
    EZOARM_SLOT_RING1 = "Anillo 1",
    EZOARM_SLOT_RING2 = "Anillo 2",
    EZOARM_SLOT_MAIN = "Arma principal",
    EZOARM_SLOT_OFF = "Arma secundaria",
    EZOARM_SLOT_BACKUP_MAIN = "Arma principal (T)",
    EZOARM_SLOT_BACKUP_OFF = "Arma secundaria (T)",

    EZOARM_ARMOR_LIGHT = "ligera",
    EZOARM_ARMOR_MEDIUM = "media",
    EZOARM_ARMOR_HEAVY = "pesada",
    EZOARM_ARMOR_UNKNOWN = "peso desconocido",

    EZOARM_CAT_ARMOR = "armadura",
    EZOARM_CAT_JEWELRY = "joyeria",
    EZOARM_CAT_WEAPONS_FRONT = "armas",
    EZOARM_CAT_WEAPONS_BACK = "armas (T)",

    EZOARM_MSG_KITS_CAPTURED_ALL = "Creados <<1>> kits, <<2>> ya existian.",
    -- Textos de boton de la ventana: cortos a proposito, el ancho de la barra
    -- de acciones es fijo y los largos del panel de opciones no caben.
    EZOARM_WINDOW_CAPTURE_GEAR = "Capturar equipo",
    EZOARM_WINDOW_CAPTURE_SKILLS = "Capturar barras",
    EZOARM_WINDOW_CAPTURE_CP = "Capturar estrellas",
    EZOARM_WINDOW_BTN_EQUIP = "Equipar kit",
    EZOARM_WINDOW_BTN_RENAME = "Renombrar",
    EZOARM_WINDOW_BTN_DELETE = "Borrar",
    EZOARM_BTN_EQUIP_SHORT = "Equipar",

    EZOARM_DIALOG_RENAME_TITLE = "Renombrar kit",
    EZOARM_DIALOG_RENAME_TEXT = "Nuevo nombre para este kit:",

    EZOARM_MSG_EQUIP_QUEUED = "En combate: EZOArmory equipara el kit en cuanto salgas de combate.",
    EZOARM_MSG_EQUIP_DONE = "Equipadas <<1>>, ya puestas <<2>>, no disponibles <<3>>.",
    EZOARM_MSG_EQUIP_MISSING = "No disponibles en la mochila: <<1>>.",
    EZOARM_MSG_EQUIP_NO_LIBASYNC = "El equipado necesita el addon LibAsync. Instalalo para activarlo.",
    EZOARM_MSG_EQUIP_EMPTY = "El kit seleccionado no tiene nada que equipar.",
    EZOARM_MSG_EQUIP_QUEUED_CP_COOLDOWN = "Los CP estan en tiempo de espera: EZOArmory ranurara el kit en cuanto este disponible.",

    -- Kits de habilidades
    EZOARM_MSG_SKILL_KIT_CREATED = "Kit de habilidades creado: <<1>>.",
    EZOARM_MSG_SKILL_KIT_DUPLICATE = "No se ha creado: el kit de habilidades <<1>> ya contiene exactamente estas barras.",
    EZOARM_MSG_SKILL_KIT_EMPTY = "No hay habilidades slotteadas que capturar.",
    EZOARM_AUTONAME_SKILLS = "Skills",
    EZOARM_MSG_SKILL_EQUIP_DONE = "Ranuradas <<1>>, ya puestas <<2>>, omitidas <<3>>.",
    EZOARM_MSG_SKILL_EQUIP_SKIPPED = "No desbloqueadas, omitidas: <<1>>.",
    EZOARM_MSG_SKILL_EQUIP_EMPTY = "El kit de habilidades seleccionado no tiene nada que ranurar.",

    -- Kits de CP
    EZOARM_MSG_CP_KIT_CREATED = "Kit de CP creado: <<1>>.",
    EZOARM_MSG_CP_KIT_DUPLICATE = "No se ha creado: el kit de CP <<1>> ya contiene exactamente estas estrellas.",
    EZOARM_MSG_CP_KIT_EMPTY = "No hay estrellas de Campeon slotteadas que capturar.",
    EZOARM_MSG_CP_EQUIP_DONE = "Ranuradas <<1>>, ya puestas <<2>>, omitidas <<3>>.",
    EZOARM_MSG_CP_EQUIP_SKIPPED = "No compradas, omitidas: <<1>>.",
    EZOARM_MSG_CP_EQUIP_EMPTY = "El kit de CP seleccionado no tiene nada que ranurar.",

    -- Builds
    EZOARM_WINDOW_TAB_BUILDS = "Builds",
    EZOARM_BUILD_COUNT = "<<1>> build(s)",
    EZOARM_BUILD_NO_BUILDS = "Todavia no hay builds.",
    EZOARM_BUILD_EMPTY_HINT = "Una build es lo que de verdad se equipa: combina tus kits de equipo con un kit de habilidades y uno de CP.\n\nPulsa |cFFFFFFNueva build|r abajo para crear una y ponerle nombre. Su editor se abre al momento, y ahi es donde le anades los kits.",
    EZOARM_BUILD_EDIT_HINT = "Selecciona una build para equiparla o editarla. Haz doble clic para ir directo a sus kits.",
    EZOARM_BUILD_EDITOR_TITLE = "Build: <<1>>",
    EZOARM_BUILD_NEW = "Nueva build",
    EZOARM_BUILD_FROM_WORN = "Copiar lo puesto",
    EZOARM_BUILD_EQUIP = "Equipar build",
    EZOARM_BUILD_DELETE = "Borrar build",
    EZOARM_MSG_BUILD_FROM_WORN = "Build <<1>> creada desde lo que llevas puesto: <<2>> kit(s) nuevos, <<3>> reutilizados.",
    EZOARM_BUILD_EDIT = "Editar build",
    EZOARM_BUILD_BACK = "Volver a la lista",
    EZOARM_BUILD_AUTONAME = "Build",
    EZOARM_DIALOG_BUILD_NAME_TITLE = "Nombre de la build",
    EZOARM_DIALOG_BUILD_NAME_TEXT = "Nombre para esta build:",
    EZOARM_BUILD_SECTION_GEAR = "Kits de equipo de esta build",
    EZOARM_BUILD_SECTION_SKILLS = "Kit de habilidades",
    EZOARM_BUILD_SECTION_CP = "Kit de CP",
    EZOARM_BUILD_SECTION_ROLE = "Rol",
    EZOARM_BUILD_SECTION_ISSUES = "Revisiones",
    EZOARM_BUILD_ROLE_AUTO = "Automatico (<<1>>)",
    EZOARM_BUILD_ADD_GEAR_KIT = "Anadir kit de equipo",
    EZOARM_BUILD_NONE_SELECTED = "(sin seleccionar)",
    EZOARM_BUILD_ALL_GOOD = "Todo correcto.",
    EZOARM_MSG_BUILD_CREATED = "Build creada: <<1>>.",
    EZOARM_MSG_BUILD_DELETED = "Build eliminada: <<1>>.",
    EZOARM_MSG_BUILD_INCOMPLETE = "Esa build esta incompleta: corrige los errores antes de equiparla.",
    EZOARM_MSG_BUILD_PART_GEAR = "Equipo:",
    EZOARM_MSG_BUILD_PART_SKILLS = "Habilidades:",
    EZOARM_MSG_BUILD_PART_CP = "CP:",

    -- Revisiones de build
    EZOARM_ISSUE_NO_GEAR_KITS = "Sin kits de equipo: la build no tiene nada que ponerse.",
    EZOARM_ISSUE_NO_SKILL_KIT = "Sin kit de habilidades asignado.",
    EZOARM_ISSUE_NO_CP_KIT = "Sin kit de CP asignado.",
    EZOARM_ISSUE_SLOT_CONFLICT = "<<1>>: dos kits reclaman este slot (<<2>> y <<3>>).",
    EZOARM_ISSUE_UNASSIGNED_SLOT = "<<1>>: sin asignar en la barra <<2>>.",
    EZOARM_ISSUE_SET_OVERFILL = "<<1>>: <<2>> piezas en la barra <<3>>, pero el set solo cuenta <<4>>.",
    EZOARM_ISSUE_MULTIPLE_MYTHICS = "Mas de un mitico: solo se puede llevar uno.",
    EZOARM_ISSUE_DUPLICATE_ITEM = "El mismo item se usa en dos slots (<<1>> y <<2>>).",
    EZOARM_ISSUE_BAR_INCOMPLETE = "Barra <<1>>: solo cuentan <<2>> de <<3>> piezas.",
    EZOARM_ISSUE_WEAPON_MISMATCH = "Barra <<1>>: el kit de habilidades <<2>> se capturo con otra arma.",
    EZOARM_ISSUE_EMPTY_KIT = "El kit <<1>> no tiene piezas.",
    EZOARM_ISSUE_UNKNOWN_SLOT = "Slot desconocido en el kit <<1>>: <<2>>.",
    EZOARM_AUTONAME_CP = "CP",

    EZOARM_OPTION_ASSIGN_TRIAL = "Trial",
    EZOARM_OPTION_ASSIGN_TARGET = "Objetivo",
    EZOARM_TARGET_DEFAULT = "Default de la trial (respaldo)",
    EZOARM_TARGET_TRASH = "Trash",
    EZOARM_OPTION_ASSIGN_PICK = "Kit",
    EZOARM_OPTION_ASSIGN_CLEAR = "Vaciar este objetivo",

    EZOARM_OPTION_EQUIP_TARGET = "Equipar los kits de este objetivo",
    EZOARM_OPTION_EQUIP_HERE = "Equipar para mi ubicacion actual",
    EZOARM_MSG_EQUIP_NO_TRIAL = "Ahora mismo no estas en una trial.",
    EZOARM_MSG_EQUIP_NO_ASSIGNMENT = "No hay kits asignados para aqui en <<1>> (ni default de la trial).",

    EZOARM_OPTION_ANALYZE_WORN = "Analizar el equipo actual",
    EZOARM_OPTION_ANALYZE_WORN_TOOLTIP = "Indica que bonus de set tienes realmente activos en cada barra de armas con el equipo que llevas. Solo cuentan 12 piezas a la vez, asi que un set repartido entre joyeria y armas frontales no estara completo en la barra trasera.",

    -- Mensajes
    EZOARM_MSG_BAR_FRONT = "Barra frontal",
    EZOARM_MSG_BAR_BACK = "Barra trasera",
    EZOARM_MSG_PIECES = "piezas",
    EZOARM_MSG_NO_SETS = "sin piezas de set",
}
