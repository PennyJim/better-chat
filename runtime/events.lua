local commands = require("runtime.commands")
local handle_messages = require("runtime.handle_messages")
local msg = handle_messages.msg

---@alias EventFunctionDict {[defines.events]: fun(EventData)}
---@type EventFunctionDict
local events = {}
---@alias EventFilterDict {[defines.events]: EventFilter}
---@type EventFilter
local eventFilters = {}


-- Actual Chatting
events[defines.events.on_console_chat] = function (event)
	global.isChatOpen[event.player_index] = nil
	local player = game.get_player(event.player_index)
	if not player then return end

	local message = handle_messages.process_message(player, event.message)
	handle_messages.send_message(msg("bc-message-header", player.name, message), player.chat_color, "force", player.force_index)
	-- log{"", "global-chat-log", serpent.block(global.GlobalChatLog), "\n"}
	-- log{"", "force-chat-log", serpent.block(global.ForceChatLog), "\n"}
	-- log{"", "player-chat-log", serpent.block(global.PlayerChatLog), "\n"}
end

-- Player events
events[defines.events.on_player_joined_game] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one joined???") end
	handle_messages.send_message({"multiplayer.player-joined-game", player.name}, player.chat_color, "global")
end
events[defines.events.on_player_left_game] =  function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one left???") end
	handle_messages.send_message({"multiplayer.player-left-game", player.name}, player.chat_color, "global")
	global.isChatOpen[event.player_index] = nil
end
events[defines.events.on_player_died] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one died???") end
	if not player.character then return log("Player.character doesn't exist on death, change to pre-death") end
	local message = {
		"multiplayer.player-died",
		player.name,
		player.character.gps_tag --[[@as LocalisedString]]
	}
	if event.cause then
		local cause_name = event.cause.localised_name
		if event.cause.name  == "character" and event.cause.player then
			cause_name = event.cause.player.name
		end

		message[1] = "multiplayer.player-died-by"
		message[4] = message[3]
		message[3] = cause_name
	end
	handle_messages.send_message(message, player.chat_color, "global")
end
events[defines.events.on_player_respawned] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one died???") end
	local message = {
		"multiplayer.player-respawn",
		player.name
	}
	handle_messages.send_message(message, player.chat_color, "global")
end

--Research Queueing
events[defines.events.on_research_finished] = function (event)
	if event.by_script then return end
	handle_messages.send_message({"technology-researched", event.research.localised_name},
		nil, "force", event.research.force.index)
end
--Research -- TODO: Get on_research_queued to become a real event
-- events[defines.events.on_research_queued] = function (event)
-- 	-- if event.by_script then return end
-- 	send_message({"player-started-research", {"chat-localization.unknown-player"}, event.research.localised_name},
-- 		nil, "force", event.research.force.index)
-- end
events[defines.events.on_research_cancelled] = function (event)
	-- if event.by_script then return end
	handle_messages.send_message({"player-cancelled-research", {"chat-localization.unknown-player"}, event.research.localised_name},
		nil, "force", event.force.index)
end

--Admin promotion and demotion
commands.promote = function (player, event)
	if not player.admin then
		return handle_messages.send_message({"cant-run-command-not-admin", "promote"},
			nil, "player", player.index)
	end

	local target = event.parameters:match("%S+")
	local promoted_player = game.get_player(target);

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

--Banned and kicked
events[defines.events.on_player_banned] = function (event)
	local player = game.get_player(event.by_player)
	if not player then
	---@diagnostic disable-next-line: missing-fields
		player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-banned",
		event.player_name,
		player.name,
		event.reason or "unspecified"
	}
	if not event.player_index then message[1] = "unknown-player-was-banned" end
	handle_messages.send_message(message, player.chat_color, "global")
end
events[defines.events.on_player_unbanned] = function (event)
	local player = game.get_player(event.by_player)
	if not player then
	---@diagnostic disable-next-line: missing-fields
		player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-unbanned",
		event.player_name,
		player.name
	}
	handle_messages.send_message(message, player.chat_color, "global")
end
events[defines.events.on_player_kicked] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one was kicked???") end
	local by_player = game.get_player(event.by_player)
	if not by_player then
	---@diagnostic disable-next-line: missing-fields
		by_player = {
			name = "console",
			chat_color = settings.global["bc-default-color"].value --[[@as Color]]
		}
	end
	local message = {
		"player-was-kicked",
		player.name,
		by_player.name,
		event.reason or "unspecified"
	}
	handle_messages.send_message(message, by_player.chat_color, "global")
end
--#endregion

-- Catchall for commands
events[defines.events.on_console_command] = function (event)
	global.isChatOpen[event.player_index] = nil
	local player = game.get_player(event.player_index)
	if not player then return end

	local func = commands[event.command]
	local enabled = not global.disabledCommands[event.command]
	if func and enabled then func(player, event) end
end

---@class EventData
---@field events EventFunctionDict
---@field eventFilters EventFilterDict
return {
	events = events,
	eventFilters = eventFilters,
}