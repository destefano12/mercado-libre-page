"""hud.py — draws the real HUD over the rendered venue.

Every size, offset and colour is taken from src/Client/UI/{Theme,StagePanel,
Scoreboard,RoomPanel}.luau. The waveform bars are computed with the same
envelope function as SoundLibrary.envelope, from a real sound's notes, so the
shapes on screen are the shapes the game would draw.
"""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

R = Path(__file__).parent
SHOTS = R / "shots"
OUT = R / "screens"; OUT.mkdir(exist_ok=True)

# ── palette, from src/Shared/Palette.luau ────────────────────────────────────
P = dict(
    Ink=(18,17,20), Panel=(29,28,33), PanelRaised=(38,37,43), Hairline=(58,56,64),
    Cream=(238,233,224), Muted=(150,145,156),
    Reference=(226,188,74), Yours=(118,196,128),
    Good=(118,196,128), Warn=(214,160,86), Bad=(192,92,92),
    Trim=(150,116,66),
)
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

def waveform(d, x, y, w, h, env, colour, flipped, played=None):
    d.rounded_rectangle([x, y, x+w, y+h], radius=S(8), fill=P["Ink"] + (150,))
    n = len(env)
    bw = w / n
    for i, v in enumerate(env):
        if v <= 0: continue
        bh = max(1, v * h * 0.94)
        bx = x + i * bw
        alpha = 230 if (played is None or i/n <= played) else 70
        if flipped:
            d.rounded_rectangle([bx, y, bx + bw*0.76, y + bh], radius=2, fill=colour + (alpha,))
        else:
            d.rounded_rectangle([bx, y + h - bh, bx + bw*0.76, y + h], radius=2, fill=colour + (alpha,))

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
        d.rounded_rectangle([tx, y+S(11), tx + tw*score/1000, y+S(19)], radius=S(4), fill=colour+(255,))
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
    waveform(d, ix, iy+S(66), iw, S(56), envelope(NOTES, DURATION), P["Reference"], False, playhead)
    ribbon(d, ix, iy+S(124), iw, S(44), contour(NOTES, DURATION),
           int(playhead*95) if playhead else None)
    waveform(d, ix, iy+S(170), iw, S(56),
             envelope(take or [], DURATION) if take else [0]*96, P["Yours"], True, playhead)
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
    w, h = S(238), S(34)
    x, y = (W-w)//2, S(22)
    panel(d, x, y, w, h, alpha=250)
    text(d, (x+w/2, y+h/2), "MESA SILENCIADA", BOLD(S(12)), P["Warn"], anchor="mm")

def playback_card(d, W, who, verdict, mel, rit, atk, total, sab=None, muted_mel=False):
    w, h = S(452), S(232)
    x, y = (W-w)//2, S(96)
    panel(d, x, y, w, h, alpha=250)
    ix, iy, iw = x+S(16), y+S(16), w-S(32)
    text(d, (ix, iy), who, BOLD(S(20)), P["Cream"])
    text(d, (ix+iw, iy), verdict, BOLD(S(15)),
         P["Good"] if total>=620 else (P["Warn"] if total>=380 else P["Bad"]), anchor="ra")
    if sab:
        text(d, (ix, iy+S(28)), sab, BODY(S(12)), P["Bad"])
    meter(d, ix, iy+S(50), iw, "Melodía", mel, P["Reference"], muted_mel)
    meter(d, ix, iy+S(80), iw, "Ritmo", rit, P["Yours"])
    meter(d, ix, iy+S(110), iw, "Ataques", atk, P["Warn"])
    d.rectangle([ix, iy+S(152), ix+iw, iy+S(153)], fill=P["Hairline"])
    text(d, (ix, iy+S(170)), "TOTAL", BODY(S(11)), P["Muted"])
    text(d, (ix+iw, iy+S(162)), str(total), BOLD(S(34)), P["Cream"], anchor="ra")
    text(d, (ix+iw, iy+S(200)), "+%d al marcador" % total, BODY(S(11)), P["Muted"], anchor="ra")

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

ROWS = [("Mora", 1420, (192,92,92), None), ("Duna", 1180, (214,160,86), "2"),
        ("Tito", 1095, (126,174,182), None), ("Rulo", 860, (146,172,110), None),
        ("Sol", 705, (226,188,74), None)]

print("componiendo pantallas:")

compose("04-cabina.png", lambda d,W,H: (
    banner(d, "GRABANDO", "1.4 s"),
    scoreboard(d, W, ROWS),
    stage_panel(d, W, H, playhead=0.62, mic=0.74, take=TAKE[:4]),
), "01-grabando.png")

compose("04-cabina.png", lambda d,W,H: (
    banner(d, "GRABANDO", "2.9 s"),
    scoreboard(d, W, ROWS),
    stage_panel(d, W, H, countdown="¡YA!", mic=0.08,
                hint="HABLÁ AL MICRÓFONO · MOVÉ EL MOUSE PARA EL TONO"),
), "02-cuenta-atras.png")

compose("02-escenario-cinco.png", lambda d,W,H: (
    banner(d, "ESCUCHANDO LAS TOMAS", "—"),
    voice_tag(d, W),
    scoreboard(d, W, ROWS),
    playback_card(d, W, "MORA", "CLAVADO", 844, 771, 1000, 858),
    stage_panel(d, W, H, playhead=0.45, mic=0.0, take=TAKE, hint=""),
), "03-escuchando.png")

compose("02-escenario-cinco.png", lambda d,W,H: (
    banner(d, "ESCUCHANDO LAS TOMAS", "—"),
    voice_tag(d, W),
    scoreboard(d, W, ROWS),
    playback_card(d, W, "RULO", "LEJOS", 0, 238, 0, 412,
                  sab="SABOTEADO · SUSTITUCIÓN por Chino  −120", muted_mel=True),
    stage_panel(d, W, H, playhead=0.7, mic=0.0, take=TAKE[:3], hint=""),
), "04-saboteado.png")
