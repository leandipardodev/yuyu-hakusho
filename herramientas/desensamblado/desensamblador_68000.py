#!/usr/bin/env python3
"""
desensamblador_68000.py - Extraccion de codigo 68000 de un ROM de Sega Mega Drive/Genesis.

El codigo de un juego Genesis esta DISPERSO por todo el ROM, intercalado con
tiles, paletas y tablas del VDP. Un barrido lineal se come los graficos como
si fueran codigo, asi que se combinan cuatro fases y se puntua el resultado:

  F0  vectores 68000 (reset + handlers) -> descenso por flujo de control.
  F1  paginas donde vive codigo: barrido lineal SOLO para cosechar
      destinos de rama/call -> nuevas semillas -> descenso recursivo.
  F2  finales de funcion: cada 'rts'/'rte' y cada 'link' son inicios validos
      -> descenso recursivo (captura funciones tras subrutinas de BIOS).
  F3  tablas de despacho: punteros long que caen en paginas de codigo.
  Tras F1 se fija el conjunto de paginas de codigo; F2/F3 amplian sobre el.
  Solo se marca como codigo lo que el flujo alcanza o un prologo legitimo
  confirma; el resto queda como data/padding en el mapa.
"""
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ruta_rom import ruta_rom
import os, re, struct, argparse
import capstone as cs
from capstone import m68k_const as M

ROM_MAX = 0x300000
NO_FALL = {'bra', 'jmp', 'rts', 'rte', 'rtr', 'rtd', 'stop', 'illegal', 'trapv'}
RET = {'rts', 'rte', 'rtr', 'rtd'}

def u32be(b, o):
    return struct.unpack('>I', b[o:o+4])[0]

class Ins:
    __slots__ = ('addr', 'size', 'mn', 'ops', 'raw', 'flow', 'dref')
    def __init__(self, i, flow, dref):
        self.addr = i.address; self.size = i.size
        self.mn = i.mnemonic; self.ops = i.op_str
        self.raw = bytes(i.bytes); self.flow = flow; self.dref = dref

class Dis:
    def __init__(self, rom, min_fsize=3):
        self.rom = rom
        self.min_fsize = min_fsize   # longitud minima para creer en un "link"
        self.md = cs.Cs(cs.CS_ARCH_M68K, cs.CS_MODE_M68K_000 | cs.CS_MODE_BIG_ENDIAN)
        self.md.detail = True
        self.code = {}
        self.cover = set()     # bytes ocupados por instrucciones ya decodificadas
        self.data = set()
        self.labels = {}
        self.calls = {}
        self.func_starts = set()

    def ok(self, a):
        return 0x200 <= a < ROM_MAX

    def one(self, a):
        r = list(self.md.disasm(self.rom[a:a+12], a, count=1))
        if not r:
            return None
        i = r[0]
        if i.id == 0 or i.mnemonic in ('.byte', '.word', '.long', 'invalid'):
            return None
        return i

    def operands(self, ins):
        flow, dref = [], []
        is_ctrl = (cs.CS_GRP_JUMP in ins.groups or cs.CS_GRP_CALL in ins.groups
                   or cs.CS_GRP_BRANCH_RELATIVE in ins.groups)
        for o in ins.operands:
            if o.type == M.M68K_OP_BR_DISP:
                d = o.br_disp.disp
                if o.br_disp.disp_size == 1 and d & 0x80:
                    d -= 0x100
                elif o.br_disp.disp_size == 2 and d & 0x8000:
                    d -= 0x10000
                flow.append((ins.address + ins.size + d) & 0xffffffff)
            elif o.type == M.M68K_OP_IMM:
                v = o.imm & 0xffffffff
                if is_ctrl:
                    flow.append(v)
                elif 0x200 <= v < ROM_MAX:
                    dref.append(v)
        mn = ins.mnemonic
        if mn.split('.')[0] in ('jsr', 'jmp', 'bra', 'bsr'):
            m = re.search(r'\$([0-9a-fA-F]{1,8})', ins.op_str)
            if m:
                v = int(m.group(1), 16)
                if v not in flow:
                    flow.append(v)
        return flow, dref

    def descend_from(self, seeds, mark_func=False):
        work = [s for s in seeds if self.ok(s)]
        while work:
            a = work.pop()
            if a in self.code or a in self.data:
                continue
            if self.mid_insn(a):        # no empezar dentro de otra instruccion
                continue
            if mark_func:
                self.func_starts.add(a)
            cur = a
            while self.ok(cur) and cur not in self.code and cur not in self.data:
                ins = self.one(cur)
                if ins is None:
                    break
                flow, dref = self.operands(ins)
                mn = ins.mnemonic
                is_jump = cs.CS_GRP_JUMP in ins.groups
                is_call = cs.CS_GRP_CALL in ins.groups
                is_branch = cs.CS_GRP_BRANCH_RELATIVE in ins.groups
                flow = [f for f in flow if self.ok(f) and f != cur]
                self.code[cur] = Ins(ins, flow, dref)
                for b in range(cur, cur + ins.size):
                    self.cover.add(b)
                for d in dref:
                    if d not in self.code:
                        self.data.add(d)
                if is_call:
                    self.calls.setdefault(cur, set()).update(flow)
                if is_call or is_jump or is_branch:
                    for f in flow:
                        if f not in self.code:
                            work.append(f)
                nxt = cur + ins.size
                if mn in NO_FALL or (is_jump and mn.startswith('jmp')):
                    break
                cur = nxt

    def mid_insn(self, a):
        """True si 'a' cae dentro (o es) el rango de una instruccion ya desensamblada."""
        return a in self.cover

    def harvest_pages(self, pages):
        """Barrido lineal de las paginas dadas; devuelve destinos de flujo."""
        seeds = set()
        for pg in pages:
            lo = pg << 12
            hi = min(lo + 0x1000, ROM_MAX)
            a = lo
            while a < hi:
                ins = self.one(a)
                if ins is None:
                    a += 1
                    continue
                flow, _ = self.operands(ins)
                for f in flow:
                    if self.ok(f):
                        seeds.add(f)
                a += ins.size
        return seeds

    def find_ret_link(self):
        """Direcciones de inicio candidatas: tras rts/rte, y en 'link'."""
        out = set()
        rom = self.rom
        for pat, off in ((b'\x4e\x75', 2), (b'\x4e\x73', 2), (b'\x4e\x57', 0),
                         (b'\x4e\x56', 0), (b'\x4e\x5e', 0), (b'\x4e\x5f', 0)):
            a = 0x200
            while a < ROM_MAX - 1:
                i = rom.find(pat, a, ROM_MAX)
                if i == -1:
                    break
                out.add(i + off)
                a = i + 2
        return sorted(x for x in out if self.ok(x))

    def find_ptrs(self, pages):
        pgset = set(pages)
        out = set()
        a = 0x200
        while a < ROM_MAX - 4:
            v = u32be(self.rom, a)
            if self.ok(v) and (v >> 12) in pgset and (v & 1) == 0:
                out.add(v)
            a += 2
        return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom', nargs='?', default=None,
                help='Ruta del ROM. Si se omite: $YUYU_ROM, luego .rom_path, luego la raiz del repo')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--stats', default=None)
    args = ap.parse_args()

    if not args.rom:
        args.rom = ruta_rom()
    raw = open(args.rom, 'rb').read()
    rom = raw[:ROM_MAX] + b'\x00' * max(0, ROM_MAX - len(raw))
    D = Dis(rom)

    # ---------- F0: vectores
    reset = u32be(rom, 4)
    D.labels[reset] = 'reset'
    vs = []
    for i in range(0x40):
        v = u32be(rom, i*4)
        if 0x200 <= v < ROM_MAX:
            vs.append(v)
            D.labels.setdefault(v, f'v_{i:02x}')
    D.descend_from([reset] + vs)
    f0 = len(D.code)
    pages = sorted(set(a >> 12 for a in D.code))

    # ---------- F1: cosechar destinos en paginas de codigo
    D.descend_from(D.harvest_pages(pages))
    f1 = len(D.code)
    pages = sorted(set(a >> 12 for a in D.code))   # reexpandir paginas

    # ---------- F2: finales de funcion / link
    D.descend_from(D.find_ret_link(), mark_func=True)
    f2 = len(D.code)

    # ---------- F3: tablas de despacho
    D.descend_from(D.find_ptrs(pages), mark_func=True)
    f3 = len(D.code)

    # ---------- segunda ronda con paginas ya ampliadas
    D.descend_from(D.harvest_pages(pages))
    f4 = len(D.code)

    # ---------- etiquetas
    for a, ins in D.code.items():
        for t in ins.flow:
            if t in D.code and t not in D.labels:
                D.labels[t] = f'loc_{t:06x}'
    for a, ts in D.calls.items():
        for t in ts:
            if t in D.code and t not in D.labels:
                D.labels[t] = f'sub_{t:06x}'

    nbytes = sum(i.size for i in D.code.values())
    lo = min(D.code); hi = max((a + i.size for a, i in D.code.items()), default=lo)
    ret_hits = sum(1 for i in D.code.values() if i.mn.split('.')[0] in RET)

    # codigo por pagina
    import collections
    per_page = collections.Counter(a >> 12 for a in D.code)
    codepages = sorted(per_page)

    # ---------- listado
    o = []
    w = o.append
    w('; ' + '=' * 78)
    w('; Sega Mega Drive / Genesis   --   CODIGO 68000 extraido')
    w(f'; ROM        : {os.path.basename(args.rom)}   ({len(raw):,} bytes)'.replace(',', '.'))
    w(f'; Code span  : ${lo:06x} .. ${hi:06x}   ({nbytes:,} bytes de codigo)'.replace(',', '.'))
    w(f'; Instrucc.  : {len(D.code)}    Etiquetas: {len(D.labels)}    Funciones: {len(D.func_starts)}')
    w(f'; Cobertura  : F0 vectores={f0}  F1 ramas={f1}  F2 rts/link={f2}  F3 punteros={f3}  F4={f4}')
    w(f'; rts/rte alcanzados: {ret_hits}')
    w(f'; Paginas con codigo ({len(codepages)}): ' + ' '.join(f'{p<<12:06x}' for p in codepages))
    w('; Generado por desensamblador_68000.py (Capstone m68k + analisis de flujo)')
    w('; ' + '=' * 78)
    w('')
    w('=============== TABLA DE VECTORES 68000 ===============')
    w('        org     $000000')
    for i in range(0x40):
        v = u32be(rom, i*4)
        w(f'        dc.l    $%08x    ; {D.labels.get(v, "")}' % v)
    w('')
    w('=============== CODIGO (por bloques alcanzados) ===============')
    w(f'        org     $%06x' % lo)
    addrs = sorted(D.code)
    blocks, cur = [], [addrs[0]]
    for a in addrs[1:]:
        if a == cur[-1] + D.code[cur[-1]].size:
            cur.append(a)
        else:
            blocks.append(cur); cur = [a]
    blocks.append(cur)
    for bi, blk in enumerate(blocks):
        s = blk[0]
        e = blk[-1] + D.code[blk[-1]].size
        w('')
        w(f'        ; ================ bloque #{bi}  ${s:06x} - ${e:06x} '
          f'({e-s} bytes) ================')
        for a in blk:
            ins = D.code[a]
            if a in D.labels:
                w('')
                w(f'{D.labels[a]}:')
            hx = ' '.join(f'{b:02x}' for b in ins.raw)
            w(f'{a:06x}:  {hx:<17s}  {ins.mn:<9s} {ins.ops}')
    w('        end')
    open(args.out, 'w', encoding='utf-8').write('\n'.join(o) + '\n')

    print(f'[+] instr     : {len(D.code)}   ({nbytes} bytes de codigo)')
    print(f'[+] span      : ${lo:06x}..${hi:06x}    bloques: {len(blocks)}')
    print(f'[+] labels    : {len(D.labels)}   funciones: {len(D.func_starts)}')
    print(f'[+] fases     : F0={f0} F1={f1} F2={f2} F3={f3} F4={f4}')
    print(f'[+] rts       : {ret_hits}')
    print(f'[+] paginas   : {len(codepages)} -> ' + ' '.join(f'{p<<12:06x}' for p in codepages))
    print(f'[+] output    : {args.out}  ({len(o)} lineas)')

    if args.stats:
        with open(args.stats, 'w', encoding='utf-8') as f:
            f.write('pagina,instr,bytes\n')
            for p in codepages:
                ins = [a for a in D.code if a >> 12 == p]
                f.write(f'0x{p<<12:06x},{len(ins)},{sum(D.code[a].size for a in ins)}\n')


if __name__ == '__main__':
    main()
