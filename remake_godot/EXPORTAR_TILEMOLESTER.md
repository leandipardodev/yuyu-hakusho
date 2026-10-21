# Especificación de exportación — TileMolester → remake_godot

Este documento define **exactamente** qué archivos exportar con TileMolester para
que el remake los consuma sin tocar código.

## 1. Hojas de animación (spritesheets)

TileMolester exporta en horizontal (frames de izquierda a derecha). Eso es
exactamente lo que espera el motor.

### Convención de nombres
```
sprites/animaciones/<personaje>_<move>.png
```
Donde `<personaje>` es el número 01-11 y `<move>` es un id corto:

| move | Descripción | frames típicas |
|---|---|---|
| `idle` | reposo | 4-6 |
| `walk` | caminar | 6-8 |
| `crouch` | agachado | 1-2 |
| `jump` | salto (subida) | 2-3 |
| `fall` | caída | 1-2 |
| `hitL` | recibe golpe (izq) | 1-2 |
| `hitH` | recibe golpe fuerte | 2-3 |
| `atkA` | ataque A parado | 3-5 |
| `atkB` | ataque B parado | 3-5 |
| `crA` | ataque A agachado | 3-4 |
| `throw` | agarre (→+A) | 3-5 |
| `special` | especial (↓↘→) | 4-8 |
| `super` | super (↓↘→+botón, HP<111, maná llena) | 6-12 |

### Formato
- PNG, **sin transparencia** (el fondo del juego es un color fijo) o con alfa
- Todos los frames del mismo sprite deben tener **la misma altura**
- El motor recorta la altura automáticamente y centra en X

## 2. Ejemplo de archivo
```
sprites/animaciones/06_yusuke_idle.png      (frames de idle de Yusuke)
sprites/animaciones/06_yusuke_atkA.png      (ataque A parado)
sprites/animaciones/06_yusuke_special.png   (Reimu)
...
```

## 3. Qué hace el motor automáticamente

`Fighter.gd` carga la animación si encuentra el archivo:
- corta la hoja en frames iguales (ancho / n_frames)
- reproduce a la velocidad de frame data real (60 fps base)
- reproduce **una vez** los attacks, **en loop** idle/walk

El motor ya tiene los timings en `data/game_data.json` → `frame_data_medidos`.
Si TileMolester exporta a distinta resolución, se escala solo.

## 4. Paletas (CRAM)

Exportar `CRAM` (128 bytes = 64 colores × 2 bytes) desde el editor de VDP.
Formato: 9 bits por color, big-endian por palabra:
```
bit 15-14: 0
bit 8-6:  Azul
bit 5-3:  Verde
bit 2-0:  Rojo
```
Guardar como `sprites/palettes/cram_charnormal.bin` y `cram_fight.bin`.

## 5. Orden de trabajo sugerido

1. Abrir el ROM en TileMolester (View → VDP, VRAM)
2. En el debugger/VRAM, capturar la paleta (CRAM) → paso 4
3. Para cada personaje: capturar sus tiles en animación
4. Exportar horizontal → paso 1

Los sprites **estáticos** de los 11 personajes ya están en `sprites/personajes/`
(los usé de respaldo), pero con las hojas de animación el remake queda completo.
