# Los datos verificados

*Este fichero es el **índice** de lo verificado. Antes era un único fichero
(`DATOS_VERIFICADOS.md`, 169 KB) y ahora está repartido por áreas, con el
mismo contenido: cada sección conserva su texto, sus direcciones y sus
marcas de certeza.*

**La regla sigue siendo la misma:** *cada afirmación lleva su dirección, y
la dirección se comprueba contra la ROM base*. Para comprobarlo:

```bash
python herramientas/docs/verificar_docs.py
```

## Dónde está cada cosa

| Área | Fichero | Qué contiene |
|---|---|---|
| **01-MOTOR** | [`ARQUITECTURA.md`](../01-MOTOR/ARQUITECTURA.md) | el hardware, los bancos de ROM, los secretos y modos |
| | [`ESTRUCTURA-DE-JUGADOR.md`](../01-MOTOR/ESTRUCTURA-DE-JUGADOR.md) | el struct del jugador en RAM ($40-$A0) |
| | [`CAMARA-Y-SCROLL.md`](../01-MOTOR/CAMARA-Y-SCROLL.md) | la cámara y el scroll |
| | [`ENTRADA-Y-PLANOS.md`](../01-MOTOR/ENTRADA-Y-PLANOS.md) | **la entrada y los planos**: el flag `$A042`, el suelo `$9c`, la escala `$3e`, el índice `$26`, los atajos de mando, el "" |
| | [`EMULADOR-68000.md`](../01-MOTOR/EMULADOR-68000.md) / [`EMULADOR-Z80.md`](../01-MOTOR/EMULADOR-Z80.md) | los emuladores propios |
| **02-COMBATE** | [`VIDA-Y-MANA.md`](../02-COMBATE/VIDA-Y-MANA.md) | el sistema de vida y el cálculo del maná |
| | [`STURDIMIENTO.md`](../02-COMBATE/STURDIMIENTO.md) | el stun, la salida del hitstun, el mash del aturdimiento |
| | [`DANO-HITPAUSE-KO.md`](../02-COMBATE/DANO-HITPAUSE-KO.md) | el daño, el resolver, los freezes, el hit-time, el KO |
| | [`FISICAS-Y-MOVIMIENTO.md`](../02-COMBATE/FISICAS-Y-MOVIMIENTO.md) | la física y la arquitectura de los moves |
| | [`MAPA-FRAME-A-FRAME.md`](../02-COMBATE/MAPA-FRAME-A-FRAME.md) | el mapa frame a frame |
| **03-PERSONAJES** | [`FICHAS.md`](../03-PERSONAJES/FICHAS.md) | la identidad verificada de los personajes |
| | [`TECNICAS.md`](../03-PERSONAJES/TECNICAS.md) | las técnicas y el teleport de Itsuki |
| | [`FRAME-DATA-MEDIDO.md`](../03-PERSONAJES/FRAME-DATA-MEDIDO.md) / [`FRAME-DATA-Y-STATS.md`](../03-PERSONAJES/FRAME-DATA-Y-STATS.md) | el frame data |
| | [`COMANDOS-Y-FRAME-DATA.md`](../03-PERSONAJES/COMANDOS-Y-FRAME-DATA.md) | los comandos |
| | [`DAMAGE-TABLE.md`](../03-PERSONAJES/DAMAGE-TABLE.md) | la tabla de daño |
| **04-DATOS** | [`DIRECCIONES.md`](../04-DATOS/DIRECCIONES.md) | **la tabla maestra de direcciones** |
| | [`DIRECCIONES-CONFIRMADAS.md`](../04-DATOS/DIRECCIONES-CONFIRMADAS.md) | las direcciones ya confirmadas (no volver a buscarlas) |
| | [`MOVES-Y-TIMING.md`](../04-DATOS/MOVES-Y-TIMING.md) | las tablas de moves y el timing |
| | [`COLISIONES-Y-HITBOXES.md`](../04-DATOS/COLISIONES-Y-HITBOXES.md) | las 5 listas de cajas y los resolvers |
| | [`DATOS-NUEVOS-2026-10-20.md`](../04-DATOS/DATOS-NUEVOS-2026-10-20.md) | lo consolidado del 07-10 |
| **05-PARCHES** | [`PARCHES.md`](../05-PARCHES/PARCHES.md) | los parches, con el porqué de cada byte |
| **00-GUIA** | [`VERIFICACION.md`](../00-GUIA/VERIFICACION.md) | **lo que NO está verificado**, y el sistema de certeza |

## La regla

> Un dato sin dirección **no** es un dato: es una opinión. Y una dirección
> sin comprobar **tampoco**: la base es la ROM **china** y el volcado (y el
> `.asm`) son de la **japonesa**, así que no siempre coinciden.

Lo que se comprobó con `herramientas/docs/verificar_docs.py` (2026-10-22):
**1.401 direcciones citadas, 0 contradicciones, 0 enlaces rotos.**
