@tool
class_name DMGraphExpressionField
extends CodeEdit
## Single line expression editor for graph condition and mutation fields.


## Emitted when the user edits the expression text.
signal text_modified()


var _pending_text: String = ""
var completion_cue_names: Array[String] = []
var completion_autoload_names: PackedStringArray = PackedStringArray([])


var expression_line_type: String = DMConstants.TYPE_CONDITION:
	set(value):
		expression_line_type = value
		_apply_line_type_to_highlighter()

var theme_overrides: DMThemeValues:
	set(value):
		theme_overrides = value
		if is_node_ready():
			_apply_editor_theme()
	get:
		if not theme_overrides:
			theme_overrides = DMThemeValues.get_safe_editor_theme()
		return theme_overrides


func _ready() -> void:
	if not syntax_highlighter:
		syntax_highlighter = DMGraphExpressionSyntaxHighlighter.new()
	_apply_line_type_to_highlighter()
	wrap_mode = LINE_WRAPPING_NONE
	minimap_draw = false
	highlight_current_line = false
	gutters_draw_line_numbers = false
	gutters_draw_fold_gutter = false
	indent_automatic = false
	auto_brace_completion_enabled = false
	line_folding = false
	code_completion_enabled = true
	scroll_past_end_of_file = false
	text_changed.connect(_on_text_changed)
	code_completion_requested.connect(_on_code_completion_requested)
	call_deferred("_apply_editor_theme")
	DMGraphNodeTheme.apply_field_background(self)
	if _pending_text != "":
		var pending: String = _pending_text
		_pending_text = ""
		call_deferred("_apply_text_silent", pending)


func set_line_type(type: String) -> void:
	expression_line_type = type


func _apply_line_type_to_highlighter() -> void:
	if syntax_highlighter is DMGraphExpressionSyntaxHighlighter:
		(syntax_highlighter as DMGraphExpressionSyntaxHighlighter).expression_line_type = expression_line_type
		(syntax_highlighter as DMGraphExpressionSyntaxHighlighter)._clear_highlighting_cache()


func _apply_editor_theme() -> void:
	var theme: DMThemeValues = theme_overrides
	add_theme_color_override(&"font_color", theme.text_color)
	add_theme_font_size_override(&"font_size", theme.font_size)
	add_theme_color_override(&"caret_color", theme.text_color)
	add_theme_color_override(&"selection_color", Color(theme.text_color, 0.25))
	queue_redraw()


func set_text_silent(value: String) -> void:
	if not is_node_ready():
		_pending_text = value
		return
	_apply_text_silent(value)


func _apply_text_silent(value: String) -> void:
	if text_changed.is_connected(_on_text_changed):
		text_changed.disconnect(_on_text_changed)
	text = value
	if not text_changed.is_connected(_on_text_changed):
		text_changed.connect(_on_text_changed)


func _on_text_changed() -> void:
	text_modified.emit()


func _on_code_completion_requested(_force: bool) -> void:
	var line: String = get_line(0)
	var column: int = get_caret_column()
	var prompt: String = _get_word_before_caret(line, column)
	var theme: DMThemeValues = theme_overrides
	var icon: Texture2D = null
	if has_theme_icon(&"ArrowRight", &"EditorIcons"):
		icon = get_theme_icon(&"ArrowRight", &"EditorIcons")

	for cue: String in completion_cue_names:
		if _matches_prompt(prompt, cue):
			add_code_completion_option(
				KIND_CLASS,
				cue,
				cue.substr(prompt.length()),
				theme.text_color,
				icon
			)

	for autoload_name: String in completion_autoload_names:
		if _matches_prompt(prompt, autoload_name):
			add_code_completion_option(
				KIND_CLASS,
				autoload_name,
				autoload_name.substr(prompt.length()),
				theme.text_color,
				get_theme_icon(&"Node", &"EditorIcons") if has_theme_icon(&"Node", &"EditorIcons") else null
			)

	for keyword: String in ["true", "false", "and", "or", "not", "locals"]:
		if _matches_prompt(prompt, keyword):
			add_code_completion_option(
				KIND_CONSTANT,
				keyword,
				keyword.substr(prompt.length()),
				Color.WHITE,
				null
			)

	update_code_completion_options(true)
	if get_code_completion_options().size() == 0:
		cancel_code_completion()


func _get_word_before_caret(line: String, column: int) -> String:
	var start: int = column
	while start > 0 and line.substr(start - 1, 1).is_valid_identifier():
		start -= 1
	return line.substr(start, column - start)


func _matches_prompt(prompt: String, candidate: String) -> bool:
	return candidate.to_lower().begins_with(prompt.to_lower()) and candidate != prompt
