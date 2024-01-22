---@class Chat
---@field msg string
---@field color Color?
---@field sender string?

---@class LinkedListItem<T>: {next:LinkedListItem?,value:T}
---@class ChatLog
---@field first_chat LinkedListItem<Chat>? The fist item in the log
---@field last_chat LinkedListItem<Chat>? The last item in the log
---@field get fun(ChatLog, integer):LinkedListItem<Chat>? Return the nth element in the linked list.
---@field size integer
local ChatLog = {
	---Return the nth element in the linked list.
	---@param self ChatLog
	---@param index integer
	---@return LinkedListItem<Chat>?
	get = function(self, index)
		local item = self.first_chat
		for i = 1, index, 1 do
			if not item then return nil end
			item = item.next
		end
		return item
	end,
	---Add a new element in the linked list
	---@param self ChatLog
	---@param chat Chat
	---@param sizeLimit integer
	---@return LinkedListItem<Chat>?
	add = function(self, chat, sizeLimit)
		self.last_chat = chat
		self.size = self.size + 1
		self:trim(sizeLimit)
	end,
	---Trim elements from linked list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit integer
	trim = function(self, sizeLimit)
		while self.size > sizeLimit do
			self.first_chat = self.first_chat.next
			self.size = self.size - 1
		end
	end,
	---Return an iterator for every element in linked list
	---@param self ChatLog
	---@return fun():Chat
	all = function(self)
		local ChatItem = self.first_chat
		return function ()
			local Chat = ChatItem.value
			ChatItem = ChatItem.next
			return Chat
		end
	end
}

local chatMetatable = {__index=ChatLog}
script.register_metatable("bc-chatlog", chatMetatable)
---Creates a new ChatLog
---@return ChatLog
local function newChatLog()
	return setmetatable({
		size = 0
	}, chatMetatable)
end

---@class ChatLogManager
local manager = {}

global.GlobalChatLog = newChatLog();

---Adds a new chatlog for force_index if it didn't exist before
---@param force_index integer
manager.add_force = function(force_index)
	if global.ForceChatLog[force_index] then return end
	global.ForceChatLog[force_index] = newChatLog()
end
---Adds a new chatlog for player_index if it didn't exist before
---@param player_index integer
manager.add_player = function(player_index)
	if global.PlayerChatLog[player_index] then return end
	global.PlayerChatLog[player_index] = newChatLog()
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
---@field message string
---@field level "global"|"force"|"player"?
---@field chat_index integer?
---@field sender string?
---@field color Color?
---Adds a message to chat history
---@param messageParams addMessageParams
manager.add_message = function(messageParams)
	---@type Chat
	local newChat = {
		msg = messageParams.message,
		color = messageParams.color,
		sender = messageParams.sender
	}

	if messageParams.level =="global" then
		-- Add message to global chat, every force, and every player
		global.GlobalChatLog:add(newChat, settings.global["bc-global-chat-history"].value)

		local force_chat_history = settings.global["bc-force-chat-history"].value
		for force_index in pairs(game.forces) do
			global.ForceChatLog[force_index]:add(newChat, force_chat_history)
		end

		local player_chat_history = settings.global["bc-player-chat-history"].value
		for player_index in pairs(game.players) do
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "force" then
		-- Add message to the force and players in the force
		global.ForceChatLog[messageParams.chat_index]
			:add(newChat, settings.global["bc-force-chat-history"].value)

		for player_index in pairs(game.forces[messageParams.chat_index].players) do
			local player_chat_history = settings.get_player_settings(player_index)["bc-player-chat-history"].value
			global.PlayerChatLog[player_index]:add(newChat, player_chat_history)
		end
	elseif messageParams.level == "player" then
		-- Add message to the player
		global.PlayerChatLog[messageParams.chat_index]
			:add(newChat, settings.get_player_settings(messageParams.chat_index)["bc-player-chat-history"].value)
	else
		log({"", {"bc-invalid-chat-level"}, serpent.line(messageParams)})
	end
end

---Print out all messages for a group
---@param chat_level "global"|"force"|"player"
---@param chat_index integer?
manager.print_chat = function(chat_level, chat_index)
	if chat_level == "global" then
		for player_index, player in pairs(game.players) do
			for chat in global.PlayerChatLog[player_index]:all() do
				player.print(chat.msg, {
					color = chat.color or settings.get_player_settings(player_index)["bc-default-color"].value,
					sound = defines.print_sound.never,
					skip = defines.print_skip.never
				})
			end
		end
	elseif chat_level == "force" then

	elseif chat_level == "player" then
	end
end

---Initializes Chat History
manager.init = function()
	global.GlobalChatLog = newChatLog();
	global.ForceChatLog = {}
	for _,force in pairs(game.forces) do
		global.ForceChatLog[force.index] = newChatLog();
	end
	global.PlayerChatLog = {}
	for player in pairs(game.players) do
		global.ForceChatLog[player] = newChatLog();
	end
end

return manager