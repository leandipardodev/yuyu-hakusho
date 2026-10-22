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

## S-2024-10-21o: el "2 cuerpos por detras" de Sensui (el `bra` no salta nunca)

**Sintoma del usuario:** *"1 frame de sensui al caminar sale mal, como que
aparecen 2 cuerpos por detras de el, es solo un frame"* y *"empezo a ocurrir
luego de algun cambio tuyo"*.

**La causa:** el grupo `un_plano` (el que desactiva el cruce de planos)
neutralizaba los TRES bloques del cruce **cambiando el `bne.b` por un
`bra.b`**. Y un `bra` **no salta nunca**: al cambiarlo, el bloque dejo de
saltarse y **se ejecutaba siempre**, con cualquier move. Al pasar el
personaje 1 frame por el estado `$0A` (pasa al cambiar de animacion,
tambien al caminar), el juego ponia **el flag del plano de atras**
(`$A042`) y **el suelo en 304** (`move.l #$1300000, $9c(a5)`) con la escala
`$d8`: el personaje se dibujaba en el otro plano y se veian **2 cuerpos por
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

**Pendiente del usuario:** probar la unificada con el fix (el "2 cuerpos"
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

**El "2 cuerpos por detras" de Sensui SIGUE** con el `un_plano` arreglado, asi
que no es (solo) el `un_plano`. Se ha generado la
`24_china_UNIFICADA_sin_hoja.bin` (la unificada sin el parche de la hoja de
Kuwabara, `$0C2EA2` = la duracion de un frame de su cadena) para la
biseccion.

**Pendiente del usuario:** probar la `22_china_DANO_al_cruzar.bin` (el
cruce con el dano) y la `24` (biseccion del "2 cuerpos").

<a name="s-2024-10-21q"></a>

## S-2024-10-21q: el "cambio de plano" es el FLAG $A042 (el usuario lo dijo)

**El usuario:** *"algo estas haciendo mal pero ninguno de los dos andan,
seguro estas modificando un valor distinto que el cambio de plano"*.
**Tenia razon.** El "plano" no lo dice el suelo (`$9C`) sino el **flag global
`$A042`** (bit 0 = "delante", bit 1 = "atras"), que esta en la RAM del Z80
(por eso la sonda no lo podia leer). Todo lo anterior (el suelo, la escala
`$3E`) es el suelo fisico.

**EL "2 CUERPOS POR DETRAS":** los 6 escritores del flag son `bset.b`, que
solo ponen bits y **nunca limpian el otro** ⇒ al pasar de un plano al otro
el flag se queda con **los dos bits a 1** ⇒ el juego cree que el personaje
esta en los dos planos a la vez y **dibuja 2 siluetas**.

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
"2 cuerpos") y `24_china_UNIFICADA_sin_hoja.bin` (biseccion del "2
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
  (era el "2 cuerpos por detras": el flag se quedaba con los dos bits a 1
  y el juego creia que el personaje estaba en los dos planos a la vez).

**ROMs para probar:** `22_china_PLANO_Y_DANO.bin` (la minima), la
`23_china_UNIFICADA_PLANO_Y_DANO.bin` (la unificada con el fix) y la
`24_china_UNIFICADA_sin_hoja.bin` (la biseccion del "2 cuerpos" por si es
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
"2 cuerpos") y tiene modos para **forzar** la bandera (1, 2 o 3) o **quitar
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
