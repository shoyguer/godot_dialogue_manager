@tool
class_name DMGraphNodeHover
extends RefCounted
## Hover highlighting for graph nodes (title bar or compact body).


const TITLE_HEIGHT: float = DMGraphNodeHeaderControls.DEFAULT_TITLE_HEIGHT


static var _hovered_node: GraphNode = null


static func update_all(graph_edit: GraphEdit) -> void:
	if not is_instance_valid(graph_edit):
		return
	var mouse_global: Vector2 = graph_edit.get_global_mouse_position()
	var next_hover: GraphNode = null
	for i: int in range(graph_edit.get_child_count() - 1, -1, -1):
		var child: Node = graph_edit.get_child(i)
		if child is GraphNode and _should_hover(child as GraphNode, mouse_global):
			next_hover = child as GraphNode
			break
	if next_hover == _hovered_node:
		return
	if is_instance_valid(_hovered_node):
		_set_hover(_hovered_node, false)
	_hovered_node = next_hover
	if is_instance_valid(_hovered_node):
		_set_hover(_hovered_node, true)


static func clear_hover() -> void:
	if is_instance_valid(_hovered_node):
		_set_hover(_hovered_node, false)
	_hovered_node = null


static func _should_hover(gn: GraphNode, mouse_global: Vector2) -> bool:
	if not gn.get_global_rect().has_point(mouse_global):
		return false
	if gn is DMGraphCompactNode:
		return (gn as DMGraphCompactNode).is_mouse_over_body(mouse_global)
	if gn is DMGraphResponseGroupNode:
		return not (gn as DMGraphResponseGroupNode).is_mouse_over_response_row(mouse_global)
	if gn is DMGraphConditionGroupNode or gn is DMGraphMatchGroupNode or gn is DMGraphRandomGroupNode:
		var title_rect: Rect2 = Rect2(gn.global_position, Vector2(gn.size.x, TITLE_HEIGHT))
		return title_rect.has_point(mouse_global)
	if gn is DMGraphNode:
		return _is_over_title_bar(gn, mouse_global)
	return _is_over_title_bar(gn, mouse_global)


static func _is_over_title_bar(gn: GraphNode, mouse_global: Vector2) -> bool:
	var title_rect: Rect2 = Rect2(gn.global_position, Vector2(gn.size.x, TITLE_HEIGHT))
	return title_rect.has_point(mouse_global)


static func _set_hover(gn: GraphNode, hovered: bool) -> void:
	if gn is DMGraphCompactNode:
		(gn as DMGraphCompactNode).set_body_hovered(hovered)
		return
	var accent: Color = _accent_for_node(gn)
	if hovered:
		DMGraphNodeTheme.apply_title_hover(gn, accent)
	else:
		DMGraphNodeTheme.restore_title_style(gn, accent)


static func _accent_for_node(gn: GraphNode) -> Color:
	if gn.has_meta(&"graph_title_accent"):
		return gn.get_meta(&"graph_title_accent") as Color
	if gn is DMGraphResponseGroupNode:
		return DMGraphNodeTheme.ACCENT_RESPONSE
	if gn is DMGraphConditionGroupNode:
		return DMGraphNodeTheme.ACCENT_CONDITION
	if gn is DMGraphMatchGroupNode:
		return DMGraphNodeTheme.get_accent_for_type(DMConstants.TYPE_MATCH)
	if gn is DMGraphRandomGroupNode:
		return DMGraphNodeTheme.get_accent_for_type(DMConstants.TYPE_RANDOM)
	if gn is DMGraphNode:
		return DMGraphNodeTheme.get_accent_for_type((gn as DMGraphNode).node_data.get("type", ""))
	return DMGraphNodeTheme.ACCENT_DEFAULT
