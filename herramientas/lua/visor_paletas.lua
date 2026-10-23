-- =====================================================================
-- visor_paletas.lua  v1 -- VER TODAS LAS PALETAS DE UN PJ (y del aura)
--                       BizHawk core Genesis; tambien FBNeo/Fightcade
--                     (misma API que sonda_efectos.lua)
-- =====================================================================
-- QUE HACE, cada frame:
--   1. Fuerza el NUMERO DE PALETA (bits 14-13) del word $24 del player
--      slot ($FF8400=P1 / $FF8800=P2). El resto del word se conserva
--      (tile index, prioridad bit 15). El juego re-escribe $24 cada
--      frame, asi que se re-fuerza siempre.
--   2. Modo CICLAR: cambia la paleta sola cada CICLO frames = se ven
--      TODAS las combinaciones sin tocar nada.
--   3. AURA_FUERZA: recolorea TAMBIEN los clones del aura vivos en el
--      pool ($FF9400, 16 slots de $80, ID $20). El ROM parcheado pinta
--      al aura en paleta 1 fija; esto lo pisa EN VIVO desde Lua, o sea
--      se ve el aura en paleta 0-3 sin rearmar el ROM.
--   4. Dibuja en pantalla las 4 paletas de CRAM (4x16 colores) para
--      saber de que color es cada numero.
-- TECLAS:  J = paleta siguiente (0-3)   K = jugador (P1/P2/AMBOS)
--          L = ciclar on/off            O = forzar on/off
--          (se pueden cambiar en TECLAS abajo; si el core ignora la
--          tecla, pon otra letra)
-- =====================================================================

local TECLAS = { paleta = "J", jugador = "K", ciclar = "L", toggle = "O" }

-- ------- configuracion que viene puesta al cargar -------
local PALETA_INI = 1      -- paleta 0-3 al arrancar
local OBJETIVO_INI = "P1" -- "P1" | "P2" | "AMBOS"
local CICLAR_INI = true   -- cambiar la paleta solo, cada CICLO frames
local CICLO   = 30        -- frames por paleta en modo ciclar
local FORZAR_INI = true   -- forzar el color en players (se apaga con O)
local AURA_FUERZA = true  -- recolorear los clones del aura (ID $20)

-- ---------------------------------------------------------------------
local state = {
  paleta = PALETA_INI, objetivo = OBJETIVO_INI,
  ciclar = CICLAR_INI, forzar = FORZAR_INI, tick = 0,
}

-- helpers con pcall: si la direccion no existe en el dominio, no explota
local function rw(a) local ok, v = pcall(memory.readword, a); if ok and type(v)=="number" then return v end return nil end
local function rb(a) local ok, v = pcall(memory.readbyte, a); if ok and type(v)=="number" then return v end return nil end
local function wr(a, v) pcall(memory.writeword, a, v) end
local function dice(s) print(s) end

-- anchors DOBLES: BizHawk indexa el dominio "68K RAM" desde 0, FBNeo con
-- direccion real $FFxxxx. Con pcall, solo uno de los dos existe: escribir
-- a los dos es inofensivo.
local PJ = { { "P1", 0xFF8400, 0x008400 }, { "P2", 0xFF8800, 0x008800 } }
local POOL = { 0xFF9400, 0x009400 }

-- $24 del record/player: bits 14-13 = numero de paleta, bit 15 = prioridad
local function mezcla_paleta(v, p)
  local prio = (v >= 0x8000) and 0x8000 or 0
  return (v % 0x2000) + 0x2000 * p + prio
end

local function puede_pal(a)   -- hay word vivo en $24 (evita pisar basura de menu)
  local hp = rw(a + 0x78)
  return hp ~= nil and hp >= 1 and hp < 0x8000
end

-- fuerza la paleta en TODOS los anchors (el que existe, lo toma)
local function fuerza_pj(a1, a2, p)
  for _, a in ipairs({ a1, a2 }) do
    local v = rw(a + 0x24)
    if v ~= nil then wr(a + 0x24, mezcla_paleta(v, p)) end
  end
end

-- ---------------------------------------------------------------------
-- los clones del aura en el pool (solo anchors que tengan $4=$0080/$58=$20)
-- ---------------------------------------------------------------------
local marcaditos = {}          -- [anchor] = { [slot]=true }
local function fuerza_aura(p)
  for _, base in ipairs(POOL) do
    local hay = false
    for i = 0, 15 do
      local s = base + i * 0x80
      local sz = rw(s + 4)
      if sz == 0x0080 and rb(s + 0x58) == 0x20 then
        hay = true
        local v = rw(s + 0x24)
        if v ~= nil then
          local nuevo = mezcla_paleta(v, p)
          if nuevo ~= v then wr(s + 0x24, nuevo) end
        end
      end
    end
    if hay then
      local t = marcaditos[base]
      if t and t.paleta and t.paleta ~= p then
        dice(string.format("aura pool $%06X: re-coloreando a paleta %d", base, p))
      end
      marcaditos[base] = { paleta = p }
    end
  end
end

-- ---------------------------------------------------------------------
-- teclado (edge: un solo disparo por presion)
-- ---------------------------------------------------------------------
local pres_ante = {}
local function toca(k)
  local ok, i = pcall(input.get)
  if not ok or type(i) ~= "table" then return false end
  local v = i[k]
  local ahora = (v == true) or (type(v) == "number" and v > 0)
  if ahora and not pres_ante[k] then pres_ante[k] = true; return true end
  if not ahora then pres_ante[k] = false end
  return false
end

-- ---------------------------------------------------------------------
-- CRAM en pantalla: 4 paletas x 16 colores. Si no existe el dominio
-- "CRAM" en este core, se saltea con un aviso.
-- ---------------------------------------------------------------------
local cram_cache = nil
local cram_aviso = false
local function lee_cram()
  local okd, dom_ante = pcall(memory.getcurrentmemorydomainname)
  local ok = pcall(memory.usememorydomain, "CRAM")
  if not ok then return nil end
  local okr, dom = pcall(memory.getcurrentmemorydomainname)
  if not okr or dom ~= "CRAM" then return nil end
  local filas = {}
  for p = 0, 3 do
    local fila = {}
    for c = 0, 15 do
      local okv, v = pcall(memory.readword, (p * 16 + c) * 2)
      fila[#fila + 1] = okv and v or 0
    end
    filas[#filas + 1] = fila
  end
  pcall(memory.usememorydomain, okd and dom_ante or "68K RAM")   -- volver
  return filas
end

local function dibuja_cram()
  local filas = lee_cram()
  if not filas then
    if not cram_aviso and state.tick % 600 == 1 then
      dice("visor paletas: sin dominio CRAM en este core: solo texto")
      cram_aviso = true
    end
    return
  end
  local p_sel = state.paleta
  for p, fila in ipairs(filas) do
    local y = 150 + (p - 1) * 16
    pcall(gui.text, 6, y + 1, p == (p_sel + 1) and ">" or " ")
    for c, v in ipairs(fila) do
      -- genesis: 0000 BBB GGG RRR = 3 bits por canal
      local r = (v % 8) * 36
      local g = (math.floor(v / 8) % 8) * 36
      local b = (math.floor(v / 64) % 8) * 36
      pcall(gui.drawRectangle, 20 + (c - 1) * 15, y, 12, 12, "black",
        string.format("#%02x%02x%02x", r, g, b))
    end
    pcall(gui.text, 20 + 16 * 15 + 6, y + 1, "P" .. (p - 1))
  end
end

-- ---------------------------------------------------------------------
-- el frame
-- ---------------------------------------------------------------------
local function cada_frame()
  state.tick = state.tick + 1

  if toca(TECLAS.paleta) then state.paleta = (state.paleta + 1) % 4 end
  if toca(TECLAS.jugador) then
    state.objetivo = (state.objetivo == "P1" and "P2") or
                     (state.objetivo == "P2" and "AMBOS") or "P1"
  end
  if toca(TECLAS.ciclar) then state.ciclar = not state.ciclar; print("ciclar="..tostring(state.ciclar)) end
  if toca(TECLAS.toggle) then state.forzar = not state.forzar; print("forzar="..tostring(state.forzar)) end
  if state.ciclar and state.tick % CICLO == 0 then
    state.paleta = (state.paleta + 1) % 4
  end

  local p = state.paleta
  local forzado = {}

  -- players
  if state.forzar then
    for _, d in ipairs(PJ) do
      if state.objetivo == "AMBOS" or state.objetivo == d[1] then
        fuerza_pj(d[2], d[3], p)
        forzado[#forzado + 1] = d[1]
      end
    end
  end

  -- clones del aura en el pool
  if state.forzar and AURA_FUERZA then fuerza_aura(p) end

  -- cartel + mosaicos de color
  local cartel = string.format(
    "VISOR PALETAS  pj=%s  paleta=%d%s  aura=%s  [J]paleta  [K]pj  [L]ciclar  [O]forzar",
    state.objetivo, p,
    state.ciclar and (" (cada " .. CICLO .. "f)") or "",
    AURA_FUERZA and tostring(p) or "ROM(1)")
  pcall(gui.text, 6, 6, cartel)
  pcall(gui.text, 6, 18, "forzando: " ..
    (#forzado > 0 and table.concat(forzado, "+") or (state.forzar and "-" or "apagado")))
  dibuja_cram()
end

-- ---------------------------------------------------------------------
-- hook de frame (mismo esquema que sonda_efectos.lua)
-- ---------------------------------------------------------------------
local function esfn(v)
  local t = type(v)
  return t == "function" or t == "userdata"   -- BizHawk moderno: userdata
end
local callback_usado = nil
local hooks = {
  { "event.onframeend",   (type(event) == "table" and esfn(event.onframeend)) and event.onframeend   or nil },
  { "event.onframestart", (type(event) == "table" and esfn(event.onframestart)) and event.onframestart or nil },
  { "emu.registerafter",  (type(emu) == "table" and esfn(emu.registerafter))  and emu.registerafter  or nil },
  { "gui.register",       (type(gui) == "table" and esfn(gui.register))       and gui.register       or nil },
}
for _, h in ipairs(hooks) do
  if h[2] then
    local ok = pcall(h[2], cada_frame)
    if ok then callback_usado = h[1] break end
  end
end
dice(string.format("VISOR PALETAS v1 CARGADA (callback=%s, teclas %s/%s/%s/%s). Si no ves el cartel, recarga el script.",
  tostring(callback_usado), TECLAS.paleta, TECLAS.jugador, TECLAS.ciclar, TECLAS.toggle))
