# Yu Yu Hakusho: Makyou Toitsusen (MD)
## Comandos en notación de flechas + frame data y mecánicas

> Basado en el análisis exhaustivo de forum.gamer.com.tw (徹底解析, 2006),
> newton.com.tw, wiki.nesbbs.com y kakusi.jp. Datos verificados contra el ROM.

---

## 📖 Cómo leer la notación de flechas

### Botones (pad de 3 botones — el juego solo usa A, B, C)
| Botón | Función |
|---|---|
| **A** | Ataque fuerte |
| **B** | Ataque débil / combo |
| **C** | Defensa /provocación / cancelar carga |

### Teclado numpad (orientado **hacia la derecha** del rival)
```
   7  8  9          ↖  ↑  ↗
   4  5  6   ←  ↑  ↓  →  (la cruceta se marca así)
   1  2  3          ↙  ↓  ↘
```
- **↑↓←→** = pulsar en esa dirección (como el motion arcade: ┘┐└┌)
- **↓↘→** = motions en diagonal, **una sola pasada de 2 frames** (motion corto)
- **→↓→** = motion en espiral, **una sola pasada de 3 frames** (motion largo)
- **↓↓** = doblar abajo rápido (hace crouch al 2.º ↓)
- **↑↑** = doble salto
- **→→** / **←←** = dash / backdash
- **+A** = pulsando A al terminar el motion

### Abreviaturas
- **A/B/C** = uno de esos botones · **AB** = A y B juntos
- **aire** = en el aire · **↓+** = nombre del golpe, no dirección

---

## 🎮 Comandos completos por personaje (con flechas)

### ID 1 — SENSUI (仙水忍)

| Técnica | Comando (numpad) | Notas |
|---|---|---|
| Puño de patada (alto) | `A + B` | Ambos a la vez |
| Puño de patada (bajo) | `↓ + A + B` | Versión baja |
| Bola roja (alta) | `↓↘→ + C` | |
| Bola roja (media) | `↓↘→ + B` | |
| Bola roja (baja) | `↓↘→ + A` | Más rápida |
| Rifle de aire | `↓ ↓ + A o B` | Mantener A/B encadenado sube la cadencia |
| **SUPER** | `↓ ↓ → + A o B o C` | Dirección con ↑/↓. **Cuesta solo 50 maná** |
| Provocación | `A+B+C` | Baja el maná del rival (stun S) |

**Combo clásico de Sensui** (según la guía):
`1. Agarre → saltar (↗) + B×3 → 2.º ataque aéreo → BBB → ↑A`

### ID 2 — JIN (陣)

| Técnica | Comando | Notas |
|---|---|---|
| Flotar arriba | `↑ ↑` (aire) | Flota hacia arriba |
| Flotar adelante | `→ →` o `Z` (aire) | Distancia de vuelo 128 |
| Flotar atrás | `← ←` (aire) | Distancia 80, con invencibilidad total |
| Puño del torbellino | `↓ ↘ → + B` | Avance 84, alcance detrás también |
| **Doble** torbellino | `↓ ↘ → + A` | Avance 136, más lento el inicio |
| Barrera del vendaval | `↓ ↑ + A o B` | Invulnerable, atraviesa rival |
| **SUPER** | `↓ ↓ + A + B` | Acumula hasta 257 de stun |

> **Jin es el único que puede quedarse flotando** en el aire mientras tenga maná
> (los demás solo dan 2 saltos). Su Barrera del Vendaval es imparable en corto.

### ID 3 — ITSUKI (樹)

| Técnica | Comando | Notas |
|---|---|---|
| Patada oscura | `↓ ↘ → + A o B` | Corto rango invencible |
| Mano oscura (ataque) | `↓ ↓ + A o B o C` → después **A** | 3 poses según dirección |
| **Mano oscura (cura)** | `↓ ↓ + A o B o C` → después **B** | **+16 HP**, 2 veces/segundo |
| Patada oscura aérea | `↓ ↓ + A o B` (aire) | |
| Viaje subespacial | `↓ ↑ + A o B o C` | A=izq, B=centro, C=der |
| **SUPER** | `↓ + A + B` | Congela rivales 3 segundos |

### ID 4 — GENKAI (幻海)

| Técnica | Comando | Notas |
|---|---|---|
| **Reimu** | `↓ ↘ → + A o B` (mantener = cargar) | 8 niveles. Cancelar con ← o C |
| Disparo de luz | `↓ ↓ + A o B` | Alcance 64 |
| Puño ascendente | `↓ ↑ + A o B` | Avance 96 (fuerte) / 60 (débil) |
| Puño ascendente aéreo | `↓ ↑ + A o B` (aire) | Igual que el de tierra |
| Cadena (×N) | `A o B` encadenados | |
| **SUPER** | `→ ↓ → + A` | 81+15 daño. En el 10.º hit sigue con puño ascendente |

### ID 5 — KUWABARA (桑原一雄)

| Técnica | Comando | Notas |
|---|---|---|
| Espada espiritual (vertical) | `A + B` | |
| Espada espiritual (horizontal) | `→ + A + B` | |
| Espada espiritual aérea | `A + B` (aire) | |
| Espada espiritual (agachado) | `↓ + A + B` | |
| Estocada espiritual | `↓ ↘ → + A o B` | Avance 138 (fuerte) / 66 (débil) |
| Shuriken espiritual | `↓ ↓ + A o B` | Proyectil 128/64 |
| Hoja dimensional | `↓ ↑ + A o B o C` | Proyectil fijo (pos. 120/56/−8) |
| **SUPER** | `↓ ↓ → + A` | 11 hits (10 vs Genkai, 12 vs Toguro menor) |

### ID 6 — YUSUKE (浦飯幽助)

| Técnica | Comando | Notas |
|---|---|---|
| **Reimu** | `↓ ↘ → + A o B` (mantener = cargar) | 8 niveles. Cancelar con ← o C |
| **Reimu aéreo** | `↓ ↘ → + A o B` (aire) | **Solo Yusuke tiene Reimu aéreo** |
| Reimu (guardado) | `↓ ↘ → + C` | Auto-carga, dispara con A/B |
| Escopetazo | `↓ ↓ + A o B o C` | Cada pulsación extra añade 1 hit |
| Cadena (×N) | `A o B` encadenados | |
| **SUPER** | `→ ↓ → + A` | En el 7.º hit podés **añadir otra Reimu** |

### ID 7 — KURAMA (蔵馬)

| Técnica | Comando | Notas |
|---|---|---|
| Látigo de rosas | `A + B` | Stun alto (6+8) |
| Flor de rosas | `↓ ↘ → + A o B` | Proyectil infinito alcance |
| Planta del demonio | `↓ ↓ + A o B o C` | 3 distancias fijas (120/56/−8) |
| Ronda de flores | `↓ ↑ + A o B` | Proyectiles cercanos múltiples |
| **SUPER** | `↓ → ↓ + A` | 8 hits, 128 daño bruto |

> ⚠️ Kurama es el **único personaje sin técnicas aéreas**.

### ID 8 — HIEI (飛影)

| Técnica | Comando | Notas |
|---|---|---|
| Afterimage | `→ → → →` | Invencible, atraviesa rival |
| Espada de fuego | `A + B` | Invencible, alcanza **detrás** |
| Quemazón | `↓ ↘ → + A o B` | Avance 161/81 |
| Corte del ave | `↓ ↓ + A o B` → luego **A o B** (antes de caer) | Dirección con ←/→ |
| **SUPER** | `↓ → ↓ ↓ + A o B` | 88 daño. Cancelar dirección con C |

> **El Dragón Negro puede golpearte a ti mismo** (tras el corte) y convertir a
> Hiei en modo dragón: daño y velocidad **×2**, maná lleno, **sin super**, y el
> maná se drena solo (si llega a 0 → stun 255).

### ID 9 — CHUI (酎)

| Técnica | Comando | Notas |
|---|---|---|
| Paso borracho | `A + B` | Invencible, cambia de orientación |
| **Bola de licor** | `↓ ↘ → + A o B` (mantener = cargar) | 7 niveles. Cancelar con ← o C |
| Bola de licor (guardada) | `↓ ↘ → + C` | Auto-carga |
| Embestida de licor | `↓ ↓ + A o B` | Avance 161/107 |
| Patada aérea de licor | `↓ ↓ + A o B` (aire) | |
| **SUPER** | `↓ → ↗ + A` | Sequences 6 hits, se puede perseguir |

> Chui es el único que puede **esquivar detrás** del rival (绕背).

### ID 10 — TOGURO hermano mayor (戶愚呂兄)

| Técnica | Comando | Notas |
|---|---|---|
| Aguja de todo el cuerpo | `A + B` | No se pueden pulsar 2 dir. a la vez |
| Estocada marcial | `↓ ↘ → + A o B` | Avance 256/128, dirección con ↑/↓ |
| Aguja subterránea | `↓ ↓ + A o B` | |
| **Aguja especial (Dedal)** | `↓ ↓ + C` | **Stun 64, no cancelable, rompe golpes** |
| Impostor (doble) | `↓ ↑ + A o B o C` | Invencible, cambia orientación |
| **SUPER** | `→ ↓ → ↓ + A` | Golpes de detrás = daño ×2 |

### ID 11 — TOGURO hermano menor (戶愚呂弟)

| Técnica | Comando | Notas |
|---|---|---|
| Armadura de músculo | `A + B` | Invencible al inicio, cancela proyectiles |
| Gancho superior | `↓ ↘ → + B` | **30+30 daño**. Avance 76 |
| Gancho inferior | `↓ ↘ → + A` | **30+30 daño**. Avance 88 |
| Ráfaga de dardos | `↓ ↓ + A o B o C` | Cada pulsación acelera |
| Caída aérea | `↓ ↓ + A o B` (aire) | |
| **SUPER** | `↓ → ↓ + A` | 20×N, invencible al transformarse |

---

## ⚔️ Sistema 相杀 (Cancelación mutua)

Es la mecánica más distintiva del juego: **golpes que se anulan entre sí** con
un aura verde.

- Normales ↔ especiales ↔ supers se cancelan entre sí (según frames)
- **Dash** también cancela golpes de impacto (excepto Jin)
- Tras un 相杀 con normal → **puedes cancelar a cualquier comando** (quedas en posición de guardia)

### Niveles de Reimu que cancela cada golpe parado
| Luchador |立 A cancela hasta |
|---|---|
| **Toguro (menor)** | **5º nivel** |
| **Chui / Sensui** | **4º nivel** |
| **Yusuke / Jin / Toguro (mayor)** | 4º nivel |
| **Hiei / Genkai / Itsuki** | 3º nivel |

---

## 🔋 Recuperación automática de maná por HIT

La mana se recupera sola al encadenar golpes (además de mantener A/B).

| HIT | Por ese hit | Acumulado |
|---|---|---|
| 2 | 2 | 2 |
| 3 | 4 | 6 |
| 4 | 6 | 12 |
| 5 | 8 | 20 |
| 6 | 10 | 30 |
| 7 | 12 | 42 |
| 8 | 14 | 56 |
| 9 | 16 | 72 |
| 10 | 18 | 90 |
| 11 | 20 | 110 |
| 12 | 22 | 132 |
| 13 | 24 | 156 |
| 14 | 26 | 182 |
| 15 | 28 | 210 |
| 16 | 30 | 240 |
| MAX | 32 | 272, 304, 336, 368… |

> **Maná máximo = 223.** A partir del 2.º hit de un combo empieza a subir.
> Se puede llegar al máximo en un solo combo de 16+ hits.

### Especiales **sin** recuperación automática
| Luchador | Técnica |
|---|---|
| Yusuke | Reimu (aérea y normal), la Reimu final del super |
| Kuwabara | Shuriken espiritual, Hoja dimensional |
| Kurama | Flor de rosas, Ronda de flores, Planta del demonio |
| Hiei | Dragón negro |
| Genkai | Reimu, Disparo de luz |
| Chui | Bola de licor |
| Sensui | Bola roja, Súper bola roja |
| Itsuki | Los ataques de Mano oscura |

---

## 📊 Rankings técnicos oficiales

### Velocidad de movimiento
`Jin > Hiei > (Yusuke = Genkai) > Chui > Sensui > Toguro(menor) > (Toguro(mayor) = Itsuki) > Kuwabara > Kurama`

### Distancia de dash
`Jin > Genkai > Hiei > Sensui > Chui > Yusuke > Toguro(menor) > Kurama > Kuwabara > Itsuki > Toguro(mayor)`

### Velocidad de un dash
`(Toguro(mayor) = Itsuki) > (Yusuke = Kuwabara = Genkai) > (Kurama = Chui = Toguro(menor) = Sensui) > (Hiei = Jin)`

### Velocidad de recuperación de maná
`Genkai > (Kuwabara = Hiei = Toguro(mayor)) > Yusuke > (Kurama = Chui = Jin = Toguro(menor) = Itsuki) > Sensui`

### Potencia del super (de mayor a menor)
`Toguro(mayor) > Kuwabara > Yusuke > Kurama > Toguro(menor) > Genkai > Chui > Hiei > Jin > Sensui > Itsuki (=0 daño)`

### Facilidad para aturdir
`(Genkai = Toguro(mayor) > (Kurama = Itsuki) > (Yusuke = Hiei = Jin) > (Chui = Sensui) > Kuwabara > Toguro(menor)`

### Provocación — golpes para vaciar el maná rival de lleno
| Golpes | Luchadores |
|---|---|
| **4** | Chui |
| 5 | Kuwabara, Hiei, Genkai, Toguro(menor), Itsuki |
| 7 | Yusuke, Toguro(mayor), Sensui |
| **8** | Kurama, Jin |

### Niveles de stun (气絕)
- **Pequeña onda** → stun ligero
- **Estrella** → stun medio
- **Murciélago (Hiei pequeño)** → stun severo

---

## 🎯 Tablas de cancelación (normales → especiales)

`○` = cancelable · `×` = no cancelable · `o/×` = depende

| Luchador | A | B | →A | →B | ↓A | ↓B | Aire A | Aire ↑A | ↘A |
|---|---|---|---|---|---|---|---|---|---|
| **Yusuke** | ○ | ○ | o/× | o/o | ○ | ○ | o/× | ○ | — |
| **Kuwabara** | ○ | ○ | o/× | ○ | × | ○ | o/o | ○ | — |
| **Genkai** | o/× | ○ | ○ | ○ | ○ | ○ | ○ | ○ | — |
| **Sensui** | o/×/× | ○ | × | o/o | ○ | ○ | ○ | ○ | ○ |
| **Jin** | ○ | ○ | × | ○ | × | ○ | ○ | ○ | — |
| **Itsuki** | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | × |
| **Kurama** | o/× | ○ | ○ | ○ | ○ | ○ | **—** | **—** | — |
| **Hiei** | ○ | ○ | × | ○ | × | ○ | ○ | ○ | — |
| **Chui** | ○ | ○ | ○ | ○ | ○ | ○ | ○ | × | — |
| **Toguro (mayor)** | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| **Toguro (menor)** | ○ | ○ | × | ○ | × | ○ | ○ | ○ | — |

---

## 🛡️ Técnicas con invencibilidad

| Tipo | Luchador | Técnica |
|---|---|---|
| **Super** | Kurama | Puño de zarza |
| **Super** | Chui | Patada del ventisquero (primera mitad) |
| **Super** | Jin | Súper barrera del vendaval |
| **Super** | Toguro (menor) | 100% dentro del 100% |
| **Super** | Toguro (mayor) | Espada del caos |
| **Especial** | Yusuke | Escopetazo |
| **Especial** | Hiei | Espada de fuego |
| **Especial** | Jin | Barrera del vendaval |
| **Especial** | Toguro (menor) | Armadura de músculo |
| **Especial** | Toguro (mayor) | Aguja de todo el cuerpo |

> Los agares (投技) también son invencibles durante la animación.
> Si una técnica invencible choca con un agarre o con un rival siendo golpeado,
> **la invencibilidad se anula**.

---

## 🌙 Secretos detalles del juego

1. **Hiei con dragón agotado** al ganar: se cae aturdido pero se levanta y hace
   la pose de victoria (con estrellitas arriba).
2. En **modo por parejas**, si el el golpe alcanza al rival en el mismo frame que
   agarras a su compañero, **el que recibe el golpe es el compañero**.
3. **La Bola roja de Sensui también pega con la pierna**, no solo con la踢球 —
   útil para combos raros.
4. Si seleccionás **Jin con C** en el select, a veces aparece un **Super Saiyan**.
5. **Jin** gritando "Barrera del Vendaval" a veces solo suena el efecto (probabilidad baja).

### Secretos de色彩 (paleta de ropa)
- En 4 jugadores, el **4P controlado por CPU siempre lleva la misma paleta de color
  que el 2P**, y nunca es el mismo personaje que el 2P.
- Cada personaje tiene **41 combinaciones de color**: 3 propias × 11 personajes +
  8 colores de equipo en modo parejas = 41.

---

## 🏆 Configuración más difícil (逆境戦 1 vs 3)

- **Dificultad:** Super · **Modo:** 1 contra 3
- **Objetivo:** derrotar a los 3 y sobrevivir
- **Combinaciones读完://más difíciles:**
  - Kuwabara ×3, Yusuke ×3, Jin ×3 (y vos también Jin)
  - **Sensui ×3** (más fácil — alinealos en la misma línea y rompe el frente desde el centro)
- **Restricción:** no usar el ataque fuerte de Toguro (menor) ni los golpes rompientes
- **Reward:** el título **"無敵 (Invencible)"**

---

## Créditos

- **forum.gamer.com.tw** — 徹底解析 (2006) — sistema 相杀, maná por HIT, rankings
- **newton.com.tw** — tabla de daño/stun/maná por golpe
- **wiki.nesbbs.com** — debug, mecánicas de stun
- **kakusi.jp** — comandos de super, debug
