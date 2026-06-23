@tool
extends GraphNode
class_name DMGraphCompactNode


signal content_changed()


const TYPE_COLORS: Dictionary = {
	DMConstants.TYPE_CUE: Color(0.45, 0.25, 0.65),
	DMConstants.TYPE_END: Color(0.25, 0.25, 0.3),
}

const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR
const MIN_WIDTH: float = 120.0
const BODY_HEIGHT: float = 40.0


var node_data: Dictionary = {}
var _fill_color: Color = Color(0.45, 0.25, 0.65)
var has_errors: bool = false:
	set(value):
		has_errors = value
		_update_error_style()


@onready var row: PanelContainer = %Row
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	resizable = false
	title = ""
	clip_contents = false
	DMGraphNodeTheme.apply_compact(self, _fill_color)
	if not node_data.is_empty():
		_apply_from_data(node_data)


func setup(data: Dictionary) -> void:
	node_data = data
	if is_node_ready():
		_apply_from_data(data)


func get_data() -> Dictionary:
	node_data.position = position_offset
	return node_data


func ensure_ports_ready() -> void:
	if node_data.is_empty():
		return
	_configure_ports(node_data.type)
	_update_size()


func has_output_port(port: int) -> bool:
	return node_data.get("type", "") == DMConstants.TYPE_CUE and port == 0 and get_child_count() > 0


func has_input_port(port: int) -> bool:
	return port == 0 and get_child_count() > 0


func _apply_from_data(data: Dictionary) -> void:
	name = data.id
	position_offset = data.get("position", Vector2.ZERO)
	_fill_color = TYPE_COLORS.get(data.type, Color(0.3, 0.3, 0.35))
	DMGraphNodeTheme.apply_compact(self, _fill_color)
	DMGraphNodeTheme.apply_compact_panel(row, _fill_color)
	if is_instance_valid(title_label):
		title_label.text = _get_title(data)
	_configure_ports(data.type)
	_update_size()
	_update_error_style()


func _get_title(data: Dictionary) -> String:
	match data.type:
		DMConstants.TYPE_CUE:
			return "Cue: %s" % data.get("cue_name", "")
		DMConstants.TYPE_END:
			return "End"
		_:
			return data.type.capitalize()


func _configure_ports(type: String) -> void:
	if get_child_count() == 0:
		return
	clear_slot(0)
	match type:
		DMConstants.TYPE_CUE:
			set_slot(0, true, 0, PORT_COLOR, true, 0, PORT_COLOR)
		DMConstants.TYPE_END:
			set_slot(0, true, 0, PORT_COLOR, false, 0, PORT_COLOR)
		_:
			set_slot(0, true, 0, PORT_COLOR, true, 0, PORT_COLOR)


func _update_size() -> void:
	var label_text: String = _get_title(node_data) if not node_data.is_empty() else ""
	if is_instance_valid(title_label) and title_label.text != "":
		label_text = title_label.text
	var title_width: float = maxf(MIN_WIDTH, float(label_text.length()) * 7.5 + 36.0)
	custom_minimum_size = Vector2(title_width, BODY_HEIGHT)
	if is_instance_valid(row):
		row.custom_minimum_size = Vector2(title_width, BODY_HEIGHT)


func _update_error_style() -> void:
	if has_errors:
		add_theme_stylebox_override(&"frame", _make_error_frame())
	else:
		remove_theme_stylebox_override(&"frame")


func _make_error_frame() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.1, 0.9)
	style.border_color = Color(1, 0.2, 0.2)
	style.set_border_width_all(2)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
