class_name DMGraphNodeIcons
extends RefCounted
## Labels and tooltips for graph editor node types.


## Menu entries for each addable graph node type.
const NODE_ENTRIES: Array[Dictionary] = [
	{ type = DMConstants.TYPE_CUE, label = "Cue", tooltip = "Start a new dialogue section (~ cue_name)" },
	{ type = DMConstants.TYPE_DIALOGUE, label = "Dialogue", tooltip = "A line of dialogue spoken by a character" },
	{ type = DMConstants.TYPE_RESPONSE, label = "Responses", tooltip = "Player choices — a menu of response options" },
	{ type = DMConstants.TYPE_CONDITION, label = "Condition", tooltip = "Branch the flow with if / elif / else" },
	{ type = DMConstants.TYPE_WHILE, label = "While", tooltip = "Repeat lines while an expression is true" },
	{ type = DMConstants.TYPE_MATCH, label = "Match", tooltip = "Branch on a value with match / when / else" },
	{ type = DMConstants.TYPE_MUTATION, label = "Mutation", tooltip = "Run a GDScript expression (do, set, etc.)" },
	{ type = DMConstants.TYPE_GOTO, label = "Goto", tooltip = "Jump to another cue or snippet" },
	{ type = DMConstants.TYPE_END, label = "End", tooltip = "End the dialogue here" },
	{ type = DMConstants.TYPE_RANDOM, label = "Random", tooltip = "Pick one line at random by weight" },
]
