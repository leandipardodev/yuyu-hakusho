# El struct del jugador en RAM

*Los offsets del jugador ($40-$A0) y lo que hay en cada uno.*

---
## 3. Estructura de jugador en RAM

Base de los slots: **`$FF8000 + n*$400`**, con P1 en `$FF8400`.

**El array tiene CUATRO slots y el juego los recorre entero.** Hay dos bucles
identicos que arrancan en `$8400`, avanzan de a `$400` y **terminan en `$9000`**,
o sea que recorren `$8400`, `$8800`, `$8C00`, `$9000`:

```asm
01c06a:  lea.l    $8400.w, a0
01c06e:  move.b   $6e(a0), d1
01c076:   beq.b    $1c07e
01c078:  move.b   #$ff, $69(a0)
01c07e:  cmpa.w   #$9000, a0     ; <- para acá
01c082:   beq.b    $1c096
01c084:  adda.w   #$400, a0      ; <- avanza de a $400
01c088:  bra.b    $1c06e
```

El segundo esta en `0x019C64` con la misma forma y el mismo `cmpa.w #$9000`.

Ademas `0x00FAF2` hace un init de struct completo apuntando a **`$8800`**:
`move.l #$12668,$0(a0)`, `$70 = 4`, `$24 = $4280`, `$40 = $3d0`, `$3E = $d8`,
`$26 = $94`.

**O sea: los cuatro son slots reales del array.** Por eso el "stride `$C00`" que
propone una fuente externa **no se puede descartar leyendo el codigo**: que el
stride del array sea `$400` no dice en que slot esta P2. Un array de 4 con P1 en
el indice 1 y P2 en el indice 4 produce exactamente `$C00` entre ambos.

Ver "Lo que NO esta verificado": el conflicto de P2 sigue abierto y se resuelve
midiendo, no leyendo.

| Offset | Contenido |
|---|---|
| `$08` / `$0C` | posicion en pantalla X / Y, **calculada por `loc_0156F0` y CLAMPADA**. No hay que recalcularla (ver §3f) |
| `$28` / `$2A` | velocidad X / Y |
| `$40` / `$44` | posicion en mundo X / Y: **16.16 con la parte ENTERA en la palabra de direccion baja** (ver §3f) |
| `$42` / `$46` | **la parte FRACCIONAL** de ese 16.16. **NO son la "mitad alta"** |
| `$54` / `$56` | offset de empuje acumulado en el frame (se borra cada frame) |
| `$9C` | **NO es el ID de personaje.** Es un rascador de coordenada: se copia a `$44` (Y de mundo) en **19 sitios** (`move.l $9c(a5),$44(a5)` en `0x19CEE`, `0x19DBC`, `0x19DF6`...) |
| `$9E` | **NO es un selector de personaje.** Es la mitad alta de ese 16.16: `move.l #$1310000,$9c(a5)` deja `$9C = $0000` y `$9E = $0013` |
| `$26` | **un indice**, el cursor de una tabla de desplazamientos (ver §5c) |
| `$58` | codigo **solo al morir** (ver §5d) |
| `$6A` | nivel de empuje 1/2/3, **NO** blockstun (ver §5e) |
| `$59` / `$5A` / `$5B` | frame de animacion / duracion / contador |
| `$5F` | id de move o estado |
| `$61` | facing (0 = derecha, 1 = izquierda; medido en ejecucion) |
| `$64` bit 5 | anula el hitpause del golpe (ver §5a) |
| `$69` | hitpause (16 al recibir golpe, 28 en clash) |
| `$75` | siempre `$69 + 1` |
| `$78` | **HP actual** (word signed, **max 223**, llega a `-1024` al final) |
| `$6F` | **el bando/equipo**: el byte que usan las rutinas del fin de ronda (`$F852`/`$F88C`/`$F8F2`) para saber si queda un solo bando vivo. Se copia a `$6E` al caer (`$01A1CA`). [ROM] |
| `$7A` | **la BARRA ANIMADA**, no el HP: persigue a `$78` de a uno por frame |
| `$7E` / `$80` | stun actual / stun maximo. `$7E` = **`$FF` (255)** es el **sentinel de proteccion** al levantarse (`0x1A282`), y cuenta hacia abajo |
| `$84` | velocidad del knockdown (la calcula el resto de `$7E` en `0x1F4E2`) |
| `$86` | se pone en `$FF` en el camino de daño COMPLETO (`0x1F41A`); qué representa, sin identificar |
| `$B8` | maná / TA, recurso gastable (max 223) |
| `$BC` | maná que se dibuja, persigue `$B8` de a uno por frame (ver abajo) |
| `$C6` | **contador de combo recibido**, vive en el defensor, tope 16 (ver §2a) |

### 3f. [CORRECCION 07-10] `$40`/`$44` son 16.16 con el ENTERO en la palabra baja

**Lo que estaba anotado estaba mal en las dos partes.** Decia que `$40/$42` era X
"en dos mitades" y que `$42` era la "mitad alta", y que por eso un teletransporte
largo se veria ahi. Las dos cosas son falsas.

#### `$42` y `$46` son la parte FRACCIONAL

En el ROM **no existe ni un solo acceso a `$42(a5)` ni a `$46(a5)`**: no hay
`move.w`, ni `tst`, ni `clr`. Solo aparecen dentro de accesos largos a `$40` y
`$44`. O sea que no son un campo aparte con su propio nombre.

Y en ejecucion [MEDIDO 07-10], del mismo teletransporte:

| | Y de mundo | fraccion |
|---|---|---|
| en el aire | `314` | `38400` |
| en el piso | `320` | `0` |

`38400 = 0x9600` es `0,586 px` en 16.16. **Un cambio de 38400 a 0 en la misma Y
es un movimiento de 6 px, no un salto de 38400.** El script tomaba ese cambio por
un teletransporte y de 7 reportados **5 eran falsos**.

#### El formato: 16.16 con la parte entera en la palabra de direccion baja

Lo confirman cuatro cosas del ROM:

```asm
; 1. La velocidad se suma como 16.16 COMPLETO
014aa0:  move.l  $10(a5), d0
014aa4:  add.l   d0, $40(a5)      ; $10/$12 es un par 16.16
014aa8:  move.l  $14(a5), d0
014aac:  add.l   d0, $44(a5)      ; $14/$16 = $FFFC0000 = -4,0 px

; 2. El clamp y el sprite leen la PALABRA, como posicion en px
0156f0:  move.w  $40(a5), d0
0161c2:  move.w  $40(a5), -$5a00(a1)   ; tabla de sprites

; 3. Hay caminos que mueven SOLO la palabra y dejan la fraccion como estaba
015034:  add.w   d1, $40(a5)      ; el paso de la tabla de senos
015046:  add.w   d1, $44(a5)

; 4. Y una correccion en 16.16, que son 1,5 px
015408:  subi.l  #$18000, $40(a5)
015410:  addi.l #$18000, $44(a5)
```

El punto 4 es el que cierra el formato: `#$18000` en 16.16 son **1,5 px**, una
deriva lenta de diagonal. En cualquier otro punto fijo serian 24 px o 0,09 px, y
ninguno de los dos tiene sentido en una rutina de spawn (`$3E = $D8`,
`$59 = $FF`, y randomiza `$40` a `$E0..$17F` y `$44` a `$80..$9F`).

**Consecuencia practica: un teletransporte se mide sobre `$40`/`$44` (los
enteros), nunca sobre `$42`/`$46`.** Y si se quiere el subpixel, la cuenta es

```
dx = (entero_actual - entero_anterior) + (fraccion_actual - fraccion_anterior) / 65536
```

#### `$08`/`$0C` ya SON la posicion en pantalla, y no hay que recalcularla

```asm
loc_0156f0:
0156f0:  move.w  $40(a5), d0
0156f4:  sub.w   $a014.w, d0          ; - base del stage
0156f8:  addi.w  #$80, d0
0156fc:  add.w   $54(a5), d0          ; + el offset de vaiven de 1 frame
015700:  cmpi.w  #$40, d0
015706:  move.w  #$40, d0             ; CLAMP bajo X = 0x40
01570a:  cmpi.w  #$1ff, d0
015710:  move.w  #$1ff, d0            ; CLAMP alto X = 0x1FF
015714:  move.w  d0, $8(a5)
01571c:  move.w  $44(a5), d0
015720:  sub.w   $a016.w, d0
015724:  add.w   $f566.w, d0          ; + scroll vertical
015728:  addi.w  #$20, d0
01572c:  add.w   $56(a5), d0
015730:  cmpi.w  #$40, d0
015736:  move.w  #$40, d0             ; CLAMP bajo Y = 0x40
01573a:  cmpi.w  #$1c0, d0
015740:  move.w  #$1c0, d0            ; CLAMP alto Y = 0x1C0
015744:  subq.w  #$8, d0              ; <- el "-8" del hitbox HUD es ESTE
015746:  move.w  d0, $c(a5)
```

**`$08`/`$0C` es lo que el juego cree que es la posicion en pantalla, con el clamp
puesto.** Recalcularlo es redundante y peor.

**Y el `CAL_X, CAL_Y = -127, -127` del hitbox HUD NO va con el jugador.** [MEDIDO
07-10] con mundo X = 1025 y base `$A014` = 973:

| | valor |
|---|---|
| `$08` del juego | **180** |
| lo que imprimia el script | 53 |
| diferencia | **127** |

Esos 127 son la calibracion de las CAJAS del HUD, que tienen otro ancla que el
origen del personaje. Aplicada al jugador da 127 px de error en los dos ejes,
sin avisar. Lo mismo con el `-8`: es el `subq.w` de `0x15744`, no una
calibracion.

*** El `+ 0x80` de X y el `+ 0x20` de Y tambien son parametros de `loc_0156F0`,
no una convencion del HUD. ***

### `$BC` es la barra del maná, y `$7A` es la del HP

**Los dos hacen lo mismo y con el mismo mecanismo.** `$7A` persigue a `$78` y
`$BC` persigue a `$B8`, de a uno por frame:

```asm
015832:  move.w   $bc(a5), d0
015836:  cmp.w    $b8(a5), d0
01583a:   beq.b    $158ae       ; ya iguales -> no dibuja nada
01583c:   blt.b    $15842
01583e:  subq.w   #$1, d0       ; la barra baja de a 1
015840:   bpl.b    $15844
015842:  addq.w   #$1, d0       ; o sube de a 1
015844:  move.w   d0, $bc(a5)
015848:  move.w   d0, d2
```

O sea que las barras **no saltan**: interpolan frame a frame hacia el valor real.
Por eso escribir solo `$78` o solo `$B8` y dejar la barra sola tarda en llegar, y
por eso el valor que hay que leer para el numero es `$78`/`$B8` y no `$7A`/`$BC`.

**Esto documentaba solo la mitad:** estaba `$7A` y faltaba `$BC`.

