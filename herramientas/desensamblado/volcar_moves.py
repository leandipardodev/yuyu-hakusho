# -*- coding: utf-8 -*-
"""
Volcado DEFINITIVO de la lista de moves: 195 entradas por contexto.

Registro de 8 bytes (leido por 0x1EB5A):
    b0  -> $5A(a5)  byte de estado/prioridad
    b1  -> indice de sublista (x4 en la tabla $8C)
    b2  -> $5C(a5)  banderas
    b3  -> or.b $6D(a5) -> $6C(a5)  = campo de bits de subsistemas
          bit0 -> $15CB0 | bit1 -> $15DE6 | bit2 -> $15E28
          bit3 -> $15EFE | bit4 -> $15F24
    b4  -> indice en la tabla $218D8
    b5  -> sin uso observado
    b6  -> velocidad X  (se resta $80)
    b7  -> velocidad Y  (se resta $A0)
"""
import struct

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()

CTX = [
    ("ctx0", 0x0BF75A), ("ctx1", 0x0C229A), ("ctx2", 0x0C4EEA), ("ctx3", 0x0C7C9A),
    ("ctx4", 0x0CA6DA), ("ctx5", 0x0CCC7A), ("ctx6", 0x0CF99A), ("ctx7", 0x0D1E5A),
    ("ctx8", 0x0D4A9A), ("ctx9", 0x0D777A),
]
N_MOVES = 195

BITS = {0: "b0", 1: "b1", 2: "b2", 3: "F3($15EFE)", 4: "F4($15F24)",
        5: "b5", 6: "b6", 7: "b7"}


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def banderas(v):
    s = "+".join(BITS[i] for i in range(8) if v & (1 << i))
    return s if s else "-"


lineas = []
totales = []
for nombre, base in CTX:
    filas = []
    for mid in range(N_MOVES):
        w = struct.unpack(">H", d[base + mid * 2:base + mid * 2 + 2])[0]
        dest = base + w
        r = d[dest:dest + 8]
        filas.append((mid, dest, r[0], r[1], r[2], r[3], r[4], r[5], sx(r[6]), sy(r[7])))
    filas.sort(key=lambda f: f[1])
    for f in filas:
        lineas.append("%s %3d $%06X %3d %4d $%02X $%02X $%02X %02X %5d %5d"
                      % (nombre, f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9]))
    totales.append((nombre, filas))

with open("volcado_moves.txt", "w", encoding="utf-8") as f:
    f.write("# Lista de moves del ROM - Yu Yu Hakusho Makyou Toitsusen\n")
    f.write("# %d entradas por contexto, registro de 8 bytes\n" % N_MOVES)
    f.write("# ctx idx destino   b0    b1  flg  b3  b4  b5    vX    vY\n")
    f.write("\n".join(lineas))

print("=== resumen por contexto ===")
print("ctx  | moves | vX min..max | vY min..max | sub-indice max | flags distintos")
for nombre, filas in totales:
    xs = [f[8] for f in filas]
    ys = [f[9] for f in filas]
    subs = [f[3] for f in filas]
    fl = sorted(set(f[4] for f in filas))
    print("%-4s | %5d | %4d .. %-4d | %4d .. %-4d | %13d | %s"
          % (nombre, len(filas), min(xs), max(xs), min(ys), max(ys),
             max(subs), " ".join("$%02X" % x for x in fl)))
print()
print("total de moves extraidos: %d" % len(lineas))
print("guardado en volcado_moves.txt")

# ejemplo imprimible de un personaje
print()
print("=== ejemplo: ctx0, 20 primeros moves por direccion ===")
for f in totales[0][1][:20]:
    print("  idx %3d  $%06X  prio=%-3d sub=%-4d %-22s cmd=$%02X  vX=%4d vY=%4d"
          % (f[0], f[1], f[2], f[3], banderas(f[5]), f[5], f[8], f[9]))
