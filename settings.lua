data:extend{
	{
		type = "int-setting",
		name = "bc-global-chat-history",
		setting_type = "runtime-global",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "global-aa"
	},
	{
		type = "int-setting",
		name = "bc-force-chat-history",
		setting_type = "runtime-global",
		default_value = 64,
		minimum_value = 1,
		order = "global-ab"
	},
	-- {
	-- 	type = "double-setting",
	-- 	name = "bc-duplicate-timer",
	-- 	setting_type = "runtime-global",
	-- 	default_value = 1.0,
	-- 	minimum_value = 0.1,
	-- 	maximum_value = 10.0,
	--  order = "global-ba"
	-- },
}
data:extend{
	{
		type = "double-setting",
		name = "bc-color-fade",
		setting_type = "runtime-per-user",
		default_value = 0,
		minimum_value = 0,
		maximum_value = 1,
		order = "player-aa"
	},
	{
		type = "int-setting",
		name = "bc-player-chat-history",
		setting_type = "runtime-per-user",
		default_value = 36,
		minimum_value = 1,
		maximum_value = 64,
		order = "player-ba"
	},
	{
		type = "bool-setting",
		name = "bc-virtual-signal-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-da"
	},
	{
		type = "bool-setting",
		name = "bc-item-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-db"
	},
	{
		type = "bool-setting",
		name = "bc-fluid-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-dc"
	},
	{
		type = "bool-setting",
		name = "bc-entity-icon",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "player-dd"
	},
	{
		type = "bool-setting",
		name = "bc-recipe-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-de"
	},
	{
		type = "bool-setting",
		name = "bc-technology-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-df"
	},
	{
		type = "bool-setting",
		name = "bc-achievement-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-dg"
	},
	{
		type = "bool-setting",
		name = "bc-item-group-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-dh"
	},
	{
		type = "bool-setting",
		name = "bc-tile-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-di"
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
		order = "player-fa"
	},
	{
		type = "color-setting",
		name = "bc-error-color",
		setting_type = "runtime-per-user",
		default_value = {1,0,0},
		order = "player-fb"
	},
	{
		type = "color-setting",
		name = "bc-warn-color",
		setting_type = "runtime-per-user",
		default_value = {1,1,0},
		order = "player-fc"
	},
	{
		type = "color-setting",
		name = "bc-debug-color",
		setting_type = "runtime-per-user",
		default_value = {0.3,0.3,0.3},
		order = "player-fd"
	}
}