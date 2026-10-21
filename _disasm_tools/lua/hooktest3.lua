-- hooktest3.lua : encontrar la firma correcta de onmemorywrite
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "hooktest3.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)
for i=1,30 do emu.frameadvance() end

local hp = 0xFF84B8
-- posibles firmas: (addr, name, scope, cb) o (addr, cb, name, scope)
local function cb(a, v, fl) end
local tries = {
  {"a,n,s,cb", function() return event.onmemorywrite(hp, "hp", "M68K BUS", cb) end},
  {"a,cb,n,s", function() return event.onmemorywrite(hp, cb, "hp", "M68K BUS") end},
  {"a,s,cb",    function() return event.onmemorywrite(hp, "M68K BUS", cb) end},
  {"a,cb",      function() return event.onmemorywrite(hp, cb) end},
  {"a,n,cb",    function() return event.onmemorywrite(hp, "hp", cb) end},
}
for _, t in ipairs(tries) do
  local ok, res = pcall(t[2])
  log(string.format("  %-12s -> ok=%s res=%s", t[1], tostring(ok), tostring(res)))
end

f:close()
client.exit()