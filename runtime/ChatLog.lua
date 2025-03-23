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
metatables["bc-chatlog"] = chatMetatable

---Creates a new ChatLog
---@param oldLog ChatLog
---@param log_type "force"|"player"
---@param player_index int
---@return ChatLog
---@overload fun():ChatLog
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

return newChatLog