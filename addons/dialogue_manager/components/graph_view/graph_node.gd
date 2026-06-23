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
const MIN_DIALOGUE_WIDTH: float = 240.0
const MAX_MUTATION_WIDTH: float = 720.0
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
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var dialogue_bottom_spacer: Control = %DialogueBottomSpacer
@onready var goto_fields: VBoxContainer = %GotoFields
@onready var goto_target_label: Label = %GotoTargetLabel
@onready var goto_target_option: OptionButton = %GotoTargetOption
@onready var goto_bottom_spacer: Control = %GotoBottomSpacer


func _ready() -> void:
	resizable = true
	_ensure_expression_code_field()
	_setup_signals()
	DMGraphNodeTheme.apply_content_controls(content_container)
	if is_instance_valid(expand_text_button):
		expand_text_button.pressed.connect(_on_expand_text_pressed)
	if not _pending_setup_data.is_empty():
		_apply_setup(_pending_setup_data)


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
	var field := DMGraphExpressionField.new()
	field.name = "ExpressionEdit"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = existing.custom_minimum_size
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


func set_available_cues(cue_names: Array[String]) -> void:
	_available_cues = cue_names.duplicate()
	if node_data.get("type", "") == DMConstants.TYPE_GOTO:
		_refresh_goto_options()


func _apply_setup(data: Dictionary) -> void:
	node_data = data
	name = data.id
	title = _get_title(data)
	position_offset = data.get("position", Vector2.ZERO)

	_apply_type_color(data.type)
	_configure_ports(data)
	_update_fields(data)
	_apply_node_size_policy(data.type)
	_update_error_style()


func _apply_node_size_policy(type: String) -> void:
	match type:
		DMConstants.TYPE_GOTO:
			resizable = false
		_:
			resizable = true


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


func _apply_type_color(type: String) -> void:
	var color: Color = TYPE_COLORS.get(type, Color(0.3, 0.3, 0.35))
	DMGraphNodeTheme.apply_title(self, color)
	remove_theme_stylebox_override(&"panel")


func _make_title_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


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

	match data.type:
		DMConstants.TYPE_GOTO:
			set_slot(0, true, 0, PORT_COLOR, false, 0, PORT_COLOR)
		_:
			set_slot(0, true, 0, PORT_COLOR, true, 0, PORT_COLOR)


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


func _apply_bottom_spacer_size(spacer: Control) -> void:
	spacer.custom_minimum_size = Vector2(0.0, NODE_BOTTOM_MARGIN)


func _hide_all_fields() -> void:
	for node: Node in [
		header_label, content_label, dialogue_fields, goto_fields,
		expression_edit, notes_edit, tags_edit, static_id_edit, weight_spin, blocking_check,
	]:
		if is_instance_valid(node):
			node.hide()
	if is_instance_valid(_mutation_expand_button):
		_mutation_expand_button.hide()


func _show_dialogue_fields(data: Dictionary) -> void:
	if not is_instance_valid(dialogue_fields):
		return

	dialogue_fields.show()
	if is_instance_valid(speaker_label):
		speaker_label.show()
	if is_instance_valid(text_label):
		text_label.show()

	var text: String = data.get("text", "")
	var body: String = text
	if is_instance_valid(character_edit):
		character_edit.show()
		var colon_idx: int = text.find(": ")
		if colon_idx > 0 and not text.begins_with("- ") and not text.begins_with("if ") and not text.begins_with("%"):
			character_edit.text = text.substr(0, colon_idx)
			body = text.substr(colon_idx + 2)
		else:
			character_edit.text = data.get("character", "")

	if is_instance_valid(text_edit):
		text_edit.show()
		text_edit.text = body
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	if is_instance_valid(dialogue_bottom_spacer):
		dialogue_bottom_spacer.show()
		_apply_bottom_spacer_size(dialogue_bottom_spacer)


func _show_response_fields(data: Dictionary) -> void:
	if is_instance_valid(text_edit):
		text_edit.show()
		var t: String = data.get("text", "")
		text_edit.text = t.trim_prefix("- ").strip_edges()
	if is_instance_valid(expression_edit) and data.get("condition", "") != "":
		_set_expression_field_type(DMConstants.TYPE_CONDITION)
		expression_edit.show()
		expression_edit.placeholder_text = "condition"
		_set_expression_field_value(data.get("condition", ""))


func _show_expression_fields(data: Dictionary) -> void:
	if is_instance_valid(header_label):
		header_label.show()
		match data.type:
			DMConstants.TYPE_WHILE:
				header_label.text = "While"
			DMConstants.TYPE_MATCH:
				header_label.text = "Match"
			DMConstants.TYPE_WHEN:
				header_label.text = "When"
			_:
				header_label.text = "Expression"
	if is_instance_valid(expression_edit):
		_set_expression_field_type(data.type)
		expression_edit.show()
		_set_expression_field_value(data.get("expression", data.get("text", "")))


func _show_mutation_fields(data: Dictionary) -> void:
	if is_instance_valid(header_label):
		header_label.show()
		header_label.text = "Mutation"
	if is_instance_valid(expression_edit):
		_set_expression_field_type(DMConstants.TYPE_MUTATION)
		expression_edit.show()
		var expr: String = data.get("expression", data.get("text", ""))
		_set_expression_field_value(expr)
	if is_instance_valid(blocking_check):
		blocking_check.show()
		blocking_check.button_pressed = data.get("mutation_blocking", true)
		blocking_check.text = "Blocking (await)"
	_ensure_mutation_expand_button()
	call_deferred("_update_mutation_layout")


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
	match node_data.get("type", ""):
		DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RANDOM:
			_update_dialogue_text_layout()
		DMConstants.TYPE_MUTATION:
			_update_mutation_layout()
		_:
			_resize_node_to_content()


func _resize_node_to_content() -> void:
	if is_instance_valid(dialogue_fields) and dialogue_fields.visible:
		_update_dialogue_text_layout()
		return

	match node_data.get("type", ""):
		DMConstants.TYPE_GOTO:
			var goto_width: float = COMPACT_NODE_WIDTH
			if is_instance_valid(goto_target_option):
				for i: int in range(0, goto_target_option.item_count):
					goto_width = maxf(goto_width, float(goto_target_option.get_item_text(i).length()) * 7.5 + 56.0)
			var goto_height: float = 52.0 + NODE_BOTTOM_MARGIN
			if is_instance_valid(goto_fields) and goto_fields.visible:
				goto_height = maxf(goto_height, goto_fields.get_combined_minimum_size().y + 16.0)
			custom_minimum_size = Vector2(mini(goto_width, 360.0), goto_height)
			return
		DMConstants.TYPE_MUTATION:
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

	expression_edit.custom_minimum_size = Vector2(visible_width, expression_edit.custom_minimum_size.y)

	if is_instance_valid(_mutation_expand_button):
		_mutation_expand_button.visible = needs_expand

	var height: float = 28.0
	if is_instance_valid(header_label) and header_label.visible:
		height += 24.0
	height += 34.0
	if is_instance_valid(blocking_check) and blocking_check.visible:
		height += 28.0
	if needs_expand and is_instance_valid(_mutation_expand_button):
		height += 24.0
	height += NODE_BOTTOM_MARGIN + 12.0

	custom_minimum_size = Vector2(visible_width + 24.0, height)
	_is_layout_updating = false


func _on_expand_mutation_pressed() -> void:
	if not is_instance_valid(expression_edit):
		return

	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit mutation"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(520, 200)
	_text_popup.min_size = Vector2i(360, 120)
	_text_popup.close_requested.connect(_text_popup.queue_free)

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
		_text_popup.queue_free()
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()


func _on_expand_text_pressed() -> void:
	if not is_instance_valid(text_edit):
		return

	if is_instance_valid(_text_popup):
		_text_popup.queue_free()

	_text_popup = Window.new()
	_text_popup.title = "Edit dialogue"
	_text_popup.unresizable = false
	_text_popup.size = Vector2i(520, 360)
	_text_popup.min_size = Vector2i(360, 240)
	_text_popup.close_requested.connect(_text_popup.queue_free)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_text_popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	var popup_edit: TextEdit = TextEdit.new()
	popup_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_edit.text = text_edit.text
	popup_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(popup_edit)

	var close_row: HBoxContainer = HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(func() -> void:
		text_edit.text = popup_edit.text
		_on_dialogue_text_changed()
		_text_popup.queue_free()
	)
	close_row.add_child(done_button)
	vbox.add_child(close_row)

	add_child(_text_popup)
	_text_popup.popup_centered()

	if is_instance_valid(character_edit) and character_edit.text != "":
		_text_popup.title = "%s — dialogue" % character_edit.text


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
			if is_instance_valid(expression_edit):
				node_data.expression = expression_edit.text
				node_data.text = expression_edit.text
			if is_instance_valid(blocking_check):
				node_data.mutation_blocking = blocking_check.button_pressed

		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			if is_instance_valid(expression_edit):
				node_data.expression = expression_edit.text
				node_data.text = expression_edit.text

		DMConstants.TYPE_RANDOM:
			if is_instance_valid(weight_spin):
				node_data.weight = int(weight_spin.value)

	if is_instance_valid(notes_edit):
		node_data.notes = notes_edit.text
	if is_instance_valid(static_id_edit):
		node_data.static_id = static_id_edit.text


func _on_content_changed(_arg: Variant = null) -> void:
	_sync_data_from_fields()
	if node_data.get("type", "") == DMConstants.TYPE_MUTATION:
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
