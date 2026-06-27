## Converts a DMTreeLine parse tree into a DMGraphDocument.
class_name DMGraphTreeBuilder extends RefCounted


static func build_from_text(text: String, path: String = ".") -> DMGraphDocument:
	var metadata: Dictionary = DMCompiler.build_tree_with_metadata(text, path)
	var document: DMGraphDocument = DMGraphDocument.new()
	document.imports = metadata.imports
	document.using_states = metadata.using_states

	var raw_lines: PackedStringArray = text.split("\n")
	for i: int in range(0, raw_lines.size()):
		var line: String = raw_lines[i].strip_edges()
		if line.begins_with("#region "):
			document.regions.append({ name = line.substr(8).strip_edges(), line_number = i + 1 })
		elif line.begins_with("using "):
			if not line.substr(6).strip_edges() in document.using_states:
				document.preamble_lines.append(line)

	var root: DMTreeLine = metadata.root
	_build_from_tree_line(root, "", document)

	DMGraphConnectionBuilder.build_connections(document, DMCompiler.get_compiled_lines(text, path))
	return document


static func _build_from_tree_line(tree_line: DMTreeLine, parent_id: String, document: DMGraphDocument) -> void:
	for child: DMTreeLine in tree_line.children:
		if child.type == DMConstants.TYPE_COMMENT:
			continue

		if child.type in [DMConstants.TYPE_UNKNOWN]:
			# Blank lines separate sections — keep the same parent for following lines.
			if child.text.strip_edges() == "":
				_build_from_tree_line(child, parent_id, document)
			continue

		var node: Dictionary = _make_node(child, parent_id)
		_enrich_node(node, child)
		document.add_node(node)

		var child_ids: Array[String] = []
		for grandchild: DMTreeLine in child.children:
			child_ids.append(grandchild.id)
		node.child_ids = child_ids

		_build_from_tree_line(child, child.id, document)


static func _make_node(tree_line: DMTreeLine, parent_id: String) -> Dictionary:
	return {
		id = tree_line.id,
		type = tree_line.type,
		text = tree_line.text,
		line_number = tree_line.line_number,
		indent = tree_line.indent,
		notes = tree_line.notes,
		is_random = tree_line.is_random,
		is_nested_dialogue = tree_line.is_nested_dialogue,
		parent_id = parent_id,
		child_ids = [] as Array[String],
		position = Vector2.ZERO,
		cue_name = "",
		weight = 1,
		condition = "",
		is_snippet = false,
		goto_target = "",
		expression = "",
		mutation_blocking = true,
		static_id = "",
		tags = [] as PackedStringArray,
		character = "",
		concurrent_lines = [] as PackedStringArray,
		response_options = [] as Array[Dictionary],
		branches = [] as Array[Dictionary],
		is_spacer = false,
	}


static func _enrich_node(node: Dictionary, tree_line: DMTreeLine) -> void:
	node.static_id = DMCompiler.get_static_line_id(tree_line.text)

	match node.type:
		DMConstants.TYPE_CUE:
			node.cue_name = tree_line.text.substr(2).strip_edges()

		DMConstants.TYPE_GOTO:
			var goto_text: String = tree_line.text.strip_edges()
			node.is_snippet = goto_text.begins_with("=><")
			node.goto_target = _extract_goto_target(goto_text)
			var end_target: String = node.goto_target.strip_edges().to_lower()
			if end_target in ["end", "end!"]:
				node.type = DMConstants.TYPE_END

		DMConstants.TYPE_CONDITION:
			node.expression = tree_line.text.strip_edges()
			node.branches = _extract_condition_branches(tree_line)
			node.branch_type = _infer_condition_branch_type(tree_line.text)

		DMConstants.TYPE_RESPONSE:
			var parts: Dictionary = parse_response_parts(tree_line.text, "")
			node.condition = parts.get(&"condition", "")
			node.condition_style = parts.get(&"condition_style", "slash")
			node.response_options = [{ text = tree_line.text, condition = node.condition, child_ids = node.child_ids }]

		DMConstants.TYPE_RANDOM:
			if tree_line.text.begins_with("%"):
				node.is_random = true
				node.weight = _extract_weight(tree_line.text)

		DMConstants.TYPE_DIALOGUE:
			if tree_line.text.begins_with("| "):
				node.concurrent_lines = [tree_line.text]
			elif tree_line.text.begins_with("%"):
				node.is_random = true
				node.weight = _extract_weight(tree_line.text)

		DMConstants.TYPE_MUTATION:
			var t: String = tree_line.text.strip_edges()
			node.mutation_blocking = not (t.begins_with("do! ") or t.begins_with("$>> "))
			node.expression = t

		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH:
			node.expression = tree_line.text.strip_edges()

		DMConstants.TYPE_WHEN:
			node.expression = tree_line.text.strip_edges()


static func _extract_goto_target(text: String) -> String:
	var cleaned: String = text.strip_edges()
	if cleaned.begins_with("=>< "):
		return cleaned.substr(4).strip_edges()
	elif cleaned.begins_with("=> "):
		return cleaned.substr(3).strip_edges()
	return cleaned


static func _extract_weight(text: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile("^%+(\\d*)")
	var match: RegExMatch = regex.search(text)
	if match and match.strings[1] != "":
		return match.strings[1].to_int()
	return 1


static func parse_response_parts(raw_text: String, stored_condition: String = "") -> Dictionary:
	var text: String = raw_text.trim_prefix("- ").strip_edges()
	var condition: String = ""
	var condition_style: String = "bracket"

	var wrapped: RegEx = RegEx.new()
	wrapped.compile("\\[if\\s+(.+?)\\s*/\\]")
	var found: RegExMatch = wrapped.search(text)
	if found:
		condition = found.strings[1].strip_edges()
		text = (text.substr(0, found.get_start()) + text.substr(found.get_end())).strip_edges()
		condition_style = "slash"
	else:
		var trailing: RegEx = RegEx.new()
		trailing.compile("\\s*\\[if\\s+(.+?)\\]\\s*$")
		found = trailing.search(text)
		if found:
			condition = found.strings[1].strip_edges()
			text = text.substr(0, found.get_start()).strip_edges()
			condition_style = "bracket"

	if condition == "" and stored_condition.strip_edges() != "":
		condition = normalize_condition_text(stored_condition)

	if condition != "":
		condition = normalize_condition_text(condition)

	return { &"text": text, &"condition": condition, &"condition_style": condition_style }


## Strips response condition wrappers and returns the raw expression text.
static func normalize_condition_text(raw: String) -> String:
	var text: String = raw.strip_edges()
	if text.is_empty(): return ""

	var wrapped: RegEx = RegEx.new()
	wrapped.compile("^\\[if\\s+(.+?)\\s*/\\]$")
	var found: RegExMatch = wrapped.search(text)
	if found:
		return found.strings[1].strip_edges()

	var bracketed: RegEx = RegEx.new()
	bracketed.compile("^\\[if\\s+(.+?)\\]$")
	found = bracketed.search(text)
	if found:
		return found.strings[1].strip_edges()

	var embedded: RegEx = RegEx.new()
	embedded.compile("\\[if\\s+(.+?)\\]")
	var last_match: RegExMatch = null
	for match: RegExMatch in embedded.search_all(text):
		last_match = match
	if last_match:
		return last_match.strings[1].strip_edges()

	if text.begins_with("if "):
		return text.substr(3).strip_edges()

	return text


static func format_response_line(body: String, condition: String, condition_style: String = "slash") -> String:
	var clean_body: String = body.strip_edges()
	if condition.strip_edges() == "":
		return "- %s" % clean_body
	match condition_style:
		"slash":
			return "- %s [if %s /]" % [clean_body, condition.strip_edges()]
		_:
			return "- %s [if %s]" % [clean_body, condition.strip_edges()]


static func _extract_response_condition(text: String) -> String:
	return parse_response_parts(text).get(&"condition", "")


static func _extract_condition_branches(tree_line: DMTreeLine) -> Array[Dictionary]:
	var branches: Array[Dictionary] = []
	var siblings: Array[DMTreeLine] = []
	var parent: DMTreeLine = tree_line.parent.get_ref() if tree_line.parent else null
	if parent:
		var collecting: bool = false
		for s: DMTreeLine in parent.children:
			if s.id == tree_line.id:
				collecting = true
			if collecting and s.type == DMConstants.TYPE_CONDITION:
				siblings.append(s)
			elif collecting:
				break
	for s: DMTreeLine in siblings:
		var branch_type: String = "if"
		if s.text.begins_with("elif") or s.text.begins_with("else if"):
			branch_type = "elif"
		elif s.text.begins_with("else"):
			branch_type = "else"
		var child_ids: Array[String] = []
		for c: DMTreeLine in s.children:
			child_ids.append(c.id)
		branches.append({
			id = s.id,
			type = branch_type,
			expression = s.text.strip_edges(),
			child_ids = child_ids,
		})
	return branches


static func _infer_condition_branch_type(text: String) -> String:
	var trimmed: String = text.strip_edges().to_lower()
	if trimmed == "else":
		return "else"
	if trimmed.begins_with("elif ") or trimmed.begins_with("else if "):
		return "elif"
	return "if"
