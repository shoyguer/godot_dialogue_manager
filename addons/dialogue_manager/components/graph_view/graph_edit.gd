@tool
class_name DMGraphEdit
extends GraphEdit
## GraphEdit subclass with connection hover and canvas hit testing.


## Emitted when the mouse hovers a connection line.
signal connection_hovered(connection: Dictionary)

## Emitted when the mouse leaves all connection lines.
signal connection_hover_cleared()


## Maximum distance in pixels to detect a hovered connection line.
const HOVER_DISTANCE: float = 14.0


var _last_hovered: Dictionary = {}


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var hovered: Dictionary = get_closest_connection_at_point(get_local_mouse_position(), HOVER_DISTANCE)
	if hovered.is_empty():
		if not _last_hovered.is_empty():
			_last_hovered = {}
			connection_hover_cleared.emit()
		return
	var hovered_key: String = _connection_key(hovered)
	var last_key: String = _connection_key(_last_hovered)
	if hovered_key != last_key:
		_last_hovered = hovered
		connection_hovered.emit(hovered)


## Converts a local GraphEdit point to graph canvas coordinates.
func local_point_to_graph_position(local_point: Vector2) -> Vector2:
	return scroll_offset + local_point / zoom


## Returns true when a local point lies inside any child GraphNode.
func is_point_on_graph_node(local_point: Vector2) -> bool:
	return get_graph_node_at_local_point(local_point) != null


## Returns the GraphNode under a local GraphEdit point, if any.
func get_graph_node_at_local_point(local_point: Vector2) -> GraphNode:
	var graph_point: Vector2 = local_point_to_graph_position(local_point)
	for child: Node in get_children():
		if not child is GraphNode:
			continue
		var graph_node: GraphNode = child as GraphNode
		var node_rect: Rect2 = Rect2(graph_node.position_offset, graph_node.size)
		if node_rect.size == Vector2.ZERO:
			node_rect.size = graph_node.get_combined_minimum_size()
		if node_rect.has_point(graph_point):
			return graph_node
	return null


## Returns true when a local point is near a connection line.
func is_point_on_connection(local_point: Vector2, max_distance: float = HOVER_DISTANCE) -> bool:
	return not get_closest_connection_at_point(local_point, max_distance).is_empty()


## Clears selection on all child graph nodes (GraphEdit has no clear_selection in all Godot versions).
func clear_graph_selection() -> void:
	for child: Node in get_children():
		if child is GraphNode:
			(child as GraphNode).selected = false


func _connection_key(connection: Dictionary) -> String:
	if connection.is_empty():
		return ""
	return "%s:%d->%s:%d" % [
		connection.get("from_node", ""),
		int(connection.get("from_port", -1)),
		connection.get("to_node", ""),
		int(connection.get("to_port", -1)),
	]
