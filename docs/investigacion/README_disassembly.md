# Yu Yu Hakusho: Makyou Toitsusen (J) — Sega Mega Drive / Genesis
# Analisis y extraccion de codigo

## Que es realmente este ROM

La carpeta contiene **8 archivos** con nombres de chips Neo Geo
(`[p1]`, `[h1]`..`[h4]`, `[b2]`, `[T+Chi]`), pero **todos son el mismo juego de
Sega Mega Drive / Genesis**, no un cartucho Neo Geo. Los sufijos son un error
de nombrado (copiados de otro set). Los 8 archivos son *variantes/dumps*
ligeramente distintos del mismo ROM:

| Archivo                         | Tamano | CRC32      | Notas                                |
|----------------------------------|--------|------------|--------------------------------------|
| `[b2].bin` / `[h1].bin` / `[h4].bin` | 3 MB | distintos  | header `(C)SEGA 1994.JUL`, serial `-00` |
| `[h2].bin`                       | 3 MB   | distinto   | titulo con espacios `Yu Yu Hakusho`   |
| `[h3].bin`                       | 3 MB   | distinto   | region **JUE** (export), sin `(C)`   |
| `[p1].bin` / sin sufijo          | 3 MB   | distinto   | serial `-004`, J                     |
| `[T+Chi].bin`                    | 3 MB   | distinto   | fecha `2002.JULY` (trad. chino)      |

Identidad del juego (leida de la cabecera Sega en `0x100`):
- Consola : `SEGA MEGA DRIVE (C)SEGA 1994.JUL`
- Titulo  : `YUYU HAKUSYO`
- Serial  : `GM G-004122-00`
- Region  : `J` (Japon)
- Tamano  : 3 MB (`ROM end = 0x2FFFFF`)

## Estructura del ROM

- `$000000-$0000FF` — tabla de vectores 68000 (RESET = `$000200`).
- `$000100-$0001FF` — cabecera Sega (titulo, serial, checksum `0x4A36`).
- `$000200+` — **codigo 68000** (motor del juego, logica de combate, VDP).
- Codigo disperso en ~107 paginas de 4 KB entre `$000200` y `$291ADD`
  (datos VDP y tablas intercalados con el codigo).
- `$0393FE` — **driver de sonido Z80** (3072 bytes / `$C00`), copiado por el
  68000 al RAM Z80 en `$0000` durante el arranque.
- Resto del ROM — tiles, sprites, paletas y muestras (VDP); relleno `$FF`
  desde ~`$2AC9E8` hasta el final.

## Herramientas creadas (en `_disasm_tools/`)

- `m68kgen.py` — extractor de codigo 68000. Usa **Capstone (m68k)** con un
  **descenso recursivo de flujo de control** en 5 fases: vectores -> ramas
  cosechadas -> finales de funcion (`rts`/`link`) -> tablas de punteros ->
  re-expansion. Separa codigo de datos (solo marca como codigo lo que el
  flujo alcanza). Genera `game_68000.asm`.
- `z80dis.py` — desensamblador **Z80** propio (Capstone 5 en Python no trae
  Z80). Cubre mapa base + prefijos `CB`/`ED`/`DD`/`FD`/`DDCB`/`FDCB` y opcodes
  no documentados.
- `z80gen.py` — localiza el driver Z80 (bucle `lea src(pc),a0 / lea $a00000.l,a1
  / move.b (a0)+,(a1)+ / dbra`) y lo desensambla. Genera `game_z80_driver.asm`.
- `rommap.py` — clasifica el ROM pagina a pagina (entropia) para separar
  codigo / datos / graficos. Genera `rom_map.txt`.

## Resultados de la extraccion

- **68000**: 28.168 instrucciones, 111.420 bytes de codigo, 3.211 etiquetas,
  2.284 funciones identificadas, 1.469 `rts` alcanzados (~90% de los 1.652
  `rts` del ROM). Salida: `game_68000.asm` (~37.000 lineas).
- **Z80**: driver de 3.072 bytes, 2.165 lineas, 98% decodificado.
  Salida: `game_z80_driver.asm`.

## Estado de la extraccion de graficos/audio (2026)

**Intentamos extraer tiles/paletas/samples y NO es viable con metodo
generico en este ROM.** Evidencia obtenida del codigo 68k:

- El juego **NO guarda tiles 4bpp crudos ni paletas CRAM** en el ROM.
  El motor grafico esta en `$2C6C`-`$2D00` y usa un **codec de compresion
  propio**: la rutina `$2D5E` hace `eori.b #$f` + `lsl.b #$4` sobre bytes de
  origen (descompresion nibble-a-nibble de 2bpp/4bpp). Las imagenes se
  expanden en work-RAM (`$D400`, `$F700`, `$F780`) y recien ahi se copian
  al VDP (rutinas `$0614`/`$0654` escriben a `$C00004`).
- Las paletas se **construyen en RAM de trabajo** (`$F780`/`$F798`) en
  runtime; no hay bloques CRAM de 16 colores almacenados en el ROM.
  Un escaneo por fuerza bruta de "bloques de 16 colores" encuentra LUTs de
  fade y tablas de datos, NO paletas (falsos positivos: ~12.700 candidatos).
- El audio usa **YM2612 escrito directamente por el 68000** (puerto
  `$C00004`), no el PSG-Z80 para el FM. Las muestras ADPCM, si las hay,
  estan referenciadas por punteros internos del driver Z80 en `$393FE`, cuyo
  formato no es trivial.

**Conclusion:** para extraer sprites/tiles correctos hay que
**reimplementar el descompresor** de la rutina `$2D5E` y reconstruir como
el juego puebla `$D400`/`$F700`, o usar una herramienta especializada de
Genesis (p.ej. un decompresor de ROMs de fight anime de 1994). Es un
proyecto de RE, no un one-liner de escaneo.

Archivos `.asm` (codigo) si son correctos y verificados:
`game_68000.asm` y `game_z80_driver.asm` (ver seccion Resultados).

## Como se regenerate

```powershell
$rom = ".\Yuu Yuu Hakusho - Makyou Toitsusen (J).bin"
python .\_disasm_tools\m68kgen.py $rom -o .\game_68000.asm --stats .\code_pages.csv
python .\_disasm_tools\z80gen.py  $rom -o .\game_z80_driver.asm --src 0x393FE --len 0xC00
python .\_disasm_tools\rommap.py  $rom -o .\rom_map.txt --pages-csv .\code_pages.csv
```

(Requiere Python 3 y `pip install capstone` para el 68000; el Z80 es propio.)

## Donde esta la ROM

La ROM **no se distribuye con el repo**: es una obra con derechos de autor
(Studio Pierrot / Toei / Shueisha). Bajala por tu cuenta y dile al script
donde esta. Hay tres formas, en este orden de prioridad:

**1. Variable de entorno `YUYU_ROM`**

```powershell
$env:YUYU_ROM = "D:\roms\yuyu.bin"
python .\_disasm_tools\m68kgen.py -o .\game_68000.asm
```

**2. Fichero `.rom_path`** en la raiz del repo, con la ruta en una sola linea.
Va en `.gitignore`, asi que es local de cada uno.

```powershell
'D:\roms\yuyu.bin' | Out-File -Encoding utf8 .\.rom_path
```

**3. Dejar la ROM en la raiz del repo** con su nombre original.

Todos los scripts de `_disasm_tools/` resuelven la ruta por `_disasm_tools/rompath.py`.
Los que aceptan `--rom` / argumento posicional ahora lo tienen **opcional**: si
se omite, se aplica la resolucion anterior.

Para comprobar que la encuentra:

```powershell
python .\_disasm_tools\rompath.py
```

## Notas de analisis

- El 68000 **controla el YM2612 directamente** (escribe al puerto `$C00004`
  del FM chip) y usa `$A11100` (arbitraje del bus Z80) para arrancar/detener
  el Z80. El driver Z80 gestiona el PSG/temporizadores.
- Los vectores de excepcion apuntan a stubs `stop #$2700` (`$0003E6`, `$0003EA`,
  `$0003EE`); el bucle principal salta a `$00219EA` y `$00080C`.
- El punto de entrada `reset` (`$000200`) hace la rutina estandar de arranque
  Genesis: limpiar RAM Z80, configurar VDP, copiar el driver Z80, etc.
