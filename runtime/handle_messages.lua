local ChatHistoryManager = require("__better-chat__.runtime.ChatHistoryManager")

---Replaces all instances of a pattern with the output of the provided function
---@param text string
---@param pattern string
---@param replaceFun fun(match:string):string
---@return string
local function replace_all(text, pattern, replaceFun)
	local output = text
	for match in text:gmatch(pattern) do
		local front, back = output:find(match, 1, true)
		local firsthalf = output:sub(1, front-1)
		local secondHalf = output:sub(back+1)
		output = firsthalf..replaceFun(match)..secondHalf
	end
	return output
end

---Replaces `:<shortcodes>:` into their emoji
---@param text string
---@return string
local function replace_shortcodes(text)
	--- FIXME: Only replaces the first shortcode..
	return replace_all(text, "%:%S+%:", function (shortcode)
		local item = nil
		for _, dictionary in pairs(global.emojipacks) do
			item = dictionary[shortcode:sub(2,-2)] or item
		end
		return item or shortcode
	end)
end

---Turns the message into a chat message
---@param sender LuaPlayer
---@param text string
---@return string
local function process_message(sender, text)
	--Process Item codes with images
	local message = replace_shortcodes(text)

	--- Toggle based icon settings
	local player_settings = settings.get_player_settings(sender)
	local icons = {"item","entity","technology","recipe","item-group","fluid","tile","virtual-signal","achievement"}

	for _,icon in pairs(icons) do
		if(player_settings["bc-"..icon.."-icon"].value) then
			message = replace_all(message, "%["..icon:gsub("%-", "%%-").."=%S+]", function (match)
				return "[img="..icon.."."..match:sub(3+#icon)
			end)
		end
	end
	return message
end

---@class messageParams.base
---@field message LocalisedString The message
---@field color Color? The general color of the message
---@field process_color boolean? Whether or not the message is faded out by the player's settings
---@field send_level historyLevel
---@field clear boolean? Whether or not the chat is cleared, `true` by default

---@class messageParams.global : messageParams.base
---@field send_level "global" How broad this is broadcast

---@class messageParams.recipient : messageParams.base
---@field send_level "force"|"player"
---@field recipient integer? Either the player or force that recieves it if the send_level was not global

---@alias messageParams messageParams.global|messageParams.recipient

---Processes messsage, saves it to history, then sends latest x messages
---@param message messageParams
---@return string? Error
local function send_message(message)
	local error = nil
	local send_level = message.send_level
	local recipient = message.recipient

	if send_level ~= "force" and
		send_level ~= "global" and
		send_level ~= "player" then
			error = "Invalid send level"
	elseif send_level ~= "global" and type(recipient) ~= "number" then
		error = "Invalid recipient. Must be an index"
	elseif send_level == "force" and not game.forces[recipient] then
		error = "Invalid force"
	elseif send_level == "player" and not game.players[recipient] then
		error = "Invalid player"
	end

	if error then
		log(error)
		return error
	end

	local msg = message.message
	local color = message.color
	local process_color = message.process_color
	local clear = message.clear ~= false

	ChatHistoryManager.add_message{
		message = msg,
		color = color,
		process_color = process_color,
		level = send_level,
		chat_index = recipient
	}

	--Clear chat if `clear` is true or nil
	if clear then
		ChatHistoryManager.print_chat(send_level, recipient)

	else -- FIXME: use the internal print function rather than this hacked together one
		---@type LuaGameScript|LuaForce|LuaPlayer
		local printer
		if send_level == "global" then
			printer = game
		elseif send_level == "force" then
			---@cast recipient -?
			printer = game.forces[recipient]
		else
			---@cast recipient -?
			printer = game.players[recipient]
		end
		printer.print(msg, {
			color = color,
			skip = defines.print_skip.never
		})
	end
end

---Turns the arguments into a LocalizedString
---@param header string
---@param player LuaPlayer
---@param message string
---@return LocalisedString message
local function msg(header, player, message)
	local name = player.name
	if player.tag and #player.tag > 0 then
		name = name.." "..player.tag
	end
	local color = player.chat_color
	return {
		"",
		{
			"chat-localization.colored-text",
			{
				"chat-localization."..header,
				name
			},
			color[1] or color.r,
			color[2] or color.g,
			color[3] or color.b,
		},
		message
	}
end

---Wraps the given LocalisedString or string in a LocalisedString
---that colors the text. Mostly just a shorthand to avoid
---turning the color objects into the argument array all the time
---@param string LocalisedString
---@param color Color
---@return LocalisedString
local function color(string, color)
	return {
		"chat-localization.colored-text",
		string,
		color[1] or color.r,
		color[2] or color.g,
		color[3] or color.b,
	}
end

-- TODO: Add Nicknames?


return {
	send_message = send_message,
	process_message = process_message,
	msg = msg,
	color = color,
}