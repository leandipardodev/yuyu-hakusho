extends RefCounted
##
## Constantes de FISICA verificadas leyendo el codigo del ROM.
##
## FUENTE: ver FISICAS_Y_MOVIMIENTO.md (proyecto Yu Yu Hakusho Makyou Toitsusen)
##
## La clave de todo: el juego trabaja en PIXELES POR FRAME a 60 Hz, con las
## posiciones alineadas a una REJILLA DE 8 PIXELES. No es un juego de
## velocidades continuas: el codigo hace
##
##     move.w  $8(a5), d2      ; posicion X
##     subi.w  #$80, d2        ; origen centrado
##     add.w   $28(a5), d2     ; + velocidad X
##     ...
##     andi.w  #$fff8, d5      ; <-- alinea a 8 px
##
## NO se usan los "grades" de velocidad A/B/C/S de las guias web: en el codigo
## no existen, la velocidad de caminado es la misma para los 11 personajes.
##

## Frames por segundo del juego original (Mega Drive, modo NTSC).
const FPS := 60

## Rejilla de posiciones: el juego alinea a multiplos de 8 px.
const GRID := 8

## Caminar: 8 px por frame exactos (medido en la tabla de estado $D282).
const WALK_PX_FRAME := 8.0

## Salto: impulso inicial -16 px/frame y despues -8 px/frame.
## Estados reales de la tabla $D2A2.
const JUMP_PX_FRAME_1 := -16.0
const JUMP_PX_FRAME_2 := -8.0

## Cuantos frames dura la primera fase del salto.
const JUMP_STAGE_FRAMES := 8

## CAIDA: el ROM no integra una gravedad continua. Fija la velocidad vertical
## por estado de caida y los valores observados son 8 -> 16 -> 24 px/frame:
## escalones de 8. Por eso arrancamos en 8 y sumamos 8 hasta 24.
const FALL_FRAME_0 := 8.0
const FALL_FRAME_MAX := 24.0

## Rozamiento: el original NO tiene inercia, se para en seco. Se deja aqui
## solo por compatibilidad; no se usa.
const FRICTION := 8.0

## Celda de sprite del original: 32x32 px = 4x4 tiles.
const SPRITE_CELL := 32

## Tamano del sprite en el juego base (320x224).
const SCREEN := Vector2(320, 224)


static func walk_px_frame() -> float:
	return WALK_PX_FRAME


static func jump_px_frame(stage: int) -> float:
	if stage <= 0:
		return JUMP_PX_FRAME_1
	return JUMP_PX_FRAME_2


## Alinea una posicion a la rejilla del original.
static func snap(value: float) -> float:
	return snappedf(value, float(GRID))
