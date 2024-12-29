---@alias CommandFunctionDict {[string]:fun(player:LuaPlayer, event:EventData.on_console_command)}
local commands_api = commands
---@type CommandFunctionDict
local commands = {}

local handle_messages = require("__better-chat__.runtime.handle_messages")
local msg = handle_messages.msg
local color = handle_messages.color
---Used to 'fill' commands so it wont log as not implemented
local dummy_func = function()end

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

---@param string LocalisedString
local function pack_localized_concat(string)
  ---@cast string -?
  local length = #string
  if length <= 21 then
    return string
  end

  ---@type LocalisedString
  local new_string, index = {""}, 1
  for i = 2, length, 20 do
    index = index + 1
    new_string[index] = {"",
      table.unpack(string--[[@as LocalisedString[] ]], i, i+19)
    }
  end

  return pack_localized_concat(new_string)
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
	message = handle_messages.process_message(player, "global", message)
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
	message = handle_messages.process_message(player, "player", message)
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
	local message = handle_messages.process_message(player, "force", event.parameters)
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

  -- Because this only is used when the player has no username set
  -- It's labelled singleplayer because multiplayer forces you to set one.
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

--TODO: Implement Ignore

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

---@param enemy_force LuaForce
---@param surface_name string
---@return LocalisedString
local function get_surface_evolution(enemy_force, surface_name)
  local evolution_factor = enemy_force.get_evolution_factor(surface_name)
  return {
    "evolution-message",
    string.format("%.4f", evolution_factor),
    string.format("%d", enemy_force.get_evolution_factor_by_time(surface_name) / evolution_factor * 100),
    string.format("%d", enemy_force.get_evolution_factor_by_pollution(surface_name) / evolution_factor * 100),
    string.format("%d", enemy_force.get_evolution_factor_by_killing_spawners(surface_name) / evolution_factor * 100)
  }
end

-- My logic for getting the localised surface name might miss something
-- I know it considers the localised_name while the base game doesn't
---@param surface LuaSurface
---@return LocalisedString|true
local function get_localised_surface_name(surface)
  ---@type LocalisedString
  local name = surface.localised_name        -- Get the localised surface name
  if not name then                           -- If it doesn't have one
    local planet = surface.planet            -- then check if it has a planet
    if planet then
      name = planet.prototype.localised_name -- And use *that* localised name
    end
  end

  return name or surface.name
end
commands.evolution = function (player, event)
  ---@type LocalisedString
  local message
  local enemy_force = game.forces["enemy"]
  local parameter = event.parameters

  if parameter ~= "" then
    local surface = game.get_surface(parameter)
    if surface then
      message = get_surface_evolution(enemy_force, surface.name)
    else
      message = {"surface-name-doesnt-exist", parameter}
    end

  else


    ---@type LocalisedString
    message = {""}
    local index = 2

    for surface_name, surface in pairs(game.surfaces) do
      ---@cast surface_name string
      if surface.platform then goto skip_evolution end -- Ignore platforms

      message[index] = get_localised_surface_name(surface)          -- Finally, fallback to the surface string name
      message[index + 1] = " - "
      message[index + 2] = get_surface_evolution(enemy_force, surface_name)
      message[index + 3] = "\n\t\t"

      index = index + 4
      ::skip_evolution::
    end
    message[index - 1] = nil -- remove trailing newline
  end

  handle_messages.send_message{
    message = pack_localized_concat(message),
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

---Adds the given player to the string
---@param player LuaPlayer
---@param list_string LocalisedString
---@param index int
---@param list_offline boolean Whether or not to include offline players in the list
---@nodiscard
---@return int new_index
local function add_player_to_list(player, list_string, index, list_offline)
  if player.connected or list_offline then
    list_string[index+1] = "\n"
    list_string[index+2] = color(player.name, player.chat_color)
    if player.connected then
      list_string[index+3] = " (online)"
      index = index+3
    else
      index = index+2
    end
  end
  return index
end

commands.admins = function (player, event)
  local list_offline = not (event.parameters == "online" or event.parameters == "o")

  local message, index = {"",
    {list_offline and "chat-localization.bc-listing-admins" or "chat-localization.bc-listing-online-admins"},
  }, 2

  for _, player in pairs(game.players) do
    if player.admin then
      index = add_player_to_list(player, message, index, list_offline)
    end
  end

  handle_messages.send_message{
    message = pack_localized_concat(message),
    send_level = "player",
    recipient = player.index
  }
end

commands.players = function (player, event)
  local list_offline = not (event.parameters == "online" or event.parameters == "o")
  local count = event.parameters == "count" or event.parameters == "c"

  local online = table_size(game.connected_players)
  local total = #game.players

  ---@type LocalisedString
  local message, index = {"",
    {"gui-player-management.online-players", online, total}
  }, 2
  ---@cast message -?

  -- Return just the count if count is chosen
  if count then
    return handle_messages.send_message{
      message = message[2],
      send_level = "player",
      recipient = player.index,
    }
  end

  for _, player in pairs(game.players) do
    index = add_player_to_list(player, message, index, list_offline)
  end

  handle_messages.send_message{
    message = pack_localized_concat(message),
    send_level = "player",
    recipient = player.index,
  }
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

commands.command = function (player, event)
  handle_messages.send_message{
    message = msg("bc-command-ran", player, event.parameters),
    color = player.chat_color,
    process_color = true,
    send_level = "global",
    skip_print = true,
  }
end
commands.c = commands.command

-- The lack of clearing will be a little jank
-- But we need to preserve the measured time the engine reports
commands["measured-command"] = function (player, event)
  handle_messages.send_message{
    message = msg("bc-command-ran", player, event.parameters),
    color = player.chat_color,
    process_color = true,
    send_level = "global",
    skip_print = true,
  }
end
commands.mc = commands.command

commands["silent-command"] = function (player, event)
  log({"command-ran", player.name, event.parameters})
end
commands.sc = commands["silent-command"]

-- script.on_event(defines.events.on_console_command, function (test)
	
-- end)
return commands