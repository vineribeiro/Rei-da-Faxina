#!/usr/bin/env python3
"""Gera os sprites 8 bits dos Faxinhos (10 animais x 4 fases x 8 poses) e ovos, itens e acessórios.
Cada quadro tem 32x32 px; o app mostra com image-rendering: pixelated.
Uso: python3 tools/gen_pets.py  (escreve em img/pet/)"""
import os, math
from PIL import Image
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'img', 'pet')
os.makedirs(OUT, exist_ok=True)
N = 32
INK = (35, 26, 51)
hexc = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
mix = lambda a, b, t: tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))
lighten = lambda c, t=.35: mix(c, (255, 255, 255), t)
darken = lambda c, t=.32: mix(c, (20, 10, 40), t)

class Cv:
    def __init__(s):
        s.rgb = np.zeros((N, N, 3), int); s.a = np.zeros((N, N), bool)
    def ell_mask(s, cx, cy, rx, ry):
        ys, xs = np.mgrid[0:N, 0:N]
        return ((xs + .5 - cx) / max(rx, .3)) ** 2 + ((ys + .5 - cy) / max(ry, .3)) ** 2 <= 1
    def poly_mask(s, pts):
        m = np.zeros((N, N), bool)
        ys, xs = np.mgrid[0:N, 0:N]
        px, py = xs + .5, ys + .5
        n = len(pts); inside = np.zeros((N, N), bool)
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]; xj, yj = pts[j]
            cond = ((yi > py) != (yj > py)) & (px < (xj - xi) * (py - yi) / ((yj - yi) or 1e-9) + xi)
            inside ^= cond; j = i
        return inside
    def part(s, mask, base, rim=False, shade=True, only=None):
        if only is not None: mask = mask & only
        m = mask.copy()
        if rim:  # separador escuro em volta, só sobre pixels já pintados
            grow = m.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)): grow |= np.roll(np.roll(m, dy, 0), dx, 1)
            ring = grow & ~m & s.a
            s.rgb[ring] = darken(base, .55)
        s.rgb[m] = base; s.a |= m
        if shade:
            ul = np.roll(np.roll(m, 1, 0), 1, 1)       # vizinho acima-esquerda
            dr = np.roll(np.roll(m, -1, 0), -1, 1)     # vizinho abaixo-direita
            lit = m & ~ul; sh = m & ~dr
            s.rgb[sh] = darken(base); s.rgb[lit] = lighten(base, .38)
            # sombra mais larga embaixo
            d2 = np.roll(m, -2, 0); s.rgb[m & ~d2 & ~sh] = mix(base, darken(base), .5)
    def px(s, x, y, c):
        if 0 <= x < N and 0 <= y < N: s.rgb[y, x] = c; s.a[y, x] = True
    def pxs(s, pts, c):
        for x, y in pts: s.px(x, y, c)
    def img(s, outline=True, tint=None):
        a = s.a.copy(); rgb = s.rgb.copy()
        if outline:
            g = a.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)): g |= np.roll(np.roll(a, dy, 0), dx, 1)
            ring = g & ~a; rgb[ring] = INK; a = g
        out = np.zeros((N, N, 4), np.uint8); out[:, :, :3] = rgb; out[:, :, 3] = a * 255
        return Image.fromarray(out, 'RGBA')

# ---------------- espécies ----------------
SP = {
 'dragao':   dict(base='#E8503A', belly='#FFD98A', acc='#FFE08A', wing='#F2A33A', cheek='#FF9AA2'),
 'unicornio':dict(base='#F6EEFF', belly='#FFFFFF', acc='#FFD34D', wing='#FF7AA8', cheek='#FFA9C8'),
 'coruja':   dict(base='#9A6B4B', belly='#F1DDB8', acc='#FFB52E', wing='#7A5238', cheek='#E9A27A'),
 'raposa':   dict(base='#F08A24', belly='#FFF2DC', acc='#3A2A2A', wing='#B85A12', cheek='#FFB0A0'),
 'polvo':    dict(base='#B56BE0', belly='#F0C8FF', acc='#FF8FC4', wing='#8444B5', cheek='#FF9ACB'),
 'morcego':  dict(base='#6B5AA0', belly='#A898D8', acc='#FFFFFF', wing='#4A3C7A', cheek='#FF9AB8'),
 'pinguim':  dict(base='#3E5C8A', belly='#F4F7FF', acc='#FFA62E', wing='#2E466B', cheek='#FF9AA2'),
 'lagarto':  dict(base='#5DBE4E', belly='#E8F5B0', acc='#FF7A59', wing='#3A8A34', cheek='#FF9A80'),
 'panda':    dict(base='#F7F7FA', belly='#FFFFFF', acc='#2B2B33', wing='#2B2B33', cheek='#FFA9B8'),
 'coelho':   dict(base='#FFF5F8', belly='#FFE0EA', acc='#FF8FB0', wing='#E3BFD0', cheek='#FFA0BC'),
}
FORMS = {  # cabeça (cx,cy,rx,ry), corpo (cx,cy,rx,ry), escala dos detalhes, pés
 'baby':  dict(h=(16, 19, 9, 8), b=None, fs=.55, feet=[(12, 27), (20, 27)], fr=(2.5, 1.6)),
 'kid':   dict(h=(16, 15, 9, 8), b=(16, 24, 6, 5), fs=.8, feet=[(13, 28.5), (19, 28.5)], fr=(2.8, 1.8)),
 'adult': dict(h=(16, 13, 10, 9), b=(16, 24, 7, 6), fs=1, feet=[(12, 29), (20, 29)], fr=(3.2, 2)),
 'elder': dict(h=(16, 13, 10, 9), b=(16, 24, 7, 6), fs=1, feet=[(12, 29), (20, 29)], fr=(3.2, 2)),
}
POSES = ['idle0', 'idle1', 'happy', 'sleep', 'sad', 'sick', 'dead', 'eat']

def draw(species, form, pose):
    P = SP[species]; F = FORMS[form]; c = Cv()
    base = hexc(P['base']); belly = hexc(P['belly']); acc = hexc(P['acc']); wing = hexc(P['wing']); cheek = hexc(P['cheek'])
    if form == 'elder': base = mix(base, (170, 170, 175), .28); belly = mix(belly, (235, 235, 235), .3)
    if pose == 'dead': base = mix(base, (150, 150, 160), .6); belly = mix(belly, (200, 200, 205), .5)
    if pose == 'sick': base = mix(base, (150, 210, 120), .3)
    fs = F['fs']; hx, hy, hrx, hry = F['h']; bob = 1 if pose == 'idle1' else 0
    hy += bob
    body = F['b']; big = form in ('adult', 'elder')
    M = c.ell_mask; T = c.poly_mask
    # ---- elementos atrás do corpo
    def wings(col, spread=1.0):
        if body is None or fs < .7: return
        bx, by, brx, bry = body
        for sd in (-1, 1):
            pts = [(bx + sd * (brx - 1), by - 5), (bx + sd * (brx + 7 * fs * spread), by - 9 * fs), (bx + sd * (brx + 8 * fs * spread), by + 1), (bx + sd * (brx + 4 * fs), by + 3), (bx + sd * (brx - 1), by + 2)]
            c.part(T(pts), col)
    def tail(col, tip=None, sz=1):
        if body is None: return
        bx, by, brx, bry = body
        c.part(M(bx + brx + 2 * fs, by + 2, 4 * fs * sz, 2.4 * fs * sz), col)
        if tip: c.part(M(bx + brx + 5 * fs * sz, by + 1, 2.2 * fs, 2.2 * fs), tip)
    if species == 'dragao':
        wings(wing); tail(base, acc)
    if species == 'unicornio':
        for i, col in enumerate(['#FF7AA8', '#FFC857', '#7AD7FF', '#B28BFF']):
            c.part(M(hx - hrx + 1 - (i % 2), hy - 3 + i * 3, 3.2 * fs + 1, 2.8), hexc(col))
        if body:
            for i, col in enumerate(['#FF7AA8', '#7AD7FF', '#B28BFF']): c.part(M(body[0] + body[2] + 1 + i, body[1] + 1 + i, 2.6, 2), hexc(col))
    if species == 'coruja': wings(wing, .55)
    if species == 'raposa' and body:
        c.part(M(body[0] + body[2] + 3, body[1] - 1, 5 * fs + 1, 6 * fs + 1), base); c.part(M(body[0] + body[2] + 5, body[1] - 4, 2.2, 2.4), belly)
    if species == 'morcego': wings(wing, 1.25)
    if species == 'pinguim': pass
    if species == 'lagarto' and body:
        bx, by, brx, bry = body
        for i, (dx, dy, rx, ry) in enumerate([(brx + 2, 3, 4, 2.4), (brx + 6, 1.6, 3.2, 2), (brx + 9, -.5, 2.4, 1.6), (brx + 11, -2.5, 1.6, 1.4)]):
            c.part(M(bx + dx * fs, by + dy, rx * fs + .6, ry * fs + .4), base)
    if species == 'coelho' and body: c.part(M(body[0] + body[2] + 1, body[1] + 2, 3 * fs + 1, 3 * fs + 1), hexc('#FFFFFF'))
    if species == 'polvo':
        for i, tx in enumerate([8, 13, 19, 24]):
            ty = 28 if form != 'baby' else 26
            c.part(M(tx, ty, 3, 2.2), base); c.px(int(tx + (-2 if i < 2 else 2)), ty - 1 if i % 2 else ty, lighten(base, .4))
        for tx, ty in ((9, 27), (23, 27)): c.px(tx, ty, belly)
    # ---- corpo
    if body:
        bx, by, brx, bry = body
        c.part(M(bx, by, brx, bry), base)
        bb = belly
        if species == 'panda': bb = hexc('#FFFFFF')
        c.part(M(bx, by + 1, brx - 2.2, bry - 1.8), bb, shade=False)
        # braços
        if species == 'panda':
            for sd in (-1, 1): c.part(M(bx + sd * (brx), by - 1, 2.2, 3.4), hexc('#2B2B33'), rim=True)
        elif species == 'pinguim':
            for sd in (-1, 1): c.part(M(bx + sd * (brx + .5), by - 1, 2, 3.8), wing, rim=True)
        elif species == 'coruja':
            for sd in (-1, 1): c.part(M(bx + sd * (brx - .5), by, 2.2, 4), wing, rim=True)
            for i in range(3): c.px(bx - 2 + i * 2, by + 1 + (i % 2), darken(belly, .25))
        elif species in ('dragao', 'lagarto'):
            for sd in (-1, 1): c.part(M(bx + sd * (brx - .5), by + 1, 1.8, 2.2), base, rim=True)
        else:
            for sd in (-1, 1): c.part(M(bx + sd * (brx - .2), by + .5, 1.8, 2.4), base, rim=True)
    # pés
    for i, (fx, fy) in enumerate(F['feet']):
        col = {'pinguim': acc, 'coruja': acc, 'unicornio': hexc('#FFD34D'), 'panda': hexc('#2B2B33'), 'raposa': hexc('#3A2A2A')}.get(species, base)
        if form == 'baby' and species in ('polvo',): continue
        if species == 'polvo' and body: continue
        c.part(M(fx, fy, F['fr'][0], F['fr'][1]), col, rim=True)
    # ---- cabeça
    c.part(M(hx, hy, hrx, hry), base, rim=True)
    top = hy - hry
    # detalhes de cabeça por espécie (sobre a cabeça)
    if species == 'dragao':
        for sd in (-1, 1):
            c.part(T([(hx + sd * 3, top + 2), (hx + sd * (5 + 1 * fs), top - 4 * fs - 1), (hx + sd * 7, top + 3)]), acc, rim=True)
        c.part(M(hx, hy + 4, 4.4, 3), belly, shade=False)  # focinho
        c.pxs([(hx - 2, hy + 4), (hx + 2, hy + 4)], darken(base, .5))
        if big:
            for sd in (-1, 1): c.part(T([(hx + sd * 8, top + 4), (hx + sd * 11, top + 2), (hx + sd * 9, top + 6)]), acc)
    if species == 'unicornio':
        for sd in (-1, 1): c.part(T([(hx + sd * 5, top + 2), (hx + sd * 6, top - 3 * fs - 1), (hx + sd * 8, top + 3)]), base, rim=True)
        hh = 6 * fs + 1
        c.part(T([(hx - 2, top + 1), (hx, top - hh), (hx + 2, top + 1)]), hexc(P['acc']), rim=True)
        for i in range(int(hh // 2)): c.pxs([(hx - 1 + (i % 2), int(top - 1 - i * 2)), (hx + (i % 2), int(top - 2 - i * 2))], lighten(hexc(P['acc']), .55))
        c.part(M(hx - 8, hy - 4, 2.4, 3), hexc('#FF7AA8')); c.part(M(hx + 6, hy - 6, 2.4, 2.6), hexc('#7AD7FF'))
    if species == 'coruja':
        for sd in (-1, 1): c.part(T([(hx + sd * 5, top + 3), (hx + sd * 8, top - 3 * fs - 1), (hx + sd * 9, top + 5)]), wing, rim=True)
        for sd in (-1, 1): c.part(M(hx + sd * 4.2, hy + 1, 4.4, 4.6), belly, shade=False)
    if species == 'raposa':
        for sd in (-1, 1):
            c.part(T([(hx + sd * 3, top + 3), (hx + sd * 7, top - 6 * fs - 1), (hx + sd * 9, top + 5)]), base, rim=True)
            c.part(T([(hx + sd * 5.5, top - 1 * fs), (hx + sd * 7, top - 6 * fs - 1), (hx + sd * 8, top)]), hexc('#3A2A2A'))
        for sd in (-1, 1): c.part(M(hx + sd * 7, hy + 4, 4, 3), belly, shade=False)
        c.part(M(hx, hy + 5, 4, 2.6), belly, shade=False)
    if species == 'polvo':
        c.part(M(hx, hy - 1, hrx - 1, hry), base, shade=True)
        for tx, ty in ((hx - 5, top + 3), (hx + 4, top + 2), (hx + 1, top + 5)): c.px(tx, ty, lighten(base, .55))
        for tx, ty in ((hx - 7, hy + 6), (hx + 7, hy + 6)): c.px(tx, ty, belly)
    if species == 'morcego':
        for sd in (-1, 1):
            c.part(T([(hx + sd * 3, top + 3), (hx + sd * 6, top - 8 * fs - 1), (hx + sd * 9, top + 4)]), base, rim=True)
            c.part(T([(hx + sd * 5, top + 1), (hx + sd * 6, top - 5 * fs), (hx + sd * 7.4, top + 2)]), hexc('#FF9AB8'), shade=False)
    if species == 'pinguim':
        for sd in (-1, 1): c.part(M(hx + sd * 3.6, hy + 3, 4.6, 5), belly, shade=False)
        c.part(M(hx, hy + 1, 5.6, 5.8), belly, shade=False)
        c.part(T([(hx - 2, hy + 4), (hx, hy + 7), (hx + 2, hy + 4)]), acc, rim=True)
        c.part(M(hx, top + 1.5, 5, 2), darken(base, .15), shade=False)
    if species == 'lagarto':
        for i in range(3 if big else 2): c.part(T([(hx - 4 + i * 4, top + 1), (hx - 2 + i * 4, top - 3 * fs - 1), (hx + i * 4, top + 1)]), acc)
        for sd in (-1, 1): c.part(M(hx + sd * 6, top + 2, 3, 3), base, rim=True)
        c.part(M(hx, hy + 5, 5, 3), belly, shade=False)
    if species == 'panda':
        for sd in (-1, 1): c.part(M(hx + sd * (hrx - 1.5), top + 2, 3.4, 3.4), hexc('#2B2B33'), rim=True)
        for sd in (-1, 1): c.part(M(hx + sd * 4.4, hy + 1.5, 3.2, 4.2), hexc('#2B2B33'), shade=False)
    if species == 'coelho':
        eh = 7 * fs + 2
        for sd in (-1, 1):
            c.part(M(hx + sd * 4.5 + (1 if pose == 'sad' else 0) * sd * 2, top - eh * .35 + (3 if pose == 'sad' else 0), 2.8, eh), base, rim=True)
            c.part(M(hx + sd * 4.5 + (1 if pose == 'sad' else 0) * sd * 2, top - eh * .3 + (3 if pose == 'sad' else 0), 1.4, eh - 2.4), acc, shade=False)
    # ---- rosto
    ey = hy + (2 if species in ('coruja', 'lagarto') else 1.5)
    ey = int(round(ey)); ex = 4 if big else (3 if form == 'kid' else 3)
    if species in ('coruja', 'panda'): ex = 4
    face(c, hx, ey, ex, pose, species, form, cheek, acc)
    # elder: sobrancelhas e barba
    if form == 'elder':
        for sd in (-1, 1):
            for k in range(4): c.px(int(hx + sd * (ex + 1) - sd * k + (0)), ey - 3 - (1 if k == 0 else 0), (240, 240, 245))
        c.part(M(hx, hy + 7, 4.2, 2.4), (240, 240, 245), shade=False)
    return c

def face(c, hx, ey, ex, pose, species, form, cheek, acc):
    black = INK; white = (255, 255, 255)
    lx, rx_ = hx - ex, hx + ex - 1    # canto esquerdo das duas pupilas (3 de largura)
    big_eye = form in ('baby', 'kid') or species in ('coruja',)
    def eye(x0, mirror):
        if pose == 'happy':
            c.pxs([(x0, ey + 1), (x0 + 1, ey), (x0 + 2, ey + 1)], black); return
        if pose == 'sleep':
            c.pxs([(x0, ey), (x0 + 1, ey + 1), (x0 + 2, ey)], black); return
        if pose == 'dead':
            c.pxs([(x0, ey - 1), (x0 + 2, ey - 1), (x0 + 1, ey), (x0, ey + 1), (x0 + 2, ey + 1)], black); return
        if pose == 'sick':
            c.pxs([(x0 + 1, ey - 1), (x0, ey), (x0 + 2, ey), (x0 + 1, ey + 1), (x0 + 1, ey)], black); c.px(x0 + 1, ey, (150, 210, 120)); return
        h = 4 if big_eye else 3
        pc = black
        for yy in range(h):
            for xx in range(3):
                if (yy in (0, h - 1)) and xx != 1 and h == 4 and False: continue
                c.px(x0 + xx, ey - 1 + yy, pc)
        c.px(x0, ey - 1, white)                       # brilho
        if h == 4: c.px(x0 + 2, ey + 2, (120, 100, 170))
        if species == 'panda': c.px(x0 + 1, ey, white)
    eye(lx, False); eye(rx_, True)
    if pose == 'sad':
        c.px(lx, ey + 3 if not big_eye else ey + 4, (130, 200, 255)); c.px(rx_ + 2, ey + 3 if not big_eye else ey + 4, (130, 200, 255))
        c.pxs([(lx, ey - 3), (lx + 1, ey - 2), (lx + 2, ey - 2)], black); c.pxs([(rx_ + 2, ey - 3), (rx_ + 1, ey - 2), (rx_, ey - 2)], black)
    # bochechas
    cc = cheek
    if pose in ('dead',): cc = (190, 190, 200)
    cy = ey + (3 if not big_eye else 4)
    if pose != 'sick':
        c.pxs([(lx - 2, cy), (lx - 1, cy)], cc); c.pxs([(rx_ + 3, cy), (rx_ + 4, cy)], cc)
    else:
        c.pxs([(lx - 2, cy), (lx - 1, cy), (rx_ + 3, cy), (rx_ + 4, cy)], (120, 190, 100))
    # boca
    my = cy + (1 if species != 'polvo' else 1)
    mx = hx
    if species in ('pinguim', 'dragao') : my += 1
    if pose == 'happy':
        c.pxs([(mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my), (mx - 1, my + 1), (mx, my + 1)], black); c.px(mx - 1, my + 1, (255, 120, 140)); c.px(mx, my + 1, (255, 120, 140))
    elif pose == 'eat':
        c.pxs([(mx - 1, my), (mx, my), (mx - 1, my + 1), (mx, my + 1)], black); c.px(mx - 1, my + 1, (255, 120, 140))
    elif pose == 'sad':
        c.pxs([(mx - 2, my + 1), (mx - 1, my), (mx, my), (mx + 1, my + 1)], black)
    elif pose in ('sleep',):
        c.pxs([(mx - 1, my), (mx, my)], black)
    elif pose == 'dead':
        c.pxs([(mx - 1, my), (mx, my), (mx + 1, my)], black)
    elif pose == 'sick':
        c.pxs([(mx - 2, my), (mx - 1, my + 1), (mx, my), (mx + 1, my + 1)], black)
    else:
        c.pxs([(mx - 2, my), (mx - 1, my + 1), (mx, my + 1), (mx + 1, my)], black)
    if species == 'morcego' and pose in ('happy', 'eat', 'idle0', 'idle1'): c.pxs([(mx - 2, my + 1), (mx + 1, my + 1)], (255, 255, 255))
    if species == 'coelho' and pose in ('idle0', 'idle1', 'happy'): c.pxs([(mx - 1, my + 1), (mx, my + 1)], (255, 255, 255))

# ---------------- ovos ----------------
EGGS = [('azul', '#7AB8FF', '#3F6FD0'), ('rosa', '#FF9EC4', '#D04F8A'), ('verde', '#8EE08A', '#3FA050')]
def egg(var, frame):
    name, spot, spot2 = EGGS[var]; c = Cv(); M = c.ell_mask
    base = hexc('#FFF4DC'); sp = hexc(spot); sp2 = hexc(spot2)
    cx = 16 + (1 if frame == 1 else 0) * 0; cy = 17 + (1 if frame == 1 else 0)
    tilt = {2: -1, 3: 1}.get(frame, 0)
    m = M(cx + tilt, cy, 8.2, 10.4) | M(cx + tilt, cy + 2, 9, 9)
    c.part(m, base)
    for (dx, dy, r) in [(-3, -3, 1.8), (3, 1, 2.2), (-4, 4, 2), (2, 6, 1.6), (-1, -7, 1.4), (4, -5, 1.4)]:
        c.part(M(cx + tilt + dx, cy + dy, r, r), sp, only=m, shade=False)
        c.px(int(cx + tilt + dx - 1), int(cy + dy - 1), lighten(sp, .5)) if False else None
    for (dx, dy) in [(-3, -3), (3, 1), (-4, 4)]: c.px(int(cx + tilt + dx), int(cy + dy + 1), sp2)
    if frame >= 2:  # rachaduras
        pts = [(cx - 4, cy - 2), (cx - 2, cy - 4), (cx, cy - 2), (cx + 2, cy - 5), (cx + 4, cy - 2)] if frame == 2 else [(cx - 5, cy - 3), (cx - 3, cy - 6), (cx - 1, cy - 3), (cx + 1, cy - 7), (cx + 3, cy - 3), (cx + 5, cy - 6)]
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            for t in range(5): c.px(int(round(x0 + (x1 - x0) * t / 4)) + tilt, int(round(y0 + (y1 - y0) * t / 4)), INK)
    if frame == 4:  # olhinhos espiando
        c.pxs([(cx - 3, cy - 1), (cx - 3, cy), (cx + 2, cy - 1), (cx + 2, cy)], INK)
    return c.img()

# ---------------- ícones 16x16 em grade ASCII ----------------
ICONS = {
 'racao': ("................|...XXXXXXX.....|..XmmmmmmmX....|.XmmMMMMmmmX...|.XmMMMMMMMmX..XX|.XmMMMMMMMmXXXwX|.XmMMMMMMMmX.XXX|..XmmMMMmmmX....|...XXmmmXX......|.....XXX........|", {'X': INK, 'm': '#E0603A', 'M': '#F28B5A', 'w': '#FFF4DC'}),
}
def grid_icon(rows, pal, scale=1):
    rows = rows.split('|'); w = max(len(r) for r in rows); h = len(rows)
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    ox, oy = (16 - w) // 2, (16 - h) // 2
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal: im.putpixel((ox + x, oy + y), hexc(pal[ch]) + (255,) if isinstance(pal[ch], str) else tuple(pal[ch]) + (255,))
    return im

def icon16(name):
    """Desenha os ícones por código (16x16)."""
    c = Cv(); c.rgb = np.zeros((N, N, 3), int); out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    return out

def sheet(frames, path):
    w = len(frames) * N; im = Image.new('RGBA', (w, N), (0, 0, 0, 0))
    for i, f in enumerate(frames): im.paste(f, (i * N, 0))
    im.save(path, optimize=True)

if __name__ == '__main__':
    for sp in SP:
        for form in FORMS:
            sheet([draw(sp, form, p).img() for p in POSES], os.path.join(OUT, '%s-%s.png' % (sp, form)))
    for v in range(3): sheet([egg(v, f) for f in range(5)], os.path.join(OUT, 'ovo-%s.png' % EGGS[v][0]))
    print('ok')
