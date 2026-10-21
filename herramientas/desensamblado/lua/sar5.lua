-- sar5.lua : S/A/R por personaje, con reposicionado y ventana amplia.
-- Aprendido: pos1 fluctua (196 <-> 2124) = a veces fuera de rango.
-- Solucion: verificar closeness antes de medir, ventana de 90 frames,
-- y detectar el hit por cambio de HP4 (no por pos).
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "sar5.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1, S4 = 0xFF8000, 0xFF8C00
local HP1, HP4 = S1+0x4B8, S4+0x4B8
local POS1 = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

local BTN = 5
local GAP = 4

log("=== S/A/R con reposicionado ===")

-- navegar
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
log("en combate HP1=" .. rd(HP1) .. " HP4=" .. rd(HP4))

-- POSIX real: buscar el offset de posicion comparando durante caminata
local function find_pos_offset()
  local p0 = rd(POS1)
  for i=1,12 do press({Right=true}) end
  local p1 = rd(POS1)
  for i=1,12 do press({Left=true}) end
  local p2 = rd(POS1)
  log(string.format("pos candidate @+0x26C: %d -> %d -> %d", p0, p1, p2))
  return (p0 ~= p1)
end
find_pos_offset()

-- medir: reposiciona, ejecuta, observa 90 frames
local function measure(name, fn, total)
  total = total or 90
  -- reposicionar: caminar hasta que pos se estabilice (pegado al rival)
  local prev = rd(POS1); local stuck = 0
  for s=1,60 do
    press({Right=true})
    local p = rd(POS1)
    if p == prev then stuck = stuck + 1 else stuck = 0 end
    prev = p
    if stuck >= 3 then break end
  end
  idle(20)
  local hp0 = rd(HP4)
  local pos0 = rd(POS1)
  local startf = emu.framecount()
  fn()
  local inp_frames = emu.framecount() - startf
  local hits = {}
  for i=1,total do
    emu.frameadvance()
    if rd(HP4) < hp0 then
      table.insert(hits, {f=inp_frames+i-1, hp=rd(HP4)})
    end
  end
  local res = {inp=inp_frames, dmg=0, sa=nil, recov=nil, nhits=#hits}
  if #hits > 0 then
    res.sa = hits[1].f
    res.dmg = hp0 - hits[#hits].hp
    -- recovery: cuando P1 puede moverse de nuevo
    for r=1,80 do
      local pb = rd(POS1)
      press({Right=true})
      if rd(POS1) ~= pb then res.recov = r break end
    end
  end
  log(string.format("%-20s | inp=%2d | startup=%-5s | hits=%d | dmg=%3d | recov=%s | pos0=%d",
    name, res.inp, tostring(res.sa or "-"), res.nhits, res.dmg, tostring(res.recov or "-"), pos0))
  return res
end

log("")
log(string.format("%-20s | %5s | %9s | %6s | %5s | %6s | %6s", "move", "inp", "startup", "hits", "dmg", "recov", "pos0"))
log("------------------------------------------------------------------------------------------------------------------")

local R = {}
R["A parado"]     = measure("A parado",        function() press({A=true}) end)
R["A agachado"]   = measure("abajo+A",         function() press({Down=true}); for i=1,GAP do emu.frameadvance() end; press({A=true}) end)
R["B parado"]     = measure("B parado",        function() press({B=true}) end)
R["B agachado"]   = measure("abajo+B",         function() press({Down=true}); for i=1,GAP do emu.frameadvance() end; press({B=true}) end)
R[">+A AGARRE"]   = measure("->+A agarre",     function() press({Right=true}); for i=1,GAP do emu.frameadvance() end; press({A=true}) end)
R["Reimu QCF+A"]  = measure("Reimu QCF+A",      function()
    press({Down=true}); for i=1,GAP do emu.frameadvance() end
    press({Down=true,Right=true}); for i=1,GAP do emu.frameadvance() end
    press({Right=true}); for i=1,GAP do emu.frameadvance() end
    press({A=true}) end, 110)
R["Reimu QCF+B"]  = measure("Reimu QCF+B",      function()
    press({Down=true}); for i=1,GAP do emu.frameadvance() end
    press({Down=true,Right=true}); for i=1,GAP do emu.frameadvance() end
    press({Right=true}); for i=1,GAP do emu.frameadvance() end
    press({B=true}) end, 110)
R["DD+A (escop.)"] = measure("DD+A escopetazo", function()
    press({Down=true}); for i=1,GAP do emu.frameadvance() end
    press({Down=true}); for i=1,GAP do emu.frameadvance() end
    press({A=true}) end, 90)

log("")
log("fin")

f:close()
client.exit()