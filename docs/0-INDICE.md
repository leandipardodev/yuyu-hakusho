# ÍNDICE — el mapa del proyecto

Este documento es el **puente entre las dos fuentes de conocimiento**:

| De dónde | Qué aporta | Dónde está |
|---|---|---|
| **El análisis técnico** (este repo) | las direcciones, el desensamblado, las herramientas, los parches | `docs/1-datos/`, `herramientas/`, `datos/` |
| **Tu diario de investigación** (el repo de notas) | las **reglas del juego**, lo que se midió jugando, el historial de 126 rondas | `notas/` |

Ninguno de los dos se lee entero. Este índice dice **qué leer para qué**.

---

## 1. Las cuatro cosas que hay que saber del juego

| Si quieres saber… | Mira |
|---|---|
| **dónde está cada cosa en la memoria** | `docs/1-datos/DIRECCIONES.md` ← **la tabla maestra** |
| **qué está verificado y cómo** | `docs/1-datos/DATOS_VERIFICADOS.md` |
| **las reglas del juego** (comandos, maná, cancelaciones, reacciones) | `notas/GENERAL/SISTEMAS.txt` ← se lee entero |
| **por qué el golpe hace lo que hace** | `docs/1-datos/PARCHES.md` §8 y `docs/1-datos/VARIACION_DANOS_HITPAUSE_KNOCKDOWN.md` |

---

## 2. Cómo se marquan las certezas

En todo el proyecto, un dato lleva siempre su procedencia:

| Marca | Significado |
|---|---|
| **[ROM]** | leído en `datos/desensamblado_68000.asm`, con la instrucción y la dirección |
| **[MEDIDO]** | medido en el emulador (FBNeo) o jugando, con el script que lo midió |
| **[NOTAS]** | viene de tu repo de notas |
| *** | **afirmación sin verificar**: se escribe con su procedencia, pero no como hecho |

> La razón de hacerlo así: un dato pendiente **es información**, y borrarlo tira
> trabajo. Lo que no se hace es escribir un dato sin marcar y sin respaldo, que
> es lo que costó el 255 del HP.

---

## 3. Los documentos de este repo

| Fichero | Qué es | Tamaño |
|---|---|---|
| `docs/1-datos/DIRECCIONES.md` | **la tabla maestra de direcciones** (aquí y en las notas, fundidas) | 11 secciones |
| `docs/1-datos/DATOS_VERIFICADOS.md` | **la fuente de verdad**: todo verificado, con su dirección | largo |
| `docs/1-datos/PARCHES.md` | los 14 grupos de parche, con el porqué de cada byte | 8 secciones |
| `docs/1-datos/COLISIONES_Y_HITBOXES.md` | las 5 listas de cajas, el dispatcher, los resolvers | |
| `docs/1-datos/FISICAS_Y_MOVIMIENTO.md` | física, struct del jugador, arquitectura de moves | |
| `docs/1-datos/TABLAS_MOVES_Y_TIMING.md` | registro de 8 bytes, 12 tablas, blockstun | |
| `docs/1-datos/VARIACION_DANOS_HITPAUSE_KNOCKDOWN.md` | el hilo completo del golpe, con lo refutado a la vista | |
| `docs/2-personajes/` | fichas de los 11, stun, frame data, comandos | 6 ficheros |
| `docs/3-investigacion/` | informes, fuentes web, errores | 5 ficheros |
| `docs/4-emulador/` | cómo funciona el emulador propio | 2 ficheros |
| `MEMORIA.md` | **la memoria del proyecto**: las ~140 trampas y las reglas de trabajo | ~1400 líneas |

---

## 4. El diario (`notas/`)

Es un **repo git propio** (`github.com/Akara1996/yuyu-rom-notas`) con 126
commits. Es donde está lo que se midió jugando.

| Fichero | Qué es | Cómo se lee |
|---|---|---|
| `GENERAL/SISTEMAS.txt` | **las reglas del juego** (478 líneas) | **se lee entero** |
| `GENERAL/PROYECTO.txt` | dónde estamos, qué falta, en qué orden | se lee entero |
| `GENERAL/CONTEXTO.txt` | **el diario**: una sección por ronda, con los logs | **se busca con grep**, nunca entero |
| `GENERAL/HIT STATE.txt` | la tabla de reacciones y todos los estados | se busca |
| `GENERAL/METODO.txt` | las lecciones de procedimiento | por número |
| `GENERAL/MOVES DE TODOS.txt` | los 227 golpes del ROM (generado) | se busca |
| `GENERAL/HIEI BALANCE.txt` | el balance de Hiei | |
| `<PERSONAJE> PDF/` | las técnicas de cada personaje (txt + PDF) | |
| `LUAS/` | tus scripts, versiones anteriores a las de `herramientas/lua/` | |
| `HERRAMIENTAS/` | `yyhrom.py` · `salida/` (ROM original y modificado) · `ENTREGAS/` (el parche de 1 byte de la planta) | |

**El historial vale por sí solo**: los mensajes de los commits son el
razonamiento escrito, con los errores y las correcciones.

---

## 5. Lo que hizo cada parte

```
notas/  ──(medición en el juego)──►  reglas del juego, estados, reacciones
   │
   ▼
herramientas/lua/  ──(sondas pasivas)──►  qué pasa en cada frame
   │
   ▼
datos/desensamblado_68000.asm  ──(lectura del código)──►  por qué pasa
   │
   ▼
datos/parches.json  ──(un dato por dirección)──►  rom/modificadas/
   │
   ▼
patch_rom.py  ──(verifica cada byte)──►  la ROM que arranca
```

**El orden importa.** Leer el código consumidor antes de interpretar los datos
fue lo que funcionó; buscar tiles a ciegas por el ROM fue lo que no.

---

## 6. Lo que falta (por valor sobre esfuerzo)

| # | Qué | Por qué |
|---|---|---|
| 1 | **Cerrar el mapa id ↔ nombre de move** | los nombres vienen de web, no del ROM. Sin esto no se sabe qué técnica es cuál |
| 2 | **El parser de frame data** | el registro de 8 bytes ya está descifrado; falta el programa que lo convierta en tabla de startup/active/recovery |
| 3 | **El blockstun** | falta la **dirección**. 32 se midió, pero es una medida, no un dato |
| 4 | **El slot del jugador 2** | `$FF8800` o `$FF9000`. La medición externa pesa más que la inferencia |
| 5 | **Terminar el emulador** | lo más caro. Daría sprites con la paleta exacta y un oráculo |
| 6 | **Sprites por diferencia de frames** | barato y en paralelo: el fondo se aísla con una placa de mediana |

Todo esto está detallado en `docs/1-datos/DIRECCIONES.md` §9.

---

## 7. Las reglas para trabajar aquí

Están en `MEMORIA.md`, pero las cinco que más importan:

1. **`DATOS_VERIFICADOS.md` es la única fuente de verdad.**
2. **Cada afirmación lleva su dirección.**
3. **Lo dudoso se marca con `***`** — se escribe igual, con su procedencia.
4. **Nunca rutas absolutas ni nombres de usuario en el código.**
5. **Un hallazgo va a un archivo de sistema; al registro solo una línea.**
