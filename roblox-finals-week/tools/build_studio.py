#!/usr/bin/env python3
"""
Empaqueta el juego para Roblox Studio.

    python3 tools/build_studio.py

Genera dos formas de llevarlo a Studio, las dos con el codigo fuente
embebido (no hay que copiar y pegar nada a mano ni instalar Rojo):

    install/FinalsWeek-TODO-EN-UNO.rbxmx  un solo modelo que se
                                          instala solo al arrancar
    install/FinalsWeek.rbxlx              el lugar entero, listo para abrir
    install/FinalsWeekShared.rbxmx        \\
    install/FinalsWeekServer.rbxmx         >  por si preferis armarlo vos
    install/FinalsWeekClient.rbxmx        /
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "install"

HEADER = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
    'version="4">'
)

# (nombre del bundle, clase del contenedor, nombre, script de entrada, carpeta)
BUNDLES = [
    ("FinalsWeekShared.rbxmx", "Folder", "Shared", None, "shared"),
    ("FinalsWeekServer.rbxmx", "Script", "Server", "init.server.lua", "server"),
    ("FinalsWeekClient.rbxmx", "LocalScript", "Client", "init.client.lua", "client"),
]

PLACE_NAME = "FinalsWeek.rbxlx"
ALL_IN_ONE_NAME = "FinalsWeek-TODO-EN-UNO.rbxmx"


class Referent:
    """Los referent tienen que ser unicos dentro de cada archivo."""

    def __init__(self):
        self.value = 0

    def next(self) -> str:
        self.value += 1
        return f"RBX{self.value}"


def cdata(source: str) -> str:
    # El fuente no puede contener "]]>" o cortaria el bloque CDATA.
    if "]]>" in source:
        raise ValueError("el fuente contiene ']]>' y rompe el CDATA")
    return f"<![CDATA[{source}]]>"


def item(class_name: str, name: str, referent: str, source: str | None,
         children: list[str], indent: int, extra: list[str] | None = None) -> str:
    pad = "  " * indent
    lines = [f'{pad}<Item class="{class_name}" referent="{referent}">',
             f"{pad}  <Properties>",
             f'{pad}    <string name="Name">{name}</string>']
    if source is not None:
        lines.append(f'{pad}    <ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    for line in extra or []:
        lines.append(f"{pad}    {line}")
    lines.append(f"{pad}  </Properties>")
    lines.extend(children)
    lines.append(f"{pad}</Item>")
    return "\n".join(lines)


def cframe(x: float, y: float, z: float) -> str:
    """CFrame sin rotacion, en el formato que serializa Roblox."""
    return (
        '<CoordinateFrame name="CFrame">'
        f"<X>{x}</X><Y>{y}</Y><Z>{z}</Z>"
        "<R00>1</R00><R01>0</R01><R02>0</R02>"
        "<R10>0</R10><R11>1</R11><R12>0</R12>"
        "<R20>0</R20><R21>0</R21><R22>1</R22>"
        "</CoordinateFrame>"
    )


def vector3(name: str, x: float, y: float, z: float) -> str:
    return f'<Vector3 name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>'


# Piso y spawn de emergencia. El juego los borra/reubica al arrancar; estan
# para que, si el servidor alguna vez se cae, caigas parado en un piso y no
# en el vacio (que es imposible de diagnosticar mirando la pantalla).
BASEPLATE = [
    vector3("size", 512, 1, 512),
    cframe(0, -0.5, 60),
    '<bool name="Anchored">true</bool>',
    '<int name="BrickColor">194</int>',
    '<token name="Material">816</token>',
]

SPAWN = [
    vector3("size", 12, 1, 12),
    cframe(0, 4, 84),
    '<bool name="Anchored">true</bool>',
    '<bool name="Neutral">true</bool>',
    '<int name="BrickColor">194</int>',
]

# Lighting.Technology es de solo lectura desde un script, asi que la
# sombra buena se define aca, en el archivo del lugar. 3 = ShadowMap.
LIGHTING = ['<token name="Technology">3</token>']


def bundle(referent: Referent, container_class: str, container_name: str,
           entry_file: str | None, folder: str, indent: int) -> str:
    """Un contenedor con todos los ModuleScripts de una carpeta adentro."""
    directory = SRC / folder
    modules = sorted(p for p in directory.glob("*.lua") if p.name != entry_file)

    children = [
        item("ModuleScript", path.stem, referent.next(),
             path.read_text(encoding="utf-8"), [], indent + 1)
        for path in modules
    ]

    entry = (directory / entry_file).read_text(encoding="utf-8") if entry_file else None
    return item(container_class, container_name, referent.next(), entry, children, indent)


def write(name: str, body: str) -> Path:
    OUT.mkdir(exist_ok=True)
    target = OUT / name
    target.write_text(f"{HEADER}\n{body}\n</roblox>\n", encoding="utf-8")
    return target


def build_models() -> list[Path]:
    written = []
    for out_name, container_class, container_name, entry_file, folder in BUNDLES:
        referent = Referent()
        body = bundle(referent, container_class, container_name, entry_file, folder, 1)
        written.append(write(out_name, body))
    return written


def build_all_in_one() -> Path:
    """Un solo modelo que insertas donde sea y se instala solo.

    Adentro van los tres bundles mas un Script instalador que los
    reparte por los servicios que Roblox exige. El Server va apagado y
    lo prende el instalador recien cuando Shared ya esta en su lugar.
    """
    referent = Referent()

    installer = item(
        "Script", "Instalador", referent.next(),
        (SRC / "installer" / "Instalador.server.lua").read_text(encoding="utf-8"),
        [], 2,
    )

    children = [installer]
    for _, container_class, container_name, entry_file, folder in BUNDLES:
        extra = ['<bool name="Disabled">true</bool>'] if container_class == "Script" else None
        body = bundle(referent, container_class, container_name, entry_file, folder, 2)
        if extra:
            # El Server arranca apagado: se prende cuando Shared ya esta puesto.
            body = body.replace(
                f'<string name="Name">{container_name}</string>',
                f'<string name="Name">{container_name}</string>\n      {extra[0]}',
                1,
            )
        children.append(body)

    root = item("Model", "FinalsWeek", referent.next(), None, children, 1)
    return write(ALL_IN_ONE_NAME, root)


def build_place() -> Path:
    """El lugar completo: cada bundle ya colgado del servicio que le toca.

    Los servicios que no estan listados (Players, SoundService, etc.) los
    crea Studio sola al abrir. El instituto lo arma el juego al arrancar; el
    baseplate y el spawn que van aca son la red de seguridad.
    """
    referent = Referent()

    services = [
        item("Workspace", "Workspace", referent.next(), None, [
            item("Part", "Baseplate", referent.next(), None, [], 2, BASEPLATE),
            item("SpawnLocation", "SpawnLocation", referent.next(), None, [], 2, SPAWN),
        ], 1),
        item("Lighting", "Lighting", referent.next(), None, [], 1, LIGHTING),
        item("ReplicatedStorage", "ReplicatedStorage", referent.next(), None, [
            bundle(referent, "Folder", "Shared", None, "shared", 2),
        ], 1),
        item("ServerScriptService", "ServerScriptService", referent.next(), None, [
            bundle(referent, "Script", "Server", "init.server.lua", "server", 2),
        ], 1),
        item("StarterPlayer", "StarterPlayer", referent.next(), None, [
            item("StarterPlayerScripts", "StarterPlayerScripts", referent.next(), None, [
                bundle(referent, "LocalScript", "Client", "init.client.lua", "client", 3),
            ], 2),
        ], 1),
    ]

    return write(PLACE_NAME, "\n".join(services))


def main() -> None:
    # Nada de empaquetar algo que no pasa los chequeos: un enum
    # inventado o una clave de Config que no existe se ve recien en
    # Roblox, y ahi te deja sin instituto.
    import check

    if check.main() != 0:
        raise SystemExit("hay problemas: no se empaqueta nada")

    print()
    for target in [build_all_in_one(), build_place()] + build_models():
        size = target.stat().st_size / 1024
        print(f"{target.relative_to(ROOT)}  ({size:.0f} KB)")


if __name__ == "__main__":
    main()
