-- =====================================================================
-- sonda_plano.lua  --  ANALISIS COMPLETO DE LOS PLANOS (para FBNeo)
-- =====================================================================
-- QUE HACE (todo en RAM, sin tocar la ROM):
--
--   1) MAPEA LA RAM DEL Z80 (la de $0000-$1FFF) y lista las direcciones
--      que tienen DATOS. La 68000 ve esa RAM en $A00000-$A0FFFF, pero por
--      un bus de 8 bits y con los bits INVERTIDOS (el byte real $01 llega
--      como $FE, el $02 como $FD). Si FBNeo da el API 'z80.read', se usa
--      ese (es el limpio); si no, el de $A00000 con el flip.
--
--   2) BUSCA LA BANDERA DEL PLANO: la direccion de la RAM del Z80 que
--      solo vale 1, 2 o 3 (los valores que usa el juego para el plano) y
--      que CAMBIA entre frames. En el codigo de la 68000 aparece como
--      $A042 (bit 0 = delante, bit 1 = atras).
--
--   3) SIGUE EL ESTADO DE LOS PLANOS: el suelo ($9c), la escala ($3e), el
--      offset del sprite ($26), el HP ($78), el estado ($5d), el move ($5f) y
--      la posicion, de los 4 jugadores.
--
--   4) AVISA DEL "2 CUERPOS": si la bandera del plano tiene los DOS bits
--      a 1 (valor 3) el juego cree que el personaje esta en los dos planos
--      a la vez y dibuja 2 siluetas.
--
-- MODOS (cambialo arriba del todo y recarga el script):
--   MODO = "datos"    solo informa
--   MODO = "forzar1"  FUERZA la bandera del plano a 1 (delante) cada frame
--   MODO = "forzar2"  FUERZA la bandera a 2 (atras)
--   MODO = "forzar3"  FUERZA la bandera a 3 (LOS DOS BITS: el "2 cuerpos")
--   MODO = "daño"     cada 3 frames, si la bandera dice "atras", quita 1
--                     de vida al jugador 1 (escribe en su HP)
--   MODO = "hp1"      pone el HP del jugador 1 en 1 cada frame
-- =====================================================================

local MODO = "datos"          -- <-- cambia aqui
local JUGADOR = 1              -- <-- el slot que controlas (1..4)

local BASE_SLOT = 0xFF8400
local STRIDE = 0x400

local OFF_ESTADO = 0x5D
local OFF_MOVE = 0x5F
local OFF_FRAME = 0x59
local OFF_XMUNDO = 0x40
local OFF_YMUNDO = 0x44
local OFF_PLANO = 0x9C
local OFF_ESCALA = 0x3E
local OFF_OFF26 = 0x26
local OFF_HP = 0x78
local OFF_DIRS = 0x71
local OFF_BOTON = 0x72

local FLAG_PLANO = 0x0042      -- el offset de la bandera en la RAM del Z80
                               -- ($A042 en el espacio de la 68000)

-- ---------------------------------------------------------------------
-- la RAM del Z80
-- ---------------------------------------------------------------------
local USA_Z80 = false

local function prueba_z80()
  if z80 == nil or type(z80.read) ~= "function" then return false end
  local ok, v = pcall(z80.read, 0)
  USA_Z80 = (ok and type(v) == "number")
  return USA_Z80
end

local function z80le(a)
  if USA_Z80 then
    local ok, v = pcall(z80.read, a)
    if ok and type(v) == "number" then return v end
    return 0
  end
  local b = memory.readbyte(0xA00000 + a)
  if type(b) ~= "number" then return 0 end
  return bit.bxor(b, 0xFF)
end

local function z80escribe(a, v)
  if USA_Z80 then
    pcall(z80.write, a, v)
    return
  end
  memory.writebyte(0xA00000 + a, bit.bxor(v, 0xFF))
end

-- ---------------------------------------------------------------------
-- la RAM de la 68000
-- ---------------------------------------------------------------------
local function rb(a)
  local v = memory.readbyte(a)
  if type(v) ~= "number" then return 0xFF end
  return v
end

local function rd16(a)
  return rb(a) * 256 + rb(a + 1)
end

local function rd32(a)
  return rb(a) * 16777216 + rb(a + 1) * 65536 + rb(a + 2) * 256 + rb(a + 3)
end

local function sx(v) return v / 65536.0 end

local function bits2(v)
  local s = ""
  if bit.band(v, 1) ~= 0 then s = s .. "DELANTE " end
  if bit.band(v, 2) ~= 0 then s = s .. "ATRAS " end
  if s == "" then s = "NINGUNO " end
  if bit.band(v, 3) == 3 then s = s .. "<<< LOS DOS: 2 CUERPOS >>>" end
  return s
end

local function botones(v)
  if v == 0 then return "-" end
  local n = { "A", "B", "C", "X", "Y", "Z" }
  local s = ""
  for b = 0, 5 do
    if bit.band(v, 2 ^ b) ~= 0 then
      s = s .. (s ~= "" and "+" or "") .. n[b + 1]
    end
  end
  if bit.band(v, 0x40) ~= 0 then s = s .. (s ~= "" and "+" or "") .. "b6" end
  if bit.band(v, 0x80) ~= 0 then s = s .. (s ~= "" and "+" or "") .. "b7" end
  return s
end

local function dirs(v)
  local n = { "ARRIBA", "ABAJO", "IZQ", "DER" }
  local s = ""
  for b = 0, 3 do
    if bit.band(v, 2 ^ b) ~= 0 then
      s = s .. (s ~= "" and "+" or "") .. n[b + 1]
    end
  end
  if s == "" then return "-" end
  return s
end

local P1 = BASE_SLOT + (JUGADOR - 1) * STRIDE

-- ---------------------------------------------------------------------
-- 1) EL MAPA DE LA RAM DEL Z80 (las 256 primeras direcciones)
-- ---------------------------------------------------------------------
local foto1 = {}

local function escanea_la_ram()
  print("=== MAPA DE LA RAM DEL Z80 ===")
  print(string.format("    hay API z80.read: %s", USA_Z80 and "SI (se usa ese)" or "NO (se usa $A00000 con el flip)"))
  local con_datos = {}
  local candidatas = {}
  for a = 0x0000, 0x00FF do
    local b = z80le(a)
    foto1[a] = b
    if b ~= 0 then
      con_datos[#con_datos + 1] = a
      if b >= 1 and b <= 3 then
        candidatas[#candidatas + 1] = a
      end
    end
  end
  print(string.format("    $0000-$00FF: %d direcciones con datos", #con_datos))
  for i = 1, math.min(#con_datos, 40) do
    local a = con_datos[i]
    print(string.format("      $%04X = $%02X (%3d)", a, z80le(a), z80le(a)))
  end
  print(string.format("    de esas, %d valen 1, 2 o 3 (candidatas a la bandera del plano):",
                      #candidatas))
  for n = 1, math.min(#candidatas, 20) do
    local a = candidatas[n]
    print(string.format("      $%04X = $%02X  %s", a, z80le(a), bits2(z80le(a))))
  end
  if #con_datos == 0 then
    print("    >>> NO SE VE LA RAM DEL Z80 por ninguna via: la bandera del plano")
    print("        no se puede leer desde el Lua (habria que mirar el codigo).")
  end
end

-- compara la foto con la de ahora: las variables "vivas"
local function compara_fotos()
  print("")
  print("=== LAS VARIABLES QUE CAMBIAN (comparando con 60 frames atras) ===")
  local vivas = {}
  local planes = {}
  for a = 0x0000, 0x00FF do
    local v = z80le(a)
    if v ~= foto1[a] then
      vivas[#vivas + 1] = a
      if v >= 1 and v <= 3 then
        planes[#planes + 1] = a
      end
    end
  end
  print(string.format("    %d direcciones han cambiado", #vivas))
  for i = 1, math.min(#vivas, 30) do
    local a = vivas[i]
    print(string.format("      $%04X: $%02X -> $%02X", a, foto1[a], z80le(a)))
  end
  print(string.format("    %d de ellas valen 1/2/3 (CANDIDATAS A LA BANDERA DEL PLANO):",
                      #planes))
  for n = 1, math.min(#planes, 15) do
    local a = planes[n]
    print(string.format("      $%04X = $%02X  <--  %s", a, z80le(a), bits2(z80le(a))))
  end
  print(string.format("    (la bandera del plano en la 68000 es $A042 = el offset $%04X del Z80)",
                      FLAG_PLANO))
  for a = 0x0000, 0x00FF do
    foto1[a] = z80le(a)
  end
end

-- ---------------------------------------------------------------------
-- 2) EL ESTADO DE UN JUGADOR
-- ---------------------------------------------------------------------
local function estado(slot)
  local b = BASE_SLOT + (slot - 1) * STRIDE
  return {
    est = rb(b + OFF_ESTADO),
    mov = rb(b + OFF_MOVE),
    fra = rb(b + OFF_FRAME),
    suelo = sx(rd32(b + OFF_PLANO)),
    esc = rd16(b + OFF_ESCALA),
    off26 = rb(b + OFF_OFF26),
    hp = rd16(b + OFF_HP),
    x = sx(rd32(b + OFF_XMUNDO)),
    y = sx(rd32(b + OFF_YMUNDO)),
    dirs = rb(b + OFF_DIRS),
    bot = rb(b + OFF_BOTON),
  }
end

local function linea_estado(e)
  return string.format(
    "suelo=%7.2f esc=%3d off26=$%02X HP=%3d | estado=$%02X move=$%02X fra=$%02X | X=%7.1f Y=%7.1f | dirs=%-12s bot=%s",
    e.suelo, e.esc, e.off26, e.hp, e.est, e.mov, e.fra,
    e.x, e.y, dirs(e.dirs), botones(e.bot))
end

-- ---------------------------------------------------------------------
-- el bucle principal
-- ---------------------------------------------------------------------
local flag_ult = -1
local tick = 0
local ncambios = 0
local cuenta = {}
local ultimo_est = {}
local nlineas = 0
local MAXLINEAS = 400

local function arranca()
  print("=== yuyu_plano: analisis de los planos ===")
  print(string.format("    modo=%s   jugador=%d ($%06X)", MODO, JUGADOR, P1))
  prueba_z80()
  escanea_la_ram()
  print("")
  print("    los 4 jugadores:")
  for s = 1, 4 do
    print(string.format("      slot %d $%06X  %s", s, BASE_SLOT + (s - 1) * STRIDE,
                         linea_estado(estado(s))))
  end
  print("")
  print("    ahora haz lo que quieras en el juego (cruzar, andar, golpear)")
  print("")
  flag_ult = -1
  tick = 0
  ncambios = 0
  cuenta = {}
  nlineas = 0
end

local function cada_frame()
  tick = tick + 1

  -- 1) la bandera del plano
  local v = z80le(FLAG_PLANO)
  if v ~= flag_ult then
    flag_ult = v
    ncambios = ncambios + 1
    local clave = string.format("$%02X", v)
    cuenta[clave] = (cuenta[clave] or 0) + 1
    print(string.format(
      "[f %5d] *** LA BANDERA DEL PLANO CAMBIA: Z80 $%04X = $%02X  ->  %s",
      tick, FLAG_PLANO, v, bits2(v)))
    for s = 1, 4 do
      print(string.format("      slot %d: %s", s, linea_estado(estado(s))))
    end
    nlineas = nlineas + 5
  end

  -- 2) los modos que ESCRIBEN
  if MODO == "forzar1" or MODO == "forzar2" or MODO == "forzar3" then
    local f = 0
    if MODO == "forzar1" then
      f = 1
    elseif MODO == "forzar2" then
      f = 2
    else
      f = 3
    end
    z80escribe(FLAG_PLANO, f)
  elseif MODO == "daño" then
    if tick % 3 == 0 and bit.band(flag_ult, 2) ~= 0 then
      local e = estado(JUGADOR)
      local hp = e.hp
      if hp > 0 then
        hp = hp - 1
        memory.writebyte(P1 + OFF_HP, bit.band(bit.rshift(hp, 8), 0xFF))
        memory.writebyte(P1 + OFF_HP + 1, bit.band(hp, 0xFF))
        print(string.format("[f %5d] *** DAO: el HP del jugador %d pasa de %d a %d",
                            tick, JUGADOR, e.hp, hp))
      end
    end
  elseif MODO == "hp1" then
    memory.writebyte(P1 + OFF_HP, 0)
    memory.writebyte(P1 + OFF_HP + 1, 1)
  end

  -- 3) los cambios de estado de los jugadores
  for s = 1, 4 do
    local e = estado(s)
    local prev = ultimo_est[s]
    if prev == nil or prev.est ~= e.est or prev.mov ~= e.mov
       or math.abs(prev.suelo - e.suelo) > 0.5 or prev.hp ~= e.hp then
      if nlineas < MAXLINEAS then
        print(string.format("[f %5d] slot %d: %s", tick, s, linea_estado(e)))
        nlineas = nlineas + 1
      end
      ultimo_est[s] = e
    end
  end

  -- 4) la comparacion y el resumen
  if tick % 60 == 35 then
    compara_fotos()
  end
  if tick % 600 == 0 then
    print("")
    print(string.format("=== RESUMEN (frame %d): la bandera del plano ha cambiado %d veces",
                        tick, ncambios))
    for k, c in pairs(cuenta) do
      print(string.format("      valor %s : %d veces", k, c))
    end
    print("")
  end
end

emu.registerstart(arranca)
emu.registerafter(cada_frame)
