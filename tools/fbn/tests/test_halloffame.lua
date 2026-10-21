-- Banco de pruebas de yuyu_halloffame.lua con la API de FBNeo simulada.
-- No se dibuja nada: se cuentan las llamadas y se verifican los datos.
--     luajit test_halloffame.lua
--
-- Modela pulsaciones reales: mantener START N frames y soltarlo.

-- FBNeo lee 0xRRGGBBAA (byte alto = ROJO, byte bajo = ALFA), no 0xAARRGGBB.
-- Los colores se comparan por igualdad exacta contra los que dibuja el script,
-- asi que el test tiene que construirlos con la misma regla o no cuenta nada.
local function color(r, g, b, a)
  return r * 16777216 + g * 65536 + b * 256 + a
end

local SW, SH = 320, 224

local calls = {}
local frame_cb = nil
local pressed = {}

_G.emu = {
  screenwidth  = function() return SW end,
  screenheight = function() return SH end,
  romname      = function() return "md_yuyumte" end,
  registerafter = function(f) frame_cb = f end,
}
_G.joypad = { get = function() return pressed end }
_G.gui = {
  box = function(l, t, r, b, fill, line)
    calls[#calls+1] = { op = "box", x1 = l, y1 = t, x2 = r, y2 = b, fill = fill, line = line }
  end,
  text = function(x, y, s, col)
    calls[#calls+1] = { op = "text", x = x, y = y, s = s, col = col }
  end,
  drawline = function(x1, y1, x2, y2, col)
    calls[#calls+1] = { op = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, col = col }
  end,
}

math.randomseed(12345)

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

-- Frame suelto.
local function frame()
  calls = {}
  frame_cb()
end
-- Mantener START durante n frames.
local function mantener(n)
  pressed = { ["P1 Start"] = true }
  for i = 1, n do frame() end
end
-- Soltar START un frame. NECESARIO entre fases: si no, hold sigue sumando y
-- una "pulsacion corta" parece larga.
local function soltar()
  pressed = {}
  frame()
end
-- Mantener n frames y soltar.
local function pulsar(n)
  mantener(n)
  soltar()
end
-- Contar el frame que se acaba de dibujar.
--
-- El relleno de la estrella va en un degradado, asi que no se puede contar por
-- un color fijo. Se cuenta el TOTAL de lineas y se restan las que si son
-- conocidas: las 60 aristas del contorno y la linea separadora del titulo.
local function escanear()
  local t, bordes, lineas, panel = {}, 0, 0, false
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "text" then
      t[c.s] = (t[c.s] or 0) + 1
    elseif c.op == "line" then
      lineas = lineas + 1
      if c.col == color(0x8A, 0x52, 0x00, 0xFF) then bordes = bordes + 1 end
    elseif c.op == "box" and c.fill == color(0x0F, 0x0D, 0x1F, 0xF0) then
      panel = true
    end
  end
  return t, bordes, lineas - bordes - 1, panel
end

print("=== autotest de yuyu_halloffame.lua ===")
dofile("tools/fightcade/yuyu_halloffame.lua")
ok("registro su callback de frame", frame_cb ~= nil)

--------------------------------------------------------------------------------
-- 1. Pulsacion CORTA no abre el menu (hay que mantener 2 s)
--------------------------------------------------------------------------------
pulsar(30)                       -- medio segundo
local t = escanear()
ok("pulsacion corta NO abre el menu", (t["HALL OF FAME"] or 0) == 0)

--------------------------------------------------------------------------------
-- 2. Mantener 2 s ABRE el menu
--------------------------------------------------------------------------------
mantener(120)
t = escanear()
ok("mantener 2 s abre el menu", (t["HALL OF FAME"] or 0) >= 1)
for _, n in ipairs({"Adolin","Kuusa","Nomercy22","N#ga","Akara1996"}) do
  ok("nombre " .. n .. " dibujado", (t[n] or 0) >= 1)
end
ok("pie de texto dibujado", (t["HieiFM y Cacenariel sigan intentando"] or 0) >= 1)
local _, bordes, relleno, panel = escanear()
ok("panel dibujado", panel)
-- 6 estrellas x 10 aristas de contorno = 60 lineas de contorno
eq("6 estrellas x 10 aristas de contorno = 60", 60, bordes)
-- Que sea SOLIDA no se comprueba contando lineas: la version vieja hacia 10
-- radios por estrella y esta hace ~21, muy parecido en numero pero opuesto en
-- aspecto. Lo que las diferencia es el ANCHO de las lineas horizontales: un
-- radio es estrecho de punta a centro, un relleno de verdad cruza la estrella
-- entera. Si hay lineas anchas, hay relleno macizo.
local anchas = 0
for i = 1, #calls do
  local c = calls[i]
  if c.op == "line" and c.y1 == c.y2 and math.abs(c.x2 - c.x1) >= 8 then
    anchas = anchas + 1
  end
end
ok("relleno macizo: hay lineas horizontales anchas (" .. anchas .. ")", anchas >= 30)

--------------------------------------------------------------------------------
-- 3. Pulsar UNA VEZ lo cierra  <-- el bug que se reporto
--------------------------------------------------------------------------------
soltar()            -- el menu abierto con START mantiene ya no lo tiene
pulsar(10)
t = escanear()
ok("una pulsacion cierra el menu", (t["HALL OF FAME"] or 0) == 0)
-- y sigue cerrado
soltar()
mantener(10)
t = escanear()
ok("el menu no se reabre solo", (t["HALL OF FAME"] or 0) == 0)
soltar()

--------------------------------------------------------------------------------
-- 4. Mantener 3 s PRENDE el confeti
--
-- Mantener 3 s pasa antes por los 2 s, asi que TAMBIEN abre el menu. Es a
-- proposito: es la forma de dejar el confeti sonando. Por eso para comprobar
-- el confeti con el menu cerrado hay que cerrarlo despues.
--------------------------------------------------------------------------------
pulsar(180)
frame()
local function contar_confeti()
  local n = 0
  for i = 1, #calls do
    local c = calls[i]
    if c.op == "box" and (c.x2 - c.x1) <= 5 and (c.y2 - c.y1) <= 6 then n = n + 1 end
  end
  return n
end
ok("mantener 3 s prende el confeti (" .. contar_confeti() .. ")", contar_confeti() > 0)

--------------------------------------------------------------------------------
-- 5. El confeti SIGUE con el menu cerrado  <-- pedido explicito
--------------------------------------------------------------------------------
soltar()
pulsar(10)                       -- cerrar el menu
t = escanear()
ok("con el menu cerrado no se dibuja el panel", (t["HALL OF FAME"] or 0) == 0)
ok("pero el confeti sigue cayendo (" .. contar_confeti() .. ")", contar_confeti() > 0)
soltar()

--------------------------------------------------------------------------------
-- 6. Mantener 3 s OTRA VEZ apaga el confeti
--------------------------------------------------------------------------------
pulsar(180)
frame()
eq("mantener 3 s de nuevo apaga el confeti", 0, contar_confeti())

--------------------------------------------------------------------------------
-- 7. El confeti no se acumula ni se agota
--------------------------------------------------------------------------------
pulsar(180)
local maxn, mins = 0, 999
for f = 1, 2000 do
  frame()
  local n = contar_confeti()
  if n > maxn then maxn = n end
  if n < mins then mins = n end
end
eq("el confeti nunca se acumula (max 70)", 70, maxn)
ok("siempre queda confeti en pantalla (min " .. mins .. ")", mins > 0)

print("")
print(string.format("=== %d pruebas, %d fallos ===", pruebas, fallos))
os.exit(fallos > 0 and 1 or 0)
