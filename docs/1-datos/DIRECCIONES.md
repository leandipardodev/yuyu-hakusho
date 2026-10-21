# DIRECCIONES — la tabla maestra

Todo lo que se sabe de la memoria del juego, en un solo sitio. Cada dirección
lleva **de dónde sale**:

| Marca | Significado |
|---|---|
| **[ROM]** | leído en el desensamblado `datos/desensamblado_68000.asm` |
| **[MEDIDO]** | medido en el emulador (FBNeo) con los `.lua` de `herramientas/lua/` |
| **[NOTAS]** | viene del repo de notas (`notas/`), que es donde mediste tú |
| *** | afirmación **sin verificar**: se escribe con su procedencia, pero no como hecho |

> Las direcciones van con **$** delante cuando están en el bus de 16 bits y con
> **#** cuando son de 32 bits, como en el desensamblado.

---

## 1. El jugador

### 1.1 Dónde vive

| Dato | Valor | Dirección | Fuente |
|---|---|---|---|
| Base del slot P1 | `$FF8400` (el juego lo usa como `$8400`) | `tst.l $ffff8400.l` en `0x10D2C` | [ROM] |
| Slot P2 | `$FF8800` **o** `$FF9000` | — | *** sin resolver, ver §9 |
| Slots P3 / P4 | `$FF8C00` / `$FF9000`, stride `$400` | — | [MEDIDO] |
| Registro base del struct | `a5` | — | [ROM] |

### 1.2 Los campos del struct

| Offset | Qué es | Trampa |
|---|---|---|
| `$06` | contador de paso | |
| `$08` / `$0C` | posición **en pantalla**, ya calculada y con clamp (`loc_0156F0`) | no hay que recalcularla |
| `$0C`→`$0C` | | |
| `$18` | índice de secuencia | |
| `$24` | offset de tiles del personaje en VRAM | |
| `$28` / `$2A` | **velocidad** X / Y | |
| `$3C` | parámetro de estado | |
| `$3E` | escala temporal (256 = 1.0) | |
| `$40` / `$44` | posición **en mundo**, 16.16 con el entero en la palabra **baja** | `$42`/`$46` son la **fracción** |
| `$50` | puntero a la **tabla índice de moves** del personaje | |
| `$54` / `$56` | offset de empuje del frame | **no** es el HP máximo |
| `$58` | **tipo de objeto** (NO es el id de personaje) | |
| `$59` / `$5A` / `$5B` | índice de frame / duración del frame / tick dentro del frame | `$5B` no es un delay: se desborda a 0 |
| `$5F` | **id de move** | |
| `$60` | variante del move | |
| `$61` | facing (bit 11 de D1 espeja el sprite) | |
| `$63` | **máscara del defensor**: elige el camino del daño y si el golpe aturde | |
| `$64` | 4º byte del blob: empuje (bits 0-1), máscara (2-3), sin daño (bit 4), sin freeze (bit 5) | |
| `$65` | **daño del move, POR FRAME ACTIVO** | |
| `$66` | **stun del move**, por frame activo | |
| `$67` | nibble **alto** del 4º byte del blob | |
| `$68` | nibble **bajo** del 4º byte del blob → **el estado de derribo** | ver §5 |
| **`$69`** | **NO es hitpause**: es la **supresión de hitstun del personaje** | valores: 0, 16, 28, 255 |
| `$6A` | **nivel de empuje**: hace DOS cosas (la amplitud del vaiven visual `$54` y la magnitud del empuje) | decrementa cada frame hasta 1 |
| `$6C` / `$6D` | flags de subsistema / flags (OR con `$6C`) | bits 0-4 → handlers `$15CB0` `$15DE6` `$15E28` `$15EFE` `$15F24` |
| `$6E` | byte de equipo/rol | |
| **`$71`** | bit 1 → elige `$2C`/`$2D` en `0x1F3F6` | **el mejor candidato a blockstun** (mecanismo demostrado) |
| `$73` | flags de input | |
| `$7A` | **barra de HP animada** (persigue a `$78` de a 1 por frame) | **no** es el HP |
| `$7E` | **stun actual** (word) | es un **presupuesto**, no un timer |
| **`$78`** | **HP** (word con signo) | el juego lo aplica en `sub.w d0,$78(a4)` en `0x1F3E0` |
| `$80` | **stun máximo** (word) | |
| `$83` | campo de Kurama | usa `$68 = 6` |
| `$84` | **tres campos distintos**: velocidad de empuje (`$1F4E2`), timer que cuenta hacia abajo (`$1A28E`), acumulador contra 256 (`$1BCB0`) | 13 accesos |
| `$87` | **contador de saltos** | ver §4 |
| `$8C` | puntero a la **sub-lista de moves** | |
| `$90` | puntero a la **tabla de 30 bytes** con velocidades | |
| `$9C` | rascador de coordenada (se copia a `$44`) | **no** es el id de personaje |
| `$9E` | mitad alta del 16.16 de la posición | **no** es el id de personaje |
| `$A0`–`$A3` | segundo frame de la cadena / ids de técnica | |
| `$A6` | id de super (en 9 de los 11 personajes) | |
| `$B8` | **maná / TA** (largo 16.16, la palabra alta es el entero, tope 223) | **no** es el HP |
| `$BC` | **barra de maná animada** | |
| `$C6` | **contador de combo**, vive en el **DEFENSOR** | tope 16 |

### 1.3 Los ids de move (`$5F`)

**68 ids distintos**, rango 0–177.

| Rango | Qué son |
|---|---|
| 0–25 | estados básicos y variantes de normales |
| 35–48 | especiales con efecto disparado |
| 128–177 | reactions / estados avanzados |

**El mismo id significa cosas distintas en personajes distintos** [NOTAS]:

| Id | Kurama | Hiei | Sensui | Yusuke |
|---|---|---|---|---|
| `$A3` | **la planta** | | la carga de la ulti | |
| `$A4` | | (Hiei **no** tiene parry) | el parry alto | |
| `$A6` | la ulti | la ulti | el parry bajo | |
| `$A7` | etapa de la ulti | | el contraataque del parry | |
| `$AC` | | | la bola aérea | el Reigan aéreo |

**El mapa de comandos** (14 ids, los mismos para los 11, medido en Hiei, Kurama,
Sensui y Yusuke) [NOTAS]:

| Comando | Id | Tipo |
|---|---|---|
| A | `$82` | básico |
| Adelante + A | `$83` | básico |
| ABAJO + A | `$86` | básico |
| B | `$80` | básico |
| Adelante + B | `$81` | básico |
| A en aire | `$95` | básico |
| ARRIBA + A en aire | `$94` | básico |
| B en aire | `$90` | básico |
| C (guardia) | `$09` | guardia |
| C + arriba | `$0F` | cambio de plano |
| Adelante o atrás + A (pegado) | `$B8` | **el agarre** |
| A + B | `$A4` | técnica, distinta por personaje |

> **Los tiempos son por personaje, aunque el id sea global.** El A de
> Kuwabara es rapidísimo; el adelante+A de Yusuke también. [NOTAS]

---

## 2. El sistema de vida

| Dato | Valor | Dirección | Fuente |
|---|---|---|---|
| **HP máximo** | **223** | medido en 2 inicios de ronda, 2 personajes | [MEDIDO] |
| (el `$78` se inicializa a `$FF`=255) | | `move.w #$ff,$78(a5)` en `0x12AE6` y `0x13688` | [ROM] — **de dónde salga 223 no está escrito en ningún sitio** |
| Umbral de HP bajo | **111** (`$6F`) | 11 comparaciones `cmpi.w #$6f,$78(a5)` | [ROM] |
| Segundo umbral | **112** (`$70`) | `cmpi.w #$70,$78(a5)` en `0x15784` | [ROM] |
| Valor al final de la pelea | **−1024** (`$FC00`) | `move.w #$fc00,$78(a5)` en `0x1A1A4` | [ROM] |
| Comprobación de KO | `bge`/`bmi` sobre `$78` | `0x15BCC`, `0x15BD8` | [ROM] |
| Maná máximo | **223** (`$DF`) | `move.l #$df0000,$b8(a5)` en `0x1A2E2` | [ROM] |
| Umbral de maná bajo | 32 (`$20`) | `cmpi.w #$20,$b8(a5)` en `0x1CD70` | [ROM] |
| Pagar coste de un move | `loc_019C46` = `pagar(coste)` | `sub.w d0,$b8(a5)` en `0x19C4E` | [ROM] |

### 2.1 El maná

**El maná NO es un word: es un largo 16.16.** La prueba: `0x1A2E2` escribe
`move.l #$df0000,$b8(a5)`, así que el 223 queda en `$B8`-`$B9` y `$BA`-`$BB` es
la parte decimal. Por eso todos los `cmpi.w` de umbral comparan solo contra la
palabra alta. [ROM]

| Qué | Dónde |
|---|---|
| Ritmo por frame: `add.l $10(a5),$b8(a5)` | `0x1A2C6` |
| El acumulador del ritmo `$10` (16.16) | `0x1432A` = `$fff80000`, `0x14356` = `$80000` |
| Ráfaga fija **+16** | `addi.w #$10,$b8(a5)` en `0x1A882`, `0x1B160` |
| Clamp a 223 | `cmpi.w #$df` → `move.l #$df0000` en `0x1A2CA`, `0x1A2E2` |
| **Goteo −1 por frame** | `subq.w #$1,$b8(a5)` en `0x1A4EA`, `0x1C460` |
| Drenaje fuerte (−1.0 en 16.16) | `subi.l #$4000,$b8(a5)` en `0x1BFCE` |
| Poner a cero | `clr.l $b8(a5)` en `0x1C016` |

**El maná ganado:** `+2 * n` con `n` = número de golpe **contando desde el
primero**. El ROM suma el contador **antes** de usarlo (`0x1F9F0` antes de
`0x1FA0C`). [MEDIDO]

> **Aviso**: `datos/parches.json` y las notas tienen tablas de maná **corridas
> un golpe** (empiezan en la clave `"2"`). La regla correcta es 1→2, 2→4…
> 16→32, acumulado 16 = 272.

---

## 3. Los golpes: el registro de 8 bytes

**Todo el sistema de moves gira alrededor de esta estructura.**

```
ID de move ($5F)
  → tabla índice en $50(a5):  destino = base + word[base + id*2]
  → registro de 8 bytes:  destino + frame*8
  → sub-lista en $8C:  entrada = $8C + byte(b1)*4
  → blob de cajas:  sub-lista + word(entrada+2)
```

### 3.1 El registro de 8 bytes

| +offset | Qué es | Va a |
|---|---|---|
| +0 | **duración del frame** (en ticks) | `$5A` |
| +1 | índice de animación → sub-lista | |
| +2 | flags del frame (bit 4 = invulnerable) | `$5C` |
| +3 | flags de subsistema | `$6C` |
| +4 | índice de sonido | `$A030` (cola de **sonido**) |
| +5 | sin uso observado | |
| +6 | velocidad/offset X (sesgo `$80`) | `$28` |
| +7 | velocidad/offset Y (sesgo `$A0`) | `$2A` |

La duración del frame está **confirmada por dos vías**:
`0x1EB5A: move.b $0(a2),$5a(a5)` y `0x19C9C`/`0x19CA0`/`0x19CA4` (comparar
`$5A` contra el tick `$5B`). [ROM] [MEDIDO]

**191 moves reales, no 195**: hay 195 índices pero `indice[191]` es offset 0 en
los diez contextos, y offset 0 = "el move no existe" (el registro caería sobre
la propia tabla de índices). [ROM]

### 3.2 La entrada de sub-lista (4 bytes)

| +offset | Qué es |
|---|---|
| +0 | flags (**bit 6 = este frame genera hitbox**) |
| +1 | valor que va a `$3C` |
| +2 | word: offset relativo al **blob de cajas** |

### 3.3 El blob de cajas

| Offset | Qué es |
|---|---|
| +0 | `$65` **daño** |
| +1 | `$66` **stun** |
| +2 | `$64` **empuje** (bits 0-1 nivel, 2-3 máscara, bit 4 sin daño, bit 5 sin freeze) |
| +3 | nibble **bajo** → `$68`, nibble **alto** → `$67` |
| +4… | cajas de 4 bytes: radioX (bit 7 = hay más), offsetX (sesgo `$80`), radioY, offsetY (sesgo `$A0`) |

Se lee en `0x1EC0E` (`move.b (a2)+, $65(a5)`), `0x1EC12` (`$66`) y `0x1EC16`
(`$64`). [ROM]

**El motor copia el blob a la RAM del objeto** en `$01EC0E`–`$01EC2C`: esa RAM
es **el oráculo**. Los 4 bytes del ROM tienen que ser los mismos. [NOTAS]

### 3.4 El mecanismo del golpe (lo más importante)

`$65`, `$66` y `$64` se leen **los tres del mismo registro de 8 bytes del frame
activo** con `(a2)+` en `0x1EC0E`–`0x1EC16`.

> **Por eso el mismo golpe no da siempre lo mismo**: un golpe con varios frames
> activos tiene un `$65` y un `$64` distintos en cada uno. El daño y el empuje
> varían **juntos**, que es lo que se ve en la práctica.
>
> **Y NO hay escalado por combo**: el camino completo resta `$65` crudo
> (`sub.w d0,$78(a4)` en `0x1F424`, con `d0 = $65` en `0x1F420`), sin
> multiplicador y sin mirar `$C6`. El ~20 % entre dos combos sale de que
> conectaron frames distintos. [MEDIDO]

**El camino reducido** (chip damage / golpe bloqueado) lo elige `$63`: con
`$63 & $64 & $0C == 0` va completo y mete stun; si no, va reducido (2-3, 4x
menos) y **no toca `$7E`**. El cruce está en `0x1F320`. [ROM]

---

## 4. Los saltos

**`$87(a5)` es el CONTADOR DE SALTOS.** [ROM]

| Dirección | Qué hace |
|---|---|
| `0x15E28` | `cmpi.b #$0,$87(a5)` / `bne.w $15ed8` → **si `$87` ≠ 0, no se permite otro salto** |
| `0x1863A` | `addq.b #$1,$87(a5)` → cuenta un salto |
| `0x1B2C8` | `addq.b #$1,$87(a5)` → `bsr.w $1860C` → arranca el salto |
| `0x1860C` | `clr.b $87(a5)` → se limpia al arrancar el salto |
| `0x1B66E`, `0x1BAF6`, `0x19E00` | `clr.b $87(a5)` → se limpia en otras transiciones |
| **`0x18440`** | **la rutina de reset: NO lo limpiaba** ← el bug del doble salto |

**El fix del doble salto** está en `docs/1-datos/PARCHES.md` §8.2: reescribir
`0x18440` para que también haga `clr.b $87(a5)`. Como la rutina crece 2 bytes,
los dos `jsr $18454.l` de `0x15CFE` y `0x15D12` pasan a `jsr $18456.l`.
**Los 18 bytes van juntos.**

---

## 5. Los estados de derribo (`$67` y `$68`)

El 4º byte del blob (`$67` alto, `$68` bajo) dice **en qué estado queda el
rival**. [NOTAS]

| `$68` | Estado | Frames | Qué es |
|---|---|---|---|
| 4 | `$23` | **164** | derribo ciego |
| 5 | `$25` | **290** | derribo **con ventana** |
| 6 | `$26` | **516** | lanzador (el rival sale volando) |
| 7 | `$27` | **390** | alto fijo, sin velocidad |
| **8** | **`$30`** | **430** | **elevación recta** (tiro vertical), **con ventana de frames** |
| 9 | `$2F` | **334** | empuje diagonal (los agarres) |

El byte: `$68 = 4` → `$24` · `$68 = 5` → `$25` · `$68 = 8` → `$28` ·
`$68 = 9` → `$29`. El nibble **alto** es `$67` y se deja en 2.

> **La planta de Kurama** (§6) usa `$68`. El **2º golpe** está en el blob
> `$0D9C66` y su byte de estado es **`$0D9C69`**. En el ROM **inglés** vale
> `$25` ($68=5) y en el **japonés** `$29` ($68=9). [NOTAS] [MEDIDO]

---

## 6. La planta de Kurama

**No es un golpe de Kurama.** Kurama lo **invoca** con el id `$A3`, pero los
golpes **salen de un objeto**: el motor copia el blob del golpe a la RAM del
objeto en `$01EC0E`–`$01EC2C`. [NOTAS]

| Golpe | Blob | `$65` daño | `$66` stun | `$64` empuje | byte de estado |
|---|---|---|---|---|---|
| 1º | `$0D9CFA` | 8 | 4 | `$1E` | `$0D9CFD` = `$25` ($68=5) |
| 2º | `$0D9C66` | 16 | 10 | `$1E` | **`$0D9C69`** |

> La firma `$65=$10 $66=$0A $64=$1E` aparece **3 veces** en 3 MB: en `$0C3AF2`,
> `$0C3B0A` y `$0D9C66`. Las dos primeras tienen `$68 = 0` (hitstun normal, 22
> frames), que no es una caída. La de la planta es la tercera.

**El parche aplicado** (1 byte): `$0D9C69: $29 → $28` → el 2º golpe pasa a
**elevación recta** (estado `$30`, 430 frames, con la ventana de frames
activada hasta la caída al suelo): el rival cae de otra forma y queda mucho
más tiempo para conectar. El 1º golpe **no** se tocó.

> **El error que hubo antes**: el parche que se había entregado era
> `$0D9C69: $25 → $24` sobre el ROM **inglés**, o sea **derribo ciego, 164
> frames**. Aplicado sobre el **japonés** (donde el byte es `$29` = `$68 = 9`,
> 334 frames) daba `$29 → $24`: **de 334 frames a 164**, justo lo contrario de
> lo que se buscaba.

---

## 7. Los objetos y las colisiones

### 7.1 Las cinco listas

| Lista | Base | Contador | Stride |
|---|---|---|---|
| hitbox | `$FFA200` | `$FFA004` | `$10` |
| clash | `$FFA300` | `$FFA006` | `$10` |
| hurtbox | `$FFA400` | `$FFA008` | `$10` |
| pushbox | `$FFA500` | `$FFA00A` | `$10` |
| descriptor de agarre | `$FFA600` | `$FFA00C` | `$20` |

- **Los contadores son offsets EN BYTES**: `n = contador / stride`. Máximo 15.
- En el ASM se escriben en `$00A004`..`$00A00C`; FBNeo los refleja en
  `$FFA004`..`$FFA00C`. Registrar write hooks en **las dos**.
- Entrada de 16 bytes: `+0` X, `+4` Y, `+8` radioX (**bit 7 = terminador**),
  `+9` radioY, `+$C` owner.
- **El owner es un WORD, no un puntero**: el builder hace `move.w a5`, así que
  vale `$8400` / `$8800`. El dispatcher lo recupera con `movea.w`.
- Builder `loc_01EB40`; dispatcher `loc_01EDAC`.

`loc_01EDAC` llama, en este orden: `loc_01EEE2` (agarre), `loc_01F090` (clash),
`loc_01F21E` (hit vs hurt), `loc_01EE1E` (push) y **luego pone a 0** los cinco
contadores. Por eso el hook tiene que leerlos **ahí**.

### 7.2 El pool de objetos

16 objetos de `$80` bytes. El allocator está en `0x1FAB4`:
`addi.w #$80,$a036.w / andi.w #$7ff,$a036.w / movea.w $a036.w,a0 / adda.w
#$9400,a0 / tst.w $4(a0) / move.l d0,$0(a0) / move.w #$80,$4(a0) / clr.w $6(a0)`.

La dirección calculada es `$009400 + indice*$80` (24 bits, `movea.w`
extiende con signo). **No está verificada en FBNeo**: `sonda_objetos.lua` la
autodetecta por firma. [NOTAS]

| Handler | Tipo | Tabla de moves |
|---|---|---|
| `$14BD2` | 16 | `$14DDC` |
| `$14BF0` | 20 | `$14DE6` |
| `$14C18` | 21 | `$14DF6` |
| `$14AEA` | 1 | `$14D76` |
| `$149AC` | `$10` | `$14DDC` (la onda de Itsuki, move 6) |

---

## 8. Globales

| Dato | Valor | Dirección |
|---|---|---|
| Cámara X / Y | `$FFF408` / `$FFF40A` | |
| Base X / Y del stage | `$FFA014` (`$360`) / `$FFA016` (`$20`) | |
| Límites del stage | `$FFA010` / `$FFA012` | |
| Puntero del task de colisión | `$FF8100` = `$1EDAC` | |
| `$F558` | **cámara lenta de muerte** (159 → 0). Su **único** escritor es `0x1FA82: move.w #$a0` = 160 | |
| `$F550` bit 7 | flag de modo desbloqueado / simulación suspendida | |
| `$F55A` | modo completado | |

---

## 9. Lo que NO se sabe

| Dato | Estado |
|---|---|
| **El frame data exacto** (startup/active/recovery) de cada golpe | **no localizado**. El registro de 8 bytes ya está descifrado (§3): falta el parser |
| **Blockstun** | **no hay dirección**. El valor 32 se midió pero es una medida, no un dato. Candidatos: `$71` bit 1 (el único con mecanismo demostrado), `$63`, `$64` bit 5, `$6C` bits 0-5 |
| **El stun real por golpe** | `$7E` es un **presupuesto**, no un timer. Golpes hasta knockdown = `ceil($80/$66)` |
| **El slot de P2: `$FF8800` o `$FF9000`** | hay una medición externa que da `$9000` y nuestra inferencia da `$8800`. **La medición pesa más** |
| **Emparejamiento ID ↔ nombre de move** | sabemos el rango y la agrupación; falta el emparejamiento (los nombres vienen de web, no del ROM) |
| **La IA del juego** | nada |
| **Sprites y paletas** | nada extraído (el ROM los tiene comprimidos) |
| **Estructura de etapas** | parcial: scroll con clamp en 176 |
| **La gravedad y el contacto con el suelo** | sin localizar |
| **Qué significa `$68 = 9`** (el valor del ROM japonés en la planta) | sin medir |

---

## 10. Las 10 tablas de personaje (ctx)

| ctx | Personaje | Tabla de moves | Sub-lista | Tabla de 30 B | Init | Stun máx |
|---|---|---|---|---|---|---|
| 0 | **KURAMA** | `$0BF75A` | `$0C04CA` | `$01251E` | `0x12792` | 40 |
| 1 | Kuwabara | `$0C229A` | `$0C31DA` | `$01253C` | `0x127DC` | 56 |
| 2 | Yusuke | `$0C4EEA` | `$0C5DAA` | `$01255A` | `0x12826` | 48 |
| 3 | **HIEI** | `$0C7C9A` | `$0C8BEA` | `$012578` | `0x12870` | 44 |
| 4 | Sensui | `$0CA6DA` | `$0CB38A` | `$0125B4` | `0x128BA` | 54 |
| 5 | Jin | `$0CCC7A` | `$0CDEFA` | `$0125D2` | `0x12904` | 46 |
| 6 | **ITSUKI** | `$0CF99A` | `$0D069A` | `$0125F0` | `0x1294E` | 40 |
| 7 | Toguro (hermano mayor) | `$0D1E5A` | `$0D2C6A` | `$01260E` | `0x12998` | 38 |
| 8 | Chui | `$0D4A9A` | `$0D59FA` | `$01262C` | `0x129E2` | 48 |
| 9 | Toguro (hermano menor) | `$0D777A` | `$0D85AA` | `$01264A` | `0x12A2C` | 62 |

> **ctx0 = KURAMA**, no ctx7. La prueba son tres fuentes independientes: el mapa
> de stun de `MEMORIA.md` (ctx6 = Itsuki = 40 está medido, así que el otro 40 es
> Kurama), las notas (`CONTEXTO.txt` §22: *"la misma partida que dio KURAMA
> (entrada 2, $0BF75A)"*) y el resto de personajes por su stun.

**Hay 2 tablas más sin asignar**: `$BDCAA` (init `$012ABE`) y `$D9A3A` (init
`$01366C`) — de ellas no se sabe a qué personaje pertenecen.

---

## 11. Las reglas del juego (medidas por ti)

Estas no son direcciones: son **reglas**. Están desarrolladas en
`notas/GENERAL/SISTEMAS.txt` (478 líneas, se lee entero) y resumidas aquí. [NOTAS]

| Regla | Qué dice |
|---|---|
| **Los comandos son globales** | 14 ids, cero excepciones, medidos en Hiei, Kurama, Sensui y Yusuke |
| **El id es la ranura, el dato es del personaje** | el mismo id significa cosas distintas en cada personaje |
| **Los tiempos son por personaje** | aunque el id sea global |
| **El maná no tiene precio por id** | hay un **precio base** y un **factor** |
| **El maná ganado** | `+2 * n` desde el primer golpe |
| **El daño tiene un piso** y el juego le suma | |
| **El daño no es un dado** | hay un "dado del daño" con su propia lógica |
| **Dos familias de golpe** | una aplica stun, la otra no |
| **El stun tiene bloqueo** | tres piezas: presupuesto, gasto y bloqueo |
| **La cadena de caída** | completa hasta `$2B` |
| **15 objetos identificados** | con su rango de proyectiles |
| **8 niveles del Reigan** | con 6 closes medidos |

**El archivo que se lee entero:** `notas/GENERAL/SISTEMAS.txt`.
**El que se busca con grep:** `notas/GENERAL/CONTEXTO.txt` (el diario, por
rondas) y `notas/GENERAL/HIT STATE.txt` (la tabla de reacciones).
