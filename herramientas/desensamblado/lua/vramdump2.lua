-- vramdump2.lua : volcado FIABLE de VRAM y CRAM del Mega Drive.
--
-- El dominio "VRAM" de BizHawk dio ceros en la parte alta, asi que aqui se
-- lee por el puerto de datos del VDP, que es el metodo correcto:
--   1. escribir el numero de registro en 0xC00004
--   2. leer el valor en 0xC00000 (el puerto se autoincrementa)
--
-- Nota: la API de BizHawk NO tiene memory.read_u16; hay que usar
-- memory.read_u16_be / memory.read_u16_le.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "vram2.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local BUS = "M68K BUS"
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i = 1, (hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i = 1, 3 do emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

-- leer un registro del VDP (0-15). El puerto se autoincrementa asi que hay
-- que resincronizar: escribimos el numero de registro antes de cada lectura.
local regs = {}
local function leer_registros()
  for reg = 0, 15 do
    memory.write_u16_be(0xC00004, reg * 2, BUS)
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    regs[reg] = ok and v or -1
  end
end

local function volcar_vram(fname)
  -- comando: CD=0 (VRAM), reg=1 (address), addr=0
  memory.write_u16_be(0xC00004, 1 * 2, BUS)
  local fh = assert(io.open(dir .. fname, "wb"))
  local n = 0
  for i = 1, 32768 do
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    if ok and type(v) == "number" then
      local hi = math.floor(v / 256) % 256
      local lo = v % 256
      fh:write(string.char(hi, lo))
      n = n + 2
    else
      fh:write(string.char(0, 0))
      n = n + 2
    end
  end
  fh:close()
  return n
end

local function volcar_cram(fname)
  -- reg=13 es el puerto de datos de CRAM
  memory.write_u16_be(0xC00004, 13 * 2, BUS)
  local fh = assert(io.open(dir .. fname, "wb"))
  for i = 1, 64 do
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    if ok and type(v) == "number" then
      fh:write(string.char(math.floor(v / 256) % 256, v % 256))
    else
      fh:write(string.char(0, 0))
    end
  end
  fh:close()
end

local function reportar(tag)
  leer_registros()
  log("=== " .. tag .. " (frame " .. emu.framecount() .. ") ===")
  local nombres = { "r0 tamanoH", "r1 tamanoV", "r2 reg2", "r3 dirCaracteres",
                    "r4 reg4", "r5 dirPantalla", "r6 ctrlFS", "r7 zoomHV",
                    "r8 sposH", "r9 sposV", "r10 sizeH", "r11 sizeV",
                    "r12 reg12", "r13 CRAM", "r14 reg14", "r15 reg15" }
  for reg = 0, 15 do
    log(string.format("   %-16s reg%-2d = $%04X", nombres[reg + 1], reg, regs[reg]))
  end
  -- campos utiles
  local reg4 = regs[4]
  local reg5 = regs[5]
  local reg11 = regs[11]
  local char_base = (reg4 & 0x07) * 0x10000
  local screen_base = (reg5 & 0x3F) * 0x800
  local sprite_base = (reg5 & 0x80) ~= 0 and 0x3FC00 or 0x3F800
  local sprite_sh = ((reg11 & 0x03) * 2)
  local addr_mask = reg1_mask(reg11)
  log(string.format("   -> dirCaracteres = $%05X", char_base))
  log(string.format("   -> dirPantalla   = $%05X", screen_base))
  log(string.format("   -> tabla sprites = $%05X", sprite_base))
  log(string.format("   -> sprites en pantalla = %d", sprite_sh))
end

local function reg1_mask(reg11)
  local lim = reg11 & 3
  if lim == 0 then return 0x3FFF
  elseif lim == 1 then return 0x7FFF
  elseif lim == 2 then return 0xFFFF
  else return 0xFFFF end
end

log("=== volcado fiable de VRAM/CRAM ===")
idle(200)
reportar("arranque")
local n1 = volcar_vram("vram2_arranque.bin")
volcar_cram("cram2_arranque.bin")
log("VRAM arranque: " .. n1 .. " bytes")

-- navegar hasta la seleccion de personaje
while emu.framecount() < 450 do emu.frameadvance() end
press({Start = true}); idle(40)
press({Start = true}); idle(40)
press({Start = true}); idle(50)
press({Right = true}); idle(8); press({Start = true}); idle(20)
press({Right = true}); idle(8); press({Start = true}); idle(20)
press({Right = true}); idle(8); press({Start = true}); idle(25)
press({Start = true}); idle(60)
reportar("seleccion de personaje")
volcar_vram("vram2_charsel.bin")
volcar_cram("cram2_charsel.bin")
pcall(function() client.screenshot(dir .. "vram2_charsel.png") end)

-- entrar al combate
press({Start = true}); idle(30)
press({Start = true}); idle(30)
press({Start = true}); idle(120)
reportar("combate")
volcar_vram("vram2_fight.bin")
volcar_cram("cram2_fight.bin")
pcall(function() client.screenshot(dir .. "vram2_fight.png") end)

log("listo")
f:close()
client.exit()
