---@type command_definition
local handled_commands = {}

local message_handler = require("handle_messages")
local send_message = message_handler.send_message
local color = message_handler.color
---Used to 'fill' commands so it won't log as not implemented
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
	storage.last_whispered[recipient.index] = player.name
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

return handled_commands