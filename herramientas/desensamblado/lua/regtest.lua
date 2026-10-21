-- regtest.lua : probar si el core Genesis expone registros (d0) via Lua,
-- para leer el dano exacto en el momento del impacto.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "regtest.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)
for i=1,60 do emu.frameadvance() end

log("=== registros expuestos por el core ===")
local regs = emu.getregisters and emu.getregisters() or nil
if regs then
  local keys = {}
  for k,v in pairs(regs) do table.insert(keys, k .. "=" .. tostring(v)) end
  table.sort(keys)
  log("total: " .. #keys)
  for i=1,math.min(#keys, 60) do log("  " .. keys[i]) end
else
  log("getregisters() no disponible")
end

-- probar lecturas individuales
log("")
log("=== prueba getregister ===")
for _, r in ipairs({"d0","D0","pc","PC","a5","A5","d1","d2","x","sp"}) do
  local ok, v = pcall(function() return emu.getregister(r) end)
  log(string.format("  %-4s -> ok=%s val=%s", r, tostring(ok), tostring(v)))
end

f:close()
client.exit()