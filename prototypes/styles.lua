--TODO: make some elegant scrollbar

local gui_styles = data.raw["gui-style"]["default"]


gui_styles.bc_chat_scroll_pane = {
	type = "scroll_pane_style",
	parent = "naked_scroll_pane",
	vertical_flow_style = {
		type = "vertical_flow_style",
		vertical_align = "bottom",
		vertical_spacing = 0
	}
}

gui_styles.bc_chat_prefix_label = {
	type = "label_style",
	font = "default-game",
	horizontally_squashable = "off",
}

gui_styles.bc_chat_message_label = {
	type = "label_style",
	font = "default-game",
	single_line = false,
}

gui_styles.bc_chat_badge_progressbar = {
	type = "progressbar_style",
	bar_width = 28,
	size = {108, 28},
	font = "default-semibold",
	color = {1,1,1,},
	bar = {
		base = { position = {0, 17}, corner_size = 8},
---@diagnostic disable-next-line: undefined-global, no-unknown
		shadow = default_dirt,
	},
	bar_background = {},
	side_text_padding = 0,
	horizontal_align = "center",
	vertical_align = "center",

	padding = 0,
	left_margin = 4,
	right_margin = 4,
}