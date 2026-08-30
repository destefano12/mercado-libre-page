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

Se juega en **primera persona**, como el original: la cámara va trabada y
ves tus propias manos con lo que llevás. Los brazos están en el espacio de
la cámara (`src/client/Viewmodel.lua`), con balanceo al caminar y sway al
girar.

| Tecla | Qué hace |
|---|---|
| `E` | Interactuar (casilleros, kiosco, libros, empollones, cajones, pelota) |
| `1`–`4` | Marcar la alternativa |
| `←` `→` | Cambiar de pregunta |
| `Q` | **Espiar** la hoja del de al lado |
| `R` | **Soplar** tu respuesta a los que están cerca |
| `F` | **Lanzar** lo que tengas en la mano |
| `G` | **Empujar** — tres empujones y el otro se va al piso |
| `B` | **Tirar a la canasta** |
| `Z` | **Prismáticos** (mantener) — con `Q` lees una hoja de lejos |
| `H` | Leer el libro que llevás en la mano |
| `J` | **Pasarle el libro** al compañero que tengas en la mira |
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
- **Pelotas de béisbol** en un cesto al costado del atrio. No hay aro ni
  marcador: tirarlas es el fin en sí mismo. Salen mucho más rápido que la
  de básquet y casi no rebotan, y si le pegás a alguien lo aturdís un
  momento — que es exactamente para lo que se usan.
- **Aerosoles** — pintás cualquier pared, casillero, puerta, pizarra o
  baldosa del colegio, la estatua del atrio, la pantalla del proyector
  del aula y **la cara de otro jugador**. Ocho colores, cuatro grosores.
  Lo que pintás en el colegio queda toda la semana; lo de una cara se
  borra cuando esa persona reaparece.
- **Libros de texto** repartidos por el pasillo — leer uno te deja
  aprendidas **de verdad** dos respuestas del examen que viene, que
  aparecen ya marcadas cuando te sentás. Es la ruta honesta, y existe
  para que copiar sea una decisión y no la única opción.
  Con `J` se lo **pasás a un compañero**: el libro es escaso y el que lo
  juntó decide si se lo queda o lo hace circular. Como el día lo decide
  el promedio del curso, repartir conviene.
- **Alumnos que estudiaron** (NPC) con el libro bajo el brazo. Podés
  pedirles la respuesta — a veces te dicen que no — o tirarlos al piso
  y quedarte con la chuleta. La vía amable es incierta; la bruta es
  segura pero, en pleno examen, carísima.
- **La biblioteca**, al costado del atrio. Estanterías, mesas de lectura
  y, contra el fondo, una que **se corre**: detrás hay una alcoba con la
  hoja de respuestas del examen del día. Revela el doble que el cajón del
  escritorio y no cuesta sospecha — lo que pagás es el recreo entero
  yendo y volviendo.

### Las trampas

- **Espiar (`Q`)** — te llevás la respuesta que tu vecino ya escribió en
  su hoja. Si todavía no la contestó, no hay nada que ver; y de reojo a
  veces se lee mal.
- **Soplar (`R`)** — le pasás tu respuesta a todos los que estén a menos
  de 14 studs. Es la mecánica cooperativa: el que estudió reparte.
- **Chuleta** — revela 3 respuestas correctas del examen, dos veces.
- **El cajón del escritorio del profesor** — con el tirador dorado, en la
  tarima. Revela 2 respuestas y cuesta **casi toda la barra de sospecha**:
  es meter la mano en su escritorio, delante suyo. La jugada del que ya no
  tiene nada que perder. (Su gemela tranquila es la alcoba de la
  biblioteca: el doble de respuestas, cero sospecha, pero hay que ir hasta
  allá en el recreo.)
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

Esta sección estaba escrita al revés, y conviene decir por qué.

La versión anterior perseguía **"que no parezca Roblox"**: nada por encima
del 60 % de saturación, materiales PBR del motor (`Concrete`, `Brick`,
`CeramicTiles`, `CorrodedMetal`) para que las superficies tuvieran grano
real, desgaste geométrico encima — rayones, óxido, baldosas gastadas,
manchas de roce — y un pasillo angosto de techo bajo, hecho claustrofóbico
a propósito.

Después miramos el trailer del juego real. Es **lo contrario en todos los
ejes**: superficies mates, planas y limpias, de color saturado; un atrio
ancho, alto y luminoso; personajes cabezones de piel violeta, rosa y roja;
y todo en primera persona.

Así que la dirección de arte se dio vuelta entera.

### La conclusión incómoda sobre el material

`SmoothPlastic` con color saturado **es** el material correcto. Es la única
superficie verdaderamente lisa de Roblox, y la referencia no tiene grano en
ningún lado. El "plástico" que la versión anterior evitaba a toda costa era
justamente lo que acercaba el resultado; los PBR del motor eran los que
rompían el parecido.

Por lo mismo desaparecieron el desgaste geométrico y el camino de
`SurfaceAppearance` (`Config.Texturas`): dependía de subir imágenes a
Roblox, nunca tuvo un solo id cargado, y con un look plano no aporta nada.

### Paleta

Muestreada de los fotogramas del trailer con `ffmpeg`, no estimada a ojo.

| Elemento | RGB |
|---|---|
| Muro del atrio | `240, 230, 212` |
| Banda turquesa | `86, 178, 176` |
| Piso del atrio (damero) | `218, 156, 132` / `208, 146, 122` |
| Casillero | `154, 180, 226` |
| Piso del aula (tablones) | `214, 152, 128` / `203, 141, 118` |
| Pizarrón | `64, 58, 66` |
| Marco del pizarrón | `176, 112, 84` |
| Mobiliario / escritorio | `215, 145, 108` |
| Silla del aula | `198, 132, 112` |
| Marco de ventana | `206, 126, 102` |
| Caoba de biblioteca | `109, 81, 86` |
| Pantalla de lámpara | `46, 122, 86` |
| Latón | `206, 168, 96` |
| Estatua | `190, 188, 182` |
| Luz cálida | `255, 244, 218` |

**Las aulas no comparten esquema.** `Style.Aulas` tiene una lista de pares
(pared alta, banda baja) y `buildClassroom` toma uno por índice: periwinkle
con banda coral, verde salvia con banda crema, lila con banda gris. Pintar
todas las aulas iguales hacía que el colegio se leyera como un pasillo
repetido.

Todo en `SmoothPlastic`, salvo el `Neon` de las luminarias y el `Glass` del
ventanal. Reflectancia cero en todo menos el vidrio: un solo brillo
especular delata el motor y rompe el dibujo.

### Iluminación

El objetivo es **aplanar**, no dramatizar.

| Propiedad | Antes | Ahora | Por qué |
|---|---|---|---|
| `Ambient` | `28, 30, 34` | `126, 122, 130` | Las sombras ya no caen a negro; una sombra que no llega a negro se lee como un tono pintado |
| `OutdoorAmbient` | `86, 92, 104` | `168, 174, 186` | Ídem |
| `Brightness` | `1.55` | `2.1` | Atrio luminoso |
| `ClockTime` | `15.2` | `13.6` | Sol alto |
| `ShadowSoftness` | `0.35` | `1` | Sombras blandas |
| `EnvironmentSpecularScale` | `0.22` | `0.05` | Superficies mates |
| Saturación (`ColorCorrection`) | `−0.26 … −0.46` | `+0.04 … +0.16` | El cambio más visible de todos |
| `DepthOfFieldEffect` | fuerte | **eliminado** | Era lo que más delataba que esto no era un juego caricaturesco |
| `SunRaysEffect` | `0.03` | `0` | Ídem |
| Bloom | `0.5` | `0.12` | Sólo el ventanal respira |

Se mantiene **Future** por la oclusión ambiental: sin SSAO las esquinas del
atrio se aplanan tanto que se pierde la profundidad. `Lighting.Technology`
es de sólo lectura en runtime, así que la escribe `tools/build_studio.py` en
el archivo del lugar leyéndola de `Config.Estilo.Tecnologia`. Si insertás el
modelo en un lugar tuyo, ponela a mano: **Lighting → Technology → Future**.

### Arquitectura: por qué ya no es claustrofóbico

| Pieza | Antes | Ahora |
|---|---|---|
| Ancho del pasillo | 16 | **46** — es un atrio |
| Altura de losa | 11 | **22** |
| Falso techo | 9.4 | *eliminado* |
| Largo del pasillo | 190 | 150 |
| Altura del aula | 10 | 13 |

El atrio tiene una **claraboya** de neón a lo largo del eje y luminarias
colgadas a los costados; en el centro, una **estatua** de figuras apiladas
sobre pedestal redondo, marcada como pintable para que el sistema de
grafiti la acepte. El aula estrena piso de tablones, **ventanal real** con
marco y parteluces (la pared se arma en cuatro pedazos alrededor del hueco),
pantalla de proyector y cajones con tirador dorado en el escritorio.

Afuera hay prado, una franja de agua y colinas lejanas: sin eso el ventanal
daba al vacío del skybox y el efecto se caía.

### El cuerpo

Los personajes eran R6 estándar — un monigote de Roblox. Ahora hay un
`src/shared/Rig.lua` con **una** tabla de proporciones caricaturescas
(cabeza de 1.7 sobre un total de ~4.8 studs, o sea un tercio del personaje)
que alimenta al jugador, al profesor y a los NPC.

La piel de colores no humanos — violeta, rosa, rojo, celeste — es el rasgo
más reconocible del juego, y sale del `UserId`: el mismo jugador se ve igual
en todas las partidas, sin ocupar almacenamiento y sin depender de que la
API de DataStore esté habilitada.

Al jugador se le impone el cuerpo con un modelo `StarterCharacter` colgado
de `StarterPlayer`, creado en runtime. Es el único método que funciona
también por el `.rbxmx` todo-en-uno: el tipo de avatar del lugar es una
opción de Game Settings que un script no puede tocar.

> Nota de derechos: se replica el **estilo** (proporciones, paleta, tipo de
> sombreado) y las **mecánicas** — nada de eso tiene copyright. No se copian
> los personajes concretos del juego original ni se extraen sus assets.


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
| Un atrio más ancho o un techo más alto | `Config.Escuela.PasilloAncho`, `AlturaPiso` |
| Más aulas | `Config.Escuela.Aulas` (el mapa se rearma solo) |
| Toda la paleta y los materiales | `src/shared/Style.lua` |
| Luz, nubes, bloom, saturación | `Config.Estilo` |
| Future ↔ ShadowMap | `Config.Estilo.Tecnologia` (lo escribe el empaquetador) |
| Piel y pelo de los personajes | `Config.Personaje.Pieles`, `Pelos` |
| Proporciones del cuerpo | `src/shared/Rig.lua` |
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
