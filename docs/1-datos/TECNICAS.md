# Las TECNICAS (los especiales de cada personaje)

Las técnicas son los moves `$A0`–`$AF` (y algunos más). **El id es la ranura y
el dato es del personaje**: el mismo `$A6` es una cosa en Kuwabara y otra en
Hiei. Solo hay 14 ids **básicos** globales; las técnicas son por personaje.

Los comandos salen de `docs/2-personajes/FICHAS_DE_PERSONAJES.md` (la ficha
traducida) y se cruzan con `notas/GENERAL/CONTEXTO.txt` (las mediciones).

---

## 1. Kuwabara (ctx1, `$0C229A`)

Ficha: *Ataque A · Defensa A · Velocidad C · Salto B · Global B+* · **Stun 56** (el
2º más alto) · **Rojo** (rol) · Provocación con stun 64.

Ids de técnica: `$A0 $A1 $A2 $A3 $A4 $A5 $A6 $A8 $AA $AB $B8`.

| Técnica | Comando | Daño | Maná | Stun | Id |
|---|---|---|---|---|---|
| Espada espiritual (vertical) | `A+B` | 18×2 | 12 | 10×2 | `$A0` |
| Espada espiritual (horizontal) | `↓+A+B` | 15×2 | 12 | 10+8 | `$A1` |
| Espada espiritual aérea | `↑↓+A+B` | 20+10 | 12 | 10×2 | `$A2` |
| Espada espiritual (agachado) | `↓+A+B` | 15×2 | 12 | 8+6 | `$A3` |
| Estocada espiritual | `↓←+A/B` | 20 / 15 | 16 | 12 | `$A4` / `$A5` |
| **Shuriken espiritual** | `↓↓+A/B` | **8×3** | 18 | 6×3 | **`$A8`** |
| **Hoja dimensional** | **`↓↑+A/B/C`** | **8×3** | **20** | **6×3** | **`$A6`** |
| Tormenta de espadas (super) | `↓↓→+A` | (20+)×11 | 200 | (8+)×11 | `$AA`? |

### 1.1 LA HOJA DIMENSIONAL = `$A6`

**↓↑ + A/B/C** · 20 de maná · **3 golpes de 8 de daño** · stun 6 por golpe.

Es una **invocación**: el personaje no tiene hitbox. Los 3 golpes **salen de un
objeto**, igual que el shuriken.

| Dato | Valor | Dónde |
|---|---|---|
| Id del move | **`$A6`** | ctx1, registro `$0C2E52` |
| El objeto usa el **layout de personaje completo** | `$50 = $0D92CA`, `$8C = $0D9A3A` | **las mismas tablas que las manos de Itsuki** |
| El **facing** (`$61`) decide de qué lado sale | | |
| **A/B/C eligen la distancia** del spawn (176 / 112 / 48 px) | | en Itsuki son esas; en Kuwabara **no se sabe ninguna** |
| La caja del objeto | activa 12 frames, startup 5, recovery 1; el objeto nace a 176 px y se va a los 21 frames | [MEDIDO] |
| El objeto nace con estado `$0C` (el shuriken con `$0D`) | | |

### 1.2 EL BYTE QUE LA DISTINGUE DEL SHURIKEN: `$67`

Los dos son objetos en la misma tabla, con el **mismo daño, el mismo stun y el
mismo empuje**. Se distinguen en **un solo byte**: el nibble **`$67`** del 4º
byte del blob.

```
        +64  +65  +66  +67  +68
Shuriken  1E   08   06   01   01     -> PROYECTIL
Hoja dim. 1E   08   06   02   01     -> FISICA (con clash)
```

**Los 6 blobs con esa firma** (daño 8, stun 6, empuje `$1E`):

| Blob | `$67` | Qué es | Cajas (radioX) |
|---|---|---|---|
| **`$0D9CAA`** | **2** | **hoja dimensional** | 12, 14, 8 |
| **`$0D9CB6`** | **2** | **hoja dimensional** | 18 |
| **`$0D9CC6`** | **2** | **hoja dimensional** | 9 |
| `$0D9CD6` | 1 | shuriken | 6, 8, 8 |
| `$0D9CE2` | 1 | shuriken | 4, 6, 8 |
| `$0D9CEE` | 1 | shuriken | 4, 6, 8 |

**El byte a tocar para cambiar el `$67`** (está en el 4º byte de cada blob):

| Byte | De | A | Efecto |
|---|---|---|---|
| `$0D9CAD` | `21` | `11` | la hoja dimensional pasa a ser PROYECTIL |
| `$0D9CB9` | `21` | `11` | ídem |
| `$0D9CC9` | `21` | `11` | ídem |

> **Ojo**: el nibble alto es `$67` y el bajo `$68`. Cambiar `21`→`11` deja
> `$68 = 1` intacto y mueve solo `$67` de 2 a 1. Ese es el discriminador
> **proyectil / físico**, confirmado en 4 de 4 casos por las notas (§106).

### 1.3 Los moves de la tabla de objetos

| Move | Registro | Blobs |
|---|---|---|
| **8** | `$0D93DA` | solo el de la hoja (`$0D9CC6`) |
| 9 | `$0D93F2` | hoja + shuriken |
| 10 | `$0D9442` | hoja + shuriken |
| 11 | `$0D9452` | solo shuriken |


### 1.5 EL OBJETO DE LA HOJA Y EL DEL SHURIKEN

Los dos son objetos en la **misma tabla** (`$50 = $0D92CA`, sub-lista
`$8C = $0D9A3A`) y los dos pegan **3 golpes de 8 con stun 6**. Se distinguen
en **un solo byte: el `$67`** (el nibble alto del 4º byte del blob).

| | Registro | `$67` | Qué es |
|---|---|---|---|
| **Hoja dimensional** (↓↑+A/B/C, `$A6`) | `$0D948A` | **2** | **FÍSICA**, con clash |
| **Shuriken** (↓↓+A/B, `$A8`) | `$0D94AA` | **1** | **PROYECTIL** |

Los tres frames con hitbox de cada uno, y el blob de cada uno:

| Técnica | frame | b1 | flags | blob | `$65` | `$66` | `$64` | `$67` | cajas (radioX) |
|---|---|---|---|---|---|---|---|---|---|
| **Hoja** | f0 | 24 | `$0D9A9A` | `$0D9CAA` | 8 | 6 | `$1E` | **2** | 12, 14, 8 |
| | f1 | 25 | `$0D9A9E` | `$0D9CB6` | 8 | 6 | `$1E` | **2** | 18 |
| | f2 | 26 | `$0D9AA2` | `$0D9CC6` | 8 | 6 | `$1E` | **2** | 9 |
| **Shuriken** | f0 | 28 | `$0D9AAA` | `$0D9CD6` | 8 | 6 | `$1E` | 1 | 6, 8, 8 |
| | f1 | 29 | `$0D9AAE` | `$0D9CE2` | 8 | 6 | `$1E` | 1 | 4, 6, 8 |
| | f2 | 30 | `$0D9AB2` | `$0D9CEE` | 8 | 6 | `$1E` | 1 | 4, 6, 8 |

> **OJO con la resolucion del blob.** En la tabla de **objetos** el offset de la
> sub-entrada es **relativo a la BASE de la sub-lista** (`$0D9A3A`), no a la
> entrada: `blob = $0D9A3A + word(entrada+2)`. En la tabla de **personajes** es
> relativo a la **entrada**: `blob = entrada + word(entrada+2)`. Con la forma
> equivocada los datos salen absurdos (daño 136, stun 127…) en vez de 8 y 6.
>
> **El dato ancla:** la planta de Kurama tiene el blob `$0D9CF6` = `08 04 1E 25`
> (daño 8, stun 4, empuje `$1E`, `$67=2`, `$68=5`), que es justo lo que dicen
> las notas. Y el dragón de Hiei (ctx3, move 38, frame 0) da `$0C99B2` con
> daño 56 / stun 36 / empuje `$06` con la forma **relativa a la entrada**.

> **Y OJO con `$0D9CB6`**: es a la vez la **caja 2** del blob `$0D9CAA` y la
> **cabecera** del blob `$0D9CB6`. Por eso un parche ahi es ambiguo.

### 1.6 Parche: 2 hits que pegan el doble, y más recovery

**Grupo `kuwabara_hoja_2hits_doble` — 3 bytes:**

| Byte | De | A | Qué hace |
|---|---|---|---|
| `$0D9AA2` | `60` | `20` | flags del **f2** (b1=26): se quita el bit 6, el de hitbox |
| `$0D9CAA` | `08` | `10` | `$65` = **el daño** del blob del f0: de 8 a **16** |
| `$0C2EA2` | `0C` | `14` | duración del **f10 del personaje**: de 12 a 20 ticks |

**2 hits:** queda el f0 y el f1 con hitbox (los dos primeros, 4 ticks cada uno).
**Doble daño:** el daño es **crudo** — el motor resta `$65` tal cual, sin
multiplicador (`0x1F420` lo carga en d0 y `0x1F424` lo resta) — así que 16 es
exactamente el doble de 8.

**Más recovery:** el f10 es el **último frame de la cadena del personaje**
(`$0C2E52`), donde espera a que el objeto termine. Alargarlo de 12 a 20 ticks
deja al personaje **61 ticks bloqueados en vez de 53** (+8 ticks = +0,13 s).

El shuriken (↓↓+A/B) **no se toca**: sus blobs son `$0D9CD6`, `$0D9CE2` y
`$0D9CEE`.

### ⚠️ El byte del daño es ambiguo

`$0D9CAA` es a la vez:

- el `$65` (daño) del blob del f0 de la hoja dimensional, **y**
- el **radioX** de una caja de los blobs `$0D9CA2`, `$0D9CA6` y `$0D9C9E`
  (los `b1` = 15, 16 y 22 de la misma tabla de objetos).

Al pasar de 8 a 16, esas **tres cajas pasan de radioX 8 a radioX 16**. El bit 7
se queda en 0 (8 = `0000 1000`, 16 = `0001 0000`), así que **no se alargan las
cadenas de cajas**; solo se ensanchan esas tres hitboxes.

**Si en el juego se nota que otra técnica pega más lejos, este byte es el
culpable.** El daño sale de `$65` y no hay otro sitio.

### Cómo queda el frame data con el parche

| | Original | Con el parche |
|---|---|---|
| golpes | 3 (f0, f1, f2) | **2** (f0, f1) |
| daño por golpe | 8 | **16** |
| daño total | 24 | **32** |
| ventana activa | 12 ticks (97..108) | **8 ticks** |
| último golpe | tick 12 | **tick 8** |
| personaje bloqueado | 53 ticks | **61 ticks** |

### Otros bytes para ajustar el recovery

| Byte | Qué | Actual |
|---|---|---|
| `$0C2E82` | duración del **f6** del personaje | 8 ticks (+4) |
| `$0D94A2` | duración del **f3** del objeto (el frame sin hitbox) | 4 ticks (+4) |

### 1.4 Lo que NO se sabe

- **Las distancias del spawn de Kuwabara.** Solo se midió una (176 px). En
  Itsuki son 176 / 112 / 48 px. Si coinciden, los tres valores están en el ROM
  y no hacen falta partidas para medirlos. [ABIERTO]
- Si el botón (A/B/C) cambia el `$67` o no. Las notas apuntan a que **no**: el
  `$67` es de la técnica, y el botón es lo que cambia la distancia.

---

## 2. Referencia rápida de las técnicas de los 11

| Personaje | ctx | Ids de técnica | Notas |
|---|---|---|---|
| Sensui | 4 | `$A4` (parry alto), `$A6` (parry bajo), `$A7` (contraataque), `$AC` (bola aérea) | el parry **roba maná del rival** |
| Jin | 5 | | |
| Itsuki | 6 | `$A3` (manos / 影手) | las manos son un **objeto** (tipo `$10`, move 6, handler `$149AC`) |
| Genkai | — | | el **Reikodan** es un objeto (handler `$12C96`) |
| **Kuwabara** | **1** | `$A0`-`$A6`, `$A8`, `$AA`, `$AB` | ver §1 |
| Yusuke | 2 | `$AC` (Reigan aéreo) | |
| Kurama | 0 | `$A3` (la planta), `$A4`/`$A5` (el proyectil), `$A6` (la ulti), `$A7` (etapa de la ulti), `$B8` (agarre) | la planta sale de un **objeto** |
| Hiei | 3 | `$A2` (espada de fuego, 3 golpes), `$A6` (la ulti), `$A8` | **Hiei no tiene parry** |
| Chui | 8 | | |
| Toguro mayor | 7 | | |
| Toguro menor | 9 | | |

> El **rol** (rojo/azul) está en `$6E` y decide a quién puede alcanzar cada
> golpe. Los agarres y las provocaciones lo usan.

---

## 3. Cómo se Investigation esto

| Herramienta | Para qué |
|---|---|
| `herramientas/desensamblado/ctx_hits.py 1` | qué moves de Kuwabara tienen hitbox y con qué blob |
| `herramientas/desensamblado/blob_chain.py 1 <move>` | la cadena de cajas de un move, frame a frame |
| `herramientas/desensamblado/blob_dump.py` | vuelca los blobs: daño, stun, empuje, radios |
| `notas/GENERAL/CONTEXTO.txt` | las mediciones (buscar por `Kuwabara`, `$A6`, `Hoja dimensional`) |

La fuente de las distancias, los frames y el maná es
`notas/GENERAL/CONTEXTO.txt` (se busca con `grep`, no se lee entero).

### 1.9 EL TELEPORT DE ITSUKI

**Abajo+arriba + A/B/C.** 16 de maná en las tres. Es **una sola tecnica con un
parámetro**: el botón elige la zona (A = izquierda, B = centro, C = derecha), y
las tres comparten el mismo estado.

| Dato | Valor |
|---|---|
| Estado | **`$A4`** (el teleport en curso) |
| Siguiente | **`$A5`** (aterrizaje, 16 frames) -> `$A9` (en el suelo) -> `$00` |
| Contexto | **ctx6** = Itsuki, tabla base `$0CF99A` |
| Bloque de frames | **`$0D044A`** |
| Frames | 14 (anims 57, 58, 59 y luego el parpadeo visible/invisible) |
| Duracion (fase 1, el blink) | **37 ticks** (original) / **22 ticks** (con el parche `itsuki_teleport`) |
| Siguiente (fase 2) | **`$A5`**, bloque de frames **`$0D04BA`**: **45 ticks** (original) / **25 ticks** (con el parche `itsuki_teleport_colocacion`) |
| Transicion `$A4`->`$A5` | **`$01926A`** (unica llamada: el handler de `$A4` en `$01B6E8`) |

El byte +0 de cada registro es la duracion del frame (la copia a `$5A` esta en
`$01EB5A`). El parche `itsuki_teleport` lleva el total de 37 a 22 ticks (un 40,5% menos).


### 1.9.bis EL FINAL DEL TELEPORT: QUE PISE EL SUELO

**Medido** (sonda `herramientas/lua/sonda_teleport.lua`): el teleport **sí**
coloca al personaje en el suelo (Y = 320 = `$9C`) y en la zona correcta
(X 895 → 1048, la zona C). Lo que lo manda al aire es **el dash de "arriba"**
(8 de maná, `$01904E`), que dispara el "ARRIBA" del comando
(abajo+arriba+A/B/C) al terminar: pone `$5D = $25` y el personaje sale
volando 80 px (Y 320 → 240), tardando 70 frames en volver.

El parche `itsuki_teleport_suelo` (**1 byte** en `$019061`) cambia
`$5D = $25` por `$5D = $03`, y el teleport acaba en el reposo (estado `$00`)
plantado en el suelo. Ver **PARCHES.md seccion 12**.


### 1.9.ter LA FASE DE COLOCACION: 45 -> 25 TICKS

El teleport tiene 3 fases: `$A4` (el blink), `$A5` (la colocacion, bloque de
frames en `$0D04BA`) y `$25` (el "aire"). La fase 2 son 45 ticks: 25 del
parpadeo final (13 frames, anim 59 visible / anim 0 invisible) y 20 de la
animacion de aterrizaje (3 frames, anims 146, 145 y 14).

El parche `itsuki_teleport_colocacion` (9 bytes, todos el byte+0 = duracion)
la deja en **25 ticks**: el parpadeo en 15 y el aterrizaje en 10. Mismo
criterio que el parche del blink: minimo 1 tick por frame y el descuento se
saca de los frames mas largos. Ver **PARCHES.md seccion 13**.
