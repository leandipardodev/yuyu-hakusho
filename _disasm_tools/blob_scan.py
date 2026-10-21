# -*- coding: utf-8 -*-
"""
Herramienta: escanear los BLOBS de caja de los 11 personajes buscando
anomalias, en especial el rastro del parche "BLOB B 68=9".

Que es un blob: la cadena de cajas de un frame de move. La cabecera son
4 bytes (dano, stun, empuje, efecto) y luego N cajas de 4 bytes
(radioX, offX, radioY, offY). El bit 7 del radioX dice "hay mas cajas".

Criterios de anomalia:
  - radioX con el bit 7 puesto (vale 68-127) -> el radio real es < 128, OK
  - radioX == 0 con "hay mas" -> es legal (el terminador lo lleva el bit 7),
    pero si TODA la cadena tiene radio 0, la caja no colisiona nunca
  - radio > 127 imposible
  - la cadena no termina en 8 cajas
  - un radio exactamente 9 (el rastro del "68=9" del nombre del ROM)

Uso: python blob_scan.py
Salida: stdout. No modifica nada.
"""
import io
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


total_blob = 0
cadenas = 0
sin_cerrar = []
todo_cero = []
con_nueve = []
radios = {}
for nombre, base50, base8c, pj in CTX:
    for mid in range(0, 178):
        w = w16(base50 + mid * 2)
        if w == 0:
            continue
        dest = base50 + w
        for f in range(30):
            rec = dest + f * 8
            if rec + 7 >= len(d):
                break
            b1 = d[rec + 1]
            sub = base8c + b1 * 4
            if sub + 3 >= len(d):
                break
            flags = d[sub]
            if not (flags & 0x40):        # bit 6 = hay hitbox
                continue
            blob = sub + w16(sub + 2)
            if blob + 4 >= len(d):
                continue
            total_blob += 1
            p = blob + 4
            rxs = []
            cerrada = False
            for k in range(9):
                if p + 4 > len(d):
                    break
                rx = d[p]
                more = (rx >> 7) & 1
                rxs.append(rx & 0x7F)
                p += 4
                if not more:
                    cerrada = True
                    break
            if not cerrada:
                sin_cerrar.append((nombre, mid, f, blob, rxs))
            else:
                cadenas += 1
                if all(r == 0 for r in rxs):
                    todo_cero.append((nombre, mid, f, blob, rxs))
                for idx, r in enumerate(rxs):
                    radios[r] = radios.get(r, 0) + 1
                    if r == 9:
                        con_nueve.append((nombre, mid, f, blob, idx, rxs))

print("blobs con hitbox: %d   cadenas bien cerradas: %d" % (total_blob, cadenas))
print()
print("=== radios que aparecen (cuenta) ===")
for r in sorted(radios):
    print("   radio %3d : %d" % (r, radios[r]))
print()
print("=== cajas con radio exactamente 9 (rastro del '68=9') ===")
if not con_nueve:
    print("   (ninguna)")
for c in con_nueve[:20]:
    print("   %s id=%3d frame=%2d blob=$%06X caja %d de %s" %
          (c[0], c[1], c[2], c[3], c[4], c[5]))
print()
print("=== cadenas que NO se cierran (posible dato corrupto) ===")
if not sin_cerrar:
    print("   (ninguna)")
for c in sin_cerrar[:20]:
    print("   %s id=%3d frame=%2d blob=$%06X  radios=%s" % (c[0], c[1], c[2], c[3], c[4]))
print()
print("=== cadenas con TODAS las cajas de radio 0 (nunca colisionan) ===")
if not todo_cero:
    print("   (ninguna)")
for c in todo_cero[:20]:
    print("   %s id=%3d frame=%2d blob=$%06X  radios=%s" % (c[0], c[1], c[2], c[3], c[4]))
