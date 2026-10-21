# -*- coding: utf-8 -*-
"""
Corrida larga del emulador: deja que el juego termine de inicializar y
volca la VRAM/CRAM en cuanto haya graficos.

Escribe progreso en Progreso.txt para poder mirarlo sin stopping nada.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import dir_sprites

import sys
import os
import time
import struct

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
os.environ["M68K_FAST"] = "1"

import emulador_68000 as G
from unicorn.m68k_const import UC_M68K_REG_PC

SALIDA = dir_sprites()
LOG = os.path.join(AQUI, "Progreso.txt")


def nota(msg):
    linea = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(linea)
    sys.stdout.flush()
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(linea + "\n")


def rd(e, a, n):
    return bytes(e.uc.mem_read(a & 0xFFFFFF, n))


def main():
    open(LOG, "w", encoding="utf-8").close()
    nota("inicio de la corrida larga (modo rapido)")
    e = G.Gen68k(verbose=False)
    t0 = time.time()
    InstructionBudget = 300_000_000
    gastado = 0
    for ronda in range(400):
        lote = 5_000_000
        try:
            e.run(frames=20, irqs_per_frame=1, max_chunk_total=lote)
        except Exception as ex:
            nota("excepcion en la ronda %d: %s" % (ronda, ex))
        gastado += lote
        vram = sum(1 for b in e.vdp.vram if b)
        cram = sum(1 for b in e.vdp.cram if b)
        f554 = struct.unpack(">H", rd(e, 0xF554, 2))[0]
        f552 = struct.unpack(">H", rd(e, 0xF552, 2))[0]
        pc = e.uc.reg_read(UC_M68K_REG_PC)
        nota("ronda %3d | cola %5d/%-5d | frames %4d | vram %6d | cram %3d "
             "| buzon %4d | PC %06X | %.0fs"
             % (ronda, f554, f552, e.frame, vram, cram, e.z80_cmds, pc,
                time.time() - t0))
        if vram > 0:
            nota(">>> HAY GRAFICOS. Volcando.")
            os.makedirs(SALIDA, exist_ok=True)
            open(os.path.join(SALIDA, "emul_vram.bin"), "wb").write(bytes(e.vdp.vram))
            open(os.path.join(SALIDA, "emul_cram.bin"), "wb").write(bytes(e.vdp.cram))
            for k, v in e.vdp.report().items():
                nota("    %-14s %s" % (k, v))
            nota("RUTA:%s" % os.path.join(SALIDA, "emul_vram.bin"))
            return 0
        if gastado > InstructionBudget:
            nota("presupuesto de instrucciones agotado")
            return 1
    nota("se agotaron las rondas sin ver graficos")
    return 1


if __name__ == "__main__":
    sys.exit(main())
