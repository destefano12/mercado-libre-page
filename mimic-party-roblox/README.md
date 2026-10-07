# Mimic Party — Roblox

Una recreación completa de **Mimic Party** (FoliesAPP) para Roblox: fiesta de voz
de 2–5 jugadores, una sola toma por ronda, puntuación de melodía/ritmo/ataques
y ruleta con sabotajes, en un teatro construido por código.

```
rojo build -o MimicParty.rbxlx     # ya está hecho: abrí MimicParty.rbxlx
```

---

## 1. Lo que no se pudo copiar, y por qué

**Roblox no puede grabar ni analizar tu voz.** Ningún script tiene acceso a las
muestras del micrófono: el chat de voz es una tubería cerrada, no hay FFT ni
detección de tono. Puntuar una voz real como hace el original es imposible en
esta plataforma, no difícil.

La decisión de diseño de este port es por lo tanto: **se conservan las tres
dimensiones de puntuación exactas y se cambia solo el dispositivo de entrada.**

| Original (Steam / web)        | Este port                                   |
|-------------------------------|---------------------------------------------|
| La garganta genera el sonido  | Mantener apretado genera el sonido          |
| El tono sale de tu voz        | El tono sale de la posición vertical del mouse |
| IA local puntúa melodía/ritmo/ataques | El mismo modelo, mismas tres dimensiones, mismos pesos |
| El timbre no se puntúa        | El timbre no existe → no se puntúa          |
| Una toma, sin repetir         | Una toma, sin repetir (`Config.TAKE.ALLOW_RETRY = false`) |

Todo lo demás es fiel: cuenta atrás simultánea, reproducción uno por uno,
silenciado de la mesa durante la escucha, ruleta compartida, sabotajes reales,
revelación del saboteador solo al reproducir, y los cinco modos de juego.

## 2. Publicar y conseguir el link

El link `roblox.com/games/...` solo lo puede crear tu cuenta. Son dos clics:

1. Abrí **`MimicParty.rbxlx`** con Roblox Studio (doble clic, o File → Open).
2. Probalo ahí mismo: **Test → Start** (o F5). Para probar la fiesta con varios
   jugadores: **Test → Clients and Servers → 2 Players → Start**.
3. **File → Publish to Roblox As…**, ponele nombre, Create.
4. En **Home → Game Settings → Permissions**, pasalo a **Public**.
5. El link aparece en [create.roblox.com](https://create.roblox.com) → Creations
   → tu juego → el botón de los tres puntos → **Copy Game Link**.

Si querés chat de voz real para las reacciones entre rondas (opcional; el juego
funciona sin él), activalo en Game Settings → Communication → Voice Chat. El
silenciado durante la reproducción se aplica solo si está activado — ver
`src/Server/VoiceGate.luau`.

### Si preferís trabajar con Rojo

```bash
rojo serve          # y conectá el plugin de Rojo desde Studio
rojo build -o MimicParty.rbxlx
```

## 3. Cómo se juega

```
    mantener apretado (mouse / Espacio / dedo)  →  estás vocalizando
    mover el mouse arriba y abajo               →  tono, ±9 semitonos
    soltar                                      →  ese ataque termina
```

Una ronda, en orden:

1. **Referencia** — el sonido suena para toda la mesa. Arriba, en amarillo, su
   forma de onda; en el medio, su contorno de tono como línea de puntos.
2. **Cuenta atrás** — 3 · 2 · 1 · ¡YA!, igual para todos.
3. **Toma** — todos graban a la vez. Tu voz se dibuja en verde abajo, en vivo, y
   te escuchás mientras lo hacés. Se corta en seco al final. No hay repetir.
4. **Escucha** — las tomas suenan una por una. La mesa queda silenciada para que
   todos oigan lo mismo. Cada una muestra sus tres medidores y su total.
5. **Ruleta** — un giro para toda la mesa: puntos, multiplicadores o sabotajes.
   Si te toca un sabotaje, elegís víctima; la víctima no se entera hasta que
   suena su propia toma en la ronda siguiente.

Cuatro rondas, y resultados.

## 4. La puntuación

`src/Shared/Scoring.luau`. Tres ejes, cada uno 0–1000:

| Eje | Qué mide | Peso |
|---|---|---|
| **Melodía** | El contorno, **centrado en su media antes de comparar** | 0.40 |
| **Ritmo** | Error de ataque a ataque, penalizado si sobran o faltan | 0.35 |
| **Ataques** | Cuántas veces lo golpeaste | 0.25 |

Ese centrado en la media es la regla que importa: **tu registro no cuenta**. Una
voz grave y una aguda trazando la misma forma puntúan idéntico. Verificado:

```
copia exacta                       mel 1000  rit 1000  atk 1000  TOTAL 1000
misma forma, 12 semitonos arriba   mel 1000  rit 1000  atk 1000  TOTAL 1000
misma forma, 7 semitonos abajo     mel 1000  rit 1000  atk 1000  TOTAL 1000
ritmo corrido 80 ms                mel  823  rit  771  atk 1000  TOTAL  849
falta un ataque                    mel  720  rit  667  atk  667  TOTAL  688
ataques de más (6 en vez de 3)     mel  822  rit  238  atk    0  TOTAL  412
silencio total                     mel    0  rit    0  atk    0  TOTAL    0
```

El servidor es el único que puntúa. El cliente manda solo el contorno, y
`TakeStore.luau` lo sanea antes de que llegue a `Scoring`: recorta tiempos y
tonos al rango legal, descarta NaN, limita a 48 notas y rechaza una segunda
toma. Un cliente modificado no puede inventarse un 1000.

**Para ajustar la dureza:** `Config.SCORING`. `MELODY_TOLERANCE` (semitonos de
error que anulan el eje) y `RHYTHM_TOLERANCE` (segundos) son los dos diales
reales. Un contorno invertido saca 776 hoy, porque ritmo y ataques siguen
perfectos; si querés castigarlo más, subí `WEIGHT_MELODY`.

## 5. La ruleta y los sabotajes

`Roulette.luau` · `Sabotages.luau`. Once segmentos con pesos; alrededor de un
tercio de los giros reparte sabotaje. Los cinco son **SoundEffects nativos de
Roblox aplicados a la toma en vivo** — la toma se arruina de verdad en el grafo
de audio, no es una etiqueta:

| Sabotaje | Implementación |
|---|---|
| Saturación | `DistortionSoundEffect` + `EqualizerSoundEffect` |
| Eco | `EchoSoundEffect` (delay 0.19, feedback 0.62) |
| Cambio de tono | `PitchShiftSoundEffect`, 0.58× o 1.72× al azar |
| Picado | Compuerta sobre el volumen cada 85 ms |
| Sustitución | La toma no se reproduce: la mesa escucha otra cosa |

Un sabotaje que nadie apunta en el tiempo dado se apunta solo, al azar. No
elegir no es una salida.

## 6. Modos

| Modo | Jugadores | Qué es |
|---|---|---|
| **Fiesta** | 2–5 online | Cuatro rondas, ruleta entre rondas. El bucle del servidor. |
| **Pasá el Micro** | 2–5, un dispositivo | Por turnos en la misma pantalla, resultados locales. |
| **Supervivencia** | 1 | 50 sonidos, 3 vidas, objetivo 300 → 720. |
| **Suelto** | 1 | 3 rondas, ruleta de bonus, rutas segura / arriesgada / enfocada. |
| **Racha Diaria** | 1 | 4 sonidos iguales para todos, por fecha UTC. Reinicia 00:00 UTC. |

Los cuatro modos solo corren en el cliente contra el **mismo** `Scoring`, así que
un 740 en Supervivencia y un 740 en fiesta significan lo mismo.

En el lobby: el primer clic en un modo solo lo selecciona, el segundo lo arranca.

## 7. Los sonidos

36 sonidos, 4 paquetes de 9, con los nombres del original.

- **Reaction Studio** — Nice, Bruh, Hello There, Yeet, Wow, Bababooey, Emotional Damage, Why Are You Running, Get Out
- **Wild Voices** — Cat Chirp, Puppy Sneeze, Night Owl, Seal Bark, Big Bird, Ho Ho Ho, Screaming Sheep, Peacock Call, Frog Chorus
- **Rhythm Lab** — Radio Beep, Notification, Error Chime, Doorbell Dance, Ba Dum Tss, Printer Rhythm, Beatbox Fill, Dial-Up Song, Computer Glitch
- **Melody Club** — Slow Melody, Kazoo Fanfare, Synth Steps, Dance Hook, Retro Chorus, Blues Riff, Hey Ya, Opera Moment, Comeback Hook

Cada uno está escrito como un **patrón** (`{t, dur, pitch}`), no como un archivo.
El motor lo reproduce transponiendo un tono sostenido, así que **el juego suena
completo sin subir un solo audio**, y tu toma suena con el mismo instrumento que
la referencia — que es la forma justa de compararlas.

**Para poner audio real:** ponele `asset = "rbxassetid://…"` a la entrada en
`SoundLibrary.luau`. El patrón sigue manejando la puntuación y la forma de onda.

**Para agregar sonidos:** una línea más en un `pack(...)`. Es el equivalente al
Workshop de la versión de Steam; no hace falta tocar nada más.

## 8. El escenario

`src/Server/StageBuilder.luau` lo construye en runtime, con primitivas. Lo que
hace que no parezca una pila de cajas:

- **Molduras anidadas** — tres losas de ancho decreciente en cada borde visible.
- **Cilindros en toda arista expuesta** — nada de esquinas de 90° hacia el público.
- **Telón de 26 paneles** con profundidad alternada y giro por panel: pliegues.
- **Tablado tabla por tabla**, con variación de tono cada tres.
- **Proscenio** de tres carcasas por pilón, flautas, base, capitel y dintel con casetones.
- **Truss real**: dos cordones y arriostramiento cruzado, no una barra.
- **Público** de 96 siluetas con posición, altura, tono y giro aleatorios, oscuro a propósito.
- **Cinco marcas** con incrustación de bronce y pie de micro completo (trípode, columna, brazo, cápsula).

Aguanta cambiarlo por modelos de verdad: lo único que el resto del juego usa es
la carpeta `StageAnchors`.

### Luces

Explícitamente suaves. `src/Server/LightingRig.luau`: exposición en −0.18, bloom
con umbral 1.7 (solo lo cruzan los neones), saturación −0.07, niebla cálida
densidad 0.3, seis cenitales a brillo 1.35 con haz de 86° y apliques de pared a
0.55. **El rig no se anima nunca** — ni estrobos, ni cambios de color, ni en un
sabotaje. El audio lleva el caos; la luz se queda quieta.

### Cámara

`CameraDirector.luau`. Seis planos sobre los anchors, con suavizado exponencial
independiente del framerate (nunca se pasa de largo). El único plano vivo es la
**procesión**: hace dolly desde el fondo de la sala siguiendo el centroide de los
jugadores que caminan hacia el escenario, con salidas escalonadas de 0.45 s para
que parezca un grupo de amigos y no una cinemática. Durante la escucha, la cámara
se acerca a la marca de quien está sonando.

## 9. Estructura

```
src/Shared/      Config · Palette · Net · Signal · SoundLibrary
                 Scoring · Sabotages · Roulette · Characters · Modes
src/Server/      init.server · MatchService · StageBuilder · LightingRig
                 PlayerProfiles · TakeStore · VoiceGate
src/Client/      init.client · CameraDirector · AudioEngine · Booth · SoloRunner
src/Client/UI/   Root · Menu · StagePanel · Waveform · Scoreboard · RouletteUI · Theme
```

`MatchService` es la única autoridad: una corrutina maneja toda la partida y cada
transición se emite con un **deadline absoluto** (`GetServerTimeNow`), así el
cliente nunca negocia el tiempo. Un error en una partida no tumba el servidor:
el bucle está en `pcall` y devuelve la sala al lobby.

Ningún número vive fuera de `Config.luau`.

## 10. Estado

- 29 módulos, 4.898 líneas de Luau. Los 29 compilan (`luau-compile`, sin errores).
- El algoritmo de puntuación está probado con aserciones; la invariancia al
  registro está verificada.
- Los personajes son **solo cosméticos**, a propósito: ninguno puntúa mejor, así
  la ruleta sigue siendo la única fuente de injusticia.
- Sin probar en un servidor real con 5 jugadores — eso necesita tu publicación.
  Lo que sí se puede probar ya: **Test → Clients and Servers → 2 Players**.
