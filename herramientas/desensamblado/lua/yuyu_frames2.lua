-- yuyu_frames2.lua : mide la DURACION del estado de golpe.
-- Idea: cuando un jugador golpea, su variable de "estado de animacion de golpe"
-- cambia (frames de startup/active/recovery). Monitoreamos:
--   - HP del rival (cae al impacto)
--   - una variable de estado/timer del atacante
-- Pero sin saber cual address es el "state" de cada jugador, usamos un truco:
-- el intervalo entre HP-drope y el siguiente HP-drop del mismo atacante = duracion
-- aproximada del recovery (el atacante queda en recovery X frames antes de
-- poder volver a golpear). Y el gap entre dos golpes seguidos del mismo
-- atacante nos da startup+active+recovery.
-- Tambien rastreamos la PRIMERA caida de HP de cada round (el move mas limpio).

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_frames2.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local HP1, HP2 = 0xFF84B8, 0xFF88B8
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end

log("=== duraciones de golpe (demo) ===")

-- Detectar eventos: (frame, target, dmg) cuando HP baja Y se mantiene bajo
-- (descartar el reset instantaneo del demo: HP baja y vuelve a 223 en 1 frame)
local events = {}
local prev1, prev2 = rd(HP1), rd(HP2)
local lastframe = 0

for fr = 1, 60000 do
  emu.frameadvance()
  local h1, h2 = rd(HP1), rd(HP2)
  -- detecta round activo: alguno bajo 223
  local active = (h1 < 0xDF) or (h2 < 0xDF)
  if active then
    if h2 < prev2 then
      events[#events+1] = {fr=fr, tgt=2, dmg=prev2-h2, newh=h2}
    elseif h1 < prev1 then
      events[#events+1] = {fr=fr, tgt=1, dmg=prev1-h1, newh=h1}
    end
  end
  prev1, prev2 = h1, h2
  if fr % 10000 == 0 then
    log("f" .. fr .. " eventos=" .. #events)
  end
  if #events >= 600 then break end
end

log("=== eventos totales: " .. #events .. " ===")

-- Analisis: agrupar eventos en "rounds" (HP se resetea a 223 = nuevo round).
-- Dentro de un round, medir gaps entre eventos del mismo objetivo (recovery)
-- y gaps entre eventos alternados (startup+recovery).
local round = 0
local last_newhp = {223, 223}
local prev_ev = nil
log("idx  frame   tgt  dmg  hp_desp  gap_mismo_tgt  gap_alterno")
local n = 0
for _, e in ipairs(events) do
  n = n + 1
  -- nuevo round si hp reseteo
  local gap_same = "-"
  local gap_alt = "-"
  if prev_ev then
    if prev_ev.tgt == e.tgt then gap_same = e.fr - prev_ev.fr
    else gap_alt = e.fr - prev_ev.fr end
  end
  log(string.format("%3d  %6d  P%d  %3d  %3d    %s    %s",
    n, e.fr, e.tgt, e.dmg, e.newh, tostring(gap_same), tostring(gap_alt)))
  prev_ev = e
  if n >= 600 then break end
end

f:close()
client.exit()