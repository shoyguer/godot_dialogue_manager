## In-memory graph model for the dialogue visual editor.
class_name DMGraphDocument extends RefCounted


const PORT_SEQUENCE: StringName = &"sequence"
const PORT_BRANCH_PREFIX: StringName = &"branch_"
const PORT_GOTO: StringName = &"goto"
const PORT_LOOP: StringName = &"loop"
const PORT_EXIT: StringName = &"exit"
const PORT_TRUE: StringName = &"true"
const PORT_FALSE: StringName = &"false"
const PORT_ELSE: StringName = &"else"
const PORT_INPUT: StringName = &"input"


## Raw import lines from the source file preamble.
var imports: PackedStringArray = []
## Using clause state names.
var using_states: PackedStringArray = []
## Region markers for editor grouping: { name, start_node_id }
var regions: Array[Dictionary] = []
## Top-level comments preserved in preamble.
var preamble_lines: PackedStringArray = []
## All graph nodes keyed by id (usually tree line id).
var nodes: Dictionary = {}
## Visual connections: { from_node, from_port, to_node, to_port, kind }
var connections: Array[Dictionary] = []
## Known cue name -> node id
var cue_map: Dictionary = {}


func clear() -> void:
	imports.clear()
	using_states.clear()
	regions.clear()
	preamble_lines.clear()
	nodes.clear()
	connections.clear()
	cue_map.clear()


func add_node(node_data: Dictionary) -> void:
	nodes[node_data.id] = node_data
	if node_data.type == DMConstants.TYPE_CUE:
		var cue_name: String = node_data.get("cue_name", "")
		if cue_name != "":
			cue_map[cue_name] = node_data.id


func get_node(id: String) -> Dictionary:
	return nodes.get(id, {})


func has_node(id: String) -> bool:
	return nodes.has(id)


func remove_node(id: String) -> void:
	nodes.erase(id)
	connections = connections.filter(func(c: Dictionary) -> bool:
		return c.from_node != id and c.to_node != id
	)


func add_connection(from_node: String, from_port: String, to_node: String, to_port: String = "input", kind: String = "sequence") -> void:
	connections = connections.filter(func(c: Dictionary) -> bool:
		return not (c.from_node == from_node and c.from_port == from_port and c.to_node == to_node)
	)
	connections.append({
		from_node = from_node,
		from_port = from_port,
		to_node = to_node,
		to_port = to_port,
		kind = kind,
	})


func get_connections_from_port(from_node: String, from_port: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c: Dictionary in connections:
		if c.from_node == from_node and c.from_port == from_port:
			result.append(c)
	return result


func get_connection_from_port(from_node: String, from_port: String) -> Dictionary:
	for c: Dictionary in connections:
		if c.from_node == from_node and c.from_port == from_port:
			return c
	return {}


func get_outgoing_connections(from_node: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c: Dictionary in connections:
		if c.from_node == from_node:
			result.append(c)
	return result


func get_connections_to(to_node: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c: Dictionary in connections:
		if c.to_node == to_node:
			result.append(c)
	return result


func duplicate() -> DMGraphDocument:
	var copy: DMGraphDocument = DMGraphDocument.new()
	copy.imports = imports.duplicate()
	copy.using_states = using_states.duplicate()
	copy.regions = regions.duplicate(true)
	copy.preamble_lines = preamble_lines.duplicate()
	copy.nodes = nodes.duplicate(true)
	copy.connections = connections.duplicate(true)
	copy.cue_map = cue_map.duplicate()
	return copy
