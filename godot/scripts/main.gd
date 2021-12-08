extends Spatial


onready var player := $Player


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
				player.disabled = true
				GenParams.start_generation()
			KEY_R:
				DebugGeometryDrawer.clear_geometry()
				player.disabled = true
				GenParams.randomize_seed()
				GenParams.start_generation()
			KEY_V:
				GenParams.landmass_array.debug_visualize_data()
			KEY_B:
				GenParams.landmass_array.debug_visualize_height_data()
			KEY_C:
				DebugGeometryDrawer.clear_geometry()


func _on_GenerationProgress_generation_finished() -> void:
	# signal deferred
	player.disabled = false
	player.translation = Vector3(
			0,
			GenParams.landmass_array.get_height(0, 0) * 0.25,
			0)
