extends CharacterBody2D
class_name Fighter

## Constantes de fisica verificadas del ROM (ver Fisica.gd)
const PH := preload("res://Fisica.gd")
##
## Luchador del remake de Yu Yu Hakusho: Makyou Toitsusen.
## Los datos vienen de data/game_data.json, que lleva la procedencia de cada
## campo en su bloque "_confianza" (ROM / BIZHAWK / WEB / ESTIMADO).
## OJO: many campos (stun_max, stats, normales, especiales) son de guias web,
## NO estan verificados contra el ROM.
## Constantes de hardware verificadas leyendo el ROM:
##   0x8054 = HP max 223 ($df)   |   0x804E = umbral HP debil 111 ($6f)
##   0x19C46 = sub.w d0,$b8(a5) = aplicar dano
##

signal landed_hit(target, damage)
signal took_damage(amount)
signal died

@export var char_id: int = 6          # 1..11
@export var is_cpu: bool = false
@export var player_slot: int = 0

# --- datos del personaje (de game_data.json) ---
var data: Dictionary = {}
var display_name: String = "?"
var stun_max: int = 48
var hp_max: int = 223
var mana_max: int = 223
## Estado del salto, usando las fases reales del ROM (-16 y -8 px/frame)
var jumping: bool = false
## Estado del salto y de la caida en PIXELES POR FRAME (no en px/s).
## El ROM trabaja en pasos discretos; ver la tabla de estados en Fisica.gd.
var _vy_anterior: float = 0.0
var _fall_frame: float = 8.0
var last_special: String = ""
var special_damage: int = 0
## Parser de motions (comandos reales del juego, ver data/comandos.json)
var motion := MotionInput.new()
var _jump_start_frame: int = 0
var _jump_stage: int = 0
var _fall_stage: int = 0
var move_speed: float = PH.WALK_PX_FRAME * PH.FPS
var jump_force: float = PH.JUMP_PX_FRAME_1 * PH.FPS

# --- estado de combate ---
var hp: int = 223
var mana: int = 0
var stun: int = 0                  # se agota a 0 -> knockdown
var stun_threshold: int = 255       # al levantarse, stun = 255
var is_grounded: bool = true
var is_knocked_down: bool = false
var is_blocking: bool = false
var facing: int = 1

# --- estado de accion / frame data ---
# Startup / active / recovery en frames (a 60fps). editables desde JSON.
var action: String = "idle"
var action_frame: int = 0
var action_total: int = 0
var has_hit_this_move: bool = false
var move_data: Dictionary = {}       # {dmg, startup, active, recovery, mana, hitstun}

# sec = { "dmg":int, "startup":int, "active":int, "recovery":int, "mana":int }
# Values from DAMAGE_TABLE.md + FRAME_DATA_MEDIDO.md
const MOVES := {
	"weak":  {"dmg": 1,  "startup": 3,  "active": 2,  "recovery": 4,  "mana": 0, "hitstun": 8},
	"stand_a": {"dmg": 16, "startup": 6, "active": 2, "recovery": 3, "mana": 0, "hitstun": 16},
	"crouch_a": {"dmg": 19, "startup": 7, "active": 2, "recovery": 8, "mana": 0, "hitstun": 16},
	"light":  {"dmg": 6,  "startup": 4,  "active": 2,  "recovery": 13, "mana": 0, "hitstun": 10},
	"crouch_b": {"dmg": 7, "startup": 4, "active": 2, "recovery": 12, "mana": 0, "hitstun": 10},
	"dash_b":  {"dmg": 12, "startup": 5,  "active": 3,  "recovery": 16, "mana": 0, "hitstun": 12},
	"throw":  {"dmg": 19, "startup": 2,  "active": 2,  "recovery": 20, "mana": 0, "hitstun": 14},
	"reimu":  {"dmg": 32, "startup": 8,  "active": 4,  "recovery": 31, "mana": 32, "hitstun": 12},
	"super":  {"dmg": 64, "startup": 10, "active": 6,  "recovery": 40, "mana": 200, "hitstun": 20},
}

@onready var sprite: Sprite2D = $Sprite2D

# --- animaciones (hojas exportadas de TileMolester) ---
const CHAR_FILES := [
	"01_sensui", "02_jin", "03_itsuki", "04_genkai", "05_kuwabara", "06_yusuke",
	"07_kurama", "08_hiei", "09_chui", "10_toguromayor", "11_toguromenor",
]
const ANIM_FRAMES := {   # nº de frames por animación
	"idle": 4, "walk": 6, "crouch": 1, "jump": 2, "fall": 1,
	"hitL": 1, "hitH": 2, "atkA": 4, "atkB": 3, "crA": 3,
	"throw": 4, "special": 6, "super": 8,
}
var anim_frames: Dictionary = {}   # nombre -> {tex, nframes, w}
var cur_anim: String = "idle"
var anim_t: float = 0.0


## Carga las hojas de animacion si existen (sprites/animaciones/).
func _load_anims() -> void:
	var base: String = CHAR_FILES[clampi(char_id - 1, 0, 10)]
	for name in ANIM_FRAMES.keys():
		var path := "res://sprites/animaciones/%s_%s.png" % [base, name]
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				var t: Texture2D = tex
				var n: int = int(ANIM_FRAMES[name])
				var fw: float = float(t.get_width()) / float(n)
				anim_frames[name] = {"tex": t, "n": n, "w": fw}
	if anim_frames.has("idle"):
		cur_anim = "idle"
		_mostrar_placeholder(false)


func play_anim(name: String) -> void:
	if not anim_frames.has(name):
		if anim_frames.has("idle"):
			name = "idle"
		else:
			return
	cur_anim = name
	anim_t = 0.0
	_apply_anim_frame()


func _apply_anim_frame() -> void:
	if sprite == null or not anim_frames.has(cur_anim):
		return
	var a: Dictionary = anim_frames[cur_anim]
	var n: int = int(a["n"])
	var w: float = float(a["w"])
	var idx: int = int(anim_t) % n
	var t: Texture2D = a["tex"]
	# recortar el frame actual via AtlasTexture
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(idx * w, 0, w, float(t.get_height()))
	sprite.texture = at
	var sc: float = 44.0 / float(max(t.get_height(), 1))
	sprite.scale = Vector2(sc, sc)
	sprite.position = Vector2(0, -22)


func _process(delta: float) -> void:
	if anim_frames.is_empty():
		return
	# Reproducir la animacion actual segun su duracion (frames a 60fps)
	var n: int = int(anim_frames.get(cur_anim, {}).get("n", 1))
	anim_t += delta * 60.0
	if cur_anim in ["idle", "walk"]:
		if anim_t >= n: anim_t = 0.0
	elif anim_t >= n:
		anim_t = 0.0
		if cur_anim != "idle": play_anim("idle")
	_apply_anim_frame()


func setup(id: int) -> void:
	char_id = id
	var db: Dictionary = _load_db()
	for p in db["personajes"]:
		if int(p["id"]) == id:
			data = p
			break
	if data.is_empty():
		data = db["personajes"][5]  # fallback: Yusuke
	display_name = str(data.get("nombre", "PJ%d" % id))
	stun_max = int(data.get("stun_max", 48))
	hp_max = int(db["globales"]["hp_max"])
	mana_max = int(db["globales"]["mana_max"])
	# El ROM usa la MISMA velocidad para los 11 personajes (8 px/frame).
	# Los "grades" A/B/C/S de las guias web no existen en el codigo, asi que
	# no se aplican. Ver Fisica.gd.
	move_speed = PH.WALK_PX_FRAME * PH.FPS
	jump_force = PH.JUMP_PX_FRAME_1 * PH.FPS
	# comandos reales de este personaje
	motion.cargar_por_personaje(id)
	hp = hp_max
	mana = 0
	stun = stun_max
	# figura provisional: se usa si no hay hojas de animacion
	_build_placeholder()
	_mostrar_placeholder(not anim_frames.has("idle"))

	# cargar el sprite real del personaje (extraido del char select)
	_load_sprite(id)
	_load_anims()
	_update_bars()


func _load_sprite(id: int) -> void:
	if sprite == null:
		return
	# los sprites van en sprites/personajes/01_sensui.png .. 11_toguromenor.png
	var files := [
		"01_sensui", "02_jin", "03_itsuki", "04_genkai", "05_kuwabara", "06_yusuke",
		"07_kurama", "08_hiei", "09_chui", "10_toguromayor", "11_toguromenor",
	]
	var nm: String = files[clampi(id - 1, 0, files.size() - 1)]
	var path := "res://sprites/personajes/%s.png" % nm
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			sprite.texture = tex
			# escalar para que el personaje mida ~40px de alto
			var t: Texture2D = tex
			var sc: float = 44.0 / float(max(t.get_height(), 1))
			sprite.scale = Vector2(sc, sc)
			sprite.position = Vector2(0, -22)


func _grade_mul(g: String) -> float:
	match g:
		"S": return 1.30
		"A": return 1.15
		"B": return 1.0
		"C": return 0.90
		"D": return 0.80
		"E": return 0.70
	return 1.0


## --------------------------------------------------------------------------
## Apariencia provisional
##
## Los sprites reales del juego NO estan en el ROM (el propio director admite
## que se comprimieron por falta de VRAM), asi que de momento se dibuja una
## figura simple y legible. Sirve para probar la mecanica y los motions; el
## arte definitivo sale de las capturas de combate que hay en emuladores/anims/.
##
## Medidas: celda de 32x32 como el original, cuerpo de ~46 px sobre suelo.
## --------------------------------------------------------------------------

const COLOR_PJ := [
	Color(0.85, 0.30, 0.30),   # 1 Sensui   rojo
	Color(0.35, 0.55, 0.90),   # 2 Jin      azul
	Color(0.55, 0.85, 0.40),   # 3 Itsuki   verde
	Color(0.90, 0.70, 0.30),   # 4 Genkai   ambar
	Color(0.95, 0.55, 0.15),   # 5 Kuwabara naranja
	Color(0.40, 0.75, 0.85),   # 6 Yusuke   celeste
	Color(0.80, 0.45, 0.85),   # 7 Kurama   violeta
	Color(0.95, 0.35, 0.35),   # 8 Hiei     rojo fuerte
	Color(0.75, 0.85, 0.35),   # 9 Chui     oliva
	Color(0.60, 0.45, 0.35),   # 10 Toguro hermano mayor  marron
	Color(0.35, 0.30, 0.30),   # 11 Toguro hermano menor  gris oscuro
]


func _build_placeholder() -> void:
	# figura simple: cabeza, torso, brazo, piernas
	if get_node_or_null("Cuerpo") != null:
		return
	var col: Color = COLOR_PJ[clampi(char_id - 1, 0, 10)]
	var oscuro := col.darkened(0.35)

	var raiz := Node2D.new()
	raiz.name = "Cuerpo"
	add_child(raiz)

	_pieza(raiz, "piernaAtras", Vector2(-5, -16), Vector2(5, 16), oscuro)
	_pieza(raiz, "piernaDelante", Vector2(1, -16), Vector2(5, 16), col.darkened(0.15))
	_pieza(raiz, "torso", Vector2(-7, -34), Vector2(14, 18), col)
	_pieza(raiz, "brazo", Vector2(6, -33), Vector2(5, 12), col.darkened(0.2))
	_pieza(raiz, "cabeza", Vector2(-6, -46), Vector2(12, 12), col.lightened(0.25))
	_pieza(raiz, "cinta", Vector2(-6, -38), Vector2(12, 3), col.darkened(0.5))
	# sombra en el suelo, para leer donde esta el personaje
	_pieza(raiz, "sombra", Vector2(-8, -3), Vector2(16, 4), Color(0, 0, 0, 0.35))


func _pieza(padre: Node, nombre: String, pos: Vector2, tam: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.name = nombre
	r.color = col
	r.position = pos
	r.size = tam
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(r)


func _orientar_cuerpo() -> void:
	var raiz := get_node_or_null("Cuerpo")
	if raiz == null:
		return
	var s := -1.0 if facing < 0 else 1.0
	raiz.scale = Vector2(s, 1.0)


func _mostrar_placeholder(usar: bool) -> void:
	var sp := get_node_or_null("Sprite2D")
	if sp != null:
		sp.visible = not usar
	var raiz := get_node_or_null("Cuerpo")
	if raiz != null:
		raiz.visible = usar
		_orientar_cuerpo()


func can_super() -> bool:
	# Condicion verificada: HP < 111 (hp_debil) Y mana llena (Sensui: mana > 50)
	return hp < 111 and mana >= (50 if display_name == "Sensui" else mana_max)


func start_move(name: String) -> void:
	if is_knocked_down or (action != "idle" and action != "walk"):
		return
	move_data = MOVES.get(name, MOVES["light"])
	# comprobar mana suficiente
	if int(move_data.get("mana", 0)) > mana:
		return
	mana = max(0, mana - int(move_data.get("mana", 0)))
	action = name
	action_frame = 0
	action_total = int(move_data["startup"]) + int(move_data["active"]) + int(move_data["recovery"])
	has_hit_this_move = false
	#mapear el move a su animacion
	var amap := {
		"weak": "atkB", "stand_a": "atkA", "crouch_a": "crA", "light": "atkB",
		"crouch_b": "crA", "dash_b": "atkA", "throw": "throw",
		"reimu": "special", "super": "super",
	}
	play_anim(str(amap.get(name, "atkA")))


func take_damage(dmg: int, from_dir: int) -> void:
	if is_blocking:
		# bloqueo: chip minimo (no medido, usamos 0)
		hp = max(0, hp - 0)
		_update_bars()
		return
	hp = max(0, hp - dmg)
	stun = max(0, stun - dmg * 2)   # aproximacion: cada dmg quita stun x2
	velocity.x = from_dir * 70.0
	took_damage.emit(dmg)
	if hp == 0:
		is_knocked_down = true
		died.emit()
	elif stun == 0:
		_knockdown()
	_update_bars()


func _knockdown() -> void:
	is_knocked_down = true
	# al levantarse el stun vuelve al maximo (255), como el juego original
	await get_tree().create_timer(0.6).timeout
	is_knocked_down = false
	stun = stun_threshold
	_update_bars()


func gain_mana(hits_in_combo: int) -> void:
	# tabla real: recov por HIT (data/game_data.json)
	var recov: Dictionary = _load_db()["sistema_mana"]["recup_por_hit"]
	var gain: int = int(recov.get(str(hits_in_combo), 0))
	mana = min(mana_max, mana + gain)


static func _load_db() -> Dictionary:
	# load() devuelve Resource; forzamos Dictionary con JSON.parse_string
	var txt: String = FileAccess.get_file_as_string("res://data/game_data.json")
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _physics_process(delta: float) -> void:
	if is_knocked_down:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		move_and_slide()
		return

	# avance de la animacion del move
	if action != "idle" and action != "walk":
		action_frame += 1
		if action_frame >= action_total:
			action = "idle"
			action_frame = 0

	# --- MOVIMIENTO: pasos discretos de px/frame ---
	# El ROM NO usa velocidad continua. Mueve en pasos enteros de pixeles por
	# frame sobre una rejilla de 8 px (hace  andi.w #$fff8  sobre la posicion).
	# Por eso el original se ve "a saltitos" de 8 px, no deslizarse.
	#
	# Tabla de estados real del ROM ($D2A2):
	#   salto   : -16 px/frame, luego -8 px/frame
	#   caida   :  8 -> 16 -> 24 px/frame (escalones de 8)
	var vy_frame := 0.0            # px/frame, positivo hacia abajo

	if jumping:
		# fase 1: -16 px/frame durante JUMP_STAGE_FRAMES
		# fase 2: -8 px/frame hasta el apice
		var transcurridos := Engine.get_physics_frames() - _jump_start_frame
		if transcurridos < PH.JUMP_STAGE_FRAMES:
			vy_frame = PH.JUMP_PX_FRAME_1
		else:
			vy_frame = PH.JUMP_PX_FRAME_2
		# en el punto mas alto empieza a caer
		if vy_frame == PH.JUMP_PX_FRAME_2 and _vy_anterior == PH.JUMP_PX_FRAME_2:
			jumping = false
			_fall_frame = PH.FALL_FRAME_0      # arranca en 8 px/frame
		_vy_anterior = vy_frame
	elif not is_on_floor():
		# caida: acelera en escalones de 8 hasta el tope de 24
		_fall_frame = minf(_fall_frame + 8.0, PH.FALL_FRAME_MAX)
		vy_frame = _fall_frame
	else:
		_vy_anterior = 0.0
		_fall_frame = PH.FALL_FRAME_0

	velocity.y = vy_frame * PH.FPS

	# --- horizontal: 8 px por frame exactos, sin inercia ---
	# En el ROM no hay friccion: se para en seco.
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0 and action == "idle":
		velocity.x = dir * PH.WALK_PX_FRAME * PH.FPS
		facing = 1 if dir > 0 else -1
		_orientar_cuerpo()
	else:
		velocity.x = 0.0

	# --- salto ---
	if Input.is_action_just_pressed("move_up") and is_on_floor() and action == "idle":
		_jump_start_frame = Engine.get_physics_frames()
		_vy_anterior = PH.JUMP_PX_FRAME_1
		jumping = true

	# --- rejilla de 8 px, siempre (no solo en suelo) ---
	position.x = snappedf(position.x, float(PH.GRID))

	# --- parser de motions ---
	var _dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var _dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	motion.empujar_dir(_dx, _dy, facing)
	motion.avanzar()

	# ataque
	if Input.is_action_just_pressed("attack_a"):
		_choose_attack(true)
	elif Input.is_action_just_pressed("attack_b"):
		_choose_attack(false)
	elif Input.is_action_just_pressed("guard") and is_on_floor():
		is_blocking = true
	else:
		is_blocking = false

	if sprite:
		sprite.flip_h = facing < 0
	# animaciones de movimiento
	if action == "idle":
		if velocity.x != 0.0 and absf(velocity.x) > 5.0:
			play_anim("walk")
		else:
			play_anim("idle")
	move_and_slide()


func _choose_attack(strong: bool) -> void:
	# 1) PRIMERO se comprueba si el motion completa un especial.
	#    Los comandos vienen de data/comandos.json (verificados).
	var b := "A" if strong else "B"
	var esp := motion.buscar(b)
	if not esp.is_empty():
		iniciar_especial(str(esp.get("nombre", "")), b)
		return
	# 2) si no, golpe normal
	if is_cpu:
		return  # la IA llama a start_move directamente
	var grounded := is_on_floor()
	if not grounded:
		start_move("weak")
	elif strong:
		if Input.is_action_pressed("move_down"):
			start_move("crouch_a")
		elif Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			start_move("throw")
		else:
			start_move("stand_a")
	else:
		if Input.is_action_pressed("move_down"):
			start_move("crouch_b")
		else:
			start_move("light")


## Ejecuta un especial por su nombre.
## El dano sale de game_data.json; ahi esta en 0 con _confianza PENDIENTE,
## porque todavia no se ha medido. Ver DATOS_VERIFICADOS.md.
func iniciar_especial(nombre: String, boton: String) -> void:
	if nombre == "":
		return
	action = "special"
	action_frame = 0
	action_total = 12          # provisional: falta el frame data real
	last_special = nombre
	has_hit_this_move = false
	var base := _load_db()
	var d := 0
	for p in base.get("personajes", []):
		if int(p.get("id", 0)) == char_id:
			d = int(p.get("especiales", {}).get(nombre, 0))
			break
	special_damage = d
	play_anim("stand_a")       # provisional hasta tener las animaciones
	print("[%s] especial: %s  (boton %s, dano %d%s)"
		% [display_name, nombre, boton, d, "" if d != 0 else " <- SIN MEDIR"])
	# empuja el ataque
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * 40.0


## Devuelve true si el golpe conecta este frame.
func get_active_hitbox() -> Dictionary:
	if action == "idle" or action == "walk" or has_hit_this_move:
		return {}
	if move_data.is_empty():
		return {}
	var s: int = int(move_data["startup"])
	var e: int = s + int(move_data["active"])
	if action_frame < s or action_frame >= e:
		return {}
	has_hit_this_move = true
	var reach: float = 18.0
	return {"dmg": int(move_data["dmg"]), "offset": Vector2(reach * facing, 0), "hitstun": int(move_data["hitstun"])}


func _update_bars() -> void:
	# Las barras viven en la UILayer de Main y se actualizan ahi: en el juego
	# original no siguen al personaje, van fijas arriba.
	pass
