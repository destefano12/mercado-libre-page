#!/usr/bin/env python3
"""
Chequeos que atrapan lo que el compilador no ve.

    python3 tools/check.py

Luau compila feliz `Enum.Material.Ceramic` o `Config.Teacher.NoExiste`:
el error recien salta en Roblox, en runtime, y si es en el arranque del
servidor te deja sin instituto y sin pistas. Esto lo detecta antes.

    1. toda referencia a Config apunta a una clave que existe
    2. todo Enum.X.Y es un valor real de Roblox
    3. toda clave de idioma usada esta definida, y los tres idiomas
       tienen exactamente las mismas claves
"""

import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Valores validos de los enums que usa el proyecto. No es la lista
# completa de Roblox: es la de las familias que tocamos.
VALID_ENUMS = {
    "Material": {
        "Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Slate", "Concrete",
        "Granite", "Brick", "Pebble", "Cobblestone", "Rock", "Sandstone", "Basalt", "CrackedLava",
        "Limestone", "Pavement", "Salt", "Snow", "Asphalt", "Ground", "Mud", "Glacier", "Sand",
        "Fabric", "Metal", "DiamondPlate", "CorrodedMetal", "Foil", "Glass", "ForceField", "Ice",
        "Grass", "LeafyGrass", "Air", "Water", "CeramicTiles", "ClayRoofTiles", "RoofShingles",
        "Rubber", "Cardboard", "Carpet", "Leather", "Plaster",
    },
    "PartType": {"Ball", "Block", "Cylinder", "Wedge", "CornerWedge"},
    "SurfaceType": {"Smooth", "Glue", "Weld", "Studs", "Inlet", "Universal", "SmoothNoOutlines",
                    "Hinge", "Motor", "SteppingMotor"},
    "NormalId": {"Top", "Bottom", "Front", "Back", "Left", "Right"},
    "Font": {"Gotham", "GothamMedium", "GothamBold", "GothamBlack", "GothamSemibold", "Code",
             "SourceSans", "SourceSansBold", "SourceSansSemibold", "PermanentMarker", "Arcade",
             "Fantasy", "Cartoon", "Highway", "Legacy", "Michroma", "Nunito", "Oswald", "Roboto",
             "RobotoCondensed", "RobotoMono", "Ubuntu", "LuckiestGuy", "Bangers", "Arial"},
    "HumanoidRigType": {"R6", "R15"},
    "HumanoidHealthDisplayType": {"DisplayWhenDamaged", "AlwaysOn", "AlwaysOff"},
    "EasingStyle": {"Linear", "Sine", "Back", "Quad", "Quart", "Quint", "Bounce", "Elastic",
                    "Exponential", "Circular", "Cubic"},
    "EasingDirection": {"In", "Out", "InOut"},
    "AutomaticSize": {"None", "X", "Y", "XY"},
    "ScrollingDirection": {"X", "Y", "XY"},
    "ElasticBehavior": {"WhenScrollable", "Always", "Never"},
    "SortOrder": {"Name", "Custom", "LayoutOrder"},
    "FillDirection": {"Horizontal", "Vertical"},
    "HorizontalAlignment": {"Center", "Left", "Right"},
    "VerticalAlignment": {"Center", "Top", "Bottom"},
    "TextXAlignment": {"Left", "Center", "Right"},
    "TextYAlignment": {"Top", "Center", "Bottom"},
    "ApplyStrokeMode": {"Contextual", "Border"},
    "ZIndexBehavior": {"Global", "Sibling"},
    "SurfaceGuiSizingMode": {"FixedSize", "PixelsPerStud"},
    "CameraType": {"Fixed", "Attach", "Watch", "Track", "Follow", "Custom", "Scriptable", "Orbital"},
    "RaycastFilterType": {"Exclude", "Include"},
    "UserInputState": {"Begin", "Change", "End", "Cancel", "None"},
    "UserInputType": {"MouseButton1", "MouseButton2", "MouseButton3", "MouseWheel", "MouseMovement",
                      "Touch", "Keyboard", "Focus", "Gamepad1", "TextInput", "None"},
    "ContextActionResult": {"Pass", "Sink"},
    "PathStatus": {"Success", "ClosestNoPath", "ClosestOutOfRange", "FailStartNotEmpty",
                   "FailFinishNotEmpty", "NoPath"},
    "Technology": {"Legacy", "Voxel", "Compatibility", "ShadowMap", "Future"},
    "MeshType": {"Head", "Torso", "Wedge", "Sphere", "Cylinder", "FileMesh", "Brick",
                 "Prism", "Pyramid", "ParallelRamp", "RightAngleRamp", "CornerWedge"},
    "HumanoidDisplayDistanceType": {"Viewer", "Subject", "None"},
    "ActuatorRelativeTo": {"Attachment0", "Attachment1", "World"},
    "SortDirection": {"Ascending", "Descending"},
    "TextTruncate": {"None", "AtEnd", "SplitWord"},
    "RenderPriority": {"First", "Input", "Camera", "Character", "Last"},
    "MultiLine": set(),
}

# Propiedades que Roblox NO deja escribir desde un script en runtime.
READ_ONLY = {
    "Lighting.Technology": "se define en el archivo del lugar, no por codigo",
    "Workspace.FilteringEnabled": "es de solo lectura en runtime",
    "Workspace.DistributedGameTime": "es de solo lectura",
}


def lua_files():
    return sorted(SRC.glob("**/*.lua"))


def check_config() -> list[str]:
    text = (SRC / "shared" / "Config.lua").read_text(encoding="utf-8")
    sections = {}
    for match in re.finditer(r"Config\.(\w+)\s*=\s*\{(.*?)^\}", text, re.S | re.M):
        sections[match.group(1)] = set(re.findall(r"^\t(\w+)\s*=", match.group(2), re.M))

    problems = []
    for path in lua_files():
        body = path.read_text(encoding="utf-8")
        aliases = dict(re.findall(r"local (\w+) = Config\.(\w+)\b", body))

        for match in re.finditer(r"Config\.(\w+)\.(\w+)", body):
            section, key = match.groups()
            if section in sections and key not in sections[section]:
                problems.append(f"{path.relative_to(ROOT)}: Config.{section}.{key} no existe")

        for alias, section in aliases.items():
            for match in re.finditer(rf"\b{alias}\.(\w+)", body):
                key = match.group(1)
                if section in sections and key not in sections[section]:
                    problems.append(f"{path.relative_to(ROOT)}: {alias}.{key} (Config.{section}.{key}) no existe")

    return sorted(set(problems))


def check_enums() -> list[str]:
    problems = []
    for path in lua_files():
        body = path.read_text(encoding="utf-8")
        for match in re.finditer(r"Enum\.(\w+)\.(\w+)", body):
            family, item = match.groups()
            if family in VALID_ENUMS and item not in VALID_ENUMS[family]:
                problems.append(f"{path.relative_to(ROOT)}: Enum.{family}.{item} no existe en Roblox")
    return sorted(set(problems))


def check_read_only() -> list[str]:
    problems = []
    for path in lua_files():
        body = path.read_text(encoding="utf-8")
        for prop, why in READ_ONLY.items():
            if re.search(rf"^\s*{re.escape(prop)}\s*=", body, re.M):
                problems.append(f"{path.relative_to(ROOT)}: {prop} {why}")
    return sorted(set(problems))


def check_strings() -> list[str]:
    text = (SRC / "shared" / "Strings.lua").read_text(encoding="utf-8")
    tables = dict(re.findall(r"^local (en|es|pt)(?:: [^=]+)? = \{(.*?)^\}", text, re.S | re.M))
    keys = {name: set(re.findall(r'\["([^"]+)"\]', body)) for name, body in tables.items()}

    problems = []
    for locale in ("es", "pt"):
        for key in sorted(keys["en"] - keys.get(locale, set())):
            problems.append(f"Strings.lua: falta {key!r} en {locale}")
        for key in sorted(keys.get(locale, set()) - keys["en"]):
            problems.append(f"Strings.lua: {key!r} esta en {locale} pero no en en")

    used = set()
    for path in lua_files():
        if path.name == "Strings.lua":
            continue
        body = path.read_text(encoding="utf-8")
        used |= set(re.findall(r'Strings\.get\("([^"]+)"', body))
        used |= set(re.findall(r'(?:topicKey|promptKey|titleKey)\s*=\s*"([^"]+)"', body))
        used |= set(re.findall(r'key\s*=\s*"([a-z]+\.[^"]+)"', body))
        used |= set(re.findall(r'"@([a-z]+\.\w+)"', body))
        used |= set(re.findall(
            r'"((?:hud|menu|phase|day|exam|cheat|item|shop|teacher|punish|notify'
            r'|report|room|error|note|topic|credits)\.[\w.]+)"', body))

    # Una clave que termina en "." o "_" viene de una concatenacion
    # (Strings.get("item." .. id)): no se puede validar como literal,
    # se valida abajo contra los ids reales de Config.
    used = {key for key in used if not key.endswith((".", "_"))}

    for key in sorted(used - keys["en"]):
        problems.append(f"clave de idioma usada y no definida: {key!r}")

    problems.extend(check_dynamic_keys(keys["en"]))
    return problems


def check_dynamic_keys(defined: set[str]) -> list[str]:
    """Las claves que se arman por concatenacion, contra sus ids reales.

    `Strings.get("item." .. id)` solo funciona si TODOS los ids de la
    tienda tienen su clave. Es exactamente el bug que no se ve hasta
    que alguien compra el objeto numero siete.
    """
    problems = []

    config = (SRC / "shared" / "Config.lua").read_text(encoding="utf-8")
    for item_id in re.findall(r'\{ id = "(\w+)"', config):
        for key in (f"item.{item_id}", f"item.desc_{item_id}"):
            if key not in defined:
                problems.append(f"falta la clave {key!r} (id de la tienda {item_id!r})")

    rounds = (SRC / "server" / "RoundManager.lua").read_text(encoding="utf-8")
    for phase in set(re.findall(r'runPhase\("(\w+)"', rounds)) | {"espera"}:
        if f"phase.{phase}" not in defined:
            problems.append(f"falta la clave 'phase.{phase}' (fase del ciclo escolar)")

    return problems


def find_luau() -> str | None:
    """El compilador de Luau, si esta instalado.

    check.py atrapa errores semanticos, pero no un parentesis de mas:
    eso lo ve el compilador. Si esta disponible lo usamos; si no, se
    salta el paso (no es un requisito para empaquetar).
    """
    candidate = os.environ.get("LUAU_COMPILE")
    if candidate and Path(candidate).exists():
        return candidate
    return shutil.which("luau-compile")


def check_syntax() -> list[str]:
    luau = find_luau()
    if not luau:
        return []
    problems = []
    for path in lua_files():
        # `--null` compila y tira el resultado: solo nos interesan
        # los errores, no el bytecode.
        result = subprocess.run([luau, "--null", str(path)],
                                capture_output=True, text=True, errors="replace")
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip().splitlines()
            problems.append(f"{path.relative_to(ROOT)}: {detail[0] if detail else 'no compila'}")
    return problems



def strip_noise(source: str) -> list[str]:
    """El fuente sin comentarios ni cadenas, conservando los renglones.

    Hace falta para buscar usos de verdad: una palabra dentro de un
    comentario de cabecera o dentro de un texto traducido no es un uso.
    Se reemplaza por espacios en vez de borrarse para que los numeros
    de linea sigan siendo los del archivo original.
    """
    out = []
    for line in source.splitlines():
        out.append(list(line))

    text = source
    spans = []
    for match in re.finditer(r"--\[\[.*?\]\]", text, re.S):      # comentario de bloque
        spans.append(match.span())
    for match in re.finditer(r"--(?!\[\[).*", text):              # comentario de linea
        spans.append(match.span())
    for match in re.finditer(r'"(?:[^"\\\n]|\\.)*"', text):        # cadena
        spans.append(match.span())

    blanked = list(text)
    for start, end in spans:
        for index in range(start, end):
            if blanked[index] != "\n":
                blanked[index] = " "
    return "".join(blanked).splitlines()


def check_use_before_declaration() -> list[str]:
    """Locales usadas antes de declararlas.

    Luau compila esto sin decir nada: dentro de la funcion de arriba,
    el nombre resuelve a una GLOBAL que vale nil, y la llamada falla
    en silencio en runtime. Nos comio una mecanica entera (el profesor
    nunca tiraba la goma) sin un solo error en el Output.
    """
    problems = []
    declaration = re.compile(r"^local (?:function )?(\w+)")

    for path in lua_files():
        lines = strip_noise(path.read_text(encoding="utf-8"))
        declared: dict[str, int] = {}
        for number, line in enumerate(lines):
            match = declaration.match(line)
            if match and match.group(1) not in declared:
                declared[match.group(1)] = number

        for name, at in declared.items():
            # Ni un campo de tipo (`opciones: {string}`) ni un
            # parametro (`tool: Tool`) ni un acceso (`x.tool`) cuentan
            # como uso de la local.
            usage = re.compile(rf"(?<![.:\w]){re.escape(name)}\b(?!\s*:)")
            for number in range(at):
                if usage.search(lines[number]):
                    problems.append(
                        f"{path.relative_to(ROOT)}:{number + 1}: usa {name!r}, "
                        f"que recien se declara en la linea {at + 1}")
                    break

    return sorted(set(problems))


def main() -> int:
    checks = [
        ("sintaxis (luau-compile)", check_syntax),
        ("referencias a Config", check_config),
        ("valores de Enum", check_enums),
        ("uso antes de declarar", check_use_before_declaration),
        ("propiedades de solo lectura", check_read_only),
        ("claves de idioma", check_strings),
    ]

    failed = 0
    for name, run in checks:
        problems = run()
        if problems:
            failed += len(problems)
            print(f"✗ {name}: {len(problems)} problema(s)")
            for problem in problems:
                print(f"    {problem}")
        else:
            print(f"✓ {name}")

    if failed:
        print(f"\n{failed} problema(s). Esto reventaria en Roblox, no en el compilador.")
        return 1
    print("\nTodo en orden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
