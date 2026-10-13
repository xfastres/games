class_name UiFont
extends RefCounted

static func make() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"SimSun",
		"Segoe UI",
	])
	return font
