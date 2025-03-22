local event_handler = require("__better-chat__.runtime.custom_event_handler")
---@type custom_event_handler
local backup_handler = {events = {}}

---@alias historyLevel "global"|"force"|"player"|"surface"
local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")
local send_message = require("__better-chat__.runtime.handle_messages").send_message
local filter = require("__better-chat__.runtime.filter")



--#region Setup


backup_handler.on_init = function ()
	ChatHistoryManager.init()
end
backup_handler.events[defines.events.on_runtime_mod_setting_changed] = function (event)
  local setting = event.setting
  if event.setting_type == "runtime-global" then
    if setting == "bc-global-chat-history"
    or setting == "bc-force-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      local message = setting == "bc-global-chat-history" and
        "chat-localization.bc-global-history-changed" or "chat-localization.bc-force-history-changed"
      local new_setting = settings.global[setting].value
      send_message{
        message = {message, new_setting},
        send_level = "global"
      }
      ChatHistoryManager.print_chat("global")
    end
  else
    local player_index = event.player_index
    if not player_index then return log("Who changed their setting???") end
    if setting == "bc-player-chat-history" then
      -- Send a message to notify the setting change
      -- Also to cause the ChatHistoryManager to fix a chatlog that's too long
      local new_setting = settings.get_player_settings(player_index)[setting].value
      send_message{
        message = {"chat-localization.bc-player-history-changed", new_setting},
        send_level = "player",
        recipient = player_index
      }
      ChatHistoryManager.print_chat("player", player_index)
    elseif setting == "bc-player-closeable-chat" then
      -- Clear opened value when closeable is disabled
      -- Also does it when enabled, but they should just be in main menu
      storage.isChatOpen[player_index--[[@as int]]] = nil
      -- Update chat to now match the openness it Should be now
      ChatHistoryManager.print_chat("player", player_index)
    elseif (
      setting == "bc-color-fade" or
      setting == "bc-default-color" or
      setting == "bc-error-color" or
      setting == "bc-warn-color" or
      setting == "bc-debug-color"
    ) then
      -- Reprint chat to update the the printed chat
      ChatHistoryManager.print_chat("player", player_index)
    end
  end
end

--#region Players/Forces Created/Destroyed
backup_handler.events[defines.events.on_player_created] =  function (event)
	ChatHistoryManager.add_player(event.player_index)
end
backup_handler.events[defines.events.on_force_created] =  function (event)
	ChatHistoryManager.add_force(event.force.index)
end
backup_handler.events[defines.events.on_player_removed] =  function (event)
	ChatHistoryManager.remove_player(event.player_index)
end
backup_handler.events[defines.events.on_forces_merged] =  function (event)
	ChatHistoryManager.remove_force(event.source_index)
end
--#endregion
--#endregion

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
	-- [ ] debug(LocalisedString, isEphemeral)
	-- [ ] print(LocalisedString, color)
	-- [ ] warn(LocalisedString, isEphemeral)
	-- [ ] error(LocalisedString, isEphemeral)
	clear = ChatHistoryManager.clear,

	get_message = filter.get_message,
	set_message = filter.set_message,
})
--#endregion

---@type {[string]:metatable}
metatables = {}

event_handler.add_libraries{
	require("__better-chat__.runtime.storage"),
	backup_handler,
	require("__better-chat__.runtime.disableFunctions"),
	require("__better-chat__.runtime.is_open"),
}

for name, metatable in pairs(metatables) do
	script.register_metatable(name, metatable)
end