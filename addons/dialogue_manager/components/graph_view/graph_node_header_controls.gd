@tool
class_name DMGraphNodeHeaderControls
extends RefCounted
## Hover delete button controls for graph node title bars.


## Default title bar height used for hover hit testing.
const DEFAULT_TITLE_HEIGHT: float = 30.0
## Size of the header delete button in pixels.
const DELETE_BUTTON_SIZE: float = 24.0


## Attaches a hover delete button to the graph node title bar.
static func attach(node: GraphNode, delete_callback: Callable, title_height: float = DEFAULT_TITLE_HEIGHT) -> void:
	if node.has_meta(&"graph_header_controls_attached"): return
	node.set_meta(&"graph_header_controls_attached", true)

	var delete_button := Button.new()
	delete_button.name = "HeaderDeleteButton"
	delete_button.flat = true
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.visible = false
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.custom_minimum_size = Vector2(DELETE_BUTTON_SIZE, DELETE_BUTTON_SIZE)
	delete_button.tooltip_text = "Delete node"
	delete_button.pressed.connect(delete_callback)
	node.add_child(delete_button)
	delete_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	delete_button.offset_left = -DELETE_BUTTON_SIZE - 4.0
	delete_button.offset_top = 4.0
	delete_button.offset_right = -4.0
	delete_button.offset_bottom = 4.0 + DELETE_BUTTON_SIZE
	delete_button.z_index = 100
	_apply_delete_icon(delete_button)

	if not node.gui_input.is_connected(_on_node_gui_input):
		node.gui_input.connect(_on_node_gui_input.bind(node, delete_button, title_height))


static func _apply_delete_icon(delete_button: Button) -> void:
	if not is_instance_valid(delete_button): return
	var host: Node = delete_button.get_parent()
	if not is_instance_valid(host): return
	if host.has_theme_icon(&"Remove", &"EditorIcons"):
		delete_button.icon = host.get_theme_icon(&"Remove", &"EditorIcons")
	elif host.has_theme_icon(&"Trash", &"EditorIcons"):
		delete_button.icon = host.get_theme_icon(&"Trash", &"EditorIcons")


static func _on_node_gui_input(node: GraphNode, delete_button: Button, title_height: float, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		delete_button.visible = motion.position.y <= title_height
	elif event is InputEventMouseButton and not event.pressed:
		if not delete_button.get_global_rect().has_point(delete_button.get_global_mouse_position()):
			if not Rect2(Vector2.ZERO, node.size).has_point(node.get_local_mouse_position()):
				delete_button.visible = false
