local event_handler = require("__better-chat__.runtime.custom_event_handler")
---@type custom_event_handler
local backup_handler = {events = {}}

---@alias historyLevel "global"|"force"|"player"|"surface"
local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")
local send_message = require("__better-chat__.runtime.handle_messages").send_message
local filter = require("__better-chat__.runtime.filter")



---@param message LocalisedString|messageParams
---@param color Color?
---@param send_level historyLevel?
---@param recipient integer?
---@param clear boolean? Whether or not the chat is cleared, `true` by default
local function compatibility_send(message, color, send_level, recipient, clear)
	if type(message) == "table" and message[1] then
		---@cast message LocalisedString
		return send_message{
			message = message,
			color = color,
			send_level = send_level or "global",
			recipient = recipient,
			clear = clear,
		}

	else
		---@cast message messageParams
		return send_message(message)
	end
end

--#region Symbol Exporting for other mods
remote.add_interface("better-chat", {
	send = compatibility_send,

	get_message = filter.get_message,
	set_message = filter.set_message,
})
--#endregion

---@type {[string]:metatable}
metatables = {}

event_handler.add_libraries{
	require("__better-chat__.runtime.storage"),
	backup_handler,
	require("__better-chat__.runtime.ChatHistoryManager"),
	require("__better-chat__.runtime.disableFunctions"),
	require("__better-chat__.runtime.is_open"),
}

for name, metatable in pairs(metatables) do
	script.register_metatable(name, metatable)
end