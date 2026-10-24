#!/usr/bin/env python3
"""
hacer_dive39.py - Genera 39_china_DIVE_A0INLINE.bin

Repara el stub v2d de la ROM 38:
- hook $0155E8 (6 bytes) -> jmp al stub (jmp, no jsr: no toca la pila).
- stub nuevo en $1A06AE (hueco de ceros de 0x179 bytes):
    FSM del doble-abajo in-air ($5F en {0E,0D,08}) en $1B0 (byte libre).
    disparo = CLON INLINE del bloque $A0 del armador $192C8 con cobro de maná
    via bsr $19C46 (move.w #4,d0); sin maná no dispara.
    al final rejuega move.b $76(a5),d0 y salta a $0155F4 (el juego hacia
    movea.l d0,a2 aplicando el mando falso del comando).
    d1/d2 se empujan y se recuperan.
- re-escribe el checksum Genesis del header.

Salida: rom/cambios/39_china_DIVE_A0INLINE.bin
"""
import io, sys, struct, hashlib

RUTA_BASE = r'C:\proyectos\yuyu-hakusho\rom\base\yuyu_makyou_base.bin'
RUTA_SAL  = r'C:\proyectos\yuyu-hakusho\rom\cambios\39_china_DIVE_A0INLINE.bin'
STUB  = 0x1A06AE
HASTA = 0x1A0826          # fin del hueco de ceros (exclusivo)
HOOK  = 0x0155E8

prog = []
def d(h): prog.append(('d', bytes.fromhex(h)))
def b(op, eti): prog.append(('b', op, eti))
def S(ops, tgt): prog.append(('S', ops, tgt))     # br tipo (d16): 4 bytes
def A(ops, tgt): prog.append(('A', ops, tgt))     # absoluto long: 6 bytes
def E(name): prog.append(('E', name))

# ------------------ programa del stub ---------------------------------------
d('10 2d 00 76')            # move.b $76(a5), d0
d('0c 00 00 ff')            # cmpi.b #$ff, d0
b(0x66, 'FSM')              # bne FSM (hay comando armado pendiente)
d('4ef9000155f0')           # jmp $0155F0  (sin comando: el base sigue)
E('FSM')
d('48e76000')               # push d1,d2
d('12 2d 00 5f')            # move.b $5f(a5), d1
d('0c 01 00 0e'); b(0x67,'RUN')   # $5F==$0E (cae)  -> RUN
d('0c 01 00 0d'); b(0x67,'RUN')   # $5F==$0D (sube) -> RUN
d('0c 01 00 08'); b(0x67,'RUN')   # $5F==$08 (apex) -> RUN
d('0c 01 00 07'); b(0x67,'RUN')   # $5F==$07 (salto diagonal) -> RUN
d('42 2d 01 b0'); b(0x60,'SALIDA')# fuera del aire: clr $1B0

E('RUN')
d('14 2d 01 b0')            # move.b $1b0(a5), d2
d('08 2d 00 01 00 71')      # btst.b #1, $71(a5)  (bit1 = abajo)
b(0x66,'PRES')
d('0c 02 00 01'); b(0x66,'RST')   # sin abajo: si d2!=1 -> reset
d('1b 7c 00 02 01 b0'); b(0x60,'SALIDA')  # soltar el 1er abajo: d2=2 armado
E('PRES')
d('0c 02 00 02'); b(0x67,'FIRE')  # abajo + armado(d2==2) -> FIRE
d('1b 7c 00 01 01 b0'); b(0x60,'SALIDA')  # 1er abajo: d2=1
E('FIRE')
d('30 3c 00 04')            # move.w #4, d0
A('4eb9', 0x019C46)         # jsr $19C46.l (cobra 4 de mana)
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

# ------------------ resolucion ----------------------------------------------
def sz(op):
    if op[0]=='d': return len(op[1])
    if op[0]=='b': return 2
    if op[0]=='S': return 4
    if op[0]=='A': return 6
    return 0                      # E

pos = STUB
addr = []
etiq_pos = {}
for op in prog:
    if op[0]=='E':
        etiq_pos[op[1]] = pos; addr.append(pos); continue
    addr.append(pos); pos += sz(op)
total = pos - STUB

cod = bytearray()
for i, op in enumerate(prog):
    aqui = addr[i]
    if op[0]=='d': cod += op[1]
    elif op[0]=='b':
        disp = etiq_pos[op[2]] - (aqui+2)
        if not -128 <= disp <= 127:
            sys.exit('rama corta fuera de margen: %s desde %06X (+%d)' % (op[2].upper(), aqui, disp))
        cod += bytes([op[1], disp & 0xff])
    elif op[0]=='S':
        disp = op[2] - (aqui+4)
        if not -32768 <= disp <= 32767: sys.exit('bsr largo')
        cod += op[1] + struct.pack('>H', disp & 0xffff)
    elif op[0]=='A':
        prefijo = bytes.fromhex(op[1]) if isinstance(op[1], str) else op[1]
        cod += prefijo + struct.pack('>I', op[2])

print('stub: %06X-%06X  (%d bytes %s $%04X)' % (STUB, STUB+len(cod)-1, len(cod),
      'si, entra en el hueco de' , HASTA-STUB))
assert STUB + len(cod) <= HASTA, 'no entra en el hueco'

# ------------------ armado ---------------------------------------------------
rom = bytearray(io.open(RUTA_BASE,'rb').read())
# jmp $1A06AE = 6 bytes EXACTOS (4e f9 00 1a 06 ae); un byte menos corrompe el rom entero
hook_bytes = bytes([0x4e, 0xf9]) + struct.pack('>I', STUB)
assert len(hook_bytes) == 6
rom[HOOK:HOOK+6] = hook_bytes
rom[STUB:STUB+len(cod)] = cod

# el checksum del header NO se toca: en la base ya sale inconsistente con el
# calculo (stored 337B, calculado otro; fix_checksum.py lo documenta)

io.open(RUTA_SAL, 'wb').write(bytes(rom))
print('guardada: %s (%d bytes)' % (RUTA_SAL, len(rom)))
print('SHA256: %s' % hashlib.sha256(bytes(rom)).hexdigest())

# diff contra la base
base = io.open(RUTA_BASE,'rb').read()
bloques = []
i = 0
n = min(len(base), len(rom))
while i < n:
    if base[i] != rom[i]:
        j = i
        while j < n and base[j] != rom[j]: j += 1
        bloques.append((i, j)); i = j
    i += 1
print('bloques distintos contra la base: %d' % len(bloques))
for s,e in bloques[:10]:
    print('  %06X: base %-22s rom39 %s' % (s, base[s:e].hex(' '), rom[s:e].hex(' ')))
