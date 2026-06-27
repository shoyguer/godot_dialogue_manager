@tool
extends GraphNode
class_name DMGraphNode


signal content_changed()


const TYPE_COLORS: Dictionary = {
	DMConstants.TYPE_DIALOGUE: Color(0.65, 0.2, 0.2),
	DMConstants.TYPE_RESPONSE: Color(0.2, 0.55, 0.3),
	DMConstants.TYPE_CONDITION: Color(0.2, 0.4, 0.7),
	DMConstants.TYPE_WHILE: Color(0.2, 0.4, 0.7),
	DMConstants.TYPE_MATCH: Color(0.2, 0.4, 0.7),
	DMConstants.TYPE_WHEN: Color(0.25, 0.45, 0.75),
	DMConstants.TYPE_MUTATION: Color(0.7, 0.45, 0.15),
	DMConstants.TYPE_GOTO: Color(0.55, 0.5, 0.15),
	DMConstants.TYPE_RANDOM: Color(0.15, 0.55, 0.5),
	DMConstants.TYPE_IMPORT: Color(0.4, 0.4, 0.5),
	DMConstants.TYPE_COMMENT: Color(0.35, 0.35, 0.35),
}

const MAX_DIALOGUE_TEXT_HEIGHT: float = 120.0
const MIN_DIALOGUE_WIDTH: float = 180.0
const DISPLAY_MAX_LINES: int = 3
const MAX_MUTATION_WIDTH: float = 720.0
const MUTATION_FIELD_HEIGHT: float = 32.0
const MUTATION_ROW_SEPARATION: float = 10.0
const MAX_RESPONSE_TEXT_WIDTH: float = 640.0
const MAX_RESPONSE_TEXT_HEIGHT: float = 160.0
const DEFAULT_DIALOGUE_TEXT_LINES: int = 2
const CHAR_WIDTH_ESTIMATE: float = 7.5
const PORT_COLOR: Color = DMGraphNodeTheme.PORT_COLOR
const NODE_BOTTOM_MARGIN: float = DMGraphNodeTheme.NODE_BOTTOM_MARGIN
const COMPACT_NODE_WIDTH: float = 140.0


var node_data: Dictionary = {}
var _available_cues: Array[String] = []
var _pending_setup_data: Dictionary = {}
var _text_popup: Window
var _mutation_expand_button: Button
var _is_layout_updating: bool = false
var _suppress_field_signals: bool = false
var has_errors: bool = false:
	set(value):
		has_errors = value
		_update_error_style()

var expression_edit: DMGraphExpressionField

@onready var header_label: Label = %HeaderLabel
@onready var content_label: Label = %ContentLabel
@onready var dialogue_fields: VBoxContainer = %DialogueFields
@onready var character_edit: LineEdit = %CharacterEdit
@onready var text_edit: TextEdit = %TextEdit
@onready var expand_text_button: Button = %ExpandTextButton
@onready var notes_edit: TextEdit = %NotesEdit
@onready var tags_edit: LineEdit = %TagsEdit
@onready var static_id_edit: LineEdit = %StaticIdEdit
@onready var weight_spin: SpinBox = %WeightSpin
@onready var blocking_check: CheckBox = %BlockingCheck
@onready var content_container: VBoxContainer = %ContentContainer
@onready var display_shell: VBoxContainer = %DisplayShell
@onready var display_header_strip: ColorRect = %DisplayHeaderStrip
@onready var display_meta_row: HBoxContainer = %DisplayMetaRow
@onready var display_id_label: Label = %DisplayIdLabel
@onready var display_character_row: HBoxContainer = %DisplayCharacterRow
@onready var display_speaker_name_label: Label = %DisplaySpeakerNameLabel
@onready var display_type_label: Label = %DisplayTypeLabel
@onready var display_character_label: Label = %DisplayCharacterLabel
@onready var display_text_row: HBoxContainer = %DisplayTextRow
@onready var display_text_name_label: Label = %DisplayTextNameLabel
@onready var display_body_label: Label = %DisplayBodyLabel
@onready var display_expression_row: HBoxContainer = %DisplayExpressionRow
@onready var display_expression_name_label: Label = %DisplayExpressionNameLabel
@onready var display_expression_label: Label = %DisplayExpressionLabel
@onready var display_blocking_label: Label = %DisplayBlockingLabel
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var dialogue_bottom_spacer: Control = %DialogueBottomSpacer
@onready var goto_fields: VBoxContainer = %GotoFields
@onready var goto_target_label: Label = %GotoTargetLabel
@onready var goto_target_option: OptionButton = %GotoTargetOption
@onready var goto_bottom_spacer: Control = %GotoBottomSpacer


func _ready() -> void:
	resizable = false
	_ensure_expression_code_field()
	_setup_signals()
	_style_display_labels()
	DMGraphNodeTheme.apply_content_controls(content_container)
	if is_instance_valid(expand_text_button):
		expand_text_button.pressed.connect(_on_expand_text_pressed)
		expand_text_button.tooltip_text = "Open a larger editor for this text"
	_setup_node_tooltips()
	if not gui_input.is_connected(_on_graph_node_gui_input):
		gui_input.connect(_on_graph_node_gui_input)
	if not _pending_setup_data.is_empty():
		_apply_setup(_pending_setup_data)


func _style_display_labels() -> void:
	if is_instance_valid(display_header_strip):
		display_header_strip.hide()
	if is_instance_valid(display_meta_row):
		display_meta_row.hide()
	for field_label: Label in [
		display_speaker_name_label, display_text_name_label, display_expression_name_label,
		speaker_label, text_label, goto_target_label,
	]:
		if is_instance_valid(field_label):
			DMGraphNodeTheme.apply_field_name_label(field_label)
	if is_instance_valid(display_character_label):
		DMGraphNodeTheme.apply_display_character_label(display_character_label)
		display_character_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		display_character_label.clip_text = true
	if is_instance_valid(display_body_label):
		DMGraphNodeTheme.apply_display_body_label(display_body_label)
		display_body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		display_body_label.clip_text = true
	if is_instance_valid(display_expression_label):
		DMGraphNodeTheme.apply_display_body_label(display_expression_label)
		display_expression_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		display_expression_label.clip_text = true
	if is_instance_valid(display_blocking_label):
		DMGraphNodeTheme.apply_display_muted_label(display_blocking_label)
	_style_goto_controls()


func _style_goto_controls() -> void:
	if is_instance_valid(goto_target_option):
		DMGraphNodeTheme.apply_option_button(goto_target_option)


func _setup_node_tooltips() -> void:
	if is_instance_valid(character_edit):
		character_edit.tooltip_text = DMGraphTooltips.INSPECTOR_CHARACTER
	if is_instance_valid(text_edit):
		text_edit.tooltip_text = DMGraphTooltips.INSPECTOR_DIALOGUE
	if is_instance_valid(notes_edit):
		notes_edit.tooltip_text = DMGraphTooltips.INSPECTOR_NOTES
	if is_instance_valid(tags_edit):
		tags_edit.tooltip_text = DMGraphTooltips.INSPECTOR_TAGS
	if is_instance_valid(static_id_edit):
		static_id_edit.tooltip_text = DMGraphTooltips.INSPECTOR_STATIC_ID
	if is_instance_valid(weight_spin):
		weight_spin.tooltip_text = DMGraphTooltips.INSPECTOR_RANDOM_WEIGHT
	if is_instance_valid(blocking_check):
		blocking_check.tooltip_text = DMGraphTooltips.INSPECTOR_MUTATION_BLOCKING
	if is_instance_valid(goto_target_option):
		goto_target_option.tooltip_text = DMGraphTooltips.INSPECTOR_GOTO_TARGET
	if is_instance_valid(display_body_label):
		display_body_label.tooltip_text = "Double-click to edit in the properties panel"


## Replaces the scene LineEdit expression field with a syntax highlighted CodeEdit.
func _ensure_expression_code_field() -> void:
	var existing: Node = get_node_or_null("%ExpressionEdit")
	if existing is DMGraphExpressionField:
		expression_edit = existing as DMGraphExpressionField
		return
	if not existing or not existing is LineEdit:
		return
	var host: Node = existing.get_parent()
	var index: int = existing.get_index()
	var field: DMGraphExpressionField = DMGraphExpressionField.new()
	field.name = "ExpressionEdit"
	field.unique_name_in_owner = true
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var min_size: Vector2 = existing.custom_minimum_size
	field.custom_minimum_size = Vector2(maxf(min_size.x, 120.0), maxf(min_size.y, 28.0))
	field.visible = existing.visible
	field.placeholder_text = existing.placeholder_text
	host.add_child(field)
	host.move_child(field, index)
	existing.queue_free()
	expression_edit = field


func _set_expression_field_value(value: String) -> void:
	if not is_instance_valid(expression_edit): return
	expression_edit.set_text_silent(value)


func _set_expression_field_type(type: String) -> void:
	if is_instance_valid(expression_edit):
		expression_edit.set_line_type(type)


func setup(data: Dictionary) -> void:
	_pending_setup_data = data
	if is_node_ready():
		_apply_setup(data)


func _setup_signals() -> void:
	if is_instance_valid(character_edit):
		character_edit.text_changed.connect(_on_content_changed.unbind(1))
	if is_instance_valid(text_edit):
		text_edit.text_changed.connect(_on_dialogue_text_changed)
	if is_instance_valid(expression_edit):
		expression_edit.text_modified.connect(_on_content_changed.unbind(1))
	if is_instance_valid(notes_edit):
		notes_edit.text_changed.connect(_on_content_changed)
	if is_instance_valid(tags_edit):
		tags_edit.text_changed.connect(_on_content_changed.unbind(1))
	if is_instance_valid(static_id_edit):
		static_id_edit.text_changed.connect(_on_content_changed.unbind(1))
	if is_instance_valid(weight_spin):
		weight_spin.value_changed.connect(_on_content_changed.unbind(1))
	if is_instance_valid(blocking_check):
		blocking_check.toggled.connect(_on_content_changed.unbind(1))
	if is_instance_valid(goto_target_option):
		goto_target_option.item_selected.connect(_on_goto_target_selected)


func set_available_cues(cue_names: Array[String], autoload_names: PackedStringArray = PackedStringArray([])) -> void:
	_available_cues = cue_names.duplicate()
	if node_data.get("type", "") == DMConstants.TYPE_GOTO:
		_refresh_goto_options()
	if is_instance_valid(expression_edit):
		expression_edit.completion_cue_names = cue_names.duplicate()
		expression_edit.completion_autoload_names = autoload_names


func _apply_setup(data: Dictionary) -> void:
	_suppress_field_signals = true
	node_data = data
	name = data.id
	title = _get_title(data)
	position_offset = data.get("position", Vector2.ZERO)

	_apply_type_color(data.type)
	_configure_ports(data)
	_update_fields(data)
	_apply_node_size_policy(data.type)
	_update_error_style()
	call_deferred("_end_field_setup")


func _end_field_setup() -> void:
	_apply_expression_field_from_data()
	_refresh_display_from_data()
	_suppress_field_signals = false


func refresh_display_from_data() -> void:
	_refresh_display_from_data()


func _apply_expression_field_from_data() -> void:
	if not is_instance_valid(expression_edit) or not expression_edit.visible:
		return
	var node_type: String = node_data.get("type", "")
	var value: String = ""
	match node_type:
		DMConstants.TYPE_MUTATION, DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			value = node_data.get("expression", node_data.get("text", ""))
		DMConstants.TYPE_RESPONSE:
			value = node_data.get("condition", "")
	if value != "":
		_set_expression_field_value(value)


func _apply_node_size_policy(type: String) -> void:
	resizable = false


func _apply_type_color(type: String) -> void:
	var accent: Color = DMGraphNodeTheme.get_accent_for_type(type)
	DMGraphNodeTheme.apply_styled_node(self, accent, _get_title(node_data))


func get_data() -> Dictionary:
	_sync_data_from_fields()
	return node_data


func _get_title(data: Dictionary) -> String:
	match data.type:
		DMConstants.TYPE_DIALOGUE:
			if data.get("concurrent_lines", []).size() > 0 or data.get("text", "").begins_with("| "):
				return "Concurrent Dialogue"
			return "Dialogue"
		DMConstants.TYPE_RESPONSE:
			return "Response"
		DMConstants.TYPE_CONDITION:
			return "Condition"
		DMConstants.TYPE_WHILE:
			return "While"
		DMConstants.TYPE_MATCH:
			return "Match"
		DMConstants.TYPE_WHEN:
			return "When"
		DMConstants.TYPE_MUTATION:
			return "Mutation"
		DMConstants.TYPE_GOTO:
			return "Goto"
		DMConstants.TYPE_RANDOM:
			return "Random"
		DMConstants.TYPE_IMPORT:
			return "Import"
		DMConstants.TYPE_UNKNOWN:
			return "Unknown"
		_:
			return data.type.capitalize() if data.type != "" else "Unknown"


func _get_display_type_label(type: String) -> String:
	match type:
		DMConstants.TYPE_DIALOGUE:
			return "DIALOGUE"
		DMConstants.TYPE_MUTATION:
			return "MUTATION"
		DMConstants.TYPE_WHILE:
			return "WHILE"
		DMConstants.TYPE_MATCH:
			return "MATCH"
		DMConstants.TYPE_WHEN:
			return "WHEN"
		DMConstants.TYPE_GOTO:
			return "GOTO"
		DMConstants.TYPE_RANDOM:
			return "RANDOM"
		_:
			return type.to_upper()


func ensure_ports_ready() -> void:
	if node_data.is_empty():
		return
	_configure_ports(node_data)
	_finalize_content_size()


func _configure_ports(data: Dictionary) -> void:
	for i: int in range(get_child_count()):
		clear_slot(i)

	if get_child_count() == 0:
		return

	var port_color: Color = DMGraphNodeTheme.get_port_color_for_type(data.type)
	match data.type:
		DMConstants.TYPE_GOTO:
			set_slot(0, true, 0, port_color, false, 0, port_color)
		_:
			set_slot(0, true, 0, port_color, true, 0, port_color)


func _update_fields(data: Dictionary) -> void:
	_hide_all_fields()

	match data.type:
		DMConstants.TYPE_DIALOGUE:
			_show_dialogue_fields(data)

		DMConstants.TYPE_RESPONSE:
			_show_response_fields(data)

		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			_show_expression_fields(data)

		DMConstants.TYPE_MUTATION:
			_show_mutation_fields(data)

		DMConstants.TYPE_GOTO:
			_show_goto_fields(data)

		DMConstants.TYPE_RANDOM:
			if is_instance_valid(weight_spin):
				weight_spin.show()
				weight_spin.value = data.get("weight", 1)
			_show_dialogue_fields(data)

		_:
			if is_instance_valid(content_label):
				content_label.show()
				content_label.text = data.get("text", "")

	_update_metadata_fields(data)
	if is_instance_valid(content_container):
		content_container.show()
	_finalize_content_size()


func _show_goto_fields(data: Dictionary) -> void:
	if not is_instance_valid(goto_fields):
		return
	goto_fields.show()
	if is_instance_valid(goto_target_label):
		goto_target_label.show()
	if is_instance_valid(goto_bottom_spacer):
		goto_bottom_spacer.show()
		_apply_bottom_spacer_size(goto_bottom_spacer)
	_refresh_goto_options()
	_select_goto_target(data.get("goto_target", _extract_goto_target_from_data(data)))


func _extract_goto_target_from_data(data: Dictionary) -> String:
	var target: String = data.get("goto_target", "")
	if target != "":
		return target.strip_edges()
	var text: String = data.get("text", "").strip_edges()
	if text.begins_with("=>< "):
		return text.substr(4).strip_edges()
	if text.begins_with("=> "):
		return text.substr(3).strip_edges()
	return text


func _refresh_goto_options() -> void:
	if not is_instance_valid(goto_target_option):
		return
	var current_target: String = _extract_goto_target_from_data(node_data)
	goto_target_option.clear()
	var added: Dictionary = {}
	for cue_name: String in _available_cues:
		goto_target_option.add_item(cue_name)
		added[cue_name] = true
	if current_target != "" and not added.has(current_target):
		goto_target_option.add_item(current_target)
	_select_goto_target(current_target)
	if is_instance_valid(goto_target_option):
		goto_target_option.clip_text = false
		goto_target_option.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		DMGraphNodeTheme.apply_popup_menu(goto_target_option.get_popup())
	call_deferred("_resize_node_to_content")


func _select_goto_target(target: String) -> void:
	if not is_instance_valid(goto_target_option):
		return
	for i: int in range(0, goto_target_option.item_count):
		if goto_target_option.get_item_text(i) == target:
			goto_target_option.select(i)
			return
	if goto_target_option.item_count > 0:
		goto_target_option.select(0)


func _on_goto_target_selected(_index: int) -> void:
	_on_content_changed()
	call_deferred("_resize_node_to_content")


func _apply_bottom_spacer_size(spacer: Control) -> void:
	spacer.custom_minimum_size = Vector2(0.0, NODE_BOTTOM_MARGIN)


func _hide_all_fields() -> void:
	if is_instance_valid(display_shell):
		display_shell.hide()
	for node: Node in [
		header_label, content_label, dialogue_fields, goto_fields,
		expression_edit, notes_edit, tags_edit, static_id_edit, weight_spin, blocking_check,
	]:
		if is_instance_valid(node):
			node.hide()
	if is_instance_valid(_mutation_expand_button):
		_mutation_expand_button.hide()


func _show_dialogue_fields(data: Dictionary) -> void:
	_sync_dialogue_hidden_fields(data)
	if is_instance_valid(display_shell):
		display_shell.show()
	if is_instance_valid(dialogue_fields):
		dialogue_fields.hide()
	_refresh_display_from_data()


func _sync_dialogue_hidden_fields(data: Dictionary) -> void:
	var text: String = data.get("text", "")
	var body: String = text
	var character: String = data.get("character", "")
	if is_instance_valid(character_edit):
		var colon_idx: int = text.find(": ")
		if colon_idx > 0 and not text.begins_with("- ") and not text.begins_with("if ") and not text.begins_with("%"):
			character = text.substr(0, colon_idx)
			body = text.substr(colon_idx + 2)
		character_edit.text = character
	if is_instance_valid(text_edit):
		text_edit.text = body


func _show_response_fields(data: Dictionary) -> void:
	_sync_dialogue_hidden_fields({
		"text": data.get("text", "").trim_prefix("- ").strip_edges(),
		"character": "",
	})
	if is_instance_valid(expression_edit):
		_set_expression_field_type(DMConstants.TYPE_CONDITION)
		expression_edit.hide()
		_set_expression_field_value(data.get("condition", ""))
	if is_instance_valid(display_shell):
		display_shell.show()
	_refresh_display_from_data()


func _show_expression_fields(data: Dictionary) -> void:
	if is_instance_valid(display_shell):
		display_shell.show()
	if is_instance_valid(expression_edit):
		_set_expression_field_type(data.type)
		expression_edit.hide()
		_set_expression_field_value(data.get("expression", data.get("text", "")))
	_refresh_display_from_data()


func _show_mutation_fields(data: Dictionary) -> void:
	if is_instance_valid(display_shell):
		display_shell.show()
	if is_instance_valid(expression_edit):
		_set_expression_field_type(DMConstants.TYPE_MUTATION)
		expression_edit.hide()
		var expr: String = data.get("expression", data.get("text", ""))
		_set_expression_field_value(expr)
	if is_instance_valid(blocking_check):
		blocking_check.hide()
		blocking_check.button_pressed = data.get("mutation_blocking", true)
	_refresh_display_from_data()


func _update_metadata_fields(data: Dictionary) -> void:
	if is_instance_valid(notes_edit) and data.get("notes", "") != "":
		notes_edit.show()
		notes_edit.text = data.get("notes", "")
	if is_instance_valid(static_id_edit) and data.get("static_id", "") != "":
		static_id_edit.show()
		static_id_edit.text = data.get("static_id", "")


func _on_dialogue_text_changed() -> void:
	_on_content_changed()
	if node_data.is_empty():
		return
	call_deferred("_update_dialogue_text_layout")


func _get_dialogue_line_height() -> float:
	if not is_instance_valid(text_edit):
		return 28.0
	var font_size: float = float(text_edit.get_theme_font_size(&"font_size"))
	if font_size <= 0.0:
		font_size = 14.0
	return font_size * 1.4 + 6.0


func _estimate_dialogue_text_height(for_width: float) -> float:
	if not is_instance_valid(text_edit):
		return 36.0

	if text_edit.has_method(&"get_content_height"):
		return float(text_edit.call(&"get_content_height"))

	var font_size: float = float(text_edit.get_theme_font_size(&"font_size"))
	if font_size <= 0.0:
		font_size = 14.0
	var line_height: float = font_size * 1.4 + 6.0

	var explicit_lines: int = maxi(1, text_edit.text.split("\n", false).size())
	var line_count: int = explicit_lines

	if explicit_lines == 1 and for_width > 0.0:
		var chars_per_line: int = maxi(1, int(for_width / CHAR_WIDTH_ESTIMATE))
		if text_edit.text.length() > chars_per_line:
			line_count = ceili(float(text_edit.text.length()) / float(chars_per_line))

	return line_height * float(line_count) + 8.0


func _update_dialogue_text_layout() -> void:
	if _is_layout_updating:
		return
	if not is_inside_tree() or not is_instance_valid(text_edit) or not dialogue_fields.visible:
		return

	_is_layout_updating = true

	var width: float = MIN_DIALOGUE_WIDTH
	for line: String in text_edit.text.split("\n"):
		width = maxf(width, float(line.length()) * CHAR_WIDTH_ESTIMATE + 24.0)
	width = mini(width, 480.0)

	var content_height: float = _estimate_dialogue_text_height(width)
	var min_two_line_height: float = _get_dialogue_line_height() * float(DEFAULT_DIALOGUE_TEXT_LINES)
	var needs_expand: bool = content_height > MAX_DIALOGUE_TEXT_HEIGHT + 4.0
	var visible_height: float = maxf(mini(content_height, MAX_DIALOGUE_TEXT_HEIGHT), min_two_line_height)

	text_edit.custom_minimum_size = Vector2(width, visible_height)

	if is_instance_valid(expand_text_button):
		expand_text_button.visible = needs_expand

	var node_height: float = _calculate_dialogue_node_height(width, visible_height, needs_expand)
	custom_minimum_size = Vector2(width + 20.0, node_height)

	_is_layout_updating = false


func _calculate_dialogue_node_height(_text_width: float, text_height: float, expand_visible: bool) -> float:
	var height: float = 0.0
	if is_instance_valid(character_edit) and character_edit.visible:
		height += 34.0
	if is_instance_valid(text_label):
		height += 20.0
	height += text_height + 8.0
	if expand_visible and is_instance_valid(expand_text_button):
		height += 24.0
	if is_instance_valid(dialogue_bottom_spacer) and dialogue_bottom_spacer.visible:
		height += NODE_BOTTOM_MARGIN
	return height + 12.0


func _finalize_content_size() -> void:
	if is_instance_valid(display_shell) and display_shell.visible:
		_update_display_layout()
		return

	match node_data.get("type", ""):
		DMConstants.TYPE_GOTO:
			_resize_node_to_content()
		_:
			_resize_node_to_content()


func _refresh_display_from_data() -> void:
	if node_data.is_empty() or not is_instance_valid(display_shell) or not display_shell.visible:
		return

	for row: Control in [
		display_character_row, display_text_row, display_expression_row,
	]:
		if is_instance_valid(row):
			row.hide()
	for label: Label in [
		display_character_label, display_body_label, display_expression_label, display_blocking_label,
	]:
		if is_instance_valid(label):
			label.hide()

	match node_data.get("type", ""):
		DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RANDOM:
			_populate_dialogue_display()
		DMConstants.TYPE_MUTATION, DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			_populate_expression_display(node_data.get("type", ""))
		DMConstants.TYPE_RESPONSE:
			_populate_response_display()

	if is_inside_tree():
		call_deferred("_update_display_layout")


func _populate_dialogue_display() -> void:
	var char_name: String = ""
	var body: String = ""
	if is_instance_valid(character_edit):
		char_name = character_edit.text
	if is_instance_valid(text_edit):
		body = text_edit.text
	if body == "" and char_name == "":
		var text: String = node_data.get("text", "")
		var colon_idx: int = text.find(": ")
		if colon_idx > 0 and not text.begins_with("- ") and not text.begins_with("if ") and not text.begins_with("%"):
			char_name = text.substr(0, colon_idx)
			body = text.substr(colon_idx + 2)
		else:
			body = text
			char_name = node_data.get("character", "")

	if is_instance_valid(display_character_row):
		display_character_row.show()
	if is_instance_valid(display_speaker_name_label):
		display_speaker_name_label.text = "Speaker"
	if is_instance_valid(display_character_label):
		display_character_label.text = char_name if char_name != "" else "(none)"
		display_character_label.show()

	if is_instance_valid(display_text_row):
		display_text_row.show()
	if is_instance_valid(display_text_name_label):
		display_text_name_label.text = "Text"
	if is_instance_valid(display_body_label):
		var full_text: String = body if body != "" else "(empty)"
		display_body_label.text = DMGraphNodeTheme.truncate_display_text(full_text, DISPLAY_MAX_LINES)
		display_body_label.tooltip_text = full_text
		display_body_label.show()


func _populate_expression_display(node_type: String) -> void:
	var expr: String = ""
	if is_instance_valid(expression_edit):
		expr = expression_edit.text
	if expr == "":
		expr = node_data.get("expression", node_data.get("text", ""))

	if is_instance_valid(display_expression_row):
		display_expression_row.show()
	if is_instance_valid(display_expression_name_label):
		display_expression_name_label.text = _get_expression_field_label(node_type)
	if is_instance_valid(display_expression_label):
		var full_text: String = expr if expr != "" else "(empty)"
		display_expression_label.text = DMGraphNodeTheme.truncate_display_text(full_text, DISPLAY_MAX_LINES)
		display_expression_label.tooltip_text = full_text
		display_expression_label.show()

	if node_type == DMConstants.TYPE_MUTATION and is_instance_valid(display_blocking_label):
		var blocking: bool = node_data.get("mutation_blocking", true)
		if is_instance_valid(blocking_check):
			blocking = blocking_check.button_pressed
		display_blocking_label.text = "Blocking (await)" if blocking else "Non-blocking"
		display_blocking_label.show()


func _populate_response_display() -> void:
	var text: String = node_data.get("text", "").trim_prefix("- ").strip_edges()
	if is_instance_valid(text_edit) and text_edit.text != "":
		text = text_edit.text
	if is_instance_valid(display_text_row):
		display_text_row.show()
	if is_instance_valid(display_text_name_label):
		display_text_name_label.text = "Text"
	if is_instance_valid(display_body_label):
		display_body_label.text = DMGraphNodeTheme.truncate_display_text(text if text != "" else "(empty)", DISPLAY_MAX_LINES)
		display_body_label.tooltip_text = text
		display_body_label.show()
	var condition: String = node_data.get("condition", "")
	if condition != "" and is_instance_valid(display_blocking_label):
		display_blocking_label.text = "[if %s]" % condition
		display_blocking_label.show()


func _get_expression_field_label(node_type: String) -> String:
	match node_type:
		DMConstants.TYPE_MUTATION:
			return "Mutation"
		DMConstants.TYPE_WHILE:
			return "While"
		DMConstants.TYPE_MATCH:
			return "Match"
		DMConstants.TYPE_WHEN:
			return "When"
		_:
			return "Expression"


func _update_display_layout() -> void:
	if _is_layout_updating or not is_inside_tree():
		return
	if not is_instance_valid(display_shell) or not display_shell.visible:
		return

	_is_layout_updating = true

	var line_h: float = 18.0
	var label_w: float = DMGraphNodeTheme.FIELD_LABEL_WIDTH
	var width: float = MIN_DIALOGUE_WIDTH
	for value_label: Label in [display_character_label, display_body_label, display_expression_label]:
		if not is_instance_valid(value_label) or not value_label.visible:
			continue
		width = maxf(width, label_w + float(value_label.text.length()) * CHAR_WIDTH_ESTIMATE + 24.0)
	width = mini(width, 480.0)
	var value_width: float = maxf(80.0, width - label_w - 8.0)

	var height: float = 4.0
	if is_instance_valid(display_character_row) and display_character_row.visible:
		if is_instance_valid(display_character_label):
			display_character_label.custom_minimum_size = Vector2(value_width, line_h)
		height += line_h + 2.0
	if is_instance_valid(display_text_row) and display_text_row.visible:
		if is_instance_valid(display_body_label) and display_body_label.visible:
			var lines: int = mini(DISPLAY_MAX_LINES, maxi(1, display_body_label.text.split("\n", false).size()))
			var body_h: float = line_h * float(lines)
			display_body_label.custom_minimum_size = Vector2(value_width, body_h)
			height += body_h + 2.0
	if is_instance_valid(display_expression_row) and display_expression_row.visible:
		if is_instance_valid(display_expression_label) and display_expression_label.visible:
			var expr_lines: int = mini(DISPLAY_MAX_LINES, maxi(1, display_expression_label.text.split("\n", false).size()))
			var expr_h: float = line_h * float(expr_lines)
			display_expression_label.custom_minimum_size = Vector2(value_width, expr_h)
			height += expr_h + 2.0
	if is_instance_valid(display_blocking_label) and display_blocking_label.visible:
		height += 14.0
	height += DMGraphNodeTheme.NODE_BOTTOM_MARGIN + 6.0

	display_shell.custom_minimum_size = Vector2(width, height)
	custom_minimum_size = Vector2(width + 16.0, height + 28.0)
	_is_layout_updating = false


func _on_graph_node_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.double_click:
		return
	mouse.accept_event()
	DMGraphNodeTheme.register_drag_guard(self)

	var node_type: String = node_data.get("type", "")
	match node_type:
		DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RANDOM:
			_open_dialogue_edit_popup()
		DMConstants.TYPE_MUTATION:
			_open_mutation_edit_popup()
		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			_open_expression_edit_popup()
		DMConstants.TYPE_RESPONSE:
			_open_response_edit_popup()


func _configure_edit_popup_close(popup: Window) -> void:
	popup.close_requested.connect(func() -> void:
		popup.queue_free()
		DMGraphNodeTheme.release_drag_guard(self)
	)


func _open_dialogue_edit_popup() -> void:
	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit dialogue"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(520, 360)
	_text_popup.min_size = Vector2i(360, 240)
	_configure_edit_popup_close(_text_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_text_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var char_field: LineEdit = LineEdit.new()
	char_field.placeholder_text = "Character name"
	if is_instance_valid(character_edit):
		char_field.text = character_edit.text
	vbox.add_child(char_field)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_instance_valid(text_edit):
		popup_edit.text = text_edit.text
	popup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(popup_edit)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		if is_instance_valid(character_edit):
			character_edit.text = char_field.text
		if is_instance_valid(text_edit):
			text_edit.text = popup_edit.text
		_on_content_changed()
		_refresh_display_from_data()
		_text_popup.queue_free()
		DMGraphNodeTheme.release_drag_guard(self)
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()

	if char_field.text != "":
		_text_popup.title = "%s — dialogue" % char_field.text


func _open_mutation_edit_popup() -> void:
	if not is_instance_valid(expression_edit):
		return

	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit mutation"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(520, 240)
	_text_popup.min_size = Vector2i(360, 160)
	_configure_edit_popup_close(_text_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_text_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_edit.text = expression_edit.text
	popup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(popup_edit)

	var blocking_row: CheckBox = CheckBox.new()
	blocking_row.text = "Blocking (await)"
	blocking_row.button_pressed = node_data.get("mutation_blocking", true)
	if is_instance_valid(blocking_check):
		blocking_row.button_pressed = blocking_check.button_pressed
	vbox.add_child(blocking_row)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		expression_edit.text = popup_edit.text
		if is_instance_valid(blocking_check):
			blocking_check.button_pressed = blocking_row.button_pressed
		_on_content_changed()
		_refresh_display_from_data()
		_text_popup.queue_free()
		DMGraphNodeTheme.release_drag_guard(self)
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()


func _open_expression_edit_popup() -> void:
	if not is_instance_valid(expression_edit):
		return

	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit expression"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(520, 200)
	_text_popup.min_size = Vector2i(360, 120)
	_configure_edit_popup_close(_text_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_text_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_edit.text = expression_edit.text
	popup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(popup_edit)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		expression_edit.text = popup_edit.text
		_on_content_changed()
		_refresh_display_from_data()
		_text_popup.queue_free()
		DMGraphNodeTheme.release_drag_guard(self)
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()


func _open_response_edit_popup() -> void:
	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit response"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(480, 200)
	_text_popup.min_size = Vector2i(320, 120)
	_configure_edit_popup_close(_text_popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_text_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_instance_valid(text_edit):
		popup_edit.text = text_edit.text
	vbox.add_child(popup_edit)

	var condition_edit: LineEdit = LineEdit.new()
	condition_edit.placeholder_text = "Condition (optional)"
	condition_edit.text = node_data.get("condition", "")
	if is_instance_valid(expression_edit):
		condition_edit.text = expression_edit.text
	vbox.add_child(condition_edit)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		if is_instance_valid(text_edit):
			text_edit.text = popup_edit.text
		if is_instance_valid(expression_edit):
			expression_edit.set_text_silent(condition_edit.text)
		_on_content_changed()
		_refresh_display_from_data()
		_text_popup.queue_free()
		DMGraphNodeTheme.release_drag_guard(self)
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()


func _on_expand_text_pressed() -> void:
	DMGraphNodeTheme.register_drag_guard(self)
	_open_dialogue_edit_popup()


func _on_expand_mutation_pressed() -> void:
	DMGraphNodeTheme.register_drag_guard(self)
	_open_mutation_edit_popup()


func _resize_node_to_content() -> void:
	if is_instance_valid(dialogue_fields) and dialogue_fields.visible:
		_update_dialogue_text_layout()
		return

	match node_data.get("type", ""):
		DMConstants.TYPE_GOTO:
			var label_width: float = DMGraphNodeTheme.FIELD_LABEL_WIDTH
			var option_width: float = DMGraphNodeTheme.measure_option_button_width(goto_target_option)
			if is_instance_valid(goto_target_option):
				goto_target_option.custom_minimum_size.x = option_width
				goto_target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var goto_width: float = maxf(COMPACT_NODE_WIDTH, label_width + option_width + 24.0)
			var goto_height: float = 52.0 + NODE_BOTTOM_MARGIN
			if is_instance_valid(goto_fields) and goto_fields.visible:
				goto_fields.custom_minimum_size.x = goto_width
				goto_height = maxf(goto_height, goto_fields.get_combined_minimum_size().y + 16.0)
			custom_minimum_size = Vector2(goto_width, goto_height)
			return
		DMConstants.TYPE_MUTATION:
			if is_instance_valid(display_shell) and display_shell.visible:
				_update_display_layout()
			else:
				_update_mutation_layout()
			return

	var height: float = 40.0
	if is_instance_valid(content_container) and content_container.visible:
		height = maxf(height, content_container.get_combined_minimum_size().y + 28.0)
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, MIN_DIALOGUE_WIDTH), height + NODE_BOTTOM_MARGIN)


func _ensure_mutation_expand_button() -> void:
	if is_instance_valid(_mutation_expand_button):
		return
	if not is_instance_valid(content_container) or not is_instance_valid(expression_edit):
		return
	_mutation_expand_button = Button.new()
	_mutation_expand_button.name = "MutationExpandButton"
	_mutation_expand_button.text = "… more text"
	_mutation_expand_button.focus_mode = Control.FOCUS_NONE
	_mutation_expand_button.flat = true
	_mutation_expand_button.visible = false
	_mutation_expand_button.pressed.connect(_on_expand_mutation_pressed)
	var insert_index: int = expression_edit.get_index() + 1
	content_container.add_child(_mutation_expand_button)
	content_container.move_child(_mutation_expand_button, insert_index)


func _update_mutation_layout() -> void:
	if _is_layout_updating:
		return
	if not is_inside_tree() or not is_instance_valid(expression_edit) or node_data.get("type", "") != DMConstants.TYPE_MUTATION:
		return
	if not expression_edit.visible:
		return

	_is_layout_updating = true
	_ensure_mutation_expand_button()

	var expr: String = expression_edit.text
	var natural_width: float = maxf(MIN_DIALOGUE_WIDTH, float(expr.length()) * CHAR_WIDTH_ESTIMATE + 40.0)
	var needs_expand: bool = natural_width > MAX_MUTATION_WIDTH + 4.0
	var visible_width: float = mini(natural_width, MAX_MUTATION_WIDTH)

	expression_edit.custom_minimum_size = Vector2(visible_width, MUTATION_FIELD_HEIGHT)

	if is_instance_valid(_mutation_expand_button):
		_mutation_expand_button.visible = needs_expand

	var height: float = 28.0
	if is_instance_valid(header_label) and header_label.visible:
		height += 24.0
	height += MUTATION_FIELD_HEIGHT + MUTATION_ROW_SEPARATION
	if is_instance_valid(blocking_check) and blocking_check.visible:
		height += 28.0
	if needs_expand and is_instance_valid(_mutation_expand_button):
		height += 24.0
	height += NODE_BOTTOM_MARGIN + 12.0

	custom_minimum_size = Vector2(visible_width + 24.0, height)
	_is_layout_updating = false


func _sync_data_from_fields() -> void:
	node_data.position = position_offset

	match node_data.type:
		DMConstants.TYPE_DIALOGUE:
			var char_name: String = character_edit.text if is_instance_valid(character_edit) else ""
			var body: String = text_edit.text if is_instance_valid(text_edit) else ""
			if char_name != "":
				node_data.text = "%s: %s" % [char_name, body]
				node_data.character = char_name
			else:
				node_data.text = body

		DMConstants.TYPE_RESPONSE:
			var resp_text: String = text_edit.text if is_instance_valid(text_edit) else ""
			node_data.text = "- %s" % resp_text
			if is_instance_valid(expression_edit) and expression_edit.text != "":
				node_data.condition = expression_edit.text

		DMConstants.TYPE_GOTO:
			var target: String = ""
			if is_instance_valid(goto_target_option) and goto_target_option.item_count > 0:
				target = goto_target_option.get_item_text(goto_target_option.selected)
			node_data.goto_target = target
			var prefix: String = "=>< " if node_data.get("is_snippet", false) else "=> "
			node_data.text = "%s%s" % [prefix, target]

		DMConstants.TYPE_MUTATION:
			_sync_expression_field_to_data()
			if is_instance_valid(blocking_check):
				node_data.mutation_blocking = blocking_check.button_pressed

		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			_sync_expression_field_to_data()

		DMConstants.TYPE_RANDOM:
			if is_instance_valid(weight_spin):
				node_data.weight = int(weight_spin.value)

	if is_instance_valid(notes_edit):
		node_data.notes = notes_edit.text
	if is_instance_valid(static_id_edit):
		node_data.static_id = static_id_edit.text
	if is_instance_valid(tags_edit) and tags_edit.visible:
		if tags_edit.text.strip_edges() == "":
			node_data.tags = PackedStringArray()
		else:
			var tag_parts: PackedStringArray = PackedStringArray()
			for part: String in tags_edit.text.split(","):
				var tag: String = part.strip_edges()
				if tag != "":
					tag_parts.append(tag)
			node_data.tags = tag_parts


func _sync_expression_field_to_data() -> void:
	if not is_instance_valid(expression_edit):
		return
	var field_text: String = expression_edit.text
	if field_text == "" and node_data.get("expression", node_data.get("text", "")) != "":
		return
	node_data.expression = field_text
	node_data.text = field_text


func _on_content_changed(_arg: Variant = null) -> void:
	if _suppress_field_signals:
		return
	_sync_data_from_fields()
	if is_instance_valid(display_shell) and display_shell.visible:
		call_deferred("_refresh_display_from_data")
	elif node_data.get("type", "") == DMConstants.TYPE_MUTATION:
		call_deferred("_update_mutation_layout")
	content_changed.emit()


func _update_error_style() -> void:
	if has_errors:
		add_theme_stylebox_override("frame", _make_error_frame())
	else:
		remove_theme_stylebox_override("frame")


func _make_error_frame() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.1, 0.9)
	style.border_color = Color(1, 0.2, 0.2)
	style.set_border_width_all(2)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
