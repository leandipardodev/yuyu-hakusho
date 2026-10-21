extends Node
class_name SimpleAI
##
## IA del oponente CPU del remake.
## Originalmente el juego (Treasure, 1994) tenia una IA simple.
## Objetivo: hacer una IA mas fuerte programandola aqui (no en asm 68k).
##
## Dificultad: Easy / Normal / Hard / Super
## - timing de reaccion (frames antes de actuar)
## - probabilidad de hacer la mejor accion
## - agresividad (acercarse vs mantener distancia)
## - uso de ataques rapidos (weak) cuando tiene ventaja de frame
##

enum Difficulty { EASY, NORMAL, HARD, SUPER }

@export var difficulty: int = Difficulty.NORMAL
@export var self_fighter: Fighter = null
@export var enemy: Fighter = null

var _decision_timer: int = 0
var _react_frames: int = 10
var _aggression: float = 0.5
var _special_ratio: float = 0.2

# tabla de dificultad (ajustable)
const CONFIG := {
	Difficulty.EASY:   {"react": 22, "aggro": 0.30, "spec": 0.05, "block": 0.05},
	Difficulty.NORMAL: {"react": 14, "aggro": 0.50, "spec": 0.20, "block": 0.20},
	Difficulty.HARD:   {"react": 8,  "aggro": 0.70, "spec": 0.35, "block": 0.45},
	Difficulty.SUPER:  {"react": 4,  "aggro": 0.85, "spec": 0.50, "block": 0.70},
}


func _ready() -> void:
	set_process(true)


func set_difficulty(d: int) -> void:
	difficulty = d
	var c: Dictionary = CONFIG[d]
	_react_frames = int(c["react"])
	_aggression = float(c["aggro"])
	_special_ratio = float(c["spec"])


func _physics_process(_delta: float) -> void:
	if self_fighter == null or enemy == null:
		return
	if self_fighter.is_knocked_down or self_fighter.hp == 0:
		return
	_decision_timer -= 1
	if _decision_timer > 0:
		return
	_decision_timer = _react_frames
	_decide()


func _decide() -> void:
	var dist: float = absf(enemy.global_position.x - self_fighter.global_position.x)
	var dir: int = signf(enemy.global_position.x - self_fighter.global_position.x)
	self_fighter.facing = dir
	var cfg: Dictionary = CONFIG[difficulty]

	# 1) bloquear si el enemigo ataca cerca
	if _randf() < float(cfg["block"]) and dist < 34.0 and self_fighter.is_on_floor():
		self_fighter.is_blocking = true
		return
	self_fighter.is_blocking = false

	# 2) super si disponible
	if self_fighter.can_super() and _randf() < 0.6:
		self_fighter.start_move("super")
		return

	# 3)的决定 por distancia
	if dist < 26.0:
		# cuerpo a cuerpo: agarre o golpe rapido
		if _randf() < 0.35 and self_fighter.stun > 10:
			self_fighter.start_move("throw")
		elif _randf() < _aggression:
			self_fighter.start_move("stand_a" if _randf() < 0.5 else "light")
		else:
			_passive()
	elif dist < 70.0:
		# media distancia: proyectil o acercarse
		if self_fighter.mana >= 32 and _randf() < _special_ratio:
			self_fighter.start_move("reimu")
		elif _randf() < _aggression:
			_approach(dir)
		else:
			_passive()
	else:
		# lejos: acercarse o proyectil
		if self_fighter.mana >= 32 and _randf() < _special_ratio * 0.5:
			self_fighter.start_move("reimu")
		else:
			_approach(dir)


func _approach(dir: int) -> void:
	var t: float = 0.09
	var p := self_fighter.global_position
	self_fighter.velocity.x = dir * self_fighter.move_speed
	# salto opcional para cerrar distancia
	if _randf() < 0.12 and self_fighter.is_on_floor():
		self_fighter.velocity.y = self_fighter.jump_force
	# mover hacia el rival
	var target := enemy.global_position
	if absf(target.x - p.x) > 6.0:
		self_fighter.global_position.x = move_toward(p.x, target.x - dir * 22.0, self_fighter.move_speed * t / max(t, 0.016))


func _passive() -> void:
	self_fighter.velocity.x = move_toward(self_fighter.velocity.x, 0, 600 * 0.016)
	if _randf() < 0.3:
		self_fighter.is_blocking = true


func _randf() -> float:
	return randf()
