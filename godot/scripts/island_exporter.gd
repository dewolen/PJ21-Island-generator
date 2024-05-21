extends WindowDialog


signal file_content_generated

const OBJ_HEADER = \
"""# exported from island-generator made by dewolen
# dewolen.itch.io/island-generator
"""


var object_name := "Island"

var _objcont := "" # .obj file content
var _matcont := "" # .mat file content
var _textures_list := {} # key: texture name, value: Texture object
var _ground_image: Image # a top-down projection of the mesh's vertex colors

var _default_message: String # default message in the InfoLabel
var _export_directory: String
var _full_export_path: String

var _gen_thread: Thread = null # generates file contents to be saved

onready var file_dialog := $FileDialog
onready var info_label := $VBC/InfoLabel
onready var open_directory_button := $VBC/OpenDirectoryButton
onready var export_progress_bar := $VBC/ExportProgressBar


func _ready() -> void:
	_default_message = info_label.text
	open_directory_button.hide()
	
	connect("file_content_generated", self, "_on_file_content_generated", [], CONNECT_DEFERRED)


func _on_ExportButton_pressed() -> void:
#	file_dialog.add_filter("*.obj; Wavefront File")
	file_dialog.popup_centered()


func _on_OpenDirectoryButton_pressed() -> void:
	if not _export_directory:
		return
	OS.shell_open(_export_directory)


func _on_FileDialog_dir_selected(path: String) -> void:
	var time_dict := Time.get_datetime_dict_from_system()
	var folder_name := "island_export_{day}-{month}-{year}_{hour}-{minute}-{second}" \
		.format(time_dict)
	_full_export_path = path.plus_file(folder_name)
	
	var meshes_container = get_tree().current_scene.get_node("TerrainMeshes")
	if not meshes_container is Node:
		return
	
	if meshes_container.get_child_count() == 0 \
	or meshes_container.get_child(0).name == "PlaceholderIsland":
		display_message("Generate an island first")
		return
	
	display_message("Exporting mesh to:\n[{path}]\n\nPlease wait" \
		.format({"path": _full_export_path}))
	
	var mesh = get_aggregate_mesh(meshes_container.get_children(), false)
	
	_gen_thread = Thread.new()
	_gen_thread.start(self, "generate_file_contents", mesh)
#	_gen_thread.start(self, "generate_file_contents", meshes_container.get_children())


func _on_file_content_generated() -> void:
	
	var err := export_files_to(_full_export_path)
	if err:
		display_message("Export failiure, error code: {err}\nPath: [{path}]" \
			.format({"path": _full_export_path, "err": err}))
		return
	
	display_message("Mesh exported to:\n[{path}]" \
		.format({"path": _full_export_path}))
	display_open_export_directory_button(_full_export_path)
	
#	if _gen_thread.is_active():
#		_gen_thread.wait_to_finish() # make sure the thread is dead


func get_aggregate_mesh(mi_array: Array, use_node_transform := true) -> Mesh:
	# creates a new mesh by connecting all given MeshInstance meshes
	
	var meshes := []
	var transforms := []
	var max_surface_count := 0
	for mi in mi_array:
		if not mi is MeshInstance:
			continue
		if mi.name.begins_with("Seabed"):
			continue
		meshes.append(mi.mesh)
		transforms.append(mi.global_transform)
		max_surface_count = max(mi.mesh.get_surface_count(), max_surface_count)
	
	# create the UV transform to change the XZ vertex
	# coordinates ranging in [-radius, radius] to texture
	# UV coordinates ranging in [0, 1]
	var radius: float = GenParams.previous_parameters["radius"]
	var uv_transform := Transform2D(
		Vector2(0.5 / radius, 0.0),
		Vector2(0.0, 0.5 / radius),
		Vector2(0.5, 0.5)
	)
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var img := Image.new()
	img.create(radius * 2, radius * 2, false, Image.FORMAT_RGB8)
	img.lock()
	var img_written_to := false
	
	for im in meshes.size():
		# get surfaces and mesh info
		for t in meshes[im].get_surface_count():
			var surface: Array = meshes[im].surface_get_arrays(t)
			var verts: PoolVector3Array = surface[ArrayMesh.ARRAY_VERTEX]
			var normals                 = surface[ArrayMesh.ARRAY_NORMAL]
#			var tangents                = surface[ArrayMesh.ARRAY_TANGENT]
			var colors                  = surface[ArrayMesh.ARRAY_COLOR]
			var UVs                     = surface[ArrayMesh.ARRAY_TEX_UV]
#			var UV2s                    = surface[ArrayMesh.ARRAY_TEX_UV2]
#			var bones                   = surface[ArrayMesh.ARRAY_BONES]
#			var weights                 = surface[ArrayMesh.ARRAY_WEIGHTS]
#			var indices                 = surface[ArrayMesh.ARRAY_INDEX]
			
			for iv in verts.size():
				if normals:
					st.add_normal(normals[iv])
				
#				if colors:
#					st.add_color(colors[iv])
				
				if UVs:
					st.add_uv(UVs[iv])
				else:
					# create uv coordinates as a top-down texture projection
					st.add_uv(uv_transform.xform(Vector2(verts[iv].x, -verts[iv].z)))
				
				if use_node_transform:
					st.add_vertex(transforms[im].xform(verts[iv]))
				else:
					st.add_vertex(verts[iv])
			
			if colors:
				# every island mesh quad is made out of two triangles/six
				# vertices, this gets color from each quad once
				for iv in verts.size() / 6:
					img.set_pixel(verts[iv * 6].x + radius, verts[iv * 6].z + radius, colors[iv * 6])
				# problem: pixels not overlapped by a vertex will be left blank
				img_written_to = true
	
	img.unlock()
	if img_written_to:
		_ground_image = img
	
	st.index()
	return st.commit()


func generate_file_contents(meshes) -> void:
	# Based on a script by: mohammedzero43 (Xtremezero)
	# https://github.com/xtremezero/CSGExport-Godot
	
	#mesh: Mesh, MeshInstance, Mesh Array or MeshInstance Array
	if not meshes:
		print("No mesh to export!")
		return
	
	if not meshes is Array:
		meshes = [meshes]
	
	var transforms := []
	transforms.resize(meshes.size())
	if meshes[0] is Node:
		var i := 0
		while i < meshes.size():
			# remove all non-MeshInstances and seabed meshes
			if not meshes[i] is MeshInstance \
			or meshes[i].name.begins_with("Seabed"):
				meshes.remove(i)
				transforms.pop_back() # decrease size by one
				continue
			transforms[i] = meshes[i].transform
			meshes[i] = meshes[i].mesh
			# meshes is now a Mesh Array
			i += 1
	elif meshes[0] is Mesh:
		# meshes is already a Mesh Array
		transforms.fill(Transform())
	else:
		print("No mesh to export!")
		return
	
	# variables
	_objcont = ""
	_matcont = ""
	_textures_list = {}
	var vertcount := 1 # set to 1 because .obj indexing starts at 1, not 0
	var used_materials := []
	
	# OBJ Headers
	_objcont = OBJ_HEADER
	_objcont += "mtllib " + object_name + ".mtl\n"
	_objcont += "o " + object_name + "\n"
	
	# default material
	var default_material := SpatialMaterial.new()
	default_material.resource_name = "DefaultMaterial"
	
	if meshes.size() > 1: # display progress only when exporting multiple meshes
		set_generation_progress(0.0)
	yield(get_tree().create_timer(0.1), "timeout")
	
	# get surfaces and mesh info
	for im in meshes.size():
		var mesh: Mesh = meshes[im]
		for t in mesh.get_surface_count():
			var surface: Array = mesh.surface_get_arrays(t)
			var verts: PoolVector3Array = surface[ArrayMesh.ARRAY_VERTEX]
			var normals                 = surface[ArrayMesh.ARRAY_NORMAL]
#			var tangents                = surface[ArrayMesh.ARRAY_TANGENT]
#			var colors                  = surface[ArrayMesh.ARRAY_COLOR]
			var UVs                     = surface[ArrayMesh.ARRAY_TEX_UV]
#			var UV2s                    = surface[ArrayMesh.ARRAY_TEX_UV2]
#			var bones                   = surface[ArrayMesh.ARRAY_BONES]
#			var weights                 = surface[ArrayMesh.ARRAY_WEIGHTS]
			var indices                 = surface[ArrayMesh.ARRAY_INDEX]
			
			var line := 0
			var surfcont := PoolStringArray()
			var surfcont_size: int = verts.size() + 2
			if normals:
				surfcont_size += normals.size()
			if UVs:
				surfcont_size += UVs.size()
			surfcont_size += (indices.size() if indices else verts.size()) / 3
			surfcont.resize(surfcont_size)
			
			var mat: SpatialMaterial = mesh.surface_get_material(t)
			if mat == null:
				mat = default_material
			
			# add verticies
			for v in verts:
				surfcont[line] = str("v ", v.x, " ", v.y, " ", v.z)
				line += 1
			
			# add UVs
			if UVs:
				for uv in UVs:
					surfcont[line] = str("vt ", uv.x, " ", uv.y)
					line += 1
			
			# add normals
			if normals:
				for n in normals:
					surfcont[line] = str("vn ", n.x, " ", n.y, " ", n.z)
					line += 1
			
			# add surface
			surfcont[line] = "\ng obj" + str(im) + "_surface" + str(t)
			line += 1
			
			# add material
			surfcont[line] = "\nusemtl " + str(mat)
			line += 1
			
			# create the index Array if none defined
			if not indices:
				indices = PoolIntArray()
				indices.resize(verts.size())
				for i in indices.size():
					indices[i] = i
			
			# add faces
			var vstart := 0
			var face_def_v1 := ""
			var face_def_v2 := ""
			var face_def_v3 := ""
			var normal_separator := "/" if UVs else "//"
			for face in indices.size() / 3:
				# vertex_index/texture_index/normal_index
				face_def_v1 = str(indices[vstart + 2] + vertcount)
				face_def_v2 = str(indices[vstart + 1] + vertcount)
				face_def_v3 = str(indices[vstart    ] + vertcount)
				if UVs:
					face_def_v1 += "/" + str(indices[vstart + 2] + vertcount)
					face_def_v2 += "/" + str(indices[vstart + 1] + vertcount)
					face_def_v3 += "/" + str(indices[vstart    ] + vertcount)
				if normals:
					face_def_v1 += normal_separator + str(indices[vstart + 2] + vertcount)
					face_def_v2 += normal_separator + str(indices[vstart + 1] + vertcount)
					face_def_v3 += normal_separator + str(indices[vstart    ] + vertcount)
				# example face definition: f 1/1/1 2/2/2 3/3/3
				# either as v OR v/vt OR v/vt/vn OR v//vn
				surfcont[line] = "f " + face_def_v1 + " " + face_def_v2 + " " + face_def_v3
				vstart += 3
				line += 1
			_objcont += surfcont.join("\n") + "\n"
			
			# add number of vertices in this surface to total count
			vertcount += verts.size()
			
			# create materials for current surface
			if not mat in used_materials:
				_matcont += str("newmtl " + str(mat), "\n")
				
				# diffuse color
				_matcont += str("Kd ", mat.albedo_color.r, " ", mat.albedo_color.g, " ", mat.albedo_color.b, "\n")
				
				# diffuse texture
				if mat == default_material or mat.albedo_texture:
					var albedo_texture_name := "colormap" + str(used_materials.size()) + ".png"
					if mat == default_material:
						_textures_list[albedo_texture_name] = _ground_image
					else:
						_textures_list[albedo_texture_name] = mat.albedo_texture
					_matcont += "map_Kd " + albedo_texture_name + "\n"
				
#				# transmission filter color
#				_matcont += str("Tf ", mat.transmission.r, " ", mat.transmission.g, " ", mat.transmission.b, "\n")
				
#				# transparency/dissolve value
#				_matcont += str("d ", mat.albedo_color.a, "\n")
				
				used_materials.append(mat)
		
		if meshes.size() > 1: # display progress only when exporting multiple meshes
			set_generation_progress(im as float / meshes.size())
			yield(get_tree().create_timer(0.1), "timeout")
	
	set_generation_progress(1.0) # finish
	_gen_thread.call_deferred("wait_to_finish")


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
	
	# save png files:
	for tex_name in _textures_list:
		var tex_data = _textures_list[tex_name]
		
		if tex_data is Texture:
			tex_data = tex_data.get_data()
		
		if not tex_data is Image:
			continue
		
		tex_data.save_png(path.plus_file(tex_name))
	
	# clear buffers
	_objcont = ""
	_matcont = ""
	_textures_list = {}
	
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
	display_open_export_directory_button() # hide the button


func set_generation_progress(percentage: float) -> void:
	export_progress_bar.call_deferred("show")
	export_progress_bar.set_deferred("value", percentage)
	if percentage >= 1.0:
		export_progress_bar.call_deferred("hide")
		emit_signal("file_content_generated")
