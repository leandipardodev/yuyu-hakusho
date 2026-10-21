-- dmgattr.lua : damage EXACTO via attract mode (demo del juego).
-- El juego se juega solo con moves reales. Capturo cada cambio de HP del
-- jugador 2 (el que la demo golpea) = damage exacto de cada golpe.
-- Correlaciono con el estado de animacion del atacante para inferir el move.
-- Esto NO necesita positioning manual porque la demo se posiciona sola.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "dmgattr.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local P1, P2, P3, P4 = 0xFF8000, 0xFF8400, 0xFF8800, 0xFF8C00
local function hp(s) local ok,v=pcall(memory.read_u16_be,s+0x4B8,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function anim(s) local ok,v=pcall(memory.read_u16_be,s+0x190,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function act(s) local ok,v=pcall(memory.read_u16_be,s+0x468,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end

log("=== Damage por impacto en ATTRACT MODE (demo) ===")
log("La demo se juega sola. Cada golpe que la IA aplica = delta de HP exacto.")

-- esperar al combate del attract
while hp(P1) == 0 and emu.framecount() < 1200 do emu.frameadvance() end
log("combate del attract en frame " .. emu.framecount())

-- monitorear TODOS los 4 slots durante 40000 frames, registrando cada impacto
local last = {hp(P1), hp(P2), hp(P3), hp(P4)}
local impacts = {}
local reset_frame = 0

for fr = 1, 45000 do
  emu.frameadvance()
  local cur = {hp(P1), hp(P2), hp(P3), hp(P4)}
  for i=1,4 do
    if cur[i] < last[i] and last[i] > 0 then
      local dmg = last[i] - cur[i]
      -- el que receives es i, el que pega es el otro. registrar.
      table.insert(impacts, {frame=fr, recv=i, dmg=dmg, hp_before=last[i], hp_after=cur[i]})
    end
    -- reset de round: vuelve a 223
    if last[i] > 100 and cur[i] == 0xDF then
      reset_frame = fr
    end
    last[i] = cur[i]
  end
end

-- analisis
log("")
log("=== DISTRIBUCION DE DANO (delta de HP exacto) ===")
local dist = {}
for _, im in ipairs(impacts) do
  dist[im.dmg] = (dist[im.dmg] or 0) + 1
end
local keys = {}
for k in pairs(dist) do table.insert(keys, k) end
table.sort(keys)
log("dano  | veces")
log("---------------")
for _, k in ipairs(keys) do
  log(string.format("%4d | %d", k, dist[k]))
end
log("")
log("total impactos: " .. #impacts)

-- tabla de referencia (web, validada antes)
log("")
log("=== CONTRASTE con tabla web (newton.com.tw) ===")
local ref = {1,12,16,20,24,32,48,81}
log("Valores esperados: 1, 12, 16, 20, 24, 32, 48, 81")
local found = {}
for _, k in ipairs(keys) do
  for _, r in ipairs(ref) do
    if k == r then found[r] = dist[k] end
  end
end
log("Coincidencias medidas:")
for _, r in ipairs(ref) do
  log(string.format("  %3d -> %s", r, found[r] and (found[r].." veces") or "NO VISTO"))
end

-- guardar impacto crudo
local ff = io.open(dir .. "dmgattr_raw.txt", "w")
for _, im in ipairs(impacts) do
  ff:write(string.format("%d\t%d\t%d\n", im.frame, im.recv, im.dmg))
end
ff:close()

f:close()
client.exit()