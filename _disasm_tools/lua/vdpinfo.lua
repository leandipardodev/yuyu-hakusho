-- vdpinfo.lua : lee rapido los registros del VDP y volca VRAM/CRAM.
--
-- Errores corregidos respecto a vramdump2.lua:
--   - reg1_mask estaba declarado DESPUES de reportar: en Lua un 'local
--     function' no es visible antes de su declaracion, asi que reportar la
--     llamaba como global (nil) y reventaba.
--   - todo va dentro de un pcall: si algo falla, se cierra igual y no se
--     queda colgado el EmuHawk.
--   - la API de BizHawk no tiene memory.read_u16: hay que usar read_u16_be.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "vdpinfo.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local BUS = "M68K BUS"

local nombres = { "tamanoH", "tamanoV", "reg2", "dirCaracteres", "reg4",
                  "dirPantalla", "ctrlFS", "zoomHV", "sposH", "sposV",
                  "sizeH", "sizeV", "reg12", "CRAM", "reg14", "reg15" }

local function leer_registros()
  local regs = {}
  for reg = 0, 15 do
    memory.write_u16_be(0xC00004, reg * 2, BUS)
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    regs[reg] = ok and v or -1
  end
  return regs
end

local function volcar_vram(fname, words)
  memory.write_u16_be(0xC00004, 1 * 2, BUS)   -- CD=0 (VRAM), reg=1 (direccion)
  local fh = assert(io.open(dir .. fname, "wb"))
  for i = 1, words do
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    if ok and type(v) == "number" then
      fh:write(string.char(math.floor(v / 256) % 256, v % 256))
    else
      fh:write(string.char(0, 0))
    end
  end
  fh:close()
  return words * 2
end

local function volcar_cram(fname)
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

local function reportar(tag, regs)
  local reg4 = regs[4]
  local reg5 = regs[5]
  local reg11 = regs[11]
  local char_base = (reg4 % 8) * 0x10000
  local screen_base = (reg5 % 64) * 0x800
  local sprite_base = 0
  if reg5 >= 0x80 then sprite_base = 0x3FC00 else sprite_base = 0x3F800 end
  local sprites_h = (reg11 % 4) * 2
  log("=== " .. tag .. " (frame " .. emu.framecount() .. ") ===")
  for reg = 0, 15 do
    log(string.format("   %-14s reg%-2d = $%04X", nombres[reg + 1], reg, regs[reg]))
  end
  log(string.format("   -> dirCaracteres  = $%05X", char_base))
  log(string.format("   -> dirPantalla    = $%05X", screen_base))
  log(string.format("   -> tabla sprites  = $%05X", sprite_base))
  log(string.format("   -> sprites en pant = %d", sprites_h))
end

local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i = 1, (hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i = 1, 3 do emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local ok, err = pcall(function()
  local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
  client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
  emu.limitframerate(false)
  log("=== info del VDP ===")

  idle(200)
  reportar("arranque", leer_registros())

  -- ir a combate
  while emu.framecount() < 450 do emu.frameadvance() end
  press({Start = true}); idle(40)
  press({Start = true}); idle(40)
  press({Start = true}); idle(50)
  press({Right = true}); idle(8); press({Start = true}); idle(20)
  press({Right = true}); idle(8); press({Start = true}); idle(20)
  press({Right = true}); idle(8); press({Start = true}); idle(25)
  press({Start = true}); idle(60)
  reportar("seleccion", leer_registros())
  local n = volcar_vram("vram3_charsel.bin", 32768)
  volcar_cram("cram3_charsel.bin")
  log("   VRAM charsel volcada: " .. n .. " bytes")
  pcall(function() client.screenshot(dir .. "vdp3_charsel.png") end)

  press({Start = true}); idle(30)
  press({Start = true}); idle(30)
  press({Start = true}); idle(120)
  reportar("combate", leer_registros())
  n = volcar_vram("vram3_fight.bin", 32768)
  volcar_cram("cram3_fight.bin")
  log("   VRAM fight volcada: " .. n .. " bytes")
  pcall(function() client.screenshot(dir .. "vdp3_fight.png") end)

  log("listo")
end)

if not ok then log("ERROR: " .. tostring(err)) end
f:close()
pcall(function() client.exit() end)
