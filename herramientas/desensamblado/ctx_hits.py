# -*- coding: utf-8 -*-
"""
Herramienta: resolver TODAS las cadenas de moves de un ctx y buscar
los que tienen HITBOX (bit 6 del byte +0 de la entrada de sub-lista).

Motivo: el log del juego (herramientas/lua/sonda_secuencia.lua) demuestra que
Itsuki (ctx6) durante el special pasa por los IDs 166 y 167, NO por
37/38/39.  Este script dice que cadena tiene la hitbox y donde esta
el byte de la duracion de cada frame.

Uso: python ctx_hits.py <ctx> [id_min] [id_max]
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

d = open(ruta_rom(), "rb").read()

CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA), ("ctx1", 0x0C229A, 0x0C31DA),
    ("ctx2", 0x0C4EEA, 0x0C5DAA), ("ctx3", 0x0C7C9A, 0x0C8BEA),
    ("ctx4", 0x0CA6DA, 0x0CB38A), ("ctx5", 0x0CCC7A, 0x0CDEFA),
    ("ctx6", 0x0CF99A, 0x0D069A), ("ctx7", 0x0D1E5A, 0x0D2C6A),
    ("ctx8", 0x0D4A9A, 0x0D59FA), ("ctx9", 0x0D777A, 0x0D85AA),
]


def w16(o):
    return (d[o] << 8) | d[o + 1]


nctx = int(sys.argv[1]) if len(sys.argv) > 1 else 6
lo = int(sys.argv[2]) if len(sys.argv) > 2 else 0
hi = int(sys.argv[3]) if len(sys.argv) > 3 else 177
nombre, base50, base8c = CTX[nctx]

print("=== %s  base50=$%06X  base8c=$%06X   IDs %d..%d ===" % (nombre, base50, base8c, lo, hi))
print()
print(" id  frame  registro   b0   b1  flags hit |  blob   dano stun emp  rX  rY  offX  offY")
print(" " + "-" * 92)

conhit = []
for mid in range(lo, hi + 1):
    w = w16(base50 + mid * 2)
    if w == 0:
        continue
    base = base50 + w
    for f in range(6):
        rec = base + f * 8
        if rec + 7 >= len(d):
            break
        b0 = d[rec]
        b1 = d[rec + 1]
        b2 = d[rec + 2]
        sub = base8c + b1 * 4
        if sub + 3 >= len(d):
            break
        flags = d[sub]
        blob = sub + w16(sub + 2)
        hit = bool(flags & 0x40)
        if blob + 7 >= len(d):
            continue
        dmg, stn, psh = d[blob], d[blob + 1], d[blob + 2]
        rx, ry = d[blob + 4] & 0x7F, d[blob + 6]
        ox, oy = d[blob + 5], d[blob + 7]
        print("%4d %5d  $%06X  %4d %4d  $%02X  %s  | $%06X %4d %4d $%02X %3d %3d  %4d %4d"
              % (mid, f, rec, b0, b1, flags, "SI" if hit else "no",
                 blob, dmg, stn, psh, rx, ry,
                 ox - 0x80 if ox >= 0x80 else ox,
                 oy - 0xA0 if oy >= 0xA0 else oy))
        if hit:
            conhit.append((mid, f, rec, b0, blob, dmg, stn, rx, ry))
    print()

print("=== frames CON HITBOX ===")
if not conhit:
    print("   (ninguno en este rango)")
for mid, f, rec, b0, blob, dmg, stn, rx, ry in conhit:
    print("   id %3d frame %d  registro $%06X  b0=%d  blob $%06X  dano=%d stun=%d rX=%d rY=%d"
          % (mid, f, rec, b0, blob, dmg, stn, rx, ry))
