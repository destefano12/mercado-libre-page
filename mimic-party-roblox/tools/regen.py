import pathlib, re
palette_src = pathlib.Path("Palette.luau").read_text()
config_src  = re.sub(r'\nreturn Config\s*$', '\n', pathlib.Path("Config.luau").read_text().rstrip())
stage_src   = re.sub(r'\nreturn StageBuilder\s*$', '\n', pathlib.Path("StageBuilder.luau").read_text().rstrip())
stage_src   = stage_src.replace('require("./Palette")', 'PALETTE').replace('require("./Config")', 'CONFIG')
dump = pathlib.Path("dump.luau").read_text().split('local StageBuilder = require("./StageBuilder")', 1)[1]
dump = dump.replace("StageBuilder.build()\n", "", 1).split("local summary = {}")[0]
pathlib.Path("combined.luau").write_text(f'''local stub = require("./roblox_stub")
local Vector3, Color3, CFrame = stub.Vector3, stub.Color3, stub.CFrame
local Enum, Instance, Random = stub.Enum, stub.Instance, stub.Random
local UDim2, Vector2, Font = stub.UDim2, stub.Vector2, stub.Font
local game, workspace = stub.game, stub.Workspace
local PALETTE = (function()
{palette_src}
end)()
local CONFIG = (function()
{config_src}
return Config
end)()
local StageBuilder = (function()
{stage_src}
return StageBuilder
end)()
StageBuilder.build()
{dump}
''')
