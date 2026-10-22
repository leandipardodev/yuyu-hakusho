# Lo pendiente

*Lo que falta, en orden.*

---
## Pendiente (lo siguiente que hay que hacer)

1. **Medidor de super**: `$B8` (maná/TA, tope 223) es casi seguro lo que se
   pide, pero falta confirmar en ejecucion si el juego lo llama TA o super.
   El stun ya esta en `$7E`/`$80`.
2. **Frame data**: ya no hace falta medir en ejecucion. El registro de frame son
   **8 bytes** (`loc_01EB40`, `0x1EB48`), `+0` es la duracion (`-> $5A`) y el bit 6
   del byte de atributos marca los frames activos. Las 12 bases estan en
   `MOVES-Y-TIMING.md` §2. Falta el parser.
3. **Blockstun**: la **direccion** sigue sin localizar. Los tres resolvers van a
   dano. El **valor 32 se midio en ejecucion** y es coherente con la escala
   (28 clash > 16 golpe), pero sin direccion no se puede implementar leyendo
   el codigo: queda como medicion, no como dato. Candidatos: **`$71` bit 1
   (el UNICO con mecanismo demostrado: elige `$2C`/`$2D` en `0x1F3F6`, y de ahi
   sale si el siguiente golpe pega completo o reducido)**, `$63`, `$64` bit 5,
   `$6C` bits 0-5. Ver `MOVES-Y-TIMING.md` §6.
4. **Stun real por golpe**: `$7E` es un **presupuesto**, no un timer. Los golpes
   hasta knockdown son `ceil($80/$66)`, ya calculable. Ver §4 de
   `MOVES-Y-TIMING.md`. Falta igual medir para confirmar.
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

### El handler de $A5 de Itsuki (para el fix "solo el teleport")
La receta `14_itsuki_teleport_pisa_el_suelo` mata el estado `$25` **de
siempre**, o sea que el **dash de Itsuki (8 de mana) deja de hacer su
salto y su espera**. Para que solo afecte al teleport, haria falta tocar
el handler de `$A5` (el que pone `$5D = $25` al final de la colocacion),
que **no se ha localizado**: la tabla `$15a68` lleva a `$0167DF`, que es
una tabla de datos y no codigo. Pista: el bloque de Itsuki esta en
`$019xxx`-`$01Cxxx`, y `$01B1CE`/`$01B1E8`/`$01B21E`/`$01B246`/`$01B2BC`
son los handlers de `$24`/`$25`/`$26`/`$27`/`$28`.

### El aturdimiento base (sin machar) son 255 frames = 4,25 s
Se puede bajar con 1 byte: `move.w #$ff, $7e(a5)` en `$01A282` (p.ej.
`#$80` = 2,1 s). El usuario todavia no lo ha pedido.

### El mash solo mira `$72` (los flags de boton)
No mira `$71` ni `$73`, o sea que el mash con las **direcciones** podria no
contar. No comprobado.

### EL RIVAL NACE EN EL PLANO DE ATRAS, Y ESO SE DEJO ASI
El rival de la CPU arranca en el **plano de atras** (304) y **mas pequeno**
(escala `$D8` = 216), en las 4 inicializaciones de `$00AA8C`, `$00AB0C`,
`$00FB1A` y `$00FBA0`. **Hubo un parche para ponerlo en el delantero
(plano 320, escala 256) y el usuario lo pidio revirter: forma parte del
juego.** No lo volvemos a poner. Lo que si se queda es `un_plano` (que
impide el CRUCE a la otra arena) y `sin_cruce`.

### LA CHINA YA TIENE EL PROYECTO APLICADO
La ROM china (`rom/original/...chinese.bin`, que es `temp/opencode/control.bin`)
**ya tiene todos los parches del proyecto** (los mismos bytes que la
unificada). Por eso:
- Al parchar la unificada completa sobre ella, el patcher **aborta** (los
  bytes "old" no coinciden porque ya estan en su valor final). Para eso esta
  la opcion `--force`.
- **Lo que le falta es el grupo `un_plano`** (el que desactiva el cruce de
  planos), que es justo lo que el usuario veia.

### !!! LOS 22 'bne.w $1886a/$18880' NO SON LOS ATAJOS !!!
Son **el MOVIMIENTO con C y con Y en cada direccion** (el "adelante A" usaba
el `$84`). Cambiar sus destinos **mueve todos los golpes de todos los
personajes** (el "adelante A se hace con abajo A", "hiei salta muy poca
distancia": el `$83` dura 4-8 frames).

**Para desactivar un atajo hay que tocar el `btst` del boton, NO el salto.**
El inmediato del `btst` va en 2 bytes (`08 2D 00 04 00 72` = `btst.b #$4,
$72(a5)`) y **el byte ALTO** es el bit que se prueba (bits 8-11). El **bit 3**
del campo `$72` **no lo prueba ninguna instruccion del juego** (0 usos).

### !!! EL INMEDIATO DEL 'btst': EL BYTE ALTO ES EL NUMERO DE BIT !!!
```
08 2D 00 04 00 72   =   btst.b #$4, $72(a5)
    ^  ^  ^  ^
    |  |  |  +-- el byte BAJO = la MASCARA (los bits que se prueban)
    |  |  +----- el byte ALTO = el NUMERO DE BIT (bits 8-11)
    |  +-------- el modo/registro
    +----------- el opcode
```

**CAMBIAR LA MASCARA ROMPE LOS ATAQUES** (el bit 0 = el boton A, el bit 1 =
el B). Para desactivar un atajo hay que cambiar **el numero de bit** (el byte
ALTO, en **salto - 4**) a un bit que el juego no use: **el bit 7** del campo
`$72` no lo escribe ni lo prueba nadie (0 usos en todo el ROM).

**MAPA DE LOS BOTONES ($72):** bit 0 = A (ataque fuerte), bit 1 = B (ataque
debil), bit 2 = C (defensa), bit 3 = X, bit 4 = Y (linea), bit 5 = Z (dash),
bit 7 = nunca se usa.

## POR QUE ESTO CIERRA EL PENDIENTE P5

P5 era "la flag que borra la hurtbox, dirección desconocida", y no se podia
podía atacar porque la ventana del backflip es de **13 frames** (hurtbox fuera en
el 24, backflip en el 37): demasiado corta para aislar.

**Esta ventana es de 60 frames** (1 a 60), con dos subventanas bien marcadas:

| Ventana | Que falta |
|---|---|
| **1 a 13** | solo la hurtbox |
| **14 a 60** | hurtbox **y** pushbox |
| **19 a 60** | ademas el sprite parpadea |

**El parpadeo del frame 19 es la mejor pista que tenemos**: es un efecto VISIBLE
que dura 42 frames, y se puede buscar por el codigo que lo dibuja. Con el blink
encontrado, el frame 1 (el primer frame de intangibilidad) tiene que estar cerca.

**O sea que P5 paso de "no atacable" a "atacable, y con tres puntos de entrada".**

---

## LO QUE FALTA

| | |
|---|---|
| **El id de `$5F`** | Sale solo en la proxima corrida del `.lua`, ahora que el guardia no tapa variantes |
| **Las direcciones** | El `.lua` las calcula y las imprime en el mismo aviso |
| **Que campo es el parametro de zona** | A/B/C apuntan a tres zonas distintas con el mismo `id`: el destino tiene que estar en algun byte del registro de 8 bytes o de la tabla B. **No verificado.** |
| **Por que A/B/C cuestan igual** | Si el destino fuera un offset en el registro, tres valores distintos con el mismo costo tiene sentido; si fuera en la tabla B, tambien. **Sin dato todavía** |

**La tabla B tiene un solo subregistro por byte `+1` del registro**, y ese byte
es el mismo para las tres variantes si comparten `id` y frame. **O sea que el
parámetro de zona probablemente NO está en la tabla B sino en otro lado**, o
las tres variante tienen `id` distinto y lo que se vio fue otra cosa. **Abierto:**
lo resuelve una linea mas de salida del `.lua`, que ya imprime el registro
completo de cada variante.


### Herramienta que lo verifica: `ITSUKI SET MOVE.LUA`

**`herramientas/lua/ITSUKI SET MOVE.LUA`** (autotest: `test_stoptime.lua`, 78
pruebas). Mapea el ult sobre el codigo y **se autocomprueba**, para que no sea
solo un lector. **Al detectar la invocacion saca un cartel gigante con "OK" en el
centro de la pantalla**, durante 75 frames: es una corroboracion a ojo de que
el script lee y detecta durante el juego, que es lo unico que el usuario pedia
para confirmar que funciona.

**Que verifica, con las tres partes de la firma:**

| Parte | Donde |
|---|---|
| `$69 = 255` en los slots enemigos | `0x1C078` |
| `$59 == 2` y `$5B == 0` y `$60 != 1` en el lanzador | `0x1C03A`, `0x1C042`, `0x1C032` |
| **`$6E` del congelado distinto al del lanzador** | `0x1C072`-`0x1C076` |

**La regla del `$6E` se comprueba en las DOS direcciones**, y por eso el script
sirve como prueba y no como lector:

| Si | El script avisa |
|---|---|
| un slot de **otro** grupo sin congelar | FALLA |
| un slot del **mismo** grupo congelado | FALLA |

**Que NO usa exec hook, y es a proposito:** `$69` es un timer que sobrevive
varios frames, asi que `registerafter` alcanza. Asi el script **no depende de
`memory.registerexec`**, que en esta build no dispara (`diagnostico_knockdown.lua` quedo
con `invocaciones=0`). Es el primer diagnostico que esquiva ese agujero en vez de
pelearse con el.

**Y distingue los DOS finales del ult:** por **cuenta regresiva** (255 frames
exactos, verificado) o por **impacto**, que es cuando el resolver sobrescribe el
byte. Si el corte cae a 0 viniendo de 1 fue la cuenta; si caia antes, fue un
impacto.

**LO QUE EL CODIGO ACLARA Y EL DOC NO DECIA:** el recorrido termina en
**`cmpa.w #$9000, a0`** (`0x1C07E`), o sea que **`$9000` es el ULTIMO slot del
array y el bucle los recorre TODOS**. Es un dato a favor de `$9000` como base
del P2, y sale de leer el codigo y no de razonar sobre el stride.

### `$FFF558` es CAMARA LENTA de muerte, no un freeze

```asm
loc_01edfa:
01edfa:  cmpi.w   #$0, $f558.w
01ee00:   beq.b    $1ee18
01ee02:  subq.w   #$1, $f558.w
01ee06:  move.w   $f558.w, d0
01ee0a:  btst.b   #$1, d0          ; ¿el contador es IMPAR?
01ee0e:   beq.b    $1ee18
01ee10:  move.b   #$1, $f55a.w     ; impar -> frena este frame
loc_01ee18:
01ee18:  clr.b    $f55a.w          ; par -> NO frena
```

**`$F55A` se prende en frames impares y se apaga en los pares.** Con `$F558 = 160`
eso es **mitad de velocidad durante 160 frames**. No es una congelacion: es
**camara lenta**.

Por eso frena **todo** — proyectiles, elementos del stage y scroll — porque
`$FFF558` es **global**, mientras que `$69` es por personaje. Y por eso no se
asocia al hit-time: no es un freeze.

Los dos se limpian juntos en varios init (`0x0034C4` + `0x0034C8`, `0x004562`,
`0x00685A`, `0x00A858`, `0x00AE80`, `0x00F324`).

### Cuando se dispara: `$78` negativo

**Aca hay un branch que es facil de leer mal.** En `loc_01F4CA` hay **dos** tests
con dos `blt` distintos:

```asm
loc_01f4ca:
01f4ca:  cmpi.w   #$0, $78(a4)     ; TEST 1: el HP del defensor
01f4d0:   blt.b    $1f4f4          ; HP < 0 -> CAMARA LENTA
01f4d2:  clr.w    $84(a4)
01f4d6:  cmpi.w   #$0, $7e(a4)     ; TEST 2: el stun del defensor
01f4dc:   blt.b    $1f4e2          ; stun < 0 -> knockdown
loc_01f4de:
01f4de:  bsr.b    $1f524          ; ninguno de los dos -> caso normal
```

**El `blt` de `0x1F4D0` es del test de `$78`, no del de `$7E`.** El slow-mo se
dispara **cuando el HP es negativo**, o sea cuando el personaje murio. `$78` es un
word **signed**, asi que es como el juego representa el KO.

**Medido: entre 150 y 170 frames**, contra los 160 del literal.

### Por que NO es acumulativo

`loc_01FA70` tiene **un solo llamador en todo el juego**, y es una asignacion:

```asm
loc_01fa70:
01fa70:  moveq    #$0, d0
01fa72:  move.b   $58(a4), d0       ; el codigo del golpe
01fa76:  lea.l    $1fa8a.l, a0     ; tabla
01fa7c:  adda.l   d0, a0
01fa7e:  move.b   (a0), $a030.w    ; una salida: ACCION (variable)
01fa82:  move.w   #$a0, $f558.w    ; la otra: 160 SIEMPRE (rigido)
01fa88:  rts
```

| | |
|---|---|
| **La duracion** | **`#$A0` es un literal.** En las 28.168 instrucciones `$FFF558` nunca recibe otro valor. No es flexible |
| Acumulable | **No**: es asignacion, no suma |
| Reiniciable | **Si**, y por eso cada golpe sobre un muerto vuelve a clavar 160 |

**Medido: se sigue golpeando a un muerto y la lentitud se mantiene.** Exacto.

### Del maná en la muerte: NO hay nada

En toda la region `0x1E000`-`0x20000`, que contiene el resolver y el slow-mo, las
**unicas** escrituras a `$B8` son las del bonus de combo (`0x1FA12`, con el tope
en `0x1FA1E`). **El slow-mo no toca el mana.**

**Medido: un personaje muerto no pierde maná.** Consistente: lo unico que lo
restaria es el goteo de `0x1A4EA` y las burlas, y ninguno depende de `$78`.

El goteo tiene su propio gate, que no es de muerte:

```asm
01a4d6:  add.w    d0, $7c(a5)
01a4da:  cmpi.w   #$100, $7c(a5)
01a4e0:   blt.b    $1a4ea          ; si $7C < 256 -> gotear
01a4e2:  move.w   #$ff, $7c(a5)    ; si no, saturar
01a4e8:   bra.b    $1a4ee          ; y SALTAR el goteo
loc_01a4ea:
01a4ea:  subq.w   #$1, $b8(a5)
```

`$7C` es un acumulador en coma fija: cuando cruza 256 se saltea el −1. Ese es el
balance entre regeneracion y gasto, y **no mira el HP**.

### `$F558` / `$F55A`: lo que NO es

Por si se vuelve a cruzar con el hit-time: **no esta en ninguno de los dos.** Se
descarto por agotamiento, no por inferencia.

| Campo | Escritores en todo el ROM | Valores |
|---|---|---|
| `$69` | 7 | **0, 16, 28, 255.** Nada entre 28 y 255 |
| `$FFF558` | **1** | **160.** Un solo valor |

