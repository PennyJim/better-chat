data:extend{
	{
		type = "custom-input",
		name = "bc-toggle-chat",
		key_sequence = "",
		linked_game_control = "toggle-console",
		action = "lua",
	},
	{
		type = "custom-input",
		name = "bc-exit-chat",
		key_sequence = "",
		linked_game_control = "toggle-menu",
		action = "lua",
	},
	{
		type = "shortcut",
		name = "bc-open-chatlog",
		action = "lua",
		toggleable = true,
		icons = {util.empty_icon()},
		small_icons = {util.empty_icon()},
	}--[[@as data.ShortcutPrototype]],
	{
		type = "custom-event",
		name = "better-chat-message",
	}
}