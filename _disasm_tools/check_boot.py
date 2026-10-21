# -*- coding: utf-8 -*-
"""
Herramienta: verificar la parte del ROM que el desensamblado NO cubre y
que el juego necesita en el ARRANQUE:

  - la tabla de vectores 68000 (0x000-0x0FF): el reset, las excepciones y
    el IRQ. Si un vector esta mal, la CPU salta a la basura y se cuelga.
    Los vectores de excepcion del juego apuntan a 'stop #$2700', o sea que
    una excepcion deja la pantalla CONGELADA.
  - la cabecera Sega (0x100-0x1FF).
  - el relleno final.

Se compara contra las dc.l del propio game_68000.asm.

Uso: python check_boot.py
Salida: stdout. No modifica nada.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom, camino_asm

rom = open(ruta_rom(), "rb").read()

# ---------------------------------------------------------------- vectores
dc = {}
for ln in io.open(camino_asm(), encoding="utf-8", errors="replace"):
    m = re.match(r"\s*dc\.l\s+\$([0-9a-fA-F]{8})", ln)
    if m:
        dc[len(dc)] = int(m.group(1), 16)

print("=== 1) tabla de vectores 68000 (%d entradas en el .asm) ===" % len(dc))
mal = 0
for i, v in sorted(dc.items()):
    r = int.from_bytes(rom[i * 4:i * 4 + 4], "big")
    if r != v:
        mal += 1
        if mal <= 8:
            print("  vector %2d @0x%03X: .asm=$%08X  ROM=$%08X" % (i, i * 4, v, r))
print("  vectores que DIFIEREN: %d" % mal)
NOMBRES = {0: "reset(sp)", 1: "reset", 2: "bus/other", 11: "v02", 12: "v03", 13: "v04",
           24: "IRQ", 31: "IRQ(spuria)"}
for i in sorted(dc):
    if i in NOMBRES:
        r = int.from_bytes(rom[i * 4:i * 4 + 4], "big")
        print("    %-10s vector %2d -> $%06X" % (NOMBRES[i], i, r))

# ---------------------------------------------------------------- cabecera
print()
print("=== 2) cabecera Sega ===")
CAMPOS = [(0x100, "consola", 16), (0x110, "copyright", 16), (0x120, "nombre JP", 48),
          (0x150, "nombre INT", 48), (0x180, "serial", 14), (0x18E, "checksum", 2),
          (0x190, "soporte", 16), (0x1A0, "rom start", 4), (0x1A4, "rom end", 4),
          (0x1A8, "ram start", 4), (0x1AC, "ram end", 4), (0x1B0, "backup", 12),
          (0x1BC, "fabricante", 16), (0x1CC, "I/O", 16), (0x1DC, "rom area", 16),
          (0x1EC, "ram area", 16)]
for off, nom, n in CAMPOS:
    raw = rom[off:off + n]
    if nom in ("checksum", "rom start", "rom end", "ram start", "ram end"):
        print("  0x%03X %-12s = $%X" % (off, nom, int.from_bytes(raw, "big")))
    else:
        txt = "".join(chr(x) if 32 <= x < 127 else "." for x in raw)
        print("  0x%03X %-12s = %s" % (off, nom, txt))

# ---------------------------------------------------------------- relleno
print()
print("=== 3) relleno final ===")
n = len(rom)
i = n
while i > 0 and rom[i - 1] == 0xFF:
    i -= 1
print("  ultimo byte no-FF: 0x%06X   (el .asm cubre hasta 0x291ADD)" % (i - 1))
print("  relleno $FF: %d bytes" % (n - i))

# ---------------------------------------------------------------- region Z80
print()
print("=== 4) driver Z80 (0x393FE, 3072 bytes) ===")
z = rom[0x393FE:0x393FE + 16]
print("  primeros bytes: " + " ".join("%02X" % b for b in z))
print("  (F3 = DI, 31 00 nn = LD SP,nn : firma de un driver Z80 real)")
print("  ultimo byte del driver: 0x%02X" % rom[0x393FE + 0xC00 - 1])

# ---------------------------------------------------------------- chequeo
print()
print("=== 5) el codigo de arranque (0x200-0x290) esta en el .asm? ===")
cubre = set()
for ln in io.open(camino_asm(), encoding="utf-8", errors="replace"):
    m = re.match(r"^([0-9a-fA-F]{6}):\s+((?:[0-9a-fA-F]{2}\s+)+)", ln)
    if m:
        a = int(m.group(1), 16)
        for k in range(len(m.group(2).split())):
            cubre.add(a + k)
faltan = [a for a in range(0x200, 0x290) if a not in cubre]
print("  bytes de 0x200-0x290 SIN cubrir por el .asm: %d" % len(faltan))
if faltan:
    print("  tramos: " + ", ".join("0x%06X-0x%06X" % (f, f) for f in faltan[:20]))
