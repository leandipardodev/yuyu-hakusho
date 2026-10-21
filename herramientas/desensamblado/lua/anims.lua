-- anims.lua : captura secuencias de frames de combate para extraer animaciones.
-- Usa el attract mode (el juego se pelea solo con la IA = moves reales).
-- Captura rafagas de N frames consecutivos cuando hay combate activo.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\anims\\"
local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local P1, P2, P3, P4 = 0xFF8000, 0xFF8400, 0xFF8800, 0xFF8C00
local function hp(s)
  local ok, v = pcall(memory.read_u16_be, s + 0x4B8, "M68K BUS")
  if ok and type(v) == "number" then return v end
  return 0
end
local function anim(s)
  local ok, v = pcall(memory.read_u16_be, s + 0x190, "M68K BUS")
  if ok and type(v) == "number" then return v end
  return 0
end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

-- esperar al combate del attract
while hp(P1) == 0 and emu.framecount() < 1500 do emu.frameadvance() end
idle(120)
-- un pequeño log
local f = io.open(dir .. "anims.txt", "w")
f:write("capturando animaciones del combate del attract\n")
f:write(string.format("combate inicia en frame %d, HP1=%d HP2=%d\n", emu.framecount(), hp(P1), hp(P2)))
f:flush()

-- Capturar RAFAGAS de N frames CONSECUTIVOS (no por cambio de anim, sino
-- bloques fijos de combate). El trigger por anim se dispara cada frame (el
-- contador avanza siempre), asi que capturamos en ventanas fijas: cuando un
-- jugador esta en una animacion de golpe (HP del otro bajando) o simplemente
-- cada X frames durante el combate, tomando N frames seguidos.
local BURST = 16
local N_BURSTS = 30
local burst_count = 0
local total_frames = 0

-- esperar combate
while hp(P1) == 0 and emu.framecount() < 1500 do emu.frameadvance() end
idle(60)

for fr = 1, 80000 do
  emu.frameadvance()
  if hp(P1) == 0 then
    -- round nuevo
  else
    -- capturar bursts cuando alguien acaba de recibir dano (golpe conecto) o
    -- cada 90 frames de combate activo
    local recently_hit = false
    if hp(P1) < 223 or hp(P2) < 223 or hp(P3) < 223 or hp(P4) < 223 then
      recently_hit = true
    end
    if (recently_hit or fr % 90 == 0) and burst_count < N_BURSTS then
      burst_count = burst_count + 1
      local name = string.format("s%02d", burst_count)
      f:write(string.format("burst %02d @frame %d HP=%d/%d/%d/%d\n",
        burst_count, emu.framecount(), hp(P1), hp(P2), hp(P3), hp(P4)))
      f:flush()
      for k = 1, BURST do
        emu.frameadvance()
        total_frames = total_frames + 1
        pcall(function() client.screenshot(dir .. string.format("%s_f%02d.png", name, k)) end)
      end
    end
    if burst_count >= N_BURSTS then
      break
    end
  end
end

f:write(string.format("TOTAL: %d bursts, %d frames capturados\n", burst_count, total_frames))
f:close()
client.exit()