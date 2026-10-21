#!/usr/bin/env python3
"""
rommap.py - Clasifica el ROM de Mega Drive por paginas de 4KB (codigo / datos /
graficos / audio) usando entropia y contenido, para orientar donde esta cada cosa.
"""
import os, sys, argparse, collections, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom

ROM_MAX = 0x300000

def entropy(blk):
    c = collections.Counter(blk)
    n = len(blk)
    return -sum((v/n)*math.log2(v/n) for v in c.values())

def note_for(base, ent, blk, code_pages):
    if all(b == 0xFF for b in blk): return 'padding $ff'
    if all(b == 0x00 for b in blk): return 'padding $00'
    if base == 0x000: return 'vectores 68k + cab. Sega'
    if base == 0x100: return 'cabecera Sega'
    if base >> 12 in code_pages: return 'CODIGO 68k'
    if 0x393F0 <= base <= 0x39400: return 'driver Z80'
    if ent < 3.0: return 'datos dispersos'
    if ent > 7.5: return 'graficos/comprimido (VDP)'
    if 4.0 <= ent <= 6.5: return 'tiles / datos VDP'
    return 'mixto'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', nargs='?', default=None,
                help='Ruta del ROM. Si se omite: $YUYU_ROM, luego .rom_path, luego la raiz del repo')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--pages-csv', default=None, help='CSV de paginas con codigo')
    args = ap.parse_args()
    if not args.rom:
        args.rom = ruta_rom()
    raw = open(args.rom, 'rb').read()
    rom = raw[:ROM_MAX] + b'\x00' * max(0, ROM_MAX - len(raw))

    code_pages = set()
    if args.pages_csv and os.path.exists(args.pages_csv):
        for line in open(args.pages_csv):
            if line.startswith('pagina'): continue
            code_pages.add(int(line.split(',')[0], 16) >> 12)

    out = []
    w = out.append
    w('=' * 84)
    w('  MAPA DEL ROM  --  Yu Yu Hakusho: Makyou Toitsusen (J)   [Sega Mega Drive]')
    w('  Archivo : %s   %d bytes (%.2f MB)' % (os.path.basename(args.rom), len(raw), len(raw)/1048576))
    w('  Titulo  : YUYU HAKUSYO    Serial: GM G-004122-00    Region: J (Japan)    1994.JUL')
    w('=' * 84)
    w('')
    w('  %-10s %-9s %-8s %-8s %s' % ('pagina', 'entropia', 'zeros%', 'ff%', 'clasificacion'))
    w('  ' + '-' * 80)
    for base in range(0, ROM_MAX, 0x1000):
        blk = rom[base:base + 0x1000]
        ent = entropy(blk)
        z = 100*blk.count(0)/len(blk)
        f = 100*blk.count(0xFF)/len(blk)
        note = note_for(base, ent, blk, code_pages)
        if note in ('padding $ff', 'padding $00') and ent == 0:
            # omitir paginas totalmente vacias paraOEM
            continue
        w('  0x%06x   %5.2f     %4.0f    %4.0f   %s' % (base, ent, z, f, note))
    w('')
    open(args.out, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print('[+] mapa escrito: %s (%d lineas)' % (args.out, len(out)))

if __name__ == '__main__':
    main()
