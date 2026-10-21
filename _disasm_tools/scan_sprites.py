#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Busca y renderiza los bloques de graficos de personajes en el ROM.

Criterio correcto (el que faltaba antes): en los tiles de sprite, el indice 0
es el FONDO y ocupa mucho, y los demas indices son pocos tonos de sombreado.
Los datos comprimidos, en cambio, reparten los 16 valores por igual.

Se mide por region (no por tile suelto) para no encadenar zonas vacias:
  - fraccion de indice 0 (fondo) alta y consistente
  - pocos tonos distintos
  - baja varianza entre tiles vecinos (los sprites comparten paleta)

Luego renderiza las mejores con indice 0 opaco.
"""
import sys
import os
import struct
import zlib
from collections import Counter

TILE = 32


def write_png(path, w, h, pix):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw += bytes(pix[y][x])

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def paleta():
    base = [(0x60, 0x38, 0x18), (0, 0, 0), (0, 0, 0xA0), (0xA0, 0x50, 0x20),
            (0xD0, 0xC0, 0x90), (0x80, 0x80, 0x30), (0x90, 0x30, 0x40),
            (0x30, 0x60, 0xC0), (0xE0, 0xD0, 0x20), (0x20, 0xC0, 0xC0),
            (0x60, 0x30, 0xA0), (0xE0, 0x40, 0xE0), (0x40, 0xC0, 0x40),
            (0x00, 0xE0, 0xE0), (0xF0, 0xA0, 0x80), (0x50, 0xE0, 0x50)]
    return [(r, g, b, 255) for r, g, b in base]


def stats_tile(t):
    h = Counter()
    for b in t:
        h[(b >> 4) & 0xF] += 1
        h[b & 0xF] += 1
    total = 16
    f0 = h.get(0, 0) / total
    usados = sum(1 for k in h if h[k] > 0)
    return f0, usados


def analizar_regiones(rom, paso_tiles=16):
    """mide bloques de 16 tiles (512 bytes) y puntua"""
    n = (len(rom)) // (paso_tiles * TILE)
    res = []
    for i in range(n):
        base = i * paso_tiles * TILE
        f0s = []
        usadoss = []
        for k in range(paso_tiles):
            f0, u = stats_tile(rom[base + k * TILE: base + (k + 1) * TILE])
            f0s.append(f0)
            usadoss.append(u)
        f0m = sum(f0s) / len(f0s)
        um = sum(usadoss) / len(usadoss)
        # varianza de f0: los sprites son consistentes, el ruido no
        var = sum((x - f0m) ** 2 for x in f0s) / len(f0s)
        # score: mucho fondo + pocos tonos + consistencia
        s = 0.0
        if f0m >= 0.35:
            s += 45 * min(1.0, (f0m - 0.35) / 0.35)
        if um <= 9:
            s += 35
        elif um <= 12:
            s += 18
        else:
            s += 0
        s += max(0.0, 20 - var * 100)
        res.append((s, base, f0m, um, var))
    return res


def agrupar(res, min_score, gap_tiles=64):
    res = sorted(res, key=lambda x: -x[0])
    buenas = [r for r in res if r[0] >= min_score]
    buenas.sort(key=lambda r: r[1])
    regiones = []
    for r in buenas:
        if not regiones:
            regiones.append([r[1], r[1] + 1])
        elif r[1] - regiones[-1][1] <= gap_tiles * TILE:
            regiones[-1][1] = max(regiones[-1][1], r[1] + 1)
        else:
            regiones.append([r[1], r[1] + 1])
    regiones.sort(key=lambda g: -(g[1] - g[0]))
    return regiones


def render(rom, off, largo, cols, pal, zoom=2):
    tiles = largo // TILE
    filas = (tiles + cols - 1) // cols
    w = cols * 8 * zoom
    h = filas * 8 * zoom
    img = [[(0, 0, 0, 255)] * w for _ in range(h)]
    for t in range(tiles):
        base = off + t * TILE
        if base + TILE > len(rom):
            break
        tx = (t % cols) * 8 * zoom
        ty = (t // cols) * 8 * zoom
        for y in range(8):
            for k in range(4):
                byte = rom[base + y * 4 + k]
                for n in range(2):
                    idx = (byte >> 4) & 0xF if n == 0 else byte & 0xF
                    x0 = tx + (k * 2 + n) * zoom
                    yy = ty + y * zoom
                    if x0 + zoom > w or yy + zoom > h:
                        continue
                    c = pal[idx]
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[yy + dy][x0 + dx] = (c[0], c[1], c[2], 255)
    return w, h, img


def main():
    rom = open(sys.argv[1], "rb").read()
    outdir = sys.argv[2] if len(sys.argv) > 2 else "scan_ok"
    max_reg = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    os.makedirs(outdir, exist_ok=True)
    print("ROM %d bytes" % len(rom))

    res = analizar_regiones(rom)
    regiones = agrupar(res, min_score=55)
    print("regiones con firma de sprite: %d" % len(regiones))
    pal = paleta()

    salidas = []
    for k, (ini, fin) in enumerate(regiones[:max_reg]):
        largo = min(fin - ini, 256 * TILE)
        w, h, img = render(rom, ini, largo, 16, pal)
        ruta = os.path.join(outdir, "s%02d_%06X.png" % (k, ini))
        write_png(ruta, w, h, img)
        salidas.append((ini, largo, ruta))
        print("  %-26s $%06X  %6d bytes  %4d tiles  %dx%d"
              % (os.path.basename(ruta), ini, largo, largo // TILE, w, h))

    with open(os.path.join(outdir, "indice.txt"), "w", encoding="utf-8") as f:
        for ini, largo, ruta in salidas:
            f.write("%s  offset $%06X  %d bytes\n" % (ruta, ini, largo))
    return 0


if __name__ == "__main__":
    sys.exit(main())