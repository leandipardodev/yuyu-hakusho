# Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994)

Ingeniería inversa del ROM de *Yu Yu Hakusho: Makyou Toitsusen* (Treasure, 1994)
y remake en Godot 4 con **datos medidos del ROM original**, no suposiciones.

Hay **dos caminos** en este proyecto, y son independientes:

| Camino | Qué es | Dónde |
|---|---|---|
| **A. Parchear la ROM** | Cambiar el juego original byte a byte, con verificación | `rom/`, `_disasm_tools/patch_rom.py` |
| **B. Remake en Godot** | Recrear el juego con los datos extraídos, para poder cambiar reglas e IA libremente | `remake_godot/` |

---

## 1. Por dónde empezar

**Si vienes de fuera y no conoces el proyecto:**

1. `AGENTS.md` — **la memoria del proyecto**. ~1400 líneas con las direcciones
   confirmadas y una tabla de **~140 trampas**: errores ya detectados, con su
   causa-raíz (qué es cada campo de memoria y por qué se confundió).
2. `docs/datos/DATOS_VERIFICADOS.md` — **la única fuente de verdad**. Todo lo
   que no esté aquí no está verificado.
3. `docs/datos/PARCHES.md` — los parches de ROM, con el porqué de cada byte.

**Si quieres tocar la ROM:** `docs/datos/PARCHES.md` → `datos/manifesto.json` →
`_disasm_tools/patch_rom.py`.

**Si quieres tocar el remake:** `remake_godot/README.md`.

---

## 2. Estructura

```
yuyu-limpio/
├── README.md               <- este fichero (índice)
├── AGENTS.md               <- la memoria del proyecto. LEER ANTES DE TOCAR NADA
├── game_68000.asm          <- desensamblado del 68000 (28.168 instrucciones)
├── game_z80_driver.asm     <- desensamblado del driver de sonido
│
├── docs/                   <- toda la documentación
│   ├── datos/              DATOS_VERIFICADOS · PARCHES · COLISIONES_Y_HITBOXES
│   │                       FISICAS_Y_MOVIMIENTO · TABLAS_MOVES_Y_TIMING
│   │                       VARIACION_DANOS_HITPAUSE_KNOCKDOWN
│   ├── personajes/         FICHAS · STURDIMIENTO · FRAME_DATA · DAMAGE_TABLE
│   │                       COMANDOS_Y_FRAME_DATA · COMANDOS_MOVES_FUENTE
│   └── investigacion/      INFORME_RE · INVESTIGACION_* · ERRORES · PLAN
│
├── rom/                    <- las ROMs
│   ├── yuyu_makyou_base.bin                    la base limpia (SHA1 BE4461EB…)
│   ├── yuyu_makyou_v16_UNIFICADO.bin          ★ LOS 4 CAMBIOS JUNTOS
│   ├── yuyu_makyou_v17_UNIFICADO_KAGEPROJ.bin  v16 + un refactor experimental
│   └── fuentes/             las ROMs de trabajo del autor y las de referencia
│
├── _disasm_tools/          <- herramientas Python (el "laboratorio")
│   ├── rompath.py           resuelve la ruta de la ROM (no hay rutas quemadas)
│   ├── patch_rom.py         el parcheador verificado
│   ├── lista_moves.py       vuelca las tablas de moves de los 11 personajes
│   ├── auditar_moves.py     audita ese volcado contra el ROM (1950/1950)
│   ├── blob_chain.py        vuelca la cadena de cajas de un move
│   ├── ctx_hits.py          qué moves tienen hitbox
│   ├── m68k_gensim.py       emulador 68000 propio (Unicorn + puente Z80 + VDP)
│   └── ...
│
├── tools/
│   ├── fbn/                scripts Lua para FBNeo / Fightcade (diagnóstico)
│   │   └── tests/          los bancos de prueba (207 pruebas del HUD)
│   └── gen_stun.py         genera STURDIMIENTO.md desde las fuentes
│
├── remake_godot/           <- el remake (Godot 4.3, viewport 320×224)
│   ├── data/game_data.json  ★ TODOS los datos del juego (editar aquí = los mods)
│   ├── data/comandos.json   los comandos de entrada de los 11 personajes
│   └── Fighter.gd AI.gd Fisica.gd MotionInput.gd …
│
├── datos/
│   ├── manifesto.json      ★ el catálogo de parches (dirección → valor)
│   └── rom_map.txt         mapa del ROM: qué es código, qué son datos
│
├── assets/
│   ├── re/                 lo que se ha extraído del ROM (sprites, retratos…)
│   └── extra/              recortes para el remake
│
└── notas/                  <- el repo de notas del proyecto (GitHub)
    └── .git                126 commits: el diario de la investigación
```

---

## 3. La ROM unificada

Los cambios se hicieron en ROMs distintas, repartidas en tres carpetas. La
**v16** los tiene todos:

| Cambio | Qué hace | Bytes |
|---|---|---|
| **Habilidad de Hiei** | el dragón 炎殺黒龍波 va a media velocidad y su hitbox se estrecha de 68 a 9 px | `$0C8168` `$012585` `$012586` `$0C99AE` `$0C99B6` |
| **Manos de Itsuki** | 影手 sale instantáneo (las duraciones medidas, IDs 166/167), se desplaza ¼ y su onda va a media velocidad | `$0D053A` `$0D0542` `$0D054A` `$0D0552` `$018809` `$01FD0D` `$01FD59` |
| **Fix del doble salto** | la rutina de reset limpia `$87(a5)`, el **contador de saltos** | `$015D03` `$015D17` + 16 bytes en `$018443` |
| **Planta de Kurama** | su 2º golpe pasa del derribo normal al **derribo ciego** | `$0D9C69` |

Reconstruirla:

```powershell
python _disasm_tools\patch_rom.py `
    "rom\yuyu_makyou_base.bin" `
    "rom\yuyu_makyou_v16_UNIFICADO.bin" `
    dragon dragon_vel blob kage_dur kage_vel onda_vel doble_salto kurama_planta
```

> **El checksum de la cabecera se reescribe SIEMPRE al final.** El juego lo
> verifica al arrancar (`0x4318`): si no cuadra, escribe `0x0E` en `$E080` y se
> queda clavado en el logo SEGA. Cada byte del manifiesto declara su valor
> esperado; si el ROM de entrada no lo tiene, el parcheador **aborta sin
> escribir nada**.

Grupos disponibles: `python _disasm_tools\patch_rom.py --list`

---

## 4. Requisitos

| Para | Necesitas |
|---|---|
| Herramientas Python | Python 3.14 · `pip install unicorn==2.1.4 capstone z80==1.2.0` |
| Remake | Godot 4.3 |
| Diagnóstico en el juego | FBNeo / Fightcade (los `.lua` de `tools/fbn/`) |
| La ROM | **no se distribuye**: es material con derechos de autor |

**Dónde está la ROM:** `.rom_path` (una línea con la ruta) o la variable de
entorno `YUYU_ROM`. Ver `_disasm_tools/rompath.py`.

---

## 5. Reglas del proyecto

Están en `AGENTS.md`, pero las que más importan:

1. **`DATOS_VERIFICADOS.md` es la única fuente de verdad.** Lo que no esté ahí,
   no está verificado.
2. **Cada afirmación lleva su dirección.** Sin `sub.w d0,$78(a4)` en `0x1F3E0`
   al lado, no es un dato: es una opinión.
3. **Lo no verificado se marca con `***`.** Se escribe igual, con su
   procedencia. Lo que no se hace es escribirlo sin marcar.
4. **Nunca escribir rutas absolutas ni nombres de usuario en el código.**
5. **Actualizar los apuntes en el mismo cambio.**

---

## 6. Estado

| Pieza | Estado |
|---|---|
| Desensamblado 68000 | 28.168 instrucciones |
| Tabla de moves | 195 índices / **191 moves** · auditoría 1950/1950 byte a byte ✓ |
| Emulador 68000 propio | **80 %**: arranca, resuelve el Z80, 200 frames. La VRAM queda vacía y no llega a combate |
| Gráficos | **bloqueados**: el ROM tiene los gráficos comprimidos y los sprites de personaje nunca están en plano |
| Remake Godot | arranca; ~10 bugs funcionales conocidos (ver `remake_godot/`) |
| Parches de ROM | 14 grupos en el manifiesto, todos verificados byte a byte |

**Lo que NO se sabe todavía:** el frame data exacto (startup/active/recovery) de
cada golpe, el blockstun, y el emparejamiento ID de move ↔ nombre.

---

## 7. Créditos

- **Juego original:** Yu Yu Hakusho — Makyou Toitsusen, ©1994 Sega / Treasure.
  Romero *Axion*, rearmado por Treasure con la licencia de YuYu.
  - Director y diseño: **Tetsuhiko Kikuchi**
  - Programación: **Masaki Ukyo**, **Mitsuru Yaida**
  - Arte: **Hiroshi Iuchi**, **Makoto Ogino**
  - Sonido: **Satoshi Murata**
- Todo el análisis, las herramientas y el remake de este repositorio son
  trabajo original.
- El repo de notas está en <https://github.com/Akara1996/yuyu-rom-notas>.
