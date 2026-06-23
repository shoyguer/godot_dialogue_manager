## Filters a graph document down to a single cue / dialogue section.
class_name DMGraphCueFilter extends RefCounted


static func get_ordered_cue_names(document: DMGraphDocument) -> Array[String]:
	var entries: Array[Dictionary] = []
	for cue_name: String in document.cue_map:
		var cue_id: String = document.cue_map[cue_name]
		var cue_node: Dictionary = document.get_node(cue_id)
		if cue_node.is_empty():
			continue
		entries.append({ name = cue_name, line_number = cue_node.line_number })

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.line_number < b.line_number
	)

	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(entry.name)
	return result


static func get_cue_line_range(document: DMGraphDocument, cue_name: String) -> Vector2i:
	var cue_id: String = document.cue_map.get(cue_name, "")
	if cue_id == "":
		return Vector2i(0, 0)

	var start_line: int = document.get_node(cue_id).line_number
	var end_line: int = 2147483647

	for other_name: String in document.cue_map:
		if other_name == cue_name:
			continue
		var other_node: Dictionary = document.get_node(document.cue_map[other_name])
		if other_node.line_number > start_line:
			end_line = mini(end_line, other_node.line_number)

	return Vector2i(start_line, end_line)


static func get_cue_entry_node_id(document: DMGraphDocument, cue_name: String) -> String:
	var line_range: Vector2i = get_cue_line_range(document, cue_name)
	var cue_id: String = document.cue_map.get(cue_name, "")
	var entry_id: String = ""
	var entry_line: int = 2147483647

	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		if id == cue_id:
			continue
		var line_number: int = node.get("line_number", 0)
		if line_number <= line_range.x or line_number >= line_range.y:
			continue
		if line_number < entry_line:
			entry_line = line_number
			entry_id = id

	return entry_id


static func get_section_response_ids(document: DMGraphDocument, cue_name: String) -> Array[String]:
	var line_range: Vector2i = get_cue_line_range(document, cue_name)
	var responses: Array[Dictionary] = []

	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.type != DMConstants.TYPE_RESPONSE:
			continue
		var line_number: int = node.get("line_number", 0)
		if line_number >= line_range.x and line_number < line_range.y:
			responses.append(node)

	responses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.line_number < b.line_number
	)

	var result: Array[String] = []
	for node: Dictionary in responses:
		result.append(node.id)
	return result


static func is_response_menu_cue(document: DMGraphDocument, cue_name: String) -> bool:
	var entry_id: String = get_cue_entry_node_id(document, cue_name)
	if entry_id == "":
		return false
	return document.get_node(entry_id).type == DMConstants.TYPE_RESPONSE


static func filter_document(source: DMGraphDocument, cue_name: String) -> DMGraphDocument:
	var filtered: DMGraphDocument = DMGraphDocument.new()
	filtered.imports = source.imports.duplicate()
	filtered.using_states = source.using_states.duplicate()
	filtered.regions = source.regions.duplicate(true)
	filtered.preamble_lines = source.preamble_lines.duplicate()

	var line_range: Vector2i = get_cue_line_range(source, cue_name)
	var included_ids: Dictionary = {}

	for id: String in source.nodes:
		var node: Dictionary = source.nodes[id]
		if node.get("is_spacer", false):
			continue
		var line_number: int = node.get("line_number", 0)
		if line_number >= line_range.x and line_number < line_range.y:
			filtered.nodes[id] = node.duplicate(true)
			included_ids[id] = true

	if source.cue_map.has(cue_name):
		filtered.cue_map[cue_name] = source.cue_map[cue_name]

	for conn: Dictionary in source.connections:
		if included_ids.has(conn.from_node) and included_ids.has(conn.to_node):
			filtered.connections.append(conn.duplicate(true))

	_repair_section_connections(filtered, cue_name)
	normalize_section_terminals(filtered, cue_name)
	return filtered


static func normalize_section_terminals(document: DMGraphDocument, cue_name: String) -> void:
	_dedupe_end_nodes(document)
	_dedupe_extra_cues(document, cue_name)


static func _dedupe_end_nodes(document: DMGraphDocument) -> void:
	var end_ids: Array[String] = []
	for id: String in document.nodes:
		if document.nodes[id].type == DMConstants.TYPE_END:
			end_ids.append(id)

	if end_ids.size() <= 1:
		return

	end_ids.sort_custom(func(a: String, b: String) -> bool:
		return document.nodes[a].line_number < document.nodes[b].line_number
	)

	var canonical_id: String = end_ids[end_ids.size() - 1]
	var remap: Dictionary = {}
	for i: int in range(0, end_ids.size() - 1):
		remap[end_ids[i]] = canonical_id

	for conn: Dictionary in document.connections:
		if remap.has(conn.to_node):
			conn.to_node = remap[conn.to_node]
		if remap.has(conn.from_node):
			conn.from_node = remap[conn.from_node]

	for duplicate_id: String in remap:
		document.remove_node(duplicate_id)


static func _dedupe_extra_cues(document: DMGraphDocument, cue_name: String) -> void:
	var section_cue_id: String = document.cue_map.get(cue_name, "")
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.type != DMConstants.TYPE_CUE:
			continue
		if section_cue_id != "" and id == section_cue_id:
			continue
		document.remove_node(id)


static func _repair_section_connections(document: DMGraphDocument, cue_name: String) -> void:
	var cue_id: String = document.cue_map.get(cue_name, "")
	if cue_id == "":
		return

	var entry_id: String = get_cue_entry_node_id(document, cue_name)
	if entry_id != "" and entry_id != cue_id:
		var repaired_connections: Array[Dictionary] = []
		for conn: Dictionary in document.connections:
			var copy: Dictionary = conn.duplicate(true)
			if copy.kind == "goto" and copy.to_node == entry_id:
				copy.to_node = cue_id
			repaired_connections.append(copy)
		document.connections = repaired_connections

	if not is_response_menu_cue(document, cue_name):
		return

	var response_ids: Array[String] = get_section_response_ids(document, cue_name)
	for resp_id: String in response_ids:
		document.connections = document.connections.filter(func(c: Dictionary) -> bool:
			return not (c.from_node == cue_id and c.to_node == resp_id and c.kind == "branch")
		)
		document.add_connection(cue_id, "branch", resp_id, "input", "branch")


static func normalize_saved_layouts(saved_layouts: Dictionary, document: DMGraphDocument) -> Dictionary:
	if saved_layouts.is_empty():
		return {}

	for cue_name: String in saved_layouts:
		if document.cue_map.has(cue_name):
			return saved_layouts.duplicate(true)

	var sample_key: Variant = saved_layouts.values()[0] if saved_layouts.size() > 0 else null
	if sample_key is Dictionary and sample_key.has("x"):
		var cue_names: Array[String] = get_ordered_cue_names(document)
		if cue_names.size() > 0:
			return { cue_names[0]: saved_layouts.duplicate(true) }

	return saved_layouts.duplicate(true)
