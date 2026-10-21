#!/usr/bin/env python3
"""
assets.py - Extraccion de assets de un ROM de Sega Mega Drive / Genesis.

Genera:
  - *_palettes.png   : paletas de 64 colores (CRAM 9-bit) como franjas PNG
  - *_tiles_*.png    : hojas de tiles 8x8 4bpp renderizados
  - *_adpcm_*.wav    : muestras ADPCM de Genesis decodificadas a WAV
  - *_region_*.bin   : volcados crudos de regiones de datos

Notas:
  - Tile 4bpp del VDP: 8x8 pixeles, 16 pixeles de 4 bits por fila = 8 bytes
    por fila * 8 filas = 32 bytes por tile.
  - Color CRAM Genesis: 16 bits, 3 bits por canal. layout del byte en VRAM:
    byte0 = --BBBBBB (azul 6->3), byte1 = --GGGGRRRR -> realmente:
    palabra = 0CCCRRR GGG BBBBB (rojo bits 1-3, verde 4-6, azul 7-9).
    Usamos: R=(w>>1)&7, G=(w>>5)&7, B=(w>>9)&7.
  - ADPCM Genesis (YM2610 PSG): 1 byte -> 2 muestras de 4 bits (nibbles),
    lookup de 16 pasos signed (-6..+6) tipicamente 3->13.
"""
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
import os, sys, struct, math, argparse
import capstone as cs
from PIL import Image

ROM_MAX = 0x300000

# tabla ADPCM PSG estandar de Genesis (valores signed para nivel 0..15)
PSG_TABLE = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, -7, -6]


def gen_color(word):
    """Convierte una palabra CRAM de 16 bits a (r,g,b) 0-255."""
    # El hardware: bit15-14 = 0, rojo = bits 1-3, verde = bits 4-6, azul = bits 7-9
    # (lineal de 9 bits: --BBB GGG RRR con R en bits bajos)
    r = (word >> 1) & 0x7
    g = (word >> 5) & 0x7
    b = (word >> 9) & 0x7
    # (algunos dumps usan el layout estandar 0BBBGGGRRR en bits 1-9)
    return (r * 255 // 7, g * 255 // 7, b * 255 // 7)


def find_palettes(rom):
    """Busca bloques de paleta de 16 colores (64 palabras CRAM de 16 bits).
    Genesis: palabra = 0 0 0 0 0 0 0 0 BBB GGG RRR -> 9 bits, R en bits 1-3.
    Exige: >=10 colores distintos, usa >=2 canales, y no es un degradado
    trivial (para evitar LUTs de fade)."""
    cands = []
    i = 0x200
    n = len(rom)
    while i < n - 64:
        vals = []
        for k in range(0, 64, 2):
            w = struct.unpack('>H', rom[i + k:i + k + 2])[0]
            vals.append(((w >> 1) & 7, (w >> 5) & 7, (w >> 9) & 7))
        nz = sum(1 for r, g, b in vals if r or g or b)
        distinct = len(set(vals))
        channels = len(set(c for r, g, b in vals for c in (r, g, b) if c > 0))
        if nz >= 12 and 10 <= distinct <= 16 and channels >= 3:
            cands.append(i)
            i += 64
        else:
            i += 2
    return cands


def render_tiles_4bpp(rom, off, length, palette, out_png, cols=16, label=''):
    """Renderiza tiles 4bpp de 8x8 a una hoja PNG con la paleta dada."""
    tiles = length // 32


def render_tiles_correct(rom, off, length, palette, out_png, cols=16, label=''):
    tiles = length // 32
    rows = (tiles + cols - 1) // cols
    img = Image.new('RGB', (cols * 8, max(rows, 1) * 8), (16, 16, 16))
    px = img.load()
    for t in range(tiles):
        base = off + t * 32
        if base + 32 > len(rom):
            break
        tx = (t % cols) * 8
        ty = (t // cols) * 8
        for y in range(8):
            # 4bpp: 8 pixeles por fila * 4 bits = 4 bytes por fila
            for byte_i in range(4):
                byte = rom[base + y * 4 + byte_i]
                hi = (byte >> 4) & 0xF
                lo = byte & 0xF
                c_hi = palette[hi] if hi < len(palette) else (255, 0, 255)
                c_lo = palette[lo] if lo < len(palette) else (255, 0, 255)
                px[tx + byte_i * 2,     ty + y] = c_hi
                px[tx + byte_i * 2 + 1, ty + y] = c_lo
    img.save(out_png)
    return tiles


def decode_adpcm_genesis(data, max_samples=1 << 20):
    """Decodifica ADPCM PSG de Genesis (1 byte -> 2 samples de 4 bits)."""
    out = bytearray()
    value = 0
    step = 0
    count = 0
    for byte in data:
        for nib in ((byte >> 4) & 0xF, byte & 0xF):
            delta = PSG_TABLE[nib]
            value = max(-2048, min(2047, value + delta * step))
            out.append((value >> 4) & 0xFF)   # ~12->8 bits
            step = min(127, step + (1 if delta > 0 else -1) * 2)
            step = max(0, step)
            count += 1
            if count >= max_samples:
                return bytes(out)
    return bytes(out)


def write_wav(path, samples, rate=32000):
    import wave
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(rate)
        w.writeframes(samples)


def default_palette():
    # paleta por defecto tipo Genesis (grises/azules) para previsualizar
    pal = []
    for i in range(16):
        v = int(i * 255 / 15)
        pal.append((v, v, v))
    return pal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', nargs='?', default=None,
                help='Ruta del ROM. Si se omite: $YUYU_ROM, luego .rom_path, luego la raiz del repo')
    ap.add_argument('-d', '--outdir', default='assets')
    args = ap.parse_args()
    if not args.rom:
        args.rom = ruta_rom()
    raw = open(args.rom, 'rb').read()
    rom = raw[:ROM_MAX] + b'\x00' * max(0, ROM_MAX - len(raw))
    os.makedirs(args.outdir, exist_ok=True)
    log = []

    # ---------- paletas ----------
    pals = find_palettes(rom)
    log.append(f'[+] paletas candidatas (16 colores): {len(pals)}')

    # hoja de contacto: cada paleta en su propia fila (16 squares de 24x24)
    if pals:
        cell = 24
        cols = min(16, len(pals))
        rows = (len(pals) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * 16 * cell, rows * cell), (24, 24, 24))
        spx = sheet.load()
        for idx, poff in enumerate(pals):
            pal = [gen_color(struct.unpack('>H', rom[poff+k*2:poff+k*2+2])[0]) for k in range(16)]
            for k in range(16):
                x0 = (idx % cols) * 16 * cell + k * cell
                y0 = (idx // cols) * cell
                for yy in range(cell):
                    for xx in range(cell):
                        spx[x0+xx, y0+yy] = pal[k]
        sheet.save(os.path.join(args.outdir, 'palettes_contact_sheet.png'))
    # dump binario + individual pngs (primeros 60)
    with open(os.path.join(args.outdir, 'palettes.bin'), 'wb') as f:
        for poff in pals:
            f.write(struct.pack('<I', poff))
            f.write(rom[poff:poff + 64])
    for idx, poff in enumerate(pals[:60]):
        pal = [gen_color(struct.unpack('>H', rom[poff+k*2:poff+k*2+2])[0]) for k in range(16)]
        img = Image.new('RGB', (16 * 16, 16))
        px = img.load()
        for k in range(16):
            for yy in range(16):
                for xx in range(16):
                    px[k*16+xx, yy] = pal[k]
        img.save(os.path.join(args.outdir, f'palette_{poff:06x}.png'))

    # para renderizar tiles usamos la paleta mas "plausible": la que mas
    # colores distintos y mas balancing de canales. Usamos la primera robusta.
    pal = default_palette()
    bestpal = None
    for poff in pals:
        pal_c = [gen_color(struct.unpack('>H', rom[poff+k*2:poff+k*2+2])[0]) for k in range(16)]
        # score: variedad + saturacion media
        sat = sum(max(c) for c in pal_c) / 16
        distinct = len(set(pal_c))
        score = distinct + sat / 255
        if bestpal is None or score > bestpal[0]:
            bestpal = (score, pal_c, poff)
    if bestpal:
        pal = bestpal[1]
        log.append(f'[+] paleta usada para tiles: 0x{bestpal[2]:06x} (score {bestpal[0]:.1f})')

    # ---------- tiles: muestra varias regiones graficas ----------
    # regiones de baja entropia grandes (4bpp tiles tipicamente ent ~4)
    import collections
    def ent(b):
        c = collections.Counter(b); n = len(b)
        return -sum((v/n)*math.log2(v/n) for v in c.values())
    # tomar bloques de 0x8000 en zona de grafica
    samples = []
    for base in range(0xE0000, 0x290000, 0x8000):
        blk = rom[base:base+0x8000]
        e = ent(blk)
        if 3.6 <= e <= 5.2:
            samples.append((base, e))
    log.append(f'[+] bloques 4bpp candidatos: {len(samples)}')
    for base, e in samples[:12]:
        n = render_tiles_correct(rom, base, 0x8000, pal,
                                  os.path.join(args.outdir, f'tiles_{base:06x}.png'),
                                  cols=32, label=f'ent={e:.2f}')
        # dump crudo
        with open(os.path.join(args.outdir, f'tiles_{base:06x}.bin'), 'wb') as f:
            f.write(rom[base:base+0x8000])

    # ---------- audio ADPCM ----------
    # muestras tipicasGenesis ADPCM: alta entropia, ~1 byte->2 samples
    audio_blocks = []
    for base in range(0x3B000, 0x4A000, 0x2000):
        blk = rom[base:base+0x2000]
        e = ent(blk)
        if e > 5.5:
            audio_blocks.append((base, e))
    log.append(f'[+] bloques audio ADPCM candidatos: {len(audio_blocks)}')
    for base, e in audio_blocks[:8]:
        smp = decode_adpcm_genesis(rom[base:base+0x2000])
        write_wav(os.path.join(args.outdir, f'sample_{base:06x}.wav'), smp)

    # ---------- volcados de regiones de datos ----------
    regions = [
        (0x24000, 0x35000, 'data_lowmid'),
        (0x3B000, 0x4A000, 'audio_mid'),
        (0xE0000, 0xF7000, 'gfx_1'),
        (0x100000, 0x113000, 'gfx_2'),
        (0x1A0000, 0x1B5000, 'gfx_3'),
        (0x1C0000, 0x1D9000, 'gfx_4'),
        (0x200000, 0x218000, 'gfx_5'),
        (0x27D000, 0x29E000, 'gfx_end'),
    ]
    for a, b, nm in regions:
        with open(os.path.join(args.outdir, f'region_{nm}_{a:06x}.bin'), 'wb') as f:
            f.write(rom[a:b])
    log.append('[+] regiones volcadas: ' + ', '.join(n for _, _, n in regions))

    # ---------- resumen ----------
    out_txt = os.path.join(args.outdir, 'ASSETS_README.txt')
    with open(out_txt, 'w', encoding='utf-8') as f:
        f.write('ASSETS extraidos - Yu Yu Hakusho: Makyou Toitsusen (J) [Mega Drive]\n')
        f.write('=' * 70 + '\n\n')
        f.write('\n'.join(log) + '\n\n')
        f.write('Archivos generados:\n')
        for fn in sorted(os.listdir(args.outdir)):
            f.write(f'  {fn}\n')
    print('\n'.join(log))
    print('[+] salida en:', args.outdir)


if __name__ == '__main__':
    main()
