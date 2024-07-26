---@alias CommandFunctionDict {[string]:fun(player:LuaPlayer, event:EventData.on_console_command)}
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



--Admin promotion and demotion
commands.promote = function (player, event)
	if not player.admin then
		return handle_messages.send_message({"cant-run-command-not-admin", "promote"},
			nil, "player", player.index)
	end

	local target = event.parameters:match("%S+")
	local promoted_player = game.get_player(target);

	---@type LocalisedString
	local message = {
		"player-was-promoted",
		target,
		player.name
	}

	-- TODO: figure out how to use `player-is-already-in-admin-list`
	if promoted_player then
		message[2] = promoted_player.name
		if promoted_player.admin then
			message[1] = "player-is-already-an-admin"
			return handle_messages.send_message(message, nil, "player", player.index)
		end
	else
		message[1] = "player-was-added-to-admin-list"
	end
	handle_messages.send_message(message, player.chat_color, "global")
end
commands.demote = function (player, event)
	if not player.admin then
		return handle_messages.send_message({"cant-run-command-not-admin", "promote"},
			nil, "player", player.index)
	end
	local target = event.parameters:match("%S+")
	local demoted_player = game.get_player(target);

	local message = {
		"player-was-demoted",
		target,
		player.name
	}

	-- TODO: figure out how to use `player-is-not-in-admin-list`
	if demoted_player then
		message[2] = demoted_player.name
		if not demoted_player.admin then
			message[1] = "player-is-not-an-admin"
			return handle_messages.send_message(message, nil, "player", player.index)
		end
	else
		message[1] = "player-was-removed-from-admin-list"
	end
	handle_messages.send_message(message, player.chat_color, "global")
end

-- script.on_event(defines.events.on_console_command, function (test)
	
-- end)
return commands