# -*- coding: utf-8 -*-
"""
Herramienta: escanear el ROM entero buscando TODOS los setups de objeto
y sus parametros, sin filtrar por nada.

Motivo: el desensamblado tiene huecos y los setups de objeto (que son lo
que define la vida de un proyectil: move ID, tabla $90 del personaje,
velocidad) viven casi todos dentro de esos huecos.

Patrones 68k (big endian):
  move.l #$01XXXX, $90(a0)   21 7C 00 01 XX XX 00 90   (tabla $90 del personaje)
  move.b #$XX, $5f(a0)       11 7C 00 XX 00 5F         (move ID del objeto)
  move.l #$XXXXXXXX, $10(a0) 21 7C XX XX XX XX 00 10   (velocidad X)
  move.l #$XXXXXXXX, $14(a0) 21 7C XX XX XX XX 00 14   (velocidad Y)
  move.l #$XXXXXXXX, $50(a0) 21 7C XX XX XX XX 00 50   (tabla de moves)
  move.l #$XXXXXXXX, $8c(a0) 21 7C XX XX XX XX 00 8C   (sub-lista)

Uso: python obj_scan2.py
Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

d = open(ruta_rom(), "rb").read()

CTX90 = {
    0x01251E: "ctx0", 0x01253C: "ctx1", 0x01255A: "ctx2", 0x012578: "ctx3 HIEI",
    0x0125B4: "ctx4", 0x0125D2: "ctx5", 0x0125F0: "ctx6 ITSUKI",
    0x01260E: "ctx7", 0x01262C: "ctx8", 0x01264A: "ctx9",
}


def todos(pat):
    res = []
    i = 0
    while True:
        j = d.find(pat, i)
        if j < 0:
            break
        res.append(j)
        i = j + 1
    return res


def f16(v):
    s = v - 0x100000000 if v >= 0x80000000 else v
    return "%+8.4f" % (s / 65536.0)


print("=== A) move.l #$01XXXX, $90(a0)  (tabla $90 del personaje en el objeto) ===")
print("  addr     valor      personaje")
for h in todos(bytes([0x21, 0x7C, 0x00, 0x01])):
    if h + 8 > len(d):
        continue
    if d[h + 6] != 0x00 or d[h + 7] != 0x90:
        continue
    v = int.from_bytes(d[h + 2:h + 6], "big")
    print("  0x%06X  $%08X  %s" % (h, v, CTX90.get(v, "")))

print()
print("=== B) move.b #$XX, $5f(a0)  (move ID del objeto) ===")
for h in todos(bytes([0x11, 0x7C, 0x00])):
    if h + 5 > len(d):
        continue
    if d[h + 3] != 0x00 or d[h + 4] != 0x5F:
        continue
    # buscar el $90(a0) mas cercano (hacia atras) para saber de quien es
    ctx = "?"
    for k in range(h, max(0, h - 0x60), -1):
        if d[k] == 0x21 and d[k + 1] == 0x7C and d[k + 2] == 0x00 and d[k + 3] == 0x01 \
                and d[k + 6] == 0x00 and d[k + 7] == 0x90:
            v = int.from_bytes(d[k + 2:k + 6], "big")
            ctx = CTX90.get(v, "$%06X" % v)
            break
    # velocidad X mas cercana hacia adelante
    vx = None
    for k in range(h, min(h + 0x60, len(d) - 8)):
        if d[k] == 0x21 and d[k + 1] == 0x7C and d[k + 6] == 0x00 and d[k + 7] == 0x10:
            vx = int.from_bytes(d[k + 2:k + 6], "big")
            break
    print("  0x%06X  ID %3d  ctx=%-14s velX=%s" % (
        h, d[h + 2], ctx, ("%s  (literal @0x%06X)" % (f16(vx), h)) if vx is not None else "?"))

print()
print("=== C) move.l #$XXXXXXXX, $8c(a0)  (sub-lista del objeto) ===")
for h in todos(bytes([0x21, 0x7C])):
    if h + 8 > len(d):
        continue
    if d[h + 6] != 0x00 or d[h + 7] != 0x8C:
        continue
    v = int.from_bytes(d[h + 2:h + 6], "big")
    print("  0x%06X  $%08X" % (h + 2, v))

print()
print("=== D) move.l #$XXXXXXXX, $50(a0)  (tabla de moves del objeto) ===")
for h in todos(bytes([0x21, 0x7C])):
    if h + 8 > len(d):
        continue
    if d[h + 6] != 0x00 or d[h + 7] != 0x50:
        continue
    v = int.from_bytes(d[h + 2:h + 6], "big")
    print("  0x%06X  $%08X" % (h + 2, v))
