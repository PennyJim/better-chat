data:extend{
	{
		type = "int-setting",
		name = "bc-global-chat-history",
		setting_type = "runtime-global",
		default_value = 500,
		minimum_value = 1,
		order = "global-a"
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
	},
}

data:extend{
	{
		type = "double-setting",
		name = "bc-color-fade",
		setting_type = "runtime-per-user",
		default_value = 0.8,
		minimum_value = 0,
		maximum_value = 1,
		order = "player-aa"
	},
	{
		type = "bool-setting",
		name = "bc-show-timestamp",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "player-ab",
	}
}

---NOTE: is a mirror of the table over in `handle_messages`
local icon_types = {
	["virtual-signal"] = true,
	["item"] = true,
	["fluid"] = true,
	["entity"] = true,
	["recipe"] = false,
	["technology"] = false,
	["space-location"] = false,
	["achievement"] = false,
	["item-group"] = false,
	["tile"] = false,
}

local order_index = 0
for icon, default in pairs(icon_types) do
	data:extend{
		{
			type = "bool-setting",
			name = "bc-"..icon.."-icon",
			setting_type = "runtime-per-user",
			default_value = default,
			order = "player-b"..order_index
		}
	}
	order_index = order_index + 1
end