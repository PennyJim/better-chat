---@alias CommandFunctionDict {[string]:fun(LuaPlayer, EventData.on_console_command)}
---@type CommandFunctionDict
local commands = {}

local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg

--- TODO: Change entirely!
---Sends an ephemeral warning message to player
---@param player LuaPlayer
---@param message LocalisedString
local function warn(player, message)
	player.print(message, settings.get_player_settings(player)["bc-warn-color"].value--[[@as Color]])
end

---Sends a message globally
---@param player LuaPlayer
---@param message string
local function shout(player, message)
	message = handle_messages.process_message(player, message)
	handle_messages.send_message(msg("bc-shout-header", player.name, message), player.chat_color, "global")
end
---Sends a message to a player
---@param player LuaPlayer
---@param recipient LuaPlayer
---@param message string
local function whisper(player, recipient, message)
	message = handle_messages.process_message(player, message)
	handle_messages.send_message(msg("bc-whisper-to-header", recipient.name, message), player.chat_color, "player", player.index)
	handle_messages.send_message(msg("bc-whisper-from-header", player.name, message), player.chat_color, "player", recipient.index)
end

commands.shout = function(player, event)
	shout(player, event.parameters)
end
commands.whisper = function(player, event)
	local target = event.parameters:match("%S+")
	local recipient = game.get_player(target);

	if not recipient then
		-- FIXME: How do I send this *after* the command response?
		-- Maybe add a delay-send command?
		return warn(player, {"player-doesnt-exist", target})
	end

	local message = event.parameters:sub(#target+2);
	whisper(player, recipient, message)
end

script.on_event(defines.events.on_console_command, function (test)
	
end)
return commands