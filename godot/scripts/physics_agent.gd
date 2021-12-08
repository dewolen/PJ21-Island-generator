extends KinematicBody
class_name PhysicsAgent


var velocity: Vector3
var disabled := false
var gravity := -15.0
var look_dir: Vector3 setget _set_look_dir

onready var visuals: Spatial = $Visuals


func _set_look_dir(new_value: Vector3) -> void:
	look_dir = new_value
	var look_dir_h = look_dir
	look_dir_h.y = 0.0
	visuals.look_at(look_dir_h, Vector3.UP)


func _physics_process(delta: float) -> void:
	if disabled: return
	
	velocity.y += gravity * delta
	
	velocity = move_and_slide(velocity, Vector3.UP, true, 4, 0.872664)
	
	if is_on_floor():
		velocity.y = -0.01
