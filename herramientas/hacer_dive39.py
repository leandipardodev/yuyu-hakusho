#!/usr/bin/env python3
"""
hacer_dive39.py - Genera los ROMs del dive (descenso veloz) desde la BASE LIMPIA:

  40_china_DIVE_A0INLINE_v2.bin   - stub completo (FSM + dive inline $A0 + cobro mana)
  41_china_DIVE_DIAG_NOFIRE.bin   - FSM completa pero el disparo DESHABILITADO
  42_china_DIVE_DIAG_SHIM.bin     - hook + stub de PASO PURO (replay + jmp base)

El hook pisa 6 bytes en $0155E8 (move.b $76(a5),d0 + cmpi.b #$ff,d0 del
APLICADOR del mando falso) con jmp al stub en $1A06AE (hueco de ceros
$1A06AE-$1A0826 en la base, 377 bytes).

Stub:
  move.b $76(a5),d0 ; cmpi.b #$ff,d0
  $76==ff  -> jmp $0155F0   (el base sigue tal cual, d0/flags intactos)
  $76!=ff  -> FSM del doble-abajo en el aire ($5F in {0E,0D,08,07}) en $1B0
              (byte libre); disparo = clon inline del bloque $A0 del armador
              $192C8 con cobro de mana via jsr $19C46.
  salida: pop d1/d2, rejuega move.b $76,d0 y salta a $0155F4 (bypass del
  beq $0155F0: aqui ya se sabe que $76 != ff).

Header/checksum: NO se tocan.

Referencias: docs/05-PARCHES/PARCHES.md (entrada ROM 39/40).
"""
import io, sys, struct, hashlib

RUTA_BASE = r'C:\proyectos\yuyu-hakusho\rom\base\yuyu_makyou_base.bin'
DIR_SAL   = r'C:\proyectos\yuyu-hakusho\rom\cambios'
STUB  = 0x1A06AE
HASTA = 0x1A0826          # fin del hueco de ceros (exclusivo)
HOOK  = 0x0155E8

prog = []
def reset(): del prog[:]
def d(h): prog.append(('d', bytes.fromhex(h)))
def b(op, eti): prog.append(('b', op, eti))
def A(ops, tgt): prog.append(('A', bytes.fromhex(ops), tgt))
def E(name): prog.append(('E', name))


def emit_stub(variant):
    """variant: 'full' | 'nofire' | 'shim'"""
    reset()
    d('10 2d 00 76')            # move.b $76(a5), d0
    d('0c 00 00 ff')            # cmpi.b #$ff, d0
    if variant == 'shim':
        d('4ef9000155f0')       # jmp $0155F0 (sin FSM: paso puro)
        return
    b(0x66, 'FSM')              # bne FSM (hay comando armado pendiente)
    d('4ef9000155f0')           # jmp $0155F0  (sin comando: el base sigue)
    E('FSM')
    d('48e76000')               # push d1,d2
    d('12 2d 00 5f')            # move.b $5f(a5), d1
    d('0c 01 00 0e'); b(0x67,'RUN')   # $5F==$0E (cae)   -> RUN
    d('0c 01 00 0d'); b(0x67,'RUN')   # $5F==$0D (sube)  -> RUN
    d('0c 01 00 08'); b(0x67,'RUN')   # $5F==$08 (apex)  -> RUN
    d('0c 01 00 07'); b(0x67,'RUN')   # $5F==$07 (diagonal) -> RUN
    d('42 2d 01 b0'); b(0x60,'SALIDA')# fuera del aire: clr $1B0
    E('RUN')
    d('14 2d 01 b0')            # move.b $1b0(a5), d2
    d('08 2d 00 01 00 71')      # btst.b #1, $71(a5)  (bit1 = abajo)
    b(0x66, 'PRES')
    d('0c 02 00 01'); b(0x66,'RST')   # sin abajo: si d2 != 1 -> reset
    d('1b 7c 00 02 01 b0'); b(0x60,'SALIDA')  # soltar el 1er abajo: armado
    E('PRES')
    d('0c 02 00 02'); b(0x67,'FIRE')  # abajo + $1B0==2 -> FIRE
    d('1b 7c 00 01 01 b0'); b(0x60,'SALIDA')  # 1er abajo: estado 1
    E('FIRE')
    if variant == 'nofire':
        d('1b 7c 00 00 01 b0'); b(0x60,'SALIDA')  # dispara NADA: $1B0=0
        E('RST')
        d('42 2d 01 b0')
    else:
        d('30 3c 00 04')            # move.w #4, d0
        A('4eb9', 0x019C46)         # jsr $19C46 (cobra 4 de mana)
        d('0c 00 00 00'); b(0x67,'RST')   # sin mana: reset y fuera
        d('2b 7c 00 00 00 00 00 10')      # move.l #0, $10(a5)
        d('2b 7c 00 04 80 00 00 14')      # move.l #$48000, $14(a5) = vel DOWN
        d('1b 7c 00 a0 00 5f')            # move.b #$a0, $5f(a5)
        d('1b 7c 00 00 00 4c')            # move.b #0, $4c(a5)
        d('1b 7c 00 2f 00 5d')            # move.b #$2f, $5d(a5)
        d('42 2d 00 6b')                  # clr.b $6b(a5)
        d('1b 7c 00 00 00 6c')            # move.b #0, $6c(a5)
        d('1b 7c 00 00 01 b0')            # move.b #0, $1b0 (consumido)
        b(0x60,'SALIDA')
        E('RST')
        d('42 2d 01 b0')
    E('SALIDA')
    d('4c df 00 06')            # pop d1,d2
    d('10 2d 00 76')            # move.b $76(a5), d0 (rejuega)
    d('4ef9000155f4')           # jmp $0155F4 (bypass del beq $0155F0)


def resolver(cod_prog):
    def sz(op):
        if op[0]=='d': return len(op[1])
        if op[0]=='b': return 2
        if op[0]=='A': return 6
        return 0
    pos = STUB
    addr = []
    etiq_pos = {}
    for op in cod_prog:
        if op[0]=='E':
            etiq_pos[op[1]] = pos; addr.append(pos); continue
        addr.append(pos); pos += sz(op)
    total = pos - STUB
    cod = bytearray()
    for i, op in enumerate(cod_prog):
        aqui = addr[i]
        if op[0]=='d': cod += op[1]
        elif op[0]=='b':
            disp = etiq_pos[op[2]] - (aqui+2)
            if not -128 <= disp <= 127:
                sys.exit('rama corta fuera de margen: %s desde %06X (%+d)' % (op[2], aqui, disp))
            cod += bytes([op[1], disp & 0xff])
        elif op[0]=='A':
            cod += op[1] + struct.pack('>I', op[2])
    return bytes(cod), total


def armar(nombre, cod):
    rom = bytearray(io.open(RUTA_BASE,'rb').read())
    hook = bytes([0x4e, 0xf9]) + struct.pack('>I', STUB)  # jmp $1A06AE (6 bytes)
    assert len(hook) == 6
    rom[HOOK:HOOK+6] = hook
    rom[STUB:STUB+len(cod)] = cod
    ruta = DIR_SAL + '\\' + nombre
    io.open(ruta, 'wb').write(bytes(rom))
    print('%s -> %d bytes  sha256 %s' % (nombre, len(rom), hashlib.sha256(bytes(rom)).hexdigest().upper()))


# chequeo de sanidad del checksum contra la base (solo INFORMA, no escribe)
rom_base = io.open(RUTA_BASE,'rb').read()
alm = struct.unpack('>H', rom_base[0x18e:0x190])[0]
s = 0
for o in range(0x200, len(rom_base)-1, 2):
    s += (rom_base[o] << 8) | rom_base[o+1]
print('base: checksum almacenado $%04X, calculado $%04X (no lo tocamos)' % (alm, s & 0xffff))

for nombre, variante in [('40_china_DIVE_A0INLINE_v2.bin', 'full'),
                         ('41_china_DIVE_DIAG_NOFIRE.bin', 'nofire'),
                         ('42_china_DIVE_DIAG_SHIM.bin',   'shim')]:
    emit_stub(variante)
    cod, total = resolver(prog)
    print('-- %s: stub %06X-%06X (%d bytes, hueco $%04X)' %
          (nombre, STUB, STUB+len(cod)-1, total, HASTA-STUB))
    assert STUB + len(cod) <= HASTA, 'no entra en el hueco'
    if variante == 'shim':
        # el shim no tiene 'SALIDA': resolver() ya devolvera el stream completo
        pass
    armar(nombre, cod)

