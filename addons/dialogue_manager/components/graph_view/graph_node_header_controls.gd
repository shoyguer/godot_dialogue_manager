@tool
class_name DMGraphNodeHeaderControls
extends RefCounted
## Hover delete button controls for graph node title bars.


## Default title bar height used for hover hit testing.
const DEFAULT_TITLE_HEIGHT: float = 34.0

## Size of the header delete button in pixels.
const DELETE_BUTTON_SIZE: float = 22.0


## Attaches a hover delete button for the graph node title bar.
static func attach(node: GraphNode, delete_callback: Callable, title_height: float = DEFAULT_TITLE_HEIGHT) -> void:
	if node.has_meta(&"graph_header_controls_attached"): return
	var graph_edit: GraphEdit = node.get_parent() as GraphEdit
	if not is_instance_valid(graph_edit): return

	node.set_meta(&"graph_header_controls_attached", true)
	node.set_meta(&"header_delete_title_height", title_height)

	var delete_button: Button = Button.new()
	delete_button.name = "HeaderDeleteButton_%s" % node.name
	delete_button.top_level = true
	delete_button.flat = true
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.visible = false
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.custom_minimum_size = Vector2(DELETE_BUTTON_SIZE, DELETE_BUTTON_SIZE)
	delete_button.tooltip_text = DMGraphTooltips.NODE_DELETE
	delete_button.z_index = 4096
	delete_button.pressed.connect(delete_callback)
	graph_edit.add_child(delete_button)
	node.set_meta(&"header_delete_button", delete_button)
	node.tree_exiting.connect(_on_node_tree_exiting.bind(node))
	_apply_delete_icon(delete_button, graph_edit)


static func detach(node: GraphNode) -> void:
	if not node.has_meta(&"header_delete_button"):
		return
	var delete_button: Button = node.get_meta(&"header_delete_button") as Button
	if is_instance_valid(delete_button):
		delete_button.queue_free()
	node.remove_meta(&"header_delete_button")
	node.remove_meta(&"graph_header_controls_attached")
	node.remove_meta(&"header_delete_title_height")


static func update_all(graph_edit: GraphEdit) -> void:
	if not is_instance_valid(graph_edit): return
	var mouse_global: Vector2 = graph_edit.get_global_mouse_position()
	for child: Node in graph_edit.get_children():
		if not child is GraphNode:
			continue
		var graph_node: GraphNode = child as GraphNode
		if not graph_node.has_meta(&"header_delete_button"):
			continue
		var delete_button: Button = graph_node.get_meta(&"header_delete_button") as Button
		if not is_instance_valid(delete_button):
			continue
		var title_height: float = float(graph_node.get_meta(&"header_delete_title_height", DEFAULT_TITLE_HEIGHT))
		var node_rect: Rect2 = graph_node.get_global_rect()
		var title_rect: Rect2 = Rect2(node_rect.position, Vector2(node_rect.size.x, title_height))
		delete_button.global_position = Vector2(
			node_rect.position.x + node_rect.size.x - DELETE_BUTTON_SIZE - 6.0,
			node_rect.position.y + 4.0
		)
		var button_rect: Rect2 = delete_button.get_global_rect()
		var over_title: bool = title_rect.has_point(mouse_global)
		var over_button: bool = button_rect.has_point(mouse_global)
		delete_button.visible = over_title or over_button


static func _on_node_tree_exiting(node: GraphNode) -> void:
	detach(node)


static func _apply_delete_icon(delete_button: Button, host: Node) -> void:
	if not is_instance_valid(delete_button) or not is_instance_valid(host): return
	if host.has_theme_icon(&"Remove", &"EditorIcons"):
		delete_button.icon = host.get_theme_icon(&"Remove", &"EditorIcons")
	elif host.has_theme_icon(&"Trash", &"EditorIcons"):
		delete_button.icon = host.get_theme_icon(&"Trash", &"EditorIcons")
