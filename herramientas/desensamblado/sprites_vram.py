# -*- coding: utf-8 -*-
"""
Extrae sprites del Mega Drive directamente desde un volcado de VRAM+CRAM.
No necesita TileMolester.

Como funciona:
  - El VDP guarda una tabla de piezas (sprites) al final de la VRAM.
  - Cada entrada son 8 bytes: Y, tamano, enlace, atributo, X, indice de tile.
  - Cada tile son 32 bytes en 4bpp linear (8 filas de 4 bytes, nibble alto a
    la izquierda, pixel 0 = transparente).
  - La paleta sale de la CRAM (64 palabras BBBGGGRR).

El juego dibuja cada personaje con varias piezas colocadas en pantalla; este
script las devuelve piece a piece con su posicion, para poder recomponer el
sprite completo (o animated) en el remake.

Uso:
    python sprites_vram.py vram.bin cram.bin -o salida [--table 0x3F800]
    python sprites_vram.py vram.bin cram.bin -o salida --screenshot pantalla.png
"""
import sys
import os
import struct
import zlib

TILE_BYTES = 32          # 4bpp, 8x8
VRAM_SIZE = 0x10000


# ------------------------------------------------------------------ PNG ---
def write_png(path, w, h, pixels):
    """pixels: lista de filas, cada fila lista de (r,g,b,a)"""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b, a = pixels[y][x]
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def bgr555(c):
    if c == 0:
        return (0, 0, 0, 0)
    r = ((c & 0x000E) >> 1) * 255 // 7
    g = ((c & 0x00E0) >> 5) * 255 // 7
    b = ((c & 0x0E00) >> 9) * 255 // 7
    return (r, g, b, 255)


# ---------------------------------------------------------------- utiles ---
def cargar(vram_path, cram_path):
    v = open(vram_path, "rb").read()
    c = open(cram_path, "rb").read()
    if len(v) < VRAM_SIZE:
        v = v + b"\x00" * (VRAM_SIZE - len(v))
    pal = []
    for i in range(0, min(len(c), 128), 2):
        pal.append(struct.unpack(">H", c[i:i + 2])[0] & 0x0EEE)
    while len(pal) < 64:
        pal.append(0)
    return v, pal


def detectar_tabla(v):
    """Busca la tabla de sprites: 8 bytes alineada, con bytes de tamano y
    posiciones plausibles. Seffee la de $3F800 (la estandar)."""
    def buena(base):
        # la primera entrada suele tener link=0 y el resto enlazado
        n = 0
        for k in range(20):
            off = base + k * 8
            if off + 8 > VRAM_SIZE:
                break
            y = struct.unpack(">H", v[off:off + 2])[0] & 0x3FF
            size = v[off + 2]
            x = struct.unpack(">H", v[off + 6:off + 8])[0] & 0x3FF
            hsz = size & 3
            vsz = (size >> 2) & 3
            if size & 0xF0 == 0 and y < 400 and x < 400 and (hsz or vsz):
                n += 1
        return n

    base_estandar = 0x3F800
    puntos = []
    for base in range(0, VRAM_SIZE - 160, 0x100):
        if base % 8:
            continue
        s = buena(base)
        if s >= 6:
            puntos.append((s, base))
    puntos.sort(reverse=True)
    res = [p for _, p in puntos[:5]]
    if buena(base_estandar) >= 6:
        res.insert(0, base_estandar)
    return res


def decodificar_tile(v, addr, tile_w, tile_h):
    """4bpp linear -> matriz de indices de pixel."""
    addr &= ~1
    bpr = tile_w // 2
    filas = []
    for y in range(tile_h):
        base = addr + y * bpr
        if base + bpr > VRAM_SIZE:
            filas.append([0] * tile_w)
            continue
        chunk = v[base:base + bpr]
        px = []
        for b in chunk:
            px.append((b >> 4) & 0xF)
            px.append(b & 0xF)
        filas.append(px[:tile_w])
    return filas


SZ_H = [1, 2, 4, 8]
SZ_V = [1, 2, 4, 8]


def parsear_tabla(v, pal, base, char_base, max_sprites=80):
    """Devuelve la lista de piezas con su posicion y pixeles."""
    piezas = []
    link = 0
    visitados = set()
    for _ in range(max_sprites):
        if link in visitados or link >= 80:
            break
        visitados.add(link)
        off = base + link * 8
        if off + 8 > VRAM_SIZE:
            break
        y = struct.unpack(">H", v[off:off + 2])[0] & 0x3FF
        sizeb = v[off + 2]
        attr = v[off + 4]
        x = struct.unpack(">H", v[off + 6:off + 8])[0] & 0x3FF
        link = v[off + 3]

        if y & 0x200:
            y -= 0x400
        if x & 0x200:
            x -= 0x400

        hsz = SZ_H[sizeb & 3]
        vsz = SZ_V[(sizeb >> 2) & 3]
        hflip = sizeb & 0x10
        vflip = sizeb & 0x20
        prio = (attr >> 2) & 3
        pal_sel = attr & 0x0F
        tile = v[off + 7] | ((v[off + 6] & 0x04) << 8)

        cell_w = 8 * hsz
        cell_h = 8 * vsz
        # ensamblamos la celda (puede ser 16x16, 16x32, 32x32...)
        pixeles = []
        for cy in range(cell_h):
            fila = []
            for cx in range(cell_w):
                sub = (cy // 8) * hsz + (cx // 8)
                tile_idx = tile + sub
                taddr = (char_base + tile_idx * TILE_BYTES)
                t = decodificar_tile(v, taddr, 8, 8)
                val = t[cy % 8][cx % 8]
                if hflip:
                    val = decodificar_tile(v, taddr, 8, 8)[cy % 8][7 - (cx % 8)]
                if vflip:
                    t2 = decodificar_tile(v, taddr, 8, 8)
                    val = t2[7 - (cy % 8)][cx % 8]
                fila.append(val)
            pixeles.append(fila)

        piezas.append({
            "x": x, "y": y, "w": cell_w, "h": cell_h,
            "tile": tile, "pal": pal_sel, "prio": prio,
            "hflip": hflip, "vflip": vflip, "px": pixeles,
        })
    return piezas


def dibujar(piezas, pal, Lienzo_w, Lienzo_h):
    """Compone las piezas sobre un lienzo con la paleta CRAM."""
    lienzo = [[(0, 0, 0, 0)] * Lienzo_w for _ in range(Lienzo_h)]
    # primero las de prioridad alta (se dibujan encima)
    for p in sorted(piezas, key=lambda s: s["prio"]):
        base_pal = (p["pal"] & 0x0F) << 4
        for j, fila in enumerate(p["px"]):
            for i, val in enumerate(fila):
                if val == 0:
                    continue
                xx = p["x"] + i
                yy = p["y"] + j
                if 0 <= xx < Lienzo_w and 0 <= yy < Lienzo_h:
                    ci = base_pal + val
                    if ci < len(pal):
                        r, g, b, a = bgr555(pal[ci])
                        if a:
                            lienzo[yy][xx] = (r, g, b, 255)
    return lienzo


def guardar_png(path, w, h, pixeles):
    write_png(path, w, h, pixeles)


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__)
        return 1
    v, pal = cargar(a[0], a[1])
    out = "sprites_out"
    table = None
    char_base = None
    lw, lh = 320, 224
    i = 2
    while i < len(a):
        if a[i] == "-o":
            out = a[i + 1]; i += 2
        elif a[i] == "--table":
            table = int(a[i + 1], 0); i += 2
        elif a[i] == "--charbase":
            char_base = int(a[i + 1], 0); i += 2
        elif a[i] == "--size":
            lw, lh = (int(x) for x in a[i + 1].split("x")); i += 2
        else:
            i += 1

    print("VRAM %d bytes, CRAM %d colores" % (len(v), len(pal)))

    tablas = [table] if table else detectar_tabla(v)
    print("tablas de sprites candidatas: %s"
          % ", ".join("0x%05X" % t for t in tablas))

    bases = [char_base] if char_base else [b for b in range(0, 0x10000, 0x2000)]
    mejor = None
    for tb in tablas:
        for cb in bases:
            piezas = parsear_tabla(v, pal, tb, cb)
            # puntuacion: piezas visibles (con pixeles no nulos)
            score = 0
            for p in piezas:
                score += sum(1 for f in p["px"] for x in f if x != 0)
            if mejor is None or score > mejor[0]:
                mejor = (score, tb, cb, piezas)

    score, tb, cb, piezas = mejor
    print("mejor combinacion: tabla 0x%05X, charbase 0x%05X, %d piezas, %d pixeles visibles"
          % (tb, cb, len(piezas), score))

    lienzo = dibujar(piezas, pal, lw, lh)
    guardar_png(out + "_pantalla.png", lw, lh, lienzo)
    print("escrito %s_pantalla.png" % out)

    # cada pieza por separado
    n = 0
    for k, p in enumerate(piezas):
        base_pal = (p["pal"] & 0x0F) << 4
        img = []
        anya = False
        for fila in p["px"]:
            r = []
            for val in fila:
                if val == 0:
                    r.append((0, 0, 0, 0))
                else:
                    ci = base_pal + val
                    if ci < len(pal):
                        px = bgr555(pal[ci])
                        r.append((px[0], px[1], px[2], 255))
                        anya = True
                    else:
                        r.append((255, 0, 255, 255))
            img.append(r)
        if anya:
            guardar_png("%s_pieza%02d.png" % (out, k), p["w"], p["h"], img)
            n += 1
    print("escritas %d piezas individuales (%s_piezaNN.png)" % (n, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
