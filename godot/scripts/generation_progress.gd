extends Control


signal generation_finished

onready var panel := $PanelContainer
onready var overall_pb := $PanelContainer/VBC/OverallPB
onready var current_pb := $PanelContainer/VBC/CurrentPartPB
onready var desc_label := $PanelContainer/VBC/DescriptionLabel

var current_part_progress: int
var max_part_progress: int


func _ready() -> void:
	panel.hide()


func begin_generation() -> void:
	overall_pb.value = 0.0
	current_pb.value = 0.0
	current_part_progress = 0
	panel.show()


func finish_generation() -> void:
	panel.hide()
	emit_signal("generation_finished")


func set_overall_progress(percentage: float, description := "") -> void:
	overall_pb.set_deferred("value", percentage)
	desc_label.set_deferred("text", description)


func set_part_progress(percentage: float) -> void:
	current_pb.set_deferred("value", percentage)


func add_to_part_progress() -> void:
	call_deferred("_add_to_part_progress_main")


func _add_to_part_progress_main() -> void:
	current_part_progress += 1
	current_pb.value = current_part_progress as float / max_part_progress


func set_max_part_progress(new_value: int) -> void:
	max_part_progress = new_value
