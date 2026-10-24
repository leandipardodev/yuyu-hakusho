-- =====================================================================
-- sonda_doble_bajo.lua  v3 -- CAZADOR DEL DETECTOR DE DOBLE-PULSACION
--                            (para BizHawk / core Genesis)
-- =====================================================================
-- OBJETIVO NUEVO: no mirar el dive, mirar el DETECTOR. Con esta sonda se
-- corre la BASE limpia (o la 34 DIAG) y se hacen DOBLE-ARRIBA (super
-- salto) unas 5 veces. La sonda compara frame a frame la pagina de RAM
-- $FFA000-$FFA0FF (la zona del buzon/globals) y vuelca CADA byte que
-- cambia, con direccion, valor viejo->nuevo y frame. El byte del
-- detector de doble-pulsacion TIENE que aparecer ahi justo alrededor
-- del doble tap. Luego se comparan los volcados entre ROMs: el byte que
-- laten en la base y queda pegado en la 33 es el detector.
--
-- Para no inundar el log, el diff de la pagina se vuelca SOLO en los
-- frames donde el mando cambia (bits de arriba/abajo o botones).
--
-- TAMBIEN LOGUEA el mando bruto ($71/$72/$73/$74 del P1), $5F y la FSM
-- del parche ($FF85B0 = $1B0(a5) del P1, en la 33; en otras ROMs es
-- basura: se ve igual, solo se interpreta en la 33).
--
-- EL LOG ESCRIBE TAMBIEN EN UN ARCHIVO:
--   C:\Users\leand\AppData\Local\Temp\opencode\sonda_doble_bajo.log
-- =====================================================================

local VERSION = "v3"
local FONDO   = 80
local LOG_TXT = "C:\\Users\\leand\\AppData\\Local\\Temp\\opencode\\sonda_doble_bajo.log"

-- la pagina del buzon/globals
local PAG_DESDE, PAG_HASTA = 0xFFA000, 0xFFA0FF
local FSM_P1, FSM_P2 = 0xFF85B0, 0xFF89B0
local P1B, P2B = 0xFF8400, 0xFF8800

local function rb(a) local ok, v = pcall(memory.readbyte, a); if ok then return v end return 0 end
local function rw(a) local ok, v = pcall(memory.readword, a); if ok then return v end return 0 end

local archivo
local function loga(s)
  print(s)
  if archivo == nil then
    local ok, fh = pcall(io.open, LOG_TXT, "a")
    if ok and fh then archivo = fh; archivo:write("\r\n== sesion nueva ==\r\n") end
  end
  if archivo then pcall(function() archivo:write(s .. "\r\n") end) end
end

local function fija_bases()
  -- fallback FBNeo (direcciones sin FFFFFF de dominio)
  if rw(P1B + 0x44) == 0 and rw(P1B + 0xB8) == 0 and rb(P1B + 0x71) == 0 then
    if rw(0x008400 + 0x44) ~= 0 or rb(0x008400 + 0x71) ~= 0 then
      P1B, P2B = 0x008400, 0x008800
      PAG_DESDE, PAG_HASTA = 0x00A000, 0x00A0FF
      FSM_P1, FSM_P2 = 0x0085B0, 0x0089B0
    end
  end
end

local pag_vieja      -- snapshot anterior de la pagina
local mando_viejo    -- los 4 bytes de mando del frame anterior
local frame = 0

local function lee_mando()
  return rb(P1B + 0x71), rb(P1B + 0x72), rb(P1B + 0x73), rb(P1B + 0x74)
end

local function hex2(v) return string.format("%02X", v) end

local function snapshot_pagina()
  local t = {}
  for a = PAG_DESDE, PAG_HASTA do t[a] = rb(a) end
  return t
end

local function vuelca_diff(vieja, nueva, tag)
  local n = 0
  local fila = {}
  for a = PAG_DESDE, PAG_HASTA do
    if vieja[a] ~= nueva[a] then
      n = n + 1
      fila[#fila + 1] = string.format("$%06X %02X->%02X", a, vieja[a] or 0, nueva[a])
      if #fila == 8 then
        loga("      " .. table.concat(fila, "  ")); fila = {}
      end
    end
  end
  if n > 0 then
    if #fila > 0 then loga("      " .. table.concat(fila, "  ")) end
    loga(string.format("[f %d] %s: %d bytes de la pagina %06X-%06X cambian",
      frame, tag, n, PAG_DESDE, PAG_HASTA))
  end
  return n
end

local function on_frame()
  frame = frame + 1
  if frame == 1 then
    fija_bases()
    loga(string.format("== sonde v%s | bases P1=%06X P2=%06X | pagina %06X-%06X | FSM P1=%06X ==",
      VERSION, P1B, P2B, PAG_DESDE, PAG_HASTA, FSM_P1))
  end

  local b71, b72, b73, b74 = lee_mando()
  local mando = b71 * 0x1000000 + b72 * 0x10000 + b73 * 0x100 + b74
  local cambio_mando = (mando ~= mando_viejo)

  if cambio_mando and mando_viejo then
    local mv71 = math.floor(mando_viejo / 0x1000000) % 0x100
    loga(string.format(
      "[f %d] MANDO cambia: $71 %s->%s  $72=%02X $73=%02X $74=%02X  $5F=%02X  Y=%04X  FSM(P1)=%02X",
      frame, hex2(mv71), hex2(b71), b72, b73, b74,
      rb(P1B + 0x5F), rw(P1B + 0x44), rb(FSM_P1)))
  end

  -- el diff de la pagina SOLO cuando el mando movio
  if frame > 60 and cambio_mando then
    local nueva = snapshot_pagina()
    if pag_vieja ~= nil then
      vuelca_diff(pag_vieja, nueva, "pagina buzon/globals")
    end
    pag_vieja = nueva
  end

  mando_viejo = mando
end

while true do
  on_frame()
  emu.frameadvance()
end
