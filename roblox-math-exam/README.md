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

El aula está llena: **20 bancos con compañeros** que escriben, se miran de
reojo y se ponen nerviosos cuando el profe pasa cerca. El profe tiene canas,
anteojos y **cara**: se pone contento cuando ve una prueba bien hecha y hecho
una furia cuando te agarra con el celular. Las paredes tienen láminas de
matemática y de lengua, hay pizarrón verde, reloj con agujas que andan,
biblioteca, bandera y mochilas abajo de los bancos.

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

## Cómo subirlo a Roblox (paso a paso)

Si nunca publicaste un juego, es esto y nada más:

**1. Instalá Roblox Studio** (es gratis y solo para PC/Mac)
   - Entrá a **create.roblox.com** e iniciá sesión con tu cuenta de Roblox
     (la misma con la que jugás; si no tenés, creala ahí).
   - Botón **Start Creating** → descarga **Roblox Studio** → instalás y abrís.

**2. Bajate el archivo del juego**
   - `install/AulaDeMatematica.rbxlx` de este repo (*Download raw file*).
   - Guardalo donde lo encuentres, por ejemplo en Escritorio.

**3. Abrilo**
   - Doble clic en el archivo. Si no abre solo: en Studio, **File → Open from
     File…** y lo elegís.
   - Se abre el aula con todo adentro.

**4. Probalo**
   - Botón **Play** ▶ (arriba a la izquierda). Aparecés sentado en tu banco.
   - Para salir del modo prueba: **Stop** ⏹.

**5. Subilo a tu cuenta**
   - **File → Publish to Roblox As…**
   - Elegí **Create new game**, ponele nombre (ej: "Prueba de Matemática") y
     descripción, y **Create**.
   - Listo: ya está subido. Studio te lo guarda en la nube, no en tu PC.

**6. Hacelo público** (si querés que entren tus amigos)
   - En Studio: **Home → Game Settings → Basic Info**, y en la web:
     **create.roblox.com → Creations → tu juego → ⋯ → Configure → Permissions**
     y ponelo en **Public**.
   - Copiá el link del juego desde **create.roblox.com → Creations → tu juego →
     ⋯ → Copy Link** y mandáselo a quien quieras.

**7. Para jugarlo de verdad**
   - Entrá al link desde roblox.com o desde la app y dale **Jugar**.

Cada vez que cambies algo en Studio, volvés a **File → Publish to Roblox** (sin
el "As…") y se actualiza el juego que ya subiste.

> Ojo: para publicar hay que tener cuenta de Roblox verificada. Si te pide
> verificar el mail, hacelo desde la web de Roblox y volvé a publicar.

## Cómo pasarlo a Roblox Studio

### Opción A — un solo archivo: abrí el lugar y listo ✅

`install/AulaDeMatematica.rbxlx` es **el lugar entero**, con todo el código ya
puesto en su servicio.

1. Bajate ese archivo (en GitHub: entrás al archivo y *Download raw file*).
2. Doble clic (o desde Studio: *File → Open from File…*).
3. **Play** ▶.

No hay nada que insertar, mover ni renombrar: ya está todo ordenado. Cuando lo
quieras tener en tu cuenta, *File → Publish to Roblox As…*, le ponés nombre y
queda subido como lugar tuyo.

Ojo: es un lugar nuevo, así que usalo si arrancás de cero. Si querés meter el
juego dentro de un lugar que **ya tenés armado**, usá la opción B.

### Opción B — los tres `.rbxmx`, para meterlo en un lugar que ya tenés

En `install/` hay tres archivos que traen **todo el código adentro**. Studio los
inserta directo, no hay que copiar y pegar nada.

1. Bajate los tres archivos de `install/` (en GitHub: entrás al archivo y
   *Download raw file*, o bajás el repo entero con *Code → Download ZIP*).
2. Abrí tu lugar en Roblox Studio.
3. En el panel **Explorer**, clic derecho sobre cada servicio → **Insert from
   File…** y elegí el archivo que le corresponde:

   | Clic derecho en | Insertás |
   |---|---|
   | `ReplicatedStorage` | `AulaShared.rbxmx` |
   | `ServerScriptService` | `AulaServer.rbxmx` |
   | `StarterPlayer` → `StarterPlayerScripts` | `AulaClient.rbxmx` |

4. **Play** ▶.

Si no ves el Explorer: pestaña *View* → *Explorer*. Y si no ves
`StarterPlayerScripts`, abrí el triangulito de `StarterPlayer`.

Tiene que quedar exactamente así:

```
ReplicatedStorage
└── Shared                (Folder)      ← AulaShared.rbxmx
ServerScriptService
└── Server                (Script)      ← AulaServer.rbxmx
StarterPlayer
└── StarterPlayerScripts
    └── Client            (LocalScript) ← AulaClient.rbxmx
```

Cuidado con dos cosas al insertar: que el servicio esté **seleccionado el
correcto** (si insertás en el lugar equivocado, arrastrá el objeto al servicio
que va, funciona igual), y que no queden **dos copias** del mismo objeto si
insertaste dos veces — borrá la repetida.

No hace falta tocar el Lighting ni borrar el Baseplate: el propio juego
configura la iluminación de interior al arrancar y saca el baseplate, porque
queda a la misma altura que el piso del aula.

Si tocás el código y querés regenerar el lugar y los bundles:

```bash
python3 tools/build_studio.py
```

### Opción C — Rojo (si vas a seguir programándolo)

```bash
rojo serve default.project.json
```

Y conectás desde el plugin de Rojo en Studio. Es lo más cómodo para iterar:
guardás el archivo en tu editor y Studio se actualiza solo.

### Opción D — a mano

Creás la estructura de abajo y pegás el contenido de cada archivo. Los
ModuleScripts van **adentro** del `Script` / `LocalScript`, no al lado.

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

Vayas por donde vayas: **no hay que crear ningún RemoteEvent a mano** (los crea
`Net.build()`) ni construir el aula (la levanta `ClassroomBuilder` por código
cuando arranca el servidor).

### Si algo no arranca

| Síntoma | Qué pasó |
|---|---|
| "Infinite yield possible on ReplicatedStorage:WaitForChild(\"Shared\")" | La carpeta `Shared` no quedó en `ReplicatedStorage` o quedó con otro nombre. |
| Se ve el aula pero no la hoja ni el HUD | El `Client` no quedó en `StarterPlayerScripts`. Fijate que sea un **LocalScript**, no un Script. |
| No pasa nada de nada | El `Server` no quedó en `ServerScriptService`, o quedó *Disabled* (propiedad `Disabled` en false). |
| El profe no camina | Falta activar el pathfinding del lugar: normalmente no hace falta, pero revisá que el aula esté sobre terreno/piso y no flotando. |

Para probar con más de un alumno: *Test* → *Clients and Servers* → 2 players →
*Start*.

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
- `CharacterArt.lua` — caras, pelo y anteojos hechos con partes y una
  SurfaceGui, sin depender de ningún asset subido. Las expresiones no son
  imágenes: mueven cejas, ojos y una boca de nueve segmentos sobre una
  parábola, así que el profe pasa de contento a furioso de verdad.
- `Theme.lua` / `Util.lua` — paleta y azúcar para construir y animar.

**Servidor**

- `ClassroomBuilder.lua` — construye el aula entera: piso, paredes, ventanal
  lateral con huecos reales y luz natural entrando, luminarias, pizarrón verde
  con bandeja de tizas, escritorio del profe, puerta, y la grilla de 20 bancos
  con su silla, su `Seat`, su hoja, su cartuchera y la mochila abajo. Más la
  decoración: láminas de matemática (Pitágoras, resolvente, áreas, tabla del 7,
  π) y de lengua (acentuación, sujeto y predicado, conectores), reloj de pared
  con agujas que se mueven con la hora real, biblioteca con libros, bandera,
  plantas, cesto de papeles y el cartel de "prohibido el celular". Devuelve
  además los nodos de patrullaje de los pasillos.
- `StudentNPCs.lua` — los compañeros de curso: rigs sentados y anclados (sin
  Humanoid ni física, así 20 alumnos no cuestan nada) que escriben, parpadean,
  se miran de reojo, giran la cabeza cuando el profe pasa y ponen cara de susto
  cuando pillan a alguien. Cuando entra un jugador, el NPC de ese banco se
  levanta y le deja el lugar.
- `TeacherAI.lua` — el profesor: canas, anteojos y cara. Patrulla con
  `PathfindingService`, frena a revisar bancos (los tuyos y los de tus
  compañeros), se va al pizarrón (ventana segura), y tiene visión real — cono
  de FOV + raycast, con la cabeza girando por el `Motor6D` del cuello, así que
  lo que "ve" coincide con lo que ves vos que mira. La expresión sigue lo que
  está haciendo: neutral patrullando, contento revisando una prueba prolija,
  cara de sospecha cuando te ve algo raro y furioso cuando viene a tu banco.
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
| Un aula más grande (y más compañeros) | `Classroom.Rows`, `Classroom.Columns` |
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
