# AGENTS.md — memoria de trabajo del proyecto

Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994). Reverse engineering del
ROM para el remake en Godot (`remake_godot/`) y herramientas de analisis.

**Leer esto antes de tocar nada.** Esta es la memoria del proyecto: todo lo que
esta aqui se verifico leyendo `game_68000.asm` o ejecutando el juego.

---

## COMO SE MARCA LO QUE NO ESTA CONFIRMADO

**`***`** en un `.md` = **afirmacion sin verificar**. Se escribe igual, completa y
con su procedencia, pero marcada. La razon: un dato pendiente es informacion y
borrarlo tira trabajo. Lo que **no** se hace es escribir un dato sin marcar y sin
respaldo, que es lo que nos costo el 255 del HP.

| | |
|---|---|
| Sin marca | **[ROM]** o **[MEDIDO]**: hay direccion, o se ejecuto y se vio |
| Con `***` | Viene de material externo, o esta pendiente de cruzar. **La direccion que se escribe es la del material, no nuestra** |

**Al consolidar material que se contradice, se anotan LAS DOS versiones**, no la
que nos guste. Ver el stun por golpe en `DATOS_VERIFICADOS.md` §2b: estan los
dos conjuntos (nuestro 38-62 y el del PDF 2-16) y el criterio que hace pesar al
segundo.

Todo el consolidado del material del 07-10 (la guia de 1127 lineas y el PDF de la
movelist) esta en `DATOS_VERIFICADOS.md` §3e.

## Reglas de trabajo

0. **Nunca escribir rutas absolutas ni nombres de usuario en el codigo.** La
   ROM y el `.asm` se resuelven con `_disasm_tools/rompath.py` (`ruta_rom()`,
   `camino_asm()`, `dir_sprites()`), que lee `$YUYU_ROM`, luego `.rom_path`,
   luego la raiz del repo. Un path quemado rompio 12 scripts: apuntaban a
   `C:\Users\leand\...` y no corrian en ninguna otra maquina.
1. **`DATOS_VERIFICADOS.md` es la unica fuente de verdad.** Si un dato no esta
   ahi, no esta verificado. No escribir como hecho nada que solo venga de web,
   de guia, o de un script de Discord.
2. **Cada afirmacion lleva su direccion.** Sin `sub.w d0,$78(a4) en 0x1F3E0`
   al lado, no es un dato: es una opinion.
3. **Cruzá writer y consumer.** Un campo no se entiende hasta que se lee lo que
   lo escribe y lo que lo lee. Asi se descifro que `$B9` es el byte alto del HP.
4. **El material externo se audita, no se copia.** Ver
   `COLISIONES_Y_HITBOXES.md` §8: el script de Discord tiene 6 errores
   confirmados.
5. **Scripts de Fightcade: pasivos.** Nada de escrituras en la memoria del
   juego. El unico write permitido es el output de `print`.
6. **Actualizar los apuntes en el mismo cambio.** Si descubriste algo, el
   `.md` se actualiza antes de pasar a otra cosa.

---

## Direcciones confirmadas (no volver a buscar)

### Jugador

| Dato | Valor |
|---|---|
| Base del slot P1 | `$FF8400` (`tst.l $ffff8400.l` en `0x10D2C`) |
| Base del slot P2 | `$FF8800`, stride `$400` — **CONFLICTO SIN RESOLVER, pero YA MEDIDO que cambia: en la misma sesion se vio S1+S2 y S1+S4. `detectar_slots()` lo agarra por HP. Ver la seccion de slots** |
| Registro base del struct | `a5` |
| Plano / capa | `$26`; en realidad es un **contador de programa** sobre uno de 8 flujos de bytes. `$0A` elige cual (1 a 8), la tabla de punteros esta en `$3A256` (ver `DATOS_VERIFICADOS.md` §5c) |
| Contador de combo | **`$C6`**, en el **DEFENSOR**, tope 16 (ver la seccion de `$C6`) |
| HP actual | word **SIGNED** en `$78`; llega a **`-1024`** (`$FC00`) al final de la pelea |
| HP maximo | **223** `[MEDIDO]`. `$78` se inicializa a `$FF` (255) en `0x12AE6` / `0x13688`, y **que de ahi salga 223 no esta escrito en ningun sitio** — pendiente abierto. Ver `DATOS_VERIFICADOS.md` §2 |
| Umbral de vida baja | **111** (`$6F`), **11** comparaciones. Hay un **segundo** umbral, **112** (`$70`), en `0x15784` |
| HP dibujado | **`$7A` es la BARRA ANIMADA**, no el HP: persigue a `$78` de a 1 por frame (`0x157A8`). Si HP < 112 toma `$C00E` |
| HP que se dibuja | word en `$7A` (persigue a `$78`, `0x1579C`) |
| Maná / TA (recurso gastable) | word en `$B8`, max **223** (`$DF`) en `0x1A2E2` |
| Umbral de maná bajo | 32 (`$20`), `0x1CD70` |
| Stun actual / maximo | `$7E` / `$80` (words) |
| Posicion en pantalla | `$08` / `$0C`, **calculada y CLAMPADA por `loc_0156F0`** (`0x15700`-`0x15746`). **No hay que recalcularla ni calibrarla**: ver la trampa de `CAL_X`/`CAL_Y` |
| Posicion en mundo | `$40` / `$44` = **16.16 con la parte ENTERA en la palabra de direccion baja**. `$42` / `$46` = **la fraccion**, no la "mitad alta". Ver `DATOS_VERIFICADOS.md` §3f |
| Offset de empuje del frame | `$54` / `$56` |
| Velocidad | `$28` / `$2A` |
| Facing | `$61` |
| Id de move | `$5F` |
| Anim frame / dur / tick | `$59` / `$5A` / `$5B` |
| **`$69`** | **NO es hitpause: es SUPRESION DE HITSTUN POR PERSONAJE**, no un freeze. Esta en el struct (`$69(a5)`, 30 accesos), asi que en un 1v4 cada slot tiene el suyo y un golpe solo toca a los dos involucrados. Y **no hay freeze global en un golpe normal**: el unico escritor de `$F558` en todo el ROM es `0x1FA82: move.w #$a0` = 160, la muerte. Valores: **16** golpe (`0x1F2E0`), **28** clasheo (`0x1F15E`, **no 32**), **255** ulti (`0x1C078`). Se le decia "hitpause" porque `$F558` vale 16 tambien en un golpe: dos campos con el mismo numero en el caso que mas se ve. **[MEDIDO]** con hitstun activo el personaje **se mueve** 1 px por frame, asi que no hay congelacion |
| La oscilacion de 1-2 px del hitstun es desplazamiento | **No: es `$54`, offset de DIBUJADO de un frame.** El signo alterna con la **paridad de `$69`** (`btst.b #$0`) y la amplitud es `$6A` (`add.w d0, $54` / `sub.w d0, $54`, 16 sitios), y se limpia una vez por frame en `0x15718`. **[MEDIDO]** coordenadas constantes mientras el sprite oscila: prueba directa |
| `$6A` es un campo mas de estado | **Es el NIVEL DE EMPUJE y hace DOS cosas:** manda la amplitud del vaiven visual (`$54`) **y** es la magnitud del empuje real. **Decrementa cada frame hasta 1** (`0x12B44`). Por eso "la repulsion se multiplica y decrece" era una sola variable |
| El mismo golpe da siempre el mismo resultado | **Falso, y NO es error de los `.lua`.** Y **NO son 2 variables: es UNA, el frame activo que conecta.** Se ha reproducido en **distintos emuladores** y con **savestates que siempre cargan en el mismo punto**, y se ve a ojo sin ningun `.lua`: en el frame 1 la victima ya aparece mas alejada. **MEDIDO:** un B causa **5 a 8** de daño, un combo completo va de **71 a 86** (15 puntos, **mas del 20 %**), y el pusheo va de **1 a 4 px**. **O sea que el pusheo varia MUCHO mas que el daño**, y nunca se vio un golpe que saquen el doble. **MECANISMO:** `$65` (daño), `$66` (stun) y `$64` (empuje) se leen **los tres del mismo registro de 8 bytes del FRAME ACTIVO** con `(a2)+` en `0x1EC0E`-`0x1EC16`, asi que **un B con mas de un frame activo tiene un `$65` y un `$64` distintos en cada uno**. Eso explica el 5-vs-8, el 1-vs-4 px **y la correlacion entre ambos de una sola vez**. **Y NO HAY ESCALADO POR COMBO:** el camino completo resta `$65` crudo (`0x1F420`), sin multiplicador y sin mirar `$C6`. El 20 % entre combos sale de que conectaron frames distintos. Ver `DATOS_VERIFICADOS.md` §2d |
| Tabla de moves | puntero en `$8C` (12 bases, ver `TABLAS_MOVES_Y_TIMING.md`) |
| **`$65`** | **Daño del move, POR FRAME ACTIVO.** Se lee en `0x1EC0E` con `(a2)+`, del **mismo registro de 8 bytes** que `$66` y `$64`. El camino completo lo resta crudo (`sub.w d0, $78(a4)` en `0x1F424`, con `d0 = $65` en `0x1F420`), **sin escalado** |
| Daño de stun del move | `$66` (`sub.w` a `$7E` en `0x1F42C`), tambien por frame activo |
| **`$63`** | **Mascara del DEFENSOR. Elige el camino del daño y si el golpe ATURDE.** Tres valores, `$00` / `$04` / `$08`, decididos por `cmpi.b #$2d, $5f(a5)` en `0x15B58`. Se cruza en `0x1F320` (`and.b $63(a4), d0` con `$64(a3) & $0C`): **`== 0` completo con stun, `!= 0` reducido sin tocar `$7E`**. **OJO: el reducido es el perfil del chip damage / golpe bloqueado (2x a 3,4x menos), y NO explica la variacion del B** (para `$65` = 8 daria 3, y el minimo medido es 5) |
| **`$64`** | **Cuarto byte del registro del FRAME ACTIVO** (`0x1EC16`, solo con bit 6 del atributo). **Es del MOVE, no del personaje.** Sus **bits 0-1 eligen la intensidad del empuje**: hay 4 niveles, y **una tabla distinta por camino** — reducido `$2B000`/`$39000`/`$4C000`, completo `$30000`/`$40000`/`$56000`. Sus **bits 2-3** son la mitad del AND de `$63` que decide el daño, y el **bit 4** decide si el golpe hace daño reducido o ninguno |
| **`$71`** bit 1 | **Elige el estado del DEFENSOR entre `$2C` y `$2D` en `0x1F3F6`** (`btst.b #$1, $71(a4)`), y de ahi sale si el siguiente golpe pega completo o reducido. **Es el mejor de los cuatro candidatos a blockstun: el unico con mecanismo DEMOSTRADO** (los otros tres solo se deducen). `$2D` ademas es uno de los seis estados que resetean el combo `$C6` |
| Empujón (long) | `$14` = `move.l #$FFFC0000/$FFFB0000/$FFFA0000` |
| ID de personaje | **`$9E`**, no `$9C`. Ver la trampa de abajo |
| Byte de equipo/rol | `$6E` |

### Globales

| Dato | Valor |
|---|---|
| Camara X / Y | `$FFF408` / `$FFF40A` |
| Base X / Y del stage | `$FFA014` (`$360`) / `$FFA016` (`$20`) |
| Scroll vertical | `$FFF566` |
| Limites del stage | `$FFA010` / `$FFA012` |
| Puntero del task de colision | `$FF8100` = `$1EDAC` |

### Colisiones

| Lista | Base | Contador | Stride |
|---|---|---|---|
| hitbox | `$FFA200` | `$FFA004` | `$10` |
| clash | `$FFA300` | `$FFA006` | `$10` |
| hurtbox | `$FFA400` | `$FFA008` | `$10` |
| pushbox | `$FFA500` | `$FFA00A` | `$10` |
| descriptor de grab | `$FFA600` | `$FFA00C` | `$20` |

- **Los contadores son offsets EN BYTES.** `n = contador / stride`. Maximo 15.
- En el ASM los contadores se escriben en `$00A004..$00A00C`; FBNeo los refleja
  en `$FFA004..$FFA00C`. Registrar write hooks en **las dos**.
- Entrada de 16 bytes: `+0` X, `+4` Y, `+8` radioX (**bit 7 = terminador**),
  `+9` radioY, `+$C` owner.
- **El owner es un WORD, no un puntero.** El builder hace `move.w a5`
  (`0x1EC40`, `0x1EC9E`, `0x1ECFC`, `0x1ED5A`, `0x161BE`), asi que vale
  `$8400` / `$8800`, no `$FF8400` / `$FF8800`. El dispatcher lo recupera con
  `movea.w` (`0x1EE34`, `0x1F0A6`, `0x1F23E`): el struct vive en `$8400`.
- Builder `loc_01EB40`, dispatcher `loc_01EDAC`.
- `loc_01EDAC` llama, en este orden: `loc_01EEE2` (grab), `loc_01F090`
  (clash), `loc_01F21E` (hit vs hurt), `loc_01EE1E` (push) y **luego pone a 0**
  los cinco contadores. Por eso el hook tiene que leerlos ahi.
- Resolvers y hitstun que escriben:
  - clash `loc_01F090`: `$69 = #$1C` (28), `$75 = #$1D`.
  - hit `loc_01F21E`: `$69 = #$10` (16), `$75 = #$11`.
  - **OJO: `$69` NO es un freeze, es la SUPRESION DE HITSTUN DEL PERSONAJE.** Esta
    en el struct (`$69(a5)`, 30 accesos), asi que en un 1v4 cada slot tiene el suyo
    y un golpe solo toca a los dos involucrados. Los dos resolvers lo ponen asi:
    clash `loc_01F090`: `$69 = #$1C` (**28**), `$75 = #$1D`; hit `loc_01F21E`:
    `$69 = #$10` (**16**), `$75 = #$11`. El unico **freeze global** del ROM es
    `$F558`, y **su unico escritor es `0x1FA82: move.w #$a0` = 160**, que es la
    **muerte**: un golpe normal no congela a nadie. Por eso durante mucho tiempo se
    le dijo "hitpause" a `$69`: **dos campos distintos con el mismo numero** en el
    caso que mas se ve. **[MEDIDO]** con el hitstun activo el personaje **se
    mueve** 1 px por frame, asi que no hay congelacion
- Hook recomendado: `memory.registerexec(0x01EDAC, fn)`, con write hooks como
  respaldo.

Detalle completo en `COLISIONES_Y_HITBOXES.md`.

---

## Trampas (no volver a caer)

| Trampa | Realidad |
|---|---|
| `$54` = HP maximo | Falso. Es offset de empuje, se borra cada frame. |
| `$14..$17` = stun | Falso. Es el empujón (long). `move.l #$FFFC0000` en `0x1F342`, y dos intensidades más en `0x1F364` y `0x1F386`. El stun es el word de `$7E`. |
| `$B8` = HP | Falso. Es maná/TA, el recurso gastable. El HP es `$78`. |
| `$B9` = super meter | Falso. Es el byte alto de `$B8`, o sea del maná. |
| HP maximo = 223 | **CORREGIDO: el HP maximo ES 223, y nosotros decíamos 255.** El 255 de `$FF` que citábamos es el **sentinel de STUN** (`$7E`, `0x1A282`), y el 223 de `$DF` es el tope del **maná** (`$B8`) — **los dos eran ciertos de campos distintos y los mezclamos con el HP.** Ahora: HP = 223 `[MEDIDO]`, y los umbrales 111 / 112 caen justo en **223/2**, lo que lo confirma. Ver `DATOS_VERIFICADOS.md` §2 |
| `$19C46` = dano | Falso. Es `pagar(coste)`: si `$B8 >= d0` lo resta, si no devuelve 0. |
| `$8479` = HP | Casi. `$79` es el byte ALTO del HP de `$78`. |
| El owner de una caja = puntero a `$FF8400` | Falso. Es un word: `$8400`. Normalizar antes de comparar. |
| `$A014` / `$A016` = camara | Falso. Son la base del stage. La camara es `$F408` / `$F40A`. |
| El contador de lista = numero de cajas | Falso. Es un offset en bytes. |
| `$A600` es una hitbox mas | Falso. Es el descriptor de grab, stride `$20`. |
| 16 cajas por lista | Falso. El maximo es 15. |
| `$08` y `$40` son la misma posicion | No. `$08` es pantalla (con clamp), `$40` es mundo. |
| Escribir ceros en las listas de caja | Nunca. El script de Discord lo hace y es un bug. |
| Usar `&`, `\|`, `~`, `//` en un script de Fightcade | No existen. El Lua de Fightcade es 5.1. Usar `bit.*` y `math.floor`. |
| El humano siempre es el P1, asi que el rival es `$FF8800` | No se puede suponer. Fightcade deja configurar que jugador es el humano. Se deduce de `joypad.get()` (si se pulsa algo en P2, el humano es el P2). Afecta a todo lo que lea `$8400` / `$8800`, no solo al combate. |
| Meter el snapshot de las cajas dentro de un `if SHOW_CAJAS then ... end` | **Nunca.** Leer y dibujar son dos capas. El snapshot se toma SIEMPRE en el exec hook de `$01EDAC`, sin mirar ningun flag. Si se condiciona, apagar las cajas se lleva por delante a cualquier efecto que las use, y no hay forma de comprobar que la memoria se sigue leyendo bien. |
| El overlay dibuja en el espacio del JUEGO | **Falso, dibuja en el de la VENTANA.** El juego es 320x224 (1.4286) y una ventana 4:3 es 1.3333, asi que al ajustar por el ancho sobran ~21 px de borde negro arriba y abajo, y la fila 0 del overlay esta en el borde, no en la primera linea del juego. Con ratio 16:9 lo que sobra son columnas a los lados. Ver la seccion de margenes. |
| Comparar `y_juego` contra `emu.screenheight()` | Son dos espacios distintos. `mundo_y_a_screen()` ya devuelve Y de JUEGO; multiplicarla por el alto de la VENTANA la corre cuando hay borde. `suelo_frontal()` hacia justo eso. |
| Un solo frame con un mando pulsado alcanza para detectar el slot | El sondeo de mandos corre cada 30 frames. Hay que mantener la pulsacion mas de un ciclo o el sondeo cae en un frame sin nada pulsado. |
| Un autotest con el RNG del script sin sembrar es fiable | No. El script hace `math.randomseed(os.time())` al cargar, asi que cada corrida siembra la lluvia en un sitio distinto. Sin congelar el reloj, tres pruebas intermitian: el minimo de particulas por frame, la suma de gotas con y sin colision, y el total de lineas con las cajas encendidas y apagadas. Congelar `os.time` mientras se hace el `dofile` las vuelve deterministas. |
| "Las particulas tienen que llegar a cero en algun frame" | Pide algo que el efecto no promete. Con 7 gotas de 66 frames impactando cada ~9 frames, hay impactos sin parar y NUNCA hay frame con cero. Lo que hay que medir es el MAXIMO: si no hay fuga, se queda en unas 6 de las 64 del pool. **OJO: esa fila se escribio cuando H.Rain tenia 7 gotas de 66 frames y el pool eran 64. Hoy H.Rain tiene 10 en la RECTA y 14 en la DIAGONAL, y el pool son 43 y 52.** El criterio sigue valiendo, los numeros no |
| El color de `gui.*` es `0xAARRGGBB` | **Falso. Es `0xRRGGBBAA`: byte ALTO = ROJO, byte BAJO = ALFA.** Verificado con 20 muestras. Escribir `0xAARRGGBB` no da error: da otro color, en silencio. De ahi que la lluvia saliera rosa. Ver la seccion de color mas abajo. |
| Leer el combo de P1 en el slot del P1 | **Falso. `$C6` esta en el DEFENSOR.** Para el combo de P1 hay que leer `$C6` del slot del P2. |
| El mana por combo no da nada hasta el segundo golpe | Falso, venia de la tabla de web. El ROM **suma el contador antes de usarlo** (`0x1F9F0` antes de `0x1FA0C`), asi que el primer golpe ya da **+2**. Regla: `+2 * n` desde el primero. |
| `$C6` se resetea fuera del rango `$20`–`$30` | A medias. **Tambien se resetea en `$28`–`$2D`**, que esta DENTRO de la ventana. Esos 6 estados cortan el combo. |
| `$26` es el hit-time | **Falso, cerrado.** Es un **contador de programa** sobre un flujo de bytes (`0x379C8`). Prende en todo contacto porque es el frame de la animacion de empuje. Con las 8 tablas volcadas (`_disasm_tools/dump_26.py`): los datos van de `-40` a `+40` y no hay ni 64 ni 192 |
| "El bit 7 es el signo, ya esta" | **Incompleto, y por poco.** Con bit 7 en 1 el valor puede ser un **codigo**: hay cinco, `$80`-`$84`, y se chequean justo despues del `bpl`. `$80`-`$84` NO son desplazamientos. Los negativos de verdad son solo `$85`-`$FF`, y en las tablas hay 8: `-40 -40 -30 -30 -20 -20 -10 -10`, que son las dos mitades de una rampa que cruza el 0 |
| Un valor grande escrito en un campo es una magnitud | No: puede ser un **indice**. Los `$40` y `$C0` que escriben en `$26` (`0x1F7C0`, `0x1F7D4`) son **offsets de arranque del cursor**, no profundidades. Leidos como magnitud, y con y sin el bit 7, dan exactamente la ilusion de "dos planos". Es la regla 3 al reves, y la cometimos dos veces |
| Mirar solo los escritores de un campo | **Media astilla.** Se escribio que `$26` era "profundidad, dos planos" durante una sesion entera porque solo se leyeron los escritores. El consumidor (`loc_0379AE`) lo desmentia en 4 lineas. Es la regla 3 aplicada al reves: **buscar el consumidor, no solo el escritor** |
| Dos `cmpi` seguidos son un test | **No.** En `0x1F4CA` hay dos `blt` distintos y cada uno pertenece a su `cmpi`: el de `0x1F4D0` es del test de `$78` (HP), no del de `$7E` (stun) de abajo. Por eso se concluyo que la camara lenta era "cualquier golpe sin knockdown" cuando es **HP negativo = muerto** |
| Un campo con 3 valores no puede servir para otra cosa | Si se descarto por la mitad. `$69` tiene 4 valores (0, 16, 28, **255**) y el 255 es la ulti de Itsuki. Hay que listar **todos** los valores antes de concluir |
| Un doc corregido por material externo ya esta aplicado al codigo | No necesariamente. Una correccion llego **solo al `.md`**, dejando el `.lua` sin tocar. Doc y codigo contradiciendose es la regla 6, y el sintoma es un HUD que no dibuja nada sin avisar. |
| El ID de personaje esta en `$9C` | **Falso por partida doble.** Ni `$9C` ni `$9E`. `$9C` es un rascador de coordenada que se copia a `$44` (Y de mundo) en 19 sitios, y `$9E` es la mitad alta de ese 16.16. El amigo lo tenia bien y nosotros solo dejamos de decir "es el ID" sin decir que es |
| `$A030` es una cola de ACCIONES de gameplay | **Falso: es la cola de SONIDO.** El byte `+4` del frame data es el **indice de sonido** (`$218D8` -> `$A030`), y `$F800` se usa como base de puntero (`lea.l $f800.w, a0`). Se paso una sesion entera buscando el hit-time en el driver de audio |
| Las ultis tienen un hit-time mas largo | **La premisa es falsa.** `$69` solo toma 0, 16, 28 y 255 en todo el ROM. Un especial pone 16, igual que un basico. **No hay hit-time por movimiento.** Lo unico distinto es el 255 de la ult de Itsuki, que es congelacion total, no hit-time |
| El stride del array de slots dice en que slot esta P2 | **Falso, y casi lo aplico.** Que el array vaya de `$400` en `$400` no dice si P2 es el indice 2 o el 4. Un array de 4 con P1 en el 1 y P2 en el 4 da `$C00` entre ambos: es compatible con el bucle. Un argumento que descarta la medicion externa sin poder probar lo contrario es un non sequitur. |
| Un comentario suelto contradice al codigo | Mirar el codigo, no el comentario. En el material externo hay un `$FF88C6` anotado para el combo cuando el archivo lee `rb(P2 + O.COMBO)` = `$FF90C6`: es un comentario viejo de antes de cambiar P2 a `$9000`. Si lo tomo como evidencia, "contradice" a un archivo que en realidad esta consistente. |
| Un color escrito en ARGB se nota al correrlo | **No, y ese es el problema.** FBNeo no da error: sale otro color, en silencio. Un `.lua` externo traia `0xFFB4D2EA` queriendo un azul palido y le sale rosa salmon. |
| Un color con el byte bajo en `00` es invisible, y el comentario puede mentir | **El alfa va en el byte BAJO, y `00` es TRANSPARENTE.** El cartel "OK" salio con el fondo visible y **las letras y el borde invisibles**, porque los tres estaban con `00` abajo mientras el comentario de cada uno decia "opaco". **El sintoma parece de posicion o de tamano y es de color**: el cartel aparece y el OK no. Ahora hay un test que recorre todos los colores dibujados y falla si alguno tiene alfa 0 (`alfa_de(col) = band(col, 0xFF)`), con las tres mutaciones verificadas |
| Una tabla dispersa se recorre con `ipairs` | **No: `ipairs` SE DETIENE en el primer `nil`.** Recorrer `{ d.c, d.f, d.o }` con `ipairs` contaba 4 de 66 colores, porque un cuadro no tiene `c` y un texto no tiene `f` ni `o`. El test daba **verde con las letras invisibles** mientras decia estar revisandolas. Con `pairs` se recorren las claves, y ahi un `nil` es una clave ausente y no corta nada. **Un test que dice "reviso N cosas" tiene que comprobar que N es el numero que esperaba, y no que sea mayor que cero** |
| Si el material externo se equivoco, el error es suyo | No siempre. Aca el autor copio **nuestro** doc, que estaba mal (`148ee27` lo corrijo despues). Se equivoco de forma totalmente razonable. Un doc sin verificar contamina lo que se construye encima, venga de adentro o de afuera. |
| Un valor hardcodeado sospechoso es un bug | **No necesariamente.** `local P2 = 0xFF8800` llevaba tiempo anotado como "el HUD del P2 no dibuja nada, sin error". **Es falso**: ese valor no llega a la salida del dibujo (`owner_filter()` decide con `SHOW_P2`, y `to_screen()` cancela el base porque la conversion es afin de pendiente 1). Antes de dejarse llevar por un valor raro, **grep de todos sus usos y ver si alguno llega a la salida**. Un `if ob then` bajo un flag en `false` no es un bug, es codigo inerte |
| Escribir `$7E` dentro de un `string.format` | **Es un `%E` de ancho 7, no un signo de pesos.** El `(%7E|+4)*16` que confirmaba `$1F4E2` en `yuyu_knockdiag.lua` comia un argumento de mas y reventaba con `bad argument #8`, en pleno combate. Todo `%` que no sea un especificador va **doble**: `%%`, o mejor se escribe `abs 7E` y se evita |
| Imprimir en cada cambio, dentro de `registerafter` | **Mide el ruido antes de imprimir.** `$84` tiene tres meanings y si es el acumulador se mueve en CADA frame: 60 lineas por segundo hunden la consola de FBNeo, bajan el framerate, y **una medicion con el framerate caido no sirve**. Por eso `yuyu_knockdiag.lua` solo reporta la salida de `$84` de 0 y con tope de 30 frames por slot. Lo que se imprime sin tope tiene que ser lo que cambia pocas veces: un cambio de estado, un contacto, un cruce |
| "No toques nada mientras se pelea" | **No lo digas asi, se entiende como "no toques el mando".** Los diagnosticos que usan el marcador de boton (yuyu_slots_diag.lua) avisan de eso porque el marcador DISPARA acciones y arruina la Pelea. Uno pasivo como `yuyu_knockdiag.lua` no lee `joypad.get()` en ningun punto: se juega normal, los dos peleadores, y el script mira. Decirlo asi obliga a pensar que hacen falta dos IAs |
| Un test de igualdad que pasa porque no mira nada | **Verificar que el observable es SENSIBLE antes de confiar en el "no cambio".** El primer test de la deteccion de P2 comparaba un conteo de lineas y pasaba igual con y sin el fix. Y la primera autocomprobacion de la firma movia al JUGADOR, y tambien pasaba: `to_screen()` cancela el base **tambien en X**, asi que un jugador en otra posicion del mundo no desplaza sus cajas. La firma tiene que moverse al mover la **CAJA** |
| Comparar conteos para demostrar que algo NO cambia | Un conteo igual no distingue "no cambio" de "cambio y me dio lo mismo". Para invariancia hay que comparar la **geometria completa** (una firma ordenada de las lineas), y varias pruebas de autocomprobacion en el mismo test |
| Un offset es un campo | **A veces son tres.** `$84` es velocidad de empujon en el resolver (`$1F4E2`), un **timer que cuenta hacia abajo** en la maquina de estados (`$1A28E`, con salida en `< 1`) y un acumulador contra 256 (`$1BCB0`). Tiene 13 accesos. Mientras no se listen los tres, cualquier lectura de `$84` mezcla los tres |
| El backflip es lo que pasa tras un agarre | **No.** El agarre manda al rival al aire en un estado de caida en el que se puede seguir golpeando con suaves, pero al aterrizar el resultado es identico a una caida total y necesita levantarse. Eso **no** es backflip. El backflip sale **solo, al agotarse la ventana de golpes suaves**: es el fin del hitstun en el aire, contra el fin del hitstun en el suelo. Armar la medicion esperando un backflip post-agarre es perder el tiempo |
| `registerafter` sirve para leer lo que pasa dentro del frame | **No, y sale carisimo.** Todo lo que cambia al procesar un golpe se lee con `memory.registerexec` en el punto exacto. La primera version de `yuyu_knockdiag.lua` leia en `registerafter` y produjo 7600 frames con **cero** `CONTACTO` y un parpadeo de "se fue la hurtbox" cada ~3 frames. **El sintoma del muestreo en el momento equivocado es el parpadeo SIMULTANEO en los dos peleadores**: la invulnerabilidad de a uno no puede depender de la del otro |
| Los contadores de cajas los borra el resolver | **Los borra el dispatcher, DESPUES de los resolvers.** `loc_01EDAC` corre grab/clash/hit/push y recien en `$1EDC2` pone en 0 los cinco. Ademas tiene guardia de entrada: `btst.b #$7, $f550.w` / `bne.b $1ee1c`, y si esta busy **no borra nada**. Por eso hay frames sin dispatcher, y en esos hay que saltarse el frame entero: comparar una captura vieja contra datos nuevos inventa transiciones |
| Un `;` sirve de comentario de cola en Lua | **No.** El `;` es separador de sentencias, no de comentarios: `local x = 1 ; del hook` parsea `del` como sentencia y tira `'=' expected near ...`. Para comentar en cola va `--` |
| El hook va en el punto "ideal" de la rutina | **El punto ideal suele estar despues de una guarda.** `loc_01EDAC` arranca con `btst.b #$7, $f550.w` / `bne.b $1ee1c`, y `$1EE1C` es **un rts**: si el bit esta activo la rutina no hace nada. Un hook en `$01EDC2` (que es donde los contadores siguen vivos y `$69` ya fue puesto) **no se ejecuta nunca** en esos frames. **Se engancha en la ENTRADA, que siempre se alcanza** |
| Un campo "se escribe cada frame" queda afuera como gate | **Es una confusion de alcance.** Se escribio que el HP no podia servir de gate para "¿estamos en pelea?" porque `0x12AE6` y `0x13688` lo escriben cada frame con `#$FF`. MEDIDO 08-10: **es FALSO, y el HP vuelve a 0 al terminar**. Y aunque se escribiera cada frame, no diria nada de un gate, porque **el gate tambien se lee cada frame**. Lo unico que importa es si el VALOR distingue dentro de la pelea de fuera, y resulta que si. El gate real es **"¿alguno de los 4 slots tiene HP > 0?"**, con los tres descartados a la vista en `DATOS_VERIFICADOS.md` §5f. **Y `!= 0` NO alcanza:** el menu conserva el centinela `-1024` (`$FC00`), MEDIDO |
| Un `!= 0` donde hacía falta `> 0` | **El centinela del juego rompe la igualdad.** `$78` va a `-1024` al terminar y el slot **lo conserva en el menu** (MEDIDO 08-10, frame 3997: `hp=0/0/0/-1024`). `!= 0` cuenta el menu como pelea. Y hay frames de pelea con HP **negativo** (`-7`, `-16`, `-22`), que con `> 0` no cuentan |
| El escenario de un banco tiene que estar en la situación que el script mide | **Con el gate puesto, el banco entero daba 33 fallos**, porque los cuatro slots con HP 0 son "no hay pelea". Y ese numero es justamente lo que hay que mirar: **prueba que el gate es SENSIBLE**. Un gate sin efecto, o que solo tocara una cosa, habria dado verde. Por eso `entrar_en_pelea()` esta en el escenario base del banco, no en cada prueba |
| Un gate que no se puede romper no está verificado | **Cinco mutaciones.** `> 0` -> `>= 0`, `~= 0` y `> -32768` dan 4 fallos cada una; gatear solo el dibujado y no la simulación da 1. Y una quinta, **gatear solo la simulación, da 0 fallos y es EQUIVALENTE**: si las gotas mueren no hay nada que dibujar. **Un caso equivalente hay que decirlo, no esconderlo**: una mutación que no falla no es una mutación que el banco no ve |
| "No se dibuja" y "no hay gotas" son la misma afirmación | **No.** Un gate que se limitara a no dibujar deja las gotas **colgadas en el aire**, y al arrancar la pelea siguiente aparecen todas de golpe donde las congelo. Por eso `__yuyu_test` expone `vivas_por_capa()` ademas de `en_pelea()`, y el banco mira el **pool** (que es un local), no solo la salida |
| Un `.lua` que enciende la sonda **apagada de fabrica** deja el banco en verde por vacuidad | **La sonda de `LLUVIA DIAGONAL.LUA` esta en `SONDA = (_G.__yuyu_test ~= nil)`**, no en un `false` a mano: apagada de fabrica para el emulador, encendida para el banco, que pone `_G.__yuyu_test` **antes** del `dofile`. Con un `false` fijo, las pruebas de "avisa al cambiar" y de "dice la verdad" pasarian por la razon equivocada: no estaria mirando nada |
| Un campo que se mueve cada frame dentro del filtro de una sonda | **La ahoga.** `stageX` (`$FFA014`, la base del stage) se mueve en CADA frame durante la pelea: con el en el texto comparado, la sonda del 08-10 tiro mas de mil lineas y **con el framerate caido, que es justo lo que hace inutil una medicion**. Se sigue leyendo y se imprime detras de la barra, que solo aparece cuando algo MAS cambio. **Y `vivas` (cuantas gotas hay en el pool) tampoco puede ir en el filtro**: el pool se renueva solo (una gota muere, otra nace) y da `43, 42, 39, 41...`, o sea una linea cada dos o tres frames |
| El ciclo pedido `-1024 -> 0 -> 223` | **El ciclo se cumple, pero `223` no es el disparador.** La regla mira `> 0`. Si preguntara "¿HP == 223?" la lluvia se apagaria en el PRIMER golpe, porque el HP baja a 222 de inmediato y no vuelve a 223 hasta la ronda siguiente. MEDIDO: en la pelea 2 el P1 paso por 223, 200, 147, 5, -5 y -1024 en un solo round |
| `HP > 0` significa "vivo" | **NO. Significa "vivo Y con vida".** MEDIDO por el usuario: *"la CPU tenia 0 de vida, le lance un ataque especial, lo bloqueo, no murio, y las gotas se detuvieron"*. En este juego **se muere cuando la vida baja DE 0**, asi que un peleador en **exactamente 0 sigue peleando**. Un gate con `> 0` lo apaga como si fuera un cadaver. Y `>= 0` tampoco: en el menu los cuatro slots estan en 0. El gate real es **"2+ slots con `HP > 0`, o 1 vivo y NINGUN slot con `HP < 0`"**, y `HP < 0` como "muerto" **esta sin medir** (el unico escritor negativo del ROM es `0x1A1A4`, el centinela `-1024` de fin de pelea) |
| Un campo "no vale cero" alcanza como gate | **Y hay que decidir CUANTOS hacen falta.** El gate arranco con "¿alguno de los 4 slots tiene HP > 0?" (987 frames de lluvia despues del KO) y paso a "2 o mas" (se apagaba con un peleador vivo en 0). **Cada medicion mato una regla y las dos estaban a medio camino.** Ver `DATOS_VERIFICADOS.md` §5f |
| Un `print` de error que avisa UNA vez no sirve | **El error de un callback se traga, y el sintoma es el overlay CONGELADO, que es identico a "no se esta dibujando".** En `LLUVIA DIAGONAL.LUA` el cuerpo del frame va en `un_frame` envuelto en un `pcall` que **avisa CADA frame que falla**, con el numero y el frame en que empezo, y limpia los bytes > 127 del mensaje (la consola los muestra como dos caracteres). **Un flag de "ya lo dije" no alcanza**: si el error arranca en el frame 3000, el aviso queda enterrado. Y `un_frame` se **asigna** con `un_frame = function()` y no con `local function`, o el `registerafter` ve un nil y el `pcall` se come el error: el bloque que avisa errores es el que se queda mudo |
| Una excepcion dentro de un callback se ve como un error | **No: se traga.** El sintoma es "el script corre, imprime su mensaje de arranque, y no dice mas", o peor: **el overlay con el ultimo frame dibujado**. Con el gate apagado las gotas se matan Y no se dibujan (dos cosas, ambas verificadas), asi que **si quedan visibles, el gate no es la explicacion**: hay que mirar si el callback llego a `draw_lluvia`. Probado en el banco rompiendo `gui.drawline` desde adentro — reemplazar el `frame_cb` entero NO sirve, porque el `pcall` del script ni se ejecuta |
| "Esta capa esta oculta" | **Oculta = invisible, y si se ve NO esta oculta.** El sintoma era ver lineas verticales palidas sobre la imagen del juego en los menus. La hipotesis "el stage ya esta calculado pero en capas inferiores" se parte en dos: que el stage **no esta congelado** si se puede medir (`$FFA014` avanza en el menu, y `$8C` se sigue escribiendo), pero **"oculto" implicaria que no se veria, y se ve**. Se dibuja y la UI lo tapa encima en parte. El mecanismo exacto (capa del VDP desactivada vs. tapada) **no se puede responder con un script pasivo**: leer los registros del VDP exige escribir el indice en `$C00004` y leer de `$C00000`, o sea el bus del Z80, y eso rompe la regla 5 |
| Los registros del VDP se leen con `memory.readbyte` | **No, y no se pueden leer en FBNeo.** En Genesis hay que **escribir** el numero de registro en `$C00004` y leer el valor de `$C00000`: es el bus del Z80. O sea, requiere una escritura en la memoria del juego, que la regla 5 prohibe. El unico script del repo que lo hacia (`_disasm_tools/lua/vdpinfo.lua`) es de BizHawk (`write_u16_be`, bus "M68K BUS") y tiene una ruta quemada a `C:\Users\leand\...`: no se porta |
| Un bloque insertado con la herramienta de edicion queda UNA vez | **No siempre.** Al meter el `pcall` del callback se quedó **DOS** `emu.registerafter` completos: el nuevo (con el `pcall` y el aviso) y el viejo entero debajo. `luajit -bl` limpio, **171 pruebas en verde**, y dos callbacks registrando la misma funcion por frame. **Ninguna prueba del banco detecta un `registerafter` de mas**, porque las dos instalaciones dan el mismo comportamiento visible. La unica forma de verlo es contar: `Select-String "emu\.registerafter"` tiene que dar **1**, y `un_frame = function` tambien |
| Un fallo que solo se ve en la consola | **Y la consola esta en otra ventana.** El sintoma de un callback muerto es el overlay congelado, que es lo mas dificil de ver solo, y el aviso unico estaba en la consola que hay que ir a buscar. Ahora ademas dibuja una **barra roja en pantalla**, y va **fuera del `pcall`**: es el unico aviso que sobrevive a un frame muerto. En coordenadas de VENTANA, no de juego, porque tiene que aparecer pase lo que pase con el margen |
| La trampa del local declarado tarde, al revés: declarado DOS VECES | **Peor que la original, y mas barata.** Un segundo `local gotas_dibujadas` junto a `draw_lluvia` creo un local que **tapa** al de arriba: el contador se escribia en un lado y el latido leia el otro, asi que daba **0 siempre**, sin error, con `luajit -bl` limpio y **168 pruebas en verde**. **La forma de cazarla: que un numero que deberia ser distinto de 0 sea SIEMPRE 0, y no un error.** Y la defensa: el banco exige las dos mitades —`gotas(1)`, las lineas medidas por el mock de `gui`, y `YUYU_TEST.gotas_dibujadas()`, el contador del script— porque **un `0` solo no distingue "no hay lluvia" de "el contador esta roto"** |
| "Eso que se ve es del juego" | **Se escribe como dato y es una suposición: pasa.** Con el sintoma de las "gotas congeladas" se afirmo que eran **la lluvia del stage**, y el usuario contesto que **el juego no tiene ningun escenario con lluvia**. No habia ningun dato: era la explicacion que cerraba el sintoma, escrita con el tono de un hecho. **MEDIDO de verdad: `lluvia = 0` en las 11 lineas del menu**, o sea que el script no dibuja ni una gota ahi, y el sintoma es de la **superficie de `gui.*` de FBNeo**, que no se limpia cuando el script no dibuja nada (cerrar y reabrir la ventana de Lua en el menu lo borra) |
| Un `if` que no dibuja nada visible, "no dibuja nada" | **En FBNeo no: no dibujar es una decision. [MEDIDO 08-10]** Con el gate apagado el script dibuja 0 gotas, y las gotas quedaban congeladas en pantalla hasta el combate siguiente, porque **la superficie de `gui.*` no se limpia si el script no emite ninguna llamada**. FBNeo **limpia al PRESENCIAR** el overlay (resuelto por medicion: el pixel invisible con alfa 0 lo arreglo), asi que **el arreglo es que TODO frame emita al menos una llamada**, aunque no se vea nada: `if gotas_dibujadas == 0 then gui.drawline(0,0,0,0, color(0,0,0,0)) end`. Sin eso habia que dibujar el fondo a mano. Y el banco tiene que distinguir **`0` lineas de `0` llamadas**, que son cosas distintas |
| Un test de apagar el efecto sirve para descartar que el efecto dibuje | **No, si el sintoma es "QUEDA algo en pantalla".** Se pidio apagar las tres capas de lluvia para probar que las gotas congeladas no eran del script, y **con `lluvia = 0` el script no dibuja nada, asi que apagarlas tampoco borra nada**: el test no distingue. **Un test de "apagar" solo vale cuando lo que se ve esta siendo dibujado AHORA.** Para "algo quedo pegado" hay que medir primero si algo se dibuja |
| Dos cosas en pantalla se separan a ojo | **No, se separan con un numero.** El sintoma "las gotas quedan congeladas y visibles" se discutio entre el script y el stage durante varias corridas, y **las dos partes tenían razon sobre lo que veian**: las lineas del overlay y las del stage se parecen. Lo que lo cierra es `lluvia=N` en el latido: si en el menu dice 0, el script no dibuja una sola gota, y la pantalla no lo discute. **Es un entero en una linea que ya se imprimia, no una sonda nueva** |
| Un argumento de que algo "no puede pasar" no es una prueba | **Es una opinion hasta que el banco la mira en el frame exacto.** El sintoma era "gotas de lluvia dibujadas pero congeladas". El argumento: con el gate apagado se matan y no se dibujan, las dos cosas en el mismo frame, y solo hay un `gui.drawline` de lluvia en todo el script. **La prueba que lo convierte en dato son dos asserts en el PRIMER frame del apagado** (`gotas(1) == 0` y `vivas_totales() == 0`), no en una ventana de 20 frames |
| Un `.lua` de Fightcade con mas de 200 locals | **Falla al CARGAR, y el error no menciona la linea.** `test_hitbox_hud.lua` esta al limite: agregar dos `local` al bloque de una prueba lo deja en `main function has more than 200 local variables`, sin decir donde. **La salida es que el helper va en el `.lua` del script** (`_G.__yuyu_test.vivas_totales()`), no como local del banco |
| El banco "esta en el limite": cuanto margen le queda, CERO | **Medido: esta en 200 exactos.** Se comprobo metiendo `local ZZ1 = 1` en un temporal y pasando `luajit -bl`: **un solo local extra ya lo rechaza**. Hoy el margen son **2**, y se reservaron para la seccion 9z. **La segunda salida, cuando no entran locales, es la TABLA de `__yuyu_test`: guardar ahi no consume ninguno** (`YUYU_TEST.m9z_pre = { ... }`). Y la tercera es **quitar locals duplicados**: `HB`/`HB2` eran las dos `0xFFA400` y `Pu`/`P2B` las dos `0xFFA500` |
| Un grep que mira la declaracion y los dos primeros usos NO es un grep completo | **Porque hay que contar, no leer.** Al buscar `X_CORTO_A` con `-AllMatches` daba **4** ocurrencias y yo habia encontrado **3** (la declaracion y dos bucles): la cuarta estaba en un bloque 50 lineas mas abajo, y el banco revento con `attempt to compare nil with number`. **Un conteo que no se compara con el numero de usos que se tocaron es un conteo que no se leyo** |
| Un gate que es un INFERIDO puede cortar una animacion | **No: solo puede encenderla.** Preguntar "¿queda alguien en pie?" no es preguntar "¿termino el round?", y por ahi salio el bug de **987 frames de lluvia despues del KO**: el gate apagaba cuando el segundo peleador bajaba de vivo. **Lo que apaga una animacion tiene que ser un dato que CUENTE FRAMES HACIA ATRAS**, y ese dato existe: `$F558`, la cuenta regresiva del slow-mo de muerte (159 -> 0, MEDIDO 08-10). En `LLUVIA DIAGONAL.LUA` el gate de HP quedo **solo como encendido** y el corte lo lleva `$F558`. Ver `DATOS_VERIFICADOS.md` §5f |
| El slow-mo del JUEGO frena el overlay de LUA | **No, y por eso hay que bajarlo a mano.** El overlay lo dibuja el host a velocidad de host: `emu.registerafter` dispara una vez por frame emulado pase lo que pase dentro del juego, asi que la camara lenta del juego no lo toca. Por eso "la lluvia baja a la mitad durante el slow-mo" es **una multiplicacion nuestra** (`MULT_SLOWMO`), no un efecto que venga gratis. Y el refresco se sigue solo: como `$F558` se rearma a 160 en cada golpe a un cadaver (**MEDIDO: 9 veces en 320 frames, una cada 40**), el slow-mo llega a **479 frames en vez de 160**, y un contador propio del script no daria ese numero |
| Una asercion que lee la constante DEL SCRIPT mide el requisito | **Mide consistencia, y aca fue una trampa real.** La duracion de la cola se comprobaba contando frames con `max_lineas(YUYU_TEST.COLA_FRAMES() - 2)`: cambiar `COLA_FRAMES` a 119 o a 121 en el `.lua` **movia las dos manos de la balanza** y dejaba las 204 pruebas en VERDE (comprobado por mutacion). **Un requisito va contra un numero fijo escrito en el test** (`max_lineas(120 - 2)`) **y APARTE un `eq` que ata el valor del script** (`eq("...", YUYU_TEST.COLA_FRAMES(), 120)`). Es la misma fila de las aserciones auto-confirmantes, pero con el caso concreto |
| Mirar UNA capa para probar un efecto que se aplica a TRES | **Es medir un trozo, y el banco lo daba en VERDE.** Aplicar el multiplicador del slow-mo **solo a la capa 1** no rompia nada de lo que se comprobaba, porque la prueba de velocidad miraba la capa 1. Ahora mide las tres en un bucle, con las tres Y en la tabla de `__yuyu_test`. Y el conteo arranca en **-1** para "no se pudo medir": **poner un `0` a proposito seria la prueba que vale 0 y 0** |
| Una mutacion que no falla hay que decir que es equivalente, PERO hay que re-contar antes | **Y el recuento de ahi es donde estaba el bug.** Se corrigio `<= 0` por `< 1` en la cuenta de la cola creyendo que la cola duraba `COLA_FRAMES - 1`; la cuenta bien da **exactamente `COLA_FRAMES` frames de lluvia**, y las dos escrituras son **equivalentes** (comprobado: las 204 pruebas en verde con las dos). O sea: el off-by-one era **amenazante y no real**, y la "correccion" era un no-op con un comentario que afirmaba un bug inexistente. **La mutacion equivalente tambien se documenta**, en el `.lua` y en el banco |
| `a, b = 1, 2` DENTRO de un constructor de tabla NO asigna `a` ni `b` | **Solo se lleva el ULTIMO nombre, y lo demas son entradas de ARRAY.** `{ xa, xb = 3, 13 }` es `{ nil, nil, xb = 3, <cuarto> = 13 }`: `xa` queda NIL y el `13` se va a la posicion 4. **El sintoma es `attempt to compare nil with number` en la primera asercion que use el campo**, muy lejos de donde esta el error, y `luajit -bl` lo pasa limpio. La forma correcta es un `=` por nombre: `{ xa = 3, xb = 13, ... }`. Salio al parametrizar las franjas de X del banco |
| Un banco que se parametriza entre DOS scripts tiene que decirlo, y decir que numeros mira | **El banco tiene un solo juego de expectativas y dos `.lua` que ya no tienen la misma lluvia**: la RECTA esta congelada y la DIAGONAL cambio stock, duracion y alturas. Con un solo juego de numeros solo se puede probar una de las dos, y **la que "no" se prueba no falla: falla la otra y parece un bug del cambio.** El arreglo es una tabla de expectativas por script, elegida con `$env:SCRIPT`, **GLOBAL porque el banco esta en el tope duro de los 200 locals**. Y los numeros van **escritos a mano por script**, no ledos de `__yuyu_test`: leerlos seria una asercion auto-confirmante |
| Subir el `n` de una capa mueve las franjas de X que el banco usa para identificarla | **Y el banco se rompe sin que se vea por que.** El grupo del parpadeo se identifica por la X porque dentro de un panel del HUD la gota se recorta y su alto dibujado deja de ser el del pool. Las franjas salen de `paso_x = emu.screenwidth() / n` con un jitter del 30 %, asi que **cambiar `n` las mueve**: con `n = 20` el paso es 16 y las franjas son 3..13 y 19..29; con `n = 22` el paso es 14,5 y son 2..12 y 17..27. Y ojo: **con paso 14,5 la mitad de las franjas intermedias cae dentro de los paneles (39..136 y 183..281)**, o sea que solo las dos de los extremos siguen sirviendo |
| Un numero que el banco no afirma es un numero sin verificar | **Y se nota por mutacion, no leyendo.** El banco comprobaba stock, altos y lineas dibujadas, pero **no afirmaba ninguna duracion**: cambiar H.Rain de 39 a 40 frames dejo las 204 pruebas en VERDE, porque nada de lo que el banco cuenta depende del `dur`. Ese `dur` es la velocidad, o sea la mitad de lo que se estaba afinando. Ahora se afirma contra `ESP.durs`, escrito a mano, con `dur_por_capa()` expuesto por el script. **La leccion es el orden: mutar primero, y preguntarse que NO mira el banco** |
| La regla documentada de un reparto puede no ser la que lo genero | **Y hay que comprobarla antes de generar el siguiente.** La regla de `largos` es "juntar las series por su posicion proporcional `(k + 0,5) / cantidad`": con las dos series iguales de B.Rain reproduce la lista **exacto**, y con las tres series de C.Rain (6/4/3) **no coincide** (la lista real es `3,5,3,7,3,5,7,3,5,3,7,5,3` y la regla da `3,5,7,3,5,3,7,3,5,3,7,5,3`: difieren en la posicion 3). O sea que la lista de C.Rain esta hecha a mano. La nueva de 16 se construyo **mapeando la real 1 a 1** (3→3, 5→4, 7→6) y agregando 3 entradas al final, para no cambiar el ritmo sin querer |
| El snapshot de una transición se mide en una ventana, no en el frame | **Para "desaparece de golpe" hay que mirar EL frame.** Una ventana de 20 frames deja pasar el frame en que ocurre la transicion, y ademas permite que algo se recupere despues. La prueba del congelado mira el primer frame con el gate apagado |
| Una excepcion dentro de un callback se ve como un error | **No: se traga.** El sintoma es "el script corre, imprime su mensaje de arranque, y no dice mas", o peor: **el overlay con el ultimo frame dibujado**. Con el gate apagado las gotas se matan Y no se dibujan (dos cosas, ambas verificadas), asi que **si quedan visibles, el gate no es la explicacion**: hay que mirar si el callback llego a `draw_lluvia`. Probado en el banco rompiendo `gui.drawline` desde adentro — reemplazar el `frame_cb` entero NO sirve, porque el `pcall` del script ni se ejecuta |
| Un sintoma raro en el emulador es del script | **No siempre, y la medicion lo dice en una linea.** El 08-10 se reportaron "gotas de lluvia congeladas y visibles en los menus". La sonda dio **`enpelea=0 vivas=0` en los 11 frames de menu, y `enpelea=0 vivas>0` en ninguno**. Como `draw_lluvia` solo dibuja cuando `p.viva`, con las 43 gotas en `false` **el script no puede dibujar ni una linea**: no es que "parezca" apagada. **Lo que se ve es la lluvia del PROPIO JUEGO**, que es un layer de fondo del stage y queda congelado al cambiar de pantalla. **Antes de horas buscando un bug de dibujado, medir el ESTADO del pool** |
| Un sintoma que el banco da por imposible | **Recargar primero: una instancia COMPILADA no recarga.** Editar el `.lua` en disco no cambia nada en la ventana de Lua de Fightcade, y el sintoma es un comportamiento viejo que "no me arreglo". Por eso el arranque imprime **`[yuyu] GATE DE PELEA = SI/NO`**: es lo unico que distingue en consola a la DIAGONAL de la RECTA (las dos imprimen identico todo lo demas, porque las dos copias tienen las mismas tres capas) y dice si el gate esta compilado adentro del archivo que esta corriendo. **Antes de culpar a un gate, confirmar que el gate esta** |
| Un diagnóstico se queda en el script después de cerrado | **No.** La sonda de "¿estamos en pelea?" de `LLUVIA DIAGONAL.LUA` se borro cuando el gate se cerro: 130 lineas de codigo, 18 de pruebas en el banco, y las declaraciones adelantadas de `LLUVIA_DEF` / `lluvia` que habia que mantener **sin `local` por culpa de ella**. Todo eso era andamiaje de medicion, no del efecto, asi que se va con el diagnostico. **Lo que se queda es el DATO**, en el comentario del gate y en `DATOS_VERIFICADOS.md`: la medicion no se tira, cambia de lugar. Y lo que se queda del banco es lo que prueba el **comportamiento** (`max_lineas(20) == 0` sin pelea, `> 0` con pelea, el ciclo `-1024 -> 0 -> 223`), no lo que contaba lineas de una sonda |
| Un diagnóstico carga el mismo flag de debug con su valor por defecto | **El flag se va con el.** Con la sonda borrada, `SONDA` desaparecio, y con ella el banner que decia si estaba encendida. Lo que queda del banner es lo que sirve de verdad: `GATE DE PELEA = SI/NO`, que distingue en consola a la DIAGONAL de la RECTA (las dos imprimen identico todo lo demas) |
| `$F558` se pone a 160 UNA vez, al morir | **Se rearma en CADA golpe a un peleador ya muerto.** MEDIDO 08-10: con el enemigo en `-5`, `-13`, `-18`, `-22`, `-27`, `-36`, `-44`, `-51`, `-58`, cada golpe suyo **vuelve a poner `$F558` en 160** en el MISMO frame en que el HP cambia: **9 veces en 320 frames**, una cada 40. O sea que el disparador es **"le pegaron a alguien con HP negativo"**, no "el peleador murio". ***No se confirmo que sea el mismo `0x1FA82` el que reaplica***. Ver `DATOS_VERIFICADOS.md` §5f. **Y por eso el gate de pelea tiene que ser `> 0`**: un slot muerto sigue recibiendo golpes y sigue con HP negativo y **variable**, no con un centinela fijo |
| Un hook que no dispara se nota como un error | **No: se calla.** El sintoma es "el script corre, imprime su mensaje de arranque, y no dice mas". Ni error ni excepcion. Por eso cualquier hook lleva **latido**: una linea cada 600 frames con cuantas veces entro, y un AVISO si hace falta que no entro. Sin eso, un hook mal puesto cuesta una ronda entera enterarse |
| Registrar el hook UNA vez al cargar es suficiente | **NO. FBNeo BORRA los hooks exec en cada reset del juego.** Si el script se cargo antes de que arrancara la partida, el hook se perdio y no volvia: la corrida dio `invocaciones=0` en los tres primeros avisos de 600 frames. **Hay que re-armarlo CADA FRAME**, que es idempotente. **La razon estaba escrita en el `LLUVIA RECTA.LUA`**, en el comentario de `arm_hook()`, y no se leyo antes de escribir el segundo script que hookea |
| Cuando algo falla dos veces, la respuesta esta en el repo | **A veces, y hay que buscarla antes de volver a medir.** Los dos fallos del hook —`$01EDC2` en vez de la entrada, y armar-una-vez en vez de cada frame— estaban los dos explicados en el HUD, que es el unico script de este repo que hookea bien. Se reescribio el mecanismo tres veces desde cero antes de leer el comentario que lo resolvia |
| Poner un hook "en el mejor momento" del frame | El momento incluye las **guardas**. Antes de elegir un PC, leer las 3 o 4 lineas de entrada de la rutina y preguntar: ¿este PC se alcanza en TODOS los caminos? |
| Editar el `.lua` en disco recarga el script | **NO.** La ventana de Lua de Fightcade tiene una **instancia compilada**: el archivo cambia en disco y el script sigue siendo el viejo, sin decir nada. Hay que **cerrar la ventana y volver a abrir el `.lua`**. Esto es distinto de "hay cambios que hacer durante la corrida": para una medicion no hay cambios, pero despues de que yo edite el archivo, el reload es obligatorio |
| Una excepcion dentro de un callback se ve como un error | **No: se traga.** En este emulador una excepcion en un hook deja el flag de captura en `false`, el callback de frame sale por su rama de "no tengo datos", y el script queda **mudo sin una sola palabra**. Por eso: `pcall` alrededor del cuerpo del hook, y un flag propio `g_error_dicho` para avisar **una vez**. Ojo: `if g_hooks == 2` no sirve, porque si el error arranca en el frame 3000 no lo dice nunca. **Ademas hay que guardar el mensaje del `pcall`** (`local ok, err = pcall(...)`) y no solo un booleano: sin el texto, el flag dice "hubo un error" y no cual |
| Una maquina de estados pregunta "¿el valor es el maximo?" | **No si el valor DECREMENTA.** La firma del stop time es `$69 = 255`, pero al frame siguiente vale 254: preguntar "¿`$69 == 255`?" es cierto **un solo frame** y hace parecer que el ult dura 1. La maxima marca el **arranque** y despues hay que seguir la **secuencia**: si baja de a uno (`0x12B36`) sigue; si llega a 0 viniendo de 1 se completo; cualquier otra cosa es que el resolver **sobrescribio** el byte. **El test lo caza**: "sigue en el ult en el frame 255" falla con la version ingenua |
| Los especificadores de un `string.format` se estiman a ojo | **No: se cuentan.** `"$59=%d (debe ser %d)"` son **DOS** especificadores, no uno. Una linea con 5 pares mas un `%s` tiene 7, y por 6 argumentos revienta con `bad argument #7 to 'format'`. Como el error lo traga el `pcall` del callback, el sintoma es "el script se calla en el frame del ult" y no un error visible |
| Silenciar `_G.print` en el test y olvidar restaurarlo | **El banco entero se queda mudo.** Los `FALLA` de `ok()`/`eq()` se tragan en el mismo print silenciado que se puso para callar el arranque, y el resumen dice *cuantas* faltaron sin decir *cuales*. **Restaurarlo en la linea siguiente al `dofile`**, con un comentario que diga por que |
| Un grep de un nombre de usuario da un falso positivo en castellano | **Si el nombre es una palabra comun.** Buscar `leand` (la ruta quemada de `C:\Users\leand\`) matchea **"pe*leand*o"**, y hacia pensar que habia una ruta absoluta donde no la hay. **Mirar el contexto de la coincidencia, no el numero** |
| Un test mide lo que el script IMPRIME | **Mide lo que el script CALCULA.** El banco captura las lineas para el latido y para "el arranque se avisa", pero las asserts de verdad van contra `estado()` y `regla_6e()`, no contra texto. Comparar texto obliga a que el wording no cambie nunca |
| Una asercion escrita con la constante DEL SCRIPT mide el requisito | **Mide consistencia.** `eq("el fondo mide...", fondo.ancho, 5*esc*2+esc+2*OK.margen()+1)` con `esc = OK.escala()` **pasa con cualquier escala**: las dos sides se mueven juntas. **Se comprobo con TRES mutaciones que daban verde:** `ESCALA_OK` a 1 (cartel de 5x7, ilegible), `MARGEN_OK` a 0 y `OK_FRAMES` a 5. Las tres tienen que fallar. **Un requisito va contra un numero fijo** (`esc == 9`, `margen == 14`) **y aparte un minimo**, porque el fijo te dice que cambio y el minimo te protege si el fijo se mueve |
| El test tiene que avanzar el reloj del juego, no solo su memoria | **Un campo que DECREMENTA en el juego y se queda quieto en el test miente entero.** Con `$69 = 255` estatico, la maquina de estados ve "no bajo de a uno", lo toma como impacto, cierra el ult, y al frame siguiente ve 255 y lo reabre: **el cartel se rearma cada dos frames y la prueba de la DURACION mide eso.** El banco tiene `tick_descendente()` que reproduce `0x12B36`; sin el, la prueba falla por el motivo equivocado |
| Dos mascaras en el mismo resolver son la misma variable | **No, y despues se comprobo al reves.** En `0x1F31C` el AND es de `$64(a3) & $0C` (con `$63(a4)`) y decide el **daño**; en `0x1F330` es de `$64(a3) & $3` y decide el **empuje**, y `$63` no participa. De ahi se concluyo que "son dos variables de distinta naturaleza". **La medicion del usuario despues lo desmintio: es UNA sola variable, el FRAME ACTIVO que conecta**, que trae su `$65` (daño) y su `$64` (empuje) del mismo registro de 8 bytes. **Conclusion sacada solo del resolutor, sin contraste con el dato medido** |
| Una propiedad aritmetica de un code path es la medicion | **No, y esta es la que mas caro salio.** Redactamos "el mismo golpe da hasta 4x de daño" tomando el `$65/4 + 1` del camino reducido y el `sub.w $65` del completo, y locileamos como si fuera la variabilidad observada. **El usuario midio un B de 5 a 8 y un combo de 71 a 86: un 20-60 %, nunca 2x.** Y la aritmetica misma lo desmentia: para `$65` = 8 el camino reducido daria **3**, y el minimo medido es **5**. **Antes de escribir un factor como efecto, comprobar que el valor que predice cae dentro del rango medido** |
| La variacion de daño y la de empuje son dos fenomenos | **Una sola eleccion.** `$65`, `$66` y `$64` se leen con `(a2)+` del mismo registro de frame activo (`0x1EC0E`-`0x1EC16`). Que conecte el frame A o el B cambia el daño **y** el empuje a la vez, y por eso el usuario los vio variar juntos. La unica forma de separarlos es leer los tres en el frame del impacto |
| El escalado por combo explica la diferencia entre combos | **No existe escalado.** El camino completo resta `$65` crudo (`0x1F420`-`0x1F424`): sin multiplicador, y sin mirar `$C6` (que se incrementa en `0x1F9F0`, o sea DESPUES del golpe). El ~20 % de diferencia entre dos combos sale de que los frames activos que conectaron fueron distintos, no de prorrateo |
| Una variacion que cruza savestates y emuladores es RNG | **Puede ser timing.** Un savestate fija el mundo pero **no la fase de la animacion en el instante del contacto**. Un frame de diferencia en cuando conecta el golpe ya cambia el estado del defensor (`$63`) y/o el frame activo del atacante (`$64`). **Antes de buscar un RNG, buscar el frame de contacto** |
| La mitad "alta" de un campo 16.16 es la posicion | **Es la fraccion.** `$40/$42` y `$44/$46` son 16.16 **con la parte entera en la palabra de direccion baja**, y `$42`/`$46` son subpixel. En el ROM **no hay ni un acceso a `$42(a5)` ni a `$46(a5)`**: solo aparecen dentro de accesos largos. **MEDIDO 07-10:** del mismo teletransporte, Y = 314 con fraccion 38400 en el aire y Y = 320 con fraccion 0 en el piso, o sea 6 px de movimiento. El detector tomaba ese cambio por un salto y de 7 teletransportes reportados **5 eran falsos**. Ver `DATOS_VERIFICADOS.md` §3f |
| La calibracion del hitbox HUD aplica a cualquier cosa | **Solo a las CAJAS, que tienen otro ancla que el origen del personaje.** `CAL_X, CAL_Y = -127, -127`prestado a `ITSUKI SET MOVE.LUA` daba **127 px de error en los dos ejes, sin avisar**: con mundo X = 1025 y base `$A014` = 973, `$08` valia **180** y el script imprimia **53**. Y la posicion en pantalla del jugador **ya esta en `$08`/`$0C`**, calculada y CLAMPADA por `loc_0156F0` (`0x15700`-`0x15746`): no hay que recalcularla. El `-8` del HUD es el `subq.w #$8` de `0x15744` |
| Un `print` de diagnostico pegado al latido esta gateado | **Solo si esta DENTRO del `if`.** En Lua lo que cierra el bloque es el `end`, no las columnas: dos lineas de "diagnostico" con la sangria del `if` pero despues del `end` salian **2 lineas por frame** (120 por segundo a 60 Hz). Produjo mas de mil lineas en la corrida del 07-10 y ** bajo el framerate, que es lo que hace inutil la medicion**. El sintoma era "el mana sube +1 cada dos lineas" cuando en realidad era +1 por frame. La prueba cuenta las lineas en una ventana de 121 frames y exige `<= 1`; por eso tambien exige `latido > 121`, para que la ventana siga siendo valida si alguien baja el periodo |
| El ROM hay que leerlo deshaciendo el WORD_SWAP del `.bin` | **No. El archivo ya esta en el orden que ve la 68000.** `_disasm_tools/auditar_moves.py:40` hace `w16(a) = int.from_bytes(rom[a:a+2], "big")` sin deshacer nada, y con eso coincide **1950/1950** contra `LISTA_MOVES.txt`. Con el swap de mas los offsets salian impares (`$8001`, `$6002`) y la tabla daba **337 moves en vez de los 191** documentados. Y `BASE50[6] = 0xCF99A`: el contexto de Itsuki es el **6**, no el 7 |
| Si la autoprueba de la tabla falla, la lectura es ruido | **Puede ser que el dato este adelantado.** El 07-10 `byte(+0)` daba `$10` contra `$5A = $06`, y se concluyo "el ROM no esta expuesto a Lua". **Falso**: leyendo el `.bin`, `$10` es el valor real del registro. Los dos son ciertos, y lo que pasa es que **en ese frame el move no habia arrancado todavia** — por eso el `$5A` es el del estado anterior. Y por el mismo motivo **el `$5F` que se anuncia tambien puede ser el del estado anterior**, no el nuevo. Un aviso de autoprueba obliga a investigar el *momento* de la lectura antes que su *fuente* |
| Tres variantes de una tecnica comparten el registro porque son una | **A veces es que se leyo el frame equivocado.** Los ids **6, 7 y 8** del contexto 6 comparten los bytes `+2..+5` = `08 94 7C 00` y solo difieren en duracion, multiplicador de tabla B y velocidades: la firma de tres variantes. Si las tres salen con el mismo id, sospechar del momento de la lectura antes que de la tabla |
| Un local declarado mas abajo, y arriba se USA | **Septima vez en este proyecto.** Al parametrizar `test_hitbox_hud.lua` con `$env:SCRIPT`, el banner de arriba imprimio `SCRIPT_PROBADO` y la declaracion quedo mas abajo, en el bloque del dofile. Revento con `attempt to concatenate global 'SCRIPT_PROBADO' (a nil value)`. **`luajit -bl` lo pasa limpio**, porque no es error de sintaxis: lo que falta es la variable. Los seis anteriores, con su nombre: `dibujar` en el `.lua` de Itsuki, `f_prueba` y `T` en el banco, `SW`/`SH` en las closures de `_G.emu`, `comandos` y `rastrear`, `anunciar_tecnica`, y `Altos_por_capa` en el HUD. La regla: **lo que se usa dentro de un callback va declarado antes de ese callback** |
| Un banco con el nombre del script escrito a mano | **Con dos copias del mismo script, tiene que poder correr contra las dos.** `test_hitbox_hud.lua` lee el nombre de `$env:SCRIPT`, con `LLUVIA RECTA.LUA` por defecto para que el comando de siempre no cambie, **imprime cual probo** (un banco en verde del archivo equivocado no dice nada) y **sale con error si el nombre no existe**, en vez de caer en la recta en silencio |
| El mock de la API solo tiene lo que el script usaba ayer | **Tiene que parecerse a la API REAL de FBNeo.** La sonda de `LLUVIA DIAGONAL.LUA` llama `emu.framecount()`, el mock no lo tenia, y el banco fallo con `obtenido = 0` en las 141 pruebas: la excepcion se traga dentro del callback y no se dibuja nada. **El sintoma es "todo a cero", no un error.** Un mock es un contrato: si le falta una funcion que existe en el emulador, el proximo script que la use muere igual |
| Un test que comprueba que algo CALLA, no comprueba que diga la verdad | **Faltan los dos.** Los tests de la sonda verificaban que no imprimiera si nada cambia, y con eso dos mutaciones quedaban en verde: una que ponia el contador de hitbox siempre en 0, y otra que lo leia con `rw` en vez de `rb`. Ninguna rompe nada, ninguna avisa de nada, y el ciclo de medicion no sirve para nada. **Un diagnosticador que miente en silencio es peor que uno que no existe**: hay que escribir un valor CONOCIDO en memoria y comprobar que la linea lo repite, con el byte de la izquierda distinto de cero para que `rb` y `rw` no den lo mismo |
| `f()[1]` para tomar el primer valor de retorno | **No funciona.** En una llamada en posicion de prefijo, Lua ajusta la llamada a UN solo valor, asi que lo que queda es un numero, y `[1]` intenta indexar un numero: `attempt to index a number value`. Se asigna a una variable primero |
| Una prueba cuyo valor esperado sale de la funcion que prueba | **Es una prueba auto-confirmante: no puede fallar.** Se escribio `w16($08, CO.crudo(1))` para comprobar que `crudo_de` no aviaba clamp, y con eso el test comparaba `crudo_de` contra si mismo. La version previa ya tenia el bug del `-8` (ver la fila de `loc_0156F0`) y asi que **nunca lo pudo cazar**. El valor esperado tiene que estar **escrito a mano en el test**, con la cuenta de `loc_0156F0` a la vista |
| Un aviso de clamp comparando crudo contra el valor guardado | **Es un SIEMPRE.** `$54` entra en la cuenta de `$08` (`add.w $54(a5), d0` en `0x156FC`) y `loc_0156F0` lo **borra en `0x15718`** justo despues de escribir `$08`: crudo **no puede reproducir `$08` al pixel**. MEDIDO: `$08 = 176` contra crudo `177`. La pregunta correcta no es "difieren" sino **"el crudo se sale de la CAJA"**: X a `[0x40..0x1FF]`, Y a `[0x38..0x1B8]` (el `-8` de `0x15744` ya aplicado) |
| Un estado de `$5F` que aparece poco se lee como un valor fijo | **La duracion depende de la entrada, no del estado.** MEDIDO 07-10: `$0D` duro **1 frame** en una corrida y **5** en otra, con el mismo boton. Y `$02`, que en una corrida aparecio un frame y se tomo por un transitorio, resulto ser el estado de **reposo: 298 frames**. Un solo frame en la ventana de 8 no es evidencia de nada: hay que ver el cambio de verdad (`[$5F]`), no la foto de la secuencia |
| `$5F` identifica la variante de una tecnica | **No necesariamente, y en el teleport no.** MEDIDO 07-10: A, B y C dan **exactamente el mismo `$0D` en la pulsada y el mismo `$A4` vivo**, y el mismo registro `$0CFC72`. Leyendo la secuencia, `$0D` aparece **5 frames antes del boton**: es el estado del comando ↓↑, no la variante. `$A4` es el teleport en curso, comun a las tres. **Cuando una tecnica tiene variantes, el `$5F` no las separa** |
| El script imprime un numero que ya declara no confiable | **Imprimirlo igual es peor que no imprimirlo.** El 07-10 la linea `dano=$0B stun=$87 empuje=$1D` salia un renglon despues de "La lectura NO es de fiar": el que lee la consola se lleva el numero y no el aviso. La autoprueba `byte(+0) == $5A vivo` **gatea** la impresion, no solo el comentario. *** Ojo: el gate es correcto y el diagnostico que se leia era incorrecto (ver la fila del `%X`): gateado != equivocado *** |
| Una tecnica que comparte id y registro con otra se separa por la tabla | **No.** MEDIDO 07-10 con Teleport A/B/C: las tres con `$5F = $08`, registro `$0CFBFA` y los 8 bytes **identicos**. La zona de destino **no esta en los datos del move**: hay que separarlas por DONDE cae el personaje. Por eso el rastreador de `ITSUKI SET MOVE.LUA` correlaciona el salto con la ultima tecnica confirmada por maná y lleva el destino al volcado de MODE |
| Escribir `$42`/`$46` como "la mitad alta" | **No se puede ni escribir**: no son un campo, son la palabra baja de un par. Un `w16($5A, 99)` en el banco tambien escribio `$5A = 0` y `$5B = 99`, porque `w16` es big-endian y 99 = `$0063`; la prueba pasaba por el motivo equivocado. Con `w8` |
| `%s` en un `string.find` es el caracter `%s` | **Es la clase de los ESPACIOS.** `string.find(s, "stun=%s")` no matchea `stun=$2A`: falso negativo silencioso. Para buscar un `%` literal hay que pasar el 4to argumento, `plain = true`. Es la misma familia que el `%7E` que se comia un argumento de `string.format` |
| `%X` con un string "siempre funciona porque son todos digitos" | **Solo si el string es parseable como DECIMAL.** Y el hex de un byte lo es o no segun el valor: `string.format("%02X", "10")` funciona (10 decimal) y `string.format("%02X", hex2(13))` revienta, porque `"0D"` no es un numero. **El banco entero pasaba por suerte**: todos sus valores daban hex parseable (`$08`→`"08"`=8, `$40`→`"40"`=40, `$47`→`"47"`=47), y el id real del juego es `$0D`, que revento el script en ejecucion con `bad argument #2 to 'format'`. **Una prueba que depende del VALOR no encuentra un bug de TIPO.** El banco ahora envuelve `string.format` y chequea que a cada `%d/%i/%X/%x/%f` le llegue un numero; el chequeo es por tipo, asi que caza el `hex2()` aunque el valor del test sea `"00"` y no reviente nada |
| El error de un `%` se ve al correr el test | **No si el valor del test es benigno.** El crash era de ejecucion en FBNeo y el banco daba verde. La regla: cuando un crash del emulador aparece en la salida, la primera pregunta es *que asercion lo habria cazado*, y esa asercion tiene que mirar la FORMA de la llamada, no su resultado |

---

## Herramientas

| Fichero | Que hace |
|---|---|
| `VARIACION_DANOS_HITPAUSE_KNOCKDOWN.md` | **El hilo del golpe, con lo refutado a la vista (07-10-2026).** Mapa frame a frame del B y del backflip, por que `$69` no es hitpause, por que la oscilacion no es desplazamiento, knockdown vs backflip, y **por que el mismo golpe no da siempre lo mismo** (`$65`/`$66`/`$64` son **los tres por frame activo**). Incluye **los 5 errores que cometimos** y los **pendientes priorizados por coherencia**, de mas facil de comprobar a menos probable. **Se lee ADEMAS de `DATOS_VERIFICADOS.md`, no en vez de:** la fuente de verdad sigue siendo el otro, pero un doc que solo guarda lo que quedo bien no sirve para no repetir los pasos en falso |
| `tools/fightcade/yuyu_probe.lua` | Sonda: vuelca struct, camara y cajas en pantalla; imprime cambios en consola |
| `tools/fightcade/LLUVIA RECTA.LUA` | Hitbox display de las 5 listas (borde de 2 px) + rango de agarre + 3 capas de lluvia. Menu de 9 toggles: 4 cajas, filtro P2, 3 capas y "G.LINE" (las guias). **Las cajas APAGADAS de fabrica; las 3 capas de lluvia ENCENDIDAS.** Colores con `color()`, nunca en hexadecimal (ver la seccion de color). Los recuadros del HUD tapan la lluvia de las 3 capas (ver la seccion de zonas del HUD). LAS TRES capas van rectas y mezclan alturas; B.Rain tiene ademas PARPADEO (ver la seccion del largo por gota). **El slot del P2 se DETECTA (`detectar_slots()`), no se supone**, pero eso es inerte para el dibujo: ver la seccion de slots. Verificar con `test_hitbox_hud.lua` (141 pruebas) |
| `tools/fightcade/LLUVIA DIAGONAL.LUA` | **COPIA DE TRABAJO de `LLUVIA RECTA.LUA`, y ya NO es identica: tiene el GATE DE PELEA, el FINAL DE PELEA en cuatro fases, y OTRA LLUVIA.** La lluvia sale **solo durante el combate**. El gate es `en_pelea()` = **"2+ slots con HP > 0, o 1 vivo y NINGUN slot con HP < 0"**, elegido **por medicion** el 08-10 (cada medicion mato una regla anterior): los otros tres candidatos quedaron descartados con el dato delante, en `DATOS_VERIFICADOS.md` §5f. **El gate SOLO enciende; el que apaga es `$F558`**, el timer del slow-mo de MUERTE (`0x1FA82: move.w #$a0`, su unico escritor en todo el ROM), y las cuatro fases son **NORMAL -> SLOW -> COLA -> OFF**: en SLOW la lluvia cae a **la mitad de velocidad** y se sincroniza sola porque `$F558` es la cuenta regresiva (MEDIDO: 159->0, con refrescos que la salvan de 120 a 159, y **479 frames de slow-mo en total, no 160**), en COLA son **120 frames** de lluvia normal **despues del ULTIMO** frame de slow-mo, y despues ya no se dibuja. El latido imprime **`fase=` y `v=`** para poder verlo en la consola. **Supuesto declarado: 1v1.** **La lluvia es la otra: stock 14/22/16, `dur` 39/66/27, y los altos de B.Rain (6 y 9 px) y C.Rain (3, 4 y 6 px) cambiados a ojo por el usuario; el bloque `TECHOS_DE_LLUVIA` explica hasta donde se puede subir cada capa y por que C.Rain ya no tiene aire.** Sigue siendo la version recta en cuanto al `dx` (las tres capas con `dx = 0`): **la sensacion de caida diagonal todavia NO esta escrita**. Verificar con `$env:SCRIPT = "LLUVIA DIAGONAL.LUA"; luajit test_hitbox_hud.lua` (**207 pruebas**). El banco tiene las **expectativas de lluvia por script** en la tabla global `ESP`, porque la RECTA esta congelada con la suya: con un solo juego de numeros solo se probaria una de las dos |
| `tools/fightcade/yuyu_halloffame.lua` | Ventana HALL OF FAME. START 2s abrir, 1 vez cerrar, 3s confeti (que sigue con el menu cerrado). Verificar con `test_halloffame.lua` (20 pruebas) |
| `tools/fightcade/ITSUKI SET MOVE.LUA` | **Diagnostico del STOP TIME de Itsuki** (la unica habilidad que pone `$69 = 255`) **y rastreador de tecnicas.** Verificar con `test_stoptime.lua` (184 pruebas). **El rastreador anuncia una tecnica SOLO cuando se GASTA maná**: la pulsada es una sospecha y el gasto de maná es la confirmacion. Se lee el maná de `$B8` (**no de `$BC`**, que es la barra animada), y **solo se mira que BAJE**: el maná sube por combo y por regeneracion, y ninguno de los dos es una tecnica. Se anuncia el **id de `$5F`**, la **direccion de su registro** (`$50 + word[id] + frame*8`), sus 8 bytes, la **tabla B** (`$8C + byte(reg+1)*4`) y la del golpe (`tabB + word(tabB+2)`). **START** arranca un lote nuevo y **MODE** vuelca la tabla **con la zona de destino de cada variante**. Carga el **CONTEXTO** (`$50` y `$8C`) en el primer anuncio, porque sin el numero no se sabe de que tabla es el registro. **La autoprueba `byte(+0) == $5A vivo` (0x1EB5A) GATEA la impresion de los datos**: si no coinciden, el ROM no esta expuesto bien a Lua, el script lo dice y **no imprime** `dano/stun/empuje` (que serian ruido), pero **publica igual la DIRECCION**, que es lo que hace falta para leerla a mano del `.asm`. Mapea la firma triple de `0x1C032`-`0x1C088`: `$69 = 255` en los enemigos, `$59 == 2` + `$5B == 0` + `$60 != 1` en el lanzador, y **`$6E` del congelado distinto al del lanzador`. **Se AUTOCOMPRUEBA** en las dos direcciones (un slot de otro grupo sin congelar, y uno del mismo grupo congelado). **Y saca un CARTEL GIGANTE que dice "OK"** durante 75 frames. **NO USA exec hook, y es a proposito:** `$69` es un timer que sobrevive frames, asi que `registerafter` alcanza, y asi esquiva el `memory.registerexec` que no dispara en esta build. **El teletransporte se mide sobre `$40`/`$44` (los enteros) y el delta usa el 16.16 COMPLETO**, porque `$42`/`$46` son la fraccion y un cambio ahi es subpixel: tomarlos por un salto daba 5 falsos de 7. El **salto se correlaciona con la ultima tecnica confirmada** y dice cuantos frames pasaron, porque las variantes que comparten id y registro (las tres de Teleport) solo se separan por donde caen. **Todo el latido, incluidas las dos lineas de `max salto` y `maná`, va dentro del `if g_frame % LATIDO`**: fuera de ahi salian 2 lineas por frame. Pasivo: ni una escritura. **El nombre lleva espacios a proposito**; el `dofile` del test lo cita con `"tools/fightcade/ITSUKI SET MOVE.LUA"` |
| `tools/fightcade/yuyu_slots_diag.lua` | **Diagnostico de solo lectura** para dos huecos: que valor de `$58` pone cada habilidad, y que slot esta poblado. Vuelca los 4 slots (`$FF8400`/`$FF8800`/`$FF8C00`/`$FF9000`) con HP, stun, mana, move y `$9E`, y **detecta P2 por HP en vez de suponerlo**. Despues imprime solo los CAMBIOS de `$58`, `$A030`, los 4 canales y `$F809`, con numero de frame. Boton de P1 = marcador `[*]`. Sin escrituras |
| `tools/fightcade/yuyu_knockdiag.lua` | **NO FUNCIONA EN ESTA BUILD — no reintentar sin resolver antes POR QUE.** El exec hook no entra: imprime el arranque y despues `AVISO: el hook de $1EDAC no ha corrido (invocaciones=0)`. Se resolvieron el PC equivocado (`$01EDC2`, detras de la guardia) y el re-armado por frame (FBNeo borra los exec en cada reset) y **no alcanzo**; la pista que queda es que `memory.registerexec` quizas no exista o no dispare en esta build. **Lo que si quedo bien y sirve de modelo:** el **latido** (convierte "no lee nada" en un sintoma con numero), el `pcall` con flag propio (para que una excepcion no se calle), el conteo de hurtboxes **por owner**, y la firma `$84 == (abs 7E + 4) * 16` que **confirma `$1F4E2` sin interpretar nada**. La medicion del backflip se hace **A MANO con el HUD de cajas**. Originally: diagnostico de solo lectura para cerrar el backflip vs knockdown. Mira `$7E` (presupuesto de stun), `$84` (el campo sobrecargado), `$5F` (estado) y `$69` (hitpause) en los 4 slots, e imprime solo los CAMBIOS con numero de frame. **Es autoverificable: CONFIRMA `$1F4E2` cuando `$84 == (abs $7E + 4) * 16`**, que es la unica forma en que ese codigo escribe ese campo, asi que la confirmacion no depende de interpretar nada. Distingue el knockback (un salto desde 0) del timer de `$1A28E` y del acumulador de `$1BCB0`, con **tope de 30 frames por slot** (si `$84` se moviera cada frame, 60 lineas/seg bajan el framerate y arruinan la medicion). Ademas imprime un **indice de estados nuevos**: cada valor de `$5F` se anuncia una vez, con su frame, asi que el volcado ya viene con la lista de candidatos y no hay que reinterpretar 200 lineas. Y lleva el **conteo de hurtbox POR OWNER** (`$FFA400` / `$FFA008`), que es la marca de la invulnerabilidad: imprime el frame exacto en que se va y en que vuelve. Con los tres frames (contacto, hurtbox que se va, cambio de `$5F`) se ve que va primero y por lo tanto que provoca a que. **Todo lo de golpe se lee con `registerexec` en `$01EDAC`, la ENTRADA del dispatcher**, no en `registerafter` ni en `$01EDC2`: `$01EDC2` esta despues de la guardia `btst.b #$7, $f550.w` cuyo destino es un `rts`, asi que hay frames en los que no se ejecuta y el hook se **calla sin error**. Descarta los frames sin captura. Lleva **latido**: una linea cada 600 frames con las invocaciones del hook, y un AVISO si no entra. **Es pasivo de verdad: no lee `joypad.get()`, asi que se juega normal.** Verificar con `test_knockdiag.lua` (41 pruebas) |
| `tools/gen_stun.py` | Generador del informe de stun |
| `_disasm_tools/dump_26.py` | Vuelca los 8 flujos de bytes que indexa `$26` (los que elige `$0A` de 1 a 8, punteros en `$3A256`) y clasifica cada byte en dato positivo / dato negativo / codigo. **154 bytes: 90,9 % dato, 3,9 % codigo.** Salen en pantalla los 8 flujos con el valor con signo al lado |
| `_disasm_tools/auditar_moves.py` | **Audita nuestra tabla de moves contra el ROM.** Relee los 1950 registros por el camino real (indice de words en `$50` + registro de 8 bytes) y compara con `LISTA_MOVES.txt`: **1950/1950 coinciden byte a byte**. Ademas calcula cuantos indices son moves de verdad, y descubre que **`indice[191]` es offset 0 en los diez contextos** = 195 indices pero **191 moves**. Es el script que sostiene `DATOS_VERIFICADOS.md` §3d |
| `_disasm_tools/ver_indice_moves.py` | La version corta del anterior: imprime el indice de words y los primeros registros de ctx0 y ctx1 con el volcado nuestro al lado, para ver de un vistazo que el camino es el correcto |

### Los `.lua` del material externo: NO se importan

Estan en `Desktop/INFORMACION ADICIONAL`, **fuera del repo**. Se auditaron y de
los tres solo uno aporta algo:

| Fichero | Lineas | Yield de la auditoria |
|---|---|---|
| `yuyu_hitbox_hud.backup.lua` | 2.100 | **Alto.** Trajo `$BC`, el camino reducido de dano y `$86`. Ademas tiene un **trainer** (`combo_refill()` + freeze, 9 `memory.writeword`) que **rompe la regla 5** y no se toma |
| `yuyu_combo_rec.lua` | 236 | **Cero.** 2 direcciones, ya verificadas. Impresor de combos por consola |
| `yuyu_spectator.lua` | 1.261 | **Cero.** 20 de sus 22 "direcciones" son **colores**, no memoria. Las 2 reales son `P1` y `P2`, y sus offsets ya eran nuestros |

**El yield de una auditoria lo marca cuantas direcciones de memoria tiene el
archivo, no cuantas lineas.** 1.261 lineas con 2 direcciones rinden menos que 236
lineas con las mismas 2: uno esta leyendo y el otro dibujando.
| `_disasm_tools/lua/traj.lua` | Trayectorias. **OJO:** usa `S1+0x4B8` como HP, es incorrecto |
| `_disasm_tools/lua/yuyu_sar2.lua` | Volcado de HP y punteros de animacion |
| `_disasm_tools/lua/yuyu_frames2.lua` | Eventos de dano y duraciones |
| `_disasm_tools/lua/vdpinfo.lua` | Patron BizHawk. No portar a FBNeo |

Carga en Fightcade: `Game > Lua Scripting > New Lua Script Window > Browse`.

### API de Lua en FBNeo (confirmada, no es la de BizHawk)

```lua
memory.registerexec(pc, func)   -- 2 args; desregistrar con memory.registerexec(pc, nil)
memory.registerwrite(addr, size, func)
memory.readbyte/readbytesigned/readword/readwordsigned/readdword/readdwordsigned
gui.box(left, top, right, bottom, fill, outline)
gui.text(x, y, str, col)       -- col = nombre o 0xRRGGBBAA (ver abajo)
gui.drawline(x1, y1, x2, y2, col)
joypad.get() / joypad.set(t)   -- "P1 Up", "P1 Button A".."Z", "P1 Mode", "P1 Start"
emu.registerstart / registerbefore / registerafter   -- hook por frame
emu.romname/parentname/sourcename/framecount/screenwidth/screenheight
bit.band/lshift  ·  savestate.registerload
```

En FBNeo el callback de dibujo por frame es **`emu.registerafter`** (ver
`fbneo-training-mode/hitboxes/kof-hitboxes.lua:234`, aunque ahi se elige con
`emu.update_func = fba and emu.registerafter or emu.registerbefore`). Ver
tambien `rotd-hitboxes.lua:245` para el uso directo `emu.registerafter(function()
... end)`. Leer memoria dentro de un hook es seguro.

### El color de `gui.*` es 0xRRGGBBAA, NO 0xAARRGGBB

**Verificado en ejecucion** con un LUA de diagnostico de 20 muestras (se cargo en
lugar del hitbox HUD, se leyo la captura y ya se borro). Las 20 salen con la
misma regla:

| Se escribio | Se vio |
|---|---|
| `0xFF0000FF` "azul" | **ROJO** |
| `0xFF00FF00` "verde" | **INVISIBLE** (alfa 0 en el byte bajo) |
| `0xFFFF00FF` "magenta" | **AMARILLO** |
| `0xFFFFFFFF` | blanco (los tres puros coincidian) |
| `0x000000FF` | negro opaco |

O sea:

```
0xRR GG BB AA
    ^^ ^^ ^^ byte BAJO = ALFA
         ^^ byte ALTO = ROJO
```

Consecuencias, todas aplicadas:

- **El alfa NO es transparente por estar en el byte alto.** Un `0x99A8C8E8`
  escrito a mano se veia como `(153,168,200)` con alfa `0xE8` = 91%, o sea casi
  solido. Por eso H.Rain "no era translucido" sin previo aviso.
- **`gui.box` y `gui.drawline` se comportan IGUAL.** No hay ninguna ventaja en
  cambiar de lineas a cuadros para poder transparentar. La hipotesis que se
  tenía (que el cuadro respetaba el alfa y la linea no) era falsa.
- **El error no es visible.** Un color mal codificado no da error ni aviso: sale
  de otro color. Por eso los dos scripts tienen ahora un helper `color(r,g,b,a)`
  y **ningun color se escribe en hexadecimal a mano**.
- Un `0xRRGGBBAA` es un numero > 2^31 y en LuaJIT es float. No pasar estos
  colores por `string.format("%08X")`: imprime un byte repetido.

### NUESTRO DOC ESTABA MAL, Y EL MATERIAL EXTERNO LO COPIO FIELMENTE

**Es el unico caso del proyecto en el que lo que no estaba verificado eramos
nosotros.** Paso asi:

| Cuando | Que decia `AGENTS.md` |
|---|---|
| **Antes** de `148ee27` | `gui.drawline` usa `0xRRGGBBAA`, pero **`box`/`text` usan `0xAARRGGBB`** |
| **Despues** de `148ee27` (10-05) | **`gui.*` es `0xRRGGBBAA`.** `box` y `drawline` **se comportan igual** |

El diagnostico de 20 muestras (`148ee27`, *"FBNeo lee 0xRRGGBBAA, no 0xAARRGGBB:
la lluvia salia rosa"*) demostro que el doc viejo estaba mal en sus dos partes: el
alpha no va adelante, y `box` no se comporta distinto de `drawline`.

**Un `.lua` del material externo esta escrito contra la version VIEJA del doc.**
Duplica cada color porque creia que habia dos formatos:

```lua
-- OJO CON EL FORMATO: gui.box y gui.text usan 0xAARRGGBB, pero gui.drawline usa
-- 0xRRGGBBAA. Por eso cada color tiene su par de constantes, en vez de calcular
-- una desde la otra. Ver AGENTS.md, seccion "gui.drawline usa 0xRRGGBBAA".

local P1_TXT  = 0xFFB4D2EA     -- ARGB: glifo, version clara del azul
local P1_LINE = 0xB4D2EAFF     -- RGBA: el mismo azul claro, para drawline
```

Los **mismos tres bytes** (`B4 D2 EA`), y lo unico que cambia es donde va el `FF`.
Esa duplicacion es la huella de la creencia equivocada. El autor no escribio nada
mal: **estaba aplicando nuestro doc al pie de la letra**, incluso citando la
seccion correcta.

**Consecuencia practica: sus `*_BOX` y `*_TXT` NO se importan.** Escritos como
ARGB y leidos como `0xRRGGBBAA` dan otro color, en silencio:

| Constante | Queria | Sale en realidad |
|---|---|---|
| `P1_TXT = 0xFFB4D2EA` | azul palido al 92% | **rosa salmon** (byte alto = `FF` = rojo) |
| `P1_BOX = 0xFF141A20` | azul casi negro | **rojo al 12%** |
| `T_PANEL = 0xFF08080C` | negro opaco | **rojo al 4,7%** |

Sus `*_LINE` si estan bien: esos si los escribio en el formato correcto.

### LA PREDICCION QUE FALSA EL DIAGNOSTICO

Hay un test de 2 minutos que confirma el diagnostico de color, y que ademas
muestra que el material externo esta roto.

`T_PANEL` se dibuja con **`gui.box`** y su trabajo declarado es tapar el cartel que
el juego pone al terminar el round:

```lua
-- El panel tiene que ser opaco: su un trabajo es tapar el cartel que pone el
-- juego al terminar el round, que no interesa en espectador.
local T_PANEL = 0xFF08080C
```

| Si al correr `yuyu_spectator.lua`... | Entonces |
|---|---|
| El panel **SI** tapa el cartel | El diagnostico de `148ee27` esta **mal** |
| El cartel **se ve** por debajo | El diagnostico acierta, y su panel esta roto |

Bajo lo verificado, `T_PANEL` tiene `A = 0x0C` = **4,7% de alfa**: transparente.
No puede tapar nada. Si tapa, hay que revisar el diagnostico.

**Por que esto importa mas que el dato del color:** la regla 4 dice que el
material externo se audita, y el ejemplo es el script de Discord con 6 errores.
Pero ese caso es **al reves**: lo no verificado era nuestro. Su script es
correcto *respecto de lo que le dijimos*, y lo que estaba mal era el doc.

**Un dato sin verificar no solo puede estar mal en el material ajeno: puede
estar mal en el nuestro y contaminar todo lo que el otro construya encima.**
Por eso los 20 samples no fueron un detalle: fueron los que cortaron el contagio.

### El overlay dibuja en la VENTANA, no en el JUEGO

**Verificado en ejecucion** con el stage de medicion del HUD, que salio mal en los
dos ejes a la vez y resulto ser un solo error.

El juego es **320x224** (proporcion 1.4286). Una ventana 4:3 es 1.3333. Al ajustar
el juego por el **ancho**, la imagen queda a 880x616 dentro de 880x658 y sobran
**~21 px de borde negro arriba y abajo**. El overlay cubre los 658 completos: la
fila 0 del overlay esta en el borde negro, no en la primera linea del juego.

| | Ancho | Alto |
|---|---|---|
| Ventana 4:3 | 880 | 658 |
| Imagen del juego | 880 | **616** |
| Borde negro | 0 | **~42** (21 arriba, 21 abajo) |

Esto explico las dos observaciones a la vez:

- **El eje X salia bien** porque al ajustar por el ancho NO sobra nada a los lados:
  el juego llena el ancho, `ox = 0`.
- **El eje Y salia corrido** porque si sobraba borde arriba: un `y1 = 1` caia en la
  franja negra y el borde inferior del panel quedaba 21 px mas abajo de donde
  deberia. "Sobresal por arriba" y "la foto no estaba abarcada" eran **el mismo
  error en dos bordes opuestos**.

Y explica el borde de C.Rain, que venia pendiente: la simulacion iba en pixeles de
ventana y la gota moria en la fila 224, que con 21 px de margen esta **dentro** de
la imagen y no en el borde.

**LA REGLA: la simulacion va en pixeles de juego, la conversion al dibujar.**

```lua
local function margen_juego()
  local ox = (emu.screenwidth()  - 320) / 2
  local oy = (emu.screenheight() - 224) / 2
  return math.floor(ox), math.floor(oy)
end
local function de_juego(x, y)      -- juego -> ventana, solo al dibujar
  local ox, oy = margen_juego()
  return x + ox, y + oy
end
```

Se **calcula**, no se supone. Sin borde da 0 y no cambia nada; con cualquier otra
proporcion sale bien. La misma idea que el snapshot de las cajas: leer y comparar
en un espacio, dibujar en el otro. Mezclarlos es lo que hacia que con borde el
suelo se fuera y las gotas murieran donde no tocaba.

Comprobado con el autotest a tres ventanas: **320x224** (borde 0), **320x448**
(borde 112) y **320x658** (borde 217). 87/87 en las tres.

### La linea de muerte de C.Rain SIGUE AL SUELO, no es un numero

**El suelo no es fijo.** Cambia con cada stage y con el scroll vertical de la camara,
así que la linea de muerte de la capa cercana (C.Rain) se calcula:

```lua
if d.suelo == "abajo" then
  local y = suelo_frente + ABAJO_OFF      -- suelo del stage + 8 de ventaja
  if y > ULTIMA_FILA then y = ULTIMA_FILA end
  return y
end
```

`suelo_frente` es el mismo que usan las otras capas, y sale de los pies del P1
(`suelo_frontal`, con el recorte SUELO_MIN/MAX).

| Constante | Que es |
|---|---|
| `ULTIMA_FILA` = 223 | **Techo**, no la linea de muerte. Ninguna gota se dibuja nunca en el borde negro. |
| `ABAJO_OFF` = 8 | Cuantas filas pasa C.Rain **por delante** del suelo. Es la capa cercana: si muriera en el suelo exacto no se distinguiria de la pesada. Con 0 muere en la linea del suelo. |

**OJO, eran dos preguntas distintas y se confundieron:**

| | Dice |
|---|---|
| Marco **AMARILLO** | Donde acaba la imagen del juego (223) |
| Linea **MAGENTA** | Donde muere la gota (suelo + 8) |

Coinciden solo si el suelo llega al fondo de la imagen, y no es el caso: debajo del
suelo hay filas negras DENTRO de la imagen. Con 223 como linea las gotas se perdian
ai; con 211 (medido en una captura) quedaban bien en un stage y mal en el siguiente.
Por eso sigue al suelo.

El recorte de la gota usa `linea_capa[t]`, que es **la misma** que calculo
`update_lluvia` este frame, no una recalculada por su cuenta: si el recorte y la
muerte usaran numeros distintos, la gota se cortaria por encima de por donde
muere.

### Las guias de medicion son un flag de menu: "G.LINE"

Las guias no estan clavadas en el codigo. Las controla `GUIAS`, que es el noveno
item del menu:

| | Que dibuja |
|---|---|
| marco **AMARILLO** | los bordes reales de la imagen del juego dentro de la ventana |
| linea **MAGENTA** | donde muere C.Rain (`suelo + ABAJO_OFF`) |
| **CYAN** | `y = 0`, `y = SPAWN_Y` y una rayita cada 32 filas de juego |
| rayitas **GRISES** | escala de la ventana, cada 16 px (larga cada 64) |

**APAGADAS de fabrica**, que es lo que corresponde a unas guias de medicion: no tienen
por que estar molestando cuando el ajuste ya termino. Se encienden desde el menu con
la opcion "G.LINE", que sigue ahi justamente para eso. Cuando no hagan falta mas, se
saca la opcion junto con `medir_hud()`.

**Apagarlas no cambia ni un pixel de la lluvia.** `GUIAS` solo gatea `medir_hud()`; ni
el calculo del margen (`margen_juego()` / `de_juego()`) ni el de las zonas del HUD
(`zona_tapa()`) dependen de esta variable. Lo que se guarda es el **calculo**, no el
dibujo.

`GUIAS` esta declarado arriba, antes de `zona_tapa()`, y no junto a `medir_hud()`
porque el menu lo usa en `DEFAULTS` y en su `bool_item`, y en Lua un local
declarado mas abajo seria un global nil en el punto de uso.

El orden de `DEFAULTS` **tiene que ser igual al de `MENU`**, en el mismo indice: el
reset (B) los aplica por posicion, no por nombre.

### "grab" salio del menu: ahora es una constante

`SHOW_GRAB` paso a ser una constante en `false` (esta junto a los demas `SHOW_*`).
La opcion no funcionaba de forma confiable y el usuario decidio no tocarla.

**NO se borro la lista**, ni el marcador de rango. La entrada `grab` de `LISTS`
sigue ahi con su detalle propio (stride `$20`, porque el descriptor de grab es el
doble que una caja) y con `SHOW_GRAB` en `true` se dibuja como antes. La logica de
dibujado es la misma que las otras cuatro, asi que sirve de referencia.

| Se perdio | |
|---|---|
| La opcion de menu | Es lo que se pidio |
| **La cobertura del autotest** | Las 3 pruebas que dibujaban la grab ya no pueden correr: con `SHOW_GRAB` en `false` no hay nada que mirar. Ahora comprueban lo que si es verdad (con la grab apagada no se dibuja nada suyo). Reponer la cobertura habria que cargar una variante del script con `SHOW_GRAB = true`, como se hace con las ventanas de 448 y 658 px |

**Ojo con los indices del menu del autotest.** Cada item se identifica por su
posicion, y sacar uno mueve todo lo de despues:

```
item 0 hitbox    item 5 H.Rain
item 1 clash     item 6 B.Rain
item 2 hurtbox   item 7 C.Rain
item 3 pushbox   item 8 G.LINE
item 4 cajas P2
```

Cada vez que se saca, agrega o reordena un item hay que revisar: `ITEM_*` del
autotest, el `for i = 1, N` de la seccion 8 (que navega a mano en vez de usar
`ir_a_item`), la lista `ESPERADAS`, `CONOCIDOS`, y el `eq("el menu tiene
exactamente 9 opciones")`.

### Las salpicaduras salen en CRUZ, no en angulo aleatorio

Cada impacto de H.Rain genera 4 particulas de 2x2 px, y van en las **cuatro
diagonales** respecto del punto de impacto. La de cada esquina toca con su punta la
punta de un hueco central de 2 px. Ese hueco **no se dibuja**: es la separación.

```
  [ ]  2px  [ ]
     2 px
 P    ....
     2 px
  [ ]     [ ]
```

`PART_CRUZ` es la tabla con los cuatro desplazamientos y el ángulo de cada una, y
`salpica()` la recorre en vez de sortear un ángulo.

**La aritmética del desplazamiento es lo único delicado.** La partícula ocupa los
píxeles `q.x .. q.x+1` y `q.y .. q.y+1`, así que para que el hueco sean **exactamente
2 px** los bloques tienen que empezar en `px-3` y `px+1`:

| | |
|---|---|
| Bloque izquierdo | `px-3 .. px-2` |
| Hueco | `px-1 .. px` |
| Bloque derecho | `px+1 .. px+2` |

Por eso los offsets son **-3 y +1 y no simétricos** (-2 y +2). El bloque es de 2 de
ancho y no se puede centrar en un píxel sin partirlo; con -2 y +2 el hueco sería de 3.

**LA VELOCIDAD SIGUE SIENDO ALEATORIA en magnitud.** La cruz se ve en el frame en que
nacen y en el siguiente; a partir de ahí cada una se va por su diagonal a velocidad
distinta y la separación ya no es 2. Para mantener la cruz hay que quitar el `rnd` de
la velocidad: con las cuatro iguales se abre como un cuadrado y la separación se
conserva.

`PART_POR` tiene que ser igual a `#PART_CRUZ`: el bucle recorre la tabla, que es la
que decide cuántas salen y en qué posición.
### Los recuadros del HUD tapan la lluvia, y NO son hurtbox

Los dos paneles (cara, barras, nombre) son **zona de no-dibujado**. No estan en
ninguna lista de colisiones, asi que no hay hurtbox que los tapara: son medidas
fijas, tomadas sobre capturas del usuario.

| Panel | x (juego) | y (juego) |
|---|---|---|
| P1 | 39..136 | 14..45 |
| P2 | 183..281 | 14..45 |

`zona_tapa(p, d)` devuelve la primera fila por la que una gota SI puede
dibujarse, o `nil`. Aplica a **las tres capas**, a proposito: el HUD esta en el
techo y le cae encima a quien le quiera. Ojo con no confundirlo con el otro
ocultamiento:

| | Quien | Que |
|---|---|---|
| `p.oculta` (hurtbox) | **solo B.Rain** | oculta la gota entera |
| `zona_tapa` (HUD) | **las tres** | recorta la parte alta |

Se **recorta**, no se oculta: la gota emerge limpia por debajo del panel. Ocultarla
entera la haria aparecer y desaparecer de golpe.

**Cuatro cosas que costaron un bug cada una.** Todas las encontro la prueba
"no hay ninguna gota dentro de los recuadros", no a ojo:

| Trampa | Que pasaba |
|---|---|
| Devolver `z.y2` sin `+1` | La punta quedaba dibujada **encima** del borde inferior del panel, que es la ultima fila y tambien esta tapada. |
| Mirar solo la diagonal en X | Con `grosor = 2` se dibujan DOS rectas, la segunda a 1 px de lado. Se colaba 1 px por el borde. El ancho real es `[min, max + grosor - 1]`. |
| Comparar `p.y` sin `math.floor` | Lo que se dibuja son FILAS enteras. Una gota con el tope en 45,5 no cumplia `p.y <= 45`, escapaba del recorte y pintaba la fila 45. |
| `d.dx * (y_top - p.y)` | `d.dx` es el desplazamiento **TOTAL** de la gota en sus `d.largo` filas, no por fila. Sin dividir por `d.largo` la punta se iba 2 px de mas, y como el total es menor que una fila el redondeo daba **gotas cayendo hacia la DERECHA**. |

Todos los recortes van en pixeles de JUEGO y la conversion a ventana se hace solo
al final, en los dos `de_juego()`. Mezclarlos hacia que con borde negro no se
dibujara ninguna gota: comparar una Y de juego contra una de ventana da siempre
falso, y con `oy = 0` no se nota. Por eso el autotest corre a **320x224** (borde
0), **320x448** (borde 112) y **320x658** (borde 217).

`gotas()` del autotest cuenta por `dy >= 4`, asi que **ya no puede usarse para
comparar igualdad exacta de lineas**: el HUD oculta gotas y las acorta, y eso
depende de la fase de la lluvia en cada ventana de medicion. La prueba "la lluvia
no cambia al apagar las cajas" paso a tolerancia (`>= 0.9`) mas un minima de
lineas en 200 frames. La trampa que persigue (el snapshot dentro de un
`if SHOW_CAJAS`) da **cero** lineas, no dos menos.

Igual con `inclinacion()`: ignora las lineas **verticales**, porque no dicen en
que sentido cae la gota. Aparecen con el recorte: a una gota a la que le quedan 4
de sus 6 filas le queda menos de 1 px de desplazamiento en todo el tramo, y al
redondear los dos extremos caen en la misma columna.

### El largo de una gota es POR GOTA, no por capa

C.Rain mezcla tres altos dentro de la misma capa: **6 de 3 px, 4 de 5 px, 3 de 7 px**,
13 gotas en total, todas de 1 px de grosor. H.Rain (7 de 7 px) y B.Rain (15 de 6 px)
siguen con un alto único cada una.

```lua
{ et = "C.Rain", n = 13, largo = 5, dx = -1, grosor = 1,
  largos = { 3, 5, 7, 3, 5, 3, 7, 3, 5, 3, 7, 5, 3 }, ... }
```

El campo `largos` es **opcional**: si esta, cada gota toma el suyo por indice; si no,
todas usan `largo`. El largo se guarda en `p.largo` al crear el pool y **no se vuelve a
tocar**: una gota no cambia de largo mientras cae.

**HAY DOS TABLAS Y NO SON LA MISMA LLUVIA.** `LLUVIA RECTA.LUA` esta CONGELADA como
la version medida, y `LLUVIA DIAGONAL.LUA` tiene otra lluvia (no solo el gate ni las
fases: tambien stock, duracion y alturas). Ojo con esto, que ya paso: la tabla de la
DIAGONAL quedo con `H.Rain | 1,10 s` mientras la de al lado decia `0,90 s`, y las dos
estaban en este archivo a doce lineas de distancia.

**`LLUVIA RECTA.LUA` — la congelada, con sus numeros medidos:**

| Capa | Stock | Dibujadas | Gotas | `dx` | Duración | Suelo |
|---|---|---|---|---|---|---|
| H.Rain | **10** | 10 | 7 px, `grosor` **2** | `0` recta | 54 frames (0,90 s) | frente |
| B.Rain | **20** | **10** | 10 de 4 px + 10 de 6 px, `grosor` 1 | `0` recta | 84 frames (1,40 s) | fondo |
| C.Rain | **13** | 13 | 6 de 3 + 4 de 5 + 3 de 7 px, `grosor` 1 | `0` recta | 33 frames (0,55 s) | suelo + 8 |
| | Duración | Velocidad relativa |
|---|---|---|
| C.Rain | 0,55 s | 1,6 veces H.Rain |
| H.Rain | 0,90 s | la intermedia |
| B.Rain | 1,40 s | **2,5 veces C.Rain** |

**En B.Rain el stock y lo dibujado NO son lo mismo**, y es lo unico de esta tabla que
no es inmediato: hay 20 gotas pero solo se dibujan 10.

**`LLUVIA DIAGONAL.LUA` — la que se esta afinando (a ojo, por pedido del usuario):**

| Capa | Stock | Dibujadas | Gotas | `dx` | Duración | Suelo |
|---|---|---|---|---|---|---|
| H.Rain | **14** | 14 | 7 px, `grosor` **2** | `0` recta | 39 frames (0,65 s) | frente |
| B.Rain | **22** | **11** | 11 de 6 px + 11 de 9 px, `grosor` 1 | `0` recta | 66 frames (1,10 s) | fondo |
| C.Rain | **16** | 16 | 7 de 3 + 5 de 4 + 4 de 6 px, `grosor` 1 | `0` recta | 27 frames (0,45 s) | suelo + 8 |
| | Duración | Velocidad relativa |
|---|---|---|
| C.Rain | 0,45 s | 1,4 veces H.Rain |
| H.Rain | 0,65 s | 1,7 veces C.Rain |
| B.Rain | 1,10 s | **2,4 veces C.Rain** |

Y el **techo de velocidad de cada capa**, que es lo que impide subirlas por el mismo
factor. El bloque largo esta en `LLUVIA DIAGONAL.LUA`, en `TECHOS_DE_LLUVIA`:

| Capa | `dur` mínimo para traza continua | `dur` real | Margen |
|---|---|---|---|
| H.Rain 7 px | 25,0 | 39 | ×1,56 |
| B.Rain 6 px | 26,5 | 66 | ×2,49 |
| B.Rain 9 px | 17,7 | 66 | ×3,73 |
| C.Rain 3 px | 61,0 | 27 | **×0,44 — ya pasada** |
| C.Rain 4 px | 45,8 | 27 | **×0,59 — ya pasada** |
| C.Rain 6 px | 30,5 | 27 | **×0,89 — ya pasada** |

El criterio es `v <= largo`, o sea `dur >= linea / largo`: una gota de `largo` px
dibujada en frames seguidos se lee como estela continua solo si el paso por frame no
supera su propia longitud. ***Es un argumento geométrico, no una medición, y no dice
que los guiones se vean mal:*** una lluvia rapida de verdad es una lluvia de guiones.
Lo que sí dice es que **C.Rain no tiene aire para subir más**, y que su gota larga (7 →
6 px) dejó de ser continua al subir la velocidad a la vez.

**Al tocar `dur`, ojo con los porcentajes.** La velocidad es `linea / dur`, o sea
inversa: bajar la duración de 0,70 a 0,55 s es un **21 % menos de duración** pero un
**27 % más de velocidad**. Si se quiere un incremento de velocidad concreto,
`dur = dur_viejo / (1 + incremento)`.

**Y `dur` NO es el tiempo en pantalla.** Es la velocidad nominal: la gota nace
`SPAWN_BANDA` = 40 filas más abajo de la fila de salida y muere cuando llega la
**punta**, no el cuerpo. Sin colisión, la vida real de la lluvia de la DIAGONAL:

| Capa | Vida real | `dur` nominal |
|---|---|---|
| H.Rain 7 px | 0,44 … 0,60 s | 0,65 s |
| B.Rain 6 px | 0,71 … 1,01 s | 1,10 s |
| C.Rain 3 px | 0,32 … 0,42 s | 0,45 s |

Lo que da el rango son dos cosas independientes: la fila de nacimiento (10 a 50) y la
altura del suelo del stage, que `suelo_frontal()` clampa entre 175 y 219. **La del
suelo casi no importa** (44 px son ~2 % del tiempo); **la de la banda de nacimiento
es un 30 %**, y por eso no se puede describir una capa con un número solo.

**Y el de H.Rain es un TECHO, no lo normal**: `choca = true`, o sea que salpica y muere
al tocar cualquier hurtbox, así que su vida real es `min(el número de arriba, frames
hasta la primera hurtbox)`. B.Rain solo se oculta y sigue cayendo, y C.Rain no
colisiona con nada.

**El contraste entre capas es lo que hace que la lluvia se lea con profundidad, y el
mayor lo aporta B.Rain: es la lenta **y la que parpadea**. Con el parpadeo a 2
frames son 15 Hz, y a la velocidad de B.Rain el ojo tiene tiempo de asentarse entre
cambios. **El parpadeo esta acoplado a la lentitud de la capa.**

| | Que es |
|---|---|
| `n = 20` | El pool. Todas caen y mueren siempre |
| `parpadeo = true` | Marca la capa como parpadeante |
| `p.grupo` | 0 si el alto es el corto de la capa, 1 si es el largo. Se decide **por el largo**, no por el indice, para que siga siendo correcto si alguien reordena `largos` |
| `p.parpadeo` | Se recalcula cada frame en `update_lluvia`. Es DISTINTO de `p.oculta`: esta es la hurtbox, aquel es el turno |

`draw_lluvia` salta el dibujado entero con `not p.oculta and not p.parpadeo`. El efecto
usa exactamente el mecanismo de la hurtbox, guardado en otro campo para poder
razonar sobre cada causa por separado.

**Lo que el parpadeo NO toca**, y es lo importante:

| | |
|---|---|
| `p.largo` | **Nunca se reasigna.** Cada gota es siempre la misma altura: NO hay estiramiento |
| La muerte | `p.y + p.largo >= linea`, sin cambios |
| La velocidad | `linea / dur`, sin cambios |
| El recorte del HUD | Se calcula sobre `p.largo` |

Las gotas ocultas **siguen vivas**: se mueven, mueren en su punto y se re-siembran.
Por eso la muerte sigue siendo exacta y no hay una "muerte invisible".

`PARPADEO_FRAMES = 2` en el bloque del parpadeo. Un ciclo son 4 frames, o sea 15 Hz a
60 Hz: se ve como un brillo. Con 1 seria 30 Hz y un estrobo.

La fase es un contador propio (`frames_parpadeo`), **no `emu.framecount`**:
`framecount` lo resetea el emulador al cargar un savestate, y un cambio de fase en
ese frame haria parpadear la lluvia de golpe.

**H.Rain es la única que queda con un alto único y en diagonal.** Las otras dos
mezclan alturas y van rectas. En B.Rain el reparto sale solo alternado: con dos
series de la misma cantidad, la posición proporcional de las dos coincide en cada
slot (0,1 / 0,3 / 0,5 / 0,7 / 0,9) y el desempate va a la primera.

Una consecuencia de mezclar alturas que **no es de dibujado**: la muerte es
`p.y + p.largo >= linea`, o sea decide *cuándo* la punta llega al suelo. Una gota de
4 px viaja por eso un par de píxeles **más** que una de 6, porque su punta está más
arriba. El valor `suelo` y `FONDO_PISO_OFF` no se tocan para nada: la diferencia es
inherente a que las gotas tengan distinta altura.

**LAS TRES CAPAS VAN RECTAS (`dx = 0`). Ninguna tiene inclinacion.**

Con 1 px de desplazamiento sobre 3, 4, 5, 6 o 7 filas la inclinacion es tan poco que
el redondeo la hacia retorcerse y se leia como una "S" que se movia. Se fueron
poniendo rectas por pedido, una a una: primero C.Rain, despues B.Rain y por ultimo
H.Rain.

**QUE SE PIERDE Y QUE NO.** Antes se sostenia que H.Rain conservaba el `dx = -2` a
proposito para no perder el paralaje. **Con las tres rectas ya no hay paralaje por
inclinacion.** Lo que sigue dando profundidad es lo de verdad:

| | |
|---|---|
| Velocidad | 0,55 / 0,90 / 1,40 s en la RECTA; **0,45 / 0,65 / 1,10 s en la DIAGONAL**. Lo mas notorio de lejos |
| Altura | 3, 5 y 7 px; 4 y 6 px; 7 px |
| Grosor | 2 px solo en H.Rain |
| Opacidad | alfa `0x99` solo en H.Rain: la unica translucida |
| Parpadeo | solo B.Rain |
| Densidad | 13 / 20 / 10 gotas en la RECTA; **16 / 22 / 14 en la DIAGONAL** |

Si alguna vez hay que devolver la sensacion de caida diagonal, el sitio no es `dx` sino
la combinacion de velocidad y altura.

**PONER UNA CAPA RECTA NO LE QUITA EL GROSOR.** El grosor no es una linea mas gruesa:
es **la misma recta dibujada dos veces, la segunda a 1 px de lado**. Con `dx = 0` las
dos quedan verticales en columnas contiguas, o sea que sigue midiendo 2 px de ancho.

Con `dx = 0` no hay que cambiar nada mas: la muerte y la banda vertical del recorte
del HUD no usan `dx`, y la punta de la recta se recalcula con `p.x + dx * frac`, que
con `dx = 0` da `p.x` en los dos extremos, o sea vertical exacta.

**Lo unico que cambia con `dx = 0` es el ancho en X del recorte**: con `grosor = 1`
el span pasa a ser de 1 px, que es lo correcto. Y en `toca_hurtbox`, que B.Rain si usa
(`oculta = true`), la caja pasa de 2 px de ancho a 1: es decir, se oculta un pelo
 menos. Ninguna de las dos cosas se nota.

**El reparto va intercalado a propósito.** El indice `i` de la gota es lo que reparte
la X (`sembrar_una`: `p.x = (i - 0.5) * paso_x`), asi que un reparto en orden
(3,3,3,3,3,3,5,5,5,5,7,7,7) deja las 6 cortas siempre en el mismo tercio de la
pantalla: **tres franjas verticales de lluvia**. La lista sale de juntar las tres
series por su posicion proporcional (`(k + 0,5) / cantidad`), que reparte los 13
slots casi a 1/13 uno.

| Trampa | Realidad |
|---|---|
| Cambiar `d.largo` por `p.largo` solo en el dibujado | `d.largo` aparece en **7** sitios: la banda vertical de `zona_tapa`, `toca_hurtbox`, la muerte, la salpicadura, `y_bot`, el denominador de `frac` y el recorte de ventana. Si se deja uno, ese comparacion sigue usando el largo de la capa |
| Usar el `|dy|` dibujado para contar gotas de cada alto | **No dice el largo.** Una gota recortada por un panel del HUD o por su linea de muerte sale mas corta: un `|dy|` de 3 puede ser una de 3 o una de 7 recortada. El reparto se mide sobre el **stock** |
| Perder el `math.floor` de las Y al reescribir el recorte | `p.y` es flotante y los dos extremos se estan recortando. Sin el floor, `y1` sale fraccionario (45,7) y se dibuja una fila de mas o de menos. Las dos Y van enteras, como antes |
| Contar gotas del autotest **por forma** (`dx > 0`) | **Contaba solo H.Rain, en silencio.** Con `dx = 0` sus lineas tienen `|dx| = 0` y el filtro las botaba, asi que varias pruebas de "la lluvia sigue saliendo" estaban midiendo una sola capa sin que se notara. Ahora se cuenta **por color**, con `dy >= 1` para dejar fuera las salpicaduras horizontales |
| Escribir un local con otra caja | `Altos_por_capa` en vez de `altos_por_capa` es un **global nil**, y el sintoma es `attempt to index global ... (a nil value)` en un punto que parece no tener nada que ver. El mensaje va a **stderr**, asi que con `2>&1` y un `Select-Object -Last` se va al final de la salida y parece que el test se corto sin error |
| Detectar el grosor de una gota por una linea vecina a 1 px | Es como se dibuja la copia de las 2 px, pero **dos gotas de la misma capa pueden caer en filas contiguas** y se contarian como copia. H.Rain es la unica con `grosor = 2`, asi que se identifica por su color |
| Identificar el grupo del parpadeo por la **altura dibujada** | Miente: una gota de 6 px dentro de la banda de un panel sale recortada a 4 filas, y un `|dy|` de 4 es indistinguible del de una de 4 entera. Da falsos "los dos grupos a la vez". Hay que identificar por la **X**: con n = 20 el paso es 16 y las impares van en `8 +- 4,8`, las pares en `24 +- 4,8`, y esas dos franjas quedan fuera de los paneles (x 39..136 y 183..281) |
| Comparar SUMAS de lineas para comprobar que una capa MUERE antes | Difference de 0,1 % sobre el total, mas pequena que el ruido. Se rompio al subir el pool de B.Rain de 10 a 20, porque `sembrar_una` consume el doble de `math.random()`, corre la fase del RNG y las gotas de otra capa caen en otras columnas. **La prueba decisiva de que H.Rain choca con la hurtbox ya existe y es exacta**: con las tres cajas de radio 127, `gotas_pesada() == 0`. Cero no tiene ruido. Y si hay que medirlo de nuevo, con caja tapando toda la pantalla, no con la caja pequena de y = 140 |
| Filtrar gotas del autotest por **forma** (`dx > 0`) | Con `dx = 0` no cuenta NINGUNA. Pasaron tres sitios: `gotas()`, `gotas_por_grosor()` y despues `firma()` y `lineas_de_gota()`. Todos cuentan ahora por **color** con `es_lluvia()`, que no depende de la pendiente |
| Dejar una prueba que da 0 vs 0 | `inclinacion(COL_PESADA)` seguia dando verde con H.Rain recta, porque ignora las verticales: 0 inclinadas a la derecha es exactamente lo que tiene que dar, pero no comprueba NADA. Una prueba que vale 0 y 0 es peor que no tenerla. Se borro; la que sirve es "no se inclina en ningun frame de 60" |

**El backflip casi no se llega sin agarre, y eso es una regla del juego, no un
detalle del experimento.** Medido por el usuario:

| Como se manda al rival al aire | ¿El siguiente suave conecta? |
|---|---|
| Golpe normal en suelo | No lo manda al aire, solo empuja |
| **Agresion / especial** | Lo manda al aire, **pero knocks down**, asi que los siguientes tambien |
| **Agarre** | **Lo manda al aire y el siguiente B igual conecta** |

Los movimientos que se pueden cancelar y encadenar solo son los especiales, y los
especiales knocks down. O sea que **sin agarre, cualquier secuencia termina en
knockdown aunque haya ventana de tiempo para conectar**. El agarre es el unico
lanzador que deja al rival golpeable.

Por lo tanto el guion para medir el backflip es **agarre -> B inmediato ->
soltar**, y NO "esperar a que el rival se de vuelta". Y no es que el agarre
produzca el backflip: lo unico que hace es **ponerlo en el aire con la ventana
abierta**. El backflip es el **fin del hitstun del B, estando en el aire**.

Un caso aparte que **no sirve**: Toguro Menor con ARRIBA+A en el aire golpea y
produce knockdown tanto en aire como en suelo, y ademas depende del tamaño del
enemigo (que se sortea). Knockdown no es backflip, asi que no ayuda.

Por lo del ultimo punto: el autotest necesita el **stock**, que es un `local` del
script. Por eso el .lua tiene un bloque de **solo lectura** al final que expone
`altos_por_capa()` **solo si el autotest pone `_G.__yuyu_test` ANTES del `dofile`**:
en el emulador no se crea nunca. No dibuja, no lee ni escribe la memoria del juego y
no cambia el efecto. Sigue siendo pasivo (ver la regla 5).

### `$C6` es el contador NATIVO de combo, y vive en el DEFENSOR

El juego lleva la cuenta del combo en un byte. **No hay que estimarlo contando
frames.** La rutina es `loc_01F9C8`.

| | |
|---|---|
| Donde | `$C6`, en **`a4` = DEFENSOR** (`a3` = atacante) |
| Incremento | `addi.b #$1, $c6(a4)` en `0x1F9F0` |
| Tope | **16**, `move.b #$10, $c6(a4)` en `0x1F9FE` |
| Reset | `clr.b $c6(a4)` en `loc_01FA6A` |
| Ventana | **por estado, no por frames** |

**Para leer el combo de P1 hay que leer `$C6` del slot del P2.** Es el punto que
mas se va a olvidar: el contador esta en la victima, no en la que pega.

**Y hay un agujero en la ventana que no se ve leyendo los dos `cmp` extremos:**

| `$5F` del defensor | Efecto |
|---|---|
| `$20`–`$27` | suma |
| **`$28`–`$2D`** | **RESETEA**, aunque este dentro de `$20`–`$30` |
| `$2E`–`$30` | suma |
| fuera de `$20`–`$30` | reset |

Los branches son `cmpi.b #$20` / `cmpi.b #$30` / `cmpi.b #$27` / `cmpi.b #$2e`
(`0x1F9C8`-`0x1F9EC`). Si uno se queda con "se resetea fuera de `$20`-`$30`"
pierde esos 6 estados.

### El maná por combo estaba corrido en un golpe

`$C6` alimenta el maná del **atacante** (`$B8` en `a3`): `asl.w #$1, d0` con `d0 =
$C6` y `add.w d0, $b8(a3)`, en `0x1FA0C`-`0x1FA12`, con tope 223 en `0x1FA1E`.

El **orden** es lo que define la tabla: `addi.b #$1, $c6(a4)` esta en `0x1F9F0`, o
sea **antes** del uso. Por eso el primer golpe ya da +2.

| | Valor |
|---|---|
| **Regla verificada** | `+2 * n`, `n` = golpe contando desde el **primero** |
| Acumulado | `n * (n + 1)`; 272 al llegar a 16, +32 por golpe extra |
| Lo que decia la tabla de web | `min(2 * (n - 1), 32)`, "nada hasta el segundo golpe" |

Los valores por golpe y el acumulado **coincidian**; solo la etiqueta del numero
de golpe estaba corrida en uno. `remake_godot/data/game_data.json` →
`sistema_maná.recup_por_hit` tiene la version corrida: corregir al usar.

### El resolver tiene DOS caminos de dano, y eso acota el blockstun

En `loc_01F21E` hay dos formas de aplicar un golpe:

```asm
01f320:  and.b   $63(a4), d0     ; mascara de defensa del DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414         ; == 0 -> camino COMPLETO

loc_01f3d6:                      ; camino REDUCIDO
01f3d8:  move.b  $65(a3), d0
01f3dc:  lsr.b   #$2, d0         ; daño = $65 / 4
01f3de:  addq.b  #$1, d0
         ...                      ; NO toca $7E en ningun momento
01f410:  bra.w   $1f50a

loc_01f414:                      ; camino COMPLETO
01f416:  clr.w   $84(a4)
01f41a:  move.b  #$ff, $86(a4)
01f424:  sub.w   d0, $78(a4)     ; daño entero
01f42c:  sub.w   d0, $7e(a4)     ; y STUN
```

| | Completo | Reducido |
|---|---|---|
| Daño | `$65` entero | `$65 / 4 + 1` |
| Stun | si (`sub.w $66,$7E`) | **no** |

**Lo que prueba: existe un camino que hace daño SIN stun.** Ese es el perfil del
chip damage y del golpe bloqueado. Por lo tanto **el blockstun NO esta en `$7E`**:
si un golpe puede damagear sin pasar por ahi, "stun de golpe" y "stun de bloqueo"
son campos distintos. El pendiente 3 estaba buscando en el lugar equivocado.

**Lo que sigue abierto:** cual es el campo. Hay que mirar **despues de
`0x1F32C`**, que es donde el golpe bloqueado prepara el empujon (`$10 = $2B000`,
`$14 = $FFFC0000`, `$6A = 1` en `0x1F33A`) antes de caer al reducido.

Ojo: hay un `beq.b $1f3f0` en `0x1F3D4` que puede saltar el reducido entero, asi
que el reducido no es automatico.

### El material externo trae un TRAINER, y no lo tomamos

Una version del hitbox HUD que vino de afuera tiene relleno automatico de vida y
maná (`combo_refill()`, 8 escrituras) y un freeze (1 escritura mas) sobre
`$FFF558`. **`memory.writeword` a `$FF8478`, `$FF847A`, `$FF84B8`, `$FF84BC`,
`$FF8878`, `$FF887A`, `$FF88B8`, `$FF88BC` y `$FFF558`.**

**No se adopto, y no se va a adoptar: rompe la regla 5.**

Que no se pueda tocar el codigo del juego no lo hace inocuo. Estas escrituras caen
todas en el espejo de RAM de trabajo (arriba de `$FF8400`), asi que **no cambian
ninguna instruccion**: cambian **variables que el juego despues lee**. Eso es un
cheat, no una modificacion del juego, y por eso la regla lo prohibe.

**La razon por la que la regla existe, y que conviene no olvidar:** un script que
escribe deja de estar **midiendo** el juego y pasa a estar **modificandolo**. Y
eso se cruzaba con la calibracion: al medir `CAL_X` / `CAL_Y` hay que ver donde
cae una caja respecto del sprite, y si el mismo script te rellena la vida, estas
calibrando contra un juego al que le estas cambiando valores. **Los dos usos no
conviven: o se mira el juego, o se lo toca.**

Los **datos** que venían alrededor si se tomaron, porque son lecturas: `$BC` como
barra del maná, el camino reducido, `$86`. Lo que se descarto fue la funcion.

### La guia tecnica unificada del amigo: cotejada, NO reemplaza nuestros docs

**Segunda pasada, 2026-10-07** (la guia paso de 925 a 1127 lineas). Lo que cambio
y lo que nuevo trajo esta en `DATOS_VERIFICADOS.md` §3e. Resumen de como termino
la cuenta:

| | |
|---|---|
| Acerto en el **191** (y no 195) | §3d, verificado con `auditar_moves.py` |
| Se equivoco en el **"volcado desalineado"** | 1950/1950 entradas coinciden byte a byte |
| Se equivoco en el **HP maximo**: dice que 223 es 255 | §2. **Nuestro `game_data.json` ya decia 223 y era el correcto** |
| Acerpto a verificar `***` | el stun por golpe (2-16 contra 38-62), los 12 contextos con la columna `$90`, `$20` como progresion de `$20000`, `$9C` en `01ef1e`/`01ee48`, el contexto 12, `especiales.danio` como deltas de mana |

**El PDF de la movelist no entra.** Dice "Sin direcciones de memoria", y por la
regla 2 sin direccion no es un dato. Trae justo lo que nos falta —las cadenas de
frames, que son el pendiente 2— pero hay que cruzarlo fila por fila contra el
registro de 8 bytes del ROM antes de adoptarlo.

**Y ojo con una cosa que se nos habia pasado:** `game_data.json` tiene
**`"hp_max": 223`**, que el guia quiere cambiar a 255. **No hay que cambiar nada:
ya estaba bien.**

`Desktop/GUIA_TECNICA_UNIFICADA.md` (10-06, 925 lineas) dice "reemplaza a
DATOS_VERIFICADOS.md, TABLAS_MOVES_Y_TIMING.md, ...". **No lo hace.** Se cotejo
parte por parte y el resultado es mixto:

| Afirmacion suya | Veredicto |
|---|---|
| `$9C` NO es el ID, se copia a `$44` | **Tenia razon, y mejor que nosotros** |
| `+4` del frame es indice de **sonido** | **Tenia razon.** `$F800` como base de puntero |
| La cola `$F80A`-`$F80D` es de sonido | **Tenia razon** |
| `$F558` es el hit-time del pipeline | Correcto, y lo medimos |
| `$6A` = nivel de empuje, no blockstun | Correcto |
| `$26` = "profundidad, 64 y 192" | **Refutado con las tablas en la mano.** Los datos van de `-40` a `+40`; 64 y 192 son los **offsets de arranque** que escriben `$0x1F7C0`/`$0x1F7D4`, o sea indices. El error es la trampa "mirar solo los escritores", que ya estaba anotada aqui |
| "el volcado de moves esta desalineado" | **Falso, y verificado las 1950 entradas.** `_disasm_tools/auditar_moves.py` revalida cada una releyendo el ROM por el camino real (indice de words -> registro) y **1950/1950 coinciden byte a byte**. Nuestra herramienta salta el indice bien. Lo que si estaba mal es el **recorte**: hay 195 indices pero **191 moves**, y las 4 entradas finales por contexto son basura. Ver `DATOS_VERIFICADOS.md` §3d |
| Un dump se audita contando numeros que coinciden | **Hay que auditar la SEMANTICA de las columnas primero.** El cruce con el PDF dio 33,6 % y no decia nada: el campo de `Startup · Activo · Recovery` y la cadena de frames **se pisan en la misma columna**, y mi parser no sabia donde arrancaba la cadena. Los desacuerdos eran sistematicos (moves 6 y 7 con la misma cadena). Un porcentaje de acuerdo sin saber que columna estas mirando es ruido |
| Lo que trae un doc sin direcciones se audita, y si coincide se adopta | **No: se audita y en las DOS direcciones.** Aqui el material externo se equivoco en una cosa y acerto en otra sobre el MISMO fichero nuestro: el "desalineado" era falso, el "191 y no 195" era cierto. Ojo que el acierto no compensa el error: son afirmaciones separadas y hay que responder a cada una por separado |
| Con un `move.w #$ff` encounterado se sabe que el HP maximo es 255 | **No. Hay DOS 255 y son de campos distintos.** `$0x12AE6` escribe `$FF` en `$78` (HP) y `$0x1A282` escribe `$FF` en `$7E` (**sentinel de stun**, que es la proteccion de 255 al levantarse). Y `$DF` (223) aparece en cuatro sitios, **todos de `$B8`** (mana). Con los tres numeros dando vueltas, el unico que se puede atribuir a un campo es el que esta pegado a su offset |
| El numero "14 comparaciones de HP bajo" | **Eran 11, no 14.** El 14 era el TOTAL de comparaciones contra `$78(a5)`: `#$6f`=111 (11), `#$70`=112 (1), `#$0` (1), `#$fc00`=-1024 (1). Y hay **DOS umbrales**, 111 y 112, no uno: el de 112 dispara el valor especial `$C00E` de la barra |
| `$7A` es el HP | **No: es la BARRA ANIMADA.** Persigue a `$78` de a 1 por frame (`$157A8` `subq.w #$1` / `$157AC` `addq.w #$1`) hasta que son iguales (`$157A4`). Un `.lua` que lea `$7A` lee la barra, no la vida |

**Lo que trae y nosotros no:** los **12 contextos** con direcciones de init (y que
el 11 y el 12 no son personajes normales), el **pipeline grafico** con el codec de
VRAM en `loc_0007BE` y que `$2D5E` NO es un descompresor, la **guardia de
entrada** `1edac: btst.b #$7,$f550.w`, y el **descriptor de grab decodificado**
campo por campo.

**Lo que no trae:** `$58`, `$F809`, los 4 canales, `$37C44`, la cola de prioridad,
los 4 freezes, el 255 de Itsuki, `$26` corregido, y la ambiguedad del slot de P2.

**Lecciones que quedan:**
- **El material externo se audita en los dos sentidos.** El codigo de color de su
  `.lua` estaba bien y nuestro doc mal. Esta vez es al reves: el suyo tiene
  `$26` viejo y nosotros lo corregimos.
- **Un doc que se autodeclara maestro se coteja igual.** Las etiquetas
  (`[ROM]`, `[MEDIDO]`, `[WEB]`, `[ABIERTO]`) son las nuestras y estan bien
  usadas, pero el rotulo no sustituye la verificacion.

### La cola de sonido pierde peticiones, y eso se oye

**Medido de oido:** hay tecnicas que se ejecutan sin pronunciar nada, y personajes
que mueren sin su grito. Los golpes le ganan a las voces. La musica nunca se corta
ni se ve afectada por el time stop ni por la camara lenta.

Todo eso tiene mecanismo, y es el mismo para los tres:

```asm
01eda0:  clr.b     $a030.w      ; <- borra la peticion SIEMPRE
01eda4:  jmp       $21960.l     ; <- y NO mira si la aceptaron
...
loc_0219a8:
0219a8:  clr.b     d0           ; los 4 canales llenos -> devuelve 0
0219aa:  rts
```

**La cola tiene 4 canales. Cuando se llenan, la peticion se pierde para siempre.**
Y `$37C44` gana el de mayor prioridad (`d2 & #$7f` contra `d3 & #$7f`), asi que
un impacto le gana a una voz.

La musica no pasa por acá: es otro driver, y por eso es inmune a los freezes.

**La unica excepcion es `$F562`**, que reintenta hasta que `$21960` acepte
(`0x219BA`-`0x219C8`). Un unico sonido tiene paciencia; los demas no.

### Que buscaba el amigo con el "hit time de las ultis"

**No lo invento: es un pendiente heredado.** Esta en la linea 7 del `AGENTS.md` de
los dos, palabra por palabra:

> 7. Gravedad, contacto con el suelo. Y el **hit-time de las especiales**, que no
> aparece ni en `$69` ni en `$F558`.

Lo que hizo: investigar `$26` (lo unico que prende en cada contacto sin estar
asignado), concluir que es profundidad y anotarlo como trampa, identificar `$69`
como el hit-time real, y dejar el de las especiales abierto.

**El problema no fue el analisis: fue la premisa.** "Las especiales congelan mas"
viene de una guia, no del ROM. Y `$69` toma **0, 16, 28 y 255** en todo el juego:
un especial pone 16, igual que un basico. **No hay hit-time por movimiento.**

Por eso le dio tanta importancia: era el pendiente que el proyecto arrastraba hace
varias sesiones, y el 255 resulto ser la unica excepcion real.

### COMO SE MAPEA UNA HABILIDAD: `loc_011F3E` es "empezar el move N"

**Esta es la rutina base, y es lo que hace falta para mapear CUALQUIER
tecnica**, no solo las que tienen un efecto caracteristico.

```asm
loc_011f3e:
011f3e:  move.b d0, $5f(a5)      ; <- EL ID DEL MOVE (el que pide el llamador)
011f42:  clr.b  $59(a5)          ; frame de animacion = 0
011f46:  move.b #$8, $5a(a5)     ; duracion
011f4c:  move.b #$ff, $5b(a5)    ; <- MARCADOR: el tick arranca en $FF
011f52:  clr.b  $5c(a5)
011f56:  clr.b  $60(a5)
011f5a:  rts
```

**Recibe el id en `d0` y pone SIEMPRE los mismos seis campos.** Hay ademas unos
14 callers que ponen `$5F` directo: `0x1433E`, `0x143AE`, `0x14614`, `0x15E6A`,
`0x15EA4`, `0x16018` y mas.

**La receta para mapear una tecnica, y es la misma para todas:**

| Se lee | Para que sirve |
|---|---|
| **`$5F`** | **Que tecnica es.** Hay **191 ids por contexto**, o sea que el id solo tiene sentido junto al personaje |
| **`$59`** | En que frame de la tecnica esta. Con `$5F` da la posicion exacta: tecnica mas frame |
| **`$5A` / `$5B`** | Duracion del frame y tick. **`$5B = $FF` es el arranque** |
| **`$8C`** | Puntero a la tabla de frame data de ESE move: dano, stun, empuje, y el bit 6 que marca los frames activos |

**Y ACA ESTA LA DIFERENCIA CON LO QUE HIZO `ITSUKI SET MOVE.LUA`:** ese script
**NO rastrea la tecnica**. Detecta el **efecto**: mira si algun `$69` vale 255, y
despues *infiere* quien lo lanzo buscando el unico slot con `$59 == 2` y
`$5B == 0`.

**Funciona unicamente porque 255 es unico:** el stop time es la unica habilidad
del juego que lo pone. Para mapear las demas **no sirve**, y por eso hace falta el
otro metodo:

| | Detectar el EFECTO (lo que hace el script) | Rastrear la TECNICA |
|---|---|---|
| Que necesita | Que el efecto sea unico (255, 160, 28...) | Nada: el id siempre esta |
| Cuantas habilidades cubre | **1 por valor** | **las 191 de cada personaje** |
| Si la habilidad no distorsiona | **No la ve** | La ve igual |
| Campos | `$69`, `$5F`, `$59`, `$8C` | `$5F`, `$59`, `$8C` |

**O sea: para mapear las demas hay que cambiar a rastrear `$5F`.** No es mas
dificil y es lo que cubre todas.

### La base del slot de P2: depende de como se armo la partida

**NO hay una respuesta unica, y por eso el HUD no la puede suponer.**

| Como se armo | P1 | P2 |
|---|---|---|
| **Desde el select**, Battle Royale 1v1 | `$FF8400` | **`$FF8800`** |
| **Desde un savestate** | `$FF8400` | **`$FF9000`** |

Medido con `yuyu_slots_diag.lua` en las dos formas, con el volcado de los 4 slots.
**Los dos aciertos eran ciertos en su contexto:** el del amigo venia de savestates,
el nuestro venia del select.

**Lo que se corrigio, y era MENOS grave de lo que se pensaba.** Este parrafo
decía que con una partida de savestate "el HUD del P2 no dibuja nada, sin error".
**Es falso, y esta verificado pixel a pixel** (autotest 8b, 141 pruebas).

`LLUVIA RECTA.LUA` sí tiene `local P2 = 0xFF8800`, pero **ese valor no llega a
la salida del dibujo**, por tres motivos:

| | Por que |
|---|---|
| `owner_filter()` | Decide con el flag `SHOW_P2`, no con el slot. Prendido devuelve `nil` = "dibuja todas"; apagado devuelve `own_lo(P1)`. El slot del P2 no se consulta. |
| `to_screen()` | Ancla a `owner_base(owner) or P1`, pero la conversion es **afín de pendiente 1**, asi que el base se cancela: `Y = (worldY - A016 + F566 + 24 + CAL_Y) + (by - worldY)` queda en `by - A016 + F566 + 24 + CAL_Y`, que no depende del base. En X pasa igual. El fallback a P1 no desplaza nada. |
| `rects_grab()` y `draw_grab_range()` | Son las dos rutas donde `owner_base()` **sí** decide algo (`if ob then` y `moves_key(ob)`), y estan **detras de `SHOW_GRAB`, que es `false` de fabrica**. |

Consecuencia: con el P2 en `$8800` o en `$9000` se dibuja **exactamente lo
mismo**. No hay ningun bug del HUD que arreglar.

**Efecto lateral que conviene conocer:** como el base se cancela, **un jugador en
otra posicion del mundo NO desplaza sus propias cajas**. Las cajas salen de las
coordenadas de mundo de la caja, no de las del dueño. Por eso el autotest tiene
que mover la CAJA para comprobar que su firma sigue a la geometria: mover el
jugador no cambia nada, y el primer intento de autocomprobacion salio verde
justamente por eso.

**Lo que si se agrego, y si sirve:** `detectar_slots()` recorre los 4 slots y
reasigna P1 y P2 si encuentra **DOS** vivos (por HP `$78` o por tabla de moves
`$8C`). Con menos de dos se quedan las constantes, o sea el comportamiento
anterior, y por eso el autotest sigue igual. En el HUD es **inerte a proposito**:
es la primitiva que necesitan los `.lua` que si leen del slot del P2 (HP, stun,
mana, moves), que es donde el dato cuenta. Para el `.lua` de lluvia, que solo
colisiona con P1, no hace falta; para cualquier cosa que lea del rival, si.

**Sigue ABIERTO, pero el peso de la evidencia esta del lado de `$9000`, por dos
motivos que no hay que dar por sabidos.**

**1. El material externo lo MEDIRIO; nosotros lo INFERIMOS.** Los tres `.lua` usan
`P2 = 0xFF9000`, y uno lo dice al pie:

```lua
local P2 = 0xFF9000            -- P2, stride $C00. $FF8800 esta VACIO.
```

Alguien volco los slots en ejecucion y los vio. **Nuestro `$8800` sale de "mismo
patron de slots"**, que es un razonamiento, no una lectura. Cuando compiten una
medicion y una inferencia gana la medicion: es el mismo criterio que se usa para
`CAL_X` / `CAL_Y`.

**2. Nuestro argumento en contra era un non sequitur.** Se decia que `$C00` no
podia ser porque "el array va de `$400` en `$400`". **Eso no dice en que slot
esta P2.** Un array de 4 slots con P1 en el indice 1 y P2 en el indice 4 es
justo lo que produce `$C00` entre P1 y P2:

```asm
01c06a:  lea.l    $8400.w, a0
01c07e:  cmpa.w   #$9000, a0     ; el array INCLUYE $9000
01c084:  adda.w   #$400, a0      ; avanza de a $400
```

O sea que el bucle de 4 slots **apoya a `$9000`**, no lo descarta: el juego
recorre el array entero y `$9000` es el ultimo.

**Lo que el codigo no puede decir:** si `$8800` y `$8C00` estan vacios, y si P2
es el indice 4 o el 2. El codigo solo confirma que los cuatro son slots reales.

| | `$FF8400` | `$FF8800` | `$FF9000` |
|---|---|---|---|
| Slot del array | si (P1 confirmado) | si | si, el ultimo |
| Init de struct completo en el ROM | — | si (`0x00FAF2`) | — |
| Poblado en ejecucion | si | **supuesto vacio** | **supuesto poblado** |

**Como se cierra:** volcar los 4 slots y leer HP (`$78`), stun (`$7E`) y maná
(`$B8`) en `$FF8400`, `$FF8800`, `$FF8C00` y `$FF9000`. Los dos con valores son P1
y P2. **Ojo que la consecuencia ya NO es la que se pensaba:** antes decia que si
daba `$9000` el HUD del P2 se rompia. No se rompe: `detectar_slots()` esta puesto
y, aunque no estuviera, el dibujo seria identico (ver arriba). Lo que queda por
determinar es **cual es el caso habitual**, no si el HUD funciona.

**Aviso para cuando llegue:** hay un comentario suelto en el material externo que
dice `$FF88C6` para el combo, cuando el codigo de ese mismo archivo lee
`rb(P2 + O.COMBO)` = `$FF90C6`. Es un comentario viejo de antes del cambio a
`$9000`, **no** una contradiccion de codigo. No usarlo ni en contra ni a favor.

### NINGUN .lua con BOM UTF-8

**Un BOM rompe la carga en FBNeo** y el error no dice nada util:

```
[japan]\tools\fightcade\LLUVIA RECTA.LUA:1: '=' expected near '>'
```

Se queja en la **linea 1**, lejos del problema: Lua ve los tres bytes `EF BB BF`
como un caracter raro justo antes del `--` del comentario de cabecera.

Trampa doble: **LuaJIT en local SI acepta el BOM**, asi que `luajit -bl` y los
autotest pasan limpios y no dan ni una pista. El fallo solo aparece al abrirlo en
Fightcade. Comprobado: los tres Lua estaban con BOM y ninguno cargaba.

La causa fue `Set-Content -Encoding UTF8` en PowerShell, que mete el BOM. Para
escribir a mano hay que hacerlo sin el:

```powershell
[System.IO.File]::WriteAllLines($p, $l, (New-Object System.Text.UTF8Encoding $false))
```

Y para revisarlo, buscar el BOM en el fichero entero:

```powershell
$b = [System.IO.File]::ReadAllBytes($f)
if ($b[0] -eq 0xEF -and $b[1] -eq 0xBB) { "TIENE BOM" }
```

### EL BACKTICK DE POWERSHELL ES CARACTER DE ESCAPE

Este es el hermano del BOM, y **borro `AGENTS.md` entero de un paso**.

En PowerShell, dentro de una cadena con comillas dobles, **el backtick es el
caracter de escape**, igual que la barra invertida en C. Y nuestros `.md` estan
llenos de backticks, porque el codigo se escribe en markdown inline.

| | |
|---|---|
| Comillas simples `'...'` | el backtick es literal, **funciona** |
| Comillas dobles `"..."` | `D, `) y `n se comen, **no es lo que parece** |

Un `.Replace()` con el `oldString` mal escrito **no da error: no reemplaza nada**.
Y si el `newString` tambien se malescapo, se come los caracteres de al lado, que en
nuestro caso fueron **todas las barras de las tablas**. `AGENTS.md` paso de 204
lineas con `|` a **0**, y el fichero quedo como prosa corrida.

**Como se recuperar:** `git checkout -- AGENTS.md` y rehacer el cambio con la
herramienta de edicion, que trata las cadenas como literales y no escapa nada.

**La regla practica: para tocar el texto de los `.md`, usar la herramienta de
edicion, no PowerShell.** PowerShell queda para lo que no lleva backticks: contar
lineas, correr el autotest, hashear ficheros, `git`. Si hay que reescribir un
`.md` entero, es con la herramienta de edicion.

### El Lua de Fightcade es 5.1, NO 5.3/5.4

Confirmado en ejecucion: escribir `a & 0x7F` da el error de parseo
`')' expected near '&'`. **No existen los operadores bitwise nativos.**

| No usar | Usar en su lugar |
|---|---|
| `a & b`, `a \| b`, `~a`, `a << b`, `a >> b` | `bit.band`, `bit.bor`, `bit.bnot`, `bit.lshift`, `bit.rshift` |
| `a // b` (division entera) | `math.floor(a / b)` |

La libreria `bit` (LuaBitOp) si esta disponible: el training mode la usa en
todos sus modulos. Preferir `bit.band` sobre operadores nativos aunque el
emulador los acepte, para que el script no dependa de la version de Lua.

Igual de importante: **`joypad.get()` devuelve una tabla donde solo estan las
teclas pulsadas.** Las no pulsadas son `nil`, no `false`. Por eso hay que
comprobar con truthiness (`if pad["P1 Button A"] then`), nunca con
`~= nil` ni `== true`.

BizHawk **no** tiene nada de esto: nada de `mainmemory.read_s16_be`, `client.*`
ni `event.onframestart`. No portar esos scripts, reescribirlos.

### Fightcade

- Fightcade `2.1.45`, FBNeo `v0.2.97.44-55`.
- Source de referencia: `fightcadeorg/fightcade-fbneo`, commit
  `c95950140e2424643a0bb589dc444f0defe03155`.
- Work RAM 68k mapeada 1:1 y reflejada cada `$010000` entre `$E00000` y
  `$FFFFFF`: `0xFF84B8` se lee directo desde Lua.
- El ROM se carga con `SEGA_MD_ROM_LOAD16_WORD_SWAP`, pero la vista del 68000
  es big-endian native: `memory.readword` no necesita deshacer el swap.
- `md_yuyumte` = T-Eng ingles de Jon Najar, CRC32 `0x0F041D2E`, `0x300000` bytes.
  `md_yuyumt` = japones, CRC32 `0x71CEAC6F`.

---

## Pendiente (lo siguiente que hay que hacer)

1. **Medidor de super**: `$B8` (maná/TA, tope 223) es casi seguro lo que se
   pide, pero falta confirmar en ejecucion si el juego lo llama TA o super.
   El stun ya esta en `$7E`/`$80`.
2. **Frame data**: ya no hace falta medir en ejecucion. El registro de frame son
   **8 bytes** (`loc_01EB40`, `0x1EB48`), `+0` es la duracion (`-> $5A`) y el bit 6
   del byte de atributos marca los frames activos. Las 12 bases estan en
   `TABLAS_MOVES_Y_TIMING.md` §2. Falta el parser.
3. **Blockstun**: la **direccion** sigue sin localizar. Los tres resolvers van a
   dano. El **valor 32 se midio en ejecucion** y es coherente con la escala
   (28 clash > 16 golpe), pero sin direccion no se puede implementar leyendo
   el codigo: queda como medicion, no como dato. Candidatos: **`$71` bit 1
   (el UNICO con mecanismo demostrado: elige `$2C`/`$2D` en `0x1F3F6`, y de ahi
   sale si el siguiente golpe pega completo o reducido)**, `$63`, `$64` bit 5,
   `$6C` bits 0-5. Ver `TABLAS_MOVES_Y_TIMING.md` §6.
4. **Stun real por golpe**: `$7E` es un **presupuesto**, no un timer. Los golpes
   hasta knockdown son `ceil($80/$66)`, ya calculable. Ver §4 de
   `TABLAS_MOVES_Y_TIMING.md`. Falta igual medir para confirmar.
5. **Jugador 2**: la config `md_yuyumte.ini` tiene 7 entradas de P2 apuntando a
   `switch 0x08` y `Button Z` duplicando P1. Remedir desde el menu de mandos de
   Fightcade, no editando el `.ini`.
6. **Calibrar la conversion caja -> pantalla**: correr el probe y ver si
   `box - cam` alinea con los sprites. Si no, ajustar `CAL_X` / `CAL_Y` en
   `LLUVIA RECTA.LUA`. Ojo: `box - cam` **no** basta, ver la nota de
   coordenadas en el propio script (falta el termino de `$A014`).
7. Gravedad, contacto con el suelo. Y el **hit-time de las especiales**, que no
   aparece ni en `$69` ni en `$F558`. **`$26` ya quedo descartado** (prende en
   todo contacto porque es el frame de la animacion de empuje; ahora se sabe que
   es un contador de programa sobre 8 flujos, con opcodes, y solo 6 codigos de
   154 bytes).
8. **Base del slot de P2: `$FF8800` o `$FF9000`.** Hay una medicion externa que da
   `$9000` (los tres `.lua` del material lo usan) y nuestra inferencia da
   `$8800`. **La medicion pesa mas**, y el argumento que teniamos en contra era
   invalido. Volcar los 4 slots y ver cuales tienen HP/stun/maná. Ver la seccion
   de slots. **`detectar_slots()` ya esta puesto** asi que cualquier `.lua` que
   lea del slot del P2 no depende de esta respuesta. Lo que falta es saber cual
   es el caso **habitual**: el HUD dibuja igual con las dos.
