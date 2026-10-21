# -*- coding: utf-8 -*-
"""
Herramienta: calcular y escribir el checksum de la cabecera Sega.

El checksum de la cabecera (0x18E, 2 bytes) es la suma de TODAS las palabras
de 16 bits del ROM desde 0x200 hasta el final, modulo 0x10000.

Da dos cosas:
  1. el valor CALCULADO, para comparar con el almacenado y saber si el ROM
     fue modificado sin actualizar la cabecera;
  2. un parche que escribe el valor correcto, para dejar la cabecera
     consistente.

Ojo: en este juego el checksum esta obsoleto en TODOS los dumps conocidos
(INFORME_RE.md: "ninguno lo recalcula... indicio de que el header no se
actualizo tras las modificaciones"), asi que un checksum que no cuadra NO
significa por si solo que el ROM este roto. Sirve como indicador, no como
veredicto.

Uso:  python check_checksum.py [rom_extra]     # solo informa
       python fix_checksum.py <entrada> <salida>
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom


def checksum(d, ini=0x200):
    s = 0
    n = len(d)
    if (n - ini) & 1:
        n -= 1
    for o in range(ini, n, 2):
        s += (d[o] << 8) | d[o + 1]
    return s & 0xFFFF


def main():
    if len(sys.argv) > 1:
        entrada, salida = sys.argv[1], sys.argv[2]
        d = bytearray(open(entrada, "rb").read())
        viejo = (d[0x18E] << 8) | d[0x18F]
        nuevo = checksum(d)
        d[0x18E] = (nuevo >> 8) & 0xFF
        d[0x18F] = nuevo & 0xFF
        with open(salida, "wb") as f:
            f.write(d)
        d2 = open(salida, "rb").read()
        if (d2[0x18E] << 8) | d2[0x18F] != nuevo:
            print("!! ERROR: el checksum no quedo escrito")
            sys.exit(1)
        print("checksum @0x18E: $%04X -> $%04X   (verificado en la salida)" % (viejo, nuevo))
        print("escrito: %s" % salida)
        return

    for path in [ruta_rom()] + sys.argv[1:]:
        d = open(path, "rb").read()
        alm = (d[0x18E] << 8) | d[0x18F]
        cal = checksum(d)
        print("%s" % path)
        print("   almacenado $%04X   calculado $%04X   %s"
              % (alm, cal, "OK" if alm == cal else "NO CUADRA"))
        print("   (referencia del proyecto: $4A36 en los 8 dumps)")


if __name__ == "__main__":
    main()
