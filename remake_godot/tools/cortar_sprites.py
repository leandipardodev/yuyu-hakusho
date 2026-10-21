#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Recorta los personajes REALES de las capturas de combate.

Metodo: el fondo de una pelea es practicamente estatico. Tomando, pixel a
pixel, el color que mas se repite a lo largo de muchos frames obtenemos una
PLACA DE FONDO. Luego cada frame se resta de esa placa y lo que sobra es el
personaje (con su sombra y sus efectos).

Con eso se arma el sprite sheet horizontal de cada animacion, que es el
formato que ya sabe cargar el remake.

    python cortar_sprites.py [carpeta_capturas] [carpeta_salida] [inicio] [fin]
"""
import os
import sys

# Carpeta de capturas por defecto. Antes era una ruta absoluta en el disco de
# otra maquina. Ahora: $YUYU_ANIMS, luego remake_godot/capturas/, luego el
# directorio actual. Se puede pisar desde la linea de comandos igualmente.
_CAPTURAS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "capturas"
)
ANIMS = os.environ.get("YUYU_ANIMS") or (
    _CAPTURAS if os.path.isdir(_CAPTURAS) else os.getcwd()
)
import glob
import re
import zlib
from collections import Counter


# --------------------------------------------------------------- PNG ---
def leer_png(ruta):
    d = open(ruta, "rb").read()
    i, idat = 8, b""
    w = h = ct = None
    plte = None
    while i < len(d):
        ln = struct.unpack(">I", d[i:i + 4])[0]
        tag = d[i + 4:i + 8]
        data = d[i + 8:i + 8 + ln]
        if tag == b"IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", data[:10])
        elif tag == b"PLTE":
            plte = data
        elif tag == b"IDAT":
            idat += data
        elif tag == b"IEND":
            break
        i += 12 + ln
    raw = zlib.decompress(idat)
    canales = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    bpp = max(1, canales)
    filas = []
    prev = bytearray(w * bpp)
    pos = 0
    for _ in range(h):
        f = raw[pos]
        pos += 1
        linea = bytearray(raw[pos:pos + w * bpp])
        pos += w * bpp
        if f == 1:
            for x in range(bpp, len(linea)):
                linea[x] = (linea[x] + linea[x - bpp]) & 0xFF
        elif f == 2:
            for x in range(len(linea)):
                linea[x] = (linea[x] + prev[x]) & 0xFF
        elif f == 3:
            for x in range(len(linea)):
                a = linea[x - bpp] if x >= bpp else 0
                linea[x] = (linea[x] + ((a + prev[x]) >> 1)) & 0xFF
        elif f == 4:
            for x in range(len(linea)):
                a = linea[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                linea[x] = (linea[x] + pr) & 0xFF
        filas.append(bytes(linea))
        prev = linea
    if ct == 2:
        return w, h, filas
    if ct == 6:
        out = []
        for f in filas:
            o = bytearray()
            for x in range(w):
                o += f[x * 4:x * 4 + 3]
            out.append(bytes(o))
        return w, h, out
    if ct == 3:
        out = []
        for f in filas:
            o = bytearray()
            for x in range(w):
                idx = f[x]
                o += plte[idx * 3:idx * 3 + 3]
            out.append(bytes(o))
        return w, h, out
    raise ValueError("PNG no soportado ct=%s" % ct)


def escribir_png(ruta, w, h, pix):
    """pix: lista de h filas, cada fila bytes RGBA"""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += pix[y]

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 6))
    png += chunk(b"IEND", b"")
    open(ruta, "wb").write(png)


# ------------------------------------------------------------sprites ---
def placa_de_fondo(frames):
    """color mas frecuente por pixel (mediana aproximada)"""
    h = frames[0][0].shape[0]
    w = frames[0][0].shape[1]
    placa = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            c = Counter()
            for f in frames:
                px = f[y][x]
                c[(int(px[0]), int(px[1]), int(px[2]))] += 1
            (r, g, b), _ = c.most_common(1)[0]
            placa[y][x] = (r, g, b)
    return placa


def main():
    import numpy as np
    carpeta = sys.argv[1] if len(sys.argv) > 1 else ANIMS
    salida = sys.argv[2] if len(sys.argv) > 2 else "sprites_reales"
    prefijo = sys.argv[3] if len(sys.argv) > 3 else None

    arc = sorted(glob.glob(os.path.join(carpeta, "*.png")))
    if prefijo:
        arc = [a for a in arc if os.path.basename(a).startswith(prefijo)]
    if not arc:
        print("no hay capturas")
        return 1
    os.makedirs(salida, exist_ok=True)
    print("capturas: %d  (prefijo %s)" % (len(arc), prefijo))

    cargadas = []
    for a in arc:
        try:
            w, h, filas = leer_png(a)
            arr = np.zeros((h, w, 3), dtype=np.uint8)
            for y in range(h):
                arr[y] = np.frombuffer(filas[y], dtype=np.uint8).reshape(w, 3)
            cargadas.append((os.path.basename(a), arr))
        except Exception as e:
            print("  fallo %s: %s" % (os.path.basename(a), e))
    print("cargadas %d de %d" % (len(cargadas), len(arc)))
    if len(cargadas) < 4:
        return 1

    print("construyendo la placa de fondo...")
    arrs = [c[1] for c in cargadas]
    placa = placa_de_fondo(arrs)

    h, w, _ = placa.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = placa
    rgba[:, :, 3] = 255
    filas = [bytes(rgba[y]) for y in range(h)]
    escribir_png(os.path.join(salida, "fondo_placa.png"), w, h, filas)
    print("  -> fondo_placa.png")

    total = 0
    for nombre, arr in cargadas:
        dif = (arr.astype(np.int16) != placa.astype(np.int16)).any(axis=2)
        ys, xs = np.nonzero(dif)
        if len(xs) == 0:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        # margen pequeno
        x0 = max(0, x0 - 2); y0 = max(0, y0 - 2)
        x1 = min(w - 1, x1 + 2); y1 = min(h - 1, y1 + 2)
        cw = x1 - x0 + 1
        ch = y1 - y0 + 1
        out = np.zeros((ch, cw, 4), dtype=np.uint8)
        sub_dif = dif[y0:y1 + 1, x0:x1 + 1]
        out[:, :, :3] = arr[y0:y1 + 1, x0:x1 + 1]
        out[:, :, 3] = np.where(sub_dif, 255, 0).astype(np.uint8)
        pix = [bytes(out[y]) for y in range(ch)]
        base = os.path.splitext(nombre)[0]
        escribir_png(os.path.join(salida, base + "_pj.png"), cw, ch, pix)
        total += 1
        if total <= 8:
            print("  %s -> %dx%d" % (nombre, cw, ch))
    print("sprites extraidos: %d -> %s" % (total, salida))
    return 0


if __name__ == "__main__":
    import numpy as np
    sys.exit(main())
