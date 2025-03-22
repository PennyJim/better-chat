local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")

---@type custom_event_handler
local handler = {events = {}}


--TODO: Use the new singleplayer/multiplayer events to clean this

local isOpenDirty = false
metatables["bc-chatOpen"] = {
	__index = {
		check = function (self, player_index)
			if isOpenDirty then
				self = {}
				isOpenDirty = false
			end
			return self[player_index]
		end
	}
}

---@param event EventData.CustomInputEvent
handler.events[prototypes.custom_input["bc-toggle-chat"].event_id] = function (event)
  if not settings.get_player_settings(event.player_index)["bc-player-closeable-chat"].value then
    return
  end
	storage.isChatOpen[event.player_index] = not storage.isChatOpen:check(event.player_index)
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Toggle Chat")
end
---@param event EventData.CustomInputEvent
handler.events[script.get_event_id("bc-exit-chat")] = function (event)
  if not settings.get_player_settings(event.player_index)["bc-player-closeable-chat"].value then
    return
  end
	storage.isChatOpen[event.player_index] = nil
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Exit Chat")
end

return handler