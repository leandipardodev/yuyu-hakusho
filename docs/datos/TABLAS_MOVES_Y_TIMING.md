# Tablas de moves y timing

Todo lo de aqui esta **verificado leyendo `game_68000.asm`**. Cada afirmacion
lleva su direccion. Lo que no se pudo confirmar esta marcado como ABIERTO.

Responde a las tres ventanas que se ven al golpear:

1. **startup / active / recovery** → §1 y §2, esta en ROM, se lee sin emulador.
2. **ventana de combo** → §4, es el presupuesto de stun `$7E`.
3. **blockstun** → §6, NO localizado todavia.

---

## 1. El registro de frame: 8 bytes

El ejecutor es `loc_01EB40` (`0x1EB48`–`0x1EC1E`). Se entra una vez por frame
de animacion y se lee de la tabla del move:

```asm
01eb48:  movea.l   $50(a5), a2       ; base del move
01eb4c:  adda.w    (a2, d0.w), a2    ; + indice (d0 = id de move)
01eb52:  move.b    $59(a5), d0       ; indice de frame
01eb56:  lsl.w     #$3, d0           ; * 8   <-- registro de 8 bytes
01eb58:  adda.w    d0, a2
```

| +offset | Destino | Que es |
|---|---|---|
| `+0` | `+$5A` | **duracion del frame** |
| `+1` | registro `d3` | indice de animacion |
| `+2` | `+$5C` | flags del frame |
| `+3` | `+$6C` | estado |
| `+4` | — | id de sonido (tabla `$218D8`) |
| `+5` | — | sin uso encontrado |
| `+6` | `+$28` | offset X, sesgado con `-0x80` |
| `+7` | `+$2A` | offset Y, sesgado con `-0xA0` |

```asm
01eb5a:  move.b  $0(a2), $5a(a5)   ; +0 -> duracion
01eb62:  move.b  $1(a2), d3        ; +1 -> indice de animacion
01eb66:  move.b  $2(a2), d5        ; +2 -> flags
01eb6a:  move.b  d5,  $5c(a5)
01eb6e:  move.b  $3(a2), d0        ; +3 -> estado
01eb72:  or.b    $6d(a5), d0
01eb76:  move.b  d0,  $6c(a5)
01eb82:  move.b  $4(a2), d0        ; +4 -> sonido
01eb86:  lea.l   $218d8.l, a3
01eb8c:  move.b  (a3, d0.w), d0
01eb94:  move.b  d0, $a030.w
01eba4:  move.b  $6(a2), d6        ; +6 -> X
01ebaa:  subi.w  #$80, d6          ;    sesgo 0x80
01ebae:  move.b  $7(a2), d7        ; +7 -> Y
01ebb4:  subi.w  #$a0, d7          ;    sesgo 0xA0
```

### Los offsets X e Y son signed con sesgo

`-$80` y `-$A0` significa que un byte `0x00` es "centro" y los valores
negativos dan offsets a la izquierda/arriba. Ojo: `move.b` carga sin signo, el
sesgo lo hace `subi.w` sobre el word, asi que el resultado **si** es signed.

Ademas se invierte por facing:

```asm
01ebd6:  beq.b    $1ebda           ; $61 == 0 ?
01ebd8:  neg.w    d6               ; facing != 0 -> negar
```

### Bit 4 de los flags = invulnerable / cancelable

```asm
01eb98:  btst.b   #$4, d5
01eb9c:  beq.b    $1eba4
01eb9e:  moveq    #$ff, d0
01eba0:  move.l   d0, $94(a5)      ; $94 = $FFFFFFFF
```

`$94` es la mascara de estados golpeables. El resolver la testea contra el
estado del defensor:

```asm
01f25e:  move.b   $70(a4), d0      ; estado del defensor
01f264:  move.l   $94(a3), d1      ; mascara del atacante
01f268:  btst.l   d0, d1
01f26a:  beq.w    $1f50a           ; 0 = no se puede golpear
```

`$70` = bit a testear, `$94` = mascara. Si el bit esta en cero, el golpe pasa.

---

## 2. Las 12 tablas por personaje

`+$8C` es puntero a la tabla del personaje. Se indexa por
`indice_de_animacion * 4`:

```asm
01ebb8:  lsl.w    #$2, d3           ; d3 = indice de animacion * 4
01ebba:  movea.l  $8c(a5), a2
01ebbe:  move.b   (a2, d3.w), d4    ; +0 atributos
01ebc4:  move.b   $1(a2, d3.w), d0  ; +1
01ebc8:  add.w    d0, d0
01ebca:  move.w   d0, $3c(a5)      ;   -> $3C (con signo, *2)
01ebce:  adda.w   $2(a2, d3.w), a2  ; +2 word = offset al blob de cajas
```

| +offset | Que es |
|---|---|
| `+0` | atributos del frame |
| `+1` | valor que va a `+$3C` (se duplica) |
| `+2` | word: offset relativo al blob de cajas |

Direcciones, con el stun max emparejado cuando esta en el mismo bloque de init:

| Slot | Tabla | Stun max | Init |
|---|---|---|---|
| 0 | `$C04CA` | 40 (`$28`) | `0x0127AA` / `0x0127C8` |
| 1 | `$C31DA` | 56 (`$38`) | `0x0127F4` / `0x012812` |
| 2 | `$C5DAA` | 48 (`$30`) | `0x01283E` / `0x01285C` |
| 3 | `$C8BEA` | 44 (`$2C`) | `0x012888` / `0x0128A6` |
| 4 | `$CB38A` | 54 (`$36`) | `0x0128D2` / `0x0128F0` |
| 5 | `$CDEFA` | 46 (`$2E`) | `0x01291C` / `0x01293A` |
| 6 | `$D069A` | 40 (`$28`) | `0x012966` / `0x012984` |
| 7 | `$D2C6A` | 38 (`$26`) | `0x0129B0` / `0x0129CE` |
| 8 | `$D59FA` | 48 (`$30`) | `0x0129FA` / `0x012A18` |
| 9 | `$D85AA` | 62 (`$3E`) | `0x012A44` / `0x012A62` |
| — | `$BDCAA` | **no emparejado** | `0x012ABE` |
| — | `$D9A3A` | **no emparejado** | `0x01366C` |

Los dos ultimos no tienen un `move.w #$xx,$80(a5)` cerca, asi que **no se sabe
a que personaje corresponden**. ABIERTO.

### Bit 6 = este frame genera caja

```asm
01ec06:  btst.b   #$6, d4
01ec0a:   beq.w   $1ec88           ; sin cajas
01ec0e:  move.b   (a2)+, $65(a5)
01ec12:  move.b   (a2)+, $66(a5)
01ec16:  move.b   (a2)+, $64(a5)
01ec1a:  move.b   (a2)+, d0
01ec1e:  andi.b   #$f, d0
01ec22:  move.b   d0, $68(a5)
```

**Los frames activos son los que tienen el bit 6.** Con eso y `+$5A` se
construye el startup / active / recovery sin ejecutar nada.

---

## 3. Dano y dano de stun

Del blob del frame salen los dos numeros del golpe:

```asm
01f420:  move.b   $65(a3), d0
01f424:  sub.w    d0, $78(a4)      ; $65 = DANO  -> HP
01f428:  move.b   $66(a3), d0
01f42c:  sub.w    d0, $7e(a4)      ; $66 = DANO DE STUN -> $7E
```

| Offset | Que es | Destino |
|---|---|---|
| `+$65` | dano del move | `sub.w` a `+$78` (HP) |
| `+$66` | dano de stun del move | `sub.w` a `+$7E` (presupuesto) |
| `+$64` | atributos | testeado por los resolvers |
| `+$68` | nibble bajo | estado |

`$64` decide el knockback segun sus bits 0-1:

```asm
01f434:  move.b   $64(a3), d0
01f438:  andi.b   #$3, d0
01f43c:  cmpi.b   #$0, d0
01f442:  move.l   #$30000,    $10(a4)   ; d0 = 0
01f364:  move.l   #$39000,    $10(a4)   ; d0 = 1
01f37e:  move.l   #$4c000,    $10(a4)   ; d0 = 2
```

### Variante de dano con flag

```asm
01f3ce:  btst.b   #$4, $64(a3)      ; bit 4 = variante
01f3d4:   beq.b   $1f3f0
01f3d8:  move.b   $65(a3), d0
01f3dc:  lsr.b    #$2, d0           ; d0 = $65 / 4
01f3de:  addq.b   #$1, d0           ; +1
01f3e0:  sub.w    d0, $78(a4)
01f3e4:  cmpi.w   #$0, $78(a4)
01f3ea:   bge.b   $1f3f0
01f3ec:   clr.w   $78(a4)           ; clamp a 0
```

Con bit 4 el dano es `(dano/4) + 1` en vez de `dano`. El clamp a 0 esta en
`0x1F3EC`.

---

## 4. La ventana de combo: `$7E` es un PRESUPUESTO

**No es un timer.** Es una bolsa que se gasta golpe a golpe. Por eso el
"cuanto combo entra" se puede calcular, no solo medir.

```asm
01f4d6:  cmpi.w   #$0, $7e(a4)      ; se agoto?
01f4d8:   bne.b   ...
01f4de:  ...
01f4e2:  move.w   $7e(a4), d0
01f4e6:  neg.w    d0
01f4e8:  addi.w   #$4, d0
01f4ec:  asl.w    #$4, d0           ; *16
01f4ee:  move.w   d0, $84(a4)       ; $84 = velocidad del knockdown
```

| Address | Que hace |
|---|---|
| `0x1F42C` | `sub.w $66,$7E` — gasta presupuesto |
| `0x1F4D6` | test de agotamiento |
| `0x1F4E2` | calcula knockback a partir del resto |
| `0x19D84` | `cmpi.w #$0,$7e(a5)` — segundo test |
| `0x15A4A` | `move.w $80(a5),$7e(a5)` — reset |
| `0x18694` | `move.w $80(a5),$7e(a5)` — reset |

**Golpes hasta knockdown = `ceil($80 / $66)`** del move que estes pegando. Con
`$80` de la tabla de §2 y `$66` del blob del frame, sale exacto y sin
emulador.

`$94 = $FFFFFFFF` (bit 4 de los flags, §1) es lo que permite encadenar: mientras
el atacante no lo tenga, el siguiente golpe no pasa el test de `0x1F268`.

## 4b. `$C6` es el contador NATIVO de combo — y vive en el DEFENSOR

**Este es el contador de combo oficial del juego.** No hay que estimarlo contando
frames: el juego lo lleva en un byte.

Vive en **`a4`, que es el defensor**, mientras que `a3` es el atacante. O sea:

> **Para leer el combo de P1 hay que leer `$C6` del slot del P2.**

La rutina de contacto es `loc_01F9C8`, y **suma el contador ANTES de usarlo**, que
es lo que define la tabla:

```asm
loc_01f9f0:
01f9f0:  addi.b   #$1, $c6(a4)      ; 1ro: SUMA
01f9f6:  cmpi.b   #$10, $c6(a4)
01f9fc:   bcs.b    $1fa0a
01f9fe:  move.b   #$10, $c6(a4)     ; tope 16
01fa04:  bset.b   #$0, $a0a4.w
loc_01fa0a:
01fa0a:  clr.b    d0
01fa0c:  move.b   $c6(a4), d0
01fa10:  asl.w    #$1, d0           ; 2do: d0 = $C6 * 2
01fa12:  add.w    d0, $b8(a3)       ; y SUMA el mana del ATACANTE
01fa16:  cmpi.w   #$df, $b8(a3)
01fa1c:   blt.b    $1fa26
01fa1e:  move.l   #$df0000, $b8(a3) ; tope 223
```

**No tiene ventana de frames.** El corte es por **estado del defensor**, asi que
es mas confiable que una medicion a mano: es la misma condicion que usa el juego
para decidir si el combo sigue.

```asm
01f9c8:  cmpi.b   #$20, $5f(a4)     ; < $20  -> reset
01f9ce:   bcs.w    $1fa6a
01f9d2:  cmpi.b   #$30, $5f(a4)     ; > $30  -> reset
01f9d8:   bhi.w    $1fa6a
01f9dc:  cmpi.b   #$27, $5f(a4)     ; > $27  -> seguir
01f9e2:   bhi.b    $1f9e6
01f9e4:   bra.b    $1f9f0           ; <= $27 -> SUMA
01f9e6:  cmpi.b   #$2e, $5f(a4)
01f9ec:   bcs.w    $1fa6a           ; $28..$2D -> RESET
```

| `$5F` del defensor | Efecto |
|---|---|
| `$20`–`$27` | **suma** |
| **`$28`–`$2D`** | **RESETEA**, aunque este dentro de `$20`–`$30` |
| `$2E`–`$30` | **suma** |
| fuera de `$20`–`$30` | reset |

**`$28`–`$2D` es un agujero DENTRO de la ventana:** esos 6 estados cortan el
combo en vez de continuarlo. No se ve leyendo solo los dos `cmp` extremos.

El reset es `clr.b $c6(a4)` en `loc_01FA6A` (`0x1FA6A`), que no tiene `rts` propio
— cae dentro del retorno de `loc_01FA6E`. Y `$C6` **nunca se inicializa** en los
bloques de init de round: arranca en 0 por el borrado general del struct.

### El maná por combo sale de acá — CORRIGE LA TABLA DE WEB

**Regla verificada: `+2 * n`, con `n` = el numero de golpe contando desde el
PRIMERO. Tope de +32 del golpe 16 en adelante.** Acumulado = `n * (n + 1)`, o sea
272 al llegar a 16.

La tabla de `newton.com.tw` que estaba en el repo decia
`min(2 * (n - 1), 32)` con "nada hasta el segundo golpe". Los valores por golpe y
el acumulado coinciden, pero **el numero de golpe va corrido en uno**: el ROM da
**+2 en el primer golpe**, no nada. Ver `DATOS_VERIFICADOS.md` §2a.

### Un tercer consumidor, que muestra que `$C6` mueve un efecto

```asm
01fa50:  move.b   $c6(a4), d0
01fa54:  addi.b   #$81, d0
01fa58:  lsl.w    #$1, d0           ; ($C6 + $81) * 2
01fa5a:  move.w   d0, $3c(a0)       ; +2 por golpe de combo
```

`$3C` del objeto que resuelve `$1FAAE` escala con el combo. **Que campo es sigue
ABIERTO**, pero el escalado es verificable.

---

## 5. Lo que NO es hit-time

### `$26` — un INDICE, NO hit-time

`$1F7B2` son **seis instrucciones** y solo escribe `$26`. Lo importante es que
la llaman **todos** los resolvers, no solo los especiales:

```asm
01ef8c:  jsr      $1f7b2           ; resolver de clash
01f2ac:  jsr      $1f7b2           ; resolver de hit
```

```asm
01f7b2:  cmpi.w   #$130, $9c(a3)
01f7b8:   beq.b   $1f7c8
01f7ba:  move.b   #$3c, $26(a3)    ; atacante = 60
01f7c0:  move.b   #$40, $26(a4)    ; defensor = 64
01f7c6:   rts
01f7c8:  move.b   #$bc, $26(a3)    ; 188
01f7ce:  move.b   #$c0, $26(a4)    ; 192
01f7d4:   rts
```

Si el atacante tiene `$9C == $130`, los valores suben a 188 / 192.

**Que sean "frames de congelacion" quedo descartado.** Y despues se descarto
tambien la lectura de "profundidad" y la de "dos planos".

**`$26` es un INDICE: el cursor de una tabla de desplazamientos.** Lo dice el
consumidor, `loc_0379AE`:

```asm
0379c8:  move.b   $26(a5), d0        ; d0 = $26
0379cc:  addq.b   #$1, $26(a5)       ; $26++
0379d0:  move.b   (a0, d0.w), d6     ; byte de la tabla
0379d4:   bpl.b    $379f4            ; el bit 7 es el SIGNO
0379f4:  ext.w    d6
0379fc:  mulu.w   d0, d6             ; x escala
037a06:  add.w    $10(a5), d6        ; + velocidad
```

**El bit 7 NO son dos planos: es el signo.** Los valores con signo:

| Valor | Con signo | | Valor | Con signo |
|---|---|---|---|---|
| `$10` | +16 | | `$40` | +64 |
| `$14` | +20 | | `$94` | **−108** |
| `$3C` | +60 | | `$C0` | **−64** |

La pareja `$14` / `$94` que se tomo como evidencia de dos planos es `+20` y
`−108`. Y se decrementa al copiarse entre structs, lo que tampoco es lo de una
profundidad que crece:

```asm
01f9bc:  move.b   $26(a3), $26(a0)
01f9c2:  subq.b   #$4, $26(a0)
01fa5e:  move.b   $26(a3), $26(a0)
01fa64:  subq.b   #$8, $26(a0)
```

Una medicion dio 64 y 192 en ejecucion, que es EXACTAMENTE lo que escribe el ROM
(`$40` y `$C0`): corrobora los valores, no el nombre del campo.

### `$14` — empuje, NO stun

Este estaba sin decodificar. Es la magnitud del empujon, un long:

```asm
01f342:  move.l   #$fffc0000, $14(a4)   ; leve
01f364:  move.l   #$fffb0000, $14(a4)   ; medio
01f386:  move.l   #$fffa0000, $14(a4)   ; fuerte
```

Los tres negativos de ahi estan en `0x1F342`, `0x1F364` y `0x1F386`.

### `$69` — hitpause (esto si es freeze)

| Valor | Quando | Direccion |
|---|---|---|
| 16 | golpe normal | `0x1F2E0` |
| 28 | clash | `0x1F15E` |
| 0 | si `$64` bit 5 | `0x1F2D8` → `0x1F2F4` |

```asm
01f2d8:  btst.b   #$5, $64(a3)
01f2de:   bne.b   $1f2f4
01f2e0:  move.b   #$10, $69(a3)    ; 16
01f2e6:  move.b   #$11, $75(a3)
01f2ec:  move.b   #$10, $69(a4)
01f2f4:  move.b   #$0,  $69(a3)    ; bit 5 puesto -> sin freeze
01f2fa:  move.b   #$1,  $75(a3)
01f300:  move.b   #$0,  $69(a4)
```

`$75` va siempre con `$69 + 1`. Los dos son reset a 0 en el camino sin hit
(`0x1F16C`).

**Prioridad** — el juego mira primero el global y solo si es 0 mira `$69`:

```asm
012af4:  cmpi.b   #$0, $f55a.w
012af8:   bne.b   $12b2e
012afc:  cmpi.b   #$0, $69(a5)
012b00:   bhi.b   $12b36
```

Con freeze lo que hace es **saltarse el tick del frame data** (`jsr $1eb40`) y el
recalculo de posicion (`jsr $156f0`), yendo directo a `0x12B2E`. Y `$69` lo
decrementa `0x12B36`: **es un timer**.

**Ojo: hay 16 gates, no uno.** `$1EB40` tiene 16 llamadores y cada uno tiene su
propio `jmp $1580` a 18 bytes. Son 16 estados del personaje con su propia condicion
de freeze, y **el hit-time de una especial tiene que estar en uno de ellos**.

### `$F558` / `$F55A` — CAMARA LENTA de muerte, no freeze

**Este NO es hit-time, y se descarto por agotamiento: `$F558` tiene un solo
escritor en todo el ROM y siempre pone 160.**

Lo que hace no es congelar: es **ralentizar a la mitad**. En `loc_01EDFA`, `$F558`
se decrementa y `$F55A` se prende **solo en los frames en que el contador es
impar**:

```asm
01edfa:  cmpi.w   #$0, $f558.w
01ee02:  subq.w   #$1, $f558.w
01ee06:  move.w   $f558.w, d0
01ee0a:  btst.b   #$1, d0
01ee10:  move.b   #$1, $f55a.w
01ee18:  clr.b    $f55a.w
```

**Medido en ejecucion:** aparece **cuando un personaje muere** y dura **entre 150
y 170 frames**. Y frena **todo** —proyectiles, elementos del stage y scroll—
porque `$FFF558` es **global**, mientras que `$69` es por personaje.

**No es acumulativo:** `loc_01FA70` es una asignacion (`move.w #$a0,$f558.w`) con
**un solo llamador** en todo el juego, `0x1F4F4`. Por eso se puede seguir golpeando
a un muerto y la lentitud se mantiene: cada golpe vuelve a clavar 160.

**Y se dispara con `$78` negativo**, o sea con el HP en negativo. Ojo: en
`loc_01F4CA` hay **dos** `blt` distintos, y el de `0x1F4D0` es del test de `$78`
(HP), no del de `$7E` (stun) de abajo:

```asm
01f4ca:  cmpi.w   #$0, $78(a4)     ; HP
01f4d0:   blt.b    $1f4f4          ; HP < 0 -> camara lenta
01f4d6:  cmpi.w   #$0, $7e(a4)     ; stun
01f4dc:   blt.b    $1f4e2          ; stun < 0 -> knockdown
```

**Del maná en la muerte: nada.** Las unicas escrituras a `$B8` en `0x1E000`-`0x20000`
son las del bonus de combo (`0x1FA12`). **Medido: un muerto no pierde maná.**

---

## 6. Blockstun — la DIRECCION abierta, el VALOR medido

Se leyeron completos los tres resolvers y **los tres van a dano**, ninguno a
block:

| Resolver | Que resuelve | Direccion |
|---|---|---|
| `loc_01EEE2` | grab descriptor vs hurtbox | `0x1EEE2` |
| `loc_01F090` | clash vs clash | `0x1F090` |
| `loc_01F21E` | hitbox vs hurtbox | `0x1F21E` |

El branch de block esta en otro lado. Candidatos sin verificar:

| Offset | Pista |
|---|---|
| `+$63` | mascara de defensa del defensor: `and.b $63(a4),d0` en `0x1F320` |
| `+$64` bit 5 | bit que anula el hitpause (`0x1F2D8`) |
| `+$71` bit 1 | decide `$5F = $2C` o `$2D` (`0x1F3F6`) |
| `+$6C` bits 0-5 | estado; testeado en `0x1F2FA` y `0x1EF2A` |
| `+$94` / `+$70` | mascara de estados golpeables (§1) |

**Valor medido en ejecucion: 32 frames.** Es una medicion, no una lectura, asi que
va anotada aparte y no como dato del ROM.

### Donde hay que mirar: NO es `$7E`

**El resolver tiene dos caminos de dano**, y esto es lo que acota la busqueda:

```asm
01f320:  and.b   $63(a4), d0     ; mascara de defensa del DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414         ; == 0 -> camino COMPLETO

loc_01f3d6:                      ; camino REDUCIDO
01f3d8:  move.b  $65(a3), d0
01f3dc:  lsr.b   #$2, d0         ; daño = $65 / 4
01f3de:  addq.b  #$1, d0
         ...                      ; NO toca $7E
01f410:  bra.w   $1f50a

loc_01f414:                      ; camino COMPLETO
01f424:  sub.w   d0, $78(a4)     ; daño entero
01f42c:  sub.w   d0, $7e(a4)     ; y STUN
```

| | Completo | Reducido |
|---|---|---|
| Daño | `$65` entero | `$65 / 4 + 1` |
| Stun | si | **no** |

Existe un camino que **hace daño sin meter stun**: es el perfil del chip damage y
del golpe bloqueado. Por eso **el blockstun no esta en `$7E`** — si un golpe puede
damagear sin pasar por ahi, stun de golpe y stun de bloqueo no pueden ser el mismo
campo.

**Donde mirar:** despues de `0x1F32C`, que es donde el golpe bloqueado prepara el
empujon (`$10 = $2B000`, `$14 = $FFFC0000`, `$6A = 1` en `0x1F33A`) antes de caer
al reducido. Ojo con el `beq.b $1f3f0` de `0x1F3D4`, que puede saltar el reducido
entero: no es automatico.

Los tres freezes quedan asi:

| Sistema | Valor | Donde |
|---|---|---|
| Hitpause | 16 | `0x1F2E0` |
| Clash | 28 | `0x1F15E` |
| Blockstun | **32** | **sin localizar** |

Que 32 > 28 > 16 tenga todo el sentido (bloquear duele mas que un clash, y un
clash manda mas que el freeze de un golpe) **no es una prueba**: es coherencia, y
un numero medido sin direccion no se puede implementar leyendo el codigo.

**Lo que no se puede hacer: dar el 32 por bueno.** Si en el HUD aparece como
constante (`BS_MAX`), tiene que quedar marcado como medido, no como verificado, y
al lado la direccion pendiente. Inventar la direccion para que el 32 quede
"resuelto" seria hacer que un dato conjeturado parezca verificado.

---

## 7. Receta para sacar el frame data

1. Leer el puntero de `+$8C` → base de la tabla del personaje.
2. Para cada move: `a2 = $50(a5) + word[id_move*2]`.
3. Contar frames hasta el fin de la lista (**el limite de la lista esta
   ABIERTO**, no se encontro en el rango leido) y sumar `+0` de cada registro
   → duracion total.
4. Startup = suma de `+0` hasta el primer frame con bit 6 en el byte de
   atributos de la tabla del personaje.
5. Recovery = suma de `+0` desde el ultimo frame con bit 6 hasta el fin.
6. Golpes hasta knockdown = `ceil($80 / $66)`, con `$66` del blob.

El punto 3 es el unico que falta por confirmar y es lectura, no ejecucion.
