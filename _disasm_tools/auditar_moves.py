# -*- coding: utf-8 -*-
"""
Auditoria completa de nuestra LISTA_MOVES.txt contra el ROM.

El guia del amigo afirma dos cosas sobre nuestro volcado:

  (a) que esta "desalineado"
  (b) que hay 191 moves por contexto, no 195 ni 401

Las dos se prueban aqui releyendo TODO desde el ROM por el camino real
(indice de words -> registro de 8 bytes) y comparando con lo guardado.

Sobre (b): un offset 0 en el indice significa que ese move no existe y el
registro cae en la propia base. Si los ultimos indices dan 0, entonces hay
indices de mas que no son moves, y el numero real de moves es el primer indice
con offset 0.
"""
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom  # noqa: E402

BASE50 = {
    0: 0xBF75A, 1: 0xC229A, 2: 0xC4EEA, 3: 0xC7C9A, 4: 0xCA6DA,
    5: 0xCCC7A, 6: 0xCF99A, 7: 0xD1E5A, 8: 0xD4A9A, 9: 0xD777A,
}
LIMITE = 420          #indices a mirar por contexto

with open(ruta_rom(), "rb") as f:
    rom = f.read()

RUTA_LISTA = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "LISTA_MOVES.txt")


def w16(a):
    return int.from_bytes(rom[a:a + 2], "big")


def cargar_nuestra():
    """(ctx, idx) -> (dest, b0, b1, flg, b3, b4, b5, vx, vy)"""
    nuestra = {}
    pat = re.compile(
        r"^ctx(\d+)\s+(\d+)\s+(\$0[0-9A-Fa-f]+)\s+(\d+)\s+(\d+)\s+"
        r"\$?([0-9A-Fa-f]{2})\s+\$?([0-9A-Fa-f]{2})\s+"
        r"\$?([0-9A-Fa-f]{2})\s+\$?([0-9A-Fa-f]{2})\s+"
        r"(-?\d+)\s+(-?\d+)\s*$")
    with open(RUTA_LISTA, "r", encoding="utf-8", errors="replace") as f:
        for linea in f:
            if linea.startswith("#") or linea.startswith("ctx idx"):
                continue
            m = pat.match(linea.rstrip("\n"))
            if not m:
                continue
            nuestra[(int(m.group(1)), int(m.group(2)))] = (
                int(m.group(3).lstrip("$"), 16), int(m.group(4)), int(m.group(5)),
                int(m.group(6), 16), int(m.group(7), 16),
                int(m.group(8), 16), int(m.group(9), 16))
    return nuestra


def main():
    nuestra = cargar_nuestra()

    print("=== (a) nuestra lista contra el ROM, entrada por entrada ===")
    print()
    total = 0
    iguais = 0
    malos = []
    for (c, idx), n in sorted(nuestra.items()):
        if c not in BASE50:
            continue
        base = BASE50[c]
        off = w16(base + 2 * idx)
        dest = base + off
        rom_rec = tuple(rom[dest:dest + 6])
        total += 1
        if (n[1], n[2], n[3], n[4], n[5], n[6]) == rom_rec:
            iguais += 1
        else:
            malos.append((c, idx, n[0], n[1:7], rom_rec))
    print("  entradas comprobadas: %d" % total)
    print("  identicas al ROM   : %d" % iguais)
    print("  distintas          : %d" % len(malos))
    if total:
        print("  -> %.2f%% coincide" % (100.0 * iguais / total))
    if malos:
        print("  primeras diferencias:")
        for c, idx, dest, nuestro, rr in malos[:12]:
            print("    ctx%-2d idx%-4d $%06X  nuestro %s  rom %s"
                  % (c, idx, dest,
                     " ".join("%02X" % v for v in nuestro),
                     " ".join("%02X" % v for v in rr)))
    print()

    print("=== (b) cuantos indices son moves de verdad ===")
    print("   offset 0 = el move no existe (el registro cae en la base)")
    print()
    print("   ctx   indices leidos   con offset 0   moves reales")
    filas = []
    for c in sorted(BASE50):
        base = BASE50[c]
        ceros = []
        for i in range(LIMITE):
            if w16(base + 2 * i) == 0:
                ceros.append(i)
            elif ceros:
                break                      # primer 0 y luego algo: hay huecos
        moves = ceros[0] if ceros else LIMITE
        filas.append((c, moves, ceros[:12]))
    print("   ctx   moves   indices con offset 0 (los primeros)")
    for c, moves, ceros in filas:
        txt = ", ".join(str(z) for z in ceros) if ceros else "-"
        print("   %-5d %-7d %s" % (c, moves, txt))
    print()
    print("   Lo que tenemos guardado por contexto:")
    por_ctx = defaultdict(int)
    for (c, idx) in nuestra:
        por_ctx[c] += 1
    for c in sorted(por_ctx):
        print("      ctx%-2d %d entradas" % (c, por_ctx[c]))


if __name__ == "__main__":
    main()
