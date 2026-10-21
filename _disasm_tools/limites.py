# -*- coding: utf-8 -*-
"""
Determina el limite REAL de cada tabla de moves.

Criterio: la tabla indice de $50(a5) es una secuencia de palabras; cada palabra
w cumple  destino = base + w  y debe caer dentro de la region del contexto
(base .. base del contexto siguiente). Se recounta cuantas entradas seguidas
cumplen eso, y ese es el numero de moves del contexto.
"""
import struct

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()

CTX = [
    ("ctx0", 0x0BF75A), ("ctx1", 0x0C229A), ("ctx2", 0x0C4EEA), ("ctx3", 0x0C7C9A),
    ("ctx4", 0x0CA6DA), ("ctx5", 0x0CCC7A), ("ctx6", 0x0CF99A), ("ctx7", 0x0D1E5A),
    ("ctx8", 0x0D4A9A), ("ctx9", 0x0D777A),
]

print("ctx  | base      | moves validos | primer destino | ultimo destino | tamano datos")
print("-" * 82)

filas = []
for k, (nombre, base) in enumerate(CTX):
    tope = CTX[k + 1][1] if k + 1 < len(CTX) else len(d)
    dests = []
    mid = 0
    while True:
        slot = base + mid * 2
        if slot + 2 > tope:
            break
        w = struct.unpack(">H", d[slot:slot + 2])[0]
        dest = base + w
        # valido: dentro de la region del contexto.
        # La alineacion a 8 es RELATIVA a la base (que no esta alineada),
        # asi que no se exige alineacion absoluta.
        if not (base <= dest < tope):
            break
        r = d[dest:dest + 8]
        if len(r) < 8:
            break
        dests.append(dest)
        mid += 1
        if mid > 400:
            break
    if not dests:
        print("%-4s | $%06X  |      0        |" % (nombre, base))
        continue
    tam = (max(dests) - min(dests)) + 8
    print("%-4s | $%06X  |     %3d       | $%06X        | $%06X        | $%04X (%d)"
          % (nombre, base, len(dests), min(dests), max(dests), tam, tam // 8))
    filas.append((nombre, base, len(dests), min(dests), max(dests)))

print()
print("=== interpretacion ===")
tot = sum(f[2] for f in filas)
print("total de entradas validas: %d" % tot)
print()
for nombre, base, n, ini, fin in filas:
    print("  %-4s  %3d moves   datos $%06X-$%06X" % (nombre, n, ini, fin))

with open("LIMITES_TABLAS.txt", "w", encoding="utf-8") as f:
    for nombre, base, n, ini, fin in filas:
        f.write("%s base=$%06X moves=%d datos=$%06X-$%06X\n" % (nombre, base, n, ini, fin))
print()
print("guardado en LIMITES_TABLAS.txt")
