local glib = require("__glib__.glib")
local formater = require("formatter")
local handlers = {}

---@class chatbox : event_handler
local chatbox = {events = {}} --[[@as event_handler]]

---@class chatbox_state
---@field player LuaPlayer
---@field format_settings ChatFormatSettngs
---@field root LuaGuiElement
---@field chatlist LuaGuiElement
---@field is_healthy boolean To see if 
---@field refs table<string,LuaGuiElement>

---@param player LuaPlayer
---@param is_healthy boolean
---@return int height
---@return int width
local function calculate_box_size(player, is_healthy)
	local active_quickbars = 2 -- TODO, make a setting
	local resolution = player.display_resolution
	local scale = player.display_scale

	local height = resolution.height
	local scaled_height = height/scale
	local distance_to_bottom = 40 * active_quickbars + 52
	if not is_healthy then
		distance_to_bottom = distance_to_bottom + 13
	end
	local box_height = scaled_height - distance_to_bottom

	local width = resolution.width
	local scaled_width = width/scale
	local midpoint = scaled_width / 2
	local box_width = midpoint + 358

	return box_height, box_width
end

---@param player LuaPlayer
local function create_state(player)
	local box_height, box_width = calculate_box_size(player, true)
	local root, refs = glib.add(player.gui.screen, {
		args = {
			name = "chatlist",
			type = "scroll-pane", style = "bc_chat_scroll_pane",
			direction = "vertical", raise_hover_events = true,
			horizontal_scroll_policy = "never",
			-- ignored_by_interaction = true,
		},
		-- _hover = handlers.test,
		style_mods = {
			height = box_height,
			width = box_width,
		},
		elem_mods = {
			location = {0, 0} -- Properly math it out
		}
	})

	---@type chatbox_state
	local state = {
		player = player,
		format_settings = formater.fetch_settings(player.mod_settings),
		root = root,
		refs = refs,
		chatlist = refs.chatlist,
		is_healthy = true,
	}
	storage.chatbox_states[player.index] = state
	return state
end

function handlers.test()
	game.print("test")
end

---@param index uint
---@return chatbox_state
local function get_state(index)
	local state = storage.chatbox_states[index]
	if state then return state end

	local player = game.get_player(index)
	if not player then error("Given index is not of a valid player") end
	return create_state(player)
end

glib.register_handlers(handlers, function (event, handler)
	handler(get_state(event.player_index), event)
end)

function chatbox.on_init()
	---@type chatbox_state[]
	storage.chatbox_states = {}
	for _, player in pairs(game.players) do
		create_state(player)
	end
end

chatbox.events[defines.events.on_player_created] = function (event)
	create_state(game.get_player(event.player_index)--[[@as LuaPlayer]])
end
chatbox.events[defines.events.on_player_removed] = function (event)
	storage.chatbox_states[event.player_index] = nil
end

---@param state chatbox_state|EventData.on_player_display_resolution_changed|EventData.on_player_display_scale_changed
local function update_height(state)
	if not state.chatlist then state = get_state(state.player_index) end
	local style = state.chatlist.style
	style.height, style.width = calculate_box_size(state.player, state.is_healthy)
end
chatbox.events[defines.events.on_player_display_resolution_changed] = update_height
chatbox.events[defines.events.on_player_display_scale_changed] = update_height
chatbox.events[defines.events.on_tick] = function (event)
	for _, player in pairs(game.players) do
		local state = get_state(player.index)
		local character = player.character

		local is_healthy = true
		if character then
			is_healthy = character.get_health_ratio() == 1
		end

		if state.is_healthy ~= is_healthy then
			state.is_healthy = is_healthy
			update_height(state)
		end
	end
end

chatbox.events[defines.events.on_runtime_mod_setting_changed] = function (event)
	local state = get_state(event.player_index)
	state.format_settings = formater.fetch_settings(state.player.mod_settings)
end

---@param player_index uint
function chatbox.clear(player_index)
	local state = get_state(player_index)
	state.chatlist.clear();
end

---@param chat Chat
function chatbox.add_message(player, chat)
	local state = get_state(player.index)
	local settings = state.format_settings

	local base_color = chat.color
	if base_color and chat.process_color then
		base_color = formater.process_color(settings, base_color)
	end

	---@type StyleMods
	local generic_style_mods
	if base_color then
		generic_style_mods = {
			font_color = base_color
		}
	end

	---@type GuiElemDef[]
	local message, index = {}, 0

	if settings.show_time then
		index = index + 1
		message[index] = {
			args = {
				type = "label", style = "bc_chat_prefix_label",
				caption = formater.time(chat.tick)
			},
			style_mods = generic_style_mods
		}
	end

	index = index + 1
	message[index] = {
		args = {
			type = "progressbar", style = "bc_chat_badge_progressbar",
			caption = chat.type, value = 1,
		},
		style_mods = {
			color = chat.color
		}
	}

	if chat.sender then
		index = index + 1
		message[index] = {
			args = {
				type = "label", style = "bc_chat_prefix_label",
				caption = formater.chat_player(chat.sender, ": "),
			},
			style_mods = generic_style_mods,
		}
	end

	index = index + 1
	message[index] = {
		args = {
			type = "label", style = "bc_chat_message_label",
			caption = chat.message
		},
		style_mods = generic_style_mods,
	}

	local elem = glib.add(state.chatlist, {
		args = {
			type = "flow", style = "packed_horizontal_flow",
			direction ="horizontal",
		},
		children = message
	}, state.refs)
	state.chatlist.scroll_to_bottom()
end

return chatbox