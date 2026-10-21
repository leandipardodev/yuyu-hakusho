-- sar7.lua : S/A/R limpio usando modo PRACTICA (dummy no ataca).
-- Elige 練習試合 (practica) en vez de 勝抜き戦, y mide la trayectoria
-- completa del timer +0x47A para separar recovery propio de golpe recibido.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar7.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local T1  = S1+0x47A
local HP1 = S1+0x4B8
local HP4 = 0xFF8C00+0x4B8
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end
local BTN, GAP = 5, 4
local function gap() for i=1,GAP do emu.frameadvance() end end
local n=0
local function shot(nm)
  n=n+1
  pcall(function() client.screenshot(string.format("%ss7_%02d_%s.png", dir, n, nm)) end)
end

log("=== S/A/R en modo PRACTICA ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)   -- menu de modo: 1a=勝抜き戦
-- bajar a la 2a opcion = 練習試合 (practica)
press({Down=true}); idle(20)
shot("modo_seleccion")
press({Start=true}); idle(40)
-- ENTRY: P1 humano, resto CPU
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
shot("entry")
-- char select
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)
shot("combate")
log("en combate. T1=" .. string.format("0x%X", rd(T1)) .. " HP1=" .. rd(HP1) .. " HP4=" .. rd(HP4))

-- verificar que el dummy NO ataca: observar 120 frames sin hacer nada
log("")
log("=== verificando que el dummy no ataca (120 frames en reposo) ===")
local hp0 = rd(HP1)
local hp_min = hp0
for i=1,120 do
  emu.frameadvance()
  if rd(HP1) < hp_min then hp_min = rd(HP1) end
end
log(string.format("HP1: inicio=%d minimo=%d  -> dummy%s ataca", hp0, hp_min,
  (hp_min < hp0) and " SI" or " NO"))

-- medir
local function measure(name, fn, obs)
  obs = obs or 60
  -- esperar recuperacion total
  local guard = 0
  while rd(T1) < 0xDF and guard < 200 do emu.frameadvance(); guard = guard + 1 end
  idle(10)
  local hp0 = rd(HP1)
  local hp4 = rd(HP4)
  local t_before = rd(T1)
  local startf = emu.framecount()
  fn()
  local inp = emu.framecount() - startf
  -- trayectoria
  local traj = {}
  for i=1,obs do
    emu.frameadvance()
    traj[i] = {t=rd(T1), hp1=rd(HP1), hp4=rd(HP4)}
  end
  -- analisis: primer decremento = startup; frames hasta volver al valor t_before
  local startup = nil
  local endf = nil
  for i=1,obs do
    if traj[i].t < t_before then
      if not startup then startup = inp + i - 1 end
      endf = inp + i - 1
    end
  end
  local recov = (startup and endf) and (endf - startup + 1) or nil
  local hit4 = nil
  for i=1,obs do if traj[i].hp4 < hp4 then hit4 = i break end end
  local dmg = hit4 and (hp4 - traj[hit4].hp4) or 0
  local got_hit = false
  for i=1,obs do if traj[i].hp1 < hp0 then got_hit = true break end end
  log(string.format("%-20s | inp=%2d | startup=%-4s | recov=%-4s | dmg=%3d | recibio=%s",
    name, inp, tostring(startup or "-"), tostring(recov or "-"), dmg, got_hit and "SI" or "no"))
  return {sa=startup, recov=recov, dmg=dmg, got_hit=got_hit}
end

log("")
log("=== MEDICIONES (Yusuke, practica) ===")
local R = {}
R["A parado"]     = measure("A parado",       function() press({A=true}) end)
R["abajo+A"]      = measure("abajo+A",        function() press({Down=true}); gap(); press({A=true}) end)
R["B parado"]     = measure("B parado",       function() press({B=true}) end)
R["abajo+B"]      = measure("abajo+B",        function() press({Down=true}); gap(); press({B=true}) end)
R[">+B"]          = measure("->+B",           function() press({Right=true}); gap(); press({B=true}) end)
R["->+A agarre"]  = measure("->+A agarre",    function() press({Right=true}); gap(); press({A=true}) end)
R["Reimu QCF+A"]  = measure("Reimu QCF+A",     function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({A=true}) end, 80)
R["Reimu QCF+B"]  = measure("Reimu QCF+B",     function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({B=true}) end, 80)
R["DD+A"]         = measure("DD+A",           function()
  press({Down=true}); gap(); press({Down=true}); gap(); press({A=true}) end)

log("")
log("=== RESUMEN ===")
log(string.format("%-20s | %8s | %8s | %5s", "move", "startup", "recov", "dmg"))
log("----------------------------------------------------------")
for k,v in pairs(R) do
  log(string.format("%-20s | %8s | %8s | %5d", k, tostring(v.sa or "-"), tostring(v.recov or "-"), v.dmg))
end

f:close()
client.exit()