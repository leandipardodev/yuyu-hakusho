# -*- coding: utf-8 -*-
"""
Herramienta: puntos de creacion de objetos y bucles que los repiten.

Los proyectiles, ondas y "manos flotantes" son OBJETOS: el 68000 reserva
uno del pool (16 objetos, 16 bytes cada uno) en la rutina $1FA96 y le
pone un handler segun $58(a0). Cada handler define su propia tabla de
moves ($50), su grafico ($1C) y sus flags ($24).

Este script lista cada llamada a una rutina de creacion, con el contexto,
y marca las que estan dentro de un bucle (recreacion periodica).

Uso: python obj_spawn.py
Salida: stdout. No modifica nada.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import camino_asm

RE = re.compile(r"^([0-9a-fA-F]{6}):\s+((?:[0-9a-fA-F]{2}\s+)+)\s*([a-z][a-z0-9.]*)?\s*(.*?)\s*$")
DST = re.compile(r"\$([0-9a-fA-F]{6})")

insns = []
for ln in io.open(camino_asm(), encoding="utf-8", errors="replace"):
    m = RE.match(ln)
    if not m:
        continue
    mn = (m.group(3) or "").strip()
    if not mn:
        continue
    insns.append((int(m.group(1), 16), mn, (m.group(4) or "").strip()))

print("instrucciones leidas: %d" % len(insns))

llamadas = []
for k, (a, mn, op) in enumerate(insns):
    if mn not in ("jsr", "bsr"):
        continue
    m = DST.search(op)
    if not m:
        continue
    d = int(m.group(1), 16)
    if not (0x01FA96 <= d <= 0x020400):
        continue
    # el llamador esta en un bucle si alguna instruccion previa salta
    # hacia atras (a una direccion <= la del llamador)
    en_bucle = False
    for j in range(max(0, k - 40), k):
        aj, mnj, opj = insns[j]
        if mnj[:3] in ("bra", "bsr") or mnj[:1] == "b":
            mm = DST.search(opj)
            if mm and int(mm.group(1), 16) <= a:
                en_bucle = True
                break
    llamadas.append((a, d, en_bucle, k))

print("puntos de creacion de objeto: %d" % len(llamadas))
print()
for a, d, loop, k in llamadas:
    print("--- 0x%06X -> $%06X  %s" % (a, d, "[EN BUCLE]" if loop else ""))
    ini = max(0, k - 9)
    for i in range(ini, min(k + 3, len(insns))):
        aa, mm, op = insns[i]
        print("    %06X  %-8s %s%s" % (aa, mm, op, "   <<<" if i == k else ""))
    print()

print("=== creadores DENTRO de un bucle ===")
for a, d, loop, k in llamadas:
    if loop:
        print("  0x%06X -> $%06X" % (a, d))
