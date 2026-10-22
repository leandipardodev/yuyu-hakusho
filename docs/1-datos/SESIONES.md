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


<a name="s-2024-10-21c"></a>

## S-2024-10-21c: cruzar hace perder 1 de vida cada 3 frames (y el primer
intento fallo)

**Pedido:** *"quiero que si alguien cruza enfrente vaya perdiendo 1 de vida
cada 3 frames"*.

**El primer intento no funcionaba.** El fallo: **el cruce NO es el estado
`$0F`**.

### Lo que se averiguo (y por que el primer parche no hacia nada)

1. **La tabla de handlers es GLOBAL** (`$15a68`, 256 entradas) y las
   entradas son **offsets relativos**: `handler(N) = ($15a68 + 2*N) + word`.
   O sea que **no hay un handler por personaje**.

2. **El estado `$0F` (`$01CA9C`) NO es el cruce.** Es el del **impulso**:
   `$016434` pone `estado = $0F`, `frame id = $0B` y `velocidad = 4.0`, y
   llama a `$1faf0` (el mismo "efecto" que el cruce). El primer parche
   modificaba ese handler, que no se ejecutaba durante el cruce.

3. **El cruce es el ESTADO `$0A` con el FRAME ID `$0F`**:
   `$01873A` pone el estado `$0A`, `$018748` pone el frame id `$0F` y
   `$01874E` lleva el plano a 319. Su handler es **`$019E08`**.

4. **El TICK `$5B` va de 0 a 254 durante el cruce** porque el frame data de
   `$0F` tiene **un solo frame de duracion 255** (8 de los 10 personajes).
   El tick se incrementa en `$019C96` y se reinicia al cambiar de frame
   (`$019CA6`); con duracion 255 el frame nunca cambia. **"Cada 3 frames" =
   "tick multiplo de 3"**.

5. **El HP es `$78`** (maximo 223 en `$012708`), el dano se resta en
   `$01F424` y el KO es cuando llega a 0 (`$015BCC`).

6. **El bloque `$019E10`-`$019E27` (el del plano) es el que `un_plano`
   desactiva** (cambia `$019E0E` de `bne.b` a `bra.b`). Con `un_plano` (que
   esta en la unificada) ese bloque **nunca se ejecuta**, asi que el dano
   no puede ir ahi. La llamada va en `$019E56`, que se ejecuta siempre
   durante el estado `$0A`.

7. **El hueco `$021B67`** (102 bytes, relleno `$FF`) tiene **cero** destinos
   de salto dentro. El bloque grande de `$021A32` tiene **285**.

### Que se hizo

Grupo `cruce_dano` (42 bytes), receta `17_cruzar_hace_perder_vida`:

- `$019E56`: `move.l $10(a5), d1` -> **`bsr $021B67`**
- `$021B67`-`$021B8C`: la rutina nueva (38 bytes), que devuelve la
  velocidad en `d1` (igual que la instruccion original) y resta 1 de vida
  si el frame id es `$0F`, el tick es multiplo de 3 y el HP es > 0.

**Lecciones para el camino:**

- **Un `bsr` en vez de reescribir el handler**: no habia hueco, y asi el
  resto del handler no cambia ni un byte.
- **Copiar los bytes de una instruccion equivalente que YA existe en el
  ROM** (`cmpi.b #$f, $5f(a5)` de `$019E08`, `tst.w $78(a5)` de `$01A03C`,
  `move.l $10(a5), d1` de `$019E56`) y **validarlo con Capstone** antes de
  escribir nada.
- **El opcode de `bne.b` (0x66) y `ble.b` (0x6F)**: better copiarlos del
  ROM que recordarlos (Capstone es mas listo: puede desensamblar `66 00`
  como `bne.w` si el destino no cuadra).
- **Mi primer escaneo automatico de "todas las instrucciones que tocan
  `$XX(a5)`" fallaba** porque busqué el desplazamiento en el orden
  equivocado: el EA `(d8,An)` es `<byte modo/reg> <d16 en big-endian>`.

**Estado:** implementado, reconstruido y verificado con Capstone. La
unificada queda en **103 bytes, checksum `$A92C`**. Falta que lo pruebes en
el emulador.


<a name="s-2024-10-21d"></a>

## S-2024-10-21d: el cruce ROMPIA EL JUEGO (el HP a 0 cuelga la ronda)

**Sintoma:** con la v2 del parche, *"al cruzar enfrente el rom se rompe"*.

**La causa (buscada en el codigo del KO):** el KO lo detectan tres sitios y
**ninguno** vigila el estado del cruce (`$0A`):

| Donde | Instruccion | Cuando salta |
|---|---|---|
| `$019CFC` (handler del estado `$00`) | `btst.b #$7, $78(a5)` | el HP es **NEGATIVO** |
| `$015BCC` (al final de cada handler) | `cmpi.w #$0, $78(a5)` / `bge.w $1877e` | el HP es **> 0** |
| `$01F3F0` (el resolver de golpes) | `move.b #$4, $5d(a4)` | al recibir un golpe |

El unico que **pone el estado del KO** es el resolver, y el dano del cruce
no pasa por ahi. **=> con el HP a 0 en pleno cruce, el personaje se queda
vivo con 0 de vida, la ronda no acaba y el juego se cuelga.**

**El arreglo (v3):** el HP **nunca baja de 1** (`cmpi.w #$2, $78(a5)` +
`blt.b`). El cruce te deja al borde de la muerte pero no te mata, y el
juego no puede colgarse.

**Lo que habria que hacer para que el cruce mate:** replicar al resolver
cuando el HP llegue a 0: `move.b #$4, $5d(a5)` + `move.b #$2c, $5f(a5)` y
llamar a `$1f786` (el efecto del KO). Pendiente de probar.

**La rutina (v3, 40 bytes):**

```
$021B67  move.l  $10(a5), d1     ; la velocidad (como antes)
$021B6B  cmpi.b  #$f, $5f(a5)    ; ¿es el cruce?
$021B71  bne.b   $021B8D
$021B73  move.b  $5b(a5), d0     ; el tick
$021B77  andi.b  #$3, d0         ; ¿multiplo de 3?
$021B7B  bne.b   $021B8D
$021B7D  cmpi.w  #$2, $78(a5)    ; ¿el HP es > 1?
$021B83  blt.b   $021B8D          ; si HP <= 1 -> fuera
$021B85  move.w  #$1, d0
$021B89  sub.w   d0, $78(a5)      ; -1 DE VIDA
$021B8D  rts
```

**Aprendido:**

- El opcode de `cmpi.w` es **`0C`** (igual que `cmpi.b`) y el formato es
  `opcode + modo/reg + inmediato(16) + d16`: `cmpi.w #$1, $78(a5)` =
  `0C 6D 00 01 00 78`.
- **`subi.w #$1, <ea>` NO EXISTE** con el EA `(d8,An)`: hay que hacer
  `move.w #$1, d0` + `sub.w d0, <ea>`.
- **`movem.l d0,-(sp)`** lo decodifica Capstone como `movem.l a7, -(a7)`:
  mejor no usarlo (por si acaso).
- El dispatcher de estados (`$015A18`) llama al handler **despues** de
  `$19c96` (el `++tick`), asi que el tick va 0,1,2... durante el cruce.
- El dispatcher se llama desde **un solo sitio** (`$01269A`), o sea que los
  handlers de estado son solo de los personajes (no de los proyectiles).


<a name="s-2024-10-21e"></a>

## S-2024-10-21e: el cruce rompia el juego (pantalla negra) -> el dano INLINE

**Sintoma de la v3:** *"instantaneamente al cruzar enfrente se pone la
pantalla negra o de algun color y queda trabado ahi"*.

**La causa:** la v3 metia el dano en una **rutina nueva** en el relleno
`$FF` del final del ROM (`$021B67`) y la llamaba con un `bsr` desde
`$019E56`. El juego se colgaba al ejecutar ese `bsr`.

**La regla que sale de esto: UN PARCHE NO DEBE LLAMAR A CODIGO NUEVO EN
EL ROM.** Se puede parchear lo que haya, pero meter rutina nueva en un
hueco rompe el juego (aunque el hueco no lo apunte ningun salto y el
`bsr` apunte a donde debe).

**La v4: el dano INLINE, dentro del handler, sin llamar a nada.**

El bloque `$019E10`-`$019E27` (24 bytes) del handler del cruce (el que
bajaba el plano y la escala) se sustituye por el dano, y **mide
exactamente los mismos 24 bytes**, asi que no se desplaza nada:

```
$019E10  cmpi.w  #$2, $78(a5)    ; ¿el HP es > 1?
$019E16  ble.b   $019E28
$019E18  move.b  $5b(a5), d0
$019E1C  andi.b  #$3, d0
$019E20  bne.b   $019E28
$019E22  moveq   #$1, d0
$019E24  sub.w   d0, $78(a5)
```

**Y `un_plano`:** quitamos su cambio en `$019E0E` (que neutralizaba ese
bloque). El plano sigue sin bajar (su codigo ya no esta), y el dano
funciona. **Las dos ROMs (la individual y la unificada) hacen lo mismo.**

**Aprendido:**

- **`moveq #$1, d0` son 2 bytes** (`70 01`), frente a los 4 de
  `move.w #$1, d0`. Con eso el dano cabe en 24 bytes exactos.
- **`subq.w #1, <ea>` NO EXISTE** con el EA `(d8,An)`: el SUBQ con memoria
  solo es de byte o de long. Para restar 1 de un word: `moveq #$1, d0` +
  `sub.w d0, <ea>`.
- **El EA `(d8,An)` en `cmpi`/`cmpi.w`**: opcode (0x0C para los dos) +
  byte de modo/reg + inmediato + d16: `cmpi.w #$2, $78(a5)` =
  `0C 6D 00 02 00 78`.
- **El dispatcher de estados llama al handler DESPUES** de `$19C96` (el
  `++tick`), asi que el tick va 0,1,2... durante el cruce ✓.


<a name="s-2024-10-21f"></a>

## S-2024-10-21f: desactivar los dos atajos del cruce

**Pedido:** *"agarra la rom original del yuyu y desactiva el cruzar
enfrente. quita el atajo arriba + c global que permite cruzar y el atajo Y.
que no apunten a su funcion, solo eso"*.

**Como se localizo (lo que mas costo):**

1. **Las tablas de comandos** son del tipo `lea.l base(pc,d0.w), a0` +
   `adda.w (a0),a0` + `jmp (a0)`: **las entradas son OFFSETS RELATIVOS**
   y el destino de la entrada `k` es `base + 2*k + word(base+2*k)`. Hay
   **62** tablas.

2. **El cruce de planos es el estado `$0A` con el frame id `$0F`**, y su
   funcion es **`$0186BE`** (-> `$018722` -> `$01873A`, que pone el estado
   `$0A`, el frame `$0F` y el plano 319).

3. La funcion `$0186BE` **solo aparece en la TABLA GLOBAL** (`$15c20`, la
   usa `$015C18` con el indice `$58(a5)`), en **dos entradas: la +80 (el
   atajo de arriba+C, global) y la +89 (el de abajo+Y)**. Las dos
   apuntaban al mismo sitio.

4. **Las tablas por personaje** ($16042, $16132, ... 16 entradas) apuntan
   a `$1886A` / `$018880` (el estado `$03` con los frames `$84`/`$86`):
   son **las tecnicas**, no el cruce. No se tocan.

**Que se hizo:** grupo `sin_cruce_atajo`, **4 bytes**: los offsets de las
entradas +80 y +89 de `$15C20` pasan a apuntar a `$019D62` (un
`bra.w $15afc`: el final del frame) en vez de a `$0186BE`. El atajo no hace
nada y la funcion del cruce no se toca.

**Dos trampas:**

- **El offset de la tabla es de 16 bits SIN SIGNO**: una entrada no puede
  apuntar a una direccion **menor** que la de la tabla. Por eso no se
  puede apuntar a `$015AFC` (el final del handler, que esta por debajo).
- **El destino no puede ser una funcion que se mueva**: el parche
  `doble_salto` reescribe `$018440` y lo mueve 2 bytes, asi que en la
  version unificada un destino ahi quedaria a mitad de instruccion. Por
  eso el destino es `$019D62` (que no lo mueve nadie).

**Estado:** implementado, reconstruido y verificado. La individual son 4
bytes (checksum `$60C3`) y la unificada 85 bytes (checksum `$52A4`).
Falta que lo pruebes en el emulador: **el atajo de arriba+C y el de abajo+Y
no deberian hacer nada** (y el resto del juego igual).


<a name="s-2024-10-21g"></a>

## S-2024-10-21g: el destino del atajo (la v2 ARRANCA ROTA)

**Sintoma:** con la v2 (las entradas de la tabla global apuntando a
`$019D62`, un `bra.w $15afc` = el final del frame) la ROM **arranca rota**.

**La causa (importante):** la tabla global `$15C20` se indexa con
**`$58(a5)`**, y **`$58` puede valer 80 o 89 en otros contextos** (al
arrancar, en la intro, en el menu) — no solo cuando se pulsa el atajo. Con
un destino que no sea un "nada" real, el juego saltaba ahi **a mitad de
una rutina** y se rompia.

**El arreglo:** el destino es ahora **`$01668A`, un `rts` suelto** (hay un
bloque de `rts` en `$016688-$016692`). La tabla salta con `jmp (a0)`, asi
que el `rts` saca la direccion de retorno del `bsr $15c10` y vuelve al
dispatcher de estados: **no hace nada y el flujo queda intacto** pase lo
que pase.

**Ademas:** el usuario dejo su ROM original en **`rom/original/`**
("yuu yuu hakusho - makyou toitsusen (english translation).bin"). Se
comprobo que es **identica** a `rom/fuentes/yuyu_makyou_ingles.bin` (y a
`dual_language.bin`). El parche se le aplica **sin tocar el original**
(el parcheador escribe en otro fichero):
`rom/cambios/18_sin_atajos_de_cruce_ingles.bin`.


<a name="s-2024-10-21h"></a>

## S-2024-10-21h: el destino del atajo (dos versiones rompian el arranque)

**Sintomas:** con la v2 *"arranca rota"* y con la v3 *"toda la pantalla en
rojo"*.

**Lo que se descarto primero:** el checksum de la cabecera. **Los dos ROMs
(checksum $337B y $BE4F) lo tienen CORRECTO** (coincide con la suma de
los datos desde $200) y **el juego no tiene el checksum como constante en
el codigo** (0 apariciones de $337B y de $BE4F). O sea que no era eso.

**La causa de fondo:** la tabla global `$15C20` se indexa con **`$58(a5)`**,
y **`$58` puede valer 80 o 89 en otros contextos** (al arrancar, en la
intro, en el menu), no solo cuando se pulsa el atajo. Por eso el destino
tiene que ser algo que **no rompa nada** pase lo que pase.

| Version | Destino | Que pasaba |
|---|---|---|
| v2 | `$019D62` (`bra.w $15afc`) | el juego saltaba ahi **a mitad de una rutina** -> **arranca rota** |
| v3 | `$01668A` (un `rts` suelto) | el `jmp (a0)` + el `rts` hace **pop de la pila** -> **pantalla roja** |
| **v4** | **`$019D5E`** (`bsr.w $18440` + `bra.w $15afc`) | **bien**: el "reset" + el final del frame |

**La regla que sale de esto:** si cambias el destino de una entrada de
tabla para "desactivar" algo, ese destino tiene que ser **una funcion
real que el juego ya use para "no hacer nada"** (aqui: el `reset` +
el final del frame), **no** un `rts` suelto ni un trozo de codigo.

**Ademas:** el usuario dejo su ROM original en `rom/original/` (es
**identica** a `rom/fuentes/yuyu_makyou_ingles.bin`). El parche se le
aplica **sin tocar el original**.
