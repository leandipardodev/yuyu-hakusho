# -*- coding: utf-8 -*-
"""
Verifica si nuestra volcado_moves.txt esta desalineada, como dice el guia del amigo.

La rutina del builder lo dice clarisimo:

    01eb42:  add.b   $5f(a5), d0      ; d0 = id de move
    01eb46:  add.w   d0, d0           ; x2 -> offset de WORD
    01eb48:  movea.l $50(a5), a2      ; a2 = base de la tabla INDICE
    01eb4c:  adda.w  (a2, d0.w), a2   ; a2 += indice[$5F]

O sea que $50 NO es la tabla de frames: es una tabla de indices de WORD, y la
direccion del frame sale de sumar el indice a la misma base. Si nuestra lista
trato $50 como si fueran los registros, esta desalineada.

Este script lee el indice y los registros de verdad, y los compara con lo que
tenemos guardado.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom  # noqa: E402

# Las bases de $50 por contexto, de la tabla del propio guia del amigo (seccion 7).
BASE50 = {
    0: 0xBF75A, 1: 0xC229A, 2: 0xC4EEA, 3: 0xC7C9A, 4: 0xCA6DA,
    5: 0xCCC7A, 6: 0xCF99A, 7: 0xD1E5A, 8: 0xD4A9A, 9: 0xD777A,
}

with open(ruta_rom(), "rb") as f:
    rom = f.read()


def w16(a):
    return int.from_bytes(rom[a:a + 2], "big")


def b8(a):
    return list(rom[a:a + 8])


def nuestra(ctx, idx):
    """Lo que tenemos guardado, para comparar."""
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "volcado_moves.txt")
    if not os.path.exists(ruta):
        return None
    with open(ruta, "r", encoding="utf-8", errors="replace") as f:
        for linea in f:
            m = re.match(r"^ctx(\d+)\s+%d\s+(\$0[0-9A-Fa-f]+)\s+(\d+)\s+"
                         r"(\d+)\s+\$?([0-9A-Fa-f]{2})\s+\$?([0-9A-Fa-f]{2})\s+"
                         r"\$?([0-9A-Fa-f]{2})\s+\$?([0-9A-Fa-f]{2})" % idx, linea)
            if m and int(m.group(1)) == ctx:
                return (m.group(2),
                        int(m.group(3)), int(m.group(4)),
                        int(m.group(5), 16), int(m.group(6), 16),
                        int(m.group(7), 16), int(m.group(8), 16))
    return None


def main():
    print("=== el indice de words en $50, y lo que hay realmente detras ===")
    print()
    for ctx in (0, 1):
        base = BASE50[ctx]
        print("ctx%d  base de $50 = $%06X" % (ctx, base))
        print("   los primeros bytes de la base, que serian el indice:")
        idx = [w16(base + 2 * i) for i in range(8)]
        print("      indice[0..7] = %s" % ", ".join("$%04X" % v for v in idx))
        print()
        for i in range(5):
            destino = base + idx[i]
            rec = b8(destino)
            n = nuestra(ctx, i)
            print("   move %d: indice=$%04X -> destino=$%06X" % (i, idx[i], destino))
            print("      registro leido del ROM : %s" %
                  " ".join("%02X" % b for b in rec))
            if n:
                print("      nuestro volcado        : dest=%s b0=%d b1=%d flg=%02X b3=%02X b4=%02X b5=%02X"
                      % (n[0], n[1], n[2], n[3], n[4], n[5], n[6]))
            else:
                print("      nuestro volcado        : (no esta en la lista)")
            print()

    print("=== conclusion ===")
    print("Si 'nuestro volcado' tiene el destino en $00XXXX cerca de la base y el")
    print("registro del ROM tiene OTROS bytes, nuestra lista esta leyendo la tabla")
    print("de indices como si fueran los registros de frame.")


if __name__ == "__main__":
    main()
