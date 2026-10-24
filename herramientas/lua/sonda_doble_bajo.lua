-- =====================================================================
-- sonda_doble_bajo.lua  v4 -- CAZADOR DEL DETECTOR DE DOBLE-PULSACION
--                            (BizHawk Y FBNeo, autodeteccion de dominio)
-- =====================================================================
-- CAMBIO v4: en BizHawk la lectura default NO mapea 0xFF8400 (el dominio
-- de memoria activo puede ser otro) y la v3 se creia el fallback FBNeo
-- y leia basura (asi salio el $92=$3B41 falso). La v4:
--   1) lista los dominios de memoria de BizHawk (nombre + tamano) y
--      los imprime al arrancar;
--   2) elige un dominio por nombre preferido ("68000", "68k", "main
--      ram", "mainram", "work ram", "wram", "bus";
--   3) traduce direcciones: dominio de 64KB (RAM) -> offset -0xFF0000;
--      dominio grande (bus) -> offset 0;
--   4) PROBE: entre f30 y f300 rota candidates y puntua cual lectura del
--      $5F del P1 da EXACTAMENTE los estados del menu boot (28/29/2A/30,
--      medidos en el log v1 real f55-f131); al final fija el ganador e
--      imprime los scores. Si ninguna da nada, cae al modo actual y
--      avisa (y DOMINIO_FIJO arriba permite forzar el dominio a mano).
--   5) si io.open no existe (BizHawk puede rechazarlo), avisa: el log
--      completo sale a la consola de Lua y hay que copiarlo a mano.
--
-- USO: la ROM arranca y SE DEJA QUIETA hasta ~f300 (la sonda hace el
-- probe sola). Luego P1 humano = Jin: salta y aprieta abajo dos veces
-- en el aire, 3 intentos.
-- =====================================================================

local VERSION = "v4"
local LOG_TXT = "C:\\Users\\leand\\AppData\\Local\\Temp\\opencode\\sonda_doble_bajo.log"

-- direcciones GLOBALES (espacio 68K del juego); rb/rw aplican el offset
local PAG_DESDE, PAG_HASTA = 0xFFA000, 0xFFA0FF
local FSM_P1, FSM_P2 = 0xFF85B0, 0xFF89B0
local P1B, P2B = 0xFF8400, 0xFF8800

-- ---- infra de dominio/offset -----------------------------------------
local DOMINIO, TAMDOM, OFF = "?", 0, 0
local modo = "actual"     -- "actual" (FBNeo-ish) | "bizhawk" | "fallback"

local function AD(a)
  return (a + OFF) % 0x1000000   -- lua sin &: modulo en 24 bits
end

local function rb(a)
  local ok, v = pcall(memory.readbyte, AD(a))
  if ok then return v end return 0
end
local function rw(a)
  local ok, v = pcall(memory.readword, AD(a))
  if ok then return v end return 0
end

local archivo
local aviso_io = false
local function loga(s)
  print(s)
  if archivo == nil and not aviso_io then
    aviso_io = true
    pcall(function()
      local fh = io.open(LOG_TXT, "a")
      if fh then
        archivo = fh
        archivo:write("\r\n== sesion nueva ==\r\n")
      end
    end)
    if archivo == nil then
      print("(!) el archivo de log no abre en este emulador (io restringido).")
      print("    TODO sale a la consola de Lua: copiala completa al final.")
    elseif aviso_io then
      print("(log tambien va a: " .. LOG_TXT .. ")")
    end
  end
  if archivo then pcall(function() archivo:write(s .. "\r\n") end) end
end

local function lista_dominios()
  local ok, lista = pcall(memory.getmemorydomainlist)
  if not ok or type(lista) ~= "table" then return nil end
  local salida = {}
  for _, nombre in pairs(lista) do
    local n = tostring(nombre)
    local tam = 0
    pcall(function() tam = memory.getmemorydomainsize(n) end)
    salida[#salida + 1] = n .. "(" .. tostring(tam) .. ")"
  end
  return table.concat(salida, " ")
end

local function tam_de(nombre)
  local tam = 0
  pcall(function() tam = memory.getmemorydomainsize(nombre) end)
  return tam
end

-- ---- fija dominio + offset --------------------------------------------
-- probe: puntua candidates leyendo $5F del P1 entre f30..f300; en el
-- boot del juego $5F pasa por 30/28/29/2A (no cero la mayor parte del
-- arranque), asi que bastantes frames nonzero = dominant plausibile.
local probe_frames      -- score por candidate: [i] = frames plausibles
local probe_cand        -- lista de candidates: [i] = {dom, off}
local probe_sak = 300   -- frames de probe (f30-f300; dejalo quieto hasta ahi)

local function armar_candidates()
  local lista_ok, lista = pcall(memory.getmemorydomainlist)
  if not lista_ok or type(lista) ~= "table" then return nil end
  local cands = {}
  local prefs = { "68000", "68k", "main ram", "mainram", "work ram", "wram", "bus" }
  local vistos = {}
  for _, pref in ipairs(prefs) do
    for _, nombre in pairs(lista) do
      local n = tostring(nombre):lower()
      if n:find(pref, 1, true) and not vistos[n] then
        vistos[n] = true
        local tam = tam_de(n)
        if tam == 0x10000 then
          cands[#cands + 1] = { dom = n, off = -0xFF0000 }
        elseif tam >= 0xFF8A00 then
          cands[#cands + 1] = { dom = n, off = 0 }
        end
      end
    end
  end
  return cands
end

local function aplicar(dom, off)
  local ok = pcall(memory.use_memory_domain, dom)
  if not ok then ok = pcall(memory.usememorydomain, dom) end
  if ok then DOMINIO, OFF, modo = dom, off, "bizhawk" end
  TAMDOM = tam_de(dom)
  return ok
end

local function fija_bases()
  local cands = armar_candidates()
  local dl = lista_dominios()
  if dl then loga("dominios de memoria: " .. dl) end
  if cands and #cands > 0 then
    probe_cand = cands
    probe_frames = {}
    for i = 1, #cands do probe_frames[i] = 0 end
    -- se hace el probe por frames de 1 a probe_sak en on_frame()
    return
  end
  -- sin API de dominios (FBNeo): la actual sirve si la base global da vida;
  -- si no, fallback FBNeo con bases 0x0084xx (historica, calibrada alli)
  if rw(P1B + 0x44) == 0 and rw(P1B + 0xB8) == 0 and rb(P1B + 0x71) == 0 then
    if rw(0x008400 + 0x44) ~= 0 or rb(0x008400 + 0x71) ~= 0 then
      P1B, P2B = 0x008400, 0x008800
      PAG_DESDE, PAG_HASTA = 0x00A000, 0x00A0FF
      FSM_P1, FSM_P2 = 0x0085B0, 0x0089B0
      modo = "fallback"
    end
  end
end

local function cerrar_probe()
  local mejor,mondon,mejoroff,mejorN = 0, nil, 0, 0
  local total = probe_sak - 30 + 1
  local res = {}
  for i = 1, #probe_cand do
    local cand = probe_cand[i]
    res[#res + 1] = string.format("%s@%+d=%d/%d", cand.dom, cand.off, probe_frames[i], total)
    if probe_frames[i] > mejorN then
      mejor, mondon, mejoroff, mejorN = i, cand.dom, cand.off, probe_frames[i]
    end
  end
  loga("probe $5F(P1) por candidate: " .. table.concat(res, " | "))
  if mejorN >= 10 then
    if aplicar(mondon, mejoroff) then
      P1B, P2B = 0xFF8400, 0xFF8800
      PAG_DESDE, PAG_HASTA = 0xFFA000, 0xFFA0FF
      FSM_P1, FSM_P2 = 0xFF85B0, 0xFF89B0
    end
  else
    loga("(!) probe sin datos: caigo al modo actual (dominio del visor)")
    loga("    si sale basura: chequea el nombre del dominio en el memory")
    loga("    viewer de BizHawk y escribelo arriba en DOMINIO_FIJO.")
  end
end

local function titulo()
  loga(string.format(
    "SONDA v%s | modo=%s dominio=%s tam=%d | addr=%+d | bases P1=%06X P2=%06X | pagina %06X-%06X | FSM P1=%06X",
    VERSION, modo, tostring(DOMINIO), TAMDOM, OFF, P1B, P2B, PAG_DESDE, PAG_HASTA, FSM_P1))
end

-- ---- el resto, identico a la v3 --------------------------------------
local pag_vieja
local mando_viejo
local char_viejo
local frame = 0

DOMINIO_FIJO = ""   -- si el autodeteque falla: pon aqui el nombre exacto

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
    if DOMINIO_FIJO ~= "" and DOMINIO ~= DOMINIO_FIJO then
      if aplicar(DOMINIO_FIJO, 0) then
        TAMDOM = tam_de(DOMINIO_FIJO)
        if TAMDOM == 0x10000 then OFF = -0xFF0000 end
      end
    end
    if modo ~= "bizhawk" then titulo() end
    -- el probe lo cierra el on_frame al llegar a probe_sak
  end

  -- probe en marcha: rotar candidates y medir $5F(P1) plausible
  if probe_cand and frame <= probe_sak then
    local idx = ((frame - 1) % #probe_cand) + 1
    local cand = probe_cand[idx]
    -- sin tocar el dominio global: leemos con el param dominio
    local v
    local okdom = pcall(function()
      if cand.off == 0 then
        v = memory.readbyte(P1B + 0x5F, cand.dom)
      else
        v = memory.readbyte((P1B + 0x5F) + cand.off, cand.dom)
      end
    end)
    -- plausibilizacion FUERTE: el boot del juego deja $5F del P1 solo en
    -- {28,29,2A,30} (log v1 real: f55-f131); la basura rara vez iguala
    -- esos valores exactos frame tras frame. (v==0 no puntua: todos lo tienen)
    if okdom and v and (v == 0x28 or v == 0x29 or v == 0x2A or v == 0x30) then
      probe_frames[idx] = probe_frames[idx] + 1
    end
    if frame == 30 and not probe_titulo then
      probe_titulo = true
      loga(string.format(
        "SONDA v%s (probe en marcha f30-%d) | bases tentativas P1=FF8400 | dominio por fijar",
        VERSION, probe_sak))
    end
    if frame == probe_sak then
      cerrar_probe()
      probe_cand, probe_frames = nil, nil
      TAMDOM = tam_de(DOMINIO)
      titulo()
    end
  end

  if probe_cand then
    mando_viejo, pag_vieja, char_viejo = nil, nil, nil   -- el probe contamina
  end

  local b71, b72, b73, b74 = lee_mando()
  local mando = b71 * 0x1000000 + b72 * 0x10000 + b73 * 0x100 + b74
  local cambio_mando = (mando ~= mando_viejo)

  -- calibracion del ID de personaje: word en $92 del struct del P1
  local w92 = rb(P1B + 0x92) * 0x100 + rb(P1B + 0x93)
  if w92 ~= char_viejo then
    loga(string.format("[f %d] CHAR P1: $92(word) %04X->%04X  ( esperado $25D2 en el build J, NINGUNO en el china )",
      frame, char_viejo or 0, w92))
    char_viejo = w92
  end

  if cambio_mando and mando_viejo then
    local mv71 = math.floor(mando_viejo / 0x1000000) % 0x100
    loga(string.format(
      "[f %d] MANDO cambia: $71 %s->%s  $72=%02X $73=%02X $74=%02X  $5F=%02X  Y=%04X  $76=%02X  FSM(P1)=%02X",
      frame, hex2(mv71), hex2(b71), b72, b73, b74,
      rb(P1B + 0x5F), rw(P1B + 0x44), rb(P1B + 0x76), rb(FSM_P1)))
  end

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
