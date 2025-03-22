local event_handler = require("__better-chat__.runtime.custom_event_handler")

---@type {[string]:metatable}
metatables = {}

event_handler.add_libraries{
	require("__better-chat__.runtime.storage"),
	require("__better-chat__.runtime.ChatHistoryManager"),
	require("__better-chat__.runtime.handle_messages"),
	require("__better-chat__.runtime.disableFunctions"),
	require("__better-chat__.runtime.filter"),
	require("__better-chat__.runtime.is_open"),
}

for name, metatable in pairs(metatables) do
	script.register_metatable(name, metatable)
end