@tool

extends VBoxContainer

class_name DMGraphView





signal document_changed()

signal node_selected(node_data: Dictionary)





const GraphNodeScene: PackedScene = preload("res://addons/dialogue_manager/components/graph_view/graph_node.tscn")
const CompactNodeScene: PackedScene = preload("res://addons/dialogue_manager/components/graph_view/graph_compact_node.tscn")
const ResponseGroupScene: PackedScene = preload("res://addons/dialogue_manager/components/graph_view/graph_response_group_node.tscn")
const ConditionGroupScene: PackedScene = preload("res://addons/dialogue_manager/components/graph_view/graph_condition_group_node.tscn")

const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR





var document: DMGraphDocument = DMGraphDocument.new()

var _full_document: DMGraphDocument = null

var _all_layouts: Dictionary = {}

var _active_cue_name: String = ""

var file_path: String = ""

var _graph_nodes: Dictionary = {}

var _response_port_map: Dictionary = {}
var _condition_port_map: Dictionary = {}
var _goto_visual_aliases: Dictionary = {}
var _goto_canonical_by_target: Dictionary = {}

var _next_id_counter: int = 10000

var _connection_refresh_attempts: int = 0

var _is_updating: bool = false

var _undo_redo: UndoRedo = UndoRedo.new()
var _is_undoing: bool = false
var _skip_auto_layout_on_populate: bool = false
var _mouse_press_undo_before: Dictionary = {}
var _debounced_undo_before: Dictionary = {}
var _undo_debounce_timer: Timer
var _graph_context_menu: PopupMenu
var _node_context_menu: PopupMenu
var _context_menu_spawn_position: Vector2 = Vector2.ZERO
var _context_menu_target_node: GraphNode
var _delete_confirm_dialog: ConfirmationDialog
var _pending_delete_nodes: Array[GraphNode] = []


@onready var graph_edit: DMGraphEdit = %GraphEdit

@onready var connection_status: Label = %ConnectionStatus

@onready var palette: DMGraphNodePalette = %Palette

@onready var inspector: DMGraphInspector = %Inspector

@onready var imports_edit: TextEdit = %ImportsEdit

@onready var using_edit: LineEdit = %UsingEdit

@onready var file_label: Label = %FileLabel





func _ready() -> void:

	graph_edit.right_disconnects = true

	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL

	graph_edit.connection_request.connect(_on_connection_request)

	graph_edit.disconnection_request.connect(_on_disconnection_request)



	if is_instance_valid(palette):

		palette.node_type_selected.connect(_on_node_type_selected)
		document_changed.connect(_refresh_palette_menu)

		var layout_btn: Button = palette.get_node_or_null("%AutoLayoutButton")

		if layout_btn:

			layout_btn.pressed.connect(_on_auto_layout_pressed)

	if is_instance_valid(inspector):

		inspector.property_changed.connect(_on_inspector_changed)

		inspector.insert_requested.connect(_on_insert_requested)

	if is_instance_valid(imports_edit):

		imports_edit.text_changed.connect(_on_file_inspector_changed)

	if is_instance_valid(using_edit):

		using_edit.text_changed.connect(_on_file_inspector_changed.unbind(1))



	graph_edit.gui_input.connect(_on_graph_gui_input)
	graph_edit.popup_request.connect(_on_graph_popup_request)
	graph_edit.connection_hovered.connect(_on_connection_hovered)
	graph_edit.connection_hover_cleared.connect(_on_connection_hover_cleared)

	visibility_changed.connect(_on_visibility_changed)

	_undo_debounce_timer = Timer.new()
	_undo_debounce_timer.one_shot = true
	_undo_debounce_timer.wait_time = 0.45
	_undo_debounce_timer.timeout.connect(_commit_debounced_undo)
	add_child(_undo_debounce_timer)

	_graph_context_menu = PopupMenu.new()
	_graph_context_menu.id_pressed.connect(_on_graph_context_menu_id_pressed)
	add_child(_graph_context_menu)

	_node_context_menu = PopupMenu.new()
	_node_context_menu.id_pressed.connect(_on_node_context_menu_id_pressed)
	add_child(_node_context_menu)

	_delete_confirm_dialog = ConfirmationDialog.new()
	_delete_confirm_dialog.title = "Delete node"
	_delete_confirm_dialog.ok_button_text = "Delete"
	_delete_confirm_dialog.cancel_button_text = "Cancel"
	_delete_confirm_dialog.confirmed.connect(_on_delete_nodes_confirmed)
	add_child(_delete_confirm_dialog)

	_apply_graph_edit_theme()
	set_process(true)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(graph_edit):
		DMGraphNodeHeaderControls.update_all(graph_edit)


func _on_visibility_changed() -> void:
	if not visible or _is_updating or _graph_nodes.is_empty():
		return
	call_deferred("_refresh_connections_when_ready")


func _apply_graph_edit_theme() -> void:
	graph_edit.add_theme_color_override(&"grid_major", Color(1.0, 1.0, 1.0, 0.04))
	graph_edit.add_theme_color_override(&"grid_minor", Color(1.0, 1.0, 1.0, 0.02))
	graph_edit.add_theme_color_override(&"selection_fill", Color(0.35, 0.55, 0.95, 0.25))
	graph_edit.add_theme_color_override(&"selection_stroke", Color(0.55, 0.75, 1.0, 0.8))
	graph_edit.add_theme_color_override(&"connection_color", DMGraphNodeTheme.CONNECTION_COLOR)
	graph_edit.add_theme_color_override(&"connection_fill_color", DMGraphNodeTheme.CONNECTION_COLOR)
	if graph_edit.has_theme_color(&"connection_outline_color", &"GraphEdit"):
		graph_edit.add_theme_color_override(&"connection_outline_color", DMGraphNodeTheme.CONNECTION_COLOR)
	if graph_edit.has_theme_constant(&"connection_hover_thickness", &"GraphEdit"):
		graph_edit.add_theme_constant_override(&"connection_hover_thickness", 100)
	if graph_edit.has_theme_color(&"connection_hover_tint_color", &"GraphEdit"):
		graph_edit.add_theme_color_override(&"connection_hover_tint_color", Color(1.0, 1.0, 1.0, 0.18))
	if graph_edit.has_theme_constant(&"connection_curvature", &"GraphEdit"):
		graph_edit.add_theme_constant_override(&"connection_curvature", DMGraphNodeTheme.CONNECTION_CURVATURE)


func _on_connection_hovered(connection: Dictionary) -> void:
	if not is_instance_valid(connection_status):
		return
	connection_status.text = _format_connection_label(connection)


func _on_connection_hover_cleared() -> void:
	if is_instance_valid(connection_status):
		connection_status.text = ""


func _format_connection_label(connection: Dictionary) -> String:
	var from_id: String = str(connection.get("from_node", ""))
	var to_id: String = str(connection.get("to_node", ""))
	from_id = _resolve_visual_node_id(from_id)
	to_id = _resolve_visual_node_id(to_id)
	return "%s  →  %s" % [_describe_graph_node(from_id), _describe_graph_node(to_id)]


func _describe_graph_node(node_id: String) -> String:
	if not _graph_nodes.has(node_id):
		return node_id
	var gn: Node = _graph_nodes[node_id]
	if gn is DMGraphCompactNode:
		var compact: DMGraphCompactNode = gn as DMGraphCompactNode
		if compact.node_data.get("type", "") == DMConstants.TYPE_CUE:
			return "Cue: %s" % compact.node_data.get("cue_name", "")
		return "End"
	if gn is DMGraphNode:
		return (gn as DMGraphNode).title
	if gn is DMGraphResponseGroupNode:
		return (gn as DMGraphResponseGroupNode).title
	if gn is DMGraphConditionGroupNode:
		return (gn as DMGraphConditionGroupNode).title
	return node_id





func load_from_text(text: String, path: String, saved_layouts: Dictionary = {}, active_cue: String = "") -> void:
	file_path = path
	_is_updating = true
	_connection_refresh_attempts = 0
	_clear_undo_history()
	clear_graph_ui()

	_full_document = DMGraphTreeBuilder.build_from_text(text, path)
	_all_layouts = DMGraphCueFilter.normalize_saved_layouts(saved_layouts, _full_document)

	var cue_names: Array[String] = DMGraphCueFilter.get_ordered_cue_names(_full_document)
	if active_cue == "" or not active_cue in cue_names:
		active_cue = cue_names[0] if cue_names.size() > 0 else ""

	if active_cue != "":
		_show_cue(active_cue, false)
	else:
		document = _full_document.duplicate()
		_populate_graph()

	_update_file_inspector()


func _finish_populating() -> void:
	_refresh_palette_menu()
	if _skip_auto_layout_on_populate:
		_skip_auto_layout_on_populate = false
		call_deferred("_end_populate_positions_only")
	else:
		call_deferred("_layout_graph_nodes_pass_1")


func _end_populate_positions_only() -> void:
	_apply_document_positions_to_nodes()
	_collapse_duplicate_goto_positions()
	call_deferred("_connect_after_layout_pass_1")


func _ensure_all_graph_ports_ready() -> void:
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if not is_instance_valid(gn):
			continue
		if gn is DMGraphResponseGroupNode:
			(gn as DMGraphResponseGroupNode).ensure_ports_ready()
		elif gn is DMGraphConditionGroupNode:
			(gn as DMGraphConditionGroupNode).ensure_ports_ready()
		elif gn is DMGraphCompactNode:
			(gn as DMGraphCompactNode).ensure_ports_ready()
		elif gn is DMGraphNode:
			(gn as DMGraphNode).ensure_ports_ready()


func _layout_graph_nodes_pass_1() -> void:
	# Wait two frames so GraphNode rows and minimum sizes finish building.
	call_deferred("_layout_graph_nodes_pass_2")


func _layout_graph_nodes_pass_2() -> void:
	call_deferred("_layout_graph_nodes")


func _layout_graph_nodes() -> void:
	for id: String in document.nodes:
		document.nodes[id].position = Vector2.ZERO
		document.nodes[id].layout_hidden = false

	for alias_id: String in _goto_visual_aliases:
		if document.has_node(alias_id):
			document.nodes[alias_id].layout_hidden = true

	_finalize_graph_node_sizes()
	var visual_sizes: Dictionary = _collect_visual_sizes()
	DMGraphLayout.apply_with_sizes(document, visual_sizes, {})
	_apply_document_positions_to_nodes()
	_collapse_duplicate_goto_positions()
	call_deferred("_connect_after_layout_pass_1")


func _collapse_duplicate_goto_positions() -> void:
	for alias_id: String in _goto_visual_aliases:
		var canonical_id: String = _goto_visual_aliases[alias_id]
		if document.has_node(alias_id) and document.has_node(canonical_id):
			document.nodes[alias_id].position = document.nodes[canonical_id].position


func _connect_after_layout_pass_1() -> void:
	_finalize_graph_node_sizes()
	_ensure_all_graph_ports_ready()
	call_deferred("_connect_after_layout_pass_2")


func _connect_after_layout_pass_2() -> void:
	call_deferred("_finalize_graph_connections")


func _finalize_graph_connections() -> void:
	_finalize_graph_node_sizes()
	_ensure_all_graph_ports_ready()
	_refresh_graph_connections()
	graph_edit.queue_redraw()
	if _count_missing_graph_connections() > 0 and _connection_refresh_attempts < 12:
		_connection_refresh_attempts += 1
		call_deferred("_finalize_graph_connections")
		return
	_connection_refresh_attempts = 0
	call_deferred("_end_populating")


func _finalize_graph_node_sizes() -> void:
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if not is_instance_valid(gn):
			continue
		if gn is DMGraphResponseGroupNode:
			(gn as DMGraphResponseGroupNode).finalize_layout_size()
		elif gn is DMGraphConditionGroupNode:
			(gn as DMGraphConditionGroupNode).finalize_layout_size()
		elif gn is DMGraphCompactNode:
			(gn as DMGraphCompactNode).ensure_ports_ready()
		elif gn is DMGraphNode:
			(gn as DMGraphNode)._finalize_content_size()


func _collect_visual_sizes() -> Dictionary:
	var sizes: Dictionary = {}
	for id: String in _graph_nodes:
		var gn: GraphNode = _graph_nodes[id] as GraphNode
		if not is_instance_valid(gn):
			continue

		var width: float = maxf(gn.custom_minimum_size.x, gn.size.x)
		var height: float = maxf(gn.custom_minimum_size.y, gn.size.y)
		if gn is DMGraphResponseGroupNode:
			height = maxf(height, gn.get_combined_minimum_size().y)
			width = maxf(width, gn.get_combined_minimum_size().x)
		elif gn is DMGraphConditionGroupNode:
			height = maxf(height, gn.get_combined_minimum_size().y)
			width = maxf(width, gn.get_combined_minimum_size().x)
		elif gn is DMGraphCompactNode:
			height = maxf(height, gn.get_combined_minimum_size().y)
			width = maxf(width, gn.get_combined_minimum_size().x)
		elif gn is DMGraphNode:
			height = maxf(height, gn.get_combined_minimum_size().y)
			width = maxf(width, gn.get_combined_minimum_size().x)

		var min_width: float = 120.0 if gn is DMGraphCompactNode else 280.0
		var min_height: float = 32.0 if gn is DMGraphCompactNode else 100.0
		var node_size: Vector2 = Vector2(maxf(width, min_width), maxf(height, min_height))
		sizes[id] = node_size

		if gn is DMGraphResponseGroupNode:
			var group: DMGraphResponseGroupNode = gn as DMGraphResponseGroupNode
			for row: Dictionary in group.response_rows:
				sizes[row.id] = node_size
		elif gn is DMGraphConditionGroupNode:
			var condition_group: DMGraphConditionGroupNode = gn as DMGraphConditionGroupNode
			for row: Dictionary in condition_group.branch_rows:
				sizes[row.id] = node_size

	return sizes


func _apply_document_positions_to_nodes() -> void:
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if gn is DMGraphResponseGroupNode:
			var group: DMGraphResponseGroupNode = gn as DMGraphResponseGroupNode
			if group.response_rows.size() > 0:
				var first_id: String = group.response_rows[0].id
				if document.has_node(first_id):
					group.position_offset = document.nodes[first_id].position
		elif gn is DMGraphConditionGroupNode:
			var condition_group: DMGraphConditionGroupNode = gn as DMGraphConditionGroupNode
			if condition_group.branch_rows.size() > 0:
				var first_branch_id: String = condition_group.branch_rows[0].id
				if document.has_node(first_branch_id):
					condition_group.position_offset = document.nodes[first_branch_id].position
		elif document.has_node(id):
			gn.position_offset = document.nodes[id].position


func _refresh_graph_connections() -> void:
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	_connect_all_nodes()


func _end_populating() -> void:
	_refresh_goto_cue_options()
	_is_updating = false
	call_deferred("_refresh_connections_when_ready")


func _refresh_connections_when_ready() -> void:
	if _is_updating:
		call_deferred("_refresh_connections_when_ready")
		return
	if not is_visible_in_tree() or not is_instance_valid(graph_edit):
		if _connection_refresh_attempts < 12:
			_connection_refresh_attempts += 1
			call_deferred("_refresh_connections_when_ready")
		else:
			_connection_refresh_attempts = 0
		return

	_ensure_all_graph_ports_ready()
	_refresh_graph_connections()
	graph_edit.queue_redraw()
	if _count_missing_graph_connections() > 0 and _connection_refresh_attempts < 12:
		_connection_refresh_attempts += 1
		call_deferred("_refresh_connections_when_ready")
		return
	_connection_refresh_attempts = 0


func _refresh_goto_cue_options() -> void:
	var cue_names: Array[String] = []
	if _full_document != null:
		cue_names = DMGraphCueFilter.get_ordered_cue_names(_full_document)
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if gn is DMGraphNode:
			(gn as DMGraphNode).set_available_cues(cue_names)





func serialize_to_text() -> String:
	if not _is_updating:
		_persist_active_cue_layout()
	if _full_document != null:
		return DMGraphTextSerializer.serialize(_full_document)
	_sync_document_from_graph()
	return DMGraphTextSerializer.serialize(document)


func is_busy() -> bool:
	return _is_updating


func get_layout() -> Dictionary:
	_persist_active_cue_layout()
	return _all_layouts.duplicate(true)


func get_active_cue_name() -> String:
	return _active_cue_name


func select_cue(cue_name: String) -> void:
	if _full_document == null or cue_name == _active_cue_name:
		return
	if not _full_document.cue_map.has(cue_name):
		return
	_show_cue(cue_name, true)





func get_selected_graph_nodes() -> Array[GraphNode]:
	var result: Array[GraphNode] = []
	for child: Node in graph_edit.get_children():
		if child is GraphNode and child.selected:
			result.append(child)
	return result





func clear_graph_ui() -> void:
	for conn: Dictionary in graph_edit.get_connection_list():
		graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)

	var nodes_to_remove: Array[Node] = []
	for child: Node in graph_edit.get_children():
		if child is GraphNode:
			nodes_to_remove.append(child)
	for node: Node in nodes_to_remove:
		if node is GraphNode:
			DMGraphNodeHeaderControls.detach(node as GraphNode)
		graph_edit.remove_child(node)
		node.free()

	_graph_nodes.clear()
	_response_port_map.clear()
	_condition_port_map.clear()
	_goto_visual_aliases.clear()
	_goto_canonical_by_target.clear()


func clear_graph() -> void:
	clear_graph_ui()
	document.clear()
	_full_document = null
	_all_layouts.clear()
	_active_cue_name = ""





func apply_errors(errors: Array) -> void:

	var error_lines: Dictionary = {}

	for error: DMError in errors:

		error_lines[error.line_number] = true



	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		var line_num: int = -1
		if gn is DMGraphCompactNode:
			line_num = (gn as DMGraphCompactNode).node_data.get("line_number", -1)
		elif gn is DMGraphNode:
			line_num = (gn as DMGraphNode).node_data.get("line_number", -1)
		elif gn is DMGraphResponseGroupNode:
			var group: DMGraphResponseGroupNode = gn as DMGraphResponseGroupNode
			if group.response_rows.size() > 0:
				line_num = group.response_rows[0].get("line_number", -1)
		elif gn is DMGraphConditionGroupNode:
			var condition_group: DMGraphConditionGroupNode = gn as DMGraphConditionGroupNode
			if condition_group.branch_rows.size() > 0:
				line_num = condition_group.branch_rows[0].get("line_number", -1)
		if gn is DMGraphCompactNode:
			(gn as DMGraphCompactNode).has_errors = error_lines.has(line_num)
		elif gn is DMGraphNode:
			(gn as DMGraphNode).has_errors = error_lines.has(line_num)





func focus_cue(cue_name: String) -> void:
	if _full_document == null or not _full_document.cue_map.has(cue_name):
		return
	if cue_name != _active_cue_name:
		select_cue(cue_name)
	var node_id: String = document.cue_map.get(cue_name, "")
	if not _graph_nodes.has(node_id):
		return
	var gn: Node = _graph_nodes[node_id]
	if gn is DMGraphCompactNode:
		graph_edit.scroll_offset = (gn as DMGraphCompactNode).position_offset - graph_edit.size / 2
		_select_node_data((gn as DMGraphCompactNode).get_data())
	elif gn is DMGraphNode:
		graph_edit.scroll_offset = (gn as DMGraphNode).position_offset - graph_edit.size / 2
		_select_node(gn as DMGraphNode)
	elif gn is DMGraphResponseGroupNode:
		graph_edit.scroll_offset = (gn as DMGraphResponseGroupNode).position_offset - graph_edit.size / 2
	elif gn is DMGraphConditionGroupNode:
		graph_edit.scroll_offset = (gn as DMGraphConditionGroupNode).position_offset - graph_edit.size / 2


func _populate_graph() -> void:
	_response_port_map.clear()
	_goto_visual_aliases.clear()
	_goto_canonical_by_target.clear()

	var ordered_nodes: Array[Dictionary] = []
	for id: String in document.nodes:
		var node_data: Dictionary = document.nodes[id]
		if node_data.get("is_spacer", false):
			continue
		ordered_nodes.append(node_data)

	ordered_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.line_number < b.line_number
	)

	var response_groups_by_parent: Dictionary = _build_response_groups_by_parent(ordered_nodes)
	var condition_groups_by_first: Dictionary = _build_condition_groups_by_chain(ordered_nodes)
	var created_response_groups: Dictionary = {}
	var index: int = 0
	while index < ordered_nodes.size():
		var node_data: Dictionary = ordered_nodes[index]
		if node_data.type == DMConstants.TYPE_RESPONSE:
			var parent_id: String = node_data.get("parent_id", "")
			if not created_response_groups.has(parent_id):
				var group: Array[Dictionary] = _collect_response_group_rows(node_data, response_groups_by_parent)
				_create_response_group_node(group)
				created_response_groups[parent_id] = true
			index += 1
		elif node_data.type == DMConstants.TYPE_CONDITION:
			if condition_groups_by_first.has(node_data.id):
				_create_condition_group_node(condition_groups_by_first[node_data.id])
			index += 1
		else:
			if node_data.type == DMConstants.TYPE_GOTO:
				var target: String = str(node_data.get("goto_target", "")).strip_edges()
				if target != "" and _goto_canonical_by_target.has(target):
					_goto_visual_aliases[node_data.id] = _goto_canonical_by_target[target]
					index += 1
					continue
				_create_graph_node(node_data)
				if target != "":
					_goto_canonical_by_target[target] = node_data.id
			else:
				_create_graph_node(node_data)
			index += 1

	call_deferred("_finish_populating")


func _collect_response_group_rows(first_response: Dictionary, response_groups_by_parent: Dictionary) -> Array[Dictionary]:
	if _active_cue_name != "" and DMGraphCueFilter.is_response_menu_cue(document, _active_cue_name):
		var rows: Array[Dictionary] = []
		for response_id: String in DMGraphCueFilter.get_section_response_ids(document, _active_cue_name):
			if document.has_node(response_id):
				rows.append(document.nodes[response_id])
		if rows.size() > 0:
			return rows

	var parent_id: String = first_response.get("parent_id", "")
	if response_groups_by_parent.has(parent_id):
		return response_groups_by_parent[parent_id]

	return [first_response]


func _build_response_groups_by_parent(ordered_nodes: Array[Dictionary]) -> Dictionary:
	var by_parent: Dictionary = {}
	for node_data: Dictionary in ordered_nodes:
		if node_data.type != DMConstants.TYPE_RESPONSE:
			continue
		var parent_id: String = node_data.get("parent_id", "")
		if not by_parent.has(parent_id):
			by_parent[parent_id] = [] as Array[Dictionary]
		(by_parent[parent_id] as Array[Dictionary]).append(node_data)

	for parent_id: String in by_parent:
		var group: Array[Dictionary] = by_parent[parent_id]
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.line_number < b.line_number
		)
	return by_parent


func _build_condition_groups_by_chain(ordered_nodes: Array[Dictionary]) -> Dictionary:
	var groups_by_first: Dictionary = {}
	var index: int = 0
	while index < ordered_nodes.size():
		if ordered_nodes[index].type != DMConstants.TYPE_CONDITION:
			index += 1
			continue
		var chain: Array[Dictionary] = []
		while index < ordered_nodes.size() and ordered_nodes[index].type == DMConstants.TYPE_CONDITION:
			chain.append(ordered_nodes[index])
			index += 1
		if chain.size() > 0:
			groups_by_first[chain[0].id] = chain
	return groups_by_first


func _create_response_group_node(responses: Array[Dictionary]) -> DMGraphResponseGroupNode:
	var group_node: DMGraphResponseGroupNode = ResponseGroupScene.instantiate()
	var node_position: Vector2 = responses[0].get("position", Vector2.ZERO)
	group_node.content_changed.connect(_on_response_group_changed.bind(group_node))
	group_node.add_response_requested.connect(_on_response_group_add_requested.bind(group_node))
	group_node.group_rebuilt.connect(_on_response_group_rebuilt.bind(group_node))
	graph_edit.add_child(group_node)
	group_node.setup_group(responses, node_position)

	var group_id: String = group_node.get_group_id()
	_graph_nodes[group_id] = group_node

	for i: int in range(0, responses.size()):
		_response_port_map[responses[i].id] = {
			group_id = group_id,
			port = i,
		}

	_attach_node_header_controls(group_node)
	return group_node


func _create_condition_group_node(branches: Array[Dictionary]) -> DMGraphConditionGroupNode:
	var group_node: DMGraphConditionGroupNode = ConditionGroupScene.instantiate()
	var node_position: Vector2 = branches[0].get("position", Vector2.ZERO)
	group_node.content_changed.connect(_on_condition_group_changed.bind(group_node))
	group_node.add_elif_requested.connect(_on_condition_group_add_elif_requested.bind(group_node))
	group_node.add_else_requested.connect(_on_condition_group_add_else_requested.bind(group_node))
	group_node.group_rebuilt.connect(_on_condition_group_rebuilt.bind(group_node))
	graph_edit.add_child(group_node)
	group_node.setup_group(branches, node_position)

	var group_id: String = group_node.get_group_id()
	_graph_nodes[group_id] = group_node

	for i: int in range(0, branches.size()):
		_condition_port_map[branches[i].id] = {
			group_id = group_id,
			port = i,
		}

	_attach_node_header_controls(group_node)
	return group_node





func _create_graph_node(data: Dictionary) -> GraphNode:
	if data.type in [DMConstants.TYPE_CUE, DMConstants.TYPE_END]:
		return _create_compact_node(data)

	var gn: DMGraphNode = GraphNodeScene.instantiate()
	gn.content_changed.connect(_on_node_content_changed.bind(gn))
	graph_edit.add_child(gn)
	gn.setup(data)
	_graph_nodes[data.id] = gn
	_attach_node_header_controls(gn)
	return gn


func _create_compact_node(data: Dictionary) -> DMGraphCompactNode:
	var gn: DMGraphCompactNode = CompactNodeScene.instantiate()
	graph_edit.add_child(gn)
	gn.setup(data)
	_graph_nodes[data.id] = gn
	_attach_node_header_controls(gn, 24.0)
	return gn


func _attach_node_header_controls(gn: GraphNode, title_height: float = DMGraphNodeHeaderControls.DEFAULT_TITLE_HEIGHT) -> void:
	DMGraphNodeHeaderControls.attach(gn, _request_delete_node.bind(gn), title_height)


func _request_delete_node(gn: GraphNode) -> void:
	request_delete_nodes([gn])


## Returns true when a text field inside the graph has keyboard focus.
func is_editing_text() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner() as Control
	if not focus_owner or not is_instance_valid(graph_edit): return false
	if not graph_edit.is_ancestor_of(focus_owner): return false
	return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is CodeEdit


func request_delete_selected_nodes() -> void:
	request_delete_nodes(get_selected_graph_nodes())


## Opens a confirmation dialog before deleting graph nodes.
func request_delete_nodes(nodes: Array[GraphNode]) -> void:
	if nodes.is_empty() or not is_instance_valid(_delete_confirm_dialog): return
	_pending_delete_nodes = nodes.duplicate()
	if _pending_delete_nodes.size() == 1:
		_delete_confirm_dialog.dialog_text = "Delete \"%s\"?" % _describe_graph_node(_pending_delete_nodes[0].name)
	else:
		_delete_confirm_dialog.dialog_text = "Delete %d selected nodes?" % _pending_delete_nodes.size()
	_delete_confirm_dialog.popup_centered()


func _on_delete_nodes_confirmed() -> void:
	if _pending_delete_nodes.is_empty(): return
	_begin_immediate_undo()
	for gn: GraphNode in _pending_delete_nodes:
		if is_instance_valid(gn):
			_delete_visual_node(gn)
	_pending_delete_nodes.clear()
	_persist_active_cue_layout()
	_refresh_palette_menu()
	_commit_immediate_undo("Delete nodes")
	document_changed.emit()


## Removes a visual node, its connections, and matching document entries.
func _delete_visual_node(gn: GraphNode) -> void:
	if not is_instance_valid(gn): return
	DMGraphNodeHeaderControls.detach(gn)
	var visual_name: String = gn.name
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == visual_name or conn.to_node == visual_name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)

	var document_ids: Array[String] = _collect_document_ids_for_visual_node(gn)
	for id: String in document_ids:
		_response_port_map.erase(id)
		_condition_port_map.erase(id)
		_remove_document_node(id)

	if gn is DMGraphResponseGroupNode:
		_graph_nodes.erase((gn as DMGraphResponseGroupNode).get_group_id())
	elif gn is DMGraphConditionGroupNode:
		_graph_nodes.erase((gn as DMGraphConditionGroupNode).get_group_id())
	elif gn is DMGraphNode:
		_graph_nodes.erase((gn as DMGraphNode).node_data.id)
	elif gn is DMGraphCompactNode:
		_graph_nodes.erase((gn as DMGraphCompactNode).node_data.id)

	graph_edit.remove_child(gn)
	gn.queue_free()

	if is_instance_valid(inspector):
		inspector.clear_inspection()


func _collect_document_ids_for_visual_node(gn: GraphNode) -> Array[String]:
	var ids: Array[String] = []
	if gn is DMGraphResponseGroupNode:
		ids.assign((gn as DMGraphResponseGroupNode).get_response_ids())
	elif gn is DMGraphConditionGroupNode:
		ids.assign((gn as DMGraphConditionGroupNode).get_branch_ids())
	elif gn is DMGraphNode:
		ids.append((gn as DMGraphNode).node_data.id)
	elif gn is DMGraphCompactNode:
		ids.append((gn as DMGraphCompactNode).node_data.id)
	return ids


func _remove_document_node(id: String) -> void:
	if document.has_node(id):
		var node_data: Dictionary = document.nodes[id]
		if node_data.get("type", "") == DMConstants.TYPE_CUE:
			var cue_name: String = node_data.get("cue_name", "")
			if cue_name != "":
				document.cue_map.erase(cue_name)
		document.remove_node(id)
	if _full_document and _full_document.has_node(id):
		var full_node: Dictionary = _full_document.nodes[id]
		if full_node.get("type", "") == DMConstants.TYPE_CUE:
			var full_cue_name: String = full_node.get("cue_name", "")
			if full_cue_name != "":
				_full_document.cue_map.erase(full_cue_name)
		_full_document.remove_node(id)





func _connect_all_nodes() -> void:
	var group_inputs_connected: Dictionary = {}
	var condition_inputs_connected: Dictionary = {}

	for conn: Dictionary in document.connections:
		var from_id: String = conn.from_node
		var to_id: String = conn.to_node
		var kind: String = conn.get("kind", "sequence")

		if kind == "branch" and _condition_port_map.has(from_id) and _condition_port_map.has(to_id):
			continue

		if _response_port_map.has(to_id) and kind == "branch":
			var group_id: String = _response_port_map[to_id].group_id
			if not group_inputs_connected.has(group_id):
				_connect_graph_ports(from_id, 0, group_id, 0)
				group_inputs_connected[group_id] = true
			continue

		if _response_port_map.has(from_id) and kind == "body":
			var mapping: Dictionary = _response_port_map[from_id]
			_connect_graph_ports(mapping.group_id, mapping.port, to_id, 0)
			continue

		if _condition_port_map.has(to_id) and kind in ["sequence", "branch"]:
			var condition_mapping: Dictionary = _condition_port_map[to_id]
			if condition_mapping.port == 0 and not condition_inputs_connected.has(condition_mapping.group_id):
				_connect_graph_ports(from_id, 0, condition_mapping.group_id, 0)
				condition_inputs_connected[condition_mapping.group_id] = true
			continue

		if _condition_port_map.has(from_id) and kind == "body":
			var body_mapping: Dictionary = _condition_port_map[from_id]
			_connect_graph_ports(body_mapping.group_id, body_mapping.port, to_id, 0)
			continue

		if _response_port_map.has(to_id) or _response_port_map.has(from_id):
			continue

		if _condition_port_map.has(to_id) or _condition_port_map.has(from_id):
			continue

		_connect_graph_ports(from_id, 0, to_id, 0)


func _resolve_visual_node_id(node_id: String) -> String:
	while _goto_visual_aliases.has(node_id):
		node_id = _goto_visual_aliases[node_id]
	return node_id


func _count_missing_graph_connections() -> int:
	var expected: int = _count_expected_graph_connections()
	return maxi(0, expected - graph_edit.get_connection_list().size())


func _count_expected_graph_connections() -> int:
	var count: int = 0
	var group_inputs_connected: Dictionary = {}
	var condition_inputs_connected: Dictionary = {}

	for conn: Dictionary in document.connections:
		var from_id: String = conn.from_node
		var to_id: String = conn.to_node
		var kind: String = conn.get("kind", "sequence")

		if kind == "branch" and _condition_port_map.has(from_id) and _condition_port_map.has(to_id):
			continue

		if _response_port_map.has(to_id) and kind == "branch":
			var group_id: String = _response_port_map[to_id].group_id
			if not group_inputs_connected.has(group_id):
				if _can_connect_graph_ports(from_id, 0, group_id, 0):
					count += 1
				group_inputs_connected[group_id] = true
			continue

		if _response_port_map.has(from_id) and kind == "body":
			var mapping: Dictionary = _response_port_map[from_id]
			if _can_connect_graph_ports(mapping.group_id, mapping.port, to_id, 0):
				count += 1
			continue

		if _condition_port_map.has(to_id) and kind in ["sequence", "branch"]:
			var condition_mapping: Dictionary = _condition_port_map[to_id]
			if condition_mapping.port == 0 and not condition_inputs_connected.has(condition_mapping.group_id):
				if _can_connect_graph_ports(from_id, 0, condition_mapping.group_id, 0):
					count += 1
				condition_inputs_connected[condition_mapping.group_id] = true
			continue

		if _condition_port_map.has(from_id) and kind == "body":
			var body_mapping: Dictionary = _condition_port_map[from_id]
			if _can_connect_graph_ports(body_mapping.group_id, body_mapping.port, to_id, 0):
				count += 1
			continue

		if _response_port_map.has(to_id) or _response_port_map.has(from_id):
			continue

		if _condition_port_map.has(to_id) or _condition_port_map.has(from_id):
			continue

		if _can_connect_graph_ports(from_id, 0, to_id, 0):
			count += 1

	return count


func _can_connect_graph_ports(from_node: String, from_port: int, to_node: String, to_port: int) -> bool:
	from_node = _resolve_visual_node_id(from_node)
	to_node = _resolve_visual_node_id(to_node)
	if not _graph_nodes.has(from_node) or not _graph_nodes.has(to_node):
		return false
	if not is_instance_valid(_graph_nodes[from_node]) or not is_instance_valid(_graph_nodes[to_node]):
		return false

	var from_gn: GraphNode = _graph_nodes[from_node] as GraphNode
	var to_gn: GraphNode = _graph_nodes[to_node] as GraphNode
	if from_gn is DMGraphResponseGroupNode and not (from_gn as DMGraphResponseGroupNode).is_structure_ready():
		return false
	if to_gn is DMGraphResponseGroupNode and not (to_gn as DMGraphResponseGroupNode).is_structure_ready():
		return false
	if from_gn is DMGraphConditionGroupNode and not (from_gn as DMGraphConditionGroupNode).is_structure_ready():
		return false
	if to_gn is DMGraphConditionGroupNode and not (to_gn as DMGraphConditionGroupNode).is_structure_ready():
		return false
	if not _node_has_output_port(from_gn, from_port):
		return false
	if not _node_has_input_port(to_gn, to_port):
		return false
	return true


func _connect_graph_ports(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	if not _can_connect_graph_ports(from_node, from_port, to_node, to_port):
		return

	from_node = _resolve_visual_node_id(from_node)
	to_node = _resolve_visual_node_id(to_node)

	var from: StringName = StringName(from_node)
	var to: StringName = StringName(to_node)

	for conn: Dictionary in graph_edit.get_connection_list():
		if conn.from_node == from and conn.from_port == from_port and conn.to_node == to and conn.to_port == to_port:
			return

	graph_edit.connect_node(from, from_port, to, to_port)


func _node_has_output_port(gn: GraphNode, port: int) -> bool:
	if port < 0:
		return false
	if gn is DMGraphCompactNode:
		return (gn as DMGraphCompactNode).has_output_port(port)
	if gn is DMGraphResponseGroupNode:
		return (gn as DMGraphResponseGroupNode).has_output_port(port)
	if gn is DMGraphConditionGroupNode:
		return (gn as DMGraphConditionGroupNode).has_output_port(port)
	if gn is DMGraphNode:
		var node_type: String = (gn as DMGraphNode).node_data.get("type", "")
		if node_type == DMConstants.TYPE_GOTO:
			return false
		return port == 0
	return port == 0


func _node_has_input_port(gn: GraphNode, port: int) -> bool:
	if port != 0:
		return false
	if gn is DMGraphCompactNode:
		return (gn as DMGraphCompactNode).has_input_port(port)
	if gn is DMGraphResponseGroupNode:
		return (gn as DMGraphResponseGroupNode).has_input_port(port)
	if gn is DMGraphConditionGroupNode:
		return (gn as DMGraphConditionGroupNode).has_input_port(port)
	if gn is DMGraphNode:
		return true
	return true





func _sync_document_from_graph() -> void:
	if _is_updating:
		return
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if gn is DMGraphResponseGroupNode:
			var group: DMGraphResponseGroupNode = gn as DMGraphResponseGroupNode
			group.sync_to_document_nodes(document)
			if _full_document != null:
				group.sync_to_document_nodes(_full_document)
			if group.response_rows.size() > 0:
				var pos: Vector2 = group.position_offset
				var first_id: String = group.response_rows[0].id
				document.nodes[first_id].position = pos
				if _full_document != null and _full_document.has_node(first_id):
					_full_document.nodes[first_id].position = pos
			continue
		if gn is DMGraphConditionGroupNode:
			var condition_group: DMGraphConditionGroupNode = gn as DMGraphConditionGroupNode
			condition_group.sync_to_document_nodes(document)
			if _full_document != null:
				condition_group.sync_to_document_nodes(_full_document)
			if condition_group.branch_rows.size() > 0:
				var condition_pos: Vector2 = condition_group.position_offset
				var first_branch_id: String = condition_group.branch_rows[0].id
				document.nodes[first_branch_id].position = condition_pos
				if _full_document != null and _full_document.has_node(first_branch_id):
					_full_document.nodes[first_branch_id].position = condition_pos
			continue
		if gn is DMGraphCompactNode:
			var compact_data: Dictionary = (gn as DMGraphCompactNode).get_data()
			document.nodes[id] = compact_data
			if _full_document != null and _full_document.has_node(id):
				_full_document.nodes[id] = compact_data
		elif gn is DMGraphNode:
			var data: Dictionary = (gn as DMGraphNode).get_data()
			document.nodes[id] = data
			if _full_document != null and _full_document.has_node(id):
				_full_document.nodes[id] = data



	if is_instance_valid(imports_edit):

		var imports: PackedStringArray = PackedStringArray([])

		for line: String in imports_edit.text.split("\n"):

			if line.strip_edges() != "":

				imports.append(line)

		document.imports = imports
		if _full_document != null:
			_full_document.imports = imports

	if is_instance_valid(using_edit):

		var using_states: PackedStringArray = PackedStringArray([])

		for part: String in using_edit.text.split(","):

			var state: String = part.strip_edges()

			if state != "":

				using_states.append(state)

		document.using_states = using_states
		if _full_document != null:
			_full_document.using_states = using_states





func _update_file_inspector() -> void:
	var source: DMGraphDocument = _full_document if _full_document != null else document
	if is_instance_valid(imports_edit):
		imports_edit.text = "\n".join(source.imports)
	if is_instance_valid(using_edit):
		using_edit.text = ", ".join(source.using_states)

	if is_instance_valid(file_label):
		if _full_document != null and _full_document.cue_map.size() > 0:
			file_label.text = "Cue: ~ %s" % _active_cue_name
		else:
			file_label.text = "File Properties"





func _select_node(gn: DMGraphNode) -> void:
	_select_node_data(gn.get_data())


func _select_node_data(data: Dictionary) -> void:
	if is_instance_valid(inspector):
		inspector.inspect(data)

	node_selected.emit(data)





func _generate_node_id() -> String:

	_next_id_counter += 1

	return "new_%d" % _next_id_counter





func _create_default_node_data(type: String) -> Dictionary:

	var id: String = _generate_node_id()

	var data: Dictionary = {

		id = id,

		type = type,

		text = "",

		line_number = 0,

		indent = 0,

		notes = "",

		is_random = false,

		parent_id = "",

		child_ids = [] as Array[String],

		position = graph_edit.scroll_offset + graph_edit.size / 2,

		cue_name = "new_cue",

		weight = 1,

		condition = "",

		is_snippet = false,

		goto_target = "",

		expression = "",

		mutation_blocking = true,

		static_id = "",

		tags = [] as PackedStringArray,

		character = "",

		concurrent_lines = [] as PackedStringArray,

		response_options = [] as Array[Dictionary],

		branches = [] as Array[Dictionary],

		is_spacer = false,

	}

	match type:

		DMConstants.TYPE_CUE:

			data.text = "~ new_cue"

		DMConstants.TYPE_DIALOGUE:

			data.text = "Character: Dialogue text"

			data.character = "Character"

		DMConstants.TYPE_RESPONSE:

			data.text = "- Option"

		DMConstants.TYPE_CONDITION:

			data.text = "if true"

			data.expression = "if true"
			data.branch_type = "if"

			data.branches = [{ id = id, type = "if", expression = "if true", child_ids = [] }]

		DMConstants.TYPE_WHILE:

			data.text = "while true"

			data.expression = "while true"

		DMConstants.TYPE_MATCH:

			data.text = "match value"

			data.expression = "match value"

		DMConstants.TYPE_MUTATION:

			data.text = "do something()"

			data.expression = "do something()"

		DMConstants.TYPE_GOTO:

			data.text = "=> some_cue"

			data.goto_target = "some_cue"

		DMConstants.TYPE_END:

			data.text = "=> END"

			data.goto_target = "END"

		DMConstants.TYPE_RANDOM:

			data.text = "% Character: Random line"

			data.is_random = true

	return data





func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:

	if _is_updating:

		return

	_begin_immediate_undo()

	graph_edit.connect_node(from_node, from_port, to_node, to_port)

	document.add_connection(str(from_node), "sequence", str(to_node), "input", "sequence")

	document_changed.emit()
	_commit_immediate_undo("Connect nodes")





func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:

	if _is_updating:

		return

	_begin_immediate_undo()

	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)

	document.connections = document.connections.filter(func(c: Dictionary) -> bool:

		return not (c.from_node == str(from_node) and c.to_node == str(to_node))

	)

	document_changed.emit()
	_commit_immediate_undo("Disconnect nodes")





func _on_node_content_changed(gn: DMGraphNode) -> void:

	if _is_updating:

		return

	_schedule_debounced_undo()

	document.nodes[gn.name] = gn.get_data()
	if _full_document != null and _full_document.has_node(gn.name):
		_full_document.nodes[gn.name] = gn.get_data()

	document_changed.emit()





func _section_has_node_type(type: String) -> bool:
	for id: String in document.nodes:
		if document.nodes[id].type == type:
			return true
	return false


## Returns false when the cue already has a singleton node type.
func _can_add_node_type(type: String) -> bool:
	if type == DMConstants.TYPE_END and _section_has_node_type(DMConstants.TYPE_END):
		return false
	if type == DMConstants.TYPE_CUE and _section_has_node_type(DMConstants.TYPE_CUE):
		return false
	return true


func _on_node_type_selected(type: String, spawn_position: Variant = null) -> void:
	if not _can_add_node_type(type):
		return

	_begin_immediate_undo()

	var data: Dictionary = _create_default_node_data(type)

	if spawn_position is Vector2:
		data.position = spawn_position
	else:
		data.position = graph_edit.scroll_offset + Vector2(100, 100)

	document.add_node(data)
	if _full_document != null:
		_full_document.add_node(data.duplicate(true))

	if type == DMConstants.TYPE_CONDITION:
		_create_condition_group_node([data])
		document_changed.emit()
		_commit_immediate_undo("Add node")
		return

	var gn: GraphNode = _create_graph_node(data)

	if type == DMConstants.TYPE_GOTO:
		_refresh_goto_cue_options()

	if gn is DMGraphNode:
		_select_node(gn as DMGraphNode)
	elif gn is DMGraphCompactNode:
		_select_node_data((gn as DMGraphCompactNode).get_data())

	document_changed.emit()
	_commit_immediate_undo("Add node")





func _on_auto_layout_pressed() -> void:
	var before_layout: Dictionary = _capture_undo_state()
	_sync_document_from_graph()
	for id: String in document.nodes:
		document.nodes[id].position = Vector2.ZERO
		document.nodes[id].layout_hidden = false
	for alias_id: String in _goto_visual_aliases:
		if document.has_node(alias_id):
			document.nodes[alias_id].layout_hidden = true
	_finalize_graph_node_sizes()
	var visual_sizes: Dictionary = _collect_visual_sizes()
	DMGraphLayout.apply_with_sizes(document, visual_sizes, {})
	_apply_document_positions_to_nodes()
	_collapse_duplicate_goto_positions()
	_ensure_all_graph_ports_ready()
	_refresh_graph_connections()
	graph_edit.queue_redraw()
	_persist_active_cue_layout()
	document_changed.emit()
	_register_undo_action("Auto layout", before_layout, _capture_undo_state())


func _persist_active_cue_layout() -> void:
	if _active_cue_name == "" or _is_updating:
		return
	_sync_document_from_graph()
	_all_layouts[_active_cue_name] = DMGraphLayout.extract_layout(document)


func _show_cue(cue_name: String, persist_previous: bool = true) -> void:
	if persist_previous and _active_cue_name != "":
		_persist_active_cue_layout()

	_active_cue_name = cue_name

	_is_updating = true
	_clear_undo_history()
	clear_graph_ui()

	document = DMGraphCueFilter.filter_document(_full_document, cue_name)

	_populate_graph()
	_update_file_inspector()

	if file_path != "":
		DMSettings.set_graph_active_cue(file_path, cue_name)


func _on_response_group_changed(group_node: DMGraphResponseGroupNode) -> void:
	if _is_updating:
		return
	_schedule_debounced_undo()
	group_node.sync_to_document_nodes(document)
	if _full_document != null:
		group_node.sync_to_document_nodes(_full_document)
	document_changed.emit()


func _on_response_group_add_requested(group_node: DMGraphResponseGroupNode) -> void:
	if _is_updating:
		return
	_begin_immediate_undo()
	var new_id: String = _generate_node_id()
	var new_response: Dictionary = _create_default_node_data(DMConstants.TYPE_RESPONSE)
	new_response.id = new_id
	var last_line: int = 0
	if group_node.response_rows.size() > 0:
		last_line = int(group_node.response_rows[-1].get("line_number", 0))
	new_response.line_number = last_line + 1
	new_response.text = "- New option"
	new_response.parent_id = group_node.response_rows[0].get("parent_id", "") if group_node.response_rows.size() > 0 else ""

	document.add_node(new_response)
	if _full_document != null:
		_full_document.add_node(new_response.duplicate(true))

	group_node.response_rows.append(new_response)
	group_node.setup_group(group_node.response_rows, group_node.position_offset)
	_response_port_map.clear()
	for i: int in range(0, group_node.response_rows.size()):
		_response_port_map[group_node.response_rows[i].id] = {
			group_id = group_node.get_group_id(),
			port = i,
		}
	_graph_nodes[group_node.get_group_id()] = group_node
	call_deferred("_refresh_graph_connections")
	document_changed.emit()
	_commit_immediate_undo("Add response")


func _on_response_group_rebuilt(_group_node: DMGraphResponseGroupNode) -> void:
	call_deferred("_refresh_connections_when_ready")


func _on_condition_group_changed(group_node: DMGraphConditionGroupNode) -> void:
	if _is_updating:
		return
	_schedule_debounced_undo()
	group_node.sync_to_document_nodes(document)
	if _full_document != null:
		group_node.sync_to_document_nodes(_full_document)
	document_changed.emit()


func _on_condition_group_add_elif_requested(group_node: DMGraphConditionGroupNode) -> void:
	if _is_updating:
		return
	_begin_immediate_undo()
	var new_branch: Dictionary = _create_default_node_data(DMConstants.TYPE_CONDITION)
	new_branch.text = "elif true"
	new_branch.expression = "true"
	new_branch.branch_type = "elif"
	var last_line: int = 0
	if group_node.branch_rows.size() > 0:
		last_line = int(group_node.branch_rows[-1].get("line_number", 0))
		new_branch.parent_id = group_node.branch_rows[0].get("parent_id", "")
	new_branch.line_number = last_line + 1

	var insert_index: int = group_node.branch_rows.size()
	for i: int in range(0, group_node.branch_rows.size()):
		if DMGraphConditionGroupNode.infer_branch_type(group_node.branch_rows[i], i) == "else":
			insert_index = i
			break

	document.add_node(new_branch)
	if _full_document != null:
		_full_document.add_node(new_branch.duplicate(true))

	group_node.branch_rows.insert(insert_index, new_branch)
	group_node.setup_group(group_node.branch_rows, group_node.position_offset)
	_rebuild_condition_port_map(group_node)
	document_changed.emit()
	_commit_immediate_undo("Add elif branch")


func _on_condition_group_add_else_requested(group_node: DMGraphConditionGroupNode) -> void:
	if _is_updating:
		return
	if group_node.has_else_branch():
		return

	_begin_immediate_undo()
	var new_branch: Dictionary = _create_default_node_data(DMConstants.TYPE_CONDITION)
	new_branch.text = "else"
	new_branch.expression = ""
	new_branch.branch_type = "else"
	var last_line: int = 0
	if group_node.branch_rows.size() > 0:
		last_line = int(group_node.branch_rows[-1].get("line_number", 0))
		new_branch.parent_id = group_node.branch_rows[0].get("parent_id", "")
	new_branch.line_number = last_line + 1

	document.add_node(new_branch)
	if _full_document != null:
		_full_document.add_node(new_branch.duplicate(true))

	group_node.branch_rows.append(new_branch)
	group_node.setup_group(group_node.branch_rows, group_node.position_offset)
	_rebuild_condition_port_map(group_node)
	document_changed.emit()
	_commit_immediate_undo("Add else branch")


func _rebuild_condition_port_map(group_node: DMGraphConditionGroupNode) -> void:
	for branch_id: String in group_node.get_branch_ids():
		_condition_port_map.erase(branch_id)
	for i: int in range(0, group_node.branch_rows.size()):
		_condition_port_map[group_node.branch_rows[i].id] = {
			group_id = group_node.get_group_id(),
			port = i,
		}
	_graph_nodes[group_node.get_group_id()] = group_node
	call_deferred("_refresh_graph_connections")


func _on_condition_group_rebuilt(_group_node: DMGraphConditionGroupNode) -> void:
	if _is_updating:
		return
	call_deferred("_refresh_graph_connections")





func _on_inspector_changed() -> void:

	var updated: Dictionary = inspector.get_updated_data()

	if updated.is_empty():

		return

	_schedule_debounced_undo()

	var id: String = updated.id

	if _graph_nodes.has(id):

		_graph_nodes[id].setup(updated)

		document.nodes[id] = updated
		if _full_document != null:
			_full_document.nodes[id] = updated

		document_changed.emit()





func _on_file_inspector_changed(_arg: Variant = null) -> void:

	if _is_updating:

		return

	_schedule_debounced_undo()

	_sync_document_from_graph()

	document_changed.emit()





func _on_insert_requested(text: String) -> void:

	for gn: DMGraphNode in _graph_nodes.values():

		var te: TextEdit = gn.get_node_or_null("%TextEdit")

		if te and te.has_focus():

			te.insert_text_at_caret(text)

			return





func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if not is_editing_text():
				request_delete_selected_nodes()
				graph_edit.accept_event()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_press_undo_before = _capture_undo_state()
			call_deferred("_check_selection")
		else:
			_try_commit_position_undo()
			_mouse_press_undo_before.clear()


## Opens the add node menu when right clicking empty graph canvas.
func _on_graph_popup_request(at_position: Vector2) -> void:
	if graph_edit.is_point_on_connection(at_position):
		return
	var graph_node: GraphNode = graph_edit.get_graph_node_at_local_point(at_position)
	if graph_node:
		_show_node_context_menu(graph_node, at_position)
		return
	_show_add_node_context_menu(at_position)


func _show_add_node_context_menu(at_position: Vector2) -> void:
	_context_menu_spawn_position = graph_edit.local_point_to_graph_position(at_position)
	DMGraphNodeIcons.populate_popup(_graph_context_menu, _can_add_node_type)
	if _graph_context_menu.item_count == 0: return
	_popup_menu_at_graph_point(_graph_context_menu, at_position)


func _show_node_context_menu(graph_node: GraphNode, at_position: Vector2) -> void:
	_context_menu_target_node = graph_node
	_node_context_menu.clear()
	_node_context_menu.add_item("Delete", 0)
	_popup_menu_at_graph_point(_node_context_menu, at_position)


func _popup_menu_at_graph_point(menu: PopupMenu, _at_position: Vector2) -> void:
	menu.reset_size()
	menu.global_position = graph_edit.get_global_mouse_position()
	menu.popup()


func _refresh_palette_menu() -> void:
	if is_instance_valid(palette):
		palette.rebuild_add_menu(_can_add_node_type)


func _on_graph_context_menu_id_pressed(id: int) -> void:
	var type: String = DMGraphNodeIcons.get_type_for_menu_id(_graph_context_menu, id)
	if type == "": return
	_on_node_type_selected(type, _context_menu_spawn_position)


func _on_node_context_menu_id_pressed(id: int) -> void:
	if id != 0 or not is_instance_valid(_context_menu_target_node): return
	request_delete_nodes([_context_menu_target_node])
	_context_menu_target_node = null


func _check_selection() -> void:
	var selected: Array[GraphNode] = get_selected_graph_nodes()
	if selected.size() == 1:
		var gn: GraphNode = selected[0]
		if gn is DMGraphNode:
			_select_node(gn as DMGraphNode)
		elif gn is DMGraphCompactNode:
			_select_node_data((gn as DMGraphCompactNode).get_data())
	elif selected.is_empty() and is_instance_valid(inspector):
		inspector.clear_inspection()


func undo() -> void:
	_undo_redo.undo()


func redo() -> void:
	_undo_redo.redo()


func _clear_undo_history() -> void:
	_undo_redo.clear_history(false)
	_debounced_undo_before.clear()
	if is_instance_valid(_undo_debounce_timer):
		_undo_debounce_timer.stop()


func _capture_undo_state() -> Dictionary:
	_sync_document_from_graph()
	return {
		"document": document.duplicate(),
		"full_document": _full_document.duplicate() if _full_document != null else null,
		"layouts": _all_layouts.duplicate(true),
		"active_cue": _active_cue_name,
	}


func _restore_undo_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	_is_undoing = true
	_is_updating = true
	_debounced_undo_before.clear()
	if is_instance_valid(_undo_debounce_timer):
		_undo_debounce_timer.stop()

	document = state.document.duplicate()
	if state.get("full_document") != null:
		_full_document = state.full_document.duplicate()
	_active_cue_name = state.get("active_cue", _active_cue_name)
	_all_layouts = state.get("layouts", {}).duplicate(true)

	_skip_auto_layout_on_populate = true
	clear_graph_ui()
	_populate_graph()
	_update_file_inspector()

	_is_updating = false
	_is_undoing = false
	document_changed.emit()


func _register_undo_action(action_name: String, before: Dictionary, after: Dictionary) -> void:
	if before.is_empty() or after.is_empty():
		return
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(_restore_undo_state.bind(after))
	_undo_redo.add_undo_method(_restore_undo_state.bind(before))
	_undo_redo.commit_action()


func _schedule_debounced_undo() -> void:
	if _is_undoing or _is_updating:
		return
	if _debounced_undo_before.is_empty():
		_debounced_undo_before = _capture_undo_state()
	if is_instance_valid(_undo_debounce_timer):
		_undo_debounce_timer.start()


func _begin_immediate_undo() -> void:
	if _is_undoing or _is_updating:
		return
	_debounced_undo_before = _capture_undo_state()
	if is_instance_valid(_undo_debounce_timer):
		_undo_debounce_timer.stop()


func _commit_immediate_undo(action_name: String) -> void:
	if _debounced_undo_before.is_empty() or _is_undoing or _is_updating:
		_debounced_undo_before.clear()
		return
	var before: Dictionary = _debounced_undo_before
	_debounced_undo_before.clear()
	_sync_document_from_graph()
	var after: Dictionary = _capture_undo_state()
	_register_undo_action(action_name, before, after)


func _commit_debounced_undo() -> void:
	if _debounced_undo_before.is_empty() or _is_undoing or _is_updating:
		_debounced_undo_before.clear()
		return
	var before: Dictionary = _debounced_undo_before
	_debounced_undo_before.clear()
	_sync_document_from_graph()
	var after: Dictionary = _capture_undo_state()
	_register_undo_action("Edit graph", before, after)


func _try_commit_position_undo() -> void:
	if _is_undoing or _is_updating or _mouse_press_undo_before.is_empty():
		return
	if not _node_positions_changed(_mouse_press_undo_before):
		return
	_sync_document_from_graph()
	var after: Dictionary = _capture_undo_state()
	_register_undo_action("Move nodes", _mouse_press_undo_before, after)


func _node_positions_changed(before_state: Dictionary) -> bool:
	for id: String in _graph_nodes:
		var gn: Node = _graph_nodes[id]
		if not is_instance_valid(gn) or not gn is GraphNode:
			continue
		var current_pos: Vector2 = (gn as GraphNode).position_offset
		var before_pos: Vector2 = _read_position_from_state(before_state, id)
		if before_pos.distance_to(current_pos) > 0.5:
			return true
	return false


func _read_position_from_state(state: Dictionary, graph_node_id: String) -> Vector2:
	var doc: DMGraphDocument = state.document
	if doc.has_node(graph_node_id):
		return doc.nodes[graph_node_id].position
	if not _graph_nodes.has(graph_node_id):
		return Vector2.ZERO
	var gn: Node = _graph_nodes[graph_node_id]
	if gn is DMGraphResponseGroupNode:
		var group: DMGraphResponseGroupNode = gn as DMGraphResponseGroupNode
		if group.response_rows.size() > 0 and doc.has_node(group.response_rows[0].id):
			return doc.nodes[group.response_rows[0].id].position
	elif gn is DMGraphConditionGroupNode:
		var condition_group: DMGraphConditionGroupNode = gn as DMGraphConditionGroupNode
		if condition_group.branch_rows.size() > 0 and doc.has_node(condition_group.branch_rows[0].id):
			return doc.nodes[condition_group.branch_rows[0].id].position
	return Vector2.ZERO


func _notification(what: int) -> void:

	if what == NOTIFICATION_THEME_CHANGED and is_instance_valid(palette):

		palette.apply_theme()
