---@alias historyLevel "global"|"force"|"player"
local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")
local default_emojipack = require("__better-chat__.runtime.default_shortcodes")
local send_message = require("__better-chat__.runtime.handle_messages").send_message
local disableFunctions = require("__better-chat__.runtime.disableFunctions")
local filter = require("__better-chat__.runtime.filter")
---@class BetterChatGlobal
---@field emojipacks table<string,table<string,string[]|string>>
---@field isChatOpen {[integer]: boolean, check:fun(this, integer):boolean}
---@field disabledListeners table<defines.events, string[]>
---@field disabledCommands table<string, string[]>
---@field lastWhispered table<int,int?>
storage = {}
---@type {[string]:metatable}
metatables = {}


---Clean emojipacks of unloaded mods
---@param changes {[string]: ModChangeData}
local function clean_emojipacks(changes)
	-- Remove emojipacks of unloaded mods
	for mod_name in pairs(changes) do
		if not changes[mod_name].new_version then
			storage.emojipacks[mod_name] = nil
		end
	end

  --- Update the default emojipack
  storage.emojipacks[script.mod_name] = default_emojipack
end

script.on_event("bc-toggle-chat", function (event)
  if not settings.get_player_settings(event.player_index)["bc-player-closeable-chat"].value then
    return
  end
	storage.isChatOpen[event.player_index] = not storage.isChatOpen:check(event.player_index)
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Toggle Chat")
end)
script.on_event("bc-exit-chat", function (event)
  if not settings.get_player_settings(event.player_index)["bc-player-closeable-chat"].value then
    return
  end
	storage.isChatOpen[event.player_index] = nil
	ChatHistoryManager.print_chat("player", event.player_index)
	-- log("Exit Chat")
end)

--#region Setup
local isOpenDirty = false
metatables.chatOpenMeta = {
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
script.register_metatable("bc-chatOpen",metatables.chatOpenMeta)

local function setupGlobal()
	storage.emojipacks = storage.emojipacks or {
    [script.mod_name] = default_emojipack
  }
	storage.isChatOpen = storage.isChatOpen or setmetatable({}, metatables.chatOpenMeta)
	storage.disabledListeners = storage.disabledListeners or {}
	storage.disabledCommands = storage.disabledCommands or {}
  storage.lastWhispered = storage.lastWhispered or {}
end

script.on_init(function ()
  setupGlobal()
	disableFunctions.register_enabled_listeners()
	ChatHistoryManager.init()
end)
script.on_load(function ()
	disableFunctions.register_enabled_listeners()
end)
script.on_configuration_changed(function (change)
  setupGlobal()
	clean_emojipacks(change.mod_changes)
	disableFunctions.reenable(change.mod_changes)
end)
script.on_event(defines.events.on_runtime_mod_setting_changed, function (event)
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
end)

--#region Players/Forces Created/Destroyed
script.on_event(defines.events.on_player_created, function (event)
	ChatHistoryManager.add_player(event.player_index)
end)
script.on_event(defines.events.on_force_created, function (event)
	ChatHistoryManager.add_force(event.force.index)
end)
script.on_event(defines.events.on_player_removed, function (event)
	ChatHistoryManager.remove_player(event.player_index)
end)
script.on_event(defines.events.on_forces_merged, function (event)
	ChatHistoryManager.remove_force(event.source_index)
end)
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
	disable_listener = disableFunctions.listener.disable,
	enable_listener = disableFunctions.listener.enable,
	disable_command = disableFunctions.command.disable,
	enable_command = disableFunctions.command.enable,
	-- [ ] debug(LocalisedString, isEphemeral)
	-- [ ] print(LocalisedString, color)
	-- [ ] warn(LocalisedString, isEphemeral)
	-- [ ] error(LocalisedString, isEphemeral)
	-- [ ] clear(player_index),

	get_message = filter.get_message,
	set_message = filter.set_message,
})
remote.add_interface("emojipack registration", {
	add = function (mod_name, shortcode_dictionary)
		if not script.active_mods[mod_name] then return end
		-- storage.emojipacks = global.emojipacks or {}

		storage.emojipacks[mod_name] = shortcode_dictionary
	end
})
--#endregion