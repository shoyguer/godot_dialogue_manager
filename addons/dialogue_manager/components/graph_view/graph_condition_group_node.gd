@tool
extends GraphNode
class_name DMGraphConditionGroupNode


signal content_changed()
signal add_elif_requested()
signal add_else_requested()
signal group_rebuilt()


const ROW_SEPARATION: int = 4
const MIN_EXPR_WIDTH: float = 200.0
const MAX_EXPR_WIDTH: float = 480.0
const PREFIX_WIDTH: float = 44.0
const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR


var group_data: Dictionary = {}
var branch_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false


func _ready() -> void:
	resizable = true
	DMGraphNodeTheme.apply_title(self, Color(0.2, 0.4, 0.7))


func setup_group(branches: Array[Dictionary], node_position: Vector2 = Vector2.ZERO) -> void:
	group_data = {
		id = "cg_%s" % branches[0].id if branches.size() > 0 else "cg_empty",
		type = "condition_group",
		branch_ids = [] as Array[String],
		position = node_position,
	}
	branch_rows = branches.duplicate(true)
	for i: int in range(0, branch_rows.size()):
		branch_rows[i].branch_type = infer_branch_type(branch_rows[i], i)

	name = group_data.id
	position_offset = node_position
	title = "Condition"

	if is_node_ready() and is_inside_tree():
		_rebuild_rows()
	else:
		call_deferred("_rebuild_rows")


func ensure_ports_ready() -> void:
	if not is_inside_tree() or branch_rows.is_empty():
		return
	if is_structure_ready():
		_configure_slots()
	else:
		_rebuild_rows()


func is_structure_ready() -> bool:
	return get_child_count() == branch_rows.size() + 1


static func infer_branch_type(row: Dictionary, index: int) -> String:
	if row.has("branch_type"):
		return row.branch_type
	var text: String = row.get("text", "").strip_edges().to_lower()
	if text == "else":
		return "else"
	if text.begins_with("elif ") or text.begins_with("else if "):
		return "elif"
	if index == 0:
		return "if"
	return "elif"


static func extract_expression(row: Dictionary, branch_type: String) -> String:
	if branch_type == "else":
		return ""
	var text: String = row.get("text", row.get("expression", "")).strip_edges()
	match branch_type:
		"if":
			return text.trim_prefix("if ").strip_edges()
		"elif":
			if text.begins_with("else if "):
				return text.substr(8).strip_edges()
			return text.trim_prefix("elif ").strip_edges()
		_:
			return text


static func format_branch_text(branch_type: String, expression: String) -> String:
	match branch_type:
		"if":
			return "if %s" % expression.strip_edges()
		"elif":
			return "elif %s" % expression.strip_edges()
		"else":
			return "else"
		_:
			return expression


func get_group_id() -> String:
	return group_data.get("id", name)


func has_output_port(port: int) -> bool:
	return port >= 0 and port < branch_rows.size() and is_structure_ready()


func has_input_port(port: int) -> bool:
	return port == 0 and is_structure_ready()


func get_branch_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in branch_rows:
		ids.append(row.id)
	return ids


func has_else_branch() -> bool:
	for i: int in range(0, branch_rows.size()):
		if infer_branch_type(branch_rows[i], i) == "else":
			return true
	return false


func sync_to_document_nodes(document: DMGraphDocument) -> void:
	_sync_from_fields()
	for row: Dictionary in branch_rows:
		if document.has_node(row.id):
			document.nodes[row.id] = row.duplicate(true)


func finalize_layout_size() -> void:
	if not is_inside_tree():
		return
	var max_row_width: float = MIN_EXPR_WIDTH
	for i: int in range(0, branch_rows.size()):
		if i < get_child_count():
			var row: Control = get_child(i) as Control
			if row and not row.name.begins_with("Actions"):
				max_row_width = maxf(max_row_width, row.custom_minimum_size.x)
	_update_minimum_size(max_row_width)


func _disconnect_own_connections() -> void:
	var graph_edit: GraphEdit = get_parent() as GraphEdit
	if graph_edit == null:
		return
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == name or conn.to_node == name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _configure_slots() -> void:
	var child_count: int = get_child_count()
	var slot_index: int = 0
	for i: int in range(0, branch_rows.size()):
		if slot_index < child_count:
			set_slot(slot_index, slot_index == 0, 0, PORT_COLOR, true, 0, PORT_COLOR)
			slot_index += 1
	if slot_index < child_count:
		set_slot(slot_index, false, 0, PORT_COLOR, false, 0, PORT_COLOR)


func _rebuild_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return

	_is_rebuilding = true
	_disconnect_own_connections()

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	group_data.branch_ids = [] as Array[String]
	var max_row_width: float = MIN_EXPR_WIDTH
	var slot_index: int = 0

	for i: int in range(0, branch_rows.size()):
		var row_data: Dictionary = branch_rows[i]
		var branch_type: String = infer_branch_type(row_data, i)
		row_data.branch_type = branch_type
		group_data.branch_ids.append(row_data.id)

		var row_control: Control = _create_branch_row(row_data, branch_type, i)
		add_child(row_control)
		max_row_width = maxf(max_row_width, row_control.custom_minimum_size.x)
		set_slot(slot_index, slot_index == 0, 0, PORT_COLOR, true, 0, PORT_COLOR)
		slot_index += 1

	var actions_row: HBoxContainer = _create_actions_row()
	add_child(actions_row)
	set_slot(slot_index, false, 0, PORT_COLOR, false, 0, PORT_COLOR)

	_update_minimum_size(max_row_width)
	_is_rebuilding = false
	group_rebuilt.emit()


func _create_branch_row(row_data: Dictionary, branch_type: String, _index: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", ROW_SEPARATION)

	var prefix: Label = Label.new()
	prefix.custom_minimum_size = Vector2(PREFIX_WIDTH, 0)
	prefix.text = branch_type.capitalize()
	DMGraphNodeTheme.apply_muted_label(prefix)
	row.add_child(prefix)

	if branch_type == "else":
		var else_label: Label = Label.new()
		else_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else_label.text = "..."
		DMGraphNodeTheme.apply_muted_label(else_label)
		row.add_child(else_label)
		row.custom_minimum_size = Vector2(PREFIX_WIDTH + 80.0, 28.0)
		return row

	var expression: String = extract_expression(row_data, branch_type)
	var expr_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	expr_edit.name = "ExpressionEdit"
	expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_edit.set_line_type(DMConstants.TYPE_CONDITION)
	expr_edit.placeholder_text = "expression"
	expr_edit.set_text_silent(expression)
	expr_edit.text_modified.connect(_on_field_changed.bind(row_data.id))
	row.add_child(expr_edit)

	var expr_width: float = maxf(MIN_EXPR_WIDTH, mini(float(expression.length()) * 7.0 + 40.0, MAX_EXPR_WIDTH))
	expr_edit.custom_minimum_size = Vector2(expr_width, 28.0)
	row.custom_minimum_size = Vector2(PREFIX_WIDTH + expr_width + 8.0, 28.0)
	row.set_meta("branch_id", row_data.id)
	return row


func _create_actions_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ActionsRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_elif_button: Button = Button.new()
	add_elif_button.text = "Add elif"
	add_elif_button.focus_mode = Control.FOCUS_NONE
	add_elif_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_elif_button.pressed.connect(_on_add_elif_pressed)
	call_deferred("_apply_add_icon", add_elif_button)
	row.add_child(add_elif_button)

	if not has_else_branch():
		var add_else_button: Button = Button.new()
		add_else_button.text = "Add else"
		add_else_button.focus_mode = Control.FOCUS_NONE
		add_else_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_else_button.pressed.connect(_on_add_else_pressed)
		call_deferred("_apply_add_icon", add_else_button)
		row.add_child(add_else_button)

	return row


func _apply_add_icon(button: Button) -> void:
	if not is_instance_valid(button) or not is_inside_tree():
		return
	if has_theme_icon(&"Add", &"EditorIcons"):
		button.icon = get_theme_icon(&"Add", &"EditorIcons")


func _on_add_elif_pressed() -> void:
	add_elif_requested.emit()


func _on_add_else_pressed() -> void:
	add_else_requested.emit()


func _on_field_changed(_value: String, branch_id: String) -> void:
	_sync_row_from_fields(branch_id)
	content_changed.emit()


func _sync_from_fields() -> void:
	for row: Dictionary in branch_rows:
		_sync_row_from_fields(row.id)


func _sync_row_from_fields(branch_id: String) -> void:
	var row_index: int = _find_row_index(branch_id)
	if row_index == -1:
		return

	var row_node: HBoxContainer = get_child(row_index) as HBoxContainer
	if not row_node: return

	var branch_type: String = infer_branch_type(branch_rows[row_index], row_index)
	var expression: String = ""
	var expr_edit: DMGraphExpressionField = row_node.get_node_or_null("ExpressionEdit") as DMGraphExpressionField
	if is_instance_valid(expr_edit):
		expression = expr_edit.text.strip_edges()

	for branch_data: Dictionary in branch_rows:
		if branch_data.id != branch_id:
			continue
		branch_data.branch_type = branch_type
		branch_data.expression = expression
		branch_data.text = format_branch_text(branch_type, expression)
		break


func _find_row_index(branch_id: String) -> int:
	for i: int in range(0, branch_rows.size()):
		if branch_rows[i].id == branch_id:
			return i
	return -1


func _update_minimum_size(content_width: float = 300.0) -> void:
	var total_height: float = 12.0
	for i: int in range(0, branch_rows.size()):
		if i < get_child_count():
			var row: Control = get_child(i) as Control
			if row and row.name != "ActionsRow":
				total_height += maxf(28.0, row.custom_minimum_size.y) + float(ROW_SEPARATION)
	total_height += 36.0
	custom_minimum_size = Vector2(maxf(280.0, content_width + PREFIX_WIDTH + 16.0), total_height + DMGraphNodeTheme.NODE_BOTTOM_MARGIN)
