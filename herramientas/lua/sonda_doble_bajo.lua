-- =====================================================================
-- sonda_doble_bajo.lua  v5 -- CAZADOR DEL DETECTOR DE DOBLE-PULSACION
--                            (BizHawk Y FBNeo, autodeteccion de dominio)
-- =====================================================================
-- CAMBIO v5:
--   BUG FIX: la v4 pasaba los nombres de dominio en minuscula a
--     memory.readbyte/use_memory_domain y BizHawk NO los encuentra
--     ("Unable to find domain: m68k bus...falling back to current").
--     La v5 guarda el nombre ORIGINAL (minuscula solo para el match).
--   NUEVO: 3er candidate implicito = "sin tocar dominio" (el actual).
--     En el run v5 del usuario el dominio actual (M68K BUS) trabalhava
--     PERFECTO y los candidates rotos cayeron por fallback al mismo...
--     mejor no arriesgar: si "actual" puntua igual o mejor, gana.
--   NUEVO: watch de los bytes de estado del STRUCT del P1 cada frame,
--     como la v1: $5F, $6B, FSM(P1), $76, $1B0. La v4 solo los imprimia
--     en los MANDO-cambia y se perdian los valores intermedios.
--   PROBE: set plausible {07,08,0D,0E,28,29,2A,30} (estados de salto y
--     menu vistos en logs reales), ventana f40-f900.
--   OJO DEL USUARIO v4 (oro puro):
--     * $92(word) = 25D2 en el struct del P1 apenas se elige Jin
--       (f808): el gate del build J NO era el asesino del dive.
--     * $07 = salto diagonal (nibbles 9/5 alto+lateral -> 5F=07 con
--       velocidad horizontal; nibble 1 arriba puro -> 5F=08),
--       armador en $015E76/$018580 (cmpi #$9/5/1 sobre $71&$F).
--     * $90/$AE/$AC = estados de ataque aereo; 0C = caida post-ataque;
--       06/01/02 = floor/walk/land-ish; 90->0C->07 al aterrizar.
-- =====================================================================

local VERSION = "v5"
local LOG_TXT = "C:\\Users\\leand\\AppData\\Local\\Temp\\opencode\\sonda_doble_bajo.log"

-- direcciones GLOBALES (espacio 68K del juego); rb/rw aplican el offset
local PAG_DESDE, PAG_HASTA = 0xFFA000, 0xFFA0FF
local FSM_P1, FSM_P2 = 0xFF85B0, 0xFF89B0
local P1B, P2B = 0xFF8400, 0xFF8800

-- ---- infra de dominio/offset -----------------------------------------
local DOMINIO, TAMDOM, OFF = "(actual)", 0, 0
local modo = "actual"

local function AD(a)
  return (a + OFF) % 0x1000000
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
    else
      print("(log tambien va a: " .. LOG_TXT .. ")")
    end
  end
  if archivo then pcall(function() archivo:write(s .. "\r\n") end) end
end

local function lista_dominios()
  local ok, lista = pcall(memory.getmemorydomainlist)
  if not ok or type(lista) ~= "table" then return "" end
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

-- ---- probe -------------------------------------------------------------
local probe_cand        -- [i] = {orig, low, off}; vacio = probe off
local probe_frames
local probe_sak = 900

local function armar_candidates()
  local lista_ok, lista = pcall(memory.getmemorydomainlist)
  if not lista_ok or type(lista) ~= "table" then return nil end
  local cands = {}
  local prefs = { "68000", "68k", "main ram", "mainram", "work ram", "wram", "bus" }
  local vistos = {}
  for _, pref in ipairs(prefs) do
    for _, nombre in pairs(lista) do
      local n = tostring(nombre)
      local low = n:lower()
      if low:find(pref, 1, true) and not vistos[n] then
        vistos[n] = true
        local tam = tam_de(n)
        if tam == 0x10000 then
          cands[#cands + 1] = { orig = n, off = -0xFF0000 }
        elseif tam >= 0xFF8A00 then
          cands[#cands + 1] = { orig = n, off = 0 }
        end
      end
    end
  end
  return cands
end

local function aplicar(off)          -- el dominio se fija UNA vez fuera
  OFF = off
  modo = "fijado"
end

local function fija_dominio(nombre)
  local ok = pcall(memory.use_memory_domain, nombre)
  if not ok then ok = pcall(memory.usememorydomain, nombre) end
  DOMINIO = nombre
  TAMDOM = tam_de(nombre)
  return ok
end

local function fija_bases()
  loga("dominios de memoria: " .. lista_dominios())
  local cands = armar_candidates()
  if cands and #cands > 0 then
    probe_cand = cands
    probe_frames = {}
    for i = 1, #cands do probe_frames[i] = 0 end
    return   -- el probe corre en on_frame hasta probe_sak
  end
  -- sin API de dominios (FBNeo): igualar al viejo fallback calibrado
  if rw(P1B + 0x44) == 0 and rw(P1B + 0xB8) == 0 and rb(P1B + 0x71) == 0 then
    if rw(0x008400 + 0x44) ~= 0 or rb(0x008400 + 0x71) ~= 0 then
      P1B, P2B = 0x008400, 0x008800
      PAG_DESDE, PAG_HASTA = 0x00A000, 0x00A0FF
      FSM_P1, FSM_P2 = 0x0085B0, 0x0089B0
      modo = "fallback"
      DOMINIO = "(FBNeo)"
    end
  end
end

local DOMUS_PLENITUD = { [0x07]=1,[0x08]=1,[0x0D]=1,[0x0E]=1,
                         [0x28]=1,[0x29]=1,[0x2A]=1,[0x30]=1 }

local function cerrar_probe()
  local total = probe_sak - 40 + 1
  local res, mejorN, mejoroff = {}, -1, nil
  local sbus, sram = probe_frames[1] or 0, probe_frames[2] or 0
  for i = 1, #probe_cand do
    local cand = probe_cand[i]
    res[#res + 1] = string.format("%s@%+d=%d/%d", cand.orig, cand.off, probe_frames[i], total)
    if probe_frames[i] > mejorN then
      mejorN, mejoroff = probe_frames[i], cand.off
    end
  end
  loga("probe $5F(P1) por candidato: " .. table.concat(res, " | "))
  if mejorN >= 20 then
    -- fijar el dominio del ganador y clarificar el modo
    local ganador
    for i = 1, #probe_cand do
      if probe_frames[i] == mejorN then ganador = probe_cand[i] break end
    end
    local ok = fija_dominio(ganador.orig)
    if ok then
      aplicar(ganador.off)
    else
      loga("(!) dominio ganador no fijable; sigo en el actual")
      modo, DOMINIO = "actual", "(actual)"
    end
  else
    loga("(!) probe debil: sigo en el dominio ACTUAL (en BizHawk con core")
    loga("    Genesis el M68K BUS suele mapear lineal y anda bien)")
  end
end

local function titulo()
  -- identidad del ROM cargado: checksum del header ($018E) leido DOCTO
  -- del dominio de cartucho (no cambia el dominio activo)
  local cs, nom = 0, "???"
  pcall(function()
    cs = memory.read_u16(0x18E, "MD CART")
  end)
  loga(string.format(
    "SONDA v%s | rom checksum=$%04X | modo=%s dominio=%s tam=%d | addr=%+d | bases P1=%06X P2=%06X | pagina %06X-%06X | FSM P1=%06X",
    VERSION, cs, modo, tostring(DOMINIO), TAMDOM, OFF, P1B, P2B, PAG_DESDE, PAG_HASTA, FSM_P1))
  loga("(la identidad EXACTA del build esta en $FFA0F0; se reporta en vivo)")
end

-- ---- el resto ---------------------------------------------------------
local pag_vieja
local mando_viejo
local char_viejo
local fsm_viejo, f5f_viejo, f6b_viejo
local bid_viejo, fire_viejo
local frame = 0

DOMINIO_FIJO = ""   -- forzar: el nombre EXACTO que imprime la lista

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
end

local function on_frame()
  frame = frame + 1
  if frame == 1 then
    fija_bases()
    if DOMINIO_FIJO ~= "" then
      if fija_dominio(DOMINIO_FIJO) then
        TAMDOM = tam_de(DOMINIO_FIJO)
        OFF = (TAMDOM == 0x10000) and -0xFF0000 or 0
        modo = "fijado"
      end
    end
  end

  if probe_cand and frame <= probe_sak then
    local idx = ((frame - 1) % #probe_cand) + 1
    local cand = probe_cand[idx]
    local v
    pcall(function()
      v = memory.readbyte((0xFF8400 + 0x5F + cand.off) % 0x1000000, cand.orig)
    end)
    if v and DOMUS_PLENITUD[v] then probe_frames[idx] = probe_frames[idx] + 1 end
    if frame == 40 and not probe_titulo then
      probe_titulo = true
      loga(string.format("SONDA v%s (probe f40-%d en marcha; dejalo quieto)",
        VERSION, probe_sak))
    end
    if frame == probe_sak then
      cerrar_probe()
      probe_cand, probe_frames = nil, nil
      titulo()
    end
  end

  if probe_cand then
    mando_viejo, pag_vieja, char_viejo = nil, nil, nil
  end

  local b71 = rb(P1B + 0x71)
  local mando = b71 * 0x1000000 + rb(P1B + 0x72) * 0x10000
             + rb(P1B + 0x73) * 0x100 + rb(P1B + 0x74)
  if probe_cand == nil then
    -- calibracion del ID
    local w92 = rb(P1B + 0x92) * 0x100 + rb(P1B + 0x93)
    if w92 ~= char_viejo then
      loga(string.format(
        "[f %d] CHAR P1: $92(word) %04X->%04X",
        frame, char_viejo or 0, w92))
      char_viejo = w92
    end
    -- watch de estado del struct P1 (la v1: $5F/$6B/FSM)
    local f5f, f6b, fsm = rb(P1B + 0x5F), rb(P1B + 0x6B), rb(FSM_P1)
    if fsm ~= fsm_viejo and frame > 60 then
      loga(string.format("[f %d] FSM(P1): %02X -> %02X", frame, fsm_viejo or 0, fsm))
    end
    if f5f ~= f5f_viejo and frame > 60 then
      loga(string.format("[f %d] P1 $5F: %02X -> %02X  (FSM=%02X $6B=%02X $71=%02X)",
        frame, f5f_viejo or 0, f5f, fsm, f6b, b71))
    end
    if f6b ~= f6b_viejo and frame > 60 then
      loga(string.format("[f %d] P1 $6B: %02X -> %02X", frame, f6b_viejo or 0, f6b))
    end
  -- identidad del build en vivo + marca de disparo del stub
    local bid, fmark = rb(0xFFA0F0), rb(0xFFA0F1)
    if bid ~= bid_viejo and frame > 60 then
      local nb = ({[0x01]='A FSM_A0',[0x02]='B AUTODIVE',[0x03]='C VELONLY',
                   [0x04]='D NOMANA',[0x05]='E NOFIRE',
                   [0x06]='F1 AD armador 5D=2',[0x07]='F2 AD armador 5D=28',
                   [0x08]='F3 AD armador cost8',[0x09]='F4 AD armador cost14',
                   [0x0A]='F5 AD armador FREE'})[bid] or '???'
      loga(string.format('[f %d] BUILD STUB: $%02X (%s)', frame, bid, nb))
    end
    if fmark ~= fire_viejo and frame > 60 then
      if fmark == 0x10 then
        loga(string.format('[f %d] ** DISPARO del stub ejecutado **', frame))
      elseif fire_viejo == 0x10 then
        loga(string.format('[f %d] marca de disparo apagada', frame))
      end
    end
    bid_viejo, fire_viejo = bid, fmark
    fsm_viejo, f5f_viejo, f6b_viejo = fsm, f5f, f6b

    if mando ~= mando_viejo then
      if mando_viejo then
        local mv71 = math.floor(mando_viejo / 0x1000000) % 0x100
        loga(string.format(
          "[f %d] MANDO: $71 %s->%s  $72=%02X $73=%02X $74=%02X  $5F=%02X  Y=%04X  $76=%02X  FSM=%02X",
          frame, hex2(mv71), hex2(b71), rb(P1B + 0x72), rb(P1B + 0x73), rb(P1B + 0x74),
          rb(P1B + 0x5F), rw(P1B + 0x44), rb(P1B + 0x76), rb(FSM_P1)))
      end
      if frame > 60 then
        local nueva = snapshot_pagina()
        if pag_vieja ~= nil then
          vuelca_diff(pag_vieja, nueva, "pagina buzon/globals")
        end
        pag_vieja = nueva
      end
    end

    -- OSD EN PANTALLA: lo que importa se ve EN EL JUEGO, sin consola
    pcall(function()
      local aire = (f5f == 0x0D or f5f == 0x08 or f5f == 0x0E)
      local bajo = (b71 % 4 >= 2)   -- bit1 de $71 = abajo
      gui.drawText(10, 10, string.format("SONDA v5 | 5F=%02X %s | FSM=%d | %s",
        f5f, aire and "AIRE" or "PISO", fsm, bajo and "ABAJO" or "-"),
        0xFFFFFFFF, 0x80000000, 14)
      if aire and fsm == 0 then
        gui.drawText(10, 34, "AIRE: tocá ABAJO, soltá, tocá de nuevo",
          0xFFFFFF00, 0x80000000, 18)
      elseif aire and fsm == 1 then
        gui.drawText(10, 34, "soltá ABAJO y tocá otra vez!",
          0xFF00FF00, 0x80000000, 18)
      elseif aire and fsm == 2 then
        gui.drawText(10, 34, "ARMADO: tocá ABAJO = DIVE!",
          0xFFFF8000, 0x80000000, 20)
      end
    end)
  end
  mando_viejo = mando
end

while true do
  on_frame()
  emu.frameadvance()
end
