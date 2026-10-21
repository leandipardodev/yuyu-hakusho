# VARIACION DE DANOS, HITPAUSE Y KNOCKDOWN

Todo lo que se resolvio —y lo que se abrio— el **07-10-2026** en el tema del
**golpe**: que es el hitpause, que es el knockdown, que es el backflip, y por que
el mismo golpe no da siempre lo mismo.

**Este documento no reemplaza a `DATOS_VERIFICADOS.md`.** Es la unica fuente de
verdad y sigue siendo la que manda. Acá esta el **detalle del hilo**, con las
correcciones y los errores del camino a la vista, porque **un doc que solo
guarda lo que quedo bien no sirve para no repetir los pasos en falso**.

| Documento | Que se lee |
|---|---|
| `DATOS_VERIFICADOS.md` §2, §2b, §2d, §2e, §5e | El dato, seco |
| **`VARIACION_DANOS_HITPAUSE_KNOCKDOWN.md`** | **El hilo completo, con lo refutado** |
| `AGENTS.md` | Memoria de trabajo y trampas |

## Como se marca lo que no esta confirmado

| Marca | Significado |
|---|---|
| `[ROM]` | Hay direccion en `game_68000.asm` al lado |
| `[MEDIDO]` | Se ejecuto y se vio, con el frame a frame |
| **`***`** | **Sin verificar.** Se escribe igual y completo, con su procedencia |

**El `***` importa mas que nunca en este documento**, porque la mitad de lo que
se escribio ayer como hecho resulto ser una lectura del resolutor sin contraste
con el dato medido. Ver §8.

---

# 1. RESUMEN, SIN DAR DE MAS

Lo que se cerro:

| | |
|---|---|
| **`$69` NO es hitpause** | Es **supresion de hitstun por personaje**. El unico freeze global del ROM es `$F558`, y es la **muerte** |
| **La oscilacion NO es desplazamiento** | Es `$54`, offset de **dibujado de un frame**. Coordenadas constantes mientras el sprite se mueve |
| **Knockdown y backflip son el MISMO evento** | Uno solo: el fin del hitstun. La unica rama es `$7E < 0` en `0x1F4D6`, y no testea si el personaje esta en el suelo |
| **El backflip NO viene de un agarre** | El agarre solo **pone al rival en el aire con la ventana abierta** |
| **El mismo golpe NO da siempre lo mismo** | Y **es determinista**: no hay RNG. Depende de que **frame activo** conecta |

Lo que se abrio:

| | |
|---|---|
| **El daño varia mucho menos que el pusheo** | Daño 20-60 %, pusheo factor 4. **Nunca se vio un golpe que saquen el doble de daño** |
| **No hay escalado por combo** | El daño completo se resta crudo. El 20 % entre combos sale de los frames, no de prorrateo |
| **Blockstun** | `$71` bit 1 paso a ser el unico candidato con mecanismo **demostrado** |
| **13 frames entre la invulnerabilidad y el backflip** | Sin causa localizada |
| **La direccion del flag que suprime la hurtbox** | Desconocida |

---

# 2. EL MAPA DE UN GOLPE, FRAME A FRAME

Todo esto es **`[MEDIDO]`**: el usuario lo رسمي a mano, frame por frame, con
coordenadas y sprite por separado. Antes se mezclaban las dos cosas y salia un
"empuje de 2 px" que en realidad era el sprite moviendose.

## 2a. El B en el suelo

Golpe suave en el suelo: no produce ni derribo ni backflip.

| Frame | Que pasa | Campo |
|---|---|---|
| **1** | El B pega. La **coordenada X cambia 2** (a veces 1, a veces 4) | `$69 = 16`, `$75 = 17` |
| **2 a 15** | **Hitstun SIN desplazamiento.** La coordenada **no se mueve**. El sprite oscila +-2 | `$54` |
| **16** | `$69` llega a 0. El sprite se asienta 1 px y vuelve a su posicion real | `btst.b #$0, $69(a5)` |
| **17** | **El empuje arranca de verdad.** La coordenada cambia frame a frame | `$14` |

**Lo importante de esta tabla:** entre los frames 2 y 15 hay **14 frames donde el
personaje NO se desplaza**. Todo lo que se ve ahi moviendose es el sprite, no
las coordenadas.

## 2b. El backflip: el mismo golpe, en el aire

| Frame | Que pasa |
|---|---|
| 2 a 15 | Hitstun, **sin desplazamiento** (igual que en el suelo) |
| **16** | **`$69 = 0`** |
| **17** | Empuje real, empieza a moverse |
| **24** | **La hurtbox desaparece** → **invulnerabilidad** |
| **25** | El sprite es **el MISMO que el del knockdown** |
| **37** | **Empieza la animacion de backflip** |

**DOS CONSECUENCIAS, y la segunda es la que nadie se esperaba:**

1. **La invulnerabilidad precede al backflip por 13 frames.** No es un efecto
   posterior: la victima ya es invulnerable 13 frames antes de que empiece a
   dar vueltas.
2. **En el frame 25 el sprite es compartido con el knockdown.** O sea que **la
   divergencia NO ocurre al entrar en el estado**, sino despues. Knockdown y
   backflip arrancan exactamente igual y se separan en el camino.

**El suelo medido es Y = 320.** En el aire, los valores van de **238 a 308**.
Con esos numeros se puede decidir si un personaje esta en el suelo mirando
`$0C`.

## 2c. La unica rama, y no testea el suelo

Los dos eventos salen de **una sola instruccion**:

```asm
01f4d6:  cmpi.w  #$0, $7e(a4)      ; ¿se agoto el presupuesto de stun?
01f4da:   bge.w   ...              ; si no, sigue
```

**Despues se distinguen solo por el estado de salida.** No hay ningun test de
"¿esta en el suelo?" en el camino. Ese test tiene que estar **antes**, en la
maquina de estados que decide a que estado entra — y **esa es la pieza que sigue
sin localizar** (ver pendiente P4).

**El PS/ataque que dispara la rama:**

```asm
01f4e2:  move.w  d0, $84(a4)       ; velocidad de empujon
```

**`[MEDIDO]` y confirmado en ejecucion:** cuando `$7E` va de **13 a -19**, `$84`
pasa a **368**. La firma `$84 == (abs $7E + 4) * 16` se cumple, y es **la unica
forma en que ese codigo escribe ese campo**.

---

# 3. HITPAUSE: LO QUE NO ES

## 3a. `$69` es supresion de hitstun POR PERSONAJE, no un freeze

**`[ROM]`** Esta **en el struct del personaje** (`$69(a5)`, **30 accesos** en todo
el ROM). En un 1v4 cada slot tiene el suyo, y **un golpe solo toca a los dos
involucrados**.

Sus cuatro valores, cada uno con su escritor:

| Valor | Que es | Direccion |
|---|---|---|
| `16` | golpe normal | `0x1F2E0` |
| `28` | clasheo (`$1C`) | `0x1F15E` |
| `255` | ulti de Itsuki | `0x1C078` |
| `0` | sin supresion | — |

**Correccion de nomenclatura: el clasheo es 28, NO 32.** El 32 que circulaba era
otra cosa, y el error venia de que el valor medido en ejecucion (32) y el valor
del codigo (28) se mezclaban como si fueran el mismo campo.

## 3b. El unico freeze global del ROM es la MUERTE

**`[ROM]`** El unico escritor de `$F558` en todo el ROM es:

```asm
01fa82:  move.w  #$a0, $f558.w     ; 160
```

**Es la muerte.** Ni el hitpause, ni el clasheo, ni la camara lenta tocan ese
campo.

**Y por que se le decia "hitpause" a `$69`:** porque **`$F558` vale 16 tambien en
un golpe normal**. Dos campos distintos con el mismo numero en el caso que mas
se ve. La confusion no era al azar, era **estructural**.

**`[MEDIDO]` que descarta la congelacion:** con el hitstun activo el personaje
**se mueve 1 px por frame**. No hay congelacion.

## 3c. La oscilacion de 1-2 px NO es desplazamiento: es `$54`

**`[ROM]`** `$54` es un **offset de dibujado de un frame**, y su mecanismo esta
completo:

```asm
012b4a:  moveq   #$0, d0
012b4c:  move.b  $6a(a5), d0       ; d0 = nivel de empuje
012b50:  btst.b  #$0, $69(a5)      ; ¿el hitstun es PAR?
012b56:   bne.b   $12b62           ;   si -> restar
012b58:  add.w   d0, $54(a5)       ;   no -> sumar
012b62:  sub.w   d0, $54(a5)
```

Y se limpia una vez por frame, en `0x15718: clr.w $54(a5)`.

| Parte | |
|---|---|
| **Amplitud** | `$6A` |
| **Signo** | la **paridad de `$69`** |
| **Limpieza** | `0x15718`, una vez por frame |

**`[MEDIDO]`** Coordenadas constantes mientras el sprite oscila. **Esa es la
prueba directa**, y es lo que separa "se mueve" de "solo parece moverse".

## 3d. `$6A` es el nivel de empuje, y hace DOS cosas

| | |
|---|---|
| **Amplitud del vaiven visual** | `add.w d0, $54(a5)` / `sub.w d0, $54(a5)`, **16 sitios** |
| **Magnitud del empuje real** | es el valor que se compara en el hit resolver |

**Y decrementa cada frame hasta 1:**

```asm
012b44:  subi.b  #$1, $6a(a5)
```

con corte por `cmpi.b #$1` / `bls`.

**Por que importa:** la sensacion de "la repulsion se multiplica y despues
decrece" **era una sola variable**, no dos fenomenos. **`***` El valor inicial
para un B suave no esta confirmado**; el vaiven medido de +-2 implica que arranca
en **2**, pero falta leerlo en el frame del impacto (pendiente **P2**).

---

# 4. KNOCKDOWN CONTRA BACKFLIP

## Que los diferencia

| | |
|---|---|
| **Lo mismo** | el fin del hitstun, disparado por **una sola rama**, `$7E < 0` en `0x1F4D6` |
| **Lo unico que cambia** | el **estado de salida** |

**No hay test de suelo en la rama.** Ese es el punto.

## El agarre NO produce el backflip

**`[MEDIDO]`** El agarre es **el unico lanzador que deja al rival golpeable**:

| Como se manda al rival al aire | El siguiente suave conecta? |
|---|---|
| Golpe normal en suelo | No lo manda al aire, solo empuja |
| **Agresion / especial** | Lo manda al aire, **pero knocks down**, asi que los siguientes tambien |
| **Agarre** | **Lo manda al aire y el siguiente B igual conecta** |

Los movimientos cancelables y encadenables son los especiales, y los especiales
**knocks down**. Sin agarre, cualquier secuencia termina en knockdown.

**El guion para medir el backflip es `agarre -> B inmediato -> soltar`.** Y no es
que el agarre produzca el backflip: lo unico que hace es **ponerlo en el aire con
la ventana abierta**.

**Un caso aparte que NO sirve:** Toguro Menor con ARRIBA+A en el aire golpea y
produce knockdown tanto en aire como en suelo, y ademas depende del tamanio del
enemigo (que se sortea).

---

# 5. VARIACION: EL MISMO GOLPE NO DA SIEMPRE LO MISMO

## 5a. El reporte

Tras reiteradas pruebas se determino que **el mismo golpe, contra el mismo
personaje enemigo, NO da siempre el mismo resultado**. Hay **entre 2 y 4
variables implicadas**. Los valores afectados son **el pusheo y el daño**. La
barra de aturdimiento **parece no verse afectada**.

## 5b. Los numeros, y son la parte importante

**`[MEDIDO]` con `.lua` de HP y daño:**

| Medicion | Valor | Variacion |
|---|---|---|
| **Daño de un B** | **5 a 8** | un 60 % |
| **Combo completo** | **71 a 86** | **15 puntos, mas del 20 %** |
| **Pusheo tras un B** | **1 a 4 px** | **factor 4** |

**LO MAS RELEVANTE, Y CONTRADICE LO QUE SE ESCRIBIO ANTES:**

- **El pusheo varia MUCHISIMO mas que el daño.**
- **Nunca se vio un golpe que saque el doble de daño (x2)**, ni mucho menos x3 o x4.

**Lo que se habia escrito, y estaba mal:** "hasta 4x de daño". Venia de la
aritmetica de un code path (§5f) y se presento como si fuera la medicion. **La
aritmetica misma lo desmentia**: para un B de `$65 = 8` el camino reducido daria
**3**, y el minimo medido es **5**. Si ese camino fuera la causa, jamas se habria
visto mas de 3.

## 5c. Por que NO puede ser un error de los `.lua`

Cuatro razones **independientes**, y con razon se descartaron los dos scripts:

| | |
|---|---|
| **Se reprodujo en DISTINTOS emuladores** | Si fuera error de lectura, no cruzaria plataformas |
| **Savestates que siempre cargan en el mismo punto** | Con poca vida, un golpe que en teoria no mata, **a veces mata** |
| **Se ve a OJOS, sin ningun `.lua`** | En el frame 1 del impacto la victima ya aparece **visiblemente mas alejada**, antes de la oscilacion del sprite |
| **El desplazamiento es real** | El mayor acercamiento inicial se aprecia antes de que el sprite empiece a oscilar |

**O sea que la variabilidad esta en el juego, no en la lectura.**

## 5d. MECANISMO: `$65` y `$64` son los dos POR FRAME ACTIVO

**Este es el hallazgo que explica las tres mediciones de una vez.**

```asm
01ec06:  btst.b  #$6, d4          ; ¿bit 6 = frame ACTIVO?
01ec0a:   beq.w   $1ec88          ;   no -> este frame NO pega
01ec0e:  move.b  (a2)+, $65(a5)   ; <- DAÑO, por frame
01ec12:  move.b  (a2)+, $66(a5)   ; <- STUN, por frame
01ec16:  move.b  (a2)+, $64(a3)   ; <- EMPUJE, por frame
```

**Los tres salen del MISMO registro de 8 bytes del frame**, leidos con `(a2)+`
uno tras otro. **Un B con mas de un frame activo tiene un `$65` y un `$64`
distintos en cada uno.**

| Lo que se midio | De donde sale |
|---|---|
| el B saca **5 o hasta 8** | el `$65` de dos frames activos distintos |
| el pusheo va de **1 a 4 px** | el `$64` de esos mismos frames |
| **daño y pusheo varian juntos** | **es la misma eleccion, no dos causas** |

**O sea que hay UNA variable, no dos ni cuatro.** La correlacion que se observo
es real y tiene una sola causa: **cual frame activo del B conecta.**

## 5e. Los cuatro niveles de empuje, y son DOS TABLAS

**`$64 & 3` elige el nivel**, y hay cuatro (el cuarto no hace nada):

| `$64 & 3` | `$6A` | Camino reducido | Camino completo |
|---|---|---|---|
| **0** | 1 | `$2B000` = 2,69 px/f | **`$30000`** = 3,00 |
| **1** | 2 | `$39000` = 3,56 | **`$40000`** = 4,00 |
| **2** | 3 | `$4C000` = 4,75 | **`$56000`** = 5,38 |
| 3 | — | **nada**, cae directo a `$1F398` | |

- Reducido: `0x1F33A`, `0x1F35C`, `0x1F37E`
- Completo: `0x1F442`, `0x1F464`, `0x1F486`

**Los dos caminos ponen `$6A` = 1, 2 o 3 igual.** Y **`$6A` es lo que decremente
cada frame** (§3d), o sea que la tabla de arriba es **el frame 1** y despues se
desarma sola.

## 5f. El camino reducido: el chip damage, y NO explica el B

```asm
loc_01f3d6:                       ; camino REDUCIDO
01f3d8:  move.b  $65(a3), d0
01f3dc:  lsr.b   #$2, d0          ; daño = $65 / 4
01f3de:  addq.b  #$1, d0          ; + 1
01f3e0:  sub.w   d0, $78(a4)
         ...                      ; NO toca $7E en ningun momento

loc_01f414:                       ; camino COMPLETO
01f420:  move.b  $65(a3), d0
01f424:  sub.w   d0, $78(a4)      ; daño entero, CRUDO
01f428:  move.b  $66(a3), d0
01f42c:  sub.w   d0, $7e(a4)      ; y STUN
```

| | Completo | Reducido |
|---|---|---|
| HP (`$78`) | `$65` | `$65 / 4 + 1` |
| **Stun (`$7E`)** | **`-= $66`** | **no se toca** |

Los factores reales de la reduccion: a `$65` = 1 da **1x (identico)**, a 4 da
**2x**, a 8 da **2,67x**, a 16 da **3,2x**, a 24 da **3,43x**. El 4x es el limite
asintotico, no un valor del juego.

**LO QUE ESTO PROBABA, Y SIGUE PROBANDO:** existe un camino que hace **daño sin
stun**. Ese es el perfil del **chip damage y del golpe bloqueado**.

**Y ESTO ES LO QUE HACE QUE `$63` NO SEA LA CAUSA DE LA MEDICION DEL B.** Para un
B de `$65` = 8 daria **3**, y el minimo medido es **5**. El camino reducido esta
ahi, es real, y **no es lo que produce el 5-vs-8 ni el 1-vs-4.**

## 5g. `$63` sale del estado del defensor

**`[ROM]`** Tres valores, y salen del **estado `$5F`**:

```asm
015b58:  cmpi.b  #$2d, $5f(a5)     ; ¿el estado es $2D?
015b5e:   beq.b   $15b6a
015b62:  move.b  #$4, $63(a5)      ; $63 = $04
015b6a:  move.b  #$8, $63(a5)      ; $63 = $08   (estado $2D)
015b72:  move.b  #$0, $63(a5)      ; $63 = $00   (normal)
```

Y se cruza con los datos del atacante:

```asm
01f318:  move.b  $64(a3), d0
01f31c:  andi.b  #$c, d0          ; bits 2-3
01f320:  and.b   $63(a4), d0      ; Y LA MASCARA DEL DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414          ; == 0 -> camino COMPLETO
```

**O sea que `$63` decide si el golpe ATURDE, no solo cuanto daño hace.**

## 5h. `$2D` LO ASIGNA EL JUEGO AL PEGAR, y lo elige el bit 1 de `$71`

**Esto no se sabia y cambia el lectura de `$63`.** `$2D` no aparece solo: **lo
pone el resolver**, y **el bit 1 de `$71` del DEFENSOR decide entre `$2C` y
`$2D`**:

```asm
01f3f0:  move.b  #$4, $5d(a4)
01f3f6:  btst.b  #$1, $71(a4)      ; bit 1 del DEFENSOR
01f3fc:   bne.b   $1f406
01f3fe:  move.b  #$2c, $5f(a4)     ; estado $2C
01f404:   bra.b   $1f40c
01f406:  move.b  #$2d, $5f(a4)     ; estado $2D  -> $63 = $08
```

**Y `$2D` es uno de los seis estados que RESETEAN el combo `$C6`** (`$28`-`$2D`).
O sea que **el estado que fuerza el daño reducido es el mismo que corta el
combo**: son la misma idea, uno como castigo.

**CONSECUENCIA DIRECTA:** el bit 1 de `$71` es **un flag de "recibir daño
reducido"**, y es el mejor candidato a blockstun de los cuatro (§6).

## 5i. NO hay escalado por combo

**`[ROM]`** El camino completo resta `$65` **crudo**. Sin multiplicador, y **sin
mirar `$C6`** — que se incrementa en `0x1F9F0`, o sea **despues** del golpe.

| Si hubiera prorrateo | Donde estaria |
|---|---|
| Un multiplicador por `$C6` | antes de `0x1F424` — **no esta** |
| Una tabla de escalado | en el camino completo — **no esta** |

**O sea que el 20 % de diferencia entre dos combos NO es prorrateo.** Sale de que
**los frames activos que conectaron fueron distintos**. Que es coherente con
§5d: un combo que conecta 6 frames y otro que conecta 4 tiene damages distintos
sin que haya ningun escalado.

## 5j. Es DETERMINISTA: no hay RNG

**Una observacion del usuario lo Cerro:** el esquema **es determinista**, y lo que
hace falta son **diferencias minimas entre el mismo escenario**, a veces
imperceptibles.

| Por que el mismo savestate no alcanza para que de lo mismo | |
|---|---|
| El savestate fija **el mundo** | posiciones, HP, velocities |
| **No fija la fase de la animacion** en el instante del contacto | |
| Un frame de diferencia en **cuando** conecta el golpe | ya cambia `$65` y `$64` |

**Y la razon de que el empuje se vea a ojo ya en el frame 1:** el frame activo que
conecta determina `$64`, y `$64` decide el empuje **de ese mismo frame**, antes
de que el vaiven de `$54` ocupe la pantalla.

## 5k. LO QUE SIGUE SIN PROBARSE

La relacion medida es:

> cuando la victima esta **mas inclinada hacia adelante** (hurtbox mas cerca del
> B), el pusheo es **mayor**.

**Pero la mecanica de §5d dice que el empuje NO depende de la proximidad:**
depende de que frame activo conecte.

**O sea que la proximidad, si algo, actua CAMBIANDO el frame que conecta por
timing**, no de forma directa.

**Quedan TRES explicaciones que la medicion no separa:**

| | |
|---|---|
| 1 | el **frame activo** del B que conecta |
| 2 | el **frame de la animacion** del rival, que cambia cuando conecta |
| 3 | la **proximidad** de la hurtbox — **estar golpeando DOS hurtbox a la vez** |

**Anotado asi, con las tres, y no como una sola.**

---

# 6. BLOCKSTUN: `$71` BIT 1

El pendiente 3 venia con **cuatro candidatos sin ninguno demostrado**:

| Antes | Ahora |
|---|---|
| `$63` | solo se **deduce** del estado |
| `$64` bit 5 | se prueba en `0x1F2D8`, pero su efecto no esta trazado |
| **`$71` bit 1** | **MECANISMO DEMOSTRADO** |
| `$6C` bits 0-5 | sin mecanismo |

**`$71` bit 1 gana por mucho:**

| | |
|---|---|
| **Que hace, en codigo** | elige el estado del defensor entre `$2C` y `$2D` (`0x1F3F6`) |
| **Efecto medido en la cadena** | `$2D` → `$63 = $08` (`0x15B6A`) → el golpe siguiente pega **reducido y sin stun** (`0x1F3D6`) |
| **Efecto adicional** | `$2D` **resetea el combo** `$C6` |
| **Valor medido** | **32** |

**El valor 32 medido en ejecucion es coherente con la escala** (28 clash > 16
golpe), pero **sin direccion no se puede implementar leyendo el codigo: queda
como medicion, no como dato.** Esto sigue siendo cierto con `$71`.

---

# 7. LO QUE SE DESCARTA, Y POR QUE

| Candidato | Por que se descarta |
|---|---|
| **`$89B0` como flag que suprime la hurtbox** | **Desensambla como basura.** No es codigo |
| **RNG como causa de la variacion** | El esquema es determinista (§5j) |
| **Escalado por combo** | No existe en el codigo (§5i) |
| **`$63` como causa del 5-vs-8** | Daria 3, y el minimo medido es 5 (§5f) |
| **El `$26` como hit-time** | Es un **contador de programa** sobre 8 flujos de bytes, con opcodes `$80`-`$84` |
| **`$F558` como hitpause** | Su unico escritor es `0x1FA82` = 160, **la muerte** |
| **Hit-time mas largo en las especiales** | `$69` toma 0, 16, 28 y 255. Un especial pone 16, igual que un basico |
| **El agarre como productor del backflip** | Es solo el lanzador que deja la ventana abierta (§4) |

---

# 8. LOS ERRORES QUE COMETIMOS EN ESTE HILO

Se dejan a proposito. **Un doc que solo guarda lo que quedo bien no sirve para no
repetir los pasos en falso.**

| # | El error | Por que fallo | La regla |
|---|---|---|---|
| **1** | **"El mismo golpe da hasta 4x de daño"** | Tome la aritmetica de un code path y la presente como si fuera la medicion. **La aritmetica misma lo desmentia**: para `$65` = 8 daria 3, y el minimo medido es 5 | **Comprobar que el valor predicho cae dentro del rango medido, antes de escribir un factor como efecto** |
| **2** | **"Son dos variables de distinta naturaleza"** (`$63` del defensor + `$64` del atacante) | Lo conclui **leyendo solo el resolutor**, sin contrastar con el dato medido. **La medicion mostraba una sola eleccion** | **Conclusion sacada del codigo sin el dato medido al lado = hipotesis, y se marca como tal** |
| **3** | **"El mismo `$63` elige la intensidad del empuje"** | Dije que "daño y pusheo varian juntos" sin fijarme que las dos mascaras son de campos distintos (`$64 & $0C` y `$64 & $3`) | **Dos mascaras en el mismo resolver no son la misma variable** — ni la misma ni la opuesta |
| **4** | **"El clasheo es 32"** | Mezcle el valor medido (32) con el del codigo (`$1C` = 28), que son campos distintos | **Un valor medido y un valor de codigo no se promedian** |
| **5** | **Dejar "queda abierto, hace falta un RNG"** | Crie la duda sin haber considerado que un savestate **no fija la fase de la animacion** | **Antes de invocar un RNG, probar que el escenario es identico hasta el frame del contacto** |

---

# 9. PENDIENTES, POR COHERENCIA

Ordenados de **mas coherente y mas facil de comprobar** a **menos probable**. La
coherencia es la fuerza de la hipotesis, y la facilidad es si una sola lectura la
confirma o la descarta.

## P1 — `$71` bit 1 es el blockstun · COHERENCIA ALTA, UNA LECTURA

**Por que es el primero:** es el unico candidato con **el mecanismo entero
trazado en el codigo** (§6). No es una conjetura, es una cadena de tres
instrucciones que se puede leer de punta a punta.

**Que hay que leer:** `$71` bit 1 del defensor en el frame de un golpe bloqueado,
y el valor de `$7E` en el mismo frame.

| Si | Entonces |
|---|---|
| bit 1 activo y `$7E` = 32 | **confirmado**, y el blockstun tiene direccion |
| bit 1 inactivo con el bloqueado puesto | el blockstun es otro campo, y `$71` solo gobierna el estado |

**Costo:** un `.lua` pasivo, una lectura en el frame del contacto.
**Riesgo de falsos positivos: bajo.** El mecanismo ya existe en el codigo.

## P2 — El valor inicial de `$6A` en un B suave · COHERENCIA ALTA, UNA LECTURA

**Por que:** el vaiven medido de **+-2** implica que `$6A` arranca en **2**, y
`0x12B44` lo decrementa hasta 1. Falta **leerlo**, no deducirlo.

| Si | Entonces |
|---|---|
| `$6A` = 2 al_contactar | **confirmado**, y ademas da el empuje del frame 1 |
| `$6A` = otro valor | el vaiven de `$54` no lo explica solo, y hay que buscar el otro escritor |

**Costo:** una lectura. **Es el pendiente mas barato de la lista.**

## P3 — Los frames activos del B · COHERENCIA ALTA, UNA LECTURA

**Por que:** es la prediccion mas fuerte del hilo. **§5d dice que `$65` y `$64`
son por frame activo.** Si un B tiene dos frames activos con datos distintos, al
conectar uno u otro se obtiene 5 o 8 de daño y 1 o 4 de empuje.

**Que hay que medir:** en el frame de cada contacto, `$65`, `$66` y `$64` del
atacante, y el frame del anim (`$59`).

| Si | Entonces |
|---|---|
| dos contactos con `$59` distintos y `$65` distintos | **todo el §5 confirmado de una** |
| un solo frame activo y `$65` siempre igual | **el mecanismo esta mal**, y hay que buscar el multiplicador que no encontramos |

**Este es el test que mas informacion da por unidad de esfuerzo**, porque puede
**refutar** la hipotesis, no solo confirmarla.

## P4 — La divergencia knockdown / backflip · COHERENCIA MEDIA, MAS TRABAJO

**Lo que se sabe:** los dos eventos entran **identicos** hasta el frame 25, y se
separan antes del 37. La rama es una sola (`$7E < 0`, `0x1F4D6`) y **no testea
el suelo**.

**Lo que falta:** el test de "¿esta en el suelo?" tiene que estar **antes**, en la
maquina de estados que elige el estado de salida.

| Donde buscar | |
|---|---|
| Los consumidores de `$0C` / `$40` cerca de `0x1F4E2` | el mas probable |
| La comparacion con el suelo del stage | `$A010` / `$A012`, el mismo patron que usa `0x1F3B6` |
| **`Y = 320` en el suelo, medido** | da el valor de referencia |

**Costo:** lectura estatica, y una confirmacion medida.
**Riesgo: medio.** El rango de la busqueda es chico si se empieza por los
consumidores de `$0C` cerca de `0x1F4E2`, pero **puede ser que el test de suelo
este en el consumidor de `$7E` y no en la maquina de estados.**


## P5 — La flag que suprime la hurtbox · COHERENCIA MEDIA-BAJA

**Lo que se sabe:** la hurtbox **desaparece en el frame 24** y vuelve despues, y
el intervalo dura **13 frames hasta el backflip**.

**Lo que falta:** la direccion. **`$89B0` desensambla como basura**, asi que no es
ese.

| Donde buscar | |
|---|---|
| Los escritores de `$89` | se sabe que `0x1F2A6` hace `bset.b #$3, $89(a3)`, asi que `$89` **si** es un campo de flags |
| El contador de hurtbox (`$FFA008`) | desaparece y vuelve, asi que **algo** lo borra |
| Los cinco contadores que el dispatcher pone en 0 | el borrado esta en `$1EDC2` |

**Costo:** lectura estatica. **Es el que mas trabajo cuesta hoy**, porque no hay
pista directa y `$89B0` ya salio como basura.

## P6 — Los 8 frames · COHERENCIA BAJA

**Lo que se sabe:** hay un segundo gap de **8 frames** sin causa localizada, y
`$1BCB0` es un **acumulador contra 256** con tres meanings de `$84` encima.

**Riesgo: alto.** `$84` tiene 13 accesos y tres significados; cualquier lectura
sin separar los tres mezcla los campos. **Se descarta primero** si hay que elegir.

## P7 — La proximidad · COHERENCIA BAJA

**Lo que se sabe:** es la **correlacion medida** (§5k), y la mecanica dice que el
empuje no depende de la proximidad.

**Que la haria prueba:** medir si cuando la victima esta inclinada cambia el
**frame activo que conecta** (P3). Si no cambia, la proximidad actua por otro
camino que **no hemos encontrado**.

**Costo:** depende de P3. **No se puede atacar antes.**

---

# 10. RESUMEN DE DIRECCIONES

Todas en `game_68000.asm`.

| Direccion | Que |
|---|---|
| `0x1EC06` | test de frame activo (bit 6) |
| `0x1EC0E` | `$65` = daño, **por frame** |
| `0x1EC12` | `$66` = stun, **por frame** |
| `0x1EC16` | `$64` = empuje + mascara de daño, **por frame** |
| `0x1F318` - `0x1F328` | AND de `$64 & $0C` con `$63`: camino completo o reducido |
| `0x1F330` - `0x1F398` | 4 niveles de empuje del camino reducido |
| `0x1F3D6` - `0x1F3E0` | camino reducido: `$65/4 + 1`, **sin stun** |
| `0x1F3F6` - `0x1F406` | `$71` bit 1 elige `$2C` / `$2D` |
| `0x1F414` - `0x1F42C` | camino completo: `$65` crudo, `-= $66` a `$7E` |
| `0x1F442` - `0x1F4A0` | 4 niveles de empuje del camino completo |
| `0x1F4D6` | **la rama unica**: `$7E < 0` |
| `0x1F4E2` | velocidad de empujon: `$84 = (abs $7E + 4) * 16` |
| `0x1F9F0` | `addi.b #$1, $c6(a4)` — **despues** del golpe |
| `0x12B44` | `$6A` decrementa hasta 1 |
| `0x12B4C` - `0x12B62` | `$54`: amplitud `$6A`, signo por paridad de `$69` |
| `0x15718` | `clr.w $54(a5)` — limpieza por frame |
| `0x15B58` - `0x15B72` | `$63` desde el estado `$5F`: `$00` / `$04` / `$08` |
| `0x1A282` | `$7E = $FF` (255): proteccion al levantarse |
| `0x1C078` | `$69 = $FF` (255): ulti de Itsuki |
| `0x1FA82` | `$F558 = 160`: **el unico freeze global, la muerte** |
| `0x1F2E0` | `$69 = 16` (golpe), `$75 = 17` |
| `0x1F15E` | `$69 = 28` (`$1C`) clasheo, `$75 = 29` (`$1D`) |

---

# 11. LO QUE NO SE TOCA

**Regla 5 del proyecto: los `.lua` son pasivos.** Ninguna escritura a la memoria
del juego. El unico `write` permitido es el de `print`.

**`yuyu_knockdiag.lua` NO FUNCIONA en esta build** y no hay que reintentar sin
resolver antes por que. Se resolvieron el PC equivocado (`$01EDC2`, detras de una
guardia cuyo destino es un `rts`) y el re-armado por frame (FBNeo borra los exec
en cada reset), y **no alcanzo**.

**Lo que si quedo bien y sirve de modelo:** el **latido** (convierte "no lee nada"
en un sintoma con numero), el `pcall` con flag propio, el conteo de hurtboxes
**por owner**, y la firma `$84 == (abs $7E + 4) * 16`.

**Para las mediciones de §9: la medicion del backflip se hace A MANO con el HUD
de cajas**, no con ese script.
