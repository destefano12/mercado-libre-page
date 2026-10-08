"""hud.py — draws the real HUD over the rendered venue.

Every size, offset and colour is taken from src/Client/UI/{Theme,StagePanel,
Scoreboard,RoomPanel}.luau. The waveform bars are computed with the same
envelope function as SoundLibrary.envelope, from a real sound's notes, so the
shapes on screen are the shapes the game would draw.
"""
import json, math, re, pathlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

R = Path(__file__).parent
SHOTS = R / "shots"
OUT = R / "screens"; OUT.mkdir(exist_ok=True)

# ── palette ──
# Parsed straight out of src/Shared/Palette.luau, so the mockup can never drift
# from the game's actual colours.
def load_palette(path="Palette.luau"):
    src = pathlib.Path(path).read_text()
    out = {}
    for name, r, g, b in re.findall(r"(\w+)\s*=\s*rgb\((\d+),\s*(\d+),\s*(\d+)\)", src):
        out[name] = (int(r), int(g), int(b))
    return out

P = load_palette()

F = "/usr/share/fonts/truetype/dejavu/"
def font(name, size):
    return ImageFont.truetype(F + name, size)
BOLD   = lambda s: font("DejaVuSans-Bold.ttf", s)
BODY   = lambda s: font("DejaVuSans.ttf", s)
MONO   = lambda s: font("DejaVuSansMono.ttf", s)

SCALE = 1600 / 1280.0   # the Luau layout is authored against a 1280-wide window

def S(v): return int(round(v * SCALE))

def panel(d, x, y, w, h, alpha=242, radius=10, stroke=True):
    d.rounded_rectangle([x, y, x+w, y+h], radius=radius,
                        fill=P["Panel"] + (alpha,),
                        outline=P["Hairline"] + (200,) if stroke else None, width=1)

def text(d, xy, s, f, colour, anchor="la"):
    d.text(xy, s, font=f, fill=colour, anchor=anchor)

# ── the envelope function, mirrored from SoundLibrary.envelope ───────────────
def envelope(notes, duration, samples=96):
    out = [0.0] * samples
    for i in range(samples):
        t = (i + 0.5) / samples * duration
        for (nt, nd, _p) in notes:
            if nt <= t <= nt + nd:
                lt = (t - nt) / max(nd, 1e-3)
                shape = min(1, lt/0.18) * min(1, (1-lt)/0.22 + 0.35)
                out[i] = max(0.0, min(1.0, 0.35 + 0.65*shape))
                break
    return out

def contour(notes, duration, samples=96):
    out = []
    for i in range(samples):
        t = (i + 0.5) / samples * duration
        hit = None
        for (nt, nd, p) in notes:
            if nt <= t <= nt + nd:
                hit = p; break
        out.append(hit)
    return out

def _mix(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def waveform(d, x, y, w, h, env, colour, flipped, played=None, core=None):
    """A framed well with the signal mirrored about the centre line, each bar
    burning from the track colour at its edges to an almost-white core."""
    core = core or P["CoreWarm"]
    d.rounded_rectangle([x, y, x+w, y+h], radius=S(12), fill=P["Well"] + (245,),
                        outline=colour + (170,), width=max(1, S(1.6)))
    inset = S(7)
    px, py = x + inset, y + inset
    pw, ph = w - inset*2, h - inset*2
    mid = py + ph/2

    # Centre line.
    d.line([(px, mid), (px+pw, mid)], fill=colour + (46,), width=1)

    n = len(env)
    bw = pw / n
    for i, v in enumerate(env):
        level = max(0.035, min(1.0, v))
        half = level * ph * 0.48
        bx = px + i*bw + bw*0.16
        bx2 = bx + bw*0.68
        faded = (played is not None and i/n > played)
        # Outer body, then a brighter mid, then the white-hot core: three
        # passes is how you get the gradient without a real shader.
        for frac, mixt, alpha in ((1.0, 0.0, 150), (0.62, 0.55, 205), (0.26, 1.0, 245)):
            hh = half * frac
            if hh < 0.6: continue
            col = _mix(colour, core, mixt)
            if faded:
                col = _mix(col, P["Well"], 0.72)
            d.rounded_rectangle([bx, mid-hh, bx2, mid+hh],
                                radius=max(1, int(bw*0.3)), fill=col + (alpha,))

def playhead(d, x, y, w, h, alpha):
    cx = x + S(7) + (w - S(14)) * alpha
    d.rounded_rectangle([cx-S(5), y+S(4), cx+S(5), y+h-S(4)], radius=S(5),
                        fill=P["Playhead"] + (56,))
    d.rectangle([cx-1, y+S(4), cx+1, y+h-S(4)], fill=P["Playhead"] + (255,))

def ribbon(d, x, y, w, h, cont, cursor_i=None):
    n = len(cont)
    for i, p in enumerate(cont):
        if p is None: continue
        cx = x + (i + 0.5) / n * w
        cy = y + (0.5 - p / 18.0) * h
        d.ellipse([cx-1.5, cy-1.5, cx+1.5, cy+1.5], fill=P["Reference"] + (235,))
    if cursor_i is not None:
        p = cont[cursor_i] if cont[cursor_i] is not None else 0
        cx = x + (cursor_i + 0.5) / n * w
        cy = y + (0.5 - (p + 1.6) / 18.0) * h
        d.ellipse([cx-6, cy-6, cx+6, cy+6], fill=P["Yours"] + (255,), outline=P["Ink"], width=2)

def meter(d, x, y, w, label, score, colour, muted=False):
    text(d, (x, y+S(8)), label, BODY(S(12)), P["Muted"])
    tx = x + S(102); tw = w - S(160)
    d.rounded_rectangle([tx, y+S(11), tx+tw, y+S(19)], radius=S(4), fill=P["Ink"]+(255,))
    if not muted:
        d.rounded_rectangle([tx, y+S(11), tx + tw*score/100, y+S(19)], radius=S(4), fill=colour+(255,))
    text(d, (x+w, y+S(8)), "—" if muted else str(score), MONO(S(14)),
         P["Muted"] if muted else P["Cream"], anchor="ra")

# ── the sound on screen: Coro de Ranas, the library's hardest rhythm ─────────
NOTES = [(0.00,0.14,-4),(0.23,0.14,-4),(0.46,0.14,-2),(0.69,0.14,-4),(0.92,0.14,-6),(1.15,0.22,-4)]
DURATION = 1.49
# A believable take: close, but one attack late and the last one short.
TAKE  = [(0.01,0.15,-3),(0.24,0.13,-3),(0.49,0.16,-1),(0.70,0.12,-3),(0.95,0.13,-5),(1.17,0.18,-4)]

def stage_panel(d, W, H, *, playhead=None, countdown=None, mic=0.0, mode="MICRÓFONO + TONO",
                take=None, hint="HABLÁ AL MICRÓFONO · MOVÉ EL MOUSE PARA EL TONO"):
    pw, ph = S(900), S(300)
    px, py = (W - pw)//2, H - ph - S(24)
    panel(d, px, py, pw, ph)
    ix, iy, iw = px + S(18), py + S(18), pw - S(36)

    text(d, (ix, iy), "CORO DE RANAS", BOLD(S(21)), P["Cream"])
    text(d, (ix, iy+S(26)), "Animales   ●●●   1.5s", BODY(S(11)), P["Muted"])
    text(d, (ix+iw, iy), "RONDA 2 / 4", MONO(S(14)), P["Muted"], anchor="ra")

    text(d, (ix, iy+S(50)), "REFERENCIA", BODY(S(10)), P["Reference"])
    waveform(d, ix, iy+S(66), iw, S(58), envelope(NOTES, DURATION), P["Reference"],
             False, playhead, core=P["CoreWarm"])
    ribbon(d, ix, iy+S(126), iw, S(42), contour(NOTES, DURATION),
           int(playhead*95) if playhead else None)
    waveform(d, ix, iy+S(170), iw, S(58),
             envelope(take or [], DURATION) if take else [0.0]*96, P["Yours"], True,
             playhead, core=P["CoreCool"])
    if playhead is not None:
        playhead_x = playhead
        globals()["_ph"] = playhead_x
        from_y = iy+S(66)
        # The red head rides over both tracks.
        for ty in (iy+S(66), iy+S(170)):
            cx = ix + S(7) + (iw - S(14)) * playhead_x
            d.rounded_rectangle([cx-S(5), ty+S(4), cx+S(5), ty+S(54)], radius=S(5),
                                fill=P["Playhead"] + (56,))
            d.rectangle([cx-1, ty+S(4), cx+1, ty+S(54)], fill=P["Playhead"] + (255,))
    text(d, (ix, iy+S(228)), "TU VOZ", BODY(S(10)), P["Yours"])
    text(d, (ix+iw, iy+S(228)), hint, BODY(S(11)), P["Muted"], anchor="ra")

    # mic meter
    my = iy + S(252)
    text(d, (ix, my), mode, BODY(S(11)), P["Yours"])
    mtx = ix + S(156)
    d.rounded_rectangle([mtx, my+S(6), mtx+S(150), my+S(12)], radius=S(3), fill=P["Ink"]+(200,))
    d.rounded_rectangle([mtx, my+S(6), mtx+S(150)*mic, my+S(12)], radius=S(3), fill=P["Yours"]+(255,))
    gx = mtx + S(150)*0.31
    d.rectangle([gx, my+S(3), gx+1, my+S(15)], fill=P["Reference"])

    if countdown is not None:
        text(d, (px+pw/2, py+ph*0.52), countdown, BOLD(S(86)),
             P["Yours"] if countdown == "¡YA!" else P["Cream"], anchor="mm")

CARD_W, CARD_H, GAP, PORTRAIT = S(128), S(158), S(10), S(104)

def bust(d, cx, cy, size, body, shirt, accent):
    """The avatar bust a ViewportFrame would show: head, torso, shoulders."""
    u = size / 100.0
    def box(x0, y0, x1, y1, col, shade=1.0):
        c = tuple(min(255, int(v*shade)) for v in col)
        d.rectangle([cx + x0*u, cy + y0*u, cx + x1*u, cy + y1*u], fill=c + (255,))
    box(-30, 18, 30, 60, shirt, 0.82)            # torso
    box(-44, 20, -30, 54, body, 0.70)            # shoulders / arms
    box( 30, 20,  44, 54, body, 0.70)
    box(-22, -34, 22, 16, body, 1.0)             # head
    box(-22, -34, 22, -22, body, 0.78)           # hair line
    # eyes
    for ex in (-11, 5):
        d.rectangle([cx + ex*u, cy - 10*u, cx + (ex+6)*u, cy - 4*u], fill=(26,22,24,255))
    d.rectangle([cx - 7*u, cy + 2*u, cx + 7*u, cy + 5*u], fill=(26,22,24,180))

def cards(d, W, rows, highlight=None):
    n = len(rows)
    total = n*CARD_W + (n-1)*GAP
    x0 = (W - total)//2
    y0 = S(14)
    best = max(r[1] for r in rows)
    for i, (name, score, accent, mult, body, shirt, delta) in enumerate(rows):
        x = x0 + i*(CARD_W + GAP)
        leader = score == best
        d.rounded_rectangle([x, y0, x+CARD_W, y0+CARD_H], radius=S(12),
                            fill=P["CardBack"] + (242,),
                            outline=(P["CardLeader"] if leader else P["Hairline"]) + (230,),
                            width=max(1, S(1.4)))
        d.rounded_rectangle([x, y0, x+CARD_W, y0+S(3)], radius=S(3), fill=accent + (255,))

        wx, wy = x + (CARD_W-PORTRAIT)//2, y0 + S(10)
        d.rounded_rectangle([wx, wy, wx+PORTRAIT, wy+PORTRAIT], radius=S(9),
                            fill=P["Well"] + (235,))
        bust(d, wx + PORTRAIT/2, wy + PORTRAIT*0.56, PORTRAIT*0.82, body, shirt, accent)

        text(d, (x+CARD_W/2, y0+S(127)), name, BODY(S(13)), P["Cream"], anchor="mm")
        text(d, (x+CARD_W/2, y0+S(145)), str(score), MONO(S(19)),
             P["CardLeader"] if leader else P["Cream"], anchor="mm")
        if mult:
            text(d, (x+CARD_W-S(8), y0+S(19)), "x"+mult, BOLD(S(13)), P["Warn"], anchor="ra")
        if delta:
            text(d, (x+CARD_W/2, y0+S(108)), delta, BOLD(S(19)), P["Good"], anchor="mm")

def banner(d, phase, clock):
    x, y, w, h = S(22), S(22), S(250), S(60)
    panel(d, x, y, w, h)
    text(d, (x+S(12), y+S(12)), phase, BOLD(S(13)), P["Reference"])
    text(d, (x+S(12), y+S(30)), clock, MONO(S(19)), P["Cream"])

def scoreboard(d, W, rows):
    w = S(268); h = S(34) + len(rows)*S(38) + S(12)
    x, y = W - w - S(22), S(22)
    panel(d, x, y, w, h)
    text(d, (x+S(12), y+S(12)), "EN ESCENA", BODY(S(11)), P["Muted"])
    for i, (name, score, accent, mult) in enumerate(rows):
        ry = y + S(34) + i*S(38)
        d.rounded_rectangle([x+S(12), ry, x+w-S(12), ry+S(32)], radius=S(7),
                            fill=P["PanelRaised"]+(150,))
        d.rounded_rectangle([x+S(20), ry+S(7), x+S(24), ry+S(25)], radius=S(2), fill=accent+(255,))
        text(d, (x+S(32), ry+S(16)), name + (f"  ×{mult}" if mult else ""),
             BODY(S(14)), P["Cream"], anchor="lm")
        text(d, (x+w-S(20), ry+S(16)), str(score), MONO(S(15)), P["Cream"], anchor="rm")

def voice_tag(d, W):
    w, h = S(250), S(34)
    x, y = S(22), S(92)
    panel(d, x, y, w, h, alpha=250)
    text(d, (x+w/2, y+h/2), "MESA SILENCIADA", BOLD(S(12)), P["Warn"], anchor="mm")

def playback_card(d, W, who, verdict, mel, rit, atk, total, sab=None, muted_mel=False):
    w, h = S(452), S(224)
    x, y = (W-w)//2, S(172)
    panel(d, x, y, w, h, alpha=250)
    ix, iy, iw = x+S(16), y+S(16), w-S(32)
    text(d, (ix, iy), who, BOLD(S(20)), P["Cream"])
    text(d, (ix+iw, iy), verdict, BOLD(S(15)),
         P["Good"] if total>=620 else (P["Warn"] if total>=380 else P["Bad"]), anchor="ra")
    if sab:
        text(d, (ix, iy+S(28)), sab, BODY(S(12)), P["Bad"])
    meter(d, ix, iy+S(48), iw, "Melodía", mel, P["Reference"], muted_mel)
    meter(d, ix, iy+S(78), iw, "Ritmo", rit, P["Yours"])
    meter(d, ix, iy+S(108), iw, "Ataques", atk, P["Warn"])
    d.rectangle([ix, iy+S(144), ix+iw, iy+S(145)], fill=P["Hairline"])
    text(d, (ix, iy+S(162)), "TOTAL", BODY(S(11)), P["Muted"])
    text(d, (ix+iw, iy+S(150)), str(total), BOLD(S(32)), P["Cream"], anchor="ra")
    text(d, (ix+iw, iy+S(186)), "+%d al marcador" % total, BODY(S(11)), P["Muted"], anchor="ra")

def top_shade(img):
    W, H = img.size
    sh = Image.new("RGBA", (W, S(150)), (0,0,0,0))
    sd = ImageDraw.Draw(sh)
    for i in range(S(150)):
        sd.line([(0,i),(W,i)], fill=P["Ink"] + (int(140 * (1 - i/S(150))),))
    img.alpha_composite(sh, (0,0))

def compose(shot, builder, out_name):
    img = Image.open(SHOTS / shot).convert("RGBA")
    W, H = img.size
    top_shade(img)
    layer = Image.new("RGBA", (W, H), (0,0,0,0))
    d = ImageDraw.Draw(layer)
    builder(d, W, H)
    img.alpha_composite(layer)
    img.convert("RGB").save(OUT / out_name, quality=95)
    print(f"  {out_name}")

#        name      score accent          mult body             shirt            delta
ROWS = [("Duna",    118, (244,86,150),  "2", (206,170,126), (92,64,82),   None),
        ("Tito",    109, (86,212,226),  None, (176,132,98),  (66,86,92),   None),
        ("Mora",    142, (246,86,86),   None, (228,196,164), (104,58,58),  None),
        ("Rulo",     86, (164,222,92),  None, (150,112,82),  (74,88,58),   None),
        ("Sol",      70, (252,202,88),  None, (238,212,184), (112,96,56),  None)]

def rows_with(name, delta):
    out = []
    for r in ROWS:
        out.append(r[:6] + (delta if r[0] == name else None,))
    return out

print("componiendo pantallas:")

compose("04-cabina.png", lambda d,W,H: (
    banner(d, "GRABANDO", "1.4 s"),
    cards(d, W, ROWS),
    stage_panel(d, W, H, playhead=0.62, mic=0.74, take=TAKE[:4]),
), "01-grabando.png")

compose("04-cabina.png", lambda d,W,H: (
    banner(d, "GRABANDO", "2.9 s"),
    cards(d, W, ROWS),
    stage_panel(d, W, H, countdown="¡YA!", mic=0.08,
                hint="HABLÁ AL MICRÓFONO · MOVÉ EL MOUSE PARA EL TONO"),
), "02-cuenta-atras.png")

compose("02-escenario-cinco.png", lambda d,W,H: (
    banner(d, "ESCUCHANDO LAS TOMAS", "—"),
    voice_tag(d, W),
    cards(d, W, rows_with("Mora", "+86")),
    playback_card(d, W, "MORA", "CLAVADO", 84, 77, 100, 86),
    stage_panel(d, W, H, playhead=0.45, mic=0.0, take=TAKE, hint=""),
), "03-escuchando.png")

compose("02-escenario-cinco.png", lambda d,W,H: (
    banner(d, "ESCUCHANDO LAS TOMAS", "—"),
    voice_tag(d, W),
    cards(d, W, rows_with("Rulo", "+29")),
    playback_card(d, W, "RULO", "LEJOS", 0, 24, 0, 29,
                  sab="SABOTEADO · SUSTITUCIÓN por Chino  −12", muted_mel=True),
    stage_panel(d, W, H, playhead=0.7, mic=0.0, take=TAKE[:3], hint=""),
), "04-saboteado.png")
