--[[
  LLUVIA DIAGONAL.LUA — COPIA DE TRABAJO de LLUVIA RECTA.LUA.

  ----------------------------------------------------------------------------
  QUE ES Y POR QUE EXISTE

  Copia EXACTA de `LLUVIA RECTA.LUA` (los dos archivos dan 93.623 bytes). Se hizo
  una copia y no una variante para poder trabajar la sensacion diagonal **sin
  tocar la version recta**, que es la que esta medida y documentada.

  ----------------------------------------------------------------------------
  QUE LO HACE DISTINTO DEL OTRO

  Son DOS diferencias, y ninguna es todavia el `dx`:

    1. EL GATE DE PELEA. La lluvia sale solo en el combate. La regla es
       `en_pelea()` = "2+ slots con HP > 0, o 1 vivo y NINGUN slot con HP < 0",
       y esta elegida por medicion: cada medicion mato una regla anterior. Ver el
       bloque de `en_pelea` y `DATOS_VERIFICADOS.md` 5f.

    2. EL FINAL DE LA PELEA, en cuatro fases. Al morir alguien, el juego entra en
       camara lenta y **el gate ya no la apaga**: la apaga `$F558`, que es el timer
       del propio slow-mo. Durante el slow-mo la lluvia cae a la mitad de velocidad,
       y cuando se acaba siguen `COLA_FRAMES` frames a velocidad normal. Ver el
       bloque de fases.

  *** Y `dx` sigue en 0 en las tres capas: la sensacion de caida diagonal TODAVIA NO
  esta escrita. ***

  ----------------------------------------------------------------------------
  QUE SE PRETENDE HACER ACA (del AGENTS.md, seccion "LO QUE SE PIERDE")

  Las tres capas quedaron **rectas**: `dx = 0` en las tres, y con `dx = 0` el
  calculo de `droplet.dx` ni se hace, asi que el parametro esta inerte. Se perdio
  el paralaje por inclinacion, y con el la sensacion de profundidad.

  *** El sitio para devolver la sensacion NO es `dx`, sino la combinacion de
  VELOCIDAD y ALTURA. *** Ese es el punto de partida de este trabajo, y lo que
  AGENTS.md dice de no perder:

      - perder la sensacion vertical de caída es lo unico que no hay que
        recuperar: la altura y la velocidad ya la dan
      - lo que falta es el paralaje lateral

  O sea: devolver la diagonal **por separado de la recta**, sin tocar la que ya
  esta medida.

  ----------------------------------------------------------------------------
  LO QUE NO SE PISA

  - `LLUVIA RECTA.LUA` no se toca. Es la referencia.
  - Las dos capas tienen las suyas: H.Rain es la unica que queda con un alto
    unico. Cualquier cambio de aqui tiene que quedar en esta copia.

  ----------------------------------------------------------------------------
  COMO PROBAR ESTA COPIA

  El banco acepta el nombre por variable de entorno, asi que las dos se prueban
  con el mismo archivo de test:

      luajit test_hitbox_hud.lua
        -> prueba LLUVIA RECTA.LUA (por defecto)

      $env:SCRIPT = "LLUVIA DIAGONAL.LUA"; luajit test_hitbox_hud.lua
        -> prueba ESTA

  El banner dice cual se probo, y si el nombre no existe el banco sale con
  error en vez de caer en la recta en silencio.

  ----------------------------------------------------------------------------
  A PARTIR DE ACA, LO DE ABAJO ESTA COPIADO SIN CAMBIOS

  Uso:
    Game > Lua Scripting > New Lua Script Window > Browse > este fichero
    Cargar el ROM md_yuyumte y entrar a un combate.

  Muestra:
    - Las cinco listas de colisiones: hitbox, clash, hurtbox, pushbox y el
      descriptor de grab. Solo borde, sin relleno, para tapar lo menos posible.
    - El rango de agarre, siguiendo al personaje.
    - Tres capas de LLUVIA, que usan las hurtbox como referencia:
        H.Rain  pesada  2 px, translucida. Salpica y muere al tocar personaje
                          o suelo. La mas lenta.
        B.Rain  fondo   1 px, solida. Se OCULTA al entrar en una hurtbox y
                          reaparece al salir. Muere en el suelo del plano fondo.
        C.Rain  cercana 1 px, opaca. No colisiona y se dibuja siempre encima.

  Menu: se abre manteniendo MODE. A=ON/OFF, flechas mueven, B=reset.

  ----------------------------------------------------------------------------
  QUE SE SACO Y POR QUE (2026-10-05)

  Este script era un HUD de estudio: barras de HP/maná, stun, hit-time, facing,
  coordenadas, historial de botones, timeline, cuadricula, display de mandos,
  bloque de combos con la tabla de carga de maná por hit y el titulo animado.

  Todo eso se elimino. El script queda SOLO con las cajas de colision, que es
  lo unico que hace falta: las cajas se van a usar como REFERENCIA para efectos
  visuales dibujados por Lua (lluvia con oclusion, salpicaduras, etc.), no para
  estudiar el juego.

  Lo que se conserva a proposito, aunque no sea una caja:

    - El menu de toggles. Es lo que permite apagar los overlays para ver el
      juego limpio, y prenderlos de nuevo cuando hay que calibrar.
    - El rango de agarre. Va junto a las cajas porque sale de la MISMA lista
      ($FFA600) y comparte su conversion a pantalla.

  NOTA DE ARQUITECTURA:

    Leer y dibujar son DOS CAPAS y no se mezclan jamas. El snapshot de los
    contadores se toma SIEMPRE en el exec hook de $01EDAC, sin mirar ningun
    SHOW_*: ver snapshot(). Y rects_de() calcula los rectangulos de una lista
    SIN mirar L.on(), porque la lluvia los necesita con las cajas apagadas.

    Por eso el frame hace el trabajo en una sola pasada y reparte el resultado:
        use, src = snapshot()        -- fresco, o cinco ceros
        rects     = rects_del_frame(use)
        update_lluvia(rects[hurt])  -- la oclusion, antes de dibujar
        draw_boxes(use, rects, src)
    Si la lluvia leyera la memoria por su cuenta, tendria su propia copia de la
    logica de frescura y el dia que una se arreglara la otra se quedaria vieja.

  Es 100% pasivo: no escribe ni un byte en la memoria del juego.

  Documentacion de las direcciones: COLISIONES_Y_HITBOXES.md y AGENTS.md
--]]

--------------------------------------------------------------------------------
-- Configuracion
--------------------------------------------------------------------------------

-- Los cinco flags son parte del API del snapshot: draw_boxes consulta L.on() para
-- saber que lista pintar, asi que los flags se quedan.
--
-- APAGADOS DE FABRICA. Las cajas son la referencia de datos que usa la lluvia
-- (la de fondo se oculta al entrar en una hurtbox), pero no es un efecto que
-- tenga sentido ver siempre encima: entorpecen la lectura y tapan el juego. Se
-- encienden desde el menu cuando hacen falta.
local SHOW_HITBOXES  = false
local SHOW_CLASH     = false
local SHOW_HURTBOXES = false
local SHOW_PUSHBOXES = false

-- LA GRAB SE SACO DEL MENU. La opcion no funcionaba de forma confiable, asi que
-- dejo de ser configurable y paso a ser una constante.
--
-- NO esta eliminada: la lista "grab" de LISTS y el marcador de rango siguen ahi,
-- y con SHOW_GRAB en true se dibujan como antes. Ponerla en true la deja siempre
-- visible, sin forma de apagarla desde el menu.
--
-- Por que se dejo la lista puesta y no se borro: la logica de dibujado es la
-- misma que las otras cuatro (el unico detalle propio es el stride $20, porque el
-- descriptor de grab es el doble que una caja), asi que sirve de referencia. Y
-- apagarla no cuesta nada: mientras este en false no se lee ni se dibuja.
local SHOW_GRAB      = false

-- Filtro de jugador. APAGADO de fabrica por lo mismo. Con el filtro OFF solo se
-- pinta el P1, que es el humano en la configuracion normal.
local SHOW_P2 = false

-- Calibracion de la conversion mundo -> pantalla, en pixeles.
--
-- $08/$0C NO son pixeles de pantalla: en $01575E se pasan como d2/d3 a $012C4,
-- que es el parser de la lista de sprites del VDP. Y $A014/$A016 son la CAMARA
-- (se actualizan cada frame en $0215D2 y $0215F4), no una base fija del stage.
--
-- Por eso el offset se calibra a mano en vez de copiar la formula de
-- loc_0156F0. La referencia es el CENTRO de la sombra redonda de los pies: la
-- linea horizontal de la cruz tiene que caer ahi.
local CAL_X, CAL_Y = -127, -127

--------------------------------------------------------------------------------
-- COLOR: FBNeo lee 0xRRGGBBAA, NO 0xAARRGGBB
--
-- Verificado empíricamente con un diagnostico de 20 muestras que se cargo en
-- lugar de este script (ya borrado; el resultado quedo anotado en AGENTS.md).
-- El byte ALTO es ROJO y el byte BAJO es ALFA:
--
--     0xRR GG BB AA
--
-- No es una conjetura, sale de las muestras:
--
--     0xFF0000FF "azul"    -> ROJO        (el FF de arriba se pinto como rojo)
--     0xFF00FF00 "verde"   -> INVISIBLE   (quedo con alfa 0 en el byte bajo)
--     0xFFFF00FF "magenta" -> AMARILLO
--     0x000000FF "alfa 0"  -> NEGRO opaco (el fondo de la prueba era casi negro)
--
-- Escribir 0xAARRGGBB no da error: da un color equivocado, en silencio. Por eso
-- NINGUN color de este script se escribe en hexadecimal a mano, todos pasan por
-- color(). Ese fue el bug que hacia que la lluvia saliera rosa.
--
-- OJO: 0xRRGGBBAA es un numero > 2^31 y en LuaJIT eso se guarda como float. No
-- pasar estos colores por string.format("%08X"), que imprime un byte repetido.
local function color(r, g, b, a)
  return r * 16777216 + g * 65536 + b * 256 + a
end

--------------------------------------------------------------------------------
-- Direcciones (verificadas contra el desensamblado)
--------------------------------------------------------------------------------

local P1 = 0xFF8400                -- slot del jugador 1
local P2 = 0xFF8800                -- slot del jugador 2

-- Los cuatro slots del array. El bucle de $1C06A los recorre de a $400 asi que
-- estos cuatro son todos los que existen.
local SLOTS = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }

local OFF_HP    = 0x78              -- HP real, word SIGNED. Negativo = muerto
local OFF_MOVES = 0x8C              -- puntero a la tabla de moves

-- EL TIMER DE LA CAMARA LENTA DE MUERTE. Word SIN signo.
--
-- MEDIDO 08-10, con el dato delante y el numero de frame al lado:
--
--   $F558 = 0      TODA la pelea 1, los menus, y el primer tramo de la pelea 2
--   $F558 = 159    el frame en que el enemigo cae al suelo
--   $F558 = 158    al siguiente
--    ...                 ...
--   $F558 = 120    treinta y nueve frames despues
--   $F558 = 159    OTRA VEZ, con el HP del cadaver ya en -13
--
-- O sea que **el valor ES la cuenta regresiva**: no hay que contar frames, se leen.
-- Y **nunca se queda en 0 en medio del slow-mo**, porque el refresco lo salta de
-- 120 a 159. Por eso `$F558 > 0` es un test limpio y no hace falta un segundo campo.
--
-- El refresco esta MEDIDO y no es un misterio: con el enemigo ya en negativo (-5,
-- -13, -18, -22, -27, -36, -44, -51, -58) **cada golpe suyo vuelve a ponerlo en
-- 160 en el MISMO frame en que el HP cambia**: 9 veces en 320 frames, una cada 40.
--
-- El unico escritor en todo el ROM es `0x1FA82: move.w #$a0, $f558.w` = 160, y esta
-- en el camino de la MUERTE. Por eso `$F558 != 0` SIEMPRE quiere decir que alguien
-- murio: no hay camara lenta por otro motivo. ***No se confirmo que sea ese mismo
-- `0x1FA82` el que reaplica en cada golpe***. Ver `DATOS_VERIFICADOS.md` 5f.
local G_F558 = 0xFFF558

local rb  = memory.readbyte
local rw  = memory.readword
local rws = memory.readwordsigned

-- EL SLOT DEL P2 NO ES FIJO, y por eso no puede estar en una constante.
--
-- Medido con yuyu_slots_diag.lua:
--
--   desde el select, Battle Royale 1v1 -> P2 en $FF8800
--   desde un savestate                 -> P2 en $FF9000
--
-- Los dos son ciertos segun como se armo la partida.
--
-- Un slot se considera vivo si tiene HP o tabla de moves. Solo se reasignan P1 y
-- P2 si se encuentran DOS: con menos se dejan las constantes, que es
-- exactamente el comportamiento anterior. Por eso el autotest sigue igual, que
-- solo arma un jugador.
--
-- AVISO, y corrige lo que se creia antes: esto NO arregla ningun fallo del HUD.
-- Se|ja escrito que con la constante vieja el P2 "no dibuja nada, sin error", y
-- es FALSO. Este valor no llega a la salida del dibujo:
--
--   - owner_filter() decide con el flag SHOW_P2, no con el slot.
--   - to_screen() ancla a owner_base(owner) or P1, pero la conversion es afin de
--     pendiente 1 y el base se cancela: (worldY - A016 + F566 + 24 + CAL_Y) +
--     (by - worldY) queda en by - A016 + F566 + 24 + CAL_Y, sin el base. En X
--     igual. O sea que el fallback a P1 no desplaza la caja.
--   - las dos rutas donde owner_base() si decide, rects_grab() y
--     draw_grab_range(), estan detras de SHOW_GRAB, que es false de fabrica.
--
-- Con P2 en $8800 y con P2 en $9000 se dibuja EXACTAMENTE lo mismo: ver el
-- autotest 8b, que compara la geometria completa pixel a pixel y se autocomprueba
-- para no quedarse verde por vacuidad.
--
-- Entonces para que esta funcion? Para lo que SI lee del slot del P2 y todavia
-- no existe en el HUD (HP, stun, mana, moves). Anyadirlo aca deja la primitiva
-- lista, igual que hace yuyu_slots_diag.lua, en vez de repetir una constante que
-- ya se sabe dudosa.
local function detectar_slots()
  local vivos, n = {}, 0
  for i = 1, #SLOTS do
    local b = SLOTS[i]
    if rws(b + OFF_HP) ~= 0 or rw(b + OFF_MOVES) ~= 0 then
      n = n + 1
      vivos[n] = b
    end
  end
  if n >= 2 then
    P1, P2 = vivos[1], vivos[2]
  end
end

-- Solo se declaran los offsets que quedan en uso. Los que usaban el HUD
-- (HP en $78, maná en $B8, stun en $7E/$80, hitpause en $69, $26, el frame en
-- $59/$5A/$5B y la velocidad en $28/$2A) se fueron con el, y con ellos el
-- bloque de combos. Ver DATOS_VERIFICADOS.md y AGENTS.md, que si los listan.
local OFF_WORLD_LO,  OFF_WORLDY_LO = 0x40, 0x44
local OFF_FACING                  = 0x61

-- ----------------------------------------------------------------------------
-- GATE DE PELEA: ESTAMOS PELEANDO?
--
-- Que la lluvia salga solo cuando ya se esta peleando, y no en los menus.
--
-- MEDIDO 08-10, dos corridas completas (titulo -> seleccion -> combate -> KO ->
-- menu). De los cuatro candidatos, SOLO el HP cambia al entrar y al salir:
--
--   frame  417   hp=0/0/0/0          $F550=$00   <- menu
--   frame  652   hp=223/223/0/0      $F550=$00   <- ENTRA la pelea 1
--   frame  851   hp=0/0/0/0          $F550=$00   <- KO, se acabo
--   frame 1845   hp=223/0/0/223      $F550=$00   <- ENTRA la pelea 2
--   frame 1864   hp=223/0/0/223      $F550=$01   <- $F550 cambia, y NO en la pelea 1
--   frame 3997   hp=0/0/0/-1024      $F550=$00
--   frame 3998   hp=0/0/0/0          $F550=$00   <- fuera
--
-- *** Y LA SEGUNDA CORRIDA CORRIGIO ESTO ***
--
-- El gate de abajo es "**dos** slots con HP > 0", no "alguno". Con "alguno" la
-- pelea 2 dejo de llover **987 frames despues del KO**: el enemigo cayo a -5 en
-- el frame 3680 y el gate se apago en el 4667, cuando el P1 (que seguia con 147)
-- llego a 0. Dieciseis segundos de lluvia con el combate ya terminado.
--
-- QUE SE CORRIGIO DE LA RAZON QUE HABIA ANTES
--
-- Se escribio que el HP no podia servir porque `0x12AE6` y `0x13A88` lo escriben
-- cada frame con `$FF` y no lo borran al salir. **La segunda mitad era mentira:**
-- lo que se comprobo es que el HP vuelve a 0 al terminar. El `$FF` de `$78` se
-- ve un frame y despues el juego lo baja a 223 (0x1579C, la barra `$7A` lo
-- persigue) y de ahi lo baja el dano crudo (`sub.w $65, $78(a4)`, `0x1F424`).
-- La razon de fondo era una confusion: "se escribe cada frame" no dice nada de un
-- gate, porque el gate TAMBIEN se lee cada frame.
--
-- LOS OTROS TRES DESCARTADOS, con la medicion delante
--
--   $F550 bit 7  NO. Estuvo en `$00` TODA la pelea 1 y en `$01` la pelea 2: no
--     acompana ni la entrada ni la salida. Es el flag de "simulacion suspendida"
--     (gates `loc_01EDAC`, que arranca con `btst.b #$7, $f550.w`, y las dos
--     maquinas de estados de arriba), como ya se sospechaba.
--
--   $F558 / $F55A  NO. Solo prendieron al FINAL de la pelea 2, cuando el enemigo
--     ya estaba muerto, y NUNCA en la pelea 1. `$F558` es el timer de la muerte
--     (160 = `$A0` en `0x1FA82`) y cuenta con wrap.
--
--   conTabla (`$8C != 0`)  NO. En el MENU oscila: frames 1344 -> 1, 1442 -> 0,
--     1456 -> 2, 1518 -> 0, 1588 -> 1, con los cuatro slots en HP 0. O sea que
--     "tiene tabla de moves" prueba "hubo pelea", no "estamos peleando": el
--     puntero del ultimo round se queda, y la `0x13A88` no lo borra.
--
-- POR QUE `> 0`, Y NO `!= 0` NI `== 223`
--
-- El HP va a `$FC00` (-1024) al terminar y el slot LO CONSERVA en el menu:
-- MEDIDO, frame 3997, hp=0/0/0/-1024. Con `!= 0` el menu contaria como pelea.
--
-- Y `223` NO es el disparador, `> 0` lo es: `223` es el valor de ARRANQUE de la
-- pelea, no su estado. Con `== 223` la lluvia se apagaria en el PRIMER golpe,
-- porque el HP baja a 222 de inmediato. MEDIDO, pelea 2, un solo round:
-- `223 -> 200 -> 147 -> 5 -> -5 -> -1024`.
--
-- Y hay frames de pelea con HP NEGATIVO: en la pelea 2 el enemigo cae a -7, -16,
-- -22 antes de llegar a -1024. Con `> 0` esos frames no cuentan por ESE slot.
--
-- *** LO QUE LA MEDICION NO CUBRE ***
--
-- Un modo de UN SOLO peleador (practice), donde nunca hay dos vivos y la lluvia no
-- sale nunca. ***No medido: no se entro a un modo asi.*** Es el unico caso abierto.
--
-- LO QUE ESTE GATILLO NO DICE, Y QUE YA NO TIENE QUE DECIR
--
-- Sigue sin distinguir el round de la pantalla de victoria, y ahora **eso es a
-- proposito**: este gate SOLO enciende la lluvia. El que la apaga, y el que le
-- dice cuanto tiempo sigue, es `$F558`, que es el slow-mo del juego y se mide
-- frame a frame. Ver el bloque de las fases, mas abajo.
--
-- Antes este gate apagaba la lluvia en el KO, y por ahi salio el bug de los 987
-- frames: apagaba cuando el segundo peleador bajaba de vivo, no cuando el round
-- terminaba. Un INFERIDO no puede cortar una animacion; solo puede encenderla.
--
-- El ciclo pedido, textual, queda asi y esta en el banco como prueba:
-- `-1024` -> no llueve, `0` -> no llueve, `223` -> llueve.
-- ----------------------------------------------------------------------------

-- Se lee UNA vez por frame, en el callback, y se pasa a los dos consumidores.
-- Llamarla dos veces (una al simular y otra al dibujar) seria leer la memoria dos
-- veces y, si algun dia se cuela una escritura en medio, dos respuestas
-- distintas en el mismo frame.
local function en_pelea()
  -- DOS MEDICIONES, Y CADA UNA MATO UNA REGLA.
  --
  -- Regla 1, "> 0" (PRIMERA medicion, 08-10). Con la pelea 2 dejo de llover 987
  -- frames despues del KO: el enemigo cayo a -5 en el frame 3680 y el gate se apago
  -- en el 4667, cuando el P1 (que seguia con 147) llego a 0.
  --
  -- Regla 2, ">= 2 slots con HP > 0" (SEGUNDA medicion). Arregla ese caso, porque
  -- un round termina cuando bajan de dos. PERO la rompio el usuario al otro dia:
  -- "la CPU tenia 0 de vida y cuando le lance un ataque especial, lo bloqueo, no
  -- murio ... y las gotas se detuvieron". O sea que **`HP == 0` NO es estar
  -- muerto**: en este juego se muere cuando la vida baja **de** 0, asi que un
  -- peleador en exactamente 0 sigue peleando. Y con `> 0` el gate lo contaba como
  -- muerto. La regla "> 0" estaba WRONG desde el principio y la aceptamos porque
  -- en las dos peleas medidas no se dio el caso.
  --
  -- LO QUE DEBERIA SER, y no esta verificado: HP < 0 como "muerto". El unico
  -- escritor negativo del ROM es `0x1A1A4: move.w #$fc00, $78(a5)` = -1024, el
  -- CENTINELA de fin de pelea, y no un "-1 al primer golpe". Si al bloquear un
  -- especial la vida pasa por un negativo chico y el peleador NO muere, entonces
  -- "ningun negativo" apagaria la lluvia en ese frame y habriamos movido el bug de
  -- lugar en vez de arreglarlo. ***FALTA MEDIR: que valor tiene el HP de un
  -- peleador que esta a 0 y bloquea un especial, en el frame justo despues.** Con
  -- un numero de un frame se decide, y es el mismo protocolo de siempre.
  --
  -- MIENTRAS TANTO, el criterio que sale de los cinco estados MEDIDOS:
  --
  --   hay pelea si hay DOS O MAS slots con HP > 0, o si hay UNO y NINGUN slot
  --   tiene HP negativo.
  --
  --   menu                     0/0/0/0          0 vivos, 0 muertos  -> NO
  --   menu                     0/0/0/-1024      0 vivos, 1 muerto  -> NO
  --   pelea 1 al entrar        223/223/0/0      2 vivos, 0 muertos -> SI
  --   pelea 2 al entrar        223/0/0/223      2 vivos, 0 muertos -> SI
  --   peleador a 0 bloqueando  147/0/0/0        1 vivo,  0 muertos -> SI  <- el caso del bloqueo
  --   pelea 2 en el KO         147/0/0/-5       1 vivo,  1 muerto  -> NO  <- el caso del KO
  --
  -- El segundo caso del KO (fallece el enemigo, el ganador sigue a 147) tiene UN
  -- muerto, asi que apaga. Y el caso del bloqueo tiene UN vivo y CERO muertos, asi
  -- que sigue. Los dos son lo que pedia cada uno.
  --
  -- Y "dos o mas vivos" cubre el 1v4, que con la regla anterior se apagaba al
  -- primer KO: con cuatro peleadores el conteo va 4, 3, 2 mientras quedan vivos y
  -- no hay ninguno muerto todavia.
  --
  -- `rws`, CON signo: `$FC00` = -1024 tiene que salir NEGATIVO, o el centinela
  -- de "no hay peleador" contaria como pelea.
  local vivos, muertos = 0, 0
  for i = 1, #SLOTS do
    local h = rws(SLOTS[i] + OFF_HP)
    if h > 0 then
      vivos = vivos + 1
    elseif h < 0 then
      muertos = muertos + 1
    end
  end
  if vivos >= 2 then return true end
  if vivos == 1 and muertos == 0 then return true end
  return false
end

-- Lo unico que la DIAGONAL tiene y la RECTA no, en UNA linea y no en una tanda de
-- condicionales escondidas en dos funciones.
--
-- OJO CON LO QUE HACE EL FLAG, porque el comentario de al lado mintio durante
-- meses: con `GATE_PELEA = false` este gate NUNCA devuelve `true`, o sea que la
-- lluvia **queda apagada siempre**, en el menu y en la pelea. NO es "el script se
-- comporta como la RECTA": la RECTA no tiene gate y llueve siempre. Para eso esta
-- `LLUVIA RECTA.LUA`, que es el otro archivo. (Corregido al leer el codigo, que es
-- lo que manda cuando un comentario y el codigo no coinciden.)
local GATE_PELEA = true

--------------------------------------------------------------------------------
-- EL FINAL DE LA PELEA: CUATRO FASES, Y LA QUE MANDA ES EL JUEGO
--
-- MEDIDO 08-10, pelea 2, un solo round. El enemigo cae al suelo en el frame 3680
-- con el P1 en 147. A partir de ahi, con numero de frame y el valor de `$F558` al
-- lado:
--
--   3680  hp 147/0/0/-5    $F558 159   arranca la camara lenta de MUERTE
--   3681  hp 147/0/0/-5    $F558 158
--    ...                         ...
--   3719                    $F558 120
--   3720  hp 147/0/0/-13   $F558 159   REFRESCO, con un golpe al cadaver
--   3760  hp 147/0/0/-18   $F558 159
--    ...                         ...
--   4000  hp 147/0/0/-58   $F558 159   el noveno refresco
--   4159                    $F558 0     se acaba
--
-- O sea **479 frames de camara lenta, no 160**: los 9 refrescos la alargan. Y
-- despues viene un tramo a velocidad normal (la animacion del vencedor), que el
-- jugador puede acortar con START.
--
-- QUE SE PIDE Y QUE SE ESCRIBE
--
--   NORMAL   pelea en curso, la lluvia a su velocidad
--
--   SLOW     mientras `$F558 > 0`: la lluvia cae a MITAD de velocidad. Y se
--            sincroniza sola, porque `$F558` dice cuantos frames quedan y los
--            refrescos la reinician solos: el script NO cuenta frames del slow-mo.
--
--   COLA     COLA_FRAMES frames DESPUES del ULTIMO frame de slow-mo (no del KO
--            original: si el slow-mo se extendio 9 veces, la cola arranca de la
--            ultima), a velocidad NORMAL.
--
--   OFF      y ahi se apaga de verdad.
--
-- POR QUE EL GATE DE HP DEJA DE CORTAR LA LLUVIA
--
-- Porque es un INFERIDO: no pregunta "¿termino el round?" sino "¿queda alguien en
-- pie?", y con esa pregunta apagaba tarde (987 frames despues del KO) o tarde al
-- reves (con un peleador en 0 bloqueando). Ahora el gate SOLO enciende, y el que
-- apaga es un dato del juego que cuenta frames hacia atras.
--
-- Y no hace falta una rama para el caso raro de "el gate se apaga y hay slow-mo sin
-- muerte": **`$F558 > 0` SIEMPRE es una muerte**, porque su unico escritor esta en
-- el camino de la muerte. Las dos señales llegan en el MISMO frame del KO, no
-- compiten, y el orden de las preguntas de mas abajo hace que gane `$F558`.
--
-- *** SUPUESTO DECLARADO: 1v1. *** Con dos peleadores los dos en HP 0 y los dos
-- bloqueando, `en_pelea()` devuelve falso (0 vivos, 0 muertos) y la lluvia se apaga
-- con los dos en pie. Es el mismo fondo del pozo ya anotado en `en_pelea`: `HP == 0`
-- significa "peleador sin vida" y "slot vacio" al mismo tiempo, y no hay ningun
-- byte que los separe. ***No medido: no se entro a un 2v2.** De momento, 1v1.

local F_NORMAL = 0      -- pelea en curso
local F_SLOW   = 1      -- camara lenta de muerte corriendo
local F_COLA   = 2      -- la cola posterior al slow-mo
local F_OFF    = 3      -- apagada

local NOMBRES_FASE = { "NORMAL", "SLOW", "COLA", "OFF" }

-- LA MITAD, y no "un frame si y otro no". La lluvia del script NO esta sincronizada
-- con la del juego: las tres velocidades se eligieron a ojo (0,45 / 0,65 / 1,10 s),
-- asi que se eligio lo que se pidio, que es bajar la velocidad a la mitad.
--
-- *** LA OTRA VARIANTE NO ESTA DESCARTADA POR NADA. *** Se escribio aqui que "si queda
-- feo, avanzar un frame si y otro no (~30 Hz) es un tiron": eso era un ARGUMENTO
-- sobre la frecuencia, no algo medido ni visto, y el usuario contesto que a ojo la
-- version de multiplicar no se ve mal. Ademas el argumento daba la vuelta: con una
-- base lenta, multiplicar es la version que **menos** se nota, no la que mas.
--
-- O sea: la eleccion es de gusto, no hay dato que la imponga, y lo que decide es el
-- ojo del usuario. La variante alternativa sigue en pie y se cambia con una linea.
local MULT_SLOWMO = 0.5

-- Frames de lluvia a velocidad NORMAL despues del ULTIMO frame de slow-mo.
--
-- Son frames de LUA, no de juego: el slow-mo ya termino y lo que sigue va a
-- velocidad normal, asi que 120 frames son unos 2 s de reloj. La animacion del
-- vencedor que se ve detras dura mas, y con esto la lluvia cubre la mayor parte de
-- la parte que no se puede saltar con START. ***SELECCION A OJO, no medida: el
-- numero viene pedido, y si queda bien se comprueba a ojo en el emulador.***
-- Subirlo a 300 frames y cortar con START es la continuacion acordada.
local COLA_FRAMES = 120

local fase   = F_OFF
local cola_n = 0

-- UNA vez por frame, y devuelve dos cosas: si la lluvia se dibuja, y a que
-- velocidad. Se pasa entera a `update_lluvia` y a `draw_lluvia` para que no se
-- vuelva a leer la memoria dos veces en el mismo frame.
--
-- EL ORDEN DE LAS TRES PREGUNTAS es lo que resuelve los casos limite:
--
--   1) `$F558 > 0`     manda sobre todo. Una muerte no tiene ambiguedad.
--   2) el gate prendido manda sobre la cola, para que una pelea NUEVA no espere a
--      que se acabe una cola de la pelea anterior (y para que no haya ni un frame
--      de OFF en medio de un combate).
--   3) solo con el gate apagado se cuenta la cola.
--
-- Con ese orden, el frame del KO (que es el unico en que 1) y 2) se dan a la vez)
-- cae en SLOW sin hueco: no hay ni un frame entre "llueve normal" y "llueve a la
-- mitad".
local function paso_lluvia()
  local f558 = rw(G_F558)
  local enp  = GATE_PELEA and en_pelea()

  if f558 > 0 then
    -- Un refresco no necesita llevar la cuenta: cuando `$F558` vuelva a 0 se sale
    -- de SLOW por la rama de abajo, y esa rama rearma la COLA desde cero. Eso es
    -- justo lo que se pide: que la cola espere al ULTIMO frame de slow-mo.
    fase = F_SLOW
  elseif enp then
    fase = F_NORMAL
    cola_n = 0
  elseif fase == F_SLOW then
    fase = F_COLA
    cola_n = COLA_FRAMES
  elseif fase == F_COLA then
    -- El frame en que se arma la COLA (el de arriba, con `cola_n = COLA_FRAMES`)
    -- **YA es un frame de cola**: la cuenta son los frames que FALTAN, no los que
    -- pasaron. Por eso el ultimo frame con lluvia es el de `cola_n = 1`, y el de
    -- `cola_n = 0` ya apaga: son exactamente COLA_FRAMES frames de lluvia.
    --
    -- OJO con el off-by-one, que aqui PARECE y no muerde: `<= 0` y `< 1` son
    -- **equivalentes**, porque `cola_n` nunca baja de 0 (no se decrementa estando en
    -- 0: en cuanto llega a 0 la fase pasa a OFF y el decremento no se repite).
    -- Comprobado por mutacion: cambiar uno por el otro deja las 204 pruebas en
    -- verde. O sea que lo que hay que vigilar no es el COMPARADOR, es que `cola_n` se
    -- arme con `COLA_FRAMES` y no con `COLA_FRAMES - 1`, que si se nota (120 -> 119).
    cola_n = cola_n - 1
    if cola_n <= 0 then fase = F_OFF end
  else
    fase = F_OFF
  end

  if fase == F_SLOW then return true, MULT_SLOWMO end
  if fase == F_COLA then return true, 1 end
  return fase == F_NORMAL, 1
end

--------------------------------------------------------------------------------
-- Colisiones
--------------------------------------------------------------------------------

-- Un color por caja, opaco. El alpha del relleno no sirve de nada: gui.box lo
-- ignora y pinta opaco, por eso las cajas se dibujan solo con el borde.
--
-- Cada tipo tiene un TRAZADO distinto, no solo un color distinto: con cinco
-- rectangulos superpuestos del mismo color el ruido era insufrible.
--
--   solid    rectangulo completo  -> hitbox, la que mas importa
--   dashed   rectangulo punteado  -> hurtbox
--   corners  solo las 4 esquinas   -> pushbox y clash, las mas grandes
--   double   doble rectangulo     -> grab, no es una caja normal
--
-- EL ORDEN DE ESTA TABLA ES EL ORDEN DE DIBUJO: primero lo que menos importa,
-- asi la hitbox queda arriba de todo y nunca tapada.
local LISTS = {
  { name = "push", base = 0xFFA500, cnt = 0xFFA00A, stride = 0x10,
    on = function() return SHOW_PUSHBOXES end,
    style = "corners", line = color(0x60, 0xE0, 0x60, 0xFF) },
  { name = "clsh", base = 0xFFA300, cnt = 0xFFA006, stride = 0x10,
    on = function() return SHOW_CLASH end,
    style = "corners", line = color(0xC0, 0xC0, 0x40, 0xFF) },
  { name = "hurt", base = 0xFFA400, cnt = 0xFFA008, stride = 0x10,
    on = function() return SHOW_HURTBOXES end,
    style = "dashed", line = color(0x80, 0xA0, 0xFF, 0xFF) },
  { name = "grab", base = 0xFFA600, cnt = 0xFFA00C, stride = 0x20,
    on = function() return SHOW_GRAB end,
    style = "double", line = color(0xE0, 0x40, 0xE0, 0xFF) },
  { name = "hit",  base = 0xFFA200, cnt = 0xFFA004, stride = 0x10,
    on = function() return SHOW_HITBOXES end,
    style = "solid", line = color(0xFF, 0x60, 0x60, 0xFF) },
}

local HOOK_PC = 0x01EDAC

-- Contador de frame PROPIO. No se usa emu.framecount() porque no avanza de
-- forma confiable en este build, y cuando no avanzaba el snapshot se
-- reutilizaba para siempre: la caja del ultimo golpe quedaba congelada en el
-- aire. Este se incrementa una vez por registerafter, o sea una vez por frame.
local frame_id = 0

local hooked = false
local exec_stamp = -1

-- Fallback por escritura: si el exec hook no prende, los write hooks sobre los
-- cinco contadores capturan los valores. El dispatcher escribe el total al
-- final y despues pone 0, asi que se ignoran las escrituras en 0.
local wr_counts = { 0, 0, 0, 0, 0 }
local wr_seen = false
local wr_frame = -1

-- Memoria del rango de grab, indexada por la TABLA DE MOVIMIENTOS ($8C) del
-- personaje, no por el jugador: cada personaje usa siempre el mismo builder de
-- grab, asi que la tabla lo identifica de forma unica.
--
-- VACIA a proposito: hay tres builders con valores distintos y no se sabe cual
-- usa cada personaje hasta medirlo con un agarre real.
--   $161BE:  dxm=16  dy=-48  16x16
--   $175EA:  dxm=16  dy=-16  12x16
--   $18346:  dxm=24  dy=-48  24x8
local grab_mem = {}
local probe_n = 0

-- GOTAS REALMENTE DIBUJADAS ESTE FRAME. Un numero, y no una sonda.
--
-- Por que hace falta, y es la leccion: el sintoma "las gotas quedan congeladas y
-- visibles" se discutio entre el script y el juego **a ojo**, y a ojo no se gana: las
-- lineas del stage y las del overlay se parecen, y una foto no las separa. Con ESTE
-- numero no hay que mirar nada: si en el menu dice 0, el script no esta dibujando
-- una sola gota, y la pantalla no lo discute.
--
-- DECLARADO ACA y no junto a `draw_lluvia`, que esta mil lineas mas abajo, porque el
-- latido de la linea 885 lo usa. Si se declarara abajo, `draw_boxes` lo veria como
-- **global nil** y el `%d` recibiria un nil: la trampa de "un local declarado mas
-- abajo", por la novena vez. Y aqui el fallo seria silencioso: el numero saldría en
-- blanco y nadie sabria por que.
local gotas_dibujadas = 0

-- Corrige que la cruz no este exactamente centrada en el sprite. La vertical
-- se calibro contra el centro de la sombra; la horizontal quedo sin afinar.
local GRAB_X_FIX = 0

-- El snapshot del frame, UNA vez por frame. Lo consume el exec hook de $01EDAC
-- y lo leen las demas piezas del frame.
--
-- La tabla del snapshot tiene que existir ANTES de que se registre el hook.
-- Si se declarara despues de arm_hook(), el write hook del contador 5 (el grab,
-- $FFA00C) podria llegar antes y hacer "wr_counts[5] = n" sobre un nil.
local counts = { 0, 0, 0, 0, 0 }

-- Si se dibuja una lista cuyo contador NO fue escrito este frame. Should be
-- false: leer el contador directo dejaba la ultima caja colgada en el aire.
-- Ponerlo en true solo para depurar, porque reintroduce el bug.
local RAW_FALLBACK = false
local raw_warned = false

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------

local function own_lo(v)
  return bit.band(v, 0xFFFF)
end

-- El owner NO se guarda completo. El builder hace "move.w a5" (0x01EC40,
-- 0x01EC9E, 0x01ECFC, 0x01ED5A, 0x0161BE), asi que el campo +$C solo tiene
-- el WORD BAJO: $8400 para P1 y $8800 para P2.
local function owner_base(v)
  local lo = own_lo(v)
  if lo == own_lo(P1) then return P1 end
  if lo == own_lo(P2) then return P2 end
  return nil
end

local function list_by(name)
  for i = 1, #LISTS do
    if LISTS[i].name == name then return LISTS[i] end
  end
  return nil
end

-- Indice de una lista dentro de LISTS. Necesario porque el snapshot (counts)
-- va indexado por posicion, no por nombre.
local function indice_de(name)
  for i = 1, #LISTS do
    if LISTS[i].name == name then return i end
  end
  return nil
end

local function moves_key(base)
  return rw(base + 0x8C)
end

-- Los contadores son offsets EN BYTES, no cantidades.
local function box_count(counter, stride)
  if counter <= 0 then return 0 end
  return math.min(math.floor(counter / stride), 0xF0 / stride)
end

-- nil = dibujar todas las cajas; un numero = solo las de ese jugador.
-- Ojo: no escribir como "SHOW_P2 and nil or P1", porque el and/or de Lua
-- devuelve P1 en los dos casos.
local function owner_filter()
  if SHOW_P2 then return nil end
  return own_lo(P1)
end

--------------------------------------------------------------------------------
-- Conversion mundo -> pantalla
--
-- $08/$0C son la posicion en pantalla PERO CLAMPADA: loc_0156F0 (0x15700 y
-- 0x15730) recorta X a [0x40..0x1FF] y Y a [0x40..0x1C0] y luego resta 8.
-- En cuanto el personaje se sale de esa caja el valor se satura y todo lo
-- anclado a el se queda corrido. Por eso se recalcula la MISMA formula SIN
-- clamp y SIN el offset de empuje ($54/$56), que es de un solo frame.
--
-- OJO: esta conversion NO esta calibrada del todo. CAL_X/CAL_Y son a mano y
-- falta el termino de $A014, asi que las cajas pueden caer corridas respecto
-- del sprite. Es el pendiente numero 6 de AGENTS.md, y la razon de que el
-- menu siga teniendo los interruptores: sin ver las cajas no hay forma de
-- saber si un efecto que las usa esta desfasado.
--------------------------------------------------------------------------------
-- Y de pantalla de una coordenada de MUNDO cualquiera. Se separa de
-- player_screen() porque la lluvia la necesita suelta: la linea del suelo se
-- calcula con el Y de mundo del suelo, no con el del personaje en este frame
-- (al saltar, la linea se moveria y las gotas moririan en el aire).
local function mundo_y_a_screen(wy)
  return wy - rw(0xFFA016) + rws(0xFFF566) + 0x20 - 8 + CAL_Y
end

local function player_screen(base)
  return rw(base + OFF_WORLD_LO) - rw(0xFFA014) + 0x80 + CAL_X,
         mundo_y_a_screen(rw(base + OFF_WORLDY_LO))
end

local function to_screen(owner, bx, by)
  local base = owner_base(owner) or P1
  local ax, ay = player_screen(base)
  return ax + (bx - rw(base + OFF_WORLD_LO)),
         ay + (by - rw(base + OFF_WORLDY_LO))
end

--------------------------------------------------------------------------------
-- Dibujo: triangulos y texto con relieve
--------------------------------------------------------------------------------

-- Triangulo relleno de 9 px, centrado en (cx,cy). La fuente de FBNeo no
-- garantiza glifos de flecha, asi que se dibuja a mano.
-- Mide 5 px en el eje hacia el que apunta y 9 en el otro, y siempre nace
-- pegado a un borde: se cornen 2 px para que quede centrado en la caja.
-- Lo usa el menu, para marcar la fila seleccionada.
local function tri(cx, cy, dir, col)
  if dir == "right" then
    cx = cx + 2
  elseif dir == "left" then
    cx = cx - 2
  elseif dir == "down" then
    cy = cy + 2
  else
    cy = cy - 2
  end
  for i = 0, 4 do
    local o = 4 - i
    if dir == "right" then
      gui.drawline(cx - 4 + i, cy - o, cx - 4 + i, cy + o, col)
    elseif dir == "left" then
      gui.drawline(cx + 4 - i, cy - o, cx + 4 - i, cy + o, col)
    elseif dir == "down" then
      gui.drawline(cx - o, cy - 4 + i, cx + o, cy - 4 + i, col)
    else
      gui.drawline(cx - o, cy + 4 - i, cx + o, cy + 4 - i, col)
    end
  end
end

-- El sombreado BLANCO en las 4 diagonales es lo que da el aspecto de 3D. Ese
-- halo solo se ve si el texto NO es blanco puro, asi que esta funcion decide
-- sola: texto de color -> halo blanco; texto blanco -> sombra oscura.
local function hud_text(x, y, s, col)
  local r = math.floor(col / 65536) % 256
  local g = math.floor(col / 256) % 256
  local b = col % 256
  if r > 200 and g > 200 and b > 200 then
    gui.text(x + 1, y + 1, s, color(0x00, 0x00, 0x00, 0xB0))
  else
    gui.text(x - 1, y - 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x + 1, y - 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x - 1, y + 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x + 1, y + 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
  end
  gui.text(x, y, s, col)
end

--------------------------------------------------------------------------------
-- Cajas: SOLO el borde, sin relleno, pero GRUESO.
--
-- Se dibuja con gui.drawline, que si renderiza (la cruz del personaje sale de
-- ahi). Antes se le ponia una pasada negra de 1 px debajo de cada linea para
-- "darle cuerpo" y eso fue un error: sobre fondo oscuro el negro se comia la
-- linea de color y las cajas NO se veian.
--
-- Lo que se hace ahora es ENGORDAR la linea en su propio color, pintandola dos
-- veces con 1 px de separacion en Y. Asi una linea de 1 px pasa a medir 2 px
-- sin taparla con nada, y las cajas se ven sobre cualquier fondo. El grosor
-- son 2 px, no mas: a 3 las cajas de proyectil, que son finas, se cierran.
--------------------------------------------------------------------------------

-- Grosor del borde, en lineas superpuestas.
local GROSOR = 2

local function ln(x1, y1, x2, y2, col)
  local dx, dy = x2 - x1, y2 - y1
  local px = 0
  local py = 1
  if math.abs(dx) > math.abs(dy) then
    px, py = 1, 0
  end
  for i = 0, GROSOR - 1 do
    gui.drawline(x1 + px * i, y1 + py * i, x2 + px * i, y2 + py * i, col)
  end
end

local function draw_box(x1, y1, x2, y2, col, style, corner)
  if x2 - x1 < 0 then x1, x2 = x2, x1 end
  if y2 - y1 < 0 then y1, y2 = y2, y1 end

  if style == "corners" then
    corner = corner or 6
    if x2 - x1 < corner * 2 then corner = math.floor((x2 - x1) / 2) end
    if y2 - y1 < corner * 2 then corner = math.floor((y2 - y1) / 2) end
    ln(x1, y1, x1 + corner, y1, col)
    ln(x1, y1, x1, y1 + corner, col)
    ln(x2, y1, x2 - corner, y1, col)
    ln(x2, y1, x2, y1 + corner, col)
    ln(x1, y2, x1 + corner, y2, col)
    ln(x1, y2, x1, y2 - corner, col)
    ln(x2, y2, x2 - corner, y2, col)
    ln(x2, y2, x2, y2 - corner, col)
    return
  end

  if style == "dashed" then
    local step, on = 4, 2
    local x = x1
    while x <= x2 do
      ln(x, y1, math.min(x + on, x2), y1, col)
      ln(x, y2, math.min(x + on, x2), y2, col)
      x = x + step
    end
    local y = y1
    while y <= y2 do
      ln(x1, y, x1, math.min(y + on, y2), col)
      ln(x2, y, x2, math.min(y + on, y2), col)
      y = y + step
    end
    return
  end

  ln(x1, y1, x2, y1, col)
  ln(x1, y2, x2, y2, col)
  ln(x1, y1, x1, y2, col)
  ln(x2, y1, x2, y2, col)
  if style == "double" and x2 - x1 > 4 and y2 - y1 > 4 then
    ln(x1 + 2, y1 + 2, x2 - 2, y1 + 2, col)
    ln(x1 + 2, y2 - 2, x2 - 2, y2 - 2, col)
    ln(x1 + 2, y1 + 2, x1 + 2, y2 - 2, col)
    ln(x2 - 2, y1 + 2, x2 - 2, y2 - 2, col)
  end
end

--------------------------------------------------------------------------------
-- Snapshot de los contadores
--
-- OJO, esta es la parte que NO hay que romper. El snapshot se sella con
-- frame_id y sin fuente fresca no hay caja.
--
-- NO se mete dentro de ningun condicional de SHOW_*. Leer y dibujar son dos
-- capas separadas: si el snapshot dependiera de que las cajas esten visibles,
-- apagar las cajas se llevaria por delante a la lluvia, que tambien las usa.
-- Ver la nota de AGENTS.md.
--
-- Fuente, en este orden:
--   1) cache del exec hook (momento exacto de la colision)
--   2) write hooks sobre los contadores
--   3) lectura directa (solo sirve si no se limpiaron todavia)
--
-- El builder solo escribe el contador cuando mete una caja (0x1EC84), y
-- $01EDAC lo pone a 0 en los cinco, todos los frames (0x1EDC2..0x1EDDA).
-- O sea que un write por frame SIEMPRE llega. Si no hay write, no hay caja.
--
-- El fallback "raw" de antes leia el contador directo, y ahi se colgaba: en el
-- frame en que el dispatcher se salta el borrado (0x01EDB2, bne $1ee1c) el
-- contador conserva el valor viejo y el builder ya no lo toca, asi que la
-- ultima hitbox/clashbox se quedaba dibujada en el aire.
--------------------------------------------------------------------------------
local function snapshot()
  if exec_stamp == frame_id then
    return counts, "exec"
  end
  if wr_seen and wr_frame == frame_id then
    local u = {}
    for i = 1, #LISTS do
      u[i] = box_count(wr_counts[i], LISTS[i].stride)
    end
    return u, "wr"
  end
  if RAW_FALLBACK then
    local u = {}
    for i = 1, #LISTS do
      u[i] = box_count(rw(LISTS[i].cnt), LISTS[i].stride)
    end
    return u, "raw"
  end

  -- BUG ARREGLADO (la vieja linea 461): esto era una tabla VACIA. Luego
  -- "drawn = drawn + use[i]" hacia nil + numero y reventaba con
  --   "attempt to perform arithmetic on field '?' (a nil value)".
  -- Sin fuente fresca no hay caja, pero la tabla tiene que tener las cinco
  -- entradas o el bucle revienta.
  local u = { 0, 0, 0, 0, 0 }

  -- Si hay contador != 0 sin write, los write hooks estan muertos. Avisar una
  -- sola vez, porque si no disappears todo sin explicar.
  if not raw_warned then
    for i = 1, #LISTS do
      if box_count(rw(LISTS[i].cnt), LISTS[i].stride) > 0 then
        raw_warned = true
        print("[yuyu] AVISO: contador != 0 sin write este frame. "
            .. "Los write hooks de los contadores no estan entrando; "
            .. "poner RAW_FALLBACK = true para ver, pero el bug de la caja "
            .. "colgada vuelve.")
        break
      end
    end
  end
  return u, "stale"
end

--------------------------------------------------------------------------------
-- Rectangulos de UNA lista, ya en pantalla.
--
-- NO mira L.on() a proposito: la lluvia necesita las hurtbox aunque las cajas
-- esten apagadas. Leer no depende de dibujar. Es la trampa de AGENTS.md.
--
-- EXCEPTO el grab. El descriptor de grab es un caso raro: el marcador de rango
-- se construye a partir de una CAPTURA con estado (grab_mem), no de la caja en
-- si, y esa captura se llenaba como efecto secundario del dibujo. Si el
-- calculo de rectangulos se charge de eso, entonces apagar el grab deja la
-- cache viva y el marcador se queda colgado. Por eso el grab tiene su propia
-- funcion de lectura, sin estado, y rects_de() no lo toca.
--
-- Cada rectangulo sale como { x1, y1, x2, y2 }. Con un radio en 0 se dibuja
-- como 1 px, igual que en el dibujo.
--------------------------------------------------------------------------------
local function rects_de(idx, use)
  local out = {}
  local L = LISTS[idx]
  local filtro = owner_filter()
  -- "or 0" por si falta alguna entrada: el conteo nunca puede ser nil.
  local n = (use[idx]) or 0
  for k = 0, n - 1 do
    local a = L.base + k * L.stride
    local owner = rw(a + 0x0C)
    local ob = owner_base(owner)
    if (not filtro) or own_lo(owner) == filtro then
      local bx = rws(a + 0x00)
      local by = rws(a + 0x04)
      -- Radio con el bit 7 reservado como terminador, por eso el band.
      local rx = bit.band(rb(a + 0x08), 0x7F)
      local ry = rb(a + 0x09)
      -- OJO: el filtro tiene que ser OR, no AND. Muchas hitboxes de
      -- proyectil tienen un radio en 0 (son finas, tipo linea o rayo), y con
      -- AND nunca se dibujaban.
      if rx > 0 or ry > 0 then
        local ex = rx > 0 and rx or 1
        local ey = ry > 0 and ry or 1
        local sx, sy = to_screen(ob or owner, bx, by)
        out[#out + 1] = { x1 = sx - ex, y1 = sy - ey,
                          x2 = sx + ex, y2 = sy + ey }
      end
    end
  end
  return out
end

-- Las cajas de GRAB, con su propio camino.
--
-- El grab NO pasa por rects_de() por lo que se explica arriba: la captura con
-- estado (grab_mem) es del marcador de rango, no del dibujo de la caja. Aqui se
-- leen los descriptores y se convierten a pantalla, sin tocar la cache.
local function rects_grab(use)
  local out = {}
  local idx = indice_de("grab")
  local n = (use[idx]) or 0
  local L = LISTS[idx]
  for k = 0, n - 1 do
    local a = L.base + k * L.stride
    local ob = owner_base(rw(a + 0x0C))
    if ob then
      local ex = rb(a + 0x04)
      local ey = rb(a + 0x05)
      if ex > 0 or ey > 0 then
        if ex == 0 then ex = 1 end
        if ey == 0 then ey = 1 end
        local sx, sy = to_screen(ob, rws(a + 0x00), rws(a + 0x02))
        out[#out + 1] = { x1 = sx - ex, y1 = sy - ey, x2 = sx + ex, y2 = sy + ey }
      end
    end
  end
  return out
end

-- Las cinco listas en una sola pasada. Se calculan TODAS aunque esten apagadas:
-- la lluvia lee la de hurtbox con las cajas apagadas.
local function rects_del_frame(use)
  local r = {}
  for i = 1, #LISTS do
    if LISTS[i].name == "grab" then
      r[i] = rects_grab(use)
    else
      r[i] = rects_de(i, use)
    end
  end
  return r
end

--------------------------------------------------------------------------------
-- Dibujo de las cajas, desde los rectangulos ya calculados
--------------------------------------------------------------------------------
local function draw_boxes(use, rects, src)
  local drawn = 0
  for i = 1, #LISTS do
    local L = LISTS[i]
    if L.on() then
      local rs = rects[i]
      for j = 1, #rs do
        local r = rs[j]
        draw_box(r.x1, r.y1, r.x2, r.y2, L.line, L.style)
        drawn = drawn + 1
      end
    end
  end

  -- El LATIDO vivia ACA y se movio a `un_frame`, DESPUES de `draw_lluvia`. Motivo:
  -- `draw_boxes` corre ANTES que `draw_lluvia`, y `gotas_dibujadas` lo pone en cero
  -- al entrar. O sea que la linea decia el conteo del frame ANTERIOR: un frame de
  -- retraso, invisible en regimen permanente, pero justo lo que no se puede ver en
  -- un cambio de fase, que dura un frame. El latido va donde ya se sabe que todo lo
  -- que imprime es de ESTE frame.
  --
  -- Solo se devuelve el numero de cajas: el resto de los datos de la sonda los
  -- necesita `un_frame`, que es quien tiene `use` y `src`.
  return drawn
end

--------------------------------------------------------------------------------
-- Grab fijo: rango de agarre siempre visible, siguiendo al personaje
--
-- Se dibuja con los offsets memorizados de la ultima caja REAL. El signo del
-- offset en X se recalcula cada frame con el facing, igual que hace el builder
-- ("addi.w #$10" si facing == 0, "subi.w #$10" si no), asi que el marcador se
-- da vuelta cuando el personaje cambia de lado.
--
-- La BASE del recuadro va a la altura de la linea horizontal de la cruz, que
-- es donde estan los pies: se ancla por abajo, no por el centro.
--------------------------------------------------------------------------------
-- El descriptor de grab de ESTE frame, leido de la lista, sin usar la cache.
-- Es el respaldo: si la captura de arriba no ha guardado nada todavia, con
-- esto el rango se ve igual en el frame en que hay agarre de verdad.
local function grab_live()
  local cnt = box_count(rw(0xFFA00C), 0x20)
  for k = 0, cnt - 1 do
    local a = 0xFFA600 + k * 0x20
    if owner_base(rw(a + 0x0C)) == P1 then
      -- Offset con LECTURAS SIN SIGNO en los dos lados: con rws en uno y rw en
      -- el otro, si la palabra tiene el bit 15 activo la resta sale corrida
      -- en 65536.
      return {
        dxm = rw(a + 0x00) - rw(P1 + OFF_WORLD_LO),
        dy  = rws(a + 0x02) - rws(P1 + OFF_WORLDY_LO),
        rx  = rb(a + 0x04),
        ry  = rb(a + 0x05),
      }
    end
  end
  return nil
end

local function draw_grab_range()
  local L = list_by("grab")
  if not (L and L.on()) then
    -- Apagado: se VACIA la cache. Sin esto, grab_mem sobrevive al flag apagado
    -- y el marcador se queda dibujado para siempre, con el offset congelado en
    -- la posicion en que se capturo.
    for k in pairs(grab_mem) do grab_mem[k] = nil end
    return
  end

  -- La captura se hace AQUI y no en rects_grab(), porque es un efecto del
  -- marcador de rango, no del dibujo de la caja: solo tiene sentido si el grab
  -- esta encendido. Y es de una sola vez por personaje (ver abajo).
  local cnt = box_count(rw(0xFFA00C), 0x20)
  for k = 0, cnt - 1 do
    local a = 0xFFA600 + k * 0x20
    local ob = owner_base(rw(a + 0x0C))
    if ob then
      local ex, ey = rb(a + 0x04), rb(a + 0x05)
      local key = moves_key(ob)
      if not grab_mem[key] then
        -- Offset con LECTURAS SIN SIGNO en los dos lados: con rws en uno y rw en
        -- el otro, si la palabra tiene el bit 15 activo la resta sale corrida en
        -- 65536.
        local dxm = math.abs(rw(a + 0x00) - rw(ob + OFF_WORLD_LO))
        local dy  = rw(a + 0x02) - rw(ob + OFF_WORLDY_LO)
        -- VALIDACION: si lo leido se sale del rango de los tres builders es que
        -- se agarro el descriptor a medio escribir. Como la captura es de una
        -- sola vez, guardar basura deja el marcador fuera de pantalla para
        -- siempre.
        -- Filtro RELAJADO: antes descartaba casi todo y el marcador no se veia
        -- nunca. Solo se descarta lo que de verdad no puede ser una caja: un
        -- offset absurdo o un radio de mas de 64 px.
        if dxm <= 128 and dy >= -160 and dy <= 96 and ex <= 64 and ey <= 64 then
          grab_mem[key] = { dxm = dxm, dy = dy,
                            rx = ex > 0 and ex or 1,
                            ry = ey > 0 and ey or 1 }
        else
          if not raw_warned then
            raw_warned = true
            print(string.format(
              "[yuyu] grab: captura descartada (dxm=%d dy=%d %dx%d)",
              dxm, dy, ex, ey))
          end
        end
      end
    end
  end

  -- Primero la cache (estable, no tiembla) y si no hay nada, el de este frame.
  -- Antes solo miraba la cache, y como grab_mem arranca vacia y solo se llena
  -- cuando una captura pasa el filtro, el rango NO SE VIA NUNCA si la
  -- captura no colaba a la primera.
  local m = grab_mem[moves_key(P1)] or grab_live()
  if not m then return end

  local ax, ay = player_screen(P1)
  local dx = m.dxm + GRAB_X_FIX
  if rb(P1 + OFF_FACING) ~= 0 then dx = -dx end
  local sx = ax + dx
  local sy = ay + (m.dy or 0)
  local top = sy - m.ry * 2

  draw_box(sx - m.rx, top, sx + m.rx, sy, L.line, "dashed", 4)
  hud_text(sx + m.rx + 3, sy - 4,
           string.format("grab %d %dx%d", dx, m.rx * 2, m.ry * 2),
           color(0xFF, 0x00, 0xFF, 0xFF))
end


--------------------------------------------------------------------------------
-- GEOMETRIA DE LA VENTANA: MARGENES DE BORDE NEGRO
--
-- EL OVERLAY NO DIBUJA EN EL ESPACIO DEL JUEGO, SINO EN EL DE LA VENTANA. Son
-- distintos cuando la ventana no tiene la misma proporcion que el juego.
--
-- El juego es 320x224 (proporcion 1.4286). Una ventana 4:3 tiene 1.3333. Al
-- ajustar el juego por el ANCHO, la imagen queda a 880x616 dentro de 880x658 y
-- sobran unos 21 px de borde negro ARRIBA y ABAJO. El overlay cubre los 658
-- completos, asi que la fila 0 del overlay esta en el borde negro, no en la
-- primera linea del juego.
--
-- Eso explica las dos cosas que se vieron a la vez en la primera medicion:
--
--   - El eje X salia bien porque al ajustar por el ancho NO sobra nada a los
--     lados: el juego llena el ancho de la ventana y ox = 0.
--   - El eje Y salia corrido porque si sobraba borde arriba: un y1 = 1 caia en
--     la franja negra, y el borde inferior del panel quedaba 21 px mas abajo de
--     donde deberia. Por eso "sobresal por arriba" y "la foto no estaba
--     abarcada" eran el MISMO error, en dos bordes opuestos.
--
-- Y explica tambien el borde de C.Rain: con ALTO_JUEGO = 224 fijo, la gota
-- moria en la fila 224 del overlay, que con 21 px de margen esta DENTRO de la
-- imagen y no en el borde. Al sumar oy, la linea de muerte cae en la ultima
-- fila real del juego para cualquier ventana.
--
-- SE CALCULA, NO SE SUPONE. Asi el mismo script sirve con cualquier relacion de
-- aspecto y cualquier resolucion: si no hay borde (ventana con la proporcion
-- del juego), ox y oy dan 0 y no cambia nada.
local ANCHO_JUEGO, ALTO_JUEGO = 320, 224

-- Centro de la imagen del juego dentro de la ventana. Se Asume que el emulador
-- centra: si dejara el borde solo en un lado habria que sumar distinto, pero en
-- las capturas medidas el borde reparte parejo.
local function margen_juego()
  local sw, sh = emu.screenwidth(), emu.screenheight()
  local ox = (sw - ANCHO_JUEGO) / 2
  local oy = (sh - ALTO_JUEGO) / 2
  -- Un borde negativo significaria que la ventana es mas pequena que el juego:
  -- en ese caso no hay margen, se dibuja a pelo desde 0.
  if ox < 0 then ox = 0 end
  if oy < 0 then oy = 0 end
  return math.floor(ox), math.floor(oy)
end

-- ULTIMA FILA DE LA IMAGEN DEL JUEGO: 223.
--
-- NO es la linea de muerte de C.Rain, solo el TECHO por arriba de donde puede morir
-- una gota. Sirve para dos cosas: que ninguna gota se dibuje nunca en el borde
-- negro, y que el recorte del HUD tenga un limite.
--
-- La linea de muerte de verdad esta en linea_de_suelo(): sigue al SUELO del stage,
-- que cambia con cada stage y con el scroll de la camara. Un numero fijo aqui no
-- servia: con 223 las gotas se perdian en las filas negras de debajo del suelo, y
-- con 211 quedaban bien en un stage y mal en el siguiente.
local ULTIMA_FILA = ALTO_JUEGO - 1

-- Filas de ventaja de C.Rain por delante del suelo del stage. Es la capa cercana,
-- asi que cae un poco mas alla de la linea del suelo en vez de morir en ella.
-- Con 0 muere exactamente en el suelo, como la pesada.
local ABAJO_OFF = 8

-- ALTURA DE NACIMIENTO DE LAS GOTAS.
--
-- Fila de JUEGO donde nace una gota nueva. MEDIDA: se dibujo una linea cyan de
-- 160 px sobre la pantalla y se confirmo que y = 10 era la correcta.
--
-- Es el MISMO valor para las tres capas a proposito. Antes cada gota nacia a una
-- altura distinta segun su indice i, lo que ataba la Y al mismo i que la X y hacia
-- que las capas formaran una diagonal en vez de mezclarse.
--
-- Va aqui y no junto a la lluvia porque el bloque de medicion, que esta mas arriba en
-- el fichero, la dibuja. En Lua un local declarado mas abajo es un nil global en
-- el punto de uso.
local SPAWN_Y = 10

-- Franja hacia abajo donde cae el punto de partida de cada gota.
--
-- NO puede ser 0: con la misma velocidad, gotas que nacen en la misma fila caen en
-- paralelo y mueren TODAS en el mismo frame, y la lluvia se ve a pulsos en vez de
-- correr. Con la franja, todas parecen salir del mismo punto de la parte alta pero
-- siguen voladas separadas y se apagan por turnos, que es como se ve una lluvia
-- de verdad.
local SPAWN_BANDA = 40

-- De coordenada de JUEGO a coordenada de OVERLAY. Todo lo que se posicione en
-- pixeles del juego (el HUD, el suelo, la linea de muerte) tiene que pasar por
-- aqui, o se va aCELL varias filas con el borde negro puesto.
local function de_juego(x, y)
  local ox, oy = margen_juego()
  return x + ox, y + oy
end

--------------------------------------------------------------------------------
-- ZONAS FIJAS DEL HUD  (MEDICION, NO VERIFICADO CONTRA EL ROM)
--
-- Los recuadros del HUD del juego (cara, barras de HP/MP, nombre, "1P"/"2P") NO
-- estan en ninguna lista de colisiones: son tiles y sprites que dibuja el juego
-- con el VDP. No hay ningun campo de memoria con esas coordenadas, asi que no se
-- pueden leer: hay que fijarlas a mano.
--
-- Que sea fijo es lo que lo hace posible. No se mueven con la camara, ocupan
-- siempre el mismo sitio y son (con "PAUSA" y el menu del juego) los unicos
-- elementos fijos del juego.
--
-- COORDENADAS EN PIXELES DE JUEGO (0..320, 0..224), no de ventana. El margen lo
-- pone de_juego() al dibujar, con lo que estas medidas no cambian al cambiar la
-- ventana.
--
-- MEDIDO sobre capturas de 880x658 con los nombres mas anchos ("Younger Toguro"
-- y "Elder Toguro", que parten en dos lineas) y despues con nombres cortos
-- ("Yasuke" y "Sensui"), para confirmar que el ancho del panel no depende del
--
-- de cortar en seco.
--
-- LO QUE HACE ESTE BLOQUE: dibuja los rectangulos encima para comprobar que
-- encuadran bien. NO esconden nada todavia. Cuando las coordenadas esten
-- confirmadas, este bloque se borra y queda solo la tabla HUD_ZONAS, que despues
-- usara el recorte de las gotas.
--------------------------------------------------------------------------------
-- AJUSTE MANUAL en dos rondas, el usuario los pidio sobre capturas suyas:
--   1) bajar 6 filas el borde superior de los dos marcos: y1 de 8 a 14
--   2),X: P1 x1 de 37 a 39 (+2, hacia la derecha) y x2 de 137 a 136 (-1);
--      P2 x2 de 285 a 281 (-4). El x1 del P2 no se toco.
--
-- Sigue SIN aplicado el efecto de ocultamiento: los rectangulos solo se dibujan.

local HUD_ZONAS = {
  { x1 =  39, y1 = 14, x2 = 136, y2 = 45 },   -- panel del P1
  { x1 = 183, y1 = 14, x2 = 281, y2 = 45 },   -- panel del P2
}
-- Ultima linea de muerte de C.Rain que se ha calculado. La guarda update_lluvia y
-- la lee el bloque de medicion de abajo, que se dibuja ANTES que update_lluvia en
-- el mismo frame: lo que muestra es el dato del frame anterior, que a 60 Hz es
-- indistinguible. Va declarado aqui y no junto a update_lluvia porque Lua solo ve
-- los locals declarados ANTES: mas abajo seria un global nil.
local linea_muerte_crain = ULTIMA_FILA

-- GUIAS DE MEDICION, y el flag que las controla.
--
-- Lo que dibuja medir_hud(), TODO junto:
--   marco AMARILLO   los bordes reales de la imagen del juego dentro de la ventana
--   linea MAGENTA    donde muere C.Rain (suelo + ABAJO_OFF)
--   CYAN             y = 0, y = SPAWN_Y, y una rayita cada 32 filas de juego
--   rayitas GRISES   escala de la ventana, cada 16 px (larga cada 64)
--
-- Los dos rectangulos del HUD NO estan: son zona de no-dibujado de verdad y los
-- usa zona_tapa(), no se dibujan.
--
-- Va declarado AQUI y no junto a medir_hud() porque el menu, que esta mas abajo,
-- lo usa en DEFAULTS y en su bool_item: en Lua un local declarado mas abajo
-- seria un global nil en el punto de uso.
--
-- APAGADO DE FABRICA, que es lo que corresponde a unas guias de medicion: no tienen
-- por que estar molestando cuando ya se termino el ajuste. Se encienden desde el
-- menu con la opcion "G.LINE", que sigue ahi justamente para eso.
--
-- Estuvieron encendidas de fabrica mientras se ajustaron las zonas del HUD y el
-- margen de la ventana. Lo que se guarda NO es el estado de las guias, sino el
-- calculo del margen y el de las zonas: zona_tapa() y de_juego() no dependen de
-- esta variable, asi que apagar las guias no cambia NI UN PIXEL de la lluvia.
local GUIAS = false

-- PRIMERA FILA POR LA QUE UNA GOTA SI PUEDE DIBUJARSE, O NIL SI NINGUNA ZONA LA
-- TAPA.
--
-- Es para los recuadros FIJOS del HUD (cara, barras, nombre). No estan en ninguna
-- lista de colisiones, asi que no hay hurtbox que los tapara: son medidas fijas,
-- tomadas sobre capturas del usuario.
--
-- Aplica a LAS TRES CAPAS. OJO con no confundirlo con el otro ocultamiento: la
-- hurtbox (p.oculta) es POR CAPA y solo B.Rain la usa. Esta es aparte y es para
-- todas, porque el HUD esta en el techo y le cae encima a quien le quiera.
--
-- Se comparan las tres cosas: solape en X, y que la gota este dentro de la banda
-- vertical. Si solapan en X pero la gota ya paso la zona, no hay nada que tapar:
-- por eso se mira tambien que la punta llegue a entrar en la banda.
--
-- Con dos zonas que no se pisan, devuelve la mas baja de las que apliquen. Asi el
-- recorte no depende del orden en que se recorran.
local function zona_tapa(p, d)
  -- La gota NO es una sola recta: si grosor = 2 se dibujan DOS, la misma a 1 px
  -- de lado. El recorte tiene que mirar el ancho que se dibuja de verdad, no solo
  -- la diagonal, o la segunda recta se cuela 1 px por el borde de la zona y
  -- dibuja un pixel ENCIMA del panel.
  --
  -- Las dos rectas van de (xa, ...) a (xa + dx, ...), y la copia desplazada
  -- termina 1 px mas a la derecha. O sea el ancho real es [min, max + grosor - 1].
  local xa = math.floor(p.x)
  local xb = xa + d.dx
  local x1 = (xa < xb) and xa or xb
  local x2 = (xa > xb) and xa or xb
  x2 = x2 + d.grosor - 1
  local y_base = nil
  for i = 1, #HUD_ZONAS do
    local z = HUD_ZONAS[i]
    -- Solapa en X?
    if x2 >= z.x1 and x1 <= z.x2 then
      -- Y esta rozando la banda vertical de la zona?
      --
      -- Las dos comparaciones van con math.floor() porque lo que se dibuja son
      -- FILAS enteras, no la posicion flotante. Sin el floor, una gota con el
      -- tope en 45,5 no cumplia "p.y <= 45" y escapaba del recorte, con el pixel
      -- de la fila 45 dibujado encima del panel.
      if math.floor(p.y + p.largo) >= z.y1 and math.floor(p.y) <= z.y2 then
        -- OJO el +1: z.y2 es la ULTIMA fila del panel, y esa fila tambien esta
        -- tapada (es su borde inferior). Si se devuelve z.y2 tal cual, la punta
        -- de la gota queda dibujada ENCIMA del borde del panel, que es
        -- justamente el pixel que no tiene que verse.
        if not y_base or z.y2 + 1 > y_base then y_base = z.y2 + 1 end
      end
    end
  end
  return y_base
end

-- GUIAS DE MEDICION. Van en el espacio de la VENTANA, que es donde se dibuja:
-- las coordenadas de JUEGO entran por de_juego().
--
-- Los dos rectangulos del HUD NO se dibujan: son zona de no-dibujado de verdad y
-- los usa zona_tapa(). Lo que queda abajo es de medicion y es de otro tema.
local function medir_hud()
  if not GUIAS then return end

  -- Referencia de ESCALA, de la ventana. Una marca cada 16 px de overlay, larga
  -- cada 64. Sirve para leer cuantos pixeles de captura vale uno de ventana, y
  -- de ahi el factor contra el juego. Se dibuja aparte de las zonas porque mide
  -- la ventana, no el juego.
  --
  -- SIN TEXTO a proposito: el autotest comprueba que con el menu cerrado no sale
  -- NINGUN texto que no sea el marcador de grab, y un texto aqui haria fallar esa
  -- prueba por algo que es temporal. Las medidas van en la consola.
  local gris = color(0xFF, 0xFF, 0xFF, 0x40)
  local sw, sh = emu.screenwidth(), emu.screenheight()
  for y = 16, sh - 1, 16 do
    if y % 64 == 0 then
      gui.drawline(0, y, 11, y, gris)          -- cada 64: raya larga
    else
      gui.drawline(0, y, 5, y, gris)
    end
  end
  for x = 16, sw - 1, 16 do
    if x % 64 == 0 then
      gui.drawline(x, 0, x, 11, gris)
    else
      gui.drawline(x, 0, x, 5, gris)
    end
  end

  -- Y los bordes REALES de la imagen del juego, en el color del marco. Con esto
  -- se ve de un vistazo si el calculo del margen es el correcto: si la linea
  -- amarilla no cae pegada al borde negro, el margen esta mal.
  local ox, oy = margen_juego()
  local amarillo = color(0xFF, 0xFF, 0x00, 0xFF)
  gui.drawline(ox, oy, ox + ANCHO_JUEGO - 1, oy, amarillo)                    -- arriba
  gui.drawline(ox, oy + ALTO_JUEGO - 1, ox + ANCHO_JUEGO - 1,
               oy + ALTO_JUEGO - 1, amarillo)                                  -- abajo
  gui.drawline(ox, oy, ox, oy + ALTO_JUEGO - 1, amarillo)                      -- izq
  gui.drawline(ox + ANCHO_JUEGO - 1, oy,
               ox + ANCHO_JUEGO - 1, oy + ALTO_JUEGO - 1, amarillo)            -- der
  -- LA LINEA DE MUERTE DE C.RAIN, en MAGENTA, y otra 16 filas mas arriba en un
  -- segmento corto. Es lo que hay que mirar: si la magenta cae por DEBAJO de
  -- donde termina el suelo del stage, ULTIMA_FILA esta demasiado alta.
  --
  -- Son dos preguntas distintas y no se deben mezclar:
  --   el marco AMARILLO  dice donde acaba la IMAGEN del juego (fila 223)
  --   la linea MAGENTA   dice donde muere la GOTA
  -- Coinciden solo si el suelo del stage llega al fondo de la imagen, y no es el
  -- caso: debajo del suelo hay filas negras DENTRO de la imagen del juego.
  local magenta = color(0xFF, 0x00, 0xFF, 0xFF)
  local mx, my = de_juego(0, linea_muerte_crain)
  gui.drawline(mx, my, mx + ANCHO_JUEGO - 1, my, magenta)
  local mx2, my2 = de_juego(0, ULTIMA_FILA - 16)
  gui.drawline(mx2, my2, mx2 + 30, my2, magenta)

  -- GUIAS DE MEDICION, en CYAN. Coordenadas de JUEGO: x de 0 a 319, y de 0 a 223.
  --
  --   CYAN completo    y = 0      el techo de la imagen del juego
  --   CYAN completo    y = SPAWN_Y   donde NACEN las gotas de verdad
  --   rayitas cada 32 filas      una larga cada 64, margen izquierdo
  --
  -- Con la rayita larga de 64 y la cyan se lee cualquier fila a ojo.
  local cyan = color(0x00, 0xFF, 0xFF, 0xFF)

  local sx, sy = de_juego(0, 0)
  gui.drawline(sx, sy, sx + ANCHO_JUEGO - 1, sy, cyan)

  -- La linea de spawn, de ancho completo. Va en SPAWN_Y, que es donde nacen las
  -- gotas de verdad (ver sembrar_una).
  local sx2, sy2 = de_juego(0, SPAWN_Y)
  gui.drawline(sx2, sy2, sx2 + ANCHO_JUEGO - 1, sy2, cyan)

  -- Escala vertical: una marca cada 32 filas de JUEGO, en el margen izquierdo.
  for r = 0, ULTIMA_FILA, 32 do
    local rx, ry = de_juego(0, r)
    if r % 64 == 0 then
      gui.drawline(rx, ry, rx + 17, ry, cyan)      -- cada 64: larga
    else
      gui.drawline(rx, ry, rx + 8, ry, cyan)
    end
  end

end

--------------------------------------------------------------------------------
-- LLUVIA
--
-- Tres capas con reglas distintas, para dar profundidad. Todas las medidas en
-- pixeles de la pantalla del JUEGO (320x224), nunca de la ventana: el emulador
-- escala y un valor medido en una captura saldria mal en cualquier otro tamano.
--
--   1 PESADA  "H.Rain"  2 px, translucida. Colisiona con la hurtbox: salpica y
--                        muere al tocar a un personaje o el suelo.
--   2 FONDO   "B.Rain"  1 px, solida. NO colisiona: se OCULTA al entrar en una
--                        hurtbox y reaparece al salir. Muere en el suelo del
--                        plano del fondo, sin salpicar. PARPADEA.
--   3 CERCA   "C.Rain"  1 px, opaca. No colisiona con nada, se dibuja siempre
--                        encima de los personajes y se pierde por abajo.
--
-- DURACIONES: en frames de 60 Hz. La velocidad sale de dividir el recorrido por
-- esos frames. B.Rain es ahora la MAS LENTA (1,10 s) y C.Rain la mas rapida (0,45 s).
-- Subir la velocidad es cambiar .dur, y OJO: el `dur` NO es el tiempo en pantalla, es
-- la velocidad nominal. Ver TECHOS_DE_LLUVIA mas abajo.
--
-- INCLINACION: LAS TRES VAN RECTAS, con dx = 0. Ninguna tiene inclinacion.
--
-- La historia: las tres iban con dx = -1, pero con 1 px de desplazamiento sobre 3, 5,
-- 6 o 7 filas la inclinacion es tan poco que el redondeo la hacia retorcerse y se
-- leia como una "S" que se movia. Se fueron poniendo rectas una a medida que se
-- pidió: primero C.Rain, despues B.Rain y por ultimo H.Rain.
--
-- QUE SE PIERDE Y QUE NO AL PONERLAS RECTAS. Antes se decia que H.Rain conservaba la
-- inclinacion a proposito para no perder el paralaje. Con las tres rectas ya NO hay
-- paralaje por inclinacion. Lo que queda dando profundidad es lo de verdad:
--
--   velocidad     0,45 / 0,65 / 1,10 s. Es lo mas notorio de lejos
--   altura         3, 4 y 6 px en la cercana; 6 y 9 en la de fondo; 7 en la pesada
--   grosor         2 px solo en la pesada
--   opacidad       alfa 0x99 solo en la pesada: es la unica translucida
--   parpadeo       solo la de fondo
--   densidad       16 / 22 / 14 gotas
--
-- Si alguna vez hay que devolver la sensacion de caida diagonal, el sitio no es el
-- `dx` sino la combinacion de velocidad y altura.
--
-- Con dx = 0 no hay que tocar NADA mas: la muerte y la banda vertical del recorte
-- del HUD no usan dx, y la punta de la recta se recalcula con p.x + dx * frac, que
-- con dx = 0 es p.x en los dos extremos, o sea vertical exacta.
--
-- CONTRADICCION EN LA ESPECIFICACION, RESUELTA ASI: se pidio que la de fondo
-- fuera "el doble de rapida" que la pesada Y que durara 2 segundos. No puede
-- ser las dos: el doble de rapida sobre 1,5 s son 0,75 s. Mandan los segundos,
-- con lo que la de fondo queda como la MAS LENTA, que ademas es lo que
-- corresponde a una capa de fondo con paralaje. Para ponerla al doble de
-- velocidad: LLUVIA_DEF[2].dur de 120 a 45.
--
-- ALPHA: las gotas se dibujan con gui.drawline y NO con gui.box. En este build
-- hay una contradiccion sin resolver sobre si gui.box respeta el alfa del
-- relleno (el comentario de LISTS dice que lo ignora y pinta opaco, pero el
-- panel del HALL OF FAME se ve mezclar). Con drawline no hace falta resolverla:
-- si el alfa saliera opaco, el arreglo es aclarar el color.
--
-- POOL FIJO, no contador: las gotas ya estan todas creadas y solo se marcan
-- vivas o muertas. El tope es automatico (no hay mas que n), no hay que crear
-- tablas en cada renovacion y el reset es poner todas a false.
--------------------------------------------------------------------------------
-- Los colores van con color(), NUNCA en hexadecimal a mano: el motor lee
-- 0xRRGGBBAA y un 0xAARRGGBB escrito a mano sale de otro color, sin avisar.
-- LARGO POR GOTA, opcional: si una capa tiene el campo `largos`, cada gota toma
-- el suyo por indice y el `largo` de la capa pasa a ser solo el valor por
-- defecto. Sin ese campo todas las gotas de la capa usan el mismo largo, que es
-- lo que hace H.Rain, la unica que lo sigue teniendo.
--
-- EN LAS CAPAS QUE MEZCLAN la lista esta MEZCLADA A PROPOSITO. El indice i de la
-- gota es lo que reparte la X (ver sembrar_una: p.x = (i - 0.5) * paso_x), asi que
-- poner los largos en orden (3,3,3,3,3,3,5,5,5,5,7,7,7) haria que las 6 gotas
-- cortas estuvieran siempre en el mismo tercio de la pantalla, y eso se ve como
-- tres franjas verticales de lluvia. Intercalados, cada banda de X tiene de todos
-- los tamanos y la mezcla sale pareja de verdad.
--
-- El reparto sale de juntar las series por su posicion proporcional
-- ((k + 0,5) / cantidad de cada una), que reparte los slots casi a 1/n uno.
--
-- OJO con una consecuencia de mezclar altos que no es de dibujado: la muerte es
-- `p.y + p.largo >= linea`, o sea decide CUANDO la punta llega al suelo. Una gota
-- de 4 px viaja por eso un par de pixeles MAS que una de 6 antes de morir, porque
-- su punta esta mas arriba. El valor `suelo` y `FONDO_PISO_OFF` no se tocan para
-- nada: la diferencia es inherente a que las gotas tengan distinta altura.
local LLUVIA_DEF = {
  -- 14 gotas de 7 px, dx = 0: RECTA, como las otras dos. grosor = 2, que es lo que
  -- la hace "agua de mayor volumen" y la que splasca al chocar. dur = 39, o sea
  -- 0,65 s.
  --
  -- QUE EL GROSOR SOBRE AL PONERLA RECTA: el grosor NO es una linea mas gruesa, es
  -- la MISMA recta dibujada dos veces, la segunda a 1 px de lado. Con dx = 0 las dos
  -- quedan verticales en columnas contiguas, o sea que sigue midiendo 2 px de ancho.
  -- Por eso ponerla recta no le quita nada de volumen.
  --
  -- dur = 39, o sea 0,65 s. Venia en 54 (0,90 s): la DURACION baja un 28 % y la
  -- VELOCIDAD sube un 38 %, porque es linea / dur y no al reves. Sigue siendo la capa
  -- lenta, pero mucho menos: el salto de 0,90 a 0,65 tambien la deja por debajo del
  -- techo de traza continua (ver la nota de TECHOS_DE_LLUVIA).
  { et = "H.Rain", n = 14, largo = 7, dx = 0, grosor = 2,
    col = color(0xA8, 0xC8, 0xE8, 0x99), dur = 39, suelo = "frente", choca = true,  oculta = false },
  -- 22 gotas: 11 de 6 px y 11 de 9 px, todas de 1 px de grosor. dx = 0: RECTA,
  -- como C.Rain. El reparto sale solo, alternado: con dos series de la misma
  -- cantidad, la posicion proporcional de las dos coincide en cada slot
  -- (0,1 / 0,3 / 0,5 / 0,7 / 0,9) y el desempate va a la primera.
  -- El suelo y FONDO_PISO_OFF NO se tocaron.
  --
  -- Los dos altos suben (4 -> 6 y 6 -> 9) porque la velocidad tambien sube: ver
  -- TECHOS_DE_LLUVIA. Con 4 px y 9 px la de fondo se leia como un raya de puntos.
  --
  -- dur = 66, o sea 1,10 s. Venia en 84 (1,40 s): la DURACION baja un 21 % y la
  -- VELOCIDAD sube un 27 %. Sigue siendo la MAS LENTA de las tres.
  --
  -- EL STOCK SIGUE SIENDO EL DOBLE DE LO QUE SE VE, y eso es a proposito: `parpadeo`
  -- oculta medio grupo cada frame (ver PARPADEO_FRAMES), asi que en cualquier
  -- instante se dibujan 11 de las 22. Las 11 ocultas siguen cayendo y muriendose
  -- igual.
  --
  -- Se subio de 20 a 22 junto con la velocidad, no por el salto horizontal: con el
  -- parpadeo lo que se ve es una de cada dos ranuras, y el paso paso de 16 a 14,5 px,
  -- o sea que el espacio entre las dibujadas baja de 32 a 29 px. Cambio chico.
  { et = "B.Rain", n = 22, largo = 6, dx = 0, grosor = 1,
    largos = { 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9, 6, 9 },
    parpadeo = true,
    col = color(0xA8, 0xC4, 0xE0, 0xFF), dur = 66, suelo = "fondo",  choca = false, oculta = true },
  -- 16 gotas: 7 de 3 px, 5 de 4 px y 4 de 6 px. Todas de 1 px de grosor, que es
  -- lo que hace el campo `grosor` de la capa, y las tres recorre lo mismo.
  -- dx = 0: RECTA, totalmente vertical (ver la nota de INCLINACION arriba).
  --
  -- Los dos altos mas largos BAJAN (5 -> 4 y 7 -> 6) mientras la duracion tambien
  -- baja, y las dos cosas van en el mismo sentido: subir la velocidad sin achicar
  -- las gotas las convierte en guiones. Con 3 px y dur 27 la gota avanza 2,3 veces
  -- su propia longitud por frame; antes eran 1,85. Ver TECHOS_DE_LLUVIA.
  --
  -- dur = 27, o sea 0,45 s. Venia en 33 (0,55 s): la DURACION baja un 18 % y la
  -- VELOCIDAD sube un 22 %.
  --
  -- OJO al pensar en porcentajes: la DURACION y la VELOCIDAD son dos numeros
  -- distintos para lo mismo, y van al reves, porque es linea / dur.
  { et = "C.Rain", n = 16, largo = 4, dx = 0, grosor = 1,
    largos = { 3, 4, 3, 6, 3, 4, 6, 3, 4, 3, 6, 4, 3, 6, 4, 3 },
    col = color(0x6E, 0x9C, 0xD8, 0xFF), dur = 27, suelo = "abajo",  choca = false, oculta = false },
}

-- TECHOS_DE_LLUVIA: hasta donde se puede subir la velocidad de cada capa
--
-- NO es una cuestion de gusto y no es un dato del juego: sale de la cuenta de la
-- simulacion, y es lo que impide subir las tres capas por el mismo factor.
--
--     v = linea / dur                     pixeles por frame
--     una gota de `largo` px dibujada en frames seguidos se lee como TRAZA continua
--     solo si el paso por frame no supera su propia longitud: con v = largo los
--     segmentos se tocan justo, y con v = 2 * largo queda un hueco de largo - 1 y
--     se lee como guiones.
--
-- O sea el limite es  v <= largo,  o sea  dur >= linea / largo.  Y hay que cumplirlo
-- para el alto MAS CORTO de la capa, que es el que manda.
--
-- `linea` sale del suelo del stage, que `suelo_frontal()` clampa entre
-- SUELO_MIN (175) y SUELO_MAX (219), asi que el techo es mas BAJO con el suelo mas
-- bajo: los dos numeros de la tabla son las dos puntas.
--
--   capa     alto   dur minimo   dur real   v/largo @175  @219
--   H.Rain    7 px      25,0        39         0,64    0,80    TRAZA    margen x1,56
--   B.Rain    6 px      26,5        66         0,40    0,51    TRAZA    margen x2,49
--   B.Rain    9 px      17,7        66         0,27    0,34    TRAZA    margen x3,73
--   C.Rain    3 px      61,0        27         2,26    2,75    GUIONES  *** x0,44 ***
--   C.Rain    4 px      45,8        27         1,69    2,06    GUIONES  *** x0,59 ***
--   C.Rain    6 px      30,5        27         1,13    1,38    GUIONES  *** x0,89 ***
--
-- LO QUE DICE ESO, y es lo unico que restringe el diseno:
--
--   - H.Rain y B.Rain tienen aire de sobra, y jalan en la misma direccion.
--   - C.Rain NO TIENE AIRE, y ya estaba pasada antes de este cambio: sus gotas de
--     3 px avanzaban 1,85 veces su propia longitud por frame. Ahora 2,26. Y la de
--     6 px (antes 7 px) paso de 0,79, que era traza, a 1,13, que ya son guiones.
--     O sea que **la gota larga de C.Rain dejo de ser continua**: es el precio de
--     subir la velocidad y bajar el alto a la vez.
--
-- *** LO QUE NO SE DICE: que los guiones se vean mal. *** Una lluvia rapida de verdad
-- es una lluvia de guiones, y el criterio de arriba solo marca donde se deja de ver
-- una estela continua. Si los guiones de C.Rain molestan, la salida no es bajar `dur`
-- sino subir los altos; y el usuario decidio a ojo que esta combinacion va bien.
--
-- Y el `dur` nominal NUNCA es el tiempo en pantalla: la gota nace SPAWN_BANDA filas
-- mas abajo y muere cuando llega la PUNTA. Sin colision, la vida real es:
--
--   H.Rain 7 px   0,44 .. 0,60 s   (dur nominal 0,65 s)
--   B.Rain 6 px   0,71 .. 1,01 s   (dur nominal 1,10 s)
--   B.Rain 9 px   0,69 .. 1,00 s
--   C.Rain 3 px   0,32 .. 0,42 s   (dur nominal 0,45 s)
--   C.Rain 4 px   0,32 .. 0,42 s
--   C.Rain 6 px   0,31 .. 0,42 s
--
-- Y de H.Rain ese numero es un TECHO, no lo normal: `choca = true`, o sea que salpica
-- y muere al tocar cualquier hurtbox. B.Rain solo se oculta y sigue cayendo, y C.Rain
-- no colisiona con nada.
--
-- EL COSTO DE DIBUJADO, que es lo unico que se movio al agrandar el stock:
--
--   antes   43 lineas por frame  (10 gotas de 2 px + 10 de 1 px + 13 de 1 px)
--   ahora   55 lineas por frame  (14 gotas de 2 px + 11 de 1 px + 16 de 1 px)
--   pool    43 -> 52 gotas
--
-- B.Rain dibuja 11 de 22 y no 22 porque el parpadeo oculta medio grupo, y eso no
-- cambio de naturaleza: lo que se ve sigue siendo una de cada dos ranuras, a 29 px de
-- separacion en vez de los 32 px de antes.


-- Desplazamiento vertical del suelo del plano DEL FONDO respecto al frontal.
-- NO VERIFICADO: no hay direccion de la que sacarlo, asi que es un valor a ojo
-- hasta que se vea en pantalla. El frontal sale de los pies del P1, que si se
-- pueden leer de $44.
local FONDO_PISO_OFF = 16

-- Las gotas se SIEMBRAN repartidas por la pantalla, no todas en el borde
-- superior: si nacieran en y = 0 al activar la lluvia se veria una franja
-- bajando junta durante el primer segundo.
--
-- Cada gota tiene su propia banda vertical (su indice), con jitter. Asi el
-- reparto se mantiene solo tras muchas renovaciones y las gotas no llegan
-- nunca al suelo en el mismo frame.

local function rnd(a, b)
  return a + math.random() * (b - a)
end

local lluvia = {}
local lluvia_on = {}
local lluvia_sembrada = {}

-- Ultima linea de muerte calculada por capa, en pixeles de JUEGO. La guarda
-- update_lluvia y la lee el recorte de draw_lluvia, para que ambos usen
-- exactamente la misma: si calcularan la linea por su cuenta, el recorte podria
-- cortar contra una fila distinta de por donde muere la gota.
local linea_capa = {}

-- El alto corto de la capa, o nil si no mezcla largos. Se usa para decidir el grupo
-- del parpadeo: grupo 0 = las del alto corto, grupo 1 = las del alto largo.
local function alto_corto(d)
  if not d.largos then return nil end
  local m = d.largos[1]
  for i = 2, #d.largos do
    if d.largos[i] < m then m = d.largos[i] end
  end
  return m
end

for t = 1, #LLUVIA_DEF do
  lluvia[t] = {}
  lluvia_on[t] = true
  lluvia_sembrada[t] = false
  local corto = alto_corto(LLUVIA_DEF[t])
  for i = 1, LLUVIA_DEF[t].n do
    local largo = LLUVIA_DEF[t].largos and LLUVIA_DEF[t].largos[i] or LLUVIA_DEF[t].largo
    -- El largo va en la GOTA, no en la capa, porque hay capas que lo mezclan
    -- (ver LLUVIA_DEF[3].largos). Se fija al crear el pool y no se vuelve a
    -- tocar: una gota no cambia de largo mientras cae, cambiaria su forma.
    --
    -- `grupo` es para el PARPADEO: 0 si es del alto corto, 1 si es del alto largo,
    -- y nil si la capa no mezcla. Se decide por el largo y NO por el indice, para
    -- que siga siendo correcto aunque alguien reordene la lista `largos`.
    --
    -- `parpadeo` se recalcula cada frame en update_lluvia y es DISTINTO de
    -- `oculta`: esta es la hurtbox, aquel es el grupo del turno. Se guardan por
    -- separado para poder razonar sobre cada causa por su cuenta.
    lluvia[t][i] = { viva = false, x = 0, y = 0, oculta = false, parpadeo = false,
                     largo = largo, grupo = corto and (largo == corto and 0 or 1) or nil }
  end
end

-- math.random() SIN semilla da la misma secuencia en cada carga, con lo que la
-- lluvia seria siempre identica. Si hay os.time se siembra; si el sandbox no lo
-- expone, se acepta y la lluvia sale igual siempre.
if math.randomseed and os and os.time then math.randomseed(os.time()) end

-- Salpicaduras: pool circular. Si esta lleno se pisa la mas vieja, que es lo
-- que pasa en un aguacero y no se nota; si en cambio se descartaran, en un
-- frame con muchas gotas a la vez no saldria ninguna.
local PART_MAX  = 64
local PART_POR  = 4         -- particulas por impacto. TIENE QUE SER IGUAL a #PART_CRUZ:
                            -- el bucle de salpica() recorre la tabla de la cruz, que
                            -- es la que decide cuantas salen y en que posicion. Si
                            -- se cambiarara solo esta constante, el numero de
                            -- particulas por impacto dejaria de ser el que dice aqui
                            -- sin que nada avisara.
local PART_VIDA = 8         -- 133 ms a 60 Hz. Menos de 5 frames es subliminal.
local parts = {}
local part_i = 0
for i = 1, PART_MAX do parts[i] = { viva = false } end

-- Y de mundo del suelo del plano frontal. Se guarda el MAXIMO alcanzado por los
-- pies del P1, no la Y de este frame: al saltar, la linea se moveria hacia
-- arriba y las gotas moririan en el aire.
local suelo_mundo = nil

  -- ALTO_DIBUJADO (arriba, junto a los margenes) es 224, el alto de la pantalla
  -- Mega Drive. NO se usa emu.screenheight(), que devuelve el alto de la VENTANA:
  -- con otra relacion de aspecto sobra borde negro y una gota que muere en la
  -- fila 224 de la ventana se ve caer ahi dentro.
  --
  -- Y ni siquiera 224 es la fila correcta para morir: la ultima DIBUJADA es la
  -- 223, que es ULTIMA_FILA. En 224 ya se entra en el negro, que es justo lo
  -- que hacia la capa "abajo".
  --
  -- Es la misma regla que el snapshot de las cajas: la simulacion va entera en
  -- pixeles de juego (suelo, siembra, colision, muerte) y la conversion a
  -- ventana ocurre en el ultimo momento, al dibujar. Ver de_juego() y
  -- draw_lluvia().
local function linea_de_suelo(d, suelo_frente, suelo_fondo, sh)
  if d.suelo == "frente" then return suelo_frente end
  if d.suelo == "fondo"  then return suelo_fondo  end
  -- La capa "abajo" (C.Rain) muere un poco MAS ABAJO que el suelo del stage: es la
  -- capa cercana, asi que tiene que pasar un poco por delante de la linea del suelo
  -- en vez de morir en ella. ABAJO_OFF son esas filas de ventaja.
  --
  -- Con un numero fijo (223, luego 211) esto iba mal en cuanto cambiaba el stage o
  -- la camara. Siguiendo el suelo se adapta solo. El techo con ULTIMA_FILA sigue
  -- haciendo falta: si el suelo queda muy abajo, la gota no debe salirse de la
  -- imagen.
  if d.suelo == "abajo" then
    local y = suelo_frente + ABAJO_OFF
    if y > ULTIMA_FILA then y = ULTIMA_FILA end
    return y
  end
end

-- Una gota sembrada en su banda, con jitter. Se reutiliza al renovarla, asi que
-- no se crean tablas nuevas.
-- Siembra UNA gota de la capa t.
--
-- Las tres capas NACEN en la misma fila, SPAWN_Y. Antes cada gota nacia a una
-- altura distinta segun su indice i, que ataba la Y al mismo i que la X y hacia
-- que las capas formaran una diagonal: la gota 1 de cada una caia en la misma
-- esquina y la ultima en la otra. Con el techo comun se mezclan de verdad.
--
-- X repartida por el ancho entero con jitter del 30 %, lo mismo que antes: es lo
-- que hace que las tres capas se entrelacen y no caigan en columnas.
--
-- Y NO puede ser exactamente SPAWN_Y para todas. Con la misma velocidad, gotas
-- que nacen en la misma fila caen en paralelo y MUEREN TODAS en el mismo frame, y la
-- lluvia se ve a pulsos en vez de correr. Por eso la fila es un punto de partida y
-- no un valor fijo: cada gota entra en un punto al azar dentro de una franja.
--
-- La franja arranca en SPAWN_Y (la candidata que se midio con la linea cyan de 160
-- px) y baja SPAWN_BANDA filas. Se ve como que todas salen del mismo punto de la
-- parte alta, pero siguen voladas separadas y se van apagando por turnos.
local function sembrar_una(t, i)
  local d = LLUVIA_DEF[t]
  local sw = emu.screenwidth()
  local p = lluvia[t][i]
  local paso_x = sw / d.n
  p.x = (i - 0.5) * paso_x + rnd(-paso_x * 0.30, paso_x * 0.30)
  p.y = SPAWN_Y + rnd(0, SPAWN_BANDA)
  if p.x < -4 then p.x = -4 elseif p.x > sw + 4 then p.x = sw + 4 end
  p.oculta = false
  p.viva = true
  return p
end

-- LAS CUATRO PARTICULAS SALEN EN CRUZ, NO EN ANGULO ALEATORIO.
--
-- Peticion del usuario sobre un dibujo: las cuatro particulas de 2x2 px se colocan en
-- las cuatro diagonales respecto del impacto, y la de cada esquina toca con su punta
-- la punta de un cuadrado central de 2 px. Ese cuadrado central NO se dibuja: es solo
-- la separacion, el hueco.
--
-- O sea esto, siendo P el punto de impacto:
--
--      [ ] 2px  [ ]
--        2 px
--   P  ......
--        2 px
--      [ ]     [ ]
--
-- LA ARITMETICA DEL DESPLAZAMIENTO, que es lo unico delicado. La particula se dibuja
-- con dos lineas, en (q.x, q.y) y (q.x, q.y + 1), cada una de x a x + 1: o sea
-- ocupa los pixeles q.x .. q.x+1 en X y q.y .. q.y+1 en Y. Para que el hueco central
-- sea de EXACTAMENTE 2 px, los bloques tienen que empezar en px-3 y px+1:
--
--   bloque izquierdo  px-3 .. px-2      hueco  px-1 .. px   (2 px)
--   bloque derecho    px+1 .. px+2
--
-- Por eso losOffsets son -3 y +1 y no simetricos (-2 y +2). Con -2 y +2 el hueco
-- seria de 3 px, porque el bloque es de 2 de ancho y no se puede centrar en un pixel
-- sin partirlo. Un pixel de diferencia a esta escala no se ve, pero la cuenta esta
-- hecha para que el hueco sean los 2 px que se pidieron.
--
-- Cada bloque y el hueco se tocan en la DIAGONAL, que es justo la forma del dibujo.
--
-- LA VELOCIDAD SIGUE SIENDO ALEATORIA en magnitud, y la direccion es la de su
-- esquina. O sea que la cruz se ve en el frame en que nacen y a partir de ahi cada
-- una se va por su diagonal a velocidad distinta. Si en algun momento hay que
-- mantener la cruz, es quitarle el `rnd` de la velocidad: con las cuatro identicas
-- la cruz se abre como un cuadrado y la separacion se conserva.
local PART_CRUZ = {
  --  x     y      angulo     (en radianes; -3/4*pi = arriba-izquierda)
  {  -3,  -3, -3 * math.pi / 4 },
  {   1,  -3, -1 * math.pi / 4 },
  {  -3,   1,  3 * math.pi / 4 },
  {   1,   1,  1 * math.pi / 4 },
}

local function salpica(px, py, col)
  for k = 1, #PART_CRUZ do
    part_i = part_i % PART_MAX + 1
    local q = parts[part_i]
    local c = PART_CRUZ[k]
    local sp = rnd(0.15, 0.50)
    q.viva = true
    q.x = px + c[1]
    q.y = py + c[2]
    q.vx = math.cos(c[3]) * sp
    q.vy = math.sin(c[3]) * sp - 0.25       -- un poco hacia arriba
    q.vida = PART_VIDA - 2 + math.floor(rnd(0, 4))
    if q.vida < 1 then q.vida = 1 end
    q.vida_max = q.vida
    q.col = col
  end
end

-- Solape del rectangulo de la gota con cualquiera de las hurtbox.
--
-- Se usa solape y no contencion: la gota tiene que desaparecer en cuanto TOCA
-- al personaje, no cuando esta completamente dentro.
local function toca_hurtbox(p, d, rects)
  local x1, x2 = p.x, p.x + d.dx
  if x1 > x2 then x1, x2 = x2, x1 end
  local y1, y2 = p.y, p.y + p.largo
  for i = 1, #rects do
    local r = rects[i]
    if x2 >= r.x1 and x1 <= r.x2 and y2 >= r.y1 and y1 <= r.y2 then
      return r
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- PARPADEO DE UN GRUPO: el efecto de "lluvia que parpadea"
--
-- De las gotas de UNA capa que mezcla dos altos, solo se dibuja un grupo por
-- turno: durante PARPADEO_FRAMES frames se ve el grupo 0 y el 1 esta oculto, y
-- alrevés. Las ocultas SIGUEN VIVAS: se mueven y mueren en su punto de siempre,
-- solo que no se dibujan. Es el mismo mecanismo que `p.oculta` con la hurtbox,
-- guardado en otro campo para poder distinguir las dos causas.
--
-- LO QUE NO TOCA, que es lo importante:
--   - el largo de la gota, que esta en p.largo y no se vuelve a tocar: NO hay
--     estiramiento ni acortamiento, cada gota es siempre la misma
--   - la muerte, que es p.y + p.largo >= linea
--   - la velocidad, que es linea / dur
--   - el recorte de los paneles del HUD, que se calcula sobre p.largo
--
-- POR QUE EL STOCK ES EL DOBLE: con 10 gotas en total el salto horizontal entre el
-- grupo que se oculta y el que aparece era el paso completo del reparto, y eso se
-- leia como un latigazo. Con 20 el paso es la mitad. El costo de DIBUJADO es el
-- mismo en los dos casos (10 lineas por frame): lo que se duplica es la
-- simulacion, que son unas pocas operaciones por gota y no se nota.
--
-- Un ciclo completo son 2 * PARPADEO_FRAMES frames. Con 2 son 4 frames, o sea
-- 15 Hz a 60 Hz: se ve como un brillo, no como un estrobo. Con 1 seria 30 Hz.
--------------------------------------------------------------------------------
local PARPADEO_FRAMES = 2

-- Contador de frames del parpadeo. Va declarado aqui y no junto a update_lluvia
-- porque... no, si: esta declarado ANTES, que es lo que importa. En Lua un local
-- declarado mas abajo seria un global nil en el punto de uso.
--
-- Es un contador propio y NO emu.framecount a proposito: framecount lo resetea el
-- emulador al cargar un savestate, y un cambio de fase en ese frame haria parpadear
-- la lluvia de golpe.
local frames_parpadeo = 0

--------------------------------------------------------------------------------
-- Y de pantalla del suelo del plano frontal.
--
-- Sale de los pies del P1: el Y de MUNDO mas bajo que ha alcanzado, que es el
-- del suelo (al saltar el personaje sube, y si se usara el Y de este frame la
-- linea subiria con el y las gotas moririan en el aire).
--
-- OJO CON EL RECORTE, y es lo importante: la conversion arrastra CAL_Y, que es
-- un ajuste A MANO y sigue sin calibrar (pendiente 6 de AGENTS.md). Con el
-- valor actual (-127) el suelo cae en cualquier sitio, y si cae MUY ARRIBA las
-- 7 gotas de la pesada se siembran en una franja de pocos pixeles que cabe
-- enterita dentro de una hurtbox: la lluvia no se ve, porque todas las gotas
-- nacen ya tocando al personaje y mueren en el mismo frame.
--
-- El recorte de abajo (SUELO_MIN = 0.78, o sea 175 de 224) evita eso: el suelo
-- nunca esta mas arriba que los pies, que es como se ve el juego. Cuando
-- CAL_X/CAL_Y esten afrados, el recorte dejara de hacer falta, pero conviene
-- dejarlo: protege de que una conversion sin afinar rompa el efecto en silencio.
--------------------------------------------------------------------------------
local SUELO_MIN = 0.78          -- 175 de 224: los pies del personaje
local SUELO_MAX = 0.98          -- 219 de 224

local function suelo_frontal()
  local wy = rw(P1 + OFF_WORLDY_LO)
  if suelo_mundo == nil or wy > suelo_mundo then suelo_mundo = wy end
  -- Todo esto va en pixeles de JUEGO (0..320, 0..224), no de ventana. La
  --Conversion del margen se hace SOLO al dibujar (ver de_juego y draw_lluvia).
  --
  -- Es lo mismo que el snapshot de las cajas: leer y comparar en un espacio,
  -- dibujar en el otro. Mezclarlos hacia que con borde negro el suelo se vaya y
  -- las gotas mueran en el sitio equivocado.
  local y = mundo_y_a_screen(suelo_mundo)
  local lo = ALTO_JUEGO * SUELO_MIN
  local hi = ALTO_JUEGO * SUELO_MAX
  if y < lo then return lo end
  if y > hi then return hi end
  return y
end

--------------------------------------------------------------------------------
-- Un frame de lluvia. Se llama UNA vez, con los rectangulos ya calculados.
--
-- `enp` es el gate de pelea, LEIDO UNA VEZ por el callback y pasado aqui. No se
-- relee dentro: leer el gate dos veces en el mismo frame (una para simular y otra
-- para dibujar) son dos respuestas posibles si algo se cuela en medio.
--
-- "No estamos en pelea" se trata EXACTAMENTE igual que una capa apagada del menu,
-- y por el mismo motivo: matan todas las gotas y `lluvia_sembrada` a false, para
-- que al volver a entrar la franja salga de golpe. Si solo se dejara de dibujar,
-- las gotas se quedarian colgadas en el aire y al arrancar la pelea siguiente
-- aparecerian todas de golpe en el punto donde las congelo.

local function update_lluvia(hurt, enp, mult)
  local frente = suelo_frontal()
  local suelo_frente = frente
  local suelo_fondo  = frente - FONDO_PISO_OFF

  -- Un turno por PARPADEO_FRAMES, y van 0 y 1 alternando. El turno se calcula UNA
  -- vez por frame, antes del bucle de capas, para que todas las capas que lo usen
  -- coincidan en el mismo frame.
  frames_parpadeo = frames_parpadeo + 1
  local turno = math.floor(frames_parpadeo / PARPADEO_FRAMES) % 2

  for t = 1, #LLUVIA_DEF do
    local d = LLUVIA_DEF[t]
    if not (lluvia_on[t] and enp) then
      -- Las posiciones NO se borran al apagar, para que al reencender salga
      -- una franja de golpe.
      for i = 1, d.n do lluvia[t][i].viva = false end
      lluvia_sembrada[t] = false
    else
      local linea = linea_de_suelo(d, suelo_frente, suelo_fondo, sh)
      -- La linea se guarda por capa para que el recorte de draw_lluvia use
      -- EXACTAMENTE esta, y no una recalculada por su cuenta.
      linea_capa[t] = linea
      -- Y la de la capa cercana aparte, que es la que dibuja el bloque de medicion
      -- en magenta y necesita verla desde fuera de update_lluvia.
      if d.suelo == "abajo" then linea_muerte_crain = linea end
      if not lluvia_sembrada[t] then
        lluvia_sembrada[t] = true
        for i = 1, d.n do sembrar_una(t, i) end
      end
      -- Pixeles por frame. El `mult` es el unico lugar donde la camara lenta del
      -- JUEGO se nota en la lluvia: el overlay lo dibuja Lua en el host, a
      -- velocidad de host, asi que el slow-mo del juego NO lo frena por su cuenta y
      -- hay que bajarlo a mano. Solo vale 0.5 en la fase SLOW y 1 en todas las
      -- demas (ver `paso_lluvia`).
      local v = (linea / d.dur) * mult

      for i = 1, d.n do
        local p = lluvia[t][i]

        -- 1) Una gota MUERTA se re-siembra aqui, siempre. Es lo que mantiene
        --    vivo el pool: si el re-sembrado solo ocurre "al morir", una gota que
        --    murio queda muerta para siempre y la capa se vacia sin aviso.
        --
        --    Con la re-siembra hay un caso patologico: si nace DENTRO de una
        --    hurtbox (que es justo lo que pasa con una caja que cubre la
        --    pantalla entera), muere en el mismo frame, se re-siembra, y otra
        --    vez dentro. La capa entera se queda invisible para siempre.
        --    La salida es dejar esa gota muerta ESTE frame y reintentarlo en el
        --    siguiente. Cuando la caja se va, la capa reaparece sola.
        if not p.viva then
          local re = sembrar_una(t, i)
          if re and d.choca and #hurt > 0 and toca_hurtbox(re, d, hurt) then
            re.viva = false
          end
        end

        if p.viva then
          p.y = p.y + v
          p.oculta = false

          -- PARPADEO: a esta gota le toca el turno, y si le toca se dibuja.
          -- Solo cambia lo que se VE; el largo, la velocidad y la muerte ya estan
          -- resueltos y no se tocan. Se recalcula aqui, una vez por frame, igual que
          -- `oculta`: por eso apagarla o sacarla de la capa la saca de verdad.
          p.parpadeo = (d.parpadeo ~= nil and p.grupo ~= nil
                        and p.grupo ~= turno)

          -- 2) el suelo manda sobre todo: si la punta llega a la linea, la gota
          --    muere. La pesada salpica, las otras dos no.
          if p.y + p.largo >= linea then
            if d.choca then
              salpica(p.x + d.dx * 0.5, linea, d.col)
            end
            p.viva = false
          end

          -- 3) La hurtbox, sobre la posicion actual. La pesada salpica y muere;
          --    la de fondo solo se esconde y SEGUERA VIVA, porque "oculta" se
          --    recalcula desde cero cada frame.
          if p.viva and (d.choca or d.oculta) and #hurt > 0 then
            if toca_hurtbox(p, d, hurt) then
              if d.choca then
                salpica(p.x + d.dx * 0.5, p.y + p.largo * 0.5, d.col)
                p.viva = false
              else
                p.oculta = true
              end
            end
          end
        end
      end
    end
  end

  for i = 1, PART_MAX do
    local q = parts[i]
    if q.viva then
      if not enp then
        -- Las salpicaduras mueren tambien fuera de pelea. Si se limitaran a no
        -- dibujarse, seguirian vivas y enteras: al arrancar la pelea siguiente
        -- aparecerian en el aire, a medio caer, del color de un golpe que no paso.
        q.viva = false
      else
        q.x = q.x + q.vx
        q.y = q.y + q.vy
        q.vy = q.vy + 0.08                  -- gravedad leve
        q.vida = q.vida - 1
        if q.vida <= 0 then q.viva = false end
      end
    end
  end
end

-- NO se vuelve a declarar `gotas_dibujadas` aca: ya esta declarado arriba, junto al
-- latido que lo lee. Una SEGUNDA declaracion aca crearia un local que TAPA al de
-- arriba, y el contador se escribiria en uno y se leeria en el otro: el numero
-- saldria 0 SIEMPRE, sin error, y `luajit -bl` lo pasa limpio. Es la trampa de "un
-- local declarado mas abajo" al reves, y salio pegada justo en el contador que
-- existe para que el diagnostico no mienta.
local function draw_lluvia(enp)
  gotas_dibujadas = 0
  local sw, sh = emu.screenwidth(), emu.screenheight()

  -- En orden de la tabla: primero la pesada, y la cercana ultima, que es la
  -- que tiene que quedar ENCIMA de los personajes.
  for t = 1, #LLUVIA_DEF do
    local d = LLUVIA_DEF[t]
    if lluvia_on[t] and enp then
      for i = 1, d.n do
        local p = lluvia[t][i]
        -- `not p.parpadeo` es el grupo que NO es su turno. Se salta el dibujado
        -- entero, no la simulacion: la gota ya se movio y ya decidio si muere, y
        -- eso se hizo en update_lluvia. Por eso una gota oculta sigue cayendo y
        -- muere igual que si se estuviera viendo.
        if p.viva and not p.oculta and not p.parpadeo then
          -- RECORTES, TODO EN PIXELES DE JUEGO. Ni una operacion con ventanas
          -- hasta el final: mezclar los dos espacios es lo que hacia que con
          -- borde negro no se dibujara ninguna gota (comparar una Y de juego contra
          -- una de ventana da siempre falso, y con oy = 0 no se nota).
          --
          -- La gota va de (p.x, p.y) a (p.x + dx, p.y + largo). Se recorta por los
          -- dos lados de ese segmento y solo despues se convierte a ventana.
          local y_top, y_bot = p.y, p.y + p.largo

          -- 1) CONTRA LA LINEA DE MUERTE, para que la punta nunca pase de ella.
          -- Solo aplica a la capa "abajo": las otras dos mueren en el suelo del
          -- stage, mas arriba, y ahi no hay borde que respetar.
          --
          -- Usa linea_capa[t], que es la MISMA linea que update_lluvia calculo este
          -- frame. Si el recorte y la muerte usaran numeros distintos, la gota se
          -- acortaria contra una fila que no es por donde muere.
          if d.suelo == "abajo" then
            local hasta = linea_capa[t] - p.y        -- cuanto cabe hasta la linea
            if hasta < (y_bot - p.y) then y_bot = p.y + hasta end
          end

          -- 2) CONTRA LOS RECUADROS FIJOS DEL HUD. Aplica a LAS TRES CAPAS, a
          -- proposito: el HUD esta en el techo y le cae encima a quien le quiera, no
          -- solo a la capa de fondo como le pasaba con la hurtbox.
          --
          -- Se recorta la parte ALTA y se dibuja el resto entero. Ocultar la gota
          -- entera mientras cruza la banda la haria aparecer y desaparecer de
          -- golpe; asi emerge limpia por debajo del panel, que es lo que se ve
          -- cuando la lluvia pasa por detras de un HUD.
          local tapa = zona_tapa(p, d)
          if tapa and tapa > y_top then y_top = tapa end

          -- Si el recorte se comio el segmento entero, no se dibuja nada. Es el
          -- caso normal de una gota entrando en el panel: sigue viva, sigue
          -- cayendo, y reaparece por debajo.
          if y_bot > y_top then
            -- Al cortar la punta de arriba hay que recalcular la X de ese extremo:
            -- en una diagonal la X va con la Y, y recortar solo la Y dejaria el
            -- trazo torcido.
            --
            -- OJO LA ESCALA: d.dx es el desplazamiento TOTAL de la gota a lo largo
            -- de sus p.largo filas, NO el desplazamiento por fila. Multiplicarlo
            -- tal cual por las filas recortadas hacia que la punta se fuera 2 px
            -- a la IZQUIERDA de mas, y como el total es menor que una fila, el
            -- redondeo llegaba a dar una gota cayendo hacia la DERECHA. Va
            -- dividido por p.largo, que es lo que hace que la recta siga siendo
            -- la misma recta.
            --
            -- Y por que el denominador es el largo de LA GOTA y no el de la capa:
            -- el largo va en p porque hay capas que lo mezclan (C.Rain tiene de
            -- 3, 5 y 7 px). Con el de la capa, la recta no seria la de esa gota.
            local frac = (y_top - p.y) / p.largo
            local xt = math.floor(p.x + d.dx * frac)
            local xb = math.floor(p.x + d.dx)
            -- OJO EL floor DE LA Y, que parece que sobra y no: p.y es flotante y
            -- aqui se estan recortando los dos extremos. Sin el floor, el recorte
            -- contra los paneles del HUD devolveria y1 fraccionario (por ejemplo
            -- 45,7) y se dibujaria una fila de mas o de menos de lo que marque
            -- el alto de la gota. Las dos Y van enteras, como antes del recorte.
            local x1, y1 = de_juego(xt, math.floor(y_top))
            local x2, y2 = de_juego(xb, math.floor(y_bot))
            -- El recorte de ventana va aqui, ya con los dos extremos convertidos.
            if x2 > -8 and x1 < sw + 8 and y2 > -p.largo and y1 < sh + p.largo then
              -- Una gota dibujada, no una linea: H.Rain dibuja DOS lineas por gota
              -- (grosor 2) y el contador tiene que ser comparable entre capas. Y va
              -- DESPUES de los dos recortes (muerte y HUD), porque una gota que se
              -- recorte entera no cuenta: en pantalla no hay nada.
              gotas_dibujadas = gotas_dibujadas + 1
              -- 1 px: una sola diagonal. 2 px: la misma repetida a 1 px de lado,
              -- que es lo que hace gruesa la gota sin taparla con nada.
              gui.drawline(x1, y1, x2, y2, d.col)
              if d.grosor > 1 then
                gui.drawline(x1 + 1, y1, x2 + 1, y2, d.col)
              end
            end
          end
        end
      end
    end
  end

  -- Salpicaduras: 2x2 con dos lineas, y el alfa cayendo en los ultimos frames.
  -- El corte abrupto delata el pixel; bajar el alfa en vez de desaparecer de
  -- golpe es lo que hace que se lea como impacto.
  --
  -- OJO CON EL ALFA, DOS COSAS:
  --
  -- 1) Va en el byte BAJO, no en el alto. FBNeo lee 0xRRGGBBAA. Con
  --    bit.lshift(a, 24) el alfa se estaba paintando como ROJO y el byte bajo
  --    (la cola del azul de la gota) se usaba como alfa: la salpicadura salia
  --    rosa y con un alfa que no era el que se queria.
  --
  -- 2) Tiene que ser un ENTERO. bit.lshift de un float (que sale de una division)
  --    no hace la conversion y el byte se va una posicion. Con math.floor()
  --    alrededor del bit.band queda limpio.
  for i = 1, PART_MAX do
    local q = parts[i]
    if q.viva then
      local a = bit.band(math.floor(255 * q.vida / q.vida_max), 0xFF)
      if a > 0 then
        -- Se conserva el RGB de la gota y se cambia SOLO el byte del alfa.
        local c = bit.bor(bit.band(q.col, 0xFFFFFF00), a)
        -- Igual que las gotas: la particula se simula en pixeles de juego y se
        -- convierte al dibujar.
        local x, y = de_juego(math.floor(q.x), math.floor(q.y))
        if x > -2 and x < sw and y > -2 and y < sh then
          gui.drawline(x, y, x + 1, y, c)
          gui.drawline(x, y + 1, x + 1, y + 1, c)
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Menu
--
-- Se abre manteniendo MODE un instante, para que no se abra por accident al
-- tocarlo. Es la unica tecla que no se usa para golpear, asi que el menu no
-- pisa nada de la partida.
--
--   mantener MODE   abrir / cerrar
--   arriba / abajo  mover el cursor
--   A               activar o desactivar la opcion
--   B               volver todo a los valores de fabrica
--
-- Cuatro tipos de caja, el filtro de jugador, las tres capas de lluvia y las
-- guias de medicion: nueve opciones, que en dos columnas entran de sobra.
--
-- Se SACO "grab" del menu: la opcion no funcionaba de forma confiable y paso a
-- ser la constante SHOW_GRAB (ver arriba). Sigue siendo la novena, porque en su
-- lugar entro "G.LINE".
--------------------------------------------------------------------------------
local MENU_HOLD = 30
local MENU_COLS = 2
local COLW  = 100
local GUTTER = 26      -- margen izquierdo para las miniaturas
local PRE_W  = 18
local VAL_X, LAB_X = 1, 24

local menu_open = false
local menu_row  = 0
local mode_hold = 0
local menu_prev = {}

-- El cuarto campo, si esta, es la lista de colisiones de la que habla el
-- item: el menu dibuja una mini muestra de SU trazo real en el margen.
local function bool_item(label, get, set, prev)
  return { label = label, kind = "bool", get = get, set = set, prev = prev,
           value = function() return get() and 1 or 0 end,
           act = function() set(not get()) end }
end

-- El orden de DEFAULTS TIENE QUE SER IGUAL al de MENU, en el mismo indice. El
-- reset (B) los aplica por posicion.
local DEFAULTS = {
  SHOW_HITBOXES, SHOW_CLASH, SHOW_HURTBOXES, SHOW_PUSHBOXES,
  SHOW_P2,
  -- Las tres capas de lluvia estan ENCENDIDAS de fabrica: para verlas no hay
  -- que tocar nada, que es lo que se quiere al probar un efecto nuevo.
  true, true, true,
  GUIAS,
}

local MENU = {
  bool_item("hitbox", function() return SHOW_HITBOXES end,
            function(v) SHOW_HITBOXES = v end, list_by("hit")),
  bool_item("clash", function() return SHOW_CLASH end,
            function(v) SHOW_CLASH = v end, list_by("clsh")),
  bool_item("hurtbox", function() return SHOW_HURTBOXES end,
            function(v) SHOW_HURTBOXES = v end, list_by("hurt")),
  bool_item("pushbox", function() return SHOW_PUSHBOXES end,
            function(v) SHOW_PUSHBOXES = v end, list_by("push")),
  bool_item("cajas P2", function() return SHOW_P2 end,
            function(v) SHOW_P2 = v end),
  -- Sin miniatura: LLUVIA_DEF[i].et es el nombre corto de la capa.
  bool_item(LLUVIA_DEF[1].et, function() return lluvia_on[1] end,
            function(v) lluvia_on[1] = v end),
  bool_item(LLUVIA_DEF[2].et, function() return lluvia_on[2] end,
            function(v) lluvia_on[2] = v end),
  bool_item(LLUVIA_DEF[3].et, function() return lluvia_on[3] end,
            function(v) lluvia_on[3] = v end),
  -- Las GUIAS DE MEDICION. Sin miniatura porque no dibujan una caja.
  --
  -- ENCENDIDAS de fabrica y eso es TEMPORAL: son el andamiaje con el que se
  -- ajustaron las zonas del HUD y el margen de la ventana. Cuando el ajuste
  -- termine, se pone en false y esta opcion se saca junto con medir_hud().
  bool_item("G.LINE", function() return GUIAS end,
            function(v) GUIAS = v end),
}

local function menu_slot(i)
  local rows = math.ceil(#MENU / MENU_COLS)
  local col = math.floor((i - 1) / rows)
  local row = (i - 1) % rows
  return col, row, rows
end

local function update_menu()
  local pad = joypad.get()
  local mode = pad["P1 Mode"] and true or false

  if mode then
    mode_hold = mode_hold + 1
    if mode_hold == MENU_HOLD then
      menu_open = not menu_open
      menu_row = 0
    end
  else
    mode_hold = 0
  end

  if not menu_open then return end

  -- Navegacion con flanco, para no repetir por mantener.
  local function edge(key)
    local d = pad[key] and true or false
    local p = menu_prev[key]
    menu_prev[key] = d
    return d and not p
  end

  if edge("P1 Up")   then menu_row = menu_row - 1 end
  if edge("P1 Down") then menu_row = menu_row + 1 end
  if menu_row < 0 then menu_row = #MENU end
  if menu_row > #MENU then menu_row = 0 end

  local it = MENU[menu_row + 1]
  if it then
    if edge("P1 Button A") then it.act() end
    if edge("P1 Button B") then
      SHOW_HITBOXES, SHOW_CLASH, SHOW_HURTBOXES = DEFAULTS[1], DEFAULTS[2], DEFAULTS[3]
      SHOW_PUSHBOXES, SHOW_P2 = DEFAULTS[4], DEFAULTS[5]
      for t = 1, 3 do lluvia_on[t] = DEFAULTS[5 + t] end
      GUIAS = DEFAULTS[9]
    end
  end
end

local function draw_menu_row(cx, ly, it, sel)
  local col = sel and color(0x60, 0xFF, 0x60, 0xFF) or color(0xC0, 0xC0, 0xC0, 0xFF)
  local val = string.format("%-3s", it.value() ~= 0 and "ON" or "off")
  hud_text(cx + VAL_X, ly, val, col)
  hud_text(cx + LAB_X, ly, it.label, col)
  if sel then
    tri(cx + COLW - 12, ly + 4, "right", color(0x60, 0xFF, 0x60, 0xFF))
  end
end

local function draw_menu()
  if not menu_open then return end
  local sw, sh = emu.screenwidth(), emu.screenheight()
  local colw, rowh = COLW, 10
  local _, _, rows = menu_slot(1)
  local w = colw * MENU_COLS + 6
  local h = rows * rowh + 24
  local x = (sw - w) / 2 + GUTTER
  local y = (sh - h) / 2

  gui.box(x, y, x + w, y + h, color(0x1A, 0x1A, 0x2A, 0xF0), color(0x60, 0xFF, 0x60, 0xFF))
  gui.text(x + 5, y + 3, "A ON/OFF   B reset   MODE salir", color(0xFF, 0xFF, 0xFF, 0xFF))
  gui.drawline(x + 3, y + 13, x + w - 3, y + 13, color(0x60, 0xFF, 0x60, 0xFF))

  for i = 1, #MENU do
    local it = MENU[i]
    local col, row = menu_slot(i)
    local cx = x + 3 + col * colw
    local ly = y + 17 + row * rowh
    local sel = (i - 1) == menu_row
    if sel then
      gui.box(cx - 1, ly - 1, cx + colw - 4, ly + 8, color(0xFF, 0xFF, 0xFF, 0x60), color(0x00, 0x00, 0x00, 0x00))
    end
    if it.prev then
      local px = x - GUTTER + 4
      draw_box(px, ly - 1, px + PRE_W, ly + 7, it.prev.line, it.prev.style, 3)
      gui.drawline(px + PRE_W + 2, ly + 3, x - 2, ly + 3, color(0xFF, 0xFF, 0xFF, 0x60))
    end
    draw_menu_row(cx, ly, it, sel)
  end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------
local function on_dispatch()
  for i = 1, #LISTS do
    counts[i] = box_count(rw(LISTS[i].cnt), LISTS[i].stride)
  end
  hooked = true
  exec_stamp = frame_id
  wr_seen = false
end

-- El callback de registerwrite no recibe argumentos: hay que leer la memoria
-- en la direccion que se registro, que se pasa por closure.
--
-- IMPORTANTE: hay que guardar TAMBIEN los ceros. $01EDAC pone a 0 los cinco
-- contadores en $01EDC2..$01EDDA todos los frames; si el callback descarta el
-- 0, wr_counts se queda con el ultimo valor no nulo y la hitbox/clashbox vieja
-- se sigue dibujando. El arreglo de "solo dibujar con write fresco" no servia
-- de nada, porque ademas wr_frame lo refrescaba en el mismo frame cualquier
-- pushbox o hurtbox con valor != 0, y el snapshot pasaba el test de frescura.
local function mk_count_hook(i, addr)
  return function()
    wr_counts[i] = rw(addr)
    wr_seen = true
    wr_frame = frame_id
  end
end

--------------------------------------------------------------------------------
-- Arranque
--------------------------------------------------------------------------------
local ROM = tostring(emu.romname())

-- FBNeo BORRA los hooks exec en cada reset del juego. Si el script se cargo
-- antes de que arrancara la partida, el hook se perdia. Por eso se re-arma
-- cada frame: registrar el mismo PC otra vez es idempotente y barato.
local function arm_hook()
  if memory.registerexec then
    memory.registerexec(HOOK_PC, on_dispatch)
  end
  if memory.registerwrite then
    for i = 1, #LISTS do
      local c = LISTS[i].cnt
      -- Registrar en las DOS direcciones: la que escribe el 68000 ($00A0xx)
      -- y el espejo de FBNeo ($FFA0xx). Con solo el espejo no llegaba nada.
      memory.registerwrite(c, 2, mk_count_hook(i, c))
      memory.registerwrite(c - 0xFF0000, 2, mk_count_hook(i, c - 0xFF0000))
    end
  end
end

arm_hook()
if emu.registerstart then emu.registerstart(arm_hook) end

-- DECLARACIONES ADELANTADAS DEL BLOQUE DE ARRANQUE
--
-- Las tres van aqui porque las usa el `registerafter` de mas abajo, y `un_frame`
-- se ASIGNA todavia mas abajo. Sin esto, en el punto de uso serian GLOBALES nil:
-- el `pcall(un_frame)` se comeria el error y volveria a congelar el overlay, que es
-- justo lo que este bloque vino a arreglar. **Que un bloque "que avisa errores" sea
-- el que se quede mudo por un local declarado tarde es la peor version de esa
-- trampa**, asi que van declaradas aca y con el motivo al lado.
local un_frame
local g_frame = 0
local g_frame_error = nil      -- frame en que EMPEZO el error, no el de ahora

-- NO se usa emu.registerbefore para invalidar el snapshot: en este build de
-- Fightcade no existe, y como la invalidacion era condicional el snapshot
-- NUNCA se limpiaba. Por eso la caja del ultimo golpe se quedaba congelada.
-- El snapshot se sella con frame_id (arriba) y frame_id avanza aqui, una vez
-- por frame.
-- El orden importa. El snapshot se resuelve UNA vez y se pasa a los dos que
-- lo consumen: la lluvia actualiza antes de que se dibujen las cajas, para que
-- la oclusion de la gota de fondo este al dia con el frame.

-- El cuerpo del frame va en SU PROPIA funcion para que el `pcall` de mas abajo lo
-- cubra entero. Si estuviera en la closure del `registerafter`, el error se
-- seguiria tragando y no habria nada que avisar.
--
-- OJO CON EL ORDEN: se ASIGNA con `un_frame = function()`, no con
-- `local function un_frame()`. Un `local function` aca crearia un SEGUNDO local que
-- tapa al de adelante, y el `registerafter` seguiria viendo un nil. Es la trampa
-- de "un local declarado mas abajo" por el camino largo: no da error de sintaxis,
-- `luajit -bl` lo pasa limpio, y en ejecucion el `pcall(nil)` se come el error y
-- vuelve a congelar el overlay, que es justo lo que este bloque vino a arreglar.
un_frame = function()
  arm_hook()
  -- El estado de la lluvia se lee UNA vez y se pasa a los dos consumidores: si la
  -- decision se tomara dos veces, una lectura de mas y una escritura de por medio
  -- darian dos respuestas distintas en el mismo frame.
  --
  -- `paso_lluvia()` devuelve las DOS cosas que hacen falta: si se dibuja, y a que
  -- velocidad. La velocidad va a `update_lluvia` (que mueve las gotas) y NO hace
  -- falta en `draw_lluvia`, que solo las pinta donde estan.
  local enp, mult = paso_lluvia()
  detectar_slots()          -- antes de snapshot(): las cajas usan P1 y P2
  update_menu()
  local use, src = snapshot()
  local rects = rects_del_frame(use)
  update_lluvia(rects[indice_de("hurt")], enp, mult)
  local dib_cajas = draw_boxes(use, rects, src)
  draw_grab_range()
  draw_lluvia(enp)

  -- LATIDO: una linea cada 60 frames. Va aca, DESPUES de `draw_lluvia`, para que
  -- todo lo que imprime sea de ESTE frame.
  --
  -- `lluvia=` son las GOTAS dibujadas ese frame (no lineas: H.Rain hace 2 lineas
  -- por gota). Con ese entero no hay que discutir a ojo si lo que se ve en pantalla
  -- es del script o del stage: en el menu tiene que decir 0.
  --
  -- Y las dos del final son el estado de la maquina de fases: `fase` dice en cual de
  -- las cuatro esta (NORMAL / SLOW / COLA / OFF) y `v` el multiplicador de
  -- velocidad que se esta aplicando. Con el KO, la linea tiene que pasar por
  -- `fase=SLOW v=0.50` y después por `fase=COLA v=1.00`, y de ahi a `fase=OFF`.
  -- Sin estos dos numeros, "la lluvia baja a la mitad" es una sensacion.
  probe_n = probe_n + 1
  if probe_n % 60 == 0 then
    local ax, ay = player_screen(P1)
    print(string.format("[yuyu] dib=%d src=%s pj=%d,%d lluvia=%d fase=%s v=%.2f | %s %d %d %d %d %d",
      dib_cajas, src, ax, ay, gotas_dibujadas, NOMBRES_FASE[fase + 1], mult,
      LISTS[1].name, use[1] or 0, use[2] or 0, use[3] or 0,
      use[4] or 0, use[5] or 0))
  end

  -- *** SI NO SE DIBUJO NADA, SE FUERZA UN DIBUJADO INVISIBLE ***
  --
  -- MEDIDO 08-10: con el gate apagado el script dibuja CERO gotas (`lluvia=0` en
  -- el latido, las 11 lineas del menu), y sin error. Y a pesar de eso **las gotas
  -- quedan congeladas en la pantalla**, hasta que empieza un combate nuevo.
  --
  -- O sea que la retencion NO es de nuestro logico de dibujado: es que **la
  -- superficie de `gui.*` de FBNeo no se limpia cuando el script no dibuja nada**, y
  -- queda el ultimo frame compuesto. Por eso "cerrar y reabrir el .lua en el menu"
  -- las borra (superficie nueva) y "empezar un combate nuevo" tambien (vuelve a
  -- haber dibujado): las dos son el mismo Sintoma.
  --
  -- El arreglo es barato y va a pelo: **si este frame no se dibujo ninguna gota, se
  -- emite una llamada de dibujado con alfa 0**. Es invisible (AGENTS.md: el alfa va
  -- en el byte bajo, y `00` es transparente), asi que no se ve, pero ES una llamada:
  -- fuerza el vaciado de la superficie y el overlay vuelve a componerse vacio.
  --
  -- ***LO QUE NO SE:*** si FBNeo limpia la superficie al PRESENCIAR el overlay o al
  -- borrar antes de cada dibujado. Si es lo segundo, este pixel invisible no borra
  -- nada y el sintoma sigue. No se decide leyendo: el usuario lo ve en una corrida.
  -- Por eso el pixel va con este comentario, y no escondido.
  if gotas_dibujadas == 0 then
    gui.drawline(0, 0, 0, 0, color(0x00, 0x00, 0x00, 0x00))
  end

  medir_hud()       -- stage de medicion del HUD; se borra al confirmar
  draw_menu()
  frame_id = frame_id + 1
  g_frame = g_frame + 1
end

emu.registerafter(function()
  -- *** ESTO NO ES UN ADORNADO: EL SINPTOMA DEL CALLBACK MUERTO ES ESTE ***
  --
  -- En este emulador una excepcion DENTRO de un callback **se traga**: no sale un
  -- error, no sale un aviso, y el callback muere a mitad. Lo que se ve es el
  -- overlay con el ULTIMO frame dibujado, congelado. O sea: si algo se congela, la
  -- primera pregunta no es "que no se esta dibujando" sino "el callback llego a
  -- `draw_lluvia`?".
  --
  -- Antes no habia nada de esto, y un fallo de una linea tardaba una sesion entera
  -- en aparecer. Un flag que avisa UNA vez no alcanza: si el error arranca en el
  -- frame 3000, el unico aviso queda enterrado en la consola. Por eso el aviso va
  -- CADA frame que falla, con el numero, y con el frame en que EMPEZO. Es lo unico
  -- que hay para no cazar a ciegas.
  --
  -- Y el mensaje se SACA del error: los bytes > 127 se cambian por '?', porque la
  -- consola de Fightcade los muestra como dos caracteres y el mensaje se vuelve
  -- ilegible justo cuando sirve.
  local okf, err = pcall(un_frame)
  if not okf then
    err = tostring(err):gsub("[^\32-\126]", "?")
    if g_frame_error == nil then g_frame_error = g_frame end
    print(string.format("[yuyu] ERROR en el frame %d (empezo en %d): %s",
      g_frame, g_frame_error, err))
  end
  -- Y el aviso EN PANTALLA, no solo en la consola. Va aca, FUERA del `pcall`, y por
  -- eso corre incluso cuando `un_frame` esta muerto: es el unico sitio del script
  -- que sigue vivo cuando todo lo demas cayo.
  --
  -- Sin esto, un fallo obliga a mirar la consola, y la consola de Fightcade esta en
  -- otra ventana. **Un error que no se ve no se arregla**, y el sintoma de un
  -- callback muerto (el overlay congelado) es justo el que mas dificil se ve solo.
  --
  -- Va en coordenadas de VENTANA y no de juego a proposito: tiene que aparecer
  -- pase lo que pase con el margen, que es de lo que no sabemos nada cuando esto
  -- salta.
  if not okf then
    local sw2, sh2 = emu.screenwidth(), emu.screenheight()
    local alto2 = math.floor(sh2 / 6)
    gui.box(0, 0, sw2 - 1, alto2, color(0xC0, 0x00, 0x00, 0xFF))
    gui.text(4, math.floor(alto2 / 3),
      "ERROR frame " .. g_frame .. " (desde " .. g_frame_error .. ")",
      color(0xFF, 0xFF, 0xFF, 0xFF))
  end
end)

-- Sonda de arranque.
--
-- Imprime el tamaño que VE el overlay y los colores de las tres capas. Con la
-- ventana en 16:9 emu.screenwidth()/screenheight() pueden no ser 320x224: si
-- devuelven el tamaño de la ventana, el overlay dibuja en coordenadas de
-- VENTANA y no de juego, y todo lo que este calculado sobre 320 se va de sitio.
-- Con ese numero por delante se puede saber si el problema es el ratio o el
-- script viejo.
local SW, SH = emu.screenwidth(), emu.screenheight()
local MARGEN_X, MARGEN_Y = margen_juego()
print(string.format(
  "[yuyu] cajas + lluvia listo. rom=%s hook en $%06X", ROM, HOOK_PC))
print(string.format("[yuyu] ventana que ve el overlay = %dx%d", SW, SH))
print(string.format("[yuyu] imagen del juego = %dx%d, MARGEN x=%d y=%d%s",
  ANCHO_JUEGO, ALTO_JUEGO, MARGEN_X, MARGEN_Y,
  (MARGEN_X == 0 and MARGEN_Y == 0) and "  (la ventana es del tamano del juego)"
    or "  (borde negro: el juego NO llena la ventana)"))
print(string.format("[yuyu] el juego ocupa de (%d,%d) a (%d,%d) dentro de la ventana",
  MARGEN_X, MARGEN_Y,
  MARGEN_X + ANCHO_JUEGO - 1, MARGEN_Y + ALTO_JUEGO - 1))

-- Si la ventana de Lua de Fightcade tiene una instancia COMPILADA del script, abrir
-- el archivo nuevo no recarga nada: sigue corriendo el viejo, sin avisar. Esta linea
-- dice si el gate esta compilado adentro, asi que un comportamiento viejo "que no me
-- arreglo" se puede atribuir al script equivocado ANTES de culpar al gate.
--
-- Y es lo unico que diferencia en la consola a la DIAGONAL de la RECTA: las dos
-- imprimen identico todo lo demas, porque las dos copias tienen las mismas tres
-- capas. Comparar el banner con el del otro archivo no sirve para distinguirlas.
--
-- El parentesito dice la REGLA y no "dos slots con HP > 0", que era lo que tenia
-- antes de que la regla pasara a ser la de "2+ vivos, o 1 vivo y nadie muerto": un
-- banner que miente sobre su propia regla es peor que uno que no la dice.
--
-- SIN `¿` NI CON TILDE, y a proposito: la consola de Fightcade los muestra como
-- dos caracteres, o sea el banner se ve roto y nadie lo lee. Los COMENTARIOS del
-- archivo pueden llevar tildes sin problema (no llegan a la consola): lo que no
-- puede es lo que se imprime. El banco comprueba exactamente eso, en el arranque.
print(string.format("[yuyu] GATE DE PELEA = %s (2+ vivos, o 1 vivo y nadie muerto)",
  (GATE_PELEA and "SI" or "NO")))
print(string.format("[yuyu] SLOW-MO DE MUERTE en $FFF558: cola de %d frames, "
  .. "lluvia al %.0f%% mientras dure", COLA_FRAMES, MULT_SLOWMO * 100))
for t = 1, #LLUVIA_DEF do
  local d = LLUVIA_DEF[t]
  -- Se imprime como "RRGGBB / AA", que es como lo lee el motor, y no como un
  -- hexadecimal de 8 digitos a secas: asi la consola y la pantalla se leen con
  -- la misma regla y no hay que recordar en que orden van los bytes.
  --
  -- Los tres bytes altos forman un numero > 2^31, que en LuaJIT es float, y
  -- string.format("%08X") sobre eso imprime un byte repetido. Por eso el
  -- hexadecimal va armandolo digito a digito con math.floor.
  local c = d.col
  if c >= 2147483648 then c = c - 4294967296 end
  local function byte(n)
    return math.floor(c / n) % 256
  end
  local function hex2(n)
    local h = ""
    for s = 4, 0, -4 do
      h = h .. string.format("%X", math.floor(byte(n) / 2^s) % 16)
    end
    return h
  end
  -- El largo se imprime como el REPARTO REAL si la capa mezcla, no como el
  -- `largo` de la capa, que en ese caso es solo el valor por defecto. Con el
  -- campo `largos` lleno se cuentan las repeticiones de cada alto: asi se ve de
  -- un vistazo si las cantidades pedidas son las que hay.
  local reparto
  if d.largos then
    local cuenta, orden = {}, {}
    for _, v in ipairs(d.largos) do
      if not cuenta[v] then cuenta[v] = 0; orden[#orden + 1] = v end
      cuenta[v] = cuenta[v] + 1
    end
    table.sort(orden)
    local partes = {}
    for _, v in ipairs(orden) do partes[#partes + 1] = v .. "px:" .. cuenta[v] end
    reparto = table.concat(partes, " ")
  else
    reparto = tostring(d.largo)
  end
  print(string.format("[yuyu]   %-7s n=%-3d largo=%-12s dx=%-3d grosor=%d "
    .. "col=%s%s%s / a=%s dur=%-4d (%.2f s) suelo=%s",
    d.et, d.n, reparto, d.dx, d.grosor,
    hex2(16777216), hex2(65536), hex2(256), hex2(1),
    d.dur, d.dur / 60, d.suelo))
end
print(string.format("[yuyu] techo de la imagen del juego (ULTIMA_FILA) = %d", ULTIMA_FILA))
print(string.format("[yuyu] C.Rain muere en el suelo + %d filas, con ese techo", ABAJO_OFF))

-- Las zonas del HUD se imprimen con el prefijo [hud] porque son MEDIDAS sobre una
-- captura del usuario, no datos ledos del ROM: no van a DATOS_VERIFICADOS.md.
--
-- Los dos rectangulos YA NO SE DIBUJAN: son zona de no-dibujado de verdad. Se
-- imprimen igual, para poder copiar las coordenadas.
if GUIAS then
  print(string.format("[yuyu] MEDICION HUD activa. %d zonas de no-dibujado, en px de JUEGO:",
    #HUD_ZONAS))
  for i = 1, #HUD_ZONAS do
    local z = HUD_ZONAS[i]
    local vx1, vy1 = de_juego(z.x1, z.y1)
    local vx2, vy2 = de_juego(z.x2, z.y2)
    print(string.format("[hud]   zona %d  juego x %d..%d y %d..%d  ->  "
      .. "ventana x %d..%d y %d..%d   (%d x %d px)",
      i, z.x1, z.x2, z.y1, z.y2, vx1, vx2, vy1, vy2,
      z.x2 - z.x1 + 1, z.y2 - z.y1 + 1))
  end
  print("[hud] Aplica a las TRES capas: la lluvia NO se dibuja dentro de la zona.")
  print("[hud] Las zonas son de JUEGO: el margen lo pone de_juego() al dibujar,")
  print("[hud] asi que valen con cualquier relacion de aspecto.")
  print("[hud] Lo que SIGUE dibujandose es de medicion, y es de otro tema:")
  print("[hud]   marco AMARILLO  los bordes reales de la imagen del juego")
  print("[hud]   linea MAGENTA   donde muere C.Rain")
  print("[hud]   CYAN           y=0, y=SPAWN_Y y rayitas cada 32 filas")
end

-- SOLO PARA EL AUTOTEST (test_hitbox_hud.lua).
--
-- Expone el LARGO REAL de cada gota, que es un local y desde el test no se
-- puede leer. Es de SOLO LECTURA: no dibuja, no lee ni escribe la memoria del
-- juego y no cambia el efecto. El test lo pide poniendo _G.__yuyu_test
-- ANTES de cargar el script; en el emulador no se crea nunca.
--
-- Por que hace falta: el largo ya no se puede leer de lo DIBUJADO. Una
-- gota recortada por los paneles del HUD o por su linea de muerte sale mas
-- corta que su largo, asi que un |dy| de 3 puede ser una gota de 3 o una de 7
-- recortada: el dibujo no dice cual es. Con el stock, si.
if _G.__yuyu_test then
  _G.__yuyu_test.altos_por_capa = function()
    local salida = {}
    for u = 1, #LLUVIA_DEF do
      local fila = {}
      for i = 1, LLUVIA_DEF[u].n do fila[i] = lluvia[u][i].largo end
      salida[LLUVIA_DEF[u].et] = fila
    end
    return salida
  end
  -- Cuantas gotas hay VIVAS por capa. De SOLO LECTURA.
  --
  -- Por que hace falta, y es lo mismo que arriba pero para el gate de pelea: "no
  -- se dibuja ninguna linea" y "no hay ninguna gota viva" son afirmaciones
  -- distintas, y la segunda es la que importa. Un gate que se limitara a no
  -- dibujar dejaria las gotas colgadas en el aire, y al arrancar la pelea
  -- siguiente aparecerian todas de golpe en el punto donde las congelo. Con
  -- esto el banco mira el ESTADO, no la salida.
  _G.__yuyu_test.vivas_por_capa = function()
    local salida = {}
    for u = 1, #LLUVIA_DEF do
      local n = 0
      for i = 1, LLUVIA_DEF[u].n do if lluvia[u][i].viva then n = n + 1 end end
      salida[LLUVIA_DEF[u].et] = n
    end
    return salida
  end
  -- El gate, tal cual lo calcula el script. Para que el banco pueda comprobar el
  -- VALOR y no solo su efecto sobre el dibujo.
  _G.__yuyu_test.en_pelea = function() return en_pelea() end
  -- El total de gotas vivas, en UNA linea. Existe para que el banco no tenga que
  -- declarar mas locales: `test_hitbox_hud.lua` esta al limite de los 200 locals de
  -- Lua y agregar dos variables lo hace fallar al CARGAR, con un error que no
  -- menciona la linea.
  _G.__yuyu_test.vivas_totales = function()
    local n = 0
    for t = 1, #LLUVIA_DEF do
      for i = 1, LLUVIA_DEF[t].n do
        if lluvia[t][i].viva then n = n + 1 end
      end
    end
    return n
  end
  -- Cuantas gotas se DIBUJARON de verdad en el ultimo `draw_lluvia`. El banco lo
  -- necesita porque un contador que siempre da 0 es indistinguible de "no hay
  -- lluvia" y de "el contador esta roto": asi, con una llamada, se sabe cual de las
  -- dos cosas es.
  _G.__yuyu_test.gotas_dibujadas = function() return gotas_dibujadas end

  -- --- LO QUE NECESITA LA SECCION 9z: LAS FASES DEL FINAL DE LA PELEA ---
  --
  -- Todo de SOLO LECTURA, igual que arriba, y por el mismo motivo: el estado de la
  -- maquina son locals, y el banco no puede verlos. Se expone el VALOR y no solo el
  -- efecto, para que una prueba no pueda pasar por el motivo equivocado.

  -- El nombre de la fase, como texto. Texto y no numero para que el fallo diga
  -- "SLOW" en vez de "1", que no dice nada.
  _G.__yuyu_test.fase_nombre = function() return NOMBRES_FASE[fase + 1] end
  -- El `dur` de cada capa, por indice. De SOLO LECTURA.
  --
  -- Por que hace falta: el banco antes NO afirmaba las duraciones, y se vio por
  -- mutacion (cambiar H.Rain de 39 a 40 dejaba las 204 pruebas en verde). El banco no
  -- mide el tiempo que tarda una gota, asi que un `dur` equivocado no cambia ninguna
  -- de las cosas que cuenta. Con esto el valor queda atado al numero escrito en el
  -- test, que es el que se ACORDO.
  --
  -- OJO: es exactamente el patron de `COLA_FRAMES`. El numero esta escrito a mano en
  -- el banco (`ESP.durs`), no ledo de aca y recalculado, porque si el test lo sacara
  -- del script seria una asercion auto-confirmante: los dos se equivocarian juntos.
  _G.__yuyu_test.dur_por_capa = function()
    local salida = {}
    for t = 1, #LLUVIA_DEF do salida[t] = LLUVIA_DEF[t].dur end
    return salida
  end
  -- Los dos numeros que definen la maquina, para que el banco mida contra EL
  -- SCRIPT y no contra una copia del 120 escrita a mano en el test (que seria una
  -- asercion auto-confirmante: si el script y el test se equivocan juntos, verde).
  _G.__yuyu_test.COLA_FRAMES = function() return COLA_FRAMES end
  _G.__yuyu_test.MULT_SLOWMO = function() return MULT_SLOWMO end
  -- La Y de UNA gota, en pixeles de JUEGO y con decimales (es `linea / dur * mult`,
  -- una division). Es lo que permite medir la MITAD de velocidad de verdad, y no
  -- solo comprobar que hay un 0.5 escrito en una variable.
  _G.__yuyu_test.y_gota = function(t, i)
    local p = lluvia[t][i]
    return p.viva and p.y or nil
  end
end
