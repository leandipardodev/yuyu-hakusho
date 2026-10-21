# -*- coding: utf-8 -*-
"""
Herramienta: resolver el move 37 del OBJETO (tabla $14DDC, el que usa
$58=$10) contra la sub-lista de CADA personaje, para ver cual de ellas
produce la caja de 9x9 de las manos.

Por que: el objeto recibe su $5F (37) y su $50 ($14DDC) pero su $8C no
esta escrito en ningun sitio del ROM (verificado). La unica forma de que
la sub-lista funcione es que el objeto herede la del personaje.

Ademas escanea el ROM buscando cualquier escritura a $8c(a0).

Uso: python obj_hands.py
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom

d = open(ruta_rom(), "rb").read()

CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA, "Sensui?"), ("ctx1", 0x0C229A, 0x0C31DA, "?"),
    ("ctx2", 0x0C4EEA, 0x0C5DAA, "?"), ("ctx3", 0x0C7C9A, 0x0C8BEA, "HIEI"),
    ("ctx4", 0x0CA6DA, 0x0CB38A, "?"), ("ctx5", 0x0CCC7A, 0x0CDEFA, "?"),
    ("ctx6", 0x0CF99A, 0x0D069A, "ITSUKI"), ("ctx7", 0x0D1E5A, 0x0D2C6A, "KURAMA"),
    ("ctx8", 0x0D4A9A, 0x0D59FA, "?"), ("ctx9", 0x0D777A, 0x0D85AA, "?"),
]


def w16(o):
    return (d[o] << 8) | d[o + 1]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


OBJ50 = 0x014DDC

print("=== el objeto $58=$10: move 37 en su tabla $14DDC ===")
w = w16(OBJ50 + 37 * 2)
rec = OBJ50 + w
b = [d[rec + i] for i in range(8)]
print("  offset del indice: %d   registro: $%06X" % (w, rec))
print("  b0(dur)=%d b1=%d b2=$%02X b3=$%02X b4=$%02X b5=$%02X b6(vX)=$%02X b7(vY)=$%02X"
      % (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]))
print()

print("=== resolviendo ese move contra la sub-lista de cada personaje ===")
print("  ctx       b1 -> sub      flags dur | DANO STUN EMP  rX  rY | blob")
for nombre, b50, b8c, pj in CTX:
    sub = b8c + b[1] * 4
    if sub + 3 >= len(d):
        continue
    flags = d[sub]
    dur = d[sub + 1]
    blob = sub + w16(sub + 2)
    if blob + 7 >= len(d):
        continue
    dmg, stn, psh = d[blob], d[blob + 1], d[blob + 2]
    rx, ry = d[blob + 4] & 0x7F, d[blob + 6]
    marca = "   <<< CAJA 9x9 (las manos)" if (rx == 9 and ry == 9) else ""
    print("  %-9s %3d -> $%06X  $%02X %3d | %4d %4d $%02X %3d %3d | $%06X%s"
          % (pj, b[1], sub, flags, dur, dmg, stn, psh, rx, ry, blob, marca))

print()
print("=== escrituras a $8c(a0) en todo el ROM (patron 00 8C como destino) ===")
n = 0
for i in range(len(d) - 10):
    if d[i] in (0x23, 0x2B) and d[i + 1] in (0x6D, 0x7C, 0x40, 0x78):
        # MOVE.L (d16,An) -> (d16,Am)  : 23 xx <disp16> <disp16>
        if d[i + 4] == 0x00 and d[i + 5] == 0x8C and d[i + 8] == 0x00 and d[i + 9] == 0x8C:
            print("  0x%06X  %s" % (i, " ".join("%02X" % x for x in d[i:i + 10])))
            n += 1
print("  total: %d" % n)
