--[[
  diagnostico_slots.lua — Diagnostico de SOLO LECTURA.

  Que responde:
    1. Que valor de `$69` (hitpause) tiene CADA personaje en cada momento.
       El 255 es la ulti de Itsuki: congela a los que no son aliados.
    2. Que valor de `$58` tiene cada uno. OJO: `$58` solo tiene UN consumidor
       (loc_01FA70) y esa rutina solo se llama con `$78` negativo, o sea al
       morir. NO es un codigo por golpe, asi que no va a cambiar cada ataque.
    3. Que slot esta poblado de verdad. No supone nada: mira los 4.

  Modos: funciona en 1v1, 3vs3, 4vs4 y tambien en entrenamiento, porque NO
  asume que el humano este en el primer slot. Detecta cuales slots estan
  poblados por HP y los sigue a todos.

  Uso:
    Game > Lua Scripting > New Lua Script Window > Browse > diagnostico_slots.lua
    1. Entrar al combate. Sale el volcado con los slots poblados.
    2. Pulsar un boton de la P1 -> marcador [*] con el frame.
    3. Hacer la ULT de Itsuki DESPUES del marcador.
    4. Copiar la salida.

  Marcadores:
    Con cualquier boton de la P1 pulsado sale un "[*]" con el frame. Hacelas
    ultimas despues del marcador: el 255 dura poco si te pegan.

  NO escribe nada en la memoria del juego. Solo memory.read* y print.
  Ver la regla 5 de MEMORIA.md.
--]]

-- Los 4 slots del array. El bucle de $1C06A los recorre de a $400 asi que
-- estos cuatro son todos los que existen.
local SLOTS   = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }

local rb  = memory.readbyte
local rw  = memory.readword
local rws = memory.readwordsigned

-- Offsets del struct del jugador
local OFF_58   = 0x58   -- codigo, solo se usa al morir (ver cabecera)
local OFF_HP   = 0x78   -- word SIGNED. Negativo = muerto
local OFF_STUN = 0x7E   -- word. Cuenta PARA ABAJO desde $80
local OFF_MP   = 0xB8   -- largo 16.16, el entero esta en la palabra alta
local OFF_MOVE = 0x5F
local OFF_HITP = 0x69   -- 0 / 16 / 28 / 255
local OFF_SEL  = 0x9E   -- selector de personaje. OJO: NO es $9C

-- Globales de la cola de acciones
local A030 = 0xFFA030   -- la peticion
local F809 = 0xFFF809   -- codigo de la accion que GANO el frame
local F80A = 0xFFF80A   -- canal 1
local F80B = 0xFFF80B   -- canal 2
local F80C = 0xFFF80C   -- canal 3
local F80D = 0xFFF80D   -- canal 4

-- Camara lenta de muerte: el contador y su flag. Cuando el HP llega a negativo
-- el juego pone $F558 = 160, y $F55A se prende en los frames impares.
local F558 = 0xFFF558   -- word, contador
local F55A = 0xFFF55A   -- byte, flag de este frame

-- Contador propio de frames: emu.framecount() se resetea al cargar un
-- savestate y partiria la linea de tiempo en dos.
local frame = 0

local function hx(v)  return string.format("%02X", v) end
local function hxw(v) return string.format("%04X", v) end

local function pulsada()
  local pad = joypad.get()
  if pad["P1 Button A"] or pad["P1 Button B"] or pad["P1 Button C"]
     or pad["P1 Start"] then return true end
  return false
end

-- -----------------------------------------------------------------------------
-- QUE SLOTS ESTAN POBLADOS
--
-- No se asume nada. Se mira el HP de los 4 y se siguen todos los que tengan
-- vida. Asi el script sirve igual en 1v1, 3vs3, 4vs4 y en entrenamiento, donde
-- el humano puede estar en cualquier slot.
-- -----------------------------------------------------------------------------

local activos = {}      -- indices en SLOTS de los que tienen vida
local rotulos = {}      -- su nombre: "jugador 1", "jugador 2", ...

local function index_poblado(i)
  return rws(SLOTS[i] + OFF_HP) ~= 0
end

local function volcar()
  print("")
  print("=== VOLCADO DE LOS 4 SLOTS ===========================================")
  print("")
  print(string.format("  %-6s  %6s  %6s  %6s  %6s  %6s  %6s",
        "slot", "base", "HP", "stun", "mana", "mov", "SEL"))
  activos = {}
  rotulos = {}
  for i = 1, #SLOTS do
    local b = SLOTS[i]
    local hp = rws(b + OFF_HP)
    print(string.format("  %-6s  %s  %6d  %6d  %6d  %6s  %6s",
          "slot" .. (i - 1), hxw(b), hp, rws(b + OFF_STUN),
          bit.band(rw(b + OFF_MP), 0x00FF),
          hx(rb(b + OFF_MOVE)), hx(rb(b + OFF_SEL))))
    if index_poblado(i) then
      activos[#activos + 1] = i
      rotulos[#rotulos + 1] = "jugador" .. #activos
    end
  end
  print("")
  print("  HP negativo = muerto.   SEL = $9E (NO $9C: ese vale $0000)")
  print("  Slots con vida: " .. #activos)
  for n = 1, #activos do
    print(string.format("    %s = %s", rotulos[n], hxw(SLOTS[activos[n]])))
  end
  print("")
  if #activos < 2 then
    print("  -> Menos de 2 con vida. Si no estas en combate, entrá.")
  else
    print("  -> El ULT de Itsuki congela a los que NO son aliados.")
    print("  -> El 255 tiene que aparecer en los OTROS, no en el que lo hace.")
  end
  print("=======================================================================")
end

-- -----------------------------------------------------------------------------
-- SEGUIMIENTO: imprime SOLO cuando algo cambia
-- -----------------------------------------------------------------------------

local prev = {}
local vol = false

local function sigue(clave, valor, texto)
  if prev[clave] == valor then return end
  prev[clave] = valor
  print(string.format("  f%-6d %s", frame, texto))
end

local marcado = false

local function linea_de_la_cola()
  return "canales = " .. hx(rb(F80A)) .. " " .. hx(rb(F80B)) .. " "
                  .. hx(rb(F80C)) .. " " .. hx(rb(F80D))
end

local function seguir()
  -- El objetivo: $69 de TODOS, para ver el 255 de la ult
  for n = 1, #activos do
    local b = SLOTS[activos[n]]
    local r = rotulos[n]
    sigue("hitp" .. n, rb(b + OFF_HITP),
          "$69 " .. r .. " = " .. rb(b + OFF_HITP))
    sigue("hpb" .. n, rws(b + OFF_HP),
          "HP " .. r .. " = " .. rws(b + OFF_HP))
    sigue("c58" .. n, rb(b + OFF_58),
          "$58 " .. r .. " = " .. hx(rb(b + OFF_58)))
  end

  -- La cola de acciones
  sigue("a030", rb(A030), "$A030  peticion = " .. hx(rb(A030)))
  sigue("cola", rb(F80A) + rb(F80B) * 256 + rb(F80C) * 65536
                + rb(F80D) * 16777216, linea_de_la_cola())
  sigue("f809", rb(F809), "$F809  gana    = " .. hx(rb(F809)))

  -- Camara lenta de muerte
  sigue("f558", rw(F558), "$F558 camara lenta = " .. hxw(rw(F558))
                        .. "   $F55A = " .. hx(rb(F55A)))
end

local function al_frame()
  frame = frame + 1

  if not vol then
    for i = 1, #SLOTS do
      if index_poblado(i) then volcar(); vol = true; break end
    end
    return
  end

  if pulsada() and not marcado then
    print("")
    print(string.format("=== [*] MARCADOR en el frame %d ========================", frame))
    marcado = true
  elseif not pulsada() then
    marcado = false
  end

  seguir()
end

-- -----------------------------------------------------------------------------

print("")
print("[yuyu] diagnostico de slots, $69 y $58 cargado.")
print("[yuyu] 1) entrar a un combate -> volcado de los slots con vida")
print("[yuyu] 2) boton de la P1 -> marcador [*]")
print("[yuyu] 3) hacer la ult de Itsuki DESPUES del marcador")
print("[yuyu] 4) copiar la salida de consola")
print("[yuyu] 100% pasivo: solo memory.read* y print")

emu.registerafter(al_frame)
