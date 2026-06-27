@tool
extends PanelContainer
class_name DMGraphInspector


signal property_changed()
signal insert_requested(text: String)


const KIND_NODE: String = "node"
const KIND_RESPONSE_GROUP: String = "response_group"
const KIND_CONDITION_GROUP: String = "condition_group"
const KIND_MATCH_GROUP: String = "match_group"
const KIND_RANDOM_GROUP: String = "random_group"


@onready var type_label: Label = %TypeLabel
@onready var notes_edit: TextEdit = %NotesEdit
@onready var static_id_edit: LineEdit = %StaticIdEdit
@onready var tags_edit: LineEdit = %TagsEdit
@onready var insert_menu: MenuButton = %InsertMenu
@onready var dialogue_section: VBoxContainer = %DialogueSection
@onready var character_edit: LineEdit = %CharacterEdit
@onready var dialogue_edit: TextEdit = %DialogueEdit
@onready var response_section: VBoxContainer = %ResponseSection
@onready var response_list: VBoxContainer = %ResponseList
@onready var extra_section: VBoxContainer = %ExtraSection


var current_node_data: Dictionary = {}
var _inspection_kind: String = KIND_NODE
var _response_rows: Array[Dictionary] = []
var _condition_rows: Array[Dictionary] = []
var _match_row: Dictionary = {}
var _match_cases: Array[Dictionary] = []
var _random_rows: Array[Dictionary] = []
var _response_editors: Array[Dictionary] = []
var _condition_editors: Array[Dictionary] = []
var _match_editors: Array[Dictionary] = []
var _random_editors: Array[Dictionary] = []
var _extra_controls: Dictionary = {}
var _completion_cue_names: Array[String] = []
var _completion_autoload_names: PackedStringArray = PackedStringArray([])
var _suppress_signals: bool = false


func _ready() -> void:
	_setup_insert_menu()
	if is_instance_valid(notes_edit):
		notes_edit.text_changed.connect(_on_property_changed)
	if is_instance_valid(static_id_edit):
		static_id_edit.text_changed.connect(_on_property_changed.unbind(1))
	if is_instance_valid(tags_edit):
		tags_edit.text_changed.connect(_on_property_changed.unbind(1))
	if is_instance_valid(character_edit):
		character_edit.text_changed.connect(_on_property_changed.unbind(1))
	if is_instance_valid(dialogue_edit):
		dialogue_edit.text_changed.connect(_on_property_changed)


func set_completion_context(cue_names: Array[String], autoload_names: PackedStringArray) -> void:
	_completion_cue_names = cue_names.duplicate()
	_completion_autoload_names = autoload_names
	_apply_completion_context_to_fields()


func _apply_completion_context_to_fields() -> void:
	for field: Node in _collect_expression_fields():
		if field is DMGraphExpressionField:
			(field as DMGraphExpressionField).completion_cue_names = _completion_cue_names.duplicate()
			(field as DMGraphExpressionField).completion_autoload_names = _completion_autoload_names


func _collect_expression_fields() -> Array[Node]:
	var fields: Array[Node] = []
	if is_instance_valid(extra_section):
		fields.append_array(extra_section.find_children("*", "DMGraphExpressionField", true, false))
	for editor: Dictionary in _condition_editors:
		var expr: Node = editor.get("expression_edit")
		if is_instance_valid(expr):
			fields.append(expr)
	for editor: Dictionary in _match_editors:
		var expr: Node = editor.get("expression_edit")
		if is_instance_valid(expr):
			fields.append(expr)
	return fields


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
	_reset_inspection(KIND_NODE)
	current_node_data = node_data
	_suppress_signals = true

	if is_instance_valid(type_label):
		type_label.text = node_data.get("type", "").capitalize()
	if is_instance_valid(notes_edit):
		notes_edit.text = node_data.get("notes", "")
	if is_instance_valid(static_id_edit):
		static_id_edit.text = node_data.get("static_id", "")
	if is_instance_valid(tags_edit):
		tags_edit.text = ", ".join(node_data.get("tags", []))

	_update_type_sections(node_data)
	_suppress_signals = false
	show()


func inspect_response_group(group_data: Dictionary, rows: Array[Dictionary]) -> void:
	_reset_inspection(KIND_RESPONSE_GROUP)
	current_node_data = group_data
	_response_rows = rows.duplicate(true)
	_suppress_signals = true

	if is_instance_valid(type_label):
		type_label.text = "Responses"
	_clear_metadata_fields()
	_hide_type_sections()
	if is_instance_valid(response_section):
		response_section.show()
		_build_response_editors()

	_suppress_signals = false
	show()


func inspect_condition_group(group_data: Dictionary, branches: Array[Dictionary]) -> void:
	_reset_inspection(KIND_CONDITION_GROUP)
	current_node_data = group_data
	_condition_rows = branches.duplicate(true)
	_suppress_signals = true

	if is_instance_valid(type_label):
		type_label.text = "Condition"
	_clear_metadata_fields()
	_hide_type_sections()
	_build_condition_editors()

	_suppress_signals = false
	show()


func inspect_match_group(group_data: Dictionary, match_data: Dictionary, cases: Array[Dictionary]) -> void:
	_reset_inspection(KIND_MATCH_GROUP)
	current_node_data = group_data
	_match_row = match_data.duplicate(true)
	_match_cases = cases.duplicate(true)
	_suppress_signals = true

	if is_instance_valid(type_label):
		type_label.text = "Match"
	_clear_metadata_fields()
	_hide_type_sections()
	_build_match_editors()

	_suppress_signals = false
	show()


func inspect_random_group(group_data: Dictionary, rows: Array[Dictionary]) -> void:
	_reset_inspection(KIND_RANDOM_GROUP)
	current_node_data = group_data
	_random_rows = rows.duplicate(true)
	_suppress_signals = true

	if is_instance_valid(type_label):
		type_label.text = "Random"
	_clear_metadata_fields()
	_hide_type_sections()
	_build_random_editors()

	_suppress_signals = false
	show()


func clear_inspection() -> void:
	_reset_inspection(KIND_NODE)
	hide()


func _reset_inspection(kind: String) -> void:
	_inspection_kind = kind
	current_node_data = {}
	_response_rows = []
	_condition_rows = []
	_match_row = {}
	_match_cases = []
	_random_rows = []
	_clear_response_editors()
	_clear_condition_editors()
	_clear_match_editors()
	_clear_random_editors()
	_clear_extra_controls()
	_hide_type_sections()


func is_inspecting_response_group() -> bool:
	return _inspection_kind == KIND_RESPONSE_GROUP


func is_inspecting_condition_group() -> bool:
	return _inspection_kind == KIND_CONDITION_GROUP


func is_inspecting_match_group() -> bool:
	return _inspection_kind == KIND_MATCH_GROUP


func is_inspecting_random_group() -> bool:
	return _inspection_kind == KIND_RANDOM_GROUP


func get_updated_data() -> Dictionary:
	if current_node_data.is_empty() or _inspection_kind != KIND_NODE:
		return {}

	_apply_metadata_fields()
	var node_type: String = current_node_data.get("type", "")

	if node_type == DMConstants.TYPE_DIALOGUE:
		_apply_dialogue_fields()
	elif node_type == DMConstants.TYPE_CUE:
		_apply_cue_fields()
	elif node_type in [DMConstants.TYPE_MUTATION, DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH]:
		_apply_expression_fields(node_type)
	elif node_type == DMConstants.TYPE_GOTO:
		_apply_goto_fields()
	elif node_type == DMConstants.TYPE_RANDOM:
		_apply_random_node_fields()

	return current_node_data


func get_response_row_updates() -> Array[Dictionary]:
	return _build_response_updates(_response_rows, _response_editors)


func get_condition_branch_updates() -> Array[Dictionary]:
	if _inspection_kind != KIND_CONDITION_GROUP:
		return []

	var updates: Array[Dictionary] = _condition_rows.duplicate(true)
	for i: int in range(0, _condition_editors.size()):
		if i >= updates.size():
			break
		var editors: Dictionary = _condition_editors[i]
		var expr_edit: DMGraphExpressionField = editors.get("expression_edit") as DMGraphExpressionField
		if not is_instance_valid(expr_edit):
			continue
		var branch_type: String = DMGraphConditionGroupNode.infer_branch_type(updates[i], i)
		var expression: String = expr_edit.text.strip_edges()
		updates[i].branch_type = branch_type
		updates[i].expression = expression
		updates[i].text = DMGraphConditionGroupNode.format_branch_text(branch_type, expression)
	return updates


func get_match_group_updates() -> Dictionary:
	if _inspection_kind != KIND_MATCH_GROUP:
		return {}

	var match_data: Dictionary = _match_row.duplicate(true)
	var cases: Array[Dictionary] = _match_cases.duplicate(true)

	if _match_editors.size() > 0:
		var match_expr: DMGraphExpressionField = _match_editors[0].get("expression_edit") as DMGraphExpressionField
		if is_instance_valid(match_expr):
			var expression: String = match_expr.text.strip_edges()
			match_data.expression = "match %s" % expression
			match_data.text = match_data.expression

	for i: int in range(0, _match_editors.size() - 1):
		if i >= cases.size():
			break
		var editors: Dictionary = _match_editors[i + 1]
		var case_type: String = DMGraphMatchGroupNode.infer_case_type(cases[i])
		if case_type == "else":
			cases[i].branch_type = "else"
			cases[i].text = "else"
			cases[i].expression = ""
			cases[i].type = DMConstants.TYPE_CONDITION
			continue
		var expr_edit: DMGraphExpressionField = editors.get("expression_edit") as DMGraphExpressionField
		if not is_instance_valid(expr_edit):
			continue
		var expression: String = expr_edit.text.strip_edges()
		cases[i].branch_type = "when"
		cases[i].type = DMConstants.TYPE_WHEN
		cases[i].expression = expression
		cases[i].text = DMGraphMatchGroupNode.format_case_text("when", expression)

	return {
		match = match_data,
		cases = cases,
	}


func get_random_row_updates() -> Array[Dictionary]:
	if _inspection_kind != KIND_RANDOM_GROUP:
		return []

	var updates: Array[Dictionary] = _random_rows.duplicate(true)
	for i: int in range(0, _random_editors.size()):
		if i >= updates.size():
			break
		var editors: Dictionary = _random_editors[i]
		var text_edit: TextEdit = editors.get("text_edit") as TextEdit
		var weight_spin: SpinBox = editors.get("weight_spin") as SpinBox
		if not is_instance_valid(text_edit):
			continue
		var body: String = text_edit.text.strip_edges()
		var weight: int = int(weight_spin.value) if is_instance_valid(weight_spin) else 1
		updates[i].weight = weight
		updates[i].is_random = true
		if body == "":
			updates[i].text = "%"
		elif weight <= 1:
			updates[i].text = "%% %s" % body
		else:
			updates[i].text = "%%%d %s" % [weight, body]
	return updates


func _apply_metadata_fields() -> void:
	if is_instance_valid(notes_edit):
		current_node_data.notes = notes_edit.text
	if is_instance_valid(static_id_edit):
		current_node_data.static_id = static_id_edit.text
	if is_instance_valid(tags_edit):
		if tags_edit.text == "":
			current_node_data.tags = PackedStringArray([])
		else:
			var tags: PackedStringArray = PackedStringArray([])
			for part: String in tags_edit.text.split(","):
				tags.append(part.strip_edges())
			current_node_data.tags = tags


func _apply_dialogue_fields() -> void:
	if not is_instance_valid(dialogue_edit):
		return
	var char_name: String = character_edit.text if is_instance_valid(character_edit) else ""
	var body: String = dialogue_edit.text
	if char_name != "":
		current_node_data.text = "%s: %s" % [char_name, body]
		current_node_data.character = char_name
	else:
		current_node_data.text = body
		current_node_data.erase("character")

	var concurrent_edit: TextEdit = _extra_controls.get("concurrent_edit") as TextEdit
	if is_instance_valid(concurrent_edit):
		var lines: PackedStringArray = PackedStringArray([])
		for line: String in concurrent_edit.text.split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed == "":
				continue
			if not trimmed.begins_with("|"):
				trimmed = "| %s" % trimmed
			lines.append(trimmed)
		current_node_data.concurrent_lines = lines


func _apply_cue_fields() -> void:
	var cue_edit: LineEdit = _extra_controls.get("cue_name_edit") as LineEdit
	if not is_instance_valid(cue_edit):
		return
	var cue_name: String = cue_edit.text.strip_edges()
	current_node_data.cue_name = cue_name
	current_node_data.text = "~ %s" % cue_name


func _apply_expression_fields(node_type: String) -> void:
	var expr_edit: DMGraphExpressionField = _extra_controls.get("expression_edit") as DMGraphExpressionField
	if not is_instance_valid(expr_edit):
		return
	var expression: String = expr_edit.text.strip_edges()
	current_node_data.expression = expression
	current_node_data.text = expression
	if node_type == DMConstants.TYPE_MUTATION:
		var blocking_check: CheckBox = _extra_controls.get("blocking_check") as CheckBox
		if is_instance_valid(blocking_check):
			current_node_data.mutation_blocking = blocking_check.button_pressed


func _apply_goto_fields() -> void:
	var target_edit: LineEdit = _extra_controls.get("goto_target_edit") as LineEdit
	var snippet_check: CheckBox = _extra_controls.get("snippet_check") as CheckBox
	if is_instance_valid(target_edit):
		var target: String = target_edit.text.strip_edges()
		current_node_data.goto_target = target
		var is_snippet: bool = snippet_check.button_pressed if is_instance_valid(snippet_check) else false
		current_node_data.is_snippet = is_snippet
		current_node_data.text = ("=>< %s" if is_snippet else "=> %s") % target


func _apply_random_node_fields() -> void:
	var text_edit: TextEdit = _extra_controls.get("random_text_edit") as TextEdit
	var weight_spin: SpinBox = _extra_controls.get("random_weight_spin") as SpinBox
	if not is_instance_valid(text_edit):
		return
	var body: String = text_edit.text.strip_edges()
	var weight: int = int(weight_spin.value) if is_instance_valid(weight_spin) else 1
	current_node_data.weight = weight
	current_node_data.is_random = true
	if body == "":
		current_node_data.text = "%"
	elif weight <= 1:
		current_node_data.text = "%% %s" % body
	else:
		current_node_data.text = "%%%d %s" % [weight, body]


func _build_response_updates(rows: Array[Dictionary], editors_list: Array[Dictionary]) -> Array[Dictionary]:
	if _inspection_kind != KIND_RESPONSE_GROUP:
		return []

	var updates: Array[Dictionary] = rows.duplicate(true)
	for i: int in range(0, editors_list.size()):
		if i >= updates.size():
			break
		var editors: Dictionary = editors_list[i]
		var text_edit: TextEdit = editors.get("text_edit") as TextEdit
		var condition_edit: LineEdit = editors.get("condition_edit") as LineEdit
		if not is_instance_valid(text_edit):
			continue

		var body: String = text_edit.text.strip_edges()
		var condition: String = ""
		if is_instance_valid(condition_edit):
			condition = DMGraphTreeBuilder.normalize_condition_text(condition_edit.text)

		var row: Dictionary = updates[i]
		row.condition = condition
		if condition != "":
			row.condition_style = "slash"
			row.text = DMGraphTreeBuilder.format_response_line(body, condition, "slash")
		else:
			row.text = "- %s" % body
	return updates


func _update_type_sections(node_data: Dictionary) -> void:
	_hide_type_sections()
	_clear_extra_controls()
	var node_type: String = node_data.get("type", "")

	if node_type == DMConstants.TYPE_DIALOGUE and is_instance_valid(dialogue_section):
		dialogue_section.show()
		var text: String = node_data.get("text", "")
		var body: String = text
		var character: String = node_data.get("character", "")
		var colon_idx: int = text.find(": ")
		if colon_idx > 0 and not text.begins_with("- ") and not text.begins_with("if ") and not text.begins_with("%"):
			character = text.substr(0, colon_idx)
			body = text.substr(colon_idx + 2)
		if is_instance_valid(character_edit):
			character_edit.text = character
		if is_instance_valid(dialogue_edit):
			dialogue_edit.text = body
		_build_concurrent_editor(node_data)

	elif node_type == DMConstants.TYPE_CUE:
		_build_cue_editor(node_data)
	elif node_type == DMConstants.TYPE_MUTATION:
		_build_mutation_editor(node_data)
	elif node_type in [DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH]:
		_build_expression_editor(node_data, node_type)
	elif node_type == DMConstants.TYPE_GOTO:
		_build_goto_editor(node_data)
	elif node_type == DMConstants.TYPE_RANDOM:
		_build_random_node_editor(node_data)

	if is_instance_valid(insert_menu):
		insert_menu.visible = node_type in [DMConstants.TYPE_DIALOGUE, DMConstants.TYPE_RANDOM]


func _build_concurrent_editor(node_data: Dictionary) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var label: Label = Label.new()
	label.text = "Concurrent lines (| Char: text)"
	DMGraphNodeTheme.apply_muted_label(label)
	extra_section.add_child(label)

	var concurrent_edit: TextEdit = TextEdit.new()
	concurrent_edit.custom_minimum_size = Vector2(0, 56)
	concurrent_edit.placeholder_text = "| Character: concurrent line"
	var lines: PackedStringArray = node_data.get("concurrent_lines", PackedStringArray([]))
	var line_text: String = ""
	for line: String in lines:
		line_text += line.trim_prefix("|").strip_edges() + "\n"
	concurrent_edit.text = line_text.strip_edges()
	concurrent_edit.text_changed.connect(_on_property_changed)
	DMGraphNodeTheme.apply_field_background(concurrent_edit)
	extra_section.add_child(concurrent_edit)
	_extra_controls["concurrent_edit"] = concurrent_edit


func _build_cue_editor(node_data: Dictionary) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var cue_edit: LineEdit = LineEdit.new()
	cue_edit.placeholder_text = "Cue name"
	cue_edit.text = node_data.get("cue_name", "")
	cue_edit.text_changed.connect(_on_property_changed.unbind(1))
	DMGraphNodeTheme.apply_field_background(cue_edit)
	extra_section.add_child(cue_edit)
	_extra_controls["cue_name_edit"] = cue_edit


func _build_mutation_editor(node_data: Dictionary) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var expr_edit: DMGraphExpressionField = _make_expression_field(
		node_data.get("expression", node_data.get("text", "")),
		DMConstants.TYPE_MUTATION
	)
	extra_section.add_child(expr_edit)
	_extra_controls["expression_edit"] = expr_edit

	var blocking_check: CheckBox = CheckBox.new()
	blocking_check.text = "Blocking (do / set)"
	blocking_check.button_pressed = node_data.get("mutation_blocking", true)
	blocking_check.toggled.connect(_on_property_changed.unbind(1))
	extra_section.add_child(blocking_check)
	_extra_controls["blocking_check"] = blocking_check


func _build_expression_editor(node_data: Dictionary, node_type: String) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var expression: String = node_data.get("expression", node_data.get("text", ""))
	if node_type == DMConstants.TYPE_MATCH and expression.begins_with("match "):
		expression = expression.substr(6).strip_edges()
	var expr_edit: DMGraphExpressionField = _make_expression_field(expression, node_type)
	extra_section.add_child(expr_edit)
	_extra_controls["expression_edit"] = expr_edit


func _build_goto_editor(node_data: Dictionary) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var target_edit: LineEdit = LineEdit.new()
	target_edit.placeholder_text = "Target cue"
	target_edit.text = node_data.get("goto_target", "")
	target_edit.text_changed.connect(_on_property_changed.unbind(1))
	DMGraphNodeTheme.apply_field_background(target_edit)
	extra_section.add_child(target_edit)
	_extra_controls["goto_target_edit"] = target_edit

	var snippet_check: CheckBox = CheckBox.new()
	snippet_check.text = "Snippet (=><)"
	snippet_check.button_pressed = node_data.get("is_snippet", false)
	snippet_check.toggled.connect(_on_property_changed.unbind(1))
	extra_section.add_child(snippet_check)
	_extra_controls["snippet_check"] = snippet_check


func _build_random_node_editor(node_data: Dictionary) -> void:
	if not is_instance_valid(extra_section):
		return
	extra_section.show()
	var text: String = node_data.get("text", "")
	var weight: int = node_data.get("weight", 1)
	var body: String = text.strip_edges()
	if body.begins_with("%"):
		var parts: PackedStringArray = body.split(" ", false, 1)
		var weight_token: String = parts[0].substr(1)
		if weight_token.is_valid_int():
			weight = int(weight_token)
			body = parts[1] if parts.size() > 1 else ""
		else:
			body = body.substr(1).strip_edges()

	var weight_spin: SpinBox = SpinBox.new()
	weight_spin.min_value = 1
	weight_spin.max_value = 100
	weight_spin.value = weight
	weight_spin.value_changed.connect(_on_property_changed.unbind(1))
	extra_section.add_child(weight_spin)
	_extra_controls["random_weight_spin"] = weight_spin

	var text_edit: TextEdit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 48)
	text_edit.text = body
	text_edit.text_changed.connect(_on_property_changed)
	DMGraphNodeTheme.apply_field_background(text_edit)
	extra_section.add_child(text_edit)
	_extra_controls["random_text_edit"] = text_edit


func _make_expression_field(expression: String, line_type: String) -> DMGraphExpressionField:
	var expr_edit: DMGraphExpressionField = DMGraphExpressionField.new()
	expr_edit.custom_minimum_size = Vector2(0, 28)
	expr_edit.set_line_type(line_type)
	expr_edit.set_text_silent(expression)
	expr_edit.completion_cue_names = _completion_cue_names.duplicate()
	expr_edit.completion_autoload_names = _completion_autoload_names
	expr_edit.text_modified.connect(_on_property_changed)
	return expr_edit


func _build_condition_editors() -> void:
	_clear_condition_editors()
	if not is_instance_valid(extra_section):
		return
	extra_section.show()

	for i: int in range(0, _condition_rows.size()):
		var row_data: Dictionary = _condition_rows[i]
		var branch_type: String = DMGraphConditionGroupNode.infer_branch_type(row_data, i)
		var row_box: VBoxContainer = VBoxContainer.new()
		var header: Label = Label.new()
		header.text = branch_type.capitalize()
		DMGraphNodeTheme.apply_muted_label(header)
		row_box.add_child(header)

		var expression: String = DMGraphConditionGroupNode.extract_expression(row_data, branch_type)
		var expr_edit: DMGraphExpressionField = _make_expression_field(expression, DMConstants.TYPE_CONDITION)
		if branch_type == "else":
			expr_edit.editable = false
			expr_edit.text = ""
		row_box.add_child(expr_edit)
		extra_section.add_child(row_box)
		_condition_editors.append({ "expression_edit": expr_edit })


func _build_match_editors() -> void:
	_clear_match_editors()
	if not is_instance_valid(extra_section):
		return
	extra_section.show()

	var match_box: VBoxContainer = VBoxContainer.new()
	var match_header: Label = Label.new()
	match_header.text = "Match expression"
	DMGraphNodeTheme.apply_muted_label(match_header)
	match_box.add_child(match_header)
	var match_expression: String = _match_row.get("expression", _match_row.get("text", ""))
	if match_expression.begins_with("match "):
		match_expression = match_expression.substr(6).strip_edges()
	var match_expr_edit: DMGraphExpressionField = _make_expression_field(match_expression, DMConstants.TYPE_MATCH)
	match_box.add_child(match_expr_edit)
	extra_section.add_child(match_box)
	_match_editors.append({ "expression_edit": match_expr_edit })

	for i: int in range(0, _match_cases.size()):
		var case_data: Dictionary = _match_cases[i]
		var case_type: String = DMGraphMatchGroupNode.infer_case_type(case_data)
		var case_box: VBoxContainer = VBoxContainer.new()
		var header: Label = Label.new()
		header.text = case_type.capitalize()
		DMGraphNodeTheme.apply_muted_label(header)
		case_box.add_child(header)
		var expression: String = DMGraphMatchGroupNode.extract_case_expression(case_data, case_type)
		var expr_edit: DMGraphExpressionField = _make_expression_field(expression, DMConstants.TYPE_WHEN)
		if case_type == "else":
			expr_edit.editable = false
			expr_edit.text = ""
		case_box.add_child(expr_edit)
		extra_section.add_child(case_box)
		_match_editors.append({ "expression_edit": expr_edit })


func _build_random_editors() -> void:
	_clear_random_editors()
	if not is_instance_valid(extra_section):
		return
	extra_section.show()

	for i: int in range(0, _random_rows.size()):
		var row_data: Dictionary = _random_rows[i]
		var row_box: VBoxContainer = VBoxContainer.new()
		var header: Label = Label.new()
		header.text = "Random line %d" % (i + 1)
		DMGraphNodeTheme.apply_muted_label(header)
		row_box.add_child(header)

		var text: String = row_data.get("text", "")
		var weight: int = row_data.get("weight", 1)
		var body: String = text.strip_edges()
		if body.begins_with("%"):
			var parts: PackedStringArray = body.split(" ", false, 1)
			var weight_token: String = parts[0].substr(1)
			if weight_token.is_valid_int():
				weight = int(weight_token)
				body = parts[1] if parts.size() > 1 else ""
			else:
				body = body.substr(1).strip_edges()

		var weight_spin: SpinBox = SpinBox.new()
		weight_spin.min_value = 1
		weight_spin.max_value = 100
		weight_spin.value = weight
		weight_spin.value_changed.connect(_on_property_changed.unbind(1))
		row_box.add_child(weight_spin)

		var text_edit: TextEdit = TextEdit.new()
		text_edit.custom_minimum_size = Vector2(0, 40)
		text_edit.text = body
		text_edit.text_changed.connect(_on_property_changed)
		DMGraphNodeTheme.apply_field_background(text_edit)
		row_box.add_child(text_edit)

		extra_section.add_child(row_box)
		_random_editors.append({
			"text_edit": text_edit,
			"weight_spin": weight_spin,
		})


func _hide_type_sections() -> void:
	if is_instance_valid(dialogue_section):
		dialogue_section.hide()
	if is_instance_valid(response_section):
		response_section.hide()
	if is_instance_valid(extra_section):
		extra_section.hide()
	if is_instance_valid(insert_menu):
		insert_menu.visible = false


func _clear_metadata_fields() -> void:
	if is_instance_valid(notes_edit):
		notes_edit.text = ""
	if is_instance_valid(static_id_edit):
		static_id_edit.text = ""
	if is_instance_valid(tags_edit):
		tags_edit.text = ""


func _clear_extra_controls() -> void:
	_extra_controls.clear()
	if not is_instance_valid(extra_section):
		return
	for child: Node in extra_section.get_children():
		child.queue_free()


func _clear_response_editors() -> void:
	_response_editors.clear()
	if not is_instance_valid(response_list):
		return
	for child: Node in response_list.get_children():
		child.queue_free()


func _clear_condition_editors() -> void:
	_condition_editors.clear()


func _clear_match_editors() -> void:
	_match_editors.clear()


func _clear_random_editors() -> void:
	_random_editors.clear()


func _build_response_editors() -> void:
	_clear_response_editors()
	if not is_instance_valid(response_list):
		return

	for i: int in range(0, _response_rows.size()):
		var row_data: Dictionary = _response_rows[i]
		var parsed: Dictionary = DMGraphTreeBuilder.parse_response_parts(
			row_data.get("text", ""),
			row_data.get("condition", "")
		)

		var row_box: VBoxContainer = VBoxContainer.new()
		row_box.add_theme_constant_override(&"separation", 2)

		var header: Label = Label.new()
		header.text = "Response %d" % (i + 1)
		DMGraphNodeTheme.apply_muted_label(header)
		row_box.add_child(header)

		var text_edit: TextEdit = TextEdit.new()
		text_edit.custom_minimum_size = Vector2(0, 48)
		text_edit.text = parsed.get("text", "")
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text_edit.text_changed.connect(_on_property_changed)
		DMGraphNodeTheme.apply_field_background(text_edit)
		row_box.add_child(text_edit)

		var condition_edit: LineEdit = LineEdit.new()
		condition_edit.placeholder_text = "Visibility [if expr /]"
		condition_edit.text = DMGraphTreeBuilder.normalize_condition_text(parsed.get("condition", ""))
		condition_edit.text_changed.connect(_on_property_changed.unbind(1))
		DMGraphNodeTheme.apply_field_background(condition_edit)
		row_box.add_child(condition_edit)

		response_list.add_child(row_box)
		_response_editors.append({
			"text_edit": text_edit,
			"condition_edit": condition_edit,
		})


func _on_property_changed(_arg: Variant = null) -> void:
	if _suppress_signals:
		return
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
