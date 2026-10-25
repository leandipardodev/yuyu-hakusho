# Comparativa de los repositorios públicos de Akara1996

**Fecha de consulta:** 2026-10-25  
**Objetivo:** identificar qué material público aporta el otro proyecto, qué
conocimiento ya tenemos en común y qué información de este repo técnico puede
ser útil para su IA sin mezclar variantes de ROM.

## Repositorios encontrados

La API pública del perfil `Akara1996` muestra dos repositorios:

| Repositorio | Estado observado | Relevancia |
|---|---|---|
| [`yuyu-rom-notas`](https://github.com/Akara1996/yuyu-rom-notas) | Público; `main` en `6809bf6` (commit 167), actualizado el 2026-10-20 | Análisis del juego, reglas, hit states, movimientos y notas por personaje |
| [`YYH-Docs-2`](https://github.com/Akara1996/YYH-Docs-2) | Repositorio vacío (GitHub respondió HTTP 409 al pedir su árbol) | No había contenido que analizar |

Se revisaron el README, `GENERAL/SISTEMAS.txt`, `GENERAL/PROYECTO.txt`,
`GENERAL/HIT STATE.txt` y los mensajes recientes de `main`. No se descargaron ni
revisaron enteros los archivos históricos grandes, los PDF por personaje ni
los 227 movimientos; sus descripciones se tomaron únicamente del README.

## Qué aporta el repositorio público

El README describe una base de investigación amplia: reglas generales del
juego, historial por rondas, una tabla de estados de reacción, documentos por
personaje y una lista generada de 227 movimientos. El proyecto se define
explícitamente como **análisis, no modificación de ROM**; sus sondas Lua deben
ser pasivas.

El material público consultado incluye análisis de `$68` como selector de
reacción: el código mostrado en `GENERAL/HIT STATE.txt` lee el byte en
`$01F526`, lo duplica en `$01F52A`, indexa una tabla relativa y salta al handler
en `$01F532`. También documenta los handlers `$68=7` (`$01F6C8` → estado `$27`)
y `$68=8` (`$01F6F2` → estado `$30`), y reporta un hitstop medido de 16/17
frames. **Estos son datos del repositorio externo; todavía no se han
revalidado contra la ROM china que se parchea aquí.**

El commit público 167 también registra una lección de método útil: una búsqueda
de bytes por sí sola confundió un blob de golpe con cajas de colisión; el autor
describe como evidencia más fuerte comparar los bytes del blob con los que el
motor acaba de copiar a RAM y limitar la búsqueda a la tabla adecuada del
objeto. La explicación completa y sus límites están en el
[commit 167](https://github.com/Akara1996/yuyu-rom-notas/commit/6809bf62ab73a3add87e77dca24ebd95ae26dbaa).

## Solapamiento y cautelas

El repo local `notas/` tiene como `origin` a
[`Akara1996/yuyu-rom-notas`](https://github.com/Akara1996/yuyu-rom-notas);
por tanto, la mayor parte de sus reglas de juego y medidas no nos es nueva:
ya forman parte de la base local de notas. La tabla `$68`, el objeto de la
planta de Kurama y varias trampas de interpretación también se reflejan en
[`DIRECCIONES.md`](../04-DATOS/DIRECCIONES.md) y
[`DATOS-NUEVOS-2026-10-20.md`](../04-DATOS/DATOS-NUEVOS-2026-10-20.md).

**No se deben trasladar direcciones entre ROMs por semejanza.** Este repo
parchea `rom/base/yuyu_makyou_base.bin`, la ROM china; el
[`desensamblado 68000`](../../datos/desensamblado_68000.asm) es de la ROM
japonesa y sirve solo como referencia. La base china puede tener código en
direcciones distintas. El propio trabajo externo documenta pruebas sobre ROMs
inglesas/japonesas; cualquier dirección externa debe contrastarse con la
variante y el binario exactos antes de usarla.

## Conocimiento complementario de este repo para compartir

El aporte diferencial es el trabajo de ingeniería inversa y parcheo de la
variante china:

1. **Identificación de la ROM objetivo:** la fuente de parches es la ROM china
   de [`rom/base/yuyu_makyou_base.bin`](../../rom/base/yuyu_makyou_base.bin);
   su checksum de cabecera de referencia es `$337B`. No usar las direcciones
   del ASM japonés como ubicaciones de parche en esta base.
2. **El checksum se valida al arrancar.** En el desensamblado de trabajo,
   `movea.l #$200,a0` en `0x4302` inicia el recorrido; `add.w (a0)+,d1` en
   `0x4312` suma palabras; `movea.l #$18e,a1` en `0x4318` apunta al checksum;
   `cmp.w (a1),d1` en `0x431E` lo compara. Todo parche debe recalcular y
   escribir el checksum al final. El desarrollo y su evidencia están en
   [`DATOS-NUEVOS-2026-10-20.md`](../04-DATOS/DATOS-NUEVOS-2026-10-20.md).
3. **Hay una cadena de construcción y verificación de parches**, manifiesto
   incluido, que recompone ROMs y contrasta la documentación contra la ROM
   base. Ver [`PARCHES.md`](../05-PARCHES/PARCHES.md) y
   [`HERRAMIENTAS.md`](../06-HERRAMIENTAS/HERRAMIENTAS.md).
4. **Datos de estructura y combate cruzados con código:** por ejemplo, el
   registro de jugador usa `$78` para HP (el daño se aplica con
   `sub.w d0,$78(a4)` en `0x1F3E0`), `$B8` para maná y `$C6` como contador de
   combo del defensor. La tabla maestra y sus niveles de confianza están en
   [`DIRECCIONES.md`](../04-DATOS/DIRECCIONES.md).

Los puntos 1–4 describen la base documental de este proyecto, no autorizan a
usar esas direcciones en la ROM del otro proyecto. Para compartirlos, conservar
las instrucciones y la advertencia de variante.

## Estado de la copia local de `notas/`

Al comparar el clon local con `origin/main`, la rama local estaba **dos commits
por delante** (commits 168 y 169) y cinco archivos de `GENERAL/` tenían cambios
sin commit. Ese material no está en el `main` público consultado. No se
inspeccionó ni copió como si fuera contenido público; revisar y acordar antes
de enviarlo a otra persona.

## Contexto listo para pegar en la IA del otro proyecto

```text
Estamos colaborando en Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994), pero
hay dos líneas de trabajo distintas. Tu repositorio público y sus notas se
centran en medir y documentar el juego; este otro repo hace ingeniería inversa
y parches byte a byte de la ROM china.

Regla crítica de compatibilidad: el objetivo de parcheo es la ROM china
rom/base/yuyu_makyou_base.bin (checksum de cabecera de referencia $337B).
El ASM japonés es solo referencia y sus direcciones no son fuente de verdad
para parchear la ROM china. No traslades offsets entre ROMs inglesa, japonesa
y china sin verificarlos en el binario exacto.

Dato verificado útil si analizas parches: el juego comprueba su checksum al
arrancar. En el código de la ROM de trabajo: 0x4302 `movea.l #$200,a0`,
0x4312 `add.w (a0)+,d1`, 0x4318 `movea.l #$18e,a1` y 0x431E
`cmp.w (a1),d1`. Un parche debe recalcular el checksum al final o la ROM puede
quedarse detenida en el arranque.

Tu análisis público de $68, estados de reacción, hitstop y blobs de objetos
es complementario y en gran parte ya está disponible en nuestro clon local de
notas. Mantén esos datos como procedentes de tu variante/emulador hasta
revalidarlos contra la ROM china. En especial, no tomes una coincidencia de
bytes como prueba de que encontraste un blob: compara con los bytes que el
juego copia a RAM y con la tabla correcta del objeto.

Para cada dato compartido, conserva fuente, versión de ROM, dirección e
instrucción o método de medición. Marca como hipótesis cualquier punto no
revalidado. No escribas parches, no cambies ROMs originales y no modifiques
sondas pasivas sin pedirlo.

Referencia de la comparación: docs/07-INVESTIGACION/COMPARATIVA-AKARA.md.
```
