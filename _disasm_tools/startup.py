# -*- coding: utf-8 -*-
"""
Herramienta: recorrer la cadena de frames de un move y decir, frame a
frame, cuando aparece la HITBOX y cuanto dura cada frame.

Sirve para el startup: el startup de una tecnica es la suma de las
duraciones (byte +0 del registro de 8 bytes) de los frames anteriores al
primero con hitbox (bit 6 del byte +0 de la entrada de sub-lista).

Uso: python startup.py <base50_hex> <sub8c_hex> <id> [n_frames]
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom

d = open(ruta_rom(), "rb").read()


def w16(o):
    return (d[o] << 8) | d[o + 1]


base50 = int(sys.argv[1], 16)
base8c = int(sys.argv[2], 16)
mid = int(sys.argv[3])
nfr = int(sys.argv[4]) if len(sys.argv) > 4 else 14

w = w16(base50 + mid * 2)
rec = base50 + w
print("=== base50=$%06X  sub8c=$%06X  move ID %d  (registro $%06X) ===" % (base50, base8c, mid, rec))
print(" frame  registro   dur(b0)  b1   flags  hit | dano stun  rX  rY | startup acum")
print(" " + "-" * 92)
acum = 0
primer = None
for f in range(nfr):
    r = rec + f * 8
    if r + 7 >= len(d):
        break
    b0 = d[r]
    b1 = d[r + 1]
    b2 = d[r + 2]
    sub = base8c + b1 * 4
    if sub + 3 >= len(d):
        break
    flags = d[sub]
    dur = d[sub + 1]
    blob = sub + w16(sub + 2)
    hit = bool(flags & 0x40)
    dmg = stn = rx = ry = 0
    if hit and blob + 7 < len(d):
        dmg, stn = d[blob], d[blob + 1]
        rx, ry = d[blob + 4] & 0x7F, d[blob + 6]
    marca = "  <<< PRIMER GOLPE" if (hit and primer is None) else ""
    if primer is None:
        acum += b0
    print("  %3d  $%06X   %5d   %3d   $%02X   %s  | %4d %4d %3d %3d | %6d%s"
          % (f, r, b0, b1, flags, "SI" if hit else "no",
             dmg, stn, rx, ry, acum, marca))
    if hit and primer is None:
        primer = f
    if b0 == 255 and f > 0:
        print("       (b0 = 255: probable frame de espera, no 255 ticks reales)")
print()
if primer is None:
    print("  >>> la hitbox NO aparece en los primeros %d frames" % nfr)
else:
    print("  >>> startup = %d ticks hasta el primer frame con hitbox (frame %d)"
          % (acum, primer))
    print("  >>> para acortarlo: baja el b0 (byte +0) de los frames anteriores")
