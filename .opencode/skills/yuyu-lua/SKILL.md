---
name: Sonda Lua (yuyu)
description: Reglas para escribir y verificar las sondas FBNeo/Fightcade del proyecto Yu Yu Hakusho (Lua 5.1), con las trampas conocidas ya resueltas. Cargarlo para crear, modificar o depurar cualquier script Lua del proyecto.
---

## Reglas técnicas que en este build NO se negocian

1. **Lua 5.1**: sin BOM, sin features de 5.2+ (el BOM rompe y ya pasó dos veces).
2. **NO usar `memory.registerexec`**: en esta build no dispara (`invocaciones=0`). Usar
   `emu.registerafter(fn)` para latidos y lecturas.
3. `emu.frameadvance()` SIEMPRE directo en el bucle, nunca envuelto en función (cuelga el emu).
4. `joypad.set({Boton=true}, 1)` — DICT, no bitmask.
5. Dominios de memoria: `M68K BUS` para la work RAM 68k (`0xFF8400` etc., directo, sin offset).
6. La ROM en FBneo se carga por nombre corto: `md_yuyumte`. El lanzamiento local puede usar
   `client.openrom(path)` — la ruta viene de `herramientas/desensamblado/ruta_rom.py`, nunca
   rutas absolutas escritas a mano.
7. Si el script lee el slot del P2, usar `detectar_slots()` si existe (ya lo tienen las
   sondas): no depende de la pregunta abierta `$FF8800` vs `$FF9000`.

## Qué debe hacer una sonda buena

- **Leer antes que escribir**: preferir sondas pasivas (lecturas) sobre hooks de escritura.
- **Avisar solo con cambios** (imprimir al cambiar de valor, con el frame en el que cambia).
- **Autocomprobarse si puede**: el patrón de oro es `herramientas/lua/ITSUKI SET MOVE.LUA`,
  que mapea la detección sobre el código del ROM y falla con carteles si la firma no
  coincide. Un script que solo lee puede estar leyendo al revés; uno que se autocomprueba
  es una prueba.
- Escribir el ROM nunca. Las sondas son de diagnóstico; los cambios si van por el flujo de
  la skill `yuyu-parche`.

## Al terminar

- El script nuevo va a `herramientas/lua/` con nombre `sonda_<que_hace>.lua` (o el nombre
  de la herramienta si es visor, p.ej. `LLUVIA RECTA.LUA`).
- Si descubrió una trampa de la API de FBNeo, añadir una línea a `docs/00-GUIA/TRAMPAS.md`.
- Referenciar el script desde la sección de sondas del README o del doc del área.
