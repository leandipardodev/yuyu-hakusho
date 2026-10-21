#!/usr/bin/env python3
"""
desensamblador_z80.py - Extrae y desensambla el driver de sonido Z80 de un ROM Genesis.

El driver se localiza leyendo el codigo 68000: la routine de arranque hace
  lea.l <src>(pc), a0
  lea.l $a00000.l, a1      ; RAM Z80
  move.w #n, d0
  move.b (a0)+, (a1)+
  dbra d0, loop
Es decir el driver es la region [src, src+n) del ROM, mapeada a $0000 del Z80.
"""
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
import os, sys, re, struct, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import capstone as cs
from z80_dis import Z80

ROM_MAX = 0x300000


def find_driver(rom):
    """Busca el bucle de copia al RAM Z80 ($a00000) y devuelve (src, len)."""
    md = cs.Cs(cs.CS_ARCH_M68K, cs.CS_MODE_M68K_000 | cs.CS_MODE_BIG_ENDIAN)
    md.detail = True
    best = None
    # el codigo vive en las paginas que sabemos que son 68000 (heuristica: hasta 0x3b000
    # mas las que el vector apunta). Barremos la region baja para ser seguros.
    for a in range(0x200, 0x40000):
        ins = list(md.disasm(rom[a:a + 2], a, count=1))
        if not ins or ins[0].mnemonic != 'lea':
            continue
        # buscar el patron: lea src(pc),a0 ... lea $a00000.l,a1 ... move.w #n,d0 ... move.b (a0)+,(a1)+ ... dbra
        m = re.search(r'\$([0-9a-f]+)\(pc\), a0', ins[0].op_str)
        if not m:
            continue
        disp = int(m.group(1), 16)
        if disp & 0x8000:
            disp -= 0x10000
        src = a + 2 + disp
        # inspeccionar los ~40 bytes siguientes
        seq = list(md.disasm(rom[a:a + 48], a))
        txt = [(i.mnemonic, i.op_str) for i in seq]
        has_a1 = any(mn == 'lea' and 'a1' in op and '$a00000' in op for mn, op in txt)
        cnt = None
        for mn, op in txt:
            if mn == 'move.w' and op.startswith('#$') and ', d0' in op:
                cnt = int(op[2:op.index('x', 2) if 'x' in op[2:] else op.index(',')], 16) + 1
        # mas preciso: tomar el valor del inmediato anterior a dbra
        length = None
        for i, (mn, op) in enumerate(txt):
            if mn == 'move.w' and re.match(r'#\$[0-9a-f]+, d0', op):
                length = int(op[2:op.index(',')], 16) + 1
        has_copy = any(mn == 'move.b' and '(a0)+' in op and '(a1)+' in op for mn, op in txt)
        has_dbra = any(mn == 'dbra' for mn, op in txt)
        if has_a1 and has_copy and has_dbra and length and 0 < src < ROM_MAX:
            if best is None or length > best[1]:
                best = (src, length)
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', nargs='?', default=None,
                help='Ruta del ROM. Si se omite: $YUYU_ROM, luego .rom_path, luego la raiz del repo')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--src', type=lambda s: int(s, 0), default=None)
    ap.add_argument('--len', type=lambda s: int(s, 0), default=None)
    args = ap.parse_args()

    if not args.rom:
        args.rom = ruta_rom()
    raw = open(args.rom, 'rb').read()
    rom = raw[:ROM_MAX] + b'\x00' * max(0, ROM_MAX - len(raw))

    if args.src is not None:
        src, length = args.src, args.len
    else:
        found = find_driver(rom)
        if not found:
            print('[!] no se encontro el bucle de carga del driver Z80')
            return 1
        src, length = found
    print(f'[+] driver Z80: ROM ${src:06x} + ${length:x} ({length} bytes) -> Z80 $0000')

    drv = rom[src:src + length]
    z = Z80(drv)
    N = len(drv)

    # ------- listado lineal (el driver tiene muchos "jp" a offsets absolutos;
    #        tambien Marquemos los objetivos para legibilidad)
    o = []
    w = o.append
    w('; ' + '=' * 74)
    w('; Driver de sonido Z80 (Sega Mega Drive / Genesis)')
    w(f'; ROM offset : ${src:06x}   tamano: {length} bytes (0x{length:x})')
    w('; Cargado por el 68000 a Z80 $0000 (lea src(pc),a0 / lea $a00000.l,a1 / dbra)')
    w('; Desensamblado con z80_dis.py (Capstone no incluye Z80)')
    w('; ' + '=' * 74)
    w('')
    w(f'        org     $0000   ; Z80 address space (driver cargado en RAM Z80)')
    w('')
    w(f'        ; fuente en ROM: ${src:06x}')
    w('')
    pc = 0
    while pc < N:
        try:
            mn, size, flow = z.one(pc)
        except Exception as e:
            mn, size, flow = f'db 0x{drv[pc]:02x}  ; err {e}', 1, ()
        rawb = ' '.join(f'{drv[pc+k]:02x}' for k in range(size) if pc + k < N)
        star = ' ' * (9 + 18)
        w(f'{pc:04x}:  {rawb:<17s}  {mn}')
        pc += size if size > 0 else 1
    w('        end')
    open(args.out, 'w', encoding='utf-8').write('\n'.join(o) + '\n')

    # resumen de demasiados db
    ndb = sum(1 for l in o if ' db 0x' in l)
    print(f'[+] lineas     : {len(o)}   (con "db" sin decodificar: {ndb})')
    print(f'[+] output     : {args.out}')


if __name__ == '__main__':
    sys.exit(main())
