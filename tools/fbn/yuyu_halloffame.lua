--[[
  yuyu_halloffame.lua — Ventana HALL OF FAME para
  Yu Yu Hakusho: Makyou Toitsusen (Mega Drive, 1994) en FBNeo / Fightcade.

  Uso:
    Game > Lua Scripting > New Lua Script Window > Browse > este fichero
    Cargar el ROM md_yuyumte.

  CONTROLES
    mantener START 2 s   abrir el menu
    pulsar START 1 vez   cerrar el menu (si esta abierto)
    mantener START 3 s   activar o desactivar el confeti

  El confeti es independiente del menu: sigue cayendo con el menu cerrado,
  que es lo que se pidio.

  100% pasivo, igual que LLUVIA RECTA.LUA: dibuja con gui.box /
  gui.text / gui.drawline, que van a una capa de overlay y NO tocan la
  memoria emulada ni la VRAM. No hay ni una sola escritura al juego.

  START no lo usa nada mas del HUD (el menu de opciones es con MODE), asi
  que no pisa nada de la partida.
--]]

--------------------------------------------------------------------------------
-- Datos del ranking
--
-- El tercer campo es el numero de estrellas. El color NO va aqui a proposito:
-- las pinta la funcion de dibujo con la misma paleta para las seis, para que
-- no puedan quedar doradas unas y otras no.
--------------------------------------------------------------------------------

local RANKING = {
  { 1, "Adolin",    2 },
  { 2, "Kuusa",     1 },
  { 3, "Nomercy22", 1 },
  { 4, "N#ga",      1 },
  { 5, "Akara1996", 1 },
}

local PIE = "HieiFM y Cacenariel sigan intentando"

--------------------------------------------------------------------------------
-- Estrellas: DORADAS y SOLIDAS
--
-- El problema de la version anterior: se dibujaba con lineas desde el centro a
-- cada vertice, y eso deja huecos entre punta y punta. A 6 px de radio se veia
-- translucida, que es justo lo que molesta.
--
-- Ahora se RELLENA el poligono entero, fila a fila, con la regla par-impar:
-- para cada fila se buscan las intersecciones con las aristas, se ordenan y
-- se pintan los tramos de dos en dos. Sale una estrella maciza, no un
-- fotograma de lineas.
--
-- El relleno va en degradado vertical de dorado claro a dorado profundo, y
-- encima el contorno en tono oscuro: asi se separa del fondo y se lee de una
-- pasada, como el U+2B50 de las fuentes de verdad.
--------------------------------------------------------------------------------

-- COLOR: FBNeo lee 0xRRGGBBAA, NO 0xAARRGGBB. El byte alto es ROJO y el byte
-- bajo es ALFA. Verificado con tools/fightcade/yuyu_colores.lua (20 muestras) y
-- anotado en AGENTS.md. Escribir un 0xAARRGGBB a mano no da error: da otro
-- color, en silencio. Por eso todos los colores pasan por color().
local function color(r, g, b, a)
  return r * 16777216 + g * 65536 + b * 256 + a
end

local ESTRELLA_TOP    = color(0xFF, 0xE9, 0x6B, 0xFF)   -- punta, dorado claro
local ESTRELLA_MID    = color(0xFF, 0xC4, 0x00, 0xFF)   -- cuerpo, dorado
local ESTRELLA_BOT    = color(0xE0, 0x8A, 0x00, 0xFF)   -- base, dorado profundo
local ESTRELLA_BORDE  = color(0x8A, 0x52, 0x00, 0xFF)   -- contorno
local ESTRELLA_BRILLO = color(0xFF, 0xFB, 0xD0, 0xFF)   -- chispazo en el centro

-- Radio grande: antes 6, que se perdia. 9 se lee bien a 320x224.
local ESTRELLA_R = 9

-- Mezcla dos colores de FBNeo (0xAARRGGBB). Misma idea que lerp_col del HUD.
local function lerp_col(c1, c2, t)
  local function ch(c, sh) return math.floor(bit.band(bit.rshift(c, sh), 0xFF)) end
  local function mix(a, b) return math.floor(a + (b - a) * t + 0.5) end
  return bit.bor(bit.lshift(mix(ch(c1, 24), ch(c2, 24)), 24),
                 bit.lshift(mix(ch(c1, 16), ch(c2, 16)), 16),
                 bit.lshift(mix(ch(c1, 8),  ch(c2, 8)),  8),
                 mix(ch(c1, 0), ch(c2, 0)))
end

-- Insertion sort. La lista tiene 4..6 elementos como mucho, asi que da igual
-- que no sea el algoritmo mas rapido del mundo.
local function ordenar(t)
  for i = 2, #t do
    local x = t[i]
    local j = i - 1
    while j >= 1 and t[j] > x do
      t[j + 1] = t[j]
      j = j - 1
    end
    t[j + 1] = x
  end
end

local function estrella(cx, cy, r)
  -- 10 vertices alternando radio exterior e interior, desde -90 grados para
  -- que la primera punta apunte hacia arriba.
  local v = {}
  for i = 0, 9 do
    local ang = -math.pi * 0.5 + i * math.pi / 5
    local rr = r
    if i % 2 == 1 then rr = r * 0.45 end
    v[i + 1] = { cx + math.cos(ang) * rr, cy + math.sin(ang) * rr }
  end

  -- Relleno solido, fila a fila.
  local top = math.floor(cy - r)
  local bot = math.ceil(cy + r)
  local span = r * 2
  for y = top, bot do
    local xs = {}
    for i = 1, 10 do
      local a = v[i]
      local b = v[(i % 10) + 1]
      -- arista que cruza esta fila (semiextremos, regla par-impar)
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        local t = (y - a[2]) / (b[2] - a[2])
        xs[#xs + 1] = a[1] + (b[1] - a[1]) * t
      end
    end
    if #xs >= 2 then
      ordenar(xs)
      local t = (y - top) / span
      local col
      if t < 0.5 then
        col = lerp_col(ESTRELLA_TOP, ESTRELLA_MID, t * 2)
      else
        col = lerp_col(ESTRELLA_MID, ESTRELLA_BOT, (t - 0.5) * 2)
      end
      for k = 1, #xs - 1, 2 do
        gui.drawline(xs[k], y, xs[k + 1], y, col)
      end
    end
  end

  -- Contorno: el poligono cerrado, en dorado oscuro. Es lo que la separa del
  -- panel y hace que se lea de un vistazo.
  for i = 1, 10 do
    local a = v[i]
    local b = v[(i % 10) + 1]
    gui.drawline(a[1], a[2], b[1], b[2], ESTRELLA_BORDE)
  end

  -- Chispazo: un punto claro arriba a la izquierda, el reflejo del dorado.
  gui.drawline(cx - 2, cy - 3, cx - 1, cy - 3, ESTRELLA_BRILLO)
end

--------------------------------------------------------------------------------
-- Colores del panel y del texto
--------------------------------------------------------------------------------

local TITULO_COLOR   = color(0xFF, 0xE8, 0x5C, 0xFF)
local NOMBRE_COLOR   = color(0xFF, 0xFF, 0xFF, 0xFF)
local PUESTO_COLOR   = color(0xD8, 0xCC, 0x96, 0xFF)
local PIE_COLOR      = color(0xE6, 0xD8, 0xB0, 0xFF)
local PANEL_FILL     = color(0x0F, 0x0D, 0x1F, 0xF0)
local PANEL_LINE     = color(0xCC, 0x99, 0x19, 0xFF)

--------------------------------------------------------------------------------
-- Confeti
--
-- Mismo criterio que el resto del HUD: Lua 5.1, sin operadores bitwise nativos
-- y sin //, y joypad.get() solo trae las teclas pulsadas (el resto es nil).
--
-- Los papelitos se RECICLAN al llegar abajo, con una x nueva: por eso nunca se
-- agotan. Tambien se devuelven por los laterales, porque con la deriva se
-- salian de pantalla y se perdian.
--------------------------------------------------------------------------------

local CANTIDAD = 70

local COLORES = {
  0xFFFFD91A,   -- amarillo
  0xFFFFF2B0,   -- crema
  0xFFFF8C26,   -- naranja
  0xFFF2D140,   -- oro
  color(0xFF, 0xFF, 0xFF, 0xFF),   -- blanco
  0xFFD9B85C,   -- arena
}

local confeti = {}
local own_frame = 0

-- El estado va ANTES de las funciones de dibujo, y no por orden estetico: en
-- Lua un "local" solo es visible desde el punto donde se declara hacia abajo.
-- Si dibujar() se declara antes que estos locals, captura una GLOBAL (nil) y
-- el menu no aparece nunca, mientras update() escribe un local que nadie lee.
local SEG_MENU    = 120   -- 2 s
local SEG_CONFETI = 180   -- 3 s

local menu_open = false
local confetti_on = false
local hold = 0

local function rnd(a, b)
  return a + math.random() * (b - a)
end

local function llenar()
  local sw, sh = emu.screenwidth(), emu.screenheight()
  confeti = {}
  for i = 1, CANTIDAD do
    confeti[i] = {
      x = rnd(0, sw),
      y = rnd(0, sh),
      v = rnd(0.30, 0.85),          -- pixeles por frame
      dx = rnd(-0.28, 0.28),        -- deriva con el "viento"
      w = math.floor(rnd(2, 5)),
      h = math.floor(rnd(3, 6)),
      c = COLORES[math.floor(rnd(1, #COLORES + 0.999))],
    }
  end
end

local function mover()
  local sw, sh = emu.screenwidth(), emu.screenheight()
  for i = 1, #confeti do
    local p = confeti[i]
    p.y = p.y + p.v
    p.x = p.x + p.dx
    -- reciclado vertical: al salir por abajo vuelve arriba
    if p.y > sh then
      p.y = -p.h
      p.x = rnd(0, sw)
    end
    -- reciclado horizontal: el viento tambien saca papelitos por un lado
    if p.x < -4 then
      p.x = sw + 4
    elseif p.x > sw + 4 then
      p.x = -4
    end
  end
end

--------------------------------------------------------------------------------
-- Dibujo
--------------------------------------------------------------------------------

-- Texto con relieve, como hud_text del HUD pero sin depender de el.
local function texto(x, y, s, col)
  if col == color(0xFF, 0xFF, 0xFF, 0xFF) then
    gui.text(x + 1, y + 1, s, color(0x00, 0x00, 0x00, 0xB0))
  else
    gui.text(x - 1, y - 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x + 1, y - 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x - 1, y + 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
    gui.text(x + 1, y + 1, s, color(0xFF, 0xFF, 0xFF, 0xC0))
  end
  gui.text(x, y, s, col)
end

-- Ancho aproximado de una cadena. La fuente de FBNeo no expone medicion, asi
-- que se usa el ancho fijo de 6 px del HUD (CHAR_W en LLUVIA RECTA.LUA) y se
-- descuenta lo que ocupan menos espacios y puntuacion.
local CHAR_W = 6

local function ancho(s)
  local w = #s * CHAR_W
  local extra = 0
  for i = 1, #s do
    local c = string.sub(s, i, i)
    if c == " " or c == "." or c == "," or c == ":" then
      extra = extra - 2
    end
  end
  return w + extra
end

local function dibujar_confeti()
  local sw, sh = emu.screenwidth(), emu.screenheight()
  for i = 1, #confeti do
    local p = confeti[i]
    if p.y > -p.h and p.y < sh and p.x > -p.w and p.x < sw then
      gui.box(p.x, p.y, p.x + p.w, p.y + p.h, p.c, p.c)
    end
  end
end

local function dibujar_menu()
  local sw, sh = emu.screenwidth(), emu.screenheight()

  local w, h = 218, 136
  local x = math.floor((sw - w) / 2)
  local y = math.floor((sh - h) / 2)
  gui.box(x, y, x + w, y + h, PANEL_FILL, PANEL_LINE)

  -- Titulo centrado
  local titulo = "HALL OF FAME"
  texto(x + math.floor((w - ancho(titulo)) / 2), y + 7, titulo, TITULO_COLOR)
  gui.drawline(x + 8, y + 17, x + w - 8, y + 17, PANEL_LINE)

  -- Entradas
  local fila_y = y + 24
  -- 19 px por fila: con radio 9 la estrella mide 18 de alto, asi que con menos
  -- se tocaban entre fila y fila.
  local fila_h = 19
  for i = 1, #RANKING do
    local e = RANKING[i]
    local puesto, nombre, estrellas = e[1], e[2], e[3]
    local ly = fila_y + (i - 1) * fila_h

    texto(x + 12, ly, tostring(puesto), PUESTO_COLOR)
    texto(x + 22, ly, nombre, NOMBRE_COLOR)

    -- Todas las estrellas en la misma columna, para que se lean como columna.
    -- 21 px de separacion: la estrella mide 18 de ancho y no se tocan.
    local sx = x + 136
    for s = 1, estrellas do
      estrella(sx + (s - 1) * 21, ly + 5, ESTRELLA_R)
    end
  end

  -- Pie
  texto(x + math.floor((w - ancho(PIE)) / 2), y + h - 12, PIE, PIE_COLOR)
end

-- El confeti va POR ENCIMA de todo, con el menu abierto o no.
local function dibujar()
  local sw, sh = emu.screenwidth(), emu.screenheight()

  if menu_open then
    -- Velo: oscurece la arena para que el menu mande sobre el combate.
    gui.box(0, 0, sw, sh, color(0x00, 0x00, 0x00, 0xC0), color(0x00, 0x00, 0x00, 0x00))
    dibujar_menu()
  end

  if confetti_on and #confeti > 0 then
    dibujar_confeti()
  end
end

--------------------------------------------------------------------------------
-- Entrada por frame
--
-- El juego va a 60 Hz, asi que un frame = 1/60 s y los umbrales se cuentan en
-- frames. Se disparan con IGUALDAD, no con >=, para que cada uno pase una sola
-- vez mientras se mantiene pulsado.
--
--   mantener 2 s -> abre el menu
--   mantener 3 s -> toggle del confeti
--
-- Mantener 3 s por lo tanto hace LAS DOS COSAS: abre a los 2 s y prende el
-- confeti a los 3 s. Es lo que hace falta para dejar el confeti sonando con el
-- menu cerrado, asi que se deja asi a proposito.
--------------------------------------------------------------------------------

local function update()
  local pad = joypad.get()
  -- joypad.get() solo trae las teclas pulsadas: se comprueba por truthiness
  local start = pad["P1 Start"] and true or false

  if start then
    hold = hold + 1
    if hold == SEG_MENU then
      if not menu_open then
        menu_open = true
        if #confeti == 0 then llenar() end
      end
    elseif hold == SEG_CONFETI then
      confetti_on = not confetti_on
      if confetti_on and #confeti == 0 then llenar() end
    end
  else
    -- Se solto START. Si fue una pulsacion CORTA y el menu estaba abierto, se
    -- cierra. Con pulsacion larga ya se habria abierto/prendido antes.
    if hold > 0 and hold < SEG_MENU then
      if menu_open then
        menu_open = false
      end
    end
    hold = 0
  end

  if confetti_on then
    mover()
  end

  own_frame = own_frame + 1
  dibujar()
end

emu.registerafter(update)

print(string.format("[yuyu] HALL OF FAME listo. START 2s menu / 1 vez cerrar / "
                    .. "3s confeti. rom=%s", tostring(emu.romname())))
