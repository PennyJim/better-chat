event_handler_lib = require("event_handler")

---@class BetterChatStorage
storage = storage
---@type {[string]:metatable}
metatables = {}

event_handler_lib.add_libraries{
	-- require("__glib__.glib"), -- Let it register its own events
	require("interface.chatbox"),
	require("runtime.chatlog_manager"),
	require("runtime.handle_messages"),
	require("runtime.chat_events"),
}

for name, metatable in pairs(metatables) do
	script.register_metatable(name, metatable)
end