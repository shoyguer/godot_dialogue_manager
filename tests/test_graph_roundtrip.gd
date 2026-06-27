extends AbstractTest


const FIXTURES: Array[String] = [
	"~ start\nNathan: Hello.\n=> END",
	"~ start\nNathan: Choose.\n- Option A\n\tNathan: You picked A.\n- Option B\n\tNathan: You picked B.\n=> END",
	"~ start\nif true\n\tNathan: It is true.\nelse\n\tNathan: It is false.\n=> END",
	"~ start\nset count = 1\ndo something()\n=> END",
	"~ start\n% Nathan: Maybe this.\n% Nathan: Or this.\n=> END",
	"~ start\nwhile count < 3\n\tNathan: Looping.\n=> END",
	"~ start\nNathan: Pick one.\n- Secret [if has_key /]\n\tNathan: You had the key.\n=> END",
	"~ start\nNathan: Tagged line [ID:intro_line] [#happy, #mood=ok]\n## Translator note\n=> END",
	"~ start\ndo! something()\n=> END",
	"~ start\n=>< other_cue\n~ other_cue\nNathan: Snippet target.\n=> END",
	"~ start\nmatch value\n\twhen 1\n\t\tNathan: One.\n\telse\n\t\tNathan: Other.\n=> END",
	"~ start\nNathan: Main line.\n| Nathan: Concurrent line.\n=> END",
]


func test_graph_roundtrip_compiles_without_errors() -> void:
	for fixture: String in FIXTURES:
		var original: DMCompilerResult = compile(fixture)
		assert(original.errors.is_empty(), "Original should compile: %s" % fixture)

		var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
		var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
		var roundtrip: DMCompilerResult = compile(roundtrip_text)

		assert(roundtrip.errors.is_empty(), "Roundtrip should compile without errors.\nOriginal:\n%s\n\nRoundtrip:\n%s" % [fixture, roundtrip_text])


func test_graph_roundtrip_preserves_cues() -> void:
	for fixture: String in FIXTURES:
		var original: DMCompilerResult = compile(fixture)
		var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
		var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
		var roundtrip: DMCompilerResult = compile(roundtrip_text)

		assert(original.cues.keys() == roundtrip.cues.keys(), "Cues should be preserved for:\n%s" % fixture)


func test_graph_roundtrip_from_test_files() -> void:
	var test_files: PackedStringArray = ["res://tests/main.dialogue", "res://tests/snippets.dialogue"]
	for path: String in test_files:
		if not FileAccess.file_exists(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var original: DMCompilerResult = DMCompiler.compile_string(text, path)
		assert(original.errors.is_empty(), "Original %s should compile" % path)

		var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(text, path)
		var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
		var roundtrip: DMCompilerResult = DMCompiler.compile_string(roundtrip_text, path)

		assert(roundtrip.errors.is_empty(), "Roundtrip of %s should compile.\n%s" % [path, roundtrip_text])
		assert(original.cues.size() == roundtrip.cues.size(), "Cue count should match for %s" % path)


func test_graph_roundtrip_example_dialogue() -> void:
	var fixture: String = FileAccess.get_file_as_string("res://dialogues/example.dialogue")
	var original: DMCompilerResult = compile(fixture)
	assert(original.errors.is_empty(), "Original example.dialogue should compile")

	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture, "res://dialogues/example.dialogue")
	assert(document.cue_map.has("start"), "Cue node should be present in graph model")
	assert(document.nodes.size() >= 7, "Example dialogue should have cue, lines, and END goto")

	var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
	var roundtrip: DMCompilerResult = compile(roundtrip_text)

	assert(roundtrip.errors.is_empty(), "Roundtrip should compile.\nRoundtrip:\n%s" % roundtrip_text)
	assert(roundtrip_text.contains("Player: Stay here"), "Dialogue lines should be preserved")
	assert(roundtrip_text.contains("Player: Follow me"), "Second dialogue block should be preserved")
	assert(roundtrip_text.contains("=> END"), "END goto should be preserved")

	var branch_count: int = 0
	for conn: Dictionary in document.connections:
		if conn.kind == "branch":
			branch_count += 1
	assert(branch_count >= 4, "Example dialogue should have response branch connections, got %d" % branch_count)


func test_response_group_branches() -> void:
	var fixture: String = "~ start\nNathan: Choose.\n- Option A\n\tNathan: A.\n- Option B\n\tNathan: B.\n=> END"
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
	var branches_from_choose: int = 0
	for conn: Dictionary in document.connections:
		if conn.kind == "branch":
			branches_from_choose += 1
	assert(branches_from_choose >= 2, "Two response options should branch from predecessor")


func test_example_dialogue_graph_stats() -> void:
	var text: String = FileAccess.get_file_as_string("res://dialogues/example.dialogue")
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(text, "res://dialogues/example.dialogue")
	assert(document.nodes.size() > 50, "Should have many nodes, got %d" % document.nodes.size())
	assert(document.connections.size() > 50, "Should have many connections, got %d" % document.connections.size())
	var branch_count: int = 0
	for conn: Dictionary in document.connections:
		if conn.kind == "branch":
			branch_count += 1
	assert(branch_count >= 10, "Should have branch connections, got %d" % branch_count)


func test_response_menu_cue_connections() -> void:
	var text: String = FileAccess.get_file_as_string("res://dialogues/example.dialogue")
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(text, "res://dialogues/example.dialogue")
	var filtered: DMGraphDocument = DMGraphCueFilter.filter_document(document, "cautious_options")

	assert(filtered.cue_map.has("cautious_options"), "Should include cautious_options cue")
	var cue_id: String = filtered.cue_map["cautious_options"]
	var response_ids: Array[String] = DMGraphCueFilter.get_section_response_ids(filtered, "cautious_options")
	assert(response_ids.size() == 5, "cautious_options should have 5 responses, got %d" % response_ids.size())

	var branches_from_cue: int = 0
	for conn: Dictionary in filtered.connections:
		if conn.from_node == cue_id and conn.kind == "branch" and conn.to_node in response_ids:
			branches_from_cue += 1

	assert(branches_from_cue == 5, "Cue should branch to every response, got %d" % branches_from_cue)

	var entry_id: String = DMGraphCueFilter.get_cue_entry_node_id(filtered, "cautious_options")
	for conn: Dictionary in filtered.connections:
		if conn.kind == "goto" and conn.to_node == entry_id and entry_id != cue_id:
			assert(false, "Loop gotos should target the cue header, not the first response line")


func test_cue_filter_splits_sections() -> void:
	var text: String = FileAccess.get_file_as_string("res://dialogues/example.dialogue")
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(text, "res://dialogues/example.dialogue")
	var full_count: int = document.nodes.size()

	var start_doc: DMGraphDocument = DMGraphCueFilter.filter_document(document, "start")
	var impressed_doc: DMGraphDocument = DMGraphCueFilter.filter_document(document, "impressed")

	assert(start_doc.nodes.size() < full_count, "Start section should be smaller than full file")
	assert(impressed_doc.nodes.size() < full_count, "Impressed section should be smaller than full file")
	assert(start_doc.cue_map.has("start"), "Start graph should include the start cue")
	assert(impressed_doc.cue_map.has("impressed"), "Impressed graph should include the impressed cue")
	assert(not start_doc.cue_map.has("impressed"), "Start graph should not include other cues")


func test_compiler_build_tree_api() -> void:
	var text: String = "~ start\nNathan: Hi.\n=> END"
	var root: DMTreeLine = DMCompiler.build_tree(text)
	assert(root.children.size() > 0, "Tree should have children")
	assert(root.children[0].type == DMConstants.TYPE_CUE, "First child should be cue")

	var metadata: Dictionary = DMCompiler.build_tree_with_metadata(text)
	assert(metadata.has("root"), "Metadata should include root")
	assert(metadata.has("cues"), "Metadata should include cues")


func test_graph_roundtrip_preserves_response_slash_condition() -> void:
	var fixture: String = "~ start\nNathan: Pick.\n- Secret [if has_key /]\n\tNathan: Unlocked.\n=> END"
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
	var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
	assert(roundtrip_text.contains("[if has_key /]"), "Slash condition should survive roundtrip: %s" % roundtrip_text)
	assert(compile(roundtrip_text).errors.is_empty(), "Should compile after roundtrip")


func test_graph_roundtrip_preserves_metadata() -> void:
	var fixture: String = "~ start\nNathan: Hello [ID:greet] [#happy]\n## Note line\n=> END"
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
	var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
	assert(roundtrip_text.contains("[ID:greet]"), "Static ID should survive: %s" % roundtrip_text)
	assert(roundtrip_text.contains("[#happy]"), "Tags should survive: %s" % roundtrip_text)
	assert(roundtrip_text.contains("## Note line"), "Notes should survive: %s" % roundtrip_text)


func test_graph_roundtrip_preserves_nonblocking_mutation() -> void:
	var fixture: String = "~ start\ndo! something()\n=> END"
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
	var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
	assert(roundtrip_text.contains("do!"), "Non-blocking mutation should survive: %s" % roundtrip_text)


func test_graph_roundtrip_preserves_snippet_goto() -> void:
	var fixture: String = "~ start\n=>< other\n~ other\nNathan: There.\n=> END"
	var document: DMGraphDocument = DMGraphTreeBuilder.build_from_text(fixture)
	var roundtrip_text: String = DMGraphTextSerializer.serialize(document)
	assert(roundtrip_text.contains("=>< other"), "Snippet goto should survive: %s" % roundtrip_text)
