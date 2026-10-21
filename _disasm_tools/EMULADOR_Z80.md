# Emulador 68000 + Z80 — estado y hallazgos

Herramientas en `_disasm_tools/`:
- `m68k_gensim.py` — motor principal (68k + puente Z80 + IRQ)
- `m68k_rescue.py` — helpers de direccionamiento y flags M68000
- `m68k_dispatch.py` — rescate por mascara de bits de las instrucciones no soportadas
- `m68k_capexec.py` — ejecutor generico que usa Capstone como fuente de verdad
- `scan_opcodes_unicorn.py` — inventario de lo que Unicorn no implementa
- `EMULADOR_68000.md` — detalle tecnico (ver tambien)

Objetivo: ejecutar el codigo real del ROM para leer los registros en la
instruccion que aplica el dano (`0x19C46`, `sub.w d0,$b8(a5)`) y extraer el
frame data real.

## Base: por que Unicorn y no un 68000 propio

Se intento primero un rastreador 68000 a mano; se abandono tras ver que el ROM
usa **169 opcodes distintos** mas VDP/Z80. El core M68K de Unicorn esta
verificado aunque incompleto, y sus huecos se pueden cubrir. Se instalo
`unicorn==2.1.4`. Para el Z80, Unicorn **no tiene soporte** (no existe
`UC_ARCH_Z80` en 2.1.4), asi que se usa `z80==1.2.0` (emulador puro en Python
con `Z80Machine` y callbacks de lectura/escritura/entrada/salida).

## Estado: el 68k arranca completo y el Z80 corre

```
espejo 24 bits: 0xFF000000 +0x10000000
reset: SP=0x00FFFF00 PC=0x00000200
rescates      : {'disp': 7982, 'capstone': 6}
por instruccion: {'ORI.W,SR': 12, 'DBcc': 7929, 'imm2Dn': 27, 'MOVE SR/CCR': 10,
                  'ADDQ/SUBQ': 3, 'MOVEM': 1}
capstone      : {'move': 1, 'cmpi': 1, 'lea': 1, 'alu': 1, 'bset': 2}
Z80           : pc=0xD290 reset=False busreq=True bloques=2048 outs=0
```

Logros verificados:
- El boot del 68k se ejecuta **sin errores**.
- El driver Z80 **se copia a la RAM compartida** (3072 iteraciones del bucle de
  copia en `0x38AA0`) y **se ejecuta** (2048 bloques).
- El handler de IRQ de VBlank funciona.

## Lo que falta

1. **Mapa de memoria del Z80**: el Z80 acaba en `0xD290`, dentro de la ventana
   bancada del 68000 (`0x8000-0xFFFF`), que devuelve `0xFF` y lo hace ejecutar
   basura. Falta mapear esa ventana al banco de ROM que indique el registro de
   banco, y tratar `0x4000-0x60FF` (registros de sonido) como rechazos.
2. **Interrupciones del Z80**: el driver es un motor de sonido que acaba en
   `halt` esperando la IRQ de VBlank; hay que inyectarsela con
   `on_handle_active_int()` y `set_get_int_vector_callback`.
3. **Valores por defecto de los puertos** de E/S (`0x00-0x1F`) que el driver
   espera al arrancar.
4. Cuando el Z80 complete su handshake, el 68k debe superar el bucle
   `0x38B88: tst.b (xxx).l / bmi` (espera a que el sonido termine) y seguir
   hasta los menus.
5. Solo entonces: VDP minima, secuencia de entrada, y lectura de `0x1EB5A`
   (moves) y `0x19C46` (dano) para el frame data exacto.

## Detalles tecnicos discoveries

### El ROM depende del bus de 24 bits
```
003172:  33 f8 e0 00 ff ff f1 40  move.w    $e000.w, $fffff140.l
003498:  21 fc ff ff e8 00 f5 98  move.l    #$ffffe800, $f598.w
```
y el vector de reset trae `SP=$FFFFFF00` (-> `$FFFF00`).

Unicorn no trunca. Se mapea un **espejo de 256 MB** de la RAM en `0xFF000000`
con la RAM canonica en `0xFF0000` (lectura -> refresca pagina; escritura ->
propaga). Parchear el codigo no sirve: rompia los inmediatos (`#$ffffe800`).

### Unicorn extiende con signo las direcciones absolutas `.W`
`MOVE.W #imm,$F518.w` escribe en `0xFFFFF518` en vez de `0x00F518`. Verificado
de forma aislada.

### Pila bancada: orden critico
Al poner el bit S del SR a 1 la CPU carga A7 desde `CR_ISP`. Escribir el SR
antes de preparar `CR_ISP`/`A7` deja A7 en 0 y el primer `jsr` escribe en
`0xFFFFFFFC`. Orden: `SR` -> `CR_ISP`/`CR_USP` -> `A7`.

### El espejo de ROM `0xE00000` no puede ser de 0x20000
Tamanos >= 0x10000 solapan con el work RAM en `0xFF0000` y rompen la pila.

### VBlank sin `emu_interrupt()`
Unicorn 2.x no expone `emu_interrupt()`. El IRQ de nivel 6 se simula a mano:
se empuja el frame de supervisor (PC largo + SR palabra), se activa el bit de
nivel 6 del SR y se salta al vector `0x78`. El handler cierra con `RTE`, que
esta en la lista de no implementados.

### Inventario de instrucciones no implementadas por Unicorn 2.1.4
Medido con `scan_opcodes_unicorn.py` (88 casos). Marcadas solo las que lanzan
`UC_ERR_EXCEPTION`:

RTE, RTR · DBcc/DBRA · ORI/ANDI/SUBI/ADDI/EORI #n,Dn · ADDQ/SUBQ · NEG/NOT ·
BTST/BCHG/BCLR/BSET · ASL/ASR/LSL/LSR/ROL/ROR/ROXL/ROXR · MOVEM · TRAP ·
`MOVE SR/CCR <ea>`

Ademas, en ejecucion real, Unicorn rechazo `move.b d1,(a0,d0.w)` (`0x1181`),
asi que hay formas validas que solo fallan con ciertos valores de operandos.
Por eso el ejecutor de `m68k_capexec.py` usa **Capstone como fuente de verdad**
(quien si decodifica esas formas) en vez de decodificar a mano: intentar
interpretar los bits a mano produjo errores propios (`KeyError` por tomar
`bits 8-6` como tamano en 0x1181, donde Capstone si acierta).

### Protocolo del arranque Z80
```
000350:  jsr    $a44.l
000356:  bset.b #0, $a11100.l      ; esperar Z80 detenido (BUSREQ=1)
00035e:  bne.b  $356
...
038a92:  lea.l  $393fe(pc), a0      ; driver Z80 en ROM
038a96:  lea.l  $a00000.l, a1       ; destino: espacio del Z80 (= work RAM $FF0000)
038a9c:  move.w #$bff, d0
038aa0:  move.b (a0)+, (a1)+
038aa2:  dbra   d0, $38aa0
038aa6:  move.w #$0, $a11200.l      ; soltar el bus: el Z80 corre
```

`$A11100` bit 0 = BUSREQ (1 = el 68k toma el bus), bit 1 = RESET.
`$A10008` y `$A1000C` los escribe el Z80 por sus puertos de E/S.

## Mapa de memoria

| Region (68k) | Tamano | Contenido |
|---|---|---|
| `0x000000-0x3FFFFF` | 4 MB | ROM (3 MB + relleno) |
| `0xA00000-0xA0FFFF` | 64 KB | ventana del Z80, alias del work RAM |
| `0xA10000-0xA11FFF` | 8 KB | puertos de E/S + ventana Z80 (alias) |
| `0xC00000-0xC00FFF` | 4 KB | VDP |
| `0xE00000-0xE0FFFF` | 64 KB | espejo de ROM |
| `0xFF0000-0xFFFFFF` | 64 KB | work RAM canonica (compartida con el Z80) |
| `0xFF000000-0xFFFFFFFF` | 256 MB | espejo de la RAM (truncado 24 bits) |

| Region (Z80) | Contenido |
|---|---|
| `0x0000-0x1FFF` | work RAM compartida con el 68k (`$FF0000`) |
| `0x2000-0x3FFF` | espejo de la anterior |
| `0x4000-0x60FF` | registros de sonido (se ignoran) |
| `0x7F00-0x7FFF` | VDP |
| `0x8000-0xFFFF` | ventana bancada del 68k (**sin mapear**) |

## Uso

```powershell
python _disasm_tools\m68k_gensim.py 60      # 60 VBlanks + informe
```
