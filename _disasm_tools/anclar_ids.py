# -*- coding: utf-8 -*-
"""
Ancla los IDs de move: extrae TODOS los valores inmediatos que el juego
escribe o compara contra $5f(a5), que es el identificador de estado/move.

    python anclar_ids.py [desensamblado]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import camino_asm

import re
import sys
import io
from collections import Counter

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ASM = sys.argv[1] if len(sys.argv) > 1 else \
    camino_asm()

texto = open(ASM, encoding="utf-8", errors="replace").read()

# move.b #$xx, $5f(a5)      -> escritura
esc = re.compile(r"^([0-9a-f]{6}):.*move\.b\s+#\$([0-9a-f]{1,2}),\s*\$5f\(a5\)", re.I | re.M)
# cmpi.b #$xx, $5f(a5)     -> comparacion
cmp = re.compile(r"^([0-9a-f]{6}):.*cmpi\.b\s+#\$([0-9a-f]{1,2}),\s*\$5f\(a5\)", re.I | re.M)

escritos = Counter()
lugares = {}
for m in esc.finditer(texto):
    v = int(m.group(2), 16)
    escritos[v] += 1
    lugares.setdefault(v, []).append(m.group(1))

comparados = Counter()
cmploc = {}
for m in cmp.finditer(texto):
    v = int(m.group(2), 16)
    comparados[v] += 1
    cmploc.setdefault(v, []).append(m.group(1))

todos = sorted(set(escritos) | set(comparados))

print("=== IDs de move usados contra $5F(a5) ===")
print(" id | escrituras | comparaciones | total | primeras direcciones")
print("-" * 78)
for v in todos:
    e = escritos.get(v, 0)
    c = comparados.get(v, 0)
    dirs = (lugares.get(v, []) + cmploc.get(v, []))[:3]
    print(" %2d |    %3d     |     %3d      |  %3d  | %s"
          % (v, e, c, e + c, ", ".join("0x" + x.upper() for x in dirs)))
print()
print("rango: %d .. %d   (%d IDs distintos)"
      % (min(todos), max(todos), len(todos)))
print("IDs solo comparados (sin escritura directa): %s"
      % ", ".join(str(v) for v in sorted(set(comparados) - set(escritos))))
print("IDs solo escritos: %s"
      % ", ".join(str(v) for v in sorted(set(escritos) - set(comparados))))
