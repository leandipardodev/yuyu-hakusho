extends SceneTree
##
## Renderiza la ventana HALL OF FAME a PNG para revisarla a ojo.
##     godot --script RenderHallOfFame.gd
##

func _init() -> void:
	var hof := HallOfFame.new()
	hof.size = Vector2(320, 224)
	get_root().add_child(hof)

	# _ready() es diferido: hay que dejar pasar un frame antes de tocar nada,
	# o el confeti todavia no esta lleno y sale una ventana vacia.
	await process_frame
	await process_frame

	hof.abrir()
	# 3 segundos de caida para que el confeti quede bien repartido
	for i in 180:
		hof._mover_confeti(0.016)
	hof.queue_redraw()

	await process_frame
	await process_frame

	print("confeti visible: %d" % hof._confeti.size())
	var img := get_root().get_texture().get_image()
	var err := img.save_png("user://hof_ventana.png")
	print("guardado: %s (err=%d)" % [ProjectSettings.globalize_path("user://hof_ventana.png"), err])
	print("tamanio: %s" % img.get_size())

	# cuantos colores distintos hay: si sale 1, no se dibuja nada
	var distintos := {}
	for x in range(0, 320, 2):
		for y in range(0, 224, 2):
			distintos[img.get_pixel(x, y)] = true
	print("colores distintos: %d" % distintos.size())
	quit(0)
