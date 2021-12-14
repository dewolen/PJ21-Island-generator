extends PhysicsAgent


var movement_speed := 4.0
var jump_velocity := 5.0
var mouse_sensitivity := 0.005
var look_dir_2d: Vector2 setget _set_look_dir_2d

onready var cam_orbit := $CameraOrbit
onready var water_tint := $CanvasLayer/WaterTint


func _set_disabled(new_value: bool) -> void:
	disabled = new_value
	$CollisionShapePill.disabled = disabled # prevents crashes


func _set_look_dir_2d(new_value: Vector2) -> void:
	look_dir_2d = Vector2(
			wrapf(new_value.x, 0.0, TAU),
			clamp(new_value.y, -PI / 2, PI / 2))
	cam_orbit.rotation = Vector3(-look_dir_2d.y, -look_dir_2d.x, 0.0)
	self.look_dir = -cam_orbit.transform.basis.z


func _ready() -> void:
	if not disabled:
		enter_first_person()


func _physics_process(_delta: float) -> void:
	if disabled: return
	
	var movement_dir_h := Vector2()
	if Input.is_action_pressed("move_forward"):
		movement_dir_h.y += 1
	if Input.is_action_pressed("move_backward"):
		movement_dir_h.y -= 1
	if Input.is_action_pressed("move_right"):
		movement_dir_h.x += 1
	if Input.is_action_pressed("move_left"):
		movement_dir_h.x -= 1
	movement_dir_h = movement_dir_h.normalized().rotated(-look_dir_2d.x)
	if Input.is_action_pressed("move_sprint"):
		movement_dir_h *= 1.5
	elif Input.is_action_pressed("move_walk"):
		movement_dir_h *= 0.5
	
	velocity.x = movement_dir_h.x * movement_speed
	velocity.z = -movement_dir_h.y * movement_speed
	
	var is_underwater: bool = translation.y < -0.6
	if (is_on_floor() or is_underwater) and Input.is_action_pressed("jump"):
		velocity.y = jump_velocity
	
	if not disabled:
		water_tint.visible = is_underwater
		if translation.y < -GenParams.max_height:
			velocity = Vector3.ZERO
			translation = Vector3(
				0, GenParams.landmass_array.get_height(0, 0) * 0.25, 0)


func _unhandled_input(event: InputEvent) -> void:
	if disabled: return
	
	# camera look-around
	if event is InputEventMouseMotion \
	and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		self.look_dir_2d += event.relative * mouse_sensitivity
	
	# mouse capturing
#	elif event is InputEventKey and event.pressed:
#		match event.scancode:
#			KEY_ESCAPE:
#				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#					# release the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#				else:
#					# capture the mouse
#					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func enter_first_person() -> void:
	$CameraOrbit/Camera.current = true
