local interface = require("__better-chat__.runtime.ChatInterface")
local chatlog = require("__better-chat__.runtime.ChatLog")
local printer = require("__better-chat__.runtime.ChatPrinter")

---MARK: Manager

---@class ChatLogManager : custom_event_handler
local manager = {events = {}--[[@as event_handler.events]], remote_interfaces = {}--[[@as custom_event_handler.remote_interfaces]]}

---@param player_index uint
local function build_player_log(player_index)
	local player = game.get_player(player_index)
	---@cast player -?
	if storage.player_logs[player_index] then return log("Player already had a log. '"..player.name.."' at "..player_index) end
	storage.player_logs[player_index] = chatlog.new(storage.master_log, player)
end
---Adds a new chatlog for player_index if it didn't exist before
manager.events[defines.events.on_player_created] = function (event)
	build_player_log(event.player_index)
end

---Removes a chatlog for deleted force
manager.events[defines.events.on_forces_merged] = function (event)
	-- TODO: Make this a setting, and possibly just *remove* those chats?
	local destination_index = event.destination.index
	for _, chat in storage.master_log:filter{
		force_index = event.source_index,
		type = {force = true}
	} do
		chat.recipient_index = destination_index
	end
end
---Removes a chatlog for removed player
manager.events[defines.events.on_player_removed] = function (event)
	local player_index = event.player_index
	storage.player_logs[player_index] = nil

	--- Remove references to this player's index
	local log = storage.master_log
	for chat_id, chat in log:from() do
		---@cast chat Chat.whisper|Chat.player
		if chat.type == "whisper"
		or chat.type == "player" then
			if chat.recipient.index == player_index then
				log:remove(chat_id)
			end
		end

		if chat.sender and chat.sender.index == player_index then
			chat.sender.index = nil
		end
	end
end

---Empties the print log for the given player
---Messages will still be visible in the chat history
---@param player_index int
manager.clear = function (player_index)
	storage.player_logs[player_index] = chatlog.new()
end

---@class ChatParams.base
---@field message LocalisedString
---@field sender? ChatPlayer
---@field color? Color
---@field process_color? boolean

---@class ChatParams.global
---@field type "global"|"command"
---@field recipient nil

---@class ChatParams.force_surface : ChatParams.base
---@field type "force"|"surface"
---@field recipient_index uint

---@class ChatParams.player : ChatParams.base
---@field type "player"
---@field recipient ChatPlayer

---@class ChatParams.whisper : ChatParams.base
---@field type "whisper"
---@field sender ChatPlayer
---@field recipient ChatPlayer

---@alias ChatParams 
---| ChatParams.global
---| ChatParams.force_surface
---| ChatParams.player
---| ChatParams.whisper
---Adds a message to chat history
---@param tentative_chat ChatParams
manager.add_message = function(tentative_chat)
	---@type Chat
	local new_chat = {
		chat_id = storage.master_log.last_index + 1,
		tick = game.ticks_played,

		type = tentative_chat.type,
		message = tentative_chat.message,
		sender = tentative_chat.sender,
		color = tentative_chat.color,
		process_color = tentative_chat.process_color,
	}

	if new_chat.type == "surface" then
		local surface_index = tentative_chat.recipient_index
		new_chat.recipient_index = surface_index
		---@type uint[]
		local list, count = {}, 0
		new_chat.recipients = list

		for index, player in pairs(game.players) do
			---@cast index uint
			if surface_index == player.surface_index then
				count = count + 1
				list[count] = index
			end
		end

	elseif new_chat.type == "force" then
		local force_index = tentative_chat.recipient_index
		new_chat.recipient_index = force_index
		---@type uint[]
		local list, count = {}, 0
		new_chat.recipients = list

		for _, player in pairs(game.forces[force_index].players) do
			count = count + 1
			list[count] = player.index
		end

	elseif new_chat.type == "player" then
		new_chat.recipient = tentative_chat.recipient

	elseif new_chat.type == "whisper" then
		if not new_chat.sender then error("Whisper has no sender") end
		local recipient = tentative_chat.recipient
		if not recipient then error("Whisper has no recipient") end
		new_chat.recipient = recipient
	end


	storage.master_log:add(new_chat, settings.global["bc-global-chat-history"].value--[[@as int]],
		interface.remove_chat
	)

	for player_index, player in pairs(game.players) do
		---@cast player_index uint
		interface.add_chat(player_index, new_chat)
		
		local force_index = player.force_index
		if chatlog.passes_filter(new_chat, {
			player_index = player_index,
			force_index = force_index
		}) then
			-- Only add to it if it was already built
			-- It should be automatically added when building it
			local player_log = storage.player_logs[player_index]
			if player_log then
				player_log:add(new_chat, 36)
			else
				build_player_log(player_index)
			end
		end
	end
end

manager.events[defines.events.on_runtime_mod_setting_changed] = function (event)
  local setting = event.setting
  if event.setting_type == "runtime-global" then
    if setting == "bc-global-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      manager.add_message{
				type = "global",
        message = {
					"chat-localization.bc-global-history-changed",
					settings.global[setting].value
				}
      }
      printer.print_chat("global")
    end
  else
    local player_index = event.player_index
    if not player_index then return log("Who changed their setting???") end
    if setting == "bc-player-closeable-chat" then
      -- Clear opened value when closeable is disabled
      -- Also does it when enabled, but they should just be in main menu
      storage.isChatOpen[player_index--[[@as int]]] = nil
      -- Update chat to now match the openness it Should be now
      printer.print_chat("player", player_index)
    elseif (
      setting == "bc-color-fade" or
      setting == "bc-default-color" or
      setting == "bc-error-color" or
      setting == "bc-warn-color" or
      setting == "bc-debug-color"
    ) then
      -- Reprint chat to update the the printed chat
      printer.print_chat("player", player_index)
    end
  end
end

---@class BetterChatStorage
---@field master_log ChatLog
---@field player_logs table<int, ChatLog>

---Initializes Chat History
manager.on_init = function()
	local master_log = chatlog.new()
	storage.master_log = master_log
	storage.player_logs = {}
	for _, player in pairs(game.players) do
		local player_index = player.index
		storage.player_logs[player_index] = chatlog.new();
	end
end

manager.remote_interfaces["better-chat"] = {
	clear = manager.clear
}

return manager