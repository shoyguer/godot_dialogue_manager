## Builds visual graph connections from compiled dialogue flow.
class_name DMGraphConnectionBuilder extends RefCounted


static func build_connections(document: DMGraphDocument, compiled_lines: Dictionary = {}) -> void:
	document.connections.clear()

	if compiled_lines.is_empty():
		_build_from_tree_structure(document)
		return

	var skip_sequence_from: Dictionary = {}

	for id: String in compiled_lines:
		if not document.has_node(id):
			continue

		var line: DMCompiledLine = compiled_lines[id]

		if line.responses.size() > 0:
			_connect_response_group(document, compiled_lines, line, skip_sequence_from)
			continue

		if line.siblings.size() > 0 and line.type in [
			DMConstants.TYPE_RANDOM,
			DMConstants.TYPE_DIALOGUE,
			DMConstants.TYPE_GOTO,
		]:
			if _find_predecessor(compiled_lines, id) != "":
				_connect_random_group(document, compiled_lines, line, skip_sequence_from)

	for id: String in compiled_lines:
		if not document.has_node(id):
			continue

		var line: DMCompiledLine = compiled_lines[id]

		if line.type == DMConstants.TYPE_MATCH:
			for sibling: Dictionary in line.siblings:
				if sibling.has("next_id"):
					_connect_flow(document, id, sibling.next_id, "branch")
			continue

		if line.type == DMConstants.TYPE_CONDITION:
			_connect_flow(document, id, line.next_id, "body")
			if line.next_sibling_id != "":
				_connect_flow(document, id, line.next_sibling_id, "branch")
			continue

		if line.type == DMConstants.TYPE_WHILE:
			_connect_flow(document, id, line.next_id, "body")
			continue

		if line.type == DMConstants.TYPE_GOTO:
			_connect_goto(document, line)
			continue

		if line.type == DMConstants.TYPE_RESPONSE and _is_secondary_response(line, compiled_lines):
			continue

		if skip_sequence_from.has(id):
			continue

		if line.concurrent_lines.size() > 0:
			for concurrent_id: String in line.concurrent_lines:
				_connect_flow(document, id, concurrent_id, "sequence")

		_connect_flow(document, id, line.next_id, "sequence")


static func _connect_response_group(
	document: DMGraphDocument,
	compiled_lines: Dictionary,
	anchor: DMCompiledLine,
	skip_sequence_from: Dictionary
) -> void:
	var predecessor_id: String = _find_predecessor(compiled_lines, anchor.id)

	for resp_id: String in anchor.responses:
		if not document.has_node(resp_id):
			continue

		if predecessor_id != "" and document.has_node(predecessor_id):
			_connect_flow(document, predecessor_id, resp_id, "branch")
		else:
			var cue_id: String = _find_owning_cue_id(document, anchor.id)
			if cue_id != "":
				_connect_flow(document, cue_id, resp_id, "branch")

		var resp_line: DMCompiledLine = compiled_lines.get(resp_id)
		if resp_line != null:
			_connect_flow(document, resp_id, resp_line.next_id, "body")

	if predecessor_id != "" and document.has_node(predecessor_id):
		skip_sequence_from[predecessor_id] = true


static func _find_owning_cue_id(document: DMGraphDocument, node_id: String) -> String:
	var node: Dictionary = document.get_node(node_id)
	if node.is_empty():
		return ""

	var line_number: int = node.get("line_number", 0)
	var best_cue_id: String = ""
	var best_cue_line: int = -1

	for cue_name: String in document.cue_map:
		var cue_id: String = document.cue_map[cue_name]
		var cue_node: Dictionary = document.get_node(cue_id)
		var cue_line: int = cue_node.get("line_number", 0)
		var line_range: Vector2i = DMGraphCueFilter.get_cue_line_range(document, cue_name)
		if line_number >= line_range.x and line_number < line_range.y and cue_line > best_cue_line:
			best_cue_line = cue_line
			best_cue_id = cue_id

	return best_cue_id


static func _connect_random_group(
	document: DMGraphDocument,
	compiled_lines: Dictionary,
	anchor: DMCompiledLine,
	skip_sequence_from: Dictionary
) -> void:
	var option_ids: Array[String] = [anchor.id]
	for sibling: Dictionary in anchor.siblings:
		if sibling.has("id") and document.has_node(sibling.id):
			option_ids.append(sibling.id)

	var predecessor_id: String = _find_predecessor(compiled_lines, anchor.id)
	if predecessor_id == "":
		return

	for option_id: String in option_ids:
		_connect_flow(document, predecessor_id, option_id, "branch")

	skip_sequence_from[predecessor_id] = true


static func _connect_flow(document: DMGraphDocument, from_id: String, to_id: String, kind: String) -> void:
	if from_id == "" or to_id == "":
		return
	if to_id in [DMConstants.ID_NULL, DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]:
		return
	if not document.has_node(from_id) or not document.has_node(to_id):
		return
	document.add_connection(from_id, kind, to_id, "input", kind)


static func _connect_goto(document: DMGraphDocument, line: DMCompiledLine) -> void:
	var target: String = line.next_id
	if target in [DMConstants.ID_NULL, DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]:
		return

	target = _resolve_goto_target(document, target)
	if target == "" or not document.has_node(target):
		return

	document.add_connection(line.id, "goto", target, "input", "goto")


static func _resolve_goto_target(document: DMGraphDocument, target_id: String) -> String:
	for cue_name: String in document.cue_map:
		var cue_id: String = document.cue_map[cue_name]
		var entry_id: String = DMGraphCueFilter.get_cue_entry_node_id(document, cue_name)
		if target_id == entry_id and cue_id != entry_id:
			return cue_id

	if document.has_node(target_id):
		return target_id

	for cue_name: String in document.cue_map:
		if document.cue_map[cue_name] == target_id or cue_name == target_id:
			var cue_id: String = document.cue_map[cue_name]
			if document.has_node(cue_id):
				return cue_id

	return ""


static func _find_predecessor(compiled_lines: Dictionary, target_id: String) -> String:
	for id: String in compiled_lines:
		var line: DMCompiledLine = compiled_lines[id]
		if line.next_id == target_id:
			return id
	return ""


static func _is_secondary_response(line: DMCompiledLine, compiled_lines: Dictionary) -> bool:
	if line.type != DMConstants.TYPE_RESPONSE:
		return false
	if line.responses.size() > 0:
		return false

	for id: String in compiled_lines:
		var anchor: DMCompiledLine = compiled_lines[id]
		if anchor.responses.size() > 0 and line.id in anchor.responses and line.id != id:
			return true

	return false


## Fallback when compiled lines are unavailable.
static func _build_from_tree_structure(document: DMGraphDocument) -> void:
	var children_by_parent: Dictionary = _group_children_by_parent(document)

	for parent_id: String in children_by_parent:
		var siblings: Array = children_by_parent[parent_id]
		var response_run: Array[Dictionary] = []

		for i: int in range(0, siblings.size()):
			var node: Dictionary = siblings[i]

			if node.type == DMConstants.TYPE_RESPONSE:
				response_run.append(node)
				continue

			if response_run.size() > 0:
				_flush_response_run(document, response_run, node)
				response_run.clear()

			if i > 0:
				var previous: Dictionary = siblings[i - 1]
				if previous.type != DMConstants.TYPE_RESPONSE and node.type != DMConstants.TYPE_CONDITION:
					if previous.child_ids.is_empty() and not _ends_sequence(previous):
						_connect_flow(document, previous.id, node.id, "sequence")

			if node.child_ids.size() > 0:
				_connect_flow(document, node.id, node.child_ids[0], "body")

		if response_run.size() > 0:
			_flush_response_run(document, response_run)


static func _flush_response_run(document: DMGraphDocument, responses: Array[Dictionary], next_node: Dictionary = {}) -> void:
	if responses.is_empty():
		return

	var predecessor_id: String = ""
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("child_ids", []).has(responses[0].id):
			predecessor_id = id
			break

	if predecessor_id == "":
		for id: String in document.nodes:
			var node: Dictionary = document.nodes[id]
			if node.type == DMConstants.TYPE_CUE:
				predecessor_id = id
				break

	if predecessor_id != "":
		for response: Dictionary in responses:
			_connect_flow(document, predecessor_id, response.id, "branch")
			if response.child_ids.size() > 0:
				_connect_flow(document, response.id, response.child_ids[0], "body")

	if not next_node.is_empty():
		for response: Dictionary in responses:
			var exit_id: String = _find_last_in_chain(document, response.id)
			if exit_id != "":
				_connect_flow(document, exit_id, next_node.id, "sequence")


static func _group_children_by_parent(document: DMGraphDocument) -> Dictionary:
	var children_by_parent: Dictionary = {}
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		var parent_id: String = node.get("parent_id", "")
		if not children_by_parent.has(parent_id):
			children_by_parent[parent_id] = []
		children_by_parent[parent_id].append(node)

	for parent_id: String in children_by_parent:
		var children: Array = children_by_parent[parent_id]
		children.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.line_number < b.line_number
		)
	return children_by_parent


static func _ends_sequence(node: Dictionary) -> bool:
	return node.type in [DMConstants.TYPE_GOTO, DMConstants.TYPE_END]


static func _find_last_in_chain(document: DMGraphDocument, start_id: String) -> String:
	var current_id: String = start_id
	var safety: int = 0
	while safety < 1000:
		safety += 1
		var conns: Array[Dictionary] = document.get_connections_from_port(current_id, "sequence")
		if conns.is_empty():
			conns = document.get_connections_from_port(current_id, "body")
		if conns.is_empty():
			return current_id
		current_id = conns[0].to_node
	return current_id
