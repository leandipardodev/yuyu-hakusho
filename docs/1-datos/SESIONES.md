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
| el teleport de Itsuki = estado `$A4` de ctx6, bloque de frames `$0D044A`, 14 frames, 37 ticks | `TECNICAS.md` §1.9, `DATOS_VERIFICADOS.md` |
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
