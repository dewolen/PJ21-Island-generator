extends Spatial


onready var player := $Player

var is_player_controlled := false

onready var gen_params_interface := $SlidersContainer
onready var generation_progress := $GenerationProgress
onready var orbiting_camera := $OrbitingCamera


func _ready() -> void:
	GenParams.progress_node = generation_progress
	#GenParams.start_generation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.scancode:
#			KEY_ESCAPE:
#				# mouse capturing
#				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#					# release the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#				else:
#					# capture the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			KEY_H:
				gen_params_interface.visible = not gen_params_interface.visible
				generation_progress.visible = gen_params_interface.visible
			KEY_G:
				GenParams.start_generation()
#			KEY_R:
#				GenParams.randomize_seed()
#				GenParams.start_generation()
			KEY_F:
				set_first_person(not is_player_controlled)
				set_interface_block(is_player_controlled)
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
	gen_params_interface.first_person_cb.pressed = enable
	is_player_controlled = enable
	orbiting_camera.disabled = is_player_controlled
	set_player_pause(not is_player_controlled)
	
	# enable correct camera
	if is_player_controlled:
		player.enter_first_person()
	else:
		orbiting_camera.set_as_current()


func set_player_pause(paused: bool) -> void:
	if GenParams.is_generating:
		player.disabled = true
		return
	if is_player_controlled:
		player.disabled = paused


func set_interface_block(blocked: bool) -> void:
	gen_params_interface.set_block(blocked)


func _on_GenerationProgress_generation_finished() -> void:
	# signal deferred
	set_player_pause(false)
	player.translation = Vector3(
			0, GenParams.landmass_array.get_height(0, 0) * 0.25, 0)
