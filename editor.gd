extends Node3D

const RAY_LENGTH = 100.0

enum State { NONE, PLACE, SELECT }

@onready var camera3d = $Camera3D
@onready var container = $ModuleContainer
@onready var selection_mesh = $MeshInstance3D

var toolbar_item_scene : PackedScene = null

var editor_state = State.SELECT

var modules = {}
var modules_order = []
var current_module = -1
var current_block : PackedScene = null
var current_instance = null
var current_attached = false
var current_anchor = 0
var current_attached_from = null
var current_attached_to = null

func clear_current_instance():
	current_block = null
	current_instance = null
	current_attached = false
	current_anchor = 0
	current_attached_from = null
	current_attached_to = null
	
func place_cancel():
	if current_instance:
		container.remove_child(current_instance)
		current_instance.queue_free()
	clear_current_instance()
	
func create_module_new_instance():
	current_instance = current_block.instantiate()
	current_instance.set_transparency(0.5)
	current_instance.visible = false
	current_instance.set_meta("module_name", modules_order[current_module])
	current_instance.set_meta("module_placed", false)
	current_instance.add_to_group("is_module")
	current_attached = false
	current_anchor = 0
	current_attached_from = null
	current_attached_to = null
	container.add_child(current_instance)
	
func place_module():
	if current_instance:
		current_instance.set_transparency(0)
		current_instance.set_meta("module_placed", true)
		
	if current_attached_from:
		current_attached_from.collision_layer = 0
	
	if current_attached_to:
		current_attached_to.collision_layer = 0
		
	create_module_new_instance()
	
func change_module(n):
	if current_instance:
		container.remove_child(current_instance)
		current_instance.queue_free()
		
	if n > -1 and n < len(modules_order):
		current_module = n
		current_block = modules[modules_order[current_module]].resource
		create_module_new_instance()
	else:
		clear_current_instance()
		current_module = -1
		
func mouse_pick_area():
	var mpos = get_viewport().get_mouse_position()
	var origin = camera3d.project_ray_origin(mpos)
	var end = origin + camera3d.project_ray_normal(mpos) * RAY_LENGTH
	
	var params = PhysicsRayQueryParameters3D.create(origin, end, 1)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	
	var hit = get_world_3d().direct_space_state.intersect_ray(params)
	if hit.has("collider") and hit.collider and (current_instance == null || current_instance != hit.collider.get_parent()):
		return hit.collider
	return null

func mouse_pick_body():
	var mpos = get_viewport().get_mouse_position()
	var origin = camera3d.project_ray_origin(mpos)
	var end = origin + camera3d.project_ray_normal(mpos) * RAY_LENGTH
	
	var params = PhysicsRayQueryParameters3D.create(origin, end, 1)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	
	var hit = get_world_3d().direct_space_state.intersect_ray(params)
	if hit.has("collider") and hit.collider and (current_instance == null || current_instance != hit.collider.get_parent()):
		return hit.collider
	return null
	
# Called when the node enters the scene tree for the first time.
func _ready():
	toolbar_item_scene = preload("res://toolbar_item.tscn")
	register_module("module_rectangle_one", preload("res://modules/module_rectangle_one.tscn"))
	register_module("module_rectangle_omni", preload("res://modules/module_rectangle_omni.tscn"))
	register_module("module_rectangle_long_two", preload("res://modules/module_rectangle_long_two.tscn"))
	register_module("module_capsule_end", preload("res://modules/module_capsule_end.tscn"))
	register_module("module_rectangle_special_1", preload("res://modules/module_rectangle_special_1.tscn"))
	register_module("module_rectangle_special_3", preload("res://modules/module_rectangle_special_3.tscn"))
	change_module(0)

func _unhandled_input(event):
	if Input.is_action_just_pressed("num_6"):
		print(get_connected_pairs())
		
	if editor_state == State.PLACE:
		editor_state_place_input(event)
	elif editor_state == State.SELECT:
		editor_state_select_input(event)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if editor_state == State.PLACE:
		editor_state_place()
	elif editor_state == State.SELECT:
		editor_state_select()
	
func editor_state_select_input(event):
	pass
	
func editor_state_select():
	var module_hover = mouse_pick_body()
	var module = get_module(module_hover)
	if module:
		if Input.is_action_just_pressed("confirm"):
			module.queue_free()
			module = null
	update_selection_box(module)

func editor_state_place_input(event):
	if Input.is_action_just_pressed("module_down"):
		change_module((len(modules_order) + current_module - 1) % len(modules_order))
	
	if Input.is_action_just_pressed("module_up"):
		change_module((current_module + 1) % len(modules_order))
		
	if Input.is_action_just_pressed("rotate_down") and current_attached:
		if current_attached_from:
			var a1 = (current_attached_from.global_position - current_instance.global_position)
			current_instance.global_rotate(a1, PI / 2)
		else:
			current_instance.global_rotate(current_instance.global_transform.basis.z, -PI / 2)
		
	if Input.is_action_just_pressed("rotate_up"):
		if current_attached_from:
			var a1 = (current_attached_from.global_position - current_instance.global_position)
			current_instance.global_rotate(a1, -PI / 2)
		else:
			current_instance.global_rotate(current_instance.global_transform.basis.z, -PI / 2)
		
	if Input.is_action_just_pressed("anchor_down"):
		var anchors = get_achors(current_instance)
		current_anchor = (len(anchors) + (current_anchor - 1)) % len(anchors)
		
	if Input.is_action_just_pressed("anchor_up"):
		var anchors = get_achors(current_instance)
		current_anchor = (current_anchor + 1) % len(anchors)
	
	if Input.is_action_just_pressed("confirm") and current_attached:
		place_module()
	
func editor_state_place():
	if current_instance:
		var placed_modules = get_placed_module()
		if len(placed_modules) == 0:
			current_instance.global_position = Vector3()
			current_instance.global_rotation = Vector3()
			current_instance.visible = true
			current_attached = true
			
		else:
			var result = current_attached_to
			
			var picked = mouse_pick_area()
			if picked:
				result = picked
				
			var module = null
			if result != null:
				module = result.get_parent()
			else:
				return
				
			var anchors = get_achors(current_instance)
			if len(anchors) > 0 and anchors[current_anchor].get_parent() != module and (anchors[current_anchor] != current_attached_from or current_attached_to != result):
				var anchor = anchors[current_anchor]
				current_instance.global_position = Vector3()
				current_instance.global_rotation = Vector3()

				var a = result.global_transform.basis.z
				var b = result.global_transform.basis.x
				var c = a.cross(b).normalized()
				var d = PI
				current_instance.global_transform = anchor.global_transform.inverse()
				current_instance.global_rotate(result.global_transform.basis.get_rotation_quaternion().get_axis(), result.global_transform.basis.get_rotation_quaternion().get_angle())
				current_instance.global_rotate(c, d)
				current_instance.global_position = module.global_position + (result.global_position - module.global_position) - (anchor.global_position - current_instance.global_position)
				
				current_instance.visible = true
				current_attached = true
				current_attached_to = result
				current_attached_from = anchor

func _on_button_delete_pressed():
	place_cancel()
	editor_state = State.SELECT
	update_selection_box(null)

func _on_button_place_pressed():
	if current_module < 0:
		change_module(0)
	editor_state = State.PLACE
	update_selection_box(null)

func _on_button_new_pressed():
	place_cancel()
	var nodes = get_tree().get_nodes_in_group("is_module")
	for n in nodes:
		n.queue_free()

func _on_button_load_pressed():
	var fd = $FileDialogLoad
	fd.popup()

func _on_button_save_as_pressed():
	var fd = $FileDialogSave
	fd.popup()

func _on_file_dialog_load_file_selected(path):
	_on_button_new_pressed()
	var f = FileAccess.open(path, FileAccess.READ)
	var storage = f.get_var(true)
	for e in storage:
		if modules.has(e.name):
			var m = modules[e.name]
			var i = m.resource.instantiate()
			i.set_meta("module_name", m.name)
			i.set_meta("module_placed", true)
			i.add_to_group("is_module")
			i.global_transform = e.transform
			container.add_child(i)
		else:
			print(e.name)

func _on_file_dialog_save_file_selected(path):
	var nodes = get_placed_module()
	var storage = []
	for n in nodes:
		storage.push_back({
				"name": n.get_meta("module_name"),
				"transform": n.global_transform,
		})
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_var(storage, true)

func update_selection_box(module):
	if module:
		var aabb = get_aabb(module)
		
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		
		st.add_vertex(aabb.get_endpoint(0));
		st.add_vertex(aabb.get_endpoint(1));
		st.add_vertex(aabb.get_endpoint(0));
		st.add_vertex(aabb.get_endpoint(2));
		st.add_vertex(aabb.get_endpoint(2));
		st.add_vertex(aabb.get_endpoint(3));
		st.add_vertex(aabb.get_endpoint(3));
		st.add_vertex(aabb.get_endpoint(1));
		
		st.add_vertex(aabb.get_endpoint(0));
		st.add_vertex(aabb.get_endpoint(4));
		st.add_vertex(aabb.get_endpoint(1));
		st.add_vertex(aabb.get_endpoint(5));
		st.add_vertex(aabb.get_endpoint(2));
		st.add_vertex(aabb.get_endpoint(6));
		st.add_vertex(aabb.get_endpoint(3));
		st.add_vertex(aabb.get_endpoint(7));
		
		st.add_vertex(aabb.get_endpoint(4));
		st.add_vertex(aabb.get_endpoint(5));
		st.add_vertex(aabb.get_endpoint(4));
		st.add_vertex(aabb.get_endpoint(6));
		st.add_vertex(aabb.get_endpoint(6));
		st.add_vertex(aabb.get_endpoint(7));
		st.add_vertex(aabb.get_endpoint(7));
		st.add_vertex(aabb.get_endpoint(5));
		
		selection_mesh.global_transform = module.global_transform
		selection_mesh.mesh = st.commit()
		selection_mesh.visible = true
	else:
		selection_mesh.visible = false

func get_connected_pairs():
	var anchors = get_tree().get_nodes_in_group("anchor")
	var pairs = {}
	
	for a1 in anchors:
		if pairs.has(a1): continue
		for a2 in anchors:
			if a1 == a2 or pairs.has(a2): continue
			if a1.global_position.is_equal_approx(a2.global_position):
				pairs[a1] = a2
				pairs[a2] = a1
				break
	return pairs

func get_placed_module():
	var result = []
	var nodes = get_tree().get_nodes_in_group("is_module")
	for n in nodes:
		if n.get_meta("module_name") and modules.has(n.get_meta("module_name")) and n.get_meta("module_placed"):
			result.push_back(n)
	return result

func toolbar_item_selected(sender):
	change_module(modules_order.find(sender.get_meta("module_name")))

func register_module(name, resource):
	modules[name] = {
		"name": name,
		"resource": resource
	}
	modules_order.push_back(name)
	var tb = toolbar_item_scene.instantiate()
	tb.add_item(resource.instantiate())
	tb.set_meta("module_name", name)
	tb.item_selected.connect(toolbar_item_selected)
	$Panel2/ScrollContainer/VBoxContainer.add_child(tb)
	
func get_achors(node):
	var open = [ node ]
	var result = []
	while len(open) > 0:
		var current = open.pop_front()
		var children = current.get_children()
		for c in children:
			if c.is_in_group("anchor"):
				result.push_back(c)
			else:
				open.push_back(c)
	return result
	
func get_aabb(node):
	var open = [ node ]
	var result = AABB()
	while len(open) > 0:
		var current = open.pop_front()
		if current is VisualInstance3D:
			result = result.merge(current.transform * current.get_aabb())
		open.append_array(current.get_children())
	return result

func get_module(node):
	while node:
		if node.is_in_group("is_module") and node.get_meta("module_name"):
			break
		node = node.get_parent()
	return node
