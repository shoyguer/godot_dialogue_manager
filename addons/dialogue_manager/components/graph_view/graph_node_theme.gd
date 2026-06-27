## Shared styling for graph editor nodes.
class_name DMGraphNodeTheme extends RefCounted


const TITLE_FONT_SIZE: int = 14
const META_FONT_SIZE: int = 11
const DISPLAY_FONT_SIZE: int = 13
const LABEL_MUTED_COLOR: Color = Color(0.52, 0.52, 0.56, 1.0)
const FIELD_BG_COLOR: Color = Color(0.08, 0.08, 0.1, 1.0)
const BODY_FILL_COLOR: Color = Color(0.08, 0.07, 0.06, 1.0)
const HEADER_STRIP_COLOR: Color = Color(0.18, 0.18, 0.2, 0.92)
const HEADER_STRIP_HEIGHT: float = 6.0
const META_ID_COLOR: Color = Color(0.92, 0.9, 0.86, 1.0)
const DISPLAY_TEXT_COLOR: Color = Color(0.88, 0.86, 0.82, 1.0)
const DISPLAY_CHARACTER_COLOR: Color = Color(0.78, 0.76, 0.72, 1.0)
const NODE_BOTTOM_MARGIN: float = 4.0
const CONNECTION_CURVATURE: int = 35
const OUTLINE_WIDTH: int = 2
const CONTENT_PADDING: int = 8

const ACCENT_CUE: Color = Color(0.24, 0.46, 0.32, 1.0)
const ACCENT_DIALOGUE: Color = Color(0.58, 0.30, 0.22, 1.0)
const ACCENT_RESPONSE: Color = Color(0.22, 0.44, 0.30, 1.0)
const ACCENT_MUTATION: Color = Color(0.72, 0.54, 0.14, 1.0)
const ACCENT_CONDITION: Color = Color(0.30, 0.40, 0.58, 1.0)
const ACCENT_GOTO: Color = Color(0.44, 0.38, 0.20, 1.0)
const ACCENT_END: Color = Color(0.34, 0.34, 0.38, 1.0)
const ACCENT_DEFAULT: Color = Color(0.38, 0.38, 0.40, 1.0)
const TITLE_DARKEN_AMOUNT: float = 0.40
const TITLE_LIGHTEN_AMOUNT: float = 0.12
const COMPACT_DARKEN_AMOUNT: float = 0.36
const COMPACT_LIGHTEN_AMOUNT: float = 0.10
const PANEL_BORDER_COLOR: Color = Color(0.28, 0.28, 0.32, 1.0)
const FIELD_LABEL_WIDTH: float = 56.0

const ROW_STRIP_COLOR_A: Color = Color(0.07, 0.06, 0.05, 1.0)
const ROW_STRIP_COLOR_B: Color = Color(0.17, 0.16, 0.15, 1.0)
const RESPONSE_NUMBER_WIDTH: float = 28.0
const RESPONSE_NUMBER_COLOR: Color = Color(0.42, 0.42, 0.46, 1.0)
const PORT_COLOR: Color = Color(0.55, 0.58, 0.65, 1.0)
const CONNECTION_COLOR: Color = Color(0.45, 0.5, 0.58, 1.0)

static var _display_font: Font


static func get_accent_for_type(type: String) -> Color:
	match type:
		DMConstants.TYPE_CUE:
			return ACCENT_CUE
		DMConstants.TYPE_DIALOGUE:
			return ACCENT_DIALOGUE
		DMConstants.TYPE_RESPONSE, "response_group":
			return ACCENT_RESPONSE
		DMConstants.TYPE_MUTATION:
			return ACCENT_MUTATION
		DMConstants.TYPE_CONDITION, DMConstants.TYPE_WHILE, DMConstants.TYPE_MATCH, DMConstants.TYPE_WHEN:
			return ACCENT_CONDITION
		DMConstants.TYPE_GOTO:
			return ACCENT_GOTO
		DMConstants.TYPE_END:
			return ACCENT_END
		_:
			return ACCENT_DEFAULT


static func get_port_color_for_type(type: String) -> Color:
	return PORT_COLOR


static func get_display_font() -> Font:
	if _display_font != null:
		return _display_font
	var system_font: SystemFont = SystemFont.new()
	system_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
	system_font.font_weight = 400
	_display_font = system_font
	return _display_font


static func get_row_strip_color(row_index: int) -> Color:
	return ROW_STRIP_COLOR_B if row_index % 2 == 1 else ROW_STRIP_COLOR_A


static func make_row_strip_style(row_index: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = get_row_strip_color(row_index)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


static func apply_styled_node(node: GraphNode, accent_color: Color, title_text: String = "") -> void:
	apply_title(node, accent_color)
	node.title = title_text


static func apply_title(node: GraphNode, bg_color: Color) -> void:
	var style: StyleBoxFlat = _make_title_stylebox(bg_color)
	node.add_theme_color_override(&"title_color", Color.WHITE)
	node.add_theme_stylebox_override(&"titlebar", style)
	node.add_theme_font_size_override(&"title_font_size", TITLE_FONT_SIZE)
	_apply_bold_title_font(node)
	node.clip_contents = false
	_apply_body_panel(node, bg_color)


static func _apply_body_panel(node: GraphNode, _accent_color: Color) -> void:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = BODY_FILL_COLOR
	panel.border_color = PANEL_BORDER_COLOR
	panel.set_border_width_all(1)
	panel.corner_radius_top_left = 3
	panel.corner_radius_top_right = 3
	panel.corner_radius_bottom_left = 3
	panel.corner_radius_bottom_right = 3
	panel.content_margin_left = CONTENT_PADDING
	panel.content_margin_right = CONTENT_PADDING
	panel.content_margin_top = 4
	panel.content_margin_bottom = CONTENT_PADDING
	node.add_theme_stylebox_override(&"panel", panel)


static func apply_palette_add_button(button: Button) -> void:
	button.add_theme_color_override(&"font_color", Color(0.84, 0.84, 0.80, 1.0))
	button.add_theme_font_size_override(&"font_size", 12)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.17, 1.0)
	normal.border_color = Color(0.24, 0.24, 0.28, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	button.add_theme_stylebox_override(&"normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.20, 0.23, 1.0)
	hover.border_color = Color(0.32, 0.32, 0.36, 1.0)
	button.add_theme_stylebox_override(&"hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.add_theme_stylebox_override(&"focus", normal.duplicate())
	button.add_theme_stylebox_override(&"disabled", normal.duplicate())


static func apply_response_number_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", RESPONSE_NUMBER_COLOR)
	label.add_theme_font_size_override(&"font_size", TITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_bold_title_font_to_control(label, 700)


static func apply_field_name_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", LABEL_MUTED_COLOR)
	label.add_theme_font_size_override(&"font_size", META_FONT_SIZE)
	label.custom_minimum_size.x = FIELD_LABEL_WIDTH


static func apply_compact(node: GraphNode, bg_color: Color) -> void:
	var empty_title: StyleBoxEmpty = StyleBoxEmpty.new()
	node.add_theme_stylebox_override(&"titlebar", empty_title)
	node.add_theme_constant_override(&"separation", 0)
	node.title = ""
	node.clip_contents = false

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = bg_color.lightened(COMPACT_LIGHTEN_AMOUNT).darkened(COMPACT_DARKEN_AMOUNT)
	panel_style.set_corner_radius_all(4)
	panel_style.set_border_width_all(0)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	node.add_theme_stylebox_override(&"panel", panel_style)


static func apply_compact_panel(panel: PanelContainer, _bg_color: Color) -> void:
	var empty_panel: StyleBoxEmpty = StyleBoxEmpty.new()
	panel.add_theme_stylebox_override(&"panel", empty_panel)
	if panel.get_child_count() > 0:
		var title_label: Label = panel.get_child(0) as Label
		if title_label != null:
			title_label.add_theme_color_override(&"font_color", Color.WHITE)
			title_label.add_theme_font_size_override(&"font_size", TITLE_FONT_SIZE)
			_apply_bold_title_font_to_control(title_label, 800)


static func _make_title_stylebox(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(TITLE_LIGHTEN_AMOUNT).darkened(TITLE_DARKEN_AMOUNT)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func _apply_bold_title_font(node: GraphNode) -> void:
	_apply_bold_title_font_to_control(node, 800)


static func _apply_bold_title_font_to_control(control: Control, weight: int = 800) -> void:
	var base_font: Font = null
	if control is GraphNode:
		base_font = control.get_theme_font(&"title_font", &"GraphNode")
	if base_font == null:
		base_font = control.get_theme_font(&"font")
	if base_font != null:
		var bold_font: FontVariation = FontVariation.new()
		bold_font.base_font = base_font
		bold_font.variation_opentype = { &"wght": weight }
		if control is GraphNode:
			control.add_theme_font_override(&"title_font", bold_font)
		else:
			control.add_theme_font_override(&"font", bold_font)


static func apply_outline_node(node: GraphNode, accent_color: Color) -> void:
	apply_styled_node(node, accent_color, "")


static func create_header_strip() -> ColorRect:
	var strip: ColorRect = ColorRect.new()
	strip.name = "HeaderStrip"
	strip.color = HEADER_STRIP_COLOR
	strip.custom_minimum_size = Vector2(0.0, HEADER_STRIP_HEIGHT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return strip


static func create_meta_row(node_id: String, type_label: String, accent_color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MetaRow"
	row.add_theme_constant_override(&"separation", 8)

	var id_label: Label = Label.new()
	id_label.name = "IdLabel"
	id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_label.text = node_id
	apply_meta_id_label(id_label)

	var type_lbl: Label = Label.new()
	type_lbl.name = "TypeLabel"
	type_lbl.text = type_label.to_upper()
	apply_meta_type_label(type_lbl, accent_color)

	row.add_child(id_label)
	row.add_child(type_lbl)
	return row


static func create_display_label(name: String = "DisplayLabel") -> Label:
	var label: Label = Label.new()
	label.name = name
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


static func apply_meta_id_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", META_ID_COLOR)
	label.add_theme_font_size_override(&"font_size", META_FONT_SIZE)


static func apply_meta_type_label(label: Label, accent_color: Color) -> void:
	label.add_theme_color_override(&"font_color", accent_color)
	label.add_theme_font_size_override(&"font_size", META_FONT_SIZE)
	var bold: FontVariation = FontVariation.new()
	bold.base_font = get_display_font()
	bold.variation_opentype = { &"wght": 700 }
	label.add_theme_font_override(&"font", bold)


static func apply_display_body_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", DISPLAY_TEXT_COLOR)
	label.add_theme_font_size_override(&"font_size", DISPLAY_FONT_SIZE)
	label.add_theme_font_override(&"font", ThemeDB.fallback_font)


static func apply_display_character_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", DISPLAY_CHARACTER_COLOR)
	label.add_theme_font_size_override(&"font_size", DISPLAY_FONT_SIZE)
	label.add_theme_font_override(&"font", ThemeDB.fallback_font)


static func apply_display_muted_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", LABEL_MUTED_COLOR)
	label.add_theme_font_size_override(&"font_size", META_FONT_SIZE)


static func truncate_display_text(text: String, max_lines: int = 3) -> String:
	var lines: PackedStringArray = text.split("\n", false)
	if lines.size() <= max_lines:
		return text
	var result: PackedStringArray = PackedStringArray()
	for i: int in range(0, max_lines):
		result.append(lines[i])
	return "\n".join(result) + "..."


static func apply_field_background(field: Control) -> void:
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		var style: StyleBoxFlat = _make_field_stylebox()
		field.add_theme_stylebox_override(state, style)


static func _make_field_stylebox() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FIELD_BG_COLOR
	style.set_border_width_all(1)
	style.border_color = Color(0.16, 0.16, 0.18, 1.0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func apply_option_button(button: OptionButton) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 28.0
	button.add_theme_color_override(&"font_color", DISPLAY_TEXT_COLOR)
	button.add_theme_font_size_override(&"font_size", DISPLAY_FONT_SIZE)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, _make_field_stylebox())
	var hover_style: StyleBoxFlat = _make_field_stylebox()
	hover_style.bg_color = FIELD_BG_COLOR.lightened(0.08)
	hover_style.border_color = Color(0.24, 0.24, 0.28, 1.0)
	button.add_theme_stylebox_override(&"hover", hover_style)
	apply_popup_menu(button.get_popup())


static func apply_popup_menu(menu: PopupMenu) -> void:
	if menu == null:
		return
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.11, 0.11, 0.13, 1.0)
	panel.border_color = Color(0.22, 0.22, 0.26, 1.0)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.content_margin_left = 4
	panel.content_margin_right = 4
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	menu.add_theme_stylebox_override(&"panel", panel)
	menu.add_theme_color_override(&"font_color", DISPLAY_TEXT_COLOR)
	menu.add_theme_color_override(&"font_hover_color", Color.WHITE)
	menu.add_theme_color_override(&"font_accelerator_color", LABEL_MUTED_COLOR)
	menu.add_theme_font_size_override(&"font_size", DISPLAY_FONT_SIZE)
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.18, 0.22, 1.0)
	hover.set_corner_radius_all(2)
	menu.add_theme_stylebox_override(&"hover", hover)


static func apply_muted_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", LABEL_MUTED_COLOR)


static func apply_content_controls(root: Node) -> void:
	if root == null:
		return
	_apply_content_controls_recursive(root)


static func _apply_content_controls_recursive(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		if not label.name in [
			"IdLabel", "TypeLabel", "DisplaySpeakerNameLabel", "DisplayTextNameLabel",
			"DisplayExpressionNameLabel", "DisplayCharacterLabel", "DisplayBodyLabel",
			"DisplayExpressionLabel", "DisplayBlockingLabel", "TitleLabel", "ResponseDisplayLabel",
			"ResponseNumberLabel", "SpeakerLabel", "TextLabel", "GotoTargetLabel",
		]:
			apply_muted_label(label)
	elif node is LineEdit:
		apply_field_background(node as LineEdit)
	elif node is TextEdit:
		apply_field_background(node as TextEdit)
	elif node is OptionButton:
		apply_option_button(node as OptionButton)
	for child: Node in node.get_children():
		_apply_content_controls_recursive(child)
