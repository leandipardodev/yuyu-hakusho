# -*- coding: utf-8 -*-
"""
Herramienta: parcheador de ROM verificado.

Por que existe: el intento anterior ("v1 NO SIRVE") fallo porque se
parcheo a mano sin verificar, y un patch de 1 byte mal puesto dejo el
juego con una instruccion ilegal (crash) o un salto a relleno $FF.

Este parcheador:
  1. Lee un MANIFIESTO declarativo (lista de patches).
  2. VERIFICA que cada byte a tocar tiene el valor esperado. Si no
     coincide, ABORTA (no escribe nada). Esto es lo que habria evitado
     los dos parches rotos.
  3. Escribe el ROM de salida.
  4. RELEE la salida y vuelve a comprobar cada byte. Si algo no quedo
     como se pidio, error.

Uso:
  python patch_rom.py <entrada> <salida> [grupos...]

  grupos: fix dragon dragon_vel blob extras sinz80 checksum todos
  --list : solo lista los patches disponibles
  --force: aplica aunque un byte esperado no coincida (avisa)
  --factor=N : factor de velocidad del dragon (0.5 = mitad)

Salida: informe por stdout. No toca el ROM de entrada.
"""
import io
import os
import sys

# la consola de Windows usa cp1252 y no tiene ideogramas
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

# El manifiesto JSON (datos/parches.json) es la FUENTE UNICA de los
# parches: direccion, valor actual, valor nuevo y nivel de confianza.
import json


def manifiesto():
    ruta = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
                         os.path.abspath(__file__)))), "datos", "parches.json")
    with io.open(ruta, encoding="utf-8") as f:
        return json.load(f)


def parches_de_json(solo_grupos=None):
    """Devuelve {grupo: (titulo, [(addr, old, new), ...])} desde el JSON."""
    m = manifiesto()
    salida = {}
    for g, datos in m["patches"].items():
        if solo_grupos and g not in solo_grupos:
            continue
        items = []
        for b in datos.get("bytes", []):
            items.append((int(b["addr"], 16),
                          int(b["old"], 16),
                          int(b["new"], 16)))
        salida[g] = (datos.get("desc", g), items)
    return salida


# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------
def w16(d, o):
    return (d[o] << 8) | d[o + 1]


def sx(b):
    v = (b - 0x80) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def sy(b):
    v = (b - 0xA0) & 0xFFFF
    return v - 0x10000 if v > 0x7FFF else v


def checksum(d, ini=0x200):
    s = 0
    n = len(d)
    if (n - ini) & 1:
        n -= 1
    for o in range(ini, n, 2):
        s += (d[o] << 8) | d[o + 1]
    return s & 0xFFFF


CTX = [
    ("ctx0", 0x0BF75A, 0x0C04CA), ("ctx1", 0x0C229A, 0x0C31DA),
    ("ctx2", 0x0C4EEA, 0x0C5DAA), ("ctx3", 0x0C7C9A, 0x0C8BEA),
    ("ctx4", 0x0CA6DA, 0x0CB38A), ("ctx5", 0x0CCC7A, 0x0CDEFA),
    ("ctx6", 0x0CF99A, 0x0D069A), ("ctx7", 0x0D1E5A, 0x0D2C6A),
    ("ctx8", 0x0D4A9A, 0x0D59FA), ("ctx9", 0x0D777A, 0x0D85AA),
]

DRAGON_ID = 38
DRAGON_ID2 = 39
CTX_HIEI = 3


def dragones(d, factor):
    """Ralentiza el dragon de Hiei.

    Solo se parchean los frames que REALMENTE hacen el golpe, que se
    reconocen por su firma:
      - la sub-lista tiene el bit 6 (bit de hitbox) activo, y
      - la caja tiene radioX >= 32 (una onda ancha; un golpe normal
        tiene radio 4-16).
    En Hiei eso son exactamente los frames 0 y 1 del move 38, que son
    ademas los unicos con b0=255 (frame en bucle): la onda sale y se
    queda viajando mientras el frame se repite.

    No se parchea la cadena entera de frames, porque donde termina la
    cadena de un move NO esta verificado y los frames siguientes
    pueden ser de OTRO move.
    """
    patches = []
    vistos = set()
    for mid in (DRAGON_ID, DRAGON_ID2):
        nombre, base50, base8c = CTX[CTX_HIEI]
        w = w16(d, base50 + mid * 2)
        base = base50 + w
        for f in range(24):
            rec = base + f * 8
            if rec + 7 >= len(d):
                break
            b1 = d[rec + 1]
            sub = base8c + b1 * 4
            if sub + 3 >= len(d):
                break
            flags = d[sub]
            if not (flags & 0x40):
                continue
            blob = sub + w16(d, sub + 2)
            if blob + 7 >= len(d):
                continue
            radio = d[blob + 4] & 0x7F
            if radio < 32:
                continue
            off = rec + 6
            if off in vistos:
                continue
            vistos.add(off)
            vx = sx(d[off])
            if vx == 0:
                continue
            nuevo = int(round(0x80 + vx * factor)) & 0xFF
            if nuevo != d[off]:
                patches.append((off, d[off], nuevo))
    return patches


# --------------------------------------------------------------------------
# MANIFIESTO
# --------------------------------------------------------------------------
def construir(d, args):
    # Los parches salen del manifiesto JSON, que es la fuente unica.
    grupos = parches_de_json(None)

    # El checksum se reescribe SIEMPRE al final: el juego lo valida al
    # arrancar (0x4318) y sin recalcularlo el ROM no pasa del logo SEGA.
    grupos["checksum"] = ("Reescribir el checksum de la cabecera (SIEMPRE)",
                          [])

    return grupos


def parche_checksum(d):
    """Devuelve los 2 parches del checksum calculados sobre d YA parcheado.

    El checksum de la cabecera Sega (0x18E) es la suma de TODAS las
    palabras de 16 bits del ROM desde 0x200 hasta el final, mod 0x10000.
    El juego lo verifica al arrancar (0x4318) y si no cuadra escribe
    E080 = 0x0E y se queda colgado en el logo SEGA.
    """
    s = 0
    n = len(d)
    if (n - 0x200) & 1:
        n -= 1
    for o in range(0x200, n, 2):
        s += (d[o] << 8) | d[o + 1]
    cal = s & 0xFFFF
    alm = (d[0x18E] << 8) | d[0x18F]
    if alm == cal:
        return []
    return [(0x018E, d[0x18E], (cal >> 8) & 0xFF),
            (0x018F, d[0x18F], cal & 0xFF)]


# --------------------------------------------------------------------------
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]

    if "--list" in flags:
        print("grupos: " + " | ".join(sorted(parches_de_json().keys())))
        print("  (el checksum se reescribe SIEMPRE al final)")
        print("El checksum de la cabecera se reescribe SIEMPRE al final:")
        print("el juego lo verifica al arrancar (0x4318); si no cuadra escribe")
        print("E080 = 0x0E y se queda colgado en el logo SEGA.")
        sys.exit(0)

    if len(args) < 2:
        print(__doc__)
        sys.exit(1)

    entrada, salida = args[0], args[1]
    grupos_pedidos = args[2:] or ["fix"]

    if "todos" in grupos_pedidos:
        grupos_pedidos = [g for g in sorted(parches_de_json().keys())
                          if g != "checksum"]

    d = bytearray(open(entrada, "rb").read())
    original = bytes(d)
    print("ROM de entrada : %s  (%d bytes)" % (entrada, len(d)))
    print("ROM de salida  : %s" % salida)
    print("grupos         : %s" % ", ".join(grupos_pedidos))
    print()

    grupos = construir(d, flags)

    todos = []
    for g in grupos_pedidos:
        if g not in grupos:
            print("!! grupo desconocido: %s" % g)
            sys.exit(1)
        titulo, parches = grupos[g]
        print("--- %s: %s" % (g, titulo))
        if not parches:
            print("    (nada que hacer: ya esta en el valor final)")
        for off, viejo, nuevo in parches:
            print("    $%06X  %02X -> %02X" % (off, viejo, nuevo))
            todos.append((off, viejo, nuevo))
        print()

    force = "--force" in flags
    fallos = []
    for off, viejo, nuevo in todos:
        if d[off] != viejo and not force:
            fallos.append((off, viejo, d[off]))
    if fallos:
        print("!! ABORTADO: %d byte(s) no coinciden con lo esperado." % len(fallos))
        for off, esperado, real in fallos[:20]:
            print("   $%06X esperado %02X, en el ROM %02X" % (off, esperado, real))
        print("   (con --force se aplica igual)")
        sys.exit(2)

    for off, viejo, nuevo in todos:
        d[off] = nuevo

    # el checksum se calcula sobre el ROM YA parcheado.
    # SE APLICA SIEMPRE: el juego lo verifica al arrancar (0x4318) y si no
    # cuadra escribe \ = 0x0E y se queda colgado en el logo SEGA.
    # Con --sin-checksum se puede desactivar (solo para depurar).
    if "--sin-checksum" not in flags:
        print("--- checksum: reescribir la cabecera (calculado sobre el ROM ya parcheado)")
        ck = parche_checksum(d)
        if not ck:
            print("    (ya cuadraba)")
        for off, viejo, nuevo in ck:
            print("    $%06X  %02X -> %02X" % (off, viejo, nuevo))
            d[off] = nuevo
            todos.append((off, viejo, nuevo))
        print()

    with open(salida, "wb") as f:
        f.write(d)

    d2 = open(salida, "rb").read()
    # si VARIOS grupos tocan el mismo byte, lo que queda aplicado es el
    # ultimo (se aplican en secuencia): comparar contra el valor final de
    # cada byte, no contra el de cada item suelto.
    finales = {}
    for off, viejo, nuevo in todos:
        finales[off] = nuevo
    malos = sorted(off for off, nuevo in finales.items() if d2[off] != nuevo)
    if malos:
        print("!! ERROR: %d byte(s) no quedaron como se pidio." % len(malos))
        sys.exit(3)

    cambiados = sum(1 for i in range(len(d)) if original[i] != d2[i])
    print("OK: %d parche(s) aplicados y verificados. %d bytes distintos del original."
          % (len(todos), cambiados))
    print("    SHA1 salida: %s"
          % __import__("hashlib").sha1(d2).hexdigest().upper())


if __name__ == "__main__":
    main()
