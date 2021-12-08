extends Node


signal clear_geometry

var disabled := false
var area_hl: ArrayMesh
var sm_b: SpatialMaterial
var sm_c: SpatialMaterial
var sm_r: SpatialMaterial


func _ready() -> void:
	# generating the area highlight
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for i1 in 2:
		for i2 in 2:
			st.add_vertex(Vector3(i1, 0, i2))
			st.add_vertex(Vector3(i1, 1, i2))
			st.add_vertex(Vector3(0, i1, i2))
			st.add_vertex(Vector3(1, i1, i2))
			st.add_vertex(Vector3(i1, i2, 0))
			st.add_vertex(Vector3(i1, i2, 1))
	st.index()
	area_hl = st.commit()
	# generating the materials
	sm_b = SpatialMaterial.new()
	sm_b.albedo_color = Color.white
	sm_b.vertex_color_use_as_albedo = true
	sm_b.flags_unshaded = true
	sm_c = SpatialMaterial.new()
	sm_c.albedo_color = Color.mediumseagreen
	sm_c.vertex_color_use_as_albedo = true
	sm_c.flags_unshaded = true
	#sm_c.flags_transparent = true
	sm_r = SpatialMaterial.new()
	sm_r.albedo_color = Color.crimson
	sm_r.vertex_color_use_as_albedo = true
	sm_r.flags_unshaded = true


# draws a highlight around an area
func draw_box(pos: Vector3, size := Vector3.ONE, color := Color(), time := 0.0, node: Node = null) -> void:
	if disabled: return
	
	var mi := MeshInstance.new()
	mi.mesh = area_hl
	mi.translation = pos
	mi.scale = size
	
	if node:
		node.add_child(mi)
	else:
		get_tree().current_scene.add_child(mi)
	
	if color:
		var sm := SpatialMaterial.new()
		sm.albedo_color = color
		sm.vertex_color_use_as_albedo = true
		sm.flags_unshaded = true
		mi.material_override = sm
	else:
		mi.material_override = sm_b
	
	if time:
		yield(get_tree().create_timer(time), "timeout")
		mi.free()
	else:
		connect("clear_geometry", mi, "free")


# draws a highlight around an area defined by an AABB
func draw_box_aabb(aabb: AABB, color := Color(), time := 0.0, node: Node = null) -> void:
	if disabled: return
	
	var mi := MeshInstance.new()
	mi.mesh = area_hl
	mi.translation = aabb.position
	mi.scale = aabb.size
	
	if node:
		node.add_child(mi)
	else:
		get_tree().current_scene.add_child(mi)
	
	if color:
		var sm := SpatialMaterial.new()
		sm.albedo_color = color
		sm.vertex_color_use_as_albedo = true
		sm.flags_unshaded = true
		mi.material_override = sm
	else:
		mi.material_override = sm_b
	
	if time:
		yield(get_tree().create_timer(time), "timeout")
		mi.free()
	else:
		connect("clear_geometry", mi, "free")


func draw_cube(pos: Vector3, size := 0.1 , color := Color(), time := 0.0, node: Node = null) -> void:
	if disabled: return
	
	var mi := MeshInstance.new()
	var cm := CubeMesh.new()
	cm.size = Vector3.ONE * size
	mi.mesh = cm
	mi.translation = pos
	
	if node:
		node.add_child(mi)
	else:
		get_tree().current_scene.add_child(mi)
	
	if color:
		var sm := SpatialMaterial.new()
		sm.albedo_color = color
		sm.vertex_color_use_as_albedo = true
		sm.flags_unshaded = true
		#sm_c.flags_transparent = true
		mi.material_override = sm
	else:
		mi.material_override = sm_c
	
	if time:
		yield(get_tree().create_timer(time), "timeout")
		mi.free()
	else:
		connect("clear_geometry", mi, "free")


func draw_ray(from: Vector3, dir: Vector3, ray_length := 1.0, color := Color(), time := 0.0, node: Node = null) -> void:
	if disabled: return
	
	var ig := ImmediateGeometry.new()
	ig.begin(Mesh.PRIMITIVE_LINES)
	ig.set_color(color)
	ig.add_vertex(Vector3.ZERO)
	ig.add_vertex(dir.normalized() * ray_length)
	ig.end()
	ig.translation = from
	
	if node:
		node.add_child(ig)
	else:
		get_tree().current_scene.add_child(ig)
	
	if color:
		var sm := SpatialMaterial.new()
		sm.albedo_color = color
		sm.vertex_color_use_as_albedo = true
		sm.flags_unshaded = true
		ig.material_override = sm
	else:
		ig.material_override = sm_r
	
	if time:
		yield(get_tree().create_timer(time), "timeout")
		ig.free()
	else:
		connect("clear_geometry", ig, "free")


func clear_geometry() -> void:
	emit_signal("clear_geometry")
