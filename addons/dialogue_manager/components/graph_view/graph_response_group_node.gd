@tool
extends GraphNode
class_name DMGraphResponseGroupNode


signal content_changed()
signal add_response_requested()
signal group_rebuilt()


const ROW_SEPARATION: int = 4
const ROW_MARGIN_TOP: int = 2
const ROW_MARGIN_BOTTOM: int = 4
const ROW_HEIGHT: float = 24.0
const MIN_TEXT_WIDTH: float = 180.0
const MAX_TEXT_WIDTH: float = 480.0
const GROUP_HORIZONTAL_PADDING: float = 8.0


var group_data: Dictionary = {}
var response_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false
var _suppress_field_sync: bool = false
var _row_popup: Window
var _accent_color: Color = DMGraphNodeTheme.ACCENT_RESPONSE


func _ready() -> void:
	resizable = false
	_apply_node_title()


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
	_apply_node_title()

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


func refresh_display_from_data() -> void:
	if not is_inside_tree() or response_rows.is_empty():
		return
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if row:
			_update_row_display_label(row, i)


func _parse_response_text(raw_text: String, stored_condition: String = "") -> Dictionary:
	return DMGraphTreeBuilder.parse_response_parts(raw_text, stored_condition)


func _disconnect_own_connections() -> void:
	var graph_edit: GraphEdit = get_parent() as GraphEdit
	if not graph_edit:
		return
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == name or conn.to_node == name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _configure_slots() -> void:
	if _is_rebuilding or response_rows.is_empty():
		return

	var child_count: int = get_child_count()
	if child_count == 0:
		return

	var port_color: Color = DMGraphNodeTheme.get_port_color_for_type("response_group")
	for i: int in range(0, response_rows.size()):
		if i >= child_count:
			break
		set_slot(i, i == 0, 0, port_color, true, 0, port_color)

	var add_index: int = response_rows.size()
	if add_index < child_count:
		set_slot(add_index, false, 0, port_color, false, 0, port_color)


func _rebuild_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return

	_is_rebuilding = true
	_suppress_field_sync = true
	_disconnect_own_connections()

	for child: Node in get_children():
		remove_child(child)
		child.free()

	group_data.response_ids = [] as Array[String]

	for i: int in range(0, response_rows.size()):
		var row_data: Dictionary = response_rows[i]
		group_data.response_ids.append(row_data.id)
		var row: HBoxContainer = _create_response_row(row_data, i)
		if not row:
			continue
		var row_control: Control = _wrap_response_row(row, i)
		add_child(row_control)

	var add_row: HBoxContainer = _create_add_row()
	add_child(_wrap_add_row(add_row))

	_configure_slots()
	_update_minimum_size()
	_is_rebuilding = false
	group_rebuilt.emit()
	call_deferred("_end_row_rebuild")


func _end_row_rebuild() -> void:
	_suppress_field_sync = false


func _apply_node_title() -> void:
	_accent_color = DMGraphNodeTheme.get_accent_for_type("response_group")
	DMGraphNodeTheme.apply_title(self, _accent_color)
	title = "Responses"


func _wrap_response_row(row: HBoxContainer, row_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))
	panel.add_child(row)
	panel.custom_minimum_size.y = ROW_HEIGHT + float(ROW_MARGIN_TOP if row_index > 0 else 0) + float(ROW_MARGIN_BOTTOM)
	panel.set_meta(&"response_row", row)
	return panel


func _wrap_add_row(add_row: HBoxContainer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(response_rows.size()))
	panel.add_child(add_row)
	panel.custom_minimum_size.y = 24.0
	return panel


func _get_row_content(row_node: Control) -> HBoxContainer:
	if row_node is PanelContainer and row_node.has_meta(&"response_row"):
		return row_node.get_meta(&"response_row") as HBoxContainer
	if row_node is MarginContainer and row_node.has_meta(&"response_row"):
		return row_node.get_meta(&"response_row") as HBoxContainer
	return row_node as HBoxContainer


func _create_response_row(row_data: Dictionary, row_index: int) -> HBoxContainer:
	var parsed: Dictionary = _parse_response_text(row_data.get("text", ""), row_data.get("condition", ""))
	var display_text: String = parsed.get("text", "")
	var condition: String = DMGraphTreeBuilder.normalize_condition_text(parsed.get("condition", ""))
	row_data.condition = condition
	row_data.condition_style = parsed.get("condition_style", row_data.get("condition_style", "slash"))

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)
	row.custom_minimum_size.y = ROW_HEIGHT

	var number_label: Label = Label.new()
	number_label.name = "ResponseNumberLabel"
	number_label.text = "%d." % (row_index + 1)
	number_label.custom_minimum_size = Vector2(DMGraphNodeTheme.RESPONSE_NUMBER_WIDTH, 0)
	DMGraphNodeTheme.apply_response_number_label(number_label)
	row.add_child(number_label)

	var display_label: Label = DMGraphNodeTheme.create_display_label("ResponseDisplayLabel")
	display_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	display_label.mouse_filter = Control.MOUSE_FILTER_STOP
	DMGraphNodeTheme.apply_display_body_label(display_label)
	display_label.gui_input.connect(_on_row_display_gui_input.bind(row_data.id))
	row.add_child(display_label)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.name = "TextEdit"
	text_edit.visible = false
	text_edit.text = display_text
	text_edit.text_changed.connect(_on_field_changed.bind(row_data.id))

	var condition_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	condition_edit.name = "ConditionEdit"
	condition_edit.visible = false
	condition_edit.set_text_silent(condition)
	condition_edit.text_modified.connect(_on_field_changed.bind(row_data.id))

	row.add_child(text_edit)
	row.add_child(condition_edit)
	row.set_meta(&"response_id", row_data.id)
	row.set_meta(&"row_index", row_index)

	_update_row_display_label(row, row_index)
	return row


func _update_row_display_label(row: HBoxContainer, row_index: int) -> void:
	var number_label: Label = row.get_node_or_null("ResponseNumberLabel") as Label
	var display_label: Label = row.get_node_or_null("ResponseDisplayLabel") as Label
	var text_edit: TextEdit = row.get_node_or_null("TextEdit") as TextEdit
	var condition_edit: DMGraphExpressionField = row.get_node_or_null("ConditionEdit") as DMGraphExpressionField
	if not is_instance_valid(display_label) or not is_instance_valid(text_edit):
		return

	if is_instance_valid(number_label):
		number_label.text = "%d." % (row_index + 1)

	var body: String = text_edit.text.strip_edges()
	var line: String = body if body != "" else "(empty)"
	var condition: String = ""
	if is_instance_valid(condition_edit):
		condition = DMGraphTreeBuilder.normalize_condition_text(condition_edit.text)
	if condition != "":
		line += " [if %s /]" % condition
	display_label.text = DMGraphNodeTheme.truncate_display_text(line, 2)
	display_label.tooltip_text = "%d. %s" % [row_index + 1, line]


func _on_row_display_gui_input(event: InputEvent, response_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.double_click:
		return
	_open_row_edit_popup(response_id)


func _open_row_edit_popup(response_id: String) -> void:
	var row_index: int = _find_row_index(response_id)
	if row_index == -1:
		return
	var row: HBoxContainer = _get_row_content(get_child(row_index) as Control)
	if not row:
		return

	var text_edit: TextEdit = row.get_node_or_null("TextEdit") as TextEdit
	var condition_edit: DMGraphExpressionField = row.get_node_or_null("ConditionEdit") as DMGraphExpressionField
	if not is_instance_valid(text_edit):
		return

	if is_instance_valid(_row_popup):
		_row_popup.queue_free()

	_row_popup = Window.new()
	_row_popup.title = "Edit response"
	_row_popup.unresizable = false
	_row_popup.size = Vector2i(480, 200)
	_row_popup.min_size = Vector2i(320, 120)
	_row_popup.close_requested.connect(_row_popup.queue_free)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_row_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_edit.text = text_edit.text
	popup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(popup_edit)

	var condition_field: LineEdit = LineEdit.new()
	condition_field.placeholder_text = "Visibility condition [if expr /]"
	if is_instance_valid(condition_edit):
		condition_field.text = condition_edit.text
	vbox.add_child(condition_field)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		text_edit.text = popup_edit.text
		if is_instance_valid(condition_edit):
			condition_edit.set_text_silent(condition_field.text)
		_on_field_changed("", response_id)
		_row_popup.queue_free()
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_row_popup)
	_row_popup.popup_centered()


func _create_add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_button: Button = Button.new()
	add_button.text = "Add response"
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.flat = true
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_button.pressed.connect(_on_add_pressed)
	call_deferred("_apply_add_button_icon", add_button)

	row.add_child(add_button)
	return row


func _apply_add_button_icon(add_button: Button) -> void:
	if not is_instance_valid(add_button) or not is_inside_tree():
		return
	if has_theme_icon(&"Add", &"EditorIcons"):
		add_button.icon = get_theme_icon(&"Add", &"EditorIcons")


func _on_add_pressed() -> void:
	add_response_requested.emit()


func _on_field_changed(_value: String, response_id: String) -> void:
	if _is_rebuilding or _suppress_field_sync:
		return
	_sync_row_from_fields(response_id)
	var row_index: int = _find_row_index(response_id)
	if row_index != -1:
		var row: HBoxContainer = _get_row_content(get_child(row_index) as Control)
		if row:
			_update_row_display_label(row, row_index)
	_update_minimum_size()
	content_changed.emit()


func _sync_from_fields() -> void:
	for row: Dictionary in response_rows:
		_sync_row_from_fields(row.id)


func _sync_row_from_fields(response_id: String) -> void:
	var row_index: int = _find_row_index(response_id)
	if row_index == -1:
		return

	var row_node: HBoxContainer = _get_row_content(get_child(row_index) as Control)
	if not row_node:
		return

	var text_edit: TextEdit = row_node.get_node_or_null("TextEdit") as TextEdit
	var condition_edit: DMGraphExpressionField = row_node.get_node_or_null("ConditionEdit") as DMGraphExpressionField

	for response_data: Dictionary in response_rows:
		if response_data.id != response_id:
			continue
		var body: String = ""
		if is_instance_valid(text_edit):
			body = text_edit.text.strip_edges()
		var condition: String = ""
		if is_instance_valid(condition_edit):
			condition = DMGraphTreeBuilder.normalize_condition_text(condition_edit.text)

		var parsed: Dictionary = DMGraphTreeBuilder.parse_response_parts("- %s" % body, condition)
		body = parsed.get("text", body)
		if parsed.get("condition", "") != "":
			condition = parsed.get("condition", condition)
		elif condition != "":
			condition = DMGraphTreeBuilder.normalize_condition_text(condition)

		if is_instance_valid(condition_edit) and condition_edit.text != condition:
			condition_edit.set_text_silent(condition)

		response_data.condition = condition
		if condition != "":
			response_data.condition_style = "slash"
			response_data.text = DMGraphTreeBuilder.format_response_line(
				body,
				condition,
				"slash"
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
	call_deferred("_update_minimum_size")


func _update_minimum_size() -> void:
	var max_width: float = MIN_TEXT_WIDTH
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		var display_label: Label = row.get_node_or_null("ResponseDisplayLabel") as Label
		if is_instance_valid(display_label):
			max_width = maxf(max_width, float(display_label.text.length()) * 7.0 + DMGraphNodeTheme.RESPONSE_NUMBER_WIDTH + 24.0)
	max_width = mini(max_width, MAX_TEXT_WIDTH)

	var total_height: float = 0.0
	for i: int in range(0, get_child_count()):
		var wrapper: Control = get_child(i) as Control
		if wrapper:
			total_height += wrapper.custom_minimum_size.y
	total_height += DMGraphNodeTheme.NODE_BOTTOM_MARGIN + 8.0
	custom_minimum_size = Vector2(max_width + GROUP_HORIZONTAL_PADDING, total_height)
