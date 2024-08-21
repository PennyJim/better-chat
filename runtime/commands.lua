---@alias CommandFunctionDict {[string]:fun(player:LuaPlayer, event:EventData.on_console_command)}
---@type CommandFunctionDict
local commands = {}

local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg
local color = handle_messages.color

--- TODO: Change entirely!
---Sends an ephemeral warning message to player
---@param player LuaPlayer
---@param message LocalisedString
local function warn(player, message)
  handle_messages.clear_ephemeral(player.index)
	player.print(message, settings.get_player_settings(player)["bc-warn-color"].value--[[@as Color]])
end

---Sends a message globally
---@param player LuaPlayer
---@param message string
local function shout(player, message)
	message = handle_messages.process_message(player, message)
	handle_messages.send_message{
		message = msg("bc-shout-header", player, message),
		color = player.chat_color,
		process_color = true,
		send_level = "global",
	}
end
---Sends a message to a player
---@param player LuaPlayer
---@param recipient LuaPlayer
---@param message string
local function whisper(player, recipient, message)
	message = handle_messages.process_message(player, message)
	handle_messages.send_message{
		message = msg("bc-whisper-to-header", recipient, message),
		color = player.chat_color,
		process_color = true,
		send_level = "player",
		recipient = player.index
	}
	handle_messages.send_message{
		message = msg("bc-whisper-from-header", player, message),
		color = player.chat_color,
		process_color = true,
		send_level = "player",
		recipient = recipient.index
	}
end

commands.shout = function(player, event)
	shout(player, event.parameters)
end
commands.s = commands.shout
commands.whisper = function(player, event)
	local target = event.parameters:match("%S+")--[[@as string?]] or ""
	local recipient = game.get_player(target);

	if not recipient then
		return warn(player, {"player-doesnt-exist", target})
	end

	local message = event.parameters:sub(#target+2);
	whisper(player, recipient, message)
end
commands.w = commands.whisper

commands.seed = function (player)
  handle_messages.send_message{
    message = game.surfaces["nauvis"].map_gen_settings.seed,
    send_level = "player",
    recipient = player.index
  }
end

commands.evolution = function (player)
  local enemy_force = game.forces["enemy"]
  local evolution_factor = enemy_force.evolution_factor
  handle_messages.send_message{
    message = {
      "evolution-message",
      string.format("%.4f", evolution_factor),
      string.format("%d", enemy_force.evolution_factor_by_time / evolution_factor * 100),
      string.format("%d", enemy_force.evolution_factor_by_pollution / evolution_factor * 100),
      string.format("%d", enemy_force.evolution_factor_by_killing_spawners / evolution_factor * 100)
    },
    send_level = "player",
    recipient = player.index
  }
end

commands.time = function (player)
  local total_seconds = math.floor(game.ticks_played / 60)
  local seconds = total_seconds % 60
  local minutes = math.floor(total_seconds / 60) % 60
  local hours = math.floor(total_seconds / 3600) % 24
  local days = math.floor(total_seconds / 86400)

  local added_time = false
  ---@type LocalisedString
  local message = {""}
  if days > 0 then
    message[#message+1] = {"days", days}
    added_time = true
  end

  if hours > 0 then
    if added_time then
      message[#message+1] = ", "
    end
    message[#message+1] = {"hours", hours}
    added_time = true
  end

  if minutes > 0 then
    if added_time then
      message[#message+1] = ", "
    end
    message[#message+1] = {"minutes", minutes}
    added_time = true
  end

  if seconds > 0 then
    if added_time then
      message[#message+1] = ", "
    end
    message[#message+1] = {"seconds", seconds}
    added_time = true
  end

  if #message > 2 then
    message[#message-1] = {""," ",{"and"}," ",}
  end

  handle_messages.send_message{
    message = message,
    send_level = "player",
    recipient = player.index
  }
end


--Admin promotion and demotion
commands.promote = function (player, event)
	if not player.admin then
		return handle_messages.send_message{
			message = {"cant-run-command-not-admin", "promote"},
			send_level = "player",
			recipient = player.index
		}
	end

	local target = event.parameters:match("%S+")
	local promoted_player = game.get_player(target);

	---@type LocalisedString
	local msg = {
		"player-was-promoted",
		target,
		player.name
	}

	-- TODO: figure out how to use `player-is-already-in-admin-list`
	if promoted_player then
		msg[2] = color(promoted_player.name, promoted_player.chat_color)
		if promoted_player.admin then
			msg[1] = "player-is-already-an-admin"
			return handle_messages.send_message{
				message = msg,
				send_level = "player",
				recipient = player.index
			}
		end
	else
		msg[1] = "player-was-added-to-admin-list"
	end
	handle_messages.send_message{
		message = msg,
		color = player.chat_color,
		process_color = true,
		send_level = "global",
	}
end
commands.demote = function (player, event)
	if not player.admin then
		return handle_messages.send_message{
			message = {"cant-run-command-not-admin", "promote"},
			send_level = "player",
			recipient = player.index
		}
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
		message[2] = color(demoted_player.name, demoted_player.chat_color)
		if not demoted_player.admin then
			message[1] = "player-is-not-an-admin"
			return handle_messages.send_message{
				message = message,
				send_level = "player",
				recipient = player.index
			}
		end
	else
		message[1] = "player-was-removed-from-admin-list"
	end
	handle_messages.send_message{
		message = message,
		color = player.chat_color,
		process_color = true,
		send_level = "global"
	}
end

-- script.on_event(defines.events.on_console_command, function (test)
	
-- end)
return commands