## A compiler of Dialogue Manager dialogue.
class_name DMCompiler extends RefCounted


## Compile a dialogue script.
static func compile_string(text: String, path: String) -> DMCompilerResult:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.compile(text, path)

	var result: DMCompilerResult = DMCompilerResult.new()
	result.imported_paths = compilation.imported_paths
	result.using_states = compilation.using_states
	result.character_names = compilation.character_names
	result.cues = compilation.cues
	result.first_cue = compilation.first_cue
	result.errors = compilation.errors
	result.lines = compilation.data

	return result


## Get the line type of a string. The returned string will match one of the [code]TYPE_[/code] constants of [DMConstants].
static func get_line_type(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.get_line_type(text)


## Get the static line ID (eg. [code][ID:SOMETHING][/code]) of some text.
static func get_static_line_id(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.extract_static_line_id(text)


## Get the translatable part of a line.
static func extract_translatable_string(text: String) -> String:
	var compilation: DMCompilation = DMCompilation.new()

	var tree_line: DMTreeLine = DMTreeLine.new("")
	tree_line.text = text
	var line: DMCompiledLine = DMCompiledLine.new("", compilation.get_line_type(text))
	compilation.parse_character_and_dialogue(tree_line, line, [tree_line], 0, null)

	return line.text


## Extract a mutation from a string.
static func extract_mutation(text: String) -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	return compilation.extract_mutation(text)


## Get the known cues in a dialogue script.
static func get_cues_in_text(text: String, path: String) -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.find_imported_cues(text, path)
	compilation.build_line_tree(text.split("\n"))
	return compilation.cues


## Build a parse tree from dialogue text without fully compiling it.
## Used by the graph editor to convert text to a visual representation.
static func build_tree(text: String, path: String = ".") -> DMTreeLine:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.file_path = path
	compilation.find_imported_cues(text, path)
	return compilation.build_line_tree(text.split("\n"))


## Build a parse tree and return preamble metadata (imports, using clauses).
static func build_tree_with_metadata(text: String, path: String = ".") -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.file_path = path
	compilation.find_imported_cues(text, path)
	var root: DMTreeLine = compilation.build_line_tree(text.split("\n"))
	var imports: PackedStringArray = []
	for i: int in range(0, text.split("\n").size()):
		var line: String = text.split("\n")[i].strip_edges()
		if compilation.is_import_line(line):
			imports.append(line)
	return {
		root = root,
		imports = imports,
		using_states = compilation.using_states,
		cues = compilation.cues,
		errors = compilation.errors,
	}


## Return live [DMCompiledLine] objects for graph flow wiring (not [code]to_data()[/code] dictionaries).
static func get_compiled_lines(text: String, path: String = ".") -> Dictionary:
	var compilation: DMCompilation = DMCompilation.new()
	compilation.file_path = path
	var compile_text: String = text + "\n=> END"
	compilation.find_imported_cues(compile_text, path)
	compilation.parse_line_tree(compilation.build_line_tree(compile_text.split("\n")))
	return compilation.lines
