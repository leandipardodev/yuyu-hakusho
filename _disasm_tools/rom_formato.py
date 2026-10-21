#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Renderiza una region del ROM como tiles de 4bpp (32 B) o de 2bpp (16 B).

Se prueban los dos formatos porque asumir el equivocado convierte cualquier
grafico en ruido, que es justo lo que pasaba.

    python rom_formato.py <rom> <offset_hex> <bytes> <4bpp|2bpp> <salida.png>
"""
import sys
import struct
import zlib


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
        v = 25 + int((i - 1) * (230 / 14))
        p.append((v, v, v, 255))
    return p


def main():
    rom = open(sys.argv[1], "rb").read()
    off = int(sys.argv[2], 0)
    largo = int(sys.argv[3], 0)
    modo = sys.argv[4]
    salida = sys.argv[5]

    tbytes = 32 if modo == "4bpp" else 16
    por_fila = 2 if modo == "4bpp" else 1
    bpr = 8 if modo == "4bpp" else 4
    pal = paleta()
    zoom = 2
    lado = 32
    tiles = largo // tbytes
    filas_t = (tiles + lado - 1) // lado
    w = lado * 8 * zoom
    h = filas_t * 8 * zoom
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]

    for i in range(tiles):
        t = off + i * tbytes
        if t + tbytes > len(rom):
            break
        tx = (i % lado) * 8 * zoom
        ty = (i // lado) * 8 * zoom
        for y in range(8):
            for k in range(bpr):
                byte = rom[t + y * bpr + k]
                for n in range(2):
                    if por_fila == 1:
                        idx = (byte >> 4) & 0xF if n == 0 else byte & 0xF
                    else:
                        idx = (byte >> 4) & 0xF if n == 0 else byte & 0xF
                    x0 = tx + (k * 2 + n) * zoom
                    yy = ty + y * zoom
                    if not idx or x0 + zoom > w or yy + zoom > h:
                        continue
                    c = pal[idx]
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[yy + dy][x0 + dx] = (c[0], c[1], c[2], 255)

    write_png(salida, w, h, img)
    print("%s : %d tiles, %dx%d -> %s" % (modo, tiles, w, h, salida))
    return 0


if __name__ == "__main__":
    sys.exit(main())
