#!/usr/bin/env python3
"""
Empaqueta el juego para Roblox Studio.

    python3 tools/build_studio.py

Genera dos formas de llevarlo a Studio, las dos con el codigo fuente
embebido (no hay que copiar y pegar nada a mano ni instalar Rojo):

    install/AulaDeMatematica.rbxlx   el lugar entero, listo para abrir
    install/AulaShared.rbxmx         \\
    install/AulaServer.rbxmx          >  para insertar en un lugar propio
    install/AulaClient.rbxmx         /
"""

from pathlib import Path

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
    ("AulaShared.rbxmx", "Folder", "Shared", None, "shared"),
    ("AulaServer.rbxmx", "Script", "Server", "init.server.lua", "server"),
    ("AulaClient.rbxmx", "LocalScript", "Client", "init.client.lua", "client"),
]

PLACE_NAME = "AulaDeMatematica.rbxlx"


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
         children: list[str], indent: int) -> str:
    pad = "  " * indent
    lines = [f'{pad}<Item class="{class_name}" referent="{referent}">',
             f"{pad}  <Properties>",
             f'{pad}    <string name="Name">{name}</string>']
    if source is not None:
        lines.append(f'{pad}    <ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    lines.append(f"{pad}  </Properties>")
    lines.extend(children)
    lines.append(f"{pad}</Item>")
    return "\n".join(lines)


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


def build_place() -> Path:
    """El lugar completo: cada bundle ya colgado del servicio que le toca.

    Los servicios que no estan listados (Players, SoundService, etc.) los
    crea Studio sola al abrir. El aula, la iluminacion y el spawn los
    arma el propio juego al arrancar, asi que el lugar va vacio.
    """
    referent = Referent()

    services = [
        item("Workspace", "Workspace", referent.next(), None, [], 1),
        item("Lighting", "Lighting", referent.next(), None, [], 1),
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
    for target in [build_place()] + build_models():
        size = target.stat().st_size / 1024
        print(f"{target.relative_to(ROOT)}  ({size:.0f} KB)")


if __name__ == "__main__":
    main()
