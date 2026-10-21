-- capt11b.lua : captura los 11 personajes en la pantalla CHARACTER SELECT.
-- Path verificado (de n5): title -> START -> Game Start -> modo torneo
--   -> ENTRY (P1 auto, P2..P4 CPU) -> [AQUI char select con los 11]
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\shots\\"
local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)

local function press(tbl, hold)
  joypad.set(tbl, 1)
  for i=1,(hold or 5) do emu.frameadvance() end
  joypad.set({}, 1)
  for i=1,3 do emu.frameadvance() end
end
local function idle(n) for i=1,n do emu.frameadvance() end end

local NOMBRES = {'sensui','jin','itsuki','genkai','kuwabara','yusuke','kurama','hiei','chui','toguromayor','toguromenor'}

-- Path VERIFICADO (de n5_02 que llego a la pantalla de 11):
--   title -> START -> Game Start -> modo torneo -> [Right, Start] UNA VEZ
--   = llega al CHARACTER SELECT con los 11 retratos
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)            -- title
press({Start=true}); idle(40)            -- Game Start
press({Start=true}); idle(50)            -- modo de juego
press({Right=true}); idle(10)
press({Start=true}); idle(25)            -- <- aqui aparece la pantalla de 11
idle(15)
pcall(function() client.screenshot(dir .. "charselect_ALL.png") end)

-- Recorrer los 11: el cursor arranca en el primero (1P). Mover RIGHT captura cada uno.
-- Nota: en esta pantalla el 1P selecciona su personaje, luego 2P, etc.
-- Capturamos el estado del cursor en cada posicion.
for i=0,10 do
  pcall(function() client.screenshot(dir .. string.format("cs_pos%02d.png", i+1)) end)
  press({Right=true}, 3)
  idle(8)
end

-- Final: seleccionar 1P (primer personaje) y entrar a combate
-- Volver al inicio del cursor y confirmar
for i=1,12 do press({Left=true},2); idle(4) end
press({A=true}, 4); idle(15)
pcall(function() client.screenshot(dir .. "cs_confirmado.png") end)

f = io.open(dir .. "capt11b.txt", "w")
f:write("OK: capturas del character select generadas\n")
f:close()
client.exit()