# Aula de Matemática — juego de Roblox

Juego completo en Luau: sos un alumno rindiendo una prueba de matemática y te
querés copiar con el celular. El profesor camina pasillo por pasillo, frena en
los bancos a revisar las hojas y, cada tanto, se da vuelta a escribir en el
pizarrón. Ese es tu momento: sacás el celu abajo del banco, le sacás una foto
al ejercicio, se la mandás a **RoGPT** y te devuelve la resolución paso a paso.

Todo pasa en 3D adentro del aula. La hoja de la prueba es una hoja de verdad
apoyada en el banco, y el celular es un celular de verdad soldado al cuerpo del
personaje: la app de RoGPT se dibuja sobre su pantalla, no sobre la cámara.
Lo único pegado a la pantalla es el HUD de controles (el botón grande de abajo
y el medidor de riesgo), que es lo que hace falta para poder jugar en celular.

---

## Cómo se juega

| Acción | Teclado | Gamepad | Botón |
|---|---|---|---|
| Sacar el celular / sacar foto / enviar a RoGPT | `F` | `X` | botón grande de abajo |
| Guardar el celular | `Q` | `B` | *Guardar* |
| Acercar la cámara a la hoja | `E` | `Y` | *Ver la hoja* |
| Responder | clic en la opción sobre la hoja 3D | | |

El botón grande de abajo es contextual y va cambiando solo:

```
📷 Sacar el celular   ->   📷 Sacar foto   ->   Enviar foto ▸
```

1. **Sacar el celular**: el celu sube de abajo del banco a la altura del pecho
   y la cámara se acerca a la pantalla. Desde ese momento el profe te puede ver.
2. **Sacar foto**: la cámara apunta un instante a la hoja, dispara el flash y
   vuelve al celu con la miniatura de la hoja fotografiada.
3. **Enviar**: "Subiendo imagen…", RoGPT escribe, y aparece la resolución paso
   a paso, tipeada en vivo, terminando con la respuesta remarcada.
4. Marcás esa opción en la hoja y **guardás el celular** antes de que el profe
   levante la vista.

La barra de riesgo de arriba dice todo: **SEGURO** / **SOSPECHA** / **TE VE** /
**ESTÁ DE ESPALDAS**. Si llega al máximo, el profe deja lo que estaba haciendo,
viene derecho a tu banco, te confisca el celular 35 segundos y te descuenta
nota. A la tercera te saca de la prueba.

Copiarse suma menos puntos que resolverlo solo, pero mucho más que dejarlo en
blanco. La nota es de 1 a 10 y se ve en el `leaderstats` junto con cuántas
copiaste y cuántas veces te pillaron.

---

## Instalación

### Opción A — Rojo (recomendada)

```bash
rojo serve default.project.json
```

Y conectás desde el plugin de Rojo en Roblox Studio. El proyecto ya deja todo
en su lugar (`ReplicatedStorage/Shared`, `ServerScriptService/Server`,
`StarterPlayerScripts/Client`) y configura Lighting con ShadowMap.

### Opción B — a mano en Roblox Studio

Creá esta estructura y pegá el contenido de cada archivo:

```
ReplicatedStorage
└── Shared                (Folder)
    ├── Config            (ModuleScript)  src/shared/Config.lua
    ├── MathEngine        (ModuleScript)  src/shared/MathEngine.lua
    ├── Net               (ModuleScript)  src/shared/Net.lua
    ├── PhoneModel        (ModuleScript)  src/shared/PhoneModel.lua
    ├── Theme             (ModuleScript)  src/shared/Theme.lua
    └── Util              (ModuleScript)  src/shared/Util.lua

ServerScriptService
└── Server                (Script)        src/server/init.server.lua
    ├── ClassroomBuilder  (ModuleScript)  src/server/ClassroomBuilder.lua
    ├── ExamService       (ModuleScript)  src/server/ExamService.lua
    ├── PhoneService      (ModuleScript)  src/server/PhoneService.lua
    ├── RoundService      (ModuleScript)  src/server/RoundService.lua
    ├── SuspicionService  (ModuleScript)  src/server/SuspicionService.lua
    └── TeacherAI         (ModuleScript)  src/server/TeacherAI.lua

StarterPlayer/StarterPlayerScripts
└── Client                (LocalScript)   src/client/init.client.lua
    ├── CameraRig         (ModuleScript)  src/client/CameraRig.lua
    ├── Hud               (ModuleScript)  src/client/Hud.lua
    ├── PaperUI           (ModuleScript)  src/client/PaperUI.lua
    └── PhoneUI           (ModuleScript)  src/client/PhoneUI.lua
```

Importante: los ModuleScripts van **adentro** del `Script` / `LocalScript`, no
al lado. No hay que crear ningún RemoteEvent a mano: los crea `Net.build()`.
Tampoco hay que construir el aula: la levanta `ClassroomBuilder` por código
cuando arranca el servidor.

---

## Qué hace cada archivo

**Compartido**

- `Config.lua` — todos los números del juego en un solo lugar: tamaño del aula,
  velocidad y visión del profe, cuánto sube y baja la sospecha, batería del
  celu, duración de la ronda, penalizaciones.
- `MathEngine.lua` — genera los ejercicios (jerarquía de operaciones, lineales,
  fracciones, porcentajes, proporciones, sistemas 2x2, cuadráticas, Pitágoras)
  junto con los distractores y **la resolución paso a paso** que después escribe
  RoGPT. El examen es el mismo para toda la clase.
- `Net.lua` — creación y acceso cacheado a los remotes.
- `PhoneModel.lua` — el celular 3D soldado al alumno, con el `Weld` animable que
  es literalmente el gesto de sacarlo y guardarlo.
- `Theme.lua` / `Util.lua` — paleta y azúcar para construir y animar.

**Servidor**

- `ClassroomBuilder.lua` — construye el aula entera: piso, paredes, ventanal
  lateral con huecos reales y luz natural entrando, luminarias, pizarrón con
  bandeja de tizas, escritorio del profe, puerta, y la grilla de bancos con su
  silla, su `Seat`, su hoja y su lapicera. Devuelve además los nodos de
  patrullaje de los pasillos.
- `TeacherAI.lua` — el profesor: patrulla con `PathfindingService`, frena a
  revisar bancos, se va al pizarrón (ventana segura), y tiene visión real —
  cono de FOV + raycast, con la cabeza girando por el `Motor6D` del cuello, así
  que lo que "ve" coincide con lo que ves vos que mira.
- `SuspicionService.lua` — el termómetro: sube el riesgo si tenés el celu
  afuera y te ve (más rápido todavía si encima te está revisando la prueba),
  baja si lo guardás. Al máximo, dispara la confrontación.
- `ExamService.lua` — reparte bancos, recibe respuestas, puntaje y nota. Nunca
  manda la respuesta correcta al cliente: la hoja viaja sanitizada.
- `PhoneService.lua` — batería, cooldown de la cámara, confiscación y el
  contenido de las fotos. La foto es un ticket de un solo uso que recién al
  enviarse a RoGPT devuelve la resolución.
- `RoundService.lua` — ciclo Preparación → Prueba → Resultados, `leaderstats` y
  qué pasa cuando te pillan.

**Cliente**

- `PaperUI.lua` — la hoja: un ejercicio por vez, cuatro opciones y la tira de
  pestañas con el estado de cada ejercicio, montada sobre la hoja física.
- `PhoneUI.lua` — la app de RoGPT sobre la pantalla del celu: barra de estado
  con batería, chat, miniatura de la foto, "escribiendo…" y la respuesta
  tipeada paso a paso.
- `CameraRig.lua` — tres encuadres con blend suave: libre, hoja y celu.
- `Hud.lua` — panel del profe con la barra de riesgo, reloj de la prueba,
  avisos y el botón grande de abajo.

---

## Ajustes rápidos

Todo en `src/shared/Config.lua`:

| Querés… | Tocá |
|---|---|
| Un aula más grande | `Classroom.Rows`, `Classroom.Columns` |
| Un profe más duro | `Teacher.FieldOfView`, `Teacher.ViewDistance`, `Teacher.RiskGainSeen` |
| Más ventanas seguras | `Teacher.BoardChance`, `Teacher.BoardDuration` |
| Prueba más larga | `Exam.QuestionCount`, `Exam.RoundDuration` |
| Que copiarse cueste más | `Phone.BatteryPerPhoto`, `Phone.ConfiscationTime`, `Penalty.GradePerCatch` |
| Que RoGPT tarde más | `Phone.ThinkTime`, `Phone.TypeSpeed` |

Los sonidos vienen vacíos a propósito (`Config.Sounds`), así no tira warnings
por assets que no existen: poné tus propios `rbxassetid://` de obturador,
mensaje enviado, respuesta y "te pillaron" y suenan solos.

---

## Notas técnicas

- El servidor es autoritativo en todo lo que importa: respuestas correctas,
  batería, sospecha y confiscación. El cliente sólo dibuja y pide.
- Las SurfaceGui de la hoja y del celular se parentean al `PlayerGui` con
  `Adornee` y `Active = true`: es lo que hace que los botones sean clickeables
  estando en el mundo 3D.
- El profesor usa un avatar real (`CreateHumanoidModelFromDescription`) y, si
  esa API no está disponible, cae en un rig estilizado con traje y corbata que
  también tiene cuello articulado.
- Probado con `luau-compile` (compila limpio) y `luau-analyze` (sin lint
  warnings). Los errores de tipo que reporta `luau-analyze` fuera de Studio son
  sólo por los tipos de Roblox, que no existen fuera del engine.
