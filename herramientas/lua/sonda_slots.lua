-- =====================================================================
-- sonda_slots.lua  --  QUE SLOT ES CADA PERSONAJE (para FBNeo/Fightcade)
-- =====================================================================
-- QUE HACE:
--
--   1) ESCANEA la RAM ($FF8000-$FFBFFF, cada $100) y busca los que
--      parecen un personaje CON VIDA: el HP ($78) entre 1 y 223, el suelo
--      ($9c) a 320 o 304, la escala ($3e) a 256 o 216 y la tabla de moves
--      ($8c) apuntando al banco 1 ($0Cxxxx). Con eso los falsos positivos
--      son practicamente nulos.
--
--   2) DICE CUAL ES EL P1 y CUAL EL P2 (y el del rival de la CPU), con la
--      direccion del HP de cada uno. OJO: el puntero A5 del personaje (lo
--      que usa el codigo para saber a quien pertenece) es (HP - $78).
--      O sea: si el HP del P2 esta en $FF9078, su A5 es $FF9000.
--
--   3) SIGUE el HP de cada personaje y AVISA si baja 1 por frame mientras
--      el suelo es 304: ESO ES EL VENENO, y dice de quien es.
--
--   4) MODOS (cambialo arriba del todo y recarga el script):
--        MODO = "datos"   solo informa
--        MODO = "veneno"  avisa de quien sufre el veneno
--        MODO = "hp1"     pone el HP del slot OBJETIVO a 1 cada frame
--                        (para probar que pasa al quedarse sin vida:
--                        si vuelve al plano principal y si muere)
--
--   OBJETIVO: el numero de la lista de personajes (1 = el primero, que es el
--   P1) o 0 = el P1. En el modo "hp1" el P1 se puede dejar a 1.
--
-- NOTA: la RAM del Z80 (y el flag del plano, $A042) NO se puede leer desde
-- el Lua. El plano se deduce del suelo ($9c): 320 = delante, 304 = atras.
-- =====================================================================

local MODO = "datos"          -- <-- cambia aqui: "datos" | "veneno" | "hp1"
local OBJETIVO = 0            -- <-- el personaje al que poner el HP a 1

local RAM_INI = 0xFF8000
local RAM_FIN = 0xFFC000
local PASO = 0x100

local OFF_HP = 0x78
local OFF_PLANO = 0x9C
local OFF_ESCALA = 0x3E
local OFF_ESTADO = 0x5D
local OFF_MOVE = 0x5F
local OFF_TABLA = 0x8C
local OFF_X = 0x40
local OFF_Y = 0x44

local MAXLINEAS = 60

-- ---------------------------------------------------------------------
-- la RAM
-- ---------------------------------------------------------------------
local function rb(a)
  local ok, v = pcall(memory.readbyte, a)
  if ok and type(v) == "number" then return v end
  return 0
end

local function rw(a)
  local ok, v = pcall(memory.readword, a)
  if ok and type(v) == "number" then return v end
  return 0
end

-- ---------------------------------------------------------------------
-- un slot parece un personaje?
-- ---------------------------------------------------------------------
local function parece_slot(base)
  local hp = rw(base + OFF_HP)
  if hp < 1 or hp > 223 then return false end
  local suelo = rw(base + OFF_PLANO)
  if suelo ~= 320 and suelo ~= 304 then return false end
  local esc = rw(base + OFF_ESCALA)
  if esc ~= 256 and esc ~= 216 then return false end
  local tabla = rw(base + OFF_TABLA)
  if tabla < 0x0C0000 or tabla > 0x0DFFFF then return false end
  return true
end

local function escanea()
  local lista = {}
  for base = RAM_INI, RAM_FIN - 0x400, PASO do
    if parece_slot(base) then
      lista[#lista + 1] = base
    end
  end
  return lista
end

local function datos_de(base)
  local suelo_h = rw(base + OFF_PLANO)
  local suelo_l = rw(base + OFF_PLANO + 2)
  return {
    base = base,
    hp = rw(base + OFF_HP),
    suelo = suelo_h + suelo_l / 65536.0,
    esc = rw(base + OFF_ESCALA),
    est = rb(base + OFF_ESTADO),
    mov = rb(base + OFF_MOVE),
    x = rw(base + OFF_X),
    y = rw(base + OFF_Y),
    tabla = rw(base + OFF_TABLA),
  }
end

-- ---------------------------------------------------------------------
-- el estado
-- ---------------------------------------------------------------------
local slots = {}
local ultimo = {}
local avisado = {}
local avisado_veneno = {}
local nlineas = 0
local tick = 0

local function dice(s)
  if nlineas >= MAXLINEAS then return end
  print(s)
  nlineas = nlineas + 1
end

local function arranca()
  slots = escanea()
  print("=====================================================================")
  print("SONDA DE SLOTS: los personajes con vida que hay en la RAM")
  print("=====================================================================")
  if #slots == 0 then
    print("  (ninguno: todavia no hay partida, o los slots no tienen vida)")
    print("  (arranca una partida y recarga el script)")
    return
  end
  for i, base in ipairs(slots) do
    local d = datos_de(base)
    print(string.format(
      "  %d) slot $%06X   A5 = $%06X   HP=%3d   suelo=%.2f   escala=%3d   estado=$%02X  move=$%02X   x=%d y=%d   tabla=$%06X%s",
      i, base, base, d.hp, d.suelo, d.esc, d.est, d.mov, d.x, d.y, d.tabla,
      (base == 0xFF8400 and "   <-- el P1 (fijo)" or "")))
  end
  print("")
  print("  El A5 de cada personaje es el slot (el HP esta en A5+$78).")
  print("  El que NO es el P1 puede ser el P2 o el rival de la CPU.")
  print("  Modo: " .. MODO .. "   objetivo: " .. OBJETIVO)
  print("=====================================================================")
  nlineas = 0
end

local function cada_frame()
  tick = tick + 1

  -- el modo "hp1": deja al personaje objetivo con 1 de vida
  if MODO == "hp1" then
    local base = nil
    if OBJETIVO == 0 then
      base = 0xFF8400
    elseif slots[OBJETIVO] then
      base = slots[OBJETIVO]
    end
    if base then
      pcall(memory.writebyte, base + OFF_HP, 0)
      pcall(memory.writebyte, base + OFF_HP + 1, 1)
    end
  end

  for i, base in ipairs(slots) do
    local d = datos_de(base)
    local prev = ultimo[i]
    if prev then
      -- el veneno: baja 1 por frame con el suelo en el plano de atras
      if d.hp == prev.hp - 1 and math.abs(d.suelo - 304) < 1 then
        if not avisado_veneno[i] then
          avisado_veneno[i] = true
          dice(string.format("[f %5d] VENENO en el personaje %d (slot $%06X): el HP baja 1 por frame en el plano de atras",
                             tick, i, base))
        end
      elseif d.hp ~= prev.hp then
        avisado_veneno[i] = nil
        if nlineas < MAXLINEAS then
          dice(string.format("[f %5d] personaje %d (slot $%06X): HP %d -> %d   suelo=%.2f  estado=$%02X  move=$%02X",
                             tick, i, base, prev.hp, d.hp, d.suelo, d.est, d.mov))
          nlineas = nlineas + 1
        end
      end
      -- el cambio de plano
      if math.abs(d.suelo - prev.suelo) >= 1 and nlineas < MAXLINEAS then
        dice(string.format("[f %5d] personaje %d (slot $%06X): el suelo %.2f -> %.2f   (estado=$%02X move=$%02X)",
                           tick, i, base, prev.suelo, d.suelo, d.est, d.mov))
        nlineas = nlineas + 1
      end
    end
    ultimo[i] = d
  end
end

emu.registerstart(arranca)
emu.registerafter(cada_frame)
