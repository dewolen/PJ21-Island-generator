extends Spatial


signal camera_moved(new_pos)

export var camera_distance := 0.0 setget _set_camera_distance
export var freecam := false setget _set_freecam
export var disabled := false

var camera_speed := 10
var mouse_sensitivity := 0.005

onready var camera := $Camera
onready var debug_label_top_left := $DebugLabelTopLeft
onready var debug_label_top_right := $DebugLabelTopRight
onready var debug_label_bottom_left := $DebugLabelBottomLeft
onready var debug_label_bottom_right := $DebugLabelBottomRight



func _set_camera_distance(new_value: float) -> void:
	camera_distance = new_value
	if camera:
		camera.translation.z = camera_distance


func _set_freecam(new_value: bool) -> void:
	freecam = new_value
	set_process(freecam)


func _ready() -> void:
	_set_freecam(freecam)
	camera.translation.z = camera_distance


func _process(delta: float) -> void:
	# getting camera's movement
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var movement_dir := Vector3()
		if Input.is_key_pressed(KEY_W):
			movement_dir.z -= 1
		if Input.is_key_pressed(KEY_S):
			movement_dir.z += 1
		if Input.is_key_pressed(KEY_A):
			movement_dir.x -= 1
		if Input.is_key_pressed(KEY_D):
			movement_dir.x += 1
		if Input.is_key_pressed(KEY_Q):
			movement_dir.y += 1
		if Input.is_key_pressed(KEY_Z):
			movement_dir.y -= 1
		
		# move the camera
		if movement_dir:
			if Input.is_key_pressed(KEY_CONTROL):
				translate_object_local(movement_dir.normalized() * camera_speed * 0.2 * delta)
			elif Input.is_key_pressed(KEY_SHIFT):
				translate_object_local(movement_dir.normalized() * camera_speed * 5 * delta)
			else:
				translate_object_local(movement_dir.normalized() * camera_speed * delta)
			emit_signal("camera_moved", camera.global_transform.origin)


func _unhandled_input(event: InputEvent) -> void:
	if disabled: return
	
	# camera look-around
	if event is InputEventMouseMotion \
	and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate(Vector3.DOWN, event.relative.x * mouse_sensitivity)
		rotate_object_local(Vector3.LEFT, event.relative.y * mouse_sensitivity)
	
#	# mouse capturing
#	elif event is InputEventKey and event.pressed:
#		match event.scancode:
#			KEY_ESCAPE:
#				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#					# release the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#				else:
#					# capture the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# detect mouse button press
	elif event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				if event.pressed:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else: # BUTTON_LEFT released
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			BUTTON_WHEEL_UP:
				if freecam: return
				self.camera_distance -= 1
			BUTTON_WHEEL_DOWN:
				if freecam: return
				self.camera_distance += 1


func set_as_current() -> void:
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
