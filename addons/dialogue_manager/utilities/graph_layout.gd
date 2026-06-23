## Auto-layout for graph nodes using a simple layered DAG algorithm.
class_name DMGraphLayout extends RefCounted


const MIN_NODE_WIDTH: float = 280.0
const MIN_NODE_HEIGHT: float = 100.0
const HORIZONTAL_GAP: float = 64.0
const VERTICAL_GAP: float = 56.0
const ORIGIN: Vector2 = Vector2(48, 48)


static func sanitize_saved_layout(saved_layout: Dictionary, document: DMGraphDocument) -> Dictionary:
	if saved_layout.is_empty():
		return {}

	var position_buckets: Dictionary = {}
	for id: String in saved_layout:
		if not document.has_node(id):
			continue
		var pos: Vector2 = _read_saved_position(saved_layout[id])
		var bucket_key: String = "%d,%d" % [int(pos.x / 100.0), int(pos.y / 100.0)]
		position_buckets[bucket_key] = position_buckets.get(bucket_key, 0) + 1

	for bucket_key: String in position_buckets:
		if position_buckets[bucket_key] >= 2:
			return {}

	return saved_layout


static func apply(document: DMGraphDocument, saved_layout: Dictionary = {}, visual_sizes: Dictionary = {}) -> void:
	apply_with_sizes(document, visual_sizes, saved_layout)


static func apply_with_sizes(document: DMGraphDocument, visual_sizes: Dictionary, saved_layout: Dictionary = {}) -> void:
	saved_layout = sanitize_saved_layout(saved_layout, document)

	if not saved_layout.is_empty():
		for id: String in document.nodes:
			if saved_layout.has(id):
				document.nodes[id].position = _read_saved_position(saved_layout[id])
		_collapse_response_group_positions(document)
		_collapse_condition_chain_positions(document)
		_refine_convergence_positions(document, visual_sizes)
		_resolve_column_overlaps(document, visual_sizes)
		_position_end_nodes_rightmost(document, visual_sizes)
		return

	for id: String in document.nodes:
		document.nodes[id].position = Vector2.ZERO

	var start_id: String = _find_layout_start_id(document)
	if start_id == "":
		return

	_layout_subgraph_with_sizes(start_id, document, ORIGIN, visual_sizes)
	_collapse_response_group_positions(document)
	_collapse_condition_chain_positions(document)
	_refine_convergence_positions(document, visual_sizes)
	_resolve_column_overlaps(document, visual_sizes)
	_position_end_nodes_rightmost(document, visual_sizes)


static func _find_layout_start_id(document: DMGraphDocument) -> String:
	if document.cue_map.size() > 0:
		var entries: Array[Dictionary] = []
		for cue_name: String in document.cue_map:
			var cue_id: String = document.cue_map[cue_name]
			var cue_node: Dictionary = document.get_node(cue_id)
			if not cue_node.is_empty():
				entries.append(cue_node)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.line_number < b.line_number
		)
		if entries.size() > 0:
			return entries[0].id

	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		if node.get("parent_id", "") == "":
			return id
	return ""


static func _collapse_response_group_positions(document: DMGraphDocument) -> void:
	var groups_by_parent: Dictionary = {}
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.type != DMConstants.TYPE_RESPONSE:
			continue
		var parent_id: String = node.get("parent_id", "")
		if not groups_by_parent.has(parent_id):
			groups_by_parent[parent_id] = []
		(groups_by_parent[parent_id] as Array).append(node)

	for parent_id: String in groups_by_parent:
		var responses: Array = groups_by_parent[parent_id]
		if responses.size() <= 1:
			continue
		responses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.line_number < b.line_number
		)
		var anchor_position: Vector2 = responses[0].position
		for i: int in range(1, responses.size()):
			responses[i].position = anchor_position


static func _collapse_condition_chain_positions(document: DMGraphDocument) -> void:
	var ordered_nodes: Array[Dictionary] = _sorted_document_nodes(document)
	var index: int = 0
	while index < ordered_nodes.size():
		if ordered_nodes[index].type != DMConstants.TYPE_CONDITION:
			index += 1
			continue
		var anchor_position: Vector2 = ordered_nodes[index].position
		index += 1
		while index < ordered_nodes.size() and ordered_nodes[index].type == DMConstants.TYPE_CONDITION:
			document.nodes[ordered_nodes[index].id].position = anchor_position
			index += 1


static func _sorted_document_nodes(document: DMGraphDocument) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("is_spacer", false):
			continue
		nodes.append(node)
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.line_number < b.line_number
	)
	return nodes


static func _condition_chain_first_id(document: DMGraphDocument, node_id: String) -> String:
	var ordered_nodes: Array[Dictionary] = _sorted_document_nodes(document)
	var target_index: int = -1
	for i: int in range(0, ordered_nodes.size()):
		if ordered_nodes[i].id == node_id:
			target_index = i
			break
	if target_index == -1:
		return node_id
	var first_index: int = target_index
	while first_index > 0 and ordered_nodes[first_index - 1].type == DMConstants.TYPE_CONDITION:
		first_index -= 1
	return ordered_nodes[first_index].id


static func _read_saved_position(pos: Variant) -> Vector2:
	if pos is Vector2:
		return pos
	if pos is Dictionary:
		return Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	if pos is String:
		var parts: PackedStringArray = pos.split(",")
		if parts.size() >= 2:
			return Vector2(parts[0].to_float(), parts[1].to_float())
	return Vector2.ZERO


static func _layout_subgraph_with_sizes(start_id: String, document: DMGraphDocument, origin: Vector2, visual_sizes: Dictionary) -> float:
	var layers: Array[Array] = []
	var visited: Dictionary = {}
	_assign_layers(start_id, document, 0, layers, visited)

	var layer_column_x: Array[float] = [origin.x]
	var positioned_response_parents: Dictionary = {}
	var max_total_height: float = 0.0

	for layer_idx: int in range(0, layers.size()):
		var layer: Array = layers[layer_idx]
		layer.sort_custom(func(a: String, b: String) -> bool:
			var node_a: Dictionary = document.get_node(a)
			var node_b: Dictionary = document.get_node(b)
			return node_a.get("line_number", 0) < node_b.get("line_number", 0)
		)

		var x: float = layer_column_x[layer_idx]
		var y_cursor: float = origin.y
		var layer_max_width: float = MIN_NODE_WIDTH

		for node_id: String in layer:
			var node: Dictionary = document.get_node(node_id)
			if node.get("layout_hidden", false):
				continue
			if node.type == DMConstants.TYPE_RESPONSE:
				var parent_id: String = node.get("parent_id", "")
				if positioned_response_parents.has(parent_id):
					continue
				positioned_response_parents[parent_id] = true
			if node.type == DMConstants.TYPE_CONDITION:
				if node_id != _condition_chain_first_id(document, node_id):
					continue

			var node_size: Vector2 = _resolve_node_size(document, node_id, visual_sizes)
			layer_max_width = maxf(layer_max_width, node_size.x)
			node.position = Vector2(x, y_cursor)
			y_cursor += node_size.y + VERTICAL_GAP

		var layer_height: float = y_cursor - origin.y
		max_total_height = maxf(max_total_height, layer_height)

		var next_x: float = x + layer_max_width + HORIZONTAL_GAP
		if layer_idx + 1 >= layer_column_x.size():
			layer_column_x.append(next_x)
		else:
			layer_column_x[layer_idx + 1] = maxf(layer_column_x[layer_idx + 1], next_x)

	return maxf(max_total_height, MIN_NODE_HEIGHT)


static func _refine_convergence_positions(document: DMGraphDocument, visual_sizes: Dictionary) -> void:
	var incoming: Dictionary = {}
	for conn: Dictionary in document.connections:
		var to_id: String = conn.get("to_node", "")
		var from_id: String = conn.get("from_node", "")
		if to_id == "" or from_id == "":
			continue
		if not document.has_node(to_id) or not document.has_node(from_id):
			continue
		if not incoming.has(to_id):
			incoming[to_id] = [] as Array[String]
		(incoming[to_id] as Array[String]).append(from_id)

	for to_id: String in incoming:
		var sources: Array[String] = incoming[to_id]
		if sources.size() < 2:
			continue
		var to_node: Dictionary = document.nodes[to_id]
		if to_node.get("layout_hidden", false):
			continue
		# Only nudge merge targets that are compact endpoints; moving dialogue/mutation
		# nodes here stacks them on top of siblings in the same column.
		if to_node.type not in [DMConstants.TYPE_END, DMConstants.TYPE_GOTO]:
			continue

		var center_y: float = 0.0
		var counted: int = 0
		for from_id: String in sources:
			if not document.has_node(from_id):
				continue
			var from_node: Dictionary = document.nodes[from_id]
			if from_node.get("layout_hidden", false):
				continue
			var from_size: Vector2 = _resolve_node_size(document, from_id, visual_sizes)
			center_y += from_node.position.y + from_size.y * 0.5
			counted += 1
		if counted == 0:
			continue

		center_y /= float(counted)
		var to_size: Vector2 = _resolve_node_size(document, to_id, visual_sizes)
		document.nodes[to_id].position.y = center_y - to_size.y * 0.5


static func _resolve_column_overlaps(document: DMGraphDocument, visual_sizes: Dictionary) -> void:
	var columns: Dictionary = {}
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("layout_hidden", false) or node.get("is_spacer", false):
			continue
		if node.type == DMConstants.TYPE_RESPONSE:
			continue
		if node.type == DMConstants.TYPE_CONDITION and id != _condition_chain_first_id(document, id):
			continue

		var column_key: int = int(round(node.position.x / 8.0))
		if not columns.has(column_key):
			columns[column_key] = [] as Array[String]
		(columns[column_key] as Array[String]).append(id)

	for column_key: int in columns:
		var node_ids: Array[String] = columns[column_key]
		if node_ids.size() < 2:
			continue

		node_ids.sort_custom(func(a: String, b: String) -> bool:
			return document.nodes[a].position.y < document.nodes[b].position.y
		)

		var previous_bottom: float = -INF
		for node_id: String in node_ids:
			var node: Dictionary = document.nodes[node_id]
			var node_size: Vector2 = _resolve_node_size(document, node_id, visual_sizes)
			var top: float = node.position.y
			if top < previous_bottom + VERTICAL_GAP:
				top = previous_bottom + VERTICAL_GAP
			node.position.y = top
			previous_bottom = top + node_size.y


static func _position_end_nodes_rightmost(document: DMGraphDocument, visual_sizes: Dictionary) -> void:
	var end_ids: Array[String] = []
	var max_right: float = ORIGIN.x

	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.get("layout_hidden", false) or node.get("is_spacer", false):
			continue
		if node.type == DMConstants.TYPE_END:
			end_ids.append(id)
			continue
		if node.type == DMConstants.TYPE_RESPONSE:
			continue
		if node.type == DMConstants.TYPE_CONDITION and id != _condition_chain_first_id(document, id):
			continue

		var node_size: Vector2 = _resolve_node_size(document, id, visual_sizes)
		max_right = maxf(max_right, node.position.x + node_size.x)

	if end_ids.is_empty():
		return

	var end_x: float = max_right + HORIZONTAL_GAP
	for end_id: String in end_ids:
		document.nodes[end_id].position.x = end_x


static func _resolve_node_size(document: DMGraphDocument, node_id: String, visual_sizes: Dictionary) -> Vector2:
	var node: Dictionary = document.get_node(node_id)
	if visual_sizes.has(node_id):
		return _clamp_size(visual_sizes[node_id], node.get("type", &""))

	if node.is_empty():
		return Vector2(MIN_NODE_WIDTH, MIN_NODE_HEIGHT)

	if node.type == DMConstants.TYPE_RESPONSE:
		var parent_id: String = node.get("parent_id", "")
		var max_size: Vector2 = Vector2(MIN_NODE_WIDTH, MIN_NODE_HEIGHT)
		for size_id: String in visual_sizes:
			if not document.has_node(size_id):
				continue
			var sized_node: Dictionary = document.get_node(size_id)
			if sized_node.type == DMConstants.TYPE_RESPONSE and sized_node.get("parent_id", "") == parent_id:
				var candidate: Vector2 = _clamp_size(visual_sizes[size_id], sized_node.type)
				max_size.x = maxf(max_size.x, candidate.x)
				max_size.y = maxf(max_size.y, candidate.y)
		if max_size.x > MIN_NODE_WIDTH or max_size.y > MIN_NODE_HEIGHT:
			return max_size

	if node.type == DMConstants.TYPE_CONDITION:
		var chain_first_id: String = _condition_chain_first_id(document, node_id)
		if visual_sizes.has(chain_first_id):
			var chain_node: Dictionary = document.get_node(chain_first_id)
			return _clamp_size(visual_sizes[chain_first_id], chain_node.get("type", &""))
		var max_size: Vector2 = Vector2(MIN_NODE_WIDTH, MIN_NODE_HEIGHT)
		for size_id: String in visual_sizes:
			if not document.has_node(size_id):
				continue
			if _condition_chain_first_id(document, size_id) == chain_first_id:
				var sized_node: Dictionary = document.get_node(size_id)
				var candidate: Vector2 = _clamp_size(visual_sizes[size_id], sized_node.get("type", &""))
				max_size.x = maxf(max_size.x, candidate.x)
				max_size.y = maxf(max_size.y, candidate.y)
		if max_size.x > MIN_NODE_WIDTH or max_size.y > MIN_NODE_HEIGHT:
			return max_size

	if node.type in [DMConstants.TYPE_CUE, DMConstants.TYPE_END, DMConstants.TYPE_GOTO]:
		return Vector2(maxf(120.0, visual_sizes.get(node_id, Vector2(120.0, 40.0)).x), maxf(40.0, visual_sizes.get(node_id, Vector2(120.0, 40.0)).y))

	return Vector2(MIN_NODE_WIDTH, _estimate_node_height(document, node_id))


static func _clamp_size(size: Vector2, node_type: StringName = &"") -> Vector2:
	var min_width: float = MIN_NODE_WIDTH
	var min_height: float = MIN_NODE_HEIGHT
	if node_type in [DMConstants.TYPE_CUE, DMConstants.TYPE_END, DMConstants.TYPE_GOTO]:
		min_width = 120.0
		min_height = 40.0
	return Vector2(
		maxf(min_width, size.x),
		maxf(min_height, size.y)
	)


static func _estimate_node_height(document: DMGraphDocument, node_id: String) -> float:
	var node: Dictionary = document.get_node(node_id)
	if node.is_empty():
		return MIN_NODE_HEIGHT

	var text: String = node.get("text", "")
	var line_count: int = maxi(1, text.split("\n").size())

	match node.type:
		DMConstants.TYPE_CONDITION:
			return _estimate_condition_group_height(document, node_id)
		DMConstants.TYPE_RESPONSE:
			return _estimate_response_group_height(document, node)
		DMConstants.TYPE_DIALOGUE:
			return clampf(160.0 + float(line_count) * 32.0, MIN_NODE_HEIGHT, 560.0)
		DMConstants.TYPE_MUTATION:
			return clampf(140.0 + float(text.length()) * 0.2, MIN_NODE_HEIGHT, 280.0)
		DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH:
			return 150.0
		DMConstants.TYPE_CUE, DMConstants.TYPE_END, DMConstants.TYPE_GOTO:
			return 48.0
		_:
			return MIN_NODE_HEIGHT


static func _estimate_response_group_height(document: DMGraphDocument, anchor_node: Dictionary) -> float:
	var parent_id: String = anchor_node.get("parent_id", "")
	var count: int = 0
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.type == DMConstants.TYPE_RESPONSE and node.get("parent_id", "") == parent_id:
			count += 1
	return clampf(100.0 + float(count) * 72.0, MIN_NODE_HEIGHT, 800.0)


static func _estimate_condition_group_height(document: DMGraphDocument, anchor_node_id: String) -> float:
	var chain_first_id: String = _condition_chain_first_id(document, anchor_node_id)
	var count: int = 0
	for id: String in document.nodes:
		var node: Dictionary = document.nodes[id]
		if node.type == DMConstants.TYPE_CONDITION and _condition_chain_first_id(document, id) == chain_first_id:
			count += 1
	return clampf(88.0 + float(count) * 36.0, MIN_NODE_HEIGHT, 480.0)


static func _assign_layers(node_id: String, document: DMGraphDocument, layer: int, layers: Array, visited: Dictionary) -> void:
	if visited.has(node_id):
		return
	visited[node_id] = true

	while layers.size() <= layer:
		layers.append([])

	if not node_id in layers[layer]:
		layers[layer].append(node_id)

	var node: Dictionary = document.get_node(node_id)
	if node.is_empty():
		return

	for conn: Dictionary in document.get_outgoing_connections(node_id):
		if conn.to_node in visited:
			continue
		_assign_layers(conn.to_node, document, layer + 1, layers, visited)


static func extract_layout(document: DMGraphDocument) -> Dictionary:
	var layout: Dictionary = {}
	for id: String in document.nodes:
		var pos: Vector2 = document.nodes[id].position
		layout[id] = { x = pos.x, y = pos.y }
	return layout
