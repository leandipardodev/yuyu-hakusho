-- yuyu_anim.lua : encuentra la variable de ESTADO/ANIMACION del personaje.
-- Estrategia: captura el player struct de P1 (0xFF8000+) cada frame durante
-- un tramo de combate y registra que offsets cambian mucho (= animacion/sprite).
-- El estado de golpe hace cambiar campos como el puntero de animacion, el
-- indice de frame, o un "action state" byte.
-- Como la demo reinicia, capturamos un stretch largo y agrupamos por "cuantos
-- offsets distintos aparecen" — el estado de animacion varia mucho.

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_anim.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local STRUCT = 0xFF8000   -- base player struct P1
local SIZE = 0x500        -- tamano a monitorear

local function rd(a)
  local ok,v = pcall(memory.read_u16_be, a, "M68K BUS")
  if ok and type(v)=="number" then return v end
  return 0
end

-- Para cada offset, guardar el set de valores distintos vistos
local hist = {}
local nframes = 0

-- correr 12000 frames, muestrear cada 2 frames en un tramo
for fr = 1, 12000 do
  emu.frameadvance()
  if fr % 2 == 0 then
    nframes = nframes + 1
    local base = STRUCT
    for off = 0, SIZE-2, 2 do
      local v = rd(base+off)
      if hist[off] == nil then hist[off] = {} end
      local h = hist[off]
      if h[v] == nil then h[v] = 1 else h[v] = h[v] + 1 end
    end
  end
end

log("=== offsets con MAS variacion (candidatos a estado/animacion) ===")
log("frames muestreados: " .. nframes)
local cand = {}
for off, h in pairs(hist) do
  local nvals = 0
  for v, c in pairs(h) do nvals = nvals + 1 end
  if nvals >= 8 and nvals <= 400 then   -- varia lo suficiente pero no es RAM de video
    table.insert(cand, {off=off, nvals=nvals})
  end
end
table.sort(cand, function(a,b) return a.nvals > b.nvals end)

for i=1,math.min(#cand, 40) do
  local c = cand[i]
  -- mostrar algunos valores
  local h = hist[c.off]
  local vals = {}
  local n=0
  for v in pairs(h) do n=n+1; if n<=10 then table.insert(vals, string.format("0x%X",v)) end end
  log(string.format("+0x%03X (addr FF%04X): %3d valores distintos   ej: %s",
      c.off, 0x8000+c.off, c.nvals, table.concat(vals, ",")))
end

f:close()
client.exit()