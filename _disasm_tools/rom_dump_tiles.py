#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Renderiza el ROM entero como tiles 4bpp linear, en hojas manejables.

Equivalente a lo que hace TileMolester al abrir un ROM, pero automatico:
en vez de ir buscando a mano, se dibuja todo y se miran las hojas.

Hoja de 64x64 tiles = 4096 tiles = 128 KB de ROM. Un ROM de 3 MB sale en
~24 hojas, que es lo que una persona revisaria de un vistazo.

    python rom_dump_tiles.py <rom> <carpeta_salida> [tiles_por_lado] [zoom]
"""
import sys
import os
import struct
import zlib

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
    """0 transparente (azul oscuro de fondo), 1..15 rampa de gris"""
    p = [(10, 10, 30, 255)]
    for i in range(1, 16):
        v = 30 + int((i - 1) * (225 / 14))
        p.append((v, v, v, 255))
    return p


def main():
    rom = open(sys.argv[1], "rb").read()
    outdir = sys.argv[2] if len(sys.argv) > 2 else "rom_tiles"
    lado = int(sys.argv[3]) if len(sys.argv) > 3 else 64
    zoom = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    os.makedirs(outdir, exist_ok=True)

    tiles_por_hoja = lado * lado
    bytes_por_hoja = tiles_por_hoja * TILE
    hojas = (len(rom) + bytes_por_hoja - 1) // bytes_por_hoja
    pal = paleta()
    w = lado * 8 * zoom
    h = lado * 8 * zoom

    print("ROM %d bytes -> %d hojas de %dx%d (%d KB cada una)"
          % (len(rom), hojas, w, h, bytes_por_hoja // 1024))

    for k in range(hojas):
        base = k * bytes_por_hoja
        img = [[(0, 0, 0, 0)] * w for _ in range(h)]
        for i in range(tiles_por_hoja):
            off = base + i * TILE
            if off + TILE > len(rom):
                break
            tx = (i % lado) * 8 * zoom
            ty = (i // lado) * 8 * zoom
            for y in range(8):
                row = off + y * 4
                for b in range(4):
                    byte = rom[row + b]
                    x0 = tx + (b * 2) * zoom
                    hi = (byte >> 4) & 0xF
                    lo = byte & 0xF
                    yy = ty + y * zoom
                    if yy + zoom > h or x0 + zoom > w:
                        continue
                    c = pal[hi]
                    for dy in range(zoom):
                        for dx in range(zoom):
                            if hi:
                                img[yy + dy][x0 + dx] = (c[0], c[1], c[2], 255)
                    c2 = pal[lo]
                    x1 = x0 + zoom
                    if lo:
                        for dy in range(zoom):
                            for dx in range(zoom):
                                if x1 + dx < w:
                                    img[yy + dy][x1 + dx] = (c2[0], c2[1], c2[2], 255)
        ruta = os.path.join(outdir, "hoja%02d_%06X.png" % (k, base))
        write_png(ruta, w, h, img)
        print("  %-26s  ROM $%06X - $%06X" % (os.path.basename(ruta), base,
                                             min(len(rom), base + bytes_por_hoja)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
