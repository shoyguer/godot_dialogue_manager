@tool
class_name DMGraphNodePalette
extends HBoxContainer
## Toolbar add node menu for the graph editor.


## Emitted when the user picks a node type from the menu.
signal node_type_selected(type: String)


@onready var add_button: MenuButton = %AddButton


func _ready() -> void:
	_build_menu()


func _build_menu(include_type: Callable = Callable()) -> void:
	if not is_instance_valid(add_button): return
	var popup: PopupMenu = add_button.get_popup()
	if popup.id_pressed.is_connected(_on_menu_id_pressed):
		popup.id_pressed.disconnect(_on_menu_id_pressed)
	DMGraphNodeIcons.populate_popup(popup, include_type)
	popup.id_pressed.connect(_on_menu_id_pressed)


func rebuild_add_menu(include_type: Callable = Callable()) -> void:
	_build_menu(include_type)


func _on_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = add_button.get_popup()
	var type: String = DMGraphNodeIcons.get_type_for_menu_id(popup, id)
	if type != "":
		node_type_selected.emit(type)


func apply_theme() -> void:
	_build_menu()
	if is_instance_valid(add_button):
		add_button.icon = get_theme_icon("Add", "EditorIcons")
