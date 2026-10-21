# -*- coding: utf-8 -*-
"""
Herramienta: resolver la cadena de moves de un OBJETO con la sub-lista
de un personaje, para ver que moves del objeto usan las cajas de la
habilidad (las entradas 131/132 de ctx6 = Itsuki).

Por que: los objetos (proyectiles, ondas, manos flotantes) tienen su
PROPIA tabla de moves ($50, la pone su handler en la tabla de handlers
$14A00) pero HEREDAN la sub-lista ($8C) del personaje. Asi que un objeto
puede usar las cajas del personaje (por eso la tabla $8C esta compartida).

Uso: python obj_chain.py <base50_hex> <sub8c_hex> [n_ids] [n_frames]
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

d = open(ruta_rom(), "rb").read()


def w16(o):
    return (d[o] << 8) | d[o + 1]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


base50 = int(sys.argv[1], 16)
base8c = int(sys.argv[2], 16)
nids = int(sys.argv[3]) if len(sys.argv) > 3 else 40
nfr = int(sys.argv[4]) if len(sys.argv) > 4 else 6

print("=== objeto: base50=$%06X  sub8c=$%06X ===" % (base50, base8c))
print("id  destino   b0(dur) b1  b2  b3  b4  b5   vX   vY | flg dur | DANO STUN EMP  rX  rY | blob")
for mid in range(nids):
    ix = base50 + mid * 2
    if ix + 1 >= len(d):
        break
    w = w16(ix)
    if w == 0:
        continue
    dest = base50 + w
    if dest + 7 >= len(d):
        continue
    b = [d[dest + i] for i in range(8)]
    sub = base8c + b[1] * 4
    if sub + 3 >= len(d):
        continue
    flags = d[sub]
    dur = d[sub + 1]
    blob = sub + w16(sub + 2)
    dmg = stn = psh = rx = ry = 0
    if flags & 0x40 and blob + 7 < len(d):
        dmg, stn, psh = d[blob], d[blob + 1], d[blob + 2]
        rx, ry = d[blob + 4] & 0x7F, d[blob + 6]
    marca = "  <<< sub %d" % b[1] if b[1] in (131, 132) else ""
    print("%3d $%06X %4d %3d  %02X  %02X  %02X  %02X %4d %4d |  %02X %3d | %4d %4d $%02X %3d %3d | $%06X%s"
          % (mid, dest, b[0], b[1], b[2], b[3], b[4], b[5], sx(b[6]), sy(b[7]),
             flags, dur, dmg, stn, psh, rx, ry, blob, marca))
