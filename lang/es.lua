EZOARMORY_STRINGS_ES = {
    EZOARM_MSG_INIT = "EZOArmory cargado.",

    EZOARM_OPTION_GENERAL = "General",
    EZOARM_OPTION_GENERAL_HEADER_TOOLTIP = "Opciones basicas de EZOArmory: idioma y diagnostico.",

    EZOARM_OPTION_LANGUAGE = "Idioma",
    EZOARM_OPTION_LANGUAGE_TOOLTIP = "Idioma que usa EZOArmory. Automatico sigue el idioma del cliente de ESO.",
    EZOARM_OPTION_LANGUAGE_AUTO = "Automatico",
    EZOARM_OPTION_LANGUAGE_EN = "Ingles",
    EZOARM_OPTION_LANGUAGE_ES = "Espanol",

    EZOARM_OPTION_DEBUG_MODE = "Modo depuracion",
    EZOARM_OPTION_DEBUG_MODE_TOOLTIP = "Envia diagnostico tecnico a LibDebugLogger. No afecta al juego normal.",

    -- Kits
    EZOARM_OPTION_KITS = "Kits",
    EZOARM_OPTION_KITS_HEADER_TOOLTIP = "Un kit es un bloque reutilizable de piezas, por ejemplo cinco piezas de ropa de un set o un monster set de dos piezas. Creas el kit una vez y lo asignas a todos los encuentros que quieras. Los kits son comunes a todo el personaje; solo las asignaciones pertenecen a cada rol.",

    EZOARM_OPTION_ROLE = "Rol activo",
    EZOARM_OPTION_ROLE_TOOLTIP = "Perfil de rol que se usa para las asignaciones de kits. Los kits en si son comunes al personaje.",
    EZOARM_ROLE_DD = "Dano",
    EZOARM_ROLE_TANK = "Tanque",
    EZOARM_ROLE_HEALER = "Sanador",

    EZOARM_OPTION_KIT_NAME = "Nombre del nuevo kit",
    EZOARM_OPTION_KIT_NAME_TOOLTIP = "Nombre del kit que vas a capturar, por ejemplo \"Arca Nula 5 ropa\".",

    EZOARM_OPTION_KIT_PRESET = "Piezas a capturar",
    EZOARM_OPTION_KIT_PRESET_TOOLTIP = "Se construye con el equipo que llevas puesto: todo, un set entero con su numero de piezas, o una pieza suelta por su nombre. La lista se actualiza al reabrir el panel o tras capturar un kit.",
    EZOARM_PRESET_ALL = "Todo el equipo puesto",

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

    EZOARM_CAT_ARMOR = "armadura",
    EZOARM_CAT_JEWELRY = "joyeria",
    EZOARM_CAT_WEAPONS_FRONT = "armas",
    EZOARM_CAT_WEAPONS_BACK = "armas (T)",

    EZOARM_OPTION_KIT_CAPTURE = "Capturar del equipo puesto",
    EZOARM_OPTION_KIT_CAPTURE_TOOLTIP = "Crea un kit con las piezas que llevas ahora mismo, limitado a la seleccion de arriba.",

    EZOARM_OPTION_KIT_CAPTURE_ALL = "Capturar todo lo puesto como kits",
    EZOARM_OPTION_KIT_CAPTURE_ALL_TOOLTIP = "Crea de una vez kits con todo lo que llevas puesto: uno por cada set de varias piezas, y ademas uno por cada pieza suelta (miticos, armas sin set, o una sola pieza de un set como una cabeza de Slimecraw). Cada kit se nombra con su palabra clave mas donde va, por ejemplo \"Null Arca - armadura\" o \"Slimecraw - Cabeza\", asi el mismo set en sitios distintos no se confunde. El nombre completo se conserva dentro del kit y los nombres repetidos se numeran en vez de saltarse.",
    EZOARM_MSG_KITS_CAPTURED_ALL = "Creados <<1>> kits, saltados <<2>>.",

    EZOARM_OPTION_KIT_LIST = "Kits guardados",
    EZOARM_OPTION_KIT_LIST_TOOLTIP = "Selecciona un kit guardado. El numero entre parentesis son las piezas que contiene.",
    EZOARM_OPTION_KIT_DELETE = "Eliminar el kit seleccionado",
    EZOARM_OPTION_KIT_DELETE_TOOLTIP = "Borra el kit seleccionado y cualquier referencia a el en las asignaciones de rol.",
    EZOARM_OPTION_KIT_SHOW = "Ver el kit seleccionado",
    EZOARM_OPTION_KIT_SHOW_TOOLTIP = "Muestra las piezas guardadas en el kit seleccionado.",

    EZOARM_OPTION_KIT_EQUIP = "Equipar el kit seleccionado",
    EZOARM_OPTION_KIT_EQUIP_TOOLTIP = "Ponte las piezas del kit seleccionado. El equipo solo se puede cambiar fuera de combate, asi que si estas luchando espera y lo equipa en cuanto sales de combate. Las piezas deben estar en la mochila; lo que este en el banco se avisa como no disponible.",
    EZOARM_MSG_EQUIP_QUEUED = "En combate: EZOArmory equipara el kit en cuanto salgas de combate.",
    EZOARM_MSG_EQUIP_DONE = "Equipadas <<1>>, ya puestas <<2>>, no disponibles <<3>>.",
    EZOARM_MSG_EQUIP_MISSING = "No disponibles en la mochila: <<1>>.",
    EZOARM_MSG_EQUIP_NO_LIBASYNC = "El equipado necesita el addon LibAsync. Instalalo para activarlo.",
    EZOARM_MSG_EQUIP_EMPTY = "El kit seleccionado no tiene nada que equipar.",

    EZOARM_OPTION_ASSIGN = "Asignaciones",
    EZOARM_OPTION_ASSIGN_HEADER_TOOLTIP = "Asigna kits a cada trial y objetivo. Las asignaciones pertenecen al rol activo. Para cada trial defines los kits del Trash y de cada boss de forma independiente; un objetivo puede llevar un solo kit con todo o varios kits, y no hay que rellenarlos todos. Un boss sin nada asignado usa el default de la trial.",
    EZOARM_OPTION_ASSIGN_TRIAL = "Trial",
    EZOARM_OPTION_ASSIGN_TRIAL_TOOLTIP = "Que trial estas configurando.",
    EZOARM_OPTION_ASSIGN_TARGET = "Objetivo",
    EZOARM_OPTION_ASSIGN_TARGET_TOOLTIP = "Donde de la trial aplican estos kits: el default de la trial (se usa cuando un objetivo no tiene nada propio), el Trash, o un boss o miniboss concreto.",
    EZOARM_TARGET_DEFAULT = "Default de la trial (respaldo)",
    EZOARM_TARGET_TRASH = "Trash",
    EZOARM_OPTION_ASSIGN_KITS = "Kits para este objetivo",
    EZOARM_OPTION_ASSIGN_KITS_TOOLTIP = "Elige los kits que forman la build de este objetivo. No elegir ninguno lo vacia para que herede el default de la trial.",

    EZOARM_OPTION_EQUIP_HERE = "Equipar para mi ubicacion actual",
    EZOARM_OPTION_EQUIP_HERE_TOOLTIP = "Equipa los kits asignados a donde estas ahora: la build del rol activo para el boss actual, o la build de trash, de la trial en la que estas. Espera a estar fuera de combate.",
    EZOARM_MSG_EQUIP_NO_TRIAL = "Ahora mismo no estas en una trial.",
    EZOARM_MSG_EQUIP_NO_ASSIGNMENT = "No hay kits asignados para aqui en <<1>> (ni default de la trial).",

    EZOARM_OPTION_ANALYZE_WORN = "Analizar el equipo actual",
    EZOARM_OPTION_ANALYZE_WORN_TOOLTIP = "Indica que bonus de set tienes realmente activos en cada barra de armas con el equipo que llevas. Solo cuentan 12 piezas a la vez, asi que un set repartido entre joyeria y armas frontales no estara completo en la barra trasera.",

    -- Mensajes
    EZOARM_MSG_KIT_NEED_NAME = "Ponle antes un nombre al kit.",
    EZOARM_MSG_KIT_NO_PIECES = "No se ha capturado nada. Comprueba que llevas puestos los slots seleccionados.",
    EZOARM_MSG_KIT_CREATED = "Kit creado: <<1>> (<<2>> piezas).",
    EZOARM_MSG_KIT_DELETED = "Kit eliminado: <<1>>.",
    EZOARM_MSG_KIT_NONE_SELECTED = "No hay ningun kit seleccionado.",
    EZOARM_MSG_BAR_FRONT = "Barra frontal",
    EZOARM_MSG_BAR_BACK = "Barra trasera",
    EZOARM_MSG_PIECES = "piezas",
    EZOARM_MSG_NO_SETS = "sin piezas de set",
}
