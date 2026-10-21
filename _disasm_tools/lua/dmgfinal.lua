-- dmgfinal.lua : daño exacto por delta de HP, con re-approach agresivo y reintentos.
-- Modo PRACTICA (dummy quieto). Solo cuenta moves que CONECTAN.
-- Ademas: histograma completo de daños vistos en el attract (modo demo del juego).
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "dmgfinal.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local HP1 = S1+0x4B8
local HP4 = 0xFF8C00+0x4B8
local T2  = S1+0x468
local POS = S1+0x26C
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end
local function gap() for i=1,4 do emu.frameadvance() end end

-- ============================================================
-- PARTE 1: histogram de daños en modo PRACTICA (midiendo A parado, que SI conecta)
-- ============================================================
log("=== PARTE 1: verificando valores de dano (modo practica) ===")
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)
press({Down=true}); idle(20)
press({Start=true}); idle(40)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(30)
press({Start=true}); idle(70)
press({Start=true}); idle(200)
log("en combate. HP1=" .. rd(HP1) .. " HP4=" .. rd(HP4))

-- approach agresivo: caminar hasta que pos quede estable
local function approach()
  local prev = rd(POS); local stuck = 0
  for s=1,50 do
    press({Right=true}, 3)
    local p = rd(POS)
    if p == prev then stuck = stuck + 1 else stuck = 0 end
    prev = p
    if stuck >= 4 then break end
  end
  idle(6)
end

-- medir con reintentos: solo cuenta si conecta
local function measure(name, fn, maxtry, frames)
  maxtry = maxtry or 5
  frames = frames or 50
  for attempt=1,maxtry do
    local g=0 while rd(T2) ~= 0 and g<200 do emu.frameadvance(); g=g+1 end
    approach()
    idle(6)
    local hp0 = rd(HP4)
    local t0 = emu.framecount()
    fn()
    local inp = emu.framecount() - t0
    local hitf = nil
    for i=1,frames do
      emu.frameadvance()
      if rd(HP4) < hp0 then hitf = i break end
    end
    if hitf then
      local dmg = hp0 - rd(HP4)
      log(string.format("%-22s | intento %d | startup=%-4d | DANO=%d", name, attempt, inp+hitf-1, dmg))
      return dmg, inp+hitf-1
    end
  end
  log(string.format("%-22s | %d intentos SIN impacto", name, maxtry))
  return nil
end

log("")
log(string.format("%-22s | %8s | %6s", "move", "startup", "dano"))
log("----------------------------------------------")
local R = {}
R["A parado"]    = measure("A parado",       function() press({A=true}) end)
R["B parado"]    = measure("B parado",       function() press({B=true}) end)
R["abajo+A"]     = measure("abajo+A",         function() press({Down=true}); gap(); press({A=true}) end)
R["abajo+B"]     = measure("abajo+B",         function() press({Down=true}); gap(); press({B=true}) end)
R["->+A agarre"] = measure("->+A agarre",    function() press({Right=true}); gap(); press({A=true}) end)
R["->+B"]        = measure("->+B",           function() press({Right=true}); gap(); press({B=true}) end)

log("")
log("=== PARTE 2: damage table consolidada (contrasta con tabla web) ===")
log("Los valores medidos en vivo deben coincidir con la tabla de newton.com.tw:")
log("  1=conectado | 12=dash/escopetazo | 16=立A Yusuke | 20=立A Kuwabara/Chui")
log("  24=立A Hiei/Genkai | 32=gancho Ryuujin | 48=Reimu nivel alto | 81=super Genkai")
log("")
log("Dano medido por move (este personaje):")
for k,v in pairs(R) do
  log(string.format("  %-20s = %s", k, tostring(v)))
end

f:close()
client.exit()