-- sar9.lua : S/A/R final, riguroso.
-- Reglas:
--   1. Reposicionar al dummy ANTES de cada move (caminar hasta contacto)
--   2. Solo registrar moves que CONECTEN (HP del rival baja)
--   3. Repetir cada move 3 veces y promediar
--   4. Medir con T2 (+0x468 = estado de accion) + HP del rival
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar9.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local T2  = S1+0x468
local HP1 = S1+0x4B8
local HP4 = 0xFF8C00+0x4B8
local POS1 = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end
local function gap() for i=1,4 do emu.frameadvance() end end

log("=== S/A/R FINAL (modo practica, 3 repeticiones) ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)
press({Down=true}); idle(20)          -- 練習試合
press({Start=true}); idle(40)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)
log("en combate (Yusuke vs dummy)")

-- reposicionar
local function approach()
  local prev = rd(POS1); local stuck = 0
  for s=1,60 do
    press({Right=true})
    local p = rd(POS1)
    if p == prev then stuck = stuck + 1 else stuck = 0 end
    prev = p
    if stuck >= 3 then break end
  end
  idle(8)
end

-- medir 1 intento: retorna (startup, active_dur, total, dmg) o nil si no conecta
local function try_move(fn, obs)
  obs = obs or 55
  local g=0 while rd(T2) ~= 0 and g<200 do emu.frameadvance(); g=g+1 end
  approach()
  idle(10)
  local hp4 = rd(HP4)
  local inp_start = emu.framecount()
  fn()
  local inp = emu.framecount() - inp_start
  local hit = nil
  for i=1,obs do
    emu.frameadvance()
    if not hit and rd(HP4) < hp4 then hit = i end
  end
  if not hit then return nil end
  local dmg = hp4 - rd(HP4)
  return {startup = inp + hit - 1, dmg = dmg, inp = inp, obs = obs}
end

local function measure3(name, fn, obs)
  local ok = 0; local s_sum = 0; local dmg = 0; local results = {}
  for i=1,3 do
    local r = try_move(fn, obs)
    if r then
      ok = ok + 1
      s_sum = s_sum + r.startup
      dmg = r.dmg
      table.insert(results, r.startup)
    end
  end
  if ok == 0 then
    log(string.format("%-18s | SIN CONEXION en 3 intentos", name))
    return nil
  end
  local avg = s_sum / ok
  local res_str = ""
  for _,v in ipairs(results) do res_str = res_str .. v .. " " end
  log(string.format("%-18s | %d/3 ok | startup avg=%5.1f f | dmg=%3d | [%s]",
    name, ok, avg, dmg, res_str))
  return {sa=avg, dmg=dmg, ok=ok}
end

log("")
log(string.format("%-18s | %8s | %12s | %5s", "move", "conexion", "startup_avg", "dmg"))
log("-----------------------------------------------------------------------")

local R = {}
R["A parado"]    = measure3("A parado",    function() press({A=true}) end)
R["B parado"]    = measure3("B parado",    function() press({B=true}) end)
R["abajo+A"]     = measure3("abajo+A",     function() press({Down=true}); gap(); press({A=true}) end)
R["abajo+B"]     = measure3("abajo+B",     function() press({Down=true}); gap(); press({B=true}) end)
R["->+B"]        = measure3("->+B",        function() press({Right=true}); gap(); press({B=true}) end)
R["->+A agarre"] = measure3("->+A agarre", function() press({Right=true}); gap(); press({A=true}) end)
R["Reimu QCF+A"] = measure3("Reimu QCF+A", function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({A=true}) end, 70)
R["Reimu QCF+B"] = measure3("Reimu QCF+B", function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({B=true}) end, 70)

log("")
log("=== RESUMEN FINAL S/A/R (Yusuke) ===")
log(string.format("%-18s | %8s | %5s", "move", "startup", "dmg"))
log("-------------------------------------")
for k,v in pairs(R) do
  if v then
    log(string.format("%-18s | %8.1f | %5d", k, v.sa, v.dmg))
  else
    log(string.format("%-18s | %8s | %5s", k, "-", "-"))
  end
end

f:close()
client.exit()