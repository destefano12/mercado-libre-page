#!/usr/bin/env python3
"""
Chequeos que atrapan lo que el compilador no ve.

    python3 tools/check.py

Luau compila feliz `Enum.Material.Ceramic` o `Config.Teacher.NoExiste`:
el error recien salta en Roblox, en runtime, y si es en el arranque del
servidor te deja sin aula y sin pistas. Esto lo detecta antes.

    1. toda referencia a Config apunta a una clave que existe
    2. todo Enum.X.Y es un valor real de Roblox
    3. toda clave de idioma usada esta definida, y los tres idiomas
       tienen exactamente las mismas claves
"""

import re
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
    tables = dict(re.findall(r"^local (en|es|pt) = \{(.*?)^\}", text, re.S | re.M))
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
        used |= set(re.findall(r'"((?:hud|paper|phone|notify|error|menu|teacher|topic|choice)\.[\w.]+)"', body))

    for key in sorted(used - keys["en"]):
        problems.append(f"clave de idioma usada y no definida: {key!r}")

    return problems


def main() -> int:
    checks = [
        ("referencias a Config", check_config),
        ("valores de Enum", check_enums),
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
