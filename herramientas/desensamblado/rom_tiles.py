#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Escanea el ROM del Mega Drive buscando bloques de tiles 4bpp linear que
parezcan graficos de personajes, y los renderiza como hojas de contacto.

Es lo mismo que hace TileMolester, pero automatico: en vez de navegar a mano
3 MB de ROM, se puntua cada tile de 32 bytes y se renderizan solo las regiones
prometedoras.

Puntuacion de un tile (0-100):
  - cuanto dato tiene (bytes no nulos), para descartar paginas en blanco
  - cuanto contraste tiene (que use varios valores de pixel y no sea ruido)
  - penalizacion si parece aleatorio (bytes 0/255 presentes de forma masiva,
    tipico de datos comprimidos o de codigo, no de graficos)

Salida: PNGs de hojas de contacto + un informe de las regiones.
"""
import sys
import os
import struct
import zlib
from collections import Counter

TILE = 32            # 8x8 en 4bpp linear


# ------------------------------------------------------------------ PNG ---
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


def paleta_gris():
    """indice 0 transparente; 1..15 rampa de gris"""
    p = [(0, 0, 0, 0)]
    for i in range(1, 16):
        v = int(40 + (i - 1) * (215 / 14))
        p.append((v, v, v, 255))
    return p


# ------------------------------------------------------------- tile ops ---
def decodificar(rom, off):
    """un tile 8x8 4bpp -> lista de 8 filas de 8 indices de pixel"""
    filas = []
    for y in range(8):
        base = off + y * 4
        px = []
        for i in range(4):
            b = rom[base + i]
            px.append((b >> 4) & 0xF)
            px.append(b & 0xF)
        filas.append(px)
    return filas


def puntuar(rom, off):
    """0-100: cuanto parece un TILE DE SPRITE real.

    Idea: un tile de grafico dibujado usa POCOS tonos (2-6 de 16) y suele
    tener un color dominante (el relleno de la piel/ropa) mas el contorno.
    Los datos comprimidos usan los 16 valores casi por igual.

    Por eso aqui se premia la BAJA variedad, al contrario que un filtro
    ingenuo: ese filtro seleccionaba justamente el ruido.
    """
    t = rom[off:off + TILE]
    if len(t) < TILE:
        return 0, None
    vals = []
    for b in t:
        vals.append((b >> 4) & 0xF)
        vals.append(b & 0xF)
    hist = Counter(vals)
    nz = sum(v for k, v in hist.items() if k != 0)
    if nz < 10:                       # casi vacio: pagina en blanco
        return 0, None
    usados = sum(1 for k in hist if k != 0)
    dominante = max(hist[k] for k in hist if k != 0) / nz

    # recompensa: pocos tonos por tile
    s = 0.0
    if usados <= 6:
        s += 55.0
    elif usados <= 9:
        s += 35.0
    elif usados <= 12:
        s += 15.0
    else:
        s += 0.0
    # recompensa: hay un color claramente dominante (relleno + contorno)
    if dominante > 0.45:
        s += 30.0
    elif dominante > 0.30:
        s += 18.0
    elif dominante > 0.20:
        s += 6.0
    # algo de contenido pero no una pagina llena de un solo tono
    frac = nz / 16.0
    if 0.35 <= frac <= 1.0:
        s += 15.0
    return max(0.0, min(100.0, s)), t



def regiones(rom, umbral, min_tiles):
    """agrupa tiles buenos consecutivos"""
    n = len(rom) // TILE
    flags = bytearray(n)
    for i in range(n):
        s, _ = puntuar(rom, i * TILE)
        flags[i] = 1 if s >= umbral else 0
    regs = []
    i = 0
    while i < n:
        if flags[i]:
            j = i
            while j < n and flags[j]:
                j += 1
            largo = j - i
            if largo >= min_tiles:
                regs.append((i * TILE, largo * TILE, largo))
            i = j
        else:
            i += 1
    regs.sort(key=lambda r: -r[1])
    return regs


def hoja(rom, off, largo_tiles, cols, pal, zoom):
    filas_tiles = (largo_tiles + cols - 1) // cols
    w = cols * 8 * zoom
    h = filas_tiles * 8 * zoom
    # inicializa transparente
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]
    for i in range(largo_tiles):
        t = decodificar(rom, off + i * TILE)
        tx = (i % cols) * 8 * zoom
        ty = (i // cols) * 8 * zoom
        for y in range(8):
            for x in range(8):
                idx = t[y][x]
                if idx == 0:
                    continue
                c = pal[idx] if idx < len(pal) else (255, 0, 255, 255)
                for dy in range(zoom):
                    yy = ty + y * zoom + dy
                    if yy >= h:
                        continue
                    for dx in range(zoom):
                        xx = tx + x * zoom + dx
                        if xx < w:
                            img[yy][xx] = c
    return w, h, img


def main():
    rom_path = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "tiles_scan"
    umbral = float(sys.argv[3]) if len(sys.argv) > 3 else 42.0
    min_tiles = int(sys.argv[4]) if len(sys.argv) > 4 else 64
    max_reg = int(sys.argv[5]) if len(sys.argv) > 5 else 14
    cols = 16
    zoom = 2

    rom = open(rom_path, "rb").read()
    os.makedirs(outdir, exist_ok=True)
    print("ROM: %d bytes (%d tiles de 32B)" % (len(rom), len(rom) // TILE))

    regs = regiones(rom, umbral, min_tiles)
    print("regiones candidatas: %d (umbral %.0f, min %d tiles)"
          % (len(regs), umbral, min_tiles))
    for r in regs[:30]:
        print("   $%06X - $%06X   %6d bytes  %5d tiles"
              % (r[0], r[0] + r[1], r[1], r[2]))

    pal = paleta_gris()
    print()
    print("renderizando las %d regiones mas grandes..." % max_reg)
    lines = []
    for k, (off, largo, nt) in enumerate(regs[:max_reg]):
        w, h, img = hoja(rom, off, nt, cols, pal, zoom)
        ruta = os.path.join(outdir, "reg%02d_%06X.png" % (k, off))
        write_png(ruta, w, h, img)
        lines.append("%-28s offset $%06X  %d bytes  %d tiles  (%dx%d px)"
                     % (os.path.basename(ruta), off, largo, nt, w, h))
        print("  " + lines[-1])

    with open(os.path.join(outdir, "indice.txt"), "w", encoding="utf-8") as f:
        f.write("Regiones de tiles 4bpp candidatas en el ROM\n")
        f.write("ROM: %s\n\n" % os.path.basename(rom_path))
        f.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())

