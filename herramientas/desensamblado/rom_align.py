#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Busca bloques de tiles 4bpp en el ROM probando TODOS los desplazamientos.

Por que: los tiles no tienen por que empezar en una direccion multiplo de 32.
TileMolester permite fijar una direccion base; si los graficos empiezan en
0x0C1000 y uno mira desde 0, cada tile sale desfasado y parece ruido. Eso era
justo lo que pasaba en los escaneos anteriores: todos alineados a 0.

Un tile real de sprite usa pocos tonos y tiene un color dominante. Los datos
comprimidos usan los 16 valores por igual. Se puntua eso, por cada
desplazamiento, y se informa el mejor.

    python rom_align.py <rom> [carpeta_salida]
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
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 6))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def paleta():
    p = [(8, 8, 24, 255)]
    for i in range(1, 16):
        v = 30 + int((i - 1) * (225 / 14))
        p.append((v, v, v, 255))
    return p


def score_tile(t):
    """0-100: cuanto parece un tile de sprite dibujado"""
    vals = []
    for b in t:
        vals.append((b >> 4) & 0xF)
        vals.append(b & 0xF)
    hist = Counter(vals)
    nz = sum(v for k, v in hist.items() if k != 0)
    if nz < 12:
        return 0
    usados = sum(1 for k in hist if k != 0)
    dominante = max(hist[k] for k in hist if k != 0) / nz
    s = 0.0
    if usados <= 5:
        s += 60
    elif usados <= 7:
        s += 45
    elif usados <= 9:
        s += 28
    elif usados <= 12:
        s += 10
    if dominante > 0.5:
        s += 30
    elif dominante > 0.35:
        s += 20
    elif dominante > 0.25:
        s += 8
    frac = nz / 16.0
    if 0.4 <= frac <= 1.0:
        s += 10
    return s


def analizar(rom, off):
    n = (len(rom) - off) // TILE
    if n <= 0:
        return 0, 0
    flags = bytearray(n)
    suma = 0
    for i in range(n):
        s = score_tile(rom[off + i * TILE: off + i * TILE + TILE])
        suma += s
        flags[i] = 1 if s >= 60 else 0
    # mejor racha de tiles buenos
    mejor = (0, 0, 0)
    i = 0
    while i < n:
        if flags[i]:
            j = i
            while j < n and flags[j]:
                j += 1
            if (j - i) > mejor[2]:
                mejor = (off + i * TILE, j - i, j - i)
            i = j
        else:
            i += 1
    return suma / n, mejor


def hoja(rom, off, tiles, lado, zoom=2):
    filas = (tiles + lado - 1) // lado
    w = lado * 8 * zoom
    h = filas * 8 * zoom
    pal = paleta()
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]
    for i in range(tiles):
        t = off + i * TILE
        if t + TILE > len(rom):
            break
        tx = (i % lado) * 8 * zoom
        ty = (i // lado) * 8 * zoom
        for y in range(8):
            for k in range(4):
                byte = rom[t + y * 4 + k]
                for n in range(2):
                    idx = (byte >> 4) & 0xF if n == 0 else byte & 0xF
                    x0 = tx + (k * 2 + n) * zoom
                    yy = ty + y * zoom
                    if not idx or x0 + zoom > w or yy + zoom > h:
                        continue
                    c = pal[idx]
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[yy + dy][x0 + dx] = (c[0], c[1], c[2], 255)
    return w, h, img


def main():
    rom = open(sys.argv[1], "rb").read()
    outdir = sys.argv[2] if len(sys.argv) > 2 else "align"
    os.makedirs(outdir, exist_ok=True)
    print("ROM %d bytes" % len(rom))

    res = []
    for off in range(TILE):
        media, mejor = analizar(rom, off)
        res.append((media, off, mejor))
    res.sort(reverse=True)

    print()
    print("desplazamiento | nota media | mejor racha")
    for media, off, mejor in res[:12]:
        print("   %2d          |  %6.1f     | $%06X  %d tiles (%d bytes)"
              % (off, media, mejor[0], mejor[2], mejor[2] * TILE))

    # renderiza la mejor racha larga encontrada
    cands = [(m[2][0], m[2][2]) for m in res]   # (inicio, n_tiles)
    cands.sort(key=lambda x: -x[1])
    pal_ok = 0
    for k, (inicio, nt) in enumerate(cands[:6]):
        if nt < 64:
            continue
        w, h, img = hoja(rom, inicio, nt, 16)
        ruta = os.path.join(outdir, "align%02d_%06X.png" % (inicio % 32, inicio))
        write_png(ruta, w, h, img)
        print("  %-30s desde $%06X, %d tiles (%dx%d)"
              % (os.path.basename(ruta), inicio, nt, w, h))
        pal_ok += 1
        if pal_ok >= 4:
            break
    return 0


if __name__ == "__main__":
    sys.exit(main())