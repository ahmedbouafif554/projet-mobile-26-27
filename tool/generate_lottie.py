"""Génère les animations Lottie de SuperFaster (welcome, success, empty_cart).

Usage (depuis la racine du projet) :
    python tool/generate_lottie.py assets/lottie

Les fichiers produits sont de simples formes vectorielles aux couleurs de la
marque. Vous pouvez aussi les remplacer par des animations LottieFiles
en gardant les mêmes noms de fichiers.
"""
import json
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join('assets', 'lottie')
FR = 60

EASE_OUT = {"i": {"x": [0.2], "y": [1]}, "o": {"x": [0.4], "y": [0]}}
EASE_IN_OUT = {"i": {"x": [0.45], "y": [1]}, "o": {"x": [0.55], "y": [0]}}


def hex_color(h, a=1):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [a]


def static(v):
    return {"a": 0, "k": v}


def anim(frames, ease=EASE_OUT):
    """frames: liste de (frame, valeur)."""
    k = []
    for idx, (t, v) in enumerate(frames):
        kf = {"t": t, "s": v if isinstance(v, list) else [v]}
        if idx < len(frames) - 1:
            kf.update(ease)
        k.append(kf)
    return {"a": 1, "k": k}


def transform(p=(0, 0), s=100, r=0, o=100, a=(0, 0)):
    def val(x, dims):
        if isinstance(x, dict):
            return x
        if isinstance(x, (int, float)):
            return static([x] * dims if dims > 1 else x)
        return static(list(x) + [0] * (dims - len(x)))

    return {
        "o": val(o, 1), "r": val(r, 1), "p": val(p, 3),
        "a": val(a, 3), "s": val(s, 3),
    }


def group_tr():
    return {"ty": "tr", "p": static([0, 0]), "a": static([0, 0]), "s": static([100, 100]),
            "r": static(0), "o": static(100), "sk": static(0), "sa": static(0), "nm": "tr"}


def ellipse(size, pos=(0, 0)):
    return {"ty": "el", "d": 1, "p": static(list(pos)), "s": static([size, size]), "nm": "el"}


def path(points, closed):
    n = len(points)
    return {"ty": "sh", "d": 1, "nm": "path", "ks": static({
        "i": [[0, 0]] * n, "o": [[0, 0]] * n, "v": [list(p) for p in points], "c": closed})}


def fill(color, opacity=100):
    return {"ty": "fl", "c": static(color), "o": static(opacity), "r": 1, "nm": "fill"}


def stroke(color, width, opacity=100):
    w = width if isinstance(width, dict) else static(width)
    o = opacity if isinstance(opacity, dict) else static(opacity)
    return {"ty": "st", "c": static(color), "o": o, "w": w, "lc": 2, "lj": 2, "ml": 4, "nm": "stroke"}


def trim(end):
    return {"ty": "tm", "s": static(0), "e": end, "o": static(0), "m": 1, "nm": "trim"}


def group(items, name="group"):
    return {"ty": "gr", "nm": name, "it": items + [group_tr()]}


_index = [0]


def layer(name, shapes, ks, ip=0, op=120):
    _index[0] += 1
    return {"ddd": 0, "ind": _index[0], "ty": 4, "nm": name, "sr": 1, "ks": ks, "ao": 0,
            "shapes": shapes, "ip": ip, "op": op, "st": 0, "bm": 0}


def composition(name, layers, op, size=300):
    return {"v": "5.7.4", "fr": FR, "ip": 0, "op": op, "w": size, "h": size, "nm": name,
            "ddd": 0, "assets": [], "layers": layers}


def write(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))


ORANGE = hex_color("#FF5A1F")
ORANGE_DARK = hex_color("#E04410")
ORANGE_SOFT = hex_color("#FFB59A")
GREEN = hex_color("#22C55E")
YELLOW = hex_color("#FFC53D")
WHITE = hex_color("#FFFFFF")
GREY = hex_color("#6B7280")
GREY_LIGHT = hex_color("#D1D5DB")
C = (150, 150)

# ---------------------------------------------------------------------------
# 1. success.json : cercle vert + coche dessinée + onde + confettis
# ---------------------------------------------------------------------------
_index[0] = 0
OP = 120
success_layers = [
    layer("check", [group([
        path([(-42, 2), (-12, 32), (46, -28)], False),
        trim(anim([(28, 0), (52, 100)])),
        stroke(WHITE, 16),
    ])], transform(p=C), op=OP),
    layer("circle", [group([ellipse(150), fill(GREEN)])],
          transform(p=C, s=anim([(0, [0, 0, 100]), (18, [112, 112, 100]), (28, [100, 100, 100])])), op=OP),
    layer("ring", [group([ellipse(150), stroke(GREEN, anim([(14, 8), (56, 1)]))])],
          transform(p=C, s=anim([(14, [100, 100, 100]), (56, [190, 190, 100])]),
                    o=anim([(14, 70), (56, 0)])), op=OP),
]
colors = [ORANGE, GREEN, YELLOW, ORANGE, GREEN, YELLOW, ORANGE, YELLOW]
for i in range(8):
    angle = math.radians(i * 45 + 20)
    start = [C[0] + math.cos(angle) * 70, C[1] + math.sin(angle) * 70, 0]
    end = [C[0] + math.cos(angle) * 132, C[1] + math.sin(angle) * 132, 0]
    size = 12 if i % 2 == 0 else 9
    success_layers.append(layer(f"particle_{i}", [group([ellipse(size), fill(colors[i])])], transform(
        p=anim([(18, start), (60, end)]),
        s=anim([(18, [100, 100, 100]), (60, [0, 0, 100])]),
        o=anim([(14, 0), (20, 100)]),
    ), op=OP))
write("success.json", composition("success", success_layers, OP))

# ---------------------------------------------------------------------------
# 2. empty_cart.json : chariot qui flotte doucement (boucle)
# ---------------------------------------------------------------------------
_index[0] = 0
OP = 120
cart_shapes = [
    group([ellipse(14, (-36, 48)), fill(GREY_LIGHT)], "wheel_l_in"),
    group([ellipse(14, (44, 48)), fill(GREY_LIGHT)], "wheel_r_in"),
    group([ellipse(28, (-36, 48)), fill(GREY)], "wheel_l"),
    group([ellipse(28, (44, 48)), fill(GREY)], "wheel_r"),
    group([path([(-22, -36), (-18, 4)], False), stroke(ORANGE_SOFT, 5)], "line_1"),
    group([path([(24, -36), (21, 4)], False), stroke(ORANGE_SOFT, 5)], "line_2"),
    group([path([(-66, -40), (78, -40), (62, 8), (-54, 8)], True),
           stroke(ORANGE_DARK, 8), fill(ORANGE)], "basket"),
    group([path([(-96, -64), (-72, -64), (-50, 24), (62, 24)], False), stroke(ORANGE_DARK, 9)], "handle"),
]
empty_layers = [
    layer("sparkle_1", [group([ellipse(10), fill(ORANGE)])],
          transform(p=(92, 70), o=anim([(0, 0), (30, 100), (60, 0)], EASE_IN_OUT),
                    s=anim([(0, [40, 40, 100]), (30, [100, 100, 100]), (60, [40, 40, 100])], EASE_IN_OUT)), op=OP),
    layer("sparkle_2", [group([ellipse(8), fill(YELLOW)])],
          transform(p=(212, 62), o=anim([(40, 0), (70, 100), (100, 0)], EASE_IN_OUT),
                    s=anim([(40, [40, 40, 100]), (70, [100, 100, 100]), (100, [40, 40, 100])], EASE_IN_OUT)), op=OP),
    layer("sparkle_3", [group([ellipse(7), fill(ORANGE_SOFT)])],
          transform(p=(240, 120), o=anim([(70, 0), (95, 100), (119, 0)], EASE_IN_OUT)), op=OP),
    layer("cart", cart_shapes, transform(
        p=anim([(0, [150, 140, 0]), (60, [150, 126, 0]), (120, [150, 140, 0])], EASE_IN_OUT),
        r=anim([(0, -4), (60, 4), (120, -4)], EASE_IN_OUT),
    ), op=OP),
    layer("shadow", [group([{"ty": "el", "d": 1, "p": static([0, 0]), "s": static([150, 18]), "nm": "el"},
                            fill(GREY, 22)])],
          transform(p=(150, 222), s=anim([(0, [100, 100, 100]), (60, [78, 78, 100]), (120, [100, 100, 100])],
                                         EASE_IN_OUT)), op=OP),
]
write("empty_cart.json", composition("empty_cart", empty_layers, OP))

# ---------------------------------------------------------------------------
# 3. welcome.json : pastille blanche + éclair orange + ondes (splash)
# ---------------------------------------------------------------------------
_index[0] = 0
OP = 150
BOLT = [(12, -55), (-30, 6), (-4, 6), (-14, 55), (30, -8), (4, -8)]
welcome_layers = [
    layer("bolt", [group([path(BOLT, True), fill(ORANGE)])], transform(
        p=C,
        s=anim([(14, [0, 0, 100]), (32, [120, 120, 100]), (42, [100, 100, 100])]),
        r=anim([(14, -25), (42, 0)]),
    ), op=OP),
    layer("disc", [group([ellipse(140), fill(WHITE)])], transform(
        p=C, s=anim([(0, [0, 0, 100]), (18, [110, 110, 100]), (28, [100, 100, 100])])), op=OP),
]
for i, start in enumerate((30, 75)):
    welcome_layers.append(layer(f"ring_{i}", [group([ellipse(140), stroke(WHITE, 4)])], transform(
        p=C,
        s=anim([(start, [100, 100, 100]), (start + 70, [205, 205, 100])], EASE_OUT),
        o=anim([(start, 80), (start + 70, 0)], EASE_OUT),
    ), ip=start, op=start + 72))
write("welcome.json", composition("welcome", welcome_layers, OP))
print("ok")
