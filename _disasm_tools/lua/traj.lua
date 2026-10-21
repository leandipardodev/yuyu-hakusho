-- traj.lua : volcar la trayectoria CRUDA del timer +0x47A para un move,
-- en modo practica, para entender el patron y construir un detector fiable.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "traj.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local T1  = S1+0x47A
local T2  = S1+0x468
local F   = S1+0x188
local HP1 = S1+0x4B8
local HP4 = 0xFF8C00+0x4B8
local POS = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

log("=== trayectoria cruda (modo practica) ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)
press({Down=true}); idle(20)          -- 練習試合
press({Start=true}); idle(40)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)

-- acercar al dummy
local prev = rd(POS); local stuck = 0
for s=1,80 do
  press({Right=true})
  local p = rd(POS)
  if p == prev then stuck = stuck + 1 else stuck = 0 end
  prev = p
  if stuck >= 3 then break end
end
log("dummy en pos " .. rd(POS))

-- 1) reposo largo: ver el valor estable del timer
log("")
log("=== reposo (60 frames) ===")
for i=1,60 do emu.frameadvance()
  if i % 5 == 0 then log(string.format("  f%02d  T1=0x%03X  T2=0x%03X  F=0x%04X  HP1=%d HP4=%d", i, rd(T1), rd(T2), rd(F), rd(HP1), rd(HP4))) end
end

-- 2) un move simple (A) con trayectoria completa
local function dump_move(name, fn, n)
  log("")
  log("=== " .. name .. " ===")
  -- asegurar reposo
  local g=0 while rd(T1) ~= 0xDF and g<250 do emu.frameadvance(); g=g+1 end
  idle(15)
  local hp4 = rd(HP4)
  log("  frame | T1    | T2    | F     | HP4  | delta")
  local prevt = rd(T1)
  local prevf = rd(F)
  log(string.format("  %4d | 0x%03X | 0x%03X | 0x%04X| %4d |   (reposo)", 0, prevt, rd(T2), prevf, hp4))
  fn()
  for i=1,n do
    emu.frameadvance()
    local t=rd(T1); local fr=rd(F)
    log(string.format("  %4d | 0x%03X | 0x%03X | 0x%04X| %4d | %+d", i, t, rd(T2), fr, rd(HP4), t-prevt))
    prevt = t
  end
end

dump_move("A parado (golpe fuerte)", function() press({A=true}) end, 45)
dump_move("B parado (golpe ligero)", function() press({B=true}) end, 45)
dump_move("abajo+A", function() press({Down=true}); for i=1,4 do emu.frameadvance() end; press({A=true}) end, 50)

log("")
log("fin")
f:close()
client.exit()