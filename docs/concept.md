# EZOArmory — Concepto y analisis funcional

Documento de trabajo interno. Fecha: 2026-07-26.

## 1. Idea central

EZOArmory gestiona builds por **composicion de kits reutilizables**, no por
snapshots completos.

- **Wizard's Wardrobe**: cada boss guarda una foto de los 14 slots. La misma
  informacion se duplica decenas de veces; cambiar una pieza obliga a repasar
  todas las entradas.
- **EZOArmory**: defines un **kit** una vez (por ejemplo "Arca Nula 5 ropa") y a
  cada trash/boss le asignas *que kits* usa. Cambiar el kit se propaga solo.

Los kits son **comunes al personaje**. Las asignaciones son **por rol**.

## 2. Modelo de slots (importante)

En ESO solo cuentan **12 piezas simultaneas**, no 14:

| Grupo | Slots | Cuentan |
|---|---|---|
| Armadura | cabeza, hombros, pecho, cintura, manos, piernas, pies | 7 siempre |
| Joyeria | collar, anillo 1, anillo 2 | 3 siempre |
| Armas barra frontal | principal, secundaria | 2 solo con esa barra activa |
| Armas barra trasera | principal, secundaria | 2 solo con esa barra activa |

**Total activo: 12 por barra.** La armadura y la joyeria se comparten entre las
dos barras; solo cambian las dos armas.

Combinaciones habituales (todas suman 12):

- `5 ropa + 5 joyeria/armas + 2 monster`
- `5 ropa + 4 + 1 mitico + 2 monster`
- `5 + 5 + 1 mitico + 1 suelta`

Reglas adicionales del juego:

- Un arma a dos manos cuenta como **2 piezas**.
- Solo se puede llevar **1 mitico**.
- Los monster sets solo van en **cabeza y hombros** (2 piezas).

**Consecuencia de diseno:** la validacion es **por barra**. Esto habilita una
funcion que WW no cubre bien: avisar de que un bonus de 5 piezas no esta activo
en una barra concreta (por ejemplo, un set repartido en 3 joyas + 2 armas
frontales solo da 3 piezas cuando estas en la barra trasera).

## 3. Modelo de datos

```text
PERSONAJE
├── Kits (pool comun, muchos)              <- se definen una vez
│     "Arca Nula 5 ropa", "Ansuul 5 joyas+armas", "Monster 2", "Mitico"
├── Perfiles de rol: DD / Tanque / Sanador
│     ├── Asignaciones: [trial][trash|boss] -> { kit, kit, kit, kit }
│     └── autoEquip por trial: automatico | manual
├── Kits de habilidades (barra frontal / trasera)
└── Grupos de CP: "pulls", "bosses", "especial"
```

### Kit

Guarda **items concretos** (decision tomada: permite equipar y distinguir
rasgo/calidad/encantamiento).

```lua
Kit = {
    id, name,
    role,       -- opcional, solo para filtrar el listado
    pieces = {
        [slotKey] = {
            itemId,    -- Id64ToString(GetItemUniqueId(bag, slot))
            setId, setName, itemName,
        },
    },
}
```

### Herencia de asignaciones

Para no repetir trabajo: se define un conjunto de kits **por defecto de la
trial**, y solo se sobrescribe en los bosses que lo necesiten. Un boss sin
asignacion propia hereda el de la trial.

## 4. Hallazgos tecnicos que condicionan el diseno

Verificado contra Wizard's Wardrobe (referencia probada en produccion) y el uso
real de la familia EZO.

### 4.1 Identidad de item

`Id64ToString(GetItemUniqueId(bag, slot))` devuelve un identificador estable por
**instancia** de item. Es la forma correcta de referenciar una pieza concreta.

Limitacion: si el jugador destruye, vende o recrea la pieza, ese id deja de
existir. El addon debe detectarlo y avisar en vez de fallar en silencio.

### 4.2 Equipar: que se puede automatizar y que no

| Accion | API | Automatizable |
|---|---|---|
| Equipar desde la mochila | `EquipItem(bag, slot, destSlot)` | **Si** |
| Mover entre banco y mochila | `CallSecureProtected("RequestMoveItem", ...)` | **No** (requiere contexto seguro / accion del jugador) |

**Regla practica: todo el equipo de los kits debe estar en la mochila.** El
addon no puede sacar piezas del banco de forma automatica. Por eso WW tiene un
modulo de banking aparte que exige interaccion del jugador.

Implicacion: hace falta una verificacion previa tipo "todas las piezas de estos
kits estan disponibles en la mochila", con aviso claro antes de entrar a la
trial.

### 4.3 Limites reales de velocidad

Esto es lo mas importante para el uso en end game. **Correccion respecto a una
version anterior de este documento: el equipo tampoco se cambia en combate.**
Verificado contra Wizard's Wardrobe, que condiciona TODOS los cambios a
`WW.IsReadyToSwap() = not IsUnitInCombat("player") and not IsUnitDeadOrReincarnating("player")`
y hace `WaitUntil(IsReadyToSwap)` antes de cada `EquipItem`.

| Que se cambia | En combate | Coste |
|---|---|---|
| **Equipo** | **No** | Rapido fuera de combate; `EquipItem` no es protegida |
| **Habilidades** | **No** | Solo fuera de combate |
| **Puntos de Campeon** | **No** | Fuera de combate **y ~30 s de cooldown** |

El cooldown de CP (`EVENT_CHAMPION_PURCHASE_RESULT`, ~31 s en WW) hace que la
idea de "un grupo de CP para pulls y otro para bosses" **no sea viable entre
pulls rapidos**. Es realista por fase larga o por boss, no por cada trash.

Conclusion de diseno: **nada se cambia en combate**. El equipado (y las
habilidades y CP) debe hacerse en la ventana breve fuera de combate: en el
staging antes del boss o entre packs. Es el modelo de WW y funciona. Si se pide
equipar durante el combate, se encola y se aplica al salir (LibAsync
`WaitUntil`).

### 4.3.1 Principio de aplicacion idempotente (obligatorio)

**Nunca aplicar algo que ya esta puesto.** Antes de equipar una pieza, asignar
una habilidad o slotear una estrella de CP, comprobar si ya coincide con lo
actual y, si coincide, no tocarla.

- **Equipo**: ya implementado. `equip.lua` salta la pieza si el item del slot es
  el correcto (contador `already`).
- **Habilidades**: pendiente (Fase 4). No re-slotear una habilidad que ya esta
  en su barra y posicion.
- **Puntos de Campeon**: pendiente (Fase 4) y **critico**. Cada cambio de CP
  arranca ~30 s de cooldown, asi que re-aplicar un CP ya slotteado es un coste
  real y visible. Comparar el conjunto activo contra el deseado y aplicar solo
  la diferencia; si no hay diferencia, no hacer nada.

Motivo general: ademas de evitar el cooldown de CP, reduce el trabajo por frame
de la cola, evita parpadeos y hace el equipado casi instantaneo cuando ya llevas
casi toda la build.

### 4.4 Aplicacion por lotes

Equipar 12 piezas no puede hacerse en un solo frame de forma fiable.

**Decision: usar LibAsync**, igual que Wizard's Wardrobe (`DependsOn
LibAsync>=30002`). Es la opcion probada en produccion para repartir el trabajo
entre frames. Queda como dependencia externa expresamente autorizada, excepcion
justificada a la regla general de la familia EZO.

La dependencia se anade al manifest en la Fase 2, cuando exista codigo que la
use; declararla antes solo impediria cargar el addon sin aportar nada.

### 4.5 APIs de habilidades y CP

- Habilidades: `ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)`,
  `hotbarData:GetSlotData(slotIndex)`, `ClearSlot`. Categorias 0 y 1 =
  barra frontal y trasera.
- CP: maximo **12 estrellas asignables**; `GetChampionSkillType`,
  `CanChampionSkillTypeBeSlotted`, `GetNumPointsSpentOnChampionSkill`,
  `GetChampionSkillName`.

Ambas requieren verificacion adicional en UESP antes de implementarse.

## 5. Que valida el motor de coherencia

- Conflicto de slot: dos kits reclaman la misma pieza.
- Set sobreasignado: mas slots que piezas admite el set.
- Slot sin asignar.
- **Suma distinta de 12 por barra.**
- **Bonus de 5 piezas no alcanzado en una barra concreta.**
- Mas de un mitico.
- Monster set fuera de cabeza/hombros.
- Item del kit no disponible en mochila (no equipable ahora).
- Mismo item usado por dos kits del mismo conjunto.
- Contraste contra lo que se lleva puesto en este momento.

## 6. Plan por fases

1. **Fase 1 — datos y motor.** Modelo de kits con items concretos, motor de
   coherencia por barra, captura desde el equipo puesto. Gestion minima en LAM.
2. **Fase 2 — equipado.** Cola de aplicacion, verificacion de disponibilidad en
   mochila, modo automatico/manual por trial.
3. **Fase 3 — ventana propia.** Rejilla de 12 slots, listado de kits, matriz
   trial/boss con herencia. Incluye la capa de revisiones (ver 6.1).
4. **Fase 4 — habilidades y CP.** Kits de habilidades por barra y grupos de CP,
   con las restricciones de la seccion 4.3.

## 6.1 Revisiones de la ventana (Fase 3)

La ventana debe hacer varias revisiones antes de dar por bueno un loadout. La
mayoria ya existen en el motor `coherence.lua`; la ventana solo tiene que
mostrarlas (color por slot, aviso por set, resumen por barra). Estado actual:

| Revision | Motor | En la ventana |
|---|---|---|
| Dos kits pisan la misma posicion (`slotConflict`) | Hecho | Pendiente de pintar |
| Un set pide mas piezas de las que admite (`setOverfill`) | Hecho | Pendiente |
| Slot sin asignar (`unassignedSlot`) | Hecho | Pendiente |
| Barra que no suma 12 (`barIncomplete`) | Hecho | Pendiente |
| Mismo item fisico en dos kits (`duplicateItem`) | Hecho | Pendiente |
| Mas de un mitico (`multipleMythics`) | Hecho | Pendiente |
| Slot desconocido / kit vacio (`unknownSlot`, `emptyKit`) | Hecho | Pendiente |
| Pieza no disponible en mochila (`CheckAvailability`) | Hecho | Pendiente |
| Contraste con lo que se lleva puesto (`CompareToEquipped`) | Hecho | Pendiente |
| Recuento por set y por barra (5/5 frontal, 3/5 trasera) | Hecho (dato) | Mostrar como semaforo |

Revisiones nuevas a anadir en esta fase (aun no en el motor):

- **Set que no completa su bonus en ninguna barra**: hoy el recuento incompleto
  por barra se trata como dato (a veces es intencionado). Un set que no llega a
  su maximo en ninguna de las dos barras suele ser un error real y merece aviso
  propio.
- **Monster set fuera de cabeza/hombros**: coherencia de posicion especifica.
- **Segundo mitico o segundo monster** por reglas del juego (parcialmente
  cubierto por `multipleMythics`; falta el caso monster).
- **Aviso visual de pieza suelta que deja hueco**: una sola pieza de un set de 2
  (monster a medias) marcada como incompleta.

La ventana presenta el resultado como codigo de color por slot (ok / conflicto /
vacio / incompleto) y una linea de resumen por barra, reutilizando
`Coherence.Analyze` sin duplicar logica.

## 7. Decisiones tomadas

| Tema | Decision |
|---|---|
| Alcance | El addon **equipa**, en modo automatico o manual **por trial** |
| Contenido del kit | **Items concretos** (permite equipar y distinguir rasgo/calidad) |
| Interfaz | Ventana propia, **por fases** (LAM minimo primero) |
| Cola de equipado | **LibAsync**, dependencia externa autorizada |
| Grupos de CP | Se mantiene la idea completa (pulls, bosses, especial). Si el cooldown de 30 s la hace inviable en la practica, se replantea con datos de uso real |
| Perfiles | Tres por personaje: **DD, Tanque, Sanador** |
| Kits | **Comunes al personaje**; las asignaciones son por rol |
