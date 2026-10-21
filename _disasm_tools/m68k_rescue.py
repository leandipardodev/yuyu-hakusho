"""
Rescate de instrucciones M68000 que el core de Unicorn 2.1.4 NO implementa.

Lista obtenida empiricamente (scan3.py, 88 casos de prueba):
  RTE, RTR
  ORI.W #n,SR        ORI.B #n,CCR
  ORI/ANDI/SUBI/ADDI/EORI #n,Dn
  ADDQ/SUBQ #n,Dn
  NEG.W Dn           NOT.W Dn
  MOVEM
  BTST/BCHG/BCLR/BSET (estatico y dinamico sobre Dn)
  ASL/ASR/LSL/LSR/ROL/ROR/ROXL/ROXR (Dn)
  TRAP #n

Semantica M68000 implementada a mano (CCR: C=bit0 V=1 Z=2 N=3, X=bit4).
"""
import struct

DR = [None]  # se rellena en bind_regs


def bind_regs(uc_consts):
    global DR
    DR = list(uc_consts)


class Rescuer:
    def __init__(self, uc, log=None):
        self.uc = uc
        self.count = {}

    # ---------- registros ----------
    def rd(self, i):
        return self.uc.reg_read(DR[i]) & 0xFFFFFFFF

    def wr(self, i, v):
        self.uc.reg_write(DR[i], v & 0xFFFFFFFF)

    def ra(self, i):
        return self.uc.reg_read(self.AR[i]) & 0xFFFFFFFF

    def wa(self, i, v):
        self.uc.reg_write(self.AR[i], v & 0xFFFFFFFF)

    def get_sr(self):
        return self.uc.reg_read(self.SR)

    def set_sr(self, v):
        self.uc.reg_write(self.SR, v & 0xFFFF)

    # ---------- flags ----------
    @staticmethod
    def m(v, size):
        return (1 << (size * 8)) - 1

    def set_nz(self, res, size):
        sr = self.get_sr()
        res &= self.m(res, size)
        if res == 0:
            sr |= 0x04                      # Z
        else:
            sr &= ~0x04
        if res & (1 << (size * 8 - 1)):
            sr |= 0x08                      # N
        else:
            sr &= ~0x08
        self.set_sr(sr)

    def set_logic_flags(self, res, size):
        self.set_nz(res, size)
        sr = self.get_sr()
        sr &= ~0x01
        sr &= ~0x02
        self.set_sr(sr)

    def set_add_flags(self, a, b, r, size):
        m = self.m(r, size)
        a &= m
        b &= m
        r &= m
        sr = self.get_sr()
        msb = 1 << (size * 8 - 1)
        if r == 0:
            sr |= 0x04
        else:
            sr &= ~0x04
        if r & msb:
            sr |= 0x08
        else:
            sr &= ~0x08
        if (~(a ^ b) & (a ^ r)) & msb:
            sr |= 0x02                      # V
        else:
            sr &= ~0x02
        if ((a & m) + (b & m)) > m:
            sr |= 0x01                      # C
        else:
            sr &= ~0x01
        self.set_sr(sr)

    def set_sub_flags(self, a, b, r, size):
        m = self.m(r, size)
        a &= m
        b &= m
        r &= m
        sr = self.get_sr()
        msb = 1 << (size * 8 - 1)
        if r == 0:
            sr |= 0x04
        else:
            sr &= ~0x04
        if r & msb:
            sr |= 0x08
        else:
            sr &= ~0x08
        if ((a ^ b) & (a ^ r)) & msb:
            sr |= 0x02
        else:
            sr &= ~0x02
        if b > a:
            sr |= 0x01
        else:
            sr &= ~0x01
        self.set_sr(sr)

    # ---------- direccionamiento ----------
    def ea_len(self, mode, reg, size):
        if mode == 0:
            return 0
        if mode == 5:
            return 2
        if mode == 6:
            return 2
        if mode == 7:
            if reg in (0, 2):
                return 2
            if reg == 1:
                return 4
            if reg == 3:
                return 2
            if reg == 4:
                return 2 if size != 4 else 4
        return 0

    def ea_addr(self, pc, mode, reg, size):
        """direccion efectiva. pc = direccion de la palabra de operacion."""
        if mode == 0:
            return None
        if mode == 2:
            return self.ra(reg)
        if mode == 3:
            return self.ra(reg)
        if mode == 4:
            return None                      # handled aparte
        if mode == 5:
            d = self.rdmem_s(pc + 2, 2)
            return (self.ra(reg) + d) & 0xFFFFFFFF
        if mode == 6:
            ext = self.rdmem(pc + 2, 2)
            d = ext & 0xFF
            if d & 0x80:
                d -= 0x100
            rn = (ext >> 12) & 0xF
            idx = self.rd(rn) & 0xFFFFFFFF
            # el indice se escala segun el tamano del acceso
            if size == 2:
                idx = (idx << 1) & 0xFFFFFFFF
            elif size == 4:
                idx = (idx << 2) & 0xFFFFFFFF
            # bit 11 = 0 -> registro de direcciones (sin signo)
            # bit 11 = 1 -> registro de datos (con signo)
            if ext & 0x0800:
                idx = (-idx) & 0xFFFFFFFF
            return (self.ra(reg) + d + idx) & 0xFFFFFFFF
        if mode == 7:
            if reg == 0:
                return self.rdmem(pc + 2, 2)
            if reg == 1:
                return self.rdmem(pc + 2, 4)
            if reg == 2:
                base = pc + 2
                d = self.rdmem_s(base, 2)
                return (base + d) & 0xFFFFFFFF
            if reg == 3:
                return self.ra(reg)
            if reg == 4:
                return None                  # inmediato
        return None

    def rdmem_s(self, addr, size):
        """lectura con signo de un operando extension."""
        v = self.rdmem(addr, size)
        bits = size * 8
        return v - (1 << bits) if v & (1 << (bits - 1)) else v

    def rdmem(self, addr, size):
        addr &= 0xFFFFFF          # el bus del 68000 es de 24 bits
        try:
            b = bytes(self.uc.mem_read(addr, size))
        except Exception:
            b = b"\x00" * size
        if size == 1:
            return b[0]
        if size == 2:
            return struct.unpack(">H", b)[0]
        return struct.unpack(">I", b)[0]

    def wrmem(self, addr, size, val):
        addr &= 0xFFFFFF
        if size == 1:
            data = bytes([val & 0xFF])
        elif size == 2:
            data = struct.pack(">H", val & 0xFFFF)
        else:
            data = struct.pack(">I", val & 0xFFFFFFFF)
        try:
            self.uc.mem_write(addr, data)
        except Exception:
            pass

    def read_ea(self, pc, mode, reg, size):
        if mode == 0:
            v = self.rd(reg)
            return v & self.m(v, size)
        if mode == 1:
            v = self.rd(reg) & 0xFFFF
            if size == 4:
                v = v - 0x10000 if v & 0x8000 else v
            return v & self.m(v, size)
        if mode == 4:                          # -(An)
            a = (self.ra(reg) - size) & 0xFFFFFFFF
            self.wa(reg, a)
            return self.rdmem(a, size) & self.m(0, size)
        a = self.ea_addr(pc, mode, reg, size)
        if a is None:
            return 0
        return self.rdmem(a, size) & self.m(0, size)

    def write_ea(self, pc, mode, reg, size, val):
        if mode == 0:
            v = val & self.m(val, size)
            cur = self.rd(reg)
            if size == 4:
                self.wr(reg, v)
            elif size == 1:
                self.wr(reg, (cur & 0xFFFFFF00) | (v & 0xFF))
            else:
                self.wr(reg, (cur & 0xFFFF0000) | (v & 0xFFFF))
            return
        if mode == 4:                          # -(An)
            a = (self.ra(reg) - size) & 0xFFFFFFFF
            self.wa(reg, a)
            self.wrmem(a, size, val)
            return
        if mode == 1:                          # (An)+
            a = self.ra(reg)
            step = size
            if reg == 7 and size == 2:
                step = 2
            self.wrmem(a, size, val)
            self.wa(reg, (a + step) & 0xFFFFFFFF)
            return
        a = self.ea_addr(pc, mode, reg, size)
        if a is None:
            return
        self.wrmem(a, size, val)
