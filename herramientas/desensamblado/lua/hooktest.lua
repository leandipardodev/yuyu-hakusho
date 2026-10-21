-- hooktest.lua : verificar si BizHawk soporta hooks de bus/memoria
-- (event.onbuswrite) para capturar el frame EXACTO de un impacto.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "hooktest.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

log("=== event API disponible ===")
if event then
  for k, v in pairs(event) do
    if type(k) == "string" and type(v) == "function" then
      log("  event." .. k)
    end
  end
  log("availableScopes:")
  if event.availableScopes then
    local sc = event.availableScopes()
    for i = 1, #sc do log("  scope: " .. sc[i]) end
  end
else
  log("event NO disponible")
end

f:close()
client.exit()