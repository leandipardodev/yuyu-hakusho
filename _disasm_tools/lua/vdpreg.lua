-- vdpreg.lua : SOLO lee los 16 registros del VDP. Son 16 lecturas por
-- momento, asi que es instantaneo (el volcado de 64KB por el puerto de datos
-- desde Lua era lentisimo y colgaba EmuHawk).
--
-- BizHawk Lua no tiene memory.read_u16: hay que usar read_u16_be.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "vdpreg.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local BUS = "M68K BUS"
local nombres = { "tamanoH", "tamanoV", "reg2", "dirCaracteres", "reg4",
                  "dirPantalla", "ctrlFS", "zoomHV", "sposH", "sposV",
                  "sizeH", "sizeV", "reg12", "CRAM", "reg14", "reg15" }

local function regs()
  local r = {}
  for reg = 0, 15 do
    memory.write_u16_be(0xC00004, reg * 2, BUS)
    local ok, v = pcall(memory.read_u16_be, 0xC00000, BUS)
    r[reg] = ok and v or -1
  end
  return r
end

local function dump(tag, r)
  local char_base = (r[4] % 8) * 0x10000
  local screen_base = (r[5] % 64) * 0x800
  local sprite_base = (r[5] >= 0x80) and 0x3FC00 or 0x3F800
  local sprites_h = (r[11] % 4) * 2
  log("--- " .. tag .. " (frame " .. emu.framecount() .. ") ---")
  for reg = 0, 15 do
    log(string.format("   %-14s reg%-2d = $%04X", nombres[reg + 1], reg, r[reg]))
  end
  log(string.format("   >> dirCaracteres = $%05X", char_base))
  log(string.format("   >> dirPantalla   = $%05X", screen_base))
  log(string.format("   >> tablaSprites  = $%05X", sprite_base))
  log(string.format("   >> spritesH      = %d", sprites_h))
  -- el estado tambien dice si hay VBlank pendiente y el modo de color
  local st = r[11]
  log("")
end

-- comprobacion extra: leer el estado por 0xC00004 y el contador HV
local function estado()
  local s = memory.read_u16_be(0xC00004, BUS)
  local hv = memory.read_u8(0xC00008, BUS)
  return s, hv
end

local function press(t, h)
  joypad.set(t, 1)
  for i = 1, (h or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i = 1, 3 do emu.frameadvance() end
end
local function idle(n) for i = 1, n do emu.frameadvance() end end

local ok, err = pcall(function()
  local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
  client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
  emu.limitframerate(false)
  log("=== registros del VDP (solo lecturas) ===")

  idle(200)
  dump("arranque (f200)", regs())
  local s, hv = estado()
  log("   estado 0xC00004 = $%04X   contadorHV = %d" % (s, hv))

  while emu.framecount() < 450 do emu.frameadvance() end
  press({Start = true}); idle(40)
  press({Start = true}); idle(40)
  press({Start = true}); idle(50)
  press({Right = true}); idle(8); press({Start = true}); idle(20)
  press({Right = true}); idle(8); press({Start = true}); idle(20)
  press({Right = true}); idle(8); press({Start = true}); idle(25)
  press({Start = true}); idle(60)
  dump("charsel", regs())
  s, hv = estado()
  log("   estado 0xC00004 = $%04X   contadorHV = %d" % (s, hv))
  -- mira si el dominio VRAM tiene algo en la tabla de sprites
  local r = regs()
  local sb = (r[5] >= 0x80) and 0x3FC00 or 0x3F800
  local nz = 0
  local bytes = {}
  for i = 0, 127 do
    local b = memory.read_u8(sb + i, "VRAM")
    bytes[#bytes + 1] = b
    if b ~= 0 then nz = nz + 1 end
  end
  log("   dominio VRAM en $%05X: %d bytes no nulos de 128" % (sb, nz))
  local hex = ""
  for i = 1, 32 do hex = hex .. string.format("%02X ", bytes[i]) end
  log("   primeros 32 bytes: " .. hex)

  press({Start = true}); idle(30)
  press({Start = true}); idle(30)
  press({Start = true}); idle(150)
  dump("combate", regs())
  r = regs()
  sb = (r[5] >= 0x80) and 0x3FC00 or 0x3F800
  nz = 0
  for i = 0, 127 do
    if memory.read_u8(sb + i, "VRAM") ~= 0 then nz = nz + 1 end
  end
  log("   dominio VRAM en $%05X: %d bytes no nulos de 128" % (sb, nz))
  log("listo")
end)

if not ok then log("ERROR: " .. tostring(err)) end
f:close()
pcall(function() client.exit() end)
