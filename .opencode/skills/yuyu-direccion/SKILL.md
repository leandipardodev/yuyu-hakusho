---
name: Investigar dirección (yuyu)
description: Camino corto para ubicar y verificar una dirección u offset del ROM de Yu Yu Hakusho (qué leer, en qué orden, y cómo cerrar el dato). Cargarlo antes de investigar direcciones, offsets, tablas o estructura del jugador.
---

## Orden de lectura: solo esto, nada más

NO leer de corrido `docs/04-DATOS/DATOS_VERIFICADOS.md` (145 KB) ni `docs/00-GUIA/TRAMPAS.md`
(64 KB): se buscan dentro con grep, no se leen enteros.

1. **`docs/04-DATOS/DIRECCIONES.md`** — la tabla maestra. Buscar la dirección en hex
   (ej. `$78(a5)`, `0x1F3E0`, `$FF8400`) o el concepto (stun, maná, hitbox, plano).
2. **`docs/04-DATOS/MOVES-Y-TIMING.md`** si es de moves/timing (registro de frame 8 bytes,
   bases, blockstun §6, el mapa frame a frame).
3. **`docs/01-MOTOR/ESTRUCTURA-DE-JUGADOR.md`** para offsets del struct del jugador
   (base `$FF8400 + n*$400`; `$59` frame, `$5A` duración, `$5F` id de move, `$78` HP,
   `$7E/$80` stun, `$B8` maná).
4. **`docs/00-GUIA/TRAMPAS.md`** solo si algo dice que "esta dirección es una trampa".

## Código: grep, no lectura

- `datos/desensamblado_68000.asm` es el desensamblado de la **ROM J** — SOLO referencia.
  Leerlo para ENTENDER el mecanismo, con `grep` de la dirección y su contexto (-B 2 -A 6),
  nunca barrido continuo.
- La fuente de verdad para parchear es la **base** (china): la traducción mueve el código,
  o sea las direcciones del .asm pueden estar desplazadas.

## Verificación jerárquica (que pesa más al final)

1. **Estático**: leer los CONSUMIDORES del offset en el .asm (quién lo lee / escribe y para
   qué). Un offset sin consumidor no es un dato.
2. **Dinámico**: sonda Lua en FBNeo midiendo en juego (skill `yuyu-lua`).
3. Conflicto entre los dos → **el MEDIDO pesa más**. Si una medición externa contradice una
   inferencia nuestra, gana la medición (precedente: la base del P2, `$FF8800` vs `$FF9000`).

## Cerrar el hallazgo

- El dato va al fichero del área correspondiente **con su dirección + instrucción**.
- No confirmado → se escribe igual pero con `***` y su procedencia.
- Una línea en `docs/08-DIARIO/SESIONES.md`; si era una trampa nueva, a `TRAMPAS.md`.
- Al terminar: `python herramientas/docs/verificar_docs.py`.

## Trampas que ya costaron sesiones

- Direcciones **+2** respecto del volcado cuando se cita de un XREF.
- `btst`: **el byte ALTO del inmediato es el número de bit** (bits 8-11); el bajo es la
  máscara. Cambiar la MÁSCARA rompe los ataques (bit 0 = A, bit 1 = B). El bit 7 de `$72`
  no lo usa nadie.
- `$F558`/`$F55A` es slow-mo de muerte (160 frames, literal `$A0`), no freeze ni hit-time.
- `$69` = hitpause, solo toma valores 0/16/28/255.
- El cruce de planos: flag `$A042`; estado `$0A` + frame id `$0F` al caer.
- Los atajos de cruce se desactivan tocando el `btst` del botón, **no** el salto destino.
