-- sar4.lua : S/A/R preciso por personaje.
-- CORRECCION DEL BUG: el boton se mantenia solo 2 frames y el juego no lo
-- registraba. Ahora cada pulsacion dura 5-6 frames (patron arcade) con 4 frames
-- degap entre partes del motion.
--
-- Estructuras de jugador (work RAM 68k), 4 slots separados 0x400:
--   P1=0xFF8000  P2=0xFF8400  P3=0xFF8800  P4=0xFF8C00
--   +0x4B8 HP   +0x478 stun actual  +0x47A stun max  +0x26C posX  +0x188 frame counter
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar4.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1, S4 = 0xFF8000, 0xFF8C00
local HP1, HP4 = S1+0x4B8, S4+0x4B8
local POS1 = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end

local BTN_HOLD = 5      -- frames por pulsacion (FIX: era 2 y no lo registraba)
local BTN_GAP  = 4      -- frames entre partes de un motion

local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or BTN_HOLD) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function gap() for i=1,BTN_GAP do emu.frameadvance() end end
local function idle(n) for i=1,n do emu.frameadvance() end end

log("=== S/A/R preciso (boton " .. BTN_HOLD .. " frames) ===")

-- navegacion al combate
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
press({Start=true}); idle(30)      -- char select P1
log("en combate HP1=" .. rd(HP1) .. " HP4=" .. rd(HP4))
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(150)     -- quitar pausa, esperar round

-- pegarse al rival
local prev = rd(POS1); local stuck = 0
for s=1,200 do
  press({Right=true})
  local p = rd(POS1)
  if p == prev then stuck = stuck + 1 else stuck = 0 end
  prev = p
  if stuck >= 4 then log("P1 adyacente (pos=" .. p .. ")"); break end
end
idle(20)

-- medicion
local function measure(name, fn, total)
  log("")
  log("### " .. name)
  idle(35)
  local hp0 = rd(HP4)
  local start_frame = emu.framecount()
  fn()
  local input_frames = emu.framecount() - start_frame
  local hp_list = {}
  for i=1,(total or 50) do emu.frameadvance(); hp_list[i] = rd(HP4) end
  local hit = nil
  for i=1,#hp_list do if hp_list[i] < hp0 then hit = i break end end
  local dmg = hit and (hp0 - hp_list[hit]) or 0
  log(string.format("  input ocupo %d frames", input_frames))
  if hit then
    log(string.format("  STARTUP+ACTIVE = %d frames", input_frames + hit - 1))
    log(string.format("  DANO = %d", dmg))
  else
    log("  sin hit")
  end
  local recov = nil
  if hit then
    for r=1,70 do
      local pb = rd(POS1)
      press({Right=true})
      if rd(POS1) ~= pb then recov = r break end
    end
    log(string.format("  RECOVERY = %s frames tras hit", tostring(recov)))
  end
  return {sa=(hit and (input_frames + hit - 1) or nil), dmg=dmg, recov=recov}
end

local R = {}
R["A parado"]       = measure("A - golpe fuerte parado",      function() press({A=true}) end, 45)
R["A agachado"]     = measure("abajo+A - fuerte agachado",     function() press({Down=true}); gap(); press({A=true}) end, 50)
R["B parado"]       = measure("B - golpe ligero parado",      function() press({B=true}) end, 40)
R["B agachado"]     = measure("abajo+B - ligero agachado",     function() press({Down=true}); gap(); press({B=true}) end, 40)
R["->+A (AGARRE)"]  = measure("derecha+A - AGARRE",            function() press({Right=true}); gap(); press({A=true}) end, 60)
R["Reimu QCF+A"]    = measure("Reimu (QCF+A)",                 function()
    press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({A=true}) end, 75)
R["Reimu QCF+B"]    = measure("Reimu (QCF+B)",                 function()
    press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({B=true}) end, 75)

log("")
log("=== RESUMEN S/A/R (Yusuke) ===")
log(string.format("%-18s %10s %10s %6s", "move", "startup", "recovery", "dano"))
for k,v in pairs(R) do
  log(string.format("%-18s %10s %10s %6d", k, tostring(v.sa or "-"), tostring(v.recov or "-"), v.dmg))
end

f:close()
client.exit()