-- =====================================================================
-- sonda_efectos.lua  v3 -- EL POOL DE OBJETOS: donde vive y que IDs hay
--                     (para FBNeo / Fightcade)
-- =====================================================================
-- AL CARGAR imprime el banner SONDA EFECTOS v3. Si no lo ves, el script
-- no esta corriendo: recarga (Archivo -> Lua -> cargar de nuevo).
-- Latido cada 300 frames: "[SONDA viva: modo ...]" para que sepas que anda.
--
-- MODOS (cambialo ACA ARRIBA y recarga el script):
--   MODO = "datos"   solo informa (escaneo + spawns en vivo)
--   MODO = "clonar"  duplica un efecto vivo a un slot libre (+128 en X)
--   MODO = "aura"    inyecta el efecto AURA_ID sobre el jugador MIENTRAS
--                    esta en el plano de atras (prototipo de la v9)
--
-- La inyeccion del aura copia del JUGADOR los campos que el llamador
-- real copia (tiles/paleta $24, plano $26, escala $3E) porque la rama del
-- ID en la tabla $14A00 SOLO hace un ORI sobre $24 (visto en el ROM:
-- $14D08, rama del $1D).
-- =====================================================================

local VERSION = "v3"

local MODO           = "datos"  -- "datos" | "clonar" | "aura"

-- ------- clonar -------
local CLON_CADA      = 90       -- cada cuantos frames busca clonar
local CLON_DX        = 0x0080   -- corrimiento de X del clon

-- ------- aura -------
local AURA_ID        = 0x1D     -- el efecto (el que pidio el usuario)
local AURA_CADA      = 16       -- re-inyectar cada N frames (vive ~50)
local AURA_DY        = 0x0000   -- offset de Y sobre la posicion del pj
local AURA_DESTINO   = "P1"     -- "P1" | "P2" | "AMBOS"

local MAXLINEAS      = 120

-- los handlers que se conocen
local HANDLERS = {
  [0x0149AC] = "grande",
  [0x014EC6] = "polvo",
  [0x014930] = "flash-combo",
  [0x013E9A] = "g Alejandro (13E9A)",
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

local function escanea()
  dice("=====================================================================")
  dice("SONDA EFECTOS " .. VERSION .. ": buscando slots (handler + $4 = $0080)")
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

  local function chequea(base, nombre)
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

  local sumA = chequea(0xFF9400, "A: $FF9400")
  local sumB = chequea(0x009400, "B: $009400")

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
    dice("  (aun sin efecto vivo: arranca la pelea y recarga el script)")
  elseif #matches > 40 then
    for i = 1, 40 do dice(matches[i]) end
    dice(string.format("  (...y %d mas)", #matches - 40))
  else
    for _, m in ipairs(matches) do dice(m) end
  end
  dice("=====================================================================")
end

-- ---------------------------------------------------------------------
-- 2) el vivo: spawns que pasan
-- ---------------------------------------------------------------------
local tick = 0
local ult_estado = {}
local ult_cursor = nil

local function slot_base(i, base) return base + i * 0x80 end

local function vivo(base)
  local c = rw(0xFFA036)
  if c ~= ult_cursor then
    ult_cursor = c
  end

  for i = 0, 15 do
    local a = slot_base(i, base)
    local sz = rw(a + 4)
    local prev = ult_estado[i]
    if prev then
      if prev == 0 and sz == 0x0080 then
        dice(string.format("[f %5d] SPAWN slot %2d ($%06X): handler $%06X  ID=$%02X  pos=$%04X,%04X  tabla=$%06X",
          tick, i, a, rdw(a), rb(a + 0x58), rw(a + 0x40), rw(a + 0x44), rdw(a + 0x1C)))
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

  -- una sola vez por recarga: aviso de que el modo esta activo
  if not clon_aviso then
    dice(string.format("[f %5d] modo CLONAR listo: busco efecto vivo para clonar...", tick))
    clon_aviso = true
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
-- 4) el aura: el efecto AURA_ID sobre el jugador envenenado
-- ---------------------------------------------------------------------
-- Condicion: parado en el plano de atras ($9C = 304) y con vida.
-- La inyeccion: $0 = handler $149AC, $4 = $0080, $6 = 0 (init),
-- $58 = AURA_ID, $40/$44 = posicion del pj (+DY), y $24/$26/$3E
-- copiados del JUGADOR (eso es lo que hacen los llamadores reales; la
-- rama del ID solo hace un ORI sobre $24, comprobado en $14D08).

local slots_pj = { P1 = 0xFF8400, P2 = 0xFF8800 }

local function inyecta_aura(b, px, py, quien, sx, sy)
  -- limpiar el record
  for o = 0, 0x7E, 2 do wr(b + o, 0) end
  wr(b + 0, 0x0149)              -- longword 0 = $00149AC
  wr(b + 2, 0x09AC)
  wr(b + 4, 0x0080)
  wr(b + 6, 0)                   -- init en el proximo pase del dispatcher
  wr(b + 0x24, rw(sx + 0x24))    -- tiles/paleta DEL JUGADOR (lo que copian los llamadores)
  wr(b + 0x26, rw(sx + 0x26))    -- plano
  wr(b + 0x3E, rw(sx + 0x3E))    -- escala
  wb(b + 0x58, AURA_ID)
  wr(b + 0x40, px)
  wr(b + 0x44, py + AURA_DY)
  dice(string.format("[f %5d] AURA (%s): ID=$%02X en slot $%06X  pos=$%04X,%04X  $24=$%04X",
    tick, quien, AURA_ID, b, px, py, rw(sx + 0x24)))
end

local aura_conto = AURA_CADA
local aura_sin_slot_avisado = false

local function aura(base)
  aura_conto = aura_conto - 1
  if aura_conto > 0 then return end
  aura_conto = AURA_CADA

  local destinos = {}
  if AURA_DESTINO == "P1" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P1", slots_pj.P1 } end
  if AURA_DESTINO == "P2" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P2", slots_pj.P2 } end

  local puso = false
  for _, d in ipairs(destinos) do
    local a = d[2]
    local hp = rw(a + 0x78)
    local suelo = rw(a + 0x9C)
    if suelo == 304 and hp >= 1 then
      -- buscar slot libre
      for j = 0, 15 do
        local b = slot_base(j, base)
        if rw(b + 4) == 0 then
          inyecta_aura(b, rw(a + 0x40), rw(a + 0x44), d[1], a, a)
          puso = true
          break
        end
      end
      if not puso and not aura_sin_slot_avisado then
        dice(string.format("[f %5d] AURA (%s): pool LLENO, no hay slot libre", tick, d[1]))
        aura_sin_slot_avisado = true
      end
    end
  end
end

-- ---------------------------------------------------------------------
-- el frame
-- ---------------------------------------------------------------------
local function cada_frame()
  tick = tick + 1

  if tick % 300 == 0 then
    dice(string.format("[SONDA viva: modo=%s  pool=$%s]", MODO,
      base_detectada and string.format("%06X", base_detectada) or "?"))
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
dice(string.format("SONDA EFECTOS %s CARGADA (modo %s). Con la pelea arrancada si no detecta el pool, escané de nuevo en ~3 s.", VERSION, MODO))
