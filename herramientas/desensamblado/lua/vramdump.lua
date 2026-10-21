-- vramdump.lua : vuelca VRAM y CRAM del Mega Drive desde BizHawk.
-- Los tiles estan YA decodificados en VRAM (no hace falta el codec del ROM).
-- Volcamos en la pantalla de seleccion de personaje (muestra los 11 retratos)
-- y durante combate.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "vramdump.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

-- dominios disponibles
log("=== dominios de memoria ===")
local doms = memory.getmemorydomainlist()
for i=1,#doms do log("  " .. doms[i]) end

-- volcar un dominio completo a archivo
local function dump_domain(dom, fname, size)
  local fh = assert(io.open(dir .. fname, "wb"))
  local n = 0
  local a = 0
  while a < size do
    local ok, v = pcall(memory.read_u8, a, dom)
    if not ok or type(v) ~= "number" then v = 0 end
    fh:write(string.char(v))
    a = a + 1
    n = n + 1
  end
  fh:close()
  return n
end

-- navegar a la pantalla de SELECCION DE PERSONAJE (muestra los 11 retratos)
log("")
log("=== navegando a character select ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)   -- Game Start
press({Start=true}); idle(50)   -- modo de juego
press({Right=true}); idle(8); press({Start=true}); idle(20)   -- P2 CPU
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
-- aqui deberiamos estar en ENTRY; avanzar a char select
press({Start=true}); idle(40)
log("en char select (frame " .. emu.framecount() .. ")")

-- volcar VRAM (64KB) y CRAM (128 bytes = 64 colores)
local n_vram = dump_domain("VRAM", "vram_charselect.bin", 0x10000)
log("VRAM volcado: " .. n_vram .. " bytes")
local n_cram = dump_domain("CRAM", "cram_charselect.bin", 128)
log("CRAM volcado: " .. n_cram .. " bytes")
-- screenshot de referencia
pcall(function() client.screenshot(dir .. "vram_charselect.png") end)
log("screenshot guardado")

-- avanzar a combate y volcar de nuevo
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)
dump_domain("VRAM", "vram_fight.bin", 0x10000)
dump_domain("CRAM", "cram_fight.bin", 128)
pcall(function() client.screenshot(dir .. "vram_fight.png") end)
log("volcado de combate hecho")

f:close()
client.exit()