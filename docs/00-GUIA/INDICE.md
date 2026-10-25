# El índice del proyecto

*Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994). Un repo de **parcheo de
ROM**: la base es la ROM china; encima hay un manifiesto de parches y un
conjunto de herramientas para descifrar el motor.*

Este índice es el **puente entre las dos fuentes de conocimiento**:

| De dónde | Qué aporta | Dónde está |
|---|---|---|
| **El análisis técnico** (este repo) | las direcciones, el desensamblado, las herramientas, los parches | `docs/`, `herramientas/`, `datos/` |
| **Tu diario de investigación** (el repo de notas) | las **reglas del juego**, lo que se midió jugando, el historial de 126 rondas | `notas/` (sub-repo, no se toca) |

Ninguno de los dos se lee entero. Este índice dice **qué leer para qué**.

---

## 1. Las áreas

| Área | Qué hay dentro |
|---|---|
| [`00-GUIA/`](COMO-TRABAJAR.md) | cómo trabajar, las reglas, las trampas, **cómo se marca lo que no está confirmado** |
| [`01-MOTOR/`](01-MOTOR/ARQUITECTURA.md) | la arquitectura del juego: hardware, los bancos de ROM, el bucle, **la entrada y los planos**, los emuladores |
| [`02-COMBATE/`](02-COMBATE/DANO-HITPAUSE-KO.md) | la vida, el maná, el stun, el daño, el hitpause, el KO, el mapa frame a frame |
| [`03-PERSONAJES/`](03-PERSONAJES/FICHAS.md) | las fichas, el frame data, las técnicas, los comandos, la tabla de daño |
| [`04-DATOS/`](04-DATOS/DIRECCIONES.md) | las tablas y las direcciones: el mapa maestro, los moves, las colisiones |
| [`05-PARCHES/`](05-PARCHES/PARCHES.md) | los parches: el manifiesto, las recetas, cómo hacer uno |
| [`06-HERRAMIENTAS/`](06-HERRAMIENTAS/HERRAMIENTAS.md) | el desensamblado, las sondas de Lua, el verificador de la documentación |
| [`07-INVESTIGACION/`](07-INVESTIGACION/PLAN.md) | los informes, las fuentes externas, **los errores** y la [comparativa de repositorios](../07-INVESTIGACION/COMPARATIVA-AKARA.md) |
| [`08-DIARIO/`](08-DIARIO/SESIONES.md) | la bitácora por sesión, la memoria del proyecto, lo pendiente |

## 2. Lo primero que hay que saber

| Si quieres saber… | Mira |
|---|---|
| **dónde está cada cosa en la memoria** | [`04-DATOS/DIRECCIONES.md`](04-DATOS/DIRECCIONES.md) — la tabla maestra |
| **qué está verificado y cómo** | [`00-GUIA/VERIFICACION.md`](00-GUIA/VERIFICACION.md) — el sistema de certeza |
| **las reglas del juego** (comandos, maná, cancelaciones) | `notas/GENERAL/SISTEMAS.txt` — se lee entero |
| **por qué el golpe hace lo que hace** | [`02-COMBATE/DANO-HITPAUSE-KO.md`](02-COMBATE/DANO-HITPAUSE-KO.md) |
| **cómo se parchea** | [`05-PARCHES/PARCHES.md`](05-PARCHES/PARCHES.md) |
| **qué se averiguó en las últimas sesiones** | [`08-DIARIO/SESIONES.md`](08-DIARIO/SESIONES.md) — la bitácora |
| **qué falta** | [`08-DIARIO/PENDIENTE.md`](08-DIARIO/PENDIENTE.md) |
| **en qué no hay que caer** | [`00-GUIA/TRAMPAS.md`](00-GUIA/TRAMPAS.md) |

## 3. Cómo se marca lo que no está confirmado

| Marca | Significado |
|---|---|
| **[ROM]** | leído en el desensamblado, con la instrucción y la dirección |
| **[MEDIDO]** | medido en el emulador (FBNeo) o jugando, con el script que lo midió |
| **[NOTAS]** | viene del repo de notas |
| *** | **afirmación sin verificar**: se escribe con su procedencia, pero no como hecho |

> La razón de hacerlo así: un dato pendiente **es información**, y borrarlo tira
> trabajo. Lo que **no** se hace es escribir un dato sin marcar y sin respaldo.

**Y ahora se puede comprobar automáticamente:**

```bash
python herramientas/docs/verificar_docs.py
```

Compara **cada dirección que se cita en la documentación** contra la ROM base
real (no contra el `.asm`, que es de la ROM japonesa) y avisa de:

1. **enlaces rotos** a ficheros `.md`;
2. **direcciones que no son código** (son datos: no es un error, pero se listan);
3. **contradicciones**: el doc afirma una instrucción para una dirección y
   ahí hay otra. **Estas son errores reales del doc** (se han encontrado
   varios: direcciones +2 por el volcado, y direcciones de la ROM J que en la
   base (china) son otra cosa).

## 4. Las dos ROMs (y por qué importa)

| | |
|---|---|
| **la base** (`rom/base/yuyu_makyou_base.bin`) | **la china**, con el checksum arreglado a `$337B`. Es la que se parchea. |
| `rom/original/...chinese.bin` | una copia de la base (la china de referencia) |
| `rom/original/...english translation.bin` | la inglesa (checksum `$BE4F`): **no arranca** |
| `datos/desensamblado_68000.asm` | el desensamblado de la **ROM japonesa (J)**. **Es una referencia, no la fuente de verdad**: la china tiene el código **en sitios distintos** (la traducción mueve cosas). Para parchear, la fuente de verdad es la **base**. |

## 5. El flujo de trabajo

```bash
# 1. el desensamblado (si hay que regenerarlo)
python herramientas/desensamblado/construir_roms.py --limpiar

# 2. un parche: se anade al manifiesto (datos/parches.json) y se construye
python herramientas/desensamblado/patch_rom.py <base> <salida> <grupos...>

# 3. comprobar que la ROM parcheada sigue desensamblandose bien
python herramientas/desensamblado/verificar_desensamblado.py <rom>

# 4. comprobar que la DOCUMENTACION sigue siendo verdad
python herramientas/docs/verificar_docs.py

# 5. las sondas (en FBNeo): Game > Lua Scripting > New Lua Script Window
herramientas/lua/sonda_plano.lua      los planos: el flag $A042 y el suelo
herramientas/lua/sonda_cruce.lua      el cruce: que boton lo lanza
herramientas/lua/sonda_teleport.lua   el teleport de Itsuki
```

**La regla de oro:** *cada afirmación lleva su dirección, y la dirección se
comprueba contra la ROM base*.
