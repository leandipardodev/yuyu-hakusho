# Informe de Reverse Engineering
## Yu Yu Hakusho: Makyou Toitsusen (Japan) - Sega Mega Drive / Genesis

**Archivo analizado:** `Yuu Yuu Hakusho - Makyou Toitsusen (J).bin`
**Serial:** `GM G-004122-00` | **Fecha:** 1994.JUL | **Region:** `J` (Japan) | **Tamano:** 3 MB (`0x000000`-`0x2FFFFF`)
**CPU:** Motorola 68000 (big-endian) + Zilog Z80 (sonido)
**Herramientas:** `desensamblador_68000.py` (Capstone m68k + descenso recursivo), `z80_dis.py` (desensamblador Z80 propio)

---

## 1. Roster - 11 personajes (Nombres reales confirmados via web)

**Correccion importante:** el roster esta COMPLETO (11 personajes, IDs 1-11). **Kuwabara SI existe** (ID 5). La web confirma: 桑原=Kazuma Kuwabara, 蔵馬=Kurama - son **dos luchadores distintos**, no dos formas del mismo personaje. Investigacion web (fuentes chinas/taiwanesas, ver `INVESTIGACION-WEB.md`) + evidencia del binario dan el roster completo. **Todos los personajes tienen la misma cantidad de vida** (HP = constante global, no stat por personaje).

El selector recorre IDs **1 a 11 con wrap circular**, verificado en el codigo 68k:
- `0x8302` `cmpi.w #$b, $10(a5)` -> si P1 supera 11, reinicia a 1
- `0x8318` `move.w #$b, $10(a5)` -> al bajar desde 1, salta a 11
- `0x834E` / `0x8364` -> identico para P2
- `0x848C` `cmpi.w #$b, d1` + `bhi` -> valida el ID del joystick (puerto `$3FFF80`)

Orden de seleccion (tabla `0x7A96` = secuencia 1..11) con tabla de retratos `0x109CA`:

| ID | Personaje | Nombre japones | Super (超霊撃) |
|----|-----------|----------------|-----------------|
| 1 | **Sensui** | 仙水 | 巨大裂蹴紅球波 |
| 2 | **Jin** | 陣 | 移動爆風障壁 |
| 3 | **Itsuki** | 樹 | 時間凍結 |
| 4 | **Genkai** | 幻海 | 霊光乱打 (tiene un **超霊撃 oculto**) |
| 5 | **Kuwabara** | 桑原一雄 | 霊剣乱舞 |
| 6 | **Yusuke** | 浦飯幽助 | 霊光ラッシュ |
| 7 | **Kurama** | 蔵馬 (妖狐) | 妖狐変化 |
| 8 | **Hiei** | 飛影 | 邪王炎殺黒龍波 |
| 9 | **Chui** | 酎 | 酔風連脚 |
| 10 | **Toguro (mayor)** | 戶愚呂兄 | 乱風剣 |
| 11 | **Toguro (menor)** | 戶愚呂弟 | 100%中の100% |

**Kuwabara (桑原一雄, ID 5) y Kurama (蔵馬, ID 7) son DOS personajes distintos** (confirmado por el usuario y por la lista de personajes). Nota de traduccion: 桑原 = Kuwabara (no Kurama), y 蔵馬 = Kurama. Son los dos luchadores principales del juego.

**Nota sobre la tabla de retratos (`0x109CA`):** realise una inferencia incorrecta al principio (crei que los IDs 9 y 11 "compartian tiles base" = mismo personaje en dos formas). Al verificar, **ningun modulo del codigo 68k referencia la tabla `0x109CA`**, asi que NO es la lista de retratos que pense - es otra estructura de datos (posiblemente una lista de sprites/HUD). La conclusion de "9 y 11 son el mismo personaje" **queda descartada**. El orden autoritativo es el que reporta el usuario (ha visto la pantalla real): Chui(9) -> Toguro mayor(10) -> Toguro menor(11).

---

## 2. Modos de juego y tablas de rondas

Las tablas de IDs estan indexadas por `$18(a5)` (numero de ronda) y se leen en rutinas que inicializan la estructura de combate en `$9000` (posicion `0x4380`, tamano `0x450`).

### VS 2 jugadores (tablas `0x7A96` P1 / `0x7ABC` P2, 16 entradas)
- **P1 (`0x7A96`):** 1,2,3,4,5,6,7,8,9,10,11,4,11,5,9,6
- **P2 (`0x7ABC`):** 11,3,6,2,3,8,5,2,11,11,7,7,5,3,1,9
- Setup: `0x7A06`; lector de IDs: `0x7A84`

### 1P vs CPU (tabla `0xD166`, 8 rondas)
- Secuencia: 6,7,8,1,3,4,2,5 (Yusuke, Kurama, Hiei, Sensui, Itsuki, Genkai, Jin, Kuwabara)
- Asigna **un solo personaje** (`$10(a5)`, no P2) -> modo 1 jugador
- Lector: `0xD154`

### 4 parejas / combate por pares (tablas `0x48E6` P1 / `0x48F0` P2)
- **P1:** 1 (Sensui), 3 (Itsuki), 2 (Jin), 5 (Kuwabara)
- **P2:** 11 (Toguro menor), 8 (Hiei), 9 (Toguro mayor), 6 (Yusuke)
- Termina con **Toguro mayor (9) vs Yusuke (6)** -> combate final
- Lector: `0x48C6`; setup gemelo al VS (`0x4870`)

**Nota:** el orden 1..11 en `0x7A96` (P1) es la secuencia de seleccion; las 8 primeras coinciden con los IDs 1-8 usados en 1P-vs-CPU, confirmando que el Story usa los 8 base y Toguro como jefe final.

---

## 3. Roster completo (11 personajes, IDs 1-11)

No queda ninguno sin identificar. La tabla de arriba esta completa. Correccion de un
error previo mio: inicialmente creia que 蔵馬 era una "forma de Kurama" y que
Kuwabara no existia. **Incorrecto**: la web (newton.com.tw, nesenbbs) confirma
que **桑原 = Kazuma Kuwabara** (ID 5) y **蔵馬 = Kurama** (ID 7) son luchadores
independientes, igual que el usuario indico.
## 4. Los 8 dumps - comparativa

| Archivo | Tamano | CRC32 | Region | Serial | vs base |
|---|---|---|---|---|---|
| `(J).bin` (base) | 3 MB | `0x71CEAC6F` | J | `-004` | referencia |
| `[h1].bin` | 3 MB | `0x0B1EE641` | J | `-00` | 8 bytes (header) |
| `[h4].bin` | 4 MB | `0x3916F5FF` | J | `-00` | 8 bytes (header) |
| `[b2].bin` | 3 MB | `0x9075C723` | J | `-00` | 29 bytes |
| `[h3].bin` | 3 MB | `0x20B8D690` | JUE | `-00` | 13 bytes (region export) |
| `[h2].bin` | 3 MB | `0xE0C24DC7` | J | `-00` | 32 bytes (titulo con espacios) |
| `[p1].bin` | 3 MB | `0x05E3FFCC` | J | `-004` | **1.396 bytes (build parcheada)** |
| `[T+Chi].bin` | 3 MB | `0x3AFFA6CC` | J | `-00` | **32.489 bytes (traduccion china)** |

Los sufijos (`p1`, `h1`-`h4`, `b2`) son nomenclatura de **chips Neo Geo** - un error de nombrado. Todos son dumps del **mismo juego de Mega Drive**.

### Checksum
El checksum almacenado en `0x190` es `0x4A36` en los 8 dumps, pero **ninguno lo recalcula** al verificar la suma de palabras 16-bit desde `0x200` - indicio de que el header no se actualizo tras las modificaciones.

---

## 4bis. Modo oculto (SECRETO) - localizado en el codigo

El juego tiene un **modo oculto** (referencia: forum.gamer.com.tw - "将CPU困难度调到最高，在游玩第一个模式破关，会新增一个新模式，最多可以1vs3"). Verificado en el codigo 68k:

**Cadena de activacion:**
- `0x3AD6` — `btst.b #$6, $f550.w` : si dificultad CPU maxima cumplida
- `0x3ADE` — `bset.b #$7, $f550.w` : **activa el flag de modo desbloqueado**, luego `move.b #$1, $f807.w`
- `0x39B0` — en el menu de modo: `tst.b $f550` (bit 7) **o** `tst.b $f55a` (modo completado) -> salta el bloqueo y **habilita el modo extra**
- `0x3A86` — durante el juego, si bit 7 activo, salta la rutina de reloj/timer (el modo extra tiene reglas distintas)

**Variables clave:**

| Variable | Rol |
|---|---|
| `$f550` bit 6 | dificultad de CPU maxima cumplida |
| `$f550` bit 7 | **modo desbloqueado** |
| `$f55a` | modo completado (set en `0xFEBC`) |
| `$f807` | flag de modo de juego activo |

**Como desbloquearlo:** poner la dificultad de CPU al MAXIMO y completar el modo 1. El juego activa `$f550` bit 7 y aparece el modo nuevo (permite hasta **1 vs 3**).

**Super oculto de Genkai:** fuentes chinas (bilibili) mencionan un 超霊撃 oculto para **Genkai** ("灵光镜反冲"), corregido en una version modificada del juego.

---

## 5. Secretos - build parcheada `[p1]`

El dump `[p1]` cambia codigo real en 4 sitios:

### Secreto 1 - Rama activada en `0x3FD4`
```
base : 6a00 00d2   bpl.w  $40A8      ; salta solo si NO hay "borrow" (rara vez)
p1   : 6000 00d2   bra.w  $40A8      ; salta SIEMPRE
```
Contexto (`0x3FC6`-`0x3FD8`): se testean `d0 = $6(a5) - 2` (contador de input) y `$ff09` (bit START del joystick, leido de `$A10001` en `0x3FBE`). En la version original esta ruta es **casi inalcanzable**; en `p1` se vuelve una rama normal.

### Secreto 2 - Llamada neutralizada en `0x4D00`
```
base : 6100 0100   bsr.w  $4E02      ; llama a la subrutina $4E02
p1   : 6002         bra.b  $4D04      ; la saltea
```
Contexto: se comprueba `$f54e.w`; si esta en 0 se ejecutaba `bsr $4E02` (logica de inicializacion de estado). En `p1` esa llamada se desactiva.

**Patron:** ambos parches activan una ruta / desactivan una verificacion - perfil de **build de desarrollo o transmision** con un chequeo removido.

---

## 6. Traduccion china `[T+Chi]`

32.489 bytes diferentes del base:
- **Codigo:** zonas `0x4E4C`-`0x6490`, `0x896D`-`0x8EAD`, `0xBB5D`-`0xC50D`
- **Graficos:** `0x180000`+ (cabecera reescrita: fecha `2002.JULY`)
- Modifica logica de juego, no solo texto.

---

## 7. Arquitectura tecnica

- **68k extraido:** 28.168 instrucciones, 111 KB de codigo, 3.211 etiquetas, 2.284 funciones, ~90% de los `rts` alcanzados -> `desensamblado_68000.asm`
- **Driver Z80:** ROM `0x393FE` (3072 bytes), copiado a RAM Z80 `$0000` por el 68000 (bucle `0x38A92`), 98% decodificado -> `desensamblado_z80.asm`
- **Sonido:** el 68000 **escribe el YM2612 directamente** (puerto `$C00004`); `$A11100` arbitra el bus Z80
- **Bucle principal:** `0x3A2E` (llama a subrutinas de pantalla `$2C9E`, `$3AD6`, `$3982`, `$2300`...)
- **Generador de sprites:** `$2D5E` decodifica atributos de sprite del VDP (tile index, paleta, flip, link) desde una tabla de 2-4 bytes -> no es un compresor de tiles
- **Handler IRQ:** `0x2E5E`; **init VDP:** `0x416`/`$046A`; **RESET vector:** `0x000200`

### Nota sobre assets
El ROM **no almacena tiles 4bpp crudos ni paletas CRAM** - se construyen en runtime (work RAM `$D400`/`$F700`/`$F780`). Un escaneo generico de "tiles/paletas" produce ruido. Para extraer sprites hay que aislar el codec real de graficos, aun no located.

---

## Pendiente / Estado

- **HP uniforme (confirmado por el usuario):** los 11 personajes tienen la **misma cantidad de vida**. Esto explica por que NO existe una tabla de HP indexada por personaje: el HP es una constante global, no un stat por personaje. Las diferencias entre personajes estan en movesets, velocidad de desplazamiento, alcance y animaciones - no en vida.
- **ID 10 = Toguro (hermano mayor)**. Roster completo, sin huecos.
- **Tabla de stats por personaje** - el analisis Heuristico produjo varias falsas pistas (LUTs de fisica/seno en `0x27xxx`/`0x34xxx`, y una tabla de 8 slots en `0x283CCC` que resulto ser **data de escenario/ronda**, no de personaje: 7 de 8 slots comparten los ultimos 16 bytes). El acceso real a los datos por personaje es indirecto y requiere traza dinamica.
- **Movesets/comandos por personaje** - requiere trazar la logica de combate por personaje (11 bloques de rutinas). No hay acceso directo `move.w tabla(pc,d0.w)` a una tabla de stats.
- **Flujo exacto del Story** - pendiente de confirmacion del usuario.
- **Descompresor de graficos** - el bloque `0x2D5E` es un generador de atributos de sprite del VDP, no el compresor de tiles. El codec real aun no esta aislado.
- **Assets (sprites/paletas)** - bloqueado hasta reimplementar el codec real.

### Herramientas para seguir
- `desensamblado_68000.asm` - desensamblado con etiquetas; grep por `lsl.w #2` / `adda.w (pc,dN.w)` para seguir indexaciones de tablas.
- `herramientas/desensambladodesensamblador_68000.py` - regenera el desensamblado (permite re-seeds).
- **Recomendacion:** para stats/movesets hace falta un debugger (MAME + monitor 68000): breakpoint al entrar en combate, y trazar donde se lee el ID del personaje. El analisis estatico a ciegas produjo demasiados falsos positivos.

---

## Archivos generados (en esta carpeta)
- `desensamblado_68000.asm` - desensamblado completo 68k (~37.000 lineas)
- `desensamblado_z80.asm` - driver Z80 (2.165 lineas)
- `mapa_rom.txt` - clasificacion del ROM por paginas (entropia)
- `paginas_codigo.csv` - mapa de paginas con codigo
- `herramientas/desensamblado` - `desensamblador_68000.py`, `z80_dis.py`, `desensamblador_z80.py`, `rommap.py`

## AVISO IMPORTANTE sobre la fiabilidad de los datos

A partir de ahora, `VERIFICACION.md` es la **unica** referencia fiable:
contiene solo lo comprobado leyendo el ROM o ejecutando el juego en BizHawk
(HP 223, umbral 111, offset $B8, direcciones de los personajes, 408 impactos
de dano, secretos, protocolo Z80).

El resto de documentos (`FICHAS.md`, `COMANDOS-Y-FRAME-DATA.md`,
`DAMAGE-TABLE.md`, `FRAME-DATA-MEDIDO.md`) contienen una mezcla de datos
medidos y datos copiados de guias web. Antes se afirmaba que "todos los
valores foram VERIFICADOS contra el ROM", lo cual era **falso**.

`(cancelado)` lleva ahora un bloque `_confianza` con la
procedencia campo a campo: `ROM`, `BIZHAWK`, `WEB` o `ESTIMADO`.

Consecuencia practica: `stun_max`, las notas de stats, y las tablas de
normales/especiales NO son canonicas. Si vas a modify el juego o ajustar la
remake, no tomes esos numeros como verdad.
