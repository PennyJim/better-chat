---@class MessageFilter : custom_event_handler
local filter = {remote_interfaces = {}}
filter.during_message = false
filter.message = ""

---NOTE: If you have any ideas for parameters to add to this event, feel free to ask.
---
---I just can't think of any more.
---@class EventData.better-chat-message : EventData
---@field player LuaPlayer The player who sent the message.
---@field type PrintLevel How many people will be able to see this message.
---@class EventData.better-chat-message
local _ = {
	---This is only there if youre *really* need it. If you act based on the original message, you'll squash previous filtering.
	---
	---*Including* base game shortcode replacement: `:heart:` -> 💜
	---@deprecated please use `remote.call("better-chat", "get_message")`
	orig_message = string.char(0)
}

---@param player LuaPlayer
---@param type PrintLevel
---@param original string
---@param message string
---@return string
function filter.chat(player, type, original, message)
	---@type EventData.better-chat-message
	local data = {
		-- To make luals happy. Even though the engine will add them :(
		name = script.get_event_id("better-chat-message"), tick = game.tick,

		player = player,
		type = type,
		orig_message = original,
		-- tick = game.tick,
	}

	filter.message = message
	filter.during_message = true
	script.raise_event("better-chat-message", data)
	filter.during_message = false
	return filter.message
end

---@param message string
function filter.set_message(message)
	if not filter.during_message then error("Can only be called during message filtering") end
	if type(message) ~= "string" then error("The filtering can only support a string") end
	filter.message = message
end
---@return string
function filter.get_message()
	if not filter.during_message then error("Can only be called during message filtering") end
	return filter.message
end

--[[TODO:
	Add some sort of filtering for printed messages?
	It might be nice, but also how do you event filter a LocalisedString?
]]

filter.remote_interfaces["better-chat"] = {
	get_message = filter.get_message,
	set_message = filter.set_message,
}

return filter