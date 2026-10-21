extends Node2D
##
## Escena principal: arena de combate 1v1 con jugador humano + CPU.
## Reproduce las reglas verificadas del juego original.
##

const ARENA_W := 320.0
## Constantes de fisica verificadas del ROM (ver Fisica.gd)
const PH := preload("res://Fisica.gd")

@onready var fighter1: Fighter = $Fighter1
@onready var fighter2: Fighter = $Fighter2
@onready var ai: SimpleAI = $AI
@onready var round_label: Label = $UILayer/Round
@onready var p1_label: Label = $UILayer/P1Label
@onready var p2_label: Label = $UILayer/P2Label
@onready var info_label: Label = $UILayer/Info
## readout de fisica: permite COMPROBAR sobre el juego que los valores
## coinciden con los del ROM
@onready var debug_label: Label = $UILayer/Debug
## Ventana HALL OF FAME: visible mientras se mantenga START presionado.
@onready var hall_of_fame: HallOfFame = $UILayer/HallOfFame
## barras fijas arriba: en el original NO siguen al personaje
@onready var h1_hp: ColorRect = $UILayer/Hud1HP
@onready var h1_mana: ColorRect = $UILayer/Hud1Mana
@onready var h1_stun: ColorRect = $UILayer/Hud1Stun
@onready var h2_hp: ColorRect = $UILayer/Hud2HP
@onready var h2_mana: ColorRect = $UILayer/Hud2Mana
@onready var h2_stun: ColorRect = $UILayer/Hud2Stun

var _combo_hits: int = 0
var _round_time: float = 0.0
var _paused_for_hit: bool = false

@export var p1_char: int = 6      # Yusuke
@export var p2_char: int = 5      # Kuwabara
@export var difficulty: int = 1    # SimpleAI.Difficulty.NORMAL


func _ready() -> void:
	_fighter_setup()


func _fighter_setup() -> void:
	fighter1.setup(p1_char)
	fighter1.player_slot = 0
	fighter1.global_position = Vector2(88, 186)
	fighter1.facing = 1

	fighter2.setup(p2_char)
	fighter2.player_slot = 1
	fighter2.is_cpu = true
	fighter2.global_position = Vector2(232, 186)
	fighter2.facing = -1

	ai.self_fighter = fighter2
	ai.enemy = fighter1
	ai.set_difficulty(difficulty)

	p1_label.text = "1P  %s" % fighter1.display_name
	p2_label.text = "%s  CPU" % fighter2.display_name
	info_label.text = ""

	fighter1.landed_hit.connect(_on_hit)
	fighter2.landed_hit.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_round_time += delta
	# resolver colisiones de hitbox (semicirculo simple)
	if not fighter1.is_knocked_down:
		var hb := fighter1.get_active_hitbox()
		if not hb.is_empty() and _in_range(fighter1, fighter2):
			fighter2.take_damage(int(hb["dmg"]), fighter1.facing)
			_combo_hits += 1
			fighter1.gain_mana(_combo_hits)
			fighter1.landed_hit.emit(fighter2, int(hb["dmg"]))
	if not fighter2.is_knocked_down:
		var hb2 := fighter2.get_active_hitbox()
		if not hb2.is_empty() and _in_range(fighter2, fighter1):
			fighter1.take_damage(int(hb2["dmg"]), fighter2.facing)
			fighter2.gain_mana(1)


func _in_range(a: Fighter, b: Fighter) -> bool:
	var dx: float = absf(a.global_position.x - b.global_position.x)
	var dy: float = absf(a.global_position.y - b.global_position.y)
	return dx < 22.0 and dy < 20.0


func _on_hit(target: Fighter, dmg: int) -> void:
	# hitstop: pequeño freeze (desactivado por defecto en datos, como el original era leve)
	pass


func _process(_d: float) -> void:
	# HALL OF FAME: se abre mientras se mantenga START y se cierra al soltar.
	# Va antes que todo lo de la pelea para que el menu tenga prioridad.
	if hall_of_fame != null:
		hall_of_fame.actualizar_hold(_d, Input.is_action_pressed("start_button"))
		if hall_of_fame.esta_abierto():
			return

	# barras de vida / espiritu / stun, fijas arriba (como el original)
	_actualizar_barra(h1_hp, fighter1.hp, fighter1.hp_max, false)
	_actualizar_barra(h1_mana, fighter1.mana, fighter1.mana_max, false)
	_actualizar_barra(h1_stun, fighter1.stun, 60.0, false)
	_actualizar_barra(h2_hp, fighter2.hp, fighter2.hp_max, true)
	_actualizar_barra(h2_mana, fighter2.mana, fighter2.mana_max, true)
	_actualizar_barra(h2_stun, fighter2.stun, 60.0, true)

	# mantener a los peleadores dentro de la arena
	for f in [fighter1, fighter2]:
		f.global_position.x = clampf(f.global_position.x, 26.0, ARENA_W - 26.0)
		f.global_position.y = minf(f.global_position.y, 186.0)

	_empujar_por_separacion()
	_actualizar_debug()


## Los dos luchadores no deben solaparse: se empujan.
## Sin esto se quedan pegados, que es lo que se veia.
const SEPARACION_MIN := 22.0


func _empujar_por_separacion() -> void:
	var dx: float = fighter2.global_position.x - fighter1.global_position.x
	var dy: float = fighter2.global_position.y - fighter1.global_position.y
	if absf(dy) > 24.0:
		return
	var d: float = absf(dx)
	if d >= SEPARACION_MIN:
		return
	if d < 0.01:
		# exactamente encima: separarlos hacia un lado fijo
		dx = 1.0
		d = 1.0
	var signo: float = 1.0 if dx >= 0.0 else -1.0
	var correccion: float = (SEPARACION_MIN - d) * 0.5 * signo
	fighter1.global_position.x -= correccion
	fighter2.global_position.x += correccion


## Muestra la fisica en vivo para poder verificarla contra el ROM.
## Constantes: FISICAS_Y_MOVIMIENTO.md
func _actualizar_debug() -> void:
	if debug_label == null:
		return
	var f := fighter1
	var vx_px_frame: float = f.velocity.x / 60.0
	var vy_px_frame: float = f.velocity.y / 60.0
	var en_rejilla: bool = absf(f.position.x - roundf(f.position.x / float(PH.GRID)) * float(PH.GRID)) < 0.01
	debug_label.text = "walk %d px/f  vX %+0.1f  vY %+0.1f px/f  x %d  rejilla8:%s  %s" % [
		int(PH.WALK_PX_FRAME),
		vx_px_frame, vy_px_frame,
		int(f.position.x), "si" if en_rejilla else "no",
		f.action,
	]


## Rellena una barra. `invertir` la vacia desde la derecha (jugador 2).
func _actualizar_barra(bar: ColorRect, valor: float, maximo: float, invertir: bool) -> void:
	if bar == null:
		return
	var ancho_total := bar.size.x
	var frac := 0.0
	if maximo > 0.0:
		frac = clampf(valor / maximo, 0.0, 1.0)
	var ancho := ancho_total * frac
	if invertir:
		bar.offset_left = bar.position.x + (ancho_total - ancho)
		bar.offset_right = bar.offset_left + ancho
	else:
		bar.offset_left = bar.position.x
		bar.offset_right = bar.position.x + ancho


func _process_sin_usar(_delta: float) -> void:
	# mantener a los luchadores en la arena
	for f in [fighter1, fighter2]:
		f.global_position.x = clampf(f.global_position.x, 20.0, ARENA_W - 20.0)
	# reset combo si no hay hit
	if _combo_hits > 0:
		_combo_hits = max(0, _combo_hits - 1)
