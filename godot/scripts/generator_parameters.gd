extends Node


const MAX_Y_RADIUS := 32
const CHUNK_SIZE := 16

var radius := 512 setget _set_radius
var max_height := 32.0 setget _set_max_height
var number_of_threads := ceil(radius as float / CHUNK_SIZE / 2.0)

var landmass_array: Array3D
var noise_scale_curve := preload("res://resources/noise_scale_curve.tres")
var noise_offset_curve := preload("res://resources/noise_offset_curve.tres")
var noise_lut_curve := preload("res://resources/noise_lut_curve.tres")
var landmass_noise := OpenSimplexNoise.new()
var generation_thread := Thread.new()
var generation_threads := []
var threads_finished: int
var progress_node: Control

#onready var gridmap: GridMap = get_node("/root/Main/GridMap")


func _set_radius(new_value: int) -> void:
	radius = new_value
	if max_height > radius:
		_set_max_height(radius)


func _set_max_height(new_value: float) -> void:
	max_height = clamp(new_value, 0, min(radius, MAX_Y_RADIUS))


func _ready() -> void:
	_set_max_height(radius / 2.0)
	landmass_array = Array3D.new(radius, min(radius, MAX_Y_RADIUS), radius)


func start_generation() -> void:
	if generation_thread.is_active(): return
	progress_node.begin_generation()
	generation_thread.start(GenParams, "_start_generation_threaded", progress_node, Thread.PRIORITY_LOW)


func _start_generation_threaded(progress: Control) -> void:
	var step_fraction := 1.0 / 3.0
	# stage 1
	LandmassGenerator.generate_terrain(progress)
	progress.set_overall_progress(step_fraction * 1)
	# stage 2
	StructureGenerator.generate_structures(progress)
	progress.set_overall_progress(step_fraction * 2)
	# stage 3
	LandmassGenerator.delete_old_chunk_meshes()
	generation_threads.resize(number_of_threads)
	threads_finished = 0
	var r16: int = GenParams.radius / 16
	var r16foreach: int = r16 / number_of_threads
	progress.set_max_part_progress(r16 * r16 * 4)
	for i in number_of_threads:
		var t := Thread.new()
		generation_threads[i] = t
		t.start(GenParams, "_generate_multithreaded",
				[progress,
				-r16 + (i * 2 * r16foreach),
				-r16 + ((i + 1) * 2 * r16foreach),
				t],
				Thread.PRIORITY_LOW)
	# wait for all threads to finish generating the mesh
	while threads_finished != number_of_threads: pass
	progress.set_overall_progress(step_fraction * 3)
	LandmassGenerator.generate_height_collisions()
	# finishing
	progress.finish_generation()
	generation_thread.call_deferred("wait_to_finish")


#func _start_generation_threaded(progress: Control) -> void:
func _generate_multithreaded(data: Array) -> void:
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
	landmass_noise.seed = randi()
