extends RefCounted
class_name MotionInput
##
## Parser de comandos de entrada (notas de luchador).
##
## Implementa el reconocimiento de motions del juego original con los comandos
## VERIFICADOS en las fuentes externas (ver COMANDOS_MOVES_FUENTE.md).
##
## Notacion de direcciones, RELATIVAS al rival:
##     f  adelante        b  atras
##     d  abajo           u  arriba
##     df abajo+adelante  db abajo+atras
##     uf arriba+adelante ub arriba+atras
##
## Ejemplos reales:
##     d+df+f+A    dragon punch      (Genkai 昇龍拳)
##     f+d+f+A     quarter circle fw (Kurama 樹靈妖斬拳)
##     d+d+f+A     super de Sensui
##
## LENIENCIA: una diagonal sirve para su cardinal adyacente, como es habitual
## en el genero (un "df" cuenta como "d" o como "f").
##

## Ventana de entrada en frames. La original anda por 15-20; aqui algo mas
## generosa para poder probarlo a mano.
const VENTANA_FRAMES := 30

var _dirs: Array = []        ## historial de direcciones, la ultima al final
var _ultimo_cambio: Array = []
var _botones: Dictionary = {}
var _frame_actual: int = 0
var moves: Array = []


func _init() -> void:
	_dirs = []
	_ultimo_cambio = []
	_botones = {}


## Registra la direccion de este frame, en coordenadas absolutas de pantalla.
func empujar_dir(dx: int, dy: int, facing: int) -> void:
	var d := a_relativa(dx, dy, facing)
	# solo guardamos cuando CAMBIA: el historial debe ser la secuencia de
	# movimientos, no un registro por frame
	if _dirs.size() > 0 and d == _dirs[_dirs.size() - 1]:
		return
	if _dirs.size() > 0 and d == "n":
		return              # volver a neutro no cuenta como paso
	_dirs.append(d)
	_ultimo_cambio.append(_frame_actual)
	if _dirs.size() > 16:
		_dirs.remove_at(0)
		_ultimo_cambio.remove_at(0)


func empujar_boton(b: String) -> void:
	_botones[b] = _frame_actual


func avanzar() -> void:
	_frame_actual += 1
	_purgar()


func _purgar() -> void:
	while _dirs.size() > 0 and _frame_actual - int(_ultimo_cambio[0]) > VENTANA_FRAMES:
		_dirs.remove_at(0)
		_ultimo_cambio.remove_at(0)
	for b in _botones.keys():
		if _frame_actual - int(_botones[b]) > VENTANA_FRAMES:
			_botones.erase(b)


## convierte una direccion de pantalla en relativa al rival
static func a_relativa(dx: int, dy: int, facing: int) -> String:
	if dx == 0 and dy == 0:
		return "n"
	var f := facing if facing != 0 else 1
	if dy < 0:
		if dx == 0:
			return "u"
		return "uf" if dx * f > 0 else "ub"
	if dy > 0:
		if dx == 0:
			return "d"
		return "df" if dx * f > 0 else "db"
	return "f" if dx * f > 0 else "b"


## una direccion concreta cumple una casilla pedida (con leniencia de diagonal)
static func casilla_coincide(pedida: String, hecha: String) -> bool:
	if pedida == hecha:
		return true
	var diag := {"df": ["d", "f"], "db": ["d", "b"],
				"uf": ["u", "f"], "ub": ["u", "b"]}
	if diag.has(hecha) and diag[hecha].has(pedida):
		return true
	if diag.has(pedida) and diag[pedida].has(hecha):
		return true
	return false


func motion_ok(sec: Array) -> bool:
	if sec.is_empty():
		return false
	var n := sec.size()
	if _dirs.size() < n:
		return false
	for k in n:
		var p: String = sec[k]
		var h: String = _dirs[_dirs.size() - n + k]
		if not casilla_coincide(p, h):
			return false
	return true


## Devuelve el move cuyo motion + boton se acaba de completar, o {}.
func buscar(boton_presionado: String) -> Dictionary:
	for m in moves:
		if str(m.get("boton", "A")) != boton_presionado:
			continue
		if motion_ok(m.get("dirs", [])):
			return m
	return {}


## Carga los moves de un personaje desde data/comandos.json
func cargar_por_personaje(personaje_id: int, es_super: bool = false) -> void:
	var db := leer_json("res://data/comandos.json")
	var pj: Dictionary = db.get("personajes", {}).get(str(personaje_id), {})
	if es_super:
		moves = []
		var s = pj.get("super", null)
		if s != null:
			moves.append(s)
	else:
		moves = pj.get("especiales", [])


static func leer_json(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var p = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return p if p is Dictionary else {}


## Util para pruebas sin montar la escena.
##
## `boton_move` es el boton que exige el move; `boton_pulsado` el que se
## busca. Si difieren, el move NO debe activarse.
static func probar(pedida: Array, hecha: Array, boton_move: String = "A",
		boton_pulsado: String = "") -> bool:
	var b := boton_pulsado if boton_pulsado != "" else boton_move
	var m := MotionInput.new()
	m.moves = [{"dirs": pedida, "boton": boton_move, "nombre": "prueba"}]
	for d in hecha:
		m._dirs.append(d)
	return not m.buscar(b).is_empty()
