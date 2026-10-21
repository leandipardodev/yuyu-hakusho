-- =====================================================================
-- yuyu_seq.lua  --  grabador de secuencia de move de UN SLOT (FBNeo)
-- =====================================================================
-- Para que sirve: cuando no sabes si un parche de ROM cambio algo,
-- esto te dice EXACTO que hace el juego. Graba, frame a frame:
--
--   $5F  id de move          $59  frame de la animacion
--   $5B  tick del frame      $5A  duracion del frame ($5A = b0 del registro)
--   $50  puntero a la tabla de moves  -> con eso se identifica el PERSONAJE
--   $8C  puntero a la sub-lista
--   $78  HP
--
-- QUE SLOT MIDE:
--   Los slots de jugador estan en $FF8400 + n*$400:
--     1 -> $FF8400     2 -> $FF8800     3 -> $FF8C00     4 -> $FF9000
--   El humano NO esta necesariamente en el slot 1 (en FBNeo se puede
--   jugar como P2).  Al arrancar el script imprime los 4 con su
--   personaje, para que veas cual es el tuyo.
--   Pon el numero correcto en JUGADOR de abajo.
--
-- OJO: en Lua 5.1 / LuaJIT NO existe el operador &.  Hay que usar
-- bit.band.  Y memory.readbyte devuelve el byte CON SIGNO, asi que sin
-- enmascarar los punteros y el HP salen como basura.
-- El 68000 es BIG ENDIAN.
--
-- Como se usa (FBNeo):
--   Game > Lua Scripting > New Lua Script Window > Browse > este fichero
--   JUGADOR = el slot donde estas vos (1-4)
--   hacé la tecnica y mira la consola.
--
-- NO escribe nada en la memoria del juego (regla 5 del proyecto).
-- =====================================================================

local JUGADOR = 1          -- <-- 1..4

local BASE_SLOT = 0xFF8400
local STRIDE    = 0x400
local OFF_MOVE   = 0x5F
local OFF_FRAME  = 0x59
local OFF_TICK   = 0x5B
local OFF_DUR    = 0x5A
local OFF_SUB    = 0x8C
local OFF_TABLA  = 0x50
local OFF_HP     = 0x78

-- tablas $50 por ctx, para identificar al personaje
local CTX50 = {
  [0x0BF75A]="ctx0", [0x0C229A]="ctx1", [0x0C4EEA]="ctx2", [0x0C7C9A]="ctx3",
  [0x0CA6DA]="ctx4", [0x0CCC7A]="ctx5", [0x0CF99A]="ctx6 ITSUKI",
  [0x0D1E5A]="ctx7", [0x0D4A9A]="ctx8", [0x0D777A]="ctx9",
}
-- nombres por ctx (el stun max $80 los identifica; ver FISICAS 6.1):
--   ctx0=40 ctx1=56 ctx2=48 ctx3=44 ctx4=54 ctx5=46
--   ctx6=40 ctx7=38 ctx8=48 ctx9=62
-- ctx3 = HIEI y ctx6 = ITSUKI confirmados por el proyecto.
local CTX_NOMBRE = {
  ctx0="Itsuki?", ctx1="Kuwabara?", ctx2="Yusuke/Chui?", ctx3="HIEI",
  ctx4="Sensui?", ctx5="Jin?", ctx6="ITSUKI", ctx7="Kurama?", ctx8="Yusuke/Chui?",
  ctx9="Toguro-",
}

local function rb(a) return bit.band(memory.readbyte(a), 0xFF) end

local function rd16(a)
  return rb(a) * 256 + rb(a + 1)
end

local function rd32(a)
  return rb(a) * 16777216 + rb(a + 1) * 65536 + rb(a + 2) * 256 + rb(a + 3)
end

local function hex8(v)  return string.format("%02X", v) end
local function hex32(v) return string.format("%08X", v) end

local P1 = BASE_SLOT + (JUGADOR - 1) * STRIDE

local anterior = { move=-1, frame=-1, dur=-1, tabla=-1 }
local nlineas = 0
local MAX_LINEAS = 300
local vistos = {}

local function ctx_de(base)
  local t = rd32(base + OFF_TABLA)
  local c = CTX50[t]
  if not c then return "?" .. hex32(t) end
  local n = CTX_NOMBRE[c]
  if n and n ~= "" then return c .. " " .. n end
  return c
end

local function una_linea()
  local f = emu.framecount()
  local move  = rb(P1 + OFF_MOVE)
  local frame = rb(P1 + OFF_FRAME)
  local tick  = rb(P1 + OFF_TICK)
  local dur   = rb(P1 + OFF_DUR)
  local tabla = rd32(P1 + OFF_TABLA)
  local sub   = rd32(P1 + OFF_SUB)
  local hp    = rd16(P1 + OFF_HP)

  local etiqueta = ctx_de(P1)

  local cambio = (move ~= anterior.move) or (frame ~= anterior.frame)
              or (dur ~= anterior.dur) or (tabla ~= anterior.tabla)

  if cambio and nlineas < MAX_LINEAS then
    nlineas = nlineas + 1
    print(string.format("[f %5d] %-22s $5F=%s $59=%s $5B=%s $5A=%s  tab50=$%s sub8C=$%s HP=%d",
      f, etiqueta, hex8(move), hex8(frame), hex8(tick), hex8(dur),
      hex32(tabla), hex32(sub), hp))
    local k = string.format("%s:%s", hex8(move), hex8(dur))
    vistos[k] = (vistos[k] or 0) + 1
  end

  anterior.move = move
  anterior.frame = frame
  anterior.dur = dur
  anterior.tabla = tabla
end

local function resumen()
  print("")
  print("=== moves vistos (move:duracion -> veces) ===")
  local claves = {}
  for k in pairs(vistos) do claves[#claves + 1] = k end
  table.sort(claves)
  for _, k in ipairs(claves) do
    print(string.format("   $5F=%s  $5A=%s   x%d", k:sub(1, 2), k:sub(4), vistos[k]))
  end
  print("=== fin ===")
end

local function al_arrancar()
  print("=== yuyu_seq: grabador de secuencia de move ===")
  print(string.format("    mide el SLOT %d  ($%06X)", JUGADOR, P1))
  print("    los 4 slots:")
  local elegido = nil
  for n = 1, 4 do
    local b = BASE_SLOT + (n - 1) * STRIDE
    local c = ctx_de(b)
    local hp = rd16(b + OFF_HP)
    print(string.format("      slot %d $%06X  %-22s  HP=%d", n, b, c, hp))
    if n == JUGADOR then elegido = c end
  end
  if elegido ~= "ctx6 ITSUKI" then
    print("")
    print("  !!!!!!!!!  AVISO: el slot elegido NO es ITSUKI (ctx6).")
    print("  !!!!!!!!!  Para medir 影手: poné ITSUKI en el personaje que")
    print("  !!!!!!!!!  estas controlando, y cerciorate de que JUGADOR = tu slot.")
  end
  print("    $5F=id move  $59=frame  $5B=tick  $5A=duracion del frame")
  print("")
  anterior.move = -1
  nlineas = 0
  vistos = {}
end

emu.registerstart(al_arrancar)
emu.registerafter(una_linea)
