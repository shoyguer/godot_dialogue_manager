class_name DMGraphTooltips
extends RefCounted
## Tooltip text for graph editor controls.


const PALETTE_AUTO_LAYOUT: String = "Automatically arrange nodes in the active cue"
const RESPONSE_ROW: String = "Click to edit this option in the properties panel. Double-click to focus the text field."
const RESPONSE_ADD: String = "Add another player choice to this response menu"
const RESPONSE_DELETE: String = "Remove this response option"
const CONDITION_ADD_ELIF: String = "Add another branch to this condition chain"
const CONDITION_ADD_ELSE: String = "Add a final else branch"
const MATCH_ADD_WHEN: String = "Add another when case to this match"
const MATCH_ADD_ELSE: String = "Add an else case to this match"
const RANDOM_ADD_LINE: String = "Add another weighted random line"
const NODE_DELETE: String = "Delete this node from the graph"
const GRAPH_CANVAS: String = "Right-click to add nodes. Drag nodes to move them. Connect ports to link dialogue flow."
const FILE_IMPORTS: String = "Import other dialogue files into this one.\nOne import per line, e.g. import \"res://npc.dialogue\" as npc"
const FILE_USING: String = "Autoloads and globals available in expressions.\nComma-separated names, e.g. Global, QuestManager"
const INSPECTOR_TYPE: String = "The kind of node or group currently selected"
const INSPECTOR_INSERT: String = "Insert dialogue markup at the cursor"
const INSPECTOR_CHARACTER: String = "Speaker name shown before the line, e.g. Alice"
const INSPECTOR_DIALOGUE: String = "Dialogue line text. Supports {{variables}}, BBCode, and [tags]."
const INSPECTOR_STATIC_ID: String = "Stable ID for referencing this line from code [ID:my_key]"
const INSPECTOR_TAGS: String = "Comma-separated tags used by your game logic"
const INSPECTOR_NOTES: String = "Notes for translators (not shown in game)"
const INSPECTOR_RESPONSE_TEXT: String = "Text shown to the player for this choice (without the leading dash)"
const INSPECTOR_RESPONSE_CONDITION: String = "Optional expression — option is shown only when true.\nWrite the expression only, e.g. Global.quest_started or {{gold}} >= 10"
const INSPECTOR_CONCURRENT: String = "Lines spoken at the same time.\nOne per line: | Character: text"
const INSPECTOR_CUE_NAME: String = "Cue title referenced by goto nodes (~ my_cue)"
const INSPECTOR_MUTATION: String = "GDScript expression run when this line is reached, e.g. Global.score += 1"
const INSPECTOR_MUTATION_BLOCKING: String = "Wait for this mutation to finish before continuing dialogue"
const INSPECTOR_GOTO_TARGET: String = "Cue or snippet title to jump to"
const INSPECTOR_GOTO_SNIPPET: String = "Jump to a snippet inside the target cue (=><) instead of its start (=>)"
const INSPECTOR_RANDOM_WEIGHT: String = "Relative weight when picking among random lines (higher = more likely)"
const INSPECTOR_RANDOM_TEXT: String = "Random line body text (without the % prefix)"
const INSPECTOR_CONDITION_BRANCH: String = "Expression that must be true for this branch to run"
const INSPECTOR_MATCH_EXPRESSION: String = "Value matched against each when case, e.g. Global.current_mood"
const INSPECTOR_MATCH_WHEN: String = "Case label compared against the match expression"
const INSPECTOR_MATCH_ELSE: String = "Runs when no when case matches"


static func for_palette_type(type: String) -> String:
	for entry: Dictionary in DMGraphNodeIcons.NODE_ENTRIES:
		if entry.get("type", "") == type:
			return entry.get("tooltip", "Add a %s node to the graph" % entry.get("label", type))
	return "Add a node to the graph"
