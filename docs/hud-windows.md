# Ventanas HUD

Diseño de las cuatro ventanas HUD (CP, Kits, Skills, Builds), independientes
entre sí y de la ventana principal del addon. Documento de especificación
previo a la implementación: recoge lo verificado contra fuentes reales y las
decisiones ya tomadas, para no improvisar sobre tanta superficie nueva.

Referencia visual: un addon visto en Twitch con dos ventanas (CP y kits). Se
copia el formato, no el comportamiento — ver "Cooldown de CP" más abajo.

> **Estado: aparcado.** Especificación acordada y guardada para más adelante.
> No empezar la implementación hasta que se retome de forma explícita, y
> respetando el orden de la sección 9.

## 1. Principios

- Cada ventana se activa, se coloca y se configura **por separado**. Ninguna
  depende de que la ventana principal esté abierta.
- Las cuatro comparten **el mismo formato**: contenido arriba, fila de iconos
  de acción abajo.
- Las ventanas son **vistas delgadas** sobre el modelo que ya existe (`Kits`,
  `Skills`, `Champion`, `Builds`, `Coherence`, `Equip`). No duplican lógica de
  equipado ni de análisis. Si hace falta algo nuevo, va al módulo de modelo, no
  a la ventana.
- Un solo marco compartido para las cuatro. La lección de `window_kits` /
  `window_builds` es que dos implementaciones paralelas divergen; cuatro sería
  peor.

## 2. Marco compartido

Módulo nuevo con la parte común:

- `TopLevelControl` por ventana, arrastrable, con posición y visibilidad
  guardadas en `sv.hud[<windowId>]`.
- Fila de iconos inferior: el marco la dibuja, cada vista declara qué acciones
  contiene.
- Si alguna vista usa `ZO_ScrollContainer`, aplicar `DisableScrollWheelArea`
  desde el primer momento (ver el caso resuelto en 0.11.10, o se pierden los
  tooltips al pasar el ratón).

### EZOCore es opcional: el addon debe funcionar sin él

**Restricción de familia**: EZOCore es una librería común, pero cada addon tiene
que poder funcionar por su cuenta — como mucho perdiendo funcionalidad común,
nunca rompiéndose. EZOArmory ya lo declara así (`## OptionalDependsOn: ...
EZOCore`) y todo su uso de EZOCore va guardado con el patrón
`if not (EZOCore and type(EZOCore.X) == "function") then return end`
(`EZOArmory.lua`, líneas 242-353). El modo de edición del HUD sigue esa misma
regla.

**Resuelve la duda de `sv.general.unlockHud`**: no se elimina. Pasa a ser **la
única fuente de verdad** del modo "desbloquear para mover", propiedad del addon:

- **Sin EZOCore**: el addon gobierna `unlockHud` por su cuenta (casilla en su
  panel LAM y/o comando propio). Las ventanas se mueven igual.
- **Con EZOCore**: se registra una superficie por ventana con
  `LAYOUT.RegisterSurface` (verificado en `EZOCore/modules/layout.lua:132`;
  requiere `id`, `addonId`, `addonName`, `name`, `setEditMode`, `isEditMode`;
  opcionales `canEdit`, `tooltip`, `sortOrder`). Los callbacks son triviales
  porque no introducen estado nuevo: `setEditMode(enabled)` escribe `unlockHud`
  e `isEditMode()` lo lee. Así el modo de edición común de la familia gobierna
  exactamente el mismo interruptor, sin duplicar estado ni poder desincronizarse.

Con esto EZOArmory queda igual que EZOMetter (`ezometter.hud`) y EZOAlerts
(`ezoalerts.alert`) cuando EZOCore está presente, y autónomo cuando no. Además
cumple por fin la capacidad **`family.layout.consumer`** que ya declara en
`EZOA.RegisterWithEZOCore` (`EZOArmory.lua:325`) pero que hoy no implementa.

## 3. Desplegables gráficos: solución nativa

Verificado que `ZO_ComboBox:AddCustomEntryTemplate(entryTemplate, entryHeight,
setupFunction)` existe en el combobox estándar
(`esoui/libraries/zo_combobox/zo_combobox.lua:45`). Permite que cada entrada de
un desplegable sea una plantilla propia — por ejemplo, las dos barras de
habilidades dibujadas con iconos reales.

Revisadas las librerías de la familia EZO por si había mejor opción:
`LibDebugLogger` (21 usos), `LibAddonMenu-2.0` (16), `LibChatMessage` (11),
`LibSlashCommander` (4), `LibGroupBroadcast`, `LibCustomMenu`, `LibCombat`,
`LibAsync`. **Conclusión: se usa el combobox nativo.** `LibScrollableMenu` está
instalada en el cliente pero **ninguna** addon EZO la usa; meterla sería una
dependencia externa nueva (la norma EZO solo tiene autorizada `LibAsync` como
excepción) a cambio de algo que el juego base ya hace. `LibCustomMenu` es para
menús contextuales de clic derecho, no encaja.

## 4. Ventana CP

### Formato

- **Tres iconos selectores de disciplina** (Guerra / Forma Física / Mundo,
  `CHAMPION_DISCIPLINE_TYPE_COMBAT` / `_CONDITIONING` / `_WORLD`), coloreados
  con `ZO_CP_BAR_GLOW_COLORS`, que es lo que ya usamos en la ventana principal.
- **Cuatro filas** con los 4 slots de la disciplina seleccionada: icono de la
  estrella + desplegable para cambiarla.
- **Debajo**: lista/desplegable de kits de CP guardados, para cargar uno entero.

### Contenido de cada desplegable

Solo estrellas que cumplan las tres condiciones:

1. Pertenecen a esa disciplina — `Champion.GetStarDisciplineType(starId)`, mapa
   ya cacheado en `champion.lua`.
2. Están compradas — `GetNumPointsSpentOnChampionSkill(starId) > 0`
   (verificada en `ESOUIDocumentation.txt:18220`).
3. Son ranurables — `CanChampionSkillTypeBeSlotted(GetChampionSkillType(starId))`
   (verificadas en `ESOUIDocumentation.txt:18184` y `:18276`).

Además, ocultar las que ya estén puestas en otro slot de la misma disciplina.

### Mapeo slot -> disciplina

No hardcodear "slots 1-4 = disciplina A". **Derivarlo en tiempo de ejecución**
de la barra real del jugador: `Champion.CaptureSlotted()` da slot -> starId, y
`Champion.GetStarDisciplineType(starId)` da la disciplina de cada una. Es más
robusto que una constante y no depende de suposiciones. Como red de seguridad,
el servidor ya devuelve `CHAMPION_PURCHASE_CHAMPION_BAR_WRONG_DISCIPLINE` si
nos equivocamos, y desde 0.11.14 ese resultado se detecta y se informa.

### Cooldown: decisión tomada

Cambio **inmediato, de uno en uno**. El uso real es puntual (poner o quitar una
estrella concreta), y para un solo cambio agrupar no ahorra nada: un cambio
cuesta un cooldown de ~30 s igual.

Consecuencias que la ventana debe cubrir:

- Mostrar el estado del cooldown de forma visible (`Equip.IsCpReady()`, ya
  existe con su cuenta atrás de 31 s). Si no está listo, indicarlo con los
  segundos restantes en vez de dejar al jugador pulsando a ciegas.
- Cargar un **kit de CP entero** es el camino agrupado: varias estrellas en una
  sola petición = un solo cooldown. Ya lo hace `Equip.ApplyCpKit`.
- Hace falta una función nueva de modelo: `Equip.ApplyCpStar(slot, starId)`.
  Es trabajo mínimo — `SendAndVerifyCp` (0.11.14) ya recibe una lista de
  diferencias, basta con construirla con un solo elemento y hereda gratis la
  verificación del resultado real y el reintento ante fallo transitorio.

## 5. Ventana Kits

La más compleja. Composición progresiva con filtrado por compatibilidad.

- **Desplegable 1**: todos los kits de equipo.
- **Desplegable 2**: solo kits compatibles con el elegido en el 1 (que no
  ocupen ningún slot ya ocupado).
- **Desplegable 3**: compatibles con 1 + 2. Y así sucesivamente.

Compatibilidad = **no pisarse ningún slot**. No basta con que coincida el número
de piezas: dos kits de 5 piezas con distinta distribución de armadura/joyería/
armas no son intercambiables si entran en conflicto. Esto ya lo detecta el motor
de coherencia como `slotConflict` en `Coherence.BuildAssignment`; la ventana
reutiliza esa misma lógica para **filtrar antes de ofrecer**, en vez de dejar
elegir y avisar después.

Complementos:

- **Icono de limpiar**: vacía la composición **sin desequipar** nada.
- **Lectura de coherencia en vivo** con el formato de la referencia
  (`5x Order's Wrath`, `5/3x Tide-Born Wildstalker`, `0/2x Perfected Merciless
  Charge`): piezas llevadas frente a piezas que pide el set. Sale directamente
  de `Coherence.Analyze`. Ojo: esto es **lectura de estado**, distinto de la
  acción de elegir kit; conviene que se vea como tal.

## 6. Ventana Skills

- Muestra las **dos barras** completas con iconos reales (ya sabemos hacerlo:
  `AbilityTooltip:SetAbilityId` y el pintado de barras de `window_kits`).
- Desplegable para cambiar **el kit de habilidades entero** (las dos barras a la
  vez), con la plantilla personalizada de la sección 3 para que cada entrada se
  vea gráficamente.
- **Filtro**: solo kits cuyas armas capturadas sean compatibles con las armas
  **equipadas en ese momento**. La comprobación ya existe: es el `weaponMismatch`
  de `Builds.CheckWeaponCoherence`. Igual que en Kits, aquí se usa para filtrar
  antes, no para avisar después.

## 7. Ventana Builds

La más simple. Desplegable de texto con los nombres, filtrado a builds
**completas y sin errores**: `Builds.Analyze(build).complete` y `.ok`, que ya
devuelven exactamente eso.

## 8. Fila de iconos inferior

Lluvia de ideas todavía. Confirmados de momento:

- **Renombrar**.
- **Rueda dentada** -> abre el panel LAM del addon.
- **Icono** -> abre la ventana principal de EZOArmory.

Pendientes de decidir: "guardar actual" y "crear nuevo desde lo puesto".
Cuidado con "guardar actual" sobre un kit existente: es destructivo y necesita
diálogo de confirmación (patrón `ZO_Dialogs_RegisterCustomDialog` ya usado en
renombrar kit y en restaurar valores por defecto).

## 9. Orden de implementación

1. **Marco compartido** (superficie EZOCore, posición/visibilidad, fila de
   iconos).
2. **CP** — es la de mayor valor y la más autocontenida.
3. **Builds** — trivial una vez existe el marco; valida el formato común.
4. **Skills** — primera con plantilla gráfica en el desplegable.
5. **Kits** — la que más lógica nueva de filtrado necesita.

## 10. Restricciones transversales

- Equipo, habilidades y CP **no se cambian en combate**. Las cuatro ventanas
  deben reflejarlo (deshabilitar o indicar la espera), no fallar en silencio.
  `Equip.IsReady()` y `Equip.IsCpReady()` ya dan ese estado.
- **Las cuatro ventanas funcionan sin EZOCore** (ver sección 2). Ninguna
  funcionalidad propia del addon puede quedar detrás de que EZOCore esté
  instalado; lo que aporta EZOCore es integración común, no funcionamiento.
- Nada de dependencias externas nuevas (ver sección 3).
- Paridad exacta de claves entre `lang/en.lua` y `lang/es.lua`, y luacheck a 0
  antes de cada commit, como siempre.
