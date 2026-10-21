# -*- coding: utf-8 -*-
"""
Lee los registros de move REALES.

Aritmetica correcta, deducida del codigo en 0x1EB40:

    movea.l $50(a5), a2          a2 = BASE de la tabla
    adda.w  (a2, d0.w), a2       a2 = BASE + palabra[BASE + id*2]

Es decir: la tabla contiene PALABRAS y el destino es BASE + palabra.
Relativo a la propia tabla, no absoluto.
"""
import struct
import sys

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()

IDX50 = [
    ("ctx0", 0x0BF75A), ("ctx1", 0x0C229A), ("ctx2", 0x0C4EEA), ("ctx3", 0x0C7C9A),
    ("ctx4", 0x0CA6DA), ("ctx5", 0x0CCC7A), ("ctx6", 0x0CF99A), ("ctx7", 0x0D1E5A),
    ("ctx8", 0x0D4A9A), ("ctx9", 0x0D777A),
]

nombre = sys.argv[1] if len(sys.argv) > 1 else "ctx0"
n = int(sys.argv[2]) if len(sys.argv) > 2 else 16
base = dict(IDX50)[nombre]

print("=== %s : tabla indice en $%06X (autorrelativa) ===" % (nombre, base))
print()
print(" id | palabra | destino    | b0   b1   b2   b3   b4   b5  |  vX     vY")
print("-" * 70)
vistos = set()
for mid in range(n):
    slot = base + mid * 2
    if slot + 2 > len(d):
        break
    pal = struct.unpack(">H", d[slot:slot + 2])[0]
    dest = base + pal
    if dest + 8 > len(d):
        print(" %2d | $%04X  | (fuera)    |" % (mid, pal))
        continue
    vistos.add(dest)
    r = d[dest:dest + 8]
    vx = (r[6] - 0x80) & 0xFFFF
    vy = (r[7] - 0xA0) & 0xFFFF
    if vx > 0x7FFF:
        vx -= 0x10000
    if vy > 0x7FFF:
        vy -= 0x10000
    print(" %2d | $%04X  | $%06X   | %02X   %02X   %02X   %02X   %02X   %02X  | %5d %6d"
          % (mid, pal, dest, r[0], r[1], r[2], r[3], r[4], r[5], vx, vy))

print()
print("destinos unicos: %d" % len(vistos))
if vistos:
    vs = sorted(vistos)
    print("rango: $%06X - $%06X" % (vs[0], vs[-1]))
print()
print("hex crudo de los primeros registros:")
for i, dest in enumerate(sorted(vistos)[:4]):
    print("  $%06X  %s" % (dest, d[dest:dest + 16].hex(" ")))
