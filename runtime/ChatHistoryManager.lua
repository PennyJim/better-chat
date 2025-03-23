local interface = require("__better-chat__.runtime.ChatInterface")
--MARK: ChatLog

---@class Chat
---@field message LocalisedString
---@field tick int
---@field color Color?
---@field process_color boolean?

---@class ChatLog
---@field chat_array Chat[]
---@field size int
---@field top_index int
---@field last_index int
local ChatLog = {
	---Add a new element in the linked list
	---@param self ChatLog
	---@param chat Chat
	---@param sizeLimit? int
	---@param removal_callback? fun(index:uint)
	add = function(self, chat, sizeLimit, removal_callback)
		self.size = self.size + 1
		self.last_index = self.last_index + 1
		self.chat_array[self.last_index] = chat
		if sizeLimit then self:trim(sizeLimit, removal_callback) end
	end,
	---Trim elements from list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit int
	---@param removal_callback? fun(index:uint)
	trim = function(self, sizeLimit, removal_callback)
		for i = self.top_index, self.last_index-sizeLimit, 1 do
			self.top_index = i + 1
			self.size = self.size - 1
			self.chat_array[i] = nil
			if removal_callback then removal_callback(i) end
		end
	end,
	---Return an iterator for every element in linked list
	---@param self ChatLog
	---@param first_index int?
	---@return fun(table:table<int,Chat>,index:int):int?,Chat?
	---@return Chat[]
	---@return int?
	from = function(self, first_index)
		return next, self.chat_array, first_index
	end
}

local chatMetatable = {__index=ChatLog}
script.register_metatable("bc-chatlog", chatMetatable)
---Creates a new ChatLog
---@param oldLog ChatLog?
---@param log_type "force"|"player"?
---@param player_index int?
---@return ChatLog
local function newChatLog(oldLog, log_type, player_index)
	local newLog = setmetatable({
		size = 0,
		top_index = 1,
		last_index = 0,
		chat_array = {}
	}, chatMetatable)
	if not oldLog then return newLog end

	for _,chat in oldLog:from() do
		newLog:add(chat)
	end
	if (log_type=="force") then
		newLog:trim(settings.global["bc-force-chat-history"].value--[[@as int]])
	else
		---@type int
		local setting
		if player_index then
			setting = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as int]]
		end
		if setting then
			newLog:trim(setting)
		else
			newLog:trim(settings.player_default["bc-player-chat-history"].value--[[@as int]])
		end
	end
	return newLog
end

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

---@class ColorSettings
---@field brighten_percent float

---returns the player settings related to color processing
---@param player_settings LuaCustomTable<string,ModSetting>
---@return ColorSettings
local function get_color_process_settings(player_settings)
	return {
		brighten_percent = player_settings["bc-color-fade"].value--[[@as float]]
	}
end

---Processes a color according to player settings
---@param color_settings ColorSettings
---@param color Color
---@return Color
local function process_color(color_settings, color)
	local new_color = {
		color[1] or color.r,
		color[2] or color.g,
		color[3] or color.b
	}
	--Brighten
	local brighten_inverse = 1/(1-color_settings.brighten_percent)
	new_color[1] = new_color[1]/brighten_inverse+color_settings.brighten_percent
	new_color[2] = new_color[2]/brighten_inverse+color_settings.brighten_percent
	new_color[3] = new_color[3]/brighten_inverse+color_settings.brighten_percent


	return new_color
end

---Formats the given tick in D+:HH:MM:SS
---@param tick int
---@return string
function format_time(tick)
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
local format_time = format_time

--MARK: Chat Printing
---@type LuaPlayer
local printing_player
---@type boolean
local isChatOpen
---@type LuaCustomTable<string, ModSetting>
local player_settings
---@type boolean
local closeable
---@type Color
local default_color
---@type int
local message_linger
---@type boolean
local show_timestamp
---@type ColorSettings
local color_processing
---@type defines.print_sound
local sound = defines.print_sound.never
---@type SoundPath?
local sound_path
---@type float?
local volume_modifier

---@param chat Chat
local function print_individual_chat(chat)
	--Skip chat if doesn't need to be logged
	if closeable and not (isChatOpen or printing_player.controller_type == defines.controllers.spectator)
	and game.ticks_played > chat.tick + message_linger then
		return -- Skip printing message
	end

	--Get general message color
	local color = chat.color or default_color

	if chat.process_color then
		color = process_color(color_processing, color)
	end

	local message = chat.message
	if show_timestamp then
		message = {"", format_time(chat.tick).." | ", message}
	end

	--Print the message
	printing_player.print(message, {
		color = color,
		skip = defines.print_skip.never,

		sound = sound,
		sound_path = sound_path,
		volume_modifier = volume_modifier,
	})
	sound = defines.print_sound.never
	sound_path = nil
	volume_modifier = nil
end

---Prints the chats to the passed player
---@param player LuaPlayer
local function print_chats(player)
	local player_index = player.index
	printing_player = player
	isChatOpen = storage.isChatOpen:check(player_index)

	--Obtain relevant settings
	player_settings = settings.get_player_settings(player_index)
	closeable = player_settings["bc-player-closeable-chat"].value--[[@as boolean]]
	default_color = player_settings["bc-default-color"].value--[[@as Color]]
	message_linger = math.floor(player_settings["bc-message-linger"].value--[[@as double]] * 60)
	show_timestamp = player_settings["bc-show-timestamp"].value--[[@as boolean]]
	color_processing = get_color_process_settings(player_settings)

	--Go through every chat
	local log = storage.PlayerChatLog[player_index]
	local start = log.last_index - 36
	if start < log.top_index then
		start = log.top_index
	end

	player.clear_console()
	for _,chat in log:from(start) do
		print_individual_chat(chat)
	end
end

---Prints the latest message from the player
---@param player LuaPlayer
local function print_chat(player)
	local player_index = player.index
	printing_player = player
	-- isChatOpen not necessary as closeable set to false

	--Obtain relevant settings
	player_settings = settings.get_player_settings(player_index)
	closeable = false -- Set to false to exit the skip printing check asap
	default_color = player_settings["bc-default-color"].value--[[@as Color]]
	-- message_linger not necessary as closeable set to false
	show_timestamp = player_settings["bc-show-timestamp"].value--[[@as boolean]]
	color_processing = get_color_process_settings(player_settings)

	local log = storage.PlayerChatLog[player_index]
	local chat = log.chat_array[log.last_index]

	print_individual_chat(chat)
end

---@type table<historyLevel, fun(index?:int,func:fun(player:LuaPlayer))>
local print_level_switch = {
	["global"] = function (index, func)
		for _, player in pairs(game.players) do
			func(player)
		end
	end,
	["force"] = function (index, func)
		---@cast index int
		for _, player in pairs(game.forces[index].players) do
			func(player)
		end
	end,
	["surface"] = function (index, func)
		---@cast index int
		for _, player in pairs(game.players) do
			if player.surface_index == index then func(player) end
		end
	end,
	["player"] = function (index, func)
		---@cast index int
		local player = game.get_player(index)
		if not player then return log("[ERR] Player getting printed to does not exist") end
		func(player)
	end
}

---Print out all messages for a group
---@param chat_level historyLevel
---@param chat_index int?
---@param print_sound defines.print_sound?
---@param print_sound_path SoundPath?
---@param print_volume float?
manager.print_chat = function(chat_level, chat_index, print_sound, print_sound_path, print_volume)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	sound = print_sound or defines.print_sound.never
	sound_path = print_sound_path
	volume_modifier = print_volume
	func(chat_index, print_chats)
end

---Print the latest message in the group without clearing chat first
---@param chat_level historyLevel
---@param chat_index int?
---@param print_sound defines.print_sound? Defaults to `defines.print_sound.never`
---@param print_sound_path SoundPath?
---@param print_volume float?
manager.print_latest = function(chat_level, chat_index, print_sound, print_sound_path, print_volume)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	sound = print_sound or defines.print_sound.never
	sound_path = print_sound_path
	volume_modifier = print_volume
	func(chat_index, print_chat)
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
      manager.print_chat("global")
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
      manager.print_chat("player", player_index)
    elseif setting == "bc-player-closeable-chat" then
      -- Clear opened value when closeable is disabled
      -- Also does it when enabled, but they should just be in main menu
      storage.isChatOpen[player_index--[[@as int]]] = nil
      -- Update chat to now match the openness it Should be now
      manager.print_chat("player", player_index)
    elseif (
      setting == "bc-color-fade" or
      setting == "bc-default-color" or
      setting == "bc-error-color" or
      setting == "bc-warn-color" or
      setting == "bc-debug-color"
    ) then
      -- Reprint chat to update the the printed chat
      manager.print_chat("player", player_index)
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