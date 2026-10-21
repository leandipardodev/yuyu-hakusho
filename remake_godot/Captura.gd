extends SceneTree
##
## Captura el juego y vuelca el estado de los luchadores.
##
var _n := 0
var _escena: Node = null


func _init() -> void:
	print("=== captura + diagnostico ===")


func _process(_delta: float) -> bool:
	_n += 1
	if _n == 3:
		var e = load("res://Main.tscn")
		if e == null:
			print("no encuentro Main.tscn")
			quit(1)
			return true
		_escena = e.instantiate()
		root.add_child(_escena)
		print("escena cargada")
	if _n < 40:
		return false

	print("--- nodos ---")
	_volcar(root, 0)

	print("--- luchadores ---")
	var f1 = _escena.get_node_or_null("Fighter1")
	var f2 = _escena.get_node_or_null("Fighter2")
	for f in [f1, f2]:
		if f == null:
			print("  (nulo)")
			continue
		print("  %s  pos=%s  visible=%s" % [f.name, str(f.global_position), str(f.visible)])
		var sp = f.get_node_or_null("Sprite2D")
		if sp == null:
			print("     sin Sprite2D")
		else:
			print("     Sprite2D pos=%s scale=%s visible=%s tex=%s"
				% [str(sp.position), str(sp.scale), str(sp.visible),
				   "NULL" if sp.texture == null else "%dx%d" % [sp.texture.get_width(), sp.texture.get_height()]])

	var dbg = _escena.get_node_or_null("UILayer/Debug")
	var inf = _escena.get_node_or_null("UILayer/Info")
	print("Debug label : ", "NULO" if dbg == null else str(dbg.text))
	print("Info label  : ", "NULO" if inf == null else str(inf.text))
	print("fighter1 pos: ", str(f1.global_position), " vel=", str(f1.velocity))

	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		print("sin imagen del viewport")
		quit(1)
		return true
	img.save_png("res://capturas/cap_00.png")
	print("captura %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
	return true


func _volcar(n: Node, prof: int) -> void:
	var pad = "  ".repeat(prof)
	var extra := ""
	if n is Sprite2D:
		extra = "  tex=%s" % ("NULL" if n.texture == null else
			"%dx%d" % [n.texture.get_width(), n.texture.get_height()])
	if n is ColorRect:
		extra = "  color=%s rect=%s" % [str(n.color), str(n.get_rect())]
	print("%s%s (%s)%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_volcar(c, prof + 1)

