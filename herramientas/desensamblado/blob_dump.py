# -*- coding: utf-8 -*-
"""
Herramienta: volcar los BLOBS de cajas de un personaje, con el dato de
daño/stun/empuje y los radios de la hitbox.

Por que sirve: el dragon de Hiei (黒龍波) es un proyectil grande. Su
move ID no esta verificado, pero SI se puede localizar por su firma:
un hitbox con radio X grande. Este volcado da la firma de cada move.

Cadena verificada (ver DATOS_VERIFICADOS.md):
  ID ($5F) -> tabla de indices en $50 : destino = base + word[base + id*2]
           -> registro de 8 bytes   : destino + frame*8
           -> $8C (sub-lista)        : entrada b1*4
           -> blob de cajas          : sub-lista + word(entrada+2)

Layout del blob (leido en 0x1EC0E-0x1EC16):
  +0  $65  dano
  +1  $66  stun
  +2  $64  empuje (bits0-1 nivel, bits2-3 mascara, bit4 sin dano, bit5 sin freeze)
  +3  nibble bajo -> $68 (contador del atacante), nibble alto -> $67 (efecto)
  +4  radio X  (bit 7 = hay mas cajas)
  +5  offset X (sesgo $80)
  +6  radio Y
  +7  offset Y
  +8  siguiente caja (4 bytes)

Uso:  python blob_dump.py [ctx]      (0..9, por defecto 3 = Hiei)
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

ROM = ruta_rom()
d = open(ROM, "rb").read()

CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA, "?"),
    ("ctx1", 0x0C229A, 0x0C31DA, "?"),
    ("ctx2", 0x0C4EEA, 0x0C5DAA, "?"),
    ("ctx3", 0x0C7C9A, 0x0C8BEA, "HIEI"),
    ("ctx4", 0x0CA6DA, 0x0CB38A, "?"),
    ("ctx5", 0x0CCC7A, 0x0CDEFA, "?"),
    ("ctx6", 0x0CF99A, 0x0D069A, "ITSUKI"),
    ("ctx7", 0x0D1E5A, 0x0D2C6A, "KURAMA"),
    ("ctx8", 0x0D4A9A, 0x0D59FA, "?"),
    ("ctx9", 0x0D777A, 0x0D85AA, "?"),
]


def w16(o):
    return (d[o] << 8) | d[o + 1]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


nctx = int(sys.argv[1]) if len(sys.argv) > 1 else 3
nombre, base50, base8c, pj = CTX[nctx]

print("=== %s (%s)  base $50 = $%06X   base $8C = $%06X ===" % (nombre, pj, base50, base8c))
print()
print("id  dest      b0  b1  b2  b3  b4  b5   vX   vY | flags  dur | DANO STUN EMPUJE  rX  rY | sub")
print("-" * 118)

filas = []
for mid in range(0, 178):
    w = w16(base50 + mid * 2)
    if w == 0:
        continue
    dest = base50 + w
    b0, b1, b2, b3, b4, b5 = d[dest:dest + 6]
    vx, vy = sx(d[dest + 6]), sy(d[dest + 7])
    if b0 == 0 and b1 == 0 and b2 == 0x80:
        continue  # entrada vacia
    # sub-lista
    sub = base8c + b1 * 4
    flags = d[sub]
    dur = d[sub + 1]
    boff = w16(sub + 2)
    blob = sub + boff
    # blob: solo si el bit de hitbox (6) esta activo
    hit = (flags >> 6) & 1
    dmg = stn = psh = rx = ry = 0
    if hit:
        dmg = d[blob]
        stn = d[blob + 1]
        psh = d[blob + 2]
        rx = d[blob + 4] & 0x7F
        ry = d[blob + 6]
    filas.append((mid, dest, b0, b1, b2, b3, b4, b5, vx, vy, flags, dur,
                  dmg, stn, psh, rx, ry, sub, blob))
    print("%3d  %06X  %3d %3d  %02X  %02X  %02X  %02X %4d %4d |  %02X   %3d | %4d %4d  $%02X   %3d %3d | %06X"
          % (mid, dest, b0, b1, b2, b3, b4, b5, vx, vy, flags, dur,
             dmg, stn, psh, rx, ry, sub))

print()
print("=== CANDIDATOS A PROYECTIL (hitbox con radio X grande) ===")
cands = [f for f in filas if f[15] >= 16]
cands.sort(key=lambda f: -f[15])
for f in cands[:14]:
    mid, dest = f[0], f[1]
    flags, dmg, stn, psh, rx, ry = f[10], f[12], f[13], f[14], f[15], f[16]
    print("  id %3d  radioX=%3d radioY=%3d  dano=%3d stun=%3d empuje=$%02X  flags=$%02X  (record $%06X)"
          % (mid, rx, ry, dmg, stn, psh, flags, dest))
