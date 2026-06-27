@tool
extends GraphNode
class_name DMGraphResponseGroupNode


signal content_changed()
signal add_response_requested()
signal delete_response_requested(response_id: String)
signal response_row_edit_requested(response_id: String, grab_focus: bool)
signal group_rebuilt()


const ROW_SEPARATION: int = 4
const ROW_MARGIN_TOP: int = 2
const ROW_MARGIN_BOTTOM: int = 4
const ROW_HEIGHT: float = 24.0
const MIN_TEXT_WIDTH: float = 200.0
const MAX_TEXT_WIDTH: float = 520.0


var group_data: Dictionary = {}
var response_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false
var _suppress_field_sync: bool = false
var _accent_color: Color = DMGraphNodeTheme.ACCENT_RESPONSE
var _active_response_id: String = ""


func _ready() -> void:
	resizable = false
	_apply_node_title()
	if not gui_input.is_connected(_on_group_gui_input):
		gui_input.connect(_on_group_gui_input)


func _on_group_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if mouse.position.y <= 30.0:
		set_active_response_id("")


func setup_group(responses: Array[Dictionary], node_position: Vector2 = Vector2.ZERO) -> void:
	var group_id: String = group_data.get("id", "")
	if group_id == "":
		group_id = "rg_%s" % responses[0].id if responses.size() > 0 else "rg_empty"
	group_data = {
		id = group_id,
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
	if _is_rebuilding:
		return

	var child_count: int = get_child_count()
	if child_count == 0:
		return

	var port_color: Color = DMGraphNodeTheme.get_port_color_for_type("response_group")
	if response_rows.is_empty():
		set_slot(0, false, 0, port_color, false, 0, port_color)
		return

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
	_refresh_response_row_selection()
	call_deferred("_end_row_rebuild")


func _end_row_rebuild() -> void:
	_suppress_field_sync = false


func get_active_response_id() -> String:
	return _active_response_id


func set_active_response_id(response_id: String) -> void:
	_active_response_id = response_id
	_refresh_response_row_selection()


func _refresh_response_row_selection() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var wrapper: Control = get_child(i) as Control
		if not wrapper is PanelContainer:
			continue
		var panel: PanelContainer = wrapper as PanelContainer
		var row_index: int = int(panel.get_meta(&"row_index", 0))
		var row_id: String = response_rows[row_index].id if row_index < response_rows.size() else ""
		if row_id != "" and row_id == _active_response_id:
			panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_selected_style(row_index))
		else:
			panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))


func _apply_node_title() -> void:
	_accent_color = DMGraphNodeTheme.get_accent_for_type("response_group")
	DMGraphNodeTheme.apply_title(self, _accent_color, true)
	title = "Responses"


func _wrap_response_row(row: HBoxContainer, row_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))
	panel.add_child(row)
	panel.custom_minimum_size.y = ROW_HEIGHT + float(ROW_MARGIN_TOP if row_index > 0 else 0) + float(ROW_MARGIN_BOTTOM)
	panel.set_meta(&"response_row", row)
	panel.set_meta(&"row_index", row_index)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = DMGraphTooltips.RESPONSE_ROW
	panel.gui_input.connect(_on_row_panel_gui_input.bind(panel))
	_bind_response_row_hover(panel)
	return panel


func _bind_response_row_hover(panel: PanelContainer) -> void:
	var targets: Array[Control] = [panel]
	var row: HBoxContainer = _get_row_content(panel)
	if is_instance_valid(row):
		targets.append(row)
		for child: Node in row.get_children():
			if child is Control:
				targets.append(child as Control)
	for target: Control in targets:
		target.mouse_entered.connect(_on_response_row_hover_entered.bind(panel))
		target.mouse_exited.connect(_on_response_row_hover_exited.bind(panel))


func _on_response_row_hover_entered(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	_set_response_row_hovered(panel, true)


func _on_response_row_hover_exited(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	call_deferred("_finish_response_row_hover_exit", panel)


func _finish_response_row_hover_exit(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	if _is_mouse_over_response_row(panel):
		return
	_set_response_row_hovered(panel, false)


func _is_mouse_over_response_row(panel: PanelContainer) -> bool:
	if not is_instance_valid(panel):
		return false
	var mouse_position: Vector2 = panel.get_viewport().get_mouse_position()
	return panel.get_global_rect().has_point(mouse_position)


func _set_response_row_hovered(panel: PanelContainer, hovered: bool) -> void:
	if not is_instance_valid(panel):
		return
	var row: HBoxContainer = _get_row_content(panel)
	if not row:
		return
	var row_index: int = int(panel.get_meta(&"row_index", 0))
	var row_id: String = response_rows[row_index].id if row_index < response_rows.size() else ""
	if hovered:
		panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_hover_style())
	elif row_id != "" and row_id == _active_response_id:
		panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_selected_style(row_index))
	else:
		panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))
	var delete_button: Button = row.get_node_or_null("DeleteButton") as Button
	if is_instance_valid(delete_button):
		delete_button.visible = hovered


func _on_row_panel_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	var row: HBoxContainer = _get_row_content(panel)
	if not row:
		return
	var delete_button: Button = row.get_node_or_null("DeleteButton") as Button
	if is_instance_valid(delete_button) and delete_button.get_global_rect().has_point(mouse.global_position):
		return
	accept_event()
	selected = false
	call_deferred("_deselect_node")
	var response_id: String = str(row.get_meta(&"response_id", ""))
	if response_id == "":
		return
	set_active_response_id(response_id)
	response_row_edit_requested.emit(response_id, mouse.double_click)


func _deselect_node() -> void:
	selected = false


func _wrap_add_row(add_row: HBoxContainer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_plain_row_style())
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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)
	row.custom_minimum_size.y = ROW_HEIGHT

	var number_label: Label = Label.new()
	number_label.name = "ResponseNumberLabel"
	number_label.text = "%d." % (row_index + 1)
	number_label.custom_minimum_size = Vector2(DMGraphNodeTheme.RESPONSE_NUMBER_WIDTH, 0)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DMGraphNodeTheme.apply_response_number_label(number_label)
	row.add_child(number_label)

	var display_label: Label = DMGraphNodeTheme.create_display_label("ResponseDisplayLabel")
	display_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	display_label.clip_text = true
	display_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DMGraphNodeTheme.apply_display_body_label(display_label)
	row.add_child(display_label)

	var delete_button: Button = Button.new()
	delete_button.name = "DeleteButton"
	DMGraphNodeTheme.apply_row_delete_button(delete_button)
	delete_button.pressed.connect(_on_delete_response_pressed.bind(row_data.id))
	call_deferred("_apply_row_delete_icon", delete_button)
	row.add_child(delete_button)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.name = "TextEdit"
	text_edit.visible = false
	text_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_edit.text = display_text
	text_edit.text_changed.connect(_on_field_changed.bind(row_data.id))

	var condition_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	condition_edit.name = "ConditionEdit"
	condition_edit.visible = false
	condition_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	display_label.text = line
	display_label.tooltip_text = "%d. %s" % [row_index + 1, line]


func _apply_row_delete_icon(delete_button: Button) -> void:
	if not is_instance_valid(delete_button) or not is_inside_tree():
		return
	DMGraphNodeTheme.apply_row_delete_icon(delete_button, self)


func _on_delete_response_pressed(response_id: String) -> void:
	delete_response_requested.emit(response_id)


func _create_add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var add_button: Button = Button.new()
	add_button.text = "Add response"
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.flat = true
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_button.tooltip_text = DMGraphTooltips.RESPONSE_ADD
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
	var reserved: float = (
		DMGraphNodeTheme.RESPONSE_NUMBER_WIDTH
		+ DMGraphNodeTheme.ROW_DELETE_BUTTON_WIDTH
		+ float(DMGraphNodeTheme.ROW_INNER_PADDING) * 2.0
		+ 12.0
	)
	for i: int in range(0, response_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		var display_label: Label = row.get_node_or_null("ResponseDisplayLabel") as Label
		if is_instance_valid(display_label):
			var line_width: float = DMGraphNodeTheme.measure_display_text_width(display_label.text)
			max_width = maxf(max_width, line_width + reserved)
	max_width = mini(max_width, MAX_TEXT_WIDTH)

	var total_height: float = 0.0
	for i: int in range(0, get_child_count()):
		var wrapper: Control = get_child(i) as Control
		if wrapper:
			total_height += wrapper.custom_minimum_size.y
	total_height += DMGraphNodeTheme.NODE_BOTTOM_MARGIN + 8.0
	custom_minimum_size = Vector2(max_width, total_height)
	call_deferred("_deferred_sync_row_widths", max_width)


func _deferred_sync_row_widths(width: float) -> void:
	DMGraphNodeTheme.sync_group_child_widths(self, width)
