@tool
class_name DMGraphExpressionSyntaxHighlighter
extends DMSyntaxHighlighter
## Syntax highlighter for single line graph expression fields.


var expression_line_type: String = DMConstants.TYPE_CONDITION


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var colors: Dictionary = {}
	var text_edit: TextEdit = get_text_edit()
	if not is_instance_valid(text_edit): return colors

	var text: String = text_edit.get_line(line).strip_edges()
	if text.is_empty(): return colors

	var tokens: Array = _tokenize_expression(text)
	if tokens is Array and tokens.size() > 0:
		if tokens[0] is Dictionary and tokens[0].get("type") == DMConstants.TOKEN_ERROR:
			colors[0] = { color = _get_highlight_theme().critical_color }
		else:
			_highlight_expression(tokens, colors, 0)

	return colors


func _tokenize_expression(text: String) -> Array:
	if expression_line_type == DMConstants.TYPE_MUTATION:
		var prefix_index: int = text.find(" ")
		if prefix_index > 0:
			return expression_parser.tokenise(text.substr(prefix_index), DMConstants.TYPE_MUTATION, 0)
		return expression_parser.tokenise(text, DMConstants.TYPE_MUTATION, 0)
	return expression_parser.tokenise(text, DMConstants.TYPE_CONDITION, 0)
