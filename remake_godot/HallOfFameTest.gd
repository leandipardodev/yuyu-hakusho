extends SceneTree
##
## Autotest de la ventana HALL OF FAME.
##     godot --headless --script HallOfFameTest.gd
##
## Verifica los datos exactos que se pidio (posiciones, nombres, estrellas,
## color amarillo, y que el confeti sea infinito), no que "se vea bien".
##

var fallos := 0
var pruebas := 0
var _pos_inicial: Array = []


func _init() -> void:
	print("=== autotest de HALL OF FAME ===")

	var hof := HallOfFame.new()
	hof.size = Vector2(320, 224)

	# --- datos exactos pedidos ---
	_eq("5 entradas", 5, HallOfFame.ENTRADAS.size())

	var esperado := [
		[1, "Adolin", 2],
		[2, "Kuusa", 1],
		[3, "Nomercy22", 1],
		[4, "N#ga", 1],
		[5, "Akara1996", 1],
	]
	for i in esperado.size():
		var e: Dictionary = HallOfFame.ENTRADAS[i]
		var exp: Array = esperado[i]
		_eq("puesto %d nombre" % exp[0], exp[1], str(e["nombre"]))
		_eq("puesto %d estrellas" % exp[0], exp[1 + 1], int(e["estrellas"]))

	_eq("total de estrellas", 6, _total_estrellas())

	# --- el pie exacto ---
	_eq("pie de texto", "HieiFM y Cacenariel sigan intentando", HallOfFame.PIE)

	# --- todas las estrellas amarillas ---
	_ok("color de estrella es amarillo",
			HallOfFame.COLOR_ESTRELLA.r > 0.9
			and HallOfFame.COLOR_ESTRELLA.g > 0.7
			and HallOfFame.COLOR_ESTRELLA.b < 0.3)

	# --- la estrella es un poligono de 5 puntas = 10 vertices ---
	_eq("estrella de 5 puntas", 10, hof._puntos_estrella(Vector2(50, 50), 5.5).size())

	# --- mantener START abre, soltar cierra ---
	hof.actualizar_hold(0.016, true)
	_ok("mantener START abre la ventana", hof.esta_abierto())

	hof.actualizar_hold(0.016, true)
	_ok("sigue abierta mientras se mantiene", hof.esta_abierto())

	hof.actualizar_hold(0.016, false)
	_ok("soltar START cierra la ventana", not hof.esta_abierto())

	# --- el confeti no se agota: siempre la misma cantidad ---
	hof.actualizar_hold(0.016, true)
	var n1: int = hof._confeti.size()
	_ok("hay confeti al abrir (%d)" % n1, n1 == HallOfFame.CANTIDAD_CONFETI)

	# avanzar muchos frames: los papelitos se reciclan, no se acumulan
	_pos_inicial = []
	for c in hof._confeti:
		_pos_inicial.append(c["pos"])
	for i in 600:
		hof._mover_confeti(0.016)
	var n2: int = hof._confeti.size()
	_eq("confeti sigue igual tras 600 frames (infinito, no crece)", n1, n2)

	# Tras 600 frames ningun papelito debe haber salido de la pantalla: eso
	# prueba que se reciclan al caer, en vez de acumularse fuera para siempre.
	# Se admite un voladizo de 4 px en los laterales: es lo que hace el
	# reciclado en _mover_confeti, para que el papel entre y salga del borde.
	const MARGEN := 4.0
	var desbordados := 0
	var fuera_de_rango := 0
	for c in hof._confeti:
		var p: Vector2 = c["pos"]
		if p.y > 224.0:
			desbordados += 1
		if p.x < -MARGEN or p.x > 320.0 + MARGEN:
			fuera_de_rango += 1
	_eq("ningun papelito se sale por abajo (se recicla)", 0, desbordados)
	_eq("ningun papelito se pierde por un lateral", 0, fuera_de_rango)

	# Y deben haberse MOVIDO: si la posicion inicial fuera igual que la final
	# tras 600 frames, el confeti estaria congelado.
	var movidos := 0
	for i in hof._confeti.size():
		var antes: Vector2 = _pos_inicial[i]
		var ahora: Vector2 = hof._confeti[i]["pos"]
		if ahora != antes:
			movidos += 1
	_ok("el confeti se mueve (%d/%d cambiaron de sitio)" % [movidos, hof._confeti.size()],
			movidos > hof._confeti.size() / 2)

	hof.free()

	print("")
	print("=== %d pruebas, %d fallos ===" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)


func _total_estrellas() -> int:
	var t := 0
	for e in HallOfFame.ENTRADAS:
		t += int(e["estrellas"])
	return t


func _ok(nombre: String, cond: bool) -> void:
	pruebas += 1
	if cond:
		print("  OK    " + nombre)
	else:
		fallos += 1
		print("  FALLA " + nombre)


func _eq(nombre: String, esperado, obtenido) -> void:
	pruebas += 1
	if esperado == obtenido:
		print("  OK    " + nombre)
	else:
		fallos += 1
		print("  FALLA " + nombre + "  esperado=%s obtenido=%s" % [esperado, obtenido])
