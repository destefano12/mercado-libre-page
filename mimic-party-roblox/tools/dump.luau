-- dump.luau — runs the real StageBuilder against the stub and prints the venue
-- as JSON: every part with its world transform, plus the camera anchors.

local stub = require("./roblox_stub")

-- The module expects these as globals, exactly as Roblox provides them.
_G.Vector3 = stub.Vector3
_G.Color3 = stub.Color3
_G.CFrame = stub.CFrame
_G.Enum = stub.Enum
_G.Instance = stub.Instance
_G.Random = stub.Random
_G.game = stub.game
_G.workspace = stub.Workspace

local StageBuilder = require("./StageBuilder")
StageBuilder.build()

-- ── json ─────────────────────────────────────────────────────────────────────
local function num(x)
    if x ~= x or x == math.huge or x == -math.huge then return "0" end
    return string.format("%.4f", x)
end
local out = {}
local function w(s) table.insert(out, s) end

local function vec(v) return ("[%s,%s,%s]"):format(num(v.X), num(v.Y), num(v.Z)) end
local function col(c) return ("[%s,%s,%s]"):format(num(c.R), num(c.G), num(c.B)) end
local function mat(r)
    local parts = {}
    for i = 1, 9 do parts[i] = num(r[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
end

local IDENTITY = { 1,0,0, 0,1,0, 0,0,1 }

w('{"parts":[')
local first = true
local counts = {}
for _, inst in ipairs(stub.ALL) do
    local class = rawget(inst, "ClassName")
    if class == "Part" or class == "WedgePart" or class == "SpawnLocation" then
        local cframe = rawget(inst, "CFrame")
        local pos = cframe and cframe.p or rawget(inst, "Position")
        local rot = cframe and cframe.r or IDENTITY
        local shapeEnum = rawget(inst, "Shape")
        local shape = "box"
        if class == "WedgePart" then
            shape = "wedge"
        elseif shapeEnum and shapeEnum.Name == "Cylinder" then
            shape = "cylinder"
        elseif shapeEnum and shapeEnum.Name == "Ball" then
            shape = "ball"
        end
        local material = rawget(inst, "Material")
        counts[shape] = (counts[shape] or 0) + 1
        if not first then w(",") end
        first = false
        w(('{"shape":"%s","name":%q,"size":%s,"pos":%s,"rot":%s,"color":%s,"material":%q,"transparency":%s,"reflectance":%s}')
            :format(shape, tostring(rawget(inst, "Name")),
                vec(rawget(inst, "Size")), vec(pos), mat(rot),
                col(rawget(inst, "Color")),
                material and material.Name or "SmoothPlastic",
                num(rawget(inst, "Transparency") or 0),
                num(rawget(inst, "Reflectance") or 0)))
    end
end
w('],"cameras":{')

first = true
for _, inst in ipairs(stub.ALL) do
    local class = rawget(inst, "ClassName")
    local name = rawget(inst, "Name")
    if class == "CFrameValue" and name:match("^Cam") then
        local value = rawget(inst, "Value")
        if value then
            if not first then w(",") end
            first = false
            -- Forward is -Z of the stored rotation.
            local r = value.r
            w(('%q:{"pos":%s,"forward":[%s,%s,%s]}'):format(
                name, vec(value.p), num(-r[3]), num(-r[6]), num(-r[9])))
        end
    end
end
w('},"lights":[')

first = true
for _, inst in ipairs(stub.ALL) do
    local class = rawget(inst, "ClassName")
    if class == "PointLight" or class == "SpotLight" then
        local parent = rawget(inst, "Parent")
        local ppos, prot
        if parent then
            local pcf = rawget(parent, "CFrame")
            ppos = pcf and pcf.p or rawget(parent, "Position")
            prot = pcf and pcf.r or { 1,0,0, 0,1,0, 0,0,1 }
        end

        -- World-space aim = parent rotation x the Face normal.
        local FACE = {
            Top = {0,1,0}, Bottom = {0,-1,0}, Front = {0,0,1}, Back = {0,0,-1},
            Left = {-1,0,0}, Right = {1,0,0},
        }
        local faceName = rawget(inst, "Face") and rawget(inst, "Face").Name or "Bottom"
        local fn = FACE[faceName] or FACE.Bottom
        local axis = { 0, -1, 0 }
        if prot then
            axis = {
                prot[1]*fn[1] + prot[2]*fn[2] + prot[3]*fn[3],
                prot[4]*fn[1] + prot[5]*fn[2] + prot[6]*fn[3],
                prot[7]*fn[1] + prot[8]*fn[2] + prot[9]*fn[3],
            }
        end
        if ppos then
            local colour = rawget(inst, "Color")
            if not first then w(",") end
            first = false
            w(('{"kind":%q,"pos":%s,"brightness":%s,"range":%s,"color":%s,"angle":%s,"face":%q,"axis":[%s,%s,%s],"shadows":%s}')
                :format(class, vec(ppos),
                    num(rawget(inst, "Brightness") or 1),
                    num(rawget(inst, "Range") or 16),
                    col(colour or { R = 1, G = 1, B = 1 }),
                    num(rawget(inst, "Angle") or 90),
                    faceName,
                    num(axis[1]), num(axis[2]), num(axis[3]),
                    tostring(rawget(inst, "Shadows") == true)))
        end
    end
end
w('],"fov":{')
first = true
for _, inst in ipairs(stub.ALL) do
    local class = rawget(inst, "ClassName")
    local name = rawget(inst, "Name")
    if class == "NumberValue" and name:match("^Cam") then
        if not first then w(",") end
        first = false
        w(('%q:%s'):format(name, num(rawget(inst, "Value") or 50)))
    end
end
w("}}")

print(table.concat(out))

local summary = {}
for shape, n in pairs(counts) do table.insert(summary, shape .. "=" .. n) end
table.sort(summary)
io.stderr:write("geometria: " .. table.concat(summary, "  ") .. "\n")
