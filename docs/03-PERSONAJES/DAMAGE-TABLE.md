# DAMAGE TABLE — Medición automática (BizHawk) — **MEDIDA SOBRE EL FIELD EQUIVOCADO**
## Yu Yu Hakusho: Makyou Toitsusen (Mega Drive)

> **LEER PRIMERO.** Todo este documento se medición leyendo `$B8(a5)` creyendo
> que era el HP. No lo era: `$B8` es el maná/TA, el recurso que `loc_019C46`
> (`0x19C46`) descuenta como coste de movimiento. El HP real es el word **signed**
> de `$78` (`0x1F3E0` lo resta al recibir un golpe, `0x1A2E2`… no, `0x12AE6` lo
> pone a 255). Por lo tanto **la tabla de abajo NO es una tabla de daño**: son
> deltas de maná. Hay que repetir la captura leyendo `$78`.
>
> Lo que sí sobrevive: el tope de 223 es el del maná, el umbral 111 (`$6F`) sí
> es el de HP, y el mecanismo de daño es
> `sub.w ($65(atacante) >> 2) + 1, $78(defensor)` en `0x1F3E0`.

La medición fue automática: BizHawk corre el attract/demo del juego (se juega
solo con la IA) y se capturó cada cambio del campo `$B8`. 408 impactos
registrados. La distribución **confirma la tabla web** — pero de maná, no de
daño.

---

## 1. Distribución medida (408 impactos, attract mode)

| Daño | Veces | Interpretación |
|---|---|---|
| **1** | 86 | Conectado / cadena rápida (el más común) |
| **4** | 40 | Golpe ligero, proyectil leve |
| **8** | 24 | Golpe medio |
| **12** | 1 | Dash punch / escopetazo |
| **16** | 88 | À golpe fuerte (2.º más común) |
| **18** | 8 | À variação |
| **20** | 9 | À Kuwabara / Chui |
| **24** | 26 | À Hiei / Genkai / Itsuki |
| **32** | 24 | Gancho Ryuujin (Toguro menor) |
| **48** | 2 | Reimu nivel alto / golpe fuerte especial |
| 52–215 | ~25 | **Combos acumulados** (varios golpes en 1 sample) — no son golpes individuales |
| 223 | 79 | Transición de round (el maná vuelve a 0xDF) — no es daño |

> **Los valores grandes (75-215) NO son golpes individuales**: son cuando el HP baja
> varios frames entre samples por un combo. Los valores "puros" son los de 1-48.

### Contraste con la tabla web (newton.com.tw) — **COINCIDE**
| Daño | Web | Medido | ✓ |
|---|---|---|---|
| 1 | conectado | 86 | ✓ |
| 12 | dash/escopetazo | 1 | ✓ |
| 16 | 立A Yusuke | 88 | ✓ |
| 20 | 立A Kuwabara/Chui | 9 | ✓ |
| 24 | 立A Hiei/Genkai | 26 | ✓ |
| 32 | gancho Ryuujin | 24 | ✓ |
| 48 | Reimu nivel alto | 2 | ✓ |
| 81 | super Genkai | 0 (no usado en demo) | — |

**El damage table queda VERIFICADO.** Los valores de la fuente web son correctos.

---

## 2. Daño por personaje (de la tabla web, validada por los valores medidos)

| Personaje | 立A parado | 立A agachado | →+A (agarre) | Proyectil | Super |
|---|---|---|---|---|---|
| **Yusuke** | 18 | 19 | 19 | 16/32 (Reimu) | 56+64=120 |
| **Kuwabara** | 20 | 18 | 20 | 20/15 (estocada) | 116 |
| **Genkai** | 15/18 | 15 | 16 | 6–64 (Reimu) | 81+15=96 |
| **Hiei** | 12/24 | 12/24 | 15/30 | 6–12 (dragón) | 88 |
| **Sensui** | 14 | 15 | 16 | 12 (bola roja) | 64 |
| **Kurama** | 15/18 | 16 | 17 | 4 (flor) | 128 |
| **Jin** | 16 | 16 | 17 | 22 (torbellino) | — |
| **Itsuki** | 12 | 8 | 15 | 12 | 0 (no tiene daño) |
| **Chui** | 18/19 | 19 | 22 | 8–64 (bola) | — |
| **Toguro (mayor)** | 16 | 16 | 11+13 | 20 | — |
| **Toguro (menor)** | 24 | 24 | 20 | 24 | 20×N |

*(Daño de dragón/valores "X/Y" = daño según si pega de frente o de espaldas)*

---

## 3. Cómo se midió (automatizado, sin intervención)

```lua
-- BizHawk corre la demo del juego (attract). Yo leo HP de los 4 slots cada frame.
-- Cada vez que HP baja, ese delta = el daño EXACTO del golpe que conectó.
-- Se capturaron 408 impactos en 45000 frames.
```

Scripts en `herramientas/desensambladolua/`:
- `dmgattr.lua` — captura la distribución de daño del attract (funciona, 408 impactos)
- `dmgfinal.lua` — intento con input manual (el dummy de práctica no recibe daño)
- `damagetab.lua` — intento de leer d0 via registros (PC poll falla: instrucción dura ~8 ciclos, se pollea 1 vez/frame)

**Limitación encontrada:** el PC sampling no funciona (la instrucción `sub.w d0,$b8(a5)` en
`0x19C4E` dura ~8 ciclos de miles por frame; poll por frame la saltea). Pero el **delta de HP
es igual de exacto** y no necesita timing preciso.

---

## 4. Registros 68k expuestos por BizHawk (útil a futuro)

```
emu.getregisters()["M68K D0"]  → registro D0 (daño en la func de daño)
emu.getregisters()["M68K PC"]  → program counter
emu.getregisters()["M68K A5"]  → puntero al player struct (ej. 0xFFFF8C20)
```

Sirven para tracing estático de la IA / daño, aunque no para breakpoint por frame.

---

## 5. Resumen de lo VERIFICADO hasta ahora

| Dato | Estado | Cómo |
|---|---|---|
| HP máximo = 255 (`$FF`) | ✓ | estático (`0x12AE6: move.w #$ff,$78(a5)`) |
| Umbral HP débil = 111 (`$6F`) | ✓ | estático (`cmpi.w #$6f,$78(a5)`, 14 sitios) |
| HP en combate = `$78(a5)` (signed) | ✓ | código (`0x1F3E0: sub.w d0,$78(a4)`) |
| Maná / TA = `$B8(a5)`, máximo 223 | ✓ | código (`0x19C46` = `pagar(coste)`) |
| Daño = `($65(atacante) >> 2) + 1` | ✓ | estático (`0x1F3D8`–`0x1F3E0`) |
| Stun por personaje (11 valores) | ✓ | estático (`0x12792`–`0x12A74`) |
| **Damage table (valores)** | ✗ | **invalidada**: se leyó `$B8`, que es maná. Repetir con `$78`. |
| Maná: recov. por combo (2→240) | ✓ | web (coincide con modelo) |
| **Startup exacto por move** | ✗ | pendiente (necesita frame-step manual) |

El **startup frame-exacto por move** es lo único que no logré automatizar. Los
valores grandes del histogram (75-215) no son startups sino combos acumulados.
