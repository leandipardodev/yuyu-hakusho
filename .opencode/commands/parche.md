---
description: Flujo completo de parche de ROM
---
Cargá la skill `yuyu-parche` y ejecutá el flujo completo para el cambio pedido:

$ARGUMENTS

Cerralo con: el grupo en `datos/parches.json`, la ROM construida con
`python herramientas/desensamblado/construir_roms.py`, el id en la lista `aceptados`
de `datos/recetas.json` (si el usuario lo aprobó), el doc del área actualizado y una
línea en `docs/08-DIARIO/SESIONES.md`. Antes de terminar corre
`python herramientas/docs/verificar_docs.py` y deja 0 enlaces rotos y 0 contradicciones.
