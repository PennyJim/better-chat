local gui = require("__gui-modules__.gui")

--MARK: Functions

---@param state modules.WindowState
---@param chat Chat
local function add_chat(state, chat)
	local list = state.elems["chat-flow"]
	state.gui.add(state.namespace, list, {
		type = "module", module_type = "chat_log_entry",
		chat = chat, name = tostring(chat.chat_id),
		player = state.player, expand_badges = true,
	}, true)
	state.elems["chat-scroll"].scroll_to_bottom()
end

---@param state modules.WindowState
---@param chat_id uint
local function remove_chat(state, chat_id)
	local chat_identifier = tostring(chat_id)
	state.elems[chat_identifier].destroy()
	state.elems[chat_identifier] = nil
end

---@param state modules.WindowState
local function clear_chat(state)
	local list = state.elems["chat-flow"]
	local names = list.children_names
	list.clear()
	for _, name in pairs(names) do
		state.elems[name] = nil
	end
end

--MARK: Definition

gui.new({
	window_def = {
		shortcut = "bc-open-chatlog",
		namespace = "better-chat",
		version = 0,
		root = "screen",
		definition = {
			type = "module", module_type = "window_frame",
			name = "better-chat", title = {"better-chat.window-title"},
			has_close_button = true, has_pin_button = true,
			children = {{
				type = "scroll-pane", name = "chat-scroll",
				horizontal_scroll_policy = "never",
				vertical_scroll_policy = "always",
				children = {{
					type = "flow", name = "chat-flow",
					direction = "vertical"
				}}
			}}
		}--[[@as WindowFrameParams]]
	},
	handlers = {
		
	},
	state_setup = function (state)
		local log = storage.master_log
		if not log then return end -- No messages yet
		local player = state.player

		---@type ChatLog.filter
		local filter
		if player.admin then
			filter = {}
		else
			filter = {
				player_index = player.index,
				force_index = player.force_index,
			}
		end

		for _, chat in log:filter(filter) do
			add_chat(state, chat)
		end
	end
}--[[@as newWindowParams]])

--MARK: Interface

---@class BetterChatInterface : custom_event_handler
local chat_interface = {}

chat_interface.commands = {
	chat = function ()
		-- Open chat somehow... How the fuck do I not have a way to open it via script?
	end
}

---@param player_index uint
---@param chat Chat
function chat_interface.add_chat(player_index, chat)
	add_chat(gui.get_state("better-chat", player_index), chat)
end

---@param chat_identifier uint
function chat_interface.remove_chat(chat_identifier)
	for index in pairs(game.players) do
		---@cast index uint
		remove_chat(gui.get_state("better-chat", index), chat_identifier)
	end
end

-- function chat_interface.clear_chat(player_index)
-- 	clear_chat(gui.get_state("better-chat", player_index))
-- end

return chat_interface