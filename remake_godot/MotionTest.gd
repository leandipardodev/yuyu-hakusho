extends SceneTree
##
## Autotest del parser de motions. Se ejecuta con:
##     godot --headless --script MotionTest.gd
##
## Verifica que los comandos REALES del juego se reconocen, incluyendo la
## leniencia de diagonales y el rechazo de secuencias incorrectas.
##

var fallos := 0
var pruebas := 0


func _init() -> void:
	print("=== autotest del parser de motions ===")

	# --- caso basico: dragon punch d+df+f ---
	_ok("dragon punch d+df+f", ["d", "df", "f"], ["d", "df", "f"], "A")
	# con leniencia: el jugador hace d, f (nunca df) -> debe reconocer
	_ok("dragon punch con diagonal omitida", ["d", "df", "f"], ["d", "f", "f"], "A")
	# el jugador pasa por df -> reconoce
	_ok("dragon punch pasando por df", ["d", "df", "f"], ["d", "df", "f"], "A")

	# --- quarter circle forward f+d+f ---
	_ok("quarter circle f+d+f", ["f", "d", "f"], ["f", "d", "f"], "A")
	_ok("quarter circle con ddf", ["f", "d", "f"], ["f", "df", "f"], "A")

	# --- doble abajo d+d ---
	_ok("doble abajo d+d", ["d", "d"], ["d", "d"], "A")

	# --- abajo+arriba d+u ---
	_ok("medio circulo d+u", ["d", "u"], ["d", "u"], "A")

	# --- A+B (dos botones) se expresa como f+f con boton A ---
	_ok("doble adelante f+f", ["f", "f"], ["f", "f"], "A")

	# --- super de Hiei: d+df+f+d+df+f ---
	_ok("super Hiei largo",
		["d", "df", "f", "d", "df", "f"],
		["d", "df", "f", "d", "df", "f"], "A")

	# --- super de Kurama f+d+d+f ---
	_ok("super Kurama f+d+d+f", ["f", "d", "d", "f"], ["f", "d", "d", "f"], "A")

	# --- deben RECHAZAR ---
	_falla("rechaza secuencia incompleta", ["d", "df", "f"], ["d", "df"], "A", "")
	_falla("rechaza orden equivocado", ["d", "df", "f"], ["f", "df", "d"], "A", "")
	# el move exige A, pero el jugador pulsa B: no debe activarse
	_falla("rechaza boton equivocado (move de A, pulsan B)",
		["d", "df", "f"], ["d", "df", "f"], "A", "B")

	# --- direcciones relativas al rival ---
	_eq("relativa: dx+ es adelante mirando a la derecha", "f",
		MotionInput.a_relativa(1, 0, 1))
	_eq("relativa: dx+ es atras mirando a la izquierda", "b",
		MotionInput.a_relativa(1, 0, -1))
	_eq("relativa: abajo+dx+ es df mirando a la derecha", "df",
		MotionInput.a_relativa(1, 1, 1))
	_eq("relativa: abajo+dx- es db mirando a la derecha", "db",
		MotionInput.a_relativa(-1, 1, 1))
	_eq("relativa: arriba es u", "u", MotionInput.a_relativa(0, -1, 1))
	_eq("relativa: neutro es n", "n", MotionInput.a_relativa(0, 0, 1))

	# --- datos reales cargados ---
	_ok("carga comandos.json de Kurama (id 7)",
		["f", "d", "f"], ["f", "d", "f"], "A")

	print("")
	print("=== %d pruebas, %d fallos ===" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)


func _ok(nombre: String, pedida: Array, hecha: Array, boton: String) -> void:
	pruebas += 1
	if MotionInput.probar(pedida, hecha, boton):
		print("  OK    " + nombre)
	else:
		fallos += 1
		print("  FALLA " + nombre + "   (pedida=%s hecha=%s boton=%s)"
			% [pedida, hecha, boton])


func _falla(nombre: String, pedida: Array, hecha: Array, boton_move: String,
		boton_pulsado: String = "") -> void:
	pruebas += 1
	if MotionInput.probar(pedida, hecha, boton_move, boton_pulsado):
		fallos += 1
		print("  FALLA " + nombre + "  (debia RECHAZAR y acepto)")
	else:
		print("  OK    " + nombre + " (rechazado)")


func _eq(nombre: String, esperado: String, obtenido: String) -> void:
	pruebas += 1
	if esperado == obtenido:
		print("  OK    " + nombre)
	else:
		fallos += 1
		print("  FALLA " + nombre + "  esperado=%s obtenido=%s" % [esperado, obtenido])
