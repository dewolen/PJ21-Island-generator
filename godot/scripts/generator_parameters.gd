extends Node


const MAX_Y_RADIUS := 256
const CHUNK_SIZE := 32
const SINGLE_THREAD_PART_DELAY := 0.1

var radius := 256 setget _set_radius # mininum of CHUNK_SIZE
var max_height := 32.0 setget _set_max_height
var number_of_threads := ceil(radius as float / CHUNK_SIZE / 2.0)
var flatness_map_scale_pow := 1
var single_threaded := false

var landmass_array: Array3D
var flatness_map: Array2D
var noise_scale_curve := preload("res://resources/noise_scale_curve.tres")
var noise_offset_curve := preload("res://resources/noise_offset_curve.tres")
var noise_lut_curve := preload("res://resources/noise_lut_curve.tres")
var landmass_noise := OpenSimplexNoise.new()
var biome_noise := OpenSimplexNoise.new()
var generation_thread := Thread.new()
var generation_threads := []
var threads_finished: int
var progress_node: Control
var is_generating := false

onready var main_scene: Spatial = get_tree().current_scene


func _set_radius(new_value: int) -> void:
	if radius == new_value: return
	radius = new_value
	update_arrays()


func _set_max_height(new_value: float) -> void:
	if max_height == new_value: return
	max_height = clamp(new_value, 0, min(radius, MAX_Y_RADIUS))
	#max_height = clamp(new_value, 0, radius)


func _ready() -> void:
	update_arrays()
	_set_max_height(sqrt(radius))
	biome_noise.octaves = 2
	biome_noise.period = 100


func update_arrays() -> void:
	landmass_array = Array3D.new(radius, min(radius, MAX_Y_RADIUS), radius)
	flatness_map = Array2D.new(
			radius >> flatness_map_scale_pow,
			radius >> flatness_map_scale_pow,
			flatness_map_scale_pow)


func reset() -> void:
	for t in generation_threads:
		if t is Thread and t.is_active():
			t.wait_to_finish()
	generation_threads = []


func start_generation() -> void:
	if generation_thread.is_active(): return
	
	is_generating = true
	main_scene.set_interface_block(true)
	main_scene.pause_player()
	GenParams.reset()
	LandmassGenerator.reset()
	StructureGenerator.reset()
	PathfindingGenerator.reset()
	
	progress_node.begin_generation()
	if single_threaded:
		yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
		_start_generation_threaded(progress_node)
	else:
		generation_thread.start(self, "_start_generation_threaded", progress_node, Thread.PRIORITY_LOW)


func _start_generation_threaded(progress: Control) -> void:
	var step_fraction := 1.0 / 5.0
	
	# stage 1
	progress.set_overall_progress(0, "Generating main landmass")
	if single_threaded: yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
	LandmassGenerator.generate_terrain(progress)
	
	# stage 2
	progress.set_overall_progress(step_fraction * 1, "Calculating slope")
	if single_threaded: yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
	StructureGenerator.generate_flatness_map(progress)
	
	# stage 3
	progress.set_overall_progress(step_fraction * 2, "Generating paths")
	if single_threaded: yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
	PathfindingGenerator.generate_paths(progress)
	
	# stage 4
	progress.set_overall_progress(step_fraction * 3, "Placing structures")
	if single_threaded: yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
	StructureGenerator.generate_structures(progress)
	
	# stage 5
	progress.set_overall_progress(step_fraction * 4, "Building meshes")
	if single_threaded:
		yield(get_tree().create_timer(SINGLE_THREAD_PART_DELAY), "timeout")
		var chunks_in_r: int = radius / CHUNK_SIZE
		progress.max_part_progress = chunks_in_r * chunks_in_r * 4
		LandmassGenerator.generate_mesh_chunks(progress, -chunks_in_r, chunks_in_r)
	else:
		generation_threads.resize(number_of_threads)
		threads_finished = 0
		var num_of_chunks: int = radius * 2 / CHUNK_SIZE
		var chunks_per_thread: int = num_of_chunks / number_of_threads
		progress.set_max_part_progress(num_of_chunks * num_of_chunks)
		for i in number_of_threads:
			var t := Thread.new()
			generation_threads[i] = t
			t.start(self, "_generate_meshes_multithreaded",
					[progress,
					-(num_of_chunks / 2) + (i * chunks_per_thread),
					-(num_of_chunks / 2) + ((i + 1) * chunks_per_thread),
					t],
					#Thread.PRIORITY_HIGH)
					Thread.PRIORITY_NORMAL)
					#Thread.PRIORITY_LOW)
		# wait for all threads to finish generating the mesh
		while threads_finished != number_of_threads:
			pass
	LandmassGenerator.generate_height_collisions()
	
	# finishing
	progress.finish_generation()
	is_generating = false
	main_scene.set_interface_block(false)
	if not single_threaded:
		generation_thread.call_deferred("wait_to_finish")


#func _start_generation_threaded(progress: Control) -> void:
func _generate_meshes_multithreaded(data: Array) -> void:
	var progress: Control = data[0]
	var x_from: int = data[1]
	var x_to: int = data[2]
	var myself: Thread = data[3]
	
	LandmassGenerator.generate_mesh_chunks(progress, x_from, x_to)
	call_deferred("_thread_finished_generation", myself)


func _thread_finished_generation(thread: Thread) -> void:
	thread.wait_to_finish()
	threads_finished += 1


func randomize_seed() -> void:
	set_seed(randi())


func set_seed(new_seed: int) -> void:
	# make sure it's 32-bit
	new_seed = new_seed & 0xFFFFFFFF
	landmass_noise.seed = new_seed
	# shift the bits 4 to the left with wrap-around
	biome_noise.seed = ((new_seed << 4) & (~0xF)) | ((new_seed >> 28) & 0xF)
