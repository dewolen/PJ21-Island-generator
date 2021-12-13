extends Spatial


onready var player := $Player

var is_player_controlled := false

onready var gen_params_interface := $SlidersContainer
onready var generation_progress := $GenerationProgress


func _ready() -> void:
	GenParams.progress_node = generation_progress
	#GenParams.start_generation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_ESCAPE:
				# mouse capturing
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					# release the mouse
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					# capture the mouse
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			KEY_H:
				gen_params_interface.visible = not gen_params_interface.visible
				generation_progress.visible = gen_params_interface.visible
			KEY_G:
				GenParams.start_generation()
			KEY_R:
				GenParams.randomize_seed()
				GenParams.start_generation()
			KEY_F:
				set_first_person(not is_player_controlled)
#				GenParams.start_generation()
#			KEY_B:
#				GenParams.landmass_array.debug_visualize_height_data()
#			KEY_C:
#				DebugGeometryDrawer.clear_geometry()
#			KEY_F:
#				var coords := (Vector2(
#						player.translation.x, player.translation.z) * 4).floor()
#				print("Slope at ", coords, ": ", StructureGenerator.get_slope(
#						coords.x as int, coords.y as int))
#			KEY_J:
#				var coords := (Vector2(
#						player.translation.x, player.translation.z) * 4).floor()
#				print("Height at ", coords, ": ",
#						GenParams.landmass_array.get_height(
#						coords.x as int, coords.y as int))


func set_first_person(enable: bool) -> void:
	is_player_controlled = enable
	var camera := $OrbitingCamera
	camera.disabled = is_player_controlled
	player.disabled = not is_player_controlled or GenParams.is_generating
	if is_player_controlled:
		player.enter_first_person()
	else:
		camera.set_as_current()
	gen_params_interface.first_person_cb.pressed = enable


func pause_player() -> void:
	if is_player_controlled:
		player.disabled = true


func set_interface_block(blocked: bool) -> void:
	gen_params_interface.set_block(blocked)


func _on_GenerationProgress_generation_finished() -> void:
	# signal deferred
	if is_player_controlled:
		player.disabled = false
	player.translation = Vector3(
			0, GenParams.landmass_array.get_height(0, 0) * 0.25, 0)
