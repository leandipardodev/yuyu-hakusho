# Emulador 68000 sobre Unicorn — estado y hallazgos

Herramienta: `_disasm_tools/m68k_gensim.py` (+ `m68k_rescue.py`, `m68k_dispatch.py`).

Objetivo: ejecutar el codigo real del ROM para capturar el frame data exacto
(startup/active/recovery) leyendo los registros en la instruccion que aplica el
dano (`0x19C46`, `sub.w d0,$b8(a5)`).

## Estado actual: ARRANCA Y CORRE, BLOQUEADO POR EL Z80

El emulador ejecuta el boot completo del juego **sin un solo error**:

```
espejo 24 bits: 0xFF000000 +0x10000000
reset: SP=0x00FFFF00 PC=0x00000200 (A7=0x00FFFF00)
frames VBlank : 20
DAÑOS         : 0
rescates      : {'disp': 4156}
por instruccion: {'ORI.W,SR': 21, 'DBcc': 4110, 'imm2Dn': 24, 'MOVE SR/CCR': 1}
errores       : 0
```

La ejecucion se detiene en un bucle de espera del handshake del Z80:

```
000356:  08 f9 00 00 00 a1 11 00  bset.b    #$0, $a11100.l
00035e:  66 f6                 bne.b     $356
```

`$A11100` bit 0 = Z80 en reset. El juego para el Z80 y espera a que el bit
quede activo. Como el Z80 no se emula, el juego se queda esperando.

## Arquitectura del emulador

### 1. Base: Unicorn Engine 2.1.4 (`UC_ARCH_M68K`)
Se descarto escribir un 68000 a mano (169 opcodes, inviable) en favour del
core de Unicorn, corrigiendo sus limitaciones con las siguientes capas.

### 2. Capa de rescate (`m68k_dispatch.py`)
El core M68K de Unicorn 2.1.4 **no implementa** estas instrucciones
(inventario obtenido con `scan_opcodes_unicorn.py`, 88 casos de prueba):

| Familia | Opcodes | Notas |
|---|---|---|
| Retorno de excepcion | `RTE`, `RTR` | imprescindible: toda IRQ vuelve con RTE |
| DBcc / DBRA | `DBRA`, `DBEQ`, ... | mascaras: `(op & 0xF0C0) == 0x50C0` |
| Inmediatos a Dn | `ORI`, `ANDI`, `SUBI`, `ADDI`, `EORI` | `CMPI` si funciona |
| Quick | `ADDQ`, `SUBQ` | |
| Logicos | `NEG`, `NOT` | |
| Bit a bit | `BTST`, `BCHG`, `BCLR`, `BSET` | |
| Desplazamientos | `ASL/ASR/LSL/LSR/ROL/ROR/ROXL/ROXR` | |
| Miscelanea | `MOVEM`, `TRAP`, `MOVE SR/CCR <ea>` | |

Ejemplo: `MOVE SR,<ea>` (`0x40C0|ea`), imprescindible en la entrada del
handler de IRQ.

Ademas Unicorn **extiende con signo** las direcciones absolutas `.W`
(`MOVE.W #imm,$F518.w` → escribe en `0xFFFFF518` en vez de `0x00F518`).
Verificado de forma aislada.

### 3. Espejo de 24 bits
El ROM depende del bus de 24 bits del 68000 y usa operandos absolutos de 32
bits con el nibble alto a 1:

```
003172:  33 f8 e0 00 ff ff f1 40  move.w    $e000.w, $fffff140.l
00318e:  33 f9 ff ff f1 42 00 c0 00 00  move.w    $fffff142.l, $c00000.l
003498:  21 fc ff ff e8 00 f5 98  move.l    #$ffffe800, $f598.w
```

y el vector de reset trae `SP=$FFFFFF00` (-> `$FFFF00`).

Unicorn no trunca. En vez de parchear el codigo (lo que **corromperia
inmediatos** como `#$ffffe800`), se mapea un **espejo de 256 MB** en
`0xFF000000` y se mantiene la RAM canonica en `0xFF0000`:

- lectura en el espejo -> se refresca la pagina desde la RAM canonica
- escritura en el espejo -> se propaga a la RAM canonica

Espejo: `16374 escrituras / 21 lecturas` en el arranque.

### 4. IRQ de VBlank
Unicorn 2.x **no expone `emu_interrupt()`**. El VBlank (nivel 6) se simula a
mano: se empuja el frame de supervisor (PC largo + SR palabra) en la pila, se
activa el bit de nivel 6 del SR y se salta al vector `0x78`. El handler
termina con `RTE`, rescatado.

### 5. Pila bancada (detalle critico)
El 68000 tiene punteros de pila bancados. Al poner el bit S del SR a 1, la CPU
carga A7 desde `CR_ISP`. Si se escribe el SR antes de preparar `CR_ISP`/`A7`,
A7 queda en 0 y el primer `jsr` escribe en `0xFFFFFFFC`. Orden correcto:
`SR` -> `CR_ISP`/`CR_USP` -> `A7`.

### 6. Handshake Z80 del arranque
El boot testea `$A10008` y `$A1000C` (espejo del work RAM) esperando el ACK del
driver de sonido Z80. Sin Z80 emulado la ROM espera eternamente en el bucle de
`$214`, asi que se inyecta el ACK en el work RAM y en su espejo `$A1xxxx`.

## Mapa de memoria

| Region | Tamano | Contenido |
|---|---|---|
| `0x000000-0x3FFFFF` | 4 MB | ROM (3 MB reales + relleno) |
| `0xA00000-0xA0FFFF` | 64 KB | bus del Z80 / SOUND |
| `0xA10000-0xA11FFF` | 8 KB | puertos I/O + ventana Z80 |
| `0xC00000-0xC00FFF` | 4 KB | VDP (data/ctrl/hv) |
| `0xE00000-0xE0FFFF` | 64 KB | espejo de ROM |
| `0xFF0000-0xFFFFFF` | 64 KB | work RAM (canonica) |
| `0xFF000000-0xFFFFFFFF` | 256 MB | espejo de la RAM (truncado 24 bits) |

Ojo: el espejo de ROM `0xE00000` debe ser **menor de 0x10000**; con 0x20000
pisaba el work RAM y rompia la pila.

## Lo que falta para tener frame data exacto

1. **Emular el Z80** (`UC_ARCH_Z80`) con memoria compartida entre las dos CPUs
   (`mem_map_ptr` sobre el mismo buffer). Es lo que desbloquea el arranque y el
   resto del juego. El driver Z80 esta en ROM `0x393FE`, `0xC00` bytes.
2. **VDP minima**: el arranque espera el flag de blanking en `$C00004`.
3. **Script de entrada**: forzar la secuencia para llegar a combate y colocar
   los joypads.
4. Instrumentar `0x1EB5A` (lector de moves) y `0x19C46` (aplicacion de dano)
   para extraer startup/active/recovery por golpe.

## Uso

```powershell
python _disasm_tools\m68k_gensim.py 60      # 60 VBlanks + informe
```
