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
	var connected_ids: Dictionary = _get_connected_node_ids(document)
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		if not connected_ids.has(id):
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

		if node.type == DMConstants.TYPE_DIALOGUE:
			for concurrent_line: String in node.get("concurrent_lines", PackedStringArray([])):
				var concurrent_text: String = concurrent_line.strip_edges()
				if concurrent_text != "":
					if not concurrent_text.begins_with("|"):
						concurrent_text = "| %s" % concurrent_text
					lines.append("%s%s" % [indent, concurrent_text])

		previous_line_number = node.line_number

	if active_region != "":
		lines.append("#endregion")

	return "\n".join(lines).strip_edges()


static func _get_connected_node_ids(document: DMGraphDocument) -> Dictionary:
	var connected: Dictionary = {}
	for conn: Dictionary in document.connections:
		connected[conn.get("from_node", "")] = true
		connected[conn.get("to_node", "")] = true
	return connected


static func _node_to_line_text(node: Dictionary) -> String:
	var line: String = _build_base_line_text(node)
	line = _append_inline_metadata(node, line)
	return line


static func _build_base_line_text(node: Dictionary) -> String:
	var text: String = node.get("text", "")

	match node.type:
		DMConstants.TYPE_CUE:
			if text.begins_with("~ "):
				return text
			return "~ %s" % node.get("cue_name", text.strip_edges())
		DMConstants.TYPE_GOTO:
			var prefix: String = "=>< " if node.get("is_snippet", false) else "=> "
			var target: String = node.get("goto_target", "")
			if target == "" and text != "":
				return text
			return "%s%s" % [prefix, target]
		DMConstants.TYPE_END:
			return "=> END"
		DMConstants.TYPE_MUTATION:
			return _format_mutation_line(node)
		DMConstants.TYPE_RESPONSE:
			var parts: Dictionary = DMGraphTreeBuilder.parse_response_parts(text, node.get("condition", ""))
			var style: String = node.get("condition_style", parts.get("condition_style", "slash"))
			return DMGraphTreeBuilder.format_response_line(
				parts.get("text", ""),
				parts.get("condition", ""),
				style
			)
		_:
			if text != "":
				return text
			if node.type == DMConstants.TYPE_WHILE:
				return node.get("expression", "while true")
			if node.type == DMConstants.TYPE_MATCH:
				return node.get("expression", "match value")
			if node.type == DMConstants.TYPE_WHEN:
				return node.get("expression", "when value")
			return text


static func _format_mutation_line(node: Dictionary) -> String:
	var expr: String = node.get("expression", node.get("text", "do something()")).strip_edges()
	if expr == "":
		return "do something()"

	var blocking: bool = node.get("mutation_blocking", true)
	if expr.begins_with("do ") or expr.begins_with("do! "):
		return ("do " if blocking else "do! ") + expr.trim_prefix("do! ").trim_prefix("do ").strip_edges()
	if expr.begins_with("set "):
		return expr
	if expr.begins_with("$> ") or expr.begins_with("$>> "):
		return ("$> " if blocking else "$>> ") + expr.trim_prefix("$>> ").trim_prefix("$> ").strip_edges()

	if not blocking:
		if expr.begins_with("do!") or expr.begins_with("$>>"):
			return expr
		return "do! %s" % expr
	return expr if expr.begins_with("do ") or expr.begins_with("set ") or expr.begins_with("$>") else "do %s" % expr


static func _append_inline_metadata(node: Dictionary, line: String) -> String:
	var result: String = line

	var static_id: String = node.get("static_id", "").strip_edges()
	if static_id != "" and not ("[ID:%s]" % static_id) in result:
		result += " [ID:%s]" % static_id

	var tag_parts: PackedStringArray = PackedStringArray()
	var raw_tags: Variant = node.get("tags", PackedStringArray())
	if raw_tags is Array:
		for tag: Variant in raw_tags:
			var tag_text: String = str(tag).strip_edges()
			if tag_text != "":
				tag_parts.append(tag_text)
		if tag_parts.size() > 0 and "[#" not in result:
			result += " [#%s]" % ", ".join(tag_parts)

	return result
