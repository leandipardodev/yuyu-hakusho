# La entrada y los PLANOS

*El input, el flag del plano $A042, el suelo $9c, la escala $3e y el indice $26.*

---
## 5c. `$26` — un INDICE, no un plano ni una profundidad

Lo que se sabia antes era solo que "`$26` prende en todo contacto". Las direcciones
del escritor:

```asm
01f7b2:  cmpi.w   #$130, $9c(a3)    ; ¿el atacante es el char $130?
01f7b8:   beq.b    $1f7c8
01f7ba:  move.b   #$3c, $26(a3)     ; atacante = 60
01f7c0:  move.b   #$40, $26(a4)     ; defensor = 64
01f7c6:   rts
01f7c8:  move.b   #$bc, $26(a3)     ; 188
01f7ce:  move.b   #$c0, $26(a4)     ; 192
01f7d4:   rts
```

### El bit 7 NO son dos planos: es el SIGNO

**Habia un error en una lectura anterior de este mismo doc.** Se sostenia que el
bit 7 discriminaba dos planos porque los mismos valores bajos aparecian con y sin
`$80`. Es falso: en el consumidor el bit 7 se lee como **signo**, con `ext.w`.

### El consumidor: `loc_0379AE`, un interprete de tablas

**`$26` no guarda una magnitud.** Es el cursor que camina por una tabla de bytes,
uno por llamada:

```asm
loc_0379c6:
0379c6:  moveq    #$0, d0
0379c8:  move.b   $26(a5), d0        ; d0 = $26
0379cc:  addq.b   #$1, $26(a5)       ; $26++
0379d0:  move.b   (a0, d0.w), d6     ; d6 = byte de la tabla en ese indice
0379d4:   bpl.b    $379f4            ; bit 7 = NEGATIVO, no opcode
loc_0379f4:
0379f4:  ext.w    d6                 ; valor CON SIGNO
0379f6:  move.b   $3(a5), d0
0379fc:  mulu.w   d0, d6             ; desplazamiento x escala
loc_0379fe:
0379fe:  move.b   $1e(a5), d0
037a04:  add.w    d0, d6
037a06:  add.w    $10(a5), d6        ; + velocidad
```

El byte de la tabla es un **desplazamiento con signo**: se multiplica por una
escala (`$3`) y se suma a una posicion (`$1E`) mas la velocidad (`$10`).

### Los cinco opcodes que manejan el cursor

| Opcode | Instruccion | Que hace |
|---|---|---|
| `$80` | `clr.b $26(a5)` en `0x37A1A` | vuelve al inicio de la sub-tabla |
| `$81` | `subq.b #$2, $26(a5)` en `0x37A20` | sube al padre |
| `$82` | `$26 = tabla[$26+1]` en `0x37A38` | salta adelante |
| `$83` | `bset.b #$1, (a5)` en `0x37A26` | prende un flag, no toca `$26` |
| `$84` | `$3 += tabla[$26+1]` en `0x37A40` | suma a la escala y avanza |

Y un segundo sitio, independiente, en la zona de actualizacion del jugador:

```asm
0015fa:  move.b    $26(a5), d4
0015fe:  andi.w    #$fc, d4        ; offset multiplo de 4
001602:  movea.w   d4, a2
001604:  movea.w   -$cfe(a2), a0   ; lee una tabla indexada por ese offset
```

### `$0A` es el selector de TABLA, y hay 8 (esto faltaba)

La cadena que faltaba era como se elegia la tabla, y sin eso no se puede acotar
el rango de valores:

```asm
0379ae:  moveq     #$0, d6
0379b0:  move.b    $a(a5), d0
0379b4:  andi.w    #$7f, d0        ; solo limpia un bit de bandera
0379b8:   beq.b    $379fe          ; $0A = 0 -> no lee nada
0379ba:  lea.l     $3a256(pc), a0  ; tabla de PUNTEROS
0379be:  subq.w    #$1, d0         ; d0 = $0A - 1
0379c0:  lsl.w     #$2, d0
0379c2:  movea.l   (a0, d0.w), a0  ; a0 = flujo de bytes
```

| | |
|---|---|
| Donde | tabla de **8** punteros en `$3A256`-`$3A275` |
| Rango de `$0A` | **1 a 8**. El `andi.w #$7f` no significa "hasta 127": solo limpia un bit |
| Los 8 flujos | `$3A276, $3A28C, $3A2A2, $3A2AC, $3A2C6, $3A2B6, $3A2F0, $3A2F2` |

Ojo: el indice se calcula con `subq.w #$1` **despues** del `beq`, asi que `$0A=0`
saltea y `$0A=1..8` da los ocho flujos.

### EL VOLCADO: que hay de verdad en los 8 flujos

`herramientas/desensambladodump_26.py` los vuelca byte por byte. **154 bytes en total:**

| Clase | Bytes | % |
|---|---|---|
| `DATO+` (`$00`-`$7F`) | 140 | **90,9 %** |
| `DATO-` (`$85`-`$FF`) | 8 | 5,2 % |
| `CODIGO` (`$80`-`$84`) | 6 | 3,9 % |

Los flujos completos, con el valor con signo al lado:

```
$0A=1  $3A276  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 83
$0A=2  $3A28C  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 80
$0A=3  $3A2A2  D8 E2 EC F6 00 0A 14 1E 28 83
$0A=4  $3A2AC  D8 E2 EC F6 00 0A 14 1E 28 80
$0A=5  $3A2C6  00 x10  01 x15  02 x8  03 x7  04 83
$0A=6  $3A2B6  04 04 04 04 03 03 03 03 02 02 02 02 01 01 01 01
$0A=7  $3A2F0  02 83
$0A=8  $3A2F2  00 x5  01 x5  02 x7  03 x5  04 x5  05 x5   (longitud aproximada)
```

**Cada flujo termina en `$80` o `$83`**, que es exactamente lo que haria una curva
de movimiento: un ciclo, o un fin. Es la comprobacion de que las longitudes (por
"hasta el siguiente puntero") estan bien.

Los valores con signo que aparecen en los datos, **todos**:

| Grupo | Valores |
|---|---|
| Positivos | `0` a `40`, de paso uno (rampas de 1, de 5, de 10) |
| Negativos | **`-40 -40 -30 -30 -20 -20 -10 -10`** |

**Ninguno mayor que 40. Ni 64, ni 192, ni 148, ni 252.**

### Donde salen "64" y "192", y por que se leyeron como planos

**Del escritor, no de la tabla.** Los unicos valores grandes de `$26` estan en
las rutinas que lo **inicializan**, y son offsets de arranque del cursor:

```asm
01f7ba:  move.b   #$3c, $26(a3)     ; 60  -> cursor arranca en la entrada 60
01f7c0:  move.b   #$40, $26(a4)     ; 64
01f7c8:  move.b   #$bc, $26(a3)     ; 188
01f7ce:  move.b   #$c0, $26(a4)     ; 192
```

O sea que `$40` y `$C0` son **indices**, no magnitudes. Leidos como
profundidad, con y sin el bit 7, parecian dos planos. **Es exactamente la
trampa que ya estaba anotada en `docs/08-DIARIO/MEMORIA.md` ("mirar solo los escritores")**,
cometida por el material externo y por una lectura anterior nuestra.

### Dos opcodes no se usan nunca

De los cinco, en los 154 bytes de los 8 flujos **solo aparecen `$80` (3 veces) y
`$83` (3 veces)**. `$81`, `$82` y `$84` estan implementados y **no salen en ningun
flujo**. O son de una tabla que no esta en `$3A256`, o quedaron de una version
anterior. Queda abierto, y no estorba.

### Los valores con signo: la tabla que hay que leer con cuidado

| Valor | Con signo | De donde sale |
|---|---|---|
| `$10` (16) | +16 | cursor escrito |
| `$14` (20) | +20 | cursor escrito |
| `$3C` (60) | +60 | cursor escrito (`0x1F7BA`) |
| `$40` (64) | +64 | cursor escrito (`0x1F7C0`) |
| `$94` (148) | −108 | cursor escrito |
| `$C0` (192) | −64 | cursor escrito (`0x1F7D4`) |
| `$FC` (252) | −4 | cursor escrito |
| `$D8 E2 EC F6` | **−40 −30 −20 −10** | **SI estan en las tablas** (`$0A`=3 y 4) |
| `$0A 14 1E 28` | **+10 +20 +30 +40** | **SI estan en las tablas** (`$0A`=3 y 4) |

**Ninguno de los siete primeros llega a leerse como desplazamiento**: las tablas
no los contienen. Los unicos negativos que el interprete ve de verdad son los de
`$0A = 3` y `$0A = 4`, y son **las dos mitades de la misma curva**:

```
D8 E2 EC F6  00  0A 14 1E 28  ->  -40 -30 -20 -10   0  +10 +20 +30 +40
```

Una rampa que **cruza el 0** y sigue subiendo. Si el bit 7 fuera un plano, el
grupo negativo seria otra magnitud y no habria continuo entre los dos. Lo hay.
**Se confirmo lo de §5c y se REFUTO lo de "dos planos", esta vez con las tablas
en la mano y no solo el consumidor.**

### Por que "prende en todo contacto"

**Un contacto dispara una animacion de empuje, y `$26` es el frame de esa
animacion.** Prende porque es el contador de la animacion, no porque sea un timer.

**VERIFICADO: NO es hit-time.** Y tampoco es profundidad ni prioridad de dibujo.

**LO QUE SIGUE ABIERTO:** si el `a5` de `loc_0379AE` es el struct del jugador o un
objeto aparte. La lectura de `0x0015FA`, que esta en la zona de jugador junto a
`$24`, lo apoya, pero no lo cierra. Es el unico punto que necesita emulador.

## 5d. `$A030`: la cola de SONIDO, y el byte `+4` del frame data

**CORRECCION IMPORTANTE.** Esto se escribio antes como "cola de acciones" y como
"el camino al hit-time". **Las dos cosas estan mal**, y la correccion viene del
material externo (`notas/GENERAL/`, 10-06) y esta confirmada aca.

**`$A030` es el indice de un SONIDO, no una accion de gameplay.** El byte `+4`
del registro de frame es el **indice de sonido**, indexado en la tabla de
`$218D8`. La cola de 4 canales con prioridad es un **driver de audio**, no un
gestor de efectos.

La prueba: `$F800` se usa como **base de puntero** (`lea.l $f800.w, a0` en
`0x38A34`, `0x38A5E`) y `$F809` se resetea a `$FF` en tres sitios (`0x37CBA`,
`0x38A42`, `0x38A72`). Ese es el patron de un driver de sonido.

**Consecuencia: el hit-time NO esta ahi.** Ibuscamos en la cola de sonido durante
una sesion entera. Esta en otro lado — ver §5b para lo que si es.

### Las perdidas de sonido, y por que se pierde

**La cola tiene 4 canales y cuando se llenan, la peticion se pierde.** No hay
espera ni reintento para `$A030`:

```asm
01ed9a:  move.b    $a030.w, d0
01ed9e:   beq.b     $1edaa
01eda0:  clr.b     $a030.w      ; <- borra SIEMPRE
01eda4:  jmp       $21960.l     ; <- y no mira el resultado
```

Y `$21960` devuelve 0 si los 4 estan ocupados:

```asm
loc_0219a8:
0219a8:  clr.b     d0           ; ninguno libre -> FALLO
0219aa:  rts
```

**Medido de oído:** hay tecnicas que se ejecutan sin pronunciar nada, y personajes
que mueren sin su grito. Eso es una peticion descartada por cola llena.

**La musica no pasa por acá** y por eso nunca se corta ni se ve afectada por el
time stop ni por la camara lenta: es otro driver.

### La unica excepcion: `$F562` si reintenta

```asm
loc_0219ba:
0219ba:  move.b    $f562.w, d0
0219be:   beq.b     $219cc
0219c0:  jsr       $21960.l     ; reintenta
0219c6:   beq.b     $219cc       ; si fallo, NO limpia: vuelve a intentar
0219c8:  clr.b     $f562.w      ; si alguno, limpio
```

Un unico sonido tiene paciencia; los demas no.

### La cola de 4 canales con dedupe

`$21960` mete el valor en el primer canal libre, y **no duplica**:

```asm
loc_021960:
021960:  tst.b    $f80a.w
021964:   bpl.b    $2196c      ; vacio -> asignar
021966:  cmp.b    $f80a.w, d0 ; ¿ya tiene el MISMO valor?
02196a:   bne.b    $21972      ; si es otro -> siguiente canal
loc_02196c:
02196c:  move.b   d0, $f80a.w  ; <- asignar
loc_021972:  tst.b  $f80b.w    ; canal 2
loc_021984:  tst.b  $f80c.w    ; canal 3
loc_021996:  tst.b  $f80d.w    ; canal 4
```

Tiene **~110 llamadores** en todo el ROM: es infraestructura central de audio.

### Y como se elige: prioridad, no orden

`$37C44` consume los 4 canales cada frame y gana el de mayor prioridad:

```asm
037c44:  lea.l    $3a50e(pc), a0      ; TABLA de prioridades
037c52:  move.b   -(a1), d0           ; leer canal (hacia atras)
037c56:  clr.b    (a1)                ; <- CONSUME
037c60:  move.b   (a0, d0.w), d2      ; prioridad[codigo]
037c6c:  move.b   d2, d5
037c6e:  andi.b   #$7f, d5            ; <- la prioridad son los 7 bits bajos
037c78:  cmp.b    d6, d5
037c7a:   bcs.b    $37c82             ; si es menor, se descarta
037c7c:  move.b   d2, d3              ; si es mayor, pasa a ser la actual
loc_037c7e:
037c7e:  move.b   d1, $f809.w         ; <- el codigo ganador
```

**Medido de oído:** los golpes le ganan a las voces. Eso es la comparacion de
prioridad, no un bug.

### El mapa del registro de 8 bytes (corregido)

```asm
01eb5a:  move.b    $0(a2), $5a(a5)    ; +0 = duracion
01eb62:  move.b    $1(a2), d3        ; +1
01eb66:  move.b    $2(a2), d5        ; +2
01eb6a:  move.b    d5,   $5c(a5)
01eb6e:  move.b    $3(a2), d0        ; +3
01eb72:  or.b      $6d(a5), d0
01eb76:  move.b    d0,   $6c(a5)
01eb82:  move.b    $4(a2), d0        ; +4 = INDICE DE SONIDO
01eba6:  move.b    $6(a2), d6        ; +6 (restado $80)
01ebb0:  move.b    $7(a2), d7        ; +7 (restado $A0)
```

Y en el mismo bloque, el flag de encadenamiento que ya se conocia:

```asm
01eb98:  btst.b    #$4, d5           ; bit 4 de +2
01eb9c:   beq.b    $1eba4
01eb9e:  moveq    #$ff, d0
01eba0:  move.l    d0, $94(a5)       ; $94 = $FFFFFFFF
```

### De donde sale `$A030`: TRES fuentes

| # | Fuente | Direccion |
|---|---|---|
| 1 | **byte `+4` del frame data** → tabla `$218D8` | `0x1EB82`-`0x1EB94` |
| 2 | `tabla_$1FA8A[$58]` (solo al morir) | `loc_01FA70`, `0x1FA7E` |
| 3 | Literales directos: `$77`, `$78`, `$7A`-`$7C`, `$7D`, `$A6` | varios |

La fuente 1, en el builder:

```asm
01eb7a:  tst.b     $5b(a5)        ; ¿el contador del frame llego a 0?
01eb7e:   bne.b    $1eba4         ; si no, no hay frame nuevo
01eb82:  move.b    $4(a2), d0     ; byte +4 del registro de 8 bytes
01eb86:  lea.l     $218d8.l, a3   ; TABLA
01eb8c:  move.b    (a3, d0.w), d0 ; tabla[byte+4]
01eb90:  tst.b     d0
01eb94:  move.b    d0, $a030.w    ; <- ENCOLAR EL SONIDO
```

**Medido:** `$A030 = $7C` aparece en casi todos los golpes de la corrida de
referencia. Es el sonido del impacto.

## LOS ATAJOS DE MANDO DEL CRUCE (la bit mask del `btst` leida bien)

**Fuente: desensamblado con Capstone sobre `rom/base/yuyu_makyou_base.bin`,
verificado byte a byte.**

### 1) El inmediato del `btst.b` es el NUMERO DE BIT (no una mascara)

El `btst.b #n, $72(a5)` se codifica en **6 bytes**:

```
08 2D <n:word> 00 72
^  ^    ^       ^-- el desplazamiento (1 byte, modo 2 = d8,A5)
|  |    +------- el NUMERO DE BIT (un WORD, el inmediato)
|  +------------ el modo/reg: 010 101 101 = d8,A5
+--------------- el opcode del BTST
```

**El numero de bit NO es una mascara.** `btst.b #$4, $72(a5)` prueba **el bit
4** del byte de botones que hay en `$72(a5)`. Los bytes son tal cual:
`$016106: 08 2D 00 04 00 72` = "prueba el bit 4".

**CONSECUENCIA (importante):** en la 68000 el numero de bit de un BTST sobre
un operando de **1 byte** se usa **modulo 8**. Por eso la receta 19
(`sin_atajo_cruce`), que cambia **el byte ALTO** del inmediato (`$00` ->
`$07`, en `salto - 4`), **NO HACE NADA**: el inmediato pasa a ser `$0704` y
`$0704 & 7 = 4` = el mismo bit 4 de antes. **Es un parche inerte.**
***(el usuario lo confirmo empiricamente: la ROM `19_china_sin_cruce.bin`
arranca y golpea, pero el cruce sigue being possible)***

**Para cambiar de verdad el bit que se prueba hay que tocar el byte BAJO**
(el numero de bit, en `salto - 3`), y no en un `btst` que ademas decida un
ataque (ver el punto 3).

### 2) Census de todos los `btst.b #n, $72(a5)` del ROM

| bit que se prueba | veces | donde |
|---|---|---|
| 2 | 2 | `$01A554`, `$01C4B4` |
| 3 | 2 | `$01A560`, `$01C4C0` |
| **4** | **74** | `$015C96`, `$016062`, `$01607A`, `$016106`, `$016152`, ... |
| 5 | 8 | `$01A50C`, `$01A534`, `$01B434`, `$01BCD0`, `$01C00A`, `$01C2A6`, `$01C46A`, `$01C494` |
| **6** | **78** | `$01386C`, `$013A8C`, `$01606C`, `$016084`, `$016110`, ... |

**Los bits 0, 1 y 7 de `$72(a5)` no los prueba NINGUNA instruccion de todo el
ROM** (0 usos). El bit 7 es el unico "libre" de los que no se usan, asi que
**cambiar un numero de bit a `$07` deja el `btst` siempre falso** (el
numero de bit `$07` con un byte = el bit 7, que nunca se escribe).

### 3) Los 22 `btst` del bloque "C o Y" (los atajos por personaje)

Los 11 dispatchers por personaje (el del personaje 1 empieza en `$015FDC`)
muestran la **direccion** (`$71`) y despachan por una tabla de 16 entradas
de 16 bits en `$016042` (`lea.l $16042(pc,d0.w),a0` + `adda.w (a0),a0` +
`jmp (a0)`). Los destinos y los moves que pone cada atajo:

| `btst` | destino | move | que direccion |
|---|---|---|---|
| bit 4 | `$018812` | `$80` | sin direccion |
| bit 6 | `$018828` | `$82` | sin direccion |
| **bit 4** | **`$01883E`** | **`$81`** | **ARRIBA** |
| bit 4 | `$01886A` | `$84` | ABAJO+DERECHA |
| bit 6 | `$018880` | `$86` | ABAJO+DERECHA |
| bit 4 | `$0188EE` | `$90` | ARRIBA+ABAJO+DERECHA |
| bit 6 | `$0188D8` | `$94` | idem |
| bit 6 | `$018930` | `$95` | idem |
| bit 6 | `$0194FA` | `$86` | (otro dispatcher) |
| bit 6 | `$0195DC` | `$87` | (otro dispatcher) |

Cada destino hace: `move.b #$3, $5d(a5)` (estado 3) + `move.b #$xx, $5f(a5)`
(el move) + `move.b #$0, $6c(a5)` + `bra.w $19c00`.

**OJO CON EL BIT 6:** en el dispatcher 1, con direccion ARRIBA, el
`btst.b #$6, $72(a5)` **no** es un atajo: si el bit 6 esta puesto **crea un
proyectil** (el bloque `$01608C`: `movea.l #$0,a1` + la tabla de 16 bytes de
la posicion + `bra.w $18854` = el move `$83`). **Por eso tocar el numero de
bit de un `btst` del bit 6 rompe los ataques**, y por eso la v1 de la receta
19 (que cambiaba el byte bajo) rompio "abajo+A" y "abajo+B".

### 4) El atajo GLOBAL (los 3 botones a la vez)

```
$015DE6  move.b   $73(a5), d0      ; los botones MANTENIDOS
$015DEA  andi.b   #$70, d0         ; los bits 4, 5 y 6
$015DEE  cmpi.b   #$70, d0         ; ¿los 3 a la vez?
$015DF2  beq.w    $18764           ; -> estado 0, move $14
```

Es el **unico** parche de la receta 19 que **si** surte efecto (el inmediato
`$70` -> `$71` en `$015DF1`). Ojo: **no** es el cruce: el destino `$18764`
pone el estado `$00` y el move **`$14`**.

### 5) El CRUCE de planos de verdad

| que | valor | donde |
|---|---|---|
| el estado del cruce | **`$0A`** | handler en **`$019E08`** |
| el move de la ida | **`$0F`** | `$01874E` |
| el move de la vuelta | **`$10`** | `$018700` |
| el suelo del plano | `$9c(a5)` = 320 (`$140`) o 304 (`$130`) | |
| el flag global del plano | **`$A042`** (bit 0 = delante 320, bit 1 = atras 304) | |

El handler `$019E08`:
```
$019E08  cmpi.b  #$f, $5f(a5)    ; ¿el move es $0F?
$019E0E  bne.b   $19e28
$019E10  bset.b  #$1, $a042.w    ; "el plano de atras"
$019E16  subi.l  #$a800, $9c(a5) ; el suelo -40 px POR FRAME
$019E1E  addi.b  #$3, $26(a5)
$019E24  subq.w  #$3, $3e(a5)    ; la escala -3
...
$019E8C  bne.b   $19ea2
$019E8E  move.l  #$1300000, $9c(a5)   ; el suelo final = 304 (el otro plano)
$019E96  move.w  #$d8, $3e(a5)       ; la escala = 216
```
(por eso el grupo `un_plano` neutraliza `$019E0E`, `$019E8C` y `$019ED2`).

**Los DOS unicos sitios que ponen el estado `$0A` son `$0186F2` y `$01873A`**
(patron `1B 7C 00 0A 00 5D` = `move.b #$0A, $5d(a5)`). Los dos estan en el
bloque `$0186BE-$018760`. Y **`$0186BE` no lo llama NINGUNA instruccion del
ROM** (ni un `bsr`, ni un `jsr`, ni un `jmp`, ni una tabla de punteros):
es un punto de entrada muerto. **ASI QUE EL CRUCE NO SE LANZA DESDE EL
CODIGO DE LA 68000 QUE HEMOS VISTO: hay que averiguarlo en el emulador.**
***(la sonda `herramientas/lua/sonda_cruce.lua` lo averigua)***

### 6) Los `btst` del bit 5 (los que lanzan los moves $AA y $A8)

| sitio | a donde va | que hace |
|---|---|---|
| `$01B434` | `$01B444` | `move.b #$aa, $5f(a5)` + estado `$03` |
| `$01C00A` | `$01C01E` | `move.b #$a8, $5f(a5)` + estado `$03` |
| `$01A50C`, `$01A534`, `$01C46A`, `$01C494` | `$01A56C` / `$01C4FE` | cambian la animacion (`move.b #$8, $59(a5)`) |
| `$01BCD0`, `$01C2A6` | `$01BD36` / `$01C304` | (movimiento) |

El `$AA` en `-$5556(a5)` (el "cambio de plano") lo pone **`$018748`**, dentro
del bloque del cruce.

### 7) La sonda que lo averigua en el emulador

`herramientas/lua/sonda_cruce.lua` (FBNeo):
1. Al arrancar **lee la ROM** y saca la tabla de atajos (el bit que prueba
   cada `btst` y el move al que salta) + el atajo global.
2. Cada frame **imprime los botones y las direcciones** (con nombre y en
   hexadecimal) cuando cambian, y guarda un **historial de los 40 frames
   anteriores**.
3. Cuando detecta el cruce (el estado `$0A`, los moves `$0F`/`$10`/`$AA`/
   `$A8` o un cambio del suelo `$9C`) **vuelca el historial**: asi se ve
   que boton habia pulsado en el frame que lo lanzo.


## EL PLANO: EL FLAG $A042

**El "plano" de un personaje lo dice el flag global `$A042`** (un byte de la
RAM del Z80, que la 68000 ve en `$A00000-$A0FFFF`):

| bit | significa | quien lo pone |
|---|---|---|
| **0** | el personaje esta en el plano de **DELANTE** (suelo 320) | `$015BE6` (el suelo es 320), `$019E30`, `$019EF4` |
| **1** | el personaje esta en el plano de **ATRAS** (suelo 304) | `$015BF6` (el suelo es 304), `$019E10`, `$019ED4` |

Los dos bits estan en el mismo byte, asi que un valor 3 significa "los dos".
El flag lo leen `btst.b #0` (`$0186DA`) y `btst.b #1` (`$018722`), en la
funcion que decide si el personaje cruza o vuelve (`$0186BE`).

**La rutina que lo actualiza cada frame es `$015BD8`** (la llama `$015A2E`
con `bsr.w`): si el suelo (`$9c(a5)`) es 320 pone el bit 0, y si es 304
pone el bit 1.

**El resto de los datos del plano:**

| que | donde |
|---|---|
| el suelo del plano | `$9c(a5)` (un long, 16.16): 320 = delante, 304 = atras |
| la escala del sprite | `$3e(a5)` (un word): 256 = delante, 216 = atras |
| el indice del sprite | `$26(a5)` (un byte) |
| el cambio de plano (la caida) | el estado `$0B` con el move `$0F`: el suelo baja 0.31 px por frame |
| el aterrizaje en el plano de atras | `$019F52` (el handler del estado `$0B`) |
| el aterrizaje en el plano de delante | `$019E8E` (el handler del estado `$0A`) |

