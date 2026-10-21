# -*- coding: utf-8 -*-
"""
Volcado FINAL de las tablas de moves por contexto.

Aritmetica (0x1EB40):  destino = BASE + palabra[BASE + id*2]
Los registros miden 8 bytes y son contiguos. Se recorren desde el primer
destino hasta el comienzo del contexto siguiente.
"""
import struct
import sys

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


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


salida = []
todos = []
print("%-5s %-8s %5s %5s %6s %5s %5s" % ("ctx", "destino", "prio", "sub", "flags", "cmd", "vX/vY"))
print("-" * 52)

for k, (nombre, base) in enumerate(CTX):
    primero = base + struct.unpack(">H", d[base:base + 2])[0]
    # limite: el comienzo del contexto siguiente (o +0x2000)
    fin = CTX[k + 1][1] if k + 1 < len(CTX) else primero + 0x4000
    n = (fin - primero) // 8
    if n > 220:
        n = 220
    print()
    print("### %s   base=$%06X  datos desde $%06X   %d registros" % (nombre, base, primero, n))
    for i in range(n):
        o = primero + i * 8
        r = d[o:o + 8]
        vx, vy = sx(r[6]), sy(r[7])
        print("  %-5s $%06X  %5d %5d  $%02X   $%02X  %4d/%4d"
              % ("", o, r[0], r[1], r[2], r[3], vx, vy))
        todos.append((nombre, i, o, r[0], r[1], r[2], r[3], vx, vy))

print()
print("=== TOTAL de registros: %d ===" % len(todos))
xs = [t[7] for t in todos]
ys = [t[8] for t in todos]
print("vX global: %d .. %d" % (min(xs), max(xs)))
print("vY global: %d .. %d" % (min(ys), max(ys)))
cmds = sorted(set(t[6] for t in todos))
print("comandos distintos (%d): %s" % (len(cmds), " ".join("$%02X" % c for c in cmds)))
with open("TABLAS_MOVES.txt", "w", encoding="utf-8") as f:
    for t in todos:
        f.write("%s %d $%06X prio=%d sub=%d flags=$%02X cmd=$%02X vX=%d vY=%d\n" % t)
print("guardado en TABLAS_MOVES.txt")
