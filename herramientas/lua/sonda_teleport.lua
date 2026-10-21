-- =====================================================================
-- sonda_teleport.lua  --  que esta pasando al final del teleport de ITSUKI
-- =====================================================================
-- El tema: al terminar el teleport (abajo+arriba + A/B/C) el personaje
-- "aparece en el aire" unos frames en vez de quedar plantado en el piso.
--
-- Este script imprime, frame a frame, lo que hace falta para saber SI
-- MISMOS:
--
--   $5F  estado/move      $59  frame de la animacion   $5A  duracion
--   $44  Y EN MUNDO (16.16, entero en la palabra baja)
--   $9C  el suelo del PLANO en el que esta el personaje
--   $08  X EN PANTALLA    $0C  Y EN PANTALLA
--   $2A  el offset Y del frame (el sprite se dibuja $44 + $2A)
--
-- Lo que hay que mirar:
--   * si $44 NO es igual a $9C -> el ancla no esta en el suelo
--   * si $9C es 304 en vez de 320 -> esta en el PLANO DE ATRAS y por eso
--     se ve 16 px por encima del suelo (el plano de atras esta mas arriba)
--   * si $2A es -64 -> el sprite se dibuja 64 px por encima del ancla
--
-- Como se usa (FBNeo):
--   Game > Lua Scripting > New Lua Script Window > Browse > este fichero
--   elegí ITSUKI, hacé el teleport, y mirá la consola.
--   JUGADOR = el slot donde controlás vos (1..4).
--
-- NO escribe nada en la memoria del juego.
-- =====================================================================

local JUGADOR = 1          -- <-- 1..4

local BASE_SLOT = 0xFF8400
local STRIDE    = 0x400
local OFF_MOVE   = 0x5F
local OFF_FRAME  = 0x59
local OFF_DUR    = 0x5A
local OFF_TABLA  = 0x50
local OFF_XMUNDO = 0x40
local OFF_YMUNDO = 0x44
local OFF_PLANO  = 0x9C
local OFF_XPANT  = 0x08
local OFF_YPANT  = 0x0C
local OFF_OFFY   = 0x2A
local OFF_VX     = 0x10
local OFF_VY     = 0x14
local OFF_FLAG60 = 0x60
local OFF_FLAG89 = 0x89
local OFF_ZONA   = 0x48
local OFF_GRAV   = 0x4C

local CTX50 = {
  [0x0BF75A]="ctx0", [0x0C229A]="ctx1", [0x0C4EEA]="ctx2", [0x0C7C9A]="ctx3",
  [0x0CA6DA]="ctx4", [0x0CCC7A]="ctx5", [0x0CF99A]="ctx6",
  [0x0D1E5A]="ctx7", [0x0D4A9A]="ctx8", [0x0D777A]="ctx9",
}

local function rb(a) return bit.band(memory.readbyte(a), 0xFF) end

local function rd16(a)
  return rb(a) * 256 + rb(a + 1)
end

local function rd32(a)
  return rb(a) * 16777216 + rb(a + 1) * 65536 + rb(a + 2) * 256 + rb(a + 3)
end

local function sx(v)          -- 16.16 con entero en la palabra baja -> numero
  return v / 65536.0
end

local function hex8(v)  return string.format("%02X", v) end
local function hex32(v) return string.format("%08X", v) end

local P1 = BASE_SLOT + (JUGADOR - 1) * STRIDE

local viendo = false        -- estamos dentro del teleport?
local nlineas = 0
local MAX = 200
local cola = 0             -- frames tras la tecnica (para ver el aterrizaje)
local ultimo = { move=-1, frame=-1 }

local function es_itsuki()
  return CTX50[rd32(P1 + OFF_TABLA)] == "ctx6"
end

local function linea()
  local f = emu.framecount()
  local move  = rb(P1 + OFF_MOVE)
  local frame = rb(P1 + OFF_FRAME)
  local dur   = rb(P1 + OFF_DUR)

  -- cualquier estado por encima de $0F es una TECNICA: asi se ve el
  -- teleport entero (blink $A4, colocacion $A5, arco $AF, aire $A8...)
  local en_tp = es_itsuki() and (move > 0x0F)

  if en_tp and not viendo then
    viendo = true
    nlineas = 0
    cola = 0
    print("")
    print(string.format("=== TP de ITSUKI empieza en el frame %d (estado $%s) ===",
                        f, hex8(move)))
  elseif not en_tp and viendo then
    cola = cola + 1
    if cola > 30 then
      viendo = false
      print(string.format("=== TP de ITSUKI termina en el frame %d (%d lineas) ===",
                          f, nlineas))
      print("")
    end
  end

  if viendo and nlineas < MAX then
    nlineas = nlineas + 1
    local ym  = sx(rd32(P1 + OFF_YMUNDO))
    local pl  = sx(rd32(P1 + OFF_PLANO))
    local xm  = sx(rd32(P1 + OFF_XMUNDO))
    local vx  = sx(rd32(P1 + OFF_VX))
    local vy  = sx(rd32(P1 + OFF_VY))
    print(string.format(
      "[f %5d] $5F=%s $59=%s $5A=%s | mundo X=%8.2f Y=%8.2f | suelo $9C=%8.2f | pant %3d,%3d | $2A=%4d | vx=%6.2f vy=%6.2f | $60=%s $89=%s $48=%s",
      f, hex8(move), hex8(frame), hex8(dur),
      xm, ym, pl,
      rd16(P1 + OFF_XPANT), rd16(P1 + OFF_YPANT),
      rb(P1 + OFF_OFFY),
      vx, vy,
      hex8(rb(P1 + OFF_FLAG60)), hex8(rb(P1 + OFF_FLAG89)),
      hex8(rb(P1 + OFF_ZONA))))
  end

  ultimo.move = move
  ultimo.frame = frame
end

local function arrancar()
  print("=== yuyu_tp: sonda del teleport de ITSUKI ===")
  print(string.format("    mide el SLOT %d ($%06X)", JUGADOR, P1))
  for n = 1, 4 do
    local b = BASE_SLOT + (n - 1) * STRIDE
    local c = CTX50[rd32(b + OFF_TABLA)] or "?"
    print(string.format("      slot %d $%06X  %-6s  HP=%d", n, b, c, rd16(b + 0x78)))
  end
  print("    hacé el teleport de ITSUKI y mirá la consola")
  print("")
  viendo = false
  nlineas = 0
  cola = 0
end

emu.registerstart(arrancar)
emu.registerafter(linea)
