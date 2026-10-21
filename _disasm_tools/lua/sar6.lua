-- sar6.lua : S/A/R preciso usando el TIMER +0x47A (decrementa 1/frame).
--
-- Hallazgo clave: en el player struct, el offset +0x47A es un contador que
-- decremIENTA 1 por frame mientras el personaje ejecuta un move (0xDF->0xDE->...).
-- Marca exactamente el estado de "en recuperacion / stun-timer".
-- +0x468 tambien decremienta (0xF->0xE->0xD...) - segundo timer.
-- +0x188 incrementa (frame counter global).
--
-- Procedimiento por move:
--   - input en frame conocido
--   - startup = frames hasta que +0x47A empieza a decrementar
--   - recovery = frames que +0x47A sigue decrementando
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar6.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local T1  = S1+0x47A   -- timer principal (decrementa)
local T2  = S1+0x468   -- timer secundario
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

log("=== S/A/R via timer +0x47A ===")
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
log("en combate")

-- medir: ejecutar move, y medir +0x47A desde el input
local function measure(name, fn, obs)
  obs = obs or 70
  idle(45)  -- que se recupere del move anterior
  local t_start = rd(T1)
  local hp0 = rd(HP4)
  local seq = {}
  local startf = emu.framecount()
  -- ejecutar el input capturando el timer CADA frame
  local input_frame = -1
  local fn2 = fn  -- fn ejecuta con emu.frameadvance interno
  -- captura manual: envolvemos emu.frameadvance? no se puede.
  -- Alternativa: medimos el timer justo despues del input y luego seguimos.
  fn2()
  input_frame = emu.framecount() - startf   -- frames que duro el input
  seq[0] = { f=input_frame, t=rd(T1), hp=rd(HP4) }
  for i=1,obs do
    emu.frameadvance()
    seq[i] = { f=input_frame+i, t=rd(T1), hp=rd(HP4) }
  end
  -- analisis
  local startup = nil; local recov_end = nil
  local dec = 0
  for i=1,#seq do
    if i>1 and seq[i].t < seq[i-1].t then
      dec = dec + 1
      if not startup then startup = seq[i].f end
      recov_end = seq[i].f
    end
  end
  local hit=nil; for i=1,#seq do if seq[i].hp < hp0 then hit=i break end end
  local recov = (startup and recov_end) and (recov_end - startup + 1) or nil
  local res = {startup=startup, recov=recov, hit=hit, dmg=(hit and (hp0-seq[hit].hp) or 0), decframes=dec}
  log(string.format("%-20s | inp=%2d | startup=%-4s | recov=%-4s | hit@%-4s | dmg=%3d | decframes=%d",
    name, input_frame, tostring(startup or "-"), tostring(recov or "-"), tostring(hit or "-"), res.dmg, dec))
  return res
end

local R = {}
R["A parado"]      = measure("A parado",       function() press({A=true}) end)
R["abajo+A"]       = measure("abajo+A",        function() press({Down=true}); for i=1,GAP do emu.frameadvance() end; press({A=true}) end)
R["B parado"]      = measure("B parado",       function() press({B=true}) end)
R["abajo+B"]       = measure("abajo+B",        function() press({Down=true}); for i=1,GAP do emu.frameadvance() end; press({B=true}) end)
R[">+A agarre"]    = measure("->+A agarre",    function() press({Right=true}); for i=1,GAP do emu.frameadvance() end; press({A=true}) end)
R["->+B"]          = measure("->+B",           function() press({Right=true}); for i=1,GAP do emu.frameadvance() end; press({B=true}) end)
R["Reimu QCF+A"]   = measure("Reimu QCF+A",     function()
   press({Down=true}); for i=1,GAP do emu.frameadvance() end
   press({Down=true,Right=true}); for i=1,GAP do emu.frameadvance() end
   press({Right=true}); for i=1,GAP do emu.frameadvance() end
   press({A=true}) end, 90)
R["Reimu QCF+B"]   = measure("Reimu QCF+B",     function()
   press({Down=true}); for i=1,GAP do emu.frameadvance() end
   press({Down=true,Right=true}); for i=1,GAP do emu.frameadvance() end
   press({Right=true}); for i=1,GAP do emu.frameadvance() end
   press({B=true}) end, 90)
R["DD+A escopetazo"] = measure("DD+A",         function()
   press({Down=true}); for i=1,GAP do emu.frameadvance() end
   press({Down=true}); for i=1,GAP do emu.frameadvance() end
   press({A=true}) end)

log("")
log(string.format("%-20s | %8s | %8s | %7s | %6s", "move", "startup", "recovery", "hit@f", "dmg"))
log("--------------------------------------------------------------")
for k,v in pairs(R) do
  log(string.format("%-20s | %8s | %8s | %7s | %6d", k, tostring(v.startup or "-"), tostring(v.recov or "-"), tostring(v.hit or "-"), v.dmg))
end

f:close()
client.exit()