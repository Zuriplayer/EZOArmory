# EZOArmory

Gestor de loadouts, sets de equipo, Puntos de Campeon y habilidades para las
trials y bosses de ESO. Forma parte de la familia de addons EZO.

> Estado: **desarrollo (0.1.0)** — esqueleto inicial. El motor de gestion de
> builds esta en construccion; esta version sienta la base del addon, los datos
> de referencia de trials/bosses y la integracion con EZOCore.

## Que hace

EZOArmory te ayuda a llevar la build correcta en cada trial y cada boss:

- **Kits de sets con nombre** (la idea central): defines un kit como un set de
  equipo mas los slots que deberia ocupar (por ejemplo "Ansuul — 5 de cuerpo" o
  "Perlescente — joyeria + armas"). Los kits son las piezas de un loadout.
- **Loadouts**: combinan kits con nombre en una build completa de 12 slots
  asignada a una trial o a un boss concreto.
- **Motor de coherencia**: valida un loadout y avisa de incoherencias — un slot
  reclamado por dos sets distintos, un set que pide mas de 5 piezas, slots sin
  asignar — y lo contrasta con lo que llevas realmente equipado.
- **Consciencia de trial y boss**: reconoce las 14 trials por zona y sus bosses,
  y detecta encuentros con boss fuera de las trials.
- **Grupos de Puntos de Campeon**: grupos de CP con nombre (por ejemplo uno para
  pulls, otro para bosses y otro especial).
- **Conjuntos de habilidades**: distribuciones de habilidades con nombre para la
  barra de arma principal y secundaria.
- **Ventana emergente configurable** (HUD): muestra donde estas (trial/boss),
  que loadout aplica y las incoherencias o recordatorios.

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
