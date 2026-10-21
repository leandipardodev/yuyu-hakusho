-- diagnostico_knockdown.lua
--
-- ============================ NO FUNCIONA EN ESTA BUILD ============================
--
-- Sintoma exacto: imprime el mensaje de arranque y despues
--
--   [f 600] AVISO: el hook de $1EDAC no ha corrido todavia (invocaciones=0).
--
-- o sea que **el exec hook NO ENTRA**, una vez solved el re-armado por frame y
-- el PC. El latido funciona (por eso se ve el AVISO), lo que falla es el hook.
--
-- Lo que SI quedo bien y vale la pena:
--   - el latido, que convierte "no lee nada" en un sintoma con numero
--   - el pcall con flag propio, para que una excepcion no se calle
--   - la forma de contar hurtboxes POR OWNER
--   - la firma `$84 == (abs 7E + 4) * 16`, que CONFIRMO $1F4E2 sin interpretar
--
-- NO REINTENTAR sin resolver antes POR QUE el hook no entra. Cuatro intentos
-- fallidos y la razon del ultimo estaba escrita en el HUD de cajas:
-- "FBNeo BORRA los hooks exec en cada reset del juego... Por eso se re-arma cada
-- frame". Eso ya se hizo y no alcanzo. La pista que queda es que
-- memory.registerexec podria no existir o no disparar en esta build de FBNeo, y
-- habria que comprobarlo con un registro en un PC inequivoco.
--
-- La medicion del backflip se esta haciendo A MANO, con el HUD de cajas.
-- ==================================================================================
--
-- DIAGNOSTICO PASIVO para cerrar una pregunta: el backflip en el aire y el
-- knockdown, ¿salen por el mismo camino?
--
-- Lo que ya esta verificado leyendo el codigo (DATOS_VERIFICADOS.md 2c):
--
--   La salida del hitstun es UNA SOLA RAMA, sin test de suelo:
--
--     01f4d6:  cmpi.w  #$0, $7e(a4)
--     01f4dc:   blt.b   $1f4e2
--     ...
--     01f4ee:  move.w  d0, $84(a4)     ; $84 = (|$7E| + 4) * 16
--
--   O sea que el DISPARADOR es el mismo en los dos casos. Lo que los distingue
--   (backflip, invulnerable, levantarse del suelo) tiene que estar mas abajo, en
--   la maquina de estados de $5F. Y ESO no tiene direccion todavia.
--
-- QUE MIRA ESTE SCRIPT
--
--   $7E   stun: el PRESUPUESTO. Se gasta por golpe (sub.w $66 en 0x1F42C)
--   $84   el campo sobrecargado. Un solo escritor lo pone en nonzero: $1F4E2
--   $5F   id de estado / de move. Si el backflip tiene estado propio, aparece aca
--   $69   hitpause: 16 = golpe, 28 = clash. Marca los contactos
--
-- POR QUE ES AUTOVERIFICABLE
--
--   El knockback se escribe SIEMPRE con el mismo calculo:
--
--     $84 = (|$7E| + 4) * 16
--
--   Asi que cuando $84 == (|$7E| + 4) * 16 se SABE que $1F4E2 corrio, sin
--   interpretar nada. Eso permite marcar los eventos como CONFIRMADOS en vez de
--   "creo que esto es un knockdown". Y si el backflip arranca con $84 todavia en
--   0, tambien es una conclusion firme: es otro camino.
--
-- NO HAY QUE TOCAR NADA MIENTRAS SE PELEA. Ni botones, ni el marcador. Este
-- script no lee el mando: se juega normal, los dos peleadores.
--
-- Como leerlo
--
--   hook OK: N invocaciones   -> el hook esta entrando. Si no aparece, no entra.
--   CONFIRMADO  $1F4E2 corrio en ese frame. Knockback.
--   $5F cambia  -> ese es el estado del backflip. Copiar el numero.
--   $84 cuenta  descendiendo solo, o sube de a 1: eso NO es el knockback, es el
--                 timer de $1A28E o el acumulador de $1BCB0.
--   SE FUE LA HURTBOX  -> se quedo invulnerable.
--   Y < el maximo que muestre el slot = esta en el aire. En la corrida del 07-10
--   el suelo era Y=320.
--
-- Los slots se detectan por HP, no se suponen. Ver MEMORIA.md, seccion de slots.
--
-- OJO CON EL MUNECO DE PRACTICA: este script solo ve lo que hay en un slot con
-- HP. Si el muñeco de practica de la pantalla de entrenamiento no llena un slot
-- de jugador, no va a aparecer aca. En ese caso hay que medir contra la CPU en un
-- 1v1 de verdad: el que hace el backflip es el rival, y este script lo detecta
-- solo por ser el segundo slot con vida.

-- Tope de lineas del caso "no esencial" ($84 salio de 0 sin la firma). 30 frames
-- son 2 lineas por segundo por slot. Ver el punto 5 del final: sin este tope, un
-- $84 que se mueve cada frame hunde la consola y tira el framerate, y una
-- medicion con el framerate caido no sirve.
local FRAME_PASEO = 30

local SLOTS = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }

local OFF_HP    = 0x78
local OFF_STUN  = 0x7E
local OFF_STATE = 0x5F
local OFF_KB    = 0x84
local OFF_HITP  = 0x69
local OFF_Y     = 0x44

local r  = memory.readword
local rs = memory.readwordsigned
local rb = memory.readbyte

-- Dónde se leen las cosas de un golpe. TODO lo que cambia durante un frame
-- de combate tiene que leerse AQUÍ, no en registerafter.
--
-- loc_01EDAC, el dispatcher de colisiones:
--
--   01edac:  btst.b   #$7, $f550.w    ; guardia: si esta busy saltea TODO
--   01edb2:   bne.b   $1ee1c          ;   y NO pone los contadores en 0
--   01edb4:  bsr.w    $1eee2          ; grab
--   01edb8:  bsr.w    $1f090          ; clash  -> $69 = 28
--   01edbc:  bsr.w    $1f21e          ; hit    -> $69 = 16, $7E -= $66, $84
--   01edc0:  bsr.b    $1ee1e          ; push
--   01edc2:  move.w   #$0, $a004.w    ; <- ACA se ponen en 0 los 5 contadores
--
-- $01EDAC es la ENTRADA, y es el unico punto que se alcanza SIEMPRE. Ver la
-- nota de la guardia, abajo, porque hooking en $01EDC2 parece mejor y no lo es.
--
-- POR QUE NO SE PUEDE LEER EN registerafter, y como se nota.
--
-- Primera version de este script: todo en registerafter, una vez por frame. La
-- salida dio esto, 7600 frames y ni un solo CONTACTO:
--
--   [f 7053] hurtbox de vuelta: 0 -> 3
--   [f 7054] *** SE FUE LA HURTBOX ***
--   [f 7056] hurtbox de vuelta: 0 -> 3
--   [f 7057] *** SE FUE LA HURTBOX ***      <- cada ~3 frames, y en LOS DOS
--                                                    peleadores a la vez
--
-- Eso no es invulnerabilidad, es muestreo en el momento equivocado: se leia el
-- contador unas veces antes de que el personaje lo rebuildiera y otras despues.
-- El parpadeo simultaneo en los dos peleadores lo delata.
--
-- LA GUARDIA, y por que $01EDC2 es el sitio PEOR.
--
-- $01EDAC tiene una guarda de entrada, y su destino es un rts:
--
--   01edac:  btst.b   #$7, $f550.w
--   01edb2:   bne.b   $1ee1c        ; <- $1EE1C es un RTS pelado
--   ...
--   01edc2:  move.w   #$0, $a004.w  ; <- los 5 contadores se borran ACA
--
-- O sea que cuando el bit 7 de $F550 esta activo, la rutina **no hace nada**: ni
-- resolvers, ni borrar contadores. Es el bit que se prende en $3ADE y se apaga en
-- $3AEE.
--
-- La segunda version del script se engancho en $01EDC2, que es donde estan los
-- contadores todavia sin borrar y donde $69 ya fue puesto por los resolvers. Es
-- el punto "ideal"... y el resultado fue **cero salida, sin error**: si la
-- guarda salta, $01EDC2 no se ejecuta nunca, el flag de "tengo captura" no se
-- pone, y el callback de frame se returns sin imprimir. Un hook puesto del lado
-- equivocado de una guarda no falla: **se calla**.
--
-- Asi que: **se engancha en la ENTRADA**. Ahi los contadores siguen siendo los
-- del frame (se borran DESPUES, en $01EDC2), y $69, $7E y $84 van con un frame
-- de atraso porque los resolvers corren despues. Ese atraso no importa: $84 dura
-- 148 frames, $7E dura lo que dure, y $69 se queda en 16 durante 16 frames. Lo
-- que decide la pregunta — hurtbox contra cambio de $5F — se lee en el mismo
-- instante y no se corre nada.
local HOOK_COLISIONES = 0x01EDAC

-- Contador de invocaciones del hook. Es el diagnostico que habria detectado el
-- fallo de arriba en 10 segundos en vez de en un round entero: si el numero no
-- sube, el hook no esta entrando y hay que mirar la direccion.
local g_hooks = 0
local g_ultimo_aviso = 0
local g_error_dicho = false
local AVISO_CADA = 600          -- 10 segundos a 60 fps

-- Lo capturado en el hook, para que el dibujado del frame siguiente lo use.
local cap = { ok = false, hurt = {}, hitp = {} }

-- Hurtbox: contador por PROPIETARIO, no el global. Con dos peleadores el total de
-- la lista no dice de quien es.
--
-- MEDIDO (el usuario, con el HUD de cajas): tras un agarre y un golpe suave, la
-- hurtbox del enemigo afectado desaparece unos frames antes del backflip. FALTA
-- CONFIRMAR: en la corrida del 07-10 esas lineas salieron mezcladas con el ruido
-- de muestreo de arriba, asi que no se puede afirmar el orden todavia.
local HURT_BASE   = 0xFFA400
local HURT_CNT    = 0xFFA008
local HURT_STRIDE = 0x10
local HURT_MAX    = 15          -- el maximo de la lista (ver MEMORIA.md)

-- Una pasada por la lista y un cubo por propietario: 15 lecturas por frame para
-- todos los peleadores, no 15 por cada uno.
local function leer_hurtboxes()
  local total = r(HURT_CNT)
  local cubo = {}
  for k = 0, HURT_MAX - 1 do
    if (k + 1) * HURT_STRIDE > total then break end
    local lo = bit.band(r(HURT_BASE + k * HURT_STRIDE + 0x0C), 0xFFFF)
    cubo[lo] = (cubo[lo] or 0) + 1
  end
  return cubo
end

-- ARRANCQUE AUTO-DIAGNOSTICADO.
--
-- Este script fallo dos veces seguidas con "no lee nada", y las dos veces fue por
-- lo mismo: algo dentro de un callback dejo de funcionar SIN DAR ERROR. Un hook
-- que lanza una excepcion no se queja, desaparece. Y en este emulador una
-- excepcion dentro de un callback parece tragarsela entera.
--
-- Por eso cada hito de arranque imprime su linea, y el cuerpo del hook va
-- dentro de pcall. Con eso, si vuelve a pasar, el log DICE en que hito se quedo,
-- en vez de obligar a adivinar. Cuesta cuatro lineas de ruido en la carga.
local function hito(msg)
  print("[yuyu-knockdiag] arranque: " .. msg)
end

hito("cargado. framecount=" .. tostring(type(emu.framecount)))
hito("bit=" .. tostring(type(bit)) .. "  (si es nil, bit.band revienta dentro del hook)")
hito("registerexec disponible=" .. tostring(type(memory.registerexec)))

-- FBNeo **BORRA los hooks exec en cada reset del juego**. Si el script se cargo
-- antes de que arrancara la partida, el hook se perdia y nunca volvia: la
-- corrida dio "invocaciones=0" en los tres primeros avisos de 600 frames.
--
-- Por eso el hook se re-arma CADA FRAME desde el callback de frame, que es lo que
-- hace el HUD de cajas. Registrar el mismo PC otra vez es idempotente y barato.
--
-- Ojo: esto solo sirve si el PC esta bien. El HUD se arma cada frame y funciona;
-- este se armaba una vez y nooreigno nada. Eran las dos cosas a la vez.
local function hook_colisiones()
  g_hooks = g_hooks + 1
  if g_hooks == 1 then
    print("[yuyu-knockdiag] hook ENTRO por primera vez en $"
          .. string.format("%X", HOOK_COLISIONES))
  end

  -- pcall porque una excepcion aqui NO da error: deja el flag de captura en
  -- false y el script entero se queda mudo, que es el sintoma que nos trajo.
  local ok, err = pcall(function()
    cap.hurt = leer_hurtboxes()
    cap.hitp = {}
    for i = 1, #SLOTS do
      cap.hitp[i] = r(SLOTS[i] + OFF_HITP)
    end
  end)

  if not ok then
    -- Se avisa UNA vez y se sigue. El flag es propio y NO es g_hooks == 2: si el
    -- error empieza en el frame 3000, un chequeo por numero de invocacion no lo
    -- dice nunca, que es justo el fallo que estamos tapando.
    if not g_error_dicho then
      g_error_dicho = true
      print("[yuyu-knockdiag] ERROR dentro del hook (invocacion " .. g_hooks
            .. "): " .. tostring(err))
      print("[yuyu-knockdiag] el script sigue vivo pero SIN datos: el flag de "
            .. "captura no se puede poner. Decime esta linea.")
    end
    return
  end

  cap.ok = true
end

-- Un re-arma por frame. Devuelve false si registerexec no existe en esta build,
-- que es otro fallo posible y tambien hay que poder distinguirlo.
local function armar_hook()
  if not memory.registerexec then return false end
  memory.registerexec(HOOK_COLISIONES, hook_colisiones)
  return true
end

if armar_hook() then
  hito("registerexec en $" .. string.format("%X", HOOK_COLISIONES)
       .. " registrado (y se re-arma cada frame: FBNeo los borra en cada reset)")
else
  hito("ATENCION: memory.registerexec NO existe en esta build. El hook no va a "
       .. "entrar nunca.")
end


-- Lo que se recuerda del frame anterior, por slot.
local prev = {}

local function nombre(base)
  for i = 1, #SLOTS do
    if SLOTS[i] == base then return "S" .. i end
  end
  return "?"
end

-- El knockback se escribe SIEMPRE con este calculo. Es la firma de $1F4E2.
local function firma_knockback(stun, kb)
  if stun >= 0 then return nil end
  local esperado = (math.abs(stun) + 4) * 16
  if kb == esperado then return esperado end
  return nil
end

emu.registerafter(function()
  -- PRIMERO: re-armar el hook. FBNeo borra los hooks exec en cada reset del
  -- juego, asi que hay que volver a registrarlo cada frame. Es idempotente.
  --
  -- Va PRIMERO y no en un `if` porque si el hook no esta armado el resto del
  -- frame no tiene nada que comparar y se calla.
  armar_hook()

  local frame = emu.framecount and emu.framecount() or 0

  -- Si el dispatcher de colisiones no ha corrido todavia este frame, NO se
  -- imprime nada de este frame. Sin esto se compararia una captura vieja contra
  -- datos nuevos y saldrian transiciones que no existen.
  --
  -- El frame_presentar corre uno tarde con el objetivo de la captura anterior,
  -- o sea lo que ya estabavalidado cuando el dispatcher corrio en ese instante.
  if not cap.ok then
    -- Sin captura no se imprime nada, porque comparar una captura vieja contra
    -- datos nuevos inventa transiciones. Pero NO se sale en silencio: si esto
    -- pasa seguido, el hook no esta entrando y hay que decirlo.
    if frame - g_ultimo_aviso >= AVISO_CADA then
      g_ultimo_aviso = frame
      print(string.format(
        "[f %d] AVISO: el hook de $%X no ha corrido todavia (invocaciones=%d). " ..
        "Si esto sigue, el hook no entra.", frame, HOOK_COLISIONES, g_hooks))
    end
    return
  end
  cap.ok = false

  -- Latido: una linea cada 10 segundos con cuantas veces entro el hook. Es lo
  -- que delata al instante un hook puesto en el sitio equivocado, en vez de
  -- descubrirlo porque no salio nada.
  if frame - g_ultimo_aviso >= AVISO_CADA then
    g_ultimo_aviso = frame
    print(string.format("[f %d] hook OK: %d invocaciones en $%X",
      frame, g_hooks, HOOK_COLISIONES))
  end

  local hurt = cap.hurt

  for i = 1, #SLOTS do
    local base = SLOTS[i]
    local hp = rs(base + OFF_HP)

    -- Slot vacio: se limpia el historico para que no reaparezca con datos viejos.
    if hp == 0 then
      prev[base] = nil
    else
      local stun = rs(base + OFF_STUN)
      local kb   = r (base + OFF_KB)
      local st   = rb(base + OFF_STATE)
      -- $69 viene del hook de $1EDC2, no de ahora: ver el bloque del hook arriba.
      local hitp = cap.hitp[i] or 0
      local y    = r (base + OFF_Y)

      local p = prev[base]
      local nh = hurt[bit.band(base, 0xFFFF)] or 0
      if p == nil then
        -- Primera vez que se ve este slot: se imprime el estado inicial y se pasa.
        print(string.format(
          "[f %d] %s presente  HP=%d  $7E=%d  $84=%d  $5F=$%02X",
          frame, nombre(base), hp, stun, kb, st))
        prev[base] = { hp = hp, stun = stun, kb = kb, st = st, hitp = hitp, y = y,
                       vistos = { [st] = true }, n_vistos = 1, nh = nh }
      else
        local marca = nil

        -- 1. CONTACTO: el hitpause pasa a 16 o 28.
        if hitp ~= p.hitp and (hitp == 16 or hitp == 28) then
          marca = marca or {}
          marca[1] = string.format("CONTACTO $69=%d", hitp)
        end

        -- 2. KNOCKBACK CONFIRMADO: la firma de $1F4E2.
        local firma = firma_knockback(stun, kb)
        if firma and p.kb ~= firma then
          print(string.format(
            "[f %d] %s  CONFIRMADO $1F4E2   $7E=%d ->  $84=%d   (abs 7E + 4)*16 = %d   HP=%d",
            frame, nombre(base), p.stun, kb, firma, hp))
        end

        -- 3. $7E cruzó cero. Esto ocurre en el MISMO frame que el knockback si
        --    el golpe agoto el presupuesto, o un frame antes si ya venia
        --    hondo. Solo informativo, el que manda es el punto 2.
        if p.stun >= 0 and stun < 0 then
          marca = marca or {}
          marca[2] = string.format("$7E cruzó 0: %d -> %d", p.stun, stun)
        end

        -- 4. EL ESTADO CAMBIO. Si el backflip tiene estado propio, sale aca.
        --
        --    El backflip es el FIN DEL HITSTUN ESTANDO EN EL AIRE; el knockdown es
        --    el fin del hitstun estando en el suelo. Comparten la rama $7E<0 y se
        --    separan despues, asi que el estado del backflip tiene que ser un
        --    valor de $5F que no aparece en los knockdowns de suelo.
        if st ~= p.st then
          marca = marca or {}
          marca[3] = string.format("ESTADO $5F $%02X -> $%02X", p.st, st)
        end

        -- 5. $84 cambio SIN la firma de $1F4E2: lo escribio otra rutina.
        --
        --    ACA ESTA LA TRAMPA DEL RUIDO, y es la que casi arruina la medicion.
        --    $84 tiene TRES meanings ($1F4E2 velocidad de empujon, $1A28E timer,
        --    $1BCB0 acumulador). Si es el acumulador, se mueve en CADA frame, y
        --    printsarlo 60 veces por segundo hunde la consola de FBNeo, baja el
        --    framerate, y una medicion hecha con el framerate caido no vale.
        --
        --    Dos cortes:
        --      a) solo interesa cuando $84 DEJA el 0. Los pasos intermedios son
        --         ruido; el evento es la salida del 0.
        --      b) y aun asi, con tope de uno cada FRAME_PASEO frames, por si
        --         vuelve a 0 y sale otra vez.
        --
        -- FRAME_PASEO = 30 son 2 lineas por segundo y slot. Con dos slots, 4.
        -- Suficiente para no perder nada, insuficiente para hundir la consola.
        if p.kb == 0 and kb ~= 0 and not firma
           and (p.paseo == nil or frame - p.paseo >= FRAME_PASEO) then
          marca = marca or {}
          marca[4] = string.format(
            "$84 salio de 0 a %d SIN la firma (NO es $1F4E2: timer $1A28E o acumulador $1BCB0)", kb)
          p.paseo = frame
        end

        if marca then
          local partes = {}
          for j = 1, 4 do
            if marca[j] then partes[#partes + 1] = marca[j] end
          end
          print(string.format("[f %d] %s  %s   | $7E=%d $84=%d $5F=$%02X HP=%d Y=%d",
            frame, nombre(base), table.concat(partes, "  ;  "), stun, kb, st, hp, y))
        end

        -- 6. LA HURTBOX SE FUE. Este es el evento que vio el usuario con el HUD de
        --    cajas, y es el que ordena todo lo demas.
        --
        --    Perder la hurtbox es quedarse INVULNERABLE. Y viene DESPUES de un
        --    contacto y, segun la observacion, ANTES del cambio de estado. Asi que
        --    lo que se imprime aca es la marca que hay que mirar para decidir si
        --    la invulnerabilidad provoca el backflip o al reves.
        if nh ~= p.nh then
          if nh == 0 then
            print(string.format(
              "[f %d] %s  *** SE FUE LA HURTBOX (invulnerable) ***  $5F=$%02X  $7E=%d  $84=%d",
              frame, nombre(base), st, stun, kb))
          else
            print(string.format(
              "[f %d] %s  hurtbox de vuelta: %d -> %d  $5F=$%02X",
              frame, nombre(base), p.nh, nh, st))
          end
        end

        prev[base] = { hp = hp, stun = stun, kb = kb, st = st, hitp = hitp, y = y,
                        paseo = p.paseo, vistos = p.vistos, n_vistos = p.n_vistos,
                        nh = nh }

      -- 7. INDICE DE ESTADOS NUEVOS.
      --
      --    Con el guion correcto (un golpe suave a un rival en el aire y esperar)
      --    la consola queda llena de transiciones de $5F, y buscar a mano cuales
      --    son nuevas lleva rato. Esto imprime el indice solo.
      --
      --    Cada estado nuevo se anuncia UNA vez, con el frame. O sea que el
      --    volcado ya viene con una lista de candidatos, y no hay que
      --    reinterpretarlo entero: el backflip va a ser un $XX que solo sale en
      --    el caso de aire.
      --
      --    No imprime nada si no aparecio ningun estado nuevo desde la ultima vez.
      --    Con eso son unas pocas lineas en toda la pelea, no una linea cada dos
      --    segundos.
      if not p.vistos[st] then
        p.vistos[st] = true
        p.n_vistos = (p.n_vistos or 0) + 1
        print(string.format("[f %d] %s  estado NUEVO $5F=$%02X  (van %d, HP=%d $7E=%d $84=%d)",
          frame, nombre(base), st, p.n_vistos, hp, stun, kb))
      end
      end
    end
  end
end)

hito("registerafter registrado. Si aparece 'hook ENTRO', el script funciona.")

print("[yuyu-knockdiag] listo. Este script NO lee el mando: se juega normal, " ..
      "los dos peleadores. Al terminar el round, volca la consola.")
