---
name: Parche de ROM (yuyu)
description: Flujo completo para un cambio en la ROM de Yu Yu Hakusho (manifiesto, recetas, construir, verificar, documentar). Cargarlo ante cualquier parche, mod o cambio de gameplay pedido.
---

## El flujo (siempre este orden)

1. **Identificar los bytes** si no se conocen: cargar la skill `yuyu-direccion` primero. No inventar valores.
2. **Agregar el grupo** a `datos/parches.json`: `direccion -> valor`, con el nivel de
   confianza definido en `_meta.niveles_de_confianza` (`CODIGO` / `MEDIDO` / `DEDUCIDO` /
   `SIN_CONFIRMAR`). Nombre de grupo consistente con los existentes.
3. **Construir**: `python herramientas/desensamblado/construir_roms.py`
   - Genera (a) la ROM individual en `rom/cambios/` y (b) suma el id a la unificada de
     `rom/combinaciones/` **solo si el id está en la lista `aceptados` de `datos/recetas.json`**.
   - Parcheo puntual de una combinación a mano:
     `python herramientas/desensamblado/patch_rom.py rom/base/yuyu_makyou_base.bin <salida.bin> <grupos...>`
4. **Verificar en juego**: FBNeo con la sonda Lua correspondiente de `herramientas/lua/`
   (ver skill `yuyu-lua`). `verificar_desensamblado.py <rom>` comprueba que el ROM parcheado
   se sigue desensamblando bien.
5. **Documentar en el MISMO cambio**: el doc del área correspondiente (los cambios de gameplay
   van a `docs/05-PARCHES/PARCHES.md`), una línea en `docs/08-DIARIO/SESIONES.md`, y correr
   `python herramientas/docs/verificar_docs.py` (debe quedar 0 rotos y 0 contradicciones).

## Reglas duras

- La base es `rom/base/yuyu_makyou_base.bin` (la china, checksum $337B). Source de verdad
  para parchear. El `.asm` en `datos/` es de la ROM **J**: SOLO referencia.
- **Toda instruccion 68K escrita a mano se valida con capstone ANTES de entrar al parche**:
  decodificar los bytes del payload y comparar contra la intencion (leccio: `30 5D`
  no era `move.w d0,$78(a5)`, era `movea.w (a5)+,a0` y tildaba el juego; el correcto es
  `3B40 0078`). Encoding de `MOVE`: destino = reg en bits 11-9 + mode en bits 8-6,
  fuente = mode en bits 5-3 + reg en bits 2-0.
- El patcher **reescribe el checksum SIEMPRE al final** y **aborta sin escribir nada** si el
  byte "old" del manifiesto no cuadra. `--force` solo si la ROM ya tenía el parche aplicado.
- Nunca tocar `rom/original/` ni `rom/fuentes/`. Nunca escribir rutas absolutas: usar
  `herramientas/desensamblado/ruta_rom.py` (lee `.rom_path` o `YUYU_ROM`).
- Los ids `06b_kurama_planta_ventana` y `06c_kurama_planta_ciego` son **alternativas excluyentes
  entre sí**: solo uno puede estar en `aceptados`.
- La doc cita checksums y direcciones: tras cambiarla, correr el verificador de docs.
