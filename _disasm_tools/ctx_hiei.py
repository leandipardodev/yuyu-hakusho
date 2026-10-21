# -*- coding: utf-8 -*-
"""
Herramienta: quien salta a una direccion, con contexto.

Que hace:
  1. Parsea game_68000.asm.
  2. Busca todas las instrucciones cuyo destino (bra/bsr/jsr/jmp) sea
     la direccion pedida.
  3. Imprime cada una con las 8 instrucciones anteriores (para ver el
     test que decide entrar ahi) y con la direccion de la rama siguiente
     (para saber si es una llamada o un salto).

Uso:  python ctx_hiei.py <hexaddr> [n_contexto]
Salida: stdout. No modifica nada.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import camino_asm

RE_LINEA = re.compile(
    r"^([0-9a-fA-F]{6}):\s+((?:[0-9a-fA-F]{2}\s+)+)\s*([a-z][a-z0-9.]*)?\s*(.*?)\s*$")
RE_DST = re.compile(r"\$([0-9a-fA-F]+)")

insns = []
for ln in open(camino_asm(), encoding="utf-8", errors="replace"):
    m = RE_LINEA.match(ln)
    if not m:
        continue
    addr = int(m.group(1), 16)
    mn = (m.group(3) or "").strip()
    op = (m.group(4) or "").strip()
    if not mn:
        continue
    insns.append((addr, mn, op))

idx = {a: n for n, (a, _, _) in enumerate(insns)}

if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(1)

OBJ = int(sys.argv[1], 16)
NCON = int(sys.argv[2]) if len(sys.argv) > 2 else 8

print("=== llamadores de 0x%06X ===" % OBJ)
print()

n = 0
for k, (a, mn, op) in enumerate(insns):
    if mn not in ("bra", "bra.w", "bra.b", "bsr", "bsr.w", "bsr.b",
                  "jsr", "jmp", "jmp.l", "rts", "bne", "beq", "blt", "bgt",
                  "bcc", "bcs", "bmi", "bpl", "bhi", "bls", "bvc", "bvs"):
        continue
    m = RE_DST.search(op)
    if not m:
        continue
    dst = int(m.group(1), 16)
    if dst != OBJ:
        continue
    n += 1
    ini = max(0, k - NCON)
    print("--- #%d  @0x%06X  (%s %s) ---" % (n, a, mn, op))
    for i in range(ini, k):
        aa, mm, oo = insns[i]
        print("    %06X  %-8s %s" % (aa, mm, oo))
    # que hay justo despues (siguiente rama del bloque)
    if k + 1 < len(insns):
        aa, mm, oo = insns[k + 1]
        print("    %06X  %-8s %s   <-- siguiente" % (aa, mm, oo))
    print()

print("total de llamadores: %d" % n)
