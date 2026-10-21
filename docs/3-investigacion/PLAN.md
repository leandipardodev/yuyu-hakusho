# PLAN DE TRABAJO
## Yu Yu Hakusho: Makyou Toitsusen (Mega Drive) — RE + Remake

**Fecha:** 2026-09-30
**Estado:** Fase 1 (investigación) — nada ejecutado aún, esperando confirmación de arranque

---

## 1. Objetivos

1. **Versión modificada con otros parámetros**, control total:
   - Cambiar daños, hitstun, blockstun, aturdimientos, gasto/recuperación de maná
   - Agregar modos de juego
   - Habilidades custom (ej: que el dragón de Hiei no consuma maná del portador)

2. **IA que supere a un humano**, con dificultades mejoradas

**Restricción:** nunca tocar los `.bin` originales. Todo en copias / subcarpeta `_datos/`.

---

## 2. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Ruta | **Investigación primero**, luego decidir entre parcheo ROM vs remake |
| Motor (si remake) | **Godot 4** |
| Fidelidad | **Lo más fiel posible** (obliga a extraer sprites reales) |
| Herramientas disponibles | Python 3.14, VS Code, .NET 10 SDK, Node, Git, BizHawk 2.11 |

---

## 3. Mapa de direcciones YA VERIFICADAS

Base de datos inicial — se amplía en Fase 1. Todo confirmado leyendo el ROM y/o BizHawk.

### Vida (global, los 11 personajes)
| Dirección | Valor | Qué hace | Estado |
|---|---|---|---|
| `0x8054` | `move.w #$df, $8cb8.w` | HP máximo = **223** | ✅ estático |
| `0x804E` | `move.w #$6f, $8c78.w` | Umbral HP débil = **111** | ✅ estático |
| `0x15C36` | `cmpi.w #$df, $b8(a5)` | Chequeo de HP lleno | ✅ estático |
| `0xFF84B8` | word | HP P1 en runtime (struct 0xFF8000 + 0x4B8) | ✅ medido |
| `0xFF90B8` | word | HP P4 en runtime (struct 0xFF8C00 + 0x4B8) | ✅ medido |

### Stun / aturdimiento (por personaje)
| Dirección | Contenido | Estado |
|---|---|---|
| `0x12792`–`0x12A74` | 11 rutinas de init, una por personaje | ✅ estático |
| `move.w #$SS, $7e(a5)` | Stun actual | ✅ |
| `move.w #$SS, $80(a5)` | **Stun máximo — offset editable** | ✅ |
| `0xFF8478` | Stun actual en runtime | ✅ medido |
| `0xFF847A` | Stun máximo en runtime (34 = Genkai) | ✅ medido |

Mapa de rutinas → personaje (verificado contra fuente web):
| Rutina | Stun | Personaje |
|---|---|---|
| `0x127DC` | 56 | Kuwabara |
| `0x12870` | 44 | Hiei |
| `0x128BA` | 54 | Sensui |
| `0x12904` | 46 | Jin |
| `0x12998` | 38 | Toguro (hermano mayor) |
| `0x12A2C` | 62 | Toguro (hermano menor) |
| `0x12792`/`0x1294E` | 40 | Kurama / Itsuki |
| `0x12826`/`0x129E2` | 48 | Yusuke / Chui |

### Structs de jugador (work RAM 68k)
| Dirección | Contenido | Estado |
|---|---|---|
| `0xFF8000` + n*`0x400` | 4 slots: P1, P2, P3, P4 | ✅ medido |
| `+0x4B8` | HP | ✅ |
| `+0x478` | Stun actual | ✅ |
| `+0x47A` | Stun máximo | ✅ |
| `+0x26C` | Posición X | ✅ |
| `+0x188` | Contador de frames (incrementa 1/frame) | ✅ |

### Selección de personaje
| Dirección | Qué hace | Estado |
|---|---|---|
| `0x8302` | `cmpi.w #$b, $10(a5)` — tope de personajes (11) | ✅ |
| `0x8318` | `move.w #$b, $10(a5)` — wrap a 11 | ✅ |
| `0x834E`/`0x8364` | Igual para P2 | ✅ |
| `0x848C` | `cmpi.w #$b, d1` + `bhi` — valida ID del joystick | ✅ |
| Tabla `0x109CA` | 11 entradas, datos de retrato (NO es lista de personajes) | ⚠️ |

### Flags y modos ocultos
| Dirección | Qué hace | Estado |
|---|---|---|
| `0x3ADE` | `bset.b #$7, $f550.w` — activa modo 1v3 | ✅ |
| `0x39B0` | `tst.b $f550.w` — testea modo desbloqueado | ✅ |
| `0x39B6` | `tst.b $f55a.w` — modo completado | ✅ |
| `0xFEBC` | `move.b #$1, $f55a.w` — setea completado | ✅ |
| `0x3A2E` | Bucle principal de pantallas | ✅ |
| `0x2300` | Timer: `$f502` / `$f504` / `$f506` | ✅ |

### Motor de combate y zonas de código
| Región | Contenido | Instr |
|---|---|---|
| `0x00000`–`0x30000` | Boot, UI, select modo/personaje, sistemas | ~4.000 |
| `0x90000`–`0xB0000` | Sistemas | ~2.500 |
| `0x180000`–`0x210000` | **Motor de combate** (IA, hitstun) | ~8.000 |

### Toolchain instalada
| Componente | Ruta |
|---|---|
| BizHawk 2.11 | `C:\BizHawk\EmuHawk.exe` |
| ROM en BizHawk | `C:\BizHawk\Rom\89A70D374A3F3E2DC5B430E6D444BEA243193B74.md` |
| Runners Lua | `%LOCALAPPDATA%\Temp\opencode\run_emu.ps1` |
| Scripts Lua | `%LOCALAPPDATA%\Temp\opencode\*.lua` |

### API Lua de BizHawk (2.11) — verificada
```lua
client.openrom(path)                          -- carga ROM, devuelve bool
memory.read_u16_be(addr, "M68K BUS")          -- work RAM 68k
joypad.set({Start=true}, 1)                   -- input (DICT, no bitmask!)
joypad.set({Right=true}, 1)                   -- Genesis: Up/Down/Left/Right/A/B/C/Start
emu.frameadvance()                            -- avanzar 1 frame (DIRECTAMENTE, no envolver en función)
emu.limitframerate(false)                     -- turbo
client.screenshot(path)                       -- captura
client.exit()                                 -- cerrar
```
**Gotchas:**Domains de memoria: `Z80 RAM, MD CART, CRAM, VSRAM, VRAM, M68K BUS`.
- `joypad.set` = dict `{boton=true}`, NO bitmask (rompe con número)
- NO envolver `emu.frameadvance()` en una función → cuelga el emulador
- Direcciones de memoria 68k son directas (`0xFF84B8`), sin offset

---

## 4. Datos de referencia del juego (verificados)

| Dato | Valor |
|---|---|
| HP máximo (todos) | 223 |
| Umbral HP débil | 111 |
| Puertos de servidor | 68k (Juego) + Z80 (sonido) |
| Roster | 11 personajes (ver `INFORME_RE.md`) |
| Modo oculto | Dificultad CPU máx + completar modo 1 → 1v3 handicap |
| Modo debug | Título → START ×2 → Opción → (A+C+START) → デバッグ=あり |
| Mecánica especial | `→+A` pegado al rival = **AGARRE** (投技), no golpe |
| Recovery medido | 4 f (cadena rápida) · 8–14 f (normal) · 46–63 f (fuerte) · 88–92 f (proyectil) |

---

## 5. Fases de trabajo

### FASE 1 — Investigación (base de datos) ← EMPEZAMOS AQUÍ
Sirve para **ambas** rutas (parcheo ROM o remake).

1. **Terminar S/A/R** de los 11 personajes
   - Bug conocido: mantener botón 2 frames no lo registra → usar 4–6 frames (patrón arcade)
   - Empezar por Yusuke, luego el resto
   - Por personaje: golpes normales, agarre, especiales, combos

2. **Volcar VRAM/CRAM** vía BizHawk → confirmar que se pueden extraer sprites sin crackear el códec
   - Esto es lo que desbloquea la fidelidad alta

3. **Localizar tablas de daño / maná / hitstun / blockstun** con `event.onbuswrite`
   - Hook sobre escrituras a `0xFF84B8` (HP) y al registro de maná
   - La dirección de instrucción que escribe = rutina de daño → tabla

4. **Documentar** en `MAPA_DIRECCIONES.md`: parámetro → dirección → qué hace → cómo parchear

**Entregable:** base de datos completa de direcciones.

### FASE 2 — Vertical slice (validar motor)
- Godot 4 (o prototipo Python si Godot no se puede instalar)
- 1 personaje (Yusuke) con datos reales del ROM + sprites extraídos de VRAM
- Combate con frames reales → verificar que el "game feel" sea fiel

### FASE 3 — Escalar a los 11 + 8 escenarios + HUD + story/arcade/torneo

### FASE 4 — Audio (lo más difícil)
- Música/SFX: emular salida YM2612 (blargg genesis core) o reimplementar

### FASE 5 — Objetivos de mod (fácil en remake)
- Todos los parámetros en `.json` editable (daño, hitstun, blockstun, stun, maná, recovery)
- Habilidades custom (dragón de Hiei sin maná, etc.)
- Modos de juego nuevos (agregar como código, no asm)
- IA fuerte en GDScript/Python (no asm 68k)

---

## 6. Pendientes de definir (con el usuario)

- [ ] Godot 4: ¿se puede descargar (~100 MB) o arrancar con prototipo Python primero?
- [ ] Música: ¿prioridad baja (arrancar sin) o hay que sí o sí?
- [ ] Ubicación de dumps/documentos: subcarpeta `_datos/` en la carpeta del juego
- [ ] Patch file de direcciones (dirección→valor) para aplicar/revertir mods

---

## 7. Archivos ya producidos

| Archivo | Contenido |
|---|---|
| `desensamblado_68000.asm` | Desensamblado 68k (28.168 instr) |
| `desensamblado_z80.asm` | Driver Z80 (3072 bytes, 98%) |
| `INFORME_RE.md` | Roster, modos, secretos, verificación |
| `FRAME_DATA_Y_STATS.md` | Stats/stun/maná por personaje (traducido) |
| `FICHAS_DE_PERSONAJES.md` | Ficha completa de los 11 |
| `COMANDOS_Y_FRAME_DATA.md` | Comandos en notación de flechas |
| `FRAME_DATA_MEDIDO.md` | Medición en vivo (BizHawk) |
| `INVESTIGACION_WEB.md` | Fuentes chinas, correcciones |
| `PLAN.md` | Este documento |
