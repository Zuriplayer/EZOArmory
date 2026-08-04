# EZOArmory - AI Development Rules

<!-- EZO-SHARED-LAM-START -->
## Estandar LAM compartido

Antes de crear o modificar ajustes LibAddonMenu, leer y aplicar:
`E:\Dev\EZOFamilyDocs\docs\ezo-lam-settings-style.md`

Las reglas especificas de este addon tienen prioridad. Si el archivo compartido
no esta accesible, no modificar LAM e indicarlo explicitamente.
<!-- EZO-SHARED-LAM-END -->

Este proyecto es un addon para The Elder Scrolls Online (ESO).

El entorno Lua de ESO es limitado y no equivale a Lua estandar. El objetivo es
mantener `EZOArmory` pequeno, estable y facil de revisar dentro de la familia EZO.

## Alcance

- Addon funcional independiente: `EZOArmory`.
- Gestor de builds por trial y boss: kits de sets con nombre, loadouts,
  grupos de Champion Points y conjuntos de habilidades.
- Motor de coherencia que analiza incoherencias de sets (dos piezas de sets
  distintos en un mismo slot, un set con mas de 5 piezas, slots sin asignar) y
  contrasta contra el equipo realmente equipado.
- Ventana emergente (HUD) configurable con el contexto actual (trial/boss).
- Panel LibAddonMenu como interfaz de configuracion.
- Dos idiomas: ingles y espanol, con opcion `Automatico`.
- Debe funcionar sin `EZOCore`; integracion blanda via `OptionalDependsOn`.

## Integracion EZOCore

- `## OptionalDependsOn: EZOCore` (nunca `DependsOn`). El addon funciona solo.
- Registrar el addon con `EZOCore:RegisterAddon` (id `ezoarmory`).
- Registrar el panel con `EZOCore:RegisterSettingsPanel`; fallback a LAM directo.
- Usar `family.language` (idioma global), `family.debug` (diagnostico) y
  `family.layout` (ventana movible) cuando esten disponibles, con fallback local.
- Contrato de referencia: `E:\Dev\EZOCore\docs\consumer-integration.md`.

## Reglas obligatorias

- No inventar APIs de ESO. Verificar cualquier API nueva en UESP ESO Data
  (esodata.uesp.net) o en el cliente antes de usarla.
- No usar librerias externas salvo indicacion expresa.
- Usar correctamente `LibAddonMenu-2.0`; `LibChatMessage`, `LibDebugLogger` y
  `DebugLogViewer` son opcionales.
- Mantener cambios pequenos y revisables.
- Evitar globals innecesarias; usar `EZOArmory = EZOArmory or {}`.
- Usar prefijo de eventos/globales propio: `EZOArmory_` o `EZOARM_`.
- Lua defensivo: prevenir `nil` tipico de la API de ESO.

## HUD y escenas

- Los controles visuales persistentes solo pueden mostrarse en las escenas
  `hud` o `hudui` (whitelist de HUD), con fragmentos y guard `IsHudScene()`.
- Registrar la superficie movible en `family.layout` cuando `EZOCore` exista,
  conservando un control local de mover/desbloquear.

## Versionado

Actualizar version con:

- `.\tools\bump-version.ps1 -Patch`
- o `.\tools\bump-version.ps1 -Version x.y.z`

La version visible debe quedar sincronizada entre `EZOArmory.txt` (`## Version`),
`modules/core.lua` (`EZOArmory.ADDON_VERSION`) y `ezo-addon.json`. `## AddOnVersion`
se incrementa cuando cambia la version visible. No adivinar `## APIVersion`.

Antes de commit: `.\tools\bump-version.ps1 -Check` y `git diff --check`.

## Localizacion

- Usar `lang/en.lua` y `lang/es.lua`, tablas `EZOARMORY_STRINGS_EN/ES`.
- No hardcodear textos visibles en modulos. Usar IDs `EZOARM_*`.
- Cada clave debe existir en ambos idiomas.

## Documentacion

- Toda modificacion funcional o de opciones actualiza `README.md` y
  `README.es.md` a la vez, equivalentes y sincronizados.
- Ningun README debe anunciar funciones que no coincidan con el codigo actual.

## Discord y publicaciones

- La configuracion de webhooks vive en `ezo-addon.json`.
- No publicar en Discord ni hacer push sin autorizacion explicita.

## Git

- Rama `main`, remoto `https://github.com/Zuriplayer/EZOArmory.git`.
- `.gitattributes` con LF. Commits pequenos y con mensaje claro.
- Autor y committer `Zuriplayer <Zuriplayer@gmail.com>`.
- NUNCA trailers `Co-authored-by` de Claude, Anthropic, Codex u otro agente.

<!-- EZO-ESO-UPDATE-START -->
## Baseline obligatorio de ESO

Antes de analizar, modificar, validar, versionar o publicar este proyecto, leer
`..\EZOFamilyDocs\docs\eso-updates\current.md` y aplicar la política enlazada.

Baseline vigente: `U51-PTS-v12.1.0`.

- La matriz por addon vive en `..\EZOFamilyDocs\data\eso-update-baseline.json`.
- U51 sigue siendo PTS provisional hasta que exista verificación explícita.
- No cambiar `## APIVersion` por inferencia; verificarla en el cliente o en una
  fuente fiable de API.
- Si estos archivos no están disponibles, detener el trabajo sensible a
  compatibilidad e indicar el bloqueo.

Fuente remota de respaldo:
https://github.com/Zuriplayer/EZOFamilyDocs/blob/main/docs/eso-updates/current.md
<!-- EZO-ESO-UPDATE-END -->
