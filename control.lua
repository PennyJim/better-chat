event_handler_lib = require("event_handler")

---@class BetterChatStorage
storage = storage
---@type {[string]:metatable}
metatables = {}

event_handler_lib.add_libraries{
	require("runtime.chatlog_manager"),
	require("runtime.chat_events"),
}

for name, metatable in pairs(metatables) do
	script.register_metatable(name, metatable)
end