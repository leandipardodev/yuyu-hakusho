# FÍSICA Y MOVIMIENTO — datos verificados del ROM

Extraídos por análisis estático del desensamblado. **No requieren emulador.**

## 1. Estructura del jugador (offsets sobre A5)

| Offset | Contenido | Evidencia |
|---|---|---|
| `$08` | **posición en pantalla X** (world → screen en `loc_0156F0`) | `0x1E02: move.w $8(a5),d2` |
| `$0C` | **posición en pantalla Y** (idem) | `0x1E0E: move.w $c(a5),d3` |
| `$24` | id/índice gráfico del personaje | cargado desde tabla `$D23A` |
| `$28` | **velocidad X** | `0x1E0A: add.w $28(a5),d2` |
| `$2A` | **velocidad Y** | `0x1E16: add.w $2a(a5),d3` |
| `$3E` | **escala temporal** (256 = 1.0) | escrita con `#$100` en 5 sitios |
| `$3C` | ? | tabla `$D222`; se usa como índice en varias tablas |
| `$14` | **long de 32 bits** (ocupa `$14..$17`) | ver nota |
| `$40` / `$44` | **posición en mundo** X / Y (32 bits) | base de las coordenadas de caja |
| `$54` / `$56` | **offset de empuje acumulado en el frame** | `loc_0156F0`, ver corrección |
| `$54` | ~~HP máximo~~ → **CORREGIDO**, no es el HP | ver abajo |
| `$4E` | **sin identificar** (antes decía "umbral HP débil") | — |
| `$5F` | **id de move / estado** | escritura más frecuente |
| `$61` | facing (0 = derecha, 1 = izquierda) | `btst.b #$0,d5` en el builder de cajas |
| `$69` | hitpause (16 al recibir golpe, 28 en clash) | `0x1F2E0`, `0x1F15E` |
| `$78` | **HP actual** (word signed, max 255) | `sub.w d0,$78(a4)` en `0x1F3E0` |
| `$7A` | HP que se dibuja, persigue a `$78` | `cmp.w $78(a5),d0` en `0x1579C` |
| `$7E` / `$80` | **stun actual / máximo** (word) | `COLISIONES_Y_HITBOXES.md` §7 |
| `$B8` | maná / TA, recurso gastable (max 223) | `loc_019C46` = `pagar(coste)` |

### Corrección sobre `$54` (importante)

`$54` **no es el HP máximo**. `loc_0156F0` (`0x156F0`) lo usa así:

```
0156f0:  move.w  $40(a5), d0     ; X en mundo
0156f4:  sub.w   $a014.w, d0     ; - base X del stage
0156f8:  addi.w  #$80, d0
0156fc:  add.w   $54(a5), d0     ; + empuje de este frame
015714:  move.w  d0, $8(a5)      ; -> posición en pantalla
015718:  clr.w   $54(a5)         ; se borra cada frame
```

`$54` y `$56` son **acumuladores de empuje (shove)**: se suman a la posición
del frame y se ponen a cero. Y (idem con `$56` y `$F566`):

```
screen_x = world_x - $A014 + $80 + $54          ; clamp [0x40 .. 0x1FF]
screen_y = world_y - $A016 + $F566 + $20 + $56 - 8 ; clamp [0x40 .. 0x1C0]
```

El HP máximo es la **constante 255** (`$FF`), no un campo:
`move.w #$ff,$78(a5)` en `0x12AE6`. Umbral de vida baja 111 (`$6F`),
`cmpi.w #$6f,$78(a5)` en 14 sitios.

El 223 (`$DF`) y el umbral 32 (`$20`) que se habían medido antes pertenecen a
`$B8`, que es el maná: `move.l #$df0000,$b8(a5)` en `0x1A2E2` y
`cmpi.w #$20,$b8(a5)` en `0x1CD70`. Ver `AGENTS.md` §Trampas.

### Nota sobre `$14` / `$16` (corrección)

`$14` y `$16` **no son dos campos**: forman **un único valor de 32 bits** que
ocupa `$14..$17`. Se ve en usos como `0x5E30: move.l $14(a5),$ff54.w` y
`0x6C84: move.l $14(a5),d0`, que leen 4 bytes desde `$14`.

Por eso la rutina `0xD1A6` escribe una palabra en `$14` y otra en `$16` de
tablas distintas, pero en realidad va rellenando el mismo largo.

Además se le escriben constantes de 32 bits grandes:
`#$40000` (`0x6CBA`), `#$0` (`0x6CC4`), `#$FFFE0000` (`0x6CCE`), lo que sugiere
un **acumulador** (energía espiritual, o un valor en punto fijo de 16.16), no
un simple parámetro de estado.

Combinando los valores de las dos tablas, el largo por entrada queda:
`0x200C, 0x280C, 0x280C, 0x200C, 0x200C, 0x280E, 0x200C, 0x280C, 0x1012,
0x280E, 0x2810, 0x200C`. **Pendiente de decodificar.**


## 2. Modelo de movimiento

Rutina en `0x1E02`:

```
0x1E02: move.w $8(a5), d2     ; X actual
0x1E06: subi.w #$80, d2       ; origen centrado en 128
0x1E0A: add.w $28(a5), d2     ; + velocidad X
0x1E0E: move.w $c(a5), d3     ; Y actual
0x1E12: subi.w #$80, d3
0x1E16: add.w $2a(a5), d3     ; + velocidad Y
```

Después, en `0x1ED8`:

```
0x1ED8: muls.w  $3e(a5), d5   ; escalar por la escala temporal
0x1EDC: asr.l   #8, d5        ; >>8  (punto fijo)
0x1EDE: sub.w   $f408.w, d5   ; restar origen de cámara
0x1EE2: add.w   d2, d5
0x1EE4: andi.w  #$fff8, d5    ; ← posición alineada a 8 píxeles
```

**Consecuencias para el remake:**
- Las posiciones están en **punto fijo escalado por 256** (`$3E`, valor normal 256).
- **Las posiciones se alinean a una rejilla de 8 píxeles.** Un personaje solo
  puede estar en múltiplos de 8. Eso explica por qué el movimiento se ve a
  "saltos" y no continuo.
- El origen del personaje está **centrado** (se resta 128).
- La orientación está en el **bit 11 de D1**; cuando está activo se espeja el
  sprite (`neg.w d5` / `addi.w #$80,d5`).

**Cuidado: `$08`/`$0C` y `$40`/`$44` no son el mismo espacio.** `$08`/`$0C` es
la posición ya proyectada a pantalla (con el clamp del stage), y es la que usa
la lógica de colisiones. `$40`/`$44` es la posición libre en mundo. La cámara
del renderer es `$F408`/`$F40A`. Ver `COLISIONES_Y_HITBOXES.md` §3.

## 3. Tablas de estado (rutina `0xD1A6`)

Carga **8 tablas paralelas** indexadas por el id de estado (D0):

| Tabla ROM | Campo destino | Contenido |
|---|---|---|
| `$D222` | `$3C(a5)` | desconocido |
| `$D23A` | `$24(a5)` | id gráfico del personaje |
| `$D252` | `$08(a5)` | **posición X inicial** |
| `$D26A` | `$0C(a5)` | **posición Y inicial** |
| `$D282` | `$28(a5)` | **velocidad X** |
| `$D2A2` | `$2A(a5)` | **velocidad Y** |
| `$D2BA` + `$D2D2` | `$14(a5)` | **un mismo largo de 32 bits** (ver nota) |

Separación entre tablas: `$18` = 24 bytes = **12 entradas**.

### Valores (12 entradas, signed 16 bit)

| id | `$3C` | `$24` | X init | Y init | **vX** | **vY** | `$14` | `$16` |
|---|---|---|---|---|---|---|---|---|
| 0 | 236 | 256 | 244 | 240 | 0 | 0 | 12 | 32 |
| 1 | 204 | 2368 | 312 | 232 | **8** | **16** | 12 | 40 |
| 2 | 292 | 384 | 264 | 232 | 0 | **24** | 12 | 40 |
| 3 | 82 | 448 | 288 | 240 | 0 | **16** | 12 | 32 |
| 4 | 286 | 512 | 326 | 240 | 0 | 0 | 12 | 32 |
| 5 | 242 | 576 | 168 | 232 | 0 | **8** | 14 | 40 |
| 6 | 244 | 2688 | 200 | 240 | 0 | 0 | 12 | 32 |
| 7 | 176 | 704 | 224 | 232 | 0 | 0 | 12 | 40 |
| 8 | 210 | 2816 | 408 | 184 | 0 | **−16** | 12 | 16 |
| 9 | 222 | 2880 | 352 | 232 | 0 | **−8** | 14 | 40 |
| 10 | 2 | 2944 | 400 | 232 | 0 | 0 | 16 | 40 |
| 11 | 0 | 960 | 424 | 252 | 0 | 0 | 12 | 32 |

### Lectura

- **vX = 8 solo en el estado 1** → caminar avanza exactamente **una celda de
  8 px por frame** (compatible con la alineación a 8 px).
- **vY negativa = subir.** Estado 8 = **−16** (impulso de salto) y estado 9 =
  **−8**. Estados con vY positiva (24, 16, 8) son **caída**.
- `$24` (256, 384, 448, 512, 576, 704, 2368, 2688, 2816, 2880, 2944, 960) no
  es monótona, así que no es un índice de tiles directo; parece un
  identificador compuesto. **Pendiente de decodificar.**
- Hay **12 entradas y 11 personajes**: encaja con "11 personajes + 1", pero es
  hipótesis, no hecho verificado.

## 4. Sprites

- Tamaño de celda: **32 × 32 px = 4 × 4 tiles**. Confirmado en `0x1F58`:
  `move.w #$8F80,(a0)+` — el nibble de tamaño `$F` son 4 tiles horizontales y
  4 verticales.
- El origen está centrado (offset −128), coherente con celdas de 32 px.

## 5. Mapa completo de tablas de parámetros

Barrido de todo el idioma `lea.l $TABLA.l, aX` + `move.(b|w|l) (aX,dN.w), $OFF(a5)`
sobre el desensamblado. **10 tablas** alimentan el struct del jugador:

| Base ROM | Offset destino | Entradas | Qué es |
|---|---|---|---|
| `$D222` | `$3C` | 12 | estado |
| `$D23A` | `$24` | 12 | offset de tiles del personaje en VRAM |
| `$D252` | `$08` | 12 | posición X inicial |
| `$D26A` | `$0C` | 12 | posición Y inicial |
| `$D282` | `$28` | 12 | **velocidad X** |
| `$D2A2` | `$2A` | 12 | **velocidad Y** |
| `$D2BA` | `$14` | 12 | acumulador de 32 bits |
| `$10C3E` | `$3C` | secuencia | valores por paso, índice en `$18(a5)` |
| `$11028` | `$3C` | secuencia | ídem, con `d1` |
| `$11040` | `$24` | — | otro origen para `$24` |
| `$A04000` | `$10` | — | (leído del buzón del Z80) |

### Rutinas de secuencia / cámara

`$10C3E` y `$11028` no son de personaje sino **secuencias de escena**. La
rutina en `0x4A00` es un desplazamiento de escenario:

```
0x4A14: subi.w  #$10, $8(a5)     ; desplazar X 16 px a la izquierda
0x4A1A: cmpi.w  #$b0, $8(a5)    ; límite = 176
0x4A20: bgt.b   $4a2c
0x4A22: move.w  #$b0, $8(a5)    ; clampear en 176
```

Y el consumidor en `0x4982` usa `$18(a5)` como índice y `$6(a5)` como
contador de paso.

## 6. Tablas POR PERSONAJE — encontradas

### 6.1 Rutinas de inicialización (0x12792 - 0x12A2C)

Hay **10 rutinas** de inicialización de personaje, separadas por **exactamente
`$4A` = 74 bytes**:

```
0x12792: move.l #$BE93A, $1C(a5)    puntero A
0x1279A: move.l #$100000, $20(a5)   puntero B  (tabla de moves)
0x127A2: move.l #$BF75A, $50(a5)    puntero C
0x127AA: move.l #$C04CA, $8C(a5)    puntero D  ← tabla de moves (confirmado)
0x127B2: move.l #$1251E, $90(a5)    puntero E
0x127BA: move.b #$3, $6C(a5)        constante 3 en las 10
```

| ctx | rutina | `$1C` | `$20` | `$50` | `$8C` | `$90` |
|---|---|---|---|---|---|---|
| 0 | `0x12792` | `$0BE93A` | `$100000` | `$0BF75A` | `$0C04CA` | `$01251E` |
| 1 | `0x127DC` | `$0C0EDA` | `$120000` | `$0C229A` | `$0C31DA` | `$01253C` |
| 2 | `0x12826` | `$0C3ECA` | `$140000` | `$0C4EEA` | `$0C5DAA` | `$01255A` |
| 3 | `0x12870` | `$0C69DA` | `$160000` | `$0C7C9A` | `$0C8BEA` | `$012578` |
| 4 | `0x128BA` | `$0C97AA` | `$180000` | `$0CA6DA` | `$0CB38A` | `$0125B4` |
| 5 | `0x12904` | `$0CBDBA` | `$1A0000` | `$0CCC7A` | `$0CDEFA` | `$0125D2` |
| 6 | `0x1294E` | `$0CE98A` | `$1C0000` | `$0CF99A` | `$0D069A` | `$0125F0` |
| 7 | `0x12998` | `$0D104A` | `$1E0000` | `$0D1E5A` | `$0D2C6A` | `$01260E` |
| 8 | `0x129E2` | `$0D36BA` | `$200000` | `$0D4A9A` | `$0D59FA` | `$01262C` |
| 9 | `0x12A2C` | `$0D643A` | `$220000` | `$0D777A` | `$0D85AA` | `$01264A` |

Observaciones:
- `$20` está separado por **exactamente `$20000` (128 KB)**: son **bancos de
  gráficos**, uno por contexto.
- `$90` está separado por **exactamente `$1E` (30 bytes)**: tabla de registros
  de tamaño fijo (ver 6.2).
- `$6C` vale 3 en las 10 rutinas, así que **no es el ID de personaje**.
- Hay una rutina adicional en `0x1533C` con `$6C = 0` y `$20 = $24B620`.

### 6.2 Tabla `$90`: registros de 30 bytes

Base `$1251E`, 10 entradas, 15 palabras cada una.

| idx | w0 | w2 | w5 | w6 | w9 | w11 | **w13** | **w14** |
|---|---|---|---|---|---|---|---|---|
| 0 | 1 | −6 | 13824 | 1 | 1536 | 8192 | **−16384** | **30** |
| 1 | 1 | −6 | 13824 | 1 | 1536 | 8192 | −16384 | **48** |
| 2 | 1 | −6 | 13824 | 1 | 1536 | 8192 | −8192 | **36** |
| 3 | 2 | −6 | 17408 | 1 | 1536 | 8192 | 0 | **48** |
| 4 | 3 | −7 | 24576 | 1 | 1536 | 8192 | 0 | **48** |
| 5 | 1 | −6 | 12800 | 1 | 1536 | 8192 | −32768 | **36** |
| 6 | 2 | −6 | 12288 | 2 | 1536 | 8192 | −16384 | **30** |
| 7 | 1 | −6 | 13824 | 1 | 1536 | 8192 | −16384 | **48** |
| 8 | 1 | −6 | 14336 | 1 | 1536 | 8192 | 0 | **36** |
| 9 | 1 | −6 | 13824 | 1 | 1536 | 8192 | −16384 | **56** |

- **w13 está en punto fijo 16.16**: −16384 = −1.0, −8192 = −0.5, −32768 = −2.0,
  0. Son **velocidades**.
- **w14 = 30 / 36 / 48 / 56** — candidato fuerte a **duración en frames**.
- w9 = 1536 y w11 = 8192 son constantes en las 10 entradas.

**Pendiente**: falta decodificar qué son w1, w3, w5, w8 y w12, y confirmar si
w14 son frames o subunits.

## 7. FORMATO DEL REGISTRO DE MOVE — descifrado

El consumidor está en **`0x1EB5A`** (el "lector de moves" que se identificó al
inicio del proyecto). Lee el registro **byte a byte** desde el puntero de
`$8C(a5)`:

```
0x1EB5A: move.b  $0(a2), $5a(a5)   ; byte 0  -> flag
0x1EB60: clr.w   d3
0x1EB62: move.b  $1(a2), d3        ; byte 1  -> indice de sublista
0x1EB66: move.b  $2(a2), d5        ; byte 2  -> $5C(a5) prioridad/flags
0x1EB6E: move.b  $3(a2), d0        ; byte 3  -> id de comando
0x1EB82: move.b  $4(a2), d0        ; byte 4  -> indice en tabla $218D8
0x1EB86: lea.l   $218D8.l, a3
0x1EBA6: move.b  $6(a2), d6        ; byte 6  -> velocidad X  (-$80)
0x1EBB0: move.b  $7(a2), d7        ; byte 7  -> velocidad Y  (-$A0)
0x1EBB8: lsl.w   #2, d3            ; sublista x 4
0x1EBBA: movea.l $8c(a5), a2       ; subtabla
0x1EBCE: adda.w  $2(a2, d3.w), a2 ; avanzar al siguiente nodo
0x1EBF2: move.w  d6, $28(a5)       ; escribe velocidad X
0x1EBA0: move.w  d7, $2a(a5)       ; escribe velocidad Y
```

**Tabla del registro (8 bytes):**

| byte | Destino | Significado |
|---|---|---|
| 0 | `$5A(a5)` | flag |
| 1 | sublista ×4 | índice dentro de la subtabla |
| 2 | `$5C(a5)` | prioridad / categoría |
| 3 | — | id de comando |
| 4 | tabla `$218D8` | índice |
| 5 | — | sin uso observado |
| 6 | `$28(a5)` | velocidad X (se le resta 128) |
| 7 | `$2A(a5)` | velocidad Y (se le resta 160) |

**Dato extra (verificado en `loc_01EB40`):** los bytes 6 y 7 se reutilizan
como origen de las coordenadas de caja. Tras escribir la velocidad, el código
hace `add.w $40(a5),d6` y `add.w $44(a5),d7`, de modo que:

```
origen_de_caja_x = world_x + vel_x + (offset_x - 0x80)
origen_de_caja_y = world_y + vel_y + (offset_y - 0xA0)
```

El `-$80` / `-$A0` es un sesgo neutro: los bytes del ROM se guardan como
`0x80 + delta` y `0xA0 + delta`. El offset de caja se niega si el personaje mira
a la izquierda (`d5` bit 0 para X, bit 1 para Y).

### Volcado de `ctx0` (tabla en `$0C04CA`)

| idx | b0 | b1 | **b2** | b3 | b4 | **b5** | b6 | b7 |
|---|---|---|---|---|---|---|---|---|
| 0 | `00` | `00` | **02** | `5C` | `18` | **01** | `02` | `5C` |
| 1 | `18` | `02` | **02** | `6C` | `18` | **03** | `02` | `7C` |
| 2 | `18` | `04` | **02** | `8C` | `18` | **05** | `02` | `9C` |
| 3 | `18` | `06` | **02** | `AC` | `18` | **07** | `02` | `BC` |
| 4 | `18` | `08` | **02** | `C8` | `18` | **09** | `02` | `D8` |
| 5 | `18` | `0A` | **02** | `E8` | `18` | **0B** | `02` | `F4` |
| 6 | `18` | `0C` | **03** | `04` | `18` | **0D** | `02` | `04` |
| 7 | `18` | `0E` | **03** | `24` | `18` | **0F** | `02` | `24` |
| … | `18` | … | **03** | … | `18` | … | `02` | … |
| 13 | `78` | `1A` | **03** | `E4` | `18` | **1B** | `02` | `E4` |
| 14 | `18` | `1C` | **04** | `10` | `78` | **1D** | `02` | `10` |
| … | | | | | | | | |

Observaciones:
- **`b1` avanza exactamente de 2 en 2** → índice de sublista ×4.
- **`b2` agrupa los moves de 6 en 6**: `02`×6, `03`×8, `04`×6… Es una
  **categoría** (probablemente: de pie, agachado, en el aire, proyectil…).
- **`b5` son índices de animación** que avanzan de 2 en 2 (1,3,5,7…).
- **`b3` y `b7` avanzan exactamente de `$20` (32 = un tile)** → son índices de
  tiles/VRAM de la animación.
- **`b6` es constante `02`** → aplicando el `−$80` da −126 en todos, lo que
  **no parece una velocidad real**. Eso indica que la interpretación de `b6` como
  velocidad no es correcta en este contexto, o que `$0C04CA` no es la tabla de
  moves de combate sino otra lista (p.ej. una secuencia de animación).
  **Pendiente de resolver.**

## 8. IDs DE MOVE — anclados

El identificador de move/estado es **`$5F(a5)`**. IDs distintos usados: **68**,
rango **0–177**. Volcado completo en `_disasm_tools/IDS_MOVE.txt`.

### Agrupación

| Rango | Carácter | Dónde se escribe |
|---|---|---|
| **0–25** | Estados básicos y variantes de normales | `0x1845A`–`0x14684`, en orden |
| **35–48** | Especiales con efecto disparado | `0x19C34`–`0x1A1E8` |
| **128–177** | Otra categoría (reactions / estados avanzados) | `0x18818`–`0x1C99A` |

Datos confirmados:
- **ID 11 y 12** son los más referenciados (22 y 11 usos) → estados base tipo
  idle / walk.
- **IDs 1–5 se escriben secuencialmente** en `0x1845A`–`0x1853A`: son variantes
  de un mismo estado, no moves distintos. El selector es **`$5D(a5)`** y
  **`$61(a5)` es un toggle** (el ID 4 hace `d1 = 1 - $61(a5)`), o sea dirección
  o animación alternada.
- Todos terminan en `bra.w $19C1C`, el continuador común.
- **6 IDs solo se comparan, nunca se escriben** (0, 35, 36, 39, 47, 48) →
  estados que solo se entran por condición (reactions).
- Al escribir el ID se pone `$6C(a5) = $0B` (bits 0,1,3 activos) → los tres
  subsistemas de física/animation se encienden por defecto en los normales.

### Corrección importante

**"195 moves por personaje" era incorrecto.** La estructura real es:

```
ID de estado ($5F, 0-177)
   -> tabla indice en $50(a5)      (entrada = 8 bytes)
   -> $8C(a5): cadena de sub-registros de 8 bytes
   -> $218D8: tabla de remapeo
```

Los 195 eran entradas de la tabla índice, no moves. Ver `LISTA_MOVES.txt`.

## 9. Candidatos a frame data YA DESCARTADOS

Para no volver a proponerlos:

| Candidato | Por qué se descartó |
|---|---|
| `$A030` (valores 125, 166) | Es un **disparador de un solo disparo**: `0xF5D6` lo lee, llama a `$21960` y lo limpia. No es un contador. |
| Tabla `$8C` (sublista) | `b5` avanza de 2 en 2 y `b7` avanza exactamente `$10`: son **direcciones de tiles**, no frames. |
| `b6`/`b7` del registro de move | `b6` es constante `$02` en la tabla `$8C`; no son velocidades ahí. (Sí lo son en el registro de `$50`.) |
| `$54` / `$56` como HP o stun | Son acumuladores de empuje del frame, se borran en `loc_0156F0`. |

## 10. Frame data: hay una vía nueva (cajas de colisión)

Las tablas por personaje con startup/active/recovery siguen sin localizarse
(ver §11). Pero **el juego ya publica los frames activos en RAM**, sin
necesidad de esas tablas:

- El builder `loc_01EB40` mete una entrada en la lista de hitbox `$FFA200`
  por cada caja activa, y el contador `$FFA004` es el **offset en bytes** del
  final de la lista.
- Los bits de flags del registro de move deciden qué listas se llenan:
  bit 3 = push, bit 4 = hurt, bit 5 = clash, bit 6 = hitbox.

**Consecuencia:** los frames en los que `$FFA004 / 0x10 > 0` son exactamente
los **frames activos** de cada golpe. Desde el primer frame con hitbox hasta el
último se obtiene **startup + active + recovery**. Sumando sobre una cadena de
golpes se separa cada piece.

Herramienta: `tools/fightcade/yuyu_probe.lua` imprime los contadores por frame,
y `tools/fightcade/LLUVIA RECTA.LUA` los dibuja.

## 11. Lo que sigue sin estar

- **Tablas por personaje**: todavía no localizadas. Son las que contendrían el
  frame data. No aparecen con el idioma `lea + move indexada` sobre `(a5)`, así
  que o usan otra base de registro o acceden a través de un puntero en el
  struct.
- **Gravedad**: no es una constante simple; los valores positivos de `vY`
  parecen estar precalculados por estado.
- **Fricción / empuje** entre personajes. Parcialmente existe: `$54` / `$56` son
  el offset de empuje del frame.
- **Postura y colisión con el suelo**.
- **Decodificar `$14`** (acumulador de 32 bits, valores `0x200C`/`0x280C`/…).
- **Medidor de super**: sin dirección. `$B9` es el byte alto del HP.

