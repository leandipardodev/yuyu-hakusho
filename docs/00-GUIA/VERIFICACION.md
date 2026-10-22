# Como se marca lo que no esta confirmado

*El sistema de certeza del proyecto: **[ROM]**, **[MEDIDO]**, **[NOTAS]** y *** (duda).*

---

> **Nota:** este proyecto se reorganizó por áreas.
> Este fichero es la versión dividida de `DATOS_VERIFICADOS.md` (que ya no
> existe): sus secciones están en las áreas `01-` a `05-`.

### Como empieza el DATOS_VERIFICADOS original

# DATOS VERIFICADOS

Este fichero es la referencia fiable del proyecto. Contiene **unicamente** lo
que se ha comprobado leyendo el codigo del ROM o ejecutando el juego en
BizHawk. Todo lo demas (guias web, suposiciones) vive en
`FICHAS.md` y en `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)*, marcados como `WEB`/`ESTIMADO`
en su bloque `_confianza`.

Regla: si algo no esta aqui, no esta verificado.

---

---
## COMO SE MARCA LO QUE NO ESTA CONFIRMADO

**`***`** en un `.md` = **afirmacion sin verificar**. Se escribe igual, completa y
con su procedencia, pero marcada. La razon: un dato pendiente es informacion y
borrarlo tira trabajo. Lo que **no** se hace es escribir un dato sin marcar y sin
respaldo, que es lo que nos costo el 255 del HP.

| | |
|---|---|
| Sin marca | **[ROM]** o **[MEDIDO]**: hay direccion, o se ejecuto y se vio |
| Con `***` | Viene de material externo, o esta pendiente de cruzar. **La direccion que se escribe es la del material, no nuestra** |

**Al consolidar material que se contradice, se anotan LAS DOS versiones**, no la
que nos guste. Ver el stun por golpe en `VERIFICACION.md` §2b: estan los
dos conjuntos (nuestro 38-62 y el del PDF 2-16) y el criterio que hace pesar al
segundo.

Todo el consolidado del material del 07-10 (la guia de 1127 lineas y el PDF de la
movelist) esta en `VERIFICACION.md` §3e.

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
  = duracion y bit 6 = frame activo. Ver `MOVES-Y-TIMING.md` §1
- Hitstun: `$7E` es un presupuesto, `ceil($80/$66)` golpes hasta knockdown
- **Hit-time: `$26` NO lo es.** Verificado por las direcciones y por el hecho de
  que se decrementa — ver §5c
- **El mana por combo ya no viene de web.** Es `$C6 * 2` con `$C6` en el
  defensor, verificado en `loc_01F9C8` — ver §2a

Ver tambien `COLISIONES-Y-HITBOXES.md` §8 para los errores concretos del
material externo de Discord / BizHawk.

