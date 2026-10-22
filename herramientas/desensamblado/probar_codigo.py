# -*- coding: utf-8 -*-
"""probar_codigo.py -- EJECUTA codigo 68000 con Unicorn sobre la ROM base
(opcionalmente con un grupo de parches aplicado) y muestra lo que hace.

Sirve para verificar un parche SIN el emulador: se ejecuta el codigo con la
RAM del juego (A5 = el struct del jugador) y se mira lo que han cambiado
el HP, el suelo, la escala...

Uso:
    python herramientas/desensamblado/probar_codigo.py 4EB9001A06F0 --ver
    python herramientas/desensamblado/probar_codigo.py <hex> --hp 5 --ver
    python herramientas/desensamblado/probar_codigo.py --fichero bytes.hex
    python herramientas/desensamblado/probar_codigo.py <hex> --grupo dano_al_cruzar

Opciones:
    --hp N       el HP inicial del jugador 1 (por defecto 223)
    --ver        muestra el HP, el suelo, la escala y el $26
    --slot N     el jugador (1..4) cuyo struct se usa como A5
    --pc N       la direccion donde se mete el codigo (por defecto $200)
    --grupo G    aplica el grupo G del manifiesto a la ROM base antes de
                 ejecutar (asi se prueba el parche entero)
"""
import argparse
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, RAIZ)

try:
    from unicorn import Uc, UcError, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN
    from unicorn.m68k_const import *
except ImportError:
    print("FALTA UNICORN: pip install unicorn")
    sys.exit(2)

BASE_SLOT = 0xFF8400
STRIDE = 0x400
BASE = os.path.join(RAIZ, "rom", "base", "yuyu_makyou_base.bin")


def carga_base(grupo=None):
    """la ROM base, con el grupo del manifiesto aplicado (si lo hay)"""
    rom = bytearray(open(BASE, "rb").read())
    if not grupo:
        return bytes(rom)
    ruta = os.path.join(RAIZ, "datos", "parches.json")
    man = json.load(open(ruta, encoding="utf-8"))["patches"]
    if grupo not in man:
        print("  el grupo '%s' no existe en el manifiesto" % grupo)
        return bytes(rom)
    for b in man[grupo]["bytes"]:
        a = int(b["addr"], 16)
        rom[a] = int(b["new"], 16)
    return bytes(rom)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("codigo", nargs="?", help="el codigo en hexadecimal")
    ap.add_argument("--fichero", help="un fichero con el codigo en hexadecimal")
    ap.add_argument("--hp", type=int, default=223, help="el HP inicial")
    ap.add_argument("--slot", type=int, default=1, help="el jugador (1..4)")
    ap.add_argument("--pc", default="0x200", help="donde se mete el codigo")
    ap.add_argument("--addr", help="toma el codigo del ROM en esa direccion (y lo "
                                   "ejecuta ahi, con el grupo aplicado)")
    ap.add_argument("--largo", type=int, default=24, help="cuantos bytes toma (si --addr)")
    ap.add_argument("--grupo", help="un grupo del manifiesto a aplicar antes")
    ap.add_argument("--ver", action="store_true", help="muestra el estado del jugador")
    args = ap.parse_args()

    rom = carga_base(args.grupo)

    if args.addr:
        pc = int(args.addr, 16)
        codigo = rom[pc:pc + args.largo]
        print("el codigo sale del ROM (con el grupo '%s') en $%06X"
              % (args.grupo or "-", pc))
    else:
        if args.fichero:
            with open(args.fichero, encoding="utf-8") as f:
                hexs = "".join(f.read().split())
        elif args.codigo:
            hexs = "".join(args.codigo.split())
        else:
            ap.print_help()
            return 2
        codigo = bytes.fromhex(hexs)
        pc = int(args.pc, 16)
    a5 = BASE_SLOT + (args.slot - 1) * STRIDE

    uc = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    for inicio, tam in ((0x000000, 0x1000), (0x019000, 0x1000),
                        (0x1A0000, 0x1000), (0xA00000, 0x10000),
                        (0xFF0000, 0x10000)):
        uc.mem_map(inicio, tam)
    # el codigo que se ejecuta, en el banco 1 si el PC esta ahi
    uc.mem_write(0x1A0000, rom[0x1A0000:0x1A1000])
    uc.mem_write(0x019000, rom[0x019000:0x01A000])
    uc.mem_write(0xFF0000, rom[0xFF0000:0x1000000])
    uc.mem_write(pc, codigo)
    uc.mem_write(a5 + 0x78, args.hp.to_bytes(2, "big"))
    uc.reg_write(UC_M68K_REG_PC, pc)
    uc.reg_write(UC_M68K_REG_A7, 0x000F00)
    uc.reg_write(UC_M68K_REG_A5, a5)

    print("ejecutando %d bytes en $%06X (A5 = $%06X, el struct del jugador %d)%s"
          % (len(codigo), pc, a5, args.slot,
             "  [con el grupo '%s']" % args.grupo if args.grupo else ""))
    try:
        uc.emu_start(pc, pc + len(codigo))
    except UcError as e:
        print("  ERROR: %s" % e)
        return 1

    print("  PC=$%06X  d0=%d d1=%d d2=%d" % (uc.reg_read(UC_M68K_REG_PC),
                                                uc.reg_read(UC_M68K_REG_D0),
                                                uc.reg_read(UC_M68K_REG_D1),
                                                uc.reg_read(UC_M68K_REG_D2)))
    if args.ver:
        hp = int.from_bytes(bytes(uc.mem_read(a5 + 0x78, 2)), "big")
        if hp >= 0x8000:
            hp -= 0x10000
        suelo = int.from_bytes(bytes(uc.mem_read(a5 + 0x9C, 4)), "big")
        esc = int.from_bytes(bytes(uc.mem_read(a5 + 0x3E, 2)), "big")
        est = uc.mem_read(a5 + 0x5D, 1)[0]
        mov = uc.mem_read(a5 + 0x5F, 1)[0]
        print("  HP=%d  suelo=$%06X  escala=%d  $26=$%02X  estado=$%02X move=$%02X"
              % (hp, suelo, esc, uc.mem_read(a5 + 0x26, 1)[0], est, mov))
        print("  (el flag del plano $A042 esta en la RAM del Z80: no se puede leer aqui)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
