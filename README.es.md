# EZOArmory

Gestor de loadouts, sets de equipo, Puntos de Campeon y habilidades para las
trials y bosses de ESO. Forma parte de la familia de addons EZO.

> Estado: **desarrollo (0.1.0)** — esqueleto inicial. El motor de gestion de
> builds esta en construccion; esta version sienta la base del addon, los datos
> de referencia de trials/bosses y la integracion con EZOCore.

## Que hace

EZOArmory gestiona builds **componiendo kits reutilizables**, en lugar de
guardar una foto completa del equipo para cada boss:

- **Kits con nombre** (el bloque de construccion): un kit es un bloque de piezas
  concretas, como "Arca Nula — 5 de ropa", "Ansuul — joyeria y armas", un
  monster set de 2 piezas, un mitico o una pieza suelta. Defines el kit una vez
  y lo reutilizas en todas partes.
- **Builds** (lo que de verdad se equipa): una build compone kits de equipo, un
  kit de habilidades y un kit de CP hasta tenerlo todo. Un kit por si solo no es
  equipable de forma coherente — le faltan slots —, mientras que una build lo
  cubre entero. EZOArmory revisa cada build y se niega a equipar una incompleta,
  indicando exactamente que falta o que entra en conflicto. Cada build tiene su
  propio rol, deducido de sus armas: baston de curacion es sanador, escudo es
  tanque, baston de hielo sin ninguno de los dos se marca como duda (hay tanques
  que no llevan escudo pero si baston de hielo), y armas de ataque en ambas
  barras es dano. Puedes forzarlo. Este rol es interno de EZOArmory y nunca toca
  tu rol del buscador de grupo.
- **Una build por encuentro**: cada trial tiene una build por defecto, y solo
  sobrescribes el trash o los bosses concretos que necesiten algo distinto. Una
  sola build por objetivo, porque una build ya lo cubre todo. Si cambias la
  build, se actualiza en todos los encuentros que la usan.
- **Tres perfiles de rol** por personaje: dano, tanque y sanador. Los kits son
  comunes al personaje; las asignaciones pertenecen a cada rol.
- **Marca en el inventario**: las piezas que forman parte de alguno de tus kits
  llevan una Z morada en la mochila, el banco, el banco de hermandad y los
  paneles de descomponer y mejorar, para ver de un vistazo lo que no debes
  destruir. Al pasar el cursor te dice en que kits y builds se usa.
- **Builds sustitutas**: una build de trash y otra de boss que se usan donde no
  haya nada asignado: una trial sin configurar, una mazmorra o el mundo
  abierto. EZOArmory equipa la de boss mientras hay un boss delante y la de
  trash el resto del tiempo. Desactivado por defecto, con interruptor por tipo
  de zona, y experimental fuera de las trials: depende de que la zona declare
  sus bosses, y no todas lo hacen.
- **Motor de coherencia**: valida la build **por barra de armas** — solo cuentan
  12 piezas a la vez, porque la armadura y la joyeria aplican siempre pero las
  armas solo cuentan en la barra activa. Avisa de conflictos de slot, sets que
  piden mas piezas de las que admiten, items duplicados, mas de un mitico,
  barras incompletas y piezas que no estan disponibles para equipar.
- **Consciencia de trial y boss**: reconoce las 14 trials por zona y sus bosses,
  y detecta encuentros con boss fuera de las trials.
- **Kits de habilidades**: memorizan las dos barras de accion junto con las
  armas con las que se capturaron (mostradas como iconos de barra frontal y
  trasera), separados de los kits de equipo.
- **Kits de Puntos de Campeon**: memorizan las doce estrellas de Campeon
  slotteadas; dos capturas con las mismas estrellas cuentan como el mismo kit.
- **Captura en un paso** de todo: sets de equipo, piezas sueltas, barras de
  habilidades y estrellas de Campeon, cada cosa en su seccion, sin duplicar
  nunca un kit existente.
- **Ventana propia**, que se abre con una tecla o con `/ezoarmory`, y muestra la
  trial y el boss actuales. Su pestana **Builds** lista todas las builds con su
  rol, su estado y las piezas, habilidades y estrellas que las componen —pasa el
  cursor por cualquiera para ver su tooltip real del juego— y equipa una build
  entera de una vez. Una vista de editor aparte la construye a partir de tus
  kits e indica que queda por corregir. Las demas pestanas navegan los kits de
  equipo, habilidades y CP con esos mismos tooltips reales, y asignan una build
  a cada trial y boss. La rejilla de coherencia de doce slots se sigue
  construyendo aqui.

Las piezas deben estar en la mochila: sacar items del banco requiere
interaccion directa del jugador y no se puede automatizar. Las habilidades y los
Puntos de Campeon solo pueden cambiarse fuera de combate, y los CP tienen ademas
un tiempo de espera del propio juego.

La comida y bebida quedan fuera de alcance de forma intencionada.

## Requisitos

- **Necesario:** LibAddonMenu-2.0
- **Opcionales:** LibChatMessage, LibDebugLogger, DebugLogViewer, EZOCore

EZOArmory funciona de forma independiente. Cuando EZOCore esta instalado se
registra bajo `Settings > EZO`, comparte la preferencia de idioma de la familia,
usa el diagnostico comun y registra su ventana movible en el servicio de layout.

## Instalacion

Instalar en `Documents/Elder Scrolls Online/live/AddOns/EZOArmory`. Durante el
desarrollo la carpeta es un symlink al repositorio en `E:\dev\EZOArmory`.

## Pruebas

- El addon carga sin errores Lua.
- `/reloadui` funciona.
- El panel de LibAddonMenu se abre (o el panel EZO cuando EZOCore esta presente).
- Las preferencias de idioma y depuracion persisten.

## Licencia

MIT. Ver [LICENSE](LICENSE).
