-- roblox_stub.luau — just enough Roblox to run StageBuilder.luau unmodified
-- and record every piece it builds. No rendering decisions live here: this only
-- reports what the game would actually create.

local M = {}
local ALL = {}
M.ALL = ALL

-- ── Vector3 ──────────────────────────────────────────────────────────────────
local Vector3 = {}
Vector3.__index = function(t, k)
    if k == "Magnitude" then
        return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
    end
    if k == "Unit" then
        local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
        if m < 1e-9 then m = 1 end
        return setmetatable({ X = t.X / m, Y = t.Y / m, Z = t.Z / m }, getmetatable(t))
    end
    return rawget(Vector3, k)
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3) end
Vector3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
    if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
    if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
    return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
Vector3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
function Vector3:Lerp(o, t) return v3(self.X+(o.X-self.X)*t, self.Y+(o.Y-self.Y)*t, self.Z+(o.Z-self.Z)*t) end
M.Vector3 = setmetatable({ new = v3, zero = v3(0,0,0), one = v3(1,1,1) }, {})

-- ── Color3 ───────────────────────────────────────────────────────────────────
local Color3 = {}
Color3.__index = Color3
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
function Color3:Lerp(o, t) return c3(self.R+(o.R-self.R)*t, self.G+(o.G-self.G)*t, self.B+(o.B-self.B)*t) end
M.Color3 = { new = c3, fromRGB = function(r,g,b) return c3(r/255, g/255, b/255) end }

-- ── CFrame: position + 3x3 rotation, enough for what StageBuilder composes ──
local CFrame = {}
CFrame.__index = CFrame
local function identity() return { 1,0,0, 0,1,0, 0,0,1 } end
local function cf(pos, rot) return setmetatable({ p = pos, r = rot or identity() }, CFrame) end

local function matmul(a, b)
    local o = {}
    for i = 0, 2 do
        for j = 0, 2 do
            local s = 0
            for k = 0, 2 do s = s + a[i*3+k+1] * b[k*3+j+1] end
            o[i*3+j+1] = s
        end
    end
    return o
end
local function apply(r, v)
    return v3(
        r[1]*v.X + r[2]*v.Y + r[3]*v.Z,
        r[4]*v.X + r[5]*v.Y + r[6]*v.Z,
        r[7]*v.X + r[8]*v.Y + r[9]*v.Z)
end

CFrame.__mul = function(a, b)
    if getmetatable(b) == Vector3 then
        local rotated = apply(a.r, b)
        return v3(a.p.X + rotated.X, a.p.Y + rotated.Y, a.p.Z + rotated.Z)
    end
    local offset = apply(a.r, b.p)
    return cf(v3(a.p.X + offset.X, a.p.Y + offset.Y, a.p.Z + offset.Z), matmul(a.r, b.r))
end
CFrame.__index = function(t, k)
    if k == "Position" or k == "p" then return rawget(t, "p") end
    return CFrame[k]
end

local function anglesXYZ(rx, ry, rz)
    local cx, sx = math.cos(rx), math.sin(rx)
    local cy, sy = math.cos(ry), math.sin(ry)
    local cz, sz = math.cos(rz), math.sin(rz)
    local Rx = { 1,0,0, 0,cx,-sx, 0,sx,cx }
    local Ry = { cy,0,sy, 0,1,0, -sy,0,cy }
    local Rz = { cz,-sz,0, sz,cz,0, 0,0,1 }
    return matmul(matmul(Rx, Ry), Rz)
end

local function normalise(v)
    local m = math.sqrt(v.X^2 + v.Y^2 + v.Z^2)
    if m < 1e-9 then return v3(0,0,1) end
    return v3(v.X/m, v.Y/m, v.Z/m)
end
local function cross(a, b)
    return v3(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X)
end

M.CFrame = {
    new = function(a, b, c)
        if type(a) == "table" then return cf(v3(a.X, a.Y, a.Z)) end
        return cf(v3(a or 0, b or 0, c or 0))
    end,
    Angles = function(rx, ry, rz) return cf(v3(0,0,0), anglesXYZ(rx, ry, rz)) end,
    fromEulerAnglesXYZ = function(rx, ry, rz) return cf(v3(0,0,0), anglesXYZ(rx, ry, rz)) end,
    lookAt = function(from, to)
        -- Roblox convention: the part's -Z faces the target.
        local forward = normalise(v3(to.X - from.X, to.Y - from.Y, to.Z - from.Z))
        local up = v3(0, 1, 0)
        local right = normalise(cross(up, v3(-forward.X, -forward.Y, -forward.Z)))
        local trueUp = cross(v3(-forward.X, -forward.Y, -forward.Z), right)
        return cf(v3(from.X, from.Y, from.Z), {
            right.X, trueUp.X, -forward.X,
            right.Y, trueUp.Y, -forward.Y,
            right.Z, trueUp.Z, -forward.Z,
        })
    end,
}

-- ── Enum: every member resolves to its own name ───────────────────────────────
local function enumTable(name)
    return setmetatable({}, { __index = function(_, k) return { EnumType = name, Name = k } end })
end
M.Enum = setmetatable({}, { __index = function(_, k) return enumTable(k) end })

-- ── Random ───────────────────────────────────────────────────────────────────
local Random = {}
Random.__index = Random
M.Random = { new = function(seed)
    -- A tiny LCG, so the dump is reproducible run to run.
    return setmetatable({ s = (seed or 0) % 2147483647 }, Random)
end }
function Random:_next()
    self.s = (self.s * 48271) % 2147483647
    return self.s / 2147483647
end
function Random:NextNumber(a, b)
    local r = self:_next()
    if a == nil then return r end
    return a + r * (b - a)
end
function Random:NextInteger(a, b) return math.floor(a + self:_next() * (b - a + 1) - 1e-9) end

-- ── UDim2 / Vector2 / Font (only needed so SurfaceGui signs construct) ──
M.UDim2 = { fromScale = function(x, y) return { X = x, Y = y } end,
            fromOffset = function(x, y) return { X = x, Y = y } end,
            new = function(...) return {} end }
M.Vector2 = { new = function(x, y) return { X = x, Y = y } end }
M.Font = { fromEnum = function(e) return { Name = e and e.Name or "Font" } end }

-- ── Instance ─────────────────────────────────────────────────────────────────
local Instance = {}
M.Instance = Instance

local Inst = {}
function Inst.__index(t, k)
    if k == "Destroy" then return function() end end
    if k == "FindFirstChild" then return function() return nil end end
    if k == "GetDescendants" then return function() return ALL end end
    if k == "IsA" then return function(_, c) return rawget(t, "ClassName") == c end end
    if k == "PivotTo" then return function() end end
    return rawget(t, k)
end

function Instance.new(className)
    local inst = setmetatable({
        ClassName = className,
        Name = className,
        Size = v3(1, 1, 1),
        Position = v3(0, 0, 0),
        CFrame = nil,
        Transparency = 0,
        Reflectance = 0,
        Color = c3(0.6, 0.6, 0.6),
        CanCollide = true,
    }, Inst)
    table.insert(ALL, inst)
    return inst
end

-- ── game / Workspace ─────────────────────────────────────────────────────────
local Workspace = setmetatable({ Name = "Workspace" }, Inst)
M.Workspace = Workspace
M.game = setmetatable({}, { __index = function(_, k)
    if k == "GetService" then return function(_, name)
        if name == "Workspace" then return Workspace end
        return setmetatable({ Name = name }, Inst)
    end end
    if k == "Workspace" then return Workspace end
    return setmetatable({ Name = k }, Inst)
end })

return M
