-- capt11.lua : captura los 11 personajes.
-- 1) Pantalla de seleccion de personaje (muestra los 11 retratos en fila)
-- 2) Cada personaje en combate (uno por uno)
-- Genera una captura por personaje.
local dir = "C:\\Users\\leand\\Downloads\\emuladores\\shots\\"
-- crear carpeta
local function mkdir(p) end  -- Lua no crea; PowerShell la crea antes

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

-- nombres de los 11 personajes en orden de seleccion
local NOMBRES = {'sensui','jin','itsuki','genkai','kuwabara','yusuke','kurama','hiei','chui','toguromayor','toguromenor'}

-- ir a la pantalla de SELECCION DE PERSONAJE (11 retratos)
while emu.framecount() < 450 do emu.frameadvance() end
press({Start=true}); idle(40)
press({Start=true}); idle(40)
press({Start=true}); idle(50)          -- modo de juego
press({Right=true}); idle(8); press({Start=true}); idle(20)   -- P2 CPU
press({Right=true}); idle(8); press({Start=true}); idle(20)
press({Right=true}); idle(8); press({Start=true}); idle(25)
-- ahora deberiamos ver la pantalla de char select con los 11
idle(20)
pcall(function() client.screenshot(dir .. "01_charselect_11.png") end)

-- recorrer los 11 personajes con Right, capturando cada uno (cursor + retrato)
for i=1,11 do
  pcall(function() client.screenshot(dir .. string.format("sel_%02d_%s.png", i, NOMBRES[i])) end)
  press({Right=true}, 3)
  idle(6)
end
pcall(function() client.screenshot(dir .. "02_charselect_11b.png") end)

f = io.open(dir .. "capt11.txt", "w")
f:write("capturas de los 11 personajes generadas\n")
f:close()

client.exit()