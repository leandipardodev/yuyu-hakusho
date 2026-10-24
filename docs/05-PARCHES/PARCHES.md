# PARCHES DE ROM — Yu Yu Hakusho: Makyou Toitsusen (Mega Drive)

Documento de trabajo para **modificar el ROM original**. Todo lo que está
aquí está verificado byte a byte contra el desensamblado `desensamblado_68000.asm`
y contra los volcados de datos del repo.

Fecha: 2026-10-19.

---

## 1. Herramienta

`herramientas/desensambladopatch_rom.py` — parcheador **verificado**.

```powershell
# aplicar un grupo
python patch_rom.py <entrada.bin> <salida.bin> fix
python patch_rom.py <entrada.bin> <salida.bin> dragon dragon_vel blob --factor=0.5
python patch_rom.py <entrada.bin> <salida.bin> extras

# ver los grupos
python patch_rom.py --list
```

**Reglas del parcheador** (aprendidas de los parches rotos de este repo):

1. Cada byte a tocar declara su **valor esperado**. Si el ROM no lo tiene,
   el parcheador **aborta sin escribir nada**. Un parche que se aplica
   sobre un ROM distinto al que se 준비ó es un parche que rompe el juego.
2. Después de escribir, **relee la salida** y comprueba cada byte.
3. Los parches son de un byte (o 4 como mucho). Nada de búsquedas de
   texto: el ROM es binario, y `str.replace` no avisa cuando no aplica.

La regla 1 es la que faltaba en el intento anterior. Un byte cambiado de
sitio (o un desplazamiento de rama partido en 2 bytes) produce un ROM que
no crashea sino que **hace otra cosa**, que es peor: no se nota.

---

## 0. ⚠️ EL JUEGO VERIFICA EL CHECKSUM DE LA CABECERA AL ARRANCAR

**Este es el motivo de todos los cuelgues en el logo SEGA.**

```asm
004302:  movea.l  #$200, a0       ; a0 = inicio de la suma
004308:  movea.l  #$1a4, a1       ; "rom end" de la cabecera
00430E:  move.l   (a1), d0
004310:  moveq    #$0, d1
004312:  add.w    (a0)+, d1       ; suma palabra a palabra desde 0x200
004314:  cmp.l    a0, d0
004316:  bcc.b    $4312
004318:  movea.l  #$18e, a1       ; <-- el checksum de la cabecera
00431E:  cmp.w    (a1), d1        ; ¿coincide?
004320:  beq.b    $432e           ; SI -> seguir
004322:  move.w   #$e, $e080.w    ; <-- ERROR: escribe 0x0E en $E080
004328:  move.b   #$1, $1a(a5)    ; <-- y marca el error: el juego se queda ahi
```

**=> Cualquier parche que cambie bytes invalida el checksum, y el juego se
clava en el logo SEGA con el código de error `0x0E` en `$E080`.**

**El checksum es**: la suma de todas las palabras de 16 bits del ROM desde
`0x200` hasta el final (0x2FFFF), módulo 0x10000, guardada en `0x18E`-`0x18F`.

**Regla del proyecto (nueva, prioritaria):**
> **Todo parche de ROM tiene que reescribir el checksum.**
> Por eso `herramientas/desensambladopatch_rom.py` lo hace **SIEMPRE al final**, ya
> calculado sobre el ROM parcheado. Con `--sin-checksum` se desactiva
> (solo para depurar).

> **ERROR PROPIO que costó una tanda entera de ROMs muertos**: los docs del
> proyecto dicen que "ninguno de los 8 dumps recalcula el checksum" y que
> el header quedó obsoleto. **Eso es cierto de los dumps, pero NO de los
> parches**: el juego valida el checksum igual, y un ROM parcheado con el
> checksum viejo **no arranca**. La deducción "el checksum no importa"
> estaba equivocada.

---

## 1.c 影手 (Itsuki): las manos NO son el personaje, son un OBJETO

**Medido en el juego** (`herramientas/lua/sonda_secuencia.lua`, Itsuki = slot 1):

```
[f 10353] $5F=01 $59=00 $5A=06      ; ataque normal
[f 10365] $5F=A6 $59=00 $5A=04      ; 166 (frames b0 = 4,4,4)
[f 10378] $5F=A7 $59=00 $5A=02      ; 167 (frames b0 = 2,2,6...)
```

Los IDs **166 y 167 no tienen hitbox** (bit 6 del byte +0 de la entrada de
sub-lista = 0). Son las poses del personaje.

**La onda de fuego es un OBJETO del pool** (16 objetos de `$80` bytes en
`$FF9400 + i*$80`):

| | |
|---|---|
| Tipo `$58` | `$10` → handler `$149AC` → tabla de moves `$14DDC` |
| **Move ID del objeto** | **6** (registro `$015AE8`, frame 1) |
| **Blob** | `$0D11E6` → **daño 64, stun 40, radioX 64, radioY 6** |
| Velocidad X | `$10(a0)` = `$FFFF0000` = −1,0 px/frame |

**radioX 64 × radioY 6 = una onda horizontal de fuego.** El mismo blob
`$0D11E6` aparece en los moves 171-175 del personaje.

> **La velocidad de la onda** se cambia en `$0x1FD0A` (`move.l #$ffff0000,
> $10(a0)`) y su gemela `$0x1FD56` (`#$10000`). Para el doble de velocidad:
> `$0x1FD0D`: `FF` → `FE` (−2,0) y `$0x1FD59`: `01` → `02` (+2,0).

> **CORRECCION**: los IDs 37/38/39 (cajas 9×9, offX −36 / +92) **NO son
> 影手**. Esos son de otro personaje. La identificación correcta sale de la
> medición, no de la deduccion.

### Herramientas de medicion

| Script | Qué mide |
|---|---|
| `herramientas/lua/sonda_secuencia.lua` | la secuencia de move del personaje (slot configurable) |
| `herramientas/lua/sonda_objetos.lua` | los 16 objetos del pool: tipo, move ID, posición, velocidad |

**Guajos de Lua en FBNeo (los tres que costaron una ronda):**
1. **No existe `&`** en Lua 5.1/LuaJIT → usar `bit.band(x, 0xFF)`.
2. `memory.readbyte` devuelve el byte **con signo** → enmascarar siempre.
3. El 68000 es **big-endian**: `rd16 = b0*256 + b1`, `rd32 = b0*2^24 + ...`.

El startup de un move es **la suma de las duraciones** (byte +0 del registro
de 8 bytes) de los frames anteriores al primero con **hitbox**
(bit 6 del byte +0 de la entrada de sub-lista `$8C`).

### ⚠️ El `$5B` NO es un delay (error propio)

Al arrancar un move, `$0x19C26` hace `move.b #$ff, $5b(a5)`. **Eso NO es un
delay de 255 frames**: el primer tick (`0x19C96: addq.b #$1, $5b(a5)`) lo
**desborda a 0**, que es justo lo que se necesita para que el frame data se
lea (`0x1EB7A: tst.b $5b(a5)` / `bne.b $1eba4`).

**=> Parchear `$0x19C29` (FF → 01) no cambia NADA.** Ya se comprobó en el
juego: el startup no se movió. Ese parche quedó **eliminado** del parcheador.

### La cadena de 影手 (Itsuki, ctx6, move ID 37)

| frame | registro | b0 (duración) | hitbox |
|---|---|---|---|
| 0 | `$0CFE4A` | 4 | no |
| 1 | `$0CFE52` | 4 | no |
| 2 | `$0CFE5A` | 8 | no |
| **3** | **`$0CFE62`** | **255** | no |
| 4 | `$0CFE6A` | 255 | **SÍ** — mano izquierda, radioX 9, offX −36 |
| 5 | `$0CFE72` | 255 | **SÍ** — mano derecha, radioX 9, offX +92 |

**El frame 3 con `b0 = 255` es el gigante del startup.** (Los `b0 = 255` de
los frames 4-5 son la ventana de golpe: la mano se queda ahí.)

### Parches

| Grupo | Bytes | Qué hace |
|---|---|---|
| **`kage_startup`** | `$0CFE4A`, `$0CFE52`, `$0CFE5A`, **`$0CFE62`** → `01` | wind-up de 4+4+8+255 → 1+1+1+1. **Solo afecta a 影手** |
| **`kage_hitdur`** | `$0CFE6A`, `$0CFE72` → `14` (20) | la ventana de golpe de cada mano: 255 → 20 ticks |
| **`kage_vel`** | `$0x18809` (`asr.l #$1` → `#$2`) | el desplazamiento durante 影手: ÷2 → **÷4** |

> Nota: los frames 0-3 son compartidos con el move ID 36 (el dispatcher de
> `$0x1A0A8` manda a `$0x1A102` para los IDs 37/39/47/48). El frame 3
> (`$0CFE62`) es el último antes de la hitbox y **es el que manda**.

### La velocidad durante 影手

```asm
018804:  move.l  $10(a5), d0
018808:  asr.l   #$1, d0        ; <-- divide la velocidad POR 2
01880a:  move.l  d0, $10(a5)
```

Al iniciar 影手, Itsuki se mueve a la mitad de su velocidad normal.

---

## 1.bis.bis EL CUELGUE: el juego depende del Z80 para arrancar

**Síntoma**: la pantalla queda en rojo y el juego no pasa del logo SEGA.

**Causa**: el 68000 **reinicia el Z80 antes de cada comando** y espera a que
el driver ponga su flag `$1F2A = 1`. Si el Z80 no responde, el juego se
queda en un **bucle infinito**:

```asm
038b4a:  lea.l   $a04000.l, a0     ; buzon del Z80
038b50:  move.w  sr, -(a7)
038b52:  ori.w   #$700, sr         ; interrupts off
038b56:  move.w  #$100, $a11100.l  ; pide el bus
038b5e:  bset.b  #$0, $a11100.l    ; RESET del Z80
038b66:  bne.b   $38b5e            ; espera el ack del reset
038b68:  tst.b   $a01f2a.l         ; ¿el Z80 puso su flag?
038b6e:  beq.b   $38b7e            ; no -> escribir el comando
038b70:  move.w  #$0, $a11100.l
038b78:  bsr.w   $38c0c
038b7c:  bra.b   $38b56            ; reintenta
038b7e:  tst.b   (a0)              ; espera a que el buzon este libre
038b80:  bmi.b   $38b7e            ; <<< BUCLE INFINITO
```

El driver Z80 pone ese flag en su **primera instrucción**
(`ld (1f2ah),a`, en `desensamblado_z80.asm` $0008), o sea que basta con que
el Z80 se ejecute una vez.

**Parche de diagnóstico `sinz80`** (5 bytes) — el juego arranca **sin
sonido** y sin depender del Z80:

| Dirección | Base | Parcheado | Qué hace |
|---|---|---|---|
| `0x38B66` | `66 F6` (bne.b $38b5e) | `60 00` (bra.b $38b68) | no espera el ack del reset |
| `0x38B6E` | `67 0E` (beq.b $38b7e) | `60 0E` (bra.b $38b7e) | no mira el flag `$1F2A` |
| `0x38B80` | `6B FC` (bmi.b $38b7e) | `60 00` (bra.b $38b82) | no espera a que el buzón se libere |

Si con este ROM el juego **arranca**, el problema es el Z80 (emulador o
driver). Si **también** se cuelga, el problema está en otro sitio.

**El driver Z80 del ROM es idéntico al de referencia** (3072 bytes,
0 diferencias) y la cabecera, los vectores, el código y las tablas de
moves también. Ver `herramientas/desensambladocheck_boot.py`, `check_z80.py` y
`check_checksum.py`.

---

## 2. Los 2 parches que estaban en el ROM y no servían

ROM original del usuario:
`C:\Users\leand\Downloads\ROM A MODIFICAR - HIEI DRAGON LENTO v1 NO SIRVE + BLOB B 68=9.md`
(SHA1 `810BAA877AE48D6B5432A16B1E3D75A00D5111C3`)

Diferencia con el ROM base: **6 bytes**, en 2 parches. Ninguno de los dos
crashea el juego — por eso "no sirve" era tan difícil de diagnosticar.

### Parche A — 4 bytes en `0x1A4EA`-`0x1A4ED`

```asm
base : 01a4ea:  53 6d 00 b8   subq.w  #$1, $b8(a5)   ; maná -= 1  (goteo por frame)
roto : 01a4ea:  4e 71 4e 71   nop ; nop              ; el goteo desaparece
```

Contexto (`0x1A4C4`): el goteo ocurre si hay maná (`tst.w $b8(a5)`) y el
acumulador `$7C` no llegó a 256.

**Efecto real**: el personaje **deja de gastar maná con el tiempo**.
`4E 71` es el NOP de 68000 → código válido, no hay crash.

### Parche B — 2 bytes en `0x1B1E6`-`0x1B1E7`  ← **ESTE es el que rompe el dragón**

```asm
base : 01b1e4:  60 00 f2 4a   bra.w  $1a430
roto : 01b1e4:  60 00 68 22   bra.w  $21a08
```

El desplazamiento ocupa `0x1B1E6` (alto) y `0x1B1E7` (bajo). `0x1B1E4` es
el opcode `0x60` y no se toca. **Los dos bytes van juntos**: con solo el
alto el destino queda en `0x1A408`, que tampoco es `0x1A430`.

**`0x1A430` es la rutina que CREA EL PROYECTIL**:

```asm
01a430:  cmpi.b #$1, $60(a5)
01a436:  beq.w  $1a6f2
01a43a:  cmpi.b #$4, $59(a5)
01a440:  bne.w  $1a6fa
01a444:  movea.l a5, a1
01a446:  adda.l #$200, a1
01a44c:  cmpi.w #$0, $4(a1)
01a452:  bne.b  $1a4c4
01a454:  move.l  #$132de, $0(a1)     ; <-- handler del objeto
01a45c:  move.w  #$100, $4(a1)
...
01a496:  move.w  $9c(a5), $9c(a1)    ; Y del objeto
01a49c:  move.w  $14(a5), $14(a1)    ; velocidad Y del objeto
01a4a2:  move.w  $10(a5), $10(a1)    ; VELOCIDAD X del objeto
01a4a8:  cmpi.b #$0, $61(a5)
01a4ae:  beq.b  $1a4b4
01a4b0:  neg.w  $10(a1)              ; invertida si mira a la izquierda
```

Al saltar a `0x21A08` (otra cosa: el drenado de maná cuando `$62` llega a
0) **el proyectil no se crea nunca** → **el dragón no aparece**. Eso es
"v1 NO SIRVE".

**La reparación**: `0x1B1E6: 68 → F2` y `0x1B1E7: 22 → 4A`.

---

## 3. El dragón de Hiei

**Move ID 38** (y 39, su variante). Es el único move del juego con una
hitbox de 68 px de ancho: una onda horizontal de fuego.

| Dato | Valor | Dónde |
|---|---|---|
| Registro del move | `$0C8162` | ctx3 (Hiei), base `$50` = `$0C7C9A` |
| Velocidad X (frame 0) | b6 = `$82` → **2 px/frame** | `$0C8168` |
| Sub-lista | `$0C8E9A` (frame 0), `$0C8E9E` (frame 1) | base `$8C` = `$0C8BEA` |
| Blob frame 0 | `$0C99B2` | daño 56, stun 36, empuje `$06` |
| Hitbox frame 0 | radioX **68**, radioY 1 | `$0C99B6` |
| Hitbox frame 1 | radioX 60, radioY 2 | `$0C99C2` |
| Frames con hitbox | **solo el 0 y el 1** (los dos con b0=`$FF` = bucle) | |

Los demás frames del move tienen flags `$08`/`$18` (pushbox/hurtbox), sin
bit 6 → **no hacen daño**. La onda sale y se queda viajando mientras el
frame en bucle se repite.

**"BLOB B 68=9"**: la caja de la cadena de 3 cajas del frame 4, en
`$0C99AE`, tiene **radioX = 68 y radioY = 9**. Cambiar el radioX a 9 es el
parche `blob` del parcheador.

### Los dos knobs de velocidad

| | Qué | Dónde | Original | Mitad |
|---|---|---|---|---|
| **A** | vX del frame con hitbox (el "cuerpo" de la onda) | `$0C8168` (b6) | `$82` = 2 px/f | `$81` = 1 px/f |
| **B** | velocidad 16.16 del **proyectil** (tabla `$90` de Hiei) | `$012585` (largo) | `$0001C000` = 1.75 px/f | `$0000E000` = 0.875 px/f |

> ### ⚠️ EL "B" ROMPIE EL SALTO DIAGONAL DE HIEI — ESTA CONFIRMADO
>
> La tabla `$90` de Hiei es **compartida**: el **salto normal diagonal** de Hiei
> usa una entrada de la misma tabla, y al bajarla a la mitad **el salto va
> lento**. Se comprobó jugando: con el grupo `dragon_vel` aplicado, el salto
> diagonal de Hiei va a la mitad de velocidad.
>
> **Por eso `dragon_vel` está FUERA de la versión unificada** y solo queda el
> **A**, que es el quirúrgico (el b6 del frame con hitbox, que solo toca al
> dragón). La receta `01b_hiei_dragon_proyectil_lento` deja el B disponible
> para hacer el A/B.

El B sale de `move.l $c(a2), $10(a5)` (`0x1865C`), con `a2` = la tabla
`$90` del personaje (ctx3 → base `$012578`, 10 entradas de 30 bytes). El
proyectil lo hereda en `0x1A4A2`.

⚠️ El B es **global para los especiales de Hiei** que usen esa entrada
de la tabla, no solo el dragón. El A es el quirúrgico.

---

## 4. Catálogo de parches verificados

### Vida / maná / stun
| Objetivo | Dirección | Bytes | Tipo |
|---|---|---|---|
| HP máximo 223 | `0x12AE8`, `0x1368A` | `FF FF` → `DF 00` | W×2 |
| Umbral HP bajo | 11× `cmpi.w #$6f, $78(a5)` | `6F` | B×11 |
| Tope de maná | `0x1A2E2` | `$df0000` | L |
| Maná por combo ×2 | `0x1FA10` (`asl.w #$1` → `#$2`) | | B |
| Stun máximo por personaje | 10× `move.w #xx, $80(a5)` | ver abajo | W×10 |
| Combo tope 16 → 255 | `0x1FA01` | `10` → `FF` | B |
| Slow-mo de muerte 160 → 255 | `0x1FA85` | `A0` → `FF` | B |
| Muerte más temprana (HP<32) | `0x1F4CD` | `00` → `20` | B |
| Hitstun 16 → 24 (atacante / defensor) | `0x1F2E3` / `0x1F2EF` | `10` → `18` | B×2 |
| Hitstun de clash 28 → 40 | `0x1F161` | `1C` → `28` | B |
| Empuje físico entre peleadores ×2 | `0x1EE94` (`asl.l #$7` → `#$8`) | `EF` → `E1` | B |
| Empuje del golpe limpio nivel 0 (3 → 6 px/f) | `0x1F445` | `03` → `06` | B |

Stun máximo por ctx: `0x127CE`=40, `0x12818`=56, `0x12862`=48,
`0x128AC`=44, `0x128F6`=54, `0x12940`=46, `0x1298A`=40, `0x129D4`=38,
`0x12A1E`=48, `0x12A68`=62.

### Golpes
| Objetivo | Dónde | Tamaño |
|---|---|---|
| Daño de un golpe | byte +0 del **blob** de su frame activo (el de `0x1EC0E`) | 1 |
| Stun por golpe | byte +1 del blob (`0x1EC12`) | 1 |
| Pushback por golpe | byte +2 del blob (`0x1EC16`), bits 0-1 | 1 |
| Quitar el daño | byte +2, **bit 4** | 1 |
| Quitar el hitstun | byte +2, **bit 5** | 1 |
| Radio de la hitbox | bytes +4 y +6 del blob | 1×2 |
| Hitstun 16 → 24 | `0x1F2E0`, `0x1F2EC` | 1×2 |
| Hitstun de clash 28 → 40 | `0x1F15E` | 1 |
| Empuje ×2 | `0x1F442`/`0x1F464`/`0x1F486` | 4×3 |
| Empuje físico ×2 | `0x1EE92`/`0x1EE94` (`asl.l #$8`→`#$9`) | 1×2 |

### Rondas / modos / física
| Objetivo | Dirección | Bytes |
|---|---|---|
| Roster VS 2P | `$0x7A96` / `$0x7ABC` (16) | W×16 |
| Roster 1P vs CPU (8 rondas) | `$0xD166` | W×8 |
| Nº de dificultades de CPU | `0x2C86` (`#$4` → `#$1`) | 2 |
| Velocidad al caminar | `$D282` (12 words) | 2 |
| Gravedad / caída | `$D2A2` (12 words) | 2 |

---

## 5. Lo que NO se puede parchear con un parche de ROM

Están en RAM en runtime, solo por cheat o emulador:

- HP actual, `$7E` (stun actual), `$69` (hitstun actual), `$63` (máscara)
- `$C6` (combo actual)
- **dificultad de CPU** (tabla en `$F798`, máscara en `$F551`)
- `$F550` bit 6/7, `$F55A`, `$F558`
- **blockstun**: no hay dirección. 32 es un valor *medido*, no leído del ROM

Y dos trampas grandes:

- **El bit 7 de `$F550` NO se puede forzar globalmente**: es a la vez el
  flag de "modo desbloqueado" y el de "simulación suspendida". Con él a 1,
  el dispatcher de colisiones (`0x1EDAC`) no corre y el combate muere.
  Para el 1v3 hay que parchear la puerta del menú, no el flag.
- **No hay dirección de "nº de rondas" ni de round time.** `$F502`/
  `$F504`/`$F506` son el interpolador de scroll de cámara.

---

## 6. Las ROMs

El ROM **no se distribuye con el repo** (derechos de autor). Va en `rom/`:

| Carpeta | Qué hay |
|---|---|
| `base/` | la ROM original reparada (los 2 parches rotos del autor revertidos, checksum al día) |
| **`cambios/`** | **una ROM por cambio**, cada una con SOLO ese cambio sobre la base |
| `combinaciones/` | ROMs con varios cambios a la vez |
| `fuentes/` | los dumps de referencia (los del autor, el inglés, el Dual Language) |
| `LEEME.md` | el índice: qué hay y qué hace cada ROM |

Se construyen todas con `python herramientas\desensamblado\construir_roms.py`,
que lee `datos/recetas.json` y `datos/parches.json`, y **verifica cada ROM**
releyéndola y comprobando byte a byte los valores y el checksum.

Los grupos de parche (los "atomos") están en `datos/parches.json`. Las recetas
(los "cambios" y las "combinaciones") en `datos/recetas.json`.

### Las que hay ahora

| Fichero | Qué es |
|---|---|
| `rom/base/yuyu_makyou_base.bin` | la base limpia (SHA1 `BE4461EBA61F3999`) |
| `rom/cambios/*.bin` | **una por cambio**, con solo ese cambio. El indice esta en `rom/LEEME.md` |
| `rom/combinaciones/yuyu_makyou_TODO.bin` | los 4 cambios + un solo plano |

### Las que hubo mientras (ya no están)

Se generaron una detrás de otra mientras se ajustaban los parches. **No están
en el repo**: cada una se reproduce con `patch_rom.py` y su historia está
aquí. Se listan para saber qué se probó y con qué resultado.

| Fichero (antiguo) | SHA1 (16) | Cambios | Qué hacía |
|---|---|---|---|
| `yuyu_makyou_v2_REPARADO.bin` | `BE4461EBA61F3999` | 8 | = la base (parches del usuario revertidos) |
| **`yuyu_makyou_v3_DRAGON.bin`** | `1D2493525A1BED12` | 13 | dragón de Hiei al 50 % + hitbox 68→9 |
| `yuyu_makyou_v3b_DRAGON_PARADO.bin` | `1917131B0351DEF5` | 9 | dragón al 0 % (parado) |
| `yuyu_makyou_v4_EXTRAS.bin` | `601C6EFE4F92DA7C` | 16 | 8 parches de gameplay |
| `yuyu_makyou_v5_TODOS.bin` | `ADC3E2CBBD9860A1` | 21 | fix + dragón + blob + extras |
| `yuyu_makyou_v6_SINZ80.bin` | `7C52F97315A2FCFF` | 13 | **no espera al Z80** (diagnóstico) |
| `yuyu_makyou_v7_CHECKSUM.bin` | `BE4461EBA61F3999` | 8 | idéntico a la base |
| `yuyu_makyou_v8_TODOS.bin` | `54B119FBD1E46CA5` | 20 | todos los grupos |
| `yuyu_makyou_v9_STARTUP_KAGE.bin` | `FB2531D8D003054F` | 12 | wind-up de 影手 |
| `yuyu_makyou_v10_KAGE_RAPIDO.bin` | `9F9D0CD5D9BF0AF3` | 10 | wind-up + velocidad ÷4 |
| `yuyu_makyou_v11_STARTUP_GLOBAL.bin` | `F908D0B2ACA38BCE` | 14 | wind-up + ventana de golpe |
| `yuyu_makyou_v12_TODOS.bin` | `6A87B646CE8ED1A4` | 29 | fix + dragón + 影手 + extras |
| **`yuyu_makyou_v13_KAGE_STARTUP.bin`** | `FB2531D8D003054F` | 12 | wind-up de 影手: 4+4+8+255 → 1+1+1+1 |
| **`yuyu_makyou_v14_KAGE_COMPLETO.bin`** | `F59B81C016557491` | 15 | lo anterior + ventana de golpe 255→20 + velocidad ÷4 |
| `yuyu_makyou_v15_ONDA_LENTA.bin` | `09DE02CD35E68E71` | 3 | la onda de Itsuki a media velocidad |

### Las ROMs del autor

Estaban en `Downloads` y en la carpeta del proyecto viejo. **No** estaban en
el manifiesto. Son la fuente de tres de los cuatro cambios unificados. Ahora
están en `rom/fuentes/`, con nombres sin espacios:

| Fichero | SHA1 (16) | Cambios | Qué hace |
|---|---|---|---|
| `rom/fuentes/usuario_HIEI_DRAGON_LENTO_ROTO.bin` | `810BAA877AE48D6B` | 8 | los 2 parches ROTOS (goteo de maná anulado + dragón que no salía) |
| `rom/fuentes/usuario_ROMA_MODIFICAR.bin` | `5B24D14A2F0543D1` | 63 | **fix del doble salto** + 2 cosas rotas (ver §8) |
| `rom/fuentes/usuario_HIEI_v3_ITSUKI_KAGE_14f-7f.bin` | `5E9D406B83846976` | 67 | 影手 de Itsuki por las duraciones MEDIDAS + refactor del proyectil |
| `rom/fuentes/yuyu_makyou_ingles.bin` | `D881629AF139EDB6` | — | la traducción inglesa (base del parche de la planta) |
| `rom/fuentes/yuyu_makyou_dual_language.bin` | — | — | el dump "Dual Language" de MIJET |

### Grupos del parcheador

| Grupo | Qué hace | Bytes |
|---|---|---|
| `fix` | Revierte los 2 parches del usuario | 6 |
| `dragon` | Ralentiza el dragón de Hiei (b6 de los frames con hitbox) | 1 |
| `dragon_vel` | Velocidad 16.16 del proyectil del dragón (tabla `$90`) | 3 |
| `blob` | Estrecha la hitbox del dragón (radioX 68 → 9) | 2 |
| `extras` | slow-mo, combo, hitstun, muerte, empuje | 8 |
| **`kage_startup`** | wind-up de 影手 a 1 tick por frame | 4 |
| **`kage_hitdur`** | ventana de golpe de cada mano: 255 → 20 ticks | 2 |
| **`kage_vel`** | el desplazamiento en 影手: ÷2 → ÷4 | 1 |
| **`kage_dur`** | **duraciones MEDIDAS de 影手**: los IDs 166/167 del personaje a 0 ticks | 4 |
| **`kage_proj`** | refactor del camino de creación del proyectil (experimental) | 57 |
| **`doble_salto`** | **fix del doble salto**: la rutina de reset limpia `$87(a5)` | 18 |
| **`kurama_planta`** | hitbox de la planta de Kurama: radioX 60 → 9 | 1 |
| `sinz80` | El juego deja de esperar al Z80 (diagnóstico) | 5 |
| — | **el checksum de la cabecera se reescribe SIEMPRE al final** | 2 |

### Checksum de la cabecera

El checksum Sega (a `0x18E`) es la suma de todas las palabras de 16 bits
del ROM desde `0x200`. El grupo `checksum` lo reescribe para que cuadre
con el contenido. En este juego el checksum está obsoleto en todos los
dumps conocidos, así que **no cuadrar no significa que el ROM esté roto**:
es un indicador, no un veredicto. `herramientas/desensambladocheck_checksum.py` lo
informa sin escribir nada.

> Dato: el ROM que tenías tiene el checksum **almacenado** `$34AE` y el
> **calculado** `$337B` (difieren en `$133`), y el proyecto documenta
> `$4A36` en los 8 dumps conocidos. O sea que tu dump **no es ninguno de
> los 8**. En las zonas verificables (código, moves, driver Z80, vectores,
> cabecera) es idéntico, pero hay una diferencia en los datos que no
> podemos comprobar (gráficos y sonido) que podría venir de ese dump.

## 7. Herramientas nuevas en `herramientas/desensamblado`

| Fichero | Qué hace |
|---|---|
| `patch_rom.py` | parcheador verificado con manifiesto |
| `blob_dump.py` | vuelca los blobs de un personaje: daño, stun, empuje, radios |
| `blob_chain.py` | vuelca la cadena de cajas de un move, frame a frame |
| `ctx_hiei.py` | grafo de llamadores de una dirección, con contexto |
| **`probar_codigo.py`** | **ejecuta un fragmento de codigo 68000 con Unicorn** (con la RAM del juego) y dice lo que ha hecho: sirve para verificar un parche SIN el emulador |

---

# 8. LA UNIFICACIÓN (20-10-2026)

Los cambios se hicieron en ROMs distintas, en tres carpetas (el repo, `Downloads`
y las generadas por el parcheador). Esta sección es el mapa final.

## 8.1 Los cuatro cambios y de dónde sale cada uno

| Cambio | Bytes | De qué ROM salió |
|---|---|---|
| **Habilidad de Hiei** (dragón) | `$0C8168` 82→81 · `$012585` 01→00 · `$012586` C0→E0 · `$0C99AE` 44→09 · `$0C99B6` 44→09 | `v3_DRAGON` / `v5` / `v8` / `v12` |
| **Manos de Itsuki** (影手) | `$0D053A` `$0D0542` `$0D054A` 04→00 · `$0D0552` 02→00 · `$018809` 80→40 · `$01FD0D` FF→FE · `$01FD59` 01→00 | `ROM A MODIFICAR - HIEI v3 + ITSUKI KAGE 14f-7f.md` (durations) + `v10`/`v14`/`v15` (velocidades) |
| **Fix del doble salto** | `$015D03` 54→56 · `$015D17` 54→56 · `$018443`–`$018457` (16 bytes) | `ROM A MODIFICAR.md` |
| **Planta de Kurama** | `$0D9C69` 29→28 | el objetivo: estado `$30` (elevación recta, 430 f, con ventana). Ver §8.4 |

## 8.2 `$87(a5)` = EL CONTADOR DE SALTOS

Esto es lo que hace que el parche del "doble salto" sea lo que es:

| Dirección | Instrucción | Qué hace |
|---|---|---|
| `$0x15E28` | `cmpi.b #$0, $87(a5)` / `bne.w $15ed8` | **el test**: si `$87` no es 0, NO se permite otro salto |
| `$0x1863A` | `addq.b #$1, $87(a5)` | cuenta un salto |
| `$0x1B2C8` | `addq.b #$1, $87(a5)` → `bsr.w $1860C` | el salto: cuenta y arranca el estado de salto |
| `$0x1860C` | `clr.b $87(a5)` | se limpia al arrancar el salto |
| `$0x1B66E`, `$0x1BAF6`, `$0x19E00` | `clr.b $87(a5)` | se limpia en otras transiciones |
| **`$0x18440`** | **la rutina de reset** | **NO lo limpiaba** ← el bug |

La rutina de reset de `$0x18440` (la que pone `$5F = 0`) es la que el ROM
`ROM A MODIFICAR.md` reescribe para que **también** haga `clr.b $87(a5)`.
Como la rutina crece 2 bytes, los dos `jsr $18454.l` de `$0x15CFE` y `$0x15D12`
pasan a `jsr $18456.l`. **Los 18 bytes van juntos: tocar uno sin el otro deja el
código saltando a media instrucción.**

## 8.3 Lo que NO se unificó, y por qué

| Cambio | Dónde | Por qué se excludes |
|---|---|---|
| Goteo de maná anulado (`$01A4EA`–`$01A4ED` → NOP) | `ROM A MODIFICAR - HIEI v3...`, y el `ROM A MODIFICAR - HIEI DRAGON LENTO v1 NO SIRVE` | **bug conocido**: el personaje deja de gastar maná con el tiempo. El grupo `fix` lo revierte |
| `$021A08`–`$021A30` rellenos con `$FF` | `ROM A MODIFICAR.md` | destruye la rutina que hace el `jmp $1A430` (creación de proyectil). Es la misma clase de error que el parche B roto |
| `$01C3BA` → `bra.w $21A08` **sin** reescribir `$21A08` | `ROM A MODIFICAR.md` | el destino está rellenado con `$FF`: salto a basura |
| `$0C95C9` 19→15 ($68 del blob `$0C95C6`) | `ROM A MODIFICAR.md` | dirección opuesta a la del ROM de Itsuki (`$0C95AD` 15→19). No se sabe cuál es el bueno |
| `sinz80` | `v6` / `v8` | es un parche de diagnóstico, no un cambio de gameplay |
| `extras` (8 bytes de gameplay) | `v4` / `v5` / `v8` / `v12` | no estaba en la lista de los 4 cambios. Se añade con `extras` en la línea de comandos |

## 8.4 La PLANTA DE KURAMA: el byte y sus dos ROMs

**No es un golpe de Kurama.** Kurama lo *invoca* (con el move `$A3`), pero **los
golpes salen de un objeto**: el motor copia el blob del golpe a la RAM del
objeto en `$01EC0E`–`$01EC2C`. Ese blob se localizó por la firma de 3 bytes
`$65 $66 $64`:

| Golpe | Blob | `$65` daño | `$66` stun | `$64` empuje | byte de estado |
|---|---|---|---|---|---|
| 1º | `$0D9CFA` | 8 | 4 | `$1E` | `$0D9CFD` |
| 2º | `$0D9C66` | 16 | 10 | `$1E` | **`$0D9C69`** |

> **Ojo: la firma NO es única.** `$65=$10 $66=$0A $64=$1E` aparece **3 veces** en
> 3 MB: en `$0C3AF2`, `$0C3B0A` y `$0D9C66`. Las dos primeras tienen `$68 = 0`
> (hitstun normal, 22 frames), que no es una caída. La de la planta es la
> tercera. La búsqueda original se hizo sobre el ROM **inglés**.

El **4º byte** de la cabecera del blob guarda **dos nibbles**: el **alto es
`$67`** y el **bajo es `$68`**. Y `$68` es el **estado de derribo** en el que
queda el rival.

### La tabla de `$68` (de las notas, `HIT STATE.txt`)

| `$68` | Estado | Frames | Qué es |
|---|---|---|---|
| 0 | `$20` | 22 | hitstun normal |
| 1 | `$21` | 102 | hitstun normal, variante |
| 2 | `$20` | 18 | chip |
| 3 | `$21` | 98 | chip, variante |
| 4 | `$23` | **164** | derribo ciego |
| 5 | `$25` | **290** | derribo **con ventana** |
| 6 | `$26` | **516** | lanzador (el rival sale volando) |
| 7 | `$27` | **390** | alto fijo, sin velocidad |
| **8** | **`$30`** | **430** | **elevación recta** (tiro vertical), **con ventana de frames** |
| 9 | `$2F` | **334** | empuje diagonal (los agarres) |

### Qué hay en cada ROM

| ROM | 1º golpe | 2º golpe | Frames |
|---|---|---|---|
| **Japonés** (la de este proyecto) | `$68=5` → `$25` | **`$68=9` → `$2F`** | 334 |
| **Inglés** | `$68=5` → `$25` | `$68=5` → `$25` | 290 |
| Japonés + parche entregado | `$68=5` | `$68=4` → `$23` | **164** |

### Lo que se aplica, y el error que se cometió

**El objetivo: `$68 = 8` → estado `$30` = elevación recta**, 430 frames, con la
ventana de frames activada hasta la caída al suelo. Así el rival **cae de otra
forma** y queda **mucho más tiempo para conectar**.

> **El error**: el parche que había entregado (`$0D9C69: $25 → $24`) deja el 2º
> golpe en **derribo ciego, 164 frames** — la mitad de frames que da el
> derribo con ventana, y un tercio de la elevación recta. Se aplicó sobre el
> ROM **japonés**, donde el byte de partida es `$29` (`$68 = 9`, 334 frames),
> así que el resultado final fue `$29 → $24`: **de 334 frames a 164**.

Los grupos del manifiesto:

| Grupo | Byte | Estado | Frames | Cuándo |
|---|---|---|---|---|
| **`kurama_planta`** | `$0D9C69` `$29` → **`$28`** | `$30` elevación recta | **430** | **el que se quiere** |
| `kurama_ventana` | `$0D9C69` `$29` → `$25` | `$25` derribo con ventana | 290 | como el ROM inglés |
| `kurama_ciego` | `$0D9C69` `$29` → `$24` | `$23` derribo ciego | 164 | el parche que se había entregado |

**El 1º golpe NO se toca** (`$0D9CFD`).

> ⚠️ **Antecedente**: con `$68 = 8` el juego **se colgó una vez** (HANGUP 68000)
> y no se sabe por qué (commit 163 de las notas). El estado `$30` lo usan
> Itsuki y Sensui, así que **no es un estado roto**: lo que no se explica es el
> cuelgue. Por eso hay tres variantes: para probar cuál funciona.

> La nota de las notas ("las direcciones coinciden con la japonesa; la
> traducción solo tocó texto") **no se cumple en este byte**: entre el ROM
> japonés y el inglés hay **113.280 bytes** distintos en 124 bloques.

## 8.4.bis Lo que NO es la planta

El ctx0 (Kurama) tiene un move con una hitbox plana de **60 px** (move 172,
frame 15, blob `$0C106E`, radioX 60 / radioY 1). **No es la planta**: es un
move de Kurama, y el radio vive en `$0C1072`. La planta es lo de arriba.

## 8.5 Cómo se construyen

```powershell
cd "...\yuyu-limpio"
python herramientas/desensamblado\patch_rom.py `
    "rom\base\yuyu_makyou_base.bin" `
    "rom\modificadas\yuyu_makyou_UNIFICADA.bin" `
    dragon dragon_vel blob kage_dur kage_vel onda_vel doble_salto kurama_planta un_plano
```

Los otros dos valores de la planta se cambian por el grupo:

```powershell
# derribo CON VENTANA (estado $25, 290 f) en vez de elevacion recta
python _disasm_tools\patch_rom.py ... kurama_ventana
# derribo CIEGO (estado $23, 164 f): el parche que se habia entregado
python _disasm_tools\patch_rom.py ... kurama_ciego
```

El checksum se reescribe **siempre** al final. Cada byte declara su valor
esperado: si el ROM de entrada no lo tiene, el parcheador **aborta sin escribir
nada**.

| ROM | SHA1 (16) | Cambios |
|---|---|---|
| `rom/modificadas/yuyu_makyou_UNIFICADA.bin` | `4D0459F8CB420BA2` | 33 bytes |
| `rom/modificadas/yuyu_makyou_UNIFICADA_EXPERIMENTAL.bin` | (idem + `kage_proj`) | 89 bytes |
| `rom/modificadas/yuyu_makyou_UNIFICADA_VENTANA.bin` | `2DB5976139592474` | 33 bytes | la misma, con la planta en derribo **con ventana** (290 f) |
| `rom/modificadas/yuyu_makyou_UNIFICADA_CIEGO.bin` | `21A859C88FA046D0` | 33 bytes | la misma, con la planta en derribo **ciego** (164 f): el parche que se había entregado |
| `rom/modificadas/yuyu_makyou_UNIFICADA_SINCRUCE.bin` | `210025AA6D680E86` | 36 bytes | la misma, con el cruce bloqueado pero **sin** quitar el filtro de plano |

`v17` = `v16` + `kage_proj` (el refactor de `$01C3BA`/`$021A08` que hace el
usuario en su ROM más reciente). **Va aparte porque cambia qué ruta crea el
proyectil** (la de `$1A430` con sus condiciones, en vez de la inline de
`$1C3CA`), y eso no se ha medido.

---

# 9. LOS PLANOS: una sola arena

## 9.1 Qué es un "plano"

El juego tiene **dos arenas en dos planos**. El plano de cada personaje está en
**`$9c(a5)`**, un 16.16 con la Y de referencia:

| Valor | Plano | Quién |
|---|---|---|
| **320** (`$01400000`) | **delantero** | P1 (el jugador) |
| **304** (`$01300000`) | **de atrás** | P2 (el rival de la CPU) |

Y en un 1v1 **el rival arranca en el plano de atrás**: la inicialización del
slot `$8800` (`0x00AA8C` y `0x00FB1A`) pone `$9c = 304`, `$3e = $D8` (escala
216 = **se ve más pequeño**) y `$40 = $3D0` (X = 976). P1 arranca en el
delantero, con `$40 = $3B0` (X = 944).

**Por eso hay que cruzar**: el rival está en la otra arena, y ahí no te
alcanza nadie.

## 9.2 El filtro de plano

Los cuatro resolvers comparan el plano del atacante con el del defensor y **si
son distintos no hay golpe**:

```asm
01f252:  move.w    $9c(a3), d0      ; el plano del atacante
01f256:  cmp.w     $9c(a4), d0      ; contra el del defensor
01f25a:  bne.w     $1f50a           ; si NO son el mismo -> no hay golpe
```

Las cuatro copias están en `$01EE48`, `$01EF1E`, `$01F0BA` y `$01F252` (el
resolver hit-vs-hurt y sus ramas).

## 9.3 El cruce

El cambio de plano es el move **`$0F`** (C+arriba; el botón Y de Sega hace lo
mismo). Cuando el personaje aterriza:

```asm
019e86:  cmpi.b    #$f, $5f(a5)      ; ¿es el cruce?
019e8c:  66 14              bne.b     $19ea2
019e8e:  move.l    #$1300000, $9c(a5)   ; Y = 304  -> PLANO DE ATRAS
019e96:  move.w    #$d8, $3e(a5)        ; escala mas pequena
019e9c:  move.b    #$c0, $26(a5)        ; $26 = plano B + rol
```

Y el **vuelo de vuelta** es el move `$10` (`$019EAA`: Y = 320). Hay una segunda
copia de los dos bloques en `$019F4A`–`$019F82`.

El dash es lo que dispara el cruce: en `$0186D2` se compara `$9c` con 320; si
está en el plano delantero, el dash pone `$5F = $0F` y `Y = 319` (`$01874E`),
y al aterrizar salta al plano de atrás.

## 9.4 El parche `un_plano` (7 bytes)

| Byte | De | A | Qué hace |
|---|---|---|---|
| `$019E8C` | `66` (bne.b) | `60` (bra.b) | el cruce ya no lleva al plano de atrás |
| `$019F50` | `66` (bne.b) | `60` (bra.b) | ídem (la segunda copia) |
| `$018751` | `3F` | `40` | el dash deja `$9c = 320` y no 319 (un "plano" fantasma) |
| `$01EE48` | `30` | `32` | filtro 1: `move.w $9c(a3),d0` → `move.w $9c(a4),d0` |
| `$01EF1E` | `30` | `32` | filtro 2 |
| `$01F0BA` | `30` | `32` | filtro 3 |
| `$01F252` | `30` | `32` | filtro 4 (hit vs hurt) |

Los dos primeros: `bne.b $19ea2` → `bra.b $19ea2`. **El destino no cambia**,
así que el desplazamiento sigue valiendo: el bloque del cruce se salta siempre.

Los cuatro últimos: el atacante se compara **consigo mismo**, así que la
comprobación de "distinto plano" nunca salta. Con eso el rival, que está en el
plano de atrás, **se puede golpear sin cruzar**.

**Resultado: el juego se comporta como si hubiera un solo plano.** El rival
sigue viéndose en su arena (más pequeño) y su posición, pero ya no es una zona
intocable.

> El grupo `sin_cruce` (3 bytes) es la variante mínima: solo bloquea el cruce y
> **no** toca los filtros. Con ella el rival de atrás sigue siendo
> intocable, porque para Reacharlo hay que cruzar.

**Nota**: si lo que se quiere es además que el rival **nazca en el plano
delantero** (y con su tamaño normal), hay que tocar las 4 inicializaciones a
304 (`$00AA8C`, `$00AB0C`, `$00FB1A`, `$00FBA0`) y sus escalas `$D8` → `$100`.
Eso no se ha hecho: es un cambio de diseño del escenario, no una desactivación.

---

# 11. EL TELEPORT DE ITSUKI, UN 40% MAS RAPIDO

**La tecnica es el estado `$A4` de la tabla de Itsuki**, y su duracion se
controla frame a frame en el propio bloque de la tabla.

| Dato | Valor |
|---|---|
| Personaje | Itsuki = **ctx6**, tabla base `$0CF99A` |
| Estado | **`$A4`** (el "teleport en curso", MEDIDO) |
| Bloque de frames | **`$0D044A`** |
| Frames | 14 |
| Duracion total | **37 ticks** |
| Patron | anims 57, 58, 59 y luego visible/invisible alternando (el parpadeo) |

El byte **+0** de cada registro de 8 bytes es la **duracion del frame**: la
copia a `$5A` esta en `$01EB5A`. Es el mismo byte que ya usa el grupo
`kage_dur`.

| Byte | De | A | Frame |
|---|---|---|---|
| `$0D044A` | `06` | `03` | 0 |
| `$0D0452` | `06` | `03` | 1 |
| `$0D045A` | `04` | `02` | 2 |
| `$0D046A` | `04` | `02` | 4 |
| `$0D047A` | `02` | `01` | 6 |
| `$0D0492` | `02` | `01` | 9 |
| `$0D04A2` | `03` | `02` | 11 |
| `$0D04B2` | `04` | `02` | 13 |

**37 ticks -> 22 ticks: un 40,5% menos de tiempo.**

**Como se llega al 40%:** hay **6 frames de 1 tick** que ya estan en el minimo
y no se pueden bajar. Escalar cada duracion por 0,60 da 24 ticks (35% menos),
o sea que el minimo se come parte del descuento. Para llegar al 40% el resto se
redistribuye quitandolo de los frames mas largos (los dos de 6 y el de 4).

El parpadeo (el patron visible/invisible) se mantiene: solo se acorta.

**Ojo:** el teleport es la unica tecnica que usa el estado `$A4` **en la tabla
de Itsuki**. Los demas personajes tienen su propio `$A4` con otro contenido
(Hiei 6 frames, Kurama 7, Yusuke 9, Chui 5, ...), y NO se tocan: el parche es
solo sobre los bytes de `$0D044A`, que son los de ctx6.


## 12. EL TELEPORT DE ITSUKI: QUE TERMINE EN EL SUELO

**Receta:** `14_itsuki_teleport_pisa_el_suelo`. **Grupo:** `itsuki_teleport_suelo`.
**1 byte** en `$019061`. **Aceptado** en la unificada.

### Lo que se ve

Al terminar el teleport, Itsuki **sale disparado al aire**: la Y sube de 320
a 240 (**80 px**) y tarda **70 frames** en volver al suelo.

### Lo medido (sonda `herramientas/lua/sonda_teleport.lua`)

| frame | estado | mundo X | mundo Y | suelo `$9C` | pantalla |
|---|---|---|---|---|---|
| 58761-58797 | `$A4` (blink) | 895 | **320** | 320 | 279,315 |
| 58798 | `$A5` (colocación) | 896 | **320** | 320 | 279,315 |
| 58799 | `$A5` | **1048** (zona) | **320** | 320 | 432,315 |
| 58836-58905 | **`$25`** | 1048 → 1127 | **320 → 240 → 320** | 320 | 315 → 242 → 316 |

**La Y del ancla SIEMPRE es 320 = el suelo.** El teleport **sí** coloca al
personaje en el suelo (Y = `$9C`) y en la zona correcta (X 895 → 1048, que
es la zona C: pantalla 432, una de las tres medidas).

Lo que lo manda al aire es **otro estado**: `$25`, un **salto de 80 px** con
vy = −6 px/frame que empieza **1 frame después** de acabar la colocación.

### De donde sale ese salto

`$5D` es el **estado siguiente** (lo lee el dispatcher en `$015A5A`). El
**único** sitio de todo el ROM que pone `$5D = $25` (el salto) es:

```
01904e:  30 3c 00 08        move.w    #$8, d0      ; 8 de mana
019052:  61 00 0b f2        bsr.w     $19c46
019056:  0c 00 00 00        cmpi.b    #$0, d0
01905a:  67 00 0b e8        beq.w     $19c44
01905e:  1b 7c 00 25 00 5d  move.b    #$25, $5d(a5)   <-- EL SALTO
019064:  1b 7c 00 a0 00 5f  move.b    #$a0, $5f(a5)   ; estado $A0
```

Es el **DASH** de Itsuki (8 de maná, "arriba"). El comando del teleport es
**abajo+arriba+A/B/C**, así que el "arriba" del comando dispara el dash al
terminar el teleport, y el dash se lleva al personaje 80 px por los aires.

Y el estado `$25` de ctx6 es un salto de verdad: su bloque de frames está en
`$0CFE4A` (4 frames, durs 4, 4, 8, **255** = espera en el aire).

### El cambio

**1 byte**, en `$019061`:

| Byte | De | A |
|---|---|---|
| `$019061` | `25` | `03` |

`$5D = $25` (salto) -> `$5D = $03`. El handler de `$03` es `$019F90`, que
acaba en `$18440` = **estado `$00`, el reposo, con el personaje en el suelo**.

Mismo tamaño, no se desplaza ningún byte, no hay que recalcular saltos.

### Nota importante (por qué el primer intento no funcionó)

Un parche anterior (commit `fc5e776`) ponía `move.l $9c(a5), $44(a5)` en
`$01926A`. **Esa no es la ruta del teleport de Itsuki**: `$01926A` es la
routine "pasa a `$A5` sin colocar nada" y **no cambia nada visible** (el
teleport ya ponía la Y en el suelo en `$01BE26`). El parche se ha sustituido
por el de `$019061`, que es el que va al nudo.

### Comprobacion

Verificador de desensamblado: **OK**. La unificada queda en **58 bytes**,
checksum **`$F1B3`**.


## 13. LA FASE DE COLOCACION DEL TELEPORT: 45 -> 25 TICKS

**Receta:** `15_itsuki_teleport_colocacion_rapida`. **Grupo:**
`itsuki_teleport_colocacion`. **9 bytes** en `$0D04C2`-`$0D0532`.
**Aceptado** en la unificada.

### Que es

El teleport de Itsuki tiene 3 fases:

| Fase | Estado | Bloque de frames | Ticks |
|---|---|---|---|
| 1. el blink | `$A4` | `$0D044A` | 37 -> **22** (receta `13`) |
| 2. **la colocacion** | **`$A5`** | **`$0D04BA`** | **45 -> 25** (esta receta) |
| 3. el "aire" | `$25` | `$0CFE4A` | (fuera con la receta `14`) |

Esta receta acorta la **fase 2**: el parpadeo final (13 frames, anim 59
visible / anim 0 invisible) y la animacion de aterrizaje (3 frames, anims
146, 145 y 14).

### El reparto

Los 16 registros de 8 bytes del bloque, con byte+0 = duracion:

| frame | dur viejo | dur nuevo | anim | |
|---|---|---|---|---|
| f0 | 1 | 1 | 59 | visible |
| f1 | 4 | **2** | 0 | invisible |
| f2 | 1 | 1 | 59 | visible |
| f3 | 3 | **1** | 0 | invisible |
| f4 | 1 | 1 | 59 | visible |
| f5 | 2 | **1** | 0 | invisible |
| f6 | 1 | 1 | 59 | visible |
| f7 | 1 | 1 | 0 | invisible |
| f8 | 2 | **1** | 59 | visible |
| f9 | 1 | 1 | 0 | invisible |
| f10 | 3 | **1** | 59 | visible |
| f11 | 1 | 1 | 0 | invisible |
| f12 | 4 | **2** | 59 | visible |
| f13 | 6 | **3** | 146 | el aterrizaje |
| f14 | 6 | **3** | 145 | el aterrizaje |
| f15 | 8 | **4** | 14 | el aterrizaje |
| | **45** | **25** | | |

- el **parpadeo**: 25 -> 15 ticks (once frames de 1 tick, f1 y f12 de 2)
- el **aterrizaje**: 20 -> 10 ticks (la mitad)

Es el **mismo criterio** que el parche del blink (receta `13`): minimo de
1 tick por frame y el descuento se saca de los frames mas largos.

### Los 9 bytes

| Byte | Frame | De | A |
|---|---|---|---|
| `$0D04C2` | f1 | `04` | `02` |
| `$0D04D2` | f3 | `03` | `01` |
| `$0D04E2` | f5 | `02` | `01` |
| `$0D04FA` | f8 | `02` | `01` |
| `$0D050A` | f10 | `03` | `01` |
| `$0D051A` | f12 | `04` | `02` |
| `$0D0522` | f13 | `06` | `03` |
| `$0D052A` | f14 | `06` | `03` |
| `$0D0532` | f15 | `08` | `04` |

Todos son el byte+0 (duracion) de su registro. No se toca ningun otro byte
del ROM.

### Comprobacion

Verificador de desensamblado: **OK**. En la unificada:

```
fase 1: el blink        $0D044A  14 frames  total= 22 ticks
fase 2: la colocacion   $0D04BA  16 frames  total= 25 ticks
```

Unificada: **67 bytes**, checksum **`$DDB3`**.


## 14. EL MASH PARA SACAR EL ATURDIMIENTO CUENTA x1,5

**Receta:** `16_mash_aturdimiento_x15`. **Grupo:** `mash_aturdimiento_x15`.
**2 bytes** en `$01A29A` y `$01A2A6`. **Aceptado** en la unificada.

### Que es

Cuando la barra de aturdimiento se agota el personaje **cae** (knockdown), se
levanta y queda **aturdido** unos 4 segundos. Si presionas muchas teclas
(mash) ese tiempo baja, pero hay que hacerlo Muchisimas veces: con 255
frames de aturdimiento y -2 por pulsacion hacen falta **~128 pulsaciones**.

### Donde esta

El estado `$0C` (el "aturdido" que queda tras el knockdown) tiene su
handler en **`$01A282`**:

```
$01A282  3B 7C 00 FF 00 7E   move.w   #$ff, $7e(a5)   ; aturdimiento = 255 frames
$01A288  2B 6D 00 9C 00 44   move.l   $9c(a5), $44(a5)  ; al suelo
$01A28E  53 6D 00 84         subq.w   #$1, $84(a5)    ; -1 por frame
$01A292  0C 2D 00 00 00 72   cmpi.b   #$0, $72(a5)    ; ?hay boton pulsado?
$01A298  67 10               beq.b    $1a2aa
$01A29A  55 6D 00 84         subq.w   #$2, $84(a5)    ; <-- EL MASH: -2 mas
$01A29E  0C 2D 00 C8 00 5B   cmpi.b   #$c8, $5b(a5)
$01A2A4  62 04               bhi.b    $1a2aa
$01A2A6  54 2D 00 5B         addq.b   #$2, $5b(a5)   ; <-- +2 ticks al frame
$01A2AA  0C 6D 00 01 00 84   cmpi.w   #$1, $84(a5)   ; ?llegó a <=1?
$01A2B0  6D 04               blt.b    $1a2b6          ; si -> se levanta
$01A2B6  42 6D 00 84         clr.w    $84(a5)
$01A2BA  61 00 E1 84         bsr.w    $18440          ; -> estado $00 (reposo)
```

`$84` es el contador real de aturdimiento. `$7E` (la barra) se pone a 255 al
entrar y la baja el dano de los golpes (`$01F42C`).

### El cambio

**2 bytes.** OJO: el dato de `SUBQ`/`ADDQ` va **en los bits 11-9 del opcode**,
no en un byte aparte (`$53` = 1, `$55` = 2, `$57` = 3, `$59` = 4), asi que lo
que cambia es el primer byte de cada instruccion.

| Byte | De | A | |
|---|---|---|---|
| `$01A29A` | `55` | `57` | `subq.w #$2` -> `subq.w #$3`: cada tecla mashada baja **3** frames el contador en vez de 2 |
| `$01A2A6` | `54` | `56` | `addq.b #$2` -> `addq.b #$3`: cada tecla mashada alarga **3** ticks el frame en vez de 2 |

**=> el mash cuenta x1,5.** Con 255 frames hacen falta **~85 pulsaciones**
en vez de ~128.

### Alcance

El estado `$0C` es **generico** (es el mismo para los 11 personajes) y el
mash es **UNO solo en todo el ROM** (el grep del EA `6D 00 84` solo devuelve
los tres sitios de esta rutina). As que el cambio afecta a todos.

### Comprobacion

Verificador de desensamblado: **OK** (solo cambian los operandos). La
unificada queda en **69 bytes**, checksum **`$E1B3`**.


## 15. REVERTIDO: `rival_delante` (el rival en el plano delantero)

**Este cambio ya NO se aplica.** La receta `09_rival_nace_delante` y el
grupo `rival_delante` se han quitado del manifiesto; la ROM unificada
vuelve al comportamiento original del ROM.

### Que hacia

El rival de la CPU arranca en el **plano de atras** y **mas pequeno** que el
jugador. Eso se decide en **cuatro inicializaciones** (dos del jugador y dos
del rival, mas sus copias):

| Direccion | Instruccion | Original | Con el parche |
|---|---|---|---|
| `$00AA8C` | `move.l #$1300000, $9c(a0)` | 304 (atras) | 320 (delantero) |
| `$00AA94` | `move.w #$d8, $3e(a0)` | escala 216 | escala 256 |
| `$00AB0C` | `move.l #$1300000, $9c(a0)` | 304 | 320 |
| `$00AB14` | `move.w #$d8, $3e(a0)` | 216 | 256 |
| `$00FB1A` | `move.l #$1300000, $9c(a0)` | 304 | 320 |
| `$00FB22` | `move.w #$d8, $3e(a0)` | 216 | 256 |
| `$00FBA0` | `move.l #$1300000, $9c(a0)` | 304 | 320 |
| `$00FBA8` | `move.w #$d8, $3e(a0)` | 216 | 256 |

Los 8 bytes que se tocaban eran: `$00AA8F` (`30`->`40`), `$00AA96`
(`00`->`01`), `$00AB0F`, `$00AB16`, `$00FB1D`, `$00FB24`, `$00FBA3`,
`$00FBAA`.

### Por que se revirtieso

Lo pidio el usuario: el cruce de planos es parte del juego y el rival debe
nacer en su arena. El parche hacia que los dos peleadores estuvieran en la
misma arena, lo que quitaba esa mecanica.

### Que queda

El resto de los cambios de planos siguen: **`un_plano`** (la receta
`08_un_solo_plano`, que neutraliza los tres bloques que alejan al
personaje a otro plano, el dash y los 4 filtros de plano) y
**`sin_cruce`**. Esos son los que hacen que el juego no tenga dos arenas.

**OJO:** `un_plano` y `rival_delante` son cosas distintas. `un_plano` evita
que el CRUCE (C+arriba / abajo+Y) te mande a la otra arena; `rival_delante`
era solo donde nace el rival. Revertir el segundo **no** toca el primero.

## 16. `sin_atajo_cruce` (desactiva los atajos de mando del cruce)

**Receta 19** (la 18 fue la que rompio los saltos: ver MASABAJO).

**Que hace:** el boton **C** (el "atajo" de arriba+C) y el boton **Y** dejan de
lanzar su movimiento en el cruce, y el atajo **global C+B+Y** a la vez
tambien. **23 bytes. No se toca ni un solo salto.**

### Como

En el input por personaje (los **11 dispatchers**, `$016030`-`$017F8A`), el
bloque "C o Y" hace:

```
$016106  btst.b     #$4, $72(a5)    ; el boton C
$01610C  bne.w      $1886a          -> el MOVIMIENTO $84
$016110  btst.b     #$6, $72(a5)    ; el boton Y
$016116  bne.w      $18880          -> el MOVIMIENTO $86
```

### !!! EL INMEDIATO DEL 'btst': DOS BYTES, Y CUAL ES CADA !!!

```
08 2D 00 04 00 72   =   btst.b #$4, $72(a5)
    ^  ^  ^  ^  ^
    |  |  |  |  +-- el desplazamiento ($72)
    |  |  |  +----- el byte BAJO del inmediato = la MASCARA ($04 = el bit 2)
    |  |  +-------- el byte ALTO del inmediato = el NUMERO DE BIT ($00 = el bit 0)
    |  +----------- el modo/registro ($2D = (d0,An) con An=a5)
    +-------------- el opcode (BTST)
```

**La v1 de este parche cambio el byte equivocado** (el de la mascara, en
salto - 3): `$04` -> `$03` (los bits 2,1 -> el bit 0) → **el atajo paso a
mirar el boton A** y **los ataques con A y B dejaron de funcionar** ("abajo + A
o B no golpea, solo se agacha"). La mascara **NO** se toca nunca.

**El fix correcto** es cambiar **el byte ALTO** (el numero de bit, en
**salto - 4**): de `$00` (bit 0) o `$01` (bit 1) a **`$07`** (el bit 7).

**El bit 7 del campo `$72`**:
- **NO lo prueba** ninguna instruccion del juego (0 usos en todo el ROM).
- **NO lo escribe** ninguna instruccion del juego (los `move.b #imm, $72(a5)`
  usan `$00`-`$60`, nunca nada con el bit 7).

=> el `btst` es **siempre falso** => el atajo **NUNCA** se dispara, y **los
ataques con A, B y C no se tocan** (solo cambia el bit que se mira, no la
mascara).

### El mapa de los botones (deducido del codigo)

| Bit de `$72` | Boton | Para que sirve |
|---|---|---|
| 0 | **A** | ataque fuerte |
| 1 | **B** | ataque debil |
| 2 | **C** | defensa / "atajo de arriba+C" (el movimiento `$84`) |
| 3 | X | (el que se mira ahora: nunca esta a 1) |
| 4 | Y | linea |
| 5 | Z | dash |
| 6 | ? | |
| 7 | ? | **nunca se escribe ni se prueba** |

Los "atajos" del cruce son: el **movimiento `$84`** (el boton C: la mascara
`$04` = el bit 2), el **movimiento `$86`** (B+C: la mascara `$06` = los bits
1 y 2) y el **movimiento `$AA`** (el atajo global C+B+Y, en `$015DEE`).

El atajo global esta en `$015DEE`: `cmpi.b #$70, d0` / `beq.w $18764` (el
**MOVIMIENTO `$AA`**, el cambio de plano/linea). Su inmediato `$70` esta en
**`$015DF1`** y pasa a ser `$71`.

### !!! NO TOCAR LOS 22 SALTOS !!!

**Los 22 `bne.w $1886a` / `bne.w $18880` NO son el atajo**: son **el
MOVIMIENTO con C y con Y en cada direccion** (el "adelante A" usaba el
`$84`). Cambiarlos fue lo que **movio todos los golpes de todos los
personajes** (el "adelante A se hace con abajo A", "hiei salta muy poca
distancia"): al mandarlos todos al `$83` (4-8 frames) se rompian.

### LAS ROMs DE LA CHINA

La ROM china (`rom/original/...chinese.bin` = la de `temp/opencode/control.bin`)
**ya tiene el proyecto aplicado** (los mismos bytes que la unificada), asi que
le falta el grupo `un_plano` (el que desactiva el cruce de planos).

| ROM | Que es | Bytes | Checksum |
|---|---|---|---|
| `rom/cambios/19_china_sin_cruce.bin` | **la china + `un_plano` + los 23 de los atajos** | 33 | `$E651` |
| `rom/cambios/20_china_UNIFICADA.bin` | la china + todo el proyecto | 57 | `$9733` |
| `rom/cambios/19_sin_atajos_de_cruce.bin` | la base del proyecto + los 23 bytes | 23 | — |
| `rom/combinaciones/yuyu_makyou_UNIFICADA.bin` | la unificada del proyecto | 84 | `$DD4A` |
## EL VENENO DEL PLANO (grupo `veneno_plano`, 48 bytes)

**Cruzar al otro plano ENVENENA al personaje: el HP baja 1 por frame (60 por
segundo) mientras esta en el plano de atras, y deja de bajar en cuanto vuelve
al plano principal.** No es un golpe: es un veneno, el dano es continuo.

**Si se queda sin vida, MUERE en el acto**: cuando el HP llega a 0 o menos se
le escribe el **marcador de cadaver `$FC00`** (-1024) en el HP, que es como el
juego marca a un muerto y lo que hace que la **secuencia de KO arranque sola**
(el por que esta en "El final sin vida", mas abajo).

**Le afecta a cualquier personaje** (P1, P2 o el rival): el slot del P2 no
siempre es el mismo (`$FF8800` desde el select, `$FF9000` con un savestate,
stride `$C00`).

### Donde esta enganchado

La rutina **`$015BD8`** actualiza el flag del plano `$A042` **cada frame** (la
llama `$015A2E` con `bsr.w`). Mira el suelo (`$9c(a5)`):

| el suelo | que hace |
|---|---|
| **320** (`$01400000`) | el plano de **delante**: pone el bit 0 del flag |
| **304** (`$01300000`) | el plano de **atras**: pone el bit 1 del flag |

**El suelo solo vale exactamente 304 cuando el personaje esta PARADO en el
plano de atras** (durante la caida va por intermedios: 319.9, 319.6...). Por
eso el veneno **empieza al aterrizar** y **para al volver** al plano principal.

**El enganche** (6 bytes por 6, el tamano no cambia):

```asm
$015BF6  bset.b  #$1, $a042.w      ; el original: poner el bit 1 del flag
```

se sustituye por un `jsr.l` a una rutina nueva en el **hueco libre `$1A0710`**
(14 bytes) que hace lo mismo que el bset **y ademas aplica el veneno**:

```asm
$1A0710  bset.b  #$1, $a042.w      ; el flag: el plano de atras      (6)
$1A0716  jsr.l   $1A06F0           ; EL VENENO                        (6)
$1A071C  rts                                                        (2)
```

### El veneno (28 bytes en `$1A06F0`)

```asm
$1A06F0  move.l  d0, -(a7)         ; guardar d0
$1A06F2  move.w  $78(a5), d0       ; el HP
$1A06F6  bmi.b   $1A0708           ; ya muerto: NO drenar mas (el HP de un
                                   ; muerto se queda como esta, que no se
                                   ; borre el marcador $FC00)
$1A06F8  subq.w  #$1, d0           ; el veneno: HP - 1
$1A06FA  move.w  d0, $78(a5)
$1A06FE  tst.w   d0
$1A0700  bgt.b   $1A0708           ; > 0: sigue vivo
$1A0702  move.w  #$fc00, $78(a5)   ; 0 o menos: EL MARCADOR DE CADAVER
$1A0708  move.l  (a7)+, d0
$1A070A  rts
```

### El final sin vida: el marcador de cadaver `$FC00`

**La v7 dejo esto mal y no funcionaba**: dejaba el HP en -1 y esperaba que el
juego lo viera. No lo ve. **El KO del juego NO es un chequeo del HP negativo
por frame**: el HP negativo entra por un lado unico, el **resolver de dano**
(`$1F4CA`: `cmpi.w #$0, $78(a4)` → `blt` → `jsr $1FA70`, que solo enciende
la camara lenta `$F558 = 160`), y el **fin de ronda** lo manejan DOS rutinas que
escanean los slots de la RAM de trabajo (`$FF8400 + n*$400`, 4 slots, con la
firma `$00012668` en el primer longword):

| rutina | que hace | su regla |
|---|---|---|
| `$F852` | la fase de combate (`$00F476`) la consulta cada frame | saltea los slots con **HP NEGATIVO**; avanza cuando en los vivos queda **un solo `$6F`** (un solo bando) |
| `$F88C` | la fase siguiente (`$00F490`) lo consulta cada frame | saltea los slots con **HP == `$FC00` EXACTO**; avanza cuando queda un solo bando |

Con un HP negativo cualquiera (`$FFFF`, -1) `$F852` avanza pero `$F88C` lo
sigue contando como VIVO: la fase no avanza NUNCA. **Toda la ronda se
quedaba esperando a que el caido tocara el suelo para escribirle el
`$FC00`** (lo escribe `$01A1A4`, en el codigo de la caida con el bit de
signo del HP en 1: `move.w #$fc00, $78(a5)`) — y como el envenenado esta
parado, nunca toca el suelo. Ese era el colgado.

**La v8b escribe el `$FC00` directamente** en el momento en que el veneno
queda sin vida: las dos rutinas pasan al toque, la secuencia de KO arranca
(`$A032 = 1` y el contador `$A03A` en `$F49E`, el mensaje y el festejo del
ganador). Muere donde esta, parado, **sin tocar el suelo ni el estado `$5D`**.

> **EL BUG DE LA v8 (y por eso se tildaba al cruzar)**: la escritura del HP
> drenado (`move.w d0, $78(a5)`) la codifique a mano como `30 5D 00 78` — 
> que **NO es esa instruccion** (con capstone resulta ser `movea.w (a5)+, a0`):
> el stream se desincronizaba, el `a0` del frame processing quedaba pisado con
> los bytes del slot y **el juego se rompia** la primera vez que el hook
> corria con vida baja. La codificacion correcta es **`3B40 0078`** (destino:
> reg a5 en los bits 11-9 + mode `(d16,An)` en los bits 8-6; fuente `d0` en
> los bits 5-0). **Regla nueva: toda instruccion escrita a mano se valida con
> capstone ANTES de entrar al parche.**

> **Los detalles**: el HP `$FC00` (-1024) es el mismo valor que usa `$F8C8`
> para calcular el delay del mensaje de KO (saltea los `$FC00`, asi que no
> hay delay especial) y el que el propio juego pone al marcar a un muerto.
> Si el HP ya estaba negativo por un golpe, no pasa nada: el `bmi` del
> payload corta el drenaje y el `$FC00` no se pisa.

> **NO se toca el suelo.** La version 5, que ademas ponia el suelo a 320 para
> devolverle al plano principal, **ROMPIA LA PARTIDA al cruzar**. El suelo se
> queda como esta: mueren donde están.

### Las ROMs

| fichero | que es | SHA1 |
|---|---|---|
| `rom/cambios/29_china_VENENO_P1_P2_muere.bin` | la **china** + `veneno_plano` (la **v8b**, el marcador de cadaver `$FC00`, con la escritura del HP corregida) | `FE4348D17C61727F508626883DCF5CE9D9F18217` |
| `rom/cambios/30_china_VENENO_AURA_P1_P2.bin` | la **china** + `veneno_plano` + `veneno_aura` (la **v9-8**: el ROM limpio del veneno CON el aura, mas arriba) | `74791462D3E58B55678C18152D374C3E67F41B25` |
| `rom/cambios/23_china_UNIFICADA_con_VENENO.bin` | la unificada (SIN `un_plano`, para que haya dos planos) + el veneno **v8b** | `96C2771175C94C35BA7252CCE23E86E88F44F2BF` |
| `rom/cambios/28_china_VENENO_P1_P2_muere.bin` | la v7 (HP -1 + estado de reposo: **no muere, la ronda no acaba**) | `688A9A097F39780BD2390DC4EA4063162DDEE4EE` |
| `rom/cambios/27_china_VENENO_P1_P2.bin` | la v6 (el veneno sin el final sin vida) | `068F02B61D3981FCD84C718F270C75169179CF3E` |
| `rom/cambios/24_china_VENENO_P1_referencia.bin` | la **v1** (solo P1), la que se probo primero | `7385066ADA220E0CED09EDAACCC2F2C3BB2059A3` |

> **OJO: `veneno_plano` y `un_plano` son excluyentes en la practica.** Con
> `un_plano` el suelo nunca es 304 (no hay dos planos) y el veneno no se
> activa nunca. Para que el veneno funcione hace falta una ROM **con dos
> planos**.

### El camino (las versiones que hubo)

| version | que cambiba | que pasó |
|---|---|---|
| **v1** | el veneno solo para el P1 (`cmpi.w #$8400,d0`) | **funciona** |
| v2 | el HP = 0 con `cmpi.w #$0,d0` y el P2 en `$FF8800` | **se rompia al cruzar el P1**: el `cmpi.w` con un registro no compara el word como se espera y disparaba el final sin vida en cada frame. Y el P2 no suffering nada: **su slot no es `$FF8800`** |
| v4 | veneno para todos (sin comparar el slot) | se rompia: **el rival de la CPU esta en el plano de atras desde el principio** y se envenenaba solo |
| v5 | + el final sin vida (suelo a 320 y estado de reposo) | se rompia: **el suelo a 320** es lo que rompia la partida |
| v6 | el veneno de la v1 para todos los slots, sin el final sin vida | **funciona para el P1 y el P2** |
| v7 | la v6 + el estado de reposo al llegar a 0 (sin tocar el suelo) | **NO muere**: el HP queda en -1 y la ronda no acaba (el escape: el `$F88C` sigue contandolo como vivo) |
| v8 | el marcador de cadaver `$FC00` al llegar a 0 o menos | **se tildaba al cruzar**: la escritura del HP estaba mal codificada (`30 5D` no era `move.w d0,$78(a5)`) |
| v8b | el fix de la v8, PERO arreglando solo UN byte: quedo `3B 5D` = `move.w (a5)+, $78(a5)` (el puntero `a5` avanzaba 2 bytes por frame: OTRO tildo) | tildado igual |
| **v8c (esta)** | los 28 bytes regenerados COMPLETOS desde el hex final y validados con capstone EN EL MISMO script (sin editar bytes sueltos a mano) | SEA LO QUE SEA: la secuencia de KO arranca sola |

### Que esta verificado y que no

| | |
|---|---|
| el veneno (HP - 1 por frame) | **PROBADO POR EL USUARIO** (v6: le resta vida al P1 y al P2) |
| el aura v9-4 (la receta del clon `$20`, paleta 1, tabla corta) | la receta identica corre en el `sonda_efectos.lua` **aprobado por el usuario jugando**; las ROMs v9-1/v9-2 rompian al cruzar (ramas `Bcc.w` con disp 2 corto, lo demostro el bisector `31_`) y la v9-3 nacio invisible (posicion en LONG arrastraba bytes del player al record; fix v9-4 en WORD, ver abajo), **a re-test** |
| la familia de wrappers del trail `$20` (`$020202`+) y la tabla de pares en word (`$14EAC`: `$4C04 `$4D04`...) | **CODIGO** (desensamblado + captura del sonda) |
| el mecanismo del fin de ronda (`$F852` / `$F88C` / el `$FC00` de `$01A1A4`) | **CODIGO**: leido en el desensamblado de la ROM J |
| el final sin vida v8 (el marcador `$FC00`) | **PENDIENTE DE PROBAR EN JUEGO** (la v7 con HP -1 + reposo no moria) |
| el resto | el verificador de desensamblado: **OK** |

### Si el veneno es muy rapido

Son 60 de vida por segundo (el HP maximo es 223 ⇒ ~3,7 segundos en el plano
de atras). Para hacerlo mas lento, la rutina del veneno (`$1A06F0`) es la que
quita el 1: se puede cambiar por un "1 cada 2 frames" (un contador) o por
quitar menos vida.

## EL AURA DEL VENENO (grupo `veneno_aura`, 202 bytes)

**La v9-2: mientras el personaje esta PARADO en el plano envenenado (veneno
activo), empieza a brillar con el aura del turbo de Genkai.** Es el efecto
`$20` (la estela del turbo, el handler `$149AC`) clonado sobre el jugador
con la **paleta 1** — la misma receta que se probo a ojo en el sonda
(`sonda_efectos.lua`) y que el usuario aprobo jugando. El aura dura **mientras
esta el jugador en el plano**: la rutina es la misma del hook del veneno, si
no esta parado ahi no corre, y el clon que ya salio muere solo (la ventana
25%-75%, al estilo del trail real).

Historia del fix v9-3 (ver `SESIONES.md`, S-2024-10-22l y S-2024-10-23): las
versiones v9-1/v9-2 rompian al cruzar, y el ROM bisector `31_` (sin spawn)
rompio IGUAL: el culpable eran los **tres `Bcc.w` de la rutina con el
desplazamiento 2 bytes corto**. La regla 68k, demostrada contra el propio
juego, es que el desplazamiento de todo salto con disp word (`Bcc.w`,
`BSR.w` y tambien `DBcc`) es **relativo a la direccion del word del disp**
(`addr+2`), no al fin de la instruccion (`addr+4`). La prueba gorda: el
`bsr.w` del juego en `$1FFA0` apunta a `$1FA96` solo con esa base
(`$1FFA0 + 2 + FAF4 = $1FA96`; con `addr+4` da `$1FFA98` = la mitad de la
instruccion). El caso del `dbra` mal (`FFFC`) era lo mismo (la misma regla
valia), PERO el peso del apagon lo cargaban los tres `Bcc.w`: el
`ble.w` con disp `$A0` caia en `$1A07E0` = la mitad de la instruccion
`move.l $44(a5), $44(a0)` del epilogo: se ejecutaba un `ori` basura que
hacia 3 pops en vez de 4, devolvia `d0` corrompido y el `rts` saltaba al
pool = el flujo moria en el PRIMER frame con `$9C(a5) = 304` = negro justo
al cruzar, con o sin spawn. Fix: disp `A2/98/84`, mismos targets
(`$1A07E2`), 3 bytes.

Queda reparado de la v9-2 el NULL-check: era `tst.l (a0)`, que con
`a0 = NULL` lee la ROM en `$000000` (el SSP del header, != 0) y NO
detectaba el pool lleno (el record se escribia encima de la tabla de
vectores); ahora es `cmpa.w #$0, a0`, el mismo patron que el juego usa
despues del `bsr $1fa96` en `$1FAF2`.

### El router v9 (`$1A071C`, 8 bytes)

El `rts` del router v8c pasa a llamar a la rutina del aura:

```asm
$1A071C  jsr.l   $1A0730           ; EL AURA                           (6)
$1A0722  rts                                                        (2)
```

### La rutina del aura (`$1A0730`, 80 bytes, v9-8)

```asm
$1A0730  move.l  d0, -(a7)         ; guardar d0/d1/a0/a1
$1A0732  move.l  d1, -(a7)         ; (el allocator del wrapper pisa d1)
$1A0734  move.l  a0, -(a7)
$1A0736  move.l  a1, -(a7)
$1A0738  move.w  $78(a5), d0       ; el HP
$1A073C  tst.w   d0
$1A073E  ble.w   $1A0776           ; <= 0 (cadaver $FC00): NO clonar
$1A0742  move.l  a5, d0            ; cadencia POR JUGADOR: P1 = $FF8400
$1A0744  btst.b  #$b, d0           ; ($8400, bit 11 = 0) vs P2 = $FF8800
$1A0748  bne.w   $1A075A           ; ($8800, bit 11 = 1)
$1A074C  addi.b  #$20, $a042.w     ; P1: su contador en los bits 5-7
$1A0752  bcc.w   $1A0776           ; (el juego solo usa bits 0/1 y el
$1A0756  bra.w   $1A0764           ; clr.b de fin de ronda los limpia)
$1A075A  addi.b  #$20, $a043.w     ; P2: su contador en el byte libre
$1A0760  bcc.w   $1A0776           ; $A043 (nadie lo referencia)
$1A0764  jsr.l   $020202           ; EL WRAPPER REAL del trail (el
$1A076A  andi.w  #$8fff, $24(a0)   ; mismo del dash: allocator + los
$1A0770  ori.w   #$2000, $24(a0)   ; campos del player) + paleta 1
$1A0776  movea.l (a7)+, a1         ; restaurar y volver
$1A0778  movea.l (a7)+, a0
$1A077A  move.l  (a7)+, d1
$1A077C  move.l  (a7)+, d0
$1A077E  rts
```

**El handler `$149AC` decodificado (S-2024-10-23 addendum)**: no estaba en
el listing del juego (hueco entre los bloques #810 y #811). Es el
INICIALIZADOR de nacimiento del record + el dispatcher de la familia:

- `move.w $6(a5), d0` + `bne $14A4A`: si `$6 != 0` ya nacio (va derecho al
  runner). Si `$6 == 0` = RECIEN NACIDO: `$6 += 2`, `$24 |= $A03E` (la
  mascara global de paleta/prioridad), limpia `$28/$2A/$2C-$38`, y el
  PROPIO JUEGO escribe `$59=$ff`, `$5b=$01`, `$5c=$00` = el estado
  nacimiento ORIGINAL: por eso mi record con `$6=0` va por el camino
  natural (la plantilla FIJA tenia `$6=$0002` POR CAPTURA y los clones
  del sonda SE SALTEABAN este init!). Despues salta por `$58` (ID) a la
  tabla `$14A00+$58*2`: el `$20` va a `$14D30`.
- El runner (continuacion `$14A4A`): dos compuertas globales
  (`tst.b $F550` + `cmpi.b #0,$F55A`), despues el ancla `tst.b $5A` (si
  `$5A != 0` = congelado: lo decrementa una vez por frame y no avanza =
  el byren de los clones del sonda con `$5A` pisado), y si `$5A == 0`:
  `subq.b #1, $5b` y al llegar a 0 hace **`$59++`** y busca el par en la
  tabla de `$50(a5)` con indice `$59` (`move.b (a0,d0.w), d1` = byte
  ingenio de la maestra; `lsl #1` -> `$3c` = offset en la tabla maestra
  `$27F618`; el byte siguiente = la nueva dur `$5b`). Si la dur sale 0 =
  TERMINADOR (`jmp $3556` = despedir).
- CON Eso queda demostrado: mi `$59=$ff` de nacimiento es el CENTINELA
  REAL (el init lo escribe el juego): en el primer tic del runner el
  `FF++ = $00` cae en la pisada 0 de la tabla corta (par 77, dur 4),
  luego par 78, y el par 2 = `[0,0]` = muere limpio. Ventana 25%-75%,
  8 frames = lo aprobado.
- Posicion: con `$48 == 0` el record es ESTATICO y cada frame hace
  `add.l` de `$10(a5)` (X) y `$14(a5)` (Y) sobre `$40/$44`; si `$48` trae
  un word de SLOT (`movea.w $48, a0`) copia la posicion de ESE slot
  (follow-the-leader). Despues `jsr $156F0` = el que manda a dibujar.
- **La aguja del v9-5**: los wrappers del ID `$20` (familia `$020202`)
  copian el Y del record desde `$9C(a5)` EN LONG, no del `$44(a5)` del
  player (y la escala `move.w $3e(a5)`, y el byte de plano
  `move.b $26(a5) − 4`). El `$44` del player = espacio MECANICO; el
  `$9C` = espacio de RENDER del plano actual. En la arena normal ambos
  cuadran (por eso la receta del sonda andaba ahi), pero al cruzar al
  plano 304 se separan y el clon nacio con un Y fuera del espacio de
  dibujo = vivo pero invisible. Ademas, el init del ID `$20`
  (`$14D30`) REESCRIBE `$50 = $14eac` (la tabla real): los pares del
  clon despues del init caminan 76-79 de la tabla verdadera, no mi
  tabla corta (que queda como patrimonio muerto en `$1A07EE`).
- **La aguja del v9-6**: la v9-5 con el Y solo SIGUIO invisible =>
  el resto del wrapper importaba. Ahora la rutina replica el wrapper
  `$020202` COMPLETO: la escala `move.w $3e(a5) -> $3e(a0)` (yo ponia
  `$0100` fijo) y el binding de plano `move.b $26(a5) -> $26(a0)` +
  `subq.b #4` (yo ponia `$10` fijo, el byte de la arena normal: si el
  plano 304 usa otro id, el record nacia en una banda de depth que no
  se dibuja donde estaba el jugador). El `$24` tambien va como el
  wrapper (byte del player + `andi #$8000` + `ori #$40` = la rama con
  `$61=0`, la que reconstruye el `$C1A6` de la captura FIJA) y ENCIMA
  se fuerza paleta 1 con `andi #$8fff` + `ori #$2000` (la customizacion
  la customizacion del look aprobado). Cada campo a la vez: si el v9-6 se
  ve, queda demostrado que el binding era uno de los tres. EL v9-6 TAMBIEN
  NACIO INVISIBLE => los tres campos tampoco eran.
- **La aguja del v9-7 (VALIDADA EN JUEGO por el usuario)**: el aura SE VE.
  El record a mano no era el problema: delegarle el spawn al wrapper real
  `$020202` funciono donde las v9-4/5/6 (record a mano con los campos
  limpiados a 0) nacieron invisibles. Hipotesis revisada tras decodificar
  el pool: el wrapper deja `$10/$14/$3C/$5A/$59/$5B/$5C/$50` STALE del
  ocupante anterior (design del juego); algunos de esos stale, que yo
  limpiaba a 0, eran los que ahogaban el dibujo.
- **La aguja del v9-8**: reporte del usuario = "cuando los 2 cruzan en
  frente solo la animacion se le pone a uno". Causa: el contador de
  cadencia era UNO compartido (`$A042` bits 5-7); el hook corre una vez
  por jugador (2 por frame si ambos estan) y el carry del `addi.b #$20`
  caia SIEMPRE en el segundo hook del frame = determinista para un solo
  jugador (no alternado, como se documento antes de decodificar el pool).
  Arreglo: contador PROPIO por jugador (P1 en `$A042` bits 5-7 / P2 en
  `$A043`, byte libre verificado) con selector `btst #$b` sobre el bit 11
  del player slot.

**Por que esa tabla corta**: la tabla real de la estela (`$14EAC`) tiene 4
pares (76, 77, 78, 79, dur 4). La corta deja SOLO 77+78 = la franja 25%-75%
de la animacion (como el `AURA_PAREJA=1/FIN=3` del sonda), y el handler al
llegar al terminador `$0000` **mata el clon LIMPIO** — nada de escribir el
`$4=0` a mano (la leccion del bug de pantalla negra: el corte a mano deja el
slot zombie y piezas de sprite huerfanas).

### El contador de la cadencia (los bits 5-7 de `$A042`)

El hook corre **por frame por jugador parado en el plano**: sin cadencia
clonaria 60 efectos por segundo. El truco: el **`addi.b #$20`** incrementa
un contador guardado en los **bits 5-7** del flag del plano `$A042`:

- los bits 0 y 1 son los que usa el juego (la rutina `$015BD8`), los bits
  5-7 **nadie los toca** (chequeado en todo el desensamblado);
- el contador no se lee: el **carry** del `addi.b #$20` se enciende una vez
  cada 8 frames (`$E0 + $20 = $100`), y el `bcc` usa ESO como disparo. 8
  frames de cadencia, 8 clones vivos como maximo (~1 segundo de vida cada
  uno por la dur de los pares);
- el `clr.b $a042.w` del fin de ronda (`$01871A` / `$01875C`) resetea el
  contador gratis entre rondas.

Si hay DOS jugadores en el plano, ambos corren el mismo contador: las pisadas
se reparten (uno clona en un tick, el otro en el siguiente) — cambia el ritmo,
no la seguridad.

### Notas

- **El record se arma COMPLETO desde cero** (el slot se limpia entero antes
  de escribir): cero dependencia de la basura que dejo el efecto anterior en
  ese slot. Es la misma leccion del `$25` en la captura del trail (el tile
  bajo se heredaba del ocupante anterior del slot).
- Generado y validado con capstone EN EL MISMO script
  (`la rutina entera se desensambla antes de entrar al parche`).
- El fichero `rom/cambios/30_china_VENENO_AURA_P1_P2.bin` = la **china** +
  `veneno_plano` + `veneno_aura` (la "ROM limpia" del veneno CON el aura).
    SHA1 `74791462D3E58B55678C18152D374C3E67F41B25` (v9-8: la v9-7 VALIDADA
  EN JUEGO (el aura se ve) y encima cadencia POR JUGADOR: en la v9-7 el
  contador era UNO compartido (`$A042` bits 5-7) y el carry del addi le
  caia SIEMPRE al segundo hook del frame = con P1 y P2 en el plano solo
  uno tenia la animacion. Ahora P1 cuenta en `$A042` bits 5-7 y P2 en
  `$A043` (byte libre del WRAM), selector = `btst #$b` del bit 11 del
  slot ($FF8400=0 / $FF8800=1). El spawn sigue siendo el wrapper real
  `$020202` + paleta 1. Bisector `31_china_TEST_AURA_SIN_SPAWN.bin`
  (amputa los DOS carry) = `1357AA40F2A6BDB215073C0D5E8549E5772F1B93`).



## 9. EL DESCENSO VELOZ DE JIN (el bisector del doble-abajo, v2b)

Pedido: reproducir el move del Jin de la ROM beta
(`netwave/md_yuyusfsw.zip`): **doble ABAJO en el aire = dive** (descenso
veloz). En la beta sale "si estoy en el aire"; la version final lo limito.
El bisector = la receta minima para SABER si el dive dispara; no es el
grupo final.

### El enganche (hook del cargador de mando `$155E8`)

El hook v1 corria en el runner de mando `$182A2` y NO FUNCIONA, y ademas
el concepto estaba mal: la escalera de comandos `$15CB0` compara `$5F`
contra `$0D/$0E` al principio y hace `rts` inmediato para el aire, asi
que el runner con laterales nunca corre en el aire. El hook v2 se pone
en la rutina que carga el mando en `$71/$72/$73` (`$155E8`, llamada por
`bsr` desde `$15592`), que corre SIEMPRE incluido en el aire, con
`a5` = struct del jugador. En ese punto `$71` trae el mando del frame
ANTERIOR y **bit 1 de `$71` = ABAJO** (verificado en `$13B86`). El hook
camina sobre `move.b $76(a5),d0` + `cmpi.b #$ff,d0` (8 bytes): el stub
los re-ejecuta y re-entra en `$155F0` (el `beq.w`) con los flags recien
puestos.

### La FSM del doble-tap (`$1B0(a5)`, un byte del PROPIO struct, v2c)

Estado: 0 = nada, 1 = abajo (apretado), 2 = ya solto una vez, y **el
disparo es el segundo abajo** con el estado en 2. Gate de aire = `$5F` =
`$0D` (subida) / `$0E` (caida) / `$08` (salto). Gate de personaje =
`$92(a5)` (puntero tabla_30) == `$25D2` = solo Jin. El disparo hace
`jsr $19408` = el armador del dive que la IA usa (gratis, sin mana; el
`$192C8` cobra 4 via `$19C46` y queda para el grupo final si el usuario
pide el mana).

**POR QUE YA NO VA EN LA WRAM `$A044` (el reporte del usuario de la
v2b):** *"no funciona el dive y ademas desactivaste el arriba arriba y
la habilidad de tornado abajo arriba A o B"*. El dives no salia y los
otros DOS movimientos por DOBLE-PULSACION del juego morian. Causa: el
`clr.b $a044.w` del stub por frame. `$A044` = `$FFA044` (el operando
abs.w sign-extends por el bit alto); el 68K NO la referencia en el
listado (escaneo: 12 hits de los bytes `A0 44` en la base, todos en
data; cero instrucciones), pero la writeln `$FFA040-$FFA0FF` es la zona
del buzon con el Z80 y ese byte tiene OTRO DUEo INVISIBLE (el detector
de doble-pulsacion del juego). La regla: **un byte de WRAM proclamado
"libre" por el listado puede tener dueno del otro lado del buzon: hay
que validarlo por EFECTO COLATERAL en juego, no solo por grep.**

**El byte nuevo: `$1B0(a5)`** = un byte del PROPIO struct del jugador,
sacado del CENSO de todos los `(d,a5)` del listado (132 disps) +
cobre conservador (`D..D+3` por si cada disp esta dentro de un long):
el run libre `$186-$1FF` (122 bytes). Ventaja extra: **la FSM es ahora
POR PERSONAJE** (limite "dos Jin se comparten" resuelto). El censo y el
cobren se volvieron a correr en la fecha; los disps usados mas cercanos
a `$1B0` estan en `$18` y `$1A2` fuera del run.

### El stub (`$1A0780-$1A07F3`, 116 bytes; hueco libre documentado hasta `$1A0826`)

    $1A0780  movem.l  d1-d2, -(a7)
    $1A0784  move.b   $5f(a5), d1      ; estado de la FSM del juego
    $1A0788  cmpi.b   #$e, d1          ; caida?
    $1A078C  beq.s    $1A07A0
    $1A078E  cmpi.b   #$d, d1          ; subida?
    $1A0792  beq.s    $1A07A0
    $1A0794  cmpi.b   #$8, d1          ; salto?
    $1A0798  beq.s    $1A07A0
    $1A079A  clr.b    $1b0(a5)         ; no es aire: resetea la FSM
    $1A079E  bra.s    $1A07E2          ; -> al tail
    $1A07A0  move.b   $71(a5), d1      ; EL MANDO (bit 1 = abajo)
    $1A07A4  move.w   $92(a5), d0      ; el personaje
    $1A07A8  cmpi.w   #$25d2, d0       ; solo Jin
    $1A07AC  bne.s    $1A07D8
    $1A07AE  move.b   $1b0(a5), d2     ; estado viejo de la FSM
    $1A07B2  btst.b   #$1, d1          ; abajo?
    $1A07B6  bne.s    $1A07C2
    $1A07B8  cmpi.b   #$1, d2          ; estado 1 (abajo) y solto
    $1A07BC  bne.s    $1A07D2          ; -> 0
    $1A07BE  moveq    #$2, d2          ; -> 2 (suelto una vez)
    $1A07C0  bra.s    $1A07DE
    $1A07C2  cmpi.b   #$2, d2          ; abajo Y estado 2: DISPARA
    $1A07C6  bne.s    $1A07D6          ; -> 1 (llevando abajo)
    $1A07C8  jsr      $19408.l         ; el armador del dive de la IA
    $1A07CE  moveq    #$1, d2
    $1A07D0  bra.s    $1A07DE
    $1A07D2  moveq    #$0, d2
    $1A07D4  bra.s    $1A07DE
    $1A07D6  moveq    #$1, d2
    $1A07D8  clr.b    $1b0(a5)         ; no es Jin: resetea
    $1A07DC  bra.s    $1A07E2
    $1A07DE  move.b   d2, $1b0(a5)     ; guarda el estado
    $1A07E2  move.b   $76(a5), d0      ; re-pone lo que tapo el hook
    $1A07E6  cmpi.b   #$ff, d0
    $1A07EA  movem.l  (a7)+, d1-d2
    $1A07EE  jmp      $155f0.l         ; el re-anclaje del hook (6 bytes: 4EF9 0001 55F0)

(+ los bytes de cada instruccion estan en `parches.json`, item por byte).

### Los DOS bugs del stub v2 (por eso esta version v2b)

1. **Los tres `beq` del gate de aire aterrizaban en `$1A07A4`** = la
   MITAD del `move.b $71(a5),d1` (el disp del `.b` calculado con otra
   base). El reload del mando quedaba MUERTO y el `btst #$1` leia el
   byte de `$5F` en su lugar (con `$5F=$0E` el bit 1 esta a 1: leia
   "abajo" caendo). Una rama puede caer DENTRO de la instruccion
   siguiente si el disp sale mal: **el disp de un `Bcc.s` es relativo a
   `addr+2`** (la direccion del byte del disp), como los `.w`.
2. **La FSM nunca leia `$A044`**: comparaba `d2` recien-escrito contra
   `#2`, el `jsr $19408` era inalcanzable y el bisector entero era
   INERTE (corria sin romperse y no hacia nada). El fix:
   `move.b $a044.w, d2` al arranque de la FSM.

**Leccion re-vista**: capstone solo certifica que las instrucciones
DECODIFICAN, no que hagan lo que la intencion dice. Lo que SI bajo el
roundtrip esta vez: los `move` con `(abs.w)` se armaron con los bits y
no de memoria (`move.b (abs.w),dn` = `$1438` y `move.b dn,(abs.w)` =
`$11C2`, ambos ENCONTRADOS por fuerza bruta sobre los 65536 opcodes con
capstone de arbitro; a mano me habian salido al reves y capstone los
cacho). Y el operando `(abs.w)` = UN word (`A044`), no tres bytes.

### El resultado

- `rom/cambios/33_china_DOBLE_ABAJO_AIRE.bin` = la base china +
  `doble_abajo_aire` (v2c, estado en `$1B0(a5)`), SHA1
  `A77F5611C235EDB29E348CA6E4DDF064BEB68732` (126 parches, 108 bytes
  distintos, checksum `$182D`). `verificar_desensamblado.py`: OK.
  Chequeo a mano del hook, del stub completo y del re-anclaje con
  capstone en el ROM final: OK. Ademas: cero hits de `$85B0`/`$89B0`/
  `$8DB0`/`$91B0` (los absolutos de ese run del struct) en codigo.
- Las versiones anteriores quedan como anti-ejemplos: la v2
  `32_china_TEST_DOBLE_ABAJO_AIRE.bin` (stub inerte por los dos bugs)
  y la v2b con SHA1 `80A34460...` (el estado en `$A044` apaga el
  doble-arriba y el tornado).
- LIMITACIONES (igual que el bisector): no exige ventana de tiempo
  entre los dos abajos, y NO
  cubre el estado de flotar `$30` (ahi el dive lo dispara la maquina
  del flotar con `$48/$4C`). El dive del bisector no cobra mana (el
  gasto "igual que el movimiento aereo" de la beta va en la receta
  final).
- **Pendiente: el test del usuario en FBNeo** (Jin vs CPU: saltar y
  doble abajo en el aire).
**AVISO para el AURA** (usa los bits 5-7 de `$A042` y el byte `$A043`):
es la MISMA zona del buzon `$FFA040-$FFA0FF`. En juego estuvo OK
(v9-8 validada por el usuario), pero si un dia el aura empieza a fallar
de forma rara, mirar el buzon primero. El addi.b de bits 5-7 es un
read-modify-write del byte ENTERO: si el dueno invisible de `$FFA042`
escribe concurrido podeis pisar bits (esto es hipotesis, no ha pasado).

### El doble-arriba SIGUE muerto con la v2c: el diagnostico diferencial

El test del usuario con la v2c (ROM 33) reporto: doble-arriba muerto y
el tornado no sale. La v2c NO escribe `$FFA044` para nada, asi que la
teoria "el clr de la v2b mato el detector" quedo sin sustento si el
doble-arriba estaba muerto en una sesion limpia. Contra-escaneo con
capstone LINEAL sobre la base CHINA entera (`censo_china.py`,
~632715 instrucciones decodificadas): **cero referencias reales del
68K a `$FFA040-$FFA045`** en la china tambien (las unicas de verdad son
las de `$A042` del plano y el `lea $A04000` del chip de sonido; el resto
era data y branch-targets falsos). Y el disp `$1B0(a5)` tampoco tiene
dueno en la china (los hits de la busqueda son el inmediato `$1B0` de
las tecnicas, data, y un disp NEGATIVO `-$1b0` que el filtro confundio).

Dos sospechosas que quedaron de pie:

1. **La RAM persiste entre recargas de ROM** en BizHawk/FBNeo: el dano
   que la v2b hizo EN JUEGO sobre `$A044` queda pegado hasta un
   ARRANQUE EN FRIO (energy/power-cycle), y un reload no lo limpia. Los
   tests anteiores pudieron estar corriendo con la `$A044` vencida.
2. **El hook del cargador `$155E8` en si**: el doble-arriba funcionaba
   con la ROM 30 del aura, cuyo hook vive en `$015BF6` (OTRO cargador).
   El hook de `$155E8` es la constante de TODAS las roturas.

Para romper el empate salio el grupo `doble_abajo_diag` (+22 items):
el MISMO hook de `$155E8` con un stub DE PASAMANOS que solo re-ejecuta
`move.b $76(a5),d0` + `cmpi.b #$ff,d0` (los dos operandos COPIADOS tal
cual del original) y vuelve con `jmp $155f0.l`; NO escribe ni un byte
de RAM y no usa `d1`/`d2`. El ROM:
`rom/cambios/34_china_DIAG_hook_pasamanos.bin`, SHA1
`2D2D993021EEF1A173EAD1FCF64ACD31CE22FA53` (17 bytes distintos),
`verificar_desensamblado.py` OK. La matriz del test:

- BASE limpia + sonda: el doble-arriba TIENE que vivir (linea de base
  del detector). Si vive aca, la base esta bien.
- ROM 34 (diag, arranque en frio): doble-arriba VIVE = el responsable
  era la escritura de la FSM (vuelve el foco al byte del struct);
  doble-arriba MUERTO = el hook del cargador en si es el asesino y hay
  que re-ancarlo en otro sitio.
- ROM 33 (v2c, arranque en frio): el test original.

La sonda=`herramientas/lua/sonda_doble_bajo.lua` v3: en vez de mirar el
dive, VUELCA EL DIFF de la pagina `$FFA000-$FFA0FF` frame a frame (solo
en los frames donde el mando cambia), con direccion y valor
viejo->nuevo. Con la base limpia y cinco doble-arriba, el byte del
detector del doble-tap TIENE que aparecer en el log; ese byte se
compara entre ROMs y se sabe que hay que respetar. El log va a
`C:/Users/leand/AppData/Local/Temp/opencode/sonda_doble_bajo.log`
(tambien vuelca `$71-$74`, `$5F`, Y y la FSM `$FF85B0` del P1).

### El hook es inocente y los bisectores v2d/v2e

Test de la ROM 34: **anda todo menos el doble-abajo** (el dive no esta
en la 34 a proposito): el hook del cargador es INOCENTE; doble-arriba
y tornado viven con el hook puesto. Sentencia de los dos
`bclr.b d0,$1b0(a0)` de la china: son data (tablas ascendentes). Y la
re-auditoria del stub v2c por capstone: la logica es correcta. El
descubrimiento: el stub v2c **escribe `$1B0(a5)` en TODAS las llamadas
del cargador ANTES del chequeo de slot activo** (`$76(a5) == $FF` =>
el camino de fabrica va al `$156D0`, clr de `$71-$73`/`$C0-$C2`). El
`a5` llega por registros (no hay `lea` directos de las bases salvo
`$FFFF8400` en `$010D2E`): no puedo certificar todos los valores.

Dos bugs nuevos de generacion a mano, cachados por el arbitro capstone:
- `$112D` NO es `move.b (d16,a5),d1`; el correcto es `$122D` (la receta
  `0x10+reg` solo casaba por suerte con d0=`$102D`).
- Un `beq.w` del `$1A0780` al `$156D0` es ILEGAL: el disp queda fuera
  del rango ±32K (los objetivos a 1.6 MB no se alcanzan volando). El
  bypass de inactivos lo sigue haciendo el `beq.w` de fabrica en
  `$155F0` con los flags que re-arma el cmpi de la cola.

Los bisectores (ambos armados y verificados, hueco `$1A0780`, 167
bytes libres):
- `doble_abajo_gate76` => `rom/cambios/35_china_DOBLE_ABAJO_GATE76.bin`
  (ROM 35, v2d 128 bytes, SHA1 `3E080D285FC9C71003FAC9845C7F832EC621DAA4`):
  la FSM solo corre con slot activo (`$76(a5) != $FF`).
- `doble_abajo_sinesc` => `rom/cambios/36_china_DOBLE_ABAJO_SINESC.bin`
  (ROM 36, v2e 118 bytes, SHA1 `399DC091BCA546EB56633A458C23A5A7AB983180`):
  el cuerpo v2c sin escribir `$1B0` para nada (nops/clr d2; jsr
  inalcanzable).
- Test: SIEMPRE arranque en frio. Si la 35 arregla el doble-arriba =>
  receta final = v2d. Si la 36 TAMBIEN mata el doble-arriba => no es
  la escritura de `$1B0`. El dive no sale en ninguna de las dos (a
  proposito).

### RESULTADO de la 35 y el gate de personaje muerto (ROM 37)

Test de la 35: **anda TODO menos el dive** (doble-arriba y tornado
viven). El gate del slot era el asesino del doble-arriba: CONFIRMADO.
Compuertas restantes de la FSM: (1) `$5F` aire `$0D/$0E/$08` +
`$71` bit1=abajo: CERTIFICADOS por el log de la sonda del usuario; (2)
el armador `jsr $19408`: CERTIFICADO en el ROM real (dump del `$19408`
de la china IDENTICO al `$12BAE` de la beta, el armador gratis; el que
cobra mana usa `bsr $19c46` y la base lo llama en `$193C0`); (3) el
gate de personaje `$92=$25D2`: **SIN PRUEBA y con evidencia en
contra** — cero instrucciones del ROM china tocan `$92(a5)` y cero
llamadas directas a `$19408`/`$192C8` existen (el armador se invoca
por rutas computadas). El `$25D2` es el word bajo del pointer de Jin
a su tabla de moves (`$0125D2`) del build J, transplantado.
=> `doble_abajo_singate92` => `rom/cambios/
37_china_DOBLE_ABAJO_SINGATE92.bin` (v2d con el `bne` del gate en nops,
SHA1 `BE2B4CE71BCB0A6BAC84D00A38763BD9254178C7`): si ahi el dive SALE,
el gate era el asesino y queda cavar el ID de personaje REAL del
struct de la china (la sonda v3 calibra el word `$92` del P1 en el
mismo log). El dive en la 37 puede salir para todos (diagnostico).
Resultado: NO sale, y el movimiento queda limitado (solo
habilidades/horizontal/up diagonal): el fire por el armadorGratis
`$19408` mete en el estado `$A0` con la maquina del final
incompleta. Re-lectura del log viejo de la sonda: el frame despues del
segundo abajo, `$6B` pasa `00->06` en la base: quien escribe `$6B=6`
vive en la FILA de armadores aereos `$1E60E-$1E8A4` (mando falso
`$10/$20/$40` + `$6B=#1..#6`, solo laterales; el consumidor de esos
bits en la escalera `$15C3E/8E/C2/D78`; cero llamadas directas,
despacho computado; el dive = abajo PURO = no tiene bloque: el final
lo recorto). El fire correcto del final = el armador CON MANA
`$192C8` de la china, CERTIFICADO: `move.w #4,d0; bsr $19c46` (cobra
4, el mismo gasto del movimiento aereo), `beq` fallback, `$10=0/
$14=$48000/$5f=$a0/$4c=0`, tail `$19350` - forma identica al `$12A7E`
de la beta; el check adentro lo hace seguro sin mana.
=> `doble_abajo_manafire` => `rom/cambios/
38_china_DOBLE_ABAJO_MANAFIRE.bin` (v2d sin gate + fire por `$192C8`,
SHA1 `8EE393E692E1AF65EFC1F22B73E19E55B674585E`). El dive tiene que
salir y costar 4 de mana. El dive puede salir para todos
(diagnostico: el gate de personaje queda pendiente de la calibracion
de `$92` de la sonda).

Resultado de la 38: NO sale el dive y el usuario reporta roturas de
regresion (los dashes laterales `<< >>` andan en el salto diagonal
pero no en el vertical; el especial abajo-arriba-A dejo de salir).
Diff completo de la 38 contra la base: UN solo hook + stub: hook en
`$0155E8` = 6 bytes `4e f9 00 1a 07 80` (jmp, no jsr) que pisa
`move.b $76(a5),d0; cmpi.b #$ff,d0` = el APLICADOR del mando falso
del movimiento armado ( `$76`= indice del comando pendiente, `ff`=
nada; el cuerpo carga `$71-$74/$c0-$c2` desde el struct apuntado).
Dentro del applier: `$015592 bsr $0155e8` por frame. Hallazgos del
dis del stub 38 + ronda de desensamblado:

- `$192C8` = armador CON MANA certificado; su tail corre `bra $19C1C`
  (runner de estado). El `$A0` sigue sin consumidor directo en el
  china (las rutas vivas de los especiales per-char van por la
  escalera `$6B` + bits `$73`: `$6B=6`+bit6=`$18A92` -> `$AA` con
  mana `$C8` = el especial de personaje, `btst #6,$73` exige un mando
  falso que solo escriben los armadores laterales `$1E852/$1E86E/
  $1E88A`; el detector doble-abajo de la base escribe `$6B=6` PELADO
  por eso muere silencioso en el btst -confirmado en el log f8414-).
- `$19C46` = solo `sub` de mana sobre `$B8(a5)`, seguro llamar.
- `$1B0(a5)` = byte LIBRE (unicos hits de `01 b0` en la base son
  literales $1b0 de `$0D0D4`, no accesos a (d16,a5)).
- el stub de la 38 llamaba `jsr $192C8` con d0 = `$92` (25D2) sin
  restore antes del jsr: defensivamente incorrecto aunque `$192C8`
  re-carga d0.

=> ROM 39/40 (regenerado DESDE LA BASE LIMPIA con
`herramientas/hacer_dive39.py`): hook `$0155E8` = `4e f9 00 1a 06 ae`
jmp al stub nuevo en `$1A06AE` (hueco de ceros `$1A06AE-$1A0826`,
377 bytes; el stub usa 180). Stub v3:
  1. replica `move.b $76,d0; cmpi #$ff,d0`; FF -> `jmp $0155F0`
     (el base sigue tal cual, d0/flags intactos).
  2. FSM de doble-abajo en `$1B0` con gate `$5F in {0E,0D,08,07}`
     (la 38 no tenia el `07` diagonal: por eso no armaba en el
     salto diagonal).
  3. fire = CLON INLINE del bloque `$A0` de `$192C8`: cobro
     `move.w #4,d0; jsr $19C46` (sin mana no dispara), luego
     `move.l #0,$10 / move.l #$48000,$14 / $5F=$A0 / $4C=0 /
     $5D=$2F / clr $6B / $6C=0 / $1B0=0`. Nada de jsr al armador.
   4. salida: pop d1-d2, clr.w d0 + rejuega move.b $76,d0,
      jmp $0155F4 (bypass del beq $0155F0: ya se sabe que $76!=ff).
      El clr.w d0 es OBLIGATORIO: el cuerpo en $0155F4 hace
      'movea.l d0,a2' y lee la tabla en -$880(a2) con d0 COMPLETO
      (32 bits); con los altos de d0 sucios, a2 = basura y el
      aplicador pisa $71-$74/$c0-$c2 con datos corruptos. El base
      lo evita en su otro camino con clr.w d0 ($1555B4) y movea.w
      ($155C0).
practica: los tres ROMs de la generacion sin recalcular dieron
"error checksum" y rojo en el logo Sega; la 38 con su checksum
recalculado $D94B arrancaba). `hacer_dive39.py` recalcula el
checksum sobre el contenido parcheado (suma de palabras desde $200,
modulo $10000) y lo escribe en $018E. Con NUESTRA base el valor de
partida es consistente ($337B almacenado == calculado).

`rom/cambios/39_china_DIVE_A0INLINE.bin` (nombre viejo, con checksum
SIN RECALCULAR: petea rojo en el logo, no cargar).

Log de la sesion con el 40 checksumado (sonda fuerte): el detector
base del doble-abajo SI dispara en el aire ($6B: 00 -> 06 con
$5F=07 diagonal, f 8414 del log) y el juego corre bien, PERO la
FSM nunca sale de 00 (FF85B0 queda 00 con abajo presionado en aire).
Diagnostico: 43_china_DIVE_DIAG_SENTINEL.bin = stub que replayea
la cabeza, escribe $A5 via ($1B0,a5), $0C por abs en FF85B0 y un
eco $C0/$A5 en $FFA0F4/$FFA0F5 (la pagina que la sonda vigila), y
sale por jmp $0155F0. Veredictos: FFA0F4=$C0/FFA0F5=$A5 => el stub
corre; FF85B0 $A5 => a5==FF8400 (el write via a5 piso el abs);
FF85B0 $0C => el stub corre pero a5 != FF8400 (los writes del FSM
van a otro struct); FF85B0 $00 con eco presente => algo del juego
borra FF85B0 por frame; sin eco => el hook no se ejecuta.
VEREDICTO de la sentinela (sesion con 43, log del usuario): FFA0F4=$C0
y FFA0F5=$A5 aparecieron (f 1993) => el stub CORRE; FF85B0 quedo en
$0C constante => el write via ($1B0,a5) NO cayo en FF85B0 => el a5 que
trae el hook NO es FF8400 (es otro struct, seguro el del buzon de
input; los armadores escriben el mando falso de P1 por su cuenta).
Aclaracion: $19C46 es a5-relativa ($B8(a5) = mana, en P1 = $FF84B8):
con el a5 del hook cobraria el mana del struct equivocado.

FIX v3 (la generadora actual): la FSM del doble-abajo queda ANCLADA al
struct de P1 por swap temporal de a5:
  FSM: push d1,d2,a5 (movem 48e7 6004); lea $FF8400,a5 (4b f9! el
  $4d=f9 seria a6); todo el bloque FSM/fire a offsets a5-relativos;
  SALIDA: movem (a7)+, d1-d2/a5 (4cdf 2006) restaura el a5 del hook
  ANTES de clr.w d0 + rejugar move.b $76(a5),d0 + jmp $0155F4 (el
  cuerpo del base espera el a5 original del contexto).
Los 4 roms regenerados con esto; el 40 resultante: checksum $355F,
sha256 5FA367783E48EADE1ED365F6E035EC0DCC95F9126B6077622E533A245DD9CEDF.
Lecciones del emisor anadidas: lea $FF8400,a5 = 4b f9 (los 4d=f9 son
a6); movem push con a5 en modo -(An): d1=bit14, d2=bit13, a5=bit2
(6004); pop en modo (a7)+: d1=0002, d2=0004, a5=2000 (2006). El
movea.l #imm,An NO se emite como 2b7c (eso es move.l #imm,(d16,A5)):
usar LEA que ademas no toca flags.


Prueba el dive (vertical y diagonal) y si el `$A0` vuelve a quedar
huorfo el proximo paso es la ruta `$6B=6`: hookear el write-site del
detector base que deja `$6B=06` pelado y sumarle el mando falso
(la via per-char `$18A92`/especiales de la escalera).
