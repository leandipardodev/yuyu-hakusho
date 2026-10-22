---
description: Investigar una dirección del ROM por el camino corto
---
Cargá la skill `yuyu-direccion` y resolvé la dirección/offset/tarea pedida por el camino
corto (leer solo DIRECCIONES.md, MOVES-Y-TIMING.md y ESTRUCTURA-DE-JUGADOR.md; el resto,
con grep). No leas ficheros gigantes de corrido:

$ARGUMENTS

Cerrá con: qué ES el dato (dirección + instrucción exacta), cómo quedó verificado
(estático / medido / conflicto resuelto a favor de lo medido), y el hallazgo anotado en
el fichero del área correcto (con `***` si no está confirmado). Si pediste construir
alguna sonda Lua, usá la skill `yuyu-lua`.
