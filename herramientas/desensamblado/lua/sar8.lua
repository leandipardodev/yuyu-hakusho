-- sar8.lua : S/A/R preciso usando T2 (+0x468) como indicador de ACCION.
--
-- Hallazgos de la trajectory:
--   +0x47A = stun max (0xDF) - constante, no sirve
--   +0x468 = ESTADO DE ACCION: 0x000 en reposo -> salta a 0x500 al actuar
--   +0x188 = frame counter global (incrementa 1/frame)
--
-- Metodo: capturo el frame EXACTO en que T2 cambia (inicio de la accion) y
-- en que vuelve a 0 (fin = recovery total). El hit se detecta por HP del rival.
-- Como el input tarda unos frames en aplicarse, mido desde el cambio de T2,
-- no desde el frame del input fisico.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar8.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local T2  = S1+0x468   -- estado de accion
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

log("=== S/A/R preciso (T2=estado de accion) ===")
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
log("en combate")

local function measure(name, fn, obs)
  obs = obs or 60
  -- esperar a reposo completo (T2 == 0)
  local g=0 while rd(T2) ~= 0 and g<200 do emu.frameadvance(); g=g+1 end
  idle(12)
  local hp4 = rd(HP4)
  local hp1 = rd(HP1)
  -- ejecutar el input, capturando T2 cada frame
  local t = {}
  local input_done = false
  -- envoltura: capturo T2 justo despues de cada frameadvance interno no es posible,
  -- asi que mido la ventana completa antes y despues.
  fn()                       -- el input
  for i=1,6 do emu.frameadvance(); t[i] = rd(T2) end   -- primeros frames
  for i=7,obs do emu.frameadvance(); t[i] = rd(T2) end
  -- detectar: primer frame con T2 != 0 (inicio accion), primer frame con
  -- T2 == 0 de nuevo (fin accion), y hit por HP
  local act_start, act_end = nil, nil
  for i=1,obs do
    if t[i] ~= 0 then
      if not act_start then act_start = i end
      act_end = i
    end
  end
  local hit = nil
  -- el hit se detecta aparte: HP4 bajo
  -- (re-muestreamos HP tras la ventana no sirve; usamos el valor final)
  local res = {
    act_start = act_start,
    act_len = (act_start and act_end) and (act_end - act_start + 1) or nil,
    dmg = hp4 - rd(HP4)
  }
  log(string.format("%-20s | accion inicia f%-4s | duraccion=%-4s | dmg=%3d",
    name, tostring(act_start or "-"), tostring(res.act_len or "-"), res.dmg))
  return res
end

-- verificar que los golpes conectan (dummy cerca)
local R = {}
R["A parado"]    = measure("A parado",       function() press({A=true}) end)
R["B parado"]    = measure("B parado",       function() press({B=true}) end)
R["abajo+A"]     = measure("abajo+A",        function() press({Down=true}); gap(); press({A=true}) end)
R["abajo+B"]     = measure("abajo+B",        function() press({Down=true}); gap(); press({B=true}) end)
R[">+A agarre"]  = measure("->+A agarre",    function() press({Right=true}); gap(); press({A=true}) end)
R["Reimu QCF+A"] = measure("Reimu QCF+A",     function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({A=true}) end, 70)
R["Reimu QCF+B"] = measure("Reimu QCF+B",     function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({B=true}) end, 70)
R["DD+A"]        = measure("DD+A",           function()
  press({Down=true}); gap(); press({Down=true}); gap(); press({A=true}) end, 60)

log("")
log(string.format("%-20s | %12s | %10s | %5s", "move", "accion_init", "duraccion", "dmg"))
log("--------------------------------------------------------")
for k,v in pairs(R) do
  log(string.format("%-20s | %12s | %10s | %5d", k, tostring(v.act_start or "-"), tostring(v.act_len or "-"), v.dmg))
end

f:close()
client.exit()