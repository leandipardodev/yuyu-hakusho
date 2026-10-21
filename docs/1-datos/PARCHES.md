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
