#!/usr/bin/env python3
"""
hacer_dive39.py - genera la FLAMADA de builds del dive (descenso veloz)
SIEMPRE desde la BASE LIMPIA. Cada build se auto-identifica escribiendo
su ID en $FFA0F0 y una marca $10 en $FFA0F1 cuando dispara (visibles en
la sonda por el watcher de la pagina FFA000-FFA0FF).

  44_DIVE_A_FSM_A0.bin    id $01 - FSM doble-abajo + bloque $A0 inline
                                    + cobro de mana (baseline, eq. 40 v3)
  45_DIVE_B_AUTODIVE.bin  id $02 - UN SOLO toque de abajo en el aire
                                    dispara el bloque $A0 (sin FSM)
  46_DIVE_C_VELONLY.bin   id $03 - mientras este abajo en el aire fuerza
                                    $14 := $48000 (vel Y abajo) cada frame,
                                    sin tocar $5F (test de fisica pura)
  47_DIVE_D_NOMANA.bin    id $04 - FSM doble-abajo + bloque $A0 SIN cobro
                                    (test: si $19C46 fuera el problema)
  48_DIVE_E_NOFIRE.bin    id $05 - SOLO la FSM (estados 1/2), sin disparo

El hook pisa 6 bytes en $0155E8 (move.b $76(a5),d0 + cmpi.b #$ff,d0 del
APLICADOR del mando falso) con jmp al stub en $1A06AE (hueco de ceros
$1A06AE-$1A0826 en la base, 377 bytes).

Salida del stub (el a5 del hook NO es FF8400; probado con sentinela):
  push d1,d2,a5 ; lea $FF8400,a5 ; <FSM/disparo con a5=P1> ; pop ; clr.w d0 ;
  move.b $76(a5),d0 ; jmp $0155F4

Header/checksum: no se toca; se RECALCULA al final (el juego lo verifica
al bootear).

Referencias: docs/05-PARCHES/PARCHES.md
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


def emit_stub(bid, tap, fire, mana):
    """bid: byte de identidad en $FFA0F0 (1..5).
    tap: 'doble' (FSM 2 toques) | 'solo' (1 toque = dispara)
    fire: 'a0' (bloque $A0 completo) | 'vel' (solo velocidad) | 'nada'
    mana: True = cobra 4 via $19C46"""
    reset()
    d('13 fc 00 %02x 00 ff a0 f0' % bid)   # ROM identidad: $FFA0F0 := bid
    d('13 fc 00 00 00 ff a0 f1')           # marca de disparo: apagarla
    d('10 2d 00 76')            # move.b $76(a5), d0 (rejuega la cabeza)
    d('0c 00 00 ff')            # cmpi.b #$ff, d0
    b(0x66, 'FSM')              # bne FSM
    d('4ef9000155f0')           # $76==ff: el base sigue tal cual
    # El a5 del hook NO es FF8400 (probado con sentinela 43): la FSM queda
    # ANCLADA al struct de P1 via swap temporal de a5 (push del a5 del hook,
    # lea $FF8400,a5, todo el bloque a offsets a5-relativos, pop antes de
    # salir porque el cuerpo en $0155F4 espera el a5 original).
    E('FSM')
    d('48 e7 60 04')            # push d1,d2,a5 (predecrem: d1=bit14 d2=bit13 a5=bit2)
    d('4b f9 00 ff 84 00')      # lea $FF8400,a5 ($4b=a5; $49=a4, $4d=a6)
    d('12 2d 00 5f')            # move.b $5f(a5), d1   (= $FF845F, estado aire)
    d('0c 01 00 0e'); b(0x67,'RUN')   # cae    -> RUN
    d('0c 01 00 0d'); b(0x67,'RUN')   # sube   -> RUN
    d('0c 01 00 08'); b(0x67,'RUN')   # apex   -> RUN
    d('0c 01 00 07'); b(0x67,'RUN')   # diagonal -> RUN
    d('42 2d 01 b0'); b(0x60,'SALIDA')# fuera del aire: clr $1B0 y fuera
    E('RUN')
    if tap == 'doble':
        d('14 2d 01 b0')            # move.b $1b0(a5), d2  (estado FSM)
        d('08 2d 00 01 00 71')      # btst.b #1, $71(a5)  (bit1 = abajo)
        b(0x66, 'PRES')
        d('0c 02 00 01'); b(0x66,'RST')   # sin abajo: si d2 != 1 -> reset
        d('1b 7c 00 02 01 b0'); b(0x60,'SALIDA')  # soltar el 1er abajo
        E('PRES')
        d('0c 02 00 02'); b(0x67,'FIRE')  # abajo + estado 2 -> FIRE
        d('1b 7c 00 01 01 b0'); b(0x60,'SALIDA')  # 1er abajo: estado 1
        E('RST')
        d('42 2d 01 b0'); b(0x60,'SALIDA')
    else:   # 'solo'
        d('14 2d 01 b0')            # move.b $1b0(a5), d2 (flag one-shot)
        d('08 2d 00 01 00 71')      # btst.b #1, $71(a5) (abajo?)
        b(0x67, 'SALIDA')           # sin abajo: nada
        d('0c 02 00 01'); b(0x67,'SALIDA')  # ya disparo este salto: nada
        E('RST')                    # sin manac: el flag queda 0 (reintenta)
        d('42 2d 01 b0'); b(0x60,'SALIDA')
    E('FIRE')
    if fire == 'nada':
        # solo FSM: el disparo no hace nada; reset para volver a probar
        d('1b 7c 00 00 01 b0'); b(0x60,'SALIDA')
    else:
        d('13 fc 00 10 00 ff a0 f1')      # marca DISPARO: $FFA0F1 := $10
        if mana:
            d('30 3c 00 04')              # move.w #4, d0
            A('4eb9', 0x019C46)           # jsr $19C46 (cobra 4 de mana $B8(a5))
            d('0c 00 00 00'); b(0x67,'RST')   # sin mana: reset y fuera
        if fire == 'a0':
            # clon del bloque $A0 del armador $192C8 (a5 = P1)
            d('2b 7c 00 00 00 00 00 10')      # move.l #0, $10(a5)
            d('2b 7c 00 04 80 00 00 14')      # move.l #$48000, $14(a5) vel DOWN
            d('1b 7c 00 a0 00 5f')            # move.b #$a0, $5f(a5)
            d('1b 7c 00 00 00 4c')            # move.b #0, $4c(a5)
            d('1b 7c 00 2f 00 5d')            # move.b #$2f, $5d(a5)
            d('42 2d 00 6b')                  # clr.b $6b(a5)
            d('1b 7c 00 00 00 6c')            # move.b #0, $6c(a5)
        else:   # 'vel'
            d('2b 7c 00 04 80 00 00 14')      # move.l #$48000, $14(a5) vel DOWN
        d('1b 7c 00 %02x 01 b0' % (1 if tap=='solo' else 0))
        b(0x60,'SALIDA')
    E('SALIDA')
    d('4c df 20 06')            # pop d1,d2 y A5 (restaura el a5 del hook)
    # los bytes altos de d0 vienen sucios: el cuerpo del base en $0155F4
    # hace movea.l d0,a2 y lee la tabla en -$880(a2); sin limpiar d0, a2 es
    # basura y el aplicador pisa $71-$74/$c0-$c2 corruptos. Limpiar SIEMPRE.
    d('42 40')                  # clr.w d0
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
    # el juego VERIFICA el checksum Genesis al bootear: recalculo sobre el
    # contenido parcheado y lo escribo en $018E.
    s = 0
    for o in range(0x200, len(rom)-1, 2):
        s += (rom[o] << 8) | rom[o+1]
    rom[0x18E:0x190] = struct.pack('>H', s & 0xffff)
    verif = struct.unpack('>H', bytes(rom[0x18e:0x190]))[0]
    assert verif == (s & 0xffff)
    ruta = DIR_SAL + '\\' + nombre
    io.open(ruta, 'wb').write(bytes(rom))
    print('%s -> %d bytes  checksum $%04X  sha256 %s' % (nombre, len(rom), s & 0xffff,
          hashlib.sha256(bytes(rom)).hexdigest().upper()))


# chequeo de sanidad del checksum contra la base (solo INFORMA, no escribe)
rom_base = io.open(RUTA_BASE,'rb').read()
alm = struct.unpack('>H', rom_base[0x18e:0x190])[0]
s = 0
for o in range(0x200, len(rom_base)-1, 2):
    s += (rom_base[o] << 8) | rom_base[o+1]
print('base: checksum almacenado $%04X, calculado $%04X (%s)' % (alm, s & 0xffff,
      'OK, se recalcula tras parchear' if alm == (s & 0xffff) else 'NO CUADRA'))

BUILDS = [
    # (archivo,                      bid, tap,   fire, mana)
    ('44_DIVE_A_FSM_A0.bin',         0x01, 'doble', 'a0', True),
    ('45_DIVE_B_AUTODIVE.bin',       0x02, 'solo',  'a0', True),
    ('46_DIVE_C_VELONLY.bin',        0x03, 'solo',  'vel', False),
    ('47_DIVE_D_NOMANA.bin',         0x04, 'doble', 'a0', False),
    ('48_DIVE_E_NOFIRE.bin',         0x05, 'doble', 'nada', False),
]

for nombre, bid, tap, fire, mana in BUILDS:
    emit_stub(bid, tap, fire, mana)
    cod, total = resolver(prog)
    print('-- %s: stub %06X-%06X (%d bytes, hueco $%04X)' %
          (nombre, STUB, STUB+len(cod)-1, total, HASTA-STUB))
    assert STUB + len(cod) <= HASTA, 'no entra en el hueco'
    armar(nombre, cod)
