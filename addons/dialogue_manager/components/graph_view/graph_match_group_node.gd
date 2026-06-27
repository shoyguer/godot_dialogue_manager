@tool
extends GraphNode
class_name DMGraphMatchGroupNode


signal content_changed()
signal add_when_requested()
signal add_else_requested()
signal group_rebuilt()


const ROW_SEPARATION: int = 4
const MIN_EXPR_WIDTH: float = 200.0
const MAX_EXPR_WIDTH: float = 480.0
const PREFIX_WIDTH: float = 52.0
const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR


var group_data: Dictionary = {}
var match_row: Dictionary = {}
var case_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false


func _ready() -> void:
	resizable = true
	var accent: Color = DMGraphNodeTheme.get_accent_for_type(DMConstants.TYPE_MATCH)
	DMGraphNodeTheme.apply_title(self, accent)
	title = "Match"


func setup_group(match_data: Dictionary, cases: Array[Dictionary], node_position: Vector2 = Vector2.ZERO) -> void:
	match_row = match_data.duplicate(true)
	case_rows = cases.duplicate(true)
	group_data = {
		id = "mg_%s" % match_data.id if not match_data.is_empty() else "mg_empty",
		type = "match_group",
		match_id = match_data.get("id", ""),
		case_ids = [] as Array[String],
		position = node_position,
	}
	name = group_data.id
	position_offset = node_position
	var accent: Color = DMGraphNodeTheme.get_accent_for_type(DMConstants.TYPE_MATCH)
	DMGraphNodeTheme.apply_title(self, accent)
	title = "Match"

	if is_node_ready() and is_inside_tree():
		_rebuild_rows()
	else:
		call_deferred("_rebuild_rows")


func ensure_ports_ready() -> void:
	if not is_inside_tree() or match_row.is_empty():
		return
	if is_structure_ready():
		_configure_slots()
	else:
		_rebuild_rows()


func is_structure_ready() -> bool:
	return get_child_count() == case_rows.size() + 2


func get_group_id() -> String:
	return group_data.get("id", name)


func has_output_port(port: int) -> bool:
	return port >= 0 and port < case_rows.size() and is_structure_ready()


func has_input_port(port: int) -> bool:
	return port == 0 and is_structure_ready()


func get_case_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in case_rows:
		ids.append(row.id)
	return ids


func has_else_case() -> bool:
	return _find_else_index() != -1


func sync_to_document_nodes(document: DMGraphDocument) -> void:
	_sync_from_fields()
	if not match_row.is_empty() and document.has_node(match_row.id):
		document.nodes[match_row.id] = match_row.duplicate(true)
	for row: Dictionary in case_rows:
		if document.has_node(row.id):
			document.nodes[row.id] = row.duplicate(true)


func set_completion_context(cue_names: Array[String], autoload_names: PackedStringArray) -> void:
	for field: Node in find_children("*", "DMGraphExpressionField", true, false):
		if field is DMGraphExpressionField:
			(field as DMGraphExpressionField).completion_cue_names = cue_names.duplicate()
			(field as DMGraphExpressionField).completion_autoload_names = autoload_names


static func infer_case_type(row: Dictionary) -> String:
	if row.get("branch_type", "") == "else":
		return "else"
	var text: String = row.get("text", "").strip_edges().to_lower()
	if text == "else":
		return "else"
	return "when"


static func extract_case_expression(row: Dictionary, case_type: String) -> String:
	if case_type == "else":
		return ""
	var text: String = row.get("text", row.get("expression", "")).strip_edges()
	return text.trim_prefix("when ").strip_edges()


static func format_case_text(case_type: String, expression: String) -> String:
	if case_type == "else":
		return "else"
	return "when %s" % expression.strip_edges()


func _wrap_row(row: Control, row_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))
	panel.add_child(row)
	panel.custom_minimum_size = row.custom_minimum_size
	return panel


func _rebuild_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return

	_is_rebuilding = true
	_disconnect_own_connections()

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	group_data.case_ids = [] as Array[String]
	var max_row_width: float = MIN_EXPR_WIDTH
	var slot_index: int = 0

	var match_control: Control = _create_match_row()
	var match_wrapped: PanelContainer = _wrap_row(match_control, 0)
	add_child(match_wrapped)
	max_row_width = maxf(max_row_width, match_wrapped.custom_minimum_size.x)
	set_slot(slot_index, true, 0, PORT_COLOR, false, 0, PORT_COLOR)
	slot_index += 1

	for i: int in range(0, case_rows.size()):
		var row_data: Dictionary = case_rows[i]
		var case_type: String = infer_case_type(row_data)
		row_data.branch_type = case_type
		group_data.case_ids.append(row_data.id)
		var row_control: Control = _create_case_row(row_data, case_type, i + 1)
		var wrapped: PanelContainer = _wrap_row(row_control, i + 1)
		add_child(wrapped)
		max_row_width = maxf(max_row_width, wrapped.custom_minimum_size.x)
		set_slot(slot_index, false, 0, PORT_COLOR, true, 0, PORT_COLOR)
		slot_index += 1

	var actions_row: HBoxContainer = _create_actions_row()
	add_child(actions_row)
	set_slot(slot_index, false, 0, PORT_COLOR, false, 0, PORT_COLOR)

	_update_minimum_size(max_row_width)
	_is_rebuilding = false
	group_rebuilt.emit()


func _create_match_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)

	var prefix: Label = Label.new()
	prefix.custom_minimum_size = Vector2(PREFIX_WIDTH, 0)
	prefix.text = "Match"
	DMGraphNodeTheme.apply_muted_label(prefix)
	row.add_child(prefix)

	var expression: String = match_row.get("expression", match_row.get("text", "match value"))
	if expression.begins_with("match "):
		expression = expression.substr(6).strip_edges()

	var expr_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	expr_edit.name = "MatchExpressionEdit"
	expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_edit.set_line_type(DMConstants.TYPE_MATCH)
	expr_edit.placeholder_text = "value"
	expr_edit.set_text_silent(expression)
	expr_edit.text_modified.connect(_on_match_field_changed)
	row.add_child(expr_edit)

	var expr_width: float = maxf(MIN_EXPR_WIDTH, mini(float(expression.length()) * 7.0 + 40.0, MAX_EXPR_WIDTH))
	expr_edit.custom_minimum_size = Vector2(expr_width, 28.0)
	row.custom_minimum_size = Vector2(PREFIX_WIDTH + expr_width + 8.0, 28.0)
	return row


func _create_case_row(row_data: Dictionary, case_type: String, _index: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)

	var prefix: Label = Label.new()
	prefix.custom_minimum_size = Vector2(PREFIX_WIDTH, 0)
	prefix.text = case_type.capitalize()
	DMGraphNodeTheme.apply_muted_label(prefix)
	row.add_child(prefix)

	if case_type == "else":
		var else_label: Label = Label.new()
		else_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else_label.text = "..."
		DMGraphNodeTheme.apply_muted_label(else_label)
		row.add_child(else_label)
		row.custom_minimum_size = Vector2(PREFIX_WIDTH + 80.0, 28.0)
		row.set_meta(&"case_id", row_data.id)
		return row

	var expression: String = extract_case_expression(row_data, case_type)
	var expr_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	expr_edit.name = "ExpressionEdit"
	expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_edit.set_line_type(DMConstants.TYPE_WHEN)
	expr_edit.placeholder_text = "expression"
	expr_edit.set_text_silent(expression)
	expr_edit.text_modified.connect(_on_field_changed.bind(row_data.id))
	row.add_child(expr_edit)

	var expr_width: float = maxf(MIN_EXPR_WIDTH, mini(float(expression.length()) * 7.0 + 40.0, MAX_EXPR_WIDTH))
	expr_edit.custom_minimum_size = Vector2(expr_width, 28.0)
	row.custom_minimum_size = Vector2(PREFIX_WIDTH + expr_width + 8.0, 28.0)
	row.set_meta(&"case_id", row_data.id)
	return row


func _create_actions_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ActionsRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_when_button: Button = Button.new()
	add_when_button.text = "Add when"
	add_when_button.focus_mode = Control.FOCUS_NONE
	add_when_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_when_button.pressed.connect(_on_add_when_pressed)
	call_deferred("_apply_add_icon", add_when_button)
	row.add_child(add_when_button)

	if not has_else_case():
		var add_else_button: Button = Button.new()
		add_else_button.text = "Add else"
		add_else_button.focus_mode = Control.FOCUS_NONE
		add_else_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_else_button.pressed.connect(_on_add_else_pressed)
		call_deferred("_apply_add_icon", add_else_button)
		row.add_child(add_else_button)

	return row


func _configure_slots() -> void:
	_rebuild_rows()


func _disconnect_own_connections() -> void:
	var graph_edit: GraphEdit = get_parent() as GraphEdit
	if graph_edit == null:
		return
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == name or conn.to_node == name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _on_add_when_pressed() -> void:
	add_when_requested.emit()


func _on_add_else_pressed() -> void:
	add_else_requested.emit()


func _apply_add_icon(button: Button) -> void:
	if not is_instance_valid(button) or not is_inside_tree():
		return
	if has_theme_icon(&"Add", &"EditorIcons"):
		button.icon = get_theme_icon(&"Add", &"EditorIcons")


func _on_match_field_changed(_value: String = "") -> void:
	var match_control: Control = get_child(0) as Control
	if match_control is PanelContainer:
		match_control = match_control.get_child(0) as Control
	var expr_edit: DMGraphExpressionField = null
	if match_control is HBoxContainer:
		expr_edit = match_control.get_node_or_null("MatchExpressionEdit") as DMGraphExpressionField
	if is_instance_valid(expr_edit):
		var expression: String = expr_edit.text.strip_edges()
		match_row.expression = "match %s" % expression
		match_row.text = match_row.expression
	content_changed.emit()


func _on_field_changed(_value: String, case_id: String) -> void:
	_sync_case_from_fields(case_id)
	content_changed.emit()


func _sync_from_fields() -> void:
	_on_match_field_changed()
	for row: Dictionary in case_rows:
		_sync_case_from_fields(row.id)


func _sync_case_from_fields(case_id: String) -> void:
	var row_index: int = _find_case_index(case_id)
	if row_index == -1:
		return

	var wrapped: Control = get_child(row_index + 1) as Control
	var row_node: HBoxContainer = wrapped.get_child(0) as HBoxContainer if wrapped is PanelContainer else wrapped as HBoxContainer
	if not row_node:
		return

	var case_type: String = infer_case_type(case_rows[row_index])
	var expression: String = ""
	var expr_edit: DMGraphExpressionField = row_node.get_node_or_null("ExpressionEdit") as DMGraphExpressionField
	if is_instance_valid(expr_edit):
		expression = expr_edit.text.strip_edges()

	for case_data: Dictionary in case_rows:
		if case_data.id != case_id:
			continue
		case_data.branch_type = case_type
		case_data.expression = expression
		case_data.text = format_case_text(case_type, expression)
		if case_type == "else":
			case_data.type = DMConstants.TYPE_CONDITION
		else:
			case_data.type = DMConstants.TYPE_WHEN
		break


func _find_case_index(case_id: String) -> int:
	for i: int in range(0, case_rows.size()):
		if case_rows[i].id == case_id:
			return i
	return -1


func _find_else_index() -> int:
	for i: int in range(0, case_rows.size()):
		if infer_case_type(case_rows[i]) == "else":
			return i
	return -1


func _update_minimum_size(content_width: float = 300.0) -> void:
	var total_height: float = 12.0
	for i: int in range(0, get_child_count()):
		var row: Control = get_child(i) as Control
		if row and row.name != "ActionsRow":
			total_height += maxf(28.0, row.custom_minimum_size.y) + float(ROW_SEPARATION)
	total_height += 36.0
	custom_minimum_size = Vector2(maxf(280.0, content_width + PREFIX_WIDTH + 16.0), total_height + DMGraphNodeTheme.NODE_BOTTOM_MARGIN)
