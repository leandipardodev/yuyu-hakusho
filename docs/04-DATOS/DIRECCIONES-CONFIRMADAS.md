# Las direcciones confirmadas

*No volver a buscarlas: aqui estan con su contexto.*

---
## Direcciones confirmadas (no volver a buscar)

### Jugador

| Dato | Valor |
|---|---|
| Base del slot P1 | `$FF8400` (`tst.l $ffff8400.l` en `0x10D2C`) |
| Base del slot P2 | `$FF8800`, stride `$400` — **CONFLICTO SIN RESOLVER, pero YA MEDIDO que cambia: en la misma sesion se vio S1+S2 y S1+S4. `detectar_slots()` lo agarra por HP. Ver la seccion de slots** |
| Registro base del struct | `a5` |
| Plano / capa | `$26`; en realidad es un **contador de programa** sobre uno de 8 flujos de bytes. `$0A` elige cual (1 a 8), la tabla de punteros esta en `$3A256` (ver `VERIFICACION.md` §5c) |
| Contador de combo | **`$C6`**, en el **DEFENSOR**, tope 16 (ver la seccion de `$C6`) |
| HP actual | word **SIGNED** en `$78`; llega a **`-1024`** (`$FC00`) al final de la pelea |
| HP maximo | **223** `[MEDIDO]`. `$78` se inicializa a `$FF` (255) en `0x12AE6` / `0x13688`, y **que de ahi salga 223 no esta escrito en ningun sitio** — pendiente abierto. Ver `VERIFICACION.md` §2 |
| Umbral de vida baja | **111** (`$6F`), **11** comparaciones. Hay un **segundo** umbral, **112** (`$70`), en `0x15784` |
| HP dibujado | **`$7A` es la BARRA ANIMADA**, no el HP: persigue a `$78` de a 1 por frame (`0x157A8`). Si HP < 112 toma `$C00E` |
| HP que se dibuja | word en `$7A` (persigue a `$78`, `0x1579C`) |
| Maná / TA (recurso gastable) | word en `$B8`, max **223** (`$DF`) en `0x1A2E2` |
| Umbral de maná bajo | 32 (`$20`), `0x1CD70` |
| Stun actual / maximo | `$7E` / `$80` (words) |
| Posicion en pantalla | `$08` / `$0C`, **calculada y CLAMPADA por `loc_0156F0`** (`0x15700`-`0x15746`). **No hay que recalcularla ni calibrarla**: ver la trampa de `CAL_X`/`CAL_Y` |
| Posicion en mundo | `$40` / `$44` = **16.16 con la parte ENTERA en la palabra de direccion baja**. `$42` / `$46` = **la fraccion**, no la "mitad alta". Ver `VERIFICACION.md` §3f |
| Offset de empuje del frame | `$54` / `$56` |
| Velocidad | `$28` / `$2A` |
| Facing | `$61` |
| Id de move | `$5F` |
| Anim frame / dur / tick | `$59` / `$5A` / `$5B` |
| **`$69`** | **NO es hitpause: es SUPRESION DE HITSTUN POR PERSONAJE**, no un freeze. Esta en el struct (`$69(a5)`, 30 accesos), asi que en un 1v4 cada slot tiene el suyo y un golpe solo toca a los dos involucrados. Y **no hay freeze global en un golpe normal**: el unico escritor de `$F558` en todo el ROM es `0x1FA82: move.w #$a0` = 160, la muerte. Valores: **16** golpe (`0x1F2E0`), **28** clasheo (`0x1F15E`, **no 32**), **255** ulti (`0x1C078`). Se le decia "hitpause" porque `$F558` vale 16 tambien en un golpe: dos campos con el mismo numero en el caso que mas se ve. **[MEDIDO]** con hitstun activo el personaje **se mueve** 1 px por frame, asi que no hay congelacion |
| La oscilacion de 1-2 px del hitstun es desplazamiento | **No: es `$54`, offset de DIBUJADO de un frame.** El signo alterna con la **paridad de `$69`** (`btst.b #$0`) y la amplitud es `$6A` (`add.w d0, $54` / `sub.w d0, $54`, 16 sitios), y se limpia una vez por frame en `0x15718`. **[MEDIDO]** coordenadas constantes mientras el sprite oscila: prueba directa |
| `$6A` es un campo mas de estado | **Es el NIVEL DE EMPUJE y hace DOS cosas:** manda la amplitud del vaiven visual (`$54`) **y** es la magnitud del empuje real. **Decrementa cada frame hasta 1** (`0x12B44`). Por eso "la repulsion se multiplica y decrece" era una sola variable |
| El mismo golpe da siempre el mismo resultado | **Falso, y NO es error de los `.lua`.** Y **NO son 2 variables: es UNA, el frame activo que conecta.** Se ha reproducido en **distintos emuladores** y con **savestates que siempre cargan en el mismo punto**, y se ve a ojo sin ningun `.lua`: en el frame 1 la victima ya aparece mas alejada. **MEDIDO:** un B causa **5 a 8** de daño, un combo completo va de **71 a 86** (15 puntos, **mas del 20 %**), y el pusheo va de **1 a 4 px**. **O sea que el pusheo varia MUCHO mas que el daño**, y nunca se vio un golpe que saquen el doble. **MECANISMO:** `$65` (daño), `$66` (stun) y `$64` (empuje) se leen **los tres del mismo registro de 8 bytes del FRAME ACTIVO** con `(a2)+` en `0x1EC0E`-`0x1EC16`, asi que **un B con mas de un frame activo tiene un `$65` y un `$64` distintos en cada uno**. Eso explica el 5-vs-8, el 1-vs-4 px **y la correlacion entre ambos de una sola vez**. **Y NO HAY ESCALADO POR COMBO:** el camino completo resta `$65` crudo (`0x1F420`), sin multiplicador y sin mirar `$C6`. El 20 % entre combos sale de que conectaron frames distintos. Ver `VERIFICACION.md` §2d |
| Tabla de moves | puntero en `$8C` (12 bases, ver `MOVES-Y-TIMING.md`) |
| **`$65`** | **Daño del move, POR FRAME ACTIVO.** Se lee en `0x1EC0E` con `(a2)+`, del **mismo registro de 8 bytes** que `$66` y `$64`. El camino completo lo resta crudo (`sub.w d0, $78(a4)` en `0x1F424`, con `d0 = $65` en `0x1F420`), **sin escalado** |
| Daño de stun del move | `$66` (`sub.w` a `$7E` en `0x1F42C`), tambien por frame activo |
| **`$63`** | **Mascara del DEFENSOR. Elige el camino del daño y si el golpe ATURDE.** Tres valores, `$00` / `$04` / `$08`, decididos por `cmpi.b #$2d, $5f(a5)` en `0x15B58`. Se cruza en `0x1F320` (`and.b $63(a4), d0` con `$64(a3) & $0C`): **`== 0` completo con stun, `!= 0` reducido sin tocar `$7E`**. **OJO: el reducido es el perfil del chip damage / golpe bloqueado (2x a 3,4x menos), y NO explica la variacion del B** (para `$65` = 8 daria 3, y el minimo medido es 5) |
| **`$64`** | **Cuarto byte del registro del FRAME ACTIVO** (`0x1EC16`, solo con bit 6 del atributo). **Es del MOVE, no del personaje.** Sus **bits 0-1 eligen la intensidad del empuje**: hay 4 niveles, y **una tabla distinta por camino** — reducido `$2B000`/`$39000`/`$4C000`, completo `$30000`/`$40000`/`$56000`. Sus **bits 2-3** son la mitad del AND de `$63` que decide el daño, y el **bit 4** decide si el golpe hace daño reducido o ninguno |
| **`$71`** bit 1 | **Elige el estado del DEFENSOR entre `$2C` y `$2D` en `0x1F3F6`** (`btst.b #$1, $71(a4)`), y de ahi sale si el siguiente golpe pega completo o reducido. **Es el mejor de los cuatro candidatos a blockstun: el unico con mecanismo DEMOSTRADO** (los otros tres solo se deducen). `$2D` ademas es uno de los seis estados que resetean el combo `$C6` |
| Empujón (long) | `$14` = `move.l #$FFFC0000/$FFFB0000/$FFFA0000` |
| ID de personaje | **`$9E`**, no `$9C`. Ver la trampa de abajo |
| Suelo del plano | **`$9C`** = 320 (delantero) / 304 (atras). Copiado a `$44` con `move.l $9c(a5), $44(a5)`, que es **la rutina de "ponerse en el suelo"** del juego: esta copiada en **14 sitios** |
| El teleport de Itsuki | Estado **`$A4`** de ctx6 (base `$0CF99A`), frames en **`$0D044A`** (14 frames, 37 ticks). El teleport (16 de mana, `$0190D2`) pone `$5F=$A4` y `$5D=$26`. **MEDIDO**: la Y del ancla SIEMPRE es 320 = el suelo, y el teleport coloca X en la zona. Lo que manda al personaje al aire es **el dash** (8 de mana, `$01904E`), que dispara el 'ARRIBA' del comando al terminar y pone `$5D = $25` (salto de 80 px, 70 frames en el aire). El **unico** escritor de `$5D = $25` en todo el ROM es `$01905E`. Fix: `$019061` de `25` a `03` (el handler de `$03` = `$019F90` acaba en `$18440` = estado `$00`, reposo en el suelo). Las 3 fases del teleport: `$A4` (blink, `$0D044A`, 37->22 ticks), `$A5` (colocacion, `$0D04BA`, 45->25 ticks), `$25` (el aire, `$0CFE4A`, durs 4,4,8,255 = espera indefinida). Ojo: **`$01926A` NO es la ruta del teleport** (pone `$A5` sin colocar nada) | **EL MASH DEL ATURDIMIENTO**: estado `$0C`, handler en `$01A282`; barra `$7E` = 255 (4,25 s), contador real `$84`; cada frame -1 y cada pulsacion de boton -2 mas (`$01A29A`) y +2 ticks al frame (`$01A2A6`). Con -2 hacen falta ~128 pulsaciones; con el parche (-3) ~85. Parche `mash_aturdimiento_x15`: 2 bytes, `$01A29A` `$55`->`$57` y `$01A2A6` `$54`->`$56` (el mash cuenta x1,5: -3 por pulsacion). **OJO: el dato de SUBQ/ADDQ va en los bits 11-9 del opcode, no en un byte aparte** ($53=1, $55=2, $57=3, $59=4). |
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

Detalle completo en `COLISIONES-Y-HITBOXES.md`.

---

