local format = require("interface.formatter")
local message_handler = require("handle_messages")
local send_message = message_handler.send_message
---Used to 'fill' commands so it won't log as not implemented
local dummy_func = function()end

---@type command_definition
local handled_commands = {}

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

	return pack_localized_concat(string)
end

local function warn(player, message)
	send_message{
		type = "player",
		recipient = player,
		message = message,
		color = nil, -- TODO: A warn color?
	}
end

--MARK: Chatting

function handled_commands.shout(player, event)
	local message = message_handler.process_message(player, "global", event.parameters)
	send_message{
		type = "global",
		sender = player,
		message = message,
		color = player.chat_color,
		process_color = true,
		sound = defines.print_sound.never,
	}
end
handled_commands.s = handled_commands.shout

commands.add_command("team", {"command-help.team"}, dummy_func)
commands.add_command("t", {"command-help.team"}, dummy_func)
function handled_commands.team(player, event)
	if type(player) ~= "userdata" then
		rcon.print{"chat-localization.bc-server-no-force"}
		return
	end
	local message = message_handler.process_message(player, "force", event.parameters)
	send_message{
		type = "force",
		sender = player,
		recipient = player.force_index,
		message = message,
		color = player.chat_color,
		process_color = true,
	}
end
handled_commands.t = handled_commands.team

---@param player LuaPlayer|ChatPlayer
---@param recipient LuaPlayer
---@param message string
local function whisper(player, recipient, message)
	message = message_handler.process_message(player, "player", message)
	send_message{
		type = "player",
		sender = player,
		recipient = recipient,
		message = message,
		color = player.chat_color,
		process_color = true,
		sound = defines.print_sound.never,
	}
	storage.last_whispered[recipient.index] = player.name --FIXME: Find out what the reply does when whispered to by the server
end
function handled_commands.whisper(player, event)
	local target = event.parameters:match("%S+")--[[@as string?]] or ""
	local recipient = game.get_player(target)

	if not recipient then
		warn(player, {"player-doesn't-exist", target})
		return
	end

	whisper(player, recipient, event.parameters:sub(#target+2))
end
handled_commands.w = handled_commands.whisper

function handled_commands.reply(player, event)
	local recipient = storage.last_whispered[player.index or 0]
	if not recipient then
		warn(player, {"noone-to-reply"})
		return
	end
	local recipient_player = game.get_player(recipient)
	if not recipient_player then
		warn(player, {"player-doesn't-exist", recipient})
		return
	end
	if not recipient_player.connected then
		warn(player {"player-isnt-online", recipient})
		--NOTE: maybe don't return early on this one?
		return
	end
	whisper(player, recipient_player, event.parameters)
end

--MARK: Personal

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

function handled_commands.color(player, event)
	local color_str = event.parameters
	local is_hex = color_str:match("^#%x%x%x%x%x%x$") or color_str:match("^%x%x%x%x%x%x%x%x$")
	local values = color_str:split()

	if not valid_colors[color_str]
	and not is_hex
	or color_str:match("%-")
	or #values > 4 or #values == 0
	then
		warn(player, {"unknown-color", color_str})
		return
	end

	local all_numbers = true
	for _, value in pairs(values) do
		if not tonumber(value) then
			all_numbers = false
			break
		end
	end
	if not all_numbers then
		warn(player, {"unknown-color", color_str})
		return
	end

	--TODO: Figure out some way to deicde when to use the `-singleplayer` key
	-- It's used when the player hasnt' set a name, but what is the default? `""`?
	-- We know they can't be in multiplayer

	send_message{
		type = "global",
		message = {
			"player-changed-color",
			format.player(player),
			format.color(color_str, player.color),
		},
		color = player.chat_color,
		process_color = true,
	}
end

--TODO: Create Ignore (?)

local builtin_command_list = ""
for command in pairs(commands.game_commands) do
	builtin_command_list = builtin_command_list .. " /"..command
end

function handled_commands.help(player, event)
	local command = event.parameters
	if command == "" then
		local custom_command_list = ""
		for command in pairs(commands.commands) do
			custom_command_list = custom_command_list .. " /"..command
		end
		send_message{
			type = "player",
			recipient = player.index,
			message = {"",
				{"command-help.help-list"},
				builtin_command_list,
				custom_command_list,
			}
		}
		return
	end

	--TODO: Preprocess the game commands to grab those who share keys so all their forms are at the front
	local help_message = commands.game_commands[command] or commands.commands[command]

	if not help_message then
		warn(player, {"command-help.unknown-command", command})
		return
	end

	send_message{
		type = "player",
		recipient = player.index,
		message = {"", "/"..command.." ", help_message},
	}
end
handled_commands.h = handled_commands.help

function handled_commands.seed(player)
	send_message{
		type = "player",
		recipient = player.index,
		message = game.surfaces["nauvis"].map_gen_settings.seed,
	}
end

---@param enemy_force LuaForce
---@param surface SurfaceIdentification
---@return LocalisedString
local function get_surface_evolution(enemy_force, surface)
  local evolution_factor = enemy_force.get_evolution_factor(surface)
  return {
    "evolution-message",
    string.format("%.4f", evolution_factor),
    string.format("%d", enemy_force.get_evolution_factor_by_time(surface) / evolution_factor * 100),
    string.format("%d", enemy_force.get_evolution_factor_by_pollution(surface) / evolution_factor * 100),
    string.format("%d", enemy_force.get_evolution_factor_by_killing_spawners(surface) / evolution_factor * 100)
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

function handled_commands.evolution(player, event)
	---@type LocalisedString, int
	local message, index
	local enemy_force = game.forces["enemy"]
	local parameter = event.parameters

	if parameter ~= "" then
		local parameters = parameter:split()
		parameter = parameters[1]
		local surface = game.get_surface(parameter)
		if surface then
			message = get_surface_evolution(enemy_force, surface)
			goto finish_message
		else
			warn(player, {"surface-name-doesnt-exist", parameter})
			return
		end
	end

	message = {""}
	---@cast message -?
	index = 2
	for _, surface in pairs(game.surfaces) do
		if surface.platform then goto skip_evolution end

		message[index] = get_localised_surface_name(surface)
		message[index + 1] = " - "
		message[index + 2] = get_surface_evolution(enemy_force, surface)
		message[index + 3] = "\n\t\t"

		index = index + 4
		::skip_evolution::
	end
	message[index - 1] = nil -- Trailing newline removal

	::finish_message::
	send_message{
		type = "player",
		recipient = player.index,
		message = pack_localized_concat(message),
	}
end

function handled_commands.time(player)
  local total_seconds = math.floor(game.ticks_played / 60)
  local seconds = total_seconds % 60
  local minutes = math.floor(total_seconds / 60) % 60
  local hours = math.floor(total_seconds / 3600) % 24
  local days = math.floor(total_seconds / 86400)

  local added_time = false
  ---@type LocalisedString
  local message = {""}
	---@cast message -?
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
		local last_index = #message
		local final_time = message[last_index]
    message[last_index - 1] = " "
		message[last_index] = {"and"}
		message[last_index + 1] = " "
		message[last_index + 2] = final_time
  end

  send_message{
    type = "player",
    recipient = player.index,
    message = message,
    clear = true,
  }
end

function handled_commands.clear(player)
	message_handler.clear(player.index)
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
    list_string[index+2] = format.player(player)
    if player.connected then
      list_string[index+3] = " (online)"
      index = index+3
    else
      index = index+2
    end
  end
  return index
end

function handled_commands.admins(player, event)
	local parameters = event.parameters:split()
	local list_offline = not (parameters[1] == "online" or parameters[1] == "o")

	local message, index = {""}, 1

	for _, player in pairs(game.players) do
		if player.admin then
			index = add_player_to_list(player, message, index, list_offline)
		end
	end

	send_message{
		type = "player",
		recipient = player.index,
		message = pack_localized_concat(message)
	}
end

function handled_commands.players(player, event)
	local parameters = event.parameters:split()
	local list_offline = false
	local only_count = false
	for _,parameter in pairs(parameters) do
		if parameter == "c" or parameter == "count" then
			only_count = true
		elseif parameter == "o" or parameter == "online" then
			list_offline = true
		end
	end

	local online = table_size(game.connected_players)
	local total = #game.players

	---@type LocalisedString
	local message, index = {""}, 2
	---@cast message -?
	
	---@type LuaPlayer[]|LuaCustomTable<string|uint32,LuaPlayer>
	local player_list
	if list_offline then
		player_list = game.connected_players
		message[index] = {"command-output.player-list", table_size(player_list)}
	else
		player_list = game.players
		message[index] = {"command-output.player-list-online", #player_list}
	end
	index = index + 1

	if not only_count then
		for _, player in pairs(player_list) do
			index = add_player_to_list(player, message, index, true)
		end
	end

	send_message{
		type = "player",
		recipient = player.index,
		message = pack_localized_concat(message),
	}
end

--MARK: Admin commands

---@param player LuaPlayer|ChatPlayer
---@return boolean
local function check_admin(player, command)
	if player.admin then return true end
	if type(player) ~= "userdata" then return true end -- It'll be the server
	warn(player, {"cant-run-command-not-admin", command})
	return false
end

function handled_commands.promote(player, event)
	if not check_admin(player, event.command) then return end

	local target = event.parameters:match("%S+")
	local promoted_player = game.get_player(target)

	if promoted_player and promoted_player.admin then
		warn(player, {"player-is-already-an-admin", format.player(promoted_player)})
		return
	end

	-- Silently returns on multiplayer games...
	--TODO: Find each behavior and see which ones happen anyways (like already an admin)
	if not game.is_multiplayer() then return end
end

--TODO: /config (oh no)


--MARK: Cheats

--TODO: Wrap these commands in a function that warns about achievements
-- We'll have to track it separately so it might be wrong when newly added..

handled_commands["editor"] = dummy_func

handled_commands["measured-command"] = dummy_func
handled_commands["mc"] = dummy_func
handled_commands["silent-command"] = dummy_func
handled_commands["sc"] = dummy_func

return handled_commands