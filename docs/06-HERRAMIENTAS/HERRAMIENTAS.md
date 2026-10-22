# Las herramientas

---
## Herramientas

| Fichero | Que hace |
|---|---|
| `DANO-HITPAUSE-KO.md` | **El hilo del golpe, con lo refutado a la vista (07-10-2026).** Mapa frame a frame del B y del backflip, por que `$69` no es hitpause, por que la oscilacion no es desplazamiento, knockdown vs backflip, y **por que el mismo golpe no da siempre lo mismo** (`$65`/`$66`/`$64` son **los tres por frame activo**). Incluye **los 5 errores que cometimos** y los **pendientes priorizados por coherencia**, de mas facil de comprobar a menos probable. **Se lee ADEMAS de `VERIFICACION.md`, no en vez de:** la fuente de verdad sigue siendo el otro, pero un doc que solo guarda lo que quedo bien no sirve para no repetir los pasos en falso |
| `herramientas/lua/sonda_probe.lua` | Sonda: vuelca struct, camara y cajas en pantalla; imprime cambios en consola |
| `herramientas/lua/LLUVIA RECTA.LUA` | Hitbox display de las 5 listas (borde de 2 px) + rango de agarre + 3 capas de lluvia. Menu de 9 toggles: 4 cajas, filtro P2, 3 capas y "G.LINE" (las guias). **Las cajas APAGADAS de fabrica; las 3 capas de lluvia ENCENDIDAS.** Colores con `color()`, nunca en hexadecimal (ver la seccion de color). Los recuadros del HUD tapan la lluvia de las 3 capas (ver la seccion de zonas del HUD). LAS TRES capas van rectas y mezclan alturas; B.Rain tiene ademas PARPADEO (ver la seccion del largo por gota). **El slot del P2 se DETECTA (`detectar_slots()`), no se supone**, pero eso es inerte para el dibujo: ver la seccion de slots. Verificar con `test_hitbox_hud.lua` (141 pruebas) |
| `herramientas/lua/LLUVIA DIAGONAL.LUA` | **COPIA DE TRABAJO de `LLUVIA RECTA.LUA`, y ya NO es identica: tiene el GATE DE PELEA, el FINAL DE PELEA en cuatro fases, y OTRA LLUVIA.** La lluvia sale **solo durante el combate**. El gate es `en_pelea()` = **"2+ slots con HP > 0, o 1 vivo y NINGUN slot con HP < 0"**, elegido **por medicion** el 08-10 (cada medicion mato una regla anterior): los otros tres candidatos quedaron descartados con el dato delante, en `VERIFICACION.md` §5f. **El gate SOLO enciende; el que apaga es `$F558`**, el timer del slow-mo de MUERTE (`0x1FA82: move.w #$a0`, su unico escritor en todo el ROM), y las cuatro fases son **NORMAL -> SLOW -> COLA -> OFF**: en SLOW la lluvia cae a **la mitad de velocidad** y se sincroniza sola porque `$F558` es la cuenta regresiva (MEDIDO: 159->0, con refrescos que la salvan de 120 a 159, y **479 frames de slow-mo en total, no 160**), en COLA son **120 frames** de lluvia normal **despues del ULTIMO** frame de slow-mo, y despues ya no se dibuja. El latido imprime **`fase=` y `v=`** para poder verlo en la consola. **Supuesto declarado: 1v1.** **La lluvia es la otra: stock 14/22/16, `dur` 39/66/27, y los altos de B.Rain (6 y 9 px) y C.Rain (3, 4 y 6 px) cambiados a ojo por el usuario; el bloque `TECHOS_DE_LLUVIA` explica hasta donde se puede subir cada capa y por que C.Rain ya no tiene aire.** Sigue siendo la version recta en cuanto al `dx` (las tres capas con `dx = 0`): **la sensacion de caida diagonal todavia NO esta escrita**. Verificar con `$env:SCRIPT = "LLUVIA DIAGONAL.LUA"; luajit test_hitbox_hud.lua` (**207 pruebas**). El banco tiene las **expectativas de lluvia por script** en la tabla global `ESP`, porque la RECTA esta congelada con la suya: con un solo juego de numeros solo se probaria una de las dos |
| `herramientas/lua/hall_of_fame.lua` | Ventana HALL OF FAME. START 2s abrir, 1 vez cerrar, 3s confeti (que sigue con el menu cerrado). Verificar con `test_hall_of_fame.lua` (20 pruebas) |
| `herramientas/lua/ITSUKI SET MOVE.LUA` | **Diagnostico del STOP TIME de Itsuki** (la unica habilidad que pone `$69 = 255`) **y rastreador de tecnicas.** Verificar con `test_stoptime.lua` (184 pruebas). **El rastreador anuncia una tecnica SOLO cuando se GASTA maná**: la pulsada es una sospecha y el gasto de maná es la confirmacion. Se lee el maná de `$B8` (**no de `$BC`**, que es la barra animada), y **solo se mira que BAJE**: el maná sube por combo y por regeneracion, y ninguno de los dos es una tecnica. Se anuncia el **id de `$5F`**, la **direccion de su registro** (`$50 + word[id] + frame*8`), sus 8 bytes, la **tabla B** (`$8C + byte(reg+1)*4`) y la del golpe (`tabB + word(tabB+2)`). **START** arranca un lote nuevo y **MODE** vuelca la tabla **con la zona de destino de cada variante**. Carga el **CONTEXTO** (`$50` y `$8C`) en el primer anuncio, porque sin el numero no se sabe de que tabla es el registro. **La autoprueba `byte(+0) == $5A vivo` (0x1EB5A) GATEA la impresion de los datos**: si no coinciden, el ROM no esta expuesto bien a Lua, el script lo dice y **no imprime** `dano/stun/empuje` (que serian ruido), pero **publica igual la DIRECCION**, que es lo que hace falta para leerla a mano del `.asm`. Mapea la firma triple de `0x1C032`-`0x1C088`: `$69 = 255` en los enemigos, `$59 == 2` + `$5B == 0` + `$60 != 1` en el lanzador, y **`$6E` del congelado distinto al del lanzador`. **Se AUTOCOMPRUEBA** en las dos direcciones (un slot de otro grupo sin congelar, y uno del mismo grupo congelado). **Y saca un CARTEL GIGANTE que dice "OK"** durante 75 frames. **NO USA exec hook, y es a proposito:** `$69` es un timer que sobrevive frames, asi que `registerafter` alcanza, y asi esquiva el `memory.registerexec` que no dispara en esta build. **El teletransporte se mide sobre `$40`/`$44` (los enteros) y el delta usa el 16.16 COMPLETO**, porque `$42`/`$46` son la fraccion y un cambio ahi es subpixel: tomarlos por un salto daba 5 falsos de 7. El **salto se correlaciona con la ultima tecnica confirmada** y dice cuantos frames pasaron, porque las variantes que comparten id y registro (las tres de Teleport) solo se separan por donde caen. **Todo el latido, incluidas las dos lineas de `max salto` y `maná`, va dentro del `if g_frame % LATIDO`**: fuera de ahi salian 2 lineas por frame. Pasivo: ni una escritura. **El nombre lleva espacios a proposito**; el `dofile` del test lo cita con `"herramientas/lua/ITSUKI SET MOVE.LUA"` |
| `herramientas/lua/diagnostico_slots.lua` | **Diagnostico de solo lectura** para dos huecos: que valor de `$58` pone cada habilidad, y que slot esta poblado. Vuelca los 4 slots (`$FF8400`/`$FF8800`/`$FF8C00`/`$FF9000`) con HP, stun, mana, move y `$9E`, y **detecta P2 por HP en vez de suponerlo**. Despues imprime solo los CAMBIOS de `$58`, `$A030`, los 4 canales y `$F809`, con numero de frame. Boton de P1 = marcador `[*]`. Sin escrituras |
| `herramientas/lua/diagnostico_knockdown.lua` | **NO FUNCIONA EN ESTA BUILD — no reintentar sin resolver antes POR QUE.** El exec hook no entra: imprime el arranque y despues `AVISO: el hook de $1EDAC no ha corrido (invocaciones=0)`. Se resolvieron el PC equivocado (`$01EDC2`, detras de la guardia) y el re-armado por frame (FBNeo borra los exec en cada reset) y **no alcanzo**; la pista que queda es que `memory.registerexec` quizas no exista o no dispare en esta build. **Lo que si quedo bien y sirve de modelo:** el **latido** (convierte "no lee nada" en un sintoma con numero), el `pcall` con flag propio (para que una excepcion no se calle), el conteo de hurtboxes **por owner**, y la firma `$84 == (abs 7E + 4) * 16` que **confirma `$1F4E2` sin interpretar nada**. La medicion del backflip se hace **A MANO con el HUD de cajas**. Originally: diagnostico de solo lectura para cerrar el backflip vs knockdown. Mira `$7E` (presupuesto de stun), `$84` (el campo sobrecargado), `$5F` (estado) y `$69` (hitpause) en los 4 slots, e imprime solo los CAMBIOS con numero de frame. **Es autoverificable: CONFIRMA `$1F4E2` cuando `$84 == (abs $7E + 4) * 16`**, que es la unica forma en que ese codigo escribe ese campo, asi que la confirmacion no depende de interpretar nada. Distingue el knockback (un salto desde 0) del timer de `$1A28E` y del acumulador de `$1BCB0`, con **tope de 30 frames por slot** (si `$84` se moviera cada frame, 60 lineas/seg bajan el framerate y arruinan la medicion). Ademas imprime un **indice de estados nuevos**: cada valor de `$5F` se anuncia una vez, con su frame, asi que el volcado ya viene con la lista de candidatos y no hay que reinterpretar 200 lineas. Y lleva el **conteo de hurtbox POR OWNER** (`$FFA400` / `$FFA008`), que es la marca de la invulnerabilidad: imprime el frame exacto en que se va y en que vuelve. Con los tres frames (contacto, hurtbox que se va, cambio de `$5F`) se ve que va primero y por lo tanto que provoca a que. **Todo lo de golpe se lee con `registerexec` en `$01EDAC`, la ENTRADA del dispatcher**, no en `registerafter` ni en `$01EDC2`: `$01EDC2` esta despues de la guardia `btst.b #$7, $f550.w` cuyo destino es un `rts`, asi que hay frames en los que no se ejecuta y el hook se **calla sin error**. Descarta los frames sin captura. Lleva **latido**: una linea cada 600 frames con las invocaciones del hook, y un AVISO si no entra. **Es pasivo de verdad: no lee `joypad.get()`, asi que se juega normal.** Verificar con `test_knockdown.lua` (41 pruebas) |
| `tools/gen_stun.py` | Generador del informe de stun |
| `herramientas/desensambladodump_26.py` | Vuelca los 8 flujos de bytes que indexa `$26` (los que elige `$0A` de 1 a 8, punteros en `$3A256`) y clasifica cada byte en dato positivo / dato negativo / codigo. **154 bytes: 90,9 % dato, 3,9 % codigo.** Salen en pantalla los 8 flujos con el valor con signo al lado |
| `herramientas/desensambladoauditar_moves.py` | **Audita nuestra tabla de moves contra el ROM.** Relee los 1950 registros por el camino real (indice de words en `$50` + registro de 8 bytes) y compara con `volcado_moves.txt`: **1950/1950 coinciden byte a byte**. Ademas calcula cuantos indices son moves de verdad, y descubre que **`indice[191]` es offset 0 en los diez contextos** = 195 indices pero **191 moves**. Es el script que sostiene `VERIFICACION.md` §3d |
| `herramientas/desensambladover_indice_moves.py` | La version corta del anterior: imprime el indice de words y los primeros registros de ctx0 y ctx1 con el volcado nuestro al lado, para ver de un vistazo que el camino es el correcto |

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
| `herramientas/desensambladolua/traj.lua` | Trayectorias. **OJO:** usa `S1+0x4B8` como HP, es incorrecto |
| `herramientas/desensambladolua/yuyu_sar2.lua` | Volcado de HP y punteros de animacion |
| `herramientas/desensambladolua/yuyu_frames2.lua` | Eventos de dano y duraciones |
| `herramientas/desensambladolua/vdpinfo.lua` | Patron BizHawk. No portar a FBNeo |

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

| Cuando | Que decia `docs/08-DIARIO/MEMORIA.md` |
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
-- una desde la otra. Ver docs/08-DIARIO/MEMORIA.md, seccion "gui.drawline usa 0xRRGGBBAA".

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
de golpe estaba corrida en uno. `(cancelado)` →
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
y lo que nuevo trajo esta en `VERIFICACION.md` §3e. Resumen de como termino
la cuenta:

| | |
|---|---|
| Acerto en el **191** (y no 195) | §3d, verificado con `auditar_moves.py` |
| Se equivoco en el **"volcado desalineado"** | 1950/1950 entradas coinciden byte a byte |
| Se equivoco en el **HP maximo**: dice que 223 es 255 | §2. **Nuestro `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)* ya decia 223 y era el correcto** |
| Acerpto a verificar `***` | el stun por golpe (2-16 contra 38-62), los 12 contextos con la columna `$90`, `$20` como progresion de `$20000`, `$9C` en `01ef1e`/`01ee48`, el contexto 12, `especiales.danio` como deltas de mana |

**El PDF de la movelist no entra.** Dice "Sin direcciones de memoria", y por la
regla 2 sin direccion no es un dato. Trae justo lo que nos falta —las cadenas de
frames, que son el pendiente 2— pero hay que cruzarlo fila por fila contra el
registro de 8 bytes del ROM antes de adoptarlo.

**Y ojo con una cosa que se nos habia pasado:** `game_data.json` *(el `game_data.json` era el JSON de datos del remake de Godot, que se canceló; aquí se conserva como referencia histórica)* tiene
**`"hp_max": 223`**, que el guia quiere cambiar a 255. **No hay que cambiar nada:
ya estaba bien.**

`Desktop/notas/GENERAL/` (10-06, 925 lineas) dice "reemplaza a
VERIFICACION.md, MOVES-Y-TIMING.md, ...". **No lo hace.** Se cotejo
parte por parte y el resultado es mixto:

| Afirmacion suya | Veredicto |
|---|---|
| `$9C` NO es el ID, se copia a `$44` | **Tenia razon, y mejor que nosotros** |
| `+4` del frame es indice de **sonido** | **Tenia razon.** `$F800` como base de puntero |
| La cola `$F80A`-`$F80D` es de sonido | **Tenia razon** |
| `$F558` es el hit-time del pipeline | Correcto, y lo medimos |
| `$6A` = nivel de empuje, no blockstun | Correcto |
| `$26` = "profundidad, 64 y 192" | **Refutado con las tablas en la mano.** Los datos van de `-40` a `+40`; 64 y 192 son los **offsets de arranque** que escriben `$0x1F7C0`/`$0x1F7D4`, o sea indices. El error es la trampa "mirar solo los escritores", que ya estaba anotada aqui |
| "el volcado de moves esta desalineado" | **Falso, y verificado las 1950 entradas.** `herramientas/desensambladoauditar_moves.py` revalida cada una releyendo el ROM por el camino real (indice de words -> registro) y **1950/1950 coinciden byte a byte**. Nuestra herramienta salta el indice bien. Lo que si estaba mal es el **recorte**: hay 195 indices pero **191 moves**, y las 4 entradas finales por contexto son basura. Ver `VERIFICACION.md` §3d |
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

**No lo invento: es un pendiente heredado.** Esta en la linea 7 del `docs/08-DIARIO/MEMORIA.md` de
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

Medido con `diagnostico_slots.lua` en las dos formas, con el volcado de los 4 slots.
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

Este es el hermano del BOM, y **borro `docs/08-DIARIO/MEMORIA.md` entero de un paso**.

En PowerShell, dentro de una cadena con comillas dobles, **el backtick es el
caracter de escape**, igual que la barra invertida en C. Y nuestros `.md` estan
llenos de backticks, porque el codigo se escribe en markdown inline.

| | |
|---|---|
| Comillas simples `'...'` | el backtick es literal, **funciona** |
| Comillas dobles `"..."` | `D, `) y `n se comen, **no es lo que parece** |

Un `.Replace()` con el `oldString` mal escrito **no da error: no reemplaza nada**.
Y si el `newString` tambien se malescapo, se come los caracteres de al lado, que en
nuestro caso fueron **todas las barras de las tablas**. `docs/08-DIARIO/MEMORIA.md` paso de 204
lineas con `|` a **0**, y el fichero quedo como prosa corrida.

**Como se recuperar:** `git checkout -- docs/08-DIARIO/MEMORIA.md` y rehacer el cambio con la
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

### EL DATO DE SUBQ/ADDQ VA EN EL OPCODE, NO EN UN BYTE
`subq.w #$2, $84(a5)` son **4 bytes**: `55 6D 00 84`. El dato va en los
**bits 11-9** del opcode: `$53`=1, `$55`=2, `$57`=3, `$59`=4. Para cambiar
el 2 por el 4 hay que tocar **el primer byte** de la instruccion, no un
"byte del inmediato" (que no existe). **Y el .asm del proyecto no marca
ese byte**, asi que a ojo no se ve donde esta. Ojo tambien con
`addq.b`: `$52`=1, `$54`=2, `$56`=3, `$58`=4.

### EL .ASM DEL PROYECTO OMITE ALGUNA LINEA
A `$01A288` falta el `move.l $9c(a5), $44(a5)` (son 6 bytes) en el
handler del estado `$0C`. Las direcciones siguientes **no** se desalinean
(el desensamblador sabe el tamano), pero la linea no esta. **Para el codigo
critico, desensambla con Capstone**: el proyecto lo usa como fuente, pero
el `.asm` guardado no coincide siempre. Como el dato de SUBQ/ADDQ esta en
el opcode, el `.asm` ademas **no lo muestra**.

### UNA DURACION DE FRAME DE 255 = "ESPERA"
El frame se repite hasta que algo lo corte. Es la marca de los estados de
espera: el "aire" del teleport (`$25` de ctx6, durs 4,4,8,**255**), el
dash (`$24`, 8,8,4,4,4,**255**), y `$26`/`$27` (1 frame, dur 255).

### `$5D` = EL ESTADO SIGUIENTE
El dispatcher de `$015A5A` lee `$5D` y salta a la tabla de handlers
`$15a68` (256 entradas, una por estado). Los handlers de Itsuki estan en
`$019xxx`-`$01Cxxx`. **No hay un dispatcher por `$5F`**: el unico
`add.b $5f(a5)` del ROM es el de los frames (`$01EB42`).

### EL ATURDIMIENTO POST-KNOCKDOWN USA UN CONTADOR PROPIO
No es la barra `$7E` (esa solo la baja el dano de los golpes, en
`$01F42C`). El contador real es **`$84`** (word), en el estado `$0C`
(handler `$01A282`): -1 por frame, **-2 por pulsacion de boton** (`$72`),
y +2 ticks al frame. Con 255 frames hacen falta ~128 pulsaciones.

