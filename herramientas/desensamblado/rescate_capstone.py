"""
Ejecutor generico de instrucciones M68000 basado en Capstone.

Unicorn 2.1.4 rechaza algunas formas de codificacion que si son legales en el
68000. En vez de decodificar a mano (error de(propios), que ya ha pasado) se
usa Capstone como fuente de verdad: nos da tamano, operandos y direccion
effectivea, y aqui se aplica la semantica.

Solo se usa como ULTIMO recurso, cuando Unicorn ha lanzado UC_ERR_EXCEPTION y
la capa de rescate por mascara de bits no lo ha reconocido.
"""
from capstone import Cs, CS_ARCH_M68K, CS_MODE_BIG_ENDIAN
import capstone.m68k as C


class CapExec:
    def __init__(self, r):
        self.r = r
        self.md = Cs(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN)
        self.md.detail = True
        self.stats = {}

    def bump(self, k):
        self.stats[k] = self.stats.get(k, 0) + 1

    # ---- utilidades ----
    def reg_index(self, rid):
        """devuelve ('d'|'a', indice) o None"""
        for i in range(8):
            if rid == C.M68K_REG_D0 + i:
                return ("d", i)
            if rid == C.M68K_REG_A0 + i:
                return ("a", i)
        return None

    def read_reg(self, kind, i):
        return self.r.rd(i) if kind == "d" else self.r.ra(i)

    def write_reg(self, kind, i, v, size):
        if kind == "d":
            if size == 4:
                self.r.wr(i, v)
            else:
                cur = self.r.rd(i)
                mask = 0xFF if size == 1 else 0xFFFF
                shift = 0 if size == 1 else 16
                self.r.wr(i, (cur & ~(mask << shift) & 0xFFFFFFFF) | ((v & mask) << shift))
        else:
            if size == 2:
                self.r.wa(i, v & 0xFFFF)
            else:
                self.r.wa(i, v & 0xFFFFFFFF)

    def size_of(self, name):
        if name.endswith(".b"):
            return 1
        if name.endswith(".w"):
            return 2
        if name.endswith(".l"):
            return 4
        return 0

    # ---- operandos ----
    def op_addr(self, mem, size, pc_base=None):
        """direccion efectiva de un operando de memoria.

        Dos correcciones importantes:

        1) El bus del 68000 es de 24 bits, asi que el resultado se enmascara
           a 0xFFFFFF. El ROM usa operandos absolutos con el nibble alto a 1
           (p.ej. $70026000). Sin truncar la lectura cae fuera del mapa,
           devuelve 0 y el salto va a PC=0.

        2) Direccionamiento RELATIVO AL PC: la base NO es el valor del
           registro PC, sino la direccion de la palabra de extension
           (pc_base = ins.address + 2). Usar el PC actual desvia el calculo.
           Esto rompia las tablas de saltos, p.ej. 'jmp $37D20(pc,d7.w)'.
        """
        addr = mem.disp & 0xFFFFFFFF
        if mem.base_reg:
            if mem.base_reg == C.M68K_REG_PC:
                if pc_base is not None:
                    addr += pc_base
            else:
                ri = self.reg_index(mem.base_reg)
                if ri:
                    addr += self.read_reg(ri[0], ri[1])
        if mem.index_reg:
            ri = self.reg_index(mem.index_reg)
            if ri:
                v = self.read_reg(ri[0], ri[1])
                addr += (v * mem.scale) if mem.scale else v
        return addr & 0xFFFFFF

    def get(self, op, size):
        if op.type == C.M68K_OP_REG:
            ri = self.reg_index(op.reg)
            if not ri:
                return None
            v = self.read_reg(ri[0], ri[1])
            return v & self.r.m(v, size)
        if op.type == C.M68K_OP_IMM:
            v = op.imm
            if size == 1:
                v &= 0xFF
            elif size == 2:
                v &= 0xFFFF
            return v & 0xFFFFFFFF
        if op.type == C.M68K_OP_MEM:
            a = self.op_addr(op.mem, size, self._pcb)
            return self.r.rdmem(a, size) & self.r.m(0, size)
        return None

    def put(self, op, size, val):
        if op.type == C.M68K_OP_REG:
            ri = self.reg_index(op.reg)
            if ri:
                self.write_reg(ri[0], ri[1], val, size)
            return True
        if op.type == C.M68K_OP_MEM:
            a = self.op_addr(op.mem, size, self._pcb)
            self.r.wrmem(a, size, val)
            return True
        return False

    # ---- punto de entrada ----
    def try_exec(self, pc, mnemonic_hint=None):
        try:
            raw = bytes(self.r.uc.mem_read(pc, 12))
        except Exception:
            return False
        ins = None
        for i in self.md.disasm(raw, pc, count=1):
            ins = i
            break
        if ins is None:
            return False
        self._pcb = ins.address + 2   # base para direccionamiento relativo al PC
        base = ins.mnemonic.split(".")[0]
        size = self.size_of(ins.mnemonic) or self._size_from_ops(ins)
        try:
            if base in ("move", "movea"):
                return self._move(ins, size)
            if base == "moveq":
                return self._moveq(ins)
            if base in ("add", "addi", "addq", "adda"):
                return self._alu(ins, size, "+")
            if base in ("sub", "subi", "subq", "suba"):
                return self._alu(ins, size, "-")
            if base in ("and", "andi"):
                return self._logic(ins, size, "&")
            if base in ("or", "ori"):
                return self._logic(ins, size, "|")
            if base == "eor":
                return self._logic(ins, size, "^")
            if base == "cmp":
                return self._cmp(ins, size)
            if base == "cmpi":
                return self._cmpi(ins, size)
            if base == "lea":
                return self._lea(ins)
            if base == "clr":
                return self._clr(ins, size)
            if base in ("jmp", "jsr"):
                return self._jmp(ins, base)
            if base == "rts":
                return self._rts(ins)
            if base == "rte":
                return self._rte(ins)
            if base == "rti":
                return self._rts(ins)
            if base == "nop":
                self.r.set_pc(pc + 2)
                return True
            if base in ("btst", "bchg", "bclr", "bset"):
                return self._bitop(ins, size)
        except Exception as e:
            self.bump("fallo:" + base)
            self.r.log("  capexec fallo en 0x%06X %s %s (%s)" % (pc, ins.mnemonic, ins.op_str, e))
            return False
        self.bump("sin soporte:" + base)
        return False

    def _size_from_ops(self, ins):
        for o in ins.operands:
            if o.type == C.M68K_OP_IMM:
                return 4 if o.imm > 0xFFFF or o.imm < -0x8000 else 2
        return 2

    def _move(self, ins, size):
        ops = ins.operands
        if len(ops) != 2:
            return False
        val = self.get(ops[0], size)
        if val is None:
            return False
        self.put(ops[1], size, val)
        if ops[1].type != C.M68K_OP_REG or self.reg_index(ops[1].reg)[0] != "a":
            self.r.set_logic_flags(val & self.r.m(val, size), size)
        self.r.set_pc(ins.address + ins.size)
        self.bump("move")
        return True

    def _moveq(self, ins):
        ops = ins.operands
        val = ops[0].imm & 0xFFFFFFFF
        val = val - 0x100000000 if val & 0x80000000 else val
        ri = self.reg_index(ops[1].reg)
        if not ri:
            return False
        self.r.wr(ri[1], val & 0xFFFFFFFF)
        self.r.set_logic_flags(val & 0xFFFFFFFF, 4)
        self.r.set_pc(ins.address + ins.size)
        self.bump("moveq")
        return True

    def _alu(self, ins, size, opc):
        ops = ins.operands
        if len(ops) != 2:
            return False
        src = self.get(ops[0], size)
        dst = self.get(ops[1], size)
        if src is None or dst is None:
            return False
        res = (dst + src) if opc == "+" else (dst - src)
        if opc == "+":
            self.r.set_add_flags(dst, src, res, size)
        else:
            self.r.set_sub_flags(dst, src, res, size)
        if ops[1].type != C.M68K_OP_REG or self.reg_index(ops[1].reg)[0] != "a":
            self.put(ops[1], size, res)
        self.r.set_pc(ins.address + ins.size)
        self.bump("alu")
        return True

    def _logic(self, ins, size, opc):
        ops = ins.operands
        src = self.get(ops[0], size)
        dst = self.get(ops[1], size)
        if src is None or dst is None:
            return False
        res = {"&": dst & src, "|": dst | src, "^": dst ^ src}[opc]
        self.put(ops[1], size, res)
        self.r.set_logic_flags(res & self.r.m(res, size), size)
        self.r.set_pc(ins.address + ins.size)
        self.bump("logic")
        return True

    def _cmpi(self, ins, size):
        ops = ins.operands
        if len(ops) != 2:
            return False
        # el inmediato decide el tamano en CMPI (no hay sufijo)
        sz = 1 if (ops[0].imm & ~0xFF) == 0 else (2 if (ops[0].imm & ~0xFFFF) == 0 else 4)
        src = ops[0].imm & self.r.m(0, sz)
        dst = self.get(ops[1], sz)
        if dst is None:
            return False
        self.r.set_sub_flags(dst, src, dst - src, sz)
        self.r.set_pc(ins.address + ins.size)
        self.bump("cmpi")
        return True

    def _cmp(self, ins, size):
        ops = ins.operands
        src = self.get(ops[0], size)
        dst = self.get(ops[1], size)
        if src is None or dst is None:
            return False
        self.r.set_sub_flags(dst, src, dst - src, size)
        self.r.set_pc(ins.address + ins.size)
        self.bump("cmp")
        return True

    def _lea(self, ins):
        ops = ins.operands
        if ops[0].type != C.M68K_OP_MEM:
            return False
        a = self.op_addr(ops[0].mem, 4, self._pcb)
        ri = self.reg_index(ops[1].reg)
        if not ri:
            return False
        self.r.wa(ri[1], a)
        self.r.set_pc(ins.address + ins.size)
        self.bump("lea")
        return True

    def _jmp(self, ins, base):
        """JMP/JSR (Dn) y JMP/JSR (xxx).L"""
        op = ins.operands[0]
        if op.type == C.M68K_OP_REG:
            ri = self.reg_index(op.reg)
            if not ri:
                return False
            target = self.read_reg(ri[0], ri[1]) & 0xFFFFFF
        elif op.type == C.M68K_OP_MEM:
            a = self.op_addr(op.mem, 4, self._pcb)
            target = self.r.rdmem(a, 4) & 0xFFFFFF
        else:
            return False
        if base == "jsr":
            sp = self.r.ra(7)
            self.r.wa(7, (sp - 4) & 0xFFFFFFFF)
            self.r.wrmem(self.r.ra(7), 4, ins.address + ins.size)
        self.r.set_pc(target)
        self.bump(base)
        return True

    def _rts(self, ins):
        sp = self.r.ra(7)
        ret = self.r.rdmem(sp, 4) & 0xFFFFFF
        self.r.wa(7, (sp + 4) & 0xFFFFFFFF)
        self.r.set_pc(ret)
        self.bump("rts")
        return True

    def _rte(self, ins):
        sp = self.r.ra(7)
        pc = self.r.rdmem(sp, 4) & 0xFFFFFF
        sr = self.r.rdmem(sp + 4, 2) & 0xFFFF
        self.r.wa(7, (sp + 6) & 0xFFFFFFFF)
        self.r.set_sr(sr)
        self.r.set_pc(pc)
        self.bump("rte")
        return True

    def _clr(self, ins, size):
        ops = ins.operands
        if not self.put(ops[0], size, 0):
            return False
        self.r.set_nz(0, size)
        self.r.set_pc(ins.address + ins.size)
        self.bump("clr")
        return True

    def _bitop(self, ins, size):
        ops = ins.operands
        if len(ops) != 2:
            return False
        bit = self.get(ops[0], 4)
        val = self.get(ops[1], size)
        if bit is None or val is None:
            return False
        b = bit % (size * 8)
        m = 1 << b
        is_set = (val >> b) & 1
        self._pcb = ins.address + 2   # base para direccionamiento relativo al PC
        base = ins.mnemonic.split(".")[0]
        if base == "bchg":
            new = val ^ m
        elif base == "bclr":
            new = val & ~m
        elif base == "bset":
            new = val | m
        else:
            new = val
        if base != "btst":
            self.put(ops[1], size, new)
        sr = self.r.get_sr()
        self.r.set_sr((sr | 0x04) if not is_set else (sr & ~0x04))
        self.r.set_pc(ins.address + ins.size)
        self.bump(base)
        return True
