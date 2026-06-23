@tool
extends GraphNode
class_name DMGraphResponseGroupNode


signal content_changed()
signal add_response_requested()
signal group_rebuilt()


const ROW_SEPARATION: int = 8
const ROW_MARGIN_TOP: int = 6
const ROW_MARGIN_BOTTOM: int = 10
const MIN_TEXT_WIDTH: float = 180.0
const MAX_TEXT_WIDTH: float = 640.0
const MAX_RESPONSE_VISIBLE_HEIGHT: float = 160.0
const TARGET_SINGLE_LINE_WIDTH: float = 300.0
const DEFAULT_RESPONSE_TEXT_LINES: int = 2
const IF_BUTTON_WIDTH: float = 40.0
const CONDITION_FIELD_WIDTH: float = 80.0
const CONDITION_FIELD_PADDING: float = 10.0
const CONDITION_LINE_HEIGHT: float = 28.0
const GROUP_HORIZONTAL_PADDING: float = 4.0
const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR


var group_data: Dictionary = {}
var response_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false


func _ready() -> void:
	resizable = true
	_apply_title_style()


func setup_group(responses: Array[Dictionary], node_position: Vector2 = Vector2.ZERO) -> void:
	group_data = {
		id = "rg_%s" % responses[0].id if responses.size() > 0 else "rg_empty",
		type = "response_group",
		response_ids = [] as Array[String],
		position = node_position,
	}
	response_rows = responses.duplicate(true)

	name = group_data.id
	position_offset = node_position
	title = "Responses"

	if is_node_ready() and is_inside_tree():
		_rebuild_rows()
	else:
		call_deferred("_rebuild_rows")


func ensure_ports_ready() -> void:
	if not is_inside_tree() or response_rows.is_empty():
		return
	if is_structure_ready():
		_configure_slots()
	else:
		_rebuild_rows()


func is_structure_ready() -> bool:
	return get_child_count() == response_rows.size() + 1


func get_group_id() -> String:
	return group_data.get("id", name)


func get_response_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in response_rows:
		ids.append(row.id)
	return ids


func has_output_port(port: int) -> bool:
	return port >= 0 and port < response_rows.size() and is_structure_ready()


func has_input_port(port: int) -> bool:
	return port == 0 and is_structure_ready()


func sync_to_document_nodes(document: DMGraphDocument) -> void:
	_sync_from_fields()
	for row: Dictionary in response_rows:
		if document.has_node(row.id):
			document.nodes[row.id] = row.duplicate(true)


func _parse_response_text(raw_text: String, stored_condition: String = "") -> Dictionary:
	return DMGraphTreeBuilder.parse_response_parts(raw_text, stored_condition)


func _disconnect_own_connections() -> void:
	var graph_edit: GraphEdit = get_parent() as GraphEdit
	if not graph_edit: return
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == name or conn.to_node == name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _configure_slots() -> void:
	if _is_rebuilding or response_rows.is_empty():
		return

	var child_count: int = get_child_count()
	if child_count == 0:
		return

	for i: int in range(0, response_rows.size()):
		if i >= child_count:
			break
		set_slot(i, i == 0, 0, PORT_COLOR, true, 0, PORT_COLOR)

	var add_index: int = response_rows.size()
	if add_index < child_count:
		set_slot(add_index, false, 0, PORT_COLOR, false, 0, PORT_COLOR)


func _rebuild_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return

	_is_rebuilding = true
	_disconnect_own_connections()

	for child: Node in get_children():
		remove_child(child)
		child.free()

	group_data.response_ids = [] as Array[String]

	for i: int in range(0, response_rows.size()):
		var row_data: Dictionary = response_rows[i]
		group_data.response_ids.append(row_data.id)
		var row: HBoxContainer = _create_response_row(row_data)
		if not row:
			continue
		var row_control: Control = _wrap_response_row(row, i > 0)
		add_child(row_control)

	var add_row: HBoxContainer = _create_add_row()
	add_child(_wrap_add_row(add_row))

	_configure_slots()
	_is_rebuilding = false
	group_rebuilt.emit()
	call_deferred("_relayout_all_response_rows")


func _wrap_response_row(row: HBoxContainer, add_top_margin: bool) -> MarginContainer:
	var wrapper: MarginContainer = MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override(&"margin_top", ROW_MARGIN_TOP if add_top_margin else 0)
	wrapper.add_theme_constant_override(&"margin_bottom", ROW_MARGIN_BOTTOM)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)

	var filler: Control = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	var row_height: float = maxf(28.0, row.custom_minimum_size.y)
	wrapper.custom_minimum_size.y = row_height + float(
		ROW_MARGIN_TOP if add_top_margin else 0
	) + float(ROW_MARGIN_BOTTOM)
	wrapper.set_meta(&"response_row", row)
	wrapper.add_child(column)
	return wrapper


func _wrap_add_row(add_row: HBoxContainer) -> MarginContainer:
	var wrapper: MarginContainer = MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override(&"margin_bottom", int(DMGraphNodeTheme.NODE_BOTTOM_MARGIN))
	wrapper.add_child(add_row)
	return wrapper


func _get_row_content(row_node: Control) -> HBoxContainer:
	if row_node is MarginContainer and row_node.has_meta(&"response_row"):
		return row_node.get_meta(&"response_row") as HBoxContainer
	return row_node as HBoxContainer


func _create_response_row(row_data: Dictionary) -> HBoxContainer:
	var parsed: Dictionary = _parse_response_text(row_data.get("text", ""), row_data.get("condition", ""))
	var display_text: String = parsed.get("text", "")
	var condition: String = DMGraphTreeBuilder.normalize_condition_text(parsed.get("condition", ""))
	row_data.condition = condition
	row_data.condition_style = parsed.get("condition_style", row_data.get("condition_style", "bracket"))

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", ROW_SEPARATION)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.name = "TextEdit"
	text_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	text_edit.placeholder_text = "Response text"
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text = display_text
	text_edit.text_changed.connect(_on_field_changed.bind(row_data.id))
	DMGraphNodeTheme.apply_field_background(text_edit)

	var if_button: Button = Button.new()
	if_button.name = "IfButton"
	if_button.text = "If" if condition == "" else "If ✓"
	if_button.toggle_mode = true
	if_button.focus_mode = Control.FOCUS_NONE
	if_button.custom_minimum_size = Vector2(IF_BUTTON_WIDTH, 0.0)
	if_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if_button.button_pressed = condition != ""

	var condition_edit := DMGraphExpressionField.new()
	condition_edit.name = "ConditionEdit"
	condition_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	condition_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	condition_edit.placeholder_text = "condition"
	condition_edit.set_text_silent(condition)
	condition_edit.visible = condition != ""
	condition_edit.text_modified.connect(_on_field_changed.bind(row_data.id))

	if_button.toggled.connect(_on_condition_toggled.bind(row_data.id, condition_edit, if_button))

	row.add_child(text_edit)
	row.add_child(if_button)
	row.add_child(condition_edit)
	row.set_meta("response_id", row_data.id)

	var condition_width: float = _condition_width_for_text(condition, condition_edit) if condition != "" else 0.0
	var text_size: Vector2 = _measure_response_text_size(text_edit, display_text)
	_apply_response_text_size(text_edit, text_size)
	if condition != "":
		condition_edit.custom_minimum_size = Vector2(condition_width, CONDITION_LINE_HEIGHT)
	row.custom_minimum_size = Vector2(
		text_size.x + IF_BUTTON_WIDTH + condition_width + ROW_SEPARATION,
		text_size.y
	)

	return row


func _line_metrics(control: Control) -> Dictionary:
	var font_size: float = float(control.get_theme_font_size(&"font_size"))
	if font_size <= 0.0:
		font_size = 14.0
	return {
		"font_size": font_size,
		"char_width": font_size * 0.6,
		"line_height": font_size * 1.4 + 6.0,
	}


func _measure_response_text_size(text_edit: TextEdit, text: String) -> Vector2:
	var metrics: Dictionary = _line_metrics(text_edit)
	var char_width: float = metrics.char_width
	var line_height: float = metrics.line_height

	var longest_line: int = 1
	for line: String in text.split("\n"):
		longest_line = maxi(longest_line, line.length())

	var width: float = maxf(MIN_TEXT_WIDTH, float(longest_line) * char_width + 24.0)
	var line_count: int = maxi(DEFAULT_RESPONSE_TEXT_LINES, text.split("\n", false).size())

	if line_count == DEFAULT_RESPONSE_TEXT_LINES and width > TARGET_SINGLE_LINE_WIDTH:
		var chars_per_line: int = maxi(1, int(TARGET_SINGLE_LINE_WIDTH / char_width))
		if text.length() > chars_per_line:
			line_count = maxi(DEFAULT_RESPONSE_TEXT_LINES, ceili(float(text.length()) / float(chars_per_line)))

	width = mini(width, MAX_TEXT_WIDTH)
	var max_lines: int = maxi(DEFAULT_RESPONSE_TEXT_LINES, ceili(MAX_RESPONSE_VISIBLE_HEIGHT / line_height))
	line_count = mini(line_count, max_lines)

	var height: float = line_height * float(line_count)
	return Vector2(width, height)


func _apply_response_text_size(text_edit: TextEdit, text_size: Vector2) -> void:
	text_edit.custom_minimum_size = text_size


func _condition_width_for_text(text: String, control: Control = null) -> float:
	var clean_text: String = DMGraphTreeBuilder.normalize_condition_text(text)
	if clean_text.is_empty():
		return 0.0
	var font_size: int = 14
	var font: Font = null
	if control:
		font_size = int(_line_metrics(control).font_size)
		font = control.get_theme_font(&"font")
	if not font and control:
		font = ThemeDB.fallback_font
	var text_width: float = float(clean_text.length()) * 7.0
	if font:
		text_width = font.get_string_size(clean_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return maxf(CONDITION_FIELD_WIDTH, text_width + CONDITION_FIELD_PADDING)


func _get_max_response_text_width() -> float:
	var max_width: float = MIN_TEXT_WIDTH
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		var text_edit: TextEdit = row.get_node_or_null("TextEdit") as TextEdit
		if not is_instance_valid(text_edit):
			continue
		var text_size: Vector2 = _measure_response_text_size(text_edit, text_edit.text)
		max_width = maxf(max_width, text_size.x)
	return max_width


func _get_max_active_condition_width() -> float:
	var max_width: float = 0.0
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		var condition_edit: DMGraphExpressionField = row.get_node_or_null("ConditionEdit") as DMGraphExpressionField
		if is_instance_valid(condition_edit) and condition_edit.visible:
			max_width = maxf(max_width, _condition_width_for_text(condition_edit.text, condition_edit))
	return max_width


func _get_group_content_width(shared_text_width: float, shared_condition_width: float) -> float:
	var width: float = shared_text_width + IF_BUTTON_WIDTH + ROW_SEPARATION
	if shared_condition_width > 0.0:
		width += shared_condition_width
	return width + GROUP_HORIZONTAL_PADDING


func _relayout_all_response_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return
	var shared_text_width: float = _get_max_response_text_width()
	var shared_condition_width: float = _get_max_active_condition_width()
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		_apply_row_layout(row, shared_text_width, shared_condition_width)
	_update_minimum_size(shared_text_width, shared_condition_width)
	_configure_slots()


func _apply_row_layout(row: HBoxContainer, shared_text_width: float, shared_condition_width: float) -> void:
	var text_edit: TextEdit = row.get_node_or_null("TextEdit") as TextEdit
	var condition_edit: DMGraphExpressionField = row.get_node_or_null("ConditionEdit") as DMGraphExpressionField
	if not text_edit: return
	var condition_visible: bool = is_instance_valid(condition_edit) and condition_edit.visible
	var condition_width: float = shared_condition_width if condition_visible else 0.0
	if condition_visible and is_instance_valid(condition_edit):
		condition_edit.custom_minimum_size = Vector2(condition_width, CONDITION_LINE_HEIGHT)
	var text_size: Vector2 = _measure_response_text_size(text_edit, text_edit.text)
	_apply_response_text_size(text_edit, Vector2(shared_text_width, text_size.y))
	row.custom_minimum_size = Vector2(
		shared_text_width + IF_BUTTON_WIDTH + condition_width + ROW_SEPARATION,
		text_size.y
	)


func _create_add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_button: Button = Button.new()
	add_button.text = "Add response"
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_button.pressed.connect(_on_add_pressed)
	call_deferred("_apply_add_button_icon", add_button)

	row.add_child(add_button)
	return row


func _apply_add_button_icon(add_button: Button) -> void:
	if not is_instance_valid(add_button) or not is_inside_tree():
		return
	if has_theme_icon("Add", "EditorIcons"):
		add_button.icon = get_theme_icon("Add", "EditorIcons")


func _on_add_pressed() -> void:
	add_response_requested.emit()


func _on_condition_toggled(enabled: bool, response_id: String, condition_edit: DMGraphExpressionField, if_button: Button) -> void:
	if not is_instance_valid(condition_edit):
		return
	condition_edit.visible = enabled
	if_button.text = "If" if not enabled else "If ✓"
	if not enabled:
		condition_edit.set_text_silent("")
	_sync_row_from_fields(response_id)
	call_deferred("_relayout_all_response_rows")
	content_changed.emit()


func _on_field_changed(_value: String, response_id: String) -> void:
	if _is_rebuilding:
		return
	_sync_row_from_fields(response_id)
	call_deferred("_relayout_all_response_rows")
	content_changed.emit()


func _sync_from_fields() -> void:
	for row: Dictionary in response_rows:
		_sync_row_from_fields(row.id)


func _sync_row_from_fields(response_id: String) -> void:
	var row_index: int = _find_row_index(response_id)
	if row_index == -1:
		return

	var row_node: HBoxContainer = _get_row_content(get_child(row_index) as Control)
	if not row_node: return

	var text_edit: TextEdit = row_node.get_node_or_null("TextEdit") as TextEdit
	var condition_edit: DMGraphExpressionField = row_node.get_node_or_null("ConditionEdit") as DMGraphExpressionField

	for response_data: Dictionary in response_rows:
		if response_data.id != response_id:
			continue
		var body: String = ""
		if is_instance_valid(text_edit):
			body = text_edit.text.strip_edges()
		var condition: String = ""
		if is_instance_valid(condition_edit) and condition_edit.visible:
			condition = DMGraphTreeBuilder.normalize_condition_text(condition_edit.text)

		var parsed: Dictionary = DMGraphTreeBuilder.parse_response_parts("- %s" % body, condition)
		body = parsed.get("text", body)
		if parsed.get("condition", "") != "":
			condition = parsed.get("condition", condition)
		elif condition != "":
			condition = DMGraphTreeBuilder.normalize_condition_text(condition)

		if is_instance_valid(condition_edit) and condition_edit.visible and condition_edit.text != condition:
			condition_edit.set_text_silent(condition)

		response_data.condition = condition
		if condition != "":
			response_data.text = DMGraphTreeBuilder.format_response_line(
				body,
				condition,
				response_data.get("condition_style", "bracket")
			)
		else:
			response_data.text = "- %s" % body
		break


func _find_row_index(response_id: String) -> int:
	for i: int in range(0, response_rows.size()):
		if response_rows[i].id == response_id:
			return i
	return -1


func finalize_layout_size() -> void:
	if not is_inside_tree():
		return
	call_deferred("_relayout_all_response_rows")


func _update_minimum_size(shared_text_width: float = MIN_TEXT_WIDTH, shared_condition_width: float = 0.0) -> void:
	var total_height: float = 12.0
	for i: int in range(0, response_rows.size()):
		if i < get_child_count():
			var wrapper: Control = get_child(i) as Control
			var row: Control = _get_row_content(wrapper)
			if row:
				var row_height: float = maxf(28.0, row.custom_minimum_size.y)
				if wrapper is MarginContainer:
					row_height += float(wrapper.get_theme_constant(&"margin_top", &"MarginContainer"))
					row_height += float(wrapper.get_theme_constant(&"margin_bottom", &"MarginContainer"))
				total_height += row_height + float(ROW_SEPARATION)
	total_height += 32.0 + DMGraphNodeTheme.NODE_BOTTOM_MARGIN
	custom_minimum_size = Vector2(
		_get_group_content_width(shared_text_width, shared_condition_width),
		total_height
	)


func _apply_title_style() -> void:
	DMGraphNodeTheme.apply_title(self, Color(0.2, 0.55, 0.3))
