# COLISIONES Y HITBOXES

Todo lo de este documento está **verificado leyendo el desensamblado**
(`game_68000.asm`). Cuando algo es hipótesis o viene de fuente externa, está
marcado como tal.

Herramientas escritas a partir de esto:

- `tools/fightcade/yuyu_probe.lua` — sonda de calibración
- `tools/fightcade/LLUVIA RECTA.LUA` — hitbox display + HUD

---

## 1. Estructura del jugador

| Dato | Valor | Evidencia |
|---|---|---|
| Base del slot de P1 | **`$FF8400`** | `tst.l $ffff8400.l` en `0x10D2C` |
| Base del slot de P2 | `$FF8800` (stride `$400`) | mismo patrón de slots — **CONFLICTO ABIERTO, ver la nota de abajo** |
| Registro base del struct | `a5` | todas las rutinas de jugador |

> **P2 sin resolver, y `$9000` tiene mas peso que `$8800`.** Hay una medicion
> externa de que P2 vive en `$FF9000` con stride `$C00`, y los tres `.lua` que
> vienen con ella usan `P2 = 0xFF9000`. Nuestro `$8800` sale de "mismo patron de
> slots", que es una inferencia. Cuando compiten una medicion y una inferencia,
> gana la medicion.
>
> **El codigo no puede zanjarlo, y hay que decirlo bien.** El bucle de slots
> recorre los cuatro con stride `$400`:
>
> ```asm
> 01c06a:  lea.l    $8400.w, a0
> 01c07e:  cmpa.w   #$9000, a0     ; <- el array INCLUYE $9000
> 01c084:  adda.w   #$400, a0      ; <- avanza de a $400
> ```
>
> **Que el stride del array sea `$400` no dice en que slot esta P2.** Un array de
> 4 con P1 en el indice 1 y P2 en el indice 4 da `$C00` entre ambos, y es
> compatible con el bucle. Asi que el bucle **apoya a `$9000`** en vez de
> descartarlo. Y `0x00FAF2` si inicializa un struct completo sobre
> `lea.l $8800.w, a0`, asi que `$8800` tambien es slot real. Los dos existen.
>
> Para cerrarlo hay que volcar los 4 slots en ejecucion y leer HP (`$78`), stun
> (`$7E`) y maná (`$B8`).
>
> **Por que importa:** para cualquier `.lua` que lea del slot del P2 (HP, stun,
> maná, moves). **NO para el dibujo de las cajas**, y esto salio al reves: este
> parrafo decia antes que si fuera `$9000` el HUD del P2 "no dibuja nada, sin
> error". **Es falso, verificado pixel a pixel** en el autotest 8b. El
> `LLUVIA RECTA.LUA` tiene `local P2 = 0xFF8800` hardcodeado, pero ese valor no
> llega a la salida del dibujo: `owner_filter()` decide con el flag `SHOW_P2` y no
> con el slot, y `to_screen()` ancla a `owner_base(owner) or P1` con una
> conversion **afín de pendiente 1** en la que el base se cancela. Las dos rutas
> donde `owner_base()` si decide (`rects_grab` y `draw_grab_range`) estan detras
> de `SHOW_GRAB = false`. Con `$8800` y con `$9000` se dibuja lo mismo.

> Las direcciones con prefijo `FF` son directamente accesibles desde Lua de
> FBNeo: los 64 KiB de work RAM están mapeados 1:1 y reflejados cada
> `$010000` entre `$E00000` y `$FFFFFF`. `0xFF84B8` → offset RAM `0x84B8`.

### Campos del struct confirmados

| Offset | Contenido | Evidencia |
|---|---|---|
| `$08` / `$0C` | **posición en pantalla** X / Y | `loc_0156F0` la calcula y la escribe |
| `$28` / `$2A` | velocidad X / Y | `move.w d6,$28(a5)` en `loc_01EB40` |
| `$3E` | escala (256 = 1.0) | `muls.w $3e(a5),d5` en `0x1ED8` |
| `$40` / `$44` | **posición en mundo** X / Y (32 bits) | base de las coordenadas de caja |
| `$50` | puntero a tabla índice de moves (stride 8) | `loc_01EB40` |
| `$54` / `$56` | **offset de empuje acumulado** en el frame | ver §2 |
| `$59` | frame / elemento de animación | índice ×8 en la tabla de moves |
| `$5A` | duración de animación | `move.b $0(a2),$5a(a5)` |
| `$5B` | contador de animación | — |
| `$5F` | **id de move / estado** | escritura y lectura mas frecuente |
| `$61` | facing (0 = mirando a la derecha) | `btst.b #$0,d5` en el builder |
| `$69` | hitpause / freeze de frames | `subi.b #$1,$69(a5)` |
| `$6C` | flags de estado | — |
| `$78` | **HP actual** (word signed, max 255) | `sub.w d0,$78(a4)` en `0x1F3E0` |
| `$7A` | HP que se dibuja, persigue a `$78` | `cmp.w $78(a5),d0` en `0x1579C` |
| `$7E` | **stun gauge** (word) | ver §6 |
| `$80` | **stun máximo** (word) | `move.w $80(a5),$7e(a5)` |
| `$8C` | puntero a la tabla de moves del personaje | ver §5 |
| `$90` | tabla de registros de 30 bytes | `FISICAS_Y_MOVIMIENTO.md` §6.2 |
| `$B8` | **maná / TA**, recurso gastable (max 223) | `loc_019C46` = `pagar(coste)` |
| `$C8` | flag testeado en el filtrado de colisión | `tst.b $c8(a4)` en `0x1EF0A` |
| `$9C` | ID de personaje (comparado para filtrar clashes) | `cmp.w $9c(a4),d0` en `0x1EF1E` |

---

## 2. `$54` y `$56` NO son el HP máximo

**Corrección importante.** Los apuntes anteriores decían que `$54` era el HP
máximo y `$4E` el umbral de HP débil. Es falso. `loc_0156F0` (`0x156F0`):

```
0156f0:  move.w  $40(a5), d0        ; X en mundo
0156f4:  sub.w   $a014.w, d0        ; - base del stage
0156f8:  addi.w  #$80, d0
0156fc:  add.w   $54(a5), d0        ; + empuje acumulado en este frame
015700:  cmpi.w  #$40, d0           ; clampear a [0x40 .. 0x1FF]
015714:  move.w  d0, $8(a5)         ; -> posicion en pantalla X
015718:  clr.w   $54(a5)            ; y se borra en cada frame
```

Lo mismo para Y con `$56` y `$F566`:

```
01571c:  move.w  $44(a5), d0
015720:  sub.w   $a016.w, d0
015724:  add.w   $f566.w, d0        ; scroll vertical
015728:  addi.w  #$20, d0
01572c:  add.w   $56(a5), d0
015730:  cmpi.w  #$40, d0           ; clampear a [0x40 .. 0x1C0]
015744:  subq.w  #$8, d0
015746:  move.w  d0, $c(a5)         ; -> posicion en pantalla Y
01574a:  clr.w   $56(a5)
```

**Conclusión:** `$54` / `$56` son acumuladores de empuje (shove) que se suman a
la posición del frame y se ponen a cero. El par add/sub en `0x12B58` /
`0x12B62` confirma que son magnitudes cortas.

**HP real:** word **signed** en `$78`. Lo resta el resolver de hitbox-vs-hurtbox
(`loc_01F21E`) en `0x1F3E0` y lo clampa a 0 en `0x1F3EC`.

| Dato | Valor | Evidencia |
|---|---|---|
| HP actual | word en `$78` | `0x1F3E0: sub.w d0,$78(a4)` |
| HP máximo | **255** (`$FF`) | `0x12AE6: move.w #$ff,$78(a5)` |
| HP dibujado | word en `$7A` | `0x1579C: cmp.w $78(a5),d0` |
| Umbral de vida baja | **111** (`$6F`) | `cmpi.w #$6f,$78(a5)` en 14 sitios |
| Umbral visual | 112 (`$70`) | `0x15784: cmpi.w #$70,$78(a5)` |
| Comprobación de KO | `bge` / `bmi` | `0x15BCC`, `0x15BD8` |

**Maná / TA:** word en `$B8`. **No** es el HP: `loc_019C46` es
`pagar(coste)`, no la rutina de daño.

| Dato | Valor | Evidencia |
|---|---|---|
| Maná actual | word en `$B8` | `0x19C46: move.w $b8(a5),d1 / sub.w d0,$b8(a5)` |
| Maná máximo | **223** (`$DF`) | `0x1A2E2: move.l #$df0000,$b8(a5)` |
| Umbral de maná bajo | **32** (`$20`) | `0x1CD70: cmpi.w #$20,$b8(a5)` |
| Recuperación (+16) | `addi.w #$10,$b8(a5)` | `0x1A882`, `0x1B160` |
| Coste de especial | `pagar(coste)` | callers en `0x1894A` (8), `0x18962` (12), `0x18992` (12), `0x189B2` (16) |

El "223" que se había medido como HP máximo era en realidad el tope del maná,
y el "32" como umbral de vida baja es el umbral de maná bajo. El 111 que se
había medido a ciegas como umbral sí es el de HP: es `$6F`.

`$4E` sigue **sin identificar**. No es el umbral de HP.

---

## 3. Cámara y scroll

| Dirección | Qué es | Evidencia |
|---|---|---|
| `$FFF408` | origen de cámara **X** | `0x1EDE: sub.w $f408.w,d5` en el renderer de sprites; escrito en `0x1EB6`, `0x2170` |
| `$FFF40A` | origen de cámara **Y** | `0x1F02: sub.w $f40a.w,d6` |
| `$FFA014` | base X del stage (init `#$360`) | `0x457A`, usado en `loc_0156F0` |
| `$FFA016` | base Y del stage (init `#$20`) | `0x4586` |
| `$FFF566` | scroll vertical acumulado | `add.w $f566.w,d0` en `loc_0156F0` |
| `$FFA010` / `$FFA012` | límites del stage para clipping | `0x1EFE4`, `0x1EFF4` |

Conversión mundo → pantalla lógica (la que usa el juego para colisiones):

```
screen_x = world_x - $A014 + $80 + empuje_x        ; clamp [0x40 .. 0x1FF]
screen_y = world_y - $A016 + $F566 + $20 + empuje_y - 8   ; clamp [0x40 .. 0x1C0]
```

---

## 4. Listas de colisiones

El builder es `loc_01EB40` (`0x1EB40`), llamado desde 18 sitios del update de
jugador. El dispatcher es `loc_01EDAC` (`0x1EDAC`).

### 4.1 Tabla de listas

| Lista | Base | Contador | Stride | Qué es |
|---|---|---|---|---|
| hitbox | `$FFA200` | `$FFA004` | `$10` | cajas de ataque |
| clash | `$FFA300` | `$FFA006` | `$10` | cajas de clash |
| hurtbox | `$FFA400` | `$FFA008` | `$10` | cajas de daño recibido |
| pushbox | `$FFA500` | `$FFA00A` | `$10` | caja de empuje |
| **grab** | `$FFA600` | `$FFA00C` | **`$20`** | **descriptor de grab / special hit** |

### 4.2 Los contadores son offsets EN BYTES

Este es el punto que hizo lento al script externo. El builder:

```
01ec30:  move.w  $a004.w, d3      ; d3 = offset actual en BYTES
01ec34:  cmpi.w  #$ff, d3
01ec3c:  move.w  #$f0, d3         ; satura en $F0 = 240 bytes
01ec3e:  movea.w d3, a3
...
01ec78:  addi.w  #$10, d3         ; avanza 16 bytes por entrada
01ec84:  move.w  d3, $a004.w      ; guarda el offset total
```

Por tanto:

- **El contador NO es la cantidad de cajas.**
- `n_cajas = contador / stride`.
- **Máximo 15 cajas** por lista de stride `$10` (y 7 para la de stride `$20`).
- El script externo recorría 16 entradas fijas y por eso leía basura.

### 4.3 Layout de entrada (stride `$10`)

Confirmado cruzando el writer (`loc_01EB40`) con el consumidor
(`loc_01EEE2`, `loc_01EE1E`):

```text
+0x00  word  X
+0x04  word  Y
+0x08  byte  radioX      ; el bit 7 es el TERMINADOR de la lista
+0x09  byte  radioY
+0x0C  word  owner       ; puntero al struct del dueño (0xFF8400, ...)
```

**El bit 7 del radioX marca "última caja".** El builder lo borra y lo testea:

```
01ec7c:  bclr.b  #$7, -$5df8(a3)
01ec82:  beq.b   $1ec34      ; si el byte quedo en 0, hay otra caja
01ec84:  move.w  d3, $a004.w ; si no, el contador queda aqui
```

Los radios son un solo byte cada uno (el juego no usaHitbox elíptica: la
comparación en `0x1EF62` y `0x1EF82` es una suma de radios contra una
diferencia de centros).

### 4.4 Layout del descriptor de grab (stride `$20`)

`$FFA600` **no es una hitbox más**. Se llena en `0x161BA` con
`addi.w #$20, $a00c.w` y lo consume `loc_01EEE2` (`0x1EEE2`):

```text
+0x00  word  X
+0x02  word  Y
+0x04  byte  radioX
+0x05  byte  radioY
+0x06  byte  id de move del victimizado
+0x08  byte  parametro -> copiado a $5D
+0x0A  byte  facing del victimizado
+0x0C  word  owner
+0x10  word  knockback X  -> se suma a $44/$40
+0x12  word  knockback Y
```

Evidencia del copiado, en `loc_01EEE2`:

```
01f004:  move.b  -$59fa(a1), $5f(a3)   ; +0x06 -> id de move
01f00a:  move.b  -$59f8(a1), $5d(a3)   ; +0x08 -> param
01efae:  move.b  -$59f6(a1), $61(a4)   ; +0x0A -> facing
01efc0:  move.w  -$59ee(a1), d0        ; +0x12 -> knockback Y
01efc8:  move.w  -$59f0(a1), d0        ; +0x10 -> knockback X
```

**Implicación para el remake:** `$FFA600` no se dibuja como una caja más. Es una
tabla de "qué pasa cuando este grab pega": a quién poner en qué estado, con qué
facing y con qué retroceso. Se puede dibujar como caja para visualizarla, pero
el contenido significa otra cosa.

### 4.5 Limpieza de los contadores

```
01edc2:  move.w  #$0, $a004.w
01edc8:  move.w  #$0, $a006.w
01edce:  move.w  #$0, $a008.w
01edd4:  move.w  #$0, $a00a.w
01edda:  move.w  #$0, $a00c.w
```

**Las entradas quedan en RAM; solo se borran los contadores.** Por eso un hook
en `0x01EDAC` (la entrada del dispatcher) alcanza para saber cuántas cajas hay:
todavía no fueron limpiadas.

Además el dispatcher tiene una salida temprana:

```
01edac:  btst.b  #$7, $f550.w
01edb2:  bne.b   $1ee1c      ; si esta activo, no se borra nada
```

Por eso el hook va en `0x01EDAC` y no en `0x01EDC2`: cubre los dos casos.

---

## 5. Flags de la tabla de moves

El builder lee un byte de flags desde la tabla de moves del personaje
(`$8C(a5)`) y decide qué listas llenar:

```
01ec06:  btst.b  #$6, d4   ; -> lista de hitbox  ($A004)
01ec88:  btst.b  #$5, d4   ; -> lista de clash   ($A006)
01ece6:  btst.b  #$4, d4   ; -> lista de hurtbox ($A008)
01ed44:  btst.b  #$3, d4   ; -> lista de pushbox ($A00A)
```

| Bit | Lista | Stride | Notas |
|---|---|---|---|
| 3 | pushbox | `$10` | una sola entrada por llamada, sin bucle |
| 4 | hurtbox | `$10` | bucle por byte 7 del flag |
| 5 | clash | `$10` | bucle por byte 7 del flag |
| 6 | hitbox | `$10` | bucle por byte 7 del flag |

Los bits 0-2 no se usan para cajas en esta rutina.

---

## 6. Dispatcher de colisiones

```
01edac:  btst.b  #$7, $f550.w
01edb2:  bne.b   $1ee1c
01edb4:  bsr.w   $1eee2      ; A600 (grab) contra A400 (hurtbox) -> hit real
01edb8:  bsr.w   $1f090      ; A300 contra A300                  -> clash
01edbc:  bsr.w   $1f21e      ; A200 contra A400                  -> hit normal
01edc0:  bsr.b   $1ee1e      ; A500 contra A500                  -> empuje
01edc2:  ... limpia los 5 contadores
```

El puntero de la tarea de colisión se instala en `$FF8100` en cinco sitios
(`0x45C6`, `0x68B4`, `0xA8B2`, `0xAEDA`, `0xF37E`):

---

## 6b. El owner es un WORD, no un puntero

**Esto fue la razón de que el HUD no mostrara ninguna caja durante días.**

El builder escribe el owner con `move.w a5`, no `move.l`:

```
01ec40:  move.w  a5, -$5df4(a3)   ; lista hit   (A200)
01ec9e:  move.w  a3, ...           ; ver tambien 0x1EC9E (clash, A300)
01ecfc:  move.w  a4, -$5bf4(a3)   ; lista hurt  (A400)
01ed5a:  move.w  a5, -$5af4(a3)   ; lista push  (A500)
0161be:  move.w  a5, -$59f4(a1)   ; descriptor de grab (A600)
```

`move.w` solo guarda los 16 bits bajos, así que el campo `+$C` vale
**`$8400`** para P1 y **`$8800`** para P2, nunca `$FF8400`. Los resolvers lo
recuperan con `movea.w` (`0x1EE34`, `0x1F0A6`, `0x1F23E`), lo que confirma que
el juego también lo trata como 16 bits: el struct vive en `$8400`, y `$FF8400`
es solo el espejo que usa FBNeo.

Comparar `owner == 0xFF8400` desde Lua **nunca** da true. Hay que normalizar.
**Ojo: los dos `low` no son constantes**, porque el slot del P2 no esta siempre en
el mismo lado (`$8800` desde el select, `$9000` desde un savestate). La version
del `LLUVIA RECTA.LUA` los deduce:

```lua
-- No suponer el slot del P2: se recorren los 4 y se reasignan si hay dos vivos.
local SLOTS  = { 0xFF8400, 0xFF8800, 0xFF8C00, 0xFF9000 }
local OFF_HP, OFF_MOVES = 0x78, 0x8C      -- HP (signed) y tabla de moves
local P1, P2 = 0xFF8400, 0xFF8800

local function detectar_slots()
  local vivos, n = {}, 0
  for i = 1, #SLOTS do
    local b = SLOTS[i]
    if rws(b + OFF_HP) ~= 0 or rw(b + OFF_MOVES) ~= 0 then
      n = n + 1; vivos[n] = b
    end
  end
  if n >= 2 then P1, P2 = vivos[1], vivos[2] end
end

local function owner_base(v)
  local lo = own_lo(v)
  if lo == own_lo(P1) then return P1 end
  if lo == own_lo(P2) then return P2 end
  return nil
end
```

Con menos de dos slots vivos se quedan las constantes, o sea el comportamiento
anterior. **Y en el HUD esto no cambia ni un pixel**, porque el valor de P2 no
llega al dibujo (ver la nota de la seccion 1). Sirve para lo que si lee del slot.


```
move.l  #$1edac, $8100.w
```

### Filtros aplicados antes de detectar overlap

En `loc_01EEE2`, una pareja se descarta si:

- `$C8` del dueño está activo (`0x1EF0A`)
- el **byte de equipo/rol en `$6E`** coincide (`0x1EF12`) → no se golpea a uno propio
- el **ID de personaje en `$9C`** coincide (`0x1EF1E`)
- el bit 5 de `$6C` está activo (`0x1EF2A`)
- el bit 3 de `$5C` difiere entre los dos (`0x1EF34`)

### Test de overlap

```
01ef4a:  move.w  boxA.x, d0
01ef4e:  sub.w   hurt.x, d0
01ef52:  bpl.b   $1ef56
01ef54:  neg.w   d0            ; d0 = |boxA.x - hurt.x|
01ef58:  moveq   #$0, d1
01ef5c:  move.b  boxA.rx, d1   ; d1 = radioX de A + radioX de B
01ef62:  sub.w   d0, d1
01ef62:  blt.w   $1f076        ; si d1 < 0 -> no hay overlap
```

Es decir: **el solapamiento es la suma de los dos radios contra la distancia
entre centros**, en cada eje por separado. Caja rectangular, no elipse.

---

## 7. Stun

| Dato | Valor | Evidencia |
|---|---|---|
| Stun actual | word en `$7E` | inicializado por move, testeado contra 0 |
| Stun máximo | word en `$80` | `move.w $80(a5),$7e(a5)` en `0x15A4A` y `0x18694` |
| Sentinel | `$FF` | `move.w #$ff,$7e(a5)` en `0x1A282` |
| Test de agotamiento | `cmpi.w #$0,$7e(a5)` | `0x19D84` |

Valores iniciales observados por move en `0x127C8`-`0x12A62`:
`$26, $28, $2A, $2C, $2E, $30, $32, $36, $38, $3E`
→ **38 a 62** en decimal.

El campo de 32 bits `$14..$17` ya no esta sin decodificar: **es el empujon**,
un long con tres intensidades.

| Direccion | Valor | Intensidad |
|---|---|---|
| `0x1F342` | `move.l #$FFFC0000, $14(a4)` | leve |
| `0x1F364` | `move.l #$FFFB0000, $14(a4)` | media |
| `0x1F386` | `move.l #$FFFA0000, $14(a4)` | fuerte |

No es el stun: el stun que decide el knockdown es el word de `$7E`, y es un
**presupuesto** que se gasta por golpe, no un timer. Ver
`TABLAS_MOVES_Y_TIMING.md` §4.

---

## 8. Errores del material externo (Discord / BizHawk)

Estos scripts se intentan usar como referencia, pero **tienen errores
confirmados**. No portarlos tal cual.

| Afirmación externa | Realidad |
|---|---|
| HP en `0x8479` | **Casí.** El HP es el word de `$78`, así que `$79` es su byte alto. El campo correcto es `0x8478` (o `$FF8478`), no `$8479`. |
| Super meter en `0x84B9` | Falso. `$B9` es el byte alto de `$B8`, o sea del maná. Y `$B8` es un recurso gastable, no el medidor de super. |
| Stun en `0x847E` | **Correcto.** Es el word de `$7E`. |
| `"camx"` en `$A014` | Falso. `$A014` es la base X del stage (init `#$360`). La cámara es `$FFF408`. |
| `$A016` como `camy` | Falso. Es la base Y del stage (init `#$20`). La cámara Y es `$FFF40A`. |
| Leer siempre 16 cajas por lista | Falso y lento. Los contadores son offsets en bytes; el máximo es 15. |
| Escribir ceros en las listas | **No hacerlo.** Puede corromper el estado del juego. Ninguna version nueva lo hace. |
| `$A600` = "hitbox especial" | Parcial. Es el **descriptor de grab**, stride `$20`, con campos propios. |

Lo único que el script de Discord acertó: el layout de 16 bytes con X, Y,
radios y owner, y que las cajas son dinámicas por frame y por move.

---

## 9. Script de referencia

`tools/fightcade/yuyu_probe.lua` — vuelca todo lo de este documento en
pantalla e imprime en consola los cambios. Sirve para:

1. Confirmar que `n = contador / 0x10` y que nunca pasa de 15.
2. Calibrar la conversión caja → pantalla contra los sprites.
3. Descartar o confirmar `$7E` como stun.
4. Buscar el medidor de super (todavía sin dirección).

`tools/fightcade/LLUVIA RECTA.LUA` — versión de uso: hitboxes + HUD de
HP/stun + input display de P1.

Carga: `Game > Lua Scripting > New Lua Script Window > Browse`.

---

## 10. Pendiente

- **Medidor de super**: sin dirección confirmada. Rutas a seguir:
  - el subsistema de `$7E` / `$80` es el mismo tipo de "gauge", puede estar
    al lado en el struct;
  - localizar la rutina que dibuja el gauge propio del juego y ver de qué
    offset lee.
- **Jugador 2**: la config `md_yuyumte.ini` tiene 7 entradas de P2 apuntando a
  `switch 0x08` y `Button Z` duplicando P1. Hay que remedirlo desde el menú de
  mandos de Fightcade, no editando el `.ini`.
- **Frame data** (startup/active/recovery): las tablas por personaje siguen sin
  localizarse. Ver `FISICAS_Y_MOVIMIENTO.md` §10.
- **Gravedad / fricción / contacto con el suelo**: sin localizar.