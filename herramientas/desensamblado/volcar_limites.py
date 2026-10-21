# -*- coding: utf-8 -*-
"""
Determina el limite REAL de cada tabla de moves.

QUE SON DOS COSAS DISTINTAS (esta confusion costo un dia el 2026-10-07):

  - INDICES: hay 195 entradas de word en la tabla indice de $50(a5). Es lo que
    hay en el slot, y el recorrido los cuenta todos.
  - MOVES: hay 191 moves de verdad. El indice 191 vale 0 en LOS DIEZ
    contextos, y offset 0 quiere decir "este move no existe": el registro
    caeria en la propia base, o sea que se estaria leyendo la tabla de
    indices como si fueran frames.

O sea: 195 slots, 191 moves. Las 4 entradas 191..194 del volcado son basura
y hay que podarlas.

El criterio del codigo (mismo que auditar_moves.py): el numero de moves es el
PRIMER indice con offset 0. No "cuantas entradas seguidas tienen un destino
dentro de la region", que es lo que decia la version anterior de este script
y por eso daba 195.

VERIFICADO con auditar_moves.py, que revalida las 1950 entradas del volcado
contra el ROM: 1950 de 1950 coinciden byte a byte. El error era solo el
recorte final, no el desalineado.
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom

ROM = ruta_rom()
d = open(ROM, "rb").read()

CTX = [
    ("ctx0", 0x0BF75A), ("ctx1", 0x0C229A), ("ctx2", 0x0C4EEA), ("ctx3", 0x0C7C9A),
    ("ctx4", 0x0CA6DA), ("ctx5", 0x0CCC7A), ("ctx6", 0x0CF99A), ("ctx7", 0x0D1E5A),
    ("ctx8", 0x0D4A9A), ("ctx9", 0x0D777A),
]

AQUI = os.path.dirname(os.path.abspath(__file__))
SALIDA = os.path.join(AQUI, "limites_tablas.txt")

print("ctx  | base      | indices | moves | datos")
print("-" * 62)

filas = []
for k, (nombre, base) in enumerate(CTX):
    tope = CTX[k + 1][1] if k + 1 < len(CTX) else len(d)

    # 1) cuantos indices hay (slots consecutivos con destino dentro de la region)
    dests = []
    mid = 0
    while True:
        slot = base + mid * 2
        if slot + 2 > tope:
            break
        w = struct.unpack(">H", d[slot:slot + 2])[0]
        dest = base + w
        if not (base <= dest < tope):
            break
        if len(d[dest:dest + 8]) < 8:
            break
        dests.append(dest)
        mid += 1
        if mid > 400:
            break

    # 2) cuantos moves hay de verdad: el primer indice con offset 0
    moves = len(dests)
    for i in range(min(len(dests), 420)):
        w = struct.unpack(">H", d[base + i * 2:base + i * 2 + 2])[0]
        if w == 0:
            moves = i
            break

    if not dests:
        print("%-4s | $%06X  |    0   |   0   |" % (nombre, base))
        continue
    tam = (max(dests) - min(dests)) + 8
    print("%-4s | $%06X  |   %3d  |  %3d  | $%06X-$%06X  ($%04X, %d registros)"
          % (nombre, base, len(dests), moves, min(dests), max(dests), tam, tam // 8))
    filas.append((nombre, base, len(dests), moves, min(dests), max(dests)))

print()
print("=== interpretacion ===")
print("  %d indices y %d moves en total, para los 10 contextos."
      % (sum(f[2] for f in filas), sum(f[3] for f in filas)))
print("  Por contexto: 195 indices y 191 moves. La diferencia son los slots con")
print("  offset 0, que son los moves que NO EXISTEN. Por eso el volcado se poda")
print("  en 191. (El 401 del ctx9 es el tamaño de la tabla de datos mal leido como")
print("  cantidad de moves: un error del 2026-10-07, ya corregido.)")

# El fichero de salida conserva el encabezado (las lineas que empiezan por #)
# que explica todo esto. Un hallazgo perdido no se vuelve a escribir.
encabezado = []
if os.path.isfile(SALIDA):
    for ln in open(SALIDA, encoding="utf-8", errors="replace"):
        if ln.startswith("#"):
            encabezado.append(ln.rstrip("\n"))
        else:
            break

with open(SALIDA, "w", encoding="utf-8", newline="") as f:
    if encabezado:
        f.write("\n".join(encabezado) + "\n")
    if not any("Formato:" in x for x in encabezado):
        f.write("# Formato: ctxN base=$0XXXXXX indices=N moves=M datos=$0XXXXXX-$0XXXXXX\n")
    for nombre, base, nind, nmov, ini, fin in filas:
        f.write("%s base=$%06X indices=%d moves=%d datos=$%06X-$%06X\n"
                % (nombre, base, nind, nmov, ini, fin))

print()
print("guardado en " + SALIDA)
