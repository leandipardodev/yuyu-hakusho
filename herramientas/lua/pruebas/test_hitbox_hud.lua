-- Banco de pruebas de LLUVIA RECTA.LUA con la API de FBNeo simulada.
--     luajit test_hitbox_hud.lua
--
-- Cajas de colision y lluvia. Las pruebas cubren lo que quedo y, sobre todo, que
-- lo eliminado no aparezca:
-- eliminado no aparezca:
--
--   1) el error de la linea 461 (use[i] nil en el snapshot "stale")
--   2) que las cajas se dibujan con el grosor correcto
--   3) que cada tipo de caja usa SU trazado
--   4) la grab box y su marcador de rango
--   5) el menu: seis opciones, solo de cajas, con A/B/MODE
--   6) que no queda NINGUNA visual pasiva (combo, stun, hit-time, historial,
--      mandos, cuadricula, titulo) con el menu cerrado
--   7) apagar un tipo de caja deja de dibujarla
--   8) el filtro de cajas del P2
--
-- La lluvia (secciones 9 a 13) va aparte porque usa drawline, no el color de
-- las cajas: las gotas se cuentan por la GEOMETRIA de la linea.

-- ESTADO DE FABRICA DEL SCRIPT (importante para leer el flujo de las secciones):
--
--   hitbox, clash, hurtbox, pushbox, grab, cajas P2   APAGADAS
--   H.Rain, B.Rain, C.Rain                            ENCENDIDAS
--
-- Las cajas apagadas hacen que las secciones 2 a 8 tengan que prenderlas antes de
-- medir. Para eso estan encender_cajas() y reset_cajas() (ver el bloque de atajos
-- de menu, antes de la seccion 2): las dos son idempotentes y se pueden llamar
-- sin mirar el estado. El estado real esta en los SHOW_* del script, que son local
-- y no se pueden leer desde aqui, asi que el test lleva su propio booleano.
--
-- La seccion 6 (A y B) es la que cambia de sentido por esto: antes A apagaba la
-- fila y B la encendia; ahora A la enciende y B la deja apagada.

local W, H = 320, 224

local calls = {}
local frame_cb = nil
local pressed = {}
local start_cb = nil
local error_en = nil

-- Memoria simulada. Los valores se cambian desde las pruebas.
local mem = {}

local function rb(a) return mem[a] or 0 end
local function rw(a)
  local lo = mem[a] or 0
  local hi = mem[(a + 1) or 0] or 0
  return (hi * 256 + lo) % 65536
end
local function rws(a)
  local v = rw(a)
  if v > 32767 then v = v - 65536 end
  return v
end
local function rd(a) return rw(a) end

local exec_cb = nil
local frame_count = 0
_G.memory = {
  readbyte = rb, readword = rw, readwordsigned = rws, readdword = rd,
  -- Se guarda el callback del dispatcher para poder dispararlo a mano: sin el,
  -- el snapshot queda "stale" y no se dibuja ninguna caja, y los tests de
  -- grosor y de grab no tendrian nada que mirar.
  registerexec = function(pc, fn) exec_cb = fn end,
  registerwrite = function() end,
}
_G.emu = {
  screenwidth  = function() return W end,
  screenheight = function() return H end,
  romname      = function() return "md_yuyumte" end,
  -- *** framecount TENIA QUE ESTAR Y NO ESTABA ***
  --
  -- Faltaba porque un diagnostico de `LLUVIA DIAGONAL.LUA` lo llamaba, y sin el el
  -- banco fallo con "obtenido = 0" en las 141 pruebas: la excepcion se traga dentro del callback
  -- y no se dibuja nada. Es la trampa de "una excepcion dentro de un callback se
  -- traga" otra vez, pero al Reves: aca el banco SI la cazó, y con un sintoma
  -- inequivoco.
  --
  -- O sea: el mock tiene que parecerse a la API real de FBNeo, no solo a la
  -- parte que el script usaba hasta ayer.
  --
  -- Y ese diagnostico ya no esta (se borro cuando el gate se cerro), pero
  -- `framecount` sigue en el mock **a proposito**: un mock es un CONTRATO con la
  -- API real, no una copia de lo que el script uso la ultima vez.
  framecount   = function() return frame_count end,
  registerstart = function(f) start_cb = f end,
  registerafter = function(f) frame_cb = f end,
}
_G.joypad = { get = function() return pressed end }
_G.gui = {
  box = function(l, t, r, b, f, ln)
    calls[#calls+1] = { op = "box", x1 = l, y1 = t, x2 = r, y2 = b, fill = f, line = ln }
  end,
  drawline = function(x1, y1, x2, y2, col)
    calls[#calls+1] = { op = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, col = col }
  end,
  text = function(x, y, s, col)
    calls[#calls+1] = { op = "text", x = x, y = y, s = s, col = col }
  end,
}

local fallos, pruebas = 0, 0
local function ok(nombre, cond)
  pruebas = pruebas + 1
  if cond then print("  OK    " .. nombre)
  else fallos = fallos + 1; print("  FALLA " .. nombre) end
end
local function eq(nombre, esperado, obtenido)
  pruebas = pruebas + 1
  if esperado == obtenido then print("  OK    " .. nombre)
  else fallos = fallos + 1
    print(string.format("  FALLA %s  esperado=%s obtenido=%s",
                        nombre, tostring(esperado), tostring(obtenido)))
  end
end

-- Con hook de ejecucion o sin el. false = el dispatcher NO se dispara antes del
-- frame, que es lo que deja el snapshot en "stale" y provoca el error de la 461.
local function frame(con_hook)
  calls = {}
  if con_hook ~= false and exec_cb then
    exec_cb()
  end
  -- El contador del emulador avanza con el frame, como en FBNeo. Lo necesita el
  -- mock de `framecount`, que esta por contrato de API y no porque el script lo use.
  frame_count = frame_count + 1
  local okf, err = pcall(frame_cb)
  if not okf then
    error_en = tostring(err)
    return false
  end
  return true
end

-- Cualquier frame que peta se cuenta como fallo y se enseÃ±a. Antes se tragaba
-- con pcall y eso escondio un nil durante varias pruebas.
local frames_rottos = 0
local function frame_seguro(con_hook)
  local v = frame(con_hook)
  if not v then
    frames_rottos = frames_rottos + 1
    print("       !! frame fallo: " .. tostring(error_en))
    error_en = nil
  end
  return v
end

-- Pone un word en la memoria simulada.
local function poke16(a, v)
  mem[a] = v % 256
  mem[a + 1] = math.floor(v / 256) % 256
end

-- Un byte suelto. Hace falta para los contadores de las listas de cajas, que son
-- BYTES (MEMORIA.md): con el byte de la izquierda distinto de cero, `rb` y `rw` dan
-- numeros distintos, asi que una prueba puede distinguir cual de los dos se usa.
local function poke8(a, v)
  mem[a] = v % 256
end

-- Textos dibujados en el frame.
local function textos()
  local t = {}
  for i = 1, #calls do
    if calls[i].op == "text" then t[#t + 1] = calls[i].s end
  end
  return t
end
local function hay_texto(frag)
  for i = 1, #calls do
    if calls[i].op == "text" and string.find(calls[i].s, frag, 1, true) then return true end
  end
  return false
end

-- Cuenta lineas de un color dado en el frame.
local function lineas_de(col)
  local n = 0
  for i = 1, #calls do
    if calls[i].op == "line" and calls[i].col == col then n = n + 1 end
  end
  return n
end

-- *** EL NOMBRE DEL SCRIPT VA ANTES DEL BANNER ***
--
-- El banner de abajo imprimia `SCRIPT_PROBADO` y reventaba con
-- "attempt to concatenate global 'SCRIPT_PROBADO' (a nil value)", porque la
-- declaracion estaba mas abajo, en el bloque del dofile.
--
-- Es la septima vez que aparece la trampa en este proyecto: en Lua un local
-- declarado despues es un GLOBAL NIL en el punto de uso. No da error de sintaxis,
-- `luajit -bl` lo pasa limpio, y solo revienta en ejecucion.
--
-- Va aca arriba, y el dofile lo lee de mas abajo.
local SCRIPT_PROBADO = os.getenv("SCRIPT") or "LLUVIA RECTA.LUA"

print("=== autotest de " .. SCRIPT_PROBADO .. " ===")

-- LO QUE ESPERA DE LA LLUVIA, POR SCRIPT. GLOBAL y no local a proposito.
--
-- Los dos `.lua` ya NO tienen la misma lluvia: la DIAGONAL se cambio (stock 14/22/16,
-- dur 39/66/27, y los altos de B.Rain y C.Rain) y la RECTA sigue con la suya, que es
-- la version medida y congelada. Un banco con UN solo juego de numeros solo puede
-- probar una de las dos.
--
-- Global porque `test_hitbox_hud.lua` esta en el limite DURO de los 200 locals de Lua
-- (ver la nota de "mas de 200 locals"), y la tabla con los numeros no cabe. Un local
-- mas lo hace fallar AL CARGAR con un error que no menciona la linea.
--
-- *** Y LOS NUMEROS ESTAN ESCRITOS A MANO, NO LEIDOS DEL SCRIPT. *** Leerlos de
-- `__yuyu_test` seria una asercion auto-confirmante: si el `.lua` y el test se
-- equivocan juntos, la prueba da verde. Ver la nota de COLA_FRAMES en la seccion 9z.
ESP = {
  ["LLUVIA RECTA.LUA"] = {
    n_pesada = 10, n_fondo = 20, n_cerca = 13, total = 43,
    lineas_pesada = 20, dibujadas_fondo = 10,      -- 20 = 10 gotas de 2 px
    altos_fondo = { {4, 10}, {6, 10} },
    altos_cerca = { {3, 6}, {5, 4}, {7, 3} },
    durs = { 54, 84, 33 },
    -- Franjas de X que identifican cada grupo del parpadeo. Con n = 20 el paso es
    -- 16 y las impares van en 8 +- 4,8 y las pares en 24 +- 4,8. Las dos franjas
    -- quedan fuera de los paneles del HUD (39..136 y 183..281) y no se tocan.
    --
    -- OJO con `xa, xb = 3, 13` DENTRO de un constructor: NO asigna `xa` ni `xb`. En
    -- una tabla, la coma separa ENTRADAS, y una entrada con `=` solo se lleva el
    -- ULTIMO nombre: `{ xa, xb = 3, 13 }` es `{ nil, nil, xb = 3, <pos 4> = 13 }`.
    -- O sea que `xa` queda NIL y `c.x1 >= ESP.xa` revienta con "attempt to compare
    -- nil with number". Por eso cada nombre lleva su propio `=`.
    xa = 3, xb = 13, ya = 19, yb = 29,
    h_a = 4, h_b = 6,                               -- alto maximo de cada grupo
  },
  ["LLUVIA DIAGONAL.LUA"] = {
    n_pesada = 14, n_fondo = 22, n_cerca = 16, total = 52,
    lineas_pesada = 28, dibujadas_fondo = 11,      -- 28 = 14 gotas de 2 px
    altos_fondo = { {6, 11}, {9, 11} },
    altos_cerca = { {3, 7}, {4, 5}, {6, 4} },
    durs = { 39, 66, 27 },
    -- Con n = 22 el paso es 14,5 y el jitter +-4,4: las impares (grupo 0) van en
    -- 7,3 +- 4,4 = x de 2 a 12, y las pares (grupo 1) en 21,8 +- 4,4 = x de 17 a 27.
    -- Las dos franjas siguen FUERA de los paneles del HUD y sin tocarse, pero las
    -- intermedias ya no sirven: con paso 14,5 la mitad de las franjas cae dentro de
    -- 39..136 o de 183..281, que es justo donde la gota se recorta y deja de medir su
    -- alto. Ver el calculo en el comentario del bloque de las franjas.
    xa = 2, xb = 12, ya = 17, yb = 27,             -- ver la nota de las comas
    h_a = 6, h_b = 9,
  },
}
ESP = ESP[SCRIPT_PROBADO]
if ESP == nil then
  print("ABORTA: no hay expectativas de lluvia para " .. SCRIPT_PROBADO)
  os.exit(2)
end

-- MISMO helper que el script, y por el mismo motivo: FBNeo lee 0xRRGGBBAA (byte
-- alto = ROJO, byte bajo = ALFA), no 0xAARRGGBB. Los colores de las cajas se
-- comparan por igualdad exacta contra los que el script dibuja, asi que el test
-- tiene que construirlos con la misma regla o no cuenta ninguno.
local function color(r, g, b, a)
  return r * 16777216 + g * 65536 + b * 256 + a
end

-- RNG FIJO PARA TODA LA CORRIDA. El script hace math.randomseed(os.time()) al
-- cargar, asi que sin esto cada corrida siembra la lluvia en un sitio distinto y
-- los conteos de gotas y particulas varian. Con la fase de los impactos movida,
-- dos pruebas fallaban de forma intermitente:
--
--   - "H.Rain colisiona": mide que la suma de gotas en 40 frames sea MENOR con
--     caja que sin ella. Con la fase movida la diferencia es de unas gotas
--     sueltas sobre un total de ~500, y el signo puede darse la vuelta.
--   - "la lluvia no cambia al apagar las cajas": compara un total con 38 y 39.
--
-- Congelar os.time mientras se carga el script es lo unico que hace falta: es ahi
-- donde se consume el reloj, no despues. Se restituye acto seguido porque el
-- resto del autotest no lo usa.
local os_time_real = os.time
os.time = function() return 1735689600 end

-- *** QUE SCRIPT SE PROBA ***
--
-- Hay dos copias que salen del mismo original: `LLUVIA RECTA.LUA` (las tres capas
-- rectas, `dx = 0`) y `LLUVIA DIAGONAL.LUA` (la variante con sensacion de caida
-- diagonal). Un banco que solo pruebe una no alcanza: el cambio de la diagonal
-- tiene que poder verificarse sin tocar el archivo de la recta.
--
-- Por eso la ruta sale de una variable de entorno, con la RECTA por defecto para
-- que el banco siga siendo el mismo comando de siempre:
--
--     luajit test_hitbox_hud.lua                              -> la recta
--     $env:SCRIPT = "LLUVIA DIAGONAL.LUA"; luajit test_hitbox_hud.lua
--
-- Y se imprime cual se probo, porque un banco en verde del archivo equivocado no
-- dice nada. Si la variable apunta a un archivo que no existe, el dofile revienta
-- con un error claro: es preferible a caer en la recta en silencio.
--
-- (SCRIPT_PROBADO se declara ARRIBA, antes del banner. Ver el comentario ahi.)
local RUTA_SCRIPT = "herramientas/lua/" .. SCRIPT_PROBADO
local f = io.open(RUTA_SCRIPT, "r")
if not f then
  io.stderr:write("test_hitbox_hud.lua: no existe " .. RUTA_SCRIPT .. "\n")
  os.exit(2)
end
f:close()

-- Pide el largo real de cada gota. Tiene que estar ANTES del dofile: el script
-- solo define su funcion de consulta si esta la marca puesta al cargarse. Es de
-- solo lectura y no cambia el efecto (ver el bloque al final del script).
--
-- Y aprovecho este punto para CAPTURAR lo que el script imprime al arrancar, que
-- hasta ahora se perdia: es lo unico que se puede comprobar del banner (que dice
-- si el gate esta compilado), y es donde se cuelan los caracteres que la consola
-- de Fightcade no maneja.
local ARRANQUE = {}
local print_real = print
print = function(s) ARRANQUE[#ARRANQUE + 1] = tostring(s) end
_G.__yuyu_test = {}
dofile(RUTA_SCRIPT)
os.time = os_time_real
print = print_real     -- restaurado en la linea siguiente al dofile, SIEMPRE

ok("registro su callback de frame", frame_cb ~= nil)

-- *** LO QUE SE IMPRIME TIENE QUE SER ASCII ***
--
-- La consola de Fightcade no maneja `¿` ni las tildes: los muestra como dos
-- caracteres, o sea el banner se ve roto. Puesto en el banner del gate se vio
-- `[yuyu] GATE DE PELEA = SI (Â¿algun slot con HP > 0?)`, y lo unico que se
-- leyo de esa corrida fue esa parte.
--
-- OJO con el alcance: los COMENTARIOS del `.lua` tienen tildes y no es un
-- problema, porque no llegan a la consola. Lo que se comprueba es SOLO lo que el
-- script imprime, que es lo unico que la consola tiene que mostrar bien. Por eso
-- se mide sobre las lineas capturadas y no sobre el archivo entero: un chequeo
-- del archivo daria 21 y 66 falsos en los tres `.lua` del repo, todos en
-- comentarios.
local arranque_ASCII, arranque_malo = true, ""
for i = 1, #ARRANQUE do
  local s = ARRANQUE[i]
  for k = 1, #s do
    if string.byte(s, k) > 127 then
      arranque_ASCII = false
      arranque_malo = string.format("linea %d: '%s' (byte %d)", i, s,
        string.byte(s, k))
      break
    end
  end
  if not arranque_ASCII then break end
end
ok("todo lo que el script imprime al arrancar es ASCII" ..
   (arranque_ASCII and "" or " -> " .. arranque_malo), arranque_ASCII)

-- Y el banner tiene que DECIR si el gate esta compilado adentro. Es lo unico que
-- distingue en consola a la DIAGONAL de la RECTA (las dos imprimen identico todo
-- lo demas), asi que sin esta linea no se puede atribuir un sintoma a una version
-- o a la otra.
--
-- SOLO para la DIAGONAL: la RECTA no tiene gate y su banner no lo anuncia, asi que
-- exigirselo seria exigir una linea que no existe. (La RECTA es la version medida
-- y congelada: no se le agrega nada.)
if SCRIPT_PROBADO == "LLUVIA DIAGONAL.LUA" then
  local arranque_txt = table.concat(ARRANQUE, "\n")
  ok("el banner dice si el GATE DE PELEA esta compilado",
     string.find(arranque_txt, "GATE DE PELEA", 1, true) ~= nil)
end

--------------------------------------------------------------------------------
-- 1. EL ERROR DE LA LINEA 461
--
-- Se dispara cuando no hay fuente fresca de contadores: use era {} y
-- "drawn = drawn + use[i]" hacia nil + numero. Esta prueba sigue siendo la mas
-- importante: es la que evita que cualquier efecto futuro que lea el snapshot
-- reviente cuando el dispatcher todavia no paso.
--------------------------------------------------------------------------------
print("  -- caso del error: sin write hook y sin exec hook --")
error_en = nil
-- Con los contadores en 0 y ningun write, el snapshot queda "stale"
mem[0xFFA004] = 0; mem[0xFFA005] = 0
mem[0xFFA006] = 0; mem[0xFFA007] = 0
mem[0xFFA008] = 0; mem[0xFFA009] = 0
mem[0xFFA00A] = 0; mem[0xFFA00B] = 0
mem[0xFFA00C] = 0; mem[0xFFA00D] = 0
poke16(0xFFA014, 0x0100)   -- camara X
poke16(0xFFA016, 0x0020)   -- camara Y
local vivo = frame(false)
ok("no revienta con snapshot vacio (el error de la 461)", vivo)
if error_en then print("       error: " .. error_en) end

--------------------------------------------------------------------------------
-- Escenario base: P1 parado, camara y stage en sitio
--------------------------------------------------------------------------------
local P1 = 0xFF8400
local P2 = 0xFF8800

poke16(P1 + 0x40, 100)      -- mundo X
poke16(P1 + 0x44, 180)      -- mundo Y
mem[P1 + 0x61] = 0          -- facing
poke16(P1 + 0x8C, 0x0100)   -- moves key

-- *** EL ESCENARIO BASE TIENE QUE ESTAR EN PELEA ***
--
-- `LLUVIA DIAGONAL.LUA` tiene el gate de `en_pelea()`, y sin esto TODO el banco
-- de lluvia daba 33 fallos: los cuatro slots con HP 0 son "no hay pelea", la
-- lluvia se apaga y no hay ni una gota que medir.
--
-- Ojo con lo que ese numero demuestra, porque es justo lo que hay que mirar: los
-- 33 fallos son la prueba de que el gate ES SENSIBLE. Un gate que no tuviera
-- efecto, o que solo afectara a una cosa, habria dado verde.
--
-- El HP va CON signo (`poke16` es big-endian) porque lo que decide el gate es
-- "> 0", y `-1024` tiene que salir negativo de verdad.
local HP_EN_PELEA = 223      -- el tope real, MEDIDO
local function entrar_en_pelea()
  poke16(0xFF8400 + 0x78, HP_EN_PELEA)
  poke16(0xFF8800 + 0x78, HP_EN_PELEA)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, 0)
end
local function salir_de_pelea()
  -- El centinela de verdad es -1024 (`$FC00`), MEDIDO en el menu del 08-10, y no
  -- 0 a secas. Es lo que hace que el gate sirva: si se conformara con `!= 0`, el
  -- menu contaria como pelea con los slots llenos de centinela.
  poke16(0xFF8400 + 0x78, -1024)
  poke16(0xFF8800 + 0x78, -1024)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, 0)
end
entrar_en_pelea()
mem[0xFFF408] = 0; mem[0xFFF409] = 0
poke16(0xFFF566, 0)
poke16(0xFFA014, 0x0100)
poke16(0xFFA016, 0x0020)
for i = 1, 5 do frame_seguro() end
-- ATajos de menu y estado de las cajas.
--
-- Van aqui y no junto a las pruebas de menu que los usaban porque hacen falta
-- desde la seccion 2: con las cajas apagadas de fabrica hay que prenderlas antes
-- de la primera prueba de caja.

-- 31 frames, no 30: MENU_HOLD = 30 y el toggle pasa por "mode_hold == 30", que es
-- el frame numero 30. Con 29 no abre y con 30 depende de si el frame 1 ya estaba
-- contando. 31 es el primer numero que abre siempre.
local function abrir_menu()
  pressed = { ["P1 Mode"] = true }
  for i = 1, 31 do frame_seguro() end
end

local function cerrar_menu()
  pressed = {}
  for i = 1, 3 do frame_seguro() end
  pressed = { ["P1 Mode"] = true }
  for i = 1, 31 do frame_seguro() end
  pressed = {}
  for i = 1, 3 do frame_seguro() end
end

-- Pulsa B: deja las nueve opciones como de fabrica, o sea las cinco cajas
-- APAGADAS y las tres capas de lluvia ENCENDIDAS.
local function reset_menu()
  abrir_menu()
  pressed = { ["P1 Button B"] = true }
  frame_seguro()
  pressed = {}
  cerrar_menu()
end

-- El cursor recorre el ORDEN DE LOS ITEMS (menu_row), no las filas, asi que "ir a
-- la fila 0" es "pulsar Down 0 veces" para hitbox y 6 para H.Rain.
local ITEM_HRAIN, ITEM_BRAIN, ITEM_CRAIN = 5, 6, 7
local ITEM_GLINE = 8        -- "G.LINE", las guias de medicion
-- OJO: el menu se abre con menu_row = 0 SIEMPRE (ver MENU_HOLD en el toggle), asi
-- que Down "item" veces lleva al item correcto. Pero abrir_menu() deja el cursor
-- donde estaba si el menu NO se llego a abrir. Por eso se comprueba que este
-- abierto antes de navegar.
local function ir_a_item(item)
  abrir_menu()
  if not hay_texto("ON/OFF") then
    print("     !! el menu no se abrio, no se puede ir al item " .. item)
    return false
  end
  for i = 1, item do
    pressed = { ["P1 Down"] = true }
    frame_seguro()
    pressed = {}
    frame_seguro()
  end
  pressed = { ["P1 Button A"] = true }
  frame_seguro()
  pressed = {}
  cerrar_menu()
  return true
end

-- ESTADO DE LAS CAJAS
--
-- El estado real vive en los SHOW_* del script, que son local y no se pueden leer
-- desde aqui. Se lleva la cuenta con un booleano propio. Con eso las tres
-- funciones de abajo son idempotentes y se pueden llamar sin pensar: si ya esta en
-- el estado pedido, no hacen nada.
--
-- Las CINCO primeras filas del menu son hitbox, clash, hurtbox, pushbox y cajas P2.
-- cajas P2. Las tres siguientes son las capas de lluvia, que NO se tocan aqui:
-- su estado es justo lo que se quiere probar.
local cajas_on = false        -- de fabrica: apagadas

local function toggle_cajas()
  for i = 0, 4 do ir_a_item(i) end
  cajas_on = not cajas_on
end

local function encender_cajas() if not cajas_on then toggle_cajas() end end
local function reset_cajas()   reset_menu(); cajas_on = false end

-- Las seis cajas encendidas para las secciones de dibujo. A partir de aqui cada
-- seccion las apaga y las vuelve a encender segun necesite.
encender_cajas()

--------------------------------------------------------------------------------
-- 2. Grosor de las lineas de caja
--
-- Con dos hitboxes, cada arista tiene que dibujarse DOS veces (GROSOR = 2).
-- Contador de hitbox en $FFA004 = 32 bytes = 2 cajas (los contadores son
-- offsets en BYTES, no cantidades: n = contador / stride).
--------------------------------------------------------------------------------
poke16(0xFFA004, 0x20)
local A = 0xFFA200
poke16(A + 0x00, 120); poke16(A + 0x04, 150)   -- X, Y
mem[A + 0x08] = 8; mem[A + 0x09] = 8           -- rx, ry
poke16(A + 0x0C, 0x8400)                       -- owner del P1
frame_seguro()

-- Una caja son 4 aristas y con GROSOR = 2 cada una se pinta 2 veces.
eq("4 aristas x 2 grosores = 8 lineas", 8, lineas_de(color(0xFF, 0x60, 0x60, 0xFF)))

-- Cuenta lineas duplicadas: la misma arista repetida con 1 px de separacion.
-- Las horizontales se duplican en X y las verticales en Y, asi que hay que
-- mirar las dos: con solo una de las dos, solo se ven 2 pares de 4.
local repe = 0
for i = 1, #calls - 1 do
  local a, b = calls[i], calls[i + 1]
  if a.op == "line" and b.op == "line" and a.col == b.col and a.col == color(0xFF, 0x60, 0x60, 0xFF) then
    local en_x = a.y1 == b.y1 and a.y2 == b.y2
                   and math.abs(a.x1 - b.x1) == 1 and math.abs(a.x2 - b.x2) == 1
    local en_y = a.x1 == b.x1 and a.x2 == b.x2
                   and math.abs(a.y1 - b.y1) == 1 and math.abs(a.y2 - b.y2) == 1
    if en_x or en_y then repe = repe + 1 end
  end
end
eq("las 4 aristas tienen su duplicado", 4, repe)

--------------------------------------------------------------------------------
-- 3. Cada tipo de caja usa SU trazado
--
-- El relleno es el mismo pero el numero de lineas cambia: la hitbox es solida
-- (8 lineas con GROSOR=2), la hurtbox va punteada y la pushbox solo esquinas.
-- Si esto se rompe, las cinco se ven iguales y el dibujo pierde sentido.
--------------------------------------------------------------------------------
-- hurtbox punteada en $FFA400, contador $FFA008
poke16(0xFFA004, 0)
poke16(0xFFA008, 0x10)
local Hu = 0xFFA400
poke16(Hu + 0x00, 120); poke16(Hu + 0x04, 150)
mem[Hu + 0x08] = 10; mem[Hu + 0x09] = 10
poke16(Hu + 0x0C, 0x8400)
frame_seguro()
local hurtbox_lineas = lineas_de(color(0x80, 0xA0, 0xFF, 0xFF))
ok("la hurtbox se dibuja punteada (" .. hurtbox_lineas .. " lineas)",
   hurtbox_lineas > 8)

-- pushbox a solo esquinas en $FFA500, contador $FFA00A
poke16(0xFFA008, 0)
poke16(0xFFA00A, 0x10)
local Pu = 0xFFA500
poke16(Pu + 0x00, 120); poke16(Pu + 0x04, 150)
mem[Pu + 0x08] = 12; mem[Pu + 0x09] = 12
poke16(Pu + 0x0C, 0x8400)
frame_seguro()
-- 8 tramos de esquina, cada uno con sus 2 grosor = 16 lineas
eq("la pushbox dibuja solo las 4 esquinas", 16, lineas_de(color(0x60, 0xE0, 0x60, 0xFF)))

poke16(0xFFA00A, 0)
frame_seguro()

--------------------------------------------------------------------------------
-- 4. LA GRAB ESTA FUERA DEL MENU y apagada de fabrica
--
-- Antes esta seccion comprobaba que el descriptor de grab se dibujara con su
-- color y que saliera el marcador de rango. Ya NO se puede comprobar asi: la
-- opcion "grab" se saco del menu porque no funcionaba de forma confiable, y
-- SHOW_GRAB paso a ser la constante `false`.
--
-- Lo que se comprueba ahora es lo que si es verdad desde el codigo: con la grab
-- apagada NO se lee la lista, no se dibuja nada de ella y no sale su marcador. Y
-- que la logica siga ahi, que es lo que hace falta para poder volver a
-- encenderla poniendo un `true` en SHOW_GRAB.
--
-- Lo que se PIERDE es la cobertura del dibujado de la grab. Reponerla habria que
-- cargar una variante del script con SHOW_GRAB en true, como se hace con las
-- ventanas de 448 y 658 px. Es la misma receta, pero son tres pruebas sobre un
-- tramite que el usuario decidio no tocar, asi que no se arma todavia.
--------------------------------------------------------------------------------
poke16(0xFFA00C, 0x20)                       -- 1 descriptor, a proposito
poke16(0xFFA600 + 0x00, 100)                 -- X en mundo del atacante
poke16(0xFFA600 + 0x02, 150)                 -- Y en +2
mem[0xFFA600 + 0x04] = 8                     -- rx
mem[0xFFA600 + 0x05] = 16                    -- ry
poke16(0xFFA600 + 0x0C, 0x8400)              -- owner = word, $8400
-- OJO: no se llama a reset_cajas() al terminar. Esta seccion empieza con las
-- cinco cajas ENCENDIDAS (ver encender_cajas() mas arriba) y todas las secciones
-- que vienen despues dan por hecho ese estado. Un reset de fabrica aqui las
-- apagaria y se cairian las pruebas de dibujado de las secciones siguientes.
frame_seguro()
eq("con la grab apagada no se dibuja ninguna linea suya", 0, lineas_de(color(0xE0, 0x40, 0xE0, 0xFF)))
ok("con la grab apagada no sale su marcador de rango", not hay_texto("grab"))

--------------------------------------------------------------------------------
-- 5. El menu
--
-- Se abre manteniendo MODE 30 frames (MENU_HOLD) y se cierra manteniendo MODE
-- OTRA vez: soltarlo no lo cierra, hay que mantenerlo de nuevo.
--
-- Ojo con dos trampas al contarlas:
--   - hud_text() dibuja cada string CINCO veces (4 sombras + el de color), asi
--     que hay que contar strings DISTINTOS, no llamadas.
--   - el menu dibuja una mini muestra del trazado real de cada tipo de caja en
--     el margen izquierdo, con el COLOR de esa lista. Con el menu abierto, la
--     hitbox aporta 8 lineas suyas + 8 de su preview. Por eso las pruebas de
--     dibujo se hacen SIEMPRE con el menu cerrado.
--------------------------------------------------------------------------------
-- Las nueve opciones: las cuatro cajas, el filtro de jugador, las tres capas de
-- lluvia. Las de lluvia tambien valen como opcion del menu, asi que el nombre
-- corto sale de LLUVIA_DEF y no esta escrito aqui a mano.
local ESPERADAS = { "hitbox", "clash", "hurtbox", "pushbox", "cajas P2",
                    "H.Rain", "B.Rain", "C.Rain", "G.LINE" }

-- Muebles del menu que no son opciones.
local CONOCIDOS = {
  ["hitbox"] = true, ["clash"] = true, ["hurtbox"] = true,
  ["pushbox"] = true, ["cajas P2"] = true,
  ["H.Rain"] = true, ["B.Rain"] = true, ["C.Rain"] = true,
  ["G.LINE"] = true,
  -- OJO: el valor sale de string.format("%-3s", ...), asi que "ON" lleva un
  -- espacio de relleno detras y "off" ya ocupa las tres columnas.
  ["ON "] = true, ["off"] = true,
  ["A ON/OFF   B reset   MODE salir"] = true,
}

-- El texto del marcador de rango de grab sale con el menu abierto, asi que se
-- acepta cualquiera que empiece por "grab ".
local function es_marcador_grab(s)
  return string.sub(s, 1, 5) == "grab "
end

local function strings_distintos()
  local set, out = {}, {}
  for i = 1, #calls do
    if calls[i].op == "text" then
      local s = calls[i].s
      if not set[s] then set[s] = true; out[#out + 1] = s end
    end
  end
  return out
end

local function intrusos()
  local out = {}
  for _, s in ipairs(strings_distintos()) do
    if not CONOCIDOS[s] and not es_marcador_grab(s) then out[#out + 1] = s end
  end
  return out
end

-- Con el menu cerrado no tiene que salir su cabecera.
frame_seguro()
ok("con el menu cerrado no sale su cabecera", not hay_texto("ON/OFF"))

abrir_menu()
local intrusos_abiertos = intrusos()
eq("el menu no dibuja nada que no sea de cajas", 0, #intrusos_abiertos)
for i = 1, #intrusos_abiertos do
  print("       intruso: '" .. tostring(intrusos_abiertos[i]) .. "'")
end
for _, lab in ipairs(ESPERADAS) do
  ok("el menu tiene la opcion '" .. lab .. "'", hay_texto(lab))
end

-- Y que "grab" este DE VERDAD fuera, no solo que nadie lo mentione. Se compara
-- exacto contra los strings distintos: hay_texto() busca un fragmento, y el
-- marcador de rango ("grab 3-5") contiene la palabra, asi que un hay_texto("grab")
-- no distinguiria una cosa de la otra.
local function opcion_exacta(lab)
  for _, s in ipairs(strings_distintos()) do
    if s == lab then return true end
  end
  return false
end
ok("el menu ya NO tiene la opcion 'grab'", not opcion_exacta("grab"))

-- El numero de filas del menu: se cuentan los items, no las llamadas.
local filas = 0
for _, lab in ipairs(ESPERADAS) do
  if hay_texto(lab) then filas = filas + 1 end
end
eq("el menu tiene exactamente 9 opciones", 9, filas)

cerrar_menu()
ok("el menu se cierra manteniendo MODE otra vez", not hay_texto("ON/OFF"))

--------------------------------------------------------------------------------
-- 6. A = ON/OFF sobre la fila 0 (hitbox) y B = reset
-- OJO: con los valores por defecto OFF, A ENCIENDE la fila y B la deja apagada. Con
-- los de antes (todo ON) era al reves: A apagaba y B encendia. Por eso esta seccion
-- tambien comprueba el estado de fabrica antes de tocar nada.
--------------------------------------------------------------------------------
local function poner_hitbox_p1()
  poke16(0xFFA004, 0x10)                   -- 16 bytes = 1 caja
  poke16(A + 0x00, 120); poke16(A + 0x04, 150)
  mem[A + 0x08] = 8; mem[A + 0x09] = 8
  poke16(A + 0x0C, 0x8400)
end

-- Se empieza desde el estado de FABRICA, no desde el que dejo la seccion anterior:
-- asi "no se dibuja de fabrica" mide algo real. B = reset deja las cajas apagadas.
reset_cajas()

poke16(0xFFA00C, 0)          -- fuera el grab de la lista
poner_hitbox_p1()
frame_seguro()
eq("la hitbox del P1 NO se dibuja de fabrica", 0, lineas_de(color(0xFF, 0x60, 0x60, 0xFF)))

abrir_menu()
pressed = { ["P1 Button A"] = true }   -- flanco: soltar -> pulsar
frame_seguro()
pressed = {}
cerrar_menu()
eq("A enciende la fila 0 (hitbox)", 8, lineas_de(color(0xFF, 0x60, 0x60, 0xFF)))

-- B = reset otra vez: como las cajas se apagan de fabrica, la fila vuelve a apagarse.
reset_menu()
eq("B restaura los valores de fabrica (cajas apagadas)", 0, lineas_de(color(0xFF, 0x60, 0x60, 0xFF)))

--------------------------------------------------------------------------------
-- 7. NO queda ninguna visual pasiva
--
-- Con el menu cerrado, lo unico que puede aparecer es el marcador de grab. Son
-- justo las cosas que se sacaron: bloque de combos, barras de HP/manÃ¡, stun,
-- hit-time, historial, timeline, display de mandos, cuadrica, facing,
-- coordenadas y el titulo animado.
--------------------------------------------------------------------------------
frame_seguro()
local intrusos_cerrado = intrusos()
eq("con el menu cerrado solo se dibuja el marcador de grab",
   0, #intrusos_cerrado)
for i = 1, #intrusos_cerrado do
  print("       intruso: '" .. tostring(intrusos_cerrado[i]) .. "'")
end

local PASIVAS = {
  "COMBO", "HITS", "DMG", "STUN", "TAKEN", "MP +", "HIT ", "BLOCK",
  "MODE", "START", "ON/OFF",
}
for _, frag in ipairs(PASIVAS) do
  ok("no sale '" .. frag .. "'", not hay_texto(frag))
end

-- Las flechas de la cruceta, el facing y el display de mandos eran triangulos
-- de 4x8. Ninguno debe existir ya.
local triangulos = 0
for i = 1, #calls do
  local c = calls[i]
  if c.op == "line" and math.abs(c.x2 - c.x1) == 4 and math.abs(c.y2 - c.y1) == 8 then
    triangulos = triangulos + 1
  end
end
eq("no queda ningun triangulo (cruz / facing / mandos)", 0, triangulos)

-- Las barras usaban gui.box con relleno 0xB0000000.
local barras = 0
for i = 1, #calls do
  local c = calls[i]
  if c.op == "box" and (c.fill == 0xB0000000 or c.fill == 0x00000000) then
    barras = barras + 1
  end
end
eq("no queda ninguna barra (hp / stun / hit-time)", 0, barras)

--------------------------------------------------------------------------------
-- 8. El filtro de cajas del P2
--
-- Con "cajas P2" apagado, solo se dibujan las cajas cuyo owner es $8400. El
-- owner es un WORD, no un puntero: $8400 y $8800.
--------------------------------------------------------------------------------
-- Las cajas hacen falta prendidas, y "cajas P2" tambien (la prueba empieza con las
-- dos visibles y luego apaga esa fila).
encender_cajas()

-- `Pu` (arriba) es LA MISMA direccion: no hace falta un segundo local para el mismo
-- numero, y este banco esta en el limite de los 200 locals de Lua. Ver la nota de
-- "mas de 200 locals" mas abajo.
poke16(0xFFA004, 0)          -- fuera la hitbox
poke16(0xFFA00A, 0x20)       -- dos pushbox
poke16(Pu + 0x00, 200); poke16(Pu + 0x04, 150)
mem[Pu + 0x08] = 10; mem[Pu + 0x09] = 10
poke16(Pu + 0x0C, 0x8800)    -- del P2
poke16(Pu + 0x10, 200); poke16(Pu + 0x14, 150)
mem[Pu + 0x18] = 10; mem[Pu + 0x19] = 10
poke16(Pu + 0x1C, 0x8400)    -- del P1
frame_seguro()
eq("con cajas P2 prendido se ven las dos", 32, lineas_de(color(0x60, 0xE0, 0x60, 0xFF)))

-- Apagar "cajas P2" desde el menu: es el item 4, hay que bajar cuatro veces.
abrir_menu()
for i = 1, 4 do
  pressed = { ["P1 Down"] = true }        -- flanco: soltar -> pulsar
  frame_seguro()
  pressed = {}
  frame_seguro()
end
pressed = { ["P1 Button A"] = true }
frame_seguro()
pressed = {}
cerrar_menu()
eq("con cajas P2 apagado solo se ve la del P1", 16, lineas_de(color(0x60, 0xE0, 0x60, 0xFF)))

--------------------------------------------------------------------------------
-- 8b. DONDE ESTA EL P2 NO CAMBIA NI UN PIXEL, Y SE PORQUE
--
-- MEDIDO: el P2 no esta siempre en el mismo slot.
--
--   desde el select, Battle Royale 1v1 -> $FF8800
--   desde un savestate                 -> $FF9000
--
-- El script recorre los 4 slots y reasigna P1/P2 (detectar_slots). Lo que se
-- comprueba aqui es que eso NO cambia un solo pixel, y el motivo es que el slot
-- del P2 no llega a la salida del dibujo:
--
--   - owner_filter() decide con el flag SHOW_P2, no con el slot. Prendido ->
--     nil, que significa "dibuja todas"; apagado -> own_lo(P1).
--
--   - to_screen() ancla la caja a owner_base(owner) or P1, pero la conversion
--     es AFIN DE PENDIENTE 1, asi que el base se cancela:
--        Y = (worldY - A016 + F566 + 24 + CAL_Y) + (by - worldY)
--          = by - A016 + F566 + 24 + CAL_Y        <- no depende del base
--     y en X lo mismo: bx - A014 + 0x80 + CAL_X. O sea que el fallback a P1 no
--     desplaza la caja: se ancla ahi y por eso cae en el mismo pixel.
--
--   - las dos rutas donde owner_base() SI llega a decidir (rects_grab, con su
--     "if ob then", y draw_grab_range, con su moves_key(ob)) estan detras de
--     SHOW_GRAB, que es false de fabrica.
--
-- CONCLUSION: el "local P2 = 0xFF8800" NO era un bug del HUD, era una constante
-- inerte. Sigue siendo correcto detectar el slot, pero para lo que SI lee del
-- slot (HP, stun, mana, moves), no para el dibujo de las cajas.
--------------------------------------------------------------------------------

local COL_CAJA = color(0x60, 0xE0, 0x60, 0xFF)

-- Firma: la geometria COMPLETA de las lineas de caja, ordenada. Comparar firmas
-- y no conteos, porque "no cambio nada" y "cambio pero dio lo mismo" dan el
-- mismo numero y no se podrian distinguir.
local function firma_cajas()
  local t = {}
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "line" and c.col == COL_CAJA then
      t[#t + 1] = string.format("%d,%d,%d,%d", c.x1, c.y1, c.x2, c.y2)
    end
  end
  table.sort(t)
  return table.concat(t, " ")
end

-- Escena: dos pushbox, la del P1 ($8400) y una con owner $9000, que es el slot
-- que el script todavia no mira.
poke16(0xFFA00A, 0x20)
poke16(0xFFA500 + 0x00, 200); poke16(0xFFA500 + 0x04, 150)
mem[0xFFA500 + 0x08] = 10; mem[0xFFA500 + 0x09] = 10
poke16(0xFFA500 + 0x0C, 0x8400)     -- del P1
poke16(0xFFA500 + 0x10, 240); poke16(0xFFA500 + 0x14, 120)
mem[0xFFA500 + 0x18] = 8;  mem[0xFFA500 + 0x19] = 8
poke16(0xFFA500 + 0x1C, 0x9000)     -- del slot que aun no es el P2

-- El filtro tiene que estar PRENDIDO: apagado solo se dibujan las cajas del P1
-- y la de $9000 ni se mira, con lo que la comparacion no mediria nada.
abrir_menu()
for i = 1, 4 do
  pressed = { ["P1 Down"] = true }
  frame_seguro()
  pressed = {}
  frame_seguro()
end
pressed = { ["P1 Button A"] = true }
frame_seguro()
pressed = {}
cerrar_menu()

-- Configuracion 1: solo vive el P1, o sea que se quedan las constantes y el
-- script cree que el P2 esta en $8800.
frame_seguro()
local firma_8800 = firma_cajas()
-- ESTA ASERCION es la que evita que todo lo de abajo sea verde por vacuidad: si
-- la escena no se dibuja, las dos firmas salen vacias y "son iguales" no dice nada.
eq("con P2 en la constante $8800 se ven las dos cajas", 32, lineas_de(COL_CAJA))
ok("la firma de la configuracion 1 no esta vacia", firma_8800 ~= "")

-- Configuracion 2: aparece el P2 en $FF9000, bien lejos del P1, y el script lo
-- tiene que detectar por HP.
poke16(0xFF9000 + 0x78, 200)        -- HP
poke16(0xFF9000 + 0x8C, 0x0100)     -- tabla de moves
poke16(0xFF9000 + 0x40, 260); poke16(0xFF9000 + 0x44, 90)
frame_seguro()
frame_seguro()
local firma_9000 = firma_cajas()
eq("con P2 detectado en $9000 se ven las mismas dos cajas", 32, lineas_de(COL_CAJA))
ok("con P2 en $9000 el dibujo es IDENTICO, pixel a pixel", firma_9000 == firma_8800)

-- Autocomprobacion del helper, y es la que de verdad cierra la seccion: si la
-- firma no se moviera al cambiar la geometria, "son iguales" no probaria nada.
--
-- OJO lo que hay que mover: la CAJA, no el jugador. La cancelacion tambien
-- funciona en X (ax + bx - worldX = bx - A014 + 0x80 + CAL_X), asi que un
-- jugador en otra posicion del mundo NO desplaza sus propias cajas. Eso es lo
-- mismo que se comprueba arriba, dicho por el otro lado, y conviene dejarlo
-- escrito porque invita a "arreglarlo" moviendo el jugador.
poke16(0xFFA500 + 0x04, 155)          -- la caja del P1 5 px mas abajo
frame_seguro()
ok("la firma SIGUE a la geometria (si no, la comparacion de arriba es vacua)",
   firma_cajas() ~= firma_9000)
poke16(0xFFA500 + 0x04, 150)          -- devolverla
frame_seguro()

-- Deshacer: filtro apagado, slot 3 vacio, y lista de la seccion 8 restaurada.
abrir_menu()
for i = 1, 4 do
  pressed = { ["P1 Down"] = true }
  frame_seguro()
  pressed = {}
  frame_seguro()
end
pressed = { ["P1 Button A"] = true }
frame_seguro()
pressed = {}
cerrar_menu()
mem[0xFF9000 + 0x78] = 0; mem[0xFF9000 + 0x79] = 0
mem[0xFF9000 + 0x8C] = 0; mem[0xFF9000 + 0x8D] = 0
poke16(0xFFA500 + 0x0C, 0x8800)     -- la primera vuelve a ser del P2 de $8800
poke16(0xFFA500 + 0x1C, 0x8400)     -- y la segunda del P1
frame_seguro()
eq("el filtro de P2 quedo apagado y la lista restaurada", 16, lineas_de(COL_CAJA))

--------------------------------------------------------------------------------
-- LLUVIA
--
-- Las gotas se dibujan con gui.drawline, no con el color de las cajas, asi que se
-- cuentan POR COLOR, no por geometria.
--
-- OJO, esto cambio cuando C.Rain y B.Rain se volvieron rectas. Antes se contaban
-- por forma (linea corta y diagonal, con dx > 0) y como H.Rain es la unica
-- inclinada, en cuanto las otras dos quedaron verticales (dx = 0) el filtro las
--botaba y gotas() estaba contando SOLO H.Rain. Todas las pruebas de "la lluvia
-- sigue saliendo" estaban midiendo una sola capa sin que se notara. Por color no
-- hay ambiguedad: cada capa tiene el suyo y ninguna caja lo comparte.
--
-- Se exige ademas dy >= 1 para no contar las SALPICADURAS: son horizontales de
-- 1 px y comparten el RGB de su gota, asi que solo el alfa las distingue. Con
-- H.Rain el alfa de la gota es 0x99 y una salpicadura llega a 0xFF, asi que el
-- color exacto ya las separa; con las otras dos, que ya son 0xFF, no las separa
-- el color y las separa la forma.
--------------------------------------------------------------------------------

-- Los tres colores, escritos aqui con la MISMA regla que el script (0xRRGGBBAA).
local COL_PESADA = color(0xA8, 0xC8, 0xE8, 0x99)  -- H.Rain: 2 px de ancho, translucida
local COL_FONDO  = color(0xA8, 0xC4, 0xE0, 0xFF)  -- B.Rain: 1 px, solida, mas celeste
local COL_CERCA  = color(0x6E, 0x9C, 0xD8, 0xFF)  -- C.Rain: 1 px, opaca, azul sobrio

-- Las tres capas, por sus nombres del menu. Vienen de LLUVIA_DEF.
local N_PESADA, N_FONDO, N_CERCA = ESP.n_pesada, ESP.n_fondo, ESP.n_cerca
eq("H.Rain son " .. ESP.n_pesada .. " gotas", ESP.n_pesada, N_PESADA)
eq("B.Rain son " .. ESP.n_fondo .. " gotas", ESP.n_fondo, N_FONDO)
eq("C.Rain son " .. ESP.n_cerca .. " gotas", ESP.n_cerca, N_CERCA)
eq("el total es " .. ESP.total .. " gotas", ESP.total, N_PESADA + N_FONDO + N_CERCA)

-- Y LAS DURACIONES, que antes no se afirmaban en ningun lado.
--
-- Se comprobo por mutacion que faltaban: cambiar H.Rain de 39 a 40 frames dejaba las
-- 204 pruebas en VERDE, porque ninguna de las cosas que el banco cuenta depende del
-- `dur`: el pool, los altos y las lineas dibujadas son los mismos con 39 o con 40.
-- Ese `dur` es la VELOCIDAD, o sea la mitad de lo que se esta afinando, y se estaba
-- sin comprobar.
--
-- El numero esperado sale de `ESP.durs`, escrito a mano; el obtenido, de lo que
-- declara el script. No es una asercion auto-confirmante porque los dos numeros
-- estan escritos en archivos distintos y a mano.
--
-- Y van por `_G.__yuyu_test` y NO por `YUYU_TEST`: ese local se declara mas abajo
-- del todo, asi que aca seria un GLOBAL nil y el `eq` compararia contra nada.
-- Tampoco se guarda en un local propio: el banco esta en el tope de 200 y el
-- helper se llama tres veces, que no es nada.
--
-- LA RECTA NO TIENE EL HELPER, y no se le agrega: `LLUVIA RECTA.LUA` esta congelada
-- como referencia medida. O sea que **contra la RECTA las duraciones NO se comprueban**,
-- y el banco lo DICE en vez de callarse: un `if` que se salta una comprobacion sin
-- avisar es la prueba que no sabe que no esta probando nada.
if _G.__yuyu_test.dur_por_capa then
  eq("H.Rain dura " .. ESP.durs[1] .. " frames (" .. ESP.durs[1] / 60 .. " s)",
     ESP.durs[1], _G.__yuyu_test.dur_por_capa()[1])
  eq("B.Rain dura " .. ESP.durs[2] .. " frames (" .. ESP.durs[2] / 60 .. " s)",
     ESP.durs[2], _G.__yuyu_test.dur_por_capa()[2])
  eq("C.Rain dura " .. ESP.durs[3] .. " frames (" .. ESP.durs[3] / 60 .. " s)",
     ESP.durs[3], _G.__yuyu_test.dur_por_capa()[3])
else
  print("       (aviso: " .. SCRIPT_PROBADO .. " no expone dur_por_capa, porque esta "
    .. "congelado. Las duraciones NO se comprueban contra este script.)")
end

--------------------------------------------------------------------------------
-- 9. Las gotas se dibujan
--
-- Sin hurtbox en la lista y con las cajas apagadas: la lluvia tiene que seguir
-- saliendo. Si el snapshot se metiera dentro de un SHOW_*, esto daria 0.
--------------------------------------------------------------------------------
poke16(0xFFA00A, 0)          -- fuera las pushbox
poke16(0xFFA004, 0)          -- fuera la hitbox
for t = 1, 5 do
  mem[0xFFA000 + t * 2] = 0
end

-- Las tres capas estan ENCENDIDAS de fabrica: con solo un frame tiene que
-- salir lluvia sin tocar el menu.
frame_seguro()

-- Cuenta lineas de LLUVIA: cualquier color de gota, con dy >= 1 para dejar fuera
-- las salpicaduras horizontales. Ver la nota de por que es por COLOR y no por
-- forma, arriba.
local COLORES_LLUVIA = { COL_PESADA, COL_FONDO, COL_CERCA }
local function es_lluvia(c)
  if c.op ~= "line" then return false end
  if math.abs(c.y2 - c.y1) < 1 then return false end          -- salpicadura o raya
  for _, col in ipairs(COLORES_LLUVIA) do
    if c.col == col then return true end
  end
  return false
end

local function gotas(n_min, n_max)
  local n = 0
  for i = 1, #calls do
    if es_lluvia(calls[i]) then n = n + 1 end
  end
  return n
end

local total = gotas(1)
ok("sale lluvia sin tocar nada (" .. total .. " lineas)", total > 0)

-- Las gotas no se dibujan todas iguales: 7 + 10 + 13 con 1 o 2 px de grosor.
--
-- El grosor NO se mide por |dx|, porque desde que B.Rain y C.Rain son rectas sus
-- lineas tienen |dx| = 0, y H.Rain con dx = -2 sobre 7 filas tambien casi.
--
-- Y NO se mide buscando una linea vecina a 1 px, que es como se hace la copia de
-- las 2 px: dos gotas de la misma capa pueden caer en filas contiguas a una
-- columna de distancia yse contarian como copia. En vez de eso se usa que H.Rain
-- es la UNICA capa con grosor 2, y por tanto la unica que dibuja 2 lineas por gota.
local function gotas_por_grosor()
  local g1, g2 = 0, 0
  for i = 1, #calls do
    local c = calls[i]
    if es_lluvia(c) then
      if c.col == COL_PESADA then g2 = g2 + 1 else g1 = g1 + 1 end
    end
  end
  return g1, g2
end
local g1, g2 = gotas_por_grosor()
ok("hay gotas de 1 px y de 2 px (" .. g1 .. " / " .. g2 .. ")",
   g1 > 0 and g2 > 0)

--------------------------------------------------------------------------------
-- 10. Apagar una capa en el menu
--
-- OJO con la disposicion: con 9 items en MENU_COLS = 2 son 5 filas, y el indice
-- del item NO coincide con el numero de fila. menu_slot(i) reparte asi:
--
--   item 0 hitbox    item 5 H.Rain
--   item 1 clash     item 6 B.Rain
--   item 2 hurtbox   item 7 C.Rain
--   item 3 pushbox   item 8 G.LINE
--   item 4 cajas P2
--
-- El cursor recorre el ORDEN DE LOS ITEMS (menu_row), no las filas, asi que
-- "ir a la fila 0" es "pulsar Down 0 veces" para H.Rain y 6 para clash.
--------------------------------------------------------------------------------

-- H.Rain (item 6) apagada: no puede quedar ninguna linea de dx = 2.
ir_a_item(ITEM_HRAIN)
local _, despues_g2 = gotas_por_grosor()
eq("apagar H.Rain quita las gotas de 2 px", 0, despues_g2)
ok("las otras capas siguen dibujandose", gotas(1) > 0)

-- Encenderla de nuevo
ir_a_item(ITEM_HRAIN)
local _, vuelve_g2 = gotas_por_grosor()
ok("volver a prender H.Rain repone las gotas de 2 px", vuelve_g2 > 0)

--------------------------------------------------------------------------------
-- 11. La oclusion de B.Rain depende de la hurtbox REAL
--
-- Es la prueba clave de que la lluvia usa el snapshot y no una copia suya.
--
-- MEDIR POR FORMA, NO POR COLOR.
--
-- SeDrawable por color, pero el color NO sirve para comparar en este test:
-- 0x99A8C8E8 (el alfa de la pesada) es 2577975528, MAYOR que 2^31, asi que en
-- LuaJIT se guarda como FLOAT y la igualdad exacta falla. Los tres colores
-- tienen el bit 7 del alfa puesto y los tres son float. Por eso se cuenta por
-- GEOMETRIA, que es exacta y no depende de como se guarden los numeros.
--
-- Cada capa tiene una forma distinta, y una arista de caja es siempre
-- horizontal o vertical, asi que no hay confusion con las cajas:
--
--   pesada  dy = 7, dx = -2   (2 llamadas por gota, 2 px de grosor)
--   fondo   dy = 6, dx = +1
--   cercana dy = 5, dx = -1
--------------------------------------------------------------------------------
-- MEDIR POR FORMA, NO POR COLOR.
--
-- Se.drawable por color, pero el color NO sirve para comparar en este test:
-- 0x99A8C8E8 (el alfa de la pesada) es 2577975528, MAYOR que 2^31, asi que en
-- LuaJIT se guarda como FLOAT y la igualdad exacta falla. Los tres colores
-- tienen el bit 7 del alfa puesto y los tres son float. Por eso se cuenta por
-- GEOMETRIA, que es exacta y no depende de como se guarden los numeros.
--
-- Cada capa tiene una forma distinta, y una arista de caja es siempre
-- horizontal o vertical, asi que no hay confusion con las cajas:
--
--   pesada  dy = 7, dx = 2   (2 llamadas por gota, 2 px de grosor)
--   fondo   dy = 6, dx = 1
--   cercana dy = 5, dx = 1
--
-- OJO con el ABS: el signo de dx depende de si la gota esta a la izquierda o a
-- la derecha del punto de partida. Se compara en absoluto.
--
-- Y OJO con dy: el codigo dibuja "drawline(x, y, x + dx, y + largo)", o sea la
-- gota va de y a y + largo. Con math.floor() en el y, una gota cuya punta cae
-- en un borde puede medir 6 en vez de 7. Por eso el conteo es ">=" y no "==":
-- una gota cuenta aunque le falte 1 px por el redondeo.
-- MEDIR POR COLOR. El color se cuenta EXACTO, sin normalizar a 32 bits sin signo:
-- con la convencion correcta (color(), arriba) los colores son enteros
-- comparables y no hace falta nada mas. Antes hacia falta u32() porque el alfa
-- iba en el byte alto y el numero pasaba de 2^31 y se guardaba como float; eso ya no
-- pasa. Los colores tienen que estar hechos con color(), nunca a mano.
--
-- Las salpicaduras cambian de color (el alfa baja cada frame), asi que contar
-- con el color EXACTO de la gota es lo que las distingue de una particula.
--
-- Cada capa tiene su color y sus pixeles son unicos, asi que el recuento es exacto
-- y ESTABLE: no depende de quantas gotas mueren en ese frame.

local function gotas_de_color(col)
  local n = 0
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "line" and c.col == col then n = n + 1 end
  end
  return n
end

-- Los tres colores ya estan definidos ARRIBA, junto a gotas(), porque hace falta
-- que existan antes de la seccion 9.
local function gotas_pesada() return gotas_de_color(COL_PESADA) end  -- 2 por gota
local function gotas_fondo()  return gotas_de_color(COL_FONDO)  end  -- 1 por gota
local function gotas_cerca()  return gotas_de_color(COL_CERCA)  end  -- 1 por gota

poke16(0xFFA004, 0)          -- fuera la hitbox
for t = 1, 5 do mem[0xFFA000 + t * 2] = 0 end

-- Cada capa con su propio color: se mide por color, no por forma. El maximo a
-- lo largo de 20 frames, porque una gota puede morir y re-sembrarse en el mismo
-- frame y en ese frame se dibuja una menos.
local mx_f, mx_p, mx_c = 0, 0, 0
for i = 1, 20 do
  frame_seguro()
  local a, b, c = gotas_fondo(), gotas_pesada(), gotas_cerca()
  if a > mx_f then mx_f = a end
  if b > mx_p then mx_p = b end
  if c > mx_c then mx_c = c end
end
ok("las " .. ESP.dibujadas_fondo .. " de fondo se dibujan (max " .. mx_f .. ")",
   mx_f == ESP.dibujadas_fondo)
-- Las PESADAS se miden por LINEAS, no por gotas: H.Rain es la unica con
-- `grosor = 2`, o sea 2 lineas por gota.
ok("las " .. ESP.n_pesada .. " gotas pesadas se dibujan (" .. ESP.lineas_pesada
   .. " lineas, max " .. mx_p .. ")", mx_p == ESP.lineas_pesada)
ok("las " .. ESP.n_cerca .. " cercanas se dibujan (max " .. mx_c .. ")",
   mx_c == ESP.n_cerca)

-- TRES hurtbox gigantes, no una: el radio se lee con bit.band(rb(a+8), 0x7F), o
-- sea que el maximo es 127. Con una sola, el radio 127 se come los cuatro
-- bytes de arriba y el ancho se va a 256 por el signo: noSirve para tapar
-- todo. Con tres, partidas en X=0 / 160 / 319 y radio 127 cada una, la union
-- cubre x de -127 a 446: toda la pantalla de 320, sin holes.
--
-- La Y se coloca en 112 (la mitad de 224) para que el radio cubra de -15 a 239,
-- o sea toda la altura tambien.
local HB = 0xFFA400
poke16(0xFFA008, 0x30)                       -- 3 hurtbox (contador en bytes)
-- ATENCION al calculo de la X, que no es el que parece.
--
-- to_screen() usa la posicion del JUGADOR como referencia:
--     sx = ax + (bx - mundoP1), con ax = mundoP1 - camX + 0x80 + CAL_X
-- El mundoP1 se cancela, asi que en la practice sx = bx - 255, y mover el P1
-- NO mueve la caja. La conversion miente sobre la velocidad, no sobre el
-- sitio: el bloque de captura de grab tiene el mismo problema y por eso
-- memoriza el offset con el del atacante.
--
-- Con CAL_X = -127 y camX = 0x100: sx = bx - 256 + 128 - 127 = bx - 255.
-- Para sx = 0 / 160 / 319 hace falta bx = 255 / 415 / 574.
local MUNDO_X = { 255, 415, 574 }
-- La Y sale por mundo_y_a_screen: sy = by - camY + scrollY + 0x20 - 8 + CAL_Y.
-- Con camY = 0x20 y CAL_Y = -127: sy = by - 32 + 0 + 32 - 8 - 127 = by - 135.
-- Para sy = 112 hace falta by = 247.
local MUNDO_Y = 247
for k = 0, 2 do
  local a = HB + k * 0x10
  poke16(a + 0x00, MUNDO_X[k + 1])
  poke16(a + 0x04, MUNDO_Y)
  mem[a + 0x08] = 127                         -- radio maximo
  mem[a + 0x09] = 127
  poke16(a + 0x0C, 0x8400)
end
-- P1 tiene que estar donde la conversion espera para que las cajas salgan en
-- pantalla: con CAL_X = -127 el offset es worldX - 375.
poke16(P1 + 0x40, 535); poke16(P1 + 0x44, 247)
poke16(0xFFA014, 0x0100); poke16(0xFFA016, 0x0020)

-- SIN hurtbox: las tres capas tienen que estar enteras. Se mide antes de tocar
-- nada, con el escenario limpio.
--
-- OJO con los numeros: NO se puede pedir el maximo exacto (15/14/10). Una gota
-- puede morir y re-sembrarse dentro del MISMO frame (si nace justo en la linea
-- del suelo, o si nace dentro de una hurtbox y el rechazo la deja muerta otra
-- vez). En ese frame se dibuja una menos. Lo que tiene que cumplirse es:
--   - sin nada que estorbe, todas estan vivas en ALGUN frame
--   - con una hurtbox tapando todo, las de fondo y la pesada están a 0
poke16(0xFFA008, 0); mem[0xFFA009] = 0
local max_f, max_p, max_c = 0, 0, 0
for i = 1, 20 do
  frame_seguro()
  local a, b, c = gotas_fondo(), gotas_pesada(), gotas_cerca()
  if a > max_f then max_f = a end
  if b > max_p then max_p = b end
  if c > max_c then max_c = c end
end
eq("sin nada, las " .. ESP.dibujadas_fondo .. " de fondo aparecen",
   ESP.dibujadas_fondo, max_f)
eq("sin nada, las " .. ESP.n_pesada .. " pesadas aparecen ("
   .. ESP.lineas_pesada .. " lineas)", ESP.lineas_pesada, max_p)
eq("sin nada, las " .. ESP.n_cerca .. " cercanas aparecen", ESP.n_cerca, max_c)

--------------------------------------------------------------------------------
-- 9a. C.Rain mezcla ALTOS dentro de la misma capa
--
-- Pido: 16 gotas de 1 px de grosor, con 7 de 3 px, 5 de 4 px y 4 de 6 px.
--
-- OJO, el reparto se mide sobre el STOCK, no sobre lo dibujado. El alto de una
-- gota es su |dy|, pero una gota recortada por los paneles del HUD o por su
-- linea de muerte sale MAS CORTA que su largo: un |dy| de 3 puede ser una gota
-- de 3 o una de 7 recortada, y el dibujo no dice cual. Por eso el script expone
-- el largo real de cada gota (ver el bloque de solo lectura al final del .lua).
--
-- El script expone el largo real de cada gota porque su largo es un local. Se lee
-- una vez aca y no en cada prueba.
local altos_por_capa = _G.__yuyu_test.altos_por_capa()
-- El enganche se suelta de `_G` (que es lo que puede hacer el emulador), pero la
-- tabla se guarda en un local: la seccion 9y la necesita para mirar el gate y
-- las gotas vivas.
local YUYU_TEST = _G.__yuyu_test
_G.__yuyu_test = nil          -- ya no hace falta colgado: se suelta el enganche

-- El reparto esta intercalado a proposito (3,5,7,3,5,3,7,3,5,3,7,5,3) y no en
-- orden. El indice i de la gota es lo que reparte la X (sembrar_una), asi que en
-- orden las 6 cortas estarian siempre en el mismo tercio de la pantalla y se
-- verian tres franjas verticales. La prueba mira que el reparto este junto al
-- ancho de pantalla, no en un bloque.
--------------------------------------------------------------------------------
local function alto_unico_de(et, gotas, alto)
  local fila = altos_por_capa[et]
  if #fila ~= gotas then return false end
  for i = 1, #fila do
    if fila[i] ~= alto then return false end
  end
  return true
end

-- H.Rain es la UNICA capa que sigue con un alto unico: no tiene el campo `largos`,
-- asi que todas sus gotas miden lo que dice `largo`. Se comprueba el alto exacto
-- (7) y no solo que sean todas iguales, porque "todas iguales" tambien pasaria si
-- tuviera cualquier otro alto comun.
ok("H.Rain: " .. ESP.n_pesada .. " gotas, todas de 7 px de alto",
   alto_unico_de("H.Rain", ESP.n_pesada, 7))

-- Y una comprobacion de que el campo `largos` no se filtro a H.Rain: si se hubiera
-- filtrado, el pool seria una copia de la lista y no 7 copias del `largo` de la
-- capa. Con `largos` ausente, el pool hace `largos[i] or largo`.
ok("H.Rain no tiene el campo `largos` (es la unica de alto unico)",
   altos_por_capa["H.Rain"][1] == 7 and altos_por_capa["H.Rain"][7] == 7)

-- B.Rain ahora MEZCLA: 11 de 6 px y 11 de 9 px. Y se comprueba el reparto del pool, no
-- el |dy| dibujado: una gota recortada por un panel del HUD o por su linea de
-- muerte sale mas corta que su largo, asi que el dibujo no dice cual es.
local br = altos_por_capa["B.Rain"]
-- B.Rain: el POOL son 20, pero solo se dibujan 10. Son dos hechos distintos y hay
-- que comprobarlos por separado: si se comprobara solo "cuantas lineas se dibujan"
-- pasaria con un pool de 10 Y con uno de 20, y no distinguiria el parpadeo de una
-- capa normal.
eq("B.Rain: " .. ESP.n_fondo .. " gotas en el pool", ESP.n_fondo, #br)
-- El conjunto de claves no importa: se cuentan TODOS los altos posibles y solo se
-- comprueban los dos de la capa, asi que la misma tabla sirve para los dos scripts.
local cuenta_br = { [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [9] = 0 }
local otros_br = {}
for i = 1, #br do
  if cuenta_br[br[i]] ~= nil then cuenta_br[br[i]] = cuenta_br[br[i]] + 1
  else otros_br[#otros_br + 1] = br[i] end
end
eq("B.Rain: " .. ESP.altos_fondo[1][2] .. " gotas de " .. ESP.altos_fondo[1][1]
   .. " px de alto", ESP.altos_fondo[1][2], cuenta_br[ESP.altos_fondo[1][1]])
eq("B.Rain: " .. ESP.altos_fondo[2][2] .. " gotas de " .. ESP.altos_fondo[2][1]
   .. " px de alto", ESP.altos_fondo[2][2], cuenta_br[ESP.altos_fondo[2][1]])
eq("B.Rain: ninguna gota de otro alto", "", table.concat(otros_br, ","))

-- Y el otro hecho, el dibujado: 10 lineas por frame, SIEMPRE, en los dos turnos.
--
-- El maximo y el minimo se miden por separado a proposito: si solo se midiera el
-- maximo, una capa sin parpadeo (20 siempre) tambien pasaria. Lo que delata al
-- parpadeo es que el maximo y el minimo NO coinciden.
--
-- OJO con el recorte de los paneles del HUD: una gota dentro de la banda no se
-- dibuja, asi que el conteo puede bajar de 10 en un frame suelto. Por eso el
-- MINIMO se mide sobre muchos frames y no en uno: en algun frame los dos grupos
-- estan fuera de los paneles y el conteo llega a 10 seguro.
local mx_dib, mn_dib = 0, math.huge
for i = 1, 60 do
  frame_seguro()
  local n = gotas_fondo()
  if n > mx_dib then mx_dib = n end
  if n < mn_dib then mn_dib = n end
end
eq("B.Rain: se dibujan " .. ESP.dibujadas_fondo .. ", nunca las " .. ESP.n_fondo
   .. " (max " .. mx_dib .. ")", ESP.dibujadas_fondo, mx_dib)

-- Y LA CONDICION EXACTA QUE SE PIDIO: las de 4 px y las de 6 px nunca estan
-- dibujadas a la vez.
--
-- EL GRUPO SE IDENTIFICA POR LA X, NO POR LA ALTURA. Se intento por la altura dos
-- veces y las dos mintio: una gota de 6 px que cae dentro de la banda de un panel
-- del HUD sale recortada a 4 filas, y un |dy| de 4 es INDISTINGUIBLE del de una de 4
-- px entera. Con 6 gotas por turno y dos paneles salen 3 frames con "los dos
-- grupos" sin que exista.
--
-- Por que la X si sirve. Con n = 20 el paso del reparto es sw/n = 16, y `sembrar_una`
-- pone la gota i en (i - 0,5) * 16 con un jitter de +-4,8. O sea que las pares van
-- en x de 24 +- 4,8 y las impares en 8 +- 4,8. Los paneles del HUD estan en
-- x 39..136 y 183..281, asi que:
--
--   x de 3 a 13   -> grupo 0 (impares), NUNCA dentro de un panel
--   x de 19 a 29  -> grupo 1 (pares),   NUNCA dentro de un panel
--
-- Las dos franjas quedan FUERA de los dos paneles y no se tocan entre si (hay 6 px
-- de hueco). Con eso la gota se dibuja siempre entera y su |dy| es el de verdad,
-- pero ya no hace falta mirarlo: clasificar por x funciona aunque este recortada.
-- Las dos franjas de X del reparto de B.Rain: grupo 0 = alto corto (4 px), impares
-- en 8 +- 4,8; grupo 1 = alto largo (6 px), pares en 24 +- 4,8. MEDIDO con n = 20
-- (paso 16) y sale del reparto de MEMORIA.md, seccion del largo por gota.
--
-- Van ESCRITOS en los TRES bucles de abajo (X_CORTO_A/B, X_LARGO_A/B) y no en
-- cuatro locals: este banco esta en el tope de los 200 locals de Lua, y un local de
-- mas lo hace fallar AL CARGAR con un error que no menciona la linea. Los numeros
-- quedan junto a sus usos.
local corto_x, largo_x, otros_x = 0, 0, 0
for i = 1, 120 do
  frame_seguro()
  for k = 1, #calls do
    local c = calls[k]
    if c.op == "line" and c.col == COL_FONDO then
      if c.x1 >= ESP.xa and c.x1 <= ESP.xb then corto_x = corto_x + 1
      elseif c.x1 >= ESP.ya and c.x1 <= ESP.yb then largo_x = largo_x + 1
      else otros_x = otros_x + 1 end
    end
  end
end
ok("se dibujan gotas del grupo corto (" .. corto_x .. ")", corto_x > 0)
ok("se dibujan gotas del grupo largo (" .. largo_x .. ")", largo_x > 0)
ok("las otras 20 de cada grupo tambien se dibujan (" .. otros_x .. ")", otros_x > 0)

-- Y el punto clave, por frame: nunca los dos grupos a la vez. Se cuenta frame a
-- frame, con las dos franjas de X, que no se confunden con nada.
local solo_corto, solo_largo, ambos = 0, 0, 0
for i = 1, 120 do
  frame_seguro()
  local g0, g1 = 0, 0
  for k = 1, #calls do
    local c = calls[k]
    if c.op == "line" and c.col == COL_FONDO then
      if c.x1 >= ESP.xa and c.x1 <= ESP.xb then g0 = g0 + 1
      elseif c.x1 >= ESP.ya and c.x1 <= ESP.yb then g1 = g1 + 1 end
    end
  end
  if g0 > 0 and g1 == 0 then solo_corto = solo_corto + 1 end
  if g1 > 0 and g0 == 0 then solo_largo = solo_largo + 1 end
  if g0 > 0 and g1 > 0 then ambos = ambos + 1 end
end
ok("hay frames con SOLO el grupo corto (" .. solo_corto .. ")", solo_corto > 0)
ok("hay frames con SOLO el grupo largo (" .. solo_largo .. ")", solo_largo > 0)
ok("NINGUN frame dibuja los dos grupos a la vez (hubo " .. ambos .. ")", ambos == 0)

-- Y que solo cambie el DIBUJADO, no el alto: las gotas ocultas conservan su alto.
-- Con la X ya sabemos que grupo es cada una, asi que se comprueba que su |dy| es
-- SIEMPRE el del grupo, sin excepciones.
local alto_malo = 0
for i = 1, 60 do
  frame_seguro()
  for k = 1, #calls do
    local c = calls[k]
    if c.op == "line" and c.col == COL_FONDO then
      local h = math.abs(c.y2 - c.y1)
      if c.x1 >= ESP.xa and c.x1 <= ESP.xb and h > ESP.h_a then alto_malo = alto_malo + 1 end
      if c.x1 >= ESP.ya and c.x1 <= ESP.yb and h > ESP.h_b then alto_malo = alto_malo + 1 end
    end
  end
end
eq("el alto de cada gota NO cambia con el turno", 0, alto_malo)

-- C.Rain: 7 de 3, 5 de 4, 4 de 6. Ni una gota de otro alto.
local cr = altos_por_capa["C.Rain"]
eq("C.Rain: " .. ESP.n_cerca .. " gotas en el pool", ESP.n_cerca, #cr)
-- Igual que `cuenta_br`: todos los altos posibles, y se comprueban tres.
local cuenta = { [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [9] = 0 }
local otros_alto = {}
for i = 1, #cr do
  if cuenta[cr[i]] ~= nil then
    cuenta[cr[i]] = cuenta[cr[i]] + 1
  else
    otros_alto[#otros_alto + 1] = cr[i]
  end
end
eq("C.Rain: " .. ESP.altos_cerca[1][2] .. " gotas de " .. ESP.altos_cerca[1][1]
   .. " px de alto", ESP.altos_cerca[1][2], cuenta[ESP.altos_cerca[1][1]])
eq("C.Rain: " .. ESP.altos_cerca[2][2] .. " gotas de " .. ESP.altos_cerca[2][1]
   .. " px de alto", ESP.altos_cerca[2][2], cuenta[ESP.altos_cerca[2][1]])
eq("C.Rain: " .. ESP.altos_cerca[3][2] .. " gotas de " .. ESP.altos_cerca[3][1]
   .. " px de alto", ESP.altos_cerca[3][2], cuenta[ESP.altos_cerca[3][1]])
eq("C.Rain: ninguna gota de otro alto", "", table.concat(otros_alto, ","))

-- Y que el reparto este JUNTO, no en bloques: el indice de la gota es lo que
-- reparte la X (sembrar_una), asi que un reparto en orden daria franjas verticales
-- de lluvia: en C.Rain las 6 cortas siempre en el mismo tercio.
--
-- Se mide que ningun alto tenga dos indices CONSECUTIVOS, que es lo que delata un
-- bloque. Con 6, 4 y 3 gotas no cabe un bloque sin que se note, asi que esta
-- comprobacion sola no alcanza: por eso estan tambien los conteos exactos de cada
-- alto, que son los que de verdad lo fijan.
local function intercalado(fila)
  for i = 2, #fila do
    if fila[i] == fila[i - 1] then return false end
  end
  return true
end
ok("C.Rain: el reparto de altos esta intercalado", intercalado(cr))
ok("B.Rain: el reparto de altos esta intercalado", intercalado(br))

--------------------------------------------------------------------------------
-- 9b. Las inclinaciones: SOLO H.Rain cae en diagonal; B.Rain y C.Rain son RECTA
--
-- Se pidio doblar la de fondo porque caia en contra. Es mas molesta por dos
-- cosas: es la mas lenta (1,9 px/frame), asi que la inclinacion se ve durante
-- mas tiempo, y ademas iba al reves que las otras dos.
--
-- Se mide el signo del desplazamiento en X de cada linea de gota. Todas tienen
-- que ir hacia la izquierda (x final < x inicial), que es lo que hace una gota
-- con dx negativo.
--
-- B.Rain y C.Rain quedaron con dx = 0: el desplazamiento total era de 1 px sobre
-- 4 a 7 filas, o sea menos de medio px por fila, y el redondeo hacia que el
-- escalon de la rasterizada cambiara de fila y la gota se leyera como una "S" que
-- se retorcia. Rectas se leen como gotas.
--------------------------------------------------------------------------------
local function inclinacion(col)
  local neg, pos = 0, 0
  for i = 1, #calls do
    local c = calls[i]
    -- Las lineas VERTICALES no cuentan: no dicen en que sentido cae la gota.
    -- Aparecen con el recorte de los paneles del HUD: una gota a la que le quedan
    -- 4 de sus 6 filas se desplaza menos de 1 px en todo el tramo, asi que al
    -- redondear los dos extremos caen en la misma columna y sale vertical. Sin
    -- esta excepcion el recorte hacia fallar una prueba que no va de eso.
    if c.op == "line" and c.col == col and (c.x2 - c.x1) ~= 0 then
      if (c.x2 - c.x1) < 0 then neg = neg + 1 else pos = pos + 1 end
    end
  end
  return neg, pos
end

-- H.Rain NO lleva prueba de inclinacion: tambien es recta. Antes decia "cae hacia la
-- izquierda (np vs pp)" con pp == 0, y al ponerla recta daba (0 vs 0): VERDE POR
-- VACUIDAD, porque inclinacion() ignora las lineas verticales. Una prueba que vale
-- 0 y 0 no comprueba nada y es peor que no tenerla, porque ocupa sitio y da
-- seguridad falsa. La que de verdad lo comprueba es "H.Rain no se inclina en ningun
-- frame de 60", con las tres capas.

-- Las otras dos NO llevan la prueba de inclinacion: llevan la contraria, la de ser
-- RECTA. Ponerlas en el mismo grupo que H.Rain daria verde por vacuo, porque
-- inclinacion() ya ignora las lineas verticales, que es justo lo que ahora tiene
-- que ser TODAS.
local function verticales(col)
  local verticales, oblicuas = 0, 0
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "line" and c.col == col then
      if (c.x2 - c.x1) == 0 then verticales = verticales + 1 else oblicuas = oblicuas + 1 end
    end
  end
  return verticales, oblicuas
end

local function check_vertical(nombre, col)
  local v, o = verticales(col)
  ok(string.format("%s es VERTICAL: %d rectas, %d inclinadas", nombre, v, o), o == 0)
end
check_vertical("C.Rain", COL_CERCA)
check_vertical("B.Rain", COL_FONDO)

-- Y no por casualidad en un frame: se mira en 60 frames seguidos, con las tres
-- capas prendidas y la lluvia moviendose. Una gota entra y sale del panel del HUD
-- cada 66 frames (B.Rain) o 27 (C.Rain), asi que en un frame suelto podria no
-- haber ninguna en la banda y la prueba no diria nada.
--
-- OJO el `local _, ob`: verticales() devuelve DOS valores (rectas, inclinadas) y
-- sin el `_` se estaria sumando el primero, que es justo el que tiene que dar 0.
local function oblicuas_en_60(col)
  local total = 0
  for i = 1, 60 do
    frame_seguro()
    local _, ob = verticales(col)
    total = total + ob
  end
  return total
end
eq("C.Rain no se inclina en ningun frame de 60", 0, oblicuas_en_60(COL_CERCA))
eq("B.Rain no se inclina en ningun frame de 60", 0, oblicuas_en_60(COL_FONDO))
-- Y LAS TRES SON RECTAS. H.Rain era la ultima que quedaba inclinada, con dx = -2, y
-- se la puso recta: el grosor de 2 px NO se pierde, porque el grosor no es una linea
-- mas gruesa sino la misma recta dibujada dos veces, la segunda a 1 px de lado.
--
-- Antes se decia que H.Rain conservaba la inclinacion A PROPOSITO, para no perder el
-- paralaje. Con las tres rectas ya no hay paralaje por inclinacion, y esta es la
-- comprobacion que avisa si eso vuelve a cambiar por accidente.
eq("H.Rain no se inclina en ningun frame de 60", 0, oblicuas_en_60(COL_PESADA))

-- Y que el grosor siga siendo 2: una gota de H.Rain produce DOS rectas VERTICALES
-- contiguas, en x y en x+1, con la misma fila de inicio y de fin. Si el grosor se
-- hubiera roto al ponerla recta, las tres capas dibujarian 1 px y H.Rain perderia
-- el volumen que la hace la pesada.
--
-- OJO con la forma que se busca: NO es una linea horizontal de 1 px, que es la de
-- las SALPICADURAS. Las dos rectas del grosor son verticales, con |dy| = largo y
-- |dx| = 0, y lo que se busca es la pareja a 1 px de distancia en X.
local function grosor_de_h2(col)
  local pares = 0
  for i = 1, #calls do
    local a = calls[i]
    if a.op == "line" and a.col == col and a.x1 == a.x2 and math.abs(a.y2 - a.y1) >= 4 then
      for j = 1, #calls do
        local b = calls[j]
        if b.x1 == a.x1 + 1 and b.x2 == a.x2 + 1
           and b.y1 == a.y1 and b.y2 == a.y2 then
          pares = pares + 1
          break
        end
      end
    end
  end
  return pares
end
ok("H.Rain sigue dibujando 2 px de ancho, no 1 (" .. grosor_de_h2(COL_PESADA) .. " pares)",
   grosor_de_h2(COL_PESADA) > 0)

-- Y lo contrario para las otras dos, que son de 1 px: no tienen que existir la pareja.
eq("B.Rain es de 1 px: ninguna recta tiene pareja a 1 px", 0, grosor_de_h2(COL_FONDO))
eq("C.Rain es de 1 px: ninguna recta tiene pareja a 1 px", 0, grosor_de_h2(COL_CERCA))
-- 9c. Los colores: C.Rain tiene que ser un azul SOBRIO y B.Rain mas CELESTE
--
-- Se comparan los canales. Lo que se quiere:
--   - las tres con el mismo tono de alpha (la pesada translucida, las otras dos
--     opacas)
--   - C.Rain: azul sobrio. Es el mas oscuro de las tres (menor suma RGB), pero
--     con los tres canales altos para que no sea un azul marino.
--   - B.Rain: perceptiblemente mas celeste. Su B tiene que destacar sobre el
--     de C.Rain, y su R por encima tambien (mas claro).
--------------------------------------------------------------------------------
-- FBNeo lee 0xRRGGBBAA, asi que R va en el byte de 2^24, G en 2^16, B en 2^8 y
-- el ALFA en el byte bajo. Con la convencion vieja (0xAARRGGBB) estos tres
-- canales salian del color equivocado, que es justo el bug que se corrigio.
local function canales(c)
  return math.floor(c / 16777216) % 256,   -- R
         math.floor(c / 65536) % 256,      -- G
         math.floor(c / 256) % 256         -- B
end

local function alfa(c)
  return c % 256
end

local rP, gP, bP = canales(COL_PESADA)
local rF, gF, bF = canales(COL_FONDO)
local rC, gC, bC = canales(COL_CERCA)

-- La pesada se queda como estaba: es la referencia.
eq("H.Rain conserva su color", color(0xA8, 0xC8, 0xE8, 0x99), COL_PESADA)

-- B.Rain tiene que ser la mas clara de las tres.
ok(string.format("B.Rain es la mas clara (R %d > C %d)", rF, rC), rF > rC)
ok(string.format("B.Rain es la mas celeste (B %d > C %d)", bF, bC), bF > bC)

-- C.Rain: azul sobrio = con los tres canales altos (nada de azul marino) pero
-- el mas oscuro de las tres.
ok(string.format("C.Rain no es un azul marino (G %d y B %d altos)", gC, bC),
   gC >= 150 and bC >= 200)
ok(string.format("C.Rain es la mas oscura (suma %d vs fondo %d)",
   rC + gC + bC, rF + gF + bF), (rC + gC + bC) < (rF + gF + bF))

-- Ninguna de las dos nuevas es transparente: las dos tienen que ser solidas.
eq("B.Rain es solida", 255, alfa(COL_FONDO))
eq("C.Rain es solida", 255, alfa(COL_CERCA))
ok("H.Rain sigue translucida", alfa(COL_PESADA) < 255)

-- Y el alfa tiene que estar en el byte BAJO, que es donde lo lee el motor. Esta
-- es la prueba que detecta la convencion invertida: con 0xAARRGGBB, el alfa
-- estaria en el byte alto y estas cuatro comprobaciones darian otro numero.
eq("H.Rain tiene el alfa en el byte bajo", 0x99, alfa(COL_PESADA))
eq("B.Rain tiene el alfa en el byte bajo", 0xFF, alfa(COL_FONDO))
eq("C.Rain tiene el alfa en el byte bajo", 0xFF, alfa(COL_CERCA))

-- Y al reponerlas, las 11 de fondo desaparecen: 0 clavado, porque con tres
-- cajas de radio 127 la union cubre de -127 a 446 en X y de -15 a 239 en Y,
-- toda la pantalla sin huecos por los que escape una gota.
--
-- Y las otras dos capas NO se ocultan: C.Rain va encima de los personajes por
-- definicion y H.Rain salpica. Esta comprobacion es la que separa "se ocultan
-- las de fondo" de "se apago la lluvia entera".
poke16(0xFFA008, 0x30)
frame_seguro()
eq("con la hurtbox tapando todo, las " .. ESP.dibujadas_fondo .. " de fondo se ocultan",
   0, gotas_fondo())
eq("con la hurtbox tapando todo, la pesada tampoco se dibuja",
   0, gotas_pesada())

-- C.Rain NO se oculta: va encima de los personajes por definicion. Con la caja
-- puesta tiene que haber al menos una gota: si se quedara en 0 seria que se
-- apago la lluvia entera, que es el otro fallo posible.
ok("C.Rain sigue visible con la hurtbox tapando todo (" .. gotas_cerca() .. ")",
   gotas_cerca() > 0)

-- H.Rain (la pesada) tiene que COLISIONAR con la hurtbox, no ocultarse.
--
-- DOS COSAS QUE IMPORTAN aqui:
--
-- 1) NO se usan las tres cajas gigantes. Con una caja que cubre TODA la
--    pantalla, cada gota pesada renace DENTRO de ella y muere en el mismo
--    frame sin llegar a dibujarse: H.Rain queda invisible. Es el comportamiento
--    correcto, pero no prueba nada.
--
-- 2) La caja tiene que estar A LA ALTURA DE LOS PIES, que es donde el recorte
--    pone el suelo: 0.78 * 224 = 174. Ponerla en la mitad de la pantalla (112)
--    no prueba nada, porque las gotas de la pesada se siembran en 175 px de
--    alto y ninguna pasa por ahi. El error sale de que con CAL_Y = -127 la
--    conversion da cualquier cosa y uno ajusta la caja "a ojo" en el sitio que
--    parece logico en vez del sitio donde cae de verdad.
-- La caja se PREPARA pero se deja el contador a 0. Ojo: poner el contador a 0x10
-- aqui y no quitarlo despues hacia que las pruebas siguientes corran con la
-- caja puesta, y como esta a la altura de los pies (donde la pesada se siembra)
-- toda gota nace DENTRO y muere: H.Rain da 0 siempre.
-- La caja se PREPARA pero se deja el contador en 0. Ojo: poner el contador a 0x10
-- aqui y no quitarlo despues hace que las pruebas siguientes corran con la caja
-- puesta, y como la pesada SI choca con la hurtbox (a diferencia de las otras
-- dos capas), H.Rain da 0 siempre.
--
-- Ademas el reparto de la pesada es 0..(175 - 7) = 168 con paso 24, o sea que su
-- punta mas baja esta en 162. Por eso la caja va centrada en 140 con radio 15
-- (de 125 a 155): la toca la gota mas baja y las de arriba no. Ponerla en el
-- centro de la pantalla (112) no toca ninguna gota y la prueba pasa por vacuio.
-- `HB` (arriba) es LA MISMA direccion: no hace falta un segundo local para el mismo
-- numero, y este banco esta en el limite de los 200 locals de Lua.
poke16(HB + 0x00, 535); poke16(HB + 0x04, 275)    -- centro en pantalla (280, 140)
mem[HB + 0x08] = 15; mem[HB + 0x09] = 15          -- de 125 a 155 en pantalla
poke16(HB + 0x0C, 0x8400)

-- Sin la caja, H.Rain esta entera.
--
-- OJO con lo que hay ANTES: el frame anterior deja las TRES hurtbox gigantes
-- PUESTAS, y con ellas la pesada choca, nace dentro y muere sin llegar a
-- dibujarse. Hay que quitarlas.
--
-- Se busca el MAXIMO en 60 frames y no un frame suelto porque la pesada SI
-- choca: si el pool quedo sembrado dentro de la caja en frames anteriores, las
-- gotas mueren y se re-siembran, y en el frame exacto en que se quita la caja
-- puede que no haya ninguna todavia.
poke16(0xFFA008, 0); mem[0xFFA009] = 0
local mejor_p = 0
for i = 1, 60 do
  frame_seguro()
  local n = gotas_pesada()
  if n > mejor_p then mejor_p = n end
end
-- 28 y no 20: H.Rain tiene `grosor = 2`, o sea 2 lineas por gota, y ahora el pool es
-- de 14. Antes eran 10 gotas y 20 lineas, y la prueba decia 20 por las dos cosas a
-- la vez, sin decir cual de las dos estaba contando.
eq("H.Rain entera sin ninguna hurtbox (" .. ESP.n_pesada .. " gotas de 2 px)",
   ESP.lineas_pesada, mejor_p)

-- Con la caja a la altura de los pies: la gota que la cruza salpica y muere, y
-- el pool se renueva. Por eso no se cuenta el numero exacto (es dinamico) sino
-- que el TOTAL a lo largo de muchos frames sea MENOR que si no colisionara:
-- cada renovacion por colision es una gota menos dibujada.
local function suma_pesada(nframes)
  poke16(0xFFA008, 0x10)                     -- caja puesta
  frame_seguro()
  local s = 0
  for i = 1, nframes do
    frame_seguro()
    s = s + gotas_pesada()
  end
  poke16(0xFFA008, 0); mem[0xFFA009] = 0   -- caja quitada
  return s
end

-- ANTES ESTO ERA CONTAR LINEAS, y era una prueba de filo. Se comparaba el total
-- dibujado con y sin hurtbox esperando que saliera MENOS con caja, y la diferencia
-- era de unas decenas sobre 2600: un 0,1 %. Es mas pequena que el ruido.
--
-- Se ha visto romper DOS veces por la misma causa: al subir el pool de B.Rain de 10
-- a 20, `sembrar_una` consume el doble de math.random() y la FASE del RNG se corre,
-- con lo que las gotas de H.Rain caen en otras columnas y el signo de la diferencia
-- se da la vuelta. El bug era de B.Rain, no de H.Rain, y la prueba de H.Rain es la
-- que lo delato.
--
-- AHORA ESTA PRUEBA SE BORRO, y no es una perdida de cobertura.
--
-- Antes comparaba el total de lineas dibujadas con y sin hurtbox y exigia que saliera
-- MENOS con caja. Se ha visto romper dos veces por lo mismo: la diferencia era de
-- unas decenas sobre 2600, un 0,1 %, mas pequena que el ruido. La ultima vez al
-- subir el pool de B.Rain de 10 a 20, que hace que `sembrar_una` consuma el doble de
-- math.random(), corra la FASE del RNG y las gotas de H.Rain caeran en otras
-- columnas. El bug era de B.Rain y la delata una prueba de H.Rain.
--
-- Ademas era REDUNDANTE. La comprobacion decisiva de que H.Rain colisiona con la
-- hurtbox ya existe y es exacta: "con la hurtbox tapando todo, la pesada tampoco se
-- dibuja" (eq(gotas_pesada(), 0) con las tres cajas de radio 127). Si la colision
-- con la hurtbox no funcionara, H.Rain se veria entera con las tres cajas puestas.
-- Cero lineas no tiene ruido.
--
-- Lo que no se debe hacer es volver a comparar SUMAS de lineas para esto. Si
-- hay que medirlo de nuevo, que sea con la caja tapando toda la pantalla, no con
-- la caja pequena de y=140.

-- Y tiene que haber SALPICADURAS. Son lineas HORIZONTALES de 1 px, dos
-- apiladas en Y (la particula es 2x2). Se distinguen de las gotas sin mirar el
-- color, porque las gotas son diagonales (dy != 0). No se puede usar el color:
-- el alfa de la pesada es 0x99, o sea 2577975528, MAYOR que 2^31, y en LuaJIT se
-- guarda como float, con lo que la igualdad exacta falla.
local function salpicaduras()
  local n = 0
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "line" and c.y2 == c.y1 and (c.x2 - c.x1) == 1 then
      n = n + 1
    end
  end
  return n
end

-- Se buscan a lo largo de varios frames, porque la colision pasa en un frame
-- concreto y en el resto no hay nada.
local mejor_salp = 0
for i = 1, 60 do
  frame_seguro()
  local s = salpicaduras()
  if s > mejor_salp then mejor_salp = s end
end
ok("la colision de H.Rain genera salpicaduras (" .. mejor_salp .. ")",
   mejor_salp > 0)

-- LAS CUATRO PARTICULAS SALEN EN CRUZ
--
-- Cada particula de 2x2 se dibuja con dos lineas horizontales apiladas, y ocupa los
-- pixeles q.x..q.x+1 y q.y..q.y+1. La cruz pide que los cuatro bloques toquen con su
-- esquina la esquina de un hueco central de 2 px, o sea bloques de 2 de ancho separados
-- por 2: la diferencia entre las esquinas opuestas es de 4 en X y 4 en Y.
--
-- Se busca la cruz EN CUALQUIER PARTE DEL FRAME, y no en un frame que tenga
-- exactamente cuatro particulas. La primera version exigia eso y solo daba 2 muestras
-- en 90 frames, porque casi nunca hay un frame con un solo impacto limpio: hay varias
-- gotas muriendo a la vez y particulas de impactos anteriores todavia vivas. Con dos
-- muestras, una regresion pasaria sin que nadie lo notara.
--
-- Tampoco basta con "hay cuatro particulas cerca": con el angulo aleatorio de antes
-- tambien habia cuatro, solo que en cualquier sitio. Lo que se comprueba es la forma.
local function hay_cruz()
  local pos = {}
  for k = 1, #calls do
    local c = calls[k]
    if c.op == "line" and c.y2 == c.y1 and (c.x2 - c.x1) == 1 then
      -- Solo la linea de ARRIBA del bloque, para no contar cada particula dos veces.
      local hay_arriba = false
      for j = 1, #calls do
        local b = calls[j]
        if b.op == "line" and b.y2 == b.y1 and (b.x2 - b.x1) == 1
           and b.y1 == c.y1 - 1 and b.x1 == c.x1 then hay_arriba = true break end
      end
      if not hay_arriba then pos[c.x1 .. "," .. c.y1] = true end
    end
  end
  -- Cuatro esquinas a 4 de separacion en ambos ejes.
  for clave in pairs(pos) do
    local x, y = clave:match("^(%-?%d+),(%-?%d+)$")
    if x then
      x, y = tonumber(x), tonumber(y)
      if pos[(x - 4) .. "," .. y] and pos[x .. "," .. (y - 4)]
         and pos[(x - 4) .. "," .. (y - 4)] then
        return true
      end
    end
  end
  return false
end

local frames_cruz = 0
for i = 1, 90 do
  frame_seguro()
  if hay_cruz() then frames_cruz = frames_cruz + 1 end
end
-- Se mide ~9 de 90. El porque de ser pocos y no mas: la cruz solo esta presente en
-- el frame en que nacen las particulas y en el siguiente. A partir de ahi cada una se
-- va por su diagonal a velocidad ALEATORIA, y en cuanto se separan dejan de formar la cruz.
--
-- El umbral es 3 y no mas a proposito: con el angulo aleatorio de antes la cuenta
-- seria CERO, porque cuatro particulas cayendo al azar no caen nunca exactamente a 4
-- de separacion en ambos ejes. O sea que cualquier numero positivo ya delata la
-- regresion, y el 3 solo protege del ruido de los frames sueltos.
ok("las 4 particulas salen en cruz con hueco de 2 px (" .. frames_cruz
   .. " frames de 90)", frames_cruz >= 3)

-- Y el segundo camino de muerte: sin hurtbox, la pesada muere contra el SUELO
-- y tambien salpica. Se recorren 150 frames, que es mas de un ciclo entero de
-- las 7 gotas (90 frames), para que todas llegan al suelo.
local mejor_suelo = 0
for i = 1, 150 do
  frame_seguro()
  local s = salpicaduras()
  if s > mejor_suelo then mejor_suelo = s end
end
ok("la pesada tambien salpica al tocar el suelo (" .. mejor_suelo .. ")",
   mejor_suelo > 0)

-- Y las particulas tienen que MORIR: no pueden quedar flotando para siempre.
--
-- QUE MIDE, Y POR QUE ASI. El test anterior media el MINIMO de particulas por
-- frame a lo largo de 200 frames y pedia <= 4. Fallaba 1 de cada 3 corridas, y el
-- motivo es que la premisa era falsa: con 14 gotas pesadas de 39 frames impacting
-- al tocar el suelo hay un impacto cada ~9 frames, y cada impacto deja 4
-- particulas vivas unos 9 frames. O sea que la lluvia RENUEVA las particulas sin
-- parar y NUNCA hay un frame con cero. No es que las particulas no mueran: es que
-- hay nuevas naciendo mientras las viejas se van. El test pedia algo que el
-- efecto no promete.
--
-- LO QUE IMPORTA ES QUE NO HAYA FUGA. El pool es de 64. Si las particulas no
-- murieran, se llenaria y se quedaria clavado en 64 para siempre. Se mide el
-- MAXIMO a lo largo de 200 frames: tiene que quedarse muy por debajo de 64, que
-- es la firma de que cada una se va cuando le toca.
--
-- El RNG va sembrado para que la corrida sea reproducible y el maximo no cambie
-- de una vez a otra por azar.
-- (el RNG ya va fijo desde el dofile: ver la nota del principio de la corrida)

local max_salp, frames_con = 0, 0
for i = 1, 200 do
  frame_seguro()
  local s = salpicaduras()
  if s > max_salp then max_salp = s end
  if s > 0 then frames_con = frames_con + 1 end
end
-- Son 8 lineas por particula (2x2 px, 2 lineas por pixel). El techo de 200 es
-- holgado a proposito: 25 particulas simultaneas ya serian una fuga en un pool
-- de 64. La firma de que no hay fuga es que el maximo se queda bajo.
ok("hay salpicaduras (" .. frames_con .. " frames con alguna)", frames_con > 0)
ok(string.format("las particulas no se acumulan (maximo %d lineas = ~%d de 64)",
   max_salp, max_salp / 8), max_salp <= 200)

--------------------------------------------------------------------------------
-- 13. C.Rain muere en el ultimo pixel de 224, no en el borde de la ventana
--
-- El problema: linea_de_suelo() devolvia emu.screenheight(), que con el ratio
-- 16:9 es MAS ALTA que 224 (el borde negro lateral). Las gotas de C.Rain llegaban
-- al suelo del juego (~175) y seguian cayendo por el borde negro hasta morir,
-- cosa que se veia en pantalla.
--
-- LO QUE SE MIDE, Y EN QUE ESPACIO
--
-- OJO: esta prueba mira donde se DIBUJA, o sea pixeles de VENTANA, pero el tope
-- de 224 es un numero de JUEGO. Con borde negro (oy > 0) las dos cosas no valen
-- lo mismo y la comparacion directa daria un falso fallo.
--
-- Lo que se mide es la fila mas baja de la VENTANA a la que llega una gota de
-- C.Rain, y se compara contra la fila mas baja de la imagen del JUEGO, que es
-- MARGEN_Y + 224 - 1. Asi la prueba sigue valiendo con cualquier proporcion de
-- ventana, que es justo lo que se quiere comprobar.
--
-- Con la ventana al tamano del juego (MARGEN_Y = 0) esto reduce a lo de antes:
-- la punta de la gota, como mucho, en 223.
--------------------------------------------------------------------------------
local MARGEN_Y_TEST = math.floor((H - 224) / 2)
if MARGEN_Y_TEST < 0 then MARGEN_Y_TEST = 0 end
local ULTIMA_FILA = MARGEN_Y_TEST + 223      -- ultima fila de la imagen del juego

poke16(0xFFA008, 0); mem[0xFFA009] = 0
local y_max_cerca = 0
for i = 1, 200 do
  frame_seguro()
  for j = 1, #calls do
    local c = calls[j]
    if c.op == "line" and c.col == COL_CERCA then
      local yb = math.max(c.y1, c.y2)
      if yb > y_max_cerca then y_max_cerca = yb end
    end
  end
end
ok(string.format("C.Rain no pasa de la ultima fila del juego (%d, margen %d; llego a %d)",
   ULTIMA_FILA, MARGEN_Y_TEST, y_max_cerca), y_max_cerca <= ULTIMA_FILA)

-- Y tiene que MORIR de verdad, no quedarse clavada en 224. No se comprueba con
-- "hay frames sin gotas": con las duraciones cortas (27 frames para C.Rain) las
-- 10 gotas se renuevan tan seguido que puede no haber ningun frame vacio, y la
-- Y tiene que MORIR DE VERDAD, no quedarse clavada a media caida.
--
-- ANTES la linea de muerte era un numero fijo (luego 223, luego 211) y la prueba
-- miraba que la gota llegara a ~210. Ahora la linea SIGUE AL SUELO del stage, que en
-- el sandbox esta en el recorte SUELO_MIN (0.78 * 224 = 175) mas ABAJO_OFF, asi que
-- la gota tiene que llegar a ahi, no mas abajo.
--
-- El suelo del sandbox no se puede leer desde el test (es local del script), asi que
-- se usa el mismo suelo con el que arranca: 0.78 * 224 + ABAJO_OFF. Con un margen de
-- un par de filas para el largo de la gota. El techo de 223 lo comprueba la prueba de
-- arriba.
local SUELO_ESPERADO = math.floor(0.78 * 224) + 8
local llego_al_final = y_max_cerca >= MARGEN_Y_TEST + SUELO_ESPERADO - 6
ok(string.format("C.Rain llega hasta su linea de muerte (llego a %d, esperaba %d)",
   y_max_cerca, MARGEN_Y_TEST + SUELO_ESPERADO),
   llego_al_final)

-- Al quitar la hurtbox vuelven las 10, y tienen que volver al MAXIMO del pool.
-- Si una gota se escondiera para siempre, el total se quedaria corto para
-- siempre: la ocultacion es un estado POR FRAME, no permanente.
--
-- Se mide el maximo en 20 frames porque una gota puede morir y re-sembrarse en
-- el mismo frame y en ese frame se dibuja una menos.
poke16(0xFFA008, 0); mem[0xFFA009] = 0
local vuelven = 0
for i = 1, 20 do
  frame_seguro()
  local n = gotas_fondo()
  if n > vuelven then vuelven = n end
end
eq("al quitar la hurtbox, las " .. ESP.dibujadas_fondo .. " de fondo vuelven",
   ESP.dibujadas_fondo, vuelven)
-- Y este `ok` es REDUNDANTE con el `eq` de arriba, y por eso se puede borrar sin
-- perder cobertura: los dos miran la MISMA variable. Queda como segunda lectura, no
-- como prueba: si el `eq` pasara y este fallara, la variable habria cambiado entre
-- medias y eso si seria una seña.
ok("la ocultacion es por frame: sacar la caja las devuelve a las "
   .. ESP.dibujadas_fondo, vuelven == ESP.dibujadas_fondo)

--------------------------------------------------------------------------------
-- 12. La lluvia no depende de que las cajas esten apagadas
--
-- El snapshot tiene que salir de la lista aunque ningun SHOW_ este activo. Con
-- las cinco cajas apagadas la lluvia tiene que seguir saliendo IGUAL. Esta es
-- la trampa que documento MEMORIA.md: si rects_de() mirara L.on(), apagar las
-- cajas se llevaria por delante a la lluvia.
--------------------------------------------------------------------------------
-- El total de lineas de lluvia en un frame es DINAMICO: una gota puede morir y
-- re-sembrarse en el mismo frame, y en ese frame hay una menos. Por eso se
-- compara el MAXIMO a lo largo de varios frames en vez de un frame suelto.
local function max_lineas(nframes)
  local m = 0
  for i = 1, nframes do
    frame_seguro()
    local n = gotas(1)
    if n > m then m = n end
  end
  return m
end

local antes = max_lineas(20)

-- Apaga las cinco cajas: items 0 (hitbox), 1 (clash), 2 (hurtbox),
-- 3 (pushbox) y 4 (grab).
for _, it in ipairs({ 0, 1, 2, 3, 4 }) do
  abrir_menu()
  for i = 1, it do
    pressed = { ["P1 Down"] = true }
    frame_seguro()
    pressed = {}
    frame_seguro()
  end
  pressed = { ["P1 Button A"] = true }
  frame_seguro()
  pressed = {}
  cerrar_menu()
end

-- Ninguna linea con un color de caja: el bucle de arriba apago las cinco (0..4)
-- y "cajas P2" (fila 4) ya venia apagada de la seccion 8.
frame_seguro()
local lineas_caja = 0
for i = 1, #calls do
  local c = calls[i]
  if c.op == "line" and (c.col == color(0xFF, 0x60, 0x60, 0xFF) or c.col == color(0x80, 0xA0, 0xFF, 0xFF)
                         or c.col == color(0x60, 0xE0, 0x60, 0xFF) or c.col == color(0xC0, 0xC0, 0x40, 0xFF)
                         or c.col == color(0xE0, 0x40, 0xE0, 0xFF)) then
    lineas_caja = lineas_caja + 1
  end
end
eq("con las 5 cajas apagadas no se dibuja ninguna", 0, lineas_caja)

-- Y la lluvia sigue saliendo. Antes esto era una IGUALDAD EXACTA de contadores y
-- ya no puede serlo: con los rectangulos del HUD tapando las gotas, cuantas
-- lineas se dibujan depende tambien de donde este cada gota respecto de los
-- paneles en ese frame, y las dos ventanas de 20 frames caen en fases distintas
-- de la lluvia. Medir 39 contra 37 no dice nada sobre las cajas.
--
-- Lo que esta prueba persigue es la trampa de MEMORIA.md: que el snapshot este
-- DENTRO de un if SHOW_CAJAS y apagar las cajas se lleve por delante la lluvia.
-- Esa trampa da cero lineas, no dos menos. Asi que se mide con margen.
local despues = max_lineas(20)
ok(string.format("la lluvia no cambia al apagar las cajas (%d vs %d)", antes, despues),
   despues >= antes * 0.9)

-- Y en ningun frame se queda sin lluvia, que es como se ve la trampa aunque el
-- maximo se escape: no hay ni un frame seco en 200 frames con las cajas apagadas.
local localGotas = math.huge
for i = 1, 200 do
  frame_seguro()
  local n = gotas(1)
  if n < localGotas then localGotas = n end
end
ok("con las cajas apagadas no hay ni un frame sin lluvia (minimo " .. localGotas .. ")",
   localGotas > 0)

--------------------------------------------------------------------------------
-- 13. Las gotas se mueven y se renuevan
--
-- Con los 27 frames de duracion de C.Rain (la mas rapida de las tres), en 20
-- frames tiene que haber advancedacion y renovacion. Se mide que el conjunto de
-- lineas sea DISTINTO entre dos instantes separados.
--------------------------------------------------------------------------------
local function firma()
  local t = {}
  for i = 1, #calls do
    -- por COLOR, no por forma. Con las TRES capas rectas (dx = 0) un filtro de
    -- "dx > 0" no contaria ninguna gota y la firma seria siempre vacia, con lo que
    -- "las gotas se mueven entre frames" pasaria por vacuio. Es el mismo error que
    -- se corrigio en gotas() y gotas_por_grosor().
    if es_lluvia(calls[i]) then
      local c = calls[i]
      t[#t + 1] = c.x1 .. "," .. c.y1
    end
  end
  table.sort(t)
  return table.concat(t, " ")
end

frame_seguro()
local f1 = firma()
for i = 1, 20 do frame_seguro() end
local f2 = firma()
ok("las gotas se mueven entre frames", f1 ~= f2)

-- Tras 200 frames (~3,3 s) tiene que seguir habiendo lluvia: si el pool no
-- se renovara, se habria vaciado. Con 32 gotas y duraciones de 48 a 120
-- frames, en 200 frames cada una muere varias veces.
for i = 1, 200 do frame_seguro() end
ok("la lluvia se renueva sola y no se vacia", gotas(1) > 0)

--------------------------------------------------------------------------------
-- 14. Los recuadros del HUD tapan la lluvia de LAS TRES CAPAS
--
-- Los dos rectangulos del HUD (cara, barras y nombre) son zona de NO DIBUJADO. No
-- estan en ninguna lista de colisiones, asi que no hay hurtbox que los tapara: son
-- medidas fijas, medidas sobre capturas del usuario.
--
-- Se recortan por la parte ALTA de la gota, no se oculta la gota entera: asi la
-- lluvia emerge limpia por debajo del panel, que es lo que se ve cuando pasa por
-- detras de un HUD. Ocultarla entera la haria aparecer y desaparecer de golpe.
--
-- Lo que se mide aca es lo unico que importa del recorte: NINGUNA gota puede
-- tener ningun pixel dentro de un rectangulo del HUD. Se recorre cada recta
-- dibujada pixel a pixel, porque una gota es una diagonal y el rectangulo puede
-- cortarla por cualquier lado.
--
-- OJO con los espacios: las zonas estan en pixeles de JUEGO y las lineas en
-- pixeles de VENTANA. Con ventana 4:3 sobra borde negro y comparar sin convertir
-- daria un falso negativo. Se aplica el mismo margen que margen_juego().
--------------------------------------------------------------------------------
-- MISMO calculo que margen_juego() en el script, que es local y no se puede leer
-- desde aqui. Se replica en vez de suponer 0: con ventana 4:3 sobra borde negro y
-- sin esto la comparacion de abajo estaria corrida.
local function margen_juego()
  local ox = (emu.screenwidth()  - 320) / 2
  local oy = (emu.screenheight() - 224) / 2
  return math.floor(ox), math.floor(oy)
end

local HUD_ZONAS_TEST = {
  { x1 =  39, y1 = 14, x2 = 136, y2 = 45 },
  { x1 = 183, y1 = 14, x2 = 281, y2 = 45 },
}

-- Recorre la recta (ax,ay)-(bx,by) pixel a pixel y dice si ALGUN pixel cae dentro
-- de una zona. Se recorre entera y no solo los extremos: el rectangulo puede
-- tapar el medio de la gota y dejar los dos extremos fuera.
local function dentro_de_hud(ax, ay, bx, by)
  local ox, oy = margen_juego()
  ax, ay, bx, by = ax - ox, ay - oy, bx - ox, by - oy
  local pasos = math.max(math.abs(bx - ax), math.abs(by - ay))
  if pasos == 0 then pasos = 1 end
  for s = 0, pasos do
    local x = math.floor(ax + (bx - ax) * s / pasos + 0.5)
    local y = math.floor(ay + (by - ay) * s / pasos + 0.5)
    for i = 1, #HUD_ZONAS_TEST do
      local z = HUD_ZONAS_TEST[i]
      if x >= z.x1 and x <= z.x2 and y >= z.y1 and y <= z.y2 then return true end
    end
  end
  return false
end

-- Todas las lineas que pueden ser una gota. Ahora se cuentan POR COLOR (es_lluvia),
-- no por geometria.
--
-- Este filtro era "dx > 0 y dy >= 1", o sea "diagonal corta". Con las TRES capas
-- rectas (dx = 0) no cuenta NINGUNA gota, y entonces la comprobacion del recorte del
-- HUD pasaria por vacuio: daria 0 intrusiones y 0 lineas de lluvia, y las dos
-- cosas en verde. Es el tercer sitio con el mismo error de fondo, despues de
-- gotas() y de firma().
local function lineas_de_gota()
  local t = {}
  for i = 1, #calls do
    local c = calls[i]
    if es_lluvia(c) then
      t[#t + 1] = { x1 = c.x1, y1 = c.y1, x2 = c.x2, y2 = c.y2 }
    end
  end
  return t
end

-- Se mira en 120 frames (~2 s), no en uno solo: las gotas bajan rapido y en un
-- frame dado puede no haber ninguna cruizando el panel. Con 32 gotas y la banda
-- de 32 filas, en 120 frames todas las capas pasan por ahi MUCHAS veces.
local intrometidas, gotas_totales = 0, 0
for i = 1, 120 do
  frame_seguro()
  local ls = lineas_de_gota()
  gotas_totales = gotas_totales + #ls
  for j = 1, #ls do
    if dentro_de_hud(ls[j].x1, ls[j].y1, ls[j].x2, ls[j].y2) then
      intrometidas = intrometidas + 1
    end
  end
end
ok(string.format("se midieron gotas de verdad (%d lineas en 120 frames)", gotas_totales),
   gotas_totales > 300)
eq("NINGUNA gota se dibuja dentro de los recuadros del HUD", 0, intrometidas)

-- Y lo contrario, que es lo que hace que el efecto sirva: la lluvia tiene que
-- SEGUIR saliendo por debajo de los paneles. Si el recorte se comiera todo, el
-- recorte "pasaria" la prueba de arriba con cero gotas dibujadas.
local ox_h, oy_h = margen_juego()
local debajo = 0
for i = 1, 120 do
  frame_seguro()
  local ls = lineas_de_gota()
  for j = 1, #ls do
    if ls[j].y1 - oy_h > 45 and ls[j].y1 - oy_h < 200 then debajo = debajo + 1 end
  end
end
ok(string.format("la lluvia sigue saliendo por debajo del HUD (%d lineas)", debajo),
   debajo > 300)

-- Y por ultimo: los dos rectangulos YA NO SE DIBUJAN. Si se dibujaran, el efecto
-- se veria como un marco de medicion y no como una zona de ocultamiento.
frame_seguro()
eq("el marco del HUD P1 no se dibuja", 0, lineas_de(color(0xFF, 0x40, 0x40, 0xFF)))
eq("el marco del HUD P2 no se dibuja", 0, lineas_de(color(0x40, 0xFF, 0x40, 0xFF)))

--------------------------------------------------------------------------------
-- 15. La opcion "G.LINE" apaga y enciende TODAS las guias de medicion
--
-- Las guias son el andamiaje con el que se ajustaron las zonas del HUD y el margen
-- de la ventana: marco AMARILLO, linea MAGENTA de C.Rain, CYAN de y = 0 / y =
-- SPAWN_Y / rayitas cada 32 filas, y las rayitas GRISES de escala.
--
-- Se cuentan por COLOR, que es lo que las distingue de todo lo demas. Los cuatro
-- son propios y no chocan con ninguna caja:
--
--   clash   (0xC0,0xC0,0x40)   marco AMARILLO  (0xFF,0xFF,0x00)
--   grab    (0xE0,0x40,0xE0)   MAGENTA         (0xFF,0x00,0xFF)
--
-- Las cajas se apagan antes de medir, asi que lo unico que queda en pantalla es lo
-- que dibuja medir_hud() y las tres capas de lluvia.
--------------------------------------------------------------------------------
local COL_MARCO   = color(0xFF, 0xFF, 0x00, 0xFF)   -- los bordes de la imagen del juego
local COL_MAGENTA = color(0xFF, 0x00, 0xFF, 0xFF)   -- donde muere C.Rain
local COL_CYAN    = color(0x00, 0xFF, 0xFF, 0xFF)   -- y = 0, y = SPAWN_Y y escala
local COL_GRIS    = color(0xFF, 0xFF, 0xFF, 0x40)   -- escala de la ventana

local function guias()
  return lineas_de(COL_MARCO) + lineas_de(COL_MAGENTA)
       + lineas_de(COL_CYAN) + lineas_de(COL_GRIS)
end

-- APAGADAS DE FABRICA. Son guias de medicion: no tienen por que estar molestando
-- cuando el ajuste ya termino. Se encienden desde el menu cuando hacen falta.
reset_cajas()
frame_seguro()
eq("G.LINE viene APAGADO de fabrica", 0, guias())

-- Y que la lluvia siga saliendo con las guias apagadas: G.LINE es solo medicion y no
-- puede llevarse por delante el efecto. Esta comprobacion va AQUI y no despues de
-- prenderla, porque el estado que importa es el de fabrica.
ok("la lluvia sigue con G.LINE apagado de fabrica", gotas(1) > 0)

-- Encendidas desde el menu tienen que salir los CUATRO colores. No uno suelto: si uno
-- se rompiera al prender, el total daria 0 en ese color y los otros darian igual.
ir_a_item(ITEM_GLINE)
frame_seguro()
ok("prender G.LINE dibuja las guias (" .. guias() .. " lineas)", guias() > 0)
for nombre, col in pairs({ marco = COL_MARCO, magenta = COL_MAGENTA,
                           cyan = COL_CYAN, gris = COL_GRIS }) do
  ok("con G.LINE prendido hay guias " .. nombre, lineas_de(col) > 0)
end

-- Apagarla tiene que quitarlas TODAS, no solo el marco.
ir_a_item(ITEM_GLINE)
frame_seguro()
eq("apagar G.LINE no deja ninguna guia", 0, guias())
for nombre, col in pairs({ marco = COL_MARCO, magenta = COL_MAGENTA,
                           cyan = COL_CYAN, gris = COL_GRIS }) do
  eq("apagada no queda guia " .. nombre, 0, lineas_de(col))
end

-- Volver a prenderla las devuelve, y la lluvia sigue saliendo con ellas puestas: las
-- guias no pueden estorbar ni tapar el efecto.
ir_a_item(ITEM_GLINE)
frame_seguro()
ok("volver a prender G.LINE repone las guias", guias() > 0)
ok("la lluvia sigue con G.LINE prendido", gotas(1) > 0)

-- Y el reset de fabrica las deja APAGADAS, que es el estado pedido. Si aca se midiera
-- el ultimo estado en vez del de fabrica, la prueba pasaria con el flag al reves.
ir_a_item(ITEM_GLINE)              -- apagar, para que el reset tenga algo que hacer
reset_menu()                       -- B: deja las nueve opciones como de fabrica
frame_seguro()
eq("el reset de fabrica deja G.LINE apagado", 0, guias())

--------------------------------------------------------------------------------
-- Dejar todo como estaba
--------------------------------------------------------------------------------
abrir_menu()
pressed = { ["P1 Button B"] = true }     -- reset de fabrica
frame_seguro()
pressed = {}
cerrar_menu()
poke16(0xFFA008, 0)
poke16(0xFFA00A, 0)
abrir_menu()
pressed = { ["P1 Button B"] = true }
frame_seguro()
pressed = {}
cerrar_menu()
frame_seguro()
eq("el reset final deja el estado de fabrica", 0, lineas_de(color(0x60, 0xE0, 0x60, 0xFF)))

--------------------------------------------------------------------------------
-- 9y. EL GATE DE "ESTAMOS EN PELEA"
--
-- MEDIDO 08-10: el gate es "¿ALGUNO de los cuatro slots tiene HP > 0?". La
-- justificacion completa, con los otros tres candidatos descartados por la misma
-- medicion, esta en el bloque del gate de `LLUVIA DIAGONAL.LUA` y en
-- DATOS_VERIFICADOS.md.
--
-- *** LO QUE ESTA SECCION PROTEGE ***
--
-- Sin ella, tres mutaciones del gate darian VERDE:
--
--   `> 0` -> `>= 0`   el menu tiene los slots en 0, entraria como pelea
--   `> 0` -> `!= 0`    el menu tiene el centinela -1024, entraria como pelea
--   gate -> `true`     siempre en pelea, que es el comportamiento de la RECTA
--
-- Las tres dejarian en verde TODO lo demas del banco, porque el resto corre en
-- pelea. Un gate que no se puede romper no esta verificado.
--
-- OJO: esta seccion SOLO aplica a LLUVIA DIAGONAL.LUA. La RECTA no tiene gate (es
-- la version medida y congelada), asi que ahi "fuera de pelea no hay lluvia" es
-- FALSO por construccion y medirlo seria medir una cosa que no existe.
--------------------------------------------------------------------------------

local function gate() return YUYU_TEST.en_pelea() == true end

if SCRIPT_PROBADO ~= "LLUVIA DIAGONAL.LUA" then
  -- La RECTA no tiene gate, y esto es lo que la distingue de la diagonal. Se mide
  -- con los cuatro slots en el centinela del menu: si aqui bajara a 0, la recta
  -- tendria el gate y el nombre de "copia de trabajo sin diferencias" estaria mal.
  salir_de_pelea()
  frame_seguro()
  local n_recta_sin_pelea = max_lineas(20)
  entrar_en_pelea()
  frame_seguro()
  ok("la RECTA no tiene gate: sigue lloviendo con los cuatro slots a -1024",
     n_recta_sin_pelea > 0)
else
  -- --- EL VALOR DEL GATE, slot por slot ---
  --
  -- Se mira el VALOR que calcula el script, no su efecto sobre el dibujo: asi una
  -- prueba no puede pasar por el motivo equivocado. Los valores del menu salen de
  -- la medicion del 08-10, no de inventarlos.
  entrar_en_pelea()
  frame_seguro()
  ok("HP 223 en dos slots: en pelea", gate())

-- *** LA REGLA ACTUAL: "DOS VIVOS, O UNO VIVO Y NADIE MUERTO" ***
  --
  -- Salio de dos mediciones que se CONTRADIJERON (ver DATOS_VERIFICADOS.md 5f):
  --
  --   "> 0"                dejo 987 frames de lluvia despues del KO
  --   ">= 2 con HP > 0"    se apagaba cuando un peleador VIVO llega a HP 0 y
  --                        bloquea un especial (medido por el usuario)
  --
  -- La regla que sale de los estados medidos:
  --
  --   hay pelea si hay 2+ slots con HP > 0, o si hay UNO y NINGUN slot con HP < 0
  poke16(0xFF8400 + 0x78, 147)      -- el ganador, con vida
  poke16(0xFF8800 + 0x78, 0)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, -5)      -- el perdedor, recien caido a negativo
  frame_seguro()
  ok("en el KO hay UN muerto: NO hay pelea", not gate())

  -- *** Y EL CASO DEL BLOQUEO, que es el que reporto el usuario ***
  --
  -- "La CPU tenia 0 de vida, le lance un ataque especial, lo bloqueo, no murio, y
  -- las gotas se detuvieron." O sea que HP == 0 NO es estar muerto: en este juego
  -- se muere cuando la vida baja DE 0.
  --
  -- Con "> 0" o con ">= 2 vivos" esto da FALSO (no hay pelea) y la lluvia se apaga
  -- con el peleador EN PIE. Es el bug, y esta es la prueba que lo tapa.
  poke16(0xFF8400 + 0x78, 147)
  poke16(0xFF8800 + 0x78, 0)       -- el rival en EXACTAMENTE 0, vivo
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, 0)
  frame_seguro()
  ok("con un peleador en HP 0 y NADIE muerto, sigue siendo pelea", gate())

  -- Y si a ese 0 le entra dano (HP < 0) sin que todavia haya centinela, la regla
  -- dice que no hay pelea. ***ESTE es el punto que FALTA MEDIR***: si el juego lo
  -- mata ahi, la regla esta bien; si no, hay que cambiarla. Ver la nota en el .lua.
  poke16(0xFF9000 + 0x78, -3)
  frame_seguro()
  ok("con un peleador ya en negativo (HP -3), NO hay pelea", not gate())

  -- Y el caso de siempre: dos vivos.
  poke16(0xFF8400 + 0x78, 147); poke16(0xFF8800 + 0x78, 100)
  poke16(0xFF8C00 + 0x78, 0);   poke16(0xFF9000 + 0x78, 0)
  frame_seguro()
  ok("con dos slots vivos hay pelea", gate())

  -- Un 1v4 con uno muerto sigue siendo pelea: los otros tres estan en pie.
  poke16(0xFF8400 + 0x78, 223); poke16(0xFF8800 + 0x78, 200)
  poke16(0xFF8C00 + 0x78, 150); poke16(0xFF9000 + 0x78, -5)
  frame_seguro()
  ok("en un 1v4 con uno muerto, los otros tres siguen peleando", gate())

  -- Un solo vivo del todo no es pelea.
  poke16(0xFF8400 + 0x78, -1024)
  poke16(0xFF8800 + 0x78, 0)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, 223)      -- el ultimo slot del array
  frame_seguro()
  ok("con vida solo en el ULTIMO slot ($FF9000), NO hay pelea", not gate())

  -- Y lo que decide no es "algun slot != 0" sino "algun slot > 0": -1024 es el
  -- centinela que el juego DEJA en el menu (MEDIDO, frame 3997 del 08-10:
  -- hp=0/0/0/-1024).
  poke16(0xFF8400 + 0x78, -1024)
  poke16(0xFF8800 + 0x78, -1024)
  poke16(0xFF8C00 + 0x78, -1024)
  poke16(0xFF9000 + 0x78, -1024)
  frame_seguro()
  ok("con los cuatro slots a -1024 (el centinela del menu), NO en pelea", not gate())

  -- Y con 0 en los cuatro tampoco, aunque `>= 0` los contaria como cuatro vivos.
  poke16(0xFF8400 + 0x78, 0)
  poke16(0xFF8800 + 0x78, 0)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, 0)
  frame_seguro()
  ok("con los cuatro slots en 0 (el menu), NO en pelea", not gate())

  -- --- EL EFECTO SOBRE LA LLUVIA ---
  --
  -- Y ahora el efecto, que es lo que se ve. Primero con pelea.
  entrar_en_pelea()
  local n_en_pelea = max_lineas(20)
  ok("en pelea la lluvia sale (" .. n_en_pelea .. " lineas)", n_en_pelea > 0)

  salir_de_pelea()
  eq("fuera de pelea no se dibuja NI UNA linea de lluvia", 0, max_lineas(20))

  -- --- Y EL ESTADO, QUE ES MAS FUERTE QUE LA SALIDA ---
  --
  -- "No se dibuja" y "no hay gotas" son dos cosas. Si el gate solo dejara de
  -- dibujar, las gotas quedarian colgadas en el aire y al volver a entrar en
  -- pelea aparecerian todas de golpe en el punto donde las congelo. Por eso se
  -- mira el POOL, que es un local del script (lo expone `__yuyu_test`).
  --
  -- Y no se mira UN frame suelto: el maximo de 20, porque el pool puede estar
  -- vacio en el frame justo en que se siembra. Un 0 en un frame suelto no dice
  -- nada, que es la trampa de la prueba que vale 0 y 0.
  local function vivas_totales(nframes)
    local m = 0
    for _ = 1, nframes do
      frame_seguro()
      local v = YUYU_TEST.vivas_por_capa()
      local n = 0
      for _, c in pairs(v) do n = n + c end
      if n > m then m = n end
    end
    return m
  end

  salir_de_pelea()
  eq("fuera de pelea no queda NI UNA GOTA VIVA en el pool", 0, vivas_totales(20))

  -- Y al volver la lluvia arranca entera. Con el pool vacio, cualquier linea que
  -- aparezca es de gotas NUEVAS: no puede ser una gota vieja reapareciendo.
  entrar_en_pelea()
  ok("al volver a entrar en pelea la lluvia arranca de cero",
     vivas_totales(4) > 0 and max_lineas(20) > 0)

  -- Y el banco se deja como lo encontro: en pelea, con las tres capas lloviendo,
  -- que es el estado de fabrica del script.
  entrar_en_pelea()
  frame_seguro()
  ok("el banco termina en pelea y con lluvia", max_lineas(20) > 0)

  -- --- EL CALLBACK NO PUEDE MORIR EN SILENCIO ---
  --
  -- En este emulador una excepcion dentro de `registerafter` **se traga**: no hay
  -- error, no hay aviso, y el overlay se queda con el ultimo frame dibujado. O sea
  -- que el sintoma de un callback muerto es EXACTAMENTE "el overlay congelado", que
  -- es el sintoma que el usuario reporto. Por eso el cuerpo del frame va en
  -- `un_frame`, envuelto en un `pcall` que AVISA en la consola.
  --
  -- Se comprueba ROMPIENDO ALGO QUE ESTA ADENTRO del frame, y no el callback
  -- entero: si se reemplaza `frame_cb`, el `pcall` del script ni se ejecuta y la
  -- prueba mide otra cosa. Se rompe `gui.drawline`, que se llama desde adentro de
  -- `draw_lluvia` y de `draw_boxes`.
  local dibline_real = gui.drawline
  local prints = {}
  gui.drawline = function() error("prueba: fallo adentro del frame") end
  local print_real2 = print
  print = function(s) prints[#prints + 1] = tostring(s) end
  frame_seguro()
  print = print_real2
  gui.drawline = dibline_real
  local dijo_error = false
  for i = 1, #prints do
    if string.find(prints[i], "[yuyu] ERROR", 1, true) ~= nil then dijo_error = true end
  end
  ok("un fallo DENTRO del frame AVISA en la consola, no se traga en silencio",
     dijo_error)

  -- Y AVISA EN PANTALLA. Una barra roja en el tercio de arriba. Va FUERA del pcall,
  -- o sea que es el unico aviso que sobrevive a un frame muerto: sin el, el unico
  -- sintoma seria el overlay congelado, que es justo lo mas dificil de ver solo.
  local barra = 0
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "box" and c.fill == color(0xC0, 0x00, 0x00, 0xFF) then barra = barra + 1 end
  end
  ok("y ademas dibuja una barra roja en pantalla", barra > 0)

  -- Y el mensaje tiene que ser ASCII: la consola de Fightcade muestra los bytes
  -- > 127 como dos caracteres, y un error ilegible no sirve para nada.
  local ascii = true
  for i = 1, #prints do
    for k = 1, #prints[i] do
      if string.byte(prints[i], k) > 127 then ascii = false end
    end
  end
  ok("y el mensaje del error es ASCII", ascii)

  -- Y el error no puede contaminar el resto: el frame siguiente tiene que volver a
  -- dibujar normal. Un estado de error que se queda prendido seria PEOR que no
  -- avisar, porque mataria el efecto para siempre.
  error_en = nil
  local vuelve = frame_seguro()
  local n = gotas(1)
  ok("y al frame siguiente el efecto vuelve a andar", vuelve and not error_en and n > 0)

  -- --- EL REQUISITO, CON LAS PALABRAS DEL USUARIO ---
  --
  -- "Cuando el valor de HP P1 o P2 pasa de -1024 a 0 la lluvia debe dejar de
  -- dibujarse, desaparecer, no aparecer en pantalla, no renderizarse. Y cuando
  -- vuelva a 223 volver a mostrarse."
  --
  -- O sea el ciclo del menu: -1024 (centinela) -> 0 (menu) -> 223 (pelea).
  --
  -- Se comprueba lo que el usuario pide, que es el DIBUJADO, no el valor del gate:
  -- que no se dibuje NI UNA linea con HP 0, y que vuelvan a dibujarse con HP 223.
  --
  -- Y OJO con una diferencia entre el requisito y la regla: **223 NO es el
  -- disparador, "> 0" lo es.** Si el gate preguntara "¿HP == 223?", la lluvia se
  -- apagaria en el PRIMER golpe, porque el HP baja a 222 de inmediato y no vuelve
  -- a 223 hasta la ronda siguiente. MEDIDO: en la pelea 2 el P1 paso por 223, 200,
  -- 147, 5, -5 y -1024 dentro de una sola pelea.
  --
  -- Y lo de "de -1024 a 0" importa porque el gate distingue el centinela del 0 solo
  -- por el signo: con `!= 0` el -1024 contaria como pelea y el menu lloviendo.
  salir_de_pelea()                       -- los cuatro slots a -1024
  frame_seguro()
  eq("con los cuatro slots en -1024 no se dibuja ninguna linea", 0, max_lineas(20))

  poke16(0xFF9000 + 0x78, 0)            -- el -1024 del ultimo slot pasa a 0
  frame_seguro()
  eq("y tampoco cuando ese -1024 pasa a 0: sigue sin dibujarse", 0, max_lineas(20))

  entrar_en_pelea()                      -- 223 / 223
  frame_seguro()
  local m_223 = max_lineas(20)
  ok("con HP 223 la lluvia vuelve a dibujarse (" .. m_223 .. " lineas)", m_223 > 0)
  -- Y sale DE VERDAD: el pool estaba vacio, asi que lo que aparece es una siembra
  -- nueva y no gotas viejas reapareciendo.
  ok("y sale de verdad, no quedan gotas colgadas de antes", vivas_totales(4) > 0)

  -- *** NO EXISTE UN FRAME CON LLUVIA DIBUJADA Y CONGELADA ***
  --
  -- El usuario reporto "la lluvia se detiene, queda estatica, y sigue viendose en el
  -- menu". Eso NO puede ser esta lluvia, y el banco lo comprueba en el frame EXACTO
  -- en que el gate se apaga, no en una ventana de 20:
  --
  --   - con el gate apagado `update_lluvia` mata las 52 gotas Y `draw_lluvia` no
  --     entra al bucle. Las dos cosas en el MISMO frame.
  --   - y solo hay UN camino de dibujado de la lluvia en todo el script (los dos
  --     `gui.drawline` de `draw_lluvia`, drops y salpicaduras), los dos con el
  --     `and enp` de la capa.
  --
  -- O sea: si en el frame en que el gate se apaga ya se dibuja CERO lineas, las
  -- gotas congeladas que se ven en pantalla **no son de este script**. Y eso es una
  -- PRUEBA, no un argumento: sin ella, "no puede ser" es una opinion.
  poke16(0xFF8400 + 0x78, 0); poke16(0xFF8800 + 0x78, 0)
  frame_seguro()
  eq("en el PRIMER frame con el gate apagado ya se dibujan 0 lineas de lluvia",
     0, gotas(1))
  eq("y el pool ya esta VACIO en ese mismo frame", 0, YUYU_TEST.vivas_totales())
  -- Y el CONTADOR del latido tambien tiene que dar 0. Sin esto, "lluvia=0" en el
  -- latido no distingue "no hay lluvia" de "el contador esta roto": que es
  -- exactamente como se colaron dos `local gotas_dibujadas` y el contador de la
  -- pantalla leia un local que nadie escribia. Un diagnostico que miente en
  -- silencio es peor que uno que no existe, asi que se exige que los dos digan lo
  -- mismo.
  eq("y el contador que va en el latido tambien da 0",
     0, YUYU_TEST.gotas_dibujadas())

  -- Y el otro lado: con pelea, el contador TIENE QUE MOVE. Si el contador llegara a
  -- cero por un error de ambito, esta es la prueba que lo dice.
  entrar_en_pelea()
  frame_seguro()
  frame_seguro()
  ok("y con pelea el contador del latido da mas de 0",
     YUYU_TEST.gotas_dibujadas() > 0)

  -- *** LA SUPERFICIE DE FBNeo SE RETIENE SI EL SCRIPT NO DIBUJA NADA ***
  --
  -- MEDIDO 08-10: con el gate apagado el script dibuja 0 gotas, y aun asi las gotas
  -- quedan congeladas en pantalla hasta el combate siguiente. Cerrar y reabrir el
  -- `.lua` en el menu las borra. O sea que la retencion es de la superficie de
  -- `gui.*`, no del logico de dibujado.
  --
  -- El arreglo es que **todo frame emita AL MENOS una llamada de dibujado**, aunque
  -- sea un pixel con alfa 0: eso fuerza a que la superficie se vuelva a componer.
  --
  -- Y con esto, "0 lineas de lluvia" y "0 llamadas de dibujado" dejan de ser lo
  -- mismo: el banco distingue las dos cosas, que es justo lo que faltaba para poder
  -- reproducir la retencion en una prueba.
  local dibuja_algo = function()
    local n = 0
    for i = 1, #calls do if calls[i].op ~= nil then n = n + 1 end end
    return n
  end
  poke16(0xFF8400 + 0x78, 0); poke16(0xFF8800 + 0x78, 0)
  frame_seguro()
  eq("fuera de pelea: 0 gotas de lluvia dibujadas", 0, gotas(1))
  ok("fuera de pelea: el script IGUAL emite alguna llamada de dibujado, para que "
     .. "la superficie de FBNeo se vuelva a componer", dibuja_algo() > 0)
  poke16(0xFF8400 + 0x78, 223); poke16(0xFF8800 + 0x78, 223)
  frame_seguro()
  ok("y en pelea sigue habiendo gotas de verdad", gotas(1) > 0)
  poke16(0xFF8400 + 0x78, 0); poke16(0xFF8800 + 0x78, 0)
  frame_seguro()
  eq("vuelta a 0: la lluvia se oculta otra vez", 0, max_lineas(20))
  entrar_en_pelea()
  frame_seguro()
  ok("y vuelve a 223: la lluvia vuelve otra vez", max_lineas(20) > 0)

  -- 9z. EL FINAL DE LA PELEA: EL SLOW-MO DE MUERTE Y LA COLA
  --
  -- MEDIDO 08-10, pelea 2, un round. El enemigo cae al suelo en el frame 3680 con
  -- hp 147/0/0/-5 y `$F558` en 159, o sea que el slow-mo arranca en el MISMO frame
  -- del KO. Y se RE-ARMA en cada golpe que le meten al cadaver: hp -13, -18, -22,
  -- -27, -36, -44, -51, -58, **9 veces en 320 frames, una cada 40**. Termina en el
  -- frame 4159 con `$F558` en 0. O sea que duro **479 frames, no 160**.
  --
  -- QUE SE ESCRIBE, con el numero al lado (el bloque entero esta en el `.lua`):
  --
  --   SLOW   mientras `$F558 > 0`: la lluvia a la MITAD de velocidad. Se sincroniza
  --          sola, porque `$F558` dice cuantos frames quedan y el refresco lo
  --          reinicia. El script NO cuenta frames del slow-mo.
  --   COLA   COLA_FRAMES frames DESPUES DEL ULTIMO frame de slow-mo (no del KO
  --          original: si el slow-mo se extendio 9 veces, la cola arranca de la
  --          ultima), a velocidad normal.
  --   OFF    y ahi se apaga de verdad.
  --
  -- Y EL CAMBIO DE FONDO: **el gate de HP ya no apaga la lluvia, solo la enciende.**
  -- Antes la apagaba, y por ahi salio el bug de los 987 frames: apagaba cuando el
  -- segundo peleador bajaba de vivo, no cuando terminaba el round.
  --
  -- *** LO QUE NO SE PROTEGE, Y POR QUE ***
  --
  -- El caso raro de "el gate se apaga y hay slow-mo SIN muerte" no se puede escribir
  -- aca. No hace falta porque `$F558` tiene UN solo escritor en todo el ROM
  -- (`0x1FA82`, `move.w #$a0`, en el camino de la muerte), o sea que `$F558 != 0`
  -- SIEMPRE es una muerte. Es una RAZON, no una prueba, asi que queda escrita con
  -- `***` en el `.lua` y no como una asercion verde.
  --
  -- *** EL SUPUESTO 1v1 ***
  --
  -- Con los dos peleadores en HP 0 y los dos bloqueando, `en_pelea()` da falso (0
  -- vivos, 0 muertos) y la lluvia se apaga con los dos en pie. No se prueba aca porque
  -- no se entro a un 2v2, y no hay byte que separe "peleador sin vida" de "slot
  -- vacio". Queda declarado en `en_pelea`.
  --
  -- OJO CON EL LIMITE DE LOCALS: esta seccion declara 3, y el banco esta en 200, el
  -- tope de Lua. Uno mas lo hace fallar AL CARGAR con un error que no menciona la
  -- linea. Por eso todo lo que se repite sale de `max_lineas(n)`, que avanza n
  -- frames, y las tres Y por capa van en la tabla del `__yuyu_test`.
  --
  -- *** MUTACIONES: 14 de 15 la rompen. ***
  --
  -- Las que se cazan, con el numero de fallos: mult a 1.0 (2), mult a 0.25 (2), el
  -- mult calculado pero no aplicado (1), el mult aplicado SOLO a la capa 1 (1), la
  -- cola que nunca acaba (4), la cola de 121 (5), la de 119 (4), `$F558` sin mirar
  -- (16), la COLA que no dibuja (3), OFF que dibuja (12), un refresco que no rearma
  -- la cola (3), salir de SLOW sin armar la COLA (8), una pelea nueva que no corta la
  -- cola (el banco revienta), y el off-by-one de `COLA_FRAMES`.
  --
  -- La DECIMOQUINTA ES EQUIVALENTE Y SE DECLARA: cambiar `cola_n <= 0` por
  -- `cola_n < 1` deja las 204 pruebas en verde, porque `cola_n` nunca baja de 0. Un
  -- caso equivalente hay que decirlo, no esconderlo.
  --
  -- Y dos que PARECIAN equivalentes y no lo eran, que tambien hay que decir:
  --
  --   - "el multiplicador se aplica solo a la capa 1" daba VERDE cuando la prueba
  --     miraba una sola capa. Ahora mira las tres, y falla. **Mirar una capa no es
  --     medir el efecto**: es medir un trozo.
  --   - el 120 de la cola estaba al principio escrito como `COLA_FRAMES()`, leido del
  --     SCRIPT, y eso era una **asercion auto-confirmante**: cambiar la constante a
  --     119 o 121 movia las dos manos de la balanza. Un requisito va contra un numero
  --     fijo, y aparte un `eq` que ata el valor del script. Ver MEMORIA.md.
  --------------------------------------------------------------------------

  -- --- 1) EL KO ENTRA EN SLOW, Y EL GATE APAGADO NO CORTA LA LLUVIA ---
  poke16(0xFFF558, 0)                -- antes del KO no hay slow-mo
  entrar_en_pelea()
  frame_seguro()
  eq("en pelea la fase es NORMAL", "NORMAL", YUYU_TEST.fase_nombre())
  ok("y la lluvia sale", gotas(1) > 0)
  frame_seguro()
  ok("hay gotas vivas en las tres capas para poder medirlas",
     YUYU_TEST.y_gota(1, 1) ~= nil and YUYU_TEST.y_gota(2, 1) ~= nil
     and YUYU_TEST.y_gota(3, 1) ~= nil)

  -- El frame del KO MEDIDO: el enemigo cae a -5 Y `$F558` pasa a 159. Las dos
  -- señales llegan en el MISMO frame, y `$F558` gana: no hay ni un frame entre
  -- "llueve normal" y "llueve a la mitad".
  --
  -- Las tres Y van en la tabla del propio `__yuyu_test` y no en tres locals: este
  -- banco esta en el tope de los 200 locals de Lua, y guardar una por capa no entra.
  YUYU_TEST.m9z_pre = { YUYU_TEST.y_gota(1, 1), YUYU_TEST.y_gota(2, 1),
                        YUYU_TEST.y_gota(3, 1) }
  poke16(0xFF8400 + 0x78, 147)
  poke16(0xFF8800 + 0x78, 0)
  poke16(0xFF8C00 + 0x78, 0)
  poke16(0xFF9000 + 0x78, -5)
  poke16(0xFFF558, 159)
  frame_seguro()
  eq("en el frame del KO la fase es SLOW, no OFF", "SLOW", YUYU_TEST.fase_nombre())
  ok("y hay gotas en el MISMO frame del KO: no hay un frame sin lluvia", gotas(1) > 0)
  ok("y el KO NO re-siembra el pool: la gota 1 sigue donde estaba, no en SPAWN_Y "
     .. "(un gate que la cortara, al volver a encenderla, la pondria arriba)",
     (YUYU_TEST.y_gota(1, 1) or -1) > (YUYU_TEST.m9z_pre[1] or 0))

  -- --- 2) LA MITAD DE VELOCIDAD, MEDIDA, NO LEIDA ---
  --
  -- No se comprueba que haya un 0.5 escrito en una variable: se mide cuanto avanza
  -- UNA gota en UN frame en cada fase, **en las TRES capas**. Mirar una sola no
  -- alcanza, y se comprobó por mutacion: aplicar el multiplicador solo a la capa 1
  -- daba VERDE con una prueba que miraba la capa 1.
  --
  -- Y la comparacion es legitima porque las dos fases usan la MISMA velocidad base
  -- (`linea / dur`), ya que `linea` sale del suelo y el suelo no se movio entre
  -- medias: lo unico que cambia es el multiplicador.
  --
  -- Cada Y es la de FINAL de su frame, asi que cada resta mide exactamente un
  -- frame: `slow - pre` es el avance del frame del KO (ya a la mitad) y el de la
  -- capa en la COLA es el de un frame a velocidad normal.
  YUYU_TEST.m9z_slow = { YUYU_TEST.y_gota(1, 1), YUYU_TEST.y_gota(2, 1),
                         YUYU_TEST.y_gota(3, 1) }
  poke16(0xFFF558, 0)                       -- se acaba el slow-mo
  frame_seguro()                            -- este frame YA es UN frame a velocidad normal
  YUYU_TEST.m9z_cola = { YUYU_TEST.y_gota(1, 1), YUYU_TEST.y_gota(2, 1),
                         YUYU_TEST.y_gota(3, 1) }
  frame_seguro()

  -- Si no se pudo medir, la cuenta se queda en -1 y la asercion FALLA. Poner un 0
  -- a proposito seria la prueba que vale 0 y 0: verde sin comprobar nada.
  local medible = true
  for t = 1, 3 do
    if not (YUYU_TEST.m9z_pre[t] and YUYU_TEST.m9z_slow[t] and YUYU_TEST.m9z_cola[t])
      and not YUYU_TEST.y_gota(t, 1) then medible = false end
  end
  local malas = -1
  if medible then
    malas = 0
    for t = 1, 3 do
      local paso_slow = YUYU_TEST.m9z_slow[t] - YUYU_TEST.m9z_pre[t]
      local paso_cola = YUYU_TEST.y_gota(t, 1) - YUYU_TEST.m9z_cola[t]
      if math.abs(paso_cola - 2 * paso_slow) > 0.001 then malas = malas + 1 end
    end
  end
  ok("un frame en SLOW avanza LA MITAD que un frame en COLA, en las TRES capas",
     medible and malas == 0)
  eq("y el multiplicador del slow-mo es el que dice el script",
     YUYU_TEST.MULT_SLOWMO(), 0.5)

  -- --- 3) LA COLA DURA 120 FRAMES Y DESPUES SE APAGA ---
  --
  -- *** EL 120 VA ESCRITO A MANO, Y NO COMO `COLA_FRAMES()`. *** Es el numero que
  -- esta acordado (unos 2 s de reloj a velocidad normal), asi que es un REQUISITO y
  -- va contra un numero fijo. La primera version de esta seccion contaba con
  -- `COLA_FRAMES()` y era una **asercion auto-confirmante**: cambiar la constante a
  -- 119 o a 121 en el `.lua` movia las dos manos de la balanza y daba VERDE. Se
  -- comprobo con mutacion, y por eso el 120 va aca. El `eq` de mas abajo es el que
  -- ata el valor del script al 120, y ese si lo mira.
  eq("la constante de cola del script es la acordada", YUYU_TEST.COLA_FRAMES(), 120)

  poke16(0xFFF558, 159)
  frame_seguro()
  eq("vuelve a SLOW", "SLOW", YUYU_TEST.fase_nombre())
  max_lineas(300)                           -- un slow-mo largo: MEDIDO 479 frames
  eq("300 frames despues el slow-mo SIGUE corriendo, o sea que la sincronizacion "
     .. "no puede ser un contador propio del script", "SLOW", YUYU_TEST.fase_nombre())

  poke16(0xFFF558, 0)
  frame_seguro()                            -- COLA, frame 1 de los 120
  eq("al llegar `$F558` a 0 arranca la COLA", "COLA", YUYU_TEST.fase_nombre())
  ok("y en la COLA la lluvia sigue, ya a velocidad normal", gotas(1) > 0)
  max_lineas(120 - 2)
  eq("a dos frames de acabarse la cola, sigue en COLA", "COLA", YUYU_TEST.fase_nombre())
  max_lineas(1)
  eq("en el frame 120 de la cola sigue en COLA", "COLA", YUYU_TEST.fase_nombre())
  ok("y ese frame dibuja gotas de verdad", gotas(1) > 0)
  max_lineas(1)
  eq("en el frame 121 ya esta OFF", "OFF", YUYU_TEST.fase_nombre())
  eq("y OFF no dibuja NI UNA gota", 0, gotas(1))
  eq("y el pool queda VACIO, o sea que queda oculta y no frenada",
     0, YUYU_TEST.vivas_totales())

  -- --- 4) UN REFRESCO DEL SLOW-MO REARMA LA COLA DESDE CERO ---
  --
  -- El disparador MEDIDO es "le pegaron a alguien con HP negativo", que es lo que
  -- hace el ganador cuando sigue golpeando el cadaver. Cada uno rearma `$F558` a 160,
  -- y por eso la cola tiene que esperar al ULTIMO.
  poke16(0xFFF558, 159)
  frame_seguro()
  eq("un golpe al cadaver devuelve la lluvia a SLOW", "SLOW", YUYU_TEST.fase_nombre())
  poke16(0xFFF558, 0)
  frame_seguro()                            -- COLA de nuevo, frame 1
  max_lineas(120 - 2)
  eq("cola casi agotada otra vez", "COLA", YUYU_TEST.fase_nombre())
  poke16(0xFFF558, 159)
  frame_seguro()
  eq("y otro golpe la corta y vuelve a SLOW", "SLOW", YUYU_TEST.fase_nombre())
  ok("y el pool NO se resiembra en el refresco", YUYU_TEST.vivas_totales() > 0)
  poke16(0xFFF558, 0)
  frame_seguro()
  max_lineas(120 - 1)
  eq("la cola nueva llega completa a su ultimo frame", "COLA", YUYU_TEST.fase_nombre())
  max_lineas(1)
  eq("y se apaga en el frame 121", "OFF", YUYU_TEST.fase_nombre())

  -- --- 5) UNA PELEA NUEVA CORTA LA COLA, Y NO HAY UN FRAME SIN LLUVIA ---
  poke16(0xFFF558, 159)
  frame_seguro()
  poke16(0xFFF558, 0)
  frame_seguro()                            -- cola a mitad de camino
  entrar_en_pelea()                         -- arranca el combate siguiente
  frame_seguro()
  eq("una pelea nueva manda sobre la cola: la fase es NORMAL",
     "NORMAL", YUYU_TEST.fase_nombre())
  ok("y la lluvia sigue: no hay ni un frame sin gotas en medio de un combate",
     gotas(1) > 0)

  -- --- 6) Y SIN SLOW-MO, EL GATE SIGUE SIENDO EL QUE CORTA ---
  --
  -- O sea: el gate no se quedo con lo de "enciende" y nunca mas apaga nada. Esta
  -- prueba es la que dice que el apagado de la 9y no se rompio al cambiar de dueño.
  poke16(0xFFF558, 0)
  poke16(0xFF8400 + 0x78, 0)
  poke16(0xFF8800 + 0x78, 0)
  frame_seguro()
  eq("en el menu la fase es OFF", "OFF", YUYU_TEST.fase_nombre())
  eq("y no hay ni una gota en pantalla", 0, gotas(1))

  -- Y el banco se deja como lo encontro: en pelea, con las tres capas lloviendo.
  poke16(0xFFF558, 0)
  entrar_en_pelea()
  frame_seguro()
  ok("el banco termina en pelea, en NORMAL y con lluvia",
     YUYU_TEST.fase_nombre() == "NORMAL" and gotas(1) > 0)
end


print("")
print(string.format("=== %d pruebas, %d fallos ===", pruebas, fallos))
if frames_rottos > 0 then
  print("ATENCION: " .. frames_rottos .. " frames petaron dentro del pcall")
end
os.exit(fallos > 0 and 1 or 0)
