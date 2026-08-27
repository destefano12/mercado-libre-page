#!/usr/bin/env python3
"""
Genera los .rbxmx que se insertan directo en Roblox Studio
(clic derecho sobre el servicio -> "Insert from File...").

Cada archivo trae adentro el codigo fuente de todos los modulos, asi que
no hay que copiar y pegar nada a mano ni instalar Rojo.

    python3 tools/build_rbxmx.py

Salida en install/:
    AulaShared.rbxmx  -> ReplicatedStorage
    AulaServer.rbxmx  -> ServerScriptService
    AulaClient.rbxmx  -> StarterPlayer/StarterPlayerScripts
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

# (archivo de salida, clase del contenedor, nombre, script de entrada, carpeta)
BUNDLES = [
    ("AulaShared.rbxmx", "Folder", "Shared", None, "shared"),
    ("AulaServer.rbxmx", "Script", "Server", "init.server.lua", "server"),
    ("AulaClient.rbxmx", "LocalScript", "Client", "init.client.lua", "client"),
]


class Referent:
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


def build(out_name: str, container_class: str, container_name: str,
          entry_file: str | None, folder: str) -> Path:
    referent = Referent()
    directory = SRC / folder

    modules = sorted(
        path for path in directory.glob("*.lua")
        if path.name != entry_file
    )

    children = [
        item("ModuleScript", path.stem, referent.next(),
             path.read_text(encoding="utf-8"), [], 2)
        for path in modules
    ]

    entry_source = (directory / entry_file).read_text(encoding="utf-8") if entry_file else None
    root = item(container_class, container_name, referent.next(),
                entry_source, children, 1)

    OUT.mkdir(exist_ok=True)
    target = OUT / out_name
    target.write_text(f"{HEADER}\n{root}\n</roblox>\n", encoding="utf-8")
    return target


def main() -> None:
    for out_name, container_class, container_name, entry_file, folder in BUNDLES:
        target = build(out_name, container_class, container_name, entry_file, folder)
        size = target.stat().st_size / 1024
        print(f"{target.relative_to(ROOT)}  ({size:.0f} KB)")


if __name__ == "__main__":
    main()
