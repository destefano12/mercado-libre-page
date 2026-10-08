"""render.py — draws the venue from the geometry StageBuilder actually builds.

Nothing here invents the scene. It reads venue.json (the dump of the real
module), projects it from the camera anchors the game uses, and shades it to
approximate LightingRig: warm key from the truss, low ambient, exposure pulled
down, slight desaturation, warm haze with distance.

The only thing added on top is the performers: StageBuilder does not create
avatars, so blocky Roblox-style figures are placed on the marks using the real
character palettes, because a stage with nobody on it does not show the game.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

R = Path(__file__).parent
V = json.loads((R / "venue.json").read_text())

W, H = 1600, 900
BG = np.array([0.13, 0.08, 0.11])      # matches Palette.Scrim, darkened
# LightingRig: Ambient (26,22,24), Brightness 1.1 at ClockTime 21 — indoors at
# night, so almost all illumination comes from the 14 fixtures the rig places.
# Those are read from the dump rather than approximated.
AMBIENT = np.array([74, 56, 62]) / 255 * 1.75
SKY = np.array([0.12, 0.09, 0.11])     # the faint top-down term
LIGHTS = [
    dict(pos=np.array(l["pos"], dtype=float),
         brightness=l["brightness"],
         rng=l["range"],
         colour=np.array(l["color"], dtype=float),
         spot=(l["kind"] == "SpotLight"),
         # Aim comes straight from the dump: the parent's rotation applied to
         # the light's Face normal. No guessing.
         axis=np.array(l.get("axis", [0.0, -1.0, 0.0]), dtype=float),
         half=math.radians(l["angle"] / 2))
    for l in V["lights"]
]
EXPOSURE = 0.0                          # LightingRig.ExposureCompensation
SATURATION = 0.22
FOG_DISTANCE = 260.0

MATERIAL_SPEC = {   # (diffuse multiplier, emissive)
    "Neon": (1.0, 0.92),
    "Metal": (0.95, 0.0),
    "DiamondPlate": (0.88, 0.0),
    "Wood": (0.92, 0.0),
    "WoodPlanks": (0.95, 0.0),
    "Fabric": (0.80, 0.0),
    "Concrete": (0.86, 0.0),
    "SmoothPlastic": (1.0, 0.0),
}

# ── shape tessellation (local space, centred at origin) ──────────────────────

def box_faces(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    return [([v[0],v[1],v[2],v[3]], (0,0,-1)), ([v[5],v[4],v[7],v[6]], (0,0,1)),
            ([v[4],v[0],v[3],v[7]], (-1,0,0)), ([v[1],v[5],v[6],v[2]], (1,0,0)),
            ([v[3],v[2],v[6],v[7]], (0,1,0)),  ([v[4],v[5],v[1],v[0]], (0,-1,0))]

def cylinder_faces(length, diameter, segments=16):
    r, hl = diameter / 2, length / 2
    faces = []
    ring = [(math.cos(2*math.pi*i/segments)*r, math.sin(2*math.pi*i/segments)*r)
            for i in range(segments)]
    for i in range(segments):
        y0, z0 = ring[i]
        y1, z1 = ring[(i + 1) % segments]
        n = (0, (y0+y1)/2, (z0+z1)/2)
        m = math.hypot(n[1], n[2]) or 1
        faces.append(([(-hl,y0,z0),(hl,y0,z0),(hl,y1,z1),(-hl,y1,z1)], (0,n[1]/m,n[2]/m)))
    for sign, nx in ((1, 1), (-1, -1)):
        cap = [(sign*hl, y, z) for y, z in (ring if sign > 0 else ring[::-1])]
        faces.append((cap, (nx, 0, 0)))
    return faces

def ball_faces(diameter, stacks=6, slices=10):
    r = diameter / 2
    faces = []
    for i in range(stacks):
        p0, p1 = math.pi*i/stacks, math.pi*(i+1)/stacks
        for j in range(slices):
            t0, t1 = 2*math.pi*j/slices, 2*math.pi*(j+1)/slices
            def pt(p, t):
                return (r*math.sin(p)*math.cos(t), r*math.cos(p), r*math.sin(p)*math.sin(t))
            quad = [pt(p0,t0), pt(p1,t0), pt(p1,t1), pt(p0,t1)]
            c = np.mean(quad, axis=0); n = c / (np.linalg.norm(c) or 1)
            faces.append((quad, tuple(n)))
    return faces

def wedge_faces(sx, sy, sz):
    # Roblox wedge: the slope falls from the top of the -Z face to the bottom
    # of the +Z face, extruded along X.
    x, y, z = sx/2, sy/2, sz/2
    a,b,c,d = (-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z)
    e,f = (-x,-y,z),(x,-y,z)
    sl = math.hypot(sy, sz) or 1
    return [([a,b,c,d],(0,0,-1)), ([e,f,b,a],(0,-1,0)),
            ([d,c,f,e],(0, sz/sl, sy/sl)),
            ([a,d,e],(-1,0,0)), ([b,f,c],(1,0,0))]

# ── performers ───────────────────────────────────────────────────────────────

CHARACTERS = [  # from src/Shared/Characters.luau
    ((206,170,126),(92,64,82),(48,42,52)),     # Duna
    ((176,132,98),(66,86,92),(42,48,52)),      # Tito
    ((228,196,164),(104,58,58),(52,38,38)),    # Mora
    ((150,112,82),(74,88,58),(44,50,38)),      # Rulo
    ((238,212,184),(112,96,56),(56,50,36)),    # Sol
]

def avatar(x, y, z, idx, yaw=0.0):
    """A blocky R6-style figure, which is what a default Roblox avatar is."""
    body, shirt, pants = [np.array(c)/255 for c in CHARACTERS[idx % len(CHARACTERS)]]
    cy, sy_ = math.cos(yaw), math.sin(yaw)
    rot = [cy,0,sy_, 0,1,0, -sy_,0,cy]
    out = []
    def piece(dx, dy, dz, w_, h_, d_, colour):
        lx = dx*cy + dz*sy_
        lz = -dx*sy_ + dz*cy
        out.append({"shape":"box","size":[w_,h_,d_],"pos":[x+lx, y+dy, z+lz],
                    "rot":rot,"color":list(colour),"material":"SmoothPlastic",
                    "transparency":0,"reflectance":0,"name":"avatar"})
    piece(0, 3.0, 0, 2.0, 2.0, 1.0, shirt)     # torso
    piece(0, 4.6, 0, 1.3, 1.3, 1.3, body)      # head
    piece(-1.5, 3.0, 0, 1.0, 2.0, 1.0, body)   # arms
    piece( 1.5, 3.0, 0, 1.0, 2.0, 1.0, body)
    piece(-0.5, 1.0, 0, 0.9, 2.0, 1.0, pants)  # legs
    piece( 0.5, 1.0, 0, 0.9, 2.0, 1.0, pants)
    return out

# ── projection and shading ───────────────────────────────────────────────────

def build_polys(parts):
    polys = []
    for p in parts:
        if p["transparency"] >= 0.9:
            continue
        sx, sy, sz = p["size"]
        shape = p["shape"]
        if shape == "box":        local = box_faces(sx, sy, sz)
        elif shape == "cylinder": local = cylinder_faces(sx, sy)
        elif shape == "ball":     local = ball_faces(sx)
        elif shape == "wedge":    local = wedge_faces(sx, sy, sz)
        else:                     continue

        r = np.array(p["rot"], dtype=float).reshape(3, 3)
        pos = np.array(p["pos"], dtype=float)
        colour = np.array(p["color"], dtype=float)
        diff, emis = MATERIAL_SPEC.get(p["material"], (1.0, 0.0))
        alpha = 1.0 - p["transparency"]

        for verts, normal in local:
            wv = (r @ np.array(verts, dtype=float).T).T + pos
            wn = r @ np.array(normal, dtype=float)
            polys.append((wv, wn, colour, diff, emis, alpha))
    return polys

DOWN = np.array([0.0, -1.0, 0.0])

def shade(colour, normal, diff, emis, depth, centre):
    """Accumulates every fixture the rig actually places, with real falloff."""
    light = AMBIENT.copy()
    # A touch of top-down sky so upward faces are not pitch black.
    light = light + SKY * max(0.0, float(normal[1])) * 0.6

    for L in LIGHTS:
        to_light = L["pos"] - centre
        dist = float(np.linalg.norm(to_light))
        if dist > L["rng"] or dist < 1e-6:
            continue
        direction = to_light / dist
        lambert = float(np.dot(normal, direction))
        if lambert <= 0:
            continue
        # Roblox falls off to nothing at Range; the exponent shapes the pool.
        atten = (1.0 - dist / L["rng"]) ** 1.45
        cone = 1.0
        if L["spot"]:
            # Face = Bottom, so the cone points straight down.
            cos_a = float(np.dot(-direction, L["axis"]))
            cos_a = max(-1.0, min(1.0, cos_a))
            angle = math.acos(cos_a)
            if angle > L["half"]:
                continue
            # Soft edge over the outer fifth of the cone.
            cone = min(1.0, (L["half"] - angle) / (L["half"] * 0.2 + 1e-6))
        light = light + L["colour"] * (L["brightness"] * atten * cone * lambert * 0.5)

    lit = colour * diff * light
    if emis > 0:
        lit = lit * (1 - emis) + colour * emis * 1.9
    lit = lit * (2 ** EXPOSURE)
    grey = float(np.dot(lit, [0.299, 0.587, 0.114]))
    lit = lit + (grey - lit) * (-SATURATION)
    fog = 1.0 - math.exp(-max(depth, 0.0) / FOG_DISTANCE)
    haze = np.array([0.30, 0.19, 0.19])
    lit = lit * (1 - fog) + haze * fog
    return tuple(int(max(0.0, min(1.0, c)) ** (1 / 1.05) * 255) for c in lit)

def render(cam_name, parts, out_path, fov_override=None, title=None):
    cam = V["cameras"][cam_name]
    fov = fov_override or V["fov"].get(cam_name + "FOV", 55)
    eye = np.array(cam["pos"], dtype=float)
    fwd = np.array(cam["forward"], dtype=float)
    fwd = fwd / np.linalg.norm(fwd)
    right = np.cross(np.array([0.0, 1.0, 0.0]), fwd)
    right = right / (np.linalg.norm(right) or 1)
    up = np.cross(fwd, right)

    f = 1.0 / math.tan(math.radians(fov) / 2)
    scale = H / 2

    polys = build_polys(parts)
    drawable = []
    for wv, wn, colour, diff, emis, alpha in polys:
        rel = wv - eye
        depth = rel @ fwd
        if np.any(depth < 0.45):
            continue
        sxs = (rel @ right) / depth * f * scale + W / 2
        sys_ = -(rel @ up) / depth * f * scale + H / 2
        pts = list(zip(sxs, sys_))
        if max(sxs) < -60 or min(sxs) > W + 60 or max(sys_) < -60 or min(sys_) > H + 60:
            continue
        mean_depth = float(np.mean(depth))
        centre = wv.mean(axis=0)
        ground = 1 if (abs(float(wn[1])) > 0.9 and float(centre[1]) < 1.6) else 0
        drawable.append((mean_depth, pts, shade(colour, wn, diff, emis, mean_depth, centre),
                         alpha, ground, float(centre[1])))

    # Ground first, lowest surface up (floor, then the rug lying on it), each
    # band far to near; then everything standing on top of it all.
    drawable.sort(key=lambda t: (-t[4], t[5] if t[4] else 0, -t[0]))

    img = Image.new("RGB", (W, H), tuple(int(c * 255) for c in BG))
    draw = ImageDraw.Draw(img, "RGBA")
    for _, pts, colour, alpha, _ground, _y in drawable:
        draw.polygon(pts, fill=colour + (int(alpha * 255),))

    # A touch of bloom on the bright practicals, as the rig's BloomEffect does.
    bright = img.point(lambda v: 255 if v > 205 else 0).filter(ImageFilter.GaussianBlur(9))
    img = Image.blend(img, Image.blend(img, bright, 0.5), 0.26)

    # Vignette, matching the UI's top shade.
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-W * 0.3, -H * 0.42, W * 1.3, H * 1.42], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(170))
    img = Image.composite(img, Image.new("RGB", (W, H), (6, 5, 7)), vig)

    img.save(out_path, quality=94)
    print(f"  {out_path.name:34s} {cam_name:14s} fov {fov:.0f}  {len(drawable)} polígonos")
    return img

# ── scenes ───────────────────────────────────────────────────────────────────

base = V["parts"]
MARK_X = [-16, -8, 0, 8, 16]

on_marks = []
for i, x in enumerate(MARK_X):
    on_marks += avatar(x, 0.35, -2.0, i, yaw=math.pi)   # on their pad, facing the room

walking = []
for i, x in enumerate(MARK_X):
    # Mid-procession: staggered down the aisle, as the 0.45 s offsets produce.
    z = 6.0 + i * 3.2
    walking += avatar(-8 + i * 4.0, 0.35, z, i, yaw=math.pi)

print("renderizando:")
out = R / "shots"
out.mkdir(exist_ok=True)
render("CamHouse", base, out / "01-sala-vacia.png")
render("CamWide", base + on_marks, out / "02-escenario-cinco.png")
render("CamProcession", base + walking, out / "03-procesion.png")
render("CamBooth", base + on_marks, out / "04-cabina.png")
render("CamRoulette", base + on_marks, out / "05-ruleta.png")
render("CamHouse", base + on_marks, out / "06-sala-con-publico.png", fov_override=70)
