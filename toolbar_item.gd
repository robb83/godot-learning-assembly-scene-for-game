extends SubViewportContainer

signal item_selected(sender)

func add_item(item):
	$SubViewport/Node3D.add_child(item)
	
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		item_selected.emit(self)
