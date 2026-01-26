
---@alias PrintLevel 
---| "global"
---| "force"
---| "player"
---| "surface"

---@alias ChatMessageType
---| PrintLevel
---| "command"

---@class ChatPlayer
---@field name string
---@field color Color.0
---@field index? uint Nilable because the player may have been removed

---@class Chat.base
---@field type "global"|"command"
---@field message LocalisedString
---@field tick uint
---@field chat_id uint
---@field sender? ChatPlayer
---@field ignored_by? {[uint]:true?}
---@field color? Color
---@field process_color? boolean

---@class Chat.player : Chat.base
---@field type "player"
---@field recipient ChatPlayer

---@class Chat.force_surface : Chat.base
---@field type "surface"|"force"
---@field recipient_index uint
---@field recipients table<uint,true>

---@alias Chat
---| Chat.base
---| Chat.player
---| Chat.force_surface

---@type table<ChatMessageType,fun(chat:Chat,player?:uint,force?:uint):boolean>
local see_lookup = {
	global = function() return true end,

	command = function (chat, player, force)
		if not player then return not force end
		return chat.sender.index == player
			or game.get_player(player).admin
	end,

	---@param chat Chat.force_surface
	force = function (chat, player, force)
		if player then
			return chat.recipients[player]
		end
		if not force then return true end
		return chat.recipient_index == force
	end,

	---@param chat Chat.player
	player = function (chat, player, force)
		if not player then return not force end
		return chat.recipient.index == player
			or chat.sender and chat.sender.index == player or false
	end,

	---@param chat Chat.force_surface
	surface = function (chat, player, force)
		if not player then return not force end
		return chat.recipients[player] or false
	end,
}

---@class ChatLog.filter
---Whether or not the given player could've seen the message *at time of sending*.
---@field player_index? uint
---Whether or not everyone in the force could've seen the message. This is fairly limited to just global and force specific message.
---
---If unset, everything is visble. Unused if `player_index` is set.
---@field force_index? uint
---Defaults to every message type if not given
---@field type? {[ChatMessageType]:true?}
---To be able to filter by sender. If a message with a sender has no player index associated, then it'll use the sender's name.
---
---`0` can be used to filter for messages without a sender. If unset, all senders are visible.
---@field sender? {[uint|string]:true?}

--- Determine if the chat is visible based on the given filter
---@param chat Chat
---@param filter ChatLog.filter
---@return boolean
local function passes_filter(chat, filter)
	-- make sure the chat is of a valid type
	if filter.type and not filter.type[chat.type] then
		return false
	end

	if filter.sender then
		---@type uint|string
		local key = 0
		if chat.sender then
			key = chat.sender.index or chat.sender.name
		end
		if not filter.sender[key] then
			return false
		end
	end

	if filter.player_index
	and chat.ignored_by
	and chat.ignored_by[filter.player_index] then
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
	local top_index = next(self.chat_array)
	if not top_index then return end
	while self.size > sizeLimit do
		self.size = self.size - 1
		self.chat_array[top_index] = nil
		if removal_callback then removal_callback(top_index) end
		top_index = next(self.chat_array, top_index)
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
		player_index = player.index
	} do
		newLog:add(chat)
	end

	return newLog
end

chatlog.passes_filter = passes_filter


return chatlog