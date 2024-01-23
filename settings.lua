data:extend{
	{
		type = "int-setting",
		name = "bc-global-chat-history",
		setting_type = "runtime-global",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "history-a"
	},
	{
		type = "int-setting",
		name = "bc-force-chat-history",
		setting_type = "runtime-global",
		default_value = 64,
		minimum_value = 1,
		order = "a-history-b"
	},
	{
		type = "int-setting",
		name = "bc-player-chat-history",
		setting_type = "runtime-per-user",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "a-history-c"
	},
	-- {
	-- 	type = "double-setting",
	-- 	name = "bc-duplicate-timer",
	-- 	setting_type = "runtime-global",
	-- 	default_value = 1.0,
	-- 	minimum_value = 0.1,
	-- 	maximum_value = 10.0
	-- },
	{
		type = "bool-setting",
		name = "bc-virtual-signal-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "b-icons-a"
	},
	{
		type = "bool-setting",
		name = "bc-item-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "b-icons-b"
	},
	{
		type = "bool-setting",
		name = "bc-fluid-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "b-icons-c"
	},
	{
		type = "bool-setting",
		name = "bc-entity-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "b-icons-d"
	},
	{
		type = "bool-setting",
		name = "bc-recipe-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b-icons-e"
	},
	{
		type = "bool-setting",
		name = "bc-technology-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b-icons-f"
	},
	{
		type = "bool-setting",
		name = "bc-achievement-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b-icons-g"
	},
	{
		type = "bool-setting",
		name = "bc-item-group-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b-icons-h"
	},
	{
		type = "bool-setting",
		name = "bc-tile-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b-icons-i"
	},
	-- { -- Changed my mind about a dropdown list, but not completely
	-- 	type = "string-setting",
	-- 	name = "bc-icon-replacement",
	-- 	setting_type = "runtime-per-user",
	-- 	default_value = "",
	-- 	allowed_values = {
	-- 		"bc-icon-none",
	-- 		"bc-icon-signals",
	-- 		"bc-icon-items",
	-- 		"bc-icon-entities",
	-- 		-- "bc-icon-almost-everything",
	-- 		-- "bc-icon-everything",
	-- 	}
	-- },
	{
		type = "color-setting",
		name = "bc-default-color",
		setting_type = "runtime-per-user",
		default_value = {1,1,1},
		order = "z-color-a"
	},
	{
		type = "color-setting",
		name = "bc-warn-color",
		setting_type = "runtime-per-user",
		default_value = {1,1,0},
		order = "z-color-c"
	}
}