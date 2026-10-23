-- =====================================================================
-- sonda_efectos.lua  v4 -- EL POOL DE OBJETOS: donde vive y que IDs hay
--                     (para FBNeo / Fightcade)
-- =====================================================================
-- AL CARGAR imprime el banner SONDA EFECTOS v4. Si no lo ves, el script
-- no esta corriendo: recarga (Archivo -> Lua -> cargar de nuevo).
-- Latido cada 300 frames: "[SONDA viva: modo ...]".
--
-- MODOS (vienen puestos en la cabecera; recarga el script al cambiarlo):
--   MODO = "datos"   solo informa + CAPTURA: si aparece un SPAWN con el
--                    ID de AURA_ID, VUELCA el record entero ($80 bytes)
--                    en hex: ES LA PLANTILLA para el parche v9.
--   MODO = "clonar"  duplica un efecto vivo a un slot libre (+128 en X)
--   MODO = "aura"    cuando aparece un effecto ID=AURA_ID VIVO en el
--                    pool, lo CLONA COMPLETO (record entero, nada
--                    inventado) a un slot libre y le pone la posicion
--                    DEL JUGADOR. Se dispara mientras el jugad�다 esta
--                    en el plano de atras (el condicion del veneno).
--
-- HISTORICO v3: la inyeccion sintetica ($24/$26/$3E copiados del PLAYER)
-- pinto la pantalla de NEGRO: los campos del player NO son los del
-- objeto (el $24 del jugador es otra cosa). Por eso la v4 no inventa
-- nada: clona records reales completos.
-- =====================================================================

local VERSION = "v4"

local MODO           = "aura"   -- "datos" | "clonar" | "aura"

-- ------- clonar -------
local CLON_CADA      = 90       -- cada cuantos frames busca clonar
local CLON_DX        = 0x0080   -- corrimiento de X del clon

-- ------- aura / captura -------
local AURA_ID        = 0x10     -- el polvo del walking (spawnea de a 2, Y $0140)
local AURA_CADA      = 16       -- cada cuantos frames del veneno intenta clonar
local AURA_DY        = 0x0000   -- offset de Y sobre la posicion del pj
local AURA_DESTINO   = "P1"     -- "P1" | "P2" | "AMBOS"
local AURA_CICLAR    = true     -- cada clon sale con la paleta SIGUIENTE (0-3)
local AURA_PALETA    = 1        -- si AURA_CICLAR es false: paleta fija (0-3)

local MAXLINEAS      = 150

-- los handlers que se conocen
local HANDLERS = {
  [0x0149AC] = "grande",
  [0x014EC6] = "polvo",
  [0x014930] = "flash-combo",
  [0x013E9A] = "13E9A",
}

local SCAN_INI = 0xFF8000
local SCAN_FIN = 0xFFC000

-- ---------------------------------------------------------------------
-- la RAM
-- ---------------------------------------------------------------------
local function rb(a) local ok, v = pcall(memory.readbyte, a); if ok then return v end return 0 end
local function rw(a) local ok, v = pcall(memory.readword, a); if ok then return v end return 0 end
local function wr(a, v) pcall(memory.writeword, a, v) end
local function wb(a, v) pcall(memory.writebyte, a, v) end

local function rdw(a)
  local ok, v = pcall(memory.readdword, a)
  if ok and type(v) == "number" then return v end
  local hi, lo = rw(a), rw(a + 2)
  if hi and lo then return hi * 65536 + lo end
  return 0
end

local function dice(s) print(s) end

-- ---------------------------------------------------------------------
-- 1) el escaneo de bases
-- ---------------------------------------------------------------------
local base_detectada = nil

local function chequea16(base, nombre)
  local libres, ocupados = 0, 0
  for i = 0, 15 do
    local f = rw(base + i * 0x80 + 4)
    if f == 0x0080 then ocupados = ocupados + 1
    elseif f == 0 then libres = libres + 1 end
  end
  dice(string.format("  candidato %s: %d libres + %d ocupados = %d (el pool suma 16)",
    nombre, libres, ocupados, libres + ocupados))
  return libres + ocupados
end

local function escanea()
  dice("=====================================================================")
  dice(string.format("SONDA EFECTOS %s: buscando slots (handler + $4 = $0080)", VERSION))
  dice("=====================================================================")

  local matches = {}
  local a = SCAN_INI
  while a < SCAN_FIN do
    local lw = rdw(a)
    if HANDLERS[lw] then
      matches[#matches + 1] = string.format("  $%06X  handler $%06X (%s)  $4=$%04X  $58=$%02X  $6=$%04X",
        a, lw, HANDLERS[lw], rw(a + 4), rb(a + 0x58), rw(a + 6))
    end
    a = a + 0x20
  end

  local sumA = chequea16(0xFF9400, "A: $FF9400")
  local sumB = chequea16(0x009400, "B: $009400")

  if sumA == 16 and sumB ~= 16 then
    base_detectada = 0xFF9400
    dice(">> VEREDICTO: el pool es $FF9400")
  elseif sumB == 16 and sumA ~= 16 then
    base_detectada = 0x009400
    dice(">> VEREDICTO: el pool es $009400")
  else
    dice(">> Ningun candidato suma 16; mirá los matches de arriba.")
  end

  if #matches == 0 then
    dice("  (aun sin efecto vivo: dispara un especial y recarga)")
  elseif #matches > 40 then
    for i = 1, 40 do dice(matches[i]) end
    dice(string.format("  (...y %d mas)", #matches - 40))
  else
    for _, m in ipairs(matches) do dice(m) end
  end
  dice("=====================================================================")
end

-- ---------------------------------------------------------------------
-- 2) el vivo: spawns de efectos con log y CAPTURA del record
-- ---------------------------------------------------------------------
local tick = 0
local ult_estado = {}

local function slot_base(i, base) return base + i * 0x80 end

local function vuelca_record(a, etiqueta)
  dice(string.format("  CAPTURA %s del slot $%06X (record completo, $80 bytes):", etiqueta or "", a))
  local lineas = {}
  for o = 0, 0x7E, 16 do
    local hex = {}
    for k = 0, 15, 2 do
      hex[#hex + 1] = string.format("%04X", rw(a + o + k))
    end
    dice(string.format("    +%02X: %s", o, table.concat(hex, " ")))
  end
end

local function vivo(base)
  for i = 0, 15 do
    local a = slot_base(i, base)
    local sz = rw(a + 4)
    local prev = ult_estado[i]
    if prev then
      if prev == 0 and sz == 0x0080 then
        local did = rb(a + 0x58)
        dice(string.format("[f %5d] SPAWN slot %2d ($%06X): handler $%06X  ID=$%02X  pos=$%04X,%04X  tabla=$%06X",
          tick, i, a, rdw(a), did, rw(a + 0x40), rw(a + 0x44), rdw(a + 0x1C)))
        -- CAPTURA: si es el ID que busca el aura, volcar el record entero
        if did == AURA_ID then
          vuelca_record(a, "ID=" .. string.format("$%02X", did))
        end
      elseif prev == 0x0080 and sz == 0 then
        dice(string.format("[f %5d] muere slot %2d ($%06X)", tick, i, a))
      end
    end
    ult_estado[i] = sz
  end
end

-- ---------------------------------------------------------------------
-- 3) clonar: efecto vivo -> copia en slot libre, corrida en X
-- ---------------------------------------------------------------------
local clon_cooldown = CLON_CADA
local clon_aviso = false

local function clona(base)
  if clon_cooldown > 0 then clon_cooldown = clon_cooldown - 1 return end
  if not clon_aviso then
    dice(string.format("[f %5d] modo CLONAR listo: busco efecto vivo para clonar...", tick))
    clon_aviso = true
    clon_cooldown = CLON_CADA
    return
  end

  for i = 0, 15 do
    local a = slot_base(i, base)
    if rw(a + 4) == 0x0080 then
      for j = 0, 15 do
        local b = slot_base(j, base)
        if j ~= i and rw(b + 4) == 0 then
          for o = 0, 0x7E, 2 do wr(b + o, rw(a + o)) end
          wr(b + 0x40, rw(a + 0x40) + CLON_DX)
          wr(b + 0x44, rw(a + 0x44))
          dice(string.format("[f %5d] CLON: slot %d (ID=$%02X) -> slot %d en +$%03X de X",
            tick, i, rb(a + 0x58), j, CLON_DX))
          clon_cooldown = CLON_CADA
          return
        end
      end
      clon_cooldown = CLON_CADA
      return
    end
  end
end

-- ---------------------------------------------------------------------
-- 4) el aura: CLONAR un ID=AURA_ID vivo y ponerlo sobre el jugador
-- ---------------------------------------------------------------------
-- NADA SINTETICO: cuando un efecto ID=AURA_ID esta vivo en el pool (le
-- toca al juego haberlo spawneado con sus datos COMPLETOS), se copia el
-- record entero a un slot libre y su posicion pasa a ser la del jugador.
-- Condicion del jugador: parado en el plano de atras ($9C = 304) con vida.

local slots_pj = { P1 = 0xFF8400, P2 = 0xFF8800 }

local aura_conto = AURA_CADA
local aura_esperando_aviso = false
local aura_paleta_n = 0

local function aura(base)
  aura_conto = aura_conto - 1
  if aura_conto > 0 then return end
  aura_conto = AURA_CADA

  -- el jugador pasa por el veneno?
  local destinos = {}
  if AURA_DESTINO == "P1" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P1", slots_pj.P1 } end
  if AURA_DESTINO == "P2" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P2", slots_pj.P2 } end

  local pj_inyectado = nil
  for _, d in ipairs(destinos) do
    local a = d[2]
    local hp = rw(a + 0x78)
    local suelo = rw(a + 0x9C)
    if suelo == 304 and hp >= 1 then
      pj_inyectado = { quien = d[1], x = rw(a + 0x40), y = rw(a + 0x44) }
      break
    end
  end
  if not pj_inyectado then
    aura_esperando_aviso = false
    return
  end

  -- buscar una fuente viva del ID pedido
  local fuente = nil
  for i = 0, 15 do
    local a = slot_base(i, base)
    if rw(a + 4) == 0x0080 and rb(a + 0x58) == AURA_ID then fuente = a break end
  end
  if not fuente then
    if not aura_esperando_aviso then
      dice(string.format("[f %5d] AURA: el jugador pasa por veneno, pero no hay un ID=$%02X vivo (esperando que el juego spawnee uno)", tick, AURA_ID))
      aura_esperando_aviso = true
    end
    return
  end

  -- buscar slot libre para el clon
  for j = 0, 15 do
    local b = slot_base(j, base)
    if rw(b + 4) == 0 then
      for o = 0, 0x7E, 2 do wr(b + o, rw(fuente + o)) end
      wr(b + 0x40, pj_inyectado.x)
      wr(b + 0x44, pj_inyectado.y + AURA_DY)
      -- cambio de color: bits 13-14 de $24 = numero de paleta VDP (aritmetica
      -- pura, sin lib bit), preservando el bit 15 (prioridad)
      local p = AURA_CICLAR and aura_paleta_n or AURA_PALETA
      local v24 = rw(b + 0x24)
      local prio = ((v24 or 0) >= 0x8000) and 0x8000 or 0
      local nuevo = ((v24 or 0) % 0x2000) + 0x2000 * p + prio
      wr(b + 0x24, nuevo)
      if AURA_CICLAR then aura_paleta_n = (aura_paleta_n + 1) % 4 end
      dice(string.format("[f %5d] AURA (%s): clon del ID=$%02X (slot $%06X) sobre el pj pos=$%04X,%04X -> slot $%06X  PALETA=%d ($24 $%04X->$%04X)",
        tick, pj_inyectado.quien, AURA_ID, fuente, pj_inyectado.x, pj_inyectado.y, b, p, v24 or 0, nuevo))
      return
    end
  end
  dice(string.format("[f %5d] AURA: pool LLENO (no hay slot libre para el clon)", tick))
end

-- ---------------------------------------------------------------------
-- el frame
-- ---------------------------------------------------------------------
local function cada_frame()
  tick = tick + 1

  if tick % 300 == 0 then
    dice(string.format("[SONDA viva: modo=%s  pool=%s]", MODO,
      base_detectada and string.format("$%06X", base_detectada) or "?"))
  end

  if base_detectada then
    vivo(base_detectada)
    if MODO == "clonar" then clona(base_detectada) end
    if MODO == "aura"   then aura(base_detectada) end
  elseif tick % 180 == 1 then
    escanea()
  end
end

escanea()
emu.registerafter(cada_frame)
dice(string.format("SONDA EFECTOS %s CARGADA (modo %s).", VERSION, MODO))
