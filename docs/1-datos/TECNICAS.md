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
