@tool
extends PanelContainer
class_name DMGraphInspector


signal property_changed()
signal insert_requested(text: String)


@onready var type_label: Label = %TypeLabel
@onready var notes_edit: TextEdit = %NotesEdit
@onready var static_id_edit: LineEdit = %StaticIdEdit
@onready var tags_edit: LineEdit = %TagsEdit
@onready var insert_menu: MenuButton = %InsertMenu


var current_node_data: Dictionary = {}


func _ready() -> void:
	_setup_insert_menu()
	if is_instance_valid(notes_edit):
		notes_edit.text_changed.connect(_on_property_changed)
	if is_instance_valid(static_id_edit):
		static_id_edit.text_changed.connect(_on_property_changed.unbind(1))
	if is_instance_valid(tags_edit):
		tags_edit.text_changed.connect(_on_property_changed.unbind(1))


func _setup_insert_menu() -> void:
	if not is_instance_valid(insert_menu):
		return
	var popup: PopupMenu = insert_menu.get_popup()
	popup.clear()
	popup.add_item("Wait [wait=N]", 0)
	popup.add_item("Speed [speed=N]", 1)
	popup.add_item("Auto-advance [next=auto]", 2)
	popup.add_item("Random text [[a|b|c]]", 3)
	popup.add_item("Wave BBCode", 4)
	popup.add_item("Shake BBCode", 5)
	popup.id_pressed.connect(_on_insert_id_pressed)


func inspect(node_data: Dictionary) -> void:
	current_node_data = node_data
	if is_instance_valid(type_label):
		type_label.text = node_data.get("type", "").capitalize()
	if is_instance_valid(notes_edit):
		notes_edit.text = node_data.get("notes", "")
	if is_instance_valid(static_id_edit):
		static_id_edit.text = node_data.get("static_id", "")
	if is_instance_valid(tags_edit):
		tags_edit.text = ", ".join(node_data.get("tags", []))
	show()


func clear_inspection() -> void:
	current_node_data = {}
	hide()


func get_updated_data() -> Dictionary:
	if current_node_data.is_empty():
		return {}
	if is_instance_valid(notes_edit):
		current_node_data.notes = notes_edit.text
	if is_instance_valid(static_id_edit):
		current_node_data.static_id = static_id_edit.text
	if is_instance_valid(tags_edit) and tags_edit.text != "":
		var tags: PackedStringArray = PackedStringArray([])
		for part: String in tags_edit.text.split(","):
			tags.append(part.strip_edges())
		current_node_data.tags = tags
	return current_node_data


func _on_property_changed(_arg: Variant = null) -> void:
	property_changed.emit()


func _on_insert_id_pressed(id: int) -> void:
	var insertion: String = ""
	match id:
		0: insertion = "[wait=1]"
		1: insertion = "[speed=0.5]"
		2: insertion = "[next=auto]"
		3: insertion = "[[Hi|Hello|Howdy]]"
		4: insertion = "[wave amp=25 freq=5]text[/wave]"
		5: insertion = "[shake rate=20 level=10]text[/shake]"
	insert_requested.emit(insertion)
