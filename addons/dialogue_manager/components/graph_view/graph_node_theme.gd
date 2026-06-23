## Shared title styling for graph editor nodes.
class_name DMGraphNodeTheme extends RefCounted


const TITLE_FONT_SIZE: int = 18
const LABEL_MUTED_COLOR: Color = Color(0.52, 0.52, 0.56, 1.0)
const FIELD_BG_COLOR: Color = Color(0.08, 0.08, 0.1, 1.0)
const PORT_COLOR: Color = Color(0.65, 0.78, 0.98, 1.0)
const CONNECTION_COLOR: Color = Color(0.65, 0.78, 0.98, 1.0)
const NODE_BOTTOM_MARGIN: float = 20.0
const CONNECTION_CURVATURE: int = 35


static func apply_title(node: GraphNode, bg_color: Color) -> void:
	var style: StyleBoxFlat = _make_title_stylebox(bg_color)
	node.add_theme_color_override(&"title_color", Color.WHITE)
	node.add_theme_stylebox_override(&"titlebar", style)
	node.add_theme_font_size_override(&"title_font_size", TITLE_FONT_SIZE)
	_apply_bold_title_font(node)


static func apply_compact(node: GraphNode, bg_color: Color) -> void:
	var empty_title: StyleBoxEmpty = StyleBoxEmpty.new()
	node.add_theme_stylebox_override(&"titlebar", empty_title)
	node.add_theme_constant_override(&"separation", 0)
	node.title = ""

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.set_corner_radius_all(4)
	panel_style.set_border_width_all(0)
	panel_style.set_content_margin_all(8)
	node.add_theme_stylebox_override(&"panel", panel_style)


static func apply_compact_panel(panel: PanelContainer, bg_color: Color) -> void:
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
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func _apply_bold_title_font(node: GraphNode) -> void:
	_apply_bold_title_font_to_control(node, 800)


static func _apply_bold_title_font_to_control(control: Control, weight: int = 800) -> void:
	var base_font: Font = control.get_theme_font(&"title_font", &"GraphNode")
	if base_font == null and control is GraphNode:
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


static func apply_field_background(field: Control) -> void:
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = FIELD_BG_COLOR
		style.set_border_width_all(1)
		style.border_color = Color(0.16, 0.16, 0.18, 1.0)
		style.set_corner_radius_all(2)
		style.set_content_margin_all(4)
		field.add_theme_stylebox_override(state, style)


static func apply_muted_label(label: Label) -> void:
	label.add_theme_color_override(&"font_color", LABEL_MUTED_COLOR)


static func apply_content_controls(root: Node) -> void:
	if root == null:
		return
	_apply_content_controls_recursive(root)


static func _apply_content_controls_recursive(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		if label.name != "TitleLabel":
			apply_muted_label(label)
	elif node is LineEdit:
		apply_field_background(node as LineEdit)
	elif node is TextEdit:
		apply_field_background(node as TextEdit)
	for child: Node in node.get_children():
		_apply_content_controls_recursive(child)
