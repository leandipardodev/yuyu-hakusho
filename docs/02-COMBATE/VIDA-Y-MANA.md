# La vida y el mana

---
## 2. Sistema de vida

| Dato | Valor | Direccion |
|---|---|---|
| Base del slot de P1 | **`$FF8400`** (el juego lo usa como `$8400`) | `tst.l $ffff8400.l` en `0x10D2C`, `movea.w` en `0x1EE34` |
| Offset del HP dentro del struct del jugador | **`$78`** (word **signed**) | `sub.w d0,$78(a4)` en `0x1F3E0` |
| Instruccion que aplica dano | `sub.w d0,$78(a4)` | `0x1F3E0` |
| Valor al final de la pelea | **`-1024`** (`$FC00`) | `move.w #$fc00,$78(a5)` en `0x1A1A4` |
| **HP maximo** | **223** `[MEDIDO]` | observado en 2 inicios de ronda, 2 personajes distintos. Los umbrales 111/112 caen en `223/2`. Ver §2 |
| ( unexplained ) | `$78` se inicializa a `$FF` (255) | `move.w #$ff,$78(a5)` en `0x12AE6` y `0x13688`. **De ahi salga 223 no esta escrito en ningun sitio**: pendiente abierto |
| HP que se dibuja | **NO: `$7A` es la BARRA ANIMADA**, no el HP. Persigue a `$78` de a 1 por frame | `subq.w #$1` / `addq.w #$1` en `0x157A8` / `0x157AC`. Con HP < 112 toma `$C00E` (`0x15784`) |
| Umbral de HP bajo | **111** (`$6F`), **11** comparaciones | `cmpi.w #$6f,$78(a5)` |
| Segundo umbral | **112** (`$70`), 1 vez | `cmpi.w #$70,$78(a5)` en `0x15784` |
| Umbral visual de HP | 112 (`$70`) | `cmpi.w #$70,$78(a5)` en `0x15784` |
| Comprobacion de KO | `bge` / `bmi` sobre `$78` | `0x15BCC`, `0x15BD8` |
| Maná / TA (recurso gastable) | **largo 16.16 en `$B8`**; la palabra ALTA es el entero, max **223** (`$DF`) | `move.l #$df0000,$b8(a5)` en `0x1A2E2` |
| Pagar coste de movimiento | `loc_019C46`: `pagar(coste)` | `0x19C46` |
| Umbral de maná bajo | 32 (`$20`) | `cmpi.w #$20,$b8(a5)` en `0x1CD70` |

## 2a. El cálculo del maná

**El maná NO es un word: es un largo 16.16.** La prueba es que
`0x1A2E2` escribe `move.l #$df0000, $b8(a5)`: el 223 queda en `$B8`-`$B9` y
`$BA`-`$BB` es la parte decimal. Por eso todos los `cmpi.w` de umbral comparan
solo contra la palabra alta.

### Ganancia

| Qué | Dónde |
|---|---|
| Ritmo por frame: `add.l $10(a5), $b8(a5)` | `0x1A2C6` |
| Acumulador del ritmo `$10` (16.16) | `0x1432A` = `$fff80000`, `0x14356` = `$80000` |
| Ráfaga fija **+16**: `addi.w #$10, $b8(a5)` | `0x1A882`, `0x1B160` (cuando `$5B` llega a 0) |
| Clamp a 223: `cmpi.w #$df` → `move.l #$df0000` | `0x1A2CA`, `0x1A2E2` |

O sea: `$10` es un **acumulador de ritmo en coma fija**. La parte decimal va
sumando sola y cuando pasa de 1 arrastra un entero al maná. Eso explica por que
el maná sube a saltos y no de forma continua.

### Gasto

| Qué | Dónde |
|---|---|
| `pagar(coste)`: `sub.w d0, $b8(a5)`, solo si había maná | `0x19C4E` |
| Goteo **−1** por frame: `subq.w #$1, $b8(a5)` | `0x1A4EA`, `0x1C460` |
| Drenaje fuerte: `subi.l #$4000, $b8(a5)` (−1.0 en 16.16) | `0x1BFCE` |
| Poner a cero: `clr.l $b8(a5)` | `0x1C016` |

### Umbrales

| Valor | Significado | Dónde |
|---|---|---|
| 223 (`$DF`) | tope | `0x15C36`, `0x1A2CA` |
| 222 (`$DE`) | casi lleno | `0x1D12A` |
| 200 (`$C8`) | umbral de bonus | `0x1581A` |
| 32 (`$20`) | maná bajo | `0x1CD70` |

**Lo que NO está medido:** el ritmo por estado. Solo se han localizado dos
escrituras de `$10` (`0x1432A`, `0x14356`); falta entrar en combate y leer el
valor que hay en `$10` en cada movimiento para tener la tabla completa.

### Carga por HIT de combo — **VERIFICADO CONTRA EL ROM**

**El maná por combo sale del contador nativo `$C6`.** La rutina completa es
`loc_01f9C8`, y el orden de las dos operaciones es lo que define la tabla:

```asm
loc_01f9f0:
01f9f0:  addi.b   #$1, $c6(a4)      ; 1ro: SUMA el contador
01f9f6:  cmpi.b   #$10, $c6(a4)
01f9fc:   bcs.b    $1fa0a
01f9fe:  move.b   #$10, $c6(a4)     ; tope 16
01fa04:  bset.b   #$0, $a0a4.w
loc_01fa0a:
01fa0a:  clr.b    d0
01fa0c:  move.b   $c6(a4), d0
01fa10:  asl.w    #$1, d0           ; 2do: d0 = $C6 * 2
01fa12:  add.w    d0, $b8(a3)       ; y SUMA el maná del ATACANTE (a3)
01fa16:  cmpi.w   #$df, $b8(a3)
01fa1c:   blt.b    $1fa26
01fa1e:  move.l   #$df0000, $b8(a3) ; tope 223
```

**Regla verificada: el maná sube `2 * n`, con `n` = número de golpe contando
desde el PRIMERO, y `+32` de golpe 16 en adelante.**

| Golpe | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17+ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Maná | 2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 | 22 | 24 | 26 | 28 | 30 | 32 | 32 |
| Acumulado | 2 | 6 | 12 | 20 | 30 | 42 | 56 | 72 | 90 | 110 | 132 | 156 | 182 | 210 | 240 | 272 | +32 |

El acumulado es exactamente **`n * (n + 1)`**: 272 al llegar a 16 golpes, que es
el tope real (de ahi sale el flag `bset #$0` de `0x1FA04`).

**CORRECCION a la tabla de web que estaba antes acá.** Venia de `newton.com.tw`
(`min(2 * (n - 1), 32)`, "nada hasta el segundo golpe") y estaba marcada como NO
verificada. Los valores por golpe y el acumulado **coinciden**, pero el
**numero de golpe va corrido en uno**: el ROM da **+2 en el PRIMER golpe**, no
nada. La fila "Acumulado" de la tabla web es en realidad `n*(n+1)` de `n = 1..16`,
con la etiqueta de golpe corrida una posicion.

> `(cancelado)` → `sistema_maná.recup_por_hit` tiene la
> version corrida. Corregir al usar.

### Cuando se resetea `$C6` — con un hueco que no es obvio

No basta con decir "fuera del rango `$20`-`$30`". Los branches son:

```asm
01f9c8:  cmpi.b   #$20, $5f(a4)     ; < $20  -> reset
01f9ce:   bcs.w    $1fa6a
01f9d2:  cmpi.b   #$30, $5f(a4)     ; > $30  -> reset
01f9d8:   bhi.w    $1fa6a
01f9dc:  cmpi.b   #$27, $5f(a4)     ; > $27  -> seguir mirando
01f9e2:   bhi.b    $1f9e6
01f9e4:   bra.b    $1f9f0           ; <= $27 -> SUMAR
01f9e6:  cmpi.b   #$2e, $5f(a4)
01f9ec:   bcs.w    $1fa6a           ; $28..$2D -> RESET
```

| `$5F` del defensor | Efecto |
|---|---|
| `$20`–`$27` | **suma** el contador |
| **`$28`–`$2D`** | **RESETEA**, aunque esta dentro de `$20`–`$30` |
| `$2E`–`$30` | **suma** el contador |
| fuera de `$20`–`$30` | reset |

**El rango `$28`–`$2D` es un agujero dentro de la ventana:** esos 6 estados
rompen el combo en vez de continuarlo. Es el unico detalle de esta rutina que no
se ve leyendo solo los dos `cmp` extremos.

El reset es `clr.b $c6(a4)` en `loc_01FA6A` (`0x1FA6A`), que **no tiene `rts`
propio**: cae dentro del retorno de `loc_01FA6E`. Y `$C6` nunca se inicializa en
los bloques de init de round: arranca en 0 por el borrado general del struct.

### Donde vive `$C6`: en el DEFENSOR

`a4` es el defensor y `a3` el atacante, en toda la rutina. Por eso:

- **Para leer el combo de P1 hay que leer `$C6` del slot del P2.**
- El maná que se suma es **el del atacante** (`$B8` en `a3`), no el del defensor.

Un tercer consumidor, que ademas muestra que `$C6` mueve un efecto:

```asm
01fa50:  move.b   $c6(a4), d0
01fa54:  addi.b   #$81, d0
01fa58:  lsl.w    #$1, d0           ; ($C6 + $81) * 2
01fa5a:  move.w   d0, $3c(a0)       ; magnitud dependiente del combo
```

`$3C` del objeto resuelto en `$1FAAE` vale `2 * ($C6 + 129)`: +2 por golpe de
combo. **Que campo es todavia OPEN**, pero el escalado es verificable.

### El recorte del contador

`$C6` se clampa a **16** (`0x1F9FE`), y al clavarse prende el bit 0 del byte
`$A0A4` (`bset.b #$0, $a0a4.w`, `0x1FA04`). El tope de 16 del contador y el tope
de 32 del maná por golpe son el mismo numero de dos formas: maná = `$C6 * 2`.

> El `LLUVIA RECTA.LUA` **ya no la usa**: el bloque de combos se eliminó al
> dejar el script solo con las cajas (ver docs/08-DIARIO/MEMORIA.md). La tabla sigue viva para
> el remake (`(cancelado)` → `sistema_maná.recup_por_hit`).
> No la busques en el Lua.

**Correccion importante:** `$B8` **no** es el HP. `loc_019C46` no es la rutina de
daño sino `pagar(coste)`: si `$B8 >= d0` lo resta y devuelve distinto de cero,
si no devuelve 0. Los callers pasan 8, 12, 16 al entrar en estados de
movimiento especiales (`0x1894A`, `0x18962`, `0x18992`, `0x189B2`), o sea que
es el precio de un especial. El 223 medido antes era el tope del maná, no el
del HP.

**El HP maximo tampoco esta en `$8054` / `$54(a5)`.** `$54` y `$56` son
acumuladores de empuje (shove) que se suman a la posicion del frame y se borran
en `loc_0156F0`. Ver `COLISIONES-Y-HITBOXES.md` §2. El offset `$4E` sigue sin
identificar.

