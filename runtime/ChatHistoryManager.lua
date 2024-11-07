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
	---@param sizeLimit int?
	add = function(self, chat, sizeLimit)
		self.size = self.size + 1
		self.last_index = self.last_index + 1
		self.chat_array[self.last_index] = chat
		if sizeLimit then self:trim(sizeLimit) end
	end,
	---Trim elements from list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit int
	trim = function(self, sizeLimit)
		for i = self.top_index, self.last_index-sizeLimit, 1 do
			self.top_index = i + 1
			self.size = self.size - 1
			self.chat_array[i] = nil
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

---@class ChatLogManager
local manager = {}

---Adds a new chatlog for force_index if it didn't exist before
---@param force_index int
manager.add_force = function(force_index)
	if storage.ForceChatLog[force_index] then return end
	storage.ForceChatLog[force_index] = newChatLog(
		storage.GlobalChatLog, "force"
	)
end
---Adds a new chatlog for player_index if it didn't exist before
---@param player_index int
manager.add_player = function(player_index)
	if storage.PlayerChatLog[player_index] then return end
	storage.PlayerChatLog[player_index] = newChatLog(
		storage.ForceChatLog[game.get_player(player_index).force_index],
		"player", player_index
	)
end

---Removes a chatlog for deleted force
---@param force_index int
manager.remove_force = function(force_index)
	storage.ForceChatLog[force_index] = nil
end
---Removes a chatlog for removed player
---@param player_index int
manager.remove_player = function(player_index)
	storage.PlayerChatLog[player_index] = nil
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
		tick = game.tick
	}

	if messageParams.level =="global" then
		-- Add message to global chat, every force, and every player
		storage.GlobalChatLog:add(newChat, settings.global["bc-global-chat-history"].value--[[@as int]])

		local force_chat_history = settings.global["bc-force-chat-history"].value--[[@as int]]
		for _,force in pairs(game.forces) do
			storage.ForceChatLog[force.index]:add(newChat, force_chat_history)
		end

		for _, player in pairs(game.players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as int]]
			storage.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end


	elseif messageParams.level == "force" then
		local force_index = messageParams.chat_index --[[@as int]]
		-- Add message to the force and players in the force
		storage.ForceChatLog[force_index]
			:add(newChat, settings.global["bc-force-chat-history"].value--[[@as int]])

		for _,player in pairs(game.forces[force_index].players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as int]]
			storage.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end


	elseif messageParams.level == "player" then
		local player_index = messageParams.chat_index --[[@as int]]
		-- Add message to the player
		storage.PlayerChatLog[messageParams.chat_index]
			:add(newChat, settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as int]])


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

---Prints the chats to the passed player
---@param player LuaPlayer
local function print_chats(player)
	local player_index = player.index
	local isChatOpen = storage.isChatOpen:check(player_index)

	--Obtain relevant settings
	local player_settings = settings.get_player_settings(player_index)
	local closeable = player_settings["bc-player-closeable-chat"].value--[[@as boolean]]
	local default_color = player_settings["bc-default-color"].value--[[@as Color]]
	local message_linger = math.floor(player_settings["bc-message-linger"].value--[[@as double]] * 60)
	local color_processing = get_color_process_settings(player_settings)

	--Go through every chat
	player.clear_console()
	for _,chat in storage.PlayerChatLog[player_index]:from() do

		--Skip chat if doesn't need to be logged
		if closeable and not (isChatOpen or player.controller_type == defines.controllers.spectator)
		and game.tick > chat.tick + message_linger then
			goto continue -- Skip printing message
		end

		--Get general message color
		local color = chat.color or default_color

		if chat.process_color then
			color = process_color(color_processing, color)
		end

		--Print the message
		player.print(chat.message, {
			color = color,
			sound = defines.print_sound.never,
			skip = defines.print_skip.never
		})
			::continue::
	end
end

---Prints the latest message from the player
---@param player LuaPlayer
local function print_chat(player)
	local player_index = player.index

	--Obtain relevant settings
	local player_settings = settings.get_player_settings(player_index)
	local default_color = player_settings["bc-default-color"].value--[[@as Color]]
	local color_processing = get_color_process_settings(player_settings)

	local log = storage.PlayerChatLog[player_index]
	local chat = log.chat_array[log.last_index]

	--Get general message color
	local color = chat.color or default_color

	if chat.process_color then
		color = process_color(color_processing, color)
	end

	--Print the message
	player.print(chat.message, {
		color = color,
		sound = defines.print_sound.never,
		skip = defines.print_skip.never
	})
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
manager.print_chat = function(chat_level, chat_index)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	func(chat_index, print_chats)
end

---Print the latest message in the group without clearing chat first
---@param chat_level historyLevel
---@param chat_index int?
manager.print_latest = function(chat_level, chat_index)
	local func = print_level_switch[chat_level]
	if not func then return log({"invalid-destination"}) end

	func(chat_index, print_chat)
end

---@class BetterChatGlobal
---@field GlobalChatLog ChatLog
---@field ForceChatLog table<int, ChatLog>
---@field PlayerChatLog table<int, ChatLog>

---Initializes Chat History
manager.init = function()
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

---Functions for internal manipulations by runtime_migrations
manager.__newChatLog = newChatLog

return manager