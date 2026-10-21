"""Despachador de la capa de rescate: recibe el opcode fallido y lo emula."""
import struct
from unicorn.m68k_const import (UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2,
                                 UC_M68K_REG_D3, UC_M68K_REG_D4, UC_M68K_REG_D5,
                                 UC_M68K_REG_D6, UC_M68K_REG_D7,
                                 UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A2,
                                 UC_M68K_REG_A3, UC_M68K_REG_A4, UC_M68K_REG_A5,
                                 UC_M68K_REG_A6, UC_M68K_REG_A7,
                                 UC_M68K_REG_SR, UC_M68K_REG_PC)
import m68k_rescue as R


class Dispatcher(R.Rescuer):
    def __init__(self, uc):
        R.bind_regs([UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2, UC_M68K_REG_D3,
                     UC_M68K_REG_D4, UC_M68K_REG_D5, UC_M68K_REG_D6, UC_M68K_REG_D7])
        self.AR = [UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A2, UC_M68K_REG_A3,
                   UC_M68K_REG_A4, UC_M68K_REG_A5, UC_M68K_REG_A6, UC_M68K_REG_A7]
        self.PC = UC_M68K_REG_PC
        self.SR = UC_M68K_REG_SR
        super().__init__(uc)
        self.stats = {}

    def bump(self, k):
        self.stats[k] = self.stats.get(k, 0) + 1

    def get_pc(self):
        return self.uc.reg_read(self.PC)

    def set_pc(self, v):
        self.uc.reg_write(self.PC, v & 0xFFFFFF)

    def imm_len(self, size):
        return 2 if size != 4 else 4

    # ------------------------------------------------------------------
    def handle(self, op, pc):
        """Emula la instruccion en `pc`. Devuelve True si la|Att handled."""
        opc = self.rdmem(pc, 2)
        mode = (opc >> 3) & 7
        reg = opc & 7
        size = 1
        if (opc >> 6) & 3 == 1:
            size = 2
        elif (opc >> 6) & 3 == 2:
            size = 4
        # tamano por defecto segun el grupo
        szbits = (opc >> 6) & 3

        # ---- MOVE con direccionamiento indexado (Unicorn no lo soporta) ----
        if (opc & 0xC000) == 0x0000 and (opc & 0x3000) != 0x3000:
            dmode = (opc >> 6) & 7
            dreg = (opc >> 9) & 7
            smode = (opc >> 3) & 7
            sreg = opc & 7
            dsize = {0: 1, 1: 2, 2: 4}[dmode]
            ssize = {0: 1, 1: 2, 2: 4}[(opc >> 12) & 3]
            if dmode == 6 or smode == 6:
                val = self.read_ea(pc, smode, sreg, ssize)
                self.write_ea(pc, dmode, dreg, dsize, val)
                self.set_logic_flags(val & self.m(val, dsize), dsize)
                ext = self.ea_len(dmode, dreg, dsize) + self.ea_len(smode, sreg, ssize)
                self.set_pc(pc + 2 + ext)
                self.bump("MOVE indexado")
                return True

        # ---- MOVE desde/hacia SR y CCR (Unicorn no los soporta con EA variable) ----
        # 0x40C0|ea = MOVE SR,<ea>   0x46C0|ea = MOVE <ea>,SR
        # 0x42C0|ea = MOVE CCR,<ea>  0x44C0|ea = MOVE <ea>,CCR
        if (opc & 0xFFC0) in (0x40C0, 0x46C0, 0x42C0, 0x44C0):
            base = opc & 0xFFC0
            size = 1 if base in (0x42C0, 0x44C0) else 2
            mode = (opc >> 3) & 7
            reg = opc & 7
            ext = self.ea_len(mode, reg, size)
            sr = self.get_sr()
            if base == 0x40C0:                  # MOVE SR,<ea>
                self.write_ea(pc, mode, reg, size, sr & 0xFFFF)
            elif base == 0x42C0:                # MOVE CCR,<ea>
                self.write_ea(pc, mode, reg, size, sr & 0xFF)
            elif base == 0x46C0:                # MOVE <ea>,SR
                v = self.read_ea(pc, mode, reg, 2)
                self.set_sr(v & 0xFFFF)
            else:                               # MOVE <ea>,CCR
                v = self.read_ea(pc, mode, reg, 1)
                self.set_sr((sr & 0xFF00) | (v & 0xFF))
            self.set_pc(pc + 2 + ext)
            self.bump("MOVE SR/CCR")
            return True

        # ---- RTE / RTR ----
        if opc == 0x4E73:
            sp = self.ra(7)
            npc = self.rdmem(sp, 4)
            nsr = self.rdmem(sp + 4, 2)
            self.wa(7, sp + 6)
            self.set_sr(nsr)
            self.set_pc(npc)
            self.bump("RTE")
            return True
        if opc == 0x4E77:
            sp = self.ra(7)
            ccr = self.rdmem(sp, 2)
            npc = struct.unpack(">I", self.rdmem(sp + 2, 4))[0]
            self.wa(7, sp + 6)
            sr = self.get_sr() & 0xFF00
            self.set_sr(sr | (ccr & 0xFF))
            self.set_pc(npc)
            self.bump("RTR")
            return True

        # ---- TRAP #n ----
        if (opc & 0xFFF0) == 0x4E40:
            # vector 32+n: el juego no lo usa, pero lo emulamos saltando
            vec = 32 + (opc & 0xF)
            addr = self.rdmem(vec * 4, 4)
            self.set_pc(addr)
            self.bump("TRAP")
            return True

        # ---- ORI.W #n,SR / ORI.B #n,CCR ----
        if opc == 0x007C:
            imm = self.rdmem(pc + 2, 2)
            self.set_sr(self.get_sr() | imm)
            self.set_pc(pc + 4)
            self.bump("ORI.W,SR")
            return True
        if opc == 0x003C:
            imm = self.rdmem(pc + 2, 1)
            sr = self.get_sr()
            self.set_sr((sr & 0xFF00) | ((sr | imm) & 0xFF))
            self.set_pc(pc + 3)
            self.bump("ORI.B,CCR")
            return True
        if opc == 0x027C:                        # ANDI.W #n,SR
            imm = self.rdmem(pc + 2, 2)
            self.set_sr(self.get_sr() & imm)
            self.set_pc(pc + 4)
            self.bump("ANDI.W,SR")
            return True
        if opc == 0x0A7C:                        # EORI.W #n,SR
            imm = self.rdmem(pc + 2, 2)
            self.set_sr(self.get_sr() ^ imm)
            self.set_pc(pc + 4)
            self.bump("EORI.W,SR")
            return True

        # ---- DBcc / DBRA : 0101 00cc 11 001 rrr  (0x50C8 base) ----
        if (opc & 0xF0C0) == 0x50C0:            # DBcc / DBRA
            cc = (opc >> 8) & 0xF
            dreg = opc & 7
            d16 = self.rdmem_s(pc + 2, 2)
            if self._cond(cc):
                self.set_pc(pc + 4)
            else:
                dn = (self.rd(dreg) - 1) & 0xFFFF
                cur = self.rd(dreg)
                self.wr(dreg, (cur & 0xFFFF0000) | dn)
                if dn != 0xFFFF:
                    self.set_pc(pc + 2 + d16)
                else:
                    self.set_pc(pc + 4)
            self.bump("DBcc")
            return True

        # ---- immediatos a registro de datos:
        #      ORI 0x00xx | ANDI 0x02xx | SUBI 0x04xx | ADDI 0x06xx | CMPI 0x0Cxx
        top = opc & 0xF000
        if top in (0x0000, 0x0200, 0x0400, 0x0600, 0x0C00) and ((opc & 0x0100) == 0) \
                and (opc & 0x00C0) != 0x00C0:
            # soloDn (mode 0). Los modos de memoria los cubre Unicorn.
            if mode == 0:
                size = {0: 1, 1: 2, 2: 4}[szbits]
                if size == 1 and szbits == 0:
                    pass
                ilen = self.imm_len(size)
                imm = self.rdmem(pc + 2, ilen)
                cur = self.read_ea(pc, 0, reg, size)
                if top == 0x0000:
                    res = (cur | imm) & self.m(cur, size)
                elif top == 0x0200:
                    res = (cur & imm) & self.m(cur, size)
                elif top == 0x0400:
                    res = self.rdmem(pc + 2, ilen)
                    self.set_sub_flags(cur, imm, cur - imm, size)
                elif top == 0x0600:
                    res = self.rdmem(pc + 2, ilen)
                    self.set_add_flags(cur, imm, cur + imm, size)
                else:  # CMPI
                    imm = self.rdmem(pc + 2, ilen)
                    self.set_sub_flags(cur, imm, cur - imm, size)
                    self.set_pc(pc + 2 + ilen)
                    self.bump("CMPI")
                    return True
                if top != 0x0C00:
                    self.write_ea(pc, 0, reg, size, res)
                    self.set_logic_flags(res, size)
                self.set_pc(pc + 2 + ilen)
                self.bump("imm2Dn")
                return True

        # ---- ADDQ/SUBQ #n,Dn  : 0101 ddd 0 ss 00 0 rrr ----
        if (opc & 0xF000) == 0x5000 and mode == 0 and ((opc & 0x00C0) != 0x00C0):
            data = (opc >> 9) & 7
            q = 8 if data == 0 else data
            size = {0: 1, 1: 2, 2: 4}[szbits]
            cur = self.read_ea(pc, 0, reg, size)
            if (opc & 0x0100) == 0:             # ADDQ
                self.set_add_flags(cur, q, cur + q, size)
                res = cur + q
            else:                                # SUBQ
                self.set_sub_flags(cur, q, cur - q, size)
                res = cur - q
            self.write_ea(pc, 0, reg, size, res)
            self.set_pc(pc + 2)
            self.bump("ADDQ/SUBQ")
            return True

        # ---- NEG/NOT Dn : 0100 0000/0100 0100 ss 000rrr ----
        if (opc & 0xFF38) == 0x4400:            # NEG
            size = {0: 1, 1: 2, 2: 4}[szbits]
            cur = self.read_ea(pc, 0, reg, size)
            self.set_sub_flags(0, cur, -cur, size)
            self.write_ea(pc, 0, reg, size, -cur)
            self.set_pc(pc + 2)
            self.bump("NEG")
            return True
        if (opc & 0xFF38) == 0x4600:            # NOT
            size = {0: 1, 1: 2, 2: 4}[szbits]
            cur = self.read_ea(pc, 0, reg, size)
            res = ~cur & self.m(cur, size)
            self.write_ea(pc, 0, reg, size, res)
            self.set_logic_flags(res, size)
            self.set_pc(pc + 2)
            self.bump("NOT")
            return True

        # ---- MOVEM ----
        if (opc & 0xFB80) in (0x4880, 0x4C80):
            to_reg = (opc & 0x0400) != 0
            size = 4 if ((opc >> 6) & 1) else 2
            mode = (opc >> 3) & 7
            reg = opc & 7
            mask = self.rdmem(pc + 2, 2)
            a = self.ra(reg)
            n = 16 if size == 4 else 8
            if mode == 4:                        # (An)+
                step = size
                regs = range(n)
                for i in regs:
                    if mask & (1 << i):
                        v = self.rd(i) if to_reg else self.rdmem(a, size)
                        if not to_reg:
                            self.rdmem(a, size)
                        if to_reg:
                            if size == 4:
                                self.wr(i, v)
                            else:
                                cur = self.rd(i)
                                v = v - 0x10000 if v & 0x8000 else v
                                self.wr(i, (cur & 0xFFFF0000) | (v & 0xFFFF))
                        a = (a + step) & 0xFFFFFFFF
                    else:
                        a = (a + step) & 0xFFFFFFFF
            elif mode == 3:                      # -(An)
                step = size
                a = (a - 8) & 0xFFFFFFFF if size == 2 else (a - 7) & 0xFFFFFFFF
                for i in range(n - 1, -1, -1):
                    if mask & (1 << i):
                        v = self.rd(i) if to_reg else self.rdmem(a, size)
                        if to_reg:
                            if size == 4:
                                self.wr(i, v)
                            else:
                                cur = self.rd(i)
                                vv = v - 0x10000 if v & 0x8000 else v
                                self.wr(i, (cur & 0xFFFF0000) | (vv & 0xFFFF))
                    a = (a - step) & 0xFFFFFFFF
            if mode in (3, 4):
                self.wa(reg, a)
            self.set_pc(pc + 4)
            self.bump("MOVEM")
            return True

        # ---- BSET/BCLR/BCHG/BTST ----
        # estatico: 0000 100 0 ss mmmrrr ; dinamico: 0000 rrr 001 ss mmmrrr
        if (opc & 0xF100) == 0x0800:            # estatico
            size = {0: 1, 1: 2, 2: 4}[szbits]
            bit = (opc >> 9) & 7
            mode = (opc >> 3) & 7
            reg = opc & 7
            if mode == 0:
                cur = self.rdmem(pc + 2, 2)      # el numero de bit esta en extension
                b = bit
            else:
                b = cur if False else bit
            val = self.read_ea(pc, mode, reg, size)
            self.set_nz_from_bit(val, b, size)
            ext = self.ea_len(mode, reg, size)
            opc2 = (opc >> 6) & 3
            if opc2 == 1:                       # BCHG
                self.write_ea(pc, mode, reg, size, val ^ (1 << b))
            elif opc2 == 2:                     # BCLR
                self.write_ea(pc, mode, reg, size, val & ~(1 << b))
            elif opc2 == 3:                     # BSET
                self.write_ea(pc, mode, reg, size, val | (1 << b))
            if mode == 0:
                self.set_pc(pc + 4)
            else:
                self.set_pc(pc + 2 + ext)
            self.bump("bitstat")
            return True
        if (opc & 0xF100) == 0x0100:            # dinamico
            size = {0: 1, 1: 2, 2: 4}[szbits]
            mode = (opc >> 3) & 7
            reg = opc & 7
            b = self.rd((opc >> 9) & 7) % (size * 8)
            val = self.read_ea(pc, mode, reg, size)
            self.set_nz_from_bit(val, b, size)
            ext = self.ea_len(mode, reg, size)
            opc2 = (opc >> 6) & 3
            if opc2 == 1:
                self.write_ea(pc, mode, reg, size, val ^ (1 << b))
            elif opc2 == 2:
                self.write_ea(pc, mode, reg, size, val & ~(1 << b))
            elif opc2 == 3:
                self.write_ea(pc, mode, reg, size, val | (1 << b))
            self.set_pc(pc + 2 + ext)
            self.bump("bitdyn")
            return True

        # ---- shifts sobre Dn : 1110 ccc d ss i rrr ----
        if (opc & 0xF000) == 0xE000:
            size = {0: 1, 1: 2, 2: 4}[szbits]
            reg = opc & 7
            ccc = (opc >> 9) & 7
            left = ccc in (0, 4)
            ccr_op = ccc in (2, 3, 6, 7)
            cnt_mode = (opc >> 5) & 3
            if cnt_mode == 0:
                cnt = (opc >> 9) & 7
                if cnt == 0:
                    cnt = 8
            else:
                cnt = self.rd((opc >> 9) & 7) % (size * 8)
            val = self.read_ea(pc, 0, reg, size)
            sr = self.get_sr()
            C = (sr >> 0) & 1
            X = (sr >> 4) & 1
            bits = size * 8
            mask = self.m(val, size)
            msb = 1 << (bits - 1)
            for _ in range(cnt):
                if left:
                    C = (val >> (bits - 1)) & 1
                    val = (val << 1) & mask
                else:
                    C = (val & 1) & 1
                    val = (val >> 1) & mask
                if ccr_op:
                    X = C
            if not left and not ccr_op:
                val = val | (C << (bits - 1)) if ccc == 3 else val
            val &= mask
            if ccc == 1:      # ASx: extension = signo original
                pass
            self.write_ea(pc, 0, reg, size, val)
            self.set_nz(val, size)
            sr = self.get_sr()
            sr = (sr & ~0x01) | C
            sr = (sr & ~0x10) | (X << 4)
            self.set_sr(sr)
            self.set_pc(pc + 2)
            self.bump("shift")
            return True

        return False

    def set_nz_from_bit(self, val, b, size):
        sr = self.get_sr()
        bit = (val >> (b % (size * 8))) & 1
        if bit:
            sr &= ~0x04
        else:
            sr |= 0x04
        self.set_sr(sr)

    def _cond(self, cc):
        sr = self.get_sr()
        c = sr & 1
        v = (sr >> 1) & 1
        z = (sr >> 2) & 1
        n = (sr >> 3) & 1
        return [1, 0, (not c) and (not z), c or z, not c, c, not z, z,
                not v, v, not n, n, n == v, n != v, (not z) and (n == v),
                z or (n != v)][cc]
