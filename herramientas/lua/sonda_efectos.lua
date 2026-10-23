-- =====================================================================
-- sonda_efectos.lua -- EL POOL DE OBJETOS: donde vive y que IDs hay
--                     (para FBNeo / Fightcade)
-- =====================================================================
-- QUE HACE (el por que de cada cosa esta en
--           docs\01-MOTOR\OBJETOS-Y-EFECTOS.md):
--
--   1) ESCANEA la RAM buscando slots de efectos por firma: el longword 0
--      es el puntero al handler ($149AC / $14EC6 / $14930 / $13E9A) y el
--      word en +4 vale $0080. Prueba la DOS hipotesis de base:
--        A) $FF9400 (la que se docuento de oido)
--        B) $009400 (lo que da la aritmetica del allocator $1FAB4,
--                    el movea.w sign-extiende)
--      y reporta CON CUAL de las dos hay slots reales (o el DIAPO: si la
--      base real es otra, lo halla en el escaneo completo).
--
--   2) MODO CLONAR: cada CLONAR_CADA frames agarra un efecto VIVO del
--      pool, clona su record completo de $80 bytes en un slot LIBRE y
--      corre la posicion: el efecto deberia aparecer DOS VECES.
--      Si aparece: el mecanismo de "efecto donde yo quiera" queda
--      demostrado en juego. Si algo tira error/lag: aca sabemos donde.
--      OJO: es una venta experimental. Si el juego se rompe, apagar
--      CLONAR = false y listo (no toca nada mas).
--
-- MODOS (cambialo ACA ARRIBA y recarga el script):
--   MODO = "datos"   solo informa (escaneo + spawns en vivo)
--   MODO = "clonar"  escaneo + spawns + el clon
--   MODO = "aura"    AURA: inyecta el efecto ID=$1D sobre el jugador
--                    MIENTRAS ESTE EN EL PLANO DE ATRAS (condicion del
--                    veneno). Es el prototipo del parche v9, sin toccar
--                    el ROM. La cadencia y destino van en AURA_*. abajo.
-- =====================================================================

local MODO           = "datos"  -- "datos" | "clonar" | "aura"
local CLONAR         = (MODO == "clonar")

-- ------- los ajustes del aura -------
local AURA_ID        = 0x1D     -- el efecto (el del log del usuario)
local AURA_CADA      = 16       -- re-inyectar cada N frames (vive ~50 => 2-3 a la vez)
local AURA_DY        = 0x0000   -- visto bueno del Y (0 = la posicion del pj tal cual)
local AURA_DESTINO   = "P1"     -- "P1" | "P2" | "AMBOS"
-- -------------------------------------
local CLONAR_CADA    = 90       -- cada cuantos frames busca clonar
local CLON_DX        = 0x0080   -- corrimiento de X del clon (px? ver el juego usa 1:1 en $40/$44)
local MAXLINEAS      = 80

-- los handlers que se conocen (docs 01-MOTOR/OBJETOS-Y-EFECTOS.md)
local HANDLERS = {
  [0x0149AC] = "grande (chispa/proyector bases)",
  [0x014EC6] = "polvo/humo",
  [0x014930] = "flash del combo",
  [0x013E9A] = "wrapper muerto",
}
local HANDLER_JUGADOR = 0x00012668   -- para ubicar los slots de jugadores

-- regional de escaneo: los efectos viven cerca de los jugadores
local SCAN_INI = 0xFF8000
local SCAN_FIN = 0xFFC000

-- ---------------------------------------------------------------------
-- la RAM
-- ---------------------------------------------------------------------
local function rb(a)
  local ok, v = pcall(memory.readbyte, a)
  if ok and type(v) == "number" then return v end
  return nil
end

local function rw(a)
  local ok, v = pcall(memory.readword, a)
  if ok and type(v) == "number" then return v end
  return nil
end

local function rdw(a)   -- longword = 2 words (la de arriba Leo es el LOW first: little endian? el 68K es BIG endian)
  local ok, v = pcall(memory.readdword, a)
  if ok and type(v) == "number" then return v end
  local hi = rw(a)
  local lo = rw(a + 2)
  if hi and lo then return hi * 65536 + lo end
  return nil
end

local function dice(s)
  print(s)
end

-- ---------------------------------------------------------------------
-- 1) el escaneo de bases
-- ---------------------------------------------------------------------
local base_detectada = nil
local escaneo_hecho = false

local function es_handler_valido(lw)
  return HANDLERS[lw] ~= nil
end

local function escanea()
  dice("=====================================================================")
  dice("SONDA DE EFECTOS: buscando slots por firma (handler + $4 == $0080)")
  dice("=====================================================================")

  local matches = {}
  local a = SCAN_INI
  while a < SCAN_FIN do
    local lw = rdw(a)
    if lw and es_handler_valido(lw) then
      local four = rw(a + 4)
      matches[#matches + 1] = string.format("  $%06X  handler $%06X (%s)  $4=$%04X  $58=$%02X  $6=$%04X",
        a, lw, HANDLERS[lw] or "", four or 0, rb(a + 0x58) or 0, rw(a + 6) or 0)
    end
    a = a + 0x20
  end

  -- los dos candidatos, verificados slot por slot
  local function chequea_candidato(base, nombre)
    local libres, ocupados = 0, 0
    for i = 0, 15 do
      local slot = base + i * 0x80
      local four = rw(slot + 4)
      if four == 0x0080 then
        ocupados = ocupados + 1
      elseif four == 0 then
        libres = libres + 1
      end
    end
    dice(string.format("  candidato %s: 16 slots -> %d libres, %d ocupados (la suma debería ser 16 para que sea el pool)",
      nombre, libres, ocupados))
    return ocupados + libres
  end

  local sumA = chequea_candidato(0xFF9400, "A: $FF9400 (doc de oido)")
  local sumB = chequea_candidato(0x009400, "B: $009400 (aritmetica del allocator)")
  dice("")

  if #matches == 0 then
    dice("  (ningun slot con firma de efecto todavia: arranca una partida,")
    dice("   tiras un par de combos, y recarga el script)")
  else
    dice("  slots con firma de efecto encontrados:")
    if #matches > 40 then
      for i = 1, 40 do dice(matches[i]) end
      dice(string.format("  (...y %d mas)", #matches - 40))
    else
      for _, m in ipairs(matches) do dice(m) end
    end
  end

  -- el veredicto: el pool es donde las 16 casillas suman 16
  if sumA == 16 and sumB ~= 16 then
    base_detectada = 0xFF9400
    dice("")
    dice(">> VEREDICTO: el pool es $FF9400 (0xFF9400 + i*$80)")
  elseif sumB == 16 and sumA ~= 16 then
    base_detectada = 0x009400
    dice("")
    dice(">> VEREDICTO: el pool es $009400 (la aritmetica del allocator tenia razon)")
  else
    base_detectada = nil
    dice("")
    dice(">> Ningun candidato da 16 casillas: mirá los slots con firma de arriba")
    dice("   y deduce la base del stride (todos deberian caer en la misma base).")
  end
  escaneo_hecho = true
  dice("=====================================================================")
end

-- ---------------------------------------------------------------------
-- 2) el vivo: los spawns que pasan
-- ---------------------------------------------------------------------
local tick = 0
local ult_estado = {}
local ult_cursor = nil

local function slot_base(i, base)
  return base + i * 0x80
end

local function vivo(base)
  local c = rw(0xFFA036) or rw(0xA036)
  if c and c ~= ult_cursor then
    dice(string.format("[f %5d] cursor $A036 -> $%04X  (slot que toca: base + $%03X)",
      tick, c, c))
    ult_cursor = c
  end

  local quel = {}
  for i = 0, 15 do
    local a = slot_base(i, base)
    local sz = rw(a + 4) or 0
    local prev = ult_estado[i]
    if prev then
      if prev == 0 and sz == 0x0080 then
        local lw = rdw(a) or 0
        dice(string.format("[f %5d] SPAWN slot %d ($%06X): handler $%06X  ID=$%02X  pos=$%04X,%04X  tabla=$%06X",
          tick, i, a, lw, rb(a + 0x58) or 0, rw(a + 0x40) or 0, rw(a + 0x44) or 0, rdw(a + 0x1C) or 0))
      elseif prev == 0x0080 and sz == 0 then
        dice(string.format("[f %5d] muere slot %d ($%06X)", tick, i, a))
      end
    end
    ult_estado[i] = sz
  end
end

-- ---------------------------------------------------------------------
-- 3) el clon: un efecto con vida -> copiar su record a un slot libre
-- ---------------------------------------------------------------------
local cooldown = CLONAR_CADA

local function clona(base)
  if cooldown > 0 then cooldown = cooldown - 1 return end
  for i = 0, 15 do
    local a = slot_base(i, base)
    if (rw(a + 4) or 0) == 0x0080 then
      -- buscar un slot libre
      for j = 0, 15 do
        local b = slot_base(j, base)
        if j ~= i and (rw(b + 4) or 1) == 0 then
          -- copiar el record completo (word por word: las direcciones impares
          -- quedan cubiertas porque se escriben las mismas posiciones)
          for o = 0, 0x7E, 2 do
            local v = rw(a + o)
            if v then pcall(memory.writeword, b + o, v) end
          end
          -- posición corrida
          local x = rw(a + 0x40) or 0
          pcall(memory.writeword, b + 0x40, x + CLON_DX)
          local y = rw(a + 0x44) or 0
          pcall(memory.writeword, b + 0x44, y)
          dice(string.format("[f %5d] CLON: efecto del slot %d ($%06X, ID=$%02X) -> slot %d ($%06X) en +$%03X de X",
            tick, i, a, rb(a + 0x58) or 0, j, b, CLON_DX))
          cooldown = CLONAR_CADA
          return
        end
      end
      cooldown = CLONAR_CADA
      return
    end
  end
end

-- ---------------------------------------------------------------------
-- 4) el aura: inyectar el efecto AURA_ID sobre el jugador envenenado
-- ---------------------------------------------------------------------
-- La condicion "esta siendo envenenado" = esta PARADO en el plano de atras
-- (el suelo ($9C) en 304, y con vida). La inyeccion es la MISMA secuencia
-- que hace el allocator del juego: $0 = handler $149AC, $4 = $0080,
-- $6 = 0 (asi el handler entra en modo init y el branch de la tabla
-- $14A00 llena tiles/tabla/velocidad), $58 = ID, $40/$44 = posicion del pj
-- (+ AURA_DY).

local wk = function(adr, v) pcall(memory.writeword, adr, v) end
local wk8 = function(adr, v) pcall(memory.writebyte, adr, v) end

local slots_pj = { P1 = 0xFF8400, P2 = 0xFF8800 }

local function inyecta_aura(base_pool, px, py, quien)
  for j = 0, 15 do
    local b = slot_base(j, base_pool)
    if (rw(b + 4) or 1) == 0 then
      -- limpiar el record y armarlo como el allocator + el llamador
      for o = 0, 0x7E, 2 do
        wk(b + o, 0)
      end
      wk(b + 0, 0x0149)          -- longword 0 = $00149AC (handler grande)
      wk(b + 2, 0x09AC)
      wk(b + 4, 0x0080)          -- ocupado
      wk(b + 6, 0)               -- $6 = 0: init en el proximo pase
      wk8(b + 0x58, AURA_ID)     -- el tipo de efecto
      wk(b + 0x40, px)           -- X del jugador
      wk(b + 0x44, py + AURA_DY) -- Y del jugador (+ offset opcional)
      dice(string.format("[f %5d] AURA (%s): ID=$%02X inyectado en slot %d ($%06X) pos=$%04X,%04X",
        tick, quien, AURA_ID, j, b, px, py))
      return true
    end
  end
  return false
end

local aura_conto = AURA_CADA

local function aura(base_pool)
  aura_conto = aura_conto - 1
  if aura_conto > 0 then return end
  aura_conto = AURA_CADA

  local destinos = {}
  if AURA_DESTINO == "P1" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P1", slots_pj.P1 } end
  if AURA_DESTINO == "P2" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P2", slots_pj.P2 } end

  for _, d in ipairs(destinos) do
    local a = d[2]
    local hp = rw(a + 0x78) or 0
    local suelo = rw(a + 0x9C) or 0
    -- siendo envenenado: parado en el plano de atras y con vida
    if suelo == 304 and hp >= 1 then
      local px = rw(a + 0x40) or 0
      local py = rw(a + 0x44) or 0
      inyecta_aura(base_pool, px, py, d[1])
    end
  end
end

-- ---------------------------------------------------------------------
-- el frame
-- ---------------------------------------------------------------------
local function cada_frame()
  tick = tick + 1
  if tick % 180 == 1 then
    -- re-escaneo suave cada ~3 s si no se detecto base todavia
    if not base_detectada then
      escanea()
    end
  end
  if base_detectada then
    vivo(base_detectada)
    if CLONAR then clona(base_detectada) end
    if MODO == "aura" then aura(base_detectada) end
  elseif escaneo_hecho then
    -- nada: el escaneo ya dijo lo suyo; el refresh lo hace el %180
  end
end

escanea()
emu.registerafter(cada_frame)
