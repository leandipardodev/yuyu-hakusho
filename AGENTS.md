# Yu Yu Hakusho: Makyou Toitsusen — reglas de este repo

Ingeniería inversa y **parcheo byte a byte** de la ROM original (Mega Drive, 1994, Treasure).
El remake en Godot está **cancelado**: todo cambio se hace sobre la ROM.

## Punto de entrada

- Mapa de todo: `docs/00-GUIA/INDICE.md`
- Reglas de trabajo y sistema de certeza: `docs/00-GUIA/COMO-TRABAJAR.md` y `docs/00-GUIA/VERIFICACION.md`
- Direcciones: `docs/04-DATOS/DIRECCIONES.md` (tabla maestra)

## Skills de este proyecto (usarlas en vez de explorar)

- `yuyu-parche` — flujo completo de un cambio de ROM (manifiesto → construir → verificar → doc)
- `yuyu-direccion` — camino corto para investigar una dirección u offset
- `yuyu-lua` — reglas de las sondas FBNeo/Fightcade (Lua 5.1)

Comandos: `/parche` (hacer un cambio), `/direccion` (investigar rápido), `/verificar`
(docs contra ROM).

## Fuentes de verdad

- **Para parchear**: `rom/base/yuyu_makyou_base.bin` (la china, checksum $337B). El juego
  verifica el checksum al arrancar: todo parche lo reescribe siempre al final.
- `datos/desensamblado_68000.asm` y `_z80.asm` son de la **ROM japonesa**: SOLO referencia,
  la china tiene el código en direcciones distintas. No usar sus direcciones para parchear.
- Los datos verificados y sus niveles de confianza: `datos/parches.json` (`CODIGO` >
  `MEDIDO` > `DEDUCIDO` > `SIN_CONFIRMAR`).

## Reglas de trabajo

1. Cada afirmación lleva su **dirección + instrucción**. Sin eso no es un dato.
2. Lo no verificado se escribe con `***` y su procedencia. Nunca sin marcar.
3. **Nunca escribir rutas absolutas ni nombres de usuario**: usar
   `herramientas/desensamblado/ruta_rom.py` (lee `.rom_path` o `YUYU_ROM`).
4. Actualizar la documentación **en el mismo cambio**, no después.
5. Un hallazgo va al fichero de área; al diario (`docs/08-DIARIO/`) solo una línea que
   diga dónde quedó.
6. Antes de cerrar cualquier cambio: `python herramientas/desensamblado/construir_roms.py`
   y `python herramientas/docs/verificar_docs.py` (0 rotos, 0 contradicciones).

## Que no se toca

- `rom/original/` y `rom/fuentes/`: dumps del juego original, derechos de Treasure/Toei/Shueisha.
- `notas/`: es un sub-repo git propio (el diario). Está excluido de este repo por el `.gitignore`.
- No escribir rutas absolutas en el código ni commitear `.rom_path`.
