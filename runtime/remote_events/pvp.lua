local handle_messages = require("__better-chat__.runtime.handle_messages")
local send_message = handle_messages.send_message
local color = handle_messages.color

---@type table<string,function>
local pvp_events = {}

function pvp_events.on_round_end()
	send_message{
		message = {
			"admin-ended-round",
			{"chat-localization.unknown-player"}
		},
		send_level = "global"
	}
end

function pvp_events.on_round_start()
	send_message{
		message = {"map-ready"},
		send_level = "global"
	}
end

function pvp_events.on_team_lost(event)
	local team = game.forces[event.name--[[@as string]]]
	if not team then return end

	send_message{
		message = {
			"silo-destroyed",
			color(team.name, team.color),
			{"chat-localization.unknown-force"}
		},
		send_level = "global"
	}
end

function pvp_events.on_team_won(event)
	local team = game.forces[event.name--[[@as string]]]
	if not team then return end

	send_message{
		message = {
			"team-won",
			color(team.name, team.color)
		},
		send_level = "global"
	}
end

function pvp_events.on_player_joined_team(event)
	local player = game.get_player(event.player_index)
	if not player then return end
	local force = event.force --[[@as LuaForce]]
	if not force or not force.valid then return end

	send_message{
		message = {
			"joined",
			color(player.name, player.chat_color),
			color(force.name, force.color),
		},
		send_level = "global"
	}
end

---@param events event_handler.events
return function (events)
	for name, event_index in pairs(remote.call("pvp", "get_events")) do
		events[event_index] = pvp_events[name]
	end
end