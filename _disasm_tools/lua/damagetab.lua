-- damagetab.lua : tabla de dano EXACTA + startup por move, reading the 68000
-- registers. Cuando el PC pasa por 0x19C4E (sub.w d0,$b8(a5) = aplicar dano),
-- D0 contiene el dano exacto. El frame entre input y ese PC = startup.
--
-- Todo automatico, sin intervencion del usuario. Usa modo PRACTICA (dummy quieto).
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\"
local f = assert(io.open(dir .. "damagetab.txt", "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local DMG_PC = 0x19C4E    -- sub.w d0,$b8(a5)

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local S1 = 0xFF8000
local HP1 = S1+0x4B8
local HP4 = 0xFF8C00+0x4B8
local T2  = S1+0x468
local function rd(a) local ok,v=pcall(memory.read_u16_be,a,"M68K BUS"); if ok and type(v)=="number" then return v end return 0 end
local function reg(n)
  local r = emu.getregisters()
  return r and r["M68K "..n] or nil
end
local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end
local function gap() for i=1,4 do emu.frameadvance() end end

-- navegación a modo PRACTICA
log("=== Extrayendo tabla de dano exacta (modo practica) ===")
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
log("en combate. HP1=" .. rd(HP1) .. " HP4=" .. rd(HP4))

-- verificar que el breakpoint PC se puede capturar en reposo (no deberia, HP lleno)
local function capture_damage(frames)
  -- devuelve {dmg=..., frame=...} del primer impacto
  local hp0 = rd(HP4)
  for i=1,frames do
    emu.frameadvance()
    local pc = reg("PC")
    if pc == DMG_PC then
      local d0 = reg("D0")
      -- confirmar que HP bajo en el siguiente frame
      return {dmg = d0, frame = i, pc = pc}
    end
    if rd(HP4) < hp0 then
      -- HP bajo pero no vimos el PC exacto (puede haber pasado entre polls)
      return {dmg = (hp0 - rd(HP4)), frame = i, approx = true}
    end
  end
  return nil
end

-- medir un move
local function measure(name, fn, frames)
  frames = frames or 60
  -- esperar reposo
  local g=0 while rd(T2) ~= 0 and g<200 do emu.frameadvance(); g=g+1 end
  -- acercar al dummy
  local pos = S1+0x26C
  local prev = rd(pos); local stuck=0
  for s=1,40 do
    press({Right=true})
    local p = rd(pos); if p==prev then stuck=stuck+1 else stuck=0 end; prev=p
    if stuck>=3 then break end
  end
  idle(8)
  local hp0 = rd(HP4)
  local inp_start = emu.framecount()
  fn()
  local inp = emu.framecount() - inp_start
  -- ahora capturar: el input ya fue aplicado, capturamos desde aqui
  -- pero el impacto puede venir DESPUES del input, buscamos PC==0x19C4E
  local dmg = nil; local hitframe = nil
  for i=1,frames do
    emu.frameadvance()
    local pc = reg("PC")
    if pc == DMG_PC then
      local d0 = reg("D0")
      if d0 and d0 > 0 and d0 < 300 then
        dmg = d0
        hitframe = inp + i   -- frames desde el inicio del input
        break
      end
    end
  end
  -- fallback: si HP bajo pero no capturamos el PC exacto
  if dmg == nil and rd(HP4) < hp0 then
    dmg = hp0 - rd(HP4)
  end
  if dmg then
    log(string.format("%-22s | startup=%-5s | DANO=%-4d | PC-capturado=%s",
      name, tostring(hitframe or "?"), dmg, tostring(hitframe ~= nil)))
  else
    log(string.format("%-22s | SIN IMPACTO", name))
  end
  return dmg, hitframe
end

log("")
log(string.format("%-22s | %8s | %6s | %s", "move", "startup", "dano", "nota"))
log("---------------------------------------------------------------")

-- personajes: por ahora el que esta en combate (Yusuke). Los demas requieren
-- cambiar de personaje en el select (se documenta como cambiar).
local R = {}
R["A parado"]       = measure("A parado (fuerte)",   function() press({A=true}) end)
R["B parado"]       = measure("B parado (ligero)",  function() press({B=true}) end)
R["abajo+A"]        = measure("abajo+A",             function() press({Down=true}); gap(); press({A=true}) end)
R["abajo+B"]        = measure("abajo+B",             function() press({Down=true}); gap(); press({B=true}) end)
R[">+A (agarre)"]    = measure("->+A agarre",         function() press({Right=true}); gap(); press({A=true}) end)
R["->+B"]           = measure("->+B",                function() press({Right=true}); gap(); press({B=true}) end)
R["Reimu QCF+A"]    = measure("Reimu QCF+A",         function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({A=true}) end, 70)
R["Reimu QCF+B"]    = measure("Reimu QCF+B",         function()
  press({Down=true}); gap(); press({Down=true,Right=true}); gap(); press({Right=true}); gap(); press({B=true}) end, 70)
R["DD+A (escop.)"]  = measure("DD+A escopetazo",     function()
  press({Down=true}); gap(); press({Down=true}); gap(); press({A=true}) end, 60)
R["DD+B"]           = measure("DD+B",                function()
  press({Down=true}); gap(); press({Down=true}); gap(); press({B=true}) end, 60)

log("")
log("=== RESUMEN (personaje actual) ===")
for k,v in pairs(R) do
  log(string.format("  %-20s dano=%s", k, tostring(v.dmg or "?")))
end

f:close()
client.exit()