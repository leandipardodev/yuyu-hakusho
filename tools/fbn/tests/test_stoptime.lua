-- ============================================================================
-- test_stoptime.lua  -  banco de pruebas de "ITSUKI SET MOVE.LUA"
-- ============================================================================
--
-- Corre:      luajit test_stoptime.lua
--
-- Modelo la memoria del juego y el hook de frame de FBNeo, y reproduzco a mano
-- lo que hace 0x1C06E..0x1C088: el recorrido de los 4 slots y el freeze por
-- grupo. Las pruebas miran lo que CAMBIA en el estado, no lo que imprime el
-- script: comparar conteos no distingue "no cambio" de "cambio y me dio lo
-- mismo".
--
-- OJO con Lua: un local declarado despues del punto de uso es un global nil
-- ahi. Por eso el estado se inicializa antes de las funciones que lo tocan.
-- ============================================================================

local pruebas, fallos = 0, 0

local function ok(nombre, cond)
  pruebas = pruebas + 1
  if not cond then
    fallos = fallos + 1
    print("  FALLA: " .. nombre)
  end
end

local function eq(nombre, a, b)
  pruebas = pruebas + 1
  if a ~= b then
    fallos = fallos + 1
    print(string.format("  FALLA: %s  (esperado %s, obtenido %s)",
          nombre, tostring(b), tostring(a)))
  end
end

-- El print de verdad, guardado ANTES de silenciarlo. El script usa `print` como
-- global, asi que cambiar _G.print en cualquier momento lo captura.
local print_real = print

local function capturar(fn)
  local lines = {}
  local anterior = _G.print
  _G.print = function(s) lines[#lines + 1] = tostring(s) end
  local r = fn()
  _G.print = anterior
  return r, lines
end

-- ----------------------------------------------------------------------------
-- Memoria simulada: direccion -> byte
-- ----------------------------------------------------------------------------

-- El Lua de Fightcade es 5.1: no existen &, |, ~, << ni >>. Va con bit.*.
-- (Lo aprendimos a la mala: el test lo caza en la linea 54, no en el emulador.)
local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local mem = {}
local function w8(a, v) mem[a] = band(v, 0xFF) end
local function w16(a, v)
  w8(a, rshift(v, 8))
  w8(a + 1, v)
end

_G.memory = {
  readbyte = function(a) return mem[a] or 0 end,
  readword = function(a)
    return bor(lshift(mem[a] or 0, 8), (mem[a + 1] or 0))
  end,
  readwordsigned = function(a)
    local v = bor(lshift(mem[a] or 0, 8), (mem[a + 1] or 0))
    if v >= 0x8000 then v = v - 0x10000 end
    return v
  end,
  readdword = function(a)
    return bor(bor(lshift(mem[a] or 0, 24), lshift(mem[a + 1] or 0, 16)),
           bor(lshift(mem[a + 2] or 0, 8), (mem[a + 3] or 0)))
  end,
}

-- Cada llamada de dibujo se registra CON SU GEOMETRIA. Para el cartel "OK" hace
-- falta el ancho y el alto de cada cuadro, no solo la cantidad: un conteo no
-- distingue "mas grande" de "la misma cantidad pero mas grandes".
local dibujadas = {}
local n_dibujos = 0

_G.gui = {
  text  = function(x, y, s, c)
    dibujadas[#dibujadas + 1] = { t = "text", x = x, y = y, s = s, c = c }
  end,
  box   = function(l, t, r, b, f, o)
    dibujadas[#dibujadas + 1] = {
      t = "box", x1 = l, y1 = t, x2 = r, y2 = b,
      ancho = r - l + 1, alto = b - t + 1, f = f, o = o,
    }
  end,
  drawline = function() end,
}

-- Tamano de la ventana. Va ANTES de _G.emu porque las clausuras de sus
-- funciones lo referencian: declarado despues seria un global nil dentro del
-- closure, y daria "attempt to perform arithmetic on global 'SW'".
-- El cartel se centra en el espacio de la VENTANA y no en el del juego (ver la
-- seccion de margenes del AGENTS.md), asi que el test usa el mismo numero.
local SW, SH = 320, 224

-- joypad.get() devuelve una tabla donde SOLO estan las teclas pulsadas: las
-- demas son nil, no false. Por eso el script usa truthiness. Aqui va vacia, o
-- sea que ningun comando se dispara salvo que una prueba pulse algo.
local teclas = {}
_G.joypad = {
  get = function() return teclas end,
}

local frame_cb = nil
_G.emu = {
  screenwidth   = function() return SW end,
  screenheight  = function() return SH end,
  romname       = function() return "md_yuyumte" end,
  registerafter = function(f) frame_cb = f end,
}

-- El contador de frame de la PRUEBA, declarado ANTES de frame() porque en Lua
-- un local declarado despues es un global nil en el punto de uso.
local f_prueba = 0
local function frame_n() return f_prueba end

-- Lo mismo con T: lo usan armar_partida() y las pruebas, asi que tiene que
-- existir ANTES de ellas. Solo se publica en _G justo antes del dofile.
local T = {}

local function frame()
  f_prueba = f_prueba + 1
  dibujadas = {}
  if frame_cb then frame_cb() end
end

local SLOTS = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }

-- Poner los 4 slots en juego. $6E: los slots 1 y 3 del grupo 1, los 2 y 4 del 2.
local GRUPOS = { 0x01, 0x02, 0x01, 0x02 }

-- $69. Va declarado arriba porque lo usan armar_partida() y tick_descendente(),
-- y esos estan antes de que existan T.offsets.
local O_FALLBACK_FREEZE = 0x69

local function armar_partida()
  mem = {}
  for i = 1, 4 do
    local b = SLOTS[i]
    w16(b + 0x78, 0x00DF)     -- HP 223, todos vivos
    w8(b + 0x6E, GRUPOS[i])
    w8(b + 0x69, 0)
    w8(b + 0x59, 0)
    w8(b + 0x5B, 0)
    w8(b + 0x60, 0)
  end
  -- Dejar morir el cartel de un ult anterior. La memoria se limpia, pero el
  -- script recuerda hasta que frame se apaga: sin esto, la prueba del cartel
  -- empieza con uno ya en pantalla de un ult de las pruebas anteriores y
  -- "no hay cartel sin ult" falla sin motivo.
  for _ = 1, T.ok.frames() + 2 do frame() end
end

-- Reproduce 0x1C06E..0x1C078 sobre la memoria simulada.
local function ejecutar_ult(lanzador)
  local g = mem[SLOTS[lanzador] + 0x6E]
  for i = 1, 4 do
    local b = SLOTS[i]
    if mem[b + 0x6E] ~= g then
      w8(b + 0x69, 255)
    end
  end
end

-- El decremento de 0x12B36 (subi.b #$1, $69(a5)).
--
-- HACE FALTA, y sin esto el test miente: si $69 se queda en 255 estatico, la
-- maquina de estados ve que "no bajo de a uno", lo toma como un impacto, cierra
-- el ult, y en el frame siguiente ve 255 otra vez y lo vuelve a abrir. El
-- cartel entonces se rearma cada dos frames y nunca se apaga, y la prueba de
-- la DURACION mide eso en vez de lo que quiere medir.
local function tick_descendente()
  for i = 1, 4 do
    local a = SLOTS[i] + O_FALLBACK_FREEZE
    local v = mem[a] or 0
    if v > 0 then w8(a, v - 1) end
  end
end

-- El gate: el test lo pide ANTES del dofile.
_G.__yuyu_test = T

_G.print = function() end            -- el arranque del script no imprime
dofile("tools/fightcade/ITSUKI SET MOVE.LUA")

local est = T.estado()
local O   = T.offsets
local C   = T.consts

-- Restaurar YA. Si se olvida, los "FALLA" de ok()/eq() se tragan en el mismo
-- print silenciado del arranque, y el banco solo dice cuantas faltaron sin
-- decir cuales. Es la misma trampa de "salida muda" que evita el script, y
-- uno se la puso a si mismo.
_G.print = print_real

--------------------------------------------------------------------------------
-- 7. AUDITOR DE TIPOS DE string.format
--
-- QUE PASÓ
--
-- El 07-10 el script se cayo en ejecucion con
--     ITSUKI SET MOVE.LUA:511: bad argument #2 to 'format' (number expected, got string)
-- por `string.format("$5F vivo=$%02X ...", hex2(e.estado), ...)`.
--
-- POR QUE NO LO ATAPO EL BANCO
--
-- Porque %X SI acepta un string SIEMPRE que se pueda parsear como numero:
--
--     LuaJIT: string.format("%02X", "10")    -> true   (lo parsea como 10)
--     LuaJIT: string.format("%02X", hex2(13)) -> false  ("0D" no es un numero)
--
-- Y todos los valores que usaban las pruebas daban hex PARSEABLE: $08 -> "08" = 8,
-- $40 -> "40" = 40, $47 -> "47" = 47. Con $0D -- que es el id que dio el juego de
-- verdad -- revienta. O sea que **el banco pasaba por suerte**, y una prueba que
-- depende del VALOR no puede encontrar un bug de TIPO.
--
-- QUE HACE ESTE
--
-- Envuelve `string.format` durante TODA la corrida y chequea, especificador por
-- especificador, que a cada %d/%i/%X/%x/%f le llegue un numero. No depende de
-- ningun valor: mira la FORMA de la llamada, que es donde esta el bug.
--
-- Va aqui, justo despues del dofile, para que cubra los `frame()` de todas las
-- secciones. Con mayusculas, para que se vea que es del banco y no del script.
--------------------------------------------------------------------------------

local ESPEC_NUM = {
  d = true, i = true, u = true, X = true, x = true, o = true,
  c = true, f = true, e = true, E = true, g = true, G = true,
}

-- Devuelve las conversiones de un formato, en orden. `%%` no cuenta.
local function conversiones(fmt)
  local out = {}
  local k, n = 1, #fmt
  while k <= n do
    if fmt:sub(k, k) ~= "%" then
      k = k + 1
    else
      local j = k + 1
      while j <= n and fmt:sub(j, j):find("[%-+ #0]") do j = j + 1 end   -- flags
      while j <= n and fmt:sub(j, j):find("%d") do j = j + 1 end        -- ancho
      if fmt:sub(j, j) == "." then                                        -- precision
        j = j + 1
        while j <= n and fmt:sub(j, j):find("%d") do j = j + 1 end
      end
      local conv = fmt:sub(j, j)
      if conv ~= "" and conv ~= "%" then out[#out + 1] = conv end
      k = j + 1
    end
  end
  return out
end

local FORMAT_REAL = string.format
local FORMAT_MALO = nil      -- la primera llamada con tipo incorrecto
local N_AUDITADAS = 0

string.format = function(fmt, ...)
  local conv = conversiones(tostring(fmt))
  N_AUDITADAS = N_AUDITADAS + 1
  local args = { ... }
  for k = 1, #conv do
    if ESPEC_NUM[conv[k]] and type(args[k]) ~= "number" then
      local info = debug.getinfo(2, "Sl")
      FORMAT_MALO = FORMAT_MALO or FORMAT_REAL(
        "%%%s recibio un %s (%s) en %s linea %d -- se esperaba un numero",
        conv[k], type(args[k]), tostring(args[k]),
        info and info.short_src or "?", info and info.currentline or 0)
    end
  end
  return FORMAT_REAL(fmt, ...)
end

--------------------------------------------------------------------------------
-- 1. Los offsets del script son los del ROM
--------------------------------------------------------------------------------
eq("offset del freeze es $69", O.freeze, 0x69)
eq("offset del grupo es $6E",  O.grupo,  0x6E)
eq("offset del frame es $59",  O.frame,  0x59)
eq("offset del tick es $5B",   O.tick,   0x5B)
eq("offset del flag es $60",   O.flag,   0x60)
eq("el freeze del ult es 255", C.ult_freeze, 255)
eq("el frame del ult es 2",    C.ult_frame,  2)
eq("el tick del ult es 0",     C.ult_tick,   0)

--------------------------------------------------------------------------------
-- 2. Un frame normal no congela a nadie
--------------------------------------------------------------------------------
armar_partida()
frame()
for i = 1, 4 do
  ok("sin ult nadie queda en 255 (slot " .. i .. ")", est[i].freeze ~= 255)
  ok("sin ult nadie marca en_ult (slot " .. i .. ")", est[i].en_ult == false)
end

--------------------------------------------------------------------------------
-- 3. EL ULT: slot 1 lanza y se congelan SOLO los de otro grupo
--------------------------------------------------------------------------------
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)   -- 0x1C03A
w8(SLOTS[1] + O.tick,  C.ult_tick)    -- 0x1C042
w8(SLOTS[1] + O.flag,  0)             -- 0x1C032
ejecutar_ult(1)
frame()

eq("el lanzador NO se congela a si mismo", est[1].freeze, 0)
eq("slot 2, de otro grupo, CONGELADO",    est[2].freeze, 255)
eq("slot 3, del mismo grupo, LIBRE",      est[3].freeze, 0)
eq("slot 4, de otro grupo, CONGELADO",    est[4].freeze, 255)
eq("los congelados cuentan 1 frame",      est[2].frames, 1)
ok("el lanzador cumple la firma", est[1].frame == 2 and est[1].tick == 0 and est[1].flag ~= 1)

local fallas, g = T.regla_6e(1)
eq("la regla $6E no tiene fallas con los grupos alternados", fallas, 0)
eq("el grupo del lanzador es $01", g, 0x01)

--------------------------------------------------------------------------------
-- 4. La cuenta regresiva baja de a uno, como 0x12B36
--------------------------------------------------------------------------------
for k = 254, 1, -1 do
  w8(SLOTS[2] + O.freeze, k)
  w8(SLOTS[4] + O.freeze, k)
  frame()
end
eq("el contador llega a 1 sin cortar", est[2].freeze, 1)
ok("sigue en el ult en el frame 255", est[2].en_ult == true)
eq("el slot lleva 255 frames",        est[2].frames, 255)

w8(SLOTS[2] + O.freeze, 0)
w8(SLOTS[4] + O.freeze, 0)
frame()
ok("llegando a 0 SALIO del ult", est[2].en_ult == false)

--------------------------------------------------------------------------------
-- 5. Un impacto SOBREESCRIBE el byte y eso tambien corta el ult
--
-- 0x1F2E0 pone 16 en $69: ni 255 ni 254. El corte es por impacto.
--------------------------------------------------------------------------------
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
ejecutar_ult(1)
frame()
eq("arranco el ult de nuevo", est[2].freeze, 255)

w8(SLOTS[2] + O.freeze, 200)          -- como si el resolver pusiera otra cosa
frame()
ok("un valor que no es 254 tambien corta", est[2].en_ult == false)

--------------------------------------------------------------------------------
-- 6. $60 == 1 hace que NO sea el ult (0x1C032)
--------------------------------------------------------------------------------
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[1] + O.tick,  C.ult_tick)
w8(SLOTS[1] + O.flag,  1)             -- la bandera que corta el ult
frame()
local hay = false
for i = 1, 4 do
  local e = est[i]
  if e.frame == C.ult_frame and e.tick == C.ult_tick and e.flag ~= 1 then hay = true end
end
ok("con $60=1 no se encuentra lanzador", hay == false)

--------------------------------------------------------------------------------
-- 7. La regla $6E se FALLA cuando el juego se portaria mal
--
-- Esto es lo que prueba que la comprobacion mira de verdad y no pasa siempre.
--------------------------------------------------------------------------------
-- Escenario A: congelo a un aliado y NO a los enemigos.
-- Son TRES fallas, no una: las dos de "enemigo sin congelar" mas la del aliado.
-- Es lo que el codigo haria mal, punto por punto.
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[3] + O.freeze, 255)          -- aliado congelado: el codigo no lo haria
frame()
eq("aliado congelado + enemigos sueltos = 3 fallas", T.regla_6e(1), 3)

-- Escenario B: congelo a TODOS, incluido el aliado. Solo queda la falla del
-- aliado, que es lo que la prueba quiere aislar.
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
for _, i in ipairs({ 2, 3, 4 }) do w8(SLOTS[i] + O.freeze, 255) end
frame()
eq("congelar a un aliado es UNA falla cuando el resto esta bien", T.regla_6e(1), 1)

-- Escenario C: el ult bien hecho, no congela a nadie del mismo grupo.
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[2] + O.freeze, 255)
w8(SLOTS[4] + O.freeze, 255)
frame()
eq("el escenario bien puesto da 0 fallas", T.regla_6e(1), 0)

-- Escenario D: enemigos sin congelar son 2 fallas, una por enemigo.
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
frame()
eq("no congelar a los dos enemigos son 2 fallas", T.regla_6e(1), 2)

--------------------------------------------------------------------------------
-- 8. Un slot muerto no se mira: no esta peleando
--
-- El ult se hace BIEN (congela a 2 y 4) y despues uno de los congelados muere.
-- Si el script mirara los muertos, el muerto sin congelar contaria como falla.
--------------------------------------------------------------------------------
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[2] + O.freeze, 255)
w8(SLOTS[4] + O.freeze, 255)
frame()
eq("antes de morir, 0 fallas", T.regla_6e(1), 0)
w16(SLOTS[4] + O.hp, 0x0000)          -- slot 4 muere, congelado
frame()
eq("con un slot muerto no aparece una falla nueva", T.regla_6e(1), 0)

-- Y al reves: si el muerto es el que NO estaba congelado, tampoco cuenta.
armar_partida()
w16(SLOTS[3] + O.hp, 0x0000)          -- slot 3 muere (era aliado, no iba a congelarse)
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[2] + O.freeze, 255)
w8(SLOTS[4] + O.freeze, 255)
frame()
eq("el aliado muerto tampoco genera falla", T.regla_6e(1), 0)

--------------------------------------------------------------------------------
-- 9. Dibujo: solo los slots vivos, y el congelado se distingue
--
-- Se cuentan SOLO los textos. A partir del cartel "OK" tambien se dibujan
-- cuadros, asi que contar todos los dibujos daria 34 en vez de 3.
--------------------------------------------------------------------------------
local function solo_textos()
  local n = 0
  for _, d in ipairs(dibujadas) do
    if d.t == "text" then n = n + 1 end
  end
  return n
end

-- Los CUADROS del cartel, sin los textos del readout de los slots. Hace falta
-- separarlos: en un frame con ulti hay 4 textos (uno por slot vivo) MAS los 31
-- cuadros del cartel, y contar todo junto daba 35 donde se esperaban 31.
local function solo_cajas()
  local n = 0
  for _, d in ipairs(dibujadas) do
    if d.t == "box" then n = n + 1 end
  end
  return n
end

armar_partida()
w16(SLOTS[3] + O.hp, 0)
w8(SLOTS[1] + O.frame, C.ult_frame)
ejecutar_ult(1)
dibujadas = {}
frame()
eq("se dibujan 4 textos con un slot muerto", solo_textos(), 4)
local congelado_marcado = false
for _, d in ipairs(dibujadas) do
  if d.t == "text" and string.find(d.s, "CONGELADO") then congelado_marcado = true end
end
ok("el slot congelado se marca CONGELADO", congelado_marcado)

--------------------------------------------------------------------------------
-- 10. Latido: el script avisa aunque no pase nada
--
-- Sin esto, un hook callado es indistinguible de uno que no hace nada.
--
-- Se corre un poco mas de un ciclo entero (1300 > 2 x 600) y no exactamente
-- 600: el latido sale en los multiplos de 600 del contador DEL SCRIPT, y ese
-- contador ya venia corrido por los frames que consume armar_partida(). Con
-- exactamente 600 frames no se garantiza que se pille un multiplo.
--------------------------------------------------------------------------------
armar_partida()
local _, lineas = capturar(function()
  for _ = 1, 1300 do frame() end
end)
local hay_latido = false
for _, s in ipairs(lineas) do
  if string.find(s, "latido") then hay_latido = true end
end
ok("dentro de un ciclo de latido hay aviso", hay_latido)

--------------------------------------------------------------------------------
-- 11. Y el latido NO tapa el trabajo util: los eventos tambien salen
--------------------------------------------------------------------------------
armar_partida()
local _, ev = capturar(function()
  w8(SLOTS[1] + O.frame, C.ult_frame)
  ejecutar_ult(1)
  frame()
end)
local hay_ult = false
local hay_regla = false
for _, s in ipairs(ev) do
  if string.find(s, "ULT") then hay_ult = true end
  if string.find(s, "REGLA") then hay_regla = true end
end
ok("el arranque del ult se avisa", hay_ult)
ok("la comprobacion de la regla $6E se avisa", hay_regla)

--------------------------------------------------------------------------------
-- 12. EL CARTEL "OK"
--
-- El proposito del cartel es que se vea a ojo, asi que lo que se verifica es
-- que sea GRANDE, que salga en el frame exacto del arranque, y que se apague solo.
-- El tamano se mide por la GEOMETRIA de las cajas, no contando lineas: un
-- conteo no distingue "mas grande" de "la misma cantidad pero mas grandes".
-- ----------------------------------------------------------------------------

local OK = T.ok
local puntos_o, puntos_k = 16, 14      -- "1" de cada glifo de 5x7
eq("el glifo O tiene 16 puntos", OK.puntos_de(OK.glifo_o()), puntos_o)
eq("el glifo K tiene 14 puntos", OK.puntos_de(OK.glifo_k()), puntos_k)
eq("los dos glifos suman 30 puntos", OK.puntos(), puntos_o + puntos_k)

-- Los glifos son 5 de ancho por 7 de alto
eq("el glifo O mide 5x7", #OK.glifo_o(), 7)
eq("el glifo O es de 5 de ancho", #OK.glifo_o()[1], 5)
eq("el glifo K mide 5x7", #OK.glifo_k(), 7)
eq("el glifo K es de 5 de ancho", #OK.glifo_k()[1], 5)

-- Los otros dos parametros del cartel, contra numeros fijos y no contra lo que
-- el script dice que usa. Con las dos cosas calculadas a partir de OK.margen()
-- y OK.frames(), mutarlos a 0 y a 5 daba 74 de 74: las dos sides cambiaban
-- juntas y la relacion se mantenia.
eq("el margen del cartel es 14 por el defecto", OK.margen(), 14)
ok("el margen deja aire alrededor de las letras (>= 6)", OK.margen() >= 6)
eq("el cartel dura 75 frames por el defecto", OK.frames(), 75)
ok("el cartel dura lo bastante para poder verlo (>= 30)", OK.frames() >= 30)

-- Un frame normal: NINGUN cuadro del cartel
armar_partida()
dibujadas = {}
frame()
eq("sin ult no hay ni un cuadro del cartel", solo_cajas(), 0)
eq("sin ult hay 5 textos: 4 slots mas el contador", solo_textos(), 5)

-- El frame del arranque: fondo + 30 cuadros de glifo
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
ejecutar_ult(1)
dibujadas = {}
frame()
eq("el cartel dibuja fondo + 30 pixeles", solo_cajas(), 1 + OK.puntos())

-- La GEOMETRIA: cada cuadro de glifo tiene ESCALA_OK x ESCALA_OK
local esc = OK.escala()

-- PRIMERO, que sea GRANDE de verdad.
--
-- OJO: todas las medidas de abajo se calculan con OK.escala(), asi que entre
-- ellas miden CONSISTENCIA y no el requisito. Con ESCALA_OK = 1 el cartel seria
-- de 5x7 px, ilegible, y todas pasarian igual porque las dos sides cambian
-- juntas. Mutarlo a 1 daba 70 de 70. Por eso el tamano se comprueba contra un
-- numero fijo, y no contra lo que el script dice que usa.
eq("la escala del cartel es la de por defecto (9)", esc, 9)
ok("la escala es al menos 5, si no el cartel es ilegible", esc >= 5)
ok("la letra es de al menos 35 px de alto", 7 * esc >= 35)
-- El ancho total son 5*esc para la O, un hueco de esc, y 5*esc para la K.
-- Con la escala por defecto son 45 + 9 + 45 = 99 px.
ok("el cartel entero es de al menos 90 px de ancho", (5 * esc * 2 + esc) >= 90)

local glifo_boxes = {}
for _, d in ipairs(dibujadas) do
  if d.t == "box" and d.ancho == esc then glifo_boxes[#glifo_boxes + 1] = d end
end
eq("los 30 pixeles del glifo son de ESCALA x ESCALA", #glifo_boxes, OK.puntos())
local todos_cuadrados = true
local ancho_total = 0
for _, d in ipairs(glifo_boxes) do
  if d.ancho ~= d.alto then todos_cuadrados = false end
  ancho_total = ancho_total + d.ancho
end
ok("cada pixel del glifo es un cuadro", todos_cuadrados)
eq("el ancho dibujado son 30 x ESCALA", ancho_total, OK.puntos() * esc)

-- El fondo es el unico cuadro que NO es del tamano del glifo
local fondo = nil
for _, d in ipairs(dibujadas) do
  if d.t == "box" and d.ancho ~= esc then fondo = d end
end
ok("el fondo del cartel esta dibujado", fondo ~= nil)
if fondo then
  -- El fondo tiene que ser EXACTAMENTE las dos letras, el hueco entre ellas y
  -- el margen por los cuatro lados. Se compara el numero exacto y no "mas
  -- grande que una letra": un ">=" pasaria con un fondo del tamano de una sola.
  --
  -- OJO el +1: gui.box toma las esquinas INCLUSIVAS, asi que el ancho que
  -- ocupa un rectangulo es (derecha - izquierda + 1), no la diferencia. Sin el
  -- +1 las dos medidas dan 127 y 91 en vez de 128 y 92.
  eq("el fondo mide las dos letras mas el hueco mas el margen",
     fondo.ancho, 5 * esc * 2 + esc + 2 * OK.margen() + 1)
  eq("el fondo mide las 7 filas mas el margen",
     fondo.alto, 7 * esc + 2 * OK.margen() + 1)
end

-- CENTRADO: el fondo tiene que estar centrado en la ventana
if fondo then
  local centro_x = (fondo.x1 + fondo.x2) / 2
  local delta = math.abs(centro_x - SW / 2)
  ok("el cartel esta centrado en X (delta " .. delta .. ")", delta <= 1)
  local centro_y = (fondo.y1 + fondo.y2) / 2
  local dy = math.abs(centro_y - SH / 2)
  ok("el cartel esta centrado en Y (delta " .. dy .. ")", dy <= 1)
end

-- DURACION: aparece en el frame del arranque y se apaga solo
armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
ejecutar_ult(1)
dibujadas = {}
frame()
eq("el frame del arranque ya muestra el cartel", solo_cajas(), 1 + OK.puntos())
eq("el cartel se armo en el frame del arranque", OK.desde(), frame_n())
-- +1 porque el arranque CUENTA como un frame del cartel: se dibuja en el
-- frame en que se arma, no en el siguiente.
eq("el cartel dura OK_FRAMES exactos", OK.hasta() - OK.desde() + 1, OK.frames())

-- Sigue en pantalla un frame antes de apagarse. $69 baja de a uno cada frame,
-- como hace 0x12B36, para que el ult siga vivo durante el cartel.
for _ = 1, OK.frames() - 1 do
  tick_descendente()
  dibujadas = {}
  frame()
end
eq("un frame antes de cumplirse, el cartel sigue", solo_cajas(), 1 + OK.puntos())
ok("el ult sigue vivo durante el cartel", est[2].en_ult == true)
eq("el cartel NO se rearma mientras el ult dura", OK.desde(), frame_n() - (OK.frames() - 1))

-- Y en el frame en que se apaga, no queda nada
tick_descendente()
dibujadas = {}
frame()
eq("en el frame en que se cumple, el cartel desaparece", solo_cajas(), 0)

-- Un SEGUNDO ult vuelve a armarlo (no queda pegado)
w8(SLOTS[2] + O.freeze, 200)   -- el primero muere por impacto
frame()
w8(SLOTS[1] + O.frame, C.ult_frame)
w8(SLOTS[2] + O.freeze, 255)
w8(SLOTS[4] + O.freeze, 255)
dibujadas = {}
frame()
eq("un segundo ult vuelve a levantar el cartel", solo_cajas(), 1 + OK.puntos())

--------------------------------------------------------------------------------
-- 13. NINGUN color dibujado puede ser INVISIBLE
--
-- Este banco no existia y por ahi se escapo el bug: las tres constantes de color
-- se escribieron con el byte BAJO en 00, que es ALFA CERO. El fondo se veia
-- porque su alfa es C8, pero las LETRAS y el BORDE salian invisibles y el
-- cartel decia "OK" sin_OK. El comentario de cada constante decia "opaco".
--
-- El sintoma en ejecucion es desconcertante: el cartel aparece y las letras no,
-- que parece un problema de posicion o de tamano y es de color.
--------------------------------------------------------------------------------
local function alfa_de(col) return band(col, 0xFF) end

-- El caso negativo, para que la prueba se autocompruebe y no sea tautologica
ok("el byte bajo de 0xFFFFFF00 es 0 (el bug)",   alfa_de(0xFFFFFF00) == 0)
ok("el byte bajo de 0xFFFFFFFF es 255",          alfa_de(0xFFFFFFFF) == 255)

armar_partida()
w8(SLOTS[1] + O.frame, C.ult_frame)
ejecutar_ult(1)
dibujadas = {}
frame()

-- OJO: NO se puede recorrer { d.c, d.f, d.o } con ipairs. Un cuadro no tiene
-- `c` y un texto no tiene `f` ni `o`, asi que la tabla es dispersa e **ipairs se
-- detiene en el primer nil**. Con ipairs solo se contaban los 4 textos (Revision
-- = 4) y los 31 cuadros del cartel pasaban sin revisar: el test daba verde con
-- las letras invisibles. Hay que mirar los tres campos por separado.
-- Devuelve (revisados, invisibles). OJO con el orden: alfa 0 significa
-- INVISIBLE, asi que ese caso devuelve 1 invisible. Tenerlo al reves hace que
-- el test falle con los colores CORRECTOS (66 invisibles de 66) y que las tres
-- mutaciones den el MISMO numero de fallos que la base: el test no distinguia
-- nada.
local function revisar_color(col)
  if col == nil then return 0, 0 end
  if alfa_de(col) == 0 then return 1, 1 end
  return 1, 0
end

local invisibles, revisados = 0, 0
for _, d in ipairs(dibujadas) do
  for _, col in pairs({ c = d.c, f = d.f, o = d.o }) do
    local n, inv = revisar_color(col)
    revisados = revisados + n
    invisibles = invisibles + inv
  end
end
ok("se revisaron todos los colores del frame (" .. revisados .. ")", revisados > 60)
eq("ningun color dibujado tiene alfa 0", invisibles, 0)

-- 14. EL RASTREADOR DE TECNICAS
--
-- El camino de direccionamiento, verbatim de loc_01eb40:
--
--   a2 = $50 + word[id] + frame * 8
--   tabB = $8C + byte(reg+1) * 4
--   hit  = tabB + word(tabB+1)
--
-- Se monta una tabla de moves falsa con DOS ids y offsets ALTERNOS, que es lo
-- que separa "usa el indice correcto" de "suma 0 y por lo tanto da la misma
-- direccion para todos".
--------------------------------------------------------------------------------

local M = T.mov
local MO = M.offsets

eq("el puntero de la tabla A esta en $50", MO.tabla_a, 0x50)
eq("el puntero de la tabla B esta en $8C", MO.tabla_b, 0x8C)
eq("la tercera tabla esta en $90",         MO.tabla_90, 0x90)
eq("el handler esta en $1C",               MO.handler, 0x1C)

-- Direcciones de ROM simuladas, con numeros altos a proposito: si el codigo las
-- enmascara a 16 bits daria otra cosa.
local TAB_A = 0x00BF75A
local TAB_B = 0x00C04CA

local OFFS = { [0] = 0x010, [1] = 0x030 }

-- Los 8 bytes de (id, frame), en indices Lua (1..8), y el registro los
--   leen en 0..7. Por eso el bucle va con [k + 1].
local REGS = {
  [0] = { {8, 0, 0, 0x44, 3, 0, 0x82, 0xA0}, {4, 0, 0, 0xC4, 3, 0, 0x90, 0xB0} },
  [1] = { {6, 1, 1, 0x44, 7, 0, 0x88, 0xA8} },
}

-- tabB[mult*4 .. mult*4+3]: +0 attrs (bit6=activo), +1 word (->$3C), +2 offset, +3 sonido
-- Los subregistros van en TAB_B + mult*4, y cada mult TIENE SUYO. Meter dos
-- subregistros en la misma direccion los pisa: el ultimo que se escribe gana,
-- y la direccion del golpe sale mal. Por eso mult 0 esta en +0 y mult 1 en +4.
local MULT0, MULT1 = 0, 4
local OFF_HIT0, OFF_HIT1 = 0x100, 0x110

local SUBS = {
  [MULT0] = { attrs = 0x40, byte1 = 0x02, offset = OFF_HIT0, sonido = 0x00 },
  [MULT1] = { attrs = 0x00, byte1 = 0x04, offset = OFF_HIT1, sonido = 0x00 },
}

-- Los golpes viven LEJOS del subregistro, para que el offset apunte afuera.
local HITS = { [OFF_HIT0] = { 8, 4, 1 }, [OFF_HIT1] = { 12, 6, 2 } }

local function montar_tablas()
  for id, off in pairs(OFFS) do w16(TAB_A + id * 2, off) end
  for id, frames in pairs(REGS) do
    for fr = 0, #frames - 1 do
      local base = TAB_A + OFFS[id] + fr * 8
      for k = 0, 7 do w8(base + k, frames[fr + 1][k + 1]) end
    end
  end
  for mult, s in pairs(SUBS) do
    local base = TAB_B + mult
    w8(base + 0, s.attrs)
    w8(base + 1, s.byte1)     -- es un BYTE, va a $3C con *2
    w16(base + 2, s.offset)   -- es un WORD, y es el OFFSET al golpe
    w8(base + 3, s.sonido)
  end
  for off, h in pairs(HITS) do
    for k = 0, 2 do w8(TAB_B + off + k, h[k + 1]) end
  end
end

-- el script calcula direcciones con los 24 bits equivocados.
local function w32(a, v)
  w8(a,     band(rshift(v, 24), 0xFF))
  w8(a + 1, band(rshift(v, 16), 0xFF))
  w8(a + 2, band(rshift(v, 8),  0xFF))
  w8(a + 3, band(v, 0xFF))
end

local function poner_punteros(i)
  w32(SLOTS[i] + 0x50, TAB_A)
  w32(SLOTS[i] + 0x8C, TAB_B)
end

armar_partida()
montar_tablas()
for i = 1, 4 do poner_punteros(i) end
for i = 2, 4 do w16(SLOTS[i] + 0x78, 0) end

local d00 = M.dir_registro(1, 0, 0)
eq("id 0 frame 0 da TAB_A + word[0]", d00, TAB_A + OFFS[0])
eq("id 0 frame 1 suma 8, no 1", M.dir_registro(1, 0, 1) - d00, 8)
eq("id 0 frame 2 suma 16",         M.dir_registro(1, 0, 2) - d00, 16)

local d10 = M.dir_registro(1, 1, 0)
eq("id 1 usa SU word del indice", d10, TAB_A + OFFS[1])
ok("los dos ids NO dan la misma direccion", d00 ~= d10)
eq("la diferencia es la de los words", d10 - d00, OFFS[1] - OFFS[0])

local r00 = M.leer_registro(d00)
eq("byte +0 = duracion",    r00[0], 8)
eq("byte +3 = atributos",   r00[3], 0x44)
eq("byte +4 = sonido",      r00[4], 3)
eq("byte +6 = velocidad X", r00[6], 0x82)

local tB0 = M.dir_tabB(1, r00)
eq("tabB del id 0 = TAB_B + mult*4", tB0, TAB_B)
ok("el bit 6 del byte +0 de tabB es el de ACTIVO", M.act_bito(0x40))
ok("sin bit 6 NO es activo", not M.act_bito(0x00))
ok("0xC4 SI tiene bit 6", M.act_bito(0xC4))

-- El multiplicador del subregistro es 4, y con mult 0 NO se nota: 0*4 y 0*1
-- dan lo mismo. Por eso hace falta un registro con mult DISTINTO de cero, o la
-- mutacion "reg[1] * 4 -> reg[1]" pasa sin que nadie lo note.
local r10 = M.leer_registro(M.dir_registro(1, 1, 0))
eq("byte +1 del id 1 es 1", r10[1], 1)
eq("tabB con mult 1 va a TAB_B + 1*4", M.dir_tabB(1, r10), TAB_B + MULT1)
ok("mult 1 NO da el mismo subregistro que mult 0", M.dir_tabB(1, r10) ~= tB0)
ok("el subregistro de mult 1 es 4 bytes mas alla", (M.dir_tabB(1, r10) - tB0) == 4)

local h0 = M.dir_hit(1, tB0)
eq("el golpe sale de tabB + el WORD de +2", h0, TAB_B + OFF_HIT0)

-- Y ahora a traves del paso de frame, que es como lo usa el script de verdad
armar_partida()
montar_tablas()
for i = 1, 4 do poner_punteros(i) end
for i = 2, 4 do w16(SLOTS[i] + 0x78, 0) end
M.nuevo_lote()


--------------------------------------------------------------------------------
-- 16. COORDENADAS PRESTADAS Y DETECCION DE TELETRANSPORTE
--
-- El sistema de coordenadas viene prestado de LLUVIA RECTA.LUA. Se importa la
-- FORMULA y sus offsets, no el archivo entero (que trae escrituras).
--
-- Lo que importa para el caso de uso: una teletransporte saca al personaje FUERA
-- de la caja de clamp de $08/$0C, asi que la posicion de PANTALLA se satura y
-- hay que medir la de MUNDO.
--
-- *** EL RESET VA DESPUES DE armar_partida() ***
--
-- armar_partida() corre 77 frames reales, y en cada una paso() llama a
-- detectar_tele. Si el reset va antes, quedan populated y el primer "delta" que
-- ve la prueba es el salto de 0 a 100 del armado, no el que la prueba quiere.
-- Por eso el reset va entre armar_partida() y el primer leer_mundo, y SOLO
-- una vez por bloque: si va antes de cada llamada, no hay posicion previa y el
-- delta nunca existe.
--------------------------------------------------------------------------------

local CO = T.coord
local COO = CO.offsets

eq("el offset de X en mundo es $40",  COO.wx, 0x40)
eq("el offset de Y en mundo es $44",  COO.wy, 0x44)
eq("la parte FRACCIONAL de X es $42", COO.wx_fr, 0x42)
eq("la parte FRACCIONAL de Y es $46", COO.wy_fr, 0x46)
eq("la pantalla CLAMPADA es $08/$0C", COO.sx, 0x08)
eq("la velocidad es $28/$2A",         COO.vx, 0x28)
eq("la base del stage X es $FFA014",  COO.stage_x, 0xFFA014)
eq("la base del stage Y es $FFA016",  COO.stage_y, 0xFFA016)
eq("el scroll vertical es $FFF566",   COO.scroll_y, 0xFFF566)
eq("una unidad de la fraccion es 1/65536 de px", CO.fraccion(), 65536)

-- *** LA CALIBRACION PRESTADA SE SACO DEL SCRIPT, Y POR QUE ***
--
-- `CAL_X, CAL_Y = -127, -127` venía de `LLUVIA RECTA.LUA`, donde esta
-- justificada: el HUD dibuja CAJAS y la caja tiene otro ancla que el origen del
-- personaje. Aplicado al JUGADOR da 127 px de error en los dos ejes, sin avisar.
--
-- MEDIDO el 07-10: con mundo X=1025 y base de stage 973, `$08` valia 180, y lo
-- que el script imprimia era 53. 53 + 127 = 180.
--
-- La prueba de que no esta es que la funcion ya no existe: si alguien la
-- vuelve a agregar, esto falla.
eq("ya NO hay calibracion -127 en la conversion", CO.cal, nil)

local function mundo_en(x, y)
  for i = 1, 4 do
    w16(SLOTS[i] + 0x40, x); w16(SLOTS[i] + 0x44, y)
    w16(SLOTS[i] + 0x42, 0);   w16(SLOTS[i] + 0x46, 0)
    w16(SLOTS[i] + 0x28, 0);   w16(SLOTS[i] + 0x2A, 0)
  end
end

-- --- La pantalla del JUGADOR es $08/$0C, tal cual ---
--
-- `loc_0156F0` ya la calcula y la deja en $08/$0C. Recalcularla y calibrarla
-- era peor que redundante: por un lado daba 127 px de error (ver arriba), y por
-- otro perdia el dato del clamp, que es justo lo que uno quiere ver.
armar_partida()
mundo_en(100, 80)
w16(0xFFA014, 0); w16(0xFFA016, 0); w16(0xFFF566, 0)
CO.reset()
CO.leer_mundo(1)
-- Valores arbitrarios a proposito: la prueba es que el script COPIA los de $08.
w16(SLOTS[1] + 0x08, 180); w16(SLOTS[1] + 0x0C, 309)
CO.leer_mundo(1)
local sx, sy = CO.pantalla(1)
eq("la pantalla del jugador es $08 tal cual", sx, 180)
eq("y $0C tal cual", sy, 309)

-- --- Y aparte, la misma cuenta SIN el clamp: `crudo_de` ---
--
-- *** TIENE QUE LLEVAR EL -8 DEL FINAL ***
--
-- `loc_0156F0` termina con `subq.w #$8, d0` antes de escribir `$0C`. Sin ese -8
-- la Y difiere SIEMPRE en 8 y el aviso de clamp disparaba en cada teletransporte
-- sin que hubiera saturacion. Se vio el 07-10 en la salida real:
--     $08/$0C = 432/316  |  la misma cuenta SIN clamp = 432/324
-- con X coincidente exacto. Los 8 no eran saturacion.
--
-- OJO: esta prueba existed antes con `+ 0x20` sin el -8, y su asercion de
-- "coinciden" daba verde siempre. Un test que no puede fallar no es un test.
CO.leer_mundo(1)
local cx, cy = CO.crudo(1)
eq("el X sin clamp es mundo - base del stage + 128", cx, 100 - 0 + 0x80)
eq("la Y sin clamp incluye el -8 de 0x15744",
   cy, 80 - 0 + 0 + 0x20 - 8)

-- Y la contraprueba: sin saturacion, crudo y $08/$0C coinciden en los dos ejes.
--
-- OJO: esto ya NO es cierto al pixel. `$54` entra en la cuenta de `$08`
-- (`add.w $54(a5), d0` en 0x156FC) y `loc_0156F0` lo borra en 0x15718, asi que
-- crudo no puede reproducirlo. MEDIDO: 176 contra 177. Por eso el aviso de clamp
-- NO compara los dos valores sino si el crudo se sale de la CAJA.
-- La contraprueba, con numeros ESCRITOS y no sacados de crudo_de: una prueba
-- que compara la funcion contra si misma no puede fallar, y ya se hizo esa vez.
--
-- Con el mundo en (100, 80), base de stage en 0 y scroll en 0, el crudo da:
--   X = 100 - 0 + 0x80          = 228
--   Y =  80 - 0 + 0 + 0x20 - 8  = 104
eq("el crudo sin saturar no avisa", CO.donde_satura(228, 104), nil)
-- Y con el pixel de vaiven de $54 que se midio el 07-10 ($08 = 176, crudo = 177):
-- un pixel de diferencia NO es saturacion.
eq("un pixel de vaiven de $54 tampoco satura", CO.donde_satura(229, 104), nil)

-- Los limites de la caja, que salen de 0x15700-0x15740 y el -8 de 0x15744.
CO.leer_mundo(1)
eq("la caja en X arranca en $40", (CO.donde_satura(0x3F, 200)), "X")
eq("y termina en $1FF",          (CO.donde_satura(0x200, 200)), "X")
eq("el ultimo valor de X no satura", (CO.donde_satura(0x1FF, 200)), nil)
eq("la caja en Y va de $38 a $1B8, con el -8 ya aplicado",
   (CO.donde_satura(200, 0x37)), "Y")
eq("y el ultimo valor de Y no satura", (CO.donde_satura(200, 0x1B8)), nil)

-- La base del stage corre el crudo, y en los dos ejes.
w16(0xFFA014, 40); w16(0xFFA016, 20)
CO.leer_mundo(1)
local cx2, cy2 = CO.crudo(1)
eq("mover la base del stage corre el X", cx2 - cx, -40)
eq("y tambien en Y",                    cy2 - cy, -20)

-- El scroll vertical va con signo: 0xFF00 es -256.
w16(0xFFA014, 0); w16(0xFFA016, 0)
w16(0xFFF566, 0xFF00)
CO.leer_mundo(1)
local _, cy3 = CO.crudo(1)
eq("el scroll con signo mueve la Y", cy3 - cy, -256)
w16(0xFFF566, 0)

-- Y el contraste que las dos mitades existen para ver: con el clamp saturado,
-- $08 queda en el borde y el crudo se va, y por eso TIENEN que diferir.
CO.leer_mundo(1)
w16(SLOTS[1] + 0x08, 0x40)              -- saturado por abajo
CO.leer_mundo(1)
local sx4 = CO.pantalla(1)
local cx4 = CO.crudo(1)
eq("con el clamp saturado $08 queda en 0x40", sx4, 0x40)
ok("y entonces $08 NO coincide con la cuenta sin clamp", sx4 ~= cx4)
eq("la cuenta sin clamp ve el valor real", cx4, 100 + 0x80)

-- --- El teletransporte ---
-- Un frame quieto, y al siguiente un salto de 300 px de golpe.
CO.reset()
CO.leer_mundo(1)
CO.detecta_tele(1)                        -- prev = nil: solo guarda la posicion
eq("sin movimiento no hay teletransporte", CO.teles(1), 0)
eq("ni maxima de salto", CO.max_salto(1), 0)

w16(SLOTS[1] + 0x40, 100 + 300)
CO.leer_mundo(1)
capturar(function() CO.detecta_tele(1) end)
eq("un salto de 300 px ES un teletransporte", CO.teles(1), 1)
eq("y el maximo de salto lo registra", CO.max_salto(1), 300)

-- Un movimiento normal de 3 px NO lo es.
CO.reset()
armar_partida()
mundo_en(100, 80)
CO.reset()
w16(SLOTS[1] + 0x40, 100)   -- la X venia en 103 del test anterior
CO.leer_mundo(1); CO.detecta_tele(1)
w16(SLOTS[1] + 0x40, 103)
CO.leer_mundo(1); CO.detecta_tele(1)
eq("un paso de 3 px no es teletransporte", CO.teles(1), 0)
eq("pero el maximo si lo recuerda", CO.max_salto(1), 3)

-- *** LA FRACCION NO ES UN SALTO, Y ESTE ES EL TEST QUE LO DEMUESTRA ***
--
-- MEDIDO el 07-10: del mismo teletransporte, Y = 314 con fraccion 38400 en el
-- aire y Y = 320 con fraccion 0 en el piso. El script tomaba el cambio de
-- fraccion por un teletransporte y de 7 reportados **5 eran falsos**.
--
-- O sea que $42/$46 NO son la "mitad alta" de la posicion: son la parte
-- fraccionaria de un 16.16, y un cambio ahi es subpixel.
--
-- OJO con el dato: se parte de 320/0 y se llega a 314/38400, o sea un movimiento
-- REAL de -5.41 px (314 + 38400/65536 = 314.586). Un "-314" o un "38400" aqui
-- estaria probando otra cosa.
CO.reset()
armar_partida()
mundo_en(100, 320)                -- en el piso, fraccion 0
CO.reset()
CO.leer_mundo(1); CO.detecta_tele(1)

-- Caso 1: 6 px de entero y la fraccion de 0 a 38400 (0.586 px).
w16(SLOTS[1] + 0x44, 314); w16(SLOTS[1] + 0x46, 38400)
CO.leer_mundo(1)
capturar(function() CO.detecta_tele(1) end)
eq("un cambio de fraccion NO es un teletransporte", CO.teles(1), 0)
ok("el delta real es de ~5.41 px", CO.max_salto(1) > 5 and CO.max_salto(1) < 6)

-- Caso 2: el entero NO se mueve y la fraccion se da vuelta casi entera.
w16(SLOTS[1] + 0x46, 65000)
CO.leer_mundo(1)
capturar(function() CO.detecta_tele(1) end)
eq("ni siquiera con la fraccion dando la vuelta entera", CO.teles(1), 0)

-- Caso 3: la vuelta al piso. 38400 de fraccion a 0 con 6 px de entero.
w16(SLOTS[1] + 0x44, 320); w16(SLOTS[1] + 0x46, 0)
CO.leer_mundo(1)
capturar(function() CO.detecta_tele(1) end)
eq("y volver al piso tampoco lo es", CO.teles(1), 0)
ok("tres transiciones de subpixel, cero teletransportes", CO.teles(1) == 0)

-- *** Y LA FRACCION SE USA, NO SOLO SE IGNORA ***
--
-- Un movimiento de 100.92 a 101.00 px vale 0.08 px, no 1 px entero. Esta prueba
-- falla si alguien saca la fraccion de la cuenta del delta, que es el otro
-- error posible al arreglar el de arriba.
CO.reset()
armar_partida()
CO.reset()
w16(SLOTS[1] + 0x40, 100); w16(SLOTS[1] + 0x42, 60000)   -- 100.9155 px
CO.leer_mundo(1); CO.detecta_tele(1)
w16(SLOTS[1] + 0x40, 101); w16(SLOTS[1] + 0x42, 0)       -- 101.0000 px
CO.leer_mundo(1)
capturar(function() CO.detecta_tele(1) end)
ok("el delta respeta la fraccion (0.08 px, no 1 px entera)", CO.max_salto(1) < 0.5)
ok("y da el valor con signo correcto", CO.max_salto(1) > 0)

-- El maximo tiene que RECORDAR el maximo, no el ultimo delta visto. Con un
-- salto grande y despues uno chico: si guardara el ultimo, valdria 3.
CO.reset()
armar_partida()
mundo_en(100, 80)
CO.reset()
CO.leer_mundo(1); CO.detecta_tele(1)
w16(SLOTS[1] + 0x40, 100 + 250)
CO.leer_mundo(1); CO.detecta_tele(1)
eq("tras un salto de 250, el maximo es 250", CO.max_salto(1), 250)
w16(SLOTS[1] + 0x40, 100 + 250 + 2)
CO.leer_mundo(1); CO.detecta_tele(1)
eq("un salto chico DESPUES no baja el maximo", CO.max_salto(1), 250)

-- El CLAMP: $08/$0C se saturan, y el script lo avisa.
CO.reset()
armar_partida()
mundo_en(100, 80)
w16(SLOTS[1] + 0x08, 0x40)          -- borde de saturacion en X
CO.reset()
CO.leer_mundo(1); CO.detecta_tele(1)
w16(SLOTS[1] + 0x40, 900)
w16(SLOTS[1] + 0x08, 0x40)
CO.leer_mundo(1)
local _, tel = capturar(function() CO.detecta_tele(1) end)
local avisa_clamp = false
for _, s in ipairs(tel) do
  if string.find(s, "CLAMP RECORTA") then avisa_clamp = true end
end
ok("avisa que el clamp de $08 esta recortando", avisa_clamp)
eq("y el mundo si se movio de verdad", CO.teles(1), 1)
eq("y el maximo ve los 800 px de salto", CO.max_salto(1), 800)

-- *** LA CONTRAPROUEBA DEL AVISO DE CLAMP ***
--
-- El aviso decia "CLAMP RECORTA" en CADA teletransporte, y no habia ningun clamp:
-- en la corrida del 07-10 salio `$08/$0C = 432/316` contra un crudo de
-- `432/324`, con X coincidente exacto. Los 8 de la Y son el `subq.w #$8` de
-- 0x15744, que `crudo_de` no restaba.
--
-- O sea que el aviso era un SIEMPRE. Esta prueba es la que lo caza: un salto
-- grande con $08/$0C consistentes NO tiene que avisar.
CO.reset()
armar_partida()
mundo_en(100, 80)
w16(0xFFA014, 40); w16(0xFFA016, 20); w16(0xFFF566, 0)
CO.reset()
CO.leer_mundo(1); CO.detecta_tele(1)
w16(SLOTS[1] + 0x40, 100 + 300)
-- El juego recalcula $08/$0C DESPUES de mover (loc_0156F0 corre en el mismo
-- tick). Hay que simularlo a mano, y con la cuenta ESCRITA ACA, no sacada de
-- `crudo_de`: si el valor esperado viene de la misma funcion que se esta
-- probando, la prueba no puede fallar. Ya se hizo esa vez y no cazaba nada.
--
--   $08 = $40 - $A014 + $80           = 400 - 40 + 128 = 488
--   $0C = $44 - $A016 + $F566 + $20 - 8 = 80 - 20 + 0 + 32 - 8 = 84
w16(SLOTS[1] + 0x08, 400 - 40 + 128)
w16(SLOTS[1] + 0x0C, 80 - 20 + 0 + 0x20 - 8)
CO.leer_mundo(1)
local _, tel_limpio = capturar(function() CO.detecta_tele(1) end)
local aviso_equivoco = false
for _, s in ipairs(tel_limpio) do
  if string.find(s, "CLAMP RECORTA") then aviso_equivoco = true end
end
ok("un salto de 300 px SIN saturacion NO avisa clamp", not aviso_equivoco)

-- *** Y EL SALTO SE ATRIBUYE A LA TECNICA CONFIRMADA ***
--
-- Las tres variantes de Teleport comparten id de $5F y registro de 8 bytes, asi
-- que la tabla no las separa: lo unico que las distingue es donde caen. Por eso
-- el salto se correlaciona con la ultima tecnica que gasto maná.
CO.reset()
armar_partida()
mundo_en(100, 80)
CO.reset()
CO.leer_mundo(1); CO.detecta_tele(1)
-- Sin tecnica previa: lo dice, en vez de atribuirlo a cualquiera.
w16(SLOTS[1] + 0x40, 100 + 126)
CO.leer_mundo(1)
local _, sin = capturar(function() CO.detecta_tele(1) end)
local avisa_huerfano = false
for _, s in ipairs(sin) do
  if string.find(s, "sin tecnica confirmada") then avisa_huerfano = true end
end
ok("un salto sin tecnica previa lo declara, no lo inventa", avisa_huerfano)

CO.reset()
armar_partida()
mundo_en(100, 80)
CO.reset()
CO.fingir_tec("^A", 0)             -- hay una tecnica previa a la que atribuirlo
CO.leer_mundo(1); CO.detecta_tele(1)   -- prev = nil: solo guarda la posicion
w16(SLOTS[1] + 0x40, 100 + 126)
CO.leer_mundo(1)
local _, con = capturar(function() CO.detecta_tele(1) end)
local atribuyo = false
for _, s in ipairs(con) do
  if string.find(s, "de la tecnica") then atribuyo = true end
end
ok("con tecnica previa nombra a cual pertenece el salto", atribuyo)
ok("y el reset limpia la ultima tecnica", (function()
  CO.reset()
  return CO.ultima_tec() == nil
end)())

--------------------------------------------------------------------------------
-- A PARTIR DE ACA EL ANUNCIO ESTA ATRAPADO POR EL GASTO DE MANA.
--
-- Los tests viejos ponian $5F a mano y esperaban un [MOV]. Con la puerta del
-- maná eso ya NO anuncia: sin pulsada no hay sospecha, y sin gasto no hay
-- confirmacion. Estos tests hacen las DOS cosas.
local MA = T.mana
local CMD_A = MA.cmd_a
local CMD_B = MA.cmd_b

eq("el maná se lee de $B8, NO de $BC (la barra)", MA.off_mp(), 0xB8)
eq("el tope de maná es 223", MA.mp_max(), 223)
ok("la ventana de espera es de varios frames", MA.ventana() >= 3)

-- Estado limpio para cada escenario.
local function escena(id_tec, man)
  M.nuevo_lote()
  CO.reset()
  armar_partida()
  montar_tablas()
  for i = 1, 4 do poner_punteros(i) end
  for i = 2, 4 do w16(SLOTS[i] + 0x78, 0) end
  w8(SLOTS[1] + O.estado, id_tec)
  w8(SLOTS[1] + O.frame, 0)
  w8(SLOTS[1] + 0x5A, 8)
  w16(SLOTS[1] + 0xB8, man)
end

local function pulsar(boton, dir)
  for _, k in pairs(dir or {}) do teclas[k] = true end
  teclas[boton] = true
  frame()
  teclas[boton] = false
  for k in pairs(dir or {}) do teclas[k] = false end
end

-- 1. Pulsada CON gasto: se anuncia.
escena(0, 200)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 195)          -- gasto de 5
local _, mv = capturar(function() frame() end)
eq("pulsada + gasto = 1 tecnica", M.lineas(), 1)

local hay_mov, hay_verif, hay_ctx = false, false, false
for _, s in ipairs(mv) do
  if string.find(s, "%[MOV") then hay_mov = true end
  if string.find(s, "lectura VERIFICADA") then hay_verif = true end
  if string.find(s, "CONTEXTO") then hay_ctx = true end
end
ok("sale la linea [MOV]", hay_mov)
ok("la lectura se autocomprueba contra $5A", hay_verif)
ok("y el CONTEXTO sale en la primera, para saber de que tabla es", hay_ctx)

local _, r1 = capturar(function() M.volcar() end)
local con_cmd = false
for _, s in ipairs(r1) do
  if string.find(s, "mana %-5") then con_cmd = true end
end
ok("el volcado muestra el comando y el gasto", con_cmd)

-- 2. Pulsada SIN gasto: NO se anuncia. ESTE es el comportamiento nuevo.
escena(0, 200)
pulsar(CMD_A, {})
capturar(function() for _ = 1, MA.ventana() + 3 do frame() end end)
eq("pulsada SIN gasto no anuncia nada (una basica)", M.lineas(), 0)
eq("y la sospecha se descarta sola", MA.pendiente(), nil)

-- 3. Gasto SIN pulsada: NO se anuncia. El maná sube por combo y por
--    regeneracion, y eso no es una tecnica.
escena(0, 200)
w16(SLOTS[1] + 0xB8, 180)          -- baja sin que haya pulsado nada
capturar(function() frame() end)
eq("gasto sin pulsada no anuncia nada", M.lineas(), 0)


-- 3b. Con una sospecha VIVA pero el maná SUBIENDO: la subida es por combo o por
-- regeneracion, y NO es una tecnica. Con "<" no confirma; con "~=" confirmaria
-- cualquier cambio, que es justo la mutacion que esta prueba tiene que cazar.
escena(0, 200)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 205)          -- el maná SUBE, no baja
capturar(function() for _ = 1, MA.ventana() + 2 do frame() end end)
eq("el maná que SUBE no confirma la sospecha", M.lineas(), 0)
eq("y la sospecha se descarta sola", MA.pendiente(), nil)
-- 4. El comando incluye la CRUCETA, no solo el boton.
escena(0, 200)
pulsar(CMD_A, { "P1 Up" })
w16(SLOTS[1] + 0xB8, 190)
local _, mv2 = capturar(function() frame() end)
local con_dir = false
for _, s in ipairs(mv2) do
  if string.find(s, "%^A") then con_dir = true end
end
ok("el comando trae la direccion de la cruceta", con_dir)

-- 5. Cada variante que GASTA maná se anuncia, aunque comparta el id de $5F.
--
-- YA NO hay guardia de repeticion. En la primera prueba real del usuario
-- (Teleport) tres variantes con el MISMO $5F salian solo 2, porque el guardia
-- casteaba por (slot, id) y las variantes comparten id: el guardia tapaba
-- justo el dato que se buscaba. El gate de maná ya evita el spam.
escena(0, 200)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 195)
capturar(function() frame() end)
eq("primera vez cuenta 1", M.lineas(), 1)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 190)
capturar(function() frame() end)
eq("cada variante que gasta maná se anuncia aunque comparta id", M.lineas(), 2)

-- escena() llama a nuevo_lote, que pone el contador en 0: despues de un solo
escena(1, 200)
pulsar(CMD_B, {})
w16(SLOTS[1] + 0x5A, 6)
w16(SLOTS[1] + 0xB8, 190)
capturar(function() frame() end)
-- escena() llama a nuevo_lote, que pone el contador en 0: despues de un solo

local _, mv3 = capturar(function() M.volcar() end)
local tiene_tabla = false
for _, s in ipairs(mv3) do
  if string.find(s, "CONFIRMADAS POR GASTO") then tiene_tabla = true end
end
ok("el volcado imprime la tabla", tiene_tabla)

-- --------------------------------------------------------------------------------
-- 6b. EL SALTO SE ATRIBUYE A LA TECNICA, Y EL VOLCADO LLEVA LA ZONA
--
-- MEDIDO el 07-10 con Teleport A/B/C: las tres variantes salen con el MISMO id de
-- $5F ($08), el MISMO registro ($0CFBFA) y los MISMOS 8 bytes. La tabla no las
-- separa. Lo unico que las distingue es DONDE cae el personaje, asi que el
-- volcado tiene que llevar el destino: sin el, tres variantes son una fila.
--
-- Esta es la prueba de INTEGRACION: la tecnica entra por la puerta de maná de
-- verdad (pulsada + gasto), y despues el salto se le atribuye.
-- --------------------------------------------------------------------------------
escena(0, 200)
-- Fijar la posicion ANTES de la tecnica: si se fija despues, el propio
-- `detectar_tele` ve el 0 -> 100 como un salto y se adjudica el teletransporte
-- de la tecnica, con un frame de atraso.
w16(SLOTS[1] + 0x40, 100); w16(SLOTS[1] + 0x44, 80)
CO.leer_mundo(1); CO.detecta_tele(1)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 184)          -- gasto de 16
capturar(function() frame() end)
eq("la tecnica entra por la puerta de maná", M.lineas(), 1)
ok("y queda registrada como la ultima", CO.ultima_tec() ~= nil)

-- Ahora el salto. Los 39 frames son de la medicion en el juego del 07-10; aca
-- el numero no importa, lo que se prueba es que el script lo REPORTE.
for _ = 1, 39 do frame() end
w16(SLOTS[1] + 0x40, 100 + 126)
CO.leer_mundo(1)
local _, tel2 = capturar(function() CO.detecta_tele(1) end)
local nombro, Delay_ok = false, false
for _, s in ipairs(tel2) do
  if string.find(s, "de la tecnica") then nombro = true end
  if string.find(s, "frame%(s%) antes") then Delay_ok = true end
end
ok("el salto nombra la tecnica a la que pertenece", nombro)
ok("y dice cuantos frames pasaron desde la pulsada", Delay_ok)

local _, mv4 = capturar(function() M.volcar() end)
local con_destino = false
for _, s in ipairs(mv4) do
  if string.find(s, "destino X=%d") then con_destino = true end
end
ok("el volcado lleva la zona de destino de la variante", con_destino)

-- Sin salto, la fila lo dice en vez de callar: un "sin salto atribuido" es
-- informacion, porque significa que esa variante todavia no se midio.
escena(0, 200)
pulsar(CMD_B, {})
w16(SLOTS[1] + 0xB8, 180)
capturar(function() frame() end)
local _, mv5 = capturar(function() M.volcar() end)
local dice_sin = false
for _, s in ipairs(mv5) do
  if string.find(s, "sin salto atribuido") then dice_sin = true end
end
ok("una variante sin teletransporte medido lo declara", dice_sin)

-- --------------------------------------------------------------------------------
-- 6c. SIN LECTURA VERIFICADA NO SE IMPRIMEN DANO/STUN/EMPUJE
--
-- En la corrida del 07-10 el script imprimia "dano=$0B stun=$87 empuje=$1D" un
-- renglon despues de decir que la lectura no era de fiar. Son numeros de un
-- lugar que el propio script habia descartado: el que lee la consola se lleva
-- el numero y no el aviso.
--
-- La autoprueba es byte(+0) == $5A vivo (0x1EB5A). Se rompe poniendo un $5A que
-- no sea la duracion del registro.
-- Con un $5A que NO sea la duracion del registro.
--
-- OJO: con `w16`, no con `w8`. 99 = $0063 en big-endian, asi que `w16($5A, 99)`
-- deja $5A = 0 y $5B = 99: se esta probando otra cosa y el aviso sale por el
-- motivo equivocado. Este banco lo comprobo.
escena(0, 200)
w8(SLOTS[1] + 0x5A, 99)           -- el registro dice 8: no coincide
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 190)
local _, mv6 = capturar(function() frame() end)
local aviso, falso_golpe = false, false
for _, s in ipairs(mv6) do
  if string.find(s, "La lectura NO es de fiar") then aviso = true end
  -- Busqueda PLANA (el 4to argumento): con patron, `%s` es la clase de los
  -- espacios y "stun=%s" no matchea "stun=$2A". Sale un falso negativo.
  if string.find(s, "stun=", 1, true) or string.find(s, "empuje=", 1, true) then
    falso_golpe = true
  end
end
ok("con la lectura rota avisa que no es de fiar", aviso)
ok("y NO imprime dano/stun/empuje de todos modos", not falso_golpe)

-- Con la lectura buena, si los imprime. El control de la prueba anterior.
escena(0, 200)
pulsar(CMD_A, {})
w16(SLOTS[1] + 0xB8, 190)
local _, mv7 = capturar(function() frame() end)
local verificada, con_golpe = false, false
for _, s in ipairs(mv7) do
  if string.find(s, "lectura VERIFICADA") then verificada = true end
  if string.find(s, "stun=", 1, true) then con_golpe = true end
end
ok("con la lectura verificada la autoprueba lo dice", verificada)
ok("y ahi si imprime el registro de golpe", con_golpe)

-- --------------------------------------------------------------------------------
-- 6d. EL LATIDO NO SE IMPREME EN CADA FRAME
--
-- Las dos lineas de diagnostico ("max salto" y "maná P1") estaban FUERA del
-- `if g_frame % LATIDO`, y solo el "[latido]" de arriba estaba adentro. O sea 2
-- lineas por frame: la corrida del 07-10 produjo mas de mil lineas de consola.
--
-- Y no es solo ruido: hunde la consola, baja el framerate, y una medicion con el
-- framerate caido no sirve. De ahi que el sintoma fuera "el maná sube +1 cada
-- dos lineas" cuando en realidad era +1 por frame.
--
-- La prueba mira una ventana de 121 frames: como LATIDO > 121, en esa ventana no
-- puede caer mas de un multiplo de LATIDO. Con el bug eran 121.
--
-- Por eso el primer requisito es `latido > 121`: si alguien baja LATIDO a 100,
-- la ventana ya no vale y la prueba pasa por la razon equivocada.
ok("el latido tiene que ser mas largo que la ventana de la prueba",
   CO.latido() > 121)
local _, ventana = capturar(function()
  for _ = 1, 121 do frame() end
end)
local n_lat, n_max, n_mana = 0, 0, 0
for _, s in ipairs(ventana) do
  if string.find(s, "%[latido%]") then n_lat = n_lat + 1 end
  if string.find(s, "max salto=") then n_max = n_max + 1 end
  if string.find(s, "maná P1 =", 1, true) then n_mana = n_mana + 1 end
end
ok("en 121 frames el latido sale a lo sumo una vez", n_lat <= 1)
ok("y 'max salto' tambien, no una por frame", n_max <= 1)
ok("y 'maná P1' tambien", n_mana <= 1)

-- --------------------------------------------------------------------------------
-- 6f. LOS CAMBIOS DE $5F SE AVISAN AUN SIN GASTAR MANA
--
-- Es lo que permite contestar si `$0D` es "el estado de agachado" o "el primer
-- paso del comando abajo-arriba" (07-10). El rastreador de tecnicas solo imprime
-- cuando el maná BAJA, asi que durante una secuencia sin gastar nada no dice
-- NADA: agacharse 3 segundos no producia ni una linea.
--
-- Con esto, cada CAMBIO de `$5F` sale solo, y se puede ver cuanto dura un estado.
-- --------------------------------------------------------------------------------
CO.reset()
armar_partida()
CO.reset()
w8(SLOTS[1] + O.estado, 0x01)      -- parado
capturar(function() frame() end)   -- asienta el "anterior"
w8(SLOTS[1] + O.estado, 0x0D)
local _, cam1 = capturar(function() frame() end)
local salio_cambio = false
for _, s in ipairs(cam1) do
  if string.find(s, "[$5F]", 1, true) then salio_cambio = true end
  if string.find(s, "$01 -> $0D", 1, true) then salio_cambio = true end
end
ok("un cambio de $5F se avisa sin que se gaste maná", salio_cambio)

-- Y uno que NO cambia no dice nada: si avisara siempre, serian 60 lineas por
-- segundo, que es justo la trampa del latido.
w8(SLOTS[1] + O.estado, 0x0D)
local _, quieto = capturar(function()
  for _ = 1, 30 do frame() end
end)
local lineas_5f = 0
for _, s in ipairs(quieto) do
  if string.find(s, "[$5F]", 1, true) then lineas_5f = lineas_5f + 1 end
end
eq("y 30 frames sin cambio NO producen ni una linea", lineas_5f, 0)

-- El primer frame no avisa: no hay "anterior" con cual comparar.
CO.reset()
armar_partida()
CO.reset()
w8(SLOTS[1] + O.estado, 0x55)
local _, primera = capturar(function() frame() end)
local hablo_al_go = false
for _, s in ipairs(primera) do
  if string.find(s, "[$5F]", 1, true) then hablo_al_go = true end
end
ok("el primer frame no avisa, porque no hay anterior con que comparar", not hablo_al_go)

-- --------------------------------------------------------------------------------
-- 6e. EL HISTORIAL DE $5F
--
-- Es lo que decide si A, B y C del Teleport son UN id o TRES. El 07-10 salieron
-- las tres con `$5F = $08`, y los ids 6/7/8 del contexto 6 comparten los bytes
-- +2..+5 de su registro (`08 94 7C 00`): la firma de tres variantes de una misma
-- tecnica. Con el `$5F` del frame de la pulsada NO se puede distinguir, asi que
-- se imprime la secuencia de los 8 frames.
-- --------------------------------------------------------------------------------
CO.reset()
armar_partida()
CO.reset()
-- 8 frames, que es lo que dura el historial: con menos quedan huecos y la
-- prueba de "sin ??" estaria probando otra cosa.
for k = 0, 7 do
  w8(SLOTS[1] + O.estado, 0x40 + k)
  frame()
end
local seq = CO.hist5f(1)
ok("el historial recoge los frames que pasan",
   string.find(seq, "$47", 1, true) ~= nil)
ok("y no deja huecos despues de 8 frames",
   string.find(seq, "??", 1, true) == nil)
eq("el frame mas reciente va primero", string.sub(seq, 1, 3), "$47")

-- Y el anuncio lo imprime.
escena(0, 200)
w8(SLOTS[1] + O.estado, 6)      -- el estado "anterior", como en el juego
pulsar(CMD_A, {})
w8(SLOTS[1] + O.estado, 7)      -- el estado nuevo, con el move ya arrancado
w16(SLOTS[1] + 0xB8, 190)
local _, mv8 = capturar(function() frame() end)
local vivo, sec = false, false
for _, s in ipairs(mv8) do
  if string.find(s, "$5F vivo=", 1, true) then vivo = true end
  if string.find(s, "secuencia:", 1, true) then sec = true end
end
ok("el anuncio imprime el $5F vivo del frame de la confirmacion", vivo)
ok("y la secuencia de $5F hacia atras", sec)
-- Y el que se anuncia es el de la pulsada, no el vivo: por eso hacen falta los
-- dos. La duda de "que id es" viene de ahi.
local uso_el_de_pulsada = false
for _, s in ipairs(mv8) do
  if string.find(s, "el de la pulsada era $06", 1, true) then uso_el_de_pulsada = true end
end
ok("y aclara que el id anunciado es el de la pulsada, no el vivo", uso_el_de_pulsada)

-- 17. $6E Y LOS HIJOS
--
-- $6E es una etiqueta de pertenencia y el juego se la copia a los hijos
-- (move.b $6e(a5), $6e(a1) en 0x1A46C y 9 mas). Eso responde la pregunta de las
-- manos: si el hijo lleva el $6E del dueno, el juego lo trata como prolongacion.
--
-- *** OJO: leer $6E en $300 + $6E es HIPOTESIS, no esta verificado. El script
-- imprime el handler (que SI es verificado, 0x1C04A) y el byte por separado, y
-- no decide. ***
--------------------------------------------------------------------------------

eq("el $6E del objeto se lee en $300 + $6E", COO.obj6e, 0x6E)

local function w32(a, v)
  w8(a,     band(rshift(v, 24), 0xFF)); w8(a + 1, band(rshift(v, 16), 0xFF))
  w8(a + 2, band(rshift(v, 8), 0xFF));  w8(a + 3, band(v, 0xFF))
end

-- En paz no dice nada: dos frames sin objeto no imprimen ni una linea.
armar_partida()
-- El reset va DESPUES: armar_partida corre 77 frames que ya llenan g_obj, y con
CO.reset()   -- g_obj vacio: asi se ejercita el guardia y no el chequeo de igualdad
local _, primera = capturar(function() CO.detectar_hijos(1) end)
eq("la PRIMERA llamada, con g_obj vacio, no imprime nada", #primera, 0)
local _, en_paz = capturar(function() CO.detectar_hijos(1) end)
eq("sin objeto no imprime nada", #en_paz, 0)

-- Ahora aparece un handler, con el $6E del dueno.
w32(SLOTS[1] + 0x300, 0x15094)      -- el handler que escribe 0x1C058
w16(SLOTS[1] + 0x304, 0x0100)       -- la vida que escribe 0x1C060
w8(SLOTS[1] + 0x300 + 0x6E, 0x01)   -- $6E = el del dueno P1
local _, hj = capturar(function() CO.detectar_hijos(1) end)
local salio = false
for _, s in ipairs(hj) do
  if string.find(s, "handler=$00015094") then salio = true end
end
ok("anuncia el handler del objeto", salio)

local coincide = false
for _, s in ipairs(hj) do
  if string.find(s, "CONSISTENTE") then coincide = true end
end
ok("avisa que el $6E coincide con el de un jugador", coincide)

-- Y si NO coincide con nadie, tambien es informacion: lo dice igual.
CO.reset()
armar_partida()
w32(SLOTS[1] + 0x300, 0x15094)
w8(SLOTS[1] + 0x300 + 0x6E, 0x77)   -- un $6E que no es de nadie
local _, hj2 = capturar(function() CO.detectar_hijos(1) end)
local sin_coincidir = false
for _, s in ipairs(hj2) do
  if string.find(s, "$6E=$77") then sin_coincidir = true end
end
ok("tambien anuncia cuando el $6E NO coincide con nadie", sin_coincidir)

--------------------------------------------------------------------------------
-- 18. El script es PASIVO: ni una escritura a la memoria del juego
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 15. El script es PASIVO: ni una escritura a la memoria del juego
--------------------------------------------------------------------------------
local Written = 0
_G.memory.writebyte = function() Written = Written + 1 end
_G.memory.writeword = function() Written = Written + 1 end
_G.memory.writedword = function() Written = Written + 1 end
_G.joypad = { set = function() Written = Written + 1 end,
              get = function() return {} end }
armar_partida()
capturar(function()
  w8(SLOTS[1] + O.frame, C.ult_frame)
  ejecutar_ult(1)
  for _ = 1, 30 do frame() end
end)
eq("cero escrituras a la memoria del juego ni al mando", Written, 0)

-- El auditor corre AL FINAL, porque necesita haber visto TODA la corrida. Y sus
-- aserciones van ANTES del resumen: si fueran despues, el "0 fallos" ya salio
-- impreso y un crash del emulador quedaria con el banco en verde.
ok("el auditor de string.format vio llamadas de verdad", N_AUDITADAS > 100)
ok("ningun %d/%i/%X/%x/%f recibio un string en toda la corrida",
   FORMAT_MALO == nil)
if FORMAT_MALO then
  print_real("  FALLA: " .. FORMAT_MALO)
  fallos = fallos + 1
end

print_real("")
print_real(string.format("=== %d pruebas, %d fallos ===", pruebas, fallos))

os.exit(fallos > 0 and 1 or 0)
