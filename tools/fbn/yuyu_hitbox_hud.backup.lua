--[[
  yuyu_hitbox_hud.lua — Hitbox display + HUD para
  Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994) en FBNeo / Fightcade.

  Uso:
    Game > Lua Scripting > New Lua Script Window > Browse > este fichero
    Cargar el ROM md_yuyumte y entrar a un combate.

  Muestra:
    - Las cinco listas de colisiones: hitbox, clash, hurtbox, pushbox y el
      descriptor de grab. Solo borde, sin relleno, para tapar lo menos posible.
    - Eje central del personaje y su caja de 48 px.
    - Input display de P1 abajo a la derecha (cruceta + A B C X Y Z + MODE/START).
    - Tira de los ultimos botones pulsados, con los frames entre pulsadas.
    - Numeros de vida y mana pegados a las barras originales del juego.
    - Barra de aturdimiento en escala global, con la marca del personaje actual.
    - Barra de hit-time y de congelacion global de especiales.
    - Titulo "N#ga hud" con arcoiris y relieve.

  Menu: se abre manteniendo MODE. A=ON/OFF, flechas mueven, B=reset.

  Es 100% pasivo: no escribe ni un byte en la memoria del juego.

  Documentacion de las direcciones: COLISIONES_Y_HITBOXES.md y AGENTS.md
--]]

--------------------------------------------------------------------------------
-- Configuracion
--------------------------------------------------------------------------------

local SHORTNAME = "md_yuyumte"
local TITLE   = "N#ga hud"
local TITLE_W = 62       -- #TITLE * 6 px de avance + aire
local CHAR_W  = 6

local SHOW_HITBOXES  = true
local SHOW_CLASH     = true
local SHOW_HURTBOXES = true
local SHOW_PUSHBOXES = true
local SHOW_GRAB      = true
local SHOW_AXIS      = true
local SHOW_GRID      = false
local SHOW_INPUT     = true
local SHOW_HUD       = true
local SHOW_STUN      = true
local SHOW_HITTIME   = true
local SHOW_HISTORY   = true
local SHOW_TIMELINE  = true
local SHOW_FACE      = true
local SHOW_COORD     = true

-- Dibuja tambien las cajas del P2. ENCENDIDO a proposito: los proyectiles
-- tienen owner del P2, asi que con el filtro activo no se veia NINGUNA de sus
-- hitboxes. Solo aparecian si el usuario prendia este flag a mano.
local SHOW_P2 = true

-- Calibracion de la conversion mundo -> pantalla, en pixeles.
--
-- $08/$0C NO son pixeles de pantalla: en $01575E se pasan como d2/d3 a $012C4,
-- que es el parser de la lista de sprites del VDP. Y $A014/$A016 son la CAMARA
-- (se actualizan cada frame en $0215D2 y $0215F4), no una base fija del stage.
--
-- Por eso el offset se calibra a mano en vez de copiar la formula de
-- loc_0156F0. La referencia es el CENTRO de la sombra redonda de los pies: la
-- linea horizontal de la cruz tiene que caer ahi.
local CAL_X, CAL_Y = -127, -127

--------------------------------------------------------------------------------
-- Direcciones (verificadas contra el desensamblado)
--------------------------------------------------------------------------------

local P1 = 0xFF8400                -- slot del jugador 1
local P2 = 0xFF8800                -- slot del jugador 2

local rb  = memory.readbyte
local rw  = memory.readword
local rws = memory.readwordsigned
local rd  = memory.readdword

local OFF_SCREEN_X, OFF_SCREEN_Y = 0x08, 0x0C
local OFF_WORLD_LO,  OFF_WORLDY_LO = 0x40, 0x44
local OFF_VX,       OFF_VY       = 0x28, 0x2A
local OFF_SCALE                   = 0x3E
local OFF_FRAME,    OFF_DUR      = 0x59, 0x5A
local OFF_TICK                    = 0x5B
local OFF_MOVE                    = 0x5F
local OFF_FACING                  = 0x61
local OFF_HITPAUSE                = 0x69
local OFF_HP                      = 0x78   -- HP real, word SIGNED, max 255
local OFF_STUN, OFF_STUN_MAX     = 0x7E, 0x80
local OFF_MP                      = 0xB8   -- energia/TA gastable, NO HP

local HP_MAX   = 0xFF              -- 255, move.w #$ff,$78(a5) en $012AE6
local HP_LOW   = 0x6F              -- 111, cmpi.w #$6f,$78(a5) en 14 sitios
local MP_MAX   = 0xDF              -- 223, move.l #$df0000,$b8(a5) en $01A2E2
local MP_LOW   = 0x20              -- 32, cmpi.w #$20,$b8(a5) en $01CD70

-- Congelacion global de pantalla: $F558 con el flag $F55A. La carga la
-- cinematica de los especiales con 160 ("move.w #$a0,$f558.w" en $01FA82).
local HT_GLOBAL_MAX = 160
local FREEZE_F     = 0xFFF558
local FREEZE_FLAG  = 0xFFF55A

-- Congelacion por ESPECIAL: $26 (byte del defensor).
-- La rutina comun a todo contacto, $1F7B2, la escribe:
--   01f7ba: move.b #$3c,$26(a3)   atacante = 60
--   01f7c0: move.b #$40,$26(a4)   defensor = 64
-- y si el atacante tiene $9C == $130 (movimiento especial de ese personaje):
--   01f7c8: move.b #$bc,$26(a3)   188
--   01f7ce: move.b #$c0,$26(a4)   192
-- El resolver de especiales $01EEE2 NO toca $69, por eso con un especial la
-- barra de hit-time se quedaba en cero.
local SPECIAL_FREEZE = 0x26

-- El stun max de los 10 personajes esta en las rutinas de init, una cada 74
-- bytes entre $0127CE y $012A74, con "move.w #$xx,$80(a5)":
--   40, 56, 48, 44, 54, 46, 40, 38, 48, 62
-- El maximo es 62 ($3E) en $012A68, y ese personaje arranca con el gauge lleno.
local STUN_GLOBAL_MAX = 62

-- Posiciones del HUD, en pixeles de pantalla de FBNeo.
local NUM_X  = 136    -- numeros a la derecha de la etiqueta H del juego
local HP_Y   = 8      -- centrado en la barra amarilla (y 15..23)
local MP_Y   = 16     -- centrado en la barra cyan (y 26..34)
local STUN_X = 4       -- aturdimiento: mismo X que la de hit-time
local STUN_Y = 189     -- justo por encima de la de hit-time
local STUN_W = 64
local HT_X   = 4
local HT_Y   = 200
local HT_W   = 64
local HT_MAX = 28      -- 16 al recibir golpe ($01F2E0), 28 en clash ($01F15E)
local ARROW_X = 166
local ARROW_Y = 20
local GRID_STEP = 16

--------------------------------------------------------------------------------
-- Colisiones
--------------------------------------------------------------------------------

-- Un color por caja, opaco. El alpha del relleno no sirve de nada: gui.box lo
-- ignora y pinta opaco, por eso las cajas se dibujan solo con el borde.
--
-- Cada tipo tiene un TRAZADO distinto, no solo un color distinto: con cinco
-- rectangulos superpuestos del mismo color el ruido era insufrible.
--
--   solid    rectangulo completo  -> hitbox, la que mas importa
--   dashed   rectangulo punteado  -> hurtbox
--   corners  solo las 4 esquinas   -> pushbox y clash, las mas grandes
--   double   doble rectangulo     -> grab, no es una caja normal
--
-- EL ORDEN DE ESTA TABLA ES EL ORDEN DE DIBUJO: primero lo que menos importa,
-- asi la hitbox queda arriba de todo y nunca tapada.
local LISTS = {
  { name = "push", base = 0xFFA500, cnt = 0xFFA00A, stride = 0x10,
    on = function() return SHOW_PUSHBOXES end,
    style = "corners", line = 0xFF60E060 },
  { name = "clsh", base = 0xFFA300, cnt = 0xFFA006, stride = 0x10,
    on = function() return SHOW_CLASH end,
    style = "corners", line = 0xFFC0C040 },
  { name = "hurt", base = 0xFFA400, cnt = 0xFFA008, stride = 0x10,
    on = function() return SHOW_HURTBOXES end,
    style = "dashed", line = 0xFF80A0FF },
  { name = "grab", base = 0xFFA600, cnt = 0xFFA00C, stride = 0x20,
    on = function() return SHOW_GRAB end,
    style = "double", line = 0xFFE040E0 },
  { name = "hit",  base = 0xFFA200, cnt = 0xFFA004, stride = 0x10,
    on = function() return SHOW_HITBOXES end,
    style = "solid", line = 0xFFFF6060 },
}

local HOOK_PC = 0x01EDAC

-- Contador de frame PROPIO. No se usa emu.framecount() porque no avanza de
-- forma confiable en este build, y cuando no avanzaba el snapshot se
-- reutilizaba para siempre: la caja del ultimo golpe quedaba congelada en el
-- aire. Este se incrementa una vez por registerafter, o sea una vez por frame.
local frame_id = 0

local hooked = false
local exec_stamp = -1
local counts = { 0, 0, 0, 0, 0 }

-- Fallback por escritura: si el exec hook no prende, los write hooks sobre los
-- cinco contadores capturan los valores. El dispatcher escribe el total al
-- final y despues pone 0, asi que se ignoran las escrituras en 0.
local wr_counts = { 0, 0, 0, 0, 0 }
local wr_seen = false
local wr_frame = -1

-- Memoria del rango de grab, indexada por la TABLA DE MOVIMIENTOS ($8C) del
-- personaje, no por el jugador: cada personaje usa siempre el mismo builder de
-- grab, asi que la tabla lo identifica de forma unica.
--
-- VACIA a proposito: hay tres builders con valores distintos y no se sabe cual
-- usa cada personaje hasta medirlo con un agarre real.
--   $161BE:  dxm=16  dy=-48  16x16
--   $175EA:  dxm=16  dy=-16  12x16
--   $18346:  dxm=24  dy=-48  24x8
local grab_mem = {}
local probe_n = 0

-- Corrige que la cruz no este exactamente centrada en el sprite. La vertical
-- se calibro contra el centro de la sombra; la horizontal quedo sin afinar.
local GRAB_X_FIX = 0

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------

local function own_lo(v)
  return bit.band(v, 0xFFFF)
end

-- El owner NO se guarda completo. El builder hace "move.w a5" (0x01EC40,
-- 0x01EC9E, 0x01ECFC, 0x01ED5A, 0x0161BE), asi que el campo +$C solo tiene
-- el WORD BAJO: $8400 para P1 y $8800 para P2.
local function owner_base(v)
  local lo = own_lo(v)
  if lo == own_lo(P1) then return P1 end
  if lo == own_lo(P2) then return P2 end
  return nil
end

local function list_by(name)
  for i = 1, #LISTS do
    if LISTS[i].name == name then return LISTS[i] end
  end
  return nil
end

local function moves_key(base)
  return rw(base + 0x8C)
end

-- Los contadores son offsets EN BYTES, no cantidades.
local function box_count(counter, stride)
  if counter <= 0 then return 0 end
  return math.min(math.floor(counter / stride), 0xF0 / stride)
end

-- nil = dibujar todas las cajas; un numero = solo las de ese jugador.
-- Ojo: no escribir como "SHOW_P2 and nil or P1", porque el and/or de Lua
-- devuelve P1 en los dos casos.
local function owner_filter()
  if SHOW_P2 then return nil end
  return own_lo(P1)
end

--------------------------------------------------------------------------------
-- Conversion mundo -> pantalla
--
-- $08/$0C son la posicion en pantalla PERO CLAMPADA: loc_0156F0 (0x15700 y
-- 0x15730) recorta X a [0x40..0x1FF] e Y a [0x40..0x1C0] y luego resta 8.
-- En cuanto el personaje se sale de esa caja el valor se satura y todo lo
-- anclado a el se queda corrido. Por eso se recalcula la MISMA formula SIN
-- clamp y SIN el offset de empuje ($54/$56), que es de un solo frame.
--------------------------------------------------------------------------------
local function player_screen(base)
  return rw(base + OFF_WORLD_LO) - rw(0xFFA014) + 0x80 + CAL_X,
         rw(base + OFF_WORLDY_LO) - rw(0xFFA016) + rws(0xFFF566) + 0x20 - 8 + CAL_Y
end

local function to_screen(owner, bx, by)
  local base = owner_base(owner) or P1
  local ax, ay = player_screen(base)
  return ax + (bx - rw(base + OFF_WORLD_LO)),
         ay + (by - rw(base + OFF_WORLDY_LO))
end

--------------------------------------------------------------------------------
-- Dibujo: triangulos y texto con relieve
--------------------------------------------------------------------------------

-- Triangulo relleno de 9 px, centrado en (cx,cy). La fuente de FBNeo no
-- garantiza glifos de flecha, asi que se dibuja a mano.
-- Mide 5 px en el eje hacia el que apunta y 9 en el otro, y siempre nace
-- pegado a un borde: se corrnen 2 px para que quede centrado en la caja.
local function tri(cx, cy, dir, col)
  if dir == "right" then
    cx = cx + 2
  elseif dir == "left" then
    cx = cx - 2
  elseif dir == "down" then
    cy = cy + 2
  else
    cy = cy - 2
  end
  for i = 0, 4 do
    local o = 4 - i
    if dir == "right" then
      gui.drawline(cx - 4 + i, cy - o, cx - 4 + i, cy + o, col)
    elseif dir == "left" then
      gui.drawline(cx + 4 - i, cy - o, cx + 4 - i, cy + o, col)
    elseif dir == "down" then
      gui.drawline(cx - o, cy - 4 + i, cx + o, cy - 4 + i, col)
    else
      gui.drawline(cx - o, cy + 4 - i, cx + o, cy + 4 - i, col)
    end
  end
end

-- El sombreado BLANCO en las 4 diagonales es lo que da el aspecto de 3D. Ese
-- halo solo se ve si el texto NO es blanco puro, asi que esta funcion decide
-- sola: texto de color -> halo blanco; texto blanco -> sombra oscura.
local function hud_text(x, y, s, col)
  local r = math.floor(col / 65536) % 256
  local g = math.floor(col / 256) % 256
  local b = col % 256
  if r > 200 and g > 200 and b > 200 then
    gui.text(x + 1, y + 1, s, 0xB0000000)
  else
    gui.text(x - 1, y - 1, s, 0xC0FFFFFF)
    gui.text(x + 1, y - 1, s, 0xC0FFFFFF)
    gui.text(x - 1, y + 1, s, 0xC0FFFFFF)
    gui.text(x + 1, y + 1, s, 0xC0FFFFFF)
  end
  gui.text(x, y, s, col)
end

--------------------------------------------------------------------------------
-- Cajas: SOLO el borde, sin relleno
--
-- Se dibuja con gui.drawline, que si renderiza (la cruz del personaje sale de
-- ahi). Antes se le ponia una pasada negra de 1 px debajo de cada linea para
-- "darle cuerpo" y eso fue un error: sobre fondo oscuro el negro se comia la
-- linea de color y las cajas NO se veian.
--------------------------------------------------------------------------------
local function draw_box(x1, y1, x2, y2, col, style, corner)
  if x2 - x1 < 0 then x1, x2 = x2, x1 end
  if y2 - y1 < 0 then y1, y2 = y2, y1 end

  if style == "corners" then
    corner = corner or 6
    if x2 - x1 < corner * 2 then corner = math.floor((x2 - x1) / 2) end
    if y2 - y1 < corner * 2 then corner = math.floor((y2 - y1) / 2) end
    gui.drawline(x1, y1, x1 + corner, y1, col)
    gui.drawline(x1, y1, x1, y1 + corner, col)
    gui.drawline(x2, y1, x2 - corner, y1, col)
    gui.drawline(x2, y1, x2, y1 + corner, col)
    gui.drawline(x1, y2, x1 + corner, y2, col)
    gui.drawline(x1, y2, x1, y2 - corner, col)
    gui.drawline(x2, y2, x2 - corner, y2, col)
    gui.drawline(x2, y2, x2, y2 - corner, col)
    return
  end

  if style == "dashed" then
    local step, on = 4, 2
    local x = x1
    while x <= x2 do
      gui.drawline(x, y1, math.min(x + on, x2), y1, col)
      gui.drawline(x, y2, math.min(x + on, x2), y2, col)
      x = x + step
    end
    local y = y1
    while y <= y2 do
      gui.drawline(x1, y, x1, math.min(y + on, y2), col)
      gui.drawline(x2, y, x2, math.min(y + on, y2), col)
      y = y + step
    end
    return
  end

  gui.drawline(x1, y1, x2, y1, col)
  gui.drawline(x1, y2, x2, y2, col)
  gui.drawline(x1, y1, x1, y2, col)
  gui.drawline(x2, y1, x2, y2, col)
  if style == "double" and x2 - x1 > 4 and y2 - y1 > 4 then
    gui.drawline(x1 + 2, y1 + 2, x2 - 2, y1 + 2, col)
    gui.drawline(x1 + 2, y2 - 2, x2 - 2, y2 - 2, col)
    gui.drawline(x1 + 2, y1 + 2, x1 + 2, y2 - 2, col)
    gui.drawline(x2 - 2, y1 + 2, x2 - 2, y2 - 2, col)
  end
end

--------------------------------------------------------------------------------
-- Dibujo de las cajas
--------------------------------------------------------------------------------
local function draw_boxes()
  local filter = owner_filter()

  -- Fuente de los contadores, en este orden:
  --   1) cache del exec hook (momento exacto de la colision)
  --   2) write hooks sobre los contadores
  --   3) lectura directa (solo sirve si no se limpiaron todavia)
  --
  -- Cada snapshot se sella con frame_id: solo vale en el frame exacto en que
  -- se capturo.
  local use, src = nil, ""
  if exec_stamp == frame_id then
    use, src = counts, "exec"
  elseif wr_seen and wr_frame == frame_id then
    use = {}
    for i = 1, #LISTS do
      use[i] = box_count(wr_counts[i], LISTS[i].stride)
    end
    src = "wr"
  end
  if not use then
    use = {}
    for i = 1, #LISTS do
      use[i] = box_count(rw(LISTS[i].cnt), LISTS[i].stride)
    end
    src = "raw"
  end

  local drawn = 0

  for i = 1, #LISTS do
    local L = LISTS[i]
    if L.on() then
      drawn = drawn + use[i]
      for k = 0, use[i] - 1 do
        local a = L.base + k * L.stride
        local owner = rw(a + 0x0C)
        local ob = owner_base(owner)
        if (not filter) or own_lo(owner) == filter then
          local bx = rws(a + 0x00)
          local by, rx, ry
          if L.stride == 0x20 then
            -- Descriptor de grab: NO es una caja de 16 bytes. El builder
            -- ($0161C2..$0161F0) escribe X en +0, Y en +2, rx en +4 y ry en
            -- +5. Y va en +2 y no en +4: leer +4 cogia los radios.
            by = rws(a + 0x02)
            rx = rb(a + 0x04)
            ry = rb(a + 0x05)
          else
            by = rws(a + 0x04)
            rx = bit.band(rb(a + 0x08), 0x7F)
            ry = rb(a + 0x09)
          end
          -- OJO: el filtro tiene que ser OR, no AND. Muchas hitboxes de
          -- proyectil tienen un radio en 0 (son finas, tipo linea o rayo), y con
          -- AND no se dibujaban nunca. Un radio en 0 se dibuja como 1 px.
          if rx > 0 or ry > 0 then
            local ex = rx > 0 and rx or 1
            local ey = ry > 0 and ry or 1
            -- La caja de grab se captura UNA SOLA VEZ por personaje. Antes se
            -- sobreescribia cada frame y cualquier lectura inconsistente
            -- cambiaba el offset: el marcador se movia a otra velocidad y se
            -- iba alejando de la caja real.
            if L.stride == 0x20 and ob then
              local key = moves_key(ob)
              if not grab_mem[key] then
                -- Offset con LECTURAS SIN SIGNO en los dos lados: con rws en
                -- uno y rw en el otro, si la palabra tiene el bit 15 activo la
                -- resta sale corrida en 65536.
                local dxm = math.abs(rw(a + 0x00) - rw(ob + OFF_WORLD_LO))
                local dy  = rw(a + 0x02) - rw(ob + OFF_WORLDY_LO)
                -- VALIDACION: si lo leido se sale del rango de los tres
                -- builders es que se agarro el descriptor a medio escribir. Como
                -- la captura es de una sola vez, guardar basura deja el
                -- marcador fuera de pantalla para siempre.
                if dxm <= 64 and dy >= -128 and dy <= 64
                   and ex <= 64 and ey <= 64 then
                  grab_mem[key] = { dxm = dxm, dy = dy, rx = ex, ry = ey }
                else
                  print(string.format(
                    "[yuyu] grab: captura descartada (dxm=%d dy=%d %dx%d)",
                    dxm, dy, ex, ey))
                end
              end
            end
            local sx, sy = to_screen(ob or owner, bx, by)
            draw_box(sx - ex, sy - ey, sx + ex, sy + ey, L.line, L.style)
          end
        end
      end
    end
  end

  -- Sonda: una linea cada 60 frames con cuantos se dibujaron y el origen.
  probe_n = probe_n + 1
  if probe_n % 60 == 0 then
    local ax, ay = player_screen(P1)
    print(string.format("[yuyu] dib=%d src=%s pj=%d,%d | %s %d %d %d %d %d",
      drawn, src, ax, ay,
      LISTS[1].name, use[1], use[2], use[3], use[4], use[5]))
  end
end

--------------------------------------------------------------------------------
-- Grab fijo: rango de agarre siempre visible, siguiendo al personaje
--
-- Se dibuja con los offsets memorizados de la ultima caja REAL. El signo del
-- offset en X se recalcula cada frame con el facing, igual que hace el builder
-- ("addi.w #$10" si facing == 0, "subi.w #$10" si no), asi que el marcador se
-- da vuelta cuando el personaje cambia de lado.
--
-- La BASE del recuadro va a la altura de la linea horizontal de la cruz, que
-- es donde estan los pies: se ancla por abajo, no por el centro.
--------------------------------------------------------------------------------
local function draw_grab_range()
  local L = list_by("grab")
  if not (L and L.on()) then return end

  local m = grab_mem[moves_key(P1)]
  if not m then return end

  local ax, ay = player_screen(P1)
  local dx = m.dxm + GRAB_X_FIX
  if rb(P1 + OFF_FACING) ~= 0 then dx = -dx end
  local sx = ax + dx
  local sy = ay
  local top = sy - m.ry * 2

  draw_box(sx - m.rx, top, sx + m.rx, sy, L.line, "dashed", 4)
  hud_text(sx + m.rx + 3, sy - 4,
           string.format("grab %d %dx%d", dx, m.rx * 2, m.ry * 2),
           0xFFFF00FF)
end

--------------------------------------------------------------------------------
-- Eje del personaje y cuadricula
--------------------------------------------------------------------------------
local function draw_axis()
  if not SHOW_AXIS then return end
  local px, py = player_screen(P1)
  gui.drawline(px - 10, py, px + 10, py, 0xFFFFFFFF)
  gui.drawline(px, py - 10, px, py + 10, 0xFFFFFFFF)
  gui.drawline(px - 24, py - 48, px + 24, py - 48, 0xFF60FF60)
  gui.drawline(px - 24, py, px + 24, py, 0xFF60FF60)
  gui.drawline(px - 24, py - 48, px - 24, py, 0xFF60FF60)
  gui.drawline(px + 24, py - 48, px + 24, py, 0xFF60FF60)
  if SHOW_COORD then
    gui.text(px + 26, py - 4, string.format("%d,%d", px, py), 0xFFFFFFFF)
  end
end

local function draw_grid()
  if not SHOW_GRID then return end
  local sw, sh = emu.screenwidth(), emu.screenheight()
  for x = 0, sw, GRID_STEP do
    local major = (x % 64) == 0
    gui.drawline(x, 0, x, sh, major and 0x80FF4040 or 0x30FFFFFF)
    if major then gui.text(x + 1, 1, tostring(x), 0xFF60FF60) end
  end
  for y = 0, sh, GRID_STEP do
    local major = (y % 64) == 0
    gui.drawline(0, y, sw, y, major and 0x80FF4040 or 0x30FFFFFF)
    if major then gui.text(1, y + 1, tostring(y), 0xFF60FF60) end
  end
end

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------
local function bar(x, y, w, h, ratio, fill, line)
  ratio = math.max(0, math.min(1, ratio or 0))
  gui.box(x, y, x + w, y + h, 0xB0000000, line)
  local fw = math.floor(w * ratio)
  if fw > 0 then
    gui.box(x, y, x + fw, y + h, fill, line)
    gui.drawline(x + 1, y + 1, x + fw - 1, y + 1, 0x60FFFFFF)
  end
  return fw
end

local function draw_hud()
  if not SHOW_HUD then return end
  local hp = rws(P1 + OFF_HP)
  local mp = rw(P1 + OFF_MP)
  hud_text(NUM_X, HP_Y, string.format("%d", hp),
           hp <= HP_LOW and 0xFFFF4040 or 0xFFFFFFFF)
  hud_text(NUM_X, MP_Y, string.format("%d", mp),
           mp <= MP_LOW and 0xFF60C0FF or 0xFFB0E0FF)
  if SHOW_FACE then
    if rb(P1 + OFF_FACING) == 0 then
      tri(ARROW_X + 4, ARROW_Y, "right", 0xFFFFFFFF)
    else
      tri(ARROW_X + 4, ARROW_Y, "left", 0xFFFFFFFF)
    end
  end
end

local function draw_stun()
  if not (SHOW_HUD and SHOW_STUN) then return end
  local stun = rw(P1 + OFF_STUN)
  local smax = rw(P1 + OFF_STUN_MAX)
  if smax <= 0 then return end
  bar(STUN_X, STUN_Y, STUN_W, 5, stun / smax, 0xC0FF9000, 0xFFC0A060)
  local mx = STUN_X + math.floor(STUN_W * smax / STUN_GLOBAL_MAX)
  if mx > STUN_X and mx < STUN_X + STUN_W then
    gui.drawline(mx, STUN_Y - 1, mx, STUN_Y + 6, 0xFFFFFFFF)
  end
  hud_text(STUN_X + STUN_W + 3, STUN_Y - 1,
           string.format("%d/%d", stun, smax), 0xFFFFD080)
end

-- Hit-time. OJO: hay DOS sistemas de congelacion y hay que mirar los dos.
--
-- 1) Hitpause del golpe, en $69 (byte del jugador). Lo pone el resolver de
--    hitbox contra hurtbox en $01F2E0 con 16, y el de clash en $01F15E con 28.
--    Baja de a uno por frame ("subi.b #$1,$69(a5)", unas 20 veces en el ROM).
--
-- 2) Congelacion GLOBAL de pantalla, en $F558 con el flag $F55A. La carga la
--    cinematica de los especiales con 160 ("move.w #$a0,$f558.w" en $01FA82).
--
-- En $012AF4 el juego chequea PRIMERO $F55A y solo si esta en cero mira $69:
--   012af4:  cmpi.b #$0,$f55a.w / bne.b $12b2e
--   012afc:  cmpi.b #$0,$69(a5)  / bhi.b $12b36
local function draw_hittime()
  if not SHOW_HITTIME then return end
  local ht = rb(P1 + OFF_HITPAUSE)
  local gf = rw(FREEZE_F)
  local on = rb(FREEZE_FLAG)
  local txt, ratio, mark, col

  if on ~= 0 and gf > 0 then
    txt   = string.format("freeze %d", gf)
    ratio = gf / HT_GLOBAL_MAX
    col   = 0xFFFF40FF
  else
    txt   = string.format("hit-time %d", ht)
    ratio = ht / HT_MAX
    col   = ht > 0 and 0xFFFF4040 or 0x60FFFFFF
    mark  = math.floor(HT_W * 16 / HT_MAX)
  end

  bar(HT_X, HT_Y, HT_W, 5, ratio,
      on ~= 0 and 0xC0FF40FF or 0xC0FF4040,
      on ~= 0 and 0xFFC0A0E0 or 0xFFC0A0A0)
  hud_text(HT_X + HT_W + 3, HT_Y - 1, txt, col)
  if mark then
    gui.drawline(HT_X + mark, HT_Y, HT_X + mark, HT_Y + 5, 0xFFFFE000)
  end
end

--------------------------------------------------------------------------------
-- Input display
--------------------------------------------------------------------------------
local BUTTONS = { "A", "B", "C", "X", "Y", "Z" }

local function draw_input()
  if not SHOW_INPUT then return end
  local pad = joypad.get()
  local sw = emu.screenwidth()
  -- Abajo a la derecha: arriba el juego ya pone los retratos y las barras de
  -- los dos jugadores, y el display se solapaba con las de P2.
  local bx, by = sw - 92, emu.screenheight() - 32
  local cx, cy = bx + 10, by + 14
  local c = 0x80808080
  local on = 0xFFFFFFFF
  local function arm(x, y, w, h, pressed)
    gui.box(x, y, x + w, y + h, pressed and on or 0x00000000, c)
  end
  arm(cx - 9, cy - 3, 6, 6, pad["P1 Left"])
  arm(cx + 3, cy - 3, 6, 6, pad["P1 Right"])
  arm(cx - 3, cy - 9, 6, 6, pad["P1 Up"])
  arm(cx - 3, cy + 3, 6, 6, pad["P1 Down"])
  arm(cx - 3, cy - 3, 6, 6, false)

  for i = 1, #BUTTONS do
    local col = (i - 1) % 3
    local row = (i - 1) < 3 and 0 or 1
    local x = bx + 26 + col * 11
    local y = by + 6 + row * 11
    local pressed = pad["P1 Button " .. BUTTONS[i]]
    gui.box(x, y, x + 9, y + 9, pressed and on or 0x00000000, c)
    gui.text(x + 3, y + 2, BUTTONS[i], 0xFFE0E0E0)
  end

  -- Mode arriba y Start abajo, apilados: en horizontal se salian de pantalla.
  local mx = bx + 58
  local mode, start = pad["P1 Mode"], pad["P1 Start"]
  gui.box(mx, by + 3, mx + 21, by + 12, mode and on or 0x00000000, c)
  gui.text(mx + 3, by + 5, "MODE", mode and on or 0xFFE0E0E0)
  gui.box(mx, by + 14, mx + 21, by + 23, start and on or 0x00000000, c)
  gui.text(mx + 3, by + 16, "START", start and on or 0xFFE0E0E0)
end

--------------------------------------------------------------------------------
-- Historial de botones
--
-- Los ultimos pulsados de P1 en orden, a la izquierda del titulo, hasta el
-- borde. El mas reciente queda pegado al titulo. Los botones NO desaparecen:
-- se acumulan y los viejos se corren a la izquierda. Al entrar pegan un
-- destello que se baja a HIST_DIM y ahi se quedan. Debajo va el numero de
-- frames desde la pulsada anterior, que es lo que sirve para leer frame data.
--------------------------------------------------------------------------------
local HIST_MAX  = 14
local HIST_GLOW = 14
local HIST_DIM  = 0.72

-- El tercer campo, si esta, es la direccion del triangulo a dibujar en vez de
-- la letra: las cuatro flechas de la cruceta se dibujan como triangulos.
local HIST_KEYS = {
  { "A", "P1 Button A" }, { "B", "P1 Button B" }, { "C", "P1 Button C" },
  { "X", "P1 Button X" }, { "Y", "P1 Button Y" }, { "Z", "P1 Button Z" },
  { "L", "P1 Left", "left" },   { "R", "P1 Right", "right" },
  { "U", "P1 Up", "up" },       { "D", "P1 Down", "down" },
  { "M", "P1 Mode" },           { "S", "P1 Start" },
}

local hist = {}
local hist_n = 0
local prev_pressed = {}
local own_frame = 0
local last_press_frame = 0

local function update_history()
  local pad = joypad.get()
  for i = 1, #HIST_KEYS do
    local name, key = HIST_KEYS[i][1], HIST_KEYS[i][2]
    -- joypad.get() solo trae las teclas pulsadas; el resto es nil, no false.
    local down = pad[key] and true or false
    if down and not prev_pressed[name] then
      hist_n = hist_n + 1
      if hist_n > HIST_MAX then
        for j = 1, hist_n - 1 do hist[j] = hist[j + 1] end
        hist_n = HIST_MAX
      end
      hist[hist_n] = { name = name, dir = HIST_KEYS[i][3], age = 0,
                       gap = own_frame - last_press_frame }
      last_press_frame = own_frame
    end
    prev_pressed[name] = down
  end
  own_frame = own_frame + 1
  for j = 1, hist_n do
    hist[j].age = hist[j].age + 1
  end
end

local function draw_history()
  if not SHOW_HISTORY then return end
  local sw = emu.screenwidth()
  local right = sw - TITLE_W - 6
  for j = hist_n, 1, -1 do
    local slot = hist_n - j           -- 0 = el mas reciente
    local x = right - (slot + 1) * 14
    if x < -14 then break end
    local h = hist[j]
    local glow = 1.0
    if h.age > 1 then
      local t = (h.age - 1) / HIST_GLOW
      if t > 1 then t = 1 end
      glow = 1.0 - (1.0 - HIST_DIM) * t
    end
    local col = 0xFF000000 + math.floor(0xFF * glow)
    gui.box(x, 3, x + 10, 13, 0x60000000, col)
    if h.dir then
      tri(x + 5, 8, h.dir, col)
    else
      gui.text(x + 3, 5, h.name, col)
    end
    if SHOW_TIMELINE and slot > 0 and h.gap < 100 then
      gui.text(x + 2, 14, string.format("%d", h.gap),
               0xFF00FF00 + math.floor(0x7F * glow))
    end
  end
end

--------------------------------------------------------------------------------
-- Titulo animado
--
-- Letras NEGRAS con outline BLANCO: se dibuja la letra blanca desplazada 1 px
-- en las 4 diagonales y despues la negra encima, dejando un borde blanco
-- alrededor del glifo. Cuando pasa el destello se apaga el outline y queda
-- solo la letra blanca, que si se distingue.
--------------------------------------------------------------------------------

local TITLE_PERIOD = 48

-- HSV a 0xAARRGGBB, el formato que usa gui.text en FBNeo.
local function hsv(h, s, v)
  h = h % 1
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local r, g, b
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return 0xFF000000
       + math.floor(r * 255) * 65536
       + math.floor(g * 255) * 256
       + math.floor(b * 255)
end

local function draw_title()
  local sw = emu.screenwidth()
  local x0 = sw - TITLE_W + 6
  local n = #TITLE
  local pos = (own_frame % TITLE_PERIOD) / TITLE_PERIOD * (n + 4)
  local y = 4

  for i = 1, n do
    local ch = string.sub(TITLE, i, i)
    local x = x0 + (i - 1) * CHAR_W
    gui.text(x - 1, y - 1, ch, 0xFFFFFFFF)
    gui.text(x + 1, y - 1, ch, 0xFFFFFFFF)
    gui.text(x - 1, y + 1, ch, 0xFFFFFFFF)
    gui.text(x + 1, y + 1, ch, 0xFFFFFFFF)
    local on = (pos - i >= 0 and pos - i < 3)
    if not on then
      gui.text(x, y, ch, 0xFF101010)
    else
      gui.text(x - 1, y - 1, ch, 0xFF101010)
      gui.text(x + 1, y - 1, ch, 0xFF101010)
      gui.text(x - 1, y + 1, ch, 0xFF101010)
      gui.text(x + 1, y + 1, ch, 0xFF101010)
      gui.text(x, y, ch, 0xFFFFFFFF)
    end
  end

  -- Subrayado que respira, con el ancho latiendo.
  local w = n * CHAR_W
  local breathe = 0.5 + 0.5 * math.sin(own_frame * 0.07)
  local uw = math.floor(w * (0.55 + 0.45 * breathe))
  for k = 0, uw - 1 do
    local x = x0 + k
    local f = k / math.max(1, uw - 1)
    gui.drawline(x, y + 10, x, y + 10,
                 hsv(own_frame * 0.010 + f * 0.5, 0.7, 0.55 + 0.45 * breathe))
  end
end

local function draw_status()
  draw_title()
  draw_history()
end

--------------------------------------------------------------------------------
-- Menu
--
-- Se abre manteniendo MODE un instante, para que no se abra por accident al
-- tocarlo. Es la unica tecla que no se usa para golpear, asi que el menu no
-- pisa nada de la partida.
--
--   mantener MODE   abrir / cerrar
--   arriba / abajo  mover el cursor
--   A               activar o desactivar la opcion
--   B               volver todo a los valores de fabrica
--
-- Va en DOS COLUMNAS: con 20 opciones en una sola hacia 226 px de alto en una
-- pantalla de 224 y se cortaba abajo.
--------------------------------------------------------------------------------
local MENU_HOLD = 30
local MENU_COLS = 2
local COLW  = 100
local GUTTER = 26      -- margen izquierdo para las miniaturas
local PRE_W  = 18
local VAL_X, LAB_X = 1, 24

local menu_open = false
local menu_row  = 0
local mode_hold = 0
local menu_prev = {}

-- El cuarto campo, si esta, es la lista de colisiones de la que habla el
-- item: el menu dibuja una mini muestra de SU trazo real en el margen.
local function bool_item(label, get, set, prev)
  return { label = label, kind = "bool", get = get, set = set, prev = prev,
           value = function() return get() and 1 or 0 end,
           act = function() set(not get()) end }
end

local DEFAULTS = {
  SHOW_HITBOXES, SHOW_CLASH, SHOW_HURTBOXES, SHOW_PUSHBOXES, SHOW_GRAB,
  SHOW_AXIS, SHOW_GRID, SHOW_INPUT, SHOW_HUD, SHOW_STUN, SHOW_HITTIME,
  SHOW_HISTORY, SHOW_TIMELINE, SHOW_FACE, SHOW_COORD, SHOW_P2,
}

local MENU = {
  bool_item("hitbox", function() return SHOW_HITBOXES end,
            function(v) SHOW_HITBOXES = v end, list_by("hit")),
  bool_item("clash", function() return SHOW_CLASH end,
            function(v) SHOW_CLASH = v end, list_by("clsh")),
  bool_item("hurtbox", function() return SHOW_HURTBOXES end,
            function(v) SHOW_HURTBOXES = v end, list_by("hurt")),
  bool_item("pushbox", function() return SHOW_PUSHBOXES end,
            function(v) SHOW_PUSHBOXES = v end, list_by("push")),
  bool_item("grab", function() return SHOW_GRAB end,
            function(v) SHOW_GRAB = v end, list_by("grab")),
  bool_item("cruz", function() return SHOW_AXIS end,
            function(v) SHOW_AXIS = v end),
  bool_item("cajas P2", function() return SHOW_P2 end,
            function(v) SHOW_P2 = v end),
  bool_item("cuadrica", function() return SHOW_GRID end,
            function(v) SHOW_GRID = v end),
  bool_item("mandos", function() return SHOW_INPUT end,
            function(v) SHOW_INPUT = v end),
  bool_item("historial", function() return SHOW_HISTORY end,
            function(v) SHOW_HISTORY = v end),
  bool_item("timeline", function() return SHOW_TIMELINE end,
            function(v) SHOW_TIMELINE = v end),
  bool_item("hp/mana", function() return SHOW_HUD end,
            function(v) SHOW_HUD = v end),
  bool_item("stun", function() return SHOW_STUN end,
            function(v) SHOW_STUN = v end),
  bool_item("hit-time", function() return SHOW_HITTIME end,
            function(v) SHOW_HITTIME = v end),
  bool_item("facing", function() return SHOW_FACE end,
            function(v) SHOW_FACE = v end),
  bool_item("coord", function() return SHOW_COORD end,
            function(v) SHOW_COORD = v end),
}

local function menu_slot(i)
  local rows = math.ceil(#MENU / MENU_COLS)
  local col = math.floor((i - 1) / rows)
  local row = (i - 1) % rows
  return col, row, rows
end

local function update_menu()
  local pad = joypad.get()
  local mode = pad["P1 Mode"] and true or false

  if mode then
    mode_hold = mode_hold + 1
    if mode_hold == MENU_HOLD then
      menu_open = not menu_open
      menu_row = 0
    end
  else
    mode_hold = 0
  end

  if not menu_open then return end

  -- Navegacion con flanco, para no repetir por mantener.
  local function edge(key)
    local d = pad[key] and true or false
    local p = menu_prev[key]
    menu_prev[key] = d
    return d and not p
  end

  if edge("P1 Up")   then menu_row = menu_row - 1 end
  if edge("P1 Down") then menu_row = menu_row + 1 end
  if menu_row < 0 then menu_row = #MENU end
  if menu_row > #MENU then menu_row = 0 end

  local it = MENU[menu_row + 1]
  if it then
    if edge("P1 Button A") then it.act() end
    if edge("P1 Button B") then
      SHOW_HITBOXES, SHOW_CLASH, SHOW_HURTBOXES = DEFAULTS[1], DEFAULTS[2], DEFAULTS[3]
      SHOW_PUSHBOXES, SHOW_GRAB, SHOW_AXIS = DEFAULTS[4], DEFAULTS[5], DEFAULTS[6]
      SHOW_GRID, SHOW_INPUT, SHOW_HUD = DEFAULTS[7], DEFAULTS[8], DEFAULTS[9]
      SHOW_STUN, SHOW_HITTIME, SHOW_HISTORY = DEFAULTS[10], DEFAULTS[11], DEFAULTS[12]
      SHOW_TIMELINE, SHOW_FACE = DEFAULTS[13], DEFAULTS[14]
      SHOW_COORD, SHOW_P2 = DEFAULTS[15], DEFAULTS[16]
    end
  end
end

local function draw_menu_row(cx, ly, it, sel)
  local col = sel and 0xFF60FF60 or 0xFFC0C0C0
  local val = string.format("%-3s", it.value() ~= 0 and "ON" or "off")
  hud_text(cx + VAL_X, ly, val, col)
  hud_text(cx + LAB_X, ly, it.label, col)
  if sel then
    tri(cx + COLW - 12, ly + 4, "right", 0xFF60FF60)
  end
end

local function draw_menu()
  if not menu_open then return end
  local sw, sh = emu.screenwidth(), emu.screenheight()
  local colw, rowh = COLW, 10
  local _, _, rows = menu_slot(1)
  local w = colw * MENU_COLS + 6
  local h = rows * rowh + 24
  local x = (sw - w) / 2 + GUTTER
  local y = (sh - h) / 2

  gui.box(x, y, x + w, y + h, 0xF01A1A2A, 0xFF60FF60)
  gui.text(x + 5, y + 3, "A ON/OFF   B reset   MODE salir", 0xFFFFFFFF)
  gui.drawline(x + 3, y + 13, x + w - 3, y + 13, 0xFF60FF60)

  for i = 1, #MENU do
    local it = MENU[i]
    local col, row = menu_slot(i)
    local cx = x + 3 + col * colw
    local ly = y + 17 + row * rowh
    local sel = (i - 1) == menu_row
    if sel then
      gui.box(cx - 1, ly - 1, cx + colw - 4, ly + 8, 0x60FFFFFF, 0x00000000)
    end
    if it.prev then
      local px = x - GUTTER + 4
      draw_box(px, ly - 1, px + PRE_W, ly + 7, it.prev.line, it.prev.style, 3)
      gui.drawline(px + PRE_W + 2, ly + 3, x - 2, ly + 3, 0x60FFFFFF)
    end
    draw_menu_row(cx, ly, it, sel)
  end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------
local function on_dispatch()
  for i = 1, #LISTS do
    counts[i] = box_count(rw(LISTS[i].cnt), LISTS[i].stride)
  end
  hooked = true
  exec_stamp = frame_id
  wr_seen = false
end

-- El callback de registerwrite no recibe argumentos: hay que leer la memoria
-- en la direccion que se registro, que se pasa por closure.
local function mk_count_hook(i, addr)
  return function()
    local v = rw(addr)
    if v > 0 then
      wr_counts[i] = v
      wr_seen = true
      wr_frame = frame_id
    end
  end
end

--------------------------------------------------------------------------------
-- Arranque
--------------------------------------------------------------------------------
local ROM = tostring(emu.romname())

-- FBNeo BORRA los hooks exec en cada reset del juego. Si el script se cargo
-- antes de que arrancara la partida, el hook se perdia. Por eso se re-arma
-- cada frame: registrar el mismo PC otra vez es idempotente y barato.
local function arm_hook()
  if memory.registerexec then
    memory.registerexec(HOOK_PC, on_dispatch)
  end
  if memory.registerwrite then
    for i = 1, #LISTS do
      local c = LISTS[i].cnt
      -- Registrar en las DOS direcciones: la que escribe el 68000 ($00A0xx)
      -- y el espejo de FBNeo ($FFA0xx). Con solo el espejo no llegaba nada.
      memory.registerwrite(c, 2, mk_count_hook(i, c))
      memory.registerwrite(c - 0xFF0000, 2, mk_count_hook(i, c - 0xFF0000))
    end
  end
end

arm_hook()
if emu.registerstart then emu.registerstart(arm_hook) end

-- NO se usa emu.registerbefore para invalidar el snapshot: en este build de
-- Fightcade no existe, y como la invalidacion era condicional el snapshot
-- NUNCA se limpiaba. Por eso la caja del ultimo golpe se quedaba congelada.
-- El snapshot se sella con frame_id (arriba) y frame_id avanza aqui, una vez
-- por frame.
emu.registerafter(function()
  arm_hook()
  update_menu()
  update_history()
  draw_grid()
  draw_boxes()
  draw_grab_range()
  draw_axis()
  draw_hud()
  draw_hittime()
  draw_stun()
  draw_input()
  draw_status()
  draw_menu()
  frame_id = frame_id + 1
end)

print(string.format("[yuyu] HUD listo. rom=%s hook en $%06X", ROM, HOOK_PC))