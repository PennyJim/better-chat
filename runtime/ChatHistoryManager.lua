---@class Chat
---@field message LocalisedString
---@field tick integer
---@field color Color?
---@field process_color boolean?

---@class ChatLog
---@field chat_array Chat[]
---@field size integer
---@field top_index integer
---@field last_index integer
local ChatLog = {
	---Add a new element in the linked list
	---@param self ChatLog
	---@param chat Chat
	---@param sizeLimit integer?
	add = function(self, chat, sizeLimit)
		self.size = self.size + 1
		self.last_index = self.last_index + 1
		self.chat_array[self.last_index] = chat
		if sizeLimit then self:trim(sizeLimit) end
	end,
	---Trim elements from list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit integer
	trim = function(self, sizeLimit)
		for i = self.top_index, self.last_index-sizeLimit, 1 do
			self.top_index = i + 1
			self.chat_array[i] = nil
		end
	end,
	---Return an iterator for every element in linked list
	---@param self ChatLog
	---@param first_index integer?
	---@return fun():Chat?
	from = function(self, first_index)
		local chat_array = self.chat_array
		local i = first_index or self.top_index
		i = i-1
		return function()
			i = 1 + i
			return chat_array[i]
		end
	end
}

local chatMetatable = {__index=ChatLog}
script.register_metatable("bc-chatlog", chatMetatable)
---Creates a new ChatLog
---@param oldLog ChatLog?
---@param log_type "force"|"player"?
---@return ChatLog
local function newChatLog(oldLog, log_type)
	local newLog = setmetatable({
		size = 0,
		top_index = 1,
		last_index = 0,
		chat_array = {}
	}, chatMetatable)
	if not oldLog then return newLog end

	for chat in oldLog:from() do
		newLog:add(chat)
	end
	if (log_type=="force") then
		newLog:trim(settings.global["bc-force-chat-history"].value--[[@as integer]])
	else
		newLog:trim(settings.player["bc-player-chat-history"].value--[[@as integer]])
	end
	return newLog
end

---@class ChatLogManager
local manager = {}

---Adds a new chatlog for force_index if it didn't exist before
---@param force_index integer
manager.add_force = function(force_index)
	if global.ForceChatLog[force_index] then return end
	global.ForceChatLog[force_index] = newChatLog(
		global.GlobalChatLog
	)
end
---Adds a new chatlog for player_index if it didn't exist before
---@param player_index integer
manager.add_player = function(player_index)
	if global.PlayerChatLog[player_index] then return end
	global.PlayerChatLog[player_index] = newChatLog(
		global.ForceChatLog[game.get_player(player_index).force_index]
	)
end

---Removes a chatlog for deleted force
---@param force_index integer
manager.remove_force = function(force_index)
	global.ForceChatLog[force_index] = nil
end
---Removes a chatlog for removed player
---@param player_index integer
manager.remove_player = function(player_index)
	global.PlayerChatLog[player_index] = nil
end

---@class addMessageParams
---@field message LocalisedString
---@field color Color?
---@field level historyLevel
---@field chat_index integer?
---Adds a message to chat history
---@param messageParams addMessageParams
manager.add_message = function(messageParams)
	---@type Chat
	local newChat = {
		message = messageParams.message,
		color = messageParams.color,
		tick = game.tick
	}

	if messageParams.level =="global" then
		-- Add message to global chat, every force, and every player
		global.GlobalChatLog:add(newChat, settings.global["bc-global-chat-history"].value--[[@as integer]])

		local force_chat_history = settings.global["bc-force-chat-history"].value--[[@as integer]]
		for _,force in pairs(game.forces) do
			global.ForceChatLog[force.index]:add(newChat, force_chat_history)
		end

		for _, player in pairs(game.players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as integer]]
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "force" then
		local force_index = messageParams.chat_index --[[@as integer]]
		-- Add message to the force and players in the force
		global.ForceChatLog[force_index]
			:add(newChat, settings.global["bc-force-chat-history"].value--[[@as integer]])

		for _,player in pairs(game.forces[force_index].players) do
			local player_index = player.index
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as integer]]
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "player" then
		local player_index = messageParams.chat_index --[[@as integer]]
		-- Add message to the player
		global.PlayerChatLog[messageParams.chat_index]
			:add(newChat, settings.get_player_settings(player_index)["bc-player-chat-history"].value--[[@as integer]])
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
	local isChatOpen = global.isChatOpen:check(player_index)
	-- log("Player: "..player_index.."\tIs Open: "..(isChatOpen and "True" or "False"))
	--Obtain relevant settings
	local player_settings = settings.get_player_settings(player_index)
	local default_color = player_settings["bc-default-color"].value--[[@as Color]]
	local message_linger = math.floor(player_settings["bc-message-linger"].value--[[@as double]] * 60)
	local color_processing = get_color_process_settings(player_settings)

	--Go through every chat
	player.clear_console()
	for chat in global.PlayerChatLog[player_index]:from() do

		--Skip chat if doesn't need to be logged
		if not isChatOpen and game.tick > chat.tick + message_linger then
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

---Print out all messages for a group
---@param chat_level historyLevel
---@param chat_index integer?
manager.print_chat = function(chat_level, chat_index)
	if chat_level == "global" then
		for _, player in pairs(game.players) do
			print_chats(player)
		end
	elseif chat_level == "force" then
		---@cast chat_index integer
		for _, player in pairs(game.forces[chat_index].players) do
			print_chats(player)
		end
	elseif chat_level == "player" then
		---@cast chat_index integer
		local player = game.get_player(chat_index)
		-- TODO: improve this error statement
		if not player then return log("[ERR] Something has gone wrong") end
		print_chats(player)
	else
		log({"invalid-destination"})
	end
end

---@class BetterChatGlobal
---@field GlobalChatLog ChatLog
---@field ForceChatLog table<integer, ChatLog>
---@field PlayerChatLog table<integer, ChatLog>

---Initializes Chat History
manager.init = function()
	global.GlobalChatLog = newChatLog();
	global.ForceChatLog = {}
	for _,force in pairs(game.forces) do
		global.ForceChatLog[force.index] = newChatLog();
	end
	global.PlayerChatLog = {}
	for _, player in pairs(game.players) do
		local player_index = player.index
		global.PlayerChatLog[player_index] = newChatLog();
	end
end

---Functions for internal manipulations by runtime_migrations
manager.__newChatLog = newChatLog

return manager