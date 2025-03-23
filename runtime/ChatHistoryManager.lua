local interface = require("__better-chat__.runtime.ChatInterface")
local newChatLog = require("__better-chat__.runtime.ChatLog")
local printer = require("__better-chat__.runtime.ChatPrinter")

---MARK: Manager

---@alias historyLevel "global"|"force"|"player"|"surface"
---@class ChatLogManager : custom_event_handler
local manager = {events = {}--[[@as event_handler.events]], remote_interfaces = {}--[[@as custom_event_handler.remote_interfaces]]}

---Adds a new chatlog for force_index if it didn't exist before
manager.events[defines.events.on_force_created] = function (event)
	local force_index = event.force.index
	if storage.ForceChatLog[force_index] then return end
	storage.ForceChatLog[force_index] = newChatLog(
		storage.GlobalChatLog, "force"
	)
end
---Adds a new chatlog for player_index if it didn't exist before
manager.events[defines.events.on_player_created] = function (event)
	local player_index = event.player_index
	if storage.PlayerChatLog[player_index] then return end
	storage.PlayerChatLog[player_index] = newChatLog(
		storage.ForceChatLog[game.get_player(player_index).force_index],
		"player", player_index
	)
end

---Removes a chatlog for deleted force
manager.events[defines.events.on_forces_merged] = function (event)
	storage.ForceChatLog[event.source_index] = nil
end
---Removes a chatlog for removed player
manager.events[defines.events.on_player_removed] = function (event)
	storage.PlayerChatLog[event.player_index] = nil
end

--Empties the ChatLog for the given player
---@param player_index int
manager.clear = function (player_index)
	storage.PlayerChatLog[player_index] = newChatLog()
	interface.clear_chat(player_index)
end

---@param player_index uint
---@param newChat Chat
local function add_to_player_log(player_index, newChat)
	local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as int]]
	local log = storage.PlayerChatLog[player_index]

	log:add(newChat, player_chat_history, function (index)
		interface.remove_chat(player_index, tostring(index))
	end)
	interface.add_chat(player_index, newChat, tostring(log.last_index))
end

---@class addMessageParams
---@field message LocalisedString
---@field color Color?
---@field process_color boolean?
---@field level historyLevel
---@field chat_index int?
---Adds a message to chat history
---@param messageParams addMessageParams
manager.add_message = function(messageParams)
	---@type Chat
	local newChat = {
		message = messageParams.message,
		color = messageParams.color,
		process_color = messageParams.process_color,
		tick = game.ticks_played
	}

	if messageParams.level =="global" then
		-- Add message to global chat, every force, and every player
		storage.GlobalChatLog:add(newChat, settings.global["bc-global-chat-history"].value--[[@as int]])

		local force_chat_history = settings.global["bc-force-chat-history"].value--[[@as int]]
		for _,force in pairs(game.forces) do
			storage.ForceChatLog[force.index]:add(newChat, force_chat_history)
		end

		for player_index in pairs(game.players) do
			---@cast player_index uint
			add_to_player_log(player_index, newChat)
		end


	elseif messageParams.level == "force" then
		local force_index = messageParams.chat_index --[[@as int]]
		-- Add message to the force and players in the force
		storage.ForceChatLog[force_index]
			:add(newChat, settings.global["bc-force-chat-history"].value--[[@as int]])

		for _,player in pairs(game.forces[force_index].players) do
			add_to_player_log(player.index, newChat)
		end


	elseif messageParams.level == "surface" then
		local surface_index = messageParams.chat_index --[[@as int]]
		-- Add message to each player on the surface
		for player_index, player in pairs(game.players) do
			---@cast player_index uint
			if player.surface_index == surface_index then
				add_to_player_log(player_index, newChat)
			end
		end


	elseif messageParams.level == "player" then
		-- Add message to the player
		add_to_player_log(messageParams.chat_index, newChat)


	else
		log({"", {"bc-invalid-chat-level"}, serpent.line(messageParams), "\n"})
	end
end

manager.events[defines.events.on_runtime_mod_setting_changed] = function (event)
  local setting = event.setting
  if event.setting_type == "runtime-global" then
    if setting == "bc-global-chat-history"
    or setting == "bc-force-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      local message = setting == "bc-global-chat-history" and
        "chat-localization.bc-global-history-changed" or "chat-localization.bc-force-history-changed"
      local new_setting = settings.global[setting].value
      send_message{
        message = {message, new_setting},
        send_level = "global"
      }
      printer.print_chat("global")
    end
  else
    local player_index = event.player_index
    if not player_index then return log("Who changed their setting???") end
    if setting == "bc-player-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      local new_setting = settings.get_player_settings(player_index)[setting].value
      send_message{
        message = {"chat-localization.bc-player-history-changed", new_setting},
        send_level = "player",
        recipient = player_index
      }
      printer.print_chat("player", player_index)
    elseif setting == "bc-player-closeable-chat" then
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
---@field GlobalChatLog ChatLog
---@field ForceChatLog table<int, ChatLog>
---@field PlayerChatLog table<int, ChatLog>

---Initializes Chat History
manager.on_init = function()
	storage.GlobalChatLog = newChatLog();
	storage.ForceChatLog = {}
	for _,force in pairs(game.forces) do
		storage.ForceChatLog[force.index] = newChatLog();
	end
	storage.PlayerChatLog = {}
	for _, player in pairs(game.players) do
		local player_index = player.index
		storage.PlayerChatLog[player_index] = newChatLog();
	end
end

manager.remote_interfaces["better-chat"] = {
	clear = manager.clear
}

---Functions for internal manipulations by runtime_migrations
manager.__newChatLog = newChatLog

return manager