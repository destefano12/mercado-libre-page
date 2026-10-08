# tools/ — mirador del escenario

Renderiza el teatro **desde la geometría que `StageBuilder.luau` construye de
verdad**. No dibuja una idea del escenario: ejecuta el módulo real contra un
stub de Roblox, vuelca cada pieza con su transformación y la proyecta desde las
mismas anclas de cámara que usa el juego, con las 22 luces que el rig coloca.

```bash
cp ../src/Shared/Palette.luau ../src/Shared/Config.luau .
sed -e 's|require(game.ReplicatedStorage.Shared.Palette)|require("./Palette")|' \
    -e 's|require(game.ReplicatedStorage.Shared.Config)|require("./Config")|' \
    ../src/Server/StageBuilder.luau > StageBuilder.luau
python3 regen.py && luau combined.luau > venue.json
python3 render.py      # tomas del escenario
python3 hud.py         # con la interfaz encima
```

Necesita `luau` (luau-lang/luau releases) y Python con PIL + numpy.

Encontró, en una sola pasada, seis bugs que el código no delataba leyéndolo:
un poste de 62 studs atravesando la sala, los pies de micrófono acostados, el
wash frontal apuntando a la platea, la cámara de la procesión metida dentro del
público, el pasillo central tapado de sillas y las caras sin luz frontal.
