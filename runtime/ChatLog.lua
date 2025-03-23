---@alias ChatMessageType
---| "global"
---| "force"
---| "player"
---| "surface"
---| "whisper"

---@class ChatPlayer
---@field name string
---@field color Color
---@field index uint

---@class Chat.base
---@field message_type "global"
---@field message LocalisedString
---@field tick uint
---@field chat_id uint
---@field sender? ChatPlayer
---@field color? Color
---@field process_color? boolean

---@class Chat.force_player : Chat.base
---@field message_type "force"|"player"
---@field recipient_index uint

---@class Chat.surface : Chat.base
---@field message_type "surface"
---@field recipients uint[]

---@class Chat.whisper : Chat.base
---@field message_type "whisper"
---@field sender ChatPlayer
---@field recipient ChatPlayer

---@alias Chat Chat.base|Chat.force_player|Chat.surface|Chat.whisper

--- Determine if the chat should be visible based on the given player and force
--- If the player or force aren't given, it'll default to visible
---@type table<ChatMessageType,fun(chat:Chat,player?:uint,force?:uint):boolean>
local can_see = {
	["global"] = function() return true end,

	---@param chat Chat.force_player
	["force"] = function (chat, _, force)
		if not force then return true end
		return chat.recipient_index == force
	end,

	---@param chat Chat.force_player
	["player"] = function (chat, player)
		if not player then return true end
		return chat.recipient_index == player
	end,

	---@param chat Chat.surface
	["surface"] = function (chat, player)
		if not player then return true end
		for _, recipient_index in pairs(chat.recipients) do
			if recipient_index == player then
				return true
			end
		end
		return false
	end,

	---@param chat Chat.whisper
	["whisper"] = function (chat, player)
		if not player then return true end
		return not chat.recipient.index == player or chat.sender == player
	end,
}

---@class ChatLog
---@field chat_array Chat[]
---@field size int
---@field top_index? uint
---@field last_index int
local ChatLog = {
	---Add a new element in the list
	---@param self ChatLog
	---@param chat Chat
	---@param sizeLimit? int
	---@param removal_callback? fun(index:uint)
	add = function(self, chat, sizeLimit, removal_callback)
		self.size = self.size + 1
		self.chat_array[chat.chat_id] = chat

		if chat.chat_id <= self.last_index then
			log("ID's are not sequential??? '"..chat.chat_id.."' was smaller than '"..self.last_index.."'")
		else
			self.last_index = chat.chat_id
		end

		if sizeLimit then self:trim(sizeLimit, removal_callback) end
	end,
	---Remove a chat from the list
	---@param self ChatLog
	---@param chat_id uint
	remove = function(self, chat_id)
		self.size = self.size - 1
		self.chat_array[chat_id] = nil
	end,
	---Trim elements from list until its equal to limit
	---@param self ChatLog
	---@param sizeLimit int
	---@param removal_callback? fun(index:uint)
	trim = function(self, sizeLimit, removal_callback)
		while self.size > sizeLimit do
			self.size = self.size - 1
			self.chat_array[self.top_index] = nil
			if removal_callback then removal_callback(self.top_index) end
			self.top_index = next(self.chat_array, self.top_index)
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
	end,
	---@class ChatLog.filterparams
	---@field player_index? uint
	---@field force_index? uint
	---@field message_type? {[ChatMessageType]:true?} Defaults to every message type if not given
	---@param self ChatLog
	---@param params ChatLog.filterparams
	---@return fun(array:table<int,Chat>,last_index:int):int?,Chat?
	---@return Chat[]
	filter = function (self, params)
		return function(array, last_index)
			local next_index, next_chat = next(array, last_index)
			while next_index do
				---@cast next_chat -?

				-- make sure the chat is of a valid type
				if params.message_type and not params.message_type[next_chat.message_type] then
					goto next
				end

				-- Make sure the chat is visible by the given? indexes
				if not can_see[next_chat.message_type](next_chat, params.player_index, params.force_index) then
					goto next
				end

				-- Finally output
				do return next_index, next_chat end

				-- Skip to the next
				::next::
				next_index, next_chat = next(array, next_index)
			end
		end, self.chat_array
	end
}

local chatMetatable = {__index=ChatLog}
metatables["bc-chatlog"] = chatMetatable

---Creates a new ChatLog
---@param global_log ChatLog
---@param player LuaPlayer
---@return ChatLog
---@overload fun():ChatLog
local function newChatLog(global_log, player)
	---@type ChatLog
	local newLog = setmetatable({
		size = 0,
		last_index = 0,
		chat_array = {}
	}, chatMetatable)
	if not global_log then return newLog end

	for _,chat in global_log:filter{
		player_index = player.index,
		force_index = player.force_index
	} do
		newLog:add(chat)
	end

	return newLog
end

return newChatLog