# -*- coding: utf-8 -*-
"""
Cruce input -> ID de move.

Las rutina de 0x1845A a 0x18604 escriben los IDs 1..8 de forma secuencial,
asi que ahi deberia estar el reconocimiento de entrada: que boton/direccion
produce que estado.
"""
from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()
md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)

for ini, fin, t in ((0x18440, 0x18480, "ID 1 y 2"),
                    (0x184B0, 0x18560, "IDs 3, 4, 5"),
                    (0x18590, 0x18620, "IDs 6, 7, 8")):
    print("=== %s ===" % t)
    for i in md.disasm(d[ini:fin], ini):
        print("  0x%06X  %-16s %s %s" % (i.address, i.bytes.hex(), i.mnemonic, i.op_str))
    print()
