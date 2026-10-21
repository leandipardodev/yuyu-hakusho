-- ============================================================================
-- ITSUKI SET MOVE.LUA  -  el STOP TIME de Itsuki, mapeado sobre el codigo
-- ============================================================================
--
-- QUE ES
--
-- Itsuki > Ulti > Stop Time. La unica habilidad del juego que pone $69 = 255,
-- y la unica que congela a los ENEMIGOS y a nadie mas.
--
-- Y ADEMAS, para CORROBORAR A OJO que el script lee y detecta la invocacion
-- durante el juego: cuando la ulti salta aparece un cartel gigante en el medio
-- de la pantalla que dice "OK". No dice "STOP TIME" ni nada elegante: es una
-- bandera de papel, y lo que importa es que no se pueda pasar por alto.
--
-- El codigo, verbatim (game_68000.asm):
--
--   01c032:  cmpi.b   #$1, $60(a5)      ; si $60 == 1 -> otra rama, NO es el ult
--   01c03a:  cmpi.b   #$2, $59(a5)      ; el frame de animacion tiene que ser 2
--   01c042:  tst.b    $5b(a5)           ; y el tick tiene que estar en 0
--   01c04a:  adda.l   #$300, a1         ; el objeto vive en slot + $300
--   01c050:  cmpi.w   #$0, $4(a1)
--   01c058:  move.l   #$15094, $0(a1)   ; handler del objeto
--   01c060:  move.w   #$100, $4(a1)     ; vida = 256
--   01c06a:  lea.l    $8400.w, a0       ; y ACA RECORRE LOS 4 SLOTS
--   01c06e:  move.b   $6e(a0), d1       ;   la pertenencia del slot
--   01c072:  cmp.b    $6e(a5), d1       ;   ¿es el mismo grupo?
--   01c076:   beq.b    $1c07e           ;   si -> NO lo congela (aliado)
--   01c078:  move.b   #$ff, $69(a0)     ;   no -> CONGELA, 255
--   01c07e:  cmpa.w   #$9000, a0        ;   el ultimo slot es $9000
--   01c084:  adda.w   #$400, a0         ;   stride $400
--
-- O sea que la firma es TRIPLE y las tres partes se pueden verificar:
--   1. $69 = 255 en los slots enemigos
--   2. $59 == 2 y $5B == 0 en el lanzador
--   3. $6E del congelado DISTINTO al $6E del lanzador
--
-- POR QUE NO USA exec HOOK
--
-- $69 ES UN TIMER, y lo decrementa 0x12B36 (subi.b #$1, $69(a5)) mientras
-- gatea el tick del frame data en 0x12AFC. O sea que el valor SOBREVIVE varios
-- frames y se puede leer en registerafter sin perder nada.
--
-- Esto es a proposito: en ESTA build de FBNeo memory.registerexec no dispara
-- (yuyu_knockdiag.lua quedo con invocaciones=0). Un script que no necesita el
-- hook no puede caer en ese agujero.
--
-- ADEMAS, el ult tiene DOS finales, y el script los distingue:
--   - por CUENTA REGRESIVA: 255 -> 254 -> ... -> 1 -> 0
--   - por IMPACTO: el resolver SOBREESCRIBE el byte (0x1F2E0 pone 16,
--     0x1F2F4 pone 0), y se corta aunque quedara contador
--
-- PASIVO (regla 5)
--
-- Ninguna escritura a la memoria del juego. No hay memory.write* ni joypad.set.
-- Solo lecturas y dibujo.
--
-- COMO SE USA, Y QUE HACE CADA MODO
--
-- El script tiene DOS modos en el mismo archivo, y corren a la vez:
--
-- 1. STOP TIME. Detecta el efecto: si algun $69 vale 255, avisa y saca el
--    cartel de OK. Funciona solo porque 255 no lo pone ninguna otra habilidad.
--
-- 2. RASTREADOR DE TECNICAS. Cada vez que $5F cambia a un id que no habia
--    visto, anuncia la tecnica con sus direcciones. Sirve para las 191 de cada
--    personaje, tenga o no distorsion.
--
-- PARA MAPEAR LAS TECNICAS DE UN PERSONAJE:
--
--   1. Pulsar START. No Y ni Z: esas disparan golpes y arruinan la medicion.
--      Empieza un lote nuevo y borra lo anterior.
--   2. Ejecutar las tecnicas UNA POR UNA, esperando a que cada una termine.
--   3. Pulsar MODE para volcar la tabla con todo lo detectado.
--
-- Cada linea anuncia el id, el frame del anim, la direccion del registro de
-- 8 bytes, sus bytes, la direccion de la tabla B, si ese frame es ACTIVO, y la
-- direccion del registro de dano/stun/empuje con sus tres valores.
--
-- LA LECTURA SE AUTOCOMPRUEBA, Y EL RESULTADO GATEA LA IMPRESION
--
-- El juego copia byte(+0) del registro a $5A en 0x1EB5A. El script compara lo
-- que leyo con lo que esta vivo. **Si no coinciden, NO imprime los datos**: solo
-- avisa y publica la DIRECCION, que sigue valiendo para leerla a mano del .asm.
--
-- MEDIDO el 07-10 con Teleport: byte(+0) = $10 contra $5A = $06, o sea que en
-- esta build el ROM NO esta expuesto bien a Lua. La version anterior imprimia
-- "dano=$0B stun=$87 empuje=$1D" un renglon despues de decir que la lectura no
-- era de fiar: es el peor de los dos mundos, porque el que lee la consola se
-- lleva el numero y no el aviso.
--
-- LO QUE SE SI SE PUEDE AFIRMAR DE LA CORRIDA DEL 07-10
--
--   - Las TRES variantes de Teleport salen con id de $5F = $08, registro
--     $0CFBFA y los 8 bytes IDENTICOS. La zona de destino NO esta en la tabla,
--     asi que las tres se separan por donde caen.
--   - El contexto en uso es $50 = $0CF99A, $8C = $0D069A (contexto 7).
--   - Las tres cuestan 16 de maná, y el gasto se ve en el MISMO frame de la
--     pulsada: el coste se paga al lanzar, no al conectar.
--   - La colocacion cae 39 frames despues de la pulsada (medido en las dos
--     variantes que se movieron).
--
-- ES PASIVO: ni una escritura a la memoria del juego, ni joypad.set.
---- Carga:  Game > Lua Scripting > New Lua Script Window > Browse
-- ============================================================================

local SLOTS = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }

local OFF_FREEZE   = 0x69   -- timer de supresion / congelacion
local OFF_GRUPO    = 0x6E   -- etiqueta de pertenencia (NO "equipo" suelto)
local OFF_FRAME    = 0x59   -- frame de animacion
local OFF_TICK     = 0x5B   -- tick del frame data
local OFF_FLAG     = 0x60   -- si vale 1, el ult toma otra rama
local OFF_ESTADO   = 0x5F   -- id de move
local OFF_DUR      = 0x5A   -- duracion del frame (el juego la copia de la tabla)
local OFF_HP       = 0x78   -- HP, word SIGNED (negativo = muerto)
local OFF_OBJ      = 0x300  -- el objeto del ult vive en slot + $300
local OBJ_LO       = 0x5094  -- mitad baja del handler $15094
local OBJ_HI       = 0x0001  -- mitad alta del handler $15094
local OBJ_VIDA     = 0x0100  -- lo que escribe 0x1C060 (move.w #$100)

local ULT_FRAME    = 2      -- $59 tiene que valer esto (0x1C03A)
local ULT_TICK     = 0      -- $5B tiene que valer esto (0x1C042)
local ULT_FREEZE   = 255    -- lo que escribe 0x1C078
local LATIDO       = 600    -- frames entre avisos de que el script esta vivo

local NOMBRES = { "P1", "P2", "P3", "P4" }

-- bit.* porque el Lua de Fightcade es 5.1: no existen &, |, ~, << ni >>.
local bit = require("bit")

-- ----------------------------------------------------------------------------
-- Lectura
-- ----------------------------------------------------------------------------

local function rb(a) return memory.readbyte(a) end
local function rw(a) return memory.readword(a) end
local function rws(a) return memory.readwordsigned(a) end

-- ----------------------------------------------------------------------------
-- Estado.  Va ANTES de las funciones que lo usan: en Lua un local declarado
-- despues es un global nil en el punto de uso.
-- ----------------------------------------------------------------------------

local g_est         = {}
local g_frame       = 0
local g_ults        = 0
local g_fines       = 0
local g_coher       = 0    -- cuantas veces se violo la regla del $6E
local g_error       = false
local g_error_dicho = false
local g_error_msg   = ""

-- La ultima tecnica confirmada por gasto de maná. La USA announcia_tecnica (que
-- esta mas abajo en el archivo) y la lee detectar_tele (que esta mas abajo aun),
-- asi que va ACA y no junto a ninguna de las dos. En Lua un local declarado
-- despues es un global nil en el punto de uso: no da error de sintaxis, y el
-- fallo aparece en ejecucion, en un punto que no tiene nada que ver.
local g_ultima_tec  = nil

-- HISTORIAL DE $5F
--
-- *** POR QUE HACE FALTA, Y QUE ESTA MEDIDO ***
--
-- El 07-10 las TRES variantes de Teleport salieron con id de $5F = $08. Con los
-- datos del ROM, los ids 6, 7 y 8 del contexto 6 comparten los bytes +2..+5 =
-- `08 94 7C 00` y solo difieren en duracion, multiplicador de tabla B y
-- velocidades: la firma de TRES VARIANTES de una misma tecnica. O sea que hay
-- una hipotesis muy fuerte de que A, B y C sean los ids 6, 7 y 8, y que el
-- script este leyendo el id demasiado temprano.
--
-- El motivo: `detectar_pulsada()` copia el `$5F` del frame DE LA PULSADA. Pero en
-- ese frame el juego todavia no habia arrancado el move, asi que ese `$5F` es el
-- del estado ANTERIOR. La prueba de que es asi la da la autoprueba de la propia
-- tabla: en el anuncio `byte(+0)` daba $10 y el `$5A` vivo era $06, o sea que el
-- juego todavia no habia copiado byte(+0) a $5A. Si el move no habia arrancado,
-- el `$5F` de ese frame tampoco era el nuevo.
--
-- Asi que el id que se anuncia puede ser el viejo, y no hay forma de saberlo sin
-- mirar la SEQUENCIA. Este historial la imprime: es lo que decide si las tres
-- variantes son un id o tres.
local HIST5F = 8    -- frames de historial por slot

local g_hist5f = {}

local function push_hist5f(i)
  local h = g_hist5f[i]
  if not h then h = {}; g_hist5f[i] = h end
  -- Corre hacia atras: el elemento HIST5F es el frame de la pulsada.
  for k = HIST5F, 2, -1 do h[k] = h[k - 1] end
  h[1] = g_est[i].estado
end

-- "$08 $08 $06 $08 ...", del frame de la pulsada hacia atras.
local function texto_hist5f(i)
  local h = g_hist5f[i]
  if not h then return "?" end
  local t = {}
  for k = 1, HIST5F do t[k] = h[k] and string.format("$%02X", h[k]) or "??" end
  return table.concat(t, " ")
end

local function leer_slots()
  for i = 1, #SLOTS do
    local b = SLOTS[i]
    local e = g_est[i]
    e.freeze = rb(b + OFF_FREEZE)
    e.grupo  = rb(b + OFF_GRUPO)
    e.frame  = rb(b + OFF_FRAME)
    e.tick   = rb(b + OFF_TICK)
    e.flag   = rb(b + OFF_FLAG)
    e.estado = rb(b + OFF_ESTADO)
    e.dur    = rb(b + OFF_DUR)
    e.hp     = rws(b + OFF_HP)
    e.vivo   = (e.hp ~= 0)
    push_hist5f(i)
  end
end

-- ----------------------------------------------------------------------------
-- Autocomprobacion: la regla del $6E
--
-- La regla es "congela a los que NO son del mismo grupo". Se puede FALSAR en
-- las dos direcciones, y por eso se comprueba en vez de suponer:
--
--   - un slot con $6E DISTINTO al del lanzador que NO queda congelado -> falla
--   - un slot con $6E IGUAL al lanzador que SI queda congelado        -> falla
--
-- Asi el script sirve como prueba y no solo como lector. Comparar conteos no
-- alcanza: 2 de 2 y 0 de 0 son el mismo numero.
--
-- Solo mira slots VIVOS: uno con HP 0 no esta peleando y no tiene que cumplir.
-- ----------------------------------------------------------------------------

local function regla_6e(lanzador)
  local g = g_est[lanzador].grupo
  local fallas, detalle = 0, {}
  for i = 1, #SLOTS do
    if i ~= lanzador and g_est[i].vivo then
      local mismo = (g_est[i].grupo == g)
      local cong  = (g_est[i].freeze == ULT_FREEZE)
      if mismo and cong then
        fallas = fallas + 1
        detalle[fallas] = NOMBRES[i] .. " esta congelado y es del MISMO grupo: deberia estar libre"
      elseif not mismo and not cong then
        fallas = fallas + 1
        detalle[fallas] = NOMBRES[i] .. " es de OTRO grupo y NO esta congelado: deberia estar congelado"
      end
    end
  end
  return fallas, g, detalle
end

-- El lanzador del ult: el unico con $59 == 2, $5B == 0 y $60 != 1 (0x1C032-42).
local function buscar_lanzador()
  for i = 1, #SLOTS do
    local e = g_est[i]
    if e.vivo and e.frame == ULT_FRAME and e.tick == ULT_TICK and e.flag ~= 1 then
      return i
    end
  end
  return nil
end

-- ¿El objeto del ult ya existe? (0x1C050 lo testea, 0x1C058/60 lo escriben)
local function objeto_vivo(i)
  local b = SLOTS[i] + OFF_OBJ
  return (rw(b) == OBJ_LO) and (rw(b + 2) == OBJ_HI)
end
-- ----------------------------------------------------------------------------
-- MODO RASTREADOR DE TECNICAS
--
-- POR QUE ESTE MODO Y NO EL OTRO
--
-- Arriba el script detecta el EFECTO del stop time: mira si algun $69 vale 255.
-- Eso funciona UNICAMENTE porque 255 no lo pone ninguna otra habilidad. Para
-- mapear el resto no sirve, y el usuario lo intuyo bien: las demas no tienen una
-- distortion con la que reconocerlas.
--
-- Este modo rastrea la TECNICA, y sirve para las 191 de cada personaje:
--
--   loc_011f3e  (empezar el move N)
--   011f3e:  move.b d0, $5f(a5)      ; el ID del move
--   011f42:  clr.b  $59(a5)          ; frame = 0
--   011f4c:  move.b #$ff, $5b(a5)    ; el tick arranca en $FF
--
-- EL CAMINO DE DIRECCIONAMIENTO, verbatim
--
--   loc_01eb40:  (el tick del frame data)
--   01eb40:  clr.w   d0
--   01eb42:  add.b   $5f(a5), d0        ; d0 = id del move
--   01eb46:  add.w   d0, d0             ; d0 = id * 2        (indice de WORDS)
--   01eb48:  movea.l $50(a5), a2        ; a2 = TABLA A
--   01eb4c:  adda.w  (a2, d0.w), a2      ; a2 += word[id]     (offset del move)
--   01eb52:  move.b  $59(a5), d0
--   01eb56:  lsl.w   #$3, d0            ; d0 = frame * 8
--   01eb58:  adda.w  d0, a2             ; a2 += frame * 8
--
--   01ebba:  movea.l $8c(a5), a2        ; a2 = TABLA B
--   01ebb8:  lsl.w   #$2, d3            ; d3 = byte(+1) * 4
--   01ebbe:  move.b  (a2, d3.w), d4     ; d4 = tabB[..]  <- BIT 6 = FRAME ACTIVO
--
-- O sea que hay DOS tablas, y la direccion de una tecnica tiene tres partes:
--
--   reg  = $50 + word[id] + frame*8     registro de 8 bytes
--   tabB = $8C + byte(reg+1) * 4        subregistro de 4 bytes
--   hit  = tabB + word(tabB+1)          daño, stun y empuje
--
-- EL REGISTRO DE 8 BYTES, campo por campo
--
--   +0  -> $5A   duracion del frame
--   +1  -> multiplicador de la TABLA B (por 4)
--   +2  -> $5C   y de ahi sale el facing invertido: eor $61, andi #$3
--   +3  -> atributos; OR con $6D y va a $6C
--   +4  -> indice de sonido, indexa $218D8, y de ahi a $A030
--   +5  -> (lo lee el resolver cuando el frame es activo)
--   +6  -> velocidad X: byte - $80
--   +7  -> velocidad Y: byte - $A0
--
-- EL SUBREGISTRO DE 4 BYTES (TABLA B)
--
--   +0  -> los atributos, y su BIT 6 es lo que marca el frame ACTIVO
--   +1  -> word, y *2 va a $3C
--   +2  -> word, y es el OFFSET al registro de daño/stun/empuje
--   +3  -> (el byte de sonido que lee el resolver)
--
-- OJO: **el byte de daño/stun/empuje NO esta en el registro de 8 bytes**, esta
-- en la TABLA B, y solo se lee si el bit 6 de d4 esta puesto (0x1EC06).
--
-- Y OJO CON `$6C`: no es el byte de atributos puro, es
--   byte(+3) OR $6D   (0x1EB72)
-- asi que para el bit de activo hay que leer la TABLA B, no `$6C`.
--
-- SE PUEDE LEER LA TABLA DESDE EL LUA
--
-- Estas direcciones ($BF75A, $C04CA, ...) son del ROM, no de la RAM espejo.
-- El script NO da por hecho que se puedan leer: intenta, y **se autocomprueba
-- comparando el byte +0 del registro con el `$5A` vivo**, que el propio juego
-- copia de ahi en 0x1EB5A. Si no coinciden, lo dice y publica la DIRECCION igual,
-- que es lo que hace falta para leerla del .asm a mano.
-- ----------------------------------------------------------------------------

local OFF_TABLA_A  = 0x50   -- words -> offset del registro
local OFF_TABLA_B  = 0x8C   -- subregistros de 4 bytes
local OFF_TABLA_90 = 0x90   -- tercera tabla (la escribe el init)
local OFF_HANDLER = 0x1C    -- handler de animacion
local OFF_TABLA_IDX = 0x50  -- alias, para que se lea claro
local OFF_ESTADO_C = 0x5C
local OFF_ATTRS_LOCAL = 0x6C

-- Los comandos van con START y MODE, y no con las de ataque: Y y Z disparan
-- golpes y contaminarian la medicion que estamos haciendo.
local CMD_NUEVO   = { "P1 Start",   "P2 Start"   }
local CMD_VOLCAR  = { "P1 Mode",    "P2 Mode"    }

-- g_mov[slot][id] = { dir=, tabB=, hit=, frames=, activos=, visto= }
local g_mov  = {}
local g_lineas = 0

local function id_de(i) return g_est[i].estado end

-- El registro de 8 bytes de (slot, id, frame), o nil si no se puede leer.
local function leer_registro(dir)
  local r = {}
  for k = 0, 7 do
    local v = memory.readbyte(dir + k)
    if v == nil then return nil end
    r[k] = v
  end
  return r
end

local function tabla_A(i)
  local v = memory.readdword(SLOTS[i] + OFF_TABLA_A)
  if v == nil or v == 0 then return nil end
  return v
end

-- a2 = $50 + word[id] + frame * 8
local function dir_registro(i, id, frame)
  local base = tabla_A(i)
  if not base then return nil end
  local off = memory.readword(base + id * 2)
  if off == nil then return nil end
  return base + off + frame * 8
end

-- tabB = $8C + byte(reg+1) * 4
local function dir_tabB(i, reg)
  local b = memory.readdword(SLOTS[i] + OFF_TABLA_B)
  if b == nil or b == 0 then return nil end
  return b + reg[1] * 4
end

-- El offset al registro de golpe esta en tabB + 2, NO en tabB + 1.
--
--   01ebc4:  move.b  $1(a2, d3.w), d0    ; +1 es un BYTE, y va a $3C con *2
--   01ebce:  adda.w  $2(a2, d3.w), a2     ; +2 es un WORD, y es el OFFSET
--
-- Leerlo en +1 da una direccion distinta de la buena, y el dano/stun/empuje
-- salen de ahi.
local function dir_hit(i, tabB)
  local off = memory.readword(tabB + 2)
  if off == nil then return nil end
  return tabB + off
end

local function hex2(v)
  if v == nil then return "??" end
  return string.format("%02X", v)
end

local function hex6(v)
  if v == nil then return "??????" end
  return string.format("%06X", v)
end

local function act_bito(d4)
  return d4 ~= nil and (bit.band(d4, 0x40) ~= 0)
end

-- Reporta una tecnica nueva. Solo la PRIMERA vez que se ve ese par (slot, id):
-- repetirla actualiza los contadores y no imprime. Asi el jugador puede ir
-- haciendo las suyas una por una sin que la consola se llene de ruido.
local function announcing(i, id)
  local por_slot = g_mov[i]
  if not por_slot then por_slot = {}; g_mov[i] = por_slot end
  local v = por_slot[id]
  if not v then
    v = { dir = nil, tabB = nil, hit = nil, frames = 0, activos = 0,
          leido = false, anunciado = false }
    por_slot[id] = v
  end
  return v
end
-- LA QUE ANUNCIA. Solo la llama confirmar_por_mana(), o sea SOLO cuando se
-- confirmo un gasto. Por eso el texto no dice "quedaste quiet" ni nada: lo que
-- llega aca ya gasto maná.
local function anunciar_tecnica(i, id, frame, cmd, gasto, frame_pulsada)
  local v = announcing(i, id)
  local e = g_est[i]
  v.repetida = (v.repetida or 0) + 1
  v.cmd     = cmd
  v.gasto   = gasto

  local dir = dir_registro(i, id, frame)
  local reg = dir and leer_registro(dir) or nil
  local tB  = reg and dir_tabB(i, reg) or nil
  local d4  = tB and memory.readbyte(tB) or nil

  if d4 ~= nil and act_bito(d4) and frame == 0 then v.activos = v.activos + 1 end

  -- EL CONTEXTO, UNA SOLA VEZ Y AL PRINCIPIO.
  --
  -- Sin esto no se puede confirmar de que tabla salen las direcciones: Itsuki y
  -- Kurama comparten el stun 40 en dos contextos distintos ($50 = $BF75A y
  -- $CF99A), asi que un id puede ser de una tabla y parecer de la otra.
  if not g_primera_vez then
    g_primera_vez = true
    local tA = tabla_A(i)
    local tB2 = memory.readdword(SLOTS[i] + OFF_TABLA_B)
    print(string.format("       CONTEXTO: $50=$%s  $8C=$%s  (estos numeros identifican la tabla)",
          hex6(tA), hex6(tB2)))
    print("       OJO: Itsuki y Kurama comparten el stun 40. Sin este numero no se")
    print("       puede confirmar de que personaje es la tabla.")
  end

  -- SIN GUARDIA DE REPETICION, Y A PROPOSITO.
  --
  -- Antes habia "if v.anunciado then return end", puesto para que machacar el mismo
  -- golpe no llenara la consola. Con la puerta del maná ese guardia NO HACE FALTA
  -- y ADEMAS ESCONDE DATOS.
  --
  -- En la primera prueba real del usuario (Teleport) sezagaron 3 variantes de una
  -- misma tecnica y solo se anotaron 2. La razon: el guardia castea por (slot, id)
  -- y las variantes COMPARTEN el id de $5F. O sea que el guardia estaba tapando
  -- justo la variante que faltaba.
  --
  -- Y el spam es imposible igual: el maná es finito (223, y esta tecnica gasta 16),
  -- asi que no se puede announcementar en cadena. El gate de maná ES el mecanismo
  -- anti-ruido; este segundo guardia solo estorba.
  --
  -- Lo que se mantiene es el CONTADOR de repeticiones, que va al volcado.
  g_lineas = g_lineas + 1
  v.dir = dir
  v.tabB = tB
  v.leido = (reg ~= nil)

  -- La linea resumen va PRIMERO y sola: si solo se copia esta, ya alcanza.
  local resumen = string.format(
        "[MOV %02d] %s  %-4s  id=$%02X (%3d)  mana -%d  registro=$%s",
        g_lineas, NOMBRES[i], cmd, id, id, gasto, hex6(dir))
  print(resumen)

  local n = string.format("       frame=%d (pulsada en el %d)  dur=%s",
        frame, frame_pulsada, reg and hex2(reg[0]) or "??")

  if reg == nil then
    print(n .. "  -> no pude leer la tabla desde Lua")
    print("       NO se pudo calcular la direccion: el puntero en $50 es nil o 0")
    return
  end

  print(n)
  -- *** EL ID QUE SE ANUNCIA PUEDE NO SER EL NUEVO ***
  --
  -- Se imprime el `$5F` que hay AHORA, que es el del frame de la confirmacion, y
  -- la secuencia hacia atras desde el de la pulsada. El 07-10 dio `$08` tres
  -- veces para tres botones, y los ids 6/7/8 del contexto 6 comparten los bytes
  -- +2..+5 de su registro, o sea que son la misma familia. Con esta linea se ve
  -- si A, B y C son un id o tres sin tener que suponerlo.
  -- OJO: %02X quiere un NUMERO. `hex2()` devuelve un string, y con letras
  -- hexadecimales ("0D", "8A") no lo parsea y revienta con
  -- "bad argument #2 to 'format'". Por eso van `e.estado` e `id` crudos, y no
  -- hex2() de ellos. El `secuencia:` si es %s, porque texto_hist5f() ya devuelve
  -- texto.
  print(string.format("       $5F vivo=$%02X (el de la pulsada era $%02X)   secuencia: %s",
        e.estado or 0, id or 0, texto_hist5f(i)))
  print(string.format("       frame de anim $59=%d  dur $5A=%s", e.frame or 0, hex2(e.dur)))
  print(string.format("       bytes: %s %s %s %s %s %s %s %s",
        hex2(reg[0]), hex2(reg[1]), hex2(reg[2]), hex2(reg[3]),
        hex2(reg[4]), hex2(reg[5]), hex2(reg[6]), hex2(reg[7])))
  print(string.format("       mult(tabB)=%s  facing=%s  attr=%s  sonido=%s  velX=%s  velY=%s",
        hex2(reg[1]), hex2(reg[2]), hex2(reg[3]), hex2(reg[4]),
        hex2(reg[6]), hex2(reg[7])))

  -- AUTOCOMPRUEBA: el juego copia byte(+0) a $5A en 0x1EB5A.
  --
  -- De esta comparacion sale TODO lo que se puede afirmar de la tabla. Si no
  -- coinciden, el ROM no esta expuesto bien a Lua y lo que se lee de ahi es
  -- RUIDO: se declara, y no se imprime como dato.
  local leido_de_fiar = (reg[0] == e.dur and e.dur ~= nil)
  if leido_de_fiar then
    print(string.format("       lectura VERIFICADA: byte(+0)=$%s == $5A vivo", hex2(reg[0])))
  else
    print(string.format("       ATENCION: byte(+0)=$%s pero $5A vivo=$%s. La lectura NO es de fiar",
          hex2(reg[0]), e.dur and hex2(e.dur) or "nil"))
    print("       Todo lo que viene de la tabla (bytes, tabB, golpe) es RUIDO. La DIRECCION")
    print("       sigue valiendo para leerla del .asm a mano.")
  end

  -- La ultima tecnica confirmada, para que el detector de teletransporte sepa a
  -- cual atribuirle el salto. Ver la seccion de coordenadas: las variantes que
  -- comparten id de $5F no se separan por la tabla, se separan por donde caen.
  g_ultima_tec = {
    n = string.format("[MOV %02d]", g_lineas), cmd = cmd, frame = frame_pulsada,
  }
  v.ultima_tec = g_ultima_tec

  if tB == nil then
    print("       tabB: no pude leerla")
    return
  end
  print(string.format("       tabB = $%s  byte(+0)=$%s  bit6=%s  offset al golpe = $%s",
        hex6(tB), d4 and hex2(d4) or "??",
        act_bito(d4) and "ACTIVO" or "inactivo",
        hex2(memory.readword(tB + 1))))

  -- El registro de dano/stun/empuje SOLO se lee si el bit 6 esta puesto (0x1EC06).
  --
  -- En la corrida del 07-10 el script imprimia "dano=$0B stun=$87 empuje=$1D" un
  -- frame despues de decir que la lectura no era de fiar. Son numeros inventados
  -- de un lugar que el propio script habia descartado: es el peor de los dos
  -- mundos, porque el que lee la consola se lleva el numero y no el aviso.
  -- Ahora, sin la comprobacion de arriba, NO se imprimen.
  if not leido_de_fiar then
    print("       golpe: no se imprime. Sin la lectura verificada es ruido (bit 6 ademas")
    print("       dice que este frame no es activo, y el registro de golpe no se lee sin el)")
    return
  end

  local hit = dir_hit(i, tB)
  if hit then
    print(string.format("       golpe = $%s   dano=$%s  stun=$%s  empuje=$%s",
          hex6(hit), hex2(memory.readbyte(hit)), hex2(memory.readbyte(hit + 1)),
          hex2(memory.readbyte(hit + 2))))
  end
end
-- ----------------------------------------------------------------------------
-- RECONOCER UNA TECNICA SOLO CUANDO SE GASTA MANA
--
-- La idea del usuario: que el script NO tome cada pulsada por una tecnica, sino
-- SOLO las que consumen maná. O sea, la pulsacion es una SOSPECHA y el gasto de
-- maná es la CONFIRMACION.
--
-- Por que es mejor que announce cada pulsada:
--
--   - standing, caminar, agacharse, recibir un golpe y la mayoria de los
--     estados: NINGUNO gasta maná, asi que dejan de ensuciar la tabla
--   - las basicas A/B/C: tampoco gastan, y quedan como CONTROL NEGATIVO
--   - lo que queda es exactamente lo que se quiere catalogar
--
-- *** EL GASTO SE PAGA AL LANZAR, NO AL CONECTAR ***
--
-- Verificado en el hitbox HUD: "el coste se paga al LANZAR, o sea ANTES de que
-- el primer golpe abra la cadena". Por eso la ventana de espera arranca en la
-- pulsada, no en el impacto.
--
-- *** LO QUE ESTA PUERTA DEJA AFUERA, Y HAY QUE DECIRLO ***
--
-- Las ULTIMATES gastan OTRO recurso, no $B8. O sea que con esta puerta las
-- ultimates NO entran en la lista de [MOV].
--
-- Eso incluye la del stop time, que es la raison d'etre del script. Por eso la
-- deteccion del stop time ($69 = 255, con su cartel de OK) NO pasa por aqui: es
-- un camino aparte, sin puerta, y sigue funcionando.
--
-- Para las OTRAS ultimates habra que nombrarlas a mano por boton, o agregarles
-- una excepcion. No las invento: no se cual es el otro recurso.
--
-- EL AUMENTO NO CUENTA, Y EL RELLENO TAMPOCO
--
-- El maná sube por combo (+2 * n) y por regeneracion con el tiempo, y el
-- relleno de training lo manda a 223 entero de golpe. Ninguna de las tres cosas
-- es una tecnica, asi que SOLO se mira que BAJE.
-- ----------------------------------------------------------------------------

local OFF_MP   = 0xB8       -- maná real. OJO: $BC es la BARRA ANIMADA, no este.
local MP_MAX   = 223        -- tope verificado en 0x1A2E2 ($DF)
local VENTANA_MP = 5        -- frames que se espera ver el gasto antes de tirar la sospecha

local CMD = {
  A = "P1 Button A", B = "P1 Button B", C = "P1 Button C",
  X = "P1 Button X", Y = "P1 Button Y", Z = "P1 Button Z",
  ARRIBA = "P1 Up", ABAJO = "P1 Down", IZQ = "P1 Left", DER = "P1 Right",
}

-- Solo los de ataque. START y MODE son comandos del script, no tecnicas.
local BOTONES = { "A", "B", "C", "X", "Y", "Z" }

local g_pulsado  = {}     -- por boton: true si esta apretado ahora
local g_pend     = nil     -- NIL y no {}: con {} el guardia no corta nunca
local g_mana     = {}     -- maná anterior, por slot
local g_cmd_log  = {}     -- historial de comandos confirmados
local g_primera_vez = false

-- La cruceta COMPLETA en el frame de la pulsada. Una especial necesita
-- direccion, asi que guardar solo el boton pierde la mitad del comando.
local function cruceta()
  local d = ""
  if joypad.get()[CMD.ARRIBA] then d = d .. "^" end
  if joypad.get()[CMD.ABAJO]  then d = d .. "v" end
  if joypad.get()[CMD.IZQ]    then d = d .. "<" end
  if joypad.get()[CMD.DER]    then d = d .. ">" end
  return d
end

-- La sospecha: una pulsada de ataque que aun no se sabe si es tecnica.
local function detectar_pulsada()
  local pad = joypad.get()
  if pad == nil then return end

  for _, b in ipairs(BOTONES) do
    local abajo = pad[CMD[b]] and true or false
    if abajo and not g_pulsado[b] then
      -- Es una pulsada NUEVA (no mantenido). Se guarda con la cruceta del
      -- frame y el maná del momento: eso es contra que se confirme el gasto.
      local mana_actual = (rw(SLOTS[1] + OFF_MP) or 0)   -- "or 0": nil < numero revienta
      g_pend = {
        boton  = b,
        dir    = cruceta(),
        frame  = g_frame,
        mana   = mana_actual,
        id     = g_est[1].estado,
        frame_anim = g_est[1].frame,
      }
    end
    g_pulsado[b] = abajo
  end
end

-- Mira si la sospecha se confirmo por un GASTO de maná.
local function confirmar_por_mana()
  -- El maná se anota SIEMPRE, haya sospecha o no: el latido lo imprime y es el
  -- dato que dice si el gasto llego o no. Antes se anotaba despues del guardia,
  -- asi que sin sospecha el latido mostraba un valor viejo.
  local mana_actual = (rw(SLOTS[1] + OFF_MP) or 0)
  g_est[1].mana = mana_actual
  if not g_pend or g_pend.mana == nil then return end
  if mana_actual < g_pend.mana then
    local gasto = g_pend.mana - mana_actual
    local cmd = g_pend.dir .. g_pend.boton
    g_cmd_log[#g_cmd_log + 1] = {
      cmd = cmd, id = g_pend.id, gasto = gasto, frame = g_pend.frame,
    }
    anunciar_tecnica(1, g_pend.id, g_pend.frame_anim, cmd, gasto, g_pend.frame)
    g_pend = nil
    return
  end

  -- Vencio la ventana sin gasto: era una basica o un estado. No se dice nada.
  if g_frame - g_pend.frame > VENTANA_MP then
    g_pend = nil
  end
end

-- LA QUE LLEVA LA CUENTA de frames por tecnica, para el volcado. No anuncia:
-- el anuncio lo dispara el gasto de mana, no el cambio de $5F.
local function rastrear(i)
  local e = g_est[i]
  if not e.vivo then return end
  local id = e.estado
  if id == nil then return end
  local v = announcing(i, id)
  if e.frame > v.frames then v.frames = e.frame end
end

-- LA ZONA DE DESTINO, Y POR QUE VA EN EL VOLCADO
--
-- Las variantes que comparten id de $5F se acumulan en la MISMA fila, y con el
-- registro de 8 bytes igual no hay nada que las separe. Medido el 07-10 con
-- Teleport A/B/C: los tres con id=$08, registro=$0CFBFA y bytes
-- `10 17 08 94 7C 00 83 7F` IDENTICOS. Lo unico que los distingue es DONDE cae
-- el personaje, y eso lo aporta el detector de teletransporte.
--
-- Por eso la fila lleva la zona: es el dato que separa las tres, y sin el la
-- tabla tiene una sola entrada donde deberia tener tres.
local function zona_de(v)
  local u = v.ultima_tec
  if not (u and u.tele_frame) then return "sin salto atribuido" end
  return string.format("destino X=%d  (salto de %.0f px, %d frames despues de la pulsada)",
        u.tele_x, u.tele_dx, u.tele_frame - u.frame)
end

local function volcar_tabla()
  print("")
  print("=============== TECNICAS CONFIRMADAS POR GASTO DE MANA ===============")
  for i = 1, #SLOTS do
    local por_slot = g_mov[i]
    if por_slot and next(por_slot) then
      local ids = {}
      for id in pairs(por_slot) do ids[#ids + 1] = id end
      table.sort(ids)
      print(string.format("  %s  (%d tecnicas)", NOMBRES[i], #ids))
      for _, id in ipairs(ids) do
        local v = por_slot[id]
        print(string.format("    %-4s id=$%02X (%3d)  mana -%d  registro=$%s  frames hasta %d  repetida %d",
              v.cmd or "?", id, id, v.gasto or 0, hex6(v.dir), v.frames, v.repetida or 1))
        print("         " .. zona_de(v))
        if not v.leido then print("       (de esa tecnica no se pudo leer la tabla)") end
      end
    end
  end
  print("===================================================")
end

local function comandos()
  local pad = joypad.get()
  if pad == nil then return end

  local nuevo = false
  for _, k in ipairs(CMD_NUEVO) do if pad[k] then nuevo = true end end
  if nuevo then
    g_mov, g_lineas = {}, 0
    g_ultima_tec = nil    -- el lote viejo no puede atribuirle saltos al nuevo
    print("[CMD] lote nuevo. Ejecuta las tecnicas una por una y despues pulsa MODE.")
  end

  local volcar = false
  for _, k in ipairs(CMD_VOLCAR) do if pad[k] then volcar = true end end
  if volcar then volcar_tabla() end
end

-- ----------------------------------------------------------------------------
-- EL CARTEL "OK"
-- ----------------------------------------------------------------------------
-- SISTEMA DE COORDENADAS, Y UNA CORRECCION QUE SALIO DE LA MEDICION
--
-- *** LO QUE ESTABA MAL: `CAL_X, CAL_Y = -127, -127` NO VA EN ESTE SCRIPT. ***
--
-- Ese par se presto de `LLUVIA RECTA.LUA` (antes `yuyu_hitbox_hud.lua`), donde
-- esta JUSTIFICADO: el HUD dibuja CAJAS, y la caja tiene otro ancla que el
-- origen del personaje, asi que ahi hace falta una calibracion de 127 px.
-- Aplicado al JUGADOR da un numero 127 px desviado en los DOS ejes, sin avisar.
--
-- MEDIDO en la corrida del 07-10 (Teleport A/B/C):
--
--   mundo X=1025  Y=314     ->  "ahora en pantalla X=53 Y=182"
--   $08/$0C del juego        ->   180 / 309
--
-- 53 + 127 = 180 y 182 + 127 = 309. O sea que el valor impreso era el correcto
-- menos la calibracion del HUD, y el que el juego tiene es el de $08/$0C.
--
-- POR QUE: `loc_0156F0` YA CALCULA la posicion en pantalla y la deja en $08/$0C.
-- No hay que rehacerla. Y rehacerla sin el clamp es peor, porque el clamp es
-- justo lo que uno quiere VER para saber si el personaje se salio de la caja:
--
--   loc_0156f0:  move.w  $40(a5), d0
--   0156f4:      sub.w   $a014.w, d0        ; - base del stage
--   0156f8:      addi.w  #$80, d0
--   0156fc:      add.w   $54(a5), d0        ; + el offset de vaiven de 1 frame
--   015700:      cmpi.w  #$40, d0  /  move.w #$40, d0     ; CLAMP bajo  = 0x40
--   01570a:      cmpi.w  #$1ff, d0 /  move.w #$1ff, d0    ; CLAMP alto  = 0x1FF
--   015714:      move.w  d0, $8(a5)
--   01571c:      move.w  $44(a5), d0
--   015720:      sub.w   $a016.w, d0
--   015724:      add.w   $f566.w, d0        ; + scroll vertical
--   015728:      addi.w  #$20, d0
--   01572c:      add.w   $56(a5), d0
--   015730:      cmpi.w  #$40, d0  /  move.w #$40, d0     ; CLAMP bajo  = 0x40
--   01573a:      cmpi.w  #$1c0, d0 /  move.w #$1c0, d0    ; CLAMP alto  = 0x1C0
--   015744:      subq.w  #$8, d0
--   015746:      move.w  d0, $c(a5)
--
-- El "y luego resta 8" del HUD es ESTE `subq.w #$8` de 0x15744. Es el mismo
-- numero por el mismo motivo, y no una calibracion.
--
-- O sea: `pantalla_de()` devuelve $08/$0C (lo que el juego cree), y
-- `crudo_de()` devuelve la misma cuenta SIN el clamp, para poder ver cuanto se
-- saturationo. Si los dos coinciden, el clamp no esta saturando.
--
-- *** LO IMPORTANTE PARA TELETRANSPORTES ***
--
-- En el hitbox HUD hay una nota que aca sigue siendo crucial, y es la razon de
-- medir el mundo y no la pantalla:
--
--   "$08/$0C son la posicion en pantalla PERO CLAMPADA: loc_0156F0 recorta X a
--    [0x40..0x1FF] e Y a [0x40..0x1C0] y luego resta 8. En cuanto el personaje
--    se sale de esa caja el valor se satura y todo lo anclado a el se queda
--    corrido."
--
-- *** Y OTRA COSA QUE ESTABA MAL: $42/$46 NO SON LA "MITAD ALTA". ***
--
-- Estaban anotadas como la parte alta de la posicion, con la idea de que un
-- teletransporte largo se veria ahi. NO: son la parte FRACCIONAL.
--
-- En la misma corrida, del mismo teletransporte:
--
--   en el aire   Y = 314 / 38400
--   en el piso   Y = 320 /     0
--
-- 38400 = 0x9600 es la FRACCION (38400/65536 = 0,586 px), no otra pagina de
-- coordenadas. Y el cambio de 38400 a 0 no es un salto: el script lo tomaba por
-- uno, y por eso de 7 teletransportes reportados **5 eran falsos** (transiciones
-- normalisimas entre aire y piso de 6 px).
--
-- El formato es 16.16 con la parte ENTERA en la palabra de direccion baja, que
-- es lo que confirma el resto del codigo:
--
--   014aa0:  move.l  $10(a5), d0
--   014aa4:  add.l   d0, $40(a5)      ; velocidad 16.16 sumada a la posicion
--   014aa8:  move.l  $14(a5), d0
--   014aac:  add.l   d0, $44(a5)
--
-- Con `$14 = $FFFC0000` (el empujon de AGENTS.md) eso son -4,0 px, o sea que la
-- cuenta es en px y no en unidades de 1/65536. Y el mismo campo se lee como
-- palabra para el clamp y para el sprite:
--
--   0156f0:  move.w  $40(a5), d0      ; el CLAMP
--   0161c2:  move.w  $40(a5), -$5a00(a1)   ; la tabla de sprites
--
-- Y hay caminos que mueven SOLO la palabra y dejan la fraccion como estaba:
--
--   015034:  add.w   d1, $40(a5)      ; el paso de la tabla de senos
--   015046:  add.w   d1, $44(a5)
--
-- O sea: la fraccion NO se puede usar para detectar un teletransporte. Para eso
-- el delta se calcula sobre el valor 16.16 COMPLETO (ver `detectar_tele`), que
-- si distingue un salto que atraviesa el salto de palabra.
-- ----------------------------------------------------------------------------

local OFF_WX_LO, OFF_WY_LO = 0x40, 0x44      -- parte ENTERA del 16.16, en mundo
local OFF_WX_FR, OFF_WY_FR = 0x42, 0x46      -- parte FRACCIONAL del 16.16
local OFF_SX, OFF_SY       = 0x08, 0x0C      -- pantalla, CON CLAMP (loc_0156F0)
local OFF_VX, OFF_VY       = 0x28, 0x2A      -- velocidad
local STAGE_X, STAGE_Y     = 0xFFA014, 0xFFA016
local SCROLL_Y             = 0xFFF566

-- La posicion en pantalla DEL JUGADOR es $08/$0C: la calcula loc_0156F0 con el
-- clamp puesto. No se recalcula y no se calibra (ver el bloque de arriba).
local function pantalla_de(i)
  local b = SLOTS[i]
  return rws(b + OFF_SX), rws(b + OFF_SY)
end

-- La MISMA cuenta de loc_0156F0 pero SIN el clamp. Sirve para ver cuanto se
-- saturo: si el valor crudo se va de [0x40..0x1FF] (o de [0x40..0x1C0] en Y) y
-- `$08`/`$0C` no, el clamp esta recortando.
--
-- *** EL -8 FINAL CUENTA, Y SU OLVIDO HACIA MENTIR AL AVISO ***
--
-- `loc_0156F0` termina con `subq.w #$8, d0` ANTES de escribir `$0C`. Si el crudo
-- no lo resta, la Y difiere SIEMPRE en 8 y el aviso de clamp disparaba en cada
-- teletransporte aunque no hubiera nada saturado. Se vio en la corrida del 07-10:
--
--     pantalla del juego $08/$0C = 432/316  |  la misma cuenta SIN clamp = 432/324
--     el CLAMP RECORTA: ...
--
-- X coincide exacto (432 = 432) y no habia ningun clamp. Los 8 de diferencia son
-- el `subq.w`, no saturacion.
local function crudo_de(i)
  local b = SLOTS[i]
  local x = rw(b + OFF_WX_LO) - rw(STAGE_X) + 0x80
  -- El -8 del `subq.w #$8` de 0x15744 va ACA: sin el, la Y nunca coincide con
  -- $0C y el aviso de clamp disparaba siempre (ver el comentario de arriba).
  local y = rw(b + OFF_WY_LO) - rw(STAGE_Y) + rws(SCROLL_Y) + 0x20 - 8
  return x, y
end

-- ----------------------------------------------------------------------------
-- TELETRANSPORTE Y SUPER-VELOCIDAD
--
-- La idea: el mundo no se mueve de a pasos. Cada frame se compara con el
-- anterior, y un salto grande en UN solo frame no puede ser velocidad, es un
-- teletransporte.
--
-- EL UMBRAL NO SE INVENTA: se imprime el MAXIMO visto en el latido, para que se
-- pueda ajustar a la vista despues de una pasada. Ponerlo fijo sin medir seria
-- repetir lo de "hasta 4x de daño".
--
-- *** EL DELTA SE CALCULA SOBRE EL 16.16 COMPLETO, Y ESO CAMBIO EL RESULTADO ***
--
-- Antes se restaban solo las palabras de $40 y $44, y se tomaba el cambio de las
-- mitades de fraccion por un salto. Las dos cosas estaban mal:
--
--   - un cambio de $42/$46 es la FRACCION, no un desplazamiento. Tomarlo por un
--     salto es lo que produjo los falsos positivos.
--   - el delta con la palabra entera sola miente cuando el paso ATRAVIESA el
--     salto de palabra.
--
-- En la corrida del 07-10 (Teleport A/B/C) eso dio 7 teletransportes de los
-- cuales **5 eran falsos**: el mismo teletransporte, con Y entre 314/38400
-- (aire) y 320/0 (piso), o sea un cambio de fraccion en un movimiento vertical
-- de 6 px. Los 2 que si eran reales dan +126 y +134 px en X.
--
-- La cuenta correcta:
--
--   dx = (entero_actual - entero_anterior) + (fraccion_actual - fraccion_anterior)/65536
--
-- Asi un paso de 1 px con la fraccion pasando de 60000 a 0 (un wrap, no un
-- salto) da 1 px, y un teletransporte de 126 px con la fraccion intacta da 126.
-- ----------------------------------------------------------------------------

local UMBRAL_TELE = 40      -- px de mundo en un frame. A AJUSTAR con el maximo.
local UMBRAL_VEL  = 6       -- px/frame. A AJUSTAR con el maximo.
local FRACCION    = 65536   -- 16.16: una unidad de la palabra de fraccion es 1/65536 px

local g_pos = {}
local g_max = {}
local g_vmax = {}
local g_teles = {}

local function leer_mundo(i)
  local b = SLOTS[i]
  local e = g_est[i]
  e.wx_lo = rw(b + OFF_WX_LO)
  e.wx_fr = rw(b + OFF_WX_FR)
  e.wy_lo = rw(b + OFF_WY_LO)
  e.wy_fr = rw(b + OFF_WY_FR)
  e.sx    = rws(b + OFF_SX)
  e.sy    = rws(b + OFF_SY)
  e.vx    = rws(b + OFF_VX)
  e.vy    = rws(b + OFF_VY)
end

-- EL CLAMP ESTA RECORTANDO, Y COMO SE COMPRUEBA BIEN
--
-- Comparar crudo con $08/$0C NO funciona, y por dos razones:
--
--   1. `$54` (y `$56`) entran en la cuenta: `add.w $54(a5), d0` en `0x156FC`. Es
--      el offset de vaiven de un frame, y `loc_0156F0` lo **borra en `0x15718`**
--      justo despues de escribir `$08`. O sea que `$54` ya no se puede leer y
--      crudo NO puede reproducir `$08` al pixel. MEDIDO: 176 contra 177, un pixel
--      de diferencia, con el clamp en cero.
--   2. Por eso el aviso de la corrida del 07-10 salia SIEMPRE: cualquier
--      diferencia, inclusive un pixel de vaiven, se leia como saturacion.
--
-- La pregunta correcta no es "difieren" sino **"la posicion cruda se sale de la
-- caja del clamp"**. Los limites estan en `0x15700`-`0x15740`:
--
--   X: crudo a [0x40 .. 0x1FF]         -> $08 queda dentro de eso
--   Y: crudo a [0x40 .. 0x1C0], -8     -> $0C queda en [0x38 .. 0x1B8]
--
-- Asi que la prueba es contra la CAJA, no contra el valor que el juego ya guardo.
local CAJA_X_MIN, CAJA_X_MAX = 0x40, 0x1FF
local CAJA_Y_MIN, CAJA_Y_MAX = 0x38, 0x1B8   -- el -8 de 0x15744 ya aplicado

local function donde_satura(cx, cy)
  if cx < CAJA_X_MIN or cx > CAJA_X_MAX then return "X" end
  if cy < CAJA_Y_MIN or cy > CAJA_Y_MAX then return "Y" end
  return nil
end

local function detectar_tele(i)
  local e = g_est[i]
  local prev = g_pos[i]
  if prev then
    -- Entero Y fraccion. La palabra sola miente cuando el paso atraviesa el
    -- salto de palabra; la fraccion sola miente siempre, porque es subpixel.
    local dx = (e.wx_lo - prev[1]) + (e.wx_fr - prev[3]) / FRACCION
    local dy = (e.wy_lo - prev[2]) + (e.wy_fr - prev[4]) / FRACCION
    e.dx, e.dy = dx, dy
    local adv = math.abs(dx)
    if math.abs(dy) > adv then adv = math.abs(dy) end
    g_max[i] = math.max(g_max[i] or 0, adv)   -- g_max arranca nil: "nil > n" revienta

    if adv > UMBRAL_TELE then
      g_teles[i] = (g_teles[i] or 0) + 1
      local sx, sy = pantalla_de(i)
      local cx, cy = crudo_de(i)
      print(string.format("[TELE %d] frame %d -- %s se movio %.2f,%.2f de golpe (umbral %d)",
            g_teles[i], g_frame, NOMBRES[i], dx, dy, UMBRAL_TELE))
      print(string.format("        mundo  X=%d+%d/65536   Y=%d+%d/65536   (entero+fraccion)",
            e.wx_lo, e.wx_fr, e.wy_lo, e.wy_fr))
      print(string.format("        pantalla del juego $08/$0C = %d/%d   |   la misma cuenta SIN clamp = %d/%d",
            sx, sy, cx, cy))
      local sat = donde_satura(cx, cy)
      if sat then
        print(string.format("        el CLAMP RECORTA en %s: el crudo se sale de [%d..%d], y $08/$0C lo recortaron",
              sat, sat == "X" and CAJA_X_MIN or CAJA_Y_MIN,
              sat == "X" and CAJA_X_MAX or CAJA_Y_MAX))
      end

      -- A QUE TECNICA PERTENECE EL SALTO, y cuanto tardo.
      --
      -- Las tres variantes de Teleport comparten el MISMO id de $5F y el MISMO
      -- registro de 8 bytes (medido el 07-10), asi que la tabla NO las separa:
      -- lo unico que las distingue es DONDE CAEN. Por eso el salto se correlaciona
      -- con la ultima tecnica que la puerta de maná ya confirmó.
      --
      -- No hay ventana inventada: se imprime cuantos frames pasaron, y que el loa
      -- decidir si es mucho o poco.
      local u = g_ultima_tec
      if u then
        print(string.format("        de la tecnica %s (%s), pulsada %d frame(s) antes",
              u.n, u.cmd, g_frame - u.frame))
        u.tele_frame = g_frame
        u.tele_dx    = dx
        u.tele_dy    = dy
        u.tele_x     = e.wx_lo
      else
        print("        sin tecnica confirmada antes: el salto no se atribuye a nadie")
      end
    end

    local v = math.abs(e.vx)
    if math.abs(e.vy) > v then v = math.abs(e.vy) end
    g_vmax[i] = math.max(g_vmax[i] or 0, v)   -- idem, arranca nil
  end
  g_pos[i] = { e.wx_lo, e.wy_lo, e.wx_fr, e.wy_fr }
end

-- ----------------------------------------------------------------------------
-- LOS CAMBIOS DE $5F, Y POR QUE ESTA SEPARADO DEL RASTREADOR
--
-- El rastreador de tecnicas solo imprime cuando el maná BAJA, asi que durante
-- una secuencia sin gastar nada no dice absolutamente nada. Eso impedia
-- responder una pregunta basica del 07-10: **si `$0D` es "el estado de
-- agachado" o "el primer paso del comando abajo-arriba"**. Las dos hipotesis
-- predicen cosas distintas, y con el rastreador solo no se ve ninguna.
--
-- Por eso esto imprime en cada CAMBIO de `$5F`, no en cada frame: es el patron
-- que ya anuncia el arranque ("Solo se avisa de cambios") y el que evita el
-- ruido de 120 lineas por segundo.
--
-- OJO CON EL RUIDO: `$5F` cambia tambien al caminar y al recibir golpes, asi que
-- en una pelea normal esto ensucia la consola. Para una medicion de estados
-- quietos es exactamente lo que se quiere.
--
-- Y para lo mas simple: el HUD ya lo muestra. La linea de cada slot lleva
-- "mov $%02X", que es el `$5F` en vivo. Mirar la pantalla alcanza, esto es solo
-- para tener el registro escrito.
-- ----------------------------------------------------------------------------

local g_5f_ant = {}

local function avisar_cambio_5f(i)
  local e = g_est[i]
  local v = e.estado
  local antes = g_5f_ant[i]
  if antes ~= nil and antes ~= v then
    print(string.format("[$5F] frame %d -- %s: $%02X -> $%02X   (anim $59=%d, dur $5A=%s)",
          g_frame, NOMBRES[i], antes, v, e.frame or 0, hex2(e.dur)))
  end
  g_5f_ant[i] = v
end

-- ----------------------------------------------------------------------------
-- $6E Y LOS HIJOS (proyectiles / entidades invocadas)
--
-- $6E NO es "el equipo": es una ETIQUETA DE PERTENENCIA, y esta verificado que
-- el juego se la COPIA a los hijos:
--
--   move.b $6e(a5), $6e(a1)      en 0x1A46C y 9 sitios mas
--
-- O sea que un proyectil propio lleva el $6E de su dueno. Eso es lo que
-- responde la pregunta de las manos de Itsuki.
--
-- *** LO QUE NO SE VERIFICO, Y HAY QUE DECIRLO ***
--
-- Se sabe que los objetos que crea una tecnica viven en `slot + $300`
-- (0x1C04A: adda.l #$300, a1, con move.l #$15094 en +0 y move.w #$100 en +4).
-- NO se verifico que el struct del hijo tenga la MISMA disposicion que el del
-- jugador, asi que leer su $6E en `$300 + $6E` es una HIPOTESIS.
--
-- El script imprime LAS DOS cosas por separado y no decide:
--   - el handler en $300, que es lo verificado
--   - el byte en $300 + $6E, que es la hipotesis
-- Si aparece un handler nuevo y el byte de $6E coincide con el del dueno, es
-- consistente con que el juego lo trate como hijo. Si NO coincide, tambien es
-- informacion: significa que la etiqueta viaja por otro lado.
--
-- Y el caso NEGATIVO tambien se avisa: si el handler aparece y el byte no
-- cambia, no hay etiqueta ahi.
-- ----------------------------------------------------------------------------

local OFF_OBJ6E = 0x6E       -- $6E dentro del bloque de objeto. HIPOTESIS.
local g_obj = {}

local function detectar_hijos(i)
  local b = SLOTS[i]
  local handler = memory.readdword(b + OFF_OBJ)
  local vida    = rw(b + OFF_OBJ + 4)
  local e6e     = rb(b + OFF_OBJ + OFF_OBJ6E)
  local dueno   = g_est[i].grupo

  local v = g_obj[i]
  if not v then v = {}; g_obj[i] = v end

  -- Sin objeto y sin objeto antes: no se dice nada. Con el guardia viejo
  -- ("v.handler == nil and handler == nil") el 0 de la memoria vacia NO es nil,
  -- asi que cada frame en paz entraba al aviso e imprimia una linea de ruido.
  local vacio = (handler == 0) and (vida == 0)
  if vacio and (v.handler == nil or v.handler == 0) then
    v.handler, v.vida, v.e6e = 0, 0, e6e
    return
  end

  if v.handler == handler and v.vida == vida and v.e6e == e6e then return end

  local dueno_txt = ""
  for k = 1, #SLOTS do
    if g_est[k].grupo == e6e and g_est[k].vivo then
      dueno_txt = " (igual que " .. NOMBRES[k] .. ")"
    end
  end
  print(string.format("[OBJ] frame %d -- %s  $300: handler=$%08X vida=%d  $6E=$%02X%s",
        g_frame, NOMBRES[i], handler, vida, e6e, dueno_txt))
  if handler == 0 then
    print("       el objeto se fue (handler a 0)")
  end
  if dueno_txt ~= "" then
    print("       *** el byte de $6E coincide con el de un jugador: CONSISTENTE ***")
  end
  v.handler, v.vida, v.e6e = handler, vida, e6e
end
--
-- gui.text NO tiene parametro de tamano, asi que "una leyenda grande" hay que
-- dibujarla. Se hace con DOS glifos de 5x7 escalados por un factor, y cada
-- pixel del glifo es un gui.box relleno. Asi el tamano es un numero (ESCALA_OK)
-- y se puede verificar en el autotest contando cajas, en vez de mirar el
-- dibujo a ojo.
--
-- Los colores son 0xRRGGBBAA: byte ALTO = ROJO, byte BAJO = ALFA.
-- ----------------------------------------------------------------------------

local ESCALA_OK = 9        -- px por pixel del glifo. 9 => letra de 45x63
local OK_FRAMES = 75       -- cuanto dura el cartel
local MARGEN_OK = 14       -- padding alrededor del cartel

local GLIFO_O = {
  "01110",
  "10001",
  "10001",
  "10001",
  "10001",
  "10001",
  "01110",
}
local GLIFO_K = {
  "10001",
  "10010",
  "10100",
  "11000",
  "10100",
  "10010",
  "10001",
}

-- OJO CON EL ALFA, QUE YA COSTO UN CARTEL INVISIBLE.
--
--   0xRR GG BB AA
--       byte ALTO = ROJO   (y verde y azul)
--               byte BAJO = ALFA
--
-- Las tres de abajo se escribieron al principio con el byte bajo en 00, que es
-- ALFA CERO: las letras y el borde se dibujaban invisibles y solo se veía el
-- fondo. El comentario decia "opaco" y el valor decia transparente. Con alpha
-- FF abajo: 0xFFFFFF00 -> 0xFFFFFFFF, y 0x00FFFF00 -> 0x00FFFFFF.
local COL_LETRA  = 0xFFFFFFFF   -- blanco, opaco (alfa FF en el byte BAJO)
local COL_FONDO  = 0x000000C8   -- negro al 78 % (alfa C8 en el byte BAJO)
local COL_BORDE  = 0x00FFFFFF   -- cian opaco (alfa FF en el byte BAJO)

-- Contador de glifo: cuantos "1" tiene cada letra. Lo usan el autotest y el
-- comentario de arriba, y evitan que las dos cosas se desincronicen.
-- Un glifo es una TABLA de strings, no un string: cada fila es una cadena de
-- cinco caracteres. Por eso el :sub va sobre la FILA, no sobre el glifo
-- ("attempt to call method 'sub'" si se hace al reves).
local function puntos_de(glifo)
  local n = 0
  for f = 1, #glifo do
    local fila = glifo[f]
    for c = 1, 5 do
      if fila:sub(c, c) == "1" then n = n + 1 end
    end
  end
  return n
end

local PUNTOS_OK = puntos_de(GLIFO_O) + puntos_de(GLIFO_K)   -- 16 + 14 = 30

local g_ok_hasta = 0    -- frame en que el cartel se apaga
local g_ok_desde = 0    -- frame en que se armo

-- Un pixel del glifo, pintado como un cuadro relleno de ESCALA_OK x ESCALA_OK.
local function pixel(gx, gy, gx0, gy0, col)
  local x = gx0 + (gx - 1) * ESCALA_OK
  local y = gy0 + (gy - 1) * ESCALA_OK
  gui.box(x, y, x + ESCALA_OK - 1, y + ESCALA_OK - 1, col, col)
end

local function pintar_glifo(glifo, gx0, gy0, col)
  for f = 1, #glifo do
    local fila = glifo[f]
    for c = 1, 5 do
      if fila:sub(c, c) == "1" then pixel(c, f, gx0, gy0, col) end
    end
  end
end

-- Centrado en la VENTANA, no en el juego: es un cartel de la herramienta y no
-- tiene por que coincidir con la imagen del ROM. Ver la seccion de margenes
-- del AGENTS.md: el overlay dibuja en el espacio de la ventana.
local function dibujar_ok()
  if g_frame > g_ok_hasta then return end

  local ancho_letra = 5 * ESCALA_OK
  local alto_letra  = 7 * ESCALA_OK
  local ancho = ancho_letra * 2 + ESCALA_OK
  local x0 = (emu.screenwidth()  - ancho) / 2
  local y0 = (emu.screenheight() - alto_letra) / 2
  local X, Y = math.floor(x0), math.floor(y0)

  gui.box(X - MARGEN_OK, Y - MARGEN_OK,
          X + ancho + MARGEN_OK, Y + alto_letra + MARGEN_OK,
          COL_FONDO, COL_BORDE)

  pintar_glifo(GLIFO_O, X, Y, COL_LETRA)
  pintar_glifo(GLIFO_K, X + ancho_letra + ESCALA_OK, Y, COL_LETRA)
end

-- ----------------------------------------------------------------------------
-- Dibujo. Va ANTES de paso(), y no por estetica.
--
-- En Lua un local declarado mas abajo es un GLOBAL NIL en el punto de uso: si
-- dibujar_ok() quedara despues de paso(), la llamada compilaria como global y
-- en ejecucion daria "attempt to call global 'dibujar_ok' (a nil value)" al
-- primer frame. No da error de sintaxis, asi que luajit -bl lo pasa limpio.
-- (Es la misma trampa que Altos_por_capa en el HUD.)
--
-- Los colores son 0xRRGGBBAA: byte ALTO = ROJO, byte BAJO = ALFA.
-- ----------------------------------------------------------------------------

local COL_TXT  = 0xFFFF00FF   -- amarillo, estado normal
local COL_COLD = 0x00FFFFFF   -- cian opaco, congelado

local function dibujar()
  local x, y = 8, 8
  for i = 1, #SLOTS do
    local e = g_est[i]
    if e.vivo then
      local txt, col
      if e.freeze == ULT_FREEZE then
        txt = string.format("%s  CONGELADO  $69=%d", NOMBRES[i], e.freeze)
        col = COL_COLD
      else
        txt = string.format("%s  $69=%d  mov $%02X f%d  grupo $%02X  mundo %d,%d  pant %d,%d",
              NOMBRES[i], e.freeze, e.estado, e.frame, e.grupo, e.wx_lo, e.wy_lo, e.sx, e.sy)
        col = COL_TXT
      end
      gui.text(x, y, txt, col)
      y = y + 12
    end
  end
  -- Contador de tecnicas. Es la unica linea que no es por slot.
  gui.text(x, y, string.format("tecnicas nuevas: %d", g_lineas), COL_TXT)
  y = y + 12
  dibujar_ok()
end

-- ----------------------------------------------------------------------------
-- Cuerpo del frame
--
-- LA MAQUINA DE ESTADOS NO PUEDE PREGUNTAR "¿$69 == 255?": durante la cuenta
-- regresiva $69 vale 254, 253, ... asi que esa pregunta es cierta UN solo frame
-- y el ult pareceria durar 1 frame. La firma de 255 marca el ARRANQUE, y despues
-- hay que seguir la SECUENCIA.
--
--   arranca:  $69 pasa a 255
--   sigue:    $69 baja de a uno (0x12B36, subi.b #$1)
--   corta por cuenta regresiva:  llega a 0 viniendo de 1
--   corta por impacto:           cualquier otra cosa, porque el resolver
--                                SOBREESCRIBE el byte (0x1F2E0 = 16, 0x1F2F4 = 0)
--
-- El corte a 0 es ambiguo si el contador iba a medias, y se reporta como tal:
-- si venia de 1 fue la cuenta, si no fue un impacto antes de tiempo.
-- ----------------------------------------------------------------------------

local function paso()
  g_frame = g_frame + 1
  leer_slots()

  local arranco_n, arranco = 0, {}

  for i = 1, #SLOTS do
    local e = g_est[i]
    local v = e.freeze

    if not e.en_ult then
      if v == ULT_FREEZE then
        arranco_n = arranco_n + 1
        arranco[arranco_n] = i
        e.en_ult   = true
        e.frames   = 1
        e.ult_prev = v
      end
    else
      if v == 0 then
        local por = "cuenta regresiva completa (255 frames exactos)"
        if e.ult_prev ~= 1 then
          por = string.format("IMPACTO: sobrescrito a 0 cuando iba por %d", e.ult_prev)
        end
        g_fines = g_fines + 1
        print(string.format("[FIN %d] frame %d -- %s salio del ult tras %d frame(s), por %s",
              g_fines, g_frame, NOMBRES[i], e.frames, por))
        e.en_ult = false
        e.frames = 0
      elseif v == e.ult_prev - 1 then
        e.frames   = e.frames + 1
        e.ult_prev = v
      else
        g_fines = g_fines + 1
        print(string.format("[FIN %d] frame %d -- %s salio del ult tras %d frame(s), por IMPACTO ($69: %d -> %d, y no era %d)",
              g_fines, g_frame, NOMBRES[i], e.frames, e.ult_prev, v, e.ult_prev - 1))
        e.en_ult = false
        e.frames = 0
      end
    end
  end

  if arranco_n > 0 then
    g_ults = g_ults + 1
    local lz = buscar_lanzador()
    -- El cartel. Se arma en el frame del arranque, que es el unico momento en
    -- que se sabe que la invocacion fue detectada.
    --
    -- El -1 importa: la condicion de dibujado es "g_frame > g_ok_hasta", o sea
    -- que el cartel sale tambien en el frame DEL ARRANQUE. Sin el -1 duraba
    -- OK_FRAMES + 1 frames. Con el, dura exactamente OK_FRAMES.
    g_ok_hasta = g_frame + OK_FRAMES - 1
    g_ok_desde = g_frame
    print(string.format("[ULT %d] frame %d -- $69=255 en %d slot(s)",
          g_ults, g_frame, arranco_n))
    print(string.format("       lanzador: %s", lz and NOMBRES[lz] or "NO ENCONTRADO"))
    print(string.format("       CARTEL OK en pantalla hasta el frame %d", g_ok_hasta))

    if lz then
      local e = g_est[lz]
      -- OJO: `$59=%d (debe ser %d)` son DOS especificadores, no uno. Esta linea
      -- tiene 5 pares mas el %s = 7, y por 6 argumentos reventaba con
      -- "bad argument #7 to 'format'". Contarlos, no estimarlos a ojo.
      print(string.format("       firma: $59=%d (debe ser %d)  $5B=%d (debe ser %d)  $60=%d (debe ser %d)  objeto=%s",
            e.frame, ULT_FRAME, e.tick, ULT_TICK, e.flag, 1,
            objeto_vivo(lz) and "si" or "NO"))
      for k = 1, arranco_n do
        local c = g_est[arranco[k]]
        print(string.format("       %s congelado: $6E=$%02X (lanzador $%02X, distintas=%s)  HP=%d",
              NOMBRES[arranco[k]], c.grupo, e.grupo,
              (c.grupo ~= e.grupo) and "si" or "NO", c.hp))
      end
      local fallas, g, detalle = regla_6e(lz)
      if fallas == 0 then
        print(string.format("       REGLA $6E: se cumple. grupo del lanzador $%02X", g))
      else
        g_coher = g_coher + 1
        for k = 1, fallas do
          print("       REGLA $6E: FALLA -- " .. detalle[k])
        end
      end
    end
  end

  -- El rastreador de TECNICAS. Va antes del dibujo porque el dibujo usa $69 y
  -- el rastreador usa $5F: son independientes, pero el orden queda fijo.
  comandos()
  detectar_pulsada()
  confirmar_por_mana()
  for i = 1, #SLOTS do
    leer_mundo(i)
    detectar_tele(i)
    detectar_hijos(i)
    rastrear(i)
    avisar_cambio_5f(i)
  end

  dibujar()

  -- EL LATIDO, Y LOS TRES PRINT DE ADENTRO VAN JUNTOS.
  --
  -- *** ESTO ESTABA FUERA DEL `if` Y SABA 2 LINEAS POR FRAME. ***
  --
  -- Las dos ultimas lineas del bloque (max salto / maná) se imprimian en CADA
  -- frame, o sea 120 lineas por segundo a 60 Hz. En la corrida del 07-10 eso
  -- lleno la consola de mas de mil lineas y, peor, baja el framerate: y una
  -- medicion con el framerate caido no sirve (la regla de AGENTS.md).
  --
  -- Se ve en el sintoma: el "aumento de maná" que se leia era de +1 cada DOS
  -- lineas, cuando en realidad era de +1 cada frame.
  --
  -- Ojo con la indentacion: en Lua lo que manda es el `end`, no las columnas. Por
  -- eso estas tres lineas arrancan DENTRO del `if` y no despues.
  if g_frame % LATIDO == 0 then
    print(string.format("[latido] frame %d -- ults=%d fines=%d regla-$6E-violada=%d",
          g_frame, g_ults, g_fines, g_coher))
    local mx, mv, nt = 0, 0, 0
    for i = 1, #SLOTS do
      if g_max[i] and g_max[i] > mx then mx = g_max[i] end
      if g_vmax[i] and g_vmax[i] > mv then mv = g_vmax[i] end
      if g_teles[i] then nt = nt + g_teles[i] end
    end
    print(string.format("        max salto=%.2f px (umbral %d)   max vel=%d (umbral %d)   teletransportes=%d",
          mx, UMBRAL_TELE, mv, UMBRAL_VEL, nt))
    -- DIAGNOSTICO DE LA PUERTA DE MANA: el maná de P1 y si hay una sospecha viva.
    -- Si aparece "SI: vA" y no salió ningun [MOV], el gasto NO llego dentro de la
    -- ventana: eso dice que hay que agrandarla, y no que el guardia tape nada.
    print(string.format("        maná P1 = %s (tope %d)   sospecha: %s",
          g_est[1].mana and tostring(g_est[1].mana) or "?", MP_MAX,
          g_pend and ("SI: " .. g_pend.dir .. g_pend.boton) or "ninguna"))
  end
end


-- ----------------------------------------------------------------------------
-- Latido y error.
--
-- Una excepcion dentro de un callback SE TRAGA en este emulador: deja el flag
-- de captura en false, el callback sale por su rama de "no tengo datos", y el
-- script queda mudo sin una sola palabra. Por eso el pcall y el flag propio:
-- `if g_ults == 2` no serviria, porque un error que arranca en el frame 3000
-- no lo diria nunca.
-- ----------------------------------------------------------------------------

local function marco()
  if g_error then
    if not g_error_dicho then
      print("[ERROR] el callback lanzo una excepcion y se detiene: " .. tostring(g_error_msg))
      g_error_dicho = true
    end
    return
  end
  local okc, err = pcall(paso)
  if not okc then
    g_error     = true
    g_error_msg = err
  end
end

for i = 1, #SLOTS do
  g_est[i] = { en_ult = false, frames = 0, ult_prev = 0, vivo = false }
end

emu.registerafter(marco)

print("ITSUKI SET MOVE.LUA: leyendo $69 y $5F de los 4 slots. Solo se avisa de cambios.")
print("  STOP TIME: $69=255 + $59=2 + $5B=0 + $6E distinto al del lanzador")
print("  sin exec hook a proposito: $69 es un timer y se lee en registerafter")
print(string.format("  al detectar la ulti sale un cartel de %dx%d que dice OK, %d frames",
      5 * ESCALA_OK, 7 * ESCALA_OK, OK_FRAMES))
print("  RASTREADOR DE TECNICAS: anuncia SOLO las que GASTAN mana, con la")
print("    direccion de su registro: $50 + word[id] + frame*8, y despues la tabla B en $8C")
print("    el salto se correlaciona con la ultima tecnica, y el volcado lleva la zona")
print("    START = lote nuevo.  MODE = volcar la tabla de todo lo detectado.")
print("  el teletransporte se mide sobre $40/$44 (los enteros); $42/$46 son la fraccion")
print("  CAMBIOS DE $5F: cada vez que $5F cambia de valor sale una linea [$5F],")
print("    aunque no se gaste maná. Sirve para ver cuanto dura un estado.")
print("    OJO: caminar y recibir golpes tambien cambian $5F, asi que en una pelea")
print("    normal esto hace ruido. El HUD ya lo muestra en 'mov $XX'.")

-- Bloque de SOLO LECTURA para el autotest. No dibuja, no lee ni escribe la
-- memoria del juego, y en el emulador no se crea nunca: el test lo pide
-- poniendo _G.__yuyu_test ANTES del dofile.
if _G.__yuyu_test then
  _G.__yuyu_test.pasos   = function() return paso() end
  _G.__yuyu_test.estado  = function() return g_est end
  _G.__yuyu_test.regla_6e = function(i) return regla_6e(i) end
  _G.__yuyu_test.slots   = SLOTS
  _G.__yuyu_test.offsets = {
    freeze = OFF_FREEZE, grupo = OFF_GRUPO, frame = OFF_FRAME,
    tick = OFF_TICK, flag = OFF_FLAG, estado = OFF_ESTADO, hp = OFF_HP,
  }
  _G.__yuyu_test.consts = {
    ult_frame = ULT_FRAME, ult_tick = ULT_TICK, ult_freeze = ULT_FREEZE,
  }
  _G.__yuyu_test.ok = {
    puntos    = function() return PUNTOS_OK end,
    escala    = function() return ESCALA_OK end,
    frames    = function() return OK_FRAMES end,
    hasta     = function() return g_ok_hasta end,
    desde     = function() return g_ok_desde end,
    margen    = function() return MARGEN_OK end,
    glifo_o   = function() return GLIFO_O end,
    glifo_k   = function() return GLIFO_K end,
    puntos_de = puntos_de,
  }
  _G.__yuyu_test.coord = {
    pantalla     = pantalla_de,
    crudo        = crudo_de,
    fraccion     = function() return FRACCION end,
    donde_satura = donde_satura,
    mundo        = function(i) return g_est[i].wx_lo, g_est[i].wy_lo end,
    mundo_frac   = function(i) return g_est[i].wx_fr, g_est[i].wy_fr end,
    max_salto    = function(i) return g_max[i] or 0 end,
    max_vel      = function(i) return g_vmax[i] or 0 end,
    teles        = function(i) return g_teles[i] or 0 end,
    leer_mundo   = leer_mundo,
    detecta_tele = detectar_tele,
    detectar_hijos = detectar_hijos,
    ultima_tec   = function() return g_ultima_tec end,
    hist5f     = texto_hist5f,
    cambio_5f  = avisar_cambio_5f,
    latido     = function() return LATIDO end,
    -- Solo para el banco: pone una "ultima tecnica" sin pasar por la puerta de
    -- maná. La via real se prueba con pulsar() + gasto, mas abajo en el test.
    fingir_tec = function(cmd, frame)
      g_ultima_tec = { n = "[MOV 99]", cmd = cmd or "A", frame = frame or g_frame }
    end,
    reset = function()
      g_pos, g_max, g_vmax, g_teles, g_obj = {}, {}, {}, {}, {}
      g_ultima_tec = nil
      g_hist5f = {}
      -- Tambien el "anterior" del avisador de $5F. En el juego esto arranca nil
      -- solo al cargar el script, y por eso el primer frame no dice nada; si el
      -- reset no lo limpiara, el test no podria comprobar esa parte.
      g_5f_ant = {}
    end,
    pulsada    = detectar_pulsada,
    confirmar  = confirmar_por_mana,
    pendiente  = function() return g_pend end,
    cmd_log    = function() return g_cmd_log end,
    primera_vez= function() return g_primera_vez end,
    mp_max     = function() return MP_MAX end,
    ventana    = function() return VENTANA_MP end,
    off_mp     = function() return OFF_MP end,
    umbral_tele  = function() return UMBRAL_TELE end,
    umbral_vel   = function() return UMBRAL_VEL end,
    offsets = {
      wx = OFF_WX_LO, wy = OFF_WY_LO, sx = OFF_SX, sy = OFF_SY,
      wx_fr = OFF_WX_FR, wy_fr = OFF_WY_FR,
      vx = OFF_VX, vy = OFF_VY, obj6e = OFF_OBJ6E,
      stage_x = STAGE_X, stage_y = STAGE_Y, scroll_y = SCROLL_Y,
    },
  }
  _G.__yuyu_test.mana = {
    off_mp = function() return OFF_MP end,
    mp_max = function() return MP_MAX end,
    ventana= function() return VENTANA_MP end,
    pulsada= detectar_pulsada,
    confirmar = confirmar_por_mana,
    pendiente = function() return g_pend end,
    cmd_log = function() return g_cmd_log end,
    primera_vez = function() return g_primera_vez end,
    cmd_a = "P1 Button A",
    cmd_b = "P1 Button B",
  }  _G.__yuyu_test.mov = {
    dir_registro = dir_registro,
    dir_tabB     = dir_tabB,
    dir_hit      = dir_hit,
    leer_registro = leer_registro,
    tabla_A      = tabla_A,
    tabla        = function() return g_mov end,
    lineas       = function() return g_lineas end,
    volcar       = volcar_tabla,
    nuevo_lote   = function() g_mov, g_lineas = {}, 0 end,
    act_bito     = act_bito,
    offsets = {
      tabla_a = OFF_TABLA_A, tabla_b = OFF_TABLA_B, tabla_90 = OFF_TABLA_90,
      handler = OFF_HANDLER, dur = OFF_DUR, estado_c = OFF_ESTADO_C,
      attrs_local = OFF_ATTRS_LOCAL,
    },
  }
end
