@tool
extends GraphNode
class_name DMGraphRandomGroupNode


signal content_changed()
signal add_line_requested()
signal group_rebuilt()


const ROW_SEPARATION: int = 4
const ROW_HEIGHT: float = 24.0
const MIN_TEXT_WIDTH: float = 180.0
const MAX_TEXT_WIDTH: float = 480.0
const GROUP_HORIZONTAL_PADDING: float = 8.0


var group_data: Dictionary = {}
var random_rows: Array[Dictionary] = []
var _is_rebuilding: bool = false
var _suppress_field_sync: bool = false


func _ready() -> void:
	resizable = false
	_apply_node_title()


func setup_group(rows: Array[Dictionary], node_position: Vector2 = Vector2.ZERO) -> void:
	random_rows = rows.duplicate(true)
	group_data = {
		id = "rng_%s" % rows[0].id if rows.size() > 0 else "rng_empty",
		type = "random_group",
		random_ids = [] as Array[String],
		position = node_position,
	}
	name = group_data.id
	position_offset = node_position
	_apply_node_title()

	if is_node_ready() and is_inside_tree():
		_rebuild_rows()
	else:
		call_deferred("_rebuild_rows")


func ensure_ports_ready() -> void:
	if not is_inside_tree() or random_rows.is_empty():
		return
	if is_structure_ready():
		_configure_slots()
	else:
		_rebuild_rows()


func is_structure_ready() -> bool:
	return get_child_count() == random_rows.size() + 1


func get_group_id() -> String:
	return group_data.get("id", name)


func sync_to_document_nodes(document: DMGraphDocument) -> void:
	_sync_from_fields()
	for row: Dictionary in random_rows:
		if document.has_node(row.id):
			document.nodes[row.id] = row.duplicate(true)


func has_output_port(port: int) -> bool:
	return port >= 0 and port < random_rows.size() and is_structure_ready()


func has_input_port(port: int) -> bool:
	return port == 0 and is_structure_ready()


func _apply_node_title() -> void:
	DMGraphNodeTheme.apply_title(self, DMGraphNodeTheme.get_accent_for_type(DMConstants.TYPE_RANDOM))
	title = "Random"


func _rebuild_rows() -> void:
	if not is_inside_tree() or _is_rebuilding:
		return

	_is_rebuilding = true
	_suppress_field_sync = true
	_disconnect_own_connections()

	for child: Node in get_children():
		remove_child(child)
		child.free()

	group_data.random_ids = [] as Array[String]

	for i: int in range(0, random_rows.size()):
		var row_data: Dictionary = random_rows[i]
		group_data.random_ids.append(row_data.id)
		var row: HBoxContainer = _create_random_row(row_data, i)
		add_child(_wrap_row(row, i))

	var add_row: HBoxContainer = _create_add_row()
	add_child(_wrap_row(add_row, random_rows.size()))

	_configure_slots()
	_update_minimum_size()
	_is_rebuilding = false
	group_rebuilt.emit()
	call_deferred("_end_row_rebuild")


func _end_row_rebuild() -> void:
	_suppress_field_sync = false


func _wrap_row(row: HBoxContainer, row_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_row_strip_style(row_index))
	panel.add_child(row)
	panel.custom_minimum_size.y = ROW_HEIGHT + 4.0
	panel.set_meta(&"random_row", row)
	return panel


func _get_row_content(row_node: Control) -> HBoxContainer:
	if row_node is PanelContainer and row_node.has_meta(&"random_row"):
		return row_node.get_meta(&"random_row") as HBoxContainer
	return row_node as HBoxContainer


func _create_random_row(row_data: Dictionary, row_index: int) -> HBoxContainer:
	var text: String = row_data.get("text", "")
	var weight: int = row_data.get("weight", 1)
	var body: String = text.strip_edges()
	if body.begins_with("%"):
		var parts: PackedStringArray = body.split(" ", false, 1)
		if parts.size() > 0:
			var weight_token: String = parts[0].substr(1)
			if weight_token.is_valid_int():
				weight = int(weight_token)
				body = parts[1] if parts.size() > 1 else ""
			else:
				body = body.substr(1).strip_edges()

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)
	row.custom_minimum_size.y = ROW_HEIGHT

	var weight_label: Label = Label.new()
	weight_label.name = "WeightLabel"
	weight_label.text = "%" + ("" if weight <= 1 else str(weight))
	weight_label.custom_minimum_size = Vector2(28.0, 0)
	DMGraphNodeTheme.apply_response_number_label(weight_label)
	row.add_child(weight_label)

	var display_label: Label = DMGraphNodeTheme.create_display_label("RandomDisplayLabel")
	display_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DMGraphNodeTheme.apply_display_body_label(display_label)
	row.add_child(display_label)

	var text_edit: TextEdit = TextEdit.new()
	text_edit.name = "TextEdit"
	text_edit.visible = false
	text_edit.text = body
	text_edit.text_changed.connect(_on_field_changed.bind(row_data.id))
	row.add_child(text_edit)

	var weight_spin: SpinBox = SpinBox.new()
	weight_spin.name = "WeightSpin"
	weight_spin.visible = false
	weight_spin.min_value = 1
	weight_spin.max_value = 100
	weight_spin.value = weight
	weight_spin.value_changed.connect(_on_field_changed.bind(row_data.id))
	row.add_child(weight_spin)

	row.set_meta(&"random_id", row_data.id)
	_update_row_display(row, row_index)
	return row


func _update_row_display(row: HBoxContainer, row_index: int) -> void:
	var display_label: Label = row.get_node_or_null("RandomDisplayLabel") as Label
	var text_edit: TextEdit = row.get_node_or_null("TextEdit") as TextEdit
	var weight_spin: SpinBox = row.get_node_or_null("WeightSpin") as SpinBox
	var weight_label: Label = row.get_node_or_null("WeightLabel") as Label
	if not is_instance_valid(display_label) or not is_instance_valid(text_edit):
		return

	var body: String = text_edit.text.strip_edges()
	var weight: int = int(weight_spin.value) if is_instance_valid(weight_spin) else 1
	if is_instance_valid(weight_label):
		weight_label.text = "%" + ("" if weight <= 1 else str(weight))
	display_label.text = DMGraphNodeTheme.truncate_display_text(body if body != "" else "(empty)", 2)


func _create_add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var add_button: Button = Button.new()
	add_button.text = "Add random line"
	add_button.flat = true
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(func() -> void: add_line_requested.emit())
	row.add_child(add_button)
	return row


func _configure_slots() -> void:
	if random_rows.is_empty():
		return
	var port_color: Color = DMGraphNodeTheme.get_port_color_for_type(DMConstants.TYPE_RANDOM)
	for i: int in range(0, random_rows.size()):
		set_slot(i, i == 0, 0, port_color, true, 0, port_color)
	var add_index: int = random_rows.size()
	if add_index < get_child_count():
		set_slot(add_index, false, 0, port_color, false, 0, port_color)


func _disconnect_own_connections() -> void:
	var graph_edit: GraphEdit = get_parent() as GraphEdit
	if not graph_edit:
		return
	for conn: Dictionary in graph_edit.get_connection_list().duplicate():
		if conn.from_node == name or conn.to_node == name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)


func _on_field_changed(_value: Variant, row_id: String) -> void:
	if _is_rebuilding or _suppress_field_sync:
		return
	_sync_row_from_fields(row_id)
	var row_index: int = _find_row_index(row_id)
	if row_index != -1:
		var row: HBoxContainer = _get_row_content(get_child(row_index) as Control)
		if row:
			_update_row_display(row, row_index)
	_update_minimum_size()
	content_changed.emit()


func _sync_from_fields() -> void:
	for row: Dictionary in random_rows:
		_sync_row_from_fields(row.id)


func _sync_row_from_fields(row_id: String) -> void:
	var row_index: int = _find_row_index(row_id)
	if row_index == -1:
		return
	var row_node: HBoxContainer = _get_row_content(get_child(row_index) as Control)
	if not row_node:
		return
	var text_edit: TextEdit = row_node.get_node_or_null("TextEdit") as TextEdit
	var weight_spin: SpinBox = row_node.get_node_or_null("WeightSpin") as SpinBox

	for row_data: Dictionary in random_rows:
		if row_data.id != row_id:
			continue
		var body: String = text_edit.text.strip_edges() if is_instance_valid(text_edit) else ""
		var weight: int = int(weight_spin.value) if is_instance_valid(weight_spin) else 1
		row_data.weight = weight
		row_data.is_random = true
		if body == "":
			row_data.text = "%"
		elif weight <= 1:
			row_data.text = "%% %s" % body
		else:
			row_data.text = "%%%d %s" % [weight, body]
		break


func _find_row_index(row_id: String) -> int:
	for i: int in range(0, random_rows.size()):
		if random_rows[i].id == row_id:
			return i
	return -1


func _update_minimum_size() -> void:
	var max_width: float = MIN_TEXT_WIDTH
	for i: int in range(0, random_rows.size()):
		if i >= get_child_count():
			break
		var row: HBoxContainer = _get_row_content(get_child(i) as Control)
		if not row:
			continue
		var display_label: Label = row.get_node_or_null("RandomDisplayLabel") as Label
		if is_instance_valid(display_label):
			max_width = maxf(max_width, float(display_label.text.length()) * 7.0 + 56.0)
	max_width = mini(max_width, MAX_TEXT_WIDTH)
	var total_height: float = 0.0
	for i: int in range(0, get_child_count()):
		var wrapper: Control = get_child(i) as Control
		if wrapper:
			total_height += wrapper.custom_minimum_size.y
	custom_minimum_size = Vector2(max_width + GROUP_HORIZONTAL_PADDING, total_height + 12.0)
