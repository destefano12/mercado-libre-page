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
| `E` | Interactuar (casilleros, kiosco, libros, empollones, pelota) |
| `1`–`4` | Marcar la alternativa |
| `←` `→` | Cambiar de pregunta |
| `Q` | **Espiar** la hoja del de al lado |
| `R` | **Soplar** tu respuesta a los que están cerca |
| `F` | **Lanzar** lo que tengas en la mano |
| `G` | **Empujar** — tres empujones y el otro se va al piso |
| `B` | **Tirar a la canasta** |
| `Z` | **Prismáticos** (mantener) — con `Q` lees una hoja de lejos |
| `H` | Leer el libro que llevás en la mano |
| Clic | Pintar con el aerosol |
| Rueda / `C` | Grosor / color del aerosol |
| `T` | Tienda |
| `M` / `Esc` | Menú |

### El pasillo: la válvula de escape

El recreo no es una sala de espera. Hay:

- **Una pelota de básquet de verdad** — física propia (densidad,
  fricción y rebote), se agarra con `E`, se tira con `B`, y la canasta
  solo cuenta si la pelota cruza el aro **bajando**. Cada canasta da
  créditos.
- **Aerosoles** — pintás cualquier pared, casillero, puerta, pizarra o
  baldosa del colegio. Ocho colores, cuatro grosores. Lo que pintás lo
  ven todos y sigue ahí toda la semana.
- **Libros de texto** repartidos por el pasillo — leer uno te deja
  aprendidas **de verdad** dos respuestas del examen que viene, que
  aparecen ya marcadas cuando te sentás. Es la ruta honesta, y existe
  para que copiar sea una decisión y no la única opción.
- **Alumnos que estudiaron** (NPC) con el libro bajo el brazo. Podés
  pedirles la respuesta — a veces te dicen que no — o tirarlos al piso
  y quedarte con la chuleta. La vía amable es incierta; la bruta es
  segura pero, en pleno examen, carísima.

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
- **Walkie-talkie** — hablás con **todos** los walkies del colegio, sin
  límite de distancia. La herramienta de equipo.
- **Celular** — le pasás un mensaje a **uno** cercano. Más discreto en
  alcance, mucho más descarado si te lo ven en la mano.
- **Prismáticos (`Z`)** — cierran el campo de visión y te dejan leer la
  hoja de alguien a cuarenta studs. Mientras mirás por ellos no ves
  venir al profesor.
- **Empujar (`G`)** — tres empujones y el otro cae; uno por la espalda
  cuenta casi por dos. Al caer se le queda una herramienta.

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
- Y si estás lejos, **te tira una goma de borrar**: predice hacia dónde
  vas y dispara con la puntería de `Config.Goma.Punteria` (1 sería
  perfecta; por debajo se abre un cono de dispersión, así que correr en
  diagonal sirve de algo). Si te pega, te aturde y te descuenta nota.

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

## Dirección de arte

El objetivo es que **no parezca Roblox**: nada de plástico saturado.
Todo lo visual sale de dos archivos — `src/shared/Style.lua` (paleta,
materiales, desgaste) y `src/server/Atmosphere.lua` (luz, cielo,
post-proceso) — y de `Config.Estilo`.

### Dos precisiones antes de empezar

**`Lighting.Technology` no está en Workspace, y no se puede escribir
desde un script.** Es de sólo lectura en runtime; el único sitio donde
Roblox la acepta es el archivo del lugar. Por eso `tools/build_studio.py`
la lee de `Config.Estilo.Tecnologia` y la escribe en el `.rbxlx`. Si
insertás el modelo en un lugar tuyo, ponela a mano: **Lighting →
Technology → Future**. El juego avisa en el Output si quedó en Voxel.

**No existe un objeto `AmbientOcclusion` en Roblox.** La oclusión
ambiental viene incluida en Future — es una de las razones para usarlo.
Con ShadowMap hay sombras proyectadas pero no SSAO, y el colegio se ve
más chato.

### Paleta exacta

Copiala tal cual en Studio si construís piezas a mano.

| Elemento | RGB | Material |
|---|---|---|
| Muro (mitad alta) | `214, 208, 191` | `Concrete` |
| Muro (friso bajo) | `47, 66, 58` | `Brick` |
| Franja de acento | `92, 112, 96` | `Metal` |
| Mancha de roce | `178, 172, 156` | `Concrete` |
| Placa de falso techo | `226, 224, 214` | `Plaster` |
| Placa manchada | `206, 200, 184` | `Plaster` |
| Perfil de aluminio | `158, 160, 163` | `Metal` |
| Losa | `120, 118, 112` | `Concrete` |
| Baldosa A | `150, 146, 136` | `CeramicTiles` |
| Baldosa B | `132, 128, 119` | `CeramicTiles` |
| Baldosa gastada | `118, 114, 106` | `Pavement` |
| Casillero | `40, 74, 82` | `Metal` |
| Casillero (puerta) | `58, 96, 104` | `Metal` |
| Rayón | `96, 116, 120` | `Metal` |
| Óxido | `122, 76, 48` | `CorrodedMetal` |
| Manija | `186, 188, 190` | `Metal` |
| Madera de pupitre | `168, 130, 84` | `WoodPlanks` |
| Madera gastada | `138, 104, 66` | `Wood` |
| Madera oscura | `104, 76, 48` | `Wood` |
| Metal de patas | `74, 78, 84` | `Metal` |
| Asiento | `38, 54, 72` | `Wood` |
| Pizarra | `38, 62, 52` | `Slate` |
| Marco de pizarra | `176, 176, 172` | `Metal` |
| Puerta | `116, 84, 54` | `WoodPlanks` |
| Marco de puerta | `96, 100, 106` | `Metal` |
| Vidrio | `178, 196, 206` | `Glass` |
| Tubo fluorescente | `246, 250, 236` | `Neon` |
| Luz fría | `226, 238, 255` | (color de luz) |
| Cartel de salida | `226, 66, 54` | `Neon` |

Ningún color pasa de ~60% de saturación. Los únicos acentos cálidos son
la madera y el óxido; el rojo del cartel de SALIDA es el único punto
saturado del pasillo, y está ahí para anclar la vista.

Reflectancia: sólo el suelo encerado (`0.06`), el vidrio (`0.25`) y las
manijas (`0.18`) reflejan algo. Un colegio con todo brillante parece un
shopping.

### Iluminación — parámetros exactos

`Lighting`:

| Propiedad | Valor |
|---|---|
| `Technology` | **Future** (en el archivo del lugar) |
| `Brightness` | `1.55` |
| `ClockTime` | `15.2` |
| `GeographicLatitude` | `41` |
| `ExposureCompensation` | `-0.12` |
| `Ambient` | `28, 30, 34` |
| `OutdoorAmbient` | `86, 92, 104` |
| `EnvironmentDiffuseScale` | `0.35` |
| `EnvironmentSpecularScale` | `0.22` |
| `ShadowSoftness` | `0.35` (sólo Future) |
| `GlobalShadows` | `true` |

`Atmosphere`: `Density 0.32`, `Offset 0.1`, `Color 188,192,198`,
`Decay 110,118,130`, `Glare 0.22`, `Haze 1.7`.

`Sky`: `StarCount 0`, `SunAngularSize 9`, `MoonAngularSize 0`. Sin un
skybox propio queda el cielo por defecto, y la Atmosphere más las nubes
lo apagan hasta que lee como día nublado. Si subís tus seis caras, van
en ese objeto (`Lighting/Cielo`).

`Clouds` (en `Terrain`, **sin subir nada**): `Cover 0.86`,
`Density 0.68`, `Color 206,208,214`. Es lo que da el cielo encapotado
de semana de exámenes.

Post-proceso:

| Efecto | Parámetros |
|---|---|
| `BloomEffect` | `Intensity 0.5`, `Size 18`, `Threshold 1.62` |
| `DepthOfFieldEffect` | `FarIntensity 0.06`, `FocusDistance 18`, `InFocusRadius 26`, `NearIntensity 0.1` |
| `SunRaysEffect` | `Intensity 0.03`, `Spread 0.9` |
| `ColorCorrectionEffect` | por clima (abajo) |

El `Threshold` del Bloom es alto a propósito: así sólo florecen los
tubos fluorescentes y el neón. Con el umbral bajo se lava todo y vuelve
el aspecto de juguete.

El `ColorCorrection` cambia con la fase, y es lo que hace que el aula
*se sienta* distinta del pasillo sin tocar una sola luz:

| Clima | Brightness | Contrast | Saturation | Tint |
|---|---|---|---|---|
| Pasillo | `-0.02` | `0.12` | `-0.26` | `236, 241, 248` |
| Examen | `-0.05` | `0.20` | `-0.36` | `230, 238, 248` |
| Tensión (últimos 30 s) | `-0.08` | `0.28` | `-0.46` | `248, 234, 232` |

Las luminarias son `SurfaceLight` empotradas en el falso techo, no
`PointLight`: una luz puntual dentro de un panel largo hace un charco
redondo en el suelo; la de superficie reparte parejo, que es como se ve
un fluorescente real. Cada una: `Face Bottom`, `Angle 110`, `Range 30`,
`Brightness 1.35`, color `226,238,255`. **Sólo una de cada tres proyecta
sombra en el pasillo** (en el aula, todas): en Future cada luz con
sombra cuesta, y con todas encendidas el colegio no corre en una máquina
modesta.

### Materiales y desgaste

Los materiales son los **PBR del propio motor** (`Concrete`, `Brick`,
`CeramicTiles`, `WoodPlanks`, `Metal`, `CorrodedMetal`, `Slate`): ya
traen mapas de normales y rugosidad reales, y con Future se leen como
superficies, no como bloques pintados.

El desgaste es **geometría**, no textura, y por eso no hace falta subir
nada:

- baldosas: damero de 4 studs, una de cada doce gastada (`Pavement`),
  manchas de roce como láminas finas apenas más oscuras;
- casilleros: de cero a tres rayones por puerta, en posición y ángulo
  aleatorios, y óxido en la base de uno de cada tres;
- pupitres: una a tres marcas talladas en la tapa;
- paredes: catorce manchas de roce a la altura del hombro por tramo;
- falso techo: una placa de cada once, manchada por filtración.

Es semilla fija (`Random.new(20240607)`), así que el colegio se ve
idéntico en todos los servidores.

### Texturas PBR propias (opcional)

`SurfaceAppearance` necesita imágenes **subidas a Roblox**: no hay forma
de generarlas por código. Cuando las tengas:

1. En Studio: **Asset Manager → Images → Add Images**, subí los cuatro
   mapas de cada superficie (color, normales, rugosidad, metalidad).
2. Copiá el id de cada uno.
3. Pegalos en `Config.Texturas`:

```lua
Config.Texturas = {
    Pared     = { color = "1234", normal = "1235", rugosidad = "1236", metalidad = "" },
    Piso      = { color = "", normal = "", rugosidad = "", metalidad = "" },
    Casillero = { color = "", normal = "", rugosidad = "", metalidad = "" },
    Pupitre   = { color = "", normal = "", rugosidad = "", metalidad = "" },
    Techo     = { color = "", normal = "", rugosidad = "", metalidad = "" },
}
```

4. Volvé a empaquetar. `Style.applySurfaces` las cuelga sola de cada
   pieza al construir el mapa, y el Output dice cuántas aplicó.

Con los campos vacíos no pasa nada y se usan los materiales del motor.
**Ojo con una cosa**: `SurfaceAppearance` manda sobre `Material`, así
que el color base pasa a ser el del `ColorMap` y `part.Color` deja de
verse. Es lo esperado — la paleta de arriba deja de aplicar a esa pieza.

Qué buscar en cada mapa, si los generás vos:

| Superficie | Cómo debería verse |
|---|---|
| Pared | Cemento pintado, con desconchones y roce a media altura |
| Suelo | Terrazo o vinilo encerado, con vetas y desgaste en las juntas |
| Casillero | Chapa con arañazos direccionales y óxido en los bordes |
| Pupitre | Madera vieja con vetas marcadas y marcas de bolígrafo |
| Techo | Placa acústica perforada, con manchas de humedad |

### Arquitectura: por qué es claustrofóbico

Las proporciones están en `Config.Escuela` y son la mitad del look:

| Pieza | Medida | Por qué |
|---|---|---|
| Ancho del pasillo | **16** studs | Poco menos de tres personas de hombro a hombro. Cruzarse roza. |
| Altura de losa | **11** | Bajo para un edificio público |
| Falso techo | **9.4** | El techo real que ves. Comprime el pasillo. |
| Friso (media pared) | **3.6** de alto | La franja oscura que llevan los institutos |
| Baldosa | **4 × 4** | Repetición que da escala al corredor |
| Placa de techo | **6 × 6** | Ídem, arriba |
| Luminarias | cada **14** | Bandas de luz y sombra a lo largo del pasillo |
| Casillero | **3.1 × 6.4 × 1.9** | 20 por lado, pegados |
| Aula | **36 × 30 × 10** | Cabe justo: 4 filas × 5 pupitres + tarima |
| Separación de pupitres | **6.4 × 6.0** | Lo justo para pasar entre ellos — y para espiar al de al lado |
| Puerta del aula | **6 × 8.5** | Un solo vano; cuando se traba, no hay salida |
| Ventanas | **4 × 6**, a 6.4 de alto | Entra luz de tarde pero no se ve afuera desde el pupitre |

El pasillo tiene dos polos — la cancha en un extremo, el kiosco en el
otro — para que la gente se reparta en el recreo en vez de amontonarse.

---

## Cómo está armado

```
src/shared/      lo que ven el servidor y el cliente
  Config.lua       todos los números del juego, en un solo lugar
  Style.lua        la dirección de arte: paleta, materiales, desgaste
  Strings.lua      es / en / pt, con las mismas claves exactas
  Net.lua          los remotes, declarados una sola vez
  Grades.lua       la aritmética de las notas
  Theme.lua        la paleta de la interfaz
  Util.lua         azúcar para construir en 3D

src/server/      nada de esto lo puede leer el cliente
  Atmosphere       luz, cielo, nubes y post-proceso
  MapBuilder       el instituto entero por código
  QuestionBank     las preguntas Y las respuestas
  Templates        las plantillas de herramientas
  ExamService      quién se sienta dónde, qué contestó, cómo se copia
  ItemService      inventario, casilleros, notas y proyectiles
  GraffitiService  pintar en las paredes (raycast + UV + estampado)
  PlaygroundService la pelota, el aro y el marcador
  BookService      los libros de texto del pasillo
  NerdNPCs         los alumnos que estudiaron
  RadioService     walkie-talkie y celular
  KnockoutService  empujones y nocaut
  TextFilter       el filtro obligatorio de todo texto de jugador
  TeacherAI        patrulla, visión, persecución y goma de borrar
  SuspicionService la barra de sospecha
  PunishService    cono, expulsión, penalización
  RoundManager     el ciclo escolar
  ShopService      tienda y premios
  DataService      guardado persistente
  CharacterService uniformes, rigs de profesor y alumno, el cono
  LobbyService     salas entre servidores

src/client/      sólo dibuja y manda intenciones
  Hud, ExamUI, NoteUI, ShopUI, MainMenu, LobbyUI,
  GraffitiUI, RadioUI, ZoomUI, CameraDirector, Poses, Music
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
| Que la goma tenga mejor puntería | `Config.Goma.Punteria` |
| Exámenes más largos | `Config.Examen.PreguntasBase`, `PreguntasPorDia` |
| Un pasillo más ancho o un techo más alto | `Config.Escuela.PasilloAncho`, `AlturaFalsoTecho` |
| Más aulas | `Config.Escuela.Aulas` (el mapa se rearma solo) |
| Toda la paleta y los materiales | `src/shared/Style.lua` |
| Luz, nubes, bloom, saturación | `Config.Estilo` |
| Future ↔ ShadowMap | `Config.Estilo.Tecnologia` (lo escribe el empaquetador) |
| Texturas PBR propias | `Config.Texturas` |
| Cuánto se puede pintar | `Config.Grafiti.*` |
| La pelota (rebote, fuerza, aro) | `Config.Pasillo.*` |
| Empujones para tirar a alguien | `Config.Nocaut.EmpujonesParaKO` |
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
4. **uso antes de declarar** — una local usada más arriba de donde se
   declara resuelve a una *global* que vale `nil`, y la llamada falla en
   silencio. Nos comió una mecánica entera (el profesor nunca tiraba la
   goma) sin un solo error en el Output;
5. **propiedades de solo lectura** — `Lighting.Technology` y compañía;
6. **idiomas** — que las tres tablas tengan exactamente las mismas
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
