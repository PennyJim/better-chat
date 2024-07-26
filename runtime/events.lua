local commands = require("__better-chat__.runtime.commands")
local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg

---@alias EventFunctionDict event_handler.events
---@type EventFunctionDict
local events = {}
---@alias EventFilterDict {[defines.events]: EventFilter}
---@type EventFilter
local eventFilters = {}


-- Actual Chatting
events[defines.events.on_console_chat] = function (event)
	local player_index = event.player_index
	if not player_index then return end
	global.isChatOpen[player_index] = nil
	local player = game.get_player(player_index)
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
	---@type LocalisedString
	local message = {
		"multiplayer.player-died",
		player.name,
		player.character.gps_tag --[[@as LocalisedString]]
	}
	---@cast message -?
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
	local research = event.research
	local force = research.force
	handle_messages.send_message({"technology-researched", research.localised_name},
		nil, "force", force.index
	)
	for _, other_force in pairs(game.forces) do
		if other_force ~= force
		or other_force.is_friend(force) then
			handle_messages.send_message({"technology-researched", research.localised_name},
				nil, "force", other_force.index
			)
		end
	end
end
--Research -- TODO: Get on_research_queued to become a real event
-- events[defines.events.on_research_queued] = function (event)
-- 	-- if event.by_script then return end
-- 	send_message({"player-started-research", {"chat-localization.unknown-player"}, event.research.localised_name},
-- 		nil, "force", event.research.force.index)
-- end
events[defines.events.on_research_cancelled] = function (event)
	-- if event.by_script then return end
	local research = event.research
	local force = event.force
	handle_messages.send_message({"player-cancelled-research", {"chat-localization.unknown-player"}, research.localised_name},
		nil, "force", force.index)

	-- Broadcast it to friendly forces
	for _, other_force in pairs(game.forces) do
		if other_force ~= force
		or other_force.is_friend(force) then
			handle_messages.send_message({"technology-researched", research.localised_name},
				nil, "force", other_force.index
			)
		end
	end
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
	global.isChatOpen[event.player_index or 0] = nil
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