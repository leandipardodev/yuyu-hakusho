# Como trabajar en este proyecto

---

> **Nota:** este proyecto se reorganizó por áreas.
> Este fichero es la versión dividida de `MEMORIA.md` (que ya no existe):
> sus secciones están en `00-GUIA/`, `04-DATOS/`, `06-HERRAMIENTAS/`
> y `08-DIARIO/`.

### Como empieza la MEMORIA original

# docs/08-DIARIO/MEMORIA.md — memoria de trabajo del proyecto

Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994). Reverse engineering del
ROM para **modificar el juego original** (`rom/modificadas/`) y herramientas de
analisis (`herramientas/`).

> **El remake en Godot está CANCELADO.** Se decidió trabajar sobre la ROM
> original, que es lo que conserva el comportamiento real del juego. No queda
> nada de Godot en este repo.

**Leer esto antes de tocar nada.** Esta es la memoria del proyecto: todo lo que
esta aqui se verifico leyendo `datos/desensamblado_68000.asm` o ejecutando el juego.

**Donde esta cada cosa:** `docs/INDICE.md` es el mapa. La tabla maestra de
direcciones esta en `docs/04-DATOS/DIRECCIONES.md`.

---

---
## Reglas de trabajo

0. **Nunca escribir rutas absolutas ni nombres de usuario en el codigo.** La
   ROM y el `.asm` se resuelven con `herramientas/desensambladoruta_rom.py` (`ruta_rom()`,
   `camino_asm()`, `dir_sprites()`), que lee `$YUYU_ROM`, luego `.rom_path`,
   luego la raiz del repo. Un path quemado rompio 12 scripts: apuntaban a
   `C:\Users\leand\...` y no corrian en ninguna otra maquina.
1. **`VERIFICACION.md` es la unica fuente de verdad.** Si un dato no esta
   ahi, no esta verificado. No escribir como hecho nada que solo venga de web,
   de guia, o de un script de Discord.
2. **Cada afirmacion lleva su direccion.** Sin `sub.w d0,$78(a4) en 0x1F3E0`
   al lado, no es un dato: es una opinion.
3. **Cruzá writer y consumer.** Un campo no se entiende hasta que se lee lo que
   lo escribe y lo que lo lee. Asi se descifro que `$B9` es el byte alto del HP.
4. **El material externo se audita, no se copia.** Ver
   `COLISIONES-Y-HITBOXES.md` §8: el script de Discord tiene 6 errores
   confirmados.
5. **Scripts de Fightcade: pasivos.** Nada de escrituras en la memoria del
   juego. El unico write permitido es el output de `print`.
6. **Actualizar los apuntes en el mismo cambio.** Si descubriste algo, el
   `.md` se actualiza antes de pasar a otra cosa.

---

