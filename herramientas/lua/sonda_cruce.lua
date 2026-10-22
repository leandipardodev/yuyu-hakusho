-- =====================================================================
-- sonda_cruce.lua  --  DIAGNOSTICO DEL CRUCE DE PLANOS
-- =====================================================================
-- QUE HACE:
--   1) Al arrancar, LEE LA ROM y te dice QUE BOTON dispara cada atajo
--      (leyendo el numero de bit de los 'btst.b #n, $72(a5)' del bloque
--      'C o Y' de los 11 dispatchers por personaje, y del atajo global).
--   2) Cada frame guarda en un historial los BOTONES y las DIRECCIONES
--      que estas pulsando (con nombre), y los imprime cuando cambian.
--   3) Cuando se CRUZA, vuelca el HISTORIAL de los ultimos frames:
--      asi ves EXACTAMENTE que boton habias pulsado en el frame que
--      lanzo el cruce.
--
-- COMO SE USA (FBNeo):
--   Game > Lua Scripting > New Lua Script Window > Browse > este fichero
--   JUGADOR = el slot donde controlas vos (1..4).
--   MODO    = "cambios" (solo imprime cuando cambian los botones)
--             "todos"   (imprime cada frame)
--
-- NO escribe nada en la memoria del juego.
--
-- LECTURA DE LA ROM: el Mega Drive mapea la ROM en el espacio de la 68000
-- (misma direccion = mismo offset), asi que memory.readbyte(0x016106)
-- lee el byte de la ROM. Si en tu emulador eso no funciona, el apartado
-- 1 saldra con '???' y el resto del script sigue sirviendo.
-- =====================================================================

local JUGADOR = 1            -- <-- 1..4
local MODO    = "cambios"   -- <-- "cambios" o "todos"

-- ---------------------------------------------------------------------
-- la memoria del juego
-- ---------------------------------------------------------------------
local BASE_SLOT = 0xFF8400   -- el struct del jugador 1 (en la RAM de la 68000)
local STRIDE    = 0x400      -- el tamano de cada struct (4 jugadores)

local OFF_ESTADO = 0x5D      -- el estado (la tabla de handlers)
local OFF_MOVE   = 0x5F      -- el move / animacion
local OFF_FRAME  = 0x59
local OFF_DUR    = 0x5A
local OFF_XMUNDO = 0x40
local OFF_YMUNDO = 0x44
local OFF_PLANO  = 0x9C      -- el suelo del plano en el que esta
local OFF_ESCALA = 0x3E
local OFF_DIRS   = 0x71      -- las direcciones
local OFF_BOTON  = 0x72      -- los botones de ESTE frame
local OFF_BOTMA  = 0x73      -- los botones MANTENIDOS
local OFF_VX     = 0x10
local OFF_VY     = 0x14
local OFF_HP     = 0x78

-- el flag GLOBAL del plano ($A042, en la RAM del Z80):
--   bit 0 = "plano de delante (320)"   bit 1 = "plano de atras (304)"
local FLAG_PLANO = 0xA042

local EST_CRUCE  = 0x0A      -- el estado de la VUELTA del cruce
local EST_CAIDA  = 0x0B      -- el estado de la CAIDA (la ida al otro plano)
local MOVE_CRUCE = 0x0F      -- el move de la ida
local MOVE_VUELTA = 0x10     -- el move de la vuelta

-- los floors (suelos) de los dos planos: 320 = el de delante, 304 = el de atras
local PLANO_DELANTE = 320
local PLANO_ATRAS   = 304

-- los moves que son "cambio de plano" (los que lanza el atajo de mando)
local MOVES_CRUCE = { [0x0F] = true, [0xAA] = true, [0xA8] = true }

-- los moves que lanza el "atajo" del bloque 'C o Y' de los dispatchers
-- (sacado del codigo: el btst del bit 4 -> $80/$81/$84, el del bit 6 -> $82/$86)
local NOMBRE_MOVE = {
  [0x80] = "atajo(bot 4, sin direccion)",
  [0x81] = "atajo(bot 4 + ARRIBA)  <-- el 'atajo de arriba+C'",
  [0x82] = "atajo(bot 6, sin direccion)",
  [0x83] = "ataque (crea el proyectil)",
  [0x84] = "atajo(bot 4 + ABAJO+DER)",
  [0x85] = "atajo(?)",
  [0x86] = "atajo(bot 6 + ABAJO+DER)",
  [0x0A] = "el CRUCE (el estado de la VUELTA)",
  [0x0B] = "el CRUCE (el estado de la CAIDA)",
  [0x0F] = "el CRUCE (move de la IDA)",
  [0x10] = "el CRUCE (move de la VUELTA)",
}

local function nombre_move(m)
  return NOMBRE_MOVE[m] or ""
end

-- ---------------------------------------------------------------------
-- los nombres de los botones (el mapa se deduce del codigo; el Lua lo
-- comprueba empiricamente: si pulsas un boton y sale otro, avisame)
-- ---------------------------------------------------------------------
local NOMBRE_BOT = { "A", "B", "C", "X", "Y", "Z" }
local NOMBRE_DIR = { "ARRIBA", "ABAJO", "IZQ", "DER" }

-- ---------------------------------------------------------------------
-- lecturas
-- ---------------------------------------------------------------------
local function rb(a)
  local v = memory.readbyte(a)
  if v == nil then return 0xFF end
  return bit.band(v, 0xFF)
end

local function rd16(a)
  return rb(a) * 256 + rb(a + 1)
end

local function rd32(a)
  return rb(a) * 16777216 + rb(a + 1) * 65536 + rb(a + 2) * 256 + rb(a + 3)
end

local function sx(v)
  return v / 65536.0
end

local function hex8(v) return string.format("%02X", v) end

-- los botones de un byte, con nombre
local function botones(v)
  if v == 0 then return "-" end
  local s = ""
  for b = 0, 5 do
    if bit.band(v, 2 ^ b) ~= 0 then
      s = s .. (s ~= "" and "+" or "") .. (NOMBRE_BOT[b + 1] or ("bit" .. b))
    end
  end
  if bit.band(v, 0x40) ~= 0 then s = s .. (s ~= "" and "+" or "") .. "bit6" end
  if bit.band(v, 0x80) ~= 0 then s = s .. (s ~= "" and "+" or "") .. "bit7" end
  return s
end

-- las direcciones (los 4 bits bajos)
local function direcciones(v)
  local d = bit.band(v, 0x0F)
  if d == 0 then return "-" end
  local s = ""
  for b = 0, 3 do
    if bit.band(d, 2 ^ b) ~= 0 then
      s = s .. (s ~= "" and "+" or "") .. NOMBRE_DIR[b + 1]
    end
  end
  return s
end

local P1 = BASE_SLOT + (JUGADOR - 1) * STRIDE

-- ---------------------------------------------------------------------
-- 1) EL ANALISIS DE LA ROM: que boton dispara cada atajo
-- ---------------------------------------------------------------------
-- el 'btst.b #n, $72(a5)' son 6 bytes:
--    08 2D <n:word> 00 72
-- el inmediato es un WORD = el NUMERO DE BIT que se prueba.
-- el 'bne.w' que va justo detras son 4 bytes:
--    66 00 <despl:word>   y el destino = (dir + 2) + despl
local function buscar_atajos()
  local res = {}
  local n = 0
  for h = 0x016000, 0x018400 do
    if rb(h) == 0x08 and rb(h + 1) == 0x2D and rb(h + 4) == 0x00 and rb(h + 5) == 0x72 then
      local b = h + 6
      if rb(b) == 0x66 and rb(b + 1) == 0x00 then
        local dest = (b + 2) + rb(b + 2) * 256 + rb(b + 3)
        -- el destino pone: primero el estado ('1B 7C 00 xx 00 5D', 6 bytes)
        -- y despues el move  ('1B 7C 00 yy 00 5F', 6 bytes)
        local mov = nil
        if rb(dest + 6) == 0x1B and rb(dest + 7) == 0x7C and rb(dest + 10) == 0x00 and rb(dest + 11) == 0x5F then
          mov = rb(dest + 8) * 256 + rb(dest + 9)
        end
        local bitnum = rb(h + 2) * 256 + rb(h + 3)
        local clave = bitnum .. "/" .. dest
        if not res[clave] then
          res[clave] = true
          n = n + 1
          print(string.format("   $%06X  prueba el BIT %d de $72(a5)  ->  $%06X  (el MOVIMIENTO $%s)",
                              h, bitnum, dest, mov and string.format("%02X", mov) or "??"))
        end
      end
    end
  end
  print(string.format("   (%d combinaciones distintas en los 11 dispatchers por personaje)", n))
end

local function analizar_rom()
  print("=== QUE BOTON DISPARA CADA ATAJO (leido de la ROM) ===")
  if rb(0x016106) ~= 0x08 then
    print("   ?? no puedo leer la ROM desde el emulador (sigue valiendo el resto)")
    print("")
    return
  end
  print("   los atajos por personaje (los 22 'btst' del bloque 'C o Y'):")
  buscar_atajos()
  print("   el ATAJO GLOBAL (los 3 botones a la vez), en $015DEE:")
  local imm = rb(0x015DF1)
  print(string.format("      'cmpi.b #$%02X, d0'   ->  el BOTON %s   (d0 = $73(a5) & #$70)  ->  el MOVIMIENTO $14",
                      imm, botones(imm)))
  print("   los 'btst' del BIT 5 (el que lanza los moves $AA y $A8):")
  for _, a in ipairs({ 0x01A50C, 0x01A534, 0x01B434, 0x01BCD0,
                       0x01C00A, 0x01C2A6, 0x01C46A, 0x01C494 }) do
    print(string.format("      $%06X  'btst.b #$%02X, $72(a5)'", a, rb(a + 3)))
  end
  print("      $01B434 -> $01B444 'move.b #$aa, $5f(a5)'  (el MOVIMIENTO $AA)")
  print("      $01C00A -> $01C01E 'move.b #$a8, $5f(a5)'  (el MOVIMIENTO $A8)")
  print("   la FUNCION que cambia de plano, en $0186BE (pone el estado $0A):")
  print("      $0186D2  'cmpi.w #$140, $9c(a5)'  ->  si el suelo es 320, va a $018722")
  print("      $0186DA  'btst.b #$0, $a042.w'    ->  si esta en el plano 320, va a $0186F2")
  print("      $018748  'move.b #$aa, -$5556(a5)'->  el MOVIMIENTO $AA (el cruce)")
  print("")
end

-- ---------------------------------------------------------------------
-- 2) EL HISTORIAL: los ultimos frames con sus botones
-- ---------------------------------------------------------------------
local HIST = {}          -- las lineas de los ultimos frames
local NHIST = 40         -- cuantos frames guardamos
local ultimo_dir = -1
local ultimo_bot = -1
local ultimo_est = -1
local ultimo_mov = -1
local ultimo_suelo = -1
local ncruces = 0
local viendo = false
local cola = 0

local function detalle(f, etiqueta)
  local est = rb(P1 + OFF_ESTADO)
  local mov = rb(P1 + OFF_MOVE)
  local fra = rb(P1 + OFF_FRAME)
  local dur = rb(P1 + OFF_DUR)
  local pl  = sx(rd32(P1 + OFF_PLANO))
  local esc = rd16(P1 + OFF_ESCALA)
  local xm  = sx(rd32(P1 + OFF_XMUNDO))
  local ym  = sx(rd32(P1 + OFF_YMUNDO))
  local b   = rb(P1 + OFF_BOTON)
  local d   = rb(P1 + OFF_DIRS)
  local bm  = rb(P1 + OFF_BOTMA)
  local gp  = rb(FLAG_PLANO)
  local pln = "? (no se lee $A042)"
  if gp ~= 0xFF then
    if bit.band(gp, 1) ~= 0 then pln = "DELANTE(320)"
    elseif bit.band(gp, 2) ~= 0 then pln = "ATRAS(304)" end
  end
  print(string.format(
    "[f %5d] %s estado=$%s move=$%s frame=$%s dur=$%s | botones=$%02X %-8s dirs=$%02X %-12s | plano=%-11s suelo=%7.2f esc=%3d | X=%7.1f Y=%7.1f | HP=%d",
    f, etiqueta, hex8(est), hex8(mov), hex8(fra), hex8(dur),
    b, botones(b), d, direcciones(d), pln, pl, esc, xm, ym, rd16(P1 + OFF_HP)))
  if bm ~= 0 then
    print(string.format("           botones MANTENIDOS ($73) = $%02X  %s", bm, botones(bm)))
  end
end

local function linea()
  local f = emu.framecount()
  local est = rb(P1 + OFF_ESTADO)
  local mov = rb(P1 + OFF_MOVE)
  local d   = rb(P1 + OFF_DIRS)
  local b   = rb(P1 + OFF_BOTON)
  local bm  = rb(P1 + OFF_BOTMA)

  -- el historial
  local s = string.format(
    "   f %5d | botones=$%02X %-8s (maint. $%02X %-8s) dirs=$%02X %-12s | estado=$%s move=$%s %-30s | suelo=%7.2f %s",
    f, b, botones(b), bm, botones(bm), d, direcciones(d),
    hex8(est), hex8(mov), nombre_move(mov), sx(rd32(P1 + OFF_PLANO)),
    (sx(rd32(P1 + OFF_PLANO)) > 315 and "el plano de DELANTE"
      or (sx(rd32(P1 + OFF_PLANO)) < 310 and "el plano de ATRAS" or "")))
  table.insert(HIST, s)
  while #HIST > NHIST do table.remove(HIST, 1) end

  -- 1) los botones: solo cuando cambian (o siempre, en modo "todos")
  if MODO == "todos" or d ~= ultimo_dir or b ~= ultimo_bot then
    print(string.format("[f %5d] PULSADO: botones=$%02X (%-8s)  dirs=$%02X (%-12s)   (estado $%s move $%s)",
                        f, b, botones(b), d, direcciones(d),
                        hex8(est), hex8(mov)))
    ultimo_dir = d
    ultimo_bot = b
  end

  -- 2) el CRUCE: lo detectamos por el estado+move del cruce (la CAIDA $0B
  --    con el move $0F, y la VUELTA $0A con el move $10), o por un cambio
  --    de PLANO (el suelo pasa de 320 a 304 o al reves).
  local suelo = rd32(P1 + OFF_PLANO)
  local suelo_num = sx(suelo)
  local suelo_ant = sx(ultimo_suelo)
  local es_plano = (suelo_num > 295 and suelo_num < 325)
  local en_cruce = (est == EST_CRUCE and mov == MOVE_VUELTA)
                    or (est == EST_CAIDA and mov == MOVE_CRUCE)
  -- un CAMBIO DE PLANO que no viene del estado del cruce (lo ajusta el juego
  -- solo cuando los peleadores se separan)
  if es_plano and ultimo_suelo >= 0 and suelo_ant > 295 and suelo_ant < 325
     and math.abs(suelo_num - suelo_ant) > 4 then
    print(string.format("[f %5d] *** CAMBIO DE PLANO: el suelo pasa de %.2f a %.2f  (estado $%s move $%s, botones $%02X) ***",
                        f, suelo_ant, suelo_num, hex8(est), hex8(mov), b))
  end
  if en_cruce and not viendo then
    viendo = true
    ncruces = ncruces + 1
    cola = 0
    print("")
    print(string.format("=== CRUCE n%02d en el frame %d (estado $%s move $%s %s) ===",
                        ncruces, f, hex8(est), hex8(mov), nombre_move(mov)))
    print(string.format("    >>> EN ESE FRAME: botones=$%02X (%s)  dirs=$%02X (%s)  suelo=%.2f",
                        b, botones(b), d, direcciones(d), suelo_num))
    print("    --- HISTORIAL (los frames previos: aqui esta el boton) ---")
    for _, h in ipairs(HIST) do print(h) end
    print("    --- DETALLE ---")
    detalle(f, "inicio ")
  elseif not en_cruce and viendo then
    cola = cola + 1
    if cola > 4 then
      viendo = false
      print(string.format("=== CRUCE n%02d termina en el frame %d ===", ncruces, f))
      print("")
    end
  end
  if en_cruce then
    cola = cola + 1
    if cola <= 12 then
      detalle(f, "sigue  ")
    end
  end
  ultimo_suelo = suelo

  ultimo_est = est
  ultimo_mov = mov
end

-- ---------------------------------------------------------------------
-- 3) EL ARRANQUE
-- ---------------------------------------------------------------------
local function arrancar()
  print("=== yuyu_cruce: sonda del CRUCE de planos ===")
  print(string.format("    mide el SLOT %d ($%06X)   modo=%s", JUGADOR, P1, MODO))
  for n = 1, 4 do
    local b = BASE_SLOT + (n - 1) * STRIDE
    print(string.format("      slot %d $%06X  estado=$%s move=$%s  HP=%d  suelo=%7.2f",
                        n, b, hex8(rb(b + OFF_ESTADO)), hex8(rb(b + OFF_MOVE)),
                        rd16(b + OFF_HP), sx(rd32(b + OFF_PLANO))))
  end
  print("    HACE el cruce (con los botones que uses) y mira la consola")
  print("    (el historial te dira que boton lo lanzo)")
  print("")
  analizar_rom()
  HIST = {}
  ultimo_dir = -1
  ultimo_bot = -1
  ultimo_suelo = -1
  ncruces = 0
  viendo = false
  cola = 0
end

emu.registerstart(arrancar)
emu.registerafter(linea)
