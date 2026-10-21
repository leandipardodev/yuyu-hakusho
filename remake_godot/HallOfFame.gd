extends Control
class_name HallOfFame
##
## Ventana de HALL OF FAME del remake.
##
## Se muestra mientras se MANTENGA presionado START y se cierra al soltarlo.
## While visible: confeti infinito cayendo por detras del panel.
##
## Las estrellas se dibujan a mano con `_draw()` en vez de usar el caracter
## Unicode de estrella: el tema por defecto de Godot no lo trae, y con
## ImageTexture seria mas pesado que un poligono de 10 vertices. Asi el
## amarillo es EXACTO y no depende de la fuente.
##

## Entradas. `estrellas` es un entero, no un texto: el color lo pone el
## codigo, para que todas salgan amarillas por definicion.
const ENTRADAS := [
	{"puesto": 1, "nombre": "Adolin", "estrellas": 2},
	{"puesto": 2, "nombre": "Kuusa", "estrellas": 1},
	{"puesto": 3, "nombre": "Nomercy22", "estrellas": 1},
	{"puesto": 4, "nombre": "N#ga", "estrellas": 1},
	{"puesto": 5, "nombre": "Akara1996", "estrellas": 1},
]

const PIE := "HieiFM y Cacenariel sigan intentando"

## Todas las estrellas amarillas. Un solo color, sin excepciones.
const COLOR_ESTRELLA := Color(1.0, 0.85, 0.1)
const COLOR_ESTRELLA_BORDE := Color(0.75, 0.5, 0.0)

const COLOR_TITULO := Color(1.0, 0.9, 0.35)
const COLOR_NOMBRE := Color(1, 1, 1)
const COLOR_PUESTO := Color(0.85, 0.8, 0.6)
const COLOR_PIE := Color(0.9, 0.85, 0.7)
## Panel opaco: el fondo del juego se transparentaba y hacia ruido.
const COLOR_PANEL_BG := Color(0.06, 0.05, 0.12, 1.0)
const COLOR_PANEL_BORDE := Color(0.75, 0.6, 0.15)

## Paleta del confeti: calida, del mismo tono que las estrellas.
const COLORES_CONFETI := [
	Color(1.0, 0.85, 0.15),   # amarillo
	Color(1.0, 0.95, 0.55),   # crema
	Color(1.0, 0.55, 0.15),   # naranja
	Color(0.95, 0.85, 0.25),  # oro
	Color(1.0, 1.0, 1.0),     # blanco
	Color(0.9, 0.75, 0.35),   # arena
]

## Cuantos papelitos hay vivos a la vez. Es "infinito" en el sentido de que
## se recyclean sin parar: no se acumulan ni se agotan.
const CANTIDAD_CONFETI := 70

## Simula el HOLD de START. Empezar a 0 evita el primer salto.
var _fuerza_hold: float = 0.0

var _confeti: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rellenar_confeti()
	visible = false


func abrir() -> void:
	# Rellena si falta, NO solo cuando estaba oculta. Al crear el nodo ya viene
	# visible=true, así que condicionar por `not visible` dejaba el confeti
	# vacio para siempre.
	if _confeti.is_empty():
		_rellenar_confeti()
	visible = true


func cerrar() -> void:
	visible = false


func esta_abierto() -> bool:
	return visible


## Mantiene la ventana abierta mientras se pulse START.
## Se llama desde _process de Main.
func actualizar_hold(delta: float, pulsado: bool) -> void:
	if pulsado:
		_fuerza_hold += delta
		abrir()
	else:
		_fuerza_hold = 0.0
		cerrar()


func _rellenar_confeti() -> void:
	_confeti.clear()
	var tam := get_rect().size
	if tam.x <= 0.0:
		tam = Vector2(320, 224)
	for i in CANTIDAD_CONFETI:
		_confeti.append({
			"pos": Vector2(randf() * tam.x, randf() * tam.y),
			"vel": 26.0 + randf() * 44.0,
			"deriva": (randf() - 0.5) * 22.0,
			"ancho": 2.0 + int(randf() * 3.0),
			"alto": 3.0 + int(randf() * 3.0),
			"color": COLORES_CONFETI[randi() % COLORES_CONFETI.size()],
		})


func _process(delta: float) -> void:
	if not visible:
		return
	_mover_confeti(delta)
	queue_redraw()


func _mover_confeti(delta: float) -> void:
	var alto := get_rect().size.y
	if alto <= 0.0:
		alto = 224.0
	var ancho := get_rect().size.x
	if ancho <= 0.0:
		ancho = 320.0
	for c in _confeti:
		var p: Vector2 = c["pos"]
		p.y += float(c["vel"]) * delta
		p.x += float(c["deriva"]) * delta
		# reciclado: al salir por abajo vuelve arriba por una x nueva. Por eso
		# nunca se acaba el confeti.
		if p.y > alto:
			p.y = -float(c["alto"])
			p.x = randf() * ancho
		# el viento tambien puede sacar un papelito por un lateral: hay que
		# devolverlo al otro lado o se pierde y la pantalla se queda vacia.
		if p.x < -4.0:
			p.x = ancho + 4.0
		elif p.x > ancho + 4.0:
			p.x = -4.0
		c["pos"] = p


func _draw() -> void:
	var r := get_rect().size
	var m := 6.0
	var panel := Rect2(m, m, r.x - m * 2.0, r.y - m * 2.0)

	# velo detras del panel: oscurece la arena para que el menu mande
	draw_rect(Rect2(0, 0, r.x, r.y), Color(0, 0, 0, 0.75))
	draw_rect(panel, COLOR_PANEL_BG)
	draw_rect(panel, COLOR_PANEL_BORDE, false, 2.0)

	_dibujar_confeti()

	var f := ThemeDB.fallback_font

	# titulo. Los 18 px de fuente ocupan ~26 de alto, asi que la linea de
	# base va un poco por debajo del borde superior del panel.
	var cx := r.x * 0.5
	var y_titulo := panel.position.y + 20.0
	dibujar_texto_centrado(f, "HALL OF FAME", cx, y_titulo, 18, COLOR_TITULO)

	# linea bajo el titulo
	var ly := panel.position.y + 32.0
	draw_line(Vector2(panel.position.x + 12.0, ly), Vector2(panel.end.x - 12.0, ly),
			COLOR_PANEL_BORDE, 1.0)

	# entradas
	var y := ly + 10.0
	var paso := 26.0
	var x0 := panel.position.x + 16.0

	for e in ENTRADAS:
		var puesto := int(e["puesto"])
		var nombre := str(e["nombre"])
		var estrellas := int(e["estrellas"])

		# numero de puesto
		dibujar_texto(f, "%d" % puesto, Vector2(x0, y), 12, COLOR_PUESTO)

		# nombre
		var x_nombre := x0 + 16.0
		dibujar_texto(f, nombre, Vector2(x_nombre, y), 12, COLOR_NOMBRE)

		# estrellas, todas amarillas, separadas 12 px
		var x_est := x_nombre + 104.0
		var cy := y - 4.0
		for s in estrellas:
			_dibujar_estrella(Vector2(x_est + s * 12.0, cy), 5.5, COLOR_ESTRELLA)

		y += paso

	# pie
	dibujar_texto_centrado(f, PIE, r.x * 0.5, panel.end.y - 20.0, 10, COLOR_PIE)


## Poligono de estrella de 5 puntas. 10 vertices alternando radio exterior e
## interior, en angulos de -90 grados para que apunte hacia arriba.
func _puntos_estrella(centro: Vector2, radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		var r: float = radio if i % 2 == 0 else radio * 0.45
		pts.append(centro + Vector2(cos(ang) * r, sin(ang) * r))
	return pts


func _dibujar_estrella(centro: Vector2, radio: float, color: Color) -> void:
	var pts := _puntos_estrella(centro, radio)
	draw_colored_polygon(pts, color)
	draw_polyline(_pts_cerrados(pts), COLOR_ESTRELLA_BORDE, 1.0)


func _pts_cerrados(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	if out.size() > 0:
		out.append(out[0])
	return out


func _dibujar_confeti() -> void:
	for c in _confeti:
		var p: Vector2 = c["pos"]
		draw_rect(Rect2(p, Vector2(float(c["ancho"]), float(c["alto"]))), c["color"])


func dibujar_texto(f: Font, txt: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(f, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0, 0, 0, 0.85))
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func dibujar_texto_centrado(f: Font, txt: String, cx: float, y: float, size: int, color: Color) -> void:
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	dibujar_texto(f, txt, Vector2(cx - w * 0.5, y), size, color)
