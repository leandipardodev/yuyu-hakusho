# Objetos y efectos: el motor de partículas

**(2026-10-22)** Primera radiografía completa del sistema de efectos. Regla de
lectura: **[VERIF]** = verificado con las herramientas de este repo (capstone
sobre los bytes de `rom/base/yuyu_makyou_base.bin` o lectura del
desensamblado); **[AGENTE]** = traido por la exploración con capstone de
sesión, **aún sin revisión propia**: creíble pero tomar con pinzas hasta verlo.

Responde: ¿se pueden agregar efectos y dispararlos donde uno quiera?
Corto: **duplicar/disparar efectos existentes en cualquier punto, SÍ y es
barato. Efectos totalmente nuevos, SÍ, con tres piezas y dos datos por cerrar.**

## 1. Todo es el mismo motor de objetos

El juego no tiene un sistema de partículas separado: **jugadores, chispas de
golpe, polvo, ondas, proyectiles y el flash del contador de combo son los
mismos "objetos"** en una sola cadena [VERIF el mecanismo, [AGENTE] los
periféricos]:

- El dispatcher `$3592` [AGENTE] recorre la RAM de objetos de `$FF8000` a
  `$FFA000` una vez por frame, hace `jsr` al puntero del longword 0 de cada
  record y avanza exactamente lo que dice `$4(a5)` (el tamaño del record).
- La "firma" `$00012668` del jugador es **simplemente el puntero a su
  handler**; los objetos del pool tienen los suyos. Nada de magia.
- Matar un objeto = `jmp $3556` [VERIF en `0149a6`]: pone `$0`=0 y limpia el
  record, con lo que el slot vuelve a quedar libre.

## 2. El pool y el spawn [VERIF]

El allocator `0x1FAB4` ([asm], capstone):

```
01fab4:  move.b #$10, d1           ; 16 intentos
         loop: subq/tst/beq $1fae8  ; pool lleno -> a0=0, rts (spawn falla)
01fabe:  addi.w #$80, $a036.w      ; cursor SIEMPRE avanza (haya slot o no)
01fac4:  andi.w #$7ff, $a036.w
01faca:  movea.w $a036.w, a0       ; SIGN-EXTIENDE (0..$7FF)
01face:  adda.w #$9400, a0         ; word inmediato SIGN-EXTIENE:
                                   ; $9400 = -$6C00 -> base $FF9400 + cursor
01fad2:  tst.w $4(a0); bne loop    ; $4==0 = slot libre
01fad8:  move.l d0, $0(a0)         ; longword 0 = puntero al handler
01fadc:  move.w #$80, $4(a0)       ; y el tamaño
01fae2:  clr.w $6(a0)              ; tick en 0 -> el handler entra en modo init
```

- **16 slots de `$80` bytes.**
- **BASE DEL POOL: `$FF9400` — CERRADA el 2026-10-22 con la sonda
  `sonda_efectos.lua` en juego** (spawns reales en `$FF9400 + i*$80`, las 16
  casillas suman 16). Y la aritmética igual cierra, el apunte anterior
  ("da `$009400`") olvidaba extender el inmediato: el `adda.w #$9400`
  **sign- extiende el word inmediato** (`$9400` signed-16 = `-$6C00`), o sea
  `cursor ($000-$7FF) + $FFFF9400 = $FF9400 + cursor`, exacto lo que la
  sonda midio. Del desensamblado literal al pool real no hay rara.
- Los cuatro **wrappers de spawn** [VERIF] solo cargan el handler en `d0` y
  caen en `$1FAB4`:

| wrapper | handler | que es |
|---|---|---|
| `$1FA96` | `$149AC` | el grande: proyectiles, ondas, chispas (tipos `$00-$24`) |
| `$1FA9E` | `$13E9A` | **NO esta muerto** (correccion de la sonda: abajo §4.1) |
| `$1FAA6` | `$14EC6` | polvo/humo |
| `$1FAAE` | `$14930` | flash del contador de combo (se mata solo: `$48` contador a 32) |

## 3. El ID del efecto es el byte `$58` [VERIF]

El handler grande `$149AC` despacha así (capstone sobre la ROM base):

```
0149f0:  moveq #$0, d0
0149f2:  move.b $58(a5), d0
0149f6:  e348           lsl.w #$1, d0
0149f8:  41fb0006       lea.l $14a00(pc, d0.w), a0
0149fc:  d0d0           adda.w (a0), a0
0149fe:  4ed0           jmp (a0)
```

- **Tabla de despacho en ROM `$14A00`, entradas de 2 bytes (offsets relativos).**
  Extensión exacta: `$14A00-$14A49` — lo confirma el propio handler, cuyo
  `bne.w $14A4A` de su init retoma el código donde termina la tabla: **37
  entradas, ID máximo `$24`** [VERIF].
- Los campos del slot que la init llena: `$1C` (tabla maestra de frames),
  `$24` (id gráfico + paleta bits), `$28/$2A` (velocidades), `$3C`
  (índice de frame), `$3E` (escala), `$40/$44` (posición), `$50` (tabla
  pares `[índice,duración]`), `$58` (tipo), `$59/$5B/$5C` (anim), `$48`
  (scratch/contador).
- Los valores de la tabla (qué ID → qué rama, tablas de anim
  `$14D6C-$14E88+`, ORIs de tiles `#$20/#$40/#$C0/#$150/#$1A6/...`) son
  **[AGENTE]**: batch de datos decodificados que falta re-verificar byte a
  byte. Lo que sí está [VERIF]: la tabla existe, ahí está, y su byte máximo.

## 4. Dónde se disparan los efectos conocidos [AGENTE, por revisar]

| efecto | disparador | ID `$58` |
|---|---|---|
| chispas de golpe (9 variantes) | bloque `$1F7D6-$1F94C` del resolver `$1F524` (por `$68(a3)`) | `$00-$08` |
| clash | `$1F970` (suena `$77` via `$A030`) | `$C` / `$12` |
| flash del combo | `$01FA26` | — |
| polvo al aterrizar | `$15FF8` / `$16026` (con `jsr $1FB4C`, contexto de jugador) | `$10` |
| polvo al caminar | `$1CA5E`/`$1CAB4`/`$1CBDC`/`$1CC36` | — |
| polvo al saltar | `$012B16` | — |
| efectos de especiales (proyectiles, ondas, humo) | librería `$1FD82-$020664`, **posición en `d5/d6`** | `$14-$24` |

Detalle [AGENTE]: las chispas de golpe **usan los tiles del atacante**
(copian `$24` del dueño, la base la rota una palabra global `$A031` de 16 en
16), y la tabla maestra de frames de los efectos `$10-$24` es `$27F618`.

## 4.1 La sonda en juego (2026-10-22, corrida del usuario) [VERIF]

Lo que `sonda_efectos.lua` vio en una pelea (el log completo esta en la
sesion del dia):

- **BASE CONFIRMADA**: todos los spawns y muertes caen en
  `$FF9400 + i*$80`, el cursor `$A036` coincide slot por slot.
- **IDs vistos en juego real**:

| familia | handler | IDs | lo que hace el log | |
|---|---|---|---|---|
| ráfagas de 3 con X progresivo (+$10 por cogida), vida `$20`-$30 frames | `$149AC` | `$20` | pos Y fija `$0140` | fija |
| sueltas | `$149AC` | `$02`, `$19`, `$1D`, `$15` | pos varias, Y `$0102-$0115` | |
| fila simple (caminar/saltar) | `$149AC` | `$10` | Y `$0140`/`$0141` | |
| ráfagas de 7 | `$13E9A` | `$00` | pos igual en las 7, tabla **`$0D8F1A`** | fija |

- **CORRECCION al "wrapper muerto"**: el handler `$13E9A` spawnea de verdad
  (la sonda lo vio dos veces). El apunte "no tiene llamador" refería al
  wrapper `$1FA9E`: el llamador existe en otra parte o el handler entra
  por otro camino — a buscar.
- una corrada muestra `ID=$02` con **tabla `$000000`**: la sonda leyó el
  slot en el MISMO frame del spawn, antes de que la init la llenara: eso
  verifica que la tabla se llena DESPUES del spawn (no un bug del juego).
- casi siempre hay **6-8 slots en uso a la vez** — el cursor avanza como
  el pool dice y no se ve `pool lleno` en pelea normal: hay razonable para
  aumentar Ammo sin dropout, TODAVIA hay.

### 4.2. La tesis DEMOSTRADA en juego (sonda v4, 2026-10-22) [VERIF]

**"Un efecto donde yo quiera" = clonar un record real y mover `$40/$44`.**
El modo `aura` de `sonda_efectos.lua` funciona: cuando el usuario esta en
veneno (parado en el plano de atras), la sonda agarra un ID=$1D vivo del
pool, clona el record entero a un slot libre y le pone la posicion del
jugador — **y el efecto aparece acompanando al pj**.

La leccion ARDUO de la v3 (pantalla negra): **los campos del record del
JUGADOR NO son los del OBJETO**, aunque ambos entren en el dispatcher.
Copie `$24/$26/$3E` desde el player creyendo que eran tile/plano/escala y
el objeto dibujo basura sobre toda la pantalla. Regla: al construir un
record de objeto, SOLO se llenan campos con datos de un record de objeto
(exactamente lo que hace la v4: nada sintetico, clon de lo que el juego
dejo vivito).

Para el parche v9 del ROM quedan dos caminos: (a) encontrar el wrapper de
la libreria de especiales que spawnea el ID deseado con d5/d6 y llamarlo
con la posicion del pj (el camino limpio), o (b) clonar-on-RAM como la
sonda (necesita guardar la ultima instancia real, mas intrusivo).

## 5. Límites duros [VERIF]


1. **16 slots** — y el cursor `$A036` avanza SIEMPRE: si se spawnea más rápido
   de lo que el juego mata objetos, el pedido devuelve `a0=0` y el spawn no
   pasa nada. La forma de no fallar es chequear `cmpa #$0, a0; beq`.
2. **80 piezas de sprite por frame**: `00169a: cmpi.w #$50, d0`
   [VERIF]. La máquina del SAT salva/restaura `$F578` (índice) y `$F57C`
   (puntero) por pase [VERIF en `$00125a-$001342`]. Si un frame pasa de 80
   se prende `$F54F` y **el resto del frame deja de dibujar** — los efectos
   compiten con los jugadores por ese cupo y pierden.
3. La escala hereda del dueño (`$3E`), el dibujado va por la tabla de
   `$1C`/`$50` del slot. No hay alocador de VRAM por efecto, salvo el cursor
   dinámico `$A038` de los especiales [AGENTE].
4. **Espacio libre en el ROM base: `$1A06AE-$1A0826`, 377 bytes** de puros
   ceros [VERIF por bytes]. Ahí ya vive el payload del veneno (aunfue el
   gap de `$1A06F0`); sobran aún para el trigger + tablas de anim chicas.

## 6. Factibilidad

### (a) Disparar un efecto EXISTENTE donde uno quiera — SÍ [mecanismo VERIF]

Patrón (a escribir en el hueco de `$1A06AE+`, validando con capstone):

```
jsr  $1FA96              ; pedir slot (o el wrapper que toque)
cmpa #$0, a0; beq fuera  ; pool lleno: salir sin romper nada
move.b #$NN, $58(a0)     ; el tipo de efecto
move.w X, $40(a0)        ; posicion que yo quiero
move.w Y, $44(a0)
...                      ; tabla/velocidad/paleta si hace falta
```

Las coordenadas custom ya son el patrón de la librería de especiales
(`d5/d6`), [AGENTE].

### (b) Agregar un efecto NUEVO — SÍ, con tres piezas

1. una rama propia en la tabla `$14A00` (hay IDs alias compartidos por
   redirigir [AGENTE], o extender la tabla — pero la tabla ya termina
   donde retoma el código del handler: una entrada extra hay que colarla
   recolocando algo);
2. tabla-anim nueva (los `[índice,duración]` en `$50`) + tabla maestra de
   frames (la referencia con `move.l #tabla, $1C(a5)`) — datos que pueden
   vivir en el hueco de `$1A06AE+`;
3. tiles: reusar los ya en VRAM con el ORI sobre `$24` (el patrón de todos),
   o el cursor dinámico `$A038` si hay que subir tiles nuevos [AGENTE].

## 7. Pendientes (en orden)

1. ~~cerrar la base real del pool~~ **HECHO (sonda 2026-10-22): `$FF9400`,
   cerrado por sonda y por la geometría del `adda.w` sign-extenido**;
2. re-verificar los valores de la tabla `$14A00` (línea por línea de ramas);
3. re-verificar los bloques de disparo del agente (chispas/clash/polvo) —
   bajas en costo, son greps cortos (la sonda ya corroboró la forma
   general de los IDs `$10`/`$20`/`$13E9A` en juego);
4. ~~primera prueba de spawn custom en juego: la sonda ya trae el modo
   `clonar`~~ **HECHO Y PASADO A ROM: la v9 del veneno clona el efecto `$20`**
   (ver `05-PARCHES/PARCHES.md`, `EL AURA DEL VENENO`).

## 8. El spawn del trail `$20` visto en el código [VERIF]

**La familia de wrappers del trail, en `$020190-$020360`** (region con el
mapper=0 leída directa): cinco variantes que comparten la misma forma:

```asm
$020202  bsr.w  $1fa96             ; el allocator (d0 ya vale el handler adentro)
$020206  cmpa.w  #$0, a0           ; pool lleno = salir sin clonar
$02020A  beq.b   (fuera)
$02020C  move.b  #$20, $58(a0)     ; el ID
$020212  move.l  $40(a5), $40(a0)  ; X desde el dueño
$020218  move.l  $9c(a5), $44(a0)  ; Y desde el SUELO del dueño
$02021E  move.w  $3e(a5), $3e(a0)  ; escala heredada
$020224  move.b  $26(a5), $26(a0)  ; ...y la variante por facing del $24
```

El `$24` del trail real sale del dueño: `move.b` del byte alto + `andi.w #$9800`
+ el `ori.$48` del facing ⇒ **`$C1A6` (paleta 2, bit15 prio, flip $0800)** —
exactamente lo que se vio en la captura del sonda. **El wrapper NO escribe el
byte bajo del `$24`**: el tile hereda del ocupante anterior del slot (en el
trail en juego eso funciona porque el `$A6` lo deja la estela anterior; en un
clon limpio hay que escribir el word completo). Consecuencia aplicada: el
record del clon del aura (v9 del veneno) se arma COMPLETO, con el slot
limpiado antes de escribir los campos.

**La tabla de pares es WORD apretado, no pares [idx,dur] separados**:
`$14EAC: 4C04 4D04 4E04 4F04 0000` = [idx 76..79, dur 4] + terminador
`[0,0]`. Al llegar al `$0000` el handler `$149AC` mata el record LIMPIO (la
via correcta de matar: nunca escribir `$4=0` a mano).

