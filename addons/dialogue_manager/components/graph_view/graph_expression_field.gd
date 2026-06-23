@tool
class_name DMGraphExpressionField
extends CodeEdit
## Single line expression editor for graph condition and mutation fields.


## Emitted when the user edits the expression text.
signal text_modified()


var _pending_text: String = ""

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
	code_completion_enabled = false
	scroll_past_end_of_file = false
	text_changed.connect(_on_text_changed)
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
