## Serializes a DMGraphDocument back to .dialogue text.
class_name DMGraphTextSerializer extends RefCounted


const INDENT: String = "\t"


static func serialize(document: DMGraphDocument) -> String:
	var lines: PackedStringArray = []

	for import_line: String in document.imports:
		lines.append(import_line)

	for using_state: String in document.using_states:
		lines.append("using %s" % using_state)

	for preamble: String in document.preamble_lines:
		if not preamble.begins_with("using "):
			lines.append(preamble)

	var content_nodes: Array[Dictionary] = []
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		content_nodes.append(node)

	content_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.line_number == b.line_number:
			return str(a.id) < str(b.id)
		return a.line_number < b.line_number
	)

	if lines.size() > 0 and content_nodes.size() > 0:
		lines.append("")

	var active_region: String = ""
	var previous_line_number: int = 0

	for node: Dictionary in content_nodes:
		# Preserve blank lines between sections when line numbers jump.
		if previous_line_number > 0 and node.line_number > previous_line_number + 1:
			lines.append("")

		for region: Dictionary in document.regions:
			if region.line_number == node.line_number:
				if active_region != region.name:
					if active_region != "":
						lines.append("#endregion")
					lines.append("#region %s" % region.name)
					active_region = region.name
				break

		var indent: String = INDENT.repeat(node.get("indent", 0))

		if node.get("notes", "") != "":
			for note_line: String in node.notes.split("\n"):
				lines.append("%s## %s" % [indent, note_line])

		lines.append("%s%s" % [indent, _node_to_line_text(node)])
		previous_line_number = node.line_number

	if active_region != "":
		lines.append("#endregion")

	return "\n".join(lines).strip_edges()


static func _node_to_line_text(node: Dictionary) -> String:
	var text: String = node.get("text", "")

	if text != "":
		if node.type == DMConstants.TYPE_CUE and not text.begins_with("~ "):
			return "~ %s" % node.get("cue_name", text.strip_edges())
		return text

	match node.type:
		DMConstants.TYPE_CUE:
			return "~ %s" % node.get("cue_name", "cue")
		DMConstants.TYPE_GOTO:
			var prefix: String = "=>< " if node.get("is_snippet", false) else "=> "
			return "%s%s" % [prefix, node.get("goto_target", "")]
		DMConstants.TYPE_END:
			return "=> END"
		DMConstants.TYPE_MUTATION:
			return node.get("expression", "do something()")
		DMConstants.TYPE_RESPONSE:
			var parts: Dictionary = DMGraphTreeBuilder.parse_response_parts(text, node.get("condition", ""))
			var style: String = node.get("condition_style", parts.get("condition_style", "bracket"))
			return DMGraphTreeBuilder.format_response_line(
				parts.get("text", ""),
				parts.get("condition", ""),
				style
			)
		_:
			return text
