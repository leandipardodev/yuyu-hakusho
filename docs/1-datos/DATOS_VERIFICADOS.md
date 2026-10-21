# DATOS VERIFICADOS

Este fichero es la referencia fiable del proyecto. Contiene **unicamente** lo
que se ha comprobado leyendo el codigo del ROM o ejecutando el juego en
BizHawk. Todo lo demas (guias web, suposiciones) vive en
`FICHAS_DE_PERSONAJES.md` y en `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)*, marcados como `WEB`/`ESTIMADO`
en su bloque `_confianza`.

Regla: si algo no esta aqui, no esta verificado.

---

## 1. Hardware

| Dato | Valor | Fuente |
|---|---|---|
| Plataforma | Sega Mega Drive / Genesis, 68000 + Z80 | lectura del ROM |
| ROM | 3.145.728 bytes (3 MB) | fichero |
| Pistas de codigo 68000 | $000200 - $291ADD (111.420 bytes) | desensamblado |
| Instrucciones 68000 desensambladas | 28.168 | `desensamblado_68000.asm` |
| Driver Z80 | ROM $393FE, $C00 bytes | `desensamblado_z80.asm` |
| Resolucion | 320 x 224 | cabecera del ROM |

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
> dejar el script solo con las cajas (ver MEMORIA.md). La tabla sigue viva para
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
en `loc_0156F0`. Ver `COLISIONES_Y_HITBOXES.md` §2. El offset `$4E` sigue sin
identificar.

## 2b. Stun

| Dato | Valor | Direccion |
|---|---|---|
| Stun actual | **word en `$7E`** | inicializado por move en `0x127C8`-`0x12A62` |
| Stun maximo | **word en `$80`** | `move.w $80(a5),$7e(a5)` en `0x15A4A`, `0x18694` |
| Sentinel | `$FF` | `0x1A282` |
| Test de agotamiento | `cmpi.w #$0,$7e(a5)` | `0x19D84` |
| Valores por move | `$26`-`$3E` (38-62) | `0x127C8`-`0x12A62` |

> ***CONTRADICCION SIN RESOLVER — el stun por golpe***
>
> La cifra de arriba es **nuestra, leida del ROM**. El PDF del material externo
> trae su propia columna `stun` por move, y **los dos conjuntos no se solapan en
> nada**:
>
> | Fuente | Valores por move |
> |---|---|
> | **Nuestro** (`0x127C8`-`0x12A62`) | **38 a 62** |
> | **El PDF** (sin direcciones) | **2, 3, 4, 5, 6, 8, 10, 12, 14, 15, 16** y **dos de 64** |
>
> **Por que el PDF parece mas creible, y no por detalle sino por cuadrar con lo
> que se observa jugando:**
>
> | Con stun por golpe | Golpes hasta knockdown (`ceil($80/$66)`) |
> |---|---|
> | 38-62 (nuestro) | **1 golpe, siempre.** Y ningun personaje tendria combos |
> | 2-16 (el PDF) | de **3 a 20 golpes**, segun el move |
>
> Lo primero contradice de frente lo medido: hay golpes basicos que **no**
> tumban y hay que encadenar 2 o 3, y los agarres y especiales **si**. Lo
> segundo lo calza.
>
> **Y el dato que mas pesa: el PDF tiene EXACTAMENTE DOS moves con `stun 64`.**
> Con umbral 40-62, 64 >= umbral, asi que esos dos son los unicos que tumban de
> un golpe. Y son exactamente los dos tipos de golpe "A" que describen.
>
> ***LO QUE HACE FALTA: leer `$66` de esos offsets y ver que valor tienen. Si
> `$26` esta en el rango 2-16 y no en 38-62, nuestra fila de arriba esta
> describiendo OTRO campo y hay que corregirla. Si de verdad vale 38-62, entonces
> el PDF no esta leyendo `$66`.***

**Correccion:** el stun que decide el knockdown es el word de `$7E`, no el largo
de 32 bits en `$14..$17`. Ese largo ya esta decodificado: **es el empujon**
(`$FFFC0000` / `$FFFB0000` / `$FFFA0000` en `0x1F342`, `0x1F364`, `0x1F386`).

**`$7E` es un presupuesto, no un timer.** Se gasta por golpe en `0x1F42C`
(`sub.w $66,$7e(a4)`) y al llegar a 0 hay knockdown en `0x1F4D6`. Por eso los
golpes hasta knockdown son `ceil($80/$66)`. Ver `TABLAS_MOVES_Y_TIMING.md` §4.

`stun_max` (`$80`) por personaje, en orden de ID: **40, 56, 48, 44, 54, 46, 40,
38, 48, 62** (`$28, $38, $30, $2C, $36, $2E, $28, $26, $30, $3E`). Se inicializa
por golpe en las rutinas `0x12792`-`0x12A74`.

**Ojo con HP y mana, que se confunden mucho, y con el 255 del STUN:**

| | |
|---|---|
| **HP maximo** | **223** `[MEDIDO]` — el valor mas alto observado en un inicio de ronda |
| Umbral de HP bajo | **111** (`$6F`), **11** comparaciones |
| El otro umbral | **112** (`$70`), 1 vez, en `0x15784` |
| HP manana | el tope es **223** (`$DF`) |

**CORREGIDO 2026-10-07. Decimos 255 y estaba mal.** Lo que hay:

1. `$78` **es** el HP: word **FIRMADO**, lo gasta el daño en `sub.w d0,$78(a4)`
   (`0x1F424`), baja de 0 y llega a **`-1024`** al final de la pelea. En ejecucion
   se vio la secuencia **223 -> 219 -> 211 -> 6 -> -58 -> -1024**.
2. `$78` se escribe en **tres** sitios de todo el ROM y solo con estos
   immediatos: **`#$FF` (255)** en `0x12AE6` y `0x13688`, y **`#$FC00`** en
   `0x1A1A4`. **No hay ningun 223 escrito en `$78` en ningun lado.**
3. Los cuatro `$DF` (223) del ROM estan todos en **`$B8`**, el mana:
   `0x15C36`, `0x1A2CA`, `0x1B462`, `0x1FA16`.

**Por que 223 y no 255 es lo que dice el codigo, aunque no lo escribamos:**

| | |
|---|---|
| `255 / 2` | 127,5 |
| **`223 / 2`** | **111,5** — y los umbrales son **111 y 112** |

Los dos umbrales de HP caen **exactamente en la mitad de 223**, no cerca de la
mitad de 255. Eso es geometria de barra, no casualidad: el juego parte el HP por
la mitad ahi. Sumado a la medicion (223 en dos inicios de ronda, dos personajes
distintos) y a que los `.lua` que calculan dano dan bien con 223, **el maximo es
223.**

**LO QUE SIGUE SIN EXPLICAR:** para que se vea 223, algo tiene que llevar `$78`
de 255 a 223 en el inicio de ronda, y **no esta escrito en ningun sitio**: no hay
`sub`, ni `add`, ni copia hacia `$78` en todo el ROM. Los unicos dos candidatos
son `0x15BD8` y `0x1A03C`, que son `tst.w $78(a5)` (el test de muerte, no una
escritura). **Queda abierto, y es el pendiente de este punto.**

### El 255 de STUN es OTRO 255, y ese ya lo teniamos

Y la trampa al leer los medidores: **`$7A` NO es el HP, es la barra animada** que
persigue a `$78` de a 1 por frame:

```asm
01579c:  move.w  $7a(a5), d0
0157a0:  cmp.w   $78(a5), d0
0157a4:   beq.b  $15814        ; iguales -> listo
0157a8:  subq.w  #$1, d0       ; va atras -> baja de a 1
0157ac:  addq.w  #$1, d0       ; va adelantado -> sube de a 1
```

y si HP < 112 (`0x15784`) toma un valor especial, `$C00E`. Un `.lua` que lea `$7A`
esta leyendo **la barra**, no la vida.

| Offset | Campo | Que es |
|---|---|---|
| `0x12AE6` | **`$78`** | init de struct (HP) — el que citamos mal |
| `0x1A282` | **`$7E`** | **sentinel de stun = 255** |

**La proteccion de stun que describes es el sentinel de `$7E`, y ya estaba en
este doc desde antes.** Cuando un personaje queda aturdido y se levanta, se le
pone **255 como umbral nuevo**; si recibe golpes antes de que expire, el 255 se
reinicia, y asi no hay ningun personaje que pueda stunear en bucle. Se comprobo en
ejecucion: el log muestra **$7E = 243** y despues **$7E = 239**, o sea el 255
contando hacia abajo.

Y la trampa al leer los medidores: **`$7A` NO es el HP, es la barra animada.**

## 2c. La salida del hitstun es UNA SOLA RAMA, sin test de suelo

La pregunta de si el backflip en el aire y el knockdown salen por el mismo
lugar tiene respuesta en el codigo: **salen por el mismo lugar**.

```asm
01f4ca:  cmpi.w  #$0, $78(a4)     ; HP del defensor
01f4d0:  blt.b   $1f4f4          ;   < 0 = muerto -> loc_01f4f4
01f4d2:  clr.w   $84(a4)          ;   vivo: velocidad de knockdown = 0
01f4d6:  cmpi.w  #$0, $7e(a4)     ; STUN
01f4dc:  blt.b   $1f4e2          ;   agotado -> loc_01f4e2

loc_01f4de:                       ; sigue con stun
01f4de:  bsr.b   $1f524          ;   reaction normal

loc_01f4e2:                       ; STUN AGOTADO
01f4e2:  move.w  $7e(a4), d0
01f4e6:  neg.w   d0
01f4e8:  addi.w  #$4, d0
01f4ec:  asl.w   #$4, d0
01f4ee:  move.w  d0, $84(a4)      ; $84 = (|$7E| + 4) * 16
```

| | |
|---|---|
| Disparador | **uno solo**, `$7E < 0` en `0x1F4D6`. No hay `cmpi` de altura ni de suelo en toda la rutina |
| Lo que escribe | **una sola palabra**, `$84`. Nada mas |
| La animacion | no se decide aca: `loc_01f524` es una **tabla de salto por `$68(a3)`**, o sea por un contador del ATACANTE, no por estar en el suelo |

O sea que **la transicion es la misma en los dos casos**, y lo que los
distingue tiene que estar mas abajo, en la maquina de estados de `$5F`.

**Que es exactamente lo que dice la observacion del usuario:**

| | Cuando | Que sale |
|---|---|---|
| **Backflip** | fin del hitstun **en el aire** | vuelta en el aire, se vuelve a levantar de pie al aterrizar |
| **Knockdown** | fin del hitstun **en el suelo** | caida total y levantarse del suelo |

**Los dos son el MISMO disparador, con distinto estado de salida.** Y coincide
con que la rutina no consulte el suelo en ningun momento: la pregunta "estoy en el
aire" la tiene que responder el estado, no esta rama.

**TRAMPA AL ARMAR LA MEDICION, y casi la cometemos.** El backflip **no** sale
esperando a un enemigo agarrado. Un agarre manda al rival al aire en un estado
de caida en el que **se puede seguir golpeando con suaves**, pero al aterrizar el
resultado es identico a una caida total y necesita levantarse: eso **no** es un
backflip. El backflip aparece **solo, al agotarse la ventana de golpes suaves**,
y sale por el agotamiento del hitstun mientras sigue en el aire.

O sea que el guion correcto es: **un golpe suave a un rival en el aire, y
esperar.** Nada de esperar que el se de vuelta por su cuenta.

### [MEDIDO] El agarre es el UNICO lanzador que deja al rival golpeable

Y esto convierte el backflip en algo raro en juego normal, que es informacion
importante por si sola.

| Como se manda al rival al aire | ¿El siguiente suave conecta? |
|---|---|
| Golpe normal en suelo | No lo manda al aire, solo empuja |
| **Agresion / especial** | Lo manda al aire, **pero knocks down**, asi que los siguientes tambien |
| **Agarre** | **Lo manda al aire y el siguiente B igual conecta** |

Los movimientos cancelables / encadenables son solo los especiales, y los
especiales knocks down. **Sin agarre, cualquier secuencia termina en knockdown
aunque haya ventana de tiempo para conectar.**

**Ojo que el agarre NO produce el backflip.** Lo unico que hace es **poner al
rival en el aire con la ventana abierta**. El backflip es el **fin del hitstun
del golpe suave, estando en el aire**. Por eso son dos cosas separadas y por eso
"esperar a que el rival se de vuelta y despues pegarle" no funciona (la ventana
ya se cerro) mientras que **agarre -> B inmediato -> soltar** si.

**Lo que queda measurable es exactamente lo que el usuario vio en su prueba
propia**: agarre, un B, y la hurtbox del afectado desaparece antes del cambio de
estado. Falta capturarlo con el hook de `$1EDC2` ya arreglado.

### Los TRES desenlaces de una caida, y por que salen de la misma rama

Cuando un enemigo esta en caida por un agarre hay **tres** desenlaces posibles:

| | Que se le hace | Que sale | En el codigo |
|---|---|---|---|
| **1** | Nada: cae derecho al suelo | **knockdown al final**, hay que levantarse | cadena `$25 -> $28 -> $29 -> $2A -> $2B` (76+26+25+21+33 frames), **Y = 320** |
| **2** | Habilidad o golpe de knockdown | **lo mismo que el 1**, con daño extra | **la misma rama**, mas daño |
| **3** | Golpe suave, uno o varios | **backflip** en el aire | **la misma rama**, otro estado |

**Los tres salen de `cmpi.w #$0, $7e(a4)` / `blt.b $1f4e2` en `0x1F4D6`-`0x1F4DC`.
Una sola rama, tres desenlaces.** Lo unico que cambia entre ellos es el estado al
que se cae.

**Y eso es lo que hace distinguible el caso 3:** su `$5F` tiene que ser un valor
que no aparezca en los casos 1 y 2. Con la lista de 45 estados ya medidos, el
backflip tiene que ser **uno que no este en esa lista**.

Tambien explica por que el caso 1 es el que mas se ve: el estado de caida por
agarre **deja conectar golpes suaves** (por eso es el unico lanzador utilizable),
asi que el caso 3 solo aparece si se aprovecha esa ventana. Si no se aprovecha,
la caida sigue hasta el suelo y es el caso 1.

**El desempate entre los tres, en el log, es la Y.** Suelo = el maximo de Y que
muestre el slot; aire = cualquier valor por debajo. En la corrida del 07-10 el
suelo era **320**, y en el aire se vieron 284, 262, 256, 253, 238, 279, 291, 299
y 308.

**Un caso aparte que NO sirve:** Toguro Menor con ARRIBA+A en el aire golpea y
produce knockdown tanto en aire como en suelo, ademas dependiente del tamaño del
enemigo (que se sortea). Knockdown no es backflip.

### [MEDIDO] La hurtbox se va ANTES del backflip, y eso INVIERTE el orden

Medido por el usuario con el HUD de cajas: tras un agarre y **un** golpe suave,
**la hurtbox del enemigo afectado desaparece unos frames antes del backflip**.

| Evento | Que es | Donde |
|---|---|---|
| Contacto | hitpause | `$69 = 16` |
| **Se va la hurtbox** | **invulnerable** | contador `$FFA008`, stride `$10`, owner en `+$C` |
| Cambio de estado | arranca el backflip | `$5F` |

**Lo que cambia con esto es la CAUSALIDAD, no la secuencia.** La suposicion
natural era "el backflip es la recuperacion y por eso se es invulnerable". Si la
hurtbox se va **primero**, es al reves: **la invulnerabilidad provoca el
backflip**, o hay una causa comun que dispara los dos. Con un solo anclaje
temporal no se puede distinguir, asi que hacen falta los **tres frames**.

**Para el codigo es una pista fuerte, porque el contador tiene un solo
escritor util.** `$A008` se escribe en dos sitios de todo el ROM: `0x1ED40` (el
dispatcher devuelve la cuenta) y `0x1EDCE` (la pone en 0). O sea que **la lista
no se vacia por un afterthought del dispatcher: la cadena de cajas deja de
generarse.** Y como el puntero a la lista llega por `$24(a5)`
(`move.w #$a004, $24(a5)` en `0x89C4`), la condicion que la apaga esta ahi.

**Y el estado tiene datos propios**, confirmado en el builder de cajas:

```asm
loc_01eb40:
01eb40:  clr.w   d0
01eb42:  add.b   $5f(a5), d0      ; $5F indexa la tabla de frames
01eb48:  movea.l $50(a5), a2      ; via $50
01eb4c:  adda.w  (a2, d0.w), a2
```

`$5F` elige los datos del frame: duracion en `$5A`, atributos en `$6C`, sonido en
`$A030` via la tabla `$218D8`. Un estado propio del backflip tendria su fila.

**Lo que NO sale de ahi:** en `$1F4D6` no hay ningun test de altura, asi que el
"estoy en el aire" lo responde el estado y no esa rama.

**ABIERTO:** la direccion de la flag que apaga la hurtbox. El desensamblado
alrededor de `$89B0` sale como basura en el ASM y no sirvio para seguirla; habria
que re-desensamblar ese bloque.

## 2d. [MEDIDO 07-10] La formula de `$1F4E2` confirmada, y donde se lee de verdad

### [MEDIDO A MANO 07-10] El backflip: la invulnerabilidad lo PRECEDE por 13 frames

Medido en el emulador **avanzando frame a frame**, con el HUD de cajas.
Referencia: **frame 1 = el instante exacto en que el B impacta**. La secuencia es
**agarre → B en el aire**, y el enemigo sale despedido hacia arriba.

| Frame | Que pasa |
|---|---|
| 1 | Conecta el B |
| 2-15 | **Hitstun.** Se mueve 1 px a un lado y al otro al frame siguiente. Es una animacion de latigazo, casi imperceptible en vivo |
| 16 | **Deja de agitarse y lo repelen hacia arriba y en direccion contraria al atacante** |
| 17-22 | La repulsion se aplica, y **decrece** (17 mas fuerte, 18-22 similar y bajando) |
| 23 | El pusheo sigue decreciendo |
| **24** | **La hurtbox DESAPARECE.** El sprite sigue igual |
| 25 | El sprite se pone de costado. **Este frame tambien se usa en las caidas knockdown** |
| 32 | Sigue la caida, desaparece el cartel "hit 2" |
| **37** | **Cambio de sprite que NO aparece en el knockdown: arranca el backflip** |

### Las tres conclusiones

| | |
|---|---|
| **1** | **La invulnerabilidad PRECEDE al backflip por 13 frames** (24 contra 37). O sea que **el backflip no es lo que vuelve invulnerable**: es al reves. Y como no son el mismo frame, tampoco es causa comun |
| **2** | La invulnerabilidad empieza **en pleno vuelo de retroceso**: el pusheo va del 16 al 23 y se lee "decreciendo hasta volver a valores del 16-17". El personaje queda invulnerable **8 frames despues de que empezo el empuje** |
| **3** | El estado del backflip **no es propio desde el primer frame**: el sprite del 25 es el mismo que usan las caidas knockdown, y la diferencia aparece en el **37**. O sea que entra a un estado compartido y **despues** diverge |

### Y una correccion nuestra: `$69` NO es un freeze

**Este doc (y MEMORIA.md) llamaban "hitpause" a `$69`. Es el TIMER DE HITSTUN, y
no hay congelacion.** La medicion lo dice: si hubiera freeze, el enemigo no se
moveria en los frames 2-15, y se mueve 1 px por frame.

| Frame | Que pasa | Campo |
|---|---|---|
| 1 | El B pega | `$69 = 16` — `move.b #$10, $69(a4)` en `0x1F2EC` |
| 2-15 | Hitstun, el latigazo | `$69` de 15 a 2, con `subi.b #$1, $69(a5)` en 16 sitios |
| **16** | **`$69` llega a 0, el hitstun termina y arranca el pusheo** | `btst.b #$0, $69(a5)` |

**El frame 16 medido es exactamente `$69` arriving a cero.** El numero coincide
solo.

**POR QUE NOS CONFUNDIMOS:** `$69` y `$F558` valen **16 en el mismo golpe**
(`$F558` es el freeze global, §5e). Como tienen el mismo valor en el caso que mas
se ve, el nombre "hitpause" se le quedo pegado al equivocado. **Son dos campos
distintos:** `$F558` es el freeze de toda la pantalla; `$69` es la duracion del
hitstun de ESE personaje.

### Lo que queda abierto, y es lo siguiente que hay que buscar

| Numero | Que hay que averiguar |
|---|---|
| **24 − 16 = 8** | Que dispara la invulnerabilidad 8 frames despues de empezar el empuje. `$84` tiene un **acumulador** (`addi.w #$1` en `0x1BCB0`, `cmpi.w #$100` en `0x1BCB6`) que podria ser el culpable |
| **37 − 24 = 13** | Que decide la divergencia entre backflip y knockdown, cuando el estado ya es el mismo desde el 25. **Lo mas probable: si esta en el aire**, porque en `0x1F4D6` no hay ningun test de suelo |
| **El flag de la hurtbox** | sigue sin direccion. La via es re-desensamblar el bloque de `$89B0`, que sale como basura en el `.asm` |

### **[MEDIDO] EL MISMO GOLPE NO PRODUCE SIEMPRE EL MISMO EFECTO**

> ### ⚠ NO ES UN ERROR DE LOS `.lua`, Y EL EFECTO TIENE MAS DE UNA VARIABLE
>
> Tras reiteradas pruebas se determino que **el mismo golpe, contra el mismo
> personaje enemigo, NO da siempre el mismo resultado**. Hay **entre 2 y 4
> variables implicadas**. Los valores que se ven afectados son **el pusheo y el
> daño infligido al HP**. La barra de aturdimiento **parece no verse afectada** por
> esta flexibilidad.
>
> **Por que NO puede ser un error de medicion de los `.lua`:** el mismo
> comportamiento se ha visto en **distintos emuladores**, y con **savestates que
> siempre cargan en el mismo punto**. Cargar una savestate con el enemigo con poca
> vida, y lanzar un golpe que en teoria no alcanzaria para matarlo, **a veces lo
> mata y a veces no**. Si el escenario es identico y el resultado varia en
> distintas plataformas de emulacion, la variabilidad esta en el juego, no en la
> lectura.
>
> **Y el efecto es visible sin ningun `.lua`:** en el frame 1 del impacto, la
> victima ya aparece **visiblemente mas alejada** antes de la oscilacion del
> sprite. O sea que el desplazamiento es real y se ve a ojo, no es un numero mal
> leido.
>
> **LO QUE SE OBSERVO, con mas detalle.** Con un golpe **B en el suelo** (que no
> produce ni derribo ni backflip, los dos en el suelo):
>
> | Frame | La coordenada X | El sprite |
> |---|---|---|
> | 1 | **cambia 2** | — |
> | 2-15 | **constante** | oscila ±2 |
> | 16 | **constante** | se ajusta 1 y vuelve a la real |
> | **17** | **empieza a cambiar** | — |
>
> Y en el frame 1 el empuje **no siempre es 2**: se han medido **1, 2 y 4**.
>
> **DONDE SE ORIGINA LA VARIABILIDAD:** la relacion medida es con el **frame
> exacto de la animacion de standing del rival**. Cuando la victima esta en su
> animacion de "no hacer nada" —que es animada y sus cajas se mueven, aunque las
> coordenadas no— hay un frame en el que el pusheo es **2**, y otro en el que es
> **4**, de forma consistente al repetir. La victima mas **inclinada hacia
> adelante**, o sea con la hurtbox **mas cerca** del B, da **mas** empuje.
>
> **CORRECCION A ESTA SECCION: `$63` y `$64` NO ELIGEN LO MISMO, y la cuenta de
"hasta 4x" estaba redondeada.**

```asm
01f31c:  andi.b  #$c, d0          ; $64(a3) bits 2-3  -> ¿DAÑO completo o reducido?
01f320:  and.b   $63(a4), d0      ; ... AND con la mascara del DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414          ; == 0 -> COMPLETO
01f32c:  move.b  $64(a3), d0
01f330:  andi.b  #$3, d0          ; bits 0-1           -> ¿que INTENSIDAD de empuje?
```

**`$63` NO participa en la eleccion del empuje.** Decir que "dano y pusheo varian
juntos" era **falso**: son dos campos y dos mascaras.

### La cuenta del "4x", CORREGIDA: es del CAMINO, no de la medicion

**[MEDIDO POR EL USUARIO, y contradice lo que escribimos antes]** Un B causa de **5
a 8** de daño. Un combo completo va de **71 a 86**, o sea 15 puntos y **mas del
20 %**. **NUNCA se vio un golpe que sacke el doble de daño**, ni mucho menos 3x o
4x. Y cuanto mas potente el golpe, mas se nota la diferencia, aunque la
proporcion sea la misma.

**O sea que la variacion de daño OBSERVADA es de un 20-60 %, y la del pusheo es de
1 a 4 px (un factor 4). NO son comparables: el pusheo varia MUCHISIMO mas que
el daño.** Nuestra redaccion anterior ("hasta 4x de daño") tomo una propiedad
aritmetica de un code path y la presento como si fuera la medicion. **No lo es.**

**ADEMAS, LA ARITMETICA MISMA DESDICE LA EXPLICACION QUE HABIAMOS DADO.** Para un
B con `$65 = 8`, el camino reducido daria `$65/4 + 1` = **3**. El usuario midio un
minimo de **5**. **El camino reducido no puede producir ese 5**, asi que no es el
que produce la variacion del B.

| `$65` | Completo | Reducido | Factor |
|---|---|---|---|
| 1 | 1 | 1 | **1x — IDENTICO** |
| 4 | 4 | 2 | 2x |
| 8 | 8 | 3 | 2,67x |
| 16 | 16 | 5 | 3,2x |
| 24 | 24 | 7 | 3,43x |

Estos factores son reales **de los dos caminos**, pero **el camino reducido es el
perfil del chip damage y del golpe bloqueado**, y su reduccion es de 2x a 3,4x.
**Que el dano completo NO lleve ninguna escala** (`sub.w d0, $78(a4)` con `d0 =
$65` crudo en `0x1F424`) confirma que el 20 % de los combos **no viene de un
escalado por combo**: no existe.

### EL MECANISMO REAL: `$65` y `$64` son AMBOS POR FRAME ACTIVO

**Este es el que explica las DOS mediciones del usuario a la vez, y es una sola
cosa: cual frame activo del B conecta.**

Los tres campos salen del **mismo registro de 8 bytes del frame**, leidos con
`(a2)+` uno tras otro:

```asm
01ec06:  btst.b  #$6, d4          ; ¿bit 6 = frame ACTIVO?
01ec0e:  move.b  (a2)+, $65(a5)   ; <- DAÑO, por frame
01ec12:  move.b  (a2)+, $66(a5)   ; <- STUN, por frame
01ec16:  move.b  (a2)+, $64(a3)   ; <- EMPUJE, por frame
```

**Un B con mas de un frame activo tiene un `$65` y un `$64` distintos en cada
uno.** Por eso:

| Lo que midio | Que campo lo produce |
|---|---|
| el B saca **5 o hasta 8** | el `$65` de dos frames activos distintos |
| el pusheo va de **1 a 4 px** | el `$64` de esos mismos frames |
| **daño y pusheo varian juntos** | es la misma eleccion, no dos causas |

**O sea que la correlacion que el usuario vio es REAL y tiene UNA causa, no dos.**
Antes escribimos que eran dos variables de distinta naturaleza (`$63` del defensor
y `$64` del atacante); eso era una lectura del resolutor y no del dato medido.
**La medicion dice que es una sola: el frame activo que conecta.**

**Y el `$63` sigue siendo real, pero es OTRO phenomenon**, el del chip damage y el
golpe bloqueado, con una reduccion de 2x a 3,4x y sin stun. **No explica el B**, y
por eso no hay que forzar la correlacion ahi.

**Y NO HAY ESCALADO POR COMBO.** El camino completo resta `$65` crudo
(`0x1F420`-`0x1F424`), sin multiplicador y sin mirar `$C6` (que se incrementa en
`0x1F9F0`, o sea DESPUES). Asi que el 20 % de diferencia entre combos **no es
prorrateo**: sale de que los frames activos que conectaron fueron distintos.

### Y el empuje tiene DOS tablas, una por camino

Los tres niveles se eligen con `$64 & 3` en los dos caminos, pero **las
velocidades NO son las mismas**:

| Nivel | Camino reducido | Camino completo |
|---|---|---|
| 1 | `$2B000` = 2,69 px/frame | **`$30000`** = 3,00 |
| 2 | `$39000` = 3,56 | **`$40000`** = 4,00 |
| 3 | `$4C000` = 4,75 | **`$56000`** = 5,38 |

Reducido en `0x1F33A` / `0x1F35C` / `0x1F37E`; completo en `0x1F442` / `0x1F464` /
`0x1F486`. Los dos caminos ponen `$6A` = 1, 2 o 3 igual.

### `$2D` lo ASIGNA el juego al pegar, y lo elige el bit 1 de `$71`

**Esto no lo sabiamos y cambia el lectura de `$63`.** `$2D` no es un estado que
aparezca solo: lo pone el resolver, y **`$71` bit 1 del DEFENSOR decide entre
`$2C` y `$2D`**:

```asm
01f3f6:  btst.b  #$1, $71(a4)      ; bit 1 del DEFENSOR
01f3fc:   bne.b   $1f406
01f3fe:  move.b  #$2c, $5f(a4)     ; estado $2C
01f406:  move.b  #$2d, $5f(a4)     ; estado $2D  -> $63 = $08
```

**Y `$2D` es uno de los seis estados que RESETEAN el combo `$C6`** (§ `$C6`). O
sea que el estado que fuerza el daño reducido es **el mismo que corta el combo**:
son la misma idea punitive.

**CONSECUENCIA PARA EL BLOCKSTUN (pendiente 3):** **`$71` bit 1 pasa de "un
candidato entre cuatro" a un campo con mecanismo demonstrado.** Elige el estado
del defensor entre dos, y de ahi sale si el siguiente golpe pega completo o
reducido. Es el mejor candidato de los cuatro, y el unico con un efecto medido.
`$63` en cambio solo se deduce del estado.

### Y el camino reducido no toca el STUN

| | Completo | **Reducido** |
|---|---|---|
| HP (`$78`) | `$65` | `$65 / 4 + 1` |
| **Stun (`$7E`)** | **`sub.w $66, $7e(a4)`** | **no se toca** |

**`$63` decide si el golpe ATURDE, no solo cuanto daño hace.** Con el rival en
estado `$2D` (`$63 = $08`), el mismo B pega **cuarto daño y sin aturdir**. Y eso
explica por que la barra de aturdimiento **no se ve afectada**: **no la toca.**

### El empuje: 4 niveles, y `$64` es DATO DEL MOVE POR FRAME

```asm
01ec06:  btst.b  #$6, d4         ; ¿bit 6 = frame activo?
01ec0e:  move.b  (a2)+, $65(a5)  ; $65 = daño
01ec12:  move.b  (a2)+, $66(a5)  ; $66 = stun
01ec16:  move.b  (a2)+, $64(a5)  ; $64 = el que elige el empuje
```

**`$64` se lee del registro del FRAME ACTIVO**: es **del move**, no del personaje.
Y hay **cuatro** niveles:

| `$64 & 3` | `$6A` | `$10` | `$14` |
|---|---|---|---|
| 0 | 1 | `$2B000` | `$FFFC0000` |
| 1 | 2 | `$39000` | `$FFFB0000` |
| 2 | 3 | `$4C000` | `$FFFA0000` |
| 3 | — | **nada**: cae directo a `$1F398` | |

**ASI QUE LA VARIABILIDAD DEL PUSHEO TIENE SU MECANISMO, y es el timing.** Si el
B tiene mas de un frame activo, cada uno trae su `$64`, y **cual conecta depende
del frame exacto del impacto**.

**Y CIERRA LO QUE HABIA DEJADO ABIERTO: es DETERMINISTA, no hay RNG.** La
savestate fija el mundo pero **no fija la fase de la animacion en el instante del
contacto**. Por eso hacen falta diferencias minimas: un frame de diferencia ya
cambia `$65` y `$64`.

**OJO, ESTE PARRAFO ESTA ANTICUADO y lo corrijo mas abajo.** Decia que hay DOS
variables de distinta naturaleza. **La medicion dice que hay UNA**: el frame
activo que conecta, que trae su `$65` y su `$64` juntos. Ver
*"EL MECANISMO REAL: `$65` y `$64` son AMBOS POR FRAME ACTIVO"*.

**LO QUE SIGUE SIN PROBAR:** que cuanto mas inclinada este la victima (hurtbox mas
cerca) mas empuje, es lo medido — pero **la mecanica de arriba dice que el empuje
NO depende de la proximidad**: depende de que frame activo conecte. O sea que la
proximidad, si algo, actua **cambiando el frame que conecta por timing**, no de
forma directa. Quedan **tres explicaciones** que la medicion no separa: el frame
activo del B que conecta, el frame de la animacion del rival via `$63`, o la
proximidad de la hurtbox (estar golpeando dos a la vez).

> ### El mecanismo encontrado en el codigo: `$63`

**Esto es `[ROM]`.** El resolver decide el camino de daño con un AND de los datos
del atacante y **una mascara del defensor**:

```asm
01f318:  move.b  $64(a3), d0      ; datos del frame del ATACANTE
01f31c:  andi.b  #$c, d0          ; bits 2-3
01f320:  and.b   $63(a4), d0      ; Y LA MASCARA DEL DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414          ; == 0 -> camino COMPLETO (dano entero)
01f32c:  move.b  $64(a3), d0
01f330:  andi.b  #$3, d0          ; bits 0-1 eligen la INTENSIDAD del empuje
01f334:  cmpi.b  #$0, d0
01f338:   bne.b   $1f356          ;   si, otra intensidad
01f33a:  move.l  #$2b000, $10(a4)
01f342:  move.l  #$fffc0000, $14(a4)
01f34a:  move.b  #$1, $6a(a4)     ; nivel de empuje
```

**Y `$63` sale del ESTADO del defensor, con solo TRES valores:**

```asm
015b58:  cmpi.b  #$2d, $5f(a5)     ; ¿el estado es $2D?
015b5e:   beq.b   $15b6a
015b60:  bra.b   $15b72
015b62:  move.b  #$4, $63(a5)      ; $63 = $04
015b6a:  move.b  #$8, $63(a5)      ; $63 = $08   (estado $2D)
015b72:  move.b  #$0, $63(a5)      ; $63 = $00   (normal)
```

**O sea que el mismo golpe pega FULL o REDUCIDO segun en que animacion este el
rival.** Con `$63 = $00` el dano es `$65` entero; con `$63 != $00` es
`$65 / 4 + 1`, y el **stun no se toca**. O sea que `$63` decide **si el golpe
aturde**, no solo cuanto dania. La cuenta del 4x y el detalle estan arriba.

**`$2D` es un estado real:** esta en la ventana de combo `$28`-`$2D` (§ `$C6`) y
aparecio en los 45 estados medidos.

**Y `$63` es uno de los cuatro candidatos de blockstun** (§6 de
`TABLAS_MOVES_Y_TIMING.md`): el camino reducido es el perfil del chip damage y
del golpe bloqueado, asi que la mascara que elige ese camino tiene toda la pinta
de ser el campo del blockstun. Sigue sin direccion del campo, pero **ahora tiene
un mecanismo a favor, que antes no tenia.**

### El mapa completo de un golpe suave, y las TRES correcciones de nomenclatura

Con el B en el suelo, midiendo **coordenadas y sprite por separado**:

| Frame | Que pasa | Campo |
|---|---|---|
| 1 | El B pega | `$69 = 16` (`0x1F2E0`), `$75 = 17`, `$6A` = nivel de empuje |
| 2-15 | **Hitstun SIN desplazamiento.** El sprite oscila y las coordenadas **no se mueven** | `$54` |
| 16 | `$69` llega a 0, el sprite se asienta en la posicion real | `btst.b #$0, $69(a5)` |
| **17** | **El empuje arranca de verdad.** Las coordenadas cambian frame a frame | |

**CORRECCION 1 — `$69` NO es un freeze: es supresion de hitstun POR PERSONAJE.**
`$69` esta en el struct del personaje, con **30 accesos** en `$69(a5)`, asi que en
un 1v4 cada slot tiene el suyo y **un golpe solo toca a los dos involucrados**. Y
**no hay freeze global en un golpe normal**: el unico escritor de `$F558` en todo
el ROM es `0x1FA82: move.w #$a0, $f558.w` = **160**, y esa es la **muerte**. Los
cuatro valores de `$69`, con su escritor:

| Valor | Que es | Direccion |
|---|---|---|
| `16` | golpe normal | `0x1F2E0` |
| **`28`** | **clasheo** (`$1C`), **no 32** | `0x1F15E` |
| `255` | ulti de Itsuki | `0x1C078` |

**Se le decia "hitpause" porque `$F558` vale 16 tambien en un golpe: dos campos
distintos con el mismo numero en el caso que mas se ve.** Por eso "el tiempo se
detiene" era la lectura equivocada: **el tiempo no se detiene para nadie**, lo que
pasa es que **esos dos no tienen animacion.**

**CORRECCION 2 — la oscilacion de 1-2 px NO es desplazamiento.** Es `$54`, un
offset de dibujado de **un frame**:

```asm
012b4a:  moveq   #$0, d0
012b4c:  move.b  $6a(a5), d0      ; d0 = el nivel de empuje
012b50:  btst.b  #$0, $69(a5)      ; ¿el hitstun es PAR?
012b56:   bne.b   $12b62           ;   si -> restar
012b58:  add.w   d0, $54(a5)       ;   no -> sumar
012b62:  sub.w   d0, $54(a5)       ; restar
```

**El signo alterna con la PARIDAD de `$69`** y la amplitud es `$6A`. Se limpia una
vez por frame en `0x15718: clr.w $54(a5)`. Eso produce el vaiven exacto **sin
mover al personaje**, que es lo medido: coordenadas constantes, sprite moviendose.

**CORRECCION 3 — `$6A` es el NIVEL DE EMPUJE, y hace dos cosas a la vez.** Manda
la amplitud del vaiven visual (`$54`) **y** es la magnitud del empuje real. Y
**decrementa cada frame hasta 1** (`0x12B44: subi.b #$1, $6a(a5)`, con
`cmpi.b #$1` / `bls` de corte). Por eso "la repulsion parece multiplicarse y
despues decrecer" era **una sola variable**, no dos fenomenos.

El hitbox del atacante desaparece en el frame **18**, un frame despues de lo que
hara un `.lua` normal, por un cambio de prioridad de dibujado. Como el empuje de
este `.lua` **no toca el orden de dibujo del juego**, ese desfase es de
presentacion y **no corre los frames del ROM**. Y la referencia de frame 1 se
tomó cuando **el enemigo reacciona**, no cuando la hitbox se dibuja encima: que es
justo lo que hay que hacer, porque la hitbox puede adelantarse a la reaccion.

### La formula, en ejecucion

Corrida con `diagnostico_knockdown.lua` (1v1, golpes normales y luego ultis):

```
[f 6446] S4  CONFIRMADO $1F4E2   $7E=13 ->  $84=368   (abs 7E + 4)*16 = 368   HP=78
[f 6446] S4  $7E cruzó 0: 13 -> -19  ;  ESTADO $5F $2F -> $25   | $7E=-19 $84=368 Y=284
```

**`(19 + 4) * 16 = 368`, exacto.** Es la primera confirmacion en ejecucion de que
`$1F4E2` es el unico escritor, y no se trata de creerse el algebra: el numero sale
solo si esa instruccion corrio.

| | |
|---|---|
| `$7E` cruzó 0 y el cambio de `$5F` | **el mismo frame**. La rama de `0x1F4D6` y la transicion de estado coinciden |
| HP | 142 -> 78, o sea 64 de daño |
| Y | 320 -> **284**: airborne en el momento del knockdown |

### `$84` es un VALOR persistente, no una marca de evento

**Estuvo en 368 durante 148 frames** (f 6446 a f 6594) sin cambiar. O sea que
`$84` es la velocidad de empujon acumulada, y **no vuelve a 0 por el mero paso del
tiempo**: se limpia en los dos writers, `clr.w $84(a4)` en `0x1F4D2` y `0x1F416`,
que son los del **siguiente golpe**.

Consecuencia para el diagnostico: "el knockback es un salto desde 0" es una regla
que puede fallar si dos knockbacks seguidos dan el mismo valor. Para el caso del
backflip da igual, pero quedalo anotado.

### Y el stun se repone al terminar el knockdown

```
[f 6573] S4  ESTADO $5F $29 -> $2A   | $7E=-19 $84=368
[f 6594] S4  ESTADO $5F $2A -> $2B   | $7E=34  $84=368
```

`$7E` pasa de **−19 a 34**, y **34 es exactamente el `$7E` con el que empezo el
slot** (f 1708: `S4 presente HP=223 $7E=34`). O sea que se repone `$80 -> $7E`,
que es lo que ya decia la tabla de §2b (`move.w $80(a5),$7e(a5)` en `0x15A4A` y
`0x18694`). **Confirmado en ejecucion, no solo por lectura.**

Secuencia del knockdown en suelo, con duraciones:

| Estado | Frames | |
|---|---|---|
| `$25` | 76 | el knockdown en si |
| `$28` | 26 | |
| `$29` | 25 | |
| `$2A` | 21 | |
| `$2B` | 33 | y aqui se repone el stun |

### DONDE HAY QUE LEER TODO ESTO: `$1EDC2`, no `registerafter`

**Esta es la parte importante, y la aprendimos de una medicion que no sirvio.**

La primera version del script leia todo en `registerafter`. El resultado fueron
7600 frames con **cero** lineas `CONTACTO` y con este parpadeo:

```
[f 7053] S1  hurtbox de vuelta: 0 -> 3
[f 7054] S1  *** SE FUE LA HURTBOX ***
[f 7056] S1  hurtbox de vuelta: 0 -> 3
[f 7057] S1  *** SE FUE LA HURTBOX ***      <- cada ~3 frames, en LOS DOS a la vez
```

**El parpadeo simultaneo en los dos peleadores lo delata: es muestreo, no
invulnerabilidad.** La razon esta en el dispatcher:

```asm
01edac:  btst.b   #$7, $f550.w    ; GUARDIA: si esta busy, saltea TODO
01edb2:   bne.b   $1ee1c          ;   y NO llega a borrar los contadores
01edb4:  bsr.w    $1eee2          ; grab
01edb8:  bsr.w    $1f090          ; clash   -> $69 = 28
01edbc:  bsr.w    $1f21e          ; hit     -> $69 = 16, $7E -= $66, $84
01edc0:  bsr.b    $1ee1e          ; push
01edc2:  move.w   #$0, $a004.w    ; <- ACA se borran los 5 contadores
01edc8:  move.w   #$0, $a006.w
01edce:  move.w   #$0, $a008.w    ; <- hurtbox
```

**`$1EDC2` es el unico instante coherente**: los resolvers ya corrieron (asi que
`$69`, `$7E` y `$84` ya valen) y los contadores **todavia no se borraron**. Ademas
la guardia `btst.b #$7, $f550.w` significa que hay frames en los que el
dispatcher **no borra nada**, y en esos hay que saltarse el frame entero: comparar
una captura vieja contra datos nuevos produce transiciones que no existen.

`diagnostico_knockdown.lua` ahora se engancha con `memory.registerexec(0x01EDAC, ...)` y
descarta los frames sin dispatcher. El guardian tiene test: **3 frames sin
dispatcher tienen que producir CERO lineas.**

### Y el hook va en la ENTRADA, no despues de la guardia

**Esta es la version 2 del script, y fallo con "no lee nada", sin error.** La
version 1 (todo en `registerafter`) daba el parpadeo de arriba. La version 2 se
engancho en `$01EDC2`, que parecia el sitio ideal: los resolvers ya corrieron
(asi que `$69` ya vale) y los contadores todavia no se borraron. **Se callaba
completo.**

La causa es la guarda de entrada:

```asm
01edac:  btst.b   #$7, $f550.w
01edb2:   bne.b   $1ee1c        ; <- $1EE1C es un RTS pelado
...
01edc2:  move.w   #$0, $a004.w  ; <- ahi estaba el hook
```

Cuando el bit 7 de `$F550` esta activo, la rutina **no hace nada**: ni resolvers,
ni borrar contadores. El destino de la guarda es un `rts`. Ese bit lo prende
`$3ADE` y lo apaga `$3AEE`, asi que hay frames con y sin resolvers.

**Un hook puesto del lado equivocado de una guarda no falla: se calla.** El
sintoma es "el script corre, imprime su mensaje de arranque, y no dice nada mas".
No hay error, no hay excepcion, no hay nada que mirar.

**La regla: se engancha en la ENTRADA.** Ahi los contadores siguen siendo los
del frame (se borran despues, en `$01EDC2`) y `$69`, `$7E` y `$84` van con un
frame de atraso porque los resolvers corren despues de la entrada. Ese atraso es
**inofensivo**: `$84` dura 148 frames, `$7E` dura lo que dure, y `$69` se queda en
16 durante 16 frames. Y lo que decide la pregunta, hurtbox contra cambio de `$5F`,
se lee en el mismo instante, asi que nada se corre.

### Y por eso ahora el script tiene LATIDO

Un hook mal puesto se descubre porque no salio nada, que es la forma mas lenta de
enterarse: una ronda entera. Ahora hay una linea cada 600 frames:

```
[f 600]  hook OK: 601 invocaciones en $1EDAC
[f 1200] AVISO: el hook de $1EDAC no ha corrido todavia (invocaciones=601). Si esto sigue, el hook no entra.
```

Las dos tienen test, y hay un test que dice literalmente **"se engancho en la
ENTRADA `$01EDAC`, no en `$01EDC2`"**, que es el que cierra este fallo.

**El backflip NO quedo capturado.** En esa corrida la ventana del backflip fue el
2do golpe y en esa parte del log no hay ningun ancla limpia. Lo que si quedo
capturado es el **knockdown en suelo** de la tabla de arriba, con su formula
confirmada. Falta repetir la corrida con el hook arreglado.

### Estados de `$5F` observados (45 valores)

```
$00 $01 $02 $03 $05 $06 $07 $09 $0A $0B $0C $0D $0E
$11 $13
$20 $21 $22 $24 $25 $28 $29 $2A $2B $2C $2D $2F
$80 $82 $83 $84 $86 $90 $95
$A0 $A1 $A2 $A4 $A6 $A7 $A8 $AA $AC $AE
$B8
```

**Ni `$07`, `$2D` ni `$22` aparecen nunca junto a una perdida de hurtbox** en una
medida limpia, porque no hay medida limpia todavia. **ABIERTO.**

### Y `$7E` llega a valores grandes

`$7E = 243` (f 6627) y `$7E = 239` (f 6734 y siguientes). Cerca del sentinel
`$FF` de `$1A282` (`move.w #$ff, $7e(a5)`) pero no igual. **ABIERTO: que campo es.**

### Y el slot del P2 cambia de verdad entre rondas

Con el mismo script y en la misma sesion:

| Momento | Slots |
|---|---|
| f 867 | **S1 y S2** |
| f 1080 | **S1 y S2** |
| f 1708 | **S1 y S4** |
| f 8474 | **S1 y S4** |

**El slot del P2 no es fijo, y `detectar_slots()` lo agarra solo.** Es la
confirmacion mas directa que tenemos del pendiente 8: no hay que suponerlo, se
detecta por HP. Lo que queda abierto es solo cual es el caso tipico, no si el
deteccion funciona.

Ademas: **HP negativo = muerto, confirmado.** Valores vistos: `-58`, `-1024`.

**Donde la altura SI importa, y es otra cosa.** El empujon justo antes
(`0x1F4A0`-`0x1F4C8`) compara `$9C(a3)` con `$44(a3)` — la Y del atacante contra
la Y del defensor — y si son distintas pone otra velocidad (`move.l #$46000,
$10(a4)` en `0x1F4AA`). Y pasado los limites del stage (`$A010`/`$A012`) copia
la velocidad del defensor al atacante (`move.l $10(a4), $98(a3)` en `0x1F4C4`),
que es el rebote contra el borde. O sea que el empujon es consciente de la
altura, pero eso es una **velocidad**, no el estado.

### `$84` NO es un campo: son tres, y por eso no se podia leer

Regla 3 aplicada a `$84`. Tiene 13 accesos y **3 significados distintos**,
separados por la rutina:

| Routine | Uso | Evidencia |
|---|---|---|
| `$1F4E2` (resolver de golpe, `a4` = defensor) | **velocidad de empujon**, solo al agotarse el stun | `move.w d0, $84(a4)` en `0x1F4EE`; se limpia en `0x1F4D2` y en `0x1F416` |
| `$1A28E` (maquina de estados, `a5` = el jugador) | **timer que cuenta hacia abajo**, con salida en `< 1` | `subq.w #$1,$84(a5)` en `0x1A28E`; `cmpi.w #$1` / `blt $1a2b6` en `0x1A2AA` |
| `$1BCB0` | **acumulador**, comparado contra 256 | `addi.w #$1,$84(a5)` en `0x1BCB0`; `cmpi.w #$100` en `0x1BCB6` |

Y en `$1A28E` hay un medio velocidad: si `$72(a5) != 0` descuenta **2** en vez de
1 (`subq.w #$2,$84(a5)` en `0x1A29A`), o sea el timer dura el doble de frames.
Al salir limpia y llama a `$18440` (`0x1A2B6`-`0x1A2BE`). Ojo que la entrada de
esa rutina pone `$7E = #$FF` (`0x1A282`) — el sentinel de la tabla de §2b — y
copia `$9C` en `$44` (`0x1A288`), que es el campo de coordenada, no un ID.

**Como se cierra el backflip (2 minutos en el emulador).**
`herramientas/lua/diagnostico_knockdown.lua` ya lo hace, y **autoverifica**: como `$1F4E2`
escribe SIEMPRE `$84 = (|$7E| + 4) * 16`, la linea se confirma cuando `$84` es
exactamente ese valor, sin depender de interpretar nada. Y distingue el
knockback (un salto **desde 0**) del timer de `$1A28E` y del acumulador de
`$1BCB0`, que son las otras dos rutinas que tocan `$84`. Verificado con
`test_knockdown.lua` (13 pruebas), y en particular la que hace util el script:
**el timer NO confirma nada**.

Si se hace a mano, mirando `$84` del slot (P1 = `$FF8484`, P2 = `$FF8884` o
`$FF9084`) en paralelo con `$7E`:

| Situacion | Que tiene que pasar |
|---|---|
| Golpe suave (B) | `$84` sigue en 0 |
| Tras un agarre en el aire, primer golpe suave | `$84` sigue en 0 |
| **El frame en que arranca el backflip** | **si `$84` salta a nonzero, el backflip es el MISMO disparador**; si sigue en 0, es otro camino |
| Golpe knockdown (A) en el aire | `$84` salta a nonzero en ese mismo golpe |

Mirar los dos (`$7E` y `$84`) en el mismo frame separa las dos hipotesis de una
sola vez. Ojo: el valor de `$84` es `(|$7E|+4)*16`, o sea que **cuanto mas
hundido quedo el presupuesto, mas fuerte el empujon**.

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

## 3b. Camara y scroll

| Direccion | Que es | Evidencia |
|---|---|---|
| `$FFF408` / `$FFF40A` | origen de camara X / Y | `sub.w $f408.w,d5` en `0x1EDE` |
| `$FFA014` / `$FFA016` | base X / Y del stage (init `$360` / `$20`) | `0x457A`, `0x4586` |
| `$FFF566` | scroll vertical acumulado | `add.w $f566.w,d0` en `loc_0156F0` |
| `$FFA010` / `$FFA012` | limites del stage | `0x1EFE4`, `0x1EFF4` |

## 3c. Colisiones

Documentacion completa en **`COLISIONES_Y_HITBOXES.md`**. Resumen:

| Lista | Base | Contador | Stride |
|---|---|---|---|
| hitbox | `$FFA200` | `$FFA004` | `$10` |
| clash | `$FFA300` | `$FFA006` | `$10` |
| hurtbox | `$FFA400` | `$FFA008` | `$10` |
| pushbox | `$FFA500` | `$FFA00A` | `$10` |
| descriptor de grab | `$FFA600` | `$FFA00C` | **`$20`** |

Entrada de 16 bytes: `+0` X word, `+4` Y word, `+8` radioX (bit 7 =
terminador), `+9` radioY, `+$C` owner.

**Los contadores son offsets en bytes, no cantidades**: `n = contador / 0x10`,
maximo 15 cajas.

## 3d. [CORRECCION 07-10] Hay 191 moves, no 195 — y our volcado NO estaba desalineado

El material externo afirma dos cosas sobre nuestra tabla de moves. Las dos se
auditan contra el ROM con `herramientas/desensambladoauditar_moves.py`:

| Afirmacion | Veredicto |
|---|---|
| "el volcado esta **desalineado**" | **Falso.** **1950 de 1950 entradas** coinciden byte a byte con el ROM. Nuestra herramienta ya salta el indice de words |
| "hay **191** moves por contexto, no 195 ni 401" | **Cierto.** `indice[191]` es offset 0 en **los diez** contextos |

**El mecanismo, que estaba a la vista desde el principio** (`loc_01EB40`):

```asm
01eb42:  add.b   $5f(a5), d0      ; d0 = id de move
01eb46:  add.w   d0, d0           ; x2 -> offset de WORD
01eb48:  movea.l $50(a5), a2      ; a2 = base de la tabla INDICE
01eb4c:  adda.w  (a2, d0.w), a2   ; a2 += indice[$5F]   <-- hay indice
```

`$50` **no es** la tabla de frames: es una tabla de **indices de word**, y el
destino sale de sumarle el indice a la misma base. Por eso hay **195 indices pero
solo 191 moves**.

**Offset 0 = el move no existe**: el registro cae en la propia base, o sea que se
esta leyendo la tabla de indices como si fueran frames. Nuestras 4 entradas
finales por contexto (191 a 194) son **basura por construccion**, y se ven:

```
ctx0 191 $0BF75A   1  128 $01 $B0 $01 B8  -127    32   <- bytes del indice
ctx0 194 $0BF75A   1  128 $01 $B0 $01 B8  -127    32   <- los mismos
```

**Y el "401" del ctx9 tambien estaba mal.** `limites_tablas.txt` decia `moves=401`
para ctx9 y `195` para los otros nueve. No: los diez son 195 indices y 191 moves.
El 401 era el tamaño de la tabla de datos leido como cantidad de moves.

### Lo que queda pendiente de esto

`volcado_moves.txt` tiene las 1950 entradas con direccion y son correctas, pero
**cada move tiene VARIOS registros de 8 bytes** (su cadena de frames) y nosotros
guardamos **solo el primero**. Por eso los golpes hasta knockdown no se pueden
calcular todavia, y por eso el pendiente 2 ("parser de los 8 bytes") sigue abierto.

El material externo **si tiene** las cadenas completas, pero **su documento dice
explicitamente "Sin direcciones de memoria"**, asi que por la regla 2 no entra
en `DATOS_VERIFICADOS.md` hasta que se cruce con el ROM.

**El cruce hay que hacerlo asi, no contando numeros.** El campo del PDF donde van
`Startup · Activo · Recovery` **y** la cadena de frames **se pisan en la misma
columna**, y las filas vienen en tres formas distintas:

```
34  | 3  | 32 | 8 · 8 · 16                             sin cadena visible
18  | 10 | 30 | 4 · 12 · 8 · 6 · 255 · 255 · 255 ...   cadena pegada al triple
184 | 9  | 48 | 20 · 4 · 24 | → daño 16 | 12 pos ...   cadena en columna aparte
```

Un intento de cruce dio **33,6 % de acuerdo**, y ese numero **no dice nada del
documento: dice de mi parser**, que no sabe donde arranca la cadena. Los
desacuerdos eran sistemáticos (los moves 6 y 7 del ctx0 con la misma cadena). **No
se reporta como hallazgo.** Para cruzar bien hay que apoyarse en las filas con
columna de daño, donde la cadena esta separada, y verificar contra el registro de
8 bytes del ROM.

Ojo tambien: `dur 255` es un frame de **bucle** (vuelve al inicio, los de andar) y
**no suma** a la duración total, y `dur 0` es frame fin.

## 3e. Consolidado del material del 07-10 (guia + PDF de movelist)

Dos ficheros en el escritorio: `GUIA_TECNICA_UNIFICADA.md` (925 -> **1127**
lineas) y `MOVELIST_COMPLETA.pdf` (**79 paginas**, 2.172 moves).

**Como se leyo el PDF**, porque no hay manera directa: este modelo no acepta PDF
y en la maquina no hay `pdftotext` ni `pypdf` ni `pdfminer`. Se escribio un
extractor con `zlib` de la stdlib: recolecta cada fragmento `BT..Tm..Tj`, los
ordena por **Y descendente y X ascendente** (cada fragmento lleva su propia
matriz y esta volteada) y traduce los codigos de glifo con el `ToUnicode` de cada
fuente. Salen **118 KB** de las 79 paginas.

### Que se CONFIRMA (ya estaba, o es nuevo y verificado)

| | |
|---|---|
| Los nombres por stun max | coinciden con los nuestros |
| Los 4 candidatos de blockstun | `$63`, bit 5 de `$64`, bit 1 de `$71`, bits 0-5 de `$6C`: **identicos** |
| **191 moves, no 195** | §3d. **El amigo tiene razon** |
| **HP maximo 223** | §2. **Nuestra `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)* ya decia 223 y era correcta** |

### Que es NUEVO y todavia no esta verificado — `***`

| | Que dice | Por que no se adopta |
|---|---|---|
| `***` | **Los 12 contextos con 5 columnas**: rutina de init, `$50`, `$8C`, **`$90` (handlers)**, `$1C`, `$20` | La columna `$90` **no la teniamos**. Los bloques son 10, stride `$1E`, desde `$1251E`; y las 10 primeras rutinas de init van a stride `$4A` desde `$012792` |
| `***` | **`$20` es una progresion de step `$20000`**, inicializado por personaje | Nadie lo ha identificado. Habria que ver como se lee |
| `***` | **`$9C` se compara en dos sitios mas**: `01ef1e` (grab) y `01ee48` (push), con valores `$0130..$0140` | El pendiente 1 de la guia. Si es cierto, `$9C` se puede cerrar |
| `***` | **Contexto 12**: clona desde `a5-$300` y **exige el move `$A7`** | Habria que desensamblar esa rutina |
| `***` | **`especiales.danio` de `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)* son deltas de MANA**, no dano | Nuestro archivo lo rotula `WEB` y `ESTIMADO`; no hay forma de decidirlo sin el ROM |
| `***` | **El stun por golpe es 2-16, no 38-62** | §2b. Es la contradiccion mas importante de las dos |
| `***` | **Las cadenas de frames completas** (duracion, flag de golpe, sonido, bucle, por frame) | El PDF **no tiene direcciones**. Es nuestro pendiente 2 |

### El PDF tiene dos reglas de su leyenda que hay que respetar al cruzar

| | |
|---|---|
| **`dur 255` = frame de BUCLE** (vuelve al inicio, los de andar) | **NO suma** a la duracion total |
| **`dur 0` = frame fin** | |

Y el cruce **no se puede hacer contando numeros**. El campo donde van
`Startup · Activo · Recovery` **y** la cadena de frames **se pisan en la misma
columna**, y las filas vienen en tres formas:

```
34  | 3  | 32 | 8 · 8 · 16                             sin cadena visible
18  | 10 | 30 | 4 · 12 · 8 · 6 · 255 · 255 · 255 ...   cadena pegada al triple
184 | 9  | 48 | 20 · 4 · 24 | → daño 16 | 12 pos ...   cadena en columna aparte
```

Un intento dio **33,6 % de acuerdo, y ese numero NO dice nada del documento: dice
del parser.** Los desacuerdos eran sistematicos (los moves 6 y 7 con la misma
cadena). Para cruzar bien hay que apoyarse en las filas **con columna de daño**,
donde la cadena esta separada.

### El descriptor del grab y el pipeline grafico

El guia trae el **descriptor de grab decodificado campo por campo**, el
**pipeline grafico con el codec de VRAM** en `loc_0007be` (y el segundo codec en
`loc_000fe0`), que **`$2D5E` NO es un descompresor**, y que **`$34A00` no
contiene tiles sino 5 nametables concatenados**. Contra el escaner anterior:
**225 streams, no 944**. Nada de esto estaba nuestro, y nada se adoptó sin
verificar.

## 4. Tablas de moves

| Dato | Direccion |
|---|---|
| Lector de moves | `0x1EB5A` - `0x1EC82` |
| Offset de la tabla dentro del struct | `$8C(a5)` |
| Rutinas de stun por personaje | `0x12792` - `0x12A74` |

**No extraido todavia**: startup / active / recovery por movimiento. Ver
`herramientas/desensambladoEMULADOR_Z80.md` para el estado del emulador que lo debe
extraer.

## 5. Dano

- La resta real esta en `0x1F3E0`: `move.b $65(a3),d0 / lsr.b #$2,d0 /
  addq.b #$1,d0 / sub.w d0,$78(a4)`. El dano sale del byte `$65` del atacante
  (un cuarto de su valor, mas 1), y se clampa a 0 en `0x1F3EC`.
- El golpe solo aplica dano si el atacante tiene bit 4 de `$64`:
  `btst.b #$4,$64(a3)` en `0x1F3CE`.
- BizHawk capturo **408 impactos** en attract mode con deltas de 1, 4, 8, 12,
  16, 18, 20, 24, 32 y 48. Ojo: esos deltas se/leian de `$B8`, que ahora
  sabemos que es maná, asi que la tabla **no** es de dano y hay que repetirla
  leyendo `$78`.

Verificado por medicion:

| Caso | Dano | Recovery |
|---|---|---|
| Cadena rapida (A/B followed de golpe) | 1 | 4 frames |
| Proyectil | — | 88-92 frames (largo, punish) |

## 5a. El resolver tiene DOS caminos de daño, y solo uno mete stun

**Este es el dato que acota la busqueda del blockstun.** En `loc_01F21E` hay dos
formas de aplicar el golpe, y no son la misma:

**Camino COMPLETO**, desde `loc_01F414`:

```asm
01f414:  moveq   #$0, d0
01f416:  clr.w   $84(a4)        ; knockback a 0
01f41a:  move.b  #$ff, $86(a4)  ; $86 = $FF
01f420:  move.b  $65(a3), d0
01f424:  sub.w   d0, $78(a4)    ; daño COMPLETO
01f428:  move.b  $66(a3), d0
01f42c:  sub.w   d0, $7e(a4)    ; y STUN
```

**Camino REDUCIDO**, desde `loc_01F3D6`:

```asm
01f3d6:  moveq   #$0, d0
01f3d8:  move.b  $65(a3), d0
01f3dc:  lsr.b   #$2, d0        ; daño = $65 / 4
01f3de:  addq.b  #$1, d0
         ...                      ; NO toca $7E
01f410:  bra.w   $1f50a
```

Y el que elige entre los dos:

```asm
01f318:  move.b  $64(a3), d0
01f31c:  andi.b  #$0c, d0
01f320:  and.b   $63(a4), d0    ; mascara de defensa del DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414        ; == 0 -> camino COMPLETO, con stun
```

### Lo que esto prueba

**El juego tiene un camino que hace daño SIN aplicar stun.** El reducido aplica
`$65/4 + 1` y no toca `$7E` en ningun momento. Ese es el perfil del **chip
damage**, y tambien del golpe bloqueado.

| | Camino completo | Camino reducido |
|---|---|---|
| Daño | `$65` entero | `$65 / 4 + 1` |
| Stun | si, `sub.w $66,$7E` | **no** |
| `$84` (knockback) | `clr.w` | — |

**Consecuencia para el blockstun: NO esta en `$7E`.** Si un golpe puede hacer
daño sin pasar por `$7E`, entonces "stun de golpe" y "stun de bloqueo" son dos
cosas distintas en dos campos distintos. Buscar el blockstun en `$7E` era buscar
en el lugar equivocado.

**Lo que SIGUE sin locating:** cual es el campo del blockstun. El camino reducido
lo esquiva por completo, asi que hay que mirar **despues** de `0x1F32C`, que es
donde el golpe bloqueado prepara el empujon (`$10 = $2B000`, `$14 = $FFFC0000`,
`$6A = 1` en `0x1F33A`) antes de caer al reducido.

**Ojo con una cosa:** hay un branch en `0x1F3D4` (`beq.b $1f3f0`) que puede
saltar el camino reducido entero. As que el reducido no es automatico: hay al
menos un caso mas que lo evita.

## 5b. Los freezes: CUATRO, y ninguno es el hit-time de las especiales

| Sistema | Valor | Donde | Que frena |
|---|---|---|---|
| Hitpause | **16** | `0x1F2E0` | solo a3 y a4 |
| Clash | **28** (`$1C`) | `0x1F15E` | a3 |
| Congelacion de Itsuki | **255** (`$FF`) | `0x1C078` | **todos los que no son aliados** |
| Camara lenta de muerte | **160** (`$A0`) | `0x1FA82` | **TODO, es global** |

### `$69` hitpause y `$75`

`$75` va **siempre con `$69 + 1`**, en los dos resolvers:

```asm
01f2e0:  move.b   #$10, $69(a3)     ; 16
01f2e6:  move.b   #$11, $75(a3)     ; 17
01f2ec:  move.b   #$10, $69(a4)
```

Clash en `0x1F15E` (`#$1C` = 28, y `$75 = #$1D` = 29). El camino sin hit pone los
dos a 0 en `0x1F16C`.

**El bit 5 de `$64` del atacante ANULA el hitpause.** No lo baja: lo deja en 0.

```asm
01f2d8:  btst.b   #$5, $64(a3)
01f2de:   bne.b    $1f2f4
01f2e0:  move.b   #$10, $69(a3)     ; bit 5 puesto -> 16
...
01f2f4:  move.b   #$0,  $69(a3)     ; bit 5 ausente -> 0 freeze
01f2fa:  move.b   #$1,  $75(a3)
01f300:  move.b   #$0,  $69(a4)
```

O sea que en el mismo golpe hay **dos valores de freeze** segun `$64` bit 5: 16 o
0. Eso es lo que hace que algunos golpes no congelen, y no es un bug.

### Que se congela es SALTARSE el tick, no un contador

El unico consumidor de `$69` esta en `0x12AF4`, y lo que hace es **no llamar al
tick del frame data**:

```asm
012af4:  cmpi.b   #$0, $f55a.w     ; primero el global
012afa:   bne.b    $12b2e
012afc:  cmpi.b   #$0, $69(a5)     ; luego el propio
012b02:   bhi.b    $12b36
012b04:  clr.b    $6a(a5)
012b08:  jsr      $19c96          ; --- con freeze, todo esto se salta ---
012b16:  jsr      $1fbaa
012b1c:  jmp      $3556
loc_012b22:
012b22:  jsr      $1eb40          ; el tick del frame data
012b28:  jsr      $156f0          ; recalcular posicion
loc_012b2e:
012b2e:  jmp      $1580
loc_012b36:
012b36:  subi.b   #$1, $69(a5)    ; descontar
```

**`$69` SI es un timer**: lo decrementa `0x12B36`. Lo que hace es gatear el tick.

**Y hay 16 gates, no uno.** `$1EB40` tiene 16 llamadores, y cada uno tiene **su
propio `jmp $1580` a 18 bytes** (`0x12384`, `0x12B22`, `0x12C38`, `0x12D76`,
`0x12E98`, `0x12FBC`, `0x130EE`, `0x13244`, `0x136C6`, `0x137E0`, `0x139F4`,
`0x13DEE`, `0x142A0`, `0x14576`, `0x14832`, `0x15B78`). Son 16 estados del
personaje, cada uno con su condicion de freeze. **El hit-time de una especial
tiene que estar en uno de esos 15 que no se han mirado.**

### El 255 es la ulti de Itsuki (medido en ejecucion)

`loc_01C06A` recorre los 4 slots y congela a los que no son del mismo equipo:

```asm
01c06a:  lea.l    $8400.w, a0
01c06e:  move.b   $6e(a0), d1
01c072:  cmp.b    $6e(a5), d1
01c076:   beq.b    $1c07e
01c078:  move.b   #$ff, $69(a0)     ; 255
01c07e:  cmpa.w   #$9000, a0
01c082:   beq.b    $1c096
01c084:  adda.w   #$400, a0
01c088:  bra.b    $1c06e
```

**Medido: 255 frames exactos, y coincide con el `#$ff` del codigo.**

| Observado en ejecucion | Por que pasa |
|---|---|
| Congela **solo enemigos** | El bucle compara `$6E` contra el del lanzador |
| **No afecta proyectiles** | `$6E` se propaga a los hijos: `move.b $6e(a5), $6e(a1)` en `0x1A46C` y 9 mas. Los proyectiles propios llevan el `$6E` del dueno |
| **Se descongela con CUALQUIER impacto**, incluso sin dano | No hay contador que llegue a 0: el resolver **sobrescribe** el byte. `0x1F2E0` pone 16, `0x1F2F4` pone 0 |

**`$6E` es una etiqueta de pertenencia, no un byte de equipo suelto.** Es lo que
explica por que los proyectiles propios no se congelan.

TELEPORT (Itsuki): abajo-arriba + A / B / C   [MEDIDO en ejecucion, 07-10-2026]

Nombre coloquial: **Teleport A**, **Teleport B**, **Teleport C**.
NO es un nombre del juego: es la referencia con la que trabajamos.

COMANDO
  Abajo, Arriba, y despues A, B o C. Las tres gastan maná.
  El joystick del Sega NO permite oprimir direcciones opuestas a la vez, asi que
  abajo-arriba a la vez no es una entrada real de esta consola (el juego la acepta igual).

LO QUE SE SABE DE LAS TRES

| | |
|---|---|
| **Costo** | **16 de maná, idéntico en las tres** (223 -> 207) |
| **A** | teletransporta a la zona **izquierda** |
| **B** | teletransporta al **centro** |
| **C** | teletransporta a la zona **derecha** |

*** OJO: LAS TRES COMPARTEN EL MISMO ID DE $5F ***

En la primera prueba real del script, tres variantes de esta tecnica y **solo se
anotaron 2**. La causa NO fue del script ni de la medicion: el guardia de
"una fila por tecnica" casteaba por `(slot, id)` y **las variantes comparten el
id**, asi que la tercera quedo tapada. El guardia se saco.

**Y que las tres cuesten EXACTAMENTE lo mismo, con el mismo efecto y distinto
destino, es la prueba de que es UNA tecnica con un parametro** — el boton elige
la zona — y no tres tecnicas distintas.

### [MEDIDO 07-10] LAS TRES TIENEN EL MISMO REGISTRO, BYTE POR BYTE

Segunda corrida del usuario, con el maná recargado al 100 % antes de cada
variante. Las tres salen announced y **los datos son identicos**:

| | Teleport A | Teleport B | Teleport C |
|---|---|---|---|
| id de `$5F` | `$08` | `$08` | `$08` |
| registro | `$0CFBFA` | `$0CFBFA` | `$0CFBFA` |
| duracion (`byte +0`) | `$10` | `$10` | `$10` |
| los 8 bytes | `10 17 08 94 7C 00 83 7F` | idem | idem |

**Contexto de la tabla, confirmado leyendo el `.bin`:** `$50 = $0CF99A`,
`$8C = $0D069A`. Es el **contexto 6** de `auditar_moves.py`
(`BASE50[6] = 0xCF99A`; `BASE50[7] = 0xD1E5A`).

*** CORRECCION: en la primera anotacion de esto se puso "contexto 7". Es el 6. ***
Ese contexto tiene los **191 moves** documentados, comprobado leyendo el indice
hasta el primer offset 0 (indice 191).

*** Ojo: Itsuki y Kurama estan los dos en los contextos 1 y 7, asi que el
numero de contexto NO alcanza para decir de quien es la tabla. *** Lo que la
identifica es que la tecnica es el teletransporte de Itsuki.

### [VERIFICADO 07-10] LOS REGISTROS, LEIDOS DEL `.bin`

Leidos **del archivo**, no desde Lua, con
`w16(a) = int.from_bytes(rom[a:a + 2], "big")`, que es lo que ya hace
`herramientas/desensambladoauditar_moves.py:40`.

| | Valor |
|---|---|
| `word[$0CF9AA]` (offset del id 8) | `$0260` |
| `$0CF99A + $0260` | **`$0CFBFA`**, el registro anunciado |
| los 8 bytes | `10 17 08 94 7C 00 83 7F` |
| tabla B (`mult = $17`) | `$0D06F6` = `18 17 03 98` |
| golpe (`+ $0398`) | `$0D0A8E` |

**LAS TRES COSAS COINCIDEN CON LO QUE ANUNCIO EL SCRIPT.** O sea que **la
lectura desde Lua era CORRECTA**.

*** CORRECCION IMPORTANTE: lo que se concluyo antes, de que "el ROM no esta
expuesto bien a Lua", es FALSO. *** La autoprueba daba `byte(+0) = $10` contra
`$5A = $06`, y se leyo como "la lectura es ruido". Los dos valores son reales:
`$10` es el registro del `.bin` y `$06` es el `$5A` de **aun**. O sea que **en el
frame del anuncio el move no habia arrancado todavia**. El aviso era correcto y
la conclusion era equivocada.

**Consecuencia sobre el `$5F` anunciado: tambien puede ser el del estado
ANTERIOR**, por el mismo motivo. Ver la seccion siguiente.

### [MEDIDO 07-10, 2a corrida] EL ID DEL TELEPORT **CAMBIO**, Y ESO ES EL DATO

Tercera corrida, esta vez **desde el centro** del stage, con el script nuevo. Se
anuncio:

```
[MOV 01] P1  ^A    id=$0D ( 13)  mana -16  registro=$0CFC72
       frame=0 (pulsada en el 799)  dur=04
```

**El MISMO boton (A), en la corrida anterior dio `id=$08`, registro `$0CFBFA`,
`dur=$10`. Ahora da `id=$0D`, registro `$0CFC72`, `dur=$04`.**

Los tres datos de esta vez **coinciden con el `.bin`**:

| | anunciado | `.bin` | coincide |
|---|---|---|---|
| id | `$0D` = 13 | — | — |
| registro | `$0CFC72` | `$0CF99A + word[13] = $0CF99A + $02D8` | **si** |
| duracion | `$04` | `byte(+0)` de id 13 = `$04` | **si** |

O sea que **las dos lecturas son correctas contra el ROM**, y aun asi el id no es
el mismo. **Conclusión: el `$5F` que anuncia el script NO es estable, porque se
lee en el frame de la pulsada, y en ese frame el juego todavia no arranco el
move.** Es el mismo problema del `$5A` que hacia fallar la autoprueba, y ya no es
una hipotesis: **esta medido dos veces con resultados distintos.**

### *** LA HIPOTESIS DE LOS IDS 6/7/8 SE DEBILITA ***

Id 13, del `.bin`:

| id | registro | bytes `+2..+5` | mult | tabla B |
|---|---|---|---|---|
| 6 | `$0CFB9A` | `08 94 7C 00` | `$1B` | `$0D0706` |
| 7 | `$0CFBCA` | `08 94 7C 00` | `$1C` | `$0D070A` |
| 8 | `$0CFBFA` | `08 94 7C 00` | `$17` | `$0D06F6` |
| **13** | `$0CFC72` | **`80 0A 00 00`** | `$1D` | `$0D070E` |

**El id 13 NO comparte la familia `08 94 7C 00`.** Si los tres botones fueran los
ids 6, 7 y 8, el id 13 no tendria que haber salido. *** Queda abierta la
alternativa de que A, B y C sean, por ejemplo, **13, 12 y 14**, que son los ids
que la corrida todavia no ha separado. *** No se afirma nada hasta medir la
secuencia de `$5F`, que es lo que imprime el renglon nuevo.

*** Y el crash que corto esa corrida viene de ahi: el renglon de `$5F vivo` se
imprimio con `%02X` recibiendo `hex2(e.estado)`, y con `$0D` —que tiene letra—
`string.format` revienta. O sea que el dato que mas nos importaba es
precisamente el que disparo el crash. *** Ver `MEMORIA.md`, la trampa de `%X` con
un string.

### *** LOS IDS 6, 7 Y 8: UNA FAMILIA REAL, PERO NO NECESARIAMENTE LA NUESTRA ***

Del mismo `.bin`, mismo contexto:

| id | registro | 8 bytes | mult | tabla B |
|---|---|---|---|---|
| **6** | `$0CFB9A` | `0C 1B` **`08 94 7C 00`** `80 7D` | `$1B` | `$0D0706` |
| **7** | `$0CFBCA` | `0C 1C` **`08 94 7C 00`** `7E 76` | `$1C` | `$0D070A` |
| **8** | `$0CFBFA` | `10 17` **`08 94 7C 00`** `83 7F` | `$17` | `$0D06F6` |

**Los tres comparten los bytes `+2 +3 +4 +5` = `08 94 7C 00`**, y solo difieren
en duracion (`+0`), multiplicador de tabla B (`+1`) y velocidades (`+6`, `+7`).
Esa es la firma de **tres variantes de una misma tecnica**.

*** HIPOTESIS, AHORA DEBILITADA: A, B y C son los ids 6, 7 y 8. *** El id que
salio en la segunda corrida fue `$0D`, que **no** es de esa familia. Sigue siendo
posible — si los tres botones usaran 6/7/8, el 13 seria estado anterior — pero ya
no es la lectura por defecto.

El indicio sigue siendo el del `$5A`: si en el frame de la pulsada el `$5A` es el
del estado anterior, el `$5F` tambien lo es, y las tres variantes saldrían
identicas o distintas solo por estar midiendo el frame equivocado. **Con el id
cambiando entre corridas eso ya no es hipotesis: es lo que se midio dos veces.**
La secuencia de `$5F` es lo que lo cierra.

**Como se cierra, sin suponer nada:** `ITSUKI SET MOVE.LUA` ahora imprime, en
cada anuncio, el **`$5F` vivo** en el frame de la confirmacion **y la secuencia
de los 8 frames** hacia atras desde el de la pulsada. Si tres anuncios distintos
dan `$06`, `$07` y `$08`, la hipotesis es correcta. Si los tres dan el mismo,
las tres son el mismo id y la zona se lee en otro lado.

### [MEDIDO 07-10] LAS TRES ZONAS, Y LOS 39 FRAMES

Tercera corrida, **desde el centro**, en orden **C → A → B**. Las tres salieron
limpias: sin crash, sin falsos, y cada `[TELE]` atribuido a su `[MOV]` con
exactamente **39 frames** de delay. Tres de tres.

| variante | pulsada | cayo en | **mundo X** | **pantalla `$08`** | desplazamiento |
|---|---|---|---|---|---|
| **C** (derecha) | 299 | 338 | **1281** | **432** | +148 |
| **A** (izquierda) | 497 | 536 | **1025** | **176** | −256 |
| **B** (centro) | 636 | 675 | **1149** | **304** | +124 |

**Las tres zonas son ABSOLUTAS, no relativas.** Se prueba con el orden: C salió
desde el centro, A desde la derecha y B desde la izquierda, y las tres'arrivée
a la misma coordenada de destino que si hubieran salido del mismo lugar.

| | |
|---|---|
| **separación en pantalla** | **128 px exactos** (176 → 304 → 432) |
| separación en mundo | 124 y 132 (**no uniforme**) |

La diferencia entre las dos mesures es que **la camara se mueve** entre un salto
y otro: el mundo se corre 4 px y la pantalla 128, y al reves. En `$08` — que es
lo que el jugador ve — la separación es de 128 clavados.

**Y esto cierra la duda de la corrida anterior:** la vez pasada el personaje
estaba en `X = 1025`, que es **exactamente la zona izquierda**. Por eso Teleport
A no lo movio: no estaba fallando, ya estaba ahi. La explicacion del clamp era
equivocada.

### [MEDIDO 07-10] `$5F` NO DISTINGUE LAS TRES VARIANTES

Este es el resultado negativo de la corrida, y es el importante:

```
[MOV 01] P1  ^C    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $01 $01
[MOV 02] P1  ^A    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $01 $01
[MOV 03] P1  ^B    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $02 $01
```

**Los tres dan exactamente lo mismo: `$0D` en la pulsada, `$A4` vivo, registro
`$0CFC72`. Ni un solo valor distinto entre A, B y C.**

Leyendo la secuencia (el primer valor es el frame actual, y el segundo es el de
la pulsada):

| frames antes | `$5F` | que es |
|---|---|---|
| 7 y 8 | `$01` | **parado** |
| 6 | `$02` | *(un estado transitorio, solo aparece en la 3a)* |
| 2 a 6 | `$0D` | **el estado de la secuencia ↓↑** |
| 1 | `$0D` | la pulsada |
| 0 | `$A4` | **el teleport en curso** |

*** `id = $0D` es el estado del comando ↓↑, no la variante: aparece ~5 frames
ANTES de que se pulse el boton. *** Y **`$A4` es el teleport ya arrancado**, y es
comun a las tres variantes.

**Consecuencia:** **la zona no esta en `$5F`.** Ni en `$0D` ni en `$A4`. Y
tampoco en el registro de 8 bytes, que es identico en los tres casos. O sea que
**la eleccion de zona se hace en el frame 39**, cuando el personaje se coloca, y
no se deduce de ningun dato de la tabla: hay que ver que lee el juego en ese
momento.

*** Candidato: el boton. La secuencia no muestra diferencia porque `$5F` no la
guarda. Habria que mirar un campo de entrada o el codigo que escribe `$40`/`$44`
en el frame de la colocacion. ***

### *** QUE ES `$0D` Y QUE ES `$A4`: DOS HIPOTESIS, Y COMO SEPARLAS ***

*** No verificado. *** De la corrida solo sale esto:

| `$5F` | cuando | lectura |
|---|---|---|
| `$01` | parado, antes de todo | estado de reposo |
| `$02` | un frame, en la 3a corrida | transitorio, sin identificar |
| `$0D` | **5 frames terminando en el de la pulsada** | ??? |
| `$A4` | desde 1 frame despues de la pulsada | el teleport en curso, comun a las tres variantes |

**Lo que NO sabemos:** si `$0D` es un estado de posicion (agachado), o el primer
paso del comando abajo-arriba, o un buffer de comando. Las tres se ajustan a "5
frames y se va un frame despues de la pulsada".

*** Las hipotesis del usuario, que son las buenas: ***

1. `$0D` = **agacharse**. Predecible: mientras se mantenga abajo, `$5F` deberia
   quedarse en `$0D` indefinidamente, y volver a `$01` al soltar.
2. `$0D` = **el primer paso del comando ↓↑**. Predecible: mantener abajo 3
   segundos y despues pulsar el boton NO deberia dejar `$0D` en los 8 frames
   previos a la pulsada, porque el abajo ya se solto hace rato.
3. `$0D` = **un buffer que se esta preparando** para la tecnica. Predecible:
   deberia aparecer solo con la secuencia ↓↑ completa, y no con un abajo suelto.

**Como separarlas, sin codigo:** el HUD muestra `mov $XX` = `$5F` en vivo. Con
↓ mantido 3 segundos se mira la pantalla y se lee.

| lo que se vea | conclusion |
|---|---|
| `$0D` y se mantiene | es **agachado** (o similar) |
| `$01` mientras se mantiene abajo | **abajo solo no produce `$0D`** |
| parpadea o cambia | es un **transitorio de transicion** |

`ITSUKI SET MOVE.LUA` ahora imprime ademas una linea `[`$5F`]` en **cada cambio**,
aunque no se gaste maná, para tener el registro escrito y ver cuanto dura cada
estado. Antes no servia: el rastreador solo anuncia con gasto de maná, asi que
agacharse 3 segundos no producia **ni una sola linea**.

### [MEDIDO 07-10] LA ESCALERA DE `$5F`, CON DURACIONES

Con el aviso de cambios de `$5F` se ve la secuencia completa del teleport:

| frame | cambio | `$59` | `$5A` | estado | cuanto duro |
|---|---|---|---|---|---|
| 166 | `$00 → $01` | 0 | `$06` | aparece en la pelea | 7 frames |
| 173 | `$01 → $02` | 0 | `$04` | **reposo** | **298 frames** |
| 471 | `$02 → $0D` | 0 | `$04` | **un frame** | **1 frame** |
| 472 | `$0D → $A4` | 0 | `$06` | **el teleport** | 38 frames |
| 510 | `$A4 → $A5` | 0 | `$01` | vuelta/aterrizaje | 46 frames |
| 556 | `$A5 → $00` | 0 | `$0C` | vuelve al principio | — |

**DOS CORRECCIONES A LO QUE SE DIJO ANTES:**

1. **`$02` no es un transitorio: es el estado de REPOSO, y duro 298 frames**
   (5 segundos parado). En la corrida anterior appeared un solo frame y se leyo
   como un estado transitorio. Es el estado normal de quieto.

2. **`$0D` no duro 5 frames: duro 1.** La secuencia de la corrida anterior
   (`$A4 $0D $0D $0D $0D $0D`) lo hacia parecer de 5. **Lo que dura cambia entre
   corridas**, porque depende de cuanto se mantenga la entrada antes del boton.
   En esta, `$0D` fue **exactamente el frame de la pulsada** y nada mas: `$02` en
   el 470, `$0D` en el 471 (pulsada), `$A4` en el 472.

*** Consecuencia para las hipotesis del usuario: `$0D` es el estado del FRAME en
que se acepta el comando, no un estado de posicion. No se mantuvo nada tiempo, y
la duracion depende de la entrada, no de una condicion. ***

### [MEDIDO 07-10] LA ZONA IZQUIERDA, TERCERA CONFIRMACION

`[TELE 1] mundo X = 1025`. Es la **tercera medicion** de la misma zona: 1281
(derecha), 1025 (izquierda), 1149 (centro), y ahora 1025 otra vez desde otra
posicion de partida (1133).

### *** EL MANA BAJO 20 SIN QUE SE ANUNCIARA NADA ***

`maná P1 = 187` en el frame 600, cuando la tecnica gasto 16 de 223. O sea que
**faltan 20 mas** y ninguna pulsada gasto. No hay explicacion y queda abierto:
puede ser un refill del training mode con otro formato, o una tecnica que no
llego a la puerta de maná. *** No se investiga hasta tener otra medicion. ***


### *** LO QUE NO SE SABE, Y NO SE PUEDE ADIVINAR ***
- **La zona NO esta en la tabla A ni en la tabla B.** Verificado en el `.bin`:
  los 8 bytes del registro y los 4 del subregistro son los mismos para las tres.
  Lo que las separa tiene que leerse **en ejecucion**: el boton pulsado, o un
  campo del struct que el juego escribe al arrancar el move.
- **No hay una direccion de CODIGO propia del teletransporte.** El unico punto
  verificado es `loc_011F3E` (`0x11F3E: move.b d0, $5f(a5)`), que es el
  "arrancar el move N" generico de todas las tecnicas. **Donde el juego decide el
  destino no esta buscado.** El candidato natural es un escritor grande de `$40`
  que no sea el `add.l` de la velocidad (`0x14AA4`), y el mas sospechoso es
  `0x14AB6: move.w $40(a0), $40(a5)`, que **copia la posicion desde el objeto
  apuntado por `$48`** — o sea que un teletransporte podria ser "apuntar `$48` a
  un marcador de destino y copiar". *** No verificado: habria que mirar quien
  escribe `$48`. ***

---

## MAPA FRAME A FRAME  [MEDIDO]

| Frame | Que pasa |
|---|---|
| **1** | **La hurtbox desaparece.** Intangible de entrada, altísima prioridad |
| **14** | La **pushbox** desaparece. El personaje **todavía se ve**, pero ya es completamente intangible |
| **19** | El sprite **empieza a parpadear** |
| **36** | Aparece en la zona acorde al botón |
| **61** | La **pushbox y la hurtbox vuelven a dibujarse**, al mismo tiempo |
| **61 a 65** | Itsuki está **en el aire**: es lo que tarda en pisar el suelo |

**Cualquier ataque recibido en esa ventana puede producir backflip o knockdown**,
según las propiedades del ataque.

---

## POR QUE ESTO CIERRA EL PENDIENTE P5

P5 era "la flag que borra la hurtbox, dirección desconocida", y no se podia
podía atacar porque la ventana del backflip es de **13 frames** (hurtbox fuera en
el 24, backflip en el 37): demasiado corta para aislar.

**Esta ventana es de 60 frames** (1 a 60), con dos subventanas bien marcadas:

| Ventana | Que falta |
|---|---|
| **1 a 13** | solo la hurtbox |
| **14 a 60** | hurtbox **y** pushbox |
| **19 a 60** | ademas el sprite parpadea |

**El parpadeo del frame 19 es la mejor pista que tenemos**: es un efecto VISIBLE
que dura 42 frames, y se puede buscar por el codigo que lo dibuja. Con el blink
encontrado, el frame 1 (el primer frame de intangibilidad) tiene que estar cerca.

**O sea que P5 paso de "no atacable" a "atacable, y con tres puntos de entrada".**

---

## LO QUE FALTA

| | |
|---|---|
| **El id de `$5F`** | Sale solo en la proxima corrida del `.lua`, ahora que el guardia no tapa variantes |
| **Las direcciones** | El `.lua` las calcula y las imprime en el mismo aviso |
| **Que campo es el parametro de zona** | A/B/C apuntan a tres zonas distintas con el mismo `id`: el destino tiene que estar en algun byte del registro de 8 bytes o de la tabla B. **No verificado.** |
| **Por que A/B/C cuestan igual** | Si el destino fuera un offset en el registro, tres valores distintos con el mismo costo tiene sentido; si fuera en la tabla B, tambien. **Sin dato todavía** |

**La tabla B tiene un solo subregistro por byte `+1` del registro**, y ese byte
es el mismo para las tres variantes si comparten `id` y frame. **O sea que el
parámetro de zona probablemente NO está en la tabla B sino en otro lado**, o
las tres variante tienen `id` distinto y lo que se vio fue otra cosa. **Abierto:**
lo resuelve una linea mas de salida del `.lua`, que ya imprime el registro
completo de cada variante.


### Herramienta que lo verifica: `ITSUKI SET MOVE.LUA`

**`herramientas/lua/ITSUKI SET MOVE.LUA`** (autotest: `test_stoptime.lua`, 78
pruebas). Mapea el ult sobre el codigo y **se autocomprueba**, para que no sea
solo un lector. **Al detectar la invocacion saca un cartel gigante con "OK" en el
centro de la pantalla**, durante 75 frames: es una corroboracion a ojo de que
el script lee y detecta durante el juego, que es lo unico que el usuario pedia
para confirmar que funciona.

**Que verifica, con las tres partes de la firma:**

| Parte | Donde |
|---|---|
| `$69 = 255` en los slots enemigos | `0x1C078` |
| `$59 == 2` y `$5B == 0` y `$60 != 1` en el lanzador | `0x1C03A`, `0x1C042`, `0x1C032` |
| **`$6E` del congelado distinto al del lanzador** | `0x1C072`-`0x1C076` |

**La regla del `$6E` se comprueba en las DOS direcciones**, y por eso el script
sirve como prueba y no como lector:

| Si | El script avisa |
|---|---|
| un slot de **otro** grupo sin congelar | FALLA |
| un slot del **mismo** grupo congelado | FALLA |

**Que NO usa exec hook, y es a proposito:** `$69` es un timer que sobrevive
varios frames, asi que `registerafter` alcanza. Asi el script **no depende de
`memory.registerexec`**, que en esta build no dispara (`diagnostico_knockdown.lua` quedo
con `invocaciones=0`). Es el primer diagnostico que esquiva ese agujero en vez de
pelearse con el.

**Y distingue los DOS finales del ult:** por **cuenta regresiva** (255 frames
exactos, verificado) o por **impacto**, que es cuando el resolver sobrescribe el
byte. Si el corte cae a 0 viniendo de 1 fue la cuenta; si caia antes, fue un
impacto.

**LO QUE EL CODIGO ACLARA Y EL DOC NO DECIA:** el recorrido termina en
**`cmpa.w #$9000, a0`** (`0x1C07E`), o sea que **`$9000` es el ULTIMO slot del
array y el bucle los recorre TODOS**. Es un dato a favor de `$9000` como base
del P2, y sale de leer el codigo y no de razonar sobre el stride.

### `$FFF558` es CAMARA LENTA de muerte, no un freeze

```asm
loc_01edfa:
01edfa:  cmpi.w   #$0, $f558.w
01ee00:   beq.b    $1ee18
01ee02:  subq.w   #$1, $f558.w
01ee06:  move.w   $f558.w, d0
01ee0a:  btst.b   #$1, d0          ; ¿el contador es IMPAR?
01ee0e:   beq.b    $1ee18
01ee10:  move.b   #$1, $f55a.w     ; impar -> frena este frame
loc_01ee18:
01ee18:  clr.b    $f55a.w          ; par -> NO frena
```

**`$F55A` se prende en frames impares y se apaga en los pares.** Con `$F558 = 160`
eso es **mitad de velocidad durante 160 frames**. No es una congelacion: es
**camara lenta**.

Por eso frena **todo** — proyectiles, elementos del stage y scroll — porque
`$FFF558` es **global**, mientras que `$69` es por personaje. Y por eso no se
asocia al hit-time: no es un freeze.

Los dos se limpian juntos en varios init (`0x0034C4` + `0x0034C8`, `0x004562`,
`0x00685A`, `0x00A858`, `0x00AE80`, `0x00F324`).

### Cuando se dispara: `$78` negativo

**Aca hay un branch que es facil de leer mal.** En `loc_01F4CA` hay **dos** tests
con dos `blt` distintos:

```asm
loc_01f4ca:
01f4ca:  cmpi.w   #$0, $78(a4)     ; TEST 1: el HP del defensor
01f4d0:   blt.b    $1f4f4          ; HP < 0 -> CAMARA LENTA
01f4d2:  clr.w    $84(a4)
01f4d6:  cmpi.w   #$0, $7e(a4)     ; TEST 2: el stun del defensor
01f4dc:   blt.b    $1f4e2          ; stun < 0 -> knockdown
loc_01f4de:
01f4de:  bsr.b    $1f524          ; ninguno de los dos -> caso normal
```

**El `blt` de `0x1F4D0` es del test de `$78`, no del de `$7E`.** El slow-mo se
dispara **cuando el HP es negativo**, o sea cuando el personaje murio. `$78` es un
word **signed**, asi que es como el juego representa el KO.

**Medido: entre 150 y 170 frames**, contra los 160 del literal.

### Por que NO es acumulativo

`loc_01FA70` tiene **un solo llamador en todo el juego**, y es una asignacion:

```asm
loc_01fa70:
01fa70:  moveq    #$0, d0
01fa72:  move.b   $58(a4), d0       ; el codigo del golpe
01fa76:  lea.l    $1fa8a.l, a0     ; tabla
01fa7c:  adda.l   d0, a0
01fa7e:  move.b   (a0), $a030.w    ; una salida: ACCION (variable)
01fa82:  move.w   #$a0, $f558.w    ; la otra: 160 SIEMPRE (rigido)
01fa88:  rts
```

| | |
|---|---|
| **La duracion** | **`#$A0` es un literal.** En las 28.168 instrucciones `$FFF558` nunca recibe otro valor. No es flexible |
| Acumulable | **No**: es asignacion, no suma |
| Reiniciable | **Si**, y por eso cada golpe sobre un muerto vuelve a clavar 160 |

**Medido: se sigue golpeando a un muerto y la lentitud se mantiene.** Exacto.

### Del maná en la muerte: NO hay nada

En toda la region `0x1E000`-`0x20000`, que contiene el resolver y el slow-mo, las
**unicas** escrituras a `$B8` son las del bonus de combo (`0x1FA12`, con el tope
en `0x1FA1E`). **El slow-mo no toca el mana.**

**Medido: un personaje muerto no pierde maná.** Consistente: lo unico que lo
restaria es el goteo de `0x1A4EA` y las burlas, y ninguno depende de `$78`.

El goteo tiene su propio gate, que no es de muerte:

```asm
01a4d6:  add.w    d0, $7c(a5)
01a4da:  cmpi.w   #$100, $7c(a5)
01a4e0:   blt.b    $1a4ea          ; si $7C < 256 -> gotear
01a4e2:  move.w   #$ff, $7c(a5)    ; si no, saturar
01a4e8:   bra.b    $1a4ee          ; y SALTAR el goteo
loc_01a4ea:
01a4ea:  subq.w   #$1, $b8(a5)
```

`$7C` es un acumulador en coma fija: cuando cruza 256 se saltea el −1. Ese es el
balance entre regeneracion y gasto, y **no mira el HP**.

### `$F558` / `$F55A`: lo que NO es

Por si se vuelve a cruzar con el hit-time: **no esta en ninguno de los dos.** Se
descarto por agotamiento, no por inferencia.

| Campo | Escritores en todo el ROM | Valores |
|---|---|---|
| `$69` | 7 | **0, 16, 28, 255.** Nada entre 28 y 255 |
| `$FFF558` | **1** | **160.** Un solo valor |

## 5c. `$26` — un INDICE, no un plano ni una profundidad

Lo que se sabia antes era solo que "`$26` prende en todo contacto". Las direcciones
del escritor:

```asm
01f7b2:  cmpi.w   #$130, $9c(a3)    ; ¿el atacante es el char $130?
01f7b8:   beq.b    $1f7c8
01f7ba:  move.b   #$3c, $26(a3)     ; atacante = 60
01f7c0:  move.b   #$40, $26(a4)     ; defensor = 64
01f7c6:   rts
01f7c8:  move.b   #$bc, $26(a3)     ; 188
01f7ce:  move.b   #$c0, $26(a4)     ; 192
01f7d4:   rts
```

### El bit 7 NO son dos planos: es el SIGNO

**Habia un error en una lectura anterior de este mismo doc.** Se sostenia que el
bit 7 discriminaba dos planos porque los mismos valores bajos aparecian con y sin
`$80`. Es falso: en el consumidor el bit 7 se lee como **signo**, con `ext.w`.

### El consumidor: `loc_0379AE`, un interprete de tablas

**`$26` no guarda una magnitud.** Es el cursor que camina por una tabla de bytes,
uno por llamada:

```asm
loc_0379c6:
0379c6:  moveq    #$0, d0
0379c8:  move.b   $26(a5), d0        ; d0 = $26
0379cc:  addq.b   #$1, $26(a5)       ; $26++
0379d0:  move.b   (a0, d0.w), d6     ; d6 = byte de la tabla en ese indice
0379d4:   bpl.b    $379f4            ; bit 7 = NEGATIVO, no opcode
loc_0379f4:
0379f4:  ext.w    d6                 ; valor CON SIGNO
0379f6:  move.b   $3(a5), d0
0379fc:  mulu.w   d0, d6             ; desplazamiento x escala
loc_0379fe:
0379fe:  move.b   $1e(a5), d0
037a04:  add.w    d0, d6
037a06:  add.w    $10(a5), d6        ; + velocidad
```

El byte de la tabla es un **desplazamiento con signo**: se multiplica por una
escala (`$3`) y se suma a una posicion (`$1E`) mas la velocidad (`$10`).

### Los cinco opcodes que manejan el cursor

| Opcode | Instruccion | Que hace |
|---|---|---|
| `$80` | `clr.b $26(a5)` en `0x37A1A` | vuelve al inicio de la sub-tabla |
| `$81` | `subq.b #$2, $26(a5)` en `0x37A20` | sube al padre |
| `$82` | `$26 = tabla[$26+1]` en `0x37A38` | salta adelante |
| `$83` | `bset.b #$1, (a5)` en `0x37A26` | prende un flag, no toca `$26` |
| `$84` | `$3 += tabla[$26+1]` en `0x37A40` | suma a la escala y avanza |

Y un segundo sitio, independiente, en la zona de actualizacion del jugador:

```asm
0015fa:  move.b    $26(a5), d4
0015fe:  andi.w    #$fc, d4        ; offset multiplo de 4
001602:  movea.w   d4, a2
001604:  movea.w   -$cfe(a2), a0   ; lee una tabla indexada por ese offset
```

### `$0A` es el selector de TABLA, y hay 8 (esto faltaba)

La cadena que faltaba era como se elegia la tabla, y sin eso no se puede acotar
el rango de valores:

```asm
0379ae:  moveq     #$0, d6
0379b0:  move.b    $a(a5), d0
0379b4:  andi.w    #$7f, d0        ; solo limpia un bit de bandera
0379b8:   beq.b    $379fe          ; $0A = 0 -> no lee nada
0379ba:  lea.l     $3a256(pc), a0  ; tabla de PUNTEROS
0379be:  subq.w    #$1, d0         ; d0 = $0A - 1
0379c0:  lsl.w     #$2, d0
0379c2:  movea.l   (a0, d0.w), a0  ; a0 = flujo de bytes
```

| | |
|---|---|
| Donde | tabla de **8** punteros en `$3A256`-`$3A275` |
| Rango de `$0A` | **1 a 8**. El `andi.w #$7f` no significa "hasta 127": solo limpia un bit |
| Los 8 flujos | `$3A276, $3A28C, $3A2A2, $3A2AC, $3A2C6, $3A2B6, $3A2F0, $3A2F2` |

Ojo: el indice se calcula con `subq.w #$1` **despues** del `beq`, asi que `$0A=0`
saltea y `$0A=1..8` da los ocho flujos.

### EL VOLCADO: que hay de verdad en los 8 flujos

`herramientas/desensambladodump_26.py` los vuelca byte por byte. **154 bytes en total:**

| Clase | Bytes | % |
|---|---|---|
| `DATO+` (`$00`-`$7F`) | 140 | **90,9 %** |
| `DATO-` (`$85`-`$FF`) | 8 | 5,2 % |
| `CODIGO` (`$80`-`$84`) | 6 | 3,9 % |

Los flujos completos, con el valor con signo al lado:

```
$0A=1  $3A276  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 83
$0A=2  $3A28C  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 80
$0A=3  $3A2A2  D8 E2 EC F6 00 0A 14 1E 28 83
$0A=4  $3A2AC  D8 E2 EC F6 00 0A 14 1E 28 80
$0A=5  $3A2C6  00 x10  01 x15  02 x8  03 x7  04 83
$0A=6  $3A2B6  04 04 04 04 03 03 03 03 02 02 02 02 01 01 01 01
$0A=7  $3A2F0  02 83
$0A=8  $3A2F2  00 x5  01 x5  02 x7  03 x5  04 x5  05 x5   (longitud aproximada)
```

**Cada flujo termina en `$80` o `$83`**, que es exactamente lo que haria una curva
de movimiento: un ciclo, o un fin. Es la comprobacion de que las longitudes (por
"hasta el siguiente puntero") estan bien.

Los valores con signo que aparecen en los datos, **todos**:

| Grupo | Valores |
|---|---|
| Positivos | `0` a `40`, de paso uno (rampas de 1, de 5, de 10) |
| Negativos | **`-40 -40 -30 -30 -20 -20 -10 -10`** |

**Ninguno mayor que 40. Ni 64, ni 192, ni 148, ni 252.**

### Donde salen "64" y "192", y por que se leyeron como planos

**Del escritor, no de la tabla.** Los unicos valores grandes de `$26` estan en
las rutinas que lo **inicializan**, y son offsets de arranque del cursor:

```asm
01f7ba:  move.b   #$3c, $26(a3)     ; 60  -> cursor arranca en la entrada 60
01f7c0:  move.b   #$40, $26(a4)     ; 64
01f7c8:  move.b   #$bc, $26(a3)     ; 188
01f7d4:  move.b   #$c0, $26(a4)     ; 192
```

O sea que `$40` y `$C0` son **indices**, no magnitudes. Leidos como
profundidad, con y sin el bit 7, parecian dos planos. **Es exactamente la
trampa que ya estaba anotada en `MEMORIA.md` ("mirar solo los escritores")**,
cometida por el material externo y por una lectura anterior nuestra.

### Dos opcodes no se usan nunca

De los cinco, en los 154 bytes de los 8 flujos **solo aparecen `$80` (3 veces) y
`$83` (3 veces)**. `$81`, `$82` y `$84` estan implementados y **no salen en ningun
flujo**. O son de una tabla que no esta en `$3A256`, o quedaron de una version
anterior. Queda abierto, y no estorba.

### Los valores con signo: la tabla que hay que leer con cuidado

| Valor | Con signo | De donde sale |
|---|---|---|
| `$10` (16) | +16 | cursor escrito |
| `$14` (20) | +20 | cursor escrito |
| `$3C` (60) | +60 | cursor escrito (`0x1F7BA`) |
| `$40` (64) | +64 | cursor escrito (`0x1F7C0`) |
| `$94` (148) | −108 | cursor escrito |
| `$C0` (192) | −64 | cursor escrito (`0x1F7D4`) |
| `$FC` (252) | −4 | cursor escrito |
| `$D8 E2 EC F6` | **−40 −30 −20 −10** | **SI estan en las tablas** (`$0A`=3 y 4) |
| `$0A 14 1E 28` | **+10 +20 +30 +40** | **SI estan en las tablas** (`$0A`=3 y 4) |

**Ninguno de los siete primeros llega a leerse como desplazamiento**: las tablas
no los contienen. Los unicos negativos que el interprete ve de verdad son los de
`$0A = 3` y `$0A = 4`, y son **las dos mitades de la misma curva**:

```
D8 E2 EC F6  00  0A 14 1E 28  ->  -40 -30 -20 -10   0  +10 +20 +30 +40
```

Una rampa que **cruza el 0** y sigue subiendo. Si el bit 7 fuera un plano, el
grupo negativo seria otra magnitud y no habria continuo entre los dos. Lo hay.
**Se confirmo lo de §5c y se REFUTO lo de "dos planos", esta vez con las tablas
en la mano y no solo el consumidor.**

### Por que "prende en todo contacto"

**Un contacto dispara una animacion de empuje, y `$26` es el frame de esa
animacion.** Prende porque es el contador de la animacion, no porque sea un timer.

**VERIFICADO: NO es hit-time.** Y tampoco es profundidad ni prioridad de dibujo.

**LO QUE SIGUE ABIERTO:** si el `a5` de `loc_0379AE` es el struct del jugador o un
objeto aparte. La lectura de `0x0015FA`, que esta en la zona de jugador junto a
`$24`, lo apoya, pero no lo cierra. Es el unico punto que necesita emulador.

## 5d. `$A030`: la cola de SONIDO, y el byte `+4` del frame data

**CORRECCION IMPORTANTE.** Esto se escribio antes como "cola de acciones" y como
"el camino al hit-time". **Las dos cosas estan mal**, y la correccion viene del
material externo (`GUIA_TECNICA_UNIFICADA.md`, 10-06) y esta confirmada aca.

**`$A030` es el indice de un SONIDO, no una accion de gameplay.** El byte `+4`
del registro de frame es el **indice de sonido**, indexado en la tabla de
`$218D8`. La cola de 4 canales con prioridad es un **driver de audio**, no un
gestor de efectos.

La prueba: `$F800` se usa como **base de puntero** (`lea.l $f800.w, a0` en
`0x38A34`, `0x38A5E`) y `$F809` se resetea a `$FF` en tres sitios (`0x37CBA`,
`0x38A42`, `0x38A72`). Ese es el patron de un driver de sonido.

**Consecuencia: el hit-time NO esta ahi.** Ibuscamos en la cola de sonido durante
una sesion entera. Esta en otro lado — ver §5b para lo que si es.

### Las perdidas de sonido, y por que se pierde

**La cola tiene 4 canales y cuando se llenan, la peticion se pierde.** No hay
espera ni reintento para `$A030`:

```asm
01ed9a:  move.b    $a030.w, d0
01ed9e:   beq.b     $1edaa
01eda0:  clr.b     $a030.w      ; <- borra SIEMPRE
01eda4:  jmp       $21960.l     ; <- y no mira el resultado
```

Y `$21960` devuelve 0 si los 4 estan ocupados:

```asm
loc_0219a8:
0219a8:  clr.b     d0           ; ninguno libre -> FALLO
0219aa:  rts
```

**Medido de oído:** hay tecnicas que se ejecutan sin pronunciar nada, y personajes
que mueren sin su grito. Eso es una peticion descartada por cola llena.

**La musica no pasa por acá** y por eso nunca se corta ni se ve afectada por el
time stop ni por la camara lenta: es otro driver.

### La unica excepcion: `$F562` si reintenta

```asm
loc_0219ba:
0219ba:  move.b    $f562.w, d0
0219be:   beq.b     $219cc
0219c0:  jsr       $21960.l     ; reintenta
0219c6:   beq.b     $219cc       ; si fallo, NO limpia: vuelve a intentar
0219c8:  clr.b     $f562.w      ; si alguno, limpio
```

Un unico sonido tiene paciencia; los demas no.

### La cola de 4 canales con dedupe

`$21960` mete el valor en el primer canal libre, y **no duplica**:

```asm
loc_021960:
021960:  tst.b    $f80a.w
021964:   bpl.b    $2196c      ; vacio -> asignar
021966:  cmp.b    $f80a.w, d0 ; ¿ya tiene el MISMO valor?
02196a:   bne.b    $21972      ; si es otro -> siguiente canal
loc_02196c:
02196c:  move.b   d0, $f80a.w  ; <- asignar
loc_021972:  tst.b  $f80b.w    ; canal 2
loc_021984:  tst.b  $f80c.w    ; canal 3
loc_021996:  tst.b  $f80d.w    ; canal 4
```

Tiene **~110 llamadores** en todo el ROM: es infraestructura central de audio.

### Y como se elige: prioridad, no orden

`$37C44` consume los 4 canales cada frame y gana el de mayor prioridad:

```asm
037c44:  lea.l    $3a50e(pc), a0      ; TABLA de prioridades
037c52:  move.b   -(a1), d0           ; leer canal (hacia atras)
037c56:  clr.b    (a1)                ; <- CONSUME
037c60:  move.b   (a0, d0.w), d2      ; prioridad[codigo]
037c6c:  move.b   d2, d5
037c6e:  andi.b   #$7f, d5            ; <- la prioridad son los 7 bits bajos
037c78:  cmp.b    d6, d5
037c7a:   bcs.b    $37c82             ; si es menor, se descarta
037c7c:  move.b   d2, d3              ; si es mayor, pasa a ser la actual
loc_037c7e:
037c7e:  move.b   d1, $f809.w         ; <- el codigo ganador
```

**Medido de oído:** los golpes le ganan a las voces. Eso es la comparacion de
prioridad, no un bug.

### El mapa del registro de 8 bytes (corregido)

```asm
01eb5a:  move.b    $0(a2), $5a(a5)    ; +0 = duracion
01eb62:  move.b    $1(a2), d3        ; +1
01eb66:  move.b    $2(a2), d5        ; +2
01eb6a:  move.b    d5,   $5c(a5)
01eb6e:  move.b    $3(a2), d0        ; +3
01eb72:  or.b      $6d(a5), d0
01eb76:  move.b    d0,   $6c(a5)
01eb82:  move.b    $4(a2), d0        ; +4 = INDICE DE SONIDO
01eba6:  move.b    $6(a2), d6        ; +6 (restado $80)
01ebb0:  move.b    $7(a2), d7        ; +7 (restado $A0)
```

Y en el mismo bloque, el flag de encadenamiento que ya se conocia:

```asm
01eb98:  btst.b    #$4, d5           ; bit 4 de +2
01eb9c:   beq.b    $1eba4
01eb9e:  moveq    #$ff, d0
01eba0:  move.l    d0, $94(a5)       ; $94 = $FFFFFFFF
```

### De donde sale `$A030`: TRES fuentes

| # | Fuente | Direccion |
|---|---|---|
| 1 | **byte `+4` del frame data** → tabla `$218D8` | `0x1EB82`-`0x1EB94` |
| 2 | `tabla_$1FA8A[$58]` (solo al morir) | `loc_01FA70`, `0x1FA7E` |
| 3 | Literales directos: `$77`, `$78`, `$7A`-`$7C`, `$7D`, `$A6` | varios |

La fuente 1, en el builder:

```asm
01eb7a:  tst.b     $5b(a5)        ; ¿el contador del frame llego a 0?
01eb7e:   bne.b    $1eba4         ; si no, no hay frame nuevo
01eb82:  move.b    $4(a2), d0     ; byte +4 del registro de 8 bytes
01eb86:  lea.l     $218d8.l, a3   ; TABLA
01eb8c:  move.b    (a3, d0.w), d0 ; tabla[byte+4]
01eb90:  tst.b     d0
01eb94:  move.b    d0, $a030.w    ; <- ENCOLAR EL SONIDO
```

**Medido:** `$A030 = $7C` aparece en casi todos los golpes de la corrida de
referencia. Es el sonido del impacto.

## 5e. `$F558` es el hit-time, y `$6A` es el nivel de empuje

### `$F558` = hit-time del golpe que MATA

Esta es la respuesta al pendiente 7. El pipeline de `loc_01EDAC` es, en orden:

```asm
01edb4:  bsr.w    $1eee2      ; grab
01edb8:  bsr.w    $1f090      ; clash
01edbc:  bsr.w    $1f21e      ; hit vs hurt
01edc0:  bsr.b    $1ee1e      ; push
01edc2:  move.w   #$0, $a004.w ; <- limpiar los 5 contadores
...
01eda4:  jmp      $21960.l    ; luego SONIDO
```

Y despues el hit-time, que es `$F558` con su toggle de bit 1 hacia `$F55A`:
**160 frames de camara lenta, y solo cuando `$78` queda negativo.**

**Consecuencia que cierra el pendiente:** el hit-time por golpe es **`$69` = 16**
para todo, sin excepcion. Los valores de `$69` en todo el ROM son **0, 16, 28 y
255**, y no hay un quinto. **No existe un hit-time especial por movimiento.**

El "hit-time de las ultis" que se venía buscando **no esta, porque no existe**: la
premisa de que las especiales congelan mas viene de una guia, no del ROM. Lo unico
distinto es el **255**, que es la congelacion total de la ult de Itsuki, y eso no
es un hit-time sino otra cosa.

### `$6A` = nivel de empuje, NO es blockstun

Un byte con valor **1, 2 o 3**, escrito junto al empuje:

| Valor | Velocidad (`$10`) | Empuje (`$14`) | Direccion |
|---|---|---|---|
| 1 | `$2B000` = 2.69 | `$FFFC0000` = −4.0 | `0x1F33A` |
| 2 | `$40000` = 4.0 | `$FFFB0000` = −5.0 | `0x1F464` |
| 3 | `$56000` = 5.375 | `$FFFA0000` = −6.0 | `0x1F486` |

**El selector es `$64(a3) & #$03`**, y los bits 2-3 del mismo `$64` participan en
la mascara de defensa:

```asm
01f318:  move.b    $64(a3), d0
01f31c:  andi.b    #$0c, d0
01f320:  and.b     $63(a4), d0    ; mascara de defensa del DEFENSOR
01f324:  cmpi.b    #$0, d0
01f328:   beq.w    $1f414         ; 0 -> golpe limpio, con stun
01f32c:  move.b    $64(a3), d0
01f330:  andi.b    #$3, d0        ; <- NIVEL DE EMPUJE
```

**Un mismo `$64` con dos nibbles para dos cosas distintas:** los bits 0-1 eligen
cuanto empuje, los bits 2-3 la defensa. Por eso dos `andi.b` con mascaras
distintas sobre el mismo byte.

## 5f. **[MEDIDO 08-10] El gate de "¿estamos en pelea?"**

Se necesitaba un disparador para que un efecto (la lluvia de `LLUVIA DIAGONAL.LUA`)
saliera solo durante el combate y no en los menus. Se eligio **por medicion**, con
una sonda que imprime una linea cada vez que uno de los candidatos cambia, y el
ciclo `titulo -> seleccion -> combate -> KO -> menu`, dos peleas seguidas.

**De los cuatro candidatos, SOLO el HP cambia al entrar y al salir.** Y el gate
resultante es **"¿DOS de los cuatro slots tienen HP > 0?"** — el `>` y el **dos**
salieron de dos mediciones distintas, y **la segunda corrigio a la primera**.

| Frame | `hp` de los 4 slots | `$F550` | Que estaba pasando |
|---|---|---|---|
| 417 | `0/0/0/0` | `$00` | menu |
| **652** | **`223/223/0/0`** | `$00` | **entra la pelea 1** |
| 667-849 | `111/111`, el slot 2 baja con el dano | `$00` | pelea 1 |
| **851** | **`0/0/0/0`** | `$00` | **KO, se acabo** |
| 1844 | `0/0/0/0` | `$00` | menu |
| **1845** | **`223/0/0/223`** | `$00` | **entra la pelea 2** |
| 1864 | `223/0/0/223` | **`$01`** | `$F550` cambia aqui |
| 3209 | `223/0/0/-7` | `$01` | el enemigo cae por debajo de 0 |
| 3466 | `223/0/0/-1024` | `$01` | el enemigo, al centinela |
| 3997 | `0/0/0/-1024` | `$00` | |
| **3998** | **`0/0/0/0`** | `$00` | **fuera** |

Las transiciones de **entrada** son de **un frame**.

### La segunda medicion corrigio el gate: "> 0" no es "estamos peleando"

Con el gate de **"alguno con HP > 0"**, la segunda corrida dio:

| Frame | `hp` | Gate | |
|---|---|---|---|
| 3680 | `147/0/0/**-5**` | `enpelea=1` | **el enemigo ya esta muerto** |
| 4177 | `147/0/0/-1024` | `enpelea=1` | el enemigo, al centinela |
| 4667 | `0/0/0/-1024` | `enpelea=0` | recien aqui |

**987 frames (16 s) de lluvia con el combate ya terminado.** El unico que mantenia
la lluvia prendida era el ganador, con 147 de vida, y eso dura toda la pose de
victoria, el cartel de round y la transicion al menu.

**El gate correcto es "DOS VIVOS"**, o sea **la regla del juego**: un round termina
cuando **bajan de dos peleadores**.

| | |
|---|---|
| Pelea 1, `223/223` | 2 vivos → lluvia |
| Pelea 2, `223/0/0/223` | 2 vivos (los slots 1 y 4) → lluvia |
| Pelea 2, `147/0/0/-5` | **1 vivo → NO hay lluvia** |

**Y no es un parche para el 1v1.** Con cuatro peleadores el conteo va `4, 3, 2, 1` y
la lluvia se apaga en el `1`, que es justo cuando se acaba el round.

***Lo UNICO que queda abierto:*** un modo de **un solo peleador** (practice), donde
nunca hay dos vivos y la lluvia no sale nunca. No se entro a un modo asi.

### La regla final: "2+ vivos, o 1 vivo y NADIE muerto" — y el dato que falta

**Dos mediciones se contradijeron, y cada una mató una regla.**

| Regla | Que rompia |
|---|---|
| `> 0` | La pelea 2 dejo de llover **987 frames despues del KO**: el enemigo cayo a -5 en el 3680 y el gate se apago en el 4667, cuando el P1 (que seguia con 147) llego a 0 |
| `>= 2` slots con `HP > 0` | **Se apagaba con un peleador VIVO en el piso.** MEDIDO por el usuario: *"la CPU tenia 0 de vida, le lance un ataque especial, lo bloqueo, no murio, y las gotas se detuvieron"* |

**La segunda es la que importa como regla:** **`HP == 0` NO es estar muerto.** En este
juego se muere cuando la vida baja **de** 0, asi que un peleador en exactamente 0
sigue peleando. **`> 0` estaba equivocado desde el principio** y se acepto porque en
las dos peleas medidas no se dio el caso.

La regla que sale de todos los estados medidos:

> **Hay pelea si hay 2 o mas slots con `HP > 0`, o si hay UNO y NINGUN slot tiene `HP < 0`.**

| Estado | `hp` de los slots | vivos | muertos | Gate |
|---|---|---|---|---|
| Menú | `0/0/0/0` | 0 | 0 | **no** |
| Menú | `0/0/0/-1024` | 0 | 1 | **no** |
| Pelea 1, al entrar | `223/223/0/0` | 2 | 0 | **si** |
| Pelea 2, al entrar | `223/0/0/223` | 2 | 0 | **si** |
| **Peleador a 0 bloqueando** | `147/0/0/0` | 1 | 0 | **si** |
| Pelea 2, en el KO | `147/0/0/-5` | 1 | **1** | **no** |

Las dos filas de negrita son los dos casos que cada regla anterior rompia, y cada una
tiene su propia prueba en el banco.

**Y "2 o mas vivos" cubre el 1v4**, que con la regla de "bajan de dos" se apagaba al
primer KO: con cuatro peleadores el conteo va 4, 3, 2 mientras quedan vivos y no hay
ninguno muerto todavia.

#### ***LO QUE FALTA MEDIR, y es un numero de un frame***

La regla usa **`HP < 0` como "muerto"**, y eso **no esta verificado**. El unico escritor
negativo del ROM es `0x1A1A4: move.w #$fc00, $78(a5)` = **-1024**, el **centinela de
fin de pelea**, y no un "-1 al primer golpe".

**La pregunta que lo decide:** en el caso del bloqueo —peleador en HP 0 que bloquea un
especial y no muere— **¿que valor tiene el HP en el frame siguiente?**

| Si el HP queda… | Entonces |
|---|---|
| en `0`, o sube | La regla esta bien: el bloqueo no lo mata y no lo apaga |
| en un negativo chico (`-3`, `-7`) | **La regla esta mal y hay que cambiar la condicion de "muerto"** por algo que no sea el signo |

Es el mismo protocolo de siempre: una medicion, un numero, y el gate se decide con el.
**No se pone un margen de frames ni un `-1` de inventario porque seria inventar.**

### Sintoma del 08-10: "gotas congeladas" — el gate NO lo explica, y por eso hay un `pcall`

> ### El sintoma del overlay congelado puede ser un CALLBACK MUERTO
>
> Una excepcion dentro de `emu.registerafter` **se traga** en este emulador: no sale
> error, no sale aviso, y el callback muere a mitad. **Lo que se ve es el overlay con
> el ultimo frame dibujado, congelado** — o sea, exactamente "las gotas se quedan
> estaticas en pantalla".
>
> Con el gate apagado, en cambio, las gotas se matan Y no se dibujan: son dos cosas
> separadas, y las dos verificadas en el banco. **Si quedan visibles, el gate no es la
> explicacion** y hay que mirar si el callback llego a `draw_lluvia`.
>
> **Por eso ahora el cuerpo del frame va en `un_frame`, envuelto en un `pcall` que
> avisa en la consola CADA frame que falla**, con el numero de frame y el frame en que
> empezo. Antes no habia nada, y un fallo de una linea tardaba una sesion entera en
> aparecer. El mensaje se le limpian los bytes > 127 (la consola los muestra como dos
> caracteres y el error se vuelve ilegible justo cuando sirve).
>
> ***Verificado con tres pruebas que ROMPEN el frame a proposito*** (no el callback
> entero: si se reemplaza `frame_cb`, el `pcall` del script ni se ejecuta y la prueba
> mide otra cosa — se rompe `gui.drawline`, que se llama desde adentro):
>
> | | |
> |---|---|
> | un fallo dentro del frame **avisa** en la consola | **si** |
> | el mensaje es **ASCII** | **si** |
> | al frame siguiente el efecto **vuelve a andar** | **si** |
>
> ***OJO: esto es una herramienta de diagnostico, no una explicacion del sintoma que
> reporto el usuario.*** Si en su corrida el callback no se muere, la linea
> `[yuyu] ERROR` no aparece y el sintoma sigue sin explicar: en ese caso la pista
> seria que los boxes **tambien** estan congelados (o no lo estan), y eso separa
> "callback muerto" de "gate mal".

### El ciclo pedido, con los valores exactos: `-1024` -> `0` -> `223`

Lo que se pide, textual: **con HP en `-1024` o en `0` no se dibuja ni una gota; con
HP en `223` vuelve.** Los tres valores son los del ciclo del menu, MEDIDO:

| HP | Donde | Lluvia |
|---|---|---|
| **`-1024`** (`$FC00`) | centinela, el slot lo conserva en el menu (frame 3997) | **no** |
| **`0`** | los cuatro slots vacios en el menu (frame 3998) | **no** |
| **`223`** | inicio de pelea (frames 652 y 1845) | **si** |

Verificado como DIBUJADO en `test_hitbox_hud.lua` (179 pruebas), y no solo como
valor del gate: `max_lineas(20) == 0` en los tres primeros casos, `> 0` en el
cuarto, y el ciclo repetido dos veces para que no sea un caso único.

**`-1024` y `0` dan lo mismo por el signo, no por el numero.** El gate usa `> 0`, y
por eso los dos son "no hay pelea". Con `!= 0` el `-1024` contaria como pelea y el
menu lloviendo: **8 fallos** en el banco.

**Y OJO: `223` NO es el disparador.** La regla es `> 0`, y esa diferencia importa:

> Si el gate preguntara **"¿HP == 223?"**, la lluvia **se apagaria en el primer
> golpe**, porque el HP baja a 222 de inmediato y no vuelve a 223 hasta la ronda
> siguiente.

MEDIDO en la pelea 2, un solo round: `223 -> 200 -> 147 -> 5 -> -5 -> -1024`. El
valor `223` es el **inicio** de la pelea, no su estado. La mutacion a `== 223` da
**4 fallos** en el banco.

### Como se medicio, y por que la sonda ya no esta

Todo lo de arriba salio de una **sonda** que se cargo en `LLUVIA DIAGONAL.LUA` e
imprimia una linea cada vez que un candidato cambiaba, durante el ciclo
`titulo -> seleccion -> combate -> KO -> menu`. **Esa sonda se BORRO del script
cuando el diagnostico cerro**: era andamiaje de medicion, no del efecto, asi que no
tiene sentido dejarla corriendo.

**Lo que se conserva es el DATO**, en este documento y en el comentario del gate.
Y en el banco quedan las pruebas de **comportamiento**, que no dependen de que
exista ninguna sonda:

| | |
|---|---|
| Sin pelea, ningun layer vivo | `max_lineas(20) == 0` |
| En pelea | `max_lineas(20) > 0` y `vivas_por_capa() > 0` |
| Ciclo `-1024 -> 0 -> 223` | 0 lineas, 0 lineas, 43 lineas, y otra vez |

Lo que se borro con ella: 18 pruebas que contaban lineas `[SONDA]` de una sonda que
ya no existe. **Y tambien las declaraciones adelantadas** de `LLUVIA_DEF` y `lluvia`,
que habia que mantener **sin `local`** solo porque la sonda las leia mil lineas antes
de que existieran. Esa es la trampa de "un local declarado mas abajo" pagandose un
costo permanente en el codigo de produccion por un diagnostico temporal.

### El sintoma "congelada y visible" — CERRADO por prueba, no por argumento

> El usuario reporto: *"la lluvia se detiene (queda estatica) cuando P1 o P2 muere"* y
> *"esa lluvia que quedo estatica sigue viendose luego en el menu y solo se corrige
> cuando empieza un nuevo combate"*.

**Eso NO puede ser esta lluvia, y ahora es una PRUEBA y no un argumento.**

| | |
|---|---|
| Caminos de dibujado de la lluvia en TODO el script | **UNO**: los dos `gui.drawline` de `draw_lluvia` (gotas y salpicaduras), los dos detrás del `and enp` de la capa |
| Con el gate apagado | `update_lluvia` mata las 43 gotas **y** `draw_lluvia` no entra al bucle, **en el MISMO frame** |

Dos pruebas del banco, y apuntan al **frame exacto** en que el gate se apaga, no a una
ventana de 20:

| | |
|---|---|
| `en el PRIMER frame con el gate apagado ya se dibujan 0 lineas de lluvia` | **0** |
| `y el pool ya esta VACIO en ese mismo frame` | **0** |

**O sea que no existe un estado "dibujada y quieta" de esta lluvia.** Si queda
congelada en pantalla, no es del script.

**Lo que si es del juego:** el stage tiene su propia lluvia, y en las pantallas de
menu el fondo es una imagen estatica donde la lluvia es parte del arte (o queda
congelada). Encima se ve el overlay, que no la toca. La foto del usuario muestra
lineas verticales palidas sobre TODA la imagen, incluido el marco decorativo de
arriba, y el menu marca **59,73 fps**: no hay consola inundada, asi que la teoria
del framerate caido esta muerta.

**Lo unico que faltaba era la prueba de las capas.** Con el gate ya corregido (2+ vivos,
o 1 vivo y nadie muerto), el efecto aparece y desaparece en el frame del KO, y eso
tambien esta verificado: `vivas = 43` entrando, `vivas = 0` saliendo.

***Sigue pendiente un dato, y es el que falta para cerrar la regla:*** **¿que valor
tiene el HP de un peleador que esta en 0 y bloquea un especial, en el frame justo
despues?** De eso depende si "HP < 0" sirve como "muerto".

### [MEDIDO 08-10] La retencion: la superficie de `gui.*` de FBNeo no se limpia

**LA CORRECCION PRIMERO, y es mia.** Se escribio que las gotas congeladas en el menu
eran "la lluvia del stage". **Es FALSO, y el usuario lo dijo: el juego no tiene
ningun escenario con lluvia.** Lo de la lluvia del stage fue una supresentacion mia
escrita como si fuera un dato, y no lo era. Lo que hay en el juego en los menus es
la decoracion de los menus, no lluvia.

**MEDIDO, con el gate de "2+ vivos, o 1 vivo y nadie muerto":**

| Tramo | `lluvia=` |
|---|---|
| Menu antes de la pelea | **0**, en todas las lineas |
| Pelea | `27, 29, 31, 33, 32, 30, 33` |
| **KO** (todavia en el stage) | **0** — baja **exactamente** en el KO |
| Menu despues de la pelea | **0**, en todas las lineas |

Sin `[yuyu] ERROR` y sin la barra roja: **el callback esta vivo**. Y el gate nuevo
funciona: la lluvia baja a 0 en el frame del KO, no 987 frames despues.

**Y LA PRUEBA QUE LO CIERRA** (la hizo el usuario): **cerrar y reabrir la ventana de
Lua en el MENU borra las gotas**, y el ciclo vuelve a funcionar de menu a pelea. Con
eso:

| Sintoma | Explicacion |
|---|---|
| Las gotas quedan congeladas en el menu | La **superficie de `gui.*` de FBNeo no se limpia cuando el script no dibuja nada**, y queda el ultimo frame compuesto |
| Solo se corrige al empezar un combate nuevo | Ahi el script vuelve a emitir llamadas de dibujado, y la superficie se vuelve a componer |
| Cerrar y reabrir el `.lua` lo arregla | Superficie nueva |

**Ninguna de las tres es del logico de dibujado de este script:** con `lluvia = 0` no
se dibuja ni una gota, y el banco lo comprueba en el PRIMER frame del apagado.

#### El arreglo, y lo que NO se

**Si este frame no se dibujo ninguna gota, se emite una llamada de dibujado con alfa
0.** Es invisible (el alfa va en el byte bajo, y `00` es transparente) pero **es una
llamada**, y fuerza a que la superficie se vuelva a componer vacia:

```lua
if gotas_dibujadas == 0 then
  gui.drawline(0, 0, 0, 0, color(0x00, 0x00, 0x00, 0x00))
end
```

***LO QUE NO SE, y no se decide leyendo:*** si FBNeo limpia la superficie **al
presenciar** el overlay o **antes de cada llamada** de dibujado.

| Si es al presenciar | El pixel invisible **arregla** el sintoma |
|---|---|
| Si es antes de cada llamada | El pixel **no borra nada** (mezcla con alfa 0) y el sintoma sigue |

**La corrida del usuario lo decide.** Por eso el pixel va con este comentario al
lado y no escondido, y por eso el banco comprueba las DOS mitades: `gotas(1) == 0`
(las lineas de lluvia, medidas por el mock de `gui`) **y** "el script igual emite
alguna llamada" — porque **`0` lineas y `0` llamadas no son lo mismo**, y esa
distincion es justamente la que faltaba para poder reproducir la retencion.

***Y el test de "apagar las tres capas" NO servia para esto:*** con `lluvia = 0` el
script no dibuja, asi que apagarlas tampoco borra nada. Un test de "apagar" solo vale
cuando lo que se ve esta **siendo dibujado ahora**; para "algo quedo pegado" hay que
descartar antes que algo se dibuje.

### **[MEDIDO 08-10] RESUELTO: FBNeo limpia la superficie AL PRESENCIAR**

Corrida del usuario con el pixel invisible: **"las gotas ahora desaparecen antes de
que comience la transicion al menu al matar al enemigo"**. O sea:

| | |
|---|---|
| Al matar al enemigo las gotas **desaparecen**, y desaparecen **antes** de que arranque la transicion al menu | El pixel invisible **SI** fuerza la recomposicion, y FBNeo limpia la superficie **al presenciar** el overlay |
| El sintoma esta cerrado | No hace falta ninguna otra tecnica, y **no** hay que dibujar el fondo a mano |

**Con esto quedan CERRADAS las dos preguntas de la lluvia:**

| | |
|---|---|
| La lluvia sale y entra con la pelea | **SI**, con el gate de "2+ vivos, o 1 vivo y nadie muerto" |
| La lluvia se oculta del KO hasta la pelea siguiente | **SI**, y en el frame del KO |

**Y el atraso de la pelea a menu que se vio al principio quedo resuelto por el camino
corto**: no hacia falta esperar a que el HP del ganador llegara a 0. Con la regla
actual, el segundo peleador cae a negativo y el gate se apaga en ese frame.

**Lo que sigue ABIERTO, y es de otra cosa:** si **`HP < 0`** sirve como "muerto" (ver
arriba, el caso del bloqueo). Eso no tiene nada que ver con el dibujado: es la
semantica del gate, y se resuelve con **un solo numero** del HP de un peleador que
esta en 0 y bloquea un especial.

### El bug del 08-10 que encontro el usuario: DOS `emu.registerafter`

Al meter el `pcall` del callback con la herramienta de edicion se quedaron **DOS**
`emu.registerafter` completos en el script: el nuevo, con el `pcall` y el aviso, y el
viejo entero debajo (2236 lineas). Los dos registraban la misma logica por frame.

**No lo detecto ninguna prueba:** `luajit -bl` limpio y **171 pruebas en verde**.
Las dos instalaciones dan el mismo comportamiento visible, asi que el banco no lo ve.

**La unica forma de verlo es contar:**

```powershell
Select-String -Path "tools\fightcade\LLUVIA DIAGONAL.LUA" -Pattern "emu\.registerafter"
# tiene que dar 1
```

Lo mismo con `un_frame = function`. **En un archivo que grew con parches, el numero
de `registerafter` / `registerexec` / `registerafter` tiene que ser una asercion, no
una costumbre.**

### El sintoma "congelada y visible": el CONTADOR DE GOTAS DIBUJADAS

El sintoma se discutio entre "es del script" y "es del stage" **a ojo**, y a ojo no se
gana: las lineas del stage y las del overlay se parecen, y una foto no las separa.

**La salida es un numero, no una opinion.** `gotas_dibujadas` cuenta las gotas
**realmente dibujadas** en el frame (despues de los dos recortes de muerte y de HUD,
y contando gotas y no lineas, porque H.Rain dibuja 2 lineas por gota). Va en el
latido que ya se imprimia cada 60 frames, asi que no agrega ni una linea por frame.

```
[yuyu] dib=0 src=exec pj=... lluvia=33 | ...     <- en pelea
[yuyu] dib=0 src=stale pj=... lluvia=0  | ...    <- en menu
```

**La medicion del banco con los valores reales** (168 pruebas): `lluvia` da
`22, 28, 29, 30, 31, 32, 33` en pelea y **`0`** en menu. El 33 es el tope: 10 de
H.Rain + 10 de B.Rain (la mitad parpadea) + 13 de C.Rain.

**Y ACA ESTA LA TRAMPA QUE CASO ESTE CONTADOR, la novena vez que aparece y la mas
barata.** La variable quedo declarada **dos veces**:

```
linea ~483 : local gotas_dibujadas = 0     <- la que lee el latido
linea 1871 : local gotas_dibujadas = 0     <- SEGUNDA, dentro del ambito de draw_lluvia
linea 1956 : gotas_dibujadas = gotas_dibujadas + 1   <- escribe la de 1871
```

O sea: el contador se **escribia** en un local y el latido **leia** otro. El numero
daba **0 siempre**, sin error, con `luajit -bl` limpio y **168 pruebas en verde**.

**Es la trampa al reves** (no "declarado mas abajo" sino "declarado dos veces"), y
salio pegada justo en el contador que existe para que el diagnostico no mienta. Por
eso el banco ahora exige las **dos** mitades: `gotas(1) == 0` (las lineas dibujadas,
medidas por el mock de `gui`) **y** `YUYU_TEST.gotas_dibujadas() == 0` (el contador
del script). Un `0` solo no distingue "no hay lluvia" de "el contador esta roto".

### Que corre y que NO corre en los menus [MEDIDO 08-10]

Del volcado de la sonda, en los tramos de menu (frames 1289-1844 y 4668-4871 de la
segunda corrida):

| | En pelea | En menu |
|---|---|---|
| `$FFA014` — **base X del stage** | **se mueve cada frame** | **tambien se mueve**: `$03B9`, `$036C`, `$0360`, `$03C1` |
| `$8C` — tabla de moves | 2 slots | **oscila**: 0, 1, 0, **2**, 0, 1 |
| `$01EDAC` — dispatcher de colisiones | corre | **no corre**: contadores en 0 y `src=stale` |
| `$F550` bit 7 | 0 en la pelea 1, 1 en la pelea 2 | 0 |

**O sea que el menu NO congela el juego:** el sistema de stage y de camara sigue
vivo (`$A014` avanzando) y las maquinas de estados del jugador siguen escribiendo
`$8C`. Lo que **no** corre es el pipeline de colisiones.

### ***¿La lluvia del stage ya esta "calculada" en el menu, en capas inferiores?***

**La pregunta se parte en dos, y una parte es FALSA y la otra no esta verificada.**

| Parte | Veredicto |
|---|---|
| "ya esta calculada" | **Parcialmente medido: el stage NO esta congelado.** `$A014` avanza en el menu y `$8C` se sigue escribiendo. Lo que **no** sabemos es si las tiles del stage ya estan en VRAM |
| "solo que no se ve porque esta en capas inferiores" | **FALSA tal como esta escrita.** Una capa inferior se dibuja **detras**: si la lluvia estuviera ahi, no se veria. **Y se ve**: la foto muestra lineas palidas en los huecos entre los paneles de la UI. O sea que no esta oculta, esta **dibujada** y la UI la tapa encima en parte |

***Lo que no se puede responder desde aca:*** el mecanismo exacto (capa del VDP
desactivada con `h40`/`v40` en cero, o capa dibujada y tapada por la UI) requiere
**leer los registros del VDP**, y eso **no se puede hacer con un script pasivo**:

- En Genesis los registros del VDP se leen escribiendo el indice en `$C00004` y
  leyendo el valor de `$C00000`. Eso es el **bus del Z80**, y requiere una
  **escritura** en la memoria del juego → **rompe la regla 5**.
- El unico script del repo que lo hacia (`herramientas/desensambladolua/vdpinfo.lua`) es de
  **BizHawk** (`memory.write_u16_be`, `BUS = "M68K BUS"`), y ademas tiene una ruta
  quemada a `C:\Users\leand\...`. MEMORIA.md dice que los `.lua` de BizHawk **no se
  portan**.

Queda como pendiente, y es de los que **no se cierran con Lua pasiva**.

| Candidato | Por que NO sirve |
|---|---|
| **`$F550` bit 7** | Estuvo en `$00` **toda** la pelea 1 y en `$01` la pelea 2. No acompana ni la entrada ni la salida. Es el flag de "simulacion suspendida": gatea `loc_01EDAC` (`01edac: btst.b #$7, $f550.w`) y las dos maquinas de estados (`0x12AE6`, `0x13688`) |
| **`$F558` / `$F55A`** | Solo prendieron al **final** de la pelea 2, cuando el enemigo ya estaba muerto, y **nunca** en la pelea 1. `$F558` es el timer de la muerte (160 = `$A0`, unico escritor `0x1FA82`) y cuenta con wrap. Ver §5e |
| **`$8C != 0`** (tabla de moves) | En el **menu** oscila: frames 1344 -> 1, 1442 -> 0, 1456 -> **2**, 1518 -> 0, 1588 -> 1, con los cuatro slots en HP 0. O sea que "tiene tabla" prueba "**hubo** pelea", no "estamos peleando": el puntero del ultimo round se queda |

### Por que `> 0` y no `!= 0`

El HP va a **`-1024` (`$FC00`)** al terminar y el slot **lo conserva en el menu**:
medido, frame 3997, `hp=0/0/0/-1024`. Con `!= 0` el menu contaria como pelea.

Y hay frames de pelea con HP **negativo**: en la pelea 2 el enemigo paso por
**-7, -16, -22** antes de llegar a -1024. Con `> 0` esos frames no cuentan por ese
slot.

### ***Lo que la medicion NO cubre***

Las dos peleas las gano el jugador, y en las dos el P1 seguia con vida (111 y 223)
cuando el otro caia, asi que **el gate no se apago antes de tiempo ni una vez**. En
un **doble KO**, con los dos slots en negativo, el gate se apagaria durante la
animacion del final. No se midio. Y no se le pone un margen de frames porque ese
seria un numero inventado.

Ademas el gate prueba "**hay ALGO VIVO**", que en las dos peleas medidas coincide
con "estamos peleando" porque el stage solo se dibuja ahi. En la pantalla de
victoria el gate cae cuando los peleadores mueren, no cuando aparece el cartel. Para
lluvia da igual.

### La correccion que hubo que hacer antes de medir

Se escribio que el HP **no podia** servir de gate porque `0x12AE6` y `0x13688` lo
escriben cada frame con `#$FF` y no lo borran al salir. **La segunda mitad era
falsa**: lo que se comprobo es que el HP **vuelve a 0** al terminar. El `$FF` se ve
un frame y despues el juego lo baja a 223 (la barra `$7A` lo persigue,
`0x157A8`) y de ahi lo baja el dano crudo (`sub.w $65, $78(a4)`, `0x1F424`).

La razon de fondo era una confusion de alcance: **"se escribe cada frame" no dice
nada de un gate**, porque el gate tambien se lee cada frame. Lo unico que importa es
si el **valor** distingue estar dentro de la pelea de estar fuera. Resulta que si.

### Donde esta implementado y como se protege

`en_pelea()` en `LLUVIA DIAGONAL.LUA`. Se lee **una vez por frame** en el
`registerafter` y se pasa a `update_lluvia()` y a `draw_lluvia()`: leerlo dos veces
en el mismo frame son dos respuestas posibles.

La sonda imprime **`vivos=`**, cuantos slots tienen HP > 0. Va en el texto
**comparado** a proposito, y es el unico campo de la sonda que cambia poco (el dano
que no mata no lo cambia), asi que cada linea es un cruce del cero: justo lo que
decide el gate.

**Gatea las dos, no solo el dibujado.** Fuera de pelea se matan todas las gotas y se
pone `lluvia_sembrada[t] = false`, igual que cuando se apaga una capa desde el menu.
Si solo se dejara de dibujar, las gotas quedarian colgadas en el aire y al arrancar
la pelea siguiente aparecerian todas de golpe en el punto donde las congelo. Las
salpicaduras mueren tambien. Asi la lluvia **queda oculta** desde el KO hasta la
proxima pelea, y no "se frena".

Verificado con once mutaciones del banco (`test_hitbox_hud.lua`, seccion 9y):

| Mutacion | Resultado |
|---|---|
| `vivos >= 2` -> `vivos >= 1` | **3 fallos** |
| `muertos == 0` -> `muertos == 1` | **4 fallos** |
| **fuera la regla de "1 vivo y nadie muerto"** | **1 fallo** — el del bloqueo |
| un `HP < 0` no cuenta como muerto | **3 fallos** |
| `h > 0` -> `h >= 0` | **9 fallos** |
| gate solo en el dibujado, no en la simulacion | **1 fallo** (el pool queda vivo) |
| gate solo en la simulacion, no en el dibujado | **0 fallos**: mutacion EQUIVALENTE |

La tercera es la importante: **quitar la regla del bloqueo es un fallo y no se
pierde entre las demas**, porque la prueba de ese caso esta escrita con las palabras
del usuario al lado.

### Sintoma del 08-10: "gotas congeladas y visibles en el menu" — **CERRADO: no es esta lluvia**

**Lo que el usuario ve:** durante las etapas del menu la lluvia queda congelada pero
las gotas se siguen viendo, y al terminar la pelea las gotas que estaban cayendo se
quedan congeladas en el aire.

**Lo que midio la sonda** (corrida completa, dos peleas, ciclo titulo -> combate ->
KO -> menu):

| | |
|---|---|
| Frames de menu con `enpelea=0` | **11** |
| De esos, con `vivas=0` | **11** |
| De esos, con `vivas>0` | **0** |

**Y las transiciones son de UN frame**, con el gate y el pool. Eso tambien explica por que las
gotas del final no quedan "a medio caer": el pool pasa de 42 a 0 en el mismo frame en
que el gate se apaga.

```
frame  652  hp=223/223/0/0    enpelea=1  vivas=43     <- ENTRA pelea 1
frame  833  hp=0/0/0/0        enpelea=0  vivas=0      <- KO
frame 1529  hp=223/0/0/223    enpelea=1  vivas=43     <- ENTRA pelea 2
frame 4177  hp=147/0/0/-1024  enpelea=1  vivas=42     <- el enemigo al centinela
frame 4667  hp=0/0/0/-1024    enpelea=0  vivas=0      <- fuera
```

**Por que el dato CIERRA el sintoma y no solo lo hace probable.** `vivas` cuenta
`lluvia[t][i].viva`, y `draw_lluvia` **solo dibuja cuando `p.viva`**. Con las 43
gotas en `viva = false` el script no puede dibujar **ni una** linea de lluvia: no es
una cuestion de que "parezca" apagada, es que no hay nada que dibujar.

**O sea que lo que se ve congelado en los menus es la LLUVIA DEL PROPIO JUEGO**, que
es un layer de fondo del stage y queda congelada cuando la pantalla cambia a menu.
Our overlay esta encima y no la toca.

***La confirmacion que falta, y es de un minuto:*** con la sonda apagada, **MODE ->
apagar H.Rain, B.Rain y C.Rain**, y ver si las gotas congeladas siguen en pantalla.
Si siguen, son del juego.

### Un hallazgo lateral de esa misma corrida: `$F558` se rearma en CADA golpe a un peleador ya muerto

**No es "una vez al morir".** MEDIDO 08-10, con el enemigo en HP negativo (`-5`,
`-13`, `-18`, `-22`, `-27`, `-36`, `-44`, `-51`, `-58`), cada golpe suyo **vuelvo a
poner `$F558` en 160** y vuelve a contar: **9 veces en 320 frames**, una cada 40
frames, y siempre en el MISMO frame en que el HP cambia.

| Frame | HP del enemigo | `$F558` |
|---|---|---|
| 3680 | `-5` | 159 (recien puesto a 160) |
| 3720 | `-13` | 159 |
| 3760 | `-18` | 159 |
| ... | ... | ... |
| 4000 | `-58` | 159 |

O sea que el disparador es **"le pegaron a alguien con HP negativo"**, no "el peleador
murio". El escritor sigue siendo el unico de todo el ROM (`0x1FA82: move.w #$a0,
$f558.w` = 160), pero **corre las veces que haga falta**. ***Lo que NO se confirmo es
que sea ese mismo `0x1FA82` el que reaplica: lo que se midio es que el valor vuelve
a 160 en el frame exacto del golpe.***

**Y esto refuerza por que el gate tiene que ser `> 0` y no `!= 0`**: un slot muerto
sigue recibiendo golpes y sigue con HP **negativo y variable** (-5, -13, -58...), no
con un centinela fijo. Un gate de "hay dano, luego hay pelea" fallaria.

### `$F558` como reloj del final de la pelea: el gate de HP dejo de cortar la lluvia

**[MEDIDO 08-10] + [ESCRITO en `LLUVIA DIAGONAL.LUA`].** Del dato anterior sale una
cosa que no se habia visto: **`$F558` no es un flag, es la cuenta regresiva**, y por
eso alcanza para decidir el final de una animacion sin contar un solo frame.

| | |
|---|---|
| Valor al morir | **159** (el escritor pone 160 y el frame siguiente ya ve 159) |
| Cuentan hacia abajo | 158, 157, ... 120 |
| En un refresco | **salta de 120 a 159**: nunca pasa por 0 mientras el slow-mo sigue |
| Cuando llega a 0 | el slow-mo se acabo |
| En toda la pelea 1 y en los menus | **0** |

O sea que **`$F558 > 0` es un flag limpio de "hay camara lenta de muerte"**, y su
valor son los frames que faltan. Y como su unico escritor en todo el ROM es
`0x1FA82` y esta en el camino de la muerte, **`$F558 != 0` SIEMPRE es una muerte**: no
existe el caso raro de "slow-mo sin muerte" que habria pedido una rama aparte.

**La duracion total del slow-mo, con los 9 refrescos: del frame 3680 al 4159 = 479
frames, no 160.** Un contador propio del script no podia dar ese numero: solo
leyendo `$F558` sale, y sale solo.

**Que se escribio con esto, en `LLUVIA DIAGONAL.LUA`:** cuatro fases, y el gate de HP
pasa a **encender** la lluvia nada mas:

| Fase | Cuando | Que hace |
|---|---|---|
| `NORMAL` | hay pelea | velocidad normal |
| `SLOW` | `$F558 > 0` | **velocidad a la mitad** (`MULT_SLOWMO = 0.5`), y se sincroniza sola |
| `COLA` | `COLA_FRAMES` (= 120) frames **despues del ULTIMO** frame de slow-mo | velocidad normal |
| `OFF` | despues | no se dibuja |

Las dos decisiones que llevan el numero:

| | |
|---|---|
| **El gate ya no apaga** | Un INFERIDO ("¿queda alguien en pie?") puede encender una animacion pero no la puede cortar: por ahi salio el bug de los **987 frames** de lluvia despues del KO. **El que apaga es `$F558`, que cuenta frames hacia atras.** |
| **`$F558 > 0` gana sobre el gate** | En el frame del KO caen las dos senales a la vez (HP negativo **y** `$F558` = 159). Con ese orden no hay ni un frame entre "llueve normal" y "llueve a la mitad", y el pool **no se re-siembra** en el KO |
| **El gate prendido gana sobre la COLA** | Una pelea nueva no espera a que se acabe una cola de la pelea anterior, y no hay un frame sin lluvia en medio de un combate |
| **Un refresco rearma la cola** | Salir de `SLOW` rearma la `COLA` desde cero, asi que la cola espera **al ultimo** slow-mo y no al KO original |

**Lo que NO se puede cubrir con esto, y queda como supuesto declarado:** el caso de
**1v1 con el rival bloqueando en HP 0**. El gate de HP sigue teniendo el hueco ya
anotado mas arriba (dos peleadores en exactamente 0 dan `0 vivos, 0 muertos` -> no hay
pelea), y con `$F558` ese hueco se nota igual: la lluvia se apaga con los dos en pie.
***No medido: no se entro a un 2v2, y no hay ningun byte que separe "peleador sin
vida" de "slot vacio".*** El trabajo se hizo bajo el supuesto de 1v1, declarado en el
`.lua`.

***Y el numero de 120 es una SELECCION A OJO, no una medicion:*** viene pedido, y lo que
falta es mirarlo en el emulador. La continuacion acordada es 300 frames con deteccion
de START para cortarlo.

## 6. Secretos y modos

| Dato | Detalle |
|---|---|
| Flag modo oculto | `$F550` bit 7; establecido en `0x3ADE`, testeado en `0x39B0` |
| Flag modo completado | `$F55A`, establecido en `0xFEBC` |
| Debug | Opciones + `START` + `A` + `C` |

## 7. Personajes (identidad, verificada)

IDs segun la tabla de seleccion del propio juego:

| ID | Nombre | Japonés |
|---|---|---|
| 1 | Sensui | 仙水 |
| 2 | Jin | 陣 |
| 3 | Itsuki | 樹 |
| 4 | Genkai | 幻海 |
| 5 | **Kuwabara** | 桑原一雄 |
| 6 | Yusuke | 浦飯幽助 |
| 7 | **Kurama** | 蔵馬 |
| 8 | Hiei | 飛影 |
| 9 | Chui | 酎 |
| 10 | Toguro (hermano mayor) | 戶愚呂兄 |
| 11 | Toguro (hermano menor) | 戶愚呂弟 |

**Kuwabara (桑原一雄, ID 5) y Kurama (蔵馬, ID 7) son personajes distintos.**
Sus sprites y sus datos estan intercambiados en varias guias web.

## 8. Protocolo de arranque Z80 (verificado en el desensamblado)

```
000356:  bset.b #0, $a11100.l     ; esperar Z80 detenido (BUSREQ = 1)
038a92:  lea.l  $393fe(pc), a0    ; driver Z80 (0xC00 bytes) en ROM
038a96:  lea.l  $a00000.l, a1     ; destino = espacio Z80 = work RAM $FF0000
038aa0:  move.b (a0)+, (a1)+
038aa6:  move.w #$0, $a11200.l    ; soltar el bus: el Z80 corre
```

El arranque tambien testea `$A10008` y `$A1000C` esperando que el driver Z80
escriba en esos puertos.

---

## Lo que NO esta verificado

Queda explicitamente fuera de este documento:

- **Medidor de super**: sin direccion. `$B9` es el byte alto de `$B8`, o sea del
  mana, asi que no sirve para HP ni para super.
- Offset `$4E`: sin identificar
- Notas de stats A/B/C/S
- **Blockstun**: sin direccion. Los tres resolvers van a dano. El **valor 32** se
  midio en ejecucion y es coherente con la escala (28 clash > 16 hitpause), pero
  **sin direccion no entra como dato**: es una medicion, no una lectura.
  Candidatos sin verificar: `$63` (`and.b $63(a4),d0` en `0x1F320`), `$64` bit 5,
  `$71` bit 1, `$6C` bits 0-5.
- **Que campo es `$3C`**: se sabe que vale `($C6 + $81) * 2` (`0x1FA5A`), o sea que
  escala con el combo, pero no que representa.
- Si los 7 bits bajos de `$26` son profundidad o prioridad de dibujo — ver §5c
- **Base del slot de P2: `$FF8800` o `$FF9000`.** Hay dos candidatos y no se
  eligio. Ver la nota de §3.
- Tabla de comandos
- Limite de la lista de frames de cada move (falta para cerrar el frame data)
- Costes y timings exactos de super

Y esto ya se **resolvio** desde la ultima version, no sigue pendiente:

- `stun_max` por personaje: 40, 56, 48, 44, 54, 46, 40, 38, 48, 62 — ver §2b
- El largo de 32 bits de `$14..$17`: es el empujon — ver §2b
- Startup / active / recovery: el registro de frame son 8 bytes en ROM, con `+0`
  = duracion y bit 6 = frame activo. Ver `TABLAS_MOVES_Y_TIMING.md` §1
- Hitstun: `$7E` es un presupuesto, `ceil($80/$66)` golpes hasta knockdown
- **Hit-time: `$26` NO lo es.** Verificado por las direcciones y por el hecho de
  que se decrementa — ver §5c
- **El mana por combo ya no viene de web.** Es `$C6 * 2` con `$C6` en el
  defensor, verificado en `loc_01F9C8` — ver §2a

Ver tambien `COLISIONES_Y_HITBOXES.md` §8 para los errores concretos del
material externo de Discord / BizHawk.


## EL TELEPORT DE ITSUKI: LA CADENA DE ESTADOS (MEDIDO)

**Fuente: sonda `herramientas/lua/sonda_teleport.lua`, 2024-10.**
**[MEDIDO]**, no deducido.

| frame | `$5F` | mundo X | mundo Y | suelo `$9C` | pantalla |
|---|---|---|---|---|---|
| 58761-58797 | `$A4` | 895 | 320 | 320 | 279,315 |
| 58798 | `$A5` | 896 | 320 | 320 | 279,315 |
| 58799 | `$A5` | **1048** | 320 | 320 | **432**,315 |
| 58836-58905 | **`$25`** | 1048 → 1127 | **320 → 240 → 320** | 320 | 315 → 242 → 316 |
| 58906-58931 | `$28` | 1129 | 320 → 311 → 320 | 320 | |
| 58932-58956 | `$29` | 1142,50 | 320 | 320 | |
| 58957-... | `$2A` | 1142,50 | 320 | 320 | |

**Hechos medidos:**

| Dato | Valor |
|---|---|
| La Y del ancla durante TODO el teleport | **320 = el suelo**, nunca se va |
| El teleport coloca X | 895 → **1048** (zona C: pantalla 432) |
| El "aire" | **NO es la Y**: es el estado **`$25`**, un salto de 80 px (vy = −6 px/frame) |
| Cuando empieza | **1 frame** despues de acabar la colocacion |
| El unico escritor de `$5D = $25` en todo el ROM | **`$01905E`** (el dash de 8 de mana de Itsuki) |
| El handler de `$03` | `$019F90` -> `$18440` = estado `$00` (reposo, en el suelo) |
| Limite izquierdo del escenario | `$a010` = **880** |
| Limite derecho del escenario | `$a012` = **1168** |
| Base de las 3 zonas del teleport | `$a010` = 880 -> 912 / 1040 / 1168 |
| El estado `$25` de ctx6 | frames en `$0CFE4A`, durs 4,4,8,**255** |

**El parche** `itsuki_teleport_suelo` cambia `$019061` de `25` a `03`
(1 byte): el dash/teleport deja de terminar con el salto y vuelve al reposo
en el suelo.


## LAS 3 FASES DEL TELEPORT DE ITSUKI

| Fase | Estado | Bloque de frames | Ticks (original) | Ticks (parcheado) | Receta |
|---|---|---|---|---|---|
| 1. el blink | `$A4` | `$0D044A` | 37 | **22** | `13_itsuki_teleport_40mas_rapido` |
| 2. la colocacion | `$A5` | `$0D04BA` | 45 | **25** | `15_itsuki_teleport_colocacion_rapida` |
| 3. el "aire" | `$25` | `$0CFE4A` | 4,4,8,**255** | (eliminado) | `14_itsuki_teleport_pisa_el_suelo` |

**El bloque de frames de la fase 2** (`$0D04BA`, 16 registros de 8 bytes,
byte+0 = duracion):

| frame | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dur original | 1 | 4 | 1 | 3 | 1 | 2 | 1 | 1 | 2 | 1 | 3 | 1 | 4 | 6 | 6 | 8 |
| dur parcheado | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 3 | 3 | 4 |
| anim | 59 | 0 | 59 | 0 | 59 | 0 | 59 | 0 | 59 | 0 | 59 | 0 | 59 | 146 | 145 | 14 |
| | | | | | | | | | | | | | | | **aterrizaje** |

Anim 59 = visible, anim 0 = invisible (el parpadeo del teleport).


## EL MASH DEL ATURDIMIENTO (el estado $0C)

**Fuente: desensamblado** (verificado con Capstone, que es la verdad).

| Dato | Valor | Donde |
|---|---|---|
| Estado del "aturdido" tras el knockdown | **`$0C`** | handler en `$01A282` |
| La barra de aturdimiento al entrar | **255** (`#$ff`) | `$01A282` |
| El contador real | **`$84`** (word) | |
| Cuanto baja por frame | **1** | `$01A28E` |
| Cuanto baja **por pulsacion de boton** | **2** (original) / **3** (con el parche) | `$01A29A` |
| Ticks extra al frame por pulsacion | **2** (original) / **3** (con el parche) | `$01A2A6` |
| Cuando se levanta | `$84 <= 1` | `$01A2AA` |
| Al levantarse | `$18440` = estado `$00` | `$01A2BA` |
| Botones que cuentan | los de **`$72`** (flags de boton) | `$01A292` |
| El boton debe estar a menos de `$C8` (200) ticks | | `$01A29E` |

**El mash:** hay que machar para bajar `$84` de 255 a 1. Con -2 por
pulsacion hacen falta **~128 pulsaciones** (por eso es casi imposible); con
el parche (x1,5, o sea -3) hacen falta **~85**.

**Parche:** `mash_aturdimiento_x15`, 2 bytes: `$01A29A` (`$55`->`$57`) y
`$01A2A6` (`$54`->`$56`). Ojo: el dato de SUBQ/ADDQ va en los bits 11-9
del opcode, no en un byte aparte.
