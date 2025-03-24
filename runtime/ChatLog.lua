---@alias ChatMessageType
---| "global"
---| "force"
---| "player"
---| "surface"
---| "whisper"

---@class ChatPlayer
---@field name string
---@field color Color.0
---@field index? uint Nilable because the player may have been removed

---@class Chat.base
---@field type "global"
---@field message LocalisedString
---@field tick uint
---@field chat_id uint
---@field sender? ChatPlayer
---@field color? Color
---@field process_color? boolean

---@class Chat.force_player : Chat.base
---@field type "force"|"player"
---@field recipient_index uint

---@class Chat.surface : Chat.base
---@field type "surface"
---@field recipients uint[]

---@class Chat.whisper : Chat.base
---@field type "whisper"
---@field sender ChatPlayer
---@field recipient ChatPlayer

---@alias Chat Chat.base|Chat.force_player|Chat.surface|Chat.whisper

---@type table<ChatMessageType,fun(chat:Chat,player?:uint,force?:uint):boolean>
local see_lookup = {
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

---@class ChatLog.filter
---@field player_index? uint
---@field force_index? uint
---@field type? {[ChatMessageType]:true?} Defaults to every message type if not given

--- Determine if the chat is visible based on the given filter
---@param chat Chat
---@param filter ChatLog.filter
---@return boolean
local function passes_filter(chat, filter)
	-- make sure the chat is of a valid type
	if filter.type and not filter.type[chat.type] then
		return false
	end

	-- Make sure the chat is visible by the given indexes
	if not see_lookup[chat.type](chat, filter.player_index, filter.force_index) then
		return false
	end

	return true
end

---@class ChatLog
---@field chat_array Chat[]
---@field size int
---@field top_index? uint
---@field last_index int
local chatlog = {}
local chatMetatable = {__index=chatlog}
metatables["bc-chatlog"] = chatMetatable

--MARK: Functions

---Add a new element in the list
---@param chat Chat
---@param sizeLimit? int
---@param removal_callback? fun(index:uint)
function chatlog:add(chat, sizeLimit, removal_callback)
	self.size = self.size + 1
	self.chat_array[chat.chat_id] = chat

	self.last_index = chat.chat_id

	if sizeLimit then self:trim(sizeLimit, removal_callback) end
end

---Remove a chat from the list
---@param chat_id uint
function chatlog:remove(chat_id)
	self.size = self.size - 1
	self.chat_array[chat_id] = nil
end

---Trim elements from list until its equal to limit
---@param self ChatLog
---@param sizeLimit int
---@param removal_callback? fun(index:uint)
function chatlog:trim(sizeLimit, removal_callback)
	while self.size > sizeLimit do
		self.size = self.size - 1
		self.chat_array[self.top_index] = nil
		if removal_callback then removal_callback(self.top_index) end
		self.top_index = next(self.chat_array, self.top_index)
	end
end

---Return an iterator for every element in linked list
---@param first_index int?
---@return fun(table:table<int,Chat>,index:int):int?,Chat?
---@return Chat[]
---@return int?
function chatlog:from(first_index)
	return next, self.chat_array, first_index
end

---@param filter ChatLog.filter
---@return fun(array:table<int,Chat>,last_index:int):int?,Chat?
---@return Chat[]
function chatlog:filter(filter)
	return function(array, last_index)
		local next_index, next_chat = next(array, last_index)
		while next_index do
			---@cast next_chat -?

			if passes_filter(next_chat, filter) then
				return next_index, next_chat
			end

			next_index, next_chat = next(array, next_index)
		end
	end, self.chat_array
end

--MARK: Static Functions

---Creates a new ChatLog
---@param global_log ChatLog
---@param player LuaPlayer
---@return ChatLog
---@overload fun():ChatLog
function chatlog.new(global_log, player)
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

chatlog.passes_filter = passes_filter


return chatlog