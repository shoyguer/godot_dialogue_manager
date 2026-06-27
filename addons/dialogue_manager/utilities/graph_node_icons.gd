class_name DMGraphNodeIcons
extends RefCounted
## Icons and labels for graph editor node types.


## Directory that stores graph node SVG icons.
const ICON_DIR: String = "res://addons/dialogue_manager/assets/graph_nodes/"

## Menu entries for each addable graph node type.
const NODE_ENTRIES: Array[Dictionary] = [
	{ type = DMConstants.TYPE_CUE, label = "Cue", icon = "cue.svg" },
	{ type = DMConstants.TYPE_DIALOGUE, label = "Dialogue", icon = "dialogue.svg" },
	{ type = DMConstants.TYPE_RESPONSE, label = "Responses", icon = "response.svg" },
	{ type = DMConstants.TYPE_CONDITION, label = "Condition", icon = "condition.svg" },
	{ type = DMConstants.TYPE_WHILE, label = "While", icon = "while.svg" },
	{ type = DMConstants.TYPE_MATCH, label = "Match", icon = "match.svg" },
	{ type = DMConstants.TYPE_MUTATION, label = "Mutation", icon = "mutation.svg" },
	{ type = DMConstants.TYPE_GOTO, label = "Goto", icon = "goto.svg" },
	{ type = DMConstants.TYPE_END, label = "End", icon = "end.svg" },
	{ type = DMConstants.TYPE_RANDOM, label = "Random", icon = "random.svg" },
]


## Cached loaded icon textures keyed by resource path.
static var _icon_cache: Dictionary = {}

static func get_icon_for_type(type: String) -> Texture2D:
	for entry: Dictionary in NODE_ENTRIES:
		if entry.type == type:
			return get_icon(entry)
	return null


static func get_icon(entry: Dictionary) -> Texture2D:
	var icon_path: String = ICON_DIR + entry.get("icon", "")
	if icon_path.is_empty(): return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path]
	if not ResourceLoader.exists(icon_path): return null
	var texture: Texture2D = load(icon_path) as Texture2D
	if texture:
		_icon_cache[icon_path] = texture
	return texture


static func populate_popup(
	popup: PopupMenu,
	include_type: Callable = Callable(),
) -> void:
	if not is_instance_valid(popup): return
	popup.clear()
	var menu_id: int = 0
	for entry: Dictionary in NODE_ENTRIES:
		var type: String = entry.type
		if include_type.is_valid() and not include_type.call(type):
			continue
		var icon: Texture2D = get_icon(entry)
		if icon:
			popup.add_icon_item(icon, entry.label, menu_id)
		else:
			popup.add_item(entry.label, menu_id)
		popup.set_item_metadata(menu_id, type)
		menu_id += 1


static func get_type_for_menu_id(popup: PopupMenu, id: int) -> String:
	if not is_instance_valid(popup) or id < 0 or id >= popup.item_count:
		return ""
	return popup.get_item_metadata(id) as String
