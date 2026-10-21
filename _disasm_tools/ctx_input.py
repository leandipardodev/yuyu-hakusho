# -*- coding: utf-8 -*-
"""Rutina de lectura de los puertos de control: donde entra la entrada."""
from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()
md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)

for ini, fin, t in ((0x2500, 0x2580, "lectura de controles"),
                    (0x9480, 0x94E0, "uso de $110(a5)")):
    print("=== %s ===" % t)
    for i in md.disasm(d[ini:fin], ini):
        print("  0x%06X  %-16s %s %s" % (i.address, i.bytes.hex(), i.mnemonic, i.op_str))
    print()
