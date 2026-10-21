# -*- coding: utf-8 -*-
"""
Herramienta: escanear el ROM entero buscando los SETUPS DE OBJETO de cada
personaje, y sacar de cada uno su move ID, su velocidad X y su velocidad Y.

Por que: el desensamblado tiene huecos y casi todos los setups de objeto
estan dentro de ellos, asi que el .asm no los muestra. Los patrones son
inequivocos (68k, big endian):

  move.l #$01XXXX, $90(a0)   -> 21 7C 00 01 XX XX 00 90
  move.l #$XXXXXXXX, $10(a0) -> 21 7C XX XX XX XX 00 10   (velocidad X)
  move.l #$XXXXXXXX, $14(a0) -> 21 7C XX XX XX XX 00 14   (velocidad Y)
  move.b  #$XX, $5f(a0)      -> 11 7C 00 XX 00 5F         (move ID del objeto)

Las tablas $90 por ctx (las del personaje):
  ctx0 $01251E  ctx1 $01253C  ctx2 $01255A  ctx3 $012578  ctx4 $0125B4
  ctx5 $0125D2  ctx6 $0125F0  ctx7 $01260E  ctx8 $01262C  ctx9 $01264A

Uso: python obj_scan.py
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


def buscar(pat, desde=0):
    res = []
    i = desde
    n = len(d)
    while True:
        j = d.find(pat, i)
        if j < 0:
            break
        res.append(j)
        i = j + 1
    return res


def f16(v):
    s = v - 0x100000000 if v >= 0x80000000 else v
    return "%+7.4f" % (s / 65536.0)


print("=== SETUPS DE OBJETO POR PERSONAJE (move.l #$01XXXX, $90(a0)) ===")
print()
print("  addr     ctx             moveID   velX 16.16      velY 16.16     dir byte del velX")
print("  " + "-" * 100)

hits = buscar(bytes([0x21, 0x7C, 0x00, 0x01]))
n = 0
for h in hits:
    if h + 8 > len(d):
        continue
    if d[h + 6] != 0x00 or d[h + 7] != 0x90:
        continue
    val = int.from_bytes(d[h + 2:h + 6], "big")
    ctx = CTX90.get(val, "? $%06X" % val)
    # move ID del objeto (11 7C 00 XX 00 5F) en los siguientes 0x60 bytes
    mid = None
    for k in range(h, min(h + 0x60, len(d) - 5)):
        if d[k] == 0x11 and d[k + 1] == 0x7C and d[k + 3] == 0x00 and d[k + 4] == 0x5F:
            mid = d[k + 2]
            break
    # velocidad X: 21 7C XX XX XX XX 00 10
    vx = vx_addr = None
    for k in range(h, min(h + 0x60, len(d) - 8)):
        if (d[k] == 0x21 and d[k + 1] == 0x7C and d[k + 6] == 0x00 and d[k + 7] == 0x10):
            vx = int.from_bytes(d[k + 2:k + 6], "big")
            vx_addr = k + 2
            break
    vy = vy_addr = None
    for k in range(h, min(h + 0x60, len(d) - 8)):
        if (d[k] == 0x21 and d[k + 1] == 0x7C and d[k + 6] == 0x00 and d[k + 7] == 0x14):
            vy = int.from_bytes(d[k + 2:k + 6], "big")
            vy_addr = k + 2
            break
    print("  0x%06X  %-14s %s  %s  %s   %s" % (
        h, ctx,
        ("ID %3d" % mid) if mid is not None else "  ?  ",
        f16(vx) if vx is not None else "    ?   ",
        f16(vy) if vy is not None else "    ?   ",
        ("$%06X" % vx_addr) if vx_addr else ""))
    n += 1
print()
print("  total: %d" % n)

print()
print("=== TODAS las velocidades de objeto (move.l #$XXXXXXXX, $10(a0)) ===")
for h in buscar(bytes([0x21, 0x7C])):
    if h + 8 > len(d):
        continue
    if d[h + 6] != 0x00 or d[h + 7] != 0x10:
        continue
    v = int.from_bytes(d[h + 2:h + 6], "big")
    print("  0x%06X   $%08X  = %+8.4f px/frame" % (h + 2, v, f16(v)))
