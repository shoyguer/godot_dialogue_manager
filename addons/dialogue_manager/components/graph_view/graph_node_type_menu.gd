@tool
class_name DMGraphNodeTypeMenu
extends PopupPanel
## Add-node menu with alternating row colors.


signal type_selected(type: String)


var _rows: VBoxContainer = null


func _ready() -> void:
	DMGraphNodeTheme.apply_type_menu_panel(self)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 4)
	margin.add_theme_constant_override(&"margin_right", 4)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_bottom", 4)
	margin.add_child(_rows)
	add_child(margin)


func populate(include_type: Callable = Callable()) -> void:
	if not is_instance_valid(_rows):
		return
	for child: Node in _rows.get_children():
		child.free()
	var row_index: int = 0
	for entry: Dictionary in DMGraphNodeIcons.NODE_ENTRIES:
		var type: String = entry.get("type", "")
		if include_type.is_valid() and not include_type.call(type):
			continue
		_rows.add_child(_make_row(entry, row_index))
		row_index += 1


func has_entries() -> bool:
	return is_instance_valid(_rows) and _rows.get_child_count() > 0


func _make_row(entry: Dictionary, row_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var row_style: StyleBox = DMGraphNodeTheme.make_type_menu_row_style(row_index)
	panel.add_theme_stylebox_override(&"panel", row_style)
	panel.custom_minimum_size.y = 28.0

	var button: Button = Button.new()
	button.text = entry.get("label", entry.get("type", ""))
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override(&"font_color", DMGraphNodeTheme.DISPLAY_TEXT_COLOR)
	button.add_theme_font_size_override(&"font_size", DMGraphNodeTheme.DISPLAY_FONT_SIZE)
	var normal: StyleBoxEmpty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"focus", normal)
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = DMGraphNodeTheme.ROW_HOVER_COLOR
	hover.set_border_width_all(0)
	button.add_theme_stylebox_override(&"hover", hover)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = DMGraphNodeTheme.ROW_SELECTED_COLOR
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.tooltip_text = entry.get("tooltip", "")
	var type: String = entry.get("type", "")
	button.pressed.connect(func() -> void:
		hide()
		type_selected.emit(type)
	)

	panel.add_child(button)
	return panel
