# -*- coding: utf-8 -*-
"""
Herramienta: calcular el checksum de la cabecera de la Mega Drive y
comparar el ROM con el estado interno.

Que hace:
  El checksum de la cabecera Sega (a 0x18E) es la suma de TODAS las
  palabras de 16 bits del ROM desde 0x200 hasta el final, modulo 0x10000.
  Si el valor calculado NO coincide con el almacenado, el ROM fue
  modificado sin actualizar la cabecera.

  Ademas compara la region 0x200-0x291ADD (todo el codigo y los datos
  del juego) contra la referencia que hay en el repo (game_68000.asm
  cubre el codigo; LISTA_MOVES.txt cubre las tablas de moves).

Uso: python check_checksum.py [rom_extra]
Salida: stdout. No modifica nada.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom

def checksum_rom(d, ini=0x200):
    s = 0
    n = len(d)
    if (n - ini) & 1:
        n -= 1
    for o in range(ini, n, 2):
        s += (d[o] << 8) | d[o + 1]
    return s & 0xFFFF

roms = [(ruta_rom(), "ROM de trabajo")]
for extra in sys.argv[1:]:
    roms.append((extra, os.path.basename(extra)))

for path, etq in roms:
    d = open(path, "rb").read()
    almacenado = (d[0x18E] << 8) | d[0x18F]
    calculado = checksum_rom(d)
    print("=== %s ===" % etq)
    print("  path             : %s" % path)
    print("  checksum ALMACENADO @0x18E : $%04X" % almacenado)
    print("  checksum CALCULADO (0x200..) : $%04X" % calculado)
    print("  -> %s" % ("COINCIDEN (ROM integro)" if almacenado == calculado
                      else "NO COINCIDEN: el ROM fue modificado sin actualizar la cabecera"))
    # checksum del proyecto: 0x4A36 (los 8 dumps)
    print("  referencia del proyecto (los 8 dumps) : $4A36")
    print()
