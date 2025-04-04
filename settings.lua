local global_module_add = module_add
local function module_add(name)
	return global_module_add(name, "__better-chat__.modules."..name)
end


data:extend{
	module_add("chat_log_entry"),
	{
		type = "int-setting",
		name = "bc-global-chat-history",
		setting_type = "runtime-global",
		default_value = 500,
		minimum_value = 1,
		order = "global-aa"
	},
	{
		type = "string-setting",
		name = "bc-normal-chat-type",
		setting_type = "runtime-global",
		default_value = "force",
		allowed_values = {
			"force",
			"global",
			"player",
			"surface",
		},
		order = "global-b"
	}
	-- {
	-- 	type = "double-setting",
	-- 	name = "bc-duplicate-timer",
	-- 	setting_type = "runtime-global",
	-- 	default_value = 1.0,
	-- 	minimum_value = 0.1,
	-- 	maximum_value = 10.0,
	--  order = "global-c"
	-- },
}
data:extend{
  {
    type = "bool-setting",
    name = "bc-player-closeable-chat",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "player-aa",
  },
	{
		type = "double-setting",
		name = "bc-color-fade",
		setting_type = "runtime-per-user",
		default_value = 0.8,
		minimum_value = 0,
		maximum_value = 1,
		order = "player-ab",
	},
	{
		type = "bool-setting",
		name = "bc-show-timestamp",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-ac",
	},
	-- { -- Now it's hardcoded to 36 for printing
	-- 	type = "int-setting",
	-- 	name = "bc-player-chat-history",
	-- 	setting_type = "runtime-per-user",
	-- 	default_value = 36,
	-- 	minimum_value = 1,
	-- 	maximum_value = 64,
	-- 	order = "player-ba"
	-- },
	{
		type = "double-setting",
		name = "bc-message-linger",
		setting_type = "runtime-per-user",
		default_value = 20,
		minimum_value = 0,
		maximum_value = 100,
		order = "player-ca"
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
		name = "bc-space-location-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-dg"
	},
	{
		type = "bool-setting",
		name = "bc-achievement-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-dh"
	},
	{
		type = "bool-setting",
		name = "bc-item-group-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-di"
	},
	{
		type = "bool-setting",
		name = "bc-tile-icon",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-dj"
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