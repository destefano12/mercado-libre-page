# Finals Week — réplica multijugador en Roblox

Una semana de exámenes en un instituto. Cinco días, un profesor que
patrulla, y un equipo de alumnos que tiene que aprobar — copiándose si
hace falta, sin que lo pillen.

Todo está hecho de cero en Luau: el mapa, la IA del profesor, los
exámenes, las trampas, los castigos, la economía y las salas. **No hay
que subir ningún asset ni instalar nada**: el instituto se construye por
código al arrancar el servidor y los sonidos salen de los archivos que
Roblox ya trae.

---

## Cómo lo pongo en Roblox Studio

### Opción A — el juego entero, un solo archivo (lo más rápido)

1. Abrí `install/FinalsWeek.rbxlx` con doble clic. Es un *lugar*
   completo: se abre en Studio y le das **Play**. No hay que hacer nada
   más.

### Opción B — meterlo en un lugar tuyo

1. En Studio, con tu lugar abierto: clic derecho sobre **Workspace** →
   **Insert from File…**
2. Elegí `install/FinalsWeek-TODO-EN-UNO.rbxmx`.
3. Dale **Play**.

Ese modelo trae adentro un script instalador que reparte el código por
donde Roblox exige que viva:

```
Shared  ->  ReplicatedStorage
Client  ->  StarterPlayer/StarterPlayerScripts
Server  ->  ServerScriptService
```

y después se borra solo. En el Output vas a ver el arranque paso a paso:

```
[Finals Week] remotes listos
[Finals Week] banco de preguntas en ServerStorage
[Finals Week] plantillas de herramientas
[Mapa] Instituto listo: 2 aulas, 40 pupitres, 36 casilleros.
[Finals Week] instituto construido
...
[Finals Week] Servidor listo.
```

Si algo falla, ese log dice exactamente **qué** paso falló y el resto
del juego sigue en pie.

> **Salas y guardado**: las salas usan `MemoryStoreService` +
> `TeleportService`, y el progreso usa `DataStoreService`. Ninguno de
> los dos existe en Studio hasta que el juego está **publicado** y
> tiene la API habilitada (Game Settings → Security → *Enable Studio
> Access to API Services*). Mientras tanto el juego avisa y se juega
> igual, con progreso en memoria.

---

## Cómo se juega

Un **día** son tres fases seguidas, y cinco días son la Semana Final.

| Fase | Dura | Qué pasa |
|---|---|---|
| **Recreo** | 55 s | Pasillo libre: abrí casilleros, comprá en el kiosco, armá el plan con tus compañeros. Suena la campana. |
| **Examen** | 165 s | Todos al pupitre asignado, las puertas se traban, el profesor patrulla. Respondé — o copiate. |
| **Boletín** | 22 s | Nota del día (examen + conducta), créditos y cuántos días lleva desaprobados el curso. |

Cada día que pasa hay más preguntas y más difíciles. Si el curso
desaprueba **3 días**, se termina la partida y la semana vuelve a
empezar.

### Controles

| Tecla | Qué hace |
|---|---|
| `E` | Interactuar (casilleros, kiosco) |
| `1`–`4` | Marcar la alternativa |
| `←` `→` | Cambiar de pregunta |
| `Q` | **Espiar** la hoja del de al lado |
| `R` | **Soplar** tu respuesta a los que están cerca |
| `F` | **Lanzar** lo que tengas en la mano |
| `T` | Tienda |
| `M` / `Esc` | Menú |

### Las trampas

- **Espiar (`Q`)** — te llevás la respuesta que tu vecino ya escribió en
  su hoja. Si todavía no la contestó, no hay nada que ver; y de reojo a
  veces se lee mal.
- **Soplar (`R`)** — le pasás tu respuesta a todos los que estén a menos
  de 14 studs. Es la mecánica cooperativa: el que estudió reparte.
- **Chuleta** — revela 3 respuestas correctas del examen, dos veces.
- **Nota / avioncito** — escribís `pregunta → letra`, apuntás y lo
  lanzás. Al impactar, la respuesta se escribe **sola** en la hoja del
  que la recibe.
- **Bolita de papel** — no lleva nada: hace ruido donde cae y el
  profesor va a mirar. Es como se abre una ventana para los demás.

Todo lo anterior sube la **sospecha**, y sube mucho más si el profesor
te está mirando.

### El profesor

Corre entero en el servidor:

- **Patrulla** los pasillos entre filas con `PathfindingService`, se
  planta a mirar una fila y a veces se da vuelta a escribir en la
  pizarra — esos segundos de espaldas son *la* ventana para copiarse.
- **Ve** con un cono real: primero el ángulo (producto punto contra su
  vector frontal), después un `Raycast` para confirmar que no hay una
  pared o un pupitre tapando. Los muebles bajos no te salvan la cabeza.
- Si alguien viene acumulando sospecha sin cruzar el umbral, **se va
  acercando a esa fila**. El aviso llega antes que el castigo.
- Al cruzar el umbral, **corre** hacia el infractor.

### Los castigos

1. **Primera vez** — cono de la verguenza: te lo pone en la cabeza, te
   tapa parte de la pantalla, te frena y te descuenta 22 puntos.
2. **Segunda vez** — a la **sala de castigo**: te perdés lo que queda
   del examen y volvés al pupitre cuando se cumple la condena.

Después de cada sanción hay unos segundos de inmunidad, para que no te
castiguen tres veces seguidas en el mismo lugar.

### Economía

Los créditos salen del rendimiento: por acierto, por aprobar, por
terminar el examen sin castigos y por sobrevivir la semana. Se gastan en
el kiosco del pasillo, en objetos de trampa y en estética (gorra,
mochila, anteojos, campera). Todo se guarda en `DataStore`.

---

## Cómo está armado

```
src/shared/      lo que ven el servidor y el cliente
  Config.lua       todos los números del juego, en un solo lugar
  Strings.lua      es / en / pt, con las mismas claves exactas
  Net.lua          los remotes, declarados una sola vez
  Grades.lua       la aritmética de las notas
  Theme.lua        la paleta
  Util.lua         azúcar para construir en 3D

src/server/      nada de esto lo puede leer el cliente
  MapBuilder       el instituto entero por código
  QuestionBank     las preguntas Y las respuestas
  Templates        las plantillas de herramientas
  ExamService      quién se sienta dónde, qué contestó, cómo se copia
  ItemService      inventario, casilleros, notas y proyectiles
  TeacherAI        patrulla, visión, persecución
  SuspicionService la barra de sospecha
  PunishService    cono, expulsión, penalización
  RoundManager     el ciclo escolar
  ShopService      tienda y premios
  DataService      guardado persistente
  CharacterService uniformes, el rig del profesor, el cono
  LobbyService     salas entre servidores

src/client/      solo dibuja y manda intenciones
  Hud, ExamUI, NoteUI, ShopUI, MainMenu, LobbyUI,
  CameraDirector, Music
```

### Dos reglas que se respetan en todo el código

**El servidor manda claves, no texto.** Nunca viaja una frase armada:
viaja `{ key = "notify.passed", args = { grade = "B" } }`. Cada jugador
la ve en el idioma que tiene puesto en su Roblox, y en la misma partida
pueden convivir los tres.

**El cliente nunca dice el resultado.** Manda "elijo la B", "quiero
espiar", "apunto para allá". Quién tiene razón, si alcanzan los
créditos, si el profesor te vio y dónde cae el papelito lo decide
siempre el servidor. Las respuestas correctas viven en
`ServerScriptService` y no salen de ahí.

---

## Tocarle los números

Casi todo el balance está en `src/shared/Config.lua`:

| Querés… | Tocá |
|---|---|
| Más o menos tiempo por fase | `Config.Ronda.Segundos*` |
| Que el profesor vea más lejos / más ancho | `Config.Profesor.DistanciaVision`, `AnguloVision` |
| Que perdone más o menos | `Config.Sospecha.*` |
| Castigos más duros | `Config.Castigo.*` |
| Exámenes más largos | `Config.Examen.PreguntasBase`, `PreguntasPorDia` |
| Más aulas | `Config.Escuela.Aulas` (el mapa se rearma solo) |
| Precios | `Config.Economia.Tienda` |
| Música propia | `Config.Musica.IdPersonalizado` |

Después de tocar algo, volvé a empaquetar:

```bash
python3 tools/build_studio.py
```

### `tools/check.py`

`build_studio.py` no empaqueta nada si esto no pasa. Atrapa lo que el
compilador no ve y que en Roblox solo se descubre en runtime — cuando ya
te dejó parado en el vacío sin ningún mensaje:

1. **sintaxis** — corre `luau-compile` si está instalado;
2. **`Config.X.Y`** — que la clave exista de verdad;
3. **`Enum.X.Y`** — que sea un valor real de Roblox (`Enum.Material.Ceramic`
   compila perfecto y no existe);
4. **propiedades de solo lectura** — `Lighting.Technology` y compañía;
5. **idiomas** — que las tres tablas tengan exactamente las mismas
   claves, que ninguna clave usada falte, y que las que se arman por
   concatenación (`"item." .. id`) existan para **todos** los ids de la
   tienda.

```bash
python3 tools/check.py
```

### Con Rojo

`default.project.json` está listo si preferís trabajar con Rojo:

```bash
rojo serve
```
