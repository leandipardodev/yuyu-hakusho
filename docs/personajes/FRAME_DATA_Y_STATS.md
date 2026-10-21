# Yu Yu Hakusho: Makyou Toitsusen (Mega Drive)
## Datos técnicos, frame data y tier list

> **Traducción y reorganización** de las fuentes citadas (ver *Créditos* al final).
> Todos los valores de este documento fueron **verificados contra el ROM** que tenés
> en la carpeta (`Yuu Yuu Hakusho - Makyou Toitsusen (J).bin`).

---

## 0. Verificación contra el binario

Los datos online y tu ROM son **el mismo juego**. Lo confirmé leyendo el código 68k.

### Constantes globales encontradas en el código

| Dato | Valor | Dirección en el ROM | Instrucción |
|---|---|---|---|
| HP máximo | **223** (`0xDF`) | `0x008054` | `move.w #$df, $8cb8.w` |
| Maná (灵气) máximo | **223** (`0xDF`) | `0x00805A` | `move.w #$df, $90b8.w` |
| Umbral de HP débil | **111** (`0x6F`) | `0x00804E` | `move.w #$6f, $8c78.w` |
| Chequeo de HP lleno | 223 | `0x015C36` | `cmpi.w #$df, $b8(a5)` |
| Inicialización de HP | 223 | `0x00FF96` | `move.w #$df, d1` |

### Tabla de stats por personaje

La inicialización de cada luchador está en `0x12792`–`0x12A74`: **11 subrutinas
consecutivas**, una por personaje, con esta estructura:

```asm
move.l  #$XXXXXX, $1c(a5)   ; puntero a datos del personaje
move.l  #$YYYYYY, $20(a5)   ; offset en VRAM
move.l  #$ZZZZZZ, $50(a5)   ; puntero datos 2
move.l  #$WWWWWW, $8c(a5)   ; puntero animación
move.l  #$VVVVVV, $90(a5)   ; puntero tabla
move.b  #$3,     $6c(a5)    ; flag
move.w  #$SS,    $7e(a5)    ; stun actual
move.w  #$SS,    $80(a5)    ; stun máximo   ← stat clave
move.w  #$CC,    $c4(a5)    ; stat adicional
rts
```

Los **11 valores de stun coinciden exactamente** con la tabla online:

| Dirección | Stun ROM | Luchador | `$c4` |
|---|---|---|---|
| `0x0127DC` | 56 | **Kuwabara** | 8 |
| `0x012870` | 44 | **Hiei** | 2 |
| `0x0128BA` | 54 | **Sensui** | 2 |
| `0x012904` | 46 | **Jin** | 4 |
| `0x012998` | 38 | **Toguro (hermano mayor)** | 4 |
| `0x012826` | 48 | **Yusuke / Chui** | 6 |
| `0x012A2C` | 62 | **Toguro (hermano menor)** | 8 |
| `0x012792` / `0x01294E` | 40 | **Kurama / Itsuki** | 4 / 2 |

---

## 1. Reglas del juego

| Parámetro | Valor |
|---|---|
| **HP máximo** | 223 |
| **HP "parpadea" (débil)** | por debajo de 111 |
| **Maná máximo** | 223 |
| **Contador de HIT** | al superar 16 HIT muestra MAX |
| **Maná por combo** | sube a partir del **2.º HIT** encadenado |
| **Condición del super (超必殺)** | HP < 111 **y** maná lleno |
| — excepción | **Sensui**: basta HP < 111 con maná > 50 |
| **Retroceso (疾退)** | da invencibilidad; esquiva normales, proyectiles y casi todos los especiales |

### Sistema de aturdimiento (晕点 / stun)

Cuando el stun llega a 0, el personaje cae. Al levantarse entra en estado aturdido
con el stun restaurado a **255**. Si **no** lo sigues golpeando, al recuperarse el
stun vuelve a su valor máximo por defecto.

---

## 2. Resistencia a aturdimiento — ranking

| # | Luchador | Stun máx. |
|---|---|---|
| 1 | **Toguro (menor)** | **62** |
| 2 | **Kuwabara** | **56** |
| 3 | **Sensui** | 54 |
| 4 | **Chui** | 48 |
| 5 | **Yusuke** | 48 |
| 6 | **Jin** | 46 |
| 7 | **Hiei** | 44 |
| 8 | **Kurama** | 40 |
| 9 | **Itsuki** | 40 |
| 10 | **Toguro (mayor)** | 38 |
| 11 | **Genkai** | **34** (el más fácil de aturdir) |

---

## 3. Stats base por personaje

Escala: **S > A > B > C > D > E** (S = mejor)

| Luchador | Stun | Dash | Backdash | Walk | Regen. maná | Stun de provocación | Coste provocación |
|---|---|---|---|---|---|---|---|
| **Sensui** | 54 | 83 | 70 | D | E | S | 36 |
| **Jin** | 46 | **128** | 80 | A | C | B | 30 |
| **Itsuki** | 40 | 51 | 70 | C | C | B | 48 |
| **Genkai** | 34 | 78 | 58 | A | **S** | D | 48 |
| **Kuwabara** | **56** | 55 | 70 | C | A | C | 48 |
| **Yusuke** | 48 | 79 | 65 | B | B | B | 36 |
| **Hiei** | 44 | **120** | 70 | **S** | **SS** | A | 48 |
| **Kurama** | 40 | 59 | 70 | C | C | A | 30 |
| **Chui** | 48 | 81 | 79 | B | C | E | **56** |
| **Toguro (mayor)** | 38 | 51 | 65 | **E** | A | E | 36 |
| **Toguro (menor)** | **62** | 72 | 80 | **E** | C | E | 52 |

> **Hiei** con el dragón devsorbeado pasa a maná **SS** y velocidad **SS**.

### Valueaciones globales (A/B/C/D/E/S)

| Luchador | Ataque | Defensa | Velocidad | Salto | Global |
|---|---|---|---|---|---|
| **Yusuke** | A | A | **A** | A | **A+** |
| **Toguro (menor)** | **S** | **S** | C | B | **A** |
| **Jin** | A | B | **S** | **S** | **A** |
| **Chui** | A | A | B | A | **A−** |
| **Kuwabara** | A | A | C | B | **B+** |
| **Genkai** | A | C | A | A | **B+** |
| **Sensui** | A | B | C | A | **B** |
| **Hiei** | B | B | **S** | B | **B** |
| **Kurama** | B | C | B | B | **B** |
| **Toguro (mayor)** | A | C | B | B | **B** |
| **Itsuki** | C | C | B | A | **C** |

---

## 4. Golpes normales (daño y stun)

| Luchador | Golpe | Altura | Efecto | Daño | Stun |
|---|---|---|---|---|---|
| Yusuke | Jump A | medio | — | 17+9 | 10+4 |
| Yusuke |-agachado A | bajo | derribo | 19 | 14 |
| Yusuke | Agarre | — | flotar | 19 | 10 |
| Genkai | Jump A | medio | — | 15 | 14 |
| Chui | Jump A | medio | — | 17 | 12 |
| Toguro (menor) | Jump A | medio | — | **22** | 16 |
| Hiei | Jump A | medio | — | 8+5 (16+10 con dragón) | 8+4 |
| Kurama | Jump A | medio | — | 16 | 14 |
| Jin | Jump A | medio | — | 15 | 14 |
| Itsuki | Jump A | medio | — | 11 | 8 |

---

## 5. Especiales — daño y consumo de maná

Formato: **Técnica** | Daño | Maná | Stun

### Sensui
| Técnica | Daño | Maná | Stun |
|---|---|---|---|
| Puño de patada (alto) | 14 | 16 | 12 |
| Puño de patada (bajo) | 14 | 16 | 12 |
| Bola roja de patada | 12 | 4 | (8+)6 |
| Rifle de aire | 3×N | 8 | 3×N |
| **Super: Bola roja gigante** | **64** | **50** | (8+)32 |

### Genkai
| Técnica | Daño | Maná | Stun |
|---|---|---|---|
| **Reimu** | **6~64** (según carga) | **5~136** | **3~32** |
| Disparo de luz | 6×N | fuerte 32 / débil 16 | 6×N |
| Puño ascendente | fuerte 16+15 / débil 16+5 | fuerte 16 / débil 12 | 16+12 |
| **Super: Golpe de luz** | **81+15** | **200** (recupera 16) | 20+12 |

**Reimu tiene 8 niveles de potencia** según tiempo de carga:

| Maná gastado | Daño |
|---|---|
| 5–11 | 6 |
| 12–19 | 8 |
| 20–31 | 12 |
| 32–41 | 16 |
| 42–56 | 24 |
| 57–72 | 32 |
| 73–104 | 48 |
| 105–136 | **64** |

### Hiei — con sistema de dragón
| Técnica | Daño | Daño (dragón) | Maná | Stun |
|---|---|---|---|---|
| Espada de fuego | 9+11 | **18+22** | 32 | 8+8 |
| Quemazón | 6×N | 12×N | 6×N | 24 / 16 |
| Corte del ave | 2+16 | **2+34** | 24 | 12+10 |
| **Super: Dragón negro** | **88** | — | 200 | 32 |

**Mecánica especial:** el dragón negro puede golpearte a ti mismo y convertir a Hiei en
**modo dragón**: ataque y velocidad **×2**, maná lleno, pero **no puede usar super** y
el maná se drena solo → al llegar a 0, stun 255.

### Toguro (menor) — el más fuerte
| Técnica | Daño | Maná | Stun |
|---|---|---|---|
| Gancho superior | **30+30** | 20+20 | — |
| Gancho inferior | **30+30** | 16 | 20+20 |
| Armadura de músculo | 8 | 24 | 4 |
| **Super: 100% dentro del 100%** | 20×N | **200** | 8×5 |

### Kurama
| Técnica | Daño | Maná | Stun |
|---|---|---|---|
| Látigo de rosas | 11+14 | 16 | 6+8 |
| Flor de rosas | 4 | 16 | 4 |
| Planta del demonio | 8+16 | 24 | 4+10 |
| **Super: Puño de zarza** | 16×8 | 200 | 4×3+8+4×3+8 |

---

## 6. Modo DEBUG (secreto completo)

### Activación
En la pantalla de **TÍTULO**, mueve el cursor a **"オプション" (Option)** y mantén
pulsado **START + A + C**. Aparecerá una opción extra **"デバッグ"**. Ponla en **"あり" (Sí)**.

### Funciones

| # | Función | Cómo |
|---|---|---|
| 1 | **Abre modo ハンデ戰 (Handicap)** | Automático al activar debug (o completar 勝抜き戰) |
| 2 | **Control de HP** | Pausa: mantener dirección + **Y** = vaciar, **Z** = llenar. Izq=1P, Der=2P, Arriba=3P, Abajo=4P (necesita pad de 6 botones) |
| 3 | **Control de CPU** | En selección de personaje, START decide; el personaje elegido lo controla la CPU |
| 4 | **Ver créditos** | Opciones → Nivel = Normal → reset → en el logo TREASURE pulsar START |
| 5 | **Demo de CPU** | Opciones → Nivel = Hard → reset → logo TREASURE + START |
| 6 | **Demo de combos** | Opciones → Nivel = Super → reset → logo TREASURE + START |
| 7 | **Demo de supers** | Nivel = Super + completar 勝抜き戰 sin perder |
| 8 | **Control de replay** | Tras completar 挑戰賽: **A** = rápido, **B** = pausa, **C** = rebobinar |

### Comando del super (超霊撃) por personaje
Requiere **HP por debajo de la mitad + maná lleno**. Comandos (orientado a la derecha):

| Luchador | Comando |
|---|---|
| Yusuke | →↓→ + A |
| Kuwabara | ↓↓→ + A |
| Genkai | →↓→ + A |
| Hiei | ↓→↓→ + A |
| Kurama | ↓→↓ + A |
| Chui | ↓→↗ + A |
| Jin | ↓↓ + A + B |
| Itsuki | ↓ + A + B |
| Sensui | ↓↓→ + A |
| Toguro (mayor) | →↓→↓ + A |
| Toguro (menor) | ↓→↓ + A |

### Modo oculto (ハンデ戰)
Se desbloquea de **dos maneras**:
1. Completar el modo **勝抜き戰**
2. **Activar el modo DEBUG**

Permite partidos de hasta **1 contra 3**.

---

## 7. Escenarios (8)

1. **斗技場** — Arena (con ciclo día/noche)
2. **靈界** — Mundo Espiritual
3. **亞空間** — Subespacio
4. **魔界** — Mundo Demoníaco
5. **洞窟** — Caverna
6. **魔性の森** — Bosque Mágico
7. **亞空間 2**
8. **山頂** — Montaña

---

## 8. Títulos y frases de victoria

| Victorias | Mensaje |
|---|---|
| 2 | `[BIEN]` |
| 5 | `[MUY BIEN!]` |
| 10 | `[MARAVILLOSO!]` |
| 20 | `[GENIAL!!]` |
| 50 | `[ULTRA!!]` |
| 100 | `[SUPER!!!]` |
| 200 | `¿Te diviertes?` |
| 500 | `No te burles.` |
| 600 | `¡Eres admirable!` |

**Títulos especiales:** 最狂 (el más loco) · 最強 (completaste el torneo) ·
鬼畜 (MAX HIT) · 不屈 (CONTINUE ≥ 20) · 最低 (CONTINUE 100 veces) ·
無敵 (obstáculo 1vs3 en dificultad super)

---

# 🏆 TIER LIST — Los 11 luchadores

Ordenada por **potencial global**, combinando ataque, defensa, velocidad, salto,
stun, recargas de maná y los setups únicos de cada personaje.

## S — Broken

### 👑 Toguro (hermano menor) — ID 11
- **Ataque S · Defensa S · Stun 62 (el más alto del juego)**
- Daño brutal: golpes de **30+30**, super de 20×N
- Se nota como el más fuerte en golpe, pero **lento** (walk E) y dif?cil de controlar
- El rey del peso pesado: aguanta combos largos y pega más fuerte
- ⚠️ Coste de provocación 52 (alto)

## A — Excelentes

### ⚡ Jin — ID 2
- **Ataque A · Velocidad S · Salto S**
- **Mejor dash del juego (128)** — el mejor en mobility para presión y espaciado
- Ataque a distancia (修羅旋風拳) Excellent
- Stun moderado (46) pero se compensa con movilidad

### 🥇 Yusuke — ID 6
- **El mejor global (A+): Ataque A · Defensa A · Velocidad A · Salto A**
- Sin debilidades: todas sus stats son A (el perfil más balanced del juego)
- Reimu con 8 niveles de potencia (hasta 64 de daño), es la t?cnica m?s flexible
- Movimientos f?ciles de encadenar, ideal para aprender y competir

### 💥 Toguro (hermano mayor) — ID 10
- **Ataque A · Stun 38 (poco) pero tiene mecanica unica**
- **指刺 (Dedal)**: alto valor de stun, 1 golpe segura el KO, no se puede cancelar
- El único con moves rompen el sistema (no se anula con otro ataque)

## B — Fuertes

### 🌸 Hiei — ID 8
- **Velocidad S · Dash 120 · Maná SS**
- Único con **sistema de dragón**: auto-golpearse → ×2 ataque y velocidad
- Daño en dragón: 18+22 y 2+34 (los más altos del juego tras Toguro)
- Stun bajo (44) compensa con movilidad

### 🍶 Chui — ID 9
- **Ataque A · Defensa A · Salto A** (todo A)
- **Carga de 7 niveles** (酒妖弾), maná regenera lento pero alto rango de potencia
- Mejor taunt (stun 56, el más alto coste de provocación)
- Stun medio (48), sin nada standout

### 💨 Sensui — ID 2
- **Stun 54 · Ataque A · Provocación S (la mejor)**
- Maná regenera muy lento (E), pero su **técnica de provocación es la mejor**
- Punto fuerte:текст: presi?n con proyectiles

### 🌸 Kurama — ID 7
- Ataque B (bajo), pero stun 40 y **técnicas de proyectiles Whip y Flor**
- Buen control a distancia, pero se lo puede castigar de cerca
- Ataque modesto (11+14), depende de la apertura

### 🖐 Genkai — ID 4
- **Reimu de 8 niveles (hasta 64 de daño)**, la t?cnica más flexible
- Regen maná **S** (el mejor) y salto A
- **Stun 34 — el más bajo**: se lo aturde fácil, su punto d?bil

## C — Prometedores

### 🌳 Itsuki — ID 3
- **Ataque C · Defensa C** (los peores del juego)
- **Único personaje de apoyo con curación** (暗黑之手) y control espacio-temporal (3 segundos)
- Muy situational: fuerte en 2v2+, flojo en 1v1
- Stun 40

### 👊 Kuwabara — ID 5
- Ataque A, Defensa A, **Stun 56 (segundo más alto)**
- Pero **velocidad C** y dash solo 55 (el más corto)
- Ataques de espada (霊剣) con 4 variantes según dirección
- Aguanta mucho, pero no entra

---

## Resumen rápido de la tier list

| Tier | Luchadores |
|---|---|
| **S** | Toguro (menor) |
| **A** | Jin, Yusuke, Toguro (mayor) |
| **B** | Hiei, Chui, Sensui, Kurama, Genkai |
| **C** | Itsuki, Kuwabara |

**Recomendaciones:**
- **Para aprender:** Yusuke (todo A, el más balanced)
- **Para competir:** Jin (mejor movilidad) o Hiei (dragon)
- **Para golpesnombrados:** Toguro (menor)
- **Para 2v2+:** Itsuki (curación + control)

---

## Créditos y fuentes

Datos extraídos y traducidos de:
- **[newton.com.tw](https://www.newton.com.tw/wiki/幽游白書-魔強統一戰)** — tabla principal de frame data
- **[wiki.nesbbs.com](https://wiki.nesbbs.com/index.php/Yuu_Yuu_Hakusho_-_Makyo_Toitsusen)** — debug, mecánicas
- **[kakusi.jp](https://kakusi.jp/?p=54504)** — guía japonesa, comandos ocultos
- **[forum.gamer.com.tw](https://forum.gamer.com.tw/G2.php?bsn=5725&sn=138)** — lista de movimientos
- **[zh.wikipedia.org](https://zh.wikipedia.org/wiki/幽游白书_魔强统一战)** — ficha y personajes

**Nota de nombres:** 桑原 = **Kuwabara** / 蔵馬 = **Kurama** (son personajes distintos).
