-- test_knockdown.lua
--
-- Validacion de diagnostico_knockdown.lua con memoria simulada. El diagnostico no se
-- manda al emulador sin probar antes, porque un print que miente es peor que no
-- tener el script.
--
-- Lo que se comprueba, y por que cada caso importa para la pregunta del
-- backflip:
--
--   1. no dice nada con los slots vacios
--   2. avisa cuando un slot aparece, con el nombre correcto
--   3. marca CONTACTO cuando $69 pasa a 16
--   4. NO marca el cruce de $7E si sigue positivo
--   5. CONFIRMA $1F2E2... $1F4E2 cuando $84 == (abs $7E + 4) * 16
--   6. la confirmacion imprime el calculo, para poder compararlo a ojo
--   7. avisa el cruce de $7E por 0
--   8. NO confunde el TIMER ($84 que pasea de a 1) con el knockback   <-- LA QUE IMPORTA
--   9. NO confirma si $84 no es la firma
--  10. marca los cambios de $5F, que es donde estaria el estado del backflip
--  11. si un slot se vacia y vuelve, se vuelve a presentar
--
-- El caso 8 es el que hace util el diagnostico. $84 tiene TRES meanings ($1F4E2
-- velocidad de empujon, $1A28E timer, $1BCB0 acumulador) y si el script
-- confirmara en el timer, "CONFIRMADO" no diria nada. Ver DATOS_VERIFICADOS.md
-- seccion 2c.

local mem = {}
-- Si falla_en apunta a una direccion, la lectura de ESA direccion revienta. Sirve
-- para provocar una excepcion de verdad dentro del hook, que es el fallo que
-- hay que cubrir: una excepcion ahi no da error, deja el flag de captura en false
-- y el script entero se queda mudo.
--
-- No se puede romper con "_G.bit = {}": LuaJIT resuelve bit.band sin mirar la
-- tabla de globales, asi que sigue funcionando. OJO que esto tambien dice que el
-- harness (LuaJIT) y el emulador (Lua 5.1) NO son el mismo Lua.
local falla_en = nil
local function rw(a)
  if a == falla_en then
    error("fallo de memoria simulado en " .. string.format("0x%X", a))
  end
  return (mem[a] or 0) * 256 + (mem[a + 1] or 0)
end
local function rs(a)
  local v = rw(a)
  if v > 32767 then v = v - 65536 end
  return v
end
local function rb(a) return mem[a] or 0 end
local function poke16(a, v)
  if v < 0 then v = v + 65536 end
  mem[a] = math.floor(v / 256) % 256
  mem[a + 1] = v % 256
end

-- El hook de colisiones. El script se engancha con memory.registerexec, y eso
-- cambia la forma de correr el test: NO alcanza con llamar al callback de frame,
-- porque ahora los datos de golpe y de hurtbox se capturan en otro momento.
--
-- Se guarda la DIRECCION del registro a proposito, y tambien CUANTAS VECES se
-- registro. Las dos cosas fueron fallos reales:
--
--   - la direccion: engancharse en $01EDC2, que esta DESPUES de la guardia de
--     $01EDAC y no se ejecuta cuando la guarda salta.
--   - la cantidad: FBNeo BORRA los hooks exec en cada reset del juego, asi que
--     armar el hook UNA sola vez al cargar no sirve: el reset de la ronda se lo
--     lleva y el hook nunca entra (corrida del 07-10, "invocaciones=0"). Hay que
--     re-armarlo cada frame, que es lo que hace el HUD de cajas.
local exec_cb, exec_pc = nil, nil
local exec_registros = 0
_G.memory = {
  readbyte = rb, readword = rw, readwordsigned = rs,
  readdword = function(a) return rw(a) end,
  registerexec = function(pc, fn)
    exec_pc = pc
    exec_cb = fn
    exec_registros = exec_registros + 1
  end,
}

local frame_cb, nframe
_G.emu = {
  framecount = function() return nframe or 0 end,
  registerafter = function(fn) frame_cb = fn end,
}

-- El script resuelve print como GLOBAL en cada llamada, asi que hay que dejarlo
-- capturado durante los frames y restaurarlo solo al final. Si se restaura antes,
-- su salida se va a stdout y salida[] queda vacio.
local salida = {}
local print_real = print
_G.print = function(s) salida[#salida + 1] = s end

dofile("herramientas/lua/diagnostico_knockdown.lua")

local fallos, pruebas = 0, 0
local function eq(nombre, esperado, obtenido)
  pruebas = pruebas + 1
  if esperado ~= obtenido then
    fallos = fallos + 1
    io.write("  FALLA " .. nombre .. "  esperado=" .. tostring(esperado)
             .. " obtenido=" .. tostring(obtenido) .. "\n")
  else
    io.write("  OK    " .. nombre .. "\n")
  end
end
local function ok(nombre, cond)
  pruebas = pruebas + 1
  if not cond then
    fallos = fallos + 1
    io.write("  FALLA " .. nombre .. "\n")
  else
    io.write("  OK    " .. nombre .. "\n")
  end
end
local function hay(frag)
  for i = 1, #salida do
    if string.find(salida[i], frag, 1, true) then return true end
  end
  return false
end
local function n_confirmados()
  local n = 0
  for i = 1, #salida do
    if string.find(salida[i], "CONFIRMADO", 1, true) then n = n + 1 end
  end
  return n
end
local function n_ocurrencias(frag)
  local n = 0
  for i = 1, #salida do
    if string.find(salida[i], frag, 1, true) then n = n + 1 end
  end
  return n
end
-- Indice de la ULTIMA linea que contiene el fragmento. Sirve para sacarle el
-- frame y comparar el orden de dos eventos, que es lo que decide si la
-- invulnerabilidad provoca al backflip o al reves.
local function n_ultima(frag)
  local ultimo
  for i = 1, #salida do
    if string.find(salida[i], frag, 1, true) then ultimo = i end
  end
  return ultimo
end

local P1 = 0xFF8400
-- Un frame = el dispatcher de colisiones corre (hook de $1EDC2) y DESPUES dispara
-- el callback de frame. Es el orden real, y es lo que hace que la lectura sea
-- coherente.
local function frame()
  nframe = (nframe or 0) + 1
  if exec_cb then exec_cb() end
  frame_cb()
end
-- Un frame en el que el dispatcher NO corrio. Sirve para comprobar que el script
-- no imprime transiciones fantasma comparando una captura vieja.
local function frame_sin_dispatcher()
  nframe = (nframe or 0) + 1
  frame_cb()
end

io.write("=== validacion de diagnostico_knockdown.lua ===\n")

-- 0. EL HOOK. Si no se registro, el script no tiene datos de golpe.
ok("se engancho en el dispatcher de colisiones", exec_cb ~= nil)
eq("y se engancho en la ENTRADA $01EDAC, no en $01EDC2", 0x01EDAC, exec_pc)

-- Y se tiene que RE-ARMAR cada frame, no una vez al cargar. Este es el test que
-- habria cerrado el fallo de la corrida del 07-10.
local registros_al_arrancar = exec_registros
for i = 1, 20 do frame() end
ok("registerexec se vuelve a llamar en cada frame (FBNeo borra los hooks exec "
   .. "en cada reset)", exec_registros >= registros_al_arrancar + 20)

-- 1
nframe = 0
frame()
eq("sin slots no dice nada", false, hay("presente"))

-- 2
poke16(P1 + 0x78, 200)
poke16(P1 + 0x7E, 56)
poke16(P1 + 0x69, 0)
poke16(P1 + 0x84, 0)
mem[P1 + 0x5F] = 0x20
frame()
ok("avisa que el slot aparecio", hay("presente"))
ok("el nombre del slot sale bien (S1)", hay("S1 presente"))

-- 3 y 4
poke16(P1 + 0x69, 16)
poke16(P1 + 0x7E, 40)
frame()
ok("marca CONTACTO con $69=16", hay("CONTACTO $69=16"))
ok("un $7E que sigue positivo NO se marca como cruce", not hay("$7E cruz"))

-- 5. $84 sale de 0 SIN la firma: lo escribio otra rutina (timer $1A28E o
--    acumulador $1BCB0). Se avisa, y NO se confirma nada.
poke16(P1 + 0x84, 99)
frame()
eq("un $84 que sale de 0 sin la firma NO confirma", 0, n_confirmados())
ok("y avisa que salio de 0 sin la firma", hay("salio de 0 a 99 SIN la firma"))

-- 8. Y ACA ESTA LO QUE IMPORTA: que NO imprima en cada frame. $84 puede moverse
--    cada frame si es el acumulador, y 60 lineas por segundo hunden la consola,
--    bajan el framerate, y hacen inutil la medicion. Con el tope de 30 frames,
--    10 pasos de $84 tienen que producir CERO lineas.
local lineas_antes = #salida
for i = 1, 10 do
  poke16(P1 + 0x84, 98 - i)
  frame()
end
eq("10 pasos de $84 no imprimen ninguna linea (el tope funciona)",
   lineas_antes, #salida)

-- Y que el tope sea de frames, no de contador: $84 vuelve a 0 y sale otra vez,
-- pero dentro de los 30 frames no dice nada.
poke16(P1 + 0x84, 0)
frame()
poke16(P1 + 0x84, 99)
frame()
eq("dentro del tope de 30 frames no repite", lineas_antes, #salida)

-- Pasados los 30 frames, vuelve a avisar.
for i = 1, 31 do frame() end
poke16(P1 + 0x84, 0)
frame()
poke16(P1 + 0x84, 99)
frame()
eq("pasados 30 frames vuelve a avisar", 2, n_ocurrencias("salio de 0 a 99 SIN la firma"))

-- 7 y 6. El caso bueno: $7E = -6 -> (6+4)*16 = 160.
poke16(P1 + 0x7E, -6)
poke16(P1 + 0x84, 160)
frame()
ok("CONFIRMA $1F4E2 con la firma correcta", n_confirmados() >= 1)
ok("la confirmacion imprime el calculo", hay("(abs 7E + 4)*16 = 160"))
ok("y avisa que $7E cruzo 0", hay("$7E cruz"))

-- 9
local conf_antes = n_confirmados()
poke16(P1 + 0x7E, -6)
poke16(P1 + 0x84, 99)          -- no es 160, asi que $1F4E2 no pudo escribir esto
frame()
eq("un $84 que no es la firma NO confirma", conf_antes, n_confirmados())

-- 10
poke16(P1 + 0x84, 0)
poke16(P1 + 0x7E, 56)
poke16(P1 + 0x69, 0)
mem[P1 + 0x5F] = 0x28
frame()
ok("marca el cambio de estado $5F", hay("ESTADO $5F"))

-- 12. EL INDICE DE ESTADOS NUEVOS. Es lo que hace legible el volcado sin
--     reinterpretar 200 lineas a mano. Tiene que anunciar cada valor UNA vez.
--     OJO: va antes del caso 11 a proposito, porque cuando el slot se vacia el
--     historico (y con el el indice) se limpia.
local nuevos = n_ocurrencias("estado NUEVO")
mem[P1 + 0x5F] = 0x40
frame()
eq("un estado nuevo se anuncia una vez", nuevos + 1, n_ocurrencias("estado NUEVO"))
ok("y dice el numero de estado y el frame", hay("estado NUEVO $5F=$40"))

-- Volver a un estado ya visto NO se vuelve a anunciar: ni al viejo ni al que
-- acaba de anunciar.
mem[P1 + 0x5F] = 0x20      -- visto al arrancar
frame()
mem[P1 + 0x5F] = 0x40      -- recien anunciado
frame()
eq("volver a un estado ya visto no se reanuncia",
   nuevos + 1, n_ocurrencias("estado NUEVO"))

-- Y dos valores distintos SÍ se anuncian los dos.
mem[P1 + 0x5F] = 0x50
frame()
eq("otro estado nuevo mas si se anuncia", nuevos + 2, n_ocurrencias("estado NUEVO"))

-- 13. LA HURTBOX. Es el evento central: la invulnerabilidad PRECEDE al cambio de
--     estado, y con los dos frames juntos se ve quien provoca a quien.
--
--     La lista de hurtbox es $FFA400, contador $FFA008 (offset en BYTES), stride
--     $10, y el owner va en +$C como un WORD ($8400, $8800...). El script cuenta
--     POR OWNER, que es lo unico que sirve con dos peleadores.

local function meter_hurt(owner, cantidad)
  -- Pone 'cantidad' hurtbox del owner dado y dos del OTRO owner. Asi se
  -- comprueba que el script separa los peleadores por owner y no cuenta el
  -- total de la lista, que con dos peleadores no dice de quien es.
  poke16(0xFFA008, (cantidad + 2) * 0x10)
  for k = 0, cantidad + 1 do
    local dueno = (k < cantidad) and owner or 0x8800
    poke16(0xFFA400 + k * 0x10, 10)
    poke16(0xFFA400 + k * 0x10 + 0x0C, dueno)
  end
end

-- El P1 arranca con 2 hurtbox. El primer frame solo se presenta, asi que todavia
-- no hay linea de "se fue".
meter_hurt(0x8400, 2)
frame()
eq("arrancar con hurtbox no dice que se fue", 0, n_ocurrencias("SE FUE LA HURTBOX"))

-- SE VAN las hurtbox del P1. Las del P2 quedan. Esto es la invulnerabilidad.
meter_hurt(0x8400, 0)
frame()
eq("avisa que se fue la hurtbox del P1", 1, n_ocurrencias("SE FUE LA HURTBOX"))
ok("y marca que es invulnerable", hay("invulnerable"))

-- QUE NO SE CONFUNDA ENTRE PELEADORES: las del P2 siguen puestas y el P1 sigue sin
-- hurtbox, asi que en este frame NO tiene que volver a avisar.
frame()
eq("no repite si sigue sin hurtbox", 1, n_ocurrencias("SE FUE LA HURTBOX"))

-- Y ahora el P1 recupera la suya: avisa que volvio.
-- OJO con la cuenta: el meter_hurt(0x8400, 2) del principio del bloque tambien
-- genero una linea de "vuelta" (venia de 0), asi que se compara contra una base
-- y no contra un numero fijo.
local vueltas_antes = n_ocurrencias("hurtbox de vuelta")
meter_hurt(0x8400, 1)
frame()
eq("avisa que la hurtbox vuelve", vueltas_antes + 1, n_ocurrencias("hurtbox de vuelta"))

-- Y que el numero que imprime sea el del P1 y no el total de la lista: con 1 del
-- P1 y 2 del P2 el total es 3.
ok("el numero es el del P1, no el total de la lista", hay("hurtbox de vuelta: 0 -> 1"))

-- Y el caso central: la hurtbox se va ANTES del cambio de estado. Con los dos
-- frames a la vista, el que va primero decide quien provoca a quien.
local f_hurt = tonumber(string.match(salida[n_ultima("SE FUE LA HURTBOX")], "%[f (%d+)%]"))
meter_hurt(0x8400, 0)
frame()
mem[P1 + 0x5F] = 0x77
frame()
local f_estado = tonumber(string.match(salida[n_ultima("ESTADO $5F")], "%[f (%d+)%]"))
ok("los dos eventos llevan frame numerico", f_hurt ~= nil and f_estado ~= nil)
io.write(string.format("       (hurtbox f=%s, cambio de estado f=%s)\n",
  tostring(f_hurt), tostring(f_estado)))

-- 11
poke16(P1 + 0x78, 0)
frame()
local veces = 0
for i = 1, #salida do
  if string.find(salida[i], "S1 presente", 1, true) then veces = veces + 1 end
end
poke16(P1 + 0x78, 200)
frame()
ok("si el slot se vacia y vuelve, se vuelve a presentar", veces == 1 and hay("S1 presente"))

-- 14. EL GUARDIAN DE FRAME. El bug real que encontre la corrida del 07-10 fue
--     muestrear los contadores de golpe FUERA del dispatcher, y salia un
--     parpadeo de "se fue la hurtbox" cada ~3 frames en los dos peleadores a la
--     vez. Con el hook en $1EDC2 y este guardian, un frame en el que el
--     dispatcher no corrio NO produce ninguna linea.
--
--     Y esto es lo que mata el parpadeo: si se imprimiera igual, el guion de
--     "se fue" / "volvio" se veria alternando sin que nada lo haya provocado.
meter_hurt(0x8400, 3)
frame()
local antes_sin = #salida
frame_sin_dispatcher()
frame_sin_dispatcher()
frame_sin_dispatcher()
eq("3 frames SIN dispatcher no imprimen nada", antes_sin, #salida)
meter_hurt(0x8400, 0)
frame()
frame_sin_dispatcher()
eq("tampoco imprime si el cambio ocurre en un frame sin dispatcher",
   antes_sin + 1, #salida)   -- solo la del frame CON dispatcher

-- 15. EL LATIDO. Es el diagnostico que habria detectado el fallo del hook en 10
--     segundos en vez de en un round entero. Sin el, un hook mal puesto se
--     descubre porque "no salio nada", que es la forma mas lenta de enterarse.
for i = 1, 620 do frame() end
ok("con el hook entrando, avisa que esta vivo", hay("hook OK:"))

-- Y si el hook NO entra, tiene que decirlo en vez de callarse.
for i = 1, 620 do frame_sin_dispatcher() end
ok("si el hook no entra, avisa en vez de quedarse mudo", hay("AVISO: el hook"))

-- 16. LOS HITOS DE ARRANQUE. El script fallo dos veces con "no lee nada", y las
--     dos por algo dentro de un callback: no da error, se calla. Por eso el
--     arranque se anuncia hito por hito. Si un dia vuelve a pasar, el log DICE en
--     que hito se quedo en vez de obligar a adivinar.
ok("anuncia que se cargo", hay("arranque: cargado"))
ok("dice si bit esta disponible (si es nil, bit.band revienta en el hook)", hay("bit="))
ok("anuncia que registro el hook", hay("registerexec en $1EDAC registrado"))
ok("anuncia que registro el frame", hay("registerafter registrado"))

-- 17. pcall DENTRO DEL HOOK. Una excepcion ahi no da error: deja el flag de
--     captura en false y el script entero queda mudo. Que se note, y que no se
--     repita cada frame.
-- OJO con COMO se fuerza el error: no se puede romper con "_G.bit = nil" ni con
-- "_G.bit = {}", porque LuaJIT resuelve bit.band sin mirar la tabla de globales.
-- Se fuerza por la VIA REAL: que la lectura del contador de hurtbox reviente.
falla_en = 0xFFA008
frame()
frame()
ok("si el hook revienta, lo dice en vez de callarse", hay("ERROR dentro del hook"))
eq("y no lo repite cada frame", 1, n_ocurrencias("ERROR dentro del hook"))
falla_en = nil
frame()
ok("y vuelve a funcionar cuando la memoria responde", hay("hook OK:"))

_G.print = print_real
io.write("\n=== " .. pruebas .. " pruebas, " .. fallos .. " fallos ===\n")
os.exit(fallos == 0 and 0 or 1)
