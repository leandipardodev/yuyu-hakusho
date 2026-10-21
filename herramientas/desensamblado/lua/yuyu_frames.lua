-- yuyu_frames.lua : mide timings de golpe durante la demo.
-- Detecta cuando el HP de un jugador cambia (impacto) y mide cuantos frames
-- el atacante permanece en estado de golpe, correlacionando con el HP del rival.
-- Variables de combate (encontradas):
--   HP  P1 = 0xFF84B8, P2 = 0xFF88B8  (word, max 223 = 0xDF)
--   HP-débil P1 = 0xFF8478, P2 = 0xFF8878 (word, 111)
-- Cronometramos: cambios de HP y su timing relative al frame del impacto.

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_frames.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local HP1, HP2 = 0xFF84B8, 0xFF88B8
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end

local function scan_nz()
  local nz=0; local a=0xFF0000
  while a<=0xFFFFFF do
    local v=rd(a); if v~=0 then nz=nz+1 end; a=a+2
  end
  return nz
end

log("=== medicion de frames de golpe (demo) ===")

-- Espera a que el combate empiece (HP cerca de 223)
local prev1, prev2 = rd(HP1), rd(HP2)
log("HP inicial: P1=" .. prev1 .. " P2=" .. prev2)

local maxfr = 30000
local hits = {}   -- {frame, dmgP1(dano hecho a P2), hpP2, hpP1}
local started = false

for fr = 1, maxfr do
  emu.frameadvance()
  local h1, h2 = rd(HP1), rd(HP2)
  --直到 el combate este activo (HP < 223 indica dano ya cleansing)
  if h1 > 0 and h1 <= 0xDF and h2 > 0 and h2 <= 0xDF then
    if not started then
      started = true
      log(">>> combate activo en frame " .. fr .. "  HP1=" .. h1 .. " HP2=" .. h2)
    end
    -- detectar cambios (impactos)
    if h1 ~= prev1 then
      hits[#hits+1] = {fr=fr, target=1, newh=h1, oldh=prev1, dmg=prev1-h1}
    end
    if h2 ~= prev2 then
      hits[#hits+1] = {fr=fr, target=2, newh=h2, oldh=prev2, dmg=prev2-h2}
    end
    prev1, prev2 = h1, h2
  end

  if fr % 2000 == 0 then
    log("f" .. fr .. " hits=" .. #hits .. " HP1=" .. h1 .. " HP2=" .. h2 .. " act=" .. scan_nz())
  end
  if #hits >= 400 then
    log("suficientes hits en frame " .. fr)
    break
  end
end

log("=== total hits detectados: " .. #hits .. " ===")
-- imprimir tabla: frame relativo entre hits, dano
local base = hits[1] and hits[1].fr or 0
local n = 0
for _, x in ipairs(hits) do
  n = n + 1
  log(string.format("%3d  frame=%6d (+%4d)  target=%d  dmg=%3d  hp_antes=%3d hp_despues=%3d",
    n, x.fr, x.fr-base, x.target, x.dmg, x.oldh, x.newh))
  if n >= 400 then break end
end

f:close()
client.exit()