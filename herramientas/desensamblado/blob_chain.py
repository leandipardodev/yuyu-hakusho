# -*- coding: utf-8 -*-
"""
Herramienta: volcar TODA la cadena de cajas (blob) de un move, frame a
frame, de un personaje.

Por que sirve: una tecnica puede tener VARIAS cajas encadenadas (el bit 7
del radioX dice "hay mas cajas"). El drag de Hiei (ID 38) es el caso
interesante: su hitbox es una cadena de cajas de 68 px de ancho.

Cadena:
  ID ($5F) -> registro de 8 bytes (destino + frame*8)
           -> $8C + b1*4  (entrada de sub-lista: flags, dur, offset)
           -> blob = sub-lista + word(offset)
           -> el blob son 4 bytes de cabecera + N cajas de 4 bytes
             (radioX, offX, radioY, offY) mientras el bit 7 del radioX
             siga puesto.

Uso:  python blob_chain.py <ctx> <move_id> [n_frames]
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

ROM = ruta_rom()
d = open(ROM, "rb").read()

CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA, "KURAMA"), ("ctx1", 0x0C229A, 0x0C31DA, "Kuwabara"),
    ("ctx2", 0x0C4EEA, 0x0C5DAA, "?"), ("ctx3", 0x0C7C9A, 0x0C8BEA, "HIEI"),
    ("ctx4", 0x0CA6DA, 0x0CB38A, "?"), ("ctx5", 0x0CCC7A, 0x0CDEFA, "?"),
    # ctx0 = KURAMA (stun 40, init $0x12792). ctx6 = ITSUKI (stun 40, init
    # $0x1294E, MEDIDO con sonda_secuencia.lua). ctx7 = Toguro (hermano mayor),
    # stun 38, init $0x12998. Antes este script ponia "KURAMA" en ctx7: FALSO.
    # Ver PARCHES.md §8.4.
    ("ctx6", 0x0CF99A, 0x0D069A, "ITSUKI"), ("ctx7", 0x0D1E5A, 0x0D2C6A, "Toguro+"),
    ("ctx8", 0x0D4A9A, 0x0D59FA, "?"), ("ctx9", 0x0D777A, 0x0D85AA, "Toguro-"),
]


def w16(o):
    return (d[o] << 8) | d[o + 1]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


nctx = int(sys.argv[1])
mid = int(sys.argv[2])
nfr = int(sys.argv[3]) if len(sys.argv) > 3 else 12
nombre, base50, base8c, pj = CTX[nctx]

w = w16(base50 + mid * 2)
base = base50 + w
print("=== %s (%s) move ID %d ===" % (nombre, pj, mid))
print("registro base: $%06X   (vX byte = $%06X, vY byte = $%06X)"
      % (base, base + 6, base + 7))
print()

for frame in range(nfr):
    rec = base + frame * 8
    if rec + 7 >= len(d):
        break
    b1 = d[rec + 1]
    b0 = d[rec]
    sub = base8c + b1 * 4
    flags = d[sub]
    dur = d[sub + 1]
    boff = w16(sub + 2)
    blob = sub + boff
    if blob + 8 > len(d):
        break
    dmg, stn, psh, efec = d[blob], d[blob + 1], d[blob + 2], d[blob + 3]
    print("frame %2d  rec $%06X  b0(dur)=%3d  sub $%06X flags=$%02X dur=%3d  blob $%06X"
          % (frame, rec, b0, sub, flags, dur, blob))
    print("   cabecera: dano=%3d stun=%3d empuje=$%02X efecto=$%02X" % (dmg, stn, psh, efec))
    # cadena de cajas
    p = blob + 4
    cajas = []
    for k in range(8):
        if p + 4 > len(d):
            break
        rx = d[p]
        ox = d[p + 1]
        ry = d[p + 2]
        oy = d[p + 3]
        more = (rx >> 7) & 1
        cajas.append((p, rx & 0x7F, sx(ox), ry, sy(oy), more))
        p += 4
        if not more:
            break
    for i, (addr, rx, ox, ry, oy, more) in enumerate(cajas):
        print("   caja %d @ $%06X: radioX=%3d offX=%4d radioY=%3d offY=%4d  %s"
              % (i, addr, rx, ox, ry, oy, ("hay mas" if more else "ultima")))
    print()
