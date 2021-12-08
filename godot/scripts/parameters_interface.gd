extends Control


var auto_update := false

onready var sliders := $SlidersContainer
onready var octaves_sh := sliders.get_node("HBC/OctavesHSlider")
onready var period_sh := sliders.get_node("HBC2/PeriodHSlider")
onready var persistence_sh := sliders.get_node("HBC3/PersistenceHSlider")
onready var lacunarity_sh := sliders.get_node("HBC4/LacunarityHSlider")
onready var max_height_sh := sliders.get_node("HBC5/MaxHeightHSlider")


func _ready() -> void:
	for c in sliders.get_children():
		for s in c.get_children():
			if s is Range:
				s.connect("value_changed", self, "_on_slider_value_changed")
	_on_slider_value_changed(0)


func _on_slider_value_changed(_value: float) -> void:
	GenParams.landmass_noise.octaves = octaves_sh.value
	GenParams.landmass_noise.period = period_sh.value
	GenParams.landmass_noise.persistence = persistence_sh.value
	GenParams.landmass_noise.lacunarity = lacunarity_sh.value
	GenParams.max_height = max_height_sh.value * min(GenParams.radius, GenParams.MAX_Y_RADIUS)
	if auto_update:
		GenParams.start_generation()


func _on_AutoUpdateCB_toggled(button_pressed) -> void:
	auto_update = button_pressed
	if auto_update: _on_slider_value_changed(0)


func _on_FirstPersonCB_toggled(is_first_person) -> void:
	get_node("/root/Main/OrbitingCamera").disabled = is_first_person
	get_node("/root/Main/Player").disabled = not is_first_person
	if is_first_person:
		get_node("/root/Main/Player").enter_first_person()
	else:
		get_node("/root/Main/OrbitingCamera").set_as_current()
