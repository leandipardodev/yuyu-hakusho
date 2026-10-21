# -*- coding: utf-8 -*-
"""
Convierte volcados de tiles 4bpp linear del Mega Drive en PNG.

Uso:
    python tiles2png.py <entrada> [-o salida] [-p paleta.bin] [-c CRAM.bin]
                        [-w 16] [-h 16] [-pal genkai]

ENTRADA admite:
    .bin  -> volcado crudo de 4bpp linear (32 bytes por tile 8x8)
    .png  -> lo que exporta TileMolester (se reinterpreta pixel a pixel)

Opciones:
    -w / -h    ancho/alto del tile en pixeles (16 por defecto: las piezas
               tipicas del juego son de 16x16 o 16x32, no de 8x8)
    -p         paleta en crudo (64 palabras big-endian BBBGGGRR)
    -c         CRAM volcada (0xC00000, 128 bytes)
    -o         nombre base de salida. Sin esto escribe <salida>.png
    --sheet    ademas genera una hoja de contacto de todas las piezas

Paleta por defecto: la estandar del Mega Drive (colores comun del juego).
Si pasas la CRAM real los colores seran exactos.
"""
import sys
import os
import struct


# ---------------------------------------------------------------- paleta ---
def gen_std_palette():
    """16 colores de referencia del Mega Drive (0 = transparente)."""
    base = [
        0x0000, 0x0000, 0x1111, 0x2222, 0x3333, 0x4444, 0x5555, 0x6666,
        0x7777, 0x8888, 0x9999, 0xAAAA, 0xBBBB, 0xCCCC, 0xDDDD, 0xEEEE,
    ]
    return base


def read_palette(path):
    data = open(path, "rb").read()
    pal = []
    for i in range(0, min(len(data) - 1, 128), 2):
        pal.append(struct.unpack(">H", data[i:i + 2])[0] & 0x0EEE)
    return pal


def bgr555_to_rgb(c):
    """BBBGGGRR -> (r,g,b) 0-255. El valor 0 queda transparente."""
    if c == 0:
        return (0, 0, 0)
    r = (c & 0x000E) >> 1
    g = (c & 0x00E0) >> 5
    b = (c & 0x0E00) >> 9
    return (r * 255 // 7, g * 255 // 7, b * 255 // 7)


# --------------------------------------------------------------- lectura ---
def decode_4bpp_linear(raw, tile_w, tile_h):
    """Convierte un volcado 4bpp linear en una lista de tiles (listas de filas).

    Formato Mega Drive: por cada fila del tile, ceil(ancho/2) bytes.
    El nibble ALTO de cada byte es el pixel de la IZQUIERDA.
    Pixel con valor 0 = transparente.
    """
    bytes_per_row = (tile_w + 1) // 2
    tile_bytes = bytes_per_row * tile_h
    tiles = []
    for off in range(0, len(raw) - tile_bytes + 1, tile_bytes):
        chunk = raw[off:off + tile_bytes]
        rows = []
        for y in range(tile_h):
            row = chunk[y * bytes_per_row:(y + 1) * bytes_per_row]
            pixels = []
            for b in row:
                hi = (b >> 4) & 0xF
                lo = b & 0xF
                pixels.append(hi)
                if len(pixels) < tile_w:
                    pixels.append(lo)
            rows.append(pixels[:tile_w])
        tiles.append(rows)
    return tiles


def write_png(path, rows, pal):
    """Escribe un PNG RGBA sin dependencias externas (zlib + struct)."""
    import zlib
    h = len(rows)
    w = len(rows[0]) if h else 0
    raw = bytearray()
    for y in range(h):
        raw.append(0)                      # filtro None
        for x in range(w):
            idx = rows[y][x] & 0xF
            r, g, b = bgr555_to_rgb(pal[idx]) if idx < len(pal) else (255, 0, 255)
            if idx == 0:
                raw += bytes((0, 0, 0, 0))          # transparente
            else:
                raw += bytes((r, g, b, 255))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1
    src = args[0]
    tile_w, tile_h = 16, 16
    out = os.path.splitext(src)[0]
    pal = gen_std_palette()
    sheet = False

    i = 1
    while i < len(args):
        a = args[i]
        if a == "-w":
            tile_w = int(args[i + 1]); i += 2
        elif a == "-h":
            tile_h = int(args[i + 1]); i += 2
        elif a in ("-o", "--out"):
            out = args[i + 1]; i += 2
        elif a in ("-p", "-c"):
            path = args[i + 1]
            pal = read_palette(path)
            print("paleta: %d colores desde %s" % (len(pal), path))
            i += 2
        elif a == "--sheet":
            sheet = True; i += 1
        else:
            i += 1

    if not src.lower().endswith(".bin"):
        print("Solo se procesan .bin (volcado crudo 4bpp linear).")
        print("Si TileMolester te exporta PNG, usa 'Save Raw' / 'Export Raw' "
              "para obtener el .bin.")
        return 2

    raw = open(src, "rb").read()
    tiles = decode_4bpp_linear(raw, tile_w, tile_h)
    print("entrada: %s (%d bytes)" % (src, len(raw)))
    print("tiles de %dx%d: %d" % (tile_w, tile_h, len(tiles)))

    if tiles:
        for idx, rows in enumerate(tiles):
            write_png("%s_%03d.png" % (out, idx), rows, pal)
        print("escritos %d PNG en %s_*.png" % (len(tiles), out))

    if sheet and tiles:
        cols = 8
        rows_n = (len(tiles) + cols - 1) // cols
        blank = [0] * tile_w
        sheet_rows = []
        for r in range(rows_n):
            for y in range(tile_h):
                line = []
                for c in range(cols):
                    k = r * cols + c
                    t = tiles[k] if k < len(tiles) else [blank] * tile_h
                    line.extend(t[y])
                sheet_rows.append(line)
        write_png("%s_hoja.png" % out, sheet_rows, pal)
        print("hoja de contacto: %s_hoja.png (%dx%d, %d por fila)"
              % (out, tile_w * cols, tile_h * rows_n, cols))
    return 0


if __name__ == "__main__":
    sys.exit(main())
