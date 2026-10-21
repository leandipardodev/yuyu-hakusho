# Remake — Yu Yu Hakusho: Makyou Toitsusen (Mega Drive)

Remake en **Godot 4.3** usando datos **verificados** extraídos del ROM original.

## Ejecutar

```powershell
C:\Godot\Godot.exe --path ".\remake_godot"
```

## Controles

| Tecla | Acción |
|---|---|
| **A / D** (o flechas) | Mover izquierda/derecha |
| **W / S** (o ↑/↓) | Saltar / agacharse |
| **J** | Ataque fuerte (A) |
| **K** | Ataque ligero (B) |
| **L** | Defender (C) |
| **ENTER / ESPACIO** (mantener) | Ventana HALL OF FAME con confeti |

## Autotests

```powershell
# parser de motions
godot --headless --script MotionTest.gd
# ventana HALL OF FAME: datos, hold de START y reciclado del confeti
godot --headless --script HallOfFameTest.gd
# volcar la ventana a PNG para revisarla a ojo
godot --script RenderHallOfFame.gd
```

Comandos especiales (motions arcade, ventana de 4 frames):
- `↓↘→ + A` = Reimu (proyectil)
- `↓↘→ + J` + maná llena y HP<111 = Super

## Estructura

```
remake_godot/
├── project.godot       # config + input map
├── data/
│   └── game_data.json  # ★ TODOS los datos del juego (editable = los mods)
├── Fighter.gd          # motor de combate (usa los datos reales)
├── AI.gd               # IA de la CPU (4 dificultades)
├── Main.gd / Main.tscn # escena del combate
└── sprites/            # gráficos extraídos del original
```

## Datos implementados (verificados contra el ROM)

| Sistema | Valor | Fuente |
|---|---|---|
| HP máximo | **255** (`$ff`) | `move.w #$ff,$78(a5)` en `0x12AE6` |
| Umbral HP débil | **111** (`$6f`) | `cmpi.w #$6f,$78(a5)`, 14 sitios |
| **Offset del HP** | **`$78(a5)`** (word signed) | `sub.w d0,$78(a4)` en `0x1F3E0` |
| Maná / TA máximo | **223** (`$df`) | `move.l #$df0000,$b8(a5)` en `0x1A2E2` |
| **Offset del stun** | **`$7E`** actual / **`$80`** máximo | `move.w $80(a5),$7e(a5)` en `0x15A4A` |
| `stun_max` por personaje | 40, 56, 48, 44, 54, 46, 40, 38, 48, 62 | rutinas `0x12792`-`0x12A74` |
| **Daño por golpe** | fórmula verificada: byte `$65` ÷ 4 + 1 | `0x1F3E0` |
| Recovery | 4f (rápido) / 88–92f (proyectil) | medido |

> **Dos trampas que confunden mucho, y que este README tenía mal:**
> el **223 es el tope del maná** (`+$B8`), no el HP — el HP llega a **255**;
> y `$14..$17` es el **empujón**, no el stun — el stun es el word de `$7E`.
> La tabla de 408 impactos se leyó de `$B8`, o sea del maná, así que **no es
> de daño**: hay que repetirla leyendo `$78`.
> Ver `DATOS_VERIFICADOS.md` §2, §2b y §5.

## Mods (objetivo 1)

**Todo se edita en `data/game_data.json`** — sin recompilar:
- `hp_max`, `hp_debil`, `maná_max` globales
- `stun_max`, velocidad, stats de cada personaje
- `normales` y `especiales` (daño por move)
- `sistema_maná.recup_por_hit` (cuánta maná da cada hit)
- Hiei dragon: `dragon.dmg_mult`, `maná_drenaje` (pon `false` = sin coste)

## IA (objetivo 2)

`AI.gd` con 4 dificultades (Easy/Normal/Hard/Super), cada una:
```json
{"react": frames_reaccion, "aggro": agresividad, "spec": ratio_especial, "block": ratio_bloqueo}
```
- **SUPER**: reacción 4 frames, 85% agresividad, 70% block, 50% especiales
- Más reaction frames = peor. Bajá `react` para una IA brutal.

## Sprites y animaciones

### Sprites estáticos (ya incluidos)
`sprites/personajes/` — los 11 personajes en PNG pixel-perfect (extraídos del char select del original). Se usan automáticamente como respaldo.

### Animaciones (exportar con TileMolester)
El motor reproduce hojas de animación horizontales automáticamente. Ver **`EXPORTAR_TILEMOLESTER.md`** para la convención exacta.

Basta con soltar los archivos así:
```
sprites/animaciones/06_yusuke_idle.png     (frames de idle)
sprites/animaciones/06_yusuke_atkA.png     (ataque A)
sprites/animaciones/06_yusuke_special.png  (especial)
...
```
Sin tocar código: el motor detecta las hojas, las recorta en frames y las reproduce a la velocidad de frame data real.

## Pendiente

- **Sprites de TileMolester**: pegar las hojas de animación en `sprites/animaciones/`
- **Hitstun/blockstun**: no medidos (tablas de moves del ROM)
- **Frame data de startup exacto**: requiere debugger MAME (breakpoint en la rutina de aplicación de daño `0x19C46`)
- **Nombres de personajes en pantalla**: falta la fuente bitmap del juego
