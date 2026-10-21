-- hooktest2.lua : probar directamente las funciones de hook de BizHawk
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "hooktest2.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)
for i=1,30 do emu.frameadvance() end

-- probar cada API de hook
local tests = {
  {"onbuswrite",  function() return event.onbuswrite(0xFF84B8, "hp") end},
  {"onbuswrite_mem", function() return event.onbuswrite(0xFF84B8, "hp", "System Bus") end},
  {"onbusread",   function() return event.onbusread(0xFF84B8, "hp", "System Bus") end},
  {"onmemorywrite", function() return event.onmemorywrite(0xFF84B8, "hp", "M68K BUS") end},
  {"onframestart", function() return event.onframestart(function() end) end},
  {"oninputpoll",  function() return event.oninputpoll(function() end) end},
}
for _, t in ipairs(tests) do
  local ok, res = pcall(t[2])
  log(string.format("  %-18s -> ok=%s res=%s", t[1], tostring(ok), tostring(res)))
end

f:close()
client.exit()