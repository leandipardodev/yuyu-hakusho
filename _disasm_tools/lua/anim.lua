-- anim.lua : medir S/A/R via el CONTADOR DE ANIMACION del atacante.
-- Idea: cuando P1 ejecuta un move, su puntero de animacion (VRAM) avanza en
-- pasos de 0x10 (1 por frame). Eso marca exactamente cuando empieza la
-- animacion (startup) y cuando vuelve al idle (fin de recovery), sin
-- depender de acertar un golpe ni de la IA rival.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "anim.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local ANIM = S1+0x190      -- puntero de animacion VRAM (avanza 0x10/frame)
local HP1 = S1+0x4B8
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

log("=== medicion por animacion (offset +0x190) ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)
log("en combate. ANIM idle=" .. string.format("0x%X", rd(ANIM)))

-- observar ANIM en reposo 10 frames
log("")
log("ANIM en reposo:")
for i=1,10 do emu.frameadvance(); log(string.format("  f%02d ANIM=0x%X", i, rd(ANIM))) end

-- ejecutar UN golpe y ver como cambia ANIM frame a frame
log("")
log("=== golpe A (parado) - ANIM frame a frame ===")
local before = rd(ANIM)
local samples = {}
for i=1,50 do
  if i == 1 then joypad.set({A=true},1) else joypad.set({},1) end
  emu.frameadvance()
  samples[i] = rd(ANIM)
end
log("  f00 ANIM=0x" .. string.format("%X", before) .. "  <-- input")
for i=1,50 do
  if samples[i] ~= samples[i-1] or i <= 6 then
    local d = samples[i] - samples[i-1]
    log(string.format("  f%02d ANIM=0x%04X  (delta %d)", i, samples[i], d))
  end
end
-- analisis: primer cambio = inicio anim; ultimo cambio = fin anim
local first_change, last_change = nil, nil
for i=2,#samples do
  if samples[i] ~= samples[i-1] then
    if not first_change then first_change = i end
    last_change = i
  end
end
log("")
log(string.format("  primer cambio de anim: frame %s  (startup)", tostring(first_change)))
log(string.format("  ultimo cambio de anim: frame %s", tostring(last_change)))
if first_change and last_change then
  log(string.format("  DURACION total de la animacion = %d frames", last_change - first_change + 1))
end

f:close()
client.exit()