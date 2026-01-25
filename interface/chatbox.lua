local glib = require("__glib__.glib")
local handlers = {}

---@class chatbox : event_handler
local chatbox = {events = {}} --[[@as event_handler]]

---@class chatbox_state
---@field player LuaPlayer
---@field root LuaGuiElement
---@field chatlist LuaGuiElement
---@field is_healthy boolean To see if 
---@field refs table<string,LuaGuiElement>

---@param player LuaPlayer
---@param is_healthy boolean?
---@return int height
local function calculate_box_height(player, is_healthy)
	local active_quickbars = 3
	local height = player.display_resolution.height
	local scale = player.display_scale
	local scaled_height = height/scale
	local distance_to_bottom = 40 * active_quickbars + 52
	if not is_healthy then
		distance_to_bottom = distance_to_bottom + 13
	end
	return scaled_height - distance_to_bottom
end

---@param player LuaPlayer
local function create_state(player)
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
			height = calculate_box_height(player, true),
			maximal_width = player.display_resolution.width/player.display_scale
		},
		elem_mods = {
			location = {0, 0} -- Properly math it out
		}
	})

	---@type chatbox_state
	local state = {
		player = player,
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
	state.chatlist.style.height = calculate_box_height(state.player, state.is_healthy)
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

---Formats the given tick in D+:HH:MM:SS
---@param tick int
---@return string
local function format_time(tick)
	---@type int, int, int, int
	local seconds, minutes, hours, days
	seconds = tick / 60
	minutes, seconds = math.floor(seconds / 60), seconds % 60
	hours, minutes = math.floor(minutes / 60), minutes % 60
	days, hours = math.floor(hours / 24), hours % 24

	if days > 0 then
		return string.format("%d:%02d:%02d.%02d", days, hours, minutes, seconds)
	elseif hours > 0 then
		return string.format("%d:%02d.%02d", hours, minutes, seconds)
	else
		return string.format("%d.%02d", minutes, seconds)
	end
end

---@param player ChatPlayer?
local function format_player(player)
	if not player then return "" end
	local color = player.color
	return {"",
		"[color="
			..color.r..","
			..color.g..","
			..color.b
		.."]",
		player.name,
		"[/color]"
	}
end

---@param chat Chat
function chatbox.add_message(player, chat)
	local state = get_state(player.index)
	local elem = glib.add(state.chatlist, {
		args = {type = "label", caption = {"",
			format_time(chat.tick) .. " | "..
			chat.type .. " - ",
			format_player(chat.sender), ": ",
			chat.message
		}},
		style_mods = {
			font_color = chat.color,
			font = "default-game",
			single_line = false,
		}
	}, state.refs)
	state.chatlist.scroll_to_bottom()
end

return chatbox