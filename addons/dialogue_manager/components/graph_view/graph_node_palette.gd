@tool
class_name DMGraphNodePalette
extends HBoxContainer
## Toolbar add-node buttons for the graph editor.


signal node_type_selected(type: String)


@onready var add_buttons_row: HBoxContainer = %AddButtonsRow
@onready var auto_layout_button: Button = %AutoLayoutButton

var _include_type: Callable = Callable()


func _ready() -> void:
	rebuild_add_menu()


func rebuild_add_menu(include_type: Callable = Callable()) -> void:
	_include_type = include_type
	_clear_add_buttons()
	if not is_instance_valid(add_buttons_row):
		return

	for entry: Dictionary in DMGraphNodeIcons.NODE_ENTRIES:
		var type: String = entry.type
		if include_type.is_valid() and not include_type.call(type):
			continue
		var button: Button = Button.new()
		button.text = "+ %s" % entry.get("label", type.capitalize())
		var icon: Texture2D = DMGraphNodeIcons.get_icon(entry)
		if icon:
			button.icon = icon
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DMGraphNodeTheme.apply_palette_add_button(button)
		button.pressed.connect(_on_add_button_pressed.bind(type))
		add_buttons_row.add_child(button)


func _clear_add_buttons() -> void:
	if not is_instance_valid(add_buttons_row):
		return
	for child: Node in add_buttons_row.get_children():
		child.queue_free()


func _on_add_button_pressed(type: String) -> void:
	if type != "":
		node_type_selected.emit(type)


func apply_theme() -> void:
	rebuild_add_menu(_include_type)
