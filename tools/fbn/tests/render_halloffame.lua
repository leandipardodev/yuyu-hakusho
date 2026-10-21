-- Renderiza yuyu_halloffame.lua a un PPM para revisarlo a ojo.
-- Muestra el glifo de estrella como lo veria una fuente de ancho fijo: cada
-- caracter se pinta como su celda, con sombra, para comprobar la composicion.
--     luajit render_halloffame.lua
local SW, SH = 320, 224

local px = {}
local function limpiar()
  for y = 0, SH - 1 do
    px[y] = {}
    for x = 0, SW - 1 do px[y][x] = { 26, 30, 58 } end   -- azulèˆžå° del juego
  end
end
limpiar()

local function put(x, y, c)
  x, y = math.floor(x), math.floor(y)
  if x < 0 or y < 0 or x >= SW or y >= SH then return end
  local r = math.floor((c / 65536) % 256)
  local g = math.floor((c / 256) % 256)
  local b = c % 256
  if r + g + b == 0 then return end
  px[y][x] = { r, g, b }
end

local function ent(v)
  if v ~= math.floor(v) then return nil end
  return v
end

-- Cada gui.text pinta una celda de 6x8 con el glifo marcado, para que se vea
-- el texto Y el caracter de estrella sin depender de una fuente real.
local CW, CH = 6, 8
_G.emu = {
  screenwidth  = function() return SW end,
  screenheight = function() return SH end,
  romname      = function() return "md_yuyumte" end,
  registerafter = function(f) _G.frame_cb = f end,
}
_G.joypad = { get = function() return _G.pressed end }
_G.gui = {
  box = function() end,
  drawline = function() end,
  text = function(x, y, s, col)
    x, y = ent(x), ent(y)
    if not (x and y) then return end
    -- glifo: la celda entera del caracter, con sombra dura abajo a la derecha
    for i = 0, CW - 1 do
      for j = 0, CH - 1 do
        if (i + j) % 2 == 0 then put(x + i, y + j, col) end
      end
    end
    for i = 0, CW - 1 do
      for j = 0, CH - 1 do
        if (i + j) % 2 == 1 then put(x + 1 + i, y + 1 + j, 0) end
      end
    end
  end,
}

math.randomseed(999)
dofile("tools/fightcade/yuyu_halloffame.lua")

_G.pressed = { ["P1 Start"] = true }
-- 120 frames para abrir el menu, 100 mas para repartir el confeti
for i = 1, 220 do
  limpiar()
  _G.frame_cb()
end

local f = io.open("hof_lua.ppm", "wb")
f:write(string.format("P6\n%d %d\n255\n", SW, SH))
for y = 0, SH - 1 do
  for x = 0, SW - 1 do
    local c = px[y][x]
    f:write(string.char(c[1], c[2], c[3]))
  end
end
f:close()
print("escrito hof_lua.ppm")
os.exit(0)
