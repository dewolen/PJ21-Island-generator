extends Control


onready var sliders := $SlidersContainer
onready var click_blocker := $ClickBlocker
onready var first_person_cb := $SlidersContainer/HBC8/FirstPersonCB
onready var single_thread_cb := $SingleThreadCB
onready var export_mesh_button := $ExportMeshButton

onready var octaves_sh := sliders.get_node("HBC/OctavesHSlider")
onready var period_sh := sliders.get_node("HBC2/PeriodHSlider")
onready var persistence_sh := sliders.get_node("HBC3/PersistenceHSlider")
onready var lacunarity_sh := sliders.get_node("HBC4/LacunarityHSlider")
onready var max_height_sh := sliders.get_node("HBC5/MaxHeightHSlider")
onready var radius_pow_sh := sliders.get_node("HBC6/RadiusHSlider")
onready var buildings_sh := sliders.get_node("HBC9/BuildingsHSlider")
onready var paths_sh := sliders.get_node("HBC10/PathsHSlider")

onready var octaves_label := sliders.get_node("HBC/ValueLabel")
onready var period_label := sliders.get_node("HBC2/ValueLabel")
onready var persistence_label := sliders.get_node("HBC3/ValueLabel")
onready var lacunarity_label := sliders.get_node("HBC4/ValueLabel")
onready var max_height_label := sliders.get_node("HBC5/ValueLabel")
onready var radius_pow_label := sliders.get_node("HBC6/ValueLabel")
onready var buildings_label := sliders.get_node("HBC9/ValueLabel")
onready var paths_label := sliders.get_node("HBC10/ValueLabel")

onready var seed_line_edit := sliders.get_node("HBC11/SeedLineEdit")



func _ready() -> void:
	for c in sliders.get_children():
		for s in c.get_children():
			if s is Range:
				s.connect("value_changed", self, "_on_slider_value_changed")
	_on_slider_value_changed(0)
	GenParams.connect("seed_changed", self, "_on_GenParams_seed_changed")
	
	set_block(false)
	GenParams.randomize_seed()
	
	if OS.has_feature("HTML5"):
		# disable island mesh exports
		export_mesh_button.hide()
		# force single-threaded mode, needed when the HTML5 export type
		# is set to regular instead of threads
		single_thread_cb.pressed = true
		single_thread_cb.hide()
	
#	# preset 2
#	GenParams.radius = 256
#	octaves_sh.value = 5
#	period_sh.value = 65
#	persistence_sh.value = 0.1
#	lacunarity_sh.value = -6
#	max_height_sh.value = 0.83


func set_block(blocked: bool) -> void:
	click_blocker.visible = blocked


func _on_slider_value_changed(_value: float) -> void:
	GenParams.radius = pow(2, radius_pow_sh.value)
	radius_pow_label.text = str(GenParams.radius)
	GenParams.landmass_noise.octaves = octaves_sh.value
	octaves_label.text = str(GenParams.landmass_noise.octaves)
	GenParams.landmass_noise.period = period_sh.value * GenParams.radius * 0.6
	period_label.text = str(floor(GenParams.landmass_noise.period))
	GenParams.landmass_noise.persistence = persistence_sh.value
	persistence_label.text = str(GenParams.landmass_noise.persistence)
	GenParams.landmass_noise.lacunarity = lacunarity_sh.value
	lacunarity_label.text = str(GenParams.landmass_noise.lacunarity)
	GenParams.max_height = sqrt(GenParams.radius * max_height_sh.value) * 6.0
	max_height_label.text = str(floor(GenParams.max_height))
	StructureGenerator.number_of_buildings = GenParams.radius * buildings_sh.value / 10
	buildings_label.text = str(StructureGenerator.number_of_buildings)
	StructureGenerator.number_of_paths = GenParams.radius * paths_sh.value / 20
	paths_label.text = str(StructureGenerator.number_of_paths)


func _on_FirstPersonCB_toggled(button_pressed: bool) -> void:
	get_node("/root/Main").set_first_person(button_pressed)
	GenParams.main_scene.set_interface_block(button_pressed)


func _on_GenerateButton_pressed() -> void:
	seed_line_edit.text = str(GenParams.current_seed) # make sure to display correct seed
	GenParams.start_generation()


func _on_SmoothTerrainCB_toggled(button_pressed: bool) -> void:
	LandmassGenerator.smooth_terrain = button_pressed


func _on_SingleThreadCB_toggled(button_pressed: bool) -> void:
	GenParams.single_threaded = button_pressed


func _on_RandomizeSeedButton_pressed() -> void:
	GenParams.randomize_seed()


func _on_SeedLineEdit_text_changed(new_text: String) -> void:
	GenParams.current_seed = int(new_text)


func _on_GenParams_seed_changed(new_seed: int) -> void:
	if seed_line_edit.has_focus():
		return
	seed_line_edit.text = str(new_seed)


func _on_camera_mouse_captured() -> void:
	var focus_owner := get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()


func _on_ExportMeshButton_pressed() -> void:
	var exporter_window: Popup = export_mesh_button.get_node("IslandExporter")
	exporter_window.popup_centered()
