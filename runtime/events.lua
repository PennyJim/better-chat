local commands = require("__better-chat__.runtime.commands")
local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg
local color = handle_messages.color

---@alias EventFunctionDict event_handler.events
---@type EventFunctionDict
local events = {}
---@alias EventFilterDict {[defines.events]: EventFilter}
---@type EventFilter
local eventFilters = {}


-- Actual Chatting
events[defines.events.on_console_chat] = function (event)
	local player_index = event.player_index
	if not player_index then return end --TODO: Support messages from console
	storage.isChatOpen[player_index] = nil
	local player = game.get_player(player_index)
	if not player then return end

	local send_level = settings.global["bc-normal-chat-type"].value --[[@as historyLevel]]
	local recipient = send_level == "force" and player.force_index or send_level == "player" and player_index or nil

	if send_level == "player" then
		for _, force_player in pairs(player.force.players) do
			if force_player.index ~= player_index then
				handle_messages.clear_ephemeral(force_player.index)
			end
		end
	end

	local message = handle_messages.process_message(player, send_level, event.message)
	handle_messages.send_message{
		message = msg("bc-message-header", player, message),
		color = player.chat_color,
		process_color = true,
		send_level = send_level,
		recipient = recipient
	}
	-- log{"", "global-chat-log", serpent.block(global.GlobalChatLog), "\n"}
	-- log{"", "force-chat-log", serpent.block(global.ForceChatLog), "\n"}
	-- log{"", "player-chat-log", serpent.block(global.PlayerChatLog), "\n"}
end

-- Player events
events[defines.events.on_player_joined_game] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one joined???") end
	handle_messages.send_message{
		message = {"multiplayer.player-joined-game", color(player.name, player.chat_color)},
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}

  if game.is_multiplayer() then
    local setting = settings.get_player_settings(player)
    if setting["bc-player-closeable-chat"].value then
      handle_messages.send_message{
        message = {"chat-localization.bc-latency-warning"},
        color = setting["bc-warn-color"].value --[[@as Color]],
        send_level = "player",
        recipient = event.player_index
      }
    end
  end
end
events[defines.events.on_player_left_game] =  function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one left???") end
	handle_messages.send_message{
		message = {"multiplayer.player-left-game", color(player.name, player.chat_color)},
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
	storage.isChatOpen[event.player_index] = nil
end
events[defines.events.on_player_died] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one died???") end
	if not player.character then return log("Player.character doesn't exist on death, change to pre-death") end
	---@type LocalisedString
	local message = {
		"multiplayer.player-died",
		color(player.name, player.chat_color),
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
	handle_messages.send_message{
		message = message,
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
end
events[defines.events.on_player_respawned] = function (event)
	local player = game.get_player(event.player_index)
	if not player then return log("No one died???") end
	local message = {
		"multiplayer.player-respawn",
		color(player.name, player.chat_color)
	}
	handle_messages.send_message{
		message = message,
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
end

--Research Queueing
events[defines.events.on_research_finished] = function (event)
	if event.by_script then return end
	local research = event.research
	local force = research.force
	handle_messages.broadcast_friendly{
		message = {"technology-researched", research.localised_name},
		color = force.color,
		process_color = true,
		send_level = "force",
		recipient = force.index
	}
end
--Research -- TODO: Get on_research_queued to become a real event
-- events[defines.events.on_research_queued] = function (event)
-- 	-- if event.by_script then return end
-- 	send_message({"player-started-research", {"chat-localization.unknown-player"}, event.research.localised_name},
-- 		nil, "force", event.research.force.index)
-- end
events[defines.events.on_research_cancelled] = function (event)
	-- if event.by_script then return end
	local tech = prototypes.technology
	local force = event.force
	local has_cleared = false
	for research in pairs(event.research) do
		handle_messages.broadcast_friendly{
			message = {"player-cancelled-research", tech[research].localised_name, {"chat-localization.unknown-player"}},
			color = force.color,
			process_color = true,
			send_level = "force",
			recipient = force.index,
			clear = not has_cleared,
		}
		has_cleared = true
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
	---@type LocalisedString
	local message = {
		"player-was-banned",
		event.player_name,
		color(player.name, player.chat_color),
		event.reason or "unspecified"
	}
	---@cast message -?
	if event.player_index then
		message[2] = color(message[2]--[[@as string]], game.get_player(event.player_index--[[@as int]]).chat_color)
	else
		message[1] = "unknown-player-was-banned"
	end
	handle_messages.send_message{
		message = message,
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
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
	handle_messages.send_message{
		message = message,
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
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
		color(player.name, player.chat_color),
		color(by_player.name, by_player.chat_color),
		event.reason or "unspecified"
	}
	handle_messages.send_message{
		message = message,
		color = by_player.chat_color,
		process_color = true,
		send_level = "global"
	}
end
--#endregion

-- Catchall for commands
---@param event EventData.on_console_command
events[defines.events.on_console_command] = function (event)
	local player_index = event.player_index
	if not player_index then return end
	storage.isChatOpen[player_index] = nil
	local player = game.get_player(event.player_index)
	if not player then return end

	local func = commands[event.command] or function() log(event.command..": Not implemented in Better Chatting") end
	local enabled = not storage.disabledCommands[event.command]
	if func and enabled then func(player, event) end
end

---@type {[string]:fun(events:event_handler.events, commands:CommandFunctionDict)}
local remote_event_handlers = {
	["pvp"] = require("__better-chat__.runtime.remote_events.pvp")
}

local function remote_events()
	local interfaces = remote.interfaces
	for remote_interface, value in pairs(remote_event_handlers) do
		if interfaces[remote_interface] then
			value(events, commands)
		end
	end
end

---@class events
---@field events EventFunctionDict
---@field eventFilters EventFilterDict
---@field get_remote_events fun()
return {
	events = events,
	eventFilters = eventFilters,
	get_remote_events = remote_events
}