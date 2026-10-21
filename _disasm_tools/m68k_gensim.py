#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Emulador/tracer M68000 del Mega Drive sobre Unicorn 2.1.4 para
Yu Yu Hakusho - Makyou Toitsusen.

Problema: el core M68K de Unicorn 2.1.4 NO implementa algunas instrucciones
usadas por el juego, y el proceso se cae al ejecutarlas:

    RTE            0x4E73   -> UC_ERR_EXCEPTION (imprescindible: vuelve de IRQ)
    ORI.W #n,SR    0x007C   -> UC_ERR_EXCEPTION (arranque y handlers)
    ORI.B #n,CCR   0x003C   -> UC_ERR_EXCEPTION

Solucion: capa de rescate. Se ejecuta en trozos; cuando Unicorn lanza la
excepcion se lee el opcode, se emula a mano en Python y se reanuda.

Ademas Unicorn 2.x no expone emu_interrupt(), asi que el VBlank (IRQ nivel 6)
se simula empujando a mano el frame de supervisor y saltando al vector 0x78,
que el handler cierra con RTE (rescatado).
"""
import os
import sys
import ctypes
import struct
from collections import Counter, deque
from unicorn import *
from unicorn.m68k_const import *

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rompath import ruta_rom, camino_asm, dir_sprites, camino_asm, dir_sprites
ROM = ruta_rom()

ROM_BASE, ROM_SIZE = 0x000000, 0x400000
RAM_BASE, RAM_SIZE = 0xFF0000, 0x10000
VDP_DATA, VDP_CTRL, VDP_HV = 0xC00000, 0xC00004, 0xC00008
Z80_BUS = 0xA00000

IRQ6_VECTOR = 0x78          # vector de autovector nivel 6 (VBlank)
AUTOVEC_L6  = 0x78 + 6 * 4  # 0x90

DAMAGE_FN = 0x00019C46
HP_OFF    = 0xB8

CHUNK = 20000                # instrucciones por llamada a emu_start
# Modo rapido: quita el contador de PCs y otros??? diagnostico por
# instruccion. Much mas rapido; se pierde el informe de PCs mas ejecutados.
FAST = os.environ.get("M68K_FAST", "1") != "0"
# Fix de BSET/BCLR/BCHG de Unicorn: correcto pero rompe el flujo de IRQ. Desactivado.
BITOPS_FIX = True


class Z80Bridge:
    """Puente entre el Z80 del Mega Drive y la RAM compartida con el 68k.

    Mapa de direcciones del Z80 en el Mega Drive:
        0x0000-0x1FFF  work RAM del 68k ($FF0000-$FF1FFF), compartida
        0x2000-0x3FFF  espejo de lo anterior
        0x4000-0x60FF  registros de sonido (YM2612/PSG) -> ignorados
        0x6100-0x7EFF  sin usar
        0x7F00-0x7FFF  VDP
        0x8000-0xFFFF  ventana bancada del 68000

    Puertos de E/S: los puertos 0x00-0x1F del Z80 se corresponden con los
    registros $A10000-$A1001F del 68000 (lectura en 0x20-0x3F).
    """

    def __init__(self, owner):
        import z80
        self.owner = owner
        self.m = z80.Z80Machine()
        self.ram = owner.ram
        self.halted = False          # True si el 68k tiene el bus
        self.in_reset = True         # Z80 retenido en reset
        self.insn = 0
        self.outs = 0
        self.rom_src = 0x393FE
        self.rom_len = 0xC00

        self.m.set_read_callback(self._rd)
        self.m.set_write_callback(self._wr)
        self.m.set_input_callback(self._in)
        self.m.set_output_callback(self._out)
        self.m.set_get_int_vector_callback(lambda: 0xFF)

    # ---- callbacks de memoria ----
    def _rd(self, a):
        a &= 0xFFFF
        if a < 0x4000:
            # 0x2000-0x3FFF es espejo de 0x0000-0x1FFF
            return self.ram[a & 0x1FFF]
        return 0xFF

    def _wr(self, a, v):
        a &= 0xFFFF
        if a < 0x4000:
            self.ram[a & 0x1FFF] = v & 0xFF
            if a < 0x1FFF:
                self.ram[(a & 0x1FFF) + 0x2000] = v & 0xFF
        # el resto (registros de sonido, VDP) se ignora: no afecta a la logica

    # ---- puertos ----
    def _out(self, port, val):
        self.outs += 1
        p = port & 0xFF
        if p < 0x20:
            # salida del Z80 -> registro $A100xx del 68k
            self.owner.io_regs[p] = val & 0xFF

    def _in(self, port):
        p = port & 0x1F
        return self.owner.io_regs[p]

    # ---- control desde el 68k ----
    def release_reset(self):
        self.in_reset = False

    def set_busreq(self, on):
        """True = el 68000 tiene el bus (el Z80 queda detenido)."""
        self.halted = on

    def can_run(self):
        return (not self.halted) and (not self.in_reset)

    def run(self, instructions=4000):
        """Ejecuta bloques del Z80 hasta un limite de ticks o hasta que el
        68k vuelve a tomar el bus."""
        if not self.can_run():
            return 0
        # la libreria mide en ticks de reloj (T-states)
        self.m.ticks_to_stop = instructions * 4
        try:
            self.m.run()
        except Exception:
            return 0
        self.insn += 1
        return 1

    def pc(self):
        return self.m.pc


class Gen68k:
    def __init__(self, verbose=True):
        self.verbose = verbose
        self.rom = bytearray(open(ROM, "rb").read())
        if len(self.rom) < ROM_SIZE:
            self.rom += b"\x00" * (ROM_SIZE - len(self.rom))

        self.uc = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)

        # --- RAM compartida con el Z80 ---
        # El 68k copia el driver Z80 a $A00000, que en el Mega Drive es el
        # espacio del Z80 (0x0000) == work RAM $FF0000. Para que ambas CPUs
        # vean la misma memoria se mapea el MISMO buffer host en las dos
        # arquitecturas con mem_map_ptr.
        self.ram = (ctypes.c_ubyte * RAM_SIZE)()
        ctypes.memset(self.ram, 0, RAM_SIZE)

        self.uc.mem_map(ROM_BASE, ROM_SIZE, UC_PROT_ALL)
        self.uc.mem_map_ptr(RAM_BASE, RAM_SIZE, UC_PROT_ALL, self.ram)
        self.uc.mem_write(ROM_BASE, bytes(self.rom))

        # ventana del Z80 vista por el 68k: $A00000-$A0FFFF y $A10000-$A11FFF
        # apuntan al mismo work RAM (offset 0)
        self.uc.mem_map_ptr(0xA00000, 0x10000, UC_PROT_ALL, self.ram)
        self.uc.mem_map_ptr(0xA10000, 0x02000, UC_PROT_ALL, self.ram)

        # resto del mapa del hardware del Mega Drive
        self.uc.mem_map(0xC00000, 0x01000, UC_PROT_ALL)   # VDP
        self.uc.mem_map(0xE00000, 0x10000, UC_PROT_ALL)   # espejo de ROM
        self.uc.mem_write(0xE00000, bytes(self.rom[0x200000:0x210000]))

        # --- VDP ---
        import m68k_vdp
        self.vdp = m68k_vdp.VDP()
        self.io_regs = bytearray(0x20)
        self.z80 = Z80Bridge(self)

        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._vdp_write, begin=0xC00000, end=0xC0000F)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._z80_write, begin=0xA00000, end=0xA0FFFF)
        self.uc.hook_add(UC_HOOK_MEM_READ, self._vdp_read, begin=0xC00000, end=0xC0000F)

        # El arranque testea $A10008 y $A1000C esperando que el driver Z80
        # haya escrito en esos puertos. Si el Z80 no los toca se inyecta un
        # valor plausible en el puerto (no en la RAM compartida, para no
        # corromper las variables del driver).
        for base in (RAM_BASE, 0xA10000):
            self.uc.mem_write(base + 0x08, b"\x01\x00\x00\x00")
            self.uc.mem_write(base + 0x0C, b"\x01\x00")

        # --- espejo de la RAM para el enmascarado a 24 bits --------------------
        # El ROM usa operandos absolutos de 32 bits con el nibble alto a 1
        # (p.ej. MOVE.W $fffff142.l -> en hardware $FFF142) y el vector de
        # reset trae SP=$FFFFFF00 (-> $FFFF00). Todo eso depende del bus de
        # 24 bits, que Unicorn no aplica. En vez de parchear el codigo (que
        # corromperia inmediatos como MOVE.L #$ffffe800), mapeamos un espejo
        # de 256 MB de la RAM y mantenemos la RAM canonica en $FF0000:
        #   - lectura en el espejo  -> refrescamos la pagina desde la RAM
        #   - escritura en el espejo -> se propaga tambien a la RAM
        self.mirror = None
        for base, size in ((0xFF000000, 0x10000000), (0xFFFF0000, 0x10000)):
            try:
                self.uc.mem_map(base, size, UC_PROT_ALL)
                self.mirror = (base, size)
                break
            except Exception:
                continue
        if self.mirror:
            self.log("  espejo 24 bits: 0x%08X +0x%X" % self.mirror)
        self.uc.hook_add(UC_HOOK_MEM_READ, self._mirror_read,
                         begin=self.mirror[0], end=self.mirror[0] + self.mirror[1] - 1)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._mirror_write,
                         begin=self.mirror[0], end=self.mirror[0] + self.mirror[1] - 1)

        # hooks
        self.hits = Counter()
        self.hot = Counter()
        self.hp_writes = []
        self.damage_events = []
        self.rescued = Counter()
        self.errors = []
        self.unmapped = []
        self.last_pc = 0
        self.disp = None
        self.capex = None
        self.z80_cmd = 0
        self.z80_ack = 0
        self.z80_cmds = 0
        self._opcache = {}
        self._bit_bug_pending = False
        self.in_irq = False
        self.irq_pending = False
        self.vdp_writes = 0
        self.vdp_reads = 0
        self.io_reads = 0
        self.io_writes = 0
        self.mirror_reads = 0
        self.mirror_writes = 0
        self.frame = 0
        self.vcount = 0

        self.uc.hook_add(UC_HOOK_CODE, self._code)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._wr, begin=RAM_BASE, end=RAM_BASE + RAM_SIZE)
        self.uc.hook_add(UC_HOOK_MEM_READ, self._io_read, begin=0xA11000, end=0xA11FFF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self._io_write, begin=0xA11000, end=0xA11FFF)
        # accesos a memoria no mapeada: solo diagnosticamos
        self.uc.hook_add(UC_HOOK_MEM_READ_UNMAPPED | UC_HOOK_MEM_WRITE_UNMAPPED,
                         self._unmapped)

        sp = struct.unpack(">I", self.uc.mem_read(0, 4))[0]
        pc = struct.unpack(">I", self.uc.mem_read(4, 4))[0]
        sp &= 0xFFFFFF
        self.uc.reg_write(UC_M68K_REG_SR, 0x2700)
        self.uc.reg_write(UC_M68K_REG_CR_ISP, sp)
        self.uc.reg_write(UC_M68K_REG_CR_USP, 0)
        self.uc.reg_write(UC_M68K_REG_A7, sp)
        self.uc.reg_write(UC_M68K_REG_PC, pc)
        self.log("reset: SP=0x%08X PC=0x%08X (A7=0x%08X)"
                 % (sp, pc, self.uc.reg_read(UC_M68K_REG_A7)))

    def _fix_24bit(self):
        import re
        asm = camino_asm()
        pat_line = re.compile(r"^([0-9A-Fa-f]{6}):\s+((?:[0-9A-Fa-f]{2}\s+)+)(.*)$")
        pat_addr = re.compile(r"\$([0-9A-Fa-f]{7,8})")
        fixed = 0
        if not os.path.exists(asm):
            self.log("  (no se encontro el desensamblado: %s)" % asm)
            return 0
        with open(asm, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = pat_line.match(line.strip())
                if not m:
                    continue
                addr = int(m.group(1), 16)
                byts = bytearray(int(x, 16) for x in m.group(2).split())
                text = m.group(3)
                for am in pat_addr.finditer(text):
                    val = int(am.group(1), 16)
                    if val <= 0xFFFFFF:
                        continue
                    masked = val & 0xFFFFFF
                    needle = struct.pack(">I", val)
                    pos = byts.find(needle)
                    if pos < 0:
                        continue
                    byts[pos:pos + 4] = struct.pack(">I", masked)
                    try:
                        self.uc.mem_write(addr, bytes(byts))
                        fixed += 1
                    except Exception:
                        pass
        self.log("  normalizacion 24 bits: %d operandos corregidos" % fixed)
        return fixed


    def log(self, *a):
        if self.verbose:
            print(*a)
            sys.stdout.flush()

    # ---------------- hooks ----------------
    def _bitops_estaticas(self, uc, addr, size, data, op=None):
        """Intercepta BTST/BCHG/BCLR/BSET con numero de bit estatico.

        ESTADO: la emulacion existe y es correcta (verificada: escribe en
        memoria y pone bien Z), pero NO se activa. Al activarla el juego
        retrocedia: el buzon del Z80 paso de 62 comandos a 0, porque al
        reentrar por emu_stop() se pierde parte del estado de la IRQ.

        Se deja el codigo listo y desactivado con BITOPS_FIX = True hasta
        que se resuelva el estado de las interrupciones.

        POR QUE existia: el core M68K de Unicorn 2.1.4 no hace bien estas
        instrucciones con operando absoluto largo (BSET no escribe, BCLR
        falla al leer) y no lanzan excepcion, asi que el rescate normal no
        interviene.
        """
        if not BITOPS_FIX:
            return False
        if getattr(self, "_bit_bug_pending", False):
            return False
        if op is None:
            op = struct.unpack(">H", uc.mem_read(addr, 2))[0]
        # prefijo 0000 1xxx -> los 4 bits en las posiciones 11..8.
        # OJO: con (op >> 12) da 0 y la comprobacion nunca pasa.
        if ((op >> 8) & 0xF) != 0x8:
            return False
        modo = (op >> 3) & 7
        if modo == 0:
            return False                      # registro: Unicorn lo hace bien

        # El tamano y la forma exacta del operando NO se calculan a mano: esa
        # cuenta fue la que rompio el arranque. Se le pregunta a Capstone,
        # que es la misma fuente que uso para decodificar.
        if self.disp is None:
            import m68k_dispatch
            self.disp = m68k_dispatch.Dispatcher(self.uc)
        if self.capex is None:
            import m68k_capexec
            self.capex = m68k_capexec.CapExec(self.disp)
        cx = self.capex
        try:
            raw = bytes(uc.mem_read(addr, 14))
        except Exception:
            return False
        ins = None
        for cand in cx.md.disasm(raw, addr, count=1):
            ins = cand
            break
        if ins is None:
            return False
        base = ins.mnemonic.split(".")[0]
        if base not in ("bts", "bclr", "bchg", "bset"):
            # BTST no escribe nada: Unicorn lo resuelve bien y su Z es el
            # correcto (Z=1 si el bit es 0). Interceptorlo con la regla de
            # las instrucciones que escriben daba el Z invertido.
            return False
        ops = ins.operands
        if len(ops) != 2:
            return False
        size = cx.size_of(ins.mnemonic) or 1

        # Capstone NO expone el operando de memoria en estas instrucciones
        # (todos sus campos salen a 0), asi que se leen de los bytes crudos.
        # Codificacion real en este juego:
        #     08 F9  <palabra: numero de bit>  <long: direccion>
        #     0x356: 08 f9 | 00 00 | 00 a1 11 00   -> bset.b #0,$a11100.l
        # Codificacion real (verificada en los bytes del ROM):
        #     08 F9 | 00 00 | 00 A1 11 00
        #            ^bit   ^direccion (long, en addr+4)
        # El numero de bit es una PALABRA en addr+2 y la direccion un LONG
        # en addr+4. Leerlos al reves hacia que la escritura no llegara nunca.
        bit = struct.unpack(">H", bytes(uc.mem_read(addr + 2, 2)))[0] % (size * 8)
        ea = struct.unpack(">I", bytes(uc.mem_read(addr + 4, 4)))[0] & 0xFFFFFF

        val = uc.mem_read(ea, size)
        val = int.from_bytes(bytes(val), "big") if isinstance(val, (bytes, bytearray)) else val
        antes = (val >> bit) & 1
        if base == "bchg":
            nuevo = val ^ (1 << bit)
        elif base == "bclr":
            nuevo = val & ~(1 << bit)
        else:
            nuevo = val | (1 << bit)
        uc.mem_write(ea, nuevo.to_bytes(size, "big"))
        # Z: 0 si el bit cambio, 1 si no  (regla de BSET/BCLR/BCHG)
        sr = cx.r.get_sr()
        cx.r.set_sr((sr | 0x04) if antes else (sr & ~0x04))
        cx.r.set_pc(addr + ins.size)
        self.rescued["bitops"] = self.rescued.get("bitops", 0) + 1
        self._bit_bug_pending = True
        try:
            uc.emu_stop()
        except Exception:
            pass
        return True

    def _code(self, uc, addr, size, data):
        self.last_pc = addr
        if self.z80_ack:
            self._z80_tick()
        # un RTE siempre cierra una excepcion: si colgamos una IRQ, la liberamos
        # Un RTE siempre cierra una excepcion: si hay una IRQ en servicio, sale
        try:
            op = self._opcache.get(addr)
            if op is None:
                op = struct.unpack(">H", uc.mem_read(addr, 2))[0]
                self._opcache[addr] = op
            if op == 0x4E73:
                self.in_irq = False
        except Exception:
            pass
        # la intercepcion de bit-ops solo hace falta si el opcode es del
        # prefijo 0000 1xxx; con la cache ya no hace falta leer memoria
        if op is not None and ((op >> 8) & 0xF) == 0x8:
            if self._bitops_estaticas(uc, addr, size, data, op):
                return
        self.hot[addr] += 1
        if addr == DAMAGE_FN:
            d0 = uc.reg_read(UC_M68K_REG_D0) & 0xFFFFFFFF
            a5 = uc.reg_read(UC_M68K_REG_A5)
            hp = a5 + HP_OFF
            try:
                before = struct.unpack(">I", uc.mem_read(hp, 4))[0]
            except Exception:
                before = -1
            self.damage_events.append({"frame": self.frame, "d0": d0,
                                       "a5": a5, "hp": hp, "hp_before": before})
            self.log("  ** DA?O frame=%d  D0=%d  A5=0x%06X  HP(0x%06X)=%d"
                     % (self.frame, d0, a5, hp, before))
        elif addr == 0x1EBBE:
            a2 = uc.reg_read(UC_M68K_REG_A2)
            d3 = uc.reg_read(UC_M68K_REG_D3)
            self.log("  >> MOVE_RD pc=1EBBE A2=0x%06X D3=%d" % (a2, d3 & 0xFFFFFFFF))

    def _wr(self, uc, access, addr, size, value, data):
        off = addr - RAM_BASE
        if off % 0x400 == HP_OFF and 0x0000 <= off < 0x4000:
            self.hp_writes.append((self.frame, addr, value & 0xFFFFFFFF))

    def _mirror_read(self, uc, access, addr, size, value, data):
        """lectura en el espejo: refresca la pagina desde la RAM canonica."""
        canon = addr & 0xFFFFFF
        try:
            apage = addr & ~0xFFF
            cpage = canon & ~0xFFF
            uc.mem_write(apage, bytes(uc.mem_read(cpage, 0x1000)))
            self.mirror_reads += 1
        except Exception:
            pass

    def _mirror_write(self, uc, access, addr, size, value, data):
        """escritura en el espejo: se propaga a la RAM canonica."""
        canon = addr & 0xFFFFFF
        try:
            if size == 1:
                uc.mem_write(canon, bytes([value & 0xFF]))
            elif size == 2:
                uc.mem_write(canon, struct.pack(">H", value & 0xFFFF))
            else:
                uc.mem_write(canon, struct.pack(">I", value & 0xFFFFFFFF))
            self.mirror_writes += 1
        except Exception:
            pass

    def _z80_write(self, uc, access, addr, size, value, data):
        """El 68k escribe en el espacio del Z80 ($A0xxxx).

        En $A04000-$A040FF esta el buzon con el driver de sonido: el 68k
        escribe un comando y luego hace  tst.b (a0) / bmi  esperando a que el
        bit 7 se borre (lo hace el Z80 al procesar el comando). Como no
        emulamos la respuesta real, la simulamos: al escribir el comando,
        programamos el borrado de ese bit unas instrucciones despues.
        """
        a = addr & 0xFFFF
        if 0x4000 <= a <= 0x40FF:
            self.z80_cmd = addr
            self.z80_ack = 300                  # instrucciones de retardo
            self.z80_cmds += 1

    def _z80_tick(self):
        """se llama en cada instruccion para cumplir el ACK del buzon"""
        if self.z80_ack <= 0:
            return
        self.z80_ack -= 1
        if self.z80_ack == 0:
            addr = self.z80_cmd
            try:
                b = self.uc.mem_read(addr, 1)[0]
                if b & 0x80:
                    self.uc.mem_write(addr, bytes([b & 0x7F]))
            except Exception:
                pass

    def _vdp_write(self, uc, access, addr, size, value, data):
        """escritura en el VDP ($C00000 puerto de datos, $C00004 control)"""
        a = addr & 0x1F
        if a < 4:
            self.vdp.poke(size, value)
            self.vdp.inc(size)
        elif a < 8:
            self.vdp.write_ctrl(value)
        elif a < 12:
            self.vdp.hcount = value & 0x3FF
        self.vdp_writes += 1

    def _vdp_read(self, uc, access, addr, size, value, data):
        """lectura del VDP. Los hooks no pueden devolver valores, asi que
        escribimos el valor en memoria y dejamos que la lectura lo tome."""
        a = addr & 0x1F
        try:
            if a < 4:
                v = self.vdp.peek(size)
                uc.mem_write(addr, (struct.pack(">H", v) if size == 2
                                    else bytes([v & 0xFF])))
                self.vdp.inc(size)
                self.vdp_reads += 1
            elif a < 8:
                uc.mem_write(addr, struct.pack(">H", self.vdp.read_status()))
            elif a < 12:
                uc.mem_write(addr, struct.pack(">H", self.vdp.vcount))
        except Exception:
            pass

    def volcar_vdp(self, prefijo):
        """guarda VRAM, CRAM y los registros del VDP"""
        d = dir_sprites()
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, prefijo + "_vram.bin"), "wb").write(bytes(self.vdp.vram))
        open(os.path.join(d, prefijo + "_cram.bin"), "wb").write(bytes(self.vdp.cram))
        info = self.vdp.report()
        lines = ["# volcado del VDP (emulador propio): " + prefijo]
        for k, v in info.items():
            lines.append("%s: %s" % (k, v))
        open(os.path.join(d, prefijo + "_vdp.txt"), "w", encoding="utf-8").write("\n".join(lines))
        self.log("  volcado VDP -> sprites/%s_{vram,cram}.bin" % prefijo)
        for k, v in info.items():
            self.log("     %-14s %s" % (k, v))
        return info

    def _io_read(self, uc, access, addr, size, value, data):
        """Registros $A10000-$A1001F (los escribe el Z80 por sus puertos).

        $A10008 = estado de bus del Z80, $A1000C = modo de memoria.
        Antes de cada lectura volcamos el estado actual a memoria.
        """
        base = addr & 0xFF00
        if base == 0x1000:
            regs = self.io_regs
            uc.mem_write(0xA10000, bytes(regs))
        # $A11100 NO se fuerza en lectura: es un registro real y el juego usa
        # el patron "bset #0 / bne" (espera a leer el bit a 1) seguido de
        # "bclr #0 / beq" (espera a que el bit CAMBIE). Si aqui se reescribe
        # el valor, el BCLR nunca ve el bit distinto y se queda en bucle.
        self.io_reads += 1

    def _io_write(self, uc, access, addr, size, value, data):
        """Control del Z80 desde el 68000.

        $A11100 bit 0 = BUSREQ (1 = el 68k toma el bus, el Z80 se detiene)
                      bit 1 = RESET  (1 = Z80 retenido)
        $A11200       =Solicitud de bus alternativa (bit 8)
        """
        v = value & 0xFFFF
        if addr == 0xA11100:
            self.z80.set_busreq(bool(v & 0x01))
            if v & 0x02:
                self.z80.in_reset = True
            elif v & 0x100:
                self.z80.release_reset()
        elif addr == 0xA11101:
            self.z80.set_busreq(bool(v & 0x01))
            if v & 0x02:
                self.z80.in_reset = True
        elif addr == 0xA11200:
            self.z80.set_busreq(bool(v & 0x0100))
        self.io_writes += 1

    def _unmapped(self, uc, access, addr, size, value, data):
        self.unmapped.append((getattr(self, "last_pc", 0), addr, size, value))

    # ---------------- rescate ----------------
    def _rescue(self):
        """Emula las instrucciones que Unicorn no soporta. True siOk."""
        if self.disp is None:
            import m68k_dispatch
            self.disp = m68k_dispatch.Dispatcher(self.uc)
        uc = self.uc
        pc = uc.reg_read(UC_M68K_REG_PC)
        try:
            op = struct.unpack(">H", uc.mem_read(pc, 2))[0]
        except Exception:
            return False
        try:
            if self.disp.handle(op, pc):
                self.rescued["disp"] += 1
                return True
        except Exception as e:
            self.log("  rescate por mascara fallo en pc=0x%06X op=0x%04X: %r" % (pc, op, e))
        # ultimo recurso: Capstone como fuente de verdad
        if self.capex is None:
            import m68k_capexec
            self.capex = m68k_capexec.CapExec(self.disp)
        try:
            if self.capex.try_exec(pc):
                self.rescued["capstone"] += 1
                return True
        except Exception as e:
            self.log("  capexec fallo en pc=0x%06X: %r" % (pc, e))
        # respaldo: implementaciones directas minimas
        if op == 0x4E73:                      # RTE
            self.in_irq = False
            sp = uc.reg_read(UC_M68K_REG_A7)
            try:
                npc = struct.unpack(">I", uc.mem_read(sp, 4))[0]
                nsr = struct.unpack(">H", uc.mem_read(sp + 4, 2))[0]
            except Exception:
                return False
            uc.reg_write(UC_M68K_REG_A7, sp + 6)
            uc.reg_write(UC_M68K_REG_SR, nsr)
            uc.reg_write(UC_M68K_REG_PC, npc)
            self.rescued["RTE"] += 1
            return True

        if op == 0x007C:                      # ORI.W #imm,SR
            imm = struct.unpack(">H", uc.mem_read(pc + 2, 2))[0]
            sr = uc.reg_read(UC_M68K_REG_SR)
            uc.reg_write(UC_M68K_REG_SR, sr | imm)
            uc.reg_write(UC_M68K_REG_PC, pc + 4)
            self.rescued["ORI.W,SR"] += 1
            return True

        if op == 0x003C:                      # ORI.B #imm,CCR
            imm = uc.mem_read(pc + 2)[0]
            sr = uc.reg_read(UC_M68K_REG_SR)
            uc.reg_write(UC_M68K_REG_SR, (sr & 0xFF00) | ((sr | imm) & 0xFF))
            uc.reg_write(UC_M68K_REG_PC, pc + 3)
            self.rescued["ORI.B,CCR"] += 1
            return True

        # DBcc / DBRA : 0101 00cc 1 001 rrr
        if (op & 0xF0FC) == 0x50C8:           # DBcc / DBRA
            cc = (op >> 8) & 0xF
            reg = op & 7
            d16 = struct.unpack(">h", bytes(uc.mem_read(pc + 2, 2)))[0]
            if self._cond(cc):
                uc.reg_write(UC_M68K_REG_PC, pc + 4)
            else:
                dn = self._dreg(reg) & 0xFFFF
                dn = (dn - 1) & 0xFFFF
                self._set_dreg(reg, dn)
                if dn != 0xFFFF:
                    uc.reg_write(UC_M68K_REG_PC, (pc + 2 + d16) & 0xFFFFFF)
                else:
                    uc.reg_write(UC_M68K_REG_PC, pc + 4)
            self.rescued["DBcc"] += 1
            return True

        return False

    def _cond(self, cc):
        """evalua una condicion Bcc desde SR. Bit 0=C 1=V 2=Z 3=N"""
        sr = self.uc.reg_read(UC_M68K_REG_SR)
        c = sr & 1
        v = (sr >> 1) & 1
        z = (sr >> 2) & 1
        n = (sr >> 3) & 1
        return [1, 0, (not c) and (not z), c or z, not c, c, not z, z,
                not v, v, not n, n, n == v, n != v, (not z) and (n == v),
                z or (n != v)][cc]

    def _dreg(self, i):
        return self.uc.reg_read([UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2,
                                 UC_M68K_REG_D3, UC_M68K_REG_D4, UC_M68K_REG_D5,
                                 UC_M68K_REG_D6, UC_M68K_REG_D7][i])

    def _set_dreg(self, i, v):
        self.uc.reg_write([UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2,
                           UC_M68K_REG_D3, UC_M68K_REG_D4, UC_M68K_REG_D5,
                           UC_M68K_REG_D6, UC_M68K_REG_D7][i], v & 0xFFFFFFFF)

    # ---------------- IRQ VBlank ----------------
    def fire_vblank(self):
        """Emula la interrupcion de nivel 6 (VBlank) del VDP.

        IMPORTANTE: si ya hay una IRQ en servicio no se inyecta otra. En
        hardware el nivel 6 queda pendiente y se atiende recien despues del
        RTE del handler en curso. Inyectarla en medio corrompe el frame de
        retorno de la pila y el handler se reentra en si mismo eternamente.
        """
        if getattr(self, "in_irq", False):
            self.irq_pending = True
            return False
        uc = self.uc
        pc = uc.reg_read(UC_M68K_REG_PC)
        sr = uc.reg_read(UC_M68K_REG_SR)
        sp = uc.reg_read(UC_M68K_REG_A7)
        # el juego usa A7 como SSP en modo supervisor
        frame_pc = struct.pack(">I", pc)
        frame_sr = struct.pack(">H", sr)
        new_sp = (sp - 6) & 0xFFFFFFFF
        try:
            uc.mem_write(new_sp, frame_pc + frame_sr)
        except Exception:
            return False
        uc.reg_write(UC_M68K_REG_A7, new_sp)
        handler = struct.unpack(">I", uc.mem_read(IRQ6_VECTOR, 4))[0]
        # activa nivel 6 manteniendo supervisor
        uc.reg_write(UC_M68K_REG_SR, (sr | 0x2000) & 0xFFFF)
        uc.reg_write(UC_M68K_REG_PC, handler)
        self.in_irq = True
        self.frame += 1
        self.vcount = (self.vcount + 1) % 262
        if self.vdp is not None:
            self.vdp.tick_frame()
        return True

    # ---------------- motor ----------------
    def run(self, frames=60, irqs_per_frame=1, until_pc=None, max_chunk_total=None):
        """Ejecuta hasta 'frames' VBlanks, inyectando 'irqs_per_frame' IRQ6 por
        cada bloque de instrucciones equivalente a un frame."""
        total_target = self.frame + frames
        budget = max_chunk_total or (frames * irqs_per_frame * CHUNK * 2)
        quota = CHUNK * irqs_per_frame
        pending = 0
        used = 0
        while self.frame < total_target and used < budget:
            pc = self.uc.reg_read(UC_M68K_REG_PC)
            if pc == 0:
                self.log("  PC=0 -> fin de ejecucion")
                return
            try:
                self.uc.emu_start(pc, 0x7FFFFFFF, count=CHUNK)
                self._bit_bug_pending = False
                used += CHUNK
                pending += CHUNK
            except UcError as e:
                if not self._rescue():
                    bad = self.last_pc
                    self.errors.append((bad, self._op(bad), str(e)))
                    a = [self.uc.reg_read(r) for r in
                         (UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A2, UC_M68K_REG_A3,
                          UC_M68K_REG_A4, UC_M68K_REG_A5, UC_M68K_REG_A6, UC_M68K_REG_A7)]
                    self.log("  ERROR no rescatable pc=0x%06X op=0x%04X %s" % (bad, self._op(bad), e))
                    self.log("     A0-A7: " + " ".join("0x%08X" % x for x in a))
                    dd = [self.uc.reg_read(r) for r in
                          (UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2, UC_M68K_REG_D3,
                           UC_M68K_REG_D4, UC_M68K_REG_D5, UC_M68K_REG_D6, UC_M68K_REG_D7)]
                    self.log("     D0-D7: " + " ".join("0x%08X" % x for x in dd))
                    self.log("     op bytes: " + bytes(self.uc.mem_read(bad, 6)).hex(" "))
                    if self.unmapped:
                        lpc, la, lsz, _ = self.unmapped[-1]
                        self.log("     ultimo acceso no mapeado: pc=0x%06X addr=0x%08X size=%d"
                                 % (lpc, la, lsz))
                    return
                used += 1
                pending += 1
            # el Z80 corre mientras el 68000 no le tenga el bus
            if self.z80 is not None:
                for _ in range(8):
                    if not self.z80.run(3000):
                        break
            if until_pc is not None and self.uc.reg_read(UC_M68K_REG_PC) == until_pc:
                self.log("  alcanzado PC objetivo 0x%06X" % until_pc)
                return
            if self.irq_pending and not self.in_irq:
                self.irq_pending = False
                self.fire_vblank()
            while pending >= quota and self.frame < total_target:
                pending -= quota
                if not self.fire_vblank():
                    break            # hay una IRQ en servicio: espera al RTE
        return

    def _op(self, pc):
        try:
            return struct.unpack(">H", self.uc.mem_read(pc, 2))[0]
        except Exception:
            return 0xFFFF

    # ---------------- informes ----------------
    def report(self, top=15):
        self.log("=" * 66)
        self.log("frames VBlank : %d" % self.frame)
        self.log("DA?OS         : %d" % len(self.damage_events))
        self.log("rescates      : %s" % dict(self.rescued))
        if self.disp is not None:
            self.log("por instruccion: %s" % self.disp.stats)
        if self.capex is not None:
            self.log("capstone      : %s" % self.capex.stats)
        if self.z80 is not None:
            self.log("buzon Z80     : %d comandos, ACK pendiente=%d" % (self.z80_cmds, self.z80_ack))
        self.log("Z80           : pc=0x%04X reset=%s busreq=%s bloques=%d outs=%d"
                     % (self.z80.pc(), self.z80.in_reset, self.z80.halted,
                        self.z80.insn, self.z80.outs))
        self.log("espejo 24bit  : %d lecturas / %d escrituras"
                 % (self.mirror_reads, self.mirror_writes))
        self.log("errores       : %d" % len(self.errors))
        if self.unmapped:
            self.log("accesos NO mapeados (%d):" % len(self.unmapped))
            for pc, a, sz, v in self.unmapped[:8]:
                self.log("   desde pc=0x%06X  addr=0x%08X  size=%d" % (pc, a, sz))
        for pc, op, e in self.errors[:5]:
            self.log("   pc=0x%06X op=0x%04X %s" % (pc, op, e))
        self.log("PCs mas hot:")
        for pc, n in self.hot.most_common(top):
            self.log("   0x%06X  x%-8d op=0x%04X" % (pc, n, self._op(pc)))
        if self.damage_events:
            self.log("DA?OS:")
            for d in self.damage_events[:20]:
                self.log("   frame=%-5d D0=%-4d A5=0x%06X HP=%d"
                         % (d["frame"], d["d0"], d["a5"], d["hp_before"]))
        if self.hp_writes:
            self.log("escrituras HP (%d), ultimas:" % len(self.hp_writes))
            for f, a, v in self.hp_writes[-15:]:
                self.log("   frame=%-5d 0x%06X = %d" % (f, a, v))


if __name__ == "__main__":
    f = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    e = Gen68k(verbose=True)
    e.run(frames=f, irqs_per_frame=1)
    e.report()



