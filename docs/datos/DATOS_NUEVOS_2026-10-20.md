# DATOS NUEVOS — 2026-10-20

Documento de traspaso. Todo lo que está acá es **nuevo** respecto de la
documentación del repo, o **corregido** respecto de ella.

> **La versión legible de este documento es `datos/manifesto.json`**, que es
> la **fuente única de verdad** y la que consume `_disasm_tools/patch_rom.py`.
> Si tocás un byte, tocá el JSON, no este `.md`.

## Niveles de confianza

| Marca | Significa |
|---|---|
| **CODIGO** | Leído del desensamblado 68k, con instrucción y dirección exactas |
| **MEDIDO** | Medido en el emulador (FBNeo) con los scripts de instrumentación |
| **DEDUCIDO** | Conclusión razonable a partir de lo anterior, sin comprobar directo |
| **SIN CONFIRMAR** | Hipótesis pendiente de comprobar en el juego |

---

## 1. EL HALLAZGO QUE ARREGLA EL COLGUE: el checksum se valida al arrancar

**CODIGO + MEDIDO.** Este es el motivo de que todos los ROMs parcheados
colgaran en el logo SEGA.

```asm
004302:  movea.l  #$200, a0       ; inicio de la suma
004308:  movea.l  #$1a4, a1       ; "rom end" de la cabecera
004312:  add.w    (a0)+, d1       ; suma palabra a palabra
004318:  movea.l  #$18e, a1       ; <-- el checksum de la cabecera
00431E:  cmp.w    (a1), d1        ; ¿coincide?
004320:  beq.b    $432e           ; sí -> seguir
004322:  move.w   #$e, $e080.w    ; <-- ERROR: código 0x0E
004328:  move.b   #$1, $1a(a5)    ; <-- y marca el error: el juego se queda ahí
```

**Checksum** = suma de todas las palabras de 16 bits del ROM desde `0x200`
hasta el final, módulo `0x10000`, guardada en `0x18E`-`0x18F`.

> **CORRECCIÓN IMPORTANTE.** El repo dice (INFORME_RE.md): *"El checksum
> almacenado en `0x190` es `0x4A36` en los 8 dumps, pero ninguno lo
> recalcula... indicio de que el header no se actualizó tras las
> modificaciones."* Eso es cierto **de los dumps**, pero **no de los
> parches**: el juego valida el checksum igual, y un ROM parcheado con el
> checksum viejo **no arranca**. La deducción "el checksum no importa"
> estaba equivocada, y costó una tanda entera de ROMs inservibles.

**Regla permanente:** todo parche reescribe el checksum. El parcheador lo
hace **siempre al final**, ya calculado sobre el ROM parcheado.

---

## 2. Correcciones de lo que se affirmations antes

Estas afirmaciones se hicieron **por deducción sin medir** y resultaron
falsas. Quedan documentadas para que no se repitan:

| ✗ Afirmación | ✓ Realidad |
|---|---|
| Los IDs 37/38/39 con hitbox 9×9 son 影手 (Itsuki) | No. **影手 es un objeto** (move ID 6, blob `$0D11E6`, radioX 64). Los 37/38/39 son de otro personaje |
| El startup arranca con 255 frames de delay por el `$5B` | No. El `$5B` **se desborda a 0** en el primer tick: no hay delay. El startup son las duraciones `b0` y/o la máquina de estados |
| El checksum de la cabecera no importa | Falso. **Se valida al arrancar** (§1) |
| El pool de objetos está en `$FF9400` | **Sin verificar.** La aritmética del allocator da `$009400` (24 bits, `movea.w` sign-extiende). En FBNeo puede ser otra cosa |
| El cuelgue en el logo SEGA era por el Z80 | Falso. Era por el **checksum** |

---

## 3. El `$5B` NO es un delay (CODIGO + MEDIDO)

```asm
019c26:  move.b  #$ff, $5b(a5)   ; al arrancar un move
019c96:  addq.b  #$1, $5b(a5)    ; el primer tick lo desborda a 0
019c7a:  tst.b   $5b(a5)         ; 0x1EB7A: el frame data se lee con $5B == 0
```

El `$FF` es **a propósito** un desbordamiento. `$5B` es el **contador de
ticks del frame**, no un delay.

**Medido**: al cambiar de frame el `$5B` salta a `FF` y el ciclo de idle
dura 32 ticks (8+6+4+4+4+6).

---

## 4. La duración de un frame es el byte +0 del registro (CODIGO + MEDIDO)

```asm
01eb5a:  move.b  $0(a2), $5a(a5)  ; byte +0 del registro de 8 bytes -> $5A
019c9c:  move.b  $5a(a5), d0
019ca0:  cmp.b   $5b(a5), d0
019ca4:  bhi.b   $19cc2           ; el frame dura exactamente $5A ticks
```

**Medido**: `$5A=08` → 8 ticks (`00..07`); `$5A=06` → 6; `$5A=04` → 4.

**Consecuencia**: el startup de un move = **la suma de los `b0` de los
frames hasta el primero con hitbox**.

---

## 5. Estructura del objeto (CODIGO)

**Las manos flotantes, las ondas y los proyectiles NO son el personaje: son
OBJETOS del pool.**

| Offset | Qué |
|---|---|
| `$00` | puntero del handler (4 bytes) |
| `$04` | flag de ocupado (word `$0080` = ocupado) |
| `$06` | contador de ticks (word) |
| `$10` | velocidad X (16.16) |
| `$14` | velocidad Y (16.16) |
| `$24` | id gráfico |
| `$40`/`$44` | posición en mundo |
| `$50` | **puntero a la tabla de moves DEL OBJETO** |
| `$58` | **tipo de objeto** (índice de la tabla de handlers en `$14A00`) |
| `$5F` | id de move (en la tabla del objeto) |

**Pool** (CODIGO para el allocator, **DEDUCIDO** para la dirección):

```asm
01fab4:  move.b  #$10, d1 / subq.b #$1, d1 / tst.b d1 / beq.b $1fae8   ; pool lleno
01fabe:  addi.w  #$80, $a036.w
01fac4:  andi.w  #$7ff, $a036.w
01faca:  movea.w $a036.w, a0      ; SIGN-EXTIENDE
01face:  adda.w  #$9400, a0        ; -> $009400 + indice*$80
01fad2:  tst.w   $4(a0) / bne.b $1fab8
01fad8:  move.l  d0, $0(a0) / move.w #$80, $4(a0) / clr.w $6(a0)
```

16 objetos, stride `$80`. **La dirección real en FBNeo no está verificada**;
`tools/fightcade/yuyu_obj.lua` la autodetecta por firma (puntero de handler
válido + flag `$80`).

**Tabla de handlers**: `$14A00`, entradas de 2 bytes = offset relativo.
Cada handler define su propia tabla de moves (`$50`), su gráfico (`$1C`) y sus
flags (`$24`). Ej. el handler de `$58=$10` (en `$14BD2`) pone
`$50 = $14DDC`.

---

## 6. La onda de Itsuki (CODIGO / SIN CONFIRMAR que sea 影手)

| | |
|---|---|
| Tipo `$58` | `$10` → handler `$149AC` → tabla de moves `$14DDC` |
| **Move ID del objeto** | **6** (registro `$015AE8`, frame 1) |
| `b0` de ese frame | 103 |
| **Blob** | `$0D11E6` → **daño 64, stun 40, empuje `$05`, radioX 64, radioY 6**, offX 60, offY 4 |
| Velocidad X | `$10(a0)` = `$FFFF0000` (**−1,0 px/frame**) en `$01FD0A` |

**Los únicos hits anchos (64 px) del set de Itsuki** (CODIGO):

| Move | Frame | Registro | Blob | Daño | Stun | radioX | radioY |
|---|---|---|---|---|---|---|---|
| 160 | 1 | `$0D0402` | `$0D0FEA` | 6 | 134 | 14 | 12 |
| 161 | 2 | `$0D042A` | `$0D11C6` | 52 | 44 | **64** | 7 |
| 171-175 | varios | `$0D05C2`/`$0D05DA` | `$0D11E6` | 64 | 40 | **64** | 6 |

---

## 7. Lo que hace Itsuki durante el especial (MEDIDO)

Con `yuyu_seq.lua` e Itsuki de P1:

```
[f 10353] $5F=01 $59=00 $5A=06      ; ataque normal
[f 10365] $5F=A6 $59=00 $5A=04      ; 166 (frames b0 = 4,4,4)
[f 10378] $5F=A7 $59=00 $5A=02      ; 167 (frames b0 = 2,2,6...)
```

**Los IDs 166 y 167 no tienen hitbox** ⇒ el personaje hace la pose y **la
hitbox la lleva el objeto**.

Tablas:
- **166** → registro `$0D053A`, frames b0 = `[4, 4, 4, 2, 2, 6]`
- **167** → registro `$0D0552`, frames b0 = `[2, 2, 6, 6, 4, 0]`

> ⚠️ **PENDIENTE**: falta la medición del **objeto** (con `yuyu_obj.lua`) para
> saber en qué frame se crea y cuándo entra su hitbox. **Eso es lo que
> falta para poder calcular el startup real de 影手.** Sin eso, cualquier
> parche de startup es una suposición.

---

## 8. El dragón de Hiei (CODIGO / SIN CONFIRMAR que sea el dragón)

**Es un objeto con setup propio**, en un hueco del desensamblado:

```asm
0140d4:  move.l  #$12578, $90(a0)   ; tabla $90 de HIEI (ctx3)
0140f4:  move.b  #$25, $5f(a0)      ; move ID 37 del objeto
014102:  move.l  #$fffa0000, $14(a0) ; velocidad Y = -6,0
014112:  move.l  #$fffe8000, $10(a0) ; velocidad X = -0,5
01411c:  move.l  #$18000,   $10(a0) ; velocidad X = +1,5
```

| Byte | Para la mitad de velocidad |
|---|---|
| `$0x14115` (`FE` → `FC`) | −0,5 → **−0,25 px/f** |
| `$0x14120` (`80` → `C0`) | +1,5 → **+0,75 px/f** |

**Y en el personaje** (ctx3), moves 38 y 39, hitbox 9×9 con la caja a
`offX` −36 y +92 (las dos manos):

| | Move 38 | Move 39 |
|---|---|---|
| Registro | `$0CFE6A` | `$0CFE72` |
| Sub-lista | `$0D08A6` | `$0D08AA` |
| Blob | `$0D10FE` | `$0D110A` |
| Daño / Stun | 9 / 36 | 9 / 172 |
| radioX / radioY | 9 / 9 | 9 / 9 |
| offX / offY | −36 / −52 | +92 / +68 |

---

## 9. Velocidades de proyectil (CODIGO)

Literales 16.16 en `$10(a0)`, por rutina de creación:

| Dirección | Literal | px/frame |
|---|---|---|
| `$0x1FB06` | `$FFFF0000` | −1,0 |
| `$0x1FB14` | `$00010000` | +1,0 |
| `$0x1FB64` | `$00010000` | +1,0 |
| `$0x1FB72` | `$FFFF0000` | −1,0 |
| `$0x1FBCC` | `$FFFE0000` | −0,5 |
| `$0x1FC1E` | `$FFFF0000` | −1,0 |
| `$0x1FC6A` | `$00010000` | +1,0 |
| `$0x1FCB6` | `$00020000` | +2,0 |
| **`$0x1FD0A`** | `$FFFF0000` | **−1,0 (la onda de Itsuki)** |
| **`$0x1FD56`** | `$00010000` | **+1,0 (la onda de Itsuki)** |
| `$0x1FE8E` | `$00010000` | +1,0 |
| `$0x1FED8` | `$00010000` | +1,0 |
| `$0x1FF22` | `$FFFF0000` | −1,0 |
| `$0x1FF6C` | `$FFFF0000` | −1,0 |
| `$0x20006` | `$00018000` | +1,5 |
| `$0x20056` | `$0001E000` | +1,875 |
| `$0x2009E` | `$00018000` | +1,5 |
| `$0x20136` | `$FFFE8000` | −0,5 |

---

## 10. Guajos de Lua en FBNeo (MEDIDO)

1. **No existe `&`** en Lua 5.1/LuaJIT → `bit.band(x, 0xFF)`. Con `&` el
   script no compila y FBNeo lo rechaza al cargarlo.
2. `memory.readbyte` devuelve el byte **con signo** → enmascarar siempre.
3. El 68000 es **big-endian**: `rd16 = b0*256 + b1`, `rd32 = b0*2^24 + …`.
   Leyendo little-endian el HP de 223 sale como 57088.

---

## 11. Cómo usar todo esto

```powershell
# el manifiesto es la fuente de verdad de los parches
python patch_rom.py <entrada.bin> <salida.bin> fix
python patch_rom.py <entrada.bin> <salida.bin> todos
python patch_rom.py --list

# instrumentación (FBNeo: Game > Lua Scripting > New Lua Script Window > Browse)
tools\fightcade\yuyu_seq.lua   # la secuencia de move del personaje
tools\fightcade\yuyu_obj.lua   # los 16 objetos del pool
```

**Los ROMs** están en `C:\proyectos\roms\` (fuera del repo: el `.gitignore`
filtra el ROM por nombre, y con otro nombre no lo filtraría).

**Todos los 16 ROMs tienen el checksum correcto y fueron verificados**
contra `game_68000.asm` (111.420 bytes de código, 0 diferencias en la base).

### Lo que falta para cerrar el startup de 影手

1. Correr `yuyu_obj.lua` con Itsuki de P1 haciendo 影手.
2. Con eso: **en qué frame se crea el objeto** (= startup) y **cuál es su
   move ID y su `$06` (tick)** cuando la hitbox está activa.
3. Recién ahí calcular el parche del startup con dato duro.

### Lo que falta para identificar los movimientos por nombre

El mapeo ID ↔ nombre está al ~50 %. `ITSUKI SET MOVE.LUA` anuncia el ID y
la dirección del registro cada vez que se gasta maná: con eso se empareja
cada ID con su técnica y se cierra la tabla.
