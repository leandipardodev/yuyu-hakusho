#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mapea todas las tablas de parametros del juego.

Busca el idioma que usa el juego para cargar un valor de una tabla al struct
del jugador:

    lea.l  $D282.l, a0
    move.w (a0, d0.w), $28(a5)

Y agrupa por (direccion de tabla, offset destino). Las tablas de 11 entradas
siguen siendo por personaje; las de 12, por estado.

    python mapear_tablas.py [desensamblado]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import camino_asm

import sys
import re
from collections import defaultdict

ASM = sys.argv[1] if len(sys.argv) > 1 else \
    camino_asm()

pat_addr = re.compile(r"lea\.l\s+\$([0-9a-f]+)\.l,\s*(a0|a1|a2|a3)", re.I)
pat_idx  = re.compile(r"move\.(b|w|l)\s+\((\$?[0-9a-f]+)?(?:,\s*)?(a0|a1|a2|a3)\s*,\s*d(\d+)\.w\)\s*,\s*\$?([0-9a-f]+)\(a5\)", re.I)
pat_idx2 = re.compile(r"move\.(b|w|l)\s+\((\$?[0-9a-f]+)?(?:,\s*)?(a0|a1|a2|a3)\s*,\s*d(\d+)\.w\)\s*,\s*\$?([0-9a-f]+)\(a5\)", re.I)
pat_lea_d = re.compile(r"lea\.(l|w)\s+d(\d+)\s*,\s*(a0|a1|a2|a3)", re.I)

lineas = open(ASM, encoding="utf-8", errors="replace").read().split("\n")
limpio = []
for l in lineas:
    if ":" in l and len(l.split(":", 1)[0].strip()) <= 6:
        limpio.append(l.split(":", 1)[1].strip())
    else:
        limpio.append(l)

tablas = defaultdict(list)   # (addr, offset) -> [(addr_linea, tam)]
reg_actual = None
for i, l in enumerate(limpio):
    m = pat_addr.search(l)
    if m:
        reg_actual = (int(m.group(1), 16), m.group(2))
        continue
    m2 = pat_idx.search(l)
    if m2 and reg_actual:
        tam = m2.group(1)
        reg = m2.group(3)
        if reg.lower() == reg_actual[1].lower():
            off = int(m2.group(5), 16)
            tablas[(reg_actual[0], off)].append(i)
        continue

print("tablas cargadas al struct del jugador (base, offset destino):")
print("-" * 78)
for (addr, off), pos in sorted(tablas.items()):
    tam = ''
    print("  base $%06X -> $%02X(a5)   %d carga(s)" % (addr, off, len(pos)))
    print("       indices de linea: %s" % ", ".join(str(p) for p in pos[:8]))
