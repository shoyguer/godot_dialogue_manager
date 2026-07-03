@tool
extends GraphNode
class_name DMGraphCompactNode


signal content_changed()
signal node_interacted()


const MIN_WIDTH: float = 120.0
const BODY_HEIGHT: float = 40.0
const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR


var node_data: Dictionary = {}
var _fill_color: Color = DMGraphNodeTheme.ACCENT_CUE
var _body_hovered: bool = false
var has_errors: bool = false:
	set(value):
		has_errors = value
		_update_row_visual()


@onready var row: PanelContainer = %Row
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	resizable = false
	draggable = true
	title = ""
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	DMGraphNodeTheme.apply_compact(self, _fill_color)
	if is_instance_valid(row):
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(title_label):
		title_label.visible = true
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not node_data.is_empty():
		_apply_from_data(node_data)
	call_deferred("_collapse_titlebar")


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


func is_mouse_over_body(mouse_global: Vector2) -> bool:
	return get_global_rect().has_point(mouse_global)


func set_body_hovered(hovered: bool) -> void:
	if _body_hovered == hovered:
		return
	_body_hovered = hovered
	_update_row_visual()


func refresh_display_from_data() -> void:
	if not node_data.is_empty():
		_apply_from_data(node_data)


func _apply_from_data(data: Dictionary) -> void:
	name = data.id
	position_offset = data.get("position", Vector2.ZERO)
	_fill_color = DMGraphNodeTheme.get_accent_for_type(data.type)
	DMGraphNodeTheme.apply_compact(self, _fill_color)
	if is_instance_valid(title_label):
		title_label.text = _get_title(data)
	_configure_ports(data.type)
	_update_size()
	_update_row_visual()
	call_deferred("_collapse_titlebar")


func _collapse_titlebar() -> void:
	var title_hbox: HBoxContainer = get_titlebar_hbox()
	if not is_instance_valid(title_hbox):
		return
	title_hbox.visible = false
	title_hbox.custom_minimum_size = Vector2.ZERO
	title_hbox.size = Vector2.ZERO


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
	var port_color: Color = DMGraphNodeTheme.get_port_color_for_type(type)
	match type:
		DMConstants.TYPE_CUE:
			set_slot(0, true, 0, port_color, true, 0, port_color, null, null, false)
		DMConstants.TYPE_END:
			set_slot(0, true, 0, port_color, false, 0, port_color, null, null, false)
		_:
			set_slot(0, true, 0, port_color, true, 0, port_color, null, null, false)


func _update_size() -> void:
	var label_text: String = _get_title(node_data) if not node_data.is_empty() else ""
	if is_instance_valid(title_label) and title_label.text != "":
		label_text = title_label.text
	var title_width: float = maxf(MIN_WIDTH, float(label_text.length()) * 7.5 + 36.0)
	custom_minimum_size = Vector2(title_width, BODY_HEIGHT)
	if is_instance_valid(row):
		row.custom_minimum_size = Vector2(title_width, BODY_HEIGHT)
		DMGraphNodeTheme.apply_compact_panel_label(row)


func _update_row_visual() -> void:
	if not is_instance_valid(row):
		return
	if has_errors:
		row.add_theme_stylebox_override(&"panel", _make_error_panel_style())
	elif _body_hovered:
		row.add_theme_stylebox_override(&"panel", DMGraphNodeTheme.make_compact_panel_style(_fill_color, false, true))
	else:
		DMGraphNodeTheme.apply_compact_panel(row, _fill_color)
		DMGraphNodeTheme.apply_compact_panel_label(row)


func _make_error_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = DMGraphNodeTheme.make_compact_panel_style(_fill_color)
	style.bg_color = Color(0.15, 0.1, 0.1, 0.9)
	style.border_color = Color(1, 0.2, 0.2)
	style.set_border_width_all(2)
	return style
