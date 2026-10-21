#!/usr/bin/env python3
"""
z80dis.py - Desensamblador Z80 (mapa base + CB/ED/DD/FD, con opcodes no
documentados). Capstone 5 (Python) no incluye Z80, asi que se implementa aqui.

one(pc) -> (mnemonic, longitud, flujo) donde flujo es una tupla con
'jmp'/'call'/'ret' para ayudar al analisis de flujo.
"""
import struct

R   = ['b', 'c', 'd', 'e', 'h', 'l', '(hl)', 'a']
RP  = ['bc', 'de', 'hl', 'sp']
RP2 = ['bc', 'de', 'hl', 'af']
CC  = ['nz', 'z', 'nc', 'c', 'po', 'pe', 'p', 'm']
ALU = ['add a,', 'adc a,', 'sub ', 'sbc a,', 'and ', 'xor ', 'or ', 'cp ']
ROT = ['rlc', 'rrc', 'rl', 'rr', 'sla', 'sra', 'sll', 'srl']


class Z80:
    def __init__(self, data):
        self.d = data

    def u8(self, p):
        return self.d[p]

    def u16(self, p):
        return struct.unpack('<H', self.d[p:p + 2])[0]

    def s8(self, p):
        v = self.d[p]
        return v - 0x100 if v & 0x80 else v

    def rel(self, pc):
        """destino relativo (el byte displacement esta en pc)."""
        return pc + 2 + self.s8(pc)

    # ---------------------------------------------------------------
    def one(self, pc):
        b = self.d[pc]
        if b == 0xCB:
            return self._cb(pc)
        if b == 0xED:
            return self._ed(pc)
        if b in (0xDD, 0xFD):
            return self._ixiy(pc, 'ix' if b == 0xDD else 'iy')
        return self._base(pc, b)

    # ---------------- CB ---------------------------------------------
    def _cb(self, pc):
        op = self.d[pc + 1]
        x, y = op >> 3, op & 7
        reg = 'a' if y == 6 else R[y]          # CB (hl) escribe en a
        if x < 8:
            return f'{ROT[x]} {reg}', 2, ()
        return f'bit {y & 7},{reg}', 2, ()
    # fin CB

    # ---------------- ED ---------------------------------------------
    def _ed(self, pc):
        op = self.d[pc + 1]
        x, y = op >> 3, op & 7
        if op == 0x47:  return 'ld i,a', 2, ()
        if op == 0x4F:  return 'ld r,a', 2, ()
        if op == 0x57:  return 'ld a,i', 2, ()
        if op == 0x5F:  return 'ld a,r', 2, ()
        if op == 0x44:  return 'neg', 2, ()
        if op == 0x4C:  return 'neg', 2, ()      # alias
        if op == 0x45:  return 'retn', 2, ('ret',)
        if op == 0x4D:  return 'reti', 2, ('ret',)
        if op == 0x55:  return 'retn', 2, ('ret',)   # alias
        if op == 0x5D:  return 'reti', 2, ('ret',)
        if op in (0x46, 0x56):  return 'im 0', 2, ()
        if op in (0x5E, 0x76):  return 'im 1', 2, ()
        if op in (0x5E, 0x7E):  return 'im 2', 2, ()
        if op == 0x66:  return 'im 0', 2, ()
        if op == 0x6E:  return 'im 1', 2, ()
        if op == 0x7E:  return 'im 2', 2, ()
        if op == 0x67:  return 'rrd', 2, ()
        if op == 0x6F:  return 'rld', 2, ()
        if 0x40 <= op <= 0x7F:                       # ld r/r1, r  (in/out via (c))
            y2, r = op & 7, (op >> 3) & 7
            rname = R[r] if r != 6 else 'a'
            if y2 == 6:
                return f'in {rname},(c)', 2, ()
            return f'out (c),{rname}', 2, ()
        if op in (0x42, 0x52, 0x62, 0x72):  return f'sbc hl,{RP[op >> 4 & 3]}', 2, ()
        if op in (0x4A, 0x5A, 0x6A, 0x7A):  return f'adc hl,{RP[op >> 4 & 3]}', 2, ()
        if 0x43 <= op <= 0x7B and (op & 0xC7) == 0x43:   # ld (nn),rp / ld rp,(nn)
            p = (op >> 4) & 3
            nn = self.u16(pc + 2)
            if op & 0x08:
                return f'ld {RP[p]},({nn:04x}h)', 4, ()
            return f'ld ({nn:04x}h),{RP[p]}', 4, ()
        return f'db 0xed,{op:02x}', 2, ()
    # fin ED

    # ---------------- DD / FD (IX / IY) -----------------------------
    def _ixiy(self, pc, r):
        pfx = self.d[pc]
        op = self.d[pc + 1]
        if op == 0xCB:
            d = self.s8(pc + 2)
            cbop = self.d[pc + 3]
            idx = f'({r}{d:+d})'
            return CBOPT(cbop, idx), 4, ()
        m = self._ixmn(pc, r, op)
        if m is None:
            return f'db 0x{pfx:02x},0x{op:02x}', 2, ()
        return m

    def _ixmn(self, pc, r, op):
        y = (op >> 3) & 7
        z = op & 7
        p = y >> 1
        if op in (0x09, 0x19, 0x29, 0x39):
            other = {0x09: 'bc', 0x19: 'de', 0x29: r, 0x39: 'sp'}[op]
            return f'add {r},{other}', 2, ()
        if op in (0x21,):  return f'ld {r},{self.u16(pc+2):04x}h', 4, ()
        if op in (0x22,):  return f'ld ({self.u16(pc+2):04x}h),{r}', 4, ()
        if op in (0x2A,):  return f'ld {r},({self.u16(pc+2):04x}h)', 4, ()
        if op in (0x23,):  return f'inc {r}', 2, ()
        if op in (0x2B,):  return f'dec {r}', 2, ()
        if op in (0x24,):  return f'inc {r}h', 2, ()
        if op in (0x25,):  return f'dec {r}h', 2, ()
        if op in (0x26,):  return f'ld {r}h,{self.u8(pc+2):02x}h', 3, ()
        if op in (0x2E,):  return f'ld {r},{self.u8(pc+2):02x}h', 3, ()
        if op in (0x34,):  return f'inc ({r})', 2, ()
        if op in (0x35,):  return f'dec ({r})', 2, ()
        if op in (0x36,):  return f'ld ({r}),{self.u8(pc+2):02x}h', 3, ()
        if op == 0xE1:  return f'pop {r}', 2, ()
        if op == 0xE5:  return f'push {r}', 2, ()
        if op == 0xE3:  return f'ex (sp),{r}', 2, ()
        if op == 0xE9:  return f'jp ({r})', 2, ('jmp',)
        if op == 0xF9:  return f'ld sp,{r}', 2, ()
        # ld r',r'' con sustitucion (hl)->(ix)/(iy)
        if 0x40 <= op <= 0x7F and op != 0x76:
            def sub(reg):
                return f'({r})' if reg == '(hl)' else f'{r}{reg}'
            return f'ld {sub(R[y])},{sub(R[z])}', 2, ()
        if op == 0x76:  return f'halt', 2, ()
        # alu con (hl) -> (ix)/(iy)
        if 0x80 <= op <= 0xBF:
            dst = R[z]
            if dst == '(hl)':
                dst = f'({r})'
            return f'{ALU[y]}{dst}', 2, ()
        return None
    # fin DD/FD

    # ---------------- mapa base 0x00-0xFF -----------------------------
    def _base(self, pc, b):
        # 0x00-0x3F : nop/ex/djnz/jr/ld nn/inc/alu/dis Single
        if b < 0x40:
            y = (b >> 3) & 7
            z = b & 7
            p = y >> 1
            if b == 0x00:  return 'nop', 1, ()
            if b == 0x08:  return "ex af,af'", 1, ()
            if b == 0x10:  return f'djnz ${self.rel(pc+1):04x}', 2, ('jmp',)
            if b == 0x18:  return f'jr ${self.rel(pc+1):04x}', 2, ('jmp',)
            if b & 0xC7 == 0x20:  return f'jr {CC[y-4]},${self.rel(pc+1):04x}', 2, ('jmp',)
            if b & 0xC7 == 0x01:  return f'ld {RP[p]},{self.u16(pc+1):04x}h', 3, ()
            if b & 0xC7 == 0x02:
                if p == 0:  return 'ld (bc),a', 1, ()
                if p == 1:  return 'ld (de),a', 1, ()
                if p == 2:  return f'ld ({self.u16(pc+1):04x}h),hl', 3, ()
                return f'ld ({self.u16(pc+1):04x}h),a', 3, ()   # 0x32
            if b & 0xC7 == 0x03:
                return f'inc {RP[p]}', 1, ()
            if b & 0xC7 == 0x04:  return f'inc {R[b&7]}', 1, ()
            if b & 0xC7 == 0x05:  return f'dec {R[b&7]}', 1, ()
            if b & 0xC7 == 0x06:  return f'ld {R[b&7]},{self.u8(pc+1):02x}h', 2, ()
            if b & 0xC7 == 0x07:
                t = ['rlca', 'rrca', 'rla', 'rra', 'daa', 'cpl', 'scf', 'ccf']
                return t[y], 1, ()
            if b & 0xC7 == 0x09:  return f'add hl,{RP[p]}', 1, ()
            if b & 0xC7 == 0x0A:
                if p == 0:  return 'ld a,(bc)', 1, ()
                if p == 1:  return 'ld a,(de)', 1, ()
                if p == 2:  return f'ld hl,({self.u16(pc+1):04x}h)', 3, ()
                return f'ld a,({self.u16(pc+1):04x}h)', 3, ()     # 0x3A
            if b & 0xC7 == 0x0B:
                return f'dec {RP[p]}', 1, ()
            if b & 0xC7 == 0x0C:  return f'inc {R[b&7]}', 1, ()
            if b & 0xC7 == 0x0D:  return f'dec {R[b&7]}', 1, ()
            if b & 0xC7 == 0x0E:  return f'ld {R[b&7]},{self.u8(pc+1):02x}h', 2, ()
            return f'db 0x{b:02x}', 1, ()
        # 0x40-0x7F : ld r,r'
        if b < 0x80:
            if b == 0x76:  return 'halt', 1, ()
            return f'ld {R[(b>>3)&7]},{R[b&7]}', 1, ()
        # 0x80-0xBF : alu a,r
        if b < 0xC0:
            return f'{ALU[(b>>3)&7]}{R[b&7]}', 1, ()
        # 0xC0-0xFF
        return self._base_hi(pc, b)

    def _base_hi(self, pc, b):
        y = (b >> 2) & 7
        p = (b >> 4) & 3
        q = (b >> 3) & 1
        # irregulares explicitos
        irr = {
            0xC3: ('jp', 'jmp'), 0xC9: ('ret', 'ret'), 0xCD: ('call', 'call'),
            0xD3: ('out',), 0xDB: ('in',), 0xD9: ('exx',), 0xE3: ('ex',),
            0xE9: ('jp', 'jmp'), 0xEB: ('ex',), 0xF3: ('di',), 0xF9: ('ld',),
            0xFB: ('ei',),
        }
        if b == 0xC3:  return f'jp ${self.u16(pc+1):04x}h', 3, ('jmp',)
        if b == 0xCD:  return f'call ${self.u16(pc+1):04x}h', 3, ('call',)
        if b == 0xC9:  return 'ret', 1, ('ret',)
        if b == 0xD3:  return f'out ({self.u8(pc+1):02x}h),a', 2, ()
        if b == 0xDB:  return f'in a,({self.u8(pc+1):02x}h)', 2, ()
        if b == 0xD9:  return 'exx', 1, ()
        if b == 0xE3:  return 'ex (sp),hl', 1, ()
        if b == 0xE9:  return 'jp (hl)', 1, ('jmp',)
        if b == 0xEB:  return 'ex de,hl', 1, ()
        if b == 0xF3:  return 'di', 1, ()
        if b == 0xF9:  return 'ld sp,hl', 1, ()
        if b == 0xFB:  return 'ei', 1, ()
        if b == 0x76:  return 'halt', 1, ()
        cls = b & 0xC7
        if cls == 0xC0:
            if q == 0:  return f'ret {CC[y]}', 1, ('ret',)
            return 'ret', 1, ('ret',)
        if cls == 0xC1:  return f'pop {RP2[p]}', 1, ()
        if cls == 0xC2:  return f'jp {CC[y]},${self.u16(pc+1):04x}h', 3, ('jmp',)
        if cls == 0xC4:  return f'call {CC[y]},${self.u16(pc+1):04x}h', 3, ('call',)
        if cls == 0xC5:  return f'push {RP2[p]}', 1, ()
        if cls == 0xC6:  return f'{ALU[y]}{self.u8(pc+1):02x}h', 2, ()
        if cls == 0xC7:  return f'rst ${p*8:02x}h', 1, ('jmp',)
        if cls == 0xC3 and q == 1 and p == 0:  # solo 0xCB (prefijo) cae aqui
            return f'db 0x{b:02x}', 1, ()
        return f'db 0x{b:02x}', 1, ()


def CBOPT(cbop, idx):
    x, y = cbop >> 3, cbop & 7
    if x < 8:
        return f'{ROT[x]} {idx}'
    if x == 8:
        return f'bit {y},{idx}'
    if x == 9:
        return f'res {y},{idx}'
    return f'set {y},{idx}'
