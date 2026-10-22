# Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994)

Ingeniería inversa del ROM de *Yu Yu Hakusho: Makyou Toitsusen* (Treasure, 1994)
para **modificar el juego original byte a byte**, con datos medidos del ROM y
nunca suposiciones.

> **Estado: solo parcheo de ROM.** El remake en Godot que hubo en este proyecto
> está **cancelado**: se decidió trabajar sobre la ROM original, que es lo que
> conserva el comportamiento real del juego. No queda nada de Godot aquí.

---

## 0. Comprobar que la documentación es verdad

```bash
python herramientas/docs/verificar_docs.py
```

Compara **cada dirección citada en los documentos** contra la ROM base real y
avisa de los enlaces rotos y de las **contradicciones** (el doc afirma una
instrucción y en esa dirección hay otra). Hay que correrlo después de tocar
cualquier documento con direcciones.

---

## 1. Por dónde empezar

**Si vienes de fuera y no conoces el proyecto:**

| Lee esto | Y sabrás |
|---|---|
| **`docs/00-GUIA/INDICE.md`** | **el mapa de todo**: qué hay, de dónde sale cada cosa, qué falta |
| **`docs/04-DATOS/DIRECCIONES.md`** | **todas las direcciones** del juego en una sola tabla, con su fuente |
| **`docs/00-GUIA/VERIFICACION.md`** | el sistema de certeza: cómo se marca lo que no está confirmado |
| **`docs/00-GUIA/TRAMPAS.md`** | la memoria del proyecto: las trampas (errores ya detectados y por qué) |
| **`docs/05-PARCHES/PARCHES.md`** | los parches de ROM, con el porqué de cada byte |

**Si quieres tocar la ROM:**
`docs/05-PARCHES/PARCHES.md` → `datos/parches.json` → `herramientas/desensamblado/patch_rom.py`

**Si quieres entender el juego:**
`notas/GENERAL/SISTEMAS.txt` (las reglas, se lee entero) y
`notas/GENERAL/CONTEXTO.txt` (el diario de la investigación, se busca con grep).

---

## 2. Estructura

```
yuyu-hakusho/
├── README.md                     <- este fichero
│   (la memoria del proyecto ahora vive en docs/00-GUIA/ y docs/08-DIARIO/)
├── .rom_path                     <- dónde está la ROM en ESTA máquina (no se comparte)
│
├── docs/                         <- LA DOCUMENTACION, por areas
│   ├── 00-GUIA/                  <- el indice, como trabajar, las trampas, la certeza
│   │   ├── INDICE.md             ← ★ EL MAPA: qué hay y de dónde sale
│   │   ├── COMO-TRABAJAR.md      ← ★ las reglas de trabajo
│   │   ├── TRAMPAS.md            ← ★ las trampas (no volver a caer)
│   │   └── VERIFICACION.md       ← ★ el sistema de certeza
│   ├── 01-MOTOR/                 <- la arquitectura: hardware, entrada, PLANOS, emuladores
│   ├── 02-COMBATE/               <- vida, mana, stun, dano, hitpause, KO
│   ├── 03-PERSONAJES/            <- las fichas de los 11 personajes y sus tecnicas
│   ├── 04-DATOS/                 <- las tablas y las direcciones (la tabla maestra)
│   ├── 05-PARCHES/               <- los parches, con el por que de cada byte
│   ├── 06-HERRAMIENTAS/          <- el desensamblado, las sondas, los verificadores
│   ├── 07-INVESTIGACION/         <- informes, fuentes externas y errores
│   └── 08-DIARIO/                <- la bitacora por sesion, la memoria y lo pendiente
│
├── rom/
│   ├── LEEME.md                  <- el índice de las ROM: qué hay y qué hace cada una
│   ├── base/
│   │   └── yuyu_makyou_base.bin  la ROM original reparada (SHA1 BE4461EB…)
│   ├── cambios/                  ← ★ UNA ROM POR CAMBIO, cada una con SOLO ese cambio
│   │   ├── 01_hiei_dragon_lento.bin
│   │   ├── 02_hiei_dragon_hitbox.bin
│   │   ├── 03_itsuki_kage_instantaneo.bin
│   │   ├── 04_itsuki_onda_lenta.bin
│   │   ├── 05_fijo_doble_salto.bin
│   │   ├── 06_kurama_planta_elevacion.bin
│   │   ├── 07_gameplay_extras.bin
│   │   ├── 08_un_solo_plano.bin
│   │   ├── 09_rival_nace_delante.bin
│   │   └── 10_diagnostico_sinz80.bin
│   ├── combinaciones/            <- ROMs con varios cambios a la vez
│   │   └── yuyu_makyou_UNIFICADA.bin   ★ la version unificada (la lista "aceptados")
│   └── fuentes/                  <- los dumps de referencia (del autor y otros)
│
├── herramientas/
│   ├── desensamblado/            <- el laboratorio (Python)
│   │   ├── ruta_rom.py            dónde está la ROM (sin rutas quemadas)
│   │   ├── patch_rom.py           EL PARCHEADOR verificado
│   │   ├── volcar_moves.py        vuelca las tablas de moves de los 11
│   │   ├── auditar_moves.py       audita ese volcado contra el ROM
│   │   ├── blob_chain.py          la cadena de cajas de un move
│   │   ├── ctx_hits.py            qué moves tienen hitbox
│   │   ├── construir_roms.py      construye TODAS las ROMs desde las recetas
│   │   ├── emulador_68000.py      emulador propio (Unicorn + Z80 + VDP)
│   │   └── …                     60 herramientas más
│   ├── lua/                      <- scripts para FBNeo / Fightcade
│   │   ├── LLUVIA RECTA.LUA       visualizador de cajas de colisión
│   │   ├── LLUVIA DIAGONAL.LUA    el mismo + gate de pelea
│   │   ├── ITSUKI SET MOVE.LUA    stop time de Itsuki + rastreador de técnicas
│   │   ├── sonda_*.lua            sondas de lectura
│   │   ├── diagnosticos/          diagnósticos
│   │   └── pruebas/               bancos de prueba (207 pruebas del HUD)
│   └── generar_stun.py            genera STURDIMIENTO.md desde las fuentes
│
├── datos/
│   ├── parches.json               ★ EL CATÁLOGO DE PARCHES (dirección → valor)
│   ├── recetas.json               ★ LAS RECETAS: qué ROMs se construyen y con qué grupos
│   ├── desensamblado_68000.asm    28.168 instrucciones desensambladas
│   ├── desensamblado_z80.asm      el driver de sonido
│   ├── mapa_rom.txt               qué es código y qué son datos
│   └── paginas_codigo.csv
│
├── assets/
│   ├── imagenes/                  lo extraído del ROM (retratos, pantallas)
│   └── recortes/                  recortes para usar
│
└── notas/                         <- TU DIARIO DE INVESTIGACIÓN (repo git propio)
    ├── GENERAL/                   SISTEMAS · CONTEXTO · HIT STATE · METODO…
    ├── <PERSONAJE> PDF/           las técnicas de cada personaje
    ├── LUAS/                      tus scripts (versiones anteriores)
    ├── HERRAMIENTAS/              yyhrom.py · salida/ · ENTREGAS/
    └── .git                       126 commits: el historial
```

---

## 3. Los cambios, uno a uno

Cada cambio que hemos ido haciendo está **por separado en su propia ROM**, hecho
solo sobre la base original. Y además **se suma a la versión unificada**. Las dos
cosas salen del mismo sitio, así que nunca se desincronizan.

| Fichero en `rom/cambios/` | Qué hace |
|---|---|
| `01_hiei_dragon_lento.bin` | el dragón de Hiei va a media velocidad (1 px/frame, y el proyectil a 0,875) |
| `02_hiei_dragon_hitbox.bin` | la hitbox del dragón se estrecha de 68 a 9 px |
| `03_itsuki_kage_instantaneo.bin` | las manos de Itsuki (影手) salen instantáneas y se desplazan ÷4 |
| `04_itsuki_onda_lenta.bin` | la onda de Itsuki viaja a media velocidad |
| `05_fijo_doble_salto.bin` | el fix del doble salto (la rutina de reset limpia `$87`, el contador de saltos) |
| `06_kurama_planta_elevacion.bin` | la planta de Kurama: su 2º golpe cae en elevación recta (430 frames, con ventana) |
| `07_gameplay_extras.bin` | 8 ajustes de gameplay (hitstun, empuje, muerte, tope de combo, slow-mo) |
| `08_un_solo_plano.bin` | **un solo plano**: no se puede cruzar y el rival se puede golpear |
| `09_rival_nace_delante.bin` | el rival nace en el plano delantero y a su tamaño normal |
| `10_diagnostico_sinz80.bin` | diagnóstico: el juego arranca sin depender del Z80 |

En `rom/combinaciones/` están las ROMs con varios cambios a la vez. La
principal es **`yuyu_makyou_UNIFICADA.bin`**: lleva todos los cambios de la
lista `aceptados` de `datos/recetas.json`.

**El índice completo, con los bytes de cada uno: `rom/LEEME.md`.**

### El flujo: un cambio nuevo se suma a las dos cosas

```
1.  su grupo se añade a  datos/parches.json     (los bytes: dirección → valor)
2.  su id se añade a    datos/recetas.json     (la lista "aceptados")
3.  python herramientas\desensamblado\construir_roms.py
```

Con eso el cambio aparece **(a)** en su propia ROM de `rom/cambios/` y **(b)**
sumado a la versión unificada de `rom/combinaciones/`. El constructor verifica
cada ROM: la relee y comprueba byte a byte los valores del manifiesto, que la
base tenía el valor esperado, y que el checksum cuadra.

> Los cambios `06b_kurama_planta_ventana` y `06c_kurama_planta_ciego` son
> **alternativas** entre sí (la misma planta con otro estado de derribo): solo
> uno puede entrar en `aceptados`.

### Aplicar una combinación que tú elijas

```powershell
python herramientas\desensamblado\patch_rom.py `
    "rom\base\yuyu_makyou_base.bin" `
    "rom\combinaciones\mi_combinacion.bin" `
    dragon dragon_vel blob kage_dur kage_vel onda_vel doble_salto kurama_planta un_plano rival_delante
```

Los grupos son los de `datos/parches.json` (dirección → valor, con el nivel de
confianza de cada uno).

> **El checksum de la cabecera se reescribe SIEMPRE al final.** El juego lo
> verifica al arrancar (`0x4318`): si no cuadra escribe `0x0E` en `$E080` y se
> queda clavado en el logo SEGA. Cada byte del manifiesto declara su valor
> esperado; si el ROM de entrada no lo tiene, el parcheador **aborta sin
> escribir nada**.

## 4. Requisitos

| Para | Necesitas |
|---|---|
| Las herramientas Python | Python 3.14 · `pip install unicorn==2.1.4 capstone z80==1.2.0` |
| Diagnóstico en el juego | FBNeo / Fightcade (los `.lua` de `herramientas/lua/`) |
| La ROM | **no se distribuye**: es material con derechos de autor |

**Dónde está la ROM:** el fichero `.rom_path` (una línea con la ruta) o la
variable de entorno `YUYU_ROM`. Ver `herramientas/desensamblado/ruta_rom.py`.

---

## 5. Las reglas del proyecto

Están todas en `docs/00-GUIA/TRAMPAS.md`, pero estas son las que más importan:

1. **`DATOS_VERIFICADOS.md` es la única fuente de verdad.** Lo que no esté ahí,
   no está verificado.
2. **Cada afirmación lleva su dirección.** Sin `sub.w d0,$78(a4)` en `0x1F3E0`
   al lado, no es un dato: es una opinión.
3. **Lo no verificado se marca con `***`.** Se escribe igual, con su
   procedencia. Lo que no se hace es escribirlo sin marcar.
4. **Nunca escribir rutas absolutas ni nombres de usuario en el código.**
5. **Actualizar los apuntes en el mismo cambio.**
6. **Un hallazgo va a un archivo de sistema; al registro solo una línea** que
   diga dónde quedó.

---

## 6. Estado

| Pieza | Estado |
|---|---|
| Desensamblado 68000 | 28.168 instrucciones |
| Tabla de moves | 195 índices / **191 moves** · auditoría **1950/1950** byte a byte ✓ |
| Emulador 68000 propio | **80 %**: arranca, resuelve el Z80, 200 frames. La VRAM queda vacía y no llega a combate |
| Gráficos | **bloqueados**: el ROM tiene los gráficos comprimidos y los sprites de personaje nunca están en plano |
| Parches de ROM | 14 grupos, todos verificados byte a byte |
| Los 4 cambios unificados | ✓ en `rom/combinaciones/` |

**Lo que NO se sabe todavía:** el frame data exacto de cada golpe, el
blockstun, el emparejamiento id de move ↔ nombre, y el slot del jugador 2.

Todo eso está detallado en `docs/04-DATOS/DIRECCIONES.md` §9.

---

## 7. Créditos

- **Juego original:** Yu Yu Hakusho — Makyou Toitsusen, ©1994 Sega / Treasure.
  Romero *Axion*, rearmado por Treasure con la licencia de YuYu.
  - Director y diseño: **Tetsuhiko Kikuchi**
  - Programación: **Masaki Ukyo**, **Mitsuru Yaida**
  - Arte: **Hiroshi Iuchi**, **Makoto Ogino**
  - Sonido: **Satoshi Murata**
- El análisis, las herramientas y los parches de este repositorio son trabajo
  original.
- El diario de investigación está en <https://github.com/Akara1996/yuyu-rom-notas>.
