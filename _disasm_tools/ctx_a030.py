# -*- coding: utf-8 -*-
"""Contexto de los valores 125/166 escritos en $A030 (posibles duraciones)."""
from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()
md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)

tramos = [
    (0xF5C0, 0xF600, "lector de A030"),
    (0x1A0C8, 0x1A0F0, "setea 125 (0x7D)"),
    (0x1A4F0, 0x1A512, "setea 166 (0xA6)"),
    (0x1EB80, 0x1EB98, "b4 -> tabla 218D8 -> A030"),
]
for ini, fin, t in tramos:
    print("=== %s ===" % t)
    for i in md.disasm(d[ini:fin], ini):
        print("  0x%06X  %-14s %s %s" % (i.address, i.bytes.hex(), i.mnemonic, i.op_str))
    print()
