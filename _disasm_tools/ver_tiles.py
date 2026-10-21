#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Renderiza tiles 4bpp (o 2bpp) SIN transparencia.

Correccion importante: en este juego el indice 0 NO es transparente, es un
color real (el fondo del sprite). Tratarlo como transparente deja en blanco
la mitad de cada tile y el resultado parece ruido, que es lo que pasaba.

    python ver_tiles.py <rom> <offset> <bytes> <salida.png> [4bpp|2bpp] [cols]
"""
import sys
import struct
import zlib

# rampa que se parece a la paleta por defecto de TileMolester en la captura:
# indice 1 = negro (dominante), y tonos，之后 progresivos
def paleta():
    p = []
    base = [
        (0x60, 0x38, 0x18),   # 0  marron oscuro (fondo)
        (0x00, 0x00, 0x00),   # 1  negro
        (0x00, 0x00, 0xA0),   # 2  azul
        (0xA0, 0x50, 0x20),   # 3  marron
        (0xD0, 0xC0, 0x90),   # 4  beige
        (0x80, 0x80, 0x30),   # 5  oliva
        (0x90, 0x30, 0x40),   # 6  rojo oscuro
        (0x30, 0x60, 0xC0),   # 7  azul claro
        (0xE0, 0xD0, 0x20),   # 8  amarillo
        (0x20, 0xC0, 0xC0),   # 9  turquesa
        (0x60, 0x30, 0xA0),   # 10 violeta
        (0xE0, 0x40, 0xE0),   # 11 magenta
        (0x40, 0xC0, 0x40),   # 12 verde
        (0x00, 0xE0, 0xE0),   # 13 cian
        (0xF0, 0xA0, 0x80),   # 14 salmon
        (0x50, 0xE0, 0x50),   # 15 verde claro
    ]
    for r, g, b in base:
        p.append((r, g, b, 255))
    return p


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


def main():
    rom = open(sys.argv[1], "rb").read()
    off = int(sys.argv[2], 0)
    largo = int(sys.argv[3], 0)
    salida = sys.argv[4]
    modo = sys.argv[5] if len(sys.argv) > 5 else "4bpp"
    cols = int(sys.argv[6]) if len(sys.argv) > 6 else 16

    if modo == "4bpp":
        tbytes, bpf, mask = 32, 4, 0xF
    else:
        tbytes, bpf, mask = 16, 2, 0x3

    pal = paleta()
    zoom = 2
    tiles = largo // tbytes
    filas = (tiles + cols - 1) // cols
    w = cols * 8 * zoom
    h = filas * 8 * zoom
    img = [[(0, 0, 0, 255)] * w for _ in range(h)]

    for t in range(tiles):
        base = off + t * tbytes
        if base + tbytes > len(rom):
            break
        tx = (t % cols) * 8 * zoom
        ty = (t // cols) * 8 * zoom
        for y in range(8):
            for k in range(bpf):
                byte = rom[base + y * bpf + k]
                for n in range(2):
                    idx = ((byte >> 4) & mask) if n == 0 else (byte & mask)
                    x0 = tx + (k * 2 + n) * zoom
                    yy = ty + y * zoom
                    if x0 + zoom > w or yy + zoom > h:
                        continue
                    c = pal[idx] if idx < len(pal) else (255, 0, 255, 255)
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[yy + dy][x0 + dx] = (c[0], c[1], c[2], 255)

    write_png(salida, w, h, img)
    print("%s  %s  offset $%06X  %d tiles  %dx%d" % (salida, modo, off, tiles, w, h))
    return 0


if __name__ == "__main__":
    sys.exit(main())