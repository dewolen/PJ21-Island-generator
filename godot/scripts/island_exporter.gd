extends WindowDialog


var object_name := "Island"
var mesh: Mesh = null

var _objcont := "" #.obj content
var _matcont := "" #.mat content
var _default_message: String # default message in the InfoLabel
var _export_directory: String

onready var file_dialog := $FileDialog
onready var info_label := $VBC/InfoLabel
onready var open_directory_button := $VBC/OpenDirectoryButton
onready var export_progress_bar := $VBC/ExportProgressBar


func _ready() -> void:
	_default_message = info_label.text
	open_directory_button.hide()


func _on_ExportButton_pressed() -> void:
#	file_dialog.add_filter("*.obj; Wavefront File")
	file_dialog.popup_centered()


func _on_OpenDirectoryButton_pressed() -> void:
	if not _export_directory:
		return
	OS.shell_open(_export_directory)


func _on_FileDialog_dir_selected(path: String) -> void:
	var time_dict := Time.get_datetime_dict_from_system()
	var folder_name := "island_export_{day}{month}{year}_{hour}{minute}{second}" \
		.format(time_dict)
	var full_folder_path := path.plus_file(folder_name)
	
	var meshes_container = get_tree().current_scene.get_node("TerrainMeshes")
	if not meshes_container is Node:
		return
	
	if meshes_container.get_child_count() == 0 \
	or meshes_container.get_child(0).name == "PlaceholderIsland":
		display_message("Generate an island first")
		return
	
	display_message("Exporting mesh to:\n[{path}]\n\nPlease wait" \
		.format({"path": full_folder_path}))
	yield(get_tree().create_timer(0.1), "timeout")
	
	get_aggregate_mesh(meshes_container.get_children(), true)
	generate_file_contents()
	
	
	
	var err := export_files_to(full_folder_path)
	if err:
		display_message("Export failiure, error code: {err}\nPath: [{path}]" \
			.format({"path": full_folder_path, "err": err}))
		return
	
	display_message("Mesh exported to:\n[{path}]" \
		.format({"path": full_folder_path}))
	display_open_export_directory_button(full_folder_path)


func get_aggregate_mesh(mi_array: Array, use_node_transform := true) -> Mesh:
	# creates a new mesh by connecting all given MeshInstance meshes
	
	var meshes := []
	var transforms := []
	var surface_count := 0 # max surface count
	for mi in mi_array:
		if not mi is MeshInstance:
			continue
		if mi.name.begins_with("Seabed"):
			continue
		meshes.append(mi.mesh)
		transforms.append(mi.global_transform)
		surface_count = max(mi.mesh.get_surface_count(), surface_count)
	
	var st := SurfaceTool.new()
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for im in meshes.size():
		# get surfaces and mesh info
#		for t in mesh.get_surface_count():
		var surface: Array = meshes[im].surface_get_arrays(0)
		var verts: PoolVector3Array = surface[ArrayMesh.ARRAY_VERTEX]
		var normals                 = surface[ArrayMesh.ARRAY_NORMAL]
#		var tangents                = surface[ArrayMesh.ARRAY_TANGENT]
		var colors                  = surface[ArrayMesh.ARRAY_COLOR]
		var UVs                     = surface[ArrayMesh.ARRAY_TEX_UV]
#		var UV2s                    = surface[ArrayMesh.ARRAY_TEX_UV2]
#		var bones                   = surface[ArrayMesh.ARRAY_BONES]
#		var weights                 = surface[ArrayMesh.ARRAY_WEIGHTS]
#		var indices                 = surface[ArrayMesh.ARRAY_INDEX]
		
		for iv in verts.size():
			if normals:
				st.add_normal(normals[iv])
			if colors:
				st.add_color(colors[iv])
			if UVs:
				st.add_uv(UVs[iv])
			if use_node_transform:
				st.add_vertex(transforms[im].xform(verts[iv]))
			else:
				st.add_vertex(verts[iv])
	
	st.index()
	return st.commit()


func generate_file_contents() -> void:
	# Based on a script by: mohammedzero43 (Xtremezero)
	# https://github.com/xtremezero/CSGExport-Godot
	if not mesh:
		print("No mesh to export!")
		return
	
	# variables
	_objcont = "" # .obj content
	_matcont = "" # .mat content
	var vertcount := 0
	
	# OBJ Headers
	_objcont += "# exported from island-generator by dewolen\n"
	_objcont += "# dewolen.itch.io/island-generator\n"
	_objcont += "mtllib " + object_name + ".mtl\n"
	_objcont += "o " + object_name + "\n"
	
	# blank material
	var blank_material := SpatialMaterial.new()
	blank_material.resource_name = "BlankMaterial"
	
	# get surfaces and mesh info
	for t in mesh.get_surface_count():
		var surface := mesh.surface_get_arrays(t)
		var verts: PoolVector3Array = surface[ArrayMesh.ARRAY_VERTEX]
		var normals                 = surface[ArrayMesh.ARRAY_NORMAL]
#		var tangents                = surface[ArrayMesh.ARRAY_TANGENT]
#		var colors                  = surface[ArrayMesh.ARRAY_COLOR]
		var UVs                     = surface[ArrayMesh.ARRAY_TEX_UV]
#		var UV2s                    = surface[ArrayMesh.ARRAY_TEX_UV2]
#		var bones                   = surface[ArrayMesh.ARRAY_BONES]
#		var weights                 = surface[ArrayMesh.ARRAY_WEIGHTS]
		var indices                 = surface[ArrayMesh.ARRAY_INDEX]
		
		var mat: SpatialMaterial = mesh.surface_get_material(t)
		if mat == null:
			mat = blank_material
		
		# add verticies
		for v in verts:
			_objcont += str("v ", v.x, " ", v.y, " ", v.z, "\n")
		
		# add UVs
		if UVs:
			for uv in UVs:
				_objcont += str("vt ", uv.x, " ", uv.y, "\n")
		elif normals:
			# normal data defined but no UV data, add three dummy UV coordinates
			_objcont += "vt 0 0\nvt 0 0\nvt 0 0\n"
		
		# add normals
		if normals:
			for n in normals:
				_objcont += str("vn ", n.x, " ", n.y, " ", n.z, "\n")
		
		# add surface
		_objcont += "g surface" + str(t) + "\n"
		
		# add material
		_objcont += "usemtl " + str(mat) + "\n"
		
		# add faces
		if indices: # indexed array
			var vstart     := 0
			var vert_index := vstart
			var uv_index   := 0
			var n_index    := 0
			if normals: # normals and maybe UVs:
				for face in indices.size() / 3:
					vert_index = vstart
					if UVs: uv_index = vstart # UV data defined
					n_index  = vstart
					_objcont += str( # vertex_index/texture_index/normal_index
						"f ", indices[vert_index]     + 1, "/", indices[uv_index]     + 1, "/", indices[n_index]     + 1,
						" ",  indices[vert_index + 1] + 1, "/", indices[uv_index + 1] + 1, "/", indices[n_index + 1] + 1,
						" ",  indices[vert_index + 2] + 1, "/", indices[uv_index + 2] + 1, "/", indices[n_index + 2] + 1,
						"\n")
					vstart += 3
			elif UVs: # UVs and no normals
				for face in indices.size() / 3:
					vert_index = vstart
					uv_index = vstart
					_objcont += str( # vertex_index/texture_index
						"f ", indices[vert_index]     + 1, "/", indices[uv_index]     + 1,
						" ",  indices[vert_index + 1] + 1, "/", indices[uv_index + 1] + 1,
						" ",  indices[vert_index + 2] + 1, "/", indices[uv_index + 2] + 1,
						"\n")
					vstart += 3
			else: # no UVs, no normals
				for face in indices.size() / 3:
					vert_index = vstart
					_objcont += str( # vertex_index
						"f ", indices[vert_index]     + 1,
						" ",  indices[vert_index + 1] + 1,
						" ",  indices[vert_index + 2] + 1,
						"\n")
					vstart += 3
		
		else: # non-indexed array
			var vstart     := 1 + vertcount
			var vert_index := vstart
			var uv_index   := 1
			var n_index    := 1
			if normals: # normals and maybe UVs:
				for face in verts.size() / 3:
					vert_index = vstart
					if UVs: uv_index = vstart # UV data defined
					n_index  = vstart
					_objcont += str( # vertex_index/texture_index/normal_index
						"f ", vert_index + 2, "/", uv_index + 2, "/", n_index + 2,
						" ",  vert_index + 1, "/", uv_index + 1, "/", n_index + 1,
						" ",  vert_index,     "/", uv_index,     "/", n_index,
						"\n")
					vstart += 3
			elif UVs: # UVs and no normals
				for face in verts.size() / 3:
					vert_index = vstart
					uv_index = vstart
					_objcont += str( # vertex_index/texture_index
						"f ", vert_index + 2, "/", uv_index + 2,
						" ",  vert_index + 1, "/", uv_index + 1,
						" ",  vert_index,     "/", uv_index,
						"\n")
					vstart += 3
			else: # no UVs, no normals
				for face in verts.size() / 3:
					vert_index = vstart
					_objcont += str( # vertex_index
						"f ", vert_index + 2,
						" ",  vert_index + 1,
						" ",  vert_index,
						"\n")
					vstart += 3
		
		# add number of vertices in this surface to total count
		vertcount += verts.size()
		
		# create materials for current surface
		_matcont += str("newmtl " + str(mat), "\n")
		_matcont += str("Kd ", mat.albedo_color.r, " ", mat.albedo_color.g, " ", mat.albedo_color.b, "\n")
#		_matcont += str("Ke ", mat.emission.r, " ", mat.emission.g, " ", mat.emission.b, "\n")
#		_matcont += str("Tf ", mat.transmission.r, " ", mat.transmission.g, " ", mat.transmission.b, "\n")
#		_matcont += str("d ", mat.albedo_color.a, "\n")


func export_files_to(path: String) -> int:
	var dir := Directory.new()
	if not dir.dir_exists(path):
		var err := dir.make_dir_recursive(path)
		if err:
			return err
	
	var file := File.new()
	# write to obj file
	var obj_file_path := path.plus_file(object_name) + ".obj"
	var err := file.open(obj_file_path, File.WRITE)
	if err:
		print("Error trying to save obj file: ", obj_file_path, " error code: ", err)
		return err
	file.store_string(_objcont)
	file.close()
	
	# write to mtl file
	var mtl_file_path := path.plus_file(object_name) + ".mtl"
	err = file.open(mtl_file_path, File.WRITE)
	if err:
		print("Error trying to save mtl file: ", mtl_file_path, " error code: ", err)
		return err
	file.store_string(_matcont)
	file.close()
	
	return OK


func display_message(msg := "") -> void:
	if not msg:
		info_label.text = _default_message
		return
	info_label.text = msg


func display_open_export_directory_button(path := "") -> void:
	if not path:
		open_directory_button.hide()
		return
	_export_directory = path
	open_directory_button.show()


func _on_IslandExporter_about_to_show() -> void:
	display_message() # reset the message to the default
