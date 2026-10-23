# BITACORA DE SESIONES

Lo que se averiguo en cada sesion, para no volver a buscarlo. Los datos
tecnicos con su direccion estan en los docs de `1-datos/`; aqui queda el
**como seccion y que se concluyo**, que es lo que se pierde.

Indice de sesiones:

| Sesion | Tema | Resultado |
|---|---|---|
| [S-2024-10-21](#s-2024-10-21) | el teleport de Itsuki y el mash del aturdimiento | 4 parches |
| [S-2024-10-21b](#s-2024-10-21b) | **reversion**: el rival vuelve a nacer en el plano de atras | 1 receta quitada |

---

<a name="s-2024-10-21"></a>

## S-2024-10-21: el teleport de Itsuki y el mash del aturdimiento

### Que se pedia

1. *"que itsuki al terminar el tp no aparezca en el aire sino en el piso"*
2. *"la parte de 45 ticks baje a 25 ticks"*
3. *"las teclas mashed cuenten x1,5, ahora es casi imposible sacarlo"*
   (el aturdimiento tras el knockdown dura ~4 s)

### Que HABIA documentado antes de la sesion

Muy poco, y solo de la fase 1:

| Lo que | Donde |
|---|---|
| el teleport de Itsuki = estado `$A4` de ctx6, bloque de frames `$0D044A`, 14 frames, 37 ticks | `TECNICAS.md` §1.9, `VERIFICACION.md` |
| que el teleport cuesta 16 de maná y tiene 3 zonas (A/B/C) | notas del usuario |
| el mapa frame a frame del teleport (frame 36 = "aparece en la zona", frame 61 = "vuelven las cajas", frames 61-65 = "está en el aire") | notas del usuario, **sin interpretar** |

**Todo lo demas es nuevo**: las 3 fases, el bloque de colocacion con las
zonas absolutas, el "aire" de 80 px, el mecanismo del mash, y las 4 recetas.

### Los 4 parches que salieron

| Receta | Que hace | Bytes | Direccion |
|---|---|---|---|
| `13_itsuki_teleport_40mas_rapido` | el blink del teleport: 37 -> 22 ticks | 8 | `$0D044A`... |
| `14_itsuki_teleport_pisa_el_suelo` | el teleport termina plantado en el suelo | 1 | `$019061` |
| `15_itsuki_teleport_colocacion_rapida` | la colocacion: 45 -> 25 ticks | 9 | `$0D04C2`... |
| `16_mash_aturdimiento_x15` | el mash del aturdimiento cuenta x1,5 | 2 | `$01A29A`, `$01A2A6` |

### El teleport: las 3 fases (MEDIDO con la sonda)

| Fase | Estado | Bloque de frames | Ticks | Que pasa |
|---|---|---|---|---|
| 1. el blink | `$A4` | `$0D044A` | 37 -> **22** | invisible e invulnerable |
| 2. la colocacion | `$A5` | `$0D04BA` | 45 -> **25** | aparece en la zona, **en el suelo** |
| 3. el "aire" | `$25` | `$0CFE4A` | 4,4,8,**255** | 80 px de salto + espera colgado |

**La colocacion** (`$01BE08`): `move.b #$a5, $5f(a5)`, `move.l $9c(a5),
$44(a5)` (al suelo) y `move.w d0, $40(a5)` con el destino segun la zona
`$48` (0/1/2) = `$a010` + `$20` / `$A0` / `$120` = **912 / 1040 / 1168**
(128 px de separacion, como dicen las notas).

**El "aire" NO es del teleport**: es el **dash** de Itsuki (8 de maná,
`$01904E`), que dispara el "ARRIBA" del comando (abajo+arriba+A/B/C) al
terminar. El unico escritor de `$5D = $25` en todo el ROM es `$01905E`.
Con la receta 14 el teleport no pasa por ahi.

**MEDIDO con `sonda_teleport.lua`** (Itsuki, slot 1, zona C):

```
[f 58761] $5F=A4  mundo X=895  Y=320  suelo $9C=320  pant 279,315
[f 58798] $5F=A5  mundo X=896  Y=320  suelo $9C=320  pant 279,315
[f 58799] $5F=A5  mundo X=1048 Y=320  suelo $9C=320  pant 432,315   <- la zona
[f 58836] $5F=25  mundo X=1048 Y=320  suelo $9C=320                 <- el salto
[f 58853] $5F=25  mundo X=1049 Y=314  ...
[f 58880] $5F=25  mundo X=1090 Y=240  ...                          <- 80 px arriba
[f 58906] $5F=28  mundo X=1129 Y=320  ...                          <- vuelve al suelo
```

### El mash del aturdimiento (CODIGO)

El estado `$0C` es el "aturdido" que queda tras el knockdown. Handler en
**`$01A282`**:

```
$01A282  move.w   #$ff, $7e(a5)   ; la barra = 255 frames (4,25 s)
$01A288  move.l   $9c(a5), $44(a5)  ; al suelo
$01A28E  subq.w   #$1, $84(a5)    ; -1 por frame
$01A292  cmpi.b   #$0, $72(a5)    ; ?boton pulsado?
$01A29A  subq.w   #$2, $84(a5)    ; <-- EL MASH: -2 mas por pulsacion
$01A2A6  addq.b   #$2, $5b(a5)   ; <-- +2 ticks al frame
$01A2AA  cmpi.w   #$1, $84(a5)    ; ?llego a <=1? -> se levanta ($18440)
```

**El contador real es `$84`** (word), NO la barra `$7E` (esa solo la baja
el dano de los golpes, en `$01F42C`). Con 255 frames y -2 por pulsacion
hacen falta **~128 pulsaciones**: de ahi el "casi imposible".

El parche pone los dos `2` en `3` (x1,5) -> **~85 pulsaciones**.

**El mash es UNO solo en todo el ROM** y el estado `$0C` es generico: el
cambio afecta a los 11 personajes.

### Lo que se aprendio del metodo

1. **La sonda LUA es lo mas rapido para los dados que estan en la RAM.**
   `herramientas/lua/sonda_teleport.lua` (nueva) imprime frame a frame `$5F`,
   `$59`, `$5A`, la Y en mundo, el suelo `$9C`, la posicion en pantalla, el
   offset de dibujo `$2A`, vx/vy y los flags `$60`/`$89`/`$48`. Con eso se
   vio en un rato que la Y nunca se salia del suelo y que el "aire" era
   otro estado.
2. **El desensamblado del proyecto (`datos/desensamblado_68000.asm`) se
   come el inmediato de `SUBQ`/`ADDQ`**: el dato va **en los bits 11-9 del
   opcode**, no en un byte aparte. `$53` = 1, `$55` = 2, `$57` = 3,
   `$59` = 4. Por eso "cambiar el 2 por el 4" es tocar **el primer byte**.
3. **El .asm del proyecto omite alguna linea** (a `$01A288` no aparece el
   `move.l $9c(a5), $44(a5)`). Para el codigo critico, **Capstone es la
   verdad** (el proyecto lo usa como fuente, pero el .asm guardado no
   siempre coincide).
4. **Una duracion de frame de 255 = "espera"**: el frame se repite hasta
   que algo lo corte. Es la marca de los estados de espera (el "aire" del
   teleport, el dash, `$26`/`$27`).
5. **`$5D` = el estado siguiente.** El dispatcher de `$015A5A` lo lee y
   salta a la tabla de handlers `$15a68` (256 entradas, una por estado).
   Los handlers de Itsuki estan en `$019xxx`-`$01Cxxx`.
6. **Las 3 fases del teleport tienen su propio bloque de frames**, y el
   byte+0 de cada registro es la duracion: cambiar solo ese byte acorta
   la fase sin tocar nada mas.

### Lo que quedo PENDIENTE

1. **El handler de `$A5` de Itsuki**: es el que cambia `$5D` a `$25` al
   final de la colocacion, y no se ha localizado (la tabla `$15a68` lleva a
   `$0167DF`, que es una tabla de datos, no codigo). Con el se podria
   hacer la **variante "solo el teleport"** de la receta 14, sin tocar el
   dash de 8 de maná.
2. **La receta 14 tiene un efecto colateral**: mata el estado `$25` siempre,
   o sea que el **dash de Itsuki (8 de maná) deja de hacer su salto y su
   espera**. Si el dash es una tecnica que se usa, hay que hacer la
   variante del punto 1.
3. El aturdimiento **base** (sin machar) son 255 frames = 4,25 s. Se
   puede bajar a 1 byte (`move.w #$ff` -> `#$80` = 2,1 s) si se quiere.
4. Habria que mirar si el mash deberia contar tambien el boton de
  Directions (`$71`/`$73`): ahora solo mira `$72`.

### Un aviso sobre las recetas 13 y 15

Las dos tocan **duraciones de frame**, que es el mismo byte (`byte+0`) que
usa el grupo `kage_dur` para el especial de Itsuki. No se solapan (bloques
distintos) pero conviene recordarlo al tocar el frame data de ctx6.


<a name="s-2024-10-21b"></a>

## S-2024-10-21b: el rival vuelve a nacer en el plano de atras

**Pedido:** *"quiero volver atras el cambio de cruzar enfrente"*.

**Que era:** la receta `09_rival_nace_delante` (grupo `rival_delante`,
8 bytes) hacia que el rival de la CPU naciera en el **plano delantero** (320)
y a su **tamano normal** (escala 256), en vez de en el **plano de atras**
(304) y mas pequeno (escala `$D8` = 216).

**Como se analizo:** con Capstone sobre el ROM base y la unificada, en las 4
inicializaciones del rival:

```
$00AA8C  base      : move.l  #$1300000, $9c(a0)   (304, atras)
$00AA8C  unificada : move.l  #$1400000, $9c(a0)   (320, delantero)
$00AA94  base      : move.w  #$d8, $3e(a0)        (escala 216)
$00AA94  unificada : move.w  #$100, $3e(a0)       (escala 256)
```

Los 8 bytes tocados: `$00AA8F` (`30`->`40`), `$00AA96` (`00`->`01`),
`$00AB0F`, `$00AB16`, `$00FB1D`, `$00FB24`, `$00FBA3`, `$00FBAA`.

**Que se hizo:** se quito la receta de `datos/recetas.json` (de `cambios` y
de `aceptados`) y el grupo de `datos/parches.json`, y se reconstruyeron las
ROMs. **Verificado byte a byte**: la unificada vuelve a tener los 8 bytes
iguales que la base, y las 4 instrucciones vuelven a ser
`move.l #$1300000, $9c(a0)`.

**Ojo:** esto **no** toca `un_plano` ni `sin_cruce`, que son otra cosa (el
cruce de planos durante la partida). El usuario quiere que el rival nazca en
su arena, pero el juego sigue sin dos arenas.


<a name="s-2024-10-21l"></a>

## S-2024-10-21l: el proyecto restaurado y los atajos, sin tocar los saltos

**Lo que paso:** el usuario probo la receta 18 y el juego se rompio
("moviste todos los golpes, el adelante A se hace con abajo A, hiei salta
muy poca distancia").

**El error mio:** los 22 `bne.w $1886a` / `bne.w $18880` que cambie **no
son los atajos**: son **el MOVIMIENTO con C y con Y en cada direccion** (el
"adelante A" usaba el `$84`). Al mandarlos todos al `$83` (4-8 frames) se
rompieron todos los saltos.

**Ademas se descubrio que la ROM china YA TIENE EL PROYECTO APLICADO** (los
mismos bytes que la unificada): por eso al parchar la unificada completa
sobre ella el patcher aborta ("29 bytes no coinciden con lo esperado",
porque ya estan en su valor final). Y por eso **a la china le falta el
grupo `un_plano`** (el que desactiva el cruce de planos) — que es
justamente lo que el usuario veia ("en la china si se puede cruzar
enfrente").

**El estado del proyecto se restauro** (reset a `75ef120`, el commit previo
a esta sesion; las ROMs se reconstruyeron; las ROMs `18*`/`19*` de las
versiones rotas se borraron). Quedo una rama `desastre-cruce` con el estado
anterior, por si acaso.

**La receta 19 (23 bytes) hace el cambio donde toca:**
- Los 12 `btst.b #$4, $72(a5)` (el boton C) y los 10 `btst.b #$6, $72(a5)`
  (el boton Y) del bloque "C o Y": se cambia **el byte alto del inmediato**
  (el bit que se prueba) del 4 o del 6 al **3**, un bit que **el juego no
  prueba en ninguna instruccion de todo el ROM**. Los saltos no se tocan.
- `$015DF1`: el inmediato del atajo global C+B+Y (`$70` -> `$71`).

**Las ROMs de la china:** `19_china_sin_cruce.bin` (la china + `un_plano` +
los 23 bytes) y `20_china_UNIFICADA.bin` (la china + todo el proyecto).


<a name="s-2024-10-21m"></a>

## S-2024-10-21m: el numero de bit del btst (el ataque con A se rompio)

**Sintoma del usuario:** *"no anda ninguna combinacion con el boton abajo, si
apreto abajo + A o B no golpea, solo se agacha"*.

**El error mio (v1 de la receta 19):** el inmediato de 16 bits del `btst` va en
**DOS** bytes:

```
08 2D 00 04 00 72   =   btst.b #$4, $72(a5)
        ^  ^
        |  +-- el byte BAJO = la MASCARA (los bits que se prueban): $04 = el bit 2
        +----- el byte ALTO = el NUMERO DE BIT (bits 8-11): $00 = el bit 0
```

Yo cambie **el byte de la mascara** (en salto - 3): `$04` -> `$03` (los bits
2,1 -> el bit 0) ⇒ **el atajo paso a mirar el boton A** ⇒ se rompieron los
ataques con A y B (el bit 0 = A, el bit 1 = B) y el atajo dejo de
dispararse con C.

**El fix (v2):** cambiar **el byte ALTO** (el numero de bit, en **salto - 4**)
de `$00` (bit 0) o `$01` (bit 1) a **`$07`** (el bit 7). Ese bit **no lo
escribe ni lo prueba ninguna instruccion del juego** (0 usos), asi que el
btst es siempre falso y el atajo nunca se dispara. **La mascara no se
toca**, asi que los ataques con A, B y C siguen exactamente igual.

**El mapa de los botones** (deducido): bit 0 = A (ataque fuerte), bit 1 = B
(ataque debil), bit 2 = C (defensa), bit 3 = X, bit 4 = Y (linea), bit 5 = Z
(dash), bit 7 = nunca se usa.

**Los tres atajos del cruce:** el movimiento `$84` (el boton C), el `$86` (B+C)
y el `$AA` (el global C+B+Y, en `$015DEE`). Los tres quedan desactivados.

<a name="s-2024-10-21n"></a>

## S-2024-10-21n: el Lua de diagnostico + el parche inerte (la bit mask leida bien)

**Prueba del usuario de `19_china_sin_cruce.bin`:** *"arranca y golpea, se
puede cruzar tambien"*. O sea: la ROM arranca, los ataques con A y B
funcionan, **pero el cruce de planos sigue disponible**.

**El motivo (error mio de la sesion anterior):** el inmediato del
`btst.b #n, $72(a5)` es un **WORD = el NUMERO DE BIT**, no una mascara. Los
bytes son `08 2D 00 04 00 72` = "prueba el bit 4". La receta 19 cambiaba el
**byte alto** de ese word (`$00` -> `$07`, en `salto - 4`), y como en la 68000
el numero de bit de un operando de 1 byte se usa **modulo 8**, `$0704` sigue
probando **el bit 4**: **el parche era inerte**. (El atajo global de
`$015DF1` si que surte efecto: ese si es un inmediato de 1 byte.)

**Lo que se ha descubierto ademas (todo con direccion):**
- Los 22 `btst` del bloque "C o Y" de los 11 dispatchers por personaje
  prueban **el bit 4** (-> moves `$80`, `$81`, `$84`, `$90`) o **el bit 6**
  (-> moves `$82`, `$86`, `$87`, `$94`, `$95`). El **bit 6 tambien decide los
  ataques** (en direccion ARRIBA crea el proyectil), asi que **el bit 6 no
  se puede tocar**.
- El "atajo de arriba+C" = direccion ARRIBA + bit 4 = **el move `$81`**
  (`$01883E`).
- Los **bits 0, 1 y 7** de `$72(a5)` no los prueba nadie en todo el ROM: el
  **bit 7** es el unico "libre" para dejar un `btst` siempre falso.
- El **atajo global** (`$015DEE`) son los **bits 4, 5 y 6** de los botones
  **mantenidos** (`$73`), y **no** es el cruce: pone el estado `$00` y el
  move `$14`.
- El **CRUCE** = estado `$0A` + move `$0F` (ida) / `$10` (vuelta), handler
  `$019E08`. Los **dos unicos** sitios que ponen el estado `$0A` son
  `$0186F2` y `$01873A`, y **`$0186BE` no lo llama nadie** de todo el ROM:
  es un punto de entrada muerto. **El cruce hay que averiguarlo en el
  emulador.**
- El move `$AA` lo pone `$018748` (dentro del bloque del cruce) y tambien
  `$01B444` (tras un `btst` del **bit 5**); el move `$A8`, `$01C01E`.

**Lo entregado:** `herramientas/lua/sonda_cruce.lua` (para FBNeo). Al
arrancar lee la ROM y saca la tabla de atajos; cada frame imprime los
botones y las direcciones (con nombre y en hex) y guarda 40 frames de
historial; cuando detecta el cruce vuelca el historial, para ver que boton
lo lanzo. **Probado con un simulador de la API de FBNeo (LuaJIT).**

**Lo que NO se ha hecho (falta permiso):** arreglar la receta 19. El fix
natural es cambiar **el byte bajo** del inmediato (el numero de bit, en
`salto - 3`) a `$07` **solo en los `btst` que lanzan el cruce**, sin tocar
los del bit 6 (los ataques). Falta saber cual es exactamente el move del
cruce: lo dice la sonda.

<a name="s-2024-10-21o"></a>

## S-2024-10-21o: el "" de Sensui (el `bra` no salta nunca)

**Sintoma del usuario:** *"1 frame de sensui al caminar sale mal, como que
aparecen  de el, es solo un frame"* y *"empezo a ocurrir
luego de algun cambio tuyo"*.

**La causa:** el grupo `un_plano` (el que desactiva el cruce de planos)
neutralizaba los TRES bloques del cruce **cambiando el `bne.b` por un
`bra.b`**. Y un `bra` **no salta nunca**: al cambiarlo, el bloque dejo de
saltarse y **se ejecutaba siempre**, con cualquier move. Al pasar el
personaje 1 frame por el estado `$0A` (pasa al cambiar de animacion,
tambien al caminar), el juego ponia **el flag del plano de atras**
(`$A042`) y **el suelo en 304** (`move.l #$1300000, $9c(a5)`) con la escala
`$d8`: el personaje se dibujaba en el otro plano y se veian ** por
detras**.

**El fix:** anular la **condicion**, no el salto: el inmediato del
`cmpi.b #$f, $5f(a5)` pasa a `$ff` en `$019E0B`, `$019E89` y `$019ECF`. La
comparacion nunca es igual, el `bne.b` salta siempre y el bloque no se
ejecuta nunca. **El salto no se toca.** El grupo `sin_cruce` tenia el mismo
error y se ha arreglado igual (`$019E89` y `$019F4D`).

**Ademas:** al construir las ROMs se perdio la ROM china de
`rom/original/`. Se ha|Sportado: **la base del proyecto ES la china** (la
de `$BE4F` es la inglesa, que no arranca) y se ha vuelto a dejar una copia
en `rom/original/` y otra en
`C:\Users\leand\AppData\Local\Temp\opencode\CHINA_ORIGINAL.bin`. Se ha
generado `21_china_UNIFICADA_sin_un_plano.bin` (todo menos `un_plano`) para
el biseccion.

**Pendiente del usuario:** probar la unificada con el fix (el ""
debe desaparecer) y, si sigue, la `21` (sin `un_plano`) para el biseccion.

<a name="s-2024-10-21p"></a>

## S-2024-10-21p: el dao al cruzar (grupo `cruce_dano`)

**Peticion del usuario:** *"mete dao al cruzar"* (1 de vida cada 3 frames,
como se habia pedido al principio del proyecto).

**Lo que se ha descubierto antes (con la sonda del cruce):** el cruce **no
lo dispara ningun boton**. Es la **CAIDA** al otro plano: el estado **`$0B`**
con el move **`$0F`** (el suelo baja de 320 hacia 304, 0.31 px por frame, y la
escala baja 1 por frame) y luego la **VUELTA** (estado `$0A` con el move
`$10`). En la salida de la sonda el cruce ocurrio **sin pulsar nada**
(`botones=$00`): es el **ajuste automatico de plano** del juego.

**El dao (grupo `cruce_dano`, 90 bytes):** el bloque de la CAIDA
(`$019ED4-$019EEB`, 24 bytes) se sustituye por un `jsr.l` a una rutina
nueva de 66 bytes en el hueco libre **`$1A06AE`** + 18 nops (no cambia ni el
tamano ni el flujo). La rutina hace lo mismo que el bloque original y quita
**1 de vida cada 3 frames** (el contador va en `d1`, se reinicia cuando el
tick `$5B` es 0 y se decrementa cada frame; el dano llega en el tercer
frame). Si el HP queda en 0 se resta **otro** 1 para que quede **NEGATIVO**:
el juego solo detecta el KO con el HP negativo (`$019CFC`) y si el HP
llegara a 0 en el estado `$0B` la ronda no acabaria y el juego se colgaria
(por eso el intento antiguo, en la rama `desastre-cruce`, rompia el
arranque).

**OJO - CONFLICTO:** el grupo `un_plano` neutraliza `$019ECF` (el `cmpi.b`
del handler del estado `$0B`) ⇒ con `un_plano` el bloque de la CAIDA no se
ejecuta ⇒ **el cruce no ocurre y el dano no se aplica**. Son las dos
opciones: `un_plano` = sin cruce; `cruce_dano` (sin `un_plano`) = el cruce
cuesta vida.

**El "" de Sensui SIGUE** con el `un_plano` arreglado, asi
que no es (solo) el `un_plano`. Se ha generado la
`24_china_UNIFICADA_sin_hoja.bin` (la unificada sin el parche de la hoja de
Kuwabara, `$0C2EA2` = la duracion de un frame de su cadena) para la
biseccion.

**Pendiente del usuario:** probar la `22_china_DANO_al_cruzar.bin` (el
cruce con el dano) y la `24` (biseccion del "").

<a name="s-2024-10-21q"></a>

## S-2024-10-21q: el "cambio de plano" es el FLAG $A042 (el usuario lo dijo)

**El usuario:** *"algo estas haciendo mal pero ninguno de los dos andan,
seguro estas modificando un valor distinto que el cambio de plano"*.
**Tenia razon.** El "plano" no lo dice el suelo (`$9C`) sino el **flag global
`$A042`** (bit 0 = "delante", bit 1 = "atras"), que esta en la RAM del Z80
(por eso la sonda no lo podia leer). Todo lo anterior (el suelo, la escala
`$3E`) es el suelo fisico.

**EL " POR DETRAS":** los 6 escritores del flag son `bset.b`, que
solo ponen bits y **nunca limpian el otro** ⇒ al pasar de un plano al otro
el flag se queda con **los dos bits a 1** ⇒ el juego cree que el personaje
esta en los dos planos a la vez y **dibuja dos siluetas**.

**El fix (grupo `plano_y_dano`, 76 bytes):** intercambiar los bits en los 6
escritores y en los 2 lectores (`btst.b` de `$0186DA` y `$018722`) ⇒ los dos
bits no pueden coexistir nunca.

**El dano al cruzar:** la misma rutina `$015BD8` (la que actualiza el plano
cada frame, la llama `$015A2E`) se reescribe con 6 bytes mas: al llegar al
plano de atras (`$9C` = 304) llama a una rutina nueva (`$1A06F0`) que quita
**1 de vida** (2 si el HP era 1, para que quede **NEGATIVO** y el juego
haga el KO: si el HP llegara a 0 en ese punto nadie lo vigilantia y la ronda
no acabaria ⇒ **el juego se colgaria**, que es lo que rompia el intento
antiguo).

**Nota:** el cruce es un EVENTO (1 frame), no una duracion ⇒ el dano es **1
vida por cruce**, no "1 cada 3 frames".

**Excluyentes:** `un_plano` (un solo plano) y `plano_y_dano` (el cruce con
dano) no se pueden usar a la vez.

**Pendiente:** probar `22_china_PLANO_Y_DANO.bin` (el cruce con dano y sin
"") y `24_china_UNIFICADA_sin_hoja.bin` (biseccion del "2
cuerpos", por si el parche de la hoja de Kuwabara es el culpable).

<a name="s-2024-10-21r"></a>

## S-2024-10-21r: la ROM 22/23 no arrancaba (mis bytes del flag iban +1)

**Sintoma del usuario:** *"22 y 23 al entrar en combate se ve todo negro no
carga"*.

**Los DOS errores mio:**
1. **El byte del numero de bit de `bset.b #n, $a042.w` es el CUARTO**
   (offset +3), no el tercero: `08 F8 00 <n> A0 42`. Yo cambiaba el byte
   +1 ⇒ **los seis `bset.b` y los dos `btst.b` del flag del plano quedaban
   rotos** (el flag recibia un numero de bit al azar) ⇒ el juego se colgaba
   al entrar en combate.
2. La rutina del plano (`$015BD8`) **crecia 6 bytes** y se comia el codigo
   de `$015C04`. Ahora los `bset.b` (6 bytes) se sustituyen por `jsr.l`
   (6 bytes) y el `bra.b` sustituye al `rts`: **la rutina sigue midiendo
   38 bytes**.

**Ademas se ha descubierto la codificacion de las operaciones con un EA y un
registro:** el byte del registro va **al final** (`move.w $78(a5), d0` =
`32 2D 00 78 00`), y Capstone no lo cuenta ⇒ el verificador los marca
como reescritos aunque la CPU los ejecuta bien.

**El grupo `plano_y_dano` (97 bytes) queda asi:**
- La rutina del plano `$015BD8` (38 bytes, sin crecer) llama a dos rutinas
  nuevas en el hueco libre `$1A06F0`:
  - **'delante'** (12 bytes): `clr.b $a042.w` + `bset.b #$1` + `rts`.
  - **'atras'** (41 bytes): **quita 1 de vida** (2 si el HP era 1, para que
    quede NEGATIVO y el juego haga el KO sin colgarse) + `clr.b $a042.w` +
    `bset.b #$0` + `rts`.
- Los 4 `bset.b` que quedan en los handlers y los 2 `btst.b` (los lectores):
  **intercambian los bits**, para que los dos bits del flag nunca coexistan
  (era el "": el flag se quedaba con los dos bits a 1
  y el juego creia que el personaje estaba en los dos planos a la vez).

**ROMs para probar:** `22_china_PLANO_Y_DANO.bin` (la minima), la
`23_china_UNIFICADA_PLANO_Y_DANO.bin` (la unificada con el fix) y la
`24_china_UNIFICADA_sin_hoja.bin` (la biseccion del "" por si es
el parche de la hoja de Kuwabara).

<a name="s-2024-10-22a"></a>

## S-2024-10-22a: la reorganizacion del proyecto

**Peticion del usuario:** "hagamos algo, vamos a organizar el proyecto. tengo
muchos md pdf etc unamoslos en grandes aristas, decidilas vos, pero unifiquemos
informacion, luego toda la info que tenes para vos direcciones etc y sea dudosa
verifica su veracidad de alguna forma con pistas dentro del codigo etc asi
tenemos info veridica. tambien unifica tu info, el sobrante de pdf y md viejos
los borramos".

**Lo que se ha hecho:**

1. **Backup** de `docs/` + `MEMORIA.md` + `README.md` en
   `C:/Users/leand/AppData/Local/Temp/opencode/backup_docs_2026-10-22.zip`.
2. **Nueve areas** (la decision del asistente): `00-GUIA`, `01-MOTOR`,
   `02-COMBATE`, `03-PERSONAJES`, `04-DATOS`, `05-PARCHES`, `06-HERRAMIENTAS`,
   `07-INVESTIGACION`, `08-DIARIO`. Todo movido con `git mv` (se conserva el
   historial).
3. **Los dos ficheros gigantes se han dividido por areas, sin perder una
   linea**: `DATOS_VERIFICADOS.md` (169 KB, 36 secciones) y `MEMORIA.md`
   (143 KB, 6 secciones). Los dos originales se han borrado y en su lugar
   quedan dos **indices** (`docs/04-DATOS/DATOS_VERIFICADOS.md` y
   `docs/08-DIARIO/MEMORIA.md`) para que los enlaces sigan valiendo.
4. **`herramientas/docs/verificar_docs.py`**: comprueba la documentacion
   contra la ROM base real: los enlaces rotos, las direcciones citadas que no
   son codigo y **las contradicciones** (el doc afirma una instruccion y en esa
   direccion hay otra). **Resultado: 1.400 direcciones citadas, 0 enlaces
   rotos, 0 contradicciones.**
5. **Los errores de la documentacion que ha encontrado** (y corregido):
   `$019C46` -> `$019C4E`; el `move.b $65(a3),d0` esta en `$01F3D8` y no en
   `$01F3E0`; `$01F7D4` -> `$01F7CE`; `$0379FE` -> `$0379B8`;
   `$0379F4` -> `$0379D4`; `$01EBA4` -> `$01EBA6`; `$01EBAE` -> `$01EBB0`;
   `$012AF8` -> `$012AFA`; `$012B00` -> `$012B02`.

**LOS HALLAZGOS IMPORTANTES (todos en `00-GUIA/TRAMPAS.md`):**

1. **LA ROM JAPONESA Y LA CHINA NO TIENEN EL CODIGO EN LOS MISMOS SITIOS.**
   El `.asm` y el volcado del usuario son de la **J**; la base del proyecto es
   la **CHINA**. En `$016106` la J no tiene nada y la china tiene un
   `btst.b #$4, $72(a5)`. **Para parchear, la unica fuente de verdad es la
   BASE** (por eso `patch_rom.py` aborta si el byte "old" no coincide).
2. **El volcado no alinea las instrucciones a pares**: sus direcciones salen
   +2 o -2 (la 68000 exige que cada instruccion empiece en una direccion par;
   si un bloque empieza en impar hay un byte de relleno que algunos volcados
   se comen como parte de la instruccion anterior).
3. **En Lua 5.1 (FBNeo) no existen `~`, `<<`, `>>` ni `&`**: hay que usar
   `bit.bxor`, `bit.lshift`, `bit.rshift` y `bit.band`. Esto rompia dos sondas.
4. **El inmediato del `btst` es el numero de bit** (un word), y en la 68000 se
   usa **modulo 8** para un operando de 1 byte: cambiar `$0004` por `$0704` no
   cambia nada (por eso la receta 19 era inerte).
5. **El numero de bit de un `bset`/`btst` es el CUARTO byte**, no el tercero.
6. **Un `bra` NO salta nunca**: para neutralizar un bloque hay que anular la
   condicion, no el salto.

**Tambien:** la sonda nueva `herramientas/lua/sonda_plano.lua` analiza todo lo
relativo a los planos: mapea la RAM del Z80, busca la bandera del plano
($A042 = el offset $0042 del Z80), avisa cuando tiene los DOS bits a 1 (el
"") y tiene modos para **forzar** la bandera (1, 2 o 3) o **quitar
vida** desde el Lua, sin tocar la ROM.

<a name="s-2024-10-22b"></a>

## S-2024-10-22b: el repo de GitHub

**Peticion del usuario:** *"quiero que crees un repo en github"*.

**Hecho:** `https://github.com/leandipardodev/yuyu-hakusho` (**PRIVADO**),
creado con `gh repo create ... --private --source=. --remote=origin --push`.
237 ficheros, 4,4 MB, rama `main`.

**Lo que se sube:** `docs/` (las nueve areas), `datos/` (el manifiesto de
parches, las recetas y el desensamblado), `herramientas/` (el desensamblado,
las sondas de Lua y los verificadores), `assets/`, `.github/` (las plantillas
de issue) y el `README.md`.

**Lo que NO se sube:** `rom/` (los dumps y las ROMs parcheadas) y `notas/`
(el otro repo del usuario, el diario de investigacion). El `.gitignore` ya
excluia las dos carpetas.

**POR QUE PRIVADO:** el juego es de Treasure, con licencia de Toei Animation
y Shueisha. En `assets/imagenes/` hay volcados de la VRAM/CRAM y capturas
del juego, y `datos/desensamblado_68000.asm` (1,5 MB) es el volcado del
ROM: **si este repo se hace publico, hay que sacar todo eso.**

## S-2024-10-22c: el daño al cruzar, rehecho y verificado

### Lo que se pidio

1. **Borrar todos los datos del "2 cuerpos"**: el usuario dijo que estaba
   mal hecho y que no lo queria. Se borro de toda la documentacion (0
   menciones) y se tiraron los dos parches que habian salido de esa
   hipotesis (`plano_y_dano`, con el intercambio de bits del flag `$A042`, y
   `escala_suave`, el byte de la escala).
2. **Dejar el daño al cruzar** (que es lo que si se habia pedido).

### Lo que se hizo

**El grupo del daño se rehicio desde cero** (`daño_al_cruzar`, 50 bytes):

- El daño va en el **aterrizaje en el plano de atrás** (`$019F52`), que es un
  **evento de un frame**, no en el bloque de la caida (`$019ED4`, que dura
  ~50 frames). Por eso el daño es **1 vida por cruce** (el "1 cada 3 frames"
  venia de una idea equivocada de lo que era el cruce).
- La rutina nueva (30 bytes) esta en el hueco libre `$1A06F0` (los ceros van
  de `$1A06AE` a `$1A0827`).
- El bloque **sigue midiendo 20 bytes**: el `jsr.l` sustituye al `move.w` de
  la escala (6 bytes por 6).

### EL BUG QUE CASO (y el que casi costaba la ROM)

La primera version del bloque **media 22 bytes** (le habia puesto un `nop` de
"relleno"): **podia el `cmpi.b #$10, $5f(a5)` de `$019F66`** y, con ello,
desalineaba todo lo que venia despues. El verificador de desensamblado
**no lo vio**, porque solo comprobaba el tamano de la PRIMERA instruccion de
cada grupo.

**Se ha anadido esa comprobacion al verificador** (`verificar_desensamblado.py`):
ahora avisa si un parche **pisa el opcode de la instruccion de al lado**
(que es el sintoma de "el rango del grupo se pasa de largo"). Es la
comprobacion que faltaba.

### LO NUEVO: EJECUTAR EL CODIGO CON UNICORN

Para escribir la rutina nueva hacia falta codificacion 68000 exacta, y
**capstone no es la CPU** (lee mal el `moveq`, el `cmpi.w`, los `move` con
inmediato y EA...) y el manual no estaba a mano.

**Se ha usado Unicorn** (`herramientas/desensamblado/probar_codigo.py`, nuevo):
se mete el fragmento, se ejecuta con la RAM del juego (A5 = el struct del
jugador) y se mira lo que ha cambiado. Con eso se encontraron:

- que `A5` es el puntero al struct del jugador (`$FF8400`): sin eso el codigo
  no hace nada **y no da error**.
- que en el 68000 **no hay SP: el stack es A7**.
- que Unicorn **no implementa el `TST.B` con un registro que no sea D0**.
- los bytes exactos de cada instruccion (tabla en `docs/00-GUIA/TRAMPAS.md`).

### El resultado, ejecutado

| HP inicial | HP final (con el parche) | HP final (sin el parche) |
|---|---|---|
| 223 | **222** | 223 |
| 5 | **4** | 5 |
| 2 | **1** | 2 |
| 1 | **-1** (negativo: el juego hara el KO) | 1 |

El suelo queda en 304 (`$1300000`), la escala en 216 y el `$26` en `$C0`, igual
que sin el parche.

### Las ROMs

| fichero | SHA1 | |
|---|---|---|
| `rom/cambios/22_china_DANO_al_cruzar.bin` | `41249F21B957C0E8EA4F61A60D4769DBFF8CB3A1` | la china + el daño |
| `rom/cambios/23_china_UNIFICADA_con_DANO.bin` | `CA4117038E368340C7D5CCCC090F04A2FB040A30` | la unificada + el daño |

Las dos verificadas con el verificador de desensamblado: **OK**.

### Lo que falta

- **Las pruebas del usuario** en FBNeo: que al cruzar baje 1 vida y que con
  1 de vida el personaje pierda (el HP negativo).
- El **push** del ultimo commit al repo: el token de `gh` no tiene el scope
  de escritura (`Write access to repository not granted`).

## S-2024-10-22d: el veneno del plano

### Lo que se pidio

El golpe de 1 vida al cruzar se quedaba corto: el usuario quiere **una resta
de HP constante, como si el personaje estuviera envenenado, hasta volver al
plano principal**.

### Lo que se hizo

El grupo `daño_al_cruzar` (el golpe de 1 punto en el aterrizaje) se sustituyo
por **`veneno_plano`** (52 bytes):

- El enganche esta en la rutina **`$015BD8`**, la que actualiza el flag del
  plano `$A042` cada frame. En `$015BF6` el `bset.b #$1, $a042.w` (6 bytes) se
  sustituye por un `jsr.l` a una rutina nueva en el hueco libre `$1A0710`.
- Esa rutina hace lo mismo que el bset (poner el bit 1 del flag) y ademas
  **quita 1 de vida por frame**.
- **El suelo solo vale 304 cuando el personaje esta parado en el plano de
  atras** (durante la caida va por intermedios), asi que el veneno empieza al
  aterrizar y para al volver al plano principal.
- **Solo el jugador 1**: la rutina copia A5 a D0 (`move.l a5,d0`) y lo compara
  con `$8400` (la palabra baja de `$FF8400`). El rival de la CPU esta en otro
  slot y no sufre el veneno.
- Si el HP queda en 0 se resta otro 1, para que quede **NEGATIVO** (el juego
  solo detecta el KO con el HP negativo; si quedara en 0, la ronda no
  acabaria y el juego se colgaria).

### LO QUE NO SE HA PODIDO VERIFICAR

**El `cmpi.w #$8400, d0`**: el core M68K de Unicorn 2.1.4 no implementa el
CMPI (tampoco el `cmpi.w #$0140, $9c(a5)` del propio juego). La codificacion
se ha sacado del patron del juego. **Si en la prueba el rival tambien pierde
vida, o si nadie pierde vida, el fallo esta ahi.**

Lo que SI se ha ejecutado con Unicorn: la rutina del veneno (HP 223->222,
5->4, 2->1 y **1->-1**) y el `move.l a5,d0`.

### Las ROMs

| fichero | SHA1 |
|---|---|
| `rom/cambios/22_china_VENENO_plano.bin` | `688A9A097F39780BD2390DC4EA4063162DDEE4EE` |
| `rom/cambios/23_china_UNIFICADA_con_VENENO.bin` | `14508BD23941B02557F257ADA451AF19ED5C42BC` |

Las dos con el verificador de desensamblado: **OK**.

### Lo que falta

- **La prueba del usuario** en FBNeo: cruzar y ver si el HP baja 1 por frame
  y si para al volver. Y que el rival NO pierda vida.
- Si el veneno resulta muy rapido (60 de vida por segundo), bajarlo.

## S-2024-10-22e: el veneno tambien para el P2 y el final sin vida

### Lo que se pidio

1. El veneno tambien para el **jugador 2** (el usuario va a quitar las
   opciones de la CPU para que el juego sea P1 vs P2: asi que da igual que el
   rival de la CPU sufra el veneno).
2. Que **si el jugador se queda sin vida, vuelva al plano principal o muera**
   (lo que sea mas facil).

### Lo que se hizo

- El veneno se aplica ahora a los **dos slots de los jugadores**: `$FF8400`
  (P1) y `$FF8800` (P2). La rutina compara A5 con `$8400` y con `$8800`.
- **Al quedarse sin vida hace LAS DOS COSAS**: se resta otro 1 (para que el HP
  quede NEGATIVO, que es como el juego detecta el KO), se pone el **suelo a
  320** (vuelve al plano principal) y el **estado a reposo** (`$5D = 0`), que
  es el handler donde el juego mira el HP negativo (`$019CFC`) ⇒ **vuelve y
  muere**.
- Por lo de antes, el `cmpi.w` con un registro es el mismo codigo que ya
  habia (**el usuario lo probo y funciona**), y el "HP = 0" se comprueba con
  un `cmpi.w #$0, d0` (el mismo patron) en vez de un `tst.w`, que no se ha
  podido verificar.

### Lo que se sabe y lo que no

El usuario probo la version 1 (solo el P1) y **funciona**: al cruzar le baja
la vida y al volver deja de bajar. Eso confirma el `cmpi.w` con un registro
en la 68000 real (Unicorn no lo puede ejecutar).

Las ROMs:

| fichero | SHA1 |
|---|---|
| `rom/cambios/22_china_VENENO_plano.bin` | `688A9A097F39780BD2390DC4EA4063162DDEE4EE` |
| `rom/cambios/23_china_UNIFICADA_con_VENENO.bin` | `14508BD23941B02557F257ADA451AF19ED5C42BC` |

## S-2024-10-22f: el veneno para todos y el final sin vida (v4)

### Lo que pasó

La v2 (el P2 con `cmpi.w #$8800,d0` y el HP = 0 con `cmpi.w #$0,d0`) **se rompio
al cruzar el P1** (la pantalla se quedaba en negro) y **al P2 no le pasaba
nada**. Las dos cosas tienen la misma causa:

1. **El `cmpi.w` con un registro no es de fiar.** En la v2, el `cmpi.w #$0,d0`
   (para comprobar si el HP llegaba a 0) disparaba el final sin vida **en cada
   frame**: el personaje volvia al plano principal, se le forzaba el estado de
   reposo y le bajaba 2 de vida por frame ⇒ en dos segundos estaba muerto ⇒
   pantalla en negro. Volviendo al `tst.b` de la v1 (que el usuario ya habia
   probado) se arregla.
2. **El P2 no esta en `$FF8800`.** El material externo dice "P2, stride $C00" ⇒
   el P2 esta en `$FF9000` (o `$FF8800` segun como se armo la partida). Por eso
   la v4 **quita la comparacion de slot**: el veneno se aplica a cualquier
   personaje en el plano de atras.

### Lo que se hizo (v4)

- El veneno se aplica a **cualquier personaje** (P1, P2 o el rival de la CPU).
- Con 0 de vida hace **las dos cosas**: el suelo a 320 (**vuelve al plano
  principal**) y el estado a reposo (`$5D = 0`), que es el handler donde el
  juego mira el HP negativo (`$019CFC`) ⇒ **vuelve y muere**.
- La comprobacion del HP = 0 es con `tst.b d0` (la de la v1, probada).

### Las ROMs

| fichero | SHA1 |
|---|---|
| `rom/cambios/22_china_VENENO_plano.bin` | `688A9A097F39780BD2390DC4EA4063162DDEE4EE` |
| `rom/cambios/23_china_UNIFICADA_con_VENENO.bin` | `14508BD23941B02557F257ADA451AF19ED5C42BC` |

> Con el veneno para todos, **en un 1v1 el rival de la CPU tambien se
> envenena** (y se muere solo). Para probar el P2 hay que jugar P1 vs P2 (que
> es lo que va a hacer el usuario: quitar las opciones de la CPU).

## S-2024-10-22g: el veneno v7 (mueren al quedarse sin vida)

### Lo que se pidio

El usuario probo la v6 (`27_china_VENENO_P1_P2.bin`) y **funciona: le resta
vida al P1 y al P2**. Pidio que, al quedarse con 0 de vida, murieran (opcion 1)
u obliga a volver al plano principal (opcion 2), y que se implemente la mas
facil.

### Lo que se hizo (v7)

**Opcion 1 (los mata), que es la mas facil**: cuando el HP llega a 0 se resta
otro 1 (para que quede NEGATIVO, que es como el juego detecta el KO) y se
fuerza el **estado de reposo** (`$5D = 0`), que es el handler donde el juego
mira el HP negativo (`$019CFC`) ⇒ **mueren en el acto, donde estén**.

**NO se toca el suelo.** La v5 (que ademas ponia el suelo a 320 para
devolverles al plano principal) rompia la partida al cruzar: el suelo a 320 es
lo que rompia (el motor ve un suelo incoherente con el sprite).

### El camino que dejo claro dos cosas

- El **`cmpi.w` con un registro** no es de fiar (Unicorn no lo puede ejecutar
  y en el juego no se comporta como deberia): el "HP = 0" se comprueba con un
  `tst.b`.
- El **slot del P2** no es `$FF8800` (el material externo dice "P2, stride
  `$C00`" ⇒ `$FF9000`): por eso la v6 aplica el veneno a cualquier slot.

### El Lua

`herramientas/lua/sonda_slots.lua` (nuevo): escanea la RAM y encuentra los
personajes con vida, dice el slot de cada uno y su A5 (= el HP - `$78`),
avisa de quien sufre el veneno y tiene un modo `hp1` que deja a un personaje
con 1 de vida para probar el final sin vida.

### La ROM

`rom/cambios/28_china_VENENO_P1_P2_muere.bin` (SHA1 `688A9A09...`).

## S-2024-10-22h: el veneno v8 (el marcador de cadaver $FC00: KO y ronda de verdad)

### El bug de la v7

El usuario lo probo: el HP quedaba en -1 pero **el personaje no moria ni
terminaba la ronda**. Investigacion en `datos/desensamblado_68000.asm`
(ROM J, referencia): el juego NO hace un chequeo de HP negativo por frame.
El HP negativo pasa por el resolver de dano (`$1F4CA`: `cmpi.w #$0, $78(a4)`
-> `blt` -> `jsr $1FA70`, que solo enciende la camara lenta `$F558 = 160`), y
el FIN DE RONDA lo manejan dos rutinas que escanean los 4 slots
(`$FF8400 + n*$400`, firma `$00012668` en el longword 0):

- `$F852` (la fase de combate, `$00F476`): saltea los HP NEGATIVO; avanza
  cuando queda un solo bando (el `$6F`).
- `$F88C` (la fase siguiente, `$00F490`): ADEMAS espera a que el caido tenga
  HP == `$FC00` EXACTO, el marcador de cadaver que escribe el juego al
  aterrizar con HP negativo (`$01A1A4`: `move.w #$fc00, $78(a5)`).

Era la trampa: con HP = -1 (`$FFFF`) la fase `$00F490` lo sigue contando como
vivo y NO avanza nunca. El envenenado esta parado, nunca toca el suelo,
nunca recibe el `$FC00`.

### La v8

El payload (`$1A06F0`, ahora 28 bytes): al llegar el HP a 0 o menos se escribe
`move.w #$fc00, $78(a5)` (el marcador de cadaver) y las dos rutinas pasan al
toque: arranca la secuencia de KO (`$A032 = 1`, el contador `$A03A`, el
mensaje y el ganador). Ademas el payload NO drena si el HP ya es negativo
(`bmi` al inicio), para no romper el marcador de un muerto. No se toca el
suelo ni el estado. Muere parado, donde esta.

### Las ROMs

- `rom/cambios/29_china_VENENO_P1_P2_muere.bin` (la v8, SHA1 `4A51649C...`)
- `rom/cambios/23_china_UNIFICADA_con_VENENO.bin` rearmada con la v8 (SHA1
  `6BA8EBA5...`): la receta de la unificada se confirmo contra el SHA que
  habia (solo diferia en kage_vel, que esta fuera de la unificada).
- la v7 queda como `28` (el anti-ejemplo: no muere).

Verificador de desensamblado: OK en las dos. Pendiente: probar en juego.

## S-2024-10-22i: el tildo de la v8 (una codificacion mala en el payload)

### El reporte

La v28 (v7) drena toda la vida y anda bien, pero el pj no muere. La v29
(v8 del marcador de cadaver) **se tilda el juego cuando uno cruza enfrente**.

### El bug

El payload nuevo tenia UNA instruccion mal codificada. Yo escribi la
instruccion de volver el HP drenado al slot como `30 5D 00 78` creyendo que
era `move.w d0, $78(a5)`. **No lo era**: con capstone, `30 5D` es
`movea.w (a5)+, a0` — el stream quedaba listo mal: el `a0` del frame
processing se pisa con los bytes del slot (la firma `$00012668`) y el HP ni
se escribe. Se rompe en la PRIMERA vez que el hook corre con vida baja, o
sea, al cruzar. La v7 no lo tenia porque usaba `sub.w d1, $78(a5)`
(`93 6D`), que viene del juego.

Un detalle humillante: el verificador de desensamblado dio **OK listo** con
el payload roto, porque desensambla las zonas y no compara SEMANTICAS con la
intencion del parche. La unica red es verificar a mano las instrucciones
escritas a mano.

### El fix (v8b)

Un byte: `30 5D` -> `3B 40` en `$1A06FA`. Regla del encoding de los M68K
`MOVE.W`: destino = reg en bits 11-9 + mode en bits 8-6, fuente = mode en
bits 5-3 + reg en bits 2-0; para `move.w d0, $78(a5)` da `3B40 0078`.

### ROMs rearmadas

- `rom/cambios/29_china_VENENO_P1_P2_muere.bin`: SHA1 `BC355A7A...`
- `rom/cambios/23_china_UNIFICADA_con_VENENO.bin`: SHA1 `80818566...`

**Regla nueva para las skills**: instruccion escrita a mano = CAPSTONE OBLIGATORIO
antes de meterla en el parche.

**EL APENDICE del S-2024-10-22i: la v8b tambien tildaba.** El fix de la v8 arreglo SOLO el byte de $1A06FA (30 -> 3B) y me olvide del siguiente: quedo 3B 5D, que capstone decodifica `move.w (a5)+, $78(a5)` — copia (a5)+ al HP y AVANZA el puntero a5 2 bytes por frame. Mismo tildo, distinta instruccion mala. La v8c regenera los 28 bytes COMPLETOS desde el hex final y los valida con capstone dentro del MISMO script (error de letra imposible por construccion). Regla ampliada: NUNCA editar bytes sueltos de un payload, SIEMPRE regenerar el bloque completo. ROMs: 29 = FE4348D1..., 23 = 96C27711...

## S-2024-10-22j: el motor de efectos (sonda = respuestas)

Sistema nuevo: los EFECTOS del juego (chispas, polvo, proyectiles) son el
MISMO motor de objetos que los jugadores: un pool de 16 slots de $80 en
$FF9400, spawn por $1FAB4, ID en el byte $58, tabla de despacho $14A00
(37 entradas), cada uno con su handler. Doc nueva completa:
`01-MOTOR/OBJETOS-Y-EFECTOS.md` (9584 bytes) y sonda
`sonda_efectos.lua` (8967 bytes).

La duda vieja del pool (doc decia $FF9400, la arimetica daba $009400)
cerro en las dos direcciones: la sonda vio los spawns reales en
$FF9400+i*$80, y la geometria era el adda.w sign-extendido (el inmediato
$9400 = -$6C00, el que da base $FFFF9400+cursor). Igual que el tildo del
veneno: el 68K dolariza los word inmediatos y si no se tiene en cuenta
el pin-pong da una direccion mala.

Otras dos correcciones del agente que trajo la sonda: (1) el handler
$13E9A NO esta sin llamador: spawnea en juego en ráfagas de 7 con la
tabla $0D8F1A; (2) la lectura de ID=$02 con tabla $000000 no es del
juego: es la sonda leyendo el slot DENTRO del mismo frame cuando la
init aun no lleno la tabla.

Pendiente del usuario: correr el modo clonar (duplicar un efecto vivo
a un slot libre con la X corrida) para demostrado 'efecto donde yo
quiera' sin parche.


**EL APENDICE del S-2024-10-22j: el aura FUNCIONA.** El modo aura de la
sonda clona un record $1D real y lo pega al jugador envenenado: la tesis
'efecto donde yo quiera = clonar record + mover \/' quedo demostrada
en juego. La v3 habia pintado la pantalla de negro: copie \/\/del PLAYER al OBJETO, y esos offsets no significan lo mismo en las dos
estructuras (en el player \ es \, no un tile). Leccion en el
doc: los campos entre record de jugador y de objeto NO son intercambiables.

## S-2024-10-22k: la v9 del veneno = el AURA en ROM limpio

**Lo pedido: `implementalo al ROM limpio`** — tomar la receta del aura que el
usuario aprobo jugando con la sonda y meterla en el ROM con SOLO el veneno
(sin ningun otro parche del proyecto).

### Lo que se descubrio para el spawn en ROM

- **El spawner real del trail `$20` vive en `$020202`+** (region de wrappers
  `$020190-$020360`, 5 variantes con el mismo `bsr $1FA96`): el wrapper de
  `$020202` arma el record a mano: `move.b #$20, $58(a0)`, `move.l $40(a5),
  $40(a0)`, el Y desde `$9C(a5)`, y el `$24` sale del atacante con
  `andi.w #$9800` + `ori` por facing (salta `$C1A6`, paleta 2, la del trail
  real). Se descarto reusar el wrapper: **no escribe el byte bajo del
  `$24`** (el tile queda heredado del ocupante anterior del slot).
- **La secuencia real de spawn confirmada**: `v $1A071C rts` en el router
  v8c`; el hook corre POR FRAME POR JUGADOR parado en el plano (el chequeo
  `$9C(a5) = 304` en `$015BEE`).
- **La tabla de pares es WORD apretado**: `$14EAC: 4C04 4D04 4E04 4F04 0000`
  = [masterIdx alto, dur bajo] x4 + terminador. La tabla corta del aura =
  `$1A07EC: 4D04 4E04 0000` (los pares 77+78 = la ventana 25%-75%, el
  terminador mata LIMPIO via handler `$149AC`).
- **El flag de plano `$A042` tiene los bits 5-7 LIBRES** (el juego solo usa
  los bits 0/1 con bset/btst y un clr.b de fin de ronda): ahi vive el
  contador de cadencia del aura, sin restar RAM.

### El parche

Grupo `veneno_aura` (200 bytes): el router `$1A071C` = `jsr $1A0730` + `rts`,
la rutina del aura en el hueco `$1A0730` (186 bytes, TODAS las instrucciones
validadas con capstone en el script), la tabla corta en `$1A07EC` (6 bytes).
La rutina: HP $78(a5) > 0 (los cadaveres `$FC00` no clonan), el
`addi.b #$20, $A042` solo dispara con CARRY (una vez cada 8 frames, el
contador no se lee), allocator del juego con el handler `$149AC` en d0,
NULL = saltear el frame, slot limpiado entero (64 words) y record escrito
completo: `$24 = $A1A6` (paleta 1), `$59 = $FF` estado nacimiento,
`$50 = $1A07EC` la tabla corta, `$40/$44` = posicion del jugador (a5).

Trampa de capstone de este tanda: mis primeros encodings tenian tres errores
que el roundtrip cacho: `21fc` escribe sobre `(d16,a7)` no sobre `(d16,a0)`
(el del juego es `217c`), `317c` con disp 0 es `(d16,a0)` y el `(a1)+` es
`32fc` (capstone lo decodifico y sali del lio), y los placeholders de rama
de 2 bytes se comian los primeros bytes de la instruccion siguiente (los
`bxx.w` son 4 bytes). Tambien: `patch_rom.py` comparaba el resultado final
byte por byte contra el valor de CADA item: con dos grupos tocando el mismo
byte ($1A071D: el v8c pone 75, mi grupo pone B9) cantaba falso positivo;
ahora gana el ULTIMO valor por byte.

### El resultado

- `rom/cambios/30_china_VENENO_AURA_P1_P2.bin` = la china base + `veneno_plano`
  + `veneno_aura`, SHA1 `7C00E4DF3F3AAE1F809DB0C388BC603DC8B9AA84`
  (179 bytes distintos de la base + checksum).
- `verificar_desensamblado.py`: OK. El desensamblado completo del hook,
  router, rutina y tabla en el ROM final: OK a mano con capstone tambien.
- Docs: la seccion `EL AURA DEL VENENO` en `PARCHES.md` (con el asm completo).
- **Pendiente del usuario: probarlo en FBNeo** (veneno + aura juntos).

## S-2024-10-22l: la pantalla negra al cruzar = dos bugs de mano en el aura v9

**Lo pedido: `al cruzar enfrente el juego se rompe`** — con el ROM v9
(`30_china_VENENO_AURA_P1_P2.bin`), al cruzar al plano de atras el juego
rompia: pantalla negra justa al cruzar. La receta era identica a la
aprobada en el sonda, asi que el bug tenia que estar en la transcripcion
a 68K.

### Los dos bugs

1. **El `dbra` del limpiado del slot saltaba mal.** Los bytes eran
   `51c8 fffc` = disp `-4` relativo a la regla que use mal. Con la regla
   CORRECTA el objetivo real era `$1A0764`: la MITAD del `move.w #$0,(a1)+`
   (el word `$0000` ahi = `ori.b #0,d0`, pan comido): el loop "limpiaba" solo
   2 bytes del slot y el resto del record quedaba con la **basura del efecto
   anterior** (el polvo del caminar, sobre todo): el handler `$149AC` leia un
   record quebrado = pantalla negra al primer clone (~8 frames despues de
   pisar el plano). El fix: disp `FFFA`, target el `move.w` en `$1A0764`
   completo, 64 words = los `$80` bytes del slot.

   **La regla que faltaba en el cuaderno** (verificada contra el juego mismo,
   no contra mi memoria):
   **[CORREGIDO por S-2024-10-23: esta bulleted-list tenia la regla de Bcc.w
AL REVEZ — el disp de Bcc.w TAMBIEN es relativo a addr+2; la gran prueba
esta en la entrada nueva. La lista de abajo queda como se razono EN ESE
MOMENTO.]**

2. **Los tres `Bcc.w` tenian el disp con base equivocada** (`addr+4`): el
   `ble.w` caia en `$1A07E0` = la mitad del `move.l $44(a5), $44(a0)` del
   epilogo. Con el ROM bisector `31_` (sin spawn) rompiendo IGUAL se
   confirmo que el apagon no era el spawn: era el flujo roto del hook.
   La regla correcta de todos los saltos con disp word (Bcc.w, BSR.w y
   DBcc) = disp relativo a la direccion del word del disp (`addr+2`),
   demostrada con el `bsr.w` del juego en `$1FFA0` -> `$1FA96` y los dos
   `dbra` de `$250`/`$238`. Los encodings capstone NUNCA estuvieron
   "2 antes": el desfase era de mis cuentas manuales.

---- texto de la sesion original (histórico) ----

- `Bcc.s` y `Bcc.w`: el disp es relativo a **addr+4** para la forma
     `.w` (los 4 bytes `6x00 xxxx`) y a **addr+2** para la `.s`. Los
     `ble/bcc/beq .w` de la rutina (disps `$A0/$96/$82`) apuntan a `$1A07E2`
     con la regla `addr+4`: OK de fabrica.
   - **`DBcc` (`dbra`/`dbf`): el disp es relativo a `addr+2`**, NO a
     `addr+4`. Prueba: el loop del juego en `$250` (`move.b (a5)+,(a0)+`
     de 2 bytes) tiene `dbra d2, FFFC` y el target tiene que ser el
     `move.b`: `$252 + 2 + FFFC = $250` solo con la regla `addr+2`; con
     `addr+4` el dbra saltaria a SI MISMO y el juego no copiaria nada.
     Otro caso igual en `$23E` (`dbra d1, FFF8` -> el cuerpo de 6 bytes en
     `$238`). Ojo: capstone imprime el target de DBcc 2 antes, igual que el
     de los Bcc.w: verificar por aritmetica, no por el print.

2. **El NULL-check del allocator era `tst.l (a0)`.** Cuando el pool esta
   lleno el allocator devuelve `a0 = $00000000` y mi `tst.l (a0)` leia la
   ROM en `$000000` (el SSP del header, ≠ 0): NO detectaba el NULL y el
   record se escribria encima de la tabla de vectores = crash. El juego
   mismo hace el chequeo `cmpa.w #$0, a0` justo despues de su `bsr $1fa96`
   (en `$1FAF2`): copie EXACTO ese patron (4 bytes) y el `beq.w` se corrio
   a `$1A075C` con el disp recalculado (`$82`, target `$1A07E2`).

### El detalle util: la rutina gano 2 bytes

`tst` (2 bytes) -> `cmpa.w` (4 bytes): la rutina pasa de 186 a **188 bytes**
(`$1A0730-$1A07EB`) y la tabla corta se corrio de `$1A07EC` a **`$1A07EE`**
(los writes del record `$50` la apuntan ahi, el hueco hasta `$1A0826` sigue
cabiendo). Los `ble/bcc` tambien alcanzan el epilogo nuevo (`$1A07E2` las
tres ramas).

### Verificacion

- Total de saltos con regla numerica (no capstone print para los ramas):
  `ble $1A073E/$A0`, `bcc $1A0748/$96`, `beq $1A075C/$82` -> `$1A07E2` (OK),
  `dbra $1A0768/FFFA` -> `$1A0764` (OK). Capstone confirma todas las
  instrucciones del ROM final (router + rutina + tabla + hueco en ceros).
- `patch_rom.py`: 252 parches aplicados, `verificar_desensamblado.py` OK.
- `parches.json`: grupo `veneno_aura` re-escrito (202 items, `desc` con los
  dos fixes = la memoria de la leccion DBcc).

### El resultado

- `rom/cambios/30_china_VENENO_AURA_P1_P2.bin` v9-2, SHA1
  `55D7981361A876F2677F78D3D356CE94BD483853` (mismo nombre, el FBNeo lo
  carga con reload).
- `PARCHES.md`: la seccion del aura re-escrita (v9-2, asm completo con las
  dos correcciones + la nota de la regla DBcc).
- **Pendiente del usuario: re-test en FBNeo** (veneno + aura juntos; si
  vuelve a romper, la sonda queda como instrumento de diagnostico).

## S-2024-10-23: el negro del aura era el DESPLAZAMIENTO de los Bcc.w (v9-3)

**Lo pedido: `nop, se sigue poniendo todo en negro al cruzar enfrente`**
(con la v9-2) y despues `lo mismo, se pone en negro` con el ROM bisector
**`31_` (spawn amputado con 1 byte: `bcc.w` -> `bra.w` en `$1A0748`)**.

### El dato que reviento la teoria

Si `31_` rompe IGUAL que `30_`, el spawn no tiene culpa: en el camino
siempre-corredor de la rutina la UNICA escritura a RAM es el
`addi.b #$20, $A042` (y el bset del v8c escribe ese mismo byte y anda).
Pero el flujo del camino siempre-corredor PASA POR LOS TRES `Bcc.w`... y
ahi estaba el bicho.

### La regla que faltaba (de una vez y con prueba)

**El desplazamiento de todo salto con disp word (Bcc.w, BSR.w y tambien
DBcc) es relativo a la DIRECCION DEL WORD DEL DISP (`addr+2`), no al fin
de la instruccion (`addr+4`).**

La prueba definitiva contradice el "quirk de capstone" que anotamos en la
v9: capstone imprime los targets VERDADEROS con base `addr+2`; la cuenta
manual con `addr+4` era la que quedaba 2 tarde:

```
01ffa0: 61 00 fa f4     bsr.w    $1fa96     <- asm del JUEGO
```

`$1FFA0 + 2 + FAF4(-1292) = $1FFA96` = `$1FA96`, EL WRAPPER DEL ALLOCATOR
que ya desensamblamos como codigo conocido (llama el pool-del-polvo en
$1FBAA, etc). Con `addr+4` da `$1FFA98` = la mitad de otra instruccion.
El juego no podria andar con `addr+4`. Y los `dbra` del juego en `$252` y
`$23E` = la misma regla aplicada a DBcc.

### El bicho exacto

- Con base `addr+4`, mis tres ramas tenian el disp 2 bytes corto:
  `ble.w $A0` caia en `$1A07E0` = la mitad del `move.l $44(a5), $44(a0)`
  del epilogo (ahi viven los bytes `00 44`). Se ejecutaba un `ori` basura
  que gastaba 2 bytes mas, dejaba los pops desandados (3 en vez de 4),
  devolvia `d0` con el valor viejo de `d1`, y el `rts` saltaba al POOL
  (la RAM de los records ejecutada como codigo). Todo eso dentro del hook
  del plano: apenas `$9C(a5) = 304` = el primer frame de cruzar = negro,
  con o sin spawn. Cuadra con TODO: v9-1, v9-2 y el `31_` bisector.
- El `dbra FFFA` de la v9-2 quedo BIEN de casualidad/mismo-regla (base del
  word del disp): el arregla del dbra era real, solo la CAUSA del negro
  estaba contada del reves.

### El parche v9-3

Tres bytes: `A0->A2`, `96->98`, `82->84` (targets iguales `$1A07E2`).

- `rom/cambios/30_china_VENENO_AURA_P1_P2.bin` v9-3, SHA1
  `0CE1770A244BE430695CF708E5324A8A2046ABDA`.
- `31_china_TEST_AURA_SIN_SPAWN.bin` regenerado con las ramas nuevas, SHA1
  `AD8100113B8D04EE8F6CB1A43A72B1E5CC701F39` (bisector disponible).
- `verificar_desensamblado.py` OK; los 4 saltos verificados numericamente
  con la regla real; `patch_rom.py` OK.
- `parches.json`: los 3 items re-escritos.
- `herramientas/lua/probe_aura.lua`: la sonda-diagnostica (solo
  observacion: `$A042`, cuenta de cadencia, libres, trail vivos + volcado
  $80 del record cuando nace o cambia de estado) a usar si vuelve a
  apagar algo.

### Lecciones para el cuaderno

- **Regla 68k unificada del proyecto**: el disp es relativo a la direccion
  del word del disp (para la forma `.s` ese word = el propio opcode, o sea
  base = instruccion+2). Capstone juzga como el hardware; si un print de
  capstone no cuadra con la cuenta manual, SE DUDAN LAS PROPIAS CUINTAS
  primero.
- El bisector de 1 byte (`bcc.w`->`bra.w`) separa "spawn" de "rutina" en
  UN solo test del usuario.
- **Pendiente del usuario: re-test de la v9-3 en FBNeo.**

### Adendum (v9-4): el handler $149AC decodificado y el clon invisible

La v9-3 dejo de crashear ("ahora anda") pero el clon **no se veia ni con
un dash real previo** (tapa la hipotesis de los tiles de VRAM: estan
cargados). Desensamblo el hueco `$149AC-$14A65` (que el listing del juego
salta): ES EL INIT DE NACIMIENTO DEL RECORD (todo en
`PARCHES.md`, seccion del aura). Lo decisivo:

- El init del handler es el que escribe `$59=$ff/$5b=$01/$5c=$0` y
  `$6 += 2`: mi record con `$6=0` sigue el nacimiento NATURAL del juego,
  y el `$59=$ff` de nacimiento es el centinela confirmado (FF++ cae en la
  pisada 0 de la tabla corta).
- El `$6=$0002` de la plantilla FIJA no era un campo: era el ESTADO
  POST-INIT de la captura, y los clones del sonda nacian con el
  init ya saltado.
- El record se dibuja con los `$40/$44` (y extra `$42/$46-$47`) PROPIOS:
  mi posicion en LONG arrastraba los sub-bytes del player al record
  = clon vivo pero dibujado donde no se ve. La receta aprobada usa WORD.
- Fix **v9-4**: `$1A07D6/$1A07DC` pasan de `move.l` a `move.w` (2 bytes,
  `$21->$31`), mismo tamano, regla de branches intacta. ROM 30 = SHA1
  `22A86626DE86B3FAAF98B11D2EE93DFE7421D129`, bisector `31_` =
  `9A5D8588BB5CA11EB804AA30B157F45AFA515ACB`. Verificador OK.
- Nota de docs: el listing del asm del doc tenia 7 filas (+2) desimuladas
  con las direcciones de un esquema viejo; re-emitidas del ROM real.

### Adendum (v9-7): el dispatcher decodificado y el wrapper real como spawn

- Test del v9-6: TAMBIEN invisible. Se termino de decodificar el pool:
  el allocator `$1FA96` = un anillo fijo de 16 slots (`$A036 += $80`
  con base `$9400`, stride `$80`, NULL si estan todos ocupados, no
  depende de d1) y el DISPATCHER ($3592) camina `$8000-$A000`,
  salta slots con `$0 = 0` y despacha `jsr (a0)` a los vivos (a5 =
  el slot). El kill ($3556) borra `$4>>4 * 16` bytes y los muertos se
  saltan con stride `$40` = el pool es una lista empacada de estados
  `$4`. Todo el mecanismo = sano, y la receta del sonda (clon a mano
  en `$FF9400` con `$4=$80`) demostro que un record a mano se dibuja.
- Con el record replicado al dedillo (v9-4/v9-5/v9-6 todos invisibles)
  el record deja de ser el sospechoso: queda el CONTEXTO del spawn.
  Dos compuertas del runner pueden helarlo (`$F550` bit7, `$F55A`) o
  directamente el despachador per-frame no corre en el estado del
  plano 304 (es la prueba bifurcante: la estela REAL del dash en ese
  plano; si tampoco aparece, el pool esta frio ahi).
- Fix **v9-7** (commit actual): el record NO se arma a mano NADA: la rutina
  llama a `jsr $020202` (el wrapper REAL del trail) y solo pinta
  paleta 1 encima (`andi #$8fff` + `ori #$2000`). Rutina de 56 bytes,
  epilogo en `$1A075E`, `ble/bcc` disp `1E/14`. La tabla corta queda
  fuera del parche (el init `$14D30` la pisaba igual). ROM 30 = SHA1
  `13467D9B97AB2E500741EE338DA924F02CF4F6D9`, bisector `31_` =
  `DACA1FE4E5B2F4EE104D21F1D26E13DF8399FB54`. Verificador OK.

### Adendum (v9-5/v9-6): el wrapper real del trail al dedillo

- Test del v9-4: "no se ve". Antes de seguir, dis de `loc_020202`
  (el wrapper REAL del ID `$20`, el que spawnea la estela del dash):
  copia del player X=`move.l $40`, **Y=`move.l $9c(a5) -> $44(a0)`**
  (espacio de RENDER, no el `$44` mecanico), `move.w $3e` (escala),
  `move.b $26 - 4` (binding de plano) y `$24` = byte del player +
  `andi.w #$8000` + `ori.b #$40` (rama con `$61=0`).
- Fix **v9-5**: el Y se copia del `$9C(a5)` en LONG (`0044->009C`, 1
  byte, la MISMA instruccion del wrapper). Resultado: TAMBIEN invisible
  (pero al usuario le gusta que la ventana sea la de la tabla real:
  init de `$14D30` reescribe `$50 = $14eac` y camina los pares 76-79 =
  estela completa, mas grande y ancha que la receta del sonda).
- Hallazgo del init de `$14D30` (dis del ROM, capstone): aparte de
  reescribir `$50`, hace `ori.w #$1a6, $24` (el hi del tile) y
  `move.b #1, $27` — la `$27=1` de la FIJA quedaba explicada: era
  solo el byte bajo de `move.w #$1001, $26` de mi copia, no un campo.
- Fix **v9-6** (commit actual): los TRES campos del wrapper al dedillo
  escalando la rutina a 216 bytes (tabla corta ahora en `$1A080A`,
  epilogo en `$1A07FE`, disp de los 3 `Bcc.w` = `BE/B4/A0`):
  `$24` = byte del player + `andi #$8000` + `ori.b #$40` + `andi
  #$8fff` + `ori.w #$2000` (paleta 1, la customizacion del aura),
  `$26` = byte del player - 4, `$3E` = word del player. ROM 30 = SHA1
  `F67E920C6A5618557BB25CD99FB988E6143A8917`, bisector `31_` =
  `D4E9AF474A5B9389185626206AA1CA0189B1803D`. Verificador de saltos y
  `verificar_desensamblado.py` OK.



