-- yuyu_sar.lua : mide S/A/R de un golpe watching los offsets candidatos.
-- Observa los campos de estado del atacante alrededor de un impacto de HP.
-- Los offsets +0x4BC, +0x47A, +0x190, +0x19C son los candidatos a estado/anim.
-- Estrategia: para CADA impacto de HP del rival, logueamos los valores de estos
-- offsets durante ~20 frames antes/despues, para ver la transicion.

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_sar.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local HP1, HP2 = 0xFF84B8, 0xFF88B8
local CAND = {0x4BC, 0x47A, 0x190, 0x19C, 0x188, 0x198, 0x4A8, 0x42C, 0x358, 0x398}

local function rd(a)
  local ok,v = pcall(memory.read_u16_be, a, "M68K BUS")
  if ok and type(v)=="number" then return v end
  return 0
end

log("=== S/A/R: secuencia de estado alrededor de impactos ===")

local prev1, prev2 = rd(HP1), rd(HP2)
local ring = {}   -- buffer circular de los ultimos 20 frames de los candidatos
local RINGN = 24
local hits_logged = 0

for fr = 1, 60000 do
  emu.frameadvance()
  -- guardar estado actual en ring buffer
  local snap = {fr=fr}
  for _, off in ipairs(CAND) do
    snap[off] = rd(0xFF8000 + off)
  end
  table.insert(ring, snap)
  if #ring > RINGN + 10 then table.remove(ring, 1) end

  local h1, h2 = rd(HP1), rd(HP2)
  local hit = nil
  if h2 < prev2 and prev2 == 0xDF then hit = {tgt=2, dmg=prev2-h2} 
  elseif h1 < prev1 and prev1 == 0xDF then hit = {tgt=1, dmg=prev1-h1} end

  if hit and hits_logged < 12 then
    hits_logged = hits_logged + 1
    log("")
    log("### IMPACTO #" .. hits_logged .. " frame=" .. fr .. " target=P" .. hit.tgt .. " dmg=" .. hit.dmg)
    log("  frame | " .. string.match(table.concat((function() local t={} for _,o in ipairs(CAND) do t[#t+1]=string.format("+%03X",o) end return t end)(), " "), "(.*)"))
    -- imprimir los ultimos frames antes del impacto
    local start = math.max(1, #ring - RINGN)
    for i = start, #ring do
      local s = ring[i]
      local vals = {}
      for _, off in ipairs(CAND) do
        vals[#vals+1] = string.format("%04X", s[off])
      end
      local mark = (s.fr == fr) and "  <-- IMPACTO" or ""
      log(string.format("  %6d | %s%s", s.fr, table.concat(vals, " "), mark))
    end
  end
  prev1, prev2 = h1, h2
  if hits_logged >= 12 then break end
end

f:close()
client.exit()