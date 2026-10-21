-- probe.lua : sondea los dominios de memoria de BizHawk para el Mega Drive.
-- Necesitamos saber cuanto mide realmente el dominio VRAM y si se puede
-- leer entero, porque el volcado anterior salio con ceros a partir de 0x0F600.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "probe.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)
for i = 1, 120 do emu.frameadvance() end

local doms = memory.getmemorydomainlist()
log("=== dominios (" .. #doms .. ") ===")
for i = 1, #doms do log("  [" .. i .. "] " .. doms[i]) end

-- para cada dominio, leer una serie de direcciones y ver donde falla
log("")
log("=== sondeo de lecturas (ultimo valor leido con exito) ===")
local sondas = { 0x0000, 0x1000, 0x8000, 0x0F000, 0x10000, 0x1FFFF, 0x20000,
                 0x3F000, 0x3F800, 0x3FFFF, 0xFFFFFF }
for i = 1, #doms do
  local d = doms[i]
  local res = {}
  for _, a in ipairs(sondas) do
    local ok, v = pcall(memory.read_u8, a, d)
    if ok and type(v) == "number" then
      res[#res + 1] = string.format("%X:%02X", a, v)
    else
      res[#res + 1] = string.format("%X:ERR", a)
    end
  end
  log(string.format("  %-22s %s", d, table.concat(res, " ")))
end

-- registros del VDP: intentar leerlos por varios dominios
log("")
log("=== registros VDP (cramos 3-6 del puerto de control) ===")
for i = 1, #doms do
  local d = doms[i]
  local crams = {}
  local ok0, v0 = pcall(memory.read_u16, 0xC00004, d)
  if ok0 and type(v0) == "number" then
    -- los registros 2..15 se leen escribiendo primero su numero en el puerto
    for reg = 0, 15 do
      memory.write_u16(0xC00004, reg * 2, d)
      local ok, v = pcall(memory.read_u16, 0xC00000, d)
      if ok and type(v) == "number" then crams[#crams + 1] = v else crams[#crams + 1] = -1 end
    end
    log("  " .. d)
    for reg = 0, 15 do
      log(string.format("    reg%-2d (%s) = $%04X", reg,
        ({ "$0000","$0000","$0000","$0000","$0000","$0000","$0000","$0000",
            "$8000","$0000","$0000","$0000","$0000","$0000","$0000","$0000" })[reg + 1],
        crams[reg + 1]))
    end
  end
end

f:close()
client.exit()
