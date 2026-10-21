# -*- coding: utf-8 -*-
"""
Herramienta: desensamblar los HUECOS del desensamblado (zonas que el
barrido lineal no pudo decodificar) y buscar quien llama a una rutina.

Por que: muchas rutinas importantes (los setups de objeto, los handlers
de los proyectiles) caen en huecos del .asm y no se ven. Aqui se
descubren por fuerza bruta: se prueban todos los puntos de inicio
posibles de una zona hasta que Capstone decodifique una secuencia valida
de N instrucciones.

Uso:
  python hueco.py 14090 140D4      # desensambla esa zona
  python hueco.py --call 140D4      # quien llama a esa direccion (en TODO el ROM)

Salida: stdout. No modifica nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom

from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN, CS_MODE_M68K_020

d = open(ruta_rom(), "rb").read()
md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN | CS_MODE_M68K_020)


def mejor_desensamblado(ini, fin, minimo=6):
    """Prueba todos los inicios posibles y se queda con el que mas
    instrucciones consecutivas decode."""
    mejor = None
    for off in range(ini, fin):
        try:
            ins = list(md.disasm(d[off:fin], off))
        except Exception:
            continue
        if len(ins) < minimo:
            continue
        # exige que las direcciones sean contiguas
        cont = True
        for i in range(1, len(ins)):
            if ins[i].address != ins[i - 1].address + ins[i - 1].size:
                cont = False
                break
        if not cont:
            continue
        if mejor is None or len(ins) > len(mejor[1]):
            mejor = (off, ins)
    return mejor


if sys.argv[1] == "--call":
    destino = int(sys.argv[2], 16)
    print("=== quien llama a 0x%06X (bsr/jsr/jmp) en todo el ROM ===" % destino)
    n = 0
    for off in range(0, len(d) - 3):
        # bsr.w = 61 00, jsr.l = 4e b9 00 00 00 00, jmp.l = 4e f9 ...
        if d[off] == 0x61 and d[off + 1] == 0x00:
            disp = (d[off + 2] << 8) | d[off + 3]
            if disp >= 0x8000:
                disp -= 0x10000
            tgt = off + 2 + 2 + disp
            if tgt == destino:
                print("  0x%06X  bsr.w $%06X" % (off, destino))
                n += 1
        elif d[off] == 0x4E and d[off + 1] == 0xB9:
            v = int.from_bytes(d[off + 2:off + 6], "big")
            if v == destino:
                print("  0x%06X  jsr.l $%06X" % (off, destino))
                n += 1
    print("  total: %d" % n)
    sys.exit(0)

ini = int(sys.argv[1], 16)
fin = int(sys.argv[2], 16)
print("=== hueco 0x%06X-0x%06X ===" % (ini, fin))
mejor = mejor_desensamblado(ini, fin)
if not mejor:
    print("  no se pudo decodificar")
    sys.exit(0)
off, ins = mejor
print("  mejor inicio: 0x%06X  (%d instrucciones)\n" % (off, len(ins)))
for i in ins:
    print("  %06X  %-8s %s" % (i.address, i.mnemonic, i.op_str))
