# VARIACION DE DANOS, HITPAUSE Y KNOCKDOWN

Todo lo que se resolvio —y lo que se abrio— el **07-10-2026** en el tema del
**golpe**: que es el hitpause, que es el knockdown, que es el backflip, y por que
el mismo golpe no da siempre lo mismo.

**Este documento no reemplaza a `VERIFICACION.md`.** Es la unica fuente de
verdad y sigue siendo la que manda. Acá esta el **detalle del hilo**, con las
correcciones y los errores del camino a la vista, porque **un doc que solo
guarda lo que quedo bien no sirve para no repetir los pasos en falso**.

| Documento | Que se lee |
|---|---|
| `VERIFICACION.md` §2, §2b, §2d, §2e, §5e | El dato, seco |
| **`DANO-HITPAUSE-KO.md`** | **El hilo completo, con lo refutado** |
| `docs/08-DIARIO/MEMORIA.md` | Memoria de trabajo y trampas |

## Como se marca lo que no esta confirmado

| Marca | Significado |
|---|---|
| `[ROM]` | Hay direccion en `desensamblado_68000.asm` al lado |
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

Todas en `desensamblado_68000.asm`.

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

**`diagnostico_knockdown.lua` NO FUNCIONA en esta build** y no hay que reintentar sin
resolver antes por que. Se resolvieron el PC equivocado (`$01EDC2`, detras de una
guardia cuyo destino es un `rts`) y el re-armado por frame (FBNeo borra los exec
en cada reset), y **no alcanzo**.

**Lo que si quedo bien y sirve de modelo:** el **latido** (convierte "no lee nada"
en un sintoma con numero), el `pcall` con flag propio, el conteo de hurtboxes
**por owner**, y la firma `$84 == (abs $7E + 4) * 16`.

**Para las mediciones de §9: la medicion del backflip se hace A MANO con el HUD
de cajas**, no con ese script.
## 5. Dano

- El dano se calcula en `0x1F3D8` (`move.b $65(a3),d0 / lsr.b #$2,d0 /
  addq.b #$1,d0 / sub.w d0,$78(a4)`. El dano sale del byte `$65` del atacante
  (un cuarto de su valor, mas 1), y se clampa a 0 en `0x1F3EC`.
- El golpe solo aplica dano si el atacante tiene bit 4 de `$64`:
  `btst.b #$4,$64(a3)` en `0x1F3CE`.
- BizHawk capturo **408 impactos** en attract mode con deltas de 1, 4, 8, 12,
  16, 18, 20, 24, 32 y 48. Ojo: esos deltas se/leian de `$B8`, que ahora
  sabemos que es maná, asi que la tabla **no** es de dano y hay que repetirla
  leyendo `$78`.

Verificado por medicion:

| Caso | Dano | Recovery |
|---|---|---|
| Cadena rapida (A/B followed de golpe) | 1 | 4 frames |
| Proyectil | — | 88-92 frames (largo, punish) |

## 5a. El resolver tiene DOS caminos de daño, y solo uno mete stun

**Este es el dato que acota la busqueda del blockstun.** En `loc_01F21E` hay dos
formas de aplicar el golpe, y no son la misma:

**Camino COMPLETO**, desde `loc_01F414`:

```asm
01f414:  moveq   #$0, d0
01f416:  clr.w   $84(a4)        ; knockback a 0
01f41a:  move.b  #$ff, $86(a4)  ; $86 = $FF
01f420:  move.b  $65(a3), d0
01f424:  sub.w   d0, $78(a4)    ; daño COMPLETO
01f428:  move.b  $66(a3), d0
01f42c:  sub.w   d0, $7e(a4)    ; y STUN
```

**Camino REDUCIDO**, desde `loc_01F3D6`:

```asm
01f3d6:  moveq   #$0, d0
01f3d8:  move.b  $65(a3), d0
01f3dc:  lsr.b   #$2, d0        ; daño = $65 / 4
01f3de:  addq.b  #$1, d0
         ...                      ; NO toca $7E
01f410:  bra.w   $1f50a
```

Y el que elige entre los dos:

```asm
01f318:  move.b  $64(a3), d0
01f31c:  andi.b  #$0c, d0
01f320:  and.b   $63(a4), d0    ; mascara de defensa del DEFENSOR
01f324:  cmpi.b  #$0, d0
01f328:   beq.w   $1f414        ; == 0 -> camino COMPLETO, con stun
```

### Lo que esto prueba

**El juego tiene un camino que hace daño SIN aplicar stun.** El reducido aplica
`$65/4 + 1` y no toca `$7E` en ningun momento. Ese es el perfil del **chip
damage**, y tambien del golpe bloqueado.

| | Camino completo | Camino reducido |
|---|---|---|
| Daño | `$65` entero | `$65 / 4 + 1` |
| Stun | si, `sub.w $66,$7E` | **no** |
| `$84` (knockback) | `clr.w` | — |

**Consecuencia para el blockstun: NO esta en `$7E`.** Si un golpe puede hacer
daño sin pasar por `$7E`, entonces "stun de golpe" y "stun de bloqueo" son dos
cosas distintas en dos campos distintos. Buscar el blockstun en `$7E` era buscar
en el lugar equivocado.

**Lo que SIGUE sin locating:** cual es el campo del blockstun. El camino reducido
lo esquiva por completo, asi que hay que mirar **despues** de `0x1F32C`, que es
donde el golpe bloqueado prepara el empujon (`$10 = $2B000`, `$14 = $FFFC0000`,
`$6A = 1` en `0x1F33A`) antes de caer al reducido.

**Ojo con una cosa:** hay un branch en `0x1F3D4` (`beq.b $1f3f0`) que puede
saltar el camino reducido entero. As que el reducido no es automatico: hay al
menos un caso mas que lo evita.

## 5b. Los freezes: CUATRO, y ninguno es el hit-time de las especiales

| Sistema | Valor | Donde | Que frena |
|---|---|---|---|
| Hitpause | **16** | `0x1F2E0` | solo a3 y a4 |
| Clash | **28** (`$1C`) | `0x1F15E` | a3 |
| Congelacion de Itsuki | **255** (`$FF`) | `0x1C078` | **todos los que no son aliados** |
| Camara lenta de muerte | **160** (`$A0`) | `0x1FA82` | **TODO, es global** |

### `$69` hitpause y `$75`

`$75` va **siempre con `$69 + 1`**, en los dos resolvers:

```asm
01f2e0:  move.b   #$10, $69(a3)     ; 16
01f2e6:  move.b   #$11, $75(a3)     ; 17
01f2ec:  move.b   #$10, $69(a4)
```

Clash en `0x1F15E` (`#$1C` = 28, y `$75 = #$1D` = 29). El camino sin hit pone los
dos a 0 en `0x1F16C`.

**El bit 5 de `$64` del atacante ANULA el hitpause.** No lo baja: lo deja en 0.

```asm
01f2d8:  btst.b   #$5, $64(a3)
01f2de:   bne.b    $1f2f4
01f2e0:  move.b   #$10, $69(a3)     ; bit 5 puesto -> 16
...
01f2f4:  move.b   #$0,  $69(a3)     ; bit 5 ausente -> 0 freeze
01f2fa:  move.b   #$1,  $75(a3)
01f300:  move.b   #$0,  $69(a4)
```

O sea que en el mismo golpe hay **dos valores de freeze** segun `$64` bit 5: 16 o
0. Eso es lo que hace que algunos golpes no congelen, y no es un bug.

### Que se congela es SALTARSE el tick, no un contador

El unico consumidor de `$69` esta en `0x12AF4`, y lo que hace es **no llamar al
tick del frame data**:

```asm
012af4:  cmpi.b   #$0, $f55a.w     ; primero el global
012afa:   bne.b    $12b2e
012afc:  cmpi.b   #$0, $69(a5)     ; luego el propio
012b02:   bhi.b    $12b36
012b04:  clr.b    $6a(a5)
012b08:  jsr      $19c96          ; --- con freeze, todo esto se salta ---
012b16:  jsr      $1fbaa
012b1c:  jmp      $3556
loc_012b22:
012b22:  jsr      $1eb40          ; el tick del frame data
012b28:  jsr      $156f0          ; recalcular posicion
loc_012b2e:
012b2e:  jmp      $1580
loc_012b36:
012b36:  subi.b   #$1, $69(a5)    ; descontar
```

**`$69` SI es un timer**: lo decrementa `0x12B36`. Lo que hace es gatear el tick.

**Y hay 16 gates, no uno.** `$1EB40` tiene 16 llamadores, y cada uno tiene **su
propio `jmp $1580` a 18 bytes** (`0x12384`, `0x12B22`, `0x12C38`, `0x12D76`,
`0x12E98`, `0x12FBC`, `0x130EE`, `0x13244`, `0x136C6`, `0x137E0`, `0x139F4`,
`0x13DEE`, `0x142A0`, `0x14576`, `0x14832`, `0x15B78`). Son 16 estados del
personaje, cada uno con su condicion de freeze. **El hit-time de una especial
tiene que estar en uno de esos 15 que no se han mirado.**

### El 255 es la ulti de Itsuki (medido en ejecucion)

`loc_01C06A` recorre los 4 slots y congela a los que no son del mismo equipo:

```asm
01c06a:  lea.l    $8400.w, a0
01c06e:  move.b   $6e(a0), d1
01c072:  cmp.b    $6e(a5), d1
01c076:   beq.b    $1c07e
01c078:  move.b   #$ff, $69(a0)     ; 255
01c07e:  cmpa.w   #$9000, a0
01c082:   beq.b    $1c096
01c084:  adda.w   #$400, a0
01c088:  bra.b    $1c06e
```

**Medido: 255 frames exactos, y coincide con el `#$ff` del codigo.**

| Observado en ejecucion | Por que pasa |
|---|---|
| Congela **solo enemigos** | El bucle compara `$6E` contra el del lanzador |
| **No afecta proyectiles** | `$6E` se propaga a los hijos: `move.b $6e(a5), $6e(a1)` en `0x1A46C` y 9 mas. Los proyectiles propios llevan el `$6E` del dueno |
| **Se descongela con CUALQUIER impacto**, incluso sin dano | No hay contador que llegue a 0: el resolver **sobrescribe** el byte. `0x1F2E0` pone 16, `0x1F2F4` pone 0 |

**`$6E` es una etiqueta de pertenencia, no un byte de equipo suelto.** Es lo que
explica por que los proyectiles propios no se congelan.

TELEPORT (Itsuki): abajo-arriba + A / B / C   [MEDIDO en ejecucion, 07-10-2026]

Nombre coloquial: **Teleport A**, **Teleport B**, **Teleport C**.
NO es un nombre del juego: es la referencia con la que trabajamos.

COMANDO
  Abajo, Arriba, y despues A, B o C. Las tres gastan maná.
  El joystick del Sega NO permite oprimir direcciones opuestas a la vez, asi que
  abajo-arriba a la vez no es una entrada real de esta consola (el juego la acepta igual).

LO QUE SE SABE DE LAS TRES

| | |
|---|---|
| **Costo** | **16 de maná, idéntico en las tres** (223 -> 207) |
| **A** | teletransporta a la zona **izquierda** |
| **B** | teletransporta al **centro** |
| **C** | teletransporta a la zona **derecha** |

*** OJO: LAS TRES COMPARTEN EL MISMO ID DE $5F ***

En la primera prueba real del script, tres variantes de esta tecnica y **solo se
anotaron 2**. La causa NO fue del script ni de la medicion: el guardia de
"una fila por tecnica" casteaba por `(slot, id)` y **las variantes comparten el
id**, asi que la tercera quedo tapada. El guardia se saco.

**Y que las tres cuesten EXACTAMENTE lo mismo, con el mismo efecto y distinto
destino, es la prueba de que es UNA tecnica con un parametro** — el boton elige
la zona — y no tres tecnicas distintas.

### [MEDIDO 07-10] LAS TRES TIENEN EL MISMO REGISTRO, BYTE POR BYTE

Segunda corrida del usuario, con el maná recargado al 100 % antes de cada
variante. Las tres salen announced y **los datos son identicos**:

| | Teleport A | Teleport B | Teleport C |
|---|---|---|---|
| id de `$5F` | `$08` | `$08` | `$08` |
| registro | `$0CFBFA` | `$0CFBFA` | `$0CFBFA` |
| duracion (`byte +0`) | `$10` | `$10` | `$10` |
| los 8 bytes | `10 17 08 94 7C 00 83 7F` | idem | idem |

**Contexto de la tabla, confirmado leyendo el `.bin`:** `$50 = $0CF99A`,
`$8C = $0D069A`. Es el **contexto 6** de `auditar_moves.py`
(`BASE50[6] = 0xCF99A`; `BASE50[7] = 0xD1E5A`).

*** CORRECCION: en la primera anotacion de esto se puso "contexto 7". Es el 6. ***
Ese contexto tiene los **191 moves** documentados, comprobado leyendo el indice
hasta el primer offset 0 (indice 191).

*** Ojo: Itsuki y Kurama estan los dos en los contextos 1 y 7, asi que el
numero de contexto NO alcanza para decir de quien es la tabla. *** Lo que la
identifica es que la tecnica es el teletransporte de Itsuki.

### [VERIFICADO 07-10] LOS REGISTROS, LEIDOS DEL `.bin`

Leidos **del archivo**, no desde Lua, con
`w16(a) = int.from_bytes(rom[a:a + 2], "big")`, que es lo que ya hace
`herramientas/desensambladoauditar_moves.py:40`.

| | Valor |
|---|---|
| `word[$0CF9AA]` (offset del id 8) | `$0260` |
| `$0CF99A + $0260` | **`$0CFBFA`**, el registro anunciado |
| los 8 bytes | `10 17 08 94 7C 00 83 7F` |
| tabla B (`mult = $17`) | `$0D06F6` = `18 17 03 98` |
| golpe (`+ $0398`) | `$0D0A8E` |

**LAS TRES COSAS COINCIDEN CON LO QUE ANUNCIO EL SCRIPT.** O sea que **la
lectura desde Lua era CORRECTA**.

*** CORRECCION IMPORTANTE: lo que se concluyo antes, de que "el ROM no esta
expuesto bien a Lua", es FALSO. *** La autoprueba daba `byte(+0) = $10` contra
`$5A = $06`, y se leyo como "la lectura es ruido". Los dos valores son reales:
`$10` es el registro del `.bin` y `$06` es el `$5A` de **aun**. O sea que **en el
frame del anuncio el move no habia arrancado todavia**. El aviso era correcto y
la conclusion era equivocada.

**Consecuencia sobre el `$5F` anunciado: tambien puede ser el del estado
ANTERIOR**, por el mismo motivo. Ver la seccion siguiente.

### [MEDIDO 07-10, 2a corrida] EL ID DEL TELEPORT **CAMBIO**, Y ESO ES EL DATO

Tercera corrida, esta vez **desde el centro** del stage, con el script nuevo. Se
anuncio:

```
[MOV 01] P1  ^A    id=$0D ( 13)  mana -16  registro=$0CFC72
       frame=0 (pulsada en el 799)  dur=04
```

**El MISMO boton (A), en la corrida anterior dio `id=$08`, registro `$0CFBFA`,
`dur=$10`. Ahora da `id=$0D`, registro `$0CFC72`, `dur=$04`.**

Los tres datos de esta vez **coinciden con el `.bin`**:

| | anunciado | `.bin` | coincide |
|---|---|---|---|
| id | `$0D` = 13 | — | — |
| registro | `$0CFC72` | `$0CF99A + word[13] = $0CF99A + $02D8` | **si** |
| duracion | `$04` | `byte(+0)` de id 13 = `$04` | **si** |

O sea que **las dos lecturas son correctas contra el ROM**, y aun asi el id no es
el mismo. **Conclusión: el `$5F` que anuncia el script NO es estable, porque se
lee en el frame de la pulsada, y en ese frame el juego todavia no arranco el
move.** Es el mismo problema del `$5A` que hacia fallar la autoprueba, y ya no es
una hipotesis: **esta medido dos veces con resultados distintos.**

### *** LA HIPOTESIS DE LOS IDS 6/7/8 SE DEBILITA ***

Id 13, del `.bin`:

| id | registro | bytes `+2..+5` | mult | tabla B |
|---|---|---|---|---|
| 6 | `$0CFB9A` | `08 94 7C 00` | `$1B` | `$0D0706` |
| 7 | `$0CFBCA` | `08 94 7C 00` | `$1C` | `$0D070A` |
| 8 | `$0CFBFA` | `08 94 7C 00` | `$17` | `$0D06F6` |
| **13** | `$0CFC72` | **`80 0A 00 00`** | `$1D` | `$0D070E` |

**El id 13 NO comparte la familia `08 94 7C 00`.** Si los tres botones fueran los
ids 6, 7 y 8, el id 13 no tendria que haber salido. *** Queda abierta la
alternativa de que A, B y C sean, por ejemplo, **13, 12 y 14**, que son los ids
que la corrida todavia no ha separado. *** No se afirma nada hasta medir la
secuencia de `$5F`, que es lo que imprime el renglon nuevo.

*** Y el crash que corto esa corrida viene de ahi: el renglon de `$5F vivo` se
imprimio con `%02X` recibiendo `hex2(e.estado)`, y con `$0D` —que tiene letra—
`string.format` revienta. O sea que el dato que mas nos importaba es
precisamente el que disparo el crash. *** Ver `docs/08-DIARIO/MEMORIA.md`, la trampa de `%X` con
un string.

### *** LOS IDS 6, 7 Y 8: UNA FAMILIA REAL, PERO NO NECESARIAMENTE LA NUESTRA ***

Del mismo `.bin`, mismo contexto:

| id | registro | 8 bytes | mult | tabla B |
|---|---|---|---|---|
| **6** | `$0CFB9A` | `0C 1B` **`08 94 7C 00`** `80 7D` | `$1B` | `$0D0706` |
| **7** | `$0CFBCA` | `0C 1C` **`08 94 7C 00`** `7E 76` | `$1C` | `$0D070A` |
| **8** | `$0CFBFA` | `10 17` **`08 94 7C 00`** `83 7F` | `$17` | `$0D06F6` |

**Los tres comparten los bytes `+2 +3 +4 +5` = `08 94 7C 00`**, y solo difieren
en duracion (`+0`), multiplicador de tabla B (`+1`) y velocidades (`+6`, `+7`).
Esa es la firma de **tres variantes de una misma tecnica**.

*** HIPOTESIS, AHORA DEBILITADA: A, B y C son los ids 6, 7 y 8. *** El id que
salio en la segunda corrida fue `$0D`, que **no** es de esa familia. Sigue siendo
posible — si los tres botones usaran 6/7/8, el 13 seria estado anterior — pero ya
no es la lectura por defecto.

El indicio sigue siendo el del `$5A`: si en el frame de la pulsada el `$5A` es el
del estado anterior, el `$5F` tambien lo es, y las tres variantes saldrían
identicas o distintas solo por estar midiendo el frame equivocado. **Con el id
cambiando entre corridas eso ya no es hipotesis: es lo que se midio dos veces.**
La secuencia de `$5F` es lo que lo cierra.

**Como se cierra, sin suponer nada:** `ITSUKI SET MOVE.LUA` ahora imprime, en
cada anuncio, el **`$5F` vivo** en el frame de la confirmacion **y la secuencia
de los 8 frames** hacia atras desde el de la pulsada. Si tres anuncios distintos
dan `$06`, `$07` y `$08`, la hipotesis es correcta. Si los tres dan el mismo,
las tres son el mismo id y la zona se lee en otro lado.

### [MEDIDO 07-10] LAS TRES ZONAS, Y LOS 39 FRAMES

Tercera corrida, **desde el centro**, en orden **C → A → B**. Las tres salieron
limpias: sin crash, sin falsos, y cada `[TELE]` atribuido a su `[MOV]` con
exactamente **39 frames** de delay. Tres de tres.

| variante | pulsada | cayo en | **mundo X** | **pantalla `$08`** | desplazamiento |
|---|---|---|---|---|---|
| **C** (derecha) | 299 | 338 | **1281** | **432** | +148 |
| **A** (izquierda) | 497 | 536 | **1025** | **176** | −256 |
| **B** (centro) | 636 | 675 | **1149** | **304** | +124 |

**Las tres zonas son ABSOLUTAS, no relativas.** Se prueba con el orden: C salió
desde el centro, A desde la derecha y B desde la izquierda, y las tres'arrivée
a la misma coordenada de destino que si hubieran salido del mismo lugar.

| | |
|---|---|
| **separación en pantalla** | **128 px exactos** (176 → 304 → 432) |
| separación en mundo | 124 y 132 (**no uniforme**) |

La diferencia entre las dos mesures es que **la camara se mueve** entre un salto
y otro: el mundo se corre 4 px y la pantalla 128, y al reves. En `$08` — que es
lo que el jugador ve — la separación es de 128 clavados.

**Y esto cierra la duda de la corrida anterior:** la vez pasada el personaje
estaba en `X = 1025`, que es **exactamente la zona izquierda**. Por eso Teleport
A no lo movio: no estaba fallando, ya estaba ahi. La explicacion del clamp era
equivocada.

### [MEDIDO 07-10] `$5F` NO DISTINGUE LAS TRES VARIANTES

Este es el resultado negativo de la corrida, y es el importante:

```
[MOV 01] P1  ^C    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $01 $01
[MOV 02] P1  ^A    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $01 $01
[MOV 03] P1  ^B    id=$0D ( 13)  mana -16  registro=$0CFC72
       $5F vivo=$A4 (el de la pulsada era $0D)   secuencia: $A4 $0D $0D $0D $0D $0D $02 $01
```

**Los tres dan exactamente lo mismo: `$0D` en la pulsada, `$A4` vivo, registro
`$0CFC72`. Ni un solo valor distinto entre A, B y C.**

Leyendo la secuencia (el primer valor es el frame actual, y el segundo es el de
la pulsada):

| frames antes | `$5F` | que es |
|---|---|---|
| 7 y 8 | `$01` | **parado** |
| 6 | `$02` | *(un estado transitorio, solo aparece en la 3a)* |
| 2 a 6 | `$0D` | **el estado de la secuencia ↓↑** |
| 1 | `$0D` | la pulsada |
| 0 | `$A4` | **el teleport en curso** |

*** `id = $0D` es el estado del comando ↓↑, no la variante: aparece ~5 frames
ANTES de que se pulse el boton. *** Y **`$A4` es el teleport ya arrancado**, y es
comun a las tres variantes.

**Consecuencia:** **la zona no esta en `$5F`.** Ni en `$0D` ni en `$A4`. Y
tampoco en el registro de 8 bytes, que es identico en los tres casos. O sea que
**la eleccion de zona se hace en el frame 39**, cuando el personaje se coloca, y
no se deduce de ningun dato de la tabla: hay que ver que lee el juego en ese
momento.

*** Candidato: el boton. La secuencia no muestra diferencia porque `$5F` no la
guarda. Habria que mirar un campo de entrada o el codigo que escribe `$40`/`$44`
en el frame de la colocacion. ***

### *** QUE ES `$0D` Y QUE ES `$A4`: DOS HIPOTESIS, Y COMO SEPARLAS ***

*** No verificado. *** De la corrida solo sale esto:

| `$5F` | cuando | lectura |
|---|---|---|
| `$01` | parado, antes de todo | estado de reposo |
| `$02` | un frame, en la 3a corrida | transitorio, sin identificar |
| `$0D` | **5 frames terminando en el de la pulsada** | ??? |
| `$A4` | desde 1 frame despues de la pulsada | el teleport en curso, comun a las tres variantes |

**Lo que NO sabemos:** si `$0D` es un estado de posicion (agachado), o el primer
paso del comando abajo-arriba, o un buffer de comando. Las tres se ajustan a "5
frames y se va un frame despues de la pulsada".

*** Las hipotesis del usuario, que son las buenas: ***

1. `$0D` = **agacharse**. Predecible: mientras se mantenga abajo, `$5F` deberia
   quedarse en `$0D` indefinidamente, y volver a `$01` al soltar.
2. `$0D` = **el primer paso del comando ↓↑**. Predecible: mantener abajo 3
   segundos y despues pulsar el boton NO deberia dejar `$0D` en los 8 frames
   previos a la pulsada, porque el abajo ya se solto hace rato.
3. `$0D` = **un buffer que se esta preparando** para la tecnica. Predecible:
   deberia aparecer solo con la secuencia ↓↑ completa, y no con un abajo suelto.

**Como separarlas, sin codigo:** el HUD muestra `mov $XX` = `$5F` en vivo. Con
↓ mantido 3 segundos se mira la pantalla y se lee.

| lo que se vea | conclusion |
|---|---|
| `$0D` y se mantiene | es **agachado** (o similar) |
| `$01` mientras se mantiene abajo | **abajo solo no produce `$0D`** |
| parpadea o cambia | es un **transitorio de transicion** |

`ITSUKI SET MOVE.LUA` ahora imprime ademas una linea `[`$5F`]` en **cada cambio**,
aunque no se gaste maná, para tener el registro escrito y ver cuanto dura cada
estado. Antes no servia: el rastreador solo anuncia con gasto de maná, asi que
agacharse 3 segundos no producia **ni una sola linea**.

### [MEDIDO 07-10] LA ESCALERA DE `$5F`, CON DURACIONES

Con el aviso de cambios de `$5F` se ve la secuencia completa del teleport:

| frame | cambio | `$59` | `$5A` | estado | cuanto duro |
|---|---|---|---|---|---|
| 166 | `$00 → $01` | 0 | `$06` | aparece en la pelea | 7 frames |
| 173 | `$01 → $02` | 0 | `$04` | **reposo** | **298 frames** |
| 471 | `$02 → $0D` | 0 | `$04` | **un frame** | **1 frame** |
| 472 | `$0D → $A4` | 0 | `$06` | **el teleport** | 38 frames |
| 510 | `$A4 → $A5` | 0 | `$01` | vuelta/aterrizaje | 46 frames |
| 556 | `$A5 → $00` | 0 | `$0C` | vuelve al principio | — |

**DOS CORRECCIONES A LO QUE SE DIJO ANTES:**

1. **`$02` no es un transitorio: es el estado de REPOSO, y duro 298 frames**
   (5 segundos parado). En la corrida anterior appeared un solo frame y se leyo
   como un estado transitorio. Es el estado normal de quieto.

2. **`$0D` no duro 5 frames: duro 1.** La secuencia de la corrida anterior
   (`$A4 $0D $0D $0D $0D $0D`) lo hacia parecer de 5. **Lo que dura cambia entre
   corridas**, porque depende de cuanto se mantenga la entrada antes del boton.
   En esta, `$0D` fue **exactamente el frame de la pulsada** y nada mas: `$02` en
   el 470, `$0D` en el 471 (pulsada), `$A4` en el 472.

*** Consecuencia para las hipotesis del usuario: `$0D` es el estado del FRAME en
que se acepta el comando, no un estado de posicion. No se mantuvo nada tiempo, y
la duracion depende de la entrada, no de una condicion. ***

### [MEDIDO 07-10] LA ZONA IZQUIERDA, TERCERA CONFIRMACION

`[TELE 1] mundo X = 1025`. Es la **tercera medicion** de la misma zona: 1281
(derecha), 1025 (izquierda), 1149 (centro), y ahora 1025 otra vez desde otra
posicion de partida (1133).

### *** EL MANA BAJO 20 SIN QUE SE ANUNCIARA NADA ***

`maná P1 = 187` en el frame 600, cuando la tecnica gasto 16 de 223. O sea que
**faltan 20 mas** y ninguna pulsada gasto. No hay explicacion y queda abierto:
puede ser un refill del training mode con otro formato, o una tecnica que no
llego a la puerta de maná. *** No se investiga hasta tener otra medicion. ***


### *** LO QUE NO SE SABE, Y NO SE PUEDE ADIVINAR ***
- **La zona NO esta en la tabla A ni en la tabla B.** Verificado en el `.bin`:
  los 8 bytes del registro y los 4 del subregistro son los mismos para las tres.
  Lo que las separa tiene que leerse **en ejecucion**: el boton pulsado, o un
  campo del struct que el juego escribe al arrancar el move.
- **No hay una direccion de CODIGO propia del teletransporte.** El unico punto
  verificado es `loc_011F3E` (`0x11F3E: move.b d0, $5f(a5)`), que es el
  "arrancar el move N" generico de todas las tecnicas. **Donde el juego decide el
  destino no esta buscado.** El candidato natural es un escritor grande de `$40`
  que no sea el `add.l` de la velocidad (`0x14AA4`), y el mas sospechoso es
  `0x14AB6: move.w $40(a0), $40(a5)`, que **copia la posicion desde el objeto
  apuntado por `$48`** — o sea que un teletransporte podria ser "apuntar `$48` a
  un marcador de destino y copiar". *** No verificado: habria que mirar quien
  escribe `$48`. ***

---

## 5e. `$F558` es el hit-time, y `$6A` es el nivel de empuje

### `$F558` = hit-time del golpe que MATA

Esta es la respuesta al pendiente 7. El pipeline de `loc_01EDAC` es, en orden:

```asm
01edb4:  bsr.w    $1eee2      ; grab
01edb8:  bsr.w    $1f090      ; clash
01edbc:  bsr.w    $1f21e      ; hit vs hurt
01edc0:  bsr.b    $1ee1e      ; push
01edc2:  move.w   #$0, $a004.w ; <- limpiar los 5 contadores
...
01eda4:  jmp      $21960.l    ; luego SONIDO
```

Y despues el hit-time, que es `$F558` con su toggle de bit 1 hacia `$F55A`:
**160 frames de camara lenta, y solo cuando `$78` queda negativo.**

**Consecuencia que cierra el pendiente:** el hit-time por golpe es **`$69` = 16**
para todo, sin excepcion. Los valores de `$69` en todo el ROM son **0, 16, 28 y
255**, y no hay un quinto. **No existe un hit-time especial por movimiento.**

El "hit-time de las ultis" que se venía buscando **no esta, porque no existe**: la
premisa de que las especiales congelan mas viene de una guia, no del ROM. Lo unico
distinto es el **255**, que es la congelacion total de la ult de Itsuki, y eso no
es un hit-time sino otra cosa.

### `$6A` = nivel de empuje, NO es blockstun

Un byte con valor **1, 2 o 3**, escrito junto al empuje:

| Valor | Velocidad (`$10`) | Empuje (`$14`) | Direccion |
|---|---|---|---|
| 1 | `$2B000` = 2.69 | `$FFFC0000` = −4.0 | `0x1F33A` |
| 2 | `$40000` = 4.0 | `$FFFB0000` = −5.0 | `0x1F464` |
| 3 | `$56000` = 5.375 | `$FFFA0000` = −6.0 | `0x1F486` |

**El selector es `$64(a3) & #$03`**, y los bits 2-3 del mismo `$64` participan en
la mascara de defensa:

```asm
01f318:  move.b    $64(a3), d0
01f31c:  andi.b    #$0c, d0
01f320:  and.b     $63(a4), d0    ; mascara de defensa del DEFENSOR
01f324:  cmpi.b    #$0, d0
01f328:   beq.w    $1f414         ; 0 -> golpe limpio, con stun
01f32c:  move.b    $64(a3), d0
01f330:  andi.b    #$3, d0        ; <- NIVEL DE EMPUJE
```

**Un mismo `$64` con dos nibbles para dos cosas distintas:** los bits 0-1 eligen
cuanto empuje, los bits 2-3 la defensa. Por eso dos `andi.b` con mascaras
distintas sobre el mismo byte.

## 5f. **[MEDIDO 08-10] El gate de "¿estamos en pelea?"**

Se necesitaba un disparador para que un efecto (la lluvia de `LLUVIA DIAGONAL.LUA`)
saliera solo durante el combate y no en los menus. Se eligio **por medicion**, con
una sonda que imprime una linea cada vez que uno de los candidatos cambia, y el
ciclo `titulo -> seleccion -> combate -> KO -> menu`, dos peleas seguidas.

**De los cuatro candidatos, SOLO el HP cambia al entrar y al salir.** Y el gate
resultante es **"¿DOS de los cuatro slots tienen HP > 0?"** — el `>` y el **dos**
salieron de dos mediciones distintas, y **la segunda corrigio a la primera**.

| Frame | `hp` de los 4 slots | `$F550` | Que estaba pasando |
|---|---|---|---|
| 417 | `0/0/0/0` | `$00` | menu |
| **652** | **`223/223/0/0`** | `$00` | **entra la pelea 1** |
| 667-849 | `111/111`, el slot 2 baja con el dano | `$00` | pelea 1 |
| **851** | **`0/0/0/0`** | `$00` | **KO, se acabo** |
| 1844 | `0/0/0/0` | `$00` | menu |
| **1845** | **`223/0/0/223`** | `$00` | **entra la pelea 2** |
| 1864 | `223/0/0/223` | **`$01`** | `$F550` cambia aqui |
| 3209 | `223/0/0/-7` | `$01` | el enemigo cae por debajo de 0 |
| 3466 | `223/0/0/-1024` | `$01` | el enemigo, al centinela |
| 3997 | `0/0/0/-1024` | `$00` | |
| **3998** | **`0/0/0/0`** | `$00` | **fuera** |

Las transiciones de **entrada** son de **un frame**.

### La segunda medicion corrigio el gate: "> 0" no es "estamos peleando"

Con el gate de **"alguno con HP > 0"**, la segunda corrida dio:

| Frame | `hp` | Gate | |
|---|---|---|---|
| 3680 | `147/0/0/**-5**` | `enpelea=1` | **el enemigo ya esta muerto** |
| 4177 | `147/0/0/-1024` | `enpelea=1` | el enemigo, al centinela |
| 4667 | `0/0/0/-1024` | `enpelea=0` | recien aqui |

**987 frames (16 s) de lluvia con el combate ya terminado.** El unico que mantenia
la lluvia prendida era el ganador, con 147 de vida, y eso dura toda la pose de
victoria, el cartel de round y la transicion al menu.

**El gate correcto es "DOS VIVOS"**, o sea **la regla del juego**: un round termina
cuando **bajan de dos peleadores**.

| | |
|---|---|
| Pelea 1, `223/223` | 2 vivos → lluvia |
| Pelea 2, `223/0/0/223` | 2 vivos (los slots 1 y 4) → lluvia |
| Pelea 2, `147/0/0/-5` | **1 vivo → NO hay lluvia** |

**Y no es un parche para el 1v1.** Con cuatro peleadores el conteo va `4, 3, 2, 1` y
la lluvia se apaga en el `1`, que es justo cuando se acaba el round.

***Lo UNICO que queda abierto:*** un modo de **un solo peleador** (practice), donde
nunca hay dos vivos y la lluvia no sale nunca. No se entro a un modo asi.

### La regla final: "2+ vivos, o 1 vivo y NADIE muerto" — y el dato que falta

**Dos mediciones se contradijeron, y cada una mató una regla.**

| Regla | Que rompia |
|---|---|
| `> 0` | La pelea 2 dejo de llover **987 frames despues del KO**: el enemigo cayo a -5 en el 3680 y el gate se apago en el 4667, cuando el P1 (que seguia con 147) llego a 0 |
| `>= 2` slots con `HP > 0` | **Se apagaba con un peleador VIVO en el piso.** MEDIDO por el usuario: *"la CPU tenia 0 de vida, le lance un ataque especial, lo bloqueo, no murio, y las gotas se detuvieron"* |

**La segunda es la que importa como regla:** **`HP == 0` NO es estar muerto.** En este
juego se muere cuando la vida baja **de** 0, asi que un peleador en exactamente 0
sigue peleando. **`> 0` estaba equivocado desde el principio** y se acepto porque en
las dos peleas medidas no se dio el caso.

La regla que sale de todos los estados medidos:

> **Hay pelea si hay 2 o mas slots con `HP > 0`, o si hay UNO y NINGUN slot tiene `HP < 0`.**

| Estado | `hp` de los slots | vivos | muertos | Gate |
|---|---|---|---|---|
| Menú | `0/0/0/0` | 0 | 0 | **no** |
| Menú | `0/0/0/-1024` | 0 | 1 | **no** |
| Pelea 1, al entrar | `223/223/0/0` | 2 | 0 | **si** |
| Pelea 2, al entrar | `223/0/0/223` | 2 | 0 | **si** |
| **Peleador a 0 bloqueando** | `147/0/0/0` | 1 | 0 | **si** |
| Pelea 2, en el KO | `147/0/0/-5` | 1 | **1** | **no** |

Las dos filas de negrita son los dos casos que cada regla anterior rompia, y cada una
tiene su propia prueba en el banco.

**Y "2 o mas vivos" cubre el 1v4**, que con la regla de "bajan de dos" se apagaba al
primer KO: con cuatro peleadores el conteo va 4, 3, 2 mientras quedan vivos y no hay
ninguno muerto todavia.

#### ***LO QUE FALTA MEDIR, y es un numero de un frame***

La regla usa **`HP < 0` como "muerto"**, y eso **no esta verificado**. El unico escritor
negativo del ROM es `0x1A1A4: move.w #$fc00, $78(a5)` = **-1024**, el **centinela de
fin de pelea**, y no un "-1 al primer golpe".

**La pregunta que lo decide:** en el caso del bloqueo —peleador en HP 0 que bloquea un
especial y no muere— **¿que valor tiene el HP en el frame siguiente?**

| Si el HP queda… | Entonces |
|---|---|
| en `0`, o sube | La regla esta bien: el bloqueo no lo mata y no lo apaga |
| en un negativo chico (`-3`, `-7`) | **La regla esta mal y hay que cambiar la condicion de "muerto"** por algo que no sea el signo |

Es el mismo protocolo de siempre: una medicion, un numero, y el gate se decide con el.
**No se pone un margen de frames ni un `-1` de inventario porque seria inventar.**

### Sintoma del 08-10: "gotas congeladas" — el gate NO lo explica, y por eso hay un `pcall`

> ### El sintoma del overlay congelado puede ser un CALLBACK MUERTO
>
> Una excepcion dentro de `emu.registerafter` **se traga** en este emulador: no sale
> error, no sale aviso, y el callback muere a mitad. **Lo que se ve es el overlay con
> el ultimo frame dibujado, congelado** — o sea, exactamente "las gotas se quedan
> estaticas en pantalla".
>
> Con el gate apagado, en cambio, las gotas se matan Y no se dibujan: son dos cosas
> separadas, y las dos verificadas en el banco. **Si quedan visibles, el gate no es la
> explicacion** y hay que mirar si el callback llego a `draw_lluvia`.
>
> **Por eso ahora el cuerpo del frame va en `un_frame`, envuelto en un `pcall` que
> avisa en la consola CADA frame que falla**, con el numero de frame y el frame en que
> empezo. Antes no habia nada, y un fallo de una linea tardaba una sesion entera en
> aparecer. El mensaje se le limpian los bytes > 127 (la consola los muestra como dos
> caracteres y el error se vuelve ilegible justo cuando sirve).
>
> ***Verificado con tres pruebas que ROMPEN el frame a proposito*** (no el callback
> entero: si se reemplaza `frame_cb`, el `pcall` del script ni se ejecuta y la prueba
> mide otra cosa — se rompe `gui.drawline`, que se llama desde adentro):
>
> | | |
> |---|---|
> | un fallo dentro del frame **avisa** en la consola | **si** |
> | el mensaje es **ASCII** | **si** |
> | al frame siguiente el efecto **vuelve a andar** | **si** |
>
> ***OJO: esto es una herramienta de diagnostico, no una explicacion del sintoma que
> reporto el usuario.*** Si en su corrida el callback no se muere, la linea
> `[yuyu] ERROR` no aparece y el sintoma sigue sin explicar: en ese caso la pista
> seria que los boxes **tambien** estan congelados (o no lo estan), y eso separa
> "callback muerto" de "gate mal".

### El ciclo pedido, con los valores exactos: `-1024` -> `0` -> `223`

Lo que se pide, textual: **con HP en `-1024` o en `0` no se dibuja ni una gota; con
HP en `223` vuelve.** Los tres valores son los del ciclo del menu, MEDIDO:

| HP | Donde | Lluvia |
|---|---|---|
| **`-1024`** (`$FC00`) | centinela, el slot lo conserva en el menu (frame 3997) | **no** |
| **`0`** | los cuatro slots vacios en el menu (frame 3998) | **no** |
| **`223`** | inicio de pelea (frames 652 y 1845) | **si** |

Verificado como DIBUJADO en `test_hitbox_hud.lua` (179 pruebas), y no solo como
valor del gate: `max_lineas(20) == 0` en los tres primeros casos, `> 0` en el
cuarto, y el ciclo repetido dos veces para que no sea un caso único.

**`-1024` y `0` dan lo mismo por el signo, no por el numero.** El gate usa `> 0`, y
por eso los dos son "no hay pelea". Con `!= 0` el `-1024` contaria como pelea y el
menu lloviendo: **8 fallos** en el banco.

**Y OJO: `223` NO es el disparador.** La regla es `> 0`, y esa diferencia importa:

> Si el gate preguntara **"¿HP == 223?"**, la lluvia **se apagaria en el primer
> golpe**, porque el HP baja a 222 de inmediato y no vuelve a 223 hasta la ronda
> siguiente.

MEDIDO en la pelea 2, un solo round: `223 -> 200 -> 147 -> 5 -> -5 -> -1024`. El
valor `223` es el **inicio** de la pelea, no su estado. La mutacion a `== 223` da
**4 fallos** en el banco.

### Como se medicio, y por que la sonda ya no esta

Todo lo de arriba salio de una **sonda** que se cargo en `LLUVIA DIAGONAL.LUA` e
imprimia una linea cada vez que un candidato cambiaba, durante el ciclo
`titulo -> seleccion -> combate -> KO -> menu`. **Esa sonda se BORRO del script
cuando el diagnostico cerro**: era andamiaje de medicion, no del efecto, asi que no
tiene sentido dejarla corriendo.

**Lo que se conserva es el DATO**, en este documento y en el comentario del gate.
Y en el banco quedan las pruebas de **comportamiento**, que no dependen de que
exista ninguna sonda:

| | |
|---|---|
| Sin pelea, ningun layer vivo | `max_lineas(20) == 0` |
| En pelea | `max_lineas(20) > 0` y `vivas_por_capa() > 0` |
| Ciclo `-1024 -> 0 -> 223` | 0 lineas, 0 lineas, 43 lineas, y otra vez |

Lo que se borro con ella: 18 pruebas que contaban lineas `[SONDA]` de una sonda que
ya no existe. **Y tambien las declaraciones adelantadas** de `LLUVIA_DEF` y `lluvia`,
que habia que mantener **sin `local`** solo porque la sonda las leia mil lineas antes
de que existieran. Esa es la trampa de "un local declarado mas abajo" pagandose un
costo permanente en el codigo de produccion por un diagnostico temporal.

### El sintoma "congelada y visible" — CERRADO por prueba, no por argumento

> El usuario reporto: *"la lluvia se detiene (queda estatica) cuando P1 o P2 muere"* y
> *"esa lluvia que quedo estatica sigue viendose luego en el menu y solo se corrige
> cuando empieza un nuevo combate"*.

**Eso NO puede ser esta lluvia, y ahora es una PRUEBA y no un argumento.**

| | |
|---|---|
| Caminos de dibujado de la lluvia en TODO el script | **UNO**: los dos `gui.drawline` de `draw_lluvia` (gotas y salpicaduras), los dos detrás del `and enp` de la capa |
| Con el gate apagado | `update_lluvia` mata las 43 gotas **y** `draw_lluvia` no entra al bucle, **en el MISMO frame** |

Dos pruebas del banco, y apuntan al **frame exacto** en que el gate se apaga, no a una
ventana de 20:

| | |
|---|---|
| `en el PRIMER frame con el gate apagado ya se dibujan 0 lineas de lluvia` | **0** |
| `y el pool ya esta VACIO en ese mismo frame` | **0** |

**O sea que no existe un estado "dibujada y quieta" de esta lluvia.** Si queda
congelada en pantalla, no es del script.

**Lo que si es del juego:** el stage tiene su propia lluvia, y en las pantallas de
menu el fondo es una imagen estatica donde la lluvia es parte del arte (o queda
congelada). Encima se ve el overlay, que no la toca. La foto del usuario muestra
lineas verticales palidas sobre TODA la imagen, incluido el marco decorativo de
arriba, y el menu marca **59,73 fps**: no hay consola inundada, asi que la teoria
del framerate caido esta muerta.

**Lo unico que faltaba era la prueba de las capas.** Con el gate ya corregido (2+ vivos,
o 1 vivo y nadie muerto), el efecto aparece y desaparece en el frame del KO, y eso
tambien esta verificado: `vivas = 43` entrando, `vivas = 0` saliendo.

***Sigue pendiente un dato, y es el que falta para cerrar la regla:*** **¿que valor
tiene el HP de un peleador que esta en 0 y bloquea un especial, en el frame justo
despues?** De eso depende si "HP < 0" sirve como "muerto".

### [MEDIDO 08-10] La retencion: la superficie de `gui.*` de FBNeo no se limpia

**LA CORRECCION PRIMERO, y es mia.** Se escribio que las gotas congeladas en el menu
eran "la lluvia del stage". **Es FALSO, y el usuario lo dijo: el juego no tiene
ningun escenario con lluvia.** Lo de la lluvia del stage fue una supresentacion mia
escrita como si fuera un dato, y no lo era. Lo que hay en el juego en los menus es
la decoracion de los menus, no lluvia.

**MEDIDO, con el gate de "2+ vivos, o 1 vivo y nadie muerto":**

| Tramo | `lluvia=` |
|---|---|
| Menu antes de la pelea | **0**, en todas las lineas |
| Pelea | `27, 29, 31, 33, 32, 30, 33` |
| **KO** (todavia en el stage) | **0** — baja **exactamente** en el KO |
| Menu despues de la pelea | **0**, en todas las lineas |

Sin `[yuyu] ERROR` y sin la barra roja: **el callback esta vivo**. Y el gate nuevo
funciona: la lluvia baja a 0 en el frame del KO, no 987 frames despues.

**Y LA PRUEBA QUE LO CIERRA** (la hizo el usuario): **cerrar y reabrir la ventana de
Lua en el MENU borra las gotas**, y el ciclo vuelve a funcionar de menu a pelea. Con
eso:

| Sintoma | Explicacion |
|---|---|
| Las gotas quedan congeladas en el menu | La **superficie de `gui.*` de FBNeo no se limpia cuando el script no dibuja nada**, y queda el ultimo frame compuesto |
| Solo se corrige al empezar un combate nuevo | Ahi el script vuelve a emitir llamadas de dibujado, y la superficie se vuelve a componer |
| Cerrar y reabrir el `.lua` lo arregla | Superficie nueva |

**Ninguna de las tres es del logico de dibujado de este script:** con `lluvia = 0` no
se dibuja ni una gota, y el banco lo comprueba en el PRIMER frame del apagado.

#### El arreglo, y lo que NO se

**Si este frame no se dibujo ninguna gota, se emite una llamada de dibujado con alfa
0.** Es invisible (el alfa va en el byte bajo, y `00` es transparente) pero **es una
llamada**, y fuerza a que la superficie se vuelva a componer vacia:

```lua
if gotas_dibujadas == 0 then
  gui.drawline(0, 0, 0, 0, color(0x00, 0x00, 0x00, 0x00))
end
```

***LO QUE NO SE, y no se decide leyendo:*** si FBNeo limpia la superficie **al
presenciar** el overlay o **antes de cada llamada** de dibujado.

| Si es al presenciar | El pixel invisible **arregla** el sintoma |
|---|---|
| Si es antes de cada llamada | El pixel **no borra nada** (mezcla con alfa 0) y el sintoma sigue |

**La corrida del usuario lo decide.** Por eso el pixel va con este comentario al
lado y no escondido, y por eso el banco comprueba las DOS mitades: `gotas(1) == 0`
(las lineas de lluvia, medidas por el mock de `gui`) **y** "el script igual emite
alguna llamada" — porque **`0` lineas y `0` llamadas no son lo mismo**, y esa
distincion es justamente la que faltaba para poder reproducir la retencion.

***Y el test de "apagar las tres capas" NO servia para esto:*** con `lluvia = 0` el
script no dibuja, asi que apagarlas tampoco borra nada. Un test de "apagar" solo vale
cuando lo que se ve esta **siendo dibujado ahora**; para "algo quedo pegado" hay que
descartar antes que algo se dibuje.

### **[MEDIDO 08-10] RESUELTO: FBNeo limpia la superficie AL PRESENCIAR**

Corrida del usuario con el pixel invisible: **"las gotas ahora desaparecen antes de
que comience la transicion al menu al matar al enemigo"**. O sea:

| | |
|---|---|
| Al matar al enemigo las gotas **desaparecen**, y desaparecen **antes** de que arranque la transicion al menu | El pixel invisible **SI** fuerza la recomposicion, y FBNeo limpia la superficie **al presenciar** el overlay |
| El sintoma esta cerrado | No hace falta ninguna otra tecnica, y **no** hay que dibujar el fondo a mano |

**Con esto quedan CERRADAS las dos preguntas de la lluvia:**

| | |
|---|---|
| La lluvia sale y entra con la pelea | **SI**, con el gate de "2+ vivos, o 1 vivo y nadie muerto" |
| La lluvia se oculta del KO hasta la pelea siguiente | **SI**, y en el frame del KO |

**Y el atraso de la pelea a menu que se vio al principio quedo resuelto por el camino
corto**: no hacia falta esperar a que el HP del ganador llegara a 0. Con la regla
actual, el segundo peleador cae a negativo y el gate se apaga en ese frame.

**Lo que sigue ABIERTO, y es de otra cosa:** si **`HP < 0`** sirve como "muerto" (ver
arriba, el caso del bloqueo). Eso no tiene nada que ver con el dibujado: es la
semantica del gate, y se resuelve con **un solo numero** del HP de un peleador que
esta en 0 y bloquea un especial.

### El bug del 08-10 que encontro el usuario: DOS `emu.registerafter`

Al meter el `pcall` del callback con la herramienta de edicion se quedaron **DOS**
`emu.registerafter` completos en el script: el nuevo, con el `pcall` y el aviso, y el
viejo entero debajo (2236 lineas). Los dos registraban la misma logica por frame.

**No lo detecto ninguna prueba:** `luajit -bl` limpio y **171 pruebas en verde**.
Las dos instalaciones dan el mismo comportamiento visible, asi que el banco no lo ve.

**La unica forma de verlo es contar:**

```powershell
Select-String -Path "tools\fightcade\LLUVIA DIAGONAL.LUA" -Pattern "emu\.registerafter"
# tiene que dar 1
```

Lo mismo con `un_frame = function`. **En un archivo que grew con parches, el numero
de `registerafter` / `registerexec` / `registerafter` tiene que ser una asercion, no
una costumbre.**

### El sintoma "congelada y visible": el CONTADOR DE GOTAS DIBUJADAS

El sintoma se discutio entre "es del script" y "es del stage" **a ojo**, y a ojo no se
gana: las lineas del stage y las del overlay se parecen, y una foto no las separa.

**La salida es un numero, no una opinion.** `gotas_dibujadas` cuenta las gotas
**realmente dibujadas** en el frame (despues de los dos recortes de muerte y de HUD,
y contando gotas y no lineas, porque H.Rain dibuja 2 lineas por gota). Va en el
latido que ya se imprimia cada 60 frames, asi que no agrega ni una linea por frame.

```
[yuyu] dib=0 src=exec pj=... lluvia=33 | ...     <- en pelea
[yuyu] dib=0 src=stale pj=... lluvia=0  | ...    <- en menu
```

**La medicion del banco con los valores reales** (168 pruebas): `lluvia` da
`22, 28, 29, 30, 31, 32, 33` en pelea y **`0`** en menu. El 33 es el tope: 10 de
H.Rain + 10 de B.Rain (la mitad parpadea) + 13 de C.Rain.

**Y ACA ESTA LA TRAMPA QUE CASO ESTE CONTADOR, la novena vez que aparece y la mas
barata.** La variable quedo declarada **dos veces**:

```
linea ~483 : local gotas_dibujadas = 0     <- la que lee el latido
linea 1871 : local gotas_dibujadas = 0     <- SEGUNDA, dentro del ambito de draw_lluvia
linea 1956 : gotas_dibujadas = gotas_dibujadas + 1   <- escribe la de 1871
```

O sea: el contador se **escribia** en un local y el latido **leia** otro. El numero
daba **0 siempre**, sin error, con `luajit -bl` limpio y **168 pruebas en verde**.

**Es la trampa al reves** (no "declarado mas abajo" sino "declarado dos veces"), y
salio pegada justo en el contador que existe para que el diagnostico no mienta. Por
eso el banco ahora exige las **dos** mitades: `gotas(1) == 0` (las lineas dibujadas,
medidas por el mock de `gui`) **y** `YUYU_TEST.gotas_dibujadas() == 0` (el contador
del script). Un `0` solo no distingue "no hay lluvia" de "el contador esta roto".

### Que corre y que NO corre en los menus [MEDIDO 08-10]

Del volcado de la sonda, en los tramos de menu (frames 1289-1844 y 4668-4871 de la
segunda corrida):

| | En pelea | En menu |
|---|---|---|
| `$FFA014` — **base X del stage** | **se mueve cada frame** | **tambien se mueve**: `$03B9`, `$036C`, `$0360`, `$03C1` |
| `$8C` — tabla de moves | 2 slots | **oscila**: 0, 1, 0, **2**, 0, 1 |
| `$01EDAC` — dispatcher de colisiones | corre | **no corre**: contadores en 0 y `src=stale` |
| `$F550` bit 7 | 0 en la pelea 1, 1 en la pelea 2 | 0 |

**O sea que el menu NO congela el juego:** el sistema de stage y de camara sigue
vivo (`$A014` avanzando) y las maquinas de estados del jugador siguen escribiendo
`$8C`. Lo que **no** corre es el pipeline de colisiones.

### ***¿La lluvia del stage ya esta "calculada" en el menu, en capas inferiores?***

**La pregunta se parte en dos, y una parte es FALSA y la otra no esta verificada.**

| Parte | Veredicto |
|---|---|
| "ya esta calculada" | **Parcialmente medido: el stage NO esta congelado.** `$A014` avanza en el menu y `$8C` se sigue escribiendo. Lo que **no** sabemos es si las tiles del stage ya estan en VRAM |
| "solo que no se ve porque esta en capas inferiores" | **FALSA tal como esta escrita.** Una capa inferior se dibuja **detras**: si la lluvia estuviera ahi, no se veria. **Y se ve**: la foto muestra lineas palidas en los huecos entre los paneles de la UI. O sea que no esta oculta, esta **dibujada** y la UI la tapa encima en parte |

***Lo que no se puede responder desde aca:*** el mecanismo exacto (capa del VDP
desactivada con `h40`/`v40` en cero, o capa dibujada y tapada por la UI) requiere
**leer los registros del VDP**, y eso **no se puede hacer con un script pasivo**:

- En Genesis los registros del VDP se leen escribiendo el indice en `$C00004` y
  leyendo el valor de `$C00000`. Eso es el **bus del Z80**, y requiere una
  **escritura** en la memoria del juego → **rompe la regla 5**.
- El unico script del repo que lo hacia (`herramientas/desensambladolua/vdpinfo.lua`) es de
  **BizHawk** (`memory.write_u16_be`, `BUS = "M68K BUS"`), y ademas tiene una ruta
  quemada a `C:\Users\leand\...`. docs/08-DIARIO/MEMORIA.md dice que los `.lua` de BizHawk **no se
  portan**.

Queda como pendiente, y es de los que **no se cierran con Lua pasiva**.

| Candidato | Por que NO sirve |
|---|---|
| **`$F550` bit 7** | Estuvo en `$00` **toda** la pelea 1 y en `$01` la pelea 2. No acompana ni la entrada ni la salida. Es el flag de "simulacion suspendida": gatea `loc_01EDAC` (`01edac: btst.b #$7, $f550.w`) y las dos maquinas de estados (`0x12AE6`, `0x13688`) |
| **`$F558` / `$F55A`** | Solo prendieron al **final** de la pelea 2, cuando el enemigo ya estaba muerto, y **nunca** en la pelea 1. `$F558` es el timer de la muerte (160 = `$A0`, unico escritor `0x1FA82`) y cuenta con wrap. Ver §5e |
| **`$8C != 0`** (tabla de moves) | En el **menu** oscila: frames 1344 -> 1, 1442 -> 0, 1456 -> **2**, 1518 -> 0, 1588 -> 1, con los cuatro slots en HP 0. O sea que "tiene tabla" prueba "**hubo** pelea", no "estamos peleando": el puntero del ultimo round se queda |

### Por que `> 0` y no `!= 0`

El HP va a **`-1024` (`$FC00`)** al terminar y el slot **lo conserva en el menu**:
medido, frame 3997, `hp=0/0/0/-1024`. Con `!= 0` el menu contaria como pelea.

Y hay frames de pelea con HP **negativo**: en la pelea 2 el enemigo paso por
**-7, -16, -22** antes de llegar a -1024. Con `> 0` esos frames no cuentan por ese
slot.

### ***Lo que la medicion NO cubre***

Las dos peleas las gano el jugador, y en las dos el P1 seguia con vida (111 y 223)
cuando el otro caia, asi que **el gate no se apago antes de tiempo ni una vez**. En
un **doble KO**, con los dos slots en negativo, el gate se apagaria durante la
animacion del final. No se midio. Y no se le pone un margen de frames porque ese
seria un numero inventado.

Ademas el gate prueba "**hay ALGO VIVO**", que en las dos peleas medidas coincide
con "estamos peleando" porque el stage solo se dibuja ahi. En la pantalla de
victoria el gate cae cuando los peleadores mueren, no cuando aparece el cartel. Para
lluvia da igual.

### La correccion que hubo que hacer antes de medir

Se escribio que el HP **no podia** servir de gate porque `0x12AE6` y `0x13688` lo
escriben cada frame con `#$FF` y no lo borran al salir. **La segunda mitad era
falsa**: lo que se comprobo es que el HP **vuelve a 0** al terminar. El `$FF` se ve
un frame y despues el juego lo baja a 223 (la barra `$7A` lo persigue,
`0x157A8`) y de ahi lo baja el dano crudo (`sub.w $65, $78(a4)`, `0x1F424`).

La razon de fondo era una confusion de alcance: **"se escribe cada frame" no dice
nada de un gate**, porque el gate tambien se lee cada frame. Lo unico que importa es
si el **valor** distingue estar dentro de la pelea de estar fuera. Resulta que si.

### Donde esta implementado y como se protege

`en_pelea()` en `LLUVIA DIAGONAL.LUA`. Se lee **una vez por frame** en el
`registerafter` y se pasa a `update_lluvia()` y a `draw_lluvia()`: leerlo dos veces
en el mismo frame son dos respuestas posibles.

La sonda imprime **`vivos=`**, cuantos slots tienen HP > 0. Va en el texto
**comparado** a proposito, y es el unico campo de la sonda que cambia poco (el dano
que no mata no lo cambia), asi que cada linea es un cruce del cero: justo lo que
decide el gate.

**Gatea las dos, no solo el dibujado.** Fuera de pelea se matan todas las gotas y se
pone `lluvia_sembrada[t] = false`, igual que cuando se apaga una capa desde el menu.
Si solo se dejara de dibujar, las gotas quedarian colgadas en el aire y al arrancar
la pelea siguiente aparecerian todas de golpe en el punto donde las congelo. Las
salpicaduras mueren tambien. Asi la lluvia **queda oculta** desde el KO hasta la
proxima pelea, y no "se frena".

Verificado con once mutaciones del banco (`test_hitbox_hud.lua`, seccion 9y):

| Mutacion | Resultado |
|---|---|
| `vivos >= 2` -> `vivos >= 1` | **3 fallos** |
| `muertos == 0` -> `muertos == 1` | **4 fallos** |
| **fuera la regla de "1 vivo y nadie muerto"** | **1 fallo** — el del bloqueo |
| un `HP < 0` no cuenta como muerto | **3 fallos** |
| `h > 0` -> `h >= 0` | **9 fallos** |
| gate solo en el dibujado, no en la simulacion | **1 fallo** (el pool queda vivo) |
| gate solo en la simulacion, no en el dibujado | **0 fallos**: mutacion EQUIVALENTE |

La tercera es la importante: **quitar la regla del bloqueo es un fallo y no se
pierde entre las demas**, porque la prueba de ese caso esta escrita con las palabras
del usuario al lado.

### Sintoma del 08-10: "gotas congeladas y visibles en el menu" — **CERRADO: no es esta lluvia**

**Lo que el usuario ve:** durante las etapas del menu la lluvia queda congelada pero
las gotas se siguen viendo, y al terminar la pelea las gotas que estaban cayendo se
quedan congeladas en el aire.

**Lo que midio la sonda** (corrida completa, dos peleas, ciclo titulo -> combate ->
KO -> menu):

| | |
|---|---|
| Frames de menu con `enpelea=0` | **11** |
| De esos, con `vivas=0` | **11** |
| De esos, con `vivas>0` | **0** |

**Y las transiciones son de UN frame**, con el gate y el pool. Eso tambien explica por que las
gotas del final no quedan "a medio caer": el pool pasa de 42 a 0 en el mismo frame en
que el gate se apaga.

```
frame  652  hp=223/223/0/0    enpelea=1  vivas=43     <- ENTRA pelea 1
frame  833  hp=0/0/0/0        enpelea=0  vivas=0      <- KO
frame 1529  hp=223/0/0/223    enpelea=1  vivas=43     <- ENTRA pelea 2
frame 4177  hp=147/0/0/-1024  enpelea=1  vivas=42     <- el enemigo al centinela
frame 4667  hp=0/0/0/-1024    enpelea=0  vivas=0      <- fuera
```

**Por que el dato CIERRA el sintoma y no solo lo hace probable.** `vivas` cuenta
`lluvia[t][i].viva`, y `draw_lluvia` **solo dibuja cuando `p.viva`**. Con las 43
gotas en `viva = false` el script no puede dibujar **ni una** linea de lluvia: no es
una cuestion de que "parezca" apagada, es que no hay nada que dibujar.

**O sea que lo que se ve congelado en los menus es la LLUVIA DEL PROPIO JUEGO**, que
es un layer de fondo del stage y queda congelada cuando la pantalla cambia a menu.
Our overlay esta encima y no la toca.

***La confirmacion que falta, y es de un minuto:*** con la sonda apagada, **MODE ->
apagar H.Rain, B.Rain y C.Rain**, y ver si las gotas congeladas siguen en pantalla.
Si siguen, son del juego.

### Un hallazgo lateral de esa misma corrida: `$F558` se rearma en CADA golpe a un peleador ya muerto

**No es "una vez al morir".** MEDIDO 08-10, con el enemigo en HP negativo (`-5`,
`-13`, `-18`, `-22`, `-27`, `-36`, `-44`, `-51`, `-58`), cada golpe suyo **vuelvo a
poner `$F558` en 160** y vuelve a contar: **9 veces en 320 frames**, una cada 40
frames, y siempre en el MISMO frame en que el HP cambia.

| Frame | HP del enemigo | `$F558` |
|---|---|---|
| 3680 | `-5` | 159 (recien puesto a 160) |
| 3720 | `-13` | 159 |
| 3760 | `-18` | 159 |
| ... | ... | ... |
| 4000 | `-58` | 159 |

O sea que el disparador es **"le pegaron a alguien con HP negativo"**, no "el peleador
murio". El escritor sigue siendo el unico de todo el ROM (`0x1FA82: move.w #$a0,
$f558.w` = 160), pero **corre las veces que haga falta**. ***Lo que NO se confirmo es
que sea ese mismo `0x1FA82` el que reaplica: lo que se midio es que el valor vuelve
a 160 en el frame exacto del golpe.***

**Y esto refuerza por que el gate tiene que ser `> 0` y no `!= 0`**: un slot muerto
sigue recibiendo golpes y sigue con HP **negativo y variable** (-5, -13, -58...), no
con un centinela fijo. Un gate de "hay dano, luego hay pelea" fallaria.

### `$F558` como reloj del final de la pelea: el gate de HP dejo de cortar la lluvia

**[MEDIDO 08-10] + [ESCRITO en `LLUVIA DIAGONAL.LUA`].** Del dato anterior sale una
cosa que no se habia visto: **`$F558` no es un flag, es la cuenta regresiva**, y por
eso alcanza para decidir el final de una animacion sin contar un solo frame.

| | |
|---|---|
| Valor al morir | **159** (el escritor pone 160 y el frame siguiente ya ve 159) |
| Cuentan hacia abajo | 158, 157, ... 120 |
| En un refresco | **salta de 120 a 159**: nunca pasa por 0 mientras el slow-mo sigue |
| Cuando llega a 0 | el slow-mo se acabo |
| En toda la pelea 1 y en los menus | **0** |

O sea que **`$F558 > 0` es un flag limpio de "hay camara lenta de muerte"**, y su
valor son los frames que faltan. Y como su unico escritor en todo el ROM es
`0x1FA82` y esta en el camino de la muerte, **`$F558 != 0` SIEMPRE es una muerte**: no
existe el caso raro de "slow-mo sin muerte" que habria pedido una rama aparte.

**La duracion total del slow-mo, con los 9 refrescos: del frame 3680 al 4159 = 479
frames, no 160.** Un contador propio del script no podia dar ese numero: solo
leyendo `$F558` sale, y sale solo.

**Que se escribio con esto, en `LLUVIA DIAGONAL.LUA`:** cuatro fases, y el gate de HP
pasa a **encender** la lluvia nada mas:

| Fase | Cuando | Que hace |
|---|---|---|
| `NORMAL` | hay pelea | velocidad normal |
| `SLOW` | `$F558 > 0` | **velocidad a la mitad** (`MULT_SLOWMO = 0.5`), y se sincroniza sola |
| `COLA` | `COLA_FRAMES` (= 120) frames **despues del ULTIMO** frame de slow-mo | velocidad normal |
| `OFF` | despues | no se dibuja |

Las dos decisiones que llevan el numero:

| | |
|---|---|
| **El gate ya no apaga** | Un INFERIDO ("¿queda alguien en pie?") puede encender una animacion pero no la puede cortar: por ahi salio el bug de los **987 frames** de lluvia despues del KO. **El que apaga es `$F558`, que cuenta frames hacia atras.** |
| **`$F558 > 0` gana sobre el gate** | En el frame del KO caen las dos senales a la vez (HP negativo **y** `$F558` = 159). Con ese orden no hay ni un frame entre "llueve normal" y "llueve a la mitad", y el pool **no se re-siembra** en el KO |
| **El gate prendido gana sobre la COLA** | Una pelea nueva no espera a que se acabe una cola de la pelea anterior, y no hay un frame sin lluvia en medio de un combate |
| **Un refresco rearma la cola** | Salir de `SLOW` rearma la `COLA` desde cero, asi que la cola espera **al ultimo** slow-mo y no al KO original |

**Lo que NO se puede cubrir con esto, y queda como supuesto declarado:** el caso de
**1v1 con el rival bloqueando en HP 0**. El gate de HP sigue teniendo el hueco ya
anotado mas arriba (dos peleadores en exactamente 0 dan `0 vivos, 0 muertos` -> no hay
pelea), y con `$F558` ese hueco se nota igual: la lluvia se apaga con los dos en pie.
***No medido: no se entro a un 2v2, y no hay ningun byte que separe "peleador sin
vida" de "slot vacio".*** El trabajo se hizo bajo el supuesto de 1v1, declarado en el
`.lua`.

***Y el numero de 120 es una SELECCION A OJO, no una medicion:*** viene pedido, y lo que
falta es mirarlo en el emulador. La continuacion acordada es 300 frames con deteccion
de START para cortarlo.

