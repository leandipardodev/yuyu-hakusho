-- =====================================================================
-- probe_aura.lua -- LA SONDA-DIAGNOSTICA DEL CRASH DEL AURA (v9-2)
--                     para FBNeo / Fightcade
-- =====================================================================
-- SOLO OBSERVA (no escribe nada en la RAM). La irmos cargando encima del
-- ROM 30_china_VENENO_AURA_P1_P2.bin (el que rompe): cuando el juego se
-- pone en negro al cruzar, las lineas ANTERIORES al apagon nos dicen:
--
--   * si el clone llego a nacer (un slot con handler $149AC),
--   * como quedo el record ($4 el vivo, $59 el estado, $24 el tile,
--     $3C la pisada, $50 la tabla...),
--   * si el contador de cadencia en $A042 (bits 5-7) llego a dar el carry,
--   * como estaba el pool (cuantos slots libres).
--
-- Salida cada 30 frames:
--   PI f<N> | $A042=xx (cuenta N) | libres=n | trail=vivos | cursor=xxxx
-- Y cuando detecta UN slot $149AC vivo (o cambia el estado), VUELCA el
-- record entero en hex ($80 bytes, 16 por linea).
--
-- Si no ves "PROBE AURA CARGADO", el script no corre: recargarlo
-- (Archivo -> Lua -> cargar de nuevo).
-- =====================================================================

local VERSION = "probe1"

local function rb(a) local ok, v = pcall(memory.readbyte, a); if ok then return v end return 0 end
local function rw(a) local ok, v = pcall(memory.readword, a); if ok then return v end return 0 end

local base = nil

-- el pool: $FF9400 (o su espejo $009400): el que de 16 slots coherentes
local function detecta()
  for _, b in ipairs({0xFF9400, 0x009400}) do
    local ok = 0
    for i = 0, 15 do
      local f = rw(b + i * 0x80 + 4)
      if f == 0x0080 or f == 0 then ok = ok + 1 end
    end
    if ok == 16 then
      base = b
      print(string.format("PROBE %s: el pool es $%06X (16 slots coherentes)", VERSION, b))
      return
    end
  end
  print("PROBE: el pool no detectado (sin juego o habiendo cambiado de arte)")
end

local tick = 0
local ult_firma = nil

local function hexd(a)
  for o = 0, 0x78, 16 do
    local hex = {}
    for k = 0, 15, 2 do
      hex[#hex + 1] = string.format("%04X", rw(a + o + k))
    end
    print(string.format("    +%02X: %s", o, table.concat(hex, " ")))
  end
end

local function cada_frame()
  tick = tick + 1
  if not base then
    if tick % 90 == 1 then detecta() end
    return
  end

  local libres, trails, otros = 0, 0, {}
  local slot_trail = nil
  for i = 0, 15 do
    local a = base + i * 0x80
    local f = rw(a + 4)
    if f == 0 then
      libres = libres + 1
    else
      lw = rw(a)
      if lw == 0x000149AC then
        trails = trails + 1
        slot_trail = slot_trail or a
      else
        otros[#otros + 1] = string.format("$%02X", rb(a + 0x58))
      end
    end
  end

  local a042 = rb(0x00A042)
  local cuenta = a042 // 32           -- bits 5-7 = mi contador de cadencia
  local cursor = rw(0x00A036)

  -- el latido cada 30 frames
  print(string.format("PI f%-6d | $A042=%02X (cuenta=%d) | libres=%d | trail=%d | resto=[%s] | cursor=%04X",
    tick, a042, cuenta, libres, trails, table.concat(otros, ","), cursor))

  -- volcado del trail cuando NACE o cambia de estado
  if slot_trail then
    local firma = rw(slot_trail + 6) * 0x10000 + rw(slot_trail + 0x3C) + rb(slot_trail + 0x59) * 256
    if firma ~= ult_firma then
      ult_firma = firma
      print(string.format("  >>> TRAIL slot $%06X  $4=%04X  $6=%04X  $3C=%04X  $59=%02X  $5B=%02X  $24=%04X  $1C=%06X  $50=%06X  $40=%04X  $44=%04X",
        slot_trail, rw(slot_trail + 4), rw(slot_trail + 6), rw(slot_trail + 0x3C),
        rb(slot_trail + 0x59), rb(slot_trail + 0x5B), rw(slot_trail + 0x24),
        rw(slot_trail + 0x1C) * 65536 + rw(slot_trail + 0x1E),
        rw(slot_trail + 0x50) * 65536 + rw(slot_trail + 0x52),
        rw(slot_trail + 0x40), rw(slot_trail + 0x44)))
      hexd(slot_trail)
      return
    end
  end
end

detecta()
emu.registerafter(cada_frame)
print(string.format("PROBE %s CARGADO (solo observacion).", VERSION))
