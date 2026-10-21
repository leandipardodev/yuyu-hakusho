-- findanim.lua : encontrar el offset REAL de animacion comparando el struct
-- P1 entre reposo y durante un golpe, ahora con el boton maintained 5 frames.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "findanim.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

local SIZE = 0x500
local function snap()
  local t = {}
  for off=0,SIZE-2,2 do t[off]=rd(S1+off) end
  return t
end

log("=== encontrar offset de animacion ===")
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
press({Start=true}); idle(200)

-- reposo
idle(30)
local idle1 = snap()
idle(10)
local idle2 = snap()

-- golpe: mantener A y capturar DURANTE los 5 frames del boton
joypad.set({A=true}, 1)
local during = {}
for i=1,5 do emu.frameadvance(); during[i] = snap() end
joypad.set({}, 1)
-- 20 frames post
for i=1,20 do emu.frameadvance(); during[5+i] = snap() end

-- buscar offsets que cambiaron entre idle2 y cualquier during
local changed = {}
for off=0,SIZE-2,2 do
  for i=1,#during do
    if during[i][off] ~= idle2[off] then
      if not changed[off] then
        changed[off] = {idle=idle2[off], seq={}}
      end
      table.insert(changed[off].seq, during[i][off])
    end
  end
end

log("offsets que cambiaron durante el golpe: " .. #changed)
-- Priorizar: offsets que cambian de forma MONOTONA (contador)
local mono = {}
for off, d in pairs(changed) do
  local is_mono = true
  for i=2,#d.seq do
    if d.seq[i] <= d.seq[i-1] then is_mono = false break end
  end
  if is_mono and #d.seq >= 3 then table.insert(mono, off) end
end
table.sort(mono)
log("offsets MONOTONOS (contadores >=3 cambios): " .. #mono)
for _, off in ipairs(mono) do
  local d = changed[off]
  local vals = {}
  for i=1,math.min(#d.seq,12) do vals[i] = string.format("0x%X", d.seq[i]) end
  log(string.format("  +0x%03X (addr FF%04X): idle=0x%04X  cambios: %s",
    off, 0x8000+off, d.idle, table.concat(vals, " ")))
end

-- tambien volcar TODOS los que cambiaron con su patron
log("")
log("=== todos los offsets que cambiaron (con patron) ===")
local keys = {}
for off in pairs(changed) do table.insert(keys, off) end
table.sort(keys)
for _, off in ipairs(keys) do
  local d = changed[off]
  local vals = {}
  for i=1,math.min(#d.seq,10) do vals[i] = string.format("0x%X", d.seq[i]) end
  local marker = ""
  for _, m in ipairs(mono) do if m == off then marker = " <== MONOTONO" end end
  log(string.format("  +0x%03X: idle=0x%04X  n=%d  %s%s", off, d.idle, #d.seq, table.concat(vals, " "), marker))
end

f:close()
client.exit()