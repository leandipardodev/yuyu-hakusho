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
local AURA_ID        = 0x20     -- el trazo del dash de Genkai (spawnea de a 4 en fila)
local AURA_CADA      = 8        -- cada cuantos frames del veneno intenta clonar;
                                -- 8 = la vida del clon con corte: el encadenado
                                -- queda casi continuo (a 16 se ve parpadear)
local AURA_DY        = 0x0000   -- offset de Y sobre la posicion del pj
local AURA_DESTINO   = "P1"     -- "P1" | "P2" | "AMBOS"
local AURA_MAXVIVOS  = 1        -- techo de clones de aura vivos a la vez (protege
                                -- el pool: 16 slots y el polvo del caminar
                                -- tambien come slots; sin techo llenaba el pool)
local AURA_LIBRE_MIN = 2        -- no clonar si quedan menos de N slots libres
                                -- (deja aire para los efectos del juego)
local AURA_VIDA_MAX  = 60      -- guarda: si un clon vive mas de X frames (el
                                -- corte deberia matarlo ~8), se mata forzado
local AURA_CICLAR    = false    -- cada clon sale con la paleta SIGUIENTE (0-3)
local AURA_PALETA    = 1        -- si AURA_CICLAR es false: paleta fija (0-3)
local AURA_PAREJA    = 1        -- cuadro de la animacion con que arranca el clon
                                -- nil = normal ($FF, secuencia completa); 0..N = arranca en ese par
local AURA_FIN       = 3        -- cortar el clon cuando $59 llegue a este par (mp3 del trail)
                                -- nil = vida natural completa. trail = pares 0-3: 1..2 = 25%/75%
local AURA_DUR       = nil      -- nil = duracion de cada par del juego; sino, ticks forzados
                                -- (ej 0x20 = un solo cuadro colgado ~32 frames)
local AURA_SILENCIO  = true     -- true = apagar el log por-frame (SPAWN/CAPTURA/SEGU/CORTE);
                                -- el stdout de la consola viene a desacelerar el emulador

-- plantilla FIJA del record $20 (capturada del CAPTURA real de un spawn).
-- si no es nil, el aura no necesita haber visto un dash en la sesion:
-- clona directo de esta tabla. Es la prueba de "efecto sin Genkai".
-- word-indexed; $40/$44 y $59/$5B/$5C/$3C los pisa el clon.
local AURA_PLANTILLA_FIJA = {
  [0x00] = 0x0001, [0x02] = 0x49AC,   -- handler $000149AC
  [0x04] = 0x0080,                    -- vivo
  [0x06] = 0x0002,                    -- tick de spawn
  [0x1C] = 0x0027, [0x1E] = 0xF618,   -- tabla maestra $27F618
  [0x24] = 0xC1A6,                    -- tile $01A6 + paleta 2 + prioridad
  [0x26] = 0x1001,                    -- plano del trail
  [0x3E] = 0x0100,                    -- escala
  [0x50] = 0x0001, [0x52] = 0x4EAC,   -- tabla de pares $14EAC
  [0x58] = 0x20FF,                    -- ID=$20, $59=$FF
  [0x5A] = 0x0001,                    -- $5B=$01 anim inicial
}

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
local plantilla_id = { ok = false }   -- ultimo record completo del AURA_ID capturado

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
        if not AURA_SILENCIO then
          dice(string.format("[f %5d] SPAWN slot %2d ($%06X): handler $%06X  ID=$%02X  pos=$%04X,%04X  tabla=$%06X",
            tick, i, a, rdw(a), did, rw(a + 0x40), rw(a + 0x44), rdw(a + 0x1C)))
        end
        -- CAPTURA: si es el ID que busca el aura, guardar copia del record
        -- (corre SIEMPRE: el print es lo silenciado, la captura no)
        if did == AURA_ID then
          if not AURA_SILENCIO then
            vuelca_record(a, "ID=" .. string.format("$%02X", did))
          end
          for o = 0, 0x7E, 2 do plantilla_id[o] = rw(a + o) end
          plantilla_id.ok = true
        end
      elseif prev == 0x0080 and sz == 0 then
        if not AURA_SILENCIO then
          dice(string.format("[f %5d] muere slot %2d ($%06X)", tick, i, a))
        end
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

-- seguimiento de clones: mirar si algo reescribe $24 despues del tiple
local seguimiento = {}
local lim_pool_dump = -999

local function sigue(base)
  for i = #seguimiento, 1, -1 do
    local s = seguimiento[i]
    s.edad = (s.edad or 0) + 1
    local sz = rw(s.slot + 4)
    if sz ~= 0x0080 then
      table.remove(seguimiento, i)
    elseif s.corte and rb(s.slot + 0x58) ~= s.id then
      -- el slot lo TOMO el juego para otro efecto (polvo, burst, ...):
      -- soltar el seguimiento SIN tocar el slot. El $59 de otro ID
      -- significa otra cosa: el corte a ciegas asesina efectos ajenos
      -- (recorre-prueba: pool LLENO + tildo caminando)
      table.remove(seguimiento, i)
    elseif s.corte and rb(s.slot + 0x59) >= s.corte then
      -- fin anticipado: NO escribir $4=0 a mano. Eso deja el record zombie
      -- (handler/tablas/$58 intactos) y las piezas del SAT colgadas:
      -- "pantalla en negro al terminar la animacion". Lo correcto es
      -- MANDARLO AL TERMINADOR de la tabla de pares ($59=$04 = la entrada
      -- [0,0]): el $149AC hace su kill COMPLETO en el proximo tick, exacto
      -- a como muere un trail real del juego.
      wb(s.slot + 0x59, 0x04)
      if not AURA_SILENCIO then
        dice(string.format("[f %5d] CORTE slot %d: $59=$%02X >= $%02X -> terminador (kill del juego)",
          tick, s.slot, rb(s.slot + 0x59), s.corte))
      end
      table.remove(seguimiento, i)
    elseif s.aura and s.edad >= AURA_VIDA_MAX then
      -- guarda: el corte debio matarlo hace rato ($59 atascado)
      wb(s.slot + 0x59, 0x04)
      if not AURA_SILENCIO then
        dice(string.format("[f %5d] GUARDIA slot %d: clon de aura vivo %d frames (max %d), mando al terminador",
          tick, s.slot, s.edad, AURA_VIDA_MAX))
      end
      table.remove(seguimiento, i)
    elseif not AURA_SILENCIO then
      dice(string.format("[f %5d] SEGU slot %d (PALETA=%d): $6=$%04X  $3C=$%04X  $59=$%02X  $5B=$%02X  $5C=$%02X",
        tick, s.slot, s.p, rw(s.slot + 6), rw(s.slot + 0x3C), rb(s.slot + 0x59), rb(s.slot + 0x5B), rb(s.slot + 0x5C)))
      s.frames = s.frames - 1
      if s.frames <= 0 then table.remove(seguimiento, i) end
    end
  end
end

local aura_conto = AURA_CADA
local aura_esperando_aviso = false
local aura_paleta_n = 0

local function aura(base)
  aura_conto = aura_conto - 1
  if aura_conto > 0 then return end
  aura_conto = AURA_CADA

  -- el jugador puede recibir el aura? (siempre y cuando este vivo;
  -- el aura lo sigue a CUALQUIER lado, no solo en el plano del fondo)
  local destinos = {}
  if AURA_DESTINO == "P1" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P1", slots_pj.P1 } end
  if AURA_DESTINO == "P2" or AURA_DESTINO == "AMBOS" then destinos[#destinos + 1] = { "P2", slots_pj.P2 } end

  local pj_inyectado = nil
  for _, d in ipairs(destinos) do
    local a = d[2]
    local hp = rw(a + 0x78)
    if hp >= 1 then
      pj_inyectado = { quien = d[1], x = rw(a + 0x40), y = rw(a + 0x44) }
      break
    end
  end
  if not pj_inyectado then
    aura_esperando_aviso = false
    return
  end

  -- guardas de recursos: techo de clones vivos + aire libre en el pool
  -- (el polvo del caminar tambien come slots: sin techo llenaba el pool
  -- y el juego tildaba; deja minimo AURA_LIBRE_MIN slots para el juego)
  local vivos = 0
  for _, s in ipairs(seguimiento) do
    if s.aura and rw(s.slot + 4) == 0x0080 then vivos = vivos + 1 end
  end
  if vivos >= AURA_MAXVIVOS then
    if not AURA_SILENCIO or tick % 60 == 0 then
      dice(string.format("[f %5d] AURA en espera: vivos=%d (max %d), listo para el proximo", tick, vivos, AURA_MAXVIVOS))
    end
    return
  end

  local libres, ocupados = 0, {}
  for i = 0, 15 do
    local b = slot_base(i, base)
    if rw(b + 4) == 0 then
      libres = libres + 1
    else
      ocupados[#ocupados + 1] = string.format("  slot %2d: ID=$%02X  $59=$%02X  $6=$%04X  handler $%06X",
        i, rb(b + 0x58), rb(b + 0x59), rw(b + 6), rdw(b))
    end
  end
  if libres < AURA_LIBRE_MIN then
    -- diagnostico: a lo sumo cada 120 frames, SIEMPRE (incluso en silencio)
    if tick - lim_pool_dump >= 120 then
      lim_pool_dump = tick
      dice(string.format("[f %5d] AURA en pausa: solo %d slot(s) libre(s) (minimo %d). Ocupacion:",
        tick, libres, AURA_LIBRE_MIN))
      for _, d in ipairs(ocupados) do dice(d) end
    end
    return
  end

  -- buscar una fuente viva del ID pedido; si no la hay, usar la plantilla
  -- capturada (asi el aura no depende de que un dash este vivo AHORA)
  local fuente = nil
  local des_plantilla = false
  for i = 0, 15 do
    local a = slot_base(i, base)
    if rw(a + 4) == 0x0080 and rb(a + 0x58) == AURA_ID then fuente = a break end
  end
  local p_plantilla = nil
  if not fuente then
    p_plantilla = AURA_PLANTILLA_FIJA or (plantilla_id.ok and plantilla_id or nil)
    if p_plantilla then
      des_plantilla = true
    end
  end
  if not fuente and not des_plantilla then
    if not aura_esperando_aviso then
      dice(string.format("[f %5d] AURA: sin ID=$%02X vivo y sin plantilla todavia (esperando que el juego spawnee uno)", tick, AURA_ID))
      aura_esperando_aviso = true
    end
    return
  end

  -- buscar slot libre para el clon
  for j = 0, 15 do
    local b = slot_base(j, base)
    if rw(b + 4) == 0 then
      for o = 0, 0x7E, 2 do
        wr(b + o, des_plantilla and (p_plantilla[o] or 0) or rw(fuente + o))
      end
      wr(b + 0x40, pj_inyectado.x)
      wr(b + 0x44, pj_inyectado.y + AURA_DY)
      -- animacion: el estado $59/$5B/$5C del source puede venir AVANZADO
      -- (clonamos recordes a mitad de la secuencia); si $59 sale alto el
      -- handler cae despues del final de la tabla y NO DIBUJA (visto en el
      -- log: los clones de plantilla con $59=$03 eran invisibles). El game
      -- al spawnar siempre setea $59=$FF/$5B=$01/$5C=$00: resetear SIEMPRE
      -- al estado recien-nacido para que la secuencia arranque completa.
      -- OJO: $59/$5B/$5C son campos de un BYTE: escribilos con wb, no wr
      -- (un writeword pisa el byte vecino: $59=0 y $5A=1 = el clon queda
      -- anclado en el par 0 y el corte nunca dispara)
      wb(b + 0x59, AURA_PAREJA or 0xFF)
      wb(b + 0x5B, AURA_DUR or 0x01)
      wb(b + 0x5C, 0x00)
      wr(b + 0x3C, 0x0000)
      -- cambio de color: bits 13-14 de $24 = numero de paleta VDP (aritmetica
      -- pura, sin lib bit), preservando el bit 15 (prioridad)
      local p = AURA_CICLAR and aura_paleta_n or AURA_PALETA
      local v24 = rw(b + 0x24)
      local prio = ((v24 or 0) >= 0x8000) and 0x8000 or 0
      local nuevo = ((v24 or 0) % 0x2000) + 0x2000 * p + prio
      wr(b + 0x24, nuevo)
      if AURA_CICLAR then aura_paleta_n = (aura_paleta_n + 1) % 4 end
      -- seguimiento: si hay corte $59-fin, vigilar hasta el corte (sin limite
      -- de 8 frames); si no, solo 8 frames de chequeo del $24
      seguimiento[#seguimiento + 1] = {
        slot = b, p = p, v24 = nuevo, id = AURA_ID, aura = true,
        corte = AURA_FIN,
        frames = AURA_FIN and 200 or 8,
      }
      dice(string.format("[f %5d] AURA (%s): clon del ID=$%02X (%s) sobre el pj pos=$%04X,%04X -> slot $%06X  PALETA=%d ($24->$%04X)",
        tick, pj_inyectado.quien, AURA_ID, des_plantilla and "de plantilla" or string.format("$%06X", fuente), pj_inyectado.x, pj_inyectado.y, b, p, nuevo))
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
    if MODO == "aura"   then aura(base_detectada); sigue(base_detectada) end
  elseif tick % 180 == 1 then
    escanea()
  end
end

local function esfn(v)
  local t = type(v)
  return t == "function" or t == "userdata" -- BizHawk: funciones nativas = userdata
end

escanea()

-- registro del callback compatible con BizHawk moderno (donde
-- emu.registerafter fue retirado: la API actual es event.onframeend /
-- event.onframestart), BizHawk viejo (emu.registerafter) y FBNeo
-- (gui.register), probando con pcall hasta que uno ande.
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
if not callback_usado then
  dice("SONDA EFECTOS: NINGUN hook ando (event/emu/gui sin callbacks) - avisa a Leonardo.")
end
dice(string.format("SONDA EFECTOS %s CARGADA (modo %s, callback=%s).", VERSION, MODO, tostring(callback_usado)))
-- inventario de la API del emulador (una vez): nombres de memory/emu
do
  local function lista(t)
    local nombres = {}
    local ok = pcall(function() for k, _ in pairs(t) do nombres[#nombres + 1] = tostring(k) end end)
    if not ok then return "???" end
    if #nombres == 0 then return "(vacia o no es tabla)" end
    table.sort(nombres)
    return table.concat(nombres, " ")
  end
  dice("  memory: " .. lista(memory))
  dice("  emu:    " .. lista(emu))
  dice("  _G:     " .. lista(_G))
end
