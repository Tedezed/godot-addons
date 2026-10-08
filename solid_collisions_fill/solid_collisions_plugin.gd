@tool
extends EditorPlugin

@export var trasnsparency_shape: float = 0.6

var debug_3d_container: Node3D

func _enter_tree() -> void:
	set_process(true)

func _exit_tree() -> void:
	set_process(false)
	clear_3d_debug_meshes()

func _process(_delta: float) -> void:
	update_overlays() #2D
	update_3d_debug_meshes() #3D

# ==========================================
# 2D (Canvas Viewport)
# ==========================================
func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var root = get_editor_interface().get_edited_scene_root()
	if root:
		_draw_collisions_2d_recursive(root, overlay)

func _draw_collisions_2d_recursive(node: Node, overlay: Control) -> void:
	if node is CollisionShape2D and node.visible and node.shape:
		var color: Color = node.debug_color
		var xform: Transform2D = node.get_global_transform_with_canvas()
		var shape = node.shape

		if shape is RectangleShape2D:
			var half = shape.size / 2.0
			var pts = PackedVector2Array([
				xform * Vector2(-half.x, -half.y),
				xform * Vector2(half.x, -half.y),
				xform * Vector2(half.x, half.y),
				xform * Vector2(-half.x, half.y)
			])
			overlay.draw_polygon(pts, PackedColorArray([color]))
		elif shape is CircleShape2D:
			var pts = PackedVector2Array()
			for i in range(32):
				var angle = (float(i) / 32) * TAU
				pts.append(xform * (Vector2(cos(angle), sin(angle)) * shape.radius))
			overlay.draw_polygon(pts, PackedColorArray([color]))

	for child in node.get_children():
		_draw_collisions_2d_recursive(child, overlay)


# ==========================================
# 3D (Vuew Global)
# ==========================================
func update_3d_debug_meshes() -> void:
	var root = get_editor_interface().get_edited_scene_root()
	if not root:
		clear_3d_debug_meshes()
		return

	if not debug_3d_container or not debug_3d_container.is_inside_tree():
		debug_3d_container = Node3D.new()
		debug_3d_container.name = "EditorDebugCollisionContainer"
		root.add_child(debug_3d_container)

	for child in debug_3d_container.get_children():
		child.queue_free()

	_create_3d_meshes_recursive(root)

func _create_3d_meshes_recursive(node: Node) -> void:
	if node is CollisionShape3D and node.visible and node.is_visible_in_tree() and node.shape:
		var mi = MeshInstance3D.new()
		var shape = node.shape
		var color = node.debug_color

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b, trasnsparency_shape)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat

		var mesh: Mesh = null
		if shape is BoxShape3D:
			var box = BoxMesh.new()
			box.size = shape.size
			mesh = box
		elif shape is SphereShape3D:
			var sph = SphereMesh.new()
			sph.radius = shape.radius
			sph.height = shape.radius * 2.0
			mesh = sph
		elif shape is CylinderShape3D:
			var cyl = CylinderMesh.new()
			cyl.top_radius = shape.radius
			cyl.bottom_radius = shape.radius
			cyl.height = shape.height
			mesh = cyl
		elif shape is CapsuleShape3D:
			var cap = CapsuleMesh.new()
			cap.radius = shape.radius
			cap.height = shape.height
			mesh = cap

		if mesh:
			mi.mesh = mesh
			debug_3d_container.add_child(mi)
			mi.global_transform = node.global_transform

	for child in node.get_children():
		_create_3d_meshes_recursive(child)

func clear_3d_debug_meshes() -> void:
	if debug_3d_container and debug_3d_container.is_inside_tree():
		debug_3d_container.queue_free()
		debug_3d_container = null
