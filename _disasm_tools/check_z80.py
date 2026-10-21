# -*- coding: utf-8 -*-
"""
Herramienta: comparar el driver Z80 del ROM contra el desensamblado de
referencia (game_z80_driver.asm).

Por que importa: el 68000 copia 3072 bytes desde ROM $0393FE a la RAM del
Z80 y arranca el driver. El juego ESPERA la respuesta del Z80 (handshake
del buzon, 62 comandos). Si el driver esta损坏 o desplazado, la 68000 se
queda esperando para siempre: la pantalla se congela y el juego no pasa
del logo SEGA.

El .asm de referencia tiene los bytes en el espacio de direcciones del Z80
($0000-$0BFF); en el ROM estan en $0393FE.

Uso: python check_z80.py
Salida: stdout. No modifica nada.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom, camino_asm

d = open(ruta_rom(), "rb").read()
ROM_BASE = 0x0393FE

# el .asm del Z80 vive junto al del 68000, en la raiz del repo
ASM_Z80 = os.path.join(os.path.dirname(camino_asm()), "game_z80_driver.asm")

cubre = {}
for ln in io.open(ASM_Z80, encoding="utf-8", errors="replace"):
    m = re.match(r"^([0-9a-fA-F]{4}):\s+((?:[0-9a-fA-F]{2}\s+)+)", ln)
    if not m:
        continue
    z = int(m.group(1), 16)
    hs = m.group(2).split()
    for i, h in enumerate(hs):
        cubre[z + i] = int(h, 16)

print("=== driver Z80: %d bytes con byte known en el .asm de referencia ===" % len(cubre))
print("    (el driver son 3072 bytes en ROM $%06X..$%06X)" % (ROM_BASE, ROM_BASE + 0xC00 - 1))

mal = []
for z, ref in sorted(cubre.items()):
    off = ROM_BASE + z
    if off >= len(d):
        mal.append((z, off, ref, None))
        continue
    real = d[off]
    if real != ref:
        mal.append((z, off, ref, real))

print("  bytes que DIFIEREN: %d" % len(mal))
for z, off, ref, real in mal[:40]:
    print("    Z80 $%04X (ROM $%06X): .asm=$%02X  ROM=%s"
          % (z, off, ref, ("$%02X" % real) if real is not None else "FUERA"))

if not mal:
    print("  -> el driver Z80 del ROM es IDENTICO al de referencia")

# los 3072 bytes completos: son todos codigo o hay relleno?
huecos = [z for z in range(0xC00) if z not in cubre]
print()
print("  bytes del driver SIN decodificar por el .asm: %d de 3072" % len(huecos))
if huecos:
    # agrupa en tramos
    tramos = []
    ini = huecos[0]
    prev = huecos[0]
    for z in huecos[1:]:
        if z != prev + 1:
            tramos.append((ini, prev))
            ini = z
        prev = z
    tramos.append((ini, prev))
    for a, b in tramos[:12]:
        vals = set(d[ROM_BASE + a:ROM_BASE + b + 1])
        etq = "RELLENO $FF" if vals == {0xFF} else ("RUIDO/0x%02X" % min(vals))
        print("    $%04X-$%04X (%3d bytes)  %s" % (a, b, b - a + 1, etq))
