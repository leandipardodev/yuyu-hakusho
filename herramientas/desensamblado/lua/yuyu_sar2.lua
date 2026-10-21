-- yuyu_sar2.lua : mide frames hasta el impacto (startup) y recovery.
-- Usa +0x190 (puntero de animacion VRAM del personaje) como indicador de
-- "el personaje esta animando un golpe".
-- Para cada impacto real: cuenta los frames desde que +0x190 empieza a cambiar
-- (movimiento) hasta el frame del impacto = startup+active. Luego cuenta hasta
-- que +0x190 se estabiliza = recovery.
-- Excluye los resets de round (dmg==223 o HP va a 0).

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_sar2.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local HP1, HP2 = 0xFF84B8, 0xFF88B8
-- P1 struct: offset 0x190 = anim ptr (VRAM, cambia 0x10/frame durante golpe)
-- El atacante = el que NO pierde HP en este impacto.
local function rd(a)
  local ok,v = pcall(memory.read_u16_be, a, "M68K BUS")
  if ok and type(v)=="number" then return v end
  return 0
end
local ANIM1 = 0xFF8190
local ANIM2 = 0xFF8590   -- P2 = +0x400

--buffer de historico de ANIM por frame para detectar "movimiento"
local prev1, prev2 = rd(HP1), rd(HP2)
local anim_hist = {}  -- {frame, a1, a2}
local results = {}
local cur_move_start = nil

local function push(frame)
  table.insert(anim_hist, {f=frame, a1=rd(ANIM1), a2=rd(ANIM2)})
  if #anim_hist > 200 then table.remove(anim_hist,1) end
end

for fr = 1, 60000 do
  emu.frameadvance()
  push(fr)
  local h1, h2 = rd(HP1), rd(HP2)

  -- detectar impacto real (no reset de round)
  local hit = nil
  if h2 < prev2 and (prev2 - h2) < 100 and prev2 > 0xDF - 100 then hit={tgt=2, dmg=prev2-h2} end
  if (not hit) and h1 < prev1 and (prev1 - h1) < 100 and prev1 > 0xDF - 100 then hit={tgt=1, dmg=prev1-h1} end

  if hit then
    -- buscar hacia atras cuando el ANIM del atacante empezo a cambiar
    local attacker_anim_idx = (hit.tgt==2) and 2 or 1
    local impact_anim = (hit.tgt==2) and rd(ANIM2) or rd(ANIM1)
    -- caminar hacia atras hasta que el anim del atacante se estabilice (ultiimo cambio)
    local stable_frame = nil
    local i = #anim_hist - 1
    while i > 2 do
      local cur = anim_hist[i]
      local prv = anim_hist[i-1]
      local cv = (attacker_anim_idx==1) and cur.a1 or cur.a2
      local pv = (attacker_anim_idx==1) and prv.a1 or prv.a2
      if cv ~= pv then
        stable_frame = prv.f   -- primer frame del movimiento
        break
      end
      i = i - 1
    end
    if stable_frame then
      local startup = fr - stable_frame
      table.insert(results, {frame=fr, tgt=hit.tgt, dmg=hit.dmg, startup=startup})
    end
  end
  prev1, prev2 = h1, h2
  if #results >= 120 then break end
end

log("=== frames hasta el impacto (startup+active) por golpe real ===")
log("idx  frame   tgt  dmg  frames_hasta_impacto")
for i, r in ipairs(results) do
  log(string.format("%3d  %6d  P%d  %3d  %d", i, r.frame, r.tgt, r.dmg, r.startup))
end

-- agrupar por dmg -> startup mas comun
log("")
log("=== agrupado por dmg (startup+active mas frecuente) ===")
local byd = {}
for _, r in ipairs(results) do
  if r.dmg > 0 then
    if byd[r.dmg] == nil then byd[r.dmg] = {} end
    table.insert(byd[r.dmg], r.startup)
  end
end
local keys = {}
for k in pairs(byd) do table.insert(keys, k) end
table.sort(keys)
for _, d in ipairs(keys) do
  local arr = byd[d]
  local sum = 0
  for _, v in ipairs(arr) do sum = sum + v end
  local avg = sum / #arr
  table.sort(arr)
  log(string.format("  dmg=%3d  n=%2d  startup_promedio=%5.1f  mediana=%d  min=%d max=%d",
      d, #arr, avg, arr[math.floor(#arr/2)+1], arr[1], arr[#arr]))
end

f:close()
client.exit()