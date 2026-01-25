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