-- diag.lua : diagnostico del estado del combate tras navegar.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "diag.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1, S4 = 0xFF8000, 0xFF8C00
local HP1, HP4 = S1+0x4B8, S4+0x4B8
local POS1 = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end
local n=0
local function shot(nm)
  n=n+1
  pcall(function() client.screenshot(string.format("%sd_%02d_%s.png", dir, n, nm)) end)
  log(string.format("  [shot %s] frame=%d HP1=%d HP4=%d pos1=%d", nm, emu.framecount(), rd(HP1), rd(HP4), rd(POS1)))
end

log("=== diagnostico de combate ===")
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
shot("al_entrar")

-- probar sin quitar pausa:是多少 frames hasta que empiece el round
log("HP tras entrar: " .. rd(HP1) .. "/" .. rd(HP4))
press({Start=true}); idle(60)
shot("tras_start")
log("HP tras start: " .. rd(HP1) .. "/" .. rd(HP4))

-- avanzar bastante
idle(240)
shot("mas_frames")
log("HP tras 240f: " .. rd(HP1) .. "/" .. rd(HP4))

-- probar un golpe simple y ver si HP baja
log("")
log("=== probando golpes ===")
press({B=true}); idle(30)
log("tras B: HP4=" .. rd(HP4) .. " pos1=" .. rd(POS1))
shot("tras_B")
press({A=true}); idle(30)
log("tras A: HP4=" .. rd(HP4) .. " pos1=" .. rd(POS1))
shot("tras_A")

-- provar caminar
local p0 = rd(POS1)
for i=1,10 do press({Right=true}) end
log("tras caminar derecha: pos1 " .. p0 .. " -> " .. rd(POS1))
shot("tras_caminar")

f:close()
client.exit()