-- =====================================================================
-- sonda_doble_bajo.lua  v2 -- EL DOBLE ABAJO EN EL AIRE (JIN)
--                            (para BizHawk / core Genesis)
-- =====================================================================
-- v2: ahora dispara por LO QUE SE VE:
--   a) caida vertical rapida: $44 baja mas de UMBRAL subpixels en un frame
--      mientras esta en el aire ($44 < $9C)
--   b) el comando de doble ($71/$72/$73 con bit5 = $20) prendido
--   c) $5F entra a la familia $A0-$AD (por si el armador deja rastro)
-- En cualquier caso VUELCA el buffer de los ultimos ~2*FONDO frames de
-- AMBOS jugadores, para ver que hizo cada uno alrededor del pique.
--
-- EL LOG ESCRIBE TAMBIEN EN UN ARCHIVO:
--   C:\Users\leand\AppData\Local\Temp\opencode\sonda_doble_bajo.log
-- =====================================================================

local VERSION = "v2"

local SILENCIO = true        -- el latido no aparea la consola
local FONDO    = 80          -- frames de buffer por jugador (se vuelca x2)
local UMBRAL   = 0x20        -- subpixels de Y por frame = "caida rapida"
local LOG_TXT  = "C:\\Users\\leand\\AppData\\Local\\Temp\\opencode\\sonda_doble_bajo.log"
local VIGILAR  = { 0x5F, 0x5D, 0x60, 0x6B, 0x59, 0x5A, 0x5B, 0x71, 0x72, 0x73, 0xCE }

local function rb(a) local ok, v = pcall(memory.readbyte, a); if ok then return v end return 0 end
local function rw(a) local ok, v = pcall(memory.readword, a); if ok then return v end return 0 end
local function rdw(a)
  local ok, v = pcall(memory.readdword, a)
  if ok and type(v) == "number" then return v end
  local hi, lo = rw(a), rw(a + 2)
  if hi and lo then return hi * 65536 + lo end
  return 0
end

-- bases: dominio BizHawk ($FF...) fallback FBNeo ($00...)
local P1B, P2B = 0xFF8400, 0xFF8800
local function fija_bases()
  if rw(P1B + 0x44) ~= 0 or rw(P1B + 0xB8) ~= 0 then return end
  if rw(0x008400 + 0x44) ~= 0 and rw(0x008800 + 0x44) ~= 0 then
    P1B, P2B = 0x008400, 0x008800
  end
end

local archivo = nil
local function loga(s)
  print(s)
  if archivo == nil then
    local ok, fh = pcall(io.open, LOG_TXT, "a")
    if ok and fh then archivo = fh; archivo:write("== sesion nueva ==\n") end
  end
  if archivo then pcall(function() archivo:write(s .. "\n") end) end
end

local fondo = {}   -- fondo[base] = lista de lineas
local prev   = {}
local frame  = 0

local function snapshot(base, tag)
  local parts = {}
  for _, off in ipairs(VIGILAR) do
    parts[#parts + 1] = string.format("$%02X=$%02X", off, rb(base + off))
  end
  parts[#parts + 1] = string.format("$D2=$%04X", rw(base + 0xD2))
  parts[#parts + 1] = string.format("$D4=$%04X", rw(base + 0xD4))
  parts[#parts + 1] = string.format("$B8=$%04X", rw(base + 0xB8))
  parts[#parts + 1] = string.format("$Y=$%04X", rw(base + 0x44))
  parts[#parts + 1] = string.format("$9C=$%04X", rw(base + 0x9C))
  parts[#parts + 1] = string.format("$61=$%02X", rb(base + 0x61))
  parts[#parts + 1] = string.format("$14=$%08X", rdw(base + 0x14))
  return string.format("  [%s] f%d: ", tag, frame) .. table.concat(parts, " ")
end

local function dump_todos(motivo)
  loga(("##### CAIDA RAPIDA / DOBLE DETECTADA (f%d) motivo=%s"):format(frame, motivo))
  for _, b in ipairs({ P1B, P2B }) do
    local tag = (b == P1B) and "P1" or "P2"
    loga("-- buffer " .. tag .. " --")
    local buf = fondo[b]
    if buf then
      for _, line in ipairs(buf) do loga(line) end
    end
  end
end

local function pasa()
  local ok_orig, err = pcall(function()
    frame = frame + 1
    fija_bases()
    for _, p in ipairs({ { P1B, "P1" }, { P2B, "P2" } }) do
      local base, tag = p[1], p[2]
      local buf = fondo[base] or {}
      buf[#buf + 1] = snapshot(base, tag)
      while #buf > FONDO * 2 do table.remove(buf, 1) end
      fondo[base] = buf

      -- transiciones livianas (sin volcado)
      for _, off in ipairs({ 0x5F, 0x6B, 0x71 }) do
        local v = rb(base + off)
        local k = string.format("%06X:%02X", base, off)
        if prev[k] ~= nil and prev[k] ~= v then
          loga(string.format(">> [%s] f%d CAMBIO $%02X: %02X -> %02X", tag, frame, off, prev[k], v))
        end
        prev[k] = v
      end

      -- a) caida rapida en el aire
      local y, yprev = rw(base + 0x44), prev[base .. ":y"]
      local enaire = rw(base + 0x44) < rw(base + 0x9C)
      local dy = 0
      if yprev then dy = y - yprev end
      prev[base .. ":y"] = y
      if dy >= UMBRAL and enaire then
        if prev[base .. ":pique"] == nil then
          prev[base .. ":pique"] = 1
          if not prev[base .. ":dumpeado"] then
            prev[base .. ":dumpeado"] = 1
            dump_todos("caida rapida en " .. tag)
          end
        end
      else
        prev[base .. ":pique"] = nil
        -- despues de 45 frames calmo re-permite dumpear
        if dy < UMBRAL and prev[base .. ":dumpeado"] then
          prev[base .. ":calm"] = (prev[base .. ":calm"] or 0) + 1
          if prev[base .. ":calm"] > 45 then
            prev[base .. ":dumpeado"] = nil
            prev[base .. ":calm"] = nil
          end
        end
      end

      -- b) el comando doble (bit5 en $71/$72/$73)
      local d71 = rb(base + 0x71)
      if (d71 % 32) >= 16 then
        -- bit5
        if not prev[base .. ":doble"] then
          prev[base .. ":doble"] = 1
          loga(string.format(">> [%s] f%d COMANDO DOBLE: $71=%02X $72=%02X $73=%02X",
            tag, frame, d71, rb(base + 0x72), rb(base + 0x73)))
          if not prev[base .. ":dumpeado"] then
            prev[base .. ":dumpeado"] = 1
            dump_todos("bit5 doble en " .. tag)
          end
        end
      else
        prev[base .. ":doble"] = nil
      end

      -- c) cualquier estado $A0-$AD
      local f5f = rb(base + 0x5F)
      if f5f >= 0xA0 and f5f <= 0xAD then
        loga(string.format(">> [%s] f%d ESTADO A-: $5F=%02X", tag, frame, f5f))
      end
    end
    if not SILENCIO and frame % 600 == 0 then
      loga(string.format("[sonda %s viva f%d]", VERSION, frame))
    end
  end)
  if not ok_orig then
    if not prev.errmostrado then
      prev.errmostrado = true
      print("SONDA ERROR: " .. tostring(err))
    end
  end
end

if event and event.onframeend then event.onframeend(pasa) end
if gui and gui.register then gui.register(function() pcall(pasa) end) end

loga("====================================================================")
loga("SONDA DOBLE BAJO " .. VERSION .. ": cargada")
loga("1) P1 humano = Jin: salta y aprieta abajo dos veces en el aire")
loga("2) despues pon Jin CPU y espera su descenso")
loga("el log tambien va a: " .. LOG_TXT)
loga("====================================================================")
