#!/usr/bin/env python3
"""
m68k_trace.py - Emulador/rastreador M68000 minimo para YU Yu Hakusho: Makyou Toitsusen.

Objetivo: ejecutar el codigo 68k del juego y capturar el VALOR que el motor
escribe en el player struct (offset $3C = daño o frames del move) en el frame
exacto de cada golpe, para obtener el frame data real.

Alcance:
  - 68000 completo (instrucciones comunes) - solo el subconjunto que usa el juego
    (169 opcodes distintos, segun analisis previo)
  - Memoria: ROM 0x000000-0x3FFFFF, work RAM 0xFF0000-0xFFFFFF
  - Sin VDP/Z80: se ejecuta solo la logica 68k; el VDP no se emula (el juego
    puede quedar esperando en VBlank, pero la logica de moves es reachable)
  - Traza: registra escrituras al player struct y cuando el PC pasa por
    la rutina de daño (0x19C46) o el lector de moves (0x1EBBE)

Este es un tracer de ingenieria inversa, no un emulador de juego completo.
"""
import struct, sys
from collections import defaultdict

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom
ROM_PATH = ruta_rom()
ROM_MAX = 0x300000
RAM_BASE = 0xFF0000
RAM_SIZE = 0x10000

# direcciones clave (del analisis estatico)
PC_DAMAGE = 0x19C46     # sub.w d0,$b8(a5)  - aplicar dano
PC_MOVE_RD = 0x1EBBE    # move.b (a2,d3.w),d4 - leer move


class M68K:
    def __init__(self, rom):
        self.rom = rom
        self.ram = bytearray(RAM_SIZE)
        self.d = [0] * 8     # d0-d7
        self.a = [0] * 8     # a0-a7
        self.pc = 0
        self.sr = 0x2700
        self.usp = 0
        self.ssp = 0
        self.stopped = False
        self.cycles = 0
        # traza
        self.trace_damage = []   # (pc, d0, a5)
        self.writes = defaultdict(int)

    # ---- memoria ----
    def rd8(self, addr):
        addr &= 0xFFFFFF
        if addr < ROM_MAX:
            return self.rom[addr]
        if RAM_BASE <= addr < RAM_BASE + RAM_SIZE:
            return self.ram[addr - RAM_BASE]
        return 0

    def rd16(self, addr):
        return (self.rd8(addr) << 8) | self.rd8(addr + 1)

    def rd32(self, addr):
        return (self.rd16(addr) << 16) | self.rd16(addr + 2)

    def wr8(self, addr, val):
        addr &= 0xFFFFFF
        val &= 0xFF
        if RAM_BASE <= addr < RAM_BASE + RAM_SIZE:
            off = addr - RAM_BASE
            self.ram[off] = val
            self.writes[off] += 1

    def wr16(self, addr, val):
        self.wr8(addr, val >> 8)
        self.wr8(addr + 1, val)

    def wr32(self, addr, val):
        self.wr16(addr, val >> 16)
        self.wr16(addr + 2, val)

    # ---- helpers registros ----
    def get_d(self, n):
        return self.d[n] & 0xFFFFFFFF

    def set_d(self, n, v):
        self.d[n] = v & 0xFFFFFFFF

    def get_a(self, n):
        return self.a[n] & 0xFFFFFFFF

    def set_a(self, n, v):
        self.a[n] = v & 0xFFFFFFFF

    # ea = direccion efectiva o valor inmediato. Retorna (valor, es_direccion)
    def calc_ea(self, mode, reg, size, pc_after):
        """Devuelve (addr_o_val, mode2) - simplificado para los modos usados."""
        r = self.get_a(reg) if reg < 8 else self.get_d(reg - 8)
        if mode == 0:  # Dn
            return (r, False)
        if mode == 1:  # An
            return (r, True)
        if mode == 2:  # (An)
            return (r, True)
        if mode == 3:  # (An)+
            return (r, True)
        if mode == 4:  # -(An)
            r = (r - size) & 0xFFFFFFFF
            self.set_a(reg, r)
            return (r, True)
        if mode == 5:  # (d16,An)
            ext = self.rd16(pc_after)
            return ((r + (ext if ext < 0x8000 else ext - 0x10000)) & 0xFFFFFFFF, True)
        if mode == 6:  # (d8,An,Xn)
            ext = self.rd8(pc_after)
            disp = ext if ext < 0x80 else ext - 0x100
            idx = self.get_d((reg >> 3) & 7) if False else 0
            return ((r + disp) & 0xFFFFFFFF, True)
        if mode == 7:
            if reg == 0:  # (xxx).W
                return (self.rd16(pc_after), True)
            if reg == 1:  # (xxx).L
                return (self.rd32(pc_after), True)
            if reg == 2:  # (d16,PC)
                ext = self.rd16(pc_after)
                t = ext if ext < 0x8000 else ext - 0x10000
                return ((self.pc + t) & 0xFFFFFF, True)
            if reg == 4:  # #imm
                if size == 1: return (self.rd8(pc_after), False)
                if size == 2: return (self.rd16(pc_after), False)
                return (self.rd32(pc_after), False)
        return (0, False)

    def read_ea(self, mode, reg, size, pc_after):
        v, is_addr = self.calc_ea(mode, reg, size, pc_after)
        if not is_addr and mode not in (0, 1) and not (mode == 7 and reg == 4):
            return v
        if is_addr:
            if size == 1: return self.rd8(v)
            if size == 2: return self.rd16(v)
            return self.rd32(v)
        return v

    def write_ea(self, mode, reg, size, val, pc_after):
        v, is_addr = self.calc_ew(mode, reg, size, pc_after)
        if is_addr:
            if size == 1: self.wr8(v, val)
            elif size == 2: self.wr16(v, val)
            else: self.wr32(v, val)
        else:
            # immediato o registro:寫 al registro
            if reg < 8:
                self.set_d(reg, val)
            else:
                self.set_a(reg - 8, val)

    def calc_ew(self, mode, reg, size, pc_after):
        r = self.get_a(reg) if reg < 8 else self.get_d(reg - 8)
        if mode == 0:
            return (r, False)
        if mode == 1:
            return (r, True)
        if mode == 2:
            return (r, True)
        if mode == 3:
            return (r, True)
        if mode == 4:
            r = (r - size) & 0xFFFFFFFF; self.set_a(reg, r); return (r, True)
        if mode == 5:
            ext = self.rd16(pc_after)
            return ((r + (ext if ext < 0x8000 else ext - 0x10000)) & 0xFFFFFFFF, True)
        if mode == 7 and reg == 0:
            return (self.rd16(pc_after), True)
        if mode == 7 and reg == 1:
            return (self.rd32(pc_after), True)
        return (r, False)

    def ext_len(self, op, mode, reg, sz):
        """Longitud de la palabra(s) de extension segun el modo de direccionamiento."""
        if mode == 5: return 2      # (d16,An)
        if mode == 6: return 1      # (d8,An,Xn)
        if mode == 7:
            if reg == 0: return 2   # (xxx).W
            if reg == 1: return 4   # (xxx).L
            if reg == 2: return 2   # (d16,PC)
            if reg == 4:            # #imm
                return 2 if sz == 1 else (4 if sz == 2 else 1)
            if reg == 3: return 2   # (d16,PC) index
        return 0

    def set_nz(self, res, size):
        mask = (1 << (size * 8)) - 1
        res &= mask
        self.sr = (self.sr & ~0x1F) | (0x10 if res == 0 else 0)
        if res & (1 << (size * 8 - 1)):
            self.sr |= 0x08
        else:
            self.sr &= ~0x08
        return res

    def cond(self, c):
        C = (self.sr >> 0) & 1
        V = (self.sr >> 1) & 1
        Z = (self.sr >> 2) & 1
        N = (self.sr >> 3) & 1
        if c == 0: return True
        if c == 1: return False
        if c == 2: return not C and not Z
        if c == 3: return C or Z
        if c == 4: return not C
        if c == 5: return C
        if c == 6: return not Z
        if c == 7: return Z
        if c == 8: return not V
        if c == 9: return V
        if c == 10: return not N
        if c == 11: return N
        if c == 12: return N == V
        if c == 13: return N != V
        if c == 14: return not Z and (N == V)
        if c == 15: return Z or (N != V)
        return False

    def branch(self, cond, disp):
        if self.cond(cond):
            self.pc = (self.pc + disp) & 0xFFFFFF

    def step(self):
        op = self.rd16(self.pc)
        self.cycles += 1
        # ---- una instruccion (subconjunto) ----
        # decode simple
        hi = (op >> 12) & 0xF
        mode = (op >> 3) & 7
        reg = op & 7
        sz = (op >> 6) & 3  # 0=b,1=w,2=l
        # extension length por defecto (modo fuente en bits 5-3)
        self._ext = self.ext_len(op, mode, reg, sz)
        # prefijos
        if op == 0x4AFC:
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if op == 0x4E70:  # RESET
            self.pc = 0; return
        if op == 0x4E71:  # NOP
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if op == 0x4E75:  # RTS
            self.pc = self.rd32(self.get_a(7)); self.set_a(7, self.get_a(7) + 4); return
        if op == 0x4E77:  # RTR
            self.sr = (self.sr & 0xFF00) | (self.rd16(self.get_a(7)) & 0xFF)
            self.pc = self.rd32(self.get_a(7) + 2); self.set_a(7, self.get_a(7) + 6); return
        if op == 0x4E73:  # RTE
            self.sr = self.rd16(self.get_a(7)); self.pc = self.rd32(self.get_a(7) + 2)
            self.set_a(7, self.get_a(7) + 6); return
        if op == 0x4E71 + 0:  # dup NOP
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # JMP
        if hi == 12 and mode == 2 and reg == 0:
            self.pc = self.rd32(self.pc + 2) & 0xFFFFFF; return
        # JSR
        if hi == 12 and mode == 2 and reg == 1:
            ext = self.rd32(self.pc + 2)
            self.set_a(7, (self.get_a(7) - 4) & 0xFFFFFFFF); self.wr32(self.get_a(7), self.pc + 6)
            self.pc = ext & 0xFFFFFF; return
        # Bcc (Bcc = 0110 cond disp8) and BScc
        if hi == 6:
            disp8 = op & 0xFF
            disp = disp8 if disp8 < 0x80 else disp8 - 0x100
            self.branch((op >> 8) & 0xF, disp)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if hi == 5 and sz == 0 and (mode == 1 or (mode == 7 and reg == 1) or mode in (2, 3, 5, 6)):
            # DBcc / DBFcc
            if sz == 0 and ((op & 0xF0F) == 0x0108 or True):
                if (op & 0xFF) == 0x08 or (op & 0xFF) == 0x00:
                    pass
            # general DBcc: 0001 0000 11 cond 001 disp
            regx = (op >> 9) & 7
            cond = (op >> 8) & 0xF
            disp = (op & 0xFF)
            disp = disp if disp < 0x80 else disp - 0x100
            # decrement word at (regx)
            a = self.get_a(regx)
            v = (self.rd16(a) - 1) & 0xFFFF
            self.wr16(a, v)
            if v != 0xFFFF and self.cond(cond):
                self.pc = (self.pc + 2 + disp) & 0xFFFFFF
            else:
                self.pc = (self.pc + 2) & 0xFFFFFF
            return
        # Scc
        if hi == 5 and mode == 3 and (op & 0xF0) != 0xC0:
            cond = (op >> 8) & 0xF
            ea, is_addr = self.calc_ea(mode, reg, 1, self.pc + 2)
            if self.cond(cond): self.wr8(ea, 0xFF)
            else: self.wr8(ea, 0x00)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # MOVEQ
        if hi == 7 and (op & 0x0100) == 0:
            v = op & 0xFF
            if v & 0x80: v -= 0x100
            self.set_d((op >> 9) & 7, v)
            self.set_nz(v & 0xFF, 1)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # MOVE
        if hi in (1, 2, 3):
            if op & 0x0800:  # MOVE.l
                src = (hi - 1) * 0x200 + (mode << 6) + reg
                # src = bits; decode
                smode = (op >> 3) & 7; sreg = op & 7
                # cuidado: src size viene de hi
                size = 4
                val = self.read_ea(smode, sreg, size, self.pc + 2)
                dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
                self.write_ea(dmode, dreg, size, val & 0xFFFFFFFF, self.pc + 2)
                self.set_nz(val, 4)
            else:
                size = 2 if hi == 1 else 1
                smode = (op >> 3) & 7; sreg = op & 7
                val = self.read_ea(smode, sreg, size, self.pc + 2)
                dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
                self.write_ea(dmode, dreg, size, val & ((1 << (size * 8)) - 1), self.pc + 2)
                self.set_nz(val, size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        #ORI/ANDI/EORI/ADDI/SUBI/CMPI/ADDQ/SUBQ
        if hi in (0, 0xA, 0xC, 0xE) and (op & 0xF000) in (0x0000, 0x0200, 0x0400, 0x0600, 0x0A00, 0x0C00, 0x0E00):
            pass
        # implementacion basica: solo las mas comunes
        # CMPI
        if hi == 0xC and mode == 7 and reg == 6:
            size = 4 if (op & 0x0100) else (2 if sz == 1 else 1)
            val = self.read_ea(mode, reg, size, self.pc + 2)
            src = self.read_ea((op >> 3) & 7, op & 7, size, self.pc + 2)
            r = (src - val)
            self.set_nz(r & ((1 << (size * 8)) - 1), size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # ADDI / SUBI
        if hi in (0x6, 0xE) and mode == 7 and reg == 6:
            imm = self.read_ea(7, 4, 2 if (op & 0x0100) else 1, self.pc + 2)
            dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
            v = self.read_ea(dmode, dreg, 2 if (op & 0x0100) else 1, self.pc + 2)
            v = (v + imm) if hi == 0x6 else (v - imm)
            self.write_ea(dmode, dreg, 2 if (op & 0x0100) else 1, v, self.pc + 2)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # ORI
        if hi in (0, 0xA) and mode == 7 and reg == 6:
            imm = self.read_ea(7, 4, 2 if (op & 0x0100) else 1, self.pc + 2)
            dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
            v = self.read_ea(dmode, dreg, 2 if (op & 0x0100) else 1, self.pc + 2)
            self.write_ea(dmode, dreg, 2 if (op & 0x0100) else 1, v | imm, self.pc + 2)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # BTST/BCHG/BCLR/BSET
        if hi in (0, 0x8) and mode == 0:
            bit = op & 0xFF
            dn = (op >> 9) & 7
            v = self.get_d(dn)
            self.sr = (self.sr & ~0x4) | (2 if (v >> (bit & 31)) & 1 else 0)
            if hi == 0x8:  # static
                kind = (op >> 6) & 3
                if kind == 1:  # BCHG
                    dmode = (op >> 3) & 7; dreg = op & 7
                    ea, is_addr = self.calc_ea(dmode, dreg, 1, self.pc + 2)
                    b = self.rd8(ea)
                    if (b >> (bit & 7)) & 1: b ^= (1 << (bit & 7))
                    self.wr8(ea, b)
                elif kind == 2:  # BCLR
                    dmode = (op >> 3) & 7; dreg = op & 7
                    ea, is_addr = self.calc_ea(dmode, dreg, 1, self.pc + 2)
                    self.wr8(ea, self.rd8(ea) & ~(1 << (bit & 7)))
                elif kind == 3:  # BSET
                    dmode = (op >> 3) & 7; dreg = op & 7
                    ea, is_addr = self.calc_ea(dmode, dreg, 1, self.pc + 2)
                    self.wr8(ea, self.rd8(ea) | (1 << (bit & 7)))
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # MOVE to SR / CCR etc se saltan
        # SUBQ/ADDQ
        if hi in (5, 4) and (op & 0xF0) in (0x50, 0x40, 0xA0, 0xA8) or (op & 0xF00) == 0x500 or (op & 0xF00) == 0x510:
            pass
        # (simplificado) SUBQ 0101 xxx dreg 1w 0001 000 10 dreg1w 01
        if (op & 0xF1F0) == 0x5140 or (op & 0xF1F0) == 0x5148 or (op & 0xF1F0) == 0x5040:
            v = (op >> 9) & 7
            if v == 0: v = 8
            dmode = (op >> 6) & 7; dreg = op & 7
            x = self.read_ea(dmode, dreg, 1, self.pc + 2)
            x = (x - v) & 0xFF
            self.write_ea(dmode, dreg, 1, x, self.pc + 2)
            self.set_nz(x, 1)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if (op & 0xF1F0) == 0x5040 or (op & 0xF1F0) == 0x5048:
            v = (op >> 9) & 7
            if v == 0: v = 8
            dmode = (op >> 6) & 7; dreg = op & 7
            x = self.read_ea(dmode, dreg, 1, self.pc + 2)
            x = (x + v) & 0xFF
            self.write_ea(dmode, dreg, 1, x, self.pc + 2)
            self.set_nz(x, 1)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # INC/DEC word
        if (op & 0xF1F0) == 0x5240:
            dmode = (op >> 6) & 7; dreg = op & 7
            ea, ia = self.calc_ea(dmode, dreg, 2, self.pc + 2)
            x = (self.rd16(ea) + 1) & 0xFFFF
            self.wr16(ea, x); self.set_nz(x, 2)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if (op & 0xF1F0) == 0x5240:
            dmode = (op >> 6) & 7; dreg = op & 7
            ea, ia = self.calc_ea(dmode, dreg, 2, self.pc + 2)
            x = (self.rd16(ea) - 1) & 0xFFFF
            self.wr16(ea, x); self.set_nz(x, 2)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # CLR
        if (op & 0xFF00) in (0x4200, 0x4300, 0x4400):
            size = 4 if (op & 0xFF00) == 0x4400 else (2 if (op & 0xFF00) == 0x4200 else 1)
            dmode = (op >> 3) & 7; dreg = op & 7
            ea, ia = self.calc_ea(dmode, dreg, size, self.pc + 2)
            if size == 1: self.wr8(ea, 0)
            elif size == 2: self.wr16(ea, 0)
            else: self.wr32(ea, 0)
            self.sr = (self.sr & ~0xC) | 0x4
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # LEA
        if hi == 4 and mode == 3 and reg == 7 and (op & 0xF1C0) == 0x41C0 or (op & 0xF1F8) == 0x41F8 or (op & 0xF1F8) == 0x41E8 or (op & 0xF1F8) == 0x43F0:
            pass
        if (op & 0xFFC0) == 0x41C0 or (op & 0xF1F8) == 0x41C0 or (op & 0xFFC0) == 0x41E8 or (op & 0xF1F8) == 0x41E8:
            dmode = (op >> 3) & 7; dreg = (op >> 9) & 7
            ea, ia = self.calc_ea(dmode, dreg, 4, self.pc + 2)
            self.set_a(dreg, ea)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if (op & 0xF1C0) == 0x41C0:
            dmode = (op >> 3) & 7; dreg = (op >> 9) & 7
            ea, ia = self.calc_ea(dmode, dreg, 4, self.pc + 2)
            self.set_a(dreg, ea)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # PEA
        if (op & 0xFFC0) == 0x4840:
            smode = (op >> 3) & 7; sreg = op & 7
            ea, ia = self.calc_ew(smode, sreg, 4, self.pc + 2)
            self.set_a(7, (self.get_a(7) - 4) & 0xFFFFFFFF)
            self.wr32(self.get_a(7), ea)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # MOVEM
        if (op & 0xFB80) == 0x4880 or (op & 0xFB80) == 0x4C80:
            w = (op >> 3) & 1
            l = (op >> 6) & 1
            predec = (op >> 10) & 1
            reglist = op & 0xFF
            amode = (op >> 3) & 7
            areg = op & 7
            a = self.get_a(areg)
            size = 4 if l else 2
            for i in range(8):
                if reglist & (1 << i):
                    if predec:
                        a = (a - size) & 0xFFFFFFFF
                        if areg == 7: self.set_a(7, a)
                        if l: self.wr32(a, self.get_d(i))
                        else: self.wr16(a, self.get_d(i) & 0xFFFF)
                    else:
                        if l: self.wr32(a, self.get_d(i))
                        else: self.wr16(a, self.get_d(i) & 0xFFFF)
                        a = (a + size) & 0xFFFFFFFF
                        if areg == 7: self.set_a(7, a)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # TST (0100 1010 ss mmmrrr) = 0x4A00..0x4AFF  (hi=4, op&0xFF00==0x4A)
        if (op & 0xFF00) == 0x4A00 and mode != 0 and mode != 1:
            size = 4 if sz == 2 else (2 if sz == 1 else 1)
            dmode = mode; dreg = op & 7
            # extension length: mode 7 reg 0/2 = 2 extra, reg 1 = 4 extra
            extlen = 0
            if mode == 7 and reg in (0, 2): extlen = 2
            elif mode == 7 and reg == 1: extlen = 4
            elif mode == 5: extlen = 2
            elif mode == 6: extlen = 1
            elif mode == 7 and reg == 4: extlen = 2 if size == 2 else (4 if size == 4 else 1)
            v = self.read_ea(dmode, dreg, size, self.pc + 2)
            self.set_nz(v, size)
            self.pc = (self.pc + 2 + extlen) & 0xFFFFFF
            return
        # CMP
        if hi in (0xB, 3):
            size = 4 if hi == 3 else (2 if sz == 1 else 1)
            smode = (op >> 3) & 7; sreg = op & 7
            src = self.read_ea(smode, sreg, size, self.pc + 2)
            dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
            dst = self.read_ea(dmode, dreg, size, self.pc + 2)
            r = (dst - src)
            self.set_nz(r & ((1 << (size * 8)) - 1), size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # ADD/SUB (Dn,<ea> and <ea>,Dn)
        if hi in (0xD, 9, 0xE) and (op & 0xF000) in (0xD000, 0x9000) and hi != 0xE:
            pass
        # SUB
        if hi == 0x9 and (op & 0xF000) == 0x9000 and mode not in (1,):
            # SUB <ea>,Dn
            size = 4 if (op & 0x0100) else (2 if sz == 1 else 1)
            smode = (op >> 3) & 7; sreg = op & 7
            src = self.read_ea(smode, sreg, size, self.pc + 2)
            dreg = (op >> 9) & 7
            dst = self.get_d(dreg)
            r = (dst - src)
            m = (1 << (size * 8)) - 1
            self.set_d(dreg, r & m)
            self.set_nz(r & m, size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        if hi == 0x5 and (op & 0xF000) == 0x5000 and mode not in (0, 1):
            # ADD <ea>,Dn
            size = 4 if (op & 0x0100) else (2 if sz == 1 else 1)
            smode = (op >> 3) & 7; sreg = op & 7
            src = self.read_ea(smode, sreg, size, self.pc + 2)
            dreg = (op >> 9) & 7
            dst = self.get_d(dreg)
            r = (dst + src)
            m = (1 << (size * 8)) - 1
            self.set_d(dreg, r & m)
            self.set_nz(r & m, size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # SUB Dn,<ea> (size) - 1001 xxx 1x eeeee
        if hi == 0x9 and (op & 0xF100) == 0x9100:
            size = 4 if (op & 0x0100) else (2 if sz == 1 else 1)
            dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
            sreg = op & 7
            src = self.get_d(sreg) & ((1 << (size * 8)) - 1)
            ea, ia = self.calc_ew(dmode, dreg, size, self.pc + 2)
            if ia:
                cur = self.rd8(ea) if size == 1 else (self.rd16(ea) if size == 2 else self.rd32(ea))
                r = (cur - src)
                if size == 1: self.wr8(ea, r & 0xFF)
                elif size == 2: self.wr16(ea, r & 0xFFFF)
                else: self.wr32(ea, r & 0xFFFFFFFF)
                self.set_nz(r & ((1 << (size * 8)) - 1), size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # ADD Dn,<ea>
        if hi == 0xD and (op & 0xF100) == 0xD100:
            size = 4 if (op & 0x0100) else (2 if sz == 1 else 1)
            dmode = (op >> 6) & 7; dreg = (op >> 9) & 7
            sreg = op & 7
            src = self.get_d(sreg) & ((1 << (size * 8)) - 1)
            ea, ia = self.calc_ew(dmode, dreg, size, self.pc + 2)
            if ia:
                cur = self.rd8(ea) if size == 1 else (self.rd16(ea) if size == 2 else self.rd32(ea))
                r = (cur + src)
                if size == 1: self.wr8(ea, r & 0xFF)
                elif size == 2: self.wr16(ea, r & 0xFFFF)
                else: self.wr32(ea, r & 0xFFFFFFFF)
                self.set_nz(r & ((1 << (size * 8)) - 1), size)
            self.pc = (self.pc + 2 + self._ext) & 0xFFFFFF; return
        # fallthrough: instruccion no implementada -> parar
        self.stopped = True
        self.unknown_op = op


if __name__ == '__main__':
    rom = open(ROM_PATH, 'rb').read()
    cpu = M68K(rom)
    # arrancar en el vector de reset
    reset = struct.unpack('>I', rom[4:8])[0]
    cpu.pc = reset
    cpu.set_a(7, RAM_BASE + RAM_SIZE - 0x400)
    print(f"reset vector = 0x{reset:06X}")
    print("Tracer: ejecuta hasta parar o alcanzar limite.")
    n = 0
    limit = 2_000_000
    while not cpu.stopped and n < limit:
        cpu.step()
        n += 1
        if n % 500_000 == 0:
            print(f"  {n} instr, pc=0x{cpu.pc:06X}, a5=0x{cpu.get_a(5):08X}")
    print(f"Parado en {n} instrucciones, pc=0x{cpu.pc:06X}")
    if cpu.stopped:
        print(f"Instruccion no implementada: 0x{cpu.unknown_op:04X} en 0x{cpu.pc:06X}")
