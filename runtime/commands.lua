---@alias CommandFunctionDict {[string]:fun(player:LuaPlayer, event:EventData.on_console_command)}
local commands_api = commands
---@type CommandFunctionDict
local commands = {}

local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg
local color = handle_messages.color

---Splits a string at 'sep'
---@param str string
---@param sep string?
---@return string[]
function string.split(str, sep)
	---@type string[]
	local fields = {}

	sep = sep or " "
	local pattern = string.format("([^%s]+)", sep)
---@diagnostic disable-next-line: discard-returns
	string.gsub(str, pattern, function(c) fields[#fields + 1] = c end)

	return fields
end

---Sends an ephemeral warning message to player
---@param player LuaPlayer
---@param message LocalisedString
local function warn(player, message)
  handle_messages.clear_ephemeral(player.index)
	player.print(message, {color=settings.get_player_settings(player)["bc-warn-color"].value--[[@as Color]]})
end

--MARK: Chatting

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
  storage.lastWhispered[recipient.index] = player.index
end

commands.shout = function(player, event)
	shout(player, event.parameters)
end
commands.s = commands.shout
commands.team = function(player, event)
	local message = handle_messages.process_message(player, event.parameters)
	handle_messages.send_message{
		message = msg("bc-team-header", player, message),
		color = player.chat_color,
		process_color = true,
		send_level = "force",
		recipient = player.force_index,
    clear = false
	}
end
commands.t = commands.team
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
commands.reply = function (player, event)
  local recipient = game.get_player(storage.lastWhispered[player.index] or "")
  if not recipient then
    return warn(player, {"noone-to-reply"})
  end
  whisper(player, recipient, event.parameters)
end
commands.r = commands.reply

local dummy_func = function()end
commands_api.add_command("team", {"command-help.team"}, dummy_func)
commands_api.add_command("t", {"command-help.team"}, dummy_func)

---@enum valid_colors
local valid_colors = {
  ["default"] = true,
  ["red"] = true,
  ["green"] = true,
  ["blue"] = true,
  ["orange"] = true,
  ["yellow"] = true,
  ["pink"] = true,
  ["purple"] = true,
  ["white"] = true,
  ["black"] = true,
  ["gray"] = true,
  ["brown"] = true,
  ["cyan"] = true,
  ["acid"] = true,
}

commands.color = function (player, event)
  local color_str = event.parameters
  local values = color_str:split()
  local num_values = #values

  -- The game lets people define less than
  -- 3 numbers, so we have to as well
  values[2] = values[2] or "0"
  values[3] = values[3] or "0"

  -- Don't let sine-parameters through if they're
  -- not valid colors or hexadecimal
  if num_values == 1
  and not valid_colors[color_str]
  and not color_str:match("^#%x%x%x%x%x%x$")
  and not color_str:match("^#%x%x%x%x%x%x%x%x$") then
    return warn(player, {"unknown-color", color_str})
  end

  -- Don't let negative numbers through
  if color_str:match("%-") then
    return warn(player, {"unknown-color", color_str})
  end

  -- Make sure each number is a valid number
  -- Unfilled ones already default to "0"
  -- But we do have to worry about whether
  -- the fourth exists or not
  if not tonumber(values[1])
  and not tonumber(values[2])
  and not tonumber(values[3])
  and (num_values ~= 4 or not tonumber(values[4])) then
    return warn(player, {"unknown-color", color_str})
  end


  -- player-changed-color=__1__'s color is now __2__.
  -- player-changed-color-singleplayer=Your color is now __1__.
  ---@type historyLevel, int?
  local send_level, recipient
  ---@type LocalisedString
  local message = {"player-changed-color", color_str}
  ---@cast message -?

  -- Change the message (and set a recipient)
  -- depending on if it's multiplayer or not

  -- Disabled because base game no longer does so??
  -- if game.is_multiplayer() then
    send_level = "global"
    message[3] = message[2]
    message[2] = color(player.name, player.chat_color)
  -- else
  --   send_level = "player"
  --   message[1] = message[1].."-singleplayer"
  --   recipient = player.index
  -- end


  handle_messages.send_message{
    message = message,
    color = player.chat_color,
    send_level = send_level,
    recipient = recipient,
  }
end

--MARK: Information

commands.help = function (player, event)
  local command = event.parameters
  local help_message = commands_api.game_commands[command] or commands_api.commands[command]

  if not help_message then
    return warn(player, {"command-help.unknown-command", {command}})
  end

  handle_messages.send_message{
    message = {"", "/"..command.." ", help_message},
    send_level = "player",
    recipient = player.index,
  }
end
commands.h = commands.help

commands.seed = function (player)
  handle_messages.send_message{
    message = game.surfaces["nauvis"].map_gen_settings.seed,
    send_level = "player",
    recipient = player.index
  }
end

commands.evolution = function (player)
  local enemy_force = game.forces["enemy"]
  local surface_index = player.surface_index
  local evolution_factor = enemy_force.get_evolution_factor(surface_index)
  handle_messages.send_message{
    message = {
      "evolution-message",
      string.format("%.4f", evolution_factor),
      string.format("%d", enemy_force.get_evolution_factor_by_time(surface_index) / evolution_factor * 100),
      string.format("%d", enemy_force.get_evolution_factor_by_pollution(surface_index) / evolution_factor * 100),
      string.format("%d", enemy_force.get_evolution_factor_by_killing_spawners(surface_index) / evolution_factor * 100)
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

--MARK: Functional

commands.clear = function (player, event)
  handle_messages.clear(player.index)
end

--MARK: Admin Functional

--TODO: Will have to store whether it's action loggin in storage.
-- I simply don't want to right now.
-- commands["toggle-action-logging"] = function (player, event)

-- end

--MARK: Admin

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