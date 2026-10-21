# -*- coding: utf-8 -*-
"""
Tabla de salto de la entrada y sus handlers.

    0x2578: movea.l $257e(pc, d2.w), a2
    0x257C: jmp (a2)

Es decir: D2 (derivado de los 4 bits de botones) indexa la tabla en 0x257E.
"""
import struct
from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
ROM = ruta_rom()
d = open(ROM, "rb").read()
md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)

# la tabla empieza en 0x257E y la referencia es (pc,d2.w) con pc = 0x257E
print("=== tabla de destinos en 0x257E (longs) ===")
destinos = []
for i in range(16):
    v = struct.unpack(">I", d[0x257E + i * 4:0x257E + i * 4 + 4])[0]
    destinos.append(v)
    print("  [%2d] -> $%06X" % (i, v))
print()
unicos = sorted(set(destinos))
print("destinos distintos: %s" % ", ".join("$%06X" % x for x in unicos))
print()

for t in unicos[:3]:
    print("=== handler $%06X ===" % t)
    n = 0
    for i in md.disasm(d[t:t + 0x80], t):
        print("  0x%06X  %-16s %s %s" % (i.address, i.bytes.hex(), i.mnemonic, i.op_str))
        n += 1
        if i.mnemonic == "rts" or n > 28:
            break
    print()
