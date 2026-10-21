# -*- coding: utf-8 -*-
"""
Que hay realmente en las tablas que indexa $26.

$26 es un CURSOR (un contador de programa), no un plano ni una profundidad. La
rutina loc_0379AE hace:

    0379ba:  lea.l    $3a256(pc), a0
    0379be:  subq.w   #$1, d0            ; d0 = ($0A & $7F) - 1
    0379c0:  lsl.w    #$2, d0
    0379c2:  movea.l  (a0, d0.w), a0     ; a0 = puntero al flujo de bytes
    0379c8:  move.b   $26(a5), d0        ; el cursor
    0379cc:  addq.b   #$1, $26(a5)      ; y avanza
    0379d0:  move.b   (a0, d0.w), d6     ; d6 = flujo[$26]
    0379d4:  bpl.b    $379f4            ; bit 7 = 0 -> es un desplazamiento
    0379d6:  cmpi.b   #$80, d6  ...      ; si no, es un CODIGO

El array de punteros tiene 8 entradas ($3A256..$3A275) y la octava apunta a
$3A276, que es justo donde empiezan los flujos: o sea que $0A va de 1 a 8, no de
0 a $7F. El andi.w #$7f del selector solo limpia un bit de bandera.

Este script vuelca los 8 flujos y clasifica cada byte, que es lo que decide entre
"dos planos" y "un cursor con codigos".
"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom  # noqa: E402

# Los 5 unicos codigos que el codigo chequea explicitamente, con su direccion.
CODIGOS = {
    0x80: ("loop",   "clr.b $26(a5)",              "0x37A1A"),
    0x81: ("atras",  "subq.b #$2, $26(a5)",        "0x37A20"),
    0x82: ("salto",  "$26(a5) = byte siguiente",  "0x37A38"),
    0x83: ("rama",   "bset.b #$1,($a5) -> $38AFC / $3A178", "0x37A26"),
    0x84: ("frames", "$3(a5) += byte siguiente",  "0x37A40"),
}

PUNTEROS = 0x3A256
N_TABLAS = 8
FIN_DATOS = 0x3A310        # despues de esto el patron ya no es de flujo


def clase(b):
    if b in CODIGOS:
        return "CODIGO"
    return "DATO+" if b < 0x80 else "DATO-"


def firma(b):
    if b in CODIGOS:
        return "  <%s>" % CODIGOS[b][0]
    if b < 0x80:
        return "%4d" % b
    return "%4d" % (b - 256)


def main():
    with open(ruta_rom(), "rb") as f:
        rom = f.read()

    punteros = []
    for i in range(N_TABLAS):
        off = PUNTEROS + i * 4
        punteros.append(int.from_bytes(rom[off:off + 4], "big"))

    print("=== los 8 punteros de $%06X ===" % PUNTEROS)
    for i, p in enumerate(punteros):
        print("  $0A = %d   ->  $%06X" % (i + 1, p))
    print()

    # Longitud de cada flujo: hasta el siguiente puntero ordenado. El ultimo se
    # acota a mano, mirando donde se rompe el patron.
    orden = sorted(punteros)
    limites = {}
    for p in orden[:-1]:
        limites[p] = None
    for i, p in enumerate(orden[:-1]):
        limites[p] = orden[i + 1] - p

    print("=== los 8 flujos, byte por byte ===")
    total = Counter()
    todos = []
    for i, ini in enumerate(punteros):
        n = limites.get(ini)
        if n is None:
            n = FIN_DATOS - ini
        datos = rom[ini:ini + n]
        c = Counter(clase(b) for b in datos)
        total.update(c)
        todos.extend(datos)
        cods = [b for b in datos if b in CODIGOS]
        print()
        print("  $0A = %d   $%06X   %d bytes" % (i + 1, ini, n))
        for base in range(0, len(datos), 12):
            trozo = datos[base:base + 12]
            hexs = " ".join("%02X" % b for b in trozo)
            val = " ".join(firma(b) for b in trozo)
            print("    +%02X  %-35s  %s" % (base, hexs, val))
        if cods:
            print("    codigos: %s" % ", ".join(
                "$%02X(%s)" % (b, CODIGOS[b][0]) for b in cods))
        else:
            print("    codigos: ninguno")

    print()
    print("=== total ===")
    tot = sum(total.values())
    print("  %d bytes en los 8 flujos" % tot)
    for k in ("DATO+", "DATO-", "CODIGO"):
        print("    %-7s %4d  (%.1f%%)" % (k, total[k], 100.0 * total[k] / tot))
    print()

    print("=== como se lee cada byte ===")
    pos = sorted(b for b in todos if b < 0x80)
    neg = sorted(b - 256 for b in todos if b > 0x84)
    print("  $00..$7F -> desplazamiento POSITIVO, multiplicado por el frame $3(a5)")
    print("             valores presentes: %s" % " ".join(str(v) for v in pos))
    print("  $85..$FF -> desplazamiento NEGATIVO (ext.w), o sea -125..-1")
    print("             valores presentes: %s" % " ".join(str(v) for v in neg))
    print("  $80..$84 -> CODIGOS, no son dato:")
    for b in sorted(CODIGOS):
        print("             $%02X  %-6s %-32s %s" % (b, CODIGOS[b][0], CODIGOS[b][1], CODIGOS[b][2]))
    print()

    print("=== LA PREGUNTA DEL BIT 7 ===")
    print("  Si el bit 7 marcara DOS PLANOS, los $85..$FF serian una segunda")
    print("  magnitud distinta y no habria continuo entre los dos grupos.")
    print("  Los flujos muestran rampas que cruzan el 0 deSigned a unsigned:")
    print("  $0A = 2 -> " + " ".join("%02X" % b for b in rom[0x3A2A2:0x3A2A2 + 9]))
    print("  $0A = 3 -> " + " ".join("%02X" % b for b in rom[0x3A2AC:0x3A2AC + 11]))
    print("  o sea -40 -30 -20 -10 0 +10 +20 +30 +40 y despues $80 (loop).")
    print("  Los dos grupos son las dos MITADES de una sola curva.")


if __name__ == "__main__":
    main()
