# -*- coding: utf-8 -*-
"""
Herramienta: volcar la tabla de moves de un OBJETO (no de un personaje).

Los objetos (proyectiles, ondas, manos flotantes...) NO usan la tabla del
personaje: su handler escribe un puntero propio en $50(a5). Por ejemplo
el handler de $58=$10 (el que usa la rutina 0x1FCE8) pone
$50(a5) = $14DDC.

Ademas, la tabla de handlers de objeto esta en $14A00: cada entrada (de 2
bytes, offset relativo) es un handler, y cada handler define su propia
tabla de moves ($50), su grafico ($1C) y sus flags ($24).

Este script:
  1. Vuelca la tabla de handlers $14A00 con su $50, $1C y $24.
  2. Vuelca la tabla de moves de un objeto (indice + registros + blobs).

Uso:
  python blob_obj.py                 # tabla de handlers
  python blob_obj.py $14DDC          # moves de un objeto
  python blob_obj.py --ctx 6 38      # moves de un personaje (ctx, id)

Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

d = open(ruta_rom(), "rb").read()

CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA), ("ctx1", 0x0C229A, 0x0C31DA),
    ("ctx2", 0x0C4EEA, 0x0C5DAA), ("ctx3", 0x0C7C9A, 0x0C8BEA),
    ("ctx4", 0x0CA6DA, 0x0CB38A), ("ctx5", 0x0CCC7A, 0x0CDEFA),
    ("ctx6", 0x0CF99A, 0x0D069A), ("ctx7", 0x0D1E5A, 0x0D2C6A),
    ("ctx8", 0x0D4A9A, 0x0D59FA), ("ctx9", 0x0D777A, 0x0D85AA),
]


def w16(o):
    return (d[o] << 8) | d[o + 1]


def w32(o):
    return (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def volcar_moves(base50, base8c, etiqueta, nids=64):
    print("=== %s : moves  base50=$%06X  base8c=$%06X ===" % (etiqueta, base50, base8c))
    print("id   destino   b0  b1  b2  b3  b4  b5   vX   vY | flg dur | DANO STUN EMP  rX  rY | blob")
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
        if b[0] == 0 and b[1] == 0 and b[2] == 0x80:
            continue
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
        print("%3d  $%06X  %3d %3d  %02X  %02X  %02X  %02X %4d %4d |  %02X %3d | %4d %4d $%02X %3d %3d | $%06X"
              % (mid, dest, b[0], b[1], b[2], b[3], b[4], b[5],
                 sx(b[6]), sy(b[7]), flags, dur, dmg, stn, psh, rx, ry, blob))


def tabla_handlers():
    print("=== tabla de handlers de objeto: $14A00 (offset relativo de 2 bytes) ===")
    print("  $58  ->  handler   $50(a5)  $1C(a5)   flags $24")
    for i in range(0, 48, 2):
        h = 0x14A00 + i + w16(0x14A00 + i)
        if h >= len(d) - 8:
            break
        m50 = m1c = None
        fl = None
        for k in range(h, min(h + 40, len(d) - 8)):
            w = w32(k)
            if (w & 0xFFFF0000) == 0x00000000 and False:
                pass
            if 0x14D00 <= w <= 0x16000 and m50 is None:
                m50 = w
            if 0x20000 <= w <= 0x30000 and m1c is None:
                m1c = w
        # flags: ori.w #$xx, $24(a5)  ->  48 7C 00 24
        for k in range(h, min(h + 40, len(d) - 4)):
            if d[k] == 0x48 and d[k + 1] == 0x7C and d[k + 2] == 0x00 and d[k + 3] == 0x24:
                fl = w16(k + 4)
                break
        print("  %3d  ->  $%06X   %s  %s  %s"
              % (i // 2, h, ("$%06X" % m50) if m50 else "   ?   ",
                 ("$%06X" % m1c) if m1c else "   ?   ",
                 ("$%04X" % fl) if fl is not None else " ? "))


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] == "--handlers":
        tabla_handlers()
    elif a[0] == "--ctx":
        n = int(a[1])
        mid = int(a[2])
        nombre, b50, b8c = CTX[n]
        w = w16(b50 + mid * 2)
        volcar_moves(b50 + w, b8c, "%s move %d" % (nombre, mid), 40)
    else:
        base = int(a[0], 16)
        # la sub-lista de un objeto suele estar cerca; la buscamos por el
        # patron "flags=0x40" en las entradas de 4 bytes
        print("=== moves del objeto con base50 $%06X ===" % base)
        for cand in range(base, base + 0x3000, 4):
            if cand + 4 > len(d):
                break
            if d[cand] == 0x40 and d[cand + 1] < 0x40:
                sub = cand
                volcar_moves(base, sub, "objeto base50=$%06X  sub=$%06X" % (base, sub), 48)
                break
        else:
            print("  (no se encontro la sub-lista automaticamente)")
