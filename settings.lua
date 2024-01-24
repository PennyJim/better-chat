data:extend{
	{
		type = "int-setting",
		name = "bc-global-chat-history",
		setting_type = "runtime-global",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "global-a-history-a"
	},
	{
		type = "int-setting",
		name = "bc-force-chat-history",
		setting_type = "runtime-global",
		default_value = 64,
		minimum_value = 1,
		order = "global-a-history-b"
	},
	-- {
	-- 	type = "double-setting",
	-- 	name = "bc-duplicate-timer",
	-- 	setting_type = "runtime-global",
	-- 	default_value = 1.0,
	-- 	minimum_value = 0.1,
	-- 	maximum_value = 10.0,
	--  order = "global-a-??-b"
	-- },
}
data:extend{{
		type = "int-setting",
		name = "bc-player-chat-history",
		setting_type = "runtime-per-user",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "player-a-history-c"
	},
	{
		type = "bool-setting",
		name = "bc-virtual-signal-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-b-icons-a"
	},
	{
		type = "bool-setting",
		name = "bc-item-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-b-icons-b"
	},
	{
		type = "bool-setting",
		name = "bc-fluid-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-b-icons-c"
	},
	{
		type = "bool-setting",
		name = "bc-entity-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-b-icons-d"
	},
	{
		type = "bool-setting",
		name = "bc-recipe-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-b-icons-e"
	},
	{
		type = "bool-setting",
		name = "bc-technology-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-b-icons-f"
	},
	{
		type = "bool-setting",
		name = "bc-achievement-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-b-icons-g"
	},
	{
		type = "bool-setting",
		name = "bc-item-group-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-b-icons-h"
	},
	{
		type = "bool-setting",
		name = "bc-tile-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-b-icons-i"
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
		type = "double-setting",
		name = "bc-color-fade",
		setting_type = "runtime-per-user",
		default_value = 0,
		minimum_value = 0,
		maximum_value = 1,
		order = "player-z-color-a"
	},
	{
		type = "color-setting",
		name = "bc-default-color",
		setting_type = "runtime-per-user",
		default_value = {1,1,1},
		order = "player-z-color-b"
	},
	{
		type = "color-setting",
		name = "bc-error-color",
		setting_type = "runtime-per-user",
		default_value = {1,0,0},
		order = "player-z-color-c"
	},
	{
		type = "color-setting",
		name = "bc-warn-color",
		setting_type = "runtime-per-user",
		default_value = {1,1,0},
		order = "player-z-color-d"
	},
	{
		type = "color-setting",
		name = "bc-debug-color",
		setting_type = "runtime-per-user",
		default_value = {0.3,0.3,0.3},
		order = "player-z-color-e"
	}
}