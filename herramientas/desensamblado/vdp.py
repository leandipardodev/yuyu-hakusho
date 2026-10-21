"""
VDP minimo del Mega Drive para el emulador 68000.

Implementa lo justo para que el codigo del juego avance y para poder volcar
VRAM/CRAM en cualquier instante:
  - 64 KB de VRAM, 128 bytes de CRAM (64 colores) y 80 de VSRAM
  - puerto de control $C00004 (selección de registro + valor)
  - puerto de datos $C00000/1 con autoincremento
  - registro de estado (VBlank/HBlank/frame par) y contador HV $C00008

El juego usa mucho el VDP: el arranque incluso espera el flag de blanking al
valorar $C00004, asi que sin esto se queda colgado.
"""


class VDP:
    DATA = 0xC00000
    CTRL = 0xC00004
    HV   = 0xC00008

    def __init__(self):
        self.vram = bytearray(0x10000)
        self.cram = bytearray(0x80)
        self.vsram = bytearray(0x50)
        self.reg = [0] * 16
        self.addr = 0            # direccion actual del puerto de datos
        self.code = 0            # comando pendiente (numero de registro)
        self.first = False       # True esperando el valor del registro
        self.in_vblank = True
        self.frame = 0
        self.vcount = 0
        self.hcount = 0
        self.overflow = 0        # escrituras que estaboraron en la linea de sprites

    # ------------------------------------------------------------------
    def addr_mask(self):
        lim = self.reg[11] & 3
        if lim == 0:
            return 0x3FFF
        if lim == 1:
            return 0x7FFF
        if lim == 2:
            return 0xFFFF
        return 0xFFFF

    def recompute_addr(self):
        cd = self.reg[1] & 3
        mask = self.addr_mask()
        hi = (self.reg[2] & (mask >> 14)) << 16 if mask > 0x3FFF else 0
        self.addr = (hi | (self.reg[1] & 0x3FFF) | (cd << 14)) & 0x1FFFFF

    def inc(self, size):
        """autoincremento: +2 por acceso de 8 bits, +4 por acceso de 16/32"""
        step = 2 if size == 1 else 4
        mask = self.addr_mask()
        self.addr = (self.addr + step) & mask

    # ------------------------------------------------------------------
    def bank(self):
        """devuelve (memoria, limite) segun los bits CD del registro 1"""
        cd = self.reg[1] & 3
        if cd == 0:
            return self.vram, 0x10000
        if cd == 1:
            return self.cram, 0x80
        if cd == 3:
            return self.vsram, 0x50
        return self.vram, 0x10000

    def peek(self, size):
        mem, lim = self.bank()
        a = self.addr
        if size == 1:
            return mem[a % lim] if a < lim else 0
        if a + 1 >= lim:
            return 0
        return (mem[a] << 8) | mem[a + 1]

    def poke(self, size, value):
        mem, lim = self.bank()
        a = self.addr
        v = value & 0xFFFF
        if size == 1:
            if a < lim:
                mem[a] = v & 0xFF
        else:
            if a + 1 < lim:
                mem[a] = (v >> 8) & 0xFF
                mem[a + 1] = v & 0xFF

    # ------------------------------------------------------------------
    def write_ctrl(self, value):
        if not self.first:
            self.code = value & 0x1F
            self.first = True
        else:
            r = self.code & 0x0F
            self.reg[r] = value & 0xFFFF
            self.first = False
            self.recompute_addr()

    def read_status(self):
        """registro de estado del VDP (lectura de $C00004)"""
        s = 0
        if self.in_vblank:
            s |= 0x0008
        return 0x3400 | (s & 0x0F)

    def tick_frame(self):
        self.frame += 1
        self.vcount = 0

    # --- info util para volcar sprites -------------------------------
    def char_base(self):
        return (self.reg[4] & 0x07) << 16

    def screen_base(self):
        return (self.reg[5] & 0x3F) << 11

    def sprite_base(self):
        return 0x3FC00 if (self.reg[5] & 0x80) else 0x3F800

    def sprites_h(self):
        return (self.reg[11] & 0x03) * 2

    def report(self):
        return {
            "registros": ["$%04X" % r for r in self.reg],
            "dirCaracteres": "$%05X" % self.char_base(),
            "dirPantalla": "$%05X" % self.screen_base(),
            "tablaSprites": "$%05X" % self.sprite_base(),
            "spritesH": self.sprites_h(),
            "frame": self.frame,
        }
