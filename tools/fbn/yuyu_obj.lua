-- =====================================================================
-- yuyu_obj.lua  --  volcado de los OBJETOS del pool (FBNeo)
-- =====================================================================
-- Las "manos flotantes" de Itsuki (影手) NO son el personaje: son un
-- OBJETO del pool, con su propio move ID, su propia tabla de moves y su
-- propia hitbox.  El objeto tiene la misma estructura que el jugador:
--   $00  puntero del handler   $04  flag de ocupado ($80 = ocupado)
--   $06  contador de ticks     $10  velocidad X (16.16)
--   $24  grafico               $40/$44  posicion en mundo
--   $58  tipo de objeto        $5F  id de move
--
-- Este script NO supone la direccion del pool: la DETECTA por firma
-- (un puntero de handler valido seguido del flag $80), y despues la
-- sigue.  Asi no depende de acertar la aritmetica de la direccion.
--
-- Como se usa (FBNeo):
--   Game > Lua Scripting > New Lua Script Window > Browse > este fichero
--   Itsuki de P1, hacé 影手, y mira la consola.
--
-- NO escribe nada en la memoria del juego (regla 5 del proyecto).
-- =====================================================================

-- El allocator (0x1FAB4) hace:
--     movea.w $a036.w, a0      ; SIGN-EXTIENDE el word
--     adda.w  #$9400, a0        ; a0 = $009400 + indice*$80
-- El 68000 tiene el bit 23 INVERTIDO para la RAM, asi que $009400 es
-- fisicamente $FF9400... pero eso depende de como lo mapee el emulador.
-- Por eso se prueban TODAS las bases plausibles y se valida con la firma
-- (puntero de handler valido + flag $80 en +4).  Si ninguna funciona,
-- se volca la zona cruda para ver donde esta de verdad.
local BASES = {
  0xFF9400, 0x009400, 0x00FF9400, 0x7F9400, 0x007F9400, 0xFF8400, 0xFF8C00,
}
local POOL_N = 16
local POOL_STRIDE = 0x80

-- puntero del contador del pool
local OFF_CTR = 0xA036

-- rango de punteros de handler validos (los handlers de objeto estan
-- en el ROM entre $13000 y $16000: $149AC, $13E9A, $14EC6, $14930)
local HANDLER_MIN = 0x0013000
local HANDLER_MAX = 0x0016000

local OFF_HANDLER = 0x00
local OFF_FLAG    = 0x04
local OFF_TICK    = 0x06
local OFF_VELX    = 0x10
local OFF_GRAF    = 0x24
local OFF_POSX    = 0x40
local OFF_POSY    = 0x44
local OFF_TIPO    = 0x58
local OFF_MOVE    = 0x5F

local function rb(a) return bit.band(memory.readbyte(a), 0xFF) end
local function rd16(a) return rb(a) * 256 + rb(a + 1) end
local function rd32(a)
  return rb(a) * 16777216 + rb(a + 1) * 65536 + rb(a + 2) * 256 + rb(a + 3)
end
local function hex8(v)  return string.format("%02X", v) end
local function hex32(v) return string.format("%08X", v) end
local function s16(v)  if v >= 0x8000 then return v - 0x10000 end return v end
local function f32(v)
  if v >= 0x80000000 then v = v - 0x100000000 end
  return v / 65536.0
end

-- ----------------------------------------------------------------------
-- Autodeteccion: probar las bases candidatas y validarlas por firma
-- (puntero de handler valido + flag $80 en +4)
-- ----------------------------------------------------------------------
local slots = {}          -- tabla base -> true
local ultimo_scan = -9999
local base_ok = nil
local ctr = 0

local function probar_base(base)
  local n = 0
  for i = 0, POOL_N - 1 do
    local b = base + i * POOL_STRIDE
    local h = rd32(b + OFF_HANDLER)
    if h >= HANDLER_MIN and h <= HANDLER_MAX then
      if rd16(b + OFF_FLAG) == 0x0080 then
        slots[b] = true
        n = n + 1
      end
    end
  end
  return n
end

local function escanear()
  slots = {}
  base_ok = nil
  ctr = rd16(0xFF0000 + OFF_CTR)
  for _, base in ipairs(BASES) do
    if probar_base(base) > 0 then
      base_ok = base
      return
    end
  end
end

local anterior = {}
local nlineas = 0
local MAX = 150
local avisado = false

local function volcar()
  local f = emu.framecount()
  if f - ultimo_scan > 30 or ultimo_scan < 0 then
    ultimo_scan = f
    escanear()
    if base_ok then
      print(string.format("[f %5d] POOL en $%06X   contador $A036 = $%04X",
        f, base_ok, ctr))
    elseif not avisado then
      avisado = true
      print(string.format("[f %5d] NO se encontro el pool. contador $A036 = $%04X", f, ctr))
      print("    bases probadas: ")
      for _, b in ipairs(BASES) do
        local h = rd32(b + OFF_HANDLER)
        local fl = rd16(b + OFF_FLAG)
        print(string.format("      $%06X  handler=$%08X  flag=$%04X", b, h, fl))
      end
      print("    volcado crudo de $FF9400-$FF9480:")
      for k = 0, 7 do
        local b = 0xFF9400 + k * 16
        local w = {}
        for j = 0, 3 do w[#w+1] = string.format("%02X", rb(b + j)) end
        print(string.format("      $%06X  %s %s %s %s", b, w[1], w[2], w[3], w[4]))
      end
    end
  end

  local bases = {}
  for a in pairs(slots) do bases[#bases + 1] = a end
  table.sort(bases)

  for _, b in ipairs(bases) do
    local v = {
      handler = rd32(b + OFF_HANDLER),
      flag    = rd16(b + OFF_FLAG),
      tick    = rd16(b + OFF_TICK),
      vx      = rd32(b + OFF_VELX),
      graf    = rb(b + OFF_GRAF),
      px      = s16(rd16(b + OFF_POSX)),
      py      = s16(rd16(b + OFF_POSY)),
      tipo    = rb(b + OFF_TIPO),
      move    = rb(b + OFF_MOVE),
    }
    local p = anterior[b]
    local camb = p == nil
      or p.move ~= v.move or p.tipo ~= v.tipo or p.graf ~= v.graf
      or p.vx ~= v.vx or p.px ~= v.px or p.py ~= v.py
      or p.tick ~= v.tick or p.handler ~= v.handler
    if camb and nlineas < MAX then
      nlineas = nlineas + 1
      print(string.format(
        "[f %5d] obj@$%06X  flag=$%02X tipo=$%02X move=$%02X graf=$%02X tick=%d  velX=%+7.4f  pos=(%4d,%4d)  handler=$%08X",
        f, b, v.flag, v.tipo, v.move, v.graf, v.tick, f32(v.vx), v.px, v.py, v.handler))
      anterior[b] = v
    end
  end
end

local function al_arrancar()
  print("=== yuyu_obj: objetos del pool (autodetectados) ===")
  print("    firma: puntero de handler en $13000-$16000 + flag $80 en +4")
  print("")
  anterior = {}
  nlineas = 0
  ultimo_scan = -9999
end

emu.registerstart(al_arrancar)
emu.registerafter(volcar)
