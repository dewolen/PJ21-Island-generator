extends Spatial


onready var player := $Player

var is_player_controlled := false


func _ready() -> void:
	GenParams.progress_node = $GenerationProgress
	GenParams.start_generation()


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
			KEY_G:
				pause_player()
				GenParams.start_generation()
			KEY_R:
				DebugGeometryDrawer.clear_geometry()
				pause_player()
				GenParams.randomize_seed()
				GenParams.start_generation()
			KEY_B:
				GenParams.landmass_array.debug_visualize_height_data()
			KEY_C:
				DebugGeometryDrawer.clear_geometry()
			KEY_F:
				var coords := (Vector2(
						player.translation.x, player.translation.z) * 4).floor()
				print("Slope at ", coords, ": ", StructureGenerator.get_slope(
						coords.x as int, coords.y as int))
			KEY_H:
				var coords := (Vector2(
						player.translation.x, player.translation.z) * 4).floor()
				print("Height at ", coords, ": ",
						GenParams.landmass_array.get_height(
						coords.x as int, coords.y as int))


func pause_player() -> void:
	if is_player_controlled:
		player.disabled = true


func _on_GenerationProgress_generation_finished() -> void:
	# signal deferred
	if is_player_controlled:
		player.disabled = false
	player.translation = Vector3(
			0,
			GenParams.landmass_array.get_height(0, 0) * 0.25,
			0)
